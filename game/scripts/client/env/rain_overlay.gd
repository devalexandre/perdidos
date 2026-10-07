class_name RainOverlay
extends Control
## Chuva cosmética local: desenha riscos sobre o mundo, sem colisão, áudio ou impacto na simulação.

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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	_rng.randomize()
	NetWorld.zone_changed.connect(set_map)
	if not NetWorld.client_map_id.is_empty():
		set_map(NetWorld.client_map_id)


func _exit_tree() -> void:
	if NetWorld.zone_changed.is_connected(set_map):
		NetWorld.zone_changed.disconnect(set_map)


func set_map(map_id: StringName) -> void:
	_map_id = map_id
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


func _roll_weather() -> void:
	_set_raining(_rng.randf() < rain_chance)
	_rain_seconds_left = _rng.randf_range(35.0, 95.0) if _raining else _rng.randf_range(50.0, 130.0)


func _set_raining(enabled: bool) -> void:
	if _raining == enabled:
		return
	_raining = enabled
	_rebuild_drops()
	queue_redraw()


func _rebuild_drops() -> void:
	_drops.clear()
	if not _raining or size.x <= 0.0 or size.y <= 0.0:
		return
	var count: int = drop_budget(size, _mobile)
	for index: int in count:
		_drops.append(Vector3(_rng.randf_range(0.0, size.x), _rng.randf_range(0.0, size.y),
				_rng.randf_range(DROP_LENGTH_MIN, DROP_LENGTH_MAX)))
	_update_accum = 0.0


static func drop_budget(view_size: Vector2, mobile: bool) -> int:
	if mobile:
		return clampi(roundi(view_size.x * view_size.y * MOBILE_DROP_RATE), 36, MOBILE_MAX_DROPS)
	return clampi(roundi(view_size.x * view_size.y * DROP_RATE), 48, 260)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _raining:
		_rebuild_drops()


func _process(delta: float) -> void:
	if not _rain_allowed(_map_id):
		return
	_rain_seconds_left -= delta
	if _rain_seconds_left <= 0.0:
		_roll_weather()
	if not _raining:
		return
	_update_accum += delta
	if _update_accum < RAIN_UPDATE_INTERVAL:
		return
	var step: float = minf(_update_accum, 0.1)
	_update_accum = 0.0
	for index: int in _drops.size():
		var drop: Vector3 = _drops[index]
		drop.x -= DROP_DRIFT * step
		drop.y += DROP_SPEED * step
		if drop.y > size.y + drop.z:
			drop.x = _rng.randf_range(0.0, size.x)
			drop.y = _rng.randf_range(-drop.z, 0.0)
		_drops[index] = drop
	queue_redraw()


func _draw() -> void:
	if not _raining:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.29, 0.4, 0.035))
	var segments := PackedVector2Array()
	for drop: Vector3 in _drops:
		segments.append(Vector2(drop.x, drop.y))
		segments.append(Vector2(drop.x - 2.0, drop.y + drop.z))
	draw_multiline(segments, DROP_COLOR, 1.0, false)