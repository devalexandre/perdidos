class_name CompanionService
extends RefCounted
## Companheiros de título (PETS-E-MONTARIAS.md §2 e §0.1). Desde 08/10/2026 eles lutam:
##  - ataque automático no alvo atual do dono (o do ataque básico ou o último que ele acertou), só em
##    combate, com intervalo e alcance por espécie (CompanionDef); a Lume não ataca, só usa magias;
##  - magias automáticas (data/companion_skills/) com recarga própria, liberadas nos níveis
##    Balance.companion_spell_levels (1 / 10 / 25);
##  - dano = poder do bicho (base + nível + fração do atributo do dono) pelo pipeline normal
##    (CombatService.deal_damage) com o DONO como atacante: o aggro, o crédito e o drop são do dono;
##    o bicho não é entidade, então não pode ser alvo nem levar dano;
##  - crítico = 1% + 0,3% × SOR do dono + 0,1% × nível do bicho (dano crítico = CombatRules);
##  - nível 1–50 com XP bônus (+20% do XP do monstro, sem tirar do dono), salvo por companheiro.
## As skills de vínculo continuam: Garra do Alto e Mordida do Guará agora ADIANTAM o próximo golpe
## automático (não criam um golpe extra por cima dele; ver bond_strike).

const HARPY: StringName = &"pindorama_companion_harpy"
const GUARA: StringName = &"pindorama_companion_guara"
const LUME: StringName = &"pindorama_companion_lume"
const SOURCE_PREFIX: String = "companion_"
## Fonte do dano: companion_<id> (golpe), companion_<id>:<magia> ou companion_<id>:bond (vínculo).
const SOURCE_SEPARATOR: String = ":"
const TAG_BOND: String = "bond"
const BOND_HARPY: StringName = &"bow_companion_hawk_strike"
const BOND_GUARA: StringName = &"bow_companion_guara_bite"
const MSG_LEVEL_UP: String = "COMPANION_LEVEL_UP"
const MSG_EVOLVED: String = "COMPANION_EVOLVED"
## Folga (células) no alcance, como no ataque básico.
const RANGE_SLACK_CELLS: float = 0.5
var world: ServerWorld
var rng := RandomNumberGenerator.new()
var _pending: Dictionary[int, Dictionary] = {}
var _swap_ready: Dictionary[int, int] = {}
var _proc_ready: Dictionary[int, int] = {}
var _reveal: Dictionary[int, Dictionary] = {}
## Combate do bicho, por dono: próximo golpe, último golpe, recarga de cada magia, último alvo do dono.
var _next_attack: Dictionary[int, int] = {}
var _last_attack: Dictionary[int, int] = {}
var _spell_ready: Dictionary[int, Dictionary] = {}
var _last_target: Dictionary[int, Dictionary] = {}

func _init(p_world: ServerWorld) -> void:
	world = p_world
	rng.randomize()

static func harpy_chance(dexterity: int) -> float:
	return minf(0.20, 0.04 + maxi(0, dexterity) * 0.002)


# ================================================================ fórmulas (puras, testadas)

static func source_for(id: StringName, tag: String = "") -> StringName:
	return StringName(SOURCE_PREFIX + String(id) + (SOURCE_SEPARATOR + tag if not tag.is_empty() else ""))


## {"id": StringName, "tag": String} de uma fonte companion_*; {} se não for de companheiro.
static func parse_source(source: StringName) -> Dictionary:
	var text: String = String(source)
	if not text.begins_with(SOURCE_PREFIX):
		return {}
	var rest: String = text.substr(SOURCE_PREFIX.length())
	var parts: PackedStringArray = rest.split(SOURCE_SEPARATOR, true, 1)
	return {"id": StringName(parts[0]), "tag": parts[1] if parts.size() > 1 else ""}


## XP para o próximo nível do companheiro (0 no nível máximo).
static func xp_to_next(level: int) -> int:
	if level >= Balance.cfg.companion_max_level:
		return 0
	return maxi(1, floori(Balance.cfg.companion_xp_curve_base * pow(maxi(1, level), Balance.cfg.companion_xp_curve_exponent)))


## Crítico do companheiro: 1% + 0,3% × SOR do dono + 0,1% × nível do bicho.
static func crit_chance(owner_luk: int, level: int) -> float:
	var b: BalanceConfig = Balance.cfg
	return clampf(b.companion_crit_base + maxi(0, owner_luk) * b.companion_crit_per_luk
			+ maxi(1, level) * b.companion_crit_per_level, 0.0, 1.0)


## Poder (ATK ou ATQM) do bicho: base + por nível + fração do atributo do dono ligado ao título.
static func power(def: CompanionDef, level: int, owner_stats: Dictionary) -> int:
	if def == null:
		return 0
	var attr: float = float(owner_stats.get(def.owner_attribute, owner_stats.get(String(def.owner_attribute), 0)))
	return maxi(1, roundi(def.power_base + def.power_per_level * maxi(1, level) + def.attribute_frac * attr))


## Magias liberadas no nível (na ordem da CompanionDef.spells).
static func unlocked_spells(def: CompanionDef, level: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if def == null:
		return out
	var gates: Array[int] = Balance.cfg.companion_spell_levels
	for i: int in def.spells.size():
		if i < gates.size() and level >= gates[i]:
			out.append(def.spells[i])
	return out


## Estágio de evolução visual (marcos alcançados: 0 a 3).
static func evolution_stage(level: int) -> int:
	var n: int = 0
	for m: int in Balance.cfg.companion_milestones:
		if level >= m:
			n += 1
	return n


## Escala do bicho no cliente (só cosmético): cresce um pouco a cada marco.
static func visual_scale_for(def: CompanionDef, level: int) -> float:
	return def.visual_scale * (1.0 + Balance.cfg.companion_evolve_scale_step * evolution_stage(level))


## Soma XP numa entrada {"level", "xp"}. Devolve os níveis ganhos.
static func add_xp_to(entry: Dictionary, amount: int) -> int:
	var level: int = int(entry.get("level", 1))
	var xp: int = int(entry.get("xp", 0)) + maxi(0, amount)
	var gained: int = 0
	while level < Balance.cfg.companion_max_level and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	if level >= Balance.cfg.companion_max_level:
		xp = 0
	entry["level"] = level
	entry["xp"] = xp
	return gained


## Dano por segundo esperado do bicho (sem defesa nem esquiva), para o teste de equilíbrio. Simula
## `seconds` de luta com o mesmo relógio do tick: golpe automático, magias com recarga e, para a harpia,
## a Garra do Alto adiantando o golpe (owner_aps = ataques básicos por segundo do dono, com arco).
static func simulate_dps(def: CompanionDef, level: int, owner_stats: Dictionary, owner_aps: float,
		seconds: float, p_rng: RandomNumberGenerator) -> float:
	var p: float = power(def, level, owner_stats)
	var crit: float = crit_chance(int(owner_stats.get(&"luk", 0)), level)
	var crit_gain: float = 1.0 + crit * (CombatRules.CRIT_MULTIPLIER - 1.0)
	var step_ms: int = 50
	var total_ms: int = roundi(seconds * 1000.0)
	var next_attack: int = 0
	var last_attack: int = -1000000
	var next_owner: int = 0
	var proc_ready: int = 0
	var ready: Dictionary = {}
	var damage: float = 0.0
	var spells: Array[StringName] = unlocked_spells(def, level)
	var interval_ms: int = roundi(def.attack_interval_sec * 1000.0)
	for now: int in range(0, total_ms, step_ms):
		# Garra do Alto: o ataque básico do dono pode adiantar o mergulho.
		if def.id == HARPY and owner_aps > 0.0 and now >= next_owner:
			next_owner = now + roundi(1000.0 / owner_aps)
			if now >= proc_ready and now - last_attack >= roundi(interval_ms * Balance.cfg.companion_bond_min_gap) \
					and p_rng.randf() < harpy_chance(int(owner_stats.get(&"dex", 0))):
				proc_ready = now + 1500
				damage += p * def.attack_mult
				last_attack = now
				next_attack = now + interval_ms
				continue
		var cast: bool = false
		for id: StringName in spells:
			var sd: SkillDef = Content.companion_skill(id)
			if sd == null or now < int(ready.get(id, 0)) or sd.effect == SkillDef.Effect.HEAL:
				continue
			ready[id] = now + roundi(sd.cooldown_sec * 1000.0)
			damage += p * sd.base_multiplier
			cast = true
			break
		if cast:
			continue
		if interval_ms > 0 and now >= next_attack:
			damage += p * def.attack_mult
			last_attack = now
			next_attack = now + interval_ms
	return damage * crit_gain / maxf(0.001, seconds)

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
	if world.combat != null:
		_tick_combat(now)


## Golpe do dono (CombatService.deal_damage): guarda o alvo atual e aciona as passivas de vínculo.
## Garra do Alto (harpia, ataque básico com arco, chance pela DES) e Mordida do Guará (Tocaia ou
## Armadilha de Cipó) ADIANTAM o próximo golpe automático do bicho (bond_strike), com recarga interna.
func on_hit(owner: NetEntity, target: NetEntity, source: StringName, amount: int, now: int = -1) -> bool:
	if not owner.is_player() or String(source).begins_with(SOURCE_PREFIX) \
			or target == null or target == owner or target.is_dead() or target.is_queued_for_deletion():
		return false
	if now < 0:
		now = Time.get_ticks_msec()
	_last_target[owner.get_peer_id()] = {"id": target.entity_id, "at": now}
	if amount <= 0:
		return false
	var session: PlayerSession = world.get_session(owner.get_peer_id())
	if session == null or session.character.hp <= 0:
		return false
	if now < int(_proc_ready.get(session.peer_id, 0)):
		return false
	var id: StringName = session.character.companion_active
	var def: CompanionDef = Content.companion(id)
	if def == null:
		return false
	var cooldown: int = 0
	if id == HARPY and source == CombatService.SOURCE_BASIC_ATTACK \
			and SkillCaster.has_weapon_kind(session, ItemDef.WeaponKind.BOW) \
			and session.character.progression.knows(BOND_HARPY):
		var dex: int = int(session.character.compute_stats().get(&"dex", 0))
		if rng.randf() >= harpy_chance(dex):
			return false
		cooldown = 1500
	elif id == GUARA and source in [&"bow_ambush_shot", &"bow_vine_snare"] \
			and session.character.progression.knows(BOND_GUARA):
		cooldown = 4000
	else:
		return false
	# Sem golpe duplo: só adianta se já passou parte do intervalo desde o último golpe do bicho.
	var gap: int = roundi(def.attack_interval_sec * 1000.0 * Balance.cfg.companion_bond_min_gap)
	if now - int(_last_attack.get(session.peer_id, -1000000)) < gap:
		return false
	_proc_ready[session.peer_id] = now + cooldown
	var hit: Dictionary = bond_strike(session, def, target, now)
	if id == GUARA and bool(hit.get("ok", false)) and is_instance_valid(target) and not target.is_dead():
		world.progression.statuses.add(target, StatusEffects.Kind.SLOW, 2.0, 0.2, BOND_GUARA, owner)
	return bool(hit.get("ok", false))


## Golpe de vínculo: é o golpe automático, adiantado agora (o relógio do golpe recomeça).
func bond_strike(session: PlayerSession, def: CompanionDef, target: NetEntity, now: int) -> Dictionary:
	return _strike(session, def, target, now, TAG_BOND)


# ================================================================ combate automático

## Nível do companheiro (1 se nunca ganhou XP).
func level_of(c: CharacterData, id: StringName) -> int:
	var entry: Variant = c.companion_progress.get(String(id), {})
	return int((entry as Dictionary).get("level", 1)) if entry is Dictionary else 1


func _entry(c: CharacterData, id: StringName) -> Dictionary:
	var key: String = String(id)
	if not c.companion_progress.get(key, null) is Dictionary:
		c.companion_progress[key] = {"level": 1, "xp": 0}
	return c.companion_progress[key]


## Alvo do bicho agora: o do ataque básico do dono ou o último que ele acertou, só em combate,
## atacável e ao alcance (alcance do golpe + quanto o bicho se afasta do dono). null = só segue.
func current_target(session: PlayerSession, def: CompanionDef, reach_cells: float, now: int) -> NetEntity:
	var combat: CombatService = world.combat
	if combat == null or not combat.is_in_combat(session.peer_id):
		return null
	var target: NetEntity = null
	var pc: CombatService.PlayerCombat = combat._players.get(session.peer_id)
	if pc != null and pc.target != null and is_instance_valid(pc.target):
		target = pc.target
	else:
		var last: Dictionary = _last_target.get(session.peer_id, {})
		if not last.is_empty() and now - int(last.at) < roundi(Balance.cfg.out_of_combat_sec * 1000.0):
			target = world.get_entity(int(last.id))
	if target == null or not can_strike(session.entity, target):
		return null
	var cell: float = Balance.cfg.cell_size
	if session.entity.flat_distance_to(target.net_position) > (reach_cells + def.chase_cells + RANGE_SLACK_CELLS) * cell:
		return null
	return target


func _tick_combat(now: int) -> void:
	for session: PlayerSession in world.get_sessions():
		var def: CompanionDef = Content.companion(session.character.companion_active)
		if def == null or session.character.hp <= 0 or session.entity == null:
			continue
		var level: int = level_of(session.character, def.id)
		if _try_spell(session, def, level, now):
			continue
		if def.attack_interval_sec <= 0.0 or now < int(_next_attack.get(session.peer_id, 0)):
			continue
		var target: NetEntity = current_target(session, def, def.attack_range_cells, now)
		if target != null:
			_strike(session, def, target, now)


## O bicho pode bater no alvo pelo dono? As regras do ataque (instância, zona, hostil, vivos...), menos
## a munição: o bicho não gasta as flechas do dono.
func can_strike(owner: NetEntity, target: NetEntity) -> bool:
	if world.combat == null:
		return false
	var why: String = world.combat.attack_block_reason(owner, target)
	return why.is_empty() or why == "attack_no_ammo"


## Golpe automático (ou de vínculo, tag "bond"). {} se não pôde.
func _strike(session: PlayerSession, def: CompanionDef, target: NetEntity, now: int, tag: String = "") -> Dictionary:
	var owner: NetEntity = session.entity
	if world.combat == null or not can_strike(owner, target):
		return {}
	_next_attack[session.peer_id] = now + roundi(def.attack_interval_sec * 1000.0)
	_last_attack[session.peer_id] = now
	NetFollowers.push_strike(Net.get_instance_peer_ids(owner.instance_id), owner.entity_id, target.entity_id,
			def.id, &"", 1)
	var kind: StringName = CombatService.KIND_MAGIC if def.damage_kind == CombatService.KIND_MAGIC else CombatService.KIND_PHYSICAL
	return world.combat.deal_damage(owner, target, kind, def.attack_mult, source_for(def.id, tag))


## Primeira magia liberada, pronta e com alvo válido. true = lançou (uma ação por tique).
func _try_spell(session: PlayerSession, def: CompanionDef, level: int, now: int) -> bool:
	var ready: Dictionary = _spell_ready.get(session.peer_id, {})
	for id: StringName in unlocked_spells(def, level):
		var sd: SkillDef = Content.companion_skill(id)
		if sd == null or now < int(ready.get(id, 0)):
			continue
		if sd.effect == SkillDef.Effect.HEAL:
			var max_hp: int = int(session.character.compute_stats().get(CharacterStats.K_MAX_HP, 1))
			if world.combat == null or not world.combat.is_in_combat(session.peer_id) \
					or float(session.character.hp) / maxf(1.0, max_hp) >= Balance.cfg.companion_heal_below_hp:
				continue
			ready[id] = now + roundi(sd.cooldown_sec * 1000.0)
			_spell_ready[session.peer_id] = ready
			cast_spell(session, def, level, sd, null)
			return true
		var target: NetEntity = current_target(session, def, sd.range_cells, now)
		if target == null:
			continue
		ready[id] = now + roundi(sd.cooldown_sec * 1000.0)
		_spell_ready[session.peer_id] = ready
		cast_spell(session, def, level, sd, target)
		return true
	return false


## Aplica a magia do bicho (dano, enfraquecimento, lentidão, atordoamento ou cura no dono).
func cast_spell(session: PlayerSession, def: CompanionDef, level: int, sd: SkillDef, target: NetEntity) -> int:
	var owner: NetEntity = session.entity
	var peers: Array[int] = Net.get_instance_peer_ids(owner.instance_id)
	if sd.effect == SkillDef.Effect.HEAL:
		var amount: int = roundi(power(def, level, session.character.compute_stats()) * sd.base_multiplier)
		NetFollowers.push_strike(peers, owner.entity_id, owner.entity_id, def.id, sd.id, 0)
		return world.combat.heal(owner, amount, owner)
	var targets: Array[NetEntity] = [target]
	if sd.target_type == SkillDef.TargetType.GROUND_AREA and sd.radius_cells > 0.0:
		targets = []
		for m: NetEntity in world.combat.monsters_in_radius(owner.instance_id, target.net_position, sd.radius_cells * Balance.cfg.cell_size):
			if can_strike(owner, m):
				targets.append(m)
		if target not in targets:
			targets.append(target)
	var hits: int = targets.size() if sd.base_multiplier > 0.0 else 0
	NetFollowers.push_strike(peers, owner.entity_id, target.entity_id, def.id, sd.id, hits)
	var statuses: StatusEffects = world.progression.statuses
	var kind: StringName = CombatService.KIND_MAGIC if sd.effect == SkillDef.Effect.MAGIC_DAMAGE else CombatService.KIND_PHYSICAL
	var done: int = 0
	for t: NetEntity in targets:
		if not is_instance_valid(t) or t.is_dead():
			continue
		var killed: bool = false
		if sd.base_multiplier > 0.0:
			var r: Dictionary = world.combat.deal_damage(owner, t, kind, sd.base_multiplier, source_for(def.id, String(sd.id)))
			killed = bool(r.get("killed", false))
			done += int(r.get("amount", 0))
		if killed or not is_instance_valid(t) or t.is_dead():
			continue
		match sd.effect:
			SkillDef.Effect.SLOW:
				statuses.add(t, StatusEffects.Kind.SLOW, sd.duration_sec, float(sd.extra.get(&"slow_pct", 0.3)), sd.id, owner)
			SkillDef.Effect.DEBUFF:
				var mods: Dictionary = {}
				for k: StringName in sd.extra:
					if k in StatusEffects.MOD_KEYS:
						mods[k] = sd.extra[k]
				statuses.add(t, StatusEffects.Kind.DEBUFF, sd.duration_sec, 0.0, sd.id, owner, &"", mods)
		if float(sd.extra.get(&"stun_sec", 0.0)) > 0.0:
			statuses.add(t, StatusEffects.Kind.STUN, float(sd.extra[&"stun_sec"]), 0.0, sd.id, owner)
	if sd.effect == SkillDef.Effect.SLOW:
		world.combat.mark_combat(session.peer_id)
	Net.log_line("companion_spell", {"peer": session.peer_id, "companion": String(def.id), "spell": String(sd.id),
			"targets": targets.size(), "damage": done, "level": level})
	return done


# ================================================================ nível e XP

## XP bônus do abate: Balance.companion_xp_share do XP do monstro, só para o companheiro ativo (o dono
## recebe o XP dele inteiro à parte). Devolve a XP dada.
func grant_kill_xp(session: PlayerSession, monster_xp: int) -> int:
	var id: StringName = session.character.companion_active
	if Content.companion(id) == null or session.character.hp <= 0 or monster_xp <= 0:
		return 0
	var amount: int = maxi(1, roundi(monster_xp * Balance.cfg.companion_xp_share))
	return grant_xp(session, id, amount)


func grant_xp(session: PlayerSession, id: StringName, amount: int) -> int:
	var entry: Dictionary = _entry(session.character, id)
	var before: int = int(entry.level)
	var before_stage: int = evolution_stage(before)
	if before >= Balance.cfg.companion_max_level:
		return 0
	var gained: int = add_xp_to(entry, amount)
	if gained > 0:
		var level: int = int(entry.level)
		var label: String = str(session.character.companion_names.get(String(id), ""))
		var def: CompanionDef = Content.companion(id)
		var args: Array = [label if not label.is_empty() else def.name_key, level]
		Net.push_system_message(session.peer_id, MSG_LEVEL_UP, args)
		if evolution_stage(level) > before_stage:
			Net.push_system_message(session.peer_id, MSG_EVOLVED, args)
		Net.log_line("companion_level_up", {"peer": session.peer_id, "companion": String(id), "level": level})
		world.refresh_appearance(session)
	world.progression.mark_dirty(session)
	return amount

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
			if target > 0:
				ids.append(target)
			_reveal[session.peer_id] = {"ids": ids, "end": Time.get_ticks_msec() + 15000}
			gathering = not world.progression.bridge.is_in_combat(session.peer_id)
		&"arcane_companion_lume_guide":
			duration = 20
			gathering = true
	NetFollowers.push_reveal(session.peer_id, ids, duration, gathering)

## Antes do golpe (CombatService.deal_damage, depois do StatusEffects). Golpe do bicho: troca o ATK/ATQM
## do dono pelo poder do bicho, põe o crítico do bicho (físico e mágico), ignora parte da DEF (mergulho
## da harpia, Mergulho Real) e corta o dano pela metade na zona PVP.
func pre_hit(owner: NetEntity, source: StringName, mods: Dictionary, atk: Dictionary, dfn: Dictionary) -> void:
	var parsed: Dictionary = parse_source(source)
	if not parsed.is_empty():
		var def: CompanionDef = Content.companion(parsed.id)
		var session: PlayerSession = world.get_session(owner.get_peer_id()) if owner.is_player() else null
		if def == null or session == null:
			return
		var level: int = level_of(session.character, def.id)
		var stats: Dictionary = session.character.compute_stats()
		var p: int = power(def, level, stats)
		atk[&"atk"] = p
		atk[&"matk"] = p
		atk[CharacterStats.K_HOLY_MATK] = p
		var crit: float = crit_chance(int(stats.get(&"luk", 0)), level)
		mods["crit_override"] = crit
		mods["magic_crit"] = crit
		var ignore: float = def.def_ignore
		var sd: SkillDef = Content.companion_skill(StringName(String(parsed.tag)))
		if sd != null:
			ignore = maxf(ignore, float(sd.extra.get(&"def_ignore", 0.0)))
		if ignore > 0.0:
			dfn[&"def"] = roundi(float(dfn.get(&"def", 0)) * (1.0 - clampf(ignore, 0.0, 1.0)))
		mods["dmg_mult"] = float(mods.get("dmg_mult", 1.0)) * pvp_multiplier(owner.instance_id)
		return
	if not owner.is_player():
		return
	var reveal: Dictionary = _reveal.get(owner.get_peer_id(), {})
	if bool(reveal.get("crit", false)) and Time.get_ticks_msec() < int(reveal.end):
		reveal["crit"] = false
		mods["crit_override"] = minf(1.0, maxf(float(mods.get("crit_override", -1)), DamageFormula.crit_chance(int(atk.get(&"luk", 0)))) + 0.1)


## Multiplicador do dano do bicho na instância (Arena da Queimada = PVP: metade).
func pvp_multiplier(instance_id: StringName) -> float:
	var zone: ZoneDef = Content.zone(Progression.map_of(instance_id))
	return Balance.cfg.companion_pvp_damage_mult if zone != null and zone.kind == ZoneDef.Kind.PVP else 1.0

func reveals(owner: NetEntity, target: NetEntity) -> bool:
	var state: Dictionary = _reveal.get(owner.get_peer_id(), {})
	return owner.instance_id == target.instance_id and Time.get_ticks_msec() < int(state.get("end", 0)) \
			and target.entity_id in state.get("ids", [])

func snapshot(session: PlayerSession) -> Dictionary:
	var c: CharacterData = session.character
	var pending: Dictionary = _pending.get(session.peer_id, {})
	return {"owned": Array(c.companions_owned), "active": String(c.companion_active),
			"names": c.companion_names.duplicate(), "casting_ms": maxi(0, int(pending.get("end", 0)) - Time.get_ticks_msec()),
			"swap_ms": maxi(0, int(_swap_ready.get(session.peer_id, 0)) - Time.get_ticks_msec()),
			"progress": progress_snapshot(c)}


## Nível, XP e magias de cada companheiro do personagem (janela de Seguidores e medidor do retrato).
func progress_snapshot(c: CharacterData) -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in c.companions_owned:
		var def: CompanionDef = Content.companion(id)
		if def == null:
			continue
		var level: int = level_of(c, id)
		var entry: Variant = c.companion_progress.get(String(id), {})
		var spells: Array = []
		for spell: StringName in unlocked_spells(def, level):
			spells.append(String(spell))
		out[String(id)] = {"level": level, "xp": int((entry as Dictionary).get("xp", 0)) if entry is Dictionary else 0,
				"xp_next": xp_to_next(level), "max_level": Balance.cfg.companion_max_level,
				"stage": evolution_stage(level), "spells": spells}
	return out

func forget(peer: int) -> void:
	_pending.erase(peer)
	_swap_ready.erase(peer)
	_proc_ready.erase(peer)
	_reveal.erase(peer)
	_next_attack.erase(peer)
	_last_attack.erase(peer)
	_spell_ready.erase(peer)
	_last_target.erase(peer)
