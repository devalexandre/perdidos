class_name ProgressionData
extends RefCounted
## Estado persistente da progressão de um personagem (GDD §6.3, §7, §8, §9): XP, pontos, skills
## conhecidas e seus níveis, barra 1–0, títulos e quests. Vai dentro do save do CharacterData
## (chave "progression"). O nível do personagem continua em CharacterData.level.

## Título de chegada: todo personagem começa com ele (TITULOS-E-SKILLS.md §1.3, camada 0).
const STARTING_TITLE: StringName = &"traveler"
const K_XP: String = "xp"
const K_TOTAL_XP: String = "total_xp"
const K_ATTRIBUTE_POINTS: String = "attribute_points"
const K_SKILL_POINTS: String = "skill_points"
const K_SKILLS: String = "skills"
const K_HOTBAR: String = "hotbar"
const K_TITLES: String = "titles"
const K_DISPLAYED_TITLE: String = "displayed_title"
const K_QUESTS: String = "quests"
const K_QUESTS_DONE: String = "quests_done"
## Estado de uma quest ativa: etapa atual e contagem nela.
const Q_STEP: String = "step"
const Q_COUNT: String = "count"
const Q_NEEDS: String = "needs"
## Etapas KILL com distinct_species: espécies já contadas nesta etapa.
const Q_SEEN: String = "seen"

## XP dentro do nível atual (0 .. xp_to_next - 1).
var xp: int = 0
## XP total já recebida (evolução dos monstros, GDD §10.6).
var total_xp: int = 0
var attribute_points: int = 0
var skill_points: int = 0
## skill_id -> nível (1..max).
var skills: Dictionary[StringName, int] = {}
## Barra 1–0: skill_id ou item_id (consumível) por espaço; &"" = vazio.
var hotbar: Array[StringName] = []
## title_id -> data (Unix, s) da conquista.
var titles: Dictionary[StringName, int] = {}
var displayed_title: StringName = &""
## quest_id -> {"step": int, "count": int}
var quests: Dictionary[StringName, Dictionary] = {}
## quest_id -> data (Unix, s) da conclusão.
var quests_done: Dictionary[StringName, int] = {}


func _init() -> void:
	hotbar.resize(Balance.cfg.hotbar_slots)
	hotbar.fill(&"")
	titles[STARTING_TITLE] = int(Time.get_unix_time_from_system())
	displayed_title = STARTING_TITLE


func skill_level(skill_id: StringName) -> int:
	return skills.get(skill_id, 0)


func knows(skill_id: StringName) -> bool:
	return skills.has(skill_id)


func has_title(title_id: StringName) -> bool:
	return titles.has(title_id)


func hotbar_index_of(entry_id: StringName) -> int:
	return hotbar.find(entry_id) if not entry_id.is_empty() else -1


func to_save() -> Dictionary:
	var sk: Dictionary = {}
	for k: StringName in skills:
		sk[String(k)] = skills[k]
	var bar: Array = []
	for s: StringName in hotbar:
		bar.append(String(s))
	var ti: Dictionary = {}
	for k: StringName in titles:
		ti[String(k)] = titles[k]
	var qa: Dictionary = {}
	for k: StringName in quests:
		qa[String(k)] = quests[k].duplicate(true)
	var qd: Dictionary = {}
	for k: StringName in quests_done:
		qd[String(k)] = quests_done[k]
	return {
		K_XP: xp, K_TOTAL_XP: total_xp, K_ATTRIBUTE_POINTS: attribute_points,
		K_SKILL_POINTS: skill_points, K_SKILLS: sk, K_HOTBAR: bar, K_TITLES: ti,
		K_DISPLAYED_TITLE: String(displayed_title), K_QUESTS: qa, K_QUESTS_DONE: qd,
	}


## Lê o save (tolerante: campos ausentes ou de tipo errado ficam no padrão).
func load_save(d: Variant) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return
	var src: Dictionary = d
	xp = maxi(int(src.get(K_XP, 0)), 0)
	total_xp = maxi(int(src.get(K_TOTAL_XP, 0)), 0)
	attribute_points = maxi(int(src.get(K_ATTRIBUTE_POINTS, 0)), 0)
	skill_points = maxi(int(src.get(K_SKILL_POINTS, 0)), 0)
	var sk: Variant = src.get(K_SKILLS, {})
	if typeof(sk) == TYPE_DICTIONARY:
		for k: Variant in sk:
			skills[StringName(str(k))] = clampi(int(sk[k]), 1, Balance.cfg.max_skill_level)
	var bar: Variant = src.get(K_HOTBAR, [])
	if typeof(bar) == TYPE_ARRAY:
		for i: int in mini((bar as Array).size(), hotbar.size()):
			hotbar[i] = StringName(str(bar[i]))
	var ti: Variant = src.get(K_TITLES, {})
	if typeof(ti) == TYPE_DICTIONARY:
		for k: Variant in ti:
			titles[StringName(str(k))] = int(ti[k])
	var shown := StringName(str(src.get(K_DISPLAYED_TITLE, "")))
	if titles.has(shown):
		displayed_title = shown
	var qa: Variant = src.get(K_QUESTS, {})
	if typeof(qa) == TYPE_DICTIONARY:
		for k: Variant in qa:
			var st: Variant = qa[k]
			if typeof(st) == TYPE_DICTIONARY:
				var entry: Dictionary = {Q_STEP: int(st.get(Q_STEP, 0)), Q_COUNT: int(st.get(Q_COUNT, 0))}
				if typeof(st.get(Q_NEEDS)) == TYPE_ARRAY:
					entry[Q_NEEDS] = (st[Q_NEEDS] as Array).map(func(v: Variant) -> int: return int(v))
				if typeof(st.get(Q_SEEN)) == TYPE_ARRAY:
					entry[Q_SEEN] = (st[Q_SEEN] as Array).map(func(v: Variant) -> String: return str(v))
				quests[StringName(str(k))] = entry
	var qd: Variant = src.get(K_QUESTS_DONE, {})
	if typeof(qd) == TYPE_DICTIONARY:
		for k: Variant in qd:
			quests_done[StringName(str(k))] = int(qd[k])
