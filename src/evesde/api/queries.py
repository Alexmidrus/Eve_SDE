"""Реализации запросов публичного API (см. `evesde.api.sde.SDE`, CLAUDE.md §7).

Читает в первую очередь витрины (dim_items/dim_universe/dim_agents/
type_common_stats/industry_*), raw-таблицы -- только для разрешения
имя-или-id вспомогательных сущностей (группа/категория/регион/корпорация/
dogma-атрибут), которых в витринах нет отдельным справочником. Все запросы
параметризованы через SQLAlchemy Core -- никакой конкатенации строк
пользовательского ввода в SQL.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from sqlalchemy import MetaData, Table, and_, func, select
from sqlalchemy.engine import Connection, Engine

from evesde.etl.source import get_local_build

#: Языки, поддерживаемые локализованными колонками (name_<lang> и т.п.).
SUPPORTED_LANGUAGES = ("de", "en", "es", "fr", "ja", "ko", "ru", "zh")


class SDENotFoundError(LookupError):
    """Ничего не найдено по указанному имени или id."""


class SDEAmbiguousNameError(LookupError):
    """Неоднозначное имя: несколько кандидатов подходят под запрос.

    Список кандидатов (id, имя) доступен в атрибуте `candidates`.
    """

    def __init__(self, value: str, candidates: list[tuple[int, str]]) -> None:
        """Сохраняет исходное имя и список кандидатов (id, имя)."""
        self.value = value
        self.candidates = candidates
        rendered = ", ".join(f"{name!r} (id={id_})" for id_, name in candidates)
        super().__init__(f"Неоднозначное имя {value!r}: {rendered}")


def _validate_lang(lang: str) -> None:
    if lang not in SUPPORTED_LANGUAGES:
        raise ValueError(f"Неподдерживаемый язык {lang!r}. Допустимо: {SUPPORTED_LANGUAGES}")


def _resolve_id(
    conn: Connection,
    table: Table,
    id_column: str,
    name_prefix: str,
    value: int | str,
    lang: str,
    *,
    what: str,
) -> int:
    """int -> id как есть (с проверкой существования); str -> точное совпадение
    по ``<name_prefix>_<lang>``, при отсутствии -- LIKE; несколько совпадений
    любого из двух шагов -> `SDEAmbiguousNameError`."""
    id_col = table.c[id_column]
    if isinstance(value, int):
        found = conn.execute(select(id_col).where(id_col == value)).first()
        if found is None:
            raise SDENotFoundError(f"{what} с id={value} не найден")
        return value

    name_col = table.c[f"{name_prefix}_{lang}"]
    candidates = conn.execute(select(id_col, name_col).where(name_col == value)).all()
    if not candidates:
        candidates = conn.execute(select(id_col, name_col).where(name_col.like(f"%{value}%"))).all()

    if len(candidates) == 1:
        return int(candidates[0][0])
    if not candidates:
        raise SDENotFoundError(f"{what} с именем {value!r} не найден (lang={lang!r})")
    raise SDEAmbiguousNameError(value, [(row[0], row[1]) for row in candidates])


# ---------------------------------------------------------------------------
# item() / items() / search()
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Item:
    """Предмет/корабль/модуль -- строка витрины `dim_items`."""

    type_id: int
    name: str | None
    description: str | None
    published: bool | None
    tech_level: int | None
    meta_level: int | None
    mass: float | None
    volume: float | None
    capacity: float | None
    radius: float | None
    base_price: float | None
    portion_size: int | None
    group_id: int | None
    group_name: str | None
    category_id: int | None
    category_name: str | None
    market_group_id: int | None
    market_group_name: str | None
    meta_group_id: int | None
    meta_group_name: str | None
    race_id: int | None
    race_name: str | None
    faction_id: int | None
    faction_name: str | None


def _row_to_item(row: Any, lang: str) -> Item:
    return Item(
        type_id=row["type_id"],
        name=row[f"type_name_{lang}"],
        description=row[f"type_description_{lang}"],
        published=row["published"],
        tech_level=row["tech_level"],
        meta_level=row["meta_level"],
        mass=row["mass"],
        volume=row["volume"],
        capacity=row["capacity"],
        radius=row["radius"],
        base_price=row["base_price"],
        portion_size=row["portion_size"],
        group_id=row["group_id"],
        group_name=row[f"group_name_{lang}"],
        category_id=row["category_id"],
        category_name=row[f"category_name_{lang}"],
        market_group_id=row["market_group_id"],
        market_group_name=row[f"market_group_name_{lang}"],
        meta_group_id=row["meta_group_id"],
        meta_group_name=row[f"meta_group_name_{lang}"],
        race_id=row["race_id"],
        race_name=row[f"race_name_{lang}"],
        faction_id=row["faction_id"],
        faction_name=row[f"faction_name_{lang}"],
    )


def item(engine: Engine, metadata: MetaData, name_or_id: int | str, *, lang: str) -> Item:
    """Реализация `SDE.item()` -- см. её докстринг за примером."""
    _validate_lang(lang)
    table = metadata.tables["dim_items"]
    with engine.connect() as conn:
        type_id = _resolve_id(conn, table, "type_id", "type_name", name_or_id, lang, what="предмет")
        row = conn.execute(select(table).where(table.c.type_id == type_id)).mappings().first()
    assert row is not None
    return _row_to_item(row, lang)


def items(
    engine: Engine,
    metadata: MetaData,
    *,
    group: int | str | None,
    category: int | str | None,
    market_group: int | str | None,
    published: bool | None,
    lang: str,
) -> list[Item]:
    """Реализация `SDE.items()` -- см. её докстринг за примером."""
    _validate_lang(lang)
    table = metadata.tables["dim_items"]
    with engine.connect() as conn:
        conditions = []
        if group is not None:
            gid = _resolve_id(
                conn, metadata.tables["item_groups"], "id", "name", group, lang, what="группа"
            )
            conditions.append(table.c.group_id == gid)
        if category is not None:
            cid = _resolve_id(
                conn, metadata.tables["categories"], "id", "name", category, lang, what="категория"
            )
            conditions.append(table.c.category_id == cid)
        if market_group is not None:
            mid = _resolve_id(
                conn,
                metadata.tables["market_groups"],
                "id",
                "name",
                market_group,
                lang,
                what="рыночная группа",
            )
            conditions.append(table.c.market_group_id == mid)
        if published is not None:
            conditions.append(table.c.published == published)

        stmt = select(table)
        if conditions:
            stmt = stmt.where(and_(*conditions))
        rows = conn.execute(stmt).mappings().all()
    return [_row_to_item(row, lang) for row in rows]


def search(engine: Engine, metadata: MetaData, name: str, *, lang: str, limit: int) -> list[Item]:
    """Реализация `SDE.search()` -- см. её докстринг за примером."""
    _validate_lang(lang)
    table = metadata.tables["dim_items"]
    name_col = table.c[f"type_name_{lang}"]
    stmt = select(table).where(name_col.like(f"%{name}%")).order_by(name_col).limit(limit)
    with engine.connect() as conn:
        rows = conn.execute(stmt).mappings().all()
    return [_row_to_item(row, lang) for row in rows]


# ---------------------------------------------------------------------------
# stats()
# ---------------------------------------------------------------------------

#: Колонки type_common_stats 1:1 с полями TypeStats (см. тест на согласованность).
_TYPE_STATS_FIELDS = (
    "type_id",
    "structure_hp",
    "armor_hp",
    "shield_capacity",
    "shield_recharge_time_ms",
    "structure_resist_em",
    "structure_resist_thermal",
    "structure_resist_kinetic",
    "structure_resist_explosive",
    "armor_resist_em",
    "armor_resist_thermal",
    "armor_resist_kinetic",
    "armor_resist_explosive",
    "shield_resist_em",
    "shield_resist_thermal",
    "shield_resist_kinetic",
    "shield_resist_explosive",
    "cpu_usage",
    "cpu_output",
    "powergrid_usage",
    "powergrid_output",
    "capacitor_capacity",
    "capacitor_recharge_time_ms",
    "capacitor_need",
    "max_locked_targets",
    "max_target_range",
    "scan_resolution",
    "signature_radius",
    "sensor_strength_radar",
    "sensor_strength_ladar",
    "sensor_strength_magnetometric",
    "sensor_strength_gravimetric",
    "max_velocity",
    "agility",
    "base_warp_speed",
    "high_slots",
    "mid_slots",
    "low_slots",
    "rig_slots",
    "launcher_hardpoints",
    "turret_hardpoints",
    "calibration",
    "rig_size",
    "drone_bay_capacity",
    "drone_bandwidth",
    "damage_multiplier",
    "optimal_range",
    "falloff",
    "tracking_speed",
    "rate_of_fire_ms",
    "activation_duration_ms",
    "em_damage",
    "explosive_damage",
    "kinetic_damage",
    "thermal_damage",
    "charge_size",
    "charge_group_1",
    "charge_group_2",
    "launcher_group",
    "required_skill_1_type_id",
    "required_skill_1_level",
    "required_skill_2_type_id",
    "required_skill_2_level",
    "required_skill_3_type_id",
    "required_skill_3_level",
    "skill_primary_attribute",
    "skill_secondary_attribute",
    "skill_time_constant",
)


@dataclass(frozen=True)
class TypeStats:
    """Характеристики предмета -- строка витрины `type_common_stats` (67 атрибутов)."""

    type_id: int
    structure_hp: float | None
    armor_hp: float | None
    shield_capacity: float | None
    shield_recharge_time_ms: float | None
    structure_resist_em: float | None
    structure_resist_thermal: float | None
    structure_resist_kinetic: float | None
    structure_resist_explosive: float | None
    armor_resist_em: float | None
    armor_resist_thermal: float | None
    armor_resist_kinetic: float | None
    armor_resist_explosive: float | None
    shield_resist_em: float | None
    shield_resist_thermal: float | None
    shield_resist_kinetic: float | None
    shield_resist_explosive: float | None
    cpu_usage: float | None
    cpu_output: float | None
    powergrid_usage: float | None
    powergrid_output: float | None
    capacitor_capacity: float | None
    capacitor_recharge_time_ms: float | None
    capacitor_need: float | None
    max_locked_targets: int | None
    max_target_range: float | None
    scan_resolution: float | None
    signature_radius: float | None
    sensor_strength_radar: float | None
    sensor_strength_ladar: float | None
    sensor_strength_magnetometric: float | None
    sensor_strength_gravimetric: float | None
    max_velocity: float | None
    agility: float | None
    base_warp_speed: float | None
    high_slots: int | None
    mid_slots: int | None
    low_slots: int | None
    rig_slots: int | None
    launcher_hardpoints: int | None
    turret_hardpoints: int | None
    calibration: float | None
    rig_size: float | None
    drone_bay_capacity: float | None
    drone_bandwidth: float | None
    damage_multiplier: float | None
    optimal_range: float | None
    falloff: float | None
    tracking_speed: float | None
    rate_of_fire_ms: float | None
    activation_duration_ms: float | None
    em_damage: float | None
    explosive_damage: float | None
    kinetic_damage: float | None
    thermal_damage: float | None
    charge_size: int | None
    charge_group_1: int | None
    charge_group_2: int | None
    launcher_group: int | None
    required_skill_1_type_id: int | None
    required_skill_1_level: int | None
    required_skill_2_type_id: int | None
    required_skill_2_level: int | None
    required_skill_3_type_id: int | None
    required_skill_3_level: int | None
    skill_primary_attribute: int | None
    skill_secondary_attribute: int | None
    skill_time_constant: float | None


def stats(
    engine: Engine, metadata: MetaData, type_id_or_name: int | str, *, lang: str
) -> TypeStats:
    """Реализация `SDE.stats()` -- см. её докстринг за примером."""
    _validate_lang(lang)
    dim_items = metadata.tables["dim_items"]
    table = metadata.tables["type_common_stats"]
    with engine.connect() as conn:
        type_id = _resolve_id(
            conn, dim_items, "type_id", "type_name", type_id_or_name, lang, what="предмет"
        )
        row = conn.execute(select(table).where(table.c.type_id == type_id)).mappings().first()
    if row is None:
        raise SDENotFoundError(f"У предмета с id={type_id} нет характеристик (type_common_stats)")
    return TypeStats(**{field: row[field] for field in _TYPE_STATS_FIELDS})


# ---------------------------------------------------------------------------
# dogma()
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class DogmaAttribute:
    """Одно значение dogma-атрибута предмета (полный EAV, `type_dogma_dogma_attributes`)."""

    attribute_id: int
    name: str | None
    display_name: str | None
    value: float


def dogma(
    engine: Engine, metadata: MetaData, type_id_or_name: int | str, *, lang: str
) -> list[DogmaAttribute]:
    """Реализация `SDE.dogma()` -- см. её докстринг за примером."""
    _validate_lang(lang)
    dim_items = metadata.tables["dim_items"]
    type_dogma = metadata.tables["type_dogma"]
    attrs = metadata.tables["type_dogma_dogma_attributes"]
    dogma_attributes = metadata.tables["dogma_attributes"]
    display_col = dogma_attributes.c[f"display_name_{lang}"]

    with engine.connect() as conn:
        type_id = _resolve_id(
            conn, dim_items, "type_id", "type_name", type_id_or_name, lang, what="предмет"
        )
        stmt = (
            select(attrs.c.attribute_id, dogma_attributes.c.name, display_col, attrs.c.value)
            .select_from(
                attrs.join(type_dogma, attrs.c.type_dogma_id == type_dogma.c.id).outerjoin(
                    dogma_attributes, attrs.c.attribute_id == dogma_attributes.c.id
                )
            )
            .where(type_dogma.c.id == type_id)
            .order_by(attrs.c.seq)
        )
        rows = conn.execute(stmt).all()
    return [
        DogmaAttribute(attribute_id=r[0], name=r[1], display_name=r[2], value=r[3]) for r in rows
    ]


# ---------------------------------------------------------------------------
# system() / systems()
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class SolarSystem:
    """Звёздная система -- строка витрины `dim_universe` (система+созвездие+регион)."""

    solar_system_id: int
    name: str | None
    security_status: float | None
    security_class: str | None
    constellation_id: int | None
    constellation_name: str | None
    region_id: int | None
    region_name: str | None
    faction_id: int | None
    faction_name: str | None


def _row_to_system(row: Any, lang: str) -> SolarSystem:
    return SolarSystem(
        solar_system_id=row["solar_system_id"],
        name=row[f"solar_system_name_{lang}"],
        security_status=row["security_status"],
        security_class=row["security_class"],
        constellation_id=row["constellation_id"],
        constellation_name=row[f"constellation_name_{lang}"],
        region_id=row["region_id"],
        region_name=row[f"region_name_{lang}"],
        faction_id=row["faction_id"],
        faction_name=row[f"faction_name_{lang}"],
    )


def system(engine: Engine, metadata: MetaData, name_or_id: int | str, *, lang: str) -> SolarSystem:
    """Реализация `SDE.system()` -- см. её докстринг за примером."""
    _validate_lang(lang)
    table = metadata.tables["dim_universe"]
    with engine.connect() as conn:
        sid = _resolve_id(
            conn, table, "solar_system_id", "solar_system_name", name_or_id, lang, what="система"
        )
        row = conn.execute(select(table).where(table.c.solar_system_id == sid)).mappings().first()
    assert row is not None
    return _row_to_system(row, lang)


def systems(
    engine: Engine,
    metadata: MetaData,
    *,
    region: int | str | None,
    min_security: float | None,
    max_security: float | None,
    lang: str,
) -> list[SolarSystem]:
    """Реализация `SDE.systems()` -- см. её докстринг за примером."""
    _validate_lang(lang)
    table = metadata.tables["dim_universe"]
    with engine.connect() as conn:
        conditions = []
        if region is not None:
            rid = _resolve_id(
                conn, metadata.tables["map_regions"], "id", "name", region, lang, what="регион"
            )
            conditions.append(table.c.region_id == rid)
        if min_security is not None:
            conditions.append(table.c.security_status >= min_security)
        if max_security is not None:
            conditions.append(table.c.security_status <= max_security)

        stmt = select(table)
        if conditions:
            stmt = stmt.where(and_(*conditions))
        rows = conn.execute(stmt).mappings().all()
    return [_row_to_system(row, lang) for row in rows]


# ---------------------------------------------------------------------------
# industry()
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class IndustryMaterial:
    """Один материал, необходимый для производственной активности."""

    type_id: int
    name: str | None
    quantity: int | None


@dataclass(frozen=True)
class IndustryProduct:
    """Один продукт производственной активности (``probability`` -- только для invention)."""

    type_id: int
    name: str | None
    quantity: int | None
    probability: float | None


@dataclass(frozen=True)
class IndustrySkill:
    """Один требуемый скилл производственной активности (level -- нужный уровень)."""

    type_id: int
    name: str | None
    level: int | None


@dataclass(frozen=True)
class IndustryRecipe:
    """Один вид производственной активности чертежа (materials/products/skills)."""

    blueprint_id: int
    blueprint_name: str | None
    activity_type: str
    activity_time: int | None
    materials: tuple[IndustryMaterial, ...]
    products: tuple[IndustryProduct, ...]
    skills: tuple[IndustrySkill, ...]


def _industry_materials(
    conn: Connection, metadata: MetaData, blueprint_id: int, activity_type: str, lang: str
) -> tuple[IndustryMaterial, ...]:
    table = metadata.tables["industry_materials"]
    dim_items = metadata.tables["dim_items"]
    name_col = dim_items.c[f"type_name_{lang}"]
    stmt = (
        select(table.c.type_id, name_col, table.c.quantity)
        .select_from(table.outerjoin(dim_items, table.c.type_id == dim_items.c.type_id))
        .where(table.c.blueprint_id == blueprint_id, table.c.activity_type == activity_type)
        .order_by(table.c.seq)
    )
    return tuple(
        IndustryMaterial(type_id=r[0], name=r[1], quantity=r[2]) for r in conn.execute(stmt).all()
    )


def _industry_products(
    conn: Connection, metadata: MetaData, blueprint_id: int, activity_type: str, lang: str
) -> tuple[IndustryProduct, ...]:
    table = metadata.tables["industry_products"]
    dim_items = metadata.tables["dim_items"]
    name_col = dim_items.c[f"type_name_{lang}"]
    stmt = (
        select(table.c.type_id, name_col, table.c.quantity, table.c.probability)
        .select_from(table.outerjoin(dim_items, table.c.type_id == dim_items.c.type_id))
        .where(table.c.blueprint_id == blueprint_id, table.c.activity_type == activity_type)
        .order_by(table.c.seq)
    )
    return tuple(
        IndustryProduct(type_id=r[0], name=r[1], quantity=r[2], probability=r[3])
        for r in conn.execute(stmt).all()
    )


def _industry_skills(
    conn: Connection, metadata: MetaData, blueprint_id: int, activity_type: str, lang: str
) -> tuple[IndustrySkill, ...]:
    table = metadata.tables["industry_skills"]
    dim_items = metadata.tables["dim_items"]
    name_col = dim_items.c[f"type_name_{lang}"]
    stmt = (
        select(table.c.type_id, name_col, table.c.level)
        .select_from(table.outerjoin(dim_items, table.c.type_id == dim_items.c.type_id))
        .where(table.c.blueprint_id == blueprint_id, table.c.activity_type == activity_type)
        .order_by(table.c.seq)
    )
    return tuple(
        IndustrySkill(type_id=r[0], name=r[1], level=r[2]) for r in conn.execute(stmt).all()
    )


def industry(
    engine: Engine,
    metadata: MetaData,
    *,
    blueprint: int | str | None,
    product: int | str | None,
    activity: str | None,
    lang: str,
) -> list[IndustryRecipe]:
    """Реализация `SDE.industry()` -- см. её докстринг за примером."""
    _validate_lang(lang)
    if blueprint is None and product is None:
        raise ValueError("industry(): нужно указать blueprint или product")

    dim_items = metadata.tables["dim_items"]
    activities = metadata.tables["industry_activities"]
    products_table = metadata.tables["industry_products"]

    with engine.connect() as conn:
        if blueprint is not None:
            blueprint_ids = [
                _resolve_id(conn, dim_items, "type_id", "type_name", blueprint, lang, what="чертёж")
            ]
        else:
            assert product is not None  # гарантировано проверкой выше (blueprint is None)
            product_type_id = _resolve_id(
                conn, dim_items, "type_id", "type_name", product, lang, what="продукт"
            )
            stmt = (
                select(products_table.c.blueprint_id)
                .where(products_table.c.type_id == product_type_id)
                .distinct()
            )
            if activity is not None:
                stmt = stmt.where(products_table.c.activity_type == activity)
            blueprint_ids = [row[0] for row in conn.execute(stmt).all()]
            if not blueprint_ids:
                return []

        stmt = select(activities).where(activities.c.blueprint_id.in_(blueprint_ids))
        if activity is not None:
            stmt = stmt.where(activities.c.activity_type == activity)
        activity_rows = conn.execute(stmt).mappings().all()

        name_col = dim_items.c[f"type_name_{lang}"]
        blueprint_names: dict[int, str | None] = {
            row[0]: row[1]
            for row in conn.execute(
                select(dim_items.c.type_id, name_col).where(dim_items.c.type_id.in_(blueprint_ids))
            ).all()
        }

        recipes: list[IndustryRecipe] = []
        for arow in activity_rows:
            bp_id = arow["blueprint_id"]
            act = arow["activity_type"]
            recipes.append(
                IndustryRecipe(
                    blueprint_id=bp_id,
                    blueprint_name=blueprint_names.get(bp_id),
                    activity_type=act,
                    activity_time=arow["activity_time"],
                    materials=_industry_materials(conn, metadata, bp_id, act, lang),
                    products=_industry_products(conn, metadata, bp_id, act, lang),
                    skills=_industry_skills(conn, metadata, bp_id, act, lang),
                )
            )
    return recipes


# ---------------------------------------------------------------------------
# agents()
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Agent:
    """Агент NPC -- строка витрины `dim_agents` (полный контекст: корп/раса/локация)."""

    agent_id: int
    name: str | None
    level: int | None
    is_locator: bool | None
    agent_type_id: int | None
    agent_type_name: str | None
    division_id: int | None
    division_name: str | None
    corporation_id: int | None
    corporation_name: str | None
    corporation_ticker: str | None
    faction_id: int | None
    faction_name: str | None
    solar_system_id: int | None
    solar_system_name: str | None
    region_id: int | None
    region_name: str | None
    security_status: float | None


def _row_to_agent(row: Any, lang: str) -> Agent:
    return Agent(
        agent_id=row["agent_id"],
        name=row[f"agent_name_{lang}"],
        level=row["agent_level"],
        is_locator=row["agent_is_locator"],
        agent_type_id=row["agent_type_id"],
        agent_type_name=row["agent_type_name"],
        division_id=row["division_id"],
        division_name=row[f"division_name_{lang}"],
        corporation_id=row["corporation_id"],
        corporation_name=row[f"corporation_name_{lang}"],
        corporation_ticker=row["corporation_ticker"],
        faction_id=row["faction_id"],
        faction_name=row[f"faction_name_{lang}"],
        solar_system_id=row["solar_system_id"],
        solar_system_name=row[f"solar_system_name_{lang}"],
        region_id=row["region_id"],
        region_name=row[f"region_name_{lang}"],
        security_status=row["security_status"],
    )


def agents(
    engine: Engine,
    metadata: MetaData,
    *,
    level: int | None,
    region: int | str | None,
    is_locator: bool | None,
    corporation: int | str | None,
    lang: str,
) -> list[Agent]:
    """Реализация `SDE.agents()` -- см. её докстринг за примером."""
    _validate_lang(lang)
    table = metadata.tables["dim_agents"]
    with engine.connect() as conn:
        conditions = []
        if level is not None:
            conditions.append(table.c.agent_level == level)
        if region is not None:
            rid = _resolve_id(
                conn, metadata.tables["map_regions"], "id", "name", region, lang, what="регион"
            )
            conditions.append(table.c.region_id == rid)
        if is_locator is not None:
            conditions.append(table.c.agent_is_locator == is_locator)
        if corporation is not None:
            cid = _resolve_id(
                conn,
                metadata.tables["npc_corporations"],
                "id",
                "name",
                corporation,
                lang,
                what="корпорация",
            )
            conditions.append(table.c.corporation_id == cid)

        stmt = select(table)
        if conditions:
            stmt = stmt.where(and_(*conditions))
        rows = conn.execute(stmt).mappings().all()
    return [_row_to_agent(row, lang) for row in rows]


# ---------------------------------------------------------------------------
# meta()
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class Meta:
    """Сводка о загруженном SDE: версия и объём данных в витринах."""

    build_number: int | None
    release_date: str | None
    item_count: int
    system_count: int
    agent_count: int


def meta(engine: Engine, metadata: MetaData) -> Meta:
    """Реализация `SDE.meta()` -- см. её докстринг за примером."""
    build_info = get_local_build(engine)
    with engine.connect() as conn:
        item_count = conn.execute(
            select(func.count()).select_from(metadata.tables["dim_items"])
        ).scalar_one()
        system_count = conn.execute(
            select(func.count()).select_from(metadata.tables["dim_universe"])
        ).scalar_one()
        agent_count = conn.execute(
            select(func.count()).select_from(metadata.tables["dim_agents"])
        ).scalar_one()
    return Meta(
        build_number=build_info.build_number if build_info else None,
        release_date=build_info.release_date if build_info else None,
        item_count=item_count,
        system_count=system_count,
        agent_count=agent_count,
    )
