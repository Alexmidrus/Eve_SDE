"""Конфигурация подключения к базе данных для evesde.

Поддерживаются три СУБД: SQLite, PostgreSQL (драйвер psycopg 3),
MySQL/MariaDB (драйвер pymysql). Конфигурация принимает либо готовый URL
в формате SQLAlchemy, либо отдельные параметры подключения.
"""

from __future__ import annotations

import importlib.util
from dataclasses import dataclass

from sqlalchemy import create_engine
from sqlalchemy.engine import URL, Engine
from sqlalchemy.engine import make_url as _make_url

#: Диалекты, поддерживаемые библиотекой.
SUPPORTED_DIALECTS: tuple[str, ...] = ("sqlite", "postgresql", "mysql", "mariadb")

#: Драйвер по умолчанию для диалектов, где он не задан явно в URL/параметрах.
_DEFAULT_DRIVER: dict[str, str] = {
    "postgresql": "psycopg",
    "mysql": "pymysql",
    "mariadb": "pymysql",
}

#: Единственный поддерживаемый драйвер на каждый диалект (см. §4 CLAUDE.md).
_ALLOWED_DRIVERS: dict[str, tuple[str, ...]] = {
    "sqlite": ("pysqlite",),
    "postgresql": ("psycopg",),
    "mysql": ("pymysql",),
    "mariadb": ("pymysql",),
}

#: Имя импортируемого модуля для каждого драйвера (для проверки наличия пакета).
_DRIVER_MODULE: dict[str, str] = {
    "pysqlite": "sqlite3",
    "psycopg": "psycopg",
    "pymysql": "pymysql",
}

#: Extras пакета evesde, устанавливающие драйвер конкретной СУБД.
_EXTRA_BY_DIALECT: dict[str, str] = {
    "postgresql": "evesde[postgres]",
    "mysql": "evesde[mysql]",
    "mariadb": "evesde[mysql]",
}


class SDEConfigError(ValueError):
    """Ошибка конфигурации подключения к базе данных evesde."""


@dataclass(frozen=True)
class SDEConfig:
    """Провалидированная конфигурация подключения к базе данных.

    Не создавать напрямую — использовать `SDEConfig.from_url` или
    `SDEConfig.from_params`, они гарантируют, что диалект и драйвер
    поддерживаются и установлены.
    """

    url: URL

    @classmethod
    def from_url(cls, url: str | URL) -> SDEConfig:
        """Строит конфигурацию из URL в формате SQLAlchemy.

        Примеры: ``sqlite:///eve.db``, ``postgresql+psycopg://user:pass@host/db``,
        ``mysql+pymysql://user:pass@host/db``, ``mariadb+pymysql://user:pass@host/db``.
        """
        parsed = _make_url(url) if isinstance(url, str) else url
        _validate(parsed)
        return cls(url=parsed)

    @classmethod
    def from_params(
        cls,
        *,
        dialect: str,
        database: str,
        host: str | None = None,
        port: int | None = None,
        user: str | None = None,
        password: str | None = None,
        driver: str | None = None,
    ) -> SDEConfig:
        """Строит конфигурацию из отдельных параметров подключения.

        Для ``dialect="sqlite"`` допустим только параметр ``database``
        (путь к файлу БД или ``:memory:``) — host/port/user/password не
        применимы и приведут к ошибке.
        """
        if dialect not in SUPPORTED_DIALECTS:
            raise SDEConfigError(_unsupported_dialect_message(dialect))

        if dialect == "sqlite":
            if host is not None or port is not None or user is not None or password is not None:
                raise SDEConfigError(
                    "sqlite не поддерживает host/port/user/password, укажите только database"
                )
            drivername = "sqlite"
        else:
            drivername = f"{dialect}+{driver or _DEFAULT_DRIVER[dialect]}"

        url = URL.create(
            drivername=drivername,
            username=user,
            password=password,
            host=host,
            port=port,
            database=database,
        )
        _validate(url)
        return cls(url=url)

    def __str__(self) -> str:
        return self.url.render_as_string(hide_password=True)


def make_engine(config: SDEConfig) -> Engine:
    """Создаёт SQLAlchemy Engine из провалидированной конфигурации."""
    return create_engine(config.url)


def _validate(url: URL) -> None:
    dialect = url.get_backend_name()
    if dialect not in SUPPORTED_DIALECTS:
        raise SDEConfigError(_unsupported_dialect_message(dialect))

    driver = url.get_driver_name()
    allowed = _ALLOWED_DRIVERS[dialect]
    if driver not in allowed:
        expected = ", ".join(f"{dialect}+{d}" for d in allowed)
        raise SDEConfigError(
            f"Драйвер '{driver}' не поддерживается для диалекта '{dialect}'. "
            f"Используйте: {expected}."
        )

    module_name = _DRIVER_MODULE[driver]
    if importlib.util.find_spec(module_name) is None:
        extra = _EXTRA_BY_DIALECT.get(dialect)
        hint = f"pip install '{extra}'" if extra else f"pip install {module_name}"
        raise SDEConfigError(
            f"Не установлен драйвер '{module_name}', необходимый для '{dialect}'. "
            f"Выполните: {hint}."
        )


def _unsupported_dialect_message(dialect: str) -> str:
    return f"Неподдерживаемый диалект '{dialect}'. Поддерживаются: {', '.join(SUPPORTED_DIALECTS)}."
