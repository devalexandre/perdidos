class_name EquipmentWindow
extends GameWindow
## Personagem: 7 espaços de equipamento (GDD §11.1) + 3 cosméticos separados (ADENDO 1), atributos
## (GDD §6.2, §6.4, §10.2) e Estrelas. Arrastar do inventário para um espaço equipa; arrastar para o
## inventário, duplo clique, botão direito ou o botão "Desequipar" desequipa.

signal equip_requested(inventory_slot: int)
signal unequip_requested(equip_slot: StringName)

## Espaços cosméticos (ADENDO 1): só aceitam itens is_cosmetic.
const COSMETIC_SLOTS: Array[StringName] = [&"cosmetic_head", &"cosmetic_body", &"cosmetic_weapon"]
## Linhas de atributos: [chave de tradução, chave do dicionário, chave do máximo (opcional)].
const STAT_ROWS: Array[Array] = [
	["STAT_LEVEL", &"level", &""], ["STAT_HP", &"hp", &"max_hp"], ["STAT_MP", &"mp", &"max_mp"],
	["STAT_ATK", &"atk", &""], ["STAT_MATK", &"matk", &""], ["STAT_DEF", &"def", &""],
	["STAT_MDEF", &"mdef", &""], ["STAT_STR", &"str", &""], ["STAT_DEX", &"dex", &""],
	["STAT_VIT", &"vit", &""], ["STAT_INT", &"int", &""], ["STAT_SPI", &"spi", &""],
	["STAT_LUK", &"luk", &""],
]

## Largura do texto do item selecionado (quebra de linha).
const DETAIL_WIDTH_PX: float = 250.0

var _slots: Dictionary[StringName, ItemSlot] = {}
var _stat_values: Dictionary[StringName, Label] = {}
var _stars_label: Label
var _selected_name: Label
var _unequip_button: Button
var _selected: StringName = &""
var _stats: Dictionary = {}


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_CHARACTER", p_scale)
	name = &"EquipmentWindow"
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", UIKit.px(UIKit.PADDING, ui_scale))
	content.add_child(columns)

	var left := VBoxContainer.new()
	columns.add_child(left)
	left.add_child(_section_label("UI_EQUIPMENT"))
	left.add_child(_slot_grid(UIKit.EQUIP_SLOTS))
	left.add_child(_section_label("UI_COSMETICS"))
	left.add_child(_slot_grid(COSMETIC_SLOTS))
	_selected_name = Label.new()
	_selected_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_name.custom_minimum_size.x = UIKit.px(DETAIL_WIDTH_PX, ui_scale)
	_selected_name.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	left.add_child(_selected_name)
	_unequip_button = Button.new()
	_unequip_button.pressed.connect(_on_unequip_pressed)
	left.add_child(_unequip_button)

	var right := VBoxContainer.new()
	columns.add_child(right)
	right.add_child(_section_label("UI_ATTRIBUTES"))
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override(&"h_separation", UIKit.px(UIKit.PADDING * 2, ui_scale))
	right.add_child(stats)
	for row: Array in STAT_ROWS:
		var name_label := Label.new()
		name_label.text = tr(row[0])
		name_label.add_theme_color_override(&"font_color", UIKit.c_text_dim())
		stats.add_child(name_label)
		var value := Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats.add_child(value)
		_stat_values[row[1]] = value
	_stars_label = Label.new()
	_stars_label.add_theme_color_override(&"font_color", UIKit.c_stars())
	right.add_child(_stars_label)
	set_stars(0)
	set_stats({})
	_refresh_selection()


func _ready() -> void:
	super._ready()
	_unequip_button.text = tr("UI_UNEQUIP")
	_refresh_selection()


## equip: espaço → item_id ou &"" (7 normais + cosméticos, se o servidor mandar).
func set_equipment(equip: Dictionary) -> void:
	for slot_name: StringName in _slots:
		_slots[slot_name].set_item(StringName(equip.get(String(slot_name), equip.get(slot_name, &""))), 1)
	_refresh_selection()


func set_stats(stats: Dictionary) -> void:
	_stats = stats.duplicate()
	for row: Array in STAT_ROWS:
		var key: StringName = row[1]
		var max_key: StringName = row[2]
		var v: String = str(_stat(key)) if _has_stat(key) else "-"
		if not max_key.is_empty() and _has_stat(max_key):
			v = "%s/%d" % [v, _stat(max_key)]
		if key == &"atk" and _has_stat(key):
			v = AttributesWindow.atk_text(_stats)
		_stat_values[key].text = v


func set_stars(stars: int) -> void:
	_stars_label.text = tr("UI_STARS") % stars


func get_slot(slot_name: StringName) -> ItemSlot:
	return _slots.get(slot_name)


# --- Internos -------------------------------------------------------------------------------------

func _has_stat(key: StringName) -> bool:
	return _stats.has(key) or _stats.has(String(key))


func _stat(key: StringName) -> int:
	return int(_stats.get(key, _stats.get(String(key), 0)))


func _section_label(key: String) -> Label:
	var l := Label.new()
	l.text = tr(key)
	l.add_theme_color_override(&"font_color", UIKit.c_title())
	return l


func _slot_grid(slot_names: Array[StringName]) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	for slot_name: StringName in slot_names:
		var cell := HBoxContainer.new()
		var slot := ItemSlot.new(ItemSlot.SOURCE_EQUIPMENT, -1, ui_scale)
		slot.name = String(slot_name)
		slot.equip_slot = slot_name
		slot.empty_hint = ""
		slot.selected.connect(_on_slot_selected)
		slot.activated.connect(func(s: ItemSlot, _alt: bool) -> void: _unequip(s.equip_slot))
		slot.dropped.connect(_on_slot_dropped)
		slot.set_item(&"")
		cell.add_child(slot)
		var l := Label.new()
		l.text = tr("EQUIP_SLOT_%s" % String(slot_name).to_upper())
		l.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		l.add_theme_color_override(&"font_color", UIKit.c_text_dim())
		l.custom_minimum_size.x = UIKit.px(UIKit.SLOT_SIZE * 2, ui_scale)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(l)
		grid.add_child(cell)
		_slots[slot_name] = slot
	return grid


func _on_slot_selected(slot: ItemSlot) -> void:
	_selected = slot.equip_slot
	for s: ItemSlot in _slots.values():
		s.set_selected(s.equip_slot == _selected)
	_refresh_selection()


func _on_slot_dropped(target: ItemSlot, data: Dictionary) -> void:
	if StringName(data.get("source", &"")) != ItemSlot.SOURCE_INVENTORY:
		return
	var def: ItemDef = UIKit.item(StringName(data.get("item", &"")))
	if def == null or not slot_accepts(target.equip_slot, def):
		return
	equip_requested.emit(int(data.get("index", -1)))


## O item cabe neste espaço? (acessório vale para accessory_1/2; cosmético só nos cosmetic_*).
static func slot_accepts(slot_name: StringName, def: ItemDef) -> bool:
	if def == null:
		return false
	var is_cosmetic_slot: bool = slot_name in COSMETIC_SLOTS
	if def.is_cosmetic != is_cosmetic_slot:
		return false
	var wanted: StringName = def.get_equip_slot()
	if is_cosmetic_slot:
		var kind: String = String(slot_name).trim_prefix("cosmetic_")
		return wanted.is_empty() or String(wanted) == kind \
				or (kind == "weapon" and wanted == &"offhand")
	return wanted == slot_name or (wanted == &"accessory" and String(slot_name).begins_with("accessory_"))


func _on_unequip_pressed() -> void:
	_unequip(_selected)


func _unequip(slot_name: StringName) -> void:
	if slot_name.is_empty() or not _slots.has(slot_name) or _slots[slot_name].is_empty():
		return
	unequip_requested.emit(slot_name)


func _refresh_selection() -> void:
	if _selected_name == null:
		return
	var slot: ItemSlot = _slots.get(_selected)
	var def: ItemDef = UIKit.item(slot.item_id) if slot != null else null
	if def == null:
		_selected_name.text = tr("UI_EQUIPMENT_HINT")
		_selected_name.add_theme_color_override(&"font_color", UIKit.c_text_dim())
		_unequip_button.visible = false
		return
	_selected_name.text = UIKit.item_tooltip_text(def, 1, false)
	_selected_name.add_theme_color_override(&"font_color", UIKit.rarity_color_on_panel(def))
	_unequip_button.visible = true
