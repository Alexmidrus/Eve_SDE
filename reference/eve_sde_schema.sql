-- CHANGELOG 2026-07-09 (ревизия схемы):
--   * Исправлены висячие запятые в CREATE TABLE dim_items / dim_universe.
--   * 9 промежуточным таблицам с дочерними таблицами (epic_arcs_missions,
--     masteries_value, type_bonus_types и др.) добавлен суррогатный PK id
--     (присваивается ETL); натуральный ключ (parent_id, seq) сохранён как UNIQUE.
--     Это чинит 12 FK, ссылавшихся на несуществующую колонку id.
--   * Удалены 95 избыточных индексов, дублировавших префикс PK/UNIQUE.
-- =====================================================================
-- EVE Online SDE (Static Data Export) -- универсальная схема БД
-- Сгенерировано из SDE_schema_report.md (анализ 79 JSONL-файлов SDE)
--
-- Принцип построения:
--   * Каждый исходный .jsonl файл -> одна "корневая" таблица (raw, без
--     нормализации справочников).
--   * Каждый вложенный массив (array) в исходном JSON -> отдельная дочерняя
--     таблица с составным первичным ключом (<родитель>_id, seq), где seq --
--     порядковая позиция элемента в исходном массиве (0-based).
--   * Вложенные объекты (не массивы, напр. position{x,y,z}) выравнены
--     (flatten) в колонки родительской таблицы: position_x, position_y, ...
--   * Локализованные строки (object<lang> из SDE: de/en/es/fr/ja/ko/ru/zh)
--     разложены в 8 колонок: <поле>_de, <поле>_en, ... <поле>_zh.
--   * Внешние ключи (FOREIGN KEY) вынесены в отдельный блок ALTER TABLE
--     в конце скрипта -- это позволяет избежать проблем с порядком
--     создания таблиц при наличии циклических связей (напр.
--     npc_corporations <-> npc_characters, types <-> factions <-> npc_corporations).
--   * Столбцы, которые по имени похожи на внешний ключ, но НЕ являются им
--     (проверено сверкой реальных данных, см. отчёт), оставлены как обычные
--     колонки с поясняющим комментарием -- FK-ограничение для них не создаётся.
--   * Поля со смешанной/неоднозначной целью (могут ссылаться на разные
--     таблицы в зависимости от записи) также оставлены без жёсткого FK,
--     но с комментарием, поясняющим обе возможные цели.
--
-- Совместимость (максимально широкая, без вендор-специфичных расширений):
--   * Типы данных ограничены множеством: INTEGER, FLOAT, VARCHAR(n), TEXT,
--     BOOLEAN -- все они понимаются MySQL, PostgreSQL, SQL Server, Oracle,
--     SQLite (с точностью до внутреннего маппинга типа, см. ниже).
--   * Идентификаторы -- только snake_case без зарезервированных слов,
--     кавычки/бэктики для идентификаторов не используются (не нужны).
--   * Автоинкремент/SERIAL/IDENTITY НЕ используются -- первичные ключи
--     "корневых" таблиц берутся из натурального ключа `_key` исходных
--     данных (сохранена семантика 1 файл = 1 таблица), а дочерние
--     таблицы используют составной ключ (parent_id, seq) без суррогатов.
--   * Внешние ключи вынесены в ALTER TABLE ... ADD CONSTRAINT (стандартный
--     ANSI SQL синтаксис, поддерживается всеми перечисленными СУБД).
--
-- Особенности типов по СУБД при фактическом развёртывании:
--   * BOOLEAN  -> MySQL/PostgreSQL: BOOLEAN нативно; SQL Server: BIT;
--                 Oracle: NUMBER(1); SQLite: принимает как есть (affinity).
--   * FLOAT    -> все перечисленные СУБД поддерживают ключевое слово FLOAT.
--   * TEXT     -> MySQL/PostgreSQL/SQLite: TEXT нативно; SQL Server: используйте
--                 NVARCHAR(MAX); Oracle: используйте CLOB.
--   * VARCHAR(n) -> поддерживается везде без изменений.
--
-- Импорт в dbdesigner.net: Schema -> Import, выбрать диалект "MySQL" или
-- "PostgreSQL" (наиболее строго ANSI-совместимые из предлагаемых опций) --
-- скрипт не использует конструкций, специфичных для конкретной СУБД.
-- =====================================================================


-- =====================================================================
-- 1. СОЗДАНИЕ ТАБЛИЦ (174 шт.: корневые + дочерние из вложенных массивов)
-- =====================================================================

CREATE TABLE sde (
    -- raw source: _sde.jsonl _key
    id VARCHAR(128),
    build_number INTEGER,
    release_date VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE agent_types (
    -- raw source: agentTypes.jsonl _key
    id INTEGER,
    name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE agents_in_space (
    -- raw source: agentsInSpace.jsonl _key
    id INTEGER,
    -- 0% совпадения с dungeons._key (0/169) — вероятно ссылается на ID динамического инстанса подземелья, которого нет в статичном SDE
    dungeon_id INTEGER,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    spawn_point_id INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE ancestries (
    -- raw source: ancestries.jsonl _key
    id INTEGER,
    -- FK -> bloodlines (подтверждено, совпадение 100%)
    bloodline_id INTEGER,
    charisma INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    intelligence INTEGER,
    memory INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    perception INTEGER,
    short_description TEXT,
    willpower INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE archetypes (
    -- raw source: archetypes.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    title_de TEXT,
    title_en TEXT,
    title_es TEXT,
    title_fr TEXT,
    title_ja TEXT,
    title_ko TEXT,
    title_ru TEXT,
    title_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE bloodlines (
    -- raw source: bloodlines.jsonl _key
    id INTEGER,
    charisma INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%)
    corporation_id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    intelligence INTEGER,
    memory INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    perception INTEGER,
    -- FK -> races (подтверждено, совпадение 100%)
    race_id INTEGER,
    willpower INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE blueprints (
    -- raw source: blueprints.jsonl _key
    id INTEGER,
    activities_copying_time INTEGER,
    activities_invention_time INTEGER,
    activities_manufacturing_time INTEGER,
    activities_reaction_time INTEGER,
    activities_research_material_time INTEGER,
    activities_research_time_time INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    blueprint_type_id INTEGER,
    max_production_limit INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE blueprints_activities_copying_materials (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 99.9%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_copying_skills (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    level INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_invention_materials (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 99.9%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_invention_products (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    probability FLOAT,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 99.7%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_invention_skills (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    level INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_manufacturing_materials (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 99.9%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_manufacturing_products (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 99.7%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_manufacturing_skills (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    level INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_reaction_materials (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 99.9%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_reaction_products (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 99.7%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_reaction_skills (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    level INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_research_material_materials (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 99.9%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_research_material_skills (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    level INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_research_time_materials (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 99.9%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE blueprints_activities_research_time_skills (
    blueprints_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    level INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (blueprints_id, seq)
);

CREATE TABLE categories (
    -- raw source: categories.jsonl _key
    id INTEGER,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    published BOOLEAN,
    PRIMARY KEY (id)
);

CREATE TABLE certificates (
    -- raw source: certificates.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    -- FK -> groups (подтверждено, совпадение 100%); неоднозначно: возможно свой домен группировки сертификатов
    group_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE certificates_recommended_for (
    certificates_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value INTEGER,
    PRIMARY KEY (certificates_id, seq)
);

CREATE TABLE certificates_skill_types (
    certificates_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    source_key INTEGER,
    advanced INTEGER,
    basic INTEGER,
    elite INTEGER,
    improved INTEGER,
    standard INTEGER,
    PRIMARY KEY (certificates_id, seq)
);

CREATE TABLE character_attributes (
    -- raw source: characterAttributes.jsonl _key
    id INTEGER,
    description TEXT,
    icon_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    notes TEXT,
    short_description TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE character_titles (
    -- raw source: characterTitles.jsonl _key
    id VARCHAR(128),
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE clone_grades (
    -- raw source: cloneGrades.jsonl _key
    id INTEGER,
    name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE clone_grades_skills (
    clone_grades_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    level INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (clone_grades_id, seq)
);

CREATE TABLE compressible_types (
    -- raw source: compressibleTypes.jsonl _key
    id INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    compressed_type_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE contraband_types (
    -- raw source: contrabandTypes.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE contraband_types_factions (
    contraband_types_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> factions (подтверждено, совпадение 100%)
    source_key INTEGER,
    attack_min_sec FLOAT,
    confiscate_min_sec FLOAT,
    fine_by_value FLOAT,
    standing_loss FLOAT,
    PRIMARY KEY (contraband_types_id, seq)
);

CREATE TABLE control_tower_resources (
    -- raw source: controlTowerResources.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE control_tower_resources_resources (
    control_tower_resources_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> factions (подтверждено, совпадение 100%)
    faction_id INTEGER,
    min_security_level FLOAT,
    purpose INTEGER,
    quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    resource_type_id INTEGER,
    PRIMARY KEY (control_tower_resources_id, seq)
);

CREATE TABLE corporation_activities (
    -- raw source: corporationActivities.jsonl _key
    id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE dbuff_collections (
    -- raw source: dbuffCollections.jsonl _key
    id INTEGER,
    aggregate_mode VARCHAR(500),
    developer_description TEXT,
    display_name_de TEXT,
    display_name_en TEXT,
    display_name_es TEXT,
    display_name_fr TEXT,
    display_name_ja TEXT,
    display_name_ko TEXT,
    display_name_ru TEXT,
    display_name_zh TEXT,
    operation_name VARCHAR(500),
    show_output_value_in_ui VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE dbuff_collections_item_modifiers (
    dbuff_collections_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    dogma_attribute_id INTEGER,
    PRIMARY KEY (dbuff_collections_id, seq)
);

CREATE TABLE dbuff_collections_location_group_modifiers (
    dbuff_collections_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    dogma_attribute_id INTEGER,
    -- FK -> groups (подтверждено, совпадение 100%)
    group_id INTEGER,
    PRIMARY KEY (dbuff_collections_id, seq)
);

CREATE TABLE dbuff_collections_location_modifiers (
    dbuff_collections_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    dogma_attribute_id INTEGER,
    PRIMARY KEY (dbuff_collections_id, seq)
);

CREATE TABLE dbuff_collections_location_required_skill_modifiers (
    dbuff_collections_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    dogma_attribute_id INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    skill_id INTEGER,
    PRIMARY KEY (dbuff_collections_id, seq)
);

CREATE TABLE dogma_attribute_categories (
    -- raw source: dogmaAttributeCategories.jsonl _key
    id INTEGER,
    description TEXT,
    name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE dogma_attributes (
    -- raw source: dogmaAttributes.jsonl _key
    id INTEGER,
    -- FK -> dogmaAttributeCategories (подтверждено, совпадение 100%)
    attribute_category_id INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%); самоссылка
    charge_recharge_time_id INTEGER,
    data_type INTEGER,
    default_value FLOAT,
    description TEXT,
    display_name_de TEXT,
    display_name_en TEXT,
    display_name_es TEXT,
    display_name_fr TEXT,
    display_name_ja TEXT,
    display_name_ko TEXT,
    display_name_ru TEXT,
    display_name_zh TEXT,
    display_when_zero BOOLEAN,
    high_is_good BOOLEAN,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%); самоссылка
    max_attribute_id INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%); самоссылка
    min_attribute_id INTEGER,
    name VARCHAR(500),
    published BOOLEAN,
    stackable BOOLEAN,
    tooltip_description_de TEXT,
    tooltip_description_en TEXT,
    tooltip_description_es TEXT,
    tooltip_description_fr TEXT,
    tooltip_description_ja TEXT,
    tooltip_description_ko TEXT,
    tooltip_description_ru TEXT,
    tooltip_description_zh TEXT,
    tooltip_title_de TEXT,
    tooltip_title_en TEXT,
    tooltip_title_es TEXT,
    tooltip_title_fr TEXT,
    tooltip_title_ja TEXT,
    tooltip_title_ko TEXT,
    tooltip_title_ru TEXT,
    tooltip_title_zh TEXT,
    -- FK -> dogmaUnits (подтверждено, совпадение 100%)
    unit_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE dogma_effects (
    -- raw source: dogmaEffects.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    disallow_auto_repeat BOOLEAN,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    discharge_attribute_id INTEGER,
    display_name_de TEXT,
    display_name_en TEXT,
    display_name_es TEXT,
    display_name_fr TEXT,
    display_name_ja TEXT,
    display_name_ko TEXT,
    display_name_ru TEXT,
    display_name_zh TEXT,
    distribution INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    duration_attribute_id INTEGER,
    effect_category_id INTEGER,
    electronic_chance BOOLEAN,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    falloff_attribute_id INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    fitting_usage_chance_attribute_id INTEGER,
    guid VARCHAR(500),
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    is_assistance BOOLEAN,
    is_offensive BOOLEAN,
    is_warp_safe BOOLEAN,
    name VARCHAR(500),
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    npc_activation_chance_attribute_id INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    npc_usage_chance_attribute_id INTEGER,
    propulsion_chance BOOLEAN,
    published BOOLEAN,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    range_attribute_id INTEGER,
    range_chance BOOLEAN,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    resistance_attribute_id INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    tracking_speed_attribute_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE dogma_effects_modifier_info (
    dogma_effects_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    domain VARCHAR(500),
    -- FK -> dogmaEffects (подтверждено, совпадение 100%); самоссылка
    effect_id INTEGER,
    func VARCHAR(500),
    -- FK -> groups (подтверждено, совпадение 100%)
    group_id INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    modified_attribute_id INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    modifying_attribute_id INTEGER,
    operation INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    skill_type_id INTEGER,
    PRIMARY KEY (dogma_effects_id, seq)
);

CREATE TABLE dogma_units (
    -- raw source: dogmaUnits.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    display_name_de TEXT,
    display_name_en TEXT,
    display_name_es TEXT,
    display_name_fr TEXT,
    display_name_ja TEXT,
    display_name_ko TEXT,
    display_name_ru TEXT,
    display_name_zh TEXT,
    name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE dungeons (
    -- raw source: dungeons.jsonl _key
    id INTEGER,
    -- FK -> archetypes (подтверждено, совпадение 100%)
    archetype_id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    -- FK -> factions (подтверждено, совпадение 100%)
    faction_id INTEGER,
    gameplay_description_de TEXT,
    gameplay_description_en TEXT,
    gameplay_description_es TEXT,
    gameplay_description_fr TEXT,
    gameplay_description_ja TEXT,
    gameplay_description_ko TEXT,
    gameplay_description_ru TEXT,
    gameplay_description_zh TEXT,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE dungeons_allowed_ships_list (
    dungeons_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- СМЕШАННАЯ ссылка на неск. таблиц: groups, types (без единого FK-constraint) — смешанный список: элемент может быть либо groupID (группа кораблей), либо конкретный typeID корабля
    value INTEGER,
    PRIMARY KEY (dungeons_id, seq)
);

CREATE TABLE dynamic_item_attributes (
    -- raw source: dynamicItemAttributes.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE dynamic_item_attributes_attribute_ids (
    dynamic_item_attributes_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    source_key INTEGER,
    high_is_good BOOLEAN,
    max FLOAT,
    min FLOAT,
    PRIMARY KEY (dynamic_item_attributes_id, seq)
);

CREATE TABLE dynamic_item_attributes_input_output_mapping (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке);
    -- нужен, т.к. на эту таблицу ссылаются дочерние таблицы (FK одной колонкой)
    id INTEGER,
    dynamic_item_attributes_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    resulting_type INTEGER,
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (dynamic_item_attributes_id, seq)
);

CREATE TABLE dynamic_item_attributes_input_output_mapping_applicab_543eea (
    dynamic_item_attributes_input_output_mapping_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (dynamic_item_attributes_input_output_mapping_id, seq)
);

CREATE TABLE epic_arcs (
    -- raw source: epicArcs.jsonl _key
    id INTEGER,
    arc_restart_interval INTEGER,
    -- FK -> factions (подтверждено, совпадение 100%)
    faction_id INTEGER,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE epic_arcs_missions (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке);
    -- нужен, т.к. на эту таблицу ссылаются дочерние таблицы (FK одной колонкой)
    id INTEGER,
    epic_arcs_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    source_key INTEGER,
    -- FK -> npcCharacters (подтверждено, совпадение 100%)
    agent_id INTEGER,
    fail_mission_id INTEGER,
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (epic_arcs_id, seq)
);

CREATE TABLE epic_arcs_missions_next_missions (
    epic_arcs_missions_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value INTEGER,
    PRIMARY KEY (epic_arcs_missions_id, seq)
);

CREATE TABLE factions (
    -- raw source: factions.jsonl _key
    id INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%)
    corporation_id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    flat_logo VARCHAR(500),
    flat_logo_with_name VARCHAR(500),
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%)
    militia_corporation_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    short_description_de TEXT,
    short_description_en TEXT,
    short_description_es TEXT,
    short_description_fr TEXT,
    short_description_ja TEXT,
    short_description_ko TEXT,
    short_description_ru TEXT,
    short_description_zh TEXT,
    size_factor FLOAT,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    unique_name BOOLEAN,
    PRIMARY KEY (id)
);

CREATE TABLE factions_member_races (
    factions_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> races (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (factions_id, seq)
);

CREATE TABLE freelance_job_schemas (
    -- raw source: freelanceJobSchemas.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE freelance_job_schemas_value (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке);
    -- нужен, т.к. на эту таблицу ссылаются дочерние таблицы (FK одной колонкой)
    id INTEGER,
    freelance_job_schemas_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    source_key VARCHAR(500),
    contribution_multiplier_default_value INTEGER,
    contribution_multiplier_description_de TEXT,
    contribution_multiplier_description_en TEXT,
    contribution_multiplier_description_es TEXT,
    contribution_multiplier_description_fr TEXT,
    contribution_multiplier_description_ja TEXT,
    contribution_multiplier_description_ko TEXT,
    contribution_multiplier_description_ru TEXT,
    contribution_multiplier_description_zh TEXT,
    contribution_multiplier_icon_id VARCHAR(500),
    contribution_multiplier_max_value INTEGER,
    contribution_multiplier_min_value FLOAT,
    contribution_multiplier_title_de TEXT,
    contribution_multiplier_title_en TEXT,
    contribution_multiplier_title_es TEXT,
    contribution_multiplier_title_fr TEXT,
    contribution_multiplier_title_ja TEXT,
    contribution_multiplier_title_ko TEXT,
    contribution_multiplier_title_ru TEXT,
    contribution_multiplier_title_zh TEXT,
    contribution_multiplier_unset_description_de TEXT,
    contribution_multiplier_unset_description_en TEXT,
    contribution_multiplier_unset_description_es TEXT,
    contribution_multiplier_unset_description_fr TEXT,
    contribution_multiplier_unset_description_ja TEXT,
    contribution_multiplier_unset_description_ko TEXT,
    contribution_multiplier_unset_description_ru TEXT,
    contribution_multiplier_unset_description_zh TEXT,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    icon_id VARCHAR(500),
    max_contributions_per_participant_description_de TEXT,
    max_contributions_per_participant_description_en TEXT,
    max_contributions_per_participant_description_es TEXT,
    max_contributions_per_participant_description_fr TEXT,
    max_contributions_per_participant_description_ja TEXT,
    max_contributions_per_participant_description_ko TEXT,
    max_contributions_per_participant_description_ru TEXT,
    max_contributions_per_participant_description_zh TEXT,
    max_contributions_per_participant_icon_id VARCHAR(500),
    max_contributions_per_participant_title_de TEXT,
    max_contributions_per_participant_title_en TEXT,
    max_contributions_per_participant_title_es TEXT,
    max_contributions_per_participant_title_fr TEXT,
    max_contributions_per_participant_title_ja TEXT,
    max_contributions_per_participant_title_ko TEXT,
    max_contributions_per_participant_title_ru TEXT,
    max_contributions_per_participant_title_zh TEXT,
    max_contributions_per_participant_unset_description_de TEXT,
    max_contributions_per_participant_unset_description_en TEXT,
    max_contributions_per_participant_unset_description_es TEXT,
    max_contributions_per_participant_unset_description_fr TEXT,
    max_contributions_per_participant_unset_description_ja TEXT,
    max_contributions_per_participant_unset_description_ko TEXT,
    max_contributions_per_participant_unset_description_ru TEXT,
    max_contributions_per_participant_unset_description_zh TEXT,
    max_progress_per_contribution_description_de TEXT,
    max_progress_per_contribution_description_en TEXT,
    max_progress_per_contribution_description_es TEXT,
    max_progress_per_contribution_description_fr TEXT,
    max_progress_per_contribution_description_ja TEXT,
    max_progress_per_contribution_description_ko TEXT,
    max_progress_per_contribution_description_ru TEXT,
    max_progress_per_contribution_description_zh TEXT,
    max_progress_per_contribution_icon_id VARCHAR(500),
    max_progress_per_contribution_title_de TEXT,
    max_progress_per_contribution_title_en TEXT,
    max_progress_per_contribution_title_es TEXT,
    max_progress_per_contribution_title_fr TEXT,
    max_progress_per_contribution_title_ja TEXT,
    max_progress_per_contribution_title_ko TEXT,
    max_progress_per_contribution_title_ru TEXT,
    max_progress_per_contribution_title_zh TEXT,
    max_progress_per_contribution_unset_description_de TEXT,
    max_progress_per_contribution_unset_description_en TEXT,
    max_progress_per_contribution_unset_description_es TEXT,
    max_progress_per_contribution_unset_description_fr TEXT,
    max_progress_per_contribution_unset_description_ja TEXT,
    max_progress_per_contribution_unset_description_ko TEXT,
    max_progress_per_contribution_unset_description_ru TEXT,
    max_progress_per_contribution_unset_description_zh TEXT,
    progress_description_de TEXT,
    progress_description_en TEXT,
    progress_description_es TEXT,
    progress_description_fr TEXT,
    progress_description_ja TEXT,
    progress_description_ko TEXT,
    progress_description_ru TEXT,
    progress_description_zh TEXT,
    reward_description_de TEXT,
    reward_description_en TEXT,
    reward_description_es TEXT,
    reward_description_fr TEXT,
    reward_description_ja TEXT,
    reward_description_ko TEXT,
    reward_description_ru TEXT,
    reward_description_zh TEXT,
    target_description_de TEXT,
    target_description_en TEXT,
    target_description_es TEXT,
    target_description_fr TEXT,
    target_description_ja TEXT,
    target_description_ko TEXT,
    target_description_ru TEXT,
    target_description_zh TEXT,
    title_de TEXT,
    title_en TEXT,
    title_es TEXT,
    title_fr TEXT,
    title_ja TEXT,
    title_ko TEXT,
    title_ru TEXT,
    title_zh TEXT,
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (freelance_job_schemas_id, seq)
);

CREATE TABLE freelance_job_schemas_value_content_tags (
    freelance_job_schemas_value_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value VARCHAR(500),
    PRIMARY KEY (freelance_job_schemas_value_id, seq)
);

CREATE TABLE freelance_job_schemas_value_parameters (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке);
    -- нужен, т.к. на эту таблицу ссылаются дочерние таблицы (FK одной колонкой)
    id INTEGER,
    freelance_job_schemas_value_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    source_key VARCHAR(500),
    boolean_choice_label_de TEXT,
    boolean_choice_label_en TEXT,
    boolean_choice_label_es TEXT,
    boolean_choice_label_fr TEXT,
    boolean_choice_label_ja TEXT,
    boolean_choice_label_ko TEXT,
    boolean_choice_label_ru TEXT,
    boolean_choice_label_zh TEXT,
    boolean_default BOOLEAN,
    boolean_description_de TEXT,
    boolean_description_en TEXT,
    boolean_description_es TEXT,
    boolean_description_fr TEXT,
    boolean_description_ja TEXT,
    boolean_description_ko TEXT,
    boolean_description_ru TEXT,
    boolean_description_zh TEXT,
    boolean_icon_id VARCHAR(500),
    boolean_option_false_description_de TEXT,
    boolean_option_false_description_en TEXT,
    boolean_option_false_description_es TEXT,
    boolean_option_false_description_fr TEXT,
    boolean_option_false_description_ja TEXT,
    boolean_option_false_description_ko TEXT,
    boolean_option_false_description_ru TEXT,
    boolean_option_false_description_zh TEXT,
    boolean_option_false_title_de TEXT,
    boolean_option_false_title_en TEXT,
    boolean_option_false_title_es TEXT,
    boolean_option_false_title_fr TEXT,
    boolean_option_false_title_ja TEXT,
    boolean_option_false_title_ko TEXT,
    boolean_option_false_title_ru TEXT,
    boolean_option_false_title_zh TEXT,
    boolean_option_true_description_de TEXT,
    boolean_option_true_description_en TEXT,
    boolean_option_true_description_es TEXT,
    boolean_option_true_description_fr TEXT,
    boolean_option_true_description_ja TEXT,
    boolean_option_true_description_ko TEXT,
    boolean_option_true_description_ru TEXT,
    boolean_option_true_description_zh TEXT,
    boolean_option_true_title_de TEXT,
    boolean_option_true_title_en TEXT,
    boolean_option_true_title_es TEXT,
    boolean_option_true_title_fr TEXT,
    boolean_option_true_title_ja TEXT,
    boolean_option_true_title_ko TEXT,
    boolean_option_true_title_ru TEXT,
    boolean_option_true_title_zh TEXT,
    boolean_title_de TEXT,
    boolean_title_en TEXT,
    boolean_title_es TEXT,
    boolean_title_fr TEXT,
    boolean_title_ja TEXT,
    boolean_title_ko TEXT,
    boolean_title_ru TEXT,
    boolean_title_zh TEXT,
    item_delivery_delivery_location_description_de TEXT,
    item_delivery_delivery_location_description_en TEXT,
    item_delivery_delivery_location_description_es TEXT,
    item_delivery_delivery_location_description_fr TEXT,
    item_delivery_delivery_location_description_ja TEXT,
    item_delivery_delivery_location_description_ko TEXT,
    item_delivery_delivery_location_description_ru TEXT,
    item_delivery_delivery_location_description_zh TEXT,
    item_delivery_delivery_location_icon_id VARCHAR(500),
    item_delivery_delivery_location_max_entries INTEGER,
    item_delivery_delivery_location_title_de TEXT,
    item_delivery_delivery_location_title_en TEXT,
    item_delivery_delivery_location_title_es TEXT,
    item_delivery_delivery_location_title_fr TEXT,
    item_delivery_delivery_location_title_ja TEXT,
    item_delivery_delivery_location_title_ko TEXT,
    item_delivery_delivery_location_title_ru TEXT,
    item_delivery_delivery_location_title_zh TEXT,
    item_delivery_delivery_location_unset_description_de TEXT,
    item_delivery_delivery_location_unset_description_en TEXT,
    item_delivery_delivery_location_unset_description_es TEXT,
    item_delivery_delivery_location_unset_description_fr TEXT,
    item_delivery_delivery_location_unset_description_ja TEXT,
    item_delivery_delivery_location_unset_description_ko TEXT,
    item_delivery_delivery_location_unset_description_ru TEXT,
    item_delivery_delivery_location_unset_description_zh TEXT,
    item_delivery_description_de TEXT,
    item_delivery_description_en TEXT,
    item_delivery_description_es TEXT,
    item_delivery_description_fr TEXT,
    item_delivery_description_ja TEXT,
    item_delivery_description_ko TEXT,
    item_delivery_description_ru TEXT,
    item_delivery_description_zh TEXT,
    item_delivery_icon_id VARCHAR(500),
    item_delivery_inventory_type_description_de TEXT,
    item_delivery_inventory_type_description_en TEXT,
    item_delivery_inventory_type_description_es TEXT,
    item_delivery_inventory_type_description_fr TEXT,
    item_delivery_inventory_type_description_ja TEXT,
    item_delivery_inventory_type_description_ko TEXT,
    item_delivery_inventory_type_description_ru TEXT,
    item_delivery_inventory_type_description_zh TEXT,
    item_delivery_inventory_type_icon_id VARCHAR(500),
    item_delivery_inventory_type_title_de TEXT,
    item_delivery_inventory_type_title_en TEXT,
    item_delivery_inventory_type_title_es TEXT,
    item_delivery_inventory_type_title_fr TEXT,
    item_delivery_inventory_type_title_ja TEXT,
    item_delivery_inventory_type_title_ko TEXT,
    item_delivery_inventory_type_title_ru TEXT,
    item_delivery_inventory_type_title_zh TEXT,
    item_delivery_inventory_type_unset_description_de TEXT,
    item_delivery_inventory_type_unset_description_en TEXT,
    item_delivery_inventory_type_unset_description_es TEXT,
    item_delivery_inventory_type_unset_description_fr TEXT,
    item_delivery_inventory_type_unset_description_ja TEXT,
    item_delivery_inventory_type_unset_description_ko TEXT,
    item_delivery_inventory_type_unset_description_ru TEXT,
    item_delivery_inventory_type_unset_description_zh TEXT,
    item_delivery_title_de TEXT,
    item_delivery_title_en TEXT,
    item_delivery_title_es TEXT,
    item_delivery_title_fr TEXT,
    item_delivery_title_ja TEXT,
    item_delivery_title_ko TEXT,
    item_delivery_title_ru TEXT,
    item_delivery_title_zh TEXT,
    matcher_description_de TEXT,
    matcher_description_en TEXT,
    matcher_description_es TEXT,
    matcher_description_fr TEXT,
    matcher_description_ja TEXT,
    matcher_description_ko TEXT,
    matcher_description_ru TEXT,
    matcher_description_zh TEXT,
    matcher_icon_id VARCHAR(500),
    matcher_max_entries INTEGER,
    matcher_optional BOOLEAN,
    matcher_title_de TEXT,
    matcher_title_en TEXT,
    matcher_title_es TEXT,
    matcher_title_fr TEXT,
    matcher_title_ja TEXT,
    matcher_title_ko TEXT,
    matcher_title_ru TEXT,
    matcher_title_zh TEXT,
    matcher_type VARCHAR(500),
    matcher_unset_description_de TEXT,
    matcher_unset_description_en TEXT,
    matcher_unset_description_es TEXT,
    matcher_unset_description_fr TEXT,
    matcher_unset_description_ja TEXT,
    matcher_unset_description_ko TEXT,
    matcher_unset_description_ru TEXT,
    matcher_unset_description_zh TEXT,
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (freelance_job_schemas_value_id, seq)
);

CREATE TABLE freelance_job_schemas_value_parameters_item_delivery__b9d62a (
    freelance_job_schemas_value_parameters_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value VARCHAR(500),
    PRIMARY KEY (freelance_job_schemas_value_parameters_id, seq)
);

CREATE TABLE freelance_job_schemas_value_parameters_item_delivery__f0dfe3 (
    freelance_job_schemas_value_parameters_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value VARCHAR(500),
    PRIMARY KEY (freelance_job_schemas_value_parameters_id, seq)
);

CREATE TABLE freelance_job_schemas_value_parameters_matcher_accept_9211f6 (
    freelance_job_schemas_value_parameters_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value VARCHAR(500),
    PRIMARY KEY (freelance_job_schemas_value_parameters_id, seq)
);

CREATE TABLE graphic_material_sets (
    -- raw source: graphicMaterialSets.jsonl _key
    id INTEGER,
    color_hull_a FLOAT,
    color_hull_b FLOAT,
    color_hull_g FLOAT,
    color_hull_r FLOAT,
    color_primary_a FLOAT,
    color_primary_b FLOAT,
    color_primary_g FLOAT,
    color_primary_r FLOAT,
    color_secondary_a FLOAT,
    color_secondary_b FLOAT,
    color_secondary_g FLOAT,
    color_secondary_r FLOAT,
    color_window_a FLOAT,
    color_window_b FLOAT,
    color_window_g FLOAT,
    color_window_r FLOAT,
    custommaterial1 VARCHAR(500),
    custommaterial2 VARCHAR(500),
    description TEXT,
    material1 VARCHAR(500),
    material2 VARCHAR(500),
    material3 VARCHAR(500),
    material4 VARCHAR(500),
    res_path_insert VARCHAR(500),
    sof_faction_name VARCHAR(500),
    sof_pattern_name VARCHAR(500),
    sof_race_hint VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE graphics (
    -- raw source: graphics.jsonl _key
    id INTEGER,
    graphic_file VARCHAR(500),
    icon_folder VARCHAR(500),
    sof_faction_name VARCHAR(500),
    sof_hull_name VARCHAR(500),
    -- FK -> graphicMaterialSets (подтверждено, совпадение 100%)
    sof_material_set_id INTEGER,
    sof_race_name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE graphics_sof_layout (
    graphics_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value VARCHAR(500),
    PRIMARY KEY (graphics_id, seq)
);

CREATE TABLE item_groups (
    -- raw source: groups.jsonl _key
    id INTEGER,
    anchorable BOOLEAN,
    anchored BOOLEAN,
    -- FK -> categories (подтверждено, совпадение 100%)
    category_id INTEGER,
    fittable_non_singleton BOOLEAN,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    published BOOLEAN,
    use_base_price BOOLEAN,
    PRIMARY KEY (id)
);

CREATE TABLE icons (
    -- raw source: icons.jsonl _key
    id INTEGER,
    icon_file VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE landmarks (
    -- raw source: landmarks.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%); неоднозначно: universe location id
    location_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    PRIMARY KEY (id)
);

CREATE TABLE map_asteroid_belts (
    -- raw source: mapAsteroidBelts.jsonl _key
    id INTEGER,
    celestial_index INTEGER,
    orbit_id INTEGER,
    orbit_index INTEGER,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    radius FLOAT,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    statistics_density FLOAT,
    statistics_eccentricity FLOAT,
    statistics_escape_velocity FLOAT,
    statistics_locked BOOLEAN,
    statistics_mass_dust FLOAT,
    statistics_mass_gas FLOAT,
    statistics_orbit_period FLOAT,
    statistics_orbit_radius FLOAT,
    statistics_rotation_rate FLOAT,
    statistics_spectral_class VARCHAR(500),
    statistics_surface_gravity FLOAT,
    statistics_temperature FLOAT,
    type_id INTEGER,
    unique_name_de TEXT,
    unique_name_en TEXT,
    unique_name_es TEXT,
    unique_name_fr TEXT,
    unique_name_ja TEXT,
    unique_name_ko TEXT,
    unique_name_ru TEXT,
    unique_name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE map_constellations (
    -- raw source: mapConstellations.jsonl _key
    id INTEGER,
    -- FK -> factions (подтверждено, совпадение 100%)
    faction_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    -- FK -> mapRegions (подтверждено, совпадение 100%)
    region_id INTEGER,
    wormhole_class_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE map_constellations_solar_system_ids (
    map_constellations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_constellations_id, seq)
);

CREATE TABLE map_moons (
    -- raw source: mapMoons.jsonl _key
    id INTEGER,
    attributes_height_map1 INTEGER,
    attributes_height_map2 INTEGER,
    attributes_shader_preset INTEGER,
    celestial_index INTEGER,
    orbit_id INTEGER,
    orbit_index INTEGER,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    radius FLOAT,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    statistics_density FLOAT,
    statistics_eccentricity FLOAT,
    statistics_escape_velocity FLOAT,
    statistics_locked BOOLEAN,
    statistics_mass_dust FLOAT,
    statistics_mass_gas FLOAT,
    statistics_orbit_period FLOAT,
    statistics_orbit_radius FLOAT,
    statistics_pressure FLOAT,
    statistics_rotation_rate FLOAT,
    statistics_spectral_class VARCHAR(500),
    statistics_surface_gravity FLOAT,
    statistics_temperature FLOAT,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    unique_name_de TEXT,
    unique_name_en TEXT,
    unique_name_es TEXT,
    unique_name_fr TEXT,
    unique_name_ja TEXT,
    unique_name_ko TEXT,
    unique_name_ru TEXT,
    unique_name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE map_moons_npc_station_ids (
    map_moons_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> npcStations (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_moons_id, seq)
);

CREATE TABLE map_planets (
    -- raw source: mapPlanets.jsonl _key
    id INTEGER,
    attributes_height_map1 INTEGER,
    attributes_height_map2 INTEGER,
    attributes_population BOOLEAN,
    attributes_shader_preset INTEGER,
    celestial_index INTEGER,
    orbit_id INTEGER,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    radius INTEGER,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    statistics_density FLOAT,
    statistics_eccentricity FLOAT,
    statistics_escape_velocity FLOAT,
    statistics_locked BOOLEAN,
    statistics_mass_dust FLOAT,
    statistics_mass_gas FLOAT,
    statistics_orbit_period FLOAT,
    statistics_orbit_radius FLOAT,
    statistics_pressure FLOAT,
    statistics_rotation_rate FLOAT,
    statistics_spectral_class VARCHAR(500),
    statistics_surface_gravity FLOAT,
    statistics_temperature FLOAT,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    unique_name_de TEXT,
    unique_name_en TEXT,
    unique_name_es TEXT,
    unique_name_fr TEXT,
    unique_name_ja TEXT,
    unique_name_ko TEXT,
    unique_name_ru TEXT,
    unique_name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE map_planets_asteroid_belt_ids (
    map_planets_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> mapAsteroidBelts (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_planets_id, seq)
);

CREATE TABLE map_planets_moon_ids (
    map_planets_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> mapMoons (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_planets_id, seq)
);

CREATE TABLE map_planets_npc_station_ids (
    map_planets_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> npcStations (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_planets_id, seq)
);

CREATE TABLE map_regions (
    -- raw source: mapRegions.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    -- FK -> factions (подтверждено, совпадение 100%)
    faction_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    nebula_id INTEGER,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    wormhole_class_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE map_regions_constellation_ids (
    map_regions_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> mapConstellations (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_regions_id, seq)
);

CREATE TABLE map_secondary_suns (
    -- raw source: mapSecondarySuns.jsonl _key
    id INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    effect_beacon_type_id INTEGER,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE map_solar_systems (
    -- raw source: mapSolarSystems.jsonl _key
    id INTEGER,
    border BOOLEAN,
    -- FK -> mapConstellations (подтверждено, совпадение 100%)
    constellation_id INTEGER,
    corridor BOOLEAN,
    -- FK -> factions (подтверждено, совпадение 100%)
    faction_id INTEGER,
    fringe BOOLEAN,
    hub BOOLEAN,
    international BOOLEAN,
    luminosity FLOAT,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    position2_d_x FLOAT,
    position2_d_y FLOAT,
    radius FLOAT,
    -- FK -> mapRegions (подтверждено, совпадение 100%)
    region_id INTEGER,
    regional BOOLEAN,
    security_class VARCHAR(500),
    security_status FLOAT,
    -- FK -> mapStars (подтверждено, совпадение 100%)
    star_id INTEGER,
    visual_effect VARCHAR(500),
    wormhole_class_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE map_solar_systems_disallowed_anchor_categories (
    map_solar_systems_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> categories (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_solar_systems_id, seq)
);

CREATE TABLE map_solar_systems_disallowed_anchor_groups (
    map_solar_systems_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> groups (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_solar_systems_id, seq)
);

CREATE TABLE map_solar_systems_planet_ids (
    map_solar_systems_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> mapPlanets (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_solar_systems_id, seq)
);

CREATE TABLE map_solar_systems_stargate_ids (
    map_solar_systems_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> mapStargates (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (map_solar_systems_id, seq)
);

CREATE TABLE map_stargates (
    -- raw source: mapStargates.jsonl _key
    id INTEGER,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    destination_solar_system_id INTEGER,
    -- FK -> mapStargates (подтверждено, совпадение 100%); самоссылка (парный стargate)
    destination_stargate_id INTEGER,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE map_stars (
    -- raw source: mapStars.jsonl _key
    id INTEGER,
    radius INTEGER,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    statistics_age FLOAT,
    statistics_life FLOAT,
    statistics_luminosity FLOAT,
    statistics_spectral_class VARCHAR(500),
    statistics_temperature FLOAT,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE market_groups (
    -- raw source: marketGroups.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    has_types BOOLEAN,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    -- FK -> marketGroups (подтверждено, совпадение 100%); самоссылка (иерархия групп рынка)
    parent_group_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE masteries (
    -- raw source: masteries.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE masteries_value (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке);
    -- нужен, т.к. на эту таблицу ссылаются дочерние таблицы (FK одной колонкой)
    id INTEGER,
    masteries_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- это порядковый номер уровня мастерства (0-4), а не FK
    source_key INTEGER,
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (masteries_id, seq)
);

CREATE TABLE masteries_value_value (
    masteries_value_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> certificates (подтверждено, совпадение 100%); уровень мастерства -> список требуемых certificateID
    value INTEGER,
    PRIMARY KEY (masteries_value_id, seq)
);

CREATE TABLE mercenary_tactical_operations (
    -- raw source: mercenaryTacticalOperations.jsonl _key
    id INTEGER,
    anarchy_impact INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    development_impact INTEGER,
    -- FK -> dungeons (подтверждено, совпадение 100%)
    dungeon_id INTEGER,
    infomorph_bonus INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE meta_groups (
    -- raw source: metaGroups.jsonl _key
    id INTEGER,
    color_b FLOAT,
    color_g FLOAT,
    color_r FLOAT,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    icon_suffix VARCHAR(500),
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE military_campaign_objectives (
    -- raw source: militaryCampaignObjectives.jsonl _key
    id VARCHAR(128),
    annotations_required_enlistment_with_faction_id INTEGER,
    annotations_restriction_tooltip_de TEXT,
    annotations_restriction_tooltip_en TEXT,
    annotations_restriction_tooltip_es TEXT,
    annotations_restriction_tooltip_fr TEXT,
    annotations_restriction_tooltip_ja TEXT,
    annotations_restriction_tooltip_ko TEXT,
    annotations_restriction_tooltip_ru TEXT,
    annotations_restriction_tooltip_zh TEXT,
    annotations_warning1_de TEXT,
    annotations_warning1_en TEXT,
    annotations_warning1_es TEXT,
    annotations_warning1_fr TEXT,
    annotations_warning1_ja TEXT,
    annotations_warning1_ko TEXT,
    annotations_warning1_ru TEXT,
    annotations_warning1_zh TEXT,
    annotations_warning2_de TEXT,
    annotations_warning2_en TEXT,
    annotations_warning2_es TEXT,
    annotations_warning2_fr TEXT,
    annotations_warning2_ja TEXT,
    annotations_warning2_ko TEXT,
    annotations_warning2_ru TEXT,
    annotations_warning2_zh TEXT,
    -- FK -> militaryCampaigns (подтверждено, совпадение 100%); тип string, ключ militaryCampaigns._key
    campaign_id VARCHAR(500),
    career_path VARCHAR(500),
    contribution_method_configuration_name VARCHAR(500),
    -- FK -> npcCorporations (подтверждено, совпадение 100%)
    issuer_corporation_id INTEGER,
    max_progress_per_participant INTEGER,
    -- FK -> npcCharacters (подтверждено, совпадение 100%)
    presenting_character_id INTEGER,
    rewards_isk_amount_per_interval INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%)
    rewards_isk_issuer_corporation_id INTEGER,
    rewards_isk_progress_interval INTEGER,
    rewards_lp_amount_per_interval INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%)
    rewards_lp_issuer_corporation_id INTEGER,
    rewards_lp_progress_interval INTEGER,
    rewards_standing_gain_percent_per_interval FLOAT,
    -- FK -> factions (подтверждено, совпадение 100%)
    rewards_standing_issuer_faction_id INTEGER,
    rewards_standing_progress_interval INTEGER,
    subtitle_de TEXT,
    subtitle_en TEXT,
    subtitle_es TEXT,
    subtitle_fr TEXT,
    subtitle_ja TEXT,
    subtitle_ko TEXT,
    subtitle_ru TEXT,
    subtitle_zh TEXT,
    target_progress INTEGER,
    title_de TEXT,
    title_en TEXT,
    title_es TEXT,
    title_fr TEXT,
    title_ja TEXT,
    title_ko TEXT,
    title_ru TEXT,
    title_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE military_campaign_objectives_content_tags (
    military_campaign_objectives_id VARCHAR(128),
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value VARCHAR(500),
    PRIMARY KEY (military_campaign_objectives_id, seq)
);

CREATE TABLE military_campaign_objectives_contribution_method_conf_00852c (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке);
    -- нужен, т.к. на эту таблицу ссылаются дочерние таблицы (FK одной колонкой)
    id INTEGER,
    military_campaign_objectives_id VARCHAR(128),
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    item_key VARCHAR(500),
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (military_campaign_objectives_id, seq)
);

CREATE TABLE military_campaign_objectives_contribution_method_conf_57d6be (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке);
    -- нужен, т.к. на эту таблицу ссылаются дочерние таблицы (FK одной колонкой)
    id INTEGER,
    military_campaign_objectives_contribution_method_conf_00852c_id VARCHAR(128),
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value_type VARCHAR(500),
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (military_campaign_objectives_contribution_method_conf_00852c_id, seq)
);

CREATE TABLE military_campaign_objectives_contribution_method_conf_4c7001 (
    military_campaign_objectives_contribution_method_conf_57d6be_id VARCHAR(128),
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value VARCHAR(500),
    PRIMARY KEY (military_campaign_objectives_contribution_method_conf_57d6be_id, seq)
);

CREATE TABLE military_campaigns (
    -- raw source: militaryCampaigns.jsonl _key
    id VARCHAR(128),
    annotations_ao_campaign_card_button_image VARCHAR(500),
    annotations_background_video_loop VARCHAR(500),
    annotations_briefing_background TEXT,
    annotations_briefing_failure_description_de TEXT,
    annotations_briefing_failure_description_en TEXT,
    annotations_briefing_failure_description_es TEXT,
    annotations_briefing_failure_description_fr TEXT,
    annotations_briefing_failure_description_ja TEXT,
    annotations_briefing_failure_description_ko TEXT,
    annotations_briefing_failure_description_ru TEXT,
    annotations_briefing_failure_description_zh TEXT,
    annotations_briefing_failure_header_de TEXT,
    annotations_briefing_failure_header_en TEXT,
    annotations_briefing_failure_header_es TEXT,
    annotations_briefing_failure_header_fr TEXT,
    annotations_briefing_failure_header_ja TEXT,
    annotations_briefing_failure_header_ko TEXT,
    annotations_briefing_failure_header_ru TEXT,
    annotations_briefing_failure_header_zh TEXT,
    annotations_briefing_final_words_de TEXT,
    annotations_briefing_final_words_en TEXT,
    annotations_briefing_final_words_es TEXT,
    annotations_briefing_final_words_fr TEXT,
    annotations_briefing_final_words_ja TEXT,
    annotations_briefing_final_words_ko TEXT,
    annotations_briefing_final_words_ru TEXT,
    annotations_briefing_final_words_zh TEXT,
    annotations_briefing_foreground TEXT,
    annotations_briefing_goal_description_de TEXT,
    annotations_briefing_goal_description_en TEXT,
    annotations_briefing_goal_description_es TEXT,
    annotations_briefing_goal_description_fr TEXT,
    annotations_briefing_goal_description_ja TEXT,
    annotations_briefing_goal_description_ko TEXT,
    annotations_briefing_goal_description_ru TEXT,
    annotations_briefing_goal_description_zh TEXT,
    annotations_briefing_header_de TEXT,
    annotations_briefing_header_en TEXT,
    annotations_briefing_header_es TEXT,
    annotations_briefing_header_fr TEXT,
    annotations_briefing_header_ja TEXT,
    annotations_briefing_header_ko TEXT,
    annotations_briefing_header_ru TEXT,
    annotations_briefing_header_zh TEXT,
    annotations_briefing_middleground TEXT,
    annotations_briefing_success_description_de TEXT,
    annotations_briefing_success_description_en TEXT,
    annotations_briefing_success_description_es TEXT,
    annotations_briefing_success_description_fr TEXT,
    annotations_briefing_success_description_ja TEXT,
    annotations_briefing_success_description_ko TEXT,
    annotations_briefing_success_description_ru TEXT,
    annotations_briefing_success_description_zh TEXT,
    annotations_briefing_success_header_de TEXT,
    annotations_briefing_success_header_en TEXT,
    annotations_briefing_success_header_es TEXT,
    annotations_briefing_success_header_fr TEXT,
    annotations_briefing_success_header_ja TEXT,
    annotations_briefing_success_header_ko TEXT,
    annotations_briefing_success_header_ru TEXT,
    annotations_briefing_success_header_zh TEXT,
    annotations_campaign_set VARCHAR(500),
    annotations_dashboard_ambient_background VARCHAR(500),
    annotations_dashboard_background VARCHAR(500),
    annotations_dashboard_foreground VARCHAR(500),
    annotations_dashboard_middleground VARCHAR(500),
    annotations_finished_campaign_ended_de TEXT,
    annotations_finished_campaign_ended_en TEXT,
    annotations_finished_campaign_ended_es TEXT,
    annotations_finished_campaign_ended_fr TEXT,
    annotations_finished_campaign_ended_ja TEXT,
    annotations_finished_campaign_ended_ko TEXT,
    annotations_finished_campaign_ended_ru TEXT,
    annotations_finished_campaign_ended_zh TEXT,
    annotations_finished_failure_description_de TEXT,
    annotations_finished_failure_description_en TEXT,
    annotations_finished_failure_description_es TEXT,
    annotations_finished_failure_description_fr TEXT,
    annotations_finished_failure_description_ja TEXT,
    annotations_finished_failure_description_ko TEXT,
    annotations_finished_failure_description_ru TEXT,
    annotations_finished_failure_description_zh TEXT,
    annotations_finished_resolution_state_failure_de TEXT,
    annotations_finished_resolution_state_failure_en TEXT,
    annotations_finished_resolution_state_failure_es TEXT,
    annotations_finished_resolution_state_failure_fr TEXT,
    annotations_finished_resolution_state_failure_ja TEXT,
    annotations_finished_resolution_state_failure_ko TEXT,
    annotations_finished_resolution_state_failure_ru TEXT,
    annotations_finished_resolution_state_failure_zh TEXT,
    annotations_finished_resolution_state_success_de TEXT,
    annotations_finished_resolution_state_success_en TEXT,
    annotations_finished_resolution_state_success_es TEXT,
    annotations_finished_resolution_state_success_fr TEXT,
    annotations_finished_resolution_state_success_ja TEXT,
    annotations_finished_resolution_state_success_ko TEXT,
    annotations_finished_resolution_state_success_ru TEXT,
    annotations_finished_resolution_state_success_zh TEXT,
    annotations_finished_success_description_de TEXT,
    annotations_finished_success_description_en TEXT,
    annotations_finished_success_description_es TEXT,
    annotations_finished_success_description_fr TEXT,
    annotations_finished_success_description_ja TEXT,
    annotations_finished_success_description_ko TEXT,
    annotations_finished_success_description_ru TEXT,
    annotations_finished_success_description_zh TEXT,
    annotations_foreground_video_intro VARCHAR(500),
    annotations_foreground_video_loop VARCHAR(500),
    annotations_foreground_video_outro VARCHAR(500),
    annotations_map_focus_entity_id INTEGER,
    annotations_map_header_de TEXT,
    annotations_map_header_en TEXT,
    annotations_map_header_es TEXT,
    annotations_map_header_fr TEXT,
    annotations_map_header_ja TEXT,
    annotations_map_header_ko TEXT,
    annotations_map_header_ru TEXT,
    annotations_map_header_zh TEXT,
    annotations_map_section1_paragraph_de TEXT,
    annotations_map_section1_paragraph_en TEXT,
    annotations_map_section1_paragraph_es TEXT,
    annotations_map_section1_paragraph_fr TEXT,
    annotations_map_section1_paragraph_ja TEXT,
    annotations_map_section1_paragraph_ko TEXT,
    annotations_map_section1_paragraph_ru TEXT,
    annotations_map_section1_paragraph_zh TEXT,
    annotations_map_section1_title_de TEXT,
    annotations_map_section1_title_en TEXT,
    annotations_map_section1_title_es TEXT,
    annotations_map_section1_title_fr TEXT,
    annotations_map_section1_title_ja TEXT,
    annotations_map_section1_title_ko TEXT,
    annotations_map_section1_title_ru TEXT,
    annotations_map_section1_title_zh TEXT,
    annotations_map_section2_paragraph_de TEXT,
    annotations_map_section2_paragraph_en TEXT,
    annotations_map_section2_paragraph_es TEXT,
    annotations_map_section2_paragraph_fr TEXT,
    annotations_map_section2_paragraph_ja TEXT,
    annotations_map_section2_paragraph_ko TEXT,
    annotations_map_section2_paragraph_ru TEXT,
    annotations_map_section2_paragraph_zh TEXT,
    annotations_map_section2_title_de TEXT,
    annotations_map_section2_title_en TEXT,
    annotations_map_section2_title_es TEXT,
    annotations_map_section2_title_fr TEXT,
    annotations_map_section2_title_ja TEXT,
    annotations_map_section2_title_ko TEXT,
    annotations_map_section2_title_ru TEXT,
    annotations_map_section2_title_zh TEXT,
    annotations_map_section3_paragraph_de TEXT,
    annotations_map_section3_paragraph_en TEXT,
    annotations_map_section3_paragraph_es TEXT,
    annotations_map_section3_paragraph_fr TEXT,
    annotations_map_section3_paragraph_ja TEXT,
    annotations_map_section3_paragraph_ko TEXT,
    annotations_map_section3_paragraph_ru TEXT,
    annotations_map_section3_paragraph_zh TEXT,
    annotations_map_section3_title_de TEXT,
    annotations_map_section3_title_en TEXT,
    annotations_map_section3_title_es TEXT,
    annotations_map_section3_title_fr TEXT,
    annotations_map_section3_title_ja TEXT,
    annotations_map_section3_title_ko TEXT,
    annotations_map_section3_title_ru TEXT,
    annotations_map_section3_title_zh TEXT,
    annotations_map_subheader_de TEXT,
    annotations_map_subheader_en TEXT,
    annotations_map_subheader_es TEXT,
    annotations_map_subheader_fr TEXT,
    annotations_map_subheader_ja TEXT,
    annotations_map_subheader_ko TEXT,
    annotations_map_subheader_ru TEXT,
    annotations_map_subheader_zh TEXT,
    annotations_map_title_de TEXT,
    annotations_map_title_en TEXT,
    annotations_map_title_es TEXT,
    annotations_map_title_fr TEXT,
    annotations_map_title_ja TEXT,
    annotations_map_title_ko TEXT,
    annotations_map_title_ru TEXT,
    annotations_map_title_zh TEXT,
    annotations_middleground_video_intro VARCHAR(500),
    annotations_middleground_video_loop VARCHAR(500),
    annotations_middleground_video_outro VARCHAR(500),
    annotations_presenting_character_name_de TEXT,
    annotations_presenting_character_name_en TEXT,
    annotations_presenting_character_name_es TEXT,
    annotations_presenting_character_name_fr TEXT,
    annotations_presenting_character_name_ja TEXT,
    annotations_presenting_character_name_ko TEXT,
    annotations_presenting_character_name_ru TEXT,
    annotations_presenting_character_name_zh TEXT,
    annotations_presenting_character_subtitle_de TEXT,
    annotations_presenting_character_subtitle_en TEXT,
    annotations_presenting_character_subtitle_es TEXT,
    annotations_presenting_character_subtitle_fr TEXT,
    annotations_presenting_character_subtitle_ja TEXT,
    annotations_presenting_character_subtitle_ko TEXT,
    annotations_presenting_character_subtitle_ru TEXT,
    annotations_presenting_character_subtitle_zh TEXT,
    annotations_presenting_character_texture_path VARCHAR(500),
    annotations_race VARCHAR(500),
    annotations_theme_pack VARCHAR(500),
    annotations_tow_campaign_card_button_image VARCHAR(500),
    -- FK -> factions (подтверждено, совпадение 100%)
    issuer_faction_id INTEGER,
    subtitle_de TEXT,
    subtitle_en TEXT,
    subtitle_es TEXT,
    subtitle_fr TEXT,
    subtitle_ja TEXT,
    subtitle_ko TEXT,
    subtitle_ru TEXT,
    subtitle_zh TEXT,
    target_progress INTEGER,
    title_de TEXT,
    title_en TEXT,
    title_es TEXT,
    title_fr TEXT,
    title_ja TEXT,
    title_ko TEXT,
    title_ru TEXT,
    title_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE missions (
    -- raw source: missions.jsonl _key
    id INTEGER,
    -- FK -> agentTypes (подтверждено, совпадение 100%)
    agent_type_id INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%)
    corporation_id INTEGER,
    courier_mission_objective_quantity INTEGER,
    courier_mission_objective_singleton BOOLEAN,
    -- FK -> types (подтверждено, совпадение 100%)
    courier_mission_objective_type_id INTEGER,
    expiration_time INTEGER,
    -- FK -> factions (подтверждено, совпадение 100%)
    faction_id INTEGER,
    has_standing_rewards BOOLEAN,
    initial_agent_gift_quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    initial_agent_gift_type_id INTEGER,
    kill_mission_drop_item_in_mission_container INTEGER,
    -- 0.2% совпадения (3/1460) — аналогично agentsInSpace.dungeonID, не является статической FK
    kill_mission_dungeon_id INTEGER,
    kill_mission_objective_quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    kill_mission_objective_type_id INTEGER,
    mission_rewards_bonus_reward_reward_quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    mission_rewards_bonus_reward_reward_type_id INTEGER,
    mission_rewards_bonus_time_interval INTEGER,
    mission_rewards_reward_reward_quantity INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    mission_rewards_reward_reward_type_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE missions_extra_standings (
    missions_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> factions (подтверждено, совпадение 100%)
    source_key INTEGER,
    value FLOAT,
    PRIMARY KEY (missions_id, seq)
);

CREATE TABLE missions_messages (
    missions_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    source_key VARCHAR(500),
    de VARCHAR(500),
    en VARCHAR(500),
    es VARCHAR(500),
    fr VARCHAR(500),
    ja VARCHAR(500),
    ko VARCHAR(500),
    ru VARCHAR(500),
    zh VARCHAR(500),
    PRIMARY KEY (missions_id, seq)
);

CREATE TABLE npc_characters (
    -- raw source: npcCharacters.jsonl _key
    id INTEGER,
    -- FK -> agentTypes (подтверждено, совпадение 100%)
    agent_agent_type_id INTEGER,
    -- FK -> npcCorporationDivisions (подтверждено, совпадение 100%)
    agent_division_id INTEGER,
    agent_is_locator BOOLEAN,
    agent_level INTEGER,
    -- FK -> ancestries (подтверждено, совпадение 100%)
    ancestry_id INTEGER,
    -- FK -> bloodlines (подтверждено, совпадение 100%)
    bloodline_id INTEGER,
    career_id INTEGER,
    ceo BOOLEAN,
    -- FK -> npcCorporations (подтверждено, совпадение 100%)
    corporation_id INTEGER,
    description TEXT,
    gender BOOLEAN,
    -- FK -> npcStations (подтверждено, совпадение 100%); неоднозначно
    location_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    -- FK -> races (подтверждено, совпадение 100%)
    race_id INTEGER,
    school_id INTEGER,
    speciality_id INTEGER,
    start_date VARCHAR(500),
    unique_name BOOLEAN,
    PRIMARY KEY (id)
);

CREATE TABLE npc_characters_skills (
    npc_characters_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (npc_characters_id, seq)
);

CREATE TABLE npc_corporation_divisions (
    -- raw source: npcCorporationDivisions.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    display_name VARCHAR(500),
    internal_name VARCHAR(500),
    leader_type_name_de TEXT,
    leader_type_name_en TEXT,
    leader_type_name_es TEXT,
    leader_type_name_fr TEXT,
    leader_type_name_ja TEXT,
    leader_type_name_ko TEXT,
    leader_type_name_ru TEXT,
    leader_type_name_zh TEXT,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE npc_corporations (
    -- raw source: npcCorporations.jsonl _key
    id INTEGER,
    -- FK -> npcCharacters (подтверждено, совпадение 99.6%)
    ceo_id INTEGER,
    deleted BOOLEAN,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    -- FK -> npcCorporations (подтверждено, совпадение 100%); самоссылка
    enemy_id INTEGER,
    extent VARCHAR(500),
    -- FK -> factions (подтверждено, совпадение 100%)
    faction_id INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%); самоссылка
    friend_id INTEGER,
    has_player_personnel_manager BOOLEAN,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    initial_price INTEGER,
    -- FK -> corporationActivities (подтверждено, совпадение 100%)
    main_activity_id INTEGER,
    member_limit INTEGER,
    min_security FLOAT,
    minimum_join_standing INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    -- FK -> races (подтверждено, совпадение 100%)
    race_id INTEGER,
    -- FK -> corporationActivities (подтверждено, совпадение 100%)
    secondary_activity_id INTEGER,
    send_char_termination_message BOOLEAN,
    shares INTEGER,
    size VARCHAR(500),
    size_factor FLOAT,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    -- FK -> npcStations (подтверждено, совпадение 99.6%)
    station_id INTEGER,
    tax_rate FLOAT,
    ticker_name VARCHAR(500),
    unique_name BOOLEAN,
    PRIMARY KEY (id)
);

CREATE TABLE npc_corporations_allowed_member_races (
    npc_corporations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> races (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (npc_corporations_id, seq)
);

CREATE TABLE npc_corporations_corporation_trades (
    npc_corporations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%); исправлено: реальная цель — types.jsonl (typeID торгуемого товара), не npcCorporations; _value — экономический коэффициент (float)
    source_key INTEGER,
    value FLOAT,
    PRIMARY KEY (npc_corporations_id, seq)
);

CREATE TABLE npc_corporations_divisions (
    npc_corporations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    source_key INTEGER,
    division_number INTEGER,
    -- FK -> npcCharacters (подтверждено, совпадение 99.2%)
    leader_id INTEGER,
    size INTEGER,
    PRIMARY KEY (npc_corporations_id, seq)
);

CREATE TABLE npc_corporations_exchange_rates (
    npc_corporations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%); неоднозначно, проверить
    source_key INTEGER,
    value FLOAT,
    PRIMARY KEY (npc_corporations_id, seq)
);

CREATE TABLE npc_corporations_investors (
    npc_corporations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%); самоссылка
    source_key INTEGER,
    value INTEGER,
    PRIMARY KEY (npc_corporations_id, seq)
);

CREATE TABLE npc_corporations_lp_offer_tables (
    npc_corporations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    value INTEGER,
    PRIMARY KEY (npc_corporations_id, seq)
);

CREATE TABLE npc_stations (
    -- raw source: npcStations.jsonl _key
    id INTEGER,
    celestial_index INTEGER,
    -- FK -> stationOperations (подтверждено, совпадение 100%)
    operation_id INTEGER,
    orbit_id INTEGER,
    orbit_index INTEGER,
    -- FK -> npcCorporations (подтверждено, совпадение 100%)
    owner_id INTEGER,
    position_x FLOAT,
    position_y FLOAT,
    position_z FLOAT,
    reprocessing_efficiency FLOAT,
    reprocessing_hangar_flag INTEGER,
    reprocessing_stations_take FLOAT,
    -- FK -> mapSolarSystems (подтверждено, совпадение 100%)
    solar_system_id INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    use_operation_name BOOLEAN,
    PRIMARY KEY (id)
);

CREATE TABLE planet_resources (
    -- raw source: planetResources.jsonl _key
    id INTEGER,
    power INTEGER,
    reagent_amount_per_cycle INTEGER,
    reagent_cycle_period INTEGER,
    reagent_secured_capacity INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    reagent_type_id INTEGER,
    reagent_unsecured_capacity INTEGER,
    workforce INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE planet_schematics (
    -- raw source: planetSchematics.jsonl _key
    id INTEGER,
    cycle_time INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE planet_schematics_pins (
    planet_schematics_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (planet_schematics_id, seq)
);

CREATE TABLE planet_schematics_types (
    planet_schematics_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    source_key INTEGER,
    is_input BOOLEAN,
    quantity INTEGER,
    PRIMARY KEY (planet_schematics_id, seq)
);

CREATE TABLE races (
    -- raw source: races.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    icon_id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    -- FK -> types (подтверждено, совпадение 100%)
    ship_type_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE races_skills (
    races_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    source_key INTEGER,
    value INTEGER,
    PRIMARY KEY (races_id, seq)
);

CREATE TABLE ship_tree_elements (
    -- raw source: shipTreeElements.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    icon VARCHAR(500),
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE ship_tree_factions (
    -- raw source: shipTreeFactions.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    icon VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE ship_tree_factions_elements (
    ship_tree_factions_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- порядковый индекс элемента массива (1..N), не FK
    source_key INTEGER,
    -- FK -> shipTreeElements (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (ship_tree_factions_id, seq)
);

CREATE TABLE ship_tree_groups (
    -- raw source: shipTreeGroups.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    icon VARCHAR(500),
    icon_large VARCHAR(500),
    icon_small VARCHAR(500),
    icon_small_npc VARCHAR(500),
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE ship_tree_groups_elements (
    ship_tree_groups_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- порядковый индекс элемента массива (1..N), не FK
    source_key INTEGER,
    -- FK -> shipTreeElements (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (ship_tree_groups_id, seq)
);

CREATE TABLE ship_tree_groups_pre_req_skills (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке);
    -- нужен, т.к. на эту таблицу ссылаются дочерние таблицы (FK одной колонкой)
    id INTEGER,
    ship_tree_groups_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- СМЕШАННАЯ ссылка на неск. таблиц: factions, shipTreeFactions (без единого FK-constraint) — значения — реальные factionID (напр. 500001=Caldari), совпадают и с factions, и с производной shipTreeFactions
    source_key INTEGER,
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (ship_tree_groups_id, seq)
);

CREATE TABLE ship_tree_groups_pre_req_skills_skills (
    ship_tree_groups_pre_req_skills_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    source_key INTEGER,
    display BOOLEAN,
    level INTEGER,
    PRIMARY KEY (ship_tree_groups_pre_req_skills_id, seq)
);

CREATE TABLE skin_licenses (
    -- raw source: skinLicenses.jsonl _key
    id INTEGER,
    duration INTEGER,
    is_single_use BOOLEAN,
    -- FK -> types (подтверждено, совпадение 99.9%)
    license_type_id INTEGER,
    -- FK -> skins (подтверждено, совпадение 99.9%)
    skin_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE skin_materials (
    -- raw source: skinMaterials.jsonl _key
    id INTEGER,
    display_name_de TEXT,
    display_name_en TEXT,
    display_name_es TEXT,
    display_name_fr TEXT,
    display_name_ja TEXT,
    display_name_ko TEXT,
    display_name_ru TEXT,
    display_name_zh TEXT,
    -- FK -> graphicMaterialSets (подтверждено, совпадение 100%); неоднозначно, проверить
    material_set_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE skinr_component_categories (
    -- raw source: skinrComponentCategories.jsonl _key
    id INTEGER,
    name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE skinr_component_point_values (
    -- raw source: skinrComponentPointValues.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE skinr_component_point_values_value (
    skinr_component_point_values_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> skinrComponentRarities (подтверждено, совпадение 100%); проверить
    source_key INTEGER,
    value INTEGER,
    PRIMARY KEY (skinr_component_point_values_id, seq)
);

CREATE TABLE skinr_component_rarities (
    -- raw source: skinrComponentRarities.jsonl _key
    id INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    rank INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE skinr_components (
    -- raw source: skinrComponents.jsonl _key
    id INTEGER,
    -- FK -> skinrComponentCategories (подтверждено, совпадение 100%)
    category INTEGER,
    finish VARCHAR(500),
    icon_file VARCHAR(500),
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    projection_type_u VARCHAR(500),
    projection_type_v VARCHAR(500),
    published BOOLEAN,
    -- FK -> skinrComponentRarities (подтверждено, совпадение 100%)
    rarity INTEGER,
    resource_file VARCHAR(500),
    sequence_binder_count INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    sequence_binder_item_type_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE skinr_components_associated_type_ids (
    skinr_components_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    license_uses_granted INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    type_id INTEGER,
    PRIMARY KEY (skinr_components_id, seq)
);

CREATE TABLE skinr_slot_categories (
    -- raw source: skinrSlotCategories.jsonl _key
    id INTEGER,
    name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE skinr_slot_configurations (
    -- raw source: skinrSlotConfigurations.jsonl _key
    id INTEGER,
    allow_all_ships BOOLEAN,
    name VARCHAR(500),
    priority INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE skinr_slot_configurations_config (
    skinr_slot_configurations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> skinrSlots (подтверждено, совпадение 100%); проверить
    value INTEGER,
    PRIMARY KEY (skinr_slot_configurations_id, seq)
);

CREATE TABLE skinr_slot_configurations_ships (
    skinr_slot_configurations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (skinr_slot_configurations_id, seq)
);

CREATE TABLE skinr_slot_names (
    -- raw source: skinrSlotNames.jsonl _key
    id INTEGER,
    name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE skinr_slots (
    -- raw source: skinrSlots.jsonl _key
    id INTEGER,
    -- FK -> skinrSlotCategories (подтверждено, совпадение 100%)
    category INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE skinr_slots_allowed_design_component_categories (
    skinr_slots_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> skinrComponentCategories (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (skinr_slots_id, seq)
);

CREATE TABLE skinr_tier_thresholds (
    -- raw source: skinrTierThresholds.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE skinr_tier_thresholds_value (
    skinr_tier_thresholds_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- порядковый номер порога (tier index 1-19), не FK; случайное совпадение с skinrComponentRarities (1-6) — ложное срабатывание
    source_key INTEGER,
    value INTEGER,
    PRIMARY KEY (skinr_tier_thresholds_id, seq)
);

CREATE TABLE skins (
    -- raw source: skins.jsonl _key
    id INTEGER,
    allow_ccp_devs BOOLEAN,
    internal_name VARCHAR(500),
    is_structure_skin BOOLEAN,
    -- FK -> skinMaterials (подтверждено, совпадение 100%)
    skin_material_id INTEGER,
    visible_serenity BOOLEAN,
    visible_tranquility BOOLEAN,
    PRIMARY KEY (id)
);

CREATE TABLE skins_types (
    skins_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (skins_id, seq)
);

CREATE TABLE sovereignty_upgrades (
    -- raw source: sovereigntyUpgrades.jsonl _key
    id INTEGER,
    fuel_hourly_upkeep INTEGER,
    fuel_startup_cost INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    fuel_type_id INTEGER,
    mutually_exclusive_group VARCHAR(500),
    power_allocation INTEGER,
    power_production INTEGER,
    workforce_allocation INTEGER,
    workforce_production INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE station_operations (
    -- raw source: stationOperations.jsonl _key
    id INTEGER,
    -- FK -> corporationActivities (подтверждено, совпадение 100%); проверить
    activity_id INTEGER,
    border FLOAT,
    corridor FLOAT,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    fringe FLOAT,
    hub FLOAT,
    manufacturing_factor FLOAT,
    operation_name_de TEXT,
    operation_name_en TEXT,
    operation_name_es TEXT,
    operation_name_fr TEXT,
    operation_name_ja TEXT,
    operation_name_ko TEXT,
    operation_name_ru TEXT,
    operation_name_zh TEXT,
    ratio FLOAT,
    research_factor FLOAT,
    PRIMARY KEY (id)
);

CREATE TABLE station_operations_services (
    station_operations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> stationServices (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (station_operations_id, seq)
);

CREATE TABLE station_operations_station_types (
    station_operations_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- значения [1,2,4,8,16] — битовая маска флагов операции станции, а не typeID (совпадение 4/5 с types.jsonl случайно из-за малых чисел)
    source_key INTEGER,
    value INTEGER,
    PRIMARY KEY (station_operations_id, seq)
);

CREATE TABLE station_services (
    -- raw source: stationServices.jsonl _key
    id INTEGER,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    service_name_de TEXT,
    service_name_en TEXT,
    service_name_es TEXT,
    service_name_fr TEXT,
    service_name_ja TEXT,
    service_name_ko TEXT,
    service_name_ru TEXT,
    service_name_zh TEXT,
    PRIMARY KEY (id)
);

CREATE TABLE translation_languages (
    -- raw source: translationLanguages.jsonl _key
    id VARCHAR(128),
    name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE type_bonus (
    -- raw source: typeBonus.jsonl _key
    id INTEGER,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE type_bonus_misc_bonuses (
    type_bonus_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    bonus FLOAT,
    bonus_text_de TEXT,
    bonus_text_en TEXT,
    bonus_text_es TEXT,
    bonus_text_fr TEXT,
    bonus_text_ja TEXT,
    bonus_text_ko TEXT,
    bonus_text_ru TEXT,
    bonus_text_zh TEXT,
    importance INTEGER,
    is_positive BOOLEAN,
    -- FK -> dogmaUnits (подтверждено, совпадение 100%)
    unit_id INTEGER,
    PRIMARY KEY (type_bonus_id, seq)
);

CREATE TABLE type_bonus_role_bonuses (
    type_bonus_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    bonus FLOAT,
    bonus_text_de TEXT,
    bonus_text_en TEXT,
    bonus_text_es TEXT,
    bonus_text_fr TEXT,
    bonus_text_ja TEXT,
    bonus_text_ko TEXT,
    bonus_text_ru TEXT,
    bonus_text_zh TEXT,
    importance INTEGER,
    -- FK -> dogmaUnits (подтверждено, совпадение 100%)
    unit_id INTEGER,
    PRIMARY KEY (type_bonus_id, seq)
);

CREATE TABLE type_bonus_types (
    -- суррогатный PK: присваивается ETL (сквозная нумерация при загрузке);
    -- нужен, т.к. на эту таблицу ссылаются дочерние таблицы (FK одной колонкой)
    id INTEGER,
    type_bonus_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    source_key INTEGER,
    PRIMARY KEY (id),
    -- натуральный ключ сохранён
    UNIQUE (type_bonus_id, seq)
);

CREATE TABLE type_bonus_types_value (
    type_bonus_types_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    bonus FLOAT,
    bonus_text_de TEXT,
    bonus_text_en TEXT,
    bonus_text_es TEXT,
    bonus_text_fr TEXT,
    bonus_text_ja TEXT,
    bonus_text_ko TEXT,
    bonus_text_ru TEXT,
    bonus_text_zh TEXT,
    importance INTEGER,
    -- FK -> dogmaUnits (подтверждено, совпадение 100%)
    unit_id INTEGER,
    PRIMARY KEY (type_bonus_types_id, seq)
);

CREATE TABLE type_dogma (
    -- raw source: typeDogma.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE type_dogma_dogma_attributes (
    type_dogma_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> dogmaAttributes (подтверждено, совпадение 100%)
    attribute_id INTEGER,
    value FLOAT,
    PRIMARY KEY (type_dogma_id, seq)
);

CREATE TABLE type_dogma_dogma_effects (
    type_dogma_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> dogmaEffects (подтверждено, совпадение 100%)
    effect_id INTEGER,
    is_default BOOLEAN,
    PRIMARY KEY (type_dogma_id, seq)
);

CREATE TABLE type_elements (
    -- raw source: typeElements.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE type_elements_elements (
    type_elements_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 90.9%); неоднозначно, проверить
    source_key INTEGER,
    value INTEGER,
    PRIMARY KEY (type_elements_id, seq)
);

CREATE TABLE type_lists (
    -- raw source: typeLists.jsonl _key
    id INTEGER,
    display_description_de TEXT,
    display_description_en TEXT,
    display_description_es TEXT,
    display_description_fr TEXT,
    display_description_ja TEXT,
    display_description_ko TEXT,
    display_description_ru TEXT,
    display_description_zh TEXT,
    display_name_de TEXT,
    display_name_en TEXT,
    display_name_es TEXT,
    display_name_fr TEXT,
    display_name_ja TEXT,
    display_name_ko TEXT,
    display_name_ru TEXT,
    display_name_zh TEXT,
    name VARCHAR(500),
    PRIMARY KEY (id)
);

CREATE TABLE type_lists_excluded_category_ids (
    type_lists_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> categories (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (type_lists_id, seq)
);

CREATE TABLE type_lists_excluded_group_ids (
    type_lists_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> groups (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (type_lists_id, seq)
);

CREATE TABLE type_lists_excluded_type_ids (
    type_lists_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (type_lists_id, seq)
);

CREATE TABLE type_lists_included_category_ids (
    type_lists_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> categories (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (type_lists_id, seq)
);

CREATE TABLE type_lists_included_group_ids (
    type_lists_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> groups (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (type_lists_id, seq)
);

CREATE TABLE type_lists_included_type_ids (
    type_lists_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    value INTEGER,
    PRIMARY KEY (type_lists_id, seq)
);

CREATE TABLE type_materials (
    -- raw source: typeMaterials.jsonl _key
    id INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE type_materials_materials (
    type_materials_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    material_type_id INTEGER,
    quantity INTEGER,
    PRIMARY KEY (type_materials_id, seq)
);

CREATE TABLE type_materials_randomized_materials (
    type_materials_id INTEGER,
    -- порядковая позиция элемента в массиве (0-based)
    seq INTEGER,
    -- FK -> types (подтверждено, совпадение 100%)
    material_type_id INTEGER,
    quantity_max INTEGER,
    quantity_min INTEGER,
    PRIMARY KEY (type_materials_id, seq)
);

CREATE TABLE types (
    -- raw source: types.jsonl _key
    id INTEGER,
    base_price FLOAT,
    capacity FLOAT,
    description_de TEXT,
    description_en TEXT,
    description_es TEXT,
    description_fr TEXT,
    description_ja TEXT,
    description_ko TEXT,
    description_ru TEXT,
    description_zh TEXT,
    -- СМЕШАННАЯ ссылка на неск. таблиц: factions, npcCorporations (без единого FK-constraint) — смешанная ссылка: для большинства типов — на factions.jsonl, но часть значений (10 из 33) на самом деле corporationID из npcCorporations.jsonl
    faction_id INTEGER,
    -- FK -> graphics (подтверждено, совпадение 97.9%)
    graphic_id INTEGER,
    -- FK -> groups (подтверждено, совпадение 100%)
    group_id INTEGER,
    -- FK -> icons (подтверждено, совпадение 100%)
    icon_id INTEGER,
    -- FK -> marketGroups (подтверждено, совпадение 100%)
    market_group_id INTEGER,
    mass FLOAT,
    -- FK -> metaGroups (подтверждено, совпадение 100%)
    meta_group_id INTEGER,
    meta_level INTEGER,
    name_de TEXT,
    name_en TEXT,
    name_es TEXT,
    name_fr TEXT,
    name_ja TEXT,
    name_ko TEXT,
    name_ru TEXT,
    name_zh TEXT,
    portion_size INTEGER,
    published BOOLEAN,
    -- FK -> races (подтверждено, совпадение 100%)
    race_id INTEGER,
    radius FLOAT,
    -- FK -> shipTreeGroups (подтверждено, совпадение 100%)
    ship_tree_group_id INTEGER,
    sound_id INTEGER,
    tech_level INTEGER,
    -- FK -> types (подтверждено, совпадение 100%); самоссылка
    variation_parent_type_id INTEGER,
    volume FLOAT,
    PRIMARY KEY (id)
);

-- =====================================================================
-- 2. ВНЕШНИЕ КЛЮЧИ (299 шт.)
-- Вынесены отдельно, чтобы избежать проблем с порядком создания таблиц
-- при циклических зависимостях. Для SQLite (не поддерживает ALTER TABLE
-- ADD CONSTRAINT) перенесите нужные FK внутрь CREATE TABLE вручную.
-- =====================================================================

ALTER TABLE agents_in_space ADD CONSTRAINT fk_agents_in_space_1 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE agents_in_space ADD CONSTRAINT fk_agents_in_space_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE ancestries ADD CONSTRAINT fk_ancestries_1 FOREIGN KEY (bloodline_id) REFERENCES bloodlines (id);
ALTER TABLE ancestries ADD CONSTRAINT fk_ancestries_2 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE bloodlines ADD CONSTRAINT fk_bloodlines_1 FOREIGN KEY (corporation_id) REFERENCES npc_corporations (id);
ALTER TABLE bloodlines ADD CONSTRAINT fk_bloodlines_2 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE bloodlines ADD CONSTRAINT fk_bloodlines_3 FOREIGN KEY (race_id) REFERENCES races (id);
ALTER TABLE blueprints ADD CONSTRAINT fk_blueprints_1 FOREIGN KEY (blueprint_type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_copying_materials ADD CONSTRAINT fk_blueprints_activities_copying_materials_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_copying_materials ADD CONSTRAINT fk_blueprints_activities_copying_materials_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_copying_skills ADD CONSTRAINT fk_blueprints_activities_copying_skills_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_copying_skills ADD CONSTRAINT fk_blueprints_activities_copying_skills_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_invention_materials ADD CONSTRAINT fk_blueprints_activities_invention_materials_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_invention_materials ADD CONSTRAINT fk_blueprints_activities_invention_materials_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_invention_products ADD CONSTRAINT fk_blueprints_activities_invention_products_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_invention_products ADD CONSTRAINT fk_blueprints_activities_invention_products_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_invention_skills ADD CONSTRAINT fk_blueprints_activities_invention_skills_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_invention_skills ADD CONSTRAINT fk_blueprints_activities_invention_skills_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_manufacturing_materials ADD CONSTRAINT fk_blueprints_activities_manufacturing_materials_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_manufacturing_materials ADD CONSTRAINT fk_blueprints_activities_manufacturing_materials_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_manufacturing_products ADD CONSTRAINT fk_blueprints_activities_manufacturing_products_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_manufacturing_products ADD CONSTRAINT fk_blueprints_activities_manufacturing_products_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_manufacturing_skills ADD CONSTRAINT fk_blueprints_activities_manufacturing_skills_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_manufacturing_skills ADD CONSTRAINT fk_blueprints_activities_manufacturing_skills_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_reaction_materials ADD CONSTRAINT fk_blueprints_activities_reaction_materials_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_reaction_materials ADD CONSTRAINT fk_blueprints_activities_reaction_materials_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_reaction_products ADD CONSTRAINT fk_blueprints_activities_reaction_products_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_reaction_products ADD CONSTRAINT fk_blueprints_activities_reaction_products_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_reaction_skills ADD CONSTRAINT fk_blueprints_activities_reaction_skills_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_reaction_skills ADD CONSTRAINT fk_blueprints_activities_reaction_skills_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_research_material_materials ADD CONSTRAINT fk_blueprints_activities_research_material_materials_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_research_material_materials ADD CONSTRAINT fk_blueprints_activities_research_material_materials_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_research_material_skills ADD CONSTRAINT fk_blueprints_activities_research_material_skills_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_research_material_skills ADD CONSTRAINT fk_blueprints_activities_research_material_skills_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_research_time_materials ADD CONSTRAINT fk_blueprints_activities_research_time_materials_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_research_time_materials ADD CONSTRAINT fk_blueprints_activities_research_time_materials_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE blueprints_activities_research_time_skills ADD CONSTRAINT fk_blueprints_activities_research_time_skills_1 FOREIGN KEY (blueprints_id) REFERENCES blueprints (id);
ALTER TABLE blueprints_activities_research_time_skills ADD CONSTRAINT fk_blueprints_activities_research_time_skills_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE categories ADD CONSTRAINT fk_categories_1 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE certificates ADD CONSTRAINT fk_certificates_1 FOREIGN KEY (group_id) REFERENCES item_groups (id);
ALTER TABLE certificates_recommended_for ADD CONSTRAINT fk_certificates_recommended_for_1 FOREIGN KEY (certificates_id) REFERENCES certificates (id);
ALTER TABLE certificates_skill_types ADD CONSTRAINT fk_certificates_skill_types_1 FOREIGN KEY (certificates_id) REFERENCES certificates (id);
ALTER TABLE certificates_skill_types ADD CONSTRAINT fk_certificates_skill_types_2 FOREIGN KEY (source_key) REFERENCES types (id);
ALTER TABLE clone_grades_skills ADD CONSTRAINT fk_clone_grades_skills_1 FOREIGN KEY (clone_grades_id) REFERENCES clone_grades (id);
ALTER TABLE clone_grades_skills ADD CONSTRAINT fk_clone_grades_skills_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE compressible_types ADD CONSTRAINT fk_compressible_types_1 FOREIGN KEY (compressed_type_id) REFERENCES types (id);
ALTER TABLE contraband_types_factions ADD CONSTRAINT fk_contraband_types_factions_1 FOREIGN KEY (contraband_types_id) REFERENCES contraband_types (id);
ALTER TABLE contraband_types_factions ADD CONSTRAINT fk_contraband_types_factions_2 FOREIGN KEY (source_key) REFERENCES factions (id);
ALTER TABLE control_tower_resources_resources ADD CONSTRAINT fk_control_tower_resources_resources_1 FOREIGN KEY (control_tower_resources_id) REFERENCES control_tower_resources (id);
ALTER TABLE control_tower_resources_resources ADD CONSTRAINT fk_control_tower_resources_resources_2 FOREIGN KEY (faction_id) REFERENCES factions (id);
ALTER TABLE control_tower_resources_resources ADD CONSTRAINT fk_control_tower_resources_resources_3 FOREIGN KEY (resource_type_id) REFERENCES types (id);
ALTER TABLE dbuff_collections_item_modifiers ADD CONSTRAINT fk_dbuff_collections_item_modifiers_1 FOREIGN KEY (dbuff_collections_id) REFERENCES dbuff_collections (id);
ALTER TABLE dbuff_collections_item_modifiers ADD CONSTRAINT fk_dbuff_collections_item_modifiers_2 FOREIGN KEY (dogma_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dbuff_collections_location_group_modifiers ADD CONSTRAINT fk_dbuff_collections_location_group_modifiers_1 FOREIGN KEY (dbuff_collections_id) REFERENCES dbuff_collections (id);
ALTER TABLE dbuff_collections_location_group_modifiers ADD CONSTRAINT fk_dbuff_collections_location_group_modifiers_2 FOREIGN KEY (dogma_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dbuff_collections_location_group_modifiers ADD CONSTRAINT fk_dbuff_collections_location_group_modifiers_3 FOREIGN KEY (group_id) REFERENCES item_groups (id);
ALTER TABLE dbuff_collections_location_modifiers ADD CONSTRAINT fk_dbuff_collections_location_modifiers_1 FOREIGN KEY (dbuff_collections_id) REFERENCES dbuff_collections (id);
ALTER TABLE dbuff_collections_location_modifiers ADD CONSTRAINT fk_dbuff_collections_location_modifiers_2 FOREIGN KEY (dogma_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dbuff_collections_location_required_skill_modifiers ADD CONSTRAINT fk_dbuff_collections_location_required_skill_modifiers_1 FOREIGN KEY (dbuff_collections_id) REFERENCES dbuff_collections (id);
ALTER TABLE dbuff_collections_location_required_skill_modifiers ADD CONSTRAINT fk_dbuff_collections_location_required_skill_modifiers_2 FOREIGN KEY (dogma_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dbuff_collections_location_required_skill_modifiers ADD CONSTRAINT fk_dbuff_collections_location_required_skill_modifiers_3 FOREIGN KEY (skill_id) REFERENCES types (id);
ALTER TABLE dogma_attributes ADD CONSTRAINT fk_dogma_attributes_1 FOREIGN KEY (attribute_category_id) REFERENCES dogma_attribute_categories (id);
ALTER TABLE dogma_attributes ADD CONSTRAINT fk_dogma_attributes_2 FOREIGN KEY (charge_recharge_time_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_attributes ADD CONSTRAINT fk_dogma_attributes_3 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE dogma_attributes ADD CONSTRAINT fk_dogma_attributes_4 FOREIGN KEY (max_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_attributes ADD CONSTRAINT fk_dogma_attributes_5 FOREIGN KEY (min_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_attributes ADD CONSTRAINT fk_dogma_attributes_6 FOREIGN KEY (unit_id) REFERENCES dogma_units (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_1 FOREIGN KEY (discharge_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_2 FOREIGN KEY (duration_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_3 FOREIGN KEY (falloff_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_4 FOREIGN KEY (fitting_usage_chance_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_5 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_6 FOREIGN KEY (npc_activation_chance_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_7 FOREIGN KEY (npc_usage_chance_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_8 FOREIGN KEY (range_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_9 FOREIGN KEY (resistance_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects ADD CONSTRAINT fk_dogma_effects_10 FOREIGN KEY (tracking_speed_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects_modifier_info ADD CONSTRAINT fk_dogma_effects_modifier_info_1 FOREIGN KEY (dogma_effects_id) REFERENCES dogma_effects (id);
ALTER TABLE dogma_effects_modifier_info ADD CONSTRAINT fk_dogma_effects_modifier_info_2 FOREIGN KEY (effect_id) REFERENCES dogma_effects (id);
ALTER TABLE dogma_effects_modifier_info ADD CONSTRAINT fk_dogma_effects_modifier_info_3 FOREIGN KEY (group_id) REFERENCES item_groups (id);
ALTER TABLE dogma_effects_modifier_info ADD CONSTRAINT fk_dogma_effects_modifier_info_4 FOREIGN KEY (modified_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects_modifier_info ADD CONSTRAINT fk_dogma_effects_modifier_info_5 FOREIGN KEY (modifying_attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE dogma_effects_modifier_info ADD CONSTRAINT fk_dogma_effects_modifier_info_6 FOREIGN KEY (skill_type_id) REFERENCES types (id);
ALTER TABLE dungeons ADD CONSTRAINT fk_dungeons_1 FOREIGN KEY (archetype_id) REFERENCES archetypes (id);
ALTER TABLE dungeons ADD CONSTRAINT fk_dungeons_2 FOREIGN KEY (faction_id) REFERENCES factions (id);
ALTER TABLE dungeons_allowed_ships_list ADD CONSTRAINT fk_dungeons_allowed_ships_list_1 FOREIGN KEY (dungeons_id) REFERENCES dungeons (id);
ALTER TABLE dynamic_item_attributes_attribute_ids ADD CONSTRAINT fk_dynamic_item_attributes_attribute_ids_1 FOREIGN KEY (dynamic_item_attributes_id) REFERENCES dynamic_item_attributes (id);
ALTER TABLE dynamic_item_attributes_attribute_ids ADD CONSTRAINT fk_dynamic_item_attributes_attribute_ids_2 FOREIGN KEY (source_key) REFERENCES dogma_attributes (id);
ALTER TABLE dynamic_item_attributes_input_output_mapping ADD CONSTRAINT fk_dynamic_item_attributes_input_output_mapping_1 FOREIGN KEY (dynamic_item_attributes_id) REFERENCES dynamic_item_attributes (id);
ALTER TABLE dynamic_item_attributes_input_output_mapping ADD CONSTRAINT fk_dynamic_item_attributes_input_output_mapping_2 FOREIGN KEY (resulting_type) REFERENCES types (id);
ALTER TABLE dynamic_item_attributes_input_output_mapping_applicab_543eea ADD CONSTRAINT fk_dynamic_item_attributes_input_output_mapping_applicab_ee56b3 FOREIGN KEY (dynamic_item_attributes_input_output_mapping_id) REFERENCES dynamic_item_attributes_input_output_mapping (id);
ALTER TABLE dynamic_item_attributes_input_output_mapping_applicab_543eea ADD CONSTRAINT fk_dynamic_item_attributes_input_output_mapping_applicab_dc545e FOREIGN KEY (value) REFERENCES types (id);
ALTER TABLE epic_arcs ADD CONSTRAINT fk_epic_arcs_1 FOREIGN KEY (faction_id) REFERENCES factions (id);
ALTER TABLE epic_arcs ADD CONSTRAINT fk_epic_arcs_2 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE epic_arcs_missions ADD CONSTRAINT fk_epic_arcs_missions_1 FOREIGN KEY (epic_arcs_id) REFERENCES epic_arcs (id);
ALTER TABLE epic_arcs_missions ADD CONSTRAINT fk_epic_arcs_missions_2 FOREIGN KEY (agent_id) REFERENCES npc_characters (id);
ALTER TABLE epic_arcs_missions_next_missions ADD CONSTRAINT fk_epic_arcs_missions_next_missions_1 FOREIGN KEY (epic_arcs_missions_id) REFERENCES epic_arcs_missions (id);
ALTER TABLE factions ADD CONSTRAINT fk_factions_1 FOREIGN KEY (corporation_id) REFERENCES npc_corporations (id);
ALTER TABLE factions ADD CONSTRAINT fk_factions_2 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE factions ADD CONSTRAINT fk_factions_3 FOREIGN KEY (militia_corporation_id) REFERENCES npc_corporations (id);
ALTER TABLE factions ADD CONSTRAINT fk_factions_4 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE factions_member_races ADD CONSTRAINT fk_factions_member_races_1 FOREIGN KEY (factions_id) REFERENCES factions (id);
ALTER TABLE factions_member_races ADD CONSTRAINT fk_factions_member_races_2 FOREIGN KEY (value) REFERENCES races (id);
ALTER TABLE freelance_job_schemas_value ADD CONSTRAINT fk_freelance_job_schemas_value_1 FOREIGN KEY (freelance_job_schemas_id) REFERENCES freelance_job_schemas (id);
ALTER TABLE freelance_job_schemas_value_content_tags ADD CONSTRAINT fk_freelance_job_schemas_value_content_tags_1 FOREIGN KEY (freelance_job_schemas_value_id) REFERENCES freelance_job_schemas_value (id);
ALTER TABLE freelance_job_schemas_value_parameters ADD CONSTRAINT fk_freelance_job_schemas_value_parameters_1 FOREIGN KEY (freelance_job_schemas_value_id) REFERENCES freelance_job_schemas_value (id);
ALTER TABLE freelance_job_schemas_value_parameters_item_delivery__b9d62a ADD CONSTRAINT fk_freelance_job_schemas_value_parameters_item_delivery__16550d FOREIGN KEY (freelance_job_schemas_value_parameters_id) REFERENCES freelance_job_schemas_value_parameters (id);
ALTER TABLE freelance_job_schemas_value_parameters_item_delivery__f0dfe3 ADD CONSTRAINT fk_freelance_job_schemas_value_parameters_item_delivery__fff83b FOREIGN KEY (freelance_job_schemas_value_parameters_id) REFERENCES freelance_job_schemas_value_parameters (id);
ALTER TABLE freelance_job_schemas_value_parameters_matcher_accept_9211f6 ADD CONSTRAINT fk_freelance_job_schemas_value_parameters_matcher_accept_7a78dc FOREIGN KEY (freelance_job_schemas_value_parameters_id) REFERENCES freelance_job_schemas_value_parameters (id);
ALTER TABLE graphics ADD CONSTRAINT fk_graphics_1 FOREIGN KEY (sof_material_set_id) REFERENCES graphic_material_sets (id);
ALTER TABLE graphics_sof_layout ADD CONSTRAINT fk_graphics_sof_layout_1 FOREIGN KEY (graphics_id) REFERENCES graphics (id);
ALTER TABLE item_groups ADD CONSTRAINT fk_item_groups_1 FOREIGN KEY (category_id) REFERENCES categories (id);
ALTER TABLE item_groups ADD CONSTRAINT fk_item_groups_2 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE landmarks ADD CONSTRAINT fk_landmarks_1 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE landmarks ADD CONSTRAINT fk_landmarks_2 FOREIGN KEY (location_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_asteroid_belts ADD CONSTRAINT fk_map_asteroid_belts_1 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_constellations ADD CONSTRAINT fk_map_constellations_1 FOREIGN KEY (faction_id) REFERENCES factions (id);
ALTER TABLE map_constellations ADD CONSTRAINT fk_map_constellations_2 FOREIGN KEY (region_id) REFERENCES map_regions (id);
ALTER TABLE map_constellations_solar_system_ids ADD CONSTRAINT fk_map_constellations_solar_system_ids_1 FOREIGN KEY (map_constellations_id) REFERENCES map_constellations (id);
ALTER TABLE map_constellations_solar_system_ids ADD CONSTRAINT fk_map_constellations_solar_system_ids_2 FOREIGN KEY (value) REFERENCES map_solar_systems (id);
ALTER TABLE map_moons ADD CONSTRAINT fk_map_moons_1 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_moons ADD CONSTRAINT fk_map_moons_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE map_moons_npc_station_ids ADD CONSTRAINT fk_map_moons_npc_station_ids_1 FOREIGN KEY (map_moons_id) REFERENCES map_moons (id);
ALTER TABLE map_moons_npc_station_ids ADD CONSTRAINT fk_map_moons_npc_station_ids_2 FOREIGN KEY (value) REFERENCES npc_stations (id);
ALTER TABLE map_planets ADD CONSTRAINT fk_map_planets_1 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_planets ADD CONSTRAINT fk_map_planets_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE map_planets_asteroid_belt_ids ADD CONSTRAINT fk_map_planets_asteroid_belt_ids_1 FOREIGN KEY (map_planets_id) REFERENCES map_planets (id);
ALTER TABLE map_planets_asteroid_belt_ids ADD CONSTRAINT fk_map_planets_asteroid_belt_ids_2 FOREIGN KEY (value) REFERENCES map_asteroid_belts (id);
ALTER TABLE map_planets_moon_ids ADD CONSTRAINT fk_map_planets_moon_ids_1 FOREIGN KEY (map_planets_id) REFERENCES map_planets (id);
ALTER TABLE map_planets_moon_ids ADD CONSTRAINT fk_map_planets_moon_ids_2 FOREIGN KEY (value) REFERENCES map_moons (id);
ALTER TABLE map_planets_npc_station_ids ADD CONSTRAINT fk_map_planets_npc_station_ids_1 FOREIGN KEY (map_planets_id) REFERENCES map_planets (id);
ALTER TABLE map_planets_npc_station_ids ADD CONSTRAINT fk_map_planets_npc_station_ids_2 FOREIGN KEY (value) REFERENCES npc_stations (id);
ALTER TABLE map_regions ADD CONSTRAINT fk_map_regions_1 FOREIGN KEY (faction_id) REFERENCES factions (id);
ALTER TABLE map_regions_constellation_ids ADD CONSTRAINT fk_map_regions_constellation_ids_1 FOREIGN KEY (map_regions_id) REFERENCES map_regions (id);
ALTER TABLE map_regions_constellation_ids ADD CONSTRAINT fk_map_regions_constellation_ids_2 FOREIGN KEY (value) REFERENCES map_constellations (id);
ALTER TABLE map_secondary_suns ADD CONSTRAINT fk_map_secondary_suns_1 FOREIGN KEY (effect_beacon_type_id) REFERENCES types (id);
ALTER TABLE map_secondary_suns ADD CONSTRAINT fk_map_secondary_suns_2 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_secondary_suns ADD CONSTRAINT fk_map_secondary_suns_3 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE map_solar_systems ADD CONSTRAINT fk_map_solar_systems_1 FOREIGN KEY (constellation_id) REFERENCES map_constellations (id);
ALTER TABLE map_solar_systems ADD CONSTRAINT fk_map_solar_systems_2 FOREIGN KEY (faction_id) REFERENCES factions (id);
ALTER TABLE map_solar_systems ADD CONSTRAINT fk_map_solar_systems_3 FOREIGN KEY (region_id) REFERENCES map_regions (id);
ALTER TABLE map_solar_systems ADD CONSTRAINT fk_map_solar_systems_4 FOREIGN KEY (star_id) REFERENCES map_stars (id);
ALTER TABLE map_solar_systems_disallowed_anchor_categories ADD CONSTRAINT fk_map_solar_systems_disallowed_anchor_categories_1 FOREIGN KEY (map_solar_systems_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_solar_systems_disallowed_anchor_categories ADD CONSTRAINT fk_map_solar_systems_disallowed_anchor_categories_2 FOREIGN KEY (value) REFERENCES categories (id);
ALTER TABLE map_solar_systems_disallowed_anchor_groups ADD CONSTRAINT fk_map_solar_systems_disallowed_anchor_groups_1 FOREIGN KEY (map_solar_systems_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_solar_systems_disallowed_anchor_groups ADD CONSTRAINT fk_map_solar_systems_disallowed_anchor_groups_2 FOREIGN KEY (value) REFERENCES item_groups (id);
ALTER TABLE map_solar_systems_planet_ids ADD CONSTRAINT fk_map_solar_systems_planet_ids_1 FOREIGN KEY (map_solar_systems_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_solar_systems_planet_ids ADD CONSTRAINT fk_map_solar_systems_planet_ids_2 FOREIGN KEY (value) REFERENCES map_planets (id);
ALTER TABLE map_solar_systems_stargate_ids ADD CONSTRAINT fk_map_solar_systems_stargate_ids_1 FOREIGN KEY (map_solar_systems_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_solar_systems_stargate_ids ADD CONSTRAINT fk_map_solar_systems_stargate_ids_2 FOREIGN KEY (value) REFERENCES map_stargates (id);
ALTER TABLE map_stargates ADD CONSTRAINT fk_map_stargates_1 FOREIGN KEY (destination_solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_stargates ADD CONSTRAINT fk_map_stargates_2 FOREIGN KEY (destination_stargate_id) REFERENCES map_stargates (id);
ALTER TABLE map_stargates ADD CONSTRAINT fk_map_stargates_3 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_stargates ADD CONSTRAINT fk_map_stargates_4 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE map_stars ADD CONSTRAINT fk_map_stars_1 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE map_stars ADD CONSTRAINT fk_map_stars_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE market_groups ADD CONSTRAINT fk_market_groups_1 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE market_groups ADD CONSTRAINT fk_market_groups_2 FOREIGN KEY (parent_group_id) REFERENCES market_groups (id);
ALTER TABLE masteries_value ADD CONSTRAINT fk_masteries_value_1 FOREIGN KEY (masteries_id) REFERENCES masteries (id);
ALTER TABLE masteries_value_value ADD CONSTRAINT fk_masteries_value_value_1 FOREIGN KEY (masteries_value_id) REFERENCES masteries_value (id);
ALTER TABLE masteries_value_value ADD CONSTRAINT fk_masteries_value_value_2 FOREIGN KEY (value) REFERENCES certificates (id);
ALTER TABLE mercenary_tactical_operations ADD CONSTRAINT fk_mercenary_tactical_operations_1 FOREIGN KEY (dungeon_id) REFERENCES dungeons (id);
ALTER TABLE meta_groups ADD CONSTRAINT fk_meta_groups_1 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE military_campaign_objectives ADD CONSTRAINT fk_military_campaign_objectives_1 FOREIGN KEY (campaign_id) REFERENCES military_campaigns (id);
ALTER TABLE military_campaign_objectives ADD CONSTRAINT fk_military_campaign_objectives_2 FOREIGN KEY (issuer_corporation_id) REFERENCES npc_corporations (id);
ALTER TABLE military_campaign_objectives ADD CONSTRAINT fk_military_campaign_objectives_3 FOREIGN KEY (presenting_character_id) REFERENCES npc_characters (id);
ALTER TABLE military_campaign_objectives ADD CONSTRAINT fk_military_campaign_objectives_4 FOREIGN KEY (rewards_isk_issuer_corporation_id) REFERENCES npc_corporations (id);
ALTER TABLE military_campaign_objectives ADD CONSTRAINT fk_military_campaign_objectives_5 FOREIGN KEY (rewards_lp_issuer_corporation_id) REFERENCES npc_corporations (id);
ALTER TABLE military_campaign_objectives ADD CONSTRAINT fk_military_campaign_objectives_6 FOREIGN KEY (rewards_standing_issuer_faction_id) REFERENCES factions (id);
ALTER TABLE military_campaign_objectives_content_tags ADD CONSTRAINT fk_military_campaign_objectives_content_tags_1 FOREIGN KEY (military_campaign_objectives_id) REFERENCES military_campaign_objectives (id);
ALTER TABLE military_campaign_objectives_contribution_method_conf_00852c ADD CONSTRAINT fk_military_campaign_objectives_contribution_method_conf_abf439 FOREIGN KEY (military_campaign_objectives_id) REFERENCES military_campaign_objectives (id);
ALTER TABLE military_campaign_objectives_contribution_method_conf_57d6be ADD CONSTRAINT fk_military_campaign_objectives_contribution_method_conf_0da802 FOREIGN KEY (military_campaign_objectives_contribution_method_conf_00852c_id) REFERENCES military_campaign_objectives_contribution_method_conf_00852c (id);
ALTER TABLE military_campaign_objectives_contribution_method_conf_4c7001 ADD CONSTRAINT fk_military_campaign_objectives_contribution_method_conf_468efb FOREIGN KEY (military_campaign_objectives_contribution_method_conf_57d6be_id) REFERENCES military_campaign_objectives_contribution_method_conf_57d6be (id);
ALTER TABLE military_campaigns ADD CONSTRAINT fk_military_campaigns_1 FOREIGN KEY (issuer_faction_id) REFERENCES factions (id);
ALTER TABLE missions ADD CONSTRAINT fk_missions_1 FOREIGN KEY (agent_type_id) REFERENCES agent_types (id);
ALTER TABLE missions ADD CONSTRAINT fk_missions_2 FOREIGN KEY (corporation_id) REFERENCES npc_corporations (id);
ALTER TABLE missions ADD CONSTRAINT fk_missions_3 FOREIGN KEY (courier_mission_objective_type_id) REFERENCES types (id);
ALTER TABLE missions ADD CONSTRAINT fk_missions_4 FOREIGN KEY (faction_id) REFERENCES factions (id);
ALTER TABLE missions ADD CONSTRAINT fk_missions_5 FOREIGN KEY (initial_agent_gift_type_id) REFERENCES types (id);
ALTER TABLE missions ADD CONSTRAINT fk_missions_6 FOREIGN KEY (kill_mission_objective_type_id) REFERENCES types (id);
ALTER TABLE missions ADD CONSTRAINT fk_missions_7 FOREIGN KEY (mission_rewards_bonus_reward_reward_type_id) REFERENCES types (id);
ALTER TABLE missions ADD CONSTRAINT fk_missions_8 FOREIGN KEY (mission_rewards_reward_reward_type_id) REFERENCES types (id);
ALTER TABLE missions_extra_standings ADD CONSTRAINT fk_missions_extra_standings_1 FOREIGN KEY (missions_id) REFERENCES missions (id);
ALTER TABLE missions_extra_standings ADD CONSTRAINT fk_missions_extra_standings_2 FOREIGN KEY (source_key) REFERENCES factions (id);
ALTER TABLE missions_messages ADD CONSTRAINT fk_missions_messages_1 FOREIGN KEY (missions_id) REFERENCES missions (id);
ALTER TABLE npc_characters ADD CONSTRAINT fk_npc_characters_1 FOREIGN KEY (agent_agent_type_id) REFERENCES agent_types (id);
ALTER TABLE npc_characters ADD CONSTRAINT fk_npc_characters_2 FOREIGN KEY (agent_division_id) REFERENCES npc_corporation_divisions (id);
ALTER TABLE npc_characters ADD CONSTRAINT fk_npc_characters_3 FOREIGN KEY (ancestry_id) REFERENCES ancestries (id);
ALTER TABLE npc_characters ADD CONSTRAINT fk_npc_characters_4 FOREIGN KEY (bloodline_id) REFERENCES bloodlines (id);
ALTER TABLE npc_characters ADD CONSTRAINT fk_npc_characters_5 FOREIGN KEY (corporation_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_characters ADD CONSTRAINT fk_npc_characters_6 FOREIGN KEY (location_id) REFERENCES npc_stations (id);
ALTER TABLE npc_characters ADD CONSTRAINT fk_npc_characters_7 FOREIGN KEY (race_id) REFERENCES races (id);
ALTER TABLE npc_characters_skills ADD CONSTRAINT fk_npc_characters_skills_1 FOREIGN KEY (npc_characters_id) REFERENCES npc_characters (id);
ALTER TABLE npc_characters_skills ADD CONSTRAINT fk_npc_characters_skills_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_1 FOREIGN KEY (ceo_id) REFERENCES npc_characters (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_2 FOREIGN KEY (enemy_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_3 FOREIGN KEY (faction_id) REFERENCES factions (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_4 FOREIGN KEY (friend_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_5 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_6 FOREIGN KEY (main_activity_id) REFERENCES corporation_activities (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_7 FOREIGN KEY (race_id) REFERENCES races (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_8 FOREIGN KEY (secondary_activity_id) REFERENCES corporation_activities (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_9 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE npc_corporations ADD CONSTRAINT fk_npc_corporations_10 FOREIGN KEY (station_id) REFERENCES npc_stations (id);
ALTER TABLE npc_corporations_allowed_member_races ADD CONSTRAINT fk_npc_corporations_allowed_member_races_1 FOREIGN KEY (npc_corporations_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_corporations_allowed_member_races ADD CONSTRAINT fk_npc_corporations_allowed_member_races_2 FOREIGN KEY (value) REFERENCES races (id);
ALTER TABLE npc_corporations_corporation_trades ADD CONSTRAINT fk_npc_corporations_corporation_trades_1 FOREIGN KEY (npc_corporations_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_corporations_corporation_trades ADD CONSTRAINT fk_npc_corporations_corporation_trades_2 FOREIGN KEY (source_key) REFERENCES types (id);
ALTER TABLE npc_corporations_divisions ADD CONSTRAINT fk_npc_corporations_divisions_1 FOREIGN KEY (npc_corporations_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_corporations_divisions ADD CONSTRAINT fk_npc_corporations_divisions_2 FOREIGN KEY (leader_id) REFERENCES npc_characters (id);
ALTER TABLE npc_corporations_exchange_rates ADD CONSTRAINT fk_npc_corporations_exchange_rates_1 FOREIGN KEY (npc_corporations_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_corporations_exchange_rates ADD CONSTRAINT fk_npc_corporations_exchange_rates_2 FOREIGN KEY (source_key) REFERENCES npc_corporations (id);
ALTER TABLE npc_corporations_investors ADD CONSTRAINT fk_npc_corporations_investors_1 FOREIGN KEY (npc_corporations_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_corporations_investors ADD CONSTRAINT fk_npc_corporations_investors_2 FOREIGN KEY (source_key) REFERENCES npc_corporations (id);
ALTER TABLE npc_corporations_lp_offer_tables ADD CONSTRAINT fk_npc_corporations_lp_offer_tables_1 FOREIGN KEY (npc_corporations_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_stations ADD CONSTRAINT fk_npc_stations_1 FOREIGN KEY (operation_id) REFERENCES station_operations (id);
ALTER TABLE npc_stations ADD CONSTRAINT fk_npc_stations_2 FOREIGN KEY (owner_id) REFERENCES npc_corporations (id);
ALTER TABLE npc_stations ADD CONSTRAINT fk_npc_stations_3 FOREIGN KEY (solar_system_id) REFERENCES map_solar_systems (id);
ALTER TABLE npc_stations ADD CONSTRAINT fk_npc_stations_4 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE planet_resources ADD CONSTRAINT fk_planet_resources_1 FOREIGN KEY (reagent_type_id) REFERENCES types (id);
ALTER TABLE planet_schematics_pins ADD CONSTRAINT fk_planet_schematics_pins_1 FOREIGN KEY (planet_schematics_id) REFERENCES planet_schematics (id);
ALTER TABLE planet_schematics_pins ADD CONSTRAINT fk_planet_schematics_pins_2 FOREIGN KEY (value) REFERENCES types (id);
ALTER TABLE planet_schematics_types ADD CONSTRAINT fk_planet_schematics_types_1 FOREIGN KEY (planet_schematics_id) REFERENCES planet_schematics (id);
ALTER TABLE planet_schematics_types ADD CONSTRAINT fk_planet_schematics_types_2 FOREIGN KEY (source_key) REFERENCES types (id);
ALTER TABLE races ADD CONSTRAINT fk_races_1 FOREIGN KEY (ship_type_id) REFERENCES types (id);
ALTER TABLE races_skills ADD CONSTRAINT fk_races_skills_1 FOREIGN KEY (races_id) REFERENCES races (id);
ALTER TABLE races_skills ADD CONSTRAINT fk_races_skills_2 FOREIGN KEY (source_key) REFERENCES types (id);
ALTER TABLE ship_tree_factions_elements ADD CONSTRAINT fk_ship_tree_factions_elements_1 FOREIGN KEY (ship_tree_factions_id) REFERENCES ship_tree_factions (id);
ALTER TABLE ship_tree_factions_elements ADD CONSTRAINT fk_ship_tree_factions_elements_2 FOREIGN KEY (value) REFERENCES ship_tree_elements (id);
ALTER TABLE ship_tree_groups_elements ADD CONSTRAINT fk_ship_tree_groups_elements_1 FOREIGN KEY (ship_tree_groups_id) REFERENCES ship_tree_groups (id);
ALTER TABLE ship_tree_groups_elements ADD CONSTRAINT fk_ship_tree_groups_elements_2 FOREIGN KEY (value) REFERENCES ship_tree_elements (id);
ALTER TABLE ship_tree_groups_pre_req_skills ADD CONSTRAINT fk_ship_tree_groups_pre_req_skills_1 FOREIGN KEY (ship_tree_groups_id) REFERENCES ship_tree_groups (id);
ALTER TABLE ship_tree_groups_pre_req_skills_skills ADD CONSTRAINT fk_ship_tree_groups_pre_req_skills_skills_1 FOREIGN KEY (ship_tree_groups_pre_req_skills_id) REFERENCES ship_tree_groups_pre_req_skills (id);
ALTER TABLE ship_tree_groups_pre_req_skills_skills ADD CONSTRAINT fk_ship_tree_groups_pre_req_skills_skills_2 FOREIGN KEY (source_key) REFERENCES types (id);
ALTER TABLE skin_licenses ADD CONSTRAINT fk_skin_licenses_1 FOREIGN KEY (license_type_id) REFERENCES types (id);
ALTER TABLE skin_licenses ADD CONSTRAINT fk_skin_licenses_2 FOREIGN KEY (skin_id) REFERENCES skins (id);
ALTER TABLE skin_materials ADD CONSTRAINT fk_skin_materials_1 FOREIGN KEY (material_set_id) REFERENCES graphic_material_sets (id);
ALTER TABLE skinr_component_point_values_value ADD CONSTRAINT fk_skinr_component_point_values_value_1 FOREIGN KEY (skinr_component_point_values_id) REFERENCES skinr_component_point_values (id);
ALTER TABLE skinr_component_point_values_value ADD CONSTRAINT fk_skinr_component_point_values_value_2 FOREIGN KEY (source_key) REFERENCES skinr_component_rarities (id);
ALTER TABLE skinr_components ADD CONSTRAINT fk_skinr_components_1 FOREIGN KEY (category) REFERENCES skinr_component_categories (id);
ALTER TABLE skinr_components ADD CONSTRAINT fk_skinr_components_2 FOREIGN KEY (rarity) REFERENCES skinr_component_rarities (id);
ALTER TABLE skinr_components ADD CONSTRAINT fk_skinr_components_3 FOREIGN KEY (sequence_binder_item_type_id) REFERENCES types (id);
ALTER TABLE skinr_components_associated_type_ids ADD CONSTRAINT fk_skinr_components_associated_type_ids_1 FOREIGN KEY (skinr_components_id) REFERENCES skinr_components (id);
ALTER TABLE skinr_components_associated_type_ids ADD CONSTRAINT fk_skinr_components_associated_type_ids_2 FOREIGN KEY (type_id) REFERENCES types (id);
ALTER TABLE skinr_slot_configurations_config ADD CONSTRAINT fk_skinr_slot_configurations_config_1 FOREIGN KEY (skinr_slot_configurations_id) REFERENCES skinr_slot_configurations (id);
ALTER TABLE skinr_slot_configurations_config ADD CONSTRAINT fk_skinr_slot_configurations_config_2 FOREIGN KEY (value) REFERENCES skinr_slots (id);
ALTER TABLE skinr_slot_configurations_ships ADD CONSTRAINT fk_skinr_slot_configurations_ships_1 FOREIGN KEY (skinr_slot_configurations_id) REFERENCES skinr_slot_configurations (id);
ALTER TABLE skinr_slot_configurations_ships ADD CONSTRAINT fk_skinr_slot_configurations_ships_2 FOREIGN KEY (value) REFERENCES types (id);
ALTER TABLE skinr_slots ADD CONSTRAINT fk_skinr_slots_1 FOREIGN KEY (category) REFERENCES skinr_slot_categories (id);
ALTER TABLE skinr_slots_allowed_design_component_categories ADD CONSTRAINT fk_skinr_slots_allowed_design_component_categories_1 FOREIGN KEY (skinr_slots_id) REFERENCES skinr_slots (id);
ALTER TABLE skinr_slots_allowed_design_component_categories ADD CONSTRAINT fk_skinr_slots_allowed_design_component_categories_2 FOREIGN KEY (value) REFERENCES skinr_component_categories (id);
ALTER TABLE skinr_tier_thresholds_value ADD CONSTRAINT fk_skinr_tier_thresholds_value_1 FOREIGN KEY (skinr_tier_thresholds_id) REFERENCES skinr_tier_thresholds (id);
ALTER TABLE skins ADD CONSTRAINT fk_skins_1 FOREIGN KEY (skin_material_id) REFERENCES skin_materials (id);
ALTER TABLE skins_types ADD CONSTRAINT fk_skins_types_1 FOREIGN KEY (skins_id) REFERENCES skins (id);
ALTER TABLE skins_types ADD CONSTRAINT fk_skins_types_2 FOREIGN KEY (value) REFERENCES types (id);
ALTER TABLE sovereignty_upgrades ADD CONSTRAINT fk_sovereignty_upgrades_1 FOREIGN KEY (fuel_type_id) REFERENCES types (id);
ALTER TABLE station_operations ADD CONSTRAINT fk_station_operations_1 FOREIGN KEY (activity_id) REFERENCES corporation_activities (id);
ALTER TABLE station_operations_services ADD CONSTRAINT fk_station_operations_services_1 FOREIGN KEY (station_operations_id) REFERENCES station_operations (id);
ALTER TABLE station_operations_services ADD CONSTRAINT fk_station_operations_services_2 FOREIGN KEY (value) REFERENCES station_services (id);
ALTER TABLE station_operations_station_types ADD CONSTRAINT fk_station_operations_station_types_1 FOREIGN KEY (station_operations_id) REFERENCES station_operations (id);
ALTER TABLE type_bonus ADD CONSTRAINT fk_type_bonus_1 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE type_bonus_misc_bonuses ADD CONSTRAINT fk_type_bonus_misc_bonuses_1 FOREIGN KEY (type_bonus_id) REFERENCES type_bonus (id);
ALTER TABLE type_bonus_misc_bonuses ADD CONSTRAINT fk_type_bonus_misc_bonuses_2 FOREIGN KEY (unit_id) REFERENCES dogma_units (id);
ALTER TABLE type_bonus_role_bonuses ADD CONSTRAINT fk_type_bonus_role_bonuses_1 FOREIGN KEY (type_bonus_id) REFERENCES type_bonus (id);
ALTER TABLE type_bonus_role_bonuses ADD CONSTRAINT fk_type_bonus_role_bonuses_2 FOREIGN KEY (unit_id) REFERENCES dogma_units (id);
ALTER TABLE type_bonus_types ADD CONSTRAINT fk_type_bonus_types_1 FOREIGN KEY (type_bonus_id) REFERENCES type_bonus (id);
ALTER TABLE type_bonus_types ADD CONSTRAINT fk_type_bonus_types_2 FOREIGN KEY (source_key) REFERENCES types (id);
ALTER TABLE type_bonus_types_value ADD CONSTRAINT fk_type_bonus_types_value_1 FOREIGN KEY (type_bonus_types_id) REFERENCES type_bonus_types (id);
ALTER TABLE type_bonus_types_value ADD CONSTRAINT fk_type_bonus_types_value_2 FOREIGN KEY (unit_id) REFERENCES dogma_units (id);
ALTER TABLE type_dogma_dogma_attributes ADD CONSTRAINT fk_type_dogma_dogma_attributes_1 FOREIGN KEY (type_dogma_id) REFERENCES type_dogma (id);
ALTER TABLE type_dogma_dogma_attributes ADD CONSTRAINT fk_type_dogma_dogma_attributes_2 FOREIGN KEY (attribute_id) REFERENCES dogma_attributes (id);
ALTER TABLE type_dogma_dogma_effects ADD CONSTRAINT fk_type_dogma_dogma_effects_1 FOREIGN KEY (type_dogma_id) REFERENCES type_dogma (id);
ALTER TABLE type_dogma_dogma_effects ADD CONSTRAINT fk_type_dogma_dogma_effects_2 FOREIGN KEY (effect_id) REFERENCES dogma_effects (id);
ALTER TABLE type_elements_elements ADD CONSTRAINT fk_type_elements_elements_1 FOREIGN KEY (type_elements_id) REFERENCES type_elements (id);
ALTER TABLE type_elements_elements ADD CONSTRAINT fk_type_elements_elements_2 FOREIGN KEY (source_key) REFERENCES types (id);
ALTER TABLE type_lists_excluded_category_ids ADD CONSTRAINT fk_type_lists_excluded_category_ids_1 FOREIGN KEY (type_lists_id) REFERENCES type_lists (id);
ALTER TABLE type_lists_excluded_category_ids ADD CONSTRAINT fk_type_lists_excluded_category_ids_2 FOREIGN KEY (value) REFERENCES categories (id);
ALTER TABLE type_lists_excluded_group_ids ADD CONSTRAINT fk_type_lists_excluded_group_ids_1 FOREIGN KEY (type_lists_id) REFERENCES type_lists (id);
ALTER TABLE type_lists_excluded_group_ids ADD CONSTRAINT fk_type_lists_excluded_group_ids_2 FOREIGN KEY (value) REFERENCES item_groups (id);
ALTER TABLE type_lists_excluded_type_ids ADD CONSTRAINT fk_type_lists_excluded_type_ids_1 FOREIGN KEY (type_lists_id) REFERENCES type_lists (id);
ALTER TABLE type_lists_excluded_type_ids ADD CONSTRAINT fk_type_lists_excluded_type_ids_2 FOREIGN KEY (value) REFERENCES types (id);
ALTER TABLE type_lists_included_category_ids ADD CONSTRAINT fk_type_lists_included_category_ids_1 FOREIGN KEY (type_lists_id) REFERENCES type_lists (id);
ALTER TABLE type_lists_included_category_ids ADD CONSTRAINT fk_type_lists_included_category_ids_2 FOREIGN KEY (value) REFERENCES categories (id);
ALTER TABLE type_lists_included_group_ids ADD CONSTRAINT fk_type_lists_included_group_ids_1 FOREIGN KEY (type_lists_id) REFERENCES type_lists (id);
ALTER TABLE type_lists_included_group_ids ADD CONSTRAINT fk_type_lists_included_group_ids_2 FOREIGN KEY (value) REFERENCES item_groups (id);
ALTER TABLE type_lists_included_type_ids ADD CONSTRAINT fk_type_lists_included_type_ids_1 FOREIGN KEY (type_lists_id) REFERENCES type_lists (id);
ALTER TABLE type_lists_included_type_ids ADD CONSTRAINT fk_type_lists_included_type_ids_2 FOREIGN KEY (value) REFERENCES types (id);
ALTER TABLE type_materials_materials ADD CONSTRAINT fk_type_materials_materials_1 FOREIGN KEY (type_materials_id) REFERENCES type_materials (id);
ALTER TABLE type_materials_materials ADD CONSTRAINT fk_type_materials_materials_2 FOREIGN KEY (material_type_id) REFERENCES types (id);
ALTER TABLE type_materials_randomized_materials ADD CONSTRAINT fk_type_materials_randomized_materials_1 FOREIGN KEY (type_materials_id) REFERENCES type_materials (id);
ALTER TABLE type_materials_randomized_materials ADD CONSTRAINT fk_type_materials_randomized_materials_2 FOREIGN KEY (material_type_id) REFERENCES types (id);
ALTER TABLE types ADD CONSTRAINT fk_types_1 FOREIGN KEY (graphic_id) REFERENCES graphics (id);
ALTER TABLE types ADD CONSTRAINT fk_types_2 FOREIGN KEY (group_id) REFERENCES item_groups (id);
ALTER TABLE types ADD CONSTRAINT fk_types_3 FOREIGN KEY (icon_id) REFERENCES icons (id);
ALTER TABLE types ADD CONSTRAINT fk_types_4 FOREIGN KEY (market_group_id) REFERENCES market_groups (id);
ALTER TABLE types ADD CONSTRAINT fk_types_5 FOREIGN KEY (meta_group_id) REFERENCES meta_groups (id);
ALTER TABLE types ADD CONSTRAINT fk_types_6 FOREIGN KEY (race_id) REFERENCES races (id);
ALTER TABLE types ADD CONSTRAINT fk_types_7 FOREIGN KEY (ship_tree_group_id) REFERENCES ship_tree_groups (id);
ALTER TABLE types ADD CONSTRAINT fk_types_8 FOREIGN KEY (variation_parent_type_id) REFERENCES types (id);
