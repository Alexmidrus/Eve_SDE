-- CHANGELOG 2026-07-09 (ревизия схемы):
--   * Исправлены висячие запятые в CREATE TABLE dim_items / dim_universe.
--   * 9 промежуточным таблицам с дочерними таблицами (epic_arcs_missions,
--     masteries_value, type_bonus_types и др.) добавлен суррогатный PK id
--     (присваивается ETL); натуральный ключ (parent_id, seq) сохранён как UNIQUE.
--     Это чинит 12 FK, ссылавшихся на несуществующую колонку id.
--   * Удалены 95 избыточных индексов, дублировавших префикс PK/UNIQUE.
-- =====================================================================
-- EVE Online SDE -- ОПТИМИЗИРОВАННЫЙ СЛОЙ (поверх eve_sde_schema.sql)
--
-- Назначение: удобное и быстрое извлечение данных из SDE для библиотеки
-- на Python (pip-пакет), без изменения/потери сырых таблиц из
-- eve_sde_schema.sql -- этот скрипт только ДОБАВЛЯЕТ индексы и новые
-- таблицы поверх уже загруженных raw-данных.
--
-- Порядок применения:
--   1) Выполнить eve_sde_schema.sql (создание raw-таблиц).
--   2) Загрузить данные из .jsonl в raw-таблицы (ETL).
--   3) Выполнить этот файл (индексы + денормализованные витрины + пивоты).
--   4) После каждого обновления SDE (патч игры) -- повторно выполнить ETL
--      для raw-таблиц, затем перезапустить DELETE+INSERT блоки из этого
--      файла (или обернуть их в хранимую процедуру/скрипт библиотеки).
--
-- Почему физические таблицы, а не VIEW:
--   SDE обновляется только вместе с патчами игры (раз в 1-4 недели), а не
--   в реальном времени. Пересчитывать JOIN/пивот на каждый запрос библиотеки
--   не нужно -- дешевле материализовать один раз и просто читать готовые
--   строки. Это снижает нагрузку на БД (нет повторяющихся тяжёлых JOIN)
--   и ускоряет типичные запросы игровых данных на порядок.
--   Если ваша СУБД поддерживает материализованные представления
--   (PostgreSQL: CREATE MATERIALIZED VIEW ... REFRESH MATERIALIZED VIEW;
--   Oracle: аналогично) -- можно заменить пары CREATE TABLE+INSERT на них
--   один в один, логика SELECT не меняется. Здесь выбран вариант с обычными
--   таблицами, т.к. он одинаково работает на MySQL/SQLite, где
--   материализованных представлений нет.
--
-- Состав:
--   A. Индексы на raw-слое (FK-колонки + горячие поля справочников)
--   B. Денормализованные витрины: dim_items, dim_universe
--   C. type_common_stats -- пивот 67 самых востребованных dogma-атрибутов
--   D. industry_* -- консолидация 18 таблиц чертежей в 4
--   E. dim_agents -- агенты NPC с полным контекстом (корпорация/локация)
-- =====================================================================


-- =====================================================================
-- ЧАСТЬ A. ИНДЕКСЫ НА RAW-СЛОЕ
--
-- В базовом скрипте (eve_sde_schema.sql) на колонках внешних ключей
-- индексы не создавались -- без них JOIN/поиск по FK-колонке в любой
-- СУБД выполняется полным сканированием таблицы. Для таблиц вроде
-- type_dogma_dogma_attributes (~640 тыс. строк) или map_moons (~344 тыс.)
-- это критично. Создаём индекс на каждой FK-колонке + на самых
-- востребованных для фильтрации колонках справочников (published,
-- name_en) -- стандартный CREATE INDEX, работает одинаково во всех СУБД.
-- =====================================================================

CREATE INDEX idx_agents_in_space_solar_system_id ON agents_in_space (solar_system_id);
CREATE INDEX idx_agents_in_space_type_id ON agents_in_space (type_id);
CREATE INDEX idx_ancestries_bloodline_id ON ancestries (bloodline_id);
CREATE INDEX idx_ancestries_icon_id ON ancestries (icon_id);
CREATE INDEX idx_bloodlines_corporation_id ON bloodlines (corporation_id);
CREATE INDEX idx_bloodlines_icon_id ON bloodlines (icon_id);
CREATE INDEX idx_bloodlines_race_id ON bloodlines (race_id);
CREATE INDEX idx_blueprints_blueprint_type_id ON blueprints (blueprint_type_id);
CREATE INDEX idx_blueprints_activities_copying_materials_type_id ON blueprints_activities_copying_materials (type_id);
CREATE INDEX idx_blueprints_activities_copying_skills_type_id ON blueprints_activities_copying_skills (type_id);
CREATE INDEX idx_blueprints_activities_invention_materials_type_id ON blueprints_activities_invention_materials (type_id);
CREATE INDEX idx_blueprints_activities_invention_products_type_id ON blueprints_activities_invention_products (type_id);
CREATE INDEX idx_blueprints_activities_invention_skills_type_id ON blueprints_activities_invention_skills (type_id);
CREATE INDEX idx_blueprints_activities_manufacturing_materials_type_id ON blueprints_activities_manufacturing_materials (type_id);
CREATE INDEX idx_blueprints_activities_manufacturing_products_type_id ON blueprints_activities_manufacturing_products (type_id);
CREATE INDEX idx_blueprints_activities_manufacturing_skills_type_id ON blueprints_activities_manufacturing_skills (type_id);
CREATE INDEX idx_blueprints_activities_reaction_materials_type_id ON blueprints_activities_reaction_materials (type_id);
CREATE INDEX idx_blueprints_activities_reaction_products_type_id ON blueprints_activities_reaction_products (type_id);
CREATE INDEX idx_blueprints_activities_reaction_skills_type_id ON blueprints_activities_reaction_skills (type_id);
CREATE INDEX idx_blueprints_activities_research_material_materials_type_id ON blueprints_activities_research_material_materials (type_id);
CREATE INDEX idx_blueprints_activities_research_material_skills_type_id ON blueprints_activities_research_material_skills (type_id);
CREATE INDEX idx_blueprints_activities_research_time_materials_type_id ON blueprints_activities_research_time_materials (type_id);
CREATE INDEX idx_blueprints_activities_research_time_skills_type_id ON blueprints_activities_research_time_skills (type_id);
CREATE INDEX idx_categories_icon_id ON categories (icon_id);
CREATE INDEX idx_certificates_group_id ON certificates (group_id);
CREATE INDEX idx_certificates_skill_types_source_key ON certificates_skill_types (source_key);
CREATE INDEX idx_clone_grades_skills_type_id ON clone_grades_skills (type_id);
CREATE INDEX idx_compressible_types_compressed_type_id ON compressible_types (compressed_type_id);
CREATE INDEX idx_contraband_types_factions_source_key ON contraband_types_factions (source_key);
CREATE INDEX idx_control_tower_resources_resources_faction_id ON control_tower_resources_resources (faction_id);
CREATE INDEX idx_control_tower_resources_resources_resource_type_id ON control_tower_resources_resources (resource_type_id);
CREATE INDEX idx_dbuff_collections_item_modifiers_dogma_attribute_id ON dbuff_collections_item_modifiers (dogma_attribute_id);
CREATE INDEX idx_dbuff_collections_location_group_modifiers_dogma_att_5d3860 ON dbuff_collections_location_group_modifiers (dogma_attribute_id);
CREATE INDEX idx_dbuff_collections_location_group_modifiers_group_id ON dbuff_collections_location_group_modifiers (group_id);
CREATE INDEX idx_dbuff_collections_location_modifiers_dogma_attribute_id ON dbuff_collections_location_modifiers (dogma_attribute_id);
CREATE INDEX idx_dbuff_collections_location_required_skill_modifiers__49676c ON dbuff_collections_location_required_skill_modifiers (dogma_attribute_id);
CREATE INDEX idx_dbuff_collections_location_required_skill_modifiers__3f2a48 ON dbuff_collections_location_required_skill_modifiers (skill_id);
CREATE INDEX idx_dogma_attributes_attribute_category_id ON dogma_attributes (attribute_category_id);
CREATE INDEX idx_dogma_attributes_charge_recharge_time_id ON dogma_attributes (charge_recharge_time_id);
CREATE INDEX idx_dogma_attributes_icon_id ON dogma_attributes (icon_id);
CREATE INDEX idx_dogma_attributes_max_attribute_id ON dogma_attributes (max_attribute_id);
CREATE INDEX idx_dogma_attributes_min_attribute_id ON dogma_attributes (min_attribute_id);
CREATE INDEX idx_dogma_attributes_unit_id ON dogma_attributes (unit_id);
CREATE INDEX idx_dogma_effects_discharge_attribute_id ON dogma_effects (discharge_attribute_id);
CREATE INDEX idx_dogma_effects_duration_attribute_id ON dogma_effects (duration_attribute_id);
CREATE INDEX idx_dogma_effects_falloff_attribute_id ON dogma_effects (falloff_attribute_id);
CREATE INDEX idx_dogma_effects_fitting_usage_chance_attribute_id ON dogma_effects (fitting_usage_chance_attribute_id);
CREATE INDEX idx_dogma_effects_icon_id ON dogma_effects (icon_id);
CREATE INDEX idx_dogma_effects_npc_activation_chance_attribute_id ON dogma_effects (npc_activation_chance_attribute_id);
CREATE INDEX idx_dogma_effects_npc_usage_chance_attribute_id ON dogma_effects (npc_usage_chance_attribute_id);
CREATE INDEX idx_dogma_effects_range_attribute_id ON dogma_effects (range_attribute_id);
CREATE INDEX idx_dogma_effects_resistance_attribute_id ON dogma_effects (resistance_attribute_id);
CREATE INDEX idx_dogma_effects_tracking_speed_attribute_id ON dogma_effects (tracking_speed_attribute_id);
CREATE INDEX idx_dogma_effects_modifier_info_effect_id ON dogma_effects_modifier_info (effect_id);
CREATE INDEX idx_dogma_effects_modifier_info_group_id ON dogma_effects_modifier_info (group_id);
CREATE INDEX idx_dogma_effects_modifier_info_modified_attribute_id ON dogma_effects_modifier_info (modified_attribute_id);
CREATE INDEX idx_dogma_effects_modifier_info_modifying_attribute_id ON dogma_effects_modifier_info (modifying_attribute_id);
CREATE INDEX idx_dogma_effects_modifier_info_skill_type_id ON dogma_effects_modifier_info (skill_type_id);
CREATE INDEX idx_dungeons_archetype_id ON dungeons (archetype_id);
CREATE INDEX idx_dungeons_faction_id ON dungeons (faction_id);
CREATE INDEX idx_dynamic_item_attributes_attribute_ids_source_key ON dynamic_item_attributes_attribute_ids (source_key);
CREATE INDEX idx_dynamic_item_attributes_input_output_mapping_resulting_type ON dynamic_item_attributes_input_output_mapping (resulting_type);
CREATE INDEX idx_dynamic_item_attributes_input_output_mapping_applica_197bdb ON dynamic_item_attributes_input_output_mapping_applicab_543eea (value);
CREATE INDEX idx_epic_arcs_faction_id ON epic_arcs (faction_id);
CREATE INDEX idx_epic_arcs_icon_id ON epic_arcs (icon_id);
CREATE INDEX idx_epic_arcs_missions_agent_id ON epic_arcs_missions (agent_id);
CREATE INDEX idx_factions_corporation_id ON factions (corporation_id);
CREATE INDEX idx_factions_icon_id ON factions (icon_id);
CREATE INDEX idx_factions_militia_corporation_id ON factions (militia_corporation_id);
CREATE INDEX idx_factions_solar_system_id ON factions (solar_system_id);
CREATE INDEX idx_factions_member_races_value ON factions_member_races (value);
CREATE INDEX idx_graphics_sof_material_set_id ON graphics (sof_material_set_id);
CREATE INDEX idx_item_groups_category_id ON item_groups (category_id);
CREATE INDEX idx_item_groups_icon_id ON item_groups (icon_id);
CREATE INDEX idx_landmarks_icon_id ON landmarks (icon_id);
CREATE INDEX idx_landmarks_location_id ON landmarks (location_id);
CREATE INDEX idx_map_asteroid_belts_solar_system_id ON map_asteroid_belts (solar_system_id);
CREATE INDEX idx_map_constellations_faction_id ON map_constellations (faction_id);
CREATE INDEX idx_map_constellations_region_id ON map_constellations (region_id);
CREATE INDEX idx_map_constellations_solar_system_ids_value ON map_constellations_solar_system_ids (value);
CREATE INDEX idx_map_moons_solar_system_id ON map_moons (solar_system_id);
CREATE INDEX idx_map_moons_type_id ON map_moons (type_id);
CREATE INDEX idx_map_moons_npc_station_ids_value ON map_moons_npc_station_ids (value);
CREATE INDEX idx_map_planets_solar_system_id ON map_planets (solar_system_id);
CREATE INDEX idx_map_planets_type_id ON map_planets (type_id);
CREATE INDEX idx_map_planets_asteroid_belt_ids_value ON map_planets_asteroid_belt_ids (value);
CREATE INDEX idx_map_planets_moon_ids_value ON map_planets_moon_ids (value);
CREATE INDEX idx_map_planets_npc_station_ids_value ON map_planets_npc_station_ids (value);
CREATE INDEX idx_map_regions_faction_id ON map_regions (faction_id);
CREATE INDEX idx_map_regions_constellation_ids_value ON map_regions_constellation_ids (value);
CREATE INDEX idx_map_secondary_suns_effect_beacon_type_id ON map_secondary_suns (effect_beacon_type_id);
CREATE INDEX idx_map_secondary_suns_solar_system_id ON map_secondary_suns (solar_system_id);
CREATE INDEX idx_map_secondary_suns_type_id ON map_secondary_suns (type_id);
CREATE INDEX idx_map_solar_systems_constellation_id ON map_solar_systems (constellation_id);
CREATE INDEX idx_map_solar_systems_faction_id ON map_solar_systems (faction_id);
CREATE INDEX idx_map_solar_systems_region_id ON map_solar_systems (region_id);
CREATE INDEX idx_map_solar_systems_star_id ON map_solar_systems (star_id);
CREATE INDEX idx_map_solar_systems_disallowed_anchor_categories_value ON map_solar_systems_disallowed_anchor_categories (value);
CREATE INDEX idx_map_solar_systems_disallowed_anchor_groups_value ON map_solar_systems_disallowed_anchor_groups (value);
CREATE INDEX idx_map_solar_systems_planet_ids_value ON map_solar_systems_planet_ids (value);
CREATE INDEX idx_map_solar_systems_stargate_ids_value ON map_solar_systems_stargate_ids (value);
CREATE INDEX idx_map_stargates_destination_solar_system_id ON map_stargates (destination_solar_system_id);
CREATE INDEX idx_map_stargates_destination_stargate_id ON map_stargates (destination_stargate_id);
CREATE INDEX idx_map_stargates_solar_system_id ON map_stargates (solar_system_id);
CREATE INDEX idx_map_stargates_type_id ON map_stargates (type_id);
CREATE INDEX idx_map_stars_solar_system_id ON map_stars (solar_system_id);
CREATE INDEX idx_map_stars_type_id ON map_stars (type_id);
CREATE INDEX idx_market_groups_icon_id ON market_groups (icon_id);
CREATE INDEX idx_market_groups_parent_group_id ON market_groups (parent_group_id);
CREATE INDEX idx_masteries_value_value_value ON masteries_value_value (value);
CREATE INDEX idx_mercenary_tactical_operations_dungeon_id ON mercenary_tactical_operations (dungeon_id);
CREATE INDEX idx_meta_groups_icon_id ON meta_groups (icon_id);
CREATE INDEX idx_military_campaign_objectives_campaign_id ON military_campaign_objectives (campaign_id);
CREATE INDEX idx_military_campaign_objectives_issuer_corporation_id ON military_campaign_objectives (issuer_corporation_id);
CREATE INDEX idx_military_campaign_objectives_presenting_character_id ON military_campaign_objectives (presenting_character_id);
CREATE INDEX idx_military_campaign_objectives_rewards_isk_issuer_corp_a76ddc ON military_campaign_objectives (rewards_isk_issuer_corporation_id);
CREATE INDEX idx_military_campaign_objectives_rewards_lp_issuer_corpo_84a0af ON military_campaign_objectives (rewards_lp_issuer_corporation_id);
CREATE INDEX idx_military_campaign_objectives_rewards_standing_issuer_04df18 ON military_campaign_objectives (rewards_standing_issuer_faction_id);
CREATE INDEX idx_military_campaigns_issuer_faction_id ON military_campaigns (issuer_faction_id);
CREATE INDEX idx_missions_agent_type_id ON missions (agent_type_id);
CREATE INDEX idx_missions_corporation_id ON missions (corporation_id);
CREATE INDEX idx_missions_courier_mission_objective_type_id ON missions (courier_mission_objective_type_id);
CREATE INDEX idx_missions_faction_id ON missions (faction_id);
CREATE INDEX idx_missions_initial_agent_gift_type_id ON missions (initial_agent_gift_type_id);
CREATE INDEX idx_missions_kill_mission_objective_type_id ON missions (kill_mission_objective_type_id);
CREATE INDEX idx_missions_mission_rewards_bonus_reward_reward_type_id ON missions (mission_rewards_bonus_reward_reward_type_id);
CREATE INDEX idx_missions_mission_rewards_reward_reward_type_id ON missions (mission_rewards_reward_reward_type_id);
CREATE INDEX idx_missions_extra_standings_source_key ON missions_extra_standings (source_key);
CREATE INDEX idx_npc_characters_agent_agent_type_id ON npc_characters (agent_agent_type_id);
CREATE INDEX idx_npc_characters_agent_division_id ON npc_characters (agent_division_id);
CREATE INDEX idx_npc_characters_ancestry_id ON npc_characters (ancestry_id);
CREATE INDEX idx_npc_characters_bloodline_id ON npc_characters (bloodline_id);
CREATE INDEX idx_npc_characters_corporation_id ON npc_characters (corporation_id);
CREATE INDEX idx_npc_characters_location_id ON npc_characters (location_id);
CREATE INDEX idx_npc_characters_race_id ON npc_characters (race_id);
CREATE INDEX idx_npc_characters_skills_type_id ON npc_characters_skills (type_id);
CREATE INDEX idx_npc_corporations_ceo_id ON npc_corporations (ceo_id);
CREATE INDEX idx_npc_corporations_enemy_id ON npc_corporations (enemy_id);
CREATE INDEX idx_npc_corporations_faction_id ON npc_corporations (faction_id);
CREATE INDEX idx_npc_corporations_friend_id ON npc_corporations (friend_id);
CREATE INDEX idx_npc_corporations_icon_id ON npc_corporations (icon_id);
CREATE INDEX idx_npc_corporations_main_activity_id ON npc_corporations (main_activity_id);
CREATE INDEX idx_npc_corporations_race_id ON npc_corporations (race_id);
CREATE INDEX idx_npc_corporations_secondary_activity_id ON npc_corporations (secondary_activity_id);
CREATE INDEX idx_npc_corporations_solar_system_id ON npc_corporations (solar_system_id);
CREATE INDEX idx_npc_corporations_station_id ON npc_corporations (station_id);
CREATE INDEX idx_npc_corporations_allowed_member_races_value ON npc_corporations_allowed_member_races (value);
CREATE INDEX idx_npc_corporations_corporation_trades_source_key ON npc_corporations_corporation_trades (source_key);
CREATE INDEX idx_npc_corporations_divisions_leader_id ON npc_corporations_divisions (leader_id);
CREATE INDEX idx_npc_corporations_exchange_rates_source_key ON npc_corporations_exchange_rates (source_key);
CREATE INDEX idx_npc_corporations_investors_source_key ON npc_corporations_investors (source_key);
CREATE INDEX idx_npc_stations_operation_id ON npc_stations (operation_id);
CREATE INDEX idx_npc_stations_owner_id ON npc_stations (owner_id);
CREATE INDEX idx_npc_stations_solar_system_id ON npc_stations (solar_system_id);
CREATE INDEX idx_npc_stations_type_id ON npc_stations (type_id);
CREATE INDEX idx_planet_resources_reagent_type_id ON planet_resources (reagent_type_id);
CREATE INDEX idx_planet_schematics_pins_value ON planet_schematics_pins (value);
CREATE INDEX idx_planet_schematics_types_source_key ON planet_schematics_types (source_key);
CREATE INDEX idx_races_ship_type_id ON races (ship_type_id);
CREATE INDEX idx_races_skills_source_key ON races_skills (source_key);
CREATE INDEX idx_ship_tree_factions_elements_value ON ship_tree_factions_elements (value);
CREATE INDEX idx_ship_tree_groups_elements_value ON ship_tree_groups_elements (value);
CREATE INDEX idx_ship_tree_groups_pre_req_skills_skills_source_key ON ship_tree_groups_pre_req_skills_skills (source_key);
CREATE INDEX idx_skin_licenses_license_type_id ON skin_licenses (license_type_id);
CREATE INDEX idx_skin_licenses_skin_id ON skin_licenses (skin_id);
CREATE INDEX idx_skin_materials_material_set_id ON skin_materials (material_set_id);
CREATE INDEX idx_skinr_component_point_values_value_source_key ON skinr_component_point_values_value (source_key);
CREATE INDEX idx_skinr_components_category ON skinr_components (category);
CREATE INDEX idx_skinr_components_rarity ON skinr_components (rarity);
CREATE INDEX idx_skinr_components_sequence_binder_item_type_id ON skinr_components (sequence_binder_item_type_id);
CREATE INDEX idx_skinr_components_associated_type_ids_type_id ON skinr_components_associated_type_ids (type_id);
CREATE INDEX idx_skinr_slot_configurations_config_value ON skinr_slot_configurations_config (value);
CREATE INDEX idx_skinr_slot_configurations_ships_value ON skinr_slot_configurations_ships (value);
CREATE INDEX idx_skinr_slots_category ON skinr_slots (category);
CREATE INDEX idx_skinr_slots_allowed_design_component_categories_value ON skinr_slots_allowed_design_component_categories (value);
CREATE INDEX idx_skins_skin_material_id ON skins (skin_material_id);
CREATE INDEX idx_skins_types_value ON skins_types (value);
CREATE INDEX idx_sovereignty_upgrades_fuel_type_id ON sovereignty_upgrades (fuel_type_id);
CREATE INDEX idx_station_operations_activity_id ON station_operations (activity_id);
CREATE INDEX idx_station_operations_services_value ON station_operations_services (value);
CREATE INDEX idx_type_bonus_icon_id ON type_bonus (icon_id);
CREATE INDEX idx_type_bonus_misc_bonuses_unit_id ON type_bonus_misc_bonuses (unit_id);
CREATE INDEX idx_type_bonus_role_bonuses_unit_id ON type_bonus_role_bonuses (unit_id);
CREATE INDEX idx_type_bonus_types_source_key ON type_bonus_types (source_key);
CREATE INDEX idx_type_bonus_types_value_unit_id ON type_bonus_types_value (unit_id);
CREATE INDEX idx_type_dogma_dogma_attributes_attribute_id ON type_dogma_dogma_attributes (attribute_id);
CREATE INDEX idx_type_dogma_dogma_effects_effect_id ON type_dogma_dogma_effects (effect_id);
CREATE INDEX idx_type_elements_elements_source_key ON type_elements_elements (source_key);
CREATE INDEX idx_type_lists_excluded_category_ids_value ON type_lists_excluded_category_ids (value);
CREATE INDEX idx_type_lists_excluded_group_ids_value ON type_lists_excluded_group_ids (value);
CREATE INDEX idx_type_lists_excluded_type_ids_value ON type_lists_excluded_type_ids (value);
CREATE INDEX idx_type_lists_included_category_ids_value ON type_lists_included_category_ids (value);
CREATE INDEX idx_type_lists_included_group_ids_value ON type_lists_included_group_ids (value);
CREATE INDEX idx_type_lists_included_type_ids_value ON type_lists_included_type_ids (value);
CREATE INDEX idx_type_materials_materials_material_type_id ON type_materials_materials (material_type_id);
CREATE INDEX idx_type_materials_randomized_materials_material_type_id ON type_materials_randomized_materials (material_type_id);
CREATE INDEX idx_types_graphic_id ON types (graphic_id);
CREATE INDEX idx_types_group_id ON types (group_id);
CREATE INDEX idx_types_icon_id ON types (icon_id);
CREATE INDEX idx_types_market_group_id ON types (market_group_id);
CREATE INDEX idx_types_meta_group_id ON types (meta_group_id);
CREATE INDEX idx_types_race_id ON types (race_id);
CREATE INDEX idx_types_ship_tree_group_id ON types (ship_tree_group_id);
CREATE INDEX idx_types_variation_parent_type_id ON types (variation_parent_type_id);

-- Дополнительные индексы на часто фильтруемых колонках справочников:
CREATE INDEX idx_types_published_extra ON types (published);
CREATE INDEX idx_types_group_id_extra ON types (group_id);
CREATE INDEX idx_types_market_group_id_extra ON types (market_group_id);
CREATE INDEX idx_types_name_en_extra ON types (name_en);
CREATE INDEX idx_item_groups_published_extra ON item_groups (published);
CREATE INDEX idx_item_groups_category_id_extra ON item_groups (category_id);
CREATE INDEX idx_item_groups_name_en_extra ON item_groups (name_en);
CREATE INDEX idx_categories_published_extra ON categories (published);
CREATE INDEX idx_categories_name_en_extra ON categories (name_en);
CREATE INDEX idx_market_groups_parent_group_id_extra ON market_groups (parent_group_id);
CREATE INDEX idx_market_groups_name_en_extra ON market_groups (name_en);
CREATE INDEX idx_map_solar_systems_region_id_extra ON map_solar_systems (region_id);
CREATE INDEX idx_map_solar_systems_constellation_id_extra ON map_solar_systems (constellation_id);
CREATE INDEX idx_map_solar_systems_name_en_extra ON map_solar_systems (name_en);
CREATE INDEX idx_map_solar_systems_security_status_extra ON map_solar_systems (security_status);
CREATE INDEX idx_map_constellations_region_id_extra ON map_constellations (region_id);
CREATE INDEX idx_map_constellations_name_en_extra ON map_constellations (name_en);
CREATE INDEX idx_map_regions_name_en_extra ON map_regions (name_en);
CREATE INDEX idx_npc_corporations_faction_id_extra ON npc_corporations (faction_id);
CREATE INDEX idx_npc_corporations_name_en_extra ON npc_corporations (name_en);
CREATE INDEX idx_npc_characters_corporation_id_extra ON npc_characters (corporation_id);
CREATE INDEX idx_npc_characters_name_en_extra ON npc_characters (name_en);
CREATE INDEX idx_blueprints_blueprint_type_id_extra ON blueprints (blueprint_type_id);
CREATE INDEX idx_factions_name_en_extra ON factions (name_en);



-- =====================================================================
-- ЧАСТЬ B.1. dim_items -- денормализованная витрина по предметам/кораблям
--
-- Собирает в одну строку на typeID всё, что раньше требовало 5-6 JOIN'ов
-- по raw-таблицам (types -> item_groups -> categories, types ->
-- market_groups, types -> meta_groups, types -> races, types -> factions).
-- Это ФИЗИЧЕСКАЯ таблица (не VIEW): т.к. SDE обновляется только с патчами
-- игры, а не в реальном времени, пересчитывать JOIN на каждый запрос
-- не имеет смысла -- один раз материализуем после каждой загрузки SDE.
-- Все 8 языков сохранены как в исходных данных (по требованию пользователя).
-- =====================================================================

CREATE TABLE dim_items (
    type_id INTEGER PRIMARY KEY, -- = types.id
    type_name_de TEXT,
    type_name_en TEXT,
    type_name_es TEXT,
    type_name_fr TEXT,
    type_name_ja TEXT,
    type_name_ko TEXT,
    type_name_ru TEXT,
    type_name_zh TEXT,
    type_description_de TEXT,
    type_description_en TEXT,
    type_description_es TEXT,
    type_description_fr TEXT,
    type_description_ja TEXT,
    type_description_ko TEXT,
    type_description_ru TEXT,
    type_description_zh TEXT,
    published BOOLEAN,
    tech_level INTEGER,
    meta_level INTEGER,
    mass FLOAT,
    volume FLOAT,
    capacity FLOAT,
    radius FLOAT,
    base_price FLOAT,
    portion_size INTEGER,
    icon_id INTEGER,
    graphic_id INTEGER,
    sound_id INTEGER,
    variation_parent_type_id INTEGER,
    ship_tree_group_id INTEGER,
    -- группа предмета (item_groups)
    group_id INTEGER,
    group_name_de TEXT,
    group_name_en TEXT,
    group_name_es TEXT,
    group_name_fr TEXT,
    group_name_ja TEXT,
    group_name_ko TEXT,
    group_name_ru TEXT,
    group_name_zh TEXT,
    group_published BOOLEAN,
    -- категория (categories)
    category_id INTEGER,
    category_name_de TEXT,
    category_name_en TEXT,
    category_name_es TEXT,
    category_name_fr TEXT,
    category_name_ja TEXT,
    category_name_ko TEXT,
    category_name_ru TEXT,
    category_name_zh TEXT,
    category_published BOOLEAN,
    -- рыночная группа (market_groups)
    market_group_id INTEGER,
    market_group_name_de TEXT,
    market_group_name_en TEXT,
    market_group_name_es TEXT,
    market_group_name_fr TEXT,
    market_group_name_ja TEXT,
    market_group_name_ko TEXT,
    market_group_name_ru TEXT,
    market_group_name_zh TEXT,
    market_group_parent_id INTEGER,
    -- мета-группа (meta_groups: Tech I/II/III, Faction, Officer ...)
    meta_group_id INTEGER,
    meta_group_name_de TEXT,
    meta_group_name_en TEXT,
    meta_group_name_es TEXT,
    meta_group_name_fr TEXT,
    meta_group_name_ja TEXT,
    meta_group_name_ko TEXT,
    meta_group_name_ru TEXT,
    meta_group_name_zh TEXT,
    -- раса (races)
    race_id INTEGER,
    race_name_de TEXT,
    race_name_en TEXT,
    race_name_es TEXT,
    race_name_fr TEXT,
    race_name_ja TEXT,
    race_name_ko TEXT,
    race_name_ru TEXT,
    race_name_zh TEXT,
    -- фракция (factions) -- ВНИМАНИЕ: types.faction_id смешанная ссылка
    -- (см. отчёт: часть значений -- на самом деле corporation_id из
    -- npc_corporations, не faction_id) -- для ~10 из 33 значений факшн
    -- может быть NULL, даже если исходное поле faction_id заполнено.
    faction_id INTEGER,
    faction_name_de TEXT,
    faction_name_en TEXT,
    faction_name_es TEXT,
    faction_name_fr TEXT,
    faction_name_ja TEXT,
    faction_name_ko TEXT,
    faction_name_ru TEXT,
    faction_name_zh TEXT
);

CREATE INDEX idx_dim_items_group_id ON dim_items (group_id);
CREATE INDEX idx_dim_items_category_id ON dim_items (category_id);
CREATE INDEX idx_dim_items_market_group_id ON dim_items (market_group_id);
CREATE INDEX idx_dim_items_published ON dim_items (published);
CREATE INDEX idx_dim_items_type_name_en ON dim_items (type_name_en);

-- Заполнение dim_items из raw-слоя. Запускать после (пере)загрузки SDE.
DELETE FROM dim_items;
INSERT INTO dim_items (
    type_id, type_name_de, type_name_en, type_name_es, type_name_fr, type_name_ja, type_name_ko, type_name_ru, type_name_zh, type_description_de, type_description_en, type_description_es, type_description_fr, type_description_ja, type_description_ko, type_description_ru, type_description_zh, published, tech_level, meta_level, mass, volume, capacity, radius, base_price, portion_size, icon_id, graphic_id, sound_id, variation_parent_type_id, ship_tree_group_id, group_id, group_name_de, group_name_en, group_name_es, group_name_fr, group_name_ja, group_name_ko, group_name_ru, group_name_zh, group_published, category_id, category_name_de, category_name_en, category_name_es, category_name_fr, category_name_ja, category_name_ko, category_name_ru, category_name_zh, category_published, market_group_id, market_group_name_de, market_group_name_en, market_group_name_es, market_group_name_fr, market_group_name_ja, market_group_name_ko, market_group_name_ru, market_group_name_zh, market_group_parent_id, meta_group_id, meta_group_name_de, meta_group_name_en, meta_group_name_es, meta_group_name_fr, meta_group_name_ja, meta_group_name_ko, meta_group_name_ru, meta_group_name_zh, race_id, race_name_de, race_name_en, race_name_es, race_name_fr, race_name_ja, race_name_ko, race_name_ru, race_name_zh, faction_id, faction_name_de, faction_name_en, faction_name_es, faction_name_fr, faction_name_ja, faction_name_ko, faction_name_ru, faction_name_zh
)
SELECT
    t.id,
    t.name_de,
    t.name_en,
    t.name_es,
    t.name_fr,
    t.name_ja,
    t.name_ko,
    t.name_ru,
    t.name_zh,
    t.description_de,
    t.description_en,
    t.description_es,
    t.description_fr,
    t.description_ja,
    t.description_ko,
    t.description_ru,
    t.description_zh,
    t.published,
    t.tech_level,
    t.meta_level,
    t.mass,
    t.volume,
    t.capacity,
    t.radius,
    t.base_price,
    t.portion_size,
    t.icon_id,
    t.graphic_id,
    t.sound_id,
    t.variation_parent_type_id,
    t.ship_tree_group_id,
    g.id,
    g.name_de,
    g.name_en,
    g.name_es,
    g.name_fr,
    g.name_ja,
    g.name_ko,
    g.name_ru,
    g.name_zh,
    g.published,
    c.id,
    c.name_de,
    c.name_en,
    c.name_es,
    c.name_fr,
    c.name_ja,
    c.name_ko,
    c.name_ru,
    c.name_zh,
    c.published,
    mg.id,
    mg.name_de,
    mg.name_en,
    mg.name_es,
    mg.name_fr,
    mg.name_ja,
    mg.name_ko,
    mg.name_ru,
    mg.name_zh,
    mg.parent_group_id,
    mgr.id,
    mgr.name_de,
    mgr.name_en,
    mgr.name_es,
    mgr.name_fr,
    mgr.name_ja,
    mgr.name_ko,
    mgr.name_ru,
    mgr.name_zh,
    r.id,
    r.name_de,
    r.name_en,
    r.name_es,
    r.name_fr,
    r.name_ja,
    r.name_ko,
    r.name_ru,
    r.name_zh,
    f.id,
    f.name_de,
    f.name_en,
    f.name_es,
    f.name_fr,
    f.name_ja,
    f.name_ko,
    f.name_ru,
    f.name_zh
FROM types t
LEFT JOIN item_groups g ON t.group_id = g.id
LEFT JOIN categories c ON g.category_id = c.id
LEFT JOIN market_groups mg ON t.market_group_id = mg.id
LEFT JOIN meta_groups mgr ON t.meta_group_id = mgr.id
LEFT JOIN races r ON t.race_id = r.id
LEFT JOIN factions f ON t.faction_id = f.id;



-- =====================================================================
-- ЧАСТЬ B.2. dim_universe -- денормализованная витрина по вселенной
--
-- Система -> созвездие -> регион -> фракция в одной строке на solarSystemID.
-- Типичный запрос бота/инструмента ("в какой системе я нахожусь, в каком
-- регионе, чей это космос, насколько тут безопасно") иначе требует
-- 3 JOIN'а по map_solar_systems -> map_constellations -> map_regions.
-- =====================================================================

CREATE TABLE dim_universe (
    solar_system_id INTEGER PRIMARY KEY, -- = map_solar_systems.id
    solar_system_name_de TEXT,
    solar_system_name_en TEXT,
    solar_system_name_es TEXT,
    solar_system_name_fr TEXT,
    solar_system_name_ja TEXT,
    solar_system_name_ko TEXT,
    solar_system_name_ru TEXT,
    solar_system_name_zh TEXT,
    security_status FLOAT,
    security_class VARCHAR(10),
    border BOOLEAN,
    corridor BOOLEAN,
    fringe BOOLEAN,
    hub BOOLEAN,
    international BOOLEAN,
    regional BOOLEAN,
    luminosity FLOAT,
    radius FLOAT,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    star_id INTEGER,
    wormhole_class_id INTEGER,
    -- созвездие
    constellation_id INTEGER,
    constellation_name_de TEXT,
    constellation_name_en TEXT,
    constellation_name_es TEXT,
    constellation_name_fr TEXT,
    constellation_name_ja TEXT,
    constellation_name_ko TEXT,
    constellation_name_ru TEXT,
    constellation_name_zh TEXT,
    -- регион
    region_id INTEGER,
    region_name_de TEXT,
    region_name_en TEXT,
    region_name_es TEXT,
    region_name_fr TEXT,
    region_name_ja TEXT,
    region_name_ko TEXT,
    region_name_ru TEXT,
    region_name_zh TEXT,
    -- фракция, контролирующая систему (nullable -- есть системы без владельца)
    faction_id INTEGER,
    faction_name_de TEXT,
    faction_name_en TEXT,
    faction_name_es TEXT,
    faction_name_fr TEXT,
    faction_name_ja TEXT,
    faction_name_ko TEXT,
    faction_name_ru TEXT,
    faction_name_zh TEXT
);

CREATE INDEX idx_dim_universe_region_id ON dim_universe (region_id);
CREATE INDEX idx_dim_universe_constellation_id ON dim_universe (constellation_id);
CREATE INDEX idx_dim_universe_security_status ON dim_universe (security_status);
CREATE INDEX idx_dim_universe_name_en ON dim_universe (solar_system_name_en);

DELETE FROM dim_universe;
INSERT INTO dim_universe (
    solar_system_id, solar_system_name_de, solar_system_name_en, solar_system_name_es, solar_system_name_fr, solar_system_name_ja, solar_system_name_ko, solar_system_name_ru, solar_system_name_zh, security_status, security_class, border, corridor, fringe, hub, international, regional, luminosity, radius, position_x, position_y, position_z, star_id, wormhole_class_id, constellation_id, constellation_name_de, constellation_name_en, constellation_name_es, constellation_name_fr, constellation_name_ja, constellation_name_ko, constellation_name_ru, constellation_name_zh, region_id, region_name_de, region_name_en, region_name_es, region_name_fr, region_name_ja, region_name_ko, region_name_ru, region_name_zh, faction_id, faction_name_de, faction_name_en, faction_name_es, faction_name_fr, faction_name_ja, faction_name_ko, faction_name_ru, faction_name_zh
)
SELECT
    s.id,
    s.name_de,
    s.name_en,
    s.name_es,
    s.name_fr,
    s.name_ja,
    s.name_ko,
    s.name_ru,
    s.name_zh,
    s.security_status,
    s.security_class,
    s.border,
    s.corridor,
    s.fringe,
    s.hub,
    s.international,
    s.regional,
    s.luminosity,
    s.radius,
    s.position_x,
    s.position_y,
    s.position_z,
    s.star_id,
    s.wormhole_class_id,
    con.id,
    con.name_de,
    con.name_en,
    con.name_es,
    con.name_fr,
    con.name_ja,
    con.name_ko,
    con.name_ru,
    con.name_zh,
    reg.id,
    reg.name_de,
    reg.name_en,
    reg.name_es,
    reg.name_fr,
    reg.name_ja,
    reg.name_ko,
    reg.name_ru,
    reg.name_zh,
    COALESCE(s.faction_id, reg.faction_id),
    f.name_de,
    f.name_en,
    f.name_es,
    f.name_fr,
    f.name_ja,
    f.name_ko,
    f.name_ru,
    f.name_zh
FROM map_solar_systems s
LEFT JOIN map_constellations con ON s.constellation_id = con.id
LEFT JOIN map_regions reg ON s.region_id = reg.id
LEFT JOIN factions f ON COALESCE(s.faction_id, reg.faction_id) = f.id;

-- Примечание: у части систем faction_id не проставлен напрямую, но известен
-- у региона (map_regions.faction_id) -- используем COALESCE, чтобы бот мог
-- сразу получить "чей это космос", не проверяя оба уровня вручную.



-- =====================================================================
-- ЧАСТЬ C. type_common_stats -- широкая таблица характеристик предметов
--
-- Сырые dogma-атрибуты (type_dogma_dogma_attributes) хранятся в формате
-- EAV (Entity-Attribute-Value): type_dogma_id, attribute_id, value.
-- Это гибко (~2100 разных атрибутов), но для конкретного вопроса
-- "сколько CPU потребляет модуль X" требует JOIN + фильтр по
-- attribute_id на таблице из ~640 тыс. строк -- медленно и неудобно
-- в коде библиотеки (нужно помнить магические числа ID атрибутов).
--
-- Курировано 67 наиболее востребованных атрибутов (отобраны по
-- частоте реального использования в SDE + доменным знаниям по фиттингу)
-- в одну строку на typeID -- получаем обычные именованные колонки
-- (cpu_usage, armor_hp, high_slots, ...). Для остальных ~2000 атрибутов,
-- не вошедших в куратированный список, raw-таблица
-- type_dogma_dogma_attributes остаётся источником истины -- ничего не теряется,
-- просто самые частые случаи вынесены в удобный вид.
--
-- Приведение типов: в SDE значения атрибутов хранятся как FLOAT
-- независимо от смысла; там, где смысл атрибута -- целое число
-- (слоты, уровни скиллов, typeID скилла), результат приводится к INTEGER.
-- =====================================================================

CREATE TABLE type_common_stats (
    type_id INTEGER PRIMARY KEY, -- = types.id
    -- attributeID=9: Structure Hitpoints
    structure_hp FLOAT,
    -- attributeID=265: Armor Hitpoints
    armor_hp FLOAT,
    -- attributeID=263: Shield Capacity
    shield_capacity FLOAT,
    -- attributeID=479: Shield recharge time
    shield_recharge_time_ms FLOAT,
    -- attributeID=113: Structure EM Damage Resistance (resonance, 1=0%)
    structure_resist_em FLOAT,
    -- attributeID=110: Structure Thermal Damage Resistance
    structure_resist_thermal FLOAT,
    -- attributeID=109: Structure Kinetic Damage Resistance
    structure_resist_kinetic FLOAT,
    -- attributeID=111: Structure Explosive Damage Resistance
    structure_resist_explosive FLOAT,
    -- attributeID=267: Armor EM Damage Resistance
    armor_resist_em FLOAT,
    -- attributeID=270: Armor Thermal Damage Resistance
    armor_resist_thermal FLOAT,
    -- attributeID=269: Armor Kinetic Damage Resistance
    armor_resist_kinetic FLOAT,
    -- attributeID=268: Armor Explosive Damage Resistance
    armor_resist_explosive FLOAT,
    -- attributeID=271: Shield EM Damage Resistance
    shield_resist_em FLOAT,
    -- attributeID=274: Shield Thermal Damage Resistance
    shield_resist_thermal FLOAT,
    -- attributeID=273: Shield Kinetic Damage Resistance
    shield_resist_kinetic FLOAT,
    -- attributeID=272: Shield Explosive Damage Resistance
    shield_resist_explosive FLOAT,
    -- attributeID=50: CPU usage (для модулей) / CPU Output (для кораблей, см. cpu_output)
    cpu_usage FLOAT,
    -- attributeID=48: CPU Output (для кораблей)
    cpu_output FLOAT,
    -- attributeID=30: Powergrid Usage (для модулей)
    powergrid_usage FLOAT,
    -- attributeID=11: Powergrid Output (для кораблей)
    powergrid_output FLOAT,
    -- attributeID=482: Capacitor Capacity
    capacitor_capacity FLOAT,
    -- attributeID=55: Capacitor Recharge time
    capacitor_recharge_time_ms FLOAT,
    -- attributeID=6: Activation Cost (расход капы за цикл)
    capacitor_need FLOAT,
    -- attributeID=192: Maximum Locked Targets
    max_locked_targets INTEGER,
    -- attributeID=76: Maximum Targeting Range
    max_target_range FLOAT,
    -- attributeID=564: Scan Resolution
    scan_resolution FLOAT,
    -- attributeID=552: Signature Radius
    signature_radius FLOAT,
    -- attributeID=208: RADAR Sensor Strength
    sensor_strength_radar FLOAT,
    -- attributeID=209: Ladar Sensor Strength
    sensor_strength_ladar FLOAT,
    -- attributeID=210: Magnetometric Sensor Strength
    sensor_strength_magnetometric FLOAT,
    -- attributeID=211: Gravimetric Sensor Strength
    sensor_strength_gravimetric FLOAT,
    -- attributeID=37: Maximum Velocity
    max_velocity FLOAT,
    -- attributeID=70: Inertia Modifier
    agility FLOAT,
    -- attributeID=1281: Ship Warp Speed
    base_warp_speed FLOAT,
    -- attributeID=14: High Slots
    high_slots INTEGER,
    -- attributeID=13: Medium Slots
    mid_slots INTEGER,
    -- attributeID=12: Low Slots
    low_slots INTEGER,
    -- attributeID=1154: Rig Slots
    rig_slots INTEGER,
    -- attributeID=101: Launcher Hardpoints
    launcher_hardpoints INTEGER,
    -- attributeID=102: Turret Hardpoints
    turret_hardpoints INTEGER,
    -- attributeID=1132: Calibration (для корабля) / Calibration cost (для рига)
    calibration FLOAT,
    -- attributeID=1547: Rig Size
    rig_size FLOAT,
    -- attributeID=283: Drone Capacity (объём ангара дронов)
    drone_bay_capacity FLOAT,
    -- attributeID=1271: Drone Bandwidth
    drone_bandwidth FLOAT,
    -- attributeID=64: Damage Modifier
    damage_multiplier FLOAT,
    -- attributeID=54: Optimal Range
    optimal_range FLOAT,
    -- attributeID=158: Accuracy falloff
    falloff FLOAT,
    -- attributeID=160: Turret Tracking
    tracking_speed FLOAT,
    -- attributeID=51: Rate of fire (для турелей/лаунчеров)
    rate_of_fire_ms FLOAT,
    -- attributeID=73: Activation time / duration (для прочих модулей)
    activation_duration_ms FLOAT,
    -- attributeID=114: EM damage
    em_damage FLOAT,
    -- attributeID=116: Explosive damage
    explosive_damage FLOAT,
    -- attributeID=117: Kinetic damage
    kinetic_damage FLOAT,
    -- attributeID=118: Thermal damage
    thermal_damage FLOAT,
    -- attributeID=128: Charge size
    charge_size INTEGER,
    -- attributeID=604: Used with (Charge Group) - FK на groups, не проставлен как constraint
    charge_group_1 INTEGER,
    -- attributeID=605: Used with (Charge Group)
    charge_group_2 INTEGER,
    -- attributeID=137: Used with (Launcher Group)
    launcher_group INTEGER,
    -- attributeID=182: Primary Skill required - FK на types
    required_skill_1_type_id INTEGER,
    -- attributeID=277
    required_skill_1_level INTEGER,
    -- attributeID=183: Secondary Skill required - FK на types
    required_skill_2_type_id INTEGER,
    -- attributeID=278
    required_skill_2_level INTEGER,
    -- attributeID=184: Tertiary Skill required - FK на types
    required_skill_3_type_id INTEGER,
    -- attributeID=279
    required_skill_3_level INTEGER,
    -- attributeID=180: Primary attribute (id характеристики персонажа)
    skill_primary_attribute INTEGER,
    -- attributeID=181: Secondary attribute
    skill_secondary_attribute INTEGER,
    -- attributeID=275: Training time multiplier
    skill_time_constant FLOAT
);

ALTER TABLE type_common_stats ADD CONSTRAINT fk_type_common_stats_type FOREIGN KEY (type_id) REFERENCES types (id);
-- ALTER TABLE type_common_stats ADD CONSTRAINT fk_type_common_stats_required_skill_1_type_id FOREIGN KEY (required_skill_1_type_id) REFERENCES types (id);
-- ALTER TABLE type_common_stats ADD CONSTRAINT fk_type_common_stats_required_skill_2_type_id FOREIGN KEY (required_skill_2_type_id) REFERENCES types (id);
-- ALTER TABLE type_common_stats ADD CONSTRAINT fk_type_common_stats_required_skill_3_type_id FOREIGN KEY (required_skill_3_type_id) REFERENCES types (id);
-- ^ FK на requiredSkill*_type_id закомментированы: значение 0 иногда
-- используется как "нет требования" и может не найтись в types (id=0 не
-- всегда существует) -- раскомментируйте, если в вашей загрузке это не так.

CREATE INDEX idx_type_common_stats_high_slots ON type_common_stats (high_slots);
CREATE INDEX idx_type_common_stats_req_skill_1 ON type_common_stats (required_skill_1_type_id);

-- Заполнение: разворачиваем EAV в колонки через агрегатный CASE WHEN --
-- стандартная ANSI-конструкция, не требует PIVOT/CROSSTAB конкретной СУБД.
DELETE FROM type_common_stats;
INSERT INTO type_common_stats (
    type_id, structure_hp, armor_hp, shield_capacity, shield_recharge_time_ms, structure_resist_em, structure_resist_thermal, structure_resist_kinetic, structure_resist_explosive, armor_resist_em, armor_resist_thermal, armor_resist_kinetic, armor_resist_explosive, shield_resist_em, shield_resist_thermal, shield_resist_kinetic, shield_resist_explosive, cpu_usage, cpu_output, powergrid_usage, powergrid_output, capacitor_capacity, capacitor_recharge_time_ms, capacitor_need, max_locked_targets, max_target_range, scan_resolution, signature_radius, sensor_strength_radar, sensor_strength_ladar, sensor_strength_magnetometric, sensor_strength_gravimetric, max_velocity, agility, base_warp_speed, high_slots, mid_slots, low_slots, rig_slots, launcher_hardpoints, turret_hardpoints, calibration, rig_size, drone_bay_capacity, drone_bandwidth, damage_multiplier, optimal_range, falloff, tracking_speed, rate_of_fire_ms, activation_duration_ms, em_damage, explosive_damage, kinetic_damage, thermal_damage, charge_size, charge_group_1, charge_group_2, launcher_group, required_skill_1_type_id, required_skill_1_level, required_skill_2_type_id, required_skill_2_level, required_skill_3_type_id, required_skill_3_level, skill_primary_attribute, skill_secondary_attribute, skill_time_constant
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
GROUP BY td.id;

-- Примечание: type_dogma.id == types.id (это подтверждённая 1:1 связь,
-- см. отчёт SDE_schema_report.md) -- typeDogma существует только для
-- типов, у которых вообще есть dogma-атрибуты (не для всех 52630 типов).



-- =====================================================================
-- ЧАСТЬ D. industry_* -- консолидация производственных таблиц чертежей
--
-- В raw-слое каждый вид активности чертежа (copying, invention,
-- manufacturing, reaction, research_material, research_time) хранится
-- в СВОЕЙ тройке таблиц (blueprints_activities_<activity>_materials/
-- _skills/_products) -- итого 18 отдельных таблиц. Чтобы получить
-- "все материалы для постройки предмета X" безотносительно вида
-- активности, нужно было бы 6 UNION ALL вручную в каждом запросе.
--
-- Здесь те же данные собраны в 4 таблицы с колонкой-дискриминатором
-- activity_type -- один понятный запрос вида
-- "SELECT * FROM industry_materials WHERE blueprint_id = ? AND
--  activity_type = 'manufacturing'" вместо похода в конкретную raw-таблицу.
-- =====================================================================

CREATE TABLE industry_activities (
    blueprint_id INTEGER,
    activity_type VARCHAR(20), -- copying|invention|manufacturing|reaction|research_material|research_time
    activity_time INTEGER, -- время выполнения активности, сек
    PRIMARY KEY (blueprint_id, activity_type)
);
ALTER TABLE industry_activities ADD CONSTRAINT fk_industry_activities_bp FOREIGN KEY (blueprint_id) REFERENCES blueprints (id);
CREATE INDEX idx_industry_activities_type ON industry_activities (activity_type);

CREATE TABLE industry_materials (
    blueprint_id INTEGER,
    activity_type VARCHAR(20),
    seq INTEGER,
    type_id INTEGER, -- материал, FK -> types
    quantity INTEGER,
    PRIMARY KEY (blueprint_id, activity_type, seq)
);
ALTER TABLE industry_materials ADD CONSTRAINT fk_industry_materials_bp FOREIGN KEY (blueprint_id) REFERENCES blueprints (id);
ALTER TABLE industry_materials ADD CONSTRAINT fk_industry_materials_type FOREIGN KEY (type_id) REFERENCES types (id);
CREATE INDEX idx_industry_materials_type_id ON industry_materials (type_id);
CREATE INDEX idx_industry_materials_activity ON industry_materials (activity_type);

CREATE TABLE industry_products (
    blueprint_id INTEGER,
    activity_type VARCHAR(20), -- invention|manufacturing|reaction (у остальных активностей продуктов нет)
    seq INTEGER,
    type_id INTEGER, -- продукт, FK -> types
    quantity INTEGER,
    probability FLOAT, -- заполнено только для invention, для остальных NULL
    PRIMARY KEY (blueprint_id, activity_type, seq)
);
ALTER TABLE industry_products ADD CONSTRAINT fk_industry_products_bp FOREIGN KEY (blueprint_id) REFERENCES blueprints (id);
ALTER TABLE industry_products ADD CONSTRAINT fk_industry_products_type FOREIGN KEY (type_id) REFERENCES types (id);
CREATE INDEX idx_industry_products_type_id ON industry_products (type_id);
CREATE INDEX idx_industry_products_activity ON industry_products (activity_type);

CREATE TABLE industry_skills (
    blueprint_id INTEGER,
    activity_type VARCHAR(20),
    seq INTEGER,
    type_id INTEGER, -- требуемый скилл, FK -> types
    level INTEGER,
    PRIMARY KEY (blueprint_id, activity_type, seq)
);
ALTER TABLE industry_skills ADD CONSTRAINT fk_industry_skills_bp FOREIGN KEY (blueprint_id) REFERENCES blueprints (id);
ALTER TABLE industry_skills ADD CONSTRAINT fk_industry_skills_type FOREIGN KEY (type_id) REFERENCES types (id);
CREATE INDEX idx_industry_skills_type_id ON industry_skills (type_id);

-- ---- Заполнение ----
DELETE FROM industry_activities;
INSERT INTO industry_activities (blueprint_id, activity_type, activity_time)
SELECT id, 'copying', activities_copying_time FROM blueprints WHERE activities_copying_time IS NOT NULL
UNION ALL
SELECT id, 'invention', activities_invention_time FROM blueprints WHERE activities_invention_time IS NOT NULL
UNION ALL
SELECT id, 'manufacturing', activities_manufacturing_time FROM blueprints WHERE activities_manufacturing_time IS NOT NULL
UNION ALL
SELECT id, 'reaction', activities_reaction_time FROM blueprints WHERE activities_reaction_time IS NOT NULL
UNION ALL
SELECT id, 'research_material', activities_research_material_time FROM blueprints WHERE activities_research_material_time IS NOT NULL
UNION ALL
SELECT id, 'research_time', activities_research_time_time FROM blueprints WHERE activities_research_time_time IS NOT NULL;

DELETE FROM industry_materials;
INSERT INTO industry_materials (blueprint_id, activity_type, seq, type_id, quantity)
SELECT blueprints_id, 'copying', seq, type_id, quantity FROM blueprints_activities_copying_materials
UNION ALL
SELECT blueprints_id, 'invention', seq, type_id, quantity FROM blueprints_activities_invention_materials
UNION ALL
SELECT blueprints_id, 'manufacturing', seq, type_id, quantity FROM blueprints_activities_manufacturing_materials
UNION ALL
SELECT blueprints_id, 'reaction', seq, type_id, quantity FROM blueprints_activities_reaction_materials
UNION ALL
SELECT blueprints_id, 'research_material', seq, type_id, quantity FROM blueprints_activities_research_material_materials
UNION ALL
SELECT blueprints_id, 'research_time', seq, type_id, quantity FROM blueprints_activities_research_time_materials;

DELETE FROM industry_products;
INSERT INTO industry_products (blueprint_id, activity_type, seq, type_id, quantity, probability)
SELECT blueprints_id, 'invention', seq, type_id, quantity, probability FROM blueprints_activities_invention_products
UNION ALL
SELECT blueprints_id, 'manufacturing', seq, type_id, quantity, CAST(NULL AS FLOAT) FROM blueprints_activities_manufacturing_products
UNION ALL
SELECT blueprints_id, 'reaction', seq, type_id, quantity, CAST(NULL AS FLOAT) FROM blueprints_activities_reaction_products;

DELETE FROM industry_skills;
INSERT INTO industry_skills (blueprint_id, activity_type, seq, type_id, level)
SELECT blueprints_id, 'copying', seq, type_id, level FROM blueprints_activities_copying_skills
UNION ALL
SELECT blueprints_id, 'invention', seq, type_id, level FROM blueprints_activities_invention_skills
UNION ALL
SELECT blueprints_id, 'manufacturing', seq, type_id, level FROM blueprints_activities_manufacturing_skills
UNION ALL
SELECT blueprints_id, 'reaction', seq, type_id, level FROM blueprints_activities_reaction_skills
UNION ALL
SELECT blueprints_id, 'research_material', seq, type_id, level FROM blueprints_activities_research_material_skills
UNION ALL
SELECT blueprints_id, 'research_time', seq, type_id, level FROM blueprints_activities_research_time_skills;



-- =====================================================================
-- ЧАСТЬ E. dim_agents -- денормализованная витрина по агентам NPC
--
-- npc_characters содержит вообще всех именованных NPC (не только
-- агентов миссий) -- поля agent_* (agent_agent_type_id и т.д.) заполнены
-- только у тех, кто реально является агентом. Фильтруем по
-- agent_agent_type_id IS NOT NULL и подтягиваем корпорацию, тип агента,
-- отдел (division), систему/регион расположения станции -- типичный
-- запрос "какие агенты уровня 4+ есть в этом регионе" иначе требует
-- 5 JOIN'ов (npc_characters -> npc_corporations -> ... , npc_characters
-- -> npc_stations -> map_solar_systems -> map_regions).
-- =====================================================================

CREATE TABLE dim_agents (
    agent_id INTEGER PRIMARY KEY, -- = npc_characters.id
    agent_name_de TEXT,
    agent_name_en TEXT,
    agent_name_es TEXT,
    agent_name_fr TEXT,
    agent_name_ja TEXT,
    agent_name_ko TEXT,
    agent_name_ru TEXT,
    agent_name_zh TEXT,
    agent_level INTEGER,
    agent_is_locator BOOLEAN,
    agent_type_id INTEGER,
    agent_type_name VARCHAR(500), -- в agent_types имя не локализовано (одна строка)
    division_id INTEGER,
    division_name_de TEXT,
    division_name_en TEXT,
    division_name_es TEXT,
    division_name_fr TEXT,
    division_name_ja TEXT,
    division_name_ko TEXT,
    division_name_ru TEXT,
    division_name_zh TEXT,
    race_id INTEGER,
    race_name_de TEXT,
    race_name_en TEXT,
    race_name_es TEXT,
    race_name_fr TEXT,
    race_name_ja TEXT,
    race_name_ko TEXT,
    race_name_ru TEXT,
    race_name_zh TEXT,
    bloodline_id INTEGER,
    bloodline_name_de TEXT,
    bloodline_name_en TEXT,
    bloodline_name_es TEXT,
    bloodline_name_fr TEXT,
    bloodline_name_ja TEXT,
    bloodline_name_ko TEXT,
    bloodline_name_ru TEXT,
    bloodline_name_zh TEXT,
    -- корпорация
    corporation_id INTEGER,
    corporation_name_de TEXT,
    corporation_name_en TEXT,
    corporation_name_es TEXT,
    corporation_name_fr TEXT,
    corporation_name_ja TEXT,
    corporation_name_ko TEXT,
    corporation_name_ru TEXT,
    corporation_name_zh TEXT,
    corporation_ticker VARCHAR(50),
    -- фракция корпорации
    faction_id INTEGER,
    faction_name_de TEXT,
    faction_name_en TEXT,
    faction_name_es TEXT,
    faction_name_fr TEXT,
    faction_name_ja TEXT,
    faction_name_ko TEXT,
    faction_name_ru TEXT,
    faction_name_zh TEXT,
    -- расположение (station -> solar system -> region)
    station_id INTEGER, -- = npc_characters.location_id (подтверждено, совпадение 99.98%)
    solar_system_id INTEGER,
    solar_system_name_de TEXT,
    solar_system_name_en TEXT,
    solar_system_name_es TEXT,
    solar_system_name_fr TEXT,
    solar_system_name_ja TEXT,
    solar_system_name_ko TEXT,
    solar_system_name_ru TEXT,
    solar_system_name_zh TEXT,
    region_id INTEGER,
    region_name_de TEXT,
    region_name_en TEXT,
    region_name_es TEXT,
    region_name_fr TEXT,
    region_name_ja TEXT,
    region_name_ko TEXT,
    region_name_ru TEXT,
    region_name_zh TEXT,
    security_status FLOAT
);

CREATE INDEX idx_dim_agents_corporation_id ON dim_agents (corporation_id);
CREATE INDEX idx_dim_agents_solar_system_id ON dim_agents (solar_system_id);
CREATE INDEX idx_dim_agents_region_id ON dim_agents (region_id);
CREATE INDEX idx_dim_agents_agent_level ON dim_agents (agent_level);
CREATE INDEX idx_dim_agents_agent_type_id ON dim_agents (agent_type_id);

DELETE FROM dim_agents;
INSERT INTO dim_agents (
    agent_id, agent_name_de, agent_name_en, agent_name_es, agent_name_fr, agent_name_ja, agent_name_ko, agent_name_ru, agent_name_zh, agent_level, agent_is_locator, agent_type_id, agent_type_name, division_id, division_name_de, division_name_en, division_name_es, division_name_fr, division_name_ja, division_name_ko, division_name_ru, division_name_zh, race_id, race_name_de, race_name_en, race_name_es, race_name_fr, race_name_ja, race_name_ko, race_name_ru, race_name_zh, bloodline_id, bloodline_name_de, bloodline_name_en, bloodline_name_es, bloodline_name_fr, bloodline_name_ja, bloodline_name_ko, bloodline_name_ru, bloodline_name_zh, corporation_id, corporation_name_de, corporation_name_en, corporation_name_es, corporation_name_fr, corporation_name_ja, corporation_name_ko, corporation_name_ru, corporation_name_zh, corporation_ticker, faction_id, faction_name_de, faction_name_en, faction_name_es, faction_name_fr, faction_name_ja, faction_name_ko, faction_name_ru, faction_name_zh, station_id, solar_system_id, solar_system_name_de, solar_system_name_en, solar_system_name_es, solar_system_name_fr, solar_system_name_ja, solar_system_name_ko, solar_system_name_ru, solar_system_name_zh, region_id, region_name_de, region_name_en, region_name_es, region_name_fr, region_name_ja, region_name_ko, region_name_ru, region_name_zh, security_status
)
SELECT
    c.id,
    c.name_de,
    c.name_en,
    c.name_es,
    c.name_fr,
    c.name_ja,
    c.name_ko,
    c.name_ru,
    c.name_zh,
    c.agent_level,
    c.agent_is_locator,
    c.agent_agent_type_id,
    at.name,
    c.agent_division_id,
    div.name_de,
    div.name_en,
    div.name_es,
    div.name_fr,
    div.name_ja,
    div.name_ko,
    div.name_ru,
    div.name_zh,
    c.race_id,
    r.name_de,
    r.name_en,
    r.name_es,
    r.name_fr,
    r.name_ja,
    r.name_ko,
    r.name_ru,
    r.name_zh,
    c.bloodline_id,
    bl.name_de,
    bl.name_en,
    bl.name_es,
    bl.name_fr,
    bl.name_ja,
    bl.name_ko,
    bl.name_ru,
    bl.name_zh,
    c.corporation_id,
    corp.name_de,
    corp.name_en,
    corp.name_es,
    corp.name_fr,
    corp.name_ja,
    corp.name_ko,
    corp.name_ru,
    corp.name_zh,
    corp.ticker_name,
    corp.faction_id,
    f.name_de,
    f.name_en,
    f.name_es,
    f.name_fr,
    f.name_ja,
    f.name_ko,
    f.name_ru,
    f.name_zh,
    c.location_id,
    st.solar_system_id,
    sys.name_de,
    sys.name_en,
    sys.name_es,
    sys.name_fr,
    sys.name_ja,
    sys.name_ko,
    sys.name_ru,
    sys.name_zh,
    sys.region_id,
    reg.name_de,
    reg.name_en,
    reg.name_es,
    reg.name_fr,
    reg.name_ja,
    reg.name_ko,
    reg.name_ru,
    reg.name_zh,
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
WHERE c.agent_agent_type_id IS NOT NULL;


