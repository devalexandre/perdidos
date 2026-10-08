extends Node
## Captura dos Campos de Pindorama no cliente real (antes/depois do chão de grama e da vida no campo).
## Para cada mapa: chegada (SpawnPoint, onde o portal deixa) e pontos de caça (--spots=x:z,...) de dia; a chegada
## também de noite; e um mapa (--rain-map) também com chuva forte depois de encharcar. Mapas só de comparação
## (--compare=a,b) saem uma vez, de dia, na chegada.
## Criado pelo main.gd com --autotest --autotest-script=res://tests/client/fields_capture.gd --shot-dir=DIR
## --phase=antes|depois; servidor com --dev-commands (goto/teleport, /dia e /noite).

const ARG_SHOT_DIR: String = "shot-dir"
const ARG_PHASE: String = "phase"
const ARG_MAPS: String = "maps"
const ARG_SPOTS: String = "spots"
const ARG_COMPARE: String = "compare"
const ARG_RAIN_MAP: String = "rain-map"
const DEFAULT_MAPS: String = "fields_pindorama,fields_pindorama_buriti,fields_pindorama_crossroads"
const DEFAULT_SPOTS: String = "-12:8,12:-10"
const SETTLE_SEC: float = 7.0
const SPOT_SETTLE_SEC: float = 3.0
const SOAK_SEC: float = 30.0

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC)
	var spots: PackedStringArray = args.get(ARG_SPOTS, DEFAULT_SPOTS).split(",", false)
	var rain_map: String = args.get(ARG_RAIN_MAP, "fields_pindorama")
	_hide_chat()
	for map_id: String in args.get(ARG_MAPS, DEFAULT_MAPS).split(",", false):
		_set_hour(12)
		await _goto(map_id)
		_dry()
		await _wait(2.0)
		await _shot("%s_chegada_dia" % map_id)
		for i: int in spots.size():
			var xz: PackedStringArray = spots[i].split(":")
			NetProgress.send_debug(&"teleport", [xz[0], xz[1]])
			await _wait(SPOT_SETTLE_SEC)
			await _shot("%s_caca%d_dia" % [map_id, i + 1])
		NetProgress.send_debug(&"goto", [map_id])
		await _wait(SETTLE_SEC)
		_set_hour(22)
		await _wait(5.0)
		await _shot("%s_chegada_noite" % map_id)
		if map_id == rain_map:
			_set_hour(12)
			_rain(1.0)
			await _wait(SOAK_SEC)
			await _shot("%s_chegada_chuva" % map_id)
			_dry()
			await _wait(2.0)
	_set_hour(12)
	for map_id: String in args.get(ARG_COMPARE, "").split(",", false):
		await _goto(map_id)
		await _wait(2.0)
		await _shot("%s_chegada_dia" % map_id)
	Net.log_line("fields_capture_done", {})
	get_tree().quit(0)


func _goto(map_id: String) -> void:
	if NetWorld.client_map_id != StringName(map_id):
		NetProgress.send_debug(&"goto", [map_id])
		await _wait(SETTLE_SEC)


## Dia (12) ou noite (22) pelos comandos de chat do dono (/dia, /noite: forçam o relógio, como no scenery_capture).
func _set_hour(h: int) -> void:
	Net.send_chat(Net.CHANNEL_LOCAL, "/noite" if h >= 19 or h < 5 else "/dia")


func _dry() -> void:
	_rain(0.0)


func _rain(amount: float) -> void:
	var view: Node = main_node.get("client_view") if main_node != null else null
	var rain: Node = view.find_child("RainOverlay", true, false) if view != null else null
	if rain != null and rain.has_method(&"force_weather"):
		rain.call(&"force_weather", amount, 0.0, true)


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
	var path: String = "%s/%s_%s.png" % [dir, args.get(ARG_PHASE, "depois"), label]
	get_viewport().get_texture().get_image().save_png(path)
	Net.log_line("fields_capture_shot", {"file": path, "map": String(NetWorld.client_map_id)})
