"""Полная цепочка на реальных PostgreSQL/MariaDB: create tables -> load
фикстур -> marts -> verify -> API-запросы. Параметризовано по обеим СУБД.

Поднимаются через ``docker-compose.test.yml`` (см. README «Как запускать
тесты»). Без docker (переменные EVESDE_TEST_POSTGRES_URL/EVESDE_TEST_MYSQL_URL
не заданы или СУБД недоступна) тесты пропускаются -- обычный `pytest`
остаётся зелёным, как и в test_builder_dbms.py/test_loader_dbms.py.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.exc import OperationalError

from evesde import SDE
from evesde.etl.loader import load_all
from evesde.etl.marts import build_marts
from evesde.etl.verify import verify
from evesde.schema.builder import create_mart_tables, create_raw_tables, drop_all, load_manifest

pytestmark = pytest.mark.dbms

_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "sde_marts"


def _dbms_url(env_var: str) -> str:
    url = os.environ.get(env_var)
    if not url:
        pytest.skip(f"{env_var} не задан -- нужна СУБД из docker-compose.test.yml")
    engine = create_engine(url)
    try:
        with engine.connect():
            pass
    except OperationalError as exc:
        pytest.skip(f"СУБД по {env_var} недоступна: {exc}")
    finally:
        engine.dispose()
    return url


@pytest.fixture(
    params=["EVESDE_TEST_POSTGRES_URL", "EVESDE_TEST_MYSQL_URL"],
    ids=["postgres", "mariadb"],
)
def dbms_url(request: pytest.FixtureRequest) -> str:
    return _dbms_url(request.param)


def test_full_chain_create_load_marts_verify_api(dbms_url: str) -> None:
    """create_raw_tables -> create_mart_tables -> load_all -> build_marts ->
    verify -> публичный API -- вся цепочка на одной реальной СУБД за раз."""
    manifest = load_manifest()
    engine: Engine = create_engine(dbms_url)
    try:
        drop_all(engine, manifest)  # подчищаем мусор от предыдущего прогона

        create_raw_tables(engine, manifest)
        create_mart_tables(engine, manifest)

        load_result = load_all(engine, _FIXTURES_DIR, manifest)
        assert load_result.total_rows > 0
        assert load_result.skipped_files == []

        build_marts(engine)

        report = verify(engine, sde_dir=_FIXTURES_DIR, manifest=manifest)
        assert report.ok, report.summary()

        sde = SDE(dbms_url)
        try:
            item = sde.item("Rifter")
            assert item.group_name == "Frigate"
            assert item.category_name == "Ship"

            assert sde.stats("Rifter").high_slots == 3

            recipe = sde.industry(product="Rifter", activity="manufacturing")[0]
            assert {m.name for m in recipe.materials} == {"Tritanium", "Pyerite"}

            jita = sde.system("Jita")
            assert jita.region_name == "The Forge"
            assert jita.faction_name == "Guristas Pirates"  # COALESCE от региона

            agents = sde.agents(level=4, region="The Forge")
            assert {a.name for a in agents} == {"Ama Amagawa"}

            assert sde.meta().build_number == 3428504
        finally:
            sde.engine.dispose()
    finally:
        drop_all(engine, manifest)
        engine.dispose()
