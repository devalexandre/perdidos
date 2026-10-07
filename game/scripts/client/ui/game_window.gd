class_name GameWindow
extends PanelContainer
## Janela base do UIKit: moldura de madeira, cabeçalho arrastável com título dourado, botão fechar e
## miolo de pergaminho. O conteúdo vai em `content` (VBoxContainer) dentro de uma rolagem: a janela
## nunca passa da área útil da tela (GameUI.work_rect: sem cobrir a barra de atalhos) — o que não
## couber rola em vez de ser cortado. Funciona com mouse e toque (sem depender de hover); no modo de
## toque o botão de fechar é grande e a janela abre centrada na área útil.

signal opened
signal closed

const CLOSE_TEXT: String = "X"
## Margem mínima (px na escala 1,0) que a janela mantém dentro da tela ao arrastar.
const KEEP_VISIBLE_PX: float = 24.0
## Lado do botão de fechar (px na escala 1,0): mouse e toque.
const CLOSE_PX: float = 28.0
const CLOSE_TOUCH_PX: float = 44.0

var ui_scale: float = 1.0
var content: VBoxContainer
var title_label: Label
var close_button: Button
## Rolagem do miolo (aparece só quando o conteúdo passa da área útil).
var scroll: ScrollContainer

## Âncora preferida na área útil (ver place) e se o jogador já arrastou a janela (aí ela fica onde ele pôs).
var default_anchor: Vector2 = Vector2(0.5, 0.0)
var user_moved: bool = false

var _title_key: String = ""
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _fit_queued: bool = false


func _init(title_key: String = "", p_scale: float = 1.0) -> void:
	_title_key = title_key
	ui_scale = p_scale
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_theme_stylebox_override(&"panel", UIKit.window_frame(ui_scale))
	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
	add_child(root)
	var header := PanelContainer.new()
	header.name = &"Header"
	header.add_theme_stylebox_override(&"panel", UIKit.window_header(ui_scale))
	root.add_child(header)
	var bar := HBoxContainer.new()
	bar.name = &"TitleBar"
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(_on_title_input)
	header.add_child(bar)
	title_label = Label.new()
	title_label.text = title_key
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
	title_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	title_label.add_theme_constant_override(&"outline_size", maxi(2, UIKit.px(3, ui_scale)))
	title_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_TITLE, ui_scale))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title_label)
	close_button = Button.new()
	close_button.name = &"Close"
	close_button.text = CLOSE_TEXT
	close_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	close_button.focus_mode = Control.FOCUS_NONE
	var close_px: float = CLOSE_TOUCH_PX if UIKit.is_touch_layout() else CLOSE_PX
	close_button.custom_minimum_size = Vector2(UIKit.px(close_px, ui_scale), UIKit.px(close_px, ui_scale))
	close_button.pressed.connect(close)
	bar.add_child(close_button)
	var body := PanelContainer.new()
	body.name = &"PaperBody"
	body.add_theme_stylebox_override(&"panel", UIKit.paper_box(ui_scale))
	root.add_child(body)
	scroll = ScrollContainer.new()
	scroll.name = &"BodyScroll"
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.name = &"Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	content.minimum_size_changed.connect(_queue_fit)
	scroll.add_child(content)


func open() -> void:
	if visible:
		move_to_front()
		return
	visible = true
	move_to_front()
	fit_to_screen()
	if UIKit.is_touch_layout():
		center_in_work_area()
	elif not user_moved and get_parent() != null and get_parent().has_method(&"arrange_window"):
		get_parent().call(&"arrange_window", self)
	clamp_to_screen()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Área útil onde as janelas podem ficar (coordenadas do pai). O GameUI informa (sem a barra de atalhos);
## sem ele, a área inteira do pai.
func work_rect() -> Rect2:
	var p: Node = get_parent()
	if p != null and p.has_method(&"work_rect"):
		return p.call(&"work_rect") as Rect2
	return Rect2(Vector2.ZERO, get_parent_area_size())


## Limite de tamanho/arrasto: a tela inteira com margem (a área útil é só a posição preferida — uma
## janela alta pode cobrir a barra de atalhos em vez de esconder botões atrás da rolagem).
func max_rect() -> Rect2:
	var p: Node = get_parent()
	if p != null and p.has_method(&"max_rect"):
		return p.call(&"max_rect") as Rect2
	return work_rect()


## Altura preferida para o topo das janelas (abaixo das barras de vida), se couber.
func _preferred_top(work: Rect2) -> float:
	var p: Node = get_parent()
	if p != null and p.has_method(&"preferred_top"):
		return maxf(work.position.y, float(p.call(&"preferred_top")))
	return work.position.y


## Limita o miolo à área útil: o que passar rola. Encolhe a janela ao conteúdo.
func fit_to_screen() -> void:
	_fit_queued = false
	if content == null or scroll == null:
		return
	var want: Vector2 = content.get_combined_minimum_size()
	var chrome: Vector2 = _chrome_size()
	var limit: Vector2 = (max_rect().size - chrome).max(Vector2(UIKit.px(80, ui_scale), UIKit.px(60, ui_scale)))
	var fit := Vector2(minf(want.x, limit.x), minf(want.y, limit.y))
	# Barra vertical visível: espaço para ela (senão aparece a horizontal à toa).
	if want.y > limit.y:
		fit.x = minf(want.x + scroll.get_v_scroll_bar().get_combined_minimum_size().x, limit.x)
	if want.x > limit.x:
		fit.y = minf(want.y + scroll.get_h_scroll_bar().get_combined_minimum_size().y, limit.y)
	if scroll.custom_minimum_size != fit:
		scroll.custom_minimum_size = fit
	reset_size()


## Espaço da moldura, do cabeçalho e das margens do pergaminho em volta da rolagem.
func _chrome_size() -> Vector2:
	var frame: StyleBox = get_theme_stylebox(&"panel")
	var body: PanelContainer = scroll.get_parent() as PanelContainer
	var paper: StyleBox = body.get_theme_stylebox(&"panel")
	var header: Control = body.get_parent().get_child(0) as Control
	var sep: int = (body.get_parent() as VBoxContainer).get_theme_constant(&"separation")
	var w: float = frame.get_minimum_size().x + paper.get_minimum_size().x
	var h: float = frame.get_minimum_size().y + paper.get_minimum_size().y \
			+ header.get_combined_minimum_size().y + sep
	return Vector2(w, h)


func _queue_fit() -> void:
	if _fit_queued or not is_inside_tree():
		return
	_fit_queued = true
	_refit.call_deferred()


func _refit() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	fit_to_screen()
	if visible:
		clamp_to_screen()


## Centraliza na área útil (modo de toque: uma janela por vez, no meio, sem ficar sob os controles).
func center_in_work_area() -> void:
	var work: Rect2 = work_rect()
	if size.y > work.size.y:
		work = max_rect()
	position = (work.position + (work.size - size) * 0.5).floor()


## Posiciona a janela relativa à área útil (âncora em fração da área livre) e mantém dentro.
## Em y, prefere começar abaixo das barras de vida/minimapa quando a janela cabe.
func place(anchor_fraction: Vector2) -> void:
	fit_to_screen()
	var work: Rect2 = work_rect()
	if UIKit.is_touch_layout():
		center_in_work_area()
		clamp_to_screen()
		return
	var top: float = _preferred_top(work)
	var bottom: float = work.end.y
	var free_y: float = bottom - size.y
	var y: float = top + maxf(0.0, free_y - top) * anchor_fraction.y if free_y >= top else free_y
	position = Vector2(work.position.x + (work.size.x - size.x) * anchor_fraction.x, y).floor()
	clamp_to_screen()


func clamp_to_screen() -> void:
	var work: Rect2 = max_rect()
	var keep: float = UIKit.px(KEEP_VISIBLE_PX, ui_scale)
	position.x = clampf(position.x, work.position.x + keep - size.x, work.end.x - keep)
	position.y = clampf(position.y, work.position.y, maxf(work.position.y, work.end.y - keep))
	if size.x <= work.size.x:
		position.x = clampf(position.x, work.position.x, work.end.x - size.x)
	if size.y <= work.size.y:
		position.y = clampf(position.y, work.position.y, work.end.y - size.y)


func _ready() -> void:
	title_label.text = tr(_title_key)


## Clicar/tocar em qualquer parte da janela a traz para a frente (janelas sobrepostas em telas pequenas).
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		move_to_front()


func _on_title_input(event: InputEvent) -> void:
	var press_pos: Variant = null
	var released: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_pos = (event as InputEventMouseButton).global_position
		else:
			released = true
	elif event is InputEventScreenTouch:
		if event.pressed:
			press_pos = (event as InputEventScreenTouch).position
		else:
			released = true
	if press_pos != null:
		_dragging = true
		_drag_offset = (press_pos as Vector2) - global_position
		move_to_front()
		accept_event()
	elif released:
		_dragging = false
		accept_event()
	elif _dragging and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		var p: Vector2 = event.global_position if event is InputEventMouseMotion \
				else (event as InputEventScreenDrag).position
		global_position = p - _drag_offset
		user_moved = true
		clamp_to_screen()
		accept_event()
