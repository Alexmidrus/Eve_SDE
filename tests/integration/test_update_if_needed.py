"""Тесты SDE.update_if_needed(): успешное обновление, сбой не портит
старую базу, интеграция с планировщиками (см. README «Расписание обновлений»)."""

from __future__ import annotations

import shutil
import time
from pathlib import Path
from typing import Any

import pytest

from evesde import SDE
from evesde.etl.source import BuildInfo

_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "sde_marts"
_BROKEN_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "sde_mini_broken"

_CURRENT_BUILD = BuildInfo(build_number=3428504, release_date="2026-07-09T11:05:50Z")
_NEW_BUILD = BuildInfo(build_number=9999999, release_date="2099-01-01T00:00:00Z")


def _copy_fixtures(src: Path):
    def _download(dest_dir: Path, *, progress_cb: Any = None, **_: Any) -> Path:
        for path in src.glob("*.jsonl"):
            shutil.copy(path, dest_dir / path.name)
        return dest_dir

    return _download


@pytest.fixture
def sde(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> SDE:
    """SDE с уже загруженными фикстурами sde_marts (build 3428504)."""
    monkeypatch.setattr("evesde.api.sde.check_remote_build", lambda *a, **k: _CURRENT_BUILD)
    monkeypatch.setattr("evesde.api.sde.download", _copy_fixtures(_FIXTURES_DIR))

    instance = SDE(f"sqlite:///{tmp_path / 'eve.db'}")
    result = instance.update_if_needed()
    assert result.updated is True
    return instance


def test_update_if_needed_downloads_new_build(sde: SDE, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("evesde.api.sde.check_remote_build", lambda *a, **k: _NEW_BUILD)
    monkeypatch.setattr("evesde.api.sde.download", _copy_fixtures(_FIXTURES_DIR))

    result = sde.update_if_needed()

    assert result.updated is True
    assert result.previous_build == _CURRENT_BUILD
    assert result.new_build == _NEW_BUILD
    assert result.verify_report is not None
    assert result.verify_report.ok
    assert sde.item("Rifter").name == "Rifter"


def test_update_if_needed_already_up_to_date_skips_download(
    sde: SDE, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = {"n": 0}

    def _counting_download(dest_dir: Path, **kwargs: Any) -> Path:
        calls["n"] += 1
        return dest_dir

    monkeypatch.setattr("evesde.api.sde.check_remote_build", lambda *a, **k: _CURRENT_BUILD)
    monkeypatch.setattr("evesde.api.sde.download", _counting_download)

    result = sde.update_if_needed()

    assert result.updated is False
    assert result.verify_report is None
    assert calls["n"] == 0


def test_update_if_needed_force_reloads_same_build(
    sde: SDE, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr("evesde.api.sde.check_remote_build", lambda *a, **k: _CURRENT_BUILD)
    monkeypatch.setattr("evesde.api.sde.download", _copy_fixtures(_FIXTURES_DIR))

    result = sde.update_if_needed(force=True)

    assert result.updated is True
    assert result.verify_report is not None


def test_update_if_needed_failure_leaves_old_database_intact(
    sde: SDE, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr("evesde.api.sde.check_remote_build", lambda *a, **k: _NEW_BUILD)
    monkeypatch.setattr("evesde.api.sde.download", _copy_fixtures(_BROKEN_DIR))

    with pytest.raises(Exception):  # noqa: B017 - json.JSONDecodeError из битой фикстуры
        sde.update_if_needed()

    # старая база осталась полностью рабочей через тот же объект SDE
    assert sde.item("Rifter").name == "Rifter"
    assert sde.meta().build_number == _CURRENT_BUILD.build_number


def test_progress_and_complete_callbacks_invoked(sde: SDE, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("evesde.api.sde.check_remote_build", lambda *a, **k: _NEW_BUILD)
    monkeypatch.setattr("evesde.api.sde.download", _copy_fixtures(_FIXTURES_DIR))

    progress_messages: list[str] = []
    completed: list[Any] = []

    result = sde.update_if_needed(
        on_progress=progress_messages.append,
        on_complete=completed.append,
    )

    assert progress_messages  # хотя бы одно сообщение о ходе обновления
    assert completed == [result]


# ---------------------------------------------------------------------------
# Интеграция с планировщиками: пример из README действительно работает.
# ---------------------------------------------------------------------------


def test_apscheduler_example_runs(sde: SDE, monkeypatch: pytest.MonkeyPatch) -> None:
    """Прогоняет пример из README «Расписание обновлений» -> APScheduler."""
    apscheduler = pytest.importorskip("apscheduler.schedulers.background")

    monkeypatch.setattr("evesde.api.sde.check_remote_build", lambda *a, **k: _NEW_BUILD)
    monkeypatch.setattr("evesde.api.sde.download", _copy_fixtures(_FIXTURES_DIR))

    ran: list[Any] = []

    def update_sde() -> None:
        result = sde.update_if_needed()
        ran.append(result)

    scheduler = apscheduler.BackgroundScheduler()
    scheduler.add_job(update_sde, "date")  # запуск один раз, немедленно
    scheduler.start()
    try:
        for _ in range(100):
            if ran:
                break
            time.sleep(0.05)
    finally:
        scheduler.shutdown(wait=False)

    assert len(ran) == 1
    assert ran[0].updated is True
    assert ran[0].new_build == _NEW_BUILD
