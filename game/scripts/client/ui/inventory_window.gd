class_name InventoryWindow
extends GameWindow
## Inventário (40 espaços, GDD §11.3) — redesenho "moderno com DNA do RO" (07/10/2026): miolo escuro
## com filete de ouro e cantos chanfrados, abas com contador (Tudo/Equipamento/Consumíveis/Materiais/
## Crendices), grade com borda pela raridade e quantidade no canto, ficha do item selecionado com ações
## (usar/equipar, vender com a loja aberta), rodapé com Estrelas, barra de ocupação da mochila (com marcas,
## como a barra de peso do RO — o jogo não tem peso) e botão Organizar.
## Arrastar entre espaços move; arrastar para a loja vende; duplo clique ou botão direito usa/equipa
## (ou vende, com a loja aberta, pelo botão direito). Nas abas filtradas a grade mostra os itens da
## categoria e depois os espaços vazios reais (soltar num deles move para lá).

signal move_requested(from_slot: int, to_slot: int)
signal use_requested(slot: int)
signal equip_requested(slot: int)
signal unequip_requested(equip_slot: StringName)
signal sell_requested(slot: int, qty: int)
## Troca aberta: botão direito põe a pilha na oferta (TradeWindow).
signal trade_offer_requested(slot: int, qty: int)

enum Tab { ALL, EQUIP, USE, MATERIAL, CRENDICE }
const TAB_KEYS: Array[String] = ["UI_INV_TAB_ALL", "UI_INV_TAB_EQUIP", "UI_INV_TAB_USE", "UI_INV_TAB_MATERIAL",
	"UI_INV_TAB_CRENDICE"]
## Organizar = sequência de trocas (o servidor só conhece "mover"); abaixo do limite de 30 mensagens/s.
const SORT_MOVES_PER_SEC: float = 10.0
## Ordem das categorias ao organizar: equipamentos (por espaço), consumíveis, crendices, materiais.
const SORT_EQUIP_ORDER: Array[StringName] = [&"weapon", &"offhand", &"head", &"body", &"gloves", &"feet",
	&"accessory"]
## Ocupação a partir da qual a barra da mochila fica âmbar (quase cheia).
const CAPACITY_WARN: float = 0.9
const GRID_SEPARATION: int = 4
## Altura mínima da ficha do item (px na escala 1,0): a janela não pula ao trocar de item.
const DETAIL_MIN_HEIGHT: float = 104.0
## Fração da largura da grade para a coluna esquerda da ficha (ícone, nome, descrição).
const DETAIL_LEFT_FRACTION: float = 0.53

var shop_open: bool = false
var trade_open: bool = false

var _slots: Array[ItemSlot] = []
var _tab_buttons: Array[Button] = []
var _tab: int = Tab.ALL
var _count_label: Label
var _stars_label: Label
var _capacity: CapacityBar
var _capacity_label: Label
var _sort_button: Button
var _detail_body: VBoxContainer
var _detail_left: VBoxContainer
var _detail_cols: HBoxContainer
var _detail_hint: Label
var _actions: HBoxContainer
var _action_button: Button
var _sell_one_button: Button
var _sell_all_button: Button
var _selected: int = -1
var _data: Array = []
var _sort_queue: Array = []
var _sort_wait: float = 0.0


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_INVENTORY", p_scale)
	name = &"InventoryWindow"
	(scroll.get_parent() as PanelContainer).add_theme_stylebox_override(&"panel", UIKit.dark_body_box(ui_scale))
	content.add_theme_constant_override(&"separation", UIKit.px(8, ui_scale))
	_build_header()
	var touch: bool = UIKit.is_touch_layout()
	# Abas com contador.
	var tabs := HBoxContainer.new()
	tabs.name = &"Tabs"
	tabs.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
	content.add_child(tabs)
	var group := ButtonGroup.new()
	for i: int in TAB_KEYS.size():
		var b := Button.new()
		b.name = &"Tab%d" % i
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == Tab.ALL
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		if touch:
			b.custom_minimum_size.y = UIKit.px(38, ui_scale)
		UIKit.style_pill_tab(b, ui_scale)
		b.pressed.connect(set_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	# Grade.
	var grid := GridContainer.new()
	grid.name = &"Grid"
	grid.columns = UIKit.INVENTORY_COLUMNS
	grid.add_theme_constant_override(&"h_separation", UIKit.px(GRID_SEPARATION, ui_scale))
	grid.add_theme_constant_override(&"v_separation", UIKit.px(GRID_SEPARATION, ui_scale))
	content.add_child(grid)
	for i: int in UIKit.INVENTORY_SIZE:
		var slot := ItemSlot.new(ItemSlot.SOURCE_INVENTORY, i, ui_scale)
		slot.name = "Slot%d" % i
		slot.set_dark_style(true)
		slot.selected.connect(_on_slot_selected)
		slot.activated.connect(_on_slot_activated)
		slot.dropped.connect(_on_slot_dropped)
		grid.add_child(slot)
		_slots.append(slot)
	_build_footer()
	_build_detail(touch)
	set_stars(0)
	_refresh_all()
	set_process(false)


func _ready() -> void:
	super._ready()
	title_label.text = tr("UI_INVENTORY").to_upper()
	_sell_one_button.text = tr("UI_SELL_ONE")
	_sell_all_button.text = tr("UI_SELL_ALL")
	_sort_button.text = tr("UI_INV_SORT")
	_sort_button.tooltip_text = tr("UI_INV_SORT_HINT")
	_refresh_all()


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
	_data.resize(UIKit.INVENTORY_SIZE)
	if _selected >= 0 and _entry(_selected).is_empty():
		_selected = -1
	_refresh_all()


func set_stars(stars: int) -> void:
	_stars_label.text = UIKit.stars_text(stars)


func set_shop_open(value: bool) -> void:
	shop_open = value
	_refresh_grid()
	_refresh_detail()


## Espaço que mostra o espaço real i do inventário (na aba Tudo, a célula i).
func get_slot(i: int) -> ItemSlot:
	for s: ItemSlot in _slots:
		if s.index == i:
			return s
	return _slots[i]


func get_selected_index() -> int:
	return _selected


func get_tab() -> int:
	return _tab


func select(i: int) -> void:
	_selected = i
	for s: ItemSlot in _slots:
		s.set_selected(i >= 0 and s.index == i)
	_refresh_detail()


## Troca a aba (Tab.ALL...). A seleção some se o item não está na categoria.
func set_tab(tab: int) -> void:
	_tab = clampi(tab, 0, TAB_KEYS.size() - 1)
	for i: int in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	if _selected >= 0 and _tab != Tab.ALL and item_tab(UIKit.item(_entry_id(_selected))) != _tab:
		_selected = -1
	_refresh_grid()
	_refresh_detail()


## Quantos itens (pilhas) há em cada aba.
func tab_counts() -> Array[int]:
	var counts: Array[int] = []
	counts.resize(TAB_KEYS.size())
	for i: int in _data.size():
		var def: ItemDef = UIKit.item(_entry_id(i))
		if def == null:
			continue
		counts[Tab.ALL] += 1
		counts[item_tab(def)] += 1
	return counts


## Organiza a mochila: categoria, raridade (maior primeiro) e nome. Manda as trocas aos poucos.
func sort_items() -> void:
	if not _sort_queue.is_empty():
		return
	_sort_queue = sort_plan(_data)
	_sort_wait = 0.0
	_sort_button.disabled = not _sort_queue.is_empty()
	set_process(not _sort_queue.is_empty())


func is_sorting() -> bool:
	return not _sort_queue.is_empty()


func _process(delta: float) -> void:
	_sort_wait -= delta
	if _sort_wait > 0.0:
		return
	_sort_wait = 1.0 / SORT_MOVES_PER_SEC
	if _sort_queue.is_empty():
		_sort_button.disabled = false
		set_process(false)
		return
	var m: Array = _sort_queue.pop_front()
	move_requested.emit(int(m[0]), int(m[1]))


## Aba de um item: crendice, consumível, equipamento (inclui munição e cosmético) ou material.
static func item_tab(def: ItemDef) -> int:
	if def == null:
		return Tab.ALL
	if def.type == ItemDef.ItemType.CRENDICE or def.is_crendice():
		return Tab.CRENDICE
	if def.type == ItemDef.ItemType.CONSUMABLE:
		return Tab.USE
	if def.is_equippable():
		return Tab.EQUIP
	return Tab.MATERIAL


## Plano de trocas [de, para] que deixa a mochila em ordem. Só troca itens diferentes (o servidor
## juntaria pilhas iguais), então a simulação aqui bate com o servidor passo a passo.
static func sort_plan(slots: Array) -> Array:
	var cur: Array[StringName] = []
	var present: Array[Dictionary] = []
	for i: int in UIKit.INVENTORY_SIZE:
		var e: Variant = slots[i] if i < slots.size() else null
		var id: StringName = StringName((e as Dictionary).get("item", &"")) if e is Dictionary else &""
		cur.append(id)
		if id != &"":
			present.append({"id": id, "i": i, "key": _sort_key(UIKit.item(id), id)})
	present.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["key"] < b["key"] or (a["key"] == b["key"] and int(a["i"]) < int(b["i"])))
	var moves: Array = []
	for i: int in present.size():
		var want: StringName = present[i]["id"]
		if cur[i] == want:
			continue
		var j: int = -1
		for k: int in range(i + 1, cur.size()):
			if cur[k] == want:
				j = k
				break
		if j < 0:
			continue
		moves.append([j, i])
		cur[j] = cur[i]
		cur[i] = want
	return moves


static func _sort_key(def: ItemDef, id: StringName) -> String:
	if def == null:
		return "9|9|%s" % id
	var cat: int = [4, 0, 1, 3, 2][item_tab(def)]
	var sub: int = 9
	if cat == 0:
		var es: int = SORT_EQUIP_ORDER.find(def.get_equip_slot())
		sub = 8 if def.is_cosmetic else (es if es >= 0 else 7)
	return "%d|%d|%d|%s|%s" % [cat, sub, 9 - int(def.rarity), UIKit.item_name(def).to_lower(), id]


# --- Montagem -------------------------------------------------------------------------------------

## Cabeçalho: losango, título em versalete (maiúsculas espaçadas) e contador de espaços.
func _build_header() -> void:
	var bar: HBoxContainer = title_label.get_parent() as HBoxContainer
	var diamond := TextureRect.new()
	diamond.name = &"TitleIcon"
	diamond.texture = UIKit.diamond_icon(ui_scale)
	diamond.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	diamond.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	diamond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(diamond)
	bar.move_child(diamond, 0)
	var spaced := FontVariation.new()
	spaced.base_font = UIKit.read_font()
	spaced.spacing_glyph = UIKit.px(1, ui_scale)
	title_label.add_theme_font_override(&"font", spaced)
	title_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_TITLE - 2, ui_scale))
	_count_label = UIKit.dark_label("", ui_scale, UIKit.FONT_SIZE_SMALL, UIKit.COLOR_PARCHMENT_SHADE)
	_count_label.name = &"SlotCount"
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.tooltip_text = ""
	bar.add_child(_count_label)
	bar.move_child(_count_label, close_button.get_index())
	var gap := Control.new()
	gap.custom_minimum_size.x = UIKit.px(6, ui_scale)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)
	bar.move_child(gap, close_button.get_index())


## Rodapé: Estrelas | barra da mochila (ocupação com marcas) | Organizar.
func _build_footer() -> void:
	var footer := PanelContainer.new()
	footer.name = &"Footer"
	footer.add_theme_stylebox_override(&"panel", UIKit.dark_card_box(ui_scale, 6.0))
	content.add_child(footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	footer.add_child(row)
	row.add_child(UIKit.star_icon_rect(ui_scale))
	_stars_label = UIKit.dark_label("", ui_scale, UIKit.FONT_SIZE, UIKit.COLOR_GOLD)
	_stars_label.name = &"Stars"
	_stars_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_stars_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var bag: Label = UIKit.dark_label("", ui_scale, UIKit.FONT_SIZE_SMALL - 2, UIKit.COLOR_TEXT_DIM)
	bag.name = &"BagLabel"
	bag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bag.set_meta(&"key", "UI_INV_BAG")
	row.add_child(bag)
	_capacity = CapacityBar.new()
	_capacity.name = &"Capacity"
	_capacity.ui_scale = ui_scale
	_capacity.custom_minimum_size = Vector2(UIKit.px(120, ui_scale), UIKit.px(10, ui_scale))
	_capacity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_capacity)
	_capacity_label = UIKit.dark_label("", ui_scale, UIKit.FONT_SIZE_SMALL, UIKit.COLOR_PARCHMENT)
	_capacity_label.name = &"CapacityText"
	_capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_capacity_label)
	var gap := Control.new()
	gap.custom_minimum_size.x = UIKit.px(4, ui_scale)
	row.add_child(gap)
	_sort_button = Button.new()
	_sort_button.name = &"Sort"
	_sort_button.focus_mode = Control.FOCUS_NONE
	_sort_button.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	UIKit.style_pill_tab(_sort_button, ui_scale)
	_sort_button.pressed.connect(sort_items)
	row.add_child(_sort_button)


## Ficha do item selecionado (funciona sem hover: toque): à esquerda ícone, nome e descrição; à
## direita atributos, preço e ações.
func _build_detail(touch: bool) -> void:
	var detail := PanelContainer.new()
	detail.name = &"Detail"
	detail.add_theme_stylebox_override(&"panel", UIKit.dark_card_box(ui_scale, 8.0))
	detail.custom_minimum_size.y = UIKit.px(DETAIL_MIN_HEIGHT, ui_scale)
	content.add_child(detail)
	var stack := Control.new()
	detail.add_child(stack)
	_detail_hint = UIKit.dark_label("", ui_scale, UIKit.FONT_SIZE_SMALL, UIKit.COLOR_TEXT_DISABLED)
	_detail_hint.name = &"Hint"
	_detail_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_detail_hint)
	var cols := HBoxContainer.new()
	cols.name = &"Columns"
	cols.add_theme_constant_override(&"separation", UIKit.px(10, ui_scale))
	detail.add_child(cols)
	_detail_left = VBoxContainer.new()
	_detail_left.name = &"Left"
	_detail_left.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	_detail_left.custom_minimum_size.x = UIKit.px(_detail_left_width(), ui_scale)
	cols.add_child(_detail_left)
	var rule := ColorRect.new()
	rule.color = Color(UIKit.COLOR_GOLD_AGED, 0.45)
	rule.custom_minimum_size.x = maxi(1, UIKit.px(1, ui_scale))
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(rule)
	var right := VBoxContainer.new()
	right.name = &"Right"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	cols.add_child(right)
	_detail_body = VBoxContainer.new()
	_detail_body.name = &"Card"
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	right.add_child(_detail_body)
	_actions = HBoxContainer.new()
	_actions.name = &"Actions"
	_actions.alignment = BoxContainer.ALIGNMENT_END
	_actions.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
	right.add_child(_actions)
	_sell_one_button = Button.new()
	_sell_one_button.pressed.connect(func() -> void: _sell_selected(1))
	_sell_all_button = Button.new()
	_sell_all_button.pressed.connect(func() -> void: _sell_selected(-1))
	_action_button = Button.new()
	_action_button.pressed.connect(_on_action_pressed)
	for b: Button in [_sell_one_button, _sell_all_button, _action_button]:
		b.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		b.custom_minimum_size = Vector2(UIKit.px(64, ui_scale), UIKit.px(40 if touch else 28, ui_scale))
		_actions.add_child(b)
	_detail_cols = cols


## Larguras das colunas da ficha (px na escala 1,0), tiradas da largura da grade: a ficha nunca
## alarga a janela, em qualquer escala.
func _grid_width_1x() -> float:
	var cols: int = UIKit.INVENTORY_COLUMNS
	return (cols * ItemSlot.dark_slot_pixels(ui_scale) + (cols - 1) * UIKit.px(GRID_SEPARATION, ui_scale)) / ui_scale


func _detail_left_width() -> float:
	return floorf(_grid_width_1x() * DETAIL_LEFT_FRACTION)


func _detail_right_width() -> float:
	return floorf(_grid_width_1x() - _detail_left_width() - 50.0)


# --- Internos -------------------------------------------------------------------------------------

func _entry(i: int) -> Dictionary:
	return _data[i] if i >= 0 and i < _data.size() and _data[i] is Dictionary else {}


func _entry_id(i: int) -> StringName:
	return StringName(_entry(i).get("item", &""))


func _refresh_all() -> void:
	if _count_label == null:
		return
	var counts: Array[int] = tab_counts()
	for i: int in _tab_buttons.size():
		_tab_buttons[i].text = "%s  %d" % [tr(TAB_KEYS[i]), counts[i]]
	var used: int = counts[Tab.ALL]
	_count_label.text = "%d/%d" % [used, UIKit.INVENTORY_SIZE]
	_capacity.set_fill(used, UIKit.INVENTORY_SIZE)
	_capacity_label.text = "%d / %d" % [used, UIKit.INVENTORY_SIZE]
	var bag: Label = _capacity.get_parent().get_node(^"BagLabel") as Label
	bag.text = tr(String(bag.get_meta(&"key"))).to_upper()
	_refresh_grid()
	_refresh_detail()


## Liga cada célula da grade a um espaço real (aba Tudo: célula i = espaço i; aba filtrada: itens da
## categoria e depois os espaços vazios; o resto fica inerte).
func _refresh_grid() -> void:
	var shown: Array[int] = []
	if _tab == Tab.ALL:
		for i: int in UIKit.INVENTORY_SIZE:
			shown.append(i)
	else:
		for i: int in UIKit.INVENTORY_SIZE:
			if item_tab(UIKit.item(_entry_id(i))) == _tab:
				shown.append(i)
		for i: int in UIKit.INVENTORY_SIZE:
			if _entry_id(i) == &"":
				shown.append(i)
	for c: int in _slots.size():
		var cell: ItemSlot = _slots[c]
		if c < shown.size():
			cell.index = shown[c]
			var e: Dictionary = _entry(cell.index)
			cell.set_item(StringName(e.get("item", &"")), int(e.get("qty", 0)))
			cell.modulate = Color.WHITE
		else:
			cell.index = -1
			cell.set_item(&"")
			cell.modulate = Color(1, 1, 1, 0.4)
		var def: ItemDef = UIKit.item(cell.item_id)
		cell.set_dimmed(shop_open and def != null and def.sell_price <= 0)
		cell.set_selected(_selected >= 0 and cell.index == _selected)


func _on_slot_selected(slot: ItemSlot) -> void:
	if slot.index >= 0:
		select(slot.index if not slot.is_empty() else -1)


func _on_slot_activated(slot: ItemSlot, alternate: bool) -> void:
	if slot.index < 0:
		return
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
		if from >= 0 and target.index >= 0 and from != target.index:
			move_requested.emit(from, target.index)
			select(target.index)
	elif src == ItemSlot.SOURCE_EQUIPMENT:
		unequip_requested.emit(StringName(data.get("equip_slot", &"")))


func _on_action_pressed() -> void:
	if _selected >= 0:
		_use_or_equip(_selected)


func _use_or_equip(i: int) -> void:
	var def: ItemDef = UIKit.item(_entry_id(i))
	if def == null:
		return
	if def.type == ItemDef.ItemType.CONSUMABLE:
		use_requested.emit(i)
	elif _is_equippable(def):
		equip_requested.emit(i)


func _sell_selected(qty: int) -> void:
	var e: Dictionary = _entry(_selected)
	if e.is_empty():
		return
	_emit_sell(_selected, int(e.get("qty", 0)) if qty < 0 else qty)


func _emit_sell(i: int, qty: int) -> void:
	var def: ItemDef = UIKit.item(_entry_id(i))
	if def == null or qty <= 0:
		return
	sell_requested.emit(i, qty)


static func _is_equippable(def: ItemDef) -> bool:
	return def != null and (not def.get_equip_slot().is_empty() or def.is_cosmetic)


func _refresh_detail() -> void:
	if _detail_body == null:
		return
	for box: VBoxContainer in [_detail_left, _detail_body]:
		for c: Node in box.get_children():
			box.remove_child(c)
			c.queue_free()
	var def: ItemDef = UIKit.item(_entry_id(_selected)) if _selected >= 0 else null
	if def == null:
		_detail_hint.text = tr("UI_INVENTORY_HINT")
		_detail_hint.visible = true
		_detail_cols.visible = false
		return
	var qty: int = int(_entry(_selected).get("qty", 1))
	_detail_hint.visible = false
	_detail_cols.visible = true
	var head: HBoxContainer = UIKit.item_card_head(def, qty, ui_scale, _detail_left_width())
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	_detail_left.add_child(head)
	# Descrição logo abaixo do nome, ao lado do ícone (a ficha fica baixa).
	var titles: VBoxContainer = head.get_child(head.get_child_count() - 1) as VBoxContainer
	var name_l: Label = titles.get_node(^"ItemName") as Label
	var desc: Label = UIKit.item_card_desc(def, ui_scale, name_l.custom_minimum_size.x / ui_scale)
	if desc != null:
		titles.add_child(desc)
	(head.get_child(0) as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	titles.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var stats: Control = UIKit.item_card_stats(def, ui_scale, _detail_right_width())
	if stats != null:
		_detail_body.add_child(stats)
	var foot: Control = UIKit.item_card_footer(def, ui_scale)
	if foot != null:
		_detail_body.add_child(foot)
	var consumable: bool = def.type == ItemDef.ItemType.CONSUMABLE
	_action_button.visible = consumable or _is_equippable(def)
	_action_button.text = tr("UI_USE") if consumable else tr("UI_EQUIP")
	var can_sell: bool = shop_open and def.sell_price > 0
	_sell_one_button.visible = can_sell
	_sell_all_button.visible = can_sell and qty > 1
	_actions.visible = _action_button.visible or can_sell


## Barra da mochila: ocupação dos espaços com marcas a cada 5 (DNA da barra de peso do RO).
class CapacityBar:
	extends Control

	var ui_scale: float = 1.0
	var used: int = 0
	var total: int = 40

	func set_fill(p_used: int, p_total: int) -> void:
		used = p_used
		total = maxi(1, p_total)
		tooltip_text = "%d / %d" % [used, total]
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var line: float = maxf(1.0, UIKit.px(1, ui_scale))
		draw_rect(r, UIKit.COLOR_OUTLINE)
		var inner: Rect2 = r.grow(-line)
		draw_rect(inner, UIKit.COLOR_SLOT_DARK_EMPTY)
		var frac: float = clampf(float(used) / float(total), 0.0, 1.0)
		var fill_c: Color = UIKit.COLOR_GOLD if frac < InventoryWindow.CAPACITY_WARN else UIKit.COLOR_STAT_BAD
		if used >= total:
			fill_c = UIKit.COLOR_LEATHER.lightened(0.15)
		var fill := Rect2(inner.position, Vector2(floorf(inner.size.x * frac), inner.size.y))
		draw_rect(fill, fill_c.darkened(0.25))
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, ceilf(fill.size.y * 0.45))), fill_c)
		var ticks: int = total / 5
		for t: int in range(1, ticks):
			var x: float = floorf(inner.position.x + inner.size.x * float(t) / float(ticks))
			draw_rect(Rect2(x, inner.position.y, line, inner.size.y), Color(UIKit.COLOR_OUTLINE, 0.8))
		draw_rect(r, UIKit.COLOR_GOLD_AGED, false, line)
