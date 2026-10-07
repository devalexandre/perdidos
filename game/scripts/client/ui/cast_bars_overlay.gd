class_name CastBarsOverlay
extends Control
## Barrinhas de conjuração sobre a cabeça de quem conjura (GDD §8.1: a conjuração aparece para todos
## da instância). Uma CastBar pequena (sem texto) por entidade, projetada da posição 3D para a tela a
## cada quadro, logo acima do nome. O jogador local usa a barra grande em cima da barra 1–0.

const BAR_WIDTH_PX: float = 44.0
const BAR_HEIGHT_PX: float = 5.0
## Distância (px de UI na escala 1) acima do centro do nome.
const ABOVE_NAME_PX: float = 12.0
## Sem visual/nome: altura acima dos pés (m).
const FALLBACK_HEAD_M: float = 2.2
const M_GET_NAMEPLATE: StringName = &"get_nameplate"

var ui_scale: float = 1.0
var view: ClientView = null
## entity_id -> CastBar
var _bars: Dictionary[int, CastBar] = {}
## entity_id -> Node3D da entidade
var _targets: Dictionary[int, Node3D] = {}


func _init(p_scale: float = 1.0) -> void:
	ui_scale = p_scale
	name = &"CastBarsOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Começa a barra de `entity` (conjuração de total_ms).
func start(entity_id: int, entity: Node3D, total_ms: int) -> void:
	if entity == null or total_ms <= 0:
		return
	var bar: CastBar = _bars.get(entity_id)
	if bar == null or not is_instance_valid(bar):
		bar = CastBar.new(ui_scale, false)
		bar.name = "Cast_%d" % entity_id
		bar.size = Vector2(UIKit.px(BAR_WIDTH_PX, ui_scale), UIKit.px(BAR_HEIGHT_PX, ui_scale))
		add_child(bar)
		_bars[entity_id] = bar
	_targets[entity_id] = entity
	bar.start("", total_ms)
	_place(entity_id)


func cancel(entity_id: int) -> void:
	var bar: CastBar = _bars.get(entity_id)
	if bar != null and is_instance_valid(bar):
		bar.cancel()


func bar_for(entity_id: int) -> CastBar:
	return _bars.get(entity_id)


func _process(_delta: float) -> void:
	for id: int in _bars.keys():
		# Sem tipo antes de validar: barra ou entidade já liberadas (troca de mapa) não podem ir para var tipada.
		var raw_bar: Variant = _bars[id]
		var raw_ent: Variant = _targets.get(id)
		if not is_instance_valid(raw_bar) or raw_ent == null or not is_instance_valid(raw_ent):
			if is_instance_valid(raw_bar):
				(raw_bar as CastBar).queue_free()
			_bars.erase(id)
			_targets.erase(id)
			continue
		var bar: CastBar = raw_bar
		var ent: Node3D = raw_ent
		if bar.state == CastBar.State.IDLE:
			bar.visible = false
			continue
		bar.visible = true
		_place(id)


func _place(entity_id: int) -> void:
	var bar: CastBar = _bars.get(entity_id)
	var ent: Node3D = _targets.get(entity_id)
	if view == null or bar == null or ent == null or not is_instance_valid(ent):
		return
	var cam: Camera3D = view.get_camera()
	if cam == null:
		return
	var anchor: Vector3 = ent.global_position + Vector3.UP * FALLBACK_HEAD_M
	var visual: Node = ent.get_node_or_null(^"Visual")
	if visual != null and visual.has_method(M_GET_NAMEPLATE):
		var plate: Label3D = visual.call(M_GET_NAMEPLATE) as Label3D
		if plate != null and plate.is_inside_tree():
			anchor = plate.global_position
	if cam.is_position_behind(anchor):
		bar.visible = false
		return
	var p: Vector2 = cam.unproject_position(anchor) * view.get_view_scale() + view.get_view_offset()
	# Coordenadas da janela -> coordenadas deste Control.
	p = get_global_transform_with_canvas().affine_inverse() * p
	bar.position = Vector2(p.x - bar.size.x * 0.5, p.y - UIKit.px(ABOVE_NAME_PX, ui_scale) - bar.size.y)
