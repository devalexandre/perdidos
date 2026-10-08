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
	rain.call("set_map", &"fields_pindorama")
	_check(bool(rain.call("is_raining")), "mapa aberto pode entrar em chuva aleatória")
	_check((rain.get("_drops") as Array).size() > 0, "chuva emite gotas visíveis")
	_check(rain.mouse_filter == Control.MOUSE_FILTER_IGNORE, "chuva não captura input")
	_check(not bool(rain.call("_rain_allowed", &"cave_reino_encoberto")), "interior de caverna fica seco")
	_check(not bool(rain.call("_rain_allowed", &"elder_trial_arena")), "arena interna fica seca")
	_check(int(RAIN_OVERLAY_SCRIPT.call("drop_budget", Vector2(1600, 900), true)) <= 90,
			"orçamento de chuva mobile fica limitado")
	_check(int(RAIN_OVERLAY_SCRIPT.call("drop_budget", Vector2(1600, 900), false)) > 90,
			"desktop mantém densidade de chuva maior")
	rain.set("_region", {"id": "test", "rain_factor": 1.0, "heavy_chance": 1.0, "fog_chance": 1.0})
	rain.call("_roll_weather")
	_check(is_equal_approx(float(rain.get("_target_intensity")), 1.0), "perfil de temporal produz chuva forte")
	_check(float(rain.get("_target_fog")) >= 0.5, "perfil úmido pode produzir neblina")
	rain.call("_process", 2.0)
	_check(float(rain.get("_intensity")) > 0.0 and float(rain.get("_intensity")) < 1.0, "chuva cresce gradualmente")
	rain.call("_process", 4.0)
	rain.call("_set_raining", false)
	rain.call("_process", 2.0)
	_check(float(rain.get("_intensity")) > 0.0, "chuva diminui sem corte abrupto")
	rain.call("set_map", &"cave_reino_encoberto")
	_check(float(rain.get("_target_fog")) == 0.0 and (rain.get("_drops") as Array).is_empty(),
		"entrar em interior limpa chuva e neblina externas")
	rain.set("focus_position", Vector3.ZERO)
	rain.call("set_map", &"training_field")
	var camp_fog: float = rain.get("_target_fog")
	var camp_rain: float = rain.get("_target_intensity")
	rain.set("focus_position", Vector3(50, 0, 34))
	rain.call("_update_region")
	rain.set("focus_position", Vector3.ZERO)
	rain.call("_update_region")
	_check(is_equal_approx(float(rain.get("_target_fog")), camp_fog)
		and is_equal_approx(float(rain.get("_target_intensity")), camp_rain),
		"voltar à região preserva clima sorteado enquanto vigente")
	rain.call("force_weather", 1.0, 0.0, true)
	rain.set("focus_position", Vector3(50, 0, 34))
	rain.call("_update_region")
	_check(bool(rain.call("is_raining")) and is_equal_approx(float(rain.get("_target_intensity")), 1.0)
		and is_equal_approx(float(rain.get("_intensity")), 1.0), "clima travado (capturas) ignora sorteio e região")
	rain.call("force_weather", 0.0)
	_check(not bool(rain.call("is_raining")) and float(rain.get("_intensity")) > 0.0,
		"destravar para seco ainda passa pela rampa")
	rain.call("release_weather")
	rain.set("focus_position", Vector3.ZERO)
	rain.call("set_map", &"fields_pindorama")
	rain.call("_process", 6.0)
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
