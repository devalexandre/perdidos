class_name MobileActionCluster
extends Control
## Cluster de ação e combate mobile (GDD §9.5, Mobile standard):
## Fica no canto inferior direito para controle ergonômico com o polegar:
## - Botão central de ataque / ação inteligente;
## - 4 slots circulares de habilidades/itens em arco;
## - Botão de trava e ciclo de alvo;
## - Botão de uso rápido de poção;
## - Botão de configuração dos 4 atalhos.

signal attack_activated
signal slot_activated(index: int)
signal target_cycle_activated
signal quick_potion_activated
signal config_requested
signal aim_direction_changed(direction: Vector2)
signal aim_finished(cancelled_gesture: bool)

const AIM_RADIUS_PX: float = 70.0
const CANCEL_RADIUS_PX: float = 26.0
const MOUSE_POINTER: int = -2
var _press_pointer: int = -1
var _aim_pointer: int = -1
var _aim_slot: int = -1
var _aim_offset: Vector2 = Vector2.ZERO
var _aim_cancelled: bool = false

const CLUSTER_SIZE_PX: float = 270.0
const ATTACK_RADIUS_PX: float = 40.0
const SLOT_RADIUS_PX: float = 28.0
const AUX_RADIUS_PX: float = 24.0
const ARC_DISTANCE_PX: float = 126.0

# Arco interno: nenhum botão ultrapassa a borda direita da tela.
const SLOT_ANGLES: Array[float] = [PI, PI * 5.0 / 6.0, PI * 2.0 / 3.0, PI * 0.5]

var ui_scale: float = 1.0
## Dados dos 4 slots: { "id": StringName, "icon": Texture2D, "cd_pct": float, "cd_sec": int, "mp": int, "pressed": bool }
var _slots_data: Array[Dictionary] = []
var _attack_pressed: bool = false
var _target_pressed: bool = false
var _potion_pressed: bool = false
var _config_pressed: bool = false

var _potion_count: int = 0
var _potion_icon: Texture2D = null
var _attack_icon: Texture2D = null

# Posições calculadas relativas
var _attack_pos: Vector2 = Vector2.ZERO
var _slot_positions: Array[Vector2] = []
var _target_pos: Vector2 = Vector2.ZERO
var _potion_pos: Vector2 = Vector2.ZERO
var _config_pos: Vector2 = Vector2.ZERO


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"MobileActionCluster"
	mouse_filter = Control.MOUSE_FILTER_PASS
	for i: int in 4:
		_slots_data.append({
			"id": &"",
			"icon": null,
			"cd_pct": 0.0,
			"cd_sec": 0,
			"mp": 0,
			"pressed": false
		})
	_attack_icon = load("res://assets/items/icons/icon_item_short_sword.png") as Texture2D
	_potion_icon = load("res://assets/items/icons/icon_item_potion_hp_small.png") as Texture2D
	_recalculate_layout()


func set_ui_scale(p_scale: float) -> void:
	ui_scale = p_scale
	_recalculate_layout()
	queue_redraw()


func _recalculate_layout() -> void:
	var total_size: float = CLUSTER_SIZE_PX * ui_scale
	custom_minimum_size = Vector2(total_size, total_size)
	size = custom_minimum_size

	# Ponto focal do botão de ataque (canto inferior direito com margem ergonômica)
	_attack_pos = Vector2(total_size - (ATTACK_RADIUS_PX + 16.0) * ui_scale,
						  total_size - (ATTACK_RADIUS_PX + 16.0) * ui_scale)

	# 4 slots de skill em arco suave ao redor do botão de ataque
	_slot_positions.clear()
	var arc_dist: float = ARC_DISTANCE_PX * ui_scale
	for angle: float in SLOT_ANGLES:
		var dir := Vector2(cos(angle), -sin(angle)) # -Y para cima
		_slot_positions.append(_attack_pos + dir * arc_dist)

	# Botão de alvo (mira) posicionado acima do arco
	_target_pos = Vector2(112.0, 32.0) * ui_scale

	# Botão de poção rápida posicionado na base à esquerda
	_potion_pos = Vector2(30.0, 239.0) * ui_scale

	# Botão de configuração das skills (engrenagem compacta)
	_config_pos = Vector2(40.0, 32.0) * ui_scale


func set_slot_entry(index: int, entry_id: StringName) -> void:
	if index < 0 or index >= _slots_data.size():
		return
	_slots_data[index]["id"] = entry_id
	var icon: Texture2D = null
	var mp: int = 0
	if not entry_id.is_empty():
		var def: SkillDef = Content.skill(entry_id)
		if def != null:
			icon = HotbarSlot.skill_icon(def)
			mp = def.mana_cost
		else:
			var item_def: ItemDef = Content.item(entry_id)
			if item_def != null:
				icon = item_def.icon if item_def.icon != null else UIKit.item_icon(item_def)
	_slots_data[index]["icon"] = icon
	_slots_data[index]["mp"] = mp
	queue_redraw()


func set_slot_cooldown(index: int, pct: float, remaining_sec: int) -> void:
	if index < 0 or index >= _slots_data.size():
		return
	_slots_data[index]["cd_pct"] = clampf(pct, 0.0, 1.0)
	_slots_data[index]["cd_sec"] = remaining_sec
	queue_redraw()


func set_potion_info(count: int, icon: Texture2D = null) -> void:
	_potion_count = count
	if icon != null:
		_potion_icon = icon
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		accept_event()
		return
	if _aim_slot >= 0:
		accept_event()
		return
	var pos: Vector2 = Vector2.ZERO
	var is_down: bool = false
	var is_up: bool = false

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		pos = touch.position
		is_down = touch.pressed
		is_up = not touch.pressed
		if touch.pressed:
			_press_pointer = touch.index
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			pos = mb.position
			is_down = mb.pressed
			is_up = not mb.pressed
			if mb.pressed:
				_press_pointer = MOUSE_POINTER
	else:
		return

	if is_down:
		_handle_press(pos)
		accept_event()
	elif is_up:
		_handle_release(pos)
		accept_event()


func begin_aim(index: int) -> void:
	_aim_slot = index
	_aim_pointer = _press_pointer
	_aim_offset = Vector2.ZERO
	_aim_cancelled = false
	queue_redraw()


func _cancel_position() -> Vector2:
	return Vector2(64, -44) * ui_scale


func _drag_aim(window_position: Vector2) -> void:
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * window_position
	var offset: Vector2 = local - _slot_positions[_aim_slot]
	var radius: float = AIM_RADIUS_PX * ui_scale
	_aim_cancelled = local.distance_to(_cancel_position()) <= CANCEL_RADIUS_PX * ui_scale \
			or offset.length() > radius * 2.4
	_aim_offset = offset.limit_length(radius)
	aim_direction_changed.emit(_aim_offset / radius)
	queue_redraw()


func _finish_aim(cancel_gesture: bool) -> void:
	if _aim_slot < 0:
		return
	_aim_slot = -1
	_aim_pointer = -1
	_handle_release(Vector2.ZERO)
	aim_finished.emit(cancel_gesture)


## Captura apenas o dedo que iniciou a mira, inclusive fora do retângulo do cluster.
func _input(event: InputEvent) -> void:
	if _aim_slot < 0:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and event.index == _aim_pointer:
		_drag_aim(event.position)
	elif event is InputEventScreenTouch and event.index == _aim_pointer and not event.pressed:
		_drag_aim(event.position)
		_finish_aim(_aim_cancelled or event.canceled)
	elif _aim_pointer == MOUSE_POINTER and event is InputEventMouseMotion:
		_drag_aim(event.position)
	elif _aim_pointer == MOUSE_POINTER and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drag_aim(event.position)
		_finish_aim(_aim_cancelled)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_finish_aim(true)
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		_finish_aim(true)
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_finish_aim(true)


func _handle_press(pos: Vector2) -> void:
	var atk_r: float = ATTACK_RADIUS_PX * ui_scale
	var slot_r: float = SLOT_RADIUS_PX * ui_scale
	var aux_r: float = AUX_RADIUS_PX * ui_scale

	var best_action: String = ""
	var best_index: int = -1
	var min_ratio: float = 1.0

	var d_atk: float = pos.distance_to(_attack_pos) / (atk_r * 1.15)
	if d_atk < min_ratio:
		min_ratio = d_atk
		best_action = "attack"

	for i: int in _slot_positions.size():
		var d_slot: float = pos.distance_to(_slot_positions[i]) / (slot_r * 1.1)
		if d_slot < min_ratio:
			min_ratio = d_slot
			best_action = "slot"
			best_index = i

	var d_tgt: float = pos.distance_to(_target_pos) / (aux_r * 1.2)
	if d_tgt < min_ratio:
		min_ratio = d_tgt
		best_action = "target"

	var d_pot: float = pos.distance_to(_potion_pos) / (aux_r * 1.2)
	if d_pot < min_ratio:
		min_ratio = d_pot
		best_action = "potion"

	var d_cfg: float = pos.distance_to(_config_pos) / (aux_r * 1.2)
	if d_cfg < min_ratio:
		min_ratio = d_cfg
		best_action = "config"

	match best_action:
		"attack":
			_attack_pressed = true
			attack_activated.emit()
		"slot":
			_slots_data[best_index]["pressed"] = true
			slot_activated.emit(best_index)
		"target":
			_target_pressed = true
			target_cycle_activated.emit()
		"potion":
			_potion_pressed = true
			quick_potion_activated.emit()
		"config":
			_config_pressed = true
			config_requested.emit()

	if not best_action.is_empty():
		queue_redraw()


func _handle_release(_pos: Vector2) -> void:
	_attack_pressed = false
	_target_pressed = false
	_potion_pressed = false
	_config_pressed = false
	for s: Dictionary in _slots_data:
		s["pressed"] = false
	queue_redraw()


func _draw() -> void:
	var atk_r: float = ATTACK_RADIUS_PX * ui_scale
	var slot_r: float = SLOT_RADIUS_PX * ui_scale
	var aux_r: float = AUX_RADIUS_PX * ui_scale

	# 1. Desenhar os 4 Slots de Habilidades em Arco
	for i: int in _slot_positions.size():
		_draw_skill_slot(i, _slot_positions[i], slot_r)

	# 2. Desenhar Botão de Alvo / Trava
	_draw_aux_button(_target_pos, aux_r, _target_pressed, Color8(50, 130, 220), &"target")

	# 3. Desenhar Botão de Poção Rápida
	_draw_potion_button(_potion_pos, aux_r + 2.0 * ui_scale, _potion_pressed)

	# 4. Desenhar Botão de Configuração
	_draw_aux_button(_config_pos, aux_r, _config_pressed, Color8(180, 160, 90), &"gear")

	# 5. Desenhar Botão Central de Ataque (Topo de hierarquia visual)
	_draw_attack_button(_attack_pos, atk_r, _attack_pressed)
	if _aim_slot >= 0:
		_draw_aim_control()


func _draw_aim_control() -> void:
	var center: Vector2 = _slot_positions[_aim_slot]
	var radius: float = AIM_RADIUS_PX * ui_scale
	var tint: Color = Color8(255, 100, 100) if _aim_cancelled else Color8(95, 235, 245)
	draw_circle(center, radius, Color(tint, 0.16))
	draw_arc(center, radius, 0, TAU, 64, tint, 2.5 * ui_scale, true)
	draw_line(center, center + _aim_offset, tint, 2.0 * ui_scale, true)
	draw_circle(center + _aim_offset, 20.0 * ui_scale, Color(tint, 0.25))
	draw_arc(center + _aim_offset, 20.0 * ui_scale, 0, TAU, 32, tint, 2.0 * ui_scale, true)
	var cancel: Vector2 = _cancel_position()
	draw_circle(cancel, CANCEL_RADIUS_PX * ui_scale, Color(0.05, 0.08, 0.10, 0.85))
	draw_arc(cancel, CANCEL_RADIUS_PX * ui_scale, 0, TAU, 32, tint, 2.0 * ui_scale, true)
	var arm: float = 9.0 * ui_scale
	draw_line(cancel + Vector2(-arm, -arm), cancel + Vector2(arm, arm), tint, 3.0 * ui_scale, true)
	draw_line(cancel + Vector2(-arm, arm), cancel + Vector2(arm, -arm), tint, 3.0 * ui_scale, true)


func _draw_attack_button(pos: Vector2, r: float, pressed: bool) -> void:
	var eff_r: float = r * (0.92 if pressed else 1.0)
	# Sombra
	draw_circle(pos + Vector2(0, 3.0 * ui_scale), eff_r + 2.0 * ui_scale, Color(0, 0, 0, 0.55))
	# Fundo rubi / bronze
	var bg_col: Color = Color8(150, 35, 35, 235) if pressed else Color8(110, 24, 24, 225)
	draw_circle(pos, eff_r, bg_col)
	# Aro de ouro grosso chanfrado
	var gold_col: Color = Color8(255, 235, 130) if pressed else Color8(218, 175, 65)
	draw_arc(pos, eff_r, 0, TAU, 32, gold_col, maxi(2.0, 3.5 * ui_scale), false)
	draw_arc(pos, eff_r - 3.0 * ui_scale, 0, TAU, 32, Color8(130, 95, 30), maxi(1.0, 1.5 * ui_scale), false)

	# Ícone da espada
	if _attack_icon != null:
		var icon_size: float = eff_r * 1.2
		var rect := Rect2(pos - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
		draw_texture_rect(_attack_icon, rect, false)


func _draw_skill_slot(index: int, pos: Vector2, r: float) -> void:
	var s: Dictionary = _slots_data[index]
	var pressed: bool = s.get("pressed", false)
	var eff_r: float = r * (0.93 if pressed else 1.0)

	# Sombra
	draw_circle(pos + Vector2(0, 2.0 * ui_scale), eff_r + 1.0 * ui_scale, Color(0, 0, 0, 0.45))
	# Base escura
	draw_circle(pos, eff_r, Color8(14, 24, 20, 230))

	# Ícone se houver
	var icon: Texture2D = s.get("icon")
	if icon != null:
		var icon_size: float = eff_r * 1.45
		var rect := Rect2(pos - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
		draw_texture_rect(icon, rect, false)
	else:
		# Slot vazio: pontilhado / círculo oco
		draw_circle(pos, eff_r * 0.35, Color(1, 1, 1, 0.15))

	# Cooldown Radial Sweep
	var cd_pct: float = s.get("cd_pct", 0.0)
	if cd_pct > 0.0:
		var angle_sweep: float = cd_pct * TAU
		var pts: PackedVector2Array = [pos]
		var steps: int = maxi(12, int(32 * cd_pct))
		for step: int in (steps + 1):
			var a: float = -PI * 0.5 + (float(step) / float(steps)) * angle_sweep
			pts.append(pos + Vector2(cos(a), sin(a)) * eff_r)
		pts.append(pos)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.65))

		# Texto de segundos restantes
		var cd_sec: int = s.get("cd_sec", 0)
		if cd_sec > 0:
			var txt: String = "%ds" % cd_sec
			var font: Font = ThemeDB.fallback_font
			var font_size: int = maxi(10, int(11 * ui_scale))
			var str_size: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, pos + Vector2(-str_size.x * 0.5, str_size.y * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color8(255, 230, 100))

	# Aro dourado
	var border_col: Color = Color8(250, 220, 95) if pressed else Color8(195, 160, 60)
	draw_arc(pos, eff_r, 0, TAU, 28, border_col, maxi(1.5, 2.0 * ui_scale), false)

	# Badge de número do slot (1, 2, 3, 4)
	var num_str: String = str(index + 1)
	var badge_pos: Vector2 = pos + Vector2(-eff_r * 0.65, -eff_r * 0.65)
	draw_circle(badge_pos, 7.0 * ui_scale, Color8(20, 32, 28, 240))
	draw_arc(badge_pos, 7.0 * ui_scale, 0, TAU, 16, Color8(210, 175, 75), maxi(1.0, 1.2 * ui_scale), false)
	var font: Font = ThemeDB.fallback_font
	var num_font_size: int = maxi(9, int(10 * ui_scale))
	var num_size: Vector2 = font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, num_font_size)
	draw_string(font, badge_pos + Vector2(-num_size.x * 0.5, num_size.y * 0.38), num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, num_font_size, Color8(255, 235, 160))


func _draw_aux_button(pos: Vector2, r: float, pressed: bool, tint: Color, kind: StringName) -> void:
	var eff_r: float = r * (0.92 if pressed else 1.0)
	draw_circle(pos + Vector2(0, 1.5 * ui_scale), eff_r + 1.0 * ui_scale, Color(0, 0, 0, 0.4))
	draw_circle(pos, eff_r, Color8(18, 30, 26, 230))
	draw_arc(pos, eff_r, 0, TAU, 24, tint if pressed else tint.darkened(0.2), maxi(1.0, 2.0 * ui_scale), false)

	if kind == &"target":
		# Desenhar retículo de mira
		draw_arc(pos, eff_r * 0.55, 0, TAU, 16, Color8(255, 220, 100), maxi(1.0, 1.5 * ui_scale), false)
		draw_circle(pos, 2.0 * ui_scale, Color8(255, 80, 80))
		draw_line(pos + Vector2(-eff_r * 0.75, 0), pos + Vector2(-eff_r * 0.3, 0), Color8(255, 220, 100), maxi(1.0, 1.5 * ui_scale))
		draw_line(pos + Vector2(eff_r * 0.3, 0), pos + Vector2(eff_r * 0.75, 0), Color8(255, 220, 100), maxi(1.0, 1.5 * ui_scale))
		draw_line(pos + Vector2(0, -eff_r * 0.75), pos + Vector2(0, -eff_r * 0.3), Color8(255, 220, 100), maxi(1.0, 1.5 * ui_scale))
		draw_line(pos + Vector2(0, eff_r * 0.3), pos + Vector2(0, eff_r * 0.75), Color8(255, 220, 100), maxi(1.0, 1.5 * ui_scale))
	elif kind == &"gear":
		# Engrenagem / Configurações
		draw_circle(pos, eff_r * 0.45, Color8(230, 195, 90))
		draw_circle(pos, eff_r * 0.2, Color8(18, 30, 26))


func _draw_potion_button(pos: Vector2, r: float, pressed: bool) -> void:
	var eff_r: float = r * (0.92 if pressed else 1.0)
	draw_circle(pos + Vector2(0, 1.5 * ui_scale), eff_r + 1.0 * ui_scale, Color(0, 0, 0, 0.4))
	draw_circle(pos, eff_r, Color8(22, 36, 30, 230))
	draw_arc(pos, eff_r, 0, TAU, 24, Color8(235, 90, 90) if pressed else Color8(190, 70, 70), maxi(1.0, 2.0 * ui_scale), false)

	if _potion_icon != null:
		var isize: float = eff_r * 1.3
		var rect := Rect2(pos - Vector2(isize, isize) * 0.5, Vector2(isize, isize))
		draw_texture_rect(_potion_icon, rect, false)

	# Contador de poções restantes
	if _potion_count > 0:
		var txt: String = "%d" % _potion_count
		var font: Font = ThemeDB.fallback_font
		var font_size: int = maxi(9, int(10 * ui_scale))
		var str_size: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var b_pos: Vector2 = pos + Vector2(eff_r * 0.5, eff_r * 0.4)
		draw_circle(b_pos, 7.0 * ui_scale, Color8(20, 20, 20, 230))
		draw_string(font, b_pos + Vector2(-str_size.x * 0.5, str_size.y * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color8(255, 255, 255))
