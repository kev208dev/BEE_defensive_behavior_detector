"""Builds the configured AI adapters, always degrading to mock on failure.

This is the single place that decides which detector and which audio
classifier the backend runs with.  The guarantee it provides is the one the
spec calls for: **the backend starts even with no YOLO weights, no audio model
and no optional dependencies installed.**
"""

from __future__ import annotations

import logging

from app.ai.audio import AudioClassifier
from app.ai.detector import HornetDetector
from app.ai.mock_audio import MockAudioClassifier
from app.ai.mock_detector import MockHornetDetector
from app.config import AudioModelMode, DetectorMode, Settings

logger = logging.getLogger(__name__)

_detector: HornetDetector | None = None
_audio_classifier: AudioClassifier | None = None


def build_detector(settings: Settings) -> HornetDetector:
    """Construct the detector named by ``DETECTOR_MODE``."""
    if settings.detector_mode is DetectorMode.YOLO:
        try:
            from app.ai.yolo_detector import DetectorUnavailable, YoloHornetDetector

            return YoloHornetDetector(settings)
        except Exception as exc:  # noqa: BLE001 - any failure must degrade
            logger.warning(
                "YOLO detector unavailable (%s). Falling back to the mock detector.",
                exc,
            )
    return MockHornetDetector()


def build_audio_classifier(settings: Settings) -> AudioClassifier:
    """Construct the classifier named by ``AUDIO_MODEL_MODE``."""
    if settings.audio_model_mode is AudioModelMode.LIBROSA:
        try:
            from app.ai.librosa_audio import LibrosaAudioClassifier

            return LibrosaAudioClassifier(settings)
        except Exception as exc:  # noqa: BLE001 - any failure must degrade
            logger.warning(
                "librosa audio classifier unavailable (%s). "
                "Falling back to the mock classifier.",
                exc,
            )
    return MockAudioClassifier()


def get_detector(settings: Settings) -> HornetDetector:
    """Return the process-wide detector, building it on first use."""
    global _detector
    if _detector is None:
        _detector = build_detector(settings)
        logger.info("Vision detector: %s", _detector.name)
    return _detector


def get_audio_classifier(settings: Settings) -> AudioClassifier:
    """Return the process-wide audio classifier, building it on first use."""
    global _audio_classifier
    if _audio_classifier is None:
        _audio_classifier = build_audio_classifier(settings)
        logger.info("Audio classifier: %s", _audio_classifier.name)
    return _audio_classifier


def reset() -> None:
    """Drop the cached adapters — used by tests and by ``/api/demo/reset``."""
    global _detector, _audio_classifier
    for adapter in (_detector, _audio_classifier):
        if adapter is not None:
            try:
                adapter.close()
            except Exception:  # noqa: BLE001 - teardown must not raise
                logger.debug("Adapter close() failed", exc_info=True)
    _detector = None
    _audio_classifier = None
