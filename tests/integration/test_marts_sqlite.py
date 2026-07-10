"""Интеграционные тесты etl/marts.py на SQLite in-memory (CLAUDE.md §8)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.engine import Engine

from evesde.etl.loader import load_all
from evesde.etl.marts import build_marts
from evesde.schema.builder import (
    build_metadata,
    create_mart_tables,
    create_raw_tables,
    load_manifest,
)

_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "sde_marts"


@pytest.fixture(scope="module")
def manifest() -> dict[str, Any]:
    return load_manifest()


@pytest.fixture
def loaded_engine(manifest: dict[str, Any]) -> Engine:
    """SQLite-движок с загруженным raw-слоем (без витрин) на фикстурах sde_marts."""
    engine = create_engine("sqlite:///:memory:")
    create_raw_tables(engine, manifest)
    create_mart_tables(engine, manifest)
    load_all(engine, _FIXTURES_DIR, manifest)
    return engine


def _rows(engine: Engine, manifest: dict[str, Any], table_name: str) -> list[dict[str, Any]]:
    metadata = build_metadata(manifest)
    table = metadata.tables[table_name]
    with engine.connect() as conn:
        return [dict(row) for row in conn.execute(select(table)).mappings().all()]


def test_dim_items_contains_group_name(loaded_engine: Engine, manifest: dict[str, Any]) -> None:
    build_marts(loaded_engine)
    rows = {r["type_id"]: r for r in _rows(loaded_engine, manifest, "dim_items")}
    row = rows[587]
    assert row["group_id"] == 25
    assert row["group_name_en"] == "Frigate"
    assert row["category_name_en"] == "Ship"
    assert row["market_group_name_en"] == "Rifter"
    assert row["meta_group_name_en"] == "Tech I"
    assert row["race_name_en"] == "Minmatar"


def test_dim_universe_coalesces_region_faction(
    loaded_engine: Engine, manifest: dict[str, Any]
) -> None:
    """У системы (Jita) faction_id не указан напрямую -- берётся из региона (COALESCE)."""
    build_marts(loaded_engine)
    (row,) = _rows(loaded_engine, manifest, "dim_universe")
    assert row["solar_system_id"] == 30000142
    assert row["constellation_name_en"] == "Kimotoro"
    assert row["region_name_en"] == "The Forge"
    assert row["faction_id"] == 500001
    assert row["faction_name_en"] == "Guristas Pirates"


def test_type_common_stats_pivots_dogma_attributes(
    loaded_engine: Engine, manifest: dict[str, Any]
) -> None:
    """attributeID=9 -> structure_hp (FLOAT), attributeID=14 -> high_slots (приведено к INTEGER)."""
    build_marts(loaded_engine)
    (row,) = _rows(loaded_engine, manifest, "type_common_stats")
    assert row["type_id"] == 587
    assert row["structure_hp"] == 500.0
    assert row["high_slots"] == 3
    assert isinstance(row["high_slots"], int)
    assert row["armor_hp"] is None  # атрибут не заполнен в фикстуре


def test_industry_materials_is_union_of_activity_tables(
    loaded_engine: Engine, manifest: dict[str, Any]
) -> None:
    build_marts(loaded_engine)
    materials = _rows(loaded_engine, manifest, "industry_materials")
    by_activity = {(r["activity_type"], r["seq"]): r for r in materials}

    assert len(materials) == 3  # 1 copying + 2 manufacturing
    assert by_activity[("copying", 0)]["type_id"] == 34
    assert by_activity[("copying", 0)]["quantity"] == 1
    assert by_activity[("manufacturing", 0)]["type_id"] == 34
    assert by_activity[("manufacturing", 0)]["quantity"] == 350
    assert by_activity[("manufacturing", 1)]["type_id"] == 35
    assert by_activity[("manufacturing", 1)]["quantity"] == 30


def test_industry_activities_products_skills_populated(
    loaded_engine: Engine, manifest: dict[str, Any]
) -> None:
    build_marts(loaded_engine)
    activities = _rows(loaded_engine, manifest, "industry_activities")
    products = _rows(loaded_engine, manifest, "industry_products")
    skills = _rows(loaded_engine, manifest, "industry_skills")

    assert {a["activity_type"] for a in activities} == {"copying", "manufacturing"}
    assert products == [
        {
            "blueprint_id": 686,
            "activity_type": "manufacturing",
            "seq": 0,
            "type_id": 587,
            "quantity": 1,
            "probability": None,
        }
    ]
    assert len(skills) == 2


def test_dim_agents_joins_full_context(loaded_engine: Engine, manifest: dict[str, Any]) -> None:
    build_marts(loaded_engine)
    (row,) = _rows(loaded_engine, manifest, "dim_agents")
    assert row["agent_id"] == 3009841
    assert row["agent_name_en"] == "Ama Amagawa"
    assert row["agent_level"] == 4
    assert row["agent_type_name"] == "Research Agent"
    assert row["division_name_en"] == "Distribution"
    assert row["corporation_name_en"] == "Guristas Pirates Corp"
    assert row["corporation_ticker"] == "GURI"
    assert row["faction_name_en"] == "Guristas Pirates"
    assert row["solar_system_name_en"] == "Jita"
    assert row["region_name_en"] == "The Forge"
    assert row["security_status"] == 0.9


def test_build_marts_is_idempotent(loaded_engine: Engine, manifest: dict[str, Any]) -> None:
    build_marts(loaded_engine)
    first = {name: _rows(loaded_engine, manifest, name) for name in _MART_TABLE_NAMES}

    build_marts(loaded_engine)
    second = {name: _rows(loaded_engine, manifest, name) for name in _MART_TABLE_NAMES}

    assert first == second


_MART_TABLE_NAMES = (
    "dim_items",
    "dim_universe",
    "type_common_stats",
    "industry_activities",
    "industry_materials",
    "industry_products",
    "industry_skills",
    "dim_agents",
)
