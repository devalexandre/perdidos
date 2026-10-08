extends Node3D
## Sinais de gente morando ali (08/10/2026): perto de barracas, ranchos, cabanas e portas de casa de QUALQUER mapa
## (achados pelo AmbientScan) espalha por regra roupa no varal balançando ao vento (shader env_banner), lenha
## empilhada, balde, ferramentas encostadas, esteira na porta, pegadas na terra e lanterna na entrada (acesa à noite);
## perto de fogueiras, panela, caneca e tora de sentar. Semente fixa por mapa (todos veem igual), sem colisão (não
## mexe na navegação) e evitando trilhas, portais, NPCs e o ponto de nascimento. Peças do kit (KitCatalog.MESH_DIR,
## CC0, ver assets/environment/LICENSES.md) + primitivas simples para varal, cabos e esteira.
## Custo: visibility_range pelo EnvQuality; BAIXA/mobile = só o essencial (sem pegadas, varal e luzes).

const AmbientScan = preload("res://scripts/client/env/ambient_scan.gd")
const KIT_DIR: String = "res://assets/environment/painted/meshes/"
const BANNER_SHADER: String = "res://assets/shaders/env_banner.gdshader"
const FIRE_GROUP: StringName = &"env_fire_spot"

## Ajustes por mapa: rich = mais coisa por barraca (o Campo de Treino é o primeiro caprichado);
## max = moradias decoradas no preset ALTA.
const MAP_EXTRAS: Dictionary = {
	&"training_field": {"rich": true, "max": 24},
	&"fields_pindorama": {"rich": true, "max": 12},
}
const DEFAULT_EXTRAS: Dictionary = {"rich": false, "max": 16}
## Luzes de lanterna simultâneas por preset (ALTA, MÉDIA, BAIXA).
const LIGHTS_BY_QUALITY: Array[int] = [6, 3, 0]
const DWELLINGS_BY_QUALITY: Array[float] = [1.0, 0.6, 0.35]
const MIN_GAP_M: float = 0.55
const FIRE_GAP_M: float = 1.15
const LANTERN_COLOR: Color = Color(1.0, 0.72, 0.38)
const CLOTH_COLORS: Array[Color] = [Color8(214, 92, 72), Color8(236, 226, 196), Color8(86, 140, 196),
	Color8(232, 186, 74), Color8(122, 168, 98), Color8(196, 120, 168)]
const WOOD: Color = Color8(118, 82, 52)
const WOOD_DARK: Color = Color8(78, 54, 36)
const STRAW: Color = Color8(206, 172, 104)

var map_id: StringName = &""
var scan_result = null
## Contagem por tipo do que foi colocado (testes e relatório).
var placed: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _taken: Array[Vector3] = []
var _lights: Array[OmniLight3D] = []
var _geoms: Array[GeometryInstance3D] = []
var _mesh_cache: Dictionary = {}
var _mat_cache: Dictionary = {}
var _quality: int = -1
var _tick: float = 0.0
var _night: float = -1.0
var _built: bool = false
## Porta de casa em rua calçada: as peças ficam coladas na parede, então a calçada não conta como trilha.
var _avoid_trails: bool = true


func _ready() -> void:
	name = &"CampDressing"
	top_level = true
	var map: Node = get_parent()
	if map_id.is_empty() and map != null and &"map_id" in map:
		map_id = map.get(&"map_id")
	if is_inside_tree():
		await get_tree().physics_frame
	build()


## Monta tudo (uma vez). Testes chamam direto.
func build(result = null) -> void:
	if _built:
		return
	_built = true
	scan_result = result if result != null else AmbientScan.scan(get_parent() as Node3D)
	var extras: Dictionary = MAP_EXTRAS.get(map_id, DEFAULT_EXTRAS)
	var q: int = _preset()
	var cap: int = maxi(1, roundi(int(extras["max"]) * DWELLINGS_BY_QUALITY[q]))
	_rng.seed = hash("camp:" + String(map_id))
	# fogueiras primeiro (panela, caneca, tora), depois as moradias
	for i: int in scan_result.fires.size():
		# ponto da fogueira para os NPCs "mexerem no fogo" (NpcGestures)
		var spot := Marker3D.new()
		spot.name = "FireSpot%d" % i
		spot.position = scan_result.fires[i]
		spot.add_to_group(FIRE_GROUP)
		add_child(spot)
		_rng.seed = hash("fire:%s:%d" % [map_id, i])
		_dress_fire(scan_result.fires[i], q)
	# as moradias mais perto do ponto de nascimento primeiro (as que todo mundo vê); ordem fixa = mesma semente
	var order: Array = range(scan_result.dwellings.size())
	var spawn: Vector3 = _spawn_point()
	order.sort_custom(func(a: int, b: int) -> bool:
		var da: float = (scan_result.dwellings[a]["pos"] as Vector3).distance_to(spawn)
		var db: float = (scan_result.dwellings[b]["pos"] as Vector3).distance_to(spawn)
		return da < db if not is_equal_approx(da, db) else a < b)
	var n: int = 0
	for i: int in order:
		if n >= cap:
			break
		var d: Dictionary = scan_result.dwellings[i]
		_rng.seed = hash("home:%s:%d" % [map_id, i])
		if d["kind"] == &"door":
			_avoid_trails = false
			_dress_door(d, q)
			_avoid_trails = true
		else:
			_dress_tent(d, q, bool(extras["rich"]))
		n += 1
	apply_quality()
	update_daylight(DayNight.night_amount_on_map(map_id) if DayNight != null else 0.0)


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0.0
	if _quality != EnvQuality.current:
		apply_quality()
	update_daylight(DayNight.night_amount_on_map(map_id))


func apply_quality() -> void:
	_quality = EnvQuality.current
	var distance: float = EnvQuality.get_setting("foliage_distance")
	for g: GeometryInstance3D in _geoms:
		if is_instance_valid(g):
			g.visibility_range_end = distance
	for i: int in _lights.size():
		_lights[i].set_meta(&"allowed", i < LIGHTS_BY_QUALITY[_preset()])
	_night = -1.0


## Lanternas acendem ao anoitecer.
func update_daylight(night: float) -> void:
	if absf(night - _night) < 0.01:
		return
	_night = night
	var on: float = smoothstep(0.2, 0.55, night)
	for l: OmniLight3D in _lights:
		l.visible = on > 0.01 and bool(l.get_meta(&"allowed", true))
		l.light_energy = 2.2 * on


func count(kind: StringName) -> int:
	return int(placed.get(kind, 0))


func lights() -> Array[OmniLight3D]:
	return _lights


# --- regras por lugar -----------------------------------------------------------------------------

func _dress_fire(c: Vector3, q: int) -> void:
	var a: float = _rng.randf() * TAU
	# panela e caneca junto das pedras, tora de sentar mais longe
	_try_kit(&"pot", "pk_pot_1", c + _dir(a) * 1.25, _rng.randf() * TAU, 0.9, true)
	_try_kit(&"mug", "pk_vase_4", c + _dir(a + 0.55) * 1.3, 0.0, 0.32, true)
	if q < 2:
		_try_kit(&"seat_log", "prop_log", c + _dir(a + PI * 0.75) * 2.1, a + PI * 0.75 + PI * 0.5, 0.55, true)
	_try_firewood(c + _dir(a - PI * 0.6) * 2.3, a)


func _dress_tent(d: Dictionary, q: int, rich: bool) -> void:
	var c: Vector3 = d["pos"]
	var fwd: Vector3 = d["fwd"]
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var half: Vector2 = d["half"]
	var door: Vector3 = c + fwd * (half.y + 0.25)
	var yaw: float = atan2(fwd.x, fwd.z)
	var s: float = 1.0 if _rng.randf() < 0.5 else -1.0
	# esteira na porta e pegadas saindo dela
	_try_mat(door + fwd * 0.35, yaw)
	if q < 2:
		_try_footprints(door + fwd * 1.2, fwd)
	# lanterna na entrada (acesa à noite)
	if _rng.randf() < (0.8 if rich else 0.5):
		_try_lantern(door + side * s * (half.x * 0.55 + 0.3), yaw + PI * 0.5 * s)
	# lenha empilhada do lado, balde, ferramenta encostada
	_try_firewood(c + side * -s * (half.x + 0.6) + fwd * _rng.randf_range(-0.5, 0.8), yaw + PI * 0.5)
	if _rng.randf() < (0.85 if rich else 0.55):
		_try_kit(&"bucket", "pk_bucket_wooden_1", door + side * -s * (half.x * 0.6 + 0.2) + fwd * 0.2,
				_rng.randf() * TAU, 1.0, true)
	if _rng.randf() < (0.75 if rich else 0.45):
		_try_tool(c + side * s * (half.x + 0.12) - fwd * _rng.randf_range(0.0, 0.9), side * -s)
	if q < 2 and _rng.randf() < (0.7 if rich else 0.35):
		_try_clothesline(c - fwd * (half.y + 1.4) + side * _rng.randf_range(-0.8, 0.8), side)
	if rich and _rng.randf() < 0.5:
		_try_kit(&"sack", "pk_bag", c + side * s * (half.x + 0.5) + fwd * 0.9, _rng.randf() * TAU, 0.85, true)


func _dress_door(d: Dictionary, q: int) -> void:
	var door: Vector3 = d["pos"]
	var fwd: Vector3 = d["fwd"]
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var yaw: float = atan2(fwd.x, fwd.z)
	var s: float = 1.0 if _rng.randf() < 0.5 else -1.0
	_try_mat(door + fwd * 0.5, yaw)
	if _rng.randf() < 0.6:
		_try_lantern(door + side * s * 0.95 + fwd * 0.35, yaw, true)
	if _rng.randf() < 0.55:
		_try_kit(&"bucket", "pk_bucket_wooden_1", door + side * -s * 1.2 + fwd * 0.45, _rng.randf() * TAU, 1.0, true)
	if _rng.randf() < 0.35:
		_try_firewood(door + side * -s * 2.0 + fwd * 0.5, yaw + PI * 0.5)
	if _rng.randf() < 0.3:
		_try_tool(door + side * s * 1.6 + fwd * 0.12, -fwd)
	if q < 2 and _rng.randf() < 0.3:
		_try_footprints(door + fwd * 1.4, fwd)


# --- peças ----------------------------------------------------------------------------------------

## Lugar livre? (chão achado, fora de trilha/portal/NPC/nascimento, longe das outras peças e do fogo)
func _free_spot(p: Vector3, gap: float = MIN_GAP_M, near_fire_ok: bool = false, avoid_trails: bool = true) -> Variant:
	if AmbientScan.is_blocked(scan_result, p, 0.2, avoid_trails and _avoid_trails):
		return null
	for t: Vector3 in _taken:
		if Vector2(t.x - p.x, t.z - p.z).length() < gap:
			return null
	if not near_fire_ok:
		for f: Vector3 in scan_result.fires:
			if Vector2(f.x - p.x, f.z - p.z).length() < FIRE_GAP_M + 0.6:
				return null
	var g: Variant = AmbientScan.ground_at(get_parent() as Node3D, p, 1.5, 3.0)
	if g == null:
		# sem física (testes sem mapa carregado): fica no y pedido
		if get_parent() == null or not (get_parent() as Node3D).is_inside_tree():
			return p
		return null
	if absf((g as Vector3).y - p.y) > 1.2:
		return null
	return g


func _take(kind: StringName, p: Vector3) -> void:
	_taken.append(p)
	placed[kind] = int(placed.get(kind, 0)) + 1


func _try_kit(kind: StringName, mesh_name: String, p: Vector3, yaw: float, scale: float, fire_ok: bool = false) -> Node3D:
	var g: Variant = _free_spot(p, MIN_GAP_M, fire_ok)
	if g == null:
		return null
	var mesh: Mesh = _kit_mesh(mesh_name)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = String(kind).capitalize().replace(" ", "") + str(count(kind))
	mi.mesh = mesh
	mi.position = g
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * scale
	_add_geom(mi)
	_take(kind, g)
	return mi


## Lenha: 3 toras deitadas + 2 em cima, cruzadas (prop_log do kit, encolhido).
func _try_firewood(p: Vector3, yaw: float) -> void:
	var g: Variant = _free_spot(p, 0.8)
	if g == null:
		return
	var mesh: Mesh = _kit_mesh("prop_log")
	if mesh == null:
		return
	var root := Node3D.new()
	root.name = "Firewood%d" % count(&"firewood")
	root.position = g
	root.rotation.y = yaw
	add_child(root)
	var k: float = 0.32
	for i: int in 5:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var row: int = 0 if i < 3 else 1
		var col: float = (i if row == 0 else i - 3) - (1.0 if row == 0 else 0.5)
		mi.position = Vector3(_rng.randf_range(-0.05, 0.05), row * 0.13, col * 0.15)
		mi.rotation.y = _rng.randf_range(-0.08, 0.08)
		mi.scale = Vector3(k, 0.28, 0.32)
		_add_geom(mi, root)
	_take(&"firewood", g)


func _try_mat(p: Vector3, yaw: float) -> void:
	var g: Variant = _free_spot(p, 0.4, false, false)
	if g == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Mat%d" % count(&"mat")
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 0.025, 0.7)
	box.material = _stripes_mat(&"mat", STRAW, Color8(160, 96, 60))
	mi.mesh = box
	mi.position = (g as Vector3) + Vector3.UP * 0.015
	mi.rotation.y = yaw + PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_geom(mi)
	_take(&"mat", g)


## Pegadas na terra: decal com pares de pés indo e vindo da porta.
func _try_footprints(p: Vector3, fwd: Vector3) -> void:
	var g: Variant = _free_spot(p, 0.3, false, false)
	if g == null:
		return
	var decal := Decal.new()
	decal.name = "Footprints%d" % count(&"footprints")
	decal.size = Vector3(0.8, 0.6, 2.2)
	decal.texture_albedo = _footprint_tex()
	decal.modulate = Color(0.26, 0.17, 0.1, 0.8)
	decal.position = g
	decal.rotation.y = atan2(fwd.x, fwd.z)
	decal.cull_mask = 1
	decal.upper_fade = 0.2
	decal.lower_fade = 0.2
	add_child(decal)
	_take(&"footprints", g)


## Lanterna: no poste do acampamento (camp_lantern) ou na parede da casa (pk_lantern_wall).
func _try_lantern(p: Vector3, yaw: float, wall: bool = false) -> void:
	var g: Variant = _free_spot(p, 0.6)
	if g == null:
		return
	var mesh: Mesh = _kit_mesh("pk_lantern_wall" if wall else "camp_lantern")
	if mesh == null:
		return
	var root := Node3D.new()
	root.name = "Lantern%d" % count(&"lantern")
	root.position = g
	root.rotation.y = yaw
	add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if wall:
		mi.position = Vector3(0, 0.9, 0)
		mi.rotation.y = PI
	else:
		mi.scale = Vector3.ONE * 0.8
	_add_geom(mi, root)
	# ponto da chama: na ponta do braço do poste (camp_lantern, 0,8×) ou na frente da arandela
	var lamp: Vector3 = Vector3(0.0, 1.6, -0.25) if wall else Vector3(0.52, 1.3, 0.0)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = LANTERN_COLOR
	light.omni_range = 5.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.position = lamp
	light.visible = false
	root.add_child(light)
	_lights.append(light)
	_take(&"lantern", g)


## Ferramenta encostada (enxada ou vassoura de palha): cabo inclinado apoiado em lean_to.
func _try_tool(p: Vector3, lean_to: Vector3) -> void:
	var g: Variant = _free_spot(p, 0.45)
	if g == null:
		return
	var root := Node3D.new()
	root.name = "Tool%d" % count(&"tool")
	root.position = g
	root.basis = Basis(Vector3.UP, atan2(lean_to.x, lean_to.z)) * Basis(Vector3.RIGHT, deg_to_rad(16.0))
	add_child(root)
	var handle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.03
	cyl.height = 1.35
	cyl.radial_segments = 6
	cyl.rings = 1
	cyl.material = _flat_mat(&"wood", WOOD)
	handle.mesh = cyl
	handle.position = Vector3(0, 0.675, 0)
	_add_geom(handle, root)
	var head := MeshInstance3D.new()
	if _rng.randf() < 0.5:
		var blade := BoxMesh.new() # enxada
		blade.size = Vector3(0.22, 0.16, 0.03)
		blade.material = _flat_mat(&"iron", Color8(92, 96, 104))
		head.mesh = blade
		head.position = Vector3(0, 1.32, 0.08)
		head.rotation.x = deg_to_rad(70.0)
	else:
		var broom := CylinderMesh.new() # vassoura de palha
		broom.top_radius = 0.035
		broom.bottom_radius = 0.13
		broom.height = 0.38
		broom.radial_segments = 7
		broom.rings = 1
		broom.material = _flat_mat(&"straw", STRAW)
		head.mesh = broom
		head.position = Vector3(0, 0.12, 0)
		handle.position.y += 0.2
	_add_geom(head, root)
	_take(&"tool", g)


## Varal: dois postes, a corda e 3–4 peças de roupa balançando (env_banner com a ponta livre para baixo).
func _try_clothesline(p: Vector3, along: Vector3) -> void:
	var length: float = _rng.randf_range(2.2, 2.8)
	var a: Vector3 = p - along * length * 0.5
	var b: Vector3 = p + along * length * 0.5
	var ga: Variant = _free_spot(a, 0.5)
	var gb: Variant = _free_spot(b, 0.5)
	var gc: Variant = _free_spot(p, 0.5)
	if ga == null or gb == null or gc == null:
		return
	var root := Node3D.new()
	root.name = "Clothesline%d" % count(&"clothesline")
	add_child(root)
	var h: float = 1.75
	for g: Vector3 in [ga, gb]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.045
		cyl.height = h
		cyl.radial_segments = 6
		cyl.rings = 1
		cyl.material = _flat_mat(&"wood_dark", WOOD_DARK)
		post.mesh = cyl
		post.position = g + Vector3.UP * h * 0.5
		_add_geom(post, root)
	var top_a: Vector3 = (ga as Vector3) + Vector3.UP * (h - 0.08)
	var top_b: Vector3 = (gb as Vector3) + Vector3.UP * (h - 0.08)
	var rope := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.008
	rc.bottom_radius = 0.008
	rc.height = top_a.distance_to(top_b)
	rc.radial_segments = 4
	rc.rings = 1
	rc.material = _flat_mat(&"rope", Color8(196, 180, 150))
	rope.mesh = rc
	var dir: Vector3 = (top_b - top_a).normalized()
	rope.position = (top_a + top_b) * 0.5
	rope.basis = _basis_y_to(dir)
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_geom(rope, root)
	var n: int = _rng.randi_range(3, 4)
	var shader: Shader = load(BANNER_SHADER)
	for i: int in n:
		var w: float = _rng.randf_range(0.38, 0.55)
		var hang: float = _rng.randf_range(0.5, 0.8)
		var k: float = (i + 0.5) / n + _rng.randf_range(-0.05, 0.05)
		var at: Vector3 = top_a.lerp(top_b, k) + Vector3.DOWN * 0.02
		var q := QuadMesh.new()
		# UV.x = 0 na corda; a ponta livre (embaixo) ondula
		q.size = Vector2(hang, w)
		q.center_offset = Vector3(hang * 0.5, 0, 0)
		q.subdivide_width = 4
		q.subdivide_depth = 2
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"banner_tex", _cloth_tex(_rng.randi()))
		m.set_shader_parameter(&"wave_amp", 0.06)
		m.set_shader_parameter(&"wave_speed", _rng.randf_range(1.8, 2.6))
		q.material = m
		var cloth := MeshInstance3D.new()
		cloth.name = "Cloth%d" % i
		cloth.mesh = q
		cloth.position = at
		var x_axis: Vector3 = Vector3.DOWN
		var y_axis: Vector3 = dir
		cloth.basis = Basis(x_axis, y_axis, x_axis.cross(y_axis))
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_add_geom(cloth, root)
		placed[&"cloth"] = int(placed.get(&"cloth", 0)) + 1
	_take(&"clothesline", gc)
	_taken.append(ga)
	_taken.append(gb)


# --- utilidades -----------------------------------------------------------------------------------

func _spawn_point() -> Vector3:
	var map: Node = get_parent()
	var m: Node3D = map.get_node_or_null(^"SpawnPoint") as Node3D if map != null else null
	return m.global_position if m != null and m.is_inside_tree() else (m.position if m != null else Vector3.ZERO)


func _add_geom(g: GeometryInstance3D, parent: Node = self) -> void:
	parent.add_child(g)
	_geoms.append(g)


func _kit_mesh(n: String) -> Mesh:
	if _mesh_cache.has(n):
		return _mesh_cache[n]
	var path: String = KIT_DIR + n + ".res"
	var m: Mesh = load(path) as Mesh if ResourceLoader.exists(path) else null
	_mesh_cache[n] = m
	return m


func _flat_mat(key: StringName, c: Color) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	_mat_cache[key] = m
	return m


## Esteira trançada: listras em pixel (nearest).
func _stripes_mat(key: StringName, a: Color, b: Color) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y: int in 16:
		for x: int in 16:
			var band: bool = (x / 2) % 3 == 0
			var weave: bool = (x + y) % 4 < 2
			img.set_pixel(x, y, b if band else (a if weave else a.darkened(0.12)))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	_mat_cache[key] = m
	return m


## Pano de roupa (12×16 px): cor lisa, com barra/listra/xadrez conforme a semente.
func _cloth_tex(seed_value: int) -> Texture2D:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var base: Color = CLOTH_COLORS[r.randi() % CLOTH_COLORS.size()]
	var accent: Color = CLOTH_COLORS[r.randi() % CLOTH_COLORS.size()]
	var style: int = r.randi() % 3
	var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	for y: int in 12:
		for x: int in 16:
			var c: Color = base
			if style == 0 and x >= 13:
				c = accent # barra na ponta
			elif style == 1 and y % 4 == 1:
				c = accent # listras
			elif style == 2 and (x / 3 + y / 3) % 2 == 0:
				c = base.darkened(0.18) # xadrez
			if x == 0:
				c = c.darkened(0.25) # dobra presa na corda
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	return tex


static var _foot_tex: Texture2D = null


func _footprint_tex() -> Texture2D:
	if _foot_tex != null:
		return _foot_tex
	var img := Image.create(32, 88, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i: int in 7:
		var left: bool = i % 2 == 0
		var cx: int = 10 if left else 21
		var cy: int = 6 + i * 12
		for y: int in range(-4, 5):
			for x: int in range(-2, 3):
				if float(x * x) / 6.0 + float(y * y) / 18.0 <= 1.0:
					img.set_pixel(cx + x, cy + y, Color(1, 1, 1, 0.9))
	_foot_tex = ImageTexture.create_from_image(img)
	return _foot_tex


static func _dir(a: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a))


static func _basis_y_to(dir: Vector3) -> Basis:
	var y: Vector3 = dir.normalized()
	var x: Vector3 = y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y))


static func _preset() -> int:
	return 2 if EnvQuality.current == EnvQuality.Preset.BAIXA or OS.has_feature("mobile") else int(EnvQuality.current)
