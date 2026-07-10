"""Скачивание SDE CCP и проверка версии build (CLAUDE.md §5).

Источник — официальный JSONL-дамп SDE, публикуемый CCP на developers.eveonline.com
(см. https://developers.eveonline.com/docs/services/static-data/ и блог
https://developers.eveonline.com/blog/reworking-the-sde-a-fresh-start-for-static-data).
Формат URL проверен вручную (curl) 2026-07-10:

* ``.../static-data/tranquility/latest.jsonl`` -- один JSON-объект
  ``{"_key": "sde", "buildNumber": ..., "releaseDate": ...}``, 302- и
  редиректов не требует, отдаётся напрямую (~80 байт) -- ровно то, что
  нужно для проверки версии без скачивания всего дампа.
* ``.../static-data/eve-online-static-data-latest-jsonl.zip`` -- редирект
  (с заголовком ``x-sde-build-number``) на архив конкретного build:
  ``.../static-data/tranquility/eve-online-static-data-<build>-jsonl.zip``.
  Раздаётся через CloudFront/S3, поддерживает ``Accept-Ranges: bytes``
  (докачка через HTTP Range) и ETag/Last-Modified.

Никаких обходов недоступного endpoint'а: если CCP не отвечает, поднимается
понятная `SourceUnavailableError` с советом указать локальный каталог
с уже скачанным SDE (``load_all``/``load_fresh`` работают с любым каталогом).
"""

from __future__ import annotations

import hashlib
import json
import logging
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from zipfile import ZipFile

import httpx
from sqlalchemy import inspect, select
from sqlalchemy.engine import Engine

from evesde.schema.builder import build_metadata, load_manifest

_LOGGER = logging.getLogger(__name__)

#: Официальный базовый endpoint CCP developers для статических данных.
DEFAULT_BASE_URL = "https://developers.eveonline.com/static-data"
_LATEST_BUILD_INFO_PATH = "/tranquility/latest.jsonl"
_LATEST_DUMP_PATH = "/eve-online-static-data-latest-jsonl.zip"

_MAX_RETRIES = 3
_CHUNK_SIZE = 1024 * 1024  # 1 МиБ
_PART_SUFFIX = ".part"


class SourceUnavailableError(Exception):
    """CCP-эндпоинт SDE недоступен -- обхода нет, укажите локальный каталог."""


class _IncompleteDownloadError(Exception):
    """Внутренний сигнал: скачанный размер не совпал с ожидаемым -- нужен повтор."""


@dataclass(frozen=True)
class BuildInfo:
    """Версия SDE: buildNumber/releaseDate из записи ``_key: "sde"``."""

    build_number: int
    release_date: str


def check_remote_build(
    base_url: str = DEFAULT_BASE_URL,
    *,
    client: httpx.Client | None = None,
) -> BuildInfo:
    """Возвращает текущую версию SDE у CCP -- без скачивания всего дампа.

    Читает маленький (~80 байт) файл ``tranquility/latest.jsonl``.
    """
    url = base_url.rstrip("/") + _LATEST_BUILD_INFO_PATH
    owns_client = client is None
    http_client = client or httpx.Client(timeout=30.0, follow_redirects=True)
    try:
        response = http_client.get(url)
    except httpx.HTTPError as exc:
        raise SourceUnavailableError(
            f"Не удалось обратиться к {url}: {exc}. Если CCP-эндпоинт недоступен, "
            "укажите локальный каталог с уже скачанным SDE явно."
        ) from exc
    finally:
        if owns_client:
            http_client.close()

    if response.status_code != 200:
        raise SourceUnavailableError(
            f"{url} вернул статус {response.status_code}. Если CCP-эндпоинт недоступен, "
            "укажите локальный каталог с уже скачанным SDE явно."
        )

    first_line = response.text.strip().splitlines()[0]
    record: dict[str, Any] = json.loads(first_line)
    return BuildInfo(build_number=record["buildNumber"], release_date=record["releaseDate"])


def get_local_build(engine: Engine) -> BuildInfo | None:
    """Возвращает версию SDE, загруженную в БД (таблица ``sde``), либо None."""
    if not inspect(engine).has_table("sde"):
        return None

    metadata = build_metadata(load_manifest(), layer="raw")
    table = metadata.tables["sde"]
    with engine.connect() as conn:
        row = conn.execute(select(table.c.build_number, table.c.release_date)).first()
    if row is None:
        return None
    return BuildInfo(build_number=row.build_number, release_date=row.release_date)


def download(
    dest_dir: Path,
    base_url: str = DEFAULT_BASE_URL,
    progress_cb: Callable[[int, int | None], None] | None = None,
    client: httpx.Client | None = None,
) -> Path:
    """Скачивает актуальный SDE (JSONL) и распаковывает его в `dest_dir`.

    Потоковая загрузка (``httpx`` streaming, без загрузки всего архива в
    память); при обрыве соединения -- докачка через HTTP Range (до
    `_MAX_RETRIES` попыток) с того места, где остановились. Целостность
    проверяется по ``Content-Length``; если сервер отдаёт ETag в виде
    простого MD5 (не составной, без ``-N``) -- дополнительно сверяется
    контрольная сумма скачанного файла.

    Возвращает `dest_dir` (тот же каталог можно передать в `load_all`).
    """
    dest_dir.mkdir(parents=True, exist_ok=True)
    url = base_url.rstrip("/") + _LATEST_DUMP_PATH
    archive_path = dest_dir / ("_sde_download.zip" + _PART_SUFFIX)

    owns_client = client is None
    http_client = client or httpx.Client(timeout=60.0, follow_redirects=True)
    try:
        _download_with_resume(http_client, url, archive_path, progress_cb)
        with ZipFile(archive_path) as zf:
            zf.extractall(dest_dir)
    finally:
        archive_path.unlink(missing_ok=True)
        if owns_client:
            http_client.close()

    return dest_dir


def _download_with_resume(
    client: httpx.Client,
    url: str,
    dest_path: Path,
    progress_cb: Callable[[int, int | None], None] | None,
) -> None:
    downloaded = dest_path.stat().st_size if dest_path.exists() else 0
    total: int | None = None
    last_error: Exception | None = None

    for attempt in range(1, _MAX_RETRIES + 1):
        headers = {"Range": f"bytes={downloaded}-"} if downloaded else {}
        try:
            with client.stream("GET", url, headers=headers) as response:
                if response.status_code == 416:
                    # Диапазон за пределами файла -- уже скачано полностью.
                    return
                if response.status_code not in (200, 206):
                    raise SourceUnavailableError(
                        f"{url} вернул статус {response.status_code}. Если CCP-эндпоинт "
                        "недоступен, укажите локальный каталог с уже скачанным SDE явно."
                    )

                resumed = response.status_code == 206
                if not resumed:
                    downloaded = 0
                content_length = response.headers.get("content-length")
                if content_length is not None:
                    total = downloaded + int(content_length)
                etag = response.headers.get("etag")

                with dest_path.open("ab" if resumed else "wb") as fh:
                    for chunk in response.iter_bytes(_CHUNK_SIZE):
                        fh.write(chunk)
                        downloaded += len(chunk)
                        if progress_cb is not None:
                            progress_cb(downloaded, total)

            if total is not None and downloaded != total:
                raise _IncompleteDownloadError(f"скачано {downloaded} из {total} байт")
            _verify_checksum_if_available(dest_path, etag)
            return
        except (httpx.TransportError, _IncompleteDownloadError) as exc:
            last_error = exc
            downloaded = dest_path.stat().st_size if dest_path.exists() else 0
            _LOGGER.warning(
                "Обрыв при скачивании SDE (попытка %d/%d): %s", attempt, _MAX_RETRIES, exc
            )

    raise SourceUnavailableError(
        f"Не удалось докачать {url} за {_MAX_RETRIES} попыток: {last_error}"
    ) from last_error


def _verify_checksum_if_available(path: Path, etag: str | None) -> None:
    """Сверяет MD5 файла с ETag, если это простой (не составной S3) хэш."""
    if not etag:
        return
    digest = etag.strip('"')
    if "-" in digest or len(digest) != 32:
        return  # составной ETag (multipart upload) -- не md5 всего файла, пропускаем
    hasher = hashlib.md5()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(_CHUNK_SIZE), b""):
            hasher.update(chunk)
    if hasher.hexdigest() != digest:
        raise _IncompleteDownloadError(f"контрольная сумма не совпала (ETag {digest})")
