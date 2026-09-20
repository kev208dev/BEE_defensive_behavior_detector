"""Configuration contracts that must also hold in an isolated deployment."""

from __future__ import annotations

import json

from sqlmodel import Session, select

from app import db as db_module
from app.config import BACKEND_ROOT, Settings
from app.models import Hive


def test_default_seed_file_is_packaged_inside_backend() -> None:
    """A Railway root of services/backend must still ship every demo hive."""
    settings = Settings(_env_file=None)

    assert settings.seed_file.is_relative_to(BACKEND_ROOT)
    definitions = json.loads(settings.seed_file.read_text(encoding="utf-8"))
    assert [row["id"] for row in definitions] == [
        "hive-a",
        "hive-b",
        "hive-c",
        "hive-d",
    ]


def test_seed_adds_missing_packaged_hives_to_a_partial_database(
    session: Session,
    settings: Settings,
) -> None:
    """A persistent DB created by an older seed gains only missing rows."""
    session.add(Hive(id="hive-a", name="사용자 지정 A", location="기존 위치"))
    session.commit()

    created = db_module.seed_hives(settings)

    assert created == 3
    hives = session.exec(select(Hive).order_by(Hive.id)).all()
    assert [hive.id for hive in hives] == ["hive-a", "hive-b", "hive-c", "hive-d"]
    assert hives[0].name == "사용자 지정 A"
