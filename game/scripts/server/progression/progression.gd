class_name Progression
extends RefCounted
## Serviço de progressão do servidor (Agente Q, docs/contracts-arrival.md "Progressão (Q)" e
## Apêndice Q): XP e nível (GDD §6.3, teto por zona), pontos de atributo/skill, skills e barra 1–0,
## lançamento de skills, efeitos de status, títulos e quests. Registrado no ServerWorld como
## `world.progression`; recebe as intenções do NetProgress e manda ao dono o snapshot
## (NetProgress.progress_changed) quando algo muda.

## XP de monstros/quests (motivos no log).
const REASON_MONSTER: StringName = &"monster"
const REASON_DEBUG: StringName = &"debug"
const MSG_LEVEL_UP: String = "PROG_MSG_LEVEL_UP"
const MSG_XP_CAPPED: String = "PROG_MSG_XP_CAPPED"
# Sinais do combate de K (Interface K→Q).
const SIG_MONSTER_KILLED: StringName = &"monster_killed"
const SIG_PLAYER_KILLED: StringName = &"player_killed"
const ZONE_RULES_PROP: StringName = &"zone_rules"
const M_XP_ALLOWED: StringName = &"xp_allowed"

static var _instance: Progression = null

var world: ServerWorld = null
var bridge: CombatBridge = null
var statuses: StatusEffects = null
var skills: SkillProgression = null
var titles: TitleService = null
var quests: QuestService = null
var caster: SkillCaster = null
## Peers com snapshot pendente (enviado no fim do tick).
var _dirty: Dictionary[int, bool] = {}
var _last_in_combat: Dictionary[int, bool] = {}
var _last_status_count: Dictionary[int, int] = {}
var _combat_connected: bool = false
## Inventários já observados (etapas de coletar), pelo instance_id do objeto.
var _watched_inventories: Dictionary[int, bool] = {}
## Teste (--progression-autotest): teto de nível forçado por peer (0 = usa a zona).
var _debug_cap: Dictionary[int, int] = {}
var _debug: ProgressionDebug = null
## Filtro de variante das quests (§3.3): primeiro golpe de cada jogador em cada monstro
## (monster entity_id -> {peer: msec}) e a última queda de cada jogador (peer -> msec).
var _first_hit: Dictionary[int, Dictionary] = {}
var _last_death: Dictionary[int, int] = {}
## Monstros mortos já lidos (entity_id -> msec), para não contar o mesmo corpo duas vezes.
var _kills_read: Dictionary[int, int] = {}
## Quanto tempo guardar os registros acima (ms).
const KILL_MEMORY_MSEC: int = 600000
const KILL_MEMORY_ENTRIES: int = 4000
const BRAIN_NODE: String = "MonsterBrain"
## Chave do kill_info com o entity_id do monstro (provação: só o monstro dela conta).
const INFO_ENTITY: String = "entity_id"
## Monstro invocado para a provação de um jogador (sem renome).
const INFO_TRIAL: String = "trial"
## Protegidos de provação (mudas da Vó Aninha): entity_id -> peer dono. Contam como aliados do dono
## (cura, escudo, reforço), jogadores não podem atacá-los e monstros podem (CombatBridges.is_protected).
var protected: Dictionary[int, int] = {}


func _init(p_world: ServerWorld) -> void:
	world = p_world
	_instance = self
	bridge = CombatBridge.new(world)
	statuses = StatusEffects.new(world, bridge)
	skills = SkillProgression.new(self)
	titles = TitleService.new(self)
	quests = QuestService.new(self)
	caster = SkillCaster.new(self)
	bridge.monster_killed.connect(_on_monster_killed)
	NetProgress.allocate_stats_intent.connect(_on_allocate_stats)
	NetProgress.skill_level_up_intent.connect(_on_skill_level_up)
	NetProgress.hotbar_set_intent.connect(_on_hotbar_set)
	NetProgress.cast_intent.connect(_on_cast)
	NetProgress.set_title_intent.connect(_on_set_title)
	NetProgress.quest_abandon_intent.connect(_on_quest_abandon)
	if NetProgress.debug_enabled:
		_debug = ProgressionDebug.new(self)
	Net.log_line("progression_ready", {"skills": Content.all(&"skills").size(),
			"titles": Content.all(&"titles").size(), "quests": Content.all(&"quests").size(),
			"debug": _debug != null})


# ---------------------------------------------------------------- API pública (K, N, testes)

## XP total acumulada do jogador (evolução dos monstros, GDD §10.6). 0 se não estiver online.
static func total_xp(peer_id: int) -> int:
	if _instance == null:
		return 0
	var s: PlayerSession = _instance.world.get_session(peer_id)
	return s.character.progression.total_xp if s != null else 0


## XP para ir do nível `level` ao próximo: floor(100 * nivel^1.6) (GDD §6.3).
static func xp_to_next(level: int) -> int:
	return floori(Balance.cfg.xp_curve_base * pow(level, Balance.cfg.xp_curve_exponent))


## map_id de um instance_id ("mapa"; "mapa:x" só nas instâncias extras dos testes).
static func map_of(instance_id: StringName) -> StringName:
	return StringName(String(instance_id).get_slice(Net.INSTANCE_SEPARATOR, 0))


## K (CombatBridges): a entidade é um protegido de provação?
func is_protected(entity: NetEntity) -> bool:
	return entity != null and protected.has(entity.entity_id)


## É protegido deste jogador ou do grupo dele (aliado para cura/escudo)?
func is_protected_ally(owner: NetEntity, entity: NetEntity) -> bool:
	if owner == null or entity == null or not owner.is_player():
		return false
	var trial_owner: int = int(protected.get(entity.entity_id, 0))
	if trial_owner == 0:
		return false
	return trial_owner == owner.get_peer_id() \
			or (world.party != null and world.party.same_party(trial_owner, owner.get_peer_id()))


## K: um protegido caiu (a provação confere na hora).
func on_protected_killed(entity: NetEntity) -> void:
	quests.on_protected_killed(entity)


func sessions() -> Array[PlayerSession]:
	var out: Array[PlayerSession] = []
	for peer_id: int in Net.get_world_peer_ids():
		var s: PlayerSession = world.get_session(peer_id)
		if s != null:
			out.append(s)
	return out


func mark_dirty(session: PlayerSession) -> void:
	_dirty[session.peer_id] = true
	session.save_pending = true


## N (Apêndice N): id do título inicial (o que tem start_map_id). &"" = nenhum.
func initial_title(peer_id: int) -> StringName:
	var s: PlayerSession = world.get_session(peer_id)
	if s == null:
		return &""
	var best: StringName = &""
	for id: StringName in s.character.progression.titles:
		var t: TitleDef = Content.title(id)
		if t != null and not t.start_map_id.is_empty():
			if id == s.character.progression.displayed_title:
				return id
			best = id
	return best


## Cidade inicial pelo título conquistado no Campo de Treino (N usa na saída). &"" se nenhum.
func start_map_for(peer_id: int) -> StringName:
	var s: PlayerSession = world.get_session(peer_id)
	return titles.start_map_for(s) if s != null else &""


## Dá XP respeitando o teto da zona e o nível máximo. Devolve a XP de fato recebida.
func grant_xp(peer_id: int, amount: int, reason: StringName) -> int:
	var s: PlayerSession = world.get_session(peer_id)
	if s == null or amount <= 0:
		return 0
	if world != null and "event_xp_mult" in world and world.event_xp_mult > 1.0 and reason == REASON_MONSTER:
		amount = roundi(amount * world.event_xp_mult)
	var c: CharacterData = s.character
	var data: ProgressionData = c.progression
	if c.level >= Balance.cfg.max_character_level or not xp_allowed(s):
		Net.log_line("xp_capped", {"peer": peer_id, "level": c.level, "amount": amount,
				"reason": String(reason)})
		Net.push_system_message(peer_id, MSG_XP_CAPPED)
		return 0
	data.xp += amount
	var granted: int = amount
	var levels: int = 0
	while c.level < Balance.cfg.max_character_level and data.xp >= xp_to_next(c.level):
		data.xp -= xp_to_next(c.level)
		c.level += 1
		levels += 1
		data.attribute_points += Balance.cfg.attribute_points_per_level
		data.skill_points += Balance.cfg.skill_points_per_level
		Net.push_system_message(peer_id, MSG_LEVEL_UP, [c.level])
		if s != null and s.entity != null:
			NetProgress.push_level_up(Net.get_instance_peer_ids(s.entity.instance_id), s.entity.entity_id, c.level)
		Net.log_line("level_up", {"peer": peer_id, "level": c.level,
				"attribute_points": data.attribute_points, "skill_points": data.skill_points})
		if not xp_allowed(s):
			# Chegou ao teto da zona: o que sobrou não conta (GDD §9.3).
			granted -= data.xp
			data.xp = 0
			break
	if c.level >= Balance.cfg.max_character_level:
		granted -= data.xp
		data.xp = 0
	data.total_xp += granted
	if levels > 0:
		# Subir de nível enche vida e mana.
		var st: Dictionary = c.compute_stats()
		c.hp = st[CharacterStats.K_MAX_HP]
		c.mp = st[CharacterStats.K_MAX_MP]
		s.mark_dirty(PlayerSession.DIRTY_STATS)
	Net.log_line("xp_gained", {"peer": peer_id, "amount": granted, "reason": String(reason),
			"level": c.level, "xp": data.xp, "xp_next": xp_to_next(c.level), "total": data.total_xp})
	mark_dirty(s)
	return granted


## Ainda ganha XP aqui? N (ZoneRules.xp_allowed) decide; sem N, ZoneDef.xp_level_cap do mapa.
func xp_allowed(s: PlayerSession) -> bool:
	var cap: int = _debug_cap.get(s.peer_id, 0)
	if cap > 0:
		return s.character.level < cap
	var zr: Variant = world.get(ZONE_RULES_PROP)
	if zr is Object and (zr as Object).has_method(M_XP_ALLOWED):
		return bool((zr as Object).call(M_XP_ALLOWED, s.peer_id))
	var zone: ZoneDef = Content.zone(map_of(s.entity.instance_id))
	return zone == null or zone.xp_level_cap <= 0 or s.character.level < zone.xp_level_cap


func set_debug_cap(peer_id: int, cap: int) -> void:
	_debug_cap[peer_id] = cap


# ---------------------------------------------------------------- ciclo de vida (ServerWorld)

## Jogador entrou no mundo (ou trocou de instância).
func on_player_ready(session: PlayerSession) -> void:
	var inv: Inventory = session.character.inventory
	if not _watched_inventories.has(inv.get_instance_id()):
		_watched_inventories[inv.get_instance_id()] = true
		inv.changed.connect(quests.on_inventory_changed.bind(session))
	titles.recalc(session)
	titles.apply_to_entity(session)
	caster.cancel(session.peer_id)
	_dirty[session.peer_id] = true


func tick(_delta: float) -> void:
	_connect_combat()
	statuses.tick()
	caster.tick()
	quests.tick()
	for s: PlayerSession in sessions():
		var fighting: bool = bridge.is_in_combat(s.peer_id)
		if fighting != _last_in_combat.get(s.peer_id, false):
			_last_in_combat[s.peer_id] = fighting
			_dirty[s.peer_id] = true
		var n: int = statuses.summary(s.entity).size()
		if n != _last_status_count.get(s.peer_id, 0):
			_last_status_count[s.peer_id] = n
			_dirty[s.peer_id] = true
	for peer_id: int in _dirty.keys():
		var s: PlayerSession = world.get_session(peer_id)
		if s != null:
			NetProgress.push_progress(peer_id, snapshot(s))
	_dirty.clear()


## Liga os sinais do combate de K assim que world.combat existir.
func _connect_combat() -> void:
	if _combat_connected:
		return
	var k: Object = bridge.k_service()
	if k == null:
		return
	_combat_connected = true
	if k.has_signal(SIG_MONSTER_KILLED):
		k.connect(SIG_MONSTER_KILLED, _on_monster_killed)
	if k.has_signal(SIG_PLAYER_KILLED):
		k.connect(SIG_PLAYER_KILLED, _on_player_killed)
	CombatEvents.bus().damage_applied.connect(_on_damage_applied)
	Net.log_line("progression_combat_connected", {"monster_killed": k.has_signal(SIG_MONSTER_KILLED)})


## Abate (GDD §6.3 e §9.1, mapas compartilhados desde 30/09/2026): killer_peer é o dono do monstro (quem
## causou mais dano). A XP é dividida entre ele e os membros do grupo dele vivos no mesmo mapa e perto do
## monstro (PartyService.credit_peers / share_xp); o crédito de quest vai para cada um deles, com o filtro
## "sem cair" de cada jogador.
func _on_monster_killed(killer_peer: int, monster_id: StringName, stage: int, xp: int) -> void:
	var info: Dictionary = kill_info(killer_peer, monster_id, stage)
	var eid: int = int(info.get(INFO_ENTITY, 0))
	var peers: Array[int] = [killer_peer]
	var party: PartyService = world.party
	if party != null and world.get_session(killer_peer) != null:
		var k: Object = bridge.k_service()
		var last: Variant = k.get(&"last_kill") if k != null else null
		var lk: Dictionary = last if last is Dictionary else {}
		var s: PlayerSession = world.get_session(killer_peer)
		var inst: StringName = StringName(str(lk.get("instance_id", s.entity.instance_id)))
		var pos: Vector3 = lk.get("position", Vector3.INF) if lk.get("position") is Vector3 else Vector3.INF
		peers = party.credit_peers(killer_peer, inst, pos)
		if peers.is_empty():
			peers = [killer_peer]
	var xp_mode: StringName = party.xp_mode_for(killer_peer) if party != null else PartyService.XP_MODE_INDIVIDUAL
	if peers.size() > 1:
		Net.log_line("party_kill_shared", {"owner": killer_peer, "peers": peers, "xp_total": xp,
				"mode": String(xp_mode), "monster": String(monster_id), "entity": eid})
	var now: int = Time.get_ticks_msec()
	for index: int in peers.size():
		var peer: int = peers[index]
		var xp_award: int = PartyService.xp_for_recipient(xp, peers.size(), xp_mode, index)
		if xp_award > 0:
			grant_xp(peer, xp_award, REASON_MONSTER)
		# Companheiro ativo (PETS-E-MONTARIAS §0.1): bônus de 20% do XP do monstro só para ele, se o
		# dono participou (é o dono do abate ou bateu no monstro). Não sai do XP do dono.
		if world.companions != null and (peer == killer_peer or (_first_hit.get(eid, {}) as Dictionary).has(peer)):
			var owner: PlayerSession = world.get_session(peer)
			if owner != null:
				world.companions.grant_kill_xp(owner, xp)
		var mine: Dictionary = info
		if peer != killer_peer:
			mine = info.duplicate()
			var first: int = int((_first_hit.get(eid, {}) as Dictionary).get(peer, now))
			mine[QuestService.INFO_NO_DEATH] = _last_death.get(peer, -1) < first
			mine[QuestService.INFO_OWNER] = false
		quests.on_monster_killed(peer, monster_id, mine)
	# Renome: só o dono do abate (quem causou mais dano), e nunca monstro de provação.
	if not bool(info.get(INFO_TRIAL, false)):
		quests.on_fame_kill(killer_peer, monster_id, info)
	# Arco 1: chefe da história conta para todos que participaram do combate (dano, golpes recebidos, grupo por perto).
	var mdef: MonsterDef = Content.monster(monster_id)
	if mdef != null and mdef.story_boss:
		quests.on_story_boss_killed(monster_id, story_participants(eid, peers))
	_first_hit.erase(eid)


## Participantes do combate contra um chefe da história: quem já tem crédito (dono e grupo), quem bateu
## (_first_hit) e quem o MonsterBrain registrou na luta (dano e golpes recebidos).
func story_participants(eid: int, credited: Array[int]) -> Array[int]:
	var out: Array[int] = credited.duplicate()
	for p: Variant in (_first_hit.get(eid, {}) as Dictionary):
		if int(p) not in out:
			out.append(int(p))
	var e: NetEntity = world.get_entity(eid) if eid != 0 else null
	var b: Node = e.get_node_or_null(BRAIN_NODE) if e != null else null
	if b != null and b.has_method(&"participant_peers"):
		for p: int in b.call(&"participant_peers"):
			if p not in out:
				out.append(p)
	return out


## Variante do monstro que acabou de morrer (filtro das quests, §3.3), lida do MonsterBrain: o corpo
## ainda está na instância (animação de morte). {"rare", "stage", "atroz", "no_death", "entity_id"}.
## "atroz" = MonsterBrain.atroz (agente de monstros; false enquanto a propriedade não existir).
func kill_info(killer_peer: int, monster_id: StringName, stage: int) -> Dictionary:
	var info: Dictionary = {QuestService.INFO_STAGE: stage, QuestService.INFO_RARE: false,
			QuestService.INFO_ATROZ: false, QuestService.INFO_NO_DEATH: true}
	var s: PlayerSession = world.get_session(killer_peer)
	if s == null or s.entity == null:
		return info
	var now: int = Time.get_ticks_msec()
	for id: int in _kills_read.keys():
		if now - _kills_read[id] > KILL_MEMORY_MSEC:
			_kills_read.erase(id)
			_first_hit.erase(id)
	# Agente de monstros: CombatService.last_kill (CombatService.kill_info) durante a emissão do abate.
	var k: Object = bridge.k_service()
	var last: Variant = k.get(&"last_kill") if k != null else null
	if last is Dictionary and not (last as Dictionary).is_empty() \
			and StringName(str((last as Dictionary).get("killer_peer", -1))) == StringName(str(killer_peer)):
		var lk: Dictionary = last
		info[QuestService.INFO_STAGE] = int(lk.get("stage", stage))
		info[QuestService.INFO_RARE] = bool(lk.get("rare", false))
		info[QuestService.INFO_ATROZ] = bool(lk.get("atroz", false))
		info[QuestService.INFO_LEVEL] = int(lk.get("level", 0))
		info[INFO_TRIAL] = int(lk.get("trial_owner", 0)) != 0
		var eid: int = int(lk.get("entity_id", 0))
		_kills_read[eid] = now
		info[INFO_ENTITY] = eid
		var first_hit: int = int((_first_hit.get(eid, {}) as Dictionary).get(killer_peer, now))
		info[QuestService.INFO_NO_DEATH] = _last_death.get(killer_peer, -1) < first_hit
		Net.log_line("quest_kill_info", {"peer": killer_peer, "monster": String(monster_id),
				"entity": eid, "info": str(info), "source": "last_kill"})
		return info
	var brain: Node = null
	for e: NetEntity in bridge.entities_in(s.entity.instance_id):
		if not e.is_monster() or e.def_id != monster_id or _kills_read.has(e.entity_id):
			continue
		var b: Node = e.get_node_or_null(BRAIN_NODE)
		if b != null and b.has_method(&"is_dead") and bool(b.call(&"is_dead")):
			brain = b
			_kills_read[e.entity_id] = now
			break
	if brain == null:
		return info
	var ent_id: int = (brain.get_parent() as NetEntity).entity_id
	var st: Variant = brain.get(&"stage")
	if st is Object and (st as Object).get(&"stage") != null:
		info[QuestService.INFO_STAGE] = int((st as Object).get(&"stage"))
	info[QuestService.INFO_RARE] = bool(brain.get(&"rare")) if brain.get(&"rare") != null else false
	info[QuestService.INFO_ATROZ] = bool(brain.get(&"atroz")) if brain.get(&"atroz") != null else false
	if st is Object and (st as Object).get(&"level") != null:
		info[QuestService.INFO_LEVEL] = int((st as Object).get(&"level"))
	info[INFO_TRIAL] = brain.get(&"owner_peer") != null and int(brain.get(&"owner_peer")) != 0
	var first: int = int((_first_hit.get(ent_id, {}) as Dictionary).get(killer_peer, now))
	info[QuestService.INFO_NO_DEATH] = _last_death.get(killer_peer, -1) < first
	info[INFO_ENTITY] = ent_id
	Net.log_line("quest_kill_info", {"peer": killer_peer, "monster": String(monster_id),
			"entity": ent_id, "info": str(info)})
	return info


## Primeiro golpe de cada jogador em cada monstro (regra "sem cair" das quests dos anciãos).
func _on_damage_applied(source_id: int, target_id: int, _amount: int, _crit: bool, _type: int) -> void:
	var src: NetEntity = world.get_entity(source_id)
	if src == null or not src.is_player():
		return
	if _first_hit.size() > KILL_MEMORY_ENTRIES:
		_first_hit.clear()
	var hits: Dictionary = _first_hit.get(target_id, {})
	if not hits.has(src.get_peer_id()):
		hits[src.get_peer_id()] = Time.get_ticks_msec()
		_first_hit[target_id] = hits


func _on_player_killed(victim_peer: int, _killer_entity: int) -> void:
	caster.cancel(victim_peer)
	_last_death[victim_peer] = Time.get_ticks_msec()
	quests.on_player_killed(victim_peer)


## Pedido de movimento aceito (ServerWorld): interrompe a conjuração em andamento (GDD §8.1).
func on_player_moved(session: PlayerSession) -> void:
	caster.interrupt(session.peer_id, SkillCaster.INTERRUPT_MOVE)
	if world.items != null:
		world.items.interrupt_use(session, SkillCaster.INTERRUPT_MOVE)


## Estado completo para o dono (NetProgress.progress_changed).
func snapshot(s: PlayerSession) -> Dictionary:
	var c: CharacterData = s.character
	var d: ProgressionData = c.progression
	var sk: Dictionary = {}
	for id: StringName in d.skills:
		sk[String(id)] = d.skills[id]
	var bar: Array = []
	for id: StringName in d.hotbar:
		bar.append(String(id))
	var ti: Array = []
	for id: StringName in d.titles:
		ti.append(String(id))
	var done: Array = []
	for id: StringName in d.quests_done:
		done.append(String(id))
	var items_cd: Dictionary = world.items.cooldowns_for(s) if world.items != null else {}
	return {
		"level": c.level, "max_level": Balance.cfg.max_character_level,
		"causos": c.causos,
		"companions": world.companions.snapshot(s) if world.companions != null else {},
		"mounts": world.mounts.snapshot(s) if world.mounts != null else {},
		"causos_rank": CharacterData.CAUSOS_RANK_KEYS[CharacterData.causos_rank_index(c.causos)],
		"causos_next": CharacterData.causos_to_next(c.causos),
		"werewolf_clues": c.story_clue_count(&"lobisomem_arc"),
		"xp": d.xp, "xp_next": xp_to_next(c.level), "total_xp": d.total_xp,
		"xp_allowed": xp_allowed(s) and c.level < Balance.cfg.max_character_level,
		"attribute_points": d.attribute_points, "skill_points": d.skill_points,
		"skills": sk, "hotbar": bar, "titles": ti, "displayed_title": String(d.displayed_title),
		"quests": quests.snapshot(s), "quests_done": done,
		"cooldowns": caster.cooldowns_for(s.peer_id), "cooldown_totals": caster.cooldown_totals_for(s.peer_id),
		"casting_ms": caster.casting_ms(s.peer_id), "casting": _casting(s),
		"item_cooldowns": items_cd.get("left", {}), "item_cooldown_totals": items_cd.get("totals", {}),
		"in_combat": bridge.is_in_combat(s.peer_id), "statuses": statuses.summary(s.entity),
		"training_title_done": quests.training_title_done(s),
	}


## Conjuração em andamento (skill ou usável): {"id", "total_ms", "left_ms"} ou {} (GDD §8.1).
func _casting(s: PlayerSession) -> Dictionary:
	var info: Dictionary = caster.casting_info(s.peer_id)
	if info.is_empty() and world.items != null:
		info = world.items.using_info(s.peer_id)
		if not info.is_empty():
			info["id"] = info["item"]
	elif not info.is_empty():
		info["id"] = info["skill"]
	return info


# ---------------------------------------------------------------- intenções

func _session(peer_id: int) -> PlayerSession:
	var s: PlayerSession = world.get_session(peer_id)
	if s == null:
		Net.log_invalid(peer_id, "intent_without_session")
	return s


func _reject(peer_id: int, reason: String, data: Dictionary = {}) -> void:
	if not reason.is_empty():
		Net.log_invalid(peer_id, reason, data)


func _on_allocate_stats(peer_id: int, points: Dictionary) -> void:
	var s: PlayerSession = _session(peer_id)
	if s == null:
		return
	var r: String = skills.allocate_stats(s, points)
	_reject(peer_id, r)
	if r.is_empty():
		s.mark_dirty(PlayerSession.DIRTY_STATS)
		Net.log_line("stats_allocated", {"peer": peer_id, "points": str(points),
				"left": s.character.progression.attribute_points})
	mark_dirty(s)


func _on_skill_level_up(peer_id: int, skill_id: StringName) -> void:
	var s: PlayerSession = _session(peer_id)
	if s == null:
		return
	var r: String = skills.level_up(s, skill_id)
	_reject(peer_id, r, {"skill": String(skill_id)})
	if r.is_empty():
		Net.log_line("skill_level_up", {"peer": peer_id, "skill": String(skill_id),
				"level": s.character.progression.skill_level(skill_id)})
	mark_dirty(s)


func _on_hotbar_set(peer_id: int, slot: int, entry_id: StringName) -> void:
	var s: PlayerSession = _session(peer_id)
	if s == null:
		return
	var r: String = skills.hotbar_set(s, slot, entry_id)
	_reject(peer_id, r, {"slot": slot, "entry": String(entry_id)})
	if r.is_empty():
		Net.log_line("hotbar_set", {"peer": peer_id, "slot": slot, "entry": String(entry_id)})
	mark_dirty(s)


func _on_cast(peer_id: int, skill_id: StringName, target_entity_id: int, ground_pos: Vector3) -> void:
	var s: PlayerSession = _session(peer_id)
	if s == null:
		return
	var r: String = caster.cast(s, skill_id, target_entity_id, ground_pos)
	_reject(peer_id, r, {"skill": String(skill_id), "target": target_entity_id})


func _on_set_title(peer_id: int, title_id: StringName) -> void:
	var s: PlayerSession = _session(peer_id)
	if s == null:
		return
	_reject(peer_id, titles.set_displayed(s, title_id), {"title": String(title_id)})
	mark_dirty(s)


func _on_quest_abandon(peer_id: int, quest_id: StringName) -> void:
	var s: PlayerSession = _session(peer_id)
	if s == null:
		return
	if not quests.abandon(s, quest_id):
		_reject(peer_id, "quest_abandon_not_active", {"quest": String(quest_id)})
