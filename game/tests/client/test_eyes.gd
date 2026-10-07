extends Node
## Teste da camada de OLHOS no mundo (GDD §17.0.1, §17.4 camada 7; tools/art/customization/eyes.py).
## Precisa de display (xvfb-run):
##   godot --path game --resolution 1920x1080 res://tests/client/test_eyes.tscn -- --out=/caminho
## ClientView real + EntityVisual com aparências que só diferem na cor dos olhos: a camada "Eyes" existe entre
## o corpo e o cabelo, segue idle/walk/golpe, some de costas, pisca no idle e a cor da íris é a da rampa.
## Capturas: eyes_world_WxH.png (lado a lado, de frente) e eyes_world_se_WxH.png (3/4).

const CLIENT_VIEW_SCENE: PackedScene = preload("res://scenes/ui/client_view.tscn")
const SETTLE_FRAMES: int = 10
## Pares com a mesma aparência e olhos diferentes (azul x âmbar; verde x cinza).
const LOOKS: Array[Dictionary] = [
	{&"body": &"male", &"hair_style": &"spiky", &"eye_color": 4},
	{&"body": &"male", &"hair_style": &"spiky", &"eye_color": 2},
	{&"body": &"female", &"hair_style": &"ponytail", &"eye_color": 3},
	{&"body": &"female", &"hair_style": &"ponytail", &"eye_color": 5},
]

var _out_dir: String = "user://"
var _failures: int = 0
var _view: ClientView
var _chars: Array[EntityVisual] = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color8(118, 142, 96)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = mat
	ground.mesh = plane
	world.add_child(ground)
	var anchor := Node3D.new()
	world.add_child(anchor)
	for i: int in LOOKS.size():
		var v := EntityVisual.new()
		world.add_child(v)
		v.set_appearance(LOOKS[i])
		v.setup_entity("e:%d" % i, "olho %d" % LOOKS[i][&"eye_color"], false, false)
		v.position = Vector3(-1.2 + i * 0.8, 0.0, 0.0)
		v.facing_yaw = 0.0
		_chars.append(v)
	_view = CLIENT_VIEW_SCENE.instantiate() as ClientView
	_view.create_game_ui = false
	add_child(_view)
	_view.set_follow_target(anchor)
	await _run()
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var win: Vector2i = get_viewport().get_visible_rect().size
	_view.camera_yaw = PI # personagens olhando -Z, câmera do outro lado: de frente (S)
	_view.camera_zoom = Balance.cfg.camera_zoom_max
	await _frames(SETTLE_FRAMES)
	var hero: EntityVisual = _chars[0]
	_check(hero.get_sector() == DirectionalSprite3D.Dir.S, "de frente (setor S)")
	var order: Array[StringName] = hero.get_visible_layer_order()
	_check(order.find(CharacterLayers.LAYER_EYES) > order.find(&"Body")
			and order.find(CharacterLayers.LAYER_EYES) < order.find(CharacterLayers.LAYER_HAIR),
			"olhos entre corpo e cabelo %s" % [order])
	var eyes: Sprite3D = hero.get_overlay_sprite(CharacterLayers.LAYER_EYES)
	_check(eyes != null and eyes.visible and eyes.material_override is ShaderMaterial, "camada Eyes com material de troca de cor")
	# cor da íris no material = rampa escolhida
	var p: CustomizationPalettes = CustomizationOptions.get_default().palettes
	for i: int in _chars.size():
		var m: ShaderMaterial = _chars[i].get_overlay_sprite(CharacterLayers.LAYER_EYES).material_override
		var ramp: PackedColorArray = m.get_shader_parameter(&"eye_ramp")
		_check(ramp == p.eye(LOOKS[i][&"eye_color"]), "personagem %d: rampa dos olhos %d" % [i, LOOKS[i][&"eye_color"]])
	# segue as animações (walk e golpe têm folha de olhos) e pisca no idle
	for a: StringName in [&"walk", &"attack_unarmed", &"cast", &"idle"]:
		hero.anim = a
		await _frames(2)
		_check(eyes.visible and eyes.texture.resource_path.ends_with("_%s.png" % a), "olhos visíveis em %s" % a)
	var blinked: bool = false
	var t: float = 0.0
	while t < CharacterLayers.BLINK_MAX_SEC + 1.0 and not blinked:
		await get_tree().process_frame
		t += get_process_delta_time()
		blinked = hero.is_blinking() and eyes.texture.resource_path.ends_with("_idle_blink.png")
	_check(blinked, "pisca no idle (folha _idle_blink) em até %.1f s" % (CharacterLayers.BLINK_MAX_SEC + 1.0))
	while hero.is_blinking():
		await get_tree().process_frame
	await _frames(2)
	await _shot("eyes_world", win)
	_view.camera_yaw = PI - PI / 4.0
	await _frames(SETTLE_FRAMES)
	await _shot("eyes_world_se", win)
	_view.camera_yaw = 0.0 # de costas
	await _frames(SETTLE_FRAMES)
	_check(hero.get_sector() == DirectionalSprite3D.Dir.N, "de costas (setor N)")


func _shot(prefix: String, win: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join("%s_%dx%d.png" % [prefix, win.x, win.y])
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)


func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
