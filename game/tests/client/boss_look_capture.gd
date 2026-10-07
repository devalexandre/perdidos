extends Node
## Foto de chefes/atrozes no cliente real, lado a lado com um chefe de referência (comparar a arte).
## Criado pelo main.gd com --autotest --autotest-script=res://tests/client/boss_look_capture.gd --shot-dir=DIR
## --map=MAPA --bosses=id:atroz,id:atroz,... [--ref=stone_armadillo] [--spots=x:z,...] [--hour=H];
## servidor com --dev-commands (goto, teleport, spawn_boss). Cada chefe vai num ponto (spots, em ordem) com a
## referência ao lado: <id>_s3.png / <id>_s4.png.

const SETTLE_SEC: float = 6.0
const SPAWN_SEC: float = 1.6

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	if args.has("hour"):
		NetProgress.send_debug(&"set_hour", [args["hour"]])
	await get_tree().create_timer(SETTLE_SEC).timeout
	var map_id: String = args.get("map", "")
	if map_id != "" and NetWorld.client_map_id != StringName(map_id):
		NetProgress.send_debug(&"goto", [map_id])
		await get_tree().create_timer(SETTLE_SEC).timeout
	var spots: PackedStringArray = args.get("spots", "").split(",", false)
	var ref: String = args.get("ref", "stone_armadillo")
	var bosses: PackedStringArray = args.get("bosses", "").split(",", false)
	for i: int in bosses.size():
		var parts: PackedStringArray = bosses[i].split(":")
		var atroz: int = int(parts[1]) if parts.size() > 1 else 0
		if i < spots.size():
			var xz: PackedStringArray = spots[i].split(":")
			NetProgress.send_debug(&"teleport", [xz[0], xz[1]])
			await get_tree().create_timer(2.5).timeout
		NetProgress.send_debug(&"spawn_boss", [ref, 0, -6, -1])
		NetProgress.send_debug(&"spawn_boss", [parts[0], atroz, 5, -1])
		await get_tree().create_timer(SPAWN_SEC).timeout
		await _shot("%s_s%d" % [parts[0], 4 if atroz else 3])
	get_tree().quit(0)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [args.get("shot-dir", "."), file_name]
	get_viewport().get_texture().get_image().save_png(path)
	Net.log_line("boss_look_shot", {"file": path, "map": String(NetWorld.client_map_id)})
