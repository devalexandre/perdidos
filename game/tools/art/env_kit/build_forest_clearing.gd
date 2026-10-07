extends SceneTree
## Cena de lookdev "clareira na floresta" (GDD §17.0.A) — sensação da ref. 1 com assets próprios.
##   godot --headless --path game --script res://tools/art/env_kit/build_forest_clearing.gd
## Gera res://scenes/lookdev/forest_clearing.tscn (+ pasta forest_clearing/ com splat, terreno, MultiMesh).
## Serve também de EXEMPLO de como vestir um mapa com o kit (docs/arte-cenario.md).
## Eixos: câmera padrão (yaw 0) olha para -Z; "cima da tela" = -Z. Jogador na origem.

const SCENE := "res://scenes/lookdev/forest_clearing.tscn"
const DIR := "res://scenes/lookdev/forest_clearing"
const KIT := "res://assets/environment/painted/"
const AREA := Rect2(-48, -56, 96, 96)
const TREE_EXCLUDE := 2.4

var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var path_pts := PackedVector2Array([Vector2(-7, 30), Vector2(-4.5, 14), Vector2(-1.5, 5), Vector2(0.5, 0),
		Vector2(2.5, -6), Vector2(5.5, -12), Vector2(10, -19), Vector2(13, -30)])
var path_b := PackedVector2Array([Vector2(1.0, -2.0), Vector2(7, -3.0), Vector2(14, -1.5), Vector2(24, 1.0)])
## Obstáculos (x, z, raio) para não espalhar capim/árvores em cima.
var blockers: Array = []


func _initialize() -> void:
	rng.seed = 20260927
	noise.seed = 11
	noise.frequency = 0.05
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var root := Node3D.new()
	root.name = "ForestClearing"
	_lighting(root)
	var decor := Node3D.new()
	decor.name = "Decor"
	root.add_child(decor)
	decor.owner = root
	_props(decor, root)
	_trees(decor, root)
	_terrain(root)
	_foliage(decor, root)
	_actors(root)
	var packed := PackedScene.new()
	_own(root, root)
	var err := packed.pack(root)
	err = ResourceSaver.save(packed, SCENE) if err == OK else err
	print("saved ", SCENE, " err=", err)
	root.free()
	quit(0 if err == OK else 1)


func _own(n: Node, root: Node) -> void:
	for c: Node in n.get_children():
		c.owner = root
		_own(c, root)


func _add(parent: Node, n: Node) -> Node:
	parent.add_child(n)
	return n


# ------------------------------------------------------------ campo de altura e máscaras

func height(x: float, z: float) -> float:
	var r := Vector2(x, z * 1.15).length()
	var hill := smoothstep(16.0, 46.0, r) * 7.0
	var n := noise.get_noise_2d(x, z) * 0.35
	# trilha levemente afundada
	var pd := minf(PaintedTerrain.dist_to_polyline(Vector2(x, z), path_pts),
			PaintedTerrain.dist_to_polyline(Vector2(x, z), path_b))
	var dip := (1.0 - smoothstep(0.0, 2.2, pd)) * 0.06
	return hill + n * (0.3 + smoothstep(8.0, 20.0, r)) - dip


## Quanto de terra (0..1) em (x, z): trilhas + a clareira de terra batida no centro.
func dirt(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var wob := noise.get_noise_2d(x * 3.0, z * 3.0) * 0.6
	var d1 := PaintedTerrain.dist_to_polyline(p, path_pts)
	var d2 := PaintedTerrain.dist_to_polyline(p, path_b)
	var path := 1.0 - smoothstep(1.0, 2.3, minf(d1, d2 + 0.3) + wob)
	var clearing := 1.0 - smoothstep(3.2, 6.0, Vector2(x - 0.8, (z + 1.0) * 1.25).length() + wob * 2.0)
	return clampf(maxf(path, clearing * 0.85), 0.0, 1.0)


func blocked(x: float, z: float, extra: float = 0.0) -> bool:
	for b: Array in blockers:
		if Vector2(x - b[0], z - b[1]).length() < float(b[2]) + extra:
			return true
	return false


# ------------------------------------------------------------ luz

func _lighting(root: Node3D) -> void:
	var sun := EnvLook.make_sun(-38.0, -40.0)
	_add(root, sun)
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = load(KIT + "env_warm_day.tres")
	_add(root, we)


# ------------------------------------------------------------ terreno

func _terrain(root: Node3D) -> void:
	var hf := Callable(self, "height")
	var mesh := PaintedTerrain.build_mesh(AREA, 1.0, hf)
	ResourceSaver.save(mesh, DIR + "/terrain_mesh.res")
	var img := PaintedTerrain.paint_splat(AREA, 4, func(x: float, z: float) -> Color:
		var rock := 0.0
		for b: Array in blockers:
			if b.size() > 3 and b[3] == "rock":
				rock = maxf(rock, 1.0 - smoothstep(float(b[2]) * 0.9, float(b[2]) * 1.6, Vector2(x - b[0], z - b[1]).length()))
		return Color(dirt(x, z), 0.0, 0.0, rock * 0.25))
	img.save_png(ProjectSettings.globalize_path(DIR + "/splat.png"))
	var tex := ImageTexture.create_from_image(img)
	var mat := PaintedTerrain.material(tex, AREA)
	mat.set_shader_parameter(&"dirt_tint", Color(0.93, 0.80, 0.64))
	ResourceSaver.save(mat, DIR + "/terrain_mat.tres")
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = load(DIR + "/terrain_mesh.res")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(root, mi)
	_add(root, PaintedTerrain.build_collision(AREA, 1.0, hf))


# ------------------------------------------------------------ props

func _mesh(parent: Node, name: String, res: String, pos: Vector3, yaw: float = 0.0, s: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var r := KitCatalog.resolve(res, pos)
	mi.mesh = load(r[0])
	mi.position = Vector3(pos.x, height(pos.x, pos.z) + pos.y, pos.z)
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * s * float(r[1])
	parent.add_child(mi)
	return mi


func _props(decor: Node3D, _root: Node3D) -> void:
	var props := Node3D.new()
	props.name = "Props"
	decor.add_child(props)
	# grupo de caixotes e barris à esquerda da trilha (como um acampamento)
	_mesh(props, "Crate1", "pk_crate_wooden", Vector3(-6.2, 0, 1.2), 0.3, 1.1)
	_mesh(props, "Crate2", "pk_crate_wooden", Vector3(-5.2, 0, 2.2), -0.2, 0.95)
	_mesh(props, "Crate3", "pk_crate_wooden", Vector3(-5.9, 0.85, 1.5), 0.9, 0.8)
	_mesh(props, "Barrel1", "pk_barrel", Vector3(-4.3, 0, 1.0), 0.0, 1.0)
	_mesh(props, "Barrel2", "pk_barrel_apples", Vector3(-7.3, 0, 2.4), 1.0, 0.9)
	blockers.append([-5.8, 1.7, 2.0])
	# pedras com musgo
	for r: Array in [["RockA", "rock_moss_a", Vector3(5.6, 0, -2.6), 0.4, 1.5], ["RockB", "rock_moss_b", Vector3(6.6, 0, -1.6), 1.2, 1.0],
			["RockC", "rock_moss_c", Vector3(-10.5, 0, -8.0), 2.0, 1.0], ["RockD", "rock_moss_b", Vector3(-8.8, 0, -6.6), 0.2, 1.3],
			["RockE", "rock_moss_a", Vector3(11.0, 0, 5.5), 2.5, 1.2], ["RockF", "rock_moss_b", Vector3(3.2, 0, 6.8), 0.7, 0.8]]:
		_mesh(props, r[0], r[1], r[2], r[3], r[4])
		blockers.append([(r[2] as Vector3).x, (r[2] as Vector3).z, 1.0 * float(r[4]) * (1.8 if r[1] == "rock_moss_c" else 1.0), "rock"])
	_mesh(props, "Log", "prop_log", Vector3(3.6, 0, 3.2), 0.5, 1.0)
	blockers.append([3.6, 3.2, 1.4])
	_mesh(props, "Stump", "pk_rock_moss_3", Vector3(-3.0, 0, -7.5), 0.0, 1.0)
	blockers.append([-3.0, -7.5, 0.8])
	for i in 3:
		_mesh(props, "Fence%d" % i, "prop_fence", Vector3(-3.4 - i * 2.0, 0, 6.2 + i * 0.25), -0.12, 1.0)
	blockers.append([-5.4, 6.4, 1.2])


# ------------------------------------------------------------ árvores

func _trees(decor: Node3D, _root: Node3D) -> void:
	var trees := Node3D.new()
	trees.name = "Trees"
	decor.add_child(trees)
	# árvores "de composição" (posição escolhida à mão, como na ref.: moldura em volta da clareira)
	var hand := [
		["tree_conifer_b", Vector3(-9.0, 0, -4.0), 1.0], ["tree_conifer_a", Vector3(-11.5, 0, 1.5), 1.1],
		["tree_conifer_c", Vector3(-8.8, 0, 5.8), 1.0], ["tree_conifer_a", Vector3(-13.5, 0, -9.5), 1.1],
		["tree_conifer_c", Vector3(-4.5, 0, -12.5), 1.1], ["tree_ipe_yellow_a", Vector3(2.5, 0, -13.5), 1.0],
		["tree_conifer_b", Vector3(8.5, 0, -11.0), 1.05], ["tree_conifer_a", Vector3(11.5, 0, -4.5), 1.0],
		["tree_conifer_c", Vector3(13.0, 0, 2.5), 1.05], ["tree_conifer_c", Vector3(9.8, 0, 7.4), 1.0],
		["tree_broadleaf_a", Vector3(-7.5, 0, 11.0), 1.0], ["tree_ipe_yellow_a", Vector3(-14.5, 0, -3.0), 0.9],
		["tree_conifer_a", Vector3(15.5, 0, -10.0), 1.1], ["tree_conifer_b", Vector3(-1.0, 0, -18.0), 1.1],
		["bush_round_a", Vector3(-3.6, 0, -9.8), 1.0], ["bush_round_a", Vector3(8.8, 0, -1.5), 0.9],
		["bush_conifer_a", Vector3(-7.0, 0, 2.2), 1.0], ["bush_round_a", Vector3(3.2, 0, 9.0), 1.2],
		["bush_conifer_a", Vector3(10.5, 0, -7.5), 1.3], ["bush_round_a", Vector3(-11.0, 0, -1.0), 1.1],
		["bush_conifer_a", Vector3(5.5, 0, -9.0), 1.0],
		["tree_conifer_a", Vector3(-6.0, 0, -7.8), 0.95], ["tree_conifer_c", Vector3(8.2, 0, -5.2), 1.0],
	]
	var i := 0
	for t: Array in hand:
		_mesh(trees, "Hand%02d_%s" % [i, t[0]], t[0], t[1], rng.randf_range(0, TAU), t[2])
		blockers.append([(t[1] as Vector3).x, (t[1] as Vector3).z, TREE_EXCLUDE * float(t[2]) * (0.5 if t[0].begins_with("bush") else 1.0)])
		i += 1
	# floresta de fundo: anel denso fora da clareira
	var kinds := ["tree_conifer_a", "tree_conifer_b", "tree_conifer_c", "tree_conifer_a", "tree_conifer_b",
			"tree_broadleaf_a", "tree_ipe_yellow_a"]
	var placed := 0
	var tries := 0
	while placed < 150 and tries < 5000:
		tries += 1
		var x := rng.randf_range(AREA.position.x + 3, AREA.end.x - 3)
		var z := rng.randf_range(AREA.position.y + 3, AREA.end.y - 3)
		var r := Vector2(x, z * 1.2).length()
		if r < 13.0 or dirt(x, z) > 0.2 or blocked(x, z, 1.2):
			continue
		var k: String = kinds[rng.randi() % kinds.size()]
		if k == "tree_ipe_yellow_a" and rng.randf() < 0.6:
			k = "tree_conifer_a"
		var s := rng.randf_range(0.85, 1.3) * lerpf(1.0, 1.25, smoothstep(18.0, 40.0, r))
		_mesh(trees, "Forest%03d" % placed, k, Vector3(x, 0, z), rng.randf_range(0, TAU), s)
		blockers.append([x, z, 2.0 * s])
		placed += 1
	print("árvores: %d à mão + %d de fundo" % [hand.size(), placed])


# ------------------------------------------------------------ capim, flores, cogumelos

func _foliage(decor: Node3D, _root: Node3D) -> void:
	var fs := FoliageScatter.new()
	fs.name = "Foliage"
	decor.add_child(fs)
	var hf := Callable(self, "height")
	var inner := Rect2(-30, -36, 60, 58)
	var grass_ok := func(x: float, z: float) -> float:
		if blocked(x, z, -0.6):
			return 0.0
		var d := dirt(x, z)
		var n := noise.get_noise_2d(x * 1.7 + 40.0, z * 1.7) * 0.5 + 0.5
		return clampf((1.0 - d * 1.6) * lerpf(0.35, 1.0, n), 0.0, 1.0)
	var edge_ok := func(x: float, z: float) -> float:
		# bordas da trilha e em volta de pedras/troncos: capim mais alto
		if blocked(x, z, -0.4):
			return 0.0
		var d := dirt(x, z)
		return clampf(1.0 - absf(d - 0.25) * 4.0, 0.0, 1.0)
	var flower_ok := func(x: float, z: float) -> float:
		if blocked(x, z, -0.3) or dirt(x, z) > 0.2:
			return 0.0
		var n := noise.get_noise_2d(x * 0.9 - 70.0, z * 0.9)
		return clampf((n - 0.05) * 3.0, 0.0, 1.0)
	var mush_ok := func(x: float, z: float) -> float:
		if dirt(x, z) > 0.3 or blocked(x, z, -0.2):
			return 0.0
		# perto de árvores e pedras (sombra/umidade)
		for b: Array in blockers:
			var dd := Vector2(x - b[0], z - b[1]).length() - float(b[2])
			if dd > -0.2 and dd < 1.2:
				return 0.5
		return 0.0
	var totals := {}
	totals["grass"] = fs.add_layer(load(KIT + "meshes/pk_grass_short.res"), inner, 2.2, rng, grass_ok, hf, 0.7, 1.2)
	totals["grass_b"] = fs.add_layer(load(KIT + "meshes/pk_grass_wispy_tall.res"), inner, 3.0, rng, edge_ok, hf, 0.8, 1.3)
	totals["flowers"] = fs.add_layer(load(KIT + "meshes/pk_flowers_a.res"), inner, 0.8, rng, flower_ok, hf, 0.7, 1.1)
	totals["flowers_b"] = fs.add_layer(load(KIT + "meshes/pk_flowers_b.res"), inner, 0.6, rng, flower_ok, hf, 0.7, 1.1)
	totals["mushrooms"] = fs.add_layer(load(KIT + "meshes/pk_mushroom.res"), inner, 0.35, rng, mush_ok, hf, 0.6, 1.0)
	totals["mushrooms_b"] = fs.add_layer(load(KIT + "meshes/pk_mushroom_shelf.res"), inner, 0.2, rng, mush_ok, hf, 0.6, 1.0)
	print("folhagem: ", totals, " ", fs.stats())
	# MultiMesh em arquivos binários (a .tscn fica pequena)
	for n: Node in fs.get_children():
		var mmi := n as MultiMeshInstance3D
		var path := DIR + "/mm_%s.res" % mmi.name
		ResourceSaver.save(mmi.multimesh, path)
		mmi.multimesh = load(path)


# ------------------------------------------------------------ atores (sprites do jogo)

func _actor(parent: Node3D, name: String, pos: Vector3, yaw_deg: float, meta: Dictionary) -> void:
	var m := Marker3D.new()
	m.name = name
	m.position = Vector3(pos.x, height(pos.x, pos.z), pos.z)
	m.rotation.y = deg_to_rad(yaw_deg)
	for k: String in meta:
		m.set_meta(StringName(k), meta[k])
	parent.add_child(m)


func _actors(root: Node3D) -> void:
	var a := Node3D.new()
	a.name = "Actors"
	a.set_script(load("res://scripts/client/env/lookdev_actors.gd"))
	root.add_child(a)
	_actor(a, "ViajanteM", Vector3(0.3, 0, 0.2), 200.0, {"body": &"male", "hero": true})
	_actor(a, "ViajanteF", Vector3(1.7, 0, -0.6), 150.0, {"body": &"female"})
	_actor(a, "MossTroll", Vector3(4.2, 0, -3.8), 30.0,
			{"sheet": "res://assets/monsters/moss_troll/mon_moss_troll_s1"})
	_actor(a, "Tanuki", Vector3(-3.4, 0, -3.0), -40.0,
			{"sheet": "res://assets/monsters/trickster_tanuki/mon_trickster_tanuki_s1"})
	_actor(a, "Whirlwind", Vector3(-1.6, 0, 3.6), 180.0,
			{"sheet": "res://assets/monsters/prank_whirlwind/mon_prank_whirlwind_s1"})
