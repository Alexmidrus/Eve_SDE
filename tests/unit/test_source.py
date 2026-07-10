"""Тесты etl/source.py: замоканный httpx (httpx.MockTransport, без сети)."""

from __future__ import annotations

import io
import json
import zipfile
from pathlib import Path

import httpx
import pytest
from sqlalchemy import create_engine, insert

from evesde.etl.loader import load_all
from evesde.etl.source import (
    BuildInfo,
    SourceUnavailableError,
    check_remote_build,
    download,
    get_local_build,
)
from evesde.schema.builder import build_metadata, create_raw_tables, load_manifest

_TYPES_RECORD = {
    "_key": 587,
    "basePrice": 84177.0,
    "capacity": 130.0,
    "description": dict.fromkeys(("de", "en", "es", "fr", "ja", "ko", "ru", "zh"), "text"),
    "factionID": None,
    "graphicID": None,
    "groupID": 25,
    "iconID": 622,
    "marketGroupID": None,
    "mass": 1067000.0,
    "metaGroupID": None,
    "metaLevel": 0,
    "name": dict.fromkeys(("de", "en", "es", "fr", "ja", "ko", "ru", "zh"), "Rifter"),
    "portionSize": 1,
    "published": True,
    "raceID": 2,
    "radius": 39.0,
    "shipTreeGroupID": None,
    "soundID": None,
    "techLevel": 1,
    "variationParentTypeID": None,
    "volume": 27289.0,
}
_TYPES_LINE = json.dumps(_TYPES_RECORD) + "\n"


def _make_zip_bytes(files: dict[str, str]) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for name, content in files.items():
            zf.writestr(name, content)
    return buf.getvalue()


# ---------------------------------------------------------------------------
# check_remote_build
# ---------------------------------------------------------------------------


def test_check_remote_build_success() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path.endswith("/tranquility/latest.jsonl")
        body = json.dumps(
            {"_key": "sde", "buildNumber": 3428504, "releaseDate": "2026-07-09T11:05:50Z"}
        )
        return httpx.Response(200, text=body + "\n")

    client = httpx.Client(transport=httpx.MockTransport(handler))
    info = check_remote_build(client=client)
    assert info == BuildInfo(build_number=3428504, release_date="2026-07-09T11:05:50Z")


def test_check_remote_build_404() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404)

    client = httpx.Client(transport=httpx.MockTransport(handler))
    with pytest.raises(SourceUnavailableError, match="404"):
        check_remote_build(client=client)


def test_check_remote_build_connection_error() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("simulated: connection refused", request=request)

    client = httpx.Client(transport=httpx.MockTransport(handler))
    with pytest.raises(SourceUnavailableError, match="локальный каталог"):
        check_remote_build(client=client)


# ---------------------------------------------------------------------------
# download
# ---------------------------------------------------------------------------


def test_download_success(tmp_path: Path) -> None:
    zip_bytes = _make_zip_bytes({"types.jsonl": _TYPES_LINE})

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200, content=zip_bytes, headers={"content-length": str(len(zip_bytes))}
        )

    client = httpx.Client(transport=httpx.MockTransport(handler))
    dest = tmp_path / "sde"

    result = download(dest, client=client)

    assert result == dest
    assert (dest / "types.jsonl").read_text(encoding="utf-8") == _TYPES_LINE
    assert not (dest / "_sde_download.zip.part").exists()


def test_download_reports_progress(tmp_path: Path) -> None:
    zip_bytes = _make_zip_bytes({"types.jsonl": _TYPES_LINE})

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200, content=zip_bytes, headers={"content-length": str(len(zip_bytes))}
        )

    client = httpx.Client(transport=httpx.MockTransport(handler))
    progress: list[tuple[int, int | None]] = []

    download(
        tmp_path / "sde",
        client=client,
        progress_cb=lambda done, total: progress.append((done, total)),
    )

    assert progress
    assert progress[-1] == (len(zip_bytes), len(zip_bytes))


def test_download_resumes_after_interruption(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Обрыв соединения посреди потока -> повтор докачивает остаток через Range."""
    # iter_bytes(chunk_size) буферизует до полного чанка перед тем, как что-то отдать
    # наружу -- уменьшаем размер чанка, чтобы наш искусственный 10-байтовый кусок
    # успел "дойти" до записи на диск раньше, чем сработает симулированный обрыв.
    monkeypatch.setattr("evesde.etl.source._CHUNK_SIZE", 4)

    full_content = _make_zip_bytes({"types.jsonl": _TYPES_LINE})

    def first_attempt_body():
        yield full_content[:10]
        raise httpx.ReadError("simulated connection drop")

    def handler(request: httpx.Request) -> httpx.Response:
        range_header = request.headers.get("range")
        if range_header:
            start = int(range_header.removeprefix("bytes=").split("-")[0])
            remainder = full_content[start:]
            return httpx.Response(
                206,
                content=remainder,
                headers={
                    "content-length": str(len(remainder)),
                    "content-range": f"bytes {start}-{len(full_content) - 1}/{len(full_content)}",
                },
            )
        return httpx.Response(
            200, content=first_attempt_body(), headers={"content-length": str(len(full_content))}
        )

    client = httpx.Client(transport=httpx.MockTransport(handler))
    dest = tmp_path / "sde"

    download(dest, client=client)

    assert (dest / "types.jsonl").read_text(encoding="utf-8") == _TYPES_LINE


def test_download_raises_after_exhausting_retries(tmp_path: Path) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("simulated: always fails", request=request)

    client = httpx.Client(transport=httpx.MockTransport(handler))
    with pytest.raises(SourceUnavailableError, match="докачать"):
        download(tmp_path / "sde", client=client)


def test_download_404_raises_without_retry(tmp_path: Path) -> None:
    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        return httpx.Response(404)

    client = httpx.Client(transport=httpx.MockTransport(handler))
    with pytest.raises(SourceUnavailableError, match="404"):
        download(tmp_path / "sde", client=client)
    assert calls["n"] == 1  # постоянная ошибка -- без повторов


# ---------------------------------------------------------------------------
# get_local_build
# ---------------------------------------------------------------------------


def test_get_local_build_returns_none_without_table() -> None:
    engine = create_engine("sqlite:///:memory:")
    assert get_local_build(engine) is None


def test_get_local_build_returns_build_info() -> None:
    manifest = load_manifest()
    engine = create_engine("sqlite:///:memory:")
    create_raw_tables(engine, manifest)
    metadata = build_metadata(manifest, layer="raw")
    with engine.begin() as conn:
        conn.execute(
            insert(metadata.tables["sde"]),
            [{"id": "sde", "build_number": 123, "release_date": "2026-01-01T00:00:00Z"}],
        )

    info = get_local_build(engine)
    assert info == BuildInfo(build_number=123, release_date="2026-01-01T00:00:00Z")


def test_compare_local_and_remote_build() -> None:
    local = BuildInfo(build_number=123, release_date="2026-01-01T00:00:00Z")
    remote = BuildInfo(build_number=3428504, release_date="2026-07-09T11:05:50Z")
    assert local != remote
    assert local.build_number < remote.build_number


# ---------------------------------------------------------------------------
# Интеграция с load_all через локальный каталог (без сети)
# ---------------------------------------------------------------------------


def test_downloaded_directory_can_be_loaded_via_load_all(tmp_path: Path) -> None:
    zip_bytes = _make_zip_bytes({"types.jsonl": _TYPES_LINE})

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200, content=zip_bytes, headers={"content-length": str(len(zip_bytes))}
        )

    client = httpx.Client(transport=httpx.MockTransport(handler))
    dest = tmp_path / "sde"
    download(dest, client=client)

    manifest = load_manifest()
    engine = create_engine("sqlite:///:memory:")
    create_raw_tables(engine, manifest)

    result = load_all(engine, dest, manifest)

    assert result.total_rows == 1
    assert {f.file_name for f in result.files} == {"types.jsonl"}
