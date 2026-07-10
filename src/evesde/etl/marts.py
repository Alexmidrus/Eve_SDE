"""Построение оптимизированного слоя (8 витрин) из raw-слоя (CLAUDE.md §2, §7).

DELETE+INSERT SQL взят ДОСЛОВНО из ЧАСТИ II ``eve_sde_full_schema.sql``
(уже спроектирован, отревьюжен и прогнан на SQLite, см. CLAUDE.md §9) и
хранится здесь текстовыми шаблонами, а не собирается SQLAlchemy Core
выражениями. Причины такого выбора:

1. Это фиксированные статические трансформации, не строящиеся динамически
   по пользовательскому вводу -- параметризация Core не даёт практической
   выгоды, а пересборка через `select()/case()/cast()` рискует незаметно
   разойтись с уже проверенным текстом (особенно 67-колоночный CASE WHEN
   пивот `type_common_stats` и 6-way `UNION ALL` в `industry_*`).
2. Автор схемы уже ограничил синтаксис ANSI-подмножеством, работающим на
   всех трёх целевых СУБД (`CAST`, `COALESCE`, `LEFT JOIN`, агрегатный
   `CASE WHEN` вместо диалект-специфичного `PIVOT`/`CROSSTAB`) -- см. шапку
   `eve_sde_full_schema.sql`, раздел "Совместимость". SQLAlchemy Core здесь
   откомпилировал бы в ту же самую SQL, только с лишним слоем риска.
3. Пользовательских параметров нет вообще -- вопрос SQL-инъекций не встаёт.

Каждая из 8 таблиц (`dim_items`, `dim_universe`, `type_common_stats`,
`industry_activities/materials/products/skills`, `dim_agents`) заполняется
DELETE + INSERT в ОДНОЙ транзакции НА ВИТРИНУ (не все 8 разом) -- сбой
одной витрины не портит остальные и не оставляет её наполовину заполненной.
Повторный вызов идемпотентен (DELETE перед INSERT).
"""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.engine import Connection, Engine

_DELETE_DIM_ITEMS = "DELETE FROM dim_items"
_INSERT_DIM_ITEMS = """
INSERT INTO dim_items (
    type_id, type_name_de, type_name_en, type_name_es, type_name_fr, type_name_ja, type_name_ko,
    type_name_ru, type_name_zh, type_description_de, type_description_en, type_description_es,
    type_description_fr, type_description_ja, type_description_ko, type_description_ru,
    type_description_zh, published, tech_level, meta_level, mass, volume, capacity, radius,
    base_price, portion_size, icon_id, graphic_id, sound_id, variation_parent_type_id,
    ship_tree_group_id, group_id, group_name_de, group_name_en, group_name_es, group_name_fr,
    group_name_ja, group_name_ko, group_name_ru, group_name_zh, group_published, category_id,
    category_name_de, category_name_en, category_name_es, category_name_fr, category_name_ja,
    category_name_ko, category_name_ru, category_name_zh, category_published, market_group_id,
    market_group_name_de, market_group_name_en, market_group_name_es, market_group_name_fr,
    market_group_name_ja, market_group_name_ko, market_group_name_ru, market_group_name_zh,
    market_group_parent_id, meta_group_id, meta_group_name_de, meta_group_name_en,
    meta_group_name_es, meta_group_name_fr, meta_group_name_ja, meta_group_name_ko,
    meta_group_name_ru, meta_group_name_zh, race_id, race_name_de, race_name_en, race_name_es,
    race_name_fr, race_name_ja, race_name_ko, race_name_ru, race_name_zh, faction_id,
    faction_name_de, faction_name_en, faction_name_es, faction_name_fr, faction_name_ja,
    faction_name_ko, faction_name_ru, faction_name_zh
)
SELECT
    t.id, t.name_de, t.name_en, t.name_es, t.name_fr, t.name_ja, t.name_ko, t.name_ru, t.name_zh,
    t.description_de, t.description_en, t.description_es, t.description_fr, t.description_ja,
    t.description_ko, t.description_ru, t.description_zh,
    t.published, t.tech_level, t.meta_level, t.mass, t.volume, t.capacity, t.radius, t.base_price,
    t.portion_size, t.icon_id, t.graphic_id, t.sound_id, t.variation_parent_type_id,
    t.ship_tree_group_id,
    g.id, g.name_de, g.name_en, g.name_es, g.name_fr, g.name_ja, g.name_ko, g.name_ru, g.name_zh,
    g.published,
    c.id, c.name_de, c.name_en, c.name_es, c.name_fr, c.name_ja, c.name_ko, c.name_ru, c.name_zh,
    c.published,
    mg.id, mg.name_de, mg.name_en, mg.name_es, mg.name_fr, mg.name_ja, mg.name_ko, mg.name_ru,
    mg.name_zh, mg.parent_group_id,
    mgr.id, mgr.name_de, mgr.name_en, mgr.name_es, mgr.name_fr, mgr.name_ja, mgr.name_ko,
    mgr.name_ru, mgr.name_zh,
    r.id, r.name_de, r.name_en, r.name_es, r.name_fr, r.name_ja, r.name_ko, r.name_ru, r.name_zh,
    f.id, f.name_de, f.name_en, f.name_es, f.name_fr, f.name_ja, f.name_ko, f.name_ru, f.name_zh
FROM types t
LEFT JOIN item_groups g ON t.group_id = g.id
LEFT JOIN categories c ON g.category_id = c.id
LEFT JOIN market_groups mg ON t.market_group_id = mg.id
LEFT JOIN meta_groups mgr ON t.meta_group_id = mgr.id
LEFT JOIN races r ON t.race_id = r.id
LEFT JOIN factions f ON t.faction_id = f.id
"""

_DELETE_DIM_UNIVERSE = "DELETE FROM dim_universe"
_INSERT_DIM_UNIVERSE = """
INSERT INTO dim_universe (
    solar_system_id, solar_system_name_de, solar_system_name_en, solar_system_name_es,
    solar_system_name_fr, solar_system_name_ja, solar_system_name_ko, solar_system_name_ru,
    solar_system_name_zh, security_status, security_class, border, corridor, fringe, hub,
    international, regional, luminosity, radius, position_x, position_y, position_z, star_id,
    wormhole_class_id, constellation_id, constellation_name_de, constellation_name_en,
    constellation_name_es, constellation_name_fr, constellation_name_ja, constellation_name_ko,
    constellation_name_ru, constellation_name_zh, region_id, region_name_de, region_name_en,
    region_name_es, region_name_fr, region_name_ja, region_name_ko, region_name_ru,
    region_name_zh, faction_id, faction_name_de, faction_name_en, faction_name_es,
    faction_name_fr, faction_name_ja, faction_name_ko, faction_name_ru, faction_name_zh
)
SELECT
    s.id, s.name_de, s.name_en, s.name_es, s.name_fr, s.name_ja, s.name_ko, s.name_ru, s.name_zh,
    s.security_status, s.security_class, s.border, s.corridor, s.fringe, s.hub, s.international,
    s.regional, s.luminosity, s.radius, s.position_x, s.position_y, s.position_z, s.star_id,
    s.wormhole_class_id,
    con.id, con.name_de, con.name_en, con.name_es, con.name_fr, con.name_ja, con.name_ko,
    con.name_ru, con.name_zh,
    reg.id, reg.name_de, reg.name_en, reg.name_es, reg.name_fr, reg.name_ja, reg.name_ko,
    reg.name_ru, reg.name_zh,
    COALESCE(s.faction_id, reg.faction_id),
    f.name_de, f.name_en, f.name_es, f.name_fr, f.name_ja, f.name_ko, f.name_ru, f.name_zh
FROM map_solar_systems s
LEFT JOIN map_constellations con ON s.constellation_id = con.id
LEFT JOIN map_regions reg ON s.region_id = reg.id
LEFT JOIN factions f ON COALESCE(s.faction_id, reg.faction_id) = f.id
"""
# Примечание (CLAUDE.md): у части систем faction_id не проставлен напрямую, но
# известен у региона (map_regions.faction_id) -- COALESCE, чтобы "чей это космос"
# отвечалось одним полем без ручной проверки обоих уровней в коде библиотеки.

_DELETE_TYPE_COMMON_STATS = "DELETE FROM type_common_stats"
_INSERT_TYPE_COMMON_STATS = """
INSERT INTO type_common_stats (
    type_id, structure_hp, armor_hp, shield_capacity, shield_recharge_time_ms,
    structure_resist_em, structure_resist_thermal, structure_resist_kinetic,
    structure_resist_explosive, armor_resist_em, armor_resist_thermal, armor_resist_kinetic,
    armor_resist_explosive, shield_resist_em, shield_resist_thermal, shield_resist_kinetic,
    shield_resist_explosive, cpu_usage, cpu_output, powergrid_usage, powergrid_output,
    capacitor_capacity, capacitor_recharge_time_ms, capacitor_need, max_locked_targets,
    max_target_range, scan_resolution, signature_radius, sensor_strength_radar,
    sensor_strength_ladar, sensor_strength_magnetometric, sensor_strength_gravimetric,
    max_velocity, agility, base_warp_speed, high_slots, mid_slots, low_slots, rig_slots,
    launcher_hardpoints, turret_hardpoints, calibration, rig_size, drone_bay_capacity,
    drone_bandwidth, damage_multiplier, optimal_range, falloff, tracking_speed, rate_of_fire_ms,
    activation_duration_ms, em_damage, explosive_damage, kinetic_damage, thermal_damage,
    charge_size, charge_group_1, charge_group_2, launcher_group, required_skill_1_type_id,
    required_skill_1_level, required_skill_2_type_id, required_skill_2_level,
    required_skill_3_type_id, required_skill_3_level, skill_primary_attribute,
    skill_secondary_attribute, skill_time_constant
)
SELECT
    td.id AS type_id,
    CAST(MAX(CASE WHEN a.attribute_id = 9 THEN a.value END) AS FLOAT) AS structure_hp,
    CAST(MAX(CASE WHEN a.attribute_id = 265 THEN a.value END) AS FLOAT) AS armor_hp,
    CAST(MAX(CASE WHEN a.attribute_id = 263 THEN a.value END) AS FLOAT) AS shield_capacity,
    CAST(MAX(CASE WHEN a.attribute_id = 479 THEN a.value END) AS FLOAT) AS shield_recharge_time_ms,
    CAST(MAX(CASE WHEN a.attribute_id = 113 THEN a.value END) AS FLOAT) AS structure_resist_em,
    CAST(MAX(CASE WHEN a.attribute_id = 110 THEN a.value END) AS FLOAT) AS structure_resist_thermal,
    CAST(MAX(CASE WHEN a.attribute_id = 109 THEN a.value END) AS FLOAT) AS structure_resist_kinetic,
    CAST(MAX(CASE WHEN a.attribute_id = 111 THEN a.value END) AS FLOAT) AS structure_resist_explosive,
    CAST(MAX(CASE WHEN a.attribute_id = 267 THEN a.value END) AS FLOAT) AS armor_resist_em,
    CAST(MAX(CASE WHEN a.attribute_id = 270 THEN a.value END) AS FLOAT) AS armor_resist_thermal,
    CAST(MAX(CASE WHEN a.attribute_id = 269 THEN a.value END) AS FLOAT) AS armor_resist_kinetic,
    CAST(MAX(CASE WHEN a.attribute_id = 268 THEN a.value END) AS FLOAT) AS armor_resist_explosive,
    CAST(MAX(CASE WHEN a.attribute_id = 271 THEN a.value END) AS FLOAT) AS shield_resist_em,
    CAST(MAX(CASE WHEN a.attribute_id = 274 THEN a.value END) AS FLOAT) AS shield_resist_thermal,
    CAST(MAX(CASE WHEN a.attribute_id = 273 THEN a.value END) AS FLOAT) AS shield_resist_kinetic,
    CAST(MAX(CASE WHEN a.attribute_id = 272 THEN a.value END) AS FLOAT) AS shield_resist_explosive,
    CAST(MAX(CASE WHEN a.attribute_id = 50 THEN a.value END) AS FLOAT) AS cpu_usage,
    CAST(MAX(CASE WHEN a.attribute_id = 48 THEN a.value END) AS FLOAT) AS cpu_output,
    CAST(MAX(CASE WHEN a.attribute_id = 30 THEN a.value END) AS FLOAT) AS powergrid_usage,
    CAST(MAX(CASE WHEN a.attribute_id = 11 THEN a.value END) AS FLOAT) AS powergrid_output,
    CAST(MAX(CASE WHEN a.attribute_id = 482 THEN a.value END) AS FLOAT) AS capacitor_capacity,
    CAST(MAX(CASE WHEN a.attribute_id = 55 THEN a.value END) AS FLOAT) AS capacitor_recharge_time_ms,
    CAST(MAX(CASE WHEN a.attribute_id = 6 THEN a.value END) AS FLOAT) AS capacitor_need,
    CAST(MAX(CASE WHEN a.attribute_id = 192 THEN a.value END) AS INTEGER) AS max_locked_targets,
    CAST(MAX(CASE WHEN a.attribute_id = 76 THEN a.value END) AS FLOAT) AS max_target_range,
    CAST(MAX(CASE WHEN a.attribute_id = 564 THEN a.value END) AS FLOAT) AS scan_resolution,
    CAST(MAX(CASE WHEN a.attribute_id = 552 THEN a.value END) AS FLOAT) AS signature_radius,
    CAST(MAX(CASE WHEN a.attribute_id = 208 THEN a.value END) AS FLOAT) AS sensor_strength_radar,
    CAST(MAX(CASE WHEN a.attribute_id = 209 THEN a.value END) AS FLOAT) AS sensor_strength_ladar,
    CAST(MAX(CASE WHEN a.attribute_id = 210 THEN a.value END) AS FLOAT) AS sensor_strength_magnetometric,
    CAST(MAX(CASE WHEN a.attribute_id = 211 THEN a.value END) AS FLOAT) AS sensor_strength_gravimetric,
    CAST(MAX(CASE WHEN a.attribute_id = 37 THEN a.value END) AS FLOAT) AS max_velocity,
    CAST(MAX(CASE WHEN a.attribute_id = 70 THEN a.value END) AS FLOAT) AS agility,
    CAST(MAX(CASE WHEN a.attribute_id = 1281 THEN a.value END) AS FLOAT) AS base_warp_speed,
    CAST(MAX(CASE WHEN a.attribute_id = 14 THEN a.value END) AS INTEGER) AS high_slots,
    CAST(MAX(CASE WHEN a.attribute_id = 13 THEN a.value END) AS INTEGER) AS mid_slots,
    CAST(MAX(CASE WHEN a.attribute_id = 12 THEN a.value END) AS INTEGER) AS low_slots,
    CAST(MAX(CASE WHEN a.attribute_id = 1154 THEN a.value END) AS INTEGER) AS rig_slots,
    CAST(MAX(CASE WHEN a.attribute_id = 101 THEN a.value END) AS INTEGER) AS launcher_hardpoints,
    CAST(MAX(CASE WHEN a.attribute_id = 102 THEN a.value END) AS INTEGER) AS turret_hardpoints,
    CAST(MAX(CASE WHEN a.attribute_id = 1132 THEN a.value END) AS FLOAT) AS calibration,
    CAST(MAX(CASE WHEN a.attribute_id = 1547 THEN a.value END) AS FLOAT) AS rig_size,
    CAST(MAX(CASE WHEN a.attribute_id = 283 THEN a.value END) AS FLOAT) AS drone_bay_capacity,
    CAST(MAX(CASE WHEN a.attribute_id = 1271 THEN a.value END) AS FLOAT) AS drone_bandwidth,
    CAST(MAX(CASE WHEN a.attribute_id = 64 THEN a.value END) AS FLOAT) AS damage_multiplier,
    CAST(MAX(CASE WHEN a.attribute_id = 54 THEN a.value END) AS FLOAT) AS optimal_range,
    CAST(MAX(CASE WHEN a.attribute_id = 158 THEN a.value END) AS FLOAT) AS falloff,
    CAST(MAX(CASE WHEN a.attribute_id = 160 THEN a.value END) AS FLOAT) AS tracking_speed,
    CAST(MAX(CASE WHEN a.attribute_id = 51 THEN a.value END) AS FLOAT) AS rate_of_fire_ms,
    CAST(MAX(CASE WHEN a.attribute_id = 73 THEN a.value END) AS FLOAT) AS activation_duration_ms,
    CAST(MAX(CASE WHEN a.attribute_id = 114 THEN a.value END) AS FLOAT) AS em_damage,
    CAST(MAX(CASE WHEN a.attribute_id = 116 THEN a.value END) AS FLOAT) AS explosive_damage,
    CAST(MAX(CASE WHEN a.attribute_id = 117 THEN a.value END) AS FLOAT) AS kinetic_damage,
    CAST(MAX(CASE WHEN a.attribute_id = 118 THEN a.value END) AS FLOAT) AS thermal_damage,
    CAST(MAX(CASE WHEN a.attribute_id = 128 THEN a.value END) AS INTEGER) AS charge_size,
    CAST(MAX(CASE WHEN a.attribute_id = 604 THEN a.value END) AS INTEGER) AS charge_group_1,
    CAST(MAX(CASE WHEN a.attribute_id = 605 THEN a.value END) AS INTEGER) AS charge_group_2,
    CAST(MAX(CASE WHEN a.attribute_id = 137 THEN a.value END) AS INTEGER) AS launcher_group,
    CAST(MAX(CASE WHEN a.attribute_id = 182 THEN a.value END) AS INTEGER) AS required_skill_1_type_id,
    CAST(MAX(CASE WHEN a.attribute_id = 277 THEN a.value END) AS INTEGER) AS required_skill_1_level,
    CAST(MAX(CASE WHEN a.attribute_id = 183 THEN a.value END) AS INTEGER) AS required_skill_2_type_id,
    CAST(MAX(CASE WHEN a.attribute_id = 278 THEN a.value END) AS INTEGER) AS required_skill_2_level,
    CAST(MAX(CASE WHEN a.attribute_id = 184 THEN a.value END) AS INTEGER) AS required_skill_3_type_id,
    CAST(MAX(CASE WHEN a.attribute_id = 279 THEN a.value END) AS INTEGER) AS required_skill_3_level,
    CAST(MAX(CASE WHEN a.attribute_id = 180 THEN a.value END) AS INTEGER) AS skill_primary_attribute,
    CAST(MAX(CASE WHEN a.attribute_id = 181 THEN a.value END) AS INTEGER) AS skill_secondary_attribute,
    CAST(MAX(CASE WHEN a.attribute_id = 275 THEN a.value END) AS FLOAT) AS skill_time_constant
FROM type_dogma td
JOIN type_dogma_dogma_attributes a ON a.type_dogma_id = td.id
GROUP BY td.id
"""
# type_dogma.id == types.id (подтверждённая 1:1 связь) -- typeDogma существует
# только для типов, у которых вообще есть dogma-атрибуты (не для всех типов).
# Значения атрибутов в SDE всегда FLOAT; там, где смысл целочисленный (слоты,
# уровни, typeID скилла) -- CAST(... AS INTEGER).

_DELETE_INDUSTRY_ACTIVITIES = "DELETE FROM industry_activities"
_INSERT_INDUSTRY_ACTIVITIES = """
INSERT INTO industry_activities (blueprint_id, activity_type, activity_time)
SELECT id, 'copying', activities_copying_time
FROM blueprints WHERE activities_copying_time IS NOT NULL
UNION ALL
SELECT id, 'invention', activities_invention_time
FROM blueprints WHERE activities_invention_time IS NOT NULL
UNION ALL
SELECT id, 'manufacturing', activities_manufacturing_time
FROM blueprints WHERE activities_manufacturing_time IS NOT NULL
UNION ALL
SELECT id, 'reaction', activities_reaction_time
FROM blueprints WHERE activities_reaction_time IS NOT NULL
UNION ALL
SELECT id, 'research_material', activities_research_material_time
FROM blueprints WHERE activities_research_material_time IS NOT NULL
UNION ALL
SELECT id, 'research_time', activities_research_time_time
FROM blueprints WHERE activities_research_time_time IS NOT NULL
"""

_DELETE_INDUSTRY_MATERIALS = "DELETE FROM industry_materials"
_INSERT_INDUSTRY_MATERIALS = """
INSERT INTO industry_materials (blueprint_id, activity_type, seq, type_id, quantity)
SELECT blueprints_id, 'copying', seq, type_id, quantity FROM blueprints_activities_copying_materials
UNION ALL
SELECT blueprints_id, 'invention', seq, type_id, quantity
FROM blueprints_activities_invention_materials
UNION ALL
SELECT blueprints_id, 'manufacturing', seq, type_id, quantity
FROM blueprints_activities_manufacturing_materials
UNION ALL
SELECT blueprints_id, 'reaction', seq, type_id, quantity
FROM blueprints_activities_reaction_materials
UNION ALL
SELECT blueprints_id, 'research_material', seq, type_id, quantity
FROM blueprints_activities_research_material_materials
UNION ALL
SELECT blueprints_id, 'research_time', seq, type_id, quantity
FROM blueprints_activities_research_time_materials
"""

_DELETE_INDUSTRY_PRODUCTS = "DELETE FROM industry_products"
_INSERT_INDUSTRY_PRODUCTS = """
INSERT INTO industry_products (blueprint_id, activity_type, seq, type_id, quantity, probability)
SELECT blueprints_id, 'invention', seq, type_id, quantity, probability
FROM blueprints_activities_invention_products
UNION ALL
SELECT blueprints_id, 'manufacturing', seq, type_id, quantity, CAST(NULL AS FLOAT)
FROM blueprints_activities_manufacturing_products
UNION ALL
SELECT blueprints_id, 'reaction', seq, type_id, quantity, CAST(NULL AS FLOAT)
FROM blueprints_activities_reaction_products
"""

_DELETE_INDUSTRY_SKILLS = "DELETE FROM industry_skills"
_INSERT_INDUSTRY_SKILLS = """
INSERT INTO industry_skills (blueprint_id, activity_type, seq, type_id, level)
SELECT blueprints_id, 'copying', seq, type_id, level FROM blueprints_activities_copying_skills
UNION ALL
SELECT blueprints_id, 'invention', seq, type_id, level FROM blueprints_activities_invention_skills
UNION ALL
SELECT blueprints_id, 'manufacturing', seq, type_id, level
FROM blueprints_activities_manufacturing_skills
UNION ALL
SELECT blueprints_id, 'reaction', seq, type_id, level FROM blueprints_activities_reaction_skills
UNION ALL
SELECT blueprints_id, 'research_material', seq, type_id, level
FROM blueprints_activities_research_material_skills
UNION ALL
SELECT blueprints_id, 'research_time', seq, type_id, level
FROM blueprints_activities_research_time_skills
"""

_DELETE_DIM_AGENTS = "DELETE FROM dim_agents"
_INSERT_DIM_AGENTS = """
INSERT INTO dim_agents (
    agent_id, agent_name_de, agent_name_en, agent_name_es, agent_name_fr, agent_name_ja,
    agent_name_ko, agent_name_ru, agent_name_zh, agent_level, agent_is_locator, agent_type_id,
    agent_type_name, division_id, division_name_de, division_name_en, division_name_es,
    division_name_fr, division_name_ja, division_name_ko, division_name_ru, division_name_zh,
    race_id, race_name_de, race_name_en, race_name_es, race_name_fr, race_name_ja, race_name_ko,
    race_name_ru, race_name_zh, bloodline_id, bloodline_name_de, bloodline_name_en,
    bloodline_name_es, bloodline_name_fr, bloodline_name_ja, bloodline_name_ko,
    bloodline_name_ru, bloodline_name_zh, corporation_id, corporation_name_de,
    corporation_name_en, corporation_name_es, corporation_name_fr, corporation_name_ja,
    corporation_name_ko, corporation_name_ru, corporation_name_zh, corporation_ticker,
    faction_id, faction_name_de, faction_name_en, faction_name_es, faction_name_fr,
    faction_name_ja, faction_name_ko, faction_name_ru, faction_name_zh, station_id,
    solar_system_id, solar_system_name_de, solar_system_name_en, solar_system_name_es,
    solar_system_name_fr, solar_system_name_ja, solar_system_name_ko, solar_system_name_ru,
    solar_system_name_zh, region_id, region_name_de, region_name_en, region_name_es,
    region_name_fr, region_name_ja, region_name_ko, region_name_ru, region_name_zh,
    security_status
)
SELECT
    c.id, c.name_de, c.name_en, c.name_es, c.name_fr, c.name_ja, c.name_ko, c.name_ru, c.name_zh,
    c.agent_level, c.agent_is_locator, c.agent_agent_type_id, at.name,
    c.agent_division_id, div.name_de, div.name_en, div.name_es, div.name_fr, div.name_ja,
    div.name_ko, div.name_ru, div.name_zh,
    c.race_id, r.name_de, r.name_en, r.name_es, r.name_fr, r.name_ja, r.name_ko, r.name_ru,
    r.name_zh,
    c.bloodline_id, bl.name_de, bl.name_en, bl.name_es, bl.name_fr, bl.name_ja, bl.name_ko,
    bl.name_ru, bl.name_zh,
    c.corporation_id, corp.name_de, corp.name_en, corp.name_es, corp.name_fr, corp.name_ja,
    corp.name_ko, corp.name_ru, corp.name_zh, corp.ticker_name,
    corp.faction_id, f.name_de, f.name_en, f.name_es, f.name_fr, f.name_ja, f.name_ko, f.name_ru,
    f.name_zh,
    c.location_id,
    st.solar_system_id, sys.name_de, sys.name_en, sys.name_es, sys.name_fr, sys.name_ja,
    sys.name_ko, sys.name_ru, sys.name_zh,
    sys.region_id, reg.name_de, reg.name_en, reg.name_es, reg.name_fr, reg.name_ja, reg.name_ko,
    reg.name_ru, reg.name_zh,
    sys.security_status
FROM npc_characters c
LEFT JOIN agent_types at ON c.agent_agent_type_id = at.id
LEFT JOIN npc_corporation_divisions div ON c.agent_division_id = div.id
LEFT JOIN races r ON c.race_id = r.id
LEFT JOIN bloodlines bl ON c.bloodline_id = bl.id
LEFT JOIN npc_corporations corp ON c.corporation_id = corp.id
LEFT JOIN factions f ON corp.faction_id = f.id
LEFT JOIN npc_stations st ON c.location_id = st.id
LEFT JOIN map_solar_systems sys ON st.solar_system_id = sys.id
LEFT JOIN map_regions reg ON sys.region_id = reg.id
WHERE c.agent_agent_type_id IS NOT NULL
"""

#: Порядок значения не имеет: витрины друг от друга не зависят, читают только raw-слой.
_MARTS: dict[str, tuple[str, str]] = {
    "dim_items": (_DELETE_DIM_ITEMS, _INSERT_DIM_ITEMS),
    "dim_universe": (_DELETE_DIM_UNIVERSE, _INSERT_DIM_UNIVERSE),
    "type_common_stats": (_DELETE_TYPE_COMMON_STATS, _INSERT_TYPE_COMMON_STATS),
    "industry_activities": (_DELETE_INDUSTRY_ACTIVITIES, _INSERT_INDUSTRY_ACTIVITIES),
    "industry_materials": (_DELETE_INDUSTRY_MATERIALS, _INSERT_INDUSTRY_MATERIALS),
    "industry_products": (_DELETE_INDUSTRY_PRODUCTS, _INSERT_INDUSTRY_PRODUCTS),
    "industry_skills": (_DELETE_INDUSTRY_SKILLS, _INSERT_INDUSTRY_SKILLS),
    "dim_agents": (_DELETE_DIM_AGENTS, _INSERT_DIM_AGENTS),
}


def build_marts(engine: Engine, schema: str | None = None) -> None:
    """Перестраивает все 8 витрин из уже загруженного raw-слоя.

    Каждая витрина -- отдельная транзакция (DELETE + INSERT). Идемпотентно:
    повторный вызов на тех же raw-данных даёт тот же результат.

    ``schema`` -- для теневой загрузки на PostgreSQL/MySQL (см. `etl.loader.
    load_fresh`): SQL-шаблоны используют неквалифицированные имена таблиц,
    поэтому вместо квалификации каждого имени переключаем схему/базу
    подключения (``SET search_path`` / ``USE``) перед каждой транзакцией.
    """
    for delete_sql, insert_sql in _MARTS.values():
        with engine.begin() as conn:
            _use_schema(conn, schema)
            conn.execute(text(delete_sql))
            conn.execute(text(insert_sql))


def _use_schema(conn: Connection, schema: str | None) -> None:
    if schema is None:
        return
    dialect = conn.engine.dialect.name
    if dialect == "postgresql":
        conn.exec_driver_sql(f'SET search_path TO "{schema}"')
    elif dialect in ("mysql", "mariadb"):
        conn.exec_driver_sql(f"USE `{schema}`")
    # sqlite: понятия схемы нет -- параметр не имеет смысла, игнорируем.
