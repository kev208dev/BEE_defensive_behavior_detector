"""Request and response models for the HTTP API.

The field names here are the contract the Flutter app is generated against,
so they follow the specification exactly (snake_case on the wire).
"""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field

from app.enums import AlertSeverity, HiveStatus, PairingFailure, PairingStatus

# ----------------------------------------------------------------------
# Health
# ----------------------------------------------------------------------


class HealthResponse(BaseModel):
    """Surfaces which adapters are live so the demo operator can verify setup."""

    status: str = "ok"
    detector_mode: str
    audio_model_mode: str
    notification_mode: str
    version: str = "0.1.0"
    server_time: datetime


# ----------------------------------------------------------------------
# Hives
# ----------------------------------------------------------------------


class HiveSummary(BaseModel):
    """One row of the hive list / dashboard."""

    id: str
    name: str
    location: str | None = None
    status: HiveStatus
    risk_score: int
    hornet_count: int
    max_hornet_count: int
    audio_probability: float
    last_updated: datetime
    monitoring_online: bool
    last_heartbeat: datetime | None = None


class HiveDetail(HiveSummary):
    """Everything the Hive Detail screen needs."""

    last_analyzed_at: datetime | None = None
    latest_snapshot_url: str | None = None
    persistence_ratio: float = 0.0
    growth_per_second: float = 0.0
    camera_ok: bool = False
    microphone_ok: bool = False
    monitoring: bool = False
    status_reason: str = ""
    recent_alerts: list["AlertSummary"] = Field(default_factory=list)


class HiveStatusResponse(BaseModel):
    """Lightweight polling endpoint for a single hive."""

    hive_id: str
    status: HiveStatus
    risk_score: int
    hornet_count: int
    max_hornet_count: int
    audio_probability: float
    monitoring_online: bool
    last_heartbeat: datetime | None = None
    last_analyzed_at: datetime | None = None
    status_reason: str = ""
    breakdown: dict[str, float] = Field(default_factory=dict)


class DashboardSummary(BaseModel):
    """Counts shown at the top of the manager dashboard."""

    total: int
    normal: int
    caution: int
    danger: int
    offline: int
    hives: list[HiveSummary] = Field(default_factory=list)
    recent_alerts: list["AlertSummary"] = Field(default_factory=list)


# ----------------------------------------------------------------------
# Alerts
# ----------------------------------------------------------------------


class AlertSummary(BaseModel):
    """One row of the alert list."""

    id: str
    hive_id: str
    hive_name: str
    timestamp: datetime
    severity: AlertSeverity
    risk_score: int
    hornet_count: int
    message: str


class AlertDetail(AlertSummary):
    """Everything the Alert Detail screen needs, including the reasoning."""

    max_hornet_count: int
    audio_probability: float
    persistence_ratio: float
    growth_per_second: float
    thumbnail_url: str | None = None
    clip_url: str | None = None
    explanation: str = ""
    resolved_at: datetime | None = None


# ----------------------------------------------------------------------
# Monitoring uploads
# ----------------------------------------------------------------------


class FrameResponse(BaseModel):
    """Answer to ``POST /api/monitor/frame`` — drives the Live screen."""

    status: HiveStatus
    risk_score: int
    hornet_count: int
    confidence: float
    processed_at: datetime
    max_hornet_count: int = 0
    audio_probability: float = 0.0
    snapshot_url: str | None = None
    alert_id: str | None = None


class AudioResponse(BaseModel):
    """Answer to ``POST /api/monitor/audio``."""

    hornet_probability: float
    processed_at: datetime
    status: HiveStatus | None = None
    risk_score: int | None = None


class HeartbeatRequest(BaseModel):
    """Body of ``POST /api/monitor/heartbeat``."""

    hive_id: str
    device_id: str
    timestamp: datetime | None = None
    camera_ok: bool = True
    microphone_ok: bool = True
    monitoring: bool = True


class HeartbeatResponse(BaseModel):
    """Lets the monitoring phone mirror the server's view of the hive."""

    acknowledged: bool = True
    hive_id: str
    status: HiveStatus
    risk_score: int
    server_time: datetime
    next_heartbeat_seconds: float


# ----------------------------------------------------------------------
# Devices
# ----------------------------------------------------------------------


class DeviceRegistrationRequest(BaseModel):
    """Body of ``POST /api/devices``."""

    device_id: str
    hive_id: str | None = None
    role: str = "monitor"
    platform: str = "unknown"


class DeviceRegistrationResponse(BaseModel):
    id: str
    device_id: str
    hive_id: str | None = None
    registered_at: datetime


class PushTokenRequest(BaseModel):
    """Body of ``POST /api/devices/push-token``."""

    token: str
    platform: str = "unknown"
    device_id: str | None = None


class PushTokenResponse(BaseModel):
    id: str
    token: str
    platform: str
    registered_at: datetime


# ----------------------------------------------------------------------
# Pairing
# ----------------------------------------------------------------------


class PairingCreateRequest(BaseModel):
    """Body of ``POST /api/pairings`` — the manager app asks a hive for a code."""

    hive_id: str


class PairingCreateResponse(BaseModel):
    """The code to display as a QR image and as six digits."""

    id: str
    code: str
    hive_id: str
    hive_name: str = ""
    expires_at: datetime
    #: Seconds left at the moment of the response, so the app can run a
    #: countdown without trusting the phone's clock to match the server's.
    expires_in_seconds: int = 0
    #: What the QR image should encode.
    pair_uri: str = ""


class PairingStatusResponse(BaseModel):
    """Answer to ``GET /api/pairings/{id}`` — polled while the sheet is open."""

    id: str
    code: str
    status: PairingStatus
    hive_id: str
    hive_name: str = ""
    claimed_device_id: str | None = None
    expires_at: datetime
    expires_in_seconds: int = 0


class PairingClaimRequest(BaseModel):
    """Body of ``POST /api/pairings/claim`` — the monitoring phone redeems."""

    code: str
    device_id: str


class PairingClaimResponse(BaseModel):
    """What the monitoring phone stores locally after a successful claim."""

    success: bool = True
    hive_id: str
    hive_name: str
    device_id: str
    pairing_id: str


class PairingErrorResponse(BaseModel):
    """Body of a rejected claim, so the app can explain what went wrong."""

    success: bool = False
    reason: PairingFailure
    message: str


# ----------------------------------------------------------------------
# Demo helpers
# ----------------------------------------------------------------------


class DemoResetResponse(BaseModel):
    reset: bool = True
    hives_seeded: int
    detections_cleared: int
    alerts_cleared: int


class DemoCreateAlertRequest(BaseModel):
    hive_id: str
    severity: AlertSeverity = AlertSeverity.DANGER
    risk_score: int = 82
    hornet_count: int = 6
    max_hornet_count: int = 7
    audio_probability: float = 0.74


class DemoObserveRequest(BaseModel):
    """Injects a single synthetic observation.

    Used by the real-time demo replay, which feeds the scenario in one second
    at a time so an audience can watch the risk score climb.
    """

    hive_id: str
    hornet_count: int = 0
    audio_probability: float | None = None


class DemoObserveResponse(BaseModel):
    hive_id: str
    status: HiveStatus
    risk_score: int
    hornet_count: int
    max_hornet_count: int
    audio_probability: float
    alert_created: bool = False
    alert_id: str | None = None
    alert_reason: str = ""
    notifications_sent: int = 0


class DemoScriptRequest(BaseModel):
    """Queues hornet counts for the mock detector to return for a hive.

    This is what lets the *camera* path be demonstrated without live hornets:
    the phone uploads genuine frames, and the mock detector answers with the
    scripted counts, so the Risk Engine and the alert state machine downstream
    are doing entirely real work.
    """

    hive_id: str
    #: Counts returned for the next frames, in order. Empty = replay the
    #: default competition scenario at one count per frame.
    counts: list[int] = Field(default_factory=list)
    #: Audio probabilities returned for the next chunks, in order.
    audio_probabilities: list[float] = Field(default_factory=list)


class DemoScriptResponse(BaseModel):
    hive_id: str
    frames_queued: int
    audio_chunks_queued: int


class DemoSimulateRequest(BaseModel):
    """Replays the scripted competition scenario against one hive."""

    hive_id: str
    #: Frames per simulated second; 1.0 matches the mobile app's default rate.
    frames_per_second: float = 1.0
    #: Also feed the audio channel so the fusion path is exercised.
    include_audio: bool = True
    #: Wipe this hive's history before replaying, for a repeatable demo.
    reset_first: bool = True


class DemoSimulateStep(BaseModel):
    offset_seconds: float
    hornet_count: int
    audio_probability: float
    risk_score: int
    status: HiveStatus
    alert_created: bool = False


class DemoSimulateResponse(BaseModel):
    hive_id: str
    steps: list[DemoSimulateStep]
    alerts_created: int
    notifications_sent: int


# Resolve the forward references used above.
HiveDetail.model_rebuild()
DashboardSummary.model_rebuild()
