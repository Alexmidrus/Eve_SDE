"""Интеграционные тесты schema/builder.py на SQLite in-memory (см. CLAUDE.md §8)."""

from __future__ import annotations

from typing import Any

import pytest
from sqlalchemy import BigInteger, Boolean, Float, String, Text, create_engine, inspect
from sqlalchemy.engine import Engine

from evesde.schema.builder import (
    build_metadata,
    create_indexes,
    create_mart_tables,
    create_raw_tables,
    drop_all,
    load_manifest,
)


@pytest.fixture(scope="module")
def manifest() -> dict[str, Any]:
    return load_manifest()


@pytest.fixture
def engine() -> Engine:
    return create_engine("sqlite:///:memory:")


def test_create_raw_tables_creates_174_tables(engine: Engine, manifest: dict[str, Any]) -> None:
    create_raw_tables(engine, manifest)
    inspector = inspect(engine)
    assert set(inspector.get_table_names()) == {
        name for name, t in manifest["tables"].items() if t["layer"] in ("raw_root", "raw_child")
    }


def test_raw_metadata_matches_manifest_inventory(manifest: dict[str, Any]) -> None:
    metadata = build_metadata(manifest, layer="raw")
    raw_names = {
        name for name, t in manifest["tables"].items() if t["layer"] in ("raw_root", "raw_child")
    }
    assert set(metadata.tables) == raw_names
    for name in raw_names:
        table = metadata.tables[name]
        expected_columns = {c["name"] for c in manifest["tables"][name]["columns"]}
        assert {c.name for c in table.columns} == expected_columns
        assert set(table.primary_key.columns.keys()) == set(manifest["tables"][name]["primary_key"])


def test_column_type_mapping(manifest: dict[str, Any]) -> None:
    metadata = build_metadata(manifest, layer="raw")
    types_table = metadata.tables["types"]
    assert isinstance(types_table.c["id"].type, BigInteger)
    assert isinstance(types_table.c["mass"].type, Float)
    assert isinstance(types_table.c["published"].type, Boolean)
    assert isinstance(types_table.c["name_en"].type, Text)

    sde_table = metadata.tables["sde"]
    assert isinstance(sde_table.c["id"].type, String)
    assert sde_table.c["id"].type.length == 128


def test_npc_cycle_foreign_keys_present(engine: Engine, manifest: dict[str, Any]) -> None:
    """npc_corporations <-> npc_characters -- взаимные FK, известная ловушка (CLAUDE.md §2)."""
    create_raw_tables(engine, manifest)
    inspector = inspect(engine)

    corp_fks = {
        fk["constrained_columns"][0]: fk["referred_table"]
        for fk in inspector.get_foreign_keys("npc_corporations")
    }
    char_fks = {
        fk["constrained_columns"][0]: fk["referred_table"]
        for fk in inspector.get_foreign_keys("npc_characters")
    }

    assert corp_fks["ceo_id"] == "npc_characters"
    assert char_fks["corporation_id"] == "npc_corporations"


def test_create_indexes_creates_all_named_indexes(engine: Engine, manifest: dict[str, Any]) -> None:
    create_raw_tables(engine, manifest)
    create_mart_tables(engine, manifest)
    create_indexes(engine, build_metadata(manifest))

    inspector = inspect(engine)
    created_index_names = {
        idx["name"]
        for table_name in inspector.get_table_names()
        for idx in inspector.get_indexes(table_name)
    }
    expected_index_names = {
        idx["name"] for t in manifest["tables"].values() for idx in t["indexes"]
    }
    assert created_index_names == expected_index_names


def test_indexes_not_created_by_create_all(engine: Engine, manifest: dict[str, Any]) -> None:
    create_raw_tables(engine, manifest)
    inspector = inspect(engine)
    all_indexes = [
        idx for name in inspector.get_table_names() for idx in inspector.get_indexes(name)
    ]
    assert all_indexes == []


def test_create_mart_tables_after_raw_layer(engine: Engine, manifest: dict[str, Any]) -> None:
    create_raw_tables(engine, manifest)
    create_mart_tables(engine, manifest)
    inspector = inspect(engine)
    mart_names = {name for name, t in manifest["tables"].items() if t["layer"] == "mart"}
    assert mart_names <= set(inspector.get_table_names())


def test_drop_all_removes_everything(engine: Engine, manifest: dict[str, Any]) -> None:
    create_raw_tables(engine, manifest)
    create_mart_tables(engine, manifest)
    drop_all(engine, manifest)
    inspector = inspect(engine)
    assert inspector.get_table_names() == []


def test_build_metadata_full_schema_has_182_tables(manifest: dict[str, Any]) -> None:
    metadata = build_metadata(manifest)
    assert len(metadata.tables) == 182
