extends Control

const RAIN_OVERLAY_SCRIPT: GDScript = preload("res://scripts/client/env/rain_overlay.gd")

var _failures: int = 0
var _out_dir: String = "/tmp"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color8(39, 61, 73)
	add_child(background)
	var rain := RAIN_OVERLAY_SCRIPT.new() as Control
	rain.set("rain_chance", 1.0)
	add_child(rain)
	await _frames(2)
	rain.call("set_map", &"fields_sabia")
	_check(bool(rain.call("is_raining")), "mapa aberto pode entrar em chuva aleatória")
	_check((rain.get("_drops") as Array).size() > 0, "chuva emite gotas visíveis")
	_check(rain.mouse_filter == Control.MOUSE_FILTER_IGNORE, "chuva não captura input")
	_check(not bool(rain.call("_rain_allowed", &"cave_reino_encoberto")), "interior de caverna fica seco")
	_check(not bool(rain.call("_rain_allowed", &"elder_trial_arena")), "arena interna fica seca")
	_check(int(RAIN_OVERLAY_SCRIPT.call("drop_budget", Vector2(1600, 900), true)) <= 90,
			"orçamento de chuva mobile fica limitado")
	_check(int(RAIN_OVERLAY_SCRIPT.call("drop_budget", Vector2(1600, 900), false)) > 90,
			"desktop mantém densidade de chuva maior")
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_out_dir.path_join("rain_overlay.png"))
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	print(("ok   " if condition else "FAIL ") + description)
	if not condition:
		_failures += 1