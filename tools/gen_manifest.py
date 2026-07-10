"""Парсер `reference/eve_sde_full_schema.sql` -> `src/evesde/schema/manifest.json`.

Манифест — машиночитаемое описание схемы (таблицы, колонки, PK/UNIQUE/FK,
индексы), используемое как единственный источник истины для DDL-строителя
(schema/builder.py) и ETL (etl/transform.py) — чтобы они не могли
разойтись со схемой.

Парсер работает построчно на уровне SQL-стейтментов (см. `_split_statements`)
и не пытается быть универсальным SQL-парсером: он рассчитан ровно на
подмножество конструкций, которые встречаются в eve_sde_full_schema.sql
(см. шапку файла — "Совместимость"). Любая конструкция за пределами этого
подмножества — это либо ошибка в эталонном файле, либо признак того, что
парсер устарел; в обоих случаях лучше упасть с понятной ошибкой, чем молча
собрать неполный манифест.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

#: Контрольные числа из TASKS.md / CLAUDE.md §9 — манифест обязан им соответствовать.
EXPECTED_TABLES = 182
EXPECTED_RAW_TABLES = 174
EXPECTED_MART_TABLES = 8
EXPECTED_FOREIGN_KEYS = 307
EXPECTED_SURROGATE_PK_TABLES = 9

#: Маркер начала ЧАСТИ II (оптимизированный слой) — таблицы после этой строки
#: относятся к слою "mart". Специально ищем "# ЧАСТЬ II." (заголовок раздела),
#: а не просто "ЧАСТЬ II" — эта подстрока также встречается в оглавлении
#: в самом начале файла.
_MART_SECTION_MARKER = "# ЧАСТЬ II."

#: Комментарий у 9 промежуточных таблиц, которым ETL присваивает суррогатный id
#: (см. CLAUDE.md §3).
_SURROGATE_PK_MARKER = "суррогатный PK"

_TABLE_HEADER_RE = re.compile(r"^CREATE TABLE (?P<name>[a-z][a-z0-9_]*) \($")
_TABLE_END_RE = re.compile(r"^\);$")
_COLUMN_RE = re.compile(
    r"^(?P<name>[a-z][a-z0-9_]*)\s+"
    r"(?P<base>INTEGER|FLOAT|BOOLEAN|TEXT|VARCHAR)"
    r"(\((?P<size>\d+)\))?"
    r"(?P<pk>\s+PRIMARY KEY)?$"
)
_TABLE_PK_RE = re.compile(r"^PRIMARY KEY \((?P<cols>[a-z0-9_,\s]+)\)$")
_TABLE_UNIQUE_RE = re.compile(r"^UNIQUE \((?P<cols>[a-z0-9_,\s]+)\)$")
_RAW_SOURCE_RE = re.compile(r"raw source:\s*(?P<file>\S+\.jsonl)\s+_key")
_FK_RE = re.compile(
    r"^ALTER TABLE (?P<table>[a-z0-9_]+) ADD CONSTRAINT (?P<cname>[a-z0-9_]+) "
    r"FOREIGN KEY \((?P<col>[a-z0-9_]+)\) REFERENCES "
    r"(?P<ref_table>[a-z0-9_]+) \((?P<ref_col>[a-z0-9_]+)\);$"
)
_INDEX_RE = re.compile(
    r"^CREATE INDEX (?P<name>[a-z0-9_]+) ON (?P<table>[a-z0-9_]+) \((?P<cols>[a-z0-9_,\s]+)\);$"
)


class SchemaParseError(Exception):
    """Неожиданный синтаксис в eve_sde_full_schema.sql — парсер не падает молча."""


def _strip_comment(line: str) -> str:
    """Обрезает `-- ...` комментарий до конца строки (в файле нет строковых литералов с `--`)."""
    return line.split("--", 1)[0].rstrip()


def _split_statements(lines: list[str]) -> list[tuple[int, list[str]]]:
    """Группирует строки файла в SQL-стейтменты, завершающиеся ';' вне комментария.

    Возвращает список (номер_строки_начала (0-based), строки_стейтмента).
    Работает единообразно для CREATE TABLE (многострочный), ALTER TABLE/
    CREATE INDEX (однострочные) и DELETE/INSERT...SELECT (многострочные,
    игнорируются выше по стеку).
    """
    statements: list[tuple[int, list[str]]] = []
    buffer: list[str] = []
    start = 0
    for i, line in enumerate(lines):
        if not buffer:
            start = i
        buffer.append(line)
        if _strip_comment(line).endswith(";"):
            statements.append((start, buffer))
            buffer = []
    if any(line.strip() for line in buffer):
        raise SchemaParseError(
            f"Файл обрывается посреди незавершённого SQL-стейтмента (начало на строке {start + 1})"
        )
    return statements


def _parse_create_table(start_line: int, stmt_lines: list[str]) -> dict[str, Any]:
    # stmt_lines может начинаться с "хвоста" не-';'-терминированных комментариев,
    # прибившихся от предыдущего стейтмента (см. _split_statements) -- ищем
    # реальный заголовок таблицы внутри, а не берём первую строку как есть.
    header_idx = next(
        (i for i, line in enumerate(stmt_lines) if _TABLE_HEADER_RE.match(line.strip())),
        None,
    )
    if header_idx is None:
        raise SchemaParseError(f"Строка {start_line + 1}: не найден заголовок CREATE TABLE")
    header_match = _TABLE_HEADER_RE.match(stmt_lines[header_idx].strip())
    assert header_match is not None
    table_name = header_match.group("name")

    source_file: str | None = None
    surrogate_pk = False
    body_lines: list[str] = []
    for raw_line in stmt_lines[header_idx + 1 :]:
        source_match = _RAW_SOURCE_RE.search(raw_line)
        if source_match:
            source_file = source_match.group("file")
        if _SURROGATE_PK_MARKER in raw_line:
            surrogate_pk = True
        code = _strip_comment(raw_line).strip()
        if code:
            body_lines.append(code)

    if not body_lines or not _TABLE_END_RE.match(body_lines[-1]):
        raise SchemaParseError(
            f"Таблица {table_name!r} (строка {start_line + 1}): не найдено завершение ');'"
        )
    body_lines = body_lines[:-1]

    columns: list[dict[str, Any]] = []
    pk_columns: list[str] = []
    unique_constraints: list[list[str]] = []
    seen_names: set[str] = set()

    for raw_item in body_lines:
        item = raw_item.rstrip(",").strip()
        if not item:
            continue

        pk_match = _TABLE_PK_RE.match(item)
        if pk_match:
            if pk_columns:
                raise SchemaParseError(f"Таблица {table_name!r}: повторное объявление PRIMARY KEY")
            pk_columns = [c.strip() for c in pk_match.group("cols").split(",")]
            continue

        unique_match = _TABLE_UNIQUE_RE.match(item)
        if unique_match:
            unique_constraints.append([c.strip() for c in unique_match.group("cols").split(",")])
            continue

        col_match = _COLUMN_RE.match(item)
        if col_match is None:
            raise SchemaParseError(
                f"Таблица {table_name!r}: не удалось разобрать колонку/ограничение: {item!r}"
            )

        col_name = col_match.group("name")
        if col_name in seen_names:
            raise SchemaParseError(f"Таблица {table_name!r}: повторная колонка {col_name!r}")
        seen_names.add(col_name)

        size = col_match.group("size")
        columns.append(
            {"name": col_name, "type": col_match.group("base"), "size": int(size) if size else None}
        )

        if col_match.group("pk"):
            if pk_columns:
                raise SchemaParseError(f"Таблица {table_name!r}: несколько PRIMARY KEY")
            pk_columns = [col_name]

    if not pk_columns:
        raise SchemaParseError(f"Таблица {table_name!r}: не найден PRIMARY KEY")
    unknown_pk_cols = sorted(set(pk_columns) - seen_names)
    if unknown_pk_cols:
        raise SchemaParseError(
            f"Таблица {table_name!r}: PRIMARY KEY ссылается на неизвестные колонки "
            f"{unknown_pk_cols}"
        )

    for col in columns:
        col["nullable"] = col["name"] not in pk_columns

    return {
        "name": table_name,
        # Абсолютный номер строки самого "CREATE TABLE ... (" -- используется для
        # определения слоя (raw/mart) по положению относительно маркера ЧАСТИ II;
        # start_line (начало буфера стейтмента) для этого не годится, см. вызывающий код.
        "header_line": start_line + header_idx,
        "source_file": source_file,
        "surrogate_pk": surrogate_pk,
        "columns": columns,
        "primary_key": pk_columns,
        "unique": unique_constraints,
        "foreign_keys": [],
        "indexes": [],
    }


def _parse_fk(start_line: int, code_lines: list[str]) -> dict[str, str]:
    # code_lines уже очищены от комментариев вызывающей стороной (parse_schema);
    # берём последнюю строку -- реальный ALTER TABLE, отбрасывая случайно
    # прибившийся "хвост" предыдущего стейтмента (см. _split_statements).
    line = code_lines[-1]
    m = _FK_RE.match(line)
    if m is None:
        raise SchemaParseError(
            f"Строка {start_line + 1}: не удалось разобрать FOREIGN KEY: {line!r}"
        )
    return {
        "table": m.group("table"),
        "name": m.group("cname"),
        "column": m.group("col"),
        "ref_table": m.group("ref_table"),
        "ref_column": m.group("ref_col"),
    }


def _parse_index(start_line: int, code_lines: list[str]) -> dict[str, Any]:
    line = code_lines[-1]
    m = _INDEX_RE.match(line)
    if m is None:
        raise SchemaParseError(
            f"Строка {start_line + 1}: не удалось разобрать CREATE INDEX: {line!r}"
        )
    return {
        "table": m.group("table"),
        "name": m.group("name"),
        "columns": [c.strip() for c in m.group("cols").split(",")],
    }


def _find_parent_table(table: dict[str, Any], known_tables: dict[str, dict[str, Any]]) -> str:
    """Определяет родителя дочерней таблицы по колонке `<родитель>_id`.

    Родитель ищется по совпадению с именем уже разобранной (более ранней
    в файле) таблицы — а не по префиксу имени самой дочерней таблицы,
    т.к. у некоторых длинных имён СУБД-специфичное усечение делает префиксное
    сравнение ненадёжным (см. `_guess_array_path`).
    """
    candidates = [
        col["name"][: -len("_id")]
        for col in table["columns"]
        if col["name"].endswith("_id") and col["name"][: -len("_id")] in known_tables
    ]
    if len(candidates) != 1:
        raise SchemaParseError(
            f"Таблица {table['name']!r}: не удалось однозначно определить родителя "
            f"(кандидаты: {candidates or 'нет'})"
        )
    return candidates[0]


#: Ручные исправления для дочерних таблиц, чьё имя усечено СУБД (лимит длины
#: идентификатора) при генерации eve_sde_full_schema.sql: усечённый суффикс
#: (напр. `_applicab_543eea`) уже не содержит исходное поле целиком, поэтому
#: `_guess_array_path` не может его восстановить. Пути сверены с реальными
#: данными SDE (JSONL) и SDE_schema_report.md -- см. обсуждение бага с
#: `dynamic_item_attributes_input_output_mapping_applicab_543eea` (не находилась
#: дочерняя таблица для `inputOutputMapping[].applicableTypes[]`).
_TRUNCATED_ARRAY_PATH_OVERRIDES: dict[str, str] = {
    "dynamic_item_attributes_input_output_mapping_applicab_543eea": "applicable_types",
    "freelance_job_schemas_value_parameters_item_delivery__b9d62a": (
        "item_delivery.delivery_location.accepted_value_types"
    ),
    "freelance_job_schemas_value_parameters_item_delivery__f0dfe3": (
        "item_delivery.inventory_type.accepted_value_types"
    ),
    "freelance_job_schemas_value_parameters_matcher_accept_9211f6": "matcher.accepted_value_types",
    "military_campaign_objectives_contribution_method_conf_00852c": (
        "contribution_method_configuration.parameters"
    ),
    "military_campaign_objectives_contribution_method_conf_57d6be": "matcher.values",
    "military_campaign_objectives_contribution_method_conf_4c7001": "values",
}


def _guess_array_path(parent: str, child_name: str) -> str | None:
    """Восстанавливает путь к массиву в исходном JSON из имени дочерней таблицы.

    Эвристика: суффикс имени таблицы после `<родитель>_` считается путём вида
    `поле.подполе` (подчёркивания -> точки). Это приблизительная реконструкция:
    если исходное поле само было многословным camelCase (напр. `nextMissions`),
    её нельзя однозначно отличить от вложенности из двух отдельных полей —
    итоговый путь в таких случаях может не совпадать с реальным JSON-полем
    дословно. Для таблиц с усечёнными/хэшированными именами (превышение лимита
    длины идентификатора СУБД) префикс может не совпасть вовсе или совпасть
    лишь частично, дав мусорный путь -- такие случаи перечислены вручную в
    `_TRUNCATED_ARRAY_PATH_OVERRIDES`; если таблицы там нет, путь неизвестен
    (None).
    """
    if child_name in _TRUNCATED_ARRAY_PATH_OVERRIDES:
        return _TRUNCATED_ARRAY_PATH_OVERRIDES[child_name]
    prefix = f"{parent}_"
    if not child_name.startswith(prefix):
        return None
    suffix = child_name[len(prefix) :]
    return suffix.replace("_", ".")


def parse_schema(sql_text: str) -> dict[str, Any]:
    """Разбирает текст eve_sde_full_schema.sql в манифест схемы (без записи на диск)."""
    lines = sql_text.splitlines()
    mart_start = next((i for i, line in enumerate(lines) if _MART_SECTION_MARKER in line), None)
    if mart_start is None:
        raise SchemaParseError(f"Не найден маркер начала ЧАСТИ II: {_MART_SECTION_MARKER!r}")

    tables: dict[str, dict[str, Any]] = {}
    order: list[str] = []
    total_fks = 0

    for start_line, stmt_lines in _split_statements(lines):
        code_lines = [c for c in (_strip_comment(line).strip() for line in stmt_lines) if c]
        if not code_lines:
            continue
        head = code_lines[0]

        if head.startswith("CREATE TABLE "):
            table = _parse_create_table(start_line, stmt_lines)
            name = table["name"]
            if name in tables:
                raise SchemaParseError(
                    f"Строка {start_line + 1}: повторное объявление таблицы {name!r}"
                )

            if table["header_line"] > mart_start:
                table["layer"] = "mart"
                table["parent_table"] = None
                table["array_path"] = None
            elif table["source_file"] is not None:
                table["layer"] = "raw_root"
                table["parent_table"] = None
                table["array_path"] = None
            else:
                table["layer"] = "raw_child"
                parent = _find_parent_table(table, tables)
                table["parent_table"] = parent
                table["array_path"] = _guess_array_path(parent, name)

            tables[name] = table
            order.append(name)

        elif head.startswith("ALTER TABLE "):
            fk = _parse_fk(start_line, code_lines)
            if fk["table"] not in tables:
                raise SchemaParseError(
                    f"Строка {start_line + 1}: FOREIGN KEY на неизвестную таблицу {fk['table']!r}"
                )
            tables[fk["table"]]["foreign_keys"].append(
                {k: v for k, v in fk.items() if k != "table"}
            )
            total_fks += 1

        elif head.startswith("CREATE INDEX "):
            idx = _parse_index(start_line, code_lines)
            if idx["table"] not in tables:
                raise SchemaParseError(
                    f"Строка {start_line + 1}: CREATE INDEX на неизвестную таблицу {idx['table']!r}"
                )
            tables[idx["table"]]["indexes"].append({"name": idx["name"], "columns": idx["columns"]})

        elif head.startswith("DELETE FROM ") or head.startswith("INSERT INTO "):
            # Заполнение витрин (ЧАСТЬ II.B-E) -- вне структуры схемы, не относится к манифесту.
            continue

        else:
            raise SchemaParseError(
                f"Строка {start_line + 1}: неожиданный тип SQL-стейтмента: {head[:80]!r}"
            )

    _internal_keys = {"name", "header_line"}
    manifest_tables = {
        name: {k: v for k, v in tables[name].items() if k not in _internal_keys} for name in order
    }

    raw_tables = sum(1 for t in manifest_tables.values() if t["layer"] in ("raw_root", "raw_child"))
    mart_tables = sum(1 for t in manifest_tables.values() if t["layer"] == "mart")
    surrogate_pk_tables = sum(1 for t in manifest_tables.values() if t["surrogate_pk"])

    return {
        "counts": {
            "tables": len(manifest_tables),
            "raw_tables": raw_tables,
            "mart_tables": mart_tables,
            "foreign_keys": total_fks,
            "surrogate_pk_tables": surrogate_pk_tables,
        },
        "tables": manifest_tables,
    }


def validate_counts(manifest: dict[str, Any]) -> None:
    """Проверяет манифест на соответствие контрольным числам из CLAUDE.md §9."""
    expected = {
        "tables": EXPECTED_TABLES,
        "raw_tables": EXPECTED_RAW_TABLES,
        "mart_tables": EXPECTED_MART_TABLES,
        "foreign_keys": EXPECTED_FOREIGN_KEYS,
        "surrogate_pk_tables": EXPECTED_SURROGATE_PK_TABLES,
    }
    counts = manifest["counts"]
    mismatches = [
        f"{key}: ожидалось {value}, получено {counts[key]}"
        for key, value in expected.items()
        if counts[key] != value
    ]
    if mismatches:
        raise SchemaParseError(
            "Контрольные числа манифеста не совпадают:\n" + "\n".join(mismatches)
        )


_DEFAULT_OUT_PATH = (
    Path(__file__).resolve().parents[1] / "src" / "evesde" / "schema" / "manifest.json"
)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Генерация schema/manifest.json из eve_sde_full_schema.sql"
    )
    parser.add_argument("sql_path", type=Path, help="путь к eve_sde_full_schema.sql")
    parser.add_argument(
        "--out", type=Path, default=_DEFAULT_OUT_PATH, help="путь для manifest.json"
    )
    args = parser.parse_args(argv)

    sql_text = args.sql_path.read_text(encoding="utf-8")
    manifest = parse_schema(sql_text)
    validate_counts(manifest)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"manifest.json записан: {args.out} ({manifest['counts']})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
