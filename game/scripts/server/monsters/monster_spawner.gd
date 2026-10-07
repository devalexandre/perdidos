class_name MonsterSpawner
extends RefCounted
## Nascimento dos monstros (contrato arrival, "Entidades"): nó Spawns/ do mapa com Marker3D e metas
##   monster_id (id do MonsterDef), count, radius_cells, respawn_sec (opcional; senão o do MonsterDef).
## Cada instância nasce os seus quando a grade do mapa fica pronta. Cada "vaga" (marcador × índice)
## renasce no seu estágio (1 normal, 2 médio, limitado pelo teto da zona) depois do respawn_sec quando o
## monstro dela morre (GDD §10.3).
## Chefes fixos (GDD §10.6.1, decisão do dono de 30/09/2026 — sem evolução e sem chefe por contagem de abates):
## cada Marker3D em BossLairs/ do mapa é o covil de UM chefe (meta monster_id; radius_cells; respawn_sec opcional,
## padrão Balance.cfg.boss_respawn_sec = 10 min). O chefe (estágio 3) nasce ali com o bando fixo (normais e médios
## da espécie em volta, Balance.cfg.boss_escort_*). Ao renascer, o bando que sobrou volta a segui-lo e só os que
## faltam nascem. Só em zonas com bosses_allowed e teto 3 (nunca no Campo de Treino). Covis são independentes.
## Forma atroz (chefe à noite): MonsterBrain.update_atroz; aparência replicada em appearance["atroz"].
## Comandos de teste do dono (chat "/chefe", "/noite"...): MonsterDebug (debug; só com --dev-commands).

const SPAWNS_NODE: String = "Spawns"
## Covis fixos dos chefes (um Marker3D por chefe).
const LAIRS_NODE: String = "BossLairs"
const MSG_LAIR: String = "SYS_BOSS_LAIR_APPEARED"
const META_MONSTER_ID: StringName = &"monster_id"
const META_COUNT: StringName = &"count"
const META_RADIUS: StringName = &"radius_cells"
const META_RESPAWN: StringName = &"respawn_sec"
## Estágio com que o monstro nasce neste marcador (1 normal, 2 médio). Padrão 1.
const META_STAGE: StringName = &"stage"
const DEFAULT_COUNT: int = 1
const SLOT_SEPARATOR: String = "|"
## Agente R (GDD §10.2): variante rara. Replicada em NetEntity.appearance[APPEARANCE_RARE] (só no
## nascimento; o cliente acrescenta o prefixo "Raro", o brilho e as faíscas).
const APPEARANCE_RARE: StringName = &"rare"
const MSG_RARE: String = "SYS_RARE_MONSTER_APPEARED"
## Forma atroz (NetEntity.appearance["atroz"] = true enquanto atroz) e aviso na instância.
const APPEARANCE_ATROZ: StringName = &"atroz"
const MSG_ATROZ: String = "SYS_MONSTER_BECAME_ATROZ"
## Teste: --force-rare=<monster_id>[,<id>...] (ou "all") faz as vagas dessas espécies nascerem raras.
const ARG_FORCE_RARE: String = "--force-rare="
const FORCE_RARE_ALL: String = "all"
## Teste: --drop-chance-mult=<x> multiplica a chance de todos os drops (autotestes determinísticos).
const ARG_DROP_CHANCE_MULT: String = "--drop-chance-mult="

var combat: CombatService = null
var world: ServerWorld = null
var _next_index: int = 0
var _done_instances: Dictionary[StringName, bool] = {}
## slot -> {"instance", "def", "center", "radius", "respawn_sec"}
var _slots: Dictionary[String, Dictionary] = {}
## slot -> msec em que renasce.
var _respawn_at: Dictionary[String, int] = {}
var _rng := RandomNumberGenerator.new()
## Espécies forçadas a nascer raras (--force-rare, só testes).
var _force_rare: PackedStringArray = []
## Covil (vaga de chefe) -> entity_ids do bando dele (reaproveitado quando o chefe renasce).
var _lair_escort: Dictionary[String, Array] = {}
## Comandos de teste (null fora de --dev-commands / --autotest).
var debug: MonsterDebug = null
## Multiplicador de chance de drop só para testes (--drop-chance-mult); 1 = normal.
var test_drop_chance_mult: float = 1.0


func _init(p_combat: CombatService) -> void:
	combat = p_combat
	world = p_combat.world
	_rng.randomize()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(ARG_FORCE_RARE):
			_force_rare = a.trim_prefix(ARG_FORCE_RARE).split(",", false)
		elif a.begins_with(ARG_DROP_CHANCE_MULT) and a.trim_prefix(ARG_DROP_CHANCE_MULT).is_valid_float():
			test_drop_chance_mult = maxf(0.0, a.trim_prefix(ARG_DROP_CHANCE_MULT).to_float())
	if MonsterDebug.enabled(world):
		debug = MonsterDebug.new(self)


func tick() -> void:
	for instance_id: StringName in world.get_instance_ids():
		if _done_instances.has(instance_id):
			continue
		if not world.is_nav_ready(instance_id) or world.get_grid_for_instance(instance_id) == null:
			continue
		_done_instances[instance_id] = true
		_spawn_instance(instance_id)
	if _respawn_at.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	for slot: String in _respawn_at.keys():
		if now < _respawn_at[slot]:
			continue
		_respawn_at.erase(slot)
		_spawn_slot(slot)


func _spawn_instance(instance_id: StringName) -> void:
	var map_node: Node = world.get_map_node(instance_id)
	if map_node == null:
		return
	combat.install_test_spawns(map_node, instance_id)
	var root: Node = map_node.get_node_or_null(SPAWNS_NODE)
	if root == null:
		return
	var total: int = 0
	for m: Node in root.get_children():
		if not (m is Node3D) or not m.has_meta(META_MONSTER_ID):
			continue
		var monster_id := StringName(str(m.get_meta(META_MONSTER_ID)))
		var def: MonsterDef = Content.monster(monster_id)
		if def == null or def.stages.is_empty():
			push_warning("MonsterSpawner: MonsterDef '%s' not found (marker %s)." % [monster_id, m.name])
			Net.log_line("monster_def_missing", {"monster": String(monster_id), "marker": String(m.name),
					"instance": String(instance_id)})
			continue
		var respawn: float = float(m.get_meta(META_RESPAWN, def.respawn_sec))
		var count: int = maxi(1, int(m.get_meta(META_COUNT, DEFAULT_COUNT)))
		var radius: float = float(m.get_meta(META_RADIUS, CombatRules.DEFAULT_ROAM_CELLS))
		# Chefe só no covil (BossLairs/): marcador comum fica no máximo no estágio médio.
		var stage_number: int = clampi(int(m.get_meta(META_STAGE, 1)), 1,
				mini(CombatBridges.monster_stage_cap(world, instance_id), CombatRules.STAGE_MEDIUM))
		for i: int in range(count):
			var slot: String = SLOT_SEPARATOR.join([String(instance_id), String(m.name), str(i)])
			_slots[slot] = {"instance": instance_id, "def": def, "center": (m as Node3D).global_position,
					"radius": radius, "respawn_sec": respawn, "stage": stage_number}
			if _spawn_slot(slot) != null:
				total += 1
	Net.log_line("monsters_spawned", {"instance": String(instance_id), "count": total})
	_install_lairs(instance_id, map_node)


## Covis fixos (BossLairs/): uma vaga de chefe por marcador.
func _install_lairs(instance_id: StringName, map_node: Node) -> void:
	var lairs: Node = map_node.get_node_or_null(LAIRS_NODE)
	if lairs == null or not bosses_allowed(instance_id):
		return
	var n: int = 0
	for m: Node in lairs.get_children():
		if not (m is Marker3D) or not m.has_meta(META_MONSTER_ID):
			continue
		var def: MonsterDef = Content.monster(StringName(str(m.get_meta(META_MONSTER_ID))))
		if def == null or MonsterEvolution.stage_by_number(def, CombatRules.STAGE_BOSS) == null:
			push_warning("MonsterSpawner: lair %s without a boss stage." % m.name)
			Net.log_line("boss_lair_invalid", {"instance": String(instance_id), "lair": String(m.name)})
			continue
		var slot: String = SLOT_SEPARATOR.join([String(instance_id), LAIRS_NODE + "/" + String(m.name), "0"])
		_slots[slot] = {"instance": instance_id, "def": def, "center": (m as Node3D).global_position,
				"radius": float(m.get_meta(META_RADIUS, CombatRules.DEFAULT_ROAM_CELLS)),
				"respawn_sec": float(m.get_meta(META_RESPAWN, Balance.cfg.boss_respawn_sec)),
				"stage": CombatRules.STAGE_BOSS, "lair": String(m.name)}
		if _spawn_slot(slot) != null:
			n += 1
	Net.log_line("boss_lairs_ready", {"instance": String(instance_id), "bosses": n})


## A zona aceita chefe? (bosses_allowed, teto 3; nunca no Campo de Treino)
func bosses_allowed(instance_id: StringName) -> bool:
	return zone_allows_bosses(CombatBridges.zone_for_instance(world, instance_id),
			CombatBridges.monster_stage_cap(world, instance_id))


## Regra pura: covil só vale em zona com bosses_allowed e teto de estágio 3; nunca no Campo de Treino.
static func zone_allows_bosses(zone: ZoneDef, stage_cap: int) -> bool:
	if zone != null and (zone.kind == ZoneDef.Kind.TRAINING or not zone.bosses_allowed):
		return false
	return stage_cap >= CombatRules.STAGE_BOSS


func _spawn_slot(slot: String) -> NetEntity:
	var info: Dictionary = _slots.get(slot, {})
	if info.is_empty():
		return null
	var instance_id: StringName = info["instance"]
	var def: MonsterDef = info["def"]
	var pos: Vector3 = random_point(instance_id, info["center"], float(info["radius"]))
	var stage: MonsterStage = MonsterEvolution.stage_by_number(def, int(info.get("stage", 1)))
	if stage == null:
		stage = def.stages[0]
	var lair: bool = info.has("lair")
	if lair:
		pos = world.snap_to_grid(instance_id, info["center"])
	var e: NetEntity = spawn(instance_id, def, stage, pos, float(info["radius"]),
			false if lair else roll_rare(instance_id, def, pos))
	if e == null:
		return null
	var brain: MonsterBrain = combat.get_brain(e)
	brain.spawn_slot = slot
	if lair:
		var escort: int = _lair_escort_for(slot, brain)
		Net.log_line("boss_lair_spawned", {"id": e.entity_id, "monster": String(def.id),
				"instance": String(instance_id), "lair": info["lair"], "escort": escort, "atroz": brain.atroz,
				"respawn_sec": info["respawn_sec"], "clock": DayNight.clock_text()})
		for p: int in Net.get_instance_peer_ids(instance_id):
			Net.push_system_message(p, MSG_LAIR, [brain.stage.name_key])
	return e


## Bando fixo do covil: quem sobrou da vida anterior volta a seguir o chefe; nascem só os que faltam.
func _lair_escort_for(slot: String, boss: MonsterBrain) -> int:
	var be: NetEntity = boss.get_entity()
	var kept: Array[NetEntity] = []
	var have: Dictionary[int, int] = {}
	for id: Variant in _lair_escort.get(slot, []):
		var m: NetEntity = world.get_entity(int(id))
		var mb: MonsterBrain = combat.get_brain(m) if m != null else null
		if mb == null or mb.is_dead():
			continue
		mb.boss_entity_id = be.entity_id
		mb.origin = boss.origin
		kept.append(m)
		have[mb.stage.stage] = int(have.get(mb.stage.stage, 0)) + 1
	var made: Array[NetEntity] = spawn_escort(boss, have)
	var ids: Array = []
	for m: NetEntity in kept + made:
		ids.append(m.entity_id)
	_lair_escort[slot] = ids
	return ids.size()


## Covis da instância: [{"lair", "monster", "position", "alive": NetEntity|null, "respawn_in_sec"}].
func lairs_of(instance_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: String in _slots:
		var info: Dictionary = _slots[slot]
		if info["instance"] != instance_id or not info.has("lair"):
			continue
		var alive: NetEntity = null
		for m: NetEntity in combat.monsters_in_radius(instance_id, Vector3.ZERO, INF):
			var b: MonsterBrain = combat.get_brain(m)
			if b != null and b.spawn_slot == slot:
				alive = m
		var left: float = maxf(0.0, float(_respawn_at.get(slot, 0) - Time.get_ticks_msec()) / CombatRules.MSEC_PER_SEC) \
				if _respawn_at.has(slot) else 0.0
		out.append({"slot": slot, "lair": info["lair"], "monster": (info["def"] as MonsterDef).id,
				"position": info["center"], "alive": alive, "respawn_in_sec": left})
	return out


## Teste: o chefe do covil renasce já (se não estiver vivo). Devolve o chefe (novo ou o que já estava).
func respawn_lair_now(slot: String) -> NetEntity:
	for l: Dictionary in lairs_of(StringName(String(slot).get_slice(SLOT_SEPARATOR, 0))):
		if l["slot"] == slot and l["alive"] != null:
			return l["alive"]
	_respawn_at.erase(slot)
	return _spawn_slot(slot)


## GDD §10.2: chance de nascer raro = rare_base_chance × MonsterDef.rare_chance_multiplier ×
## (1 + maior SOR entre os jogadores da instância perto do ponto × 0,02).
func rare_chance(instance_id: StringName, def: MonsterDef, pos: Vector3) -> float:
	if def == null or not def.can_be_rare:
		return 0.0
	var luk: int = best_luck_near(instance_id, pos)
	return clampf(Balance.cfg.rare_base_chance * def.rare_chance_multiplier
			* DamageFormula.rare_luck_multiplier(luk), 0.0, 1.0)


func roll_rare(instance_id: StringName, def: MonsterDef, pos: Vector3) -> bool:
	if def == null or not def.can_be_rare:
		return false
	if FORCE_RARE_ALL in _force_rare or String(def.id) in _force_rare:
		return true
	return _rng.randf() < rare_chance(instance_id, def, pos)


## Maior SOR entre os jogadores da instância a até Balance.cfg.rare_luck_range_cells de pos (0 = ninguém).
func best_luck_near(instance_id: StringName, pos: Vector3) -> int:
	var grid: WalkGrid = world.get_grid_for_instance(instance_id)
	var reach: float = Balance.cfg.rare_luck_range_cells * (grid.cell_size if grid != null else Balance.cfg.cell_size)
	var best: int = 0
	for sess: PlayerSession in world.get_sessions():
		if sess.entity == null or sess.entity.instance_id != instance_id \
				or sess.entity.flat_distance_to(pos) > reach:
			continue
		best = maxi(best, int(sess.character.compute_stats().get(&"luk", 0)))
	return best


## Marca a vaga para renascer (monstro dela morreu).
func schedule_respawn(slot: String) -> void:
	var info: Dictionary = _slots.get(slot, {})
	if info.is_empty():
		return
	_respawn_at[slot] = Time.get_ticks_msec() + int(float(info["respawn_sec"]) * CombatRules.MSEC_PER_SEC)


## Célula andável aleatória a até radius_cells do centro (o centro encaixado, se nada servir).
func random_point(instance_id: StringName, center: Vector3, radius_cells: float) -> Vector3:
	var grid: WalkGrid = world.get_grid_for_instance(instance_id)
	if grid == null:
		return center
	var r: float = radius_cells * grid.cell_size
	for i: int in range(CombatRules.PATROL_PICK_ATTEMPTS):
		var angle: float = _rng.randf_range(0.0, TAU)
		var dist: float = _rng.randf_range(0.0, r)
		var c: Vector2i = grid.world_to_cell(center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist))
		if grid.is_walkable(c):
			return grid.cell_to_world(c)
	var near: Vector2i = grid.nearest_walkable(grid.world_to_cell(center), CombatRules.SPAWN_SNAP_CELLS)
	return grid.cell_to_world(near) if near.x >= 0 else center


## Cria um monstro parado em pos, no estágio dado. roam_cells = raio da patrulha. rare = variante
## rara (Agente R): atributos melhores, drops melhores, visual próprio e aviso na instância.
func spawn(instance_id: StringName, def: MonsterDef, stage: MonsterStage, pos: Vector3,
		roam_cells: float, rare: bool = false) -> NetEntity:
	var grid: WalkGrid = world.get_grid_for_instance(instance_id)
	if grid == null or stage == null:
		return null
	_next_index += 1
	var e: NetEntity = world.new_entity()
	e.server_setup(CombatRules.MONSTER_ID_BASE + _next_index, NetEntity.KIND_MONSTER, stage.name_key,
			def.id, instance_id, pos)
	e.server_ensure_mover(grid, stage.walk_ms_per_cell)
	if rare:
		e.appearance = {APPEARANCE_RARE: true}
	var brain := MonsterBrain.new()
	brain.name = MonsterBrain.NODE_NAME
	brain.rare = rare
	e.add_child(brain)
	brain.setup(combat, def, stage, pos, roam_cells)
	world.spawn_entity(e)
	combat.register_monster(e)
	Net.log_line("monster_spawned", {"id": e.entity_id, "monster": String(def.id), "stage": stage.stage,
			"instance": String(instance_id), "pos": str(pos), "rare": rare, "atroz": brain.atroz})
	if rare:
		var shown: String = def.rare_name_key if not def.rare_name_key.is_empty() else stage.name_key
		Net.log_line("monster_rare_spawned", {"id": e.entity_id, "monster": String(def.id),
				"stage": stage.stage, "instance": String(instance_id), "max_hp": brain.max_hp(),
				"atk": int(brain.combat_stats().get(&"atk", 0))})
		for p: int in Net.get_instance_peer_ids(instance_id):
			Net.push_system_message(p, MSG_RARE, [shown])
	return e


## GDD §10.6: chefe com bando (normais e médios da mesma espécie) em volta dele. have = quantos de cada
## estágio já existem (não nascem de novo). Devolve os que nasceram.
func spawn_escort(boss: MonsterBrain, have: Dictionary[int, int] = {}) -> Array[NetEntity]:
	var e: NetEntity = boss.get_entity()
	var plan: Dictionary[int, int] = MonsterEvolution.escort_plan()
	var total: int = 0
	for n: int in plan.values():
		total += n
	var k: int = 0
	var made: Array[NetEntity] = []
	var grid: WalkGrid = world.get_grid_for_instance(e.instance_id)
	for stage_number: int in plan:
		var st: MonsterStage = MonsterEvolution.stage_by_number(boss.def, stage_number)
		if st == null:
			continue
		for i: int in range(plan[stage_number]):
			var angle: float = TAU * float(k) / float(maxi(total, 1))
			k += 1
			if i < int(have.get(stage_number, 0)):
				continue
			var p: Vector3 = e.net_position + Vector3(cos(angle), 0.0, sin(angle)) \
					* CombatRules.ESCORT_RING_CELLS * grid.cell_size
			var c: Vector2i = grid.nearest_walkable(grid.world_to_cell(p), CombatRules.SPAWN_SNAP_CELLS)
			if c.x < 0:
				continue
			var m: NetEntity = spawn(e.instance_id, boss.def, st, grid.cell_to_world(c),
					boss.roam_radius_cells)
			if m == null:
				continue
			var mb: MonsterBrain = combat.get_brain(m)
			mb.boss_entity_id = e.entity_id
			mb.origin = boss.origin
			made.append(m)
	Net.log_line("boss_escort_spawned", {"boss": e.entity_id, "monster": String(boss.def.id),
			"count": made.size(), "kept": have, "instance": String(e.instance_id)})
	return made



## Centro do Spawns/ dessa espécie na instância (Vector3.INF se não houver).
func species_center(instance_id: StringName, monster_id: StringName) -> Vector3:
	for slot: String in _slots:
		var info: Dictionary = _slots[slot]
		if info["instance"] == instance_id and (info["def"] as MonsterDef).id == monster_id:
			return info["center"]
	return Vector3.INF


## Teste (MonsterDebug): chefe (estágio 3) extra com bando em pos, fora do covil; à noite já nasce atroz
## (MonsterBrain.update_atroz). Não renasce. msg = aviso (%s = nome). reason só vai para o log.
func spawn_boss(instance_id: StringName, def: MonsterDef, pos: Vector3, roam_cells: float, reason: String,
		msg: String = MSG_LAIR) -> NetEntity:
	if not bosses_allowed(instance_id):
		Net.log_line("boss_spawn_failed", {"monster": String(def.id) if def != null else "", "reason": "zone"})
		return null
	var st: MonsterStage = MonsterEvolution.stage_by_number(def, CombatRules.STAGE_BOSS) if def != null else null
	if st == null:
		Net.log_line("boss_spawn_failed", {"monster": String(def.id) if def != null else "", "reason": "no_boss_stage"})
		return null
	var e: NetEntity = spawn(instance_id, def, st, world.snap_to_grid(instance_id, pos), roam_cells)
	if e == null:
		return null
	var b: MonsterBrain = combat.get_brain(e)
	var escort: int = spawn_escort(b).size()
	Net.log_line("boss_spawned", {"id": e.entity_id, "monster": String(def.id), "instance": String(instance_id),
			"reason": reason, "pos": str(e.net_position), "escort": escort, "atroz": b.atroz,
			"max_hp": b.max_hp(), "clock": DayNight.clock_text()})
	var shown: String = b.stage.name_key
	for p: int in Net.get_instance_peer_ids(instance_id):
		Net.push_system_message(p, msg, [shown])
	return e
