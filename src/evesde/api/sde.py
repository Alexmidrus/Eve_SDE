"""Класс SDE — публичный фасад библиотеки evesde (CLAUDE.md §7).

~10 методов с богатыми параметрами вместо десятков узких. Все методы
принимают ``lang="en"`` по умолчанию (любой из 8 языков SDE) и возвращают
лёгкие frozen dataclass'ы (не сырые Row). Разрешение "имя или id" везде
единообразно: `int` трактуется как id, `str` ищется точным совпадением по
локализованному имени, затем LIKE; неоднозначность бросает
`SDEAmbiguousNameError` со списком кандидатов, отсутствие --
`SDENotFoundError`. Всё, что не покрыто API, доступно через `sde.engine`.
"""

from __future__ import annotations

import tempfile
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from sqlalchemy import MetaData
from sqlalchemy.engine import Engine

from evesde.api import queries as q
from evesde.api.queries import (
    Agent,
    DogmaAttribute,
    IndustryRecipe,
    Item,
    Meta,
    SDEAmbiguousNameError,
    SDENotFoundError,
    SolarSystem,
    TypeStats,
)
from evesde.config import SDEConfig, make_engine
from evesde.etl.loader import load_fresh
from evesde.etl.source import BuildInfo, check_remote_build, download, get_local_build
from evesde.etl.verify import VerifyReport, verify
from evesde.schema.builder import build_metadata, load_manifest

__all__ = [
    "SDE",
    "Agent",
    "DogmaAttribute",
    "IndustryRecipe",
    "Item",
    "Meta",
    "SDEAmbiguousNameError",
    "SDENotFoundError",
    "SolarSystem",
    "TypeStats",
    "UpdateResult",
]


@dataclass(frozen=True)
class UpdateResult:
    """Результат `SDE.update_if_needed()`."""

    updated: bool
    previous_build: BuildInfo | None
    new_build: BuildInfo
    verify_report: VerifyReport | None


class SDE:
    """Публичный фасад evesde: подключение к БД + чтение загруженного SDE.

    Пример::

        from evesde import SDE

        sde = SDE("sqlite:///eve.db")
        ship = sde.item("Rifter")               # по имени или type_id
        stats = sde.stats(ship.type_id)
        mats = sde.industry(product="Rifter", activity="manufacturing")
        jita = sde.system("Jita")
        agents = sde.agents(level=4, region="The Forge", is_locator=True)
    """

    def __init__(self, config_or_url: str | SDEConfig) -> None:
        """Подключается к БД: строка URL SQLAlchemy или готовый `SDEConfig`."""
        self._config = (
            config_or_url
            if isinstance(config_or_url, SDEConfig)
            else SDEConfig.from_url(config_or_url)
        )
        self._engine: Engine = make_engine(self._config)
        self._manifest: dict[str, Any] = load_manifest()
        self._metadata: MetaData = build_metadata(self._manifest)

    @property
    def engine(self) -> Engine:
        """SQLAlchemy Engine для произвольных запросов, не покрытых API."""
        return self._engine

    def item(self, name_or_id: int | str, *, lang: str = "en") -> Item:
        """Возвращает предмет по имени (в языке `lang`) или по `type_id`.

        >>> sde.item("Rifter").group_name
        'Frigate'
        >>> sde.item(587).name
        'Rifter'

        :raises SDENotFoundError: нет предмета с таким именем/id.
        :raises SDEAmbiguousNameError: имени соответствует несколько предметов.
        """
        return q.item(self._engine, self._metadata, name_or_id, lang=lang)

    def items(
        self,
        *,
        group: int | str | None = None,
        category: int | str | None = None,
        market_group: int | str | None = None,
        published: bool | None = None,
        lang: str = "en",
    ) -> list[Item]:
        """Возвращает предметы, отфильтрованные по группе/категории/рыночной группе.

        >>> [i.name for i in sde.items(category="Ship", published=True)]
        ['Rifter', ...]

        Фильтры принимают id или имя (в языке `lang`); отсутствующий фильтр
        не применяется. Пустой список -- если ничего не подошло.
        """
        return q.items(
            self._engine,
            self._metadata,
            group=group,
            category=category,
            market_group=market_group,
            published=published,
            lang=lang,
        )

    def search(self, name: str, *, lang: str = "en", limit: int = 20) -> list[Item]:
        """Ищет предметы по подстроке имени (LIKE), до `limit` штук.

        >>> [i.name for i in sde.search("Rift")]
        ['Rifter']

        В отличие от `item()` никогда не бросает `SDEAmbiguousNameError` --
        это и есть инструмент для разрешения неоднозначности вручную.
        """
        return q.search(self._engine, self._metadata, name, lang=lang, limit=limit)

    def stats(self, type_id_or_name: int | str, *, lang: str = "en") -> TypeStats:
        """Возвращает характеристики предмета (67 курированных dogma-атрибутов).

        >>> sde.stats("Rifter").high_slots
        4

        :raises SDENotFoundError: нет предмета, либо у предмета нет характеристик
            (не для всех типов есть typeDogma -- см. CLAUDE.md §3).
        """
        return q.stats(self._engine, self._metadata, type_id_or_name, lang=lang)

    def dogma(self, type_id_or_name: int | str, *, lang: str = "en") -> list[DogmaAttribute]:
        """Возвращает полный EAV dogma-атрибутов предмета (не только курированные 67).

        >>> {a.attribute_id for a in sde.dogma("Rifter")}  # doctest: +SKIP
        {9, 14, 30, ...}

        Пустой список, если у предмета нет dogma-атрибутов вообще.
        """
        return q.dogma(self._engine, self._metadata, type_id_or_name, lang=lang)

    def system(self, name_or_id: int | str, *, lang: str = "en") -> SolarSystem:
        """Возвращает звёздную систему (+ созвездие, регион, сек-статус) по имени/id.

        >>> sde.system("Jita").region_name
        'The Forge'
        """
        return q.system(self._engine, self._metadata, name_or_id, lang=lang)

    def systems(
        self,
        *,
        region: int | str | None = None,
        min_security: float | None = None,
        max_security: float | None = None,
        lang: str = "en",
    ) -> list[SolarSystem]:
        """Возвращает системы, отфильтрованные по региону и диапазону сек-статуса.

        >>> [s.name for s in sde.systems(region="The Forge", min_security=0.5)]
        ['Jita', ...]
        """
        return q.systems(
            self._engine,
            self._metadata,
            region=region,
            min_security=min_security,
            max_security=max_security,
            lang=lang,
        )

    def industry(
        self,
        *,
        blueprint: int | str | None = None,
        product: int | str | None = None,
        activity: str | None = None,
        lang: str = "en",
    ) -> list[IndustryRecipe]:
        """Возвращает производственные рецепты (материалы/продукты/скиллы).

        Нужно указать `blueprint` (сам чертёж) либо `product` (что он производит);
        `activity` (``"manufacturing"``, ``"copying"``, ``"invention"``,
        ``"reaction"``, ``"research_material"``, ``"research_time"``) сужает
        до одной активности, иначе возвращаются все активности чертежа.

        >>> [m.name for m in sde.industry(product="Rifter", activity="manufacturing")[0].materials]
        ['Tritanium', 'Pyerite', ...]

        :raises ValueError: не указаны ни `blueprint`, ни `product`.
        """
        return q.industry(
            self._engine,
            self._metadata,
            blueprint=blueprint,
            product=product,
            activity=activity,
            lang=lang,
        )

    def agents(
        self,
        *,
        level: int | None = None,
        region: int | str | None = None,
        is_locator: bool | None = None,
        corporation: int | str | None = None,
        lang: str = "en",
    ) -> list[Agent]:
        """Возвращает агентов NPC, отфильтрованных по уровню/региону/корпорации.

        >>> [a.name for a in sde.agents(level=4, region="The Forge", is_locator=True)]
        ['Ama Amagawa', ...]
        """
        return q.agents(
            self._engine,
            self._metadata,
            level=level,
            region=region,
            is_locator=is_locator,
            corporation=corporation,
            lang=lang,
        )

    def meta(self) -> Meta:
        """Возвращает версию загруженного SDE и объём данных в витринах.

        >>> sde.meta().build_number
        3428504
        """
        return q.meta(self._engine, self._metadata)

    def update_if_needed(
        self,
        *,
        force: bool = False,
        on_progress: Callable[[str], None] | None = None,
        on_complete: Callable[[UpdateResult], None] | None = None,
    ) -> UpdateResult:
        """Проверяет версию SDE у CCP и обновляет БД, если вышел новый build.

        Полный цикл -- скачивание, ``load_fresh`` (raw-слой + витрины в
        теневом хранилище), ``verify`` -- атомарно подменяет текущую БД
        только после успешного построения теневой копии; при любой ошибке
        (сеть, парсинг, ...) исключение пробрасывается вызывающему коду, а
        старая БД остаётся полностью рабочей и доступной через `sde.engine`.

        ``on_progress`` вызывается с короткими текстовыми статусами по ходу
        обновления, ``on_complete`` -- один раз в конце с `UpdateResult`
        (например, для отправки уведомления в приложении пользователя).

        >>> result = sde.update_if_needed(on_progress=print)
        >>> result.updated
        True

        :raises evesde.etl.source.SourceUnavailableError: CCP-эндпоинт недоступен.
        """

        def progress(message: str) -> None:
            if on_progress is not None:
                on_progress(message)

        progress("Проверка версии SDE у CCP...")
        previous_build = get_local_build(self._engine)
        remote_build = check_remote_build()

        if (
            not force
            and previous_build is not None
            and previous_build.build_number == remote_build.build_number
        ):
            result = UpdateResult(
                updated=False,
                previous_build=previous_build,
                new_build=remote_build,
                verify_report=None,
            )
            progress(f"Уже актуально: build {remote_build.build_number}.")
            if on_complete is not None:
                on_complete(result)
            return result

        # Открытое подключение держит файл БД занятым и на Windows не даёт
        # атомарно подменить его внутри load_fresh -- закрываем заранее и
        # пересоздаём после (успешно или нет -- self.engine должен остаться
        # рабочим в любом случае, см. docstring load_fresh).
        self._engine.dispose()
        try:
            with tempfile.TemporaryDirectory(prefix="evesde-sde-") as tmp:
                tmp_path = Path(tmp)
                progress("Скачивание SDE...")
                download(tmp_path, progress_cb=lambda done, total: None)
                progress(f"Загрузка raw-слоя и витрин из {tmp_path}...")
                load_fresh(self._config, tmp_path, self._manifest)
        finally:
            self._engine = make_engine(self._config)

        progress("Проверка (verify)...")
        report = verify(self._engine, sde_dir=None, manifest=self._manifest)

        result = UpdateResult(
            updated=True,
            previous_build=previous_build,
            new_build=remote_build,
            verify_report=report,
        )
        progress(f"Обновлено до build {remote_build.build_number}.")
        if on_complete is not None:
            on_complete(result)
        return result
