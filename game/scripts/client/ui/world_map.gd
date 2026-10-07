class_name WorldMap
extends Control
## Mapa grande da área atual em tela cheia (GDD §9.4; M abre o atlas global, Shift+M/Esc fecha): o mapa inteiro
## com norte para cima, ampliação inteira (ou 1/n) que cabe na tela, ícones, seta do jogador e
## legenda. Usa os mesmos dados do Minimap (MinimapData). Sem sons de UI.

## Fração da tela ocupada pelo mapa (o resto é margem, título e legenda).
const SCREEN_FRACTION: float = 0.8
const BACKDROP: Color = Color(UIKit.COLOR_BORDER_DARK, 0.85)
const TITLE_GAP_PX: float = 8.0
const LEGEND_GAP_PX: float = 8.0
const LEGEND_SPACING_PX: float = 18.0
const LEGEND: Array[Array] = [[MinimapData.Icon.MASTER, "WORLD_MAP_LEGEND_MASTER"],
		[MinimapData.Icon.SHOP, "WORLD_MAP_LEGEND_SHOP"], [MinimapData.Icon.PORTAL, "WORLD_MAP_LEGEND_PORTAL"],
		[MinimapData.Icon.QUEST, "WORLD_MAP_LEGEND_QUEST"]]
const HINT_KEY: String = "WORLD_MAP_HINT"
const NO_MAP_KEY: String = "WORLD_MAP_UNAVAILABLE"

var minimap: Minimap = null


func _init() -> void:
	name = &"WorldMap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## Ampliação nítida que faz a textura caber em SCREEN_FRACTION da tela.
func fit_pixel_scale(d: MinimapData) -> float:
	var room: Vector2 = size * SCREEN_FRACTION
	var tex: Vector2 = Vector2(d.texture.get_size())
	var ideal: float = minf(room.x / tex.x, room.y / tex.y)
	if ideal >= 1.0:
		return floorf(ideal)
	return 1.0 / ceilf(1.0 / ideal)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	var ui_scale: float = minimap.ui_scale if minimap != null else 1.0
	var f: Font = UIKit.read_font()
	var fs_title: int = UIKit.px(UIKit.FONT_SIZE_TITLE, ui_scale)
	var fs: int = UIKit.px(UIKit.FONT_SIZE, ui_scale)
	var d: MinimapData = minimap.data if minimap != null else null
	if d == null or d.texture == null:
		_centered_text(f, tr(NO_MAP_KEY), size.y * 0.5, fs_title, UIKit.COLOR_TEXT)
		return
	var s: float = fit_pixel_scale(d)
	var map_size: Vector2 = Vector2(d.texture.get_size()) * s
	var origin: Vector2 = ((size - map_size) * 0.5).round()
	var border: int = UIKit.px(UIKit.BORDER, ui_scale)
	draw_rect(Rect2(origin, map_size).grow(border * 2), UIKit.COLOR_BORDER_DARK)
	draw_rect(Rect2(origin, map_size).grow(border), UIKit.COLOR_BORDER)
	draw_texture_rect(d.texture, Rect2(origin, map_size), false)
	var zone_key: String = d.zone.name_key if d.zone != null and not d.zone.name_key.is_empty() \
			else Minimap.ZONE_NAME_FALLBACK_PREFIX + String(d.map_id).to_upper()
	_centered_text(f, tr(zone_key), origin.y - UIKit.px(TITLE_GAP_PX, ui_scale) - border * 2, fs_title,
			UIKit.COLOR_TITLE)
	var icon_px: float = UIKit.px(Minimap.ICON_PX, ui_scale)
	for icon: Dictionary in d.icons:
		Minimap.draw_icon(self, icon[&"icon"], (origin + d.world_to_texel(icon[&"pos"]) * s).round(),
				icon_px, ui_scale)
	var p: Node3D = minimap.get_player()
	if p != null:
		var at: Vector2 = origin + d.world_to_texel(Vector2(p.global_position.x, p.global_position.z)) * s
		Minimap.draw_arrow(self, at.round(), -float(p.get(&"facing_yaw")),
				UIKit.px(Minimap.ARROW_PX, ui_scale), ui_scale)
	# Legenda e dica embaixo do mapa.
	var y: float = origin.y + map_size.y + border * 2 + UIKit.px(LEGEND_GAP_PX, ui_scale) + f.get_ascent(fs)
	var x: float = origin.x
	for entry: Array in LEGEND:
		Minimap.draw_icon(self, entry[0], Vector2(x + icon_px * 0.5, y - f.get_ascent(fs) * 0.35).round(),
				icon_px, ui_scale)
		var label: String = tr(entry[1])
		draw_string(f, Vector2(x + icon_px + UIKit.px(UIKit.SEPARATION, ui_scale), y), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.COLOR_TEXT)
		x += icon_px + f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x \
				+ UIKit.px(LEGEND_SPACING_PX, ui_scale)
	var hint: String = tr(HINT_KEY)
	draw_string(f, Vector2(origin.x + map_size.x - f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, y),
			hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.COLOR_TEXT_DIM)


func _centered_text(f: Font, text: String, baseline: float, fs: int, color: Color) -> void:
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(roundf((size.x - w) * 0.5), roundf(baseline)), text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, fs, color)


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		visible = false
		accept_event()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		visible = false
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()
