extends Node3D
## Clarão local de contato. Luzes sem sombra, com orçamento compartilhado entre todas as magias.
const SHADER: Shader = preload("res://assets/shaders/spell_contact.gdshader")
const MAX_LIGHTS: int = 4
static var active_lights: int = 0
var color: Color = Color(0.2, 0.6, 1.0)
var style: StringName = &"arcane"
var radius: float = 1.4
var height: float = 0.85
var duration: float = 0.24
var elapsed: float = 0.0
var _materials: Array[ShaderMaterial] = []
var _light: OmniLight3D
var _owns_light: bool = false

func _ready() -> void:
	for i: int in 2:
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter(&"color", color)
		material.set_shader_parameter(&"billboard", i == 1)
		material.render_priority = 8 + i
		var mesh := MeshInstance3D.new()
		if i == 0:
			var plane := PlaneMesh.new()
			plane.size = Vector2.ONE * clampf(radius * 1.6, 1.2, 3.8)
			mesh.mesh = plane
			mesh.position.y = 0.08
		else:
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE * 0.7
			mesh.mesh = quad
			mesh.position.y = height
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		_materials.append(material)
	if EnvQuality.current == EnvQuality.Preset.ALTA and active_lights < MAX_LIGHTS:
		_light = OmniLight3D.new()
		_light.light_color = color.lerp(Color.WHITE, 0.25)
		_light.omni_range = clampf(radius * 1.6, 2.5, 5.0)
		_light.omni_attenuation = 1.7
		_light.shadow_enabled = false
		_light.position.y = maxf(height, 0.65)
		add_child(_light)
		active_lights += 1
		_owns_light = true
	_update()

func envelope() -> float:
	var t: float = clampf(elapsed / duration, 0.0, 1.0)
	if style == &"nature":
		return sin(t * PI) * 0.45
	if style == &"ice":
		return smoothstep(0.0, 0.10, t) * (1.0 - t) * 0.8
	return pow(1.0 - t, 2.5)

func _update() -> void:
	var strength: float = envelope()
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"strength", strength)
		material.set_shader_parameter(&"progress", clampf(elapsed / duration, 0.0, 1.0))
	if is_instance_valid(_light):
		_light.light_energy = strength * 3.0

func _process(delta: float) -> void:
	elapsed += delta
	_update()
	if elapsed >= duration:
		queue_free()

func _exit_tree() -> void:
	if _owns_light:
		active_lights = maxi(0, active_lights - 1)
		_owns_light = false
