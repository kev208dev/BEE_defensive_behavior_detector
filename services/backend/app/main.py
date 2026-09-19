"""FastAPI application entry point.

Run with::

    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.ai.factory import get_audio_classifier, get_detector
from app.api import alerts, demo, devices, health, hives, monitor, pairings
from app.config import Settings, get_settings
from app.db import init_db
from app.notifications.factory import get_sender

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-7s %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Create the schema, seed data and warm the AI adapters on startup.

    The adapters are built here rather than lazily on the first frame so that
    a misconfigured model path shows up in the startup log — and falls back to
    mock — before the demo begins, not in the middle of it.
    """
    settings = get_settings()
    init_db(settings)

    detector = get_detector(settings)
    classifier = get_audio_classifier(settings)
    sender = get_sender(settings)
    logger.info(
        "Ready — detector=%s audio=%s notifications=%s",
        detector.name,
        classifier.name,
        sender.name,
    )
    yield


def create_app(settings: Settings | None = None) -> FastAPI:
    """Build the application.  Factored out so tests can build their own."""
    settings = settings or get_settings()

    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        description=(
            "Early detection of hornet mass attacks on beehives, using an "
            "ordinary smartphone as the camera and microphone."
        ),
        lifespan=lifespan,
    )

    # The mobile app talks to this server directly over the local network, and
    # the OpenAPI docs are opened from a browser during development.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health.router)
    app.include_router(hives.router)
    app.include_router(alerts.router)
    app.include_router(monitor.router)
    app.include_router(devices.router)
    app.include_router(pairings.router)
    app.include_router(demo.router)

    snapshot_dir = Path(settings.snapshot_dir)
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    app.mount(
        "/static/snapshots",
        StaticFiles(directory=str(snapshot_dir)),
        name="snapshots",
    )

    return app


app = create_app()
