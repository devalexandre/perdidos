extends Node
## Captura água, passagem e arena no cliente conectado a servidor de teste com --dev-commands.
var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false
func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)
	get_tree().create_timer(120).timeout.connect(func() -> void: get_tree().quit(2))
func _on_spawned(_player: Node3D) -> void:
	if _started:
		return
	_started = true
	await get_tree().create_timer(5).timeout
	NetProgress.send_debug(&"set_hour", [12])
	NetProgress.send_debug(&"goto", ["cave_reino_encoberto_4"])
	await get_tree().create_timer(5).timeout
	NetProgress.send_debug(&"teleport", [0, -22])
	await get_tree().create_timer(2).timeout
	await _sequence("waterfall")
	NetProgress.send_debug(&"teleport", [0, -30])
	await get_tree().create_timer(2).timeout
	await _sequence("hidden_passage")
	NetProgress.send_debug(&"goto", ["cave_reino_encoberto_5"])
	await get_tree().create_timer(5).timeout
	NetProgress.send_debug(&"teleport", [0, -10])
	await get_tree().create_timer(2).timeout
	NetProgress.send_debug(&"spawn_boss", ["story_boitata", 1, 0, -6])
	await get_tree().create_timer(1).timeout
	await _sequence("final_arena")
	print("cave_capture_done")
	get_tree().quit()
func _sequence(label: String) -> void:
	var out: String = args.get("shot-dir", "user://cave-client")
	DirAccess.make_dir_recursive_absolute(out)
	for i: int in 12:
		await get_tree().create_timer(1.0 / 12.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [out, label, i])
	print("cave_capture_shot ", label, " map=", NetWorld.client_map_id)
