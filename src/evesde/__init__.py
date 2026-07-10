"""evesde — библиотека для работы со статическими данными EVE Online (SDE)."""

from __future__ import annotations

from evesde.api.sde import (
    SDE,
    Agent,
    DogmaAttribute,
    IndustryRecipe,
    Item,
    Meta,
    SDEAmbiguousNameError,
    SDENotFoundError,
    SolarSystem,
    TypeStats,
    UpdateResult,
)
from evesde.config import SDEConfig

__all__ = [
    "SDE",
    "Agent",
    "DogmaAttribute",
    "IndustryRecipe",
    "Item",
    "Meta",
    "SDEAmbiguousNameError",
    "SDENotFoundError",
    "SDEConfig",
    "SolarSystem",
    "TypeStats",
    "UpdateResult",
]
