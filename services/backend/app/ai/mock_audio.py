"""Deterministic stand-in for a trained audio classifier.

There is no trained hornet-audio model yet, and the spec requires the whole
system to work without one.  This produces a stable, low-by-default
probability derived from the chunk's bytes, and — like the mock detector —
accepts a scripted sequence so the demo can drive the audio signal on cue.
"""

from __future__ import annotations

import hashlib
import threading

from app.ai.audio import AudioClassifier, AudioResult


class MockAudioClassifier(AudioClassifier):
    """An audio classifier that needs no model file."""

    name = "mock"

    #: The deterministic fallback stays inside this band, i.e. ambient noise.
    FALLBACK_MIN = 0.05
    FALLBACK_MAX = 0.35

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._scripts: dict[str, list[float]] = {}

    def push_script(self, hive_id: str, probabilities: list[float]) -> None:
        """Queue probabilities to be returned for the next chunks of a hive."""
        with self._lock:
            self._scripts.setdefault(hive_id, []).extend(probabilities)

    def clear_scripts(self) -> None:
        with self._lock:
            self._scripts.clear()

    def _next_scripted(self, hive_id: str | None) -> float | None:
        if hive_id is None:
            return None
        with self._lock:
            queue = self._scripts.get(hive_id)
            if not queue:
                return None
            return queue.pop(0)

    def classify(self, audio: bytes, hive_id: str | None = None) -> AudioResult:
        scripted = self._next_scripted(hive_id)
        if scripted is not None:
            return AudioResult(hornet_probability=scripted).clamped()

        digest = hashlib.sha256(audio if audio else b"silence").digest()
        # Map the first two digest bytes onto the ambient band.
        raw = int.from_bytes(digest[:2], "big") / 0xFFFF
        span = self.FALLBACK_MAX - self.FALLBACK_MIN
        return AudioResult(hornet_probability=self.FALLBACK_MIN + raw * span)
