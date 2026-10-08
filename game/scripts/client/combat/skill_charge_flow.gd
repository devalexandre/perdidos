extends Node3D
## Energia de preparação contínua: gira, converge e cresce durante o tempo real da conjuração.
## Complementa as folhas do personagem, sem criar quadros duplicados nem alterar o tempo da skill.
const SHADER: Shader = preload("res://assets/shaders/skill_charge_flow.gdshader")
const PARTICLE: Shader = preload("res://assets/shaders/env_ambient_particle.gdshader")

var follow: Node3D = null
var duration: float = 1.0
var color: Color = Color(0.25, 0.65, 1.0)
var elapsed: float = 0.0
var stopping: bool = false
var _fade_left: float = 0.0
var _fade_duration: float = 0.18
var _materials: Array[ShaderMaterial] = []
var _particles: CPUParticles3D = null


func _ready() -> void:
	for flat: bool in [false, true]:
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter(&"color", color)
		material.set_shader_parameter(&"billboard", not flat)
		material.render_priority = 7
		var mesh := MeshInstance3D.new()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if flat:
			var plane := PlaneMesh.new()
			plane.size = Vector2(2.1, 2.1)
			plane.material = material
			mesh.mesh = plane
			mesh.position.y = 0.055
		else:
			var quad := QuadMesh.new()
			quad.size = Vector2(1.9, 1.8)
			quad.material = material
			mesh.mesh = quad
			mesh.position.y = 0.8
		add_child(mesh)
		_materials.append(material)
	_particles = CPUParticles3D.new()
	_particles.amount = 14 if EnvQuality.current == EnvQuality.Preset.ALTA else 8
	_particles.lifetime = 0.8
	_particles.local_coords = true
	_particles.direction = Vector3.UP
	_particles.spread = 12.0
	_particles.gravity = Vector3(0, 0.15, 0)
	_particles.initial_velocity_min = 0.6
	_particles.initial_velocity_max = 1.4
	_particles.radial_accel_min = -1.1
	_particles.radial_accel_max = -0.7
	_particles.tangential_accel_min = 0.3
	_particles.tangential_accel_max = 0.6
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_particles.emission_ring_radius = 0.7
	_particles.emission_ring_inner_radius = 0.45
	_particles.emission_ring_height = 0.05
	_particles.emission_ring_axis = Vector3.UP
	_particles.color = Color(color, 0.6)
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = PARTICLE
	material.set_shader_parameter(&"kind", 3)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.07)
	quad.material = material
	_particles.mesh = quad
	add_child(_particles)
	if is_instance_valid(follow):
		global_position = follow.global_position


func stop(fade_sec: float = 0.18) -> void:
	if stopping:
		return
	stopping = true
	_fade_duration = maxf(0.001, fade_sec)
	_fade_left = _fade_duration
	if _particles != null:
		_particles.emitting = false
		_particles.visible = false


func _process(delta: float) -> void:
	elapsed += delta
	if not is_instance_valid(follow) or not follow.is_inside_tree() or follow.is_queued_for_deletion():
		stop()
	else:
		global_position = follow.global_position
		var dead: bool = (&"hp_ratio" in follow and float(follow.get(&"hp_ratio")) <= 0.0) \
			or (&"hp" in follow and float(follow.get(&"hp")) <= 0.0)
		if dead or elapsed >= duration:
			stop()
	var fade: float = minf(1.0, elapsed / 0.12)
	if stopping:
		_fade_left -= delta
		fade *= clampf(_fade_left / _fade_duration, 0.0, 1.0)
		if _fade_left <= 0.0:
			queue_free()
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"progress", clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0))
		material.set_shader_parameter(&"fade", fade)
