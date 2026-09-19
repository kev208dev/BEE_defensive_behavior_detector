"""Health endpoint."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter

from app.api.deps import SettingsDep
from app.schemas import HealthResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
def health(settings: SettingsDep) -> HealthResponse:
    """Liveness check that also reports which adapters are active."""
    return HealthResponse(
        status="ok",
        detector_mode=settings.detector_mode.value,
        audio_model_mode=settings.audio_model_mode.value,
        notification_mode=settings.notification_mode.value,
        server_time=datetime.utcnow(),
    )
