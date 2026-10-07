class_name Minimap
extends Control
## Minimapa no canto superior direito (GDD §9.4), estilo MMO clássico: imagem do mapa vista de cima
## (MinimapData: arte de W ou imagem gerada da WalkGrid), seta do jogador com a direção, ícones de
## Mestres, loja e portais, 2 níveis de zoom (botões + e − desenhados, roda do mouse sobre ele),
## "norte fixo" ou "gira com a câmera" (GameSettings.minimap_rotate) e mapa grande em tela cheia
## (Shift+M ou clique no minimapa, WorldMap; M alterna área → atlas global → fechar). Ampliação sempre inteira (ou 1/n) sobre os pixels da textura: nítido.
## Sem sons de UI. Criado pelo ClientView (Hud), antes do GameUI.
## Futuro (GDD §9.4/§12.2): membros do grupo e a Marca da Alma com tempo restante.

## Mapa grande da área atual. Shift+M abre/fecha direto; M alterna com o atlas global (Agente G).
const ACTION_WORLD_MAP: StringName = &"ui_area_map"
const ANY_DEVICE: int = -1
## Tamanho do quadro do mapa (px na escala 1,0) e margem até a borda da tela.
const VIEW_SIZE_PX: float = 144.0
const MARGIN_PX: float = 8.0
const FRAME_PX: float = 3.0
## Altura da faixa do nome da área e da linha de zoom.
const HEADER_PX: float = 22.0
const FOOTER_PX: float = 16.0
## Largura do mundo (unidades) mostrada em cada nível de zoom (perto, longe).
const ZOOM_SPANS: Array[float] = [36.0, 72.0]
## Ícones e seta (px na escala 1,0).
const ICON_PX: float = 7.0
const ARROW_PX: float = 11.0
const OUTLINE_PX: float = 1.0
const COLOR_MASTER: Color = UIKit.COLOR_TITLE
const COLOR_SHOP: Color = UIKit.COLOR_NAME_LOCAL
const COLOR_PORTAL: Color = Color8(178, 132, 232)
const COLOR_QUEST: Color = Color8(255, 211, 72)
const COLOR_ARROW: Color = UIKit.COLOR_NAME_PLAYER
const COLOR_ICON_OUTLINE: Color = UIKit.COLOR_OUTLINE
const COLOR_OUTSIDE: Color = UIKit.COLOR_FIELD
## Um ciclo de verificação da grade/mapa (s) enquanto os dados não estão prontos.
const RETRY_SEC: float = 0.5
const MAP_NODE_NAME: String = "Map"
const ZONE_NAME_FALLBACK_PREFIX: String = "MAP_"

## Nível de zoom atual (índice de ZOOM_SPANS); guardado entre trocas de mapa.
static var zoom_level: int = 0

## ClientView (câmera: camera_yaw; nome do mapa: set_map_name). Pode ser null nos testes.
var view: Node = null
var ui_scale: float = 1.0
var data: MinimapData = null
var world_map: WorldMap = null

var _player: Node3D = null
var _map_node: Node = null
var _retry_left: float = 0.0
var _map_view: Control
var _zoom_in_rect: Rect2 = Rect2()
var _zoom_out_rect: Rect2 = Rect2()
var _label: Label
var _quest_progress: Dictionary = {}


func _init() -> void:
	name = &"Minimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_map_view = Control.new()
	_map_view.name = &"MapView"
	_map_view.clip_contents = true
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_view.draw.connect(_draw_map_view)
	add_child(_map_view)
	_label = Label.new()
	_label.name = &"ZoneName"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_label)


func _ready() -> void:
	_register_actions()
	get_viewport().size_changed.connect(_layout)
	Net.local_player_spawned.connect(set_player)
	NetWorld.zone_changed.connect(func(_m: StringName) -> void: _reset_map())
	world_map = WorldMap.new()
	world_map.minimap = self
	world_map.visible = false
	# Irmão do minimapa no Hud (tela cheia, por cima do jogo).
	get_parent().add_child.call_deferred(world_map)
	_layout()


## Jogador local a seguir (a cada troca de instância chega um novo).
func set_player(player: Node3D) -> void:
	_player = player
	_reset_map()


func get_player() -> Node3D:
	return _player if is_instance_valid(_player) and _player.is_inside_tree() else null


## Rotação do mapa (rad): 0 = norte fixo; gira com a câmera se a opção estiver ligada.
func map_rotation() -> float:
	if not GameSettings.get_instance().minimap_rotate or view == null:
		return 0.0
	return float(view.get(&"camera_yaw"))


func set_zoom_level(level: int) -> void:
	zoom_level = clampi(level, 0, ZOOM_SPANS.size() - 1)
	queue_redraw()


## Ampliação (pixels de tela por pixel de textura) do nível de zoom: inteira, ou 1/n se a textura
## for mais densa que a tela.
func pixel_scale() -> float:
	return fit_scale(data, UIKit.px(VIEW_SIZE_PX, ui_scale) / ZOOM_SPANS[zoom_level])


## Escala nítida mais próxima de "px_per_unit" pixels de tela por unidade do mundo.
static func fit_scale(d: MinimapData, px_per_unit: float) -> float:
	var ideal: float = px_per_unit / d.texels_per_unit() if d != null else 1.0
	if ideal >= 1.0:
		return float(maxi(1, roundi(ideal)))
	return 1.0 / float(maxi(1, roundi(1.0 / ideal)))


func _reset_map() -> void:
	data = null
	_map_node = null
	_retry_left = 0.0


func _process(delta: float) -> void:
	if data == null or (data.texture == null and get_player() != null):
		_retry_left -= delta
		if _retry_left <= 0.0:
			_retry_left = RETRY_SEC
			_try_build()
	_map_view.queue_redraw()
	queue_redraw()


func _try_build() -> void:
	var p: Node3D = get_player()
	if p == null or not p.is_inside_tree() or p.get_parent() == null:
		return
	var inst: Node = p.get_parent().get_parent()
	_map_node = inst.get_node_or_null(MAP_NODE_NAME) if inst != null else null
	if _map_node == null:
		return
	var map_id: StringName = StringName(str(_map_node.get(&"map_id")))
	var grid: WalkGrid = null
	if view != null and view.has_method(&"get_walk_grid"):
		grid = view.call(&"get_walk_grid") as WalkGrid
	data = MinimapData.build(map_id, _map_node, grid)
	_collect_quest_icons(map_id)
	var key: String = data.zone.name_key if data.zone != null and not data.zone.name_key.is_empty() \
			else ZONE_NAME_FALLBACK_PREFIX + String(map_id).to_upper()
	_label.text = tr(key)
	if view != null and view.has_method(&"set_map_name"):
		view.call(&"set_map_name", key)
	if data.texture != null:
		Net.log_line("minimap_ready", {"map": String(map_id), "from_grid": data.from_grid,
				"size": str(data.texture.get_size()), "rect": str(data.world_rect),
				"icons": data.icons.size()})


# ---------------------------------------------------------------- layout e desenho

func _layout() -> void:
	ui_scale = UIKit.scale_for(get_viewport_rect().size)
	var view_px: int = UIKit.px(VIEW_SIZE_PX, ui_scale)
	var frame: int = UIKit.px(FRAME_PX, ui_scale)
	var footer: int = UIKit.px(FOOTER_PX, ui_scale)
	var margin: int = UIKit.px(MARGIN_PX, ui_scale)
	var header: int = UIKit.px(HEADER_PX, ui_scale)
	var total := Vector2(view_px + frame * 2, view_px + frame * 2 + footer + header)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(get_viewport_rect().size.x - total.x - margin, margin)
	size = total
	_map_view.position = Vector2(frame, frame + header)
	_map_view.size = Vector2(view_px, view_px)
	var btn: float = footer
	_zoom_in_rect = Rect2(total.x - btn * 2.0, view_px + frame * 2 + header, btn, btn)
	_zoom_out_rect = Rect2(total.x - btn, view_px + frame * 2 + header, btn, btn)
	_label.position = Vector2(0, 0)
	_label.size = Vector2(total.x, header)
	_label.add_theme_font_override(&"font", UIKit.read_font())
	_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, ui_scale))
	_label.add_theme_color_override(&"font_color", UIKit.COLOR_TEXT)
	_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_label.add_theme_constant_override(&"outline_size", UIKit.px(UIKit.OUTLINE_SIZE, ui_scale))


func _draw() -> void:
	var frame: int = UIKit.px(FRAME_PX, ui_scale)
	var header: int = UIKit.px(HEADER_PX, ui_scale)
	var title_rect := Rect2(Vector2.ZERO, Vector2(size.x, header))
	draw_rect(title_rect, UIKit.COLOR_BORDER_DARK)
	draw_rect(title_rect.grow(-UIKit.px(OUTLINE_PX, ui_scale)), UIKit.COLOR_BORDER)
	var map_rect := Rect2(Vector2(0, header), _map_view.size + Vector2(frame * 2, frame * 2))
	draw_rect(map_rect, UIKit.COLOR_BORDER_DARK)
	draw_rect(map_rect.grow(-UIKit.px(OUTLINE_PX, ui_scale)), UIKit.COLOR_BORDER)
	draw_rect(Rect2(Vector2(frame, frame + header), _map_view.size), COLOR_OUTSIDE)
	_draw_button(_zoom_in_rect, "+", zoom_level > 0)
	_draw_button(_zoom_out_rect, "-", zoom_level < ZOOM_SPANS.size() - 1)


func _draw_button(r: Rect2, glyph: String, enabled: bool) -> void:
	var inner: Rect2 = r.grow(-UIKit.px(OUTLINE_PX, ui_scale))
	draw_rect(inner, UIKit.COLOR_BORDER_DARK)
	draw_rect(inner.grow(-UIKit.px(OUTLINE_PX, ui_scale)), UIKit.COLOR_BUTTON if enabled else UIKit.COLOR_BUTTON_PRESSED)
	var f: Font = UIKit.read_font()
	var fs: int = UIKit.px(UIKit.FONT_SIZE, ui_scale)
	var text_size: Vector2 = f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = (r.position + (r.size - text_size) * 0.5 + Vector2(0, f.get_ascent(fs))).round()
	draw_string(f, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			UIKit.COLOR_TEXT if enabled else UIKit.COLOR_TEXT_DISABLED)


func _draw_map_view() -> void:
	var p: Node3D = get_player()
	var c: Vector2 = _map_view.size * 0.5
	if data == null or data.texture == null or p == null:
		return
	var s: float = pixel_scale()
	var rot: float = map_rotation()
	var player_xz := Vector2(p.global_position.x, p.global_position.z)
	var player_tex: Vector2 = data.world_to_texel(player_xz)
	# Centro do quadro = posição do jogador; sem rotação, deslocamento inteiro (pixels nítidos).
	var origin: Vector2 = c - (player_tex * s).rotated(rot)
	if is_zero_approx(rot):
		origin = origin.round()
	_map_view.draw_set_transform(origin, rot, Vector2(s, s))
	_map_view.draw_texture(data.texture, Vector2.ZERO)
	_map_view.draw_set_transform_matrix(Transform2D.IDENTITY)
	var icon_px: float = UIKit.px(ICON_PX, ui_scale)
	for icon: Dictionary in data.icons:
		var at: Vector2 = origin + (data.world_to_texel(icon[&"pos"]) * s).rotated(rot)
		draw_icon(_map_view, icon[&"icon"], at.round(), icon_px, ui_scale)
	for entity: Node3D in NetCombat.all_entities():
		if entity is NetEntity and NetFollowers.is_revealed((entity as NetEntity).entity_id):
			var marked: Vector2 = origin + (data.world_to_texel(Vector2(entity.global_position.x, entity.global_position.z)) * s).rotated(rot)
			_map_view.draw_circle(marked, 4, Color(1, 0.82, 0.2))
	draw_arrow(_map_view, c.round(), rot - float(p.get(&"facing_yaw")), UIKit.px(ARROW_PX, ui_scale), ui_scale)


## Ícone de ponto de interesse centrado em "at".
static func draw_icon(ci: CanvasItem, icon: int, at: Vector2, px: float, p_scale: float) -> void:
	var h: float = floorf(px * 0.5)
	var o: float = UIKit.px(OUTLINE_PX, p_scale)
	match icon:
		MinimapData.Icon.MASTER:
			var d := PackedVector2Array([at + Vector2(0, -h - o), at + Vector2(h + o, 0),
					at + Vector2(0, h + o), at + Vector2(-h - o, 0)])
			ci.draw_colored_polygon(d, COLOR_ICON_OUTLINE)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -h), at + Vector2(h, 0),
					at + Vector2(0, h), at + Vector2(-h, 0)]), COLOR_MASTER)
		MinimapData.Icon.SHOP:
			ci.draw_rect(Rect2(at - Vector2(h + o, h + o), Vector2(h + o, h + o) * 2.0), COLOR_ICON_OUTLINE)
			ci.draw_rect(Rect2(at - Vector2(h, h), Vector2(h, h) * 2.0), COLOR_SHOP)
		MinimapData.Icon.PORTAL:
			ci.draw_circle(at, h + o, COLOR_ICON_OUTLINE)
			ci.draw_circle(at, h, COLOR_PORTAL)
			ci.draw_circle(at, maxf(1.0, h - o * 2.0), COLOR_ICON_OUTLINE)
		MinimapData.Icon.QUEST:
			# Losango dourado com centro claro: legível sobre qualquer terreno.
			var outer := PackedVector2Array([at + Vector2(0, -h - o), at + Vector2(h + o, 0),
					at + Vector2(0, h + o), at + Vector2(-h - o, 0)])
			var inner := PackedVector2Array([at + Vector2(0, -h), at + Vector2(h, 0),
					at + Vector2(0, h), at + Vector2(-h, 0)])
			ci.draw_colored_polygon(outer, COLOR_ICON_OUTLINE)
			ci.draw_colored_polygon(inner, COLOR_QUEST)
			ci.draw_circle(at, maxf(1.0, h * 0.25), Color.WHITE)


## Seta do jogador centrada em "at", apontando para "angle" (0 = para cima da tela).
static func draw_arrow(ci: CanvasItem, at: Vector2, angle: float, px: float, p_scale: float) -> void:
	var h: float = px * 0.5
	var o: float = UIKit.px(OUTLINE_PX, p_scale)
	var tip := Vector2(0, -h)
	var left := Vector2(-h * 0.8, h)
	var notch := Vector2(0, h * 0.45)
	var right := Vector2(h * 0.8, h)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for v: Vector2 in [tip, right, notch, left]:
		outer.append(at + (v * (1.0 + 2.0 * o / px)).rotated(angle))
		inner.append(at + v.rotated(angle))
	ci.draw_colored_polygon(outer, COLOR_ICON_OUTLINE)
	ci.draw_colored_polygon(inner, COLOR_ARROW)


# ---------------------------------------------------------------- entrada

func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			# Em touch os botões de zoom continuam funcionando; o restante do quadro abre o mapa.
			if _zoom_in_rect.has_point(touch.position):
				set_zoom_level(zoom_level - 1)
			elif _zoom_out_rect.has_point(touch.position):
				set_zoom_level(zoom_level + 1)
			else:
				toggle_world_map()
			accept_event()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if _zoom_in_rect.has_point(mb.position):
			set_zoom_level(zoom_level - 1)
		elif _zoom_out_rect.has_point(mb.position):
			set_zoom_level(zoom_level + 1)
		else:
			toggle_world_map()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		set_zoom_level(zoom_level - 1)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		set_zoom_level(zoom_level + 1)
	else:
		return
	accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or (event as InputEventKey).echo:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event.is_action_pressed(ACTION_WORLD_MAP, false, true):
		toggle_world_map()
		get_viewport().set_input_as_handled()


func toggle_world_map() -> void:
	if world_map != null:
		world_map.visible = not world_map.visible


## Recebe o mesmo snapshot usado pelo diário/rastreador e refaz somente os marcadores.
func set_quest_progress(progress: Dictionary) -> void:
	_quest_progress = progress.duplicate(true)
	if data != null:
		_try_build()


func quest_map_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Variant in _quest_progress.get("quests", []):
		var map_id: StringName = _objective_map(entry as Dictionary)
		if not map_id.is_empty() and map_id not in result:
			result.append(map_id)
	return result


func _collect_quest_icons(map_id: StringName) -> void:
	if data == null or _map_node == null:
		return
	for entry: Variant in _quest_progress.get("quests", []):
		var e := entry as Dictionary
		var q: QuestDef = Content.quest(StringName(str(e.get("id", ""))))
		if q == null:
			continue
		var nodes: Array[Node3D] = _objective_nodes(e, q, map_id)
		for n: Node3D in nodes:
			var p: Vector3 = n.global_position if n.is_inside_tree() else n.position
			data.icons.append({&"icon": MinimapData.Icon.QUEST, &"pos": Vector2(p.x, p.z),
					&"key": q.name_key})


func _objective_nodes(e: Dictionary, q: QuestDef, map_id: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var target := StringName(str(e.get("target", "")))
	var npc_id: StringName = q.turn_in_npc if not q.turn_in_npc.is_empty() else q.giver_npc
	if bool(e.get("ready", false)):
		return _npc_marker(npc_id, map_id)
	var step_i := int(e.get("step", 0))
	if step_i < 0 or step_i >= q.steps.size():
		return out
	var step: QuestStep = q.steps[step_i]
	if step.type == QuestStep.StepType.TALK:
		return _npc_marker(target, map_id)
	if _objective_map(e) != map_id:
		return out
	if step.type == QuestStep.StepType.EXPLORE:
		var point := _map_node.find_child(String(target), true, false) as Node3D
		if point != null:
			out.append(point)
		return out
	# Spawners carregam monster_id; para coleta, marque quem derruba o item desejado.
	for n: Node in _map_node.find_children("*", "Node3D", true, false):
		var node := n as Node3D
		var monster_id := StringName(str(node.get_meta(&"monster_id", "")))
		if monster_id.is_empty():
			continue
		if step.type in [QuestStep.StepType.KILL, QuestStep.StepType.TRIAL] and \
				(target.is_empty() or target == &"*" or MonsterDef.species_of(monster_id) == target):
			out.append(node)
		elif step.type == QuestStep.StepType.COLLECT and _monster_drops(monster_id, target):
			out.append(node)
	return out


func _npc_marker(npc_id: StringName, map_id: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var npc: NpcDef = Content.npc(npc_id)
	if npc == null or npc.map_id != map_id:
		return out
	var points: Node = _map_node.get_node_or_null(MinimapData.NPC_POINTS_NODE)
	var marker := points.get_node_or_null(String(npc.spawn_marker)) as Node3D if points != null else null
	if marker != null:
		out.append(marker)
	return out


func _objective_map(e: Dictionary) -> StringName:
	var q: QuestDef = Content.quest(StringName(str(e.get("id", ""))))
	if q == null:
		return &""
	var npc_id: StringName = q.turn_in_npc if not q.turn_in_npc.is_empty() else q.giver_npc
	if bool(e.get("ready", false)):
		var npc: NpcDef = Content.npc(npc_id)
		return npc.map_id if npc != null else &""
	var i := int(e.get("step", 0))
	if i < 0 or i >= q.steps.size():
		return &""
	var s: QuestStep = q.steps[i]
	if s.type == QuestStep.StepType.TALK:
		var target_npc: NpcDef = Content.npc(s.target_id)
		return target_npc.map_id if target_npc != null else &""
	if s.type == QuestStep.StepType.TRIAL and not s.trial_map_id.is_empty():
		return s.trial_map_id
	# KILL/COLLECT/EXPLORE sem destino explícito continuam no mapa onde o jogador está.
	return data.map_id if data != null else &""


static func _monster_drops(monster_id: StringName, item_id: StringName) -> bool:
	var monster: MonsterDef = Content.monster(monster_id)
	if monster == null:
		return false
	for stage: MonsterStage in monster.stages:
		for drop: DropEntry in stage.drops:
			if drop.item_id == item_id:
				return true
	return false


func _register_actions() -> void:
	if not InputMap.has_action(ACTION_WORLD_MAP):
		InputMap.add_action(ACTION_WORLD_MAP)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_M
	ev.shift_pressed = true
	ev.device = ANY_DEVICE
	for existing: InputEvent in InputMap.action_get_events(ACTION_WORLD_MAP):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == KEY_M:
			return
	InputMap.action_add_event(ACTION_WORLD_MAP, ev)
