"""Vision detector interface.

Two implementations satisfy this contract — :class:`MockHornetDetector` and
:class:`YoloHornetDetector` — and the rest of the backend never learns which
one it is talking to.  Selecting between them is a config change.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Detection:
    """One detected hornet, in pixel coordinates of the analysed image."""

    x1: float
    y1: float
    x2: float
    y2: float
    confidence: float
    class_name: str = "hornet"

    def as_dict(self) -> dict[str, float | str]:
        return {
            "x1": round(self.x1, 2),
            "y1": round(self.y1, 2),
            "x2": round(self.x2, 2),
            "y2": round(self.y2, 2),
            "confidence": round(self.confidence, 4),
            "class_name": self.class_name,
        }


@dataclass(frozen=True)
class DetectionResult:
    """Outcome of analysing a single frame."""

    hornet_count: int = 0
    max_confidence: float = 0.0
    detections: list[Detection] = field(default_factory=list)
    annotated_image_path: str | None = None

    @classmethod
    def from_detections(
        cls,
        detections: list[Detection],
        annotated_image_path: str | None = None,
    ) -> "DetectionResult":
        return cls(
            hornet_count=len(detections),
            max_confidence=max((d.confidence for d in detections), default=0.0),
            detections=detections,
            annotated_image_path=annotated_image_path,
        )


class HornetDetector(ABC):
    """Detects hornets in a single image."""

    #: Human-readable name reported by ``GET /health`` so the demo operator can
    #: confirm at a glance which detector is live.
    name: str = "detector"

    @abstractmethod
    def detect(self, image: bytes, hive_id: str | None = None) -> DetectionResult:
        """Analyse raw image bytes (JPEG/PNG) and return the detections.

        ``hive_id`` is passed for context only.  Real detectors ignore it;
        the mock uses it to look up a scripted demo scenario.
        """

    def close(self) -> None:  # pragma: no cover - default is a no-op
        """Release any model resources.  Overridden where it matters."""
