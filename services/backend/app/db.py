"""Database engine, schema creation and seed data."""

from __future__ import annotations

import json
import logging
from collections.abc import Iterator
from pathlib import Path

from sqlalchemy.engine import Engine
from sqlmodel import Session, SQLModel, create_engine, select

from app.config import Settings, get_settings
from app.models import Hive

logger = logging.getLogger(__name__)

_engine: Engine | None = None


def get_engine(settings: Settings | None = None) -> Engine:
    """Return (and lazily build) the process-wide SQLAlchemy engine."""
    global _engine
    if _engine is None:
        settings = settings or get_settings()
        connect_args = (
            {"check_same_thread": False}
            if settings.database_url.startswith("sqlite")
            else {}
        )
        _engine = create_engine(
            settings.database_url,
            echo=False,
            connect_args=connect_args,
        )
    return _engine


def reset_engine() -> None:
    """Drop the cached engine — used by tests that swap the database URL."""
    global _engine
    if _engine is not None:
        _engine.dispose()
    _engine = None


def init_db(settings: Settings | None = None) -> None:
    """Create tables and storage directories, then seed if the DB is empty."""
    settings = settings or get_settings()
    engine = get_engine(settings)
    SQLModel.metadata.create_all(engine)

    Path(settings.snapshot_dir).mkdir(parents=True, exist_ok=True)

    if settings.seed_on_startup:
        seed_hives(settings)


def seed_hives(settings: Settings | None = None, *, force: bool = False) -> int:
    """Insert the sample hives when none exist yet.

    Returns the number of hives created.
    """
    settings = settings or get_settings()
    engine = get_engine(settings)

    with Session(engine) as session:
        existing = session.exec(select(Hive)).first()
        if existing is not None and not force:
            return 0

        hives = _load_seed_definitions(Path(settings.seed_file))
        created = 0
        for definition in hives:
            hive_id = definition["id"]
            if session.get(Hive, hive_id) is not None:
                continue
            session.add(
                Hive(
                    id=hive_id,
                    name=definition["name"],
                    location=definition.get("location"),
                )
            )
            created += 1
        session.commit()

    if created:
        logger.info("Seeded %d hives", created)
    return created


def _load_seed_definitions(seed_file: Path) -> list[dict[str, str]]:
    """Read seed hives from JSON, falling back to a built-in default."""
    fallback: list[dict[str, str]] = [
        {"id": "hive-a", "name": "벌통 A", "location": "1구역 동편"},
        {"id": "hive-b", "name": "벌통 B", "location": "1구역 서편"},
        {"id": "hive-c", "name": "벌통 C", "location": "2구역 남편"},
    ]
    if not seed_file.exists():
        logger.warning("Seed file %s not found — using built-in defaults", seed_file)
        return fallback
    try:
        data = json.loads(seed_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        logger.warning("Could not read seed file %s (%s) — using defaults", seed_file, exc)
        return fallback
    if not isinstance(data, list):
        logger.warning("Seed file %s is not a JSON list — using defaults", seed_file)
        return fallback
    return [item for item in data if isinstance(item, dict) and "id" in item and "name" in item]


def get_session() -> Iterator[Session]:
    """FastAPI dependency yielding a database session."""
    with Session(get_engine()) as session:
        yield session
