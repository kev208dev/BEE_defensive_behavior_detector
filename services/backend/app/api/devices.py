"""Device and push-token registration."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter
from sqlmodel import select

from app.api.deps import SessionDep, SettingsDep
from app.models import MonitoringDevice, PushDevice
from app.schemas import (
    DeviceRegistrationRequest,
    DeviceRegistrationResponse,
    PushTokenRequest,
    PushTokenResponse,
)

router = APIRouter(prefix="/api/devices", tags=["devices"])


@router.post("", response_model=DeviceRegistrationResponse)
def register_device(
    payload: DeviceRegistrationRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> DeviceRegistrationResponse:
    """Register (or re-register) a monitoring phone.

    Idempotent on ``(device_id, hive_id)`` so an app restart does not create a
    duplicate row.
    """
    device: MonitoringDevice | None = None
    if payload.hive_id:
        device = session.exec(
            select(MonitoringDevice)
            .where(MonitoringDevice.device_identifier == payload.device_id)
            .where(MonitoringDevice.hive_id == payload.hive_id)
        ).first()

    if device is None:
        device = MonitoringDevice(
            hive_id=payload.hive_id or "",
            device_identifier=payload.device_id,
        )
        session.add(device)

    session.commit()
    session.refresh(device)
    return DeviceRegistrationResponse(
        id=device.id,
        device_id=device.device_identifier,
        hive_id=device.hive_id or None,
        registered_at=device.created_at,
    )


@router.post("/push-token", response_model=PushTokenResponse)
def register_push_token(
    payload: PushTokenRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> PushTokenResponse:
    """Store an FCM registration token for a manager phone.

    Idempotent on the token itself — FCM reissues the same token across app
    launches, and a duplicate would mean the beekeeper's phone buzzes twice.
    """
    existing = session.exec(
        select(PushDevice).where(PushDevice.token == payload.token)
    ).first()

    if existing is None:
        existing = PushDevice(
            token=payload.token,
            platform=payload.platform,
            device_identifier=payload.device_id,
        )
        session.add(existing)
    else:
        existing.platform = payload.platform
        existing.device_identifier = payload.device_id
        session.add(existing)

    session.commit()
    session.refresh(existing)
    return PushTokenResponse(
        id=existing.id,
        token=existing.token,
        platform=existing.platform,
        registered_at=existing.created_at,
    )
