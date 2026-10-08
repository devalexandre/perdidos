extends Node
## Captura NO CLIENTE REAL do diário da história e da cena da fala da lenda (regra do dono: visual só é "pronto"
## com captura do jogo). Criado pelo main.gd com --autotest --autotest-script=res://tests/story/story_scene_capture.gd
## --shot-dir=DIR (tests/story/run_story_scene_capture.sh). Usa dados de exemplo por cima do estado real: aba
## Fragmentos, objetivo "Onde está Maria?", a cena do Curupira e a memória do rio do Boitatá.

const ARG_SHOT_DIR: String = "shot-dir"
const SETTLE_SEC: float = 4.0

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false
var _ui: GameUI = null


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		print("story_capture_timeout")
		get_tree().quit(2))


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC)
	var view: Node = main_node.get("client_view") if main_node != null else null
	_ui = view.call(&"get_game_ui") as GameUI if view != null else null
	if _ui == null:
		print("story_capture_no_ui")
		get_tree().quit(1)
		return
	var hud: ProgressionHud = _ui.progression
	var progress: Dictionary = NetProgress.client_progress.duplicate(true)
	progress["quests_done"] = ["arc1_ch6_iara", "arc1_final_boitata"]
	hud.quest_log.inventory_slots = [{"item": &"boiuna_words", "qty": 1}]
	hud.quest_log.open()
	hud.quest_log.set_progress(progress)
	await _wait(0.5)
	await _shot("journal_goal")
	hud.quest_log.set_tab(QuestLogWindow.TAB_FRAGMENTS)
	await _wait(0.5)
	await _shot("journal_fragments")
	hud.quest_log.close()
	var sc: StoryScene = _ui.story_scene
	sc.play(StoryFragments.make_scene(&"arc1_ch4_curupira", &"story_curupira", "QUEST_ARC1_CH4_DONE_4",
			["QUEST_ARC1_CH4_DONE_4"], []))
	await _wait(0.6)
	sc.advance()
	await _wait(0.2)
	await _shot("scene_legend")
	while sc.is_playing():
		sc.advance()
		await _wait(0.1)
	sc.play(StoryFragments.make_scene(&"arc1_final_boitata", &"story_boitata", "QUEST_ARC1_FINAL_DONE_2",
			["QUEST_ARC1_FINAL_DONE_2"], [&"river_memory"]))
	await _wait(0.6)
	sc.advance()
	await _wait(0.2)
	await _shot("scene_memory_intro")
	sc.advance()
	await _wait(1.9)
	await _shot("scene_memory_vision")
	sc.advance()
	await _wait(1.0)
	sc.advance()
	await _wait(1.0)
	await _shot("scene_memory_lines")
	sc.skip()
	await _wait(0.6)
	print("story_capture_done")
	get_tree().quit(0)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [dir, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("story_capture_shot ", path)
