extends SceneTree
## Minimapa (GDD 9.4): render ORTOGRAFICO de cima do mapa, norte (-Z) para cima, cobrindo exatamente o
## ZoneDef.minimap_world_rect. Depois tools/art/minimap_pixel.py faz o tratamento em pixel art.
##   godot --path game --resolution 1024x1024 --script res://tools/art/render_minimap.gd -- --map=training_field --out=/dir
## (precisa de GPU/tela: DISPLAY=:0 ou xvfb-run)

func _initialize() -> void:
	var map_id := "training_field"
	var out := "."
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_id = a.trim_prefix("--map=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var zone := load("res://data/zones/%s.tres" % map_id) as ZoneDef
	var rect: Rect2 = zone.minimap_world_rect
	var map := (load("res://scenes/maps/%s.tscn" % map_id) as PackedScene).instantiate()
	root.add_child(map)
	# sem nevoa nem particulas na vista de cima
	for we: Node in map.find_children("*", "WorldEnvironment", true, false):
		var env := (we as WorldEnvironment).environment.duplicate() as Environment
		env.fog_enabled = false
		env.glow_enabled = false
		(we as WorldEnvironment).environment = env
	for p: Node in map.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).visible = false
	for l: Node in map.find_children("*", "DirectionalLight3D", true, false):
		(l as DirectionalLight3D).directional_shadow_max_distance = 300.0
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = rect.size.y
	cam.near = 1.0
	cam.far = 400.0
	root.add_child(cam)
	var c := Vector3(rect.position.x + rect.size.x * 0.5, 150.0, rect.position.y + rect.size.y * 0.5)
	cam.look_at_from_position(c, c - Vector3(0, 1, 0), Vector3(0, 0, -1))
	cam.current = true
	_shot.call_deferred(out, map_id)


func _shot(out: String, map_id: String) -> void:
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/minimap_raw_%s.png" % [out, map_id])
	print("minimap raw ", map_id)
	quit()
