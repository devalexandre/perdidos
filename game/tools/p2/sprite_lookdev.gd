extends Node
## Lookdev isolado dos sprites (GDD §17.0.C): chão, sol com sombra, Viajante e monstros, câmera do jogo.
##   godot --path game --resolution 1280x720 res://tools/p2/sprite_lookdev.tscn -- --out=/dir

var out := "user://sprite_lookdev"

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.6, 0.75, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.8, 0.79)
	e.ambient_light_energy = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.6, 0.3)
	pm.material = gm
	ground.mesh = pm
	root.add_child(ground)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.position = Vector3(-2.5, 0.5, -1)
	root.add_child(box)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.add_to_group(DirectionalSprite3D.CAMERA_GROUP)
	var pitch := deg_to_rad(Balance.cfg.camera_pitch_deg)
	var look := Vector3(0, 1, 0)
	cam.position = look + Vector3(0, sin(pitch), cos(pitch)) * 12.0
	cam.look_at(look)
	cam.fov = 30
	cam.current = true
	var hero := EntityVisual.new()
	root.add_child(hero)
	hero.set_appearance({&"body": &"female"})
	hero.setup_entity("e:1", "Viajante", false, true)
	hero.facing_yaw = PI * 0.25
	var hero2 := EntityVisual.new()
	root.add_child(hero2)
	hero2.set_appearance({&"body": &"male"})
	hero2.setup_entity("e:2", "Sombra", false, false)
	hero2.position = Vector3(-1.7, 0, -1.3)
	# Copa/telhado alto acima do segundo Viajante: ele deve ficar na sombra (recebe sombra do cenário).
	var roof := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(3.0, 0.2, 3.0)
	roof.mesh = rb
	roof.position = hero2.position + Vector3(0.0, 6.0, 0.0) - (-Vector3(0.0, 0.0, 0.0))
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	root.add_child(roof)
	await get_tree().process_frame
	roof.global_position = hero2.global_position + sun.global_basis.z * 6.0
	var i := 0
	for id in ["prank_whirlwind", "stone_armadillo", "enchanted_firefly"]:
		var def: MonsterDef = Content.monster(StringName(id))
		if def == null:
			continue
		var v := EntityVisual.new()
		root.add_child(v)
		var st: MonsterStage = def.stages[0]
		v.setup_sheets(st.sprite_base)
		v.visual_scale = st.visual_scale
		v.life = CombatVisuals.life_profile(st)
		v.position = Vector3(-2.2 + i * 2.2, 0, 2.0)
		v.anim = &"walk" if i == 0 else &"idle"
		i += 1
	for f in 40:
		await get_tree().process_frame
	DirectionalSprite3D.set_scene_sun(-sun.global_basis.z, sun.light_energy, true)
	for f in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("lookdev.png"))
	print("saved ", out)
	get_tree().quit()
