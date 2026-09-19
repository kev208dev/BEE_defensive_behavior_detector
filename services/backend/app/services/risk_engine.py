"""Risk Engine — turns a short history of observations into a 0-100 risk score.

Design rules
------------
* **Pure.**  This module imports no AI library, no database and no web
  framework.  It takes plain dataclasses in and returns a plain dataclass out,
  which is what makes it cheap to unit-test and to re-tune.
* **Config-driven.**  Every weight, saturation point and threshold comes from
  :class:`app.config.Settings`.  Nothing is hard-coded.

Scoring model
-------------
The score is a weighted sum of four sub-scores, each normalised to 0-100:

``visual_count``
    How many hornets are visible right now, blended with the recent maximum so
    that a single dropped frame does not collapse the score.
``persistence``
    What fraction of the recent frames contained hornets.  Gated by
    ``persistence_min_frames`` so one isolated sighting scores near zero — this
    is what keeps a lone scout hornet from tripping a DANGER alert.
``growth``
    How fast the hornet count is rising (hornets/second), comparing the first
    half of the window against the second half.  A mass attack builds up.
``audio``
    The hornet probability reported by the audio classifier.

.. warning::
   The default weights and thresholds are **MVP validation heuristics**, not
   scientifically validated criteria for a real hornet mass attack.  They were
   chosen so that the demonstration scenario produces a legible NORMAL →
   CAUTION → DANGER progression.  A field deployment must re-derive them from
   real observational data.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta

from app.config import Settings
from app.enums import HiveStatus

__all__ = [
    "Observation",
    "RiskBreakdown",
    "RiskAssessment",
    "evaluate_risk",
    "resolve_status",
    "is_offline",
]


@dataclass(frozen=True)
class Observation:
    """A single vision observation — one analysed frame."""

    timestamp: datetime
    hornet_count: int
    max_confidence: float = 0.0


@dataclass(frozen=True)
class RiskBreakdown:
    """Per-component contribution, kept for explanation and debugging."""

    visual_count_score: float = 0.0
    persistence_score: float = 0.0
    growth_score: float = 0.0
    audio_score: float = 0.0

    # Raw observable facts behind the sub-scores, surfaced in the UI.
    current_hornet_count: int = 0
    recent_max_hornet_count: int = 0
    persistence_ratio: float = 0.0
    growth_per_second: float = 0.0
    audio_probability: float = 0.0
    frames_considered: int = 0

    def as_dict(self) -> dict[str, float]:
        return {
            "visual_count_score": round(self.visual_count_score, 2),
            "persistence_score": round(self.persistence_score, 2),
            "growth_score": round(self.growth_score, 2),
            "audio_score": round(self.audio_score, 2),
            "current_hornet_count": self.current_hornet_count,
            "recent_max_hornet_count": self.recent_max_hornet_count,
            "persistence_ratio": round(self.persistence_ratio, 3),
            "growth_per_second": round(self.growth_per_second, 3),
            "audio_probability": round(self.audio_probability, 3),
            "frames_considered": self.frames_considered,
        }


@dataclass(frozen=True)
class RiskAssessment:
    """Result of one Risk Engine evaluation."""

    score: float
    status: HiveStatus
    breakdown: RiskBreakdown = field(default_factory=RiskBreakdown)

    @property
    def score_int(self) -> int:
        """Score rounded to an integer, which is what the API returns."""
        return int(round(self.score))


def _clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def _saturating(value: float, saturation: float) -> float:
    """Map ``value`` onto 0-100, reaching 100 at ``saturation``."""
    if saturation <= 0:
        return 100.0 if value > 0 else 0.0
    return _clamp(value / saturation) * 100.0


def _visual_count_score(
    observations: list[Observation], settings: Settings
) -> tuple[float, int, int]:
    """Blend the current count with the recent maximum count."""
    if not observations:
        return 0.0, 0, 0

    current = observations[-1].hornet_count
    recent_max = max(obs.hornet_count for obs in observations)

    blend = _clamp(settings.recent_max_blend)
    effective = (1.0 - blend) * current + blend * recent_max
    return _saturating(effective, settings.count_saturation), current, recent_max


def _persistence_score(
    observations: list[Observation], settings: Settings
) -> tuple[float, float]:
    """Fraction of recent frames containing hornets, gated by frame count.

    The gate is what separates "a hornet flew past once" from "hornets are
    camped in front of the hive".  With ``persistence_min_frames = 3``, one
    sighting scores a third of its raw ratio, two sightings two thirds, and
    three or more score the full ratio.
    """
    total = len(observations)
    if total == 0:
        return 0.0, 0.0

    detected = sum(1 for obs in observations if obs.hornet_count > 0)
    if detected == 0:
        return 0.0, 0.0

    ratio = detected / total
    min_frames = max(1, settings.persistence_min_frames)
    gate = _clamp(detected / min_frames)
    return ratio * gate * 100.0, ratio


def _growth_score(
    observations: list[Observation], settings: Settings
) -> tuple[float, float]:
    """Rate of increase in hornet count, in hornets per second.

    Compares the mean count of the first half of the window against the mean
    of the second half, measured between the midpoints of the two halves.
    Only growth counts; a falling count scores zero rather than negative.
    """
    if len(observations) < 2:
        return 0.0, 0.0

    midpoint = len(observations) // 2
    first, second = observations[:midpoint], observations[midpoint:]
    if not first or not second:
        return 0.0, 0.0

    def mean_count(items: list[Observation]) -> float:
        return sum(obs.hornet_count for obs in items) / len(items)

    def mean_time(items: list[Observation]) -> float:
        return sum(obs.timestamp.timestamp() for obs in items) / len(items)

    elapsed = mean_time(second) - mean_time(first)
    if elapsed <= 0:
        return 0.0, 0.0

    rate = (mean_count(second) - mean_count(first)) / elapsed
    if rate <= 0:
        return 0.0, 0.0

    return _saturating(rate, settings.growth_saturation), rate


def evaluate_risk(
    observations: list[Observation],
    settings: Settings,
    *,
    audio_probability: float = 0.0,
    now: datetime | None = None,
) -> RiskAssessment:
    """Compute the risk score for one hive.

    Args:
        observations: Vision observations, any order; only those inside the
            configured window are used.
        settings: Weights, saturation points and thresholds.
        audio_probability: Hornet probability from the audio classifier, 0-1.
            Pass ``0.0`` when there is no recent audio — the audio component
            then simply contributes nothing.
        now: Evaluation time, defaulting to the newest observation (or the
            current time when there are no observations).  Injectable so tests
            are deterministic.

    Returns:
        A :class:`RiskAssessment` carrying the score, the derived status and
        the per-component breakdown.
    """
    ordered = sorted(observations, key=lambda obs: obs.timestamp)
    if now is None:
        now = ordered[-1].timestamp if ordered else datetime.utcnow()

    cutoff = now - timedelta(seconds=settings.risk_window_seconds)
    window = [obs for obs in ordered if obs.timestamp >= cutoff]

    visual, current, recent_max = _visual_count_score(window, settings)
    persistence, persistence_ratio = _persistence_score(window, settings)
    growth, growth_rate = _growth_score(window, settings)
    audio_prob = _clamp(audio_probability)
    audio = audio_prob * 100.0

    score = (
        visual * settings.weight_visual_count
        + persistence * settings.weight_persistence
        + growth * settings.weight_growth
        + audio * settings.weight_audio
    )
    score = _clamp(score, 0.0, 100.0)

    breakdown = RiskBreakdown(
        visual_count_score=visual,
        persistence_score=persistence,
        growth_score=growth,
        audio_score=audio,
        current_hornet_count=current,
        recent_max_hornet_count=recent_max,
        persistence_ratio=persistence_ratio,
        growth_per_second=growth_rate,
        audio_probability=audio_prob,
        frames_considered=len(window),
    )
    return RiskAssessment(
        score=score,
        status=classify(score, settings),
        breakdown=breakdown,
    )


def classify(score: float, settings: Settings) -> HiveStatus:
    """Map a 0-100 score onto NORMAL / CAUTION / DANGER."""
    if score >= settings.danger_threshold:
        return HiveStatus.DANGER
    if score >= settings.caution_threshold:
        return HiveStatus.CAUTION
    return HiveStatus.NORMAL


def is_offline(
    last_heartbeat: datetime | None, settings: Settings, now: datetime | None = None
) -> bool:
    """True when the monitoring phone has gone quiet for too long.

    A hive that has never sent a heartbeat is considered offline.
    """
    if last_heartbeat is None:
        return True
    now = now or datetime.utcnow()
    return (now - last_heartbeat).total_seconds() > settings.offline_after_seconds


def resolve_status(
    score: float,
    settings: Settings,
    *,
    last_heartbeat: datetime | None = None,
    now: datetime | None = None,
) -> HiveStatus:
    """Status shown to the user, with device liveness taking precedence.

    OFFLINE is not a threat level — it means we can no longer see the hive, so
    it overrides whatever the last computed score happened to be.
    """
    if is_offline(last_heartbeat, settings, now):
        return HiveStatus.OFFLINE
    return classify(score, settings)
