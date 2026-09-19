"""Domain enums shared by the API, the database and the Risk Engine.

Deliberately dependency-free so the pure Risk Engine can import them without
pulling in SQLModel or FastAPI.
"""

from __future__ import annotations

from enum import Enum


class HiveStatus(str, Enum):
    """Operational status of a single hive."""

    NORMAL = "NORMAL"
    CAUTION = "CAUTION"
    DANGER = "DANGER"
    OFFLINE = "OFFLINE"

    @property
    def rank(self) -> int:
        """Ordering used by the alert state machine.

        OFFLINE is not part of the escalation ladder — it is a liveness
        condition, not a threat level — so it shares rank 0 with NORMAL.
        """
        return _STATUS_RANK[self]


_STATUS_RANK: dict[HiveStatus, int] = {
    HiveStatus.OFFLINE: 0,
    HiveStatus.NORMAL: 0,
    HiveStatus.CAUTION: 1,
    HiveStatus.DANGER: 2,
}


class AlertSeverity(str, Enum):
    """Severity of a generated alert."""

    CAUTION = "CAUTION"
    DANGER = "DANGER"

    @property
    def rank(self) -> int:
        return 1 if self is AlertSeverity.CAUTION else 2
