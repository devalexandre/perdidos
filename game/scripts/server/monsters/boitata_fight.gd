class_name BoitataFight
extends RefCounted
## Luta do Boitatá Atroz (GDD §10.4 + ARCO-1-TERRA-DE-PINDORAMA.md §3, final). Ligada pelo comportamento
## &"boitata_phases" no MonsterStage; o MonsterBrain chama tick() a cada tick e reset()/on_death().
## Fases pela vida que resta (nunca voltam, só quando ele volta para casa e recupera a vida):
##  1 (100–60%): mordida (o golpe normal) e Sopro de Fogo em cone, com aviso no chão 1 s antes;
##  2 (60–30%):  +3 fogos-fátuos (boitata_wisp) que perseguem e deixam rastro de fogo no chão;
##  3 (30–10%):  mais rápido (passo e golpe) e Anéis de Fogo que fecham partes da câmara (aviso de 1,5 s);
##  4 (< 10%):   chama negra: dano ×1,5 e aparência appearance["black_flame"] (aura negra no cliente).
## Habilidades: SkillDef em data/monster_skills/ (o cliente toca o efeito e o aviso pelo NetProgress.skill_cast).

const BEHAVIOR: StringName = &"boitata_phases"
const PHASE_2_AT: float = 0.6
const PHASE_3_AT: float = 0.3
const PHASE_4_AT: float = 0.1
const BREATH: StringName = &"boitata_breath"
const TRAIL: StringName = &"boitata_fire_trail"
const RING: StringName = &"boitata_fire_ring"
const WISP_ID: StringName = &"boitata_wisp"
const WISP_COUNT: int = 3
const BREATH_EVERY_SEC: float = 7.0
const TRAIL_EVERY_SEC: float = 2.0
const RING_EVERY_SEC: float = 9.0
const RINGS_PER_CAST: int = 2
## Anéis caem perto do Boitatá (células) e, um deles, embaixo de um jogador da luta.
const RING_SPREAD_CELLS: float = 8.0
const P3_STEP_FACTOR: float = 0.7
const P3_ATTACK_FACTOR: float = 0.75
const P4_DAMAGE: float = 1.5
const APPEARANCE_BLACK_FLAME: StringName = &"black_flame"
const MSG_PHASE: Array[String] = ["", "", "SYS_BOITATA_PHASE_2", "SYS_BOITATA_PHASE_3", "SYS_BOITATA_PHASE_4"]
const MSEC: float = 1000.0

var brain: MonsterBrain = null
var phase: int = 1
var wisps: Array[int] = []
var _next_breath: int = 0
var _next_trail: int = 0
var _next_ring: int = 0
## Golpes com aviso esperando a hora: {"at": msec, "kind": skill, "origin", "point", "dir"}.
var _pending: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


static func wants(stage: MonsterStage) -> bool:
	return stage != null and BEHAVIOR in stage.behaviors


## Fase pela fração da vida (1..4).
static func phase_for(ratio: float) -> int:
	if ratio <= PHASE_4_AT:
		return 4
	if ratio <= PHASE_3_AT:
		return 3
	if ratio <= PHASE_2_AT:
		return 2
	return 1


func _init(p_brain: MonsterBrain) -> void:
	brain = p_brain
	_rng.randomize()


func tick() -> void:
	if brain == null or brain.is_dead() or brain.combat == null:
		return
	var now: int = Time.get_ticks_msec()
	var want: int = phase_for(float(brain.hp) / float(brain.max_hp()))
	if want > phase:
		for p: int in range(phase + 1, want + 1):
			_enter(p)
	_resolve_pending(now)
	if brain.state not in [MonsterBrain.State.CHASE, MonsterBrain.State.ATTACK] or brain.target == null:
		return
	if now >= _next_breath:
		_next_breath = now + int(BREATH_EVERY_SEC * MSEC)
		_breath(now)
	if phase >= 2 and now >= _next_trail:
		_next_trail = now + int(TRAIL_EVERY_SEC * MSEC)
		_trails()
	if phase >= 3 and now >= _next_ring:
		_next_ring = now + int(RING_EVERY_SEC * MSEC)
		_rings(now)


## Voltou para casa (vida cheia): a luta recomeça da fase 1.
func reset() -> void:
	_clear_wisps()
	_pending.clear()
	phase = 1
	brain.step_factor = 1.0
	brain.attack_interval_factor = 1.0
	brain.damage_mult = 1.0
	_set_black_flame(false)
	Net.log_line("boitata_phase", {"id": _id(), "phase": 1, "reason": "reset"})


func on_death() -> void:
	_clear_wisps()
	_pending.clear()


func _enter(p: int) -> void:
	phase = p
	match p:
		2:
			_summon_wisps()
		3:
			brain.step_factor = P3_STEP_FACTOR
			brain.attack_interval_factor = P3_ATTACK_FACTOR
			_next_ring = Time.get_ticks_msec() + 1500
		4:
			brain.damage_mult = P4_DAMAGE
			_set_black_flame(true)
	var e: NetEntity = brain.get_entity()
	Net.log_line("boitata_phase", {"id": _id(), "phase": p, "hp": brain.hp, "max_hp": brain.max_hp(),
			"wisps": wisps.size()})
	if e != null and p < MSG_PHASE.size() and not MSG_PHASE[p].is_empty():
		for peer: int in Net.get_instance_peer_ids(e.instance_id):
			Net.push_system_message(peer, MSG_PHASE[p])


func _id() -> int:
	var e: NetEntity = brain.get_entity() if brain != null else null
	return e.entity_id if e != null else 0


# ---------------------------------------------------------------- habilidades

func _cell() -> float:
	return brain.cell_size()


## Sopro de Fogo: cone na direção do alvo; o aviso aparece no chão e o fogo sai 1 s depois.
func _breath(now: int) -> void:
	var def: SkillDef = Content.monster_skill(BREATH)
	var me: NetEntity = brain.get_entity()
	if def == null or me == null or not is_instance_valid(brain.target):
		return
	var d := Vector3(brain.target.net_position.x - me.net_position.x, 0.0, brain.target.net_position.z - me.net_position.z)
	var dir: Vector3 = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	var point: Vector3 = me.net_position + dir * def.radius_cells * _cell() * 0.5
	_cast(def, point, roundi(def.ground_warning_sec * MSEC))
	_pending.append({"at": now + roundi(def.ground_warning_sec * MSEC), "kind": BREATH, "origin": me.net_position,
			"point": point, "dir": dir})


## Rastro de fogo debaixo de cada fogo-fátuo vivo.
func _trails() -> void:
	var def: SkillDef = Content.monster_skill(TRAIL)
	if def == null:
		return
	for id: int in wisps.duplicate():
		var w: NetEntity = brain.combat.world.get_entity(id)
		var wb: MonsterBrain = brain.combat.get_brain(w) if w != null else null
		if wb == null or wb.is_dead():
			wisps.erase(id)
			continue
		_cast(def, w.net_position, 0)
		_zone(def, w.net_position)


## Anéis de Fogo: um embaixo de um jogador da luta, os outros perto do Boitatá; caem depois do aviso.
func _rings(now: int) -> void:
	var def: SkillDef = Content.monster_skill(RING)
	var me: NetEntity = brain.get_entity()
	if def == null or me == null:
		return
	var points: Array[Vector3] = []
	if is_instance_valid(brain.target):
		points.append(brain.target.net_position)
	while points.size() < RINGS_PER_CAST:
		var a: float = _rng.randf_range(0.0, TAU)
		var r: float = _rng.randf_range(2.0, RING_SPREAD_CELLS) * _cell()
		points.append(brain.origin + Vector3(cos(a) * r, 0.0, sin(a) * r))
	for p: Vector3 in points:
		_cast(def, p, roundi(def.ground_warning_sec * MSEC))
		_pending.append({"at": now + roundi(def.ground_warning_sec * MSEC), "kind": RING, "point": p})


func _resolve_pending(now: int) -> void:
	for job: Dictionary in _pending.duplicate():
		if now < int(job["at"]):
			continue
		_pending.erase(job)
		var def: SkillDef = Content.monster_skill(job["kind"])
		if def == null:
			continue
		if job["kind"] == BREATH:
			_hit_cone(def, job["origin"], job["point"], job["dir"])
		else:
			_zone(def, job["point"])


func _hit_cone(def: SkillDef, origin: Vector3, point: Vector3, dir: Vector3) -> int:
	var me: NetEntity = brain.get_entity()
	var n: int = 0
	for s: PlayerSession in brain.combat.world.get_sessions():
		var p: NetEntity = s.entity
		if p == null or p.instance_id != me.instance_id or not brain.combat.is_valid_victim(brain, p):
			continue
		if SkillCaster.in_shape(def, origin, point, dir, p.net_position, _cell()):
			brain.combat.deal_damage(me, p, CombatService.KIND_MAGIC, def.base_multiplier * brain.damage_mult, def.id)
			n += 1
	Net.log_line("boitata_skill", {"id": _id(), "skill": String(def.id), "hits": n, "phase": phase})
	return n


## Fogo no chão (rastro ou anel): zona de dano do StatusEffects (só atinge quem o Boitatá pode atacar).
func _zone(def: SkillDef, center: Vector3) -> void:
	var prog: Progression = brain.combat.world.progression
	if prog == null:
		return
	prog.statuses.add_ground_zone(brain.get_entity(), center, def.radius_cells * _cell(), def.duration_sec,
			def.base_multiplier * brain.damage_mult, CombatService.KIND_MAGIC, def.id)
	Net.log_line("boitata_skill", {"id": _id(), "skill": String(def.id), "pos": str(center.snappedf(0.1)),
			"phase": phase})


func _cast(def: SkillDef, point: Vector3, delay_ms: int) -> void:
	var me: NetEntity = brain.get_entity()
	var target_id: int = brain.target.entity_id if is_instance_valid(brain.target) else 0
	NetProgress.push_skill_cast(Net.get_instance_peer_ids(me.instance_id), me.entity_id, def.id, target_id,
			point, delay_ms)


# ---------------------------------------------------------------- fogos-fátuos e chama negra

func _summon_wisps() -> void:
	var def: MonsterDef = Content.monster(WISP_ID)
	var spawner: MonsterSpawner = brain.combat.spawner
	var me: NetEntity = brain.get_entity()
	var grid: WalkGrid = brain.combat.world.get_grid_for_instance(me.instance_id)
	if def == null or spawner == null or grid == null:
		return
	for i: int in WISP_COUNT:
		var a: float = TAU * float(i) / float(WISP_COUNT)
		var c: Vector2i = grid.nearest_walkable(grid.world_to_cell(me.net_position + Vector3(cos(a), 0.0, sin(a)) * 3.0 * _cell()),
				CombatRules.SPAWN_SNAP_CELLS)
		if c.x < 0:
			continue
		var w: NetEntity = spawner.spawn(me.instance_id, def, def.stages[0], grid.cell_to_world(c), brain.roam_radius_cells)
		if w == null:
			continue
		var wb: MonsterBrain = brain.combat.get_brain(w)
		wb.boss_entity_id = me.entity_id
		wb.origin = brain.origin
		wisps.append(w.entity_id)
		var victim: NetEntity = brain.target
		if is_instance_valid(victim) and brain.combat.is_valid_victim(wb, victim):
			wb._engage(victim)


func _clear_wisps() -> void:
	if brain == null or brain.combat == null:
		wisps.clear()
		return
	for id: int in wisps:
		var w: NetEntity = brain.combat.world.get_entity(id)
		if w != null and is_instance_valid(w) and not w.is_queued_for_deletion():
			brain.combat.world.despawn_entity(w)
	wisps.clear()


func _set_black_flame(on: bool) -> void:
	var e: NetEntity = brain.get_entity()
	if e == null:
		return
	var app: Dictionary = e.appearance.duplicate()
	if on:
		app[APPEARANCE_BLACK_FLAME] = true
	else:
		app.erase(APPEARANCE_BLACK_FLAME)
	e.appearance = app
