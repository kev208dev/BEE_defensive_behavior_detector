"""Development-only endpoints that make the competition demo reproducible.

These are not part of the product surface — they exist so a demo can be
reset and replayed on stage without hornets, and so the manager phone can be
exercised without waiting for a real escalation.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter
from sqlmodel import delete, select

from app.ai.factory import get_audio_classifier, get_detector
from app.api import mappers
from app.api.deps import SessionDep, SettingsDep, get_hive_or_404
from app.db import seed_hives
from app.enums import HiveStatus
from app.models import Alert, AudioDetection, Hive, MonitoringDevice, VisionDetection
from app.notifications.factory import get_sender
from app.schemas import (
    AlertDetail,
    DemoCreateAlertRequest,
    DemoObserveRequest,
    DemoObserveResponse,
    DemoResetResponse,
    DemoScriptRequest,
    DemoScriptResponse,
    DemoSimulateRequest,
    DemoSimulateResponse,
    DemoSimulateStep,
)
from app.services import demo as demo_service, pipeline
from app.services.alert_manager import dispatch_notification
from app.services.explanation import build_explanation, build_message
from app.services.risk_engine import RiskAssessment, RiskBreakdown

router = APIRouter(prefix="/api/demo", tags=["demo"])


@router.post("/reset", response_model=DemoResetResponse)
def reset_demo(session: SessionDep, settings: SettingsDep) -> DemoResetResponse:
    """Wipe all observations, alerts and device state, then re-seed hives."""
    detections = int(session.exec(delete(VisionDetection)).rowcount or 0)
    detections += int(session.exec(delete(AudioDetection)).rowcount or 0)
    alerts = int(session.exec(delete(Alert)).rowcount or 0)
    session.exec(delete(MonitoringDevice))

    for hive in session.exec(select(Hive)).all():
        hive.status = HiveStatus.OFFLINE
        hive.risk_score = 0
        hive.current_hornet_count = 0
        hive.max_hornet_count = 0
        hive.audio_probability = 0.0
        hive.audio_updated_at = None
        hive.latest_snapshot_path = None
        hive.last_analyzed_at = None
        hive.last_updated = datetime.utcnow()
        session.add(hive)
    session.commit()

    detector = get_detector(settings)
    if hasattr(detector, "clear_scripts"):
        detector.clear_scripts()

    seeded = seed_hives(settings)
    return DemoResetResponse(
        hives_seeded=seeded,
        detections_cleared=detections,
        alerts_cleared=alerts,
    )


@router.post("/simulate", response_model=DemoSimulateResponse)
def simulate(
    payload: DemoSimulateRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> DemoSimulateResponse:
    """Replay the scripted hornet attack against one hive.

    Runs through the real pipeline, so the resulting alert is a genuine
    product of the Risk Engine and the alert state machine.
    """
    hive = get_hive_or_404(session, payload.hive_id)
    result = demo_service.run_simulation(
        session=session,
        settings=settings,
        hive=hive,
        sender=get_sender(settings),
        frames_per_second=payload.frames_per_second,
        include_audio=payload.include_audio,
        reset_first=payload.reset_first,
    )
    return DemoSimulateResponse(
        hive_id=hive.id,
        steps=[
            DemoSimulateStep(
                offset_seconds=step.offset_seconds,
                hornet_count=step.hornet_count,
                audio_probability=step.audio_probability,
                risk_score=step.risk_score,
                status=HiveStatus(step.status),
                alert_created=step.alert_created,
            )
            for step in result.steps
        ],
        alerts_created=result.alerts_created,
        notifications_sent=result.notifications_sent,
    )


@router.post("/create-alert", response_model=AlertDetail)
def create_alert(
    payload: DemoCreateAlertRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> AlertDetail:
    """Force one alert into existence and push it.

    Bypasses the state machine on purpose — this is the "make the manager
    phone buzz right now" button for rehearsing the notification path.
    """
    hive = get_hive_or_404(session, payload.hive_id)

    breakdown = RiskBreakdown(
        current_hornet_count=payload.hornet_count,
        recent_max_hornet_count=payload.max_hornet_count,
        persistence_ratio=0.85,
        growth_per_second=0.25,
        audio_probability=payload.audio_probability,
        visual_count_score=90.0,
        persistence_score=85.0,
        growth_score=70.0,
        audio_score=payload.audio_probability * 100,
        frames_considered=20,
    )
    assessment = RiskAssessment(
        score=float(payload.risk_score),
        status=HiveStatus.DANGER
        if payload.severity.value == "DANGER"
        else HiveStatus.CAUTION,
        breakdown=breakdown,
    )

    alert = Alert(
        hive_id=hive.id,
        timestamp=datetime.utcnow(),
        severity=payload.severity,
        risk_score=payload.risk_score,
        hornet_count=payload.hornet_count,
        max_hornet_count=payload.max_hornet_count,
        audio_probability=payload.audio_probability,
        persistence_ratio=breakdown.persistence_ratio,
        growth_per_second=breakdown.growth_per_second,
        thumbnail_url=mappers.snapshot_url(hive.latest_snapshot_path, settings),
        message=build_message(hive.name, payload.severity),
        explanation=build_explanation(breakdown, settings, payload.severity),
    )
    session.add(alert)

    hive.status = assessment.status
    hive.risk_score = payload.risk_score
    hive.current_hornet_count = payload.hornet_count
    hive.max_hornet_count = payload.max_hornet_count
    hive.audio_probability = payload.audio_probability
    hive.last_updated = alert.timestamp
    session.add(hive)
    session.commit()
    session.refresh(alert)

    dispatch_notification(session, alert, hive, get_sender(settings))
    return mappers.alert_to_detail(alert, hive.name)


@router.post("/script", response_model=DemoScriptResponse)
def script_detector(
    payload: DemoScriptRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> DemoScriptResponse:
    """Queue detector answers so real camera frames drive the scenario.

    Only the mock adapters can be scripted; with ``DETECTOR_MODE=yolo`` the
    real model is in charge and this is a no-op.  Use it when demonstrating
    the full phone → backend → alert path without live hornets: start
    monitoring, call this, and the next frames the phone uploads will carry
    the scripted counts through the genuine Risk Engine.
    """
    get_hive_or_404(session, payload.hive_id)

    counts = payload.counts
    if not counts:
        counts = [
            frame.hornet_count
            for frame in demo_service.expand_scenario(
                demo_service.DEFAULT_SCENARIO, frames_per_second=1.0
            )
        ]

    probabilities = payload.audio_probabilities
    if not probabilities:
        probabilities = [
            frame.audio_probability for frame in demo_service.DEFAULT_SCENARIO
        ]

    frames_queued = 0
    detector = get_detector(settings)
    if hasattr(detector, "push_script"):
        detector.push_script(payload.hive_id, counts)
        frames_queued = len(counts)

    audio_queued = 0
    classifier = get_audio_classifier(settings)
    if hasattr(classifier, "push_script"):
        classifier.push_script(payload.hive_id, probabilities)
        audio_queued = len(probabilities)

    return DemoScriptResponse(
        hive_id=payload.hive_id,
        frames_queued=frames_queued,
        audio_chunks_queued=audio_queued,
    )


@router.post("/observe", response_model=DemoObserveResponse)
def observe(
    payload: DemoObserveRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> DemoObserveResponse:
    """Record one synthetic observation and report the resulting state.

    Goes through the same pipeline a camera frame does, so the risk score and
    any alert are computed for real — only the hornet count is supplied rather
    than detected.  The real-time demo replay drives this once per second.
    """
    hive = get_hive_or_404(session, payload.hive_id)
    now = datetime.utcnow()

    # Keep the hive online for the duration of the replay, otherwise every
    # read would report OFFLINE and mask the escalation.
    demo_service.ensure_demo_heartbeat(session, hive.id, now)

    outcome = pipeline.record_observation(
        session=session,
        settings=settings,
        hive=hive,
        sender=get_sender(settings),
        hornet_count=payload.hornet_count,
        timestamp=now,
        audio_probability=payload.audio_probability,
    )

    breakdown = outcome.evaluation.assessment.breakdown
    return DemoObserveResponse(
        hive_id=hive.id,
        status=outcome.evaluation.assessment.status,
        risk_score=outcome.evaluation.assessment.score_int,
        hornet_count=breakdown.current_hornet_count,
        max_hornet_count=breakdown.recent_max_hornet_count,
        audio_probability=breakdown.audio_probability,
        alert_created=outcome.alert is not None,
        alert_id=outcome.alert.id if outcome.alert else None,
        alert_reason=outcome.alert_reason,
        notifications_sent=outcome.notifications_sent,
    )
