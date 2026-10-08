class_name ClientView
extends Control
## Visão do cliente (GDD §17.0.A, §9.5): renderiza /root/Main/World numa SubViewport do TAMANHO DA JANELA
## (Balance.cfg.world_render_mode = "native"; o mundo ocupa a janela inteira, sem faixas) com pós-processo
## de tela (tilt-shift + vinheta, env_screen_post.gdshader) e presets de qualidade (EnvQuality); HUD por cima.
## Sprites continuam pixel art: o FOV é escolhido para 1 texel = k px no ponto focado (get_texel_scale(); inteiro
## sempre que possível, senão fracionário com "pixel AA" no shader dos sprites — GDD §17.0.C).
## Modo legado "internal": SubViewport Balance.cfg.internal_resolution ampliada por múltiplo inteiro.
## Câmera orbital, clique/toque para mover, gestos de toque.
## Movimento clássico por células (GDD §10.1): o clique é encaixado no centro da célula (WalkGrid do
## mapa); segurar o botão esquerdo segue o cursor, pedindo de novo a cada
## Balance.cfg.hold_walk_repeat_ms só se a célula sob o cursor mudou. O marcador de destino fica no
## centro da célula final do caminho confirmado pelo servidor até o jogador chegar. Sem som no clique.

## Clique/toque válido no chão (camada de colisão 1).
signal move_requested(world_pos: Vector3)
## Clique/toque numa coisa clicável (camada 2): "e:<entity_id>" ou "m:<interact_id>".
signal interact_requested(target_id: String)
## O cursor passou a apontar para outro alvo clicável ("" = nenhum).
signal hover_changed(target_id: String)

# --- Ações de input (registradas em runtime; não editar project.godot) ---
const ACTION_WORLD_CLICK: StringName = &"world_click"
const ACTION_CAMERA_DRAG: StringName = &"camera_drag"
const ACTION_ROTATE_LEFT: StringName = &"camera_rotate_left"
const ACTION_ROTATE_RIGHT: StringName = &"camera_rotate_right"
const ACTION_ZOOM_IN: StringName = &"camera_zoom_in"
const ACTION_ZOOM_OUT: StringName = &"camera_zoom_out"
const ACTION_PHOTO_MODE: StringName = &"toggle_photo_mode"

# --- Parâmetros locais de sensação de controle (sem equivalente em Balance) ---
## Camada de colisão do chão clicável (contrato: camada 1).
const GROUND_COLLISION_MASK: int = 1
## Camada das coisas clicáveis (contrato: camada 2 = bit 2).
const PICK_COLLISION_MASK: int = 1 << 1
const META_TARGET_ID: StringName = &"target_id"
const META_INTERACT_ID: StringName = &"interact_id"
const TARGET_MAP_PREFIX: String = "m:"
const RAY_LENGTH: float = 1000.0
## Passo de zoom por clique da roda do mouse.
const ZOOM_STEP: float = 0.1
## Graus de yaw por pixel (da janela) ao arrastar com botão direito / dois dedos.
const DRAG_ROTATE_DEG_PER_PX: float = 0.4
## Deslocamento máximo (pixels da janela) para um toque ainda contar como "tap".
const TAP_MAX_MOVE_PX: float = 24.0
## Suavização da câmera seguindo o alvo (1/s) e distância a partir da qual ela salta direto.
const FOLLOW_SHARPNESS: float = 12.0
const FOLLOW_SNAP_DISTANCE: float = 10.0
## Altura (m) do ponto para onde a câmera olha, acima dos pés do alvo.
const LOOK_AT_HEIGHT: float = 1.0
## Tempo de sumiço do marcador depois que o jogador chega (ou do clique sem caminho).
const MARKER_LIFETIME_SEC: float = 0.6
## Nó do mapa dentro da instância (contrato: Instances/<inst>/Map) e pasta das entidades.
const MAP_NODE_NAME: String = "Map"
const MARKER_GROUND_OFFSET: float = 0.02
const MARKER_INNER_RADIUS: float = 0.2
const MARKER_OUTER_RADIUS: float = 0.35
const MARKER_COLOR: Color = Color(1.0, 0.93, 0.6)
const MAP_NAME_KEY: String = "MAP_CITY_AWAKENING"
## Evento de ação válido para qualquer dispositivo (InputMap ALL_DEVICES).
const ANY_DEVICE: int = -1
const SCREEN_POST_SHADER: Shader = preload("res://assets/shaders/env_screen_post.gdshader")
const RENDER_MODE_INTERNAL: String = "internal"

@onready var _game_view: TextureRect = $GameView
@onready var _sub_viewport: SubViewport = $SubViewport
@onready var _camera: Camera3D = $SubViewport/Camera3D
@onready var _marker: MeshInstance3D = $SubViewport/ClickMarker
@onready var _hud: Control = $Hud
@onready var _map_name_label: Label = $Hud/MapName
@onready var _status_label: Label = $Hud/Status
var _moon_label: Label = null
var _moon_refresh_left: float = 0.0
var _last_moon_phase: int = -1

var camera_yaw: float = 0.0
var camera_zoom: float = 1.0

var _follow_target: Node3D = null
var _focus: Vector3 = Vector3.ZERO
var _has_focus: bool = false
var _view_scale: int = 1
var _view_offset: Vector2 = Vector2.ZERO
## Tamanho (px) da imagem 3D renderizada (SubViewport) e px de tela por texel de sprite no foco.
var _render_size: Vector2i = Vector2i.ONE
var _texel_scale: float = 1.0
var _native: bool = true
var _render_scale: float = 1.0
var _screen_mat: ShaderMaterial = null
var _env_seen: Environment = null
var _mouse_rotating: bool = false
## Clique direito: onde apertou e quanto arrastou (sem arrastar = menu do jogador sob o cursor).
var _right_press_pos: Vector2 = Vector2.INF
var _right_drag_px: float = 0.0
var _touches: Dictionary[int, Vector2] = {}
var _tap_candidate: bool = false
var _tap_start: Vector2 = Vector2.ZERO
var _marker_time_left: float = 0.0
## O marcador segue o destino do caminho do jogador local enquanto ele anda.
var _marker_pinned: bool = false
## Segurando o botão esquerdo depois de um clique de movimento no chão.
var _hold_walking: bool = false
var _hold_last_cell: Vector2i = Vector2i(-1, -1)
var _hold_next_msec: float = 0.0
var _grid: WalkGrid = null
var _hover_cell: MeshInstance3D
## Última posição do ponteiro vinda de evento de mouse (não da posição do SO: sob xvfb/testes e com eventos
## injetados ela é a única confiável). INF = sem ponteiro ainda.
var _last_pointer: Vector2 = Vector2.INF
var _hover_target: String = ""
var _hover_node: Node = null
var _game_ui: GameUI = null
var _audio: AudioDirector = null
var _listener: AudioListener3D = null
var _rain: RainOverlay = null

## Cria a interface do jogo (GameUI) e o AudioDirector. Testes de render podem desligar.
@export var create_game_ui: bool = true
@export var create_audio: bool = true


func _enter_tree() -> void:
	# O World vive em /root/Main/World: a SubViewport compartilha o World3D do raiz,
	# e o raiz para de renderizar 3D (só desenha a UI, incluindo a imagem da SubViewport).
	var root: Window = get_tree().root
	$SubViewport.world_3d = root.world_3d
	root.disable_3d = true
	# Quem ouve o 3D é a SubViewport (ouvinte no jogador); o raiz não, para não duplicar.
	root.audio_listener_enable_3d = false


func _exit_tree() -> void:
	get_tree().root.disable_3d = false
	get_tree().root.audio_listener_enable_3d = true
	UIKit.apply_cursor(false)


func _ready() -> void:
	_register_input_actions()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var settings: GameSettings = GameSettings.get_instance()
	EnvQuality.current = settings.graphics_quality
	if not settings.graphics_quality_changed.is_connected(_on_graphics_quality_changed):
		settings.graphics_quality_changed.connect(_on_graphics_quality_changed)
	_native = Balance.cfg.world_render_mode != RENDER_MODE_INTERNAL
	_render_scale = GameSettings.render_scale_for_quality(GameSettings.is_mobile_platform(), settings.graphics_quality)
	_render_size = Balance.cfg.internal_resolution
	_sub_viewport.size = _render_size
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_game_view.texture = _sub_viewport.get_texture()
	_game_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_game_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_game_view.stretch_mode = TextureRect.STRETCH_SCALE
	_game_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain = RainOverlay.new()
	_rain.name = &"RainOverlay"
	_game_view.add_child(_rain)
	if _native:
		_screen_mat = ShaderMaterial.new()
		_screen_mat.shader = SCREEN_POST_SHADER
		_screen_mat.set_shader_parameter(&"scene_linear", _sub_viewport.get_texture())
		_game_view.material = _screen_mat
	apply_env_quality()
	_setup_camera()
	_setup_marker()
	_setup_hover_cell()
	_map_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_map_name_label.text = tr(MAP_NAME_KEY)
	_status_label.text = ""
	_setup_moon_indicator()
	get_viewport().size_changed.connect(_update_layout)
	_listener = AudioListener3D.new()
	_listener.name = &"Listener"
	_sub_viewport.add_child(_listener)
	_listener.make_current()
	if create_audio:
		_audio = AudioDirector.new()
		_audio.name = &"AudioDirector"
		add_child(_audio)
	if create_game_ui:
		# Minimapa (Agente N) antes do GameUI: as janelas do jogo ficam por cima dele.
		var minimap := Minimap.new()
		minimap.view = self
		_hud.add_child(minimap)
		_game_ui = GameUI.new()
		_hud.add_child(_game_ui)
		_game_ui.quit_requested.connect(func() -> void: get_tree().quit())
	_update_layout()
	_update_camera(0.0)


func _setup_moon_indicator() -> void:
	_moon_label = Label.new()
	_moon_label.name = &"MoonPhase"
	_moon_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_moon_label.offset_left = -UIKit.px(230, 1.0)
	_moon_label.offset_right = -UIKit.px(158, 1.0)
	_moon_label.offset_top = UIKit.px(12, 1.0)
	_moon_label.offset_bottom = UIKit.px(38, 1.0)
	_moon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_moon_label.add_theme_font_override(&"font", UIKit.read_font())
	_moon_label.add_theme_font_size_override(&"font_size", UIKit.px(UIKit.FONT_SIZE_SMALL, 1.0))
	_moon_label.add_theme_color_override(&"font_color", UIKit.COLOR_TITLE)
	_moon_label.add_theme_color_override(&"font_outline_color", UIKit.COLOR_OUTLINE)
	_moon_label.add_theme_constant_override(&"outline_size", UIKit.px(UIKit.OUTLINE_SIZE, 1.0))
	_moon_label.tooltip_text = tr("HUD_MOON_TOOLTIP")
	_hud.add_child(_moon_label)
	_update_moon_indicator()


func _update_moon_indicator() -> void:
	if not is_instance_valid(_moon_label):
		return
	var phase: int = WorldClock.lunar_phase_index(float(Time.get_unix_time_from_system()))
	if phase == _last_moon_phase:
		return
	_last_moon_phase = phase
	_moon_label.text = tr("HUD_MOON_PHASE") % tr(WorldClock.LUNAR_PHASE_KEYS[phase])


# --- API pública ---

## Reaplica o preset de qualidade do cenário (EnvQuality.current) — tela de opções chama depois de trocar.
func apply_env_quality() -> void:
	EnvQuality.apply_viewport(_sub_viewport)
	EnvQuality.apply_screen_material(_screen_mat)
	_env_seen = null # força reaplicar no Environment/luzes do mapa atual no próximo quadro


func _on_graphics_quality_changed(preset_index: int) -> void:
	EnvQuality.current = GameSettings.quality_from_index(preset_index)
	_render_scale = GameSettings.render_scale_for_quality(GameSettings.is_mobile_platform(), EnvQuality.current)
	_update_layout()
	apply_env_quality()


## px de tela por texel de sprite no ponto focado com zoom 1.0 (modo native; 1 no modo internal).
func get_texel_scale() -> float:
	return _texel_scale


## Tamanho (px) da imagem 3D (SubViewport).
func get_render_size() -> Vector2i:
	return _render_size

## Alvo que a câmera segue (normalmente o jogador local). null = câmera parada.
func set_follow_target(target: Node3D) -> void:
	if _follow_target != null and is_instance_valid(_follow_target) \
			and _follow_target.has_signal(&"path_changed") \
			and _follow_target.is_connected(&"path_changed", _on_follow_path_changed):
		_follow_target.disconnect(&"path_changed", _on_follow_path_changed)
	_follow_target = target
	_grid = null
	if target != null:
		_focus = target.global_position
		_has_focus = true
		if target.has_signal(&"path_changed"):
			target.connect(&"path_changed", _on_follow_path_changed)
	if _audio != null:
		_audio.follow(target)


func get_follow_target() -> Node3D:
	return _follow_target


## Linha de status (conexão etc.). Aceita chave de tradução ou texto pronto; "" esconde.
func show_status(text: String) -> void:
	if _status_label == null:
		await ready
	_status_label.text = tr(text)


## Troca o nome de mapa exibido (chave de tradução).
func set_map_name(key: String) -> void:
	if _map_name_label == null:
		await ready
	_map_name_label.text = tr(key)


func get_camera() -> Camera3D:
	return _camera


## Interface do jogo (null se create_game_ui = false).
func get_game_ui() -> GameUI:
	return _game_ui


func get_audio_director() -> AudioDirector:
	return _audio


## Alvo clicável sob o cursor agora ("" = nenhum).
func get_hover_target() -> String:
	return _hover_target


## Raycast contra a camada 2 (entidades e objetos do mapa). Retorna {} ou
## {"target_id": String, "collider": Object, "position": Vector3}.
func pick_target(window_pos: Vector2) -> Dictionary:
	var internal_pos: Vector2 = window_to_internal(window_pos)
	if internal_pos == Vector2.INF:
		return {}
	var origin: Vector3 = _camera.project_ray_origin(internal_pos)
	var direction: Vector3 = _camera.project_ray_normal(internal_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, PICK_COLLISION_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target_id: String = target_id_of(hit["collider"])
		if not target_id.is_empty():
			return {"target_id": target_id, "collider": hit["collider"], "position": hit["position"]}
	# Tolerância de toque / clique por proximidade ao chão (vital para mobile e cliques rápidos)
	var ground_query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, GROUND_COLLISION_MASK)
	var ground_hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(ground_query)
	if not ground_hit.is_empty():
		var gpos: Vector3 = ground_hit["position"]
		var best_ent: Node3D = null
		var best_dist: float = 1.4
		for e: Node3D in NetCombat.all_entities():
			if not is_instance_valid(e) or (e.has_method(&"is_dead") and e.call(&"is_dead")):
				continue
			var d: float = Vector2(gpos.x - e.global_position.x, gpos.z - e.global_position.z).length()
			if d < best_dist:
				best_dist = d
				best_ent = e
		if best_ent != null:
			var visual: Node = best_ent.get_node_or_null(^"Visual")
			var pick_area: Area3D = visual.get_node_or_null(^"PickArea") if visual != null else null
			var tid: String = "e:%d" % int(best_ent.get(&"entity_id"))
			return {"target_id": tid, "collider": pick_area if pick_area != null else best_ent, "position": best_ent.global_position}
	return {}


## target_id de um colisor: meta target_id (dele ou do pai) ou "m:" + meta interact_id.
static func target_id_of(collider: Object) -> String:
	var node: Node = collider as Node
	var depth: int = 0
	while node != null and depth < 2:
		if node.has_meta(META_TARGET_ID):
			return String(node.get_meta(META_TARGET_ID))
		if node.has_meta(META_INTERACT_ID):
			return TARGET_MAP_PREFIX + String(node.get_meta(META_INTERACT_ID))
		node = node.get_parent()
		depth += 1
	return ""


## Grade de células do mapa do alvo seguido (null até o navmesh do cliente sincronizar).
func get_walk_grid() -> WalkGrid:
	if _grid != null:
		return _grid
	if _follow_target == null or not is_instance_valid(_follow_target) \
			or _follow_target.get_parent() == null:
		return null
	var inst: Node = _follow_target.get_parent().get_parent()
	var map_node: Node = inst.get_node_or_null(MAP_NODE_NAME) if inst != null else null
	if map_node == null or not map_node.has_method(&"get_navigation_map"):
		return null
	var map_id: StringName = StringName(str(map_node.get(&"map_id")))
	_grid = WalkGrid.for_map(map_id, map_node, map_node.call(&"get_navigation_map"))
	return _grid


## Centro da célula que contém o ponto (sem grade: o próprio ponto).
func snap_to_cell(point: Vector3) -> Vector3:
	var g: WalkGrid = get_walk_grid()
	if g == null:
		return point
	var c: Vector2i = g.world_to_cell(point)
	var center: Vector3 = g.cell_to_world(c)
	if not g.is_walkable(c):
		center.y = point.y
	return center


## Marcador de destino visível agora e sua posição (testes/capturas).
func is_marker_visible() -> bool:
	return _marker.visible


func get_marker_position() -> Vector3:
	return _marker.position - Vector3.UP * MARKER_GROUND_OFFSET


## Fator inteiro de ampliação e deslocamento atuais da imagem do jogo na janela.
func get_view_scale() -> int:
	return _view_scale


func get_view_offset() -> Vector2:
	return _view_offset


## Converte coordenada da janela (viewport raiz) para a SubViewport de resolução interna.
## Retorna Vector2.INF se o ponto estiver fora da imagem do jogo.
func window_to_internal(window_pos: Vector2) -> Vector2:
	var local: Vector2 = (window_pos - _view_offset) / float(_view_scale)
	var internal := Vector2(_render_size)
	if local.x < 0.0 or local.y < 0.0 or local.x >= internal.x or local.y >= internal.y:
		return Vector2.INF
	return local


## Raycast da câmera contra a camada 1 a partir de uma posição da janela. Retorna {} se nada.
func pick_ground(window_pos: Vector2) -> Dictionary:
	var internal_pos: Vector2 = window_to_internal(window_pos)
	if internal_pos == Vector2.INF:
		return {}
	var origin: Vector3 = _camera.project_ray_origin(internal_pos)
	var direction: Vector3 = _camera.project_ray_normal(internal_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH, GROUND_COLLISION_MASK)
	return _camera.get_world_3d().direct_space_state.intersect_ray(query)


# --- Loop ---

func _process(delta: float) -> void:
	_moon_refresh_left -= delta
	if _moon_refresh_left <= 0.0:
		_moon_refresh_left = 60.0
		_update_moon_indicator()
	var rotate_axis: float = Input.get_axis(ACTION_ROTATE_RIGHT, ACTION_ROTATE_LEFT)
	if _is_typing():
		rotate_axis = 0.0
	if rotate_axis != 0.0:
		camera_yaw += rotate_axis * deg_to_rad(Balance.cfg.camera_rotate_speed_deg) * delta
	_update_camera(delta)
	_rain.focus_position = _focus
	_update_env_quality()
	_update_scene_sun()
	_update_hold_walk()
	_update_marker(delta)
	_refresh_pointer_hover()


func _unhandled_input(event: InputEvent) -> void:
	# Eventos emulados (mouse←toque ou toque←mouse) são ignorados: cada gesto físico é tratado uma vez.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMagnifyGesture:
		_apply_zoom(camera_zoom * (event as InputEventMagnifyGesture).factor)
	elif event.is_action_pressed(ACTION_WORLD_CLICK):
		if _pointer_over_ui():
			return # arrastando skill/item ou clicando numa janela: não é clique no chão
		_world_click((event as InputEventMouse).position)
		_hold_walking = _hold_last_cell.x >= 0
	elif event.is_action_released(ACTION_WORLD_CLICK):
		_hold_walking = false
	elif event.is_action_pressed(ACTION_CAMERA_DRAG):
		_mouse_rotating = true
		_right_press_pos = (event as InputEventMouse).position if event is InputEventMouse else Vector2.INF
		_right_drag_px = 0.0
	elif event.is_action_released(ACTION_CAMERA_DRAG):
		_mouse_rotating = false
		if _right_press_pos != Vector2.INF and _right_drag_px <= TAP_MAX_MOVE_PX and event is InputEventMouse:
			_right_click((event as InputEventMouse).position)
		_right_press_pos = Vector2.INF
	elif event.is_action_pressed(ACTION_ZOOM_IN):
		_apply_zoom(camera_zoom + ZOOM_STEP)
	elif event.is_action_pressed(ACTION_ZOOM_OUT):
		_apply_zoom(camera_zoom - ZOOM_STEP)
	elif event.is_action_pressed(ACTION_PHOTO_MODE):
		_hud.visible = not _hud.visible
	elif event is InputEventMouseMotion and _mouse_rotating:
		_right_drag_px += (event as InputEventMouseMotion).relative.length()
		camera_yaw -= deg_to_rad((event as InputEventMouseMotion).relative.x * DRAG_ROTATE_DEG_PER_PX)
	elif event is InputEventMouseMotion:
		_last_pointer = (event as InputEventMouseMotion).position
		_update_hover(_last_pointer)
		return
	else:
		return
	get_viewport().set_input_as_handled()


# --- Toque ---

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		_tap_candidate = _touches.size() == 1
		_tap_start = event.position
	else:
		var was_tap: bool = _tap_candidate and _touches.size() == 1 and _touches.has(event.index)
		_touches.erase(event.index)
		if was_tap and event.position.distance_to(_tap_start) <= TAP_MAX_MOVE_PX:
			_world_click(event.position)
		_tap_candidate = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var previous: Dictionary[int, Vector2] = _touches.duplicate()
	_touches[event.index] = event.position
	if _touches.size() == 1:
		if event.position.distance_to(_tap_start) > TAP_MAX_MOVE_PX:
			_tap_candidate = false
		return
	# Dois dedos: arrastar gira (ponto médio em X), pinça dá zoom (razão entre distâncias).
	var ids: Array[int] = _touches.keys()
	var a_id: int = ids[0]
	var b_id: int = ids[1]
	var old_mid: Vector2 = (previous[a_id] + previous[b_id]) * 0.5
	var new_mid: Vector2 = (_touches[a_id] + _touches[b_id]) * 0.5
	camera_yaw -= deg_to_rad((new_mid.x - old_mid.x) * DRAG_ROTATE_DEG_PER_PX)
	var old_dist: float = previous[a_id].distance_to(previous[b_id])
	var new_dist: float = _touches[a_id].distance_to(_touches[b_id])
	if old_dist > 0.0:
		_apply_zoom(camera_zoom * new_dist / old_dist)


# --- Internos ---

## Clique/toque no mundo: primeiro coisas clicáveis (camada 2), senão movimento no chão.
func _world_click(window_pos: Vector2) -> void:
	var target: Dictionary = pick_target(window_pos)
	if not target.is_empty():
		_set_hover(target["target_id"], target["collider"])
		_hold_last_cell = Vector2i(-1, -1)
		interact_requested.emit(String(target["target_id"]))
		return
	_request_move(window_pos)


## Clique direito sem arrastar: sobre outro jogador abre o menu do grupo (o arrasto continua girando a câmera).
func _right_click(window_pos: Vector2) -> void:
	var target: Dictionary = pick_target(window_pos)
	if target.is_empty():
		return
	var id: int = NetCombat.parse_entity_id(String(target["target_id"]))
	var e: Node = NetCombat.find_entity(id)
	if e is NetEntity and (e as NetEntity).is_player() and not (e as NetEntity).is_local_player():
		NetParty.player_menu_requested.emit(id, (e as NetEntity).display_name)


## Clique sobre janela/controle da interface ou durante um arrasto não vira movimento no mundo.
func _pointer_over_ui() -> bool:
	if get_viewport().gui_is_dragging():
		return true
	var control := get_viewport().gui_get_hovered_control()
	return control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _refresh_pointer_hover() -> void:
	# Recalcular também com o mouse parado: a câmera acompanha o jogador.
	var pointer := _last_pointer
	if pointer == Vector2.INF:
		return
	var control := get_viewport().gui_get_hovered_control()
	if _mouse_rotating or not _touches.is_empty() or not get_viewport_rect().has_point(pointer) \
			or (control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE):
		_hover_cell.hide()
		_set_hover("", null)
		return
	_update_hover(pointer)


func _update_hover(window_pos: Vector2) -> void:
	_hover_cell.hide()
	var target: Dictionary = pick_target(window_pos)
	if not target.is_empty():
		_set_hover(target["target_id"], target["collider"])
		return
	_set_hover("", null)
	var grid: WalkGrid = get_walk_grid()
	if grid == null:
		return
	var hit: Dictionary = pick_ground(window_pos)
	if hit.is_empty():
		return
	var cell: Vector2i = grid.world_to_cell(hit["position"])
	if not grid.is_walkable(cell):
		return
	var center: Vector3 = grid.cell_to_world(cell)
	center.y = maxf(center.y, (hit["position"] as Vector3).y) + 0.085
	_hover_cell.position = center
	_hover_cell.scale = Vector3(grid.cell_size, 1.0, grid.cell_size)
	_hover_cell.show()


func _setup_hover_cell() -> void:
	_hover_cell = MeshInstance3D.new()
	_hover_cell.name = &"HoverCell"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/grid_hover.gdshader")
	material.render_priority = 10
	plane.material = material
	_hover_cell.mesh = plane
	_hover_cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover_cell.hide()
	_sub_viewport.add_child(_hover_cell)


func is_hover_cell_visible() -> bool:
	return _hover_cell != null and _hover_cell.visible


func get_hover_cell_position() -> Vector3:
	return _hover_cell.position if _hover_cell != null else Vector3.INF


func _set_hover(target_id: String, collider: Object) -> void:
	if target_id == _hover_target:
		return
	if _hover_node != null and is_instance_valid(_hover_node) and _hover_node.has_method(&"set_hovered"):
		_hover_node.call(&"set_hovered", false)
	_hover_target = target_id
	_hover_node = null
	# O visual (EntityVisual) é o pai da área de clique.
	var node: Node = collider as Node
	if node != null:
		var owner_visual: Node = node.get_parent()
		if owner_visual != null and owner_visual.has_method(&"set_hovered"):
			_hover_node = owner_visual
			owner_visual.call(&"set_hovered", true)
	UIKit.apply_cursor(not target_id.is_empty())
	hover_changed.emit(target_id)


func _is_typing() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit


func _request_move(window_pos: Vector2) -> void:
	_hold_last_cell = Vector2i(-1, -1)
	var hit: Dictionary = pick_ground(window_pos)
	if hit.is_empty():
		return
	var point: Vector3 = snap_to_cell(hit["position"])
	var g: WalkGrid = get_walk_grid()
	_hold_last_cell = g.world_to_cell(point) if g != null else Vector2i(0, 0)
	_hold_next_msec = NetClock.local_now_msec() + Balance.cfg.hold_walk_repeat_ms
	_show_marker(point)
	move_requested.emit(point)


## Botão esquerdo segurado: segue o cursor, um pedido por intervalo e só se a célula mudou.
func _update_hold_walk() -> void:
	if not _hold_walking:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hold_walking = false
		return
	var now: float = NetClock.local_now_msec()
	if now < _hold_next_msec:
		return
	_hold_next_msec = now + Balance.cfg.hold_walk_repeat_ms
	var hit: Dictionary = pick_ground(get_viewport().get_mouse_position())
	if hit.is_empty():
		return
	var point: Vector3 = snap_to_cell(hit["position"])
	var g: WalkGrid = get_walk_grid()
	var cell: Vector2i = g.world_to_cell(point) if g != null else Vector2i(roundi(point.x), roundi(point.z))
	if cell == _hold_last_cell:
		return
	_hold_last_cell = cell
	_show_marker(point)
	move_requested.emit(point)


## O servidor confirmou um caminho novo do jogador local: o marcador vai para o destino real.
func _on_follow_path_changed() -> void:
	var path: MovePath = _follow_target.call(&"get_client_path") as MovePath \
			if _follow_target != null and _follow_target.has_method(&"get_client_path") else null
	if path == null or not path.is_pending_at(NetClock.server_now_msec()):
		return
	_show_marker(path.destination())
	_marker_pinned = true


func _apply_zoom(value: float) -> void:
	camera_zoom = clampf(value, Balance.cfg.camera_zoom_min, Balance.cfg.camera_zoom_max)


func _setup_camera() -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_update_fov()
	_camera.current = true
	_camera.add_to_group(DirectionalSprite3D.CAMERA_GROUP)


func _update_camera(delta: float) -> void:
	if _follow_target != null and not is_instance_valid(_follow_target):
		_follow_target = null
	if _follow_target != null and _follow_target.is_inside_tree():
		var target_pos: Vector3 = _follow_target.global_position
		if not _has_focus or _focus.distance_to(target_pos) > FOLLOW_SNAP_DISTANCE or delta <= 0.0:
			_focus = target_pos
		else:
			_focus = _focus.lerp(target_pos, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
		_has_focus = true
	var pitch: float = deg_to_rad(Balance.cfg.camera_pitch_deg)
	var distance: float = Balance.cfg.camera_base_distance / camera_zoom
	# yaw 0 = câmera no lado +Z do alvo, olhando para -Z.
	var offset := Vector3(0.0, sin(pitch), cos(pitch)) * distance
	var look_at_point: Vector3 = _focus + Vector3.UP * LOOK_AT_HEIGHT
	_camera.position = look_at_point + offset.rotated(Vector3.UP, camera_yaw)
	_camera.look_at(look_at_point, Vector3.UP)
	if _listener != null:
		# Ouvinte no jogador, orientado como a câmera (esquerda/direita da tela = estéreo).
		_listener.global_transform = Transform3D(Basis(Vector3.UP, camera_yaw), _focus)


## FOV tal que, com zoom 1.0 e distância base, 1 texel de sprite = _texel_scale px no ponto focado.
func _update_fov() -> void:
	var view_height_units: float = float(_render_size.y) / (Balance.cfg.world_pixels_per_unit * _texel_scale)
	_camera.fov = rad_to_deg(2.0 * atan(view_height_units * 0.5 / Balance.cfg.camera_base_distance))


## Escala de texel para uma altura de janela (GDD §17.0.C: Viajante ≈9–11% da tela em 1080p). Inteira quando
## fica a menos de Balance.cfg.sprite_texel_snap de um inteiro; senão fracionária (nunca abaixo de 0,5).
static func texel_scale_for_height(window_height: float) -> float:
	var exact: float = window_height * Balance.cfg.character_screen_fraction / Balance.cfg.character_body_px
	var whole: float = maxf(1.0, roundf(exact))
	if absf(exact - whole) <= Balance.cfg.sprite_texel_snap:
		return whole
	return maxf(0.5, exact)


## O mapa carregado pode trocar o Environment: aplica o preset de qualidade uma vez por Environment.
func _update_env_quality() -> void:
	var world: World3D = _camera.get_world_3d()
	var env: Environment = world.environment if world != null else null
	if env == _env_seen:
		return
	_env_seen = env
	_sun = null
	EnvQuality.apply_environment(env)
	EnvQuality.apply_lights(get_tree().root)


var _sun: DirectionalLight3D = null
var _sun_search_msec: int = 0


## Sol da cena para a sombra macia dos pés (direção e força; GDD §17.0.C). Procura o DirectionalLight3D
## visível no máximo 1x por segundo (o mapa pode trocar); a direção é lida a cada quadro (ciclo dia/noite).
func _update_scene_sun() -> void:
	if _sun != null and (not is_instance_valid(_sun) or not _sun.is_inside_tree()):
		_sun = null
	if _sun == null:
		var now: int = Time.get_ticks_msec()
		if now < _sun_search_msec:
			return
		_sun_search_msec = now + 1000
		var best_energy: float = -1.0
		for n: Node in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			var l := n as DirectionalLight3D
			if l.is_visible_in_tree() and l.light_energy > best_energy:
				best_energy = l.light_energy
				_sun = l
		if _sun == null:
			return
	var energy: float = _sun.light_energy if _sun.is_visible_in_tree() else 0.0
	DirectionalSprite3D.set_scene_sun(-_sun.global_basis.z, energy, _sun.shadow_enabled and energy > 0.0)


func _update_layout() -> void:
	var window_size: Vector2 = get_viewport_rect().size
	if _native:
		# Em mobile Baixa, reduz pixels 3D sem alterar a proporção nem o tamanho da UI.
		_render_size = Vector2i(maxi(1, roundi(window_size.x * _render_scale)),
				maxi(1, roundi(window_size.y * _render_scale)))
		_sub_viewport.size = _render_size
		_view_scale = 1
		_view_offset = Vector2.ZERO
		_game_view.position = Vector2.ZERO
		_game_view.size = window_size
		_texel_scale = texel_scale_for_height(window_size.y)
		DirectionalSprite3D.set_screen_texel_scale(_texel_scale, window_size.y)
		_update_fov()
		return
	_texel_scale = 1.0
	DirectionalSprite3D.set_screen_texel_scale(1.0, float(Balance.cfg.internal_resolution.y))
	var internal := Vector2(Balance.cfg.internal_resolution)
	var fit: int = int(minf(floorf(window_size.x / internal.x), floorf(window_size.y / internal.y)))
	_view_scale = maxi(1, fit)
	var scaled: Vector2 = internal * _view_scale
	_view_offset = ((window_size - scaled) * 0.5).floor()
	_game_view.position = _view_offset
	_game_view.size = scaled


func _setup_marker() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = MARKER_INNER_RADIUS
	mesh.outer_radius = MARKER_OUTER_RADIUS
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = MARKER_COLOR
	mesh.material = mat
	_marker.mesh = mesh
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false


func _show_marker(point: Vector3) -> void:
	_marker.position = point + Vector3.UP * MARKER_GROUND_OFFSET
	_marker.visible = true
	_marker.transparency = 0.0
	_marker_time_left = MARKER_LIFETIME_SEC


func _update_marker(delta: float) -> void:
	if not _marker.visible:
		return
	if _marker_pinned:
		var path: MovePath = _follow_target.call(&"get_client_path") as MovePath \
				if _follow_target != null and is_instance_valid(_follow_target) \
				and _follow_target.has_method(&"get_client_path") else null
		if path != null and path.is_pending_at(NetClock.server_now_msec()):
			_marker_time_left = MARKER_LIFETIME_SEC
			_marker.transparency = 0.0
			return
		_marker_pinned = false
	_marker_time_left -= delta
	if _marker_time_left <= 0.0:
		_marker.visible = false
		return
	_marker.transparency = 1.0 - _marker_time_left / MARKER_LIFETIME_SEC


func _register_input_actions() -> void:
	_add_key_action(ACTION_ROTATE_LEFT, KEY_Q)
	_add_key_action(ACTION_ROTATE_RIGHT, KEY_E)
	_add_key_action(ACTION_PHOTO_MODE, KEY_F10)
	_add_mouse_action(ACTION_WORLD_CLICK, MOUSE_BUTTON_LEFT)
	_add_mouse_action(ACTION_CAMERA_DRAG, MOUSE_BUTTON_RIGHT)
	_add_mouse_action(ACTION_ZOOM_IN, MOUSE_BUTTON_WHEEL_UP)
	_add_mouse_action(ACTION_ZOOM_OUT, MOUSE_BUTTON_WHEEL_DOWN)


func _add_key_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.device = ANY_DEVICE
	InputMap.action_add_event(action, ev)


func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.device = ANY_DEVICE
	InputMap.action_add_event(action, ev)
