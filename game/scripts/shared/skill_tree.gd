class_name SkillTree
extends RefCounted
## Árvores de skills por título (TITULOS-E-SKILLS.md §3.0 e §3.4, v0.4). Funções puras sobre o
## Content, usadas pelo servidor (requisitos das quests) e pelo cliente (janela de skills).
##
## Herança (§3.0 regra 2): quem tem um título de ramo "tem" também o título pai (e o avô...), para
## requisitos de quest e para ver a árvore do pai.


## title_id está entre os títulos (lista ou dicionário de ids) ou é ancestral de um deles?
static func holds_title(titles: Variant, title_id: StringName) -> bool:
	if title_id.is_empty():
		return true
	for held: Variant in _ids(titles):
		var t: StringName = StringName(str(held))
		var guard: int = 0
		while not t.is_empty() and guard < 16:
			if t == title_id:
				return true
			var d: TitleDef = Content.title(t)
			t = d.parent_title if d != null else &""
			guard += 1
	return false


## Títulos cujas árvores o jogador vê: os que tem + os ancestrais (herança), pela ordem do painel.
static func visible_trees(titles: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	for held: Variant in _ids(titles):
		var t: StringName = StringName(str(held))
		var guard: int = 0
		while not t.is_empty() and guard < 16:
			var d: TitleDef = Content.title(t)
			if d == null:
				break
			if t not in out and not tree_skills(t).is_empty():
				out.append(t)
			t = d.parent_title
			guard += 1
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return Content.title(a).sort_order < Content.title(b).sort_order)
	return out


## As skills da árvore de um título, na ordem da árvore (1..5).
static func tree_skills(title_id: StringName) -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for r: Resource in Content.all(&"skills").values():
		var d: SkillDef = r as SkillDef
		if d != null and d.tree_title == title_id and d.companion_id.is_empty():
			out.append(d)
	out.sort_custom(func(a: SkillDef, b: SkillDef) -> bool:
		return a.tree_order < b.tree_order if a.tree_order != b.tree_order else String(a.id) < String(b.id))
	return out


## Quest que ensina a skill (reward_skill), ou null.
static func quest_for_skill(skill_id: StringName, map_id: StringName = &"") -> QuestDef:
	var fallback: QuestDef = null
	for r: Resource in Content.all(&"quests").values():
		var q: QuestDef = r as QuestDef
		if q == null or q.reward_skill != skill_id:
			continue
		var teacher: NpcDef = Content.npc(q.giver_npc)
		if teacher != null and not map_id.is_empty() and teacher.map_id == map_id:
			return q
		# Outside training, the permanent city teacher takes precedence.
		if fallback == null or (fallback.training_title_quest and not q.training_title_quest):
			fallback = q
	return fallback


static func _ids(titles: Variant) -> Array:
	if titles is Dictionary:
		return (titles as Dictionary).keys()
	if titles is Array:
		return titles
	return []
