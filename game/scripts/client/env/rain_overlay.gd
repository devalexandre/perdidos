class_name RainOverlay
extends Control
## Clima cosmético regional: chuva leve/forte, neblina e iluminação, com transições suaves.

const REGIONS = preload("res://scripts/client/env/weather_regions.gd")
const INSTANCES: NodePath = ^"/root/Main/World/Instances"

const RAIN_CHANCE: float = 0.32
const DROP_RATE: float = 1.0 / 4200.0
const MOBILE_DROP_RATE: float = 1.0 / 8000.0
const MOBILE_MAX_DROPS: int = 90
const RAIN_UPDATE_INTERVAL: float = 1.0 / 30.0
const DROP_SPEED: float = 520.0
const DROP_DRIFT: float = 42.0
const DROP_COLOR: Color = Color(0.72, 0.84, 0.96, 0.28)
const DROP_LENGTH_MIN: float = 10.0
const DROP_LENGTH_MAX: float = 22.0
const INTERIOR_MAP_PREFIX: String = "cave_"
const NO_RAIN_MAPS: Array[StringName] = [&"elder_trial_arena"]

var _rng := RandomNumberGenerator.new()
var rain_chance: float = RAIN_CHANCE
var _mobile: bool = false
var _update_accum: float = 0.0
var _map_id: StringName = &""
var _rain_seconds_left: float = 0.0
var _raining: bool = false
var _drops: Array[Vector3] = []
## Preenchido pelo ClientView; posição do jogador, independente de rotação/zoom da câmera.
var focus_position: Vector3 = Vector3.ZERO
var _weather_map: Node = null
var _region: Dictionary = {}
var _region_cache: Dictionary = {}
var _context_left: float = 0.0
var _target_intensity: float = 0.0
var _target_fog: float = 0.0
var _intensity: float = 0.0
var _fog: float = 0.0
var _last_quality: int = -1
## Clima travado por teste/captura (force_weather): x = chuva, y = neblina; negativo = sorteio normal.
var _forced: Vector2 = Vector2(-1.0, -1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	_rng.randomize()
	NetWorld.zone_changed.connect(set_map)
	if not NetWorld.client_map_id.is_empty():
		set_map(NetWorld.client_map_id)


func _exit_tree() -> void:
	_clear_map_weather()
	if NetWorld.zone_changed.is_connected(set_map):
		NetWorld.zone_changed.disconnect(set_map)


func set_map(map_id: StringName) -> void:
	_clear_map_weather()
	_map_id = map_id
	_weather_map = null
	_region_cache.clear()
	_region = REGIONS.profile(map_id, focus_position)
	_intensity = 0.0
	_fog = 0.0
	_target_fog = 0.0
	_drops.clear()
	queue_redraw()
	if not _rain_allowed(map_id):
		_set_raining(false)
		_rain_seconds_left = 0.0
		return
	_roll_weather()


func is_raining() -> bool:
	return _raining


func _rain_allowed(map_id: StringName) -> bool:
	var map_name: String = String(map_id)
	return not map_name.is_empty() and not map_name.begins_with(INTERIOR_MAP_PREFIX) \
			and map_id not in NO_RAIN_MAPS


## Trava o clima (capturas e testes): chuva/neblina 0..1 sem sorteio; instant pula a rampa de entrada.
func force_weather(rain: float, fog: float = 0.0, instant: bool = false) -> void:
	_forced = Vector2(clampf(rain, 0.0, 1.0), clampf(fog, 0.0, 1.0))
	if instant:
		_intensity = _forced.x
		_fog = _forced.y
	_roll_weather()


## Volta ao sorteio normal.
func release_weather() -> void:
	_forced = Vector2(-1.0, -1.0)
	_roll_weather()


func _roll_weather() -> void:
	if _forced.x >= 0.0:
		_target_fog = _forced.y
		_set_raining(_forced.x > 0.0)
		_target_intensity = _forced.x
		_rain_seconds_left = 3600.0
		_rebuild_drops()
		return
	var chance: float = 1.0 if rain_chance >= 1.0 else rain_chance * float(_region.get("rain_factor", 1.0))
	var raining: bool = _rng.randf() < chance
	_target_intensity = (1.0 if _rng.randf() < float(_region.get("heavy_chance", 0.3)) else 0.4) if raining else 0.0
	_target_fog = _rng.randf_range(0.5, 1.0) if _rng.randf() < float(_region.get("fog_chance", 0.25)) else 0.0
	_set_raining(raining)
	_rain_seconds_left = _rng.randf_range(35.0, 95.0) if _raining else _rng.randf_range(50.0, 130.0)
	_region_cache[_region.get("id", "")] = {"rain": _target_intensity, "fog": _target_fog,
		"until": Time.get_ticks_msec() + int(_rain_seconds_left * 1000.0)}
	_rebuild_drops()


func _set_raining(enabled: bool) -> void:
	if not enabled:
		_target_intensity = 0.0
	if _raining == enabled:
		return
	_raining = enabled
	_rebuild_drops()
	queue_redraw()


func _rebuild_drops() -> void:
	_drops.clear()
	if (not _raining and _intensity <= 0.01) or size.x <= 0.0 or size.y <= 0.0:
		return
	var count: int = drop_budget(size, _mobile)
	count = mini(roundi(count * lerpf(0.65, 1.5, _target_intensity)), MOBILE_MAX_DROPS if _mobile else 390)
	if EnvQuality.current == EnvQuality.Preset.BAIXA:
		count = maxi(24, count / 2)
	for index: int in count:
		_drops.append(Vector3(_rng.randf_range(0.0, size.x), _rng.randf_range(0.0, size.y),
				_rng.randf_range(DROP_LENGTH_MIN, DROP_LENGTH_MAX)))
	_update_accum = 0.0


static func drop_budget(view_size: Vector2, mobile: bool) -> int:
	if mobile:
		return clampi(roundi(view_size.x * view_size.y * MOBILE_DROP_RATE), 36, MOBILE_MAX_DROPS)
	return clampi(roundi(view_size.x * view_size.y * DROP_RATE), 48, 260)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and (_raining or _intensity > 0.01):
		_rebuild_drops()


func _process(delta: float) -> void:
	if not _rain_allowed(_map_id):
		return
	if _last_quality != EnvQuality.current:
		_last_quality = EnvQuality.current
		_rebuild_drops()
	_context_left -= delta
	if _context_left <= 0.0:
		_context_left = 0.5
		_update_region()
	_intensity = move_toward(_intensity, _target_intensity, delta / 6.0)
	_fog = move_toward(_fog, _target_fog, delta / 10.0)
	if is_instance_valid(_weather_map):
		_weather_map.set_meta(&"weather_visual", Vector2(_intensity, _fog))
	_rain_seconds_left -= delta
	if _rain_seconds_left <= 0.0:
		_roll_weather()
	if _intensity <= 0.01:
		queue_redraw()
		return
	_update_accum += delta
	if _update_accum < RAIN_UPDATE_INTERVAL:
		return
	var step: float = minf(_update_accum, 0.1)
	_update_accum = 0.0
	for index: int in _drops.size():
		var drop: Vector3 = _drops[index]
		drop.x -= DROP_DRIFT * lerpf(0.6, 2.4, _intensity) * step
		drop.y += DROP_SPEED * lerpf(0.75, 1.65, _intensity) * step
		if drop.y > size.y + drop.z:
			drop.x = _rng.randf_range(0.0, size.x)
			drop.y = _rng.randf_range(-drop.z, 0.0)
		_drops[index] = drop
	queue_redraw()


func _draw() -> void:
	if _intensity <= 0.01:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.29, 0.4, 0.045 * _intensity))
	var segments := PackedVector2Array()
	for drop: Vector3 in _drops:
		segments.append(Vector2(drop.x, drop.y))
		segments.append(Vector2(drop.x - lerpf(1.0, 5.0, _intensity), drop.y + drop.z * lerpf(0.7, 1.5, _intensity)))
	draw_multiline(segments, Color(DROP_COLOR, DROP_COLOR.a * _intensity), 1.0, false)


func _clear_map_weather() -> void:
	if is_instance_valid(_weather_map):
		_weather_map.set_meta(&"weather_visual", Vector2.ZERO)


func _update_region() -> void:
	if not is_instance_valid(_weather_map):
		var instances: Node = get_node_or_null(INSTANCES)
		if instances != null:
			for inst: Node in instances.get_children():
				var map: Node = inst.get_node_or_null(^"Map")
				if map != null and &"map_id" in map and map.get(&"map_id") == _map_id:
					_weather_map = map
					break
	var next: Dictionary = REGIONS.profile(_map_id, focus_position)
	if next["id"] == _region.get("id", ""):
		return
	_region = next
	var cached: Dictionary = _region_cache.get(next["id"], {})
	if not cached.is_empty() and _forced.x < 0.0 and int(cached["until"]) > Time.get_ticks_msec():
		_target_intensity = cached["rain"]
		_target_fog = cached["fog"]
		_rain_seconds_left = float(int(cached["until"]) - Time.get_ticks_msec()) / 1000.0
		_set_raining(_target_intensity > 0.0)
	else:
		_roll_weather()
	_rebuild_drops()
