"""Hive listing, detail and status endpoints."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter
from sqlmodel import select

from app.api import mappers
from app.api.deps import SessionDep, SettingsDep, get_hive_or_404
from app.enums import HiveStatus
from app.models import Hive
from app.schemas import (
    DashboardSummary,
    HiveDetail,
    HiveStatusResponse,
    HiveSummary,
)
from app.services import hive_state
from app.services.explanation import build_status_reason

router = APIRouter(prefix="/api", tags=["hives"])


@router.get("/hives", response_model=list[HiveSummary])
def list_hives(session: SessionDep, settings: SettingsDep) -> list[HiveSummary]:
    """Every hive with its current status.

    Statuses are re-evaluated on read so a hive whose monitoring phone went
    quiet flips to OFFLINE without needing a background job.
    """
    now = datetime.utcnow()
    hives = session.exec(select(Hive).order_by(Hive.name)).all()

    summaries: list[HiveSummary] = []
    for hive in hives:
        evaluation = hive_state.evaluate_hive(session, hive, settings, now=now)
        summaries.append(
            mappers.hive_to_summary(
                hive, settings, last_heartbeat=evaluation.last_heartbeat, now=now
            )
        )
    session.commit()
    return summaries


@router.get("/dashboard", response_model=DashboardSummary)
def dashboard(session: SessionDep, settings: SettingsDep) -> DashboardSummary:
    """Aggregated counts plus recent alerts — one call for the manager home."""
    summaries = list_hives(session, settings)
    counts = {status: 0 for status in HiveStatus}
    for summary in summaries:
        counts[summary.status] += 1

    return DashboardSummary(
        total=len(summaries),
        normal=counts[HiveStatus.NORMAL],
        caution=counts[HiveStatus.CAUTION],
        danger=counts[HiveStatus.DANGER],
        offline=counts[HiveStatus.OFFLINE],
        hives=summaries,
        recent_alerts=mappers.recent_alert_summaries(session, settings, limit=10),
    )


@router.get("/hives/{hive_id}", response_model=HiveDetail)
def get_hive(hive_id: str, session: SessionDep, settings: SettingsDep) -> HiveDetail:
    """Full detail for one hive."""
    hive = get_hive_or_404(session, hive_id)
    evaluation = hive_state.evaluate_hive(session, hive, settings)
    detail = mappers.hive_to_detail(session, hive, settings, evaluation)
    session.commit()
    return detail


@router.get("/hives/{hive_id}/status", response_model=HiveStatusResponse)
def get_hive_status(
    hive_id: str, session: SessionDep, settings: SettingsDep
) -> HiveStatusResponse:
    """Lightweight status poll for one hive."""
    hive = get_hive_or_404(session, hive_id)
    evaluation = hive_state.evaluate_hive(session, hive, settings)
    breakdown = evaluation.assessment.breakdown

    response = HiveStatusResponse(
        hive_id=hive.id,
        status=evaluation.display_status,
        risk_score=evaluation.assessment.score_int,
        hornet_count=breakdown.current_hornet_count,
        max_hornet_count=breakdown.recent_max_hornet_count,
        audio_probability=breakdown.audio_probability,
        monitoring_online=not evaluation.offline,
        last_heartbeat=evaluation.last_heartbeat,
        last_analyzed_at=hive.last_analyzed_at,
        status_reason=build_status_reason(breakdown, settings),
        breakdown=breakdown.as_dict(),
    )
    session.commit()
    return response
