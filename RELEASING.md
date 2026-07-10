# Чек-лист релиза

Публикация в PyPI этим чек-листом **не выполняется** — только подготовка
и локальная проверка пакета (сборка, `twine check`, установка в чистый
venv). Публиковать (`twine upload`) — отдельное, осознанное действие.

## Перед релизом

1. Убедиться, что рабочее дерево чистое (`git status`) и весь набор тестов
   зелёный:
   ```bash
   pip install -e ".[dev]"
   ruff check .
   ruff format --check .
   mypy
   pytest                 # dbms-тесты пропустятся без docker-compose
   ```
2. Обновить версию:
   - `version` в `pyproject.toml` (semver: `MAJOR.MINOR.PATCH`).
   - Перенести содержимое `[Unreleased]` в `CHANGELOG.md` в новую секцию
     `[X.Y.Z] - YYYY-MM-DD`, оставить `[Unreleased]` пустым сверху.
3. Если это первый релиз в публичный репозиторий — добавить в
   `[project.urls]` в `pyproject.toml` реальные `Homepage`/`Repository`/
   `Issues` (сейчас не указаны: проект ещё не привязан к конкретному
   git-хостингу).

## Сборка

```bash
pip install -e ".[release]"   # build, twine -- только для этого чек-листа
rm -rf dist build src/*.egg-info
python -m build                # соберёт sdist (.tar.gz) и wheel (.whl) в dist/
twine check dist/*
```

`twine check` должен вывести `PASSED` для обоих файлов.

## Проверка в чистом окружении

Устанавливать нужно именно из `dist/*.whl`, а не editable-режимом — это
проверяет, что `MANIFEST`/`package-data` (включая `schema/manifest.json` и
`py.typed`) реально попали в собранный пакет:

```bash
python -m venv /tmp/evesde-release-check
/tmp/evesde-release-check/bin/pip install dist/evesde-*.whl
/tmp/evesde-release-check/bin/python -c "
from evesde import SDE
sde = SDE('sqlite:////tmp/evesde-release-check/eve.db')
print(sde.engine)  # подключение работает, manifest.json нашёлся и прочитался
"
```

Импорт `evesde.SDE` и создание объекта уже требуют, чтобы
`schema/manifest.json` был найден внутри установленного пакета — если его
нет в wheel, здесь будет `FileNotFoundError`.

## После проверки (публикация — вручную, не автоматически)

```bash
twine upload dist/*
git tag vX.Y.Z
git push origin vX.Y.Z
```

## Откат

Если после `twine upload` найдена проблема — версию на PyPI нельзя
перезаписать. Выпустить новую патч-версию с исправлением; при
необходимости пометить сломанный релиз как `yanked` через интерфейс PyPI.
