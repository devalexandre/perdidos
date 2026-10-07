extends SceneTree
## Constroi e salva res://scenes/maps/city_awakening.tscn (Porto do Despertar, GDD 4.2) com o
## navmesh JA ASSADO. Reexecutavel. Rodar:
##   godot --headless --path game --script res://tools/art/build_city.gd
##
## Geometria low-poly montada por codigo e agrupada em 1 malha por material (poucas draw calls).
## VISUAL (GDD §17.0.A, 27/09/2026): materiais PINTADOS do kit (assets/environment/painted, docs/arte-cenario.md),
## arvores/arbustos/props/flores do kit em Decor/ (MultiMesh por malha), luz EnvLook. A geometria de jogo (chao,
## obstrucoes, navmesh) nao muda: pecas trocadas pelo kit sao "silenciadas" (mute_geo) mantendo a obstrucao e o RNG.
## UV em coordenadas de mundo na densidade TEXELS_PER_UNIT (48 px/unidade, GDD 17.2 revisado):
## uma textura de TEX_SIZE px cobre TEX_SIZE / TEXELS_PER_UNIT unidades.
## Eixos: X = leste (rio do lado +X), Z = sul, Y = cima. Praca em y = 0, origem no centro.

const SCENE_PATH := "res://scenes/maps/city_awakening.tscn"
const GEO_DIR := "res://scenes/maps/city_awakening"
const MAT_DIR := "res://assets/environment/materials"
const TEX_DIR := "res://assets/environment/textures"
const MAP_SCRIPT := "res://scripts/shared/map.gd"

const LAND_MIN_X := -60.0
const QUAY_X := 36.0 # borda do cais; rio de QUAY_X ate FAR_BANK_X
const FAR_BANK_X := 72.0
const HALF := 60.0
const WATER_Y := -0.7
const NAV_CELL := 0.2
const TEXELS_PER_UNIT := 48.0
const PLAZA_R := 16.0
const TREE_POS := Vector3(0, 0, -1.5)
const CRYSTAL_POS := Vector3(0.3, 0, 1.9)
const SPAWN_POS := Vector3(0, 0, 5.5)
const DONA_ANA_POS := Vector3(6.5, 0, 2.5)
const TEX_SIZE := 64.0 # lado das texturas de tools/art/gen_textures.py
const UV_PER_UNIT := TEXELS_PER_UNIT / TEX_SIZE
const AGENT_RADIUS := 0.4

# paleta mestra (tons usados em materiais de cor chapada)
const C_BLUE_1 := Color8(28, 42, 90)
const C_BLUE_2 := Color8(47, 85, 168)
const C_BLUE_3 := Color8(90, 144, 224)
const C_TEAL_2 := Color8(42, 110, 110)
const C_TEAL_3 := Color8(79, 168, 160)
const C_GREEN_2 := Color8(47, 107, 62)
const C_GREEN_3 := Color8(90, 160, 72)
const C_YELLOW_3 := Color8(230, 180, 58)
const C_YELLOW_4 := Color8(250, 229, 140)
const C_RED_2 := Color8(156, 42, 38)
const C_RED_3 := Color8(217, 85, 58)
const C_RED_4 := Color8(245, 154, 106)
const C_PINK_3 := Color8(224, 122, 160)
const C_PURPLE_3 := Color8(142, 102, 196)
const C_WOOD_1 := Color8(58, 36, 24)
const C_WOOD_2 := Color8(107, 66, 38)
const C_STONE_3 := Color8(140, 135, 148)
const C_WHITE := Color8(252, 250, 245)
const C_PARCH_4 := Color8(242, 230, 200)

var mats: Dictionary = {} # nome -> StandardMaterial3D
var deco_rng := RandomNumberGenerator.new() # enfeites do passe visual (nao altera o layout do rng principal)
var props: Array = [] # [textura, posicao, escala] sprites de enfeite (passe visual)
var tools: Dictionary = {} # nome -> SurfaceTool
var walk_faces := PackedVector3Array() # triangulos caminhaveis (fonte do navmesh)
var obstructions: Array = [] # [PackedVector3Array contorno, elevacao, altura]
var colliders: Array = [] # [centro, tamanho] caixas da camada 1
var rng := RandomNumberGenerator.new()
var uv_mult := 1.0 # multiplicador temporario de UV (ex.: listras de toldo mais largas)
## Kit pintado: enquanto true, a geometria emitida vai para o lixo (a peca e trocada por uma malha do kit).
var mute_geo := false
## RNG proprio das casas do kit (nao mexe no RNG do layout nem no dos enfeites).
var house_rng := RandomNumberGenerator.new()
## Instancias do kit: [nome da malha em assets/environment/painted/meshes, Transform3D]
var kit_items: Array = []
## Canteiros de flores/capim do kit: [centro, raio, densidade]
var kit_beds: Array = []
const KIT := "res://assets/environment/painted/"
## Materiais de "mancha" no chão (borda macia): nome -> render_priority (ordem de empilhamento). Essas peças ganham
## uma franja externa com alfa 0 na cor de vértice (shaders *_decal) — sem borda dura de polígono.
var decal_mats: Dictionary = {}
const FEATHER_MIN := 0.9
const FEATHER_MAX := 2.4


func _initialize() -> void:
	rng.seed = 20260927
	deco_rng.seed = 4242
	house_rng.seed = 777
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEO_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	clean_dir(GEO_DIR)
	decal_mats = {"garden": 1, "sand": 1}
	_make_materials()
	_build_world()
	var root := _assemble()
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack falhou: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, SCENE_PATH)
	print("saved ", SCENE_PATH, " err=", err)
	root.free()
	quit(0 if err == OK else 1)


## Apaga as malhas geradas antes (geo_*.res, mm_*.res, spr_*.res): nada de arquivo órfão de outra versão.
static func clean_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".res") and (f.begins_with("geo_") or f.begins_with("mm_") or f.begins_with("spr_")):
			d.remove(f)


# ---------------------------------------------------------------- materiais
func _tex_mat(mat_name: String, tex: String, cull_off: bool = false) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("%s/%s.png" % [TEX_DIR, tex]) as Texture2D
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if cull_off:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[mat_name] = m


func _col_mat(mat_name: String, c: Color, cull_off: bool = false) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if cull_off:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[mat_name] = m


func _make_materials() -> void:
	_tex_mat("cobble", "tex_cobblestone_01")
	_tex_mat("grass", "tex_grass_flowers_01")
	_tex_mat("sand", "tex_wet_sand_01")
	_tex_mat("wall_white", "tex_whitewash_wall_01")
	_tex_mat("wall_yellow", "tex_painted_wall_yellow_01")
	_tex_mat("wall_pink", "tex_painted_wall_pink_01")
	_tex_mat("wall_blue", "tex_painted_wall_blue_01")
	_tex_mat("wall_green", "tex_painted_wall_green_01")
	_tex_mat("roof", "tex_clay_roof_tile_01", true)
	_tex_mat("azulejo", "tex_azulejo_01")
	_tex_mat("wood", "tex_wood_planks_01")
	_tex_mat("hull", "tex_wood_planks_01", true)
	var wsh := ShaderMaterial.new()
	wsh.shader = load("res://assets/environment/shaders/water_pixel.gdshader") as Shader
	wsh.set_shader_parameter(&"albedo_tex", load("%s/tex_water_01.png" % TEX_DIR))
	mats["water"] = wsh
	var mc := StandardMaterial3D.new()
	mc.albedo_texture = load("%s/tex_magic_circle_01.png" % TEX_DIR) as Texture2D
	mc.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # kit pintado: brilho suave, sem pixel
	mc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mc.alpha_scissor_threshold = 0.5
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mc.albedo_color = Color(1.9, 1.65, 1.2)
	mats["magic_circle"] = mc
	_tex_mat("stone", "tex_stone_wall_01")
	_tex_mat("leaves", "tex_leaves_01")
	_tex_mat("ipe_yellow", "tex_ipe_yellow_01")
	_tex_mat("ipe_purple", "tex_ipe_purple_01")
	_tex_mat("calcada", "tex_calcada_waves_01")
	_tex_mat("awning_red", "tex_awning_red_01", true)
	_tex_mat("awning_teal", "tex_awning_teal_01", true)
	_tex_mat("awning_yellow", "tex_awning_yellow_01", true)
	_tex_mat("awning_blue", "tex_awning_blue_01", true)
	_tex_mat("awning_green", "tex_awning_green_01", true)
	_col_mat("frame_teal", C_TEAL_2)
	_col_mat("frame_magenta", Color8(168, 64, 106))
	_col_mat("stone_trim", Color8(242, 230, 200))
	_col_mat("roof_ridge", Color8(156, 42, 38))
	_col_mat("pot", Color8(176, 113, 90))
	_col_mat("palm", C_GREEN_3, true)
	_col_mat("palm_dark", C_GREEN_2, true)
	var lg := StandardMaterial3D.new()
	lg.albedo_color = C_YELLOW_4
	lg.emission_enabled = true
	lg.emission = C_YELLOW_4
	lg.emission_energy_multiplier = 0.8
	mats["lamp_glow"] = lg
	_col_mat("frame_blue", C_BLUE_2)
	_col_mat("frame_yellow", C_YELLOW_3)
	_col_mat("frame_green", C_GREEN_2)
	_col_mat("frame_red", C_RED_2)
	_col_mat("glass", C_BLUE_1)
	_col_mat("trunk", C_WOOD_2)
	_col_mat("dark_wood", C_WOOD_1)
	_col_mat("cloth_red", C_RED_3, true)
	_col_mat("cloth_yellow", C_YELLOW_4, true)
	_col_mat("cloth_teal", C_TEAL_3, true)
	_col_mat("sail", C_PARCH_4, true)
	_col_mat("fruit_orange", C_RED_4)
	_col_mat("fruit_red", C_RED_3)
	_col_mat("fruit_yellow", C_YELLOW_3)
	_col_mat("fruit_green", C_GREEN_3)
	_col_mat("fruit_purple", C_PURPLE_3)
	_col_mat("flower_pink", C_PINK_3)
	# copas e telhados somem (dither) quando a camera orbital chega muito perto/entra neles
	# ipe amarelo luminoso como na ancora 4 (sem o tom oliva da luz ambiente azulada)
	var ipm := mats["ipe_yellow"] as StandardMaterial3D
	ipm.emission_enabled = true
	ipm.emission_texture = ipm.albedo_texture
	ipm.emission_energy_multiplier = 0.35
	for k: String in ["ipe_yellow", "ipe_purple", "leaves", "roof"]:
		var fm := mats[k] as StandardMaterial3D
		fm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		fm.distance_fade_min_distance = 3.0
		fm.distance_fade_max_distance = 7.0
	mats["crystal"] = _make_crystal_material()
	_paint_materials()
	for k: String in mats:
		ResourceSaver.save(mats[k], "%s/mat_city_%s.tres" % [MAT_DIR, k])
		(mats[k] as Resource).take_over_path("%s/mat_city_%s.tres" % [MAT_DIR, k])


## Cria o material do cristal de renascimento com shader pulsante e emissivo celestial.
func _make_crystal_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/env_crystal.gdshader")
	m.set_shader_parameter(&"deep_color", Color(0.12, 0.42, 0.92))
	m.set_shader_parameter(&"light_color", Color(0.58, 0.94, 1.0))
	m.set_shader_parameter(&"rim_color", Color(0.92, 0.98, 1.0))
	m.set_shader_parameter(&"emission_strength", 2.6)
	m.set_shader_parameter(&"pulse_speed", 1.1)
	m.set_shader_parameter(&"height_m", 3.6)
	return m


## Kit pintado (GDD §17.0.A): troca os materiais pixel art por materiais pintados (cópias tingidas do kit).
## UV da geometria = metros × UV_PER_UNIT; tile_uv(m) converte "metros por repetição" em uv_scale.
func _kit(name: String) -> ShaderMaterial:
	return (load(KIT + "materials/mat_%s.tres" % name) as ShaderMaterial).duplicate()


func _kit_tint(name: String, tint: Color, extra: Dictionary = {}) -> ShaderMaterial:
	var m := _kit(name)
	m.set_shader_parameter(&"tint", tint)
	for k: String in extra:
		m.set_shader_parameter(StringName(k), extra[k])
	return m


static func tile_uv(meters: float) -> Vector2:
	return Vector2.ONE / (meters * UV_PER_UNIT)


## Material pintado de duas faces com a textura dada (toldos, velas, cascos, telhados).
func _kit_2s(tex: String, tint: Color, extra: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/env_painted_2s.gdshader")
	m.set_shader_parameter(&"albedo_tex", load(tex if tex.begins_with("res://") else KIT + "textures/" + tex))
	m.set_shader_parameter(&"tex_noise", load(KIT + "materials/tex_env_noise.tres"))
	m.set_shader_parameter(&"tint", tint)
	for k: String in extra:
		m.set_shader_parameter(StringName(k), extra[k])
	return m


func _paint_materials() -> void:
	var painted := {
		"cobble": _kit_2s("tex_cobble.png", Color(1.06, 1.01, 0.94),
				{"triplanar": true, "tile_m": 3.6, "detail": 0.95, "macro_strength": 0.16}),
		"calcada": _kit_2s("tex_paving.png", Color(1.18, 1.12, 1.03),
				{"triplanar": true, "tile_m": 3.2, "detail": 0.96, "macro_strength": 0.12}),
		"sand": _kit("ground_sand"),
		"wall_white": _kit("plaster_warm"),
		"wall_yellow": _kit("plaster_ochre"),
		"wall_pink": _kit("plaster_rose"),
		"wall_blue": _kit_tint("plaster_warm", Color(0.84, 0.9, 0.95)),
		"wall_green": _kit_tint("plaster_warm", Color(0.86, 0.93, 0.78)),
		"roof": _kit_2s("tex_roof_canal.png", Color(1.0, 0.9, 0.84), {"uv_scale": tile_uv(2.6), "macro_strength": 0.18}),
		"roof_ridge": _kit_2s("tex_roof_canal.png", Color(0.8, 0.68, 0.62), {"uv_scale": tile_uv(2.6)}),
		"azulejo": _kit("azulejo"),
		"wood": _kit_tint("wood", Color(0.95, 0.88, 0.8), {"uv_scale": tile_uv(1.8)}),
		"hull": _kit_2s("tex_wood.png", Color(0.62, 0.5, 0.42), {"uv_scale": tile_uv(1.8)}),
		"dark_wood": _kit_tint("wood_dark", Color(0.62, 0.5, 0.42), {"uv_scale": tile_uv(1.8)}),
		"stone": _kit_tint("stonewall", Color(1.12, 1.06, 0.98)),
		"stone_trim": _kit_tint("stonewall", Color(1.22, 1.16, 1.05)),
		"trunk": _kit_tint("bark", Color(0.95, 0.85, 0.78), {"uv_scale": tile_uv(1.5)}),
		"leaves": _kit("canopy_broad"),
		"ipe_yellow": _kit("canopy_ipe"),
		"ipe_purple": _kit("canopy_ipe_purple"),
		"palm": _kit("palm_leaf"),
		"palm_dark": _kit("palm_leaf_dark"),
		"pot": _kit_tint("plaster_warm", Color(0.85, 0.5, 0.38), {"triplanar": true, "tile_m": 1.5}),
		"glass": _kit_tint("plaster_warm", Color(0.2, 0.26, 0.34), {"roughness": 0.35, "grime_height": 0.0}),
		"water": load(KIT + "materials/mat_water.tres"),
		"sail": _kit_2s("tex_plaster.png", Color(1.0, 0.94, 0.82), {"triplanar": true, "tile_m": 3.0}),
		"crystal": _make_crystal_material(),
		"awning_red": _kit_2s("res://assets/environment/textures/tex_awning_red_01.png", Color(1.05, 0.98, 0.95), {"detail": 0.95}),
		"awning_teal": _kit_2s("res://assets/environment/textures/tex_awning_teal_01.png", Color(1.0, 1.05, 1.02), {"detail": 0.95}),
		"awning_yellow": _kit_2s("res://assets/environment/textures/tex_awning_yellow_01.png", Color(1.08, 1.04, 0.92), {"detail": 0.95}),
		"awning_blue": _kit_2s("res://assets/environment/textures/tex_awning_blue_01.png", Color(1.0, 1.0, 1.08), {"detail": 0.95}),
		"awning_green": _kit_2s("res://assets/environment/textures/tex_awning_green_01.png", Color(0.98, 1.05, 0.95), {"detail": 0.95}),
	}
	# molduras, panos e frutas: madeira/pano pintados tingidos com a cor original (sem cor chapada)
	for k: String in ["frame_teal", "frame_magenta", "frame_blue", "frame_yellow", "frame_green", "frame_red"]:
		var c: Color = (mats[k] as StandardMaterial3D).albedo_color
		painted[k] = _kit_tint("wood", c.lerp(Color(1, 1, 1), 0.15) * 1.6, {"uv_scale": tile_uv(1.2), "detail": 0.5})
	for k: String in ["cloth_red", "cloth_yellow", "cloth_teal", "flower_pink", "fruit_orange", "fruit_red", "fruit_yellow",
			"fruit_green", "fruit_purple"]:
		var c: Color = (mats[k] as StandardMaterial3D).albedo_color
		painted[k] = _kit_2s("tex_plaster.png", c * 1.1, {"triplanar": true, "tile_m": 2.0, "detail": 0.5})
	var grass := _kit("terrain")
	grass.set_shader_parameter(&"splat_source", 0)
	painted["grass"] = grass
	var garden := _kit("terrain")
	garden.set_shader_parameter(&"splat_source", 0)
	garden.set_shader_parameter(&"tex_grass", load(KIT + "textures/tex_grass_lush.png"))
	garden.shader = load("res://assets/shaders/env_terrain_decal.gdshader")
	garden.render_priority = 1
	painted["garden"] = garden
	var sand: ShaderMaterial = _kit("ground_sand")
	sand.shader = load("res://assets/shaders/env_painted_decal.gdshader")
	sand.render_priority = 1
	painted["sand"] = sand
	for k: String in painted:
		mats[k] = painted[k]


# ---------------------------------------------------------------- primitivas
func _st(mat_name: String) -> SurfaceTool:
	if mute_geo:
		var trash := SurfaceTool.new()
		trash.begin(Mesh.PRIMITIVE_TRIANGLES)
		return trash
	if not tools.has(mat_name):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[mat_name] = st
	return tools[mat_name]


func _uv(p: Vector3, t: Vector3, b: Vector3) -> Vector2:
	return Vector2(p.dot(t), -p.dot(b)) * UV_PER_UNIT * uv_mult


## Quad com cantos a,b,c,d em sentido anti-horario visto de fora.
func quad(mat_name: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(d - a).normalized()
	var t := _tangent(n, (b - a).normalized())
	var bt := n.cross(t).normalized()
	_tri_raw(mat_name, [a, d, c], n, t, bt)
	_tri_raw(mat_name, [a, c, b], n, t, bt)


func tri(mat_name: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	var t := _tangent(n, (b - a).normalized())
	var bt := n.cross(t).normalized()
	_tri_raw(mat_name, [a, c, b], n, t, bt)


## Faces horizontais usam UV alinhado ao mundo (x, z) para o padrao continuar entre pecas.
func _tangent(n: Vector3, edge: Vector3) -> Vector3:
	if absf(n.y) > 0.99:
		return Vector3.RIGHT
	return edge


func _tri_raw(mat_name: String, pts: Array, n: Vector3, t: Vector3, bt: Vector3) -> void:
	var st := _st(mat_name)
	for p: Vector3 in pts:
		st.set_color(Color.WHITE)
		st.set_normal(n)
		st.set_uv(_uv(p, t, bt))
		st.add_vertex(p)


func _smooth_tri(mat_name: String, pts: Array, center: Vector3) -> void:
	# normal suave (volume arredondado) + UV por projecao do eixo dominante da face (sem esticar)
	var st := _st(mat_name)
	var fn: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).cross((pts[2] as Vector3) - (pts[0] as Vector3)).abs()
	for p: Vector3 in pts:
		st.set_color(Color.WHITE)
		st.set_normal((p - center).normalized())
		var uv: Vector2
		if fn.y >= fn.x and fn.y >= fn.z:
			uv = Vector2(p.x, p.z)
		elif fn.x >= fn.z:
			uv = Vector2(p.z, -p.y)
		else:
			uv = Vector2(p.x, -p.y)
		st.set_uv(uv * UV_PER_UNIT)
		st.add_vertex(p)


## Caixa com base em pos.y; yaw em radianos.
func box(mat_name: String, pos: Vector3, size: Vector3, yaw: float = 0.0, top_mat: String = "", bottom: bool = false) -> void:
	var tr := Transform3D(Basis(Vector3.UP, yaw), pos)
	var x := size.x * 0.5
	var z := size.z * 0.5
	var h := size.y
	var P := func(px: float, py: float, pz: float) -> Vector3: return tr * Vector3(px, py, pz)
	quad(mat_name, P.call(-x, 0, z), P.call(x, 0, z), P.call(x, h, z), P.call(-x, h, z))
	quad(mat_name, P.call(x, 0, -z), P.call(-x, 0, -z), P.call(-x, h, -z), P.call(x, h, -z))
	quad(mat_name, P.call(x, 0, z), P.call(x, 0, -z), P.call(x, h, -z), P.call(x, h, z))
	quad(mat_name, P.call(-x, 0, -z), P.call(-x, 0, z), P.call(-x, h, z), P.call(-x, h, -z))
	quad(top_mat if top_mat != "" else mat_name, P.call(-x, h, z), P.call(x, h, z), P.call(x, h, -z), P.call(-x, h, -z))
	if bottom:
		quad(mat_name, P.call(-x, 0, -z), P.call(x, 0, -z), P.call(x, 0, z), P.call(-x, 0, z))


## Placa horizontal (so a face de cima). Em material de mancha, ganha franja macia nas 4 bordas.
func flat(mat_name: String, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	quad(mat_name, Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3(x0, y, z0))
	if decal_mats.has(mat_name):
		var f := FEATHER_MIN * 1.3
		var c := [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
		var o := [Vector3(x0 - f, y, z0 - f), Vector3(x1 + f, y, z0 - f), Vector3(x1 + f, y, z1 + f), Vector3(x0 - f, y, z1 + f)]
		for i in 4:
			feather_quad(mat_name, c[i], c[(i + 1) % 4], o[(i + 1) % 4], o[i])


## Quad de franja: a,b na borda da mancha (alfa 1), c,d por fora (alfa 0). Face para cima.
func feather_quad(mat_name: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var st := _st(mat_name)
	var pts := [a, b, c, a, c, d]
	var al := [1.0, 1.0, 0.0, 1.0, 0.0, 0.0]
	# garante a face para cima (horario visto de cima = frente no Godot)
	if ((b - a).cross(c - a)).y > 0.0:
		pts = [a, c, b, a, d, c]
		al = [1.0, 0.0, 1.0, 1.0, 0.0, 0.0]
	for i in 6:
		var p: Vector3 = pts[i]
		st.set_color(Color(1, 1, 1, al[i]))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(p.x, -p.z) * UV_PER_UNIT * uv_mult)
		st.add_vertex(p)


## Faixa contínua (rio/trilha) ao longo de uma polilinha, sem sobreposição: juntas em "miter" suaves, franja
## macia dos dois lados e nas pontas (1 malha, sem anéis de espuma nas emendas da água).
func ribbon(mat_name: String, pts: Array, w: float, y: float, feather: float) -> void:
	var n := pts.size()
	var left: Array = []
	var right: Array = []
	var lo: Array = []
	var ro: Array = []
	for i in n:
		var p: Vector3 = pts[i]
		var d0: Vector3 = (p - (pts[i - 1] as Vector3)) if i > 0 else ((pts[1] as Vector3) - p)
		var d1: Vector3 = ((pts[i + 1] as Vector3) - p) if i < n - 1 else d0
		d0.y = 0
		d1.y = 0
		var t := (d0.normalized() + d1.normalized()).normalized()
		var nrm := Vector3(-t.z, 0, t.x)
		var k := 1.0 / maxf(0.5, nrm.dot(Vector3(-d0.normalized().z, 0, d0.normalized().x)))
		var q := Vector3(p.x, y, p.z)
		left.append(q + nrm * w * 0.5 * k)
		right.append(q - nrm * w * 0.5 * k)
		lo.append(q + nrm * (w * 0.5 + feather) * k)
		ro.append(q - nrm * (w * 0.5 + feather) * k)
	for i in n - 1:
		quad(mat_name, right[i], left[i], left[i + 1], right[i + 1])
		feather_quad(mat_name, left[i], left[i + 1], lo[i + 1], lo[i])
		feather_quad(mat_name, right[i + 1], right[i], ro[i], ro[i + 1])
	# pontas
	for e: int in [0, n - 1]:
		var dir: Vector3 = ((pts[0] as Vector3) - (pts[1] as Vector3)) if e == 0 else ((pts[n - 1] as Vector3) - (pts[n - 2] as Vector3))
		dir.y = 0
		var off := dir.normalized() * feather
		feather_quad(mat_name, right[e], left[e], left[e] + off, right[e] + off)


## Franja macia em volta de um contorno fechado (pontos em ordem) a partir do centro c.
func feather_ring(mat_name: String, c: Vector3, pts: Array, width: float) -> void:
	var n := pts.size()
	for i in n:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[(i + 1) % n]
		var o0 := p0 + Vector3(p0.x - c.x, 0, p0.z - c.z).normalized() * width
		var o1 := p1 + Vector3(p1.x - c.x, 0, p1.z - c.z).normalized() * width
		feather_quad(mat_name, p0, p1, o1, o0)


## Prisma de n lados entre dois pontos (tronco, poste, mastro).
func cyl(mat_name: String, a: Vector3, b: Vector3, r: float, sides: int = 6, cap: bool = true) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	var up := side.cross(axis).normalized()
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for i in sides:
		var ang := TAU * i / sides
		var o := (side * cos(ang) + up * sin(ang)) * r
		ring_a.append(a + o)
		ring_b.append(b + o)
	for i in sides:
		var j := (i + 1) % sides
		quad(mat_name, ring_a[j], ring_a[i], ring_b[i], ring_b[j])
	if cap:
		for i in sides:
			var j := (i + 1) % sides
			tri(mat_name, b, ring_b[j], ring_b[i])


## "Bolha" low-poly (copas de arvore, frutas).
func blob(mat_name: String, c: Vector3, r: Vector3, segs: int = 7, rings: int = 4) -> void:
	var rows: Array = []
	for i in rings + 1:
		var phi := PI * i / rings
		var row: Array[Vector3] = []
		for j in segs:
			var th := TAU * j / segs + (0.5 if i % 2 == 1 else 0.0)
			row.append(c + Vector3(sin(phi) * cos(th) * r.x, cos(phi) * r.y, sin(phi) * sin(th) * r.z))
		rows.append(row)
	for i in rings:
		for j in segs:
			var k := (j + 1) % segs
			var p00: Vector3 = rows[i][j]
			var p01: Vector3 = rows[i][k]
			var p10: Vector3 = rows[i + 1][j]
			var p11: Vector3 = rows[i + 1][k]
			if i > 0:
				_smooth_tri(mat_name, [p00, p01, p10], c) if _outward(p00, p01, p10, c) else _smooth_tri(mat_name, [p00, p10, p01], c)
			if i < rings - 1:
				_smooth_tri(mat_name, [p01, p11, p10], c) if _outward(p01, p11, p10, c) else _smooth_tri(mat_name, [p01, p10, p11], c)


## Verdadeiro se o triangulo (a,b,c) emitido nessa ordem fica de frente para fora (Godot: horario = frente).
func _outward(a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> bool:
	var n := (c - a).cross(b - a)
	return n.dot((a + b + c) / 3.0 - center) > 0.0


func obstruct_rect(center: Vector3, sx: float, sz: float, yaw: float = 0.0, height: float = 4.0) -> void:
	var tr := Transform3D(Basis(Vector3.UP, yaw), Vector3(center.x, 0, center.z))
	var pts := PackedVector3Array([tr * Vector3(-sx * 0.5, 0, -sz * 0.5), tr * Vector3(sx * 0.5, 0, -sz * 0.5),
		tr * Vector3(sx * 0.5, 0, sz * 0.5), tr * Vector3(-sx * 0.5, 0, sz * 0.5)])
	obstructions.append([pts, -0.5, height])


func obstruct_circle(center: Vector3, r: float, height: float = 4.0) -> void:
	var pts := PackedVector3Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(Vector3(center.x + cos(a) * r, 0, center.z + sin(a) * r))
	obstructions.append([pts, -0.5, height])


func walk_rect(x0: float, z0: float, x1: float, z1: float, y: float = 0.0) -> void:
	var a := Vector3(x0, y, z0)
	var b := Vector3(x1, y, z0)
	var c := Vector3(x1, y, z1)
	var d := Vector3(x0, y, z1)
	walk_faces.append_array(PackedVector3Array([a, b, c, a, c, d]))


# ---------------------------------------------------------------- mundo
func _build_river_and_docks() -> void:
	# muro do cais e fundo
	quad("stone", Vector3(QUAY_X, WATER_Y - 0.6, HALF + 60), Vector3(QUAY_X, WATER_Y - 0.6, -HALF - 60), Vector3(QUAY_X, 0.0, -HALF - 60), Vector3(QUAY_X, 0.0, HALF + 60))
	quad("stone", Vector3(FAR_BANK_X, WATER_Y - 0.6, -HALF - 60), Vector3(FAR_BANK_X, WATER_Y - 0.6, HALF + 60), Vector3(FAR_BANK_X, 0.3, HALF + 60), Vector3(FAR_BANK_X, 0.3, -HALF - 60))
	flat("water", QUAY_X, -HALF - 60, FAR_BANK_X, HALF + 60, WATER_Y)
	# praia de areia molhada ao norte (vista para o rio)
	flat("sand", 29, -HALF, QUAY_X, -38, 0.04)
	# piers: [z, comprimento]
	var piers := [[-22.0, 14.0], [0.0, 16.0], [26.0, 12.0]]
	for p: Array in piers:
		var z: float = p[0]
		var length: float = p[1]
		var x1 := QUAY_X + length
		box("wood", Vector3(QUAY_X + length * 0.5, -0.25, z), Vector3(length, 0.25, 3.0))
		walk_rect(QUAY_X - 0.5, z - 1.5, x1, z + 1.5)
		colliders.append([Vector3(QUAY_X + length * 0.5, -0.5, z), Vector3(length, 1.0, 3.0), "wood"])
		var x := QUAY_X + 1.5
		while x < x1:
			for sz: float in [-1.4, 1.4]:
				cyl("dark_wood", Vector3(x, WATER_Y - 0.5, z + sz), Vector3(x, 0.45, z + sz), 0.13, 5)
			x += 3.0
		# barquinhos amarrados dos dois lados
		_boat(Vector3(QUAY_X + length * 0.55, WATER_Y, z + 3.2), 0.05, "cloth_red" if z < 0 else "sail")
		_boat(Vector3(QUAY_X + length * 0.35, WATER_Y, z - 3.3), PI + 0.08, "sail" if z < 0 else "cloth_teal")
	# caixotes e barris no cais
	for c: Vector3 in [Vector3(33.5, 0, -6), Vector3(34.2, 0, -7.2), Vector3(33.2, 0, 7.5), Vector3(34.0, 0, 21.5), Vector3(33.0, 0, -18.5)]:
		box("wood", c, Vector3(1.0, 0.9, 1.0), rng.randf() * 0.6)
		obstruct_rect(c, 1.2, 1.2)
	for c: Vector3 in [Vector3(34.5, 0, 5.5), Vector3(33.4, 0, 4.8), Vector3(34.4, 0, 30.5)]:
		cyl("wood", c, c + Vector3(0, 1.0, 0), 0.45, 8)
		obstruct_circle(c, 0.5)
	# barcos navegando mais longe
	_boat(Vector3(62, WATER_Y, -38), 0.3, "sail", 1.4)
	_boat(Vector3(58, WATER_Y, 44), -0.5, "cloth_yellow", 1.2)


func _boat(c: Vector3, yaw: float, sail_mat: String, s: float = 1.0) -> void:
	# kit: barco do Pirate Kit (Kenney, CC0) — casco ao longo de Z no modelo, aqui ao longo de X local
	kit_items.append(["pk_ship_small", Transform3D(Basis(Vector3.UP, yaw + PI * 0.5).scaled(Vector3.ONE * 0.62 * s),
			c + Vector3(0, -0.25, 0))])
	var was_muted := mute_geo
	mute_geo = true
	var tr := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), c)
	var hl := 2.2
	var hw := 0.9
	var P := func(x: float, y: float, z: float) -> Vector3: return tr * Vector3(x, y, z)
	# casco: laterais inclinadas + proa pontuda
	quad("hull", P.call(-hl, -0.3, hw * 0.6), P.call(hl * 0.6, -0.3, hw * 0.6), P.call(hl * 0.6, 0.55, hw), P.call(-hl, 0.55, hw))
	quad("hull", P.call(hl * 0.6, -0.3, -hw * 0.6), P.call(-hl, -0.3, -hw * 0.6), P.call(-hl, 0.55, -hw), P.call(hl * 0.6, 0.55, -hw))
	quad("hull", P.call(hl * 0.6, -0.3, hw * 0.6), P.call(hl * 1.2, 0.0, 0), P.call(hl * 1.35, 0.7, 0), P.call(hl * 0.6, 0.55, hw))
	quad("hull", P.call(hl * 1.2, 0.0, 0), P.call(hl * 0.6, -0.3, -hw * 0.6), P.call(hl * 0.6, 0.55, -hw), P.call(hl * 1.35, 0.7, 0))
	quad("hull", P.call(-hl, -0.3, -hw * 0.6), P.call(-hl, -0.3, hw * 0.6), P.call(-hl, 0.55, hw), P.call(-hl, 0.55, -hw))
	quad("dark_wood", P.call(-hl, 0.3, hw * 0.9), P.call(hl * 0.6, 0.3, hw * 0.9), P.call(hl * 0.6, 0.3, -hw * 0.9), P.call(-hl, 0.3, -hw * 0.9))
	quad("frame_blue", P.call(-hl - 0.01, 0.4, hw + 0.01), P.call(hl * 0.6, 0.4, hw + 0.01), P.call(hl * 0.6, 0.55, hw + 0.01), P.call(-hl - 0.01, 0.55, hw + 0.01))
	# mastro e vela triangular
	cyl("dark_wood", P.call(0.1, 0.3, 0), P.call(0.1, 4.2, 0), 0.07 * s, 5)
	quad(sail_mat, P.call(-1.7, 1.0, 0), P.call(0.0, 1.0, 0), P.call(0.0, 4.0, 0), P.call(-0.2, 4.0, 0))
	tri(sail_mat, P.call(0.2, 1.0, 0), P.call(1.8, 1.0, 0), P.call(0.2, 3.8, 0))
	mute_geo = was_muted


func _build_walls_and_gates() -> void:
	# muralha baixa em volta, com 3 portoes (N: Campos do Sabia, S: Mata/Chapada, O: Arena)
	var h := 3.0
	var t := 1.6
	var wz := HALF - 3.0
	var wx := LAND_MIN_X + 3.0
	var gap := 4.0
	for side: float in [-1.0, 1.0]:
		box("stone", Vector3((wx + -gap) * 0.5, 0, side * wz), Vector3(-gap - wx, h, t), 0.0, "grass")
		obstruct_rect(Vector3((wx - gap) * 0.5, 0, side * wz), -gap - wx, t)
		box("stone", Vector3((gap + 29.0) * 0.5, 0, side * wz), Vector3(29.0 - gap, h, t), 0.0, "grass")
		obstruct_rect(Vector3((gap + 29.0) * 0.5, 0, side * wz), 29.0 - gap, t)
		box("stone", Vector3(wx, 0, side * (gap + wz) * 0.5), Vector3(t, h, wz - gap), 0.0, "grass")
		obstruct_rect(Vector3(wx, 0, side * (gap + wz) * 0.5), t, wz - gap)
	_gate(Vector3(0, 0, -wz), 0.0, "frame_yellow")
	_gate(Vector3(0, 0, wz), 0.0, "frame_green")
	_gate(Vector3(wx, 0, 0), PI / 2.0, "frame_red")
	# torres de canto
	for c: Vector3 in [Vector3(wx, 0, -wz), Vector3(wx, 0, wz), Vector3(29.0, 0, -wz), Vector3(29.0, 0, wz)]:
		cyl("stone", c, c + Vector3(0, 4.5, 0), 1.8, 8)
		_cone_roof(c + Vector3(0, 4.5, 0), 2.3, 2.2, 8)
		obstruct_circle(c, 1.9)


func _gate(c: Vector3, yaw: float, banner: String) -> void:
	var tr := Transform3D(Basis(Vector3.UP, yaw), c)
	for sx: float in [-3.3, 3.3]:
		box("stone", tr * Vector3(sx, 0, 0), Vector3(1.6, 5.0, 2.2), yaw)
		obstruct_rect(tr * Vector3(sx, 0, 0), 1.6, 2.2, yaw)
	box("stone", tr * Vector3(0, 5.0, 0), Vector3(8.2, 1.2, 2.4), yaw)
	box("roof", tr * Vector3(0, 6.2, 0), Vector3(8.8, 0.3, 2.8), yaw)
	for sz: float in [-1.25, 1.25]:
		quad(banner, tr * Vector3(-0.8, 3.2, sz), tr * Vector3(0.8, 3.2, sz), tr * Vector3(0.8, 5.0, sz), tr * Vector3(-0.8, 5.0, sz))
		quad(banner, tr * Vector3(0.8, 3.2, sz), tr * Vector3(-0.8, 3.2, sz), tr * Vector3(-0.8, 5.0, sz), tr * Vector3(0.8, 5.0, sz))
	# painel de azulejo acima do arco (face voltada para a cidade e para fora)
	for sz: float in [-1.22, 1.22]:
		var a := tr * Vector3(-1.2, 5.1, sz)
		var b := tr * Vector3(1.2, 5.1, sz)
		var cc := tr * Vector3(1.2, 6.0, sz)
		var d := tr * Vector3(-1.2, 6.0, sz)
		if sz > 0:
			quad("azulejo", a, b, cc, d)
		else:
			quad("azulejo", b, a, d, cc)


func _cone_roof(c: Vector3, r: float, h: float, sides: int) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		tri("roof", c + Vector3(0, h, 0), c + Vector3(cos(a1) * r, 0, sin(a1) * r), c + Vector3(cos(a0) * r, 0, sin(a0) * r))


func tree(c: Vector3, kind: String, s: float = 1.0) -> void:
	var kit_tree := {"leaves": "tree_broadleaf_a", "ipe_yellow": "tree_ipe_yellow_a", "ipe_purple": "tree_ipe_purple_a"}
	kit_items.append([kit_tree.get(kind, "tree_broadleaf_a"), Transform3D(Basis(Vector3.UP, c.x * 1.7 + c.z).scaled(
			Vector3.ONE * s * 0.9), c)])
	mute_geo = true
	var h := 3.2 * s
	cyl("trunk", c, c + Vector3(0.2, h, 0.1), 0.3 * s, 6, false)
	blob(kind, c + Vector3(0.2, h + 0.8 * s, 0.1), Vector3(2.0, 1.5, 2.0) * s, 8, 4)
	blob(kind, c + Vector3(-0.9, h + 0.2 * s, 0.6) , Vector3(1.3, 1.0, 1.3) * s, 7, 3)
	blob(kind, c + Vector3(1.1, h + 0.4 * s, -0.5), Vector3(1.2, 1.0, 1.2) * s, 7, 3)
	mute_geo = false
	obstruct_circle(c, 0.5 * s)


func _inside_building(c: Vector3) -> bool:
	for o: Array in obstructions:
		var pts: PackedVector3Array = o[0]
		var poly := PackedVector2Array()
		for p in pts:
			poly.append(Vector2(p.x, p.z))
		if Geometry2D.is_point_in_polygon(Vector2(c.x, c.z), poly):
			return true
		for p in pts:
			if Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z)) < 1.6:
				return true
	return false


func bench(c: Vector3, yaw: float) -> void:
	# yaw: direcao para onde quem senta olha
	var tr := Transform3D(Basis(Vector3.UP, yaw), c)
	box("wood", tr * Vector3(0, 0.45, 0), Vector3(2.2, 0.12, 0.6), yaw)
	box("wood", tr * Vector3(0, 0.75, 0.3), Vector3(2.2, 0.5, 0.1), yaw)
	for sx: float in [-0.95, 0.95]:
		box("dark_wood", tr * Vector3(sx, 0, 0), Vector3(0.12, 0.45, 0.5), yaw)
	obstruct_rect(c + (tr.basis * Vector3(0, 0, 0.1)), 2.3, 0.8, yaw, 1.0)


var viewpoints: Array = [] # [pos, yaw]


func _build_scenery_beyond() -> void:
	# margem oposta do rio (decorativa, nao caminhavel)
	flat("grass", FAR_BANK_X, -HALF - 60, FAR_BANK_X + 80, HALF + 60, 0.3)
	for i in 22:
		var c := Vector3(rng.randf_range(FAR_BANK_X + 3, FAR_BANK_X + 40), 0.3, rng.randf_range(-100, 100))
		var kinds := ["leaves", "leaves", "ipe_yellow", "ipe_purple"]
		var s := rng.randf_range(1.0, 1.6)
		var h := 3.2 * s
		cyl("trunk", c, c + Vector3(0.2, h, 0.1), 0.3 * s, 5, false)
		blob(kinds[i % 4], c + Vector3(0.2, h + 0.8 * s, 0.1), Vector3(2.0, 1.5, 2.0) * s, 7, 3)
	# morros ao longe (silhuetas no horizonte)
	for h: Array in [[Vector3(130, -4, -60), Vector3(45, 22, 40)], [Vector3(140, -6, 20), Vector3(50, 28, 45)],
			[Vector3(120, -4, 90), Vector3(40, 18, 35)], [Vector3(-40, -6, -125), Vector3(60, 22, 30)],
			[Vector3(40, -6, -130), Vector3(55, 26, 35)], [Vector3(-110, -6, 10), Vector3(40, 20, 60)],
			[Vector3(-30, -6, 130), Vector3(60, 20, 30)]]:
		blob("leaves", h[0], h[1], 10, 5)
	# bosque fora da muralha (atras dos portoes)
	for i in 30:
		var side := i % 3
		var c: Vector3
		if side == 0:
			c = Vector3(rng.randf_range(-70, 30), 0, rng.randf_range(-100, -64))
		elif side == 1:
			c = Vector3(rng.randf_range(-70, 30), 0, rng.randf_range(64, 100))
		else:
			c = Vector3(rng.randf_range(-100, -64), 0, rng.randf_range(-70, 70))
		var s := rng.randf_range(1.0, 1.7)
		cyl("trunk", c, c + Vector3(0.2, 3.2 * s, 0.1), 0.3 * s, 5, false)
		blob(["leaves", "leaves", "ipe_yellow"][i % 3], c + Vector3(0.2, 4.0 * s, 0.1), Vector3(2.2, 1.6, 2.2) * s, 7, 3)


func _build_world() -> void:
	_build_ground()
	_build_plaza()
	_build_river_and_docks()
	_build_walls_and_gates()
	_build_masters_house()
	_build_houses()
	_build_market()
	_build_viewpoints()
	_build_greenery()
	_build_props()
	_build_scenery_beyond()


func _build_ground() -> void:
	# fora da muralha: grama; dentro: calcamento de pedra (cidade toda pavimentada)
	flat("grass", LAND_MIN_X - 60, -HALF - 60, QUAY_X, HALF + 60, 0.0)
	walk_rect(LAND_MIN_X, -HALF, QUAY_X, HALF)
	_ground_colliders()
	var y := 0.02
	flat("cobble", LAND_MIN_X + 2.2, -HALF + 2.2, QUAY_X, HALF - 2.2, y)
	# saidas dos portoes
	flat("cobble", -3, -HALF - 20, 3, -HALF + 2.2, y)
	flat("cobble", -3, HALF - 2.2, 3, HALF + 20, y)
	flat("cobble", LAND_MIN_X - 20, -3, LAND_MIN_X + 2.2, 3, y)
	# ruas (usadas para nao construir em cima)
	roads = [
		Rect2(-3.5, -HALF, 7, HALF - 16), Rect2(-3.5, 16, 7, HALF - 16),
		Rect2(LAND_MIN_X, -3.5, -16 - LAND_MIN_X, 7), Rect2(16, -3.5, QUAY_X - 16, 7),
		Rect2(29.5, -HALF, QUAY_X - 29.5, HALF * 2),
		Rect2(-45, 3, 5, HALF), Rect2(3, -30.5, 26.5, 5), Rect2(3, 29.5, 26.5, 5),
	]


var roads: Array = []


## Particao SEM sobreposicao do chao caminhavel em caixas por tipo de piso (meta "surface" usada
## pelos passos do cliente). Todas com topo em y = 0, camada 1.
func _ground_colliders() -> void:
	var c := HALF - 2.2 # borda do calcamento (dentro da muralha)
	var rects := [
		# calcamento de pedra: cidade toda, cais e saidas dos portoes
		["stone", LAND_MIN_X + 2.2, -c, 29.0, c], ["stone", 29.0, -38.0, QUAY_X, c],
		["stone", -3.0, -HALF, 3.0, -c], ["stone", -3.0, c, 3.0, HALF], ["stone", LAND_MIN_X, -3.0, LAND_MIN_X + 2.2, 3.0],
		# prainha de areia ao norte do cais
		["sand", 29.0, -HALF, QUAY_X, -38.0],
		# faixas de grama junto a muralha (fora do calcamento)
		["grass", LAND_MIN_X + 2.2, -HALF, -3.0, -c], ["grass", 3.0, -HALF, 29.0, -c],
		["grass", LAND_MIN_X + 2.2, c, -3.0, HALF], ["grass", 3.0, c, QUAY_X, HALF],
		["grass", LAND_MIN_X, -HALF, LAND_MIN_X + 2.2, -3.0], ["grass", LAND_MIN_X, 3.0, LAND_MIN_X + 2.2, HALF],
	]
	for r: Array in rects:
		var x0: float = r[1]
		var z0: float = r[2]
		var x1: float = r[3]
		var z1: float = r[4]
		colliders.append([Vector3((x0 + x1) * 0.5, -0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, 1.0, z1 - z0), r[0]])


func _build_plaza() -> void:
	var y := 0.035
	var n := 40
	var r := PLAZA_R
	uv_mult = TEX_SIZE / 128.0 # tex_calcada_waves_01 tem 128 px
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		tri("calcada", Vector3(0, y, 0), Vector3(cos(a1) * r, y, sin(a1) * r), Vector3(cos(a0) * r, y, sin(a0) * r))
	uv_mult = 1.0
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		var yy := Vector3(0, y + 0.01, 0)
		quad("stone", p1 * (r + 0.7) + yy, p0 * (r + 0.7) + yy, p0 * r + yy, p1 * r + yy)
	# circulo magico dourado em volta do tronco e do cristal
	var mr := 5.6
	var mc := Vector3(0, 0.07, 0.3)
	var st := _st("magic_circle")
	var corners := [mc + Vector3(-mr, 0, -mr), mc + Vector3(mr, 0, -mr), mc + Vector3(mr, 0, mr), mc + Vector3(-mr, 0, mr)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[idx])
		st.add_vertex(corners[idx])
	# ipe amarelo gigante: arvore volumetrica do kit (a geometria antiga e silenciada, RNG e obstrucao mantidos)
	kit_items.append(["tree_ipe_yellow_giant", Transform3D(Basis(Vector3.UP, 0.4), TREE_POS)])
	mute_geo = true
	var base := TREE_POS
	cyl("trunk", base, base + Vector3(0.2, 4.8, 0.1), 1.05, 8, false)
	for k in 7:
		var a := TAU * k / 7.0 + 0.3
		cyl("trunk", base + Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6), base + Vector3(cos(a) * 2.1, -0.05, sin(a) * 2.1), 0.38, 5, false)
	var fork := base + Vector3(0.2, 4.6, 0.1)
	var branch_tips := [Vector3(-4.5, 8.3, -3.0), Vector3(4.2, 8.6, -2.5), Vector3(-2.5, 8.8, 3.5), Vector3(3.0, 8.4, 3.2), Vector3(0.3, 10.2, -1.0)]
	for tip: Vector3 in branch_tips:
		cyl("trunk", fork, base + tip, 0.5, 6, false)
	obstruct_circle(base, 1.6)
	# copa: muitos cachos de flores redondos (domo achatado)
	var cc := base + Vector3(0, 9.6, 0)
	for i in 64:
		var u := rng.randf()
		var th := rng.randf() * TAU
		var ph := acos(1.0 - u * 1.25) # hemisferio de cima + borda
		var dirv := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
		var p := cc + Vector3(dirv.x * 7.4, dirv.y * 3.4, dirv.z * 7.4)
		var rr := rng.randf_range(1.3, 1.9)
		blob("ipe_yellow", p, Vector3(rr, rr * 0.85, rr), 7, 4)
	# passe visual: copa mais cheia (mais cachos, RNG proprio para nao mudar o resto do mapa)
	for i in 70:
		var th := deco_rng.randf() * TAU
		var ph := acos(1.0 - deco_rng.randf() * 1.35)
		var dirv := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
		var p := cc + Vector3(dirv.x * 8.3, dirv.y * 3.9 - 0.3, dirv.z * 8.3)
		var rr := deco_rng.randf_range(1.2, 2.0)
		blob("ipe_yellow", p, Vector3(rr, rr * 0.85, rr), 7, 4)
	# cachos inferiores (mesma cor), para a copa nao parecer oca vista de baixo
	for i in 12:
		var th := TAU * i / 12.0
		blob("ipe_yellow", cc + Vector3(cos(th) * 5.2, -1.4, sin(th) * 5.2), Vector3(1.5, 1.0, 1.5), 7, 3)
	mute_geo = false
	# canteiro de flores e arbustos em volta do ipe (kit)
	kit_beds.append([TREE_POS, 5.4, 4.2])
	# Borda circular de pedra talhada contornando o canteiro central
	var bn := 32
	var br := 5.8
	for i in bn:
		var ba0 := TAU * i / bn
		var ba1 := TAU * (i + 1) / bn
		var bp0 := TREE_POS + Vector3(cos(ba0), 0, sin(ba0)) * br
		var bp1 := TREE_POS + Vector3(cos(ba1), 0, sin(ba1)) * br
		var byy := Vector3(0, 0.09, 0)
		quad("stone_trim", bp1 + byy, bp0 + byy, bp0, bp1)
	for i in 12:
		var ang := i * TAU / 12.0 + 0.15
		var mesh_name := "pk_bush_flowers" if i % 2 == 0 else "bush_round_a"
		kit_items.append([mesh_name, Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * 0.85),
				TREE_POS + Vector3(cos(ang), 0, sin(ang)) * 5.4)])
	# cristal azul na base do tronco (ponto de renascimento)
	var cp := CRYSTAL_POS
	# Pedestal nobre de pedra esculpida para o cristal de renascimento
	cyl("stone_trim", cp, cp + Vector3(0, 0.14, 0), 1.7, 16)
	cyl("stone", cp + Vector3(0, 0.14, 0), cp + Vector3(0, 0.28, 0), 1.25, 12)
	kit_items.append(["crystal_cluster", Transform3D(Basis(Vector3.UP, 0.3).scaled(Vector3.ONE * 1.15), cp + Vector3(0, 0.28, 0))])
	# Cristais secundários ressonantes saindo do pedestal
	_crystal(cp + Vector3(0.85, 0.26, 0.35), 0.26, 1.35, 0.32)
	_crystal(cp + Vector3(-0.75, 0.26, 0.4), 0.24, 1.15, -0.38)
	_crystal(cp + Vector3(0.2, 0.26, -0.85), 0.22, 1.0, 0.25)
	_crystal(cp + Vector3(-0.6, 0.26, -0.65), 0.18, 0.85, -0.28)
	# Pedrinhas e seixos decorativos no pedestal
	kit_items.append(["pk_pebble_round_1", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.9), cp + Vector3(1.1, 0.15, -0.5))])
	kit_items.append(["pk_pebble_round_3", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.85), cp + Vector3(-1.0, 0.15, 0.8))])
	obstruct_circle(cp, 1.3)
	# petalas caidas no chao
	for i in 160:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 13.0
		var c := Vector3(cos(a) * d, 0.08, sin(a) * d)
		if c.distance_to(TREE_POS) < 1.7 or c.distance_to(CRYSTAL_POS) < 1.1:
			continue
		var s := 0.11
		mute_geo = true # petalas quadradas antigas: o canteiro de flores do kit substitui (RNG mantido)
		quad("cloth_yellow", c + Vector3(-s, 0, s), c + Vector3(s, 0, s), c + Vector3(s, 0, -s), c + Vector3(-s, 0, -s))
		mute_geo = false
	# Vasos de ipê floridos (amarelo e roxo) e lampiões em volta da praça
	for i in 8:
		var a := TAU * i / 8.0 + TAU / 16.0
		var c := Vector3(cos(a) * (PLAZA_R - 1.2), 0, sin(a) * (PLAZA_R - 1.2))
		potted_ipe(c, 1.0, i % 2 == 1)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0 + 0.28
		_lamp(Vector3(cos(a) * (PLAZA_R + 1.5), 0, sin(a) * (PLAZA_R + 1.5)))



func _crystal(base: Vector3, r: float, h: float, tilt: float) -> void:
	var b := Basis(Vector3(0, 0, 1), tilt)
	var top := base + b * Vector3(0, h, 0)
	var ring: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0
		ring.append(base + b * Vector3(cos(a) * r, h * 0.62, sin(a) * r))
	var low: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0
		low.append(base + b * Vector3(cos(a) * r * 0.7, 0.0, sin(a) * r * 0.7))
	for i in 6:
		var j := (i + 1) % 6
		tri("crystal", top, ring[j], ring[i])
		quad("crystal", low[i], low[j], ring[j], ring[i])


## Palmeira em vaso de barro (enfeite de rua e praca).
func potted_palm(c: Vector3, s: float) -> void:
	kit_items.append(["pk_vase_2", Transform3D(Basis(Vector3.UP, c.x).scaled(Vector3.ONE * 1.3 * s), c)])
	kit_items.append(["pk_plant_1_big", Transform3D(Basis(Vector3.UP, c.z).scaled(Vector3.ONE * 0.75 * s), c + Vector3(0, 0.55 * s, 0))])
	var was_muted := mute_geo
	mute_geo = true
	cyl("pot", c, c + Vector3(0, 0.55 * s, 0), 0.38 * s, 8)
	cyl("pot", c + Vector3(0, 0.5 * s, 0), c + Vector3(0, 0.65 * s, 0), 0.46 * s, 8)
	var top := c + Vector3(0, 1.3 * s, 0)
	cyl("trunk", c + Vector3(0, 0.6 * s, 0), top, 0.1 * s, 5, false)
	var nf := 8
	for i in nf:
		var a := TAU * i / nf + rng.randf() * 0.3
		var dirv := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dirv.z, 0, dirv.x)
		var mid := top + dirv * 0.6 * s + Vector3(0, 0.35 * s, 0)
		var tip := top + dirv * 1.25 * s + Vector3(0, -0.25 * s, 0)
		var mat := "palm" if i % 2 == 0 else "palm_dark"
		tri(mat, top, mid + side * 0.28 * s, mid - side * 0.28 * s)
		tri(mat, mid - side * 0.28 * s, mid + side * 0.28 * s, tip)
	mute_geo = was_muted
	obstruct_circle(c, 0.5 * s, 1.5)


## Vaso de ipê florido (amarelo ou roxo) com flores na borda — marco visual aconchegante da praça.
func potted_ipe(c: Vector3, s: float, is_purple: bool = false) -> void:
	kit_items.append(["pk_vase_2", Transform3D(Basis(Vector3.UP, c.x * 2.3).scaled(Vector3.ONE * 1.35 * s), c)])
	var ipe_mesh := "pk_ipe_purple_1" if is_purple else "pk_ipe_yellow_1"
	kit_items.append([ipe_mesh, Transform3D(Basis(Vector3.UP, c.z * 1.7).scaled(Vector3.ONE * 0.28 * s), c + Vector3(0, 0.45 * s, 0))])
	kit_items.append(["pk_bush_flowers", Transform3D(Basis(Vector3.UP, c.x + c.z).scaled(Vector3.ONE * 0.38 * s), c + Vector3(0, 0.5 * s, 0))])
	obstruct_circle(c, 0.55 * s, 1.8)


func _lamp(c: Vector3) -> void:
	cyl("dark_wood", c, c + Vector3(0, 2.6, 0), 0.08, 5)
	box("dark_wood", c + Vector3(0, 2.6, 0), Vector3(0.45, 0.08, 0.45))
	box("lamp_glow", c + Vector3(0, 2.68, 0), Vector3(0.3, 0.35, 0.3))
	box("frame_red", c + Vector3(0, 3.03, 0), Vector3(0.45, 0.1, 0.45))
	obstruct_circle(c, 0.25)


## Casa colonial: paredes caiadas, cunhais de pedra, faixas de azulejo, telhado de barro, chamine.
## yaw 0 -> fachada voltada para +Z.
func house(c: Vector3, w: float, d: float, floors: int, yaw: float, wall: String, frame: String,
		azulejo_base: bool = false) -> void:
	var tr := Transform3D(Basis(Vector3.UP, yaw), c)
	var fh := 3.0
	var h := fh * floors + 0.5
	obstruct_rect(c, w + 0.3, d + 0.3, yaw, h + 1.0)
	# kit (CC0 + retextura): casa colonial modular. A geometria antiga abaixo so consome o RNG (layout identico).
	ColonialHouse.build(kit_items, tr, w, d, floors, wall, frame, azulejo_base, house_rng)
	var was_muted := mute_geo
	mute_geo = true
	box(wall, c, Vector3(w, h, d), yaw)
	# cunhais (pilastras) nos cantos
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box("stone_trim", tr * Vector3(sx * (w / 2 - 0.15), 0, sz * (d / 2 - 0.15)), Vector3(0.45, h, 0.45), yaw)
	# faixas de azulejo: sob o beiral e entre andares; barrado de azulejo opcional
	box("azulejo", tr * Vector3(0, h - 0.65, 0), Vector3(w + 0.1, 0.5, d + 0.1), yaw)
	for fl in range(1, floors):
		box("azulejo", tr * Vector3(0, fl * fh + 0.1, 0), Vector3(w + 0.08, 0.3, d + 0.08), yaw)
	if azulejo_base:
		box("azulejo", tr * Vector3(0, 0, 0), Vector3(w + 0.06, 1.1, d + 0.06), yaw)
	else:
		box("stone_trim", tr * Vector3(0, 0, 0), Vector3(w + 0.06, 0.35, d + 0.06), yaw)
	# telhado de duas aguas
	var o := 0.55
	var rh := minf(d * 0.42, 2.8)
	var P := func(x: float, y: float, z: float) -> Vector3: return tr * Vector3(x, y, z)
	quad("roof", P.call(-w / 2 - o, h - 0.2, d / 2 + o), P.call(w / 2 + o, h - 0.2, d / 2 + o), P.call(w / 2 + o, h + rh, 0), P.call(-w / 2 - o, h + rh, 0))
	quad("roof", P.call(w / 2 + o, h - 0.2, -d / 2 - o), P.call(-w / 2 - o, h - 0.2, -d / 2 - o), P.call(-w / 2 - o, h + rh, 0), P.call(w / 2 + o, h + rh, 0))
	tri(wall, P.call(w / 2, h, d / 2), P.call(w / 2, h, -d / 2), P.call(w / 2, h + rh - 0.1, 0))
	tri(wall, P.call(-w / 2, h, -d / 2), P.call(-w / 2, h, d / 2), P.call(-w / 2, h + rh - 0.1, 0))
	cyl("roof_ridge", P.call(-w / 2 - o, h + rh + 0.03, 0), P.call(w / 2 + o, h + rh + 0.03, 0), 0.14, 4, false)
	# beiral: borda branca sob as telhas
	box("stone_trim", tr * Vector3(0, h - 0.2, d / 2 + 0.25), Vector3(w + 0.6, 0.18, 0.5), yaw)
	# chamine
	var ch := tr * Vector3(w * 0.28 * (1.0 if rng.randf() < 0.5 else -1.0), h, -d * 0.2)
	box("wall_white", ch, Vector3(0.65, rh + 0.9, 0.65), yaw)
	box("roof_ridge", ch + Vector3(0, rh + 0.9, 0), Vector3(0.85, 0.15, 0.85), yaw)
	# fachada
	var fz := d / 2 + 0.03
	var nwin := maxi(1, int(floor((w - 1.0) / 2.3)))
	var xs: Array[float] = []
	for i in nwin:
		xs.append((i - (nwin - 1) * 0.5) * 2.3)
	var door_i := nwin / 2
	for i in nwin:
		if i == door_i:
			_door(tr, Vector3(xs[i], 0, fz), frame)
		else:
			_window(tr, Vector3(xs[i], 1.0, fz), frame, false)
	for fl in range(1, floors):
		for i in nwin:
			_window(tr, Vector3(xs[i], fl * fh + 0.75, fz), frame, i == door_i)
	# janelas nas laterais e nos fundos (vistas quando a camera gira)
	for sx: float in [-1.0, 1.0]:
		var side_tr := Transform3D(Basis(Vector3.UP, yaw + sx * PI / 2.0), tr * Vector3(sx * (w / 2 + 0.03), 0, 0))
		for fl in floors:
			_window(side_tr, Vector3(0, fl * fh + (1.0 if fl == 0 else 0.75), 0), frame, false)
	var back_tr := Transform3D(Basis(Vector3.UP, yaw + PI), tr * Vector3(0, 0, -d / 2 - 0.03))
	for fl in floors:
		for i in nwin:
			if (i + fl) % 2 == 0:
				_window(back_tr, Vector3(xs[i], fl * fh + (1.0 if fl == 0 else 0.75), 0), frame, false)
	mute_geo = was_muted


func _window(tr: Transform3D, local: Vector3, frame: String, balcony: bool) -> void:
	var yaw := tr.basis.get_euler().y
	var ww := 0.95
	var hh := 1.35
	box(frame, tr * local, Vector3(ww + 0.32, hh + 0.3, 0.1), yaw)
	box("glass", tr * (local + Vector3(0, 0.15, 0.05)), Vector3(ww, hh, 0.07), yaw)
	# caixilho em cruz
	box(frame, tr * (local + Vector3(0, 0.15, 0.1)), Vector3(0.08, hh, 0.04), yaw)
	box(frame, tr * (local + Vector3(0, 0.15 + hh * 0.55, 0.1)), Vector3(ww, 0.08, 0.04), yaw)
	# frontao sobre a janela e peitoril
	box("stone_trim", tr * (local + Vector3(0, hh + 0.3, 0.04)), Vector3(ww + 0.55, 0.16, 0.2), yaw)
	box("stone_trim", tr * (local + Vector3(0, -0.12, 0.08)), Vector3(ww + 0.45, 0.12, 0.28), yaw)
	if balcony:
		box("dark_wood", tr * (local + Vector3(0, -0.2, 0.45)), Vector3(ww + 0.9, 0.1, 0.8), yaw)
		for k in 6:
			box("dark_wood", tr * (local + Vector3(-ww * 0.5 - 0.4 + k * (ww + 0.8) / 5.0, -0.1, 0.82)), Vector3(0.06, 0.7, 0.06), yaw)
		box("dark_wood", tr * (local + Vector3(0, 0.55, 0.82)), Vector3(ww + 0.9, 0.08, 0.08), yaw)
	else:
		# rng principal consumido como antes (layout identico); deco_rng acrescenta jardineiras (passe visual)
		var has_box := rng.randf() < 0.55
		var fl := "flower_pink" if (rng.randf() < 0.5 if has_box else false) else "fruit_red"
		if not has_box and deco_rng.randf() < 0.7:
			has_box = true
			fl = ["flower_pink", "cloth_yellow", "fruit_red", "flower_pink"][deco_rng.randi() % 4]
		if has_box:
			box("pot", tr * (local + Vector3(0, -0.05, 0.25)), Vector3(ww + 0.1, 0.22, 0.3), yaw)
			blob(fl, tr * (local + Vector3(0, 0.25, 0.27)), Vector3(ww * 0.45, 0.2, 0.18), 6, 2)
			blob("leaves", tr * (local + Vector3(-ww * 0.3, 0.12, 0.3)), Vector3(0.2, 0.14, 0.14), 5, 2)


func _door(tr: Transform3D, local: Vector3, frame: String) -> void:
	var yaw := tr.basis.get_euler().y
	box("stone_trim", tr * local, Vector3(1.75, 2.75, 0.1), yaw)
	box(DOOR_COLORS[int(rng.randi() % DOOR_COLORS.size())], tr * (local + Vector3(0, 0.05, 0.05)), Vector3(1.25, 2.35, 0.08), yaw)
	box(frame, tr * (local + Vector3(0, 2.35, 0.08)), Vector3(1.3, 0.25, 0.06), yaw)
	box("stone_trim", tr * (local + Vector3(0, 0, 0.45)), Vector3(1.9, 0.14, 0.8), yaw)
	# passe visual: lampiao de parede ao lado da porta e vaso de flores no degrau
	if deco_rng.randf() < 0.6:
		var side := 1.0 if deco_rng.randf() < 0.5 else -1.0
		box("dark_wood", tr * (local + Vector3(side * 1.15, 2.2, 0.12)), Vector3(0.08, 0.08, 0.3), yaw)
		box("lamp_glow", tr * (local + Vector3(side * 1.15, 1.95, 0.3)), Vector3(0.2, 0.26, 0.2), yaw)
		box("frame_red", tr * (local + Vector3(side * 1.15, 2.21, 0.3)), Vector3(0.28, 0.07, 0.28), yaw)
	if deco_rng.randf() < 0.45:
		var pside := 1.0 if deco_rng.randf() < 0.5 else -1.0
		props.append(["prop_flower_pot", tr * (local + Vector3(pside * 1.25, 0, 0.55)), 1.0])


const DOOR_COLORS := ["frame_magenta", "frame_green", "frame_teal", "frame_blue", "frame_red"]
const FRAMES := ["frame_teal", "frame_magenta", "frame_yellow", "frame_green", "frame_red", "frame_blue"]
const WALLS := ["wall_white", "wall_white", "wall_white", "wall_yellow", "wall_white", "wall_pink", "wall_white", "wall_blue", "wall_white", "wall_green"]
var house_count := 0


func _next_house(c: Vector3, w: float, d: float, floors: int, yaw: float) -> void:
	house(c, w, d, floors, yaw, WALLS[house_count % WALLS.size()], FRAMES[(house_count * 5 + 2) % FRAMES.size()], house_count % 3 == 1)
	house_count += 1


func _footprint_free(c: Vector3, w: float, d: float, yaw: float) -> bool:
	var b := Basis(Vector3.UP, yaw)
	var sx := -w * 0.5
	while sx <= w * 0.5 + 0.01:
		var sz := -d * 0.5
		while sz <= d * 0.5 + 0.01:
			var p := c + b * Vector3(sx, 0, sz)
			if p.x < LAND_MIN_X + 4.0 or p.x > 29.3 or absf(p.z) > HALF - 4.0:
				return false
			if Vector2(p.x, p.z).length() < PLAZA_R + 2.5:
				return false
			for rr: Rect2 in roads:
				if rr.has_point(Vector2(p.x, p.z)):
					return false
			for o: Array in obstructions:
				var poly := PackedVector2Array()
				for q in (o[0] as PackedVector3Array):
					poly.append(Vector2(q.x, q.z))
				if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), poly):
					return false
			sz += minf(1.0, d * 0.5)
		sx += minf(1.0, w * 0.5)
	return true


## Enfileira casas (casario) ao longo de uma rua, dos dois lados, com fachada para a rua.
func _fill_street(origin: Vector3, dirv: Vector3, length: float, half_w: float, sides: Array) -> void:
	var n := Vector3(-dirv.z, 0, dirv.x)
	for side: float in sides:
		var t := 0.0
		while t < length:
			var w := rng.randf_range(6.0, 9.0)
			var d := rng.randf_range(6.5, 8.0)
			var floors := 2 if rng.randf() < 0.7 else 1
			var c := origin + dirv * (t + w * 0.5) + n * side * (half_w + 0.8 + d * 0.5)
			var face := -n * side
			var yaw := atan2(face.x, face.z)
			if _footprint_free(c, w + 0.6, d + 0.6, yaw):
				_next_house(c, w, d, floors, yaw)
				t += w + (0.0 if rng.randf() < 0.6 else rng.randf_range(1.5, 3.0))
			else:
				t += 1.0


func _build_houses() -> void:
	# casas que fecham a praca nas diagonais (fachada para o ipe)
	for a_deg: float in [45.0, 135.0, 315.0]:
		var a := deg_to_rad(a_deg)
		var c := Vector3(cos(a), 0, sin(a)) * (PLAZA_R + 7.0)
		_next_house(c, 11.0, 8.0, 2, atan2(-c.x, -c.z))
	_fill_street(Vector3(0, 0, -18), Vector3(0, 0, -1), 38.0, 3.5, [-1.0, 1.0])
	_fill_street(Vector3(0, 0, 18), Vector3(0, 0, 1), 38.0, 3.5, [-1.0, 1.0])
	_fill_street(Vector3(-18, 0, 0), Vector3(-1, 0, 0), 38.0, 3.5, [-1.0, 1.0])
	_fill_street(Vector3(18, 0, 0), Vector3(1, 0, 0), 11.0, 3.5, [-1.0, 1.0])
	_fill_street(Vector3(-42.5, 0, 5.5), Vector3(0, 0, 1), 50.0, 2.5, [-1.0, 1.0])
	_fill_street(Vector3(4, 0, -28), Vector3(1, 0, 0), 25.0, 2.5, [-1.0, 1.0])
	_fill_street(Vector3(4, 0, 32), Vector3(1, 0, 0), 25.0, 2.5, [-1.0, 1.0])
	_fill_street(Vector3(29.5, 0, -54), Vector3(0, 0, 1), 108.0, 0.0, [1.0])
	print("casas: ", house_count)


func _build_masters_house() -> void:
	# Casa dos Mestres: sobrado grande na diagonal noroeste da praca, com torre e painel de azulejos
	var a := deg_to_rad(225.0)
	var c := Vector3(cos(a), 0, sin(a)) * (PLAZA_R + 8.0)
	var yaw := atan2(-c.x, -c.z)
	masters_door = c + Basis(Vector3.UP, yaw) * Vector3(0, 0, 6.2)
	house(c, 14.0, 9.0, 2, yaw, "wall_white", "frame_blue", true)
	var tr := Transform3D(Basis(Vector3.UP, yaw), c)
	var fz := 4.5 + 0.08
	for sx: float in [-1.0, 1.0]:
		box("azulejo", tr * Vector3(sx * 3.45, 1.2, fz), Vector3(1.2, 4.0, 0.06), yaw)
	var tc := tr * Vector3(-5.2, 0, -2.2)
	box("wall_white", tc, Vector3(3.8, 11.0, 3.8), yaw)
	box("azulejo", tc + Vector3(0, 6.6, 0), Vector3(3.9, 0.5, 3.9), yaw)
	for k in 4:
		var ttr := Transform3D(Basis(Vector3.UP, yaw + k * PI / 2.0), tc + Basis(Vector3.UP, yaw + k * PI / 2.0) * Vector3(0, 0, 1.92))
		_window(ttr, Vector3(0, 8.4, 0), "frame_blue", false)
	var roof_c := tc + Vector3(0, 11.0, 0)
	var pts: Array[Vector3] = []
	for k in 4:
		pts.append(roof_c + Basis(Vector3.UP, yaw + PI / 4.0 + k * PI / 2.0) * Vector3(0, 0, 3.0))
	for k in 4:
		tri("roof", roof_c + Vector3(0, 3.2, 0), pts[(k + 1) % 4], pts[k])
	obstruct_rect(tc, 4.0, 4.0, yaw, 12.0)
	# estandartes das duas escolas (Lamina = vermelho, Arcano = verde-agua)
	for s: Array in [[-1.75, "cloth_red"], [1.75, "cloth_teal"]]:
		box(s[1], tr * Vector3(s[0], 3.4, fz + 0.12), Vector3(0.8, 1.9, 0.05), yaw)


var masters_door := Vector3.ZERO


func _build_market() -> void:
	# feira de frutas e produtos da colheita dentro da praca (GDD §17, Sun Haven cozy style)
	var awnings := ["awning_red", "awning_yellow", "awning_teal", "awning_blue", "awning_green"]
	var n := 0
	for a_deg: float in [28.0, 62.0, 118.0, 152.0, 332.0]:
		var a := deg_to_rad(a_deg)
		var c := Vector3(cos(a), 0, sin(a)) * 11.8
		var yaw := atan2(-c.x, -c.z)
		var tr := Transform3D(Basis(Vector3.UP, yaw), c)

		# Estrutura de madeira da banca / carroça do kit (ambas em escala proporcional de 1.05)
		kit_items.append(["pk_stall_cart_empty" if n % 2 == 0 else "pk_stall_empty", Transform3D(
				Basis(Vector3.UP, yaw + PI).scaled(Vector3.ONE * 1.05), tr * Vector3(0, 0, 0.2))])

		# Toldo de tecido listrado colorido (cobertura gable com duas águas e valances aconchegantes)
		uv_mult = 0.5
		var xw := 1.35
		var zf := 1.08
		var zb := -0.68
		var zp := 0.00
		var yp := 2.92
		var yf := 2.52
		var yb := 2.56
		var yfv := 2.24
		var ybv := 2.30

		# Água frontal (da cumeeira ao beiral frontal)
		quad(awnings[n], tr * Vector3(-xw, yf, zf), tr * Vector3(xw, yf, zf), tr * Vector3(xw, yp, zp), tr * Vector3(-xw, yp, zp))
		# Água traseira (da cumeeira ao beiral traseiro)
		quad(awnings[n], tr * Vector3(xw, yb, zb), tr * Vector3(-xw, yb, zb), tr * Vector3(-xw, yp, zp), tr * Vector3(xw, yp, zp))
		# Valance frontal vertical (babado listrado voltado para a frente)
		quad(awnings[n], tr * Vector3(-xw, yfv, zf), tr * Vector3(xw, yfv, zf), tr * Vector3(xw, yf, zf), tr * Vector3(-xw, yf, zf))
		# Valance traseiro vertical
		quad(awnings[n], tr * Vector3(xw, ybv, zb), tr * Vector3(-xw, ybv, zb), tr * Vector3(-xw, yb, zb), tr * Vector3(xw, yb, zb))
		# Frontão lateral esquerdo (triângulo do gable)
		tri(awnings[n], tr * Vector3(-xw, yf, zf), tr * Vector3(-xw, yp, zp), tr * Vector3(-xw, yb, zb))
		# Frontão lateral direito (triângulo do gable)
		tri(awnings[n], tr * Vector3(xw, yb, zb), tr * Vector3(xw, yp, zp), tr * Vector3(xw, yf, zf))
		# Abas laterais penduradas (valances laterais)
		quad(awnings[n], tr * Vector3(-xw, ybv, zb), tr * Vector3(-xw, yfv, zf), tr * Vector3(-xw, yf, zf), tr * Vector3(-xw, yb, zb))
		quad(awnings[n], tr * Vector3(xw, yfv, zf), tr * Vector3(xw, ybv, zb), tr * Vector3(xw, yb, zb), tr * Vector3(xw, yf, zf))
		uv_mult = 1.0

		# Caixotes com maçãs e cenouras no balcão da barraca
		kit_items.append(["pk_farmcrate_apple", Transform3D(Basis(Vector3.UP, yaw + 0.12).scaled(Vector3.ONE * 0.8), tr * Vector3(-0.65, 0.88, 0.15))])
		kit_items.append(["pk_farmcrate_carrot", Transform3D(Basis(Vector3.UP, yaw - 0.08).scaled(Vector3.ONE * 0.8), tr * Vector3(0.65, 0.88, 0.15))])

		# Enfeites e produtos no chão em volta da barraca (Sun Haven style)
		kit_items.append(["pk_farmcrate_apple", Transform3D(Basis(Vector3.UP, yaw + house_rng.randf_range(-0.15, 0.15)), tr * Vector3(-0.9, 0, 1.25))])
		kit_items.append(["pk_farmcrate_carrot", Transform3D(Basis(Vector3.UP, yaw + house_rng.randf_range(-0.15, 0.15)), tr * Vector3(0.1, 0, 1.35))])
		kit_items.append(["pk_farmcrate_empty", Transform3D(Basis(Vector3.UP, yaw + 0.35), tr * Vector3(1.0, 0, 1.2))])

		# Caixotes de madeira e barris
		kit_items.append(["pk_crate_wooden", Transform3D(Basis(Vector3.UP, yaw + 0.25).scaled(Vector3.ONE * 0.9), tr * Vector3(-1.7, 0, 0.3))])
		kit_items.append(["pk_crate_wooden", Transform3D(Basis(Vector3.UP, yaw - 0.15).scaled(Vector3.ONE * 0.75), tr * Vector3(-1.7, 0.42, 0.3))])
		kit_items.append(["pk_barrel_apples", Transform3D(Basis.IDENTITY, tr * Vector3(1.65, 0, 0.85))])
		kit_items.append(["pk_barrel", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.9), tr * Vector3(1.75, 0, -0.35))])

		# Sacos de grãos/especiarias e baú/vasos
		kit_items.append(["pk_bag", Transform3D(Basis(Vector3.UP, yaw + 0.4).scaled(Vector3.ONE * 1.1), tr * Vector3(-1.6, 0, 1.0))])
		if n % 2 == 1:
			kit_items.append(["pk_chest_wood", Transform3D(Basis(Vector3.UP, yaw - 0.3).scaled(Vector3.ONE * 0.85), tr * Vector3(1.9, 0, 0.3))])
		else:
			kit_items.append(["vg_clay_pots", Transform3D(Basis(Vector3.UP, yaw + 0.5).scaled(Vector3.ONE * 0.75), tr * Vector3(1.85, 0, 0.3))])

		# Mesa de apoio lateral para as barracas 1 e 3
		if n in [1, 3]:
			kit_items.append(["pk_table_large", Transform3D(Basis(Vector3.UP, yaw + PI * 0.5).scaled(Vector3.ONE * 0.75), tr * Vector3(-2.2, 0, 0.1))])
			kit_items.append(["pk_farmcrate_apple", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.7), tr * Vector3(-2.2, 0.61, 0.1))])

		# Lampião pendurado no poste lateral da barraca (abaixo do beiral do toldo)
		kit_items.append(["pk_lantern_wall", Transform3D(Basis(Vector3.UP, yaw - PI * 0.5).scaled(Vector3.ONE * 0.65), tr * Vector3(0.96, 1.25, 0.66))])

		obstruct_rect(tr * Vector3(0, 0, 0.3), 3.4, 2.4, yaw, 3.0)
		n += 1



func _build_greenery() -> void:
	# jardins: canteiros de grama com arvores nos vazios entre as casas
	var placed := 0
	var tries := 0
	while placed < 34 and tries < 900:
		tries += 1
		var c := Vector3(rng.randf_range(LAND_MIN_X + 6, 27), 0, rng.randf_range(-HALF + 6, HALF - 6))
		if not _footprint_free(c, 5.0, 5.0, 0.0):
			continue
		var kinds := ["leaves", "leaves", "ipe_yellow", "ipe_purple", "leaves"]
		flat_disc("garden", c, 2.6, 0.04)
		tree(c, kinds[placed % kinds.size()], rng.randf_range(0.9, 1.3))
		for k in 4:
			var a := TAU * k / 4.0 + rng.randf()
			var bc := c + Vector3(cos(a) * 1.8, 0, sin(a) * 1.8)
			kit_items.append(["bush_round_a" if k % 2 == 0 else "bush_olive_a", Transform3D(Basis(Vector3.UP, a).scaled(
					Vector3.ONE * 0.6), bc)])
		kit_beds.append([c, 2.5, 2.5])
		obstruct_circle(c, 2.4, 1.5)
		placed += 1
	# palmeiras em vasos junto as fachadas e ao longo do cais
	var pp := 0
	tries = 0
	while pp < 40 and tries < 1500:
		tries += 1
		var c := Vector3(rng.randf_range(LAND_MIN_X + 4, 34.5), 0, rng.randf_range(-HALF + 4, HALF - 4))
		if Vector2(c.x, c.z).length() < PLAZA_R + 2.0:
			continue
		if not _near_obstruction(c, 1.4) or _in_obstruction(c, 0.9):
			continue
		# nao bloquear o meio das ruas principais
		if absf(c.x) < 2.0 or absf(c.z) < 2.0:
			continue
		potted_palm(c, rng.randf_range(0.8, 1.1))
		pp += 1
	# lampioes ao longo das ruas principais
	for k in range(1, 4):
		for s: float in [-1.0, 1.0]:
			for L: Vector3 in [Vector3(s * 3.2, 0, -PLAZA_R - k * 11.0), Vector3(s * 3.2, 0, PLAZA_R + k * 11.0), Vector3(-PLAZA_R - k * 11.0, 0, s * 3.2)]:
				if not _in_obstruction(L, 0.6):
					_lamp(L)
	print("jardins: ", placed, " palmeiras: ", pp)


func _near_obstruction(c: Vector3, dist: float) -> bool:
	for o: Array in obstructions:
		var pts: PackedVector3Array = o[0]
		for i in pts.size():
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[(i + 1) % pts.size()].x, pts[(i + 1) % pts.size()].z)
			var q := Geometry2D.get_closest_point_to_segment(Vector2(c.x, c.z), a, b)
			if q.distance_to(Vector2(c.x, c.z)) < dist and (o[2] as float) > 3.0:
				return true
	return false


func _in_obstruction(c: Vector3, margin: float) -> bool:
	for o: Array in obstructions:
		var pts: PackedVector3Array = o[0]
		var poly := PackedVector2Array()
		for q in pts:
			poly.append(Vector2(q.x, q.z))
		if Geometry2D.is_point_in_polygon(Vector2(c.x, c.z), poly):
			return true
		for i in pts.size():
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[(i + 1) % pts.size()].x, pts[(i + 1) % pts.size()].z)
			if Geometry2D.get_closest_point_to_segment(Vector2(c.x, c.z), a, b).distance_to(Vector2(c.x, c.z)) < margin:
				return true
	return false


func flat_disc(mat_name: String, c: Vector3, r: float, y: float) -> void:
	var n := 12 if not decal_mats.has(mat_name) else 20
	var ring: Array = []
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		tri(mat_name, Vector3(c.x, y, c.z), Vector3(c.x + cos(a1) * r, y, c.z + sin(a1) * r), Vector3(c.x + cos(a0) * r, y, c.z + sin(a0) * r))
		ring.append(Vector3(c.x + cos(a0) * r, y, c.z + sin(a0) * r))
	if decal_mats.has(mat_name):
		feather_ring(mat_name, Vector3(c.x, y, c.z), ring, clampf(r * 0.45, FEATHER_MIN, FEATHER_MAX))


func _build_viewpoints() -> void:
	# yaw 0 = olhando para -Z
	# 1: ponta do pier principal, olhando o rio e os barcos (leste)
	var v1 := Vector3(QUAY_X + 14.5, 0, 0.0)
	bench(v1 + Vector3(-0.2, 0, 0), -PI / 2)
	viewpoints.append([v1 + Vector3(-1.4, 0, 0), -PI / 2, v1 + Vector3(-0.2, 0, 0), "bench_pier"])
	# 2: praca, banco olhando o ipe e o cristal
	var a := deg_to_rad(242.0)
	var v2 := Vector3(cos(a), 0, sin(a)) * 12.0
	var yaw2 := atan2(v2.x, v2.z) # quem senta olha para o centro da praca
	bench(v2, yaw2)
	viewpoints.append([v2 - v2.normalized() * 1.0, yaw2, v2, "bench_plaza"])
	# 3: prainha ao norte, olhando o rio
	var v3 := Vector3(33.0, 0, -46.0)
	bench(v3, -PI / 2 + 0.3)
	viewpoints.append([v3 + Vector3(-1.2, 0, -0.3), -PI / 2 + 0.3, v3, "bench_beach"])


## Passe visual (ancora 4): enfeites pequenos como sprites billboard (assets/environment/props/prop_*.png).
## Cada um bloqueia um circulo pequeno do navmesh (menos flores). Usa deco_rng.
const PROP_DIR := "res://assets/environment/props"
const PROP_RADIUS := {"prop_flower_pot": 0.4, "prop_fruit_crate": 0.55, "prop_lantern": 0.3, "prop_fishing_net": 0.7, "prop_flowers": 0.0}


func _build_props() -> void:
	# feira: caixotes de fruta ao lado das bancas (lado oposto ao mercador na banca de 28 graus)
	for a_deg: float in [28.0, 62.0, 118.0, 152.0, 332.0]:
		var c := Vector3(cos(deg_to_rad(a_deg)), 0, sin(deg_to_rad(a_deg))) * 11.8
		var tr := Transform3D(Basis(Vector3.UP, atan2(-c.x, -c.z)), c)
		props.append(["prop_fruit_crate", tr * Vector3(-2.4, 0, -0.3), 1.0])
		if a_deg != 28.0 and deco_rng.randf() < 0.6:
			props.append(["prop_fruit_crate", tr * Vector3(2.4, 0, -0.5), 0.9])
	# praca: canteiros de flores entre as palmeiras em vaso
	for i in 8:
		var a := TAU * i / 8.0
		props.append(["prop_flowers", Vector3(cos(a), 0, sin(a)) * (PLAZA_R - 1.3), 1.0])
	# cais: lampioes na entrada dos pieres, redes de pesca secando, caixotes
	for z: float in [-22.0, 0.0, 26.0]:
		for sz: float in [-2.2, 2.2]:
			props.append(["prop_lantern", Vector3(QUAY_X - 0.7, 0, z + sz), 1.0])
	for c: Vector3 in [Vector3(33.2, 0, -25.5), Vector3(33.4, 0, -14.0), Vector3(33.0, 0, 16.5)]:
		props.append(["prop_fishing_net", c, 1.0])
	for c: Vector3 in [Vector3(34.3, 0, -9.0), Vector3(33.2, 0, 11.0)]:
		props.append(["prop_fruit_crate", c, 1.0])
	# vasos de flores extras nas ruas principais
	for k in 10:
		var c := Vector3(deco_rng.randf_range(-3.0, 3.0), 0, deco_rng.randf_range(-50.0, 50.0))
		c.x = 3.0 * signf(c.x)
		if absf(c.z) > PLAZA_R + 3.0 and not _in_obstruction(c, 0.8):
			props.append(["prop_flower_pot", c, 1.0])
	for p: Array in props:
		var r: float = PROP_RADIUS.get(p[0], 0.3) * (p[2] as float)
		if r > 0.0:
			obstruct_circle(p[1], r, 1.2)


# ---------------------------------------------------------------- montagem
func _assemble() -> Node3D:
	var root := Node3D.new()
	root.name = "CityAwakening"
	root.set_script(load(MAP_SCRIPT))
	root.set(&"map_id", &"city_awakening")
	root.set(&"nav_cell_size", NAV_CELL)
	root.set(&"nav_cell_height", NAV_CELL)

	# --- luz / ambiente (funciona headless: so recursos, sem codigo)
	var lighting := Node3D.new()
	lighting.name = "Lighting"
	_add(root, lighting)
	# luz e pos do kit pintado (GDD §17.0.A): sol quente com sombra macia, ambiente/nevoa quentes
	var sun := EnvLook.make_sun(-35.0, -42.0)
	sun.directional_shadow_max_distance = 80.0
	_add(lighting, sun)
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = load(KIT + "env_warm_city.tres")
	_add(lighting, we)

	# Luz mágica do cristal de renascimento
	var cl := OmniLight3D.new()
	cl.name = "CrystalLight"
	cl.light_color = Color8(130, 205, 255)
	cl.light_energy = 2.4
	cl.omni_range = 10.5
	cl.omni_attenuation = 1.15
	cl.position = CRYSTAL_POS + Vector3(0, 1.8, 0)
	_add(lighting, cl)

	# Lampiões aconchegantes nas barracas da feira
	var market_angles := [28.0, 62.0, 118.0, 152.0, 332.0]
	for idx in market_angles.size():
		var ma := deg_to_rad(market_angles[idx])
		var mc_pos := Vector3(cos(ma), 0, sin(ma)) * 11.8
		var ml := OmniLight3D.new()
		ml.name = "StallLight_%d" % idx
		ml.light_color = Color(1.0, 0.82, 0.55) # luz dourada aconchegante
		ml.light_energy = 0.95
		ml.omni_range = 5.2
		ml.omni_attenuation = 1.3
		ml.position = mc_pos + Vector3(0, 2.0, 0)
		_add(lighting, ml)

	# --- petalas de ipe caindo (GPUParticles3D: nao processa no servidor headless)
	var petals := GPUParticles3D.new()
	petals.name = "IpePetals"
	petals.amount = 140
	petals.lifetime = 10.0
	petals.preprocess = 10.0
	petals.position = TREE_POS + Vector3(0, 8.5, 0)
	petals.visibility_aabb = AABB(Vector3(-14, -10, -14), Vector3(28, 14, 28))
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(7, 1, 7)
	ppm.gravity = Vector3(0.25, -0.7, 0.1)
	ppm.initial_velocity_min = 0.1
	ppm.initial_velocity_max = 0.4
	ppm.direction = Vector3(1, 0, 0)
	ppm.spread = 180.0
	ppm.turbulence_enabled = true
	ppm.turbulence_noise_strength = 0.6
	ppm.turbulence_noise_scale = 3.0
	petals.process_material = ppm
	var pq := QuadMesh.new()
	pq.size = Vector2(0.08, 0.08)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color8(255, 222, 108)
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pmat.billboard_keep_scale = true
	pq.material = pmat
	petals.draw_pass_1 = pq
	_add(lighting, petals)


	# --- geometria (1 malha por material)
	var geo := Node3D.new()
	geo.name = "Geometry"
	_add(root, geo)
	var names: Array = tools.keys()
	names.sort()
	for mat_name: String in names:
		var st: SurfaceTool = tools[mat_name]
		st.set_material(mats[mat_name])
		st.index()
		var mesh := st.commit()
		var path := "%s/geo_%s.res" % [GEO_DIR, mat_name]
		ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		mesh.take_over_path(path)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + mat_name
		mi.mesh = mesh
		if mat_name in ["water", "sand", "cobble", "grass"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(geo, mi)

	# --- decoracao do kit pintado (sem colisao; obstrucoes ja registradas): arvores, arbustos, props, flores
	_kit_decor(root)

	# --- colisao do chao (camada 1 apenas): um StaticBody3D por tipo de piso, com meta "surface"
	var ground := Node3D.new()
	ground.name = "Ground"
	_add(root, ground)
	var bodies := {}
	var ci := 0
	for c: Array in colliders:
		var surf: String = c[2]
		if not bodies.has(surf):
			var body := StaticBody3D.new()
			body.name = "Ground" + surf.capitalize()
			body.collision_layer = 1
			body.collision_mask = 0
			body.set_meta(&"surface", StringName(surf))
			_add(ground, body)
			bodies[surf] = body
		var cs := CollisionShape3D.new()
		cs.name = "Shape%d" % ci
		var bs := BoxShape3D.new()
		bs.size = c[1]
		cs.shape = bs
		cs.position = c[0]
		_add(bodies[surf], cs)
		ci += 1

	# --- navegacao (assada agora)
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	region.navigation_mesh = _bake_navmesh()
	_add(root, region)

	# --- marcadores
	var spawn := Marker3D.new() # ao sul do cristal, virado para a praca
	spawn.name = "SpawnPoint"
	spawn.position = SPAWN_POS
	_add(root, spawn)
	var waystone := Marker3D.new() # chegada ao lado da Dona Ana (WaystoneService.ARRIVAL_MARKER)
	waystone.name = "WaystoneArrival"
	waystone.position = DONA_ANA_POS + Vector3(-1.5, 0, 1.5)
	_add(root, waystone)
	var vi := 1
	for v: Array in viewpoints:
		var m := Marker3D.new()
		m.name = "Viewpoint%d" % vi
		m.position = v[0]
		m.rotation.y = v[1]
		_add(root, m)
		vi += 1
	var poi := Node3D.new()
	poi.name = "PointsOfInterest"
	_add(root, poi)
	var pois := {
		"RespawnCrystal": [CRYSTAL_POS, &""],
		"MastersHouseDoor": [masters_door, &""],
		"GateNorth": [Vector3(0, 0, -57), &"fields_sabia"],
		"GateSouth": [Vector3(0, 0, 57), &"fields_sabia"],
		"GateWest": [Vector3(-57, 0, 0), &"arena_burning"],
		"DocksArrival": [Vector3(38, 0, 0), &""],
		"Market": [Vector3(8, 0, 8), &""],
		"IpeTree": [TREE_POS, &""],
	}
	for k: String in pois:
		var m := Marker3D.new()
		m.name = k
		m.position = pois[k][0]
		if pois[k][1] != &"":
			m.set_meta(&"target_map", pois[k][1])
		_add(poi, m)
	_add_npc_points(root)
	_add_interactables(root)
	_add_audio_zones(root)
	return root


## Decor/ com as malhas do kit (MultiMesh por malha, em pedacos de 16 m) + canteiros e capim.
## Os enfeites que eram sprites (props) viram malhas do kit.
const PROP_KIT := {"prop_fruit_crate": ["pk_farmcrate_apple", 1.2], "prop_flower_pot": ["bush_olive_a", 0.45],
	"prop_lantern": ["prop_barrel", 0.8], "prop_fishing_net": ["pk_barrel_holder", 1.0]}


## Faiscas subindo do cristal (GPUParticles3D; nao roda no servidor headless).
static func crystal_sparkles(pos: Vector3) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = "CrystalSparkles"
	gp.amount = 75
	gp.lifetime = 3.2
	gp.preprocess = 3.2
	gp.position = pos + Vector3(0, 0.8, 0)
	gp.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	ppm.emission_sphere_radius = 1.6
	ppm.gravity = Vector3(0, 0.45, 0)
	ppm.initial_velocity_min = 0.1
	ppm.initial_velocity_max = 0.45
	ppm.spread = 180.0
	ppm.scale_min = 0.8
	ppm.scale_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.25, 1))
	curve.add_point(Vector2(0.75, 0.8))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	ppm.scale_curve = ct
	gp.process_material = ppm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.8, 0.96, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.88, 1.0)
	m.emission_energy_multiplier = 3.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	gp.draw_pass_1 = q
	return gp


func _kit_decor(root: Node3D) -> void:
	var decor := Node3D.new()
	decor.name = "Decor"
	_add(root, decor)
	var krng := RandomNumberGenerator.new()
	krng.seed = 1709
	for p: Array in props:
		var pos: Vector3 = p[1]
		if p[0] == "prop_flowers":
			kit_beds.append([pos, 0.9, 6.0])
		elif PROP_KIT.has(p[0]):
			var spec: Array = PROP_KIT[p[0]]
			kit_items.append([spec[0], Transform3D(Basis(Vector3.UP, krng.randf() * TAU).scaled(
					Vector3.ONE * float(spec[1]) * float(p[2])), pos)])
	# faiscas do cristal
	_add(decor, crystal_sparkles(CRYSTAL_POS))
	var fs := FoliageScatter.new()
	fs.name = "Kit"
	fs.chunk_size = 40.0
	_add(decor, fs)
	var by_mesh := KitCatalog.group(kit_items, krng)
	for m: String in by_mesh:
		fs.add_instances(load(m), by_mesh[m], m.get_file().get_basename(), krng, true)
	var flat := func(_x: float, _z: float) -> float: return 0.04
	var small := {"flowers": [], "flowers_b": [], "grass_tuft_b": [], "grass_tuft": []}
	for bed: Array in kit_beds:
		var c: Vector3 = bed[0]
		var r: float = bed[1]
		var ring := func(x: float, z: float) -> float:
			var d := Vector2(x - c.x, z - c.z).length()
			return 1.0 if d < r and (r < 3.0 or d > r - 1.2) and not _in_obstruction(Vector3(x, 0, z), 0.1) else 0.0
		var area := Rect2(c.x - r, c.z - r, r * 2, r * 2)
		small["flowers"].append_array(FoliageScatter.sample(area, bed[2], krng, ring, flat, 0.8, 1.2))
		small["flowers_b"].append_array(FoliageScatter.sample(area, bed[2] * 0.7, krng, ring, flat, 0.8, 1.2))
		small["grass_tuft_b"].append_array(FoliageScatter.sample(area, bed[2] * 0.6, krng, ring, flat, 0.8, 1.2))
	# capim e flores fora da muralha (faixa de 26 m)
	var outside := func(x: float, z: float) -> float:
		var inside_walls := x > LAND_MIN_X - 1.0 and absf(z) < HALF + 1.0
		if inside_walls or x > QUAY_X - 1.0:
			return 0.0
		if absf(x) < 4.0 or absf(z) < 4.0: # estradas dos portoes
			return 0.0
		return 1.0
	var band := Rect2(LAND_MIN_X - 26, -HALF - 26, QUAY_X - LAND_MIN_X + 26, HALF * 2 + 52)
	small["grass_tuft"].append_array(FoliageScatter.sample(band, 0.9, krng, outside, flat, 0.8, 1.3))
	small["grass_tuft_b"].append_array(FoliageScatter.sample(band, 0.25, krng, outside, flat, 0.8, 1.3))
	small["flowers"].append_array(FoliageScatter.sample(band, 0.12, krng, outside, flat, 0.8, 1.2))
	for m: String in small:
		var sub := []
		for it: Array in small[m]:
			sub.append([m, it[0]])
		_ground_hugging_city(sub, m)
		var g := KitCatalog.group(sub, krng)
		for path: String in g:
			fs.add_instances(load(path), g[path], path.get_file().get_basename(), krng, false)
	print("kit: ", fs.stats(), " malhas=", by_mesh.keys())
	for n: Node in fs.get_children():
		n.owner = root
	# MultiMesh em arquivos binarios na pasta do mapa (a .tscn fica pequena)
	for n: Node in fs.get_children():
		var mmi := n as MultiMeshInstance3D
		var path := "%s/mm_%s.res" % [_geo_dir(), mmi.name]
		ResourceSaver.save(mmi.multimesh, path, ResourceSaver.FLAG_COMPRESS)
		mmi.multimesh.take_over_path(path)


## GDD §17.0.C (P2, 28/09/2026): plantas rasteiras mais baixas; metade do capim de fora da muralha sai (o chão
## pintado lê como grama contínua); o capim alto dos canteiros vira folhagem baixa e cheia (KitCatalog "bush_low").
## Só transforma/filtra o que já foi sorteado (não consome RNG).
func _ground_hugging_city(sub: Array, kind: String) -> void:
	for i in range(sub.size() - 1, -1, -1):
		var t: Transform3D = sub[i][1]
		var o := t.origin
		if kind == "grass_tuft" and absi(int(floor(o.x * 13.7) * 73856093) ^ int(floor(o.z * 11.3) * 19349663)) % 1000 >= 500:
			sub.remove_at(i)
			continue
		if kind == "grass_tuft_b" and o.x > LAND_MIN_X - 1.0 and absf(o.z) < HALF + 1.0:
			sub[i] = ["bush_low", Transform3D(t.basis * Basis.from_scale(Vector3(0.5, 0.2, 0.5)), o)]
			continue
		var f := 0.55 if kind.begins_with("grass") else 0.78
		sub[i][1] = Transform3D(t.basis * Basis.from_scale(Vector3(1.0, f, 1.0)), o)


## Pasta das malhas deste mapa (o campo de treino sobrescreve).
func _geo_dir() -> String:
	return GEO_DIR


## Yaw (convencao do jogo: 0 = olhando para -Z) para olhar na direcao dir.
func _yaw_of(dirv: Vector3) -> float:
	return atan2(-dirv.x, -dirv.z)


## NpcPoints/: um Marker3D por NPC (nome = spawn_marker do NpcDef) + pontos de patrulha.
## rotation.y e a meta facing_yaw = para onde o NPC olha parado.
func _add_npc_points(root: Node3D) -> void:
	var pts := Node3D.new()
	pts.name = "NpcPoints"
	_add(root, pts)
	var stall := Vector3(cos(deg_to_rad(28.0)), 0, sin(deg_to_rad(28.0))) * 11.8
	var stall_tr := Transform3D(Basis(Vector3.UP, atan2(-stall.x, -stall.z)), stall)
	var list := [
		# nome, posicao, yaw
		["merchant", stall_tr * Vector3(2.7, 0, 0.6), _yaw_of(-stall.normalized())],
		["boatman", Vector3(QUAY_X + 3.5, 0, -0.8), PI / 2.0],
		["fruit_vendor", Vector3(cos(deg_to_rad(135.0)), 0, sin(deg_to_rad(135.0))) * 8.5, _yaw_of(Vector3(1, 0, -1))],
		["gate_guard", Vector3(0, 0, -HALF + 7.0), PI],
		["gate_guard_patrol_1", Vector3(-2.2, 0, -HALF + 7.5), PI],
		["gate_guard_patrol_2", Vector3(2.2, 0, -HALF + 7.5), PI],
		["fisherman", Vector3(QUAY_X + 10.0, 0, -22.9), 0.0],
		["curious_child", Vector3(4.0, 0, -6.0), _yaw_of(TREE_POS - Vector3(4.0, 0, -6.0))],
		# Dona Ana (WaystoneService): na praça, ao lado do SpawnPoint, olhando para ele.
		["dona_ana", DONA_ANA_POS, _yaw_of(SPAWN_POS - DONA_ANA_POS)],
	]
	# Mestres em recantos exploráveis, fora da praça central.
	var mentors := {
		&"master_brisa": Vector3(-37, 0, -29),
		&"master_orvalho": Vector3(30, 0, 24),
		&"master_taquari": Vector3(20, 0, -40),
		&"elder_ze_ferreiro": Vector3(-42, 0, 20),
		&"elder_aninha": Vector3(-18.5, 0, 33.5),
		&"elder_tiao": Vector3(0.5, 0, 40.5),
	}
	for mentor: StringName in mentors:
		var pos: Vector3 = mentors[mentor]
		list.append([String(mentor), pos, _yaw_of(-pos.normalized())])
	for e: Array in list:
		var m := Marker3D.new()
		m.name = e[0]
		m.position = e[1]
		m.rotation.y = e[2]
		m.set_meta(&"facing_yaw", e[2])
		if StringName(e[0]) in mentors:
			m.set_meta(&"minimap_icon", &"none")
		elif e[0] == "dona_ana":
			m.set_meta(&"minimap_icon", &"shop")
		_add(pts, m)


## Interactables/: Area3D SO na camada 2 (clicaveis), metas do contrato docs/contracts-city-walk.md.
func _add_interactables(root: Node3D) -> void:
	var inter := Node3D.new()
	inter.name = "Interactables"
	_add(root, inter)
	for v: Array in viewpoints:
		var yaw: float = v[1]
		var seat: Vector3 = v[2]
		var a := _click_area(inter, v[3], seat + Vector3(0, 0.5, 0), Vector3(2.3, 1.2, 0.9), yaw)
		a.set_meta(&"interact_type", &"sit")
		a.set_meta(&"facing_yaw", yaw)
		a.set_meta(&"seat_position", seat) # centro do assento (fora do navmesh)
		a.set_meta(&"approach_position", v[0]) # ponto caminhavel ao lado do banco (= ViewpointN)
	var gates := [
		["gate_north", Vector3(0, 0, -HALF + 3.0), 0.0, &"fields_sabia", "1–10"],
		["gate_south", Vector3(0, 0, HALF - 3.0), 0.0, &"fields_sabia", "1–10"],
		["gate_west", Vector3(LAND_MIN_X + 3.0, 0, 0), PI / 2.0, &"arena_burning", "PVP"],
	]
	for g: Array in gates:
		var a := _click_area(inter, g[0], g[1] + Vector3(0, 2.5, 0), Vector3(5.0, 5.0, 2.6), g[2])
		a.set_meta(&"interact_type", &"portal")
		a.set_meta(&"target_map", g[3])
		a.set_meta(&"recommended_level", g[4])
		a.set_meta(&"approach_position", g[1])


func _click_area(parent: Node, id: String, pos: Vector3, size: Vector3, yaw: float) -> Area3D:
	var a := Area3D.new()
	a.name = id
	a.position = pos
	a.rotation.y = yaw
	a.collision_layer = 2
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = false
	a.input_ray_pickable = true
	a.set_meta(&"interact_id", StringName(id))
	a.set_meta(&"target_id", "m:" + id)
	_add(parent, a)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	_add(a, cs)
	return a


## AudioZones/: Area3D (camada 0: nao interferem no clique) com meta zone_id; o AudioZoneDef e
## data/audio/<map_id>_<zone_id>.tres (id = "<map_id>_<zone_id>", meta audio_zone_def).
func _add_audio_zones(root: Node3D) -> void:
	var az := Node3D.new()
	az.name = "AudioZones"
	_add(root, az)
	var zones := [
		["default", Vector3(0, 5, 0), Vector3(400, 40, 400)],
		["docks", Vector3((29.0 + FAR_BANK_X) * 0.5, 5, 0), Vector3(FAR_BANK_X - 29.0, 40, HALF * 2 + 40)],
		["market", Vector3(0, 5, 0), Vector3(PLAZA_R * 2 + 2, 40, PLAZA_R * 2 + 2)],
	]
	for z: Array in zones:
		var a := Area3D.new()
		a.name = z[0]
		a.position = z[1]
		a.collision_layer = 0
		a.collision_mask = 0
		a.input_ray_pickable = false
		a.set_meta(&"zone_id", StringName(z[0]))
		a.set_meta(&"audio_zone_def", StringName("city_awakening_" + z[0]))
		_add(az, a)
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var bs := BoxShape3D.new()
		bs.size = z[2]
		cs.shape = bs
		_add(a, cs)


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	var owner_node: Node = parent
	while owner_node.get_parent() != null:
		owner_node = owner_node.get_parent()
	child.owner = owner_node


func _bake_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = NAV_CELL
	nm.cell_height = NAV_CELL
	nm.agent_radius = AGENT_RADIUS
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 40.0
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var src := NavigationMeshSourceGeometryData3D.new()
	src.add_faces(walk_faces, Transform3D.IDENTITY)
	for o: Array in obstructions:
		src.add_projected_obstruction(o[0], o[1], o[2], false)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	# o Recast coloca os poligonos alguns "cell_height" acima do chao; recoloca o chao da praca em y = 0
	var verts := nm.get_vertices()
	var min_y := INF
	for v in verts:
		min_y = minf(min_y, v.y)
	for i in verts.size():
		verts[i].y -= min_y
	nm.vertices = verts
	print("navmesh y offset corrigido: ", min_y)
	print("navmesh: %d vertices, %d polygons" % [nm.get_vertices().size(), nm.get_polygon_count()])
	return nm
