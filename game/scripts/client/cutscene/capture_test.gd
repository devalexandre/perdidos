extends Node
## Teste de desenvolvimento (agente I). Rodar com xvfb:
##   OUT=/pasta BODY=male|female godot --path . res://scenes/cutscenes/capture_test.tscn
## Toca a cinemática inteira (tempo real acelerado), salva 1 captura por plano, testa pular e finished.
var out_dir: String = OS.get_environment("OUT") if OS.get_environment("OUT") != "" else OS.get_user_data_dir()
var body: StringName = StringName(OS.get_environment("BODY") if OS.get_environment("BODY") != "" else "male")

func _ready() -> void:
	if OS.get_environment("FLOW") == "1":
		_flow.call_deferred()
	else:
		_run.call_deferred()


## FLOW=1: título → Jogar → cinemática (1ª vez deste nome) → pular → conecta; 2ª vez não toca.
func _flow() -> void:
	var test_name := "IntroFlow%d" % (Time.get_ticks_msec() % 100000)
	# request_play grava o perfil em settings.cfg: guarda e devolve no fim.
	var backup: String = FileAccess.get_file_as_string(GameSettings.PATH) if FileAccess.file_exists(GameSettings.PATH) else ""
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	for k in 10: await get_tree().process_frame
	var title: Node = main.get("_title_screen")
	title.call("set_fields", test_name, &"female", "127.0.0.1", 7999)
	title.call("request_play")
	for k in 5: await get_tree().process_frame
	var cs: CutscenePlayer = null
	for c: Node in main.get_children():
		if c is CutscenePlayer:
			cs = c
	print("flow_cutscene_started=", cs != null, " body=", cs.body if cs else &"")
	if cs:
		cs.seek(3.0)
		for k in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir + "/flow_cutscene.png")
		cs.skip()
	for k in 60: await get_tree().process_frame
	print("flow_client_started=", main.get("client_view") != null, " seen=", IntroState.has_seen(test_name))
	var cfg := ConfigFile.new()
	cfg.load(IntroState.PATH)
	if cfg.has_section_key(IntroState.SECTION, IntroState._key(test_name)):
		cfg.erase_section_key(IntroState.SECTION, IntroState._key(test_name))
		cfg.save(IntroState.PATH)
	if not backup.is_empty():
		var f := FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	get_tree().quit(0)

func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, body, name])

func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://scenes/cutscenes/arrival.tscn")
	# 1) Reprodução inteira com speed alto; capturas no meio de cada plano.
	var p: CutscenePlayer = packed.instantiate()
	p.body = body
	p.use_audio = true
	get_tree().root.add_child(p)
	var fin: Array = []
	p.finished.connect(func(s: bool) -> void: fin.append(s))
	print("total ", p.total_duration, " shots ", p.shot_count())
	var mids: PackedFloat32Array = p.shot_midpoints()
	p.playing = false
	for i: int in mids.size():
		p.seek(mids[i])
		for k in 3: await get_tree().process_frame
		await _shot("%02d_%s" % [i + 1, p._shots[i]["id"]])
	# transições
	p.seek(p._starts[2] + 4.2); await _shot("t_white")
	p.seek(p._starts[4] + 0.7); await _shot("t_crossfade")
	p.seek(0.0)
	p.playing = true
	p.speed = 20.0
	var t0: int = Time.get_ticks_msec()
	while fin.is_empty() and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
	print("full_finished=", fin, " time=", p.time)
	p.queue_free()
	# 2) Pular com Esc.
	var q: CutscenePlayer = packed.instantiate()
	q.body = body
	get_tree().root.add_child(q)
	var fin2: Array = []
	q.finished.connect(func(s: bool) -> void: fin2.append(s))
	for k in 10: await get_tree().process_frame
	var ev := InputEventAction.new(); ev.action = &"ui_cancel"; ev.pressed = true
	Input.parse_input_event(ev)
	t0 = Time.get_ticks_msec()
	while fin2.is_empty() and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	print("skip_finished=", fin2)
	# 3) Pular pelo botão.
	var r: CutscenePlayer = CutscenePlayer.play_overlay(get_tree(), body)
	var fin3: Array = []
	r.finished.connect(func(s: bool) -> void: fin3.append(s))
	for k in 5: await get_tree().process_frame
	(r.get_node("Skip") as Button).pressed.emit()
	t0 = Time.get_ticks_msec()
	while fin3.is_empty() and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	await get_tree().process_frame
	print("button_skip_finished=", fin3, " overlay_freed=", get_tree().root.get_node_or_null("CutsceneOverlay") == null)
	# 4) IntroState
	var path := "user://intro_seen_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var a: bool = IntroState.has_seen("Zé Teste", path)
	IntroState.mark_seen("Zé Teste", path)
	print("intro_state before=", a, " after=", IntroState.has_seen("zé teste ", path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().quit(0)
