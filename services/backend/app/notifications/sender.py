"""Push notification interface and payload."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass(frozen=True)
class PushPayload:
    """What a manager phone receives when a DANGER alert is raised.

    ``alert_id`` / ``hive_id`` / ``severity`` are the three fields the mobile
    app needs to deep-link into ``/alerts/:id``.
    """

    alert_id: str
    hive_id: str
    severity: str
    title: str
    body: str
    extra: dict[str, str] = field(default_factory=dict)

    def as_data(self) -> dict[str, str]:
        """Flatten into the string-only data map that FCM requires."""
        data = {
            "alertId": self.alert_id,
            "hiveId": self.hive_id,
            "severity": self.severity,
            # Deep link target, so the app does not have to rebuild the route.
            "route": f"/alerts/{self.alert_id}",
        }
        data.update(self.extra)
        return data


class NotificationSender(ABC):
    """Delivers an alert to the manager phones."""

    name: str = "sender"

    @abstractmethod
    def send(self, payload: PushPayload, tokens: list[str]) -> int:
        """Deliver ``payload`` to ``tokens``.

        Returns the number of successful deliveries.  Implementations must not
        raise — a notification failure is never a reason to fail the request
        that produced the alert.
        """
