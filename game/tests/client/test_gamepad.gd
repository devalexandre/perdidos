extends Node
## Teste do controle (joypad) no cliente, com eventos de verdade (Input.parse_input_event com
## InputEventJoypadButton/InputEventJoypadMotion) e controle conectado simulado (GamepadInput.simulate_connected).
## Precisa de display:
##   xvfb-run -a godot --path game --resolution 1280x720 res://tests/client/test_gamepad.tscn [-- --out=DIR]
## Cobre: andar (analógico e D-pad), A (conversar, pegar, travar, atacar), LB/RB/B no alvo, Start abre/B
## fecha o menu, A no menu abre janela, opção de diálogo com D-pad + A, atalhos da barra (X, RT+Y, LT+A),
## toque/controle trocando os controles de toque, desconectar, câmera no analógico direito e a tela de título
## (foco, abas com LB/RB, campo de nome com A/B, Start = Jogar).

const CLIENT_VIEW_SCENE: PackedScene = preload("res://scenes/ui/client_view.tscn")
const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")
const FAKE_NET_SCRIPT: GDScript = preload("res://tests/client/fake_net.gd")
const SETTLE_FRAMES: int = 8
const PLAYER_ID: int = 1
const NPC_ID: int = 50
const DROP_ID: int = 60
const MON_A: int = 101
const MON_B: int = 102

var _out_dir: String = ""
var _failures: int = 0
var _view: ClientView
var _ui: GameUI
var _net: Node
var _pad: GamepadInput
var _ents: Node
var _player: NetEntity
var _moves: Array[Vector3] = []
var _actions: Array = []
var _slots_used: Array[int] = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	GamepadInput.simulate_connected = true
	GameSettings.get_instance().mobile_controls = false
	_build_world()
	await get_tree().process_frame
	_net = FAKE_NET_SCRIPT.new()
	_net.name = &"FakeNet"
	add_child(_net)
	_view = CLIENT_VIEW_SCENE.instantiate() as ClientView
	add_child(_view)
	_ui = _view.get_game_ui()
	_ui.bind_net(_net)
	_view.set_follow_target(_player)
	_view.move_requested.connect(func(p: Vector3) -> void: _moves.append(p))
	await _frames(SETTLE_FRAMES)
	_pad = _ui.gamepad
	_ui.combat_assist.action_performed.connect(func(k: StringName, id: int) -> void: _actions.append([k, id]))
	_pad.slot_used.connect(func(i: int) -> void: _slots_used.append(i))
	await _test_mode()
	await _test_walk()
	await _test_action_button()
	await _test_menu()
	await _test_dialogue()
	await _test_hotbar()
	await _test_touch_switch()
	await _test_controller_status()
	await _test_title()
	GamepadInput.simulate_connected = false
	GameSettings.get_instance().mobile_controls = false
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


# --- Mundo ----------------------------------------------------------------------------------------

func _build_world() -> void:
	var main := Node.new()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	var world := Node3D.new()
	world.name = "World"
	main.add_child(world)
	var instances := Node3D.new()
	instances.name = "Instances"
	world.add_child(instances)
	var inst := Node3D.new()
	inst.name = "Test"
	instances.add_child(inst)
	_ents = Node3D.new()
	_ents.name = "Entities"
	inst.add_child(_ents)
	_player = _entity(PLAYER_ID, NetEntity.KIND_PLAYER, Vector3.ZERO, "Ana")


func _entity(id: int, kind: StringName, pos: Vector3, display: String) -> NetEntity:
	var e := NetEntity.new()
	e.name = str(id)
	e.entity_id = id
	e.kind = kind
	e.display_name = display
	e.hp_ratio = 1.0
	e.position = pos
	_ents.add_child(e)
	return e


# --- Utilidades -----------------------------------------------------------------------------------

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _button(b: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = b
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Aperta e solta (um quadro entre cada, como um toque real).
func _tap(b: JoyButton) -> void:
	_button(b, true)
	await _frames(2)
	_button(b, false)
	await _frames(2)


func _axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _shot(file: String) -> void:
	if _out_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(file + ".png"))


func _key_text(i: int) -> String:
	return (_ui.progression.hotbar.slots[i].get(&"_key_label") as Label).text


# --- Casos ----------------------------------------------------------------------------------------

func _test_mode() -> void:
	_check(_pad != null and _pad.is_pad_mode(), "controle conectado (simulado) → modo controle")
	_check(_ui.gamepad_hints.visible, "faixa de dicas visível")
	_check(_key_text(0) == "X" and _key_text(3) == "RT+Y" and _key_text(9) == "LT+A",
			"barra mostra os botões do controle (%s, %s, %s)" % [_key_text(0), _key_text(3), _key_text(9)])
	_check(InputMap.action_has_event(&"ui_accept", _joy(JOY_BUTTON_A)), "A entra em ui_accept")
	_check(InputMap.action_has_event(&"ui_cancel", _joy(JOY_BUTTON_B)), "B entra em ui_cancel")


func _joy(b: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.device = -1
	return ev


func _test_walk() -> void:
	_moves.clear()
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(4)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(2)
	_check(not _moves.is_empty() and _moves[0].x > 0.5 and absf(_moves[0].z) < 0.5,
			"analógico para a direita → passo para +X %s" % [_moves.slice(0, 1)])
	var n: int = _moves.size()
	await _frames(4)
	_check(_moves.size() == n, "soltar o analógico para de andar")
	_moves.clear()
	_button(JOY_BUTTON_DPAD_UP, true)
	await _frames(4)
	_button(JOY_BUTTON_DPAD_UP, false)
	await _frames(2)
	_check(not _moves.is_empty() and _moves[0].z < -0.5, "D-pad para cima → passo para a frente (-Z) %s" % [_moves.slice(0, 1)])


func _test_action_button() -> void:
	var npc: NetEntity = _entity(NPC_ID, NetEntity.KIND_NPC, Vector3(1.5, 0.0, 0.0), "Vendedora")
	var mon_a: NetEntity = _entity(MON_A, NetEntity.KIND_MONSTER, Vector3(3.0, 0.0, 0.0), "Lobo")
	var mon_b: NetEntity = _entity(MON_B, NetEntity.KIND_MONSTER, Vector3(6.0, 0.0, 0.0), "Urso")
	await _frames(1)
	_actions.clear()
	await _tap(JOY_BUTTON_A)
	_check(_actions == [[&"talk", NPC_ID]] and _net.last_call(&"send_interact") == ["e:%d" % NPC_ID],
			"A com NPC perto → conversa %s" % [_actions])
	npc.free()
	var drop: NetEntity = _entity(DROP_ID, NetEntity.KIND_DROP, Vector3(0.0, 0.0, 1.0), "")
	await _frames(1)
	_actions.clear()
	await _tap(JOY_BUTTON_A)
	_check(_actions == [[&"pickup", DROP_ID]], "A com item no chão → pega %s" % [_actions])
	drop.free()
	await _frames(1)
	_actions.clear()
	await _tap(JOY_BUTTON_A)
	_check(_actions == [[&"target", MON_A]] and NetCombat.client_attack_target == MON_A,
			"A sem nada perto → trava o monstro mais perto %s" % [_actions])
	_actions.clear()
	await _tap(JOY_BUTTON_A)
	_check(_actions == [[&"attack", MON_A]], "A com alvo travado → ataca %s" % [_actions])
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(NetCombat.client_attack_target == MON_B, "RB → próximo alvo")
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(NetCombat.client_attack_target == MON_A, "LB → alvo anterior")
	await _tap(JOY_BUTTON_B)
	_check(NetCombat.client_attack_target == 0 and _ui.combat_assist.current_target < 0, "B sem janela → solta o alvo")
	await _tap(JOY_BUTTON_RIGHT_STICK)
	_check(NetCombat.client_attack_target == MON_A, "R3 → trava o mais perto")
	await _tap(JOY_BUTTON_RIGHT_STICK)
	_check(NetCombat.client_attack_target == 0, "R3 de novo → solta")
	mon_a.free()
	mon_b.free()
	# Objeto clicável do mapa (portal/altar): A usa como um clique ("m:<id>").
	var map_script := GDScript.new()
	map_script.source_code = "extends Node3D\nfunc get_interactables() -> Dictionary:\n\treturn {\"portal_test\": {\"type\": &\"portal\", \"position\": Vector3(0, 0, 2)}}\n"
	map_script.reload()
	var map_node := Node3D.new()
	map_node.name = "Map"
	map_node.set_script(map_script)
	_ents.get_parent().add_child(map_node)
	var clicked: Array[String] = []
	_view.interact_requested.connect(func(t: String) -> void: clicked.append(t))
	await _frames(1)
	_actions.clear()
	await _tap(JOY_BUTTON_A)
	_check(_actions == [[&"use", -1]] and clicked == ["m:portal_test"], "A perto de objeto do mapa → usa %s" % [clicked])
	map_node.free()
	# Câmera no analógico direito.
	var yaw: float = _view.camera_yaw
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(5)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(1)
	_check(not is_equal_approx(_view.camera_yaw, yaw), "analógico direito gira a câmera")


func _test_menu() -> void:
	await _tap(JOY_BUTTON_START)
	await _frames(2)
	var panel: Control = _ui.gear.menu_panel
	_check(panel.visible, "Start abre o menu da engrenagem")
	var f: Control = _focus()
	_check(f != null and panel.is_ancestor_of(f), "foco no primeiro item do menu (%s)" % [f.name if f else "nenhum"])
	_check(_ui.gamepad_hints.context == GamepadHints.CONTEXT_MENU, "dicas trocam para o menu")
	await _shot("gamepad_menu")
	var first: Control = f
	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check(_focus() != null and _focus() != first and panel.is_ancestor_of(_focus()), "D-pad desce no menu")
	await _tap(JOY_BUTTON_B)
	await _frames(1)
	_check(not panel.visible, "B fecha o menu")
	_check(_focus() == null or not _focus().is_visible_in_tree(), "foco sai da interface ao fechar")
	# Start → A no primeiro item (Skills) abre a janela; foco vai para ela; B fecha.
	await _tap(JOY_BUTTON_START)
	await _frames(2)
	await _tap(JOY_BUTTON_A)
	await _frames(3)
	var skills: GameWindow = _ui.progression.skills_window
	_check(skills.visible and not panel.visible, "A no item do menu abre a janela (Skills)")
	_check(_focus() != null and skills.is_ancestor_of(_focus()), "foco entra na janela aberta")
	await _tap(JOY_BUTTON_B)
	_check(not skills.visible, "B fecha a janela")
	await _tap(JOY_BUTTON_START)
	await _tap(JOY_BUTTON_START)
	_check(not panel.visible, "Start de novo fecha o menu")


func _test_dialogue() -> void:
	var options: Array[String] = ["DLG_OPT_A", "DLG_OPT_B", "DLG_OPT_C"]
	_net.dialogue_opened.emit(NPC_ID, "NPC", "DLG_TEXT", options)
	await _frames(3)
	var f: Control = _focus()
	_check(f != null and f.name == &"Option0", "diálogo abre com foco na 1ª opção (%s)" % [f.name if f else "nenhum"])
	await _shot("gamepad_dialogue")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check(_focus() != null and _focus().name == &"Option1", "D-pad desce para a 2ª opção")
	await _tap(JOY_BUTTON_A)
	_check(_net.last_call(&"send_dialogue_choice") == [1], "A escolhe a opção → send_dialogue_choice(1)")
	var closes: int = _net.count(&"send_dialogue_close")
	await _tap(JOY_BUTTON_B)
	_check(not _ui.dialogue.visible and _net.count(&"send_dialogue_close") == closes + 1, "B fecha o diálogo")


func _test_hotbar() -> void:
	var progress: Dictionary = NetProgress.client_progress.duplicate(true)
	var bar: Array = []
	for i: int in 10:
		bar.append("")
	bar[0] = "machete"
	progress["hotbar"] = bar
	_ui.progression._on_progress_changed(progress)
	await _frames(1)
	_slots_used.clear()
	await _tap(JOY_BUTTON_X)
	_check(_slots_used == [0], "X → espaço 1 %s" % [_slots_used])
	_check(_ui.toasts.get_texts().has(tr("UI_HOTBAR_ALREADY_EQUIPPED")),
			"espaço 1 (equipamento já vestido) passou pelo caminho real da barra")
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(2)
	await _tap(JOY_BUTTON_Y)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(2)
	await _tap(JOY_BUTTON_A)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _frames(2)
	_check(_slots_used == [0, 3, 9], "RT+Y → espaço 4, LT+A → espaço 0 %s" % [_slots_used])
	await _tap(JOY_BUTTON_Y)
	_check(_slots_used == [0, 3, 9, 1], "Y → espaço 2 %s" % [_slots_used])
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(2)
	await _tap(JOY_BUTTON_B)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(2)
	await _tap(JOY_BUTTON_B)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _frames(2)
	_check(_slots_used == [0, 3, 9, 1, 4, 8], "RT+B e LT+B usam skills em vez de voltar %s" % [_slots_used])


func _test_controller_status() -> void:
	_ui.settings.open()
	await _frames(2)
	_check(_ui.settings.pad_status.text.contains(str(ProjectSettings.get_setting("application/config/version"))) and _ui.settings.pad_status.text.contains(tr("UI_PAD_STATUS_NONE")),
			"configurações mostram versão e ausência de hardware real")
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(2)
	_check(not _ui.settings.get("_last_pad_event").is_empty() and _ui.settings.pad_status.text.contains("Joypad"),
			"diagnóstico confirma o comando recebido mesmo com a janela aberta")
	await _tap(JOY_BUTTON_B)
	_check(not _ui.settings.visible, "B fecha configurações após testar o controle")


func _test_touch_switch() -> void:
	GameSettings.get_instance().mobile_controls = true
	_ui.set_mobile_mode(true)
	await _frames(2)
	var mc: MobileControlsOverlay = _ui.mobile_controls
	var tray: Control = _ui.progression.hotbar.find_child("Tray", true, false) as Control
	_check(mc != null and not mc.visible, "modo celular + controle: controles de toque escondidos")
	_check(tray != null and tray.visible, "barra de atalhos volta a aparecer com o controle")
	await _shot("gamepad_mobile")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(640, 200)
	touch.pressed = true
	Input.parse_input_event(touch)
	await _frames(2)
	touch.pressed = false
	Input.parse_input_event(touch)
	await _frames(2)
	_check(mc.visible and not _ui.gamepad_hints.visible and _key_text(0) == "1",
			"tocar a tela devolve os controles de toque (opcionais com controle)")
	_axis(JOY_AXIS_RIGHT_Y, -1.0)
	await _frames(2)
	_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await _frames(2)
	_check(not mc.visible and _ui.gamepad_hints.visible, "usar o controle esconde o toque de novo")
	GamepadInput.simulate_connected = false
	Input.joy_connection_changed.emit(0, false)
	await _frames(2)
	_check(mc.visible and not _ui.gamepad_hints.visible and tray != null and not tray.visible,
			"desconectar o controle devolve os controles de toque")
	GamepadInput.simulate_connected = true
	Input.joy_connection_changed.emit(0, true)
	await _frames(2)
	_check(not mc.visible and _ui.gamepad_hints.visible, "reconectar esconde o toque")
	GameSettings.get_instance().mobile_controls = false
	_ui.set_mobile_mode(false)


func _test_title() -> void:
	_view.queue_free()
	await _frames(2)
	CharacterSlots.path = OS.get_temp_dir().path_join("test_gamepad_slots_%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(CharacterSlots.path)
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.apply_video_settings = false
	add_child(title)
	var played: Array = []
	title.play_requested.connect(func(n: String, b: StringName, _h: String, _p: int) -> void: played.append([n, b]))
	await _frames(SETTLE_FRAMES + 4)
	title.set_fields("Iracema", &"female", "127.0.0.1", 7788)
	get_viewport().gui_release_focus()
	await _tap(JOY_BUTTON_A)
	var play: Control = title.find_child("Play", true, false) as Control
	_check(_focus() == play, "título: 1º botão do controle põe o foco em Criar/Jogar")
	_check((title.get(&"_pad_hints") as Control).visible, "título: dicas do controle visíveis")
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(title.current_creation_tab() == 1, "título: RB → próxima aba")
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(title.current_creation_tab() == 0, "título: LB → aba anterior")
	await _tap(JOY_BUTTON_DPAD_DOWN)
	_check(_focus() != null and _focus() != title.find_child("TabBody", true, false), "título: D-pad move o foco")
	var name_edit: LineEdit = title.find_child("NameEdit", true, false) as LineEdit
	name_edit.grab_focus()
	name_edit.unedit()
	await _tap(JOY_BUTTON_A)
	_check(name_edit.is_editing(), "título: A no nome começa a editar (teclado virtual no Android)")
	await _tap(JOY_BUTTON_B)
	_check(not name_edit.is_editing() and name_edit.has_focus(), "título: B para de editar")
	await _shot("gamepad_title")
	await _tap(JOY_BUTTON_START)
	_check(played == [["Iracema", &"female"]], "título: Start = Jogar/Criar %s" % [played])
	title.queue_free()
	DirAccess.remove_absolute(CharacterSlots.path)
