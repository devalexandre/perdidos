class_name Hotbar
extends VBoxContainer
## Barra de atalhos (GDD §8.1, §10.1): 10 espaços, teclas 1 a 0, embaixo no centro. Em cima dela a
## barra de conjuração e a de XP (nível, XP/próximo nível, teto da zona). Arrastar uma skill da janela
## de skills (ou um consumível do inventário) para um espaço; arrastar entre espaços troca; botão
## direito limpa. Mudanças só fora de combate (o servidor confere).
## Animada (GDD §8.1 "Tempo de uso na barra"): barra de conjuração enchendo (CastBar), espaços
## apagados durante a conjuração, sombra radial da recarga e brilho "pronto" (HotbarSlot).

signal slot_activated(index: int)
signal slot_assigned(index: int, entry_id: StringName)

## Teclas mostradas em cada espaço (espaço 10 = tecla 0).
const KEY_TEXTS: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const BOTTOM_MARGIN_PX: float = 8.0
## Altura da fileira de botões do HUD (canto inferior direito): a barra fica logo acima dela.
const HUD_ROW_PX: float = 40.0
const BAR_HEIGHT_PX: float = 6.0
const CAST_BAR_HEIGHT_PX: float = 13.0
## Prefixo das recargas de usáveis (grupo) nos dicionários de set_state.
const ITEM_COOLDOWN_PREFIX: String = "item:"
const XP_FONT_PX: int = 13
const XP_FILL: Color = Color8(166, 216, 106)
const XP_FILL_CAPPED: Color = Color8(201, 176, 138)
const MSEC_PER_SEC: float = 1000.0

var ui_scale: float = 1.0
var slots: Array[HotbarSlot] = []
var _slot_tray: PanelContainer
var _mobile_layout: bool = false
var _xp_bar: ProgressBar
var _xp_label: Label
var cast_bar: CastBar
## Skill/usável sendo conjurado agora (&"" = nenhum).
var _cast_entry: StringName = &""
var _in_combat_label: Label


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"Hotbar"
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override(&"separation", UIKit.px(2, ui_scale))
	cast_bar = CastBar.new(ui_scale)
	cast_bar.name = &"CastBar"
	cast_bar.custom_minimum_size.y = UIKit.px(CAST_BAR_HEIGHT_PX, ui_scale)
	cast_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cast_bar.finished.connect(_on_cast_over)
	cast_bar.cancelled.connect(_on_cast_over)
	add_child(cast_bar)
	var info := HBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	_xp_label = Label.new()
	_xp_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_xp_label.add_theme_font_size_override(&"font_size", UIKit.px(XP_FONT_PX, ui_scale))
	_xp_label.add_theme_constant_override(&"outline_size", UIKit.px(UIKit.OUTLINE_SIZE, ui_scale))
	_xp_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_xp_label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT)
	_xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_xp_label)
	_in_combat_label = Label.new()
	_in_combat_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_in_combat_label.add_theme_font_size_override(&"font_size", UIKit.px(XP_FONT_PX, ui_scale))
	_in_combat_label.add_theme_constant_override(&"outline_size", UIKit.px(UIKit.OUTLINE_SIZE, ui_scale))
	_in_combat_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_in_combat_label.add_theme_color_override(&"font_color", UIKit.COLOR_ERROR)
	_in_combat_label.visible = false
	info.add_child(_in_combat_label)
	_xp_bar = _bar(XP_FILL)
	_xp_bar.name = &"XPBar"
	add_child(_xp_bar)
	_slot_tray = PanelContainer.new()
	_slot_tray.name = &"Tray"
	_slot_tray.mouse_filter = Control.MOUSE_FILTER_PASS
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = UIKit.COLOR_HUD_PANEL
	tsb.border_color = UIKit.COLOR_GOLD_AGED
	tsb.set_border_width_all(maxi(1, UIKit.px(2, ui_scale)))
	tsb.set_corner_radius_all(maxi(2, UIKit.px(3, ui_scale)))
	tsb.shadow_size = maxi(2, UIKit.px(4, ui_scale))
	tsb.shadow_color = UIKit.COLOR_SHADOW
	tsb.content_margin_left = UIKit.px(4, ui_scale)
	tsb.content_margin_right = UIKit.px(4, ui_scale)
	tsb.content_margin_top = UIKit.px(3, ui_scale)
	tsb.content_margin_bottom = UIKit.px(3, ui_scale)
	tsb.anti_aliasing = false
	_slot_tray.add_theme_stylebox_override(&"panel", tsb)
	var row := HBoxContainer.new()
	row.name = &"Slots"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", UIKit.px(UIKit.SEPARATION, ui_scale))
	_slot_tray.add_child(row)
	add_child(_slot_tray)
	for i: int in Balance.cfg.hotbar_slots:
		var s := HotbarSlot.new(ui_scale, i, KEY_TEXTS[i] if i < KEY_TEXTS.size() else "")
		s.name = "Slot%d" % (i + 1)
		s.activated.connect(func(sl: HotbarSlot) -> void: slot_activated.emit(sl.index))
		s.cleared.connect(func(sl: HotbarSlot) -> void: slot_assigned.emit(sl.index, &""))
		s.dropped.connect(_on_dropped)
		row.add_child(s)
		slots.append(s)


func _bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.custom_minimum_size.y = UIKit.px(BAR_HEIGHT_PX, ui_scale)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIKit.COLOR_FIELD
	bg.border_color = UIKit.COLOR_BORDER_DARK
	bg.set_border_width_all(maxi(1, UIKit.px(1, ui_scale)))
	bg.set_corner_radius_all(0)
	bg.anti_aliasing = false
	b.add_theme_stylebox_override(&"background", bg)
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.border_color = fill.lightened(0.28)
	f.border_width_top = maxi(1, UIKit.px(1, ui_scale))
	f.border_width_bottom = 0
	f.border_width_left = 0
	f.border_width_right = 0
	f.set_corner_radius_all(0)
	f.anti_aliasing = false
	b.add_theme_stylebox_override(&"fill", f)
	return b


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -UIKit.px(BOTTOM_MARGIN_PX + HUD_ROW_PX, ui_scale)
	cast_bar.custom_minimum_size.x = UIKit.px(ItemSlot.slot_pixels(ui_scale) * 4, 1.0)
	set_mobile_layout(_mobile_layout)


## Rótulo de cada espaço (teclas 1–0 ou, no modo controle, GamepadInput.SLOT_LABELS).
func set_key_texts(texts: Array[String]) -> void:
	for i: int in slots.size():
		slots[i].set_key_text(texts[i] if i < texts.size() else "")


func set_mobile_layout(enabled: bool) -> void:
	_mobile_layout = enabled
	if _slot_tray != null:
		_slot_tray.visible = not enabled
	if enabled:
		custom_minimum_size.x = UIKit.px(300, ui_scale)
	else:
		custom_minimum_size.x = 0.0
	if is_inside_tree():
		reset_size()
		set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		grow_horizontal = Control.GROW_DIRECTION_BOTH
		grow_vertical = Control.GROW_DIRECTION_BEGIN
		offset_bottom = -UIKit.px(BOTTOM_MARGIN_PX + HUD_ROW_PX, ui_scale)


func _on_dropped(target: HotbarSlot, data: Dictionary) -> void:
	var entry := StringName(str(data.get("entry", data.get("item", ""))))
	if entry.is_empty():
		return
	var from_slot: int = int(data.get("from_slot", -1))
	if from_slot >= 0 and from_slot < slots.size() and from_slot != target.index:
		var old_entry: StringName = target.entry_id
		target.set_entry(entry)
		slots[from_slot].set_entry(old_entry)
	else:
		target.set_entry(entry)
	slot_assigned.emit(target.index, entry)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	if d.has(HotbarSlot.SKILL_DRAG_KEY):
		return true
	if d.has(ItemSlot.DRAG_KEY) and StringName(d.get("source", &"")) == ItemSlot.SOURCE_INVENTORY:
		var item: ItemDef = UIKit.item(StringName(d.get("item", &"")))
		return item != null and item.type == ItemDef.ItemType.CONSUMABLE
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var closest: HotbarSlot = null
	var min_dist: float = INF
	var global_pos: Vector2 = global_position + at_position
	for s: HotbarSlot in slots:
		var slot_center: Vector2 = s.global_position + s.size * 0.5
		var d: float = slot_center.distance_squared_to(global_pos)
		if d < min_dist:
			min_dist = d
			closest = s
	if closest != null:
		_on_dropped(closest, data as Dictionary)


## Atualiza o conteúdo a partir do snapshot (hotbar, cooldowns) + mana e inventário atuais.
## stats (Net.client_stats) entra na dica com os tempos efetivos (GDD §8.1).
func set_state(progress: Dictionary, mp: int, inventory: Array, cooldown_ends: Dictionary,
		cooldown_totals: Dictionary, stats: Dictionary = {}) -> void:
	var bar: Array = progress.get("hotbar", [])
	var levels: Dictionary = progress.get("skills", {})
	for i: int in slots.size():
		var entry := StringName(str(bar[i])) if i < bar.size() else &""
		var qty: int = _count(inventory, entry)
		slots[i].set_entry(entry, qty)
		var sd: SkillDef = Content.skill(entry)
		if sd != null:
			slots[i].tooltip_text = "\n".join([tr(sd.name_key), tr(sd.desc_key)] + Array(SkillsWindow.timing_lines(
					sd, maxi(1, int(levels.get(String(entry), 1))), stats)))
			slots[i].set_usable(mp >= sd.mana_cost)
			var key: String = String(entry)
			slots[i].set_cooldown(float(cooldown_ends.get(key, 0.0)), float(cooldown_totals.get(key, 1.0)))
		elif not entry.is_empty():
			slots[i].set_usable(true, qty > 0)
			# Poções: sem recarga (GDD §8.1). Demais usáveis: recarga do grupo.
			var item: ItemDef = Content.item(entry)
			var ikey: String = ITEM_COOLDOWN_PREFIX + String(CastTiming.item_group(item))
			if item != null and not CastTiming.is_instant_item(item):
				slots[i].set_cooldown(float(cooldown_ends.get(ikey, 0.0)), float(cooldown_totals.get(ikey, 1.0)))
			else:
				slots[i].set_cooldown(0.0, 1.0)
		else:
			slots[i].set_cooldown(0.0, 1.0)
	var level: int = int(progress.get("level", 1))
	var xp: int = int(progress.get("xp", 0))
	var nxt: int = maxi(1, int(progress.get("xp_next", 1)))
	var allowed: bool = bool(progress.get("xp_allowed", true))
	_xp_bar.max_value = nxt
	_xp_bar.value = xp if allowed else nxt
	var fill_color: Color = XP_FILL if allowed else XP_FILL_CAPPED
	var f := StyleBoxFlat.new()
	f.bg_color = fill_color
	f.border_color = fill_color.lightened(0.28)
	f.border_width_top = maxi(1, UIKit.px(1, ui_scale))
	f.border_width_bottom = 0
	f.border_width_left = 0
	f.border_width_right = 0
	f.set_corner_radius_all(0)
	f.anti_aliasing = false
	_xp_bar.add_theme_stylebox_override(&"fill", f)
	var xp_text: String = (tr("UI_XP") % [xp, nxt]) if allowed else tr("UI_XP_CAPPED")
	_xp_label.text = "%s · %s" % [tr("UI_LEVEL_SHORT") % level, xp_text]
	_in_combat_label.text = tr("UI_IN_COMBAT")
	_in_combat_label.visible = bool(progress.get("in_combat", false))
	# Conjuração em andamento no snapshot (ex.: janela refeita no meio): retoma sem reiniciar a barra.
	var casting: Dictionary = progress.get("casting", {})
	if not casting.is_empty() and int(casting.get("left_ms", 0)) > 0:
		var id := StringName(str(casting.get("id", "")))
		if not cast_bar.is_casting() or id != _cast_entry:
			start_cast(int(casting.get("total_ms", 0)), id, int(casting.get("left_ms", 0)))


## Barra de conjuração local: total_ms de conjuração de `entry` (skill ou usável), faltando left_ms.
func start_cast(total_ms: int, entry: StringName = &"", left_ms: int = -1) -> void:
	if total_ms <= 0:
		return
	_cast_entry = entry
	cast_bar.start(HotbarSlot.entry_name(entry), total_ms, left_ms)
	_update_slots_casting()


## Conjuração interrompida (NetProgress.cast_cancelled do jogador local).
func cancel_cast() -> void:
	cast_bar.cancel()


func is_casting() -> bool:
	return cast_bar.is_casting()


func casting_entry() -> StringName:
	return _cast_entry if cast_bar.is_casting() else &""


func _on_cast_over() -> void:
	_cast_entry = &""
	_update_slots_casting()


func _update_slots_casting() -> void:
	var casting: bool = cast_bar.is_casting()
	for s: HotbarSlot in slots:
		var own: float = cast_bar.progress() if casting and not s.is_empty() and s.entry_id == _cast_entry else -1.0
		s.set_casting(casting, own)


func _process(_delta: float) -> void:
	if cast_bar.is_casting():
		_update_slots_casting()


## Espaço da barra que tem esta entrada (-1 se nenhum).
func slot_of(entry: StringName) -> int:
	for s: HotbarSlot in slots:
		if s.entry_id == entry:
			return s.index
	return -1


static func _count(inventory: Array, item_id: StringName) -> int:
	if item_id.is_empty() or Content.item(item_id) == null:
		return 0
	var n: int = 0
	for s: Variant in inventory:
		if s is Dictionary and StringName(str((s as Dictionary).get("item", ""))) == item_id:
			n += int((s as Dictionary).get("qty", 0))
	return n
