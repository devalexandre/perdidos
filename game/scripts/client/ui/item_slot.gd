class_name ItemSlot
extends PanelContainer
## Espaço de item do UIKit (inventário, equipamento, loja): ícone, quantidade, seleção,
## dica (tooltip) e arrastar-e-soltar. Clique/toque seleciona; duplo clique ou botão direito ativa.
## Os dados arrastados são um Dictionary {source, index, equip_slot, item, qty}.

signal selected(slot: ItemSlot)
signal activated(slot: ItemSlot, alternate: bool)
## Algo foi solto neste espaço (data = dados do arrasto de outro espaço).
signal dropped(slot: ItemSlot, data: Dictionary)

const SOURCE_INVENTORY: StringName = &"inventory"
const SOURCE_EQUIPMENT: StringName = &"equipment"
const SOURCE_SHOP: StringName = &"shop"
const DRAG_KEY: String = "item_slot_drag"
## Opacidade do ícone-fantasma do espaço de equipamento vazio.
const PLACEHOLDER_ALPHA: float = 0.35

var source: StringName = SOURCE_INVENTORY
var index: int = -1
var equip_slot: StringName = &""
var item_id: StringName = &""
var qty: int = 0
var ui_scale: float = 1.0
## Texto mostrado no espaço vazio (ex.: nome do espaço de equipamento).
var empty_hint: String = ""

## Estilo escuro do inventário (07/10/2026): ícone em 2x+, borda pela raridade, vazio discreto.
## Desligado = estilo clássico (equipamento, loja, troca).
var dark_style: bool = false

var _icon: TextureRect
var _qty_label: Label
var _hint_label: Label
var _corner: Control
var _selected: bool = false
var _hovered: bool = false


func _init(p_source: StringName = SOURCE_INVENTORY, p_index: int = -1, p_scale: float = 1.0) -> void:
	source = p_source
	index = p_index
	ui_scale = p_scale
	mouse_filter = Control.MOUSE_FILTER_STOP
	var s: int = slot_pixels(ui_scale)
	custom_minimum_size = Vector2(s, s)
	add_theme_stylebox_override(&"panel", UIKit.slot_box(ui_scale, false))
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ícone 32x32 ampliado por fator inteiro para ficar nítido.
	var icon_px: int = UIKit.ICON_SIZE * UIKit.texture_scale(ui_scale)
	_icon.custom_minimum_size = Vector2(icon_px, icon_px)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_icon)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL - 2, ui_scale))
	_hint_label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DISABLED)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.clip_text = true
	add_child(_hint_label)
	_qty_label = Label.new()
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_qty_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_qty_label.add_theme_constant_override(&"outline_size", UIKit.px(UIKit.OUTLINE_SIZE, ui_scale))
	_qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_qty_label)
	# Foco do controle seleciona (mostra o detalhe do item como o clique).
	focus_entered.connect(func() -> void: selected.emit(self))
	mouse_entered.connect(func() -> void: _set_hovered(true))
	mouse_exited.connect(func() -> void: _set_hovered(false))


## Liga o estilo escuro do inventário: ícone no tamanho de UIKit.inventory_icon_px, quantidade com contorno no canto
## inferior direito, marca de raridade no canto superior esquerdo.
func set_dark_style(value: bool) -> void:
	dark_style = value
	var icon_px: int = UIKit.inventory_icon_px(ui_scale) if value else UIKit.ICON_SIZE * UIKit.texture_scale(ui_scale)
	_icon.custom_minimum_size = Vector2(icon_px, icon_px)
	var s: int = dark_slot_pixels(ui_scale) if value else slot_pixels(ui_scale)
	custom_minimum_size = Vector2(s, s)
	if value:
		_qty_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL - 1, ui_scale))
		_qty_label.add_theme_color_override(&"font_color", UIKit.COLOR_PARCHMENT)
		_qty_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
		if _corner == null:
			_corner = Control.new()
			_corner.name = &"RarityCorner"
			_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_corner.draw.connect(_draw_corner)
			add_child(_corner)
	_refresh_style()


## Lado do espaço escuro em px: ícone (UIKit.inventory_icon_px) + respiro de 2 px de cada lado.
static func dark_slot_pixels(p_scale: float) -> int:
	return UIKit.inventory_icon_px(p_scale) + 2 * UIKit.px(2, p_scale)


## Lado do espaço em px: ícone ampliado por fator inteiro + bordas.
static func slot_pixels(p_scale: float) -> int:
	return UIKit.ICON_SIZE * UIKit.texture_scale(p_scale) \
			+ 2 * maxi(1, UIKit.px(UIKit.BORDER, p_scale)) + UIKit.px(UIKit.SLOT_SIZE - UIKit.ICON_SIZE - 2 * UIKit.BORDER, p_scale)


## Define o conteúdo (item vazio = &"").
func set_item(p_item: StringName, p_qty: int = 1) -> void:
	item_id = p_item
	qty = p_qty if p_item != &"" else 0
	var def: ItemDef = UIKit.item(item_id)
	var tex: Texture2D = UIKit.item_icon(def)
	_icon.texture = tex
	_icon.modulate = Color.WHITE
	_qty_label.text = str(qty) if qty > 1 else ""
	_hint_label.text = empty_hint if item_id == &"" else ""
	if def != null and tex == null:
		# Sem ícone ainda (C em paralelo): mostra o começo do nome.
		_hint_label.text = UIKit.item_name(def).left(3)
		_hint_label.add_theme_color_override(&"font_color", UIKit.rarity_color(def))
	elif item_id == &"":
		_hint_label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DISABLED)
	tooltip_text = UIKit.item_tooltip_text(def, qty) if def != null else ""
	_refresh_style()


func is_empty() -> bool:
	return item_id == &""


func set_selected(value: bool) -> void:
	_selected = value
	_refresh_style()


## Esmaece o espaço (ex.: item que a loja não compra).
func set_dimmed(value: bool) -> void:
	_icon.modulate = Color(1, 1, 1, 0.35) if value else Color.WHITE


func _set_hovered(value: bool) -> void:
	_hovered = value
	if dark_style:
		_refresh_style()


func _refresh_style() -> void:
	if not dark_style:
		add_theme_stylebox_override(&"panel", UIKit.slot_box(ui_scale, _selected))
		return
	var def: ItemDef = UIKit.item(item_id)
	var sb: StyleBoxFlat = UIKit.dark_slot_box(ui_scale, def.rarity if def != null else -1, _selected,
			_hovered and index >= 0)
	var m: int = UIKit.px(3, ui_scale)
	sb.content_margin_left = m
	sb.content_margin_top = m
	sb.content_margin_right = m + UIKit.px(1, ui_scale)
	sb.content_margin_bottom = 0
	add_theme_stylebox_override(&"panel", sb)
	if _corner != null:
		_corner.queue_redraw()


## Triângulo da raridade no canto superior esquerdo (incomum para cima).
func _draw_corner() -> void:
	var def: ItemDef = UIKit.item(item_id)
	if def == null or def.rarity <= 0:
		return
	var c: Color = UIKit.RARITY_EDGE_COLORS[clampi(def.rarity, 0, UIKit.RARITY_EDGE_COLORS.size() - 1)]
	var o: float = float(UIKit.px(1, ui_scale))
	var t: float = float(UIKit.px(10, ui_scale))
	_corner.draw_colored_polygon(PackedVector2Array([Vector2(o, o), Vector2(o + t, o), Vector2(o, o + t)]), c)


func is_selected() -> bool:
	return _selected


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(self)
			if mb.double_click and not is_empty():
				activated.emit(self, false)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not is_empty():
			selected.emit(self)
			activated.emit(self, true)
			accept_event()
	elif has_focus() and event.is_action_pressed(&"ui_accept"):
		# Controle (GamepadInput deixa o espaço focável): A = como o botão direito (usar/vestir/vender/ofertar).
		selected.emit(self)
		if not is_empty():
			activated.emit(self, true)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_empty() or source == SOURCE_SHOP:
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = _icon.custom_minimum_size
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return {DRAG_KEY: true, "source": source, "index": index, "equip_slot": equip_slot,
			"item": item_id, "qty": qty}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(DRAG_KEY) and source != SOURCE_SHOP


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(self, data as Dictionary)


## Dica rica (07/10/2026): ficha do item em painel escuro chanfrado; o painel padrão da dica some.
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null
	var def: ItemDef = UIKit.item(item_id)
	if def == null:
		var l := Label.new()
		l.text = for_text
		l.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		return l
	var panel: Control = UIKit.item_tooltip_panel(def, qty, ui_scale)
	panel.tree_entered.connect(func() -> void:
		var host: Node = panel.get_parent()
		if host is Window:
			(host as Window).add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
			(host as Window).transparent_bg = true, CONNECT_ONE_SHOT)
	return panel
