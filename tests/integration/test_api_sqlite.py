"""Интеграционные тесты публичного API (evesde.SDE) на фикстурах sde_marts."""

from __future__ import annotations

from pathlib import Path

import pytest
from sqlalchemy import create_engine

from evesde import SDE, SDEAmbiguousNameError, SDENotFoundError
from evesde.etl.loader import load_all
from evesde.etl.marts import build_marts
from evesde.schema.builder import create_mart_tables, create_raw_tables, load_manifest

_FIXTURES_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "sde_marts"


@pytest.fixture(scope="module")
def sde(tmp_path_factory: pytest.TempPathFactory) -> SDE:
    """Реальный файл SQLite, загруженный фикстурами sde_marts, обёрнутый в SDE()."""
    db_path = tmp_path_factory.mktemp("api_db") / "eve.db"
    manifest = load_manifest()
    engine = create_engine(f"sqlite:///{db_path}")
    create_raw_tables(engine, manifest)
    create_mart_tables(engine, manifest)
    load_all(engine, _FIXTURES_DIR, manifest)
    build_marts(engine)
    engine.dispose()
    return SDE(f"sqlite:///{db_path}")


# ---------------------------------------------------------------------------
# item() / items() / search()
# ---------------------------------------------------------------------------


def test_item_by_name(sde: SDE) -> None:
    item = sde.item("Rifter")
    assert item.type_id == 587
    assert item.group_name == "Frigate"
    assert item.category_name == "Ship"


def test_item_by_id(sde: SDE) -> None:
    assert sde.item(587).name == "Rifter"


def test_item_not_found(sde: SDE) -> None:
    with pytest.raises(SDENotFoundError):
        sde.item("Not A Real Item Name")
    with pytest.raises(SDENotFoundError):
        sde.item(999999999)


def test_item_ambiguous_name(sde: SDE) -> None:
    with pytest.raises(SDEAmbiguousNameError) as excinfo:
        sde.item("Ambiguous Item")
    assert {c[0] for c in excinfo.value.candidates} == {9998, 9999}


def test_item_lang_ru(sde: SDE) -> None:
    assert sde.item("Риффтер", lang="ru").type_id == 587
    assert sde.item(587, lang="ru").name == "Риффтер"


def test_items_filter_by_category(sde: SDE) -> None:
    names = {i.name for i in sde.items(category="Ship")}
    assert names == {"Rifter"}


def test_items_no_filters_returns_all(sde: SDE) -> None:
    all_items = sde.items()
    assert len(all_items) >= 5


def test_search_by_substring(sde: SDE) -> None:
    names = {i.name for i in sde.search("Rift")}
    assert names == {"Rifter", "Rifter Blueprint"}


def test_search_no_match_returns_empty(sde: SDE) -> None:
    assert sde.search("NoSuchThingXYZ") == []


# ---------------------------------------------------------------------------
# stats() / dogma()
# ---------------------------------------------------------------------------


def test_stats_positive(sde: SDE) -> None:
    stats = sde.stats("Rifter")
    assert stats.type_id == 587
    assert stats.structure_hp == 500.0
    assert stats.high_slots == 3


def test_stats_not_found_no_dogma(sde: SDE) -> None:
    """У Tritanium (id=34) нет записи в type_common_stats (нет typeDogma)."""
    with pytest.raises(SDENotFoundError):
        sde.stats("Tritanium")


def test_stats_item_not_found(sde: SDE) -> None:
    with pytest.raises(SDENotFoundError):
        sde.stats("Not A Real Item Name")


def test_dogma_positive(sde: SDE) -> None:
    attrs = {a.attribute_id: a.value for a in sde.dogma("Rifter")}
    assert attrs == {9: 500.0, 14: 3.0}


def test_dogma_empty_when_no_attributes(sde: SDE) -> None:
    assert sde.dogma("Tritanium") == []


# ---------------------------------------------------------------------------
# system() / systems()
# ---------------------------------------------------------------------------


def test_system_by_name(sde: SDE) -> None:
    jita = sde.system("Jita")
    assert jita.solar_system_id == 30000142
    assert jita.region_name == "The Forge"
    assert jita.faction_name == "Guristas Pirates"  # COALESCE от региона


def test_system_by_id(sde: SDE) -> None:
    assert sde.system(30000142).name == "Jita"


def test_system_not_found(sde: SDE) -> None:
    with pytest.raises(SDENotFoundError):
        sde.system("Not A Real System")


def test_systems_filter_by_region(sde: SDE) -> None:
    names = {s.name for s in sde.systems(region="The Forge")}
    assert names == {"Jita"}


def test_systems_filter_by_security(sde: SDE) -> None:
    assert {s.name for s in sde.systems(min_security=0.5)} == {"Jita"}
    assert sde.systems(min_security=0.99) == []


# ---------------------------------------------------------------------------
# industry()
# ---------------------------------------------------------------------------


def test_industry_by_product_and_activity(sde: SDE) -> None:
    recipes = sde.industry(product="Rifter", activity="manufacturing")
    assert len(recipes) == 1
    recipe = recipes[0]
    assert recipe.blueprint_id == 686
    assert recipe.blueprint_name == "Rifter Blueprint"
    assert {m.name for m in recipe.materials} == {"Tritanium", "Pyerite"}
    assert {p.name for p in recipe.products} == {"Rifter"}


def test_industry_by_blueprint_all_activities(sde: SDE) -> None:
    recipes = sde.industry(blueprint="Rifter Blueprint")
    assert {r.activity_type for r in recipes} == {"copying", "manufacturing"}


def test_industry_requires_blueprint_or_product(sde: SDE) -> None:
    with pytest.raises(ValueError, match="blueprint.*product"):
        sde.industry()


def test_industry_unknown_product_not_found(sde: SDE) -> None:
    with pytest.raises(SDENotFoundError):
        sde.industry(product="Not A Real Product")


# ---------------------------------------------------------------------------
# agents()
# ---------------------------------------------------------------------------


def test_agents_filter_by_level_and_region(sde: SDE) -> None:
    names = {a.name for a in sde.agents(level=4, region="The Forge", is_locator=False)}
    assert names == {"Ama Amagawa"}


def test_agents_filter_no_match(sde: SDE) -> None:
    assert sde.agents(level=1) == []


# ---------------------------------------------------------------------------
# meta()
# ---------------------------------------------------------------------------


def test_meta(sde: SDE) -> None:
    info = sde.meta()
    assert info.build_number == 3428504
    assert info.release_date == "2026-07-09T11:05:50Z"
    assert info.item_count >= 5
    assert info.system_count == 1
    assert info.agent_count == 1


# ---------------------------------------------------------------------------
# sde.engine
# ---------------------------------------------------------------------------


def test_engine_property_allows_raw_queries(sde: SDE) -> None:
    from sqlalchemy import text

    with sde.engine.connect() as conn:
        assert conn.execute(text("SELECT COUNT(*) FROM types")).scalar_one() >= 5
