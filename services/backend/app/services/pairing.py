"""Device pairing — binding a monitoring phone to a hive with a short code.

Replaces the previous setup flow, where the beekeeper typed the backend's IP
address into the app and then picked a hive from a list. Now the manager phone
asks a hive for a code, shows it as a QR image and six digits, and the
monitoring phone redeems it. Nobody types a URL.

Security posture for the MVP
----------------------------
* Codes are generated with :mod:`secrets`, not :mod:`random`.
* They live for ``PAIRING_TTL_SECONDS`` (10 minutes by default).
* They are single-use: claiming one marks it spent.
* Claims are rate limited, because six digits is only a million possibilities
  and an unthrottled endpoint would be brute-forceable.

There is deliberately no account system — the spec rules one out, and a phone
being taped to a hive in a field should be usable in seconds.
"""

from __future__ import annotations

import logging
import secrets
import threading
from collections import defaultdict, deque
from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlmodel import Session, delete, desc, select

from app.config import Settings
from app.enums import PairingFailure, PairingStatus
from app.models import Hive, MonitoringDevice, PairingSession

logger = logging.getLogger(__name__)

#: How many times to re-roll before giving up on finding an unused code.
#: With a six-digit space and a handful of live codes, one roll practically
#: always works; this only guards against a pathological collision streak.
_MAX_CODE_ATTEMPTS = 20


class PairingError(Exception):
    """A claim (or code generation) could not be completed."""

    def __init__(self, failure: PairingFailure, message: str) -> None:
        super().__init__(message)
        self.failure = failure
        self.message = message


@dataclass(frozen=True)
class ClaimResult:
    """What the monitoring phone needs after a successful claim."""

    hive_id: str
    hive_name: str
    device_id: str
    pairing_id: str


# ----------------------------------------------------------------------
# Rate limiting
# ----------------------------------------------------------------------


class ClaimRateLimiter:
    """Sliding-window limiter for the claim endpoint.

    Keyed on the caller's IP rather than the device id, because the device id
    is supplied by the client and an attacker would simply vary it.

    .. note::
       This lives in process memory, so it does not hold across multiple
       uvicorn workers or replicas, and it resets on restart. That is
       acceptable for the MVP's single-process deployment. **TODO:** before
       running more than one worker, move this to Redis or a small table so
       the window is shared.
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._attempts: dict[str, deque[datetime]] = defaultdict(deque)

    def check_and_record(
        self, key: str, settings: Settings, now: datetime | None = None
    ) -> bool:
        """Record an attempt for ``key``; return False when over the limit."""
        now = now or datetime.utcnow()
        cutoff = now - timedelta(seconds=settings.pairing_claim_window_seconds)

        with self._lock:
            bucket = self._attempts[key]
            while bucket and bucket[0] < cutoff:
                bucket.popleft()

            if len(bucket) >= settings.pairing_claim_max_attempts:
                return False

            bucket.append(now)
            return True

    def reset(self) -> None:
        """Forget every recorded attempt — used by tests and demo reset."""
        with self._lock:
            self._attempts.clear()


#: Process-wide limiter. See the note on :class:`ClaimRateLimiter`.
claim_rate_limiter = ClaimRateLimiter()


# ----------------------------------------------------------------------
# Status
# ----------------------------------------------------------------------


def status_of(
    pairing: PairingSession, now: datetime | None = None
) -> PairingStatus:
    """Derive a pairing's status from its timestamps.

    Claimed wins over expired: a code that was redeemed and then sat past its
    TTL is still CLAIMED, because that is the fact the manager app is waiting
    to see.
    """
    if pairing.claimed_at is not None:
        return PairingStatus.CLAIMED
    now = now or datetime.utcnow()
    if now >= pairing.expires_at:
        return PairingStatus.EXPIRED
    return PairingStatus.WAITING


def is_claimable(pairing: PairingSession, now: datetime | None = None) -> bool:
    return status_of(pairing, now) is PairingStatus.WAITING


# ----------------------------------------------------------------------
# Creating a code
# ----------------------------------------------------------------------


def generate_code(
    session: Session, settings: Settings, now: datetime | None = None
) -> str:
    """A zero-padded random code, unique among the codes still claimable.

    Uniqueness only has to hold across *live* codes: an expired or claimed code
    can never be redeemed again, so reusing its digits later is harmless and
    keeps the space from thinning out over time.
    """
    now = now or datetime.utcnow()
    digits = max(4, settings.pairing_code_digits)
    upper_bound = 10**digits

    for _ in range(_MAX_CODE_ATTEMPTS):
        code = f"{secrets.randbelow(upper_bound):0{digits}d}"
        if find_claimable_by_code(session, code, now) is None:
            return code

    raise PairingError(
        PairingFailure.INVALID_CODE,
        "Could not allocate an unused pairing code; try again shortly.",
    )


def create_pairing(
    session: Session,
    hive: Hive,
    settings: Settings,
    now: datetime | None = None,
) -> PairingSession:
    """Issue a fresh code for ``hive``. The caller commits."""
    now = now or datetime.utcnow()
    purge_stale(session, settings, now)

    pairing = PairingSession(
        code=generate_code(session, settings, now),
        hive_id=hive.id,
        created_at=now,
        expires_at=now + timedelta(seconds=settings.pairing_ttl_seconds),
    )
    session.add(pairing)
    session.flush()
    logger.info("Pairing code issued for hive %s (expires %s)", hive.id, pairing.expires_at)
    return pairing


def purge_stale(
    session: Session, settings: Settings, now: datetime | None = None
) -> int:
    """Delete long-dead pairings so the table stays small.

    Only rows well past their usefulness are removed, so a manager app polling
    a recently expired code still gets a truthful EXPIRED rather than a 404.
    """
    now = now or datetime.utcnow()
    cutoff = now - timedelta(seconds=settings.pairing_retention_seconds)
    # "fetch" keeps the session's identity map in step with the bulk delete, so
    # a caller still holding one of these rows sees it gone rather than
    # tripping over a stale reference on the next access.
    statement = delete(PairingSession).where(PairingSession.created_at < cutoff)
    result = session.exec(
        statement.execution_options(synchronize_session="fetch")
    )
    return int(result.rowcount or 0)


# ----------------------------------------------------------------------
# Claiming
# ----------------------------------------------------------------------


def find_claimable_by_code(
    session: Session, code: str, now: datetime | None = None
) -> PairingSession | None:
    """The one live pairing carrying ``code``, if any."""
    now = now or datetime.utcnow()
    rows = session.exec(
        select(PairingSession)
        .where(PairingSession.code == code)
        .order_by(desc(PairingSession.created_at))
    ).all()
    for row in rows:
        if is_claimable(row, now):
            return row
    return None


def claim(
    session: Session,
    code: str,
    device_id: str,
    settings: Settings,
    now: datetime | None = None,
) -> ClaimResult:
    """Redeem ``code`` for ``device_id``, binding the device to the hive.

    Raises :class:`PairingError` with a specific failure so the app can tell
    the beekeeper whether to retype the code or ask for a new one. The caller
    commits.
    """
    now = now or datetime.utcnow()
    normalised = code.strip().replace("-", "").replace(" ", "")

    if not normalised.isdigit():
        raise PairingError(
            PairingFailure.INVALID_CODE, "코드는 숫자 6자리여야 합니다."
        )

    # Look at every pairing with these digits, newest first, so we can say
    # *why* it failed rather than a flat "invalid".
    candidates = session.exec(
        select(PairingSession)
        .where(PairingSession.code == normalised)
        .order_by(desc(PairingSession.created_at))
    ).all()

    if not candidates:
        raise PairingError(
            PairingFailure.INVALID_CODE, "존재하지 않는 코드입니다. 다시 확인해주세요."
        )

    live = next((row for row in candidates if is_claimable(row, now)), None)
    if live is None:
        newest = candidates[0]
        if newest.claimed_at is not None:
            raise PairingError(
                PairingFailure.ALREADY_CLAIMED,
                "이미 사용된 코드입니다. 새 코드를 발급받아주세요.",
            )
        raise PairingError(
            PairingFailure.EXPIRED,
            "만료된 코드입니다. 새 코드를 발급받아주세요.",
        )

    hive = session.get(Hive, live.hive_id)
    if hive is None:  # pragma: no cover - only if a hive was deleted mid-flight
        raise PairingError(
            PairingFailure.INVALID_CODE, "연결하려는 벌통을 찾을 수 없습니다."
        )

    live.claimed_at = now
    live.claimed_device_id = device_id
    session.add(live)

    bind_device_to_hive(session, device_id=device_id, hive_id=hive.id)
    session.flush()

    logger.info("Pairing %s claimed by device %s for hive %s", live.id, device_id, hive.id)
    return ClaimResult(
        hive_id=hive.id,
        hive_name=hive.name,
        device_id=device_id,
        pairing_id=live.id,
    )


# ----------------------------------------------------------------------
# Device binding — shared with POST /api/devices
# ----------------------------------------------------------------------


def bind_device_to_hive(
    session: Session, *, device_id: str, hive_id: str | None
) -> MonitoringDevice:
    """Register (or re-register) a monitoring phone against a hive.

    **One row per device.** A phone is physically in front of exactly one hive,
    so re-pairing it *moves* it rather than adding a second registration. If it
    accumulated rows instead, the hive it left would keep a device record that
    looks real, and the beekeeper would see two devices for one phone.

    Idempotent: an app restart, a repeated registration, a heartbeat and a
    pairing claim all converge on the same row. Passing ``hive_id=None`` leaves
    an existing binding alone, which is what a manager phone registering itself
    should do.

    Shared by the pairing claim, ``POST /api/devices`` and the heartbeat so all
    three bind a device the same way. The caller commits.
    """
    device = session.exec(
        select(MonitoringDevice).where(
            MonitoringDevice.device_identifier == device_id
        )
    ).first()

    if device is None:
        device = MonitoringDevice(
            hive_id=hive_id or "",
            device_identifier=device_id,
        )
    elif hive_id and device.hive_id != hive_id:
        logger.info(
            "Device %s moved from hive %s to %s",
            device_id,
            device.hive_id or "(none)",
            hive_id,
        )
        device.hive_id = hive_id

    session.add(device)
    session.flush()
    return device
