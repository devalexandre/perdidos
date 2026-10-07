extends Node

var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	for floor_number: int in range(1, 5):
		var id: StringName = &"cave_reino_encoberto" if floor_number == 1 else StringName("cave_reino_encoberto_%d" % floor_number)
		var map: GameMap = load("res://scenes/maps/%s.tscn" % id).instantiate()
		add_child(map)
		for i: int in range(60):
			await get_tree().physics_frame
			if WalkGrid.is_nav_synced(map.get_navigation_map()):
				break
		var grid: WalkGrid = WalkGrid.for_map(id, map, map.get_navigation_map())
		check(grid != null, "%s navigation ready" % id)
		if grid == null:
			map.queue_free()
			continue
		check(grid.is_walkable(grid.world_to_cell(map.get_spawn_point())), "%s spawn walkable" % id)
		var data := MinimapData.build(id, map, grid)
		check(data.from_grid, "%s minimap matches navigation" % id)
		var zone: ZoneDef = Content.zone(id)
		check(zone.recommended_level_max == [16, 20, 24, 30][floor_number - 1], "%s canonical levels" % id)
		var portals: Dictionary = map.get_interactables()
		check(portals.size() >= 3, "%s multiple exits" % id)
		for obj: Dictionary in portals.values():
			var point: Vector3 = obj.meta[&"approach_position"]
			check(grid.is_walkable(grid.world_to_cell(point)), "%s portal walkable %s" % [id, point])
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map.get_navigation_map(), map.get_spawn_point(), point, true)
			check(path.size() >= 2 and path[-1].distance_to(point) < 0.2, "%s connected portal %s" % [id, point])
			var dest: StringName = obj.meta[&"target_map"]
			check(MapTransfer.portal_allowed(zone, dest), "%s allowed destination %s" % [id, dest])
			var target: Node = load("res://scenes/maps/%s.tscn" % dest).instantiate()
			check(target.has_node(NodePath(obj.meta[&"target_spawn"])), "%s arrival marker" % id)
			target.free()
		for spawn: Node3D in map.get_node("Spawns").get_children():
			check(grid.is_walkable(grid.world_to_cell(spawn.position)), "%s spawn pack walkable %s" % [id, spawn.name])
		var obstacle := Vector3(0, 0, -16) if floor_number == 4 else Vector3.ZERO
		check(not grid.is_walkable(grid.world_to_cell(obstacle)), "%s pillar/abyss is not walkable" % id)
		if floor_number == 4:
			check(map.has_node("BossLairs/werewolf") and zone.bosses_allowed, "fixed boss lair")
			check(portals["cave_surface_escape"].meta[&"requires_boss_victory"], "surface escape locked before victory")
		if "--shots" in OS.get_cmdline_user_args():
			var camera := Camera3D.new()
			map.add_child(camera)
			camera.position = Vector3(0, 78, 55)
			camera.look_at(Vector3(0, 0, -4))
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 110
			camera.current = true
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/cave-floor-%d.png" % floor_number)
		map.queue_free()
		await get_tree().process_frame
	var world := ServerWorld.new()
	var transfer := MapTransfer.new(world)
	var info: Dictionary = {"map_id": &"cave_reino_encoberto_4", "instance_id": &"cave_reino_encoberto_4", "boss": false}
	transfer._on_cave_boss_killed(1, &"cave_werewolf", info)
	check(transfer._cleared_cave_instances.is_empty(), "escort kill cannot unlock exit")
	info.boss = true
	transfer._on_cave_boss_killed(1, &"werewolf", info)
	check(transfer._cleared_cave_instances.is_empty(), "other boss cannot unlock exit")
	transfer._on_cave_boss_killed(1, &"cave_werewolf", info)
	check(transfer._cleared_cave_instances.has(&"cave_reino_encoberto_4"), "cave boss victory unlocks exit")
	world.free()
	print("CAVE ARCHITECTURE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
