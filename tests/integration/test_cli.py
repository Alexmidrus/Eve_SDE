"""Тесты CLI (evesde.cli) через click.testing.CliRunner: SQLite + фикстуры, download замокан."""

from __future__ import annotations

import shutil
from pathlib import Path
from typing import Any

import pytest
from click.testing import CliRunner
from sqlalchemy import create_engine, delete

from evesde.cli import cli
from evesde.etl.source import BuildInfo
from evesde.schema.builder import build_metadata, load_manifest

_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "sde_marts"


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


def _fake_download(dest_dir: Path, *, progress_cb: Any = None, **_: Any) -> Path:
    """Замена etl.source.download(): просто копирует фикстуры (без сети)."""
    for path in _FIXTURES_DIR.glob("*.jsonl"):
        shutil.copy(path, dest_dir / path.name)
    if progress_cb is not None:
        progress_cb(1, 1)
    return dest_dir


def test_help_is_meaningful(runner: CliRunner) -> None:
    result = runner.invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "load" in result.output
    assert "update" in result.output
    assert "verify" in result.output
    assert "status" in result.output


def test_load_from_directory_success(runner: CliRunner, tmp_path: Path) -> None:
    db_path = tmp_path / "eve.db"
    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "load", str(_FIXTURES_DIR)])

    assert result.exit_code == 0, result.output
    assert db_path.exists()
    assert "Проблем не найдено" in result.output


def test_load_requires_exactly_one_of_dir_or_download(runner: CliRunner, tmp_path: Path) -> None:
    db_path = tmp_path / "eve.db"
    result_none = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "load"])
    assert result_none.exit_code != 0

    result_both = runner.invoke(
        cli, ["--db", f"sqlite:///{db_path}", "load", str(_FIXTURES_DIR), "--download"]
    )
    assert result_both.exit_code != 0


def test_load_missing_db_option_is_an_error(runner: CliRunner) -> None:
    result = runner.invoke(cli, ["load", str(_FIXTURES_DIR)])
    assert result.exit_code == 1
    assert "EVESDE_DB" in result.output


def test_load_with_download_flag(
    runner: CliRunner, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr("evesde.cli.download", _fake_download)
    db_path = tmp_path / "eve.db"

    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "load", "--download"])

    assert result.exit_code == 0, result.output
    assert db_path.exists()


def test_db_url_from_env_var(
    runner: CliRunner, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    db_path = tmp_path / "eve.db"
    monkeypatch.setenv("EVESDE_DB", f"sqlite:///{db_path}")

    result = runner.invoke(cli, ["load", str(_FIXTURES_DIR)])

    assert result.exit_code == 0, result.output
    assert db_path.exists()


def _load_fixtures(db_path: Path) -> None:
    runner = CliRunner()
    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "load", str(_FIXTURES_DIR)])
    assert result.exit_code == 0, result.output


def test_verify_clean_database(runner: CliRunner, tmp_path: Path) -> None:
    db_path = tmp_path / "eve.db"
    _load_fixtures(db_path)

    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "verify"])

    assert result.exit_code == 0, result.output
    assert "Проблем не найдено" in result.output


def test_verify_reports_errors_with_exit_code_2(runner: CliRunner, tmp_path: Path) -> None:
    db_path = tmp_path / "eve.db"
    _load_fixtures(db_path)

    manifest = load_manifest()
    engine = create_engine(f"sqlite:///{db_path}")
    metadata = build_metadata(manifest, layer="raw")
    with engine.begin() as conn:
        conn.execute(delete(metadata.tables["types"]).where(metadata.tables["types"].c.id == 587))
    engine.dispose()

    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "verify"])

    assert result.exit_code == 2, result.output


def test_status_before_load(runner: CliRunner, tmp_path: Path) -> None:
    db_path = tmp_path / "eve.db"
    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "status"])

    assert result.exit_code == 0, result.output
    assert "не загружен" in result.output


def test_status_after_load(runner: CliRunner, tmp_path: Path) -> None:
    db_path = tmp_path / "eve.db"
    _load_fixtures(db_path)

    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "status"])

    assert result.exit_code == 0, result.output
    assert "Build: 3428504" in result.output
    assert "Таблиц в БД:" in result.output


def test_update_already_up_to_date(
    runner: CliRunner, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    db_path = tmp_path / "eve.db"
    _load_fixtures(db_path)  # локальный build = 3428504 (из _sde.jsonl фикстуры)

    monkeypatch.setattr(
        "evesde.cli.check_remote_build",
        lambda *a, **k: BuildInfo(build_number=3428504, release_date="2026-07-09T11:05:50Z"),
    )

    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "update"])

    assert result.exit_code == 0, result.output
    assert "Уже актуально" in result.output


def test_update_downloads_new_build(
    runner: CliRunner, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    db_path = tmp_path / "eve.db"
    monkeypatch.setattr(
        "evesde.cli.check_remote_build",
        lambda *a, **k: BuildInfo(build_number=9999999, release_date="2099-01-01T00:00:00Z"),
    )
    monkeypatch.setattr("evesde.cli.download", _fake_download)

    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "update"])

    assert result.exit_code == 0, result.output
    assert db_path.exists()


def test_update_remote_unavailable(
    runner: CliRunner, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    from evesde.etl.source import SourceUnavailableError

    def _raise(*args: Any, **kwargs: Any) -> BuildInfo:
        raise SourceUnavailableError("simulated: CCP endpoint down")

    monkeypatch.setattr("evesde.cli.check_remote_build", _raise)

    db_path = tmp_path / "eve.db"
    result = runner.invoke(cli, ["--db", f"sqlite:///{db_path}", "update"])

    assert result.exit_code == 1
