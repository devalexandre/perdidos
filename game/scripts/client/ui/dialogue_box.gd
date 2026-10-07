class_name DialogueBox
extends PanelContainer
## Caixa de diálogo com NPC (embaixo, centralizada, acima da barra de atalhos): moldura de madeira com
## miolo de pergaminho, placa com o nome de quem fala, fala em tinta escura e opções (já filtradas pelo
## servidor) como botões largos e numerados. Opção → choice_selected(índice); fechar → close_requested.
## Teclas 1..9 escolhem opções; Esc fecha (tratado pelo GameUI). No modo de toque fica entre o analógico
## e os botões de ação, com opções mais altas (GameUI.dialogue_area).

signal choice_selected(option_index: int)
signal close_requested

## Largura da caixa em px na escala 1,0 e distância da borda de baixo (sem GameUI).
const WIDTH_PX: float = 560.0
const BOTTOM_MARGIN_PX: float = 96.0
const CLOSE_TEXT: String = "X"
## Altura mínima das opções (px na escala 1,0): mouse e toque.
const OPTION_HEIGHT_PX: float = 34.0
const OPTION_TOUCH_HEIGHT_PX: float = 44.0
const CLOSE_TOUCH_PX: float = 44.0
## Texto com argumentos (Agente R, TitleTalk): "CHAVE|arg|arg"; arg "A,B" = lista.
const TEXT_ARG_SEP: String = "|"
const TEXT_LIST_SEP: String = ","
const TEXT_LIST_JOIN: String = ", "

var ui_scale: float = 1.0
var npc_entity_id: int = -1

var _speaker: Label
var _plate: PanelContainer
var _text: Label
var _options: VBoxContainer
var _close: Button


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"DialogueBox"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.dialogue_box(ui_scale))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	# Placa de couro com o nome de quem fala.
	_plate = PanelContainer.new()
	_plate.name = &"NamePlate"
	_plate.add_theme_stylebox_override(&"panel", UIKit.name_plate(ui_scale))
	_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_plate)
	_speaker = Label.new()
	_speaker.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT)
	_speaker.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_speaker.add_theme_constant_override(&"outline_size", maxi(2, UIKit.px(3, ui_scale)))
	_speaker.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_TITLE, ui_scale))
	_plate.add_child(_speaker)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_close = Button.new()
	_close.name = &"Close"
	_close.text = CLOSE_TEXT
	_close.focus_mode = Control.FOCUS_NONE
	var close_px: float = CLOSE_TOUCH_PX if UIKit.is_touch_layout() else OPTION_HEIGHT_PX
	_close.custom_minimum_size = Vector2(UIKit.px(close_px, ui_scale), UIKit.px(close_px, ui_scale))
	_close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(_close)
	_text = Label.new()
	_text.name = &"Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = UIKit.px(WIDTH_PX, ui_scale)
	_text.add_theme_font_override(&"font", UIKit.read_font())
	_text.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE + 1, ui_scale))
	_text.add_theme_color_override(&"font_color", UIKit.COLOR_INK)
	_text.add_theme_color_override(&"font_outline_color", Color.TRANSPARENT)
	_text.add_theme_constant_override(&"outline_size", 0)
	box.add_child(_text)
	var rule := ColorRect.new()
	rule.color = UIKit.COLOR_PARCHMENT_EDGE
	rule.custom_minimum_size.y = maxi(1, UIKit.px(1, ui_scale))
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	_options = VBoxContainer.new()
	_options.name = &"Options"
	_options.add_theme_constant_override(&"separation", UIKit.px(5, ui_scale))
	box.add_child(_options)


## Botão de opção: cartão de pergaminho com tinta escura; passa o mouse/toca = borda de ouro e tinta vermelha.
func _option_button(i: int, text: String) -> Button:
	var b := Button.new()
	b.name = "Option%d" % i
	b.text = "%d. %s" % [i + 1, text]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	var h: float = OPTION_TOUCH_HEIGHT_PX if UIKit.is_touch_layout() else OPTION_HEIGHT_PX
	b.custom_minimum_size.y = UIKit.px(h, ui_scale)
	var line: int = maxi(1, UIKit.px(1, ui_scale))
	var pad: int = UIKit.px(6, ui_scale)
	var normal: StyleBoxFlat = UIKit.flat_box(UIKit.COLOR_CARD, UIKit.COLOR_PARCHMENT_EDGE, line, pad)
	var hover: StyleBoxFlat = UIKit.flat_box(UIKit.COLOR_PARCHMENT_SHADE, UIKit.COLOR_GOLD_AGED, maxi(1, UIKit.px(2, ui_scale)), pad)
	var pressed: StyleBoxFlat = UIKit.flat_box(UIKit.COLOR_WOOD, UIKit.COLOR_GOLD, maxi(1, UIKit.px(2, ui_scale)), pad)
	for sb: StyleBoxFlat in [normal, hover, pressed]:
		sb.border_width_left = maxi(2, UIKit.px(4, ui_scale))
		sb.content_margin_left = UIKit.px(12, ui_scale)
	b.add_theme_stylebox_override(&"normal", normal)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"pressed", pressed)
	b.add_theme_stylebox_override(&"hover_pressed", pressed)
	b.add_theme_color_override(&"font_color", UIKit.COLOR_INK)
	b.add_theme_color_override(&"font_hover_color", UIKit.COLOR_INK_TITLE)
	b.add_theme_color_override(&"font_pressed_color", UIKit.COLOR_TEXT)
	b.add_theme_color_override(&"font_hover_pressed_color", UIKit.COLOR_TEXT)
	b.add_theme_color_override(&"font_outline_color", Color.TRANSPARENT)
	b.add_theme_constant_override(&"outline_size", 0)
	b.add_theme_font_override(&"font", UIKit.read_font())
	b.pressed.connect(choose.bind(i))
	return b


## Abre (ou atualiza) a caixa. options = chaves de tradução das opções visíveis.
func show_dialogue(p_npc_entity_id: int, speaker_key: String, text_key: String, options: Array) -> void:
	npc_entity_id = p_npc_entity_id
	_speaker.text = tr(speaker_key)
	_text.text = resolve_text(text_key)
	for child: Node in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for i: int in options.size():
		_options.add_child(_option_button(i, resolve_text(String(options[i]))))
	visible = true
	_place()


## Agente R: texto com argumentos vindo do servidor, "CHAVE|arg|arg" (TitleTalk). Cada arg é uma
## chave traduzida; "A,B" vira "A, B" (lista). Sem "|" = só tr(chave).
static func resolve_text(raw: String) -> String:
	if not raw.contains(TEXT_ARG_SEP):
		return TranslationServer.translate(raw)
	var parts: PackedStringArray = raw.split(TEXT_ARG_SEP)
	var fmt: String = TranslationServer.translate(parts[0])
	var args: Array = []
	for i: int in range(1, parts.size()):
		var items: PackedStringArray = []
		for k: String in parts[i].split(TEXT_LIST_SEP, false):
			items.append(TranslationServer.translate(k))
		args.append(TEXT_LIST_JOIN.join(items))
	if fmt.count("%s") != args.size():
		return fmt
	return fmt % args


func hide_dialogue() -> void:
	visible = false
	npc_entity_id = -1


func get_option_count() -> int:
	return _options.get_child_count()


func choose(option_index: int) -> void:
	if option_index < 0 or option_index >= _options.get_child_count():
		return
	choice_selected.emit(option_index)


## Área onde a caixa cabe (GameUI.dialogue_area: acima da barra de atalhos e, no toque, entre os
## controles); sem GameUI, a tela com a margem antiga embaixo.
func _area() -> Rect2:
	var p: Node = get_parent()
	if p != null and p.has_method(&"dialogue_area"):
		return p.call(&"dialogue_area") as Rect2
	var screen: Vector2 = get_parent_area_size()
	return Rect2(0.0, 0.0, screen.x, screen.y - UIKit.px(BOTTOM_MARGIN_PX, ui_scale))


func _place() -> void:
	var area: Rect2 = _area()
	var frame: Vector2 = get_theme_stylebox(&"panel").get_minimum_size()
	_text.custom_minimum_size.x = clampf(area.size.x - frame.x, UIKit.px(160, ui_scale), UIKit.px(WIDTH_PX, ui_scale))
	reset_size()
	position = Vector2(floorf(area.position.x + (area.size.x - size.x) * 0.5),
			floorf(maxf(0.0, area.end.y - size.y)))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
