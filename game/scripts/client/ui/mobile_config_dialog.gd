class_name MobileConfigDialog
extends GameWindow
## Janela touch-friendly para configurar os 4 atalhos mobile (GDD §9.5):
## O jogador seleciona um dos 4 slots e clica na habilidade ou item que deseja atribuir.

signal slot_assigned(slot_index: int, entry_id: StringName)

var _selected_slot: int = 0
var _slot_buttons: Array[Button] = []
var _catalog_grid: GridContainer
var _hint_label: Label
var _current_hotbar: Array = []


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_MOBILE_CONFIG_TITLE", p_scale)
	name = &"MobileConfigDialog"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", UIKit.px(UIKit.PADDING, ui_scale))
	content.add_child(vbox)

	_hint_label = Label.new()
	_hint_label.text = tr("UI_MOBILE_HINT_ASSIGN")
	_hint_label.add_theme_font_size_override(&"font_size", UIKit.px(11, ui_scale))
	_hint_label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_hint_label)

	# Linha com os 4 slots principais
	var slots_hbox := HBoxContainer.new()
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.add_theme_constant_override(&"separation", UIKit.px(10, ui_scale))
	vbox.add_child(slots_hbox)

	var slot_size: int = UIKit.px(54, ui_scale)
	for i: int in 4:
		var btn := Button.new()
		btn.name = "SlotBtn_%d" % i
		btn.custom_minimum_size = Vector2(slot_size, slot_size)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_slot_button_pressed.bind(i))
		slots_hbox.add_child(btn)
		_slot_buttons.append(btn)

	# Botão de desequipar / limpar slot
	var clear_btn := Button.new()
	clear_btn.text = tr("UI_MOBILE_SLOT_EMPTY")
	clear_btn.custom_minimum_size.y = UIKit.px(28, ui_scale)
	clear_btn.pressed.connect(func() -> void:
		slot_assigned.emit(_selected_slot, &"")
		_refresh_display()
	)
	vbox.add_child(clear_btn)

	# Área de rolagem para catálogo de skills e itens
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(UIKit.px(260, ui_scale), UIKit.px(160, ui_scale))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_catalog_grid = GridContainer.new()
	_catalog_grid.columns = 4
	_catalog_grid.add_theme_constant_override(&"h_separation", UIKit.px(6, ui_scale))
	_catalog_grid.add_theme_constant_override(&"v_separation", UIKit.px(6, ui_scale))
	scroll.add_child(_catalog_grid)


func set_data(hotbar_entries: Array, known_skills: Array, inventory_items: Array) -> void:
	_current_hotbar = hotbar_entries.duplicate()
	_refresh_display()
	_populate_catalog(known_skills, inventory_items)


func _on_slot_button_pressed(idx: int) -> void:
	_selected_slot = idx
	for i: int in _slot_buttons.size():
		_slot_buttons[i].button_pressed = (i == idx)


func _refresh_display() -> void:
	for i: int in _slot_buttons.size():
		var btn: Button = _slot_buttons[i]
		btn.text = "Atalho %d" % (i + 1)
		btn.icon = null
		if i < _current_hotbar.size():
			var entry_id: StringName = StringName(str(_current_hotbar[i]))
			if not entry_id.is_empty():
				var sdef: SkillDef = Content.skill(entry_id)
				if sdef != null:
					btn.icon = HotbarSlot.skill_icon(sdef)
					btn.text = "" if btn.icon != null else HotbarSlot.skill_icon_text(sdef)
				else:
					var idef: ItemDef = Content.item(entry_id)
					if idef != null:
						btn.icon = idef.icon if idef.icon != null else UIKit.item_icon(idef)
						btn.text = "" if btn.icon != null else UIKit.item_name(idef).left(3)


func _populate_catalog(known_skills: Array, inventory_items: Array) -> void:
	for child: Node in _catalog_grid.get_children():
		child.queue_free()

	var item_size: int = UIKit.px(44, ui_scale)

	# Adicionar Skills
	for sk_id in known_skills:
		var sid := StringName(str(sk_id))
		var def: SkillDef = Content.skill(sid)
		if def == null or def.passive:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(item_size, item_size)
		var icon_tex: Texture2D = HotbarSlot.skill_icon(def)
		btn.icon = icon_tex
		if icon_tex == null:
			btn.text = HotbarSlot.skill_icon_text(def)
		btn.expand_icon = true
		btn.tooltip_text = tr(def.name_key)
		btn.pressed.connect(func() -> void:
			if _selected_slot >= 0 and _selected_slot < 4:
				if _selected_slot < _current_hotbar.size():
					_current_hotbar[_selected_slot] = sid
				slot_assigned.emit(_selected_slot, sid)
				_refresh_display()
		)
		_catalog_grid.add_child(btn)

	# Adicionar Consumíveis
	var seen_items: Dictionary = {}
	for inv_slot in inventory_items:
		if not (inv_slot is Dictionary):
			continue
		var iid: StringName = StringName(str((inv_slot as Dictionary).get("item", "")))
		if iid.is_empty() or seen_items.has(iid):
			continue
		var idef: ItemDef = Content.item(iid)
		if idef == null or idef.type != ItemDef.ItemType.CONSUMABLE:
			continue
		seen_items[iid] = true
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(item_size, item_size)
		var icon_tex: Texture2D = idef.icon if idef.icon != null else UIKit.item_icon(idef)
		btn.icon = icon_tex
		if icon_tex == null:
			btn.text = UIKit.item_name(idef).left(3)
		btn.expand_icon = true
		btn.tooltip_text = tr(idef.name_key)
		btn.pressed.connect(func() -> void:
			if _selected_slot >= 0 and _selected_slot < 4:
				if _selected_slot < _current_hotbar.size():
					_current_hotbar[_selected_slot] = iid
				slot_assigned.emit(_selected_slot, iid)
				_refresh_display()
		)
		_catalog_grid.add_child(btn)
