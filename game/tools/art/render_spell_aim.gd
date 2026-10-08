extends SceneTree
## Captura da mira rúnica, com raios reais das skills, sobre o Campo de Treino.
## godot --path game --script res://tools/art/render_spell_aim.gd -- --out=/pasta
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var out: String = "user://spell-aim"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var clock: Script = load("res://scripts/shared/world_clock.gd")
	root.get_node(^"DayNight").force = clock.Force.DAY
	var map: Node3D = (load("res://scenes/maps/training_field.tscn") as PackedScene).instantiate()
	root.add_child(map)
	(load("res://scripts/client/env/day_night_light.gd") as Script).call("apply", map, 0.0)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.0
	camera.current = true
	camera.look_at_from_position(Vector3(0, 12, 14), Vector3(0, 0, 5), Vector3.UP)
	for id: StringName in [&"arcane_creeping_flame", &"arcane_star_fall", &"support_coconut_water"]:
		var def: SkillDef = load("res://data/skills/%s.tres" % id)
		var color: Color = (load("res://scripts/client/combat/skill_fx.gd") as Script).call("charge_color_for", def)
		color.a = 0.35
		var marker: Node3D = (load("res://scripts/client/ui/hotbar_aim.gd") as Script).call("make_shape", def, color)
		root.add_child(marker)
		marker.position = Vector3(0, 0.08, 5)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, id])
		marker.free()
	print("spell aim capture: ", out)
	quit()
