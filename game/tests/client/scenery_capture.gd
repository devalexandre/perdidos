extends Node
## Captura do cenário vivo no cliente real (08/10/2026): vento nas plantas, sombras de nuvem passando no chão,
## partículas de ar por bioma e vida de caverna. Para cada mapa: sequência de 4 quadros com ~0,5 s entre eles (para
## ver o que se mexe) de dia; um mapa também de noite (vaga-lumes). Rótulo com a fase (--scenery-phase=antes|depois).
## Criado pelo main.gd com --autotest --autotest-script=res://tests/client/scenery_capture.gd --shot-dir=DIR;
## servidor com --dev-commands (tests/client/run_scenery_capture.sh).

const ARG_SHOT_DIR: String = "shot-dir"
const ARG_PHASE: String = "scenery-phase"
const ARG_MAPS: String = "scenery-maps"
const SETTLE_SEC: float = 7.0
const CMD_GAP_SEC: float = 1.2
const FRAMES: int = 4
const FRAME_GAP_SEC: float = 0.5
const DEFAULT_MAPS: Array[String] = ["training_field", "city_awakening", "fields_pindorama", "jungle_z_trail",
	"enchanted_forest", "fog_moor_swamp", "cave_reino_encoberto"]
## Mapa que também sai de noite.
const NIGHT_MAP: String = "fields_pindorama"
## Mapa que também sai com chuva forte depois de encharcar (chão de mata molhado, nuvem mais densa).
const RAIN_MAP: String = "enchanted_forest"
const SOAK_SEC: float = 36.0

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
	var maps: Array = DEFAULT_MAPS
	if args.has(ARG_MAPS):
		maps = args[ARG_MAPS].split(",")
	await _cmd("/dia")
	for id: String in maps:
		if NetWorld.client_map_id != StringName(id):
			NetProgress.send_debug(&"goto", [id])
			await _wait(SETTLE_SEC)
		_hide_chat()
		_dry()
		await _wait(1.5)
		await _sequence("%s_dia" % id)
		if id == NIGHT_MAP:
			await _cmd("/noite")
			await _wait(5.0)
			await _sequence("%s_noite" % id)
			await _cmd("/dia")
			await _wait(4.0)
		if id == RAIN_MAP:
			_rain(1.0)
			await _wait(SOAK_SEC)
			await _sequence("%s_chuva" % id)
			_dry()
			await _wait(2.0)
	Net.log_line("scenery_capture_done", {})
	get_tree().quit(0)


func _sequence(label: String) -> void:
	var phase: String = args.get(ARG_PHASE, "depois")
	var map: Node = _current_map()
	var life: Node = map.get_node_or_null(^"SceneryLife") if map != null else null
	Net.log_line("scenery_capture_map", {"map": String(NetWorld.client_map_id), "life": life != null,
		"info": str(life.call(&"debug_info")) if life != null and life.has_method(&"debug_info") else ""})
	# caverna: uma passagem de morcegos garantida no meio da sequência (no jogo é sorteada a cada 9–22 s)
	if life != null and life.has_method(&"spawn_bats") and life.get(&"_bat_mesh") != null:
		life.call(&"spawn_bats", 3)
		await _wait(1.2)
	for i: int in FRAMES:
		await _shot("%s_%s_%d" % [phase, label, i])
		await _wait(FRAME_GAP_SEC)


func _dry() -> void:
	_rain(0.0)


func _rain(amount: float) -> void:
	var view: Node = main_node.get("client_view") if main_node != null else null
	var rain: Node = view.find_child("RainOverlay", true, false) if view != null else null
	if rain != null and rain.has_method(&"force_weather"):
		rain.call(&"force_weather", amount, 0.0, true)


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
	Net.log_line("scenery_capture_shot", {"file": path})


func _current_map() -> Node:
	var root: Node = get_node_or_null(^"/root/Main/World/Instances")
	if root == null:
		return null
	for inst: Node in root.get_children():
		var map: Node = inst.get_node_or_null(^"Map")
		if map != null and &"map_id" in map and map.get(&"map_id") == NetWorld.client_map_id:
			return map
	return null
