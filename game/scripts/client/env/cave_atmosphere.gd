extends Node3D
## Água e umidade nos nichos; cachoeira que esconde a passagem F4→F5;
## arena quente do Boitatá. Só decoração cliente: não altera navegação nem regras da história.
const WATER = preload("res://assets/shaders/cave_water.gdshader")
const FALL = preload("res://assets/shaders/cave_waterfall.gdshader")
const VEINS = preload("res://assets/shaders/cave_ember_veins.gdshader")
var _detail: Array[GeometryInstance3D] = []
var _particles: Array[CPUParticles3D] = []
var _waterfall_materials: Array[ShaderMaterial] = []
var _lights: Array[OmniLight3D] = []
var _quality: int = -1
var _elapsed: float = 0.0

func _ready() -> void:
	var map := get_parent() as Node3D
	var id: String = str(map.get("map_id"))
	if id == "cave_reino_encoberto_5":
		_build_boss()
	else:
		var index: int = 0
		for anchor: Node in map.find_children("Crystal*", "MeshInstance3D", true, false):
			var p: Vector3 = (anchor as Node3D).position
			_pool(p + Vector3(-0.6, 0.06, 1.0), Vector2(3.4, 2.4), float(index), false)
			_pool(p + Vector3(-0.9, 0.32, 0.9), Vector2(5.0, 3.4), float(index), true)
			index += 1
		if id == "cave_reino_encoberto_4":
			_build_waterfall(Vector3(0, 0, -28))
	# As paredes existentes recebem mais profundidade, sem mudar colisões.
	for n: Node in map.find_children("Rock*", "MeshInstance3D", true, false):
		var wall := n as MeshInstance3D
		wall.scale.y = maxf(wall.scale.y * 1.4, 9.0)
		wall.scale.x *= 1.12
		wall.scale.z *= 1.12
	var we := map.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null:
		we.environment = we.environment.duplicate() as Environment
		we.environment.ssao_enabled = true
		we.environment.ssao_radius = 1.8
		we.environment.ssao_intensity = 1.5
		we.environment.ssao_light_affect = 0.35
		we.environment.glow_enabled = true
		we.environment.glow_intensity = 0.3
		we.environment.glow_hdr_threshold = 1.1
	_refresh_quality()

func _process(delta: float) -> void:
	_elapsed += delta
	if _quality != EnvQuality.current:
		_refresh_quality()
	for i: int in _lights.size():
		_lights[i].light_energy = (1.45 if i == 0 else 0.9) * (0.94 + 0.06 * sin(_elapsed * 1.6 + i * 2.1))
	if not _waterfall_materials.is_empty():
		# Abre a visão da passagem e do jogador quando ele se aproxima da cortina.
		var player: Node3D = NetWorld.client_player as Node3D
		var near: float = 0.0
		if is_instance_valid(player) and player.is_inside_tree():
			near = 1.0 - smoothstep(1.2, 5.0, player.global_position.distance_to(global_position + Vector3(0, 0, -28)))
		for mat: ShaderMaterial in _waterfall_materials:
			mat.set_shader_parameter(&"opacity", 0.82 - near * 0.36)

func _refresh_quality() -> void:
	_quality = EnvQuality.current
	for item: GeometryInstance3D in _detail:
		item.visible = _quality != EnvQuality.Preset.BAIXA
	for p: CPUParticles3D in _particles:
		p.amount = 40 if _quality == EnvQuality.Preset.ALTA else (22 if _quality == EnvQuality.Preset.MEDIA else 10)
	for light: OmniLight3D in _lights:
		light.visible = _quality != EnvQuality.Preset.BAIXA

func _mesh(label: String, mesh: Mesh, material: Material, at: Vector3, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = mesh
	n.material_override = material
	n.position = at
	n.scale = scale_value
	n.visibility_range_end = 75.0
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n

func _pool(at: Vector3, size_value: Vector2, phase: float, mist: bool, impact: bool = false) -> void:
	var plane := PlaneMesh.new()
	plane.size = size_value
	var mat := ShaderMaterial.new()
	mat.shader = WATER
	mat.set_shader_parameter(&"phase", phase)
	mat.set_shader_parameter(&"mist", mist)
	mat.set_shader_parameter(&"impact", impact)
	mat.set_shader_parameter(&"opacity", 0.14 if mist else 0.82)
	mat.render_priority = 2 if mist else 1
	var n := _mesh("GroundMist" if mist else "RipplePool", plane, mat, at)
	if mist:
		_detail.append(n)

func _build_waterfall(at: Vector3) -> void:
	# Três lâminas curvas têm largura, transparência e fases diferentes.
	for i: int in 3:
		var mat := ShaderMaterial.new()
		mat.shader = FALL
		mat.set_shader_parameter(&"phase", float(i) * 2.17)
		mat.render_priority = i + 3
		var strip := _curtain(7.4 - i * 0.6, 9.2 - i * 0.18)
		_mesh("WaterCurtain%d" % i, strip, mat, at + Vector3(0, 0, float(i) * 0.26))
		_waterfall_materials.append(mat)
	_pool(at + Vector3(0, 0.08, 1.1), Vector2(10.4, 6.2), 0.0, false, true)
	_pool(at + Vector3(0, 0.55, 0.8), Vector2(10.0, 5.0), 2.0, true)
	_spray(at + Vector3(0, 0.35, 0.6))
	var rock: Mesh = load("res://assets/environment/painted/meshes/rock_moss_a.res")
	var stone: Material = load("res://assets/environment/painted/materials/mat_rock_moss.tres")
	# Contrafortes do fundo: passagem central livre, ombreiras e cornija rochosas.
	for side: float in [-1.0, 1.0]:
		for i: int in 4:
			var n := _mesh("FallCliff", rock, stone, at + Vector3(side * (4.4 + i * 1.1), -0.3, -2.4 - i * 0.6), Vector3(3.0, 12.0 + i * 1.8, 3.6))
			n.rotation.y = side * float(i) * 0.47
	for i: int in 5:
		_mesh("FallCrown", rock, stone, at + Vector3((i - 2) * 1.8, 8.3, -1.2), Vector3(2.0, 2.1 + sin(float(i)) * 0.4, 2.3))
	# Pedra molhada ao redor da bacia, com uma abertura frontal para atravessar a água.
	for i: int in 11:
		var a: float = PI + float(i) / 10.0 * PI
		_mesh("BasinStone", rock, stone, at + Vector3(cos(a) * 5.2, -0.15, 1.1 + sin(a) * 2.7), Vector3(0.75, 0.65, 0.65))
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.018, 0.035, 0.039)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var door := QuadMesh.new()
	door.size = Vector2(3.4, 3.8)
	_mesh("HiddenTunnel", door, dark, at + Vector3(0, 1.9, -2.6))
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0, 3.0, 1.8)
	glow.light_color = Color(0.20, 0.59, 0.66)
	glow.light_energy = 1.45
	glow.omni_range = 12.0
	glow.shadow_enabled = false
	add_child(glow)
	_lights.append(glow)
	var audio := AudioStreamPlayer3D.new()
	audio.name = &"WaterfallSound"
	var stream := (load("res://assets/audio/ambience/amb_cave_waterfall.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	audio.stream = stream
	audio.bus = AudioDirector.BUS_AMBIENCE
	audio.position = at + Vector3(0, 2, 0)
	audio.unit_size = 5.0
	audio.max_distance = 32.0
	audio.volume_db = -11.0
	add_child(audio)
	audio.play()

func _curtain(width: float, height: float) -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y: int in 14:
		for x: int in 16:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var u: float = float(x + corner.x) / 16.0
				var v: float = float(y + corner.y) / 14.0
				s.set_uv(Vector2(u, v))
				s.set_normal(Vector3.FORWARD)
				s.add_vertex(Vector3((u - 0.5) * width, (1.0 - v) * height, sin(u * PI) * 0.28))
	return s.commit()

func _spray(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = &"WaterfallSpray"
	p.amount = 40
	p.lifetime = 1.8
	p.preprocess = 1.8
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(3.1, 0.1, 0.7)
	p.direction = Vector3.UP
	p.spread = 34.0
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -1.0, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.80, 0.85, 0))
	ramp.add_point(0.2, Color(0.55, 0.80, 0.85, 0.34))
	ramp.set_color(1, Color(0.55, 0.80, 0.85, 0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.24)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/env_ambient_particle.gdshader")
	mat.set_shader_parameter(&"kind", 0)
	quad.material = mat
	p.mesh = quad
	add_child(p)
	_particles.append(p)

func _build_boss() -> void:
	var rock: Mesh = load("res://assets/environment/painted/meshes/rock_moss_a.res")
	var stone: Material = load("res://assets/environment/painted/materials/mat_rock.tres")
	# Silhueta monumental na borda norte, sem cobrir o espaço de combate.
	for i: int in 17:
		var angle: float = PI + float(i) / 16.0 * PI
		var at := Vector3(cos(angle) * 22.8, -0.5, -14.0 + sin(angle) * 22.8)
		var n := _mesh("BasaltRidge%d" % i, rock, stone, at, Vector3(4.0, 12.0 + sin(float(i) * 2.1) * 3.0, 3.5))
		n.rotation.y = float(i) * 1.73
	# Troca apenas a aparência dos pilares cilíndricos; as colisões e os desvios permanecem.
	for p: Node in get_parent().get_children():
		if String(p.name).begins_with("pillar_"):
			for child: Node in p.get_children():
				if child is MeshInstance3D:
					(child as MeshInstance3D).visible = false
			var pos: Vector3 = (p as Node3D).position
			pos.y = -0.3
			var column := _mesh("BasaltColumn", rock, stone, pos, Vector3(2.2, 8.5, 2.2))
			column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var ground: Material = load("res://assets/environment/painted/materials/mat_ground_gravel.tres")
	for surface: Node in get_parent().find_children("Surface", "MeshInstance3D", true, false):
		(surface as MeshInstance3D).material_override = ground
	var arena := PlaneMesh.new()
	arena.size = Vector2(29.0, 29.0)
	var mat := ShaderMaterial.new()
	mat.shader = VEINS
	_mesh("BreathingArena", arena, mat, Vector3(0, 0.035, -16))
	for side: float in [-1.0, 1.0]:
		_embers(Vector3(side * 16.5, 0.5, -17.0))
		_pool(Vector3(side * 18.0, 0.065, -15.0), Vector2(4.0, 9.0), side * 2.0, false)
		_pool(Vector3(side * 18.0, 0.3, -15.0), Vector2(6.0, 12.0), side * 2.0, true)
		for i: int in 4:
			var crystal: Mesh = load("res://assets/environment/painted/meshes/crystal_cluster.res")
			var amber := StandardMaterial3D.new()
			amber.albedo_color = Color(0.17, 0.10, 0.065)
			amber.emission_enabled = true
			amber.emission = Color(0.45, 0.12, 0.022)
			amber.emission_energy_multiplier = 0.22
			amber.roughness = 0.28
			amber.metallic = 0.25
			_mesh("EmberCrystals", crystal, amber, Vector3(side * (19.3 + i * 0.6), 0, -9.0 - i * 4.1), Vector3(0.7, 0.9 + i * 0.15, 0.7))
		var glow := OmniLight3D.new()
		glow.position = Vector3(side * 12.0, 3.5, -18)
		glow.light_color = Color(1.0, 0.34, 0.09)
		glow.light_energy = 0.9
		glow.omni_range = 18.0
		glow.shadow_enabled = false
		add_child(glow)
		_lights.append(glow)
	var env := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env != null:
		env.environment = env.environment.duplicate() as Environment
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.008, 0.012, 0.02)
		env.environment.ambient_light_color = Color(0.34, 0.43, 0.56)
		env.environment.ambient_light_energy = 0.55
		env.environment.fog_light_color = Color(0.024, 0.039, 0.06)
		env.environment.fog_density = 0.002
	var sun := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(0.55, 0.65, 0.75)
		sun.light_energy = 0.3

func _embers(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = &"ArenaEmbers"
	p.amount = 40
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.4, 0.1, 4.0)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.65
	p.gravity = Vector3(0.02, 0.06, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.45, 0.08, 0))
	ramp.add_point(0.15, Color(1.0, 0.45, 0.08, 0.65))
	ramp.set_color(1, Color(0.9, 0.21, 0.04, 0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.16)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/env_ambient_particle.gdshader")
	mat.set_shader_parameter(&"kind", 3)
	quad.material = mat
	p.mesh = quad
	add_child(p)
	_particles.append(p)
