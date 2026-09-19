"""SQLModel database tables.

Kept intentionally flat — a single SQLite database is all the MVP needs.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlmodel import Field, SQLModel

from app.enums import AlertSeverity, HiveStatus


def _uuid() -> str:
    return uuid.uuid4().hex


def _now() -> datetime:
    return datetime.utcnow()


class Hive(SQLModel, table=True):
    """A beehive and its most recently computed state.

    The denormalised ``status`` / ``risk_score`` columns are a cache of the
    last analysis so that ``GET /api/hives`` stays a single cheap query; the
    authoritative history lives in :class:`VisionDetection`.
    """

    __tablename__ = "hives"

    id: str = Field(default_factory=_uuid, primary_key=True)
    name: str = Field(index=True)
    location: str | None = None
    status: HiveStatus = Field(default=HiveStatus.OFFLINE)
    risk_score: int = Field(default=0)
    current_hornet_count: int = Field(default=0)
    max_hornet_count: int = Field(default=0)
    audio_probability: float = Field(default=0.0)
    audio_updated_at: datetime | None = Field(default=None)
    latest_snapshot_path: str | None = Field(default=None)
    last_analyzed_at: datetime | None = Field(default=None)
    last_updated: datetime = Field(default_factory=_now)
    created_at: datetime = Field(default_factory=_now)


class MonitoringDevice(SQLModel, table=True):
    """A phone acting as the camera/microphone in front of a hive."""

    __tablename__ = "monitoring_devices"

    id: str = Field(default_factory=_uuid, primary_key=True)
    hive_id: str = Field(foreign_key="hives.id", index=True)
    device_identifier: str = Field(index=True)
    last_heartbeat: datetime | None = Field(default=None)
    camera_ok: bool = Field(default=False)
    microphone_ok: bool = Field(default=False)
    monitoring: bool = Field(default=False)
    created_at: datetime = Field(default_factory=_now)


class VisionDetection(SQLModel, table=True):
    """One analysed camera frame."""

    __tablename__ = "vision_detections"

    id: str = Field(default_factory=_uuid, primary_key=True)
    hive_id: str = Field(foreign_key="hives.id", index=True)
    device_id: str | None = Field(default=None)
    timestamp: datetime = Field(default_factory=_now, index=True)
    hornet_count: int = Field(default=0)
    max_confidence: float = Field(default=0.0)
    snapshot_path: str | None = Field(default=None)


class AudioDetection(SQLModel, table=True):
    """One analysed audio chunk."""

    __tablename__ = "audio_detections"

    id: str = Field(default_factory=_uuid, primary_key=True)
    hive_id: str = Field(foreign_key="hives.id", index=True)
    device_id: str | None = Field(default=None)
    timestamp: datetime = Field(default_factory=_now, index=True)
    hornet_probability: float = Field(default=0.0)


class Alert(SQLModel, table=True):
    """A de-duplicated threat event raised by the alert state machine."""

    __tablename__ = "alerts"

    id: str = Field(default_factory=_uuid, primary_key=True)
    hive_id: str = Field(foreign_key="hives.id", index=True)
    timestamp: datetime = Field(default_factory=_now, index=True)
    severity: AlertSeverity = Field(default=AlertSeverity.CAUTION)
    risk_score: int = Field(default=0)
    hornet_count: int = Field(default=0)
    max_hornet_count: int = Field(default=0)
    audio_probability: float = Field(default=0.0)
    persistence_ratio: float = Field(default=0.0)
    growth_per_second: float = Field(default=0.0)
    thumbnail_url: str | None = Field(default=None)
    clip_url: str | None = Field(default=None)
    message: str = Field(default="")
    explanation: str = Field(default="")
    resolved_at: datetime | None = Field(default=None)


class PairingSession(SQLModel, table=True):
    """A short-lived code that binds a monitoring phone to a hive.

    Replaces the old flow where the beekeeper typed a server address and picked
    a hive by hand. The manager phone asks for a code, the monitoring phone
    redeems it, and the binding is recorded here and on
    :class:`MonitoringDevice`.

    Note that ``claimed_at`` being ``None`` does not mean the code is still
    usable — expiry is derived from ``expires_at`` against the current time, so
    no background job is needed to retire stale codes.
    """

    __tablename__ = "pairing_sessions"

    id: str = Field(default_factory=_uuid, primary_key=True)
    code: str = Field(index=True)
    hive_id: str = Field(foreign_key="hives.id", index=True)
    created_at: datetime = Field(default_factory=_now)
    expires_at: datetime = Field(index=True)
    claimed_at: datetime | None = Field(default=None)
    claimed_device_id: str | None = Field(default=None)


class PushDevice(SQLModel, table=True):
    """An FCM registration token belonging to a manager phone."""

    __tablename__ = "push_devices"

    id: str = Field(default_factory=_uuid, primary_key=True)
    token: str = Field(index=True, unique=True)
    platform: str = Field(default="unknown")
    device_identifier: str | None = Field(default=None)
    created_at: datetime = Field(default_factory=_now)
