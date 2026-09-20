"""Alert state machine tests — the duplicate-prevention contract.

At one frame per second, a hive left in DANGER would generate an alert every
second without this machine.  These tests pin the behaviour that stops it.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlmodel import Session, select

from app.config import Settings
from app.enums import AlertSeverity, HiveStatus
from app.models import Alert, Hive, PushDevice
from app.notifications.console import ConsoleNotificationSender
from app.services.alert_manager import (
    dispatch_notification,
    evaluate_alert,
    severity_for_status,
)
from app.services.risk_engine import RiskAssessment, RiskBreakdown


def assessment_for(status: HiveStatus, score: float = 80.0) -> RiskAssessment:
    """A minimal assessment carrying the status the machine reacts to."""
    return RiskAssessment(
        score=score,
        status=status,
        breakdown=RiskBreakdown(
            current_hornet_count=6,
            recent_max_hornet_count=7,
            persistence_ratio=0.8,
            growth_per_second=0.3,
            audio_probability=0.7,
            visual_count_score=90.0,
            persistence_score=80.0,
            growth_score=75.0,
            audio_score=70.0,
            frames_considered=20,
        ),
    )


def alert_count(session: Session, hive_id: str) -> int:
    return len(session.exec(select(Alert).where(Alert.hive_id == hive_id)).all())


# ----------------------------------------------------------------------
# Rule 1 — escalation only
# ----------------------------------------------------------------------


def test_escalation_to_danger_creates_an_alert(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    decision = evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.DANGER),
        settings, now=base_time,
    )
    session.commit()

    assert decision.created is True
    assert decision.alert is not None
    assert decision.alert.severity is AlertSeverity.DANGER
    assert decision.alert.message
    assert decision.alert.explanation


def test_sustained_danger_creates_only_one_alert(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """Sixty frames of DANGER is one attack, not sixty."""
    first = evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.DANGER),
        settings, now=base_time,
    )
    session.commit()

    for second in range(1, 60):
        evaluate_alert(
            session,
            hive,
            HiveStatus.DANGER,  # status is already DANGER — same episode
            assessment_for(HiveStatus.DANGER),
            settings,
            now=base_time + timedelta(seconds=second),
        )
    session.commit()

    assert first.created is True
    assert alert_count(session, hive.id) == 1


def test_normal_status_never_alerts(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    decision = evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.NORMAL, 5.0),
        settings, now=base_time,
    )

    assert decision.created is False
    assert alert_count(session, hive.id) == 0


def test_de_escalation_never_alerts(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """Coming *down* from DANGER to CAUTION is good news, not a new alert."""
    decision = evaluate_alert(
        session, hive, HiveStatus.DANGER, assessment_for(HiveStatus.CAUTION, 50.0),
        settings, now=base_time,
    )

    assert decision.created is False
    assert alert_count(session, hive.id) == 0


def test_caution_then_danger_produces_both_alerts(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """A rising threat must always get through — cooldown may not silence it."""
    evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.CAUTION, 45.0),
        settings, now=base_time,
    )
    session.commit()

    escalation = evaluate_alert(
        session,
        hive,
        HiveStatus.CAUTION,
        assessment_for(HiveStatus.DANGER),
        settings,
        # Deliberately inside the cooldown window.
        now=base_time + timedelta(seconds=5),
    )
    session.commit()

    assert escalation.created is True
    assert alert_count(session, hive.id) == 2


# ----------------------------------------------------------------------
# Rule 2 — recovery window
# ----------------------------------------------------------------------


def test_flickering_status_does_not_duplicate_alerts(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """DANGER → NORMAL → DANGER within seconds is one attack, not two."""
    evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.DANGER),
        settings, now=base_time,
    )
    session.commit()

    for offset in (2, 4, 6, 8):
        evaluate_alert(
            session,
            hive,
            HiveStatus.NORMAL,  # momentarily dropped out
            assessment_for(HiveStatus.DANGER),
            settings,
            now=base_time + timedelta(seconds=offset),
        )
    session.commit()

    assert alert_count(session, hive.id) == 1


def test_new_attack_after_recovery_window_alerts_again(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """A genuinely separate attack later in the day must alert again."""
    evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.DANGER),
        settings, now=base_time,
    )
    session.commit()

    later = base_time + timedelta(seconds=settings.alert_recovery_seconds + 30)
    second = evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.DANGER),
        settings, now=later,
    )
    session.commit()

    assert second.created is True
    assert alert_count(session, hive.id) == 2


def test_recovery_window_is_configurable(
    session: Session, hive: Hive, base_time: datetime, tmp_path
) -> None:
    impatient = Settings(
        database_url=f"sqlite:///{tmp_path / 'test.db'}",
        seed_on_startup=False,
        alert_recovery_seconds=1.0,
        alert_cooldown_seconds=0.0,
    )
    evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.DANGER),
        impatient, now=base_time,
    )
    session.commit()

    second = evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.DANGER),
        impatient, now=base_time + timedelta(seconds=5),
    )
    session.commit()

    assert second.created is True


# ----------------------------------------------------------------------
# Severity mapping and notification dispatch
# ----------------------------------------------------------------------


def test_caution_alerts_can_be_switched_off(tmp_path) -> None:
    quiet = Settings(
        database_url=f"sqlite:///{tmp_path / 'test.db'}",
        seed_on_startup=False,
        alert_on_caution=False,
    )

    assert severity_for_status(HiveStatus.CAUTION, quiet) is None
    assert severity_for_status(HiveStatus.DANGER, quiet) is AlertSeverity.DANGER


def test_offline_status_does_not_alert(settings: Settings) -> None:
    assert severity_for_status(HiveStatus.OFFLINE, settings) is None


def test_danger_alert_is_pushed_to_registered_devices(
    session: Session,
    hive: Hive,
    settings: Settings,
    base_time: datetime,
    sender: ConsoleNotificationSender,
) -> None:
    session.add(PushDevice(token="token-1", platform="android"))
    session.add(PushDevice(token="token-2", platform="ios"))
    session.commit()

    decision = evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.DANGER),
        settings, now=base_time,
    )
    session.commit()
    assert decision.alert is not None

    delivered = dispatch_notification(session, decision.alert, hive, sender)

    assert delivered == 2
    payload, tokens = sender.sent[0]
    assert payload.severity == "DANGER"
    assert payload.alert_id == decision.alert.id
    assert payload.as_data()["route"] == f"/alerts/{decision.alert.id}"
    assert sorted(tokens) == ["token-1", "token-2"]


def test_caution_alert_is_not_pushed(
    session: Session,
    hive: Hive,
    settings: Settings,
    base_time: datetime,
    sender: ConsoleNotificationSender,
) -> None:
    """A CAUTION is recorded and visible in the app, but does not buzz."""
    session.add(PushDevice(token="token-1", platform="android"))
    session.commit()

    decision = evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.CAUTION, 45.0),
        settings, now=base_time,
    )
    session.commit()
    assert decision.alert is not None

    assert dispatch_notification(session, decision.alert, hive, sender) == 0
    assert sender.sent == []


def test_notification_failure_does_not_propagate(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """A dead FCM connection must never fail the frame upload that caused it."""

    class BrokenSender(ConsoleNotificationSender):
        def send(self, payload, tokens):  # type: ignore[no-untyped-def]
            raise RuntimeError("FCM is down")

    decision = evaluate_alert(
        session, hive, HiveStatus.NORMAL, assessment_for(HiveStatus.DANGER),
        settings, now=base_time,
    )
    session.commit()
    assert decision.alert is not None

    assert dispatch_notification(session, decision.alert, hive, BrokenSender()) == 0
