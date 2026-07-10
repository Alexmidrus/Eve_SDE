"""Интеграционные тесты etl/loader.py на SQLite (CLAUDE.md §8: SQLite -- всегда)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine, func, inspect, select
from sqlalchemy.engine import Engine

from evesde.config import SDEConfig
from evesde.etl.loader import load_all, load_file, load_fresh
from evesde.schema.builder import build_metadata, create_raw_tables, load_manifest

_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "sde_mini"
_FIXTURES_DIR_V2 = Path(__file__).resolve().parents[1] / "fixtures" / "sde_mini_v2"
_FIXTURES_DIR_BROKEN = Path(__file__).resolve().parents[1] / "fixtures" / "sde_mini_broken"


@pytest.fixture(scope="module")
def manifest() -> dict[str, Any]:
    return load_manifest()


@pytest.fixture
def engine(manifest: dict[str, Any]) -> Engine:
    eng = create_engine("sqlite:///:memory:")
    create_raw_tables(eng, manifest)
    return eng


def _count(engine: Engine, table_name: str) -> int:
    metadata = build_metadata(load_manifest(), layer="raw")
    table = metadata.tables[table_name]
    with engine.connect() as conn:
        return conn.execute(select(func.count()).select_from(table)).scalar_one()


def test_load_file_epic_arcs_counts_root_child_and_grandchild(
    engine: Engine, manifest: dict[str, Any]
) -> None:
    result = load_file(engine, _FIXTURES_DIR / "epicArcs.jsonl", manifest)

    assert result.file_name == "epicArcs.jsonl"
    assert result.row_counts["epic_arcs"] == 1
    assert result.row_counts["epic_arcs_missions"] == 2
    assert result.row_counts["epic_arcs_missions_next_missions"] == 2

    assert _count(engine, "epic_arcs") == 1
    assert _count(engine, "epic_arcs_missions") == 2
    assert _count(engine, "epic_arcs_missions_next_missions") == 2


def test_load_file_masteries_counts(engine: Engine, manifest: dict[str, Any]) -> None:
    result = load_file(engine, _FIXTURES_DIR / "masteries.jsonl", manifest)

    assert result.row_counts["masteries"] == 2
    assert result.row_counts["masteries_value"] == 3  # 2 уровня у типа 587 + 1 у типа 34
    assert result.row_counts["masteries_value_value"] == 4  # 2+1+1 сертификатов


def test_load_file_blueprints_counts(engine: Engine, manifest: dict[str, Any]) -> None:
    result = load_file(engine, _FIXTURES_DIR / "blueprints.jsonl", manifest)

    assert result.row_counts["blueprints"] == 1
    assert result.row_counts["blueprints_activities_copying_materials"] == 1
    assert result.row_counts["blueprints_activities_copying_skills"] == 1
    assert result.row_counts["blueprints_activities_manufacturing_materials"] == 2
    assert result.row_counts["blueprints_activities_manufacturing_products"] == 1
    assert result.row_counts["blueprints_activities_manufacturing_skills"] == 1


def test_load_all_loads_every_known_fixture_file_and_skips_unknown(
    engine: Engine, manifest: dict[str, Any]
) -> None:
    result = load_all(engine, _FIXTURES_DIR, manifest)

    loaded_files = {f.file_name for f in result.files}
    assert loaded_files == {"types.jsonl", "blueprints.jsonl", "epicArcs.jsonl", "masteries.jsonl"}
    assert result.skipped_files == ["notInManifest.jsonl"]

    assert _count(engine, "types") == 2
    assert _count(engine, "epic_arcs_missions_next_missions") == 2


def test_load_all_creates_indexes_after_loading(engine: Engine, manifest: dict[str, Any]) -> None:
    load_all(engine, _FIXTURES_DIR, manifest)
    inspector = inspect(engine)
    index_names = {idx["name"] for idx in inspector.get_indexes("epic_arcs_missions")}
    expected = {idx["name"] for idx in manifest["tables"]["epic_arcs_missions"]["indexes"]}
    assert expected
    assert expected <= index_names


def test_id_allocator_is_shared_across_files_in_load_all(
    engine: Engine, manifest: dict[str, Any]
) -> None:
    """Сквозная нумерация суррогатных id: epic_arcs_missions и masteries_value используют
    РАЗНЫЕ счётчики (по одному на таблицу), поэтому id в каждой из них начинаются с 1
    независимо от порядка загрузки файлов."""
    result = load_all(engine, _FIXTURES_DIR, manifest)
    assert result.total_rows > 0

    metadata = build_metadata(manifest, layer="raw")
    with engine.connect() as conn:
        mission_ids = sorted(
            row[0] for row in conn.execute(select(metadata.tables["epic_arcs_missions"].c.id))
        )
        mastery_ids = sorted(
            row[0] for row in conn.execute(select(metadata.tables["masteries_value"].c.id))
        )
    assert mission_ids == [1, 2]
    assert mastery_ids == [1, 2, 3]


# ---------------------------------------------------------------------------
# load_fresh: атомарная подмена
# ---------------------------------------------------------------------------


def test_load_fresh_creates_new_sqlite_file(tmp_path: Path) -> None:
    db_path = tmp_path / "eve.db"
    config = SDEConfig.from_url(f"sqlite:///{db_path}")

    result = load_fresh(config, _FIXTURES_DIR)

    assert db_path.exists()
    assert result.total_rows > 0
    assert not db_path.with_name(db_path.name + ".new").exists()


def test_load_fresh_atomically_replaces_old_data(tmp_path: Path) -> None:
    db_path = tmp_path / "eve.db"
    config = SDEConfig.from_url(f"sqlite:///{db_path}")

    load_fresh(config, _FIXTURES_DIR)
    engine_v1 = create_engine(config.url)
    assert _query_epic_arc_name(engine_v1) == "Sisters of EVE"
    engine_v1.dispose()

    load_fresh(config, _FIXTURES_DIR_V2)
    engine_v2 = create_engine(config.url)
    assert _query_epic_arc_name(engine_v2) == "Sansha Incursion"
    engine_v2.dispose()


def test_load_fresh_leaves_old_database_intact_if_load_fails(tmp_path: Path) -> None:
    """«Читатели не должны видеть полупустую базу»: сбой при построении теневой
    копии не должен затронуть уже существующий работающий файл БД."""
    db_path = tmp_path / "eve.db"
    config = SDEConfig.from_url(f"sqlite:///{db_path}")

    load_fresh(config, _FIXTURES_DIR)
    engine_before = create_engine(config.url)
    name_before = _query_epic_arc_name(engine_before)
    engine_before.dispose()

    with pytest.raises(Exception):  # noqa: B017 - json.JSONDecodeError из битой фикстуры
        load_fresh(config, _FIXTURES_DIR_BROKEN)

    # старый файл не тронут и полностью рабочий
    engine_after = create_engine(config.url)
    assert _query_epic_arc_name(engine_after) == name_before
    engine_after.dispose()
    assert not db_path.with_name(db_path.name + ".new").exists()


def _query_epic_arc_name(engine: Engine) -> str:
    metadata = build_metadata(load_manifest(), layer="raw")
    table = metadata.tables["epic_arcs"]
    with engine.connect() as conn:
        return conn.execute(select(table.c.name_en)).scalars().first()
