"""Верификация загруженного SDE (CLAUDE.md §5): ничего не чинит, только сообщает.

`verify(engine, sde_dir=None)` проверяет:

1. количество строк в каждой корневой raw-таблице = количеству строк
   соответствующего ``.jsonl`` файла (если передан `sde_dir` и файл в нём
   существует -- частичный каталог фикстур не считается ошибкой);
2. FK-сироты -- для каждого FK из манифеста (raw и mart-слой) считает
   значения, для которых нет родителя. Заведомо-не-FK колонки (например,
   ``agents_in_space.dungeon_id``) в манифесте вообще не значатся как FK
   (они не объявлены как FOREIGN KEY в эталонном
   ``reference/eve_sde_full_schema.sql``) -- их не нужно исключать отдельно, verify
   их и не проверяет;
3. витрины не пустые, и их ключи существуют в соответствующей raw-таблице
   (см. `_MART_KEY_SOURCE`, повторяет комментарии `-- = types.id` и т.п. из
   ``reference/eve_sde_full_schema.sql``);
4. buildNumber/releaseDate текущей загрузки (таблица ``sde``).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Literal

from sqlalchemy import func, inspect, select
from sqlalchemy.engine import Engine

from evesde.etl.source import BuildInfo, get_local_build
from evesde.schema.builder import build_metadata, load_manifest

Severity = Literal["error", "warning"]

#: Соответствие "витрина.колонка-ключ" -> "raw-таблица.колонка", из которой
#: эта витрина материализуется (см. комментарии `-- = ...` в CREATE TABLE
#: витрин в eve_sde_full_schema.sql). Явных FK-constraint'ов на это в схеме
#: нет (у витрин большинство колонок не FK), поэтому сверка захардкожена тут.
_MART_KEY_SOURCE: dict[str, tuple[str, str, str]] = {
    "dim_items": ("type_id", "types", "id"),
    "dim_universe": ("solar_system_id", "map_solar_systems", "id"),
    "type_common_stats": ("type_id", "types", "id"),
    "industry_activities": ("blueprint_id", "blueprints", "id"),
    "industry_materials": ("blueprint_id", "blueprints", "id"),
    "industry_products": ("blueprint_id", "blueprints", "id"),
    "industry_skills": ("blueprint_id", "blueprints", "id"),
    "dim_agents": ("agent_id", "npc_characters", "id"),
}


@dataclass(frozen=True)
class VerifyIssue:
    """Одна найденная проблема."""

    severity: Severity
    category: str
    message: str


@dataclass
class VerifyReport:
    """Результат `verify()`. Только диагностика -- ничего не исправляет."""

    build_info: BuildInfo | None = None
    issues: list[VerifyIssue] = field(default_factory=list)

    @property
    def errors(self) -> list[VerifyIssue]:
        """Только проблемы уровня error (без warning)."""
        return [i for i in self.issues if i.severity == "error"]

    @property
    def warnings(self) -> list[VerifyIssue]:
        """Только проблемы уровня warning (без error)."""
        return [i for i in self.issues if i.severity == "warning"]

    @property
    def ok(self) -> bool:
        """Нет ошибок (предупреждения не блокируют использование SDE)."""
        return not self.errors

    def summary(self) -> str:
        """Человекочитаемый текстовый отчёт."""
        lines: list[str] = []
        if self.build_info is not None:
            lines.append(
                f"SDE build {self.build_info.build_number} от {self.build_info.release_date}"
            )
        else:
            lines.append("Версия SDE неизвестна (таблица 'sde' пуста или отсутствует)")

        if not self.issues:
            lines.append("Проблем не найдено.")
            return "\n".join(lines)

        lines.append(
            f"Найдено проблем: {len(self.errors)} ошибок, {len(self.warnings)} предупреждений."
        )
        for issue in self.issues:
            marker = "ERROR" if issue.severity == "error" else "WARN"
            lines.append(f"  [{marker}] ({issue.category}) {issue.message}")
        return "\n".join(lines)


def verify(
    engine: Engine,
    sde_dir: Path | None = None,
    manifest: dict[str, Any] | None = None,
) -> VerifyReport:
    """Проверяет загруженный SDE и возвращает отчёт (см. модульный докстринг)."""
    manifest = manifest if manifest is not None else load_manifest()
    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())

    report = VerifyReport(build_info=get_local_build(engine))
    if report.build_info is None:
        report.issues.append(
            VerifyIssue("warning", "build_info", "Версия SDE неизвестна (таблица 'sde' пуста)")
        )

    if sde_dir is not None:
        _verify_row_counts(engine, manifest, sde_dir, existing_tables, report)

    _verify_fk_orphans(engine, manifest, existing_tables, report)
    _verify_marts(engine, manifest, existing_tables, report)
    return report


def _verify_row_counts(
    engine: Engine,
    manifest: dict[str, Any],
    sde_dir: Path,
    existing_tables: set[str],
    report: VerifyReport,
) -> None:
    metadata = build_metadata(manifest, layer="raw")
    for name, table_def in manifest["tables"].items():
        if table_def["layer"] != "raw_root" or name not in existing_tables:
            continue
        file_path = sde_dir / table_def["source_file"]
        if not file_path.exists():
            continue  # частичный каталог (напр. фикстуры) -- не ошибка

        with file_path.open("r", encoding="utf-8") as fh:
            expected = sum(1 for line in fh if line.strip())

        table = metadata.tables[name]
        with engine.connect() as conn:
            actual = conn.execute(select(func.count()).select_from(table)).scalar_one()

        if actual != expected:
            report.issues.append(
                VerifyIssue(
                    "error",
                    "row_count",
                    f"{name}: в таблице {actual} строк, в {table_def['source_file']} -- {expected}",
                )
            )


def _verify_fk_orphans(
    engine: Engine,
    manifest: dict[str, Any],
    existing_tables: set[str],
    report: VerifyReport,
) -> None:
    metadata = build_metadata(manifest)
    for name, table_def in manifest["tables"].items():
        if name not in existing_tables:
            continue
        table = metadata.tables[name]
        for fk in table_def["foreign_keys"]:
            if fk["ref_table"] not in existing_tables:
                continue
            col = table.c[fk["column"]]
            ref_alias = metadata.tables[fk["ref_table"]].alias()
            ref_col = ref_alias.c[fk["ref_column"]]

            stmt = (
                select(func.count())
                .select_from(table.outerjoin(ref_alias, col == ref_col))
                .where(col.is_not(None), ref_col.is_(None))
            )
            with engine.connect() as conn:
                orphan_count = conn.execute(stmt).scalar_one()

            if orphan_count:
                report.issues.append(
                    VerifyIssue(
                        "error",
                        "fk_orphan",
                        f"{name}.{fk['column']} -> {fk['ref_table']}.{fk['ref_column']}: "
                        f"{orphan_count} значений без родителя",
                    )
                )


def _verify_marts(
    engine: Engine,
    manifest: dict[str, Any],
    existing_tables: set[str],
    report: VerifyReport,
) -> None:
    metadata = build_metadata(manifest)
    for mart_name, (mart_col, raw_table, raw_col) in _MART_KEY_SOURCE.items():
        if mart_name not in existing_tables:
            continue
        table = metadata.tables[mart_name]
        with engine.connect() as conn:
            count = conn.execute(select(func.count()).select_from(table)).scalar_one()

        if count == 0:
            report.issues.append(
                VerifyIssue("warning", "mart_empty", f"Витрина '{mart_name}' пуста")
            )
            continue

        if raw_table not in existing_tables:
            continue
        ref_alias = metadata.tables[raw_table].alias()
        ref_col = ref_alias.c[raw_col]
        stmt = (
            select(func.count())
            .select_from(table.outerjoin(ref_alias, table.c[mart_col] == ref_col))
            .where(ref_col.is_(None))
        )
        with engine.connect() as conn:
            orphan_count = conn.execute(stmt).scalar_one()

        if orphan_count:
            report.issues.append(
                VerifyIssue(
                    "error",
                    "mart_orphan_key",
                    f"Витрина '{mart_name}': {orphan_count} строк с {mart_col}, "
                    f"отсутствующим в {raw_table}.{raw_col}",
                )
            )
