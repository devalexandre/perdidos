class_name CharacterStats
extends RefCounted
## Atributos e valores derivados [PROVISÓRIO] do GDD §6.2, §6.4 e §10.2. Função pura: recebe
## nível, atributos base e o equipamento e devolve o dicionário do contrato (stats_changed).

## GDD §6.2: todos começam com 5 em cada atributo.
const BASE_ATTRIBUTE: int = 5
## GDD §6.3: personagem novo começa no nível 1.
const START_LEVEL: int = 1
# GDD §6.4
const HP_BASE: int = 100
const HP_PER_VIT: int = 12
const HP_PER_LEVEL: int = 8
const MP_BASE: int = 50
const MP_PER_INT: int = 8
const MP_PER_LEVEL: int = 4
# GDD §10.2
const ATK_PER_STR: int = 2
const MATK_PER_INT: int = 2
const DEF_PER_VIT: int = 1
const MDEF_PER_SPI: int = 1

## GDD §6.2 (27/09/2026): Sorte (&"luk", sigla SOR) no fim. Saves antigos sem ela ganham BASE_ATTRIBUTE.
const ATTRIBUTES: Array[StringName] = [&"str", &"dex", &"vit", &"int", &"spi", &"luk"]
const K_LEVEL: StringName = &"level"
const K_HP: StringName = &"hp"
const K_MAX_HP: StringName = &"max_hp"
const K_MP: StringName = &"mp"
const K_MAX_MP: StringName = &"max_mp"
const K_ATK: StringName = &"atk"
const K_MATK: StringName = &"matk"
const K_HOLY_MATK: StringName = &"holy_matk"
const K_DEF: StringName = &"def"
const K_MDEF: StringName = &"mdef"
## GDD §8.1 (28/09/2026): somas (% inteiro) de ItemDef.stats dos itens equipados; usadas por CastTiming.
const K_CAST_REDUCTION: StringName = &"cast_reduction"
const K_COOLDOWN_REDUCTION: StringName = &"cooldown_reduction"
## GDD §6.2 (30/09/2026): índice em ATTRIBUTES do atributo que dá o ATK (o da arma equipada).
const K_ATK_ATTR: StringName = &"atk_attr"
## Sem arma, ou arma sem scaling_attribute: Força.
const DEFAULT_ATK_ATTRIBUTE: StringName = &"str"
const WEAPON_SLOT: StringName = &"weapon"


static func base_attributes() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for a: StringName in ATTRIBUTES:
		out[a] = BASE_ATTRIBUTE
	return out


## Soma dos bônus (ItemDef.stats) das pilhas equipadas nos 7 espaços normais + bônus de Crendices ativas.
static func equipment_bonus(equipment: Equipment, context: Dictionary = {}) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if equipment == null:
		return out
	for st: ItemStack in equipment.gear_stacks():
		var def: ItemDef = st.get_def()
		if def == null:
			continue
		for k: StringName in def.stats:
			out[k] = out.get(k, 0) + def.stats[k]
	# Bônus de atributos das Crendices
	var crendice_res: Dictionary = CrendiceSystem.calc_equipped_bonuses(equipment, context)
	var c_stats: Dictionary = crendice_res.get("stats", {})
	for k: StringName in c_stats:
		out[k] = out.get(k, 0) + int(c_stats[k])
	return out


static func equipment_percent_bonus(equipment: Equipment) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if equipment == null:
		return out
	for st: ItemStack in equipment.gear_stacks():
		var def: ItemDef = st.get_def()
		if def == null:
			continue
		for k: StringName in def.stat_percent:
			out[k] = out.get(k, 0) + def.stat_percent[k]
	return out


## Atributo que dá o ATK: Projéteis = DES; Corpo a corpo / sem arma = FOR; Arcano = INT; Título Sagrado = ESP.
static func atk_attribute(equipment: Equipment, title_id: StringName = &"") -> StringName:
	var st: ItemStack = equipment.get_slot(WEAPON_SLOT) if equipment != null else null
	var def: ItemDef = st.get_def() if st != null else null
	if def != null:
		if def.is_projectile_weapon():
			return &"dex"
		if def.weapon_kind == ItemDef.WeaponKind.BLADE:
			return &"str"
		if def.weapon_kind == ItemDef.WeaponKind.ARCANE:
			if TitleDef.is_holy_title_id(title_id):
				return &"spi"
			return &"int"
		if def.scaling_attribute in ATTRIBUTES:
			return def.scaling_attribute
	if TitleDef.is_holy_title_id(title_id):
		return &"spi"
	return DEFAULT_ATK_ATTRIBUTE


## Dicionário completo (sem hp/mp atuais): level, max_hp, max_mp, atk, matk, holy_matk, def, mdef,
## atributos, cast_reduction/cooldown_reduction (itens) e atk_attr (índice do atributo do ATK).
static func compute(level: int, base: Dictionary[StringName, int], equipment: Equipment,
		title_id: StringName = &"", context: Dictionary = {}) -> Dictionary:
	var bonus: Dictionary[StringName, int] = equipment_bonus(equipment, context)
	var percent: Dictionary[StringName, int] = equipment_percent_bonus(equipment)

	var attr: Dictionary[StringName, int] = {}
	for a: StringName in ATTRIBUTES:
		var fixed_value: int = base.get(a, BASE_ATTRIBUTE) + bonus.get(a, 0)
		attr[a] = maxi(0, roundi(float(fixed_value) * (1.0 + float(percent.get(a, 0)) / 100.0)))
	var out: Dictionary = {}
	out[K_LEVEL] = level
	out[K_MAX_HP] = HP_BASE + attr[&"vit"] * HP_PER_VIT + level * HP_PER_LEVEL
	out[K_MAX_MP] = MP_BASE + attr[&"int"] * MP_PER_INT + level * MP_PER_LEVEL
	var scale: StringName = atk_attribute(equipment, title_id)
	out[K_ATK] = bonus.get(K_ATK, 0) + attr[scale] * ATK_PER_STR + level
	out[K_ATK_ATTR] = ATTRIBUTES.find(scale)
	out[K_MATK] = bonus.get(K_MATK, 0) + attr[&"int"] * MATK_PER_INT + level
	out[K_HOLY_MATK] = bonus.get(K_MATK, 0) + attr[&"spi"] * MATK_PER_INT + level
	out[K_DEF] = bonus.get(K_DEF, 0) + attr[&"vit"] * DEF_PER_VIT
	out[K_MDEF] = bonus.get(K_MDEF, 0) + attr[&"spi"] * MDEF_PER_SPI
	out[K_CAST_REDUCTION] = bonus.get(K_CAST_REDUCTION, 0)
	out[K_COOLDOWN_REDUCTION] = bonus.get(K_COOLDOWN_REDUCTION, 0)
	for a: StringName in ATTRIBUTES:
		out[a] = attr[a]
	for stat: StringName in [K_MAX_HP, K_MAX_MP, K_ATK, K_MATK, K_HOLY_MATK, K_DEF, K_MDEF]:
		if percent.get(stat, 0) != 0:
			out[stat] = maxi(0, roundi(float(out[stat]) * (1.0 + float(percent[stat]) / 100.0)))
	return out
