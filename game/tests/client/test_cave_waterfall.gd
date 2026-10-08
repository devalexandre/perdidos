extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _run() -> void:
	var grid_script: Script = load("res://scripts/shared/grid/walk_grid.gd")
	var quality: Script = load("res://scripts/client/env/env_quality.gd")
	var old_quality: int = quality.current
	for id: StringName in [&"cave_reino_encoberto_4", &"cave_reino_encoberto_5"]:
		var map: Node3D = load("res://scenes/maps/%s.tscn" % id).instantiate()
		root.add_child(map)
		for i: int in 60:
			await physics_frame
			if grid_script.call("is_nav_synced", map.call("get_navigation_map")):
				break
		var grid: RefCounted = grid_script.call("for_map", id, map, map.call("get_navigation_map"))
		check(grid != null, "%s navigation ready" % id)
		check(not map.has_node("CaveAtmosphere"), "headless server does not create cave art")
		if id == &"cave_reino_encoberto_4":
			var portal: Area3D = map.get_node("Interactables/DeepPassagePortal")
			check(portal.get_meta(&"target_map") == &"cave_reino_encoberto_5", "hidden entrance leads to final floor")
			check(portal.get_meta(&"requires_quest") == &"arc1_final_boitata", "story progression gate retained")
			check(portal.get_meta(&"hidden_waterfall_passage"), "entrance marked as hidden")
			check(not portal.get_node("Name").visible, "floating sign does not reveal secret")
			check(portal.get_meta(&"minimap_icon") == &"none", "minimap does not reveal hidden passage")
			(load("res://scripts/client/combat/portal_fx.gd") as Script).call("decorate_map", map)
			check(not portal.has_node("PortalFx"), "hidden entrance has no bright portal marker")
			if grid != null:
				for at: Vector3 in [Vector3(0, 0, -26), Vector3(0, 0, -28), Vector3(0, 0, -30)]:
					check(grid.call("is_walkable", grid.call("world_to_cell", at)), "walkable through and behind waterfall %s" % at)
		else:
			check(map.get_node("StoryLairs/boitata").get_meta(&"monster_id") == &"story_boitata", "original final boss remains")
			check(map.get_node("Interactables/ToFloor4").get_meta(&"target_spawn") == &"DeepPassageReturn", "return route remains in front of waterfall")
			if grid != null:
				check(grid.call("is_walkable", grid.call("world_to_cell", map.get_node("SpawnPoint").position)), "final floor arrival is walkable")
		quality.current = quality.Preset.ALTA
		var fx: Node3D = (load("res://scripts/client/env/cave_atmosphere.gd") as Script).new()
		map.add_child(fx)
		await process_frame
		check(fx.find_children("*", "CollisionObject3D", true, false).is_empty(), "client atmosphere does not introduce gameplay obstacles")
		var lights: Array = fx.find_children("*", "OmniLight3D", true, false)
		check(lights.size() <= 2, "bounded local light count")
		for light: OmniLight3D in lights:
			check(not light.shadow_enabled, "local lights do not allocate shadow maps")
		if id == &"cave_reino_encoberto_4":
			check(fx.find_children("WaterCurtain*", "MeshInstance3D", true, false).size() == 3, "three independent water layers")
			var sound: AudioStreamPlayer3D = fx.get_node("WaterfallSound")
			check(sound.stream != null and sound.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "waterfall has continuous positional audio")
			check(sound.bus == &"Ambience", "waterfall follows ambience volume")
		quality.current = quality.Preset.BAIXA
		await process_frame
		for light: OmniLight3D in lights:
			check(not light.visible, "low quality disables extra local lights")
		for particle: CPUParticles3D in fx.find_children("*", "CPUParticles3D", true, false):
			check(particle.amount == 10, "low quality reduces particle density")
		map.queue_free()
		await process_frame
		check(not is_instance_valid(fx), "atmosphere cleans up with map transfer")
	quality.current = old_quality
	print("CAVE WATERFALL: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
