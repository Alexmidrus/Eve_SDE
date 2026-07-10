"""Построение SQLAlchemy MetaData из manifest.json.

FK объявлены inline в `Table` (как объекты `ForeignKeyConstraint`) с
``use_alter=True``: для диалектов, поддерживающих ``ALTER TABLE ADD
CONSTRAINT`` (PostgreSQL, MySQL), SQLAlchemy откладывает их создание до
конца ``create_all`` — единственный надёжный способ создать таблицы со
взаимными FK (например, ``npc_corporations`` <-> ``npc_characters``) без
ручной сортировки. Для SQLite, где ``ALTER TABLE ADD CONSTRAINT`` не
поддерживается, ``use_alter`` дialectом игнорируется и FK всё равно
оказываются inline в ``CREATE TABLE`` — именно то, что нужно (см. CLAUDE.md §4).

Индексы из манифеста только ОПИСАНЫ на ``Table.info["indexes"]``, а не
построены как реальные объекты `Index` — поэтому `create_all()` их не
создаёт. Настоящие `Index` создаются отдельно функцией `create_indexes`,
после загрузки данных (правило §5 CLAUDE.md «индексы после загрузки»).
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Literal

from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    Float,
    ForeignKeyConstraint,
    Index,
    MetaData,
    PrimaryKeyConstraint,
    String,
    Table,
    Text,
    UniqueConstraint,
)
from sqlalchemy.engine import Engine

Layer = Literal["raw", "mart"]

_DEFAULT_MANIFEST_PATH = Path(__file__).with_name("manifest.json")

#: INTEGER -> BigInteger: ID в EVE (mapMoons, dynamicItemAttributes и т.п.)
#: превышают 2^31 (см. CLAUDE.md §4).
_TYPE_MAP: dict[str, type] = {
    "INTEGER": BigInteger,
    "FLOAT": Float,
    "TEXT": Text,
    "BOOLEAN": Boolean,
}

#: Лимит PostgreSQL (NAMEDATALEN-1 = 63) -- самый строгий среди трёх целевых
#: СУБД (MySQL/MariaDB допускают 64), поэтому ориентируемся на него.
_MAX_IDENTIFIER_LENGTH = 63


def _safe_identifier(name: str) -> str:
    """Укорачивает сгенерированное имя ограничения до лимита PostgreSQL.

    Нужно, т.к. некоторые дочерние таблицы сами получили хэш-усечённые имена
    из-за лимита длины идентификатора ещё на этапе проектирования схемы
    (см. T02) -- добавление префикса/суффикса к уже почти предельно длинному
    имени таблицы может вывести сгенерированное имя ограничения за лимит.
    Усечение детерминированное и заканчивается коротким хэшем, чтобы разные
    длинные имена не схлопнулись в одинаковый обрезанный идентификатор.
    """
    if len(name) <= _MAX_IDENTIFIER_LENGTH:
        return name
    suffix = hashlib.md5(name.encode()).hexdigest()[:8]
    return f"{name[: _MAX_IDENTIFIER_LENGTH - len(suffix) - 1]}_{suffix}"


def load_manifest(path: Path | None = None) -> dict[str, Any]:
    """Загружает manifest.json (по умолчанию — упакованный вместе с библиотекой)."""
    manifest_path = path or _DEFAULT_MANIFEST_PATH
    with manifest_path.open(encoding="utf-8") as f:
        result: dict[str, Any] = json.load(f)
        return result


def _column_type(col: dict[str, Any]) -> Any:
    base = col["type"]
    if base == "VARCHAR":
        return String(col["size"])
    try:
        return _TYPE_MAP[base]
    except KeyError:
        raise ValueError(f"Неизвестный тип колонки в манифесте: {base!r}") from None


def _select_table_names(manifest: dict[str, Any], layer: Layer | None) -> set[str]:
    tables = manifest["tables"]
    if layer is None:
        return set(tables)
    if layer == "raw":
        return {name for name, t in tables.items() if t["layer"] in ("raw_root", "raw_child")}
    if layer == "mart":
        return {name for name, t in tables.items() if t["layer"] == "mart"}
    raise ValueError(f"Неизвестный слой: {layer!r} (допустимо: 'raw', 'mart', None)")


def _fk_target_closure(manifest: dict[str, Any], names: set[str]) -> set[str]:
    """Достраивает набор таблиц теми, на кого ссылаются FK выбранных таблиц.

    Нужно, чтобы FK-ссылки разрешались внутри одной MetaData, даже когда
    запрашивается изолированный слой (mart-таблицы ссылаются на types/
    blueprints из raw-слоя). Достроенные таблицы не обязательно создавать
    повторно -- см. `create_mart_tables`, которая ограничивает `create_all`
    только своим слоем.
    """
    tables = manifest["tables"]
    extra: set[str] = set()
    frontier = set(names)
    while frontier:
        discovered: set[str] = set()
        for name in frontier:
            for fk in tables[name]["foreign_keys"]:
                ref = fk["ref_table"]
                if ref not in names and ref not in extra:
                    discovered.add(ref)
        extra |= discovered
        frontier = discovered
    return extra


def build_metadata(
    manifest: dict[str, Any], layer: Layer | None = None, schema: str | None = None
) -> MetaData:
    """Строит SQLAlchemy MetaData для указанного слоя (или всей схемы, если None).

    ``schema`` -- необязательная схема/база-приёмник (используется T05 для
    теневой загрузки на PostgreSQL/MySQL: `MetaData(schema=...)` автоматически
    квалифицирует им все таблицы и разрешение строковых FK-ссылок между ними,
    имена таблиц (``Table.name``) при этом остаются исходными).
    """
    selected = _select_table_names(manifest, layer)
    names = selected | _fk_target_closure(manifest, selected)

    metadata = MetaData(schema=schema)
    for name in names:
        _build_table(metadata, name, manifest["tables"][name])
    return metadata


def _build_table(metadata: MetaData, name: str, table_def: dict[str, Any]) -> Table:
    columns = [
        Column(col["name"], _column_type(col), nullable=col["nullable"])
        for col in table_def["columns"]
    ]

    constraints: list[Any] = [PrimaryKeyConstraint(*table_def["primary_key"])]
    for i, unique_cols in enumerate(table_def["unique"], start=1):
        constraints.append(UniqueConstraint(*unique_cols, name=_safe_identifier(f"uq_{name}_{i}")))
    for fk in table_def["foreign_keys"]:
        constraints.append(
            ForeignKeyConstraint(
                [fk["column"]],
                [f"{fk['ref_table']}.{fk['ref_column']}"],
                name=fk["name"],
                use_alter=True,
            )
        )

    return Table(
        name,
        metadata,
        *columns,
        *constraints,
        info={"layer": table_def["layer"], "indexes": table_def["indexes"]},
    )


def create_indexes(engine: Engine, metadata: MetaData) -> None:
    """Создаёт индексы, описанные в `Table.info["indexes"]` (правило §5: после загрузки)."""
    for table in metadata.tables.values():
        for idx_def in table.info.get("indexes", []):
            index = Index(idx_def["name"], *[table.c[col_name] for col_name in idx_def["columns"]])
            index.create(engine, checkfirst=True)


def create_raw_tables(engine: Engine, manifest: dict[str, Any] | None = None) -> None:
    """Создаёт 174 таблицы raw-слоя (без индексов -- см. `create_indexes`)."""
    manifest = manifest if manifest is not None else load_manifest()
    metadata = build_metadata(manifest, layer="raw")
    metadata.create_all(engine)


def create_mart_tables(
    engine: Engine, manifest: dict[str, Any] | None = None, schema: str | None = None
) -> None:
    """Создаёт 8 таблиц витрин. Raw-слой должен быть уже создан (FK на raw-таблицы).

    ``schema`` -- см. `build_metadata` (теневая загрузка на PostgreSQL/MySQL).
    """
    manifest = manifest if manifest is not None else load_manifest()
    metadata = build_metadata(manifest, layer="mart", schema=schema)
    mart_tables = [
        t for t in metadata.tables.values() if manifest["tables"][t.name]["layer"] == "mart"
    ]
    metadata.create_all(engine, tables=mart_tables)


def drop_all(engine: Engine, manifest: dict[str, Any] | None = None) -> None:
    """Удаляет все таблицы схемы (raw + mart)."""
    manifest = manifest if manifest is not None else load_manifest()
    metadata = build_metadata(manifest)
    metadata.drop_all(engine)
