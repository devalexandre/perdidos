extends Node3D
## Chama com profundidade real, ancorada nos troncos. Nenhum plano gira junto com a câmera.
const SHADER: Shader = preload("res://assets/shaders/env_fire_volume.gdshader")
static var _tongue_mesh: ArrayMesh
var _tongues: Array[MeshInstance3D] = []

func _ready() -> void:
	if _tongue_mesh == null:
		_tongue_mesh = _make_mesh()
	for i: int in 7:
		var inner: bool = i < 3
		var angle: float = i * 2.39996
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter(&"phase", i * 1.73 + position.x + position.z)
		material.set_shader_parameter(&"height", (0.8 + i * 0.11) if inner else (1.20 + (i % 3) * 0.24))
		material.set_shader_parameter(&"radius", 0.25 if inner else 0.30)
		material.set_shader_parameter(&"core", inner)
		material.render_priority = 3 + (1 if inner else 0)
		var tongue := MeshInstance3D.new()
		tongue.mesh = _tongue_mesh
		tongue.material_override = material
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tongue.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		tongue.custom_aabb = AABB(Vector3(-0.7, -0.1, -0.7), Vector3(1.4, 2.3, 1.4))
		var spread: float = 0.16 if inner else 0.34
		tongue.position = Vector3(cos(angle) * spread, 0.0, sin(angle) * spread)
		add_child(tongue)
		_tongues.append(tongue)
	apply_quality()

func apply_quality() -> void:
	var count: int = 7 if EnvQuality.current == EnvQuality.Preset.ALTA else (5 if EnvQuality.current == EnvQuality.Preset.MEDIA else 3)
	for i: int in _tongues.size():
		_tongues[i].visible = i < count
		_tongues[i].visibility_range_end = EnvQuality.get_setting("foliage_distance")

static func _make_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	const SIDES: int = 10
	const RINGS: int = 18
	for j: int in RINGS + 1:
		var y: float = float(j) / RINGS
		var width: float = pow(1.0 - y, 0.65)
		for i: int in SIDES:
			var angle: float = TAU * i / SIDES + y * 0.8
			vertices.append(Vector3(cos(angle) * width, y, sin(angle) * width))
	for j: int in RINGS:
		for i: int in SIDES:
			var a: int = j * SIDES + i
			var b: int = j * SIDES + (i + 1) % SIDES
			indices.append_array(PackedInt32Array([a, b, a + SIDES, b, b + SIDES, a + SIDES]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
