"""Scripted demo scenario.

Real hornets cannot be brought to a competition venue, so the system must be
able to *replay* an attack on demand.  This module drives the exact same
pipeline the camera uses — the only difference is where the hornet counts come
from — which means what the judges see is the real risk engine and the real
alert state machine, not a hard-coded animation.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlmodel import Session, delete

from app.config import Settings
from app.models import Alert, AudioDetection, Hive, MonitoringDevice, VisionDetection
from app.notifications.sender import NotificationSender
from app.services import pipeline


@dataclass(frozen=True)
class ScenarioKeyframe:
    """A point in the scripted timeline."""

    offset_seconds: float
    hornet_count: int
    audio_probability: float


#: The scenario from the specification: a calm hive that is gradually
#: overwhelmed.  Audio rises alongside the visual count because a real mass
#: attack is audible before it is unmistakable on camera.
DEFAULT_SCENARIO: list[ScenarioKeyframe] = [
    ScenarioKeyframe(offset_seconds=0, hornet_count=0, audio_probability=0.05),
    ScenarioKeyframe(offset_seconds=5, hornet_count=1, audio_probability=0.10),
    ScenarioKeyframe(offset_seconds=10, hornet_count=2, audio_probability=0.20),
    ScenarioKeyframe(offset_seconds=15, hornet_count=4, audio_probability=0.30),
    ScenarioKeyframe(offset_seconds=20, hornet_count=6, audio_probability=0.85),
]


@dataclass(frozen=True)
class SimulationStep:
    """One replayed frame and the state it produced."""

    offset_seconds: float
    hornet_count: int
    audio_probability: float
    risk_score: int
    status: str
    alert_created: bool


@dataclass(frozen=True)
class SimulationResult:
    steps: list[SimulationStep]
    alerts_created: int
    notifications_sent: int


def clear_hive_history(session: Session, hive_id: str) -> tuple[int, int]:
    """Wipe a hive's observations and alerts so the demo is repeatable.

    Returns ``(detections_cleared, alerts_cleared)``.
    """
    vision = session.exec(
        delete(VisionDetection).where(VisionDetection.hive_id == hive_id)
    ).rowcount or 0
    audio = session.exec(
        delete(AudioDetection).where(AudioDetection.hive_id == hive_id)
    ).rowcount or 0
    alerts = session.exec(delete(Alert).where(Alert.hive_id == hive_id)).rowcount or 0

    hive = session.get(Hive, hive_id)
    if hive is not None:
        hive.status = hive.status.NORMAL
        hive.risk_score = 0
        hive.current_hornet_count = 0
        hive.max_hornet_count = 0
        hive.audio_probability = 0.0
        hive.latest_snapshot_path = None
        hive.last_analyzed_at = None
        session.add(hive)

    session.commit()
    return int(vision) + int(audio), int(alerts)


def expand_scenario(
    scenario: list[ScenarioKeyframe], frames_per_second: float
) -> list[ScenarioKeyframe]:
    """Fill the gaps between keyframes at the app's real frame rate.

    The monitoring phone uploads roughly one frame per second, so the Risk
    Engine normally sees a dense window.  Replaying only the five keyframes
    would starve the persistence and growth sub-scores and make the demo look
    less responsive than the real thing.
    """
    if frames_per_second <= 0 or not scenario:
        return list(scenario)

    step = 1.0 / frames_per_second
    expanded: list[ScenarioKeyframe] = []
    last = scenario[-1]

    for index, keyframe in enumerate(scenario):
        next_offset = (
            scenario[index + 1].offset_seconds
            if index + 1 < len(scenario)
            else keyframe.offset_seconds
        )
        offset = keyframe.offset_seconds
        # Hold this keyframe's values until the next one is due.
        while offset < next_offset - 1e-9:
            expanded.append(
                ScenarioKeyframe(
                    offset_seconds=offset,
                    hornet_count=keyframe.hornet_count,
                    audio_probability=keyframe.audio_probability,
                )
            )
            offset += step

    expanded.append(last)
    return expanded


def run_simulation(
    *,
    session: Session,
    settings: Settings,
    hive: Hive,
    sender: NotificationSender,
    scenario: list[ScenarioKeyframe] | None = None,
    frames_per_second: float = 1.0,
    include_audio: bool = True,
    reset_first: bool = True,
    now: datetime | None = None,
) -> SimulationResult:
    """Replay the scenario against one hive and report what happened.

    The timeline is laid down ending at ``now``, so the simulation completes
    instantly and leaves the hive in its final state — no sleeping, and the
    dashboard is immediately showing DANGER when the judges look at it.
    """
    scenario = scenario if scenario is not None else DEFAULT_SCENARIO
    now = now or datetime.utcnow()

    if reset_first:
        clear_hive_history(session, hive.id)
        session.refresh(hive)

    frames = expand_scenario(scenario, frames_per_second)
    if not frames:
        return SimulationResult(steps=[], alerts_created=0, notifications_sent=0)

    total_span = frames[-1].offset_seconds
    start = now - timedelta(seconds=total_span)

    # A hive with no heartbeat reads as OFFLINE, which would mask the whole
    # demo, so give it a live monitoring device for the duration of the replay.
    ensure_demo_heartbeat(session, hive.id, now)

    steps: list[SimulationStep] = []
    alerts_created = 0
    notifications_sent = 0

    for frame in frames:
        timestamp = start + timedelta(seconds=frame.offset_seconds)
        outcome = pipeline.record_observation(
            session=session,
            settings=settings,
            hive=hive,
            sender=sender,
            hornet_count=frame.hornet_count,
            timestamp=timestamp,
            audio_probability=frame.audio_probability if include_audio else None,
        )
        created = outcome.alert is not None
        if created:
            alerts_created += 1
            notifications_sent += outcome.notifications_sent

        steps.append(
            SimulationStep(
                offset_seconds=frame.offset_seconds,
                hornet_count=frame.hornet_count,
                audio_probability=frame.audio_probability if include_audio else 0.0,
                risk_score=outcome.evaluation.assessment.score_int,
                status=outcome.evaluation.assessment.status.value,
                alert_created=created,
            )
        )

    return SimulationResult(
        steps=steps,
        alerts_created=alerts_created,
        notifications_sent=notifications_sent,
    )


def ensure_demo_heartbeat(session: Session, hive_id: str, now: datetime) -> None:
    """Give the hive a live simulated monitoring device."""
    from sqlmodel import select

    device = session.exec(
        select(MonitoringDevice)
        .where(MonitoringDevice.hive_id == hive_id)
        .where(MonitoringDevice.device_identifier == "demo-simulator")
    ).first()

    if device is None:
        device = MonitoringDevice(
            hive_id=hive_id,
            device_identifier="demo-simulator",
        )

    device.last_heartbeat = now
    device.camera_ok = True
    device.microphone_ok = True
    device.monitoring = True
    session.add(device)
    session.commit()
