class_name HotbarAim
extends Node3D
## Mira das skills de chão (GDD §10.1: "skills de área pedem um clique no chão, com pré-visualização
## da área") e o aviso no chão antes do impacto quando alguém lança uma skill com aviso (NetProgress.skill_cast).
## Vive dentro da SubViewport do ClientView (mesmo World3D do jogo).
##
## Mira: begin(def) → a forma (círculo, cone ou linha) segue o cursor; clique esquerdo confirma
## (confirmed), botão direito/Esc cancela. Áreas no chão ficam presas ao alcance da skill (anel).

signal confirmed(skill_id: StringName, point: Vector3)
signal cancelled

const GROUND_OFFSET: float = 0.05
const RING_WIDTH: float = 0.08
const CONE_SEGMENTS: int = 16
const RUNE_SHADER: Shader = preload("res://assets/shaders/skill_aim_runes.gdshader")
const PREVIEW_COLOR: Color = Color(1.0, 0.9, 0.45, 0.35)
const RANGE_COLOR: Color = Color(1.0, 0.9, 0.45, 0.6)
const FLASH_ALPHA: float = 0.45
const FLASH_SEC: float = 0.45
const MSEC_PER_SEC: float = 1000.0

var view: ClientView = null
var player: Node3D = null
var aiming_skill: SkillDef = null
var _preview: Node3D = null
var _range_ring: MeshInstance3D = null
var _last_point: Vector3 = Vector3.ZERO
var mobile_drag: bool = false
var _mobile_direction: Vector2 = Vector2.ZERO


func is_aiming() -> bool:
	return aiming_skill != null


func begin(def: SkillDef, p_player: Node3D, use_mobile_drag: bool = false) -> void:
	cancel(false)
	mobile_drag = use_mobile_drag
	_mobile_direction = Vector2.ZERO
	aiming_skill = def
	player = p_player
	var color: Color = SkillFx.charge_color_for(def)
	color.a = PREVIEW_COLOR.a
	_preview = make_shape(def, color)
	add_child(_preview)
	if def.target_type == SkillDef.TargetType.GROUND_AREA and def.range_cells > 0.0:
		var range_color := Color(color, RANGE_COLOR.a * 0.65)
		_range_ring = _ring(def.range_cells * Balance.cfg.cell_size, range_color)
		add_child(_range_ring)
	_update_preview()


func cancel(emit: bool = true) -> void:
	var was: bool = aiming_skill != null
	aiming_skill = null
	mobile_drag = false
	for n: Node in [_preview, _range_ring]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_preview = null
	_range_ring = null
	if was and emit:
		cancelled.emit()


## Chamado pelo HUD em _input. true = consumiu o evento.
func handle_input(event: InputEvent) -> bool:
	if not is_aiming():
		return false
	# O dedo dono da skill é tratado pelo círculo mobile; outros dedos continuam andando.
	if mobile_drag:
		return false
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var id: StringName = aiming_skill.id
			var p: Variant = _aim_point(mb.position)
			cancel(false)
			if p != null:
				confirmed.emit(id, p as Vector3)
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
			return true
	elif event is InputEventScreenTouch and event.pressed:
		var id2: StringName = aiming_skill.id
		var p2: Variant = _aim_point((event as InputEventScreenTouch).position)
		cancel(false)
		if p2 != null:
			confirmed.emit(id2, p2 as Vector3)
		return true
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		cancel()
		return true
	return false


func _process(_delta: float) -> void:
	if is_aiming():
		_update_preview()


func update_mobile_direction(direction: Vector2) -> void:
	_mobile_direction = direction.limit_length(1.0)
	if is_aiming() and mobile_drag:
		_update_preview()


func finish_mobile(cancelled_gesture: bool) -> void:
	if not is_aiming() or not mobile_drag:
		return
	if cancelled_gesture or not is_instance_valid(player):
		cancel()
		return
	_update_preview()
	var id: StringName = aiming_skill.id
	var point: Vector3 = _last_point
	cancel(false)
	confirmed.emit(id, point)


func _mobile_point() -> Vector3:
	var yaw: float = view.camera_yaw
	var forward := -Vector3(sin(yaw), 0.0, cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var direction: Vector3 = right * _mobile_direction.x + forward * -_mobile_direction.y
	if aiming_skill.target_type == SkillDef.TargetType.GROUND_AREA:
		return player.global_position + direction * aiming_skill.range_cells * Balance.cfg.cell_size
	if direction.length_squared() < 0.001:
		var facing: float = player.facing_yaw if player is NetEntity else yaw
		direction = -Vector3(sin(facing), 0, cos(facing))
	return player.global_position + direction.normalized() * maxf(aiming_skill.range_cells * Balance.cfg.cell_size, 1.0)


## Ponto do chão sob a posição da janela (preso ao alcance em áreas no chão).
func _aim_point(window_pos: Vector2) -> Variant:
	if view == null:
		return null
	var hit: Dictionary = view.pick_ground(window_pos)
	if hit.is_empty():
		return null
	var p: Vector3 = hit["position"]
	if aiming_skill != null and aiming_skill.target_type == SkillDef.TargetType.GROUND_AREA \
			and player != null and is_instance_valid(player):
		var origin: Vector3 = player.global_position
		var max_r: float = aiming_skill.range_cells * Balance.cfg.cell_size
		var d := Vector3(p.x - origin.x, 0.0, p.z - origin.z)
		if d.length() > max_r:
			p = origin + d.normalized() * max_r
			p.y = hit["position"].y
	return p


func _update_preview() -> void:
	if view == null or player == null or not is_instance_valid(player) or _preview == null:
		return
	var origin: Vector3 = player.global_position
	if _range_ring != null:
		_range_ring.global_position = origin + Vector3.UP * GROUND_OFFSET
	var p: Variant = _mobile_point() if mobile_drag else _aim_point(view.get_viewport().get_mouse_position())
	if p != null:
		_last_point = p
	match aiming_skill.target_type:
		SkillDef.TargetType.GROUND_AREA:
			_preview.global_position = _last_point + Vector3.UP * GROUND_OFFSET
		_:
			_preview.global_position = origin + Vector3.UP * GROUND_OFFSET
			var d := Vector3(_last_point.x - origin.x, 0.0, _last_point.z - origin.z)
			if d.length() > 0.01:
				_preview.rotation.y = atan2(-d.x, -d.z)


# ---------------------------------------------------------------- efeitos de lançamento

## Mostra a forma da skill no chão por um instante (ou o aviso antes do impacto).
func show_cast(def: SkillDef, caster: Node3D, point: Vector3, cast_ms: int) -> void:
	# O efeito da skill vem do SkillFx (folhas de assets/fx/skills/). Desde 30/09/2026 o aviso antes do
	# impacto (ground_warning_sec, Queda Estelar) também: a sombra da pedra-estrela com o chão rachando
	# (arcane_star_fall_warning). A mira rúnica daqui é a alternativa quando a folha não existe.
	if def == null or def.ground_warning_sec <= 0.0 or SkillFxSprite.has_piece(SkillFx.WARNING_PIECE):
		return
	var color: Color = SkillFx.charge_color_for(def)
	color.a = FLASH_ALPHA
	var shape: Node3D = make_shape(def, color)
	add_child(shape)
	var origin: Vector3 = caster.global_position if caster != null and is_instance_valid(caster) else point
	match def.target_type:
		SkillDef.TargetType.CONE, SkillDef.TargetType.LINE:
			shape.global_position = origin + Vector3.UP * GROUND_OFFSET
			var d := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
			if d.length() > 0.01:
				shape.rotation.y = atan2(-d.x, -d.z)
		SkillDef.TargetType.SELF_AREA, SkillDef.TargetType.SELF:
			shape.global_position = origin + Vector3.UP * GROUND_OFFSET
		_:
			shape.global_position = point + Vector3.UP * GROUND_OFFSET
	var hold: float = maxf(cast_ms / MSEC_PER_SEC, 0.0)
	var duration: float = def.duration_sec if def.effect == SkillDef.Effect.DAMAGE_OVER_TIME else 0.0
	var tw: Tween = shape.create_tween()
	tw.tween_interval(hold + duration)
	tw.tween_property(shape, "scale", Vector3(1.08, 1.0, 1.08), FLASH_SEC * 0.5)
	tw.tween_property(shape, "scale", Vector3(0.01, 1.0, 0.01), FLASH_SEC * 0.5)
	tw.tween_callback(shape.queue_free)


# ---------------------------------------------------------------- formas

## Forma da skill no plano XZ, com a "frente" para -Z (mesma convenção do facing_yaw).
static func make_shape(def: SkillDef, color: Color) -> Node3D:
	var cell: float = Balance.cfg.cell_size
	var root := Node3D.new()
	root.name = &"SkillShape"
	match def.target_type:
		SkillDef.TargetType.CONE:
			var mi := MeshInstance3D.new()
			mi.mesh = _cone_mesh(def.radius_cells * cell, def.cone_deg)
			mi.material_override = _mat(color)
			root.add_child(mi)
		SkillDef.TargetType.LINE:
			var mi2 := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(def.line_width_cells * cell, def.line_length_cells * cell)
			mi2.mesh = pm
			mi2.position = Vector3(0.0, 0.0, -def.line_length_cells * cell * 0.5)
			mi2.material_override = _mat(color)
			root.add_child(mi2)
		_:
			var r: float = def.radius_cells * cell if def.radius_cells > 0.0 else cell * 0.6
			var mi3 := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2.ONE * r * 2.08
			mi3.mesh = plane
			var material := ShaderMaterial.new()
			material.shader = RUNE_SHADER
			material.set_shader_parameter(&"color", Color(color, 1.0))
			material.set_shader_parameter(&"opacity", clampf(color.a * 2.5, 0.25, 1.0))
			material.set_shader_parameter(&"rune_count", 12.0 if EnvQuality.current == EnvQuality.Preset.ALTA else 8.0)
			mi3.material_override = material
			root.add_child(mi3)
	for c: Node in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.albedo_color = color
	return m


static func _ring(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(radius - RING_WIDTH, 0.0)
	tm.outer_radius = radius
	mi.mesh = tm
	mi.scale = Vector3(1.0, 0.1, 1.0)
	mi.material_override = _mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _cone_mesh(radius: float, angle_deg: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var half: float = deg_to_rad(angle_deg) * 0.5
	for i: int in CONE_SEGMENTS:
		var a0: float = -half + (2.0 * half) * i / CONE_SEGMENTS
		var a1: float = -half + (2.0 * half) * (i + 1) / CONE_SEGMENTS
		verts.append(Vector3.ZERO)
		verts.append(Vector3(-sin(a0), 0.0, -cos(a0)) * radius)
		verts.append(Vector3(-sin(a1), 0.0, -cos(a1)) * radius)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
