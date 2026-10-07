class_name CharacterLayers
extends RefCounted
## Montagem do personagem personalizado em camadas (GDD §6.1, §17.4; contrato ADENDO 2) — lógica reutilizável
## pela prévia 2D (LayeredCharacterPreview) e pelo renderizador do mundo (Sprite3D).
##
## Camadas do jogador, de trás para frente (só as de personalização; equipamentos continuam do ADENDO 1):
##   corpo-base  assets/characters/base/chr_<body>_base_<anim>.png  (+ chr_<body>_base_mask_<anim>.png)
##   olhos       assets/characters/eyes/<body>_<anim>.png           (tools/art/customization/eyes.py; pele/íris
##               codificadas, MODE_EYES; <body>_idle_blink.png = olho fechado para piscar)
##   cabelo      assets/characters/hair/<style>/<body>_<anim>.png   (rampa de cinza; "buzz" = sem folha)
##   rosto       assets/characters/face/<id>/<body>_<anim>.png      (brincos; cores próprias)
## Todas as folhas: quadro 96x96, linhas S/SE/L/NE/N, mesmas colunas das folhas chr_traveler_* (idle 4,
## walk 8, sit 1), mesmos quadros, mesmo espelhamento (SO/O/NO = SE/L/NE espelhados).
##
## Cor: shader assets/shaders/char_palette_swap.gdshader (2D) / char_palette_swap_3d.gdshader (Sprite3D),
## ou bake_sheet() na CPU (gera uma textura já colorida; útil se o renderizador não aceitar material).
##
## USO NO MUNDO (Sprite3D / DirectionalSprite3D) — passo a passo em tools/art/customization/README.md:
##   var specs := CharacterLayers.layer_specs(appearance)          # [{name, mode, sheets{anim:path}, masks{anim:path}}]
##   para cada spec: um Sprite3D (o corpo usa o sprite "Body"; cabelo/rosto viram overlays com order 1, 2)
##   sprite.texture = load(spec.sheets[anim])                     # a geometria/UV continuam do Sprite3D
##   sprite.material_override = CharacterLayers.make_material_3d(spec.mode, appearance)
##   CharacterLayers.set_sheet_3d(sprite.material_override, sprite.texture, mask_tex_or_null)  # a cada troca de anim

const SHADER_2D_PATH: String = "res://assets/shaders/char_palette_swap.gdshader"
const SHADER_3D_PATH: String = "res://assets/shaders/char_palette_swap_3d.gdshader"
const BASE_DIR: String = "res://assets/characters/base/"
const HAIR_DIR: String = "res://assets/characters/hair/"
const FACE_DIR: String = "res://assets/characters/face/"
const EYES_DIR: String = "res://assets/characters/eyes/"
## idle/walk/sit + combate (GDD §10.2.1, Agente A): as folhas que faltarem são omitidas.
const ANIMS: Array[StringName] = [&"idle", &"walk", &"sit", &"hit", &"attack_unarmed", &"attack_blade",
		&"attack_staff", &"attack_bow", &"cast", &"death"]
## Estilo sem folha própria: o cabelo curtinho já está no corpo-base (máscara B).
const STYLE_BUZZ: StringName = &"buzz"

const LAYER_BASE: StringName = &"Base"
const LAYER_HAIR: StringName = &"Hair"
const LAYER_OUTFIT: StringName = &"Outfit"
const LAYER_FACE: StringName = &"FaceAccessory"
## Olhos grandes em camada própria (GDD §17.4 camada 7), entre corpo/roupa e cabelo.
const LAYER_EYES: StringName = &"Eyes"
const OUTFIT_DIR: String = "res://assets/characters/outfits/"
## Roupa que já está desenhada no corpo-base (não gera camada).
const OUTFIT_BASE: StringName = &"traveler"
## Modos do shader.
## Recolor da roupa por nacionalidade: saturação mínima para ser "tecido" e brilho médio do tecido original.
const CLOTH_MIN_SAT: float = 0.2
const CLOTH_REF_L: float = 0.29
## Máscara com alfa 128 = zona da cabeça (tools/art/customization/cloth_zone.py): sem recolor.
const CLOTH_MIN_MASK_ALPHA: int = 191
const MODE_BASE: int = 0
const MODE_HAIR: int = 1
const MODE_PLAIN: int = 2
## Camada de olhos: (v,0,0) = pele, (0,v,0) = íris, resto literal (eyes.py).
const MODE_EYES: int = 3
## Codificação das rampas (tools/art/customization/common.py): tom i -> valor 8 bits i*STEP + STEP/2.
const STEP: int = 40
## Ordem sugerida das camadas em relação ao corpo (DirectionalSprite3D.add_overlay order).
const ORDER_EYES: int = 1
const ORDER_HAIR: int = 2
const ORDER_FACE: int = 3
## Piscar (cliente): olho fechado por BLINK_SEC a cada BLINK_MIN_SEC..BLINK_MAX_SEC, só no idle.
const BLINK_SEC: float = 0.12
const BLINK_MIN_SEC: float = 2.5
const BLINK_MAX_SEC: float = 5.5
const BLINK_ANIM: StringName = &"idle"

static var _shader_2d: Shader = null
static var _shader_3d: Shader = null
static var _bake_cache: Dictionary[String, Texture2D] = {}


static func base_sheet_path(body: StringName, anim: StringName) -> String:
	return "%schr_%s_base_%s.png" % [BASE_DIR, body, anim]


static func mask_sheet_path(body: StringName, anim: StringName) -> String:
	return "%schr_%s_base_mask_%s.png" % [BASE_DIR, body, anim]


static func hair_sheet_path(style: StringName, body: StringName, anim: StringName) -> String:
	return "%s%s/%s_%s.png" % [HAIR_DIR, style, body, anim]


## Roupa (ADENDO 1). ATENÇÃO: as folhas atuais de roupa são personagens inteiros (com cabelo/pele do
## Viajante); para ficarem por cima do corpo-base precisam ser refeitas "sobre o corpo-base raspado".
static func outfit_sheet_path(outfit: StringName, body: StringName, anim: StringName) -> String:
	return "%schr_%s_%s_%s.png" % [OUTFIT_DIR, body, outfit, anim]


## Mascara da folha de roupa (C3, pipeline 3D): com ela a roupa vira o CORPO recolorivel (pele/sobrancelha
## pela mascara, como o corpo-base) e olhos/cabelo/brinco vao por cima, iguais ao Viajante.
static func outfit_mask_path(outfit: StringName, body: StringName, anim: StringName) -> String:
	return "%schr_%s_%s_mask_%s.png" % [OUTFIT_DIR, body, outfit, anim]


## A roupa tem folhas de corpo inteiro com mascara (feitas sobre o mesmo esqueleto do corpo-base)?
static func outfit_has_body(outfit: StringName, body: StringName) -> bool:
	return outfit != &"" and outfit != OUTFIT_BASE and ResourceLoader.exists(outfit_mask_path(outfit, body, &"idle"))


static func face_sheet_path(id: StringName, body: StringName, anim: StringName) -> String:
	return "%s%s/%s_%s.png" % [FACE_DIR, id, body, anim]


static func eyes_sheet_path(body: StringName, anim: StringName) -> String:
	return "%s%s_%s.png" % [EYES_DIR, body, anim]


## Folha do idle com o olho fechado (piscar); "" se não existir.
static func eyes_blink_path(body: StringName) -> String:
	var p: String = "%s%s_%s_blink.png" % [EYES_DIR, body, BLINK_ANIM]
	return p if ResourceLoader.exists(p) else ""


## Próximo intervalo até piscar (s), com um pouco de acaso para os personagens não piscarem juntos.
static func next_blink_wait(rng: RandomNumberGenerator = null) -> float:
	return rng.randf_range(BLINK_MIN_SEC, BLINK_MAX_SEC) if rng != null else randf_range(BLINK_MIN_SEC, BLINK_MAX_SEC)


## Camadas de personalização da aparência, de trás para frente. Cada item:
## {name: StringName, mode: int, sheets: {anim: path}, masks: {anim: path} (só no corpo-base)}.
## Ordem: Base, Outfit (opcional), Eyes, Hair (se não raspado), FaceAccessory (se houver brinco).
## Só entram folhas que existem (sit é opcional).
static func layer_specs(appearance: Dictionary) -> Array[Dictionary]:
	var body: StringName = StringName(str(appearance.get(&"body", &"male")))
	var style: StringName = StringName(str(appearance.get(&"hair_style", &"")))
	var ear: StringName = StringName(str(appearance.get(&"earrings", &"")))
	var out: Array[Dictionary] = []
	var outfit: StringName = StringName(str(appearance.get(&"outfit", OUTFIT_BASE)))
	if outfit_has_body(outfit, body):
		# roupa de corpo inteiro com mascara: ela e o corpo-base desta aparencia
		out.append(_spec(LAYER_BASE, MODE_BASE, func(a: StringName) -> String: return outfit_sheet_path(outfit, body, a),
				func(a: StringName) -> String: return outfit_mask_path(outfit, body, a)))
	else:
		out.append(_spec(LAYER_BASE, MODE_BASE, func(a: StringName) -> String: return base_sheet_path(body, a),
				func(a: StringName) -> String: return mask_sheet_path(body, a)))
	if outfit != &"" and outfit != OUTFIT_BASE and not outfit_has_body(outfit, body):
		out.append(_spec(LAYER_OUTFIT, MODE_PLAIN, func(a: StringName) -> String: return outfit_sheet_path(outfit, body, a)))
	var eyes: Dictionary = _spec(LAYER_EYES, MODE_EYES, func(a: StringName) -> String: return eyes_sheet_path(body, a))
	if not (eyes[&"sheets"] as Dictionary).is_empty():
		out.append(eyes)
	if style != &"" and style != STYLE_BUZZ:
		out.append(_spec(LAYER_HAIR, MODE_HAIR, func(a: StringName) -> String: return hair_sheet_path(style, body, a)))
	if ear != &"":
		out.append(_spec(LAYER_FACE, MODE_PLAIN, func(a: StringName) -> String: return face_sheet_path(ear, body, a)))
	return out


static func _spec(layer_name: StringName, mode: int, sheet_of: Callable, mask_of: Callable = Callable()) -> Dictionary:
	var sheets: Dictionary[StringName, String] = {}
	var masks: Dictionary[StringName, String] = {}
	for a: StringName in ANIMS:
		var p: String = sheet_of.call(a)
		if ResourceLoader.exists(p):
			sheets[a] = p
			if mask_of.is_valid() and ResourceLoader.exists(mask_of.call(a)):
				masks[a] = mask_of.call(a)
	return {&"name": layer_name, &"mode": mode, &"sheets": sheets, &"masks": masks}


# --- Rampas ---------------------------------------------------------------------------------------

static func palettes() -> CustomizationPalettes:
	var o: CustomizationOptions = CustomizationOptions.get_default()
	return o.palettes if o != null else null


## {&"skin": PackedColorArray(6), &"hair": ..., &"eye": ...} da aparência.
static func ramps_for(appearance: Dictionary, pal: CustomizationPalettes = null) -> Dictionary:
	if pal == null:
		pal = palettes()
	if pal == null:
		return {}
	var out: Dictionary = {
		&"skin": pal.skin(int(appearance.get(&"skin", 0))),
		&"hair": pal.hair(int(appearance.get(&"hair_color", 0))),
		&"eye": pal.eye(int(appearance.get(&"eye_color", 0))),
	}
	var cloth: PackedColorArray = cloth_for(appearance)
	if not cloth.is_empty():
		out[&"cloth"] = cloth
	var arch: int = archetype_code_for(appearance)
	if arch > 0:
		out[&"archetype_mode"] = arch
	return out


## Código do arquétipo para shaders (1: Tanque, 2: Ágil/Lâmina, 3: Arcano, 4: Xamânico/Selvagem).
static func archetype_code_for(appearance: Dictionary) -> int:
	var direct: Variant = appearance.get(&"archetype", "")
	if direct is int and direct > 0:
		return int(direct)
	var direct_str: String = str(direct).to_lower()
	if direct_str == "tank": return 1
	if direct_str in ["blade", "bow", "agile"]: return 2
	if direct_str in ["arcane", "hybrid"]: return 3
	if direct_str in ["support", "shamanic", "shaman"]: return 4

	var title_id: StringName = StringName(str(appearance.get(&"title_look", "")))
	if not title_id.is_empty():
		var t: TitleDef = Content.title(title_id)
		if t != null and t.has_method(&"get_archetype_code"):
			var code: int = t.get_archetype_code()
			if code > 0:
				return code
		elif t != null and not t.archetype.is_empty():
			var arch_name: String = String(t.archetype).to_lower()
			if arch_name == "tank": return 1
			if arch_name in ["blade", "bow"]: return 2
			if arch_name in ["arcane", "hybrid"]: return 3
			if arch_name in ["support"]: return 4

	var outfit: String = str(appearance.get(&"outfit", "")).to_lower()
	if not outfit.is_empty():
		if "jabuti" in outfit or "anta" in outfit or "mapinguari" in outfit or "master_armor" in outfit or "tank" in outfit:
			return 1
		if "machete" in outfit or "aroeira" in outfit or "jaguar" in outfit or "cerrado" in outfit or "brejo" in outfit or "gaviao" in outfit or "leather_jerkin" in outfit or "blade" in outfit or "bow" in outfit:
			return 2
		if "firefly" in outfit or "crystal" in outfit or "boitata" in outfit or "ember" in outfit or "branch_coat" in outfit or "arcane" in outfit:
			return 3
		if "root" in outfit or "buriti" in outfit or "matinta" in outfit or "apprentice" in outfit or "support" in outfit or "shaman" in outfit:
			return 4

	return 0


## [tecido, detalhe] da roupa do Viajante (sem folha de roupa própria): o título exibido com cloth_colors vale
## por cima da nacionalidade.
static func cloth_for(appearance: Dictionary) -> PackedColorArray:
	var o: CustomizationOptions = CustomizationOptions.get_default()
	if o == null:
		return PackedColorArray()
	var outfit: StringName = StringName(str(appearance.get(&"outfit", OUTFIT_BASE)))
	if outfit != &"" and outfit != OUTFIT_BASE:
		return PackedColorArray()
	var title_id: StringName = StringName(str(appearance.get(&"title_look", "")))
	if not title_id.is_empty():
		var t: TitleDef = Content.title(title_id)
		if t != null and t.cloth_colors.size() >= 2:
			return t.cloth_colors
	return o.nationality_cloth(StringName(str(appearance.get(&"nationality", ""))))


static func _apply_ramps(mat: ShaderMaterial, mode: int, ramps: Dictionary) -> void:
	mat.set_shader_parameter(&"layer_mode", mode)
	for k: StringName in [&"skin", &"hair", &"eye"]:
		if ramps.has(k):
			mat.set_shader_parameter(StringName("%s_ramp" % k), ramps[k])
	var cloth: PackedColorArray = ramps.get(&"cloth", PackedColorArray())
	mat.set_shader_parameter(&"cloth_on", not cloth.is_empty())
	if not cloth.is_empty():
		mat.set_shader_parameter(&"cloth_color", cloth[0])
		mat.set_shader_parameter(&"accent_color", cloth[1])
	var arch: int = int(ramps.get(&"archetype_mode", 0))
	mat.set_shader_parameter(&"archetype_mode", arch)


# --- Materiais ------------------------------------------------------------------------------------

## Material 2D (CanvasItem: Sprite2D/TextureRect). mask_tex só no corpo-base.
static func make_material(mode: int, appearance: Dictionary, mask_tex: Texture2D = null) -> ShaderMaterial:
	if _shader_2d == null:
		_shader_2d = load(SHADER_2D_PATH) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shader_2d
	_apply_ramps(m, mode, ramps_for(appearance))
	if mask_tex != null:
		m.set_shader_parameter(&"mask_tex", mask_tex)
	return m


## Troca só as rampas de um material já criado (2D ou 3D).
static func update_material(mat: ShaderMaterial, mode: int, appearance: Dictionary) -> void:
	_apply_ramps(mat, mode, ramps_for(appearance))


## Material 3D para Sprite3D.material_override (faz o billboard eixo Y e o corte de alfa no shader).
static func make_material_3d(mode: int, appearance: Dictionary) -> ShaderMaterial:
	if _shader_3d == null:
		_shader_3d = load(SHADER_3D_PATH) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shader_3d
	_apply_ramps(m, mode, ramps_for(appearance))
	return m


## Chamar sempre que o Sprite3D trocar de folha (idle/walk/sit): o shader 3D lê a folha por uniform.
static func set_sheet_3d(mat: ShaderMaterial, sheet: Texture2D, mask: Texture2D = null) -> void:
	mat.set_shader_parameter(&"sheet_tex", sheet)
	if mask != null:
		mat.set_shader_parameter(&"mask_tex", mask)


# --- Recolorir na CPU (alternativa sem shader) ----------------------------------------------------

## Folha já colorida (ImageTexture), com cache por (folha, máscara, modo, rampas). Serve para qualquer
## renderizador que só aceite textura (ex.: DirectionalSprite3D.add_overlay com textura pronta).
static func bake_sheet(sheet_path: String, mode: int, appearance: Dictionary, mask_path: String = "") -> Texture2D:
	var ramps: Dictionary = ramps_for(appearance)
	var key: String = "%s|%s|%d|%s" % [sheet_path, mask_path, mode, str(ramps)]
	if _bake_cache.has(key):
		return _bake_cache[key]
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		return null
	var img: Image = tex.get_image()
	var mask: Image = null
	if mask_path != "" and ResourceLoader.exists(mask_path):
		mask = (load(mask_path) as Texture2D).get_image()
	var out := ImageTexture.create_from_image(bake_image(img, mode, ramps, mask))
	_bake_cache[key] = out
	return out


## Recolore uma imagem (mesma regra do shader). Imagens pequenas (768x480): ~0,1 s.
static func bake_image(img: Image, mode: int, ramps: Dictionary, mask: Image = null) -> Image:
	var src: Image = img.duplicate() as Image
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = src.get_data()
	var mdata := PackedByteArray()
	if mask != null:
		var mm: Image = mask.duplicate() as Image
		if mm.is_compressed():
			mm.decompress()
		mm.convert(Image.FORMAT_RGBA8)
		mdata = mm.get_data()
	if mode == MODE_BASE and mdata.size() != data.size():
		return src
	var tables: Array[PackedByteArray] = []
	for k: StringName in [&"skin", &"eye", &"hair"]:
		var t := PackedByteArray()
		var ramp: PackedColorArray = ramps.get(k, PackedColorArray())
		for i: int in CustomizationPalettes.MAX_TONES:
			var c: Color = ramp[mini(i, ramp.size() - 1)] if not ramp.is_empty() else Color.MAGENTA
			t.append(c.r8)
			t.append(c.g8)
			t.append(c.b8)
		tables.append(t)
	var cloth: PackedColorArray = ramps.get(&"cloth", PackedColorArray())
	var n: int = data.size()
	var i: int = 0
	while i < n:
		if data[i + 3] >= 128:
			var table: int = -1
			var v: int = 0
			if mode == MODE_HAIR:
				table = 2
				v = data[i]
			elif mode == MODE_EYES:
				if data[i + 1] == 0 and data[i + 2] == 0 and data[i] > 5:
					table = 0 # pele
					v = data[i]
				elif data[i] == 0 and data[i + 2] == 0 and data[i + 1] > 5:
					table = 1 # íris
					v = data[i + 1]
			elif mode == MODE_BASE:
				for ch: int in 3:
					if mdata[i + ch] > 5:
						table = ch # R = pele, G = olhos, B = cabelo raspado
						v = mdata[i + ch]
						break
			if table < 0 and mode == MODE_BASE and cloth.size() >= 2 and mdata[i + 3] > CLOTH_MIN_MASK_ALPHA:
				var rc: Color = recolor_cloth(Color8(data[i], data[i + 1], data[i + 2]), cloth)
				data[i] = rc.r8
				data[i + 1] = rc.g8
				data[i + 2] = rc.b8
			if table >= 0:
				var idx: int = mini(v / STEP, CustomizationPalettes.MAX_TONES - 1) * 3
				var t: PackedByteArray = tables[table]
				data[i] = t[idx]
				data[i + 1] = t[idx + 1]
				data[i + 2] = t[idx + 2]
			data[i + 3] = 255
		else:
			data[i + 3] = 0
		i += 4
	return Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8, data)


## Mesma regra do shader: tecido azul -> cloth[0], detalhe vermelho -> cloth[1]; brilho relativo preservado.
static func recolor_cloth(c: Color, cloth: PackedColorArray) -> Color:
	var h: float = c.h
	var s: float = c.s
	var l: float = (maxf(c.r, maxf(c.g, c.b)) + minf(c.r, minf(c.g, c.b))) * 0.5
	var hsl_s: float = 0.0 if l <= 0.0 or l >= 1.0 else (maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))) / (1.0 - absf(2.0 * l - 1.0))
	if hsl_s < CLOTH_MIN_SAT or l < 0.08 or l > 0.92:
		return c
	var target: Color
	if h >= 0.45 and h < 0.70:
		target = cloth[0]
	elif h < 0.09 or h > 0.90:
		target = cloth[1]
	else:
		return c
	var tl: float = (maxf(target.r, maxf(target.g, target.b)) + minf(target.r, minf(target.g, target.b))) * 0.5
	var ts: float = 0.0 if tl <= 0.0 or tl >= 1.0 else (maxf(target.r, maxf(target.g, target.b)) - minf(target.r, minf(target.g, target.b))) / (1.0 - absf(2.0 * tl - 1.0))
	var nl: float = clampf(tl + (l - CLOTH_REF_L) * 1.1, 0.04, 0.96)
	var ns: float = clampf(ts * (0.6 + 0.4 * hsl_s / 0.55), 0.0, 1.0)
	return _hsl(target.h, ns, nl)


static func _hsl(h: float, s: float, l: float) -> Color:
	var q: float = l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p: float = 2.0 * l - q
	return Color(_hue(p, q, h + 1.0 / 3.0), _hue(p, q, h), _hue(p, q, h - 1.0 / 3.0))


static func _hue(p: float, q: float, t: float) -> float:
	t = fposmod(t, 1.0)
	if t < 1.0 / 6.0:
		return p + (q - p) * 6.0 * t
	if t < 0.5:
		return q
	if t < 2.0 / 3.0:
		return p + (q - p) * (2.0 / 3.0 - t) * 6.0
	return p


static func clear_cache() -> void:
	_bake_cache.clear()
