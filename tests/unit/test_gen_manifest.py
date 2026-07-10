"""Тесты парсера tools/gen_manifest.py на фрагментах SQL и на эталонном файле."""

from __future__ import annotations

from pathlib import Path

import pytest
from gen_manifest import (
    EXPECTED_FOREIGN_KEYS,
    EXPECTED_MART_TABLES,
    EXPECTED_RAW_TABLES,
    EXPECTED_SURROGATE_PK_TABLES,
    EXPECTED_TABLES,
    SchemaParseError,
    parse_schema,
    validate_counts,
)

_MART_MARKER = "-- # ЧАСТЬ II. ОПТИМИЗИРОВАННЫЙ СЛОЙ (тестовая заглушка)\n"
# Комментарий-маркер сам по себе не завершает SQL-стейтмент (нет ';'), поэтому
# в мини-фрагментах для негативных тестов после него нужен хоть один валидный
# однострочный стейтмент -- иначе _split_statements() увидит "подвисший" хвост
# в конце файла и сообщит об оборванном стейтменте раньше, чем до проверяемой
# ошибки дойдёт очередь.
_EOF_TERMINATOR = "CREATE INDEX idx_eof_terminator ON widgets (id);\n"

_SAMPLE_SQL = (
    """\
CREATE TABLE widgets (
    -- raw source: widgets.jsonl _key
    id INTEGER,
    name_en TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE widgets_tags (
    widgets_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value VARCHAR(50),
    PRIMARY KEY (widgets_id, seq)
);

CREATE TABLE widgets_parts (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке)
    id INTEGER,
    widgets_id INTEGER,
    seq INTEGER,
    part_name VARCHAR(100),
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (widgets_id, seq)
);

CREATE TABLE widgets_parts_bolts (
    widgets_parts_id INTEGER,
    seq INTEGER,
    length FLOAT,
    PRIMARY KEY (widgets_parts_id, seq)
);

ALTER TABLE widgets_tags ADD CONSTRAINT fk_widgets_tags_1 FOREIGN KEY (widgets_id) REFERENCES widgets (id);
ALTER TABLE widgets_parts ADD CONSTRAINT fk_widgets_parts_1 FOREIGN KEY (widgets_id) REFERENCES widgets (id);
ALTER TABLE widgets_parts_bolts ADD CONSTRAINT fk_widgets_parts_bolts_1 FOREIGN KEY (widgets_parts_id) REFERENCES widgets_parts (id);

CREATE INDEX idx_widgets_parts_part_name ON widgets_parts (part_name);

"""
    + _MART_MARKER
    + """

CREATE TABLE dim_widgets (
    widget_id INTEGER PRIMARY KEY,
    widget_name TEXT
);
"""
)


def test_root_table_parsed_with_source_file() -> None:
    manifest = parse_schema(_SAMPLE_SQL)
    widgets = manifest["tables"]["widgets"]
    assert widgets["layer"] == "raw_root"
    assert widgets["source_file"] == "widgets.jsonl"
    assert widgets["primary_key"] == ["id"]
    assert widgets["surrogate_pk"] is False
    assert {c["name"] for c in widgets["columns"]} == {"id", "name_en"}
    id_col = next(c for c in widgets["columns"] if c["name"] == "id")
    assert id_col == {"name": "id", "type": "INTEGER", "size": None, "nullable": False}
    name_col = next(c for c in widgets["columns"] if c["name"] == "name_en")
    assert name_col["nullable"] is True


def test_child_table_with_composite_pk() -> None:
    manifest = parse_schema(_SAMPLE_SQL)
    tags = manifest["tables"]["widgets_tags"]
    assert tags["layer"] == "raw_child"
    assert tags["parent_table"] == "widgets"
    assert tags["array_path"] == "tags"
    assert tags["primary_key"] == ["widgets_id", "seq"]
    assert tags["surrogate_pk"] is False
    assert tags["unique"] == []


def test_surrogate_pk_table_with_unique() -> None:
    manifest = parse_schema(_SAMPLE_SQL)
    parts = manifest["tables"]["widgets_parts"]
    assert parts["layer"] == "raw_child"
    assert parts["parent_table"] == "widgets"
    assert parts["surrogate_pk"] is True
    assert parts["primary_key"] == ["id"]
    assert parts["unique"] == [["widgets_id", "seq"]]


def test_grandchild_table_parents_to_surrogate_pk_table() -> None:
    manifest = parse_schema(_SAMPLE_SQL)
    bolts = manifest["tables"]["widgets_parts_bolts"]
    assert bolts["parent_table"] == "widgets_parts"
    assert bolts["array_path"] == "bolts"


def test_foreign_keys_attached_to_owning_table() -> None:
    manifest = parse_schema(_SAMPLE_SQL)
    fks = manifest["tables"]["widgets_parts_bolts"]["foreign_keys"]
    assert fks == [
        {
            "name": "fk_widgets_parts_bolts_1",
            "column": "widgets_parts_id",
            "ref_table": "widgets_parts",
            "ref_column": "id",
        }
    ]
    assert manifest["counts"]["foreign_keys"] == 3


def test_index_attached_to_table() -> None:
    manifest = parse_schema(_SAMPLE_SQL)
    parts = manifest["tables"]["widgets_parts"]
    assert parts["indexes"] == [{"name": "idx_widgets_parts_part_name", "columns": ["part_name"]}]


def test_mart_table_with_inline_primary_key() -> None:
    manifest = parse_schema(_SAMPLE_SQL)
    dim = manifest["tables"]["dim_widgets"]
    assert dim["layer"] == "mart"
    assert dim["parent_table"] is None
    assert dim["primary_key"] == ["widget_id"]
    counts = manifest["counts"]
    assert counts == {
        "tables": 5,
        "raw_tables": 4,
        "mart_tables": 1,
        "foreign_keys": 3,
        "surrogate_pk_tables": 1,
    }


def test_unknown_column_type_raises() -> None:
    bad_sql = (
        "CREATE TABLE broken (\n"
        "    id INTEGER,\n"
        "    created_at DATE,\n"
        "    PRIMARY KEY (id)\n"
        ");\n" + _MART_MARKER + _EOF_TERMINATOR
    )
    with pytest.raises(SchemaParseError, match="не удалось разобрать колонку"):
        parse_schema(bad_sql)


def test_missing_primary_key_raises() -> None:
    bad_sql = (
        "CREATE TABLE broken (\n    id INTEGER,\n    name TEXT\n);\n"
        + _MART_MARKER
        + _EOF_TERMINATOR
    )
    with pytest.raises(SchemaParseError, match="не найден PRIMARY KEY"):
        parse_schema(bad_sql)


def test_fk_on_unknown_table_raises() -> None:
    bad_sql = (
        "CREATE TABLE widgets (\n"
        "    -- raw source: widgets.jsonl _key\n"
        "    id INTEGER,\n"
        "    PRIMARY KEY (id)\n"
        ");\n"
        "ALTER TABLE ghosts ADD CONSTRAINT fk_1 FOREIGN KEY (widgets_id) REFERENCES widgets (id);\n"
        + _MART_MARKER
        + _EOF_TERMINATOR
    )
    with pytest.raises(SchemaParseError, match="неизвестную таблицу"):
        parse_schema(bad_sql)


def test_unexpected_statement_raises() -> None:
    bad_sql = "DROP TABLE widgets;\n" + _MART_MARKER + _EOF_TERMINATOR
    with pytest.raises(SchemaParseError, match="неожиданный тип"):
        parse_schema(bad_sql)


def test_missing_mart_marker_raises() -> None:
    with pytest.raises(SchemaParseError, match="маркер"):
        parse_schema("CREATE TABLE widgets (\n    id INTEGER,\n    PRIMARY KEY (id)\n);\n")


def test_unterminated_statement_raises() -> None:
    with pytest.raises(SchemaParseError, match="незавершённого"):
        parse_schema(
            "CREATE TABLE widgets (\n    id INTEGER,\n    PRIMARY KEY (id)\n" + _MART_MARKER
        )


def test_validate_counts_passes_for_matching_manifest() -> None:
    manifest = {
        "counts": {
            "tables": EXPECTED_TABLES,
            "raw_tables": EXPECTED_RAW_TABLES,
            "mart_tables": EXPECTED_MART_TABLES,
            "foreign_keys": EXPECTED_FOREIGN_KEYS,
            "surrogate_pk_tables": EXPECTED_SURROGATE_PK_TABLES,
        },
        "tables": {},
    }
    validate_counts(manifest)


def test_validate_counts_rejects_mismatch() -> None:
    manifest = {
        "counts": {
            "tables": 1,
            "raw_tables": 1,
            "mart_tables": 0,
            "foreign_keys": 0,
            "surrogate_pk_tables": 0,
        },
        "tables": {},
    }
    with pytest.raises(SchemaParseError, match="Контрольные числа"):
        validate_counts(manifest)


_REPO_ROOT = Path(__file__).resolve().parents[2]
_FULL_SCHEMA_PATH = _REPO_ROOT / "reference" / "eve_sde_full_schema.sql"


def test_full_schema_matches_control_numbers() -> None:
    sql_text = _FULL_SCHEMA_PATH.read_text(encoding="utf-8")
    manifest = parse_schema(sql_text)
    validate_counts(manifest)


def test_full_schema_parse_is_deterministic() -> None:
    sql_text = _FULL_SCHEMA_PATH.read_text(encoding="utf-8")
    first = parse_schema(sql_text)
    second = parse_schema(sql_text)
    assert first == second
