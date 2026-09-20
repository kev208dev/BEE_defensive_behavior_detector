"""Builds the configured notification sender, degrading to console on failure."""

from __future__ import annotations

import logging

from app.config import NotificationMode, Settings
from app.notifications.console import ConsoleNotificationSender
from app.notifications.sender import NotificationSender

logger = logging.getLogger(__name__)

_sender: NotificationSender | None = None


def build_sender(settings: Settings) -> NotificationSender:
    """Construct the sender named by ``NOTIFICATION_MODE``."""
    if settings.notification_mode is NotificationMode.FIREBASE:
        try:
            from app.notifications.firebase import FirebaseNotificationSender

            return FirebaseNotificationSender(settings)
        except Exception as exc:  # noqa: BLE001 - any failure must degrade
            logger.warning(
                "Firebase sender unavailable (%s). Falling back to console. "
                "Manager phones can still receive alerts through the polling "
                "fallback in the mobile app.",
                exc,
            )
    return ConsoleNotificationSender()


def get_sender(settings: Settings) -> NotificationSender:
    """Return the process-wide sender, building it on first use."""
    global _sender
    if _sender is None:
        _sender = build_sender(settings)
        logger.info("Notification sender: %s", _sender.name)
    return _sender


def reset() -> None:
    """Drop the cached sender — used by tests."""
    global _sender
    _sender = None
