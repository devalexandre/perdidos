extends Node3D
## Fauna de ambiente (08/10/2026): bandinhos de 2–4 passarinhos que chegam voando, pousam no chão, em cercas,
## bancos, caixas e telhados de barracas, ciscam e saltitam, e levantam voo quando alguém passa perto (~3,5 m) ou
## depois de um tempo. Só cliente, sem rede e sem colisão. Carregado em todo mapa externo (Map._ready); em caverna,
## subterrâneo e arena não carrega (ver NO_BIRDS_PREFIXES). Espécie e quantidade por bioma (BIOMES, pelo prefixo do
## map_id); pontos de pouso achados sozinhos pelo AmbientScan. Custo: só existe perto da câmera e do jogador, e o
## número de bandos segue o EnvQuality (BAIXA/mobile: um bandinho de 2, raro). Sem pouso com chuva forte (meta
## &"weather_visual" do mapa) nem à noite.

const AmbientScan = preload("res://scripts/client/env/ambient_scan.gd")
const BirdArt = preload("res://scripts/client/env/ambient_bird_art.gd")

## Bioma pelo prefixo do map_id (o primeiro que casar vence). species = sorteio por bando; flocks = bandos
## simultâneos no preset ALTA; size = [mín, máx] de aves por bando; every = [mín, máx] s entre chegadas.
const BIOMES: Array = [
	[["city_of_z", "ruins_ratanaba", "jungle_", "enchanted_forest"],
		{"species": [&"periquito", &"saira", &"periquito"], "flocks": 2, "size": [2, 4], "every": [8.0, 18.0]}],
	[["city_", "vila_", "town_"],
		{"species": [&"pombo", &"pardal", &"pardal"], "flocks": 2, "size": [2, 4], "every": [7.0, 16.0]}],
	[["beach_", "coast_", "praia_", "litoral_"],
		{"species": [&"gaivota"], "flocks": 2, "size": [2, 3], "every": [9.0, 20.0]}],
	[["fog_moor"], {"species": [&"anu"], "flocks": 1, "size": [2, 3], "every": [12.0, 26.0]}],
	[["split_sky", "hollow_mountain"], {"species": [&"anu", &"pardal"], "flocks": 1, "size": [2, 3], "every": [12.0, 24.0]}],
	[["training_field", "fields_pindorama", "hoer_verde"],
		{"species": [&"sabia", &"anu", &"sabia", &"pardal"], "flocks": 2, "size": [2, 4], "every": [7.0, 16.0]}],
]
## Campo/cerrado genérico para mapas externos que não estão na tabela.
const DEFAULT_PROFILE: Dictionary = {"species": [&"sabia", &"pardal"], "flocks": 1, "size": [2, 3], "every": [10.0, 22.0]}
## Sem passarinhos (interior, caverna, subterrâneo, abismo, arena).
const NO_BIRDS_PREFIXES: Array[String] = ["cave_", "hollow_earth", "sumidouro_abyss", "elder_trial_arena", "arena_",
	"interior_", "dungeon_"]

## Distâncias (m): de onde os bandos podem pousar em volta do jogador, quem espanta, onde somem.
const SITE_MIN_M: float = 4.5
const SITE_MAX_M: float = 16.0
const FLEE_RADIUS_M: float = 3.5
const SITE_CLEAR_M: float = 5.0
const DESPAWN_M: float = 34.0
const PERCH_MAX_ABOVE_GROUND: float = 4.5
const ARRIVE_FROM_M: float = 13.0
## Tempo pousado (s) antes de ir embora sozinho.
const STAY_SEC: Vector2 = Vector2(18.0, 40.0)
## Chuva (weather_visual.x) acima disto não pousa; noite acima disto, idem.
const RAIN_MAX: float = 0.45
const NIGHT_MAX: float = 0.6
const TICK_SEC: float = 0.15
const FLAP_SEC: float = 0.08
const HOP_SEC: float = 0.2

enum State { ARRIVING, LANDED, LEAVING }

var map_id: StringName = &""
var profile: Dictionary = {}
var scan_result = null
## Liga/desliga o sorteio automático de bandos (capturas e testes podem desligar e chamar force_flock).
var auto_spawn: bool = true

var _flocks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _tick: float = 0.0
var _next_arrival: float = 4.0
var _rain: float = 0.0
var _night: float = 0.0
var _entities: Array[Node3D] = []
## Última posição de cada entidade (quem está andando espanta; NPC parado não).
var _last_pos: Dictionary = {}
var _moving: Dictionary = {}
var _entities_t: float = 0.0
var _ready_scan: bool = false
var _shadow_mesh: QuadMesh = null


## Perfil de fauna do mapa ({} = sem passarinhos).
static func profile_for(id: StringName) -> Dictionary:
	var s: String = String(id)
	for p: String in NO_BIRDS_PREFIXES:
		if s.begins_with(p):
			return {}
	for row: Array in BIOMES:
		for prefix: String in row[0]:
			if s.begins_with(prefix):
				return row[1]
	return DEFAULT_PROFILE


static func supports(id: StringName) -> bool:
	return not profile_for(id).is_empty()


func _ready() -> void:
	name = &"AmbientLife"
	top_level = true # posições das aves em coordenadas de mundo
	var map: Node = get_parent()
	if map_id.is_empty() and map != null and &"map_id" in map:
		map_id = map.get(&"map_id")
	profile = profile_for(map_id)
	_rng.seed = hash(String(map_id)) ^ Time.get_ticks_usec()
	_next_arrival = _rng.randf_range(2.0, 6.0)
	# a malha de navegação e a física do mapa ficam prontas no quadro seguinte
	if is_inside_tree():
		await get_tree().physics_frame
	rescan()


## Lê de novo o mapa (pontos de pouso). Testes chamam direto.
func rescan() -> void:
	scan_result = AmbientScan.scan(get_parent() as Node3D)
	_ready_scan = true


func _process(delta: float) -> void:
	step(delta)


## Avança a fauna (o _process chama; testes chamam com set_process(false)).
func step(delta: float) -> void:
	if profile.is_empty():
		return
	_tick += delta
	_entities_t -= delta
	if _tick >= TICK_SEC:
		var dt: float = _tick
		_tick = 0.0
		_read_environment()
		if _entities_t <= 0.0:
			_entities_t = 0.5
			_refresh_entities()
		_track_motion(dt)
		_think(dt)
	for f: Dictionary in _flocks:
		_animate_flock(f, delta)
	for i: int in range(_flocks.size() - 1, -1, -1):
		if (_flocks[i]["birds"] as Array).is_empty():
			(_flocks[i]["root"] as Node3D).queue_free()
			_flocks.remove_at(i)


func _read_environment() -> void:
	var map: Node = get_parent()
	if map == null:
		return
	var weather: Vector2 = map.get_meta(&"weather_visual", Vector2.ZERO)
	_rain = weather.x
	var id: StringName = map_id
	_night = DayNight.night_amount_on_map(id) if DayNight != null else 0.0


## Chuva forte agora (testes).
func set_weather(rain: float) -> void:
	_rain = rain


func set_night(amount: float) -> void:
	_night = amount


func can_land() -> bool:
	return _rain < RAIN_MAX and _night < NIGHT_MAX


## Bandos simultâneos permitidos pelo preset (BAIXA/mobile = 1 bandinho de 2).
func max_flocks() -> int:
	if profile.is_empty():
		return 0
	if is_low_end():
		return 1
	if EnvQuality.current == EnvQuality.Preset.MEDIA:
		return maxi(1, int(profile["flocks"]) - 1)
	return int(profile["flocks"])


func max_birds() -> int:
	var hi: int = int((profile.get("size", [2, 3]) as Array)[1])
	return 2 if is_low_end() else hi


static func is_low_end() -> bool:
	return EnvQuality.current == EnvQuality.Preset.BAIXA or OS.has_feature("mobile")


func _think(dt: float) -> void:
	var focus: Variant = _focus()
	# chuva forte ou noite: quem está pousado vai embora
	for f: Dictionary in _flocks:
		if f["state"] == State.LEAVING:
			continue
		if not can_land():
			_leave(f, Vector3.ZERO)
			continue
		if focus != null and _flat(f["site"], focus) > DESPAWN_M:
			_leave(f, Vector3.ZERO)
			continue
		var threat: Variant = _threat_near(f)
		if threat != null:
			_leave(f, threat)
			continue
		if f["state"] == State.LANDED:
			f["stay"] = float(f["stay"]) - dt
			if float(f["stay"]) <= 0.0:
				_leave(f, Vector3.ZERO)
	if not auto_spawn or not _ready_scan or focus == null or not can_land():
		return
	_next_arrival -= dt
	if _next_arrival > 0.0 or _flocks.size() >= max_flocks():
		return
	var every: Array = profile.get("every", [10.0, 20.0])
	_next_arrival = _rng.randf_range(float(every[0]), float(every[1])) * (2.0 if is_low_end() else 1.0)
	var site: Dictionary = pick_site(focus)
	if site.is_empty():
		return
	var species: Array = profile["species"]
	var size: Array = profile.get("size", [2, 3])
	force_flock(site, _rng.randi_range(int(size[0]), mini(int(size[1]), max_birds())),
			species[_rng.randi() % species.size()])


## Escolhe onde pousar perto do foco: poleiro achado no mapa (cerca, banco, caixa, telhado) ou chão aberto e
## navegável. {} = nenhum lugar bom agora. {pos, kind, span}
func pick_site(focus: Vector3) -> Dictionary:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var options: Array[Dictionary] = []
	if scan_result != null:
		for p: Dictionary in scan_result.perches:
			var d: float = _flat(p["pos"], focus)
			if d < SITE_MIN_M or d > SITE_MAX_M:
				continue
			if AmbientScan.is_blocked(scan_result, p["pos"], 0.0, false) or not _site_clear(p["pos"]):
				continue
			if not _perch_height_ok(p):
				continue
			options.append(p)
	var on_screen: Array[Dictionary] = []
	for p: Dictionary in options:
		if cam == null or cam.is_position_in_frustum(p["pos"]):
			on_screen.append(p)
	if not on_screen.is_empty() and _rng.randf() < 0.55:
		return on_screen[_rng.randi() % on_screen.size()]
	# chão aberto: alguns sorteios em volta do foco
	var map := get_parent() as Node3D
	for i: int in 10:
		var a: float = _rng.randf() * TAU
		var d: float = _rng.randf_range(SITE_MIN_M, SITE_MAX_M * 0.8)
		var p: Vector3 = focus + Vector3(cos(a) * d, 0.0, sin(a) * d)
		var g: Variant = AmbientScan.ground_at(map, p)
		if g == null:
			continue
		p = g
		if cam != null and not cam.is_position_in_frustum(p):
			continue
		if scan_result != null and AmbientScan.is_blocked(scan_result, p, 0.0, false):
			continue
		if not AmbientScan.is_walkable(map, p) or not _site_clear(p):
			continue
		return {"pos": p, "kind": &"ground", "span": Vector2(2.4, 2.4)}
	if not options.is_empty():
		return options[_rng.randi() % options.size()]
	return {}


## Poleiro alto demais (telhado de sobrado) fica fora da vista da câmera: só até PERCH_MAX_ABOVE_GROUND do chão.
func _perch_height_ok(p: Dictionary) -> bool:
	if p.has("ok"):
		return bool(p["ok"])
	var top: Vector3 = p["pos"]
	var g: Variant = AmbientScan.ground_at(get_parent() as Node3D, top - Vector3.UP * 0.05, 0.0, 30.0)
	p["ok"] = g == null or top.y - (g as Vector3).y <= PERCH_MAX_ABOVE_GROUND
	return bool(p["ok"])


## Cria um bando chegando agora no lugar dado (testes e capturas usam direto). landed = já pousado.
func force_flock(site: Dictionary, count: int, species: StringName, landed: bool = false) -> Dictionary:
	var root := Node3D.new()
	root.name = "Flock%d" % _flocks.size()
	add_child(root)
	var f: Dictionary = {"root": root, "site": site["pos"], "kind": site.get("kind", &"ground"), "birds": [],
		"state": State.LANDED if landed else State.ARRIVING, "stay": _rng.randf_range(STAY_SEC.x, STAY_SEC.y),
		"species": species}
	var spots: Array[Vector3] = _spots(site, maxi(1, count))
	var from_dir: Vector3 = _arrival_dir(site["pos"])
	for i: int in spots.size():
		var b: Dictionary = _make_bird(root, species)
		var spot: Vector3 = spots[i]
		b["spot"] = spot
		var side := Vector3(-from_dir.z, 0.0, from_dir.x) * _rng.randf_range(-2.0, 2.0)
		b["from"] = spot + from_dir * _rng.randf_range(ARRIVE_FROM_M, ARRIVE_FROM_M + 4.0) + side \
				+ Vector3.UP * _rng.randf_range(5.0, 7.5)
		b["to"] = spot
		b["t"] = -_rng.randf_range(0.0, 0.7) # chegam um pouco espaçados
		b["dur"] = _rng.randf_range(2.4, 3.4)
		b["state"] = State.LANDED if landed else State.ARRIVING
		b["next"] = _rng.randf_range(0.4, 1.8)
		b["face"] = 1.0 if _rng.randf() < 0.5 else -1.0
		(b["node"] as Node3D).position = spot if landed else b["from"]
		(b["node"] as Node3D).visible = landed
		(f["birds"] as Array).append(b)
	_flocks.append(f)
	return f


## Espanta os bandos perto de um ponto (testes; o _think faz o mesmo com as entidades do mapa).
func scare(at: Vector3) -> int:
	var n: int = 0
	for f: Dictionary in _flocks:
		if f["state"] != State.LEAVING and _flat(f["site"], at) < FLEE_RADIUS_M + 1.5:
			_leave(f, at)
			n += 1
	return n


func flock_count() -> int:
	return _flocks.size()


func bird_count() -> int:
	var n: int = 0
	for f: Dictionary in _flocks:
		n += (f["birds"] as Array).size()
	return n


func count_in_state(state: int) -> int:
	var n: int = 0
	for f: Dictionary in _flocks:
		for b: Dictionary in f["birds"]:
			n += 1 if b["state"] == state else 0
	return n


func perch_count() -> int:
	return scan_result.perches.size() if scan_result != null else 0


# --- internos -------------------------------------------------------------------------------------

func _spots(site: Dictionary, count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var center: Vector3 = site["pos"]
	var kind: StringName = site.get("kind", &"ground")
	var span: Vector2 = site.get("span", Vector2(1.0, 1.0))
	var map := get_parent() as Node3D
	if kind == &"ground":
		for i: int in count:
			var p: Vector3 = center + Vector3(_rng.randf_range(-1.1, 1.1), 0.0, _rng.randf_range(-1.1, 1.1))
			var g: Variant = AmbientScan.ground_at(map, p, 2.0, 4.0)
			out.append((g as Vector3) + Vector3.UP * 0.01 if g != null else Vector3(p.x, center.y + 0.01, p.z))
		return out
	# poleiro: em fila ao longo do lado mais comprido do topo (topo pequeno = no máximo 2), um pouco puxados para
	# o lado da câmera para o pé não "afundar" na peça (o sprite é um cartaz em pé)
	var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
	var long_side: float = maxf(span.x, span.y)
	var n: int = mini(count, 3 if long_side > 1.2 else 2)
	var half: float = clampf(long_side * 0.5 - 0.15, 0.12, 0.8)
	var toward := Vector3.ZERO
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		toward = cam.global_position - center
		toward.y = 0.0
		toward = toward.normalized() * 0.12 if toward.length() > 0.01 else Vector3.ZERO
	for i: int in n:
		var k: float = 0.0 if n == 1 else lerpf(-half, half, float(i) / (n - 1))
		out.append(center + along * (k + _rng.randf_range(-0.05, 0.05)) + toward + Vector3.UP * 0.03)
	return out


## Direção (horizontal) de onde o bando vem: de trás/dos lados da câmera, para entrar na tela voando.
func _arrival_dir(site: Vector3) -> Vector3:
	var a: float = _rng.randf() * TAU
	var d := Vector3(cos(a), 0.0, sin(a))
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var away: Vector3 = site - cam.global_position
		away.y = 0.0
		if away.length() > 0.1:
			d = (away.normalized() + d * 0.8).normalized()
	return d


func _make_bird(root: Node3D, species: StringName) -> Dictionary:
	var s := Sprite3D.new()
	s.texture = BirdArt.sheet(species)
	s.hframes = BirdArt.FRAME_COUNT
	s.frame = BirdArt.FRAME_IDLE
	s.pixel_size = (Balance.cfg.sprite_pixel_size if Balance.cfg != null else 1.0 / 48.0) * BirdArt.species_scale(species)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.centered = true
	s.offset = Vector2(0.0, BirdArt.FRAME_H * 0.5 - 1.0) # pés na origem
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(s)
	var sh := MeshInstance3D.new()
	if _shadow_mesh == null:
		_shadow_mesh = QuadMesh.new()
		_shadow_mesh.orientation = PlaneMesh.FACE_Y
		_shadow_mesh.size = Vector2(0.42, 0.42)
	sh.mesh = _shadow_mesh
	sh.material_override = DirectionalSprite3D.blob_material()
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.visible = false
	root.add_child(sh)
	return {"node": s, "shadow": sh, "act": &"", "act_t": 0.0, "hop_from": Vector3.ZERO, "hop_to": Vector3.ZERO}


func _leave(f: Dictionary, threat: Vector3) -> void:
	if f["state"] == State.LEAVING:
		return
	f["state"] = State.LEAVING
	for b: Dictionary in f["birds"]:
		var node: Node3D = b["node"]
		var p: Vector3 = node.position
		var away: Vector3 = p - threat if threat != Vector3.ZERO else Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
		away = away.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
		b["from"] = p
		b["to"] = p + away * _rng.randf_range(14.0, 20.0) + Vector3.UP * _rng.randf_range(6.0, 9.0)
		b["t"] = -_rng.randf_range(0.0, 0.25 if threat != Vector3.ZERO else 0.9)
		b["dur"] = _rng.randf_range(1.6, 2.3) if threat != Vector3.ZERO else _rng.randf_range(2.6, 3.4)
		b["state"] = State.LEAVING
		(b["node"] as Node3D).visible = true


func _animate_flock(f: Dictionary, delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var birds: Array = f["birds"]
	var all_landed: bool = true
	for i: int in range(birds.size() - 1, -1, -1):
		var b: Dictionary = birds[i]
		var s: Sprite3D = b["node"]
		var sh: MeshInstance3D = b["shadow"]
		match int(b["state"]):
			State.ARRIVING:
				all_landed = false
				b["t"] = float(b["t"]) + delta
				if float(b["t"]) < 0.0:
					continue
				s.visible = true
				var k: float = clampf(float(b["t"]) / float(b["dur"]), 0.0, 1.0)
				var e: float = 1.0 - pow(1.0 - k, 2.2) # desacelera para pousar
				var p: Vector3 = _arc(b["from"], b["to"], e, 2.5)
				_face(b, p - s.position, cam)
				s.position = p
				s.frame = _flap_frame(float(b["t"]), k)
				_shadow_at(sh, b["to"], k)
				if k >= 1.0:
					b["state"] = State.LANDED
					s.frame = BirdArt.FRAME_IDLE
					b["next"] = _rng.randf_range(0.3, 1.2)
			State.LANDED:
				_animate_landed(f, b, s, delta, cam)
				sh.visible = true
				sh.position = Vector3(s.position.x, (b["spot"] as Vector3).y + 0.005, s.position.z)
			State.LEAVING:
				all_landed = false
				b["t"] = float(b["t"]) + delta
				if float(b["t"]) < 0.0:
					_animate_landed(f, b, s, delta, cam)
					continue
				var k2: float = clampf(float(b["t"]) / float(b["dur"]), 0.0, 1.0)
				var p2: Vector3 = _arc(b["from"], b["to"], k2 * k2 * (1.6 - 0.6 * k2), -1.0)
				_face(b, p2 - s.position, cam)
				s.position = p2
				s.frame = _flap_frame(float(b["t"]), 0.0)
				_shadow_at(sh, b["from"], 1.0 - k2 * 3.0)
				if k2 >= 1.0:
					s.queue_free()
					sh.queue_free()
					birds.remove_at(i)
	if f["state"] == State.ARRIVING and all_landed and not birds.is_empty():
		f["state"] = State.LANDED


## Pousado: parado, bica o chão, levanta o rabo, vira e (no chão) dá pulinhos.
func _animate_landed(f: Dictionary, b: Dictionary, s: Sprite3D, delta: float, cam: Camera3D) -> void:
	var act: StringName = b["act"]
	if not act.is_empty():
		b["act_t"] = float(b["act_t"]) - delta
		if act == &"hop":
			var k: float = 1.0 - clampf(float(b["act_t"]) / HOP_SEC, 0.0, 1.0)
			s.position = (b["hop_from"] as Vector3).lerp(b["hop_to"], k) + Vector3.UP * 0.09 * sin(PI * k)
			s.frame = BirdArt.FRAME_FLICK if k < 0.5 else BirdArt.FRAME_IDLE
		if float(b["act_t"]) <= 0.0:
			if act == &"hop":
				s.position = b["hop_to"]
				b["spot"] = b["hop_to"]
			b["act"] = &""
			s.frame = BirdArt.FRAME_IDLE
		return
	b["next"] = float(b["next"]) - delta
	if float(b["next"]) > 0.0:
		return
	b["next"] = _rng.randf_range(0.5, 2.0)
	var roll: float = _rng.randf()
	if roll < 0.4:
		b["act"] = &"peck"
		b["act_t"] = _rng.randf_range(0.2, 0.45)
		s.frame = BirdArt.FRAME_PECK
	elif roll < 0.58:
		b["act"] = &"flick"
		b["act_t"] = 0.22
		s.frame = BirdArt.FRAME_FLICK
	elif roll < 0.72:
		b["face"] = -float(b["face"])
		s.flip_h = float(b["face"]) < 0.0
	elif f["kind"] == &"ground":
		var dir: float = float(b["face"]) if _rng.randf() < 0.7 else -float(b["face"])
		var right: Vector3 = cam.global_basis.x if cam != null else Vector3.RIGHT
		right.y = 0.0
		right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
		var to: Vector3 = (b["spot"] as Vector3) + right * dir * _rng.randf_range(0.12, 0.3) \
				+ Vector3(0, 0, _rng.randf_range(-0.1, 0.1))
		# não se afasta demais do centro do bando
		if _flat(to, f["site"]) < 1.6:
			b["act"] = &"hop"
			b["act_t"] = HOP_SEC
			b["hop_from"] = b["spot"]
			b["hop_to"] = to
			b["face"] = dir
			s.flip_h = dir < 0.0


static func _arc(a: Vector3, b: Vector3, k: float, lift: float) -> Vector3:
	var p: Vector3 = a.lerp(b, k)
	return p + Vector3.UP * lift * sin(PI * k) * 0.5


func _flap_frame(t: float, k: float) -> int:
	# planando no fim da chegada; batendo as asas no resto
	if k > 0.82:
		return BirdArt.FRAME_WING_UP
	return BirdArt.FRAME_WING_UP if int(t / FLAP_SEC) % 2 == 0 else BirdArt.FRAME_WING_DOWN


func _face(b: Dictionary, motion: Vector3, cam: Camera3D) -> void:
	if motion.length() < 0.0001:
		return
	var right: Vector3 = cam.global_basis.x if cam != null else Vector3.RIGHT
	var sx: float = motion.dot(right)
	if absf(sx) > 0.0005:
		b["face"] = signf(sx)
		(b["node"] as Sprite3D).flip_h = sx < 0.0


func _shadow_at(sh: MeshInstance3D, ground: Vector3, k: float) -> void:
	sh.visible = k > 0.55
	sh.position = ground + Vector3.UP * 0.005
	sh.scale = Vector3.ONE * clampf(k, 0.3, 1.0)


## Foco: o jogador local (ou o ponto da câmera no chão). null = nada para olhar ainda.
func _focus() -> Variant:
	for e: Node3D in _entities:
		if is_instance_valid(e) and e.has_method(&"is_local_player") and bool(e.call(&"is_local_player")):
			return e.global_position
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return null
	var fwd: Vector3 = -cam.global_basis.z
	if fwd.y > -0.05:
		return Vector3(cam.global_position.x, 0.0, cam.global_position.z)
	var t: float = -cam.global_position.y / fwd.y
	return cam.global_position + fwd * t


func _refresh_entities() -> void:
	_entities.clear()
	var map: Node = get_parent()
	var inst: Node = map.get_parent() if map != null else null
	var ents: Node = inst.get_node_or_null(^"Entities") if inst != null else null
	if ents == null:
		return
	for e: Node in ents.get_children():
		if e is Node3D and (not &"kind" in e or e.get(&"kind") != &"drop"):
			_entities.append(e as Node3D)


## Quem espanta: alguém ANDANDO a menos de FLEE_RADIUS_M de uma ave, ou qualquer um muito perto (metade do raio).
## NPC parado no lugar dele não espanta (as aves só não pousam colado nele, ver _site_clear).
func _threat_near(f: Dictionary) -> Variant:
	var site: Vector3 = f["site"]
	for e: Node3D in _entities:
		if not is_instance_valid(e):
			continue
		var p: Vector3 = e.global_position
		if _flat(p, site) > FLEE_RADIUS_M + 1.2:
			continue
		var radius: float = FLEE_RADIUS_M if bool(_moving.get(e.get_instance_id(), false)) else FLEE_RADIUS_M * 0.5
		for b: Dictionary in f["birds"]:
			if _flat((b["node"] as Node3D).position, p) < radius:
				return p
	return null


func _track_motion(dt: float) -> void:
	for e: Node3D in _entities:
		if not is_instance_valid(e):
			continue
		var id: int = e.get_instance_id()
		var p: Vector3 = e.global_position
		var last: Variant = _last_pos.get(id)
		_moving[id] = last != null and _flat(p, last) / maxf(dt, 0.01) > 0.4
		_last_pos[id] = p


func _site_clear(p: Vector3) -> bool:
	for e: Node3D in _entities:
		if not is_instance_valid(e):
			continue
		var player: bool = &"kind" in e and e.get(&"kind") != &"npc"
		if _flat(e.global_position, p) < (SITE_CLEAR_M if player else 2.5):
			return false
	for f: Dictionary in _flocks:
		if _flat(f["site"], p) < 3.0:
			return false
	return true


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
