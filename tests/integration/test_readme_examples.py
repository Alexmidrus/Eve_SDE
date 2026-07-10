"""Проверяет, что каждый python-пример из README.md реально выполняется на
SQLite (T13). Сеть (check_remote_build/download) замокана на локальные
фикстуры sde_marts -- сами примеры выполняются дословно, без правок."""

from __future__ import annotations

import re
import shutil
from pathlib import Path
from typing import Any

import pytest

from evesde.etl.source import BuildInfo

_README = Path(__file__).resolve().parents[2] / "README.md"
_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "sde_marts"
_BUILD = BuildInfo(build_number=3428504, release_date="2026-07-09T11:05:50Z")


def _python_blocks() -> list[str]:
    text = _README.read_text(encoding="utf-8")
    return re.findall(r"```python\n(.*?)```", text, flags=re.DOTALL)


def _fake_download(dest_dir: Path, *, progress_cb: Any = None, **_: Any) -> Path:
    for path in _FIXTURES_DIR.glob("*.jsonl"):
        shutil.copy(path, dest_dir / path.name)
    return dest_dir


@pytest.fixture(autouse=True)
def _mock_network(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("evesde.api.sde.check_remote_build", lambda *a, **k: _BUILD)
    monkeypatch.setattr("evesde.api.sde.download", _fake_download)


def test_readme_has_the_expected_python_examples() -> None:
    blocks = _python_blocks()
    assert len(blocks) == 4  # EN quickstart, RU quickstart, APScheduler, Celery beat


def test_quickstart_examples_run_verbatim(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """И русский, и английский quickstart из README (оба используют
    ``sqlite:///eve.db`` -- относительный путь, поэтому изолируем через chdir,
    не трогая сам код примера)."""
    monkeypatch.chdir(tmp_path)
    quickstarts = [
        block
        for block in _python_blocks()
        if "update_if_needed()" in block and 'sde.item("Rifter")' in block
    ]
    assert len(quickstarts) == 2

    for i, block in enumerate(quickstarts):
        namespace: dict[str, Any] = {}
        exec(compile(block, f"<readme:quickstart-{i}>", "exec"), namespace)  # noqa: S102
        assert namespace["ship"].name == "Rifter"
        assert namespace["sde"].meta().build_number == _BUILD.build_number


def test_apscheduler_example_job_runs(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """`scheduler.start()` -- блокирующий вызов (BlockingScheduler): выполняем
    пример до него дословно, затем вручную дёргаем задачу один раз, как это
    сделал бы сам APScheduler по расписанию."""
    monkeypatch.chdir(tmp_path)
    (block,) = [b for b in _python_blocks() if "BlockingScheduler" in b]
    lines = block.splitlines()
    assert lines[-1].strip() == "scheduler.start()"
    setup_code = "\n".join(lines[:-1])

    namespace: dict[str, Any] = {}
    exec(compile(setup_code, "<readme:apscheduler>", "exec"), namespace)  # noqa: S102

    namespace["update_sde"]()  # один тик, как будто сработал scheduled_job
    assert namespace["sde"].item("Rifter").name == "Rifter"


def test_celery_beat_example_configures_without_broker(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Создание Celery-приложения и `app.conf.beat_schedule` не требуют
    работающего брокера -- подключение к redis происходит лениво, при
    первой реальной отправке/чтении задачи. Сам пример только настраивает
    расписание и не вызывает задачу -- дёргаем её напрямую (минуя брокер,
    как обычный вызов Python-функции), чтобы убедиться, что тело задачи
    рабочее."""
    monkeypatch.chdir(tmp_path)
    (block,) = [b for b in _python_blocks() if "from celery import Celery" in b]

    namespace: dict[str, Any] = {}
    exec(compile(block, "<readme:celery-beat>", "exec"), namespace)  # noqa: S102

    assert "update-sde-every-6-hours" in namespace["app"].conf.beat_schedule

    namespace["update_sde"]()  # прямой вызов задачи, как это сделал бы воркер
    assert namespace["sde"].item("Rifter").name == "Rifter"
