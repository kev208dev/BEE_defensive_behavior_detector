"""The analysis pipeline: frame in → detection → risk → alert → notification.

Both the real monitoring endpoints and the demo simulation go through here,
so the demo exercises the same code path the competition will run on.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from sqlmodel import Session

from app.ai.audio import AudioClassifier
from app.ai.detector import DetectionResult, HornetDetector
from app.config import Settings
from app.models import Alert, AudioDetection, Hive, VisionDetection
from app.notifications.sender import NotificationSender
from app.services import hive_state
from app.services.alert_manager import dispatch_notification, evaluate_alert

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class FrameOutcome:
    """Everything the caller needs to build a response or a demo step."""

    detection: DetectionResult
    evaluation: hive_state.HiveEvaluation
    alert: Alert | None
    alert_reason: str
    notifications_sent: int
    snapshot_path: str | None


def store_snapshot(image: bytes, hive_id: str, settings: Settings) -> str | None:
    """Persist the uploaded frame so the alert can show what was seen.

    Returns the stored path, or ``None`` when the write fails — a snapshot is
    useful, not essential, and must never fail the analysis.
    """
    if not image:
        return None
    try:
        snapshot_dir = Path(settings.snapshot_dir)
        snapshot_dir.mkdir(parents=True, exist_ok=True)
        filename = f"{hive_id}_{datetime.utcnow():%Y%m%d%H%M%S}_{uuid.uuid4().hex[:8]}.jpg"
        path = snapshot_dir / filename
        path.write_bytes(image)
        return str(path)
    except OSError as exc:
        logger.warning("Could not store snapshot for hive %s: %s", hive_id, exc)
        return None


def process_frame(
    *,
    session: Session,
    settings: Settings,
    hive: Hive,
    detector: HornetDetector,
    sender: NotificationSender,
    image: bytes,
    device_id: str | None = None,
    timestamp: datetime | None = None,
    store_image: bool = True,
) -> FrameOutcome:
    """Analyse one frame and advance the hive's state.

    The detector is called first, its result is appended to the history, and
    only then is the Risk Engine re-run over that history — so the score
    always reflects the frame that was just uploaded.
    """
    now = timestamp or datetime.utcnow()

    try:
        detection = detector.detect(image, hive.id)
    except Exception as exc:  # noqa: BLE001 - a bad frame must not break monitoring
        logger.warning("Detector failed on a frame for hive %s: %s", hive.id, exc)
        detection = DetectionResult()

    snapshot_path = store_snapshot(image, hive.id, settings) if store_image else None

    return process_detection_observation(
        session=session,
        settings=settings,
        hive=hive,
        sender=sender,
        detection=detection,
        device_id=device_id,
        timestamp=now,
        snapshot_path=snapshot_path,
    )


def process_detection_observation(
    *,
    session: Session,
    settings: Settings,
    hive: Hive,
    sender: NotificationSender,
    detection: DetectionResult,
    device_id: str | None = None,
    timestamp: datetime | None = None,
    snapshot_path: str | None = None,
) -> FrameOutcome:
    """Persist a detection and run the shared risk/alert pipeline.

    The legacy frame endpoint performs backend inference before entering here;
    the observation endpoint enters with inference already completed on the
    phone. Both therefore produce identical history, growth, fusion and alert
    behaviour.
    """
    now = timestamp or datetime.utcnow()

    session.add(
        VisionDetection(
            hive_id=hive.id,
            device_id=device_id,
            timestamp=now,
            hornet_count=detection.hornet_count,
            max_confidence=detection.max_confidence,
            snapshot_path=snapshot_path,
        )
    )
    session.flush()

    if snapshot_path:
        hive.latest_snapshot_path = snapshot_path

    return _advance_state(
        session=session,
        settings=settings,
        hive=hive,
        sender=sender,
        now=now,
        detection=detection,
        snapshot_path=snapshot_path,
    )


def process_audio(
    *,
    session: Session,
    settings: Settings,
    hive: Hive,
    classifier: AudioClassifier,
    audio: bytes,
    device_id: str | None = None,
    timestamp: datetime | None = None,
) -> tuple[float, hive_state.HiveEvaluation]:
    """Analyse one audio chunk and refresh the fused risk score.

    Audio does not raise alerts on its own — it feeds the Risk Engine, and the
    next frame (or this same refresh) decides.  Returning the refreshed
    evaluation lets the monitoring phone display the fused score immediately.
    """
    now = timestamp or datetime.utcnow()

    try:
        result = classifier.classify(audio, hive.id)
        probability = result.clamped().hornet_probability
    except Exception as exc:  # noqa: BLE001 - a bad chunk must not break monitoring
        logger.warning("Audio classifier failed for hive %s: %s", hive.id, exc)
        probability = 0.0

    session.add(
        AudioDetection(
            hive_id=hive.id,
            device_id=device_id,
            timestamp=now,
            hornet_probability=probability,
        )
    )
    session.flush()

    evaluation = hive_state.evaluate_hive(session, hive, settings, now=now)
    hive.audio_updated_at = now
    session.add(hive)
    session.commit()
    return probability, evaluation


def record_observation(
    *,
    session: Session,
    settings: Settings,
    hive: Hive,
    sender: NotificationSender,
    hornet_count: int,
    timestamp: datetime,
    max_confidence: float = 0.9,
    audio_probability: float | None = None,
) -> FrameOutcome:
    """Inject a synthetic observation — the demo simulation's entry point.

    Deliberately shares :func:`_advance_state` with the real frame path so a
    simulated attack exercises the identical risk and alert logic.
    """
    if audio_probability is not None:
        session.add(
            AudioDetection(
                hive_id=hive.id,
                device_id="demo-simulator",
                timestamp=timestamp,
                hornet_probability=audio_probability,
            )
        )
    detection = DetectionResult(
        hornet_count=hornet_count,
        max_confidence=max_confidence if hornet_count else 0.0,
    )
    return process_detection_observation(
        session=session,
        settings=settings,
        hive=hive,
        sender=sender,
        detection=detection,
        device_id="demo-simulator",
        timestamp=timestamp,
        snapshot_path=hive.latest_snapshot_path,
    )


def _advance_state(
    *,
    session: Session,
    settings: Settings,
    hive: Hive,
    sender: NotificationSender,
    now: datetime,
    detection: DetectionResult,
    snapshot_path: str | None,
) -> FrameOutcome:
    """Re-run the Risk Engine, run the alert state machine, commit."""
    from app.api.mappers import snapshot_url  # local import avoids a cycle

    evaluation = hive_state.evaluate_hive(session, hive, settings, now=now)

    decision = evaluate_alert(
        session=session,
        hive=hive,
        previous_status=evaluation.previous_status,
        assessment=evaluation.assessment,
        settings=settings,
        now=now,
        snapshot_url=snapshot_url(snapshot_path, settings),
    )

    notified = 0
    if decision.created and decision.alert is not None:
        notified = dispatch_notification(session, decision.alert, hive, sender)

    session.commit()
    if decision.alert is not None:
        session.refresh(decision.alert)

    return FrameOutcome(
        detection=detection,
        evaluation=evaluation,
        alert=decision.alert if decision.created else None,
        alert_reason=decision.reason,
        notifications_sent=notified,
        snapshot_path=snapshot_path,
    )
