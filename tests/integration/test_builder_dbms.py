"""Smoke-тесты schema/builder.py на реальных PostgreSQL/MySQL (см. CLAUDE.md §8).

Требуют СУБД, поднятой через `docker-compose.test.yml`. Тесты читают URL
подключения из переменных окружения ``EVESDE_TEST_POSTGRES_URL`` /
``EVESDE_TEST_MYSQL_URL`` и
пропускаются (skip), если переменная не задана или СУБД недоступна --
поэтому обычный прогон `pytest` (без docker) остаётся зелёным.
"""

from __future__ import annotations

import os

import pytest
from sqlalchemy import create_engine, inspect
from sqlalchemy.engine import Engine
from sqlalchemy.exc import OperationalError

from evesde.schema.builder import create_mart_tables, create_raw_tables, drop_all, load_manifest

pytestmark = pytest.mark.dbms


def _dbms_engine(env_var: str) -> Engine:
    url = os.environ.get(env_var)
    if not url:
        pytest.skip(f"{env_var} не задан -- нужна СУБД из docker-compose.test.yml")
    engine = create_engine(url)
    try:
        with engine.connect():
            pass
    except OperationalError as exc:
        pytest.skip(f"СУБД по {env_var} недоступна: {exc}")
    return engine


def _smoke_create_all_and_drop_all(engine: Engine) -> None:
    manifest = load_manifest()
    drop_all(engine, manifest)  # подчищаем мусор от предыдущего прогона
    create_raw_tables(engine, manifest)
    create_mart_tables(engine, manifest)

    inspector = inspect(engine)
    table_names = set(inspector.get_table_names())
    assert table_names == set(manifest["tables"])

    drop_all(engine, manifest)
    assert inspect(engine).get_table_names() == []


def test_create_all_and_drop_all_on_postgres() -> None:
    _smoke_create_all_and_drop_all(_dbms_engine("EVESDE_TEST_POSTGRES_URL"))


def test_create_all_and_drop_all_on_mysql() -> None:
    _smoke_create_all_and_drop_all(_dbms_engine("EVESDE_TEST_MYSQL_URL"))
