class_name MobileVirtualJoystick
extends Control
## Analógico virtual (GDD §9.5, Mobile / Touch standard):
## Fica no canto inferior esquerdo para controle contínuo do movimento com o polegar.
## Emite direction_changed(dir: Vector2) normalizado em coordenadas de tela.

signal direction_changed(dir: Vector2)

const BASE_RADIUS_PX: float = 100.0
const KNOB_RADIUS_PX: float = 36.0
const DEADZONE: float = 0.15
const RETURN_SPEED: float = 24.0

var ui_scale: float = 1.0
var _touch_index: int = -1
var _knob_position: Vector2 = Vector2.ZERO
var _current_direction: Vector2 = Vector2.ZERO
var _is_active: bool = false


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"VirtualJoystick"
	mouse_filter = Control.MOUSE_FILTER_PASS
	_update_dimensions()


func _update_dimensions() -> void:
	var total_size: float = (BASE_RADIUS_PX + 12.0) * 2.0 * ui_scale
	custom_minimum_size = Vector2(total_size, total_size)
	size = custom_minimum_size


func set_ui_scale(p_scale: float) -> void:
	ui_scale = p_scale
	_update_dimensions()
	queue_redraw()


func get_direction() -> Vector2:
	return _current_direction


func is_active() -> bool:
	return _is_active


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_is_active = true
			_process_drag(touch.position)
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_release_touch()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_process_drag(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _touch_index == -1:
				_touch_index = 0
				_is_active = true
				_process_drag(mb.position)
				accept_event()
			elif not mb.pressed and _touch_index == 0:
				_release_touch()
				accept_event()
	elif event is InputEventMouseMotion and _touch_index == 0:
		var mm := event as InputEventMouseMotion
		_process_drag(mm.position)
		accept_event()


func _process_drag(pos: Vector2) -> void:
	_is_active = true
	var center: Vector2 = size * 0.5
	var offset: Vector2 = pos - center
	var max_dist: float = BASE_RADIUS_PX * ui_scale
	var dist: float = offset.length()
	if dist > max_dist and max_dist > 0.0:
		offset = offset.normalized() * max_dist
	_knob_position = offset
	var raw_dir: Vector2 = offset / max_dist if max_dist > 0.0 else Vector2.ZERO
	if raw_dir.length() < DEADZONE:
		_current_direction = Vector2.ZERO
	else:
		_current_direction = raw_dir
	direction_changed.emit(_current_direction)
	queue_redraw()


func _release_touch() -> void:
	_touch_index = -1
	_is_active = false
	_current_direction = Vector2.ZERO
	direction_changed.emit(Vector2.ZERO)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_touch()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_touch()


func _process(delta: float) -> void:
	if not _is_active and _knob_position.length_squared() > 0.01:
		_knob_position = _knob_position.move_toward(Vector2.ZERO, RETURN_SPEED * BASE_RADIUS_PX * delta * ui_scale)
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var base_r: float = BASE_RADIUS_PX * ui_scale
	var knob_r: float = KNOB_RADIUS_PX * ui_scale
	var knob_center: Vector2 = center + _knob_position

	# Sombra da base
	draw_circle(center + Vector2(0, 3.0 * ui_scale), base_r + 2.0 * ui_scale, Color(0, 0, 0, 0.12))
	# Base translúcida com estilo fantasia
	draw_circle(center, base_r, Color(0.06, 0.12, 0.1, 0.18))
	# Aro exterior dourado fino
	var ring_color: Color = Color8(235, 220, 174, 190) if _is_active else Color8(220, 214, 189, 100)
	draw_arc(center, base_r, 0, TAU, 36, ring_color, maxi(1.0, 2.0 * ui_scale), false)

	# Marcadores cardeais sutis (N, S, L, O)
	var tick_len: float = 6.0 * ui_scale
	var tick_color: Color = Color8(250, 217, 108, 120)
	var dirs: Array[Vector2] = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	for d: Vector2 in dirs:
		var p1: Vector2 = center + d * (base_r - tick_len)
		var p2: Vector2 = center + d * base_r
		draw_line(p1, p2, tick_color, maxi(1.0, 1.5 * ui_scale))

	# Linha direcional de tração quando ativo
	if _is_active and _knob_position.length_squared() > 4.0:
		draw_line(center, knob_center, Color8(52, 211, 153, 90), maxi(1.0, 2.5 * ui_scale))

	# Sombra do manípulo / knob
	draw_circle(knob_center + Vector2(0, 2.0 * ui_scale), knob_r, Color(0, 0, 0, 0.5))
	# Corpo do manípulo
	var knob_body: Color = Color8(25, 42, 35, 130) if _is_active else Color8(20, 34, 28, 80)
	draw_circle(knob_center, knob_r, knob_body)
	# Anel de ouro do manípulo
	var knob_rim: Color = Color8(255, 230, 120, 240) if _is_active else Color8(210, 175, 75, 200)
	draw_arc(knob_center, knob_r, 0, TAU, 28, knob_rim, maxi(1.0, 2.0 * ui_scale), false)
	# Gema esmeralda central com brilho
	var gem_r: float = 8.0 * ui_scale
	var gem_color: Color = Color8(52, 211, 153, 250) if _is_active else Color8(30, 170, 115, 200)
	draw_circle(knob_center, gem_r, gem_color)
	draw_circle(knob_center - Vector2(2.0, 2.0) * ui_scale, gem_r * 0.4, Color(1, 1, 1, 0.7))
