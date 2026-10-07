extends Node

var failures: int = 0
var checks: int = 0

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
		print("  FAIL: ", message)
	else:
		print("  PASS: ", message)


func _ready() -> void:
	print("--- TEST COMPLETO DO ECOSSISTEMA DOS TÚNEIS DA TERRA OCA ---")
	await _test_approach_serra_sumidouro()
	await _test_dungeon_5_floors()
	_test_monsters()
	_test_exclusive_gear_and_items()
	_test_city_connection()
	print("ECOSSISTEMA TERRA OCA: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _test_map_common(map_id: StringName, min_exits: int) -> void:
	var scene_path: String = "res://scenes/maps/%s.tscn" % map_id
	var map: GameMap = load(scene_path).instantiate()
	_check(map != null, "%s.tscn instantiates cleanly" % map_id)
	if map == null:
		return
	add_child(map)

	for i: int in range(60):
		await get_tree().physics_frame
		if WalkGrid.is_nav_synced(map.get_navigation_map()):
			break

	var grid: WalkGrid = WalkGrid.for_map(map_id, map, map.get_navigation_map())
	_check(grid != null, "Navigation map ready for %s" % map_id)
	if grid != null:
		var spawn_pos: Vector3 = map.get_spawn_point()
		_check(grid.is_walkable(grid.world_to_cell(spawn_pos)), "%s SpawnPoint is walkable: %s" % [map_id, spawn_pos])

		var portals: Dictionary = map.get_interactables()
		_check(portals.size() >= min_exits, "%s has >= %d portals (has %d)" % [map_id, min_exits, portals.size()])

		for pid: String in portals:
			var obj: Dictionary = portals[pid]
			var point: Vector3 = obj.meta.get(&"approach_position", Vector3.ZERO)
			_check(grid.is_walkable(grid.world_to_cell(point)), "%s portal approach walkable: %s" % [map_id, pid])
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map.get_navigation_map(), spawn_pos, point, true)
			_check(path.size() >= 2 and path[-1].distance_to(point) < 0.4, "%s portal reachable from spawn: %s" % [map_id, pid])

		var spawns_node: Node = map.get_node_or_null("Spawns")
		if spawns_node != null and spawns_node.get_child_count() > 0:
			for spawn: Node3D in spawns_node.get_children():
				_check(grid.is_walkable(grid.world_to_cell(spawn.position)), "%s spawn pack on walkable ground: %s" % [map_id, spawn.name])

	map.queue_free()


func _test_approach_serra_sumidouro() -> void:
	print("\n-- Test Approach Region: Serra do Sumidouro (3 maps, >=3 exits each) --")
	var maps: Array[StringName] = [&"hollow_mountain_trail", &"hollow_mountain_gorge", &"hollow_mountain_gate"]
	for mid: StringName in maps:
		var zone: ZoneDef = Content.zone(mid)
		_check(zone != null, "ZoneDef %s exists" % mid)
		if zone != null:
			_check(zone.kind == ZoneDef.Kind.HUNT, "%s is HUNT kind" % mid)
			_check(zone.combat_allowed, "Combat allowed in %s" % mid)
			_check(zone.connected_maps.size() >= 2, "%s has >= 2 connected maps in ZoneDef (has %d)" % [mid, zone.connected_maps.size()])
		await _test_map_common(mid, 3)

	# Test gate map markers
	var gate_map: GameMap = load("res://scenes/maps/hollow_mountain_gate.tscn").instantiate()
	add_child(gate_map)
	var ret_marker: Node = gate_map.get_node_or_null("HollowReturn")
	_check(ret_marker != null, "hollow_mountain_gate has HollowReturn escape arrival marker")
	var dungeon_portal: Node = gate_map.get_node_or_null("Interactables/ToDungeon")
	_check(dungeon_portal != null, "hollow_mountain_gate has ToDungeon portal")
	if dungeon_portal != null:
		_check(dungeon_portal.get_meta(&"target_map", &"") == &"hollow_earth_1", "ToDungeon targets hollow_earth_1")
	gate_map.queue_free()


func _test_dungeon_5_floors() -> void:
	print("\n-- Test Dungeon Floors: Túneis da Terra Oca (5 floors, boss on F5) --")
	var floors: Array[StringName] = [&"hollow_earth_1", &"hollow_earth_2", &"hollow_earth_3", &"hollow_earth_4", &"hollow_earth_5"]
	for i: int in range(floors.size()):
		var fid: StringName = floors[i]
		var zone: ZoneDef = Content.zone(fid)
		_check(zone != null, "ZoneDef %s exists" % fid)
		if zone != null:
			_check(zone.kind == ZoneDef.Kind.HUNT, "%s is HUNT kind" % fid)
			_check(zone.combat_allowed, "Combat allowed in %s" % fid)
			_check(zone.connected_maps.size() >= 1, "%s has >= 1 connected maps" % fid)

		var min_exits: int = 2
		if i == 4:
			min_exits = 2 # Stair to F4 + Escape Portal to Surface
		await _test_map_common(fid, min_exits)

	# Test Floor 5 boss lair and escape portal specifically
	var f5_map: GameMap = load("res://scenes/maps/hollow_earth_5.tscn").instantiate()
	add_child(f5_map)
	for i: int in range(60):
		await get_tree().physics_frame
		if WalkGrid.is_nav_synced(f5_map.get_navigation_map()):
			break
	var f5_grid: WalkGrid = WalkGrid.for_map(&"hollow_earth_5", f5_map, f5_map.get_navigation_map())
	var escape: Node = f5_map.get_node_or_null("Interactables/SurfaceEscapePortal")
	_check(escape != null, "F5 has SurfaceEscapePortal")
	if escape != null:
		var target_map: StringName = escape.get_meta(&"target_map", &"")
		_check(target_map == &"hollow_mountain_gate", "SurfaceEscapePortal leads back to hollow_mountain_gate")
	var boss_spawn: Node = f5_map.get_node_or_null("BossLairs/deep_titan_lair")
	_check(boss_spawn != null, "F5 has deep_titan_lair in BossLairs")
	if boss_spawn != null and f5_grid != null:
		var bpos: Vector3 = (boss_spawn as Node3D).position
		_check(f5_grid.is_walkable(f5_grid.world_to_cell(bpos)), "Boss lair is on walkable navmesh: %s" % bpos)
		var spawn_pos: Vector3 = f5_map.get_spawn_point()
		var path_to_boss: PackedVector3Array = NavigationServer3D.map_get_path(f5_map.get_navigation_map(), spawn_pos, bpos, true)
		_check(path_to_boss.size() >= 2 and path_to_boss[-1].distance_to(bpos) < 0.5, "Boss lair reachable from F5 entrance")
	f5_map.queue_free()


func _test_monsters() -> void:
	print("\n-- Test Hollow Earth Monsters (3 species, 4 stages each) --")
	var species: Array[StringName] = [&"living_crystal", &"shadow_weaver", &"deep_titan"]

	for sp: StringName in species:
		var mdef: MonsterDef = Content.monster(sp)
		_check(mdef != null, "MonsterDef %s exists" % sp)
		if mdef == null:
			continue
		_check(mdef.stages.size() == 4, "MonsterDef %s has 4 stages" % sp)
		for st: int in range(1, 5):
			var stage: MonsterStage = mdef.stages[st - 1]
			_check(stage != null, "%s stage %d exists" % [sp, st])
			if stage != null:
				_check(stage.level >= 40, "%s stage %d level >= 40 (lv %d)" % [sp, st, stage.level])
				_check(stage.drops.size() > 0, "%s stage %d has drops configured" % [sp, st])


func _test_exclusive_gear_and_items() -> void:
	print("\n-- Test Exclusive Gear and Drops for Túneis da Terra Oca --")
	var items: Array[StringName] = [
		&"elmo_de_cristal_ressonante",
		&"armadura_do_tita_profundo",
		&"manoplas_de_quartzo_puro",
		&"grevas_do_abismo_oco",
		&"escudo_bastiao_tectonico",
		&"amuleto_do_nucleo_cristalino",
		&"martelo_do_abismo_profundo",
		&"arco_de_estilha_ressonante",
		&"cetro_do_coracao_da_terra",
		&"elixir_mineral_das_profundezas",
		&"cascalho_de_cristal_vivente",
		&"seda_sombria_profunda",
		&"estilha_primordial_do_tita",
		&"olho_do_tita",
	]

	for item_id: StringName in items:
		var item: ItemDef = Content.item(item_id)
		_check(item != null, "ItemDef %s exists" % item_id)
		if item != null:
			_check(item.exclusive_drop_zone == &"hollow_earth", "Item %s exclusive_drop_zone is 'hollow_earth'" % item_id)
			_check(item.buy_price == 0, "Item %s cannot be bought from shops (buy_price == 0)" % item_id)
			_check(item.icon != null, "Item %s has valid icon texture" % item_id)


func _test_city_connection() -> void:
	print("\n-- Test City Connection (Sumidouro <-> Serra do Sumidouro) --")
	var city_zone: ZoneDef = Content.zone(&"city_sumidouro")
	_check(city_zone != null and &"hollow_mountain_trail" in city_zone.connected_maps, "city_sumidouro connected to hollow_mountain_trail")
	var trail_zone: ZoneDef = Content.zone(&"hollow_mountain_trail")
	_check(trail_zone != null and &"city_sumidouro" in trail_zone.connected_maps, "hollow_mountain_trail connected back to city_sumidouro")
