"""Audio classifier interface.

The contract is deliberately tiny: given an audio chunk, how likely is it that
hornets are present?  The Risk Engine fuses that probability with the vision
signal; it never sees the audio itself.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class AudioResult:
    """Outcome of analysing one audio chunk."""

    hornet_probability: float = 0.0

    def clamped(self) -> "AudioResult":
        return AudioResult(hornet_probability=max(0.0, min(1.0, self.hornet_probability)))


class AudioClassifier(ABC):
    """Estimates hornet presence from a short audio chunk."""

    name: str = "audio"

    @abstractmethod
    def classify(self, audio: bytes, hive_id: str | None = None) -> AudioResult:
        """Analyse raw audio bytes (m4a/wav/aac) and return a probability."""

    def close(self) -> None:  # pragma: no cover - default is a no-op
        """Release any model resources."""
