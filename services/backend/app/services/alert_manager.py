"""Alert state machine — decides when a threat level becomes an *event*.

The problem this solves: at 1 FPS a hive sitting in DANGER would otherwise
produce sixty alerts a minute.  An alert must represent an *episode*, not a
frame.

The rules, in order:

1. **Escalation only.**  An alert is raised when the hive's status is promoted
   (NORMAL → CAUTION, NORMAL/CAUTION → DANGER).  While the status merely
   *persists*, nothing new is raised — one episode, one alert.
2. **Recovery window.**  The same severity may not fire again until
   ``ALERT_RECOVERY_SECONDS`` have passed since the last alert of that
   severity.  This is what stops a flickering signal (DANGER → NORMAL →
   DANGER within a couple of seconds) from counting as two attacks, while
   still allowing a genuinely new attack later in the day to alert again.
3. **Cooldown.**  A belt-and-braces floor of ``ALERT_COOLDOWN_SECONDS``
   between any two alerts for one hive — except for a strict escalation in
   severity, which always gets through.  A rising threat must never be
   silenced by a timer.

Every threshold above is configuration, not code.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime

from sqlmodel import Session, desc, select

from app.config import Settings
from app.enums import AlertSeverity, HiveStatus
from app.models import Alert, Hive, PushDevice
from app.notifications.sender import NotificationSender, PushPayload
from app.services.explanation import build_explanation, build_message
from app.services.risk_engine import RiskAssessment

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class AlertDecision:
    """Why the state machine did or did not raise an alert."""

    alert: Alert | None
    created: bool
    reason: str
    notified: int = 0


def severity_for_status(
    status: HiveStatus, settings: Settings
) -> AlertSeverity | None:
    """Map a hive status onto the severity it would alert at, if any."""
    if status is HiveStatus.DANGER:
        return AlertSeverity.DANGER
    if status is HiveStatus.CAUTION and settings.alert_on_caution:
        return AlertSeverity.CAUTION
    return None


def _latest_alert(
    session: Session, hive_id: str, severity: AlertSeverity | None = None
) -> Alert | None:
    """Most recent alert for a hive, optionally restricted to one severity."""
    statement = select(Alert).where(Alert.hive_id == hive_id)
    if severity is not None:
        statement = statement.where(Alert.severity == severity)
    statement = statement.order_by(desc(Alert.timestamp)).limit(1)
    return session.exec(statement).first()


def _seconds_since(moment: datetime, now: datetime) -> float:
    return (now - moment).total_seconds()


def evaluate_alert(
    session: Session,
    hive: Hive,
    previous_status: HiveStatus,
    assessment: RiskAssessment,
    settings: Settings,
    *,
    now: datetime | None = None,
    snapshot_url: str | None = None,
    clip_url: str | None = None,
) -> AlertDecision:
    """Decide whether this evaluation starts a new alert episode.

    ``previous_status`` is the hive's status *before* this evaluation; it is
    what makes rule 1 (escalation only) possible.  The caller is responsible
    for committing the session.
    """
    now = now or datetime.utcnow()
    new_status = assessment.status

    severity = severity_for_status(new_status, settings)
    if severity is None:
        return AlertDecision(None, False, f"status {new_status.value} does not alert")

    # Rule 1 — escalation only.
    if previous_status.rank >= new_status.rank:
        return AlertDecision(
            None,
            False,
            f"status sustained at {new_status.value} — same episode",
        )

    # Rule 2 — recovery window for this severity.
    same_severity = _latest_alert(session, hive.id, severity)
    if same_severity is not None:
        elapsed = _seconds_since(same_severity.timestamp, now)
        if elapsed < settings.alert_recovery_seconds:
            return AlertDecision(
                None,
                False,
                f"within {settings.alert_recovery_seconds:.0f}s recovery window "
                f"of the previous {severity.value} alert ({elapsed:.0f}s ago)",
            )

    # Rule 3 — cooldown, bypassed by a strict escalation in severity.
    most_recent = _latest_alert(session, hive.id)
    if most_recent is not None and severity.rank <= most_recent.severity.rank:
        elapsed = _seconds_since(most_recent.timestamp, now)
        if elapsed < settings.alert_cooldown_seconds:
            return AlertDecision(
                None,
                False,
                f"within {settings.alert_cooldown_seconds:.0f}s cooldown "
                f"({elapsed:.0f}s since the last alert)",
            )

    alert = _create_alert(
        session=session,
        hive=hive,
        severity=severity,
        assessment=assessment,
        settings=settings,
        now=now,
        snapshot_url=snapshot_url,
        clip_url=clip_url,
    )
    return AlertDecision(alert, True, f"escalated to {new_status.value}")


def _create_alert(
    *,
    session: Session,
    hive: Hive,
    severity: AlertSeverity,
    assessment: RiskAssessment,
    settings: Settings,
    now: datetime,
    snapshot_url: str | None,
    clip_url: str | None,
) -> Alert:
    breakdown = assessment.breakdown
    alert = Alert(
        hive_id=hive.id,
        timestamp=now,
        severity=severity,
        risk_score=assessment.score_int,
        hornet_count=breakdown.current_hornet_count,
        max_hornet_count=breakdown.recent_max_hornet_count,
        audio_probability=breakdown.audio_probability,
        persistence_ratio=breakdown.persistence_ratio,
        growth_per_second=breakdown.growth_per_second,
        thumbnail_url=snapshot_url,
        clip_url=clip_url,
        message=build_message(hive.name, severity),
        explanation=build_explanation(breakdown, settings, severity),
    )
    session.add(alert)
    session.flush()  # assign the primary key without ending the transaction
    logger.info(
        "Alert raised: hive=%s severity=%s score=%d",
        hive.id,
        severity.value,
        alert.risk_score,
    )
    return alert


def dispatch_notification(
    session: Session,
    alert: Alert,
    hive: Hive,
    sender: NotificationSender,
) -> int:
    """Push a newly created DANGER alert to every registered manager phone.

    Only DANGER is pushed — a CAUTION alert is recorded and shown in the app,
    but does not wake the beekeeper.  Delivery failures are swallowed: an
    alert that was stored but not delivered is still an alert.
    """
    if alert.severity is not AlertSeverity.DANGER:
        return 0

    tokens = [device.token for device in session.exec(select(PushDevice)).all()]
    payload = PushPayload(
        alert_id=alert.id,
        hive_id=hive.id,
        severity=alert.severity.value,
        title=f"[위험] {hive.name}",
        body=alert.message,
        extra={"riskScore": str(alert.risk_score)},
    )
    try:
        return sender.send(payload, tokens)
    except Exception as exc:  # noqa: BLE001 - notification must never break the flow
        logger.error("Notification dispatch failed: %s", exc)
        return 0
