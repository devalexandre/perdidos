class_name InventoryWindow
extends GameWindow
## Inventário (40 espaços, GDD §11.3): grade com ícones, Estrelas, painel do item selecionado com
## ações (usar/equipar, vender com a loja aberta). Arrastar entre espaços move; arrastar para a loja
## vende; duplo clique ou botão direito usa/equipa (ou vende, com a loja aberta, pelo botão direito).

signal move_requested(from_slot: int, to_slot: int)
signal use_requested(slot: int)
signal equip_requested(slot: int)
signal unequip_requested(equip_slot: StringName)
signal sell_requested(slot: int, qty: int)
## Troca aberta: botão direito põe a pilha na oferta (TradeWindow).
signal trade_offer_requested(slot: int, qty: int)

var shop_open: bool = false
var trade_open: bool = false

var _slots: Array[ItemSlot] = []
var _stars_label: Label
var _detail_name: Label
var _detail_text: Label
var _action_button: Button
var _sell_one_button: Button
var _sell_all_button: Button
var _selected: int = -1
var _data: Array = []


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_INVENTORY", p_scale)
	name = &"InventoryWindow"
	var grid := GridContainer.new()
	grid.columns = UIKit.INVENTORY_COLUMNS
	content.add_child(grid)
	for i: int in UIKit.INVENTORY_SIZE:
		var slot := ItemSlot.new(ItemSlot.SOURCE_INVENTORY, i, ui_scale)
		slot.name = "Slot%d" % i
		slot.selected.connect(_on_slot_selected)
		slot.activated.connect(_on_slot_activated)
		slot.dropped.connect(_on_slot_dropped)
		grid.add_child(slot)
		_slots.append(slot)
	_stars_label = Label.new()
	_stars_label.add_theme_color_override(&"font_color", UIKit.c_stars())
	content.add_child(_stars_label)
	# Painel do item selecionado: funciona sem hover (toque).
	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override(&"panel", UIKit.flat_box(UIKit.COLOR_FIELD, UIKit.COLOR_BORDER_DARK,
			maxi(1, UIKit.px(UIKit.BORDER, ui_scale)), UIKit.px(UIKit.PADDING, ui_scale)))
	content.add_child(detail)
	var dbox := VBoxContainer.new()
	detail.add_child(dbox)
	_detail_name = Label.new()
	dbox.add_child(_detail_name)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size.x = UIKit.px(UIKit.SLOT_SIZE * 6, ui_scale)
	_detail_text.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_detail_text.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
	_detail_text.custom_minimum_size.y = UIKit.px(UIKit.FONT_SIZE_SMALL * 4, ui_scale)
	dbox.add_child(_detail_text)
	var actions := HBoxContainer.new()
	dbox.add_child(actions)
	_action_button = Button.new()
	_action_button.pressed.connect(_on_action_pressed)
	actions.add_child(_action_button)
	_sell_one_button = Button.new()
	_sell_one_button.pressed.connect(func() -> void: _sell_selected(1))
	actions.add_child(_sell_one_button)
	_sell_all_button = Button.new()
	_sell_all_button.pressed.connect(func() -> void: _sell_selected(-1))
	actions.add_child(_sell_all_button)
	set_stars(0)
	_refresh_detail()


func _ready() -> void:
	super._ready()
	_sell_one_button.text = tr("UI_SELL_ONE")
	_sell_all_button.text = tr("UI_SELL_ALL")
	_refresh_detail()


func open() -> void:
	super.open()
	call_deferred("_fit_to_screen")


func _fit_to_screen() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	reset_size()
	clamp_to_screen()


## slots: 40 posições, {} ou {"item": StringName, "qty": int}.
func set_slots(slots: Array) -> void:
	_data = slots.duplicate()
	for i: int in _slots.size():
		var entry: Dictionary = slots[i] if i < slots.size() and slots[i] is Dictionary else {}
		_slots[i].set_item(StringName(entry.get("item", &"")), int(entry.get("qty", 0)))
	_refresh_detail()


func set_stars(stars: int) -> void:
	_stars_label.text = tr("UI_STARS") % stars


func set_shop_open(value: bool) -> void:
	shop_open = value
	_refresh_detail()


func get_slot(i: int) -> ItemSlot:
	return _slots[i]


func get_selected_index() -> int:
	return _selected


func select(i: int) -> void:
	for s: ItemSlot in _slots:
		s.set_selected(s.index == i)
	_selected = i
	_refresh_detail()


# --- Internos -------------------------------------------------------------------------------------

func _on_slot_selected(slot: ItemSlot) -> void:
	select(slot.index)


func _on_slot_activated(slot: ItemSlot, alternate: bool) -> void:
	if alternate and trade_open:
		trade_offer_requested.emit(slot.index, slot.qty)
		return
	if alternate and shop_open:
		# Botão direito com a loja aberta: vende 1 (Shift = a pilha toda).
		_emit_sell(slot.index, slot.qty if Input.is_key_pressed(KEY_SHIFT) else 1)
		return
	_use_or_equip(slot.index)


func _on_slot_dropped(target: ItemSlot, data: Dictionary) -> void:
	var src: StringName = StringName(data.get("source", &""))
	if src == ItemSlot.SOURCE_INVENTORY:
		var from: int = int(data.get("index", -1))
		if from >= 0 and from != target.index:
			move_requested.emit(from, target.index)
			select(target.index)
	elif src == ItemSlot.SOURCE_EQUIPMENT:
		unequip_requested.emit(StringName(data.get("equip_slot", &"")))


func _on_action_pressed() -> void:
	if _selected >= 0:
		_use_or_equip(_selected)


func _use_or_equip(i: int) -> void:
	var def: ItemDef = UIKit.item(_slots[i].item_id)
	if def == null:
		return
	if def.type == ItemDef.ItemType.CONSUMABLE:
		use_requested.emit(i)
	elif _is_equippable(def):
		equip_requested.emit(i)


func _sell_selected(qty: int) -> void:
	if _selected < 0 or _slots[_selected].is_empty():
		return
	_emit_sell(_selected, _slots[_selected].qty if qty < 0 else qty)


func _emit_sell(i: int, qty: int) -> void:
	var def: ItemDef = UIKit.item(_slots[i].item_id)
	if def == null or qty <= 0:
		return
	sell_requested.emit(i, qty)


static func _is_equippable(def: ItemDef) -> bool:
	return def != null and (not def.get_equip_slot().is_empty() or def.is_cosmetic)


func _refresh_detail() -> void:
	if _detail_name == null:
		return
	var slot: ItemSlot = _slots[_selected] if _selected >= 0 else null
	var def: ItemDef = UIKit.item(slot.item_id) if slot != null else null
	if def == null:
		_detail_name.text = tr("UI_INVENTORY_HINT")
		_detail_name.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
		_detail_text.text = ""
		_action_button.visible = false
		_sell_one_button.visible = false
		_sell_all_button.visible = false
		return
	_detail_name.text = UIKit.item_name(def) + (" x%d" % slot.qty if slot.qty > 1 else "")
	_detail_name.add_theme_color_override(&"font_color", UIKit.rarity_color(def))
	var lines: PackedStringArray = UIKit.item_tooltip_text(def, 1).split("\n")
	lines.remove_at(0)
	_detail_text.text = "\n".join(lines)
	var consumable: bool = def.type == ItemDef.ItemType.CONSUMABLE
	_action_button.visible = consumable or _is_equippable(def)
	_action_button.text = tr("UI_USE") if consumable else tr("UI_EQUIP")
	var can_sell: bool = shop_open and def.sell_price > 0
	_sell_one_button.visible = can_sell
	_sell_all_button.visible = can_sell and slot.qty > 1
