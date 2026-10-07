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
	print("--- TEST COMPLETO DO ECOSSISTEMA DE RATANABÁ ---")
	await _test_city_serra_dourada()
	await _test_approach_selva_ratanaba()
	await _test_dungeon_4_floors()
	_test_monsters()
	_test_exclusive_gear_and_items()
	_test_summit_connection()
	print("ECOSSISTEMA RATANABÁ: %d checks, %d failures" % [checks, failures])
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


func _test_city_serra_dourada() -> void:
	print("\n-- Test City 2: Serra Dourada --")
	var zid: StringName = &"city_serra_dourada"
	var zone: ZoneDef = Content.zone(zid)
	_check(zone != null, "ZoneDef city_serra_dourada exists")
	if zone != null:
		_check(zone.kind == ZoneDef.Kind.CITY, "city_serra_dourada is CITY kind")
		_check(not zone.combat_allowed, "Combat not allowed in city_serra_dourada")
		_check(&"split_sky_plateau_summit" in zone.connected_maps, "Connected to summit")
		_check(&"jungle_ratanaba_trail" in zone.connected_maps, "Connected to jungle trail")

	var map: GameMap = load("res://scenes/maps/city_serra_dourada.tscn").instantiate()
	_check(map != null, "city_serra_dourada.tscn instantiates cleanly")
	add_child(map)

	for i: int in range(60):
		await get_tree().physics_frame
		if WalkGrid.is_nav_synced(map.get_navigation_map()):
			break

	var grid: WalkGrid = WalkGrid.for_map(zid, map, map.get_navigation_map())
	_check(grid != null, "Navigation map ready for city_serra_dourada")
	if grid != null:
		var altar: Node = map.get_node_or_null("Interactables/altar_crendice")
		_check(altar != null, "Altar de Crendice exists in city_serra_dourada")

		var portals: Dictionary = map.get_interactables()
		_check(portals.size() >= 4, "city_serra_dourada has >= 4 exits/portals (has %d)" % portals.size())

		var npcs: Node = map.get_node_or_null("NpcPoints")
		_check(npcs != null and npcs.get_node_or_null("curandeira_joana") != null, "Curandeira NPC exists")
		_check(npcs != null and npcs.get_node_or_null("mercador_serra_dourada") != null, "Merchant NPC exists")
		_check(npcs != null and npcs.get_node_or_null("artesao_goncalo") != null, "Artisan NPC exists")

	map.queue_free()


func _test_approach_selva_ratanaba() -> void:
	print("\n-- Test Selva de Ratanabá (3 Approach Maps) --")
	var maps: Array[StringName] = [&"jungle_ratanaba_trail", &"jungle_ratanaba_waterfall", &"jungle_ratanaba_gate"]
	for mid: StringName in maps:
		var zone: ZoneDef = Content.zone(mid)
		_check(zone != null, "ZoneDef %s exists" % mid)
		if zone != null:
			_check(zone.recommended_level_min >= 20 and zone.recommended_level_max <= 30, "%s level in 20-30 range" % mid)
			_check(zone.connected_maps.size() >= 2, "%s connects to >= 2 adjacent maps" % mid)
		await _test_map_common(mid, 3)

	# Verify gate contains dungeon entry portal
	var gate_map: GameMap = load("res://scenes/maps/jungle_ratanaba_gate.tscn").instantiate()
	add_child(gate_map)
	var dungeon_portal: Node = gate_map.get_node_or_null("Interactables/ToDungeon")
	_check(dungeon_portal != null, "jungle_ratanaba_gate has ToDungeon portal")
	if dungeon_portal != null:
		_check(dungeon_portal.get_meta(&"target_map", &"") == &"ruins_ratanaba_1", "Dungeon portal targets ruins_ratanaba_1")
	var ret_marker: Node = gate_map.get_node_or_null("RatanabaReturn")
	_check(ret_marker != null, "jungle_ratanaba_gate has RatanabaReturn arrival marker for boss escape")
	gate_map.queue_free()


func _test_dungeon_4_floors() -> void:
	print("\n-- Test Ruínas de Ratanabá (4 Floors) --")
	var floors: Array[StringName] = [&"ruins_ratanaba_1", &"ruins_ratanaba_2", &"ruins_ratanaba_3", &"ruins_ratanaba_4"]
	for fid: StringName in floors:
		var zone: ZoneDef = Content.zone(fid)
		_check(zone != null, "ZoneDef %s exists" % fid)
		if zone != null:
			_check(zone.recommended_level_min >= 24 and zone.recommended_level_max <= 38, "%s level in 24-38 range" % fid)
			_check(zone.connected_maps.size() >= 1, "%s connected to adjacent floor" % fid)
		await _test_map_common(fid, 3)

	# Verify F4 Boss and Escape Portal
	var f4_map: GameMap = load("res://scenes/maps/ruins_ratanaba_4.tscn").instantiate()
	add_child(f4_map)
	var boss_lair: Marker3D = f4_map.get_node_or_null("BossLairs/architect") as Marker3D
	_check(boss_lair != null, "F4 has architect boss lair")
	if boss_lair != null:
		_check(boss_lair.get_meta(&"monster_id", &"") == &"ratanaba_architect", "Boss lair targets ratanaba_architect")

	var escape_portal: Node = f4_map.get_node_or_null("Interactables/SurfaceEscapePortal")
	_check(escape_portal != null, "F4 has SurfaceEscapePortal")
	if escape_portal != null:
		_check(bool(escape_portal.get_meta(&"requires_boss_victory", false)), "Escape portal requires boss victory")
		_check(escape_portal.get_meta(&"target_map", &"") == &"jungle_ratanaba_gate", "Escape portal returns to surface gate")
	f4_map.queue_free()


func _test_monsters() -> void:
	print("\n-- Test Ratanabá Monsters --")
	var expected_monsters: Array[StringName] = [&"ratanaba_sentinel", &"crystal_serpent", &"ratanaba_architect"]
	for mid: StringName in expected_monsters:
		var m: MonsterDef = Content.monster(mid)
		_check(m != null, "MonsterDef '%s' registered" % mid)
		if m == null:
			continue
		_check(m.stages.size() == 4, "%s has 4 stages" % mid)
		for st: int in range(1, 5):
			var stage: MonsterStage = m.stages[st - 1]
			_check(stage != null, "%s stage %d exists" % [mid, st])
			if stage != null:
				_check(stage.level >= 20, "%s stage %d level >= 20 (is %d)" % [mid, st, stage.level])
				_check(stage.max_hp > 500, "%s stage %d hp > 500 (is %d)" % [mid, st, stage.max_hp])
				_check(not stage.drops.is_empty(), "%s stage %d has drop entries" % [mid, st])
				if st >= 3:
					_check(&"boss" in stage.behaviors, "%s stage %d has boss behavior" % [mid, st])


func _test_exclusive_gear_and_items() -> void:
	print("\n-- Test Exclusive Gear and Items (Drop-only) --")
	var exclusive_items: Array[StringName] = [
		&"diadema_de_glifos",
		&"couraca_de_placas_runicas",
		&"manoplas_do_construtor",
		&"sandalias_de_pedra_pomes",
		&"egide_prismatica",
		&"anel_do_circuito_antigo",
		&"oleo_runico",
		&"obsidian_machete",
		&"crystal_recurve_bow",
		&"ratanaba_energy_wand",
		&"biomechanic_mace",
		&"figa_de_obsidiana",
		&"prisma_da_serpente",
		&"coracao_obsidiana_arquiteto",
	]

	for iid: StringName in exclusive_items:
		var item: ItemDef = Content.item(iid)
		_check(item != null, "Item '%s' exists" % iid)
		if item != null:
			_check(item.exclusive_drop_zone == &"ruins_ratanaba", "%s has exclusive_drop_zone = ruins_ratanaba" % iid)
			_check(item.buy_price == 0, "%s buy_price is 0 (cannot be bought)" % iid)

	# Verify no shop sells any exclusive items
	var shops: Dictionary = Content.all(&"shops")
	for sid: StringName in shops:
		var shop: ShopDef = shops[sid]
		for item_id: StringName in shop.available_items(5):
			var it: ItemDef = Content.item(item_id)
			if it != null:
				_check(it.exclusive_drop_zone.is_empty(), "Shop '%s' does not sell exclusive item '%s'" % [sid, item_id])


func _test_summit_connection() -> void:
	print("\n-- Test Summit Connection --")
	var summit_zone: ZoneDef = Content.zone(&"split_sky_plateau_summit")
	_check(summit_zone != null, "ZoneDef split_sky_plateau_summit exists")
	if summit_zone != null:
		_check(&"city_serra_dourada" in summit_zone.connected_maps, "Summit connects to city_serra_dourada")
