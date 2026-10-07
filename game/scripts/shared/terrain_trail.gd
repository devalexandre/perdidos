@tool
extends MeshInstance3D
## Sampled woodland trail; cosmetic geometry leaves the authoritative floor/nav intact.
@export var points: PackedVector3Array = PackedVector3Array()
@export var phase: float = 0.0
@export var half_width: float = 1.45
@export var soil_tint: Color = Color(0.56, 0.43, 0.28)

func _ready() -> void:
	if points.size() < 2:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance: float = 0.0
	for i: int in points.size():
		if i > 0:
			distance += points[i].distance_to(points[i - 1])
		var tangent: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(0, i - 1)]).normalized()
		var side := Vector3(-tangent.z, 0, tangent.x)
		var width: float = half_width * (1.0 + 0.18 * sin(distance * 0.31 + phase) + 0.08 * sin(distance * 0.87))
		for edge: int in 2:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(float(edge), distance / 3.0))
			surface.add_vertex(points[i] + side * width * (-1.0 if edge == 0 else 1.0))
		if i > 0:
			var k: int = (i - 1) * 2
			for index: int in [k, k + 2, k + 1, k + 1, k + 2, k + 3]:
				surface.add_index(index)
	mesh = surface.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/woodland_trail.gdshader")
	mat.set_shader_parameter("dirt", preload("res://assets/environment/painted/textures/tex_dirt.png"))
	mat.set_shader_parameter("soil_tint", soil_tint)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
