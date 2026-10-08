class_name TradeWindow
extends GameWindow
## Janela de troca entre personagens (30/09/2026), no visual do UIKit. Dois lados: "Você" (recebe itens
## arrastados do inventário; botão direito num item do inventário também põe a pilha; clique direito num item
## da sua oferta tira) e o outro jogador (só leitura). Cada lado mostra ícone, nome e quantidade de cada item e
## as Estrelas. "Confirmar" trava a oferta; "Trocar" só liga com os dois confirmados; "Cancelar" (ou o X)
## fecha. Qualquer mudança desfaz as confirmações (o servidor decide e manda o estado de novo).
## Lê NetTrade.trade_changed; manda pelos sinais (o GameUI liga ao NetTrade).

signal offer_item_requested(slot: int, qty: int)
signal offer_stars_requested(amount: int)
signal confirm_requested(on: bool)
signal commit_requested
signal cancel_requested

const COLUMN_WIDTH_PX: float = 250.0
const LIST_HEIGHT_PX: float = 196.0
## Espera depois de mexer nas Estrelas antes de mandar (evita um pedido por clique na setinha).
const STARS_DEBOUNCE_SEC: float = 0.5
const COLOR_OK: Color = UIKit.COLOR_STAT_GOOD

var state: Dictionary = {}
var my_stars: int = 0
var mine_list: VBoxContainer
var theirs_list: VBoxContainer
var mine_area: PanelContainer
var stars_spin: SpinBox
var theirs_stars: Label
var mine_status: Label
var theirs_status: Label
var theirs_title: Label
var confirm_button: Button
var commit_button: Button
var cancel_button: Button
var _stars_timer: float = -1.0
var _setting: bool = false


func _init(p_scale: float = 1.0) -> void:
	super("UI_TRADE_TITLE", p_scale)
	name = &"TradeWindow"
	close_button.pressed.disconnect(close)
	close_button.pressed.connect(func() -> void: cancel_requested.emit())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", UIKit.px(10.0, ui_scale))
	content.add_child(cols)
	# --- meu lado
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = UIKit.px(COLUMN_WIDTH_PX, ui_scale)
	cols.add_child(left)
	left.add_child(_title(tr("UI_TRADE_YOU")))
	mine_area = PanelContainer.new()
	mine_area.name = &"MineArea"
	mine_area.add_theme_stylebox_override(&"panel", UIKit.flat_box(UIKit.COLOR_FIELD, UIKit.COLOR_BORDER,
			maxi(1, UIKit.px(1.0, ui_scale)), UIKit.px(4.0, ui_scale)))
	mine_area.set_drag_forwarding(Callable(), _can_drop_offer, _drop_offer)
	left.add_child(mine_area)
	mine_list = _list(mine_area)
	mine_list.name = &"MineList"
	var stars_row := HBoxContainer.new()
	left.add_child(stars_row)
	var sl := _label(tr("UI_TRADE_STARS"), UIKit.COLOR_STARS)
	stars_row.add_child(sl)
	stars_spin = SpinBox.new()
	stars_spin.name = &"Stars"
	stars_spin.min_value = 0
	stars_spin.step = 1
	stars_spin.rounded = true
	stars_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stars_spin.value_changed.connect(_on_stars_changed)
	stars_row.add_child(stars_spin)
	mine_status = _label("", UIKit.COLOR_TEXT_DIM)
	mine_status.name = &"MineStatus"
	left.add_child(mine_status)
	# --- lado do outro
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = UIKit.px(COLUMN_WIDTH_PX, ui_scale)
	cols.add_child(right)
	theirs_title = _title("")
	right.add_child(theirs_title)
	var theirs_area := PanelContainer.new()
	theirs_area.add_theme_stylebox_override(&"panel", UIKit.flat_box(UIKit.COLOR_FIELD, UIKit.COLOR_BORDER,
			maxi(1, UIKit.px(1.0, ui_scale)), UIKit.px(4.0, ui_scale)))
	right.add_child(theirs_area)
	theirs_list = _list(theirs_area)
	theirs_list.name = &"TheirsList"
	theirs_stars = _label("", UIKit.COLOR_STARS)
	theirs_stars.name = &"TheirsStars"
	right.add_child(theirs_stars)
	theirs_status = _label("", UIKit.COLOR_TEXT_DIM)
	theirs_status.name = &"TheirsStatus"
	right.add_child(theirs_status)
	# --- botões
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", UIKit.px(10.0, ui_scale))
	content.add_child(buttons)
	confirm_button = _button(&"Confirm")
	confirm_button.pressed.connect(func() -> void:
		confirm_requested.emit(not bool(_mine().get(NetTrade.K_CONFIRMED, false))))
	buttons.add_child(confirm_button)
	commit_button = _button(&"Commit")
	commit_button.pressed.connect(func() -> void: commit_requested.emit())
	buttons.add_child(commit_button)
	cancel_button = _button(&"Cancel")
	cancel_button.pressed.connect(func() -> void: cancel_requested.emit())
	buttons.add_child(cancel_button)


func _ready() -> void:
	super()
	confirm_button.text = tr("UI_TRADE_CONFIRM")
	commit_button.text = tr("UI_TRADE_COMMIT")
	cancel_button.text = tr("UI_TRADE_CANCEL")
	_refresh()


func _process(delta: float) -> void:
	if _stars_timer >= 0.0:
		_stars_timer -= delta
		if _stars_timer < 0.0:
			offer_stars_requested.emit(int(stars_spin.value))


## Estado do NetTrade ({} = fechada) e Estrelas do jogador local (limite do campo).
func set_state(p_state: Dictionary, p_my_stars: int) -> void:
	state = p_state
	my_stars = p_my_stars
	if state.is_empty():
		close()
		return
	open()
	_refresh()


func set_my_stars(stars: int) -> void:
	my_stars = stars
	_setting = true
	stars_spin.max_value = maxi(stars, int(stars_spin.value))
	_setting = false


func mine_count() -> int:
	return mine_list.get_child_count()


func theirs_count() -> int:
	return theirs_list.get_child_count()


func _mine() -> Dictionary:
	return state.get(NetTrade.K_MINE, {})


func _theirs() -> Dictionary:
	return state.get(NetTrade.K_THEIRS, {})


func _refresh() -> void:
	if state.is_empty() or title_label == null:
		return
	var partner: String = str(state.get(NetTrade.K_PARTNER, ""))
	title_label.text = UIKit.format_message("UI_TRADE_TITLE", [partner])
	theirs_title.text = partner
	_fill(mine_list, _mine().get(NetTrade.K_ITEMS, []), true)
	_fill(theirs_list, _theirs().get(NetTrade.K_ITEMS, []), false)
	_setting = true
	stars_spin.max_value = maxi(my_stars, int(_mine().get(NetTrade.K_STARS, 0)))
	if _stars_timer < 0.0:
		stars_spin.value = int(_mine().get(NetTrade.K_STARS, 0))
	_setting = false
	theirs_stars.text = "%s: %d" % [tr("UI_TRADE_STARS"), int(_theirs().get(NetTrade.K_STARS, 0))]
	var mine_ok: bool = bool(_mine().get(NetTrade.K_CONFIRMED, false))
	var theirs_ok: bool = bool(_theirs().get(NetTrade.K_CONFIRMED, false))
	mine_status.text = _status_text(_mine())
	theirs_status.text = _status_text(_theirs())
	mine_status.add_theme_color_override(&"font_color", COLOR_OK if mine_ok else UIKit.COLOR_TEXT_DIM)
	theirs_status.add_theme_color_override(&"font_color", COLOR_OK if theirs_ok else UIKit.COLOR_TEXT_DIM)
	confirm_button.text = tr("UI_TRADE_UNCONFIRM") if mine_ok else tr("UI_TRADE_CONFIRM")
	commit_button.disabled = not (mine_ok and theirs_ok) or bool(_mine().get(NetTrade.K_COMMITTED, false))
	stars_spin.editable = not mine_ok
	reset_size()


func _status_text(side: Dictionary) -> String:
	if bool(side.get(NetTrade.K_COMMITTED, false)):
		return "✔ " + tr("UI_TRADE_COMMITTED")
	if bool(side.get(NetTrade.K_CONFIRMED, false)):
		return "✔ " + tr("UI_TRADE_CONFIRMED")
	return tr("UI_TRADE_WAITING")


func _fill(list: VBoxContainer, items: Array, mine: bool) -> void:
	for c: Node in list.get_children():
		list.remove_child(c)
		c.queue_free()
	if items.is_empty() and mine:
		var hint := _label(tr("UI_TRADE_DROP_HINT"), UIKit.COLOR_TEXT_DISABLED)
		hint.name = &"Hint"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size.x = UIKit.px(COLUMN_WIDTH_PX - 16.0, ui_scale)
		list.add_child(hint)
		return
	for e: Variant in items:
		var d: Dictionary = e
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var slot := ItemSlot.new(ItemSlot.SOURCE_SHOP, int(d.get(NetTrade.K_SLOT, -1)), ui_scale)
		slot.set_dark_style(true)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.set_item(StringName(str(d.get(NetTrade.K_ITEM, ""))), int(d.get(NetTrade.K_QTY, 1)))
		row.add_child(slot)
		var def: ItemDef = UIKit.item(StringName(str(d.get(NetTrade.K_ITEM, ""))))
		var name_label := _label("%s ×%d" % [UIKit.item_name(def) if def != null else str(d.get(NetTrade.K_ITEM, "")),
				int(d.get(NetTrade.K_QTY, 1))], UIKit.rarity_color(def) if def != null else UIKit.COLOR_TEXT)
		name_label.name = &"Name"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		row.add_child(name_label)
		row.name = "Item_%d" % list.get_child_count()
		if mine:
			slot.activated.connect(func(s: ItemSlot, _alt: bool) -> void: offer_item_requested.emit(s.index, 0))
		list.add_child(row)


func _can_drop_offer(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName((data as Dictionary).get("source", &"")) == ItemSlot.SOURCE_INVENTORY \
			and not bool(_mine().get(NetTrade.K_CONFIRMED, false))


func _drop_offer(_pos: Vector2, data: Variant) -> void:
	var d: Dictionary = data as Dictionary
	offer_item_requested.emit(int(d.get("index", -1)), int(d.get("qty", 1)))


func _on_stars_changed(_value: float) -> void:
	if not _setting:
		_stars_timer = STARS_DEBOUNCE_SEC


func _list(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(UIKit.px(COLUMN_WIDTH_PX - 8.0, ui_scale), UIKit.px(LIST_HEIGHT_PX, ui_scale))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(list)
	return list


func _title(text: String) -> Label:
	var l := _label(text, UIKit.COLOR_TITLE)
	l.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE, ui_scale))
	return l


func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	l.add_theme_color_override(&"font_color", color)
	return l


func _button(n: StringName) -> Button:
	var b := Button.new()
	b.name = n
	b.focus_mode = Control.FOCUS_NONE
	return b
