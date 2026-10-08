extends Node
## Captura do clima integrado no cliente real (08/10/2026): fogueira do acampamento (ponto de nascimento do Campo
## de Treino) e a margem do riacho, em seco, no começo de uma chuva forte, depois de ~40 s de chuva e secando.
## Criado pelo main.gd com --autotest --autotest-script=res://tests/client/weather_capture.gd --shot-dir=DIR;
## servidor com --dev-commands (tests/client/run_weather_capture.sh).
## --weather-phase=dry: só as fotos em seco (referência antes de mexer nos shaders).

const ARG_SHOT_DIR: String = "shot-dir"
const ARG_PHASE: String = "weather-phase"
const MAP: String = "training_field"
const RAIN_OVERLAY: NodePath = ^"RainOverlay"
## Ponto de nascimento (fogueira à frente) e a margem norte do riacho (perto da ponte).
const CAMP_XZ: Vector2 = Vector2(0.0, 4.0)
const RIVER_XZ: Vector2 = Vector2(-10.0, 53.0)
const SETTLE_SEC: float = 6.0
const MOVE_SEC: float = 2.5
const CMD_GAP_SEC: float = 1.2
const RAIN_SOAK_SEC: float = 40.0
const DRY_SEC: float = 40.0

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false
var _rain_t0: int = 0


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC)
	if NetWorld.client_map_id != StringName(MAP):
		NetProgress.send_debug(&"goto", [MAP])
		await _wait(SETTLE_SEC)
	_hide_chat()
	await _cmd("/dia")
	var rain: RainOverlay = _overlay()
	if rain == null:
		Net.log_line("weather_capture_missing_overlay", {})
		get_tree().quit(1)
		return
	rain.force_weather(0.0, 0.0, true)
	await _wait(3.0)
	await _go(CAMP_XZ)
	await _shot("camp_seco")
	await _go(RIVER_XZ)
	await _shot("rio_seco")
	if args.get(ARG_PHASE, "") == "dry":
		get_tree().quit(0)
		return
	# chuva forte começando agora (sem rampa): o chão ainda está seco, a fogueira já sente
	rain.force_weather(1.0, 0.0, true)
	_rain_t0 = Time.get_ticks_msec()
	await _wait(2.0)
	await _shot("rio_chuva_inicio")
	await _go(CAMP_XZ)
	await _shot("camp_chuva_inicio")
	await _wait(maxf(0.0, RAIN_SOAK_SEC - _elapsed()))
	await _shot("camp_chuva_40s")
	await _go(RIVER_XZ)
	await _shot("rio_chuva_40s")
	# para de chover: o chão seca devagar
	rain.force_weather(0.0, 0.0, false)
	_rain_t0 = Time.get_ticks_msec()
	await _wait(DRY_SEC * 0.5)
	await _shot("rio_secando_20s")
	await _go(CAMP_XZ)
	await _wait(maxf(0.0, DRY_SEC - _elapsed()))
	await _shot("camp_secando_40s")
	rain.release_weather()
	Net.log_line("weather_capture_done", {})
	get_tree().quit(0)


func _overlay() -> RainOverlay:
	var view: Node = main_node.get("client_view") if main_node != null else null
	if view == null:
		return null
	return view.find_child("RainOverlay", true, false) as RainOverlay


func _elapsed() -> float:
	return float(Time.get_ticks_msec() - _rain_t0) / 1000.0


func _go(xz: Vector2) -> void:
	NetProgress.send_debug(&"teleport", [xz.x, xz.y])
	await _wait(MOVE_SEC)


func _cmd(text: String) -> void:
	Net.send_chat(Net.CHANNEL_LOCAL, text)
	await _wait(CMD_GAP_SEC)


func _hide_chat() -> void:
	var view: Node = main_node.get("client_view") if main_node != null else null
	if view == null:
		return
	for n: Node in view.find_children("*Chat*", "Control", true, false):
		(n as Control).modulate.a = 0.0


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [dir, label]
	get_viewport().get_texture().get_image().save_png(path)
	var map: Node = _current_map()
	Net.log_line("weather_capture_shot", {"file": path, "t": snappedf(_elapsed(), 0.1),
		"weather": str(map.get_meta(&"weather_visual", Vector2.ZERO)) if map != null else "",
		"wetness": snappedf(float(map.get_meta(&"weather_wetness", 0.0)), 0.01) if map != null else -1.0})


func _current_map() -> Node:
	var root: Node = get_node_or_null(^"/root/Main/World/Instances")
	if root == null:
		return null
	for inst: Node in root.get_children():
		var map: Node = inst.get_node_or_null(^"Map")
		if map != null and &"map_id" in map and map.get(&"map_id") == NetWorld.client_map_id:
			return map
	return null
