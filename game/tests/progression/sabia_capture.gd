extends Node
## Capturas no cliente real da Terra do Sabiá v0.4 (anciãos, Mestre Taquari, árvore do arco).
## Criado pelo main.gd com --autotest --autotest-script=res://tests/progression/sabia_capture.gd
## --shot-dir=DIR; o servidor precisa de --dev-commands (comandos de teste). Personagem na cidade.
## Roteiro: Vó Aninha sem os títulos (lenda em balões + "Volte quando...") → ganha os títulos →
## Vó Aninha oferece a quest → Seu Zé e Velho Tião sem títulos → Mestre Taquari (lição do arco) →
## aprende a árvore Flecha do Cerrado e abre a janela de skills.
## Imprime "sabia_capture {...}" por captura e "sabia_capture_done"; código 0.

const ARG_SHOT_DIR: String = "shot-dir"
## --sabia-role=trial: personagem novo no Campo de Treino (zona com combate) faz a provação das mudas.
const ARG_ROLE: String = "sabia-role"
const ROLE_TRIAL: String = "trial"
const WAIT_SEC: float = 8.0
const SETTLE_SEC: float = 0.8
const NEAR_OFFSET := Vector3(1.6, 0.0, 1.6)

var main_node: Node = null
var args: Dictionary[String, String] = {}

var _local: NetEntity = null
var _started: bool = false
var _opts: Array = []
var _text: String = ""
var _dialogue_seq: int = 0
var _progress_seq: int = 0
var _progress: Dictionary = {}
var _shot_index: int = 0
var _checks: Dictionary = {}


func _ready() -> void:
	Net.local_player_spawned.connect(func(p: Node3D) -> void:
		_local = p as NetEntity
		if not _started:
			_started = true
			_run.call_deferred())
	Net.dialogue_opened.connect(func(_npc: int, _sp: String, tk: String, opts: Array) -> void:
		_text = tk
		_opts = opts
		_dialogue_seq += 1)
	NetProgress.progress_changed.connect(func(p: Dictionary) -> void:
		_progress = p
		_progress_seq += 1)


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _wait(cond: Callable, timeout: float = WAIT_SEC) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _dbg(cmd: StringName, a: Array = []) -> void:
	var seq: int = _progress_seq
	NetProgress.send_debug(cmd, a)
	await _wait(func() -> bool: return _progress_seq > seq)
	await _sleep(0.3)


func _npc(def_id: StringName) -> NetEntity:
	if _local == null or _local.get_parent() == null:
		return null
	for n: Node in _local.get_parent().get_children():
		if n is NetEntity and (n as NetEntity).def_id == def_id:
			return n as NetEntity
	return null


## Posição dos marcadores (NpcPoints do Porto): chega perto antes (o cliente só vê entidades próximas).
const SPOTS: Dictionary = {&"elder_aninha": Vector3(-10.7, 0, 14.4), &"elder_tiao": Vector3(14.4, 0, -10.7),
		&"elder_ze_ferreiro": Vector3(10.7, 0, 14.4), &"master_taquari": Vector3(10.7, 0, -14.4)}


func _talk(def_id: StringName) -> bool:
	var spot: Vector3 = SPOTS.get(def_id, Vector3.ZERO) * 0.8
	await _dbg(&"teleport", [spot.x, spot.z])
	await _sleep(SETTLE_SEC)
	await _wait(func() -> bool: return _npc(def_id) != null, 20.0)
	var npc: NetEntity = _npc(def_id)
	if npc == null:
		return false
	Net.send_dialogue_close()
	var p: Vector3 = npc.position + NEAR_OFFSET
	await _dbg(&"teleport", [p.x, p.z])
	await _sleep(SETTLE_SEC)
	var seq: int = _dialogue_seq
	Net.send_interact(npc.get_target_id())
	var ok: bool = await _wait(func() -> bool: return _dialogue_seq > seq)
	await _sleep(SETTLE_SEC)
	return ok


func _choose(key: String) -> bool:
	var i: int = _opts.find(key)
	if i < 0:
		Net.log_line("sabia_capture_missing_option", {"key": key, "options": _opts})
		return false
	var seq: int = _dialogue_seq
	Net.send_dialogue_choice(i)
	await _wait(func() -> bool: return _dialogue_seq > seq)
	await _sleep(SETTLE_SEC)
	return true


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var prefix: String = "sabia_provacao" if args.get(ARG_ROLE, "") == ROLE_TRIAL else "sabia"
	var path: String = "%s/%s_%02d_%s.png" % [dir, prefix, _shot_index, label]
	_shot_index += 1
	get_viewport().get_texture().get_image().save_png(path)
	Net.log_line("sabia_capture", {"file": path, "text": _text, "options": _opts})


func _check(name: String, ok: bool) -> void:
	_checks[name] = ok
	Net.log_line("sabia_capture_check", {"check": name, "pass": ok, "text": _text, "options": _opts})


func _legend(elder: String) -> void:
	var up: String = elder.to_upper()
	await _choose("DLG_%s_START_OPT0" % up)
	await _shot("%s_lenda_1" % elder)
	await _choose("DLG_%s_LEGEND_1_OPT0" % up)
	await _shot("%s_lenda_2" % elder)
	await _choose("DLG_%s_LEGEND_2_OPT0" % up)
	await _shot("%s_precisa" % elder)


func _run() -> void:
	await _sleep(3.0)
	await _wait(func() -> bool: return not _progress.is_empty())
	if args.get(ARG_ROLE, "") == ROLE_TRIAL:
		await _run_trial()
		return
	# 1) Vó Aninha sem os títulos: lenda e "Volte quando tiver aprendido essas três coisas."
	await _talk(&"elder_aninha")
	await _shot("aninha_inicio_sem_titulos")
	await _legend("elder_aninha")
	_check("aninha_sem_titulos_so_volte", _opts == ["DLG_ELDER_ANINHA_NEED_OPT1"])
	await _choose("DLG_ELDER_ANINHA_NEED_OPT1")
	await _shot("aninha_volte_quando")
	_check("aninha_volte_quando", _text == "DLG_ELDER_ANINHA_COME_BACK")
	# 2) Ganha os títulos (Guarda do Cristal traz Luz de Vaga-lume pela herança) e volta.
	await _dbg(&"grant_title", [&"sabia_arcane_crystal"])
	await _dbg(&"grant_title", [&"sabia_bow_cerrado"])
	await _talk(&"elder_aninha")
	_check("aninha_oferta_no_inicio", "QUEST_ELDER_ANINHA_ROOT_FIRE_OPTION" in _opts)
	await _shot("aninha_inicio_com_titulos")
	await _legend("elder_aninha")
	_check("aninha_com_titulos_oferece", _opts == ["DLG_ELDER_ANINHA_NEED_OPT0"])
	await _choose("DLG_ELDER_ANINHA_NEED_OPT0")
	await _shot("aninha_oferta_da_quest")
	_check("aninha_oferta_texto", _text == "QUEST_ELDER_ANINHA_ROOT_FIRE_OFFER")
	# 3) Seu Zé e Velho Tião sem os títulos deles.
	for elder: String in ["elder_ze_ferreiro", "elder_tiao"]:
		await _talk(StringName(elder))
		await _shot("%s_inicio" % elder)
		await _legend(elder)
		await _choose("DLG_%s_NEED_OPT1" % elder.to_upper())
		await _shot("%s_volte_quando" % elder)
		_check("%s_volte_quando" % elder, _text == "DLG_%s_COME_BACK" % elder.to_upper())
	# 4) Mestre Taquari: lição do Tiro Rasante sem título.
	await _talk(&"master_taquari")
	await _shot("taquari_inicio")
	_check("taquari_licao_tiro_rasante", "QUEST_LESSON_BOW_LOW_SHOT_OPTION" in _opts)
	await _choose("QUEST_LESSON_BOW_LOW_SHOT_OPTION")
	await _shot("taquari_oferta_licao")
	Net.send_dialogue_close()
	# 5) Árvore Flecha do Cerrado aprendida, arco na mão, janela de skills (K).
	await _dbg(&"equip_item", [&"simple_bow"])
	await _dbg(&"learn_tree", [&"sabia_bow_cerrado", 3])
	await _dbg(&"learn_tree", [&"sabia_bow_gaviao", 1])
	await _sleep(SETTLE_SEC)
	var view: Node = main_node.get("client_view")
	var ui: Node = view.call(&"get_game_ui") if view != null and view.has_method(&"get_game_ui") else null
	var hud: Node = ui.get(&"progression") if ui != null else null
	if hud != null:
		(hud.get(&"skills_window") as Node).call(&"open")
		await _sleep(SETTLE_SEC)
		await _shot("janela_skills_arvore_arco")
		_check("titulo_flecha_do_cerrado", "sabia_bow_cerrado" in _progress.get("titles", []))
	var failed: Array = []
	for k: String in _checks:
		if not _checks[k]:
			failed.append(k)
	Net.log_line("sabia_capture_done", {"checks": _checks.size(), "failed": failed})
	get_tree().quit(0 if failed.is_empty() else 1)


func _seedlings() -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	if _local == null or _local.get_parent() == null:
		return out
	for n: Node in _local.get_parent().get_children():
		if n is NetEntity and (n as NetEntity).def_id == &"pequi_seedling" and (n as NetEntity).hp_ratio > 0.0:
			out.append(n as NetEntity)
	return out


## Provação da Vó Aninha: 3 mudas, ondas de redemoinhos, cura numa muda, uma muda cai, fim com sucesso.
func _run_trial() -> void:
	const Q: StringName = &"elder_aninha_root_fire"
	for i: int in 6:
		await _dbg(&"grant_xp", [5000])
	await _dbg(&"set_hp", [99999])
	await _dbg(&"grant_title", [&"sabia_arcane_crystal"])
	await _dbg(&"grant_title", [&"sabia_bow_cerrado"])
	await _dbg(&"learn", [&"support_herb_tea"])
	await _dbg(&"quest_accept", [Q])
	await _dbg(&"quest_step", [Q, 3])
	await _dbg(&"quest_trial", [Q])
	await _wait(func() -> bool: return _seedlings().size() == 3)
	_check("mudas_nasceram", _seedlings().size() == 3)
	await _sleep(6.0)
	await _dbg(&"hurt_protected", [90])
	await _sleep(1.0)
	var sd: Array[NetEntity] = _seedlings()
	if not sd.is_empty():
		NetCombat.send_attack(sd[0].entity_id)
		await _sleep(SETTLE_SEC)
	await _shot("mudas_e_ondas")
	if not sd.is_empty():
		await _dbg(&"set_mp", [9999])
		NetProgress.send_cast(&"support_herb_tea", sd[0].entity_id, sd[0].position)
		await _sleep(1.0)
		await _shot("cura_na_muda")
	await _dbg(&"kill_protected", [1])
	await _sleep(1.2)
	await _shot("muda_caiu")
	_check("uma_muda_caiu", _seedlings().size() == 2)
	await _dbg(&"trial_time", [1.0])
	await _sleep(2.0)
	await _shot("sucesso")
	var q: Dictionary = {}
	for e: Variant in _progress.get("quests", []):
		if StringName(str((e as Dictionary).get("id", ""))) == Q:
			q = e
	_check("provacao_concluida", bool(q.get("ready", false)))
	var failed: Array = []
	for k: String in _checks:
		if not _checks[k]:
			failed.append(k)
	Net.log_line("sabia_capture_done", {"checks": _checks.size(), "failed": failed})
	get_tree().quit(0 if failed.is_empty() else 1)
