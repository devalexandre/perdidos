extends Node3D
## Cenário vivo (08/10/2026): o mundo inteiro se mexendo, genérico por bioma (nada só no Campo de Treino).
## Criado em todo mapa pelo Map._ready (só cliente; nunca no servidor nem no headless). Quatro partes:
##  1. Vento nas plantas: árvores, palmeiras e bambus balançam inteiros (tronco firme no pé, copa indo e voltando),
##     além do vento de folha que o env_foliage já tinha. Por NÓ (instance uniform veg_bend/veg_height em
##     env_painted e env_foliage): só ganha quem tem folhagem (superfície env_foliage) ou é árvore seca pelo nome;
##     construção, pedra e chão nunca. Ver apply_plant_wind.
##  2. Sombras de nuvem: o global env_clouds (env_weather.gdshaderinc) faz manchas grandes e macias andarem pelo
##     chão, plantas e paredes. Só em mapa externo com sol, de dia, sem neblina forte; mais nuvem com chuva; desligado
##     no preset Baixa. Publicado só pelo mapa em que o jogador está (cloud_params).
##  3. Partículas de ar perto da câmera, por bioma (BIOMES): pólen/pontinhos de luz de dia, vaga-lumes à noite,
##     folhas caindo na mata/selva, poeira na cidade e nas ruínas, névoa rasteira no brejo. Somem com chuva forte.
##  4. Caverna: gotas pingando com brilho, poeira em volta das luzes, morcegos cruzando ao longe de vez em quando e
##     cristais pulsando (camada aditiva env_crystal_pulse).
## Custo: partículas CPU pequenas (quantidade × foliage_density do EnvQuality, corte em foliage_distance), um tique
## a cada 0,25 s; vento e nuvem são só contas no shader (nuvem desligada em Baixa; morcegos também).

const PARTICLE_SHADER: Shader = preload("res://assets/shaders/env_ambient_particle.gdshader")
const CRYSTAL_PULSE_SHADER: Shader = preload("res://assets/shaders/env_crystal_pulse.gdshader")
const GLOBAL_CLOUDS: StringName = &"env_clouds"
const FOLIAGE_SHADER_FILE: String = "env_foliage.gdshader"

## Tipos de partícula (env_ambient_particle.gdshader).
const K_MIST: int = 0
const K_BAT: int = 7
const K_FIREFLY: int = 2
const K_MOTE: int = 4
const K_LEAF: int = 5
const K_DRIP: int = 6

## Quando cada camada aparece: dia, noite ou sempre.
enum When { DAY, NIGHT, ALWAYS }

## Bioma pelo prefixo do map_id (o primeiro que casar vence). clouds = mapa a céu aberto (sombra de nuvem quando há
## sol). layers = partículas de ar em volta da câmera: kind, cor, quantidade (preset Alta), tamanho do quad (m),
## vida (s), when, altura [mín, máx] (m), e "rain_keep" (fração que fica com chuva forte).
const BIOMES: Array = [
	[["cave_", "hollow_earth", "sumidouro_abyss", "hoer_verde"], {"biome": &"cave", "clouds": false, "cave": true,
		"layers": [
			{"kind": K_MOTE, "color": Color(0.78, 0.86, 0.95, 0.55), "count": 22, "size": 0.2, "life": 9.0,
				"when": When.ALWAYS, "height": [0.4, 3.5], "rain_keep": 1.0},
		]}],
	[["city_of_z", "ruins_ratanaba"], {"biome": &"ruins", "clouds": false, "cave": true,
		"layers": [
			{"kind": K_MOTE, "color": Color(1.0, 0.86, 0.5, 0.6), "count": 24, "size": 0.2, "life": 9.0,
				"when": When.ALWAYS, "height": [0.4, 3.5], "rain_keep": 1.0},
		]}],
	[["jungle_", "enchanted_forest"], {"biome": &"jungle", "clouds": true, "cave": false,
		"layers": [
			{"kind": K_MOTE, "color": Color(0.78, 1.0, 0.45, 0.8), "count": 26, "size": 0.22, "life": 8.0,
				"when": When.DAY, "height": [0.3, 3.0], "rain_keep": 0.0},
			{"kind": K_LEAF, "color": Color(0.46, 0.62, 0.22, 0.95), "count": 12, "size": 0.36, "life": 9.0,
				"when": When.ALWAYS, "height": [3.0, 6.0], "rain_keep": 0.6},
			{"kind": K_FIREFLY, "color": Color(0.72, 1.0, 0.33, 0.9), "count": 26, "size": 0.26, "life": 8.0,
				"when": When.NIGHT, "height": [0.3, 2.4], "rain_keep": 0.0},
		]}],
	[["fog_moor"], {"biome": &"moor", "clouds": true, "cave": false,
		"layers": [
			{"kind": K_MIST, "color": Color(0.80, 0.86, 0.88, 0.22), "count": 16, "size": 7.0, "life": 14.0,
				"when": When.ALWAYS, "height": [0.1, 0.5], "rain_keep": 0.7},
			{"kind": K_MOTE, "color": Color(0.8, 0.95, 0.85, 0.5), "count": 14, "size": 0.2, "life": 9.0,
				"when": When.DAY, "height": [0.3, 2.0], "rain_keep": 0.0},
			{"kind": K_FIREFLY, "color": Color(0.55, 0.95, 0.85, 0.9), "count": 18, "size": 0.26, "life": 8.0,
				"when": When.NIGHT, "height": [0.3, 1.8], "rain_keep": 0.0},
		]}],
	[["city_", "vila_", "town_"], {"biome": &"city", "clouds": true, "cave": false,
		"layers": [
			{"kind": K_MOTE, "color": Color(1.0, 0.92, 0.74, 0.5), "count": 24, "size": 0.18, "life": 9.0,
				"when": When.DAY, "height": [0.3, 3.0], "rain_keep": 0.0},
			{"kind": K_FIREFLY, "color": Color(1.0, 0.82, 0.45, 0.8), "count": 10, "size": 0.22, "life": 8.0,
				"when": When.NIGHT, "height": [0.5, 3.0], "rain_keep": 0.0},
		]}],
	[["elder_trial_arena", "arena_", "interior_", "dungeon_"], {"biome": &"none", "clouds": false, "cave": false,
		"layers": []}],
]
## Campo/cerrado/serra: o padrão de todo mapa externo fora da tabela (training_field, fields_pindorama, split_sky...).
const DEFAULT_PROFILE: Dictionary = {"biome": &"field", "clouds": true, "cave": false,
	"layers": [
		{"kind": K_MOTE, "color": Color(1.0, 0.86, 0.46, 0.85), "count": 30, "size": 0.22, "life": 8.0,
			"when": When.DAY, "height": [0.3, 3.0], "rain_keep": 0.0},
		{"kind": K_FIREFLY, "color": Color(0.78, 1.0, 0.38, 0.9), "count": 26, "size": 0.26, "life": 8.0,
			"when": When.NIGHT, "height": [0.3, 2.2], "rain_keep": 0.0},
	]}

## Caixa (m, meia-largura) em volta do ponto que a câmera olha onde nascem as partículas de ar.
const AIR_BOX: Vector3 = Vector3(11.0, 0.0, 8.0)
const TICK_SEC: float = 0.25
## Nuvem: força no chão (escurece ~30%), cobertura com tempo seco e com chuva forte, deriva (m/s).
const CLOUD_STRENGTH: float = 0.36
const CLOUD_COVER_DRY: float = 0.42
const CLOUD_COVER_RAIN: float = 0.85
const CLOUD_DRIFT: Vector2 = Vector2(1.1, 0.4)
## Neblina (weather_visual.y) acima disto apaga a nuvem por completo.
const CLOUD_MIST_OFF: float = 0.6
## Plantas: abaixo desta altura (m) é capim/arbusto (já tem o vento de folha); acima, balanço inteiro.
const PLANT_MIN_HEIGHT: float = 1.6
const PLANT_MAX_HEIGHT: float = 12.0
## Balanço no topo por metro de altura da planta, por tipo (primeira palavra que casar no nome da malha/nó).
const PLANT_BEND: Array = [
	[["palm", "buriti", "coconut", "coqueiro"], 0.034],
	[["bamboo", "reed", "junco"], 0.045],
	[["deadtree", "dead_tree", "twisted", "seca"], 0.012],
]
const PLANT_BEND_DEFAULT: float = 0.022
## Árvores sem folha (só tronco env_painted) que também balançam: pelo nome.
const LEAFLESS_PLANT_WORDS: Array[String] = ["deadtree", "dead_tree", "twisted"]
## Caverna: gotas (por preset Alta), poeira por luz, máx. de luzes com poeira, morcegos (s entre passagens).
const DRIP_COUNT: int = 8
const LIGHT_DUST_COUNT: int = 8
const LIGHT_DUST_MAX: int = 8
const BAT_EVERY: Vector2 = Vector2(9.0, 22.0)
const BAT_SPEED: float = 6.5

var map_id: StringName = &""
var profile: Dictionary = {}
## Nós de planta que ganharam balanço (para teste/diagnóstico).
var plants: Array[GeometryInstance3D] = []
var crystals: Array[MeshInstance3D] = []

var _layers: Array[CPUParticles3D] = []
var _layer_specs: Array[Dictionary] = []
var _anchor: Node3D = null
var _cave_nodes: Array[CPUParticles3D] = []
var _bats: Array[Dictionary] = []
var _bat_wait: float = 6.0
var _bat_mesh: QuadMesh = null
var _rng := RandomNumberGenerator.new()
var _tick: float = 0.0
var _quality: int = -1
var _night: float = 0.0
var _rain: float = 0.0
var _mist: float = 0.0
var _has_sun: bool = false
var _published: Vector4 = Vector4(-1, -1, -1, -1)
var _camera: Camera3D = null
var _camera_retry: float = 0.0
## Força a publicação do global mesmo sem rede (testes e capturas).
var publish_always: bool = false


## Perfil do mapa pelo prefixo do id (padrão: campo).
static func profile_for(id: StringName) -> Dictionary:
	var s: String = String(id)
	for row: Array in BIOMES:
		for prefix: String in row[0]:
			if s.begins_with(prefix):
				return row[1]
	return DEFAULT_PROFILE


## Parâmetros da sombra de nuvem (global env_clouds): x força, y cobertura, zw deriva. Força 0 = desligado.
static func cloud_params(outdoor: bool, has_sun: bool, night: float, rain: float, mist: float, preset: int) -> Vector4:
	var r: float = clampf(rain, 0.0, 1.0)
	var strength: float = 0.0
	if outdoor and has_sun and preset != EnvQuality.Preset.BAIXA:
		strength = CLOUD_STRENGTH * (1.0 - smoothstep(0.2, 0.75, night)) * (1.0 - smoothstep(0.15, CLOUD_MIST_OFF, mist))
		strength *= 1.0 + r * 0.35
	var cover: float = lerpf(CLOUD_COVER_DRY, CLOUD_COVER_RAIN, r)
	return Vector4(snappedf(strength, 0.005), snappedf(cover, 0.01), CLOUD_DRIFT.x, CLOUD_DRIFT.y)


## Balanço por nó em todas as plantas do mapa. Planta = malha com superfície env_foliage e alta o bastante, ou
## árvore seca pelo nome. Devolve os nós que ganharam balanço.
static func apply_plant_wind(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		var mesh: Mesh = null
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			continue
		var label: String = (mesh.resource_path.get_file() + " " + String(gi.name)).to_lower()
		if not _has_foliage(gi, mesh) and not _has_word(label, LEAFLESS_PLANT_WORDS):
			continue
		var top: float = mesh.get_aabb().end.y * absf(gi.global_transform.basis.get_scale().y) if gi.is_inside_tree() \
				else mesh.get_aabb().end.y * absf(gi.transform.basis.get_scale().y)
		if top < PLANT_MIN_HEIGHT:
			continue
		var height: float = clampf(top, PLANT_MIN_HEIGHT, PLANT_MAX_HEIGHT)
		var per_m: float = PLANT_BEND_DEFAULT
		for row: Array in PLANT_BEND:
			if _has_word(label, row[0]):
				per_m = row[1]
				break
		gi.set_instance_shader_parameter(&"veg_bend", per_m * height)
		gi.set_instance_shader_parameter(&"veg_height", height)
		out.append(gi)
	return out


static func _has_word(label: String, words: Array) -> bool:
	for w: String in words:
		if label.contains(w):
			return true
	return false


static func _has_foliage(gi: GeometryInstance3D, mesh: Mesh) -> bool:
	var mats: Array[Material] = []
	if gi.material_override != null:
		mats.append(gi.material_override)
	for i: int in mesh.get_surface_count():
		var m: Material = null
		if gi is MeshInstance3D:
			m = (gi as MeshInstance3D).get_surface_override_material(i)
		mats.append(m if m != null else mesh.surface_get_material(i))
	for m: Material in mats:
		var sm := m as ShaderMaterial
		if sm != null and sm.shader != null and sm.shader.resource_path.get_file() == FOLIAGE_SHADER_FILE:
			return true
	return false


func _ready() -> void:
	name = &"SceneryLife"
	_rng.seed = hash(String(map_id))
	if profile.is_empty():
		profile = profile_for(map_id)
	var map: Node = get_parent()
	if map != null:
		plants = apply_plant_wind(map)
		_has_sun = not map.find_children("*", "DirectionalLight3D", true, false).is_empty()
	_anchor = Node3D.new()
	_anchor.name = &"AirAnchor"
	add_child(_anchor)
	for spec: Dictionary in profile.get("layers", []):
		var p := _make_air(spec)
		_anchor.add_child(p)
		_layers.append(p)
		_layer_specs.append(spec)
	if bool(profile.get("cave", false)) and map != null:
		_build_cave(map)
	apply_quality()
	_refresh_state()
	update_daylight(_night)
	_publish_clouds()


func _process(delta: float) -> void:
	_step_bats(delta)
	_tick += delta
	if _tick < TICK_SEC:
		return
	_tick = 0.0
	if _quality != EnvQuality.current:
		apply_quality()
	_follow_camera()
	_refresh_state()
	update_daylight(_night)
	_publish_clouds()


## Para os testes: lê clima e noite do mapa sem depender do tique.
func _refresh_state() -> void:
	var map: Node = get_parent()
	if map == null:
		return
	var weather: Vector2 = map.get_meta(&"weather_visual", Vector2.ZERO)
	_rain = clampf(weather.x, 0.0, 1.0)
	_mist = clampf(weather.y, 0.0, 1.0)
	var day_night: Node = get_node_or_null(^"/root/DayNight")
	if day_night != null:
		_night = float(day_night.call(&"night_amount_on_map", map_id))


## Clima e noite vindos de fora (testes); vale no próximo update_daylight.
func set_conditions(night: float, rain: float, mist: float = 0.0) -> void:
	_night = clampf(night, 0.0, 1.0)
	_rain = clampf(rain, 0.0, 1.0)
	_mist = clampf(mist, 0.0, 1.0)


func apply_quality() -> void:
	_quality = EnvQuality.current
	var density: float = EnvQuality.get_setting("foliage_density")
	var distance: float = EnvQuality.get_setting("foliage_distance")
	for i: int in _layers.size():
		_layers[i].amount = maxi(2, roundi(int(_layer_specs[i]["count"]) * density))
		_layers[i].visibility_range_end = distance
	for p: CPUParticles3D in _cave_nodes:
		p.amount = maxi(2, roundi(int(p.get_meta(&"count", 6)) * density))
		p.visibility_range_end = distance
	var pulse: bool = EnvQuality.current != EnvQuality.Preset.BAIXA
	for c: MeshInstance3D in crystals:
		c.material_overlay = c.get_meta(&"pulse_mat") if pulse else null


## Mostra/esconde cada camada pela noite (0..1) e pela chuva.
func update_daylight(night: float) -> void:
	_night = clampf(night, 0.0, 1.0)
	for i: int in _layers.size():
		var spec: Dictionary = _layer_specs[i]
		var opacity: float = 1.0
		match int(spec["when"]):
			When.DAY:
				opacity = 1.0 - smoothstep(0.15, 0.7, _night)
			When.NIGHT:
				opacity = smoothstep(0.25, 0.85, _night)
		opacity *= lerpf(1.0, float(spec.get("rain_keep", 0.0)), smoothstep(0.1, 0.6, _rain))
		var p: CPUParticles3D = _layers[i]
		(p.mesh.material as ShaderMaterial).set_shader_parameter(&"opacity", opacity)
		p.visible = opacity > 0.01
		p.emitting = opacity > 0.01


func layer(kind: int) -> CPUParticles3D:
	for i: int in _layers.size():
		if int(_layer_specs[i]["kind"]) == kind:
			return _layers[i]
	return null


func layer_opacity(kind: int) -> float:
	var p: CPUParticles3D = layer(kind)
	return float((p.mesh.material as ShaderMaterial).get_shader_parameter(&"opacity")) if p != null else -1.0


func current_clouds() -> Vector4:
	return cloud_params(bool(profile.get("clouds", false)), _has_sun, _night, _rain, _mist, EnvQuality.current)


func debug_info() -> Dictionary:
	var states: Array = []
	for i: int in _layers.size():
		states.append([int(_layer_specs[i]["kind"]), _layers[i].emitting, _layers[i].amount,
			snappedf(layer_opacity(int(_layer_specs[i]["kind"])), 0.01)])
	return {"biome": profile.get("biome", &""), "plants": plants.size(), "layers": states,
		"cave": _cave_nodes.size(), "crystals": crystals.size(), "clouds": current_clouds(),
		"anchor": _anchor.global_position.snapped(Vector3.ONE * 0.1) if _anchor.is_inside_tree() else Vector3.ZERO}


func _publish_clouds() -> void:
	if not publish_always and map_id != NetWorld.client_map_id:
		return
	var v: Vector4 = current_clouds()
	if v == _published:
		return
	_published = v
	RenderingServer.global_shader_parameter_set(GLOBAL_CLOUDS, v)


## Leva o ponto de nascimento das partículas para onde a câmera olha (no plano do chão).
func _follow_camera() -> void:
	var cam: Camera3D = _find_camera()
	if cam == null:
		return
	var o: Vector3 = cam.global_position
	var f: Vector3 = -cam.global_basis.z
	var ground: float = global_position.y
	var focus: Vector3 = o + f * 14.0
	if f.y < -0.05:
		focus = o + f * ((ground - o.y) / f.y)
	_anchor.global_position = Vector3(focus.x, ground, focus.z)


## A câmera do jogo vive na SubViewport do ClientView (que divide o World3D com o raiz onde o mapa está), então
## get_viewport() do mapa não a acha: procura uma vez a câmera atual e guarda (nova busca a cada ~2 s se sumir).
func _find_camera() -> Camera3D:
	if is_instance_valid(_camera) and _camera.is_inside_tree() and _camera.current:
		return _camera
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		_camera = cam
		return cam
	_camera_retry -= TICK_SEC
	if _camera_retry > 0.0 or not is_inside_tree():
		return null
	_camera_retry = 2.0
	for n: Node in get_tree().root.find_children("*", "Camera3D", true, false):
		if (n as Camera3D).current:
			_camera = n as Camera3D
			return _camera
	return null


func _make_air(spec: Dictionary) -> CPUParticles3D:
	var kind: int = spec["kind"]
	var h: Array = spec["height"]
	var p := CPUParticles3D.new()
	p.name = "Air%d" % kind
	p.amount = spec["count"]
	p.lifetime = spec["life"]
	p.preprocess = p.lifetime
	p.local_coords = false
	p.randomness = 0.5
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var half_h: float = (float(h[1]) - float(h[0])) * 0.5
	var box := AIR_BOX
	if kind == K_MIST:
		box = AIR_BOX * 1.2
	p.emission_box_extents = Vector3(box.x, half_h, box.z)
	p.position = Vector3(0.0, float(h[0]) + half_h, 0.0)
	match kind:
		K_LEAF:
			p.direction = Vector3(0.6, -1.0, 0.2)
			p.spread = 25.0
			p.gravity = Vector3(0.12, -0.18, 0.04)
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.45
		K_MIST:
			p.direction = Vector3(1.0, 0.0, 0.35)
			p.spread = 20.0
			p.gravity = Vector3.ZERO
			p.initial_velocity_min = 0.15
			p.initial_velocity_max = 0.3
		_:
			p.direction = Vector3(1.0, 0.15, 0.35)
			p.spread = 180.0
			p.gravity = Vector3(0.0, 0.01, 0.0)
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var color: Color = spec["color"]
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0))
	ramp.add_point(0.2, color)
	ramp.add_point(0.75, color)
	ramp.set_color(1, Color(color, 0))
	p.color_ramp = ramp
	var mat := ShaderMaterial.new()
	mat.shader = PARTICLE_SHADER
	mat.set_shader_parameter(&"kind", kind)
	var s: float = spec["size"]
	if kind == K_MIST:
		# névoa rasteira: manchas deitadas no chão (billboard cortaria no piso)
		mat.set_shader_parameter(&"billboard", false)
		var plane := PlaneMesh.new()
		plane.size = Vector2(s, s * 0.7)
		plane.material = mat
		p.mesh = plane
		p.particle_flag_rotate_y = true
		p.angle_min = -180.0
		p.angle_max = 180.0
		return p
	var quad := QuadMesh.new()
	quad.size = Vector2(s, s)
	quad.material = mat
	p.mesh = quad
	return p


# --- caverna -------------------------------------------------------------------------------------------------------

func _build_cave(map: Node) -> void:
	# gotas pingando do teto em volta da câmera (risco claro caindo)
	var drip := CPUParticles3D.new()
	drip.name = &"Drips"
	drip.set_meta(&"count", DRIP_COUNT)
	drip.amount = DRIP_COUNT
	drip.lifetime = 1.1
	drip.local_coords = false
	drip.randomness = 1.0
	drip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drip.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drip.emission_box_extents = Vector3(AIR_BOX.x, 0.3, AIR_BOX.z)
	drip.position = Vector3(0.0, 5.5, 0.0)
	drip.direction = Vector3.DOWN
	drip.spread = 0.0
	drip.gravity = Vector3(0.0, -9.8, 0.0)
	drip.initial_velocity_min = 0.0
	drip.initial_velocity_max = 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.75, 0.9, 1.0, 0.0))
	ramp.add_point(0.15, Color(0.75, 0.9, 1.0, 0.75))
	ramp.add_point(0.9, Color(0.75, 0.9, 1.0, 0.75))
	ramp.set_color(1, Color(0.75, 0.9, 1.0, 0.0))
	drip.color_ramp = ramp
	drip.mesh = _particle_quad(K_DRIP, Vector2(0.08, 0.42))
	_anchor.add_child(drip)
	_cave_nodes.append(drip)
	# poeira flutuando no facho das luzes do mapa (as mais perto do nascimento primeiro)
	var spawn: Node3D = map.get_node_or_null(^"SpawnPoint") as Node3D
	var center: Vector3 = spawn.global_position if spawn != null and spawn.is_inside_tree() else Vector3.ZERO
	var lights: Array = map.find_children("*", "Light3D", true, false).filter(
			func(l: Node) -> bool: return not (l is DirectionalLight3D))
	lights.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return _pos_of(a).distance_to(center) < _pos_of(b).distance_to(center))
	for i: int in mini(lights.size(), LIGHT_DUST_MAX):
		var l: Light3D = lights[i]
		var dust := CPUParticles3D.new()
		dust.name = "LightDust%d" % i
		dust.set_meta(&"count", LIGHT_DUST_COUNT)
		dust.amount = LIGHT_DUST_COUNT
		dust.lifetime = 7.0
		dust.preprocess = 7.0
		dust.local_coords = false
		dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(1.6, 1.4, 1.6)
		dust.direction = Vector3(0.3, 1.0, 0.1)
		dust.spread = 180.0
		dust.gravity = Vector3(0.0, 0.015, 0.0)
		dust.initial_velocity_min = 0.03
		dust.initial_velocity_max = 0.12
		var c: Color = l.light_color.lerp(Color.WHITE, 0.45)
		var dramp := Gradient.new()
		dramp.set_color(0, Color(c, 0.0))
		dramp.add_point(0.25, Color(c, 0.85))
		dramp.add_point(0.7, Color(c, 0.85))
		dramp.set_color(1, Color(c, 0.0))
		dust.color_ramp = dramp
		dust.mesh = _particle_quad(K_MOTE, Vector2(0.2, 0.2))
		dust.position = _pos_of(l) - Vector3(0.0, 1.2, 0.0)
		add_child(dust)
		_cave_nodes.append(dust)
	# cristais pulsando (camada aditiva por cima do material do próprio cristal)
	var mats: Dictionary = {}
	for n: Node in map.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not (mi.mesh.resource_path.get_file().contains("crystal") or String(mi.name).to_lower().contains("crystal")):
			continue
		var used: Material = mi.material_override
		if used == null and mi.mesh.get_surface_count() > 0:
			used = mi.mesh.surface_get_material(0)
		if used is ShaderMaterial:
			continue # cristal com shader próprio (env_crystal) já pulsa
		var col: Color = Color(0.35, 0.8, 1.0)
		var std := used as StandardMaterial3D
		if std != null:
			col = std.emission if std.emission_enabled else std.albedo_color
		var key: String = col.to_html(false)
		if not mats.has(key):
			var pm := ShaderMaterial.new()
			pm.shader = CRYSTAL_PULSE_SHADER
			pm.set_shader_parameter(&"glow_color", col.lerp(Color.WHITE, 0.25))
			mats[key] = pm
		mi.set_meta(&"pulse_mat", mats[key])
		crystals.append(mi)
	_bat_mesh = _particle_quad(K_BAT, Vector2(1.2, 0.7))
	((_bat_mesh.material as ShaderMaterial)).set_shader_parameter(&"opacity", 0.9)


func _pos_of(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position


func _particle_quad(kind: int, size: Vector2) -> QuadMesh:
	var mat := ShaderMaterial.new()
	mat.shader = PARTICLE_SHADER
	mat.set_shader_parameter(&"kind", kind)
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = mat
	return quad


## Morcegos: de tempos em tempos 1–3 cruzam a tela ao longe, no alto, e somem (só caverna; nunca em Baixa).
func _step_bats(delta: float) -> void:
	if _bat_mesh == null:
		return
	for i: int in range(_bats.size() - 1, -1, -1):
		var b: Dictionary = _bats[i]
		b["t"] = float(b["t"]) + delta
		var node: MeshInstance3D = b["node"]
		var t: float = float(b["t"])
		var pos: Vector3 = (b["from"] as Vector3) + (b["vel"] as Vector3) * t
		pos.y += sin(t * 5.0 + float(b["ph"])) * 0.25
		node.position = pos
		if t >= float(b["dur"]):
			node.queue_free()
			_bats.remove_at(i)
	if EnvQuality.current == EnvQuality.Preset.BAIXA:
		return
	_bat_wait -= delta
	if _bat_wait > 0.0:
		return
	_bat_wait = _rng.randf_range(BAT_EVERY.x, BAT_EVERY.y)
	spawn_bats()


## Uma passagem de morcegos atravessando a área da câmera (capturas/testes podem chamar direto).
func spawn_bats(count: int = 0) -> int:
	if _bat_mesh == null:
		return 0
	var n: int = count if count > 0 else _rng.randi_range(1, 3)
	var center: Vector3 = _anchor.position
	var ang: float = _rng.randf() * TAU
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	var side := Vector3(-dir.z, 0.0, dir.x)
	var off: float = _rng.randf_range(4.0, 9.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var span: float = 30.0
	for i: int in n:
		var node := MeshInstance3D.new()
		node.mesh = _bat_mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.name = "Bat%d" % i
		var lag: Vector3 = -dir * float(i) * _rng.randf_range(0.8, 1.6) + side * _rng.randf_range(-0.8, 0.8)
		var from: Vector3 = center - dir * span * 0.5 + side * off + lag + Vector3(0.0, _rng.randf_range(3.5, 5.0), 0.0)
		node.position = from
		add_child(node)
		_bats.append({"node": node, "from": from, "vel": dir * BAT_SPEED * _rng.randf_range(0.9, 1.15), "t": 0.0,
			"dur": span / BAT_SPEED + 1.0, "ph": _rng.randf() * TAU})
	return n


func bat_count() -> int:
	return _bats.size()
