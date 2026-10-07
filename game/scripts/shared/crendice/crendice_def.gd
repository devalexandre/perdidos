class_name CrendiceDef
extends Resource
## Definição de um Amuleto de Crendice (GDD §11, Sistema de Crendices).
## Em vez de cartas genéricas, os equipamentos possuem "Encaixes de Crendice" (sockets)
## onde o jogador insere amuletos folclóricos com Condições de Superstição.

enum SlotCategory { ANY, WEAPON, OFFHAND, BODY, HEAD, FEET, ACCESSORY }

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var lore_key: String = ""
@export var superstition_desc_key: String = ""
@export var icon: Texture2D

## Espaços de equipamento onde o amuleto pode ser engastado
@export var valid_slots: Array[StringName] = []

## Bônus diretos de atributos (chaves: str, dex, vit, int, spi, luk, atk, matk, def, mdef, etc.)
@export var stats: Dictionary[StringName, int] = {}

## Efeitos especiais e multiplicadores percentuais
## Chaves possíveis:
##   "crit_chance_pct": int
##   "phys_dmg_pct": int
##   "magic_dmg_pct": int
##   "holy_dmg_pct": int
##   "thunder_dmg_pct": int
##   "shadow_resist_pct": int
##   "curse_resist_pct": int
##   "flee_pct": int
##   "drop_rate_pct": int
##   "life_steal_pct": int
##   "poison_chance_pct": int
##   "ignore_def_pct": int
##   "damage_to_shield_pct": int
##   "hp_regen_idle_pct": int
##   "potion_efficiency_pct": int
##   "poison_immunity": bool
##   "slow_immunity": bool
##   "petrify_immunity": bool
##   "silence_immunity": bool
##   "stun_immunity": bool
##   "reflect_poison_pct": int
##   "slow_on_hit_pct": int
##   "poison_spread_area": bool
##   "emergency_shield_pct": int
@export var special_effects: Dictionary = {}

## Regra de Condição de Superstição que ativa/maximiza o bônus:
##   &"low_hp_double"        -> Bônus dobra se HP < 30% ("protege no desespero")
##   &"no_water_or_poison"   -> Perde o efeito se pisar na água/lama ou for envenenado
##   &"night_or_forest"      -> Só ativa à noite ou em mapas de mata densa
##   &"lucky_paw_death"      -> Anulado se o jogador morrer (adormece até ser reconsagrado no altar)
##   &"enemy_first_strike"   -> Jogador não pode iniciar combate (monstro deve atacar primeiro)
##   &"hp_above_50"          -> Só ativa se HP do jogador > 50%
##   &"weather_rain"         -> Bônus maximizado durante chuva
##   &"night_only"           -> Só ativa estritamente durante a noite
##   &"day_only"             -> Só ativa estritamente durante o dia
##   &"still_in_forest"      -> Só ativa enquanto parado em mapa de floresta
##   &"mana_above_40"        -> Só ativa se mana atual > 40%
##   &"mana_above_20"        -> Só ativa se mana atual > 20%
@export var superstition_rule: StringName = &""

## Regras temáticas para o drop por superstição:
## Chaves:
##   "monster_ids": Array[StringName]
##   "chance": float (0.0 a 1.0)
##   "crit_kill": bool
##   "killer_low_hp": bool (< 30% HP)
##   "no_poison_kill": bool
##   "enemy_struck_first": bool
##   "night_only": bool
##   "day_only": bool
##   "rain_only": bool
##   "atroz_only": bool
##   "boss_only": bool
##   "forest_only": bool
@export var drop_rules: Dictionary = {}

## Grupo de Sinergia Temática (ex: &"protecao_total", &"espirito_da_caca", &"elemental", &"plenilunio")
@export var synergy_group: StringName = &""
