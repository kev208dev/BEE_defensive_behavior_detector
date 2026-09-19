"""Pairing tests — the code that binds a monitoring phone to a hive.

The contract these pin down is what makes the pairing flow safe enough for the
MVP: a code works exactly once, only for its TTL, and only for the hive that
issued it — and a failed claim says *why* so the app can react.
"""

from __future__ import annotations

from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app.config import Settings
from app.enums import PairingStatus
from app.models import Hive, MonitoringDevice, PairingSession
from app.services import pairing as pairing_service


@pytest.fixture(autouse=True)
def _clear_rate_limiter():
    """The limiter is process-wide, so tests must not inherit each other's attempts."""
    pairing_service.claim_rate_limiter.reset()
    yield
    pairing_service.claim_rate_limiter.reset()


# ----------------------------------------------------------------------
# Code generation
# ----------------------------------------------------------------------


def test_created_code_is_six_digits(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()

    assert len(pairing.code) == 6
    assert pairing.code.isdigit()


def test_code_length_is_configurable(
    session: Session, hive: Hive, base_time: datetime, tmp_path
) -> None:
    longer = Settings(
        database_url=f"sqlite:///{tmp_path / 'test.db'}",
        seed_on_startup=False,
        pairing_code_digits=8,
    )
    pairing = pairing_service.create_pairing(session, hive, longer, now=base_time)

    assert len(pairing.code) == 8


def test_pairing_expires_after_the_configured_ttl(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)

    expected = base_time + timedelta(seconds=settings.pairing_ttl_seconds)
    assert pairing.expires_at == expected


def test_codes_are_unique_among_live_pairings(
    session: Session, settings: Settings, base_time: datetime
) -> None:
    """Two live codes colliding would bind a phone to the wrong hive."""
    hives = [Hive(id=f"hive-{i}", name=f"벌통 {i}") for i in range(20)]
    for row in hives:
        session.add(row)
    session.commit()

    codes = {
        pairing_service.create_pairing(session, row, settings, now=base_time).code
        for row in hives
    }
    session.commit()

    assert len(codes) == len(hives)


def test_expired_code_digits_can_be_reused(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """Uniqueness only has to hold across claimable codes."""
    first = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()

    later = base_time + timedelta(seconds=settings.pairing_ttl_seconds + 1)
    assert pairing_service.find_claimable_by_code(session, first.code, later) is None


# ----------------------------------------------------------------------
# Status
# ----------------------------------------------------------------------


def test_status_is_waiting_then_expired(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)

    assert pairing_service.status_of(pairing, base_time) is PairingStatus.WAITING

    past_ttl = base_time + timedelta(seconds=settings.pairing_ttl_seconds + 1)
    assert pairing_service.status_of(pairing, past_ttl) is PairingStatus.EXPIRED


def test_claimed_status_survives_expiry(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """A redeemed code stays CLAIMED — that is what the manager app waits for."""
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)
    pairing.claimed_at = base_time
    pairing.claimed_device_id = "phone-1"

    long_after = base_time + timedelta(days=1)
    assert pairing_service.status_of(pairing, long_after) is PairingStatus.CLAIMED


# ----------------------------------------------------------------------
# Claiming
# ----------------------------------------------------------------------


def test_claim_succeeds_and_returns_the_hive(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()

    result = pairing_service.claim(
        session, pairing.code, "phone-monitor-1", settings, now=base_time
    )
    session.commit()

    assert result.hive_id == hive.id
    assert result.hive_name == hive.name
    assert result.device_id == "phone-monitor-1"


def test_claim_binds_the_device_to_the_hive(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """The whole point: after claiming, the phone is registered against the hive."""
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()

    pairing_service.claim(
        session, pairing.code, "phone-monitor-1", settings, now=base_time
    )
    session.commit()

    device = session.exec(
        select(MonitoringDevice).where(
            MonitoringDevice.device_identifier == "phone-monitor-1"
        )
    ).one()
    assert device.hive_id == hive.id


def test_claim_marks_the_pairing_claimed(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()

    pairing_service.claim(session, pairing.code, "phone-1", settings, now=base_time)
    session.commit()
    session.refresh(pairing)

    assert pairing.claimed_at == base_time
    assert pairing.claimed_device_id == "phone-1"
    assert pairing_service.status_of(pairing, base_time) is PairingStatus.CLAIMED


def test_unknown_code_is_rejected(
    session: Session, settings: Settings, base_time: datetime
) -> None:
    with pytest.raises(pairing_service.PairingError) as excinfo:
        pairing_service.claim(session, "000000", "phone-1", settings, now=base_time)

    assert excinfo.value.failure.value == "INVALID_CODE"


def test_non_numeric_code_is_rejected(
    session: Session, settings: Settings, base_time: datetime
) -> None:
    with pytest.raises(pairing_service.PairingError) as excinfo:
        pairing_service.claim(session, "abcdef", "phone-1", settings, now=base_time)

    assert excinfo.value.failure.value == "INVALID_CODE"


def test_expired_code_is_rejected_as_expired(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """The app shows "ask for a new code", which needs EXPIRED not INVALID."""
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()

    too_late = base_time + timedelta(seconds=settings.pairing_ttl_seconds + 1)
    with pytest.raises(pairing_service.PairingError) as excinfo:
        pairing_service.claim(session, pairing.code, "phone-1", settings, now=too_late)

    assert excinfo.value.failure.value == "EXPIRED"


def test_code_cannot_be_claimed_twice(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """Single-use: a code read off someone's screen must not work again."""
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()

    pairing_service.claim(session, pairing.code, "phone-1", settings, now=base_time)
    session.commit()

    with pytest.raises(pairing_service.PairingError) as excinfo:
        pairing_service.claim(session, pairing.code, "phone-2", settings, now=base_time)

    assert excinfo.value.failure.value == "ALREADY_CLAIMED"


def test_claim_tolerates_spacing_in_the_code(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """The manager screen shows "482 731"; retyping it with the space must work."""
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()
    spaced = f"{pairing.code[:3]} {pairing.code[3:]}"

    result = pairing_service.claim(session, spaced, "phone-1", settings, now=base_time)

    assert result.hive_id == hive.id


# ----------------------------------------------------------------------
# Device binding reuse
# ----------------------------------------------------------------------


def test_binding_is_idempotent(session: Session, hive: Hive) -> None:
    first = pairing_service.bind_device_to_hive(
        session, device_id="phone-1", hive_id=hive.id
    )
    second = pairing_service.bind_device_to_hive(
        session, device_id="phone-1", hive_id=hive.id
    )
    session.commit()

    assert first.id == second.id


def test_rebinding_moves_a_device_to_the_new_hive(session: Session) -> None:
    """Re-pairing a phone to a different hive must not leave it on the old one."""
    first_hive = Hive(id="hive-1", name="벌통 1")
    second_hive = Hive(id="hive-2", name="벌통 2")
    session.add(first_hive)
    session.add(second_hive)
    session.commit()

    pairing_service.bind_device_to_hive(
        session, device_id="phone-1", hive_id=first_hive.id
    )
    session.commit()
    pairing_service.bind_device_to_hive(
        session, device_id="phone-1", hive_id=second_hive.id
    )
    session.commit()

    devices = session.exec(
        select(MonitoringDevice).where(
            MonitoringDevice.device_identifier == "phone-1"
        )
    ).all()
    assert [d.hive_id for d in devices] == [second_hive.id]


# ----------------------------------------------------------------------
# Rate limiting
# ----------------------------------------------------------------------


def test_rate_limiter_blocks_after_the_configured_attempts(
    settings: Settings, base_time: datetime
) -> None:
    limiter = pairing_service.ClaimRateLimiter()

    allowed = [
        limiter.check_and_record("1.2.3.4", settings, base_time)
        for _ in range(settings.pairing_claim_max_attempts)
    ]
    blocked = limiter.check_and_record("1.2.3.4", settings, base_time)

    assert all(allowed)
    assert blocked is False


def test_rate_limiter_window_slides(settings: Settings, base_time: datetime) -> None:
    limiter = pairing_service.ClaimRateLimiter()
    for _ in range(settings.pairing_claim_max_attempts):
        limiter.check_and_record("1.2.3.4", settings, base_time)

    later = base_time + timedelta(seconds=settings.pairing_claim_window_seconds + 1)
    assert limiter.check_and_record("1.2.3.4", settings, later) is True


def test_rate_limiter_is_per_client(settings: Settings, base_time: datetime) -> None:
    limiter = pairing_service.ClaimRateLimiter()
    for _ in range(settings.pairing_claim_max_attempts):
        limiter.check_and_record("1.2.3.4", settings, base_time)

    assert limiter.check_and_record("5.6.7.8", settings, base_time) is True


# ----------------------------------------------------------------------
# Housekeeping
# ----------------------------------------------------------------------


def test_stale_pairings_are_purged(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    old = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()
    # Read the id up front: the purge detaches the row from the session, and
    # touching an attribute afterwards would try to refresh a deleted row.
    old_id = old.id

    much_later = base_time + timedelta(
        seconds=settings.pairing_retention_seconds + 60
    )
    removed = pairing_service.purge_stale(session, settings, much_later)
    session.commit()

    assert removed == 1
    assert session.get(PairingSession, old_id) is None


def test_recently_expired_pairings_are_kept(
    session: Session, hive: Hive, settings: Settings, base_time: datetime
) -> None:
    """A manager still polling a just-expired code should see EXPIRED, not 404."""
    pairing = pairing_service.create_pairing(session, hive, settings, now=base_time)
    session.commit()

    just_after = base_time + timedelta(seconds=settings.pairing_ttl_seconds + 60)
    pairing_service.purge_stale(session, settings, just_after)
    session.commit()

    assert session.get(PairingSession, pairing.id) is not None


# ----------------------------------------------------------------------
# HTTP surface
# ----------------------------------------------------------------------


def test_create_pairing_endpoint(client: TestClient) -> None:
    response = client.post("/api/pairings", json={"hive_id": "hive-a"})
    body = response.json()

    assert response.status_code == 201
    assert len(body["code"]) == 6
    assert body["code"].isdigit()
    assert body["hive_id"] == "hive-a"
    assert body["pair_uri"] == f"beehiveguard://pair?code={body['code']}"
    assert body["expires_in_seconds"] > 0


def test_create_pairing_for_unknown_hive_is_404(client: TestClient) -> None:
    assert client.post("/api/pairings", json={"hive_id": "nope"}).status_code == 404


def test_pairing_status_endpoint_reports_waiting(client: TestClient) -> None:
    created = client.post("/api/pairings", json={"hive_id": "hive-a"}).json()

    body = client.get(f"/api/pairings/{created['id']}").json()

    assert body["status"] == "WAITING"
    assert body["claimed_device_id"] is None
    assert body["hive_name"]


def test_pairing_status_flips_to_claimed(client: TestClient) -> None:
    """This transition is what closes the manager's pairing sheet."""
    created = client.post("/api/pairings", json={"hive_id": "hive-a"}).json()
    client.post(
        "/api/pairings/claim",
        json={"code": created["code"], "device_id": "phone-monitor-1"},
    )

    body = client.get(f"/api/pairings/{created['id']}").json()

    assert body["status"] == "CLAIMED"
    assert body["claimed_device_id"] == "phone-monitor-1"


def test_unknown_pairing_id_is_404(client: TestClient) -> None:
    assert client.get("/api/pairings/does-not-exist").status_code == 404


def test_claim_endpoint_returns_the_hive(client: TestClient) -> None:
    created = client.post("/api/pairings", json={"hive_id": "hive-a"}).json()

    response = client.post(
        "/api/pairings/claim",
        json={"code": created["code"], "device_id": "phone-monitor-1"},
    )
    body = response.json()

    assert response.status_code == 200
    assert body["success"] is True
    assert body["hive_id"] == "hive-a"
    assert body["hive_name"]


def test_claim_endpoint_rejects_unknown_code(client: TestClient) -> None:
    response = client.post(
        "/api/pairings/claim", json={"code": "123456", "device_id": "phone-1"}
    )

    assert response.status_code == 404
    assert response.json()["detail"]["reason"] == "INVALID_CODE"


def test_claim_endpoint_rejects_reused_code(client: TestClient) -> None:
    created = client.post("/api/pairings", json={"hive_id": "hive-a"}).json()
    client.post(
        "/api/pairings/claim",
        json={"code": created["code"], "device_id": "phone-1"},
    )

    response = client.post(
        "/api/pairings/claim",
        json={"code": created["code"], "device_id": "phone-2"},
    )

    assert response.status_code == 409
    assert response.json()["detail"]["reason"] == "ALREADY_CLAIMED"


def test_claim_endpoint_throttles_repeated_attempts(client: TestClient) -> None:
    """Brute-forcing six digits must not be free."""
    statuses = [
        client.post(
            "/api/pairings/claim",
            json={"code": f"{i:06d}", "device_id": "attacker"},
        ).status_code
        for i in range(15)
    ]

    assert 429 in statuses
    assert statuses[-1] == 429


def test_claimed_device_can_immediately_heartbeat(client: TestClient) -> None:
    """End to end: pair, then run the existing monitoring flow unchanged."""
    created = client.post("/api/pairings", json={"hive_id": "hive-a"}).json()
    claim = client.post(
        "/api/pairings/claim",
        json={"code": created["code"], "device_id": "phone-monitor-1"},
    ).json()

    heartbeat = client.post(
        "/api/monitor/heartbeat",
        json={"hive_id": claim["hive_id"], "device_id": claim["device_id"]},
    )

    assert heartbeat.status_code == 200
    status = client.get(f"/api/hives/{claim['hive_id']}/status").json()
    assert status["monitoring_online"] is True


def test_demo_reset_clears_pairings(client: TestClient) -> None:
    created = client.post("/api/pairings", json={"hive_id": "hive-a"}).json()

    client.post("/api/demo/reset")

    assert client.get(f"/api/pairings/{created['id']}").status_code == 404
