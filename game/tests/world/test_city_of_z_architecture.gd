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
	print("--- TEST COMPLETO DO ECOSSISTEMA DA CIDADE PERDIDA DE Z ---")
	await _test_approach_dossel_z()
	await _test_dungeon_4_floors()
	_test_monsters()
	_test_exclusive_gear_and_items()
	_test_city_connection()
	print("ECOSSISTEMA CIDADE DE Z: %d checks, %d failures" % [checks, failures])
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


func _test_approach_dossel_z() -> void:
	print("\n-- Test Approach Region: Dossel de Z (3 maps, >=3 exits each) --")
	var maps: Array[StringName] = [&"jungle_z_trail", &"jungle_z_river", &"jungle_z_gate"]
	for mid: StringName in maps:
		var zone: ZoneDef = Content.zone(mid)
		_check(zone != null, "ZoneDef %s exists" % mid)
		if zone != null:
			_check(zone.kind == ZoneDef.Kind.HUNT, "%s is HUNT kind" % mid)
			_check(zone.combat_allowed, "Combat allowed in %s" % mid)
			_check(zone.connected_maps.size() >= 2, "%s has >= 2 connected maps in ZoneDef (has %d)" % [mid, zone.connected_maps.size()])
		await _test_map_common(mid, 3)


func _test_dungeon_4_floors() -> void:
	print("\n-- Test Dungeon Floors: A Cidade Perdida de Z (4 floors, boss on F4) --")
	var dungeon_floors: Array[StringName] = [&"city_of_z_1", &"city_of_z_2", &"city_of_z_3", &"city_of_z_4"]
	for i: int in range(dungeon_floors.size()):
		var fid: StringName = dungeon_floors[i]
		var zone: ZoneDef = Content.zone(fid)
		_check(zone != null, "ZoneDef %s exists" % fid)
		if zone != null:
			_check(zone.kind == ZoneDef.Kind.HUNT, "%s is HUNT kind" % fid)
			_check(zone.combat_allowed, "Combat allowed in %s" % fid)
			_check(zone.connected_maps.size() >= 1, "%s has >= 1 connected maps" % fid)

		var min_exits: int = 2
		if i == 3:
			min_exits = 2 # Stair to F3 + Escape Portal to Surface
		await _test_map_common(fid, min_exits)

	# Test Floor 4 boss lair and escape portal specifically
	var f4_map: GameMap = load("res://scenes/maps/city_of_z_4.tscn").instantiate()
	add_child(f4_map)
	for i: int in range(60):
		await get_tree().physics_frame
		if WalkGrid.is_nav_synced(f4_map.get_navigation_map()):
			break
	var f4_grid: WalkGrid = WalkGrid.for_map(&"city_of_z_4", f4_map, f4_map.get_navigation_map())
	var escape: Node = f4_map.get_node_or_null("Interactables/SurfaceEscapePortal")
	_check(escape != null, "F4 has SurfaceEscapePortal")
	if escape != null:
		var target_map: StringName = escape.get_meta(&"target_map", &"")
		_check(target_map == &"jungle_z_gate", "SurfaceEscapePortal leads back to jungle_z_gate")
	var boss_spawn: Node = f4_map.get_node_or_null("BossLairs/kuarahy")
	_check(boss_spawn != null, "F4 has kuarahy boss lair in BossLairs")
	if boss_spawn != null and f4_grid != null:
		var bpos: Vector3 = (boss_spawn as Node3D).position
		_check(f4_grid.is_walkable(f4_grid.world_to_cell(bpos)), "Boss lair is on walkable navmesh: %s" % bpos)
		var spawn_pos: Vector3 = f4_map.get_spawn_point()
		var path_to_boss: PackedVector3Array = NavigationServer3D.map_get_path(f4_map.get_navigation_map(), spawn_pos, bpos, true)
		_check(path_to_boss.size() >= 2 and path_to_boss[-1].distance_to(bpos) < 0.5, "Boss lair reachable from F4 entrance")
	f4_map.queue_free()


func _test_monsters() -> void:
	print("\n-- Test City of Z Monsters (3 species, 4 stages each) --")
	var species: Array[StringName] = [&"shadow_jaguar", &"camo_hunter", &"kuarahy_soberano"]

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
				_check(stage.level >= 30, "%s stage %d level >= 30 (lv %d)" % [sp, st, stage.level])
				_check(stage.drops.size() > 0, "%s stage %d has drops configured" % [sp, st])


func _test_exclusive_gear_and_items() -> void:
	print("\n-- Test Exclusive Gear and Drops for A Cidade Perdida de Z --")
	var items: Array[StringName] = [
		&"diadema_solar_de_z",
		&"couraca_de_placas_douradas",
		&"bracadeiras_do_rastreador",
		&"sandalias_de_cipo_dourado",
		&"escudo_radiante_kuarahy",
		&"colar_do_disco_solar",
		&"lanca_solar_de_z",
		&"arco_do_dossel_profundo",
		&"cajado_solar_kuarahy",
		&"nectar_solar_da_mata",
		&"ouro_antigo_de_z",
		&"fragmento_mural_solar",
		&"garra_onca_sombra",
		&"matriz_solar_kuarahy",
		&"mascara_ritual_kuarahy",
	]

	for item_id: StringName in items:
		var item: ItemDef = Content.item(item_id)
		_check(item != null, "ItemDef %s exists" % item_id)
		if item != null:
			_check(item.exclusive_drop_zone == &"city_of_z", "Item %s exclusive_drop_zone is 'city_of_z'" % item_id)
			_check(item.buy_price == 0, "Item %s cannot be bought from shops (buy_price == 0)" % item_id)
			_check(item.icon != null, "Item %s has valid icon texture" % item_id)


func _test_city_connection() -> void:
	print("\n-- Test City 2 (Serra Dourada) to Z Connection --")
	var city_zone: ZoneDef = Content.zone(&"city_serra_dourada")
	_check(city_zone != null and &"jungle_z_trail" in city_zone.connected_maps, "city_serra_dourada connected to jungle_z_trail")
	var trail_zone: ZoneDef = Content.zone(&"jungle_z_trail")
	_check(trail_zone != null and &"city_serra_dourada" in trail_zone.connected_maps, "jungle_z_trail connected back to city_serra_dourada")
