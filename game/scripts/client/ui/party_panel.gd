class_name PartyPanel
extends PanelContainer
## Painel do grupo (GDD §13 "barra de vida dos membros na tela"; decisão do dono em 30/09/2026), na lateral
## esquerda, abaixo das barras do jogador. Uma linha por membro: coroa no líder, nome, nível, vida e mana e,
## se estiver em outro mapa, o nome do mapa (ou "desconectado"). Clicar num membro (sendo líder) abre o
## menu com "Passar a liderança" e "Expulsar do grupo". Botão "Sair do grupo" no fim.
## Lê NetParty.party_changed / client_party. Criado pelo GameUI a cada reconstrução (escala).

signal leave_requested
signal xp_mode_requested(mode: StringName)
## O líder clicou num membro (abre o PlayerMenu do GameUI).
signal member_clicked(member_name: String, screen_pos: Vector2)

const MARGIN_LEFT_PX: float = 16.0
## Abaixo das barras de vida e mana do jogador (PlayerBars: 76 + 2 × 14 + 3).
const MARGIN_TOP_PX: float = 116.0
const WIDTH_PX: float = 176.0
const BAR_HEIGHT_PX: float = 6.0
const ROW_GAP_PX: float = 5.0
## Ampliação da coroa (inteira) na escala 1,0 da interface.
const CROWN_SCALE: int = 2
const COLOR_HP: Color = Color8(200, 58, 48)
const COLOR_MP: Color = Color8(64, 120, 220)
const COLOR_BAR_BG: Color = Color(UIKit.COLOR_FIELD, 0.86)
const COLOR_BAR_BORDER: Color = UIKit.COLOR_BORDER_DARK
## Opacidade de quem está desconectado.
const OFFLINE_ALPHA: float = 0.5
## Coroa pixel art (1 = ouro, 2 = pedra), 9 × 5; o contorno escuro é posto em volta no código.
const CROWN_ROWS: Array[String] = [
	"1...1...1",
	"11.111.11",
	"111111111",
	"121212121",
	"111111111",
]
const COLOR_CROWN_GEM: Color = Color8(200, 58, 48)

var ui_scale: float = 1.0
var net_party: Object = null
var local_name: String = ""
var title_label: Label
var rows: VBoxContainer
var xp_split_button: Button
var xp_individual_button: Button
var leave_button: Button
var _state: Dictionary = {}
static var _crown_tex: Texture2D = null


func _init(p_scale: float = 1.0, p_net_party: Object = null) -> void:
	ui_scale = p_scale
	theme = UIKit.build_window_theme(ui_scale)
	net_party = p_net_party
	name = &"PartyPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_theme_stylebox_override(&"panel", UIKit.dark_card_box(ui_scale, 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", UIKit.px(ROW_GAP_PX, ui_scale))
	add_child(box)
	title_label = Label.new()
	title_label.name = &"Title"
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_label.add_theme_color_override(&"font_color", UIKit.COLOR_GOLD_LIGHT)
	title_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	box.add_child(title_label)
	rows = VBoxContainer.new()
	rows.name = &"Rows"
	rows.add_theme_constant_override(&"separation", UIKit.px(ROW_GAP_PX, ui_scale))
	box.add_child(rows)
	var xp_modes := HBoxContainer.new()
	xp_modes.name = &"XpModes"
	xp_modes.add_theme_constant_override(&"separation", UIKit.px(3, ui_scale))
	box.add_child(xp_modes)
	var mode_group := ButtonGroup.new()
	xp_split_button = _xp_mode_button("UI_PARTY_XP_SPLIT", mode_group)
	xp_split_button.name = &"XpSplit"
	xp_split_button.pressed.connect(func() -> void: xp_mode_requested.emit(&"split"))
	xp_modes.add_child(xp_split_button)
	xp_individual_button = _xp_mode_button("UI_PARTY_XP_INDIVIDUAL", mode_group)
	xp_individual_button.name = &"XpIndividual"
	xp_individual_button.pressed.connect(func() -> void: xp_mode_requested.emit(&"individual"))
	xp_modes.add_child(xp_individual_button)
	leave_button = Button.new()
	leave_button.name = &"Leave"
	leave_button.focus_mode = Control.FOCUS_NONE
	leave_button.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	leave_button.pressed.connect(func() -> void: leave_requested.emit())
	box.add_child(leave_button)


func _ready() -> void:
	position = Vector2(UIKit.px(MARGIN_LEFT_PX, ui_scale), UIKit.px(MARGIN_TOP_PX, ui_scale))
	leave_button.text = tr("UI_PARTY_LEAVE")
	if net_party == null:
		net_party = get_node_or_null(^"/root/NetParty")
	if net_party != null:
		if net_party.has_signal(&"party_changed") and not net_party.is_connected(&"party_changed", set_state):
			net_party.connect(&"party_changed", set_state)
		if &"client_party" in net_party:
			set_state(net_party.get(&"client_party") as Dictionary)


## Estado do NetParty ({} = sem grupo: painel some).
func set_state(state: Dictionary) -> void:
	_state = state
	visible = not state.is_empty()
	for c: Node in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	if state.is_empty():
		return
	var members: Array = state.get(NetParty.K_MEMBERS, [])
	title_label.text = UIKit.format_message("UI_PARTY_TITLE", [members.size(), int(state.get(NetParty.K_MAX, 5))])
	var xp_mode := StringName(str(state.get(NetParty.K_XP_MODE, "split")))
	xp_split_button.set_pressed_no_signal(xp_mode == &"split")
	xp_individual_button.set_pressed_no_signal(xp_mode == &"individual")
	var is_leader: bool = str(state.get(NetParty.K_LEADER, "")).to_lower() == local_name.to_lower()
	xp_split_button.disabled = not is_leader
	xp_individual_button.disabled = not is_leader
	var my_map: StringName = _local_map()
	for m: Variant in members:
		if m is Dictionary:
			rows.add_child(_make_row(m as Dictionary, my_map))
	reset_size()


func member_count() -> int:
	return rows.get_child_count()


func _xp_mode_button(key: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.toggle_mode = true
	button.button_group = group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	return button


## Linha do membro pelo nome (testes).
func row_for(member_name: String) -> Control:
	for c: Node in rows.get_children():
		if str(c.get_meta(&"member", "")).to_lower() == member_name.to_lower():
			return c as Control
	return null


func _local_map() -> StringName:
	var nw: Node = get_node_or_null(^"/root/NetWorld")
	return StringName(str(nw.get(&"client_map_id"))) if nw != null else &""


func _make_row(m: Dictionary, my_map: StringName) -> Control:
	var member_name: String = str(m.get(NetParty.K_NAME, ""))
	var online: bool = bool(m.get(NetParty.K_ONLINE, false))
	var row := VBoxContainer.new()
	row.name = StringName("Member_" + member_name.validate_node_name())
	row.set_meta(&"member", member_name)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_constant_override(&"separation", UIKit.px(1.0, ui_scale))
	row.gui_input.connect(_on_row_input.bind(member_name))
	if not online:
		row.modulate.a = OFFLINE_ALPHA
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", UIKit.px(3.0, ui_scale))
	row.add_child(head)
	var crown := TextureRect.new()
	crown.name = &"Crown"
	crown.texture = _crown()
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Escala inteira (pixel art nítida): 2× na interface 1,0.
	crown.custom_minimum_size = Vector2(crown.texture.get_size()) * CROWN_SCALE * UIKit.texture_scale(ui_scale)
	crown.modulate.a = 1.0 if bool(m.get(NetParty.K_IS_LEADER, false)) else 0.0
	head.add_child(crown)
	var is_me: bool = member_name.to_lower() == local_name.to_lower()
	var name_label := _label(member_name, UIKit.COLOR_NAME_LOCAL if is_me else UIKit.COLOR_NAME_PARTY)
	name_label.name = &"Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	head.add_child(name_label)
	if online:
		var lv := _label(UIKit.format_message("UI_PARTY_LEVEL", [int(m.get(NetParty.K_LEVEL, 1))]), UIKit.COLOR_TEXT_DIM)
		lv.name = &"Level"
		head.add_child(lv)
	var hp := _bar(COLOR_HP, int(m.get(NetParty.K_HP, 0)), int(m.get(NetParty.K_MAX_HP, 1)))
	hp.name = &"Hp"
	row.add_child(hp)
	var mp := _bar(COLOR_MP, int(m.get(NetParty.K_MP, 0)), int(m.get(NetParty.K_MAX_MP, 1)))
	mp.name = &"Mp"
	row.add_child(mp)
	var map_id := StringName(str(m.get(NetParty.K_MAP, "")))
	var where: String = ""
	if not online:
		where = tr("UI_PARTY_OFFLINE")
	elif not map_id.is_empty() and map_id != my_map:
		where = map_display_name(map_id)
	if not where.is_empty():
		var w := _label(where, UIKit.COLOR_TEXT_DIM)
		w.name = &"Map"
		w.add_theme_font_size_override(&"font_size", UIKit.px(11.0, ui_scale))
		row.add_child(w)
	return row


## Nome do mapa para o jogador (ZoneDef.name_key traduzido; sem zona, o id).
static func map_display_name(map_id: StringName) -> String:
	var z: ZoneDef = Content.zone(map_id)
	return TranslationServer.translate(z.name_key) if z != null and not z.name_key.is_empty() else String(map_id)


func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	l.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(2.0, ui_scale)))
	return l


func _bar(fill: Color, value: int, max_value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(UIKit.px(WIDTH_PX, ui_scale), UIKit.px(BAR_HEIGHT_PX, ui_scale))
	var border: int = maxi(1, UIKit.px(1.0, ui_scale))
	bar.add_theme_stylebox_override(&"background", UIKit.flat_box(COLOR_BAR_BG, COLOR_BAR_BORDER, border, 0))
	bar.add_theme_stylebox_override(&"fill", UIKit.flat_box(fill, fill.darkened(0.3), border, 0))
	bar.max_value = maxi(1, max_value)
	bar.value = clampi(value, 0, maxi(1, max_value))
	return bar


func _on_row_input(event: InputEvent, member_name: String) -> void:
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed and member_name.to_lower() != local_name.to_lower():
		member_clicked.emit(member_name, get_global_mouse_position())
		accept_event()


static func _crown() -> Texture2D:
	if _crown_tex != null:
		return _crown_tex
	var h: int = CROWN_ROWS.size()
	var w: int = CROWN_ROWS[0].length()
	var img := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			if CROWN_ROWS[y][x] == ".":
				continue
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					if img.get_pixel(x + 1 + ox, y + 1 + oy).a == 0.0:
						img.set_pixel(x + 1 + ox, y + 1 + oy, UIKit.COLOR_OUTLINE)
	for y: int in h:
		for x: int in w:
			match CROWN_ROWS[y][x]:
				"1":
					img.set_pixel(x + 1, y + 1, UIKit.COLOR_STARS)
				"2":
					img.set_pixel(x + 1, y + 1, COLOR_CROWN_GEM)
	_crown_tex = ImageTexture.create_from_image(img)
	return _crown_tex
