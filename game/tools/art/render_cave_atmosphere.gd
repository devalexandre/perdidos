extends SceneTree
## Revisão das cavernas, cachoeira e arena final. --out=DIR [--frames=36]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var out: String = "user://cave-review"
	var frames: int = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		if arg.begins_with("--frames="):
			frames = int(arg.trim_prefix("--frames="))
	DirAccess.make_dir_recursive_absolute(out)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.size = 24
	for id: String in ["cave_reino_encoberto", "cave_reino_encoberto_4", "cave_reino_encoberto_5"]:
		var map: Node3D = load("res://scenes/maps/%s.tscn" % id).instantiate()
		root.add_child(map)
		var at := Vector3(0, 0, 30)
		if id.ends_with("_4"):
			at = Vector3(0, 3, -28)
		elif id.ends_with("_5"):
			at = Vector3(0, 0, -16)
		camera.size = 42 if id.ends_with("_5") else 24
		camera.look_at_from_position(at + Vector3(7, 18, 21), at, Vector3.UP)
		await create_timer(1.0).timeout
		for i: int in frames:
			await create_timer(1.0 / 12.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%03d.png" % [out, id, i])
		map.queue_free()
		await process_frame
	print("cave review: ", out)
	quit()
