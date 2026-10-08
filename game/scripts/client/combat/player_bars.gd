class_name PlayerBars
extends PanelContainer
## Unit Frame com medalhão de avatar, nível, nome, e barras de vida (rubi) e mana (safira).
## Fica no canto superior esquerdo (estilo Ragnarok / Sun Haven), abaixo do nome do mapa.
## Lê Net.stats_changed (hp, max_hp, mp, max_mp, level) e o cache Net.client_stats.
## Criada pelo GameUI a cada reconstrução (escala da interface).

const NET_SIGNAL: StringName = &"stats_changed"
const NET_CACHE: StringName = &"client_stats"
const K_HP: StringName = &"hp"
const K_MAX_HP: StringName = &"max_hp"
const K_MP: StringName = &"mp"
const K_MAX_MP: StringName = &"max_mp"
const K_LEVEL: StringName = &"level"

## Posição e tamanho (px na escala 1,0 da interface).
const MARGIN_LEFT_PX: float = 16.0
const MARGIN_TOP_PX: float = 54.0
const BAR_WIDTH_PX: float = 164.0
const BAR_HEIGHT_PX: float = 15.0
const MEDALLION_SIZE_PX: float = 48.0
const GAP_PX: float = 7.0

const COLOR_HP: Color = Color8(222, 54, 64)
const COLOR_MP: Color = Color8(46, 124, 238)
const COLOR_BG: Color = UIKit.COLOR_FIELD
const COLOR_BORDER_MEDALLION: Color = Color8(218, 165, 32)
const COLOR_BORDER_BAR: Color = Color8(32, 22, 18)
const BORDER_PX: int = 1
const OUTLINE_PX: float = 2.0
const FILL_BORDER_DARKEN: float = 0.35
const LABEL_FORMAT: String = "%d / %d"

var net: Object = null
var ui_scale: float = 1.0
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var _hp_label: Label
var _mp_label: Label
var _level_label: Label
var _name_label: Label
var _portrait_rect: TextureRect
## Retrato com as camadas do próprio personagem (corpo, pele, cabelo, roupa): feminino fica feminino.
var _portrait_clip: Control
var _portrait_preview: LayeredCharacterPreview
var _portrait_key: String = ""
var _portrait_poll: float = 0.0
## Medidor do companheiro ativo (escondido sem companheiro).
var companion_bar: ProgressBar
var companion_label: Label
const COMPANION_COLOR: Color = Color8(96, 214, 236)
const COMPANION_BAR_HEIGHT_PX: float = 9.0


func _init(p_scale: float = 1.0, p_net: Object = null) -> void:
	ui_scale = p_scale
	net = p_net
	name = &"PlayerBars"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color8(38, 25, 19, 232)
	panel.border_color = Color8(190, 143, 61)
	panel.set_border_width_all(maxi(1, UIKit.px(2, ui_scale)))
	panel.set_corner_radius_all(maxi(2, UIKit.px(3, ui_scale)))
	panel.content_margin_left = UIKit.px(5, ui_scale)
	panel.content_margin_right = UIKit.px(7, ui_scale)
	panel.content_margin_top = UIKit.px(4, ui_scale)
	panel.content_margin_bottom = UIKit.px(4, ui_scale)
	panel.shadow_size = maxi(2, UIKit.px(4, ui_scale))
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.anti_aliasing = false
	add_theme_stylebox_override(&"panel", panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", UIKit.px(GAP_PX, ui_scale))
	add_child(row)

	var medallion: Control = _create_medallion()
	row.add_child(medallion)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", UIKit.px(2, ui_scale))
	row.add_child(col)

	_name_label = Label.new()
	_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name_label.text = "Aventureiro"
	_name_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_name_label.add_theme_color_override(&"font_color", Color8(255, 245, 215))
	_name_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_name_label.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(OUTLINE_PX, ui_scale)))
	col.add_child(_name_label)

	var hp: Array = _make_bar(COLOR_HP, BAR_HEIGHT_PX)
	hp_bar = hp[0]
	_hp_label = hp[1]
	col.add_child(hp_bar)

	var mp: Array = _make_bar(COLOR_MP, BAR_HEIGHT_PX - 2.0)
	mp_bar = mp[0]
	_mp_label = mp[1]
	col.add_child(mp_bar)

	# Medidor do companheiro de título (PETS-E-MONTARIAS §0.1): nível e XP do bicho ativo.
	companion_bar = _make_bar(COMPANION_COLOR, COMPANION_BAR_HEIGHT_PX)[0]
	companion_label = companion_bar.get_child(0) as Label
	companion_label.add_theme_font_size_override(&"font_size", maxi(8, UIKit.px(9, ui_scale)))
	companion_bar.name = &"CompanionMeter"
	companion_bar.visible = false
	col.add_child(companion_bar)

	# Valores iniciais agradáveis antes do primeiro pacote de rede
	set_stats({"hp": 100, "max_hp": 100, "mp": 50, "max_mp": 50, "level": 1})


func _ready() -> void:
	position = Vector2(UIKit.px(MARGIN_LEFT_PX, ui_scale), UIKit.px(MARGIN_TOP_PX, ui_scale))
	var target_net: Object = net if net != null else get_node_or_null(^"/root/Net")
	bind_net(target_net)
	var prog: Node = get_node_or_null(^"/root/NetProgress")
	if prog != null and prog.has_signal(&"progress_changed"):
		prog.connect(&"progress_changed", set_companion_progress)
		var cached: Variant = prog.get(&"client_progress")
		if cached is Dictionary:
			set_companion_progress(cached)


## Nível e XP do companheiro ativo ao lado do retrato (progress = Progression.snapshot()).
func set_companion_progress(progress: Dictionary) -> void:
	if companion_bar == null:
		return
	var state: Dictionary = progress.get("companions", {})
	var active: String = str(state.get("active", ""))
	var def: CompanionDef = Content.companion(StringName(active)) if not active.is_empty() else null
	companion_bar.visible = def != null
	if def == null:
		return
	var entry: Dictionary = (state.get("progress", {}) as Dictionary).get(active, {})
	var level: int = int(entry.get("level", 1))
	var next: int = int(entry.get("xp_next", 0))
	companion_bar.max_value = maxi(1, next)
	companion_bar.value = companion_bar.max_value if next <= 0 else int(entry.get("xp", 0))
	var nick: String = str((state.get("names", {}) as Dictionary).get(active, ""))
	companion_label.text = "%s · %s" % [nick if not nick.is_empty() else tr(def.name_key),
			tr("COMPANION_LEVEL_SHORT") % level]


func bind_net(p_net: Object) -> void:
	if net != null and net.has_signal(NET_SIGNAL) and net.is_connected(NET_SIGNAL, set_stats):
		net.disconnect(NET_SIGNAL, set_stats)
	net = p_net
	if net != null:
		if net.has_signal(NET_SIGNAL) and not net.is_connected(NET_SIGNAL, set_stats):
			net.connect(NET_SIGNAL, set_stats)
		if NET_CACHE in net:
			set_stats(net.get(NET_CACHE) as Dictionary)
	_update_name()


func set_stats(stats: Dictionary) -> void:
	if stats.is_empty():
		return
	_apply(hp_bar, _hp_label, int(stats.get(K_HP, 0)), int(stats.get(K_MAX_HP, 1)))
	_apply(mp_bar, _mp_label, int(stats.get(K_MP, 0)), int(stats.get(K_MAX_MP, 1)))
	if stats.has(K_LEVEL):
		_level_label.text = "Lv. %d" % int(stats[K_LEVEL])
	elif stats.has("level"):
		_level_label.text = "Lv. %d" % int(stats["level"])
	_update_name()


## Recorte da cabeça no quadro de 96 px das folhas (o mesmo do retrato antigo do Viajante).
const PORTRAIT_HEAD: Rect2 = Rect2(26, 12, 44, 44)
## Camadas que não entram no retrato (arma e escudo cruzariam o rosto).
const PORTRAIT_SKIP: Array[StringName] = [&"weapon", &"offhand", &"weapon_item"]
const PORTRAIT_POLL_SEC: float = 0.5


func _process(delta: float) -> void:
	_portrait_poll -= delta
	if _portrait_poll > 0.0:
		return
	_portrait_poll = PORTRAIT_POLL_SEC
	var nw: Node = get_node_or_null(^"/root/NetWorld")
	var p: Variant = nw.get(&"client_player") if nw != null else null
	if is_instance_valid(p) and p is Node:
		set_portrait_appearance((p as Node).get(&"appearance") as Dictionary)


## Troca o retrato para esta aparência (vazio = mantém). Público para testes e capturas.
func set_portrait_appearance(app: Dictionary) -> void:
	if app == null or app.is_empty() or _portrait_clip == null:
		return
	var clean: Dictionary = app.duplicate()
	for k: StringName in PORTRAIT_SKIP:
		clean.erase(k)
	var key: String = str(clean)
	if key == _portrait_key:
		return
	_portrait_key = key
	if _portrait_preview == null:
		_portrait_preview = LayeredCharacterPreview.new()
		_portrait_preview.name = &"Portrait"
		_portrait_preview.show_rotate_buttons = false
		_portrait_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait_clip.add_child(_portrait_preview)
		_portrait_preview.set_process.call_deferred(false) # parado de frente (depois do _ready, que liga o _process)
	_portrait_preview.set_appearance(clean)
	_portrait_preview.set_anim(&"idle")
	_portrait_preview.set_sector(0)
	_portrait_rect.visible = false
	_layout_portrait()


func portrait_body() -> StringName:
	if _portrait_preview == null:
		return &""
	return StringName(str(_portrait_preview.appearance.get(&"body", "")))


func _layout_portrait() -> void:
	if _portrait_preview == null or _portrait_clip == null:
		return
	var side: float = minf(_portrait_clip.size.x, _portrait_clip.size.y)
	if side <= 0.0:
		return
	var k: int = maxi(1, roundi(side / PORTRAIT_HEAD.size.x))
	_portrait_preview.fixed_scale = k
	var box: Vector2 = _portrait_preview.get_minimum_size_for_scale(k)
	_portrait_preview.size = box
	var head_center: Vector2 = (PORTRAIT_HEAD.position + PORTRAIT_HEAD.size * 0.5) * k
	_portrait_preview.position = (_portrait_clip.size * 0.5 - head_center).round()


static func _apply(bar: ProgressBar, label: Label, value: int, max_value: int) -> void:
	bar.max_value = maxi(1, max_value)
	bar.value = clampi(value, 0, maxi(1, max_value))
	label.text = LABEL_FORMAT % [value, max_value]


func _update_name() -> void:
	if _name_label == null or not is_inside_tree():
		return
	var nw: Node = get_node_or_null(^"/root/NetWorld")
	var p: Variant = nw.get(&"client_player") if nw != null else null
	if is_instance_valid(p) and p is Node:
		var n: String = str((p as Node).get(&"display_name"))
		if not n.is_empty():
			_name_label.text = n
			return
	if net != null and &"_client_name" in net:
		var n: String = str(net.get(&"_client_name"))
		if not n.is_empty():
			_name_label.text = n
			return


func _create_medallion() -> Control:
	var s: int = UIKit.px(MEDALLION_SIZE_PX, ui_scale)
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.custom_minimum_size = Vector2(s, s)

	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.COLOR_FIELD
	sb.border_color = COLOR_BORDER_MEDALLION
	sb.set_border_width_all(maxi(1, UIKit.px(2, ui_scale)))
	sb.set_corner_radius_all(maxi(2, UIKit.px(4, ui_scale)))
	sb.shadow_size = maxi(2, UIKit.px(4, ui_scale))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.anti_aliasing = false
	frame.add_theme_stylebox_override(&"panel", sb)

	_portrait_rect = TextureRect.new()
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var char_path: String = "res://assets/characters/chr_traveler_male_idle.png"
	if ResourceLoader.exists(char_path):
		var base_tex: Texture2D = load(char_path) as Texture2D
		if base_tex != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = base_tex
			atlas.region = Rect2(26, 12, 44, 44)
			_portrait_rect.texture = atlas

	frame.add_child(_portrait_rect)
	_portrait_clip = Control.new()
	_portrait_clip.name = &"PortraitClip"
	_portrait_clip.clip_contents = true
	_portrait_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_clip.resized.connect(_layout_portrait)
	frame.add_child(_portrait_clip)
	wrapper.add_child(frame)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color8(32, 20, 14, 245)
	bsb.border_color = Color8(238, 178, 72)
	bsb.set_border_width_all(maxi(1, UIKit.px(1, ui_scale)))
	bsb.set_corner_radius_all(0)
	bsb.anti_aliasing = false
	badge.add_theme_stylebox_override(&"panel", bsb)

	_level_label = Label.new()
	_level_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_level_label.text = "Lv. 1"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override(&"font_size", maxi(9, UIKit.px(10, ui_scale)))
	_level_label.add_theme_color_override(&"font_color", Color8(255, 230, 110))
	_level_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_level_label.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(1, ui_scale)))
	badge.add_child(_level_label)

	wrapper.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	badge.offset_top = -UIKit.px(14, ui_scale)
	badge.offset_bottom = UIKit.px(2, ui_scale)
	badge.offset_left = UIKit.px(4, ui_scale)
	badge.offset_right = -UIKit.px(4, ui_scale)

	return wrapper


func _make_bar(fill: Color, height_px: float) -> Array:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(UIKit.px(BAR_WIDTH_PX, ui_scale), UIKit.px(height_px, ui_scale))
	var border: int = maxi(1, UIKit.px(BORDER_PX, ui_scale))

	var bg := StyleBoxFlat.new()
	bg.bg_color = COLOR_BG
	bg.border_color = COLOR_BORDER_BAR
	bg.set_border_width_all(border)
	bg.set_corner_radius_all(maxi(1, UIKit.px(2, ui_scale)))
	bg.anti_aliasing = false
	bar.add_theme_stylebox_override(&"background", bg)

	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.border_color = fill.lightened(0.28)
	f.border_width_top = maxi(1, UIKit.px(1, ui_scale))
	f.border_width_bottom = border
	f.border_width_left = 0
	f.border_width_right = 0
	f.set_corner_radius_all(maxi(1, UIKit.px(2, ui_scale)))
	f.anti_aliasing = false
	bar.add_theme_stylebox_override(&"fill", f)

	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override(&"font_size", maxi(10, UIKit.px(11, ui_scale)))
	label.add_theme_color_override(&"font_color", Color8(255, 255, 255))
	label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	label.add_theme_constant_override(&"outline_size", maxi(1, UIKit.px(OUTLINE_PX, ui_scale)))
	bar.add_child(label)
	return [bar, label]
