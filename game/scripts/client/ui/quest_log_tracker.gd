class_name QuestTracker
extends PanelContainer
## Acompanhamento das missões na tela (lado direito, abaixo do minimapa): cartão de madeira translúcida
## com o nome de cada missão, o objetivo atual e o progresso (3/5). Tocar numa missão abre o diário;
## o botão do cabeçalho recolhe e reabre.

signal open_log_requested

## Abaixo do quadro completo do minimapa (22 + 144 + bordas + rodapé) com respiro.
const TOP_PX: float = 198.0
const RIGHT_MARGIN_PX: float = 8.0
const WIDTH_PX: float = 230.0
const HEADER_FONT_PX: int = 13
const TITLE_FONT_PX: int = 13
const STEP_FONT_PX: int = 12
const PADDING_PX: float = 8.0
const TOGGLE_PX: float = 22.0
## Mais que isso vira "+N no diário" (o cartão não cresce sobre o mapa).
const MAX_SHOWN: int = 3
## Toque: cartão baixo ao lado do quadro de vida (longe do analógico, dos botões de ação e da
## personagem, que fica no centro), só a missão principal.
const TOUCH_TOP_PX: float = 54.0
const TOUCH_LEFT_PX: float = 256.0
const TOUCH_WIDTH_PX: float = 240.0
const TOUCH_PADDING_PX: float = 5.0
const TOUCH_MAX_SHOWN: int = 1

var ui_scale: float = 1.0
static var minimized: bool = false
var _quests: Array = []
var _box: VBoxContainer = null


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"QuestTracker"
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size.x = UIKit.px(WIDTH_PX, ui_scale)
	add_theme_stylebox_override(&"panel", UIKit.hud_box(ui_scale, PADDING_PX))
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_box.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
	add_child(_box)
	_box.minimum_size_changed.connect(func() -> void: _fit.call_deferred())


func _ready() -> void:
	_place()


## Desktop: canto direito, abaixo do minimapa. Toque: alto da tela, ao centro.
func _place() -> void:
	var touch: bool = UIKit.is_touch_layout()
	var w: float = UIKit.px(TOUCH_WIDTH_PX if touch else WIDTH_PX, ui_scale)
	custom_minimum_size.x = w
	add_theme_stylebox_override(&"panel", UIKit.hud_box(ui_scale, TOUCH_PADDING_PX if touch else PADDING_PX))
	if touch:
		anchor_left = 0.0
		anchor_right = 0.0
		anchor_top = 0.0
		anchor_bottom = 0.0
		grow_horizontal = Control.GROW_DIRECTION_END
		offset_left = UIKit.px(TOUCH_LEFT_PX, ui_scale)
		offset_right = offset_left + w
		offset_top = UIKit.px(TOUCH_TOP_PX, ui_scale)
	else:
		anchor_left = 1.0
		anchor_right = 1.0
		anchor_top = 0.0
		anchor_bottom = 0.0
		grow_horizontal = Control.GROW_DIRECTION_BEGIN
		offset_left = -UIKit.px(RIGHT_MARGIN_PX, ui_scale) - w
		offset_right = -UIKit.px(RIGHT_MARGIN_PX, ui_scale)
		offset_top = UIKit.px(TOP_PX, ui_scale)
	_fit.call_deferred()


## Altura = conteúdo (o cartão termina na última missão). Mede depois do layout: antes disso os
## rótulos com quebra de linha ainda não têm largura e pedem altura demais.
func _fit() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	var h: float = 0.0
	var n: int = 0
	for c: Node in _box.get_children():
		if c is Control and (c as Control).visible and not c.is_queued_for_deletion():
			h += (c as Control).get_combined_minimum_size().y
			n += 1
	h += float(maxi(0, n - 1) * _box.get_theme_constant(&"separation"))
	var sb: StyleBox = get_theme_stylebox(&"panel")
	offset_bottom = offset_top + h + (sb.get_minimum_size().y if sb != null else 0.0)


func set_progress(progress: Dictionary) -> void:
	_quests = (progress.get("quests", []) as Array).duplicate(true)
	_rebuild()


func _rebuild() -> void:
	for c: Node in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	visible = not _quests.is_empty()
	if _quests.is_empty():
		return
	if is_inside_tree():
		_place()
	_box.add_child(_header())
	if minimized:
		return
	var shown: int = 0
	for e: Variant in _quests:
		var entry: Dictionary = e
		var q: QuestDef = Content.quest(StringName(str(entry.get("id", ""))))
		if q == null:
			continue
		if shown >= (TOUCH_MAX_SHOWN if UIKit.is_touch_layout() else MAX_SHOWN):
			break
		_box.add_child(_separator())
		_box.add_child(_quest_row(q, entry))
		shown += 1
	var more: int = _quests.size() - shown
	if more > 0 and not UIKit.is_touch_layout():
		var l: Label = _label("+%d · %s" % [more, tr("UI_QUEST_LOG")], STEP_FONT_PX, UIKit.COLOR_TEXT_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_box.add_child(l)


## "MISSÕES (2)" em dourado + botão pequeno de recolher (−/+).
func _header() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var title: Label = _label("%s (%d)" % [tr("UI_QUEST_TRACKER").to_upper(), _quests.size()],
			HEADER_FONT_PX, UIKit.COLOR_GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var toggle := Button.new()
	toggle.name = &"TrackerToggle"
	toggle.text = "+" if minimized else "−"
	toggle.tooltip_text = tr("UI_QUEST_TRACKER_TOGGLE")
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.flat = true
	toggle.custom_minimum_size = Vector2.ONE * UIKit.px(TOGGLE_PX, ui_scale)
	toggle.add_theme_font_size_override(&"font_size", UIKit.px(HEADER_FONT_PX + 2, ui_scale))
	toggle.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD)
	toggle.add_theme_color_override(&"font_hover_color", UIKit.COLOR_GOLD_LIGHT)
	toggle.pressed.connect(func() -> void:
		minimized = not minimized
		_rebuild())
	row.add_child(toggle)
	return row


## Nome da missão + objetivo atual (com o progresso à direita). Tocar abre o diário.
func _quest_row(q: QuestDef, entry: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_theme_constant_override(&"separation", UIKit.px(1, ui_scale))
	row.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
				or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			open_log_requested.emit())
	var ready: bool = bool(entry.get("ready", false))
	row.add_child(_label(tr(q.name_key), TITLE_FONT_PX, UIKit.COLOR_GOLD_LIGHT))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	var objective: Label = _label(("✓ " if ready else "› ") + _objective(q, entry), STEP_FONT_PX,
			UIKit.COLOR_LEAF_LIGHT if ready else UIKit.COLOR_TEXT_DIM)
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UIKit.is_touch_layout():
		# Toque: uma linha só, cortada com reticências (o cartão fica baixo e não cobre o centro).
		objective.autowrap_mode = TextServer.AUTOWRAP_OFF
		objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		objective.clip_text = true
		objective.custom_minimum_size.x = 1.0
	line.add_child(objective)
	var count: String = _count(q, entry)
	if not count.is_empty():
		var c: Label = _label(count, STEP_FONT_PX, UIKit.COLOR_TEXT)
		c.autowrap_mode = TextServer.AUTOWRAP_OFF
		c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(c)
	row.add_child(line)
	return row


## Texto da etapa sem a contagem (ela vai à direita).
static func _objective(q: QuestDef, entry: Dictionary) -> String:
	if bool(entry.get("ready", false)):
		return TranslationServer.translate("UI_QUEST_READY")
	var i: int = int(entry.get("step", 0))
	if i < 0 or i >= q.steps.size():
		return ""
	return TranslationServer.translate(q.steps[i].text_key)


## "3/5" (quantidade desta aceitação; cresce com os títulos) e o tempo da provação, se houver.
static func _count(q: QuestDef, entry: Dictionary) -> String:
	if bool(entry.get("ready", false)):
		return ""
	var i: int = int(entry.get("step", 0))
	if i < 0 or i >= q.steps.size():
		return ""
	var out: String = ""
	var need: int = int(entry.get("need", q.steps[i].count))
	if need > 1:
		out = "%d/%d" % [int(entry.get("count", 0)), need]
	if int(entry.get("trial_ms", -1)) > 0:
		out += (" · " if not out.is_empty() else "") + "%ds" % ceili(int(entry["trial_ms"]) / 1000.0)
	return out


func _separator() -> Control:
	var sep := ColorRect.new()
	sep.color = Color(UIKit.COLOR_GOLD_AGED, 0.45)
	sep.custom_minimum_size.y = maxi(1, UIKit.px(1, ui_scale))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep


func _label(text: String, font_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override(&"font_size", UIKit.px(font_px, ui_scale))
	l.add_theme_constant_override(&"outline_size", UIKit.px(2, ui_scale))
	l.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	l.add_theme_color_override(&"font_color", color)
	return l
