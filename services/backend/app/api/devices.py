"""Device and push-token registration."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter
from sqlmodel import select

from app.api.deps import SessionDep, SettingsDep
from app.models import PushDevice
from app.schemas import (
    DeviceRegistrationRequest,
    DeviceRegistrationResponse,
    PushTokenRequest,
    PushTokenResponse,
)
from app.services.pairing import bind_device_to_hive

router = APIRouter(prefix="/api/devices", tags=["devices"])


@router.post("", response_model=DeviceRegistrationResponse)
def register_device(
    payload: DeviceRegistrationRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> DeviceRegistrationResponse:
    """Register (or re-register) a monitoring phone.

    Shares :func:`~app.services.pairing.bind_device_to_hive` with the pairing
    claim, so a device bound by code and one registered directly end up as the
    same row rather than two rows that each look like a separate device.
    """
    device = bind_device_to_hive(
        session,
        device_id=payload.device_id,
        hive_id=payload.hive_id,
    )
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
