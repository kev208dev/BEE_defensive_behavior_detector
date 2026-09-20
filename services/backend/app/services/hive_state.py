"""Ties the stored observations to the Risk Engine and the Hive row.

The Risk Engine itself is pure; this module is the thin layer that reads the
recent history out of the database, hands it over, and writes the verdict
back onto the denormalised columns of :class:`~app.models.Hive`.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlmodel import Session, desc, select

from app.config import Settings
from app.enums import HiveStatus
from app.models import AudioDetection, Hive, MonitoringDevice, VisionDetection
from app.services.risk_engine import (
    Observation,
    RiskAssessment,
    evaluate_risk,
    is_offline,
)


@dataclass(frozen=True)
class HiveEvaluation:
    """Result of re-evaluating one hive."""

    assessment: RiskAssessment
    previous_status: HiveStatus
    display_status: HiveStatus
    offline: bool
    last_heartbeat: datetime | None


def recent_observations(
    session: Session,
    hive_id: str,
    settings: Settings,
    now: datetime | None = None,
) -> list[Observation]:
    """Vision detections inside the configured risk window, oldest first."""
    now = now or datetime.utcnow()
    cutoff = now - timedelta(seconds=settings.risk_window_seconds)
    rows = session.exec(
        select(VisionDetection)
        .where(VisionDetection.hive_id == hive_id)
        .where(VisionDetection.timestamp >= cutoff)
        .order_by(VisionDetection.timestamp)
    ).all()
    return [
        Observation(
            timestamp=row.timestamp,
            hornet_count=row.hornet_count,
            max_confidence=row.max_confidence,
        )
        for row in rows
    ]


def recent_audio_probability(
    session: Session,
    hive_id: str,
    settings: Settings,
    now: datetime | None = None,
) -> float:
    """The newest audio probability, provided it is still fresh.

    Stale audio is treated as "no audio signal" (0.0) rather than being
    carried forward, so a loud reading from two minutes ago cannot keep a hive
    in DANGER after the noise has stopped.
    """
    now = now or datetime.utcnow()
    cutoff = now - timedelta(seconds=settings.audio_freshness_seconds)
    row = session.exec(
        select(AudioDetection)
        .where(AudioDetection.hive_id == hive_id)
        .where(AudioDetection.timestamp >= cutoff)
        .order_by(desc(AudioDetection.timestamp))
        .limit(1)
    ).first()
    return float(row.hornet_probability) if row is not None else 0.0


def latest_device(session: Session, hive_id: str) -> MonitoringDevice | None:
    """The monitoring phone that most recently reported for this hive."""
    return session.exec(
        select(MonitoringDevice)
        .where(MonitoringDevice.hive_id == hive_id)
        .order_by(desc(MonitoringDevice.last_heartbeat))
        .limit(1)
    ).first()


def evaluate_hive(
    session: Session,
    hive: Hive,
    settings: Settings,
    *,
    now: datetime | None = None,
    apply: bool = True,
) -> HiveEvaluation:
    """Re-run the Risk Engine for a hive and (optionally) persist the verdict.

    ``display_status`` is what the apps show: it is the risk status, unless
    the monitoring phone has gone quiet, in which case it is OFFLINE.  The
    *stored* status stays the risk status so that an alert episode is not
    reset merely because the phone dropped off the network.
    """
    now = now or datetime.utcnow()
    previous_status = hive.status

    observations = recent_observations(session, hive.id, settings, now)
    audio_probability = recent_audio_probability(session, hive.id, settings, now)
    assessment = evaluate_risk(
        observations,
        settings,
        audio_probability=audio_probability,
        now=now,
    )

    device = latest_device(session, hive.id)
    last_heartbeat = device.last_heartbeat if device is not None else None
    offline = is_offline(last_heartbeat, settings, now)
    display_status = HiveStatus.OFFLINE if offline else assessment.status

    if apply:
        breakdown = assessment.breakdown
        hive.status = assessment.status
        hive.risk_score = assessment.score_int
        hive.current_hornet_count = breakdown.current_hornet_count
        hive.max_hornet_count = breakdown.recent_max_hornet_count
        hive.audio_probability = breakdown.audio_probability
        hive.last_updated = now
        if observations:
            hive.last_analyzed_at = observations[-1].timestamp
        session.add(hive)

    return HiveEvaluation(
        assessment=assessment,
        previous_status=previous_status,
        display_status=display_status,
        offline=offline,
        last_heartbeat=last_heartbeat,
    )


def latest_snapshot_path(session: Session, hive_id: str) -> str | None:
    """Path of the most recent frame stored for this hive."""
    row = session.exec(
        select(VisionDetection)
        .where(VisionDetection.hive_id == hive_id)
        .where(VisionDetection.snapshot_path.is_not(None))  # type: ignore[union-attr]
        .order_by(desc(VisionDetection.timestamp))
        .limit(1)
    ).first()
    return row.snapshot_path if row is not None else None
