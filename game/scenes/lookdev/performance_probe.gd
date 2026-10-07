extends Node
## Diagnóstico temporário no cliente real; sem alterar configurações persistidas.
func _ready() -> void:
	_run.call_deferred()

func _sample(label: String) -> void:
	await get_tree().create_timer(3.0).timeout
	print("PROBE ", label, " fps=", Engine.get_frames_per_second(), " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS)*1000, " physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)

func _run() -> void:
	await get_tree().create_timer(12.0).timeout
	await _sample("baseline")
	for view in get_tree().root.find_children("*", "ClientView", true, false):
		view.get("_game_view").material = null
	await _sample("no_screen_post")
	get_tree().quit()
