extends SceneTree
## Captura curta do acampamento: --fixed-fps 12 -- --out=/pasta [--night]. PNGs a 12 fps.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = "user://living_environment"
	var night: bool = "--night" in OS.get_cmdline_user_args()
	var portal: bool = "--portal" in OS.get_cmdline_user_args()
	var weather: String = "clear"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--weather="):
			weather = arg.trim_prefix("--weather=")
	DirAccess.make_dir_recursive_absolute(out)
	var day_night: Node = root.get_node(^"DayNight")
	var clock: Script = load("res://scripts/shared/world_clock.gd")
	day_night.force = clock.Force.NIGHT if night else clock.Force.DAY
	var map := (load("res://scenes/maps/training_field.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await physics_frame
	var portals: Script = load("res://scripts/client/combat/portal_fx.gd")
	portals.decorate_map(map)
	var light_script: Script = load("res://scripts/client/env/day_night_light.gd")
	light_script.apply(map, 1.0 if night else 0.0)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 50.0
	cam.look_at_from_position(Vector3(5, 11, 11), Vector3(0, 0.8, -1.5), Vector3.UP)
	if portal:
		cam.look_at_from_position(Vector3(1, 8, -5), Vector3(5.5, 1.8, -16.5), Vector3.UP)
	if weather != "clear":
		var rain: Control = (load("res://scripts/client/env/rain_overlay.gd") as Script).new()
		root.add_child(rain)
		rain.call("set_map", &"training_field")
		rain.set("_weather_map", map)
		rain.set("_target_intensity", 1.0 if weather == "storm" else 0.0)
		rain.set("_intensity", 1.0 if weather == "storm" else 0.0)
		rain.set("_target_fog", 0.6 if weather == "storm" else 1.0)
		rain.set("_fog", 0.6 if weather == "storm" else 1.0)
		rain.set("_raining", weather == "storm")
		rain.set("_rain_seconds_left", 100.0)
		rain.call("_rebuild_drops")
	await create_timer(1.0).timeout
	for i: int in 48:
		await process_frame
		light_script.apply(map, 1.0 if night else 0.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/frame_%03d.png" % [out, i])
	print("living environment capture: ", out)
	quit()
