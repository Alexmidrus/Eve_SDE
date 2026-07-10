# CLAUDE.md — инструкции для кодирующей модели (Claude Sonnet)

Ты пишешь и сопровождаешь код Python-библиотеки **evesde** для работы со статическими данными EVE Online (SDE, формат JSONL). Первоначальная разработка (см. §9 «Что уже сделано») завершена — сейчас работа состоит из багфиксов, доработок и поддержки; перед любой задачей перечитай этот файл.

---

## 1. Цель библиотеки

Пользователь (разработчик приложений/ботов для EVE Online):

1. Устанавливает библиотеку в своё приложение: `pip install evesde`.
2. Подключает её, указывая **СУБД** (SQLite, MySQL/MariaDB, PostgreSQL) и **имя/адрес базы данных**.
3. Получает набор команд для **загрузки и проверки SDE**, которые он настраивает в своём приложении, включая расписание обновления (библиотека даёт механизм «проверить и обновить», планировщик — на стороне пользователя).
4. После загрузки получает **лаконичный API извлечения данных**: не 50–60 узких команд, а ~10 команд с параметрами.

Пример целевого использования (ориентир, не догма):

```python
from evesde import SDE

sde = SDE("sqlite:///eve.db")          # или "postgresql://...", "mysql://..."
sde.update_if_needed()                  # скачать и загрузить новый build, если вышел

ship = sde.item("Rifter")               # по имени или type_id, любой язык
stats = sde.stats(ship.type_id)         # характеристики из type_common_stats
mats = sde.industry(product="Rifter", activity="manufacturing")
jita = sde.system("Jita")               # система + созвездие + регион + сек-статус
agents = sde.agents(level=4, region="The Forge", is_locator=True)
```

## 2. Архитектура (зафиксирована, не менять без явного запроса)

Три слоя, пайплайн: **JSONL → raw-слой → витрины**.

1. **Raw-слой** — 174 таблицы, 1 исходный `.jsonl` файл = 1 корневая таблица + дочерние таблицы для вложенных массивов. Полное соответствие исходным данным, ничего не теряется.
2. **Витрины (оптимизированный слой)** — 8 таблиц, строятся `INSERT ... SELECT` из raw: `dim_items`, `dim_universe`, `dim_agents`, `type_common_stats` (пивот 67 dogma-атрибутов), `industry_activities/materials/products/skills`.
3. **Публичный API** читает в первую очередь витрины, raw — для редких данных.

Эталон структуры — SQL-файлы в `reference/` (`eve_sde_full_schema.sql` = `eve_sde_schema.sql` + `eve_sde_optimized.sql`). Они уже проверены и исправлены (см. CHANGELOG в шапке файлов). **Источником истины для кода является манифест** `schema/manifest.json`, генерируемый из этих SQL (задача T02): из манифеста строятся и DDL, и ETL — чтобы они не могли разойтись.

## 3. Конвенции схемы (обязательны в ETL)

| Исходный JSON | В базе |
|---|---|
| `_key` записи | колонка `id` (PK корневой таблицы) |
| `camelCase` | `snake_case` |
| вложенный объект `position: {x,y,z}` | flatten: `position_x`, `position_y`, `position_z` |
| локализованный объект `name: {de,en,es,fr,ja,ko,ru,zh}` | 8 колонок `name_de` … `name_zh` |
| вложенный массив | дочерняя таблица `<родитель>_<поле>` с PK `(родитель_id, seq)`, `seq` — позиция в массиве, 0-based |
| массив скаляров | дочерняя таблица с колонкой `value` |
| dict с ключами-идентификаторами | колонка `source_key` |

**Суррогатные PK.** 9 промежуточных таблиц (у которых есть собственные дочерние таблицы: `epic_arcs_missions`, `masteries_value`, `type_bonus_types`, `freelance_job_schemas_value`, `freelance_job_schemas_value_parameters`, `dynamic_item_attributes_input_output_mapping`, `military_campaign_objectives_contribution_method_conf_*`, `ship_tree_groups_pre_req_skills`) имеют колонку `id INTEGER PRIMARY KEY`, которую **присваивает ETL** (сквозная нумерация строк при загрузке); натуральный ключ `(parent_id, seq)` сохранён как UNIQUE. Дочерние таблицы ссылаются на этот `id`.

**Известные ловушки данных** (подтверждены сверкой):
- `types.faction_id` — смешанная ссылка: 10 из 33 значений на самом деле ID NPC-корпораций (диапазон 1000xxx), а не фракций. LEFT JOIN на factions даёт NULL-имена — это ожидаемо.
- `agents_in_space.dungeon_id` не совпадает с `dungeons._key` — FK не ставить.
- `type_dogma.id == types.id`, но typeDogma есть не для всех типов.
- Значения dogma-атрибутов всегда FLOAT; там, где смысл целочисленный (слоты, уровни), витрина приводит к INTEGER.

## 4. Технологический стек (зафиксирован)

- **Python ≥ 3.10**, типизация обязательна (mypy-чистый код).
- **SQLAlchemy 2.x Core** (НЕ ORM) — единственная абстракция над тремя СУБД: DDL из `MetaData.create_all()`, диалектные различия (AUTO_INCREMENT/SERIAL, TEXT-типы, кавычки) закрывает SQLAlchemy. FK объявлять **внутри** Table (inline) — тогда работает и SQLite, где `ALTER TABLE ADD CONSTRAINT` не поддерживается.
- Драйверы — extras: `evesde[postgres]` → psycopg, `evesde[mysql]` → pymysql; SQLite из stdlib.
- **CLI** — `click`, тонкая обёртка над Python-API (API первичен).
- Никакого встроенного планировщика: только `update_if_needed()` / `check_remote_build()`; расписание пользователь делает своим cron/APScheduler/Celery. В README — примеры подключения.
- Из зависимостей только: sqlalchemy, click, httpx (скачивание SDE). Каждая новая зависимость — только по явной необходимости с обоснованием в PR-описании.

## 5. Правила ETL

- Источник: официальный JSONL-дамп SDE CCP (URL конфигурируем, по умолчанию — официальный endpoint CCP developers; актуальность проверять по `_sde.jsonl`: `buildNumber`, `releaseDate`).
- Файлы большие (types.jsonl ~144 МБ, mapMoons.jsonl ~214 МБ, ~640 тыс. строк в type_dogma_dogma_attributes) — **потоковое чтение построчно**, никаких `json.load()` целого файла.
- Вставка батчами `executemany` по 5 000–10 000 строк, транзакция на файл.
- **Индексы создавать после загрузки данных**, не до.
- Обновление должно быть атомарным для читателей: SQLite — собрать новый файл БД и подменить; MySQL/PostgreSQL — загрузка во временные таблицы/схему + переименование, либо одна транзакция (PostgreSQL).
- После загрузки — автоматическая верификация: количество строк = количеству строк JSONL, отсутствие FK-сирот, отчёт по buildNumber.
- Порядок загрузки raw-таблиц не важен, если FK создаются после (или проверяются верификацией); при inline-FK в SQLite использовать `PRAGMA foreign_keys=OFF` на время загрузки.

## 6. Структура проекта

```
evesde/
  pyproject.toml
  reference/             # эталонные SQL + отчёт по структуре JSONL (не редактировать)
    eve_sde_full_schema.sql
    eve_sde_schema.sql
    eve_sde_optimized.sql
    SDE_schema_report.md
  src/evesde/
    __init__.py          # экспорт SDE
    config.py            # конфигурация подключения
    schema/
      manifest.json      # источник истины (генерируется T02)
      builder.py         # manifest -> SQLAlchemy MetaData
    etl/
      transform.py       # чистые функции JSON -> строки таблиц
      loader.py          # батч-загрузка
      source.py          # скачивание/распаковка SDE, проверка build
      marts.py           # построение витрин (SQL-шаблоны из optimized-слоя)
      verify.py          # проверки целостности
    api/
      sde.py             # класс SDE — публичный фасад
      queries.py         # реализации запросов
    cli.py               # click-команды: load, update, verify, status
  tools/
    gen_manifest.py      # парсер reference/eve_sde_full_schema.sql -> manifest.json
  tests/
    fixtures/            # мини-JSONL (по 5-20 строк на файл)
    unit/  integration/
```

## 7. Публичный API — принципы

Мало команд, богатые параметры. Ориентир (~10 методов): `item()`, `items()` (фильтры: группа/категория/маркет-группа/published), `search()` (по имени, `lang=`), `stats()`, `dogma()` (полный EAV по типу), `system()`, `systems()` (фильтры: регион, сек-статус), `industry()` (blueprint/product/activity, материалы/продукты/скиллы), `agents()`, `meta()` (buildNumber, дата, статистика загрузки). Возвращать легковесные dataclass/NamedTuple, не сырые Row. Параметр `lang="en"` по умолчанию, принимает любой из 8 языков. Всё, что не покрыто API, доступно через `sde.engine` (SQLAlchemy) — экранирование не прятать.

## 8. Стандарты кода и тестов

- ruff (lint+format), mypy strict для `src/`. Докстринги на русском, идентификаторы на английском.
- pytest. Юнит-тесты трансформаций — обязательны для каждой конвенции из §3 (включая суррогатные PK и ловушки данных). Интеграционные: SQLite in-memory — всегда; MySQL и PostgreSQL — через docker-compose, помечены маркером `@pytest.mark.dbms`.
- Тестовые данные — только мини-фикстуры в `tests/fixtures/`, реальные JSONL из этого каталога в тесты не тащить.
- Каждая задача завершается: код + тесты зелёные + краткое резюме изменений (при заметных изменениях в поведении — запись в `CHANGELOG.md`). Не начинай следующую задачу без команды пользователя.
- Не редактируй исходные `.jsonl` и эталонные `.sql` файлы. Не переименовывай публичные методы после того, как они появились в README.

## 9. Что уже сделано (не переделывать)

- Схема raw-слоя и витрин спроектирована и проверена: `reference/eve_sde_full_schema.sql` (850 стейтментов, 182 таблицы, 252 индекса, 307 FK) — прогнана через SQLite, ссылочная целостность выверена.
- Отчёт по структуре всех 79 JSONL-файлов: `reference/SDE_schema_report.md` (типы полей, подтверждённые FK, ловушки).
- Библиотека полностью реализована и упакована (0.1.0): каркас пакета, генератор манифеста, DDL-строитель, ETL (transform/loader/source/marts/verify), публичный API, CLI, интеграционные тесты MySQL/PostgreSQL и CI, README, `RELEASING.md`.
