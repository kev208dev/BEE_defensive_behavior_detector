"""Timestamps arriving from a phone in a real timezone.

The storage layer is naive UTC throughout (``datetime.utcnow()``), but a
correct client sends RFC 3339 with an offset. Both have to work, and both have
to mean the same instant, or two things break:

* the risk window compares an aware timestamp against a naive one and the
  upload endpoint answers 500;
* an unmarked local timestamp is read as UTC, so a phone in KST stamps every
  heartbeat nine hours ahead and the hive never goes OFFLINE.
"""

from __future__ import annotations

import io
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from PIL import Image

KST = timezone(timedelta(hours=9))


def observation_body(timestamp: str, hive_id: str = "hive-a") -> dict:
    return {
        "hive_id": hive_id,
        "device_id": "phone-tz",
        "timestamp": timestamp,
        "hornet_count": 0,
        "max_confidence": 0.0,
        "detections": [],
        "inference_ms": 5,
        "model_version": "tz-test",
    }


def jpeg() -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (64, 48), color=(10, 20, 30)).save(buffer, format="JPEG")
    return buffer.getvalue()


@pytest.mark.parametrize(
    "timestamp",
    [
        "2026-09-19T12:00:00Z",  # the form the API docs show
        "2026-09-19T12:00:00+00:00",
        "2026-09-19T21:00:00+09:00",  # a Korean phone
        "2026-09-19T12:00:00",  # naive, already UTC
    ],
    ids=["zulu", "utc-offset", "kst-offset", "naive"],
)
def test_observation_accepts_any_timezone(
    client: TestClient, timestamp: str
) -> None:
    response = client.post("/api/monitor/observation", json=observation_body(timestamp))
    assert response.status_code == 200


@pytest.mark.parametrize(
    "timestamp",
    ["2026-09-19T12:00:00Z", "2026-09-19T21:00:00+09:00", "2026-09-19T12:00:00"],
    ids=["zulu", "kst-offset", "naive"],
)
def test_legacy_frame_accepts_any_timezone(
    client: TestClient, timestamp: str
) -> None:
    """The multipart path needs the same normalisation as the JSON one."""
    response = client.post(
        "/api/monitor/frame",
        data={"hive_id": "hive-a", "device_id": "phone-tz", "timestamp": timestamp},
        files={"image": ("f.jpg", jpeg(), "image/jpeg")},
    )
    assert response.status_code == 200


def test_offsets_denoting_one_instant_are_stored_identically(
    client: TestClient,
) -> None:
    """21:00+09:00 and 12:00Z are the same moment and must land the same way."""
    client.post("/api/monitor/heartbeat", json={
        "hive_id": "hive-a",
        "device_id": "phone-kst",
        "timestamp": "2026-09-19T21:00:00+09:00",
    })
    kst_view = client.get("/api/hives/hive-a").json()["last_heartbeat"]

    client.post("/api/monitor/heartbeat", json={
        "hive_id": "hive-a",
        "device_id": "phone-kst",
        "timestamp": "2026-09-19T12:00:00Z",
    })
    utc_view = client.get("/api/hives/hive-a").json()["last_heartbeat"]

    assert datetime.fromisoformat(kst_view) == datetime.fromisoformat(utc_view)


def test_a_silent_phone_goes_offline_when_it_reports_its_offset(
    client: TestClient,
) -> None:
    """The bug this guards: a stale heartbeat must actually read as stale.

    Sent with an offset, a heartbeat from ten minutes ago is ten minutes old
    whatever zone the phone is in, so the hive reports OFFLINE.
    """
    stale = datetime.now(KST) - timedelta(minutes=10)
    client.post("/api/monitor/heartbeat", json={
        "hive_id": "hive-b",
        "device_id": "phone-gone",
        "timestamp": stale.isoformat(),
    })

    status = client.get("/api/hives/hive-b/status").json()
    assert status["monitoring_online"] is False
    assert status["status"] == "OFFLINE"


def test_a_live_phone_stays_online(client: TestClient) -> None:
    """The other half: a fresh heartbeat in KST must not read as stale."""
    client.post("/api/monitor/heartbeat", json={
        "hive_id": "hive-c",
        "device_id": "phone-live",
        "timestamp": datetime.now(KST).isoformat(),
    })

    status = client.get("/api/hives/hive-c/status").json()
    assert status["monitoring_online"] is True
    assert status["status"] != "OFFLINE"
