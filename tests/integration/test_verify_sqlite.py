"""Интеграционные тесты etl/verify.py на SQLite in-memory (CLAUDE.md §8)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine, delete
from sqlalchemy.engine import Engine

from evesde.etl.loader import load_all
from evesde.etl.marts import build_marts
from evesde.etl.verify import verify
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
    """Полностью загруженная (raw + marts) SQLite-база на фикстурах sde_marts."""
    engine = create_engine("sqlite:///:memory:")
    create_raw_tables(engine, manifest)
    create_mart_tables(engine, manifest)
    load_all(engine, _FIXTURES_DIR, manifest)
    build_marts(engine)
    return engine


def test_clean_database_has_no_issues(loaded_engine: Engine, manifest: dict[str, Any]) -> None:
    report = verify(loaded_engine, sde_dir=_FIXTURES_DIR, manifest=manifest)

    assert report.errors == []
    assert report.warnings == []
    assert report.ok is True
    assert report.build_info is not None
    assert report.build_info.build_number == 3428504
    assert "Проблем не найдено" in report.summary()


def test_deleted_parent_creates_fk_orphan(loaded_engine: Engine, manifest: dict[str, Any]) -> None:
    """Удалённый types.id=587 -> blueprints/dim_items ссылаются в никуда."""
    metadata = build_metadata(manifest, layer="raw")
    with loaded_engine.begin() as conn:
        conn.execute(delete(metadata.tables["types"]).where(metadata.tables["types"].c.id == 587))

    report = verify(loaded_engine, sde_dir=_FIXTURES_DIR, manifest=manifest)

    assert not report.ok
    fk_categories = {(i.category, i.severity) for i in report.issues}
    assert ("fk_orphan", "error") in fk_categories or ("mart_orphan_key", "error") in fk_categories
    messages = " ".join(i.message for i in report.errors)
    assert "types" in messages


def test_underloaded_file_creates_row_count_error(
    loaded_engine: Engine, manifest: dict[str, Any]
) -> None:
    """agent_types.jsonl содержит 1 строку -- удаляем её из таблицы напрямую."""
    metadata = build_metadata(manifest, layer="raw")
    with loaded_engine.begin() as conn:
        conn.execute(delete(metadata.tables["agent_types"]))

    report = verify(loaded_engine, sde_dir=_FIXTURES_DIR, manifest=manifest)

    row_count_issues = [i for i in report.issues if i.category == "row_count"]
    assert len(row_count_issues) == 1
    assert row_count_issues[0].severity == "error"
    assert "agent_types" in row_count_issues[0].message


def test_verify_without_sde_dir_skips_row_count_check(
    loaded_engine: Engine, manifest: dict[str, Any]
) -> None:
    metadata = build_metadata(manifest, layer="raw")
    with loaded_engine.begin() as conn:
        conn.execute(delete(metadata.tables["agent_types"]))

    report = verify(loaded_engine, sde_dir=None, manifest=manifest)

    assert all(i.category != "row_count" for i in report.issues)


def test_empty_marts_are_flagged_as_warnings(manifest: dict[str, Any]) -> None:
    engine = create_engine("sqlite:///:memory:")
    create_raw_tables(engine, manifest)
    create_mart_tables(engine, manifest)
    load_all(engine, _FIXTURES_DIR, manifest)
    # build_marts() не вызывался -- витрины созданы, но не заполнены

    report = verify(engine, sde_dir=_FIXTURES_DIR, manifest=manifest)

    mart_empty = {i.message for i in report.issues if i.category == "mart_empty"}
    assert len(mart_empty) == 8


def test_missing_build_info_is_a_warning(manifest: dict[str, Any]) -> None:
    engine = create_engine("sqlite:///:memory:")
    create_raw_tables(engine, manifest)
    create_mart_tables(engine, manifest)
    # _sde.jsonl не грузили вообще

    report = verify(engine, manifest=manifest)

    assert report.build_info is None
    assert any(i.category == "build_info" and i.severity == "warning" for i in report.issues)
    assert report.ok  # предупреждение не делает отчёт "не ok"
