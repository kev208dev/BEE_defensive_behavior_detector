"""Development notification sender — prints instead of pushing.

This is the default.  It keeps the backend fully functional with no Firebase
project, no service-account JSON and no network access, which is what lets the
whole pipeline be demonstrated and tested offline.
"""

from __future__ import annotations

import logging

from app.notifications.sender import NotificationSender, PushPayload

logger = logging.getLogger(__name__)


class ConsoleNotificationSender(NotificationSender):
    """Logs the notification that *would* have been pushed."""

    name = "console"

    def __init__(self) -> None:
        #: Everything sent so far, so tests and the demo script can assert on it.
        self.sent: list[tuple[PushPayload, list[str]]] = []

    def send(self, payload: PushPayload, tokens: list[str]) -> int:
        self.sent.append((payload, list(tokens)))
        logger.warning(
            "\n"
            "==================== PUSH NOTIFICATION ====================\n"
            " severity : %s\n"
            " hive     : %s\n"
            " alert    : %s\n"
            " title    : %s\n"
            " body     : %s\n"
            " deeplink : /alerts/%s\n"
            " targets  : %d registered device(s)\n"
            "===========================================================",
            payload.severity,
            payload.hive_id,
            payload.alert_id,
            payload.title,
            payload.body,
            payload.alert_id,
            len(tokens),
        )
        return len(tokens)
