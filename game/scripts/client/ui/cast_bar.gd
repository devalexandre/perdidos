class_name CastBar
extends Control
## Barra de conjuração animada (GDD §8.1 "Tempo de uso na barra"): enche no tempo da conjuração,
## com texto (nome + segundos restantes) opcional. Entra com fade, termina com um clarão e some;
## interrompida fica vermelha, treme e some. Sem som de UI.
## Usada em cima da barra 1–0 (jogador local) e, pequena, sobre a cabeça de quem conjura (CastBarsOverlay).

signal finished
signal cancelled

enum State { IDLE, CASTING, DONE, CANCELLED }

const FILL: Color = Color8(250, 229, 140)
const FILL_DARK: Color = Color8(214, 168, 72)
const FILL_CANCEL: Color = Color8(245, 120, 90)
const EDGE: Color = Color(1.0, 1.0, 0.95, 0.9)
const MSEC_PER_SEC: float = 1000.0
const FADE_IN_SEC: float = 0.12
const DONE_FLASH_SEC: float = 0.12
const FADE_OUT_SEC: float = 0.3
const CANCEL_SHAKE_SEC: float = 0.25
const CANCEL_SHAKE_PX: float = 3.0
const LABEL_FONT_PX: int = 10

var ui_scale: float = 1.0
var state: State = State.IDLE
var show_text: bool = true
var title: String = ""
var _start_msec: float = 0.0
var _end_msec: float = 0.0
var _progress: float = 0.0
var _flash: float = 0.0
var _label: Label
var _tween: Tween
var _base_x: float = 0.0


func _init(p_scale: float = 1.0, p_show_text: bool = true) -> void:
	ui_scale = p_scale
	show_text = p_show_text
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	_label = Label.new()
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", UIKit.px(LABEL_FONT_PX, ui_scale))
	_label.add_theme_constant_override(&"outline_size", UIKit.px(UIKit.OUTLINE_SIZE, ui_scale))
	_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.visible = show_text
	add_child(_label)


## Começa (ou continua) uma conjuração de total_ms, faltando left_ms.
func start(p_title: String, total_ms: float, left_ms: float = -1.0) -> void:
	title = p_title
	var now: float = Time.get_ticks_msec()
	var total: float = maxf(total_ms, 1.0)
	var left: float = total if left_ms < 0.0 else clampf(left_ms, 0.0, total)
	_end_msec = now + left
	_start_msec = _end_msec - total
	state = State.CASTING
	_flash = 0.0
	_kill_tween()
	if is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SEC)
	else:
		modulate.a = 1.0
	_update()


func is_casting() -> bool:
	return state == State.CASTING


func progress() -> float:
	return _progress


func left_msec() -> float:
	return maxf(0.0, _end_msec - Time.get_ticks_msec())


## Interrompida: fica vermelha, treme e some.
func cancel() -> void:
	if state != State.CASTING:
		return
	state = State.CANCELLED
	_label.text = title
	_kill_tween()
	queue_redraw()
	if not is_inside_tree():
		modulate.a = 0.0
		return
	_base_x = position.x
	var d: float = UIKit.px(CANCEL_SHAKE_PX, ui_scale)
	_tween = create_tween()
	for k: int in 4:
		_tween.tween_property(self, "position:x", _base_x + (d if k % 2 == 0 else -d), CANCEL_SHAKE_SEC / 5.0)
	_tween.tween_property(self, "position:x", _base_x, CANCEL_SHAKE_SEC / 5.0)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	_tween.tween_callback(_to_idle)
	cancelled.emit()


func _complete() -> void:
	state = State.DONE
	_progress = 1.0
	_label.text = title
	_kill_tween()
	if not is_inside_tree():
		modulate.a = 0.0
		state = State.IDLE
		return
	_tween = create_tween()
	_tween.tween_property(self, "_flash", 1.0, DONE_FLASH_SEC)
	_tween.tween_property(self, "_flash", 0.0, DONE_FLASH_SEC)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	_tween.tween_callback(_to_idle)
	finished.emit()


func _to_idle() -> void:
	if state != State.CASTING:
		state = State.IDLE


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _process(_delta: float) -> void:
	if state == State.CASTING:
		_update()
	elif _flash > 0.0 or state == State.CANCELLED:
		queue_redraw()


func _update() -> void:
	var now: float = Time.get_ticks_msec()
	var total: float = maxf(_end_msec - _start_msec, 1.0)
	_progress = clampf((now - _start_msec) / total, 0.0, 1.0)
	var left: float = maxf(0.0, _end_msec - now) / MSEC_PER_SEC
	_label.text = "%s  %s s" % [title, UIKit.seconds_text(left)] if not title.is_empty() \
			else "%s s" % UIKit.seconds_text(left)
	queue_redraw()
	if now >= _end_msec:
		_complete()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var b: float = maxf(1.0, UIKit.px(1, ui_scale))
	draw_rect(r, UIKit.COLOR_FIELD)
	var inner: Rect2 = r.grow(-b)
	var w: float = inner.size.x * _progress
	var fill: Color = FILL_CANCEL if state == State.CANCELLED else FILL
	var dark: Color = FILL_CANCEL.darkened(0.25) if state == State.CANCELLED else FILL_DARK
	if w > 0.0:
		# Duas faixas (luz em cima) no estilo pixel, sem gradiente suave.
		draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), dark)
		draw_rect(Rect2(inner.position, Vector2(w, ceilf(inner.size.y * 0.5))), fill)
		if state == State.CASTING:
			draw_rect(Rect2(inner.position.x + w - b, inner.position.y, b, inner.size.y), EDGE)
	if _flash > 0.0:
		draw_rect(inner, Color(1.0, 1.0, 0.95, 0.7 * _flash))
	draw_rect(r, UIKit.COLOR_BORDER_DARK, false, b)
