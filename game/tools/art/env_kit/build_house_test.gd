extends SceneTree
## Cena de teste das casas coloniais modulares: scenes/lookdev/house_test.tscn
func _initialize() -> void:
	var root := Node3D.new()
	root.name = "HouseTest"
	root.add_child(EnvLook.make_sun(-35.0, -42.0))
	var we := WorldEnvironment.new()
	we.environment = load("res://assets/environment/painted/env_warm_city.tres")
	root.add_child(we)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	g.mesh = pm
	g.material_override = load("res://assets/environment/painted/materials/mat_paving.tres")
	root.add_child(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var items: Array = []
	ColonialHouse.build(items, Transform3D(Basis(Vector3.UP, 0.0), Vector3(-6, 0, 0)), 8.0, 7.0, 2, "wall_white", "frame_blue", true, rng)
	ColonialHouse.build(items, Transform3D(Basis(Vector3.UP, 0.0), Vector3(4, 0, 0)), 6.5, 7.5, 1, "wall_yellow", "frame_green", false, rng)
	ColonialHouse.build(items, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, -12)), 9.0, 7.0, 2, "wall_pink", "frame_teal", false, rng)
	var fs := FoliageScatter.new()
	fs.name = "Kit"
	root.add_child(fs)
	var groups := KitCatalog.group(items, rng)
	for m: String in groups:
		fs.add_instances(load(m), groups[m], m.get_file().get_basename(), rng, true)
	for c: Node in root.find_children("*", "", true, false):
		c.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://scenes/lookdev/house_test.tscn")
	print("houses ok ", items.size())
	quit()
