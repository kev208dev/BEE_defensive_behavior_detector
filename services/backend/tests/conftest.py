"""Shared pytest fixtures.

Each test gets a throwaway SQLite file and a fresh set of cached singletons
(settings, engine, AI adapters, notification sender) so tests cannot leak
state into one another.
"""

from __future__ import annotations

from collections.abc import Iterator
from datetime import datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel

from app import db as db_module
from app.ai import factory as ai_factory
from app.config import Settings, get_settings
from app.models import Hive
from app.notifications import factory as notification_factory
from app.notifications.console import ConsoleNotificationSender


@pytest.fixture
def settings(tmp_path: Path) -> Settings:
    """Settings pointed at a temporary database and snapshot directory."""
    return Settings(
        database_url=f"sqlite:///{tmp_path / 'test.db'}",
        storage_dir=tmp_path / "storage",
        snapshot_dir=tmp_path / "storage" / "snapshots",
        seed_on_startup=False,
        public_base_url="",
    )


@pytest.fixture(autouse=True)
def _reset_singletons() -> Iterator[None]:
    """Clear every module-level cache before and after each test."""
    get_settings.cache_clear()
    db_module.reset_engine()
    ai_factory.reset()
    notification_factory.reset()
    yield
    get_settings.cache_clear()
    db_module.reset_engine()
    ai_factory.reset()
    notification_factory.reset()


@pytest.fixture
def session(settings: Settings) -> Iterator[Session]:
    """A database session against a freshly created schema."""
    engine = db_module.get_engine(settings)
    SQLModel.metadata.create_all(engine)
    with Session(engine) as db_session:
        yield db_session


@pytest.fixture
def hive(session: Session) -> Hive:
    """A single hive to attach observations to."""
    row = Hive(id="hive-test", name="테스트 벌통", location="테스트 구역")
    session.add(row)
    session.commit()
    session.refresh(row)
    return row


@pytest.fixture
def sender() -> ConsoleNotificationSender:
    """A console sender whose `sent` list can be asserted on."""
    return ConsoleNotificationSender()


@pytest.fixture
def base_time() -> datetime:
    """A fixed clock so every test is deterministic."""
    return datetime(2026, 1, 1, 12, 0, 0)


@pytest.fixture
def client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    """A TestClient wired to a temporary database, in full mock mode."""
    monkeypatch.setenv("DATABASE_URL", f"sqlite:///{tmp_path / 'api.db'}")
    monkeypatch.setenv("STORAGE_DIR", str(tmp_path / "storage"))
    monkeypatch.setenv("SNAPSHOT_DIR", str(tmp_path / "storage" / "snapshots"))
    monkeypatch.setenv("DETECTOR_MODE", "mock")
    monkeypatch.setenv("AUDIO_MODEL_MODE", "mock")
    monkeypatch.setenv("NOTIFICATION_MODE", "console")
    monkeypatch.setenv("SEED_ON_STARTUP", "true")

    get_settings.cache_clear()
    db_module.reset_engine()

    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client


def observations_at(
    base: datetime, counts: list[int], step_seconds: float = 1.0
) -> list[tuple[datetime, int]]:
    """Build ``(timestamp, hornet_count)`` pairs spaced evenly in time."""
    return [
        (base + timedelta(seconds=index * step_seconds), count)
        for index, count in enumerate(counts)
    ]
