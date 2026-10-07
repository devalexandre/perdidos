class_name SkillProgression
extends RefCounted
## Regras de pontos e skills (GDD §6.2, §7, §8.1): distribuir pontos de atributo, aprender skill
## (só por quest), subir skill com pontos de skill e montar a barra 1–0 (só fora de combate).
## Não sabe nada de rede: devolve "" (ok) ou o motivo da recusa (Net.log_invalid) e a chave de
## mensagem para o jogador.

const OK_RESULT: String = ""
## Mensagens para o jogador (localization/progression.csv).
const MSG_NO_ATTRIBUTE_POINTS: String = "PROG_MSG_NO_ATTRIBUTE_POINTS"
const MSG_NO_SKILL_POINTS: String = "PROG_MSG_NO_SKILL_POINTS"
const MSG_SKILL_MAX_LEVEL: String = "PROG_MSG_SKILL_MAX_LEVEL"
const MSG_HOTBAR_IN_COMBAT: String = "PROG_MSG_HOTBAR_IN_COMBAT"
const MSG_SKILL_LEARNED: String = "PROG_MSG_SKILL_LEARNED"
const MSG_SKILL_LEVEL_UP: String = "PROG_MSG_SKILL_LEVEL_UP"
const MSG_PREREQ_MISSING: String = "PROG_REQ_SKILL_LEVEL"

var progression: Progression = null


func _init(p_progression: Progression) -> void:
	progression = p_progression


static func max_level_of(def: SkillDef) -> int:
	return mini(def.max_level, Balance.cfg.max_skill_level) if def != null else 0


## points: {&"str": n, ...}. Todos >= 0, soma entre 1 e os pontos disponíveis.
func allocate_stats(session: PlayerSession, points: Dictionary) -> String:
	var data: ProgressionData = session.character.progression
	var total: int = 0
	for k: Variant in points:
		var attr := StringName(str(k))
		if attr not in CharacterStats.ATTRIBUTES:
			return "allocate_stats_unknown_attribute"
		var n: int = int(points[k])
		if n < 0:
			return "allocate_stats_negative"
		total += n
	if total <= 0:
		return "allocate_stats_empty"
	if total > data.attribute_points:
		Net.push_system_message(session.peer_id, MSG_NO_ATTRIBUTE_POINTS)
		return "allocate_stats_not_enough_points"
	for k: Variant in points:
		var attr := StringName(str(k))
		session.character.base_attributes[attr] += int(points[k])
	data.attribute_points -= total
	return OK_RESULT


## Aprende (nível 1) e põe no primeiro espaço vazio da barra. Só as quests chamam (e o debug, com
## force = true). Confere os pré-requisitos da árvore (SkillDef.required_skill_levels).
func learn(session: PlayerSession, skill_id: StringName, force: bool = false) -> bool:
	var def: SkillDef = Content.skill(skill_id)
	var data: ProgressionData = session.character.progression
	if def == null or data.knows(skill_id):
		return false
	var missing: Array = def.missing_prerequisites(data.skills)
	if not force and not missing.is_empty():
		Net.log_line("skill_learn_prerequisites_missing", {"peer": session.peer_id,
				"skill": String(skill_id), "missing": str(missing)})
		return false
	data.skills[skill_id] = 1
	var free: int = data.hotbar.find(&"")
	if free >= 0:
		data.hotbar[free] = skill_id
	Net.push_system_message(session.peer_id, MSG_SKILL_LEARNED, [def.name_key])
	Net.log_line("skill_learned", {"peer": session.peer_id, "skill": String(skill_id),
			"hotbar_slot": free})
	return true


func level_up(session: PlayerSession, skill_id: StringName) -> String:
	var def: SkillDef = Content.skill(skill_id)
	var data: ProgressionData = session.character.progression
	if def == null or not data.knows(skill_id):
		return "skill_level_up_unknown_skill"
	if data.skill_points <= 0:
		Net.push_system_message(session.peer_id, MSG_NO_SKILL_POINTS)
		return "skill_level_up_no_points"
	if data.skill_level(skill_id) >= max_level_of(def):
		Net.push_system_message(session.peer_id, MSG_SKILL_MAX_LEVEL)
		return "skill_level_up_max"
	# Árvore (TITULOS-E-SKILLS.md §3.0): só sobe quem ainda cumpre os pré-requisitos.
	for m: Array in def.missing_prerequisites(data.skills):
		var req: SkillDef = Content.skill(m[0])
		Net.push_system_message(session.peer_id, MSG_PREREQ_MISSING,
				[req.name_key if req != null else String(m[0]), m[1]])
		return "skill_level_up_prerequisites_missing"
	data.skills[skill_id] += 1
	data.skill_points -= 1
	Net.push_system_message(session.peer_id, MSG_SKILL_LEVEL_UP,
			[def.name_key, data.skills[skill_id]])
	return OK_RESULT


## entry_id: skill conhecida, consumível que o jogador tem, ou &"" (limpar). Só fora de combate.
## Se o mesmo item já está em outro espaço, ele sai de lá (troca de lugar).
func hotbar_set(session: PlayerSession, slot: int, entry_id: StringName) -> String:
	var data: ProgressionData = session.character.progression
	if slot < 0 or slot >= data.hotbar.size():
		return "hotbar_slot_out_of_range"
	if progression.bridge.is_in_combat(session.peer_id):
		Net.push_system_message(session.peer_id, MSG_HOTBAR_IN_COMBAT)
		return "hotbar_in_combat"
	if not entry_id.is_empty() and not is_hotbar_entry_valid(session, entry_id):
		return "hotbar_unknown_entry"
	var old: int = data.hotbar_index_of(entry_id)
	if old >= 0 and old != slot:
		data.hotbar[old] = data.hotbar[slot]
	data.hotbar[slot] = entry_id
	return OK_RESULT


func is_hotbar_entry_valid(session: PlayerSession, entry_id: StringName) -> bool:
	if Content.skill(entry_id) != null:
		return session.character.progression.knows(entry_id) and not Content.skill(entry_id).passive
	var item: ItemDef = Content.item(entry_id)
	return item != null and item.is_hotbar_item()
