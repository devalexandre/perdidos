extends Node
## Validação do P2 ("não parecer papel", GDD §17.0.C) no CLIENTE REAL: roda main.tscn normal, entra com
## personagem novo e, por pedidos reais de movimento/ataque ao servidor:
##  - mede fluidez (tempo de quadro, CPU de processo, CPU/GPU de renderização da SubViewport do mundo);
##  - salva capturas 1920x1080 (nascimento, luta, zonas);
##  - salva sequências curtas recortadas (respiração parada, balanço do andar, reação ao golpe).
##   godot --path game --resolution 1920x1080 res://scenes/lookdev/p2_tour.tscn -- --name=X --port=P \
##       --p2-out=/dir [--p2-steps=perf,spawn,seq,fight,zones] [--p2-vsync=0]
## Imprime linhas "p2 perf {...}" (JSON) e "p2 shot <arquivo>".

const STEP_M: float = 16.0
const SETTLE_SEC: float = 2.0
const FIGHT_POINT := Vector3(-12.0, 0.0, 38.0)
const ZONES := {"japao": 3.0, "egito": 208.0, "nordico": 270.0}
const ZONE_STAND_R: float = 58.5
const SEQ_CROP := Vector2i(220, 260)

var _out := "user://p2_tour"
var _steps: PackedStringArray = ["perf", "spawn", "seq", "fight", "zones"]
var _vsync := true
var _player: Node3D = null
var _view: ClientView = null
var _frame_ms: PackedFloat32Array = []
var _proc_ms: PackedFloat32Array = []
var _rcpu_ms: PackedFloat32Array = []
var _rgpu_ms: PackedFloat32Array = []
var _sampling := false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--p2-out="):
			_out = a.trim_prefix("--p2-out=")
		elif a.begins_with("--p2-steps="):
			_steps = a.trim_prefix("--p2-steps=").split(",")
		elif a.begins_with("--p2-vsync="):
			_vsync = a.trim_prefix("--p2-vsync=") != "0"
	DirAccess.make_dir_recursive_absolute(_out)
	_fit_window()
	if not _vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


## O mouse real (monitor do dono) não pode clicar/pairar no jogo durante a validação.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()


## Janela sem borda de 1920x1080 exatos no primeiro monitor 1080p (a decoração da janela encolheria a imagem).
func _fit_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := Vector2i(1920, 1080)
	for i in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_size(i) == want:
			DisplayServer.window_set_current_screen(i)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(i))
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			return


func _process(delta: float) -> void:
	if not _sampling:
		return
	_frame_ms.append(delta * 1000.0)
	_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var rid := _world_rid()
	if rid.is_valid():
		_rcpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(rid)
				+ RenderingServer.get_frame_setup_time_cpu())
		_rgpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))


func _world_rid() -> RID:
	if _view == null:
		return RID()
	var vp: SubViewport = _view.get_node_or_null(^"SubViewport") as SubViewport
	return vp.get_viewport_rid() if vp != null else RID()


func _run() -> void:
	for i in 900:
		await get_tree().process_frame
		var views := get_tree().root.find_children("*", "ClientView", true, false)
		_view = views.front() if not views.is_empty() else null
		for n: Node in get_tree().root.find_children("*", "", true, false):
			if n is Node3D and n.has_method(&"is_local_player") and bool(n.call(&"is_local_player")):
				_player = n
				break
		if _player != null and _view != null:
			break
	if _player == null:
		print("p2: sem jogador local")
		get_tree().quit(1)
		return
	RenderingServer.viewport_set_measure_render_time(_world_rid(), true)
	await _wait(4.0)
	if "perf" in _steps:
		await _perf("spawn_idle", 6.0)
		_spin_camera(true)
		await _perf("spawn_rotating", 5.0)
		_spin_camera(false)
		_view.camera_yaw = 0.0
		await _wait(1.0)
	if "bisect" in _steps:
		await _bisect()
	if "spawn" in _steps:
		_shot("00_spawn")
		var crop := _crop_around(_player, Vector2i(360, 420))
		crop.save_png(_out.path_join("00_spawn_crop.png"))
		_view.camera_zoom = Balance.cfg.camera_zoom_min
		await _wait(0.8)
		_shot("00_spawn_zoom_min")
		_view.camera_zoom = Balance.cfg.camera_zoom_max
		await _wait(0.8)
		_shot("00_spawn_zoom_max")
		_view.camera_zoom = 1.0
		_view.camera_yaw = deg_to_rad(135.0)
		await _wait(1.0)
		_shot("00_spawn_yaw135")
		_view.camera_yaw = 0.0
		await _wait(0.5)
	if "seq" in _steps:
		await _seq_idle()
		await _seq_walk()
	if "fight" in _steps:
		await _fight()
	if "zones" in _steps:
		for zone: String in ZONES:
			var a := deg_to_rad(float(ZONES[zone]))
			var look_out := Vector3(cos(a), 0, sin(a))
			await _walk_to(look_out * ZONE_STAND_R, "perf" in _steps and zone == ZONES.keys()[0])
			_view.camera_yaw = atan2(-look_out.x, -look_out.z)
			await _wait(SETTLE_SEC)
			_shot("zone_" + zone)
			if "perf" in _steps:
				await _perf("zone_" + zone, 4.0)
			_view.camera_yaw = 0.0
	get_tree().quit(0)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


var _spin_tween: Tween = null


func _spin_camera(on: bool) -> void:
	if _spin_tween != null:
		_spin_tween.kill()
		_spin_tween = null
	if on:
		_spin_tween = create_tween().set_loops()
		_spin_tween.tween_property(_view, ^"camera_yaw", _view.camera_yaw + TAU, 4.0).from(_view.camera_yaw)


func _perf(label: String, sec: float) -> void:
	# A captura de tela anterior (leitura da GPU + PNG) trava o quadro seguinte: não entra na medida.
	for i in 3:
		await get_tree().process_frame
	_frame_ms.clear()
	_proc_ms.clear()
	_rcpu_ms.clear()
	_rgpu_ms.clear()
	_sampling = true
	await _wait(sec)
	_sampling = false
	var info := {"label": label, "frames": _frame_ms.size()}
	info["fps_avg"] = snappedf(1000.0 / maxf(0.001, _mean(_frame_ms)), 0.1)
	info["frame_ms_p50"] = snappedf(_pct(_frame_ms, 0.5), 0.01)
	info["frame_ms_p99"] = snappedf(_pct(_frame_ms, 0.99), 0.01)
	info["frame_ms_max"] = snappedf(_pct(_frame_ms, 1.0), 0.01)
	info["frames_over_20ms"] = Array(_frame_ms).filter(func(v: float) -> bool: return v > 20.0).size()
	var spikes := []
	for i in _frame_ms.size():
		if _frame_ms[i] > 40.0:
			spikes.append([i, snappedf(_frame_ms[i], 0.1)])
	info["spikes_over_40ms"] = spikes
	info["process_ms_avg"] = snappedf(_mean(_proc_ms), 0.01)
	info["render_cpu_ms_avg"] = snappedf(_mean(_rcpu_ms), 0.01)
	info["render_gpu_ms_avg"] = snappedf(_mean(_rgpu_ms), 0.01)
	var rid := _world_rid()
	info["draw_calls"] = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	info["shadow_draw_calls"] = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	info["primitives"] = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	info["shadow_primitives"] = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	info["objects"] = RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	info["vsync"] = _vsync
	info["adapter"] = RenderingServer.get_video_adapter_name()
	print("p2 perf ", JSON.stringify(info))
	var f := FileAccess.open(_out.path_join("perf.jsonl"), FileAccess.READ_WRITE if FileAccess.file_exists(
			_out.path_join("perf.jsonl")) else FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(JSON.stringify(info))


static func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


static func _pct(a: PackedFloat32Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[clampi(int(round((b.size() - 1) * p)), 0, b.size() - 1)]


func _shot(name: String) -> void:
	var path := _out.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("p2 shot ", path, " fps=", Engine.get_frames_per_second())


func _walk_to(target: Vector3, measure: bool = false) -> void:
	if measure:
		for i in 3:
			await get_tree().process_frame
		_frame_ms.clear()
		_proc_ms.clear()
		_rcpu_ms.clear()
		_rgpu_ms.clear()
		_sampling = true
	for step in 40:
		var pos := _player.global_position
		var d := target - pos
		d.y = 0
		if d.length() < 1.5:
			break
		var goal := pos + d.normalized() * minf(d.length(), STEP_M)
		_view.move_requested.emit(goal)
		await _wait(minf(d.length(), STEP_M) * 0.24 + 0.4)
	if measure:
		_sampling = false
		# Reaproveita o relatório com o que foi coletado andando.
		var keep := [_frame_ms.duplicate(), _proc_ms.duplicate(), _rcpu_ms.duplicate(), _rgpu_ms.duplicate()]
		var info := {"label": "walking", "frames": (keep[0] as PackedFloat32Array).size(),
			"fps_avg": snappedf(1000.0 / maxf(0.001, _mean(keep[0])), 0.1),
			"frame_ms_p50": snappedf(_pct(keep[0], 0.5), 0.01), "frame_ms_p99": snappedf(_pct(keep[0], 0.99), 0.01),
			"frame_ms_max": snappedf(_pct(keep[0], 1.0), 0.01), "process_ms_avg": snappedf(_mean(keep[1]), 0.01),
			"render_cpu_ms_avg": snappedf(_mean(keep[2]), 0.01), "render_gpu_ms_avg": snappedf(_mean(keep[3]), 0.01),
			"vsync": _vsync}
		print("p2 perf ", JSON.stringify(info))
		var f := FileAccess.open(_out.path_join("perf.jsonl"), FileAccess.READ_WRITE if FileAccess.file_exists(
				_out.path_join("perf.jsonl")) else FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(JSON.stringify(info))


## Recorte em volta de uma entidade (pés no terço inferior).
func _crop_around(node: Node3D, size: Vector2i) -> Image:
	var img := get_viewport().get_texture().get_image()
	var feet := _view.get_camera().unproject_position(node.global_position)
	var r := Rect2i(Vector2i(int(feet.x) - size.x / 2, int(feet.y) - int(size.y * 0.78)), size)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r)


func _save_strip(frames: Array[Image], name: String, cols: int = 8) -> void:
	if frames.is_empty():
		return
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var rows := int(ceil(frames.size() / float(cols)))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var f := frames[i]
		f.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((i % cols) * w, (i / cols) * h))
	var path := _out.path_join(name + ".png")
	sheet.save_png(path)
	print("p2 shot ", path)


func _seq_idle() -> void:
	var frames: Array[Image] = []
	for i in 16:
		await _wait(0.15)
		frames.append(_crop_around(_player, SEQ_CROP))
	_save_strip(frames, "seq_idle_breathing")


func _seq_walk() -> void:
	var frames: Array[Image] = []
	var goal := _player.global_position + Vector3(6.0, 0.0, 0.0)
	_view.move_requested.emit(goal)
	await _wait(0.25)
	for i in 16:
		await _wait(0.05)
		frames.append(_crop_around(_player, SEQ_CROP))
	_save_strip(frames, "seq_walk_bob")
	await _wait(1.2)


func _nearest_monster() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e: Node3D in NetCombat.all_entities():
		if StringName(str(e.get(&"kind"))) != &"monster" or float(e.get(&"hp_ratio")) <= 0.0:
			continue
		var d := e.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _fight() -> void:
	await _walk_to(FIGHT_POINT)
	await _wait(1.0)
	var mon := _nearest_monster()
	if mon == null:
		print("p2: nenhum monstro perto")
		return
	_shot("fight_00_approach")
	var tid := "e:%d" % int(mon.get(&"entity_id"))
	_view.interact_requested.emit(tid)
	var frames: Array[Image] = []
	var shots := 0
	for i in 120:
		await _wait(0.05)
		if not is_instance_valid(mon):
			break
		if i >= 20 and frames.size() < 32:
			frames.append(_crop_around(mon, Vector2i(260, 240)))
		if i in [30, 60, 90]:
			_shot("fight_%02d" % (shots + 1))
			shots += 1
	_save_strip(frames, "seq_fight_hit")
	await _wait(3.0)
	_shot("fight_after")


## Liga/desliga sistemas do cliente e mede o tempo de quadro de cada estado (achar o custo de CPU).
func _bisect() -> void:
	await _perf("bisect_base", 3.0)
	var groups := {
		"minimap": get_tree().root.find_children("*", "Minimap", true, false),
		"game_ui": get_tree().root.find_children("*", "GameUI", true, false),
		"sprites": get_tree().root.find_children("*", "DirectionalSprite3D", true, false),
		"combat_fx": get_tree().root.find_children("*", "CombatFx", true, false),
		"client_view": [_view],
	}
	var nodes := get_tree().root.find_children("*", "", true, false)
	print("p2 nodes total=", nodes.size(), " processing=", nodes.filter(func(n: Node) -> bool: return n.is_processing()).size(),
			" physics=", nodes.filter(func(n: Node) -> bool: return n.is_physics_processing()).size())
	var counts := {}
	for n: Node in nodes:
		if n.is_processing() or n.is_physics_processing():
			var k: String = n.get_class() if n.get_script() == null else String((n.get_script() as Script).resource_path.get_file())
			counts[k] = int(counts.get(k, 0)) + 1
	print("p2 processing by type: ", counts)
	for g: String in groups:
		var list: Array = groups[g]
		for n: Node in list:
			n.set_process(false)
			n.set_physics_process(false)
		await _perf("bisect_no_" + g, 3.0)
		for n: Node in list:
			n.set_process(true)
			n.set_physics_process(true)
	var vp: SubViewport = _view.get_node(^"SubViewport")
	var old := vp.render_target_update_mode
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await _perf("bisect_no_world_render", 3.0)
	vp.render_target_update_mode = old
	var hud: Control = _view.get_node(^"Hud")
	hud.visible = false
	await _perf("bisect_no_hud", 3.0)
	hud.visible = true
