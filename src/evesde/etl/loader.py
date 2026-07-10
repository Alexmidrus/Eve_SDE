"""Потоковая батч-загрузка JSONL в raw-слой и атомарная подмена (CLAUDE.md §5).

``load_file``/``load_all`` читают JSONL построчно (никогда не грузят файл
целиком в память), превращают каждую запись в строки таблиц через
`evesde.etl.transform.transform_record` и вставляют их батчами через
executemany, одна транзакция на файл. ``load_fresh`` выполняет полный цикл
в теневое хранилище, чтобы читатели никогда не видели наполовину
загруженную базу: для SQLite -- отдельный файл + атомарный `os.replace`;
для PostgreSQL/MySQL -- отдельная схема/база + атомарное переименование.
"""

from __future__ import annotations

import json
import logging
import os
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from sqlalchemy import MetaData, Table, insert
from sqlalchemy.engine import Connection, Engine

from evesde.config import SDEConfig, make_engine
from evesde.etl.marts import build_marts
from evesde.etl.transform import IdAllocator, TransformReport, transform_record
from evesde.schema.builder import (
    build_metadata,
    create_indexes,
    create_mart_tables,
    create_raw_tables,
    load_manifest,
)

_LOGGER = logging.getLogger(__name__)

#: Размер батча executemany-вставки (§5 CLAUDE.md: 5000-10000 строк).
_DEFAULT_BATCH_SIZE = 5000


@dataclass
class FileLoadResult:
    """Результат загрузки одного файла."""

    file_name: str
    row_counts: dict[str, int]
    seconds: float

    @property
    def total_rows(self) -> int:
        """Суммарное число загруженных строк по всем таблицам этого файла."""
        return sum(self.row_counts.values())


@dataclass
class LoadResult:
    """Результат загрузки каталога SDE (`load_all`)."""

    files: list[FileLoadResult] = field(default_factory=list)
    report: TransformReport = field(default_factory=TransformReport)
    skipped_files: list[str] = field(default_factory=list)

    @property
    def total_rows(self) -> int:
        """Суммарное число загруженных строк по всем файлам."""
        return sum(f.total_rows for f in self.files)


def _iter_jsonl(path: Path) -> Any:
    """Потоковое построчное чтение .jsonl (без загрузки всего файла в память)."""
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            yield json.loads(line)


def _set_sqlite_bulk_load_pragmas(conn: Connection) -> None:
    conn.exec_driver_sql("PRAGMA foreign_keys=OFF")
    conn.exec_driver_sql("PRAGMA synchronous=OFF")
    conn.exec_driver_sql("PRAGMA journal_mode=MEMORY")


def _normalize_row(row: dict[str, Any], columns: list[str]) -> dict[str, Any]:
    """Приводит строку к полному набору колонок таблицы (недостающие -> None).

    Нужно, т.к. одна и та же таблица в разных JSON-записях может получать
    разные подмножества полей (опциональные вложенные объекты), а один
    executemany-батч требует одинакового набора параметров у всех строк.
    """
    return {col: row.get(col) for col in columns}


def _flush(
    conn: Connection,
    table: Table,
    buffer: list[dict[str, Any]],
    row_counts: dict[str, int],
) -> None:
    if not buffer:
        return
    conn.execute(insert(table), buffer)
    row_counts[table.name] = row_counts.get(table.name, 0) + len(buffer)


def load_file(
    engine: Engine,
    path: Path,
    manifest: dict[str, Any],
    id_allocator: IdAllocator | None = None,
    report: TransformReport | None = None,
    batch_size: int = _DEFAULT_BATCH_SIZE,
    metadata: MetaData | None = None,
) -> FileLoadResult:
    """Загружает один jsonl-файл в raw-таблицы одной транзакцией.

    ``id_allocator``/``report`` можно передать общими на несколько вызовов
    (так делает `load_all`), чтобы суррогатные id были сквозными по всем
    файлам одной загрузки. ``metadata`` -- необязательный override набора
    таблиц-приёмников (используется `load_fresh` для теневой схемы/базы на
    PostgreSQL/MySQL); по умолчанию строится из манифеста (raw-слой).
    """
    id_allocator = id_allocator if id_allocator is not None else IdAllocator()
    report = report if report is not None else TransformReport()
    metadata = metadata if metadata is not None else build_metadata(manifest, layer="raw")
    table_map = {t.name: t for t in metadata.tables.values()}

    file_name = path.name
    started = time.monotonic()
    row_counts: dict[str, int] = {}
    buffers: dict[str, list[dict[str, Any]]] = {}

    with engine.begin() as conn:
        if engine.dialect.name == "sqlite":
            _set_sqlite_bulk_load_pragmas(conn)

        for record in _iter_jsonl(path):
            rows_by_table = transform_record(file_name, record, manifest, id_allocator, report)
            for table_name, rows in rows_by_table.items():
                if not rows:
                    continue
                columns = [c["name"] for c in manifest["tables"][table_name]["columns"]]
                buffer = buffers.setdefault(table_name, [])
                buffer.extend(_normalize_row(row, columns) for row in rows)
                if len(buffer) >= batch_size:
                    _flush(conn, table_map[table_name], buffer, row_counts)
                    buffers[table_name] = []

        for table_name, buffer in buffers.items():
            _flush(conn, table_map[table_name], buffer, row_counts)

    elapsed = time.monotonic() - started
    _LOGGER.info(
        "Загружен файл %s: %d строк за %.2fс (%s)",
        file_name,
        sum(row_counts.values()),
        elapsed,
        row_counts,
    )
    return FileLoadResult(file_name=file_name, row_counts=row_counts, seconds=elapsed)


def load_all(
    engine: Engine,
    sde_dir: Path,
    manifest: dict[str, Any] | None = None,
    metadata: MetaData | None = None,
) -> LoadResult:
    """Загружает все ``*.jsonl`` файлы каталога `sde_dir` в raw-таблицы.

    Порядок файлов не важен (FK объявлены как ``use_alter``/не проверяются
    во время загрузки -- см. `load_file`). После загрузки всех файлов
    строит индексы (`create_indexes`) -- индексы создаются один раз, после
    данных, а не до (правило §5 CLAUDE.md).
    """
    manifest = manifest if manifest is not None else load_manifest()
    metadata = metadata if metadata is not None else build_metadata(manifest, layer="raw")
    known_files = {
        t["source_file"] for t in manifest["tables"].values() if t["layer"] == "raw_root"
    }

    id_allocator = IdAllocator()
    report = TransformReport()
    result = LoadResult(report=report)

    for path in sorted(sde_dir.glob("*.jsonl")):
        if path.name not in known_files:
            _LOGGER.warning("Файл %s не описан в манифесте -- пропущен", path.name)
            result.skipped_files.append(path.name)
            continue
        result.files.append(
            load_file(engine, path, manifest, id_allocator, report, metadata=metadata)
        )

    create_indexes(engine, metadata)
    return result


def load_fresh(
    config: SDEConfig,
    sde_dir: Path,
    manifest: dict[str, Any] | None = None,
) -> LoadResult:
    """Полная загрузка raw-слоя и витрин в теневое хранилище с атомарной подменой.

    Читатели, использующие исходный `config`, не видят промежуточного
    состояния: для SQLite строится отдельный файл БД (raw + marts + verify-
    независимые индексы) и атомарно подменяет старый (`os.replace`); для
    PostgreSQL -- отдельная схема с переносом через ``ALTER SCHEMA ...
    RENAME``; для MySQL/MariaDB -- отдельная база с переносом через
    ``RENAME TABLE`` (в MySQL это атомарная DDL-операция).

    ВАЖНО (Windows): если вызывающий код уже держит открытый `Engine`,
    указывающий на тот же файл SQLite (например, долгоживущий `SDE.engine`),
    его нужно явно `dispose()` ДО вызова `load_fresh` и пересоздать после --
    иначе `os.replace` упадёт с "Access is denied" (Windows блокирует
    переименование файла с открытым хендлом; POSIX это допускает).
    """
    manifest = manifest if manifest is not None else load_manifest()
    dialect = config.url.get_backend_name()
    if dialect == "sqlite":
        return _load_fresh_sqlite(config, sde_dir, manifest)
    if dialect == "postgresql":
        return _load_fresh_postgresql(config, sde_dir, manifest)
    if dialect in ("mysql", "mariadb"):
        return _load_fresh_mysql(config, sde_dir, manifest)
    raise ValueError(f"load_fresh не поддерживает диалект {dialect!r}")


def _load_fresh_sqlite(config: SDEConfig, sde_dir: Path, manifest: dict[str, Any]) -> LoadResult:
    database = config.url.database
    if not database or database == ":memory:":
        # Нет файла для атомарной подмены -- грузим прямо в целевой engine.
        engine = make_engine(config)
        create_raw_tables(engine, manifest)
        return load_all(engine, sde_dir, manifest)

    original_path = Path(database)
    shadow_path = original_path.with_name(original_path.name + ".new")
    if shadow_path.exists():
        shadow_path.unlink()

    shadow_engine = make_engine(SDEConfig.from_params(dialect="sqlite", database=str(shadow_path)))
    try:
        create_raw_tables(shadow_engine, manifest)
        result = load_all(shadow_engine, sde_dir, manifest)
        create_mart_tables(shadow_engine, manifest)
        build_marts(shadow_engine)
    except BaseException:
        shadow_engine.dispose()
        shadow_path.unlink(missing_ok=True)
        raise
    shadow_engine.dispose()

    os.replace(shadow_path, original_path)
    return result


def _load_fresh_postgresql(
    config: SDEConfig, sde_dir: Path, manifest: dict[str, Any]
) -> LoadResult:
    engine = make_engine(config)
    target_schema = "public"
    shadow_schema = f"evesde_shadow_{uuid.uuid4().hex[:8]}"
    old_schema = f"evesde_old_{uuid.uuid4().hex[:8]}"

    with engine.begin() as conn:
        conn.exec_driver_sql(f'CREATE SCHEMA "{shadow_schema}"')

    shadow_metadata = build_metadata(manifest, layer="raw", schema=shadow_schema)
    try:
        shadow_metadata.create_all(engine)
        result = load_all(engine, sde_dir, manifest, metadata=shadow_metadata)
        create_mart_tables(engine, manifest, schema=shadow_schema)
        build_marts(engine, schema=shadow_schema)
    except BaseException:
        with engine.begin() as conn:
            conn.exec_driver_sql(f'DROP SCHEMA "{shadow_schema}" CASCADE')
        raise

    with engine.begin() as conn:
        has_target = conn.exec_driver_sql(
            "SELECT 1 FROM information_schema.schemata WHERE schema_name = %(name)s",
            {"name": target_schema},
        ).first()
        if has_target:
            conn.exec_driver_sql(f'ALTER SCHEMA "{target_schema}" RENAME TO "{old_schema}"')
        conn.exec_driver_sql(f'ALTER SCHEMA "{shadow_schema}" RENAME TO "{target_schema}"')

    with engine.begin() as conn:
        if has_target:
            conn.exec_driver_sql(f'DROP SCHEMA "{old_schema}" CASCADE')

    return result


def _load_fresh_mysql(config: SDEConfig, sde_dir: Path, manifest: dict[str, Any]) -> LoadResult:
    engine = make_engine(config)
    with engine.connect() as conn:
        target_db = conn.exec_driver_sql("SELECT DATABASE()").scalar()
    if not target_db:
        raise ValueError("Не удалось определить текущую базу данных MySQL из подключения")

    shadow_db = f"{target_db}_shadow_{uuid.uuid4().hex[:8]}"
    old_db = f"{target_db}_old_{uuid.uuid4().hex[:8]}"

    with engine.begin() as conn:
        conn.exec_driver_sql(f"CREATE DATABASE `{shadow_db}`")

    shadow_metadata = build_metadata(manifest, layer="raw", schema=shadow_db)
    try:
        shadow_metadata.create_all(engine)
        result = load_all(engine, sde_dir, manifest, metadata=shadow_metadata)
        create_mart_tables(engine, manifest, schema=shadow_db)
        build_marts(engine, schema=shadow_db)
    except BaseException:
        with engine.begin() as conn:
            conn.exec_driver_sql(f"DROP DATABASE `{shadow_db}`")
        raise

    mart_names = [name for name, t in manifest["tables"].items() if t["layer"] == "mart"]
    table_names = [t.name for t in shadow_metadata.tables.values()] + mart_names
    with engine.begin() as conn:
        existing = (
            conn.exec_driver_sql(
                "SELECT table_name FROM information_schema.tables WHERE table_schema = %s",
                (target_db,),
            )
            .scalars()
            .all()
        )
    existing_names = set(existing)

    with engine.begin() as conn:
        # Оба направления переименования -- в ОДНОМ RENAME TABLE, иначе между
        # "увести старые" и "ввести новые" будет окно, где в target_db вообще
        # нет наших таблиц (нарушает "читатели не видят полупустую базу").
        # RENAME TABLE в MySQL/MariaDB атомарен именно для одного стейтмента
        # с несколькими таблицами -- см. документацию MySQL/MariaDB.
        moves: list[str] = []
        if existing_names:
            conn.exec_driver_sql(f"CREATE DATABASE IF NOT EXISTS `{old_db}`")
            moves.extend(
                f"`{target_db}`.`{n}` TO `{old_db}`.`{n}`"
                for n in table_names
                if n in existing_names
            )
        moves.extend(f"`{shadow_db}`.`{n}` TO `{target_db}`.`{n}`" for n in table_names)
        conn.exec_driver_sql(f"RENAME TABLE {', '.join(moves)}")

    with engine.begin() as conn:
        conn.exec_driver_sql(f"DROP DATABASE `{shadow_db}`")
        if existing_names:
            conn.exec_driver_sql(f"DROP DATABASE `{old_db}`")

    return result
