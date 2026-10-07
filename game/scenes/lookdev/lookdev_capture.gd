extends Node
## Captura de lookdev com a câmera e o pós REAIS do jogo (ClientView, sem rede nem interface).
##   godot --path game --resolution 1920x1080 res://scenes/lookdev/lookdev_capture.tscn -- \
##       --scene=res://scenes/lookdev/forest_clearing.tscn --out=/dir [--name=forest] [--yaws=0,35,-40]
##       [--quality=alta|media|baixa] [--mode=internal] [--focus=x,y,z] [--zoom=1.0] [--stats]
## Salva <out>/<name>_<W>x<H>_yaw<N>.png e, com --stats, imprime draw calls/primitivas/memória.

const CLIENT_VIEW_SCENE: PackedScene = preload("res://scenes/ui/client_view.tscn")
const SETTLE_FRAMES: int = 20

var _view: ClientView


func _ready() -> void:
	var scene_path := "res://scenes/lookdev/forest_clearing.tscn"
	var out := "user://lookdev"
	var shot_name := "shot"
	var yaws: Array[float] = [0.0]
	var focus := Vector3.INF
	var zoom := 1.0
	var stats := false
	var bench := 0.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_path = a.trim_prefix("--scene=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--name="):
			shot_name = a.trim_prefix("--name=")
		elif a.begins_with("--yaws="):
			yaws.clear()
			for y: String in a.trim_prefix("--yaws=").split(","):
				yaws.append(float(y))
		elif a.begins_with("--quality="):
			var q := a.trim_prefix("--quality=")
			EnvQuality.current = EnvQuality.Preset.MEDIA if q == "media" else (
					EnvQuality.Preset.BAIXA if q == "baixa" else EnvQuality.Preset.ALTA)
		elif a.begins_with("--mode="):
			Balance.cfg.world_render_mode = a.trim_prefix("--mode=")
		elif a.begins_with("--focus="):
			var p := a.trim_prefix("--focus=").split(",")
			focus = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif a.begins_with("--zoom="):
			zoom = float(a.trim_prefix("--zoom="))
		elif a == "--stats":
			stats = true
		elif a.begins_with("--bench="):
			bench = float(a.trim_prefix("--bench="))
	DirAccess.make_dir_recursive_absolute(out)
	var world := (load(scene_path) as PackedScene).instantiate()
	add_child(world)
	_view = CLIENT_VIEW_SCENE.instantiate() as ClientView
	_view.create_game_ui = false
	_view.create_audio = false
	add_child(_view)
	_view.get_node(^"Hud").visible = false
	_view.camera_zoom = zoom
	var target: Node3D = null
	var actors := world.get_node_or_null(^"Actors")
	await get_tree().process_frame
	if focus != Vector3.INF:
		target = Node3D.new()
		world.add_child(target)
		target.global_position = focus
	elif actors != null and actors.get(&"hero") != null:
		target = actors.get(&"hero")
	_view.set_follow_target(target)
	var size := get_viewport().get_visible_rect().size
	for y: float in yaws:
		_view.camera_yaw = deg_to_rad(y)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := out.path_join("%s_%dx%d_yaw%03d.png" % [shot_name, size.x, size.y, int(y) % 360 + (360 if y < 0 else 0)])
		img.save_png(path)
		print("saved ", path)
		if stats:
			var vp_rid: RID = (_view.get_node(^"SubViewport") as Viewport).get_viewport_rid()
			print("stats yaw=%d draw_calls=%d objects=%d primitives=%d vram_MB=%.0f fps=%d" % [y,
				RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
					RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
				RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
					RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
				RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
					RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
				Engine.get_frames_per_second()])
	if bench > 0.0:
		# Mede o tempo médio de quadro girando a câmera (use numa tela com GPU, sem vsync).
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var t0 := Time.get_ticks_usec()
		var frames := 0
		while Time.get_ticks_usec() - t0 < bench * 1000000.0:
			_view.camera_yaw += 0.01
			await get_tree().process_frame
			frames += 1
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
		print("bench quality=%s frames=%d avg_ms=%.2f fps=%.0f" % [EnvQuality.PRESET_NAMES[EnvQuality.current], frames, ms, 1000.0 / ms])
	get_tree().quit(0)
