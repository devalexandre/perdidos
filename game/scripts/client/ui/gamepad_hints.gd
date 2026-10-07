class_name GamepadHints
extends PanelContainer
## Dicas do controle (só no modo controle): botão desenhado (A verde, B vermelho, X azul, Y amarelo,
## gatilhos/ombros/Start/Select em placa) + o que faz, conforme o contexto: mundo, menu/diálogo ou mira.
## No jogo fica logo acima do chat, da mesma largura (quebra em linhas); sem âncora (tela de título), embaixo
## e centralizada numa linha só. Sem mouse (MOUSE_FILTER_IGNORE).

const CONTEXT_WORLD: StringName = &"world"
const CONTEXT_MENU: StringName = &"menu"
const CONTEXT_AIM: StringName = &"aim"
## Tela de título/criação.
const CONTEXT_TITLE: StringName = &"title"
## [botões, chave do texto] por contexto. Botões separados por "/" viram glifos lado a lado.
const ENTRIES: Dictionary[StringName, Array] = {
	CONTEXT_WORLD: [["A", "PAD_HINT_ACT"], ["B", "PAD_HINT_BACK"], ["X/Y", "PAD_HINT_SLOTS_12"],
		["RT/LT", "PAD_HINT_SLOTS_MORE"], ["LB/RB", "PAD_HINT_TARGET"], ["Start", "PAD_HINT_MENU"],
		["Select", "PAD_HINT_MAP"]],
	CONTEXT_MENU: [["DPAD", "PAD_HINT_NAVIGATE"], ["A", "PAD_HINT_CHOOSE"], ["B", "PAD_HINT_BACK"]],
	CONTEXT_AIM: [["L", "PAD_HINT_AIM"], ["A", "PAD_HINT_CAST"], ["B", "PAD_HINT_CANCEL"]],
	CONTEXT_TITLE: [["DPAD", "PAD_HINT_NAVIGATE"], ["A", "PAD_HINT_CHOOSE"], ["LB/RB", "PAD_HINT_TABS"],
		["Y", "PAD_HINT_RANDOM"], ["LT/RT", "PAD_HINT_ROTATE"], ["Start", "PAD_HINT_PLAY"]],
}
const GLYPH_PX: float = 20.0
const FONT_PX: int = 13
const GAP_PX: float = 4.0
## Largura mínima (px na escala 1,0) quando presa ao chat (chat minimizado é estreito).
const MIN_ANCHORED_WIDTH_PX: float = 300.0
const FACE_COLORS: Dictionary[String, Color] = {
	"A": Color8(76, 175, 80), "B": Color8(222, 68, 55), "X": Color8(52, 128, 220), "Y": Color8(240, 190, 40)}
const PLATE_COLOR: Color = Color8(70, 62, 56)

var ui_scale: float = 1.0
var context: StringName = &""
## Controle acima do qual as dicas ficam (o chat); null = embaixo e centralizada.
var anchor: Control = null
var _rows: VBoxContainer
var _items: Array[Control] = []
var _layout_width: float = -1.0
var _anchor_rect: Rect2 = Rect2()


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"GamepadHints"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var sb: StyleBoxFlat = UIKit.flat_box(UIKit.COLOR_HUD_PANEL, UIKit.COLOR_GOLD_AGED,
			maxi(1, UIKit.px(1, ui_scale)), UIKit.px(4, ui_scale))
	sb.content_margin_left = UIKit.px(8, ui_scale)
	sb.content_margin_right = UIKit.px(8, ui_scale)
	sb.set_corner_radius_all(maxi(2, UIKit.px(4, ui_scale)))
	add_theme_stylebox_override(&"panel", sb)
	_rows = VBoxContainer.new()
	_rows.name = &"Rows"
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
	add_child(_rows)
	set_context(CONTEXT_WORLD)


func _process(_delta: float) -> void:
	if not visible:
		return
	var rect: Rect2 = anchor.get_global_rect() if anchor != null and is_instance_valid(anchor) \
			and anchor.is_visible_in_tree() else Rect2()
	if rect != _anchor_rect or _layout_width < 0.0:
		_anchor_rect = rect
		_layout()


func set_context(value: StringName) -> void:
	if value == context or not ENTRIES.has(value):
		return
	context = value
	for c: Control in _items:
		c.queue_free()
	_items.clear()
	for e: Array in ENTRIES[value]:
		_items.append(_entry(String(e[0]), String(e[1])))
	_layout_width = -1.0
	if is_inside_tree():
		_layout()


## Textos visíveis (testes): "A Agir", ...
func entry_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for item: Control in _items:
		var label := item.get_node_or_null(^"Text") as Label
		out.append("%s %s" % [String(item.get_meta(&"buttons", "")), label.text if label != null else ""])
	return out


func _entry(buttons: String, key: String) -> Control:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
	box.set_meta(&"buttons", buttons)
	for b: String in buttons.split("/"):
		box.add_child(PadGlyph.new(b, ui_scale))
	var label := Label.new()
	label.name = &"Text"
	label.text = tr(key)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", UIKit.px(FONT_PX, ui_scale))
	label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT)
	label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	label.add_theme_constant_override(&"outline_size", UIKit.px(UIKit.OUTLINE_SIZE, ui_scale))
	box.add_child(label)
	return box


## Distribui as dicas em linhas que cabem na largura (a do chat; sem âncora, a tela) e posiciona.
func _layout() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var anchored: bool = _anchor_rect.size != Vector2.ZERO
	var frame: Vector2 = get_theme_stylebox(&"panel").get_minimum_size()
	var width: float = screen.x - UIKit.px(16, ui_scale)
	if anchored:
		width = minf(width, maxf(_anchor_rect.size.x, UIKit.px(MIN_ANCHORED_WIDTH_PX, ui_scale)))
	_layout_width = width
	var gap: float = UIKit.px(GAP_PX * 3.0, ui_scale)
	for row: Node in _rows.get_children():
		for item: Node in row.get_children():
			row.remove_child(item)
		_rows.remove_child(row)
		row.queue_free()
	var row: HBoxContainer = null
	var used: float = 0.0
	for item: Control in _items:
		var w: float = item.get_combined_minimum_size().x
		if row == null or used + gap + w > width - frame.x:
			row = HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override(&"separation", int(gap))
			_rows.add_child(row)
			used = 0.0
		else:
			used += gap
		row.add_child(item)
		used += w
	reset_size()
	var m: float = UIKit.px(GAP_PX, ui_scale)
	if anchored:
		position = Vector2(_anchor_rect.position.x, _anchor_rect.position.y - size.y - m).floor()
	else:
		position = Vector2(floorf((screen.x - size.x) * 0.5), screen.y - size.y - m)


## Botão do controle desenhado: face (círculo colorido com a letra), placa (LB, RT, Start…), D-pad ou analógico.
class PadGlyph extends Control:
	var button: String = ""
	var ui_scale: float = 1.0

	func _init(p_button: String, p_scale: float) -> void:
		button = p_button
		ui_scale = p_scale
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h: float = UIKit.px(GLYPH_PX, ui_scale)
		var w: float = h
		if not GamepadHints.FACE_COLORS.has(button) and button != "DPAD" and button != "L" and button != "R":
			w = maxf(h, _font().get_string_size(button, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_px()).x + h * 0.6)
		custom_minimum_size = Vector2(w, h)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _font() -> Font:
		return UIKit.read_font()

	func _font_px() -> int:
		return UIKit.px(12, ui_scale)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		var outline: Color = UIKit.COLOR_OUTLINE
		if GamepadHints.FACE_COLORS.has(button):
			draw_circle(c, r, outline)
			draw_circle(c, r - maxf(1.0, UIKit.px(1.5, ui_scale)), GamepadHints.FACE_COLORS[button])
			_text(button, Color.WHITE)
		elif button == "DPAD":
			var arm: float = r * 0.36
			draw_rect(Rect2(c.x - arm, c.y - r, arm * 2.0, r * 2.0), PLATE_COLOR_LIGHT)
			draw_rect(Rect2(c.x - r, c.y - arm, r * 2.0, arm * 2.0), PLATE_COLOR_LIGHT)
		elif button == "L" or button == "R":
			draw_circle(c, r, outline)
			draw_circle(c, r - maxf(1.0, UIKit.px(1.5, ui_scale)), GamepadHints.PLATE_COLOR)
			draw_circle(c, r * 0.45, PLATE_COLOR_LIGHT)
			_text(button, UIKit.COLOR_OUTLINE)
		else:
			var rect := Rect2(Vector2.ZERO, size)
			var sb := StyleBoxFlat.new()
			sb.bg_color = GamepadHints.PLATE_COLOR
			sb.border_color = outline
			sb.set_border_width_all(maxi(1, UIKit.px(1, ui_scale)))
			sb.set_corner_radius_all(int(size.y * 0.3))
			draw_style_box(sb, rect)
			_text(button, UIKit.COLOR_TEXT)

	const PLATE_COLOR_LIGHT: Color = Color8(220, 210, 190)

	func _text(t: String, color: Color) -> void:
		var f: Font = _font()
		var fs: int = _font_px()
		var ts: Vector2 = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var base: Vector2 = Vector2((size.x - ts.x) * 0.5, (size.y + f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
		draw_string_outline(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, UIKit.px(2, ui_scale)),
				UIKit.COLOR_OUTLINE)
		draw_string(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
