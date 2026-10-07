extends SceneTree
## PRÉVIA da redecoração da praça do Porto do Despertar com o kit pintado (GDD §17.0.A).
## NÃO é o mapa real: copia a geometria de res://scenes/maps/city_awakening.tscn (só leitura), troca os
## materiais pelos pintados, a luz pelo EnvLook, e planta o ipê gigante volumétrico + props do kit.
##   godot --headless --path game --script res://tools/art/env_kit/build_city_preview.gd
## Saída: res://scenes/lookdev/city_plaza_preview.tscn

const SRC := "res://scenes/maps/city_awakening.tscn"
const OUT := "res://scenes/lookdev/city_plaza_preview.tscn"
const KIT := "res://assets/environment/painted/"
const TREE_POS := Vector3(0, 0, -1.5)
const PLAZA_R := 16.0

## Malha da cidade (Geometry/Mesh_<nome>) → material do kit (null = some).
var swap: Dictionary = {}


func _m(name: String) -> Material:
	return load(KIT + "materials/mat_%s.tres" % name)


func _tinted(name: String, tint: Color, extra: Dictionary = {}) -> Material:
	var m: ShaderMaterial = _m(name).duplicate()
	m.set_shader_parameter(&"tint", tint)
	for k: String in extra:
		m.set_shader_parameter(StringName(k), extra[k])
	return m


func _initialize() -> void:
	var ground_cobble := _tinted("paving", Color(0.98, 0.95, 0.9), {"tile_m": 4.0, "detail": 0.8})
	var calcada := _tinted("paving", Color(1.08, 1.04, 0.97), {"tile_m": 3.0, "detail": 0.75})
	var grass: ShaderMaterial = _m("terrain").duplicate()
	grass.set_shader_parameter(&"splat_source", 0)
	var sand := _tinted("rock", Color(1, 1, 1), {"albedo_tex": load(KIT + "textures/tex_sand.png"), "tile_m": 5.0})
	swap = {
		"wall_white": _m("plaster_warm"),
		"wall_yellow": _m("plaster_ochre"),
		"wall_pink": _m("plaster_rose"),
		# as paredes "azuis" viram cal quente com um toque frio muito leve — nada de azul chapado
		"wall_blue": _tinted("plaster_warm", Color(0.93, 0.95, 0.93)),
		"wall_green": _tinted("plaster_warm", Color(0.90, 0.95, 0.82)),
		"roof": _tinted("roof_clay", Color(1.0, 0.9, 0.84), {"uv_scale": Vector2(0.45, 0.45)}),
		"roof_ridge": _tinted("roof_clay", Color(0.8, 0.7, 0.64), {"uv_scale": Vector2(0.45, 0.45)}),
		"wood": _m("wood"),
		"dark_wood": _m("wood_dark"),
		"hull": _m("wood_dark"),
		"cobble": ground_cobble,
		"calcada": calcada,
		"stone": _m("stonewall"),
		"stone_trim": _tinted("stonewall", Color(1.05, 1.0, 0.94)),
		"azulejo": _m("azulejo"),
		"grass": grass,
		"sand": sand,
		"trunk": _m("bark"),
		"leaves": _m("canopy_broad"),
		"palm": _m("canopy_broad"),
		"palm_dark": _tinted("canopy_broad", Color(0.7, 0.82, 0.62)),
		"ipe_purple": _m("canopy_ipe"),
		"ipe_yellow": null, # o ipê gigante da praça vira a árvore volumétrica do kit
	}
	var city: Node3D = (load(SRC) as PackedScene).instantiate()
	city.set_script(null) # prévia: sem lógica de mapa/navegação
	city.name = "CityPlazaPreview"
	city.scene_file_path = ""
	for n: Node in city.find_children("*", "", true, false):
		n.scene_file_path = ""
	var geo := city.get_node("Geometry")
	for mi: Node in geo.get_children():
		var key := String(mi.name).trim_prefix("Mesh_")
		if swap.has(key):
			if swap[key] == null:
				mi.get_parent().remove_child(mi)
				mi.free()
			else:
				(mi as MeshInstance3D).material_override = swap[key]
	# enfeites em pixel art (sprites) saem: no kit o cenário não é pixel art
	var props := city.get_node_or_null("Props")
	if props != null:
		props.get_parent().remove_child(props)
		props.free()
	# luz e pós do kit
	var lighting := city.get_node("Lighting")
	for n: String in ["Sun", "WorldEnvironment"]:
		var old := lighting.get_node_or_null(n)
		if old != null:
			lighting.remove_child(old)
			old.free()
	lighting.add_child(EnvLook.make_sun(-35.0, -42.0))
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = load(KIT + "env_warm_city.tres")
	lighting.add_child(we)
	var petals := lighting.get_node_or_null("IpePetals") as GPUParticles3D
	if petals != null:
		petals.position = TREE_POS + Vector3(0, 11, 0)
		petals.visibility_aabb = AABB(Vector3(-20, -14, -20), Vector3(40, 18, 40))
	_decor(city)
	for n: Node in city.find_children("*", "", true, false):
		n.owner = city
	var packed := PackedScene.new()
	var err := packed.pack(city)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("saved ", OUT, " err=", err)
	city.free()
	quit(0 if err == OK else 1)


func _mesh(parent: Node, name: String, res: String, pos: Vector3, yaw: float = 0.0, s: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = load(KIT + "meshes/" + res + ".res")
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * s
	parent.add_child(mi)


func _decor(city: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/lookdev/city_plaza_preview"))
	var decor := Node3D.new()
	decor.name = "Decor"
	city.add_child(decor)
	var actors := Node3D.new()
	actors.name = "Actors"
	actors.set_script(load("res://scripts/client/env/lookdev_actors.gd"))
	city.add_child(actors)
	for a: Array in [["ViajanteM", Vector3(0.0, 0.02, 6.5), 200.0, {"body": &"male", "hero": true}],
			["ViajanteF", Vector3(1.5, 0.02, 7.0), 160.0, {"body": &"female"}]]:
		var m := Marker3D.new()
		m.name = a[0]
		m.position = a[1]
		m.rotation.y = deg_to_rad(a[2])
		for k: String in a[3]:
			m.set_meta(StringName(k), a[3][k])
		actors.add_child(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_mesh(decor, "IpeGigante", "tree_ipe_yellow_giant", TREE_POS, 0.4, 1.0)
	# canteiros de flores e arbustos em volta do ipê (anel) e caixotes/barris da feira
	var fs := FoliageScatter.new()
	fs.name = "Foliage"
	decor.add_child(fs)
	var flat := func(_x: float, _z: float) -> float: return 0.03
	var bed := func(x: float, z: float) -> float:
		var r := Vector2(x - TREE_POS.x, z - TREE_POS.z).length()
		return 1.0 if r > 4.2 and r < 5.4 else 0.0
	fs.add_layer(load(KIT + "meshes/flowers.res"), Rect2(-7, -8.5, 14, 14), 5.0, rng, bed, flat, 0.8, 1.2)
	fs.add_layer(load(KIT + "meshes/flowers_b.res"), Rect2(-7, -8.5, 14, 14), 4.0, rng, bed, flat, 0.8, 1.2)
	fs.add_layer(load(KIT + "meshes/grass_tuft_b.res"), Rect2(-7, -8.5, 14, 14), 3.0, rng, bed, flat, 0.8, 1.2)
	for i in 8:
		var a := i * TAU / 8.0 + 0.2
		_mesh(decor, "Bush%d" % i, "bush_round_a", TREE_POS + Vector3(cos(a), 0, sin(a)) * 5.6, a, 0.8)
	for p: Array in [["Crate", "prop_crate", Vector3(-9.5, 0, 9.0), 0.3], ["Crate2", "prop_crate", Vector3(-8.7, 0, 9.8), -0.4],
			["Barrel", "prop_barrel", Vector3(-10.4, 0, 10.0), 0.0], ["Barrel2", "prop_barrel", Vector3(9.8, 0, 9.4), 0.0],
			["Crate3", "prop_crate", Vector3(10.6, 0, 8.6), 0.6]]:
		_mesh(decor, p[0], p[1], p[2], p[3], 1.0)
	for n: Node in fs.get_children():
		var mm := (n as MultiMeshInstance3D).multimesh
		ResourceSaver.save(mm, "res://scenes/lookdev/city_plaza_preview/mm_%s.res" % n.name)
		(n as MultiMeshInstance3D).multimesh = load("res://scenes/lookdev/city_plaza_preview/mm_%s.res" % n.name)
