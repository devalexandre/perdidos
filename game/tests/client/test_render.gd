extends Node
## Teste visual (sem rede) do ClientView + DirectionalSprite3D. Precisa de display (xvfb-run).
## godot --path game --resolution 1920x1080 res://tests/client/test_render.tscn -- --out=/caminho [--mode=internal]
## Modo "native" (padrão, GDD §17.0.A/§9.5): mundo na resolução da janela ocupando a janela inteira;
## sprites nítidos (pixel AA do shader, poucas cores distintas + controle negativo com filtro linear); texel = k px
## no foco (inteiro quando possível); Viajante com ≈9–11,5% da altura da tela (GDD §17.0.C); clique no chão → move_requested; clique num
## alvo da camada 2 → interact_requested. Modo "internal" (legado): escala inteira em blocos NxN e bordas.
## Nos dois: raiz sem 3D, direção muda com o yaw da câmera, modo foto.

const CLIENT_VIEW_SCENE: PackedScene = preload("res://scenes/ui/client_view.tscn")
const STUB_DIR: String = "res://tests/_stub_b/"
const SETTLE_FRAMES: int = 8
const GROUND_SIZE: float = 40.0
const HUD_EXCLUDE_HEIGHT: int = 80
## Cores das linhas das folhas provisórias (make_stub_sheets.py): S, SE, E, NE, N.
const ROW_COLORS: Array[Color] = [
	Color8(220, 40, 40), Color8(240, 140, 20), Color8(240, 220, 30), Color8(40, 190, 60), Color8(40, 90, 230)]
const COLOR_TOL: float = 0.04
const NPC_RING_RADIUS: float = 6.0
## Região em volta dos pés do herói (em quadros de personagem) usada para identificar a linha exibida.
const HERO_REGION_HALF_WIDTH_FRAMES: float = 0.5
const HERO_REGION_HEIGHT_FRAMES: float = 1.6
## Casos: yaw da câmera (graus) → setor esperado com o personagem olhando -Z.
const CASES: Array[Dictionary] = [
	{ "yaw": 0, "sector": DirectionalSprite3D.Dir.N },
	{ "yaw": 90, "sector": DirectionalSprite3D.Dir.E },
	{ "yaw": 180, "sector": DirectionalSprite3D.Dir.S },
	{ "yaw": 270, "sector": DirectionalSprite3D.Dir.W },
	{ "yaw": 45, "sector": DirectionalSprite3D.Dir.NE },
]

var _out_dir: String = "user://"
## Com --assets=<dir> usa outra arte (ex.: a real do Agente C) e pula a checagem de cor das linhas.
var _asset_dir: String = STUB_DIR
var _failures: int = 0
var _view: ClientView
var _hero: DirectionalSprite3D
var _moves: Array[Vector3] = []
var _interacts: Array[String] = []
var _mode: String = "native"
## Faixa aceita para a altura do Viajante na tela (fração da janela) com zoom 1.0 — GDD §17.0.C (≈9–11% em 1080p;
## em 720p a escala vira inteira 1 → 11,7%).
const HERO_SCREEN_MIN: float = 0.085
const HERO_SCREEN_MAX: float = 0.125
## Máximo de cores distintas no recorte do herói (sprite nearest de folha provisória + chão xadrez).
## Com escala de texel fracionária o shader faz "pixel AA": cada texel continua um bloco de cor sólida e só a
## fronteira ganha 1 px de transição. Nitidez = fração dos pixels do recorte que estão em cores "de bloco" (cada uma
## com ≥ CRISP_BLOCK_SHARE dos pixels). Nearest/pixel AA fica perto de 1; filtro linear cai bastante.
const CRISP_BLOCK_SHARE: float = 0.005
const CRISP_MIN_BLOCK_FRACTION: float = 0.93
# O valor alto foi calibrado para folhas-placeholder de paleta simples. As folhas finais (paper doll com roupa,
# rosto e cabelo) geram mais bordas/cores de transição pelo pixel-AA; o limite vem do teste real dos dois corpos.
const CRISP_MIN_BLOCK_FRACTION_FINAL: float = 0.65
const PICK_TARGET_ID: String = "e:777"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--assets="):
			_asset_dir = arg.trim_prefix("--assets=")
		elif arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
	Balance.cfg.world_render_mode = _mode
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DirectionalSprite3D.asset_dir = _asset_dir
	_build_world()
	_view = CLIENT_VIEW_SCENE.instantiate() as ClientView
	# Checagem de pixels da imagem do jogo: sem as janelas/botões da interface por cima.
	_view.create_game_ui = false
	add_child(_view)
	_view.move_requested.connect(func(p: Vector3) -> void: _moves.append(p))
	_view.interact_requested.connect(func(t: String) -> void: _interacts.append(t))
	_view.set_follow_target(_hero)
	_view.show_status("NET_CONNECTED")
	await _run()
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _run() -> void:
	await _frames(SETTLE_FRAMES)
	var win: Vector2 = get_viewport().get_visible_rect().size
	var scale: int = _view.get_view_scale()
	var offset: Vector2 = _view.get_view_offset()
	var native: bool = _mode != "internal"
	print("mode=%s window=%s scale=%d offset=%s texel_scale=%.3f render=%s fov=%.2f" % [_mode, win, scale, offset,
			_view.get_texel_scale(), _view.get_render_size(), _view.get_camera().fov])
	_check(get_tree().root.disable_3d, "viewport raiz com disable_3d")
	if native:
		_check(scale == 1 and offset == Vector2.ZERO, "native: sem ampliação nem deslocamento")
		_check(Vector2(_view.get_render_size()) == win, "native: mundo renderizado no tamanho da janela %s" % win)
		var gv: Control = _view.get_node(^"GameView")
		_check(gv.get_global_rect() == Rect2(Vector2.ZERO, win), "native: imagem do jogo cobre a janela inteira (sem faixas)")
		_check_texel_scale()
	_check(tr("MAP_CITY_AWAKENING") == "Porto do Despertar", "tradução pt_BR: '%s'" % tr("MAP_CITY_AWAKENING"))
	_check(tr("NET_UPDATE_REQUIRED") != "NET_UPDATE_REQUIRED", "NET_UPDATE_REQUIRED traduzida")

	# Desliga a luz em todas as camadas (corpo, roupa, cabelo, olhos e acessórios) para contar a nitidez das
	# texturas originais. O teste usava só a camada-base e media cores de iluminação nas outras camadas do paper doll.
	for ds: Node in find_children("*", "DirectionalSprite3D", true, false):
		var body: Sprite3D = (ds as DirectionalSprite3D).get_body_sprite()
		for layer_node: Node in ds.find_children("*", "Sprite3D", true, false):
			var layer_mat: ShaderMaterial = (layer_node as Sprite3D).material_override as ShaderMaterial
			if layer_mat != null:
				layer_mat.set_shader_parameter(&"unlit", true)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(ds.get_node(^"Shadow") as Node3D).visible = false
		(ds as DirectionalSprite3D).set_process(true)
	for case: Dictionary in CASES:
		_view.camera_yaw = deg_to_rad(case["yaw"])
		await _frames(SETTLE_FRAMES)
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = _out_dir.path_join("client_view_yaw%03d.png" % case["yaw"])
		img.save_png(path)
		print("saved " + path)
		var expected: int = case["sector"]
		_check(_hero.get_sector() == expected, "yaw %d° setor=%s esperado=%s" % [
			case["yaw"], DirectionalSprite3D.Dir.keys()[_hero.get_sector()], DirectionalSprite3D.Dir.keys()[expected]])
		if _asset_dir == STUB_DIR:
			var row: int = _dominant_row(img, offset, scale)
			_check(row == DirectionalSprite3D.sheet_row_for_sector(expected), "yaw %d° linha visível=%d" % [case["yaw"], row])
		if native:
			var crisp: float = _hero_block_fraction(img)
			var crisp_min: float = CRISP_MIN_BLOCK_FRACTION if _asset_dir == STUB_DIR else CRISP_MIN_BLOCK_FRACTION_FINAL
			_check(crisp >= crisp_min, "yaw %d° herói nítido: %.1f%% dos pixels em cores de bloco (mín %.0f%%; %d cores)" % [
					case["yaw"], crisp * 100.0, crisp_min * 100.0, _hero_distinct_colors(img)])
		else:
			_check(_blocks_uniform(img, offset, scale), "yaw %d° pixels em blocos %dx%d (escala inteira)" % [case["yaw"], scale, scale])
			_check(_letterbox_clear(img, offset, scale), "yaw %d° bordas sem 3D (raiz não renderiza)" % case["yaw"])

	# Controle negativo: com o raiz renderizando 3D, a câmera intrusa do World apareceria nas bordas.
	if offset != Vector2.ZERO:
		await _negative_control(offset, scale)

	if native:
		await _crisp_negative_control()

	_check_click(offset, scale)
	await _check_pick(offset, scale)
	_check_hover_cell(offset, scale)

	# Modo foto esconde a HUD.
	var photo := InputEventKey.new()
	photo.physical_keycode = KEY_F10
	photo.pressed = true
	get_viewport().push_input(photo)
	await _frames(SETTLE_FRAMES)
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join("client_view_photo_mode.png"))
	_check(not _view.get_node(^"Hud").visible, "modo foto esconde HUD")


func _negative_control(offset: Vector2, scale: int) -> void:
	get_tree().root.disable_3d = false
	await _frames(SETTLE_FRAMES)
	var control_img: Image = get_viewport().get_texture().get_image()
	control_img.save_png(_out_dir.path_join("control_root_3d_enabled.png"))
	_check(not _letterbox_clear(control_img, offset, scale), "controle: sem disable_3d o raiz desenharia 3D")
	get_tree().root.disable_3d = true


func _check_click(offset: Vector2, scale: int) -> void:
	_view.camera_yaw = 0.0
	var target := Vector3(2.0, 0.0, 1.0)
	var internal: Vector2 = _view.get_camera().unproject_position(target)
	var win_pos: Vector2 = offset + internal * scale + Vector2.ONE * (scale * 0.5)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = win_pos
	ev.global_position = win_pos
	get_viewport().push_input(ev)
	var release := ev.duplicate() as InputEventMouseButton
	release.pressed = false
	get_viewport().push_input(release)
	var ok: bool = _moves.size() == 1 and _moves[0].distance_to(target) < 0.15
	_check(ok, "clique em %s → move_requested %s (alvo %s)" % [win_pos, _moves, target])
	# Clique na borda preta (fora da imagem do jogo) não move.
	if offset.x > 0.0:
		var outside := ev.duplicate() as InputEventMouseButton
		outside.position = Vector2(offset.x * 0.5, offset.y + 100.0)
		get_viewport().push_input(outside)
		_check(_moves.size() == 1, "clique fora da imagem ignorado")


## Texel de sprite = k px inteiros no foco; Viajante do tamanho pedido (GDD §9.5).
func _check_texel_scale() -> void:
	var cam: Camera3D = _view.get_camera()
	var k: float = _view.get_texel_scale()
	var focus: Vector3 = _hero.global_position + Vector3.UP * ClientView.LOOK_AT_HEIGHT
	var right: Vector3 = cam.global_basis.x
	var px: float = cam.unproject_position(focus + right * Balance.cfg.sprite_pixel_size).x \
			- cam.unproject_position(focus).x
	_check(absf(px - k) < 0.01, "texel no foco = %.3f px (esperado %.3f)" % [px, k])
	var exact: float = win_h_for_texel() * Balance.cfg.character_screen_fraction / Balance.cfg.character_body_px
	_check(absf(exact - roundf(exact)) > Balance.cfg.sprite_texel_snap or is_equal_approx(k, roundf(exact)),
			"escala inteira sempre que possível (exata %.3f → %.3f)" % [exact, k])
	var body_top: Vector3 = _hero.global_position + Vector3.UP * (Balance.cfg.character_body_px
			* Balance.cfg.sprite_pixel_size / cos(deg_to_rad(Balance.cfg.camera_pitch_deg)))
	var h_px: float = cam.unproject_position(_hero.global_position).y - cam.unproject_position(body_top).y
	var win_h: float = get_viewport().get_visible_rect().size.y
	var frac: float = h_px / win_h
	print("  Viajante na tela: %.0f px = %.1f%% da altura (zoom %.2f; limites %.2f–%.2f)" % [h_px, frac * 100.0,
			_view.camera_zoom, Balance.cfg.camera_zoom_min, Balance.cfg.camera_zoom_max])
	_check(frac >= HERO_SCREEN_MIN and frac <= HERO_SCREEN_MAX, "Viajante com %.1f%% da altura da tela" % (frac * 100.0))
	var at_min: float = frac * Balance.cfg.camera_zoom_min
	_check(at_min >= HERO_SCREEN_MIN * 0.85, "zoom mínimo mantém o Viajante legível (%.1f%%)" % (at_min * 100.0))


func win_h_for_texel() -> float:
	return get_viewport().get_visible_rect().size.y


## Controle negativo da nitidez: com filtro linear o mesmo recorte teria muito mais cores. O corpo usa o shader dos
## sprites (char_palette_swap_3d): filter_mode 0 = pixel AA (padrão), 2 = linear.
func _crisp_negative_control() -> void:
	_view.camera_yaw = deg_to_rad(20.0)
	var mat: ShaderMaterial = _hero.get_body_sprite().material_override as ShaderMaterial
	_check(mat != null, "corpo com o shader dos sprites (luz da cena, GDD §17.0.C)")
	if mat == null:
		return
	# Perto (texel ≈ 4 px) a diferença aparece: linear espalha cada fronteira por ~4 px, o pixel AA por 1 px.
	_view.camera_zoom = 3.0
	await _frames(SETTLE_FRAMES)
	var sharp: float = 1.0 - _hero_block_fraction(get_viewport().get_texture().get_image())
	mat.set_shader_parameter(&"filter_mode", 2)
	await _frames(SETTLE_FRAMES)
	var blurred: float = 1.0 - _hero_block_fraction(get_viewport().get_texture().get_image())
	mat.set_shader_parameter(&"filter_mode", 0)
	_view.camera_zoom = 1.0
	await _frames(SETTLE_FRAMES)
	# O Viajante de proporção compacta usa roupa, cabelo, olhos e acessórios em camadas; a comparação mede o shader
	# no zoom em que cada transição tem espaço visível e exige que linear fique claramente pior que pixel AA.
	_check(blurred > sharp * 1.3, "controle: filtro linear teria %.1f%% de pixels de transição (pixel AA: %.1f%%)" % [
			blurred * 100.0, sharp * 100.0])


## Fração dos pixels do recorte do herói que estão em cores "de bloco" (≥ CRISP_BLOCK_SHARE do recorte).
func _hero_block_fraction(img: Image) -> float:
	var counts: Dictionary = _hero_color_counts(img)
	var total: int = 0
	for c: int in counts.values():
		total += c
	if total == 0:
		return 0.0
	var block: int = 0
	for c: int in counts.values():
		if c >= total * CRISP_BLOCK_SHARE:
			block += c
	return float(block) / total


## Cores distintas no recorte do herói (retângulo do quadro projetado).
func _hero_distinct_colors(img: Image) -> int:
	return _hero_color_counts(img).size()


func _hero_color_counts(img: Image) -> Dictionary:
	var cam: Camera3D = _view.get_camera()
	var feet: Vector2 = cam.unproject_position(_hero.global_position)
	var top: Vector2 = cam.unproject_position(_hero.global_position + Vector3.UP * _hero.get_world_height())
	var h: int = int(feet.y - top.y)
	var half_w: int = int(h * 0.35)
	var seen: Dictionary = {}
	for y in range(int(top.y) + 2, int(feet.y) - 2):
		for x in range(int(feet.x) - half_w, int(feet.x) + half_w):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				var k: int = img.get_pixel(x, y).to_rgba32()
				seen[k] = int(seen.get(k, 0)) + 1
	return seen


## Clique num alvo da camada 2 (entidade clicável) → interact_requested com o target_id.
func _check_pick(offset: Vector2, scale: int) -> void:
	var area := Area3D.new()
	area.collision_layer = ClientView.PICK_COLLISION_MASK
	area.collision_mask = 0
	area.set_meta(ClientView.META_TARGET_ID, PICK_TARGET_ID)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 1.6, 0.8)
	shape.shape = box
	shape.position.y = 0.8
	area.add_child(shape)
	area.position = Vector3(-2.0, 0.0, 1.0)
	get_node(^"World").add_child(area)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var internal: Vector2 = _view.get_camera().unproject_position(area.position + Vector3.UP * 0.8)
	var win_pos: Vector2 = offset + internal * scale
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = win_pos
	ev.global_position = win_pos
	get_viewport().push_input(ev)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	get_viewport().push_input(up)
	_check(_interacts == [PICK_TARGET_ID], "clique no alvo da camada 2 → interact_requested %s" % [_interacts])
	_check(_view.pick_target(win_pos).get("target_id", "") == PICK_TARGET_ID, "pick_target acha o alvo")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Linha da folha cuja cor mais aparece na imagem do jogo.
func _dominant_row(img: Image, offset: Vector2, scale: int) -> int:
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var feet: Vector2i = Vector2i(_view.get_camera().unproject_position(_hero.global_position))
	var frame: float = Balance.cfg.character_frame_size
	var half_w: int = int(frame * HERO_REGION_HALF_WIDTH_FRAMES)
	for y in range(feet.y - int(frame * HERO_REGION_HEIGHT_FRAMES), feet.y + 1):
		for x in range(feet.x - half_w, feet.x + half_w):
			var c: Color = img.get_pixelv(Vector2i(offset) + Vector2i(x, y) * scale)
			for r in ROW_COLORS.size():
				var rc: Color = ROW_COLORS[r]
				if absf(c.r - rc.r) < COLOR_TOL and absf(c.g - rc.g) < COLOR_TOL and absf(c.b - rc.b) < COLOR_TOL:
					counts[r] += 1
	print("  contagem de cores por linha: %s" % [counts])
	var best: int = 0
	for r in counts.size():
		if counts[r] > counts[best]:
			best = r
	return best if counts[best] > 0 else -1


func _blocks_uniform(img: Image, offset: Vector2, scale: int) -> bool:
	var internal := Balance.cfg.internal_resolution
	for y in internal.y:
		for x in internal.x:
			var base := Vector2i(offset) + Vector2i(x, y) * scale
			if base.y < HUD_EXCLUDE_HEIGHT:
				continue
			var c: Color = img.get_pixelv(base)
			for dy in scale:
				for dx in scale:
					if img.get_pixelv(base + Vector2i(dx, dy)) != c:
						return false
	return true


func _letterbox_clear(img: Image, offset: Vector2, scale: int) -> bool:
	var game_rect := Rect2i(Vector2i(offset), Balance.cfg.internal_resolution * scale)
	var clear: Color = img.get_pixel(0, img.get_height() - 1)
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if not game_rect.has_point(Vector2i(x, y)) and y >= HUD_EXCLUDE_HEIGHT and img.get_pixel(x, y) != clear:
				return false
	return true


func _build_world() -> void:
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	# Câmera "intrusa" no World: se o raiz renderizasse 3D, ela apareceria nas bordas.
	var root_cam := Camera3D.new()
	root_cam.position = Vector3(0, 5, 5)
	root_cam.current = true
	world.add_child(root_cam)
	root_cam.look_at(Vector3.ZERO)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(light)

	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 1.0, GROUND_SIZE)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _checker_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(GROUND_SIZE / 2.0, GROUND_SIZE / 2.0, 1.0)
	plane.material = mat
	mesh_inst.mesh = plane
	ground.add_child(mesh_inst)
	world.add_child(ground)

	_hero = DirectionalSprite3D.new()
	_hero.name = "Hero"
	world.add_child(_hero)
	_hero.setup(&"male")
	_hero.facing_yaw = 0.0 # olhando para -Z
	_hero.anim = &"walk"
	# Outros personagens de referência ao redor, olhando em direções variadas.
	for i in 4:
		var npc := DirectionalSprite3D.new()
		world.add_child(npc)
		npc.setup(&"female")
		npc.position = Vector3(NPC_RING_RADIUS, 0.0, 0.0).rotated(Vector3.UP, i * TAU / 4.0 + PI / 4.0)
		npc.facing_yaw = i * TAU / 8.0


## Xadrez de 2x2 unidades, Balance.cfg.world_pixels_per_unit px/unidade, com linhas de 1 px para evidenciar a escala.
func _checker_texture() -> Texture2D:
	var cell: int = Balance.cfg.world_pixels_per_unit
	var size: int = cell * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var odd: bool = (x / cell + y / cell) % 2 == 1
			var c: Color = Color8(96, 120, 80) if odd else Color8(120, 144, 96)
			if x % cell == 0 or y % cell == 0:
				c = Color8(70, 80, 60)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _check_hover_cell(offset: Vector2, scale: int) -> void:
	_view._grid = WalkGrid.from_ascii(PackedStringArray([
		"..........", "..........", "..........", "...#......", "..........", ".........."
	]))
	var point := Vector3(2.2, 0, 3.7)
	var screen: Vector2 = offset + _view.get_camera().unproject_position(point) * scale
	_view._update_hover(screen)
	_check(_view.is_hover_cell_visible(), "célula andável sob o mouse iluminada")
	var cell_pos: Vector3 = _view.get_hover_cell_position()
	_check(absf(cell_pos.x - 2.5) < 0.01 and absf(cell_pos.z - 3.5) < 0.01,
			"luz alinhada ao centro real da grade")
	point = Vector3(3.2, 0, 3.7)
	screen = offset + _view.get_camera().unproject_position(point) * scale
	_view._update_hover(screen)
	_check(not _view.is_hover_cell_visible(), "célula bloqueada não recebe luz")
	_view._grid = null
