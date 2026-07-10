# Changelog

[Keep a Changelog](https://keepachangelog.com/ru/1.0.0/).

## [Unreleased]

## [0.1.0] - 2026-07-10

### Добавлено

- Каркас пакета (src-layout), конфигурация подключения (`SDEConfig`) для
  SQLite/PostgreSQL/MySQL/MariaDB с валидацией диалекта и драйвера.
- Генератор `manifest.json` из эталонного `reference/eve_sde_full_schema.sql`
  (`tools/gen_manifest.py`) — источник истины для схемы и ETL.
- Построение SQLAlchemy `MetaData` из манифеста (`schema/builder.py`):
  raw-слой (174 таблицы) и витрины (8 таблиц), индексы отложены до загрузки.
- Чистые функции преобразования JSON-записи SDE в строки таблиц
  (`etl/transform.py`) по конвенциям `_key`/camelCase/flatten/локализация/
  суррогатные id.
- Потоковый батч-загрузчик JSONL (`etl/loader.py`) с атомарной подменой БД
  (`load_fresh`) для SQLite/PostgreSQL/MySQL/MariaDB.
- Скачивание SDE и проверка версии у CCP (`etl/source.py`), с докачкой по
  HTTP Range и повтором при обрыве.
- Построение витрин `INSERT ... SELECT` из raw-слоя (`etl/marts.py`).
- Верификация загруженного SDE: количество строк, FK-сироты, пустые
  витрины, версия (`etl/verify.py`) — только диагностика, ничего не чинит.
- Публичный API запросов (`evesde.SDE`): `item`, `items`, `search`, `stats`,
  `dogma`, `system`, `systems`, `industry`, `agents`, `meta`.
- CLI `evesde` (`load`, `update`, `verify`, `status`).
- `SDE.update_if_needed()` — полный цикл проверки версии, скачивания,
  атомарного обновления и верификации; колбэки `on_progress`/`on_complete`.
- Интеграционные тесты на PostgreSQL/MariaDB через `docker-compose.test.yml`
  и CI на GitHub Actions (lint, test-sqlite, test-dbms).

### Исправлено

- ETL искал дочерние таблицы вложенных массивов простой конкатинацией имён
  `<таблица>_<поле>`; для 7 таблиц, чьё полное имя превышает лимит длины
  идентификатора СУБД и усечено в эталонной схеме (например
  `dynamic_item_attributes_input_output_mapping_applicab_543eea` для
  `inputOutputMapping[].applicableTypes[]`), это не совпадало с реальным
  именем таблицы, и данные по этим полям молча терялись. `transform.py`
  теперь ищет такую таблицу по манифестной паре `(parent_table, array_path)`
  как fallback; `tools/gen_manifest.py` содержит явные исправления путей
  для этих 7 таблиц.
- `militaryCampaignObjectives.jsonl`: поле `contributionMethodConfiguration
  .parameters[].key` (простая строка, не идентификатор `_key`) переименовано
  в эталонной схеме в колонку `item_key` — ETL это не учитывал и терял
  значение; добавлено явное переименование колонки для этой таблицы.

### Изменено

- Эталонные SQL-файлы схемы и `SDE_schema_report.md` перенесены из корня
  репозитория в `reference/`.
- `TASKS.md` удалён: все 14 задач разработки выполнены, библиотека
  упакована и готова к релизу (см. `RELEASING.md`).
