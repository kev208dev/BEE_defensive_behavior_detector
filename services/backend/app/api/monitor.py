"""Monitoring uploads: frames, audio chunks and heartbeats.

These three endpoints are what the phone in front of the hive talks to.
"""

from __future__ import annotations

import logging
from datetime import datetime

from fastapi import APIRouter, File, Form, UploadFile

from app.ai.detector import Detection, DetectionResult
from app.ai.factory import get_audio_classifier, get_detector
from app.api import mappers
from app.api.deps import SessionDep, SettingsDep, get_hive_or_404
from app.notifications.factory import get_sender
from app.schemas import (
    AudioResponse,
    FrameResponse,
    HeartbeatRequest,
    HeartbeatResponse,
    ObservationRequest,
)
from app.services import hive_state, pipeline
from app.services.pairing import bind_device_to_hive

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/monitor", tags=["monitor"])

#: Frames larger than this are rejected rather than buffered. The mobile app
#: downscales and JPEG-compresses before upload, so a legitimate frame is well
#: under this; anything bigger is a misconfigured client.
MAX_FRAME_BYTES = 8 * 1024 * 1024
MAX_AUDIO_BYTES = 16 * 1024 * 1024


@router.post("/frame", response_model=FrameResponse)
async def upload_frame(
    session: SessionDep,
    settings: SettingsDep,
    hive_id: str = Form(...),
    device_id: str = Form(...),
    timestamp: datetime | None = Form(default=None),
    image: UploadFile = File(...),
) -> FrameResponse:
    """Accept one camera frame, analyse it and return the hive's new state.

    The response is what drives the Live Monitoring screen, so it carries the
    status, the score and the counts rather than just an acknowledgement.
    """
    hive = get_hive_or_404(session, hive_id)

    payload = await image.read()
    if len(payload) > MAX_FRAME_BYTES:
        logger.warning(
            "Frame from %s for hive %s is %d bytes — truncating analysis",
            device_id,
            hive_id,
            len(payload),
        )
        payload = b""

    outcome = pipeline.process_frame(
        session=session,
        settings=settings,
        hive=hive,
        detector=get_detector(settings),
        sender=get_sender(settings),
        image=payload,
        device_id=device_id,
        timestamp=timestamp,
    )

    evaluation = outcome.evaluation
    breakdown = evaluation.assessment.breakdown
    return FrameResponse(
        # The uploading phone is by definition online, so it should see the
        # risk status rather than an OFFLINE flag racing its own heartbeat.
        status=evaluation.assessment.status,
        risk_score=evaluation.assessment.score_int,
        hornet_count=outcome.detection.hornet_count,
        confidence=round(outcome.detection.max_confidence, 4),
        processed_at=datetime.utcnow(),
        max_hornet_count=breakdown.recent_max_hornet_count,
        audio_probability=breakdown.audio_probability,
        snapshot_url=mappers.snapshot_url(outcome.snapshot_path, settings),
        alert_id=outcome.alert.id if outcome.alert else None,
    )


@router.post("/observation", response_model=FrameResponse)
def upload_observation(
    payload: ObservationRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> FrameResponse:
    """Accept on-device detection metadata without receiving a camera image."""
    hive = get_hive_or_404(session, payload.hive_id)
    detection = DetectionResult(
        hornet_count=payload.hornet_count,
        max_confidence=payload.max_confidence,
        detections=[
            Detection(
                x1=item.x,
                y1=item.y,
                x2=item.x + item.width,
                y2=item.y + item.height,
                confidence=item.confidence,
                class_name=item.class_name,
            )
            for item in payload.detections
        ],
    )
    outcome = pipeline.process_detection_observation(
        session=session,
        settings=settings,
        hive=hive,
        sender=get_sender(settings),
        detection=detection,
        device_id=payload.device_id,
        timestamp=payload.timestamp,
    )

    evaluation = outcome.evaluation
    breakdown = evaluation.assessment.breakdown
    return FrameResponse(
        status=evaluation.assessment.status,
        risk_score=evaluation.assessment.score_int,
        hornet_count=detection.hornet_count,
        confidence=round(detection.max_confidence, 4),
        processed_at=datetime.utcnow(),
        max_hornet_count=breakdown.recent_max_hornet_count,
        audio_probability=breakdown.audio_probability,
        snapshot_url=None,
        alert_id=outcome.alert.id if outcome.alert else None,
    )


@router.post("/audio", response_model=AudioResponse)
async def upload_audio(
    session: SessionDep,
    settings: SettingsDep,
    hive_id: str = Form(...),
    device_id: str = Form(...),
    timestamp: datetime | None = Form(default=None),
    audio: UploadFile = File(...),
) -> AudioResponse:
    """Accept one audio chunk and return its hornet probability."""
    hive = get_hive_or_404(session, hive_id)

    payload = await audio.read()
    if len(payload) > MAX_AUDIO_BYTES:
        logger.warning(
            "Audio chunk from %s for hive %s is %d bytes — ignoring",
            device_id,
            hive_id,
            len(payload),
        )
        payload = b""

    probability, evaluation = pipeline.process_audio(
        session=session,
        settings=settings,
        hive=hive,
        classifier=get_audio_classifier(settings),
        audio=payload,
        device_id=device_id,
        timestamp=timestamp,
    )

    return AudioResponse(
        hornet_probability=round(probability, 4),
        processed_at=datetime.utcnow(),
        status=evaluation.assessment.status,
        risk_score=evaluation.assessment.score_int,
    )


@router.post("/heartbeat", response_model=HeartbeatResponse)
def heartbeat(
    payload: HeartbeatRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> HeartbeatResponse:
    """Record that the monitoring phone is alive.

    A hive whose device stops sending these is reported as OFFLINE by every
    read endpoint after ``OFFLINE_AFTER_SECONDS``.
    """
    hive = get_hive_or_404(session, payload.hive_id)
    now = payload.timestamp or datetime.utcnow()

    # Same binding path as pairing and device registration, so a phone never
    # ends up with one row per hive it has ever watched.
    device = bind_device_to_hive(
        session,
        device_id=payload.device_id,
        hive_id=payload.hive_id,
    )

    device.last_heartbeat = now
    device.camera_ok = payload.camera_ok
    device.microphone_ok = payload.microphone_ok
    device.monitoring = payload.monitoring
    session.add(device)

    evaluation = hive_state.evaluate_hive(session, hive, settings, now=now)
    session.commit()

    return HeartbeatResponse(
        acknowledged=True,
        hive_id=hive.id,
        status=evaluation.assessment.status,
        risk_score=evaluation.assessment.score_int,
        server_time=datetime.utcnow(),
        next_heartbeat_seconds=settings.heartbeat_interval_seconds,
    )
