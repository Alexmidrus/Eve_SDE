"""Чистые функции преобразования JSON-записей SDE в строки таблиц raw-слоя.

Конвенции — CLAUDE.md §3. `transform_record` не делает I/O и не обращается
к БД: она принимает одну JSON-запись исходного файла и уже готовый
`manifest.json` (T02) и возвращает словарь ``{имя_таблицы: [строка, ...]}``
для корневой таблицы и всех дочерних/внучатых таблиц, порождённых
вложенными массивами записи. Единственные побочные эффекты — мутация
переданных `id_allocator`/`report`: это стейтфул объекты-коллаборанты,
специально передаваемые вызывающей стороной (а не глобальное состояние),
чтобы суррогатные id были сквозными по всем файлам одной загрузки.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Any

_LOGGER = logging.getLogger(__name__)

#: Акроним (2+ заглавных), за которым начинается новое слово: "HTTPResponse" -> "HTTP_Response".
_ACRONYM_BOUNDARY_RE = re.compile(r"([A-Z]{2,})([A-Z][a-z])")
#: Обычная граница слова: "typeID" -> "type_ID" (а "planet_IDs" после шага выше уже не трогается).
_WORD_BOUNDARY_RE = re.compile(r"([a-z0-9])([A-Z])")


def camel_to_snake(name: str) -> str:
    """camelCase -> snake_case с учётом акронимов.

    ``typeID`` -> ``type_id``, ``planetIDs`` -> ``planet_ids`` (а не
    ``planet_i_ds``), ``blueprintTypeID`` -> ``blueprint_type_id``.
    """
    step1 = _ACRONYM_BOUNDARY_RE.sub(r"\1_\2", name)
    step2 = _WORD_BOUNDARY_RE.sub(r"\1_\2", step1)
    return step2.lower()


#: Переименования колонок, введённые эталонной SQL-схемой для отдельных таблиц
#: (обычно чтобы не конфликтовать с зарезервированным словом СУБД): реальное
#: имя JSON-поля -> имя колонки в манифесте. Формат ключа: (таблица, поле).
#: `military_campaign_objectives_contribution_method_conf_00852c.key` -- поле
#: `contributionMethodConfiguration.parameters[].key` (обычная строка, а не
#: идентификатор `_key`), в eve_sde_full_schema.sql названо `item_key`.
_COLUMN_RENAMES: dict[tuple[str, str], str] = {
    ("military_campaign_objectives_contribution_method_conf_00852c", "key"): "item_key",
}


class IdAllocator:
    """Счётчик суррогатных id для промежуточных таблиц, отдельный на таблицу.

    Один экземпляр должен использоваться на протяжении всей загрузки
    (все файлы, все записи), чтобы нумерация была сквозной, а не сбрасывалась
    на каждой записи/файле.
    """

    def __init__(self) -> None:
        """Создаёт пустой счётчик (без предвыделенных таблиц)."""
        self._counters: dict[str, int] = {}

    def __call__(self, table_name: str) -> int:
        """Возвращает следующий id для таблицы ``table_name`` (нумерация с 1)."""
        next_id = self._counters.get(table_name, 0) + 1
        self._counters[table_name] = next_id
        return next_id


@dataclass
class TransformReport:
    """Отчёт о полях JSON, не описанных в манифесте (см. `transform_record`)."""

    unknown_fields: dict[str, set[str]] = field(default_factory=dict)

    def add_unknown_field(self, table_name: str, field_name: str) -> None:
        """Регистрирует поле `field_name`, не описанное в манифесте для `table_name`."""
        self.unknown_fields.setdefault(table_name, set()).add(field_name)


def transform_record(
    file_name: str,
    json_record: dict[str, Any],
    manifest: dict[str, Any],
    id_allocator: IdAllocator,
    report: TransformReport | None = None,
) -> dict[str, list[dict[str, Any]]]:
    """Преобразует одну JSON-запись файла ``file_name`` в строки raw-таблиц.

    Пример::

        record = {"_key": 587, "mass": 1067000.0, ...}
        rows = transform_record("types.jsonl", record, manifest, IdAllocator())
        rows["types"] == [{"id": 587, "mass": 1067000.0, ...}]

    Неизвестное (отсутствующее в манифесте) поле или вложенный массив без
    соответствующей дочерней таблицы -- не ошибка: пишется warning в лог,
    поле добавляется в ``report.unknown_fields`` и исключается из строки
    (SDE обновляется патчами CCP, схема библиотеки может временно отстать).
    Неизвестное имя файла (нет корневой таблицы с таким ``source_file``
    в манифесте) -- ошибка вызывающей стороны, поднимается `ValueError`.
    """
    if report is None:
        report = TransformReport()
    tables = manifest["tables"]
    root_table = _find_root_table(tables, file_name)

    rows: dict[str, list[dict[str, Any]]] = {}
    _process_object(
        root_table,
        json_record,
        {},
        is_root=True,
        tables=tables,
        id_allocator=id_allocator,
        rows=rows,
        report=report,
    )
    return rows


def _find_root_table(tables: dict[str, Any], file_name: str) -> str:
    for name, table_def in tables.items():
        if table_def["layer"] == "raw_root" and table_def["source_file"] == file_name:
            return name
    raise ValueError(
        f"Файл {file_name!r} не найден в манифесте (нет корневой таблицы с таким source_file)"
    )


def _snake_field_name(key: str) -> str:
    # "_value" - специальный ключ SDE (см. masteries.jsonl: {"_key":.., "_value":[...]}),
    # означает "весь payload этого объекта -- массив/скаляр без отдельного имени поля".
    # camel_to_snake("_value") сохранил бы лидирующее подчёркивание, поэтому -- отдельно.
    return "value" if key == "_value" else camel_to_snake(key)


def _process_object(
    table_name: str,
    obj: dict[str, Any],
    extra_columns: dict[str, Any],
    *,
    is_root: bool,
    tables: dict[str, Any],
    id_allocator: IdAllocator,
    rows: dict[str, list[dict[str, Any]]],
    report: TransformReport,
) -> None:
    """Строит одну строку таблицы `table_name` из объекта `obj` (запись или элемент массива)."""
    table_def = tables[table_name]
    row: dict[str, Any] = dict(extra_columns)
    if table_def["surrogate_pk"]:
        row["id"] = id_allocator(table_name)

    for key, value in obj.items():
        if key == "_key":
            # У корневой записи _key -> id (PK корневой таблицы); у элемента массива,
            # представленного своим _key (был dict с ключами-идентификаторами
            # в исходном JSON), _key -> source_key, отдельно от суррогатного id.
            row["id" if is_root else "source_key"] = value
            continue
        field_name = _COLUMN_RENAMES.get((table_name, key), _snake_field_name(key))
        _process_field(table_name, field_name, value, row, tables, id_allocator, rows, report)

    _drop_unknown_columns(table_name, row, table_def, report)
    rows.setdefault(table_name, []).append(row)


def _process_field(
    table_name: str,
    field_name: str,
    value: Any,
    row: dict[str, Any],
    tables: dict[str, Any],
    id_allocator: IdAllocator,
    rows: dict[str, list[dict[str, Any]]],
    report: TransformReport,
) -> None:
    """Обрабатывает одно поле текущей строки: скаляр, вложенный объект (flatten) или массив."""
    if isinstance(value, dict):
        for sub_key, sub_value in value.items():
            nested_name = f"{field_name}_{_snake_field_name(sub_key)}"
            _process_field(
                table_name, nested_name, sub_value, row, tables, id_allocator, rows, report
            )
        return

    if isinstance(value, list):
        naive_child_table = f"{table_name}_{field_name}"
        child_table: str | None = naive_child_table
        if naive_child_table not in tables:
            child_table = _find_child_table_by_array_path(table_name, field_name, tables)
        if child_table is None:
            _LOGGER.warning(
                "Неизвестное поле-массив %r таблицы %r: нет дочерней таблицы %r в манифесте",
                field_name,
                table_name,
                naive_child_table,
            )
            report.add_unknown_field(table_name, field_name)
            return

        parent_id_column = f"{table_name}_id"
        parent_id_value = row.get("id")
        for seq, item in enumerate(value):
            if isinstance(item, dict):
                _process_object(
                    child_table,
                    item,
                    {parent_id_column: parent_id_value, "seq": seq},
                    is_root=False,
                    tables=tables,
                    id_allocator=id_allocator,
                    rows=rows,
                    report=report,
                )
            else:
                rows.setdefault(child_table, []).append(
                    {parent_id_column: parent_id_value, "seq": seq, "value": item}
                )
        return

    row[field_name] = value


def _find_child_table_by_array_path(
    parent_table: str, field_name: str, tables: dict[str, Any]
) -> str | None:
    """Ищет дочернюю таблицу массива по манифестной паре (parent_table, array_path).

    Используется только когда наивная конкатенация `<parent_table>_<field_name>`
    не нашла таблицу -- это происходит для полей, чьё полное имя таблицы
    превысило лимит длины идентификатора СУБД и было усечено генератором
    eve_sde_full_schema.sql (напр. `dynamic_item_attributes_input_output_mapping`
    + `applicable_types` -> `..._applicab_543eea`, см. tools/gen_manifest.py).
    `array_path` хранится с точками на границах вложенных объектов; сравниваем
    с `field_name`, заменив точки на подчёркивания -- ровно то разделение,
    которое `_process_field` использует при построении `field_name`.
    """
    for name, table_def in tables.items():
        if (
            table_def.get("layer") == "raw_child"
            and table_def.get("parent_table") == parent_table
            and table_def.get("array_path") is not None
            and table_def["array_path"].replace(".", "_") == field_name
        ):
            return name
    return None


def _drop_unknown_columns(
    table_name: str,
    row: dict[str, Any],
    table_def: dict[str, Any],
    report: TransformReport,
) -> None:
    known_columns = {c["name"] for c in table_def["columns"]}
    for unknown_key in [k for k in row if k not in known_columns]:
        _LOGGER.warning(
            "Неизвестное поле %r для таблицы %r отсутствует в манифесте -- пропущено",
            unknown_key,
            table_name,
        )
        report.add_unknown_field(table_name, unknown_key)
        del row[unknown_key]
