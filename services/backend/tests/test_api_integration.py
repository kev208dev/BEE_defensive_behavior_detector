"""End-to-end API tests over the real application.

These walk the same path the competition demo does: upload frames, watch the
risk climb, confirm exactly one alert per episode, and confirm the manager
endpoints can then read it back.
"""

from __future__ import annotations

import io
from datetime import datetime, timedelta

from fastapi.testclient import TestClient
from PIL import Image


def jpeg_bytes(seed: int = 0, size: tuple[int, int] = (320, 240)) -> bytes:
    """A small, valid JPEG so the upload path is exercised for real."""
    image = Image.new("RGB", size, color=(seed % 256, (seed * 7) % 256, 40))
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=70)
    return buffer.getvalue()


def upload_frame(client: TestClient, hive_id: str, seed: int = 0):
    return client.post(
        "/api/monitor/frame",
        data={"hive_id": hive_id, "device_id": "phone-monitor-1"},
        files={"image": (f"frame{seed}.jpg", jpeg_bytes(seed), "image/jpeg")},
    )


def upload_observation(
    client: TestClient,
    hive_id: str,
    *,
    hornet_count: int,
    timestamp: datetime,
    max_confidence: float = 0.9,
):
    detections = [
        {
            "confidence": max_confidence,
            "x": 0.1,
            "y": 0.2,
            "width": 0.3,
            "height": 0.4,
            "class_name": "hornet",
        }
        for _ in range(hornet_count)
    ]
    return client.post(
        "/api/monitor/observation",
        json={
            "hive_id": hive_id,
            "device_id": "phone-monitor-edge-1",
            "timestamp": timestamp.isoformat(),
            "hornet_count": hornet_count,
            "max_confidence": max_confidence if hornet_count else 0.0,
            "detections": detections,
            "inference_ms": 38,
            "model_version": "mock-v1",
        },
    )


# ----------------------------------------------------------------------
# Basics
# ----------------------------------------------------------------------


def test_health_reports_mock_adapters(client: TestClient) -> None:
    body = client.get("/health").json()

    assert body["status"] == "ok"
    assert body["detector_mode"] == "mock"
    assert body["audio_model_mode"] == "mock"
    assert body["notification_mode"] == "console"


def test_seeded_hives_are_listed(client: TestClient) -> None:
    hives = client.get("/api/hives").json()

    assert len(hives) >= 3
    assert {"id", "name", "status", "risk_score", "hornet_count"} <= set(hives[0])


def test_unknown_hive_returns_404(client: TestClient) -> None:
    assert client.get("/api/hives/does-not-exist").status_code == 404
    assert client.get("/api/alerts/does-not-exist").status_code == 404


def test_hive_with_no_heartbeat_is_offline(client: TestClient) -> None:
    body = client.get("/api/hives/hive-a/status").json()

    assert body["status"] == "OFFLINE"
    assert body["monitoring_online"] is False


# ----------------------------------------------------------------------
# Monitoring uploads
# ----------------------------------------------------------------------


def test_frame_upload_returns_the_documented_shape(client: TestClient) -> None:
    body = upload_frame(client, "hive-a").json()

    assert set(body) >= {
        "status",
        "risk_score",
        "hornet_count",
        "confidence",
        "processed_at",
    }
    assert body["status"] in {"NORMAL", "CAUTION", "DANGER", "OFFLINE"}
    assert 0 <= body["risk_score"] <= 100
    assert body["hornet_count"] >= 0


def test_frame_upload_to_unknown_hive_returns_404(client: TestClient) -> None:
    assert upload_frame(client, "nope").status_code == 404


def test_frame_upload_stores_a_snapshot(client: TestClient) -> None:
    body = upload_frame(client, "hive-a").json()

    assert body["snapshot_url"] is not None
    assert body["snapshot_url"].endswith(".jpg")


def test_observation_upload_persists_count_and_growth(client: TestClient) -> None:
    base = datetime.utcnow() - timedelta(seconds=3)

    for index, count in enumerate((0, 1, 2, 4)):
        response = upload_observation(
            client,
            "hive-a",
            hornet_count=count,
            timestamp=base + timedelta(seconds=index),
        )
        assert response.status_code == 200

    body = response.json()
    detail = client.get("/api/hives/hive-a").json()

    assert body["hornet_count"] == 4
    assert body["confidence"] == 0.9
    assert body["snapshot_url"] is None
    assert detail["id"] == "hive-a"
    assert detail["hornet_count"] == 4
    assert detail["max_hornet_count"] == 4
    assert detail["growth_per_second"] > 0
    assert detail["persistence_ratio"] > 0


def test_observation_upload_uses_existing_risk_and_alert_pipeline(
    client: TestClient,
) -> None:
    base = datetime.utcnow() - timedelta(seconds=11)
    statuses: list[str] = []

    for index in range(12):
        response = upload_observation(
            client,
            "hive-b",
            hornet_count=6,
            timestamp=base + timedelta(seconds=index),
            max_confidence=0.96,
        )
        assert response.status_code == 200
        statuses.append(response.json()["status"])

    alerts = client.get(
        "/api/alerts", params={"hive_id": "hive-b", "severity": "DANGER"}
    ).json()

    assert "DANGER" in statuses
    assert len(alerts) == 1


def test_observation_upload_rejects_invalid_metadata(client: TestClient) -> None:
    invalid_payloads = [
        {"hornet_count": -1, "max_confidence": 0.5, "detections": []},
        {"hornet_count": 1, "max_confidence": 1.1, "detections": []},
        {
            "hornet_count": 1,
            "max_confidence": 0.9,
            "detections": [
                {
                    "confidence": 0.9,
                    "x": 0.9,
                    "y": 0.2,
                    "width": 0.3,
                    "height": 0.4,
                    "class_name": "hornet",
                }
            ],
        },
        {"hornet_count": 0, "max_confidence": 0.0, "detections": [], "inference_ms": -1},
    ]

    for invalid in invalid_payloads:
        response = client.post(
            "/api/monitor/observation",
            json={
                "hive_id": "hive-a",
                "device_id": "phone-monitor-edge-1",
                "timestamp": "2026-09-19T12:00:00",
                "inference_ms": 10,
                "model_version": "mock-v1",
                **invalid,
            },
        )
        assert response.status_code == 422


def test_audio_upload_returns_the_documented_shape(client: TestClient) -> None:
    response = client.post(
        "/api/monitor/audio",
        data={"hive_id": "hive-a", "device_id": "phone-monitor-1"},
        files={"audio": ("chunk.m4a", b"\x00\x01fake-audio-chunk", "audio/mp4")},
    )
    body = response.json()

    assert response.status_code == 200
    assert set(body) >= {"hornet_probability", "processed_at"}
    assert 0.0 <= body["hornet_probability"] <= 1.0


def test_heartbeat_brings_a_hive_online(client: TestClient) -> None:
    response = client.post(
        "/api/monitor/heartbeat",
        json={
            "hive_id": "hive-a",
            "device_id": "phone-monitor-1",
            "camera_ok": True,
            "microphone_ok": True,
            "monitoring": True,
        },
    )

    assert response.status_code == 200
    assert response.json()["acknowledged"] is True

    status = client.get("/api/hives/hive-a/status").json()
    assert status["monitoring_online"] is True
    assert status["status"] != "OFFLINE"


def test_hive_detail_reflects_device_flags(client: TestClient) -> None:
    client.post(
        "/api/monitor/heartbeat",
        json={
            "hive_id": "hive-b",
            "device_id": "phone-monitor-2",
            "camera_ok": True,
            "microphone_ok": False,
            "monitoring": True,
        },
    )
    detail = client.get("/api/hives/hive-b").json()

    assert detail["camera_ok"] is True
    assert detail["microphone_ok"] is False
    assert detail["monitoring"] is True


# ----------------------------------------------------------------------
# The full demo path
# ----------------------------------------------------------------------


def test_simulation_walks_normal_to_danger(client: TestClient) -> None:
    body = client.post("/api/demo/simulate", json={"hive_id": "hive-a"}).json()
    statuses = [step["status"] for step in body["steps"]]

    assert statuses[0] == "NORMAL"
    assert statuses[-1] == "DANGER"
    assert "CAUTION" in statuses
    # CAUTION must be reached before DANGER — the escalation has to be legible.
    assert statuses.index("CAUTION") < statuses.index("DANGER")


def test_simulation_produces_exactly_one_danger_alert(client: TestClient) -> None:
    """The de-duplication guarantee, measured end to end."""
    body = client.post("/api/demo/simulate", json={"hive_id": "hive-a"}).json()
    danger = client.get("/api/alerts", params={"severity": "DANGER"}).json()

    assert body["alerts_created"] >= 1
    assert len(danger) == 1
    assert danger[0]["hive_id"] == "hive-a"


def test_simulation_alert_carries_an_explanation(client: TestClient) -> None:
    client.post("/api/demo/simulate", json={"hive_id": "hive-a"})
    alert_id = client.get("/api/alerts", params={"severity": "DANGER"}).json()[0]["id"]

    detail = client.get(f"/api/alerts/{alert_id}").json()

    assert detail["explanation"]
    assert detail["max_hornet_count"] >= detail["hornet_count"]
    assert detail["hive_name"]


def test_simulation_is_repeatable(client: TestClient) -> None:
    """Reset-and-replay must give the same result, so the demo can be rehearsed."""
    first = client.post("/api/demo/simulate", json={"hive_id": "hive-a"}).json()
    second = client.post("/api/demo/simulate", json={"hive_id": "hive-a"}).json()

    assert [s["status"] for s in first["steps"]] == [
        s["status"] for s in second["steps"]
    ]
    assert len(client.get("/api/alerts", params={"severity": "DANGER"}).json()) == 1


def test_dashboard_counts_add_up(client: TestClient) -> None:
    client.post("/api/demo/simulate", json={"hive_id": "hive-a"})
    body = client.get("/api/dashboard").json()

    assert body["total"] == len(body["hives"])
    assert body["normal"] + body["caution"] + body["danger"] + body["offline"] == (
        body["total"]
    )
    assert body["danger"] >= 1


def test_alerts_since_filter_supports_polling(client: TestClient) -> None:
    """The manager app's no-Firebase fallback depends on this filter."""
    client.post("/api/demo/simulate", json={"hive_id": "hive-a"})
    alerts = client.get("/api/alerts").json()
    newest = alerts[0]["timestamp"]

    assert client.get("/api/alerts", params={"since": newest}).json() == []

    client.post("/api/demo/create-alert", json={"hive_id": "hive-b"})
    fresh = client.get("/api/alerts", params={"since": newest}).json()

    assert len(fresh) == 1
    assert fresh[0]["hive_id"] == "hive-b"


def test_demo_reset_clears_everything(client: TestClient) -> None:
    client.post("/api/demo/simulate", json={"hive_id": "hive-a"})
    assert client.get("/api/alerts").json() != []

    client.post("/api/demo/reset")

    assert client.get("/api/alerts").json() == []
    assert client.get("/api/hives/hive-a/status").json()["status"] == "OFFLINE"


# ----------------------------------------------------------------------
# Device registration
# ----------------------------------------------------------------------


def test_device_registration_is_idempotent(client: TestClient) -> None:
    payload = {"device_id": "phone-1", "hive_id": "hive-a", "role": "monitor"}
    first = client.post("/api/devices", json=payload).json()
    second = client.post("/api/devices", json=payload).json()

    assert first["id"] == second["id"]


def test_push_token_registration_is_idempotent(client: TestClient) -> None:
    payload = {"token": "fcm-token-abc", "platform": "android"}
    first = client.post("/api/devices/push-token", json=payload).json()
    second = client.post("/api/devices/push-token", json=payload).json()

    assert first["id"] == second["id"]
    assert second["token"] == "fcm-token-abc"


def test_registered_token_receives_the_danger_push(client: TestClient) -> None:
    client.post(
        "/api/devices/push-token", json={"token": "fcm-token-xyz", "platform": "android"}
    )
    body = client.post("/api/demo/simulate", json={"hive_id": "hive-a"}).json()

    assert body["notifications_sent"] >= 1


# ----------------------------------------------------------------------
# Resilience
# ----------------------------------------------------------------------


def test_empty_image_does_not_crash_the_endpoint(client: TestClient) -> None:
    response = client.post(
        "/api/monitor/frame",
        data={"hive_id": "hive-a", "device_id": "phone-1"},
        files={"image": ("empty.jpg", b"", "image/jpeg")},
    )

    assert response.status_code == 200
    assert response.json()["hornet_count"] >= 0


def test_corrupt_image_does_not_crash_the_endpoint(client: TestClient) -> None:
    response = client.post(
        "/api/monitor/frame",
        data={"hive_id": "hive-a", "device_id": "phone-1"},
        files={"image": ("bad.jpg", b"not really a jpeg at all", "image/jpeg")},
    )

    assert response.status_code == 200


def test_many_frames_do_not_spam_alerts(client: TestClient) -> None:
    """Sustained uploads must not produce one alert per frame."""
    client.post(
        "/api/monitor/heartbeat",
        json={"hive_id": "hive-c", "device_id": "phone-3"},
    )
    for seed in range(40):
        assert upload_frame(client, "hive-c", seed).status_code == 200

    alerts = client.get("/api/alerts", params={"hive_id": "hive-c"}).json()

    # The mock detector's deterministic fallback may or may not escalate, but
    # forty frames can never be forty separate episodes.
    assert len(alerts) <= 2


def test_scripted_detector_drives_real_frames_to_danger(client: TestClient) -> None:
    """The camera path, demonstrated without live hornets.

    Real JPEG uploads go through the real pipeline; only the detector's answer
    is scripted, so the escalation and the alert are genuinely computed.
    """
    client.post("/api/monitor/heartbeat", json={"hive_id": "hive-d", "device_id": "p"})
    queued = client.post("/api/demo/script", json={"hive_id": "hive-d"}).json()

    assert queued["frames_queued"] > 0

    statuses = []
    for seed in range(queued["frames_queued"]):
        statuses.append(upload_frame(client, "hive-d", seed).json()["status"])

    assert statuses[0] == "NORMAL"
    assert "DANGER" in statuses

    danger = client.get(
        "/api/alerts", params={"hive_id": "hive-d", "severity": "DANGER"}
    ).json()
    assert len(danger) == 1
