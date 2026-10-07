extends Node

var failures: int = 0
var checks: int = 0
const MAPS: Array[StringName] = [&"fields_sabia", &"fields_sabia_buriti", &"fields_sabia_crossroads", &"enchanted_forest", &"enchanted_forest_glade", &"enchanted_forest_roots", &"enchanted_forest_heart", &"split_sky_plateau", &"split_sky_plateau_ridges", &"split_sky_plateau_summit"]

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	var previous_min: int = 0
	for map_id: StringName in MAPS:
		var zone: ZoneDef = Content.zone(map_id)
		check(zone != null and zone.kind == ZoneDef.Kind.HUNT, "%s hunt rules" % map_id)
		var map: GameMap = (load("res://scenes/maps/%s.tscn" % map_id) as PackedScene).instantiate() as GameMap
		add_child(map)
		for attempt: int in range(60):
			await get_tree().physics_frame
			if WalkGrid.is_nav_synced(map.get_navigation_map()):
				break
		var grid: WalkGrid = WalkGrid.for_map(map_id, map, map.get_navigation_map())
		var mdata: MinimapData = MinimapData.build(map_id, map, grid)
		check(zone.minimap_texture != null or (mdata != null and mdata.texture != null), "sector has a minimap")
		check(map.get_node("Trail").mesh != null, "trail geometry built")
		check(grid != null, "%s navigation synced" % map_id)
		if grid == null:
			map.queue_free()
			continue
		check(grid.is_walkable(grid.world_to_cell(map.get_spawn_point())), "safe spawn walkable")
		check(grid.is_walkable(grid.world_to_cell(map.get_node("NorthArrival").position)), "return spawn walkable")
		var low: int = 999
		for spawn: Node3D in map.get_node("Spawns").get_children():
			var def: MonsterDef = Content.monster(spawn.get_meta(&"monster_id"))
			var stage: MonsterStage = MonsterEvolution.stage_by_number(def, int(spawn.get_meta(&"stage")))
			for animation: String in ["idle", "walk", "attack", "hit", "death"]:
				check(ResourceLoader.exists(stage.sprite_base + "_" + animation + ".png"), "spawn animation exists")
			check(stage != null, "spawn references real stage")
			check(stage.stage <= CombatBridges.stage_cap_for_zone(zone), "spawn respects area difficulty")
			check(grid.is_walkable(grid.world_to_cell(spawn.position)), "spawn on navigation")
			check(spawn.position.distance_to(map.get_spawn_point()) > 14.0, "entry separated from monsters")
			low = mini(low, stage.level)
		check(low >= previous_min, "monster levels do not decrease along the route")
		previous_min = low
		for obj: Dictionary in map.get_interactables().values():
			if not obj.meta.has(&"target_map"):
				continue  # altar de crendice, NPCs: não são portais
			var dest: StringName = obj.meta[&"target_map"]
			check(MapTransfer.portal_allowed(zone, dest), "portal has valid connection")
			var reverse: ZoneDef = Content.zone(dest)
			check(map_id in reverse.connected_maps, "connection has a return route")
			var destination: GameMap = (load("res://scenes/maps/%s.tscn" % dest) as PackedScene).instantiate() as GameMap
			check(destination.has_node(NodePath(String(obj.meta[&"target_spawn"]))), "arrival marker exists")
			destination.free()
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map.get_navigation_map(), map.get_spawn_point(), obj.meta[&"approach_position"], true)
			check(path.size() >= 2, "portal reachable from safe spawn")
		var advanced: bool = String(map_id).begins_with("split_sky_plateau")
		check(MonsterSpawner.zone_allows_bosses(zone, CombatBridges.stage_cap_for_zone(zone)) == advanced, "only advanced maps host boss lairs")
		check(map.has_node("BossLairs") == advanced, "boss lairs only in the Chapada")
		check(CombatBridges.stage_cap_for_zone(zone) == (3 if advanced else (1 if String(map_id).begins_with("fields_sabia") else 2)), "stage ceiling")
		check(not MapTransfer.portal_allowed(zone, &"training_field"), "no return to training")
		check(not MapTransfer.portal_allowed(zone, &"nonexistent"), "reject missing destination")
		var atlas: WorldAtlasDef = load(WorldAtlasDef.DEFAULT_PATH)
		check(atlas.place_for_map(map_id) != null, "atlas identifies new map")
		if "--shots" in OS.get_cmdline_user_args():
			var cam := Camera3D.new()
			map.add_child(cam)
			cam.position = Vector3(46, 65, 65)
			cam.look_at(Vector3.ZERO)
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 120
			cam.current = true
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/hunt_%s.png" % map_id)
		map.queue_free()
		await get_tree().process_frame
	var city: ZoneDef = Content.zone(&"city_awakening")
	check(MapTransfer.portal_allowed(city, MAPS[0]), "city opens beginner field")
	check(not MapTransfer.portal_allowed(city, &"enchanted_forest"), "city cannot skip to intermediate map")
	print("HUNT AREAS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
