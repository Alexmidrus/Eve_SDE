# Сводная схема данных EVE Online SDE

Полная схема атрибутов и типов данных по всем файлам SDE (Static Data Export) EVE Online, формат JSONL. Всего покрыто 79 файлов. Для каждого файла указаны связи (внешние ключи) с другими файлами, подтверждённые сверкой реальных значений (а не только по совпадению имён полей) — раздел «Связи (внешние ключи)» внутри описания файла и сводный раздел «Связи между таблицами (Foreign Keys)» перед итоговой таблицей.

Локализованные текстовые поля (`name`, `description`, `title`) во всех файлах имеют одинаковую структуру — объект с ключами языков: `de, en, es, fr, ja, ko, ru, zh` (тип каждого — `string`). В таблицах ниже это обозначено как `object<lang>`.

---

## `_sde.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | string |
| `buildNumber` | integer |
| `releaseDate` | string (ISO 8601 datetime) |

---

## `agentsInSpace.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `dungeonID` | integer |
| `solarSystemID` | integer |
| `spawnPointID` | integer |
| `typeID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `dungeonID` | **не является FK** | — | НЕ ЯВЛЯЕТСЯ FK — 0% совпадения с dungeons._key (0/169) — вероятно ссылается на ID динамического инстанса подземелья, которого нет в статичном SDE |
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |
| `typeID` | `types.jsonl` | 100% | подтверждено |

---

## `agentTypes.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `name` | string |

---

## `ancestries.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `bloodlineID` | integer |
| `charisma` | integer |
| `description` | object\<lang\> |
| `iconID` | integer |
| `intelligence` | integer |
| `memory` | integer |
| `name` | object\<lang\> |
| `perception` | integer |
| `shortDescription` | string |
| `willpower` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `bloodlineID` | `bloodlines.jsonl` | 100% | подтверждено |
| `iconID` | `icons.jsonl` | 100% | подтверждено |

---

## `archetypes.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `title` | object\<lang\> |

---

## `bloodlines.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `charisma` | integer |
| `corporationID` | integer |
| `description` | object\<lang\> |
| `iconID` | integer |
| `intelligence` | integer |
| `memory` | integer |
| `name` | object\<lang\> |
| `perception` | integer |
| `raceID` | integer |
| `willpower` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `corporationID` | `npcCorporations.jsonl` | 100% | подтверждено |
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `raceID` | `races.jsonl` | 100% | подтверждено |

---

## `blueprints.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `blueprintTypeID` | integer |
| `maxProductionLimit` | integer |
| `activities` | object |
| `activities.copying.time` | integer |
| `activities.copying.materials[]` | array of object |
| `activities.copying.materials[].quantity` | integer |
| `activities.copying.materials[].typeID` | integer |
| `activities.copying.skills[]` | array of object |
| `activities.copying.skills[].level` | integer |
| `activities.copying.skills[].typeID` | integer |
| `activities.manufacturing.time` | integer |
| `activities.manufacturing.materials[]` | array of object (см. copying.materials) |
| `activities.manufacturing.products[]` | array of object |
| `activities.manufacturing.products[].quantity` | integer |
| `activities.manufacturing.products[].typeID` | integer |
| `activities.manufacturing.skills[]` | array of object (см. copying.skills) |
| `activities.research_material.time` | integer |
| `activities.research_material.materials[]` | array of object (см. copying.materials) |
| `activities.research_material.skills[]` | array of object (см. copying.skills) |
| `activities.research_time.time` | integer |
| `activities.research_time.materials[]` | array of object (см. copying.materials) |
| `activities.research_time.skills[]` | array of object (см. copying.skills) |
| `activities.invention.time` | integer |
| `activities.invention.materials[]` | array of object (см. copying.materials) |
| `activities.invention.products[]` | array of object |
| `activities.invention.products[].probability` | float |
| `activities.invention.products[].quantity` | integer |
| `activities.invention.products[].typeID` | integer |
| `activities.invention.skills[]` | array of object (см. copying.skills) |
| `activities.reaction.time` | integer |
| `activities.reaction.materials[]` | array of object (см. copying.materials) |
| `activities.reaction.products[]` | array of object (см. manufacturing.products) |
| `activities.reaction.skills[]` | array of object (см. copying.skills) |

> Примечание: не для каждого чертежа присутствуют все виды активностей (`copying`, `manufacturing`, `research_material`, `research_time`, `invention`, `reaction`) — набор зависит от типа предмета.

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `activities.*.materials[].typeID` | `types.jsonl` | 99.9% (1700/1701) | подтверждено |
| `activities.*.products[].typeID` | `types.jsonl` | 99.7% (6147/6167) | подтверждено |
| `activities.*.skills[].typeID` | `types.jsonl` | 100% | подтверждено |
| `blueprintTypeID` | `types.jsonl` | 100% | подтверждено |

---

## `categories.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `name` | object\<lang\> |
| `published` | boolean |
| `iconID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `iconID` | `icons.jsonl` | 100% | подтверждено |

---

## `certificates.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `groupID` | integer |
| `name` | object\<lang\> |
| `recommendedFor[]` | array of integer |
| `skillTypes[]` | array of object |
| `skillTypes[]._key` | integer |
| `skillTypes[].advanced` | integer |
| `skillTypes[].basic` | integer |
| `skillTypes[].elite` | integer |
| `skillTypes[].improved` | integer |
| `skillTypes[].standard` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `groupID` | `groups.jsonl` | 100% | подтверждено — неоднозначно: возможно свой домен группировки сертификатов |
| `skillTypes[]._key` | `types.jsonl` | 100% | подтверждено |

---

## `characterAttributes.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | string |
| `iconID` | integer |
| `name` | object\<lang\> |
| `notes` | string |
| `shortDescription` | string |

---

## `characterTitles.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | string |
| `name` | object\<lang\> |

---

## `cloneGrades.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `name` | string |
| `skills[]` | array of object |
| `skills[].level` | integer |
| `skills[].typeID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `skills[].typeID` | `types.jsonl` | 100% | подтверждено |

---

## `compressibleTypes.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `compressedTypeID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_key` | `types.jsonl` | 100% | подтверждено — PK = typeID сжимаемого предмета |
| `compressedTypeID` | `types.jsonl` | 100% | подтверждено |

---

## `contrabandTypes.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `factions[]` | array of object |
| `factions[]._key` | integer |
| `factions[].attackMinSec` | float |
| `factions[].confiscateMinSec` | float |
| `factions[].fineByValue` | float |
| `factions[].standingLoss` | float |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_key` | `types.jsonl` | 100% | подтверждено — PK = typeID контрабандного предмета |
| `factions[]._key` | `factions.jsonl` | 100% | подтверждено |

---

## `controlTowerResources.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `resources[]` | array of object |
| `resources[].purpose` | integer |
| `resources[].quantity` | integer |
| `resources[].resourceTypeID` | integer |
| `resources[].factionID` | integer |
| `resources[].minSecurityLevel` | float |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_key` | `types.jsonl` | 100% | подтверждено — PK = typeID контрол-тауэра |
| `resources[].factionID` | `factions.jsonl` | 100% | подтверждено |
| `resources[].resourceTypeID` | `types.jsonl` | 100% | подтверждено |

---

## `landmarks.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `name` | object\<lang\> |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `iconID` | integer |
| `locationID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `locationID` | `mapSolarSystems.jsonl` | 100% | подтверждено — неоднозначно: universe location id |

---

## `corporationActivities.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `name` | object\<lang\> |

---

## `dbuffCollections.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `aggregateMode` | string |
| `developerDescription` | string |
| `operationName` | string |
| `showOutputValueInUI` | string |
| `displayName` | object\<lang\> |
| `itemModifiers[]` | array of object |
| `itemModifiers[].dogmaAttributeID` | integer |
| `locationGroupModifiers[]` | array of object |
| `locationGroupModifiers[].dogmaAttributeID` | integer |
| `locationGroupModifiers[].groupID` | integer |
| `locationModifiers[]` | array of object |
| `locationModifiers[].dogmaAttributeID` | integer |
| `locationRequiredSkillModifiers[]` | array of object |
| `locationRequiredSkillModifiers[].dogmaAttributeID` | integer |
| `locationRequiredSkillModifiers[].skillID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `itemModifiers[].dogmaAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `locationGroupModifiers[].dogmaAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `locationGroupModifiers[].groupID` | `groups.jsonl` | 100% | подтверждено |
| `locationModifiers[].dogmaAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `locationRequiredSkillModifiers[].dogmaAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `locationRequiredSkillModifiers[].skillID` | `types.jsonl` | 100% | подтверждено |

---

## `dogmaAttributeCategories.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | string |
| `name` | string |

---

## `dogmaAttributes.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `attributeCategoryID` | integer |
| `dataType` | integer |
| `defaultValue` | float |
| `description` | string |
| `displayWhenZero` | boolean |
| `highIsGood` | boolean |
| `name` | string |
| `published` | boolean |
| `stackable` | boolean |
| `displayName` | object\<lang\> |
| `iconID` | integer |
| `tooltipDescription` | object\<lang\> |
| `tooltipTitle` | object\<lang\> |
| `unitID` | integer |
| `chargeRechargeTimeID` | integer |
| `maxAttributeID` | integer |
| `minAttributeID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `attributeCategoryID` | `dogmaAttributeCategories.jsonl` | 100% | подтверждено |
| `chargeRechargeTimeID` | `dogmaAttributes.jsonl` | 100% | подтверждено — самоссылка |
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `maxAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено — самоссылка |
| `minAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено — самоссылка |
| `unitID` | `dogmaUnits.jsonl` | 100% | подтверждено |

---

## `dogmaEffects.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `disallowAutoRepeat` | boolean |
| `dischargeAttributeID` | integer |
| `durationAttributeID` | integer |
| `effectCategoryID` | integer |
| `electronicChance` | boolean |
| `guid` | string |
| `isAssistance` | boolean |
| `isOffensive` | boolean |
| `isWarpSafe` | boolean |
| `name` | string |
| `propulsionChance` | boolean |
| `published` | boolean |
| `rangeChance` | boolean |
| `distribution` | integer |
| `falloffAttributeID` | integer |
| `rangeAttributeID` | integer |
| `trackingSpeedAttributeID` | integer |
| `description` | object\<lang\> |
| `displayName` | object\<lang\> |
| `iconID` | integer |
| `npcUsageChanceAttributeID` | integer |
| `npcActivationChanceAttributeID` | integer |
| `fittingUsageChanceAttributeID` | integer |
| `resistanceAttributeID` | integer |
| `modifierInfo[]` | array of object |
| `modifierInfo[].domain` | string |
| `modifierInfo[].func` | string |
| `modifierInfo[].modifiedAttributeID` | integer |
| `modifierInfo[].modifyingAttributeID` | integer |
| `modifierInfo[].operation` | integer |
| `modifierInfo[].groupID` | integer |
| `modifierInfo[].skillTypeID` | integer |
| `modifierInfo[].effectID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `dischargeAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `durationAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `falloffAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `fittingUsageChanceAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `modifierInfo[].effectID` | `dogmaEffects.jsonl` | 100% | подтверждено — самоссылка |
| `modifierInfo[].groupID` | `groups.jsonl` | 100% | подтверждено |
| `modifierInfo[].modifiedAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `modifierInfo[].modifyingAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `modifierInfo[].skillTypeID` | `types.jsonl` | 100% | подтверждено |
| `npcActivationChanceAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `npcUsageChanceAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `rangeAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `resistanceAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `trackingSpeedAttributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |

---

## `dogmaUnits.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `displayName` | object\<lang\> |
| `name` | string |

---

## `dungeons.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `allowedShipsList[]` | array of integer |
| `archetypeID` | integer |
| `description` | object\<lang\> |
| `factionID` | integer |
| `name` | object\<lang\> |
| `gameplayDescription` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `allowedShipsList[]` | `groups.jsonl` | 87.0% (60/69) | подтверждено (смешанная) — смешанный список: элемент может быть либо groupID (группа кораблей), либо конкретный typeID корабля |
| `allowedShipsList[]` | `types.jsonl` | 33.3% (23/69) | подтверждено (смешанная) — смешанный список: элемент может быть либо groupID (группа кораблей), либо конкретный typeID корабля |
| `archetypeID` | `archetypes.jsonl` | 100% | подтверждено |
| `factionID` | `factions.jsonl` | 100% | подтверждено |

---

## `dynamicItemAttributes.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `attributeIDs[]` | array of object |
| `attributeIDs[]._key` | integer |
| `attributeIDs[].max` | float |
| `attributeIDs[].min` | float |
| `attributeIDs[].highIsGood` | boolean |
| `inputOutputMapping[]` | array of object |
| `inputOutputMapping[].applicableTypes[]` | array of integer |
| `inputOutputMapping[].resultingType` | integer |

> Актуально для PI/производства модулей с абиссальными/динамическими характеристиками — задаёт диапазоны min/max для генерируемых атрибутов предмета.

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_key` | `types.jsonl` | 100% | подтверждено — PK = typeID мутаплазмида, проверить |
| `attributeIDs[]._key` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `inputOutputMapping[].applicableTypes[]` | `types.jsonl` | 100% | подтверждено |
| `inputOutputMapping[].resultingType` | `types.jsonl` | 100% | подтверждено |

---

## `epicArcs.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `arcRestartInterval` | integer |
| `factionID` | integer |
| `iconID` | integer |
| `name` | object\<lang\> |
| `missions[]` | array of object |
| `missions[]._key` | integer |
| `missions[].agentID` | integer |
| `missions[].failMissionID` | integer |
| `missions[].nextMissions[]` | array of integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `factionID` | `factions.jsonl` | 100% | подтверждено |
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `missions[].agentID` | `npcCharacters.jsonl` | 100% | подтверждено |

---

## `factions.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `corporationID` | integer |
| `description` | object\<lang\> |
| `flatLogo` | string |
| `flatLogoWithName` | string |
| `iconID` | integer |
| `memberRaces[]` | array of integer |
| `militiaCorporationID` | integer |
| `name` | object\<lang\> |
| `shortDescription` | object\<lang\> |
| `sizeFactor` | float |
| `solarSystemID` | integer |
| `uniqueName` | boolean |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `corporationID` | `npcCorporations.jsonl` | 100% | подтверждено |
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `memberRaces[]` | `races.jsonl` | 100% | подтверждено |
| `militiaCorporationID` | `npcCorporations.jsonl` | 100% | подтверждено |
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |

---

## `freelanceJobSchemas.jsonl`

Самая глубоко вложенная структура из всех рассмотренных файлов (1 запись, но с большим деревом). Верхний уровень:

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `_value[]` | array of object (схема заданий) |

Каждый элемент `_value[]` описывает тип фриланс-задания:

| Атрибут (внутри `_value[]`) | Тип |
|---|---|
| `_key` | string |
| `contentTags[]` | array of string |
| `description` | object\<lang\> |
| `iconID` | string |
| `progressDescription` | object\<lang\> |
| `rewardDescription` | object\<lang\> |
| `targetDescription` | object\<lang\> |
| `title` | object\<lang\> |
| `maxContributionsPerParticipant` | object (`description`, `iconID`, `title`, `unsetDescription` — все object\<lang\> кроме `iconID`: string) |
| `contributionMultiplier` | object (`defaultValue`: integer, `minValue`: float, `maxValue`: integer, `description`/`title`/`unsetDescription`: object\<lang\>, `iconID`: string) |
| `maxProgressPerContribution` | object (`description`/`title`/`unsetDescription`: object\<lang\>, `iconID`: string) |
| `parameters[]` | array of object — параметры задания, каждый содержит: |
| `parameters[]._key` | string |
| `parameters[].matcher` | object — общий шаблон полей: `acceptedValueTypes[]` (array of string), `type` (string), `maxEntries` (integer), `optional` (boolean), `description`/`title`/`unsetDescription` (object\<lang\>), `iconID` (string) |
| `parameters[].itemDelivery` | object — `deliveryLocation` и `inventoryType` (оба повторяют структуру `matcher`), плюс `description`/`title` (object\<lang\>), `iconID` (string) |
| `parameters[].boolean` | object — `default` (boolean), `choiceLabel`/`description`/`title` (object\<lang\>), `iconID` (string), `optionTrue`/`optionFalse` (object: `description`+`title` как object\<lang\>) |

> Примечание: этот файл описывает мета-схему UI для фриланс-заданий (job board), а не сами задания игроков — по сути конфигурация формы: какие параметры, лейблы и лимиты доступны при создании задания.

---

## `graphicMaterialSets.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | string |
| `sofFactionName` | string |
| `sofRaceHint` | string |
| `sofPatternName` | string |
| `resPathInsert` | string |
| `material1` | string |
| `material2` | string |
| `material3` | string |
| `material4` | string |
| `custommaterial1` | string |
| `custommaterial2` | string |
| `colorHull` | object |
| `colorHull.r/g/b/a` | float |
| `colorPrimary` | object |
| `colorPrimary.r/g/b/a` | float |
| `colorSecondary` | object |
| `colorSecondary.r/g/b/a` | float |
| `colorWindow` | object |
| `colorWindow.r/g/b/a` | float |

---

## `graphics.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `graphicFile` | string |
| `iconFolder` | string |
| `sofFactionName` | string |
| `sofHullName` | string |
| `sofRaceName` | string |
| `sofMaterialSetID` | integer |
| `sofLayout[]` | array of string |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `sofMaterialSetID` | `graphicMaterialSets.jsonl` | 100% | подтверждено |

---

## `groups.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `anchorable` | boolean |
| `anchored` | boolean |
| `categoryID` | integer |
| `fittableNonSingleton` | boolean |
| `name` | object\<lang\> |
| `published` | boolean |
| `useBasePrice` | boolean |
| `iconID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `categoryID` | `categories.jsonl` | 100% | подтверждено |
| `iconID` | `icons.jsonl` | 100% | подтверждено |

---

## `icons.jsonl`

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `iconFile` | string |

---

## `mapAsteroidBelts.jsonl`

Записей (просканировано): 40928

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `celestialIndex` | integer |
| `orbitID` | integer |
| `orbitIndex` | integer |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `radius` | float |
| `solarSystemID` | integer |
| `statistics` | object |
| `statistics.density` | float |
| `statistics.eccentricity` | float |
| `statistics.escapeVelocity` | float |
| `statistics.locked` | boolean |
| `statistics.massDust` | float |
| `statistics.massGas` | float |
| `statistics.orbitPeriod` | float |
| `statistics.orbitRadius` | float |
| `statistics.rotationRate` | float |
| `statistics.spectralClass` | string |
| `statistics.surfaceGravity` | float |
| `statistics.temperature` | float |
| `typeID` | integer |
| `uniqueName` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |

---

## `mapConstellations.jsonl`

Записей (просканировано): 1184

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `factionID` | integer |
| `name` | object\<lang\> |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `regionID` | integer |
| `solarSystemIDs[]` | array of integer |
| `wormholeClassID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `factionID` | `factions.jsonl` | 100% | подтверждено |
| `regionID` | `mapRegions.jsonl` | 100% | подтверждено |
| `solarSystemIDs[]` | `mapSolarSystems.jsonl` | 100% | подтверждено |

---

## `mapMoons.jsonl`

Записей (просканировано): 344457

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `attributes` | object |
| `attributes.heightMap1` | integer |
| `attributes.heightMap2` | integer |
| `attributes.shaderPreset` | integer |
| `celestialIndex` | integer |
| `npcStationIDs[]` | array of integer |
| `orbitID` | integer |
| `orbitIndex` | integer |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `radius` | float |
| `solarSystemID` | integer |
| `statistics` | object |
| `statistics.density` | float |
| `statistics.eccentricity` | float |
| `statistics.escapeVelocity` | float |
| `statistics.locked` | boolean |
| `statistics.massDust` | float |
| `statistics.massGas` | float |
| `statistics.orbitPeriod` | float |
| `statistics.orbitRadius` | float |
| `statistics.pressure` | float |
| `statistics.rotationRate` | float |
| `statistics.spectralClass` | string |
| `statistics.surfaceGravity` | float |
| `statistics.temperature` | float |
| `typeID` | integer |
| `uniqueName` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `npcStationIDs[]` | `npcStations.jsonl` | 100% | подтверждено |
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |
| `typeID` | `types.jsonl` | 100% | подтверждено |

---

## `mapPlanets.jsonl`

Записей (просканировано): 68407

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `asteroidBeltIDs[]` | array of integer |
| `attributes` | object |
| `attributes.heightMap1` | integer |
| `attributes.heightMap2` | integer |
| `attributes.population` | boolean |
| `attributes.shaderPreset` | integer |
| `celestialIndex` | integer |
| `moonIDs[]` | array of integer |
| `npcStationIDs[]` | array of integer |
| `orbitID` | integer |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `radius` | integer |
| `solarSystemID` | integer |
| `statistics` | object |
| `statistics.density` | float |
| `statistics.eccentricity` | float |
| `statistics.escapeVelocity` | float |
| `statistics.locked` | boolean |
| `statistics.massDust` | float |
| `statistics.massGas` | float |
| `statistics.orbitPeriod` | float |
| `statistics.orbitRadius` | float |
| `statistics.pressure` | float |
| `statistics.rotationRate` | float |
| `statistics.spectralClass` | string |
| `statistics.surfaceGravity` | float |
| `statistics.temperature` | float |
| `typeID` | integer |
| `uniqueName` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `asteroidBeltIDs[]` | `mapAsteroidBelts.jsonl` | 100% | подтверждено |
| `moonIDs[]` | `mapMoons.jsonl` | 100% | подтверждено |
| `npcStationIDs[]` | `npcStations.jsonl` | 100% | подтверждено |
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |
| `typeID` | `types.jsonl` | 100% | подтверждено |

---

## `mapRegions.jsonl`

Записей (просканировано): 114

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `constellationIDs[]` | array of integer |
| `description` | object\<lang\> |
| `factionID` | integer |
| `name` | object\<lang\> |
| `nebulaID` | integer |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `wormholeClassID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `constellationIDs[]` | `mapConstellations.jsonl` | 100% | подтверждено |
| `factionID` | `factions.jsonl` | 100% | подтверждено |

---

## `mapSecondarySuns.jsonl`

Записей (просканировано): 1038

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `effectBeaconTypeID` | integer |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `solarSystemID` | integer |
| `typeID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `effectBeaconTypeID` | `types.jsonl` | 100% | подтверждено |
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |
| `typeID` | `types.jsonl` | 100% | подтверждено |

---

## `mapSolarSystems.jsonl`

Записей (просканировано): 8490

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `border` | boolean |
| `constellationID` | integer |
| `corridor` | boolean |
| `disallowedAnchorCategories[]` | array of integer |
| `disallowedAnchorGroups[]` | array of integer |
| `factionID` | integer |
| `fringe` | boolean |
| `hub` | boolean |
| `international` | boolean |
| `luminosity` | float |
| `name` | object\<lang\> |
| `planetIDs[]` | array of integer |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `position2D` | object |
| `position2D.x` | float |
| `position2D.y` | float |
| `radius` | float |
| `regionID` | integer |
| `regional` | boolean |
| `securityClass` | string |
| `securityStatus` | float |
| `starID` | integer |
| `stargateIDs[]` | array of integer |
| `visualEffect` | string |
| `wormholeClassID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `constellationID` | `mapConstellations.jsonl` | 100% | подтверждено |
| `disallowedAnchorCategories[]` | `categories.jsonl` | 100% | подтверждено |
| `disallowedAnchorGroups[]` | `groups.jsonl` | 100% | подтверждено |
| `factionID` | `factions.jsonl` | 100% | подтверждено |
| `planetIDs[]` | `mapPlanets.jsonl` | 100% | подтверждено |
| `regionID` | `mapRegions.jsonl` | 100% | подтверждено |
| `starID` | `mapStars.jsonl` | 100% | подтверждено |
| `stargateIDs[]` | `mapStargates.jsonl` | 100% | подтверждено |

---

## `mapStargates.jsonl`

Записей (просканировано): 13978

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `destination` | object |
| `destination.solarSystemID` | integer |
| `destination.stargateID` | integer |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `solarSystemID` | integer |
| `typeID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `destination.solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |
| `destination.stargateID` | `mapStargates.jsonl` | 100% | подтверждено — самоссылка (парный стargate) |
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |
| `typeID` | `types.jsonl` | 100% | подтверждено |

---

## `mapStars.jsonl`

Записей (просканировано): 8089

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `radius` | integer |
| `solarSystemID` | integer |
| `statistics` | object |
| `statistics.age` | float |
| `statistics.life` | float |
| `statistics.luminosity` | float |
| `statistics.spectralClass` | string |
| `statistics.temperature` | float |
| `typeID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |
| `typeID` | `types.jsonl` | 100% | подтверждено |

---

## `marketGroups.jsonl`

Записей (просканировано): 2102

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `hasTypes` | boolean |
| `iconID` | integer |
| `name` | object\<lang\> |
| `parentGroupID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `parentGroupID` | `marketGroups.jsonl` | 100% | подтверждено — самоссылка (иерархия групп рынка) |

---

## `masteries.jsonl`

Записей (просканировано): 476

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `_value[]` | array of object |
| `_value[]._key` | integer |
| `_value[]._value[]` | array of integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_key` | `types.jsonl` | 100% | подтверждено — PK = typeID корабля |
| `_value[]._key` | **не является FK** | — | НЕ ЯВЛЯЕТСЯ FK — это порядковый номер уровня мастерства (0-4), а не FK |
| `_value[]._value[]` | `certificates.jsonl` | 100% | подтверждено (добавлено) — уровень мастерства -> список требуемых certificateID |

---

## `mercenaryTacticalOperations.jsonl`

Записей (просканировано): 3

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `anarchyImpact` | integer |
| `description` | object\<lang\> |
| `developmentImpact` | integer |
| `dungeonID` | integer |
| `infomorphBonus` | integer |
| `name` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `dungeonID` | `dungeons.jsonl` | 100% | подтверждено |

---

## `metaGroups.jsonl`

Записей (просканировано): 13

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `color` | object |
| `color.b` | float |
| `color.g` | float |
| `color.r` | float |
| `description` | object\<lang\> |
| `iconID` | integer |
| `iconSuffix` | string |
| `name` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `iconID` | `icons.jsonl` | 100% | подтверждено |

---

## `militaryCampaignObjectives.jsonl`

Записей (просканировано): 42

| Атрибут | Тип |
|---|---|
| `_key` | string |
| `annotations` | object |
| `annotations.requiredEnlistmentWithFactionID` | integer |
| `annotations.restrictionTooltip` | object\<lang\> |
| `annotations.warning1` | object\<lang\> |
| `annotations.warning2` | object\<lang\> |
| `campaignID` | string |
| `careerPath` | string |
| `contentTags[]` | array of string |
| `contributionMethodConfiguration` | object |
| `contributionMethodConfiguration.name` | string |
| `contributionMethodConfiguration.parameters[]` | array of object |
| `contributionMethodConfiguration.parameters[].key` | string |
| `contributionMethodConfiguration.parameters[].matcher` | object |
| `contributionMethodConfiguration.parameters[].matcher.values[]` | array of object |
| `contributionMethodConfiguration.parameters[].matcher.values[].valueType` | string |
| `contributionMethodConfiguration.parameters[].matcher.values[].values[]` | array of string |
| `issuer` | object |
| `issuer.corporationID` | integer |
| `maxProgressPerParticipant` | integer |
| `presentingCharacterID` | integer |
| `rewards` | object |
| `rewards.isk` | object |
| `rewards.isk.amountPerInterval` | integer |
| `rewards.isk.issuer` | object |
| `rewards.isk.issuer.corporationID` | integer |
| `rewards.isk.progressInterval` | integer |
| `rewards.lp` | object |
| `rewards.lp.amountPerInterval` | integer |
| `rewards.lp.issuer` | object |
| `rewards.lp.issuer.corporationID` | integer |
| `rewards.lp.progressInterval` | integer |
| `rewards.standing` | object |
| `rewards.standing.gainPercentPerInterval` | float |
| `rewards.standing.issuer` | object |
| `rewards.standing.issuer.factionID` | integer |
| `rewards.standing.progressInterval` | integer |
| `subtitle` | object\<lang\> |
| `targetProgress` | integer |
| `title` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `campaignID` | `militaryCampaigns.jsonl` | 100% | подтверждено — тип string, ключ militaryCampaigns._key |
| `issuer.corporationID` | `npcCorporations.jsonl` | 100% | подтверждено |
| `presentingCharacterID` | `npcCharacters.jsonl` | 100% | подтверждено |
| `rewards.isk.issuer.corporationID` | `npcCorporations.jsonl` | 100% | подтверждено |
| `rewards.lp.issuer.corporationID` | `npcCorporations.jsonl` | 100% | подтверждено |
| `rewards.standing.issuer.factionID` | `factions.jsonl` | 100% | подтверждено |

---

## `militaryCampaigns.jsonl`

Записей (просканировано): 4

| Атрибут | Тип |
|---|---|
| `_key` | string |
| `annotations` | object |
| `annotations.aoCampaignCardButtonImage` | string |
| `annotations.backgroundVideoLoop` | string |
| `annotations.briefingBackground` | string |
| `annotations.briefingFailureDescription` | object\<lang\> |
| `annotations.briefingFailureHeader` | object\<lang\> |
| `annotations.briefingFinalWords` | object\<lang\> |
| `annotations.briefingForeground` | string |
| `annotations.briefingGoalDescription` | object\<lang\> |
| `annotations.briefingHeader` | object\<lang\> |
| `annotations.briefingMiddleground` | string |
| `annotations.briefingSuccessDescription` | object\<lang\> |
| `annotations.briefingSuccessHeader` | object\<lang\> |
| `annotations.campaignSet` | string |
| `annotations.dashboardAmbientBackground` | string |
| `annotations.dashboardBackground` | string |
| `annotations.dashboardForeground` | string |
| `annotations.dashboardMiddleground` | string |
| `annotations.finishedCampaignEnded` | object\<lang\> |
| `annotations.finishedFailureDescription` | object\<lang\> |
| `annotations.finishedResolutionStateFailure` | object\<lang\> |
| `annotations.finishedResolutionStateSuccess` | object\<lang\> |
| `annotations.finishedSuccessDescription` | object\<lang\> |
| `annotations.foregroundVideoIntro` | string |
| `annotations.foregroundVideoLoop` | string |
| `annotations.foregroundVideoOutro` | string |
| `annotations.mapFocusEntityID` | integer |
| `annotations.mapHeader` | object\<lang\> |
| `annotations.mapSection1Paragraph` | object\<lang\> |
| `annotations.mapSection1Title` | object\<lang\> |
| `annotations.mapSection2Paragraph` | object\<lang\> |
| `annotations.mapSection2Title` | object\<lang\> |
| `annotations.mapSection3Paragraph` | object\<lang\> |
| `annotations.mapSection3Title` | object\<lang\> |
| `annotations.mapSubheader` | object\<lang\> |
| `annotations.mapTitle` | object\<lang\> |
| `annotations.middlegroundVideoIntro` | string |
| `annotations.middlegroundVideoLoop` | string |
| `annotations.middlegroundVideoOutro` | string |
| `annotations.presentingCharacterName` | object\<lang\> |
| `annotations.presentingCharacterSubtitle` | object\<lang\> |
| `annotations.presentingCharacterTexturePath` | string |
| `annotations.race` | string |
| `annotations.themePack` | string |
| `annotations.towCampaignCardButtonImage` | string |
| `issuer` | object |
| `issuer.factionID` | integer |
| `subtitle` | object\<lang\> |
| `targetProgress` | integer |
| `title` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `issuer.factionID` | `factions.jsonl` | 100% | подтверждено |

---

## `missions.jsonl`

Записей (просканировано): 2892

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `agentTypeID` | integer |
| `corporationID` | integer |
| `courierMission` | object |
| `courierMission.objectiveQuantity` | integer |
| `courierMission.objectiveSingleton` | boolean |
| `courierMission.objectiveTypeID` | integer |
| `expirationTime` | integer |
| `extraStandings[]` | array of object |
| `extraStandings[]._key` | integer |
| `extraStandings[]._value` | float |
| `factionID` | integer |
| `hasStandingRewards` | boolean |
| `initialAgentGiftQuantity` | integer |
| `initialAgentGiftTypeID` | integer |
| `killMission` | object |
| `killMission.dropItemInMissionContainer` | integer |
| `killMission.dungeonID` | integer |
| `killMission.objectiveQuantity` | integer |
| `killMission.objectiveTypeID` | integer |
| `messages[]` | array of object |
| `messages[]._key` | string |
| `messages[].de` | string |
| `messages[].en` | string |
| `messages[].es` | string |
| `messages[].fr` | string |
| `messages[].ja` | string |
| `messages[].ko` | string |
| `messages[].ru` | string |
| `messages[].zh` | string |
| `missionRewards` | object |
| `missionRewards.bonusReward` | object |
| `missionRewards.bonusReward.rewardQuantity` | integer |
| `missionRewards.bonusReward.rewardTypeID` | integer |
| `missionRewards.bonusTimeInterval` | integer |
| `missionRewards.reward` | object |
| `missionRewards.reward.rewardQuantity` | integer |
| `missionRewards.reward.rewardTypeID` | integer |
| `name` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `agentTypeID` | `agentTypes.jsonl` | 100% | подтверждено |
| `corporationID` | `npcCorporations.jsonl` | 100% | подтверждено |
| `courierMission.objectiveTypeID` | `types.jsonl` | 100% | подтверждено |
| `extraStandings[]._key` | `factions.jsonl` | 100% | подтверждено |
| `factionID` | `factions.jsonl` | 100% | подтверждено |
| `initialAgentGiftTypeID` | `types.jsonl` | 100% | подтверждено |
| `killMission.dungeonID` | **не является FK** | — | НЕ ЯВЛЯЕТСЯ FK — 0.2% совпадения (3/1460) — аналогично agentsInSpace.dungeonID, не является статической FK |
| `killMission.objectiveTypeID` | `types.jsonl` | 100% | подтверждено |
| `missionRewards.bonusReward.rewardTypeID` | `types.jsonl` | 100% | подтверждено |
| `missionRewards.reward.rewardTypeID` | `types.jsonl` | 100% | подтверждено |

---

## `npcCharacters.jsonl`

Записей (просканировано): 11393

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `agent` | object |
| `agent.agentTypeID` | integer |
| `agent.divisionID` | integer |
| `agent.isLocator` | boolean |
| `agent.level` | integer |
| `ancestryID` | integer |
| `bloodlineID` | integer |
| `careerID` | integer |
| `ceo` | boolean |
| `corporationID` | integer |
| `description` | string |
| `gender` | boolean |
| `locationID` | integer |
| `name` | object\<lang\> |
| `raceID` | integer |
| `schoolID` | integer |
| `skills[]` | array of object |
| `skills[].typeID` | integer |
| `specialityID` | integer |
| `startDate` | string |
| `uniqueName` | boolean |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `agent.agentTypeID` | `agentTypes.jsonl` | 100% | подтверждено |
| `agent.divisionID` | `npcCorporationDivisions.jsonl` | 100% | подтверждено |
| `ancestryID` | `ancestries.jsonl` | 100% | подтверждено |
| `bloodlineID` | `bloodlines.jsonl` | 100% | подтверждено |
| `corporationID` | `npcCorporations.jsonl` | 100% | подтверждено |
| `locationID` | `npcStations.jsonl` | 100% | подтверждено — неоднозначно |
| `raceID` | `races.jsonl` | 100% | подтверждено |
| `skills[].typeID` | `types.jsonl` | 100% | подтверждено |

---

## `npcCorporationDivisions.jsonl`

Записей (просканировано): 10

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `displayName` | string |
| `internalName` | string |
| `leaderTypeName` | object\<lang\> |
| `name` | object\<lang\> |

---


## `npcCorporations.jsonl`

Записей (просканировано): 283

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `allowedMemberRaces[]` | array of integer |
| `ceoID` | integer |
| `corporationTrades[]` | array of object |
| `corporationTrades[]._key` | integer |
| `corporationTrades[]._value` | float |
| `deleted` | boolean |
| `description` | object\<lang\> |
| `divisions[]` | array of object |
| `divisions[]._key` | integer |
| `divisions[].divisionNumber` | integer |
| `divisions[].leaderID` | integer |
| `divisions[].size` | integer |
| `enemyID` | integer |
| `exchangeRates[]` | array of object |
| `exchangeRates[]._key` | integer |
| `exchangeRates[]._value` | float |
| `extent` | string |
| `factionID` | integer |
| `friendID` | integer |
| `hasPlayerPersonnelManager` | boolean |
| `iconID` | integer |
| `initialPrice` | integer |
| `investors[]` | array of object |
| `investors[]._key` | integer |
| `investors[]._value` | integer |
| `lpOfferTables[]` | array of integer |
| `mainActivityID` | integer |
| `memberLimit` | integer |
| `minSecurity` | float |
| `minimumJoinStanding` | integer |
| `name` | object\<lang\> |
| `raceID` | integer |
| `secondaryActivityID` | integer |
| `sendCharTerminationMessage` | boolean |
| `shares` | integer |
| `size` | string |
| `sizeFactor` | float |
| `solarSystemID` | integer |
| `stationID` | integer |
| `taxRate` | float |
| `tickerName` | string |
| `uniqueName` | boolean |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `allowedMemberRaces[]` | `races.jsonl` | 100% | подтверждено |
| `ceoID` | `npcCharacters.jsonl` | 99.6% (257/258) | подтверждено |
| `corporationTrades[]._key` | `types.jsonl` | 100% | подтверждено (исправлено) — исправлено: реальная цель — types.jsonl (typeID торгуемого товара), не npcCorporations; _value — экономический коэффициент (float) |
| `divisions[].leaderID` | `npcCharacters.jsonl` | 99.2% (245/247) | подтверждено |
| `enemyID` | `npcCorporations.jsonl` | 100% | подтверждено — самоссылка |
| `exchangeRates[]._key` | `npcCorporations.jsonl` | 100% | подтверждено — неоднозначно, проверить |
| `factionID` | `factions.jsonl` | 100% | подтверждено |
| `friendID` | `npcCorporations.jsonl` | 100% | подтверждено — самоссылка |
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `investors[]._key` | `npcCorporations.jsonl` | 100% | подтверждено — самоссылка |
| `mainActivityID` | `corporationActivities.jsonl` | 100% | подтверждено |
| `raceID` | `races.jsonl` | 100% | подтверждено |
| `secondaryActivityID` | `corporationActivities.jsonl` | 100% | подтверждено |
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |
| `stationID` | `npcStations.jsonl` | 99.6% (236/237) | подтверждено |

---

## `npcStations.jsonl`

Записей (просканировано): 5210

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `celestialIndex` | integer |
| `operationID` | integer |
| `orbitID` | integer |
| `orbitIndex` | integer |
| `ownerID` | integer |
| `position` | object |
| `position.x` | float |
| `position.y` | float |
| `position.z` | float |
| `reprocessingEfficiency` | float |
| `reprocessingHangarFlag` | integer |
| `reprocessingStationsTake` | float |
| `solarSystemID` | integer |
| `typeID` | integer |
| `useOperationName` | boolean |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `operationID` | `stationOperations.jsonl` | 100% | подтверждено |
| `ownerID` | `npcCorporations.jsonl` | 100% | подтверждено |
| `solarSystemID` | `mapSolarSystems.jsonl` | 100% | подтверждено |
| `typeID` | `types.jsonl` | 100% | подтверждено |

---

## `planetResources.jsonl`

Записей (просканировано): 25798

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `power` | integer |
| `reagent` | object |
| `reagent.amount_per_cycle` | integer |
| `reagent.cycle_period` | integer |
| `reagent.secured_capacity` | integer |
| `reagent.type_id` | integer |
| `reagent.unsecured_capacity` | integer |
| `workforce` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_key` | `mapPlanets.jsonl` | 89.5% (23086/25798) | подтверждено (исправлено) — PK — это ID планеты (celestial ID), не typeID; часть значений не находит планету (устаревшие/удалённые записи) |
| `reagent.type_id` | `types.jsonl` | 100% | подтверждено |

---

## `planetSchematics.jsonl`

Записей (просканировано): 68

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `cycleTime` | integer |
| `name` | object\<lang\> |
| `pins[]` | array of integer |
| `types[]` | array of object |
| `types[]._key` | integer |
| `types[].isInput` | boolean |
| `types[].quantity` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `pins[]` | `types.jsonl` | 100% | подтверждено |
| `types[]._key` | `types.jsonl` | 100% | подтверждено |

---

## `races.jsonl`

Записей (просканировано): 11

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `iconID` | integer |
| `name` | object\<lang\> |
| `shipTypeID` | integer |
| `skills[]` | array of object |
| `skills[]._key` | integer |
| `skills[]._value` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `shipTypeID` | `types.jsonl` | 100% | подтверждено |
| `skills[]._key` | `types.jsonl` | 100% | подтверждено |

---

## `shipTreeElements.jsonl`

Записей (просканировано): 30

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `icon` | string |
| `name` | object\<lang\> |

---


## `shipTreeFactions.jsonl`

Записей (просканировано): 17

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `elements[]` | array of object |
| `elements[]._key` | integer |
| `elements[]._value` | integer |
| `icon` | string |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_key` | `factions.jsonl` | 100% | подтверждено — проверить |
| `elements[]._key` | **не является FK** | — | НЕ ЯВЛЯЕТСЯ FK — порядковый индекс элемента массива (1..N), не FK |
| `elements[]._value` | `shipTreeElements.jsonl` | 100% | подтверждено (добавлено) |

---

## `shipTreeGroups.jsonl`

Записей (просканировано): 52

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `elements[]` | array of object |
| `elements[]._key` | integer |
| `elements[]._value` | integer |
| `icon` | string |
| `iconLarge` | string |
| `iconSmall` | string |
| `iconSmallNPC` | string |
| `name` | object\<lang\> |
| `preReqSkills[]` | array of object |
| `preReqSkills[]._key` | integer |
| `preReqSkills[].skills[]` | array of object |
| `preReqSkills[].skills[]._key` | integer |
| `preReqSkills[].skills[].display` | boolean |
| `preReqSkills[].skills[].level` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `elements[]._key` | **не является FK** | — | НЕ ЯВЛЯЕТСЯ FK — порядковый индекс элемента массива (1..N), не FK |
| `elements[]._value` | `shipTreeElements.jsonl` | 100% | подтверждено (добавлено) |
| `preReqSkills[]._key` | `factions.jsonl` | 100% | подтверждено (смешанная) — значения — реальные factionID (напр. 500001=Caldari), совпадают и с factions, и с производной shipTreeFactions |
| `preReqSkills[]._key` | `shipTreeFactions.jsonl` | 100% | подтверждено (смешанная) — значения — реальные factionID (напр. 500001=Caldari), совпадают и с factions, и с производной shipTreeFactions |
| `preReqSkills[].skills[]._key` | `types.jsonl` | 100% | подтверждено |

---

## `skinLicenses.jsonl`

Записей (просканировано): 11794

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `duration` | integer |
| `isSingleUse` | boolean |
| `licenseTypeID` | integer |
| `skinID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `licenseTypeID` | `types.jsonl` | 99.9% (11787/11794) | подтверждено |
| `skinID` | `skins.jsonl` | 99.9% (6956/6963) | подтверждено |

---

## `skinMaterials.jsonl`

Записей (просканировано): 859

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `displayName` | object\<lang\> |
| `materialSetID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `materialSetID` | `graphicMaterialSets.jsonl` | 100% | подтверждено — неоднозначно, проверить |

---

## `skinrComponentCategories.jsonl`

Записей (просканировано): 3

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `name` | string |

---


## `skinrComponentPointValues.jsonl`

Записей (просканировано): 3

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `_value[]` | array of object |
| `_value[]._key` | integer |
| `_value[]._value` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_value[]._key` | `skinrComponentRarities.jsonl` | 100% | подтверждено — проверить |

---

## `skinrComponentRarities.jsonl`

Записей (просканировано): 6

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `name` | object\<lang\> |
| `rank` | integer |

---


## `skinrComponents.jsonl`

Записей (просканировано): 543

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `associatedTypeIds[]` | array of object |
| `associatedTypeIds[].licenseUsesGranted` | integer |
| `associatedTypeIds[].typeID` | integer |
| `category` | integer |
| `finish` | string |
| `iconFile` | string |
| `name` | object\<lang\> |
| `projectionTypeU` | string |
| `projectionTypeV` | string |
| `published` | boolean |
| `rarity` | integer |
| `resourceFile` | string |
| `sequenceBinder` | object |
| `sequenceBinder.count` | integer |
| `sequenceBinder.itemTypeID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `associatedTypeIds[].typeID` | `types.jsonl` | 100% | подтверждено |
| `category` | `skinrComponentCategories.jsonl` | 100% | подтверждено |
| `rarity` | `skinrComponentRarities.jsonl` | 100% | подтверждено |
| `sequenceBinder.itemTypeID` | `types.jsonl` | 100% | подтверждено |

---

## `skinrSlotCategories.jsonl`

Записей (просканировано): 3

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `name` | string |

---


## `skinrSlotConfigurations.jsonl`

Записей (просканировано): 4

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `allowAllShips` | boolean |
| `config[]` | array of integer |
| `name` | string |
| `priority` | integer |
| `ships[]` | array of integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `config[]` | `skinrSlots.jsonl` | 100% | подтверждено — проверить |
| `ships[]` | `types.jsonl` | 100% | подтверждено |

---

## `skinrSlotNames.jsonl`

Записей (просканировано): 8

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `name` | string |

---


## `skinrSlots.jsonl`

Записей (просканировано): 8

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `allowedDesignComponentCategories[]` | array of integer |
| `category` | integer |
| `name` | object\<lang\> |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `allowedDesignComponentCategories[]` | `skinrComponentCategories.jsonl` | 100% | подтверждено |
| `category` | `skinrSlotCategories.jsonl` | 100% | подтверждено |

---

## `skinrTierThresholds.jsonl`

Записей (просканировано): 49

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `_value[]` | array of object |
| `_value[]._key` | integer |
| `_value[]._value` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_value[]._key` | **не является FK** | — | НЕ ЯВЛЯЕТСЯ FK — порядковый номер порога (tier index 1-19), не FK; случайное совпадение с skinrComponentRarities (1-6) — ложное срабатывание |

---

## `skins.jsonl`

Записей (просканировано): 6965

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `allowCCPDevs` | boolean |
| `internalName` | string |
| `isStructureSkin` | boolean |
| `skinMaterialID` | integer |
| `types[]` | array of integer |
| `visibleSerenity` | boolean |
| `visibleTranquility` | boolean |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `skinMaterialID` | `skinMaterials.jsonl` | 100% | подтверждено |
| `types[]` | `types.jsonl` | 100% | подтверждено |

---

## `sovereigntyUpgrades.jsonl`

Записей (просканировано): 49

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `fuel` | object |
| `fuel.hourly_upkeep` | integer |
| `fuel.startup_cost` | integer |
| `fuel.type_id` | integer |
| `mutually_exclusive_group` | string |
| `power_allocation` | integer |
| `power_production` | integer |
| `workforce_allocation` | integer |
| `workforce_production` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `fuel.type_id` | `types.jsonl` | 100% | подтверждено |

---

## `stationOperations.jsonl`

Записей (просканировано): 68

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `activityID` | integer |
| `border` | float |
| `corridor` | float |
| `description` | object\<lang\> |
| `fringe` | float |
| `hub` | float |
| `manufacturingFactor` | float |
| `operationName` | object\<lang\> |
| `ratio` | float |
| `researchFactor` | float |
| `services[]` | array of integer |
| `stationTypes[]` | array of object |
| `stationTypes[]._key` | integer |
| `stationTypes[]._value` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `activityID` | `corporationActivities.jsonl` | 100% | подтверждено — проверить |
| `services[]` | `stationServices.jsonl` | 100% | подтверждено |
| `stationTypes[]._key` | **не является FK** | — | НЕ ЯВЛЯЕТСЯ FK — значения [1,2,4,8,16] — битовая маска флагов операции станции, а не typeID (совпадение 4/5 с types.jsonl случайно из-за малых чисел) |

---

## `stationServices.jsonl`

Записей (просканировано): 27

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `description` | object\<lang\> |
| `serviceName` | object\<lang\> |

---


## `translationLanguages.jsonl`

Записей (просканировано): 8

| Атрибут | Тип |
|---|---|
| `_key` | string |
| `name` | string |

---


## `typeBonus.jsonl`

Записей (просканировано): 650

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `iconID` | integer |
| `miscBonuses[]` | array of object |
| `miscBonuses[].bonus` | integer / float |
| `miscBonuses[].bonusText` | object\<lang\> |
| `miscBonuses[].importance` | integer |
| `miscBonuses[].isPositive` | boolean |
| `miscBonuses[].unitID` | integer |
| `roleBonuses[]` | array of object |
| `roleBonuses[].bonus` | integer / float |
| `roleBonuses[].bonusText` | object\<lang\> |
| `roleBonuses[].importance` | integer |
| `roleBonuses[].unitID` | integer |
| `types[]` | array of object |
| `types[]._key` | integer |
| `types[]._value[]` | array of object |
| `types[]._value[].bonus` | integer / float |
| `types[]._value[].bonusText` | object\<lang\> |
| `types[]._value[].importance` | integer |
| `types[]._value[].unitID` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `miscBonuses[].unitID` | `dogmaUnits.jsonl` | 100% | подтверждено |
| `roleBonuses[].unitID` | `dogmaUnits.jsonl` | 100% | подтверждено |
| `types[]._key` | `types.jsonl` | 100% | подтверждено |
| `types[]._value[].unitID` | `dogmaUnits.jsonl` | 100% | подтверждено |

---

## `typeDogma.jsonl`

Записей (просканировано): 26724

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `dogmaAttributes[]` | array of object |
| `dogmaAttributes[].attributeID` | integer |
| `dogmaAttributes[].value` | float |
| `dogmaEffects[]` | array of object |
| `dogmaEffects[].effectID` | integer |
| `dogmaEffects[].isDefault` | boolean |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_key` | `types.jsonl` | 100% | подтверждено — PK = typeID |
| `dogmaAttributes[].attributeID` | `dogmaAttributes.jsonl` | 100% | подтверждено |
| `dogmaEffects[].effectID` | `dogmaEffects.jsonl` | 100% | подтверждено |

---

## `typeElements.jsonl`

Записей (просканировано): 422

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `elements[]` | array of object |
| `elements[]._key` | integer |
| `elements[]._value` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `elements[]._key` | `types.jsonl` | 90.9% (10/11) | частично — неоднозначно, проверить |

---

## `typeLists.jsonl`

Записей (просканировано): 460

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `displayDescription` | object\<lang\> |
| `displayName` | object\<lang\> |
| `excludedCategoryIDs[]` | array of integer |
| `excludedGroupIDs[]` | array of integer |
| `excludedTypeIDs[]` | array of integer |
| `includedCategoryIDs[]` | array of integer |
| `includedGroupIDs[]` | array of integer |
| `includedTypeIDs[]` | array of integer |
| `name` | string |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `excludedCategoryIDs[]` | `categories.jsonl` | 100% | подтверждено |
| `excludedGroupIDs[]` | `groups.jsonl` | 100% | подтверждено |
| `excludedTypeIDs[]` | `types.jsonl` | 100% | подтверждено |
| `includedCategoryIDs[]` | `categories.jsonl` | 100% | подтверждено |
| `includedGroupIDs[]` | `groups.jsonl` | 100% | подтверждено |
| `includedTypeIDs[]` | `types.jsonl` | 100% | подтверждено |

---

## `typeMaterials.jsonl`

Записей (просканировано): 9548

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `materials[]` | array of object |
| `materials[].materialTypeID` | integer |
| `materials[].quantity` | integer |
| `randomizedMaterials[]` | array of object |
| `randomizedMaterials[].materialTypeID` | integer |
| `randomizedMaterials[].quantityMax` | integer |
| `randomizedMaterials[].quantityMin` | integer |

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `_key` | `types.jsonl` | 100% | подтверждено — PK = typeID |
| `materials[].materialTypeID` | `types.jsonl` | 100% | подтверждено |
| `randomizedMaterials[].materialTypeID` | `types.jsonl` | 100% | подтверждено |

---

## `types.jsonl`

Записей (просканировано): 52630

| Атрибут | Тип |
|---|---|
| `_key` | integer |
| `basePrice` | float |
| `capacity` | float |
| `description` | object\<lang\> |
| `factionID` | integer |
| `graphicID` | integer |
| `groupID` | integer |
| `iconID` | integer |
| `marketGroupID` | integer |
| `mass` | float |
| `metaGroupID` | integer |
| `metaLevel` | integer |
| `name` | object\<lang\> |
| `portionSize` | integer |
| `published` | boolean |
| `raceID` | integer |
| `radius` | float |
| `shipTreeGroupID` | integer |
| `soundID` | integer |
| `techLevel` | integer |
| `variationParentTypeID` | integer |
| `volume` | float |

---

**Связи (внешние ключи):**

| Поле | Ссылается на | Совпадение | Статус / примечание |
|---|---|---|---|
| `factionID` | `factions.jsonl` | 69.7% (23/33) | подтверждено (смешанная) — смешанная ссылка: для большинства типов — на factions.jsonl, но часть значений (10 из 33) на самом деле corporationID из npcCorporations.jsonl |
| `factionID` | `npcCorporations.jsonl` | 30.3% (10/33) | подтверждено (смешанная) — смешанная ссылка: для большинства типов — на factions.jsonl, но часть значений (10 из 33) на самом деле corporationID из npcCorporations.jsonl |
| `graphicID` | `graphics.jsonl` | 97.9% (3986/4071) | подтверждено |
| `groupID` | `groups.jsonl` | 100% | подтверждено |
| `iconID` | `icons.jsonl` | 100% | подтверждено |
| `marketGroupID` | `marketGroups.jsonl` | 100% | подтверждено |
| `metaGroupID` | `metaGroups.jsonl` | 100% | подтверждено |
| `raceID` | `races.jsonl` | 100% | подтверждено |
| `shipTreeGroupID` | `shipTreeGroups.jsonl` | 100% | подтверждено |
| `variationParentTypeID` | `types.jsonl` | 100% | подтверждено — самоссылка |

---

---

## Связи между таблицами (Foreign Keys) — сводный анализ

Ниже — результат сплошной проверки всех потенциальных FK-полей (имена вида `*ID`, `*IDs[]`, `type_id`, вложенные `_key`/`_value` и т.п.) по всем 79 файлам. Проверка не ограничивалась догадкой по имени поля: для каждого кандидата были извлечены реально встречающиеся значения и сверены с множеством `_key` предполагаемой целевой таблицы. Детальные таблицы по каждому файлу — в разделе **«Связи (внешние ключи)»** внутри описания каждого файла выше. Всего проверено кандидатов: **214**, подтверждено (совпадение ≥95%): **201**, отброшено как ложные срабатывания: **7**, со смешанной/неоднозначной целью: **6**.

### Хаб-таблицы (наиболее часто цитируемые файлы)

Таблицы, на которые ссылается больше всего других файлов — это кандидаты на отдельные справочники (lookup tables) в итоговой схеме БД:

| Файл (таблица) | Кол-во входящих ссылок (FK, указывающих на неё) |
|---|---|
| `types.jsonl` | 54 |
| `dogmaAttributes.jsonl` | 20 |
| `factions.jsonl` | 15 |
| `icons.jsonl` | 14 |
| `npcCorporations.jsonl` | 14 |
| `mapSolarSystems.jsonl` | 13 |
| `groups.jsonl` | 8 |
| `races.jsonl` | 6 |
| `dogmaUnits.jsonl` | 4 |
| `npcCharacters.jsonl` | 4 |
| `categories.jsonl` | 4 |
| `npcStations.jsonl` | 4 |
| `corporationActivities.jsonl` | 3 |
| `bloodlines.jsonl` | 2 |
| `dogmaEffects.jsonl` | 2 |
| `graphicMaterialSets.jsonl` | 2 |
| `mapRegions.jsonl` | 2 |
| `mapConstellations.jsonl` | 2 |
| `mapPlanets.jsonl` | 2 |
| `mapStargates.jsonl` | 2 |
| `marketGroups.jsonl` | 2 |
| `agentTypes.jsonl` | 2 |
| `skinrComponentRarities.jsonl` | 2 |
| `skinrComponentCategories.jsonl` | 2 |
| `shipTreeElements.jsonl` | 2 |
| `dogmaAttributeCategories.jsonl` | 1 |
| `archetypes.jsonl` | 1 |
| `mapStars.jsonl` | 1 |
| `dungeons.jsonl` | 1 |
| `militaryCampaigns.jsonl` | 1 |
| `npcCorporationDivisions.jsonl` | 1 |
| `ancestries.jsonl` | 1 |
| `stationOperations.jsonl` | 1 |
| `shipTreeFactions.jsonl` | 1 |
| `skins.jsonl` | 1 |
| `skinrSlots.jsonl` | 1 |
| `skinrSlotCategories.jsonl` | 1 |
| `skinMaterials.jsonl` | 1 |
| `stationServices.jsonl` | 1 |
| `metaGroups.jsonl` | 1 |
| `graphics.jsonl` | 1 |
| `shipTreeGroups.jsonl` | 1 |
| `mapAsteroidBelts.jsonl` | 1 |
| `mapMoons.jsonl` | 1 |
| `certificates.jsonl` | 1 |

### Особые случаи, найденные при проверке (важно для проектирования БД)

Ниже — случаи, где имя поля вводит в заблуждение относительно реальной связи. Все выводы получены сверкой фактических значений, а не по аналогии имён.

**Поля, которые выглядят как FK, но не являются ими:**

- `agentsInSpace.dungeonID` — 0% совпадения с dungeons._key (0/169) — вероятно ссылается на ID динамического инстанса подземелья, которого нет в статичном SDE
- `masteries._value[]._key` — это порядковый номер уровня мастерства (0-4), а не FK
- `shipTreeFactions.elements[]._key` — порядковый индекс элемента массива (1..N), не FK
- `shipTreeGroups.elements[]._key` — порядковый индекс элемента массива (1..N), не FK
- `skinrTierThresholds._value[]._key` — порядковый номер порога (tier index 1-19), не FK; случайное совпадение с skinrComponentRarities (1-6) — ложное срабатывание
- `stationOperations.stationTypes[]._key` — значения [1,2,4,8,16] — битовая маска флагов операции станции, а не typeID (совпадение 4/5 с types.jsonl случайно из-за малых чисел)
- `missions.killMission.dungeonID` — 0.2% совпадения (3/1460) — аналогично agentsInSpace.dungeonID, не является статической FK

**Поля со смешанной/неоднозначной целью (ссылаются на разные таблицы в зависимости от записи):**

- `dungeons.allowedShipsList[]` → `groups.jsonl`, `types.jsonl` — смешанный список: элемент может быть либо groupID (группа кораблей), либо конкретный typeID корабля
- `shipTreeGroups.preReqSkills[]._key` → `factions.jsonl`, `shipTreeFactions.jsonl` — значения — реальные factionID (напр. 500001=Caldari), совпадают и с factions, и с производной shipTreeFactions
- `types.factionID` → `factions.jsonl`, `npcCorporations.jsonl` — смешанная ссылка: для большинства типов — на factions.jsonl, но часть значений (10 из 33) на самом деле corporationID из npcCorporations.jsonl

**Прочие важные наблюдения:**

- Множество полей `*.dogmaAttributeID`, `*AttributeID` в `dogmaEffects.jsonl` и `dbuffCollections.jsonl` образуют плотный хаб вокруг `dogmaAttributes.jsonl` — при нормализации это будет одна из центральных таблиц.
- `types.jsonl` — главный хаб схемы (54 входящие ссылки): почти любой файл, где встречается предмет, корабль, скилл или ресурс, ссылается на него через `typeID`/`type_id`/`materialTypeID` и т.п.
- Самоссылки (self-reference) отмечены отдельно в таблицах файлов: `types.variationParentTypeID`, `npcCorporations.enemyID/friendID/investors/corporationTrades`, `marketGroups.parentGroupID`, `dogmaEffects.modifierInfo[].effectID`, `mapStargates.destination.stargateID` (парный стargate) и др.
- Поля `_key`/`_value` внутри вложенных массивов (`masteries`, `skinrTierThresholds`, `shipTreeGroups.elements`) часто оказываются НЕ идентификатором, а порядковым индексом или числовым значением — реальная FK может находиться в соседнем `_value`, а не в `_key`, что и было обнаружено проверкой данных.
- `epicArcs.missions[].failMissionID` и `epicArcs.missions[].nextMissions[]` — это ссылки НЕ на `missions.jsonl`, а на `_key` соседних элементов того же массива `missions[]` (внутренний граф шагов арки).

---

## Сводная таблица по файлам

| Файл | Кол-во записей | Верхнеуровневые поля | Есть вложенные объекты | Есть массивы |
|---|---|---|---|---|
| `_sde.jsonl` | 1 | 3 | нет | нет |
| `agentsInSpace.jsonl` | 360 | 5 | нет | нет |
| `agentTypes.jsonl` | 13 | 2 | нет | нет |
| `ancestries.jsonl` | 43 | 11 | да (`name`, `description`) | нет |
| `archetypes.jsonl` | 34 | 3 | да (`title`, `description`) | нет |
| `bloodlines.jsonl` | 18 | 11 | да (`name`, `description`) | нет |
| `blueprints.jsonl` | 5081 | 4 | да (`activities.*`) | да |
| `categories.jsonl` | 48 | 4 | да (`name`) | нет |
| `certificates.jsonl` | 139 | 5 | да (`name`, `description`) | да (`recommendedFor`, `skillTypes`) |
| `characterAttributes.jsonl` | 5 | 6 | да (`name`) | нет |
| `characterTitles.jsonl` | 43 | 2 | да (`name`) | нет |
| `cloneGrades.jsonl` | 4 | 3 | нет | да (`skills`) |
| `compressibleTypes.jsonl` | 212 | 2 | нет | нет |
| `contrabandTypes.jsonl` | 8 | 2 | нет | да (`factions`) |
| `controlTowerResources.jsonl` | 44 | 2 | нет | да (`resources`) |
| `landmarks.jsonl` | 45 | 5 | да (`name`, `description`, `position`) | нет |
| `corporationActivities.jsonl` | 20 | 2 | да (`name`) | нет |
| `dbuffCollections.jsonl` | 270 | 7 | да (`displayName`) | да (4 вида модификаторов) |
| `dogmaAttributeCategories.jsonl` | 37 | 3 | нет | нет |
| `dogmaAttributes.jsonl` | 2855 | 18 | да (`displayName`, `tooltipDescription`, `tooltipTitle`) | нет |
| `dogmaEffects.jsonl` | 3411 | 25 | да (`description`, `displayName`) | да (`modifierInfo`) |
| `dogmaUnits.jsonl` | 60 | 3 | да (`description`, `displayName`) | нет |
| `dungeons.jsonl` | 1404 | 6 | да (`description`, `name`, `gameplayDescription`) | да (`allowedShipsList`) |
| `dynamicItemAttributes.jsonl` | 413 | 2 | нет | да (`attributeIDs`, `inputOutputMapping`) |
| `epicArcs.jsonl` | 21 | 4 | да (`name`) | да (`missions`) |
| `factions.jsonl` | 27 | 12 | да (`description`, `name`, `shortDescription`) | да (`memberRaces`) |
| `freelanceJobSchemas.jsonl` | 1 | 2 | да, глубоко (5+ уровней) | да |
| `graphicMaterialSets.jsonl` | 931 | 15 | да (4 цветовых объекта) | нет |
| `graphics.jsonl` | 6021 | 7 | нет | да (`sofLayout`) |
| `groups.jsonl` | 1605 | 8 | да (`name`) | нет |
| `icons.jsonl` | 4648 | 2 | нет | нет |
| `mapAsteroidBelts.jsonl` | 40928 | 10 | да (`position`, `statistics`, `uniqueName`) | нет |
| `mapConstellations.jsonl` | 1184 | 7 | да (`name`, `position`) | да (`solarSystemIDs`) |
| `mapMoons.jsonl` | 344457 | 12 | да (`attributes`, `position`, `statistics`, `uniqueName`) | да (`npcStationIDs`) |
| `mapPlanets.jsonl` | 68407 | 13 | да (`attributes`, `position`, `statistics`, `uniqueName`) | да (`asteroidBeltIDs`, `moonIDs`, `npcStationIDs`) |
| `mapRegions.jsonl` | 114 | 8 | да (`description`, `name`, `position`) | да (`constellationIDs`) |
| `mapSecondarySuns.jsonl` | 1038 | 5 | да (`position`) | нет |
| `mapSolarSystems.jsonl` | 8490 | 24 | да (`name`, `position`, `position2D`) | да (`planetIDs`, `stargateIDs`, `disallowedAnchorCategories`, `disallowedAnchorGroups`) |
| `mapStargates.jsonl` | 13978 | 5 | да (`destination`, `position`) | нет |
| `mapStars.jsonl` | 8089 | 5 | да (`statistics`) | нет |
| `marketGroups.jsonl` | 2102 | 6 | да (`description`, `name`) | нет |
| `masteries.jsonl` | 476 | 2 | нет | да (`_value`) |
| `mercenaryTacticalOperations.jsonl` | 3 | 7 | да (`description`, `name`) | нет |
| `metaGroups.jsonl` | 13 | 6 | да (`color`, `name`, `description`) | нет |
| `militaryCampaignObjectives.jsonl` | 42 | 13 | да (`contributionMethodConfiguration`, `issuer`, `rewards`, `subtitle`, `title`, `annotations`) | да (`contentTags`) |
| `militaryCampaigns.jsonl` | 4 | 6 | да (`annotations`, `issuer`, `subtitle`, `title`) | нет |
| `missions.jsonl` | 2892 | 14 | да (`killMission`, `name`, `courierMission`, `missionRewards`) | да (`messages`, `extraStandings`) |
| `npcCharacters.jsonl` | 11393 | 17 | да (`name`, `agent`) | да (`skills`) |
| `npcCorporationDivisions.jsonl` | 10 | 6 | да (`leaderTypeName`, `name`, `description`) | нет |
| `npcCorporations.jsonl` | 283 | 33 | да (`description`, `name`) | да (`allowedMemberRaces`, `corporationTrades`, `divisions`, `investors`, `lpOfferTables`, `exchangeRates`) |
| `npcStations.jsonl` | 5210 | 13 | да (`position`) | нет |
| `planetResources.jsonl` | 25798 | 4 | да (`reagent`) | нет |
| `planetSchematics.jsonl` | 68 | 5 | да (`name`) | да (`pins`, `types`) |
| `races.jsonl` | 11 | 6 | да (`description`, `name`) | да (`skills`) |
| `shipTreeElements.jsonl` | 30 | 4 | да (`description`, `name`) | нет |
| `shipTreeFactions.jsonl` | 17 | 4 | да (`description`) | да (`elements`) |
| `shipTreeGroups.jsonl` | 52 | 9 | да (`description`, `name`) | да (`elements`, `preReqSkills`) |
| `skinLicenses.jsonl` | 11794 | 5 | нет | нет |
| `skinMaterials.jsonl` | 859 | 3 | да (`displayName`) | нет |
| `skinrComponentCategories.jsonl` | 3 | 2 | нет | нет |
| `skinrComponentPointValues.jsonl` | 3 | 2 | нет | да (`_value`) |
| `skinrComponentRarities.jsonl` | 6 | 3 | да (`name`) | нет |
| `skinrComponents.jsonl` | 543 | 12 | да (`name`, `sequenceBinder`) | да (`associatedTypeIds`) |
| `skinrSlotCategories.jsonl` | 3 | 2 | нет | нет |
| `skinrSlotConfigurations.jsonl` | 4 | 6 | нет | да (`config`, `ships`) |
| `skinrSlotNames.jsonl` | 8 | 2 | нет | нет |
| `skinrSlots.jsonl` | 8 | 4 | да (`name`) | да (`allowedDesignComponentCategories`) |
| `skinrTierThresholds.jsonl` | 49 | 2 | нет | да (`_value`) |
| `skins.jsonl` | 6965 | 8 | нет | да (`types`) |
| `sovereigntyUpgrades.jsonl` | 49 | 7 | да (`fuel`) | нет |
| `stationOperations.jsonl` | 68 | 13 | да (`description`, `operationName`) | да (`services`, `stationTypes`) |
| `stationServices.jsonl` | 27 | 3 | да (`serviceName`, `description`) | нет |
| `translationLanguages.jsonl` | 8 | 2 | нет | нет |
| `typeBonus.jsonl` | 650 | 5 | нет | да (`roleBonuses`, `types`, `miscBonuses`) |
| `typeDogma.jsonl` | 26724 | 3 | нет | да (`dogmaAttributes`, `dogmaEffects`) |
| `typeElements.jsonl` | 422 | 2 | нет | да (`elements`) |
| `typeLists.jsonl` | 460 | 10 | да (`displayDescription`, `displayName`) | да (`includedTypeIDs`, `includedGroupIDs`, `includedCategoryIDs`, `excludedGroupIDs`, `excludedTypeIDs`, `excludedCategoryIDs`) |
| `typeMaterials.jsonl` | 9548 | 3 | нет | да (`materials`, `randomizedMaterials`) |
| `types.jsonl` | 52630 | 22 | да (`name`, `description`) | нет |
