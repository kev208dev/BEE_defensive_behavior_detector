"""Converts database rows into API response models."""

from __future__ import annotations

from datetime import datetime

from sqlmodel import Session, desc, select

from app.config import Settings
from app.enums import HiveStatus
from app.models import Alert, Hive
from app.schemas import AlertDetail, AlertSummary, HiveDetail, HiveSummary
from app.services import hive_state
from app.services.explanation import build_status_reason
from app.services.risk_engine import RiskAssessment, is_offline


def snapshot_url(path: str | None, settings: Settings) -> str | None:
    """Turn a stored snapshot filename into a URL the mobile app can load."""
    if not path:
        return None
    filename = path.rsplit("/", 1)[-1]
    return f"{settings.public_base_url}/static/snapshots/{filename}"


def hive_to_summary(
    hive: Hive,
    settings: Settings,
    *,
    last_heartbeat: datetime | None,
    now: datetime | None = None,
) -> HiveSummary:
    offline = is_offline(last_heartbeat, settings, now)
    return HiveSummary(
        id=hive.id,
        name=hive.name,
        location=hive.location,
        status=HiveStatus.OFFLINE if offline else hive.status,
        risk_score=hive.risk_score,
        hornet_count=hive.current_hornet_count,
        max_hornet_count=hive.max_hornet_count,
        audio_probability=hive.audio_probability,
        last_updated=hive.last_updated,
        monitoring_online=not offline,
        last_heartbeat=last_heartbeat,
    )


def alert_to_summary(alert: Alert, hive_name: str) -> AlertSummary:
    return AlertSummary(
        id=alert.id,
        hive_id=alert.hive_id,
        hive_name=hive_name,
        timestamp=alert.timestamp,
        severity=alert.severity,
        risk_score=alert.risk_score,
        hornet_count=alert.hornet_count,
        message=alert.message,
    )


def alert_to_detail(alert: Alert, hive_name: str) -> AlertDetail:
    return AlertDetail(
        id=alert.id,
        hive_id=alert.hive_id,
        hive_name=hive_name,
        timestamp=alert.timestamp,
        severity=alert.severity,
        risk_score=alert.risk_score,
        hornet_count=alert.hornet_count,
        message=alert.message,
        max_hornet_count=alert.max_hornet_count,
        audio_probability=alert.audio_probability,
        persistence_ratio=alert.persistence_ratio,
        growth_per_second=alert.growth_per_second,
        thumbnail_url=alert.thumbnail_url,
        clip_url=alert.clip_url,
        explanation=alert.explanation,
        resolved_at=alert.resolved_at,
    )


def recent_alert_summaries(
    session: Session,
    settings: Settings,
    *,
    hive_id: str | None = None,
    limit: int = 10,
    hive_names: dict[str, str] | None = None,
) -> list[AlertSummary]:
    """Newest-first alert summaries, optionally scoped to one hive."""
    statement = select(Alert)
    if hive_id is not None:
        statement = statement.where(Alert.hive_id == hive_id)
    statement = statement.order_by(desc(Alert.timestamp)).limit(limit)
    alerts = session.exec(statement).all()

    names = hive_names if hive_names is not None else load_hive_names(session)
    return [
        alert_to_summary(alert, names.get(alert.hive_id, alert.hive_id))
        for alert in alerts
    ]


def load_hive_names(session: Session) -> dict[str, str]:
    """``{hive_id: name}`` for every hive, so alert lists avoid N+1 queries."""
    return {hive.id: hive.name for hive in session.exec(select(Hive)).all()}


def hive_to_detail(
    session: Session,
    hive: Hive,
    settings: Settings,
    evaluation: hive_state.HiveEvaluation,
    *,
    assessment: RiskAssessment | None = None,
) -> HiveDetail:
    """Build the Hive Detail payload, including the live breakdown."""
    assessment = assessment or evaluation.assessment
    breakdown = assessment.breakdown
    device = hive_state.latest_device(session, hive.id)

    summary = hive_to_summary(
        hive,
        settings,
        last_heartbeat=evaluation.last_heartbeat,
    )
    return HiveDetail(
        **summary.model_dump(),
        last_analyzed_at=hive.last_analyzed_at,
        latest_snapshot_url=snapshot_url(
            hive_state.latest_snapshot_path(session, hive.id), settings
        ),
        persistence_ratio=breakdown.persistence_ratio,
        growth_per_second=breakdown.growth_per_second,
        camera_ok=device.camera_ok if device else False,
        microphone_ok=device.microphone_ok if device else False,
        monitoring=device.monitoring if device else False,
        status_reason=build_status_reason(breakdown, settings),
        recent_alerts=recent_alert_summaries(
            session, settings, hive_id=hive.id, limit=5
        ),
    )
