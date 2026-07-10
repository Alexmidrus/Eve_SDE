"""Тесты чистых функций etl/transform.py.

Часть тестов работает на реальном manifest.json (T02) с мини-примерами
записей types.jsonl/blueprints.jsonl/epicArcs.jsonl/masteries.jsonl,
построенными по SDE_schema_report.md. Часть -- на маленьком синтетическом
манифесте (аналогично tests/unit/test_gen_manifest.py), где удобнее точечно
проверить суррогатные id и обработку неизвестных полей.
"""

from __future__ import annotations

import logging
from typing import Any

import pytest

from evesde.etl.transform import IdAllocator, TransformReport, camel_to_snake, transform_record
from evesde.schema.builder import load_manifest


@pytest.fixture(scope="module")
def manifest() -> dict[str, Any]:
    return load_manifest()


# ---------------------------------------------------------------------------
# camel_to_snake
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("source", "expected"),
    [
        ("typeID", "type_id"),
        ("blueprintTypeID", "blueprint_type_id"),
        ("planetIDs", "planet_ids"),
        ("stargateIDs", "stargate_ids"),
        ("attributeIDs", "attribute_ids"),
        ("highIsGood", "high_is_good"),
        ("position2D", "position2_d"),
        ("nextMissions", "next_missions"),
    ],
)
def test_camel_to_snake(source: str, expected: str) -> None:
    assert camel_to_snake(source) == expected


# ---------------------------------------------------------------------------
# types.jsonl -- плоская запись, только скаляры + локализованные объекты
# ---------------------------------------------------------------------------


def test_types_record(manifest: dict[str, Any]) -> None:
    record = {
        "_key": 587,
        "basePrice": 84177.0,
        "capacity": 130.0,
        "description": {
            "de": "de-text",
            "en": "The Rifter is a fast attack frigate.",
            "es": "es-text",
            "fr": "fr-text",
            "ja": "ja-text",
            "ko": "ko-text",
            "ru": "ru-text",
            "zh": "zh-text",
        },
        "factionID": None,
        "graphicID": 22,
        "groupID": 25,
        "iconID": 622,
        "marketGroupID": 1361,
        "mass": 1067000.0,
        "metaGroupID": 1,
        "metaLevel": 0,
        "name": {
            "de": "Rifter",
            "en": "Rifter",
            "es": "Rifter",
            "fr": "Rifter",
            "ja": "Rifter-ja",
            "ko": "Rifter-ko",
            "ru": "Rifter",
            "zh": "Rifter-zh",
        },
        "portionSize": 1,
        "published": True,
        "raceID": 2,
        "radius": 39.0,
        "shipTreeGroupID": None,
        "soundID": None,
        "techLevel": 1,
        "variationParentTypeID": None,
        "volume": 27289.0,
    }

    rows = transform_record("types.jsonl", record, manifest, IdAllocator())

    assert set(rows) == {"types"}
    (row,) = rows["types"]
    assert row["id"] == 587
    assert row["base_price"] == 84177.0
    assert row["group_id"] == 25
    assert row["name_en"] == "Rifter"
    assert row["name_ja"] == "Rifter-ja"
    assert row["description_en"] == "The Rifter is a fast attack frigate."
    assert row["published"] is True
    assert row["faction_id"] is None
    assert set(row) == {c["name"] for c in manifest["tables"]["types"]["columns"]}


# ---------------------------------------------------------------------------
# blueprints.jsonl -- flatten вложенных объектов (activities.copying.*) + массивы
# ---------------------------------------------------------------------------


def test_blueprints_record(manifest: dict[str, Any]) -> None:
    record = {
        "_key": 686,
        "blueprintTypeID": 587,
        "maxProductionLimit": 300,
        "activities": {
            "copying": {
                "time": 22500,
                "materials": [{"quantity": 1, "typeID": 34}],
                "skills": [{"level": 1, "typeID": 3380}],
            },
            "manufacturing": {
                "time": 1200,
                "materials": [
                    {"quantity": 350, "typeID": 34},
                    {"quantity": 30, "typeID": 35},
                ],
                "products": [{"quantity": 1, "typeID": 587}],
                "skills": [{"level": 1, "typeID": 3380}],
            },
        },
    }

    rows = transform_record("blueprints.jsonl", record, manifest, IdAllocator())

    (root,) = rows["blueprints"]
    assert root == {
        "id": 686,
        "blueprint_type_id": 587,
        "max_production_limit": 300,
        "activities_copying_time": 22500,
        "activities_manufacturing_time": 1200,
    }

    assert rows["blueprints_activities_copying_materials"] == [
        {"blueprints_id": 686, "seq": 0, "quantity": 1, "type_id": 34}
    ]
    assert rows["blueprints_activities_copying_skills"] == [
        {"blueprints_id": 686, "seq": 0, "level": 1, "type_id": 3380}
    ]
    assert rows["blueprints_activities_manufacturing_materials"] == [
        {"blueprints_id": 686, "seq": 0, "quantity": 350, "type_id": 34},
        {"blueprints_id": 686, "seq": 1, "quantity": 30, "type_id": 35},
    ]
    assert rows["blueprints_activities_manufacturing_products"] == [
        {"blueprints_id": 686, "seq": 0, "quantity": 1, "type_id": 587}
    ]
    assert rows["blueprints_activities_manufacturing_skills"] == [
        {"blueprints_id": 686, "seq": 0, "level": 1, "type_id": 3380}
    ]
    # активности, которых нет у этого чертежа (research_material и т.п.), не создают строк
    assert "blueprints_activities_research_material_materials" not in rows


# ---------------------------------------------------------------------------
# epicArcs.jsonl -- трёхуровневая вложенность missions[] -> nextMissions[]
# ---------------------------------------------------------------------------


def test_epic_arcs_record_three_level_nesting(manifest: dict[str, Any]) -> None:
    record = {
        "_key": 1,
        "arcRestartInterval": 216000,
        "factionID": 500001,
        "iconID": 2436,
        "name": {k: "Sisters of EVE" for k in ("de", "en", "es", "fr", "ja", "ko", "ru", "zh")},
        "missions": [
            {"_key": 100, "agentID": 3009841, "failMissionID": 102, "nextMissions": [101, 102]},
            {"_key": 101, "agentID": 3009842, "failMissionID": None, "nextMissions": []},
        ],
    }

    rows = transform_record("epicArcs.jsonl", record, manifest, IdAllocator())

    (arc,) = rows["epic_arcs"]
    assert arc["id"] == 1
    assert arc["arc_restart_interval"] == 216000
    assert arc["faction_id"] == 500001
    assert arc["name_en"] == "Sisters of EVE"

    missions = rows["epic_arcs_missions"]
    assert len(missions) == 2
    first, second = missions
    assert first["id"] == 1  # суррогатный id, сквозная нумерация с 1
    assert first["epic_arcs_id"] == 1
    assert first["seq"] == 0
    assert first["source_key"] == 100
    assert first["agent_id"] == 3009841
    assert first["fail_mission_id"] == 102
    assert second["id"] == 2
    assert second["seq"] == 1
    assert second["source_key"] == 101

    next_missions = rows["epic_arcs_missions_next_missions"]
    assert next_missions == [
        {"epic_arcs_missions_id": 1, "seq": 0, "value": 101},
        {"epic_arcs_missions_id": 1, "seq": 1, "value": 102},
    ]
    # у второй миссии nextMissions пуст -- строк для неё нет вообще
    assert all(row["epic_arcs_missions_id"] != 2 for row in next_missions)


# ---------------------------------------------------------------------------
# masteries.jsonl -- анонимный "_value" на двух уровнях + суррогатный id
# ---------------------------------------------------------------------------


def test_masteries_record(manifest: dict[str, Any]) -> None:
    record = {
        "_key": 587,
        "_value": [
            {"_key": 0, "_value": [123, 456]},
            {"_key": 1, "_value": [789]},
        ],
    }

    rows = transform_record("masteries.jsonl", record, manifest, IdAllocator())

    (root,) = rows["masteries"]
    assert root == {"id": 587}

    levels = rows["masteries_value"]
    assert levels == [
        {"id": 1, "masteries_id": 587, "seq": 0, "source_key": 0},
        {"id": 2, "masteries_id": 587, "seq": 1, "source_key": 1},
    ]

    certs = rows["masteries_value_value"]
    assert certs == [
        {"masteries_value_id": 1, "seq": 0, "value": 123},
        {"masteries_value_id": 1, "seq": 1, "value": 456},
        {"masteries_value_id": 2, "seq": 0, "value": 789},
    ]


def test_unknown_file_name_raises(manifest: dict[str, Any]) -> None:
    with pytest.raises(ValueError, match="не найден"):
        transform_record("neverHeardOf.jsonl", {"_key": 1}, manifest, IdAllocator())


# ---------------------------------------------------------------------------
# Дочерние таблицы с усечённым СУБД-именем (превышение лимита длины
# идентификатора в eve_sde_full_schema.sql) -- находятся не по наивной
# конкатенации `<таблица>_<поле>`, а по манифестной паре (parent_table,
# array_path). См. tools/gen_manifest.py:_TRUNCATED_ARRAY_PATH_OVERRIDES.
# ---------------------------------------------------------------------------


def test_dynamic_item_attributes_truncated_child_table(manifest: dict[str, Any]) -> None:
    report = TransformReport()
    record = {
        "_key": 47297,
        "attributeIDs": [{"_key": 6, "max": 1.4, "min": 0.6}],
        "inputOutputMapping": [{"applicableTypes": [5975, 12052], "resultingType": 47408}],
    }

    rows = transform_record("dynamicItemAttributes.jsonl", record, manifest, IdAllocator(), report)

    assert rows["dynamic_item_attributes_input_output_mapping_applicab_543eea"] == [
        {"dynamic_item_attributes_input_output_mapping_id": 1, "seq": 0, "value": 5975},
        {"dynamic_item_attributes_input_output_mapping_id": 1, "seq": 1, "value": 12052},
    ]
    assert report.unknown_fields == {}


def test_military_campaign_objectives_key_column_rename(manifest: dict[str, Any]) -> None:
    """`parameters[].key` -- обычное строковое поле (не `_key`-идентификатор);

    в эталонной схеме колонка называется `item_key`, т.к. `key` конфликтует
    с зарезервированным словом СУБД.
    """
    report = TransformReport()
    record = {
        "_key": "objective-1",
        "contributionMethodConfiguration": {
            "name": "CompleteAgentMission",
            "parameters": [
                {
                    "key": "agent_division",
                    "matcher": {"values": [{"valueType": "agent_division", "values": ["2"]}]},
                }
            ],
        },
    }

    rows = transform_record(
        "militaryCampaignObjectives.jsonl", record, manifest, IdAllocator(), report
    )

    (param_row,) = rows["military_campaign_objectives_contribution_method_conf_00852c"]
    assert param_row["item_key"] == "agent_division"
    assert report.unknown_fields == {}


# ---------------------------------------------------------------------------
# Синтетический манифест: точечная проверка конвенций, сквозной нумерации
# суррогатных id и обработки неизвестных полей.
# ---------------------------------------------------------------------------


def _column(
    name: str, type_: str = "INTEGER", size: int | None = None, nullable: bool = True
) -> dict[str, Any]:
    return {"name": name, "type": type_, "size": size, "nullable": nullable}


_MINI_MANIFEST: dict[str, Any] = {
    "tables": {
        "widgets": {
            "layer": "raw_root",
            "source_file": "widgets.jsonl",
            "parent_table": None,
            "array_path": None,
            "surrogate_pk": False,
            "columns": [
                _column("id", nullable=False),
                _column("name_en", "TEXT"),
                _column("position_x", "FLOAT"),
                _column("position_y", "FLOAT"),
            ],
            "primary_key": ["id"],
            "unique": [],
            "foreign_keys": [],
            "indexes": [],
        },
        "widgets_tags": {
            "layer": "raw_child",
            "source_file": None,
            "parent_table": "widgets",
            "array_path": "tags",
            "surrogate_pk": False,
            "columns": [
                _column("widgets_id", nullable=False),
                _column("seq", nullable=False),
                _column("value", "VARCHAR", 50),
            ],
            "primary_key": ["widgets_id", "seq"],
            "unique": [],
            "foreign_keys": [],
            "indexes": [],
        },
        "widgets_parts": {
            "layer": "raw_child",
            "source_file": None,
            "parent_table": "widgets",
            "array_path": "parts",
            "surrogate_pk": True,
            "columns": [
                _column("id", nullable=False),
                _column("widgets_id"),
                _column("seq"),
                _column("source_key"),
                _column("weight", "FLOAT"),
            ],
            "primary_key": ["id"],
            "unique": [["widgets_id", "seq"]],
            "foreign_keys": [],
            "indexes": [],
        },
        "widgets_parts_bolts": {
            "layer": "raw_child",
            "source_file": None,
            "parent_table": "widgets_parts",
            "array_path": "bolts",
            "surrogate_pk": False,
            "columns": [
                _column("widgets_parts_id", nullable=False),
                _column("seq", nullable=False),
                _column("length", "FLOAT"),
            ],
            "primary_key": ["widgets_parts_id", "seq"],
            "unique": [],
            "foreign_keys": [],
            "indexes": [],
        },
    }
}


def test_flatten_nested_object() -> None:
    record = {"_key": 1, "name": {"en": "Widget"}, "position": {"x": 1.5, "y": 2.5}}
    rows = transform_record("widgets.jsonl", record, _MINI_MANIFEST, IdAllocator())
    assert rows["widgets"] == [{"id": 1, "name_en": "Widget", "position_x": 1.5, "position_y": 2.5}]


def test_scalar_array_creates_value_rows() -> None:
    record = {"_key": 1, "tags": ["red", "blue"]}
    rows = transform_record("widgets.jsonl", record, _MINI_MANIFEST, IdAllocator())
    assert rows["widgets_tags"] == [
        {"widgets_id": 1, "seq": 0, "value": "red"},
        {"widgets_id": 1, "seq": 1, "value": "blue"},
    ]


def test_surrogate_id_is_continuous_across_records_and_links_grandchild() -> None:
    """Сквозная нумерация: id_allocator общий на несколько вызовов transform_record."""
    allocator = IdAllocator()

    record1 = {
        "_key": 1,
        "parts": [
            {"_key": 900, "weight": 1.0, "bolts": [{"length": 0.1}, {"length": 0.2}]},
        ],
    }
    record2 = {
        "_key": 2,
        "parts": [
            {"_key": 901, "weight": 2.0, "bolts": [{"length": 0.3}]},
        ],
    }

    rows1 = transform_record("widgets.jsonl", record1, _MINI_MANIFEST, allocator)
    rows2 = transform_record("widgets.jsonl", record2, _MINI_MANIFEST, allocator)

    assert rows1["widgets_parts"] == [
        {"id": 1, "widgets_id": 1, "seq": 0, "source_key": 900, "weight": 1.0}
    ]
    assert rows2["widgets_parts"] == [
        {"id": 2, "widgets_id": 2, "seq": 0, "source_key": 901, "weight": 2.0}
    ]

    assert rows1["widgets_parts_bolts"] == [
        {"widgets_parts_id": 1, "seq": 0, "length": 0.1},
        {"widgets_parts_id": 1, "seq": 1, "length": 0.2},
    ]
    assert rows2["widgets_parts_bolts"] == [
        {"widgets_parts_id": 2, "seq": 0, "length": 0.3},
    ]


def test_unknown_scalar_field_is_reported_and_dropped(caplog: pytest.LogCaptureFixture) -> None:
    report = TransformReport()
    with caplog.at_level(logging.WARNING):
        rows = transform_record(
            "widgets.jsonl",
            {"_key": 1, "name": {"en": "Widget"}, "totallyNewField": 42},
            _MINI_MANIFEST,
            IdAllocator(),
            report,
        )

    assert rows["widgets"] == [{"id": 1, "name_en": "Widget"}]
    assert report.unknown_fields == {"widgets": {"totally_new_field"}}
    assert any("totally_new_field" in message for message in caplog.messages)


def test_unknown_array_field_is_reported_and_dropped() -> None:
    report = TransformReport()
    rows = transform_record(
        "widgets.jsonl",
        {"_key": 1, "gizmos": [{"foo": 1}, {"foo": 2}]},
        _MINI_MANIFEST,
        IdAllocator(),
        report,
    )

    assert rows["widgets"] == [{"id": 1}]
    assert "widgets_gizmos" not in rows
    assert report.unknown_fields == {"widgets": {"gizmos"}}
