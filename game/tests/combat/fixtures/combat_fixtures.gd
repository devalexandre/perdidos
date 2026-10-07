extends RefCounted
## Dados de teste do combate (Agente K), só com --combat-fixtures (servidor e cliente). Nunca
## sobrescrevem um id real de data/. Enquanto W não entrega data/monsters e os Spawns/ do Campo:
##  - 3 espécies de teste com 3 estágios (folhas provisórias em tests/combat/fixtures/art/);
##  - Spawns/ no mapa da instância (se o mapa não tiver): criaturas perto do SpawnPoint, um
##    monstro resistente (teste de retorno), um bruto agressivo (evolução) e um distante (alcance);
##  - uma segunda instância do mesmo mapa (teste "outra instância");
##  - jogadores de teste por prefixo do nome: "Hero*" forte, "Victim*" nível 4 e frágil.

const CRITTER: StringName = &"test_critter"
const STURDY: StringName = &"test_sturdy"
const BRUTE: StringName = &"test_brute"
## Agente R: passivo, imortal na prática e com DES de esquiva (teste do "Errou" com --always-hit).
const DODGER: StringName = &"test_dodger"
const DODGER_OFFSET: Vector3 = Vector3(-4.0, 0.0, 5.0)
const ART_DIR: String = "res://tests/combat/fixtures/art/mon_test_"
const DROP_ITEM: StringName = &"spinning_leaf"
const OTHER_PARTY: String = "party_combat_test"
const CITY_MAP_ID: StringName = &"city_awakening"
## Marcadores relativos ao SpawnPoint (m) e raio (células).
const CRITTER_OFFSET: Vector3 = Vector3(5.0, 0.0, -3.0)
const STURDY_OFFSET: Vector3 = Vector3(-5.0, 0.0, -3.0)
const BRUTE_OFFSET: Vector3 = Vector3(0.0, 0.0, -12.0)
## Covil de teste da criatura (MonsterSpawner: BossLairs/) e quanto tempo o chefe leva para renascer (s).
const LAIR_OFFSET: Vector3 = Vector3(10.0, 0.0, 10.0)
const LAIR_RESPAWN_SEC: float = 5.0
const FAR_MIN_CELLS: int = 26
const FAR_MAX_CELLS: int = 34
const SPAWN_RADIUS_CELLS: float = 1.0
const CRITTER_COUNT: int = 3
const SNAP_CELLS: int = 8
const HERO_PREFIX: String = "Hero"
const VICTIM_PREFIX: String = "Victim"
const HERO_STR: int = 60
const HERO_VIT: int = 300
const VICTIM_LEVEL: int = 4
const VICTIM_HP: int = 1


static func _stage(n: int, art: String, lvl: int, hp: int, atk: int, xp: int, evolve: int,
		scale: float) -> MonsterStage:
	var st := MonsterStage.new()
	st.stage = n
	st.name_key = "TEST_MONSTER_%s_%d" % [art.to_upper(), n]
	st.sprite_base = ART_DIR + art
	st.visual_scale = scale
	st.level = lvl
	st.max_hp = hp
	st.atk = atk
	st.xp_reward = xp
	return st


static func _def(id: StringName, stages: Array[MonsterStage], respawn: float) -> MonsterDef:
	var d := MonsterDef.new()
	d.id = id
	d.stages = stages
	d.respawn_sec = respawn
	return d


static func install_content() -> void:
	var db: Dictionary = Content.all(&"monsters")
	var leaf := DropEntry.new()
	leaf.item_id = DROP_ITEM
	leaf.chance = 1.0
	# Criatura passiva: morre rápido, sempre deixa uma folha e 1–3 Estrelas.
	var c1 := _stage(1, "critter", 1, 30, 3, 12, 0, 1.0)
	c1.drops = [leaf]
	c1.stars_min = 1
	c1.stars_max = 3
	c1.behaviors = [&"hop_teleport"]
	var critter := _def(CRITTER, [c1, _stage(2, "critter", 3, 80, 8, 30, 100, 1.3),
			_stage(3, "critter", 6, 200, 15, 80, 250, 1.8)], 4.0)
	# Resistente e lento: para o teste de retorno (coleira curta).
	var s1 := _stage(1, "sturdy", 5, 5000, 2, 20, 0, 1.2)
	s1.walk_ms_per_cell = 600
	s1.leash_cells = 5
	s1.behaviors = [&"roll_charge"]
	var sturdy := _def(STURDY, [s1, _stage(2, "sturdy", 8, 6000, 4, 40, 100, 1.4),
			_stage(3, "sturdy", 12, 8000, 8, 90, 250, 1.9)], 30.0)
	# Bruto agressivo: mata o frágil (1 de vida) num golpe; com a XP dele vira chefe (estágio 3) de pouca vida.
	var b1 := _stage(1, "brute", 3, 400, 40, 25, 0, 1.0)
	b1.aggressive = true
	b1.aggro_range_cells = 4
	b1.attack_interval_ms = 800
	var b2 := _stage(2, "brute", 6, 400, 40, 50, 200, 1.3)
	b2.aggressive = true
	var b3 := _stage(3, "brute", 9, 60, 60, 100, 500, 1.8)
	b3.aggressive = true
	b3.aggro_range_cells = 3
	var brute := _def(BRUTE, [b1, b2, b3], 30.0)
	var d1 := _stage(1, "sturdy", 1, 100000, 1, 1, 0, 1.0)
	d1.dex = DamageFormula.TEST_EVASIVE_DEX
	var dodger := _def(DODGER, [d1], 30.0)
	dodger.can_be_rare = false
	for d: MonsterDef in [critter, sturdy, brute, dodger]:
		if not db.has(d.id):
			db[d.id] = d
			print("[combat_fixtures] registered monster %s" % d.id)
	# A cidade não tem combate (ZoneDef de W). Nos testes de combate ela vira arena: cópia em
	# memória com combat_allowed = true (nada é gravado).
	var zones: Dictionary = Content.all(&"zones")
	var city: ZoneDef = zones.get(CITY_MAP_ID) as ZoneDef
	if city != null and not city.combat_allowed:
		var arena: ZoneDef = city.duplicate() as ZoneDef
		arena.combat_allowed = true
		zones[CITY_MAP_ID] = arena
		print("[combat_fixtures] %s: combat_allowed = true (test only)" % CITY_MAP_ID)


## Servidor: se o mapa não tem Spawns/, cria os marcadores de teste; também cria a 2ª instância.
static func install_spawns(map_node: Node, instance_id: StringName, world: ServerWorld) -> void:
	var map_id: StringName = world.get_instance_map_id(instance_id)
	var other: StringName = Net.make_instance_id(map_id, OTHER_PARTY)
	if instance_id == map_id:
		world.get_or_create_instance(other, map_id)
	if map_node.get_node_or_null("Spawns") != null:
		return
	var grid: WalkGrid = world.get_grid_for_instance(instance_id)
	var center: Vector3 = world.get_spawn_point(instance_id)
	var root := Node3D.new()
	root.name = "Spawns"
	map_node.add_child(root)
	_marker(root, "critters", _snap(grid, center + CRITTER_OFFSET), CRITTER, CRITTER_COUNT)
	_marker(root, "sturdy", _snap(grid, center + STURDY_OFFSET), STURDY, 1)
	_marker(root, "brute", _snap(grid, center + BRUTE_OFFSET), BRUTE, 1)
	_marker(root, "dodger", _snap(grid, center + DODGER_OFFSET), DODGER, 1)
	var far: Vector3 = _far_point(grid, center)
	if far != Vector3.INF:
		_marker(root, "far", far, CRITTER, 1)
	# Covil fixo de teste (chefes fixos, 30/09/2026): chefe da criatura com bando, renasce rápido.
	var lairs := Node3D.new()
	lairs.name = "BossLairs"
	map_node.add_child(lairs)
	var lair := Marker3D.new()
	lair.name = "critter_lair"
	lair.set_meta(&"monster_id", CRITTER)
	lair.set_meta(&"radius_cells", SPAWN_RADIUS_CELLS)
	lair.set_meta(&"respawn_sec", LAIR_RESPAWN_SEC)
	lairs.add_child(lair)
	lair.global_position = _snap(grid, center + LAIR_OFFSET)


static func _marker(root: Node, marker_name: String, pos: Vector3, monster_id: StringName,
		count: int) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	m.set_meta(&"monster_id", monster_id)
	m.set_meta(&"count", count)
	m.set_meta(&"radius_cells", SPAWN_RADIUS_CELLS)
	root.add_child(m)
	m.global_position = pos
	print("[combat_fixtures] spawn marker %s (%s x%d) at %s" % [marker_name, monster_id, count, pos])


static func _snap(grid: WalkGrid, p: Vector3) -> Vector3:
	var c: Vector2i = grid.nearest_walkable(grid.world_to_cell(p), SNAP_CELLS)
	return grid.cell_to_world(c) if c.x >= 0 else p


## Célula andável entre FAR_MIN_CELLS e FAR_MAX_CELLS do centro (teste "fora de alcance").
static func _far_point(grid: WalkGrid, center: Vector3) -> Vector3:
	var c0: Vector2i = grid.world_to_cell(center)
	for r: int in range(FAR_MIN_CELLS, FAR_MAX_CELLS):
		for d: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r),
				Vector2i(r, r), Vector2i(-r, -r), Vector2i(r, -r), Vector2i(-r, r)]:
			var c: Vector2i = c0 + d
			if grid.in_bounds(c) and grid.is_walkable(c) and Vector2(d).length() >= FAR_MIN_CELLS:
				return grid.cell_to_world(c)
	return Vector3.INF


## Servidor: ajusta jogadores de teste pelo nome.
static func prepare_player(session: PlayerSession) -> void:
	var c: CharacterData = session.character
	if c.char_name.begins_with(HERO_PREFIX):
		c.base_attributes[&"str"] = HERO_STR
		c.base_attributes[&"vit"] = HERO_VIT
		c.hp = c.compute_stats()[CharacterStats.K_MAX_HP]
	elif c.char_name.begins_with(VICTIM_PREFIX):
		c.level = VICTIM_LEVEL
		var prog: Variant = c.get(&"progression")
		if prog is Object and &"total_xp" in prog:
			(prog as Object).set(&"total_xp", CombatBridges.curve_total_for_level(VICTIM_LEVEL))
		c.hp = VICTIM_HP
	else:
		return
	print("[combat_fixtures] prepared %s level=%d hp=%d" % [c.char_name, c.level, c.hp])
