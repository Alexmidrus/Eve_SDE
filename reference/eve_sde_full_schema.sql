-- CHANGELOG 2026-07-09 (ревизия схемы):
--   * Исправлены висячие запятые в CREATE TABLE dim_items / dim_universe.
--   * 9 промежуточным таблицам с дочерними таблицами (epic_arcs_missions,
--     masteries_value, type_bonus_types и др.) добавлен суррогатный PK id
--     (присваивается ETL); натуральный ключ (parent_id, seq) сохранён как UNIQUE.
--     Это чинит 12 FK, ссылавшихся на несуществующую колонку id.
--   * Удалены 95 избыточных индексов, дублировавших префикс PK/UNIQUE.
-- =====================================================================================
-- EVE Online SDE (Static Data Export) -- ПОЛНАЯ СХЕМА БАЗЫ ДАННЫХ
-- Один файл: сырой слой (1 файл SDE = 1 таблица) + оптимизированный слой
-- (индексы, денормализованные витрины, пивот dogma-атрибутов, консолидация
-- производственных таблиц). Собрано на основе SDE_schema_report.md
-- (анализ 79 .jsonl файлов SDE + проверенные сверкой данных внешние ключи).
--
-- СТРУКТУРА ЭТОГО ФАЙЛА
-- =====================================================================================
--   ЧАСТЬ I.  RAW-СЛОЙ           (79 корневых + 95 дочерних таблиц = 174)
--             I.1  CREATE TABLE для всех 174 таблиц
--             I.2  FOREIGN KEY (299 constraint'ов, отдельным блоком)
--
--   ЧАСТЬ II. ОПТИМИЗИРОВАННЫЙ СЛОЙ  (8 таблиц поверх raw-слоя)
--             II.A  Индексы (322: все FK-колонки raw-слоя + горячие поля)
--             II.B  dim_items, dim_universe  (денормализованные витрины)
--             II.C  type_common_stats        (пивот 67 dogma-атрибутов)
--             II.D  industry_*               (консолидация 18 -> 4 таблиц чертежей)
--             II.E  dim_agents                (агенты NPC с полным контекстом)
--
-- ПОРЯДОК РАЗВЁРТЫВАНИЯ
-- =====================================================================================
--   1) Выполнить целиком ЧАСТЬ I -- создаст все raw-таблицы 1:1 с файлами SDE.
--   2) Загрузить данные из .jsonl в raw-таблицы (ETL, вне этого файла).
--   3) Выполнить целиком ЧАСТЬ II -- создаст индексы и построит витрины/пивоты
--      из уже загруженных raw-данных (INSERT...SELECT).
--   4) При каждом обновлении SDE (патч игры): повторить ETL для raw-таблиц,
--      затем перезапустить блоки DELETE+INSERT из ЧАСТИ II.
--
-- ПРИНЦИПЫ RAW-СЛОЯ (ЧАСТЬ I)
-- =====================================================================================
--   * Каждый исходный .jsonl файл -> одна "корневая" таблица (без нормализации
--     справочников -- это сделано в ЧАСТИ II).
--   * Каждый вложенный массив -> отдельная дочерняя таблица с составным
--     первичным ключом (<родитель>_id, seq).
--   * Вложенные объекты (не массивы) выровнены (flatten) в колонки родителя.
--   * Локализованные строки разложены в 8 колонок (_de/_en/_es/_fr/_ja/_ko/_ru/_zh).
--   * Внешние ключи вынесены в отдельный блок ALTER TABLE (избегаем проблем
--     с порядком создания при циклических зависимостях, напр.
--     npc_corporations <-> npc_characters).
--   * Поля, похожие на FK по имени, но не являющиеся им (проверено сверкой
--     реальных данных), и поля со смешанной целью -- оставлены как обычные
--     колонки с поясняющим комментарием, без ложного FK-ограничения.
--
-- ПРИНЦИПЫ ОПТИМИЗИРОВАННОГО СЛОЯ (ЧАСТЬ II)
-- =====================================================================================
--   * Физические таблицы (не VIEW): SDE обновляется только патчами игры,
--     пересчитывать JOIN на каждый запрос библиотеки не нужно.
--   * EAV-атрибуты (dogma) развёрнуты в именованные колонки для самых
--     востребованных случаев -- редкие атрибуты остаются в raw-таблице.
--   * Повторяющиеся по структуре raw-таблицы (18 таблиц чертежей) сведены
--     к 4 таблицам с колонкой-дискриминатором activity_type.
--
-- СОВМЕСТИМОСТЬ
-- =====================================================================================
--   Только ANSI-подмножество: INTEGER, FLOAT, VARCHAR(n), TEXT, BOOLEAN,
--   CREATE INDEX, ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY.
--   Работает на MySQL, PostgreSQL, SQL Server, Oracle (с точностью до
--   маппинга BOOLEAN/TEXT, см. комментарии в тексте), SQLite -- кроме
--   ALTER TABLE ADD CONSTRAINT (перенесите такие FK в CREATE TABLE вручную).
--   Импорт в dbdesigner.net: Schema -> Import, диалект MySQL или PostgreSQL.
--
-- СПИСОК ТАБЛИЦ ЧАСТИ I (корневые, 1:1 с исходными .jsonl файлами)
-- =====================================================================================
--   agent_types, agents_in_space, ancestries, archetypes, bloodlines, blueprints
--   categories, certificates, character_attributes, character_titles, clone_grades, compressible_types
--   contraband_types, control_tower_resources, corporation_activities, dbuff_collections, dogma_attribute_categories, dogma_attributes
--   dogma_effects, dogma_units, dungeons, dynamic_item_attributes, epic_arcs, factions
--   freelance_job_schemas, graphic_material_sets, graphics, icons, item_groups, landmarks
--   map_asteroid_belts, map_constellations, map_moons, map_planets, map_regions, map_secondary_suns
--   map_solar_systems, map_stargates, map_stars, market_groups, masteries, mercenary_tactical_operations
--   meta_groups, military_campaign_objectives, military_campaigns, missions, npc_characters, npc_corporation_divisions
--   npc_corporations, npc_stations, planet_resources, planet_schematics, races, sde
--   ship_tree_elements, ship_tree_factions, ship_tree_groups, skin_licenses, skin_materials, skinr_component_categories
--   skinr_component_point_values, skinr_component_rarities, skinr_components, skinr_slot_categories, skinr_slot_configurations, skinr_slot_names
--   skinr_slots, skinr_tier_thresholds, skins, sovereignty_upgrades, station_operations, station_services
--   translation_languages, type_bonus, type_dogma, type_elements, type_lists, type_materials
--   types
--
-- (+ 95 дочерних таблиц для вложенных массивов -- см. имена вида
--   <корневая>_<поле> в самой схеме, например blueprints_activities_copying_materials)
--
-- СПИСОК ТАБЛИЦ ЧАСТИ II (оптимизированный слой)
-- =====================================================================================
--   dim_items, dim_universe, type_common_stats, industry_activities, industry_materials, industry_products
--   industry_skills, dim_agents
-- =====================================================================================


-- #####################################################################################
-- # ЧАСТЬ I. RAW-СЛОЙ (1 файл SDE = 1 таблица)
-- #####################################################################################

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


-- #####################################################################################
-- # ЧАСТЬ II. ОПТИМИЗИРОВАННЫЙ СЛОЙ (индексы, витрины, пивоты, консолидация)
-- #####################################################################################

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


