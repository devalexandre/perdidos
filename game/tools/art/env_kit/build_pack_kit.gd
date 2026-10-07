extends SceneTree
## Converte modelos dos pacotes CC0 (assets/environment/packs, ver assets/environment/LICENSES.md) em malhas do
## kit pintado (assets/environment/painted/meshes/pk_*.res):
##  - junta todas as partes num ArrayMesh (1 superfície por material → poucas draw calls, pronto para MultiMesh);
##  - escala para metros do jogo (Viajante ≈ 1,7 m) e apoia a base no chão (y = 0);
##  - troca os materiais pelos do kit (shaders env_foliage / env_painted) com a paleta quente/pastel;
##  - folhagem: normais "esféricas" a partir do centro da copa (volume macio), cor de vértice = oclusão pintada +
##    peso do vento (alfa) calculados aqui.
##   godot --headless --path game --script res://tools/art/env_kit/build_pack_kit.gd
## Precisa do kit base (build_kit.gd) já gerado.

const PK := "res://assets/environment/packs/"
const OUT := "res://assets/environment/painted/meshes/"
const KIT_MAT := "res://assets/environment/painted/materials/"
const SH_FOLIAGE := preload("res://assets/shaders/env_foliage.gdshader")
const SH_PAINTED := preload("res://assets/shaders/env_painted.gdshader")
const SH_PAINTED_2S := preload("res://assets/shaders/env_painted_2s.gdshader")
const NAT := PK + "quaternius_nature/"
const VIL := PK + "quaternius_village/"
const PRO := PK + "quaternius_props/"
const PIR := PK + "kenney_pirate/"

var noise: Texture2D
var cache: Dictionary = {}


func _initialize() -> void:
	noise = load(KIT_MAT + "tex_env_noise.tres")
	# -- nature,props,village,blender  (sem argumento: tudo)
	var only: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "nature,props,village,blender"
	if "nature" in only:
		_nature()
	if "props" in only:
		_props()
	if "village" in only:
		_village()
	if "blender" in only:
		_blender()
	print("pack kit: ok")
	quit(0)


# ------------------------------------------------------------------ materiais

func foliage(tex: Texture2D, tint: Color, extra: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_FOLIAGE
	m.set_shader_parameter(&"albedo_tex", tex)
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"alpha_cut", 0.45)
	m.set_shader_parameter(&"wind_strength", 0.10)
	m.set_shader_parameter(&"hue_variation", 0.08)
	m.set_shader_parameter(&"value_variation", 0.10)
	for k: String in extra:
		m.set_shader_parameter(StringName(k), extra[k])
	return m


func painted(tex: Texture2D, tint: Color, extra: Dictionary = {}, two_sided: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_PAINTED_2S if two_sided else SH_PAINTED
	m.set_shader_parameter(&"albedo_tex", tex)
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"tex_noise", noise)
	m.set_shader_parameter(&"macro_strength", 0.06)
	for k: String in extra:
		m.set_shader_parameter(StringName(k), extra[k])
	return m


func tex_of(mat: Material) -> Texture2D:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_texture
	return null


# ------------------------------------------------------------------ conversão

## Converte "src" em "name". rules: {prefixo do nome do material de origem: Material (ou Callable(mat)->Material)}.
## kind: "tree" (copa com normais esféricas/vento), "plant" (vento pela altura), "solid".
func conv(src: String, name: String, scale: float, rules: Dictionary, kind: String = "solid",
		opts: Dictionary = {}) -> ArrayMesh:
	var ps := load(src) as PackedScene
	if ps == null:
		push_error("não achei " + src)
		return null
	var root := ps.instantiate()
	# grupos por material de destino
	var groups: Dictionary = {} # key -> {mat, v, n, uv, c, idx, leaf}
	for mi_node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		var xf := _xf(mi, root)
		xf = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3.ZERO) * xf
		if opts.has("rotate_y"):
			xf = Transform3D(Basis(Vector3.UP, float(opts["rotate_y"])), Vector3.ZERO) * xf
		for s in mi.mesh.get_surface_count():
			var src_mat := mi.get_active_material(s)
			var src_name := src_mat.resource_name if src_mat != null else ""
			var dst: Variant = null
			var leaf := false
			for pre: String in rules:
				if src_name.begins_with(pre):
					dst = rules[pre]
					leaf = pre.begins_with("Leaves") or pre.begins_with("Grass") or pre.begins_with("Flowers") \
							or pre.begins_with("leaf:") or pre.begins_with("Card")
					break
			if dst == null and rules.has("*"):
				dst = rules["*"]
			if dst is Callable:
				dst = (dst as Callable).call(src_mat)
			if dst == null:
				continue # material descartado (ex.: vidro invisível)
			var key := str((dst as Resource).get_instance_id())
			if not groups.has(key):
				groups[key] = {"mat": dst, "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
					"c": PackedColorArray(), "idx": PackedInt32Array(), "leaf": leaf}
			var g: Dictionary = groups[key]
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var gv: PackedVector3Array = g["v"]
			var gn: PackedVector3Array = g["n"]
			var guv: PackedVector2Array = g["uv"]
			var gc: PackedColorArray = g["c"]
			var gi: PackedInt32Array = g["idx"]
			var base := gv.size()
			var nb := xf.basis.inverse().transposed()
			for i in verts.size():
				gv.append(xf * verts[i])
				gn.append((nb * (norms[i] if i < norms.size() else Vector3.UP)).normalized())
				guv.append(uvs[i] if i < uvs.size() else Vector2.ZERO)
				gc.append(cols[i] if i < cols.size() else Color.WHITE)
			if idx.is_empty():
				for i in verts.size():
					gi.append(base + i)
			else:
				for i in idx:
					gi.append(base + i)
			g["v"] = gv
			g["n"] = gn
			g["uv"] = guv
			g["c"] = gc
			g["idx"] = gi
	root.free()
	# base no chão e centrado em XZ (opcional)
	var aabb := AABB()
	var first := true
	for key: String in groups:
		for v: Vector3 in groups[key]["v"]:
			aabb = AABB(v, Vector3.ZERO) if first else aabb.expand(v)
			first = false
	var shift := Vector3(0, -aabb.position.y - float(opts.get("sink", 0.0)), 0)
	if opts.get("keep_origin", false):
		shift = Vector3.ZERO
	if opts.get("center", false):
		shift.x = -aabb.get_center().x
		shift.z = -aabb.get_center().z
	var height := aabb.size.y
	# centro/raio da copa (vértices de folha)
	var leaf_c := Vector3.ZERO
	var leaf_n := 0
	var leaf_min := INF
	var leaf_max := -INF
	for key: String in groups:
		if groups[key]["leaf"]:
			for v: Vector3 in groups[key]["v"]:
				leaf_c += v + shift
				leaf_n += 1
				leaf_min = minf(leaf_min, v.y + shift.y)
				leaf_max = maxf(leaf_max, v.y + shift.y)
	if leaf_n > 0:
		leaf_c /= leaf_n
	var imesh := ImporterMesh.new()
	var keys := groups.keys()
	# folhagem por último (ordem: tronco/sólidos, depois copa)
	keys.sort_custom(func(a: String, b: String) -> bool: return int(groups[a]["leaf"]) < int(groups[b]["leaf"]))
	for key: String in keys:
		var g: Dictionary = groups[key]
		var v: PackedVector3Array = g["v"]
		var n: PackedVector3Array = g["n"]
		var c: PackedColorArray = g["c"]
		for i in v.size():
			v[i] += shift
			var hrel := clampf(v[i].y / maxf(height, 0.01), 0.0, 1.0)
			if kind == "tree" and g["leaf"] and leaf_n > 0:
				var out := (v[i] - leaf_c)
				var sph := out.normalized()
				n[i] = n[i].lerp(sph, float(opts.get("sphere", 0.75))).normalized()
				var crown_rel := clampf((v[i].y - leaf_min) / maxf(leaf_max - leaf_min, 0.01), 0.0, 1.0)
				var outward := clampf(out.length() / maxf((leaf_max - leaf_min) * 0.6, 0.01), 0.0, 1.0)
				var ao := lerpf(0.5, 1.08, pow(crown_rel, 0.7)) * lerpf(0.72, 1.0, outward)
				c[i] = Color(ao, ao, ao, clampf(0.35 + hrel * 0.65, 0.0, 1.0))
			elif kind == "tree":
				var ao := lerpf(0.55, 1.0, clampf(hrel * 3.0, 0.0, 1.0))
				c[i] = Color(ao * c[i].r, ao * c[i].g, ao * c[i].b, hrel * 0.3)
			elif kind == "plant":
				var ao := lerpf(0.65, 1.05, hrel)
				c[i] = Color(ao, ao, ao, hrel)
			else:
				c[i] = Color(c[i].r, c[i].g, c[i].b, 0.0)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = g["uv"]
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_INDEX] = g["idx"]
		imesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, g["mat"])
	# LODs automáticos (a GPU troca por versões mais simples à distância)
	imesh.generate_lods(25.0, 60.0, [])
	var mesh := imesh.get_mesh()
	var path := OUT + name + ".res"
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(path)
	var tris := 0
	for s in mesh.get_surface_count():
		tris += mesh.surface_get_array_index_len(s) / 3
	print("  %-26s %s  superfícies=%d  triângulos=%d" % [name, (mesh.get_aabb().size).snapped(Vector3.ONE * 0.01),
			mesh.get_surface_count(), tris])
	return mesh


func _xf(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _tex(path: String) -> Texture2D:
	if not cache.has(path):
		cache[path] = load(path)
	return cache[path]


# ------------------------------------------------------------------ natureza

func _nature() -> void:
	var bark := painted(_tex(NAT + "Bark_NormalTree.png"), Color(0.95, 0.85, 0.75))
	var bark_tw := painted(_tex(NAT + "Bark_NormalTree.png"), Color(0.9, 0.78, 0.68))
	var leaf_tex := _tex(NAT + "Leaves_NormalTree_C.png")
	var pine_tex := _tex(NAT + "Leaf_Pine_C.png")
	var tw_tex := _tex(NAT + "Leaves_TwistedTree_C.png")
	# folhagem: tons quentes da paleta (verde-amarelado ao sol, verde fundo na sombra)
	# paleta unificada: gradiente pela oclusão (topo iluminado verde-amarelado quente, miolo verde fundo)
	var green := {"recolor_amount": 1.0, "recolor_dark": Color(0.16, 0.32, 0.12), "recolor_light": Color(0.74, 0.86, 0.34)}
	var leaf := foliage(leaf_tex, Color(1, 1, 1), green)
	var pine := foliage(pine_tex, Color(1, 1, 1), {"wind_strength": 0.06, "recolor_amount": 1.0,
		"recolor_dark": Color(0.1, 0.24, 0.13), "recolor_light": Color(0.52, 0.7, 0.28)})
	var pine_snow := foliage(pine_tex, Color(1.0, 1.0, 1.0), {"wind_strength": 0.05, "recolor_amount": 1.0,
		"recolor_dark": Color(0.25, 0.4, 0.33), "recolor_light": Color(0.95, 0.97, 1.0)})
	var tw := foliage(tw_tex, Color(1, 1, 1), green)
	var ipe_y := foliage(leaf_tex, Color(1, 1, 1), {"recolor_amount": 1.0, "recolor_dark": Color(0.86, 0.55, 0.08),
		"recolor_light": Color(1.0, 0.93, 0.42), "speckle_amount": 0.06, "speckle_color": Color(0.45, 0.6, 0.18),
		"backlight_color": Color(0.6, 0.45, 0.1)})
	var ipe_p := foliage(leaf_tex, Color(1, 1, 1), {"recolor_amount": 1.0, "recolor_dark": Color(0.52, 0.32, 0.62),
		"recolor_light": Color(0.96, 0.8, 1.0), "speckle_amount": 0.05, "speckle_color": Color(0.4, 0.55, 0.2),
		"backlight_color": Color(0.45, 0.3, 0.5)})
	var sakura := foliage(leaf_tex, Color(1, 1, 1), {"recolor_amount": 1.0, "recolor_dark": Color(0.72, 0.38, 0.48),
		"recolor_light": Color(1.0, 0.84, 0.88), "backlight_color": Color(0.5, 0.35, 0.4)})
	var olive := foliage(leaf_tex, Color(1, 1, 1), {"recolor_amount": 1.0, "recolor_dark": Color(0.22, 0.32, 0.24),
		"recolor_light": Color(0.66, 0.76, 0.58)})
	var birch := foliage(leaf_tex, Color(1, 1, 1), {"recolor_amount": 1.0, "recolor_dark": Color(0.3, 0.45, 0.14),
		"recolor_light": Color(0.86, 0.95, 0.42)})
	var jungle := foliage(tw_tex, Color(1, 1, 1), {"recolor_amount": 1.0, "recolor_dark": Color(0.07, 0.2, 0.1),
		"recolor_light": Color(0.4, 0.62, 0.24)})
	var dry := foliage(leaf_tex, Color(1, 1, 1), {"recolor_amount": 1.0, "recolor_dark": Color(0.45, 0.4, 0.12),
		"recolor_light": Color(0.95, 0.85, 0.42)})
	var bark_birch := painted(_tex(NAT + "Bark_NormalTree.png"), Color(1.7, 1.62, 1.5), {"detail": 0.6})
	print("árvores:")
	for i in 5:
		conv(NAT + "CommonTree_%d.gltf" % (i + 1), "pk_tree_common_%d" % (i + 1), 1.0,
				{"Bark": bark, "Leaves": leaf}, "tree")
		conv(NAT + "Pine_%d.gltf" % (i + 1), "pk_pine_%d" % (i + 1), 1.0, {"Bark": bark, "Leaves": pine}, "tree",
				{"sphere": 0.5})
	for i in [1, 3, 4]:
		conv(NAT + "Pine_%d.gltf" % i, "pk_pine_snow_%d" % i, 1.0, {"Bark": bark, "Leaves": pine_snow}, "tree",
				{"sphere": 0.5})
	for i in [1, 2, 3, 5]:
		conv(NAT + "CommonTree_%d.gltf" % i, "pk_ipe_yellow_%d" % i, 1.0, {"Bark": bark_tw, "Leaves": ipe_y}, "tree")
		conv(NAT + "CommonTree_%d.gltf" % i, "pk_ipe_purple_%d" % i, 1.0, {"Bark": bark_tw, "Leaves": ipe_p}, "tree")
	conv(NAT + "TwistedTree_1.gltf", "pk_ipe_giant", 0.95, {"Bark": bark_tw, "Leaves": ipe_y}, "tree")
	conv(NAT + "TwistedTree_3.gltf", "pk_ipe_giant_b", 0.95, {"Bark": bark_tw, "Leaves": ipe_y}, "tree")
	conv(NAT + "CommonTree_2.gltf", "pk_sakura_1", 0.85, {"Bark": bark_tw, "Leaves": sakura}, "tree")
	conv(NAT + "CommonTree_5.gltf", "pk_sakura_2", 0.85, {"Bark": bark_tw, "Leaves": sakura}, "tree")
	conv(NAT + "CommonTree_1.gltf", "pk_olive_1", 0.7, {"Bark": bark_tw, "Leaves": olive}, "tree")
	conv(NAT + "CommonTree_3.gltf", "pk_birch_1", 0.9, {"Bark": bark_birch, "Leaves": birch}, "tree")
	conv(NAT + "CommonTree_4.gltf", "pk_birch_2", 0.9, {"Bark": bark_birch, "Leaves": birch}, "tree")
	conv(NAT + "TwistedTree_2.gltf", "pk_jungle_1", 0.75, {"Bark": bark_tw, "Leaves": jungle}, "tree")
	conv(NAT + "TwistedTree_5.gltf", "pk_jungle_2", 0.75, {"Bark": bark_tw, "Leaves": jungle}, "tree")
	conv(NAT + "CommonTree_1.gltf", "pk_pequi_1", 0.8, {"Bark": bark_tw, "Leaves": dry}, "tree")
	# bordo (maple) de outono para o jardim japonês e ceiba (sumaúma) gigante para a mata mexicana
	var maple := foliage(leaf_tex, Color(1, 1, 1), {"recolor_amount": 1.0, "recolor_dark": Color(0.55, 0.12, 0.06),
		"recolor_light": Color(0.98, 0.45, 0.18), "backlight_color": Color(0.5, 0.2, 0.08)})
	conv(NAT + "CommonTree_2.gltf", "pk_maple_1", 0.75, {"Bark": bark_tw, "Leaves": maple}, "tree")
	conv(NAT + "CommonTree_5.gltf", "pk_maple_2", 0.7, {"Bark": bark_tw, "Leaves": maple}, "tree")
	conv(NAT + "TwistedTree_4.gltf", "pk_ceiba", 1.0, {"Bark": bark, "Leaves": jungle}, "tree")
	for i in 5:
		conv(NAT + "TwistedTree_%d.gltf" % (i + 1), "pk_twisted_%d" % (i + 1), 0.8, {"Bark": bark_tw, "Leaves": tw},
				"tree")
		conv(NAT + "DeadTree_%d.gltf" % (i + 1), "pk_deadtree_%d" % (i + 1), 0.6,
				{"Bark": painted(_tex(NAT + "Bark_DeadTree.png"), Color(0.9, 0.82, 0.74))}, "tree")
	print("arbustos, plantas, flores:")
	var leaves_tex := _tex(NAT + "Leaves.png")
	var gb := green.duplicate()
	gb["wind_strength"] = 0.06
	var bush_leaf := foliage(_tex(NAT + "Leaves_TwistedTree_C.png"), Color(1, 1, 1), gb)
	var bush_leaf2 := foliage(_tex(NAT + "Leaves_NormalTree_C.png"), Color(1, 1, 1), gb)
	var flowers := foliage(_tex(NAT + "Flowers.png"), Color(1, 1, 1), {"wind_strength": 0.08})
	conv(NAT + "Bush_Common.gltf", "pk_bush", 0.75, {"Leaves": bush_leaf}, "tree", {"sphere": 0.8})
	conv(NAT + "Bush_Common_Flowers.gltf", "pk_bush_flowers", 0.75, {"Leaves": bush_leaf2, "Flowers": flowers}, "tree",
			{"sphere": 0.8})
	conv(NAT + "Bush_Common.gltf", "pk_bush_dry", 0.7, {"Leaves": dry}, "tree", {"sphere": 0.8})
	conv(NAT + "Bush_Common.gltf", "pk_bush_snow", 0.65, {"Leaves": foliage(_tex(NAT + "Leaves_TwistedTree_C.png"),
			Color(1, 1, 1), {"recolor_amount": 0.6, "recolor_dark": Color(0.3, 0.45, 0.35), "recolor_light": Color(0.95, 0.97, 1.0)})},
			"tree", {"sphere": 0.8})
	conv(NAT + "Bush_Common.gltf", "pk_bush_jungle", 0.8, {"Leaves": jungle}, "tree", {"sphere": 0.8})
	var plant := foliage(leaves_tex, Color(1.0, 1.0, 0.9), {"wind_strength": 0.08})
	var grass := foliage(_tex(NAT + "Grass.png"), Color(0.95, 0.98, 0.82), {"wind_strength": 0.10, "wind_speed": 1.7,
		"use_instance_custom": true, "fade_start": 40.0, "fade_end": 48.0})
	var grass_gold := foliage(_tex(NAT + "Grass.png"), Color(1.15, 1.0, 0.6), {"wind_strength": 0.10, "wind_speed": 1.7,
		"use_instance_custom": true, "fade_start": 40.0, "fade_end": 48.0})
	var flowers_small := foliage(_tex(NAT + "Flowers.png"), Color(1, 1, 1), {"wind_strength": 0.1, "use_instance_custom": true,
		"fade_start": 40.0, "fade_end": 48.0})
	var leaves_small := foliage(leaves_tex, Color(1, 1, 0.92), {"wind_strength": 0.1, "use_instance_custom": true,
		"fade_start": 40.0, "fade_end": 48.0})
	conv(NAT + "Fern_1.gltf", "pk_fern", 0.55, {"Leaves": plant}, "plant")
	conv(NAT + "Plant_1.gltf", "pk_plant_1", 0.6, {"Leaves": plant}, "plant")
	conv(NAT + "Plant_1_Big.gltf", "pk_plant_1_big", 0.6, {"Leaves": plant}, "plant")
	conv(NAT + "Plant_7.gltf", "pk_plant_7", 0.7, {"Leaves": plant}, "plant")
	conv(NAT + "Clover_1.gltf", "pk_clover_1", 0.4, {"Leaves": leaves_small}, "plant")
	conv(NAT + "Grass_Common_Short.gltf", "pk_grass_short", 0.5, {"Grass": grass}, "plant")
	conv(NAT + "Grass_Common_Tall.gltf", "pk_grass_tall", 0.45, {"Grass": grass}, "plant")
	conv(NAT + "Grass_Wispy_Short.gltf", "pk_grass_wispy", 0.55, {"Grass": grass}, "plant")
	conv(NAT + "Grass_Wispy_Tall.gltf", "pk_grass_wispy_tall", 0.55, {"Grass": grass}, "plant")
	conv(NAT + "Grass_Wispy_Tall.gltf", "pk_grass_golden", 0.55, {"Grass": grass_gold}, "plant")
	conv(NAT + "Grass_Common_Tall.gltf", "pk_reeds", 0.6, {"Grass": grass}, "plant")
	conv(NAT + "Flower_3_Group.gltf", "pk_flowers_a", 0.45, {"Leaves": leaves_small, "Flowers": flowers_small}, "plant")
	conv(NAT + "Flower_4_Group.gltf", "pk_flowers_b", 0.42, {"Leaves": leaves_small, "Flowers": flowers_small}, "plant")
	conv(NAT + "Flower_3_Single.gltf", "pk_flower_single", 0.3, {"Leaves": leaves_small, "Flowers": flowers_small}, "plant")
	var lav := foliage(_tex(NAT + "Flowers.png"), Color(1, 1, 1), {"wind_strength": 0.1, "use_instance_custom": true,
		"recolor_amount": 0.85, "recolor_dark": Color(0.35, 0.22, 0.55), "recolor_light": Color(0.78, 0.62, 1.0)})
	conv(NAT + "Flower_4_Group.gltf", "pk_flowers_purple", 0.42, {"Leaves": leaves_small, "Flowers": lav}, "plant")
	var mush := foliage(_tex(NAT + "Mushrooms.png"), Color(1, 1, 1), {"wind_strength": 0.0, "use_alpha": false})
	conv(NAT + "Mushroom_Common.gltf", "pk_mushroom", 1.1, {"Mushrooms": mush}, "plant")
	conv(NAT + "Mushroom_Laetiporus.gltf", "pk_mushroom_shelf", 0.6, {"Mushrooms": mush}, "plant")
	var petals := foliage(_tex(NAT + "Flowers.png"), Color(1, 1, 1), {"wind_strength": 0.0, "use_instance_custom": true,
		"recolor_amount": 1.0, "recolor_dark": Color(0.85, 0.55, 0.05), "recolor_light": Color(1.0, 0.88, 0.3)})
	for i in [1, 2, 3, 5]:
		conv(NAT + "Petal_%d.gltf" % i, "pk_petals_%d" % i, 0.6, {"Flowers": petals}, "plant")
	print("pedras:")
	var moss := _tex("res://assets/environment/painted/textures/tex_grass_lush.png")
	var rock := painted(_tex(NAT + "Rocks_Diffuse.png"), Color(1.0, 0.96, 0.9), {"top_tex": moss, "top_amount": 0.18,
		"top_tile_m": 1.5, "top_tint": Color(0.95, 1.0, 0.8)})
	var rock_plain := painted(_tex(NAT + "Rocks_Diffuse.png"), Color(1.02, 0.97, 0.9))
	var rock_red := painted(_tex(NAT + "Rocks_Diffuse.png"), Color(1.15, 0.78, 0.6))
	var rock_sand := painted(_tex(NAT + "Rocks_Diffuse.png"), Color(1.15, 1.0, 0.8))
	var path := painted(_tex(NAT + "PathRocks_Diffuse.png"), Color(1.0, 0.97, 0.92))
	for i in 3:
		conv(NAT + "Rock_Medium_%d.gltf" % (i + 1), "pk_rock_moss_%d" % (i + 1), 0.7, {"Rocks": rock}, "solid",
				{"sink": 0.15})
		conv(NAT + "Rock_Medium_%d.gltf" % (i + 1), "pk_rock_%d" % (i + 1), 0.7, {"Rocks": rock_plain}, "solid",
				{"sink": 0.15})
	conv(NAT + "Rock_Medium_2.gltf", "pk_rock_red", 0.7, {"Rocks": rock_red}, "solid", {"sink": 0.15})
	conv(NAT + "Rock_Medium_3.gltf", "pk_rock_sand", 0.8, {"Rocks": rock_sand}, "solid", {"sink": 0.15})
	for n: String in ["Pebble_Round_1", "Pebble_Round_3", "Pebble_Square_2", "RockPath_Round_Small_1", "RockPath_Round_Thin",
			"RockPath_Square_Wide"]:
		conv(NAT + n + ".gltf", "pk_" + n.to_lower(), 1.0, {"PathRocks": path}, "solid")


# ------------------------------------------------------------------ props

func _props() -> void:
	print("props:")
	var furn := painted(_tex(PRO + "T_Trim_Furniture_BaseColor.png"), Color(1.02, 0.95, 0.85))
	var metal := painted(_tex(PRO + "T_Trim_Metal_BaseColor.png"), Color(0.9, 0.86, 0.8), {"roughness": 0.6})
	var cloth := painted(_tex(PRO + "T_Trim_Cloth_BaseColor.png"), Color(1.05, 0.98, 0.9), {}, true)
	var props_v := painted(_tex(PRO + "T_Trim_Props_BaseColor.png") if ResourceLoader.exists(PRO + "T_Trim_Props_BaseColor.png")
			else _tex(PRO + "T_Trim_Furniture_BaseColor.png"), Color(1, 1, 1))
	var rules := {"MI_Trim_Furniture": furn, "MI_Trim_Metal": metal, "MI_Trim_Cloth": cloth, "MI_Banner": cloth,
		"MI_Trim_Props": props_v, "*": furn}
	for n: String in ["Barrel", "Barrel_Apples", "Crate_Wooden", "FarmCrate_Apple", "FarmCrate_Carrot", "FarmCrate_Empty",
			"Bench", "Lantern_Wall", "Torch_Metal", "Bucket_Wooden_1", "Vase_2", "Vase_4",
			"Dummy", "Table_Large", "Bag", "Chest_Wood", "Barrel_Holder", "Banner_1", "Banner_1_Cloth", "Pot_1"]:
		conv(PRO + n + ".gltf", "pk_" + n.to_lower(), 1.0, rules, "solid")
	var stall_rules := {"MI_Banner": null, "MI_Trim_Furniture": furn, "MI_Trim_Metal": metal, "*": furn}
	for n: String in ["Stall_Empty", "Stall_Cart_Empty"]:
		conv(PRO + n + ".gltf", "pk_" + n.to_lower(), 1.0, stall_rules, "solid")
	# barcos e píer (Kenney): paleta de cores do pacote, esquentada
	var kmat := painted(_tex(PIR + "Textures/colormap.png"), Color(1.02, 0.95, 0.86), {"detail": 1.0}, true)
	for n: String in ["ship-small", "ship-medium", "boat-row-small", "boat-row-large", "structure-platform-dock",
			"structure-platform-dock-small", "palm-detailed-bend", "palm-detailed-straight"]:
		conv(PIR + n + ".glb", "pk_" + n.replace("-", "_"), 0.8 if n.begins_with("ship") else 1.0, {"*": kmat},
				"tree" if n.begins_with("palm") else "solid")


# ------------------------------------------------------------------ vila (casas coloniais)

func _village() -> void:
	print("vila:")
	var plaster := painted(_tex("res://assets/environment/painted/textures/tex_plaster.png"), Color(1.0, 0.96, 0.88),
			{"triplanar": true, "tile_m": 3.0, "use_instance_tint": true, "grime_height": 0.9,
			"grime_color": Color(0.8, 0.66, 0.5), "macro_strength": 0.08})
	var trim := painted(_tex(VIL + "T_WoodTrim_BaseColor.png"), Color(0.62, 0.46, 0.36))
	# molduras/venezianas coloridas (cor por instância)
	var trim_col := painted(_tex("res://assets/environment/painted/textures/tex_wood.png"), Color(1.25, 1.25, 1.25),
			{"use_instance_tint": true, "detail": 0.3, "uv_scale": Vector2(0.5, 0.5)})
	var azulejo := painted(_tex("res://assets/environment/painted/textures/tex_azulejo.png"), Color(1, 0.98, 0.94),
			{"triplanar": true, "tile_m": 1.2, "macro_strength": 0.04})
	var rocktrim := painted(_tex(VIL + "T_RockTrim_BaseColor.png"), Color(1.1, 1.04, 0.95))
	var tiles := painted(_tex(VIL + "T_RoundTiles_BaseColor.png"), Color(0.86, 0.64, 0.54), {"macro_strength": 0.14,
			"detail": 0.8}, true)
	var glass := painted(_tex("res://assets/environment/painted/textures/tex_plaster.png"), Color(0.22, 0.28, 0.36),
			{"roughness": 0.35})
	var metal := painted(_tex(VIL + "T_MetalOrnaments_BaseColor.png"), Color(0.7, 0.66, 0.62))
	var vine := foliage(_tex(VIL + "T_VineLeaf_png.png"), Color(1, 1, 0.9), {"wind_strength": 0.03})
	var rules := {"MI_Plaster": plaster, "MI_WoodTrim_Wear": trim_col, "MI_WoodTrim": trim, "MI_Brick": azulejo,
		"MI_RedBrick": azulejo, "MI_UnevenBrick": rocktrim, "MI_RockTrim": rocktrim, "MI_RoundTiles": tiles,
		"MI_WindowGlass": glass, "MI_MetalOrnaments": metal, "MI_Vine": vine, "*": trim}
	for f: String in DirAccess.get_files_at(VIL):
		if not f.ends_with(".gltf"):
			continue
		var n := f.get_basename()
		conv(VIL + f, "pkv_" + n.to_lower(), 1.0, rules, "plant" if n.begins_with("Prop_Vine") else "solid",
				{"keep_origin": true})


# ------------------------------------------------------------------ modelos originais (Blender)

func _blender() -> void:
	print("blender (originais):")
	var BL := "res://assets/environment/blender/"
	var palm := foliage(_tex(NAT + "Leaves_NormalTree_C.png"), Color(1, 1, 1), {"use_alpha": false, "recolor_amount": 1.0,
		"recolor_dark": Color(0.18, 0.34, 0.14), "recolor_light": Color(0.66, 0.8, 0.32), "recolor_ao_mix": 0.85,
		"wind_strength": 0.08})
	var dry := foliage(_tex(NAT + "Leaves_NormalTree_C.png"), Color(1, 1, 1), {"use_alpha": false, "recolor_amount": 1.0,
		"recolor_dark": Color(0.42, 0.28, 0.12), "recolor_light": Color(0.8, 0.62, 0.32), "wind_strength": 0.04})
	var bark := painted(_tex(NAT + "Bark_NormalTree.png"), Color(0.95, 0.9, 0.86), {"detail": 0.6})
	var fruit := painted(_tex(NAT + "Bark_NormalTree.png"), Color(0.8, 0.45, 0.3), {"detail": 0.4})
	for n: String in ["buriti_a", "buriti_b"]:
		if ResourceLoader.exists(BL + n + ".glb"):
			conv(BL + n + ".glb", n, 1.0, {"Leaves_BuritiDry": dry, "Leaves": palm, "Bark": bark, "Fruit": fruit}, "tree",
					{"sphere": 0.35})
	# palmeiras macias (cards pintados com alfa)
	var C := "res://assets/environment/painted/cards/"
	var fan := foliage(_tex(C + "card_palm_fan.png"), Color(1, 1, 1), {"alpha_cut": 0.4, "recolor_amount": 0.55,
		"recolor_dark": Color(0.2, 0.38, 0.14), "recolor_light": Color(0.72, 0.84, 0.36), "recolor_ao_mix": 0.4,
		"wind_strength": 0.07})
	var fan_dry := foliage(_tex(C + "card_palm_fan.png"), Color(1, 1, 1), {"alpha_cut": 0.4, "recolor_amount": 1.0,
		"recolor_dark": Color(0.42, 0.28, 0.12), "recolor_light": Color(0.82, 0.64, 0.34), "recolor_ao_mix": 0.2,
		"wind_strength": 0.03})
	var frond := foliage(_tex(C + "card_palm_frond.png"), Color(1, 1, 1), {"alpha_cut": 0.4, "recolor_amount": 0.5,
		"recolor_dark": Color(0.2, 0.38, 0.14), "recolor_light": Color(0.75, 0.86, 0.38), "recolor_ao_mix": 0.4,
		"wind_strength": 0.08})
	var pbark := painted(_tex(NAT + "Bark_NormalTree.png"), Color(0.95, 0.9, 0.84), {"detail": 0.5})
	var stalk := painted(_tex(NAT + "Bark_NormalTree.png"), Color(0.8, 0.9, 0.6), {"detail": 0.3})
	for n: String in ["buriti_soft_a", "buriti_soft_b", "palm_soft_a", "palm_soft_b"]:
		if ResourceLoader.exists(BL + n + ".glb"):
			conv(BL + n + ".glb", n, 1.0, {"Card_FanDry": fan_dry, "Card_Fan": fan, "Card_Frond": frond,
					"Bark_Stalk": stalk, "Bark": pbark, "Fruit": fruit}, "tree", {"sphere": 0.45})
	var crystal := ShaderMaterial.new()
	crystal.shader = load("res://assets/shaders/env_crystal.gdshader")
	crystal.set_shader_parameter(&"deep_color", Color(0.12, 0.42, 0.92))
	crystal.set_shader_parameter(&"light_color", Color(0.58, 0.94, 1.0))
	crystal.set_shader_parameter(&"rim_color", Color(0.92, 0.98, 1.0))
	crystal.set_shader_parameter(&"emission_strength", 2.6)
	crystal.set_shader_parameter(&"pulse_speed", 1.1)
	crystal.set_shader_parameter(&"height_m", 3.6)
	var stone := painted(_tex(NAT + "Rocks_Diffuse.png"), Color(1.05, 1.0, 0.94))
	if ResourceLoader.exists(BL + "crystal_cluster.glb"):
		conv(BL + "crystal_cluster.glb", "crystal_cluster", 1.0, {"Crystal": crystal, "Stone": stone}, "solid")
	for f: String in DirAccess.get_files_at(BL):
		if (f.begins_with("lm_") or f.begins_with("camp_") or f.begins_with("vg_")) and f.ends_with(".glb"):
			conv(BL + f, f.get_basename(), 1.0, _landmark_rules(), "solid", {"keep_origin": true})


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var key := "emit|" + c.to_html()
	if not cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		m.roughness = 0.6
		cache[key] = m
	return cache[key]


## Materiais dos marcos das nações (nomes dos materiais no Blender: Plaster_*, Wood_*, Stone_*, Roof_*, Cloth_*,
## Thatch, Gold, Lacquer_*, Tile_Azulejo, Sand_*). A cor vem do próprio material do Blender (tinta).
func _landmark_rules() -> Dictionary:
	var P := "res://assets/environment/painted/textures/"
	var mk := func(tex: String, extra: Dictionary, two: bool) -> Callable:
		return func(src: Material) -> Material:
			var c := Color(1, 1, 1)
			if src is BaseMaterial3D:
				c = (src as BaseMaterial3D).albedo_color
			var key := "%s|%s" % [tex, c.to_html()]
			if not cache.has(key):
				cache[key] = painted(_tex(tex), c * 1.25, extra, two)
			return cache[key]
	return {
		"Plaster": mk.call(P + "tex_plaster.png", {"triplanar": true, "tile_m": 3.0, "grime_height": 0.8}, false),
		"Stone": mk.call(P + "tex_rock.png", {"triplanar": true, "tile_m": 3.5, "detail": 0.85}, false),
		"Sand": mk.call(P + "tex_rock.png", {"triplanar": true, "tile_m": 4.0, "detail": 0.6}, false),
		"Wood": mk.call(VIL + "T_WoodTrim_BaseColor.png", {"triplanar": true, "tile_m": 1.6}, false),
		"Lacquer": mk.call(VIL + "T_WoodTrim_BaseColor.png", {"triplanar": true, "tile_m": 1.6, "detail": 0.35}, false),
		"Roof": mk.call(VIL + "T_RoundTiles_BaseColor.png", {"triplanar": true, "tile_m": 2.0}, true),
		"Thatch": mk.call(P + "tex_thatch.png", {"triplanar": true, "tile_m": 2.0}, true),
		"Cloth": mk.call(P + "tex_plaster.png", {"triplanar": true, "tile_m": 2.0, "detail": 0.5}, true),
		"Dune": mk.call(P + "tex_sand.png", {"triplanar": true, "tile_m": 5.0, "detail": 0.8}, false),
		"Ember": _emissive(Color(1.0, 0.45, 0.12), 3.5),
		"Lamp_Glow": _emissive(Color(1.0, 0.78, 0.42), 2.2),
		"Sign_Board": painted(_tex(VIL + "T_WoodTrim_BaseColor.png"), Color(1.3, 1.3, 1.3), {"triplanar": true,
			"tile_m": 1.2, "detail": 0.5, "use_instance_tint": true}),
		"Turf": mk.call(P + "tex_grass_lush.png", {"triplanar": true, "tile_m": 2.5, "detail": 0.8}, true),
		"Tile_Azulejo": mk.call(P + "tex_azulejo.png", {"triplanar": true, "tile_m": 1.2}, false),
		"Gold": mk.call(P + "tex_plaster.png", {"triplanar": true, "tile_m": 2.0, "detail": 0.3, "roughness": 0.4}, false),
		"Leaves": foliage(_tex(NAT + "Leaves_NormalTree_C.png"), Color(1, 1, 1), {"use_alpha": false, "recolor_amount": 1.0,
			"recolor_dark": Color(0.16, 0.32, 0.12), "recolor_light": Color(0.7, 0.84, 0.34)}),
		"*": mk.call(P + "tex_plaster.png", {"triplanar": true, "tile_m": 3.0}, false),
	}
