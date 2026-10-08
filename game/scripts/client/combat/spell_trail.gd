extends MeshInstance3D
## Rastro contínuo da trajetória real; dissolve após a chegada. Não deixa carimbos no chão.
const SHADER: Shader = preload("res://assets/shaders/spell_trail.gdshader")
var follow: Node3D
var color: Color = Color(0.2, 0.6, 1.0)
var width: float = 0.13
var _points: Array[Vector3] = []
var _sample_time: float = 0.0
var _fade: float = 1.0
var _material: ShaderMaterial
var _mesh: ImmediateMesh

func _ready() -> void:
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"color", color)
	_material.render_priority = 5
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if is_instance_valid(follow):
		_points.append(follow.global_position)

func _process(delta: float) -> void:
	var live: bool = is_instance_valid(follow) and follow.is_inside_tree() and not follow.is_queued_for_deletion()
	if live:
		_sample_time += delta
		if _sample_time >= 0.025:
			_sample_time = fmod(_sample_time, 0.025)
			var point: Vector3 = follow.global_position
			if _points.is_empty() or point.distance_squared_to(_points.back()) > 0.0001:
				_points.append(point)
			var limit: int = 14 if EnvQuality.current == EnvQuality.Preset.ALTA else 7
			while _points.size() > limit:
				_points.pop_front()
	else:
		_fade = maxf(0.0, _fade - delta / 0.18)
		if _fade == 0.0:
			queue_free()
	_material.set_shader_parameter(&"fade", _fade)
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	# O cliente usa SubViewport: a câmera do root pode ser nula; usa a câmera dos sprites.
	if camera == null:
		camera = get_tree().get_first_node_in_group(DirectionalSprite3D.CAMERA_GROUP) as Camera3D
	var toward: Vector3 = camera.global_basis.z if camera != null else Vector3(0, 1, 1).normalized()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)
	for i: int in _points.size():
		var tangent: Vector3 = _points[mini(i + 1, _points.size() - 1)] - _points[maxi(i - 1, 0)]
		var side: Vector3 = tangent.cross(toward).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var u: float = float(i) / (_points.size() - 1)
		var half_width: float = width * (0.15 + u * 0.85) * 0.5
		_mesh.surface_set_uv(Vector2(u, 0))
		_mesh.surface_add_vertex(to_local(_points[i] - side * half_width))
		_mesh.surface_set_uv(Vector2(u, 1))
		_mesh.surface_add_vertex(to_local(_points[i] + side * half_width))
	_mesh.surface_end()
