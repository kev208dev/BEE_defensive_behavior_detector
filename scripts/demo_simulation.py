#!/usr/bin/env python3
"""Replay a hornet attack against a running backend.

This is the competition's safety net: it proves the full NORMAL → CAUTION →
DANGER → alert → notification chain on demand, with no hornets required.

Usage::

    # Instant replay (server computes the whole timeline at once)
    python scripts/demo_simulation.py --hive-id hive-a

    # Real-time replay, one frame per second, so an audience can watch it climb
    python scripts/demo_simulation.py --hive-id hive-a --live

    # Queue the scenario for a real monitoring phone's camera to pick up
    python scripts/demo_simulation.py --hive-id hive-a --script-camera

    # Just make the manager phone buzz
    python scripts/demo_simulation.py --hive-id hive-a --create-alert

Only the standard library is required, so this runs without the backend venv.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from typing import Any

DEFAULT_BASE_URL = "http://127.0.0.1:8000"

#: Mirrors ``app.services.demo.DEFAULT_SCENARIO`` for the --live path.
SCENARIO: list[tuple[float, int, float]] = [
    # (offset_seconds, hornet_count, audio_probability)
    (0, 0, 0.05),
    (5, 1, 0.10),
    (10, 2, 0.20),
    (15, 4, 0.30),
    (20, 6, 0.85),
]

STATUS_COLOUR = {
    "NORMAL": "\033[32m",
    "CAUTION": "\033[33m",
    "DANGER": "\033[31m",
    "OFFLINE": "\033[90m",
}
RESET = "\033[0m"


def request(
    base_url: str, path: str, payload: dict[str, Any] | None = None, method: str = "POST"
) -> Any:
    """Small JSON HTTP helper with a clear error message on failure."""
    url = f"{base_url.rstrip('/')}{path}"
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise SystemExit(f"HTTP {exc.code} from {path}: {body}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(
            f"Could not reach the backend at {base_url} ({exc.reason}).\n"
            "Start it with: uvicorn app.main:app --host 0.0.0.0 --port 8000"
        ) from exc


def colourise(status: str) -> str:
    return f"{STATUS_COLOUR.get(status, '')}{status:<8}{RESET}"


def print_step(offset: float, count: int, score: int, status: str, alert: bool) -> None:
    marker = "  ← ALERT" if alert else ""
    print(
        f"  t={offset:>5.1f}s  hornets={count:<2}  risk={score:>3}  "
        f"{colourise(status)}{marker}"
    )


def check_health(base_url: str) -> None:
    health = request(base_url, "/health", method="GET")
    print(
        f"Backend OK — detector={health['detector_mode']} "
        f"audio={health['audio_model_mode']} "
        f"notifications={health['notification_mode']}\n"
    )


def run_instant(base_url: str, hive_id: str, include_audio: bool) -> None:
    """Let the server replay the whole timeline in one call."""
    print(f"Replaying the scripted attack on '{hive_id}'...\n")
    result = request(
        base_url,
        "/api/demo/simulate",
        {
            "hive_id": hive_id,
            "frames_per_second": 1.0,
            "include_audio": include_audio,
            "reset_first": True,
        },
    )
    for step in result["steps"]:
        if step["offset_seconds"] % 5 == 0 or step["alert_created"]:
            print_step(
                step["offset_seconds"],
                step["hornet_count"],
                step["risk_score"],
                step["status"],
                step["alert_created"],
            )
    print(
        f"\nAlerts created: {result['alerts_created']}  "
        f"Notifications sent: {result['notifications_sent']}"
    )


def run_live(base_url: str, hive_id: str, include_audio: bool, speed: float) -> None:
    """Replay in real time so an audience can watch the score climb.

    Feeds the scenario one observation per second through
    ``POST /api/demo/observe``, which runs the same pipeline a camera frame
    does — so the escalation and the alert on screen are computed live.
    """
    print(f"Live replay on '{hive_id}' (speed x{speed:g}) — Ctrl-C to stop\n")
    request(base_url, "/api/demo/reset")

    total = int(SCENARIO[-1][0])
    alerts_seen = 0
    started = time.monotonic()

    for offset in range(total + 1):
        count, audio = current_values(offset)
        step = request(
            base_url,
            "/api/demo/observe",
            {
                "hive_id": hive_id,
                "hornet_count": count,
                "audio_probability": audio if include_audio else None,
            },
        )
        if step["alert_created"]:
            alerts_seen += 1
        print_step(
            float(offset),
            count,
            step["risk_score"],
            step["status"],
            step["alert_created"],
        )

        target = started + (offset + 1) / speed
        remaining = target - time.monotonic()
        if remaining > 0:
            time.sleep(remaining)

    print(f"\nAlerts created: {alerts_seen}")


def current_values(offset: float) -> tuple[int, float]:
    """The scenario's hornet count and audio probability at a given second."""
    count, audio = SCENARIO[0][1], SCENARIO[0][2]
    for keyframe_offset, keyframe_count, keyframe_audio in SCENARIO:
        if offset >= keyframe_offset:
            count, audio = keyframe_count, keyframe_audio
    return count, audio


def run_script_camera(base_url: str, hive_id: str) -> None:
    """Queue the scenario for a real monitoring phone's frames to consume."""
    result = request(base_url, "/api/demo/script", {"hive_id": hive_id})
    print(
        f"Queued {result['frames_queued']} frames and "
        f"{result['audio_chunks_queued']} audio chunks for '{hive_id}'.\n"
        "Now press Start Monitoring on the monitoring phone — its real camera\n"
        "frames will be answered with the scripted counts, and the Risk Engine\n"
        "will escalate to DANGER on its own."
    )


def run_create_alert(base_url: str, hive_id: str) -> None:
    """Force a single DANGER alert, for rehearsing the push path."""
    alert = request(base_url, "/api/demo/create-alert", {"hive_id": hive_id})
    print(f"Alert {alert['id']} created for '{alert['hive_name']}'.")
    print(f"  {alert['message']}")
    print(f"  Deep link: /alerts/{alert['id']}")


def show_alerts(base_url: str) -> None:
    alerts = request(base_url, "/api/alerts?limit=10", method="GET")
    if not alerts:
        print("\nNo alerts recorded.")
        return
    print(f"\nAlerts now in the system ({len(alerts)}):")
    for alert in alerts:
        print(
            f"  [{alert['severity']:<7}] {alert['hive_name']}  "
            f"risk={alert['risk_score']:<3} {alert['message']}"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--hive-id", default="hive-a")
    parser.add_argument(
        "--live",
        action="store_true",
        help="Replay in real time instead of instantly",
    )
    parser.add_argument(
        "--script-camera",
        action="store_true",
        help="Queue the scenario for a real monitoring phone's camera",
    )
    parser.add_argument(
        "--create-alert",
        action="store_true",
        help="Force one DANGER alert and push it",
    )
    parser.add_argument(
        "--no-audio", action="store_true", help="Replay vision only"
    )
    parser.add_argument(
        "--speed", type=float, default=1.0, help="Live replay speed multiplier"
    )
    args = parser.parse_args(argv)

    check_health(args.base_url)

    if args.create_alert:
        run_create_alert(args.base_url, args.hive_id)
    elif args.script_camera:
        run_script_camera(args.base_url, args.hive_id)
    elif args.live:
        run_live(args.base_url, args.hive_id, not args.no_audio, args.speed)
    else:
        run_instant(args.base_url, args.hive_id, not args.no_audio)
        show_alerts(args.base_url)

    return 0


if __name__ == "__main__":
    sys.exit(main())
