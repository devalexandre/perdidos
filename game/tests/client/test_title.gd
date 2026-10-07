extends Node
## Teste da tela de título (precisa de display: xvfb-run). Valida nome (3–16), corpo, host/porta,
## emite play_requested e salva captura em --out.
##   godot --path game --resolution 1920x1080 res://tests/client/test_title.tscn -- --out=/caminho

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")
const SETTLE_FRAMES: int = 10
const TEST_PORT: int = 7788

var _out_dir: String = "user://"
var _failures: int = 0
var _played: Array = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Sem personagem salvo (modo criação), sem tocar nos slots do jogador.
	CharacterSlots.path = OS.get_temp_dir().path_join("test_title_slots_%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(CharacterSlots.path)
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.apply_video_settings = false
	add_child(title)
	title.play_requested.connect(func(n: String, b: StringName, h: String, p: int) -> void: _played = [n, b, h, p])
	await _frames(SETTLE_FRAMES)
	_check(title.validate_name("Ab") == "TITLE_ERR_NAME_LENGTH", "nome curto recusado")
	_check(title.validate_name("NomeMuitoGrandeDemais") == "TITLE_ERR_NAME_LENGTH", "nome longo recusado")
	_check(title.validate_name("Ana<3") == "TITLE_ERR_NAME_CHARS", "caracteres inválidos recusados")
	_check(title.validate_name("João Pé") == "", "nome com acento aceito")
	title.set_fields("Ab", &"female")
	_check(not title.request_play() and _played.is_empty(), "Jogar bloqueado com nome inválido")
	title.set_fields("Iracema", &"female", "127.0.0.1", TEST_PORT)
	await _frames(SETTLE_FRAMES)
	var win: Vector2i = get_viewport().get_visible_rect().size
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join("title_%dx%d.png" % [win.x, win.y])
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)
	_check(title.request_play(), "Jogar com dados válidos")
	_check(_played == ["Iracema", &"female", "127.0.0.1", TEST_PORT], "play_requested %s" % [_played])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
