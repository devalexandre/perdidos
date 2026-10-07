extends Node
## Captura do controle NO CLIENTE REAL (ponto de nascimento): controle "conectado" simulado
## (GamepadInput.simulate_connected + Input.joy_connection_changed) e botões apertados com
## Input.parse_input_event. Criado pelo main.gd com --autotest --autotest-script=res://tests/client/gamepad_capture.gd
## --shot-dir=DIR [--ui-mobile] (tests/client/run_gamepad_capture.sh). Salva DIR/<tag>_<etapa>.png:
## touch (antes do controle, só no celular), pad_hud, pad_target, pad_menu, pad_dialogue, pad_settings_help.

const ARG_SHOT_DIR: String = "shot-dir"
const ARG_MOBILE: String = "ui-mobile"
const SETTLE_SEC: float = 4.0
const STEP_SEC: float = 0.5
const DIALOGUE_NPC: StringName = &"fruit_vendor"

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false
var _ui: GameUI = null
var _tag: String = ""


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)
	get_tree().create_timer(180.0).timeout.connect(func() -> void:
		print("gamepad_capture_timeout")
		get_tree().quit(2))


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC)
	var view: Node = main_node.get("client_view") if main_node != null else null
	_ui = view.call(&"get_game_ui") as GameUI if view != null else null
	if _ui == null:
		print("gamepad_capture_no_ui")
		get_tree().quit(1)
		return
	var size: Vector2 = _ui.get_viewport_rect().size
	var mobile: bool = args.has(ARG_MOBILE)
	_tag = "%s_%dx%d" % ["mobile" if mobile else "desktop", int(size.x), int(size.y)]
	var was_mobile: bool = GameSettings.get_instance().mobile_controls
	# Só em memória: nada aqui chama GameSettings.save().
	GameSettings.get_instance().mobile_controls = mobile
	_ui.set_mobile_mode(mobile)
	await _wait(STEP_SEC)
	if mobile:
		await _shot("touch")
	# Controle conecta (como o GameSir no USB-C).
	GamepadInput.simulate_connected = true
	Input.joy_connection_changed.emit(0, true)
	await _wait(STEP_SEC)
	print("gamepad_capture pad_mode=%s touch_visible=%s" % [_ui.is_pad_mode(),
			_ui.mobile_controls.visible if _ui.mobile_controls != null else false])
	await _shot("pad_hud")
	# A: trava o monstro mais perto (se houver) e RB cicla.
	await _tap(JOY_BUTTON_A)
	await _wait(STEP_SEC)
	await _shot("pad_target")
	await _tap(JOY_BUTTON_B)
	# Start: menu da engrenagem com foco; D-pad desce um item.
	await _tap(JOY_BUTTON_START)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _wait(STEP_SEC)
	await _shot("pad_menu")
	await _tap(JOY_BUTTON_B)
	# Diálogo de um NPC de verdade: foco na 1ª opção, D-pad desce.
	var dlg: DialogueDef = Content.dialogue(DIALOGUE_NPC)
	var npc: NpcDef = Content.npc(DIALOGUE_NPC)
	if dlg != null and dlg.get_node_by_id(dlg.start_node) != null:
		var node: DialogueNode = dlg.get_node_by_id(dlg.start_node)
		var options: Array = []
		for o: DialogueOption in node.options:
			options.append(o.text_key)
		_ui._on_dialogue_opened(1, npc.name_key if npc != null else "NPC", node.text_key, options)
		await _wait(STEP_SEC)
		await _tap(JOY_BUTTON_DPAD_DOWN)
		await _wait(STEP_SEC)
		await _shot("pad_dialogue")
		_ui._on_dialogue_closed()
	# Configurações com a ajuda do controle aberta (esconde sem close(): close() grava o settings.cfg).
	_ui.settings.open()
	var toggle: Button = _ui.settings.find_child("PadHelpToggle", true, false) as Button
	if toggle != null:
		toggle.button_pressed = true
	await _wait(STEP_SEC)
	_ui.settings.fit_to_screen()
	_ui.settings.clamp_to_screen()
	await _wait(STEP_SEC)
	await _shot("pad_settings_help")
	_ui.settings.visible = false
	GamepadInput.simulate_connected = false
	GameSettings.get_instance().mobile_controls = was_mobile
	print("gamepad_capture_done")
	get_tree().quit(0)


func _button(b: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = b
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tap(b: JoyButton) -> void:
	_button(b, true)
	await _wait(0.1)
	_button(b, false)
	await _wait(0.15)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s_%s.png" % [dir, _tag, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("gamepad_capture_shot ", path)
