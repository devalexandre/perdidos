extends "res://tools/art/build_city.gd"
## Constroi e salva res://scenes/maps/training_field.tscn (Campo de Treino dos Viajantes, GDD 9.3) com o
## navmesh JA ASSADO. Reexecutavel. Rodar:
##   godot --headless --path game --script res://tools/art/build_training_field.gd
## Reusa as primitivas de build_city.gd (1 malha por material, UV em coordenadas de mundo a 48 px/un.).
## Eixos: X = leste, Z = sul, Y = cima. Acampamento no centro (origem); mapa util = disco de raio FIELD_R.
## Cada nacao ocupa um setor em volta do acampamento (angulo = atan2(z, x) em graus: 90 = sul, 270 = norte).
## VISUAL (GDD §17.0.A, 27/09/2026): kit pintado (docs/arte-cenario.md). Materiais pintados (_paint_field_materials),
## arvores/arbustos/pedras/capim/flores do kit em Decor/Kit (MultiMesh por malha; ver _sprite_layer, que converte os
## antigos sprites fld_* em malhas do kit). Obstrucoes, RNG e navmesh inalterados.

const TF_SCENE := "res://scenes/maps/training_field.tscn"
const TF_GEO := "res://scenes/maps/training_field"
const FIELD_R := 92.0
const CAMP_R := 15.0
const ZONE_R := 62.0 # distancia do centro das zonas das nacoes
const PINDORAMA_C := Vector3(0, 0, 52) # centro da Terra de Pindorama (setor sul, maior)
const RANCHO := Vector3(0, 0, 36)
const PORTAL_POS := Vector3(5.5, 0, -16.5)
const SPR_DIR := "res://assets/environment/field"

## id da regiao, angulo (graus), material do chao, raio da clareira, cor da bandeira, master id,
## [monstros], superficie dos passos
const NATIONS := [
	["portugal", 145.0, "cobble", 17.0, "banner_portugal", "master_guiomar", ["fountain_serpent", "trasgo_imp"], "stone"],
	["grecia", 177.0, "dry_meadow", 18.0, "banner_grecia", "master_nicandro", ["griffin_chick", "little_chimera"], "grass"],
	["egito", 208.0, "desert_sand", 18.0, "banner_egito", "master_seneb", ["dune_scorpion", "sphinx_cub"], "sand"],
	["celta", 239.0, "lush_grass", 18.0, "banner_celta", "master_ewan", ["puca_trickster", "lake_kelpie"], "grass"],
	["nordico", 270.0, "snow", 18.0, "banner_nordico", "master_solveig", ["moss_troll", "lindworm_hatchling"], "sand"],
	["eslavo", 301.0, "birch_meadow", 18.0, "banner_eslavo", "master_zlata", ["zmey_hatchling", "walking_hut"], "grass"],
	["china", 332.0, "stone_paving", 17.0, "banner_china", "master_xiaoyu", ["hopping_jiangshi", "spirit_fox_cub"], "stone"],
	["japao", 3.0, "moss_gravel", 18.0, "banner_japao", "master_tsubaki", ["kasa_obake", "trickster_tanuki"], "grass"],
	["mexico", 34.0, "jungle_floor", 18.0, "banner_mexico", "master_citlali", ["obsidian_iguana", "jaguar_cub"], "grass"],
]

var npc_points: Array = [] # [nome, pos, yaw]
var spawns: Array = [] # [nome, pos, monster_id, count, radius_cells, estágio inicial (opcional, 1)]
var pois: Array = [] # [nome, pos]
var sprites: Array = [] # [textura, pos, escala]
var ground_discs: Array = [] # [surface, centro, raio]
var stream_pts: Array = [] # pontos do riacho da Terra de Pindorama
var tf_viewpoints: Array = []
var keepout: Array = [] # [centro, raio] areas que a vegetacao espalhada evita (spawns, Mestres)
## Revisão 5 (relevo orgânico): o chão deixa de ser feito de discos/faixas; tudo vai para um terreno único com
## relevo e mistura pintada (tools/art/env_kit/field_relief.gd). As peças de chão antigas só REGISTRAM a forma.
const FieldRelief := preload("res://tools/art/env_kit/field_relief.gd")
var relief = FieldRelief.new()
const ORGANIC_MUTED := ["grass", "cerrado", "red_earth", "dirt", "snow", "ice", "desert_sand", "lush_grass",
	"moss_gravel", "jungle_floor", "dry_meadow", "birch_meadow", "stone_paving", "cobble", "sand", "water",
	"blob_shadow"]
const TERRAIN_INNER := Rect2(-110, -110, 220, 220)
const TERRAIN_OUTER := Rect2(-210, -210, 420, 420)


func _initialize() -> void:
	rng.seed = 92702026
	deco_rng.seed = 5151
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TF_GEO))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	clean_dir(TF_GEO)
	decal_mats = FIELD_DECALS.duplicate()
	_make_materials()
	_make_field_materials()
	_paint_field_materials()
	_build_field()
	var root := _assemble_field()
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack falhou: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, TF_SCENE)
	print("saved ", TF_SCENE, " err=", err)
	root.free()
	quit(0 if err == OK else 1)


static func pol(deg: float, r: float) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(cos(a) * r, 0, sin(a) * r)


# ---------------------------------------------------------------- materiais
func _make_field_materials() -> void:
	for t: Array in [["cerrado", "tex_cerrado_grass_01"], ["red_earth", "tex_red_earth_01"], ["dirt", "tex_packed_dirt_01"],
			["snow", "tex_snow_01"], ["ice", "tex_ice_01"], ["desert_sand", "tex_desert_sand_01"], ["lush_grass", "tex_lush_grass_01"],
			["moss_gravel", "tex_moss_gravel_01"], ["jungle_floor", "tex_jungle_floor_01"], ["dry_meadow", "tex_dry_meadow_01"],
			["birch_meadow", "tex_birch_meadow_01"], ["stone_paving", "tex_stone_paving_01"], ["thatch", "tex_thatch_01"]]:
		_tex_mat(t[0], t[1], t[0] == "thatch")
	var cols := {
		"banner_brasil": Color8(230, 180, 58), "banner_portugal": Color8(168, 64, 106), "banner_grecia": Color8(168, 212, 245),
		"banner_egito": Color8(168, 116, 30), "banner_celta": Color8(90, 160, 72), "banner_nordico": Color8(47, 85, 168),
		"banner_eslavo": Color8(142, 102, 196), "banner_china": Color8(217, 85, 58), "banner_japao": Color8(252, 250, 245),
		"banner_mexico": Color8(79, 168, 160), "tent_a": Color8(242, 230, 200), "tent_b": Color8(201, 176, 138),
		"olive": Color8(79, 168, 160), "pine": Color8(31, 59, 44), "pine_snow": Color8(199, 195, 204), "sakura": Color8(247, 188, 208),
		"birch_bark": Color8(242, 230, 200), "birch_leaf": Color8(166, 216, 106), "bamboo": Color8(90, 160, 72),
		"obsidian": Color8(43, 38, 48), "sandstone": Color8(201, 176, 138), "mudbrick": Color8(156, 106, 60),
		"heather": Color8(142, 102, 196), "termite": Color8(156, 42, 38), "termite_hi": Color8(217, 85, 58), "rock": Color8(140, 135, 148),
		"rock_red": Color8(160, 103, 74), "straw": Color8(230, 180, 58), "dark_roof": Color8(86, 80, 94), "jade": Color8(79, 168, 160),
		"buriti_leaf": Color8(90, 160, 72), "buriti_dark": Color8(47, 107, 62), "jungle_leaf": Color8(31, 59, 44),
	}
	for k: String in cols:
		_col_mat(k, cols[k], k.begins_with("banner") or k.begins_with("tent") or k.begins_with("buriti") or k == "bamboo")
	# chao com variacao em grande escala (ground_macro.gdshader); substitui so no dicionario deste mapa
	var noise := FastNoiseLite.new()
	noise.seed = 2709
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.noise = noise
	ResourceSaver.save(nt, "%s/tex_field_macro_noise.tres" % MAT_DIR)
	nt = load("%s/tex_field_macro_noise.tres" % MAT_DIR)
	var gsh := load("res://assets/environment/shaders/ground_macro.gdshader") as Shader
	var ground_tex := {"grass": "tex_grass_flowers_01", "cerrado": "tex_cerrado_grass_01", "lush_grass": "tex_lush_grass_01",
		"desert_sand": "tex_desert_sand_01", "snow": "tex_snow_01", "dry_meadow": "tex_dry_meadow_01", "birch_meadow": "tex_birch_meadow_01",
		"jungle_floor": "tex_jungle_floor_01", "moss_gravel": "tex_moss_gravel_01", "dirt": "tex_packed_dirt_01", "red_earth": "tex_red_earth_01",
		"stone_paving": "tex_stone_paving_01", "cobble": "tex_cobblestone_01"}
	for k: String in ground_tex:
		var gm := ShaderMaterial.new()
		gm.shader = gsh
		gm.set_shader_parameter(&"albedo_tex", load("%s/%s.png" % [TEX_DIR, ground_tex[k]]))
		gm.set_shader_parameter(&"macro_noise", nt)
		if k == "grass":
			gm.set_shader_parameter(&"tint_dark", Color(0.78, 0.84, 0.86))
			gm.set_shader_parameter(&"tint_light", Color(1.06, 1.02, 0.86))
		mats[k] = gm
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color8(245, 154, 106)
	fire.emission_enabled = true
	fire.emission = Color8(230, 180, 58)
	fire.emission_energy_multiplier = 2.2
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats["fire"] = fire
	var lan := StandardMaterial3D.new()
	lan.albedo_color = Color8(217, 85, 58)
	lan.emission_enabled = true
	lan.emission = Color8(217, 85, 58)
	lan.emission_energy_multiplier = 0.9
	mats["lantern_red"] = lan
	var portal := StandardMaterial3D.new()
	portal.albedo_color = Color8(168, 212, 245)
	portal.emission_enabled = true
	portal.emission = Color8(90, 144, 224)
	portal.emission_energy_multiplier = 1.6
	portal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal.albedo_color.a = 0.75
	portal.cull_mode = BaseMaterial3D.CULL_DISABLED
	portal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats["portal"] = portal
	var shadow := StandardMaterial3D.new()
	shadow.albedo_color = Color(0.09, 0.07, 0.12, 0.28)
	shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats["blob_shadow"] = shadow
	for k: String in ["sakura", "olive", "pine", "birch_leaf", "jungle_leaf", "thatch", "dark_roof"]:
		var fm := mats[k] as StandardMaterial3D
		fm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		fm.distance_fade_min_distance = 3.0
		fm.distance_fade_max_distance = 7.0
	for k: String in mats:
		var p := "%s/mat_field_%s.tres" % [MAT_DIR, k]
		if (mats[k] as Resource).resource_path == "":
			ResourceSaver.save(mats[k], p)
			(mats[k] as Resource).take_over_path(p)


## Kit pintado: chaos das nacoes, panos, rochas e folhagens residuais.
func _terrain_mat(grass_tex: String, alt_tex: String, tint: Color, alt_amount: float = 0.35) -> ShaderMaterial:
	var m := _kit("terrain")
	m.set_shader_parameter(&"splat_source", 0)
	m.set_shader_parameter(&"tex_grass", load(KIT + "textures/tex_%s.png" % grass_tex))
	m.set_shader_parameter(&"tex_grass_alt", load(KIT + "textures/tex_%s.png" % alt_tex))
	m.set_shader_parameter(&"grass_tint", tint)
	m.set_shader_parameter(&"grass_alt_amount", alt_amount)
	return m


## Chãos de mancha do campo (borda macia) e ordem de empilhamento (render_priority).
const FIELD_DECALS := {"cerrado": 1, "lush_grass": 1, "dry_meadow": 1, "birch_meadow": 1, "jungle_floor": 1,
	"moss_gravel": 1, "desert_sand": 1, "snow": 1, "stone_paving": 1, "cobble": 1, "sand": 2, "dirt": 3,
	"red_earth": 3, "ice": 4, "water": 5}


## Troca o shader do material pelo equivalente de "mancha" (borda macia) e ajusta a ordem.
static func as_decal(m: ShaderMaterial, priority: int) -> ShaderMaterial:
	var path := m.shader.resource_path
	if path.ends_with("env_terrain.gdshader"):
		m.shader = load("res://assets/shaders/env_terrain_decal.gdshader")
	elif path.ends_with("env_painted.gdshader") or path.ends_with("env_painted_2s.gdshader"):
		m.shader = load("res://assets/shaders/env_painted_decal.gdshader")
	m.render_priority = priority
	return m


func _paint_field_materials() -> void:
	var painted := {
		"grass": _terrain_mat("grass", "grass_lush", Color(1, 1, 1)),
		"hill": _terrain_mat("grass_lush", "grass", Color(0.8, 0.88, 0.78), 0.5),
		"cerrado": _terrain_mat("dry_grass", "grass", Color(1, 0.97, 0.9), 0.3),
		"lush_grass": _terrain_mat("grass", "grass_lush", Color(0.82, 0.95, 0.8), 0.3),
		"dry_meadow": _terrain_mat("dry_grass", "grass", Color(1.0, 0.93, 0.82), 0.2),
		"birch_meadow": _terrain_mat("grass", "grass_lush", Color(1.02, 1.05, 0.92), 0.5),
		"jungle_floor": _terrain_mat("grass_lush", "jungle_floor", Color(0.72, 0.86, 0.66), 0.35),
		"moss_gravel": _terrain_mat("grass_lush", "gravel", Color(0.86, 0.96, 0.8), 0.4),
		"desert_sand": _kit_tint("ground_sand", Color(1.05, 0.95, 0.8)),
		"snow": _kit("ground_snow"),
		"ice": _kit("ground_ice"),
		"dirt": _kit_tint("ground_dirt", Color(0.94, 0.88, 0.77), {"tile_m": 3.2, "detail": 0.52}),
		"red_earth": _kit("ground_red_earth"),
		"stone_paving": _kit_tint("paving", Color(0.92, 0.92, 0.95), {"tile_m": 3.0, "detail": 0.8}),
		"cobble": _kit_tint("paving", Color(0.98, 0.95, 0.9), {"tile_m": 4.0, "detail": 0.8}),
		"thatch": _kit_2s("tex_thatch.png", Color(1, 0.95, 0.85), {"uv_scale": tile_uv(2.0)}),
		"straw": _kit_2s("tex_thatch.png", Color(1.05, 0.95, 0.75), {"uv_scale": tile_uv(1.0)}),
		"dark_roof": _kit_2s("tex_roof_canal.png", Color(0.55, 0.56, 0.64), {"uv_scale": tile_uv(2.6)}),
		"birch_bark": _kit("bark_birch"),
		"obsidian": _kit_tint("stonewall", Color(0.3, 0.27, 0.33)),
		"sandstone": _kit_tint("stonewall", Color(1.08, 0.92, 0.72)),
		"mudbrick": _kit_tint("plaster_warm", Color(0.78, 0.55, 0.4), {"grime_height": 0.6}),
		"jade": _kit_tint("plaster_warm", Color(0.55, 0.85, 0.75)),
		"termite": _kit("termite"),
		"termite_hi": _kit_tint("termite", Color(1.1, 1.0, 0.95)),
		"rock": _kit("rock_moss"),
		"rock_red": _kit("rock_red"),
		"olive": _kit("canopy_olive"), "pine": _kit("needles"), "pine_snow": _kit("needles_snow"),
		"sakura": _kit("canopy_sakura"), "birch_leaf": _kit("canopy_birch"), "jungle_leaf": _kit("canopy_jungle"),
		"buriti_leaf": _kit("palm_leaf"), "buriti_dark": _kit("palm_leaf_dark"), "bamboo": _kit("bamboo"),
		"heather": _kit_tint("plaster_warm", Color(0.6, 0.45, 0.8)),
	}
	for k: String in ["banner_brasil", "banner_portugal", "banner_grecia", "banner_egito", "banner_celta", "banner_nordico",
			"banner_eslavo", "banner_china", "banner_japao", "banner_mexico", "tent_a", "tent_b"]:
		var c: Color = (mats[k] as StandardMaterial3D).albedo_color
		painted[k] = _kit_2s("tex_plaster.png", c * 1.08, {"triplanar": true, "tile_m": 2.0, "detail": 0.6})
	painted["sand"] = _kit_tint("ground_sand", Color(1.02, 0.97, 0.88))
	painted["water"] = (load(KIT + "materials/mat_water.tres") as ShaderMaterial).duplicate()
	for k: String in FIELD_DECALS:
		if painted.has(k):
			painted[k] = as_decal(painted[k], FIELD_DECALS[k])
	for k: String in painted:
		mats[k] = painted[k]
		var path := "%s/mat_field_%s.tres" % [MAT_DIR, k]
		ResourceSaver.save(mats[k], path)
		(mats[k] as Resource).take_over_path(path)


# ---------------------------------------------------------------- primitivas extras
## Disco com borda irregular (clareiras); y acima do chao base.
func _st(mat_name: String) -> SurfaceTool:
	if mat_name in ORGANIC_MUTED:
		var trash := SurfaceTool.new()
		trash.begin(Mesh.PRIMITIVE_TRIANGLES)
		return trash
	return super(mat_name)


func flat_disc(mat_name: String, c: Vector3, r: float, y: float) -> void:
	if not mute_geo and mat_name in ORGANIC_MUTED and mat_name != "blob_shadow":
		if mat_name == "water":
			relief.ponds.append([Vector2(c.x, c.z), r, 1.0])
		else:
			relief.shapes.append([mat_name, Vector2(c.x, c.z), r, 0.08])
	super(mat_name, c, r, y)


func ribbon(mat_name: String, pts: Array, w: float, y: float, feather: float) -> void:
	if mat_name != "water":
		var p2 := PackedVector2Array()
		for p: Vector3 in pts:
			p2.append(Vector2(p.x, p.z))
		relief.ribbons.append([mat_name, p2, w])
	super(mat_name, pts, w, y, feather)


func disc(mat_name: String, c: Vector3, r: float, y: float, wobble: float = 0.12, segs: int = 28) -> void:
	if mat_name in ["water", "ice"]:
		relief.ponds.append([Vector2(c.x, c.z), r, 1.1 if mat_name == "water" else 0.6, mat_name])
	elif not mute_geo:
		relief.shapes.append([mat_name, Vector2(c.x, c.z), r, 0.1])
	var was_muted := mute_geo
	if mat_name in ["water", "ice"]:
		mute_geo = false # lagos continuam (a construção dos marcos é silenciada em volta)
	_disc_impl(mat_name, c, r, y, wobble, segs)
	mute_geo = was_muted


func _disc_impl(mat_name: String, c: Vector3, r: float, y: float, wobble: float, segs: int) -> void:
	var pts: Array[Vector3] = []
	var ph := rng.randf() * TAU
	for i in segs:
		var a := TAU * i / segs
		var rr := r * (1.0 + wobble * sin(a * 3.0 + ph) + wobble * 0.5 * sin(a * 7.0 + ph * 2.0))
		pts.append(Vector3(c.x + cos(a) * rr, y, c.z + sin(a) * rr))
	for i in segs:
		tri(mat_name, Vector3(c.x, y, c.z), pts[(i + 1) % segs], pts[i])
	if decal_mats.has(mat_name):
		feather_ring(mat_name, Vector3(c.x, y, c.z), pts, clampf(r * 0.12, FEATHER_MIN, FEATHER_MAX))


## Faixa (trilha) de a ate b, largura w.
func strip(mat_name: String, a: Vector3, b: Vector3, w: float, y: float) -> void:
	if mat_name in ["dirt", "red_earth"]:
		trails.append([a, b, w * 0.5])
	if not mute_geo and mat_name != "water":
		relief.strips.append([mat_name, Vector2(a.x, a.z), Vector2(b.x, b.z), w])
	var d := (b - a)
	d.y = 0
	var s := Vector3(-d.z, 0, d.x).normalized() * w * 0.5
	var ya := Vector3(0, y, 0)
	quad(mat_name, Vector3(a.x, 0, a.z) - s + ya, Vector3(a.x, 0, a.z) + s + ya, Vector3(b.x, 0, b.z) + s + ya, Vector3(b.x, 0, b.z) - s + ya)
	if decal_mats.has(mat_name):
		var f := s.normalized() * clampf(w * 0.45, FEATHER_MIN, FEATHER_MAX)
		var A := Vector3(a.x, 0, a.z) + ya
		var B := Vector3(b.x, 0, b.z) + ya
		feather_quad(mat_name, A + s, B + s, B + s + f, A + s + f)
		feather_quad(mat_name, B - s, A - s, A - s - f, B - s - f)


## Trilha curva por pontos (com arredondamento nas juncoes).
func trail(mat_name: String, pts: Array, w: float, y: float) -> void:
	for i in pts.size() - 1:
		strip(mat_name, pts[i], pts[i + 1], w, y)
	for i in range(1, pts.size() - 1):
		flat_disc(mat_name, pts[i], w * 0.5, y + 0.001)
	# pontas arredondadas com franja macia (sem borda reta de retângulo)
	if decal_mats.has(mat_name):
		for e: Vector3 in [pts[0], pts[pts.size() - 1]]:
			flat_disc(mat_name, e, w * 0.5, y + 0.0005)


## Telhado de duas aguas (cumeeira ao longo de X local).
func gable_roof(mat_name: String, gable_mat: String, c: Vector3, w: float, d: float, h: float, yaw: float, over: float = 0.4) -> void:
	var tr := Transform3D(Basis(Vector3.UP, yaw), c)
	var x := w * 0.5 + over
	var z := d * 0.5 + over
	var P := func(px: float, py: float, pz: float) -> Vector3: return tr * Vector3(px, py, pz)
	quad(mat_name, P.call(-x, 0, z), P.call(x, 0, z), P.call(x, h, 0), P.call(-x, h, 0))
	quad(mat_name, P.call(x, 0, -z), P.call(-x, 0, -z), P.call(-x, h, 0), P.call(x, h, 0))
	tri(gable_mat, P.call(x - over, 0, d * 0.5), P.call(x - over, 0, -d * 0.5), P.call(x - over, h, 0))
	tri(gable_mat, P.call(-x + over, 0, -d * 0.5), P.call(-x + over, 0, d * 0.5), P.call(-x + over, h, 0))


## Casa simples: paredes + telhado de duas aguas; bloqueia o navmesh.
func hut(c: Vector3, w: float, d: float, wall_h: float, yaw: float, wall: String, roof_mat: String, roof_h: float = 1.6) -> void:
	box(wall, c, Vector3(w, wall_h, d), yaw)
	gable_roof(roof_mat, wall, c + Vector3(0, wall_h, 0), w, d, roof_h, yaw)
	var tr := Transform3D(Basis(Vector3.UP, yaw), c)
	box("dark_wood", tr * Vector3(0, 0, d * 0.5 + 0.02), Vector3(0.9, 1.6, 0.06), yaw)
	obstruct_rect(c, w + 0.4, d + 0.4, yaw)


func blob_shadow(c: Vector3, r: float) -> void:
	# kit pintado: sombra real do sol; a mancha escura falsa nao e mais desenhada
	mute_geo = true
	flat_disc("blob_shadow", c, r, 0.045)
	mute_geo = false


## Arvore/enfeite grande em sprite (se a arte existir): sombra oval no chao + circulo bloqueado.
func _spr_ok(tex: String) -> bool:
	return ResourceLoader.exists("%s/%s.png" % [SPR_DIR, tex])


func tree_spr(tex: String, c: Vector3, s: float, block_r: float, shadow_r: float) -> void:
	sprites.append([tex, c, s])
	blob_shadow(c + Vector3(0.5, 0, 0.35) * s, shadow_r * s)
	obstruct_circle(c, block_r * s)


const LEAF_SPR := {"olive": "fld_olive_tree", "sakura": "fld_sakura", "birch_leaf": "fld_birch", "jungle_leaf": "fld_jungle_tree",
	"leaves": "fld_leafy_tree", "ipe_yellow": "fld_ipe_yellow", "ipe_purple": "fld_ipe_purple"}


## Arvore redonda generica (copa em bolhas).
func round_tree(c: Vector3, leaf: String, s: float = 1.0, trunk: String = "trunk") -> void:
	if LEAF_SPR.has(leaf) and _spr_ok(LEAF_SPR[leaf]):
		tree_spr(LEAF_SPR[leaf], c, s * 0.95, 0.5, 1.9)
		return
	var h := 2.6 * s
	cyl(trunk, c, c + Vector3(0.15, h, 0.1), 0.25 * s, 6, false)
	blob(leaf, c + Vector3(0.15, h + 0.7 * s, 0.1), Vector3(1.7, 1.3, 1.7) * s, 8, 4)
	blob(leaf, c + Vector3(-0.8, h + 0.1 * s, 0.5), Vector3(1.1, 0.9, 1.1) * s, 7, 3)
	blob(leaf, c + Vector3(0.9, h + 0.3 * s, -0.4), Vector3(1.0, 0.9, 1.0) * s, 7, 3)
	blob_shadow(c + Vector3(0.6, 0, 0.4), 1.7 * s)
	obstruct_circle(c, 0.45 * s)


func pine(c: Vector3, s: float = 1.0, snowy: bool = false) -> void:
	if _spr_ok("fld_pine_snow"):
		tree_spr("fld_pine_snow", c, s * 0.9, 0.5, 1.6)
		return
	cyl("trunk", c, c + Vector3(0, 1.2 * s, 0), 0.22 * s, 5, false)
	for k in 3:
		var base := c + Vector3(0, (1.0 + k * 1.3) * s, 0)
		var r := (1.8 - k * 0.45) * s
		var mat := "pine_snow" if snowy and k == 2 else "pine"
		for i in 7:
			var a0 := TAU * i / 7
			var a1 := TAU * (i + 1) / 7
			tri(mat, base + Vector3(0, 2.0 * s, 0), base + Vector3(cos(a1) * r, 0, sin(a1) * r), base + Vector3(cos(a0) * r, 0, sin(a0) * r))
	blob_shadow(c + Vector3(0.5, 0, 0.3), 1.5 * s)
	obstruct_circle(c, 0.5 * s)


## Palmeira (tamareira/buriti): tronco alto + folhas em leque.
func palm(c: Vector3, s: float, leaf_a: String, leaf_b: String, fan: bool = false) -> void:
	var ptex := "fld_buriti" if fan else "fld_date_palm"
	if _spr_ok(ptex):
		tree_spr(ptex, c, s * 0.95, 0.4, 1.7)
		return
	var top := c + Vector3(0.3 * s, 5.5 * s, 0.1 * s)
	cyl("trunk", c, top, 0.24 * s, 6, false)
	var nf := 11 if fan else 8
	for i in nf:
		var a := TAU * i / nf + rng.randf() * 0.3
		var dirv := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dirv.z, 0, dirv.x)
		var L := (2.0 if fan else 2.4) * s
		var mid := top + dirv * L * 0.5 + Vector3(0, 0.45 * s, 0)
		var tip := top + dirv * L + Vector3(0, (0.1 if fan else -0.6) * s, 0)
		var wdt := (0.75 if fan else 0.4) * s
		var mat := leaf_a if i % 2 == 0 else leaf_b
		quad(mat, top, mid + side * wdt, tip, mid - side * wdt)
	if fan: # cachos de coquinhos do buriti
		blob("rock_red", top + Vector3(0, -0.5 * s, 0), Vector3(0.45, 0.35, 0.45) * s, 6, 3)
	blob_shadow(c + Vector3(0.6, 0, 0.3), 1.8 * s)
	obstruct_circle(c, 0.4 * s)


## Ipe: tronco torto e copa florida (amarelo ou roxo).
func ipe(c: Vector3, kind: String, s: float = 1.0) -> void:
	if _spr_ok("fld_" + kind):
		tree_spr("fld_" + kind, c, s * 1.05, 0.55, 2.8)
		mute_geo = true # flores caidas quadradas: RNG mantido, sem geometria
		for i in 30:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 3.4 * s
			var p := c + Vector3(cos(a) * d, 0.06, sin(a) * d)
			var q := 0.09
			quad("cloth_yellow" if kind == "ipe_yellow" else "flower_pink", p + Vector3(-q, 0, q), p + Vector3(q, 0, q), p + Vector3(q, 0, -q), p + Vector3(-q, 0, -q))
		mute_geo = false
		return
	var fork := c + Vector3(0.4 * s, 3.0 * s, 0.2 * s)
	cyl("trunk", c, fork, 0.3 * s, 6, false)
	for tip: Vector3 in [Vector3(-2.0, 4.6, -0.8), Vector3(2.2, 4.8, 0.5), Vector3(0.2, 5.4, 1.4), Vector3(-0.4, 5.0, -1.6)]:
		cyl("trunk", fork, c + tip * s, 0.16 * s, 5, false)
	var cc := c + Vector3(0.2, 5.4, 0) * s
	for i in 14:
		var th := rng.randf() * TAU
		var ph := acos(1.0 - rng.randf() * 1.2)
		var dv := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
		var rr := rng.randf_range(0.8, 1.2) * s
		blob(kind, cc + Vector3(dv.x * 2.6, dv.y * 1.2, dv.z * 2.6) * s, Vector3(rr, rr * 0.8, rr), 6, 3)
	# flores caidas no chao
	for i in 26:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 3.6 * s
		var p := c + Vector3(cos(a) * d, 0.06, sin(a) * d)
		var q := 0.1
		quad("cloth_yellow" if kind == "ipe_yellow" else "flower_pink", p + Vector3(-q, 0, q), p + Vector3(q, 0, q), p + Vector3(q, 0, -q), p + Vector3(-q, 0, -q))
	blob_shadow(c + Vector3(0.8, 0, 0.5), 2.8 * s)
	obstruct_circle(c, 0.55 * s)


## Cupinzeiro: morrinho de terra vermelha, alto e pontudo.
func termite_mound(c: Vector3, s: float) -> void:
	if _spr_ok("fld_termite_mound"):
		tree_spr("fld_termite_mound", c, s * 1.1, 0.8, 1.0)
		return
	blob("termite", c + Vector3(0, 0.5 * s, 0), Vector3(0.9, 0.7, 0.9) * s, 7, 3)
	cyl("termite", c + Vector3(0, 0.6 * s, 0), c + Vector3(0.1, 1.9 * s, 0), 0.5 * s, 6, false)
	blob("termite_hi", c + Vector3(0.1, 1.95 * s, 0), Vector3(0.45, 0.4, 0.45) * s, 6, 3)
	blob("termite", c + Vector3(0.55 * s, 0.9 * s, 0.1), Vector3(0.35, 0.6, 0.35) * s, 6, 3)
	blob_shadow(c + Vector3(0.3, 0, 0.2), 1.0 * s)
	obstruct_circle(c, 0.9 * s)


func rock(c: Vector3, s: float, mat: String = "rock") -> void:
	var rt := "fld_red_rock" if mat == "rock_red" else "fld_grey_rock"
	if _spr_ok(rt):
		tree_spr(rt, c, s * 1.6, 0.6, 0.8)
		return
	blob(mat, c + Vector3(0, 0.35 * s, 0), Vector3(0.9, 0.6, 0.75) * s, 6, 3)
	obstruct_circle(c, 0.8 * s)


## Bandeiras com o brasão de cada nação (assets/environment/banners/banner_<nação>.png).
var banners: Array = []   # [posição do topo junto ao mastro, nação, yaw]

func banner_pole(c: Vector3, mat: String, h: float = 4.0, face_camp: bool = false) -> void:
	cyl("dark_wood", c, c + Vector3(0, h, 0), 0.08, 5)
	# o pano fica virado para o centro do acampamento (quem está no meio lê todos os brasões); nas zonas,
	# de frente para quem chega do acampamento (face_camp)
	var yaw := atan2(-c.x, -c.z) + (0.0 if face_camp else PI * 0.5)
	banners.append([c + Vector3(0, h - 0.2, 0), mat.trim_prefix("banner_"), yaw])
	obstruct_circle(c, 0.25, 3.0)


func _add_banners(parent: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Banners"
	_add(parent, node)
	var shader: Shader = load("res://assets/shaders/env_banner.gdshader")
	for b: Array in banners:
		var tex_path := "res://assets/environment/banners/banner_%s.png" % b[1]
		if not ResourceLoader.exists(tex_path):
			continue
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"banner_tex", load(tex_path))
		var q := QuadMesh.new()
		q.size = Vector2(BANNER_W, BANNER_H)
		q.center_offset = Vector3(BANNER_W * 0.5, -BANNER_H * 0.5, 0)   # canto superior esquerdo no mastro
		q.subdivide_width = 8
		q.subdivide_depth = 4
		q.material = m
		var mi := MeshInstance3D.new()
		mi.name = "Banner_" + String(b[1])
		mi.mesh = q
		mi.position = b[0] + Vector3(0.09, 0, 0).rotated(Vector3.UP, b[2])
		mi.rotation.y = b[2]
		_add(node, mi)

const BANNER_W: float = 1.2
const BANNER_H: float = 1.8


func tent(c: Vector3, yaw: float, mat: String) -> void:
	kit_items.append(["camp_tent_v2_a" if mat == "tent_a" else "camp_tent_v2_b", Transform3D(Basis(Vector3.UP, yaw), c)])
	var was_muted := mute_geo
	mute_geo = true
	_tent_old(c, yaw, mat)
	mute_geo = was_muted


func _tent_old(c: Vector3, yaw: float, mat: String) -> void:
	var tr := Transform3D(Basis(Vector3.UP, yaw), c)
	var P := func(x: float, y: float, z: float) -> Vector3: return tr * Vector3(x, y, z)
	var w := 1.6
	var L := 1.8
	var h := 2.0
	quad(mat, P.call(-L, 0, w), P.call(L, 0, w), P.call(L, h, 0), P.call(-L, h, 0))
	quad(mat, P.call(L, 0, -w), P.call(-L, 0, -w), P.call(-L, h, 0), P.call(L, h, 0))
	tri(mat, P.call(-L, 0, -w), P.call(-L, 0, w), P.call(-L, h, 0))
	tri("dark_wood", P.call(L, 0, w * 0.5), P.call(L, 0, -w * 0.5), P.call(L, h * 0.5, 0))
	tri(mat, P.call(L, 0, w), P.call(L, 0, -w), P.call(L, h, 0))
	cyl("dark_wood", P.call(L + 0.1, 0, 0), P.call(L + 0.1, h + 0.3, 0), 0.05, 4)
	obstruct_rect(c, L * 2 + 0.6, w * 2 + 0.4, yaw, 2.5)


func campfire(c: Vector3, s: float = 1.0) -> void:
	kit_items.append(["camp_fire_v2", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), c)])
	var was_muted := mute_geo
	mute_geo = true
	_campfire_old(c, s)
	mute_geo = was_muted


func _campfire_old(c: Vector3, s: float = 1.0) -> void:
	for i in 8:
		var a := TAU * i / 8
		blob("rock", c + Vector3(cos(a) * 0.9 * s, 0.12, sin(a) * 0.9 * s), Vector3(0.28, 0.2, 0.28) * s, 5, 2)
	for i in 4:
		var a := TAU * i / 4 + 0.4
		cyl("dark_wood", c + Vector3(cos(a) * 0.6 * s, 0.1, sin(a) * 0.6 * s), c + Vector3(0, 0.55 * s, 0), 0.09 * s, 5)
	blob("fire", c + Vector3(0, 0.55 * s, 0), Vector3(0.35, 0.6, 0.35) * s, 6, 3)
	obstruct_circle(c, 1.1 * s, 1.0)


func fence_line(a: Vector3, b: Vector3) -> void:
	var n := int(a.distance_to(b) / 1.5) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		cyl("dark_wood", p, p + Vector3(0, 1.0, 0), 0.07, 4)
	for y: float in [0.45, 0.85]:
		cyl("trunk", a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.05, 4, false)


## Boneco de treino de palha (enfeite; a provacao e de Q).
func dummy(c: Vector3) -> void:
	cyl("dark_wood", c, c + Vector3(0, 1.6, 0), 0.07, 4)
	cyl("dark_wood", c + Vector3(-0.6, 1.2, 0), c + Vector3(0.6, 1.2, 0), 0.05, 4)
	blob("straw", c + Vector3(0, 1.05, 0), Vector3(0.32, 0.45, 0.25), 6, 3)
	blob("straw", c + Vector3(0, 1.65, 0), Vector3(0.22, 0.22, 0.22), 6, 3)
	obstruct_circle(c, 0.35, 1.8)


# ---------------------------------------------------------------- mundo
func _build_field() -> void:
	_build_field_ground()
	_build_camp()
	_build_pindorama()
	for n: Array in NATIONS:
		_build_nation(n)
	_build_relief()
	_build_border()
	_build_sprinkles()
	_arrival_ground()


func _build_field_ground() -> void:
	# chao base (cerrado claro) muito alem do disco util; caminhavel so dentro de FIELD_R
	flat("grass", -260, -260, 260, 260, 0.0)
	var segs := 48
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := Vector3(cos(a0) * FIELD_R, 0, sin(a0) * FIELD_R)
		var p1 := Vector3(cos(a1) * FIELD_R, 0, sin(a1) * FIELD_R)
		walk_faces.append_array(PackedVector3Array([Vector3.ZERO, p0, p1]))


func _build_camp() -> void:
	disc("dirt", Vector3(0, 0, -1.0), 4.8, 0.03, 0.12, 40)
	campfire(Vector3(0, 0, -1.5), 1.0)
	pois.append(["CampFire", Vector3(0, 0, -1.5)])
	npc_points.append(["instructor_bento", Vector3(2.4, 0, 1.8), deg_to_rad(-135.0)])

	# tendas em arco (lado oeste/leste), caixotes e barris
	var ti := 0
	for deg: float in [200.0, 225.0, 320.0, 345.0]:
		var p := pol(deg, CAMP_R - 4.0)
		tent(p, atan2(-p.x, -p.z) + PI / 2, "tent_a" if ti % 2 == 0 else "tent_b")
		ti += 1
	for c: Vector3 in [Vector3(-9.5, 0, 3.0), Vector3(-10.4, 0, 4.2), Vector3(9.8, 0, 3.6)]:
		var cy := rng.randf()
		kit_items.append(["pk_crate_wooden" if c.x < 0 else "pk_barrel", Transform3D(Basis(Vector3.UP, cy), c)])
		mute_geo = true
		box("wood", c, Vector3(0.9, 0.8, 0.9), cy)
		mute_geo = false
		obstruct_rect(c, 1.1, 1.1)
	# bandeiras das 10 nacoes em roda, cada uma virada para o caminho da sua terra
	banner_pole(pol(90.0, CAMP_R - 1.2), "banner_brasil")
	for n: Array in NATIONS:
		banner_pole(pol(n[1], CAMP_R - 1.2), n[4])
	# portal de saida: arco de pedra com veu de luz (Ponte da Travessia)
	var yaw := atan2(PORTAL_POS.x, PORTAL_POS.z) # arco de frente para o centro
	var tr := Transform3D(Basis(Vector3.UP, yaw), PORTAL_POS)
	for sx: float in [-1.9, 1.9]:
		box("stone", tr * Vector3(sx, 0, 0), Vector3(0.9, 4.2, 0.9), yaw)
		obstruct_rect(tr * Vector3(sx, 0, 0), 1.0, 1.0, yaw)
	box("stone", tr * Vector3(0, 4.2, 0), Vector3(4.9, 0.7, 1.0), yaw)
	box("azulejo", tr * Vector3(0, 4.9, 0), Vector3(2.0, 0.5, 0.6), yaw)
	quad("portal", tr * Vector3(-1.45, 0.05, 0), tr * Vector3(1.45, 0.05, 0), tr * Vector3(1.45, 4.2, 0), tr * Vector3(-1.45, 4.2, 0))
	obstruct_rect(PORTAL_POS, 2.8, 0.5, yaw, 4.0) # nao se atravessa andando: o portal e clicavel
	pois.append(["ExitPortal", PORTAL_POS])
	# trilhas de terra do acampamento para cada nacao
	for n: Array in NATIONS:
		var a: float = n[1]
		trail("dirt", [pol(a, CAMP_R - 1.0), pol(a + 3.0, 30.0), pol(a - 2.0, ZONE_R - n[3] * 0.6)], 2.6, 0.025)
	trail("red_earth", [pol(90.0, CAMP_R - 1.0), Vector3(1.0, 0, 24.0), RANCHO + Vector3(0, 0, -4.0)], 3.0, 0.026)


# ---------------------------------------------------------------- Terra de Pindorama
func _build_pindorama() -> void:
	for sp: Vector3 in [Vector3(-17, 0, 42), Vector3(19, 0, 46), Vector3(-27, 0, 63), Vector3(26, 0, 64), Vector3(-12, 0, 79), Vector3(12, 0, 82)]:
		keepout.append([sp, 4.0])
	disc("cerrado", PINDORAMA_C, 36.0, 0.015, 0.08, 40)
	ground_discs.append(["grass", PINDORAMA_C, 36.0])
	# riacho (vereda) atravessando de oeste a leste, com buritis nas margens
	stream_pts = [Vector3(-44, 0, 60), Vector3(-30, 0, 55), Vector3(-16, 0, 59), Vector3(-4, 0, 56), Vector3(8, 0, 58),
		Vector3(20, 0, 54), Vector3(32, 0, 58), Vector3(44, 0, 63)]
	var bridge_seg := 3 # trecho com ponte (trilha principal)
	var ford_seg := 5 # vau de pedras
	for i in stream_pts.size() - 1:
		var a: Vector3 = stream_pts[i]
		var b: Vector3 = stream_pts[i + 1]
		if i != bridge_seg and i != ford_seg:
			var mid := (a + b) * 0.5
			obstruct_rect(mid, a.distance_to(b) + 1.2, 3.2, atan2(-(b - a).z, (b - a).x))
	# margem de areia e água: faixas contínuas com borda macia (sem emendas)
	ribbon("sand", stream_pts, 5.2, 0.02, 1.6)
	ribbon("water", stream_pts, 3.0, 0.04, 0.9)
	# ponte de madeira no trecho da trilha
	var ba: Vector3 = stream_pts[bridge_seg]
	var bb: Vector3 = stream_pts[bridge_seg + 1]
	var bm := (ba + bb) * 0.5
	var byaw := atan2(-(bb - ba).z, (bb - ba).x)
	box("wood", bm + Vector3(0, 0.05, 0), Vector3(2.6, 0.18, 4.6), byaw)
	for sx: float in [-1.2, 1.2]:
		var tr := Transform3D(Basis(Vector3.UP, byaw), bm)
		cyl("dark_wood", tr * Vector3(sx, 0, -2.2), tr * Vector3(sx, 0.9, -2.2), 0.07, 4)
		cyl("dark_wood", tr * Vector3(sx, 0, 2.2), tr * Vector3(sx, 0.9, 2.2), 0.07, 4)
		cyl("trunk", tr * Vector3(sx, 0.85, -2.2), tr * Vector3(sx, 0.85, 2.2), 0.05, 4, false)
	# vau: pedras chatas
	var fa: Vector3 = stream_pts[ford_seg]
	var fb: Vector3 = stream_pts[ford_seg + 1]
	for k in 5:
		var p := fa.lerp(fb, 0.3 + k * 0.1) + Vector3(0, 0, -1.6 + k * 0.8)
		blob("rock", p + Vector3(0, 0.08, 0), Vector3(0.45, 0.12, 0.4), 6, 2)
	# buritis ao longo do riacho
	for i in stream_pts.size() - 1:
		var a: Vector3 = stream_pts[i]
		var b: Vector3 = stream_pts[i + 1]
		if i == bridge_seg:
			continue
		for k in 2:
			var p := a.lerp(b, 0.25 + 0.5 * k)
			var side := 1.0 if (i + k) % 2 == 0 else -1.0
			palm(p + Vector3(rng.randf_range(-1.0, 1.0), 0, side * rng.randf_range(3.8, 5.0)), rng.randf_range(1.0, 1.35), "buriti_leaf", "buriti_dark", true)
	# trilha de terra vermelha: rancho -> ponte -> sul
	trail("red_earth", [RANCHO + Vector3(0, 0, 4.5), Vector3(-2, 0, 48), bm, Vector3(-3, 0, 66), Vector3(-1, 0, 80)], 2.8, 0.027)
	trail("red_earth", [RANCHO + Vector3(3, 0, 3), Vector3(16, 0, 44), Vector3(25, 0, 52)], 2.2, 0.027)
	# rancho dos Mestres: casa de pau a pique com telhado de sape, cerca, bonecos de treino, fogueira
	# rancho aconchegante (modelo original, tools/art/blender/camp.py): varanda de sapê virada para o acampamento,
	# rede, potes de barro. A geometria antiga só registra a obstrução (mesma planta).
	kit_items.append(["camp_rancho", Transform3D(Basis(Vector3.UP, PI), RANCHO + Vector3(-5.5, 0, -1.5))])
	var was_muted := mute_geo
	mute_geo = true
	hut(RANCHO + Vector3(-5.5, 0, -1.5), 5.0, 3.6, 2.3, 0.0, "wall_white", "thatch", 1.8)
	box("dark_wood", RANCHO + Vector3(-5.5, 0, 0.7), Vector3(5.6, 0.2, 1.4))
	mute_geo = was_muted
	fence_line(RANCHO + Vector3(2.0, 0, -4.0), RANCHO + Vector3(11.0, 0, -4.0))
	fence_line(RANCHO + Vector3(11.0, 0, -4.0), RANCHO + Vector3(11.0, 0, 3.0))
	for x: float in [4.5, 7.0, 9.5]:
		dummy(RANCHO + Vector3(x, 0, -2.2))
	pois.append(["TrainingDummies", RANCHO + Vector3(7.0, 0, -0.5)])
	campfire(RANCHO + Vector3(-1.0, 0, 3.0), 0.9)
	banner_pole(RANCHO + Vector3(-2.2, 0, -3.6), "banner_brasil", 4.5, true)
	npc_points.append(["master_jatoba", RANCHO + Vector3(1.8, 0, 0.6), _yaw_of(-RANCHO)])
	npc_points.append(["master_candeia", RANCHO + Vector3(-3.4, 0, 2.4), _yaw_of(-RANCHO)])
	npc_points.append(["master_inhambu", RANCHO + Vector3(5.5, 0, 1.8), _yaw_of(-RANCHO)])

	pois.append(["Rancho", RANCHO])
	pois.append(["Area_brasil", PINDORAMA_C])
	# ipes grandes (amarelos e roxos) e arvores tortas do cerrado
	var ipes := [[Vector3(-14, 0, 34), "ipe_yellow", 1.3], [Vector3(15, 0, 31), "ipe_purple", 1.1], [Vector3(-26, 0, 46), "ipe_yellow", 1.0],
		[Vector3(27, 0, 42), "ipe_yellow", 1.2], [Vector3(-12, 0, 70), "ipe_purple", 1.2], [Vector3(14, 0, 72), "ipe_yellow", 1.4],
		[Vector3(-30, 0, 68), "ipe_purple", 0.9], [Vector3(31, 0, 70), "ipe_purple", 1.0], [Vector3(2, 0, 84), "ipe_yellow", 1.6]]
	for e: Array in ipes:
		ipe(e[0], e[1], e[2])
	# cupinzeiros espalhados
	for c: Vector3 in [Vector3(-8, 0, 42), Vector3(9, 0, 40), Vector3(-21, 0, 38), Vector3(22, 0, 36), Vector3(-18, 0, 77),
			Vector3(20, 0, 80), Vector3(-5, 0, 75), Vector3(8, 0, 68), Vector3(-34, 0, 60), Vector3(35, 0, 52), Vector3(-24, 0, 84)]:
		termite_mound(c, rng.randf_range(0.8, 1.3))
	for i in 18:
		var p := PINDORAMA_C + pol(rng.randf() * 360.0, rng.randf_range(8.0, 33.0))
		if _near_stream(p, 4.0) or p.distance_to(RANCHO) < 9.0 or _in_obstruction(p, 1.2) or _in_keepout(p):
			continue
		rock(p, rng.randf_range(0.5, 1.0), "rock_red")
	# arvores tortas do cerrado (pequizeiros)
	for i in 16:
		var p := PINDORAMA_C + pol(rng.randf() * 360.0, rng.randf_range(10.0, 35.0))
		if _near_stream(p, 4.5) or p.distance_to(RANCHO) < 10.0 or _in_obstruction(p, 2.0) or _on_trail(p) or _in_keepout(p):
			continue
		if _spr_ok("fld_pequi_tree"):
			tree_spr("fld_pequi_tree", p, rng.randf_range(0.9, 1.25), 0.45, 1.6)
	# marcos de pedra antigos (quest de explorar, GDD 9.2 A2)
	var mi := 1
	for c: Vector3 in [Vector3(-33, 0, 44), Vector3(34, 0, 64), Vector3(-6, 0, 86)]:
		box("rock", c, Vector3(0.8, 2.2, 0.5), rng.randf() * PI)
		box("azulejo", c + Vector3(0, 1.4, 0), Vector3(0.84, 0.4, 0.54), 0.0)
		obstruct_circle(c, 0.6)
		pois.append(["StoneMark%d" % mi, c + Vector3(0, 0, -1.6)])
		mi += 1
	# pontos de vista (GDD 17.11)
	_viewpoint(Vector3(-20, 0, 51.2), PI, "bench_vereda") # olhando o riacho com buritis
	_viewpoint(Vector3(15.5, 0, 75.8), 0.25, "bench_ipe") # sob o ipe amarelo grande
	_viewpoint(RANCHO + Vector3(-2.8, 0, 5.8), PI * 0.9, "bench_rancho") # fogueira do rancho
	# spawns (contrato: Spawns/ Marker3D com monster_id, count, radius_cells)
	# Mais monstros + 1–2 médios por área (dono, 28/09/2026: progressão menos demorada).
	spawns.append(["pindorama_whirlwind_1", Vector3(-17, 0, 42), "prank_whirlwind", 8, 6])
	spawns.append(["pindorama_whirlwind_2", Vector3(19, 0, 46), "prank_whirlwind", 8, 6])
	spawns.append(["pindorama_whirlwind_med", Vector3(-30, 0, 50), "prank_whirlwind", 2, 5, 2])
	spawns.append(["pindorama_firefly_1", Vector3(-27, 0, 63), "enchanted_firefly", 7, 5])
	spawns.append(["pindorama_firefly_2", Vector3(26, 0, 64), "enchanted_firefly", 7, 5])
	spawns.append(["pindorama_firefly_med", Vector3(34, 0, 70), "enchanted_firefly", 1, 4, 2])
	spawns.append(["pindorama_armadillo_1", Vector3(-12, 0, 79), "stone_armadillo", 5, 5])
	spawns.append(["pindorama_armadillo_2", Vector3(12, 0, 82), "stone_armadillo", 5, 5])
	spawns.append(["pindorama_armadillo_med", Vector3(-24, 0, 88), "stone_armadillo", 1, 4, 2])


func _near_stream(p: Vector3, d: float) -> bool:
	for i in stream_pts.size() - 1:
		var a: Vector3 = stream_pts[i]
		var b: Vector3 = stream_pts[i + 1]
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
		if q.distance_to(Vector2(p.x, p.z)) < d:
			return true
	return false


## Banco virado para yaw (convencao do jogo: 0 = olhando para -Z).
func _viewpoint(seat: Vector3, yaw: float, id: String) -> void:
	bench(seat, yaw)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	tf_viewpoints.append([seat + fwd * 1.1, yaw, seat, id])


# ---------------------------------------------------------------- outras nacoes
func _build_nation(n: Array) -> void:
	var id: String = n[0]
	var ang: float = n[1]
	var c := pol(ang, ZONE_R)
	var r: float = n[3]
	disc(n[2], c, r, 0.016, 0.1, 32)
	ground_discs.append([n[7], c, r])
	pois.append(["Area_" + id, c])
	var to_camp := -c.normalized()
	var side := Vector3(-to_camp.z, 0, to_camp.x)
	# Mestre perto da borda voltada para o acampamento, olhando para quem chega
	var mp := c + to_camp * (r * 0.45)
	npc_points.append([n[5], mp, _yaw_of(to_camp)])
	banner_pole(mp + side * 1.8 - to_camp * 0.8, n[4], 4.0, true)
	# 2 grupos de monstros nos flancos (reservados antes da vegetacao: keepout)
	var ms: Array = n[6]
	for k in 2:
		var sp := c + side * (r * 0.45) * (1.0 if k == 0 else -1.0) + to_camp * (r * 0.3)
		spawns.append(["%s_%s" % [id, ms[k]], sp, ms[k], 5, 4])
		spawns.append(["%s_%s_med" % [id, ms[k]], sp, ms[k], 1, 4, 2])
		keepout.append([sp, 4.5])
	keepout.append([mp, 3.0])
	# landmark e vegetacao da regiao, atras do Mestre (lado de fora)
	call("_landmark_" + id, c - to_camp * (r * 0.35), c, r, _yaw_of(to_camp))


func _scatter(c: Vector3, r0: float, r1: float, n: int, fn: Callable, clear_from: Vector3 = Vector3.INF, clear_r: float = 0.0) -> void:
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 30:
		tries += 1
		var p := c + pol(rng.randf() * 360.0, rng.randf_range(r0, r1))
		if Vector2(p.x, p.z).length() > FIELD_R - 1.5 or _in_obstruction(p, 1.6):
			continue
		if clear_from != Vector3.INF and p.distance_to(clear_from) < clear_r:
			continue
		var blocked := false
		for ko: Array in keepout:
			if p.distance_to(ko[0]) < (ko[1] as float):
				blocked = true
		if blocked:
			continue
		fn.call(p)
		placed += 1


## Marco da nação (modelo original do Blender, tools/art/blender/landmarks.py). yaw = convenção do mapa
## (frente do modelo, +Z, fica virada para o acampamento).
func lm_item(mesh: String, pos: Vector3, yaw: float) -> void:
	kit_items.append([mesh, Transform3D(Basis(Vector3.UP, yaw + PI), pos)])


func _landmark_portugal(lm: Vector3, c: Vector3, r: float, yaw: float) -> void:
	# torre de vigia caiada com faixa de azulejo e ameias + fonte das mouras
	lm_item("lm_portugal_tower", lm, yaw)
	lm_item("lm_portugal_fountain", c + (lm - c).rotated(Vector3.UP, 1.4) * 1.3, yaw)
	mute_geo = true
	cyl("wall_white", lm, lm + Vector3(0, 7.0, 0), 2.2, 10)
	cyl("azulejo", lm + Vector3(0, 4.6, 0), lm + Vector3(0, 5.3, 0), 2.25, 10)
	for i in 10:
		var a := TAU * i / 10
		box("stone", lm + Vector3(cos(a) * 2.0, 7.0, sin(a) * 2.0), Vector3(0.6, 0.7, 0.6), -a)
	obstruct_circle(lm, 2.4)
	var f := c + (lm - c).rotated(Vector3.UP, 1.4) * 1.3
	cyl("stone", f, f + Vector3(0, 0.6, 0), 1.6, 12)
	flat_disc("water", f, 1.35, 0.62)
	cyl("stone", f, f + Vector3(0, 1.6, 0), 0.25, 6)
	obstruct_circle(f, 1.8)
	mute_geo = false
	_scatter(c, r * 0.5, r * 0.95, 7, func(p: Vector3) -> void: round_tree(p, "olive", rng.randf_range(0.8, 1.1)), c, 6.0)


func _landmark_grecia(lm: Vector3, c: Vector3, r: float, yaw: float) -> void:
	# colunata branca sobre plataforma de pedra
	lm_item("lm_grecia_colonnade", lm, yaw)
	var gtr := Transform3D(Basis(Vector3.UP, yaw), lm)
	lm_item("lm_grecia_broken_column", gtr * Vector3(5.5, 0, 2.5), yaw + 0.7)
	lm_item("lm_grecia_broken_column", gtr * Vector3(-6.0, 0, -2.0), yaw - 1.1)
	mute_geo = true
	var tr := Transform3D(Basis(Vector3.UP, yaw), lm)
	box("stone_trim", lm, Vector3(9.0, 0.5, 4.2), yaw)
	for i in 5:
		for sz: float in [-1.5, 1.5]:
			var p := tr * Vector3(-3.6 + i * 1.8, 0.5, sz)
			cyl("stone_trim", p, p + Vector3(0, 4.2, 0), 0.32, 8)
	box("stone_trim", tr * Vector3(0, 4.7, 0), Vector3(8.4, 0.6, 3.8), yaw)
	obstruct_rect(lm, 9.4, 4.6, yaw)
	for p: Vector3 in [tr * Vector3(5.5, 0, 2.5), tr * Vector3(-6.0, 0, -2.0)]:
		cyl("stone_trim", p, p + Vector3(0, 1.4, 0), 0.32, 8) # colunas partidas
		obstruct_circle(p, 0.5)
	mute_geo = false
	_scatter(c, r * 0.5, r * 0.95, 7, func(p: Vector3) -> void: round_tree(p, "olive", rng.randf_range(0.8, 1.1)), c, 6.0)


func _landmark_egito(lm: Vector3, c: Vector3, r: float, yaw: float) -> void:
	# estatua de leao de pedra deitado, meio enterrado + casa de adobe + tamareiras
	lm_item("lm_egito_obelisks", lm, yaw + PI * 0.5)
	lm_item("lm_egito_adobe", c + (lm - c).rotated(Vector3.UP, -1.3) * 1.2, yaw)
	mute_geo = true
	var tr := Transform3D(Basis(Vector3.UP, yaw), lm)
	box("sandstone", tr * Vector3(0, 0, 0), Vector3(3.0, 1.2, 6.0), yaw)
	blob("sandstone", tr * Vector3(0, 1.6, -2.4), Vector3(1.3, 1.4, 1.1), 7, 4)
	blob("sandstone", tr * Vector3(0, 1.2, 0.6), Vector3(1.4, 0.9, 2.4), 7, 3)
	for sx: float in [-0.9, 0.9]:
		box("sandstone", tr * Vector3(sx, 0, -3.6), Vector3(0.7, 0.6, 1.8), yaw)
	obstruct_rect(lm, 3.4, 7.6, yaw)
	var h := c + (lm - c).rotated(Vector3.UP, -1.3) * 1.2
	box("mudbrick", h, Vector3(4.0, 2.4, 3.2), yaw)
	obstruct_rect(h, 4.4, 3.6, yaw)
	mute_geo = false
	_scatter(c, r * 0.5, r * 0.95, 6, func(p: Vector3) -> void: palm(p, rng.randf_range(0.8, 1.05), "palm", "palm_dark"), c, 6.0)


func _landmark_celta(lm: Vector3, c: Vector3, r: float, yaw: float) -> void:
	# torre redonda de pedra seca + casinha de sape + lago com urzes
	lm_item("lm_celta_tower", lm, yaw)
	lm_item("lm_celta_hut", Transform3D(Basis(Vector3.UP, yaw), lm) * Vector3(5.5, 0, 1.0), yaw)
	mute_geo = true
	var tr := Transform3D(Basis(Vector3.UP, yaw), lm)
	cyl("stone", lm, lm + Vector3(0, 6.0, 0), 2.6, 12)
	cyl("stone", lm + Vector3(0, 6.0, 0), lm + Vector3(0, 6.6, 0), 2.3, 12)
	obstruct_circle(lm, 2.8)
	hut(tr * Vector3(5.5, 0, 1.0), 3.8, 3.0, 2.0, yaw, "wall_white", "thatch", 1.7)
	var lake := c + (lm - c).rotated(Vector3.UP, -1.5) * 1.3
	disc("water", lake, 3.4, 0.045, 0.15, 20)
	obstruct_circle(lake, 3.6)
	mute_geo = false
	_scatter(c, r * 0.4, r * 0.95, 14, func(p: Vector3) -> void:
		# urzes: tufos de flores roxas do kit (antes "cristais" roxos low-poly)
		mute_geo = true
		blob("heather", p + Vector3(0, 0.25, 0), Vector3(0.5, 0.3, 0.5), 5, 2)
		mute_geo = false
		kit_items.append(["flowers_purple", Transform3D(Basis(Vector3.UP, p.x + p.z).scaled(Vector3.ONE * 1.6), p)])
		kit_items.append(["bush_olive_a", Transform3D(Basis(Vector3.UP, p.x).scaled(Vector3.ONE * 0.45), p + Vector3(0.4, 0, 0.3))]), c, 5.0)
	_scatter(c, r * 0.6, r * 0.95, 4, func(p: Vector3) -> void: round_tree(p, "leaves", rng.randf_range(0.9, 1.2)), c, 6.0)


func _landmark_nordico(lm: Vector3, c: Vector3, r: float, yaw: float) -> void:
	# casa longa de madeira com telhado de turfa + lago congelado + pinheiros com neve + pedras "troll"
	lm_item("lm_nordico_longhouse", lm, yaw)
	mute_geo = true
	box("wood", lm, Vector3(8.0, 2.2, 4.2), yaw)
	gable_roof("grass", "wood", lm + Vector3(0, 2.2, 0), 8.0, 4.2, 2.0, yaw, 0.5)
	obstruct_rect(lm, 8.4, 4.6, yaw)
	var pond := c + (lm - c).rotated(Vector3.UP, 1.5) * 1.2
	disc("ice", pond, 3.5, 0.045, 0.12, 20)
	obstruct_circle(pond, 3.7)
	for k in 3:
		rock(c + (lm - c).rotated(Vector3.UP, -1.2 - k * 0.3) * (1.1 + k * 0.15), 1.4 + k * 0.3)
	mute_geo = false
	_scatter(c, r * 0.5, r * 0.98, 9, func(p: Vector3) -> void: pine(p, rng.randf_range(0.9, 1.3), true), c, 6.0)


func _landmark_eslavo(lm: Vector3, c: Vector3, r: float, yaw: float) -> void:
	# cabana sobre pes de galinha (conto popular) + isba de madeira + betulas
	lm_item("lm_eslavo_hut_legs", lm, yaw)
	lm_item("lm_eslavo_izba", c + (lm - c).rotated(Vector3.UP, 1.3) * 1.2, yaw + 0.3)
	mute_geo = true
	var tr := Transform3D(Basis(Vector3.UP, yaw), lm)
	for sx: float in [-0.8, 0.8]:
		cyl("fruit_yellow", tr * Vector3(sx, 0, 0), tr * Vector3(sx * 0.6, 2.0, 0), 0.22, 5)
		for k in 3:
			var toe := tr * Vector3(sx + (k - 1) * 0.35, 0.05, 0.7)
			cyl("fruit_yellow", tr * Vector3(sx, 0.1, 0), toe, 0.08, 4)
	box("wood", tr * Vector3(0, 2.0, 0), Vector3(2.8, 2.0, 2.4), yaw)
	gable_roof("dark_roof", "wood", tr * Vector3(0, 4.0, 0), 2.8, 2.4, 1.3, yaw)
	obstruct_circle(lm, 1.8)
	var iz := c + (lm - c).rotated(Vector3.UP, 1.3) * 1.2
	hut(iz, 4.4, 3.4, 2.2, yaw + 0.3, "wood", "dark_roof", 1.8)
	mute_geo = false
	_scatter(c, r * 0.5, r * 0.98, 9, func(p: Vector3) -> void: round_tree(p, "birch_leaf", rng.randf_range(0.8, 1.1), "birch_bark"), c, 6.0)


func _landmark_china(lm: Vector3, c: Vector3, r: float, yaw: float) -> void:
	# muro com portal da lua (abertura redonda) + pavilhao + lanternas vermelhas + bambus
	lm_item("lm_china_moongate", lm, yaw)
	lm_item("lm_china_pavilion", c + (lm - c).rotated(Vector3.UP, 1.4) * 1.1, yaw)
	for k in 6:
		lm_item("lm_china_lantern", c + (lm - c).rotated(Vector3.UP, -0.9 + k * 0.36) * 0.75, yaw)
	mute_geo = true
	var tr := Transform3D(Basis(Vector3.UP, yaw), lm)
	var R := 1.8
	var segs := 16
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := Vector3(cos(a0) * R, 2.0 + sin(a0) * R, 0)
		var p1 := Vector3(cos(a1) * R, 2.0 + sin(a1) * R, 0)
		quad("wall_white", tr * (p0 + Vector3(0, 0, 0.31)), tr * (p1 + Vector3(0, 0, 0.31)), tr * (p1 * Vector3(1.4, 1, 1) + Vector3(0, 0, 0.31)), tr * (p0 * Vector3(1.4, 1, 1) + Vector3(0, 0, 0.31)))
	for sx: float in [-1.0, 1.0]:
		box("wall_white", tr * Vector3(sx * 4.1, 0, 0), Vector3(3.8, 4.2, 0.6), yaw)
		obstruct_rect(tr * Vector3(sx * 4.1, 0, 0), 3.8, 0.8, yaw)
	box("wall_white", tr * Vector3(0, 3.9, 0), Vector3(4.4, 0.4, 0.6), yaw)
	box("dark_roof", tr * Vector3(0, 4.2, 0), Vector3(12.4, 0.35, 1.2), yaw)
	var pv := c + (lm - c).rotated(Vector3.UP, 1.4) * 1.1
	for sx: float in [-1.6, 1.6]:
		for sz: float in [-1.6, 1.6]:
			cyl("frame_red", pv + Vector3(sx, 0, sz), pv + Vector3(sx, 2.6, sz), 0.15, 6)
			obstruct_circle(pv + Vector3(sx, 0, sz), 0.3)
	_cone_roof_mat("dark_roof", pv + Vector3(0, 2.6, 0), 3.2, 1.6, 4)
	for k in 6:
		var p := c + (lm - c).rotated(Vector3.UP, -0.9 + k * 0.36) * 0.75
		cyl("dark_wood", p, p + Vector3(0, 2.2, 0), 0.06, 4)
		blob("lantern_red", p + Vector3(0, 2.3, 0), Vector3(0.28, 0.35, 0.28), 6, 3)
		obstruct_circle(p, 0.25, 2.5)
	mute_geo = false
	_scatter(c, r * 0.6, r * 0.98, 10, func(p: Vector3) -> void:
		if _spr_ok("fld_bamboo_small"):
			for q in 3:
				sprites.append(["fld_bamboo_small", p + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)), rng.randf_range(1.6, 2.2)])
		obstruct_circle(p, 0.7), c, 6.0)


func _cone_roof_mat(mat: String, c: Vector3, r: float, h: float, sides: int) -> void:
	for i in sides:
		var a0 := TAU * i / sides + PI / sides
		var a1 := TAU * (i + 1) / sides + PI / sides
		tri(mat, c + Vector3(0, h, 0), c + Vector3(cos(a1) * r, 0, sin(a1) * r), c + Vector3(cos(a0) * r, 0, sin(a0) * r))


func _landmark_japao(lm: Vector3, c: Vector3, r: float, yaw: float) -> void:
	# lago com ponte arqueada vermelha + casa de madeira de telhado escuro + cerejeiras + bambus
	lm_item("lm_japao_bridge", lm, yaw + PI / 2)
	lm_item("lm_japao_house", c + (lm - c).rotated(Vector3.UP, 1.4) * 1.25, yaw)
	mute_geo = true
	var tr := Transform3D(Basis(Vector3.UP, yaw + PI / 2), lm)
	disc("water", lm, 4.2, 0.045, 0.08, 24)
	# ponte arqueada (so enfeite; o lago bloqueia)
	var prev := Vector3.ZERO
	for i in 9:
		var t := i / 8.0
		var p := tr * Vector3(-5.0 + t * 10.0, 0.2 + sin(t * PI) * 1.3, 0)
		if i > 0:
			box("frame_red", (prev + p) * 0.5, Vector3(1.4, 0.15, 1.8), yaw)
		prev = p
	obstruct_circle(lm, 4.4)
	var hs := c + (lm - c).rotated(Vector3.UP, 1.4) * 1.25
	hut(hs, 4.6, 3.4, 2.2, yaw, "wall_white", "dark_roof", 1.4)
	mute_geo = false
	_scatter(c, r * 0.5, r * 0.98, 8, func(p: Vector3) -> void: round_tree(p, "sakura", rng.randf_range(0.8, 1.1)), c, 6.0)


func _landmark_mexico(lm: Vector3, c: Vector3, r: float, yaw: float) -> void:
	# ruina de plataforma em degraus coberta de mata + pedras de obsidiana + cenote + arvores densas
	lm_item("lm_mexico_platform", lm, yaw)
	mute_geo = true
	for k in 4:
		var s := 9.0 - k * 2.0
		box("stone", lm + Vector3(0, k * 1.0, 0), Vector3(s, 1.0, s), yaw)
		for i in 3:
			blob("leaves", lm + pol(rng.randf() * 360.0, s * 0.45) + Vector3(0, k + 1.0, 0), Vector3(0.6, 0.35, 0.6), 5, 2)
	obstruct_rect(lm, 9.4, 9.4, yaw)
	var ce := c + (lm - c).rotated(Vector3.UP, -1.4) * 1.2
	disc("water", ce, 2.8, 0.045, 0.05, 20)
	cyl("stone", ce + Vector3(0, -0.2, 0), ce + Vector3(0, 0.3, 0), 3.0, 14, false)
	obstruct_circle(ce, 3.2)
	for k in 4:
		var p := c + (lm - c).rotated(Vector3.UP, 1.0 + k * 0.25) * 1.05
		box("obsidian", p, Vector3(0.7, rng.randf_range(0.8, 1.8), 0.6), rng.randf() * PI)
		obstruct_circle(p, 0.6)
		kit_items.append(["rock_grey_a", Transform3D(Basis(Vector3.UP, p.x * 3.0).scaled(Vector3.ONE * 0.9), p)])
	for k in 10:
		var rp := ce + Vector3(cos(k * TAU / 10.0), 0, sin(k * TAU / 10.0)) * 3.1
		kit_items.append(["rock_moss_b", Transform3D(Basis(Vector3.UP, k * 1.3).scaled(Vector3.ONE * 1.1), rp)])
	mute_geo = false
	_scatter(c, r * 0.55, r * 0.98, 9, func(p: Vector3) -> void: round_tree(p, "jungle_leaf", rng.randf_range(1.1, 1.5)), c, 6.0)


# ---------------------------------------------------------------- vegetacao em sprite
## Espalha n sprites de enfeite (so visual; os maiores bloqueiam um circulo pequeno).
func sprinkle(tex: String, c: Vector3, r0: float, r1: float, n: int, s0: float = 0.85, s1: float = 1.15, block: float = 0.0) -> void:
	var tries := 0
	var placed := 0
	while placed < n and tries < n * 12:
		tries += 1
		var p := c + pol(deco_rng.randf() * 360.0, sqrt(deco_rng.randf_range(r0 * r0 / (r1 * r1), 1.0)) * r1)
		if Vector2(p.x, p.z).length() > FIELD_R + 6.0 or _in_obstruction(p, 0.5):
			continue
		if stream_pts.size() > 0 and _near_stream(p, 2.8) and tex != "fld_reeds":
			continue
		if _on_trail(p):
			continue
		sprites.append([tex, p, deco_rng.randf_range(s0, s1)])
		if block > 0.0:
			obstruct_circle(p, block, 1.5)
		placed += 1


var trails: Array = [] # [a, b, meia largura]


func _in_keepout(p: Vector3) -> bool:
	for ko: Array in keepout:
		if p.distance_to(ko[0]) < (ko[1] as float):
			return true
	return false


func _on_trail(p: Vector3) -> bool:
	for t: Array in trails:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
		if q.distance_to(Vector2(p.x, p.z)) < (t[2] as float) + 0.4:
			return true
	return false


func _build_sprinkles() -> void:
	# entre as zonas: capim verde, florzinhas e moitas
	sprinkle("fld_grass_tuft", Vector3.ZERO, CAMP_R + 1.0, FIELD_R, 260)
	sprinkle("fld_white_flowers", Vector3.ZERO, CAMP_R + 3.0, FIELD_R, 90)
	sprinkle("fld_round_bush", Vector3.ZERO, CAMP_R + 4.0, FIELD_R + 4.0, 40, 0.9, 1.3, 0.4)
	# Terra de Pindorama: capim dourado, flores do cerrado, arbustos tortos, juncos no riacho
	sprinkle("fld_golden_grass", PINDORAMA_C, 0.0, 36.0, 320)
	sprinkle("fld_cerrado_flowers", PINDORAMA_C, 0.0, 36.0, 90)
	sprinkle("fld_cerrado_shrub", PINDORAMA_C, 4.0, 38.0, 30, 0.9, 1.3, 0.35)
	for i in stream_pts.size() - 1:
		if i == 3:
			continue # trecho da ponte
		for k in 6:
			var p: Vector3 = (stream_pts[i] as Vector3).lerp(stream_pts[i + 1], deco_rng.randf())
			p += Vector3(deco_rng.randf_range(-0.6, 0.6), 0, (1.0 if k % 2 == 0 else -1.0) * deco_rng.randf_range(1.6, 2.4))
			if not _in_obstruction(p, 0.2) or true:
				sprites.append(["fld_reeds", p, deco_rng.randf_range(0.8, 1.1)])
	var sets := {
		"portugal": [["fld_rosemary", 26], ["fld_lavender", 12]], "grecia": [["fld_lavender", 24], ["fld_dry_bush", 10]],
		"egito": [["fld_dry_bush", 22]], "celta": [["fld_heather", 40], ["fld_white_flowers", 20]],
		"nordico": [["fld_snow_shrub", 24]], "eslavo": [["fld_mushrooms", 22], ["fld_white_flowers", 24]],
		"china": [["fld_bamboo_small", 14], ["fld_grass_tuft", 20]], "japao": [["fld_bamboo_small", 10], ["fld_grass_tuft", 30]],
		"mexico": [["fld_fern", 30], ["fld_big_leaf", 16]],
	}
	for n: Array in NATIONS:
		var c := pol(n[1], ZONE_R)
		for e: Array in sets[n[0]]:
			sprinkle(e[0], c, 3.0, n[3] + 1.0, e[1])


# ---------------------------------------------------------------- borda
func _build_border() -> void:
	# anel de mata e morros fora do disco util (nao caminhavel)
	for i in 70:
		var a := rng.randf() * 360.0
		var p := pol(a, rng.randf_range(FIELD_R + 2.0, FIELD_R + 14.0))
		var leaf := "leaves"
		if a > 255.0 and a < 285.0:
			pine(p, rng.randf_range(1.2, 1.8), true)
			continue
		if a > 50.0 and a < 130.0:
			leaf = ["leaves", "ipe_yellow", "leaves", "ipe_purple"][i % 4]
		round_tree(p, leaf, rng.randf_range(1.2, 1.9))
	for h: Array in [[pol(0, 150), Vector3(50, 24, 60)], [pol(60, 155), Vector3(55, 20, 50)], [pol(120, 150), Vector3(60, 26, 50)],
			[pol(180, 150), Vector3(50, 22, 60)], [pol(240, 150), Vector3(55, 28, 50)], [pol(300, 155), Vector3(60, 30, 55)]]:
		blob("hill", h[0] + Vector3(0, -6, 0), h[1], 10, 5)


# ---------------------------------------------------------------- relevo orgânico (revisão 5)
## Cristas de rocha e mata entre as zonas (fronteiras naturais), morros na borda, rio com margens e fundo, lagoas
## novas (oásis no Egito, lago do pavilhão na China). Tudo que sobe ou desce vira obstrução: onde se anda é plano.
func _build_relief() -> void:
	var sp2 := PackedVector2Array()
	for p: Vector3 in stream_pts:
		sp2.append(Vector2(p.x, p.z))
	relief.stream = sp2
	# ponte (segmento 3) e vau (segmento 5): só o corredor do tabuleiro/das pedras continua andável
	for spec: Array in [[3, 1.4, false], [5, 2.6, true]]:
		var a: Vector3 = stream_pts[spec[0]]
		var b: Vector3 = stream_pts[spec[0] + 1]
		var m := (a + b) * 0.5
		var dir := (b - a).normalized()
		var gap: float = spec[1]
		var yaw := atan2(-(b - a).z, (b - a).x)
		for part: Array in [[a, m - dir * gap], [m + dir * gap, b]]:
			var p0: Vector3 = part[0]
			var p1: Vector3 = part[1]
			obstruct_rect((p0 + p1) * 0.5, p0.distance_to(p1), 3.2, yaw)
		if spec[2]:
			relief.stream_dry.append([Vector2(m.x, m.z), gap + 0.6])
			relief.shapes.append(["sand", Vector2(m.x, m.z), gap + 1.2, 0.15])
	# cristas nas fronteiras entre nações vizinhas (e duas nas pontas da Terra de Pindorama, mais longe)
	var angs: Array = []
	for n: Array in NATIONS:
		angs.append(float(n[1]))
	angs.sort()
	var bounds: Array = []
	for i in angs.size():
		var a0: float = angs[i]
		var a1: float = angs[(i + 1) % angs.size()] + (360.0 if i == angs.size() - 1 else 0.0)
		if a1 - a0 > 60.0:
			continue # a Terra de Pindorama fica entre México e Portugal
		bounds.append([fmod((a0 + a1) * 0.5, 360.0), 50.0])
	bounds.append([58.0, 80.0])
	bounds.append([122.0, 80.0])
	var k := 0
	for bd: Array in bounds:
		var pts := PackedVector2Array()
		var r: float = bd[1]
		while r <= FIELD_R + 16.0:
			var a: float = float(bd[0]) + 1.2 * sin(r * 0.11 + k)
			var p := pol(a, r)
			pts.append(Vector2(p.x, p.z))
			r += 7.0
		relief.add_ridge(pts, rng.randf_range(3.0, 4.2), 4.2)
		for i in pts.size() - 1:
			var p0 := Vector3(pts[i].x, 0, pts[i].y)
			var p1 := Vector3(pts[i + 1].x, 0, pts[i + 1].y)
			obstruct_rect((p0 + p1) * 0.5, p0.distance_to(p1) + 4.2, 8.4, atan2(-(p1 - p0).z, (p1 - p0).x), 5.0)
		# rochas e mata em cima da crista (alturas acertadas no fim pelo relevo)
		var biome := _biome_at(float(bd[0]))
		for i in pts.size() - 1:
			for q in 3:
				var t := (q + rng.randf()) / 3.0
				var c := pts[i].lerp(pts[i + 1], t)
				var side := (pts[i + 1] - pts[i]).orthogonal().normalized() * rng.randf_range(-1.6, 1.6)
				var pos := Vector3(c.x + side.x, 0, c.y + side.y)
				if rng.randf() < 0.5:
					kit_items.append(["rock_moss_c" if rng.randf() < 0.5 else "rock_moss_a", Transform3D(Basis(Vector3.UP,
							rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.6)), pos)])
				else:
					kit_items.append([biome, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE *
							rng.randf_range(0.8, 1.15)), pos)])
		k += 1
	# zonas com contorno lobado (manchas satélites do mesmo chão) em vez de "disco"
	var extra: Array = []
	for sh: Array in relief.shapes:
		var rr: float = sh[2]
		if rr >= 14.0:
			for q in 4:
				var ang := rng.randf() * TAU
				var off := Vector2.from_angle(ang) * rr * rng.randf_range(0.45, 0.7)
				extra.append([sh[0], (sh[1] as Vector2) + off, rr * rng.randf_range(0.35, 0.5), 0.2])
			sh[3] = 0.22
	relief.shapes.append_array(extra)
	# campo entre as zonas: manchas de prado viçoso, capim seco e urze (quebra o "gramado liso")
	for q in 60:
		var p := pol(rng.randf() * 360.0, rng.randf_range(18.0, FIELD_R + 20.0))
		relief.shapes.append([["lush_grass", "dry_meadow", "heather", "lush_grass", "birch_meadow"][q % 5],
				Vector2(p.x, p.z), rng.randf_range(4.0, 9.0), 0.25])
	# lagoas novas das vinhetas
	for spec: Array in [["egito", Vector2(-8.5, 6.5), 3.2], ["china", Vector2(-9.0, 5.0), 3.4]]:
		var c := _zone_local(spec[0], spec[1])
		relief.ponds.append([Vector2(c.x, c.z), spec[2], 1.0, "water"])
		obstruct_circle(c, float(spec[2]) + 0.3)
	print("relevo: %d cristas, %d lagoas, %d manchas, %d faixas" % [relief.ridges.size(), relief.ponds.size(),
			relief.shapes.size(), relief.strips.size()])


## Árvore típica da crista conforme o ângulo (bioma das nações vizinhas).
func _biome_at(ang: float) -> String:
	ang = fmod(ang + 360.0, 360.0)
	if ang > 250.0 and ang < 295.0:
		return "tree_conifer_snow_a"
	if ang > 295.0 and ang < 320.0:
		return "tree_birch_a"
	if ang > 180.0 and ang < 230.0:
		return "palm_date_a"
	if ang < 60.0 or ang > 340.0:
		return "tree_jungle_a" if ang < 60.0 and ang > 15.0 else "tree_sakura_a"
	if ang > 60.0 and ang < 130.0:
		return "tree_ipe_yellow_a"
	return "tree_olive_a" if ang < 200.0 else "tree_conifer_a"


## Ponto no referencial local de uma zona: x = lado (u), y = para fora do acampamento (v).
func _zone_local(id: String, uv: Vector2) -> Vector3:
	for n: Array in NATIONS:
		if n[0] == id:
			var c := pol(n[1], ZONE_R)
			var out := c.normalized()
			var side := Vector3(-out.z, 0, out.x)
			return c + side * uv.x + out * uv.y
	return Vector3.ZERO


## Ambiente do campo (direção de arte da tela de título): céu pintado com nuvens, névoa de altura que assenta
## nos vales, oclusão ambiente mais forte nos cantos, brilho suave.
func _field_environment() -> Environment:
	var env: Environment = (load(KIT + "env_warm_day.tres") as Environment).duplicate(true)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://assets/shaders/env_sky_painted.gdshader")
	sm.set_shader_parameter(&"top_color", Color(0.32, 0.5, 0.78))
	sm.set_shader_parameter(&"mid_color", Color(0.62, 0.74, 0.88))
	sm.set_shader_parameter(&"horizon_color", Color(0.98, 0.86, 0.66))
	sm.set_shader_parameter(&"ground_color", Color(0.5, 0.52, 0.38))
	sm.set_shader_parameter(&"cloud_light", Color(1.0, 0.95, 0.86))
	sm.set_shader_parameter(&"cloud_shade", Color(0.62, 0.66, 0.8))
	sm.set_shader_parameter(&"cloud_cover", 0.45)
	sm.set_shader_parameter(&"cloud_speed", 0.004)
	var sky := Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_sky_contribution = 0.5
	env.ssao_intensity = 1.3
	env.ssao_radius = 1.2
	env.ssao_power = 1.2
	env.fog_height = 0.5
	env.fog_height_density = 0.025
	env.fog_light_color = Color(0.83, 0.9, 0.86)
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 110.0
	env.glow_intensity = 0.22
	env.ambient_light_color = Color(0.72, 0.8, 0.79)
	env.ambient_light_energy = 0.64
	env.ssao_intensity = 1.6
	env.ssao_power = 1.35
	env.adjustment_contrast = 1.10
	env.adjustment_brightness = 1.0
	var path := "%s/env_field.tres" % TF_GEO
	ResourceSaver.save(env, path)
	return load(path)


## Terreno único (malha interna fina + anel externo grosso), água única com margem pela profundidade, gelo.
func _organic_terrain(parent: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var imgs: Array[Image] = relief.paint(TERRAIN_INNER, 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/env_terrain_world.gdshader")
	var P := KIT + "textures/"
	for kv: Array in [["tex_grass", "tex_grass"], ["tex_lush", "tex_grass_lush"], ["tex_dirt", "tex_dirt"],
			["tex_paving", "tex_paving"], ["tex_sand", "tex_sand"], ["tex_rock", "tex_rock"], ["tex_snow", "tex_snow"],
			["tex_dry", "tex_dry_grass"], ["tex_jungle", "tex_jungle_floor"], ["tex_gravel", "tex_gravel"],
			["tex_red", "tex_red_earth"]]:
		mat.set_shader_parameter(StringName(kv[0]), load(P + kv[1] + ".png"))
	mat.set_shader_parameter(&"tex_noise", load(KIT + "materials/tex_env_noise.tres"))
	for i in 3:
		var path := "%s/splat_%d.png" % [TF_GEO, i]
		imgs[i].save_png(ProjectSettings.globalize_path(path))
		var tex := ImageTexture.create_from_image(imgs[i])
		ResourceSaver.save(tex, "%s/splat_%d.res" % [TF_GEO, i], ResourceSaver.FLAG_COMPRESS)
		mat.set_shader_parameter(StringName("splat_" + "abc"[i]), load("%s/splat_%d.res" % [TF_GEO, i]))
	mat.set_shader_parameter(&"splat_origin", TERRAIN_INNER.position)
	mat.set_shader_parameter(&"splat_size", TERRAIN_INNER.size)
	mat.set_shader_parameter(&"tile_m", 6.0)
	mat.set_shader_parameter(&"blend_softness", 0.2)
	mat.set_shader_parameter(&"edge_noise", 0.28)
	mat.set_shader_parameter(&"macro_warm", Color(1.08, 1.0, 0.78))
	mat.set_shader_parameter(&"macro_cool", Color(0.78, 0.9, 0.8))
	mat.set_shader_parameter(&"macro_strength", 0.22)
	mat.set_shader_parameter(&"brush_strength", 0.075)
	mat.set_shader_parameter(&"slope_rock_start", 0.86)
	mat.set_shader_parameter(&"slope_rock_end", 0.66)
	mat.set_shader_parameter(&"heather_tint", Color(0.86, 0.78, 0.95))
	mat.set_shader_parameter(&"wet_depth", 0.6)
	mat.set_shader_parameter(&"camp_surface_strength", 0.85)
	ResourceSaver.save(mat, "%s/terrain_mat.tres" % TF_GEO)
	mat = load("%s/terrain_mat.tres" % TF_GEO)
	var inner: ArrayMesh = relief.build_mesh(TERRAIN_INNER, 1.0)
	ResourceSaver.save(inner, "%s/terrain_inner.res" % TF_GEO, ResourceSaver.FLAG_COMPRESS)
	var outer: ArrayMesh = _outer_ring_mesh()
	ResourceSaver.save(outer, "%s/terrain_outer.res" % TF_GEO, ResourceSaver.FLAG_COMPRESS)
	var node := Node3D.new()
	node.name = "Terrain"
	_add(parent, node)
	for spec: Array in [["TerrainInner", "terrain_inner"], ["TerrainOuter", "terrain_outer"]]:
		var mi := MeshInstance3D.new()
		mi.name = spec[0]
		mi.mesh = load("%s/%s.res" % [TF_GEO, spec[1]])
		mi.material_override = mat
		# o chão recebe sombra mas não projeta (poupa o passe de sombra; as cristas têm rochas/árvores que projetam)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(node, mi)
	# água única: aparece só onde o relevo desce (rio, lagoas); margem suave pela profundidade
	var wm := MeshInstance3D.new()
	wm.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = TERRAIN_INNER.size
	var wmat: ShaderMaterial = (load(KIT + "materials/mat_water.tres") as ShaderMaterial).duplicate()
	wmat.set_shader_parameter(&"use_depth_edge", true)
	pm.material = wmat
	wm.mesh = pm
	wm.position = Vector3(TERRAIN_INNER.get_center().x, -0.3, TERRAIN_INNER.get_center().y)
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(node, wm)
	# gelo: disco abaixo do chão; a borda some sob o terreno (contorno orgânico vem do relevo)
	for pd: Array in relief.ponds:
		if pd.size() > 3 and pd[3] == "ice":
			var im := MeshInstance3D.new()
			im.name = "Ice"
			var cm := CylinderMesh.new()
			cm.top_radius = float(pd[1]) * 1.2
			cm.bottom_radius = float(pd[1]) * 1.2
			cm.height = 0.05
			cm.radial_segments = 32
			cm.material = mats["ice"]
			im.mesh = cm
			im.position = Vector3((pd[0] as Vector2).x, -0.2, (pd[0] as Vector2).y)
			_add(node, im)
	print("terreno orgânico em %d ms" % (Time.get_ticks_msec() - t0))


## Anel externo grosso (passo 4 m) até 210 m: sob a malha interna ele fica 2 m abaixo (não aparece).
func _outer_ring_mesh() -> ArrayMesh:
	var area := TERRAIN_OUTER
	var step := 4.0
	var nx := int(area.size.x / step) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hf := func(x: float, z: float) -> float:
		var r := Vector2(x, z).length()
		var inside := 1.0 - smoothstep(104.0, 109.0, maxf(absf(x), absf(z)))
		return relief.height(x, z) - 2.0 * inside if r > 60.0 else -2.0
	for iz in nx:
		for ix in nx:
			var x := area.position.x + ix * step
			var z := area.position.y + iz * step
			var h: float = hf.call(x, z)
			var dx: float = float(hf.call(x + step, z)) - float(hf.call(x - step, z))
			var dz: float = float(hf.call(x, z + step)) - float(hf.call(x, z - step))
			st.set_normal(Vector3(-dx, 4.0 * step, -dz).normalized())
			st.set_uv(Vector2(ix, iz))
			st.add_vertex(Vector3(x, h, z))
	for iz in nx - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + nx)
			st.add_index(a + 1)
			st.add_index(a + nx + 1)
			st.add_index(a + nx)
	return st.commit()


# ---------------------------------------------------------------- montagem
func _assemble_field() -> Node3D:
	var root := Node3D.new()
	root.name = "TrainingField"
	root.set_script(load(MAP_SCRIPT))
	root.set(&"map_id", &"training_field")
	root.set(&"nav_cell_size", NAV_CELL)
	root.set(&"nav_cell_height", NAV_CELL)

	var lighting := Node3D.new()
	lighting.name = "Lighting"
	_add(root, lighting)
	# luz e pos do kit pintado (GDD §17.0.A)
	var sun := EnvLook.make_sun(-38.0, -40.0)
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.2
	sun.directional_shadow_max_distance = 70.0
	_add(lighting, sun)
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = _field_environment()
	_add(lighting, we)
	for p: Array in [["CampFireLight", Vector3(0, 1.6, -1.5), 8.0], ["RanchoFireLight", RANCHO + Vector3(-1.0, 1.4, 3.0), 6.0]]:
		var ol := OmniLight3D.new()
		ol.name = p[0]
		ol.light_color = Color8(255, 160, 90)
		ol.light_energy = 2.6
		ol.set_script(load("res://scripts/client/env/flicker_light.gd"))
		ol.omni_range = p[2]
		ol.position = p[1]
		_add(lighting, ol)
	var pl := OmniLight3D.new()
	pl.name = "PortalLight"
	pl.light_color = Color8(168, 212, 245)
	pl.light_energy = 1.5
	pl.omni_range = 7.0
	pl.position = PORTAL_POS + Vector3(0, 2.2, 0)
	_add(lighting, pl)
	# Decor/: TODO o visual (geometria agrupada por material, sprites de vegetacao, particulas), separado dos nos de
	# jogo. O kit de ambiente pintado (agente V) pode trocar Decor/ inteiro; o layout esta em training_field_layout.json.
	var decor := Node3D.new()
	decor.name = "Decor"
	_add(root, decor)
	_add_field_particles(decor)
	_add_camp_flames(decor)

	var geo := Node3D.new()
	geo.name = "Geometry"
	_add(decor, geo)
	var names: Array = tools.keys()
	names.sort()
	for mat_name: String in names:
		var st: SurfaceTool = tools[mat_name]
		st.set_material(mats[mat_name])
		st.index()
		var mesh := st.commit()
		var path := "%s/geo_%s.res" % [TF_GEO, mat_name]
		ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		mesh.take_over_path(path)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + mat_name
		mi.mesh = mesh
		if mat_name in ["water", "sand", "cobble", "grass", "lush_grass", "cerrado", "red_earth", "dirt", "snow", "ice", "desert_sand",
				"moss_gravel", "jungle_floor", "dry_meadow", "birch_meadow", "stone_paving", "blob_shadow", "portal", "fire"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(geo, mi)
	_sprite_layer(decor)
	_organic_terrain(decor)
	_add_banners(decor)
	_write_layout()

	# colisao do chao (camada 1): caixa base de grama + discos das regioes 5 mm acima (o clique acerta o de cima)
	var ground := Node3D.new()
	ground.name = "Ground"
	_add(root, ground)
	var bodies := {}
	var gi := 0
	var base_shapes := [["grass", Vector3(0, -0.5, 0), Vector3(FIELD_R * 2 + 8, 1.0, FIELD_R * 2 + 8)]]
	for sh: Array in base_shapes:
		gi = _ground_shape(ground, bodies, sh[0], sh[1], null, gi, sh[2])
	for d: Array in ground_discs + [["sand", Vector3.ZERO, CAMP_R]]:
		gi = _ground_shape(ground, bodies, d[0], (d[1] as Vector3) + Vector3(0, -0.495, 0), d[2], gi)

	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	region.navigation_mesh = _bake_navmesh()
	_add(root, region)

	var spawn := Marker3D.new()
	spawn.name = "SpawnPoint"
	spawn.position = Vector3(0, 0, 4.0)
	spawn.rotation.y = PI # olhando para o sul (Terra de Pindorama)
	_add(root, spawn)
	var respawn := Marker3D.new()
	respawn.name = "CampRespawn" # ZoneDef.respawn_marker: renasce no acampamento, sem Marca da Alma
	respawn.position = Vector3(-2.5, 0, 3.0)
	_add(root, respawn)
	var vi := 1
	for v: Array in tf_viewpoints:
		var m := Marker3D.new()
		m.name = "Viewpoint%d" % vi
		m.position = v[0]
		m.rotation.y = v[1]
		_add(root, m)
		vi += 1
	var poi := Node3D.new()
	poi.name = "PointsOfInterest"
	_add(root, poi)
	for p: Array in pois:
		var m := Marker3D.new()
		m.name = p[0]
		m.position = p[1]
		_add(poi, m)
	var pts := Node3D.new()
	pts.name = "NpcPoints"
	_add(root, pts)
	for e: Array in npc_points:
		var m := Marker3D.new()
		m.name = e[0]
		m.position = e[1]
		m.rotation.y = e[2]
		m.set_meta(&"facing_yaw", e[2])
		m.set_meta(&"minimap_icon", &"master")
		_add(pts, m)
	var sp := Node3D.new()
	sp.name = "Spawns"
	_add(root, sp)
	for s: Array in spawns:
		var m := Marker3D.new()
		m.name = s[0]
		m.position = s[1]
		m.set_meta(&"monster_id", StringName(s[2]))
		m.set_meta(&"count", int(s[3]))
		m.set_meta(&"radius_cells", int(s[4]))
		if s.size() > 5:
			m.set_meta(&"stage", int(s[5]))
		_add(sp, m)
	_add_field_interactables(root)
	_add_field_audio_zones(root)
	return root


## Layout do mapa em dados (para re-vestir o mapa com outro kit visual sem mexer na jogabilidade).
func _write_layout() -> void:
	var v := func(p: Vector3) -> Array: return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]
	var zones := [{"id": "brasil", "center": v.call(PINDORAMA_C), "radius": 36.0, "ground": "cerrado"}, {"id": "camp", "center": [0, 0, 0], "radius": CAMP_R, "ground": "dirt"}]
	for n: Array in NATIONS:
		zones.append({"id": n[0], "angle_deg": n[1], "center": v.call(pol(n[1], ZONE_R)), "radius": n[3], "ground": n[2], "surface": n[7]})
	var tr := []
	for t: Array in trails:
		tr.append({"a": v.call(t[0]), "b": v.call(t[1]), "half_width": t[2]})
	var st := []
	for p: Vector3 in stream_pts:
		st.append(v.call(p))
	var spr := {}
	for s: Array in sprites:
		if not spr.has(s[0]):
			spr[s[0]] = []
		spr[s[0]].append(v.call(s[1]) + [snappedf(s[2], 0.01)])
	var pp := {}
	for p: Array in pois:
		pp[p[0]] = v.call(p[1])
	var out := {"_doc": "Gerado por tools/art/build_training_field.gd. Eixos: X leste, Z sul. Area andavel = disco de raio field_radius menos obstrucoes (ver navmesh). sprites: tipo -> [x, y, z, escala].",
		"field_radius": FIELD_R, "zones": zones, "trails": tr, "stream": {"points": st, "water_width": 3.0, "bank_width": 5.2, "bridge_segment": 3, "ford_segment": 5},
		"rancho": v.call(RANCHO), "portal": v.call(PORTAL_POS), "points_of_interest": pp, "sprites": spr}
	var f := FileAccess.open("res://tools/art/training_field_layout.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()


func _ground_shape(ground: Node3D, bodies: Dictionary, surf: String, pos: Vector3, radius: Variant, gi: int, size: Vector3 = Vector3.ZERO) -> int:
	if not bodies.has(surf):
		var body := StaticBody3D.new()
		body.name = "Ground" + surf.capitalize()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta(&"surface", StringName(surf))
		_add(ground, body)
		bodies[surf] = body
	var cs := CollisionShape3D.new()
	cs.name = "Shape%d" % gi
	if radius == null:
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
	else:
		var cy := CylinderShape3D.new()
		cy.radius = radius
		cy.height = 1.0
		cs.shape = cy
	cs.position = pos
	_add(bodies[surf], cs)
	return gi + 1


func _add_field_interactables(root: Node3D) -> void:
	var inter := Node3D.new()
	inter.name = "Interactables"
	_add(root, inter)
	for v: Array in tf_viewpoints:
		var a := _click_area(inter, v[3], (v[2] as Vector3) + Vector3(0, 0.5, 0), Vector3(2.3, 1.2, 0.9), v[1])
		a.set_meta(&"interact_type", &"sit")
		a.set_meta(&"facing_yaw", v[1])
		a.set_meta(&"seat_position", v[2])
		a.set_meta(&"approach_position", v[0])
	var altar_pos := Vector3(2.5, 0.45, -3.2)
	var altar := _click_area(inter, "altar_crendice", altar_pos, Vector3(2.0, 1.5, 2.0), 0.0)
	altar.set_meta(&"interact_type", &"altar_crendice")
	altar.set_meta(&"minimap_icon", &"altar")
	altar.set_meta(&"approach_position", altar_pos + Vector3(0, 0, 1.2))

	var yaw := atan2(PORTAL_POS.x, PORTAL_POS.z)

	var p := _click_area(inter, "training_exit", PORTAL_POS + Vector3(0, 2.1, 0), Vector3(3.2, 4.2, 1.4), yaw)
	p.set_meta(&"interact_type", &"portal")
	p.set_meta(&"target_map", &"city_awakening") # N troca pelo start_map_id do titulo
	p.set_meta(&"training_exit", true)
	p.set_meta(&"recommended_level", "")
	p.set_meta(&"minimap_icon", &"portal")
	p.set_meta(&"approach_position", PORTAL_POS - PORTAL_POS.normalized() * 1.6)


func _add_field_audio_zones(root: Node3D) -> void:
	var az := Node3D.new()
	az.name = "AudioZones"
	_add(root, az)
	var zones := [["default", Vector3(0, 5, 0), Vector3(400, 40, 400), "ZONE_TRAINING_FIELD_NAME"],
		["camp", Vector3.ZERO + Vector3(0, 5, 0), Vector3(CAMP_R * 2, 40, CAMP_R * 2), "AREA_CAMP_NAME"],
		["brasil", PINDORAMA_C + Vector3(0, 5, 0), Vector3(72, 40, 72), "REGION_BRASIL_NAME"]]
	for n: Array in NATIONS:
		zones.append([n[0], pol(n[1], ZONE_R) + Vector3(0, 5, 0), Vector3(n[3] * 2.2, 40, n[3] * 2.2), "REGION_%s_NAME" % String(n[0]).to_upper()])
	for z: Array in zones:
		var a := Area3D.new()
		a.name = z[0]
		a.position = z[1]
		a.collision_layer = 0
		a.collision_mask = 0
		a.input_ray_pickable = false
		a.set_meta(&"zone_id", StringName(z[0]))
		a.set_meta(&"audio_zone_def", StringName("training_field_" + z[0]))
		a.set_meta(&"name_key", z[3])
		_add(az, a)
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var bs := BoxShape3D.new()
		bs.size = z[2]
		cs.shape = bs
		_add(a, cs)


## Particulas leves: petalas de ipe no rancho, vaga-lumes no riacho, fumaca da fogueira.
func _add_field_particles(parent: Node3D) -> void:
	var specs := [
		["IpePetals", RANCHO + Vector3(0, 6, 8), Vector3(18, 1, 14), 70, Color8(250, 229, 140), Vector3(0.2, -0.6, 0.1), 0.1],
		["CampPetals", Vector3(0, 7, 0), Vector3(16, 1, 16), 18, Color8(245, 232, 181), Vector3(0.25, -0.5, 0.1), 0.09],
		["FireflyGlow", Vector3(0, 1.2, 58), Vector3(40, 0.8, 5), 60, Color8(250, 229, 140), Vector3(0, 0.02, 0), 0.07],
		["CampSparks", Vector3(0, 1.0, -1.5), Vector3(0.4, 0.2, 0.4), 18, Color8(245, 154, 106), Vector3(0, 0.6, 0), 0.06],
		["SnowFlakes", pol(270.0, ZONE_R) + Vector3(0, 8, 0), Vector3(16, 1, 16), 90, Color8(252, 250, 245), Vector3(0.1, -0.8, 0), 0.07],
	]
	for s: Array in specs:
		var gp := GPUParticles3D.new()
		gp.name = s[0]
		gp.amount = s[3]
		gp.lifetime = 8.0
		gp.preprocess = 8.0
		gp.position = s[1]
		gp.visibility_aabb = AABB(-(s[2] as Vector3) - Vector3(2, 10, 2), (s[2] as Vector3) * 2 + Vector3(4, 14, 4))
		var ppm := ParticleProcessMaterial.new()
		ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		ppm.emission_box_extents = s[2]
		ppm.gravity = s[5]
		ppm.initial_velocity_min = 0.05
		ppm.initial_velocity_max = 0.3
		ppm.spread = 180.0
		ppm.turbulence_enabled = true
		ppm.turbulence_noise_strength = 0.5
		ppm.turbulence_noise_scale = 3.0
		gp.process_material = ppm
		var q := QuadMesh.new()
		q.size = Vector2(s[6], s[6])
		var m := StandardMaterial3D.new()
		m.albedo_color = s[4]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		if s[0] == "FireflyGlow" or s[0] == "CampSparks":
			m.emission_enabled = true
			m.emission = s[4]
			m.emission_energy_multiplier = 2.0
		q.material = m
		gp.draw_pass_1 = q
		_add(parent, gp)


## Antigos sprites de vegetacao (assets/environment/field/fld_*.png) -> malhas do kit pintado: [malha, escala].
## As posicoes/escala/obstrucoes vem do layout (sprites[]); a escala do sprite e convertida pelo fator.
const SPRITE_KIT := {
	"fld_ipe_yellow": ["tree_ipe_yellow_a", 0.9], "fld_ipe_purple": ["tree_ipe_purple_a", 0.9],
	"fld_leafy_tree": ["tree_broadleaf_a", 0.85], "fld_olive_tree": ["tree_olive_a", 0.7], "fld_sakura": ["tree_sakura_a", 0.72],
	"fld_birch": ["tree_birch_a", 0.85], "fld_jungle_tree": ["tree_jungle_a", 1.0], "fld_pequi_tree": ["tree_pequi_a", 0.8],
	"fld_pine_snow": ["tree_conifer_snow_a", 0.85], "fld_date_palm": ["palm_date_a", 0.9], "fld_buriti": ["palm_buriti_a", 0.9],
	"fld_termite_mound": ["termite_mound_a", 0.9], "fld_grey_rock": ["rock_grey_a", 0.55], "fld_red_rock": ["rock_red_a", 0.9],
	"fld_bamboo_small": ["bamboo_clump_a", 0.9], "fld_round_bush": ["bush_round_a", 0.7], "fld_cerrado_shrub": ["bush_dry_a", 0.7],
	"fld_rosemary": ["bush_olive_a", 0.5], "fld_dry_bush": ["bush_dry_a", 0.55], "fld_snow_shrub": ["bush_snow_a", 0.6],
	"fld_big_leaf": ["bush_jungle_a", 0.6],
	"fld_grass_tuft": ["grass_tuft", 1.2], "fld_golden_grass": ["grass_golden", 1.3], "fld_white_flowers": ["flowers_b", 1.2],
	"fld_cerrado_flowers": ["flowers", 1.2], "fld_reeds": ["reeds", 1.3], "fld_lavender": ["flowers_purple", 1.3],
	"fld_heather": ["flowers_purple", 1.1], "fld_mushrooms": ["mushrooms", 1.2], "fld_fern": ["fern", 1.2],
}
const SMALL_KIT := ["grass_tuft", "grass_golden", "flowers", "flowers_b", "reeds", "flowers_purple", "mushrooms", "fern",
	"grass_tuft_b"]
## Nacoes cujo chao nao tem capim (angulo central, meia largura em graus)
const NO_GRASS_ZONES := [["portugal", 145.0], ["egito", 208.0], ["nordico", 270.0], ["china", 332.0]]


func _geo_dir() -> String:
	return TF_GEO


## Vestir o chão (revisão 3): bordas de trilha e riacho, Terra de Pindorama densa, acampamento, Japão, México, Egito
## e Grécia. Só enfeites baixos e atravessáveis (capim, flores, seixos, arbustinhos, juncos) ou peças junto de
## obstruções que já existem — o navmesh não muda.
func _dress(krng: RandomNumberGenerator) -> void:
	_vignettes(krng)
	var put := func(mesh: String, p: Vector3, s: float) -> void:
		kit_items.append([mesh, Transform3D(Basis(Vector3.UP, krng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, 0.0, p.z))])
	var free := func(p: Vector3, m: float) -> bool:
		return not _in_obstruction(p, m) and not _in_keepout(p) and Vector2(p.x, p.z).length() < FIELD_R + 4.0
	# --- bordas das trilhas: seixos colados na borda, capim alto e flores logo fora
	for t: Array in trails:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var hw: float = t[2]
		var d := b - a
		d.y = 0
		var L := d.length()
		var side := Vector3(-d.z, 0, d.x).normalized()
		var n := int(L / 0.7)
		for i in n:
			var q := a.lerp(b, (i + krng.randf()) / n)
			for sg: float in [-1.0, 1.0]:
				var e := q + side * sg * (hw + krng.randf_range(0.0, 0.5))
				if _on_trail(e - side * sg * 0.45):
					pass
				if stream_pts.size() > 1 and _near_stream(e, 2.6):
					continue
				if krng.randf() < 0.18 and free.call(e, 0.0) and Vector2(e.x, e.z).length() > CAMP_R + 6.0:
					put.call(["pk_pebble_round_1", "pk_pebble_round_3", "pk_pebble_square_2"][krng.randi() % 3], e, krng.randf_range(0.8, 1.5))
				var g := q + side * sg * (hw + krng.randf_range(0.5, 1.6))
				if free.call(g, 0.0) and not _on_trail(g) and not (stream_pts.size() > 1 and _near_stream(g, 2.6)):
					put.call("grass_tuft_b" if krng.randf() < 0.6 else "flowers_b", g, krng.randf_range(0.7, 1.0))
	# --- riacho: juncos e pedras nas margens (dentro da faixa já bloqueada), seixos no vau
	if stream_pts.size() > 1:
		for i in stream_pts.size() - 1:
			var a: Vector3 = stream_pts[i]
			var b: Vector3 = stream_pts[i + 1]
			var d := b - a
			var side := Vector3(-d.z, 0, d.x).normalized()
			var n := int(d.length() / 0.9)
			for k in n:
				var q := a.lerp(b, (k + krng.randf()) / n)
				for sg: float in [-1.0, 1.0]:
					var r := q + side * sg * krng.randf_range(1.75, 2.6)
					if krng.randf() < 0.55:
						put.call("reeds_card", r, krng.randf_range(0.8, 1.3))
					elif krng.randf() < 0.5:
						put.call("rock_moss_b", r, krng.randf_range(0.35, 0.6))
					else:
						put.call("pk_pebble_round_3", r, krng.randf_range(1.0, 1.8))
	# --- Terra de Pindorama: capim dourado denso, flores do cerrado, arbustinhos, seixos
	var sab := func(p: Vector3) -> bool:
		return free.call(p, 0.2) and not _on_trail(p) and not _near_stream(p, 2.8)
	for i in 3200:
		var p := PINDORAMA_C + pol(krng.randf() * 360.0, sqrt(krng.randf()) * 35.0)
		if not sab.call(p):
			continue
		var roll := krng.randf()
		if roll < 0.55:
			put.call("grass_golden", p, krng.randf_range(0.8, 1.3))
		elif roll < 0.75:
			put.call("grass_tuft_b", p, krng.randf_range(0.8, 1.2))
		elif roll < 0.88:
			put.call(["flowers", "flowers_b", "flowers_purple"][krng.randi() % 3], p, krng.randf_range(0.6, 0.9))
		elif roll < 0.95:
			put.call("pk_bush_dry", p, krng.randf_range(0.35, 0.55))
		else:
			put.call("pk_pebble_round_1", p, krng.randf_range(1.0, 1.8))
	# pedras com musgo e cupinzeirinhos ao pé de obstruções que já existem (árvores/cupinzeiros)
	for o: Array in obstructions:
		var pts: PackedVector3Array = o[0]
		var cc := Vector3.ZERO
		for q in pts:
			cc += q
		cc /= maxf(pts.size(), 1)
		if cc.distance_to(PINDORAMA_C) < 34.0 and krng.randf() < 0.5:
			var off := pol(krng.randf() * 360.0, krng.randf_range(0.6, 1.1))
			put.call("rock_moss_b" if krng.randf() < 0.7 else "pk_mushroom", cc + off, krng.randf_range(0.35, 0.55))
	# --- acampamento: bordas de capim, seixos, toras, sacos, barris, bancos e bonecos de treino
	for i in 260:
		var p := pol(krng.randf() * 360.0, krng.randf_range(CAMP_R - 2.0, CAMP_R + 2.5))
		if free.call(p, 0.1) and not _on_trail(p):
			put.call("grass_tuft_b" if krng.randf() < 0.7 else "flowers_b", p, krng.randf_range(0.8, 1.2))
	_dress_camp(krng, put, free)
	for spec: Array in [["pk_bench", Vector3(-3.4, 0, -1.2), 0.9, 1.3], ["pk_bench", Vector3(3.3, 0, -2.0), 0.9, -1.4],
			["pk_bag", Vector3(-9.0, 0, 5.0), 1.0, 0.3], ["pk_bag", Vector3(9.2, 0, 4.6), 1.0, 2.0],
			["pk_barrel", Vector3(-8.8, 0, 2.2), 1.0, 0.0], ["pk_crate_wooden", Vector3(10.6, 0, 2.8), 0.9, 0.6],
			["prop_log", Vector3(-1.5, 0, 9.5), 0.8, 0.4], ["pk_dummy", Vector3(-6.5, 0, -7.5), 1.0, 0.8],
			["pk_dummy", Vector3(-8.0, 0, -6.0), 1.0, 0.5], ["pk_bucket_wooden_1", Vector3(1.8, 0, 1.2), 1.0, 0.0]]:
		if free.call(spec[1], 0.2):
			kit_items.append([spec[0], Transform3D(Basis(Vector3.UP, spec[3]).scaled(Vector3.ONE * float(spec[2])), spec[1])])
	# --- zonas: identidade no chão
	var zone := func(id: String) -> Vector3:
		for nn: Array in NATIONS:
			if nn[0] == id:
				return pol(nn[1], ZONE_R)
		return Vector3.ZERO
	var jp: Vector3 = zone.call("japao")
	for i in 400:
		var p := jp + pol(krng.randf() * 360.0, sqrt(krng.randf()) * 17.0)
		if not free.call(p, 0.2) or _on_trail(p):
			continue
		var roll := krng.randf()
		if roll < 0.35:
			put.call("pk_clover_1", p, krng.randf_range(0.8, 1.2))
		elif roll < 0.55:
			put.call("pk_rockpath_round_small_1", p, krng.randf_range(0.5, 0.8))
		elif roll < 0.8:
			put.call("fern", p, krng.randf_range(0.6, 0.9))
		else:
			put.call("pk_pebble_round_3", p, krng.randf_range(1.0, 1.6))
	var mx: Vector3 = zone.call("mexico")
	for i in 700:
		var p := mx + pol(krng.randf() * 360.0, sqrt(krng.randf()) * 17.5)
		if not free.call(p, 0.2) or _on_trail(p):
			continue
		var roll := krng.randf()
		if roll < 0.4:
			put.call("fern", p, krng.randf_range(0.8, 1.3))
		elif roll < 0.6:
			put.call("pk_plant_1", p, krng.randf_range(0.7, 1.1))
		elif roll < 0.75:
			put.call("pk_plant_7", p, krng.randf_range(0.8, 1.2))
		elif roll < 0.9:
			put.call("flowers", p, krng.randf_range(0.8, 1.1))
		else:
			put.call("pk_mushroom", p, krng.randf_range(0.6, 0.9))
	var eg: Vector3 = zone.call("egito")
	var eg_out := eg.normalized()
	var eg_side := Vector3(-eg_out.z, 0, eg_out.x)
	kit_items.append(["lm_egito_dunes", Transform3D(Basis(Vector3.UP, atan2(eg_side.x, eg_side.z)), eg + eg_out * 15.5)])
	kit_items.append(["lm_egito_dunes", Transform3D(Basis(Vector3.UP, atan2(eg_side.x, eg_side.z) + 0.5).scaled(Vector3.ONE * 0.8),
			eg + eg_out * 12.0 + eg_side * 11.0)])
	kit_items.append(["lm_egito_ruins", Transform3D(Basis(Vector3.UP, 0.7), eg + eg_side * 8.5 + eg_out * 4.0)])
	for i in 120:
		var p := eg + pol(krng.randf() * 360.0, sqrt(krng.randf()) * 17.0)
		if free.call(p, 0.2) and not _on_trail(p):
			put.call("pk_pebble_round_1" if krng.randf() < 0.6 else "pk_bush_dry", p, krng.randf_range(0.5, 1.2) if krng.randf() < 0.6 else 0.35)
	var gr: Vector3 = zone.call("grecia")
	var gr_out := gr.normalized()
	var gr_side := Vector3(-gr_out.z, 0, gr_out.x)
	kit_items.append(["lm_grecia_ruins", Transform3D(Basis(Vector3.UP, 0.3), gr - gr_side * 8.0 + gr_out * 3.0)])
	kit_items.append(["lm_grecia_ruins", Transform3D(Basis(Vector3.UP, 2.1).scaled(Vector3.ONE * 0.8), gr + gr_side * 9.0 - gr_out * 2.0)])
	for i in 300:
		var p := gr + pol(krng.randf() * 360.0, sqrt(krng.randf()) * 18.0)
		if free.call(p, 0.2) and not _on_trail(p):
			put.call(["grass_golden", "flowers_purple", "pk_bush_dry", "grass_tuft_b"][krng.randi() % 4], p, krng.randf_range(0.6, 1.1))


## Vinhetas culturais (revisão 5): cada nação ganha peças que a representam, em volta do marco e do Mestre.
## Peças sólidas registram obstrução pequena (navmesh re-assado e verificado); só entram se não caem em trilha,
## grupo de monstros, Mestre ou outra obstrução.
func _vignettes(krng: RandomNumberGenerator) -> void:
	var skipped: Array = []
	var yaw_to_camp := func(p: Vector3) -> float:
		return atan2(-p.x, -p.z)
	var stats := {"placed": 0}
	var solid := func(mesh: String, zone: String, uv: Vector2, yaw_off: float, r: float, s: float = 1.0) -> void:
		# procura o ponto livre mais próximo (espiral de até 4 m) — não cai em trilha, monstros, Mestre ou obstrução
		var found := false
		var p := Vector3.ZERO
		for k in 25:
			var off := Vector2.ZERO if k == 0 else Vector2.from_angle(k * 2.4) * (0.6 + k * 0.15)
			p = _zone_local(zone, uv + off)
			var bad := _on_trail(p) or _in_keepout(p) or _in_obstruction(p, r * 0.5)
			for e: Array in npc_points:
				if p.distance_to(e[1]) < r + 1.8:
					bad = true
			if not bad:
				found = true
				break
		if not found:
			skipped.append("%s@%s" % [mesh, zone])
			return
		kit_items.append([mesh, Transform3D(Basis(Vector3.UP, yaw_to_camp.call(p) + yaw_off).scaled(Vector3.ONE * s), p)])
		if r > 0.0:
			obstruct_circle(p, r, 3.0)
		stats["placed"] += 1
	var deco := func(mesh: String, zone: String, uv: Vector2, s: float = 1.0) -> void:
		var p := _zone_local(zone, uv)
		if not _in_keepout(p) and not _on_trail(p):
			kit_items.append([mesh, Transform3D(Basis(Vector3.UP, krng.randf() * TAU).scaled(Vector3.ONE * s), p)])
	var paint := func(mat: String, zone: String, uv: Vector2, r: float) -> void:
		var p := _zone_local(zone, uv)
		relief.shapes.append([mat, Vector2(p.x, p.z), r, 0.12])
	var lane := func(mat: String, zone: String, a: Vector2, b: Vector2, w: float) -> void:
		var pa := _zone_local(zone, a)
		var pb := _zone_local(zone, b)
		relief.strips.append([mat, Vector2(pa.x, pa.z), Vector2(pb.x, pb.z), w])
	# Portugal: casinha caiada com azulejo, muros com vasos, beco de pedra, barquinho na areia
	lane.call("cobble", "portugal", Vector2(0, -9), Vector2(0, 8), 2.6)
	solid.call("vg_portugal_house", "portugal", Vector2(-9.5, 2.5), 0.3, 2.6)
	solid.call("vg_portugal_wall", "portugal", Vector2(5.5, -3.0), -0.2, 1.6)
	solid.call("vg_portugal_wall", "portugal", Vector2(-5.0, -10.5), 0.1, 1.6)
	paint.call("sand", "portugal", Vector2(10.0, 9.0), 3.6)
	solid.call("pk_boat_row_small", "portugal", Vector2(10.0, 9.0), 0.9, 1.4)
	# Grécia: escadaria diante da colunata, ânforas, colunas caídas, oliveiral
	solid.call("vg_greek_steps", "grecia", Vector2(0, 2.2), PI, 2.0)
	solid.call("vg_greek_amphorae", "grecia", Vector2(-4.5, -9.5), 0.0, 1.0)
	solid.call("vg_greek_amphorae", "grecia", Vector2(6.5, 0.5), 1.2, 1.0)
	for q in 5:
		deco.call("tree_olive_a", "grecia", Vector2(-12.0 + q * 2.2, 8.0 + (q % 2) * 2.5), 0.9)
	# Egito: oásis com palmeiras e barco de junco (lagoa criada no relevo)
	for q in 6:
		var a := q * TAU / 6.0
		solid.call("palm_date_a", "egito", Vector2(-8.5, 6.5) + Vector2(cos(a), sin(a)) * 4.3, 0.0, 0.5, krng.randf_range(0.85, 1.1))
	solid.call("vg_reed_boat", "egito", Vector2(-6.0, 5.2), 0.6, 0.0)
	solid.call("vg_clay_pots", "egito", Vector2(4.5, -9.5), 0.0, 0.8)
	# Celta: círculo de pedras na colina, urze, cabanas
	solid.call("vg_standing_stones", "celta", Vector2(8.5, 6.5), 0.0, 4.2)
	for q in 5:
		paint.call("heather", "celta", Vector2(krng.randf_range(-13, 13), krng.randf_range(-6, 13)), krng.randf_range(2.0, 3.5))
	# Nórdico: postes entalhados na entrada da casa longa, rochas de fiorde
	solid.call("vg_carved_post", "nordico", Vector2(-3.2, 3.0), 0.0, 0.4)
	solid.call("vg_carved_post", "nordico", Vector2(3.2, 3.0), 0.0, 0.4)
	solid.call("vg_carved_post", "nordico", Vector2(4.5, -9.5), 0.0, 0.4)
	solid.call("pk_rock_2", "nordico", Vector2(-10.0, 10.0), 0.3, 2.2, 1.6)
	solid.call("pk_rock_3", "nordico", Vector2(10.5, 11.0), 1.3, 2.2, 1.7)
	# Eslavo: poço de grua e bosque de bétulas
	solid.call("vg_crane_well", "eslavo", Vector2(7.0, -3.0), 0.4, 1.0)
	for q in 6:
		deco.call("tree_birch_a", "eslavo", Vector2(-13.0 + q * 1.8, -2.0 + (q % 3) * 3.0), 0.9)
	# China: lago do pavilhão com ponte de pedra, calçamento
	solid.call("vg_stone_bridge", "china", Vector2(-9.0, 5.0), 0.2, 0.0, 0.9)
	lane.call("stone_paving", "china", Vector2(0, -9), Vector2(0, 5), 2.4)
	for q in 4:
		var a := q * TAU / 4.0 + 0.4
		deco.call("bamboo_clump_a", "china", Vector2(-9.0, 5.0) + Vector2(cos(a), sin(a)) * 4.6, 1.0)
	# Japão: jardim de cascalho, lanternas de pedra, bordos vermelhos
	paint.call("gravel", "japao", Vector2(7.5, -1.0), 4.2)
	for q in 3:
		deco.call("rock_grey_a", "japao", Vector2(6.0 + q * 1.6, -2.0 + (q % 2) * 1.8), 1.2)
	solid.call("vg_stone_lantern", "japao", Vector2(-4.0, -9.5), 0.0, 0.5)
	solid.call("vg_stone_lantern", "japao", Vector2(4.0, 1.5), 0.0, 0.5)
	solid.call("vg_stone_lantern", "japao", Vector2(-5.5, 3.0), 0.0, 0.5)
	for uv: Vector2 in [Vector2(-10, 8), Vector2(10, 8), Vector2(-12, -2), Vector2(12, 3)]:
		solid.call("pk_maple_1" if uv.x < 0 else "pk_maple_2", "japao", uv, 0.0, 0.6)
	# México: sumaúma gigante, potes de barro
	solid.call("pk_ceiba", "mexico", Vector2(9.0, 9.0), 0.0, 1.4, 0.8)
	solid.call("vg_clay_pots", "mexico", Vector2(-4.0, -9.5), 0.0, 0.8)
	solid.call("vg_clay_pots", "mexico", Vector2(5.0, -2.5), 0.0, 0.8)
	print("vinhetas: %d peças; puladas: %s" % [stats["placed"], skipped])


## Acampamento (ponto de nascimento — o lugar mais bonito do mapa): anel de lajes em volta da fogueira, placas para
## cada nação, lampiões, poço e carroça de suprimentos, canteiros floridos e arbustos na borda. Tudo baixo/atravessável
## exceto poço e carroça (obstrução própria, pequena).
func _dress_camp(krng: RandomNumberGenerator, put: Callable, free: Callable) -> void:
	_camp_landscape()
	var fire := Vector3(0, 0, -1.5)
	# placas: uma por nação, na saída da trilha, seta apontando para fora
	var dests := NATIONS.map(func(n: Array) -> Array: return [n[1], n[4]])
	dests.append([90.0, "banner_brasil"])
	for dd: Array in dests:
		var a: float = dd[0]
		var d := pol(a, 1.0)
		var side := Vector3(-d.z, 0, d.x)
		var p := pol(a, CAMP_R - 2.8) + side * 1.75
		var tint := Color(0.8, 0.6, 0.4)
		var bm: Variant = mats.get(dd[1])
		if bm is ShaderMaterial:
			tint = (bm as ShaderMaterial).get_shader_parameter(&"tint")
		elif bm is StandardMaterial3D:
			tint = (bm as StandardMaterial3D).albedo_color
		kit_items.append(["camp_signpost", Transform3D(Basis(Vector3.UP, -deg_to_rad(a)), p), tint])
	# lampiões entre as trilhas, braço virado para o centro
	var angs: Array = [90.0]
	for n: Array in NATIONS:
		angs.append(n[1])
	angs.sort()
	for i in range(0, angs.size(), 2):
		var a0: float = angs[i]
		var a1: float = angs[(i + 1) % angs.size()] + (360.0 if i == angs.size() - 1 else 0.0)
		var am := (a0 + a1) * 0.5
		var p := pol(am, 7.0)
		if free.call(p, 0.4):
			kit_items.append(["camp_lantern", Transform3D(Basis(Vector3.UP, -deg_to_rad(am + 180.0)), p)])
	# poço e carroça de suprimentos (perto do nascimento, visíveis de cara)
	var well := pol(125.0, 10.5)
	kit_items.append(["camp_well", Transform3D(Basis(Vector3.UP, 0.6), well)])
	obstruct_circle(well, 1.15, 2.5)
	var cart := pol(58.0, 10.8)
	var cyaw := -deg_to_rad(58.0) + PI * 0.5
	kit_items.append(["pkv_prop_wagon", Transform3D(Basis(Vector3.UP, cyaw), cart)])
	for k in 3:
		kit_items.append([["pk_crate_wooden", "pk_barrel_apples", "pk_farmcrate_carrot"][k],
				Transform3D(Basis(Vector3.UP, krng.randf() * TAU).scaled(Vector3.ONE * 0.85),
				cart + Basis(Vector3.UP, cyaw) * Vector3(0.0, 0.9, -1.2 + k * 1.0))])
	obstruct_rect(cart, 2.2, 4.2, cyaw, 2.0)
	# Canteiros deliberados: uma cor por grupo e gramado vazio entre eles.
	# RNG independente: não desloca as vinhetas nem as obstruções do mapa.
	var garden := RandomNumberGenerator.new()
	garden.seed = 2809202606
	for bed: Array in [[115.0, 9.4, "flowers_purple"], [62.0, 8.8, "flowers_b"],
			[185.0, 12.0, "flowers_b"], [350.0, 12.0, "flowers_purple"],
			[242.0, 12.8, "flowers_purple"], [298.0, 12.8, "flowers_b"]]:
		var center := pol(bed[0], bed[1])
		for j in 35:
			var p := center + pol(garden.randf() * 360.0, sqrt(garden.randf()) * 2.0)
			if not free.call(p, 0.4) or _on_trail(p):
				continue
			var mesh: String = bed[2] if j % 3 == 0 else "grass_tuft_b"
			var size := garden.randf_range(0.4, 0.65)
			var yaw := garden.randf() * TAU
			if mesh == "grass_tuft_b":
				# GDD §17.0.C: o "capim baixo" do canteiro vira folhagem baixa e cheia (moita rasteira), sem tufo espetado.
				kit_items.append([BUSH_LOW, Transform3D(Basis(Vector3.UP, yaw).scaled(
						Vector3(size * 0.95, size * 0.4, size * 0.95)), p)])
			else:
				kit_items.append([mesh, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size * 0.85, size)), p)])


## Bosques enquadram a clareira em vez de espalhar plantas isoladas. RNG próprio e troncos bloqueados.
func _camp_landscape() -> void:
	var garden := RandomNumberGenerator.new()
	garden.seed = 8102026
	var tree_count := 0
	for angle: float in [113.0, 161.0, 192.0, 224.0, 254.0, 285.0, 316.0, 347.0, 18.0, 62.0]:
		var center := pol(angle, 18.5)
		for i: int in 3:
			var p := center if i == 0 else pol(angle + (-4.0 if i == 1 else 5.0), 22.0 + i)
			if not _camp_plantable(p, 0.9):
				continue
			var size := garden.randf_range(0.85, 1.12)
			var mesh := "tree_broadleaf_a"
			if i == 0 and angle in [113.0, 254.0, 347.0]:
				mesh = "tree_ipe_yellow_a" if angle == 113.0 else "tree_ipe_purple_a"
			kit_items.append([mesh, Transform3D(Basis(Vector3.UP, garden.randf() * TAU).scaled(Vector3.ONE * size), p)])
			obstruct_circle(p, 0.55 * size, 4.0)
			tree_count += 1
		# Sub-bosque em massas: moitas sobrepostas e poucos pontos de flor.
		for j: int in 24:
			var p := center + pol(garden.randf() * 360.0, sqrt(garden.randf()) * 3.3)
			if not _camp_plantable(p, 0.15):
				continue
			var size := garden.randf_range(0.6, 1.1)
			var mesh := BUSH_LOW if j % 6 != 0 else "fern"
			var scale := Vector3(size, size * 0.7, size)
			kit_items.append([mesh, Transform3D(Basis(Vector3.UP, garden.randf() * TAU).scaled(scale), p)])
			if j % 8 == 0:
				kit_items.append(["flowers_b", Transform3D(Basis(Vector3.UP, garden.randf() * TAU).scaled(Vector3.ONE * 0.7), p)])
	# Bordas internas de canteiros maiores, baixas para manter a vista da fogueira e dos NPCs.
	for center: Vector3 in [Vector3(-10, 0, 5), Vector3(10, 0, 5), Vector3(-12, 0, -3), Vector3(12, 0, -3)]:
		for j: int in 28:
			var p := center + pol(garden.randf() * 360.0, sqrt(garden.randf()) * 2.2)
			if not _camp_plantable(p, 0.1):
				continue
			var s := garden.randf_range(0.45, 0.72)
			kit_items.append([BUSH_LOW, Transform3D(Basis(Vector3.UP, garden.randf() * TAU).scaled(Vector3(s, s * 0.5, s)), p)])
	print("camp landscape: ", tree_count, " trees")


func _camp_plantable(p: Vector3, clearance: float) -> bool:
	if _in_obstruction(p, clearance) or _in_keepout(p) or _on_trail(p):
		return false
	for offset: Vector3 in [Vector3(clearance, 0, 0), Vector3(-clearance, 0, 0), Vector3(0, 0, clearance), Vector3(0, 0, -clearance)]:
		if _on_trail(p + offset):
			return false
	return true


## Cópias próprias do Campo: materiais novos não recolorem tendas usadas por outros mapas.
func _camp_canvas_mesh(path: String) -> Mesh:
	var mesh: ArrayMesh = (load(path) as ArrayMesh).duplicate() as ArrayMesh
	var blue: bool = path.get_file().get_basename().ends_with("_b")
	for i: int in mesh.get_surface_count():
		var source: ShaderMaterial = mesh.surface_get_material(i) as ShaderMaterial
		if source == null:
			continue
		var material := source.duplicate() as ShaderMaterial
		if i == 0 or i == 5:
			material.shader = load("res://assets/shaders/env_camp_canvas.gdshader")
			var tint := Color(0.36, 0.57, 0.53) if blue else Color(0.74, 0.58, 0.36)
			material.set_shader_parameter(&"tint", tint * (0.85 if i == 5 else 1.0))
		else:
			var tint: Color = source.get_shader_parameter(&"tint")
			material.set_shader_parameter(&"tint", tint * 0.78)
		mesh.surface_set_material(i, material)
	var destination := "%s/canvas_%s.res" % [TF_GEO, path.get_file().get_basename()]
	ResourceSaver.save(mesh, destination, ResourceSaver.FLAG_COMPRESS)
	return load(destination)


## Decor/Kit: malhas do kit pintado em MultiMesh (pedacos de 24 m). Substitui a antiga camada de sprites.
func _sprite_layer(root: Node3D) -> void:
	var krng := RandomNumberGenerator.new()
	krng.seed = 2709
	_dress(krng)
	var logical: Array = [] # [nome lógico, Transform3D] → KitCatalog escolhe a malha real
	var add := func(mesh: String, t: Transform3D) -> void:
		logical.append([mesh, t])
	var missing := {}
	for sp: Array in sprites:
		if not SPRITE_KIT.has(sp[0]):
			missing[sp[0]] = true
			continue
		var spec: Array = SPRITE_KIT[sp[0]]
		var sc: float = float(sp[2]) * float(spec[1])
		add.call(spec[0], Transform3D(Basis(Vector3.UP, krng.randf() * TAU).scaled(Vector3(sc, sc * krng.randf_range(0.92, 1.08), sc)), sp[1]))
	for it: Array in kit_items:
		add.call(it[0], it[1])
	if not missing.is_empty():
		push_warning("sprites sem malha do kit: %s" % [missing.keys()])
	# capim espalhado pelo campo (fora de trilhas, agua, obstrucoes, acampamento e chaos sem grama)
	var grassy := func(x: float, z: float) -> float:
		var p := Vector3(x, 0, z)
		var r := Vector2(x, z).length()
		if r < CAMP_R + 1.0 or r > FIELD_R + 4.0 or _on_trail(p) or _in_obstruction(p, 0.3):
			return 0.0
		if stream_pts.size() > 0 and _near_stream(p, 2.6):
			return 0.0
		for zc: Array in NO_GRASS_ZONES:
			if p.distance_to(pol(zc[1], ZONE_R)) < 19.0:
				return 0.0
		return 1.0
	var flat := func(_x: float, _z: float) -> float: return 0.02
	var disc_area := Rect2(-FIELD_R - 4, -FIELD_R - 4, FIELD_R * 2 + 8, FIELD_R * 2 + 8)
	for sample: Array in FoliageScatter.sample(disc_area, 0.7, krng, grassy, flat, 0.8, 1.3):
		add.call("grass_tuft", sample[0])
	for sample: Array in FoliageScatter.sample(disc_area, 0.12, krng, grassy, flat, 0.8, 1.3):
		add.call("grass_tuft_b", sample[0])
	var fs := FoliageScatter.new()
	fs.name = "Kit"
	fs.chunk_size = 40.0
	_add(root, fs)
	var small_paths := {}
	for sk: String in SMALL_KIT:
		if KitCatalog.ALIAS.has(sk):
			for alt: Array in KitCatalog.ALIAS[sk]:
				small_paths[KitCatalog.MESH_DIR + String(alt[0]) + ".res"] = true
	# relevo: o que está em crista, borda, margem de rio/lagoa assenta no terreno (o chão andável é 0)
	for it: Array in logical:
		var nm := String(it[0])
		if nm.begins_with("lm_") or nm == "vg_stone_bridge" or nm.begins_with("camp_"):
			continue
		var t: Transform3D = it[1]
		var h: float = relief.height(t.origin.x, t.origin.z)
		if absf(h) > 0.01:
			t.origin.y = h
			it[1] = t
	# Grandes massas de vegetação com respiros: nunca confete uniforme no campo todo.
	# Filtragem visual posterior ao layout; não altera navegação, spawns ou marcos.
	var meadow := FastNoiseLite.new()
	meadow.seed = 28092026
	meadow.frequency = 0.11
	for i in range(logical.size() - 1, -1, -1):
		var item: Array = logical[i]
		var id := String(item[0])
		if not (id.begins_with("grass") or id.begins_with("flowers") or id == "fern"):
			continue
		var p: Vector3 = (item[1] as Transform3D).origin
		if Vector2(p.x, p.z).length() < CAMP_R:
			continue # canteiros do acampamento possuem composição própria
		var patch := meadow.get_noise_2d(p.x, p.z)
		var threshold := 0.08 if id.begins_with("flowers") else -0.08
		if _in_keepout(p) or patch < threshold:
			logical.remove_at(i)
	_ground_hugging_pass(logical, grassy)
	var items := KitCatalog.group(logical, krng)
	for m: String in items:
		var bn := m.get_file().get_basename()
		var small := small_paths.has(m)
		for key: String in ["pebble", "grass", "flower", "clover", "reeds", "fern", "plant_7", "mushroom", "rockpath",
				"bush_low"]:
			if key in bn:
				small = true
		var mesh: Mesh = _camp_canvas_mesh(m) if bn.begins_with("camp_tent_v2") else load(m)
		fs.add_instances(mesh, items[m], bn, krng, not small)
	var root_node: Node = root
	while root_node.get_parent() != null:
		root_node = root_node.get_parent()
	for n: Node in fs.get_children():
		var mmi := n as MultiMeshInstance3D
		n.owner = root_node
		var path := "%s/mm_%s.res" % [TF_GEO, mmi.name]
		ResourceSaver.save(mmi.multimesh, path, ResourceSaver.FLAG_COMPRESS)
		mmi.multimesh.take_over_path(path)
	print("kit do campo: ", fs.stats(), " malhas=", items.keys())


# ---------------------------------------------------------------- GDD §17.0.C (P2, 28/09/2026)
## Moita baixa e cheia (nome lógico do KitCatalog): copas pintadas achatadas e sobrepostas.
const BUSH_LOW := "bush_low"
const P2_SEED := 2809202617
## Achatamento das plantas rasteiras que continuam (capim/flores/samambaia): nada de tufo espetado.
const P2_FLATTEN := {"grass": 0.55, "flowers": 0.78, "fern": 0.8}
## Planta de chão sem vizinhas a menos de P2_NEIGHBOR_M sai (tufo isolado = recorte ao girar a câmera).
const P2_NEIGHBOR_M := 1.4
const P2_MIN_NEIGHBORS := 2
## Fração dos capins espalhados que fica (o chão pintado já lê como grama contínua).
const P2_GRASS_KEEP := 0.5
var p2_stats := {}


## Vegetação "não parecer papel" (GDD §17.0.C): (1) capins/flores/samambaias rasteiros ficam mais baixos e em grupos
## — tufos soltos e metade do capim espalhado saem (o terreno pintado segura a leitura de grama contínua);
## (2) moitas baixas e cheias em massas: nas bordas das trilhas (com intervalos), em manchas de ruído pelo campo e
## ao pé de árvores/pedras. Só decoração atravessável; não mexe em navmesh, spawns, marcos nem nos canteiros do
## acampamento (composição da revisão 6). RNG próprio: não desloca nada do que já existia.
func _ground_hugging_pass(logical: Array, grassy: Callable) -> void:
	var before := logical.size()
	# (1) plantas rasteiras existentes
	var cell := P2_NEIGHBOR_M
	var buckets := {}
	var is_ground_plant := func(id: String) -> bool:
		return id.begins_with("grass") or id.begins_with("flowers") or id == "fern"
	for it: Array in logical:
		if not is_ground_plant.call(String(it[0])):
			continue
		var o: Vector3 = (it[1] as Transform3D).origin
		var key := Vector2i(floori(o.x / cell), floori(o.z / cell))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(o)
	var removed_isolated := 0
	var removed_thin := 0
	for i in range(logical.size() - 1, -1, -1):
		var it: Array = logical[i]
		var id := String(it[0])
		if not is_ground_plant.call(id):
			continue
		var t: Transform3D = it[1]
		var o := t.origin
		if Vector2(o.x, o.z).length() < CAMP_R - 3.0:
			continue # canteiros do acampamento (revisão 6)
		# metade do capim espalhado sai (determinístico pela posição)
		if id == "grass_tuft" and _p2_hash(o) >= P2_GRASS_KEEP:
			logical.remove_at(i)
			removed_thin += 1
			continue
		var key := Vector2i(floori(o.x / cell), floori(o.z / cell))
		var near := 0
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for q: Vector3 in buckets.get(key + Vector2i(dx, dz), []):
					if q != o and Vector2(q.x - o.x, q.z - o.z).length() < P2_NEIGHBOR_M:
						near += 1
		if near < P2_MIN_NEIGHBORS:
			logical.remove_at(i)
			removed_isolated += 1
			continue
		var f := 1.0
		for k: String in P2_FLATTEN:
			if id.begins_with(k):
				f = P2_FLATTEN[k]
		t.basis = t.basis * Basis.from_scale(Vector3(1.0, f, 1.0))
		it[1] = t
	# (2) moitas baixas
	var prng := RandomNumberGenerator.new()
	prng.seed = P2_SEED
	var added := [0]
	var free_for := func(p: Vector3, r: float) -> bool:
		if float(grassy.call(p.x, p.z)) <= 0.0 or _in_keepout(p) or _in_obstruction(p, r * 0.5):
			return false
		for e: Array in npc_points:
			if p.distance_to(e[1]) < r + 2.0:
				return false
		# a moita inteira fora da trilha
		for t: Array in trails:
			var a: Vector3 = t[0]
			var b: Vector3 = t[1]
			var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(a.x, a.z), Vector2(b.x, b.z))
			if q.distance_to(Vector2(p.x, p.z)) < (t[2] as float) + r * 0.8 + 0.3:
				return false
		return true
	var moita := func(c: Vector3, r: float, flower: String) -> void:
		var n := clampi(int(r * r * 2.4), 2, 10)
		for k in n:
			var off := pol(prng.randf() * 360.0, sqrt(prng.randf()) * r * 0.7)
			var s := prng.randf_range(0.36, 0.5) * clampf(r / 1.2, 0.75, 1.25)
			var sy := s * prng.randf_range(0.36, 0.5)
			var p := c + off
			p.y = relief.height(p.x, p.z)
			logical.append([BUSH_LOW, Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled(Vector3(s, sy, s)), p)])
			added[0] += 1
		# folhas rasteiras na borda e, às vezes, flores por cima
		for k in clampi(int(r * 2.0), 1, 4):
			var p := c + pol(prng.randf() * 360.0, r * prng.randf_range(0.75, 1.05))
			p.y = relief.height(p.x, p.z)
			var s2 := prng.randf_range(0.45, 0.65)
			logical.append(["pk_fern", Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled(Vector3(s2, s2 * 0.6, s2)), p)])
			added[0] += 1
		if not flower.is_empty():
			for k in clampi(int(r * 2.5), 2, 5):
				var p := c + pol(prng.randf() * 360.0, sqrt(prng.randf()) * r * 0.55)
				p.y = relief.height(p.x, p.z)
				var s3 := prng.randf_range(0.45, 0.6)
				logical.append([flower, Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled(Vector3(s3, s3 * 0.8, s3)), p)])
				added[0] += 1
	var flower_for := func(p: Vector3) -> String:
		var roll := prng.randf()
		if roll < 0.7:
			return ""
		if p.distance_to(PINDORAMA_C) < 36.0:
			return "flowers"
		return "flowers_b" if roll < 0.85 else "flowers_purple"
	var count := {"trail": 0, "patch": 0, "base": 0}
	# bordas das trilhas: moitas intercaladas, com respiros
	for t: Array in trails:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var hw: float = t[2]
		var d := b - a
		d.y = 0.0
		var L := d.length()
		if L < 2.0:
			continue
		var side := Vector3(-d.z, 0, d.x).normalized()
		var x := prng.randf_range(1.0, 5.0)
		while x < L:
			var q := a.lerp(b, x / L)
			var r := prng.randf_range(0.8, 1.5)
			var sg := -1.0 if prng.randf() < 0.5 else 1.0
			var c := q + side * sg * (hw + r * 0.8 + prng.randf_range(0.4, 1.1))
			if Vector2(c.x, c.z).length() > CAMP_R + 2.0 and free_for.call(c, r):
				moita.call(c, r, flower_for.call(c))
				count["trail"] += 1
			x += prng.randf_range(5.5, 10.0)
	# manchas grandes pelo campo (massas cheias com respiros)
	var mass := FastNoiseLite.new()
	mass.seed = P2_SEED
	mass.frequency = 0.05
	var step := 3.0
	var gx := -FIELD_R
	while gx <= FIELD_R:
		var gz := -FIELD_R
		while gz <= FIELD_R:
			var p := Vector3(gx + prng.randf_range(-1.2, 1.2), 0.0, gz + prng.randf_range(-1.2, 1.2))
			var nv := mass.get_noise_2d(p.x, p.z)
			var rr := Vector2(p.x, p.z).length()
			if nv > 0.25 and rr > CAMP_R + 3.0 and rr < FIELD_R and free_for.call(p, 1.4):
				moita.call(p, prng.randf_range(1.0, 1.9), flower_for.call(p))
				count["patch"] += 1
			gz += step
		gx += step
	# ao pé de árvores e pedras (obstruções pequenas já existentes)
	for o: Array in obstructions:
		var pts: PackedVector3Array = o[0]
		if pts.size() == 0 or prng.randf() > 0.45:
			continue
		var cc := Vector3.ZERO
		for q in pts:
			cc += q
		cc /= pts.size()
		var rad := 0.0
		for q in pts:
			rad = maxf(rad, Vector2(q.x - cc.x, q.z - cc.z).length())
		if rad > 3.0:
			continue
		var c := cc + pol(prng.randf() * 360.0, rad + prng.randf_range(0.8, 1.4))
		if free_for.call(c, 0.9):
			moita.call(c, prng.randf_range(0.8, 1.3), "")
			count["base"] += 1
	p2_stats = {"before": before, "after": logical.size(), "grass_thinned": removed_thin,
		"isolated_removed": removed_isolated, "moitas": count, "moita_pieces": added[0]}
	print("P2 vegetação (GDD §17.0.C): ", p2_stats)


## 0..1 determinístico pela posição (sem consumir RNG).
static func _p2_hash(p: Vector3) -> float:
	var h := absi(int(floor(p.x * 13.7) * 73856093) ^ int(floor(p.z * 11.3) * 19349663))
	return float(h % 1000) / 1000.0


## Revisão da chegada: clareira compacta com caminhos visíveis em meio à vegetação.
## Só decoração; estado dos geradores e obstruções originais preservados.
func _arrival_ground() -> void:
	var saved_state: int = rng.state
	for n: Array in NATIONS:
		trail("dirt", [pol(n[1], 4.2), pol(n[1], CAMP_R - 1.0)], 1.1, 0.035)
	trail("dirt", [Vector3(0, 0, 3), Vector3(0, 0, 9), pol(90, CAMP_R)], 2.0, 0.036)
	for deg: float in [200.0, 225.0, 320.0, 345.0]:
		var p: Vector3 = pol(deg, CAMP_R - 4.0)
		disc("dirt", p, 2.2, 0.037, 0.18)
		trail("dirt", [p, p.normalized() * 4.2], 1.1, 0.038)
	rng.state = saved_state


## Chamas em partículas (aditivas, rampa amarelo → laranja → vermelho), por cima da língua de fogo pintada.
static func _fire_particles(pname: String, pos: Vector3, s: float) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = pname
	gp.amount = 18
	gp.lifetime = 0.9
	gp.preprocess = 1.0
	gp.position = pos + Vector3(0, 0.15, 0)
	gp.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3, 4, 3))
	var ppm := ParticleProcessMaterial.new()
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	ppm.emission_sphere_radius = 0.28 * s
	ppm.direction = Vector3.UP
	ppm.spread = 12.0
	ppm.gravity = Vector3(0, 1.2, 0)
	ppm.initial_velocity_min = 0.4
	ppm.initial_velocity_max = 0.9
	ppm.scale_min = 0.7 * s
	ppm.scale_max = 1.2 * s
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(0.25, 1.0))
	sc.add_point(Vector2(1, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	ppm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.62, 0.15, 0.0))
	g.add_point(0.15, Color(1.0, 0.5, 0.1, 0.7))
	g.add_point(0.55, Color(0.9, 0.22, 0.05, 0.45))
	g.set_color(1, Color(0.35, 0.08, 0.04, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	ppm.color_ramp = gt
	gp.process_material = ppm
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.45)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	var rg := Gradient.new()
	rg.set_color(0, Color(1, 1, 1, 1))
	rg.set_color(1, Color(1, 1, 1, 0))
	var rt := GradientTexture2D.new()
	rt.gradient = rg
	rt.fill = GradientTexture2D.FILL_RADIAL
	rt.fill_from = Vector2(0.5, 0.5)
	rt.fill_to = Vector2(0.5, 0.0)
	rt.width = 64
	rt.height = 64
	m.albedo_texture = rt
	q.material = m
	gp.draw_pass_1 = q
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return gp


func _add_camp_flames(parent: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/env_fire.gdshader")
	for spec: Array in [[Vector3(0, 0, -1.5), 1.45], [RANCHO + Vector3(-1, 0, 3), 0.9]]:
		var flame := MeshInstance3D.new()
		flame.name = "CampFlame" if spec[1] > 1 else "RanchoFlame"
		var quad := QuadMesh.new()
		quad.size = Vector2(1.1, 1.45) * float(spec[1])
		quad.material = material
		flame.mesh = quad
		flame.position = spec[0] + Vector3(0, 0.62 * float(spec[1]), 0)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(parent, flame)
