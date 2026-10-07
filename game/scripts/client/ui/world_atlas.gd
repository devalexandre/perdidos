class_name WorldAtlas
extends Control
## Atlas do mundo em tela cheia (GDD §4.0.1, tecla M; M ou Esc fecha): o pergaminho ilustrado com
## todas as regiões, cidades, campos e masmorras (inclusive as "terras ainda não alcançadas").
## Arrastar/setas/WASD movem, roda/+/− dão zoom, 0 centraliza. Nomes desenhados pela engine (chaves
## WA_*, localization/world_atlas.csv) com contorno legível sobre o pergaminho; dica ao passar o
## mouse (ou tocar) com nome, tipo, região, níveis, estado e gancho. "Você está aqui" pelo gancho
## do Agente N (NetWorld.where_am_i) ou, sem ele, pelo map_id atual. M alterna do mapa local para cá;
## Esc fecha. Sem sons de UI.
## Dados: data/world/atlas.tres (gerados por docs/mundo/gerar_dados_atlas.py).

const ACTION_TOGGLE: StringName = &"ui_world_atlas"
const ANY_DEVICE: int = -1

# --- Visual (px na escala 1,0) --------------------------------------------------------------------
const MARGIN_PX: float = 14.0
const HEADER_PX: float = 46.0
const FOOTER_PX: float = 54.0
const FRAME_PX: float = 2.0
const ICON_PX: float = 20.0
## Quanto o ícone cresce com o zoom (zoom^x).
const ICON_ZOOM_GROWTH: float = 0.5
const LEGEND_ICON_PX: float = 18.0
const LEGEND_SPACING_PX: float = 12.0
const LABEL_GAP_PX: float = 1.0
const REGION_FONT_FACTOR: float = 1.0
const LABEL_OUTLINE_PX: float = 1.0
const REGION_OUTLINE_PX: float = 1.0
const TOOLTIP_OFFSET_PX: float = 16.0
const TOOLTIP_WIDTH_PX: float = 260.0
const HERE_BOB_PX: float = 3.0
const HERE_BOB_SPEED: float = 3.0
const HERE_RING_PX: float = 16.0
const BACKDROP: Color = Color("202c2b")
const PAPER: Color = Color("f1e5c8")
const BRASS: Color = Color("b9a373")
const SIDEBAR_PX: float = 218.0
## Tintas sobre o pergaminho (rampas da paleta mestra).
const INK: Color = UIKit.COLOR_INK
const INK_DIM: Color = Color8(107, 66, 38)
const INK_REGION: Color = UIKit.COLOR_INK_TITLE
const INK_SEA: Color = Color8(38, 72, 140)
const INK_OUTLINE: Color = Color8(250, 240, 214, 235)
const HERE_COLOR: Color = UIKit.COLOR_SLOT_SELECTED
const QUEST_COLOR: Color = Color8(244, 183, 39)
## Ícone esmaecido das terras ainda não alcançadas.
const UNREACHED_MODULATE: Color = Color(0.90, 0.87, 0.79, 0.95)

# --- Zoom e movimento -----------------------------------------------------------------------------
const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 4.0
const ZOOM_STEP: float = 1.25
## Movimento pelo teclado (fração da área visível por segundo).
const PAN_KEY_SPEED: float = 0.8
## Arrastar menos que isso (px) conta como clique.
const CLICK_SLOP_PX: float = 6.0
## Acima deste zoom aparecem os nomes dos lugares menores; acima do outro, os desenhos de monstros.
const ZOOM_MINOR_LABELS: float = 1.6
const ZOOM_DOODLE_LABELS: float = 2.4
## Acima desta ampliação (px da tela por texel) o mapa fica em vizinho mais próximo (pixel nítido).
const NEAREST_ABOVE: float = 1.5

const ICON_PATH: String = "res://assets/worldmap/icons/wm_icon_%s.png"
const KIND_ICON: Dictionary = {
	WorldPlaceDef.Kind.CAPITAL: "city", WorldPlaceDef.Kind.TOWN: "town", WorldPlaceDef.Kind.FIELD: "field",
	WorldPlaceDef.Kind.DUNGEON: "dungeon", WorldPlaceDef.Kind.MYSTERY: "mystery",
	WorldPlaceDef.Kind.BOSS: "boss", WorldPlaceDef.Kind.LANDMARK: "landmark",
	WorldPlaceDef.Kind.PORT: "port", WorldPlaceDef.Kind.PVP: "field", WorldPlaceDef.Kind.TRAINING: "field",
}
const HERE_ICON: String = "here"
const LEGEND: Array[Array] = [["city", "WA_LEG_CAPITAL"], ["town", "WA_LEG_TOWN"], ["field", "WA_LEG_FIELD"],
		["dungeon", "WA_LEG_DUNGEON"], ["mystery", "WA_LEG_MYSTERY"], ["boss", "WA_LEG_BOSS"],
		["port", "WA_LEG_PORT"], ["landmark", "WA_LEG_LANDMARK"], ["here", "WA_YOU_ARE_HERE"],
		["unreached", "WA_LEG_UNREACHED"]]

## Estado lembrado entre aberturas (e quando o GameUI se reconstrói ao mudar a escala).
static var keep_open: bool = false
static var saved_zoom: float = ZOOM_MIN
static var saved_center: Vector2 = Vector2(0.5, 0.5)

var atlas: WorldAtlasDef = null
var ui_scale: float = 1.0
## Testes: força o mapa atual (sem NetWorld).
var map_id_override: StringName = &""

var _view: Control
var _overlay: Control
var _tooltip: PanelContainer
var _tip_name: Label
var _tip_sub: Label
var _tip_levels: Label
var _tip_status: Label
var _tip_hook: Label
var _close_button: Button
var _icons: Dictionary = {}
var _zoom: float = ZOOM_MIN
var _center: Vector2 = Vector2(0.5, 0.5)
var _dragging: bool = false
var _drag_dist: float = 0.0
var _touch_index: int = -1
var _hover: WorldPlaceDef = null
var _pinned: WorldPlaceDef = null
var _hits: Array = []
var _here: WorldPlaceDef = null
var _time: float = 0.0
var _sidebar: PanelContainer
var _region_list: VBoxContainer
var _region_buttons: Array[Button] = []
var _here_button: Button
var _zoom_label: Label
var _toolbar: HBoxContainer
var _label_boxes: Array[Rect2] = []
var _legend_rows: int = 1
var _quest_maps: Array[StringName] = []



func _init() -> void:
	name = &"WorldAtlas"
	mouse_filter = Control.MOUSE_FILTER_STOP
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visible = false
	_view = Control.new()
	_view.name = &"MapView"
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_map)
	add_child(_view)
	_overlay = Control.new()
	_overlay.name = &"Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_overlay.draw.connect(_draw_overlay)
	_view.add_child(_overlay)
	_build_tooltip()
	_close_button = Button.new()
	_close_button.name = &"Close"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.pressed.connect(close)
	add_child(_close_button)
	_build_navigation()
	move_child(_tooltip, -1)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	register_action()
	if atlas == null and ResourceLoader.exists(WorldAtlasDef.DEFAULT_PATH):
		atlas = load(WorldAtlasDef.DEFAULT_PATH) as WorldAtlasDef
	for kind: String in ["city", "town", "field", "dungeon", "mystery", "boss", "landmark", "port", HERE_ICON]:
		var path: String = ICON_PATH % kind
		if ResourceLoader.exists(path):
			_icons[kind] = load(path)
	_build_region_index()
	_zoom = saved_zoom
	_center = saved_center
	get_viewport().size_changed.connect(_layout)
	var nw: Node = get_node_or_null(^"/root/NetWorld")
	if nw != null and nw.has_signal(&"zone_changed"):
		nw.connect(&"zone_changed", func(_m: StringName) -> void: _refresh_here())
	_layout()
	if keep_open:
		open()


## Registra a ação M, usada pelo GameUI para alternar mapa local/atlas global.
static func register_action() -> void:
	if not InputMap.has_action(ACTION_TOGGLE):
		InputMap.add_action(ACTION_TOGGLE)
	for existing: InputEvent in InputMap.action_get_events(ACTION_TOGGLE):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == KEY_M:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_M
	ev.device = ANY_DEVICE
	InputMap.action_add_event(ACTION_TOGGLE, ev)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_refresh_here()
	visible = true
	keep_open = true
	_pinned = null
	_hover = null
	_tooltip.visible = false
	_redraw()


func close() -> void:
	visible = false
	keep_open = false
	_tooltip.visible = false
	saved_zoom = _zoom
	saved_center = _center


## Lugar onde o jogador está (ou null).
func current_place() -> WorldPlaceDef:
	return _here


func set_quest_maps(map_ids: Array[StringName]) -> void:
	_quest_maps = map_ids.duplicate()
	_redraw()


# ---------------------------------------------------------------- "você está aqui"

func _refresh_here() -> void:
	_here = null
	if atlas == null:
		return
	var map_id: StringName = map_id_override
	if map_id == &"":
		var nw: Node = get_node_or_null(^"/root/NetWorld")
		if nw != null:
			if nw.has_method(&"where_am_i"):
				var w: Dictionary = nw.call(&"where_am_i")
				map_id = StringName(str(w.get(&"map_id", w.get("map_id", ""))))
			elif &"client_map_id" in nw:
				map_id = nw.get(&"client_map_id")
	_here = atlas.place_for_map(map_id)
	_here_button.disabled = _here == null
	_redraw()


# ---------------------------------------------------------------- layout

func _layout() -> void:
	if not is_inside_tree():
		return
	ui_scale = UIKit.scale_for(get_viewport_rect().size)
	theme = UIKit.build_theme(ui_scale)
	theme.default_font = _font()
	for button: Button in _region_buttons + [_close_button, _here_button]:
		_style_button(button)
	for child: Node in _toolbar.get_children():
		if child is Button:
			_style_button(child)
	_sidebar.add_theme_stylebox_override(&"panel", _panel(PAPER, BRASS, 12))
	_tooltip.add_theme_stylebox_override(&"panel", _panel(PAPER, BRASS, 12))
	var m: float = UIKit.px(MARGIN_PX, ui_scale)
	var header: float = UIKit.px(HEADER_PX, ui_scale)
	var footer: float = UIKit.px(FOOTER_PX, ui_scale)
	var s: Vector2 = get_viewport_rect().size
	var side: float = UIKit.px(SIDEBAR_PX, ui_scale)
	_sidebar.position = Vector2(m, m + header)
	_sidebar.size = Vector2(side, s.y - m * 2.0 - header - footer)
	_view.position = Vector2(m * 2.0 + side, m + header)
	_view.size = Vector2(s.x - m * 3.0 - side, s.y - m * 2.0 - header - footer)
	_toolbar.position = Vector2(_view.position.x + UIKit.px(10, ui_scale), m + UIKit.px(4, ui_scale))
	_toolbar.add_theme_constant_override(&"separation", UIKit.px(5, ui_scale))
	_zoom_label.add_theme_font_size_override(&"font_size", UIKit.px(13, ui_scale))
	for button: Button in _region_buttons:
		button.custom_minimum_size.y = UIKit.px(30, ui_scale)
		button.add_theme_font_size_override(&"font_size", UIKit.px(13, ui_scale))
	_here_button.custom_minimum_size.y = UIKit.px(34, ui_scale)
	for label: Node in _sidebar.find_children("*", "Label", true, false):
		(label as Label).add_theme_font_size_override(&"font_size", UIKit.px(12, ui_scale))
	_overlay.position = Vector2.ZERO
	_overlay.size = _view.size
	_close_button.text = "%s [M]" % tr("WA_CLOSE")
	_close_button.reset_size()
	_close_button.position = Vector2(s.x - m - _close_button.size.x,
			m + (header - _close_button.size.y) * 0.5).round()
	_tip_hook.custom_minimum_size.x = UIKit.px(TOOLTIP_WIDTH_PX, ui_scale)
	for l: Label in [_tip_name, _tip_sub, _tip_levels, _tip_status, _tip_hook]:
		l.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_tip_name.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE, ui_scale))
	_clamp_center()
	_redraw()


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.name = &"Tooltip"
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	add_child(_tooltip)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(box)
	_tip_name = _tip_label(box)
	_tip_sub = _tip_label(box)
	_tip_levels = _tip_label(box)
	_tip_status = _tip_label(box)
	_tip_hook = _tip_label(box)
	_tip_hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _tip_label(parent: Control) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	parent.add_child(l)
	return l


# ---------------------------------------------------------------- geometria

func _texture_size() -> Vector2:
	if atlas == null or atlas.map_texture == null:
		return Vector2(1920, 1080)
	return Vector2(atlas.map_texture.get_size())


func _fit_scale() -> float:
	var tex: Vector2 = _texture_size()
	return minf(_view.size.x / tex.x, _view.size.y / tex.y)


func _map_size() -> Vector2:
	return _texture_size() * _fit_scale() * _zoom


func _map_origin() -> Vector2:
	return (_view.size * 0.5 - _center * _map_size()).round()


## Posição normalizada (0..1) → px dentro da área do mapa.
func norm_to_view(p: Vector2) -> Vector2:
	return _map_origin() + p * _map_size()


func _clamp_center() -> void:
	var ms: Vector2 = _map_size()
	for axis: int in 2:
		if ms[axis] <= _view.size[axis] or ms[axis] <= 0.0:
			_center[axis] = 0.5
		else:
			var half: float = _view.size[axis] / (2.0 * ms[axis])
			_center[axis] = clampf(_center[axis], half, 1.0 - half)


func set_zoom(z: float, anchor_view: Vector2 = Vector2(-1, -1)) -> void:
	if anchor_view.x < 0.0:
		anchor_view = _view.size * 0.5
	var before: Vector2 = (anchor_view - _map_origin()) / _map_size()
	_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	var ms: Vector2 = _map_size()
	var origin: Vector2 = anchor_view - before * ms
	_center = (_view.size * 0.5 - origin) / ms
	_clamp_center()
	_redraw()


func get_zoom() -> float:
	return _zoom


func pan_by_view(delta_px: Vector2) -> void:
	_center -= delta_px / _map_size()
	_clamp_center()
	_redraw()


func reset_view() -> void:
	_zoom = ZOOM_MIN
	_center = Vector2(0.5, 0.5)
	_clamp_center()
	_redraw()


## Centraliza num lugar (com zoom mínimo dado).
func focus_place(p: WorldPlaceDef, z: float = 2.0) -> void:
	if p == null:
		return
	_zoom = clampf(maxf(_zoom, z), ZOOM_MIN, ZOOM_MAX)
	_center = p.pos
	_clamp_center()
	_redraw()


func _redraw() -> void:
	queue_redraw()
	_view.queue_redraw()
	_overlay.queue_redraw()
	if _zoom_label != null:
		_zoom_label.text = "%d%%" % roundi(_zoom * 100)


# ---------------------------------------------------------------- desenho

func _process(delta: float) -> void:
	if not visible:
		return
	# Textos com quebra de linha calculam o mínimo depois do primeiro layout.
	# Reaplica a altura disponível quando esse mínimo estabiliza.
	if not is_equal_approx(_sidebar.size.y, _view.size.y):
		_sidebar.size.y = _view.size.y
	_time += delta
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		pan_by_view(-dir * _view.size * PAN_KEY_SPEED * delta)
	if _here != null:
		_overlay.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	var f: Font = _font()
	var m: float = UIKit.px(MARGIN_PX, ui_scale)
	var header: float = UIKit.px(HEADER_PX, ui_scale)
	var fs_title: int = UIKit.px(UIKit.FONT_SIZE_TITLE, ui_scale)
	var fs: int = UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale)
	var outline: int = UIKit.px(UIKit.OUTLINE_SIZE, ui_scale)
	# Moldura da área do mapa.
	var frame: int = maxi(1, UIKit.px(FRAME_PX, ui_scale))
	var r := Rect2(_view.position, _view.size)
	draw_rect(r.grow(frame * 2), UIKit.COLOR_BORDER_DARK)
	draw_rect(r.grow(frame), UIKit.COLOR_BORDER)
	# Cabeçalho: título à esquerda, dica no meio.
	var base_y: float = m + (header + f.get_ascent(fs_title) - f.get_descent(fs_title)) * 0.5
	var title: String = tr("WA_TITLE")
	draw_string_outline(f, Vector2(m, base_y).round(), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title, outline,
			UIKit.COLOR_OUTLINE)
	draw_string(f, Vector2(m, base_y).round(), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title, UIKit.COLOR_TITLE)
	_draw_legend(f, fs)


func _draw_legend(f: Font, fs: int) -> void:
	var margin: float = UIKit.px(MARGIN_PX, ui_scale)
	var icon: float = UIKit.px(LEGEND_ICON_PX, ui_scale)
	var gap: float = UIKit.px(4, ui_scale)
	var spacing: float = UIKit.px(12, ui_scale)
	var line_height: float = UIKit.px(25, ui_scale)
	var x: float = margin
	var y: float = size.y - margin - UIKit.px(FOOTER_PX, ui_scale) + line_height * 0.5
	_legend_rows = 1
	for entry: Array in LEGEND:
		var label: String = tr(entry[1])
		var width: float = icon + gap + f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if x + width > size.x - margin:
			x = margin
			y += line_height
			_legend_rows += 1
		var key: String = entry[0]
		var tex: Texture2D = _icons.get("dungeon" if key == "unreached" else key)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x, y - icon * 0.5), Vector2.ONE * icon), false,
					UNREACHED_MODULATE if key == "unreached" else Color.WHITE)
		draw_string(f, Vector2(x + icon + gap, y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5).round(),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PAPER)
		x += width + spacing


func _draw_map() -> void:
	if atlas == null or atlas.map_texture == null:
		var f: Font = _font()
		_view.draw_string(f, Vector2(0, _view.size.y * 0.5), tr("WA_TITLE"), HORIZONTAL_ALIGNMENT_CENTER,
				_view.size.x, UIKit.px(UIKit.FONT_SIZE_TITLE, ui_scale), UIKit.COLOR_TEXT)
		return
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.draw_rect(Rect2(Vector2.ZERO, _view.size), UIKit.COLOR_PANEL)
	_view.draw_texture_rect(atlas.map_texture, Rect2(_map_origin(), _map_size()), false)


## Tamanho do ícone na tela para o zoom atual.
func _icon_size() -> float:
	return roundf(UIKit.px(ICON_PX, ui_scale) * pow(_zoom, ICON_ZOOM_GROWTH))


func _draw_overlay() -> void:
	_hits.clear()
	_label_boxes.clear()
	if atlas == null:
		return
	var f: Font = _font()
	var icon: float = _icon_size()
	var taken: Array[Rect2] = []
	var view_rect := Rect2(Vector2.ZERO, _view.size)
	# 1) Ícones (os não alcançados primeiro, para os abertos ficarem por cima).
	var places: Array[WorldPlaceDef] = atlas.all_places()
	var markers: Array[WorldPlaceDef] = []
	for p: WorldPlaceDef in places:
		if p.is_marker() and _marker_visible(p):
			markers.append(p)
	markers.sort_custom(func(a: WorldPlaceDef, b: WorldPlaceDef) -> bool: return a.status > b.status)
	for p: WorldPlaceDef in markers:
		var at: Vector2 = norm_to_view(p.pos).round()
		var rect := Rect2(at - Vector2(icon, icon) * 0.5, Vector2(icon, icon))
		if not view_rect.grow(icon).intersects(rect):
			continue
		var tex: Texture2D = _icons.get(KIND_ICON.get(p.kind, "landmark"))
		var mod: Color = UNREACHED_MODULATE if p.status == WorldPlaceDef.Status.UNREACHED else Color.WHITE
		_overlay.draw_circle(at, icon * 0.56, Color(PAPER, 0.94), true, -1.0, true)
		_overlay.draw_arc(at, icon * 0.56, 0, TAU, 32, BRASS, 1.0, true)
		if p == _hover or p == _pinned:
			_overlay.draw_arc(at, icon * 0.66, 0, TAU, 32, INK_REGION, 2.0, true)
		if tex != null:
			_overlay.draw_texture_rect(tex, rect, false, mod)
		else:
			_overlay.draw_circle(at, icon * 0.3, INK)
		_hits.append([rect, p])
		if _place_has_quest(p):
			var pulse: float = 0.75 + 0.25 * sin(_time * HERE_BOB_SPEED)
			_overlay.draw_arc(at, icon * 0.76, 0, TAU, 32, Color(QUEST_COLOR, pulse),
					maxf(2.0, UIKit.px(2, ui_scale)))
			var badge_at := at + Vector2(icon * 0.48, -icon * 0.48)
			_overlay.draw_circle(badge_at, icon * 0.22, QUEST_COLOR)
			_overlay.draw_circle(badge_at, icon * 0.08, Color.WHITE)
	# 2) "Você está aqui": anel pulsando e a pétala dourada balançando por cima.
	if _here != null:
		var at: Vector2 = norm_to_view(_here.pos).round()
		var pulse: float = 0.5 + 0.5 * sin(_time * HERE_BOB_SPEED)
		var ring: float = UIKit.px(HERE_RING_PX, ui_scale) * pow(_zoom, ICON_ZOOM_GROWTH) * (1.0 + 0.15 * pulse)
		_overlay.draw_arc(at, ring, 0.0, TAU, 40, Color(HERE_COLOR, 0.6 + 0.4 * pulse),
				maxf(2.0, UIKit.px(2, ui_scale)))
		var here_tex: Texture2D = _icons.get(HERE_ICON)
		var hs: float = icon * 1.1
		var bob: float = UIKit.px(HERE_BOB_PX, ui_scale) * sin(_time * HERE_BOB_SPEED)
		var hr := Rect2(Vector2(at.x - hs * 0.5, at.y - icon * 0.5 - hs + bob), Vector2(hs, hs)).abs()
		if here_tex != null:
			_overlay.draw_texture_rect(here_tex, hr, false)
		taken.append(hr)
		_hits.append([hr, _here])
	# 3) Rótulos, por prioridade, sem sobrepor (regiões > capitais/abertos > mares > resto).
	for r: WorldRegionDef in atlas.regions:
		var fsr: int = UIKit.px(15, ui_scale)
		_region_label(f, tr(r.name_key), norm_to_view(r.label_pos), fsr, taken)
	var fs: int = UIKit.px(13, ui_scale)
	var ordered: Array[WorldPlaceDef] = places.duplicate()
	ordered.sort_custom(func(a: WorldPlaceDef, b: WorldPlaceDef) -> bool:
		return _label_priority(a) < _label_priority(b))
	for p: WorldPlaceDef in ordered:
		if not _label_visible(p):
			continue
		var at: Vector2 = norm_to_view(p.pos).round()
		var text: String = tr(p.name_key)
		var col: Color = INK
		var size_px: int = fs
		match p.kind:
			WorldPlaceDef.Kind.SEA:
				col = INK_SEA
				size_px = roundi(fs * 1.15)
			WorldPlaceDef.Kind.FRONTIER, WorldPlaceDef.Kind.DOODLE, WorldPlaceDef.Kind.ISLAND:
				col = INK_DIM
			_:
				if p.status == WorldPlaceDef.Status.UNREACHED:
					col = INK_DIM
		if p == _here:
			col = UIKit.COLOR_INK_TITLE
		var outline: int = UIKit.px(LABEL_OUTLINE_PX, ui_scale)
		if p.is_marker():
			var below: Vector2 = at + Vector2(0, icon * 0.5 + UIKit.px(LABEL_GAP_PX, ui_scale) + f.get_ascent(size_px))
			if not _label(f, text, below, size_px, col, outline, taken, false):
				var above: Vector2 = at - Vector2(0, icon * 0.5 + UIKit.px(LABEL_GAP_PX, ui_scale) + f.get_descent(size_px))
				_label(f, text, above, size_px, col, outline, taken, false)
		else:
			var rect: Rect2 = _label_rect(f, text, at + Vector2(0, f.get_ascent(size_px) * 0.5), size_px)
			if _label(f, text, at + Vector2(0, f.get_ascent(size_px) * 0.5), size_px, col, outline, taken, false):
				_hits.append([rect, p])


func _place_has_quest(place: WorldPlaceDef) -> bool:
	if place.map_id in _quest_maps:
		return true
	for map_id: StringName in place.map_ids:
		if map_id in _quest_maps:
			return true
	return false


func _label_priority(p: WorldPlaceDef) -> int:
	if p == _here:
		return 0
	if p.kind == WorldPlaceDef.Kind.CAPITAL or p.status != WorldPlaceDef.Status.UNREACHED:
		return 1
	if p.kind == WorldPlaceDef.Kind.SEA or p.kind == WorldPlaceDef.Kind.FRONTIER:
		return 2
	if p.kind == WorldPlaceDef.Kind.MYSTERY or p.kind == WorldPlaceDef.Kind.BOSS:
		return 3
	if p.kind == WorldPlaceDef.Kind.DOODLE:
		return 5
	return 4


func _marker_visible(p: WorldPlaceDef) -> bool:
	return p == _here or p == _hover or p == _pinned or p.kind == WorldPlaceDef.Kind.CAPITAL \
			or p.status == WorldPlaceDef.Status.OPEN or _zoom >= ZOOM_MINOR_LABELS


func _label_visible(p: WorldPlaceDef) -> bool:
	if p == _hover or p == _pinned or p == _here:
		return true
	if _zoom < 1.5:
		return p.kind == WorldPlaceDef.Kind.SEA
	if p.kind == WorldPlaceDef.Kind.DOODLE:
		return _zoom >= ZOOM_DOODLE_LABELS
	return _marker_visible(p) or not p.is_marker()


func _label_rect(f: Font, text: String, baseline_center: Vector2, fs: int) -> Rect2:
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return Rect2(Vector2(baseline_center.x - w * 0.5, baseline_center.y - f.get_ascent(fs)),
			Vector2(w, f.get_height(fs)))


## Desenha um rótulo centrado (com contorno claro de pergaminho). Não desenha se sobrepõe outro,
## a não ser que force = true. Devolve true se desenhou.
func _label(f: Font, text: String, baseline_center: Vector2, fs: int, color: Color, _outline: int,
		taken: Array[Rect2], _force: bool) -> bool:
	var rect: Rect2 = _label_rect(f, text, baseline_center, fs)
	var padded: Rect2 = rect.grow(UIKit.px(4, ui_scale))
	var bounds := Rect2(Vector2.ZERO, _view.size).grow(-UIKit.px(5, ui_scale))
	if not bounds.encloses(padded):
		return false
	for other: Rect2 in taken:
		if other.intersects(padded):
			return false
	taken.append(padded)
	_label_boxes.append(padded)
	_overlay.draw_style_box(_panel(Color(PAPER, 0.96), Color(BRASS, 0.75), 0), padded)
	var pos: Vector2 = Vector2(rect.position.x, baseline_center.y).round()
	_overlay.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	return true


func _region_label(f: Font, text: String, at: Vector2, fs: int, taken: Array[Rect2]) -> void:
	# Duas linhas quando necessário: o nome nunca invade a região vizinha.
	var lines: Array[String] = [text]
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > UIKit.px(160, ui_scale):
		var words := text.split(" ")
		var split_at: int = int(ceil(words.size() * 0.5))
		lines = [" ".join(words.slice(0, split_at)), " ".join(words.slice(split_at))]
	var width: float = 0.0
	for line: String in lines:
		width = maxf(width, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var pad: float = UIKit.px(7, ui_scale)
	var height: float = f.get_height(fs)
	var box_size := Vector2(width + pad * 2, height * lines.size() + pad * 1.5)
	var bounds := Rect2(Vector2.ZERO, _view.size).grow(-5)
	for shift: float in [0.0, -1.0, 1.0, -2.0, 2.0]:
		var box := Rect2(at - box_size * 0.5 + Vector2(0, shift * box_size.y), box_size)
		if not bounds.encloses(box):
			continue
		var collides: bool = false
		for other: Rect2 in taken:
			if other.intersects(box.grow(2)):
				collides = true
		if collides:
			continue
		taken.append(box.grow(2))
		_label_boxes.append(box)
		_overlay.draw_style_box(_panel(Color(PAPER, 0.96), BRASS, 0), box)
		for i: int in lines.size():
			var w: float = f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_overlay.draw_string(f, Vector2(box.get_center().x - w * 0.5,
					box.position.y + pad * 0.75 + f.get_ascent(fs) + i * height).round(),
					lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK_REGION)
		return



# ---------------------------------------------------------------- dica

func _place_at(view_pos: Vector2) -> WorldPlaceDef:
	for i: int in range(_hits.size() - 1, -1, -1):
		if (_hits[i][0] as Rect2).has_point(view_pos):
			return _hits[i][1]
	return null


func _show_tooltip(p: WorldPlaceDef, screen_pos: Vector2) -> void:
	if p == null:
		_tooltip.visible = false
		return
	_tip_name.text = tr(p.name_key)
	_tip_name.add_theme_color_override(&"font_color", INK_REGION)
	var kind_text: String = tr("WA_KIND_%s" % WorldPlaceDef.Kind.keys()[p.kind])
	var region: WorldRegionDef = atlas.region(p.region_id) if atlas != null else null
	_tip_sub.text = kind_text if region == null \
			else "%s · %s" % [kind_text, tr("WA_REGION_OF") % tr(region.name_key)]
	_tip_sub.add_theme_color_override(&"font_color", INK_DIM)
	_tip_levels.visible = p.has_levels() or p.kind == WorldPlaceDef.Kind.PVP
	if p.kind == WorldPlaceDef.Kind.PVP and not p.has_levels():
		_tip_levels.text = tr("WA_LEVELS_ANY")
	elif p.level_min == p.level_max:
		_tip_levels.text = tr("WA_LEVEL_ONE") % p.level_max
	else:
		_tip_levels.text = tr("WA_LEVELS") % [p.level_min, p.level_max]
	_tip_levels.add_theme_color_override(&"font_color", INK)
	_tip_status.visible = p.is_marker() or p.kind == WorldPlaceDef.Kind.FRONTIER
	var status_key: String = ["WA_STATUS_OPEN", "WA_STATUS_SOON", "WA_STATUS_UNREACHED"][p.status]
	_tip_status.text = tr(status_key)
	if p == _here:
		_tip_status.text += " · " + tr("WA_YOU_ARE_HERE")
	_tip_status.add_theme_color_override(&"font_color", _status_color(p.status))
	_tip_hook.text = tr(p.hook_key) if not p.hook_key.is_empty() else ""
	_tip_hook.visible = not _tip_hook.text.is_empty()
	_tip_hook.add_theme_color_override(&"font_color", INK)
	_tooltip.visible = true
	_tooltip.reset_size()
	var off: float = UIKit.px(TOOLTIP_OFFSET_PX, ui_scale)
	var pos: Vector2 = screen_pos + Vector2(off, off)
	var s: Vector2 = get_viewport_rect().size
	if pos.x + _tooltip.size.x > s.x:
		pos.x = screen_pos.x - off - _tooltip.size.x
	if pos.y + _tooltip.size.y > s.y:
		pos.y = screen_pos.y - off - _tooltip.size.y
	_tooltip.position = pos.clamp(Vector2.ZERO, (s - _tooltip.size).max(Vector2.ZERO)).round()


func _status_color(status: WorldPlaceDef.Status) -> Color:
	var light: bool = true
	match status:
		WorldPlaceDef.Status.OPEN:
			return UIKit.RARITY_COLORS_INK[1] if light else UIKit.COLOR_NAME_LOCAL
		WorldPlaceDef.Status.SOON:
			return UIKit.c_stars()
	return INK_DIM


## Testes/toque: mostra a dica de um lugar como se o mouse estivesse sobre ele.
func hover_place(p: WorldPlaceDef) -> void:
	_hover = p
	_redraw()
	_show_tooltip(p, _view.position + norm_to_view(p.pos) if p != null else Vector2.ZERO)


# ---------------------------------------------------------------- entrada

func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			if not _view.get_global_rect().has_point(touch.position):
				close()
				accept_event()
				return
			_touch_index = touch.index
			_dragging = true
			_drag_dist = 0.0
		else:
			if _dragging and touch.index == _touch_index \
					and _drag_dist < UIKit.px(CLICK_SLOP_PX, ui_scale):
				_pinned = _place_at(touch.position - _view.position)
				if _pinned != null:
					_show_tooltip(_pinned, touch.position)
					_redraw()
			_dragging = false
			_touch_index = -1
		accept_event()
		return
	var screen_drag := event as InputEventScreenDrag
	if screen_drag != null and _dragging and screen_drag.index == _touch_index:
		_drag_dist += screen_drag.relative.length()
		if _drag_dist >= UIKit.px(CLICK_SLOP_PX, ui_scale):
			pan_by_view(screen_drag.relative)
			_pinned = null
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		var local: Vector2 = mb.position - _view.position
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					set_zoom(_zoom * ZOOM_STEP, local)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					set_zoom(_zoom / ZOOM_STEP, local)
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_dragging = true
					_drag_dist = 0.0
				else:
					if _dragging and _drag_dist < UIKit.px(CLICK_SLOP_PX, ui_scale):
						_pinned = _place_at(local)
						_show_tooltip(_pinned, mb.position)
						_redraw()
					_dragging = false
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					close()
		accept_event()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		if _dragging and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag_dist += mm.relative.length()
			if _drag_dist >= UIKit.px(CLICK_SLOP_PX, ui_scale):
				pan_by_view(mm.relative)
				_pinned = null
		var p: WorldPlaceDef = _place_at(mm.position - _view.position)
		if p != _hover:
			_hover = p
			_overlay.queue_redraw()
		if _pinned == null:
			_show_tooltip(_hover, mm.position)
		accept_event()
		return
	var mg: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if mg != null:
		set_zoom(_zoom * mg.factor, mg.position - _view.position)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	if event.is_action_pressed(ACTION_TOGGLE, false, true) or key.physical_keycode == KEY_ESCAPE:
		close()
	elif key.physical_keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		set_zoom(_zoom * ZOOM_STEP)
	elif key.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		set_zoom(_zoom / ZOOM_STEP)
	elif key.physical_keycode in [KEY_0, KEY_KP_0]:
		reset_view()
	# Com o atlas aberto, nenhuma tecla passa para o jogo (as setas/WASD são lidas no _process).
	get_viewport().set_input_as_handled()


static func _font() -> Font:
	return UIKit.world_font()


func _panel(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(UIKit.px(3, ui_scale))
	style.content_margin_left = UIKit.px(padding, ui_scale)
	style.content_margin_right = UIKit.px(padding, ui_scale)
	style.content_margin_top = UIKit.px(padding * 0.6, ui_scale)
	style.content_margin_bottom = UIKit.px(padding * 0.6, ui_scale)
	return style


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override(&"normal", _panel(Color("e6d9b9"), BRASS, 9))
	button.add_theme_stylebox_override(&"hover", _panel(Color("fff2cf"), INK_REGION, 9))
	button.add_theme_stylebox_override(&"pressed", _panel(Color("cfbc93"), INK_REGION, 9))
	button.add_theme_stylebox_override(&"focus", _panel(Color(0, 0, 0, 0), INK_REGION, 9))
	button.add_theme_color_override(&"font_color", INK)
	button.add_theme_color_override(&"font_hover_color", INK_REGION)
	button.add_theme_color_override(&"font_pressed_color", INK)
	button.add_theme_color_override(&"font_focus_color", INK)
	button.add_theme_color_override(&"font_outline_color", Color.TRANSPARENT)
	button.add_theme_font_override(&"font", _font())
	button.add_theme_font_size_override(&"font_size", UIKit.px(13, ui_scale))


func _build_navigation() -> void:
	_sidebar = PanelContainer.new()
	_sidebar.name = &"RegionIndex"
	add_child(_sidebar)
	var column := VBoxContainer.new()
	_sidebar.add_child(column)
	var title := Label.new()
	title.text = tr("WA_EXPLORE")
	title.add_theme_color_override(&"font_color", INK_REGION)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = tr("WA_WORLD_NAME")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override(&"font_color", INK_DIM)
	column.add_child(subtitle)
	_here_button = Button.new()
	_here_button.text = tr("WA_YOU_ARE_HERE")
	_here_button.pressed.connect(func() -> void:
		focus_place(_here, 2.0)
		hover_place(_here))
	column.add_child(_here_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_region_list = VBoxContainer.new()
	_region_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_region_list)
	var hint := Label.new()
	hint.text = tr("WA_INDEX_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override(&"font_color", INK_DIM)
	column.add_child(hint)
	_toolbar = HBoxContainer.new()
	_toolbar.name = &"MapControls"
	add_child(_toolbar)
	for spec: Array in [["−", "WA_ZOOM_OUT"], ["+", "WA_ZOOM_IN"], ["↺", "WA_OVERVIEW"]]:
		var button := Button.new()
		button.text = spec[0]
		button.tooltip_text = tr(spec[1])
		button.custom_minimum_size = Vector2(34, 30)
		var action: String = spec[1]
		if action == "WA_ZOOM_OUT":
			button.pressed.connect(func() -> void: set_zoom(_zoom / ZOOM_STEP))
		elif action == "WA_ZOOM_IN":
			button.pressed.connect(func() -> void: set_zoom(_zoom * ZOOM_STEP))
		else:
			button.pressed.connect(reset_view)
		_toolbar.add_child(button)
	_zoom_label = Label.new()
	_zoom_label.text = "100%"
	_zoom_label.add_theme_color_override(&"font_color", PAPER)
	_toolbar.add_child(_zoom_label)


func _build_region_index() -> void:
	if atlas == null:
		return
	for region: WorldRegionDef in atlas.regions:
		var button := Button.new()
		button.text = tr(region.name_key)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = tr(region.name_key)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_zoom = 2.2
			_center = region.label_pos
			_hover = null
			_pinned = null
			_tooltip.hide()
			_clamp_center()
			_redraw())
		_region_list.add_child(button)
		_region_buttons.append(button)
