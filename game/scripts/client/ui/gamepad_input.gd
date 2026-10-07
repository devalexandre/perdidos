class_name GamepadInput
extends Node
## Controle físico (layout Xbox: Xbox/8BitDo no PC; GameSir X5 Lite e outros joypads padrão no Android)
## no jogo, sem quebrar teclado/mouse nem o toque. Filho do GameUI (refeito junto com ele).
##
## Mundo: analógico esquerdo / D-pad anda (mesmo passo em grade do analógico virtual, via CombatAssist);
## A age (ataca o alvo, pega item, conversa com NPC ou trava o monstro mais perto); B volta (fecha a janela
## do topo, cancela a mira, solta o alvo); X/Y = espaços 1/2 da barra; RT + X/Y/B/A = 3–6; LT + X/Y/B/A =
## 7–0; LB/RB = alvo anterior/próximo; R3 = trava/solta o mais perto; L3 = poção rápida; analógico direito
## gira a câmera (X) e dá zoom (Y); Start = menu (engrenagem); Select = mapa.
## Interface: janela/diálogo/menu aberto = modo navegação: o foco vai para o primeiro botão, D-pad/analógico
## movem o foco (ui_*), A confirma (ui_accept), B volta. Skills de área: o analógico esquerdo mira, A (ou o
## mesmo botão) solta, B cancela.
## Modo controle (is_pad_mode) = há controle conectado e o último toque/tecla/clique veio dele: os controles
## de toque somem, a barra mostra os botões do controle e aparece a faixa de dicas. Tocar a tela, teclar ou
## clicar volta ao modo anterior; qualquer botão do controle volta ao modo controle.

signal mode_changed(pad_mode: bool)
## Espaço da barra usado pelo controle (0 = tecla 1).
signal slot_used(index: int)

const ACTION_LEFT: StringName = &"pad_move_left"
const ACTION_RIGHT: StringName = &"pad_move_right"
const ACTION_UP: StringName = &"pad_move_up"
const ACTION_DOWN: StringName = &"pad_move_down"
const ACTION_CAM_LEFT: StringName = &"pad_camera_left"
const ACTION_CAM_RIGHT: StringName = &"pad_camera_right"
const ACTION_ZOOM_IN: StringName = &"pad_zoom_in"
const ACTION_ZOOM_OUT: StringName = &"pad_zoom_out"
const ACTION_A: StringName = &"pad_a"
const ACTION_B: StringName = &"pad_b"
const ACTION_X: StringName = &"pad_x"
const ACTION_Y: StringName = &"pad_y"
const ACTION_LB: StringName = &"pad_lb"
const ACTION_RB: StringName = &"pad_rb"
const ACTION_LT: StringName = &"pad_lt"
const ACTION_RT: StringName = &"pad_rt"
const ACTION_L3: StringName = &"pad_l3"
const ACTION_R3: StringName = &"pad_r3"
const ACTION_START: StringName = &"pad_start"
const ACTION_SELECT: StringName = &"pad_select"
const ANY_DEVICE: int = -1
const STICK_DEADZONE: float = 0.25
const TRIGGER_DEADZONE: float = 0.5
## Eixo acima disso conta como "usou o controle" (deriva do analógico não troca o modo).
const ACTIVITY_AXIS: float = 0.5
## Botão → ação (os de face também entram em ui_accept/ui_cancel para a navegação da interface).
const BUTTON_ACTIONS: Dictionary[StringName, JoyButton] = {
	ACTION_A: JOY_BUTTON_A, ACTION_B: JOY_BUTTON_B, ACTION_X: JOY_BUTTON_X, ACTION_Y: JOY_BUTTON_Y,
	ACTION_LB: JOY_BUTTON_LEFT_SHOULDER, ACTION_RB: JOY_BUTTON_RIGHT_SHOULDER,
	ACTION_L3: JOY_BUTTON_LEFT_STICK, ACTION_R3: JOY_BUTTON_RIGHT_STICK,
	ACTION_START: JOY_BUTTON_START, ACTION_SELECT: JOY_BUTTON_BACK,
}
## Barra de atalhos: botão de face por camada (sem gatilho / RT segurado / LT segurado) → espaço (0 = tecla 1).
const SLOTS_BASE: Dictionary[StringName, int] = {ACTION_X: 0, ACTION_Y: 1}
const SLOTS_RT: Dictionary[StringName, int] = {ACTION_X: 2, ACTION_Y: 3, ACTION_B: 4, ACTION_A: 5}
const SLOTS_LT: Dictionary[StringName, int] = {ACTION_X: 6, ACTION_Y: 7, ACTION_B: 8, ACTION_A: 9}
## Rótulo de cada espaço da barra no modo controle.
const SLOT_LABELS: Array[String] = ["X", "Y", "RT+X", "RT+Y", "RT+B", "RT+A", "LT+X", "LT+Y", "LT+B", "LT+A"]
## Graus/s da câmera no analógico direito todo inclinado e zoom/s.
const CAMERA_DEG_PER_SEC: float = 120.0
const ZOOM_PER_SEC: float = 1.2
## Meta guardada nos controles que só ganharam foco por causa do controle (desfeito ao sair do modo).
const META_FOCUS_PATCHED: StringName = &"pad_focus_patched"

## Testes e capturas: finge um controle conectado (sem hardware).
static var simulate_connected: bool = false

var game_ui: GameUI = null
var assist: CombatAssist = null
var hints: GamepadHints = null
var focus_ring: FocusRing = null

var _pad_mode: bool = false
var _using_pad: bool = true
var _walking: bool = false
var _aim_slot_action: StringName = &""
var _patched: Array[Control] = []


func _init(p_game_ui: GameUI = null, p_assist: CombatAssist = null) -> void:
	game_ui = p_game_ui
	assist = p_assist
	name = &"GamepadInput"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	register_actions()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_using_pad = is_connected_any()
	_refresh_mode()


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	_restore_focus_modes()


# --- Estado ---------------------------------------------------------------------------------------

## Há controle (ou simulado) conectado.
static func is_connected_any() -> bool:
	return simulate_connected or not Input.get_connected_joypads().is_empty()


## Modo controle: conectado e o último uso foi o controle.
func is_pad_mode() -> bool:
	return _pad_mode


## Força o modo (testes/capturas e quando o controle conecta).
func set_using_pad(value: bool) -> void:
	_using_pad = value
	_refresh_mode()


func _refresh_mode() -> void:
	var want: bool = is_connected_any() and _using_pad
	if want == _pad_mode:
		return
	_pad_mode = want
	if not _pad_mode:
		_walking = false
		if assist != null:
			assist.stop_walk()
		_release_patched_focus()
		_restore_focus_modes()
	mode_changed.emit(_pad_mode)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		_using_pad = true
	_refresh_mode()


# --- Ações no InputMap ----------------------------------------------------------------------------

## Registra as ações pad_* e acrescenta A/B a ui_accept/ui_cancel (navegação da interface do Godot).
## Idempotente; também usado pela tela de título.
static func register_actions() -> void:
	_add_axis(ACTION_LEFT, JOY_AXIS_LEFT_X, -1.0, STICK_DEADZONE)
	_add_axis(ACTION_RIGHT, JOY_AXIS_LEFT_X, 1.0, STICK_DEADZONE)
	_add_axis(ACTION_UP, JOY_AXIS_LEFT_Y, -1.0, STICK_DEADZONE)
	_add_axis(ACTION_DOWN, JOY_AXIS_LEFT_Y, 1.0, STICK_DEADZONE)
	_add_button(ACTION_LEFT, JOY_BUTTON_DPAD_LEFT)
	_add_button(ACTION_RIGHT, JOY_BUTTON_DPAD_RIGHT)
	_add_button(ACTION_UP, JOY_BUTTON_DPAD_UP)
	_add_button(ACTION_DOWN, JOY_BUTTON_DPAD_DOWN)
	_add_axis(ACTION_CAM_LEFT, JOY_AXIS_RIGHT_X, -1.0, STICK_DEADZONE)
	_add_axis(ACTION_CAM_RIGHT, JOY_AXIS_RIGHT_X, 1.0, STICK_DEADZONE)
	_add_axis(ACTION_ZOOM_IN, JOY_AXIS_RIGHT_Y, -1.0, STICK_DEADZONE)
	_add_axis(ACTION_ZOOM_OUT, JOY_AXIS_RIGHT_Y, 1.0, STICK_DEADZONE)
	_add_axis(ACTION_LT, JOY_AXIS_TRIGGER_LEFT, 1.0, TRIGGER_DEADZONE)
	_add_axis(ACTION_RT, JOY_AXIS_TRIGGER_RIGHT, 1.0, TRIGGER_DEADZONE)
	for action: StringName in BUTTON_ACTIONS:
		_add_button(action, BUTTON_ACTIONS[action])
	_add_button(&"ui_accept", JOY_BUTTON_A)
	_add_button(&"ui_cancel", JOY_BUTTON_B)


static func _add_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and (existing as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = ANY_DEVICE
	InputMap.action_add_event(action, ev)


static func _add_axis(action: StringName, axis: JoyAxis, value: float, deadzone: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion and (existing as InputEventJoypadMotion).axis == axis \
				and signf((existing as InputEventJoypadMotion).axis_value) == signf(value):
			return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = ANY_DEVICE
	InputMap.action_add_event(action, ev)


## Evento que mostra uso real do controle (botão apertado ou eixo bem inclinado).
static func is_pad_activity(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= ACTIVITY_AXIS
	return false


## Evento que mostra uso de teclado, mouse (clique) ou toque real (não emulado).
static func is_other_activity(event: InputEvent) -> bool:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return false
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		return event.is_pressed()
	return false


## Campo de texto com o controle: A começa a editar (abre o teclado virtual no Android), A/B param.
## true = consumiu o evento. Usado aqui e nas telas de título/conta.
static func handle_line_edit(event: InputEvent, viewport: Viewport) -> bool:
	if not (event is InputEventJoypadButton) or not event.is_pressed():
		return false
	var le := viewport.gui_get_focus_owner() as LineEdit
	if le == null or not le.is_visible_in_tree():
		return false
	var button: JoyButton = (event as InputEventJoypadButton).button_index
	if button == JOY_BUTTON_A and not le.is_editing() and le.editable:
		le.edit()
		return true
	if (button == JOY_BUTTON_A or button == JOY_BUTTON_B) and le.is_editing():
		le.unedit()
		return true
	return false


# --- Foco da interface ----------------------------------------------------------------------------

## Deixa focáveis (para o controle) os botões/espaços de root que nasceram sem foco (FOCUS_NONE: teclado
## não rouba Espaço/Enter). Desfeito por restore_focus_modes quando o controle deixa de ser usado.
static func enable_focus(root: Node, patched: Array[Control] = []) -> void:
	if root == null:
		return
	for n: Node in root.find_children("*", "Control", true, false):
		var c := n as Control
		# Texto escuro no pergaminho: com foco continua com a cor normal (o tema clareia o texto focado).
		if c is Button and c.has_theme_color_override(&"font_color") \
				and not c.has_theme_color_override(&"font_focus_color"):
			c.add_theme_color_override(&"font_focus_color", c.get_theme_color(&"font_color"))
		if c.focus_mode == Control.FOCUS_NONE and (c is BaseButton or c is ItemSlot or c is Range):
			c.focus_mode = Control.FOCUS_ALL
			c.set_meta(META_FOCUS_PATCHED, true)
			patched.append(c)
	if root is Control and root is BaseButton and (root as Control).focus_mode == Control.FOCUS_NONE:
		(root as Control).focus_mode = Control.FOCUS_ALL
		root.set_meta(META_FOCUS_PATCHED, true)
		patched.append(root as Control)


## Primeiro controle focável e visível de root (pula o "X" de fechar: B já fecha).
static func first_focusable(root: Node) -> Control:
	if root == null:
		return null
	var fallback: Control = null
	for n: Node in root.find_children("*", "Control", true, false):
		var c := n as Control
		if c.focus_mode == Control.FOCUS_NONE or not c.is_visible_in_tree():
			continue
		if c is BaseButton and (c as BaseButton).disabled:
			continue
		if c is LineEdit:
			continue
		if c.name == &"Close":
			if fallback == null:
				fallback = c
			continue
		return c
	return fallback


func _restore_focus_modes() -> void:
	for c: Control in _patched:
		if is_instance_valid(c) and c.has_meta(META_FOCUS_PATCHED):
			c.remove_meta(META_FOCUS_PATCHED)
			if c.has_focus():
				c.release_focus()
			c.focus_mode = Control.FOCUS_NONE
	_patched.clear()


func _release_patched_focus() -> void:
	var vp: Viewport = get_viewport()
	var f: Control = vp.gui_get_focus_owner() if vp != null else null
	if f != null and not (f is LineEdit):
		f.release_focus()


## Interface "modal" aberta no topo (onde o foco do controle deve ficar) ou null = mundo.
func top_ui_root() -> Control:
	if game_ui == null or not is_instance_valid(game_ui):
		return null
	for c: Control in [game_ui.player_menu, game_ui.trade_request, game_ui.party_invite]:
		if c != null and is_instance_valid(c) and c.visible:
			return c
	if game_ui.dialogue != null and game_ui.dialogue.visible and game_ui.dialogue.get_option_count() > 0:
		return game_ui.dialogue
	if game_ui.gear != null:
		if game_ui.gear.menu_panel.visible:
			return game_ui.gear.menu_panel
		if game_ui.gear.emote_panel.visible:
			return game_ui.gear.emote_panel
	var mc: MobileControlsOverlay = game_ui.mobile_controls
	if mc != null and is_instance_valid(mc) and mc.config_dialog != null and mc.config_dialog.is_visible_in_tree():
		return mc.config_dialog
	if game_ui.world_atlas != null and game_ui.world_atlas.visible:
		return game_ui.world_atlas
	if game_ui.windows_layer != null:
		var kids: Array[Node] = game_ui.windows_layer.get_children()
		for i: int in range(kids.size() - 1, -1, -1):
			if kids[i] is GameWindow and (kids[i] as GameWindow).visible:
				return kids[i] as Control
	if game_ui.dialogue != null and game_ui.dialogue.visible:
		return game_ui.dialogue
	return null


func _area_map() -> WorldMap:
	var minimap: Minimap = game_ui.get_parent().get_node_or_null(^"Minimap") as Minimap \
			if game_ui != null and game_ui.get_parent() != null else null
	return minimap.world_map if minimap != null and is_instance_valid(minimap.world_map) else null


## Modo navegação: põe o foco no primeiro botão da interface do topo (se ainda não estiver nela).
func _update_focus() -> void:
	var vp: Viewport = get_viewport()
	var owner_c: Control = vp.gui_get_focus_owner()
	if owner_c is LineEdit and (owner_c as LineEdit).is_editing():
		return
	var root: Control = top_ui_root()
	if root == null:
		if owner_c != null and owner_c.has_meta(META_FOCUS_PATCHED):
			owner_c.release_focus()
		return
	enable_focus(root, _patched)
	if owner_c != null and owner_c.is_visible_in_tree() and root.is_ancestor_of(owner_c):
		return
	var first: Control = first_focusable(root)
	if first != null:
		first.grab_focus()


# --- Entrada --------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if is_pad_activity(event):
		if not _using_pad:
			_using_pad = true
			_refresh_mode()
	elif is_other_activity(event) and _using_pad and _pad_mode:
		_using_pad = false
		_refresh_mode()
	if handle_line_edit(event, get_viewport()):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if not event.is_pressed() or game_ui == null:
		return
	if handle_button(event):
		get_viewport().set_input_as_handled()


## Trata um botão do controle que a interface não consumiu. true = usou.
func handle_button(event: InputEvent) -> bool:
	if event.is_action_pressed(ACTION_START):
		_toggle_menu()
		return true
	if event.is_action_pressed(ACTION_SELECT):
		game_ui._toggle_map_views()
		return true
	if game_ui.is_typing() or top_ui_root() != null:
		return back() if event.is_action_pressed(ACTION_B) else false
	var prog: ProgressionHud = game_ui.progression
	if prog != null and is_instance_valid(prog.aim) and prog.aim.is_aiming() and prog.aim.mobile_drag:
		if event.is_action_pressed(ACTION_B):
			return back()
		if event.is_action_pressed(ACTION_A) or (_aim_slot_action != &"" and event.is_action_pressed(_aim_slot_action)):
			prog.aim.finish_mobile(false)
			_aim_slot_action = &""
			return true
		return false
	var layer: Dictionary[StringName, int] = SLOTS_BASE
	if Input.is_action_pressed(ACTION_RT):
		layer = SLOTS_RT
	elif Input.is_action_pressed(ACTION_LT):
		layer = SLOTS_LT
	for action: StringName in layer:
		if event.is_action_pressed(action):
			use_slot(layer[action], action)
			return true
	if event.is_action_pressed(ACTION_B):
		return back()
	if event.is_action_pressed(ACTION_A):
		if assist != null:
			assist.smart_action()
		return true
	if event.is_action_pressed(ACTION_LB) or event.is_action_pressed(ACTION_RB):
		if assist != null:
			assist.cycle_target(-1 if event.is_action_pressed(ACTION_LB) else 1)
		return true
	if event.is_action_pressed(ACTION_R3):
		if assist != null:
			if assist.current_target >= 0:
				assist.clear_target()
			else:
				assist.cycle_target(1)
		return true
	if event.is_action_pressed(ACTION_L3):
		if assist != null:
			assist.quick_potion()
		return true
	return false


## Usa o espaço da barra (skills de área entram na mira por analógico, como no toque).
func use_slot(index: int, action: StringName = &"") -> void:
	var prog: ProgressionHud = game_ui.progression
	if prog == null:
		return
	if is_instance_valid(prog.aim) and prog.aim.is_aiming():
		prog.aim.cancel(false)
	prog.use_slot(index, true)
	slot_used.emit(index)
	if is_instance_valid(prog.aim) and prog.aim.is_aiming():
		_aim_slot_action = action
		prog.aim.update_mobile_direction(_stick())


## B: cancela a mira, fecha o que estiver no topo (menu, diálogo, janela, mapa) ou solta o alvo.
func back() -> bool:
	var prog: ProgressionHud = game_ui.progression
	if prog != null and is_instance_valid(prog.aim) and prog.aim.is_aiming():
		if prog.aim.mobile_drag:
			prog.aim.finish_mobile(true)
		else:
			prog.aim.cancel()
		_aim_slot_action = &""
		return true
	var mc: MobileControlsOverlay = game_ui.mobile_controls
	if mc != null and is_instance_valid(mc) and mc.config_dialog != null and mc.config_dialog.visible:
		mc.config_dialog.visible = false
		return true
	var root: Control = top_ui_root()
	if root is GameWindow and root != game_ui.trade_window:
		(root as GameWindow).close()
		return true
	if root == game_ui.world_atlas:
		game_ui.world_atlas.close()
		return true
	if game_ui.close_top():
		return true
	if prog != null:
		for w: GameWindow in [prog.quest_log, prog.attributes_window, prog.skills_window, game_ui.crendice_altar]:
			if w != null and w.visible:
				w.close()
				return true
	var area: WorldMap = _area_map()
	if area != null and area.visible:
		area.visible = false
		return true
	if assist != null and assist.current_target >= 0:
		assist.clear_target()
		return true
	return false


func _toggle_menu() -> void:
	if game_ui.gear == null:
		return
	game_ui.gear.toggle_menu()


func _stick() -> Vector2:
	return Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)


func _process(delta: float) -> void:
	if game_ui == null or not is_instance_valid(game_ui):
		return
	if not _pad_mode:
		if not is_connected_any():
			return
		_refresh_mode()
		if not _pad_mode:
			return
	_update_focus()
	if hints != null:
		hints.set_context(_context())
	var prog: ProgressionHud = game_ui.progression
	var aiming: bool = prog != null and is_instance_valid(prog.aim) and prog.aim.is_aiming() and prog.aim.mobile_drag
	var free_world: bool = top_ui_root() == null and not game_ui.is_typing()
	var dir: Vector2 = _stick()
	if aiming:
		prog.aim.update_mobile_direction(dir)
	elif free_world and dir != Vector2.ZERO and assist != null:
		assist.walk(dir)
		_walking = true
	elif _walking:
		_walking = false
		if assist != null:
			assist.stop_walk()
	if free_world:
		_update_camera(delta)


func _update_camera(delta: float) -> void:
	var view: ClientView = assist.client_view if assist != null else null
	if view == null or not is_instance_valid(view):
		return
	var turn: float = Input.get_axis(ACTION_CAM_LEFT, ACTION_CAM_RIGHT)
	if turn != 0.0:
		view.camera_yaw -= turn * deg_to_rad(CAMERA_DEG_PER_SEC) * delta
	var zoom: float = Input.get_axis(ACTION_ZOOM_OUT, ACTION_ZOOM_IN)
	if zoom != 0.0:
		view.camera_zoom = clampf(view.camera_zoom + zoom * ZOOM_PER_SEC * delta,
				Balance.cfg.camera_zoom_min, Balance.cfg.camera_zoom_max)


## Contexto das dicas na tela.
func _context() -> StringName:
	var prog: ProgressionHud = game_ui.progression
	if prog != null and is_instance_valid(prog.aim) and prog.aim.is_aiming():
		return GamepadHints.CONTEXT_AIM
	if top_ui_root() != null:
		return GamepadHints.CONTEXT_MENU
	return GamepadHints.CONTEXT_WORLD


# --- Anel de foco ---------------------------------------------------------------------------------

## Moldura dourada em volta do controle com foco (muitos botões do jogo não têm estilo de foco próprio).
## Desenha por cima de tudo; some sem foco ou fora do modo controle.
class FocusRing extends Control:
	var pad: GamepadInput = null
	var ui_scale: float = 1.0
	## Sem GamepadInput (tela de título): mostra quando o último uso foi o controle.
	var active: bool = false

	func _init(p_scale: float = 1.0) -> void:
		ui_scale = p_scale
		name = &"PadFocusRing"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = true
		z_index = RenderingServer.CANVAS_ITEM_Z_MAX
		focus_mode = Control.FOCUS_NONE

	func _process(_delta: float) -> void:
		var on: bool = pad.is_pad_mode() if pad != null and is_instance_valid(pad) else active
		var f: Control = get_viewport().gui_get_focus_owner() if on else null
		if f == null or not f.is_visible_in_tree():
			visible = false
			return
		var r: Rect2 = f.get_global_rect()
		var grow: float = UIKit.px(3, ui_scale)
		global_position = r.position - Vector2(grow, grow)
		size = r.size + Vector2(grow, grow) * 2.0
		visible = true
		queue_redraw()

	func _draw() -> void:
		var w: float = maxf(2.0, UIKit.px(3, ui_scale))
		var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 160.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(UIKit.COLOR_OUTLINE, 0.8), false, w + 2.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(UIKit.COLOR_GOLD_LIGHT, pulse), false, w)
