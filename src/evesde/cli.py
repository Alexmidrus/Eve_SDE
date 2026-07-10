"""CLI-команды evesde: load, update, verify, status.

Тонкие обёртки над Python-API -- вся логика в библиотеке (`etl.*`,
`schema.*`, `api.queries`). Коды возврата: 0 -- успех, 1 -- ошибка
выполнения, 2 -- `verify` нашёл ошибки (не предупреждения). Прогресс
скачивания -- в stderr явно (см. `_download_progress`); прогресс загрузки
файлов -- тоже в stderr через стандартный `logging` (см. `etl.loader`,
который уже логирует по файлу: имя, число строк, время).
"""

from __future__ import annotations

import logging
import os
import sys
import tempfile
from pathlib import Path
from typing import Any

import click
from sqlalchemy import inspect

from evesde.api import queries as q
from evesde.config import SDEConfig, make_engine
from evesde.etl.loader import load_fresh
from evesde.etl.source import SourceUnavailableError, check_remote_build, download, get_local_build
from evesde.etl.verify import verify
from evesde.schema.builder import build_metadata, load_manifest

_LOGGER = logging.getLogger(__name__)


def _resolve_config(db: str | None) -> SDEConfig:
    url = db or os.environ.get("EVESDE_DB")
    if not url:
        raise click.ClickException(
            "Не указана база данных: используйте --db <url> или переменную окружения EVESDE_DB"
        )
    return SDEConfig.from_url(url)


def _download_progress(downloaded: int, total: int | None) -> None:
    if total:
        pct = downloaded * 100 // total
        click.echo(f"\rСкачивание SDE: {pct}% ({downloaded}/{total} байт)", nl=False, err=True)
    else:
        click.echo(f"\rСкачивание SDE: {downloaded} байт", nl=False, err=True)


def _db_size(config: SDEConfig) -> int | None:
    """Размер файла БД в байтах (только для файлового SQLite, иначе None)."""
    if config.url.get_backend_name() != "sqlite":
        return None
    database = config.url.database
    if not database or database == ":memory:":
        return None
    path = Path(database)
    return path.stat().st_size if path.exists() else None


def _human_size(num_bytes: int) -> str:
    value = float(num_bytes)
    for unit in ("Б", "КБ", "МБ", "ГБ"):
        if value < 1024:
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{value:.1f} ТБ"


def _load_and_verify(config: SDEConfig, sde_dir: Path, manifest: dict[str, Any]) -> None:
    """Общее ядро для `load` и `update`: атомарная загрузка + verify + отчёт."""
    click.echo(f"Загрузка raw-слоя и витрин из {sde_dir}...", err=True)
    result = load_fresh(config, sde_dir, manifest)
    click.echo(f"Загружено {result.total_rows} строк из {len(result.files)} файлов.", err=True)

    engine = make_engine(config)
    report = verify(engine, sde_dir=sde_dir, manifest=manifest)
    click.echo(report.summary(), err=True)
    if not report.ok:
        sys.exit(2)


@click.group()
@click.option(
    "--db", envvar="EVESDE_DB", default=None, help="URL БД (SQLAlchemy) или переменная EVESDE_DB."
)
@click.pass_context
def cli(ctx: click.Context, db: str | None) -> None:
    """evesde -- загрузка, обновление и проверка статических данных EVE Online (SDE)."""
    logging.basicConfig(stream=sys.stderr, level=logging.INFO, format="%(message)s")
    ctx.ensure_object(dict)
    ctx.obj["db"] = db


@cli.command()
@click.argument(
    "sde_dir", required=False, type=click.Path(exists=True, file_okay=False, path_type=Path)
)
@click.option(
    "--download",
    "do_download",
    is_flag=True,
    default=False,
    help="Скачать актуальный SDE у CCP вместо локального каталога.",
)
@click.pass_context
def load(ctx: click.Context, sde_dir: Path | None, do_download: bool) -> None:
    """Загружает SDE в БД: из SDE_DIR или --download (атомарная подмена + verify)."""
    if bool(sde_dir) == bool(do_download):
        raise click.UsageError("Укажите либо SDE_DIR, либо --download (не оба и не ни одного).")

    config = _resolve_config(ctx.obj.get("db"))
    manifest = load_manifest()

    try:
        if do_download:
            with tempfile.TemporaryDirectory(prefix="evesde-sde-") as tmp:
                tmp_path = Path(tmp)
                click.echo("Скачивание SDE...", err=True)
                download(tmp_path, progress_cb=_download_progress)
                click.echo("", err=True)
                _load_and_verify(config, tmp_path, manifest)
        else:
            assert sde_dir is not None
            _load_and_verify(config, sde_dir, manifest)
    except Exception as exc:
        click.echo(f"Ошибка загрузки: {exc}", err=True)
        sys.exit(1)


@cli.command()
@click.option(
    "--force", is_flag=True, default=False, help="Загрузить, даже если версия не изменилась."
)
@click.pass_context
def update(ctx: click.Context, force: bool) -> None:
    """Сверяет версию SDE у CCP с локальной и обновляет БД при выходе нового build."""
    config = _resolve_config(ctx.obj.get("db"))
    manifest = load_manifest()

    try:
        engine = make_engine(config)
        try:
            local_build = get_local_build(engine)
        finally:
            # Открытое подключение держит файл БД занятым и на Windows не даёт
            # атомарно подменить его внутри load_fresh -- закрываем заранее.
            engine.dispose()
        remote_build = check_remote_build()
    except SourceUnavailableError as exc:
        click.echo(f"Ошибка: {exc}", err=True)
        sys.exit(1)
        return

    if (
        local_build is not None
        and local_build.build_number == remote_build.build_number
        and not force
    ):
        click.echo(f"Уже актуально: build {local_build.build_number}.", err=True)
        return

    current = local_build.build_number if local_build is not None else "нет"
    click.echo(
        f"Найден build {remote_build.build_number} (текущий: {current}). Обновление...", err=True
    )

    try:
        with tempfile.TemporaryDirectory(prefix="evesde-sde-") as tmp:
            tmp_path = Path(tmp)
            click.echo("Скачивание SDE...", err=True)
            download(tmp_path, progress_cb=_download_progress)
            click.echo("", err=True)
            _load_and_verify(config, tmp_path, manifest)
    except Exception as exc:
        click.echo(f"Ошибка обновления: {exc}", err=True)
        sys.exit(1)


@cli.command(name="verify")
@click.argument(
    "sde_dir", required=False, type=click.Path(exists=True, file_okay=False, path_type=Path)
)
@click.pass_context
def verify_command(ctx: click.Context, sde_dir: Path | None) -> None:
    """Проверяет уже загруженную БД (см. etl.verify): целостность, версия."""
    config = _resolve_config(ctx.obj.get("db"))
    engine = make_engine(config)
    manifest = load_manifest()

    report = verify(engine, sde_dir=sde_dir, manifest=manifest)
    click.echo(report.summary())
    if not report.ok:
        sys.exit(2)


@cli.command()
@click.pass_context
def status(ctx: click.Context) -> None:
    """Показывает версию SDE, количество таблиц/строк в витринах и размер БД."""
    config = _resolve_config(ctx.obj.get("db"))
    engine = make_engine(config)
    manifest = load_manifest()

    existing = set(inspect(engine).get_table_names())
    click.echo(f"Таблиц в БД: {len(existing)} (в манифесте: {len(manifest['tables'])})")

    size = _db_size(config)
    click.echo(f"Размер БД: {_human_size(size) if size is not None else 'н/д'}")

    if not {"dim_items", "dim_universe", "dim_agents"} <= existing:
        click.echo("SDE не загружен (витрины отсутствуют).")
        return

    metadata = build_metadata(manifest)
    info = q.meta(engine, metadata)
    if info.build_number is not None:
        click.echo(f"Build: {info.build_number} ({info.release_date})")
    else:
        click.echo("Build: неизвестен")
    click.echo(
        f"Предметов: {info.item_count}, систем: {info.system_count}, агентов: {info.agent_count}"
    )


if __name__ == "__main__":
    cli()
