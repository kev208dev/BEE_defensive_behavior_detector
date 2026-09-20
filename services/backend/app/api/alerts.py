"""Alert listing and detail endpoints."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, HTTPException, Query, status
from sqlmodel import desc, select

from app.api import mappers
from app.api.deps import SessionDep, SettingsDep
from app.enums import AlertSeverity
from app.models import Alert
from app.schemas import AlertDetail, AlertSummary

router = APIRouter(prefix="/api", tags=["alerts"])


@router.get("/alerts", response_model=list[AlertSummary])
def list_alerts(
    session: SessionDep,
    settings: SettingsDep,
    hive_id: str | None = Query(default=None, description="Restrict to one hive"),
    severity: AlertSeverity | None = Query(default=None),
    since: datetime | None = Query(
        default=None,
        description=(
            "Only alerts strictly newer than this timestamp. Used by the "
            "manager app's polling fallback when FCM is not configured."
        ),
    ),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[AlertSummary]:
    """Recent alerts, newest first."""
    statement = select(Alert)
    if hive_id is not None:
        statement = statement.where(Alert.hive_id == hive_id)
    if severity is not None:
        statement = statement.where(Alert.severity == severity)
    if since is not None:
        statement = statement.where(Alert.timestamp > since)
    statement = statement.order_by(desc(Alert.timestamp)).limit(limit)

    alerts = session.exec(statement).all()
    names = mappers.load_hive_names(session)
    return [
        mappers.alert_to_summary(alert, names.get(alert.hive_id, alert.hive_id))
        for alert in alerts
    ]


@router.get("/alerts/{alert_id}", response_model=AlertDetail)
def get_alert(
    alert_id: str, session: SessionDep, settings: SettingsDep
) -> AlertDetail:
    """Full detail for one alert, including the reasoning text."""
    alert = session.get(Alert, alert_id)
    if alert is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alert not found: {alert_id}",
        )
    names = mappers.load_hive_names(session)
    return mappers.alert_to_detail(alert, names.get(alert.hive_id, alert.hive_id))
