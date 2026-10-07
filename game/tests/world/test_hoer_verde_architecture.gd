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
	print("--- TEST COMPLETO DO ECOSSISTEMA DE HOER VERDE E SUMIDOURO ---")
	await _test_city_sumidouro()
	await _test_approach_charneca_nevoa()
	await _test_dungeon_4_floors()
	_test_monsters()
	_test_exclusive_gear_and_items()
	_test_city_connections()
	print("ECOSSISTEMA HOER VERDE: %d checks, %d failures" % [checks, failures])
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


func _test_city_sumidouro() -> void:
	print("\n-- Test City 3: Arraial do Sumidouro --")
	var zid: StringName = &"city_sumidouro"
	var zone: ZoneDef = Content.zone(zid)
	_check(zone != null, "ZoneDef city_sumidouro exists")
	if zone != null:
		_check(zone.kind == ZoneDef.Kind.CITY, "city_sumidouro is CITY kind")
		_check(not zone.combat_allowed, "Combat not allowed in city_sumidouro")
		_check(&"city_serra_dourada" in zone.connected_maps, "Connected to city_serra_dourada")
		_check(&"fog_moor_trail" in zone.connected_maps, "Connected to fog_moor_trail")

	var map: GameMap = load("res://scenes/maps/city_sumidouro.tscn").instantiate()
	_check(map != null, "city_sumidouro.tscn instantiates cleanly")
	add_child(map)

	for i: int in range(60):
		await get_tree().physics_frame
		if WalkGrid.is_nav_synced(map.get_navigation_map()):
			break

	var grid: WalkGrid = WalkGrid.for_map(zid, map, map.get_navigation_map())
	_check(grid != null, "Navigation map ready for city_sumidouro")
	if grid != null:
		var altar: Node = map.get_node_or_null("Interactables/altar_crendice")
		_check(altar != null, "Altar de Crendice exists in city_sumidouro")

		var portals: Dictionary = map.get_interactables()
		_check(portals.size() >= 4, "city_sumidouro has >= 4 exits/portals (has %d)" % portals.size())

		var npcs: Node = map.get_node_or_null("NpcPoints")
		_check(npcs != null and npcs.get_node_or_null("curandeiro_sumidouro") != null, "Curandeiro NPC exists")
		_check(npcs != null and npcs.get_node_or_null("mercador_sumidouro") != null, "Mercador NPC exists")
		_check(npcs != null and npcs.get_node_or_null("artesao_sumidouro") != null, "Artesão NPC exists")

	map.queue_free()


func _test_approach_charneca_nevoa() -> void:
	print("\n-- Test Approach Region: Charneca da Névoa (3 maps, >=3 exits each) --")
	var maps: Array[StringName] = [&"fog_moor_trail", &"fog_moor_swamp", &"fog_moor_gate"]
	for mid: StringName in maps:
		var zone: ZoneDef = Content.zone(mid)
		_check(zone != null, "ZoneDef %s exists" % mid)
		if zone != null:
			_check(zone.kind == ZoneDef.Kind.HUNT, "%s is HUNT kind" % mid)
			_check(zone.combat_allowed, "Combat allowed in %s" % mid)
			_check(zone.connected_maps.size() >= 2, "%s has >= 2 connected maps in ZoneDef (has %d)" % [mid, zone.connected_maps.size()])
		await _test_map_common(mid, 3)

	# Test gate map markers
	var gate_map: GameMap = load("res://scenes/maps/fog_moor_gate.tscn").instantiate()
	add_child(gate_map)
	var ret_marker: Node = gate_map.get_node_or_null("HoerReturn")
	_check(ret_marker != null, "fog_moor_gate has HoerReturn escape arrival marker")
	var dungeon_portal: Node = gate_map.get_node_or_null("Interactables/ToDungeon")
	_check(dungeon_portal != null, "fog_moor_gate has ToDungeon portal")
	if dungeon_portal != null:
		_check(dungeon_portal.get_meta(&"target_map", &"") == &"hoer_verde_1", "ToDungeon targets hoer_verde_1")
	gate_map.queue_free()


func _test_dungeon_4_floors() -> void:
	print("\n-- Test Dungeon Floors: Vilarejo de Hoer Verde (4 floors, boss on F4) --")
	var floors: Array[StringName] = [&"hoer_verde_1", &"hoer_verde_2", &"hoer_verde_3", &"hoer_verde_4"]
	for i: int in range(floors.size()):
		var fid: StringName = floors[i]
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
	var f4_map: GameMap = load("res://scenes/maps/hoer_verde_4.tscn").instantiate()
	add_child(f4_map)
	for i: int in range(60):
		await get_tree().physics_frame
		if WalkGrid.is_nav_synced(f4_map.get_navigation_map()):
			break
	var f4_grid: WalkGrid = WalkGrid.for_map(&"hoer_verde_4", f4_map, f4_map.get_navigation_map())
	var escape: Node = f4_map.get_node_or_null("Interactables/SurfaceEscapePortal")
	_check(escape != null, "F4 has SurfaceEscapePortal")
	if escape != null:
		var target_map: StringName = escape.get_meta(&"target_map", &"")
		_check(target_map == &"fog_moor_gate", "SurfaceEscapePortal leads back to fog_moor_gate")
	var boss_spawn: Node = f4_map.get_node_or_null("BossLairs/silence_crier_lair")
	_check(boss_spawn != null, "F4 has silence_crier_lair in BossLairs")
	if boss_spawn != null and f4_grid != null:
		var bpos: Vector3 = (boss_spawn as Node3D).position
		_check(f4_grid.is_walkable(f4_grid.world_to_cell(bpos)), "Boss lair is on walkable navmesh: %s" % bpos)
		var spawn_pos: Vector3 = f4_map.get_spawn_point()
		var path_to_boss: PackedVector3Array = NavigationServer3D.map_get_path(f4_map.get_navigation_map(), spawn_pos, bpos, true)
		_check(path_to_boss.size() >= 2 and path_to_boss[-1].distance_to(bpos) < 0.5, "Boss lair reachable from F4 entrance")
	f4_map.queue_free()


func _test_monsters() -> void:
	print("\n-- Test Hoer Verde Monsters (3 species, 4 stages each) --")
	var species: Array[StringName] = [&"whispering_shade", &"despair_possessed", &"silence_crier"]

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
				_check(stage.level >= 35, "%s stage %d level >= 35 (lv %d)" % [sp, st, stage.level])
				_check(stage.drops.size() > 0, "%s stage %d has drops configured" % [sp, st])


func _test_exclusive_gear_and_items() -> void:
	print("\n-- Test Exclusive Gear and Drops for Vilarejo de Hoer Verde --")
	var items: Array[StringName] = [
		&"capuz_da_bruma_espectral",
		&"manto_dos_desesperados",
		&"luvas_do_toque_gelido",
		&"botas_do_passo_silencioso",
		&"escudo_do_lamento_eterno",
		&"pingente_do_sino_funebre",
		&"foice_da_colheita_sombria",
		&"arco_do_sussurro_noturno",
		&"cajado_das_almas_perdidas",
		&"essencia_da_nevoa_densa",
		&"tecido_fantasmagorico",
		&"cinzas_do_desespero",
		&"residuo_espectral",
		&"badalo_de_ferro_funebre",
		&"lenco_do_pregoeiro",
	]

	for item_id: StringName in items:
		var item: ItemDef = Content.item(item_id)
		_check(item != null, "ItemDef %s exists" % item_id)
		if item != null:
			_check(item.exclusive_drop_zone == &"hoer_verde", "Item %s exclusive_drop_zone is 'hoer_verde'" % item_id)
			_check(item.buy_price == 0, "Item %s cannot be bought from shops (buy_price == 0)" % item_id)
			_check(item.icon != null, "Item %s has valid icon texture" % item_id)


func _test_city_connections() -> void:
	print("\n-- Test City Connections (Serra Dourada <-> Sumidouro) --")
	var city_serra: ZoneDef = Content.zone(&"city_serra_dourada")
	_check(city_serra != null and &"city_sumidouro" in city_serra.connected_maps, "city_serra_dourada connected to city_sumidouro")
	var city_sumidouro: ZoneDef = Content.zone(&"city_sumidouro")
	_check(city_sumidouro != null and &"city_serra_dourada" in city_sumidouro.connected_maps, "city_sumidouro connected back to city_serra_dourada")
