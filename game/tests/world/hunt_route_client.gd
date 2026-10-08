extends Node
## Real client smoke test: traverses all ten areas and returns to the city.
var main_node: Node = null
var args: Dictionary[String, String] = {}
var player: NetEntity = null
var started: bool = false
var failures: int = 0
var maps: Array[StringName] = []

func _ready() -> void:
	Net.enter_instance_requested.connect(func(_id: StringName, map_id: StringName) -> void: maps.append(map_id))
	Net.local_player_spawned.connect(_placed)
	get_tree().create_timer(1500).timeout.connect(func() -> void:
		push_error("Hunt route timed out")
		get_tree().quit(1))

func _placed(placed_entity: Node3D) -> void:
	player = placed_entity as NetEntity
	if started:
		return
	started = true
	await get_tree().create_timer(2).timeout
	for step: Array in [["gate_north", &"fields_pindorama"],
			["forward", &"fields_pindorama_buriti"],
			["forward", &"fields_pindorama_crossroads"],
			["forward", &"enchanted_forest"],
			["forward", &"enchanted_forest_glade"],
			["forward", &"enchanted_forest_roots"],
			["cave", &"cave_reino_encoberto"],
			["cave_deeper_1", &"cave_reino_encoberto_2"],
			["cave_deeper_2", &"cave_reino_encoberto_3"],
			["cave_deeper_3", &"cave_reino_encoberto_4"],
			["cave_east_return", &"cave_reino_encoberto_3"],
			["cave_east_return", &"cave_reino_encoberto_2"],
			["cave_east_2", &"cave_reino_encoberto_3"],
			["cave_return", &"cave_reino_encoberto_2"],
			["cave_return", &"cave_reino_encoberto"],
			["cave_return", &"enchanted_forest_roots"],
			["forward", &"enchanted_forest_heart"],
			["forward", &"split_sky_plateau"],
			["forward", &"split_sky_plateau_ridges"],
			["forward", &"split_sky_plateau_summit"],
			["back", &"split_sky_plateau_ridges"],
			["back", &"split_sky_plateau"],
			["back", &"enchanted_forest_heart"],
			["back", &"enchanted_forest_roots"],
			["back", &"enchanted_forest_glade"],
			["back", &"enchanted_forest"],
			["back", &"fields_pindorama_crossroads"],
			["back", &"fields_pindorama_buriti"],
			["back", &"fields_pindorama"],
			["back", &"city_awakening"]]:
		var previous: NetEntity = player
		var walk_portals: bool = "--walk-portals" in OS.get_cmdline_user_args()
		var map: GameMap = player.get_parent().get_parent().get_node("Map") as GameMap
		var point: Vector3 = map.get_interactables()[step[0]].meta[&"approach_position"]
		if "--quick-route" in OS.get_cmdline_user_args():
			var nearby: Vector3 = point + (player.net_position - point).normalized() * 4.0
			NetProgress.send_debug(&"teleport", [nearby.x, nearby.z])
			var arrival_deadline: int = Time.get_ticks_msec() + 5000
			while player.net_position.distance_to(nearby) > 1.0 and Time.get_ticks_msec() < arrival_deadline:
				await get_tree().create_timer(0.1).timeout
		if walk_portals:
			Net.send_move_request(point)
		else:
			Net.send_interact("m:" + step[0])
		var deadline: int = Time.get_ticks_msec() + 90000
		while Time.get_ticks_msec() < deadline:
			if is_instance_valid(player) and player != previous and NetWorld.client_map_id == step[1]:
				break
			await get_tree().create_timer(0.2).timeout
		if not is_instance_valid(player) or player == previous or NetWorld.client_map_id != step[1]:
			push_error("Failed portal %s to %s" % step)
			get_tree().quit(1)
			return
		await get_tree().create_timer(2).timeout
		if step[0] == "back" and step[1] != &"city_awakening" and player.net_position.z > -25:
			failures += 1
			push_error("Return did not use NorthArrival")
		var levels: Array[int] = []
		for instance: Node in main_node.get_node("World/Instances").get_children():
			var entities: Node = instance.get_node_or_null("Entities")
			if entities == null:
				continue
			for entity: Node in entities.get_children():
				if entity is NetEntity and (entity as NetEntity).kind == NetEntity.KIND_MONSTER:
					levels.append((entity as NetEntity).level)
		if step[1] not in [&"city_awakening", &"cave_reino_encoberto"] and levels.is_empty():
			failures += 1
			push_error("Hunt map has no replicated monsters")
		if String(step[1]).begins_with("split_sky_plateau") and levels.max() < 22:
			failures += 1
			push_error("Advanced area missing its boss")
		print("HUNT_ROUTE_STEP ", step[1], " position=", player.net_position, " monster_levels=", levels)
	print("HUNT_ROUTE_RESULT failures=", failures, " maps=", maps)
	get_tree().quit(0 if failures == 0 else 1)
