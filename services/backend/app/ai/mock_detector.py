"""Deterministic stand-in for a trained hornet detector.

This is what makes the whole pipeline runnable with no model weights at all.
It has two behaviours:

* **Scripted** — when a scenario has been pushed for a hive (by the demo
  endpoints), the next queued count is returned.  This is how the competition
  demo drives a reproducible NORMAL → CAUTION → DANGER progression.
* **Deterministic fallback** — otherwise the count is derived from a hash of
  the image bytes, so the same frame always yields the same answer and the
  numbers move around a little as the scene changes.  It never invents a
  large swarm out of nowhere, which would make the demo confusing.
"""

from __future__ import annotations

import hashlib
import random
import threading

from app.ai.detector import Detection, DetectionResult, HornetDetector


class MockHornetDetector(HornetDetector):
    """A detector that needs no model file."""

    name = "mock"

    #: Counts above this are never produced by the deterministic fallback.
    FALLBACK_MAX_COUNT = 2

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._scripts: dict[str, list[int]] = {}

    # ------------------------------------------------------------------
    # Scenario scripting (used by the demo endpoints)
    # ------------------------------------------------------------------
    def push_script(self, hive_id: str, counts: list[int]) -> None:
        """Queue hornet counts to be returned for the next frames of a hive."""
        with self._lock:
            self._scripts.setdefault(hive_id, []).extend(counts)

    def clear_scripts(self) -> None:
        with self._lock:
            self._scripts.clear()

    def _next_scripted_count(self, hive_id: str | None) -> int | None:
        if hive_id is None:
            return None
        with self._lock:
            queue = self._scripts.get(hive_id)
            if not queue:
                return None
            return queue.pop(0)

    # ------------------------------------------------------------------
    # Detection
    # ------------------------------------------------------------------
    def detect(self, image: bytes, hive_id: str | None = None) -> DetectionResult:
        count = self._next_scripted_count(hive_id)
        seed_source = image if image else b"empty"
        digest = hashlib.sha256(seed_source).digest()
        rng = random.Random(digest)

        if count is None:
            # Weighted so "nothing there" is the common case.
            count = rng.choices(
                population=list(range(self.FALLBACK_MAX_COUNT + 1)),
                weights=[70, 22, 8],
                k=1,
            )[0]

        detections = [self._fake_box(rng) for _ in range(max(0, count))]
        return DetectionResult.from_detections(detections)

    @staticmethod
    def _fake_box(rng: random.Random) -> Detection:
        """A plausible bounding box so the mobile UI has something to draw."""
        width = rng.uniform(40, 90)
        height = rng.uniform(30, 70)
        x1 = rng.uniform(0, 640 - width)
        y1 = rng.uniform(0, 480 - height)
        return Detection(
            x1=x1,
            y1=y1,
            x2=x1 + width,
            y2=y1 + height,
            confidence=rng.uniform(0.55, 0.95),
            class_name="hornet",
        )
