extends Node3D
## Camadas originais de contato: ondas fragmentadas, estilhaços volumosos e dissipação.
## Só apresentação: não cria colisão, área de dano ou estado de rede.
const PULSE: Shader = preload("res://assets/shaders/spell_impact_pulse.gdshader")
const PARTICLE: Shader = preload("res://assets/shaders/env_ambient_particle.gdshader")
const FLAME: Shader = preload("res://assets/shaders/spell_flame.gdshader")
const DURATION: Dictionary = {&"arcane": 0.75, &"electric": 0.48, &"fire": 1.05, &"ice": 0.95, &"nature": 1.2}
var color: Color = Color(0.2, 0.6, 1.0)
var style: StringName = &"arcane"
var radius: float = 1.4
var duration: float = 0.85
var elapsed: float = 0.0
var cone: bool = false
var cone_half_angle: float = deg_to_rad(30.0)
var wave: bool = false
var persistent: bool = false
var follow: Node3D
var _materials: Array[ShaderMaterial] = []
var _shards: Array[MeshInstance3D] = []
var _particles: CPUParticles3D
var _plumes: Array[MeshInstance3D] = []

func _ready() -> void:
	if not persistent and not wave:
		duration = DURATION.get(style, 0.85)
	for i: int in 2:
		var material := ShaderMaterial.new()
		material.shader = PULSE
		material.set_shader_parameter(&"color", color)
		material.set_shader_parameter(&"phase", i * 1.7)
		material.set_shader_parameter(&"healing", style == &"nature")
		material.set_shader_parameter(&"cone", cone)
		material.set_shader_parameter(&"cone_width", tan(cone_half_angle))
		material.set_shader_parameter(&"element", {&"arcane": 0, &"electric": 1, &"fire": 2, &"ice": 3, &"nature": 4}.get(style, 0))
		material.render_priority = 4 + i
		var ring := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * radius * 2.4 * (1.0 if i == 0 else 0.80)
		plane.material = material
		ring.mesh = plane
		ring.position.y = 0.06 + i * 0.015
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_materials.append(material)
	if style == &"ice":
		_make_shards()
	elif style == &"fire":
		_make_plumes()
	_make_particles()

func _make_plumes() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y: int in 5:
		for side: int in 8:
			for corner: Vector2i in [Vector2i(side, y), Vector2i(side, y + 1), Vector2i(side + 1, y), Vector2i(side + 1, y), Vector2i(side, y + 1), Vector2i(side + 1, y + 1)]:
				var t: float = float(corner.y) / 5.0
				var angle: float = TAU * corner.x / 8.0
				var width: float = (1.0 - t) * (0.24 + sin(t * PI) * 0.2)
				tool.set_uv(Vector2(float(corner.x) / 8.0, t))
				tool.add_vertex(Vector3(cos(angle) * width, t, sin(angle) * width))
	tool.generate_normals()
	var mesh: ArrayMesh = tool.commit()
	for i: int in (3 if EnvQuality.current == EnvQuality.Preset.ALTA else 2):
		var plume := MeshInstance3D.new()
		plume.mesh = mesh
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plume.custom_aabb = AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
		var material := ShaderMaterial.new()
		material.shader = FLAME
		material.set_shader_parameter(&"color", color)
		material.set_shader_parameter(&"phase", i * 2.3)
		plume.material_override = material
		add_child(plume)
		_plumes.append(plume)

func _make_shards() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lerp(Color(0.7, 0.95, 1.0), 0.35)
	material.roughness = 0.25
	material.metallic = 0.2
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.18
	var mesh: ArrayMesh = _crystal_mesh()
	mesh.surface_set_material(0, material)
	var count: int = (12 if wave else 8) if EnvQuality.current == EnvQuality.Preset.ALTA else (7 if wave else 5)
	for i: int in count:
		var shard := MeshInstance3D.new()
		shard.mesh = mesh
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle: float = TAU * i / count + 0.21
		if cone:
			var spread: float = lerpf(-cone_half_angle * 0.82, cone_half_angle * 0.82, float(i % 3) / 2.0)
			shard.position = Vector3(sin(spread), 0, -cos(spread)) * radius * (0.22 + float(i) / count * 0.70)
		else:
			shard.position = Vector3(cos(angle), 0.0, sin(angle)) * radius * (0.9 if persistent else 0.62)
		shard.rotation = Vector3(cos(angle) * 0.16, angle, sin(angle) * 0.16)
		if wave:
			shard.scale = Vector3(1.3 + (i % 3) * 0.3, 1.0, 1.3 + (i % 3) * 0.3)
		shard.scale.y = 0.001
		add_child(shard)
		_shards.append(shard)

static func _crystal_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 5:
		var a: float = TAU * i / 5.0
		var b: float = TAU * (i + 1) / 5.0
		var low_a := Vector3(cos(a) * 0.07, 0.0, sin(a) * 0.07)
		var low_b := Vector3(cos(b) * 0.07, 0.0, sin(b) * 0.07)
		var wide_a := Vector3(cos(a) * 0.18, 0.45, sin(a) * 0.18)
		var wide_b := Vector3(cos(b) * 0.18, 0.45, sin(b) * 0.18)
		for vertex: Vector3 in [low_a, wide_a, low_b, low_b, wide_a, wide_b, wide_a, Vector3.UP, wide_b]:
			tool.set_smooth_group(-1)
			tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()

func _make_particles() -> void:
	_particles = CPUParticles3D.new()
	_particles.amount = 14 if EnvQuality.current == EnvQuality.Preset.ALTA else 6
	_particles.one_shot = true
	_particles.explosiveness = 0.05 if style == &"nature" else (0.6 if style == &"fire" else 0.90)
	_particles.randomness = 0.25
	_particles.lifetime = 0.6 if style == &"nature" else (0.35 if style == &"electric" else 0.65)
	_particles.local_coords = true
	_particles.position.y = 0.15
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = radius * 0.25
	_particles.direction = Vector3.UP
	_particles.spread = 65.0 if style != &"nature" else 22.0
	_particles.initial_velocity_min = 0.25 if style == &"nature" else 0.6
	_particles.initial_velocity_max = 0.65 if style == &"nature" else (2.8 if style == &"electric" else 1.4)
	_particles.gravity = Vector3(0, -1.5 if style == &"ice" else (0.9 if style == &"fire" else 0.1), 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.add_point(0.1, Color(color, 0.9))
	ramp.add_point(0.4, Color(color, 0.7))
	ramp.set_color(1, Color(color, 0.0))
	_particles.color_ramp = ramp
	var material := ShaderMaterial.new()
	material.shader = PARTICLE
	material.set_shader_parameter(&"kind", 3)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.09)
	quad.material = material
	_particles.mesh = quad
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)

func _process(delta: float) -> void:
	elapsed += delta
	if persistent:
		if not is_instance_valid(follow):
			queue_free()
			return
		if not follow.is_inside_tree() or follow.is_queued_for_deletion() or (&"hp_ratio" in follow and float(follow.get(&"hp_ratio")) <= 0.0):
			queue_free()
			return
	for i: int in _materials.size():
		_materials[i].set_shader_parameter(&"progress", clampf((elapsed - i * 0.07) / (0.85 if persistent else duration), 0.0, 1.0))
	for i: int in _plumes.size():
		var plume: MeshInstance3D = _plumes[i]
		var fade: float = smoothstep(0.0, 0.06, elapsed) * (1.0 - smoothstep(duration * 0.35, duration, elapsed))
		plume.position = Vector3(cos(i * 2.3 + elapsed * 1.4), 0, sin(i * 2.3 + elapsed * 1.4)) * radius * 0.18
		plume.scale = Vector3(1.0, (1.1 + i * 0.23) * fade, 1.0)
		var material: ShaderMaterial = plume.material_override
		material.set_shader_parameter(&"age", elapsed)
		material.set_shader_parameter(&"opacity", fade)
	for i: int in _shards.size():
		var delay: float = _shards[i].position.length() / 16.0 if wave else (i if persistent else i % 4) * 0.035
		var local_time: float = maxf(0.0, elapsed - delay)
		var emerge: float = smoothstep(0.0, 0.20, local_time)
		var sink: float = 1.0 - smoothstep(maxf(0.3, duration - 0.4) if persistent else duration * 0.55, duration, elapsed if wave else local_time)
		var height: float = emerge * sink * ((1.3 + (i % 3) * 0.24) if persistent else ((1.2 + (i % 4) * 0.26) if wave else (0.65 + (i % 3) * 0.17)))
		_shards[i].scale.y = maxf(0.001, height)
		# A malha nasce em y=0; sua base permanece no chão enquanto cresce.
		_shards[i].position.y = -(1.0 - sink) * 0.15
	if elapsed >= duration + (0.35 if persistent else 0.18):
		queue_free()
