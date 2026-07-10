# evesde

Библиотека для работы со статическими данными EVE Online (SDE): загрузка
официального JSONL-дампа CCP в SQLite/PostgreSQL/MySQL/MariaDB и лаконичный
API для чтения игровых данных (~10 методов с богатыми параметрами вместо
десятков узких).

## English

`evesde` is a Python library for working with EVE Online's Static Data
Export (SDE): it loads CCP's official JSONL dump into SQLite/PostgreSQL/
MySQL/MariaDB and exposes a small, richly-parameterized query API (~10
methods) instead of dozens of narrow ones. Install with
`pip install evesde` (add `[postgres]`/`[mysql]` extras for those drivers),
then:

```python
from evesde import SDE

sde = SDE("sqlite:///eve.db")
sde.update_if_needed()          # downloads and loads SDE on first run
ship = sde.item("Rifter")       # by name or type_id, any of the 8 SDE languages
```

The rest of this README is in Russian; see the docstrings on `evesde.SDE`
for full per-method reference in English.

## Установка

```bash
pip install evesde
# с драйвером для конкретной СУБД:
pip install "evesde[postgres]"
pip install "evesde[mysql]"
```

## Быстрый старт

```python
from evesde import SDE

sde = SDE("sqlite:///eve.db")
sde.update_if_needed()          # скачает и загрузит SDE при первом запуске

ship = sde.item("Rifter")       # по имени или type_id, любой из 8 языков SDE
print(ship.name, ship.group_name, ship.category_name)
```

Если SDE уже загружен локальным каталогом (например, командой `evesde load`),
`update_if_needed()` можно не вызывать каждый раз — она сама проверяет версию
у CCP и ничего не делает, если данные уже актуальны.

## Публичный API

Все методы — на объекте `SDE`; принимают `lang="en"` (любой из 8 языков SDE:
`de/en/es/fr/ja/ko/ru/zh`) и возвращают лёгкие frozen dataclass'ы. Разрешение
"имя или id" единообразно: `int` — это `id`, `str` ищется точным совпадением
по локализованному имени, затем по подстроке; неоднозначность бросает
`SDEAmbiguousNameError` (со списком кандидатов в `.candidates`), отсутствие —
`SDENotFoundError`. Всё, что не покрыто API, доступно через `sde.engine`
(SQLAlchemy Core).

| Метод | Параметры | Возвращает | Пример |
|---|---|---|---|
| `item` | `name_or_id`, `lang` | `Item` | `sde.item("Rifter")` |
| `items` | `group`, `category`, `market_group`, `published`, `lang` | `list[Item]` | `sde.items(category="Ship", published=True)` |
| `search` | `name`, `lang`, `limit` | `list[Item]` | `sde.search("Rift")` |
| `stats` | `type_id_or_name`, `lang` | `TypeStats` | `sde.stats("Rifter").high_slots` |
| `dogma` | `type_id_or_name`, `lang` | `list[DogmaAttribute]` | `sde.dogma("Rifter")` |
| `system` | `name_or_id`, `lang` | `SolarSystem` | `sde.system("Jita").region_name` |
| `systems` | `region`, `min_security`, `max_security`, `lang` | `list[SolarSystem]` | `sde.systems(region="The Forge", min_security=0.5)` |
| `industry` | `blueprint` или `product`, `activity`, `lang` | `list[IndustryRecipe]` | `sde.industry(product="Rifter", activity="manufacturing")` |
| `agents` | `level`, `region`, `is_locator`, `corporation`, `lang` | `list[Agent]` | `sde.agents(level=4, region="The Forge", is_locator=True)` |
| `meta` | — | `Meta` | `sde.meta().build_number` |
| `update_if_needed` | `force`, `on_progress`, `on_complete` | `UpdateResult` | `sde.update_if_needed()` |

`industry()` нужен `blueprint` (сам чертёж) либо `product` (что он
производит); без `activity` возвращаются рецепты всех активностей чертежа
(`manufacturing`, `copying`, `invention`, `reaction`, `research_material`,
`research_time`), с `activity` — только она.

## Команды CLI

```bash
evesde --db sqlite:///eve.db load ./sde_dump   # загрузить из локального каталога
evesde --db sqlite:///eve.db load --download   # скачать и загрузить
evesde --db sqlite:///eve.db update             # обновить, если вышел новый build
evesde --db sqlite:///eve.db verify              # проверить целостность
evesde --db sqlite:///eve.db status              # версия, число таблиц/строк, размер БД
```

Вместо `--db <url>` можно задать переменную окружения `EVESDE_DB`. Коды
возврата: `0` — успех, `1` — ошибка выполнения, `2` — `verify` нашёл ошибки
(предупреждения код возврата не меняют).

## Расписание обновлений

Библиотека не содержит встроенного планировщика: `SDE.update_if_needed()`
(сверяет версию у CCP и, если вышел новый build, атомарно перезагружает БД)
и `evesde update` (то же самое из CLI) — это просто функции, которые ваше
приложение вызывает по расписанию любым удобным способом.

### cron + CLI

```bash
# каждый день в 04:00 проверить версию у CCP и обновить БД при необходимости
0 4 * * * EVESDE_DB=sqlite:////srv/app/eve.db evesde update >> /var/log/evesde-update.log 2>&1
```

### APScheduler

```python
from apscheduler.schedulers.blocking import BlockingScheduler

from evesde import SDE

sde = SDE("sqlite:///eve.db")
scheduler = BlockingScheduler()


@scheduler.scheduled_job("interval", hours=6)
def update_sde() -> None:
    result = sde.update_if_needed(on_progress=print)
    if result.updated:
        print(f"SDE обновлён до build {result.new_build.build_number}")


scheduler.start()
```

### Celery beat

```python
from celery import Celery

from evesde import SDE

app = Celery("myapp", broker="redis://localhost:6379/0")
sde = SDE("sqlite:///eve.db")


@app.task
def update_sde() -> None:
    sde.update_if_needed()


app.conf.beat_schedule = {
    "update-sde-every-6-hours": {
        "task": "myapp.tasks.update_sde",
        "schedule": 6 * 60 * 60,
    },
}
```

## Схема данных

Три слоя (полный список из 182 таблиц, колонки и связи — см.
`reference/SDE_schema_report.md`):

1. **raw-слой** (174 таблицы) — 1 исходный `.jsonl`-файл = 1 корневая
   таблица + дочерние таблицы для вложенных массивов, без потерь и
   нормализации справочников.
2. **Витрины** (8 таблиц: `dim_items`, `dim_universe`, `dim_agents`,
   `type_common_stats`, `industry_activities/materials/products/skills`) —
   денормализованные таблицы поверх raw-слоя, физически материализуются
   заново после каждой загрузки (`INSERT ... SELECT`, не VIEW).
3. Публичный API читает в первую очередь витрины; raw-слой — для редких
   полей и произвольных запросов через `sde.engine`.

## Ограничения и особенности данных

- `types.faction_id` — смешанная ссылка: часть значений (~10 из 33) на
  самом деле ID NPC-корпораций, а не фракций. `dim_items.faction_name`
  в этих случаях будет `None` — это ожидаемое поведение, а не баг.
- `agents_in_space.dungeon_id` не совпадает с `dungeons._key` — внешний
  ключ на эту колонку сознательно не строится.
- Не у каждого предмета есть dogma-атрибуты (`typeDogma` заполнена не для
  всех типов): `stats()` бросает `SDENotFoundError`, если характеристик
  нет, `dogma()` в этом случае просто возвращает пустой список.
- Значения dogma-атрибутов в исходном SDE всегда `FLOAT`; там, где смысл
  атрибута целочисленный (слоты, уровни скиллов), `type_common_stats`
  приводит их к `INTEGER` (например, `stats(...).high_slots`).

## Как запускать тесты

Быстрый набор (SQLite in-memory, всегда) не требует ничего, кроме
dev-зависимостей:

```bash
pip install -e ".[dev]"
pytest                    # включает dbms-тесты, только если СУБД доступна
pytest -m "not dbms"      # явно только быстрый набор
```

Интеграционные тесты на реальных PostgreSQL и MariaDB (маркер `dbms`)
поднимаются через `docker-compose.test.yml`:

```bash
docker compose -f docker-compose.test.yml up -d
pip install -e ".[dev,postgres,mysql]"

export EVESDE_TEST_POSTGRES_URL="postgresql+psycopg://evesde:evesde@localhost:5432/evesde_test"
export EVESDE_TEST_MYSQL_URL="mysql+pymysql://evesde:evesde@localhost:3306/evesde_test"
pytest -m dbms

docker compose -f docker-compose.test.yml down -v
```

Без этих переменных (или если СУБД недоступна) `dbms`-тесты аккуратно
пропускаются (skip), а не падают -- обычный `pytest` без docker всегда
зелёный. В CI (`.github/workflows/ci.yml`) есть отдельные джобы `lint`
(ruff + mypy), `test-sqlite` (матрица версий Python) и `test-dbms`
(PostgreSQL + MariaDB как сервисы).
