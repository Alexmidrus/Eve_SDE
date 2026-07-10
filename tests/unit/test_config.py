"""Тесты парсинга и валидации SDEConfig."""

from __future__ import annotations

import importlib.util
from collections.abc import Iterator

import pytest
from sqlalchemy import text

from evesde.config import SDEConfig, SDEConfigError, make_engine


@pytest.fixture
def drivers_installed() -> Iterator[None]:
    """Притворяется, что psycopg и pymysql установлены (extras не входят в dev-окружение)."""
    real_find_spec = importlib.util.find_spec

    def fake_find_spec(name: str, *args: object, **kwargs: object) -> object | None:
        if name in ("psycopg", "pymysql"):
            return object()
        return real_find_spec(name, *args, **kwargs)  # type: ignore[return-value]

    original = importlib.util.find_spec
    importlib.util.find_spec = fake_find_spec  # type: ignore[assignment]
    try:
        yield
    finally:
        importlib.util.find_spec = original


@pytest.mark.parametrize(
    "url",
    [
        "sqlite:///eve.db",
        "sqlite:///:memory:",
        "postgresql+psycopg://user:pass@localhost:5432/eve",
        "mysql+pymysql://user:pass@localhost:3306/eve",
        "mariadb+pymysql://user:pass@localhost:3306/eve",
    ],
)
def test_from_url_accepts_all_supported_dialects(url: str, drivers_installed: None) -> None:
    config = SDEConfig.from_url(url)
    assert config.url.render_as_string(hide_password=False) == url


def test_from_url_hides_password_in_str(drivers_installed: None) -> None:
    config = SDEConfig.from_url("postgresql+psycopg://user:secret@localhost:5432/eve")
    assert "secret" not in str(config)
    assert "***" in str(config)


@pytest.mark.parametrize(
    "url",
    [
        "oracle://user:pass@localhost/eve",
        "mssql+pyodbc://user:pass@localhost/eve",
    ],
)
def test_from_url_rejects_unsupported_dialect(url: str) -> None:
    with pytest.raises(SDEConfigError, match="Неподдерживаемый диалект"):
        SDEConfig.from_url(url)


@pytest.mark.parametrize(
    "url",
    [
        "postgresql://user:pass@localhost:5432/eve",  # без явного +psycopg
        "postgresql+psycopg2://user:pass@localhost:5432/eve",  # неподдерживаемый драйвер
        "mysql+mysqldb://user:pass@localhost:3306/eve",
    ],
)
def test_from_url_rejects_unsupported_driver(url: str, drivers_installed: None) -> None:
    with pytest.raises(SDEConfigError, match="не поддерживается"):
        SDEConfig.from_url(url)


def test_from_url_reports_missing_driver_package() -> None:
    """Без extras драйверы psycopg/pymysql не установлены — ошибка должна быть понятной."""
    with pytest.raises(SDEConfigError, match=r"evesde\[postgres\]"):
        SDEConfig.from_url("postgresql+psycopg://user:pass@localhost:5432/eve")


def test_from_params_sqlite() -> None:
    config = SDEConfig.from_params(dialect="sqlite", database="eve.db")
    assert config.url.get_backend_name() == "sqlite"
    assert config.url.database == "eve.db"


def test_from_params_sqlite_rejects_host() -> None:
    with pytest.raises(SDEConfigError, match="host/port/user/password"):
        SDEConfig.from_params(dialect="sqlite", database="eve.db", host="localhost")


def test_from_params_postgresql_defaults_to_psycopg(drivers_installed: None) -> None:
    config = SDEConfig.from_params(
        dialect="postgresql",
        database="eve",
        host="localhost",
        port=5432,
        user="user",
        password="pass",
    )
    assert config.url.drivername == "postgresql+psycopg"


def test_from_params_mysql_defaults_to_pymysql(drivers_installed: None) -> None:
    config = SDEConfig.from_params(
        dialect="mysql",
        database="eve",
        host="localhost",
        user="user",
        password="pass",
    )
    assert config.url.drivername == "mysql+pymysql"


def test_from_params_rejects_unsupported_dialect() -> None:
    with pytest.raises(SDEConfigError, match="Неподдерживаемый диалект"):
        SDEConfig.from_params(dialect="oracle", database="eve")


def test_make_engine_sqlite_memory() -> None:
    config = SDEConfig.from_url("sqlite:///:memory:")
    engine = make_engine(config)
    with engine.connect() as conn:
        assert conn.execute(text("SELECT 1")).scalar() == 1
