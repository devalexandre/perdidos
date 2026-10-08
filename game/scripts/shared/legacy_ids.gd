class_name LegacyIds
extends RefCounted
## Tabela única de/para dos ids renomeados (08/10/2026: a nação "Sabiá" virou "Pindorama";
## docs/mundo/renomeacao-pindorama.md). Aplicada quando chega dado antigo:
##   - save de personagem (CharacterData.from_save; o JsonCharacterStore regrava no formato novo na hora);
##   - cache local do cliente (character_slots.cfg, appearance.cfg);
##   - aparência vinda da rede (CustomizationOptions.sanitize) e eventos do painel (active_events.json).
## Idempotente: id novo (ou qualquer id fora da tabela) passa direto.
## O passarinho sabiá (ambient_life, espécie &"sabia") NÃO é id de save e não entra aqui.

## Ids antigos -> novos. Inclui nação/região, mapas, títulos, quests de título, companheiros, montaria,
## item, monstro, grupos de spawn e o cosmético do evento do painel.
const RENAMED: Dictionary[String, String] = {
	"sabia": "pindorama",
	"fields_sabia": "fields_pindorama",
	"fields_sabia_buriti": "fields_pindorama_buriti",
	"fields_sabia_crossroads": "fields_pindorama_crossroads",
	"sabia_blade_machete": "pindorama_blade_machete",
	"sabia_blade_aroeira": "pindorama_blade_aroeira",
	"sabia_blade_jaguar": "pindorama_blade_jaguar",
	"sabia_arcane_firefly": "pindorama_arcane_firefly",
	"sabia_arcane_crystal": "pindorama_arcane_crystal",
	"sabia_arcane_boitata": "pindorama_arcane_boitata",
	"sabia_bow_cerrado": "pindorama_bow_cerrado",
	"sabia_bow_brejo": "pindorama_bow_brejo",
	"sabia_bow_gaviao": "pindorama_bow_gaviao",
	"sabia_support_root": "pindorama_support_root",
	"sabia_support_buriti": "pindorama_support_buriti",
	"sabia_support_matinta": "pindorama_support_matinta",
	"sabia_tank_jabuti": "pindorama_tank_jabuti",
	"sabia_tank_anta": "pindorama_tank_anta",
	"sabia_tank_mapinguari": "pindorama_tank_mapinguari",
	"sabia_hybrid_ember": "pindorama_hybrid_ember",
	"sabia_blade_aroeira_title": "pindorama_blade_aroeira_title",
	"sabia_blade_jaguar_title": "pindorama_blade_jaguar_title",
	"sabia_arcane_crystal_title": "pindorama_arcane_crystal_title",
	"sabia_arcane_boitata_title": "pindorama_arcane_boitata_title",
	"sabia_bow_brejo_title": "pindorama_bow_brejo_title",
	"sabia_bow_gaviao_title": "pindorama_bow_gaviao_title",
	"sabia_support_buriti_title": "pindorama_support_buriti_title",
	"sabia_support_matinta_title": "pindorama_support_matinta_title",
	"sabia_tank_anta_title": "pindorama_tank_anta_title",
	"sabia_tank_mapinguari_title": "pindorama_tank_mapinguari_title",
	"sabia_companion_guara": "pindorama_companion_guara",
	"sabia_companion_harpy": "pindorama_companion_harpy",
	"sabia_companion_lume": "pindorama_companion_lume",
	"sabia_mount_donkey": "pindorama_mount_donkey",
	"sabia_long_blade": "pindorama_long_blade",
	"sabia_jaguar": "pindorama_jaguar",
	"sabia_firefly_1": "pindorama_firefly_1",
	"sabia_firefly_2": "pindorama_firefly_2",
	"sabia_firefly_med": "pindorama_firefly_med",
	"sabia_whirlwind_1": "pindorama_whirlwind_1",
	"sabia_whirlwind_2": "pindorama_whirlwind_2",
	"sabia_whirlwind_med": "pindorama_whirlwind_med",
	"sabia_armadillo_1": "pindorama_armadillo_1",
	"sabia_armadillo_2": "pindorama_armadillo_2",
	"sabia_armadillo_med": "pindorama_armadillo_med",
	"cosmetic_broche_sabia": "cosmetic_broche_pindorama",
}
## Rede de segurança para ids fora da tabela: segmento "sabia" (separado por "_" ou ":") num id
## em minúsculas, ex. "causo_deed:title:sabia_bow_gaviao" ou "waystone:fields_sabia".
const OLD_SEGMENT: String = "sabia"
const NEW_SEGMENT: String = "pindorama"
## Chaves de save cujo VALOR é texto do jogador (nome, apelido) e nunca é traduzido.
const KEEP_VALUE_KEYS: Array[String] = ["name", "char_name", "display_name"]
## Chaves cujo dicionário tem id nas CHAVES e texto do jogador nos valores (apelidos dos companheiros).
const KEYS_ONLY_KEYS: Array[String] = ["names"]

static var _id_shape: RegEx


## Id atual para um id possivelmente antigo (String). Idempotente.
static func id(value: String) -> String:
	if value.is_empty() or not value.contains(OLD_SEGMENT):
		return value
	if RENAMED.has(value):
		return RENAMED[value]
	if _id_shape == null:
		_id_shape = RegEx.create_from_string("^[a-z0-9_:]+$")
	if _id_shape.search(value) == null:
		return value
	var parts: PackedStringArray = value.split(":")
	for i: int in parts.size():
		if RENAMED.has(parts[i]):
			parts[i] = RENAMED[parts[i]]
			continue
		var seg: PackedStringArray = parts[i].split("_")
		for j: int in seg.size():
			if seg[j] == OLD_SEGMENT:
				seg[j] = NEW_SEGMENT
		parts[i] = "_".join(seg)
	return ":".join(parts)


## Mesmo que id(), para StringName.
static func sname(value: StringName) -> StringName:
	var s: String = String(value)
	var out: String = id(s)
	return value if out == s else StringName(out)


## Cópia com todos os ids trocados (dicionários: chaves e valores; arrays; String/StringName).
## Textos do jogador (KEEP_VALUE_KEYS, valores de KEYS_ONLY_KEYS) ficam como estão.
static func migrate(v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING:
			return id(v)
		TYPE_STRING_NAME:
			return sname(v)
		TYPE_ARRAY:
			var arr: Array = (v as Array).duplicate()
			for i: int in arr.size():
				arr[i] = migrate(arr[i])
			return arr
		TYPE_DICTIONARY:
			return _migrate_dict(v, false)
	return v


static func _migrate_dict(d: Dictionary, keys_only: bool) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d:
		var nk: Variant = migrate(k) if (k is String or k is StringName) else k
		var val: Variant = d[k]
		var key_s: String = str(k)
		if keys_only or key_s in KEEP_VALUE_KEYS:
			out[nk] = val
		elif key_s in KEYS_ONLY_KEYS and val is Dictionary:
			out[nk] = _migrate_dict(val, true)
		else:
			out[nk] = migrate(val)
	return out


## true se migrate(v) mudaria algo (para regravar o save só quando precisa).
static func needs_migration(v: Variant) -> bool:
	return migrate(v) != v
