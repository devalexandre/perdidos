extends Node
## Foto de cada mapa no ponto de nascimento (comparar o visual entre mapas). Criado pelo main.gd com
## --autotest --autotest-script=res://tests/client/map_look_capture.gd --shot-dir=DIR --maps=a,b,c;
## servidor com --dev-commands (vai de mapa em mapa pelo debug "goto").
## Opcionais: --spots=x:z,x:z (mais fotos em cada mapa, teleportando até lá: <mapa>_s<n>.png) e
## --hour=H (muda a hora do mundo antes das fotos, ex.: 22 para a noite).

const ARG_SHOT_DIR: String = "shot-dir"
const ARG_MAPS: String = "maps"
const ARG_SPOTS: String = "spots"
const ARG_HOUR: String = "hour"
const SETTLE_SEC: float = 6.0
const SPOT_SETTLE_SEC: float = 2.5

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	if args.has(ARG_HOUR):
		NetProgress.send_debug(&"set_hour", [args[ARG_HOUR]])
	await get_tree().create_timer(SETTLE_SEC).timeout
	var spots: PackedStringArray = args.get(ARG_SPOTS, "").split(",", false)
	for map_id: String in args.get(ARG_MAPS, "").split(",", false):
		if NetWorld.client_map_id != StringName(map_id):
			NetProgress.send_debug(&"goto", [map_id])
			await get_tree().create_timer(SETTLE_SEC).timeout
		await _shot(map_id, map_id)
		for i: int in spots.size():
			var xz: PackedStringArray = spots[i].split(":")
			NetProgress.send_debug(&"teleport", [xz[0], xz[1]])
			await get_tree().create_timer(SPOT_SETTLE_SEC).timeout
			await _shot(map_id, "%s_s%d" % [map_id, i])
	get_tree().quit(0)


func _shot(map_id: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [args.get(ARG_SHOT_DIR, "."), file_name]
	get_viewport().get_texture().get_image().save_png(path)
	Net.log_line("map_look_shot", {"map": map_id, "now": String(NetWorld.client_map_id), "file": path})
