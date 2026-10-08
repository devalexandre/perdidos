extends SceneTree
## Prévia da preparação contínua e do cenário: --fixed-fps 24 -- --out=/pasta.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out: String = "user://skill_charge_preview"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var clock: Script = load("res://scripts/shared/world_clock.gd")
	root.get_node(^"DayNight").force = clock.Force.DAY
	var map := (load("res://scenes/maps/training_field.tscn") as PackedScene).instantiate()
	root.add_child(map)
	var lights: Script = load("res://scripts/client/env/day_night_light.gd")
	lights.apply(map, 0.0)
	var caster := Node3D.new()
	root.add_child(caster)
	caster.position = Vector3(0, 0, 4)
	var visual: Node3D = (load("res://scripts/client/entity_visual.gd") as Script).new()
	caster.add_child(visual)
	visual.call("set_appearance", {&"body": &"female", &"outfit": &"traveler"})
	var fx: Node3D = (load("res://scripts/client/combat/skill_fx.gd") as Script).new()
	fx.set(&"find_entity", func(id: int) -> Node3D: return caster if id == 101 else null)
	root.add_child(fx)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 45.0
	cam.look_at_from_position(Vector3(3, 7, 12), Vector3(0, 0.8, 3.5), Vector3.UP)
	var listener := AudioListener3D.new()
	root.add_child(listener)
	listener.position = caster.position
	listener.make_current()
	await create_timer(1.0).timeout
	visual.call("play_cast_duration", 3.0)
	fx.call("play", load("res://data/skills/arcane_spark.tres"), 101, 0, Vector3(0, 0, -5), 3000)
	var audio_script: Script = load("res://scripts/client/audio_director.gd")
	audio_script.ensure_buses()
	var charge_audio: Node3D = (load("res://scripts/client/combat/skill_charge_audio.gd") as Script).new()
	charge_audio.set(&"follow", caster)
	charge_audio.set(&"duration", 3.0)
	root.add_child(charge_audio)
	for i: int in 96:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/frame_%03d.png" % [out, i])
	print("skill charge capture: ", out)
	quit()
