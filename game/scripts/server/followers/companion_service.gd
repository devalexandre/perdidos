class_name CompanionService
extends RefCounted

const HARPY: StringName = &"sabia_companion_harpy"
const GUARA: StringName = &"sabia_companion_guara"
const LUME: StringName = &"sabia_companion_lume"
const SOURCE_PREFIX: String = "companion_"
var world: ServerWorld
var rng := RandomNumberGenerator.new()
var _pending: Dictionary[int, Dictionary] = {}
var _swap_ready: Dictionary[int, int] = {}
var _proc_ready: Dictionary[int, int] = {}
var _reveal: Dictionary[int, Dictionary] = {}

func _init(p_world: ServerWorld) -> void:
	world = p_world
	rng.randomize()

static func harpy_chance(dexterity: int) -> float:
	return minf(0.20, 0.04 + maxi(0, dexterity) * 0.002)

func grant(session: PlayerSession, id: StringName) -> bool:
	var def: CompanionDef = Content.companion(id)
	if def == null or not SkillTree.holds_title(session.character.progression.titles, def.title_id):
		return false
	if id not in session.character.companions_owned:
		session.character.companions_owned.append(id)
	if session.character.companion_active.is_empty():
		_activate(session, id)
	world.progression.mark_dirty(session)
	return true

func restore(session: PlayerSession) -> void:
	var id: StringName = session.character.companion_active
	var def: CompanionDef = Content.companion(id)
	if def == null or id not in session.character.companions_owned \
			or not SkillTree.holds_title(session.character.progression.titles, def.title_id):
		id = &""
	_activate(session, id)

func can_swap(session: PlayerSession) -> bool:
	return session.character.hp > 0 and not world.progression.bridge.is_in_combat(session.peer_id) \
			and session.entity.target_id == 0 \
			and (session.entity.get_mover() == null or not session.entity.get_mover().is_moving()) \
			and world.progression.caster.casting_info(session.peer_id).is_empty() \
			and (world.items == null or world.items.using_info(session.peer_id).is_empty())

func request(session: PlayerSession, id: StringName, now: int = -1) -> String:
	if now < 0:
		now = Time.get_ticks_msec()
	if not id.is_empty():
		var def: CompanionDef = Content.companion(id)
		if def == null or id not in session.character.companions_owned \
				or not SkillTree.holds_title(session.character.progression.titles, def.title_id):
			return "FOLLOWER_NOT_OWNED"
	if id == session.character.companion_active:
		return ""
	if not can_swap(session):
		return "FOLLOWER_STAND_STILL"
	if now < int(_swap_ready.get(session.peer_id, 0)):
		return "COMPANION_SWAP_COOLDOWN"
	if _pending.has(session.peer_id):
		return "FOLLOWER_BUSY"
	_pending[session.peer_id] = {"id": id, "end": now + 2000, "position": session.entity.net_position,
			"instance": session.entity.instance_id}
	world.progression.mark_dirty(session)
	return ""

func cancel(session: PlayerSession) -> void:
	if _pending.erase(session.peer_id):
		world.progression.mark_dirty(session)

func _activate(session: PlayerSession, id: StringName) -> void:
	var data: ProgressionData = session.character.progression
	# Não apaga skills da árvore/ofícios: só as vinculadas a companheiros.
	for resource: CompanionDef in Content.all(&"companions").values():
		for skill: StringName in resource.bond_skills:
			data.skills.erase(skill)
			if resource.id != id:
				for i: int in data.hotbar.size():
					if data.hotbar[i] == skill:
						data.hotbar[i] = &""
	session.character.companion_active = id
	var def: CompanionDef = Content.companion(id)
	if def != null:
		for skill: StringName in def.bond_skills:
			data.skills[skill] = 1
			var sd: SkillDef = Content.skill(skill)
			if sd != null and not sd.passive and data.hotbar_index_of(skill) < 0:
				var index: int = data.hotbar.find(&"")
				if index >= 0:
					data.hotbar[index] = skill
	_reveal.erase(session.peer_id)
	NetFollowers.push_reveal(session.peer_id, [], 0)
	world.refresh_appearance(session)
	world.progression.mark_dirty(session)

func name_companion(session: PlayerSession, id: StringName, text: String) -> String:
	var clean: String = text.strip_edges()
	if clean.length() < 2 or clean.length() > 12 or clean.contains("\n") or clean.contains("\r") \
			or not Net._name_filter().is_name_allowed(clean):
		return "FOLLOWER_NAME_INVALID"
	var quest: QuestDef = null
	if id not in session.character.companions_owned:
		for qid: StringName in session.character.progression.quests:
			var candidate: QuestDef = Content.quest(qid)
			var step: QuestStep = world.progression.quests.current_step(session, candidate) if candidate != null else null
			if step != null and step.type == QuestStep.StepType.NAME_COMPANION and step.target_id == id:
				quest = candidate
				break
		if quest == null:
			return "FOLLOWER_NOT_OWNED"
	session.character.companion_names[String(id)] = clean
	if quest != null:
		world.progression.quests._advance(session, quest)
	world.refresh_appearance(session)
	world.progression.mark_dirty(session)
	return ""

func tick(now: int = -1) -> void:
	if now < 0:
		now = Time.get_ticks_msec()
	for peer: int in _pending.keys():
		var session: PlayerSession = world.get_session(peer)
		if session == null:
			forget(peer)
			continue
		var pending: Dictionary = _pending[peer]
		if not can_swap(session) or session.entity.instance_id != pending.instance \
				or session.entity.net_position.distance_to(pending.position) > 0.01:
			cancel(session)
		elif now >= int(pending.end):
			_pending.erase(peer)
			_swap_ready[peer] = now + roundi(Balance.cfg.companion_swap_cooldown_sec * 1000)
			_activate(session, pending.id)

func on_hit(owner: NetEntity, target: NetEntity, source: StringName, amount: int, now: int = -1) -> bool:
	if not owner.is_player() or amount <= 0 or String(source).begins_with(SOURCE_PREFIX) \
			or target.is_dead() or target.is_queued_for_deletion():
		return false
	var session: PlayerSession = world.get_session(owner.get_peer_id())
	if session == null or session.character.hp <= 0:
		return false
	if now < 0:
		now = Time.get_ticks_msec()
	if now < int(_proc_ready.get(session.peer_id, 0)):
		return false
	var id: StringName = session.character.companion_active
	var mult: float = 0.0
	var cooldown: int = 0
	if id == HARPY and source == CombatService.SOURCE_BASIC_ATTACK \
			and SkillCaster.has_weapon_kind(session, ItemDef.WeaponKind.BOW):
		var dex: int = int(session.character.compute_stats().get(&"dex", 0))
		if rng.randf() >= harpy_chance(dex):
			return false
		mult = 0.8
		cooldown = 1500
	elif id == GUARA and source in [&"bow_ambush_shot", &"bow_vine_snare"]:
		mult = 0.6
		cooldown = 4000
	else:
		return false
	var zone: ZoneDef = Content.zone(Progression.map_of(owner.instance_id))
	if zone != null and zone.kind == ZoneDef.Kind.PVP:
		mult *= Content.companion(id).pvp_proc_mult
	_proc_ready[session.peer_id] = now + cooldown
	NetFollowers.push_strike(Net.get_instance_peer_ids(owner.instance_id), owner.entity_id, target.entity_id, id)
	world.combat.apply_damage(owner, target, &"physical", mult, StringName(SOURCE_PREFIX + String(id)))
	if id == GUARA and is_instance_valid(target) and not target.is_dead():
		world.progression.statuses.add(target, StatusEffects.Kind.SLOW, 2.0, 0.2, &"bow_companion_guara_bite", owner)
	return true

func use_active(session: PlayerSession, skill: StringName, target: int) -> void:
	var me: NetEntity = session.entity
	var statuses: StatusEffects = world.progression.statuses
	var ids: Array = []
	var duration: float = 0
	var gathering: bool = false
	match skill:
		&"bow_companion_sky_eye":
			duration = 8
			for entity: NetEntity in world._entities.values():
				if entity.instance_id == me.instance_id and not entity.is_dead() \
						and me.flat_distance_to(entity.net_position) <= 12 * Balance.cfg.cell_size:
					var brain: MonsterBrain = world.combat.get_brain(entity) if entity.is_monster() else null
					if statuses.is_hidden(entity) or (brain != null and brain.rare):
						ids.append(entity.entity_id)
			_reveal[session.peer_id] = {"ids": ids, "end": Time.get_ticks_msec() + 8000, "crit": true}
		&"bow_companion_guara_track":
			duration = 15
			ids.append(target)
			_reveal[session.peer_id] = {"ids": ids, "end": Time.get_ticks_msec() + 15000}
			gathering = not world.progression.bridge.is_in_combat(session.peer_id)
		&"arcane_companion_lume_guide":
			duration = 20
			gathering = true
	NetFollowers.push_reveal(session.peer_id, ids, duration, gathering)

func pre_hit(owner: NetEntity, source: StringName, mods: Dictionary, atk: Dictionary, dfn: Dictionary) -> void:
	if source == StringName(SOURCE_PREFIX + String(HARPY)):
		dfn[&"def"] = roundi(float(dfn.get(&"def", 0)) * 0.5)
	if not owner.is_player() or String(source).begins_with(SOURCE_PREFIX):
		return
	var reveal: Dictionary = _reveal.get(owner.get_peer_id(), {})
	if bool(reveal.get("crit", false)) and Time.get_ticks_msec() < int(reveal.end):
		reveal["crit"] = false
		mods["crit_override"] = minf(1.0, maxf(float(mods.get("crit_override", -1)), DamageFormula.crit_chance(int(atk.get(&"luk", 0)))) + 0.1)

func reveals(owner: NetEntity, target: NetEntity) -> bool:
	var state: Dictionary = _reveal.get(owner.get_peer_id(), {})
	return owner.instance_id == target.instance_id and Time.get_ticks_msec() < int(state.get("end", 0)) \
			and target.entity_id in state.get("ids", [])

func snapshot(session: PlayerSession) -> Dictionary:
	var c: CharacterData = session.character
	var pending: Dictionary = _pending.get(session.peer_id, {})
	return {"owned": Array(c.companions_owned), "active": String(c.companion_active),
			"names": c.companion_names.duplicate(), "casting_ms": maxi(0, int(pending.get("end", 0)) - Time.get_ticks_msec()),
			"swap_ms": maxi(0, int(_swap_ready.get(session.peer_id, 0)) - Time.get_ticks_msec())}

func forget(peer: int) -> void:
	_pending.erase(peer)
	_swap_ready.erase(peer)
	_proc_ready.erase(peer)
	_reveal.erase(peer)
