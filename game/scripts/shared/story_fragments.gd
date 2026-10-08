class_name StoryFragments
extends RefCounted
## Diário da história (ARCO-1-TERRA-DE-PINDORAMA.md §5): os fragmentos do Arco 1, os objetivos abertos da história
## ("Onde está Maria?") e o estilo da cena que o cliente mostra depois da vitória sobre um chefe da história
## (StoryScene). Contas puras sobre o estado da progressão (Progression.snapshot: "quests", "quests_done") e a
## mochila do cliente ([{item, qty}]), iguais em servidor, cliente e testes.
##
## Um fragmento conta como obtido quando a quest que o entrega já passou da etapa que dá o item (ou foi
## entregue), ou quando o item está na mochila.

const STYLE_LEGEND: StringName = &"legend"
const STYLE_MEMORY: StringName = &"memory"
## Quest cuja vitória vira a memória do rio (cena com escurecimento, as duas falas e o brilho rosado).
const MEMORY_QUEST: StringName = &"arc1_final_boitata"
const MEMORY_LINE_KEYS: Array[String] = ["STORY_MEMORY_LINE_1", "STORY_MEMORY_LINE_2"]
const MEMORY_INTRO_KEY: String = "STORY_MEMORY_INTRO"
const MEMORY_VISION_KEY: String = "STORY_MEMORY_VISION"
## Nome da lenda já calma (a placa da cena): STORY_LEGEND_<chefe sem "story_">.
const LEGEND_KEY_PREFIX: String = "STORY_LEGEND_"
const STORY_MONSTER_PREFIX: String = "story_"

## Ordem do diário = ordem da história.
const FRAGMENTS: Array[Dictionary] = [
	{"item": &"mother_of_pearl_comb", "quest": &"arc1_ch6_iara", "kind_key": "JOURNAL_FRAGMENT_KIND_OBJECT",
			"lore_key": "JOURNAL_FRAGMENT_COMB_LORE"},
	{"item": &"dolphin_rubbing", "quest": &"arc1_ch7_mapinguari", "kind_key": "JOURNAL_FRAGMENT_KIND_SYMBOL",
			"lore_key": "JOURNAL_FRAGMENT_DOLPHIN_LORE"},
	{"item": &"boiuna_words", "quest": &"arc1_ch9_boiuna", "kind_key": "JOURNAL_FRAGMENT_KIND_WITNESS",
			"lore_key": "JOURNAL_FRAGMENT_BOIUNA_LORE"},
	{"item": &"river_memory", "quest": &"arc1_final_boitata", "kind_key": "JOURNAL_FRAGMENT_KIND_MEMORY",
			"lore_key": "JOURNAL_FRAGMENT_MEMORY_LORE"},
]

## Objetivos abertos da história (sem quest ligada): aparecem depois de entregar a quest "after".
const GOALS: Array[Dictionary] = [
	{"id": &"arc1_where_is_maria", "after": &"arc1_final_boitata", "title_key": "JOURNAL_GOAL_WHERE_IS_MARIA",
			"desc_key": "JOURNAL_GOAL_WHERE_IS_MARIA_DESC"},
]


## Fragmentos na ordem do diário: [{item, quest, kind_key, lore_key, name_key, icon, obtained}].
static func list(progress: Dictionary, inventory: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in FRAGMENTS:
		var e: Dictionary = f.duplicate()
		var it: ItemDef = Content.item(f["item"])
		e["name_key"] = it.name_key if it != null else String(f["item"])
		e["icon"] = it.icon if it != null else null
		e["obtained"] = is_obtained(f, progress, inventory)
		out.append(e)
	return out


static func obtained_count(progress: Dictionary, inventory: Array = []) -> int:
	var n: int = 0
	for f: Dictionary in FRAGMENTS:
		if is_obtained(f, progress, inventory):
			n += 1
	return n


static func is_obtained(fragment: Dictionary, progress: Dictionary, inventory: Array = []) -> bool:
	var item: StringName = fragment["item"]
	for s: Variant in inventory:
		if s is Dictionary and StringName(str((s as Dictionary).get("item", ""))) == item \
				and int((s as Dictionary).get("qty", 0)) > 0:
			return true
	var quest_id: StringName = fragment["quest"]
	if _done(progress, quest_id):
		return true
	var q: QuestDef = Content.quest(quest_id)
	var grant_i: int = grant_step_index(q, item)
	if grant_i < 0:
		return false
	for e: Variant in progress.get("quests", []):
		if e is Dictionary and StringName(str((e as Dictionary).get("id", ""))) == quest_id:
			return bool(e.get("ready", false)) or int(e.get("step", 0)) > grant_i
	return false


## Índice da etapa que entrega o item (grant_items) ou -1 (só na entrega, reward_items).
static func grant_step_index(q: QuestDef, item: StringName) -> int:
	if q == null:
		return -1
	for i: int in q.steps.size():
		if q.steps[i].grant_items.has(item):
			return i
	return -1


## Objetivos abertos já liberados: [{id, title_key, desc_key}].
static func open_goals(progress: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in GOALS:
		if _done(progress, g["after"]):
			out.append(g.duplicate())
	return out


static func _done(progress: Dictionary, quest_id: StringName) -> bool:
	for id: Variant in progress.get("quests_done", []):
		if StringName(str(id)) == quest_id:
			return true
	return false


## Estilo da cena da vitória de história (StoryScene).
static func scene_style(quest_id: StringName) -> StringName:
	return STYLE_MEMORY if quest_id == MEMORY_QUEST else STYLE_LEGEND


## Chave do nome da lenda já calma (ex.: story_curupira -> STORY_LEGEND_CURUPIRA).
static func legend_name_key(monster_id: StringName) -> String:
	return LEGEND_KEY_PREFIX + String(monster_id).trim_prefix(STORY_MONSTER_PREFIX).to_upper()


## Cena da vitória de história para um jogador (o servidor manda; o cliente mostra). pages = chaves das falas.
static func make_scene(quest_id: StringName, monster_id: StringName, text_key: String, page_keys: Array,
		items: Array) -> Dictionary:
	var pages: Array = []
	for k: Variant in page_keys:
		pages.append(String(k))
	var granted: Array = []
	for it: Variant in items:
		granted.append(String(it))
	return {"quest": String(quest_id), "monster": String(monster_id), "text_key": text_key, "pages": pages,
			"items": granted, "style": String(scene_style(quest_id))}
