extends Node
## Galeria de vegetação vista pela câmera do jogo (GDD §17.0.C). --out=/dir --meshes=a,b,c [--yaw=deg] [--sy=0.6]
var out := "user://veg"
var names: PackedStringArray = []
var yaw := 0.0
var sy := 1.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--meshes="): names = a.trim_prefix("--meshes=").split(",")
		elif a.begins_with("--yaw="): yaw = float(a.trim_prefix("--yaw="))
		elif a.begins_with("--sy="): sy = float(a.trim_prefix("--sy="))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()

func _run() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.6, 0.75, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.8, 0.79)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.58, 0.3)
	pm.material = gm
	ground.mesh = pm
	add_child(ground)
	var cols := 5
	for i in names.size():
		var path := String(names[i])
		if not path.begins_with("res://"):
			path = "res://assets/environment/painted/meshes/%s.res" % path
		var m: Mesh = load(path)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = Vector3((i % cols - (cols - 1) * 0.5) * 2.6, 0, (i / cols) * 2.6 - 2.6)
		mi.scale = Vector3(1, sy, 1)
		add_child(mi)
		var l := Label3D.new()
		l.text = String(names[i])
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = mi.position + Vector3(0, 0.05, 1.0)
		add_child(l)
	var hero := EntityVisual.new()
	add_child(hero)
	hero.set_appearance({&"body": &"female"})
	hero.position = Vector3(0, 0, 3.2)
	var cam := Camera3D.new()
	add_child(cam)
	cam.add_to_group(DirectionalSprite3D.CAMERA_GROUP)
	var pitch := deg_to_rad(Balance.cfg.camera_pitch_deg)
	var look := Vector3(0, 0.5, 0.5)
	cam.position = look + (Vector3(0, sin(pitch), cos(pitch)) * 26.0).rotated(Vector3.UP, deg_to_rad(yaw))
	cam.look_at(look)
	cam.fov = 26
	cam.current = true
	for f in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("veg_yaw%d.png" % int(yaw)))
	get_tree().quit()
