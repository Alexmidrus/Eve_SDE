"""Smoke-тесты load_fresh на реальных PostgreSQL/MySQL (см. CLAUDE.md §8, T03).

Как и test_builder_dbms.py: требуют СУБД из docker-compose (T12); до этого
читают URL из EVESDE_TEST_POSTGRES_URL/EVESDE_TEST_MYSQL_URL и пропускаются
(skip), если переменная не задана или СУБД недоступна.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.engine import Engine
from sqlalchemy.exc import OperationalError

from evesde.config import SDEConfig
from evesde.etl.loader import load_fresh
from evesde.schema.builder import build_metadata, drop_all, load_manifest

pytestmark = pytest.mark.dbms

_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "sde_mini"


def _dbms_config(env_var: str) -> SDEConfig:
    url = os.environ.get(env_var)
    if not url:
        pytest.skip(f"{env_var} не задан -- нужна СУБД из docker-compose (см. T12)")
    engine = create_engine(url)
    try:
        with engine.connect():
            pass
    except OperationalError as exc:
        pytest.skip(f"СУБД по {env_var} недоступна: {exc}")
    finally:
        engine.dispose()
    return SDEConfig.from_url(url)


def _smoke_load_fresh(config: SDEConfig) -> None:
    manifest = load_manifest()
    engine: Engine = create_engine(config.url)
    try:
        drop_all(engine, manifest)  # подчищаем мусор от предыдущего прогона

        result = load_fresh(config, _FIXTURES_DIR, manifest)
        assert result.total_rows > 0

        metadata = build_metadata(manifest, layer="raw")
        with engine.connect() as conn:
            arc_name = (
                conn.execute(select(metadata.tables["epic_arcs"].c.name_en)).scalars().first()
            )
        assert arc_name == "Sisters of EVE"
    finally:
        drop_all(engine, manifest)
        engine.dispose()


def test_load_fresh_on_postgres() -> None:
    _smoke_load_fresh(_dbms_config("EVESDE_TEST_POSTGRES_URL"))


def test_load_fresh_on_mysql() -> None:
    _smoke_load_fresh(_dbms_config("EVESDE_TEST_MYSQL_URL"))
