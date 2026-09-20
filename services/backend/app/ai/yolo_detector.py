"""Ultralytics YOLO adapter.

``ultralytics`` and the model weights are both optional.  The import happens
inside :meth:`YoloHornetDetector.__init__` so that a backend configured for
mock mode never pays for it, and a missing package or missing weight file
raises :class:`DetectorUnavailable` — which the factory catches and turns into
a fallback to the mock detector.  The service must start either way.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

from app.ai.detector import Detection, DetectionResult, HornetDetector
from app.config import Settings

logger = logging.getLogger(__name__)


class DetectorUnavailable(RuntimeError):
    """Raised when the real detector cannot be constructed."""


class YoloHornetDetector(HornetDetector):
    """Runs a trained YOLO model over incoming frames."""

    name = "yolo"

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._confidence = settings.yolo_confidence_threshold
        self._hornet_classes = settings.yolo_hornet_class_set

        model_path = settings.yolo_model_path.strip()
        if not model_path:
            raise DetectorUnavailable(
                "DETECTOR_MODE=yolo but YOLO_MODEL_PATH is empty. "
                "Point it at a .pt weight file."
            )
        if not Path(model_path).exists():
            raise DetectorUnavailable(f"YOLO weight file not found: {model_path}")

        try:
            from ultralytics import YOLO  # noqa: PLC0415 - deliberately lazy
        except ImportError as exc:  # pragma: no cover - depends on environment
            raise DetectorUnavailable(
                "ultralytics is not installed. Run: pip install -r requirements-ai.txt"
            ) from exc

        try:
            self._model = YOLO(model_path)
        except Exception as exc:  # pragma: no cover - depends on weight file
            raise DetectorUnavailable(f"Could not load YOLO model: {exc}") from exc

        logger.info("YOLO detector ready (weights=%s)", model_path)

    def detect(self, image: bytes, hive_id: str | None = None) -> DetectionResult:
        """Decode the frame and run inference.

        Any failure is downgraded to "no detections" rather than an exception:
        a single corrupt frame must never take the monitoring pipeline down.
        """
        frame = self._decode(image)
        if frame is None:
            return DetectionResult()

        try:
            results = self._model.predict(
                source=frame,
                conf=self._confidence,
                verbose=False,
            )
        except Exception as exc:  # pragma: no cover - depends on model
            logger.warning("YOLO inference failed: %s", exc)
            return DetectionResult()

        return DetectionResult.from_detections(self._extract(results))

    def _extract(self, results: Any) -> list[Detection]:
        """Convert ultralytics results into our own Detection objects."""
        detections: list[Detection] = []
        for result in results:
            names = getattr(result, "names", {}) or {}
            boxes = getattr(result, "boxes", None)
            if boxes is None:
                continue
            for box in boxes:
                try:
                    class_index = int(box.cls[0])
                    confidence = float(box.conf[0])
                    x1, y1, x2, y2 = (float(v) for v in box.xyxy[0])
                except (IndexError, TypeError, ValueError):  # pragma: no cover
                    continue

                class_name = str(names.get(class_index, class_index)).lower()
                # When the model was trained exclusively on hornets its single
                # class may be named anything; in that case accept everything.
                if self._hornet_classes and len(names) > 1:
                    if class_name not in self._hornet_classes:
                        continue

                detections.append(
                    Detection(
                        x1=x1,
                        y1=y1,
                        x2=x2,
                        y2=y2,
                        confidence=confidence,
                        class_name=class_name,
                    )
                )
        return detections

    @staticmethod
    def _decode(image: bytes) -> Any | None:
        """Decode JPEG/PNG bytes into a BGR numpy array."""
        try:
            import cv2  # noqa: PLC0415 - deliberately lazy
            import numpy as np  # noqa: PLC0415
        except ImportError:  # pragma: no cover - depends on environment
            logger.warning("opencv/numpy unavailable — cannot decode frame")
            return None

        buffer = np.frombuffer(image, dtype=np.uint8)
        if buffer.size == 0:
            return None
        frame = cv2.imdecode(buffer, cv2.IMREAD_COLOR)
        if frame is None:
            logger.warning("Received a frame that could not be decoded")
        return frame
