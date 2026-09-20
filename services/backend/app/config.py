"""Central configuration for the beehive hornet-attack detection backend.

Every tunable value of the system lives here so that the Risk Engine, the
alert state machine and the AI adapter selection can be changed without
touching code.  Values are read from the environment (or a ``.env`` file).

IMPORTANT — scientific disclaimer
---------------------------------
The risk weights and thresholds below are **MVP validation heuristics**.
They are NOT scientifically validated criteria for a real hornet mass attack.
They exist so the end-to-end pipeline can be demonstrated and tuned; any
field deployment must re-derive them from real observational data.
"""

from __future__ import annotations

from enum import Enum
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_ROOT = Path(__file__).resolve().parent.parent


class DetectorMode(str, Enum):
    """Which vision detector implementation to use."""

    MOCK = "mock"
    YOLO = "yolo"


class AudioModelMode(str, Enum):
    """Which audio classifier implementation to use."""

    MOCK = "mock"
    LIBROSA = "librosa"


class NotificationMode(str, Enum):
    """Which push notification backend to use."""

    CONSOLE = "console"
    FIREBASE = "firebase"


class Settings(BaseSettings):
    """Application settings, overridable through environment variables."""

    model_config = SettingsConfigDict(
        env_file=str(BACKEND_ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # ------------------------------------------------------------------
    # Server / storage
    # ------------------------------------------------------------------
    app_name: str = "Beehive Hornet Defense API"
    debug: bool = True
    database_url: str = f"sqlite:///{BACKEND_ROOT / 'beehive.db'}"
    storage_dir: Path = BACKEND_ROOT / "storage"
    snapshot_dir: Path = BACKEND_ROOT / "storage" / "snapshots"
    seed_on_startup: bool = True
    seed_file: Path = BACKEND_ROOT / "data" / "seed_hives.json"

    # Public base URL used when building thumbnail/clip URLs returned to the
    # mobile app.  Override in production, e.g. https://api.example.com
    public_base_url: str = ""

    # ------------------------------------------------------------------
    # AI adapter selection (all default to mock so the stack runs with no
    # model weights, no audio model and no Firebase credentials at all)
    # ------------------------------------------------------------------
    detector_mode: DetectorMode = DetectorMode.MOCK
    audio_model_mode: AudioModelMode = AudioModelMode.MOCK
    notification_mode: NotificationMode = NotificationMode.CONSOLE

    yolo_model_path: str = ""
    yolo_confidence_threshold: float = 0.35
    # Class names that count as a hornet.  Kept configurable because a custom
    # trained model may label the class differently (hornet / wasp / vespa...).
    yolo_hornet_classes: str = "hornet,wasp,vespa"

    audio_model_path: str = ""
    firebase_credentials_path: str = ""

    # ------------------------------------------------------------------
    # Risk Engine — analysis window
    # ------------------------------------------------------------------
    risk_window_seconds: float = 30.0
    # Audio observations older than this are ignored when fusing with vision.
    audio_freshness_seconds: float = 20.0

    # ------------------------------------------------------------------
    # Risk Engine — component weights (should sum to 1.0)
    # ------------------------------------------------------------------
    weight_visual_count: float = 0.40
    weight_persistence: float = 0.25
    weight_growth: float = 0.20
    weight_audio: float = 0.15

    # ------------------------------------------------------------------
    # Risk Engine — component normalisation
    # ------------------------------------------------------------------
    # Hornet count that maps to a full visual sub-score of 100.
    count_saturation: float = 6.0
    # Weight applied to the recent *maximum* count vs. the *current* count,
    # so a brief dip between frames does not collapse the score.
    recent_max_blend: float = 0.35
    # Growth (hornets/second) that maps to a full growth sub-score of 100.
    growth_saturation: float = 0.30
    # A single isolated detection should not produce a high persistence score;
    # persistence needs at least this many frames in the window to count.
    persistence_min_frames: int = 3

    # ------------------------------------------------------------------
    # Risk Engine — status thresholds
    # ------------------------------------------------------------------
    caution_threshold: float = 35.0
    danger_threshold: float = 65.0

    # ------------------------------------------------------------------
    # Device liveness
    # ------------------------------------------------------------------
    # A hive whose monitoring phone has not sent a heartbeat within this many
    # seconds is reported as OFFLINE.
    offline_after_seconds: float = 45.0
    heartbeat_interval_seconds: float = 10.0

    # ------------------------------------------------------------------
    # Device pairing
    # ------------------------------------------------------------------
    # How long a pairing code stays claimable. Short enough that a code read
    # off someone's screen is useless later, long enough to walk to the hive.
    pairing_ttl_seconds: float = 600.0
    # Digits in a pairing code. Six is what a person can retype from a screen.
    pairing_code_digits: int = 6
    # Claim attempts allowed from one client inside the window. A six-digit
    # code is only a million possibilities, so the claim endpoint has to be
    # throttled or it is brute-forceable.
    pairing_claim_max_attempts: int = 10
    pairing_claim_window_seconds: float = 300.0
    # Claimed/expired codes older than this are swept when a new code is made,
    # so the table does not grow without bound.
    pairing_retention_seconds: float = 86_400.0

    # ------------------------------------------------------------------
    # Alert state machine / de-duplication
    # ------------------------------------------------------------------
    # Minimum gap between two alerts of the same severity for one hive.
    alert_cooldown_seconds: float = 60.0
    # After an alert, the hive must stay below the alerting severity for this
    # long before the same severity may raise a *new* alert.
    alert_recovery_seconds: float = 120.0
    # Emit an alert when the hive is promoted to CAUTION as well as DANGER.
    alert_on_caution: bool = True

    @property
    def yolo_hornet_class_set(self) -> set[str]:
        """Normalised set of class names that are treated as hornets."""
        return {
            name.strip().lower()
            for name in self.yolo_hornet_classes.split(",")
            if name.strip()
        }


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return the process-wide settings singleton."""
    return Settings()
