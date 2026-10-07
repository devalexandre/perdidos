extends Node
## Teste da personalização (GDD §6.1, contrato ADENDO 2). Precisa de display (xvfb-run):
##   godot --path game --resolution 1920x1080 res://tests/client/test_customization.tscn -- --out=/caminho
## Checa dados/arquivos, validação (sanitize/is_valid), recolor na CPU, a prévia 2D (8 direções) e o shader
## 3D num Sprite3D; na tela de título: seções, "Aleatório", get_appearance() e play_requested (4 args).
## Capturas: custom_grid_WxH.png (prévias), custom_3d_WxH.png (Sprite3D), custom_title_WxH.png.

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")
const SETTLE_FRAMES: int = 8

var _out_dir: String = "user://"
var _failures: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Slots isolados: arquivo temporário vazio (modo criação), sem tocar no do jogador.
	CharacterSlots.path = OS.get_temp_dir().path_join("test_customization_slots_%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(CharacterSlots.path)
	var win: Vector2i = get_viewport().get_visible_rect().size
	_test_data()
	await _test_preview_grid(win)
	await _test_3d(win)
	await _test_title(win)
	await _test_touch_title(win)
	await _test_slot_title(win, false)
	await _test_slot_title(win, true)
	DirAccess.remove_absolute(CharacterSlots.path)
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _test_data() -> void:
	var o: CustomizationOptions = CustomizationOptions.get_default()
	_check(o != null and o.palettes != null, "options.tres + palettes.tres carregam")
	if o == null:
		return
	var p: CustomizationPalettes = o.palettes
	_check(p.skin_count() == 6 and p.hair_count() == 10 and p.eye_count() == 6, "6 peles, 10 cabelos, 6 olhos")
	for body: StringName in CustomizationOptions.BODIES:
		_check(o.styles_for(body).size() >= 4, "%s: >= 4 estilos" % body)
		for anim: StringName in CharacterLayers.ANIMS:
			var bp: String = CharacterLayers.base_sheet_path(body, anim)
			var mp: String = CharacterLayers.mask_sheet_path(body, anim)
			if anim == &"hit" and not ResourceLoader.exists(bp) and not ResourceLoader.exists(mp):
				continue # hit é opcional (só as folhas do pipeline 3D trazem; DirectionalSprite3D usa a vida procedural)
			_check(ResourceLoader.exists(bp) and ResourceLoader.exists(mp), "%s %s: corpo-base e máscara" % [body, anim])
			var bt: Texture2D = load(bp)
			var mt: Texture2D = load(mp)
			_check(bt.get_size() == mt.get_size(), "%s %s: máscara do mesmo tamanho" % [body, anim])
			for style: StringName in o.styles_for(body):
				if style == CharacterLayers.STYLE_BUZZ:
					continue
				var hp: String = CharacterLayers.hair_sheet_path(style, body, anim)
				_check(ResourceLoader.exists(hp) and (load(hp) as Texture2D).get_size() == bt.get_size(),
						"%s %s: cabelo %s alinhado (mesmo tamanho)" % [body, anim, style])
			var ep: String = CharacterLayers.eyes_sheet_path(body, anim)
			_check(ResourceLoader.exists(ep) and (load(ep) as Texture2D).get_size() == bt.get_size(),
					"%s %s: olhos alinhados (mesmo tamanho)" % [body, anim])
			for ear: StringName in o.earrings:
				_check(ResourceLoader.exists(CharacterLayers.face_sheet_path(ear, body, anim)), "%s %s: brinco %s" % [body, anim, ear])
	var d: Dictionary = o.default_appearance(&"female")
	_check(o.is_valid(d), "padrão válido")
	_check(d[&"hair_style"] == &"ponytail" and o.default_appearance(&"male")[&"hair_style"] == &"spiky", "padrão = Viajante atual")
	var bad: Dictionary = {&"body": &"male", &"skin": 99, &"hair_style": &"bob", &"hair_color": 3, &"eye_color": -1, &"earrings": &"crown"}
	_check(not o.is_valid(bad), "aparência inválida recusada")
	var fixed: Dictionary = o.sanitize(bad)
	_check(fixed[&"skin"] == 0 and fixed[&"hair_style"] == &"spiky" and fixed[&"hair_color"] == 3 and fixed[&"earrings"] == &"", "sanitize corrige só o inválido")
	# nacionalidade (GDD §4.0): padrão Terra do Sabiá, região válida aceita, inválida volta ao padrão
	_check(d[&"nationality"] == &"sabia" and o.nationalities.size() == 10, "nacionalidade padrão = sabia, 10 regiões")
	_check(o.sanitize({&"body": &"male", &"nationality": &"jade"})[&"nationality"] == &"jade", "nacionalidade válida aceita")
	_check(o.sanitize({&"body": &"male", &"nationality": &"atlantida"})[&"nationality"] == &"sabia", "nacionalidade inválida corrigida")
	for nat: StringName in o.nationalities:
		_check(TranslationServer.translate(o.nationality_key(nat)) != o.nationality_key(nat), "nacionalidade %s traduzida" % nat)
	# roupa por nacionalidade: o tecido azul muda de cor; Sabiá e roupa de título ficam como estão
	_check(CharacterLayers.cloth_for({&"nationality": &"sabia"}).is_empty(), "Sabiá mantém as cores do Viajante")
	_check(CharacterLayers.cloth_for({&"nationality": &"jade", &"outfit": &"sabia_blade_machete"}).is_empty(), "roupa de título não recolore")
	# arquétipos principais (Tanque, Ágil, Arcano, Xamânico): detecção e códigos de shader
	_check(CharacterLayers.archetype_code_for({&"archetype": &"tank"}) == 1 and CharacterLayers.archetype_code_for({&"outfit": &"title_jabuti"}) == 1, "arquétipo Tanque mapeado (código 1)")
	_check(CharacterLayers.archetype_code_for({&"archetype": &"blade"}) == 2 and CharacterLayers.archetype_code_for({&"outfit": &"title_machete"}) == 2, "arquétipo Ágil mapeado (código 2)")
	_check(CharacterLayers.archetype_code_for({&"archetype": &"arcane"}) == 3 and CharacterLayers.archetype_code_for({&"outfit": &"title_firefly"}) == 3, "arquétipo Arcano mapeado (código 3)")
	_check(CharacterLayers.archetype_code_for({&"archetype": &"support"}) == 4 and CharacterLayers.archetype_code_for({&"outfit": &"title_root"}) == 4, "arquétipo Xamânico mapeado (código 4)")
	# diferenciação de silhueta entre os 4 arquétipos
	var t_img: Image = (load(CharacterLayers.outfit_sheet_path(&"title_jabuti", &"male", &"idle")) as Texture2D).get_image()
	var a_img: Image = (load(CharacterLayers.outfit_sheet_path(&"title_machete", &"male", &"idle")) as Texture2D).get_image()
	var arc_img: Image = (load(CharacterLayers.outfit_sheet_path(&"title_firefly", &"male", &"idle")) as Texture2D).get_image()
	var sh_img: Image = (load(CharacterLayers.outfit_sheet_path(&"title_root", &"male", &"idle")) as Texture2D).get_image()
	var diff_tank_arcane: int = 0
	var diff_agile_shaman: int = 0
	for y: int in 96:
		for x: int in 96:
			var ta: bool = t_img.get_pixel(x, y).a > 0.5
			var aa: bool = a_img.get_pixel(x, y).a > 0.5
			var arca: bool = arc_img.get_pixel(x, y).a > 0.5
			var sha: bool = sh_img.get_pixel(x, y).a > 0.5
			if ta != arca:
				diff_tank_arcane += 1
			if aa != sha:
				diff_agile_shaman += 1
	_check(diff_tank_arcane > 150, "silhuetas Tanque e Arcano diferenciadas (%d px distintos)" % diff_tank_arcane)
	_check(diff_agile_shaman > 100, "silhuetas Ágil e Xamânico diferenciadas (%d px distintos)" % diff_agile_shaman)
	var blue := Color8(31, 128, 178)
	var jade_c: PackedColorArray = CharacterLayers.cloth_for({&"nationality": &"jade"})
	var recol: Color = CharacterLayers.recolor_cloth(blue, jade_c)
	_check(jade_c.size() == 2 and absf(recol.h - jade_c[0].h) < 0.03, "tecido azul vira o tecido da região (%s)" % recol)
	var base_img: Image = (load(CharacterLayers.base_sheet_path(&"male", &"idle")) as Texture2D).get_image()
	var base_mask: Image = (load(CharacterLayers.mask_sheet_path(&"male", &"idle")) as Texture2D).get_image()
	var plain: Image = CharacterLayers.bake_image(base_img, CharacterLayers.MODE_BASE, CharacterLayers.ramps_for({&"nationality": &"sabia"}), base_mask)
	var jade_img: Image = CharacterLayers.bake_image(base_img, CharacterLayers.MODE_BASE, CharacterLayers.ramps_for({&"nationality": &"jade"}), base_mask)
	var changed: int = 0
	var head_changed: int = 0
	for y: int in 96:
		for x: int in 96:
			if plain.get_pixel(x, y) != jade_img.get_pixel(x, y):
				changed += 1
				if base_mask.get_pixel(x, y).a < 0.75:
					head_changed += 1
	_check(changed > 300 and head_changed == 0, "roupa recolorida (%d px) sem tocar a zona da cabeça (%d)" % [changed, head_changed])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var all_valid: bool = true
	for i: int in 40:
		all_valid = all_valid and o.is_valid(o.random_appearance(CustomizationOptions.BODIES[i % 2], rng))
	_check(all_valid, "40 aparências aleatórias válidas")
	# recolor na CPU: rampa de cinza do cabelo vira exatamente as cores da rampa escolhida
	var app: Dictionary = {&"body": &"male", &"hair_style": &"neat", &"hair_color": 7}
	var img: Image = (load(CharacterLayers.hair_sheet_path(&"neat", &"male", &"idle")) as Texture2D).get_image()
	var baked: Image = CharacterLayers.bake_image(img, CharacterLayers.MODE_HAIR, CharacterLayers.ramps_for(app))
	var ramp: PackedColorArray = p.hair(7)
	var ok: bool = true
	for y: int in range(0, img.get_height(), 3):
		for x: int in range(0, img.get_width(), 3):
			var c: Color = baked.get_pixel(x, y)
			if c.a > 0.5:
				var hit: bool = false
				for rc: Color in ramp:
					hit = hit or (absi(rc.r8 - c.r8) <= 1 and absi(rc.g8 - c.g8) <= 1 and absi(rc.b8 - c.b8) <= 1)
				ok = ok and hit
	_check(ok, "bake_image: cabelo só com cores da rampa")
	# olhos: camada própria entre corpo e cabelo; íris vira a rampa escolhida, e as 6 cores são bem distintas
	for body: StringName in CustomizationOptions.BODIES:
		_check(CharacterLayers.eyes_blink_path(body) != "", "%s: folha do piscar" % body)
	var names: Array[StringName] = []
	for spec: Dictionary in CharacterLayers.layer_specs({&"body": &"female", &"hair_style": &"bob", &"earrings": &"hoop"}):
		names.append(spec[&"name"])
	_check(names == [CharacterLayers.LAYER_BASE, CharacterLayers.LAYER_EYES, CharacterLayers.LAYER_HAIR,
			CharacterLayers.LAYER_FACE], "ordem das camadas com olhos %s" % [names])
	var eimg: Image = (load(CharacterLayers.eyes_sheet_path(&"male", &"idle")) as Texture2D).get_image()
	for e: int in p.eye_count():
		var eb: Image = CharacterLayers.bake_image(eimg, CharacterLayers.MODE_EYES,
				CharacterLayers.ramps_for({&"eye_color": e}))
		var ramp_e: PackedColorArray = p.eye(e)
		var hits: int = 0
		var misses: int = 0
		for y: int in range(0, 96):
			for x: int in range(0, 96):
				var src: Color = eimg.get_pixel(x, y)
				if src.a > 0.5 and src.r8 == 0 and src.b8 == 0 and src.g8 > 0:
					var c: Color = eb.get_pixel(x, y)
					var t: Color = ramp_e[mini(src.g8 / CharacterLayers.STEP, ramp_e.size() - 1)]
					if absi(t.r8 - c.r8) <= 1 and absi(t.g8 - c.g8) <= 1 and absi(t.b8 - c.b8) <= 1:
						hits += 1
					else:
						misses += 1
		# C3: o novo padrão (≈5,7 cabeças) tem olhos menores que o chibi (7 px de íris por olho, 2 olhos).
		_check(hits >= 12 and misses == 0, "olhos %d: íris na frente só com a rampa (%d px, %d fora)" % [e, hits, misses])


func _test_preview_grid(win: Vector2i) -> void:
	var o: CustomizationOptions = CustomizationOptions.get_default()
	var bg := ColorRect.new()
	bg.color = Color8(124, 116, 138)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 8
	bg.add_child(grid)
	var k: int = 2 if win.y >= 1000 else 1
	var previews: Array[LayeredCharacterPreview] = []
	var i: int = 0
	for body: StringName in CustomizationOptions.BODIES:
		for style: StringName in o.styles_for(body):
			for sector: int in [0, 1, 2, 3, 4, 5, 6, 7]:
				if i >= 64:
					break
				var pv := LayeredCharacterPreview.new()
				pv.show_rotate_buttons = false
				pv.fixed_scale = k
				pv.custom_minimum_size = Vector2(96, 96) * k
				grid.add_child(pv)
				pv.set_appearance({&"body": body, &"hair_style": style, &"hair_color": (i * 3) % 10,
						&"skin": i % 6, &"eye_color": i % 6, &"earrings": o.earring_choices()[i % 4]})
				pv.set_sector(sector)
				previews.append(pv)
				i += 1
	await _frames(SETTLE_FRAMES)
	_check(previews[0].get_layer_names().has(CharacterLayers.LAYER_HAIR), "prévia tem camada de cabelo")
	var buzz: LayeredCharacterPreview = LayeredCharacterPreview.new()
	add_child(buzz)
	buzz.set_appearance({&"body": &"male", &"hair_style": &"buzz", &"earrings": &"hoop"})
	_check(buzz.get_layer_names() == [CharacterLayers.LAYER_BASE, CharacterLayers.LAYER_EYES, CharacterLayers.LAYER_FACE],
			"raspado: sem folha de cabelo (corpo, olhos, brinco)")
	buzz.rotate_by(-1)
	_check(buzz.sector == 7, "girar ◀ a partir de S vai para SO")
	buzz.queue_free()
	await _shot("custom_grid", win)
	bg.queue_free()


func _test_3d(win: Vector2i) -> void:
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color8(124, 116, 138)
	root.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.2)
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.make_current()
	var looks: Array[Dictionary] = [
		{&"body": &"male", &"hair_style": &"spiky"},
		{&"body": &"male", &"hair_style": &"curly", &"hair_color": 4, &"skin": 5, &"earrings": &"hoop"},
		{&"body": &"female", &"hair_style": &"ponytail"},
		{&"body": &"female", &"hair_style": &"braid", &"hair_color": 8, &"skin": 3, &"eye_color": 3, &"earrings": &"feather"},
	]
	for j: int in looks.size():
		var holder := Node3D.new()
		holder.position = Vector3(-1.5 + j * 1.0, 0, 0)
		root.add_child(holder)
		for spec: Dictionary in CharacterLayers.layer_specs(looks[j]):
			var s := Sprite3D.new()
			s.texture = load(spec[&"sheets"][&"idle"])
			s.vframes = 5
			s.hframes = maxi(1, s.texture.get_width() / (s.texture.get_height() / 5))
			s.frame = 0
			s.pixel_size = 1.0 / 48.0
			s.centered = true
			s.offset = Vector2(0, 48)
			var mat: ShaderMaterial = CharacterLayers.make_material_3d(spec[&"mode"], looks[j])
			var mask: Texture2D = load(spec[&"masks"][&"idle"]) if spec[&"masks"].has(&"idle") else null
			CharacterLayers.set_sheet_3d(mat, s.texture, mask)
			s.material_override = mat
			s.position.z = 0.004 * holder.get_child_count()
			holder.add_child(s)
	await _frames(SETTLE_FRAMES)
	await _shot("custom_3d", win)
	root.queue_free()
	await _frames(2)


func _test_title(win: Vector2i) -> void:
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.apply_video_settings = false
	add_child(title)
	var played: Array = []
	title.play_requested.connect(func(n: String, b: StringName, h: String, p: int) -> void: played.assign([n, b, h, p]))
	await _frames(SETTLE_FRAMES)
	_check(title.find_child("Customization", true, false) != null, "seção de personalização existe")
	_check(title.find_child("Preview", true, false) is LayeredCharacterPreview, "prévia em camadas existe")
	title.set_fields("Iracema", &"female", "127.0.0.1", 7788)
	title.set_appearance({&"hair_style": &"braid", &"hair_color": 6, &"skin": 4, &"eye_color": 2, &"earrings": &"seed"})
	var a: Dictionary = title.get_appearance()
	_check(a == {&"body": &"female", &"skin": 4, &"hair_style": &"braid", &"hair_color": 6, &"eye_color": 2, &"earrings": &"seed", &"nationality": &"sabia"}, "get_appearance %s" % a)
	title.set_fields("Iracema", &"male")
	_check(title.get_appearance()[&"hair_style"] == &"spiky", "trocar de corpo corrige estilo inexistente")
	title.set_fields("Iracema", &"female", "127.0.0.1", 7788)
	title.set_appearance({&"hair_style": &"waves", &"hair_color": 7, &"skin": 2, &"eye_color": 4, &"earrings": &"hoop"})
	var rnd: Button = title.find_child("Random", true, false)
	_check(rnd != null, "botão Aleatório")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	title.randomize_appearance(rng)
	_check(CustomizationOptions.get_default().is_valid(title.get_appearance()), "Aleatório gera aparência válida")
	title.set_appearance({&"hair_style": &"waves", &"hair_color": 7, &"skin": 2, &"eye_color": 4, &"earrings": &"hoop"})
	var pv: LayeredCharacterPreview = title.find_child("Preview", true, false)
	pv.set_sector(1)
	await _frames(SETTLE_FRAMES)
	await _shot("custom_title", win)
	_check(title.request_play(), "Jogar com dados válidos")
	_check(played == ["Iracema", &"female", "127.0.0.1", 7788], "play_requested inalterado %s" % [played])
	title.queue_free()
	await _frames(2)


func _test_touch_title(win: Vector2i) -> void:
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.apply_video_settings = false
	title.touch_layout_override = true
	add_child(title)
	await _frames(SETTLE_FRAMES)
	var panel := title.find_child("TravelerPanel", true, false) as Control
	var origin := title.find_child("Origin_sabia", true, false) as Button
	var body := title.find_child("male", true, false) as Button
	_check(title._touch_layout and title._wide_layout and title.ui_scale >= TitleScreen.TOUCH_WIDE_MIN_SCALE,
			"layout touch paisagem usa escala ampliada")
	_check(panel != null and panel.size.x >= get_viewport().get_visible_rect().size.x * 0.4,
			"painel touch é largo o bastante para os dedos")
	var pv_touch := title.find_child("Preview", true, false) as Control
	_check(panel != null and pv_touch != null and not pv_touch.get_global_rect().intersects(panel.get_global_rect()),
			"Viajante no pedestal não fica embaixo da ficha")
	var tab_bar := title.find_child("CreationTabs", true, false) as Control
	_check(tab_bar != null and tab_bar.get_child_count() == title.creation_tab_count(), "ficha tem as 3 abas")
	for i: int in title.creation_tab_count():
		title.select_creation_tab(i)
		var tab := tab_bar.get_child(i) as Button if tab_bar != null else null
		_check(tab != null and tab.button_pressed and tab.size.y >= TitleScreen.TOUCH_TARGET_PX,
				"aba %d ativa e com alvo de toque" % i)
	title.select_creation_tab(0)
	_check(origin != null and origin.custom_minimum_size.x >= 70.0 and origin.custom_minimum_size.y >= 75.0,
			"origens têm alvos grandes para toque")
	_check(body != null and body.custom_minimum_size.y >= 60.0, "seleção de corpo tem alvo grande para toque")
	if panel != null:
		_check(get_viewport().get_visible_rect().encloses(panel.get_global_rect()),
				"painel touch inteiro fica visível")
	await _shot("custom_title_touch", win)
	title.queue_free()
	await _frames(2)


## Slot vazio = criação (abas); slot preenchido = seleção: sem abas nem Aleatório, JOGAR com o nome do
## slot e get_appearance() = aparência salva.
func _test_slot_title(win: Vector2i, touch: bool) -> void:
	DirAccess.remove_absolute(CharacterSlots.path)
	var empty: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	empty.apply_video_settings = false
	empty.touch_layout_override = touch
	add_child(empty)
	await _frames(SETTLE_FRAMES)
	_check(not empty.is_slot_mode() and empty.find_child("CreationTabs", true, false) != null,
			"slot vazio abre na criação com abas (toque=%s)" % touch)
	empty.queue_free()
	await _frames(2)

	var saved: Dictionary = {&"body": &"female", &"skin": 3, &"hair_style": &"braid", &"hair_color": 3,
		&"eye_color": 3, &"earrings": &"seed", &"nationality": &"sabia"}
	_check(CharacterSlots.remember({CharacterSlots.KEY_NAME: "Jaci", CharacterSlots.KEY_BODY: "female",
		CharacterSlots.KEY_APPEARANCE: saved, CharacterSlots.KEY_LEVEL: 5}), "slot gravado no arquivo temporário")
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.apply_video_settings = false
	title.touch_layout_override = touch
	add_child(title)
	var played: Array = []
	title.play_requested.connect(func(n: String, b: StringName, h: String, p: int) -> void: played.assign([n, b, h, p]))
	await _frames(SETTLE_FRAMES)
	_check(title.is_slot_mode(), "slot preenchido abre na seleção (toque=%s)" % touch)
	_check(title.find_child("CreationTabs", true, false) == null and title.find_child("Customization", true, false) == null,
			"seleção não tem abas de edição")
	var rnd := title.find_child("Random", true, false) as Control
	_check(rnd == null or not rnd.visible, "seleção sem Aleatório")
	var name_edit := title.find_child("NameEdit", true, false) as Control
	_check(name_edit == null or not name_edit.is_visible_in_tree(), "nome do slot não é editável")
	var name_label := title.find_child("SlotName", true, false) as Label
	_check(name_label != null and name_label.text == "Jaci", "cartão mostra o nome do slot")
	var a: Dictionary = title.get_appearance()
	_check(a.get(&"hair_style") == &"braid" and a.get(&"body") == &"female" and int(a.get(&"skin", -1)) == 3,
			"get_appearance() devolve a aparência do slot %s" % a)
	var play := title.find_child("Play", true, false) as Button
	_check(play != null and not play.disabled and play.size.y >= (TitleScreen.TOUCH_TARGET_PX if touch else 1),
			"JOGAR habilitado")
	if touch:
		var panel := title.find_child("TravelerPanel", true, false) as Control
		var pv := title.find_child("Preview", true, false) as Control
		_check(panel != null and pv != null and not pv.get_global_rect().intersects(panel.get_global_rect()),
				"Viajante do slot no pedestal, fora da ficha")
	await _shot("custom_slot_touch" if touch else "custom_slot", win)
	_check(title.request_play(), "JOGAR com o slot")
	_check(played.size() == 4 and played[0] == "Jaci" and played[1] == &"female", "play_requested com o slot %s" % [played])
	title.queue_free()
	await _frames(2)


func _shot(prefix: String, win: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join("%s_%dx%d.png" % [prefix, win.x, win.y])
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)


func _check(cond: bool, msg: String) -> bool:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1
	return cond


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
