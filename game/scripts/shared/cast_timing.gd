class_name CastTiming
extends RefCounted
## Tempo de uso na barra (GDD §8.1 "Tempo de uso na barra", §6.2, §11.3). Funções puras usadas pelo
## servidor (autoridade) e pelo cliente (dicas e animação da barra). Números em Balance.cfg
## (grupo "Cast & cooldown").
##
## - Skill: conjuração = base × (1 + 0,06 × (nível − 1)) × (1 − min(DES×0,5% + INT×0,3% [≤50%] + itens%, 60%));
##   recarga = base × (1 − min(ESP×0,4% + itens%, 40%)). Base 0 = instantânea.
## - Poções (heal_hp/heal_mp): instantâneas, sem recarga.
## - Demais usáveis: use_effect "cast_sec"/"cooldown_sec"/"cooldown_group" (padrões no Balance),
##   com as mesmas reduções de atributo e de item.
## `stats` é o dicionário de CharacterStats.compute() (servidor) ou Net.client_stats (cliente):
## chaves dex, int, spi e as somas de itens cast_reduction / cooldown_reduction (% inteiro).

const K_CAST_REDUCTION: StringName = &"cast_reduction"
const K_COOLDOWN_REDUCTION: StringName = &"cooldown_reduction"
const K_DEX: StringName = &"dex"
const K_INT: StringName = &"int"
const K_SPI: StringName = &"spi"
const EFFECT_HEAL_HP: StringName = &"heal_hp"
const EFFECT_HEAL_MP: StringName = &"heal_mp"
const EFFECT_CAST_SEC: StringName = &"cast_sec"
const EFFECT_COOLDOWN_SEC: StringName = &"cooldown_sec"
const EFFECT_COOLDOWN_GROUP: StringName = &"cooldown_group"
const PERCENT: float = 100.0
const MSEC_PER_SEC: float = 1000.0


static func _stat(stats: Dictionary, key: StringName) -> int:
	return int(stats.get(key, stats.get(String(key), 0)))


# ---------------------------------------------------------------- reduções

## Parte dos atributos na redução de conjuração (0..cast_reduction_attr_cap).
static func cast_attr_reduction(stats: Dictionary) -> float:
	var b: BalanceConfig = Balance.cfg
	var r: float = _stat(stats, K_DEX) * b.cast_reduction_per_dex + _stat(stats, K_INT) * b.cast_reduction_per_int
	return clampf(r, 0.0, b.cast_reduction_attr_cap)


## Parte dos itens (cast_reduction somado dos equipados, em fração).
static func cast_item_reduction(stats: Dictionary) -> float:
	return maxf(0.0, _stat(stats, K_CAST_REDUCTION) / PERCENT)


## Redução total da conjuração (atributos + itens), limitada a cast_reduction_total_cap.
static func cast_reduction(stats: Dictionary) -> float:
	return minf(cast_attr_reduction(stats) + cast_item_reduction(stats), Balance.cfg.cast_reduction_total_cap)


static func cooldown_attr_reduction(stats: Dictionary) -> float:
	return maxf(0.0, _stat(stats, K_SPI) * Balance.cfg.cooldown_reduction_per_spi)


static func cooldown_item_reduction(stats: Dictionary) -> float:
	return maxf(0.0, _stat(stats, K_COOLDOWN_REDUCTION) / PERCENT)


## Redução total da recarga (Espírito + itens), limitada a cooldown_reduction_cap.
static func cooldown_reduction(stats: Dictionary) -> float:
	return clampf(cooldown_attr_reduction(stats) + cooldown_item_reduction(stats), 0.0,
			Balance.cfg.cooldown_reduction_cap)


## Multiplicador do nível da skill: 1 + 0,06 × (nível − 1) (skill evoluída = mais lenta).
static func skill_level_factor(level: int) -> float:
	return 1.0 + Balance.cfg.cast_time_per_skill_level * (maxi(level, 1) - 1)


# ---------------------------------------------------------------- skills

## Conjuração efetiva (s). Base 0 continua instantânea.
static func skill_cast_sec(def: SkillDef, level: int, stats: Dictionary) -> float:
	if def == null or def.cast_time_sec <= 0.0:
		return 0.0
	return def.cast_time_sec * skill_level_factor(level) * (1.0 - cast_reduction(stats))


## Recarga efetiva (s).
static func skill_cooldown_sec(def: SkillDef, stats: Dictionary) -> float:
	if def == null or def.cooldown_sec <= 0.0:
		return 0.0
	return def.cooldown_sec * (1.0 - cooldown_reduction(stats))


static func to_ms(sec: float) -> int:
	return roundi(sec * MSEC_PER_SEC)


# ---------------------------------------------------------------- itens usáveis

## Poção de vida/mana: uso instantâneo, sem recarga (GDD §8.1, §11.3).
static func is_potion(def: ItemDef) -> bool:
	return def != null and def.type == ItemDef.ItemType.CONSUMABLE \
			and (def.use_effect.has(EFFECT_HEAL_HP) or def.use_effect.has(EFFECT_HEAL_MP))


static func is_instant_item(def: ItemDef) -> bool:
	return is_potion(def) and Balance.cfg.potions_instant


## Grupo de recarga do usável (padrão: o próprio id).
static func item_group(def: ItemDef) -> StringName:
	if def == null:
		return &""
	return StringName(str(def.use_effect.get(EFFECT_COOLDOWN_GROUP, def.id)))


static func item_base_cast_sec(def: ItemDef) -> float:
	if def == null or is_instant_item(def):
		return 0.0
	return maxf(0.0, float(def.use_effect.get(EFFECT_CAST_SEC, Balance.cfg.item_default_cast_sec)))


static func item_base_cooldown_sec(def: ItemDef) -> float:
	if def == null or is_instant_item(def):
		return 0.0
	return maxf(0.0, float(def.use_effect.get(EFFECT_COOLDOWN_SEC, Balance.cfg.item_default_cooldown_sec)))


static func item_cast_sec(def: ItemDef, stats: Dictionary) -> float:
	return item_base_cast_sec(def) * (1.0 - cast_reduction(stats))


static func item_cooldown_sec(def: ItemDef, stats: Dictionary) -> float:
	return item_base_cooldown_sec(def) * (1.0 - cooldown_reduction(stats))
