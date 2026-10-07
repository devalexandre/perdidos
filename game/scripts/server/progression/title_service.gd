class_name TitleService
extends RefCounted
## Títulos regionais (GDD §8.5): vêm de quests (QuestDef.reward_title). Cada título concede as cinco
## skills da própria árvore; títulos de ramo também concedem as árvores ancestrais.
## O jogador escolhe o título exibido; ele vai para NetEntity.title_id (visível na instância).

const MSG_TITLE_EARNED: String = "PROG_MSG_TITLE_EARNED"
const MSG_TITLE_SHOWN: String = "PROG_MSG_TITLE_SHOWN"
## Camada do título de chegada ("Viajante"): trocada automaticamente pelo primeiro título real.
const ARRIVAL_TIER: int = 0

var progression: Progression = null


func _init(p_progression: Progression) -> void:
	progression = p_progression


## Migra saves antigos: mantém títulos ganhos e concede as skills de suas árvores que ainda faltam.
func recalc(session: PlayerSession) -> Array[StringName]:
	var data: ProgressionData = session.character.progression
	for title_id: StringName in data.titles:
		_grant_tree_skills(session, title_id)
	return []


## Skills entregues por este título e por todos os títulos ancestrais.
static func skills_for_title(title_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for tree_id: StringName in SkillTree.visible_trees([title_id]):
		for skill: SkillDef in SkillTree.tree_skills(tree_id):
			if skill.id not in out:
				out.append(skill.id)
	return out


func _grant_tree_skills(session: PlayerSession, title_id: StringName) -> void:
	for skill_id: StringName in skills_for_title(title_id):
		progression.skills.learn(session, skill_id, true)
	for skill_id: StringName in bonus_skills_for_title(title_id):
		progression.skills.learn(session, skill_id, true)


## Skills de ofício (TitleDef.bonus_skills) deste título e dos ancestrais (fora da árvore de 5).
static func bonus_skills_for_title(title_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for tree_id: StringName in SkillTree.visible_trees([title_id]):
		var def: TitleDef = Content.title(tree_id)
		if def == null:
			continue
		for s: StringName in def.bonus_skills:
			if s not in out and Content.skill(s) != null:
				out.append(s)
	return out


## Concede um título (quest ou recálculo). Exibe automaticamente se o atual for o de chegada.
func grant(session: PlayerSession, title_id: StringName) -> bool:
	var data: ProgressionData = session.character.progression
	var def: TitleDef = Content.title(title_id)
	if def == null:
		return false
	if data.has_title(title_id):
		_grant_tree_skills(session, title_id)
		return false
	data.titles[title_id] = int(Time.get_unix_time_from_system())
	var shown: TitleDef = Content.title(data.displayed_title)
	if shown == null or shown.tier == ARRIVAL_TIER:
		data.displayed_title = title_id
		apply_to_entity(session)
	_grant_tree_skills(session, title_id)
	Net.push_system_message(session.peer_id, MSG_TITLE_EARNED, [def.name_key])
	if def.tier > ARRIVAL_TIER:
		progression.quests.award_fame(session, "title:%s" % title_id, CharacterData.CAUSO_POINTS_TITLE,
				QuestService.MSG_FAME_TITLE, [def.name_key])
	Net.log_line("title_earned", {"peer": session.peer_id, "title": String(title_id),
			"displayed": String(data.displayed_title)})
	return true


## Só aceita um título já conquistado (ou &"" para esconder).
func set_displayed(session: PlayerSession, title_id: StringName) -> String:
	var data: ProgressionData = session.character.progression
	if not title_id.is_empty() and not data.has_title(title_id):
		return "set_title_not_earned"
	data.displayed_title = title_id
	apply_to_entity(session)
	if not title_id.is_empty():
		Net.push_system_message(session.peer_id, MSG_TITLE_SHOWN, [Content.title(title_id).name_key])
	return ""


## Replica o título exibido (NetEntity.title_id, se a propriedade existir).
func apply_to_entity(session: PlayerSession) -> void:
	if &"title_id" in session.entity:
		session.entity.set(&"title_id", session.character.progression.displayed_title)
	if &"appearance" in session.entity:
		progression.world.refresh_appearance(session)


## Cidade inicial pelo título do Campo de Treino (GDD §9.3; N usa). &"" se nenhum.
func start_map_for(session: PlayerSession) -> StringName:
	var data: ProgressionData = session.character.progression
	var best: StringName = &""
	for id: StringName in data.titles:
		var t: TitleDef = Content.title(id)
		if t != null and not t.start_map_id.is_empty():
			best = t.start_map_id
			if id == data.displayed_title:
				return best
	return best
