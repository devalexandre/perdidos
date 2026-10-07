class_name GearMenu
extends Control
## Agente R (GDD §9.5, 27/09/2026): os botões de menu ficam numa engrenagem no canto inferior direito
## (libera a tela). A engrenagem abre um menu vertical compacto com ícone + nome + atalho de cada
## janela (Skills, Atributos, Missões, Inventário, Personagem, Menu); o botão de carinha abre a barra
## de emotes no mesmo canto. Os atalhos de teclado continuam os mesmos (GameUI/ProgressionHud).
## Cores do texto seguem o painel (UIKit.c_*: tinta no pergaminho, claro no painel escuro). Sem som.

const MARGIN_PX: float = 8.0
## Tamanho do ícone dos botões redondos (px na escala 1,0 = grade × fator).
const BUTTON_ICON_FACTOR: int = 2
const ENTRY_ICON_FACTOR: int = 1
const ENTRY_MIN_WIDTH_PX: float = 176.0
const ENTRY_HOVER: Color = Color(UIKit.COLOR_GOLD, 0.28)
const POPUP_GAP_PX: float = 4.0

var ui_scale: float = 1.0
## Entradas do menu (Button). O ProgressionHud acrescenta as dele no começo.
var entries: VBoxContainer
var emotes: EmoteBar
var gear_button: Button
var emote_button: Button
var menu_panel: PanelContainer
var emote_panel: PanelContainer
var _column: VBoxContainer


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"GearMenu"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var m: int = UIKit.px(MARGIN_PX, ui_scale)
	_column = VBoxContainer.new()
	_column.name = &"Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.alignment = BoxContainer.ALIGNMENT_END
	_column.add_theme_constant_override(&"separation", UIKit.px(POPUP_GAP_PX, ui_scale))
	add_child(_column)

	menu_panel = PanelContainer.new()
	menu_panel.name = &"MenuPanel"
	menu_panel.visible = false
	menu_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_column.add_child(menu_panel)
	entries = VBoxContainer.new()
	entries.name = &"Entries"
	entries.add_theme_constant_override(&"separation", 0)
	entries.custom_minimum_size.x = UIKit.px(ENTRY_MIN_WIDTH_PX, ui_scale)
	menu_panel.add_child(entries)

	emote_panel = PanelContainer.new()
	emote_panel.name = &"EmotePanel"
	emote_panel.visible = false
	emote_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_column.add_child(emote_panel)
	emotes = EmoteBar.new(ui_scale)
	emotes.alignment = BoxContainer.ALIGNMENT_END
	emote_panel.add_child(emotes)

	var row := HBoxContainer.new()
	row.name = &"Buttons"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(row)
	emote_button = _round_button(&"EmoteButton", MenuIcons.SMILEY, "UI_EMOTES_TOOLTIP")
	emote_button.pressed.connect(toggle_emotes)
	row.add_child(emote_button)
	gear_button = _round_button(&"GearButton", MenuIcons.GEAR, "UI_GEAR_TOOLTIP")
	gear_button.pressed.connect(toggle_menu)
	row.add_child(gear_button)
	# Escolher um emote fecha a barra (volta a liberar a tela).
	emotes.emote_selected.connect(func(_id: StringName) -> void: emote_panel.visible = false)

	_column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_column.offset_right = -m
	_column.offset_bottom = -m


func set_mobile_layout(is_mobile: bool) -> void:
	var m: int = UIKit.px(MARGIN_PX, ui_scale)
	_column.offset_bottom = -UIKit.px(300.0, ui_scale) if is_mobile else -m


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _round_button(node_name: StringName, icon_id: StringName, tooltip_key: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.icon = MenuIcons.icon(icon_id, BUTTON_ICON_FACTOR * UIKit.texture_scale(ui_scale))
	b.tooltip_text = tr(tooltip_key)
	return b


## Acrescenta uma entrada (ícone + nome + atalho). index < 0 = no fim. Escolher fecha o menu.
func add_entry(key: String, hotkey: String, icon_id: StringName, cb: Callable, index: int = -1) -> Button:
	var b := Button.new()
	b.name = key
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s (%s)" % [tr(key), hotkey]
	var empty := StyleBoxEmpty.new()
	var hover: StyleBoxFlat = UIKit.flat_box(ENTRY_HOVER, ENTRY_HOVER, 0, 0)
	for st: StringName in [&"normal", &"disabled", &"focus"]:
		b.add_theme_stylebox_override(st, empty)
	for st: StringName in [&"hover", &"pressed", &"hover_pressed"]:
		b.add_theme_stylebox_override(st, hover)
	var row := HBoxContainer.new()
	row.name = &"Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad: int = UIKit.px(UIKit.SEPARATION, ui_scale)
	row.add_theme_constant_override(&"separation", UIKit.px(UIKit.PADDING, ui_scale))
	b.add_child(row)
	var ic := TextureRect.new()
	ic.name = &"Icon"
	ic.texture = MenuIcons.icon(icon_id, ENTRY_ICON_FACTOR * UIKit.texture_scale(ui_scale))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var label := Label.new()
	label.name = &"Label"
	label.text = tr(key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", UIKit.c_text())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	var hint := Label.new()
	hint.name = &"Hotkey"
	hint.text = hotkey
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override(&"font_color", UIKit.c_text_dim())
	hint.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hint)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = pad
	row.offset_right = -pad
	b.custom_minimum_size = Vector2(0.0, row.get_combined_minimum_size().y + pad * 2)
	b.mouse_entered.connect(func() -> void: label.add_theme_color_override(&"font_color", UIKit.c_title()))
	b.mouse_exited.connect(func() -> void: label.add_theme_color_override(&"font_color", UIKit.c_text()))
	b.pressed.connect(func() -> void:
		close_popups()
		cb.call())
	entries.add_child(b)
	if index >= 0:
		entries.move_child(b, mini(index, entries.get_child_count() - 1))
	return b


func toggle_menu() -> void:
	var want: bool = not menu_panel.visible
	close_popups()
	menu_panel.visible = want
	gear_button.set_pressed_no_signal(want)


func toggle_emotes() -> void:
	var want: bool = not emote_panel.visible
	close_popups()
	emote_panel.visible = want
	emote_button.set_pressed_no_signal(want)


func is_open() -> bool:
	return menu_panel.visible or emote_panel.visible


## Fecha o menu e a barra de emotes. true = havia algo aberto.
func close_popups() -> bool:
	var was: bool = is_open()
	menu_panel.visible = false
	emote_panel.visible = false
	gear_button.set_pressed_no_signal(false)
	emote_button.set_pressed_no_signal(false)
	return was


## Nomes das entradas na ordem (testes).
func entry_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Node in entries.get_children():
		out.append(String(c.name))
	return out
