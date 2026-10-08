class_name ShopWindow
extends GameWindow
## Loja de NPC: lista de compra (ícone, nome, preço, "Comprar") com quantidade, e área de venda
## que aceita itens arrastados do inventário. Vender também funciona pelo botão direito/botões do
## inventário enquanto a loja está aberta.

signal buy_requested(item_id: StringName, qty: int)
signal sell_requested(slot: int, qty: int)

const MAX_BUY_QTY: int = 99
## Linhas visíveis antes de rolar.
const VISIBLE_ROWS: int = 6

var shop_id: StringName = &""
var items: Array[StringName] = []

var _list: VBoxContainer
var _qty: SpinBox
var _stars_label: Label
var _sell_area: PanelContainer
var _sell_label: Label
var _stars: int = 0


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_SHOP", p_scale)
	name = &"ShopWindow"
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(UIKit.px(UIKit.SLOT_SIZE * 8, ui_scale),
			VISIBLE_ROWS * (ItemSlot.slot_pixels(ui_scale) + UIKit.px(UIKit.SEPARATION, ui_scale)))
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	var qty_label := Label.new()
	qty_label.text = tr("UI_QUANTITY")
	footer.add_child(qty_label)
	_qty = SpinBox.new()
	_qty.min_value = 1
	_qty.max_value = MAX_BUY_QTY
	_qty.value = 1
	_qty.rounded = true
	footer.add_child(_qty)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_stars_label = Label.new()
	_stars_label.add_theme_color_override(&"font_color", UIKit.COLOR_STARS)
	footer.add_child(_stars_label)
	_sell_area = PanelContainer.new()
	_sell_area.name = &"SellArea"
	_sell_area.add_theme_stylebox_override(&"panel", UIKit.flat_box(UIKit.COLOR_FIELD, UIKit.COLOR_BORDER_DARK,
			maxi(1, UIKit.px(UIKit.BORDER, ui_scale)), UIKit.px(UIKit.PADDING, ui_scale)))
	_sell_area.set_drag_forwarding(Callable(), _can_drop_sell, _drop_sell)
	content.add_child(_sell_area)
	_sell_label = Label.new()
	_sell_label.text = tr("UI_SELL_HINT")
	_sell_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sell_label.custom_minimum_size.x = UIKit.px(UIKit.SLOT_SIZE * 8, ui_scale)
	_sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)  # fica numa caixa escura
	_sell_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_sell_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_area.add_child(_sell_label)
	set_stars(0)


func set_shop(p_shop_id: StringName, p_items: Array[StringName]) -> void:
	shop_id = p_shop_id
	items = p_items.duplicate()
	for child: Node in _list.get_children():
		child.queue_free()
	for id: StringName in items:
		_list.add_child(_make_row(id))
	_refresh_affordable()


func set_stars(stars: int) -> void:
	_stars = stars
	_stars_label.text = tr("UI_STARS") % stars
	_refresh_affordable()


func get_row_count() -> int:
	return items.size()


## Compra direta (usado pelos botões e pelos testes).
func buy(item_id: StringName) -> void:
	var qty: int = int(_qty.value)
	var def: ItemDef = UIKit.item(item_id)
	if def != null and not def.stackable:
		qty = 1
	buy_requested.emit(item_id, qty)


func _make_row(id: StringName) -> Control:
	var def: ItemDef = UIKit.item(id)
	var row := HBoxContainer.new()
	row.name = String(id)
	var slot := ItemSlot.new(ItemSlot.SOURCE_SHOP, -1, ui_scale)
	slot.set_dark_style(true)
	slot.set_item(id, 1)
	row.add_child(slot)
	var name_label := Label.new()
	name_label.text = UIKit.item_name(def) if def != null else String(id)
	name_label.add_theme_color_override(&"font_color", UIKit.rarity_color(def))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var price := Label.new()
	price.name = &"Price"
	price.text = tr("UI_PRICE") % (def.buy_price if def != null else 0)
	price.add_theme_color_override(&"font_color", UIKit.COLOR_STARS)
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(price)
	var btn := Button.new()
	btn.name = &"Buy"
	btn.text = tr("UI_BUY")
	btn.pressed.connect(buy.bind(id))
	row.add_child(btn)
	# Clicar no ícone também mostra a dica; duplo clique compra.
	slot.activated.connect(func(_s: ItemSlot, _alt: bool) -> void: buy(id))
	return row


## Preço acima das Estrelas fica em vermelho (o servidor ainda valida).
func _refresh_affordable() -> void:
	for row: Node in _list.get_children():
		var def: ItemDef = UIKit.item(StringName(row.name))
		var price: Label = row.get_node_or_null(^"Price") as Label
		if price != null and def != null:
			price.add_theme_color_override(&"font_color",
					UIKit.COLOR_STARS if def.buy_price <= _stars else UIKit.COLOR_ERROR)


func _can_drop_sell(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName((data as Dictionary).get("source", &"")) == ItemSlot.SOURCE_INVENTORY


func _drop_sell(_pos: Vector2, data: Variant) -> void:
	var d: Dictionary = data as Dictionary
	sell_requested.emit(int(d.get("index", -1)), int(d.get("qty", 1)))


func _can_drop_data(pos: Vector2, data: Variant) -> bool:
	return _can_drop_sell(pos, data)


func _drop_data(pos: Vector2, data: Variant) -> void:
	_drop_sell(pos, data)
