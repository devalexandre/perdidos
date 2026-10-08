extends Node3D
## Ambiente local do Campo de Treino. Criado somente no cliente, sem colisão ou estado de rede.
## Quantidades pequenas e distância por preset; materiais próprios para não alterar recursos do mapa.
## Chuva (08/10/2026): fumaça e brasas rareiam, borboletas e vaga-lumes se escondem; a luz das fogueiras cai pela
## meta &"rain_dim" (DayNightLight aplica) e a chama/brasas pelo uniform global env_rain/env_wetness.

## Fumaça e brasas com chuva forte (fração que sobra) e insetos (somem com a chuva).
const SMOKE_RAIN_KEEP: float = 0.35
const EMBER_RAIN_KEEP: float = 0.25
const CRITTER_RAIN_KEEP: float = 0.0

const WeatherWetness = preload("res://scripts/client/env/weather_wetness.gd")
const PARTICLE_SHADER: Shader = preload("res://assets/shaders/env_ambient_particle.gdshader")
const EFFECTS: Array[Dictionary] = [
	{"name": "CampSmoke", "kind": 0, "pos": Vector3(0, 1.5, -1.5), "count": 12, "life": 5.0},
	{"name": "RanchoSmoke", "kind": 0, "pos": Vector3(-1, 1.0, 39), "count": 10, "life": 5.0},
	{"name": "RanchoEmbers", "kind": 3, "pos": Vector3(-1, 0.8, 39), "count": 10, "life": 2.4},
	{"name": "CampButterflies", "kind": 1, "pos": Vector3(-5, 0.9, 5), "count": 6, "life": 9.0},
	{"name": "EastButterflies", "kind": 1, "pos": Vector3(8, 0.9, 1), "count": 5, "life": 9.0},
	{"name": "RanchoButterflies", "kind": 1, "pos": Vector3(2, 1.0, 43), "count": 6, "life": 9.0},
	{"name": "CampFireflies", "kind": 2, "pos": Vector3(-5, 1.0, 5), "count": 14, "life": 8.0},
	{"name": "EastFireflies", "kind": 2, "pos": Vector3(8, 1.0, 1), "count": 12, "life": 8.0},
]

var _effects: Array[CPUParticles3D] = []
var _quality: int = -1
var _tick: float = 0.0
var _fire_lights: Array[OmniLight3D] = []
var _fires: Array[Node3D] = []
var _rain: float = 0.0
var _damp: float = 0.0


func _ready() -> void:
	_add_fire_details()
	for spec: Dictionary in EFFECTS:
		var p := _make_effect(spec)
		add_child(p)
		_effects.append(p)
	apply_quality()
	update_daylight(DayNight.night_amount_on_map(&"training_field"))


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.25:
		return
	_tick = 0.0
	if _quality != EnvQuality.current:
		apply_quality()
	var map: Node = get_parent()
	if map != null:
		var weather: Vector2 = map.get_meta(&"weather_visual", Vector2.ZERO)
		update_weather(weather.x, float(map.get_meta(WeatherWetness.META_WETNESS, 0.0)))
	update_daylight(DayNight.night_amount_on_map(&"training_field"))


func apply_quality() -> void:
	_quality = EnvQuality.current
	var density: float = EnvQuality.get_setting("foliage_density")
	var distance: float = EnvQuality.get_setting("foliage_distance")
	for fire: Node3D in _fires:
		fire.call(&"apply_quality")
	for light: OmniLight3D in _fire_lights:
		light.shadow_enabled = EnvQuality.current != EnvQuality.Preset.BAIXA
	for i: int in _effects.size():
		var p: CPUParticles3D = _effects[i]
		p.amount = maxi(2, roundi(int(EFFECTS[i]["count"]) * density))
		p.visibility_range_end = distance


func _add_fire_details() -> void:
	var map: Node = get_parent()
	for spec: Array in [["CampFlame", Vector3(0, 0.25, -1.5), 1.0], ["RanchoFlame", Vector3(-1, 0.23, 39), 0.9]]:
		var old: Node3D = map.get_node_or_null("Decor/" + spec[0]) as Node3D
		if old != null:
			old.visible = false
		var fire: Node3D = (load("res://scripts/client/env/campfire_volume.gd") as Script).new()
		fire.name = String(spec[0]) + "Volume"
		fire.position = spec[1]
		fire.scale = Vector3.ONE * float(spec[2])
		add_child(fire)
		_fires.append(fire)
	for path: String in ["Lighting/CampFireLight", "Lighting/RanchoFireLight"]:
		var light: OmniLight3D = map.get_node_or_null(path) as OmniLight3D
		if light != null:
			light.set_meta(&"rain_dim", WeatherWetness.FIRE_LIGHT_RAIN_DIM)
			light.shadow_blur = 1.5
			light.shadow_bias = 0.08
			_fire_lights.append(light)
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/env_ember_bed.gdshader")
	for spec: Array in [[Vector3(0, 0.13, -1.5), 1.0], [Vector3(-1, 0.10, 39), 0.65]]:
		var bed := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.35, 1.35) * float(spec[1])
		plane.material = material
		bed.mesh = plane
		bed.position = spec[0]
		bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bed)


## Chuva agora e umidade do chão (0..1); vale no próximo update_daylight.
func update_weather(rain: float, wetness: float) -> void:
	_rain = clampf(rain, 0.0, 1.0)
	_damp = WeatherWetness.fire_damp(_rain, wetness)


func update_daylight(night: float) -> void:
	for i: int in _effects.size():
		var kind: int = EFFECTS[i]["kind"]
		var opacity: float = 1.0
		if kind == 1:
			opacity = 1.0 - smoothstep(0.15, 0.7, night)
		elif kind == 2:
			opacity = smoothstep(0.25, 0.85, night)
		if kind == 0:
			opacity *= lerpf(1.0, SMOKE_RAIN_KEEP, _damp)
		elif kind == 3:
			opacity *= lerpf(1.0, EMBER_RAIN_KEEP, _damp)
		else:
			opacity *= lerpf(1.0, CRITTER_RAIN_KEEP, smoothstep(0.1, 0.6, _rain))
		(_effects[i].mesh.material as ShaderMaterial).set_shader_parameter(&"opacity", opacity)
		_effects[i].visible = opacity > 0.01
		_effects[i].emitting = opacity > 0.01


func _make_effect(spec: Dictionary) -> CPUParticles3D:
	var kind: int = spec["kind"]
	var p := CPUParticles3D.new()
	p.name = spec["name"]
	p.position = spec["pos"]
	p.amount = spec["count"]
	p.lifetime = spec["life"]
	p.preprocess = p.lifetime
	p.local_coords = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.direction = Vector3(0.35, 1, 0.12) if kind == 0 or kind == 3 else Vector3(1, 0.1, 0.35)
	p.spread = 18.0 if kind == 0 or kind == 3 else 180.0
	p.gravity = Vector3(0.025, 0.04, 0.01) if kind == 0 else Vector3.ZERO
	p.initial_velocity_min = 0.35 if kind == 0 or kind == 3 else 0.08
	p.initial_velocity_max = 0.65 if kind == 0 or kind == 3 else 0.22
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.18, 0.06, 0.18) if kind == 0 or kind == 3 else Vector3(2.8, 0.4, 2.0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.25
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.45 if kind == 0 else 0.8))
	scale_curve.add_point(Vector2(1, 2.2 if kind == 0 else 0.6))
	p.scale_amount_curve = scale_curve
	var color: Color = [Color(0.55, 0.58, 0.62, 0.16), Color(1.0, 0.76, 0.33, 1),
		Color(0.72, 1.0, 0.33, 0.9), Color(1.0, 0.38, 0.08, 0.9)][kind]
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0))
	ramp.add_point(0.18, color)
	ramp.add_point(0.55, color)
	ramp.set_color(1, Color(color, 0))
	p.color_ramp = ramp
	var mat := ShaderMaterial.new()
	mat.shader = PARTICLE_SHADER
	mat.set_shader_parameter(&"kind", kind)
	var quad := QuadMesh.new()
	quad.size = [Vector2(0.7, 0.8), Vector2(0.22, 0.18), Vector2(0.10, 0.10), Vector2(0.045, 0.065)][kind]
	quad.material = mat
	p.mesh = quad
	return p
