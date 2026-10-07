class_name QuestService
extends RefCounted
## Quests de aprendizado (GDD §9): aceitar, progredir (derrotar, coletar, explorar, conversar,
## provação), entregar e recompensar (XP, itens, skill, título). Nenhuma quest exige nível
## (GDD §8.4): só conhecimento (skills, níveis de skill, títulos, quests anteriores). No Campo de
## Treino só UMA quest de título pode ser concluída (QuestDef.training_title_quest, GDD §9.3).
##
## Diálogo: as opções de quest entram sozinhas no primeiro nó do diálogo do Mestre (extend_dialogue);
## o DialogueRunner delega a este serviço as condições e ações que não conhece.

## Ações de diálogo (DialogueOption.action) tratadas aqui. action_args {"quest_id": id}.
const ACTION_ACCEPT: StringName = &"accept_quest"
const ACTION_TURN_IN: StringName = &"turn_in_quest"
const ACTION_START_TRIAL: StringName = &"start_trial"
const ACTION_OFFER: StringName = &"quest_offer"
const ACTION_SHOW_PROGRESS: StringName = &"quest_show_progress"
const ACTION_SHOW_COMPLETE: StringName = &"quest_show_complete"
const ACTION_MISSING: StringName = &"quest_missing"
## Sub-história: ouvir o causo do NPC (QuestStep.lore_text_key) conclui a etapa TALK.
const ACTION_HEAR_LORE: StringName = &"quest_hear_lore"
const ACTIONS: Array[StringName] = [ACTION_ACCEPT, ACTION_TURN_IN, ACTION_START_TRIAL, ACTION_OFFER,
		ACTION_SHOW_PROGRESS, ACTION_SHOW_COMPLETE, ACTION_MISSING, ACTION_HEAR_LORE]
const ARG_QUEST_ID: StringName = &"quest_id"
## Condições de diálogo (DialogueOption.conditions) tratadas aqui; valor = id.
const COND_QUEST_AVAILABLE: StringName = &"quest_available"
const COND_QUEST_ACTIVE: StringName = &"quest_active"
const COND_QUEST_READY: StringName = &"quest_ready"
const COND_QUEST_DONE: StringName = &"quest_done"
const COND_HAS_TITLE: StringName = &"has_title"
const COND_KNOWS_SKILL: StringName = &"knows_skill"
## Anciãos (TITULOS-E-SKILLS.md §3.2): falta requisito (e nem ativa nem feita) / já aceita ou feita.
const COND_QUEST_LOCKED: StringName = &"quest_locked"
const COND_QUEST_TAKEN: StringName = &"quest_taken"
const CONDITIONS: Array[StringName] = [COND_QUEST_AVAILABLE, COND_QUEST_ACTIVE, COND_QUEST_READY,
		COND_QUEST_DONE, COND_HAS_TITLE, COND_KNOWS_SKILL, COND_QUEST_LOCKED, COND_QUEST_TAKEN]
## Textos das opções geradas (localization/progression.csv).
const OPT_ACCEPT: String = "QUEST_OPT_ACCEPT"
const OPT_DECLINE: String = "QUEST_OPT_DECLINE"
const OPT_REPORT: String = "QUEST_OPT_REPORT"
const OPT_TURN_IN: String = "QUEST_OPT_TURN_IN"
const OPT_BYE: String = "QUEST_OPT_BYE"
const OPT_START_TRIAL: String = "QUEST_OPT_START_TRIAL"
const OPT_ASK_PROGRESS: String = "QUEST_OPT_ASK_PROGRESS"
const OPT_HEAR_LORE: String = "QUEST_OPT_HEAR_LORE"
const OPT_LORE_DONE: String = "QUEST_OPT_LORE_DONE"
## Nós gerados (não existem no DialogueDef).
const NODE_PREFIX: String = "_quest_"
## Mensagens.
const MSG_ACCEPTED: String = "PROG_MSG_QUEST_ACCEPTED"
const MSG_PROGRESS: String = "PROG_MSG_QUEST_PROGRESS"
const MSG_STEP_DONE: String = "PROG_MSG_QUEST_STEP_DONE"
const MSG_READY: String = "PROG_MSG_QUEST_READY"
const MSG_COMPLETED: String = "PROG_MSG_QUEST_COMPLETED"
const MSG_CAUSO_EARNED: String = "PROG_MSG_CAUSO_EARNED"
const MSG_CAUSO_RANK_UP: String = "PROG_MSG_CAUSO_RANK_UP"
const MSG_ABANDONED: String = "PROG_MSG_QUEST_ABANDONED"
const MSG_MISSING: String = "PROG_MSG_QUEST_MISSING"
const MSG_TRAINING_CLOSED: String = "PROG_MSG_TRAINING_TITLE_CLOSED"
const MSG_TRIAL_STARTED: String = "PROG_MSG_TRIAL_STARTED"
const MSG_TRIAL_FAILED: String = "PROG_MSG_TRIAL_FAILED"
const MSG_TRIAL_TIME: String = "PROG_MSG_TRIAL_TIME"
const REQ_SKILL: String = "PROG_REQ_SKILL"
const REQ_SKILL_LEVEL: String = "PROG_REQ_SKILL_LEVEL"
const REQ_TITLE: String = "PROG_REQ_TITLE"
const REQ_QUEST: String = "PROG_REQ_QUEST"
const REQ_STORY_CLUES: String = "PROG_REQ_STORY_CLUES"
const REQ_STORY_ROUTE: String = "PROG_REQ_STORY_ROUTE"
const REQ_STORY_OBSERVATIONS: String = "PROG_REQ_STORY_OBSERVATIONS"
const REQ_TRAINING_TITLE: String = "PROG_REQ_TRAINING_TITLE_DONE"
const REQ_SKILL_KNOWN: String = "PROG_REQ_SKILL_KNOWN"
const REQ_CAUSOS: String = "PROG_REQ_CAUSOS"
const REQ_LEAVE_TRAINING: String = "PROG_REQ_LEAVE_TRAINING"
## Renome (Causos) ganho por feitos: [pontos, motivo...].
const MSG_FAME_TITLE: String = "PROG_MSG_FAME_TITLE"
const MSG_FAME_BOSS: String = "PROG_MSG_FAME_BOSS"
const MSG_FAME_ATROZ: String = "PROG_MSG_FAME_ATROZ"
const MSG_FAME_RANK_UP: String = "PROG_MSG_FAME_RANK_UP"
## Quest de título é feita sozinho (sai do grupo ao aceitar; só conta o que o próprio personagem faz).
const MSG_SOLO_LEFT_PARTY: String = "PROG_MSG_TITLE_SOLO_LEFT_PARTY"
const MSG_SOLO_LOOT_ONLY: String = "PROG_MSG_TITLE_SOLO_LOOT_ONLY"
## Dificuldade por título já conquistado: abates/coletas da lição crescem 50% por título e as etapas de
## veterano (QuestStep.min_prior_titles) entram (relíquias, chefe do covil, forma atroz).
const TITLE_STEP_GROWTH: float = 0.5
## Etapa pulada nesta aceitação (Q_NEEDS[i] == SKIPPED_STEP).
const SKIPPED_STEP: int = 0

## Variantes do filtro de KILL (QuestStep.variant) e o que vem no `info` de on_monster_killed.
const VARIANT_ANY: StringName = &"any"
const VARIANT_RARE: StringName = &"rare"
const VARIANT_BOSS: StringName = &"boss"
const VARIANT_ATROZ: StringName = &"atroz"
const INFO_RARE: String = "rare"
const INFO_STAGE: String = "stage"
const INFO_ATROZ: String = "atroz"
const INFO_NO_DEATH: String = "no_death"
## Quem recebe o crédito é o dono do abate (false = crédito de grupo; não vale para quest de título).
const INFO_OWNER: String = "owner"
## Nível do monstro abatido (renome: chefe/atroz acima do nível do personagem).
const INFO_LEVEL: String = "level"
## target_id que aceita qualquer espécie.
const ANY_SPECIES: StringName = &"*"
## Provação de sobreviver (QuestStep.trial_mode).
const TRIAL_KILL: StringName = &"kill"
const TRIAL_SURVIVE: StringName = &"survive"
## Proteger (Vó Aninha): mudas nascem em volta do jogador, a esta distância (células).
const TRIAL_PROTECT: StringName = &"protect"
const PROTECT_RING_CELLS: float = 2.0
## Primeira onda sai um pouco depois das mudas (dá tempo de se posicionar).
const PROTECT_FIRST_WAVE_SEC: float = 3.0
const MSG_TRIAL_PROTECTED: String = "PROG_MSG_TRIAL_PROTECTED"
const MSG_TRIAL_PROTECT_LOST: String = "PROG_MSG_TRIAL_PROTECT_LOST"
const MSG_TRIAL_PROTECT_FELL: String = "PROG_MSG_TRIAL_PROTECT_FELL"
## Monstros da provação de sobreviver nascem neste anel (células) em volta do jogador.
const TRIAL_RING_CELLS: float = 4.0
const MSG_TRIAL_SURVIVED: String = "PROG_MSG_TRIAL_SURVIVED"
## Explorar: checagem de posição a cada tantos ms (não precisa ser todo tick).
const EXPLORE_CHECK_MSEC: int = 500
## Provação: o boneco nasce a esta distância (m) do jogador, no lado do Mestre.
const TRIAL_SPAWN_DISTANCE: float = 2.0
const MSEC_PER_SEC: float = 1000.0

var progression: Progression = null
var world: ServerWorld = null
## peer_id -> {"quest": id, "target": monster_id, "entity": entity_id, "deadline": msec (0 = sem)}
var _trials: Dictionary[int, Dictionary] = {}
## Transferência e retorno das provas privadas, sem alterar os mapas compartilhados.
var _arena_visits: Dictionary[int, Dictionary] = {}
var _next_explore_msec: int = 0
## map_id -> {marker_name -> posição} (cache dos pontos de explorar).
var _marker_cache: Dictionary[StringName, Dictionary] = {}
var _waits: Dictionary[String, Dictionary] = {}


func _init(p_progression: Progression) -> void:
	progression = p_progression
	world = p_progression.world


# ---------------------------------------------------------------- consultas

static func turn_in_npc_of(q: QuestDef) -> StringName:
	return q.turn_in_npc if not q.turn_in_npc.is_empty() else q.giver_npc


func is_active(session: PlayerSession, quest_id: StringName) -> bool:
	return session.character.progression.quests.has(quest_id)


func is_done(session: PlayerSession, quest_id: StringName) -> bool:
	return session.character.progression.quests_done.has(quest_id)


func is_ready(session: PlayerSession, quest_id: StringName) -> bool:
	var q: QuestDef = Content.quest(quest_id)
	var st: Dictionary = session.character.progression.quests.get(quest_id, {})
	if q == null or st.is_empty():
		return false
	_normalize(st, q)
	return int(st[ProgressionData.Q_STEP]) >= q.steps.size()


func current_step(session: PlayerSession, q: QuestDef) -> QuestStep:
	var st: Dictionary = session.character.progression.quests.get(q.id, {})
	if st.is_empty():
		return null
	_normalize(st, q)
	var i: int = int(st[ProgressionData.Q_STEP])
	return q.steps[i] if i >= 0 and i < q.steps.size() else null


func required_count(session: PlayerSession, q: QuestDef, step_index: int = -1) -> int:
	if q == null:
		return 0
	var st: Dictionary = session.character.progression.quests.get(q.id, {})
	if not st.is_empty():
		_normalize(st, q)
	var index := step_index if step_index >= 0 else int(st.get(ProgressionData.Q_STEP, 0))
	if index < 0 or index >= q.steps.size():
		return 0
	var needs: Variant = st.get(ProgressionData.Q_NEEDS, [])
	if needs is Array and index < (needs as Array).size():
		return maxi(1, int(needs[index]))
	return q.steps[index].count


## Quantidade pedida por uma etapa de quest de título, dado quantos títulos o personagem já tem.
## Abates comuns e coletas crescem TITLE_STEP_GROWTH por título (1 título: ×1,5; 2: ×2; 3: ×2,5).
static func scaled_title_step_count(step: QuestStep, earned_titles: int) -> int:
	if step == null:
		return 0
	var prior: int = maxi(0, earned_titles)
	if not step.scale_with_titles or prior == 0:
		return step.count
	if (step.type == QuestStep.StepType.KILL and step.variant == VARIANT_ANY) \
			or step.type == QuestStep.StepType.COLLECT:
		return ceili(float(step.count) * (1.0 + TITLE_STEP_GROWTH * float(prior)))
	return step.count


## A etapa entra nesta aceitação? Etapas de veterano só em quest de título, com títulos suficientes.
static func step_active(q: QuestDef, step: QuestStep, earned_titles: int) -> bool:
	if step.min_prior_titles <= 0:
		return true
	return not q.reward_title.is_empty() and earned_titles >= step.min_prior_titles


## Q_NEEDS de uma aceitação: quantidade por etapa (SKIPPED_STEP = etapa fora desta vez).
static func needs_for(q: QuestDef, earned_titles: int) -> Array[int]:
	var needs: Array[int] = []
	for step: QuestStep in q.steps:
		if not step_active(q, step, earned_titles):
			needs.append(SKIPPED_STEP)
		elif q.reward_title.is_empty():
			needs.append(step.count)
		else:
			needs.append(maxi(1, scaled_title_step_count(step, earned_titles)))
	return needs


## Saves de antes das etapas de veterano e de causo falado: Q_NEEDS menor que a lista de etapas e Q_STEP
## contado só nas etapas de base. Converte para o formato atual (índice real; as etapas novas ficam fora
## desta aceitação), sem mudar o progresso.
static func _normalize(st: Dictionary, q: QuestDef) -> void:
	var raw: Variant = st.get(ProgressionData.Q_NEEDS, [])
	var old: Array = raw if raw is Array else []
	if old.size() == q.steps.size():
		return
	var needs: Array[int] = []
	var base: Array[int] = []
	for i: int in q.steps.size():
		if q.steps[i].min_prior_titles > 0 or not q.steps[i].lore_text_key.is_empty():
			needs.append(SKIPPED_STEP)
			continue
		var pos: int = base.size()
		base.append(i)
		needs.append(maxi(1, int(old[pos])) if pos < old.size() else q.steps[i].count)
	var step_pos: int = int(st.get(ProgressionData.Q_STEP, 0))
	st[ProgressionData.Q_STEP] = base[step_pos] if step_pos >= 0 and step_pos < base.size() else q.steps.size()
	st[ProgressionData.Q_NEEDS] = needs


## Etapas que contam nesta aceitação (para o diário: "etapa X de Y").
static func active_step_count(st: Dictionary, q: QuestDef) -> int:
	var needs: Variant = st.get(ProgressionData.Q_NEEDS, [])
	if not needs is Array or (needs as Array).size() != q.steps.size():
		return q.steps.size()
	var n: int = 0
	for v: Variant in needs:
		if int(v) != SKIPPED_STEP:
			n += 1
	return n


static func _active_position(st: Dictionary, q: QuestDef, index: int) -> int:
	var needs: Variant = st.get(ProgressionData.Q_NEEDS, [])
	if not needs is Array or (needs as Array).size() != q.steps.size():
		return index
	var pos: int = 0
	for i: int in mini(index, q.steps.size()):
		if int(needs[i]) != SKIPPED_STEP:
			pos += 1
	return pos


## Quest de título: feita sozinho, só conta o que o próprio personagem faz.
static func is_solo_quest(q: QuestDef) -> bool:
	return q != null and (not q.reward_title.is_empty() or not q.reward_companion.is_empty())


## Nome (chave) da quest de título em andamento (ainda não pronta para entregar); "" = nenhuma.
## O grupo (PartyService) recusa convites enquanto houver uma.
func active_solo_quest(session: PlayerSession) -> String:
	for id: StringName in session.character.progression.quests:
		var q: QuestDef = Content.quest(id)
		if is_solo_quest(q) and not is_ready(session, id):
			return q.name_key
	return ""


static func earned_title_count(data: ProgressionData) -> int:
	var count := 0
	for title_id: StringName in data.titles:
		var def: TitleDef = Content.title(title_id)
		if def != null and def.tier > TitleService.ARRIVAL_TIER:
			count += 1
	return count


## Já concluiu alguma quest de título do Campo de Treino?
func training_title_done(session: PlayerSession) -> bool:
	for id: StringName in session.character.progression.quests_done:
		var q: QuestDef = Content.quest(id)
		if q != null and q.training_title_quest:
			return true
	return false


## O que falta para aceitar (lista de [chave, args]); vazio = pode. Nunca olha o nível.
func missing_requirements(session: PlayerSession, q: QuestDef) -> Array:
	var data: ProgressionData = session.character.progression
	var out: Array = []
	if q.requires_left_training and not session.character.left_training:
		out.append([REQ_LEAVE_TRAINING, []])
	if q.training_title_quest and training_title_done(session):
		out.append([REQ_TRAINING_TITLE, []])
	# No Campo de Treino só se conquista UM título; o próximo, de qualquer Mestre, só depois de sair do treino.
	elif is_solo_quest(q) and not session.character.left_training and earned_title_count(data) >= 1:
		out.append([REQ_LEAVE_TRAINING, []])
	# Renome (Causos): sub-histórias de título só para quem já tem fama pelos seus feitos.
	if q.required_causos > 0 and session.character.causos < q.required_causos:
		out.append([REQ_CAUSOS, [q.required_causos, session.character.causos]])
	var title_reward: TitleDef = Content.title(q.reward_title)
	for s: StringName in q.required_skills:
		if not data.knows(s):
			out.append([REQ_SKILL, [_skill_name(s)]])
	var reward: SkillDef = Content.skill(q.reward_skill)
	# Pré-requisitos da árvore da skill ensinada entram junto (TITULOS-E-SKILLS.md §3.0 regra 1).
	var levels: Dictionary = {}
	for s: StringName in q.required_skill_levels:
		levels[s] = q.required_skill_levels[s]
	if reward != null:
		for s: StringName in reward.required_skill_levels:
			levels[s] = maxi(int(levels.get(s, 0)), reward.required_skill_levels[s])
	for s: StringName in levels:
		if data.skill_level(s) < int(levels[s]):
			out.append([REQ_SKILL_LEVEL, [_skill_name(s), int(levels[s])]])
	var titles: Array[StringName] = q.required_titles.duplicate()
	if title_reward != null:
		for t: StringName in title_reward.required_titles:
			if t not in titles:
				titles.append(t)
	if reward != null and not reward.exclusive_to_title.is_empty() \
			and reward.exclusive_to_title not in titles and reward.exclusive_to_title != q.reward_title:
		titles.append(reward.exclusive_to_title)
	if reward != null and not reward.tree_title.is_empty() and reward.tree_title != q.reward_title \
			and reward.tree_title not in titles:
		titles.append(reward.tree_title)
	for t: StringName in titles:
		# Herança (§3.0 regra 2): o título de ramo vale pelo pai.
		if not SkillTree.holds_title(data.titles, t):
			var td: TitleDef = Content.title(t)
			out.append([REQ_TITLE, [td.name_key if td != null else String(t)]])
	if reward != null and data.knows(reward.id) \
			and (q.reward_title.is_empty() or data.has_title(q.reward_title)) \
			and not is_active(session, q.id):
		out.append([REQ_SKILL_KNOWN, [reward.name_key]])
	for r: StringName in q.required_quests:
		if not data.quests_done.has(r):
			var rq: QuestDef = Content.quest(r)
			out.append([REQ_QUEST, [rq.name_key if rq != null else String(r)]])
	if not q.required_story_id.is_empty() and q.required_story_clues > 0:
		var clue_count: int = session.character.story_clue_count(q.required_story_id)
		if clue_count < q.required_story_clues:
			out.append([REQ_STORY_CLUES, [q.required_story_clues, clue_count]])
	if not q.required_story_id.is_empty() and not q.required_story_route.is_empty():
		if session.character.story_route(q.required_story_id) != q.required_story_route:
			out.append([REQ_STORY_ROUTE, []])
	if not q.required_story_id.is_empty() and q.required_story_observations > 0:
		var observation_count: int = session.character.story_observation_count(q.required_story_id)
		if observation_count < q.required_story_observations:
			out.append([REQ_STORY_OBSERVATIONS, [q.required_story_observations, observation_count]])
	return out


func is_available(session: PlayerSession, q: QuestDef) -> bool:
	return not is_active(session, q.id) and not is_done(session, q.id) \
		and (q.reward_title.is_empty() or not session.character.progression.has_title(q.reward_title)) \
			and missing_requirements(session, q).is_empty()


static func _skill_name(skill_id: StringName) -> String:
	var d: SkillDef = Content.skill(skill_id)
	return d.name_key if d != null else String(skill_id)


## Diário: [{id, step, count, need, type, target, ready}].
func snapshot(session: PlayerSession) -> Array:
	var out: Array = []
	var data: ProgressionData = session.character.progression
	for id: StringName in data.quests:
		var q: QuestDef = Content.quest(id)
		if q == null:
			continue
		var st: Dictionary = data.quests[id]
		_normalize(st, q)
		var step_i: int = int(st[ProgressionData.Q_STEP])
		# "step" = índice em QuestDef.steps (o cliente lê o texto dela); "pos"/"steps" = etapa X de Y
		# contando só as etapas desta aceitação (as de veterano podem estar fora).
		var entry: Dictionary = {"id": String(id), "step": step_i, "steps": active_step_count(st, q),
				"pos": _active_position(st, q, step_i), "count": int(st[ProgressionData.Q_COUNT]),
				"ready": step_i >= q.steps.size(), "solo": is_solo_quest(q)}
		if step_i < q.steps.size():
			var s: QuestStep = q.steps[step_i]
			entry["need"] = required_count(session, q, step_i)
			if s.type == QuestStep.StepType.COLLECT and is_solo_quest(q):
				entry["count"] = mini(int(st[ProgressionData.Q_COUNT]),
						session.character.inventory.count(s.target_id))
			entry["type"] = String(QuestStep.StepType.keys()[s.type]).to_lower()
			entry["target"] = String(s.target_id)
			if s.variant != VARIANT_ANY:
				entry["variant"] = String(s.variant)
			if _trials.has(session.peer_id) and _trials[session.peer_id]["quest"] == id:
				var deadline: int = int(_trials[session.peer_id]["deadline"])
				entry["trial_ms"] = maxi(0, deadline - Time.get_ticks_msec()) if deadline > 0 else -1
		out.append(entry)
	return out


# ---------------------------------------------------------------- aceitar / abandonar / entregar

func accept(session: PlayerSession, quest_id: StringName) -> bool:
	var q: QuestDef = Content.quest(quest_id)
	if q == null:
		Net.log_invalid(session.peer_id, "quest_unknown", {"quest": String(quest_id)})
		return false
	if is_active(session, quest_id) or is_done(session, quest_id):
		Net.log_invalid(session.peer_id, "quest_accept_twice", {"quest": String(quest_id)})
		return false
	var missing: Array = missing_requirements(session, q)
	if not missing.is_empty():
		_tell_missing(session, missing)
		Net.log_invalid(session.peer_id, "quest_requirements_missing", {"quest": String(quest_id)})
		return false
	var earned_titles: int = earned_title_count(session.character.progression)
	var needs: Array[int] = needs_for(q, earned_titles)
	var st: Dictionary = {ProgressionData.Q_STEP: 0, ProgressionData.Q_COUNT: 0, ProgressionData.Q_NEEDS: needs}
	session.character.progression.quests[quest_id] = st
	_skip_inactive(st, q)
	Net.push_system_message(session.peer_id, MSG_ACCEPTED, [q.name_key])
	Net.log_line("quest_accepted", {"peer": session.peer_id, "quest": String(quest_id),
			"titles": earned_titles, "needs": needs})
	if is_solo_quest(q):
		_go_solo(session)
	_enter_step(session, q)
	progression.mark_dirty(session)
	return true


## Quest de título é provação pessoal: sai do grupo e avisa que só conta o que ele mesmo fizer.
func _go_solo(session: PlayerSession) -> void:
	var party: PartyService = world.party
	if party != null and party.party_of_peer(session.peer_id) != null:
		party.leave(session)
		Net.push_system_message(session.peer_id, MSG_SOLO_LEFT_PARTY)
		Net.log_line("quest_solo_left_party", {"peer": session.peer_id})
	Net.push_system_message(session.peer_id, MSG_SOLO_LOOT_ONLY)


## Pula as etapas fora desta aceitação a partir da atual.
static func _skip_inactive(st: Dictionary, q: QuestDef) -> void:
	var needs: Array = st.get(ProgressionData.Q_NEEDS, [])
	var i: int = int(st[ProgressionData.Q_STEP])
	while i < q.steps.size() and i < needs.size() and int(needs[i]) == SKIPPED_STEP:
		i += 1
	st[ProgressionData.Q_STEP] = i


func abandon(session: PlayerSession, quest_id: StringName) -> bool:
	if not is_active(session, quest_id):
		return false
	session.character.progression.quests.erase(quest_id)
	if _trials.has(session.peer_id) and _trials[session.peer_id]["quest"] == quest_id:
		_clear_trial_entities(_trials[session.peer_id])
		_trials.erase(session.peer_id)
	var q: QuestDef = Content.quest(quest_id)
	Net.push_system_message(session.peer_id, MSG_ABANDONED, [q.name_key if q != null else ""])
	Net.log_line("quest_abandoned", {"peer": session.peer_id, "quest": String(quest_id)})
	progression.mark_dirty(session)
	return true


## Entrega no NPC certo, com todas as etapas feitas; revalida os requisitos (TITULOS §6.2 regra 4).
func turn_in(session: PlayerSession, quest_id: StringName, npc_def_id: StringName) -> bool:
	var q: QuestDef = Content.quest(quest_id)
	if q != null and session.character.stars < q.turn_in_stars:
		Net.push_system_message(session.peer_id, "MOUNT_NEED_STARS", [q.turn_in_stars])
		return false
	if q == null or not is_ready(session, quest_id):
		Net.log_invalid(session.peer_id, "quest_turn_in_not_ready", {"quest": String(quest_id)})
		return false
	if npc_def_id != turn_in_npc_of(q):
		Net.log_invalid(session.peer_id, "quest_turn_in_wrong_npc", {"quest": String(quest_id)})
		return false
	var missing: Array = missing_requirements(session, q)
	if not missing.is_empty():
		_tell_missing(session, missing)
		Net.log_invalid(session.peer_id, "quest_turn_in_requirements", {"quest": String(quest_id)})
		return false
	var inv: Inventory = session.character.inventory
	if not inv.can_add_all(q.reward_items):
		Net.push_system_message(session.peer_id, SysMsg.INVENTORY_FULL)
		return false
	var data: ProgressionData = session.character.progression
	data.quests.erase(quest_id)
	data.quests_done[quest_id] = int(Time.get_unix_time_from_system())
	if not q.reward_causo_id.is_empty():
		var old_rank: int = CharacterData.causos_rank_index(session.character.causos)
		if session.character.grant_causo(q.reward_causo_id):
			session.character.complete_story_arc(q.reward_causo_id, q.reward_story_ending)
			var new_rank: int = CharacterData.causos_rank_index(session.character.causos)
			Net.push_system_message(session.peer_id, MSG_CAUSO_EARNED, [q.name_key, CharacterData.CAUSO_POINTS_STORY])
			match q.reward_story_ending:
				&"killed":
					Net.push_system_message(session.peer_id, "PROG_MSG_WEREWOLF_ENDING_DEATH", [])
				&"healed":
					Net.push_system_message(session.peer_id, "PROG_MSG_WEREWOLF_ENDING_HEALED", [])
				&"pacted":
					Net.push_system_message(session.peer_id, "PROG_MSG_WEREWOLF_ENDING_PACT", [])
			if new_rank > old_rank:
				Net.push_system_message(session.peer_id, MSG_CAUSO_RANK_UP, [
						CharacterData.CAUSOS_RANK_KEYS[old_rank], CharacterData.CAUSOS_RANK_KEYS[new_rank]])
	for item_id: StringName in q.reward_items:
		inv.add(item_id, q.reward_items[item_id])
	Net.push_system_message(session.peer_id, MSG_COMPLETED, [q.name_key])
	Net.log_line("quest_completed", {"peer": session.peer_id, "quest": String(quest_id),
			"skill": String(q.reward_skill), "title": String(q.reward_title),
			"causo": String(q.reward_causo_id), "xp": q.reward_xp})
	_grant_rewards(session, q)
	if q.turn_in_stars > 0:
		session.character.stars -= q.turn_in_stars
		session.mark_dirty(PlayerSession.DIRTY_CURRENCY)
	if not q.reward_companion.is_empty() and world.companions != null:
		world.companions.grant(session, q.reward_companion)
	if not q.reward_mount.is_empty() and Content.mount(q.reward_mount) != null \
			and q.reward_mount not in session.character.mounts_owned:
		session.character.mounts_owned.append(q.reward_mount)
	progression.titles.recalc(session)
	if q.training_title_quest:
		_close_other_training_quests(session, quest_id)
	if q.reward_xp > 0:
		progression.grant_xp(session.peer_id, q.reward_xp, &"quest")
	progression.mark_dirty(session)
	return true


## Renome por um feito (uma vez por deed_id): soma os pontos, avisa o motivo e a subida de renome.
func award_fame(session: PlayerSession, deed_id: String, points: int, msg_key: String, args: Array = []) -> bool:
	var c: CharacterData = session.character
	var old_rank: int = CharacterData.causos_rank_index(c.causos)
	if not c.grant_deed(deed_id, points):
		return false
	var new_rank: int = CharacterData.causos_rank_index(c.causos)
	var msg_args: Array = [points]
	msg_args.append_array(args)
	Net.push_system_message(session.peer_id, msg_key, msg_args)
	if new_rank > old_rank:
		Net.push_system_message(session.peer_id, MSG_FAME_RANK_UP, [CharacterData.CAUSOS_RANK_KEYS[new_rank]])
	Net.log_line("causos_deed", {"peer": session.peer_id, "deed": deed_id, "points": points,
			"causos": c.causos, "rank": new_rank})
	progression.mark_dirty(session)
	return true


## Abate de chefe (estágio 3) ou forma atroz com nível acima do personagem: renome, uma vez por espécie
## e forma. Provações (monstros invocados para um jogador) não contam.
func on_fame_kill(peer_id: int, monster_id: StringName, info: Dictionary) -> void:
	var session: PlayerSession = world.get_session(peer_id)
	if session == null:
		return
	var level: int = int(info.get(INFO_LEVEL, 0))
	if level <= session.character.level:
		return
	var species: StringName = MonsterDef.species_of(monster_id)
	var def: MonsterDef = Content.monster(species)
	var boss_stage: MonsterStage = null
	if def != null:
		for st: MonsterStage in def.stages:
			if st.stage == CombatRules.STAGE_BOSS:
				boss_stage = st
	var name_key: String = boss_stage.name_key if boss_stage != null else String(species)
	if bool(info.get(INFO_ATROZ, false)):
		var atroz: MonsterStage = def.atroz_stage() if def != null else null
		award_fame(session, "atroz:%s" % species, CharacterData.CAUSO_POINTS_ATROZ, MSG_FAME_ATROZ,
				[atroz.name_key if atroz != null else name_key])
	elif int(info.get(INFO_STAGE, 1)) >= CombatRules.STAGE_BOSS:
		award_fame(session, "boss:%s" % species, CharacterData.CAUSO_POINTS_BOSS, MSG_FAME_BOSS, [name_key])


## Recompensa na ordem certa: o título do ancião antes da skill exclusiva dele.
func _grant_rewards(session: PlayerSession, q: QuestDef) -> void:
	if not q.reward_title.is_empty():
		progression.titles.grant(session, q.reward_title)
	if not q.reward_skill.is_empty():
		progression.skills.learn(session, q.reward_skill)


## Só uma quest de título no treino: as outras ativas são encerradas.
func _close_other_training_quests(session: PlayerSession, done_id: StringName) -> void:
	var data: ProgressionData = session.character.progression
	for id: StringName in data.quests.keys():
		var q: QuestDef = Content.quest(id)
		if id != done_id and q != null and q.training_title_quest:
			data.quests.erase(id)
			Net.push_system_message(session.peer_id, MSG_TRAINING_CLOSED, [q.name_key])
			Net.log_line("quest_training_closed", {"peer": session.peer_id, "quest": String(id)})


func _tell_missing(session: PlayerSession, missing: Array) -> void:
	if missing.is_empty():
		return
	Net.push_system_message(session.peer_id, MSG_MISSING)
	for m: Array in missing:
		Net.push_system_message(session.peer_id, String(m[0]), m[1])


# ---------------------------------------------------------------- progresso das etapas

## Evento de K (ou do substituto): conta derrotas e fecha provações. info (Progression lê do
## MonsterBrain): {"rare": bool, "stage": int, "atroz": bool, "no_death": bool}; vazio = monstro comum.
func on_monster_killed(peer_id: int, monster_id: StringName, info: Dictionary = {}) -> void:
	var session: PlayerSession = world.get_session(peer_id)
	if session == null:
		return
	var trial: Dictionary = _trials.get(peer_id, {})
	for id: StringName in session.character.progression.quests.keys():
		var q: QuestDef = Content.quest(id)
		var s: QuestStep = current_step(session, q) if q != null else null
		if s == null:
			continue
		# Quest de título: só o abate do próprio personagem (crédito de grupo não conta).
		if is_solo_quest(q) and not bool(info.get(INFO_OWNER, true)):
			continue
		if s.type == QuestStep.StepType.KILL and kill_matches(s, monster_id, info):
			var st: Dictionary = session.character.progression.quests[id]
			if s.distinct_species:
				var seen: Array = st.get(ProgressionData.Q_SEEN, [])
				var species: String = String(MonsterDef.species_of(monster_id))
				if species in seen:
					continue
				seen.append(species)
				st[ProgressionData.Q_SEEN] = seen
			_add_count(session, q, s, 1)
		elif s.type == QuestStep.StepType.TRIAL and s.target_id == monster_id \
				and not trial.is_empty() and trial["quest"] == id \
				and StringName(str(trial.get("mode", TRIAL_KILL))) == TRIAL_KILL \
				and _is_trial_entity(trial, info):
			_trials.erase(peer_id)
			_clear_trial_entities(trial)
			_add_count(session, q, s, s.count)


## Provação em andamento (Pergaminho de Retorno não funciona nela).
func has_trial(peer_id: int) -> bool:
	return _trials.has(peer_id) or _arena_visits.has(peer_id)


## Mapas compartilhados (30/09/2026): a provação só fecha com o monstro DELA (outro do mesmo tipo no mapa não
## conta). Sem entity_id no info (substituto de testes sem K) vale a regra antiga.
static func _is_trial_entity(trial: Dictionary, info: Dictionary) -> bool:
	var eid: int = int(info.get(Progression.INFO_ENTITY, 0))
	return eid == 0 or int(trial.get("entity", 0)) == 0 or eid == int(trial["entity"])


## A derrota conta para a etapa KILL? Espécie (vazio/"*" = qualquer; variante regional conta como a espécie
## original, MonsterDef.base_species), variante e "sem cair".
static func kill_matches(s: QuestStep, monster_id: StringName, info: Dictionary) -> bool:
	if s.required_stage > 0 and int(info.get(INFO_STAGE, 0)) != s.required_stage:
		return false
	if not (s.target_id.is_empty() or s.target_id == ANY_SPECIES or s.target_id == monster_id
			or s.target_id == MonsterDef.species_of(monster_id)):
		return false
	match s.variant:
		VARIANT_RARE:
			if not bool(info.get(INFO_RARE, false)):
				return false
		VARIANT_BOSS:
			if int(info.get(INFO_STAGE, 1)) < CombatRules.STAGE_BOSS:
				return false
		VARIANT_ATROZ:
			if not bool(info.get(INFO_ATROZ, false)):
				return false
	if s.no_death and not bool(info.get(INFO_NO_DEATH, true)):
		return false
	return true


## O jogador caiu: provação de sobreviver falha.
func on_player_killed(peer_id: int) -> void:
	var t: Dictionary = _trials.get(peer_id, {})
	if t.is_empty() or StringName(str(t.get("mode", TRIAL_KILL))) != TRIAL_SURVIVE:
		return
	_end_survive(peer_id, false)


## Inventário mudou: recalcula etapas de coletar.
func on_inventory_changed(session: PlayerSession) -> void:
	for id: StringName in session.character.progression.quests.keys():
		var q: QuestDef = Content.quest(id)
		var s: QuestStep = current_step(session, q) if q != null else null
		if s != null and s.type == QuestStep.StepType.COLLECT:
			_update_collect(session, q, s)


## O personagem pegou um item do chão (DropService.pickup, antes de entrar na mochila). Na quest de título,
## a coleta só conta o que ele mesmo pegou depois de chegar à etapa (Q_COUNT); troca, loja e mochila
## antiga não contam. Concluir ainda exige ter a quantidade na mochila (os itens são entregues).
func on_item_looted(session: PlayerSession, item_id: StringName, qty: int) -> void:
	for id: StringName in session.character.progression.quests.keys():
		var q: QuestDef = Content.quest(id)
		var s: QuestStep = current_step(session, q) if q != null else null
		if s == null or s.type != QuestStep.StepType.COLLECT or s.target_id != item_id or not is_solo_quest(q):
			continue
		if not step_time_allowed(session, s):
			continue
		var st: Dictionary = session.character.progression.quests[id]
		var need: int = required_count(session, q)
		var looted: int = mini(int(st[ProgressionData.Q_COUNT]) + qty, need)
		st[ProgressionData.Q_COUNT] = looted
		Net.push_system_message(session.peer_id, MSG_PROGRESS, [q.name_key,
				mini(looted, session.character.inventory.count(item_id) + qty), need])
		progression.mark_dirty(session)


func _update_collect(session: PlayerSession, q: QuestDef, s: QuestStep) -> void:
	var st: Dictionary = session.character.progression.quests[q.id]
	var need: int = required_count(session, q)
	if is_solo_quest(q) and not s.allow_purchased:
		_update_solo_collect(session, q, s, st, need)
		return
	var have: int = mini(session.character.inventory.count(s.target_id), need)
	if have == int(st[ProgressionData.Q_COUNT]):
		return
	var gained: bool = have > int(st[ProgressionData.Q_COUNT])
	st[ProgressionData.Q_COUNT] = have
	if gained:
		Net.push_system_message(session.peer_id, MSG_PROGRESS, [q.name_key, have, need])
	if have >= need:
		_remove_items(session, s.target_id, need)
		_advance(session, q)
	progression.mark_dirty(session)


func _update_solo_collect(session: PlayerSession, q: QuestDef, s: QuestStep, st: Dictionary, need: int) -> void:
	if int(st[ProgressionData.Q_COUNT]) >= need and session.character.inventory.count(s.target_id) >= need:
		_remove_items(session, s.target_id, need)
		_advance(session, q)
		progression.mark_dirty(session)


func _add_count(session: PlayerSession, q: QuestDef, s: QuestStep, n: int) -> void:
	var st: Dictionary = session.character.progression.quests[q.id]
	var need: int = required_count(session, q)
	var c: int = mini(int(st[ProgressionData.Q_COUNT]) + n, need)
	st[ProgressionData.Q_COUNT] = c
	Net.push_system_message(session.peer_id, MSG_PROGRESS, [q.name_key, c, need])
	Net.log_line("quest_progress", {"peer": session.peer_id, "quest": String(q.id),
			"step": int(st[ProgressionData.Q_STEP]), "count": c, "need": need})
	if c >= need:
		_advance(session, q)
	progression.mark_dirty(session)


func _advance(session: PlayerSession, q: QuestDef) -> void:
	var st: Dictionary = session.character.progression.quests[q.id]
	st[ProgressionData.Q_STEP] = int(st[ProgressionData.Q_STEP]) + 1
	st[ProgressionData.Q_COUNT] = 0
	st.erase(ProgressionData.Q_SEEN)
	_skip_inactive(st, q)
	session.save_pending = true
	if int(st[ProgressionData.Q_STEP]) >= q.steps.size():
		Net.push_system_message(session.peer_id, MSG_READY, [q.name_key])
		Net.log_line("quest_ready", {"peer": session.peer_id, "quest": String(q.id)})
	else:
		Net.push_system_message(session.peer_id, MSG_STEP_DONE, [q.name_key])
		_enter_step(session, q)


## Etapa nova: coletar já conta o que está na mochila.
func _enter_step(session: PlayerSession, q: QuestDef) -> void:
	var s: QuestStep = current_step(session, q)
	if s != null and s.type == QuestStep.StepType.COLLECT:
		_update_collect(session, q, s)


func _remove_items(session: PlayerSession, item_id: StringName, qty: int) -> void:
	var inv: Inventory = session.character.inventory
	var left: int = qty
	for slot: int in inv.size():
		if left <= 0:
			break
		var st: ItemStack = inv.get_slot(slot)
		if st == null or st.item_id != item_id:
			continue
		var n: int = mini(left, st.qty)
		inv.remove_at(slot, n)
		left -= n


## Explorar (posição) e prazo das provações. Chamado a cada tick pela Progression.
func tick() -> void:
	var now: int = Time.get_ticks_msec()
	_tick_arena_visits()
	for peer_id: int in _trials.keys():
		var t: Dictionary = _trials[peer_id]
		var deadline: int = int(t["deadline"])
		if StringName(str(t.get("mode", TRIAL_KILL))) == TRIAL_SURVIVE:
			_tick_survive(peer_id, t, now)
			continue
		if StringName(str(t.get("mode", TRIAL_KILL))) == TRIAL_PROTECT:
			_tick_protect(peer_id, t, now)
			continue
		if deadline > 0 and now > deadline:
			_trials.erase(peer_id)
			var target: NetEntity = world.get_entity(int(t["entity"]))
			if target != null and progression.bridge.stub_hp(target.entity_id) > 0:
				target.queue_free()
			Net.push_system_message(peer_id, MSG_TRIAL_FAILED)
			Net.log_line("trial_failed", {"peer": peer_id, "quest": String(t["quest"])})
			var s: PlayerSession = world.get_session(peer_id)
			if s != null:
				progression.mark_dirty(s)
	if now < _next_explore_msec:
		return
	_next_explore_msec = now + EXPLORE_CHECK_MSEC
	for session: PlayerSession in progression.sessions():
		for id: StringName in session.character.progression.quests.keys():
			var q: QuestDef = Content.quest(id)
			var s: QuestStep = current_step(session, q) if q != null else null
			if s == null:
				continue
			if s.type == QuestStep.StepType.WAIT:
				_tick_wait(session, q, s, now)
				continue
			if s.type != QuestStep.StepType.EXPLORE or not step_time_allowed(session, s):
				continue
			if s.requires_full_moon \
					and not DayNight.is_full_moon_night(Progression.map_of(session.entity.instance_id)):
				continue
			var p: Variant = _explore_point(session.entity.instance_id, s.target_id)
			if p != null and session.entity.flat_distance_to(p as Vector3) \
					<= s.radius_cells * Balance.cfg.cell_size:
				_add_count(session, q, s, s.count)


static func step_time_allowed(session: PlayerSession, step: QuestStep) -> bool:
	var night: bool = DayNight.is_night_on_map(Progression.map_of(session.entity.instance_id))
	return (not step.requires_night or night) and (not step.requires_day or not night)


func _tick_wait(session: PlayerSession, q: QuestDef, step: QuestStep, now: int) -> void:
	var key: String = "%d:%s" % [session.peer_id, q.id]
	var point: Variant = _explore_point(session.entity.instance_id, step.target_id)
	var allowed: bool = point != null and session.character.hp > 0 and step_time_allowed(session, step) \
			and session.entity.flat_distance_to(point) <= step.radius_cells * Balance.cfg.cell_size \
			and (session.entity.get_mover() == null or not session.entity.get_mover().is_moving()) \
			and (not step.requires_hidden or progression.statuses.is_hidden(session.entity))
	if not allowed:
		_waits.erase(key)
		return
	var previous: Dictionary = _waits.get(key, {})
	if previous.is_empty() or previous.position.distance_to(session.entity.net_position) > 0.01 \
			or previous.instance != session.entity.instance_id:
		_waits[key] = {"start": now, "position": session.entity.net_position, "instance": session.entity.instance_id}
	elif now - int(previous.start) >= roundi(step.wait_sec * 1000):
		_waits.erase(key)
		_add_count(session, q, step, 1)


## Ponto de explorar: Marker3D/Node3D com esse nome no mapa, ou "x,z" literal.
func _explore_point(instance_id: StringName, marker: StringName) -> Variant:
	var text: String = String(marker)
	if text.count(",") == 1 and text.get_slice(",", 0).is_valid_float():
		return Vector3(text.get_slice(",", 0).to_float(), 0.0, text.get_slice(",", 1).to_float())
	var map_id: StringName = Progression.map_of(instance_id)
	var cache: Dictionary = _marker_cache.get(map_id, {})
	if cache.has(marker):
		return cache[marker]
	var inst_root: Node = world.main_node.get(&"instances_root") as Node
	var inst: Node = inst_root.get_node_or_null(Net.instance_node_name(instance_id))
	var map_node: Node = inst.get_node_or_null(^"Map") if inst != null else null
	var n: Node3D = map_node.find_child(text, true, false) as Node3D if map_node != null else null
	if n == null:
		return null
	cache[marker] = n.global_position
	_marker_cache[map_id] = cache
	return n.global_position


# ---------------------------------------------------------------- provação

func on_player_placed(session: PlayerSession) -> void:
	var visit: Dictionary = _arena_visits.get(session.peer_id, {})
	if visit.is_empty() or not bool(visit.get("pending", false)):
		return
	if Progression.map_of(session.entity.instance_id) != StringName(visit["arena"]):
		return
	visit["arrived"] = true


func _tick_arena_visits() -> void:
	for peer_id: int in _arena_visits.keys():
		var visit: Dictionary = _arena_visits[peer_id]
		var session: PlayerSession = world.get_session(peer_id)
		if session == null:
			_clear_trial_entities(_trials.get(peer_id, {}))
			_trials.erase(peer_id)
			_arena_visits.erase(peer_id)
			continue
		if bool(visit.get("pending", false)):
			if bool(visit.get("arrived", false)) and world.get_grid_for_instance(session.entity.instance_id) != null:
				visit["pending"] = false
				start_trial(session, StringName(visit["quest"]))
			continue
		if session.character.hp <= 0:
			if _trials.has(peer_id):
				_clear_trial_entities(_trials[peer_id])
				_trials.erase(peer_id)
				Net.push_system_message(peer_id, MSG_TRIAL_FAILED)
			continue # ZoneRules renasce o jogador antes de voltar à cidade.
		if not _trials.has(peer_id):
			if world.map_transfer.transfer(session, StringName(visit["return_map"])):
				_arena_visits.erase(peer_id)


func start_trial(session: PlayerSession, quest_id: StringName) -> bool:
	var q: QuestDef = Content.quest(quest_id)
	var s: QuestStep = current_step(session, q) if q != null else null
	if s == null or s.type != QuestStep.StepType.TRIAL:
		Net.log_invalid(session.peer_id, "trial_not_current", {"quest": String(quest_id)})
		return false
	if session.character.hp <= 0:
		return false
	var active_visit: Dictionary = _arena_visits.get(session.peer_id, {})
	var arrived_for_trial: bool = not active_visit.is_empty() and not bool(active_visit.get("pending", false))
	if s.trial_requires_full_moon and not arrived_for_trial \
			and not DayNight.is_full_moon_night(s.trial_map_id if not s.trial_map_id.is_empty() \
				else Progression.map_of(session.entity.instance_id)):
		Net.push_system_message(session.peer_id, "PROG_MSG_STORY_NEEDS_FULL_MOON", [])
		return false
	if not s.trial_map_id.is_empty() and Progression.map_of(session.entity.instance_id) != s.trial_map_id:
		if _arena_visits.has(session.peer_id):
			return false
		_arena_visits[session.peer_id] = {"quest": quest_id, "arena": s.trial_map_id,
				"return_map": Progression.map_of(session.entity.instance_id), "pending": true}
		if not world.map_transfer.transfer(session, s.trial_map_id):
			_arena_visits.erase(session.peer_id)
			return false
		return true
	var old: Dictionary = _trials.get(session.peer_id, {})
	if not old.is_empty():
		Net.log_invalid(session.peer_id, "trial_already_running")
		return false
	var npc: NetEntity = world.get_entity(session.dialogue_npc_id)
	var me: NetEntity = session.entity
	var dir: Vector3 = Vector3.FORWARD
	if npc != null:
		var d := Vector3(npc.net_position.x - me.net_position.x, 0.0, npc.net_position.z - me.net_position.z)
		if d.length() > 0.0:
			dir = d.normalized()
	if s.trial_mode == TRIAL_SURVIVE:
		return _start_survive(session, q, s)
	if s.trial_mode == TRIAL_PROTECT:
		return _start_protect(session, q, s)
	var pos: Vector3 = world.snap_to_grid(me.instance_id, me.net_position + dir * TRIAL_SPAWN_DISTANCE)
	var target: NetEntity = progression.bridge.spawn_trial_target(me.instance_id, s.target_id, pos,
			session.peer_id, s.trial_stage)
	if target == null:
		Net.log_line("trial_spawn_failed", {"peer": session.peer_id, "quest": String(quest_id)})
		return false
	var deadline: int = 0
	if s.time_limit_sec > 0.0:
		deadline = Time.get_ticks_msec() + roundi(s.time_limit_sec * MSEC_PER_SEC)
	_trials[session.peer_id] = {"quest": quest_id, "target": s.target_id,
			"entity": target.entity_id, "deadline": deadline}
	Net.push_system_message(session.peer_id, MSG_TRIAL_STARTED, [q.name_key])
	if s.time_limit_sec > 0.0:
		Net.push_system_message(session.peer_id, MSG_TRIAL_TIME, [roundi(s.time_limit_sec)])
	Net.log_line("trial_started", {"peer": session.peer_id, "quest": String(quest_id),
			"target": target.entity_id, "monster": String(s.target_id)})
	progression.mark_dirty(session)
	return true


# ---------------------------------------------------------------- provação de sobreviver

## Aguentar vivo até o fim do tempo contra ondas de monstros (quests dos anciãos, §3.3).
func _start_survive(session: PlayerSession, q: QuestDef, s: QuestStep) -> bool:
	var now: int = Time.get_ticks_msec()
	var deadline: int = now + roundi(maxf(1.0, s.time_limit_sec) * MSEC_PER_SEC)
	var t: Dictionary = {"quest": q.id, "target": s.target_id, "entity": 0, "deadline": deadline,
			"mode": TRIAL_SURVIVE, "spawned": [], "next_wave": now}
	_trials[session.peer_id] = t
	Net.push_system_message(session.peer_id, MSG_TRIAL_STARTED, [q.name_key])
	Net.push_system_message(session.peer_id, MSG_TRIAL_TIME, [roundi(s.time_limit_sec)])
	Net.log_line("trial_started", {"peer": session.peer_id, "quest": String(q.id), "mode": "survive",
			"monster": String(s.target_id), "count": s.trial_spawn_count, "sec": s.time_limit_sec})
	_tick_survive(session.peer_id, t, now)
	progression.mark_dirty(session)
	return true


func _tick_survive(peer_id: int, t: Dictionary, now: int) -> void:
	var session: PlayerSession = world.get_session(peer_id)
	if session == null or session.entity == null:
		_trials.erase(peer_id)
		return
	if session.character.hp <= 0:
		_end_survive(peer_id, false)
		return
	if now >= int(t["deadline"]):
		_end_survive(peer_id, true)
		return
	if now < int(t["next_wave"]):
		return
	var q: QuestDef = Content.quest(t["quest"])
	var s: QuestStep = current_step(session, q) if q != null else null
	if s == null:
		_trials.erase(peer_id)
		return
	t["next_wave"] = now + roundi(s.trial_wave_sec * MSEC_PER_SEC) if s.trial_wave_sec > 0.0 \
			else int(t["deadline"]) + 1
	var me: NetEntity = session.entity
	var n: int = maxi(1, s.trial_spawn_count)
	for i: int in n:
		var angle: float = TAU * float(i) / float(n)
		var p: Vector3 = me.net_position + Vector3(cos(angle), 0.0, sin(angle)) \
				* TRIAL_RING_CELLS * Balance.cfg.cell_size
		var m: NetEntity = progression.bridge.spawn_trial_target(me.instance_id, s.target_id,
				world.snap_to_grid(me.instance_id, p), peer_id)
		if m == null:
			continue
		(t["spawned"] as Array).append(m.entity_id)
		_engage(m, me)


## O monstro da provação vai direto no jogador (mesmo as espécies passivas).
func _engage(monster: NetEntity, victim: NetEntity) -> void:
	var k: Object = progression.bridge.k_service()
	if k == null or not k.has_method(CombatBridge.M_GET_BRAIN):
		return
	var brain: Object = k.call(CombatBridge.M_GET_BRAIN, monster)
	if brain != null and brain.has_method(&"_engage"):
		brain.call(&"_engage", victim)


func _end_survive(peer_id: int, success: bool) -> void:
	var t: Dictionary = _trials.get(peer_id, {})
	_trials.erase(peer_id)
	_clear_trial_entities(t)
	var session: PlayerSession = world.get_session(peer_id)
	Net.log_line("trial_survive_end", {"peer": peer_id, "quest": String(t.get("quest", "")),
			"success": success})
	if session == null:
		return
	if not success:
		Net.push_system_message(peer_id, MSG_TRIAL_FAILED)
		progression.mark_dirty(session)
		return
	var q: QuestDef = Content.quest(t.get("quest", &""))
	var s: QuestStep = current_step(session, q) if q != null else null
	if s != null and s.type == QuestStep.StepType.TRIAL:
		Net.push_system_message(peer_id, MSG_TRIAL_SURVIVED, [q.name_key])
		_add_count(session, q, s, s.count)


# ---------------------------------------------------------------- provação de proteger (Vó Aninha)

## Nascem as mudas (protegidas, aliadas do jogador) em volta dele; as ondas vêm atrás delas.
func _start_protect(session: PlayerSession, q: QuestDef, s: QuestStep) -> bool:
	var me: NetEntity = session.entity
	var now: int = Time.get_ticks_msec()
	var seedlings: Array = []
	var n: int = maxi(1, s.protect_count)
	var used: Dictionary = {}
	for i: int in n:
		var angle: float = TAU * float(i) / float(n) + PI * 0.5
		var p: Vector3 = world.snap_to_grid(me.instance_id, me.net_position + Vector3(cos(angle), 0.0, sin(angle))
				* PROTECT_RING_CELLS * Balance.cfg.cell_size)
		if used.has(p):
			p = world.snap_to_grid(me.instance_id, p + Vector3(Balance.cfg.cell_size, 0.0, 0.0))
		used[p] = true
		var e: NetEntity = progression.bridge.spawn_trial_target(me.instance_id, s.protect_target, p, session.peer_id)
		if e == null:
			continue
		progression.protected[e.entity_id] = session.peer_id
		seedlings.append(e.entity_id)
	if seedlings.is_empty():
		Net.log_line("trial_spawn_failed", {"peer": session.peer_id, "quest": String(q.id), "mode": "protect"})
		return false
	var t: Dictionary = {"quest": q.id, "target": s.target_id, "entity": 0, "mode": TRIAL_PROTECT,
			"deadline": now + roundi(maxf(1.0, s.time_limit_sec) * MSEC_PER_SEC), "spawned": [],
			"protected": seedlings, "next_wave": now + roundi(PROTECT_FIRST_WAVE_SEC * MSEC_PER_SEC)}
	_trials[session.peer_id] = t
	Net.push_system_message(session.peer_id, MSG_TRIAL_STARTED, [q.name_key])
	Net.push_system_message(session.peer_id, MSG_TRIAL_TIME, [roundi(s.time_limit_sec)])
	Net.log_line("trial_started", {"peer": session.peer_id, "quest": String(q.id), "mode": "protect",
			"protected": seedlings, "monster": String(s.target_id), "sec": s.time_limit_sec})
	progression.mark_dirty(session)
	return true


## Mudas vivas da provação.
func _alive_protected(t: Dictionary) -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	for id: Variant in t.get("protected", []):
		var e: NetEntity = world.get_entity(int(id))
		if e != null and is_instance_valid(e) and not e.is_queued_for_deletion() and e.hp_ratio > 0.0:
			out.append(e)
	return out


func _tick_protect(peer_id: int, t: Dictionary, now: int) -> void:
	var session: PlayerSession = world.get_session(peer_id)
	var q: QuestDef = Content.quest(t["quest"])
	var s: QuestStep = current_step(session, q) if session != null and q != null else null
	if s == null:
		_clear_trial_entities(t)
		_trials.erase(peer_id)
		return
	var alive: Array[NetEntity] = _alive_protected(t)
	if alive.size() < maxi(1, s.protect_min_alive):
		_end_protect(peer_id, false)
		return
	if now >= int(t["deadline"]):
		_end_protect(peer_id, true)
		return
	# Ondas: nascem em volta do jogador e vão nas mudas.
	if now >= int(t["next_wave"]):
		t["next_wave"] = now + roundi(s.trial_wave_sec * MSEC_PER_SEC) if s.trial_wave_sec > 0.0 \
				else int(t["deadline"]) + 1
		var me: NetEntity = session.entity
		var n: int = maxi(1, s.trial_spawn_count)
		for i: int in n:
			var angle: float = TAU * float(i) / float(n)
			var p: Vector3 = me.net_position + Vector3(cos(angle), 0.0, sin(angle)) \
					* TRIAL_RING_CELLS * Balance.cfg.cell_size
			var m: NetEntity = progression.bridge.spawn_trial_target(me.instance_id, s.target_id,
					world.snap_to_grid(me.instance_id, p), peer_id)
			if m != null:
				(t["spawned"] as Array).append(m.entity_id)
	# Monstro sem alvo válido (ou que acabou de ser provocado e já soltou) volta para a muda mais perto.
	var k: Object = progression.bridge.k_service()
	if k == null or not k.has_method(CombatBridge.M_GET_BRAIN):
		return
	for id: Variant in t["spawned"]:
		var m2: NetEntity = world.get_entity(int(id))
		if m2 == null or not is_instance_valid(m2) or m2.hp_ratio <= 0.0:
			continue
		if progression.statuses.has(m2, StatusEffects.Kind.TAUNT):
			continue
		var brain: Object = k.call(CombatBridge.M_GET_BRAIN, m2)
		if brain == null or bool(brain.call(&"is_dead")):
			continue
		var cur: Variant = brain.get(&"target")
		if cur is NetEntity and is_instance_valid(cur) and progression.is_protected(cur as NetEntity) \
				and (cur as NetEntity).hp_ratio > 0.0:
			continue
		var best: NetEntity = null
		for sd: NetEntity in alive:
			if best == null or m2.flat_distance_to(sd.net_position) < m2.flat_distance_to(best.net_position):
				best = sd
		if best != null and brain.has_method(&"_engage"):
			brain.call(&"_engage", best)


## Só testes (ProgressionDebug trial_time): a provação ativa acaba daqui a `sec` segundos.
func set_trial_deadline(peer_id: int, sec: float) -> void:
	if _trials.has(peer_id):
		_trials[peer_id]["deadline"] = Time.get_ticks_msec() + roundi(sec * MSEC_PER_SEC)


## K avisou: uma muda caiu.
func on_protected_killed(entity: NetEntity) -> void:
	for peer_id: int in _trials.keys():
		var t: Dictionary = _trials[peer_id]
		if entity.entity_id in (t.get("protected", []) as Array):
			var left: int = _alive_protected(t).size()
			Net.push_system_message(peer_id, MSG_TRIAL_PROTECT_FELL, [left])
			Net.log_line("trial_protected_fell", {"peer": peer_id, "entity": entity.entity_id, "alive": left})
			_tick_protect(peer_id, t, Time.get_ticks_msec())
			return


func _end_protect(peer_id: int, success: bool) -> void:
	var t: Dictionary = _trials.get(peer_id, {})
	_trials.erase(peer_id)
	var alive: int = _alive_protected(t).size()
	_clear_trial_entities(t)
	Net.log_line("trial_protect_end", {"peer": peer_id, "quest": String(t.get("quest", "")),
			"success": success, "alive": alive})
	var session: PlayerSession = world.get_session(peer_id)
	if session == null:
		return
	var q: QuestDef = Content.quest(t.get("quest", &""))
	if not success:
		Net.push_system_message(peer_id, MSG_TRIAL_PROTECT_LOST, [q.name_key if q != null else ""])
		progression.mark_dirty(session)
		return
	var s: QuestStep = current_step(session, q) if q != null else null
	if s != null and s.type == QuestStep.StepType.TRIAL:
		Net.push_system_message(peer_id, MSG_TRIAL_PROTECTED, [alive])
		_add_count(session, q, s, s.count)


## Tira da instância os monstros e protegidos de uma provação.
func _clear_trial_entities(t: Dictionary) -> void:
	var target: NetEntity = world.get_entity(int(t.get("entity", 0)))
	if target != null and not target.is_queued_for_deletion():
		world.despawn_entity(target)
	for key: String in ["spawned", "protected"]:
		for id: Variant in t.get(key, []):
			progression.protected.erase(int(id))
			var m: NetEntity = world.get_entity(int(id))
			if m != null and is_instance_valid(m) and not m.is_queued_for_deletion():
				world.despawn_entity(m)


# ---------------------------------------------------------------- diálogo

func handles_condition(key: StringName) -> bool:
	return key in CONDITIONS


func check_condition(session: PlayerSession, key: StringName, value: Variant) -> bool:
	var id := StringName(str(value))
	match key:
		COND_QUEST_AVAILABLE:
			var q: QuestDef = Content.quest(id)
			return q != null and is_available(session, q)
		COND_QUEST_ACTIVE:
			return is_active(session, id) and not is_ready(session, id)
		COND_QUEST_READY:
			return is_ready(session, id)
		COND_QUEST_DONE:
			return is_done(session, id)
		COND_QUEST_LOCKED:
			var ql: QuestDef = Content.quest(id)
			return ql != null and not is_active(session, id) and not is_done(session, id) \
					and not missing_requirements(session, ql).is_empty()
		COND_QUEST_TAKEN:
			return is_active(session, id) or is_done(session, id)
		COND_HAS_TITLE:
			return SkillTree.holds_title(session.character.progression.titles, id)
		COND_KNOWS_SKILL:
			return session.character.progression.knows(id)
	return false


func handles_action(action: StringName) -> bool:
	return action in ACTIONS


## Executa a ação. true = tratada (o DialogueRunner não segue para next_node).
func run_dialogue_action(session: PlayerSession, opt: DialogueOption) -> bool:
	var quest_id := StringName(str(opt.action_args.get(ARG_QUEST_ID, "")))
	var q: QuestDef = Content.quest(quest_id)
	var npc_def: StringName = _dialogue_npc_def(session)
	if q == null:
		world.dialogue.close(session, true)
		return true
	match opt.action:
		ACTION_OFFER:
			_show(session, NODE_PREFIX + "offer", q.offer_text_key, [
					_opt(OPT_ACCEPT, ACTION_ACCEPT, quest_id), _opt(OPT_DECLINE, DialogueRunner.ACTION_CLOSE)])
			return true
		ACTION_SHOW_PROGRESS:
			_show(session, NODE_PREFIX + "progress", q.progress_text_key,
					[_opt(OPT_BYE, DialogueRunner.ACTION_CLOSE)])
			return true
		ACTION_SHOW_COMPLETE:
			_show(session, NODE_PREFIX + "complete", q.complete_text_key,
					[_opt(OPT_TURN_IN, ACTION_TURN_IN, quest_id)])
			return true
		ACTION_MISSING:
			_tell_missing(session, missing_requirements(session, q))
			world.dialogue.close(session, true)
			return true
		ACTION_HEAR_LORE:
			_hear_lore(session, q, npc_def)
			return true
		ACTION_ACCEPT:
			accept(session, quest_id)
		ACTION_TURN_IN:
			turn_in(session, quest_id, npc_def)
		ACTION_START_TRIAL:
			start_trial(session, quest_id)
	if opt.next_node.is_empty():
		world.dialogue.close(session, true)
		return true
	return false


func _dialogue_npc_def(session: PlayerSession) -> StringName:
	var npc: NetEntity = world.get_entity(session.dialogue_npc_id)
	return npc.def_id if npc != null else &""


## Acrescenta as opções de quest ao primeiro nó do diálogo do NPC (e conclui etapas "conversar").
func extend_dialogue(session: PlayerSession, node: DialogueNode, keys: Array[String]) -> void:
	if session.dialogue_def == null or node == null or node.id != session.dialogue_def.start_node:
		return
	var npc_def: StringName = _dialogue_npc_def(session)
	if npc_def.is_empty():
		return
	_complete_talk_steps(session, npc_def, keys)
	var ids: Array = Content.all(&"quests").keys()
	ids.sort()
	for id: StringName in ids:
		var q: QuestDef = Content.quest(id)
		if q == null or _dialogue_mentions(session.dialogue_def, id):
			continue
		var opt: DialogueOption = _quest_option(session, q, npc_def)
		if opt != null:
			session.dialogue_options.append(opt)
			keys.append(opt.text_key)


func _quest_option(session: PlayerSession, q: QuestDef, npc_def: StringName) -> DialogueOption:
	if is_done(session, q.id):
		return null
	if is_active(session, q.id):
		if is_ready(session, q.id):
			return _opt(OPT_REPORT, ACTION_SHOW_COMPLETE, q.id) if turn_in_npc_of(q) == npc_def else null
		if q.giver_npc != npc_def:
			return null
		var s: QuestStep = current_step(session, q)
		if s != null and s.type == QuestStep.StepType.TRIAL and not _trials.has(session.peer_id):
			return _opt(OPT_START_TRIAL, ACTION_START_TRIAL, q.id)
		return _opt(OPT_ASK_PROGRESS, ACTION_SHOW_PROGRESS, q.id)
	if q.giver_npc != npc_def:
		return null
	var missing: Array = missing_requirements(session, q)
	if missing.is_empty():
		return _opt(q.option_text_key, ACTION_OFFER, q.id)
	# Treino já concluído: some. Faltando conhecimento: aparece só se a quest não for escondida.
	if q.training_title_quest and training_title_done(session):
		return null
	return null if q.hidden_until_eligible else _opt(q.option_text_key, ACTION_MISSING, q.id)


## O diálogo do NPC já cita a quest (ações próprias)? Então não duplica. Só oferecer (quest_offer,
## como no fim da lenda dos anciãos) não conta: as opções geradas continuam no começo.
static func _dialogue_mentions(d: DialogueDef, quest_id: StringName) -> bool:
	for n: DialogueNode in d.nodes:
		for o: DialogueOption in n.options:
			if o.action != ACTION_OFFER and StringName(str(o.action_args.get(ARG_QUEST_ID, ""))) == quest_id:
				return true
	return false


func _complete_talk_steps(session: PlayerSession, npc_def: StringName, keys: Array[String]) -> void:
	for id: StringName in session.character.progression.quests.keys():
		var q: QuestDef = Content.quest(id)
		var s: QuestStep = current_step(session, q) if q != null else null
		if s == null or s.type != QuestStep.StepType.TALK or s.target_id != npc_def:
			continue
		if s.lore_text_key.is_empty():
			_add_count(session, q, s, s.count)
		else:
			var opt: DialogueOption = _opt(s.lore_option_key if not s.lore_option_key.is_empty() else OPT_HEAR_LORE,
					ACTION_HEAR_LORE, q.id)
			session.dialogue_options.append(opt)
			keys.append(opt.text_key)


## Conta o causo da etapa TALK atual (se for com este NPC) e conclui a etapa.
func _hear_lore(session: PlayerSession, q: QuestDef, npc_def: StringName) -> void:
	var s: QuestStep = current_step(session, q)
	if s == null or s.type != QuestStep.StepType.TALK or s.target_id != npc_def or s.lore_text_key.is_empty():
		Net.log_invalid(session.peer_id, "quest_lore_not_current", {"quest": String(q.id)})
		world.dialogue.close(session, true)
		return
	_show(session, NODE_PREFIX + "lore", s.lore_text_key, [_opt(OPT_LORE_DONE, DialogueRunner.ACTION_CLOSE)])
	Net.log_line("quest_lore_heard", {"peer": session.peer_id, "quest": String(q.id), "npc": String(npc_def)})
	_add_count(session, q, s, s.count)


static func _opt(text_key: String, action: StringName, quest_id: StringName = &"") -> DialogueOption:
	var o := DialogueOption.new()
	o.text_key = text_key
	o.action = action
	if not quest_id.is_empty():
		o.action_args = {ARG_QUEST_ID: quest_id}
	return o


func _show(session: PlayerSession, node_id: String, text_key: String,
		options: Array[DialogueOption]) -> void:
	var n := DialogueNode.new()
	n.id = StringName(node_id)
	n.text_key = text_key
	n.options = options
	world.dialogue.show_node(session, n)
