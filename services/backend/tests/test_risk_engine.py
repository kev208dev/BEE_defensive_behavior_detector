"""Risk Engine behaviour tests.

These assert *behaviour*, not specific numbers: that the engine stays calm
when it should, escalates when it should, and that each input moves the score
in the right direction.  The thresholds themselves are tunable configuration,
so pinning exact scores would make the suite brittle without making it
stronger.  Where a threshold is unavoidable the test compares against
``settings.danger_threshold`` rather than a literal.
"""

from __future__ import annotations

from datetime import datetime, timedelta

import pytest

from app.config import Settings
from app.enums import HiveStatus
from app.services.risk_engine import (
    Observation,
    evaluate_risk,
    is_offline,
    resolve_status,
)


def build(
    base: datetime, counts: list[int], step_seconds: float = 1.0
) -> list[Observation]:
    """Observations with ``counts`` spaced ``step_seconds`` apart."""
    return [
        Observation(timestamp=base + timedelta(seconds=i * step_seconds), hornet_count=c)
        for i, c in enumerate(counts)
    ]


# ----------------------------------------------------------------------
# Case 1 — no hornets at all must be NORMAL
# ----------------------------------------------------------------------


def test_no_hornets_is_normal(settings: Settings, base_time: datetime) -> None:
    result = evaluate_risk(build(base_time, [0] * 10), settings)

    assert result.status is HiveStatus.NORMAL
    assert result.score == pytest.approx(0.0)
    assert result.breakdown.current_hornet_count == 0


def test_no_observations_is_normal(settings: Settings) -> None:
    """A hive that has never reported anything is not dangerous, just silent."""
    result = evaluate_risk([], settings)

    assert result.status is HiveStatus.NORMAL
    assert result.score == pytest.approx(0.0)
    assert result.breakdown.frames_considered == 0


# ----------------------------------------------------------------------
# Case 2 — a single hornet passing through must not raise DANGER
# ----------------------------------------------------------------------


def test_single_brief_hornet_does_not_reach_danger(
    settings: Settings, base_time: datetime
) -> None:
    """One scout hornet is normal beekeeping, not a mass attack."""
    result = evaluate_risk(build(base_time, [0] * 9 + [1]), settings)

    assert result.status is not HiveStatus.DANGER
    assert result.score < settings.danger_threshold


def test_single_hornet_that_leaves_decays(
    settings: Settings, base_time: datetime
) -> None:
    """Once the hornet is gone the score must fall, not stay latched high."""
    while_present = evaluate_risk(build(base_time, [0] * 5 + [1]), settings)
    after_leaving = evaluate_risk(build(base_time, [0] * 5 + [1] + [0] * 6), settings)

    assert after_leaving.score < while_present.score
    assert after_leaving.status is not HiveStatus.DANGER


def test_isolated_sighting_scores_below_sustained_presence(
    settings: Settings, base_time: datetime
) -> None:
    """The persistence gate is what separates a fly-past from an occupation."""
    isolated = evaluate_risk(build(base_time, [0, 0, 0, 0, 0, 0, 0, 0, 0, 3]), settings)
    sustained = evaluate_risk(build(base_time, [3] * 10), settings)

    assert isolated.score < sustained.score
    assert isolated.breakdown.persistence_score < sustained.breakdown.persistence_score


# ----------------------------------------------------------------------
# Case 3 — 3-5 hornets present across many frames must escalate
# ----------------------------------------------------------------------


@pytest.mark.parametrize("count", [3, 4, 5])
def test_sustained_hornets_reach_caution_or_danger(
    settings: Settings, base_time: datetime, count: int
) -> None:
    result = evaluate_risk(build(base_time, [count] * 12), settings)

    assert result.status in (HiveStatus.CAUTION, HiveStatus.DANGER)
    assert result.score >= settings.caution_threshold


def test_sustained_risk_increases_with_hornet_count(
    settings: Settings, base_time: datetime
) -> None:
    """More hornets must never score lower than fewer hornets."""
    scores = [
        evaluate_risk(build(base_time, [count] * 12), settings).score
        for count in (1, 2, 3, 4, 5, 6)
    ]

    assert scores == sorted(scores)
    assert scores[-1] > scores[0]


# ----------------------------------------------------------------------
# Case 4 — a rapid increase in hornet count must raise the risk
# ----------------------------------------------------------------------


def test_rapid_growth_increases_risk(
    settings: Settings, base_time: datetime
) -> None:
    """A hive going from empty to swarming outranks one that was always busy.

    Both windows end at the same hornet count, so anything the surge scores
    above the flat case comes from the growth component.
    """
    flat = evaluate_risk(build(base_time, [4] * 8), settings)
    surge = evaluate_risk(build(base_time, [0, 0, 1, 1, 2, 3, 4, 4]), settings)

    assert surge.breakdown.growth_score > flat.breakdown.growth_score
    assert surge.breakdown.growth_per_second > 0


def test_faster_growth_scores_higher_than_slower_growth(
    settings: Settings, base_time: datetime
) -> None:
    slow = evaluate_risk(build(base_time, [0, 0, 0, 1, 1, 1, 2, 2]), settings)
    fast = evaluate_risk(build(base_time, [0, 0, 0, 2, 4, 6, 8, 8]), settings)

    assert fast.breakdown.growth_per_second > slow.breakdown.growth_per_second
    assert fast.score > slow.score


def test_falling_count_does_not_produce_growth_score(
    settings: Settings, base_time: datetime
) -> None:
    """A retreating swarm must not be scored as if it were advancing."""
    result = evaluate_risk(build(base_time, [6, 5, 4, 3, 2, 1, 0, 0]), settings)

    assert result.breakdown.growth_score == pytest.approx(0.0)
    assert result.breakdown.growth_per_second == pytest.approx(0.0)


# ----------------------------------------------------------------------
# Case 5 — visual and audio signals together must raise the risk
# ----------------------------------------------------------------------


def test_audio_and_visual_together_exceed_either_alone(
    settings: Settings, base_time: datetime
) -> None:
    observations = build(base_time, [4] * 12)

    visual_only = evaluate_risk(observations, settings, audio_probability=0.0)
    with_audio = evaluate_risk(observations, settings, audio_probability=0.9)
    audio_only = evaluate_risk(build(base_time, [0] * 12), settings, audio_probability=0.9)

    assert with_audio.score > visual_only.score
    assert with_audio.score > audio_only.score


def test_audio_alone_does_not_reach_danger(
    settings: Settings, base_time: datetime
) -> None:
    """Sound by itself is corroboration, not proof — a noisy day is not an attack."""
    result = evaluate_risk(
        build(base_time, [0] * 12), settings, audio_probability=1.0
    )

    assert result.status is not HiveStatus.DANGER


def test_risk_increases_monotonically_with_audio_probability(
    settings: Settings, base_time: datetime
) -> None:
    observations = build(base_time, [3] * 12)
    scores = [
        evaluate_risk(observations, settings, audio_probability=p).score
        for p in (0.0, 0.25, 0.5, 0.75, 1.0)
    ]

    assert scores == sorted(scores)


def test_score_is_clamped_to_range(settings: Settings, base_time: datetime) -> None:
    result = evaluate_risk(
        build(base_time, [0, 5, 20, 60, 120]), settings, audio_probability=1.0
    )

    assert 0.0 <= result.score <= 100.0


# ----------------------------------------------------------------------
# Case 6 — a missing heartbeat must report OFFLINE
# ----------------------------------------------------------------------


def test_missing_heartbeat_is_offline(settings: Settings, base_time: datetime) -> None:
    assert is_offline(None, settings, base_time) is True
    assert resolve_status(0.0, settings, last_heartbeat=None, now=base_time) is (
        HiveStatus.OFFLINE
    )


def test_stale_heartbeat_is_offline(settings: Settings, base_time: datetime) -> None:
    stale = base_time - timedelta(seconds=settings.offline_after_seconds + 5)

    assert is_offline(stale, settings, base_time) is True
    assert resolve_status(
        0.0, settings, last_heartbeat=stale, now=base_time
    ) is HiveStatus.OFFLINE


def test_recent_heartbeat_is_online(settings: Settings, base_time: datetime) -> None:
    fresh = base_time - timedelta(seconds=settings.offline_after_seconds / 2)

    assert is_offline(fresh, settings, base_time) is False
    assert resolve_status(
        0.0, settings, last_heartbeat=fresh, now=base_time
    ) is HiveStatus.NORMAL


def test_offline_overrides_a_dangerous_score(
    settings: Settings, base_time: datetime
) -> None:
    """We cannot claim DANGER for a hive we can no longer see."""
    status = resolve_status(
        99.0, settings, last_heartbeat=None, now=base_time
    )

    assert status is HiveStatus.OFFLINE


# ----------------------------------------------------------------------
# Window and configuration behaviour
# ----------------------------------------------------------------------


def test_observations_outside_the_window_are_ignored(
    settings: Settings, base_time: datetime
) -> None:
    ancient = base_time - timedelta(seconds=settings.risk_window_seconds + 60)
    observations = [
        Observation(timestamp=ancient, hornet_count=50),
        Observation(timestamp=base_time, hornet_count=0),
    ]

    result = evaluate_risk(observations, settings, now=base_time)

    assert result.breakdown.frames_considered == 1
    assert result.breakdown.recent_max_hornet_count == 0
    assert result.status is HiveStatus.NORMAL


def test_thresholds_are_configurable(base_time: datetime) -> None:
    """Lowering the thresholds must change the verdict, not just the number."""
    observations = build(base_time, [2] * 10)

    strict = Settings(caution_threshold=5.0, danger_threshold=10.0, seed_on_startup=False)
    lenient = Settings(
        caution_threshold=95.0, danger_threshold=99.0, seed_on_startup=False
    )

    assert evaluate_risk(observations, strict).status is HiveStatus.DANGER
    assert evaluate_risk(observations, lenient).status is HiveStatus.NORMAL


def test_weights_are_configurable(base_time: datetime) -> None:
    """Zeroing the audio weight must remove audio's influence entirely."""
    observations = build(base_time, [3] * 10)
    no_audio_weight = Settings(weight_audio=0.0, seed_on_startup=False)

    silent = evaluate_risk(observations, no_audio_weight, audio_probability=0.0)
    loud = evaluate_risk(observations, no_audio_weight, audio_probability=1.0)

    assert silent.score == pytest.approx(loud.score)


def test_unordered_observations_are_handled(
    settings: Settings, base_time: datetime
) -> None:
    """Frames can arrive out of order over a flaky network."""
    ordered = build(base_time, [0, 1, 2, 3, 4])
    shuffled = [ordered[3], ordered[0], ordered[4], ordered[1], ordered[2]]

    assert evaluate_risk(shuffled, settings, now=ordered[-1].timestamp).score == (
        pytest.approx(evaluate_risk(ordered, settings, now=ordered[-1].timestamp).score)
    )
