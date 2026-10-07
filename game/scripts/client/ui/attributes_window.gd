class_name AttributesWindow
extends GameWindow
## Distribuição dos pontos de atributo (GDD §6.2): FOR, DES, VIT, INT, ESP, SOR, com o efeito de cada
## um (também como dica ao passar o mouse na sigla). DES/INT mostram a redução de conjuração e ESP a de
## recarga atuais (com os pontos do rascunho), GDD §8.1 "Tempo de uso na barra".
## O jogador soma pontos com "+"/"−" (só no rascunho local) e confirma (com aviso: não dá para
## redistribuir). Intenção: NetProgress.send_allocate_stats(dict). Atalho A.

signal allocate_requested(points: Dictionary)

const ROWS: Array[Array] = [
	[&"str", "STAT_STR", "UI_ATTR_STR_DESC"], [&"dex", "STAT_DEX", "UI_ATTR_DEX_DESC"],
	[&"vit", "STAT_VIT", "UI_ATTR_VIT_DESC"], [&"int", "STAT_INT", "UI_ATTR_INT_DESC"],
	[&"spi", "STAT_SPI", "UI_ATTR_SPI_DESC"], [&"luk", "STAT_LUK", "UI_ATTR_LUK_DESC"]]
## Valores derivados mostrados embaixo (GDD §6.4, §10.2).
const DERIVED: Array[Array] = [["STAT_MAX_HP", &"max_hp"], ["STAT_MAX_MP", &"max_mp"],
	["STAT_ATK", &"atk"], ["STAT_MATK", &"matk"], ["STAT_DEF", &"def"], ["STAT_MDEF", &"mdef"]]
const DESC_WIDTH_PX: float = 330.0
const CARD_BG: Color = UIKit.COLOR_CARD
const CARD_BORDER: Color = UIKit.COLOR_CARD_BORDER
const PENDING_INK: Color = UIKit.COLOR_INK_GOOD

var _points_label: Label
var _values: Dictionary[StringName, Label] = {}
var _plus: Dictionary[StringName, Button] = {}
var _minus: Dictionary[StringName, Button] = {}
var _derived: Dictionary[StringName, Label] = {}
var _desc: Dictionary[StringName, Label] = {}
var _detail: Label
var _focus_attr: StringName = &"str"
var _confirm: Button
var _reset: Button
var _confirm_box: HBoxContainer
var _confirm_label: Label
var _pending: Dictionary[StringName, int] = {}
var _available: int = 0
var _stats: Dictionary = {}


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_ATTRIBUTES_WINDOW", p_scale)
	name = &"AttributesWindow"

	# Banner de pontos disponíveis com fundo de pergaminho destacado
	var pts_card := PanelContainer.new()
	pts_card.add_theme_stylebox_override(&"panel", UIKit.banner_box(ui_scale))
	content.add_child(pts_card)

	_points_label = Label.new()
	_points_label.name = &"Points"
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_label.add_theme_font_override(&"font", UIKit.read_font())
	_points_label.add_theme_font_size_override(&"font_size", UIKit.px(16, ui_scale))
	_points_label.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT)
	_points_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_points_label.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(2, ui_scale)))
	pts_card.add_child(_points_label)

	# Tabela compacta (uma linha por atributo); a descrição do atributo em foco aparece no quadro abaixo.
	var table := PanelContainer.new()
	table.add_theme_stylebox_override(&"panel", _card_box())
	content.add_child(table)
	var attr_list := VBoxContainer.new()
	attr_list.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
	table.add_child(attr_list)

	for row: Array in ROWS:
		var attr: StringName = row[0]
		if attr != ROWS[0][0]:
			var rule := ColorRect.new()
			rule.color = UIKit.COLOR_PARCHMENT_SHADE
			rule.custom_minimum_size.y = maxi(1, UIKit.px(1, ui_scale))
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			attr_list.add_child(rule)
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
		line.mouse_entered.connect(_focus.bind(attr))
		attr_list.add_child(line)

		var n := Label.new()
		n.name = "Name_%s" % attr
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.add_theme_font_override(&"font", UIKit.read_font())
		n.add_theme_font_size_override(&"font_size", UIKit.px(18, ui_scale))
		n.add_theme_color_override(&"font_color", UIKit.COLOR_INK_TITLE)
		line.add_child(n)

		var minus := Button.new()
		minus.name = "Minus_%s" % attr
		minus.text = "−"
		minus.focus_mode = Control.FOCUS_NONE
		minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		minus.custom_minimum_size = Vector2(UIKit.px(30, ui_scale), UIKit.px(30, ui_scale))
		_style_stat_button(minus)
		minus.pressed.connect(_change.bind(attr, -1))
		line.add_child(minus)

		var v := Label.new()
		v.name = "Value_%s" % attr
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.custom_minimum_size.x = UIKit.px(76, ui_scale)
		v.add_theme_font_override(&"font", UIKit.read_font())
		v.add_theme_font_size_override(&"font_size", UIKit.px(18, ui_scale))
		v.add_theme_color_override(&"font_color", UIKit.COLOR_INK)
		line.add_child(v)

		var plus := Button.new()
		plus.name = "Plus_%s" % attr
		plus.text = "+"
		plus.focus_mode = Control.FOCUS_NONE
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.custom_minimum_size = Vector2(UIKit.px(30, ui_scale), UIKit.px(30, ui_scale))
		_style_stat_button(plus)
		plus.pressed.connect(_change.bind(attr, 1))
		line.add_child(plus)

		var d := Label.new()
		d.name = "Desc_%s" % attr
		d.visible = false
		line.add_child(d)

		_values[attr] = v
		_desc[attr] = d
		_plus[attr] = plus
		_minus[attr] = minus
		_pending[attr] = 0

	# Quadro de detalhe: descrição do atributo em foco (mouse por cima ou último +/− tocado).
	var detail_card := PanelContainer.new()
	detail_card.add_theme_stylebox_override(&"panel", _card_box())
	content.add_child(detail_card)
	_detail = Label.new()
	_detail.name = &"Detail"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(UIKit.px(DESC_WIDTH_PX, ui_scale), UIKit.px(84, ui_scale))
	_detail.add_theme_font_override(&"font", UIKit.read_font())
	_detail.add_theme_font_size_override(&"font_size", UIKit.px(14, ui_scale))
	_detail.add_theme_color_override(&"font_color", UIKit.COLOR_INK)
	detail_card.add_child(_detail)

	# Painel de valores derivados (Vida, Mana, ATQ, MATQ, DEF, MDEF)
	var der_card := PanelContainer.new()
	der_card.add_theme_stylebox_override(&"panel", _card_box())
	content.add_child(der_card)

	var derived := GridContainer.new()
	derived.columns = 4
	derived.add_theme_constant_override(&"h_separation", UIKit.px(10, ui_scale))
	derived.add_theme_constant_override(&"v_separation", UIKit.px(4, ui_scale))
	der_card.add_child(derived)

	for row: Array in DERIVED:
		var n2 := Label.new()
		n2.name = "DName_%s" % row[1]
		n2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n2.add_theme_font_override(&"font", UIKit.read_font())
		n2.add_theme_font_size_override(&"font_size", UIKit.px(13, ui_scale))
		n2.add_theme_color_override(&"font_color", UIKit.COLOR_INK_DIM)
		derived.add_child(n2)
		var v2 := Label.new()
		v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v2.add_theme_font_override(&"font", UIKit.read_font())
		v2.add_theme_font_size_override(&"font_size", UIKit.px(15, ui_scale))
		v2.add_theme_color_override(&"font_color", UIKit.COLOR_INK)
		derived.add_child(v2)
		_derived[row[1]] = v2

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", UIKit.px(10, ui_scale))
	content.add_child(buttons)

	_reset = Button.new()
	_reset.name = &"Reset"
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.custom_minimum_size = Vector2(UIKit.px(90, ui_scale), UIKit.px(28, ui_scale))
	_style_action_button(_reset, false)
	_reset.pressed.connect(_reset_pending)
	buttons.add_child(_reset)

	_confirm = Button.new()
	_confirm.name = &"Confirm"
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.custom_minimum_size = Vector2(UIKit.px(110, ui_scale), UIKit.px(28, ui_scale))
	_style_action_button(_confirm, true)
	_confirm.pressed.connect(_ask_confirm)
	buttons.add_child(_confirm)

	_confirm_box = HBoxContainer.new()
	_confirm_box.visible = false
	_confirm_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_box.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	content.add_child(_confirm_box)

	_confirm_label = Label.new()
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.custom_minimum_size.x = UIKit.px(DESC_WIDTH_PX, ui_scale)
	_confirm_label.add_theme_font_override(&"font", UIKit.read_font())
	_confirm_label.add_theme_font_size_override(&"font_size", UIKit.px(12, ui_scale))
	_confirm_label.add_theme_color_override(&"font_color", UIKit.c_error())
	_confirm_box.add_child(_confirm_label)

	var yes := Button.new()
	yes.name = &"Yes"
	yes.focus_mode = Control.FOCUS_NONE
	_style_action_button(yes, true)
	yes.pressed.connect(_send)
	_confirm_box.add_child(yes)

	var no := Button.new()
	no.name = &"No"
	no.focus_mode = Control.FOCUS_NONE
	_style_action_button(no, false)
	no.pressed.connect(func() -> void: _confirm_box.visible = false)
	_confirm_box.add_child(no)


func _card_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(maxi(1, UIKit.px(1, ui_scale)))
	sb.set_corner_radius_all(maxi(2, UIKit.px(3, ui_scale)))
	sb.content_margin_left = UIKit.px(10, ui_scale)
	sb.content_margin_right = UIKit.px(10, ui_scale)
	sb.content_margin_top = UIKit.px(6, ui_scale)
	sb.content_margin_bottom = UIKit.px(6, ui_scale)
	return sb


func _style_stat_button(b: Button) -> void:
	b.add_theme_font_override(&"font", UIKit.read_font())
	b.add_theme_font_size_override(&"font_size", UIKit.px(18, ui_scale))
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.COLOR_WOOD
	sb.border_color = UIKit.COLOR_GOLD_AGED
	sb.set_border_width_all(maxi(1, UIKit.px(1, ui_scale)))
	sb.set_corner_radius_all(0)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = UIKit.COLOR_WOOD_LIGHT
	sb_hover.border_color = UIKit.COLOR_GOLD
	var sb_press := sb.duplicate()
	sb_press.bg_color = UIKit.COLOR_WOOD_DARK
	var sb_dis := sb.duplicate()
	sb_dis.bg_color = UIKit.COLOR_PARCHMENT_SHADE
	sb_dis.border_color = UIKit.COLOR_PARCHMENT_EDGE

	b.add_theme_stylebox_override(&"normal", sb)
	b.add_theme_stylebox_override(&"hover", sb_hover)
	b.add_theme_stylebox_override(&"pressed", sb_press)
	b.add_theme_stylebox_override(&"disabled", sb_dis)
	b.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT)
	b.add_theme_color_override(&"font_hover_color", UIKit.COLOR_NAME_PLAYER)
	b.add_theme_color_override(&"font_disabled_color", UIKit.COLOR_PARCHMENT_EDGE)


func _style_action_button(b: Button, is_primary: bool) -> void:
	b.add_theme_font_override(&"font", UIKit.read_font())
	b.add_theme_font_size_override(&"font_size", UIKit.px(14, ui_scale))
	var sb := StyleBoxFlat.new()
	if is_primary:
		sb.bg_color = UIKit.COLOR_LEAF
		sb.border_color = UIKit.COLOR_GOLD
	else:
		sb.bg_color = UIKit.COLOR_LEATHER
		sb.border_color = UIKit.COLOR_GOLD_AGED
	sb.set_border_width_all(maxi(1, UIKit.px(1, ui_scale)))
	sb.set_corner_radius_all(0)
	sb.content_margin_left = UIKit.px(10, ui_scale)
	sb.content_margin_right = UIKit.px(10, ui_scale)
	sb.content_margin_top = UIKit.px(4, ui_scale)
	sb.content_margin_bottom = UIKit.px(4, ui_scale)

	var sb_hover := sb.duplicate()
	sb_hover.bg_color = sb.bg_color.lightened(0.2)
	sb_hover.border_color = UIKit.COLOR_GOLD_LIGHT

	var sb_press := sb.duplicate()
	sb_press.bg_color = sb.bg_color.darkened(0.2)

	var sb_dis := sb.duplicate()
	sb_dis.bg_color = UIKit.COLOR_PARCHMENT_SHADE
	sb_dis.border_color = UIKit.COLOR_PARCHMENT_EDGE

	b.add_theme_stylebox_override(&"normal", sb)
	b.add_theme_stylebox_override(&"hover", sb_hover)
	b.add_theme_stylebox_override(&"pressed", sb_press)
	b.add_theme_stylebox_override(&"disabled", sb_dis)
	b.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT)
	b.add_theme_color_override(&"font_hover_color", UIKit.COLOR_GOLD_LIGHT)
	b.add_theme_color_override(&"font_disabled_color", UIKit.COLOR_INK_DIM)


func _ready() -> void:
	super._ready()
	for row: Array in ROWS:
		var name_label: Label = content.find_child("Name_%s" % row[0], true, false) as Label
		name_label.text = tr(row[1])
		name_label.tooltip_text = tr(row[2])
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	for row: Array in DERIVED:
		(content.find_child("DName_%s" % row[1], true, false) as Label).text = tr(row[0])
	_reset.text = tr("UI_RESET")
	_confirm.text = tr("UI_CONFIRM")
	_confirm_label.text = tr("UI_CONFIRM_ATTRIBUTES")
	(_confirm_box.get_node(^"Yes") as Button).text = tr("UI_YES")
	(_confirm_box.get_node(^"No") as Button).text = tr("UI_NO")
	_refresh()


func set_points(available: int) -> void:
	if available != _available:
		_reset_pending()
	_available = available
	_refresh()


func set_stats(stats: Dictionary) -> void:
	_stats = stats.duplicate()
	_refresh()


func pending_total() -> int:
	var n: int = 0
	for a: StringName in _pending:
		n += _pending[a]
	return n


func _focus(attr: StringName) -> void:
	_focus_attr = attr
	if _detail != null and _desc.has(attr):
		_detail.text = _desc[attr].text


func _change(attr: StringName, delta: int) -> void:
	_focus(attr)
	var total: int = pending_total()
	if delta > 0 and total >= _available:
		return
	_pending[attr] = maxi(0, _pending[attr] + delta)
	_confirm_box.visible = false
	_refresh()


func _reset_pending() -> void:
	for a: StringName in _pending:
		_pending[a] = 0
	if _confirm_box != null:
		_confirm_box.visible = false
	_refresh()


func _ask_confirm() -> void:
	if pending_total() > 0:
		_confirm_box.visible = true
		reset_size()


func _send() -> void:
	var out: Dictionary = {}
	for a: StringName in _pending:
		if _pending[a] > 0:
			out[a] = _pending[a]
	_confirm_box.visible = false
	if not out.is_empty():
		allocate_requested.emit(out)
	_reset_pending()


func _stat(key: StringName) -> int:
	return int(_stats.get(key, _stats.get(String(key), 0)))


func _refresh() -> void:
	if _points_label == null:
		return
	var left: int = _available - pending_total()
	_points_label.text = tr("UI_ATTRIBUTE_POINTS") % left
	for row: Array in ROWS:
		var a: StringName = row[0]
		var p: int = _pending[a]
		_values[a].text = ("%d (+%d)" % [_stat(a), p]) if p > 0 else str(_stat(a))
		_values[a].add_theme_color_override(&"font_color", PENDING_INK if p > 0 else UIKit.COLOR_INK)
		_plus[a].disabled = left <= 0
		_minus[a].disabled = p <= 0
	for row: Array in DERIVED:
		_derived[row[1]].text = atk_text(_stats) if row[1] == &"atk" else str(_stat(row[1]))
	_refresh_descriptions()
	_confirm.disabled = pending_total() <= 0
	_reset.disabled = pending_total() <= 0


## Descrições com a redução atual de conjuração (DES/INT) e de recarga (ESP), já com o rascunho.
func _refresh_descriptions() -> void:
	var preview: Dictionary = {}
	for k: Variant in _stats:
		preview[StringName(str(k))] = _stats[k]
	for a: StringName in _pending:
		preview[a] = _stat(a) + _pending[a]
	var b: BalanceConfig = Balance.cfg
	for row: Array in ROWS:
		var a: StringName = row[0]
		var text: String = tr(row[2])
		match a:
			&"dex":
				text += "\n" + tr("UI_ATTR_CAST_NOW") % [_pct(CastTiming.cast_attr_reduction(preview)),
						_pct(b.cast_reduction_attr_cap), _pct(b.cast_reduction_per_dex)]
			&"int":
				text += "\n" + tr("UI_ATTR_CAST_NOW_INT") % [_pct(CastTiming.cast_attr_reduction(preview)),
						_pct(b.cast_reduction_attr_cap), _pct(b.cast_reduction_per_int)]
			&"spi":
				text += "\n" + tr("UI_ATTR_COOLDOWN_NOW") % [_pct(CastTiming.cooldown_attr_reduction(preview)),
						_pct(b.cooldown_reduction_cap), _pct(b.cooldown_reduction_per_spi)]
		_desc[a].text = text
	_focus(_focus_attr)


## "ATQ 34 (DES)": o ATK vem do atributo da arma equipada (GDD §6.2, 30/09/2026; o servidor manda
## o índice em CharacterStats.K_ATK_ATTR).
static func atk_text(stats: Dictionary) -> String:
	var atk: int = int(stats.get(&"atk", stats.get("atk", 0)))
	var i: int = int(stats.get(CharacterStats.K_ATK_ATTR, -1))
	if i < 0 or i >= CharacterStats.ATTRIBUTES.size():
		return str(atk)
	var key: String = "STAT_" + String(CharacterStats.ATTRIBUTES[i]).to_upper()
	return "%d (%s)" % [atk, TranslationServer.translate(key)]


static func _pct(frac: float) -> String:
	return String.num(frac * CastTiming.PERCENT, 1).replace(".", ",").trim_suffix(",0")
