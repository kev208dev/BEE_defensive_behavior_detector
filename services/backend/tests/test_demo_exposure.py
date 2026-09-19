"""The demo endpoints must not be reachable on a production deployment.

None of `/api/demo/*` authenticates, and `/api/demo/reset` deletes every
observation, alert, monitoring device and pairing session. Served publicly that
is a wipe of the hive history and an unpairing of every phone, for anyone who
knows the URL. Production runs with ``DEBUG=false``, so that is the switch.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import datetime, timezone
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app import db as db_module
from app.config import get_settings

#: Every route the demo router publishes, with a body valid enough that a
#: mounted endpoint would answer something other than "not found".
DEMO_ENDPOINTS: list[tuple[str, dict]] = [
    ("/api/demo/reset", {}),
    ("/api/demo/simulate", {"hive_id": "hive-a"}),
    ("/api/demo/create-alert", {"hive_id": "hive-a"}),
    ("/api/demo/script", {"hive_id": "hive-a"}),
    ("/api/demo/observe", {"hive_id": "hive-a", "hornet_count": 0}),
]


def _client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, *, debug: bool):
    monkeypatch.setenv("DATABASE_URL", f"sqlite:///{tmp_path / 'api.db'}")
    monkeypatch.setenv("STORAGE_DIR", str(tmp_path / "storage"))
    monkeypatch.setenv("SNAPSHOT_DIR", str(tmp_path / "storage" / "snapshots"))
    monkeypatch.setenv("DETECTOR_MODE", "mock")
    monkeypatch.setenv("AUDIO_MODEL_MODE", "mock")
    monkeypatch.setenv("NOTIFICATION_MODE", "console")
    monkeypatch.setenv("SEED_ON_STARTUP", "true")
    monkeypatch.setenv("DEBUG", "true" if debug else "false")

    get_settings.cache_clear()
    db_module.reset_engine()

    from app.main import create_app

    return TestClient(create_app())


@pytest.fixture
def production_client(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> Iterator[TestClient]:
    """A client configured the way the Railway deployment is."""
    with _client(tmp_path, monkeypatch, debug=False) as client:
        yield client


@pytest.fixture
def development_client(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> Iterator[TestClient]:
    with _client(tmp_path, monkeypatch, debug=True) as client:
        yield client


@pytest.mark.parametrize(("path", "payload"), DEMO_ENDPOINTS)
def test_demo_endpoints_are_absent_in_production(
    production_client: TestClient, path: str, payload: dict
) -> None:
    assert production_client.post(path, json=payload).status_code == 404


@pytest.mark.parametrize(("path", "payload"), DEMO_ENDPOINTS)
def test_demo_endpoints_are_available_in_development(
    development_client: TestClient, path: str, payload: dict
) -> None:
    """The rehearsal tools still work where they are supposed to."""
    assert development_client.post(path, json=payload).status_code != 404


def test_production_reset_cannot_wipe_pairings(production_client: TestClient) -> None:
    """The specific attack the gate exists to stop.

    A pairing is created and claimed, then /api/demo/reset is called the way an
    anonymous caller would. The pairing must survive, because the endpoint is
    not served at all.
    """
    created = production_client.post(
        "/api/pairings", json={"hive_id": "hive-a"}
    ).json()

    assert production_client.post("/api/demo/reset").status_code == 404

    claimed = production_client.post(
        "/api/pairings/claim",
        json={"code": created["code"], "device_id": "phone-after-reset"},
    )
    assert claimed.status_code == 200
    assert claimed.json()["hive_id"] == "hive-a"


def test_production_still_serves_the_real_api(production_client: TestClient) -> None:
    """Gating the demo router must not take anything else down with it."""
    assert production_client.get("/health").status_code == 200
    assert production_client.get("/api/hives").status_code == 200
    assert production_client.post(
        "/api/monitor/observation",
        json={
            "hive_id": "hive-a",
            "device_id": "phone-production",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "hornet_count": 0,
            "max_confidence": 0.0,
            "detections": [],
            "inference_ms": 5,
            "model_version": "test",
        },
    ).status_code == 200
