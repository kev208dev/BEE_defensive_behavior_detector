"""Shared FastAPI dependencies."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, HTTPException, status
from sqlmodel import Session

from app.config import Settings, get_settings
from app.db import get_session
from app.models import Hive

SessionDep = Annotated[Session, Depends(get_session)]
SettingsDep = Annotated[Settings, Depends(get_settings)]


def get_hive_or_404(session: Session, hive_id: str) -> Hive:
    """Look up a hive, raising a clean 404 when it does not exist."""
    hive = session.get(Hive, hive_id)
    if hive is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Hive not found: {hive_id}",
        )
    return hive
