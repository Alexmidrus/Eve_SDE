"""Юнит-тесты api/queries.py, не требующие БД."""

from __future__ import annotations

import dataclasses

from evesde.api.queries import _TYPE_STATS_FIELDS, TypeStats
from evesde.schema.builder import load_manifest


def test_type_stats_fields_match_manifest_columns() -> None:
    """TypeStats дублирует колонки type_common_stats вручную (см. queries.py) --
    страховка от опечаток/расхождения при будущих изменениях манифеста."""
    manifest = load_manifest()
    manifest_columns = tuple(c["name"] for c in manifest["tables"]["type_common_stats"]["columns"])

    assert manifest_columns == _TYPE_STATS_FIELDS

    dataclass_fields = tuple(f.name for f in dataclasses.fields(TypeStats))
    assert dataclass_fields == manifest_columns
