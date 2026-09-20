"""Pairing endpoints — connecting a monitoring phone to a hive.

Three calls make up the whole flow:

* the manager app asks a hive for a code (``POST /api/pairings``),
* it polls that code while the sheet is open (``GET /api/pairings/{id}``),
* the monitoring phone redeems it (``POST /api/pairings/claim``).

A rejected claim answers with a specific reason rather than a flat failure, so
the monitoring app can tell the beekeeper whether to retype the digits or ask
for a fresh code.
"""

from __future__ import annotations

import math
from datetime import datetime

from fastapi import APIRouter, HTTPException, Request, status

from app.api.deps import SessionDep, SettingsDep, get_hive_or_404
from app.config import Settings
from app.enums import PairingFailure
from app.models import Hive, PairingSession
from app.schemas import (
    PairingClaimRequest,
    PairingClaimResponse,
    PairingCreateRequest,
    PairingCreateResponse,
    PairingStatusResponse,
)
from app.services import pairing as pairing_service

router = APIRouter(prefix="/api/pairings", tags=["pairing"])

#: Scheme the QR image encodes. The monitoring app's scanner accepts this form
#: and also a bare six-digit string, so a code copied by hand still works.
PAIR_URI_SCHEME = "beehiveguard"

#: Maps a claim failure onto the HTTP status that best describes it, so a
#: client can react on the status alone if it wants to.
_FAILURE_STATUS: dict[PairingFailure, int] = {
    PairingFailure.INVALID_CODE: status.HTTP_404_NOT_FOUND,
    PairingFailure.EXPIRED: status.HTTP_410_GONE,
    PairingFailure.ALREADY_CLAIMED: status.HTTP_409_CONFLICT,
    PairingFailure.RATE_LIMITED: status.HTTP_429_TOO_MANY_REQUESTS,
}


def build_pair_uri(code: str) -> str:
    """The deep link a QR code carries."""
    return f"{PAIR_URI_SCHEME}://pair?code={code}"


def _seconds_left(expires_at: datetime, now: datetime) -> int:
    """Whole seconds until expiry, never negative."""
    return max(0, math.floor((expires_at - now).total_seconds()))


def _claim_failure(failure: PairingFailure, message: str) -> HTTPException:
    """A rejection carrying a machine-readable reason in its body."""
    return HTTPException(
        status_code=_FAILURE_STATUS.get(failure, status.HTTP_400_BAD_REQUEST),
        detail={"success": False, "reason": failure.value, "message": message},
    )


def _to_status_response(
    pairing: PairingSession, hive_name: str, now: datetime
) -> PairingStatusResponse:
    return PairingStatusResponse(
        id=pairing.id,
        code=pairing.code,
        status=pairing_service.status_of(pairing, now),
        hive_id=pairing.hive_id,
        hive_name=hive_name,
        claimed_device_id=pairing.claimed_device_id,
        expires_at=pairing.expires_at,
        expires_in_seconds=_seconds_left(pairing.expires_at, now),
    )


@router.post(
    "",
    response_model=PairingCreateResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_pairing(
    payload: PairingCreateRequest,
    session: SessionDep,
    settings: SettingsDep,
) -> PairingCreateResponse:
    """Issue a pairing code for one hive.

    Each call returns a new code; the previous one stays claimable until it
    expires, so reopening the sheet does not strand a beekeeper who already
    walked to the hive with the old digits.
    """
    hive = get_hive_or_404(session, payload.hive_id)
    now = datetime.utcnow()

    pairing = pairing_service.create_pairing(session, hive, settings, now=now)
    session.commit()
    session.refresh(pairing)

    return PairingCreateResponse(
        id=pairing.id,
        code=pairing.code,
        hive_id=pairing.hive_id,
        hive_name=hive.name,
        expires_at=pairing.expires_at,
        expires_in_seconds=_seconds_left(pairing.expires_at, now),
        pair_uri=build_pair_uri(pairing.code),
    )


@router.get("/{pairing_id}", response_model=PairingStatusResponse)
def get_pairing(
    pairing_id: str,
    session: SessionDep,
    settings: SettingsDep,
) -> PairingStatusResponse:
    """Current state of a pairing, polled by the manager app."""
    pairing = session.get(PairingSession, pairing_id)
    if pairing is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Pairing not found: {pairing_id}",
        )

    hive = session.get(Hive, pairing.hive_id)
    return _to_status_response(
        pairing,
        hive.name if hive is not None else "",
        datetime.utcnow(),
    )


@router.post("/claim", response_model=PairingClaimResponse)
def claim_pairing(
    payload: PairingClaimRequest,
    request: Request,
    session: SessionDep,
    settings: SettingsDep,
) -> PairingClaimResponse:
    """Redeem a code, binding this phone to the hive that issued it.

    Throttled per client: six digits is a small enough space that an
    unthrottled endpoint could be walked through in bulk.
    """
    now = datetime.utcnow()
    _enforce_rate_limit(request, payload.device_id, settings, now)

    try:
        result = pairing_service.claim(
            session,
            code=payload.code,
            device_id=payload.device_id,
            settings=settings,
            now=now,
        )
    except pairing_service.PairingError as exc:
        session.rollback()
        raise _claim_failure(exc.failure, exc.message) from exc

    session.commit()
    return PairingClaimResponse(
        success=True,
        hive_id=result.hive_id,
        hive_name=result.hive_name,
        device_id=result.device_id,
        pairing_id=result.pairing_id,
    )


def _enforce_rate_limit(
    request: Request,
    device_id: str,
    settings: Settings,
    now: datetime,
) -> None:
    """Throttle on the caller's address, falling back to the device id.

    Keyed on the address rather than the device id because the device id comes
    from the client and an attacker would simply vary it. Behind a reverse
    proxy this needs X-Forwarded-For handling to see the real client.
    """
    client_host = request.client.host if request.client is not None else None
    key = client_host or device_id or "unknown"

    if not pairing_service.claim_rate_limiter.check_and_record(key, settings, now):
        raise _claim_failure(
            PairingFailure.RATE_LIMITED,
            "잠시 후 다시 시도해주세요. 시도 횟수가 너무 많습니다.",
        )
