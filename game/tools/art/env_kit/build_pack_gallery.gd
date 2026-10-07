extends SceneTree
## Galeria de lookdev das malhas do kit (pk_*): scenes/lookdev/pack_gallery.tscn, com a luz do kit.
##   godot --headless --path game --script res://tools/art/env_kit/build_pack_gallery.gd -- nome1,nome2,...
const OUT := "res://assets/environment/painted/meshes/"


func _initialize() -> void:
	var names: PackedStringArray = OS.get_cmdline_user_args()[0].split(",") if not OS.get_cmdline_user_args().is_empty() else PackedStringArray()
	var root := Node3D.new()
	root.name = "PackGallery"
	root.add_child(EnvLook.make_sun(-38.0, -40.0))
	var we := WorldEnvironment.new()
	we.environment = load("res://assets/environment/painted/env_warm_day.tres")
	root.add_child(we)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	ground.mesh = pm
	var tm: ShaderMaterial = (load("res://assets/environment/painted/materials/mat_terrain.tres") as ShaderMaterial).duplicate()
	ground.material_override = tm
	root.add_child(ground)
	var x := 0.0
	var z := 0.0
	var i := 0
	for n: String in names:
		var mi := MeshInstance3D.new()
		mi.name = n
		mi.mesh = load(OUT + n + ".res")
		var w := maxf(mi.mesh.get_aabb().size.x, 1.0)
		mi.position = Vector3(x + w * 0.5, 0, z)
		root.add_child(mi)
		x += w + 1.0
		i += 1
		if x > 18.0:
			x = 0.0
			z += 7.0
	for c: Node in root.get_children():
		c.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://scenes/lookdev/pack_gallery.tscn")
	print("gallery ok ", names.size())
	quit()
