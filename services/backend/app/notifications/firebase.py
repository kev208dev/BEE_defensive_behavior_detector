"""Firebase Cloud Messaging sender.

``firebase-admin`` and the service-account credentials are both optional; the
import and the SDK initialisation happen in the constructor so that a backend
running in console mode never touches them.  A failure here raises
:class:`NotificationUnavailable`, and the factory falls back to the console
sender rather than letting the service fail to start.
"""

from __future__ import annotations

import logging
from pathlib import Path

from app.config import Settings
from app.notifications.sender import NotificationSender, PushPayload

logger = logging.getLogger(__name__)


class NotificationUnavailable(RuntimeError):
    """Raised when the Firebase sender cannot be constructed."""


class FirebaseNotificationSender(NotificationSender):
    """Sends real FCM messages to the registered manager phones."""

    name = "firebase"

    def __init__(self, settings: Settings) -> None:
        try:
            import firebase_admin  # noqa: PLC0415 - deliberately lazy
            from firebase_admin import credentials, messaging  # noqa: PLC0415
        except ImportError as exc:  # pragma: no cover - depends on environment
            raise NotificationUnavailable(
                "firebase-admin is not installed. "
                "Run: pip install -r requirements-ai.txt"
            ) from exc

        self._messaging = messaging

        credentials_path = settings.firebase_credentials_path.strip()
        try:
            if firebase_admin._apps:  # noqa: SLF001 - the SDK's only "is init" check
                self._app = firebase_admin.get_app()
            elif credentials_path:
                if not Path(credentials_path).exists():
                    raise NotificationUnavailable(
                        f"Firebase credentials not found: {credentials_path}"
                    )
                self._app = firebase_admin.initialize_app(
                    credentials.Certificate(credentials_path)
                )
            else:
                # Falls back to GOOGLE_APPLICATION_CREDENTIALS / workload identity.
                self._app = firebase_admin.initialize_app()
        except NotificationUnavailable:
            raise
        except Exception as exc:  # pragma: no cover - depends on credentials
            raise NotificationUnavailable(
                f"Could not initialise Firebase: {exc}"
            ) from exc

        logger.info("Firebase notification sender ready")

    def send(self, payload: PushPayload, tokens: list[str]) -> int:
        """Push to every registered token, reporting how many succeeded."""
        if not tokens:
            logger.info("No push tokens registered — nothing to send")
            return 0

        message = self._messaging.MulticastMessage(
            tokens=tokens,
            notification=self._messaging.Notification(
                title=payload.title,
                body=payload.body,
            ),
            data=payload.as_data(),
            android=self._messaging.AndroidConfig(
                priority="high",
                notification=self._messaging.AndroidNotification(
                    channel_id="hornet_alerts",
                    sound="default",
                ),
            ),
            apns=self._messaging.APNSConfig(
                payload=self._messaging.APNSPayload(
                    aps=self._messaging.Aps(sound="default"),
                ),
            ),
        )

        try:
            response = self._messaging.send_each_for_multicast(message)
        except Exception as exc:  # noqa: BLE001 - delivery must never raise
            logger.error("FCM delivery failed: %s", exc)
            return 0

        if response.failure_count:
            logger.warning(
                "FCM: %d delivered, %d failed",
                response.success_count,
                response.failure_count,
            )
        return int(response.success_count)
