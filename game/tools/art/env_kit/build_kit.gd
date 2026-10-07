extends SceneTree
## Kit de cenário pintado (GDD §17.0.A) — gera materiais e malhas reutilizáveis em
## res://assets/environment/painted/{materials,meshes}. Reexecutável e determinístico (seeds fixas).
##   godot --headless --path game --script res://tools/art/env_kit/build_kit.gd
## Antes: python tools/art/env_kit/process_textures.py (texturas) e `godot --headless --import`.
## Catálogo e regras de uso: docs/arte-cenario.md

const OUT := "res://assets/environment/painted"
const TEX := OUT + "/textures/"
const CARDS := OUT + "/cards/"
const SH_TERRAIN := preload("res://assets/shaders/env_terrain.gdshader")
const SH_FOLIAGE := preload("res://assets/shaders/env_foliage.gdshader")
const SH_PAINTED := preload("res://assets/shaders/env_painted.gdshader")
const SH_PAINTED_2S := preload("res://assets/shaders/env_painted_2s.gdshader")
const SH_WATER := preload("res://assets/shaders/env_water.gdshader")

var mats: Dictionary = {}
var noise_tex: NoiseTexture2D


func _initialize() -> void:
	for d: String in ["materials", "meshes"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/" + d))
	_make_noise()
	_make_materials()
	_make_trees()
	_make_small()
	_make_props()
	_make_variants()
	_save(EnvLook.make_environment("day"), "env_warm_day.tres")
	_save(EnvLook.make_environment("city"), "env_warm_city.tres")
	print("env_kit: ok")
	quit(0)


func _tex(path: String) -> Texture2D:
	var t: Texture2D = load(path)
	if t == null:
		push_error("textura ausente: " + path)
	return t


func _save(res: Resource, name: String) -> Resource:
	var path := OUT + "/" + name
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("falhou salvar %s: %d" % [path, err])
	res.take_over_path(path)
	return load(path)


func _make_noise() -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 4
	n.seed = 7
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.generate_mipmaps = true
	noise_tex.noise = n
	noise_tex = _save(noise_tex, "materials/tex_env_noise.tres")


# ---------------------------------------------------------------- materiais

func _painted(name: String, tex: String, tint: Color, extra: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_PAINTED
	m.set_shader_parameter(&"albedo_tex", _tex(TEX + tex))
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"tex_noise", noise_tex)
	for k: String in extra:
		m.set_shader_parameter(StringName(k), extra[k])
	mats[name] = _save(m, "materials/mat_%s.tres" % name)
	return mats[name]


func _foliage(name: String, tex: String, tint: Color, extra: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_FOLIAGE
	m.set_shader_parameter(&"albedo_tex", _tex(tex))
	m.set_shader_parameter(&"tint", tint)
	for k: String in extra:
		m.set_shader_parameter(StringName(k), extra[k])
	mats[name] = _save(m, "materials/mat_%s.tres" % name)
	return mats[name]


func _make_materials() -> void:
	# Terreno (camadas pintadas; o mapa de mistura é por cena — ver PaintedTerrain).
	var t := ShaderMaterial.new()
	t.shader = SH_TERRAIN
	for kv: Array in [["tex_grass", "tex_grass"], ["tex_grass_alt", "tex_grass_lush"], ["tex_dirt", "tex_dirt"],
			["tex_cobble", "tex_cobble"], ["tex_sand", "tex_sand"], ["tex_rock", "tex_rock"]]:
		t.set_shader_parameter(StringName(kv[0]), _tex(TEX + kv[1] + ".png"))
	t.set_shader_parameter(&"tex_noise", noise_tex)
	t.set_shader_parameter(&"splat_source", 0)
	mats["terrain"] = _save(t, "materials/mat_terrain.tres")

	# Construções (cal quente — nunca azulada —, telha de barro, madeira, azulejo, pedra).
	_painted("plaster_warm", "tex_plaster.png", Color(1.0, 0.95, 0.86),
			{"triplanar": true, "tile_m": 3.0, "grime_height": 0.9, "grime_color": Color(0.78, 0.62, 0.46)})
	_painted("plaster_ochre", "tex_plaster.png", Color(1.0, 0.82, 0.55),
			{"triplanar": true, "tile_m": 3.0, "grime_height": 0.9, "grime_color": Color(0.75, 0.58, 0.42)})
	_painted("plaster_rose", "tex_plaster.png", Color(1.0, 0.80, 0.74),
			{"triplanar": true, "tile_m": 3.0, "grime_height": 0.9, "grime_color": Color(0.75, 0.58, 0.46)})
	_painted("roof_clay", "tex_roof_canal.png", Color(1.0, 0.9, 0.84), {"uv_scale": Vector2(1.0, 1.0), "macro_strength": 0.18})
	_painted("paving", "tex_paving.png", Color(1.0, 0.97, 0.92), {"triplanar": true, "tile_m": 4.0, "macro_strength": 0.16})
	_painted("wood", "tex_wood.png", Color(0.95, 0.88, 0.80), {"uv_scale": Vector2(0.8, 0.8)})
	_painted("wood_dark", "tex_wood.png", Color(0.62, 0.50, 0.42), {"uv_scale": Vector2(0.8, 0.8)})
	_painted("azulejo", "tex_azulejo.png", Color(1.0, 0.98, 0.94), {"triplanar": true, "tile_m": 1.6, "macro_strength": 0.05})
	_painted("stonewall", "tex_stonewall.png", Color(1.0, 0.96, 0.9), {"triplanar": true, "tile_m": 2.5})
	_painted("cobble_wall", "tex_cobble.png", Color(1.0, 0.97, 0.92), {"triplanar": true, "tile_m": 2.5})
	var moss: Texture2D = _tex(TEX + "tex_grass_lush.png")
	_painted("rock_moss", "tex_rock.png", Color(1.0, 0.97, 0.92),
			{"triplanar": true, "tile_m": 2.2, "top_tex": moss, "top_amount": 0.3, "top_tile_m": 1.5,
			"top_tint": Color(0.95, 1.0, 0.8)})
	_painted("rock", "tex_rock.png", Color(1.0, 0.97, 0.92), {"triplanar": true, "tile_m": 2.2})
	_painted("bark", "tex_bark.png", Color(0.95, 0.85, 0.78), {"uv_scale": Vector2(1.0, 1.0), "macro_strength": 0.05})
	_painted("metal", "tex_rock.png", Color(0.42, 0.40, 0.40), {"triplanar": true, "tile_m": 1.0, "roughness": 0.6})

	# Copas (malhas opacas com textura pintada) e cards recortados.
	_foliage("needles", TEX + "tex_needles.png", Color(0.92, 1.0, 0.86),
			{"use_alpha": false, "uv_scale": Vector2(1.0, 1.0), "wind_strength": 0.06, "backlight_color": Color(0.35, 0.42, 0.12)})
	_foliage("needles_b", TEX + "tex_needles_b.png", Color(0.95, 1.0, 0.86),
			{"use_alpha": false, "wind_strength": 0.06, "backlight_color": Color(0.35, 0.42, 0.12)})
	_foliage("canopy_broad", TEX + "tex_grass_lush.png", Color(0.9, 1.0, 0.8),
			{"use_alpha": false, "uv_scale": Vector2(1.8, 1.8), "wind_strength": 0.05})
	_foliage("canopy_ipe", TEX + "tex_ipe_bloom.png", Color(1.0, 0.95, 0.8),
			{"use_alpha": false, "uv_scale": Vector2(1.6, 1.6), "wind_strength": 0.05, "backlight_color": Color(0.55, 0.42, 0.10)})
	_foliage("card_conifer", CARDS + "card_conifer_tuft.png", Color(0.95, 1.0, 0.88),
			{"alpha_cut": 0.45, "wind_strength": 0.08})
	_foliage("card_conifer_b", CARDS + "card_conifer_tuft_b.png", Color(0.95, 1.0, 0.88),
			{"alpha_cut": 0.45, "wind_strength": 0.08})
	_foliage("card_broad", CARDS + "card_broad_clump.png", Color(0.95, 1.0, 0.88), {"alpha_cut": 0.45, "wind_strength": 0.07})
	_foliage("card_ipe", CARDS + "card_ipe_clump.png", Color(1.0, 1.0, 1.0),
			{"alpha_cut": 0.45, "wind_strength": 0.07, "backlight_color": Color(0.55, 0.42, 0.10)})
	var grass_extra := {"alpha_cut": 0.4, "wind_strength": 0.10, "wind_speed": 1.8, "base_darken": 0.55,
			"base_color": Color(0.36, 0.44, 0.16), "use_instance_custom": true, "fade_start": 40.0, "fade_end": 48.0}
	_foliage("card_grass", CARDS + "card_grass_tuft.png", Color(0.78, 0.86, 0.62), grass_extra)
	_foliage("card_grass_b", CARDS + "card_grass_tuft_b.png", Color(0.82, 0.9, 0.66), grass_extra)
	var flower_extra := grass_extra.duplicate()
	flower_extra["base_darken"] = 0.35
	_foliage("card_flowers", CARDS + "card_flowers.png", Color(1, 1, 1), flower_extra)
	_foliage("card_flowers_b", CARDS + "card_flowers_b.png", Color(1, 1, 1), flower_extra)
	var mush := grass_extra.duplicate()
	mush["wind_strength"] = 0.0
	mush["base_darken"] = 0.25
	var reeds_extra := grass_extra.duplicate()
	reeds_extra["base_darken"] = 0.3
	_foliage("card_reeds_real", CARDS + "card_reeds.png", Color(1, 1, 1), reeds_extra)
	_foliage("card_mushrooms", CARDS + "card_mushrooms.png", Color(1, 1, 1), mush)
	_foliage("card_mushrooms_b", CARDS + "card_mushrooms_b.png", Color(1, 1, 1), mush)


# ---------------------------------------------------------------- árvores

func _mesh_save(mesh: ArrayMesh, name: String) -> void:
	var total := 0
	for s in mesh.get_surface_count():
		total += mesh.surface_get_array_len(s)
	_save(mesh, "meshes/%s.res" % name)
	print("  %-22s superfícies=%d vértices=%d" % [name, mesh.get_surface_count(), total])


func _make_trees() -> void:
	var specs := [
		["tree_conifer_a", 7.5, 2.6, 5, 11, 101, "needles"],
		["tree_conifer_b", 9.0, 3.0, 6, 12, 202, "needles_b"],
		["tree_conifer_c", 5.5, 2.1, 4, 10, 303, "needles"],
	]
	for s: Array in specs:
		_mesh_save(_conifer(s[1], s[2], s[3], s[4], s[5], s[6]), s[0])
	_mesh_save(_broadleaf(6.0, 2.6, 404, "canopy_broad", "card_broad", 1.0), "tree_broadleaf_a")
	_mesh_save(_broadleaf(7.0, 3.2, 505, "canopy_ipe", "card_ipe", 1.0), "tree_ipe_yellow_a")
	_mesh_save(_broadleaf(13.0, 6.5, 606, "canopy_ipe", "card_ipe", 1.6), "tree_ipe_yellow_giant")
	_mesh_save(_bush(1.1, 707, "canopy_broad", "card_broad"), "bush_round_a")
	_mesh_save(_bush(0.8, 808, "needles", "card_conifer"), "bush_conifer_a")


func _conifer(h: float, r: float, tiers: int, segs: int, seed_: int, needles: String) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var mesh := ArrayMesh.new()
	var trunk := PaintedGeo.Builder.new()
	var crown := PaintedGeo.Builder.new()
	var cards := PaintedGeo.Builder.new()
	var base_y := h * 0.14
	PaintedGeo.cylinder(trunk, Vector3.ZERO + Vector3.DOWN * 0.2, Vector3(0, h * 0.5, 0), r * 0.13, r * 0.06, 8,
			0.45, 0.8, 0.0, 0.2, 2.0, 0.7)
	# raízes rasas
	for i in 4:
		var a := i * TAU / 4.0 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		PaintedGeo.cylinder(trunk, d * r * 0.05 + Vector3.UP * 0.25, d * r * 0.28 + Vector3.DOWN * 0.08,
				r * 0.07, r * 0.02, 5, 0.6, 0.5, 0.0, 0.0, 1.0, 0.7)
	var sc := Vector3(0, h * 0.5, 0)
	for t in tiers:
		var f := float(t) / (tiers - 1)
		var tier_r := r * lerpf(1.0, 0.28, pow(f, 0.9)) * rng.randf_range(0.93, 1.07)
		var y0 := lerpf(base_y, h * 0.80, f)
		var th := lerpf(h * 0.30, h * 0.24, f)
		var center := Vector3(rng.randf_range(-0.08, 0.08), y0, rng.randf_range(-0.08, 0.08))
		PaintedGeo.conifer_skirt(crown, center, y0, th, tier_r, segs + (t % 2), rng, sc, h)
		# tufos (cards) na borda da saia: silhueta fofa e serrilhada
		var n_cards := int(tier_r * 9.0) + 5
		for c in n_cards:
			var a := float(c) / n_cards * TAU + rng.randf_range(-0.2, 0.2)
			var d := Vector3(cos(a), 0, sin(a))
			var p := center + d * tier_r * rng.randf_range(0.8, 1.0) + Vector3.UP * th * rng.randf_range(0.0, 0.18)
			var ao := lerpf(0.72, 1.0, f) * rng.randf_range(0.9, 1.05)
			PaintedGeo.card(cards, p, d, tier_r * rng.randf_range(0.36, 0.52), rng.randf_range(-0.3, 0.3), sc, ao,
					clampf(p.y / h, 0.2, 1.0), 0.5)
	# ponta
	PaintedGeo.card(cards, Vector3(0, h * 0.97, 0), Vector3(0.01, 1, 0), r * 0.45, 0.0, sc, 1.05, 1.0, 0.0)
	trunk.commit_to(mesh, mats["bark"])
	crown.commit_to(mesh, mats[needles])
	cards.commit_to(mesh, mats["card_conifer" if needles == "needles" else "card_conifer_b"])
	return mesh


func _broadleaf(h: float, r: float, seed_: int, canopy: String, card_mat: String, card_scale: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var mesh := ArrayMesh.new()
	var trunk := PaintedGeo.Builder.new()
	var crown := PaintedGeo.Builder.new()
	var cards := PaintedGeo.Builder.new()
	var crown_c := Vector3(0, h * 0.64, 0)
	var crown_bottom := h * 0.36
	var crown_top := h
	# tronco levemente torto + galhos principais até os blobs
	var mid := Vector3(rng.randf_range(-0.3, 0.3), h * 0.35, rng.randf_range(-0.3, 0.3)) * Vector3(r * 0.3, 1, r * 0.3)
	PaintedGeo.cylinder(trunk, Vector3.DOWN * 0.2, mid, r * 0.11, r * 0.08, 9, 0.45, 0.8, 0.0, 0.1, 2.0, 0.6)
	var blobs: Array = []
	var n_blobs := 7 + int(r)
	for i in n_blobs:
		var a := float(i) / n_blobs * TAU + rng.randf_range(-0.3, 0.3)
		var rr := r * rng.randf_range(0.35, 0.72)
		var y := h * rng.randf_range(0.52, 0.80)
		blobs.append([Vector3(cos(a) * rr, y, sin(a) * rr), r * rng.randf_range(0.42, 0.58)])
	blobs.append([Vector3(0, h * 0.84, 0), r * 0.6])
	blobs.append([Vector3(rng.randf_range(-0.3, 0.3), h * 0.66, 0), r * 0.62])
	for b: Array in blobs:
		var bp: Vector3 = b[0]
		PaintedGeo.cylinder(trunk, mid, bp.lerp(mid, 0.25), r * 0.07, r * 0.03, 6, 0.6, 0.75, 0.1, 0.5, 1.0, 0.6)
		PaintedGeo.blob(crown, bp, float(b[1]) * 0.8, Vector3(1.0, 0.78, 1.0), rng, crown_c, crown_bottom, crown_top, h)
		# cards de ramalhete na superfície (silhueta recortada)
		var n_cards := int(float(b[1]) * 5.5 * card_scale) + 4
		for c in n_cards:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1.0), rng.randf_range(-1, 1)).normalized()
			var p: Vector3 = bp + dir * float(b[1]) * Vector3(1.0, 0.78, 1.0) * rng.randf_range(0.8, 0.95)
			var out_dir := (p - crown_c).normalized()
			var h_rel := clampf((p.y - crown_bottom) / (crown_top - crown_bottom), 0.0, 1.0)
			PaintedGeo.card(cards, p, out_dir, minf(float(b[1]) * rng.randf_range(0.6, 0.9), 2.4),
					rng.randf_range(-PI, PI), crown_c, lerpf(0.6, 1.05, h_rel), clampf(p.y / h, 0.3, 1.0), 0.3)
	trunk.commit_to(mesh, mats["bark"])
	crown.commit_to(mesh, mats[canopy])
	cards.commit_to(mesh, mats[card_mat])
	return mesh


func _bush(r: float, seed_: int, canopy: String, card_mat: String) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var mesh := ArrayMesh.new()
	var crown := PaintedGeo.Builder.new()
	var cards := PaintedGeo.Builder.new()
	var cc := Vector3(0, r * 0.45, 0)
	for i in 4:
		var a := i * TAU / 4.0 + rng.randf_range(-0.4, 0.4)
		var p := Vector3(cos(a) * r * 0.4, r * rng.randf_range(0.35, 0.55), sin(a) * r * 0.4)
		PaintedGeo.blob(crown, p, r * rng.randf_range(0.5, 0.65), Vector3(1, 0.8, 1), rng, cc, 0.0, r * 1.1, r * 1.1, 5, 9)
	for c in 14:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 1.0), rng.randf_range(-1, 1)).normalized()
		var p := cc + dir * r * Vector3(0.9, 0.6, 0.9)
		PaintedGeo.card(cards, p, dir, r * rng.randf_range(0.6, 0.85), rng.randf_range(-PI, PI), cc,
				lerpf(0.65, 1.0, dir.y), 0.6, 0.3)
	crown.commit_to(mesh, mats[canopy])
	cards.commit_to(mesh, mats[card_mat])
	return mesh


# ---------------------------------------------------------------- capim, flores, cogumelos (MultiMesh)

func _make_small() -> void:
	var specs := [
		["grass_tuft", "card_grass", 0.6, 0.38, 2],
		["grass_tuft_b", "card_grass_b", 0.8, 0.6, 2],
		["flowers", "card_flowers", 0.7, 0.62, 2],
		["flowers_b", "card_flowers_b", 0.7, 0.62, 2],
		["mushrooms", "card_mushrooms", 0.5, 0.48, 2],
		["mushrooms_b", "card_mushrooms_b", 0.5, 0.48, 2],
		["reeds_card", "card_reeds_real", 0.9, 1.15, 3],
	]
	for s: Array in specs:
		var mesh := ArrayMesh.new()
		var b := PaintedGeo.Builder.new()
		PaintedGeo.tuft(b, Vector3.ZERO, s[2], s[3], s[4], 0.0)
		b.commit_to(mesh, mats[s[1]])
		_mesh_save(mesh, s[0])


# ---------------------------------------------------------------- props

func _make_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	# Caixote de madeira: estrutura + tábuas
	var m := ArrayMesh.new()
	var w := PaintedGeo.Builder.new()
	var d := PaintedGeo.Builder.new()
	PaintedGeo.box(w, Vector3(0, 0.4, 0), Vector3(0.78, 0.78, 0.78), 0.55, 1.0)
	for e: Vector3 in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		PaintedGeo.box(d, Vector3(e.x * 0.39, 0.41, e.z * 0.39), Vector3(0.1, 0.82, 0.1), 0.5, 0.95)
	for y: float in [0.06, 0.76]:
		PaintedGeo.box(d, Vector3(0, y, 0.4), Vector3(0.84, 0.1, 0.05), 0.6, 0.95)
		PaintedGeo.box(d, Vector3(0, y, -0.4), Vector3(0.84, 0.1, 0.05), 0.6, 0.95)
		PaintedGeo.box(d, Vector3(0.4, y, 0), Vector3(0.05, 0.1, 0.84), 0.6, 0.95)
		PaintedGeo.box(d, Vector3(-0.4, y, 0), Vector3(0.05, 0.1, 0.84), 0.6, 0.95)
	PaintedGeo.box(d, Vector3(0, 0.41, 0.41), Vector3(0.08, 0.95, 0.04), 0.6, 0.95, Basis(Vector3.BACK, 0.78))
	w.commit_to(m, mats["wood"])
	d.commit_to(m, mats["wood_dark"])
	_mesh_save(m, "prop_crate")

	# Barril: aduelas (perfil abaulado) + aros de metal
	m = ArrayMesh.new()
	w = PaintedGeo.Builder.new()
	var met := PaintedGeo.Builder.new()
	var prof: Array = []
	for i in 9:
		var t := float(i) / 8.0
		prof.append([t * 1.0, 0.34 + sin(t * PI) * 0.07, lerpf(0.6, 1.0, t)])
	PaintedGeo.lathe(w, Vector3.ZERO, prof, 14, 3.0, 1.0, true, 0.85)
	for y: float in [0.14, 0.86]:
		var r := 0.34 + sin(y * PI) * 0.07 + 0.012
		PaintedGeo.lathe(met, Vector3.ZERO, [[y - 0.04, r, 0.8], [y + 0.04, r, 0.9]], 14, 2.0, 1.0, false)
	w.commit_to(m, mats["wood"])
	met.commit_to(m, mats["metal"])
	_mesh_save(m, "prop_barrel")

	# Cerca de madeira (segmento de 2 m): 2 postes + 2 travessas
	m = ArrayMesh.new()
	w = PaintedGeo.Builder.new()
	for x: float in [-1.0, 1.0]:
		PaintedGeo.box(w, Vector3(x, 0.5, 0), Vector3(0.14, 1.0, 0.14), 0.55, 1.0)
	for y: float in [0.45, 0.8]:
		PaintedGeo.box(w, Vector3(0, y, 0), Vector3(2.1, 0.1, 0.06), 0.8, 1.0,
				Basis(Vector3.BACK, rng.randf_range(-0.03, 0.03)))
	w.commit_to(m, mats["wood_dark"])
	_mesh_save(m, "prop_fence")

	# Pedras com musgo
	var rock_specs := [["rock_moss_a", Vector3(1.4, 0.9, 1.1)], ["rock_moss_b", Vector3(0.7, 0.45, 0.6)],
			["rock_moss_c", Vector3(2.4, 1.5, 1.9)]]
	for rs: Array in rock_specs:
		m = ArrayMesh.new()
		w = PaintedGeo.Builder.new()
		PaintedGeo.rock(w, Vector3.ZERO, rs[1], rng)
		w.commit_to(m, mats["rock_moss"])
		_mesh_save(m, rs[0])

	# Tronco caído e toco
	m = ArrayMesh.new()
	w = PaintedGeo.Builder.new()
	PaintedGeo.lathe(w, Vector3(-1.1, 0.26, 0), [[0.0, 0.26, 0.6], [2.2, 0.22, 0.75]], 10, 2.0, 0.6, true, 0.9,
			Basis(Vector3.BACK, -PI / 2.0))
	w.commit_to(m, mats["bark"])
	_mesh_save(m, "prop_log")
	m = ArrayMesh.new()
	w = PaintedGeo.Builder.new()
	PaintedGeo.lathe(w, Vector3.ZERO, [[-0.1, 0.42, 0.5], [0.12, 0.33, 0.7], [0.5, 0.3, 0.9]], 10, 2.0, 0.8, true, 1.0)
	w.commit_to(m, mats["bark"])
	_mesh_save(m, "prop_stump")


# ---------------------------------------------------------------- variantes (outras regiões/nações)

func _tint_of(base: String, name: String, tint: Color, extra: Dictionary = {}) -> ShaderMaterial:
	var m: ShaderMaterial = (mats[base] as ShaderMaterial).duplicate()
	m.set_shader_parameter(&"tint", tint)
	for k: String in extra:
		m.set_shader_parameter(StringName(k), extra[k])
	mats[name] = _save(m, "materials/mat_%s.tres" % name)
	return mats[name]


## Cópia da malha do kit com materiais trocados por superfície ({índice: nome do material}).
func _variant(src: String, name: String, surf: Dictionary) -> void:
	var m: ArrayMesh = (load(OUT + "/meshes/%s.res" % src) as ArrayMesh).duplicate(true)
	for i: int in surf:
		m.surface_set_material(i, mats[surf[i]])
	_mesh_save(m, name)


func _make_variants() -> void:
	# chãos extras (texturas próprias) e materiais genéricos
	for kv: Array in [["snow", Color(1, 1, 1)], ["red_earth", Color(1, 1, 1)], ["gravel", Color(1, 1, 1)],
			["ice", Color(1, 1, 1)], ["dry_grass", Color(1, 1, 1)], ["jungle_floor", Color(1, 1, 1)],
			["sand", Color(1, 1, 1)], ["dirt", Color(0.93, 0.8, 0.64)], ["paving", Color(1, 1, 1)]]:
		_painted("ground_" + kv[0], "tex_%s.png" % kv[0], kv[1], {"triplanar": true, "tile_m": 5.0, "macro_strength": 0.16,
				"detail": 0.85})
	_painted("thatch", "tex_thatch.png", Color(1, 0.95, 0.85), {"uv_scale": Vector2(0.5, 0.5)})
	var w := ShaderMaterial.new()
	w.shader = SH_WATER
	w.set_shader_parameter(&"tex_noise", noise_tex)
	mats["water"] = _save(w, "materials/mat_water.tres")
	var c := ShaderMaterial.new()
	c.shader = SH_PAINTED_2S
	c.set_shader_parameter(&"albedo_tex", _tex(TEX + "tex_plaster.png"))
	c.set_shader_parameter(&"tex_noise", noise_tex)
	c.set_shader_parameter(&"detail", 0.6)
	mats["cloth"] = _save(c, "materials/mat_cloth.tres")
	# folhagem tingida
	_tint_of("canopy_ipe", "canopy_ipe_purple", Color(0.78, 0.55, 1.05))
	_tint_of("card_ipe", "card_ipe_purple", Color(0.8, 0.55, 1.1))
	_tint_of("canopy_ipe", "canopy_sakura", Color(1.05, 0.72, 0.8))
	_tint_of("card_ipe", "card_sakura", Color(1.1, 0.75, 0.85))
	_tint_of("canopy_broad", "canopy_olive", Color(0.72, 0.85, 0.7))
	_tint_of("card_broad", "card_olive", Color(0.75, 0.88, 0.72))
	_tint_of("canopy_broad", "canopy_birch", Color(1.05, 1.1, 0.75))
	_tint_of("card_broad", "card_birch", Color(1.05, 1.1, 0.72))
	_tint_of("canopy_broad", "canopy_jungle", Color(0.62, 0.78, 0.6))
	_tint_of("card_broad", "card_jungle", Color(0.62, 0.8, 0.6))
	_tint_of("canopy_broad", "canopy_dry", Color(1.0, 0.9, 0.55))
	_tint_of("card_broad", "card_dry", Color(1.0, 0.9, 0.55))
	_tint_of("needles", "needles_snow", Color(0.95, 1.0, 1.05))
	_tint_of("card_conifer", "card_conifer_snow", Color(1.0, 1.05, 1.1))
	_tint_of("bark", "bark_birch", Color(1.5, 1.45, 1.35))
	_tint_of("card_grass", "card_grass_golden", Color(1.1, 0.95, 0.55))
	_tint_of("card_grass_b", "card_reeds", Color(0.7, 0.85, 0.55))
	_tint_of("card_grass_b", "card_fern", Color(0.55, 0.78, 0.5))
	_tint_of("card_flowers", "card_flowers_purple", Color(0.85, 0.7, 1.1))
	_tint_of("rock", "rock_red", Color(1.1, 0.72, 0.55))
	_tint_of("canopy_broad", "palm_leaf", Color(0.85, 1.0, 0.7), {"wind_strength": 0.08})
	_tint_of("canopy_broad", "palm_leaf_dark", Color(0.6, 0.8, 0.55), {"wind_strength": 0.08})
	_painted("termite", "tex_red_earth.png", Color(1, 1, 1), {"triplanar": true, "tile_m": 2.0})
	_painted("bamboo", "tex_bark.png", Color(0.75, 1.1, 0.55), {"uv_scale": Vector2(1.0, 1.0)})
	# árvores (superfícies: 0 tronco, 1 copa, 2 cards)
	_variant("tree_ipe_yellow_a", "tree_ipe_purple_a", {1: "canopy_ipe_purple", 2: "card_ipe_purple"})
	_variant("tree_ipe_yellow_a", "tree_sakura_a", {1: "canopy_sakura", 2: "card_sakura"})
	_variant("tree_broadleaf_a", "tree_olive_a", {1: "canopy_olive", 2: "card_olive"})
	_variant("tree_broadleaf_a", "tree_birch_a", {0: "bark_birch", 1: "canopy_birch", 2: "card_birch"})
	_variant("tree_broadleaf_a", "tree_jungle_a", {1: "canopy_jungle", 2: "card_jungle"})
	_variant("tree_broadleaf_a", "tree_pequi_a", {1: "canopy_dry", 2: "card_dry"})
	_variant("tree_conifer_a", "tree_conifer_snow_a", {1: "needles_snow", 2: "card_conifer_snow"})
	_variant("bush_round_a", "bush_dry_a", {0: "canopy_dry", 1: "card_dry"})
	_variant("bush_round_a", "bush_olive_a", {0: "canopy_olive", 1: "card_olive"})
	_variant("bush_round_a", "bush_jungle_a", {0: "canopy_jungle", 1: "card_jungle"})
	_variant("bush_conifer_a", "bush_snow_a", {0: "needles_snow", 1: "card_conifer_snow"})
	_variant("grass_tuft", "grass_golden", {0: "card_grass_golden"})
	_variant("grass_tuft_b", "reeds", {0: "card_reeds"})
	_variant("grass_tuft_b", "fern", {0: "card_fern"})
	_variant("flowers", "flowers_purple", {0: "card_flowers_purple"})
	_variant("rock_moss_b", "rock_red_a", {0: "rock_red"})
	_variant("rock_moss_a", "rock_grey_a", {0: "rock"})
	# palmeiras (tamareira e buriti), bambu, cupinzeiro
	for spec: Array in [["palm_date_a", 6.5, false, 11, 3.2, 111], ["palm_buriti_a", 8.0, true, 14, 2.6, 222]]:
		var rng := RandomNumberGenerator.new()
		rng.seed = spec[5]
		var mesh := ArrayMesh.new()
		var trunk := PaintedGeo.Builder.new()
		var leaves := PaintedGeo.Builder.new()
		var leaves_b := PaintedGeo.Builder.new()
		var h: float = spec[1]
		var top := Vector3(0.5, h, 0.2)
		PaintedGeo.curved_trunk(trunk, Vector3.DOWN * 0.2, top, Vector3(0.6, 0, 0.2), 0.3, 0.2, 6)
		var n: int = spec[3]
		for i in n:
			var a := TAU * i / n + rng.randf_range(-0.15, 0.15)
			var dir := Vector3(cos(a), 0, sin(a))
			PaintedGeo.palm_frond(leaves if i % 2 == 0 else leaves_b, top, dir, float(spec[4]) * rng.randf_range(0.85, 1.1),
					0.5 if not spec[2] else 0.42, 0.55 if not spec[2] else 0.2, 7, spec[2], top, h)
		trunk.commit_to(mesh, mats["bark"])
		leaves.commit_to(mesh, mats["palm_leaf"])
		leaves_b.commit_to(mesh, mats["palm_leaf_dark"])
		_mesh_save(mesh, spec[0])
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 333
	var bm := ArrayMesh.new()
	var stems := PaintedGeo.Builder.new()
	var tops := PaintedGeo.Builder.new()
	for i in 7:
		var p := Vector3(rng2.randf_range(-0.5, 0.5), 0, rng2.randf_range(-0.5, 0.5))
		var hh := rng2.randf_range(2.2, 3.4)
		var tip := p + Vector3(rng2.randf_range(-0.3, 0.3), hh, rng2.randf_range(-0.3, 0.3))
		PaintedGeo.cylinder(stems, p, tip, 0.06, 0.045, 6, 0.6, 1.0, 0.0, 1.0, 1.0, 2.0)
		for k in 3:
			var dir := Vector3(rng2.randf_range(-1, 1), 0.3, rng2.randf_range(-1, 1)).normalized()
			PaintedGeo.card(tops, p.lerp(tip, rng2.randf_range(0.55, 1.0)), dir, rng2.randf_range(0.6, 0.9),
					rng2.randf_range(-PI, PI), Vector3(0, hh * 0.7, 0), 1.0, 1.0, 0.2)
	stems.commit_to(bm, mats["bamboo"])
	tops.commit_to(bm, mats["card_reeds"])
	_mesh_save(bm, "bamboo_clump_a")
	var tm := ArrayMesh.new()
	var tb := PaintedGeo.Builder.new()
	PaintedGeo.lathe(tb, Vector3.ZERO, [[-0.1, 0.9, 0.55], [0.4, 0.75, 0.7], [1.0, 0.45, 0.85], [1.6, 0.3, 0.95], [2.1, 0.12, 1.0]],
			10, 2.0, 0.8, true, 1.0)
	PaintedGeo.lathe(tb, Vector3(0.55, 0, 0.1), [[-0.1, 0.35, 0.6], [0.6, 0.25, 0.8], [1.1, 0.08, 0.95]], 8, 1.0, 0.8, true, 1.0)
	tb.commit_to(tm, mats["termite"])
	_mesh_save(tm, "termite_mound_a")
