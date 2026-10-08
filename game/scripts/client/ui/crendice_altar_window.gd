class_name CrendiceAltarWindow
extends GameWindow
## Janela do Altar de Crendice: interface para consagração, encaixe, desencaixe e
## reativação de amuletos folclóricos e visualização de sinergias temáticas.

signal insert_requested(equip_slot: StringName, socket_idx: int, inv_idx: int)
signal remove_requested(equip_slot: StringName, socket_idx: int)
signal consecrate_requested(equip_slot: StringName, socket_idx: int)

const GEAR_SLOTS_ORDER: Array[StringName] = [
	&"weapon", &"offhand", &"body", &"head", &"feet", &"gloves", &"accessory_1", &"accessory_2"
]

var _equip: Dictionary = {}
var _inv_slots: Array = []
var _selected_inv_idx: int = -1

var _altar_title: Label
var _equip_container: VBoxContainer
var _inv_container: VBoxContainer
var _details_panel: PanelContainer
var _details_name: Label
var _details_lore: Label
var _details_effect: Label
var _details_superstition: Label
var _details_synergy: Label
var _synergies_container: VBoxContainer


func _init(p_scale: float = 1.0) -> void:
	super._init("UI_CRENDICE_ALTAR", p_scale)
	name = &"CrendiceAltarWindow"

	# Layout principal: 2 colunas
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override(&"separation", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	content.add_child(main_hbox)

	# --- Coluna Esquerda: Equipamentos e Encaixes ---
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size.x = UIKit.px(320, ui_scale)
	main_hbox.add_child(left_vbox)

	var left_header := Label.new()
	left_header.text = "ENCAIXES DE CRENDICE (EQUIPAMENTOS)"
	left_header.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
	left_header.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	left_vbox.add_child(left_header)

	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.custom_minimum_size = Vector2(UIKit.px(320, ui_scale), UIKit.px(340, ui_scale))
	left_vbox.add_child(left_scroll)

	_equip_container = VBoxContainer.new()
	_equip_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_container.add_theme_constant_override(&"separation", UIKit.px(6, ui_scale))
	left_scroll.add_child(_equip_container)

	# --- Coluna Direita: Amuletos na Mochila, Detalhes e Sinergias ---
	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size.x = UIKit.px(300, ui_scale)
	main_hbox.add_child(right_vbox)

	var right_header := Label.new()
	right_header.text = "AMULETOS NA MOCHILA"
	right_header.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
	right_header.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	right_vbox.add_child(right_header)

	var inv_scroll := ScrollContainer.new()
	inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inv_scroll.custom_minimum_size = Vector2(UIKit.px(300, ui_scale), UIKit.px(100, ui_scale))
	right_vbox.add_child(inv_scroll)

	_inv_container = VBoxContainer.new()
	_inv_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_container.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
	inv_scroll.add_child(_inv_container)

	# Painel de Detalhes
	_details_panel = PanelContainer.new()
	_details_panel.add_theme_stylebox_override(&"panel", UIKit.flat_box(UIKit.COLOR_FIELD, UIKit.COLOR_BORDER_DARK,
			maxi(1, UIKit.px(UIKit.BORDER, ui_scale)), UIKit.px(UIKit.PADDING, ui_scale)))
	right_vbox.add_child(_details_panel)

	var det_vbox := VBoxContainer.new()
	det_vbox.add_theme_constant_override(&"separation", UIKit.px(2, ui_scale))
	_details_panel.add_child(det_vbox)

	_details_name = Label.new()
	_details_name.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
	_details_name.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	det_vbox.add_child(_details_name)

	_details_lore = Label.new()
	_details_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_lore.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
	_details_lore.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	det_vbox.add_child(_details_lore)

	_details_effect = Label.new()
	_details_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_effect.add_theme_color_override(&"font_color", UIKit.COLOR_LEAF_LIGHT)
	_details_effect.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	det_vbox.add_child(_details_effect)

	_details_superstition = Label.new()
	_details_superstition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_superstition.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD)
	_details_superstition.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	det_vbox.add_child(_details_superstition)

	_details_synergy = Label.new()
	_details_synergy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_synergy.add_theme_color_override(&"font_color", Color8(201, 168, 236))
	_details_synergy.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	det_vbox.add_child(_details_synergy)

	_clear_details()

	# Painel de Sinergias Ativas
	var syn_header := Label.new()
	syn_header.text = "SINERGIAS TEMÁTICAS ATIVAS"
	syn_header.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
	syn_header.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	right_vbox.add_child(syn_header)

	var syn_scroll := ScrollContainer.new()
	syn_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	syn_scroll.custom_minimum_size = Vector2(UIKit.px(300, ui_scale), UIKit.px(80, ui_scale))
	right_vbox.add_child(syn_scroll)

	_synergies_container = VBoxContainer.new()
	_synergies_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergies_container.add_theme_constant_override(&"separation", UIKit.px(2, ui_scale))
	syn_scroll.add_child(_synergies_container)


func set_equipment_data(equip: Dictionary) -> void:
	_equip.clear()
	for slot: Variant in equip:
		var entry: Variant = equip[slot]
		# O inventário manda IDs simples; dados ricos de encaixe também são aceitos.
		_equip[slot] = entry.duplicate(true) if entry is Dictionary else {"item": str(entry)}
	_refresh_equip_list()
	_refresh_synergies()


func set_inventory_data(inv_slots: Array) -> void:
	_inv_slots = inv_slots.duplicate(true)
	_refresh_inv_list()


func open_altar(altar_name: String = "Altar de Crendice") -> void:
	title_label.text = altar_name
	_clear_details()
	_refresh_equip_list()
	_refresh_inv_list()
	_refresh_synergies()
	open()


func _clear_details() -> void:
	_selected_inv_idx = -1
	_details_name.text = "Nenhum amuleto selecionado"
	_details_lore.text = "Selecione um amuleto da mochila para ver seus detalhes e consagrá-lo em um equipamento."
	_details_effect.text = ""
	_details_superstition.text = ""
	_details_synergy.text = ""


func _refresh_equip_list() -> void:
	for child: Node in _equip_container.get_children():
		child.queue_free()

	var has_any: bool = false
	for slot_name: StringName in GEAR_SLOTS_ORDER:
		var item_data: Dictionary = _equip.get(slot_name, {})
		if item_data.is_empty():
			continue

		var item_id: StringName = StringName(str(item_data.get("item", "")))
		if item_id.is_empty():
			continue

		var def: ItemDef = Content.item(item_id)
		var max_sockets: int = int(item_data.get("max_sockets", def.get_crendice_sockets() if def != null else 0))
		if max_sockets <= 0:
			continue

		has_any = true
		var card := _create_gear_card(slot_name, item_id, def, item_data, max_sockets)
		_equip_container.add_child(card)

	if not has_any:
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum equipamento com encaixes vestido.\nEquipe armas, armaduras ou acessórios."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
		empty_lbl.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		_equip_container.add_child(empty_lbl)


func _create_gear_card(slot_name: StringName, item_id: StringName, def: ItemDef, item_data: Dictionary, max_sockets: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UIKit.flat_box(UIKit.COLOR_FIELD, UIKit.COLOR_BORDER,
			maxi(1, UIKit.px(1, ui_scale)), UIKit.px(4, ui_scale)))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
	panel.add_child(vbox)

	# Cabeçalho do item
	var item_name: String = UIKit.item_name(def) if def != null else String(item_id)
	var header_lbl := Label.new()
	header_lbl.text = "%s (%s) - %d Encaixe(s)" % [item_name, _slot_display_name(slot_name), max_sockets]
	header_lbl.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
	header_lbl.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	vbox.add_child(header_lbl)

	var crendices: Array = item_data.get("crendices", [])
	var dormants: Array = item_data.get("dormant_crendices", [])

	for i: int in range(max_sockets):
		var socket_row := HBoxContainer.new()
		socket_row.add_theme_constant_override(&"separation", UIKit.px(4, ui_scale))
		vbox.add_child(socket_row)

		if i < crendices.size():
			var c_id: StringName = StringName(str(crendices[i]))
			var is_dormant: bool = bool(dormants[i]) if i < dormants.size() else false
			var c_def: CrendiceDef = CrendiceDatabase.get_crendice(c_id)
			var c_name: String = _amulet_name(c_def) if c_def != null else String(c_id)

			var c_lbl := Label.new()
			c_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c_lbl.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))

			if is_dormant:
				c_lbl.text = "• %s [ADORMECIDO]" % c_name
				c_lbl.add_theme_color_override(&"font_color", UIKit.COLOR_ERROR)
			else:
				c_lbl.text = "• %s [CONSAGRADO]" % c_name
				c_lbl.add_theme_color_override(&"font_color", UIKit.COLOR_LEAF_LIGHT)
			socket_row.add_child(c_lbl)

			if is_dormant:
				var btn_consecrate := Button.new()
				btn_consecrate.text = "Reconsagrar"
				btn_consecrate.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
				btn_consecrate.pressed.connect(func() -> void:
					consecrate_requested.emit(slot_name, i)
				)
				socket_row.add_child(btn_consecrate)

			var btn_remove := Button.new()
			btn_remove.text = "Desencaixar"
			btn_remove.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
			btn_remove.pressed.connect(func() -> void:
				remove_requested.emit(slot_name, i)
			)
			socket_row.add_child(btn_remove)
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "• [Vazio]"
			empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_lbl.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
			empty_lbl.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
			socket_row.add_child(empty_lbl)

			var btn_insert := Button.new()
			btn_insert.text = "Encaixar"
			btn_insert.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
			btn_insert.disabled = (_selected_inv_idx < 0)
			btn_insert.pressed.connect(func() -> void:
				if _selected_inv_idx >= 0:
					insert_requested.emit(slot_name, i, _selected_inv_idx)
			)
			socket_row.add_child(btn_insert)

	return panel


func _refresh_inv_list() -> void:
	for child: Node in _inv_container.get_children():
		child.queue_free()

	var has_amulets: bool = false
	for i: int in range(_inv_slots.size()):
		var slot_data: Dictionary = _inv_slots[i] if _inv_slots[i] != null else {}
		if slot_data.is_empty():
			continue

		var item_id: StringName = StringName(str(slot_data.get("item", "")))
		if item_id.is_empty():
			continue

		var c_def: CrendiceDef = CrendiceDatabase.get_crendice(item_id)
		if c_def == null:
			continue

		has_amulets = true
		var qty: int = int(slot_data.get("qty", 1))
		var btn := Button.new()
		btn.text = "%s (x%d)" % [_amulet_name(c_def), qty]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		if i == _selected_inv_idx:
			btn.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)

		var cur_idx: int = i
		btn.pressed.connect(func() -> void:
			_selected_inv_idx = cur_idx
			_show_amulet_details(c_def)
			_refresh_inv_list()
			_refresh_equip_list()
		)
		_inv_container.add_child(btn)

	if not has_amulets:
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum amuleto na mochila.\nDerrote criaturas sob condições de superstição para encontrá-los!"
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
		empty_lbl.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		_inv_container.add_child(empty_lbl)


func _show_amulet_details(c_def: CrendiceDef) -> void:
	if c_def == null:
		_clear_details()
		return

	_details_name.text = _amulet_name(c_def)
	_details_lore.text = '"%s"' % _amulet_phrase(c_def, "LORE", c_def.lore_key)

	var eff_parts: Array[String] = []
	for k: StringName in c_def.stats:
		eff_parts.append("%+d %s" % [c_def.stats[k], UIKit.stat_label(k)])
	var description: String = _amulet_phrase(c_def, "DESC", c_def.desc_key)
	if description.is_empty():
		var item: ItemDef = Content.item(c_def.id)
		description = tr(item.desc_key) if item != null else ""
	_details_effect.text = "\n".join(eff_parts) + ("\n" + description if not description.is_empty() else "")

	_details_superstition.text = _amulet_phrase(c_def, "SUP", c_def.superstition_desc_key)

	var syn_name: String = tr(str(CrendiceDatabase.get_synergies().get(c_def.synergy_group, {}).get("name_key", "")))
	if not syn_name.is_empty():
		_details_synergy.text = "Sinergia: %s" % syn_name
	else:
		_details_synergy.text = ""


func _refresh_synergies() -> void:
	for child: Node in _synergies_container.get_children():
		child.queue_free()

	# Coleta crendices ativas em todos os equipamentos vestidos
	var active_ids: Array[StringName] = []
	for slot_name: StringName in GEAR_SLOTS_ORDER:
		var item_data: Dictionary = _equip.get(slot_name, {})
		if item_data.is_empty():
			continue
		var crendices: Array = item_data.get("crendices", [])
		var dormants: Array = item_data.get("dormant_crendices", [])
		for i: int in range(crendices.size()):
			var is_dormant: bool = bool(dormants[i]) if i < dormants.size() else false
			if not is_dormant:
				active_ids.append(StringName(str(crendices[i])))

	var active_synergies: Array[Dictionary] = CrendiceSystem.get_active_synergies(active_ids)
	if active_synergies.is_empty():
		var tip := Label.new()
		tip.text = "Nenhuma sinergia ativa.\nEquipe 2 ou 3 amuletos do mesmo tema para despertar poderes folclóricos!"
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT_DIM)
		tip.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		_synergies_container.add_child(tip)
		return

	for syn: Dictionary in active_synergies:
		var s_lbl := Label.new()
		s_lbl.text = "★ %s: %s" % [tr(str(syn.get("name_key", ""))), tr(str(syn.get("desc_key", "")))]
		s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s_lbl.add_theme_color_override(&"font_color", UIKit.COLOR_STARS)
		s_lbl.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
		_synergies_container.add_child(s_lbl)


func _slot_display_name(slot: StringName) -> String:
	match slot:
		&"weapon": return "Arma"
		&"offhand": return "Mão Secundária (Escudo/Aljava)"
		&"body": return "Armadura"
		&"head": return "Cabeça"
		&"feet": return "Calçado"
		&"gloves": return "Luvas"
		&"accessory_1": return "Acessório 1"
		&"accessory_2": return "Acessório 2"
	return String(slot).capitalize()

func _amulet_name(def: CrendiceDef) -> String:
	var item: ItemDef = Content.item(def.id)
	return UIKit.item_name(item) if item != null else tr(def.name_key)

func _amulet_phrase(def: CrendiceDef, suffix: String, fallback: String) -> String:
	for key: String in ["CRENDICE_%s_%s" % [String(def.id).to_upper(), suffix], fallback]:
		if key.is_empty():
			continue
		var text: String = tr(key)
		if text != key:
			return text
	return ""
