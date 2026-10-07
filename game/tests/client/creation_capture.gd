extends Node
## Captura da tela de criação de personagem no cliente real (TitleScreen), uma imagem por aba.
##   tests/client/run_creation_capture.sh  (ou: godot --path game --resolution 1280x720
##   res://tests/client/creation_capture.tscn -- --out=DIR [--touch] [--prefix=depois] [--slot])
## --slot: grava um personagem falso num CharacterSlots.path temporário (modo seleção, sem abas).
## Salva DIR/<prefix>_<desktop|touch>_<LxA>_aba<N>.png.

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")
const SETTLE_FRAMES: int = 12

var _out_dir: String = "user://"
var _prefix: String = "shot"
var _touch: bool = false
var _slot: bool = false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
		elif arg == "--touch":
			_touch = true
		elif arg == "--slot":
			_slot = true
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Slots sempre num arquivo temporário: vazio = criação; --slot = um personagem salvo falso.
	CharacterSlots.path = OS.get_temp_dir().path_join("creation_capture_slots_%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(CharacterSlots.path)
	if _slot:
		CharacterSlots.remember({CharacterSlots.KEY_NAME: "Iracema", CharacterSlots.KEY_BODY: "female",
			CharacterSlots.KEY_APPEARANCE: {"body": "female", "skin": 3, "hair_style": "braid", "hair_color": 3,
				"eye_color": 3, "earrings": "seed", "nationality": "sabia"}, CharacterSlots.KEY_LEVEL: 7})
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.apply_video_settings = false
	title.touch_layout_override = _touch
	add_child(title)
	await _frames(SETTLE_FRAMES)
	if not _slot:
		title.set_fields("Iracema", &"female", "127.0.0.1", 7788)
	await _frames(SETTLE_FRAMES)
	var tabs: int = 1 if _slot or not title.has_method(&"creation_tab_count") else int(title.call(&"creation_tab_count"))
	for i: int in tabs:
		if title.has_method(&"select_creation_tab"):
			title.call(&"select_creation_tab", i)
		await _frames(SETTLE_FRAMES)
		await _shot("aba%d" % (i + 1))
	DirAccess.remove_absolute(CharacterSlots.path)
	get_tree().quit(0)


func _shot(suffix: String) -> void:
	await RenderingServer.frame_post_draw
	var win: Vector2i = get_viewport().get_visible_rect().size
	var mode: String = ("touch" if _touch else "desktop") + ("_slot" if _slot else "")
	var path: String = _out_dir.path_join("%s_%s_%dx%d_%s.png" % [_prefix, mode,
			win.x, win.y, suffix])
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
