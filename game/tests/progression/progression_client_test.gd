extends Node
## Teste automático da progressão (Agente Q; docs/contracts-arrival.md, "Testes obrigatórios — Q").
## Roda no cliente quando ele sobe com --progression-autotest (NetProgress cria este nó), contra um
## servidor também em --progression-autotest (comandos de teste do ProgressionDebug).
##
## Cobre: barra 1–0; quest de título do Campo (aceitar, matar, provação, entregar) que ensina a
## skill 1 e dá o título; só UMA quest de título no treino; subir do 1 ao 10 e parar de ganhar XP;
## gastar pontos de atributo e de skill; títulos por skills (ramos e híbrido); lançar skills de cada
## tipo de alvo; negativos (sem mana, recarga, fora da barra, barra em combate). Capturas com
## --q-shots=DIR (precisa de janela: xvfb-run). Resultado: linhas "q_check" e "q_result".
## Agente H (GDD §8.1 "Tempo de uso na barra"): conjuração pelo nível da skill, DES/INT e itens;
## recarga por ESP/itens; poções instantâneas; usável com conjuração/recarga; andar interrompe;
## animação da barra (capturas h_anim_*: sombra da recarga, barra de conjuração, brilho "pronto").
## Terra de Pindorama v0.4 (TITULOS-E-SKILLS.md §3): ATQ pela arma (FOR/DES), lição que ensina skill,
## pré-requisito que esconde a lição, título de combinação só pela quest do ancião (variantes de verdade:
## chefe de dia não conta como atroz; chefe atroz derrubado conta) e sinais status_changed/healed.

const ARG_SHOTS: String = "q-shots"
const TOTAL_TIMEOUT_SEC: float = 900.0
const WAIT_SEC: float = 8.0
const LONG_WAIT_SEC: float = 30.0
const SETTLE_SEC: float = 0.6
const MSEC_PER_SEC: float = 1000.0
const NEAR_OFFSET: float = 1.6
const MASTER_BLADE: StringName = &"master_jatoba"
const MASTER_ARCANE: StringName = &"master_candeia"
const QUEST_BLADE: StringName = &"tf_blade_title"
const QUEST_ARCANE: StringName = &"tf_arcane_title"
const DUMMY: StringName = &"q_test_dummy"
const MAX_LEVEL_TRAINING: int = 10
const XP_CHUNK: int = 4000
## Skills lançadas no teste, por tipo de alvo.
const ALL_SKILLS: Array[StringName] = [&"blade_firm_strike", &"blade_charge", &"blade_steel_spin",
	&"blade_iron_stance", &"blade_horizon_cut", &"arcane_spark", &"arcane_frost_burst",
	&"arcane_creeping_flame", &"arcane_barrier", &"arcane_star_fall"]

var _events: Array[Dictionary] = []
var _progress: Dictionary = {}
var _local: NetEntity = null
var _checks: Dictionary = {}
var _dialogue_opts: Array = []
var _dialogue_npc: int = 0
var _dialogue_text: String = ""
var _args: Dictionary = {}
var _shot_index: int = 0
var _finished: bool = false


func _ready() -> void:
	for raw: String in OS.get_cmdline_user_args():
		var a: String = raw.trim_prefix("--")
		var eq: int = a.find("=")
		_args[a.substr(0, eq) if eq >= 0 else a] = a.substr(eq + 1) if eq >= 0 else ""
	ProgressionDebug.install_dummy_def()
	Net.local_player_spawned.connect(_on_spawned)
	NetProgress.progress_changed.connect(func(p: Dictionary) -> void:
		_progress = p
		_rec(&"progress", [p]))
	NetProgress.skill_cast.connect(func(e: int, s: StringName, t: int, p: Vector3, ms: int) -> void:
		_rec(&"cast", [e, s, t, p, ms]))
	NetProgress.cast_cancelled.connect(func(e: int, s: StringName) -> void: _rec(&"cast_cancelled", [e, s]))
	# Terra de Pindorama v0.4 (contrato ADENDO 4): efeitos de status e cura para a instância.
	NetProgress.status_changed.connect(func(e: int, st: StringName, sk: StringName, on: bool, sec: float) -> void:
		_rec(&"status", [e, st, sk, on, sec]))
	NetCombat.healed.connect(func(src: int, dst: int, amount: int) -> void: _rec(&"healed", [src, dst, amount]))
	ProgressionDebug.install_test_items()
	Net.dialogue_opened.connect(func(npc: int, _sp: String, tk: String, opts: Array) -> void:
		_dialogue_opts = opts
		_dialogue_npc = npc
		_dialogue_text = tk
		_rec(&"dialogue", [npc, tk, opts]))
	Net.dialogue_closed.connect(func() -> void: _rec(&"dialogue_closed", []))
	Net.system_message.connect(func(k: String, a: Array) -> void: _rec(&"system", [k, a]))
	get_tree().create_timer(TOTAL_TIMEOUT_SEC).timeout.connect(func() -> void:
		_check("total_timeout", false, "test did not finish in time")
		_finish())


func _rec(type: StringName, a: Array) -> void:
	_events.append({"t": type, "a": a})


func _check(check_name: String, ok: bool, detail: Variant = null) -> bool:
	_checks[check_name] = ok
	Net.log_line("q_check", {"check": check_name, "pass": ok, "detail": detail})
	return ok


func _cursor() -> int:
	return _events.size()


func _wait_event(type: StringName, from: int, timeout: float, pred: Callable = Callable()) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + int(timeout * MSEC_PER_SEC)
	var i: int = from
	while true:
		while i < _events.size():
			var e: Dictionary = _events[i]
			i += 1
			if e["t"] == type and (not pred.is_valid() or pred.call(e["a"])):
				return e
		if Time.get_ticks_msec() >= deadline:
			return {}
		await get_tree().process_frame
	return {}


func _wait_until(cond: Callable, timeout: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * MSEC_PER_SEC)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _sys_since(from: int, key: String) -> bool:
	for i: int in range(from, _events.size()):
		if _events[i]["t"] == &"system" and _events[i]["a"][0] == key:
			return true
	return false


## Comando de teste no servidor; espera o snapshot que ele manda no fim.
func _dbg(cmd: StringName, args: Array = []) -> void:
	var c: int = _cursor()
	NetProgress.send_debug(cmd, args)
	await _wait_event(&"progress", c, WAIT_SEC)


func _entities() -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	if _local == null or _local.get_parent() == null:
		return out
	for n: Node in _local.get_parent().get_children():
		if n is NetEntity and not n.is_queued_for_deletion():
			out.append(n as NetEntity)
	return out


func _find(def_id: StringName, near: Vector3 = Vector3.INF) -> NetEntity:
	var best: NetEntity = null
	var best_d: float = INF
	for e: NetEntity in _entities():
		# Só estágio 1: os médios (estágio 2) do Campo matariam o personagem de teste.
		if e.def_id != def_id or e.hp_ratio <= 0.0 or int(e.get(&"stage")) > 1:
			continue
		var d: float = e.position.distance_to(near) if near != Vector3.INF else 0.0
		if d < best_d:
			best_d = d
			best = e
	return best


func _teleport(p: Vector3) -> void:
	await _dbg(&"teleport", [p.x, p.z])
	await _wait_until(func() -> bool:
		return Vector2(_local.position.x - p.x, _local.position.z - p.z).length() < 1.5, WAIT_SEC)
	await _sleep(SETTLE_SEC)


func _talk(npc: NetEntity) -> Dictionary:
	await _teleport(npc.position + Vector3(NEAR_OFFSET, 0.0, 0.0))
	var c: int = _cursor()
	Net.send_interact(npc.get_target_id())
	return await _wait_event(&"dialogue", c, WAIT_SEC, func(a: Array) -> bool: return a[0] == npc.entity_id)


## Escolhe a opção com essa chave no diálogo aberto; espera o próximo nó ou o fechamento.
func _choose(key: String) -> bool:
	var i: int = _dialogue_opts.find(key)
	if i < 0:
		Net.log_line("q_debug", {"missing_option": key, "options": _dialogue_opts})
		return false
	var c: int = _cursor()
	Net.send_dialogue_choice(i)
	var e: Dictionary = await _wait_event(&"dialogue", c, WAIT_SEC)
	if e.is_empty():
		await _sleep(SETTLE_SEC)
	return true


func _quest(id: StringName) -> Dictionary:
	for q: Variant in _progress.get("quests", []):
		if StringName(str((q as Dictionary).get("id", ""))) == id:
			return q
	return {}


func _key(physical: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = physical
		ev.keycode = physical
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _hud() -> ProgressionHud:
	var view: Node = get_tree().root.get_node_or_null(^"Main/ClientView")
	var ui: GameUI = view.call(&"get_game_ui") as GameUI if view != null else null
	return ui.progression if ui != null else null


func _shot(label: String) -> void:
	var dir: String = _args.get(ARG_SHOTS, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/q_%02d_%s.png" % [dir, _shot_index, label]
	_shot_index += 1
	img.save_png(path)
	Net.log_line("q_shot", {"file": path})


# ---------------------------------------------------------------- roteiro

## Troca de mapa (arena das provações) recria o personagem: atualiza _local sem recomeçar o roteiro.
func _on_spawned(player: Node3D) -> void:
	_local = player as NetEntity
	if _started:
		return
	_started = true
	await _sleep(2.0)
	await _run()
	_finish()


var _started: bool = false



func _run() -> void:
	await _wait_until(func() -> bool: return not _progress.is_empty(), WAIT_SEC)
	_check("initial_progress", int(_progress.get("level", 0)) >= 1 \
			and "traveler" in _progress.get("titles", []), _progress.get("titles"))
	await _test_hotbar_ui()
	await _test_title_quest()
	await _test_levels_and_points()
	await _test_title_talk()
	await _test_titles_by_skills()
	await _test_cast_all_types()
	await _test_negatives()
	await _test_screens()
	await _test_cast_timing()
	await _test_pindorama()


func _test_hotbar_ui() -> void:
	var hud: ProgressionHud = _hud()
	_check("hotbar_10_slots", hud != null and hud.hotbar.slots.size() == Balance.cfg.hotbar_slots \
			and (_progress.get("hotbar", []) as Array).size() == Balance.cfg.hotbar_slots,
			(_progress.get("hotbar", []) as Array).size())
	var keys_ok: bool = true
	for i: int in ProgressionHud.HOTBAR_KEYS.size():
		var action := StringName(ProgressionHud.ACTION_HOTBAR_PREFIX + str(i + 1))
		var evs: Array[InputEvent] = InputMap.action_get_events(action) if InputMap.has_action(action) else []
		keys_ok = keys_ok and not evs.is_empty() \
				and (evs[0] as InputEventKey).physical_keycode == ProgressionHud.HOTBAR_KEYS[i]
	_check("hotbar_keys_1_to_0", keys_ok and ProgressionHud.HOTBAR_KEYS[9] == KEY_0)


func _test_title_quest() -> void:
	var jatoba: NetEntity = _find(MASTER_BLADE)
	var candeia: NetEntity = _find(MASTER_ARCANE)
	if not _check("masters_present", jatoba != null and candeia != null):
		return
	# Aceita as duas quests de título (as duas podem estar ativas; só uma conclui).
	var d: Dictionary = await _talk(jatoba)
	# Agente R (GDD §9.3): a conversa sobre o título só aparece no nível 10.
	_check("title_talk_hidden_below_10", not d.is_empty() and int(_progress.get("level", 0)) < 10 \
			and TitleTalk.OPTION_KEY not in _dialogue_opts, _dialogue_opts)
	var ok: bool = not d.is_empty() and await _choose("QUEST_TF_BLADE_TITLE_OPTION") \
			and await _choose("QUEST_OPT_ACCEPT")
	await _wait_until(func() -> bool: return not _quest(QUEST_BLADE).is_empty(), WAIT_SEC)
	_check("quest_blade_accepted", ok and not _quest(QUEST_BLADE).is_empty(), _dialogue_opts)
	d = await _talk(candeia)
	ok = not d.is_empty() and await _choose("QUEST_TF_ARCANE_TITLE_OPTION") \
			and await _choose("QUEST_OPT_ACCEPT")
	await _wait_until(func() -> bool: return not _quest(QUEST_ARCANE).is_empty(), WAIT_SEC)
	_check("quest_arcane_accepted", ok and not _quest(QUEST_ARCANE).is_empty())
	var hud: ProgressionHud = _hud()
	if hud != null:
		hud.quest_log.open()
		await _shot("quest_log")
		hud.quest_log.close()
	# Etapa 1: conversar com o Instrutor Bento.
	var bento: NetEntity = _find(&"instructor_bento")
	if bento != null:
		await _talk(bento)
		Net.send_dialogue_close()
	await _wait_until(func() -> bool: return int(_quest(QUEST_BLADE).get("step", 0)) >= 1, WAIT_SEC)
	_check("quest_talk_step_done", int(_quest(QUEST_BLADE).get("step", 0)) == 1, _quest(QUEST_BLADE))
	# Etapa 2 (coletar): quest de título é solo; item que não foi pego do chão pelo personagem não conta.
	await _dbg(&"give_item", [&"spinning_leaf", 10])
	await _sleep(SETTLE_SEC)
	_check("solo_collect_ignores_given_items", int(_quest(QUEST_BLADE).get("step", 0)) == 1
			and int(_quest(QUEST_BLADE).get("count", 0)) == 0, _quest(QUEST_BLADE))
	await _dbg(&"quest_step", [QUEST_BLADE, 2])
	# Etapa 3: 1 Redemoinho de verdade (combate de K) + os outros pelo evento de teste.
	var xp_before: int = int(_progress.get("total_xp", 0))
	var whirl: NetEntity = _find(&"prank_whirlwind", _local.position)
	var real_kill: bool = false
	if whirl != null:
		await _teleport(whirl.position + Vector3(1.0, 0.0, 0.0))
		NetCombat.send_attack(whirl.entity_id)
		real_kill = await _wait_until(func() -> bool:
			return int(_quest(QUEST_BLADE).get("count", 0)) >= 1 or int(_quest(QUEST_BLADE).get("step", 0)) >= 3,
			LONG_WAIT_SEC)
		NetCombat.send_stop_attack()
	_check("real_kill_counts_quest_and_xp", real_kill and int(_progress.get("total_xp", 0)) > xp_before,
			{"xp_before": xp_before, "xp": _progress.get("total_xp"), "quest": _quest(QUEST_BLADE)})
	var guard: int = 0
	while int(_quest(QUEST_BLADE).get("step", 0)) == 2 and not _quest(QUEST_BLADE).is_empty() and guard < 40:
		guard += 1
		await _dbg(&"kill", [&"prank_whirlwind", 16])
	_check("quest_kill_step_done", int(_quest(QUEST_BLADE).get("step", 0)) == 3, _quest(QUEST_BLADE))
	# Etapa 2: provação — o Mestre solta um Tatu-Pedra (spawn de K).
	d = await _talk(jatoba)
	var before: Array[NetEntity] = _entities()
	ok = not d.is_empty() and await _choose("QUEST_OPT_START_TRIAL")
	var spawned: bool = await _wait_until(func() -> bool:
		for e: NetEntity in _entities():
			if e.def_id == &"stone_armadillo" and e not in before:
				return true
		return false, WAIT_SEC)
	_check("trial_spawns_opponent", ok and spawned)
	await _dbg(&"kill", [&"stone_armadillo", 60])
	await _wait_until(func() -> bool: return bool(_quest(QUEST_BLADE).get("ready", false)), WAIT_SEC)
	_check("quest_ready_after_trial", bool(_quest(QUEST_BLADE).get("ready", false)), _quest(QUEST_BLADE))
	# Entrega: ganha o título e as cinco skills da árvore.
	var c: int = _cursor()
	d = await _talk(jatoba)
	ok = not d.is_empty() and await _choose("QUEST_OPT_REPORT") and await _choose("QUEST_OPT_TURN_IN")
	await _wait_until(func() -> bool: return QUEST_BLADE in _progress.get("quests_done", []), WAIT_SEC)
	var skills: Dictionary = _progress.get("skills", {})
	var title_skill_bundle := TitleService.skills_for_title(&"pindorama_blade_machete")
	var bundle_learned := true
	for skill_id: StringName in title_skill_bundle:
		bundle_learned = bundle_learned and skills.has(String(skill_id))
	_check("title_grants_all_tree_skills", ok and title_skill_bundle.size() == 5 and bundle_learned
			and (_progress.get("hotbar", []) as Array).has("blade_firm_strike"), skills)
	_check("title_earned_by_quest", "pindorama_blade_machete" in _progress.get("titles", []) \
			and _progress.get("displayed_title") == "pindorama_blade_machete", _progress.get("titles"))
	await _wait_until(func() -> bool: return _local.title_id == &"pindorama_blade_machete", WAIT_SEC)
	_check("title_replicated_on_entity", _local.title_id == &"pindorama_blade_machete", String(_local.title_id))
	# C3 (GDD §17.0.B): o título exibido veste a roupa dele (Facão Firme -> aprendiz) para todos os clientes: a
	# aparência replicada troca e o visual passa a usar a folha de corpo da roupa (com máscara, recolorível).
	# A roupa do título vem de TitleDef.outfit_id; sem roupa definida (arte ainda não aprovada) fica o Viajante.
	var title_def: TitleDef = Content.title(&"pindorama_blade_machete")
	var want_outfit: StringName = title_def.outfit_id if title_def != null and not String(title_def.outfit_id).is_empty() else &"traveler"
	await _wait_until(func() -> bool: return StringName(str(_local.appearance.get(&"outfit", ""))) == want_outfit, WAIT_SEC)
	_check("title_outfit_replicated", StringName(str(_local.appearance.get(&"outfit", ""))) == want_outfit, _local.appearance)
	# Roupa do título por recolor (TitleDef.cloth_colors): o título exibido vai na aparência e muda as cores.
	await _wait_until(func() -> bool: return StringName(str(_local.appearance.get(&"title_look", ""))) == &"pindorama_blade_machete", WAIT_SEC)
	# Com traje próprio (outfit_id) o recolor não vale: cloth_for fica vazio; sem traje, as cores do título.
	var look: PackedColorArray = CharacterLayers.cloth_for(_local.appearance)
	var want_look: PackedColorArray = title_def.cloth_colors if want_outfit == &"traveler" else PackedColorArray()
	_check("title_look_replicated", StringName(str(_local.appearance.get(&"title_look", ""))) == &"pindorama_blade_machete"
			and look == want_look, _local.appearance)
	var vis: Node = _local.get_visual()
	var base: String = str(vis.get(&"sprite_base")) if vis != null else ""
	var body_s: String = str(_local.appearance.get(&"body", "male"))
	if want_outfit != &"traveler" and ResourceLoader.exists("res://assets/characters/outfits/chr_%s_%s_idle.png" % [body_s, want_outfit]):
		_check("title_outfit_drawn", base.ends_with("outfits/chr_%s_%s" % [body_s, want_outfit]), base)
	else:
		# folhas da roupa ainda não instaladas (aguardando aprovação da arte): cai para o Viajante sem travar
		_check("title_outfit_drawn", base.ends_with("chr_traveler_%s" % body_s) or base.ends_with("chr_%s_base" % body_s), base)
	# Só uma quest de título no treino.
	_check("only_one_training_title_quest", _quest(QUEST_ARCANE).is_empty() \
			and bool(_progress.get("training_title_done", false)) \
			and _sys_since(c, "PROG_MSG_TRAINING_TITLE_CLOSED"), _progress.get("quests"))
	d = await _talk(candeia)
	_check("second_title_quest_not_offered", not d.is_empty() \
			and "QUEST_TF_ARCANE_TITLE_OPTION" not in _dialogue_opts, _dialogue_opts)
	Net.send_dialogue_close()
	await _sleep(SETTLE_SEC)


func _test_levels_and_points() -> void:
	var guard: int = 0
	while int(_progress.get("level", 1)) < MAX_LEVEL_TRAINING and guard < 40:
		guard += 1
		await _dbg(&"grant_xp", [XP_CHUNK])
	_check("level_1_to_10_in_training", int(_progress.get("level", 0)) == MAX_LEVEL_TRAINING,
			_progress.get("level"))
	var total: int = int(_progress.get("total_xp", 0))
	var c: int = _cursor()
	await _dbg(&"grant_xp", [XP_CHUNK])
	_check("xp_stops_at_10", int(_progress.get("level", 0)) == MAX_LEVEL_TRAINING \
			and int(_progress.get("total_xp", 0)) == total and int(_progress.get("xp", -1)) == 0 \
			and not bool(_progress.get("xp_allowed", true)) and _sys_since(c, "PROG_MSG_XP_CAPPED"),
			{"level": _progress.get("level"), "total": _progress.get("total_xp"), "was": total})
	var levels_gained: int = MAX_LEVEL_TRAINING - 1
	_check("points_per_level", int(_progress.get("attribute_points", 0)) \
			== levels_gained * Balance.cfg.attribute_points_per_level \
			and int(_progress.get("skill_points", 0)) == levels_gained * Balance.cfg.skill_points_per_level,
			{"attr": _progress.get("attribute_points"), "skill": _progress.get("skill_points")})
	var hud: ProgressionHud = _hud()
	if hud != null:
		hud.attributes_window.open()
		hud.attributes_window.call(&"_change", &"str", 1)
		hud.attributes_window.call(&"_change", &"vit", 1)
		await _shot("attributes")
		hud.attributes_window.call(&"_reset_pending")
		hud.attributes_window.close()
	# Gastar pontos de atributo.
	var str_before: int = int(Net.client_stats.get(&"str", 0))
	var pts: int = int(_progress.get("attribute_points", 0))
	c = _cursor()
	NetProgress.send_allocate_stats({&"str": 3, &"vit": 2})
	await _wait_event(&"progress", c, WAIT_SEC)
	await _wait_until(func() -> bool: return int(Net.client_stats.get(&"str", 0)) == str_before + 3, WAIT_SEC)
	_check("spend_attribute_points", int(_progress.get("attribute_points", 0)) == pts - 5 \
			and int(Net.client_stats.get(&"str", 0)) == str_before + 3,
			{"points": _progress.get("attribute_points"), "str": Net.client_stats.get(&"str")})
	c = _cursor()
	NetProgress.send_allocate_stats({&"int": 999})
	await _wait_event(&"progress", c, WAIT_SEC)
	_check("reject_too_many_attribute_points", int(_progress.get("attribute_points", 0)) == pts - 5)
	# Agente R (GDD §6.2): Sorte (SOR) começa em 5 e recebe pontos como os outros.
	var luk_before: int = int(Net.client_stats.get(&"luk", -1))
	c = _cursor()
	NetProgress.send_allocate_stats({&"luk": 2})
	await _wait_event(&"progress", c, WAIT_SEC)
	await _wait_until(func() -> bool: return int(Net.client_stats.get(&"luk", 0)) == luk_before + 2, WAIT_SEC)
	_check("spend_points_on_luck", luk_before == CharacterStats.BASE_ATTRIBUTE \
			and int(Net.client_stats.get(&"luk", 0)) == luk_before + 2 \
			and int(_progress.get("attribute_points", 0)) == pts - 7,
			{"before": luk_before, "luk": Net.client_stats.get(&"luk"), "points": _progress.get("attribute_points")})
	# Gastar ponto de skill.
	var sp: int = int(_progress.get("skill_points", 0))
	c = _cursor()
	NetProgress.send_skill_level_up(&"blade_firm_strike")
	await _wait_event(&"progress", c, WAIT_SEC)
	_check("spend_skill_point", int((_progress.get("skills", {}) as Dictionary).get("blade_firm_strike", 0)) == 2 \
			and int(_progress.get("skill_points", 0)) == sp - 1, _progress.get("skills"))
	c = _cursor()
	NetProgress.send_skill_level_up(&"arcane_star_fall")
	await _wait_event(&"progress", c, WAIT_SEC)
	_check("reject_level_up_unknown_skill", int(_progress.get("skill_points", 0)) == sp - 1)


## Agente R (GDD §9.3): no nível 10 cada Mestre fala do título que ensina (3 falas).
func _test_title_talk() -> void:
	var jatoba: NetEntity = _find(MASTER_BLADE)
	var d: Dictionary = await _talk(jatoba) if jatoba != null else {}
	_check("title_talk_visible_at_10", not d.is_empty() and TitleTalk.OPTION_KEY in _dialogue_opts, _dialogue_opts)
	var ok: bool = await _choose(TitleTalk.OPTION_KEY)
	_check("title_talk_what", ok and _dialogue_text.begins_with(TitleTalk.K_WHAT + "|TITLE_PINDORAMA_BLADE_MACHETE_NAME|"),
			_dialogue_text)
	await _shot("title_talk")
	ok = await _choose(TitleTalk.K_OPT_STYLE)
	_check("title_talk_style_lists_skills", ok and _dialogue_text.begins_with(TitleTalk.K_STYLE) \
			and _dialogue_text.contains("SKILL_BLADE_FIRM_STRIKE_NAME") \
			and not DialogueBox.resolve_text(_dialogue_text).contains("%s"), _dialogue_text)
	ok = await _choose(TitleTalk.K_OPT_CITY)
	_check("title_talk_city", ok and _dialogue_text == TitleTalk.K_CITY_OPEN + "|MAP_CITY_AWAKENING", _dialogue_text)
	ok = await _choose(TitleTalk.K_OPT_BACK)
	_check("title_talk_back_to_start", ok and TitleTalk.OPTION_KEY in _dialogue_opts, _dialogue_opts)
	Net.send_dialogue_close()
	await _sleep(SETTLE_SEC)
	# Mestre de nação ainda fechada: título de TITULOS-E-SKILLS.md §5 e "travessia fechada".
	var guiomar: NetEntity = _find(&"master_guiomar")
	d = await _talk(guiomar) if guiomar != null else {}
	ok = not d.is_empty() and await _choose(TitleTalk.OPTION_KEY)
	_check("title_talk_other_nation", ok and _dialogue_text.contains("RULES_TT_GUIOMAR_TITLE"), _dialogue_text)
	ok = ok and await _choose(TitleTalk.K_OPT_STYLE) and await _choose(TitleTalk.K_OPT_CITY)
	_check("title_talk_other_nation_closed", ok \
			and _dialogue_text == TitleTalk.K_CITY_CLOSED + "|REGION_PORTUGAL_NAME", _dialogue_text)
	Net.send_dialogue_close()
	await _sleep(SETTLE_SEC)


func _test_titles_by_skills() -> void:
	for s: StringName in ALL_SKILLS:
		if not (_progress.get("skills", {}) as Dictionary).has(String(s)):
			await _dbg(&"learn", [s])
	# Desde a v0.4 o título vem só da quest do Mestre (conhecer as skills não basta).
	var want: Array[String] = ["pindorama_arcane_firefly", "pindorama_blade_aroeira", "pindorama_blade_jaguar",
			"pindorama_arcane_crystal", "pindorama_arcane_boitata"]
	_check("titles_not_by_known_skills", not ("pindorama_blade_jaguar" in _progress.get("titles", [])),
			_progress.get("titles"))
	for t: String in want:
		await _dbg(&"grant_title", [StringName(t)])
	var titles: Array = _progress.get("titles", [])
	var ok: bool = true
	for t: String in want:
		ok = ok and t in titles
	_check("titles_granted_by_master_quests", ok, titles)
	# TITULOS-E-SKILLS.md §3.0 regra 4: Brasa no Facão agora é da quest do ancião, nunca automática.
	_check("combo_title_not_automatic", not ("pindorama_hybrid_ember" in titles), titles)
	var c: int = _cursor()
	NetProgress.send_set_title(&"pindorama_blade_jaguar")
	await _wait_event(&"progress", c, WAIT_SEC)
	await _wait_until(func() -> bool: return _local.title_id == &"pindorama_blade_jaguar", WAIT_SEC)
	_check("choose_displayed_title", _progress.get("displayed_title") == "pindorama_blade_jaguar" \
			and _local.title_id == &"pindorama_blade_jaguar")
	c = _cursor()
	NetProgress.send_set_title(&"pindorama_title_not_earned")
	await _wait_event(&"progress", c, WAIT_SEC)
	_check("reject_unearned_title", _progress.get("displayed_title") == "pindorama_blade_jaguar")


## Põe as skills na barra (fora de combate) e lança uma de cada tipo de alvo em bonecos.
func _test_cast_all_types() -> void:
	await _dbg(&"equip_item", [&"machete"])
	for i: int in ALL_SKILLS.size():
		NetProgress.send_hotbar_set(i, ALL_SKILLS[i])
	await _sleep(SETTLE_SEC * 2)
	var bar: Array = _progress.get("hotbar", [])
	var bar_ok: bool = true
	for i: int in ALL_SKILLS.size():
		bar_ok = bar_ok and i < bar.size() and bar[i] == String(ALL_SKILLS[i])
	_check("hotbar_set_all_slots", bar_ok, bar)
	# Bonecos: A ao lado (+2 x), B à frente (-6 z: longe da câmera, dentro da imagem).
	var me: Vector3 = _local.position
	await _dbg(&"spawn_dummy", [DUMMY, 2.0, 0.0])
	await _dbg(&"spawn_dummy", [DUMMY, 0.0, -6.0])
	await _sleep(SETTLE_SEC)
	var a: NetEntity = _find(DUMMY, me + Vector3(2.0, 0.0, 0.0))
	var b: NetEntity = _find(DUMMY, me + Vector3(0.0, 0.0, -6.0))
	if not _check("dummies_spawned", a != null and b != null and a != b):
		return
	var hud: ProgressionHud = _hud()
	# SINGLE pela tecla 1 (Golpe Firme, corpo a corpo, alvo = último monstro clicado/atacado).
	hud.call(&"_on_interact_requested", a.get_target_id())
	await _cast_via_key(0, a, "cast_single_key1_melee")
	# SINGLE à distância pela tecla 6 (Faísca, conjuração 0,4 s).
	hud.call(&"_on_interact_requested", b.get_target_id())
	await _cast_via_key(5, b, "cast_single_ranged_key6")
	# SELF_AREA (Giro de Aço) — A está a 2 células.
	await _cast_direct(&"blade_steel_spin", 0, _local.position, a, "cast_self_area")
	# CONE (Rajada Gélida) na direção de A.
	await _cast_direct(&"arcane_frost_burst", 0, a.position, a, "cast_cone")
	# LINE (Corte do Horizonte, 0,6 s) na direção de B.
	await _cast_direct(&"blade_horizon_cut", 0, b.position, b, "cast_line")
	# GROUND_AREA (Chama Rastejante: dano por segundo) em B.
	await _cast_direct(&"arcane_creeping_flame", 0, b.position, b, "cast_ground_area_dot")
	# GROUND_AREA com aviso (Queda Estelar) pela mira de verdade: tecla 0 + clique no chão.
	NetProgress.send_hotbar_set(9, &"arcane_star_fall")
	await _sleep(SETTLE_SEC * 2)
	await _cast_via_aim(9, b, "cast_ground_area_aim_key0")
	# SELF (Postura de Ferro) e ALLY_OR_SELF (Barreira Arcana): status no snapshot.
	await _cast_status(&"blade_iron_stance", "def_buff", "cast_self_buff")
	await _cast_status(&"arcane_barrier", "shield", "cast_ally_or_self_shield")
	# Investida (SINGLE com avanço + atordoamento) até B.
	var far_before: float = _local.position.distance_to(b.position)
	await _cast_direct(&"blade_charge", b.entity_id, Vector3.ZERO, b, "cast_charge_dash")
	await _sleep(SETTLE_SEC)
	_check("charge_moves_next_to_target", _local.position.distance_to(b.position) < minf(far_before, 2.5),
			{"before": far_before, "after": _local.position.distance_to(b.position)})
	if hud != null:
		hud.skills_window.open()
		await _shot("skills_window")
		hud.skills_window.close()
		await _shot("hotbar_cooldowns")


func _prep_cast() -> void:
	await _dbg(&"set_mp", [9999])
	await _dbg(&"reset_cooldowns")


func _hp_dropped(target: NetEntity, before: float) -> Callable:
	return func() -> bool: return is_instance_valid(target) and target.hp_ratio < before


func _cast_direct(skill: StringName, target_id: int, pos: Vector3, victim: NetEntity,
		check_name: String) -> void:
	await _prep_cast()
	var before: float = victim.hp_ratio
	var c: int = _cursor()
	NetProgress.send_cast(skill, target_id, pos)
	var cast: Dictionary = await _wait_event(&"cast", c, WAIT_SEC,
			func(a: Array) -> bool: return a[1] == skill)
	var hit: bool = await _wait_until(_hp_dropped(victim, before), WAIT_SEC)
	_check(check_name, not cast.is_empty() and hit, {"skill": String(skill), "hp": victim.hp_ratio})


func _cast_via_key(slot: int, victim: NetEntity, check_name: String) -> void:
	await _prep_cast()
	var before: float = victim.hp_ratio
	var c: int = _cursor()
	await _key(ProgressionHud.HOTBAR_KEYS[slot])
	var skill := StringName(str((_progress.get("hotbar", []) as Array)[slot]))
	var cast: Dictionary = await _wait_event(&"cast", c, WAIT_SEC,
			func(a: Array) -> bool: return a[1] == skill)
	var hit: bool = await _wait_until(_hp_dropped(victim, before), WAIT_SEC)
	_check(check_name, not cast.is_empty() and hit, {"skill": String(skill), "hp": victim.hp_ratio})


func _cast_via_aim(slot: int, victim: NetEntity, check_name: String) -> void:
	await _prep_cast()
	var hud: ProgressionHud = _hud()
	var view: ClientView = get_tree().root.get_node_or_null(^"Main/ClientView") as ClientView
	var before: float = victim.hp_ratio
	var c: int = _cursor()
	await _key(ProgressionHud.HOTBAR_KEYS[slot])
	var aiming: bool = hud.aim != null and hud.aim.is_aiming()
	var p: Vector2 = view.get_camera().unproject_position(victim.position) * view.get_view_scale() \
			+ view.get_view_offset()
	Input.warp_mouse(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("aim_preview")
	Net.log_line("q_debug", {"aim_click": str(p), "ground": str(view.pick_ground(p)),
			"aiming": hud.aim.is_aiming(), "victim": str(victim.position)})
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		Input.parse_input_event(ev)
		await get_tree().process_frame
	var cast: Dictionary = await _wait_event(&"cast", c, WAIT_SEC,
			func(a: Array) -> bool: return a[1] == &"arcane_star_fall")
	if not cast.is_empty():
		# Conjuração + aviso no chão: espera o impacto antes do próximo lançamento.
		await _sleep(int(cast["a"][4]) / MSEC_PER_SEC + SETTLE_SEC)
	var hit: bool = await _wait_until(_hp_dropped(victim, before), LONG_WAIT_SEC)
	_check(check_name, aiming and not cast.is_empty() and hit and int(cast["a"][4]) > 0,
			{"aiming": aiming, "cast": not cast.is_empty(), "hp": victim.hp_ratio})


func _cast_status(skill: StringName, kind: String, check_name: String) -> void:
	await _prep_cast()
	var c: int = _cursor()
	NetProgress.send_cast(skill, NetProgress.NO_TARGET, _local.position)
	var ok: bool = await _wait_until(func() -> bool:
		for s: Variant in _progress.get("statuses", []):
			if (s as Dictionary).get("kind") == kind and (s as Dictionary).get("skill") == String(skill):
				return true
		return false, WAIT_SEC)
	_check(check_name, ok and not (await _wait_event(&"cast", c, 0.1)).is_empty(), _progress.get("statuses"))


func _test_negatives() -> void:
	var c: int = _cursor()
	await _dbg(&"set_mp", [0])
	NetProgress.send_cast(&"blade_steel_spin", 0, _local.position)
	await _sleep(SETTLE_SEC)
	_check("reject_cast_without_mana", _sys_since(c, "PROG_MSG_NO_MANA") \
			and (await _wait_event(&"cast", c, 0.1)).is_empty())
	await _dbg(&"set_mp", [9999])
	c = _cursor()
	NetProgress.send_cast(&"blade_steel_spin", 0, _local.position)
	NetProgress.send_cast(&"blade_steel_spin", 0, _local.position)
	await _sleep(SETTLE_SEC)
	_check("reject_cast_on_cooldown", _sys_since(c, "PROG_MSG_SKILL_COOLDOWN"))
	c = _cursor()
	NetProgress.send_hotbar_set(3, &"")
	await _sleep(SETTLE_SEC)
	_check("reject_hotbar_change_in_combat", _sys_since(c, "PROG_MSG_HOTBAR_IN_COMBAT") \
			and bool(_progress.get("in_combat", false)) \
			and (_progress.get("hotbar", []) as Array)[3] == "blade_iron_stance")
	c = _cursor()
	NetProgress.send_cast(&"blade_clearing_sweep", 0, _local.position)
	await _sleep(SETTLE_SEC)
	_check("reject_cast_unknown_skill", (await _wait_event(&"cast", c, 0.1)).is_empty())


func _test_screens() -> void:
	var hud: ProgressionHud = _hud()
	if hud == null:
		return
	await _sleep(Balance.cfg.out_of_combat_sec + 1.0)
	hud.quest_log.open()
	hud.skills_window.open()
	await _shot("all_windows")
	hud.quest_log.close()
	hud.skills_window.close()
	# Agente R (GDD §9.5): menus na engrenagem (ícone + nome + atalho) e emotes recolhidos.
	var gear: GearMenu = hud.game_ui.gear
	_check("gear_menu_entries", gear != null and gear.entry_names() == PackedStringArray(["UI_SKILLS",
			"UI_ATTRIBUTES_WINDOW", "UI_QUEST_LOG", "UI_INVENTORY", "UI_CHARACTER", "UI_MENU"]) \
			and not gear.menu_panel.visible and not gear.emote_panel.visible,
			gear.entry_names() if gear != null else [])
	if gear != null:
		gear.toggle_menu()
		await _shot("gear_menu")
		(gear.entries.get_child(1) as Button).pressed.emit()
		await get_tree().process_frame
		_check("gear_entry_opens_window", hud.attributes_window.visible and not gear.menu_panel.visible)
		await _shot("gear_attributes")
		hud.attributes_window.close()
		gear.toggle_emotes()
		await _shot("gear_emotes")
		_check("gear_emotes_popup", gear.emote_panel.visible and not gear.menu_panel.visible)
		gear.close_popups()
		await _key(KEY_A)
		await get_tree().process_frame
		_check("shortcut_still_works", hud.attributes_window.visible)
		hud.attributes_window.close()


# ---------------------------------------------------------------- tempo de uso (Agente H, GDD §8.1)

const SPARK: StringName = &"arcane_spark"
const STAR_FALL: StringName = &"arcane_star_fall"
const MS_TOLERANCE: int = 2
const ANIM_FRAME_SEC: float = 0.12
const STRIP_ZOOM: int = 2


func _stats() -> Dictionary:
	return Net.client_stats


func _skill_level(id: StringName) -> int:
	return int((_progress.get("skills", {}) as Dictionary).get(String(id), 1))


func _inv_count(item_id: StringName) -> int:
	var n: int = 0
	for st: Variant in Net.client_inventory:
		if st is Dictionary and StringName(str((st as Dictionary).get("item", ""))) == item_id:
			n += int((st as Dictionary).get("qty", 0))
	return n


func _inv_slot(item_id: StringName) -> int:
	var inv: Array = Net.client_inventory
	for i: int in inv.size():
		if inv[i] is Dictionary and StringName(str((inv[i] as Dictionary).get("item", ""))) == item_id:
			return i
	return -1


## Espera os atributos do cliente satisfazerem cond (depois de equipar/distribuir).
func _wait_stats(cond: Callable) -> bool:
	return await _wait_until(func() -> bool: return cond.call(_stats()), WAIT_SEC)


## Lança a Faísca no boneco e devolve o cast_ms anunciado a todos (0 = não lançou). Espera terminar.
func _spark_cast_ms(victim: NetEntity) -> int:
	await _prep_cast()
	var c: int = _cursor()
	NetProgress.send_cast(SPARK, victim.entity_id, Vector3.ZERO)
	var ev: Dictionary = await _wait_event(&"cast", c, WAIT_SEC, func(a: Array) -> bool:
		return a[1] == SPARK and a[0] == _local.entity_id)
	if ev.is_empty():
		return 0
	var ms: int = int(ev["a"][4])
	await _sleep(ms / MSEC_PER_SEC + SETTLE_SEC)
	return ms


func _expected_spark_ms() -> int:
	return CastTiming.to_ms(CastTiming.skill_cast_sec(Content.skill(SPARK), _skill_level(SPARK), _stats()))


## Recorte da tela em volta da barra 1–0 (e da barra de conjuração em cima dela).
func _hotbar_shot(label: String, frames: Array[Image]) -> void:
	var dir: String = _args.get(ARG_SHOTS, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var hud: ProgressionHud = _hud()
	var img: Image = get_viewport().get_texture().get_image()
	var r: Rect2i = Rect2i(hud.hotbar.get_global_rect().grow(8.0))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop: Image = img.get_region(r)
	# Ampliada (vizinho mais próximo) para dar para ver a animação nos quadros.
	crop.resize(crop.get_width() * STRIP_ZOOM, crop.get_height() * STRIP_ZOOM, Image.INTERPOLATE_NEAREST)
	var path: String = "%s/h_anim_%02d_%s.png" % [dir, frames.size(), label]
	crop.save_png(path)
	frames.append(crop)
	Net.log_line("q_shot", {"file": path})


## Junta os quadros numa folha vertical (sequência da animação).
func _save_strip(frames: Array[Image], file_name: String) -> void:
	var dir: String = _args.get(ARG_SHOTS, "")
	if dir.is_empty() or frames.is_empty():
		return
	var w: int = 0
	var h: int = 0
	for f: Image in frames:
		w = maxi(w, f.get_width())
		h += f.get_height() + 2
	var sheet: Image = Image.create_empty(w, h, false, frames[0].get_format())
	sheet.fill(Color8(12, 10, 16))
	var y: int = 0
	for f: Image in frames:
		sheet.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i(0, y))
		y += f.get_height() + 2
	sheet.save_png("%s/%s" % [dir, file_name])
	Net.log_line("q_shot", {"file": "%s/%s" % [dir, file_name]})


func _test_cast_timing() -> void:
	var hud: ProgressionHud = _hud()
	var frames: Array[Image] = []
	# --- Poções: instantâneas e sem recarga, também pela barra (fora de combate para mudar a barra).
	await _dbg(&"give_item", [&"potion_mp_small", 5])
	await _dbg(&"give_item", [&"potion_hp_small", 3])
	await _wait_out_of_combat()
	NetProgress.send_hotbar_set(3, &"potion_mp_small")
	await _wait_until(func() -> bool: return (_progress.get("hotbar", []) as Array)[3] == "potion_mp_small", WAIT_SEC)
	await _dbg(&"set_mp", [0])
	await _wait_stats(func(st: Dictionary) -> bool: return int(st.get(&"mp", -1)) == 0)
	var c: int = _cursor()
	var mp_small: int = int(Content.item(&"potion_mp_small").use_effect[&"heal_mp"])
	var before_mp: int = _inv_count(&"potion_mp_small")
	var before_hp: int = _inv_count(&"potion_hp_small")
	for i: int in 3:
		Net.send_use_item(_inv_slot(&"potion_mp_small"))
	var hp_slot: int = _inv_slot(&"potion_hp_small")
	Net.send_use_item(hp_slot)
	Net.send_use_item(hp_slot)
	await _wait_until(func() -> bool: return _inv_count(&"potion_mp_small") == before_mp - 3 \
			and _inv_count(&"potion_hp_small") == before_hp - 2, WAIT_SEC)
	await _sleep(SETTLE_SEC)
	_check("potions_instant_spammable", _inv_count(&"potion_mp_small") == before_mp - 3 \
			and _inv_count(&"potion_hp_small") == before_hp - 2 and not _sys_since(c, SysMsg.ITEM_ON_COOLDOWN) \
			and int(_stats().get(&"mp", 0)) >= 3 * mp_small and int(_stats().get(&"mp", 0)) < 4 * mp_small \
			and (_progress.get("item_cooldowns", {}) as Dictionary).is_empty(),
			{"mp_left": _inv_count(&"potion_mp_small"), "hp_left": _inv_count(&"potion_hp_small"),
			"mp": _stats().get(&"mp"), "cds": _progress.get("item_cooldowns")})
	# Poção pela tecla 4: "pop" rápido, sem sombra de recarga.
	var pslot: HotbarSlot = hud.hotbar.slots[3]
	c = _cursor()
	await _key(KEY_4)
	await _hotbar_shot("potion_pop", frames)
	await _wait_until(func() -> bool: return _inv_count(&"potion_mp_small") == before_mp - 4, WAIT_SEC)
	_check("potion_hotbar_key_instant", _inv_count(&"potion_mp_small") == before_mp - 4 \
			and not pslot.is_cooling_down() and pslot.cooldown_fraction() == 0.0, pslot.cooldown_fraction())
	# --- Usável (não poção) com conjuração e recarga por grupo.
	await _dbg(&"give_item", [ProgressionDebug.TEST_SCROLL_ID, 3])
	var scroll: ItemDef = Content.item(ProgressionDebug.TEST_SCROLL_ID)
	c = _cursor()
	Net.send_use_item(_inv_slot(ProgressionDebug.TEST_SCROLL_ID))
	var sev: Dictionary = await _wait_event(&"cast", c, WAIT_SEC, func(a: Array) -> bool:
		return a[1] == ProgressionDebug.TEST_SCROLL_ID)
	var want_scroll: int = CastTiming.to_ms(CastTiming.item_cast_sec(scroll, _stats()))
	var during: int = _inv_count(ProgressionDebug.TEST_SCROLL_ID)
	await _wait_until(func() -> bool: return _inv_count(ProgressionDebug.TEST_SCROLL_ID) == 2 \
			and (_progress.get("item_cooldowns", {}) as Dictionary).has(String(ProgressionDebug.TEST_SCROLL_GROUP)), WAIT_SEC)
	var cds: Dictionary = _progress.get("item_cooldowns", {})
	_check("usable_item_has_cast_and_cooldown", not sev.is_empty() and absi(int(sev["a"][4]) - want_scroll) <= MS_TOLERANCE \
			and during == 3 and _inv_count(ProgressionDebug.TEST_SCROLL_ID) == 2 \
			and cds.has(String(ProgressionDebug.TEST_SCROLL_GROUP)),
			{"cast_ms": sev.get("a", [0, 0, 0, 0, -1])[4], "want": want_scroll, "during": during, "cds": cds})
	c = _cursor()
	Net.send_use_item(_inv_slot(ProgressionDebug.TEST_SCROLL_ID))
	await _sleep(SETTLE_SEC)
	_check("usable_item_group_cooldown", _sys_since(c, SysMsg.ITEM_ON_COOLDOWN) \
			and _inv_count(ProgressionDebug.TEST_SCROLL_ID) == 2)
	await _sleep(ProgressionDebug.TEST_SCROLL_COOLDOWN_SEC)
	# Andar interrompe o uso: o item não é gasto.
	c = _cursor()
	Net.send_use_item(_inv_slot(ProgressionDebug.TEST_SCROLL_ID))
	await _wait_event(&"cast", c, WAIT_SEC, func(a: Array) -> bool: return a[1] == ProgressionDebug.TEST_SCROLL_ID)
	Net.send_move_request(_local.position + Vector3(2.0, 0.0, 0.0))
	var ic: Dictionary = await _wait_event(&"cast_cancelled", c, WAIT_SEC)
	await _sleep(scroll.use_effect[&"cast_sec"] + SETTLE_SEC)
	_check("usable_item_cancel_on_move", not ic.is_empty() and _inv_count(ProgressionDebug.TEST_SCROLL_ID) == 2 \
			and _sys_since(c, SkillCaster.MSG_CAST_INTERRUPTED), {"cancel": ic, "left": _inv_count(ProgressionDebug.TEST_SCROLL_ID)})
	# --- Conjuração da skill: nível, DES/INT e itens.
	var dummy: NetEntity = _find(DUMMY, _local.position)
	if not _check("cast_timing_dummy", dummy != null):
		return
	await _teleport(dummy.position + Vector3(2.0, 0.0, 0.0))
	var spark: SkillDef = Content.skill(SPARK)
	var lvl1_ms: int = await _spark_cast_ms(dummy)
	var want1: int = _expected_spark_ms()
	var lvl1: int = _skill_level(SPARK)
	c = _cursor()
	NetProgress.send_skill_level_up(SPARK)
	await _wait_until(func() -> bool: return _skill_level(SPARK) == lvl1 + 1, WAIT_SEC)
	var lvl2_ms: int = await _spark_cast_ms(dummy)
	var want2: int = _expected_spark_ms()
	_check("cast_time_lower_skill_level_faster", lvl1_ms > 0 and absi(lvl1_ms - want1) <= MS_TOLERANCE \
			and absi(lvl2_ms - want2) <= MS_TOLERANCE and lvl1_ms < lvl2_ms \
			and absf(float(lvl2_ms) / lvl1_ms - CastTiming.skill_level_factor(lvl1 + 1) / CastTiming.skill_level_factor(lvl1)) < 0.02,
			{"lvl": [lvl1, lvl1 + 1], "ms": [lvl1_ms, lvl2_ms], "want": [want1, want2]})
	# DES/INT.
	var dex0: int = int(_stats().get(&"dex", 0))
	NetProgress.send_allocate_stats({&"dex": 10, &"int": 5})
	await _wait_stats(func(st: Dictionary) -> bool: return int(st.get(&"dex", 0)) == dex0 + 10)
	var attr_ms: int = await _spark_cast_ms(dummy)
	var want_attr: int = _expected_spark_ms()
	_check("cast_time_reduced_by_dex_int", attr_ms > 0 and attr_ms < lvl2_ms and absi(attr_ms - want_attr) <= MS_TOLERANCE,
			{"ms": attr_ms, "want": want_attr, "before": lvl2_ms, "dex": _stats().get(&"dex"), "int": _stats().get(&"int")})
	# Itens com cast_reduction (ipê +8%, tomo +10%).
	await _dbg(&"equip_item", [&"ipe_wand"])
	await _dbg(&"equip_item", [&"simple_tome"])
	await _wait_stats(func(st: Dictionary) -> bool: return int(st.get(&"cast_reduction", 0)) == 18)
	var item_ms: int = await _spark_cast_ms(dummy)
	var want_item: int = _expected_spark_ms()
	_check("cast_time_reduced_by_items", item_ms > 0 and item_ms < attr_ms and absi(item_ms - want_item) <= MS_TOLERANCE \
			and int(_stats().get(&"cast_reduction", 0)) == 18,
			{"ms": item_ms, "want": want_item, "before": attr_ms, "cast_reduction": _stats().get(&"cast_reduction")})
	# Recarga: o total vem do servidor com ESP/itens aplicados e começa depois da conjuração.
	var cd0: int = int((_progress.get("cooldown_totals", {}) as Dictionary).get(String(SPARK), 0))
	var want_cd0: int = CastTiming.to_ms(CastTiming.skill_cooldown_sec(spark, _stats()))
	var spi0: int = int(_stats().get(&"spi", 0))
	NetProgress.send_allocate_stats({&"spi": 5})
	await _wait_stats(func(st: Dictionary) -> bool: return int(st.get(&"spi", 0)) == spi0 + 5)
	await _dbg(&"equip_item", [&"seed_necklace"])
	await _wait_stats(func(st: Dictionary) -> bool: return int(st.get(&"cooldown_reduction", 0)) == 5)
	await _prep_cast()
	c = _cursor()
	NetProgress.send_cast(SPARK, dummy.entity_id, Vector3.ZERO)
	await _wait_event(&"cast", c, WAIT_SEC, func(a: Array) -> bool: return a[1] == SPARK)
	await _wait_until(func() -> bool:
		return str((_progress.get("casting", {}) as Dictionary).get("id", "")) == String(SPARK), 1.0)
	var casting: Dictionary = _progress.get("casting", {})
	var cd_during: bool = (_progress.get("cooldowns", {}) as Dictionary).has(String(SPARK))
	await _wait_until(func() -> bool: return (_progress.get("cooldowns", {}) as Dictionary).has(String(SPARK)), WAIT_SEC)
	var cd1: int = int((_progress.get("cooldown_totals", {}) as Dictionary).get(String(SPARK), 0))
	var want_cd1: int = CastTiming.to_ms(CastTiming.skill_cooldown_sec(spark, _stats()))
	_check("cooldown_reduced_by_spirit_and_items", absi(cd0 - want_cd0) <= MS_TOLERANCE and absi(cd1 - want_cd1) <= MS_TOLERANCE \
			and cd1 < cd0 and int(_stats().get(&"cooldown_reduction", 0)) == 5,
			{"before": cd0, "want_before": want_cd0, "after": cd1, "want": want_cd1, "spi": _stats().get(&"spi")})
	_check("cooldown_starts_after_cast", str(casting.get("id", "")) == String(SPARK) and not cd_during,
			{"casting": casting, "cd_during_cast": cd_during})
	# Dica da janela de skills com os valores efetivos.
	hud.skills_window.set_stats(_stats())
	hud.skills_window.call(&"_select", SPARK)
	var detail: String = (hud.skills_window.get(&"_detail") as Label).text
	_check("skills_window_effective_timing", detail.contains(SkillsWindow._sec(CastTiming.skill_cast_sec(spark, _skill_level(SPARK), _stats()))) \
			and detail.contains(SkillsWindow._sec(CastTiming.skill_cooldown_sec(spark, _stats()))) \
			and detail.contains(tr("UI_TIMING_ITEMS") % "18"), detail)
	# --- Andar interrompe a conjuração da skill (Queda Estelar, conjuração mais longa).
	await _prep_cast()
	var hp_before: float = dummy.hp_ratio
	c = _cursor()
	NetProgress.send_cast(STAR_FALL, 0, dummy.position)
	var sf: Dictionary = await _wait_event(&"cast", c, WAIT_SEC, func(a: Array) -> bool: return a[1] == STAR_FALL)
	await _sleep(0.2)
	var bar_casting: bool = hud.hotbar.is_casting() and hud.hotbar.casting_entry() == STAR_FALL
	Net.send_move_request(_local.position + Vector3(-2.0, 0.0, 0.0))
	var cc: Dictionary = await _wait_event(&"cast_cancelled", c, WAIT_SEC)
	await _sleep(0.05)
	var bar_cancelled: bool = hud.hotbar.cast_bar.state == CastBar.State.CANCELLED
	await _sleep((int(sf["a"][4]) if not sf.is_empty() else 0) / MSEC_PER_SEC + SETTLE_SEC)
	_check("cast_cancel_on_move", not sf.is_empty() and not cc.is_empty() and cc["a"][0] == _local.entity_id \
			and dummy.hp_ratio >= hp_before - 0.0001 and _sys_since(c, SkillCaster.MSG_CAST_INTERRUPTED) \
			and not (_progress.get("cooldowns", {}) as Dictionary).has(String(STAR_FALL)),
			{"cast": not sf.is_empty(), "cancel": cc, "hp": [hp_before, dummy.hp_ratio], "cds": _progress.get("cooldowns")})
	_check("hotbar_cast_bar_shown_and_cancelled", bar_casting and bar_cancelled,
			{"casting": bar_casting, "cancelled": bar_cancelled})
	await _test_hotbar_animation(dummy, frames)


## Sequência de quadros da barra: tecla, barra de conjuração enchendo, espaços apagados, sombra
## radial da recarga, brilho "pronto" e sem mana. Também a barrinha sobre a cabeça de outro.
func _test_hotbar_animation(dummy: NetEntity, frames: Array[Image]) -> void:
	var hud: ProgressionHud = _hud()
	await _teleport(dummy.position + Vector3(2.0, 0.0, 0.0))
	await _prep_cast()
	# Queda Estelar pela tecla 0 + clique: espaço afunda; barra de conjuração enche; outros apagados.
	var view: ClientView = get_tree().root.get_node_or_null(^"Main/ClientView") as ClientView
	var c: int = _cursor()
	await _key(ProgressionHud.HOTBAR_KEYS[9])
	await _hotbar_shot("press_key0", frames)
	var p: Vector2 = view.get_camera().unproject_position(dummy.position) * view.get_view_scale() + view.get_view_offset()
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		Input.parse_input_event(ev)
		await get_tree().process_frame
	var sf: Dictionary = await _wait_event(&"cast", c, WAIT_SEC, func(a: Array) -> bool: return a[1] == STAR_FALL)
	var dimmed: bool = false
	var own_fill: bool = false
	var t_end: int = Time.get_ticks_msec() + 1600
	var n: int = 0
	while hud.hotbar.is_casting() and Time.get_ticks_msec() < t_end:
		await _hotbar_shot("cast_%d" % n, frames)
		dimmed = dimmed or hud.hotbar.slots[0].is_dimmed()
		own_fill = own_fill or hud.hotbar.slots[9].get_node(^"Fx").get(&"cast_frac") > 0.0
		n += 1
		await _sleep(ANIM_FRAME_SEC)
	_check("hotbar_cast_animation", not sf.is_empty() and n >= 2 and dimmed and own_fill,
			{"frames": n, "dimmed": dimmed, "own_fill": own_fill})
	# Sombra radial girando + segundos (recarga da Queda Estelar e da Faísca).
	await _sleep(0.3)
	await _prep_cast_keep_cooldowns()
	var sw_frames: int = 0
	var fracs: Array[float] = []
	c = _cursor()
	NetProgress.send_cast(SPARK, dummy.entity_id, Vector3.ZERO)
	await _wait_event(&"cast", c, WAIT_SEC, func(a: Array) -> bool: return a[1] == SPARK)
	await _wait_until(func() -> bool: return hud.hotbar.slots[5].is_cooling_down(), WAIT_SEC)
	var spark_slot: HotbarSlot = hud.hotbar.slots[5]
	var glows0: int = spark_slot.ready_glows
	while spark_slot.is_cooling_down() and sw_frames < 20:
		fracs.append(spark_slot.cooldown_fraction())
		await _hotbar_shot("cooldown_%d" % sw_frames, frames)
		sw_frames += 1
		await _sleep(ANIM_FRAME_SEC * 2.0)
	# Brilho "pronto" logo depois que a recarga acaba.
	var glow_seen: float = 0.0
	for k: int in 4:
		glow_seen = maxf(glow_seen, spark_slot.glow_amount())
		await _hotbar_shot("ready_glow_%d" % k, frames)
		await _sleep(ANIM_FRAME_SEC)
	var decreasing: bool = fracs.size() >= 2 and fracs[0] > fracs[fracs.size() - 1]
	_check("hotbar_cooldown_sweep_and_ready_glow", decreasing and spark_slot.ready_glows > glows0 and glow_seen > 0.0 \
			and hud.hotbar.slots[9].is_cooling_down(),
			{"fracs": fracs, "glows": spark_slot.ready_glows - glows0, "glow_seen": glow_seen})
	# Sem mana: ícones tingidos.
	await _dbg(&"set_mp", [0])
	# A mana regenera: basta ficar abaixo do custo da Faísca.
	var tinted: bool = await _wait_until(func() -> bool: return not hud.hotbar.slots[5].has_mana(), WAIT_SEC)
	await _sleep(0.25)
	await _hotbar_shot("no_mana", frames)
	_check("hotbar_no_mana_tint", tinted, {"mp": _stats().get(&"mp"), "cost": Content.skill(SPARK).mana_cost})
	await _dbg(&"set_mp", [9999])
	_save_strip(frames, "h_anim_sequence.png")
	# Barrinha sobre a cabeça de outro que conjura (aqui o boneco, pelo mesmo caminho do evento).
	hud.call(&"_on_skill_cast", dummy.entity_id, SPARK, _local.entity_id, _local.position, 1500)
	await _sleep(0.5)
	var ob: CastBar = hud.cast_overlay.bar_for(dummy.entity_id)
	_check("overhead_cast_bar_for_others", ob != null and ob.is_casting() and ob.visible, ob)
	await _shot("overhead_cast_bar")


## A barra só muda fora de combate: espera (e, se preciso, vai para perto do Mestre, longe dos monstros).
func _wait_out_of_combat() -> void:
	if await _wait_until(func() -> bool: return not bool(_progress.get("in_combat", false)), LONG_WAIT_SEC):
		return
	var master: NetEntity = _find(MASTER_BLADE)
	if master != null:
		await _teleport(master.position + Vector3(NEAR_OFFSET, 0.0, NEAR_OFFSET))
	await _wait_until(func() -> bool: return not bool(_progress.get("in_combat", false)), LONG_WAIT_SEC)


## Mana cheia sem zerar as recargas (para ver a sombra da recarga anterior junto).
func _prep_cast_keep_cooldowns() -> void:
	await _dbg(&"set_mp", [9999])


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var failed: Array = []
	for k: String in _checks:
		if not _checks[k]:
			failed.append(k)
	Net.log_line("q_result", {"pass": failed.is_empty(), "checks": _checks.size(), "failed": failed})
	get_tree().quit(0 if failed.is_empty() else 1)


# ---------------------------------------------------------------- Terra de Pindorama v0.4

func _stats_now() -> Dictionary:
	return Net.client_stats


## Chefe vivo mais perto (estágio >= 3), ou null.
func _find_boss(def_id: StringName) -> NetEntity:
	for e: NetEntity in _entities():
		if e.def_id == def_id and e.hp_ratio > 0.0 and int(e.get(&"stage")) >= CombatRules.STAGE_BOSS:
			return e
	return null


func _quest_step(id: StringName) -> int:
	return int(_quest(id).get("step", -1))


func _test_pindorama() -> void:
	await _wait_out_of_combat()
	# ATQ pela arma (GDD §6.2, 30/09/2026): facão = FOR, arco = DES.
	await _dbg(&"equip_item", [&"machete"])
	await _wait_until(func() -> bool: return int(_stats_now().get(CharacterStats.K_ATK_ATTR, -1)) == 0, WAIT_SEC)
	var atk_machete: int = int(_stats_now().get(&"atk", 0))
	var attr_machete: int = int(_stats_now().get(CharacterStats.K_ATK_ATTR, -1))
	await _dbg(&"equip_item", [&"simple_bow"])
	await _wait_until(func() -> bool: return int(_stats_now().get(CharacterStats.K_ATK_ATTR, -1)) == 1, WAIT_SEC)
	var attr_bow: int = int(_stats_now().get(CharacterStats.K_ATK_ATTR, -1))
	_check("weapon_swap_changes_atk_attribute", attr_machete == CharacterStats.ATTRIBUTES.find(&"str")
			and attr_bow == CharacterStats.ATTRIBUTES.find(&"dex") and int(_stats_now().get(&"atk", 0)) != atk_machete,
			{"machete": [atk_machete, attr_machete], "bow": [_stats_now().get(&"atk"), attr_bow]})
	# No Campo de Treino só um título: a lição (que dá título) é recusada até sair do treino.
	var c_tr: int = _cursor()
	await _dbg(&"quest_accept", [&"lesson_bow_low_shot"])
	_check("second_title_blocked_in_training", _quest(&"lesson_bow_low_shot").is_empty()
			and _sys_since(c_tr, "PROG_MSG_QUEST_MISSING"))
	await _dbg(&"leave_training")
	# Lição do Mestre Taquari: Tiro Rasante, ensina a skill (e dá o título do arco).
	await _dbg(&"quest_accept", [&"lesson_bow_low_shot"])
	var accepted: bool = not _quest(&"lesson_bow_low_shot").is_empty()
	# A lição concede o título do arco: é quest de título, mais difícil a cada título já conquistado.
	var guard: int = 0
	while accepted and not bool(_quest(&"lesson_bow_low_shot").get("ready", false)) and guard < 30:
		guard += 1
		await _dbg(&"kill", [&"prank_whirlwind", 0])
	await _dbg(&"quest_turn_in", [&"lesson_bow_low_shot"])
	_check("lesson_quest_teaches_skill", accepted and int((_progress.get("skills", {}) as Dictionary).get("bow_low_shot", 0)) == 1
			and "lesson_bow_low_shot" in _progress.get("quests_done", []), _progress.get("skills"))
	# Ofício do título do arco (06/10/2026): Fazer Flechas gasta 1 Vara de Taquara e dá 10 Flechas Simples.
	await _wait_out_of_combat()
	var knows_fletch: bool = (_progress.get("skills", {}) as Dictionary).has("bow_fletching")
	await _dbg(&"give_item", [&"taquara_cane", 1])
	var arrows0: int = _inv_count(&"simple_arrow")
	var canes0: int = _inv_count(&"taquara_cane")
	# Como toda skill, precisa estar na barra (o jogador arrasta da janela de Skills); vai no último espaço.
	var c_bar: int = _cursor()
	NetProgress.send_hotbar_set(9, &"bow_fletching")
	await _wait_event(&"progress", c_bar, WAIT_SEC)
	NetProgress.send_cast(&"bow_fletching", NetProgress.NO_TARGET, _local.position)
	await _wait_until(func() -> bool: return _inv_count(&"simple_arrow") >= arrows0 + 10, LONG_WAIT_SEC)
	_check("title_bow_fletching_crafts_arrows", knows_fletch and _inv_count(&"simple_arrow") == arrows0 + 10
			and _inv_count(&"taquara_cane") == canes0 - 1,
			{"knows": knows_fletch, "arrows": [arrows0, _inv_count(&"simple_arrow")], "canes": [canes0, _inv_count(&"taquara_cane")]})
	# Pré-requisito da árvore: Flecha Dupla pede Tiro Rasante 3.
	var c: int = _cursor()
	await _dbg(&"quest_accept", [&"lesson_bow_double_arrow"])
	var refused: bool = _quest(&"lesson_bow_double_arrow").is_empty() and _sys_since(c, "PROG_MSG_QUEST_MISSING")
	await _dbg(&"skill_level", [&"bow_low_shot", 3])
	await _dbg(&"quest_accept", [&"lesson_bow_double_arrow"])
	# Desde a v0.5 o título do arco já concede a árvore inteira: a lição fica indisponível por já saber a skill.
	_check("lesson_prerequisite_gates_quest", refused and (not _quest(&"lesson_bow_double_arrow").is_empty()
			or (_progress.get("skills", {}) as Dictionary).has("bow_double_arrow")))
	NetProgress.send_quest_abandon(&"lesson_bow_double_arrow")
	# Ancião: Aço que Canta (Brasa no Facão). Tem Facão Firme e Luz de Vaga-lume.
	c = _cursor()
	# Títulos (os três da Vó) e renome 3 (rendido por eles) liberam a sub-história; nenhum nível exigido.
	await _dbg(&"quest_accept", [&"elder_aninha_root_fire"])
	_check("elder_quest_unlocked_by_titles_and_renome", not _quest(&"elder_aninha_root_fire").is_empty()
			and int(_progress.get("causos", 0)) >= 3, {"causos": _progress.get("causos")})
	NetProgress.send_quest_abandon(&"elder_aninha_root_fire")
	# Sub-história (renome 3, que os títulos acima já renderam): causo, brasas, chefe, causo, atroz, provação.
	await _dbg(&"quest_accept", [&"elder_ze_steel_song"])
	var elder_ok: bool = not _quest(&"elder_ze_steel_song").is_empty()
	await _dbg(&"quest_step", [&"elder_ze_steel_song", 1])
	# Quest de título é solo: brasa recebida (sem pegar do chão) não conta.
	await _dbg(&"give_item", [&"eternal_ember", 2])
	await _sleep(SETTLE_SEC)
	var given_ignored: bool = _quest_step(&"elder_ze_steel_song") == 1
	await _dbg(&"quest_step", [&"elder_ze_steel_song", 2])
	await _dbg(&"kill_variant", [&"enchanted_firefly", &"any"])
	var normal_ignored: bool = _quest_step(&"elder_ze_steel_song") == 2
	await _dbg(&"kill_variant", [&"enchanted_firefly", &"boss"])
	_check("elder_quest_variant_filter", elder_ok and given_ignored and normal_ignored
			and _quest_step(&"elder_ze_steel_song") == 3, _quest(&"elder_ze_steel_song"))
	await _dbg(&"quest_step", [&"elder_ze_steel_song", 4])
	# Chefes de verdade (variante lida do MonsterBrain/last_kill): de dia não conta como atroz.
	await _dbg(&"set_hp", [99999])
	await _dbg(&"equip_item", [&"machete"]) # o arco sem flechas não derruba nada
	Net.send_chat(&"local", "/dia") # dia forçado: o chefe comum não pode virar atroz sozinho
	await _sleep(SETTLE_SEC)
	await _dbg(&"spawn_boss", [&"stone_armadillo", 0, 3.0, 0.0])
	await _wait_until(func() -> bool: return _find_boss(&"stone_armadillo") != null, WAIT_SEC)
	Net.send_chat(&"local", "/derrubar chefe")
	await _wait_until(func() -> bool: return _find_boss(&"stone_armadillo") == null, WAIT_SEC)
	await _sleep(SETTLE_SEC)
	var day_ignored: bool = _quest_step(&"elder_ze_steel_song") == 4
	await _dbg(&"spawn_boss", [&"stone_armadillo", 1, 3.0, 0.0])
	await _wait_until(func() -> bool: return _find_boss(&"stone_armadillo") != null, WAIT_SEC)
	Net.send_chat(&"local", "/derrubar chefe")
	await _wait_until(func() -> bool: return _quest_step(&"elder_ze_steel_song") == 5, WAIT_SEC)
	_check("elder_quest_real_atroz_boss", day_ignored and _quest_step(&"elder_ze_steel_song") == 5,
			_quest(&"elder_ze_steel_song"))
	# Provação (fantoche de dois escudos) e entrega: título de combinação + Lâmina Faiscante.
	await _dbg(&"quest_trial", [&"elder_ze_steel_song"])
	# A provação é na arena: espera chegar e o fantoche nascer antes de derrubar.
	await _wait_until(func() -> bool: return _find(&"trial_twin_shield_puppet") != null, LONG_WAIT_SEC)
	await _dbg(&"kill", [&"trial_twin_shield_puppet", 0])
	await _wait_until(func() -> bool: return bool(_quest(&"elder_ze_steel_song").get("ready", false)), WAIT_SEC)
	await _dbg(&"quest_turn_in", [&"elder_ze_steel_song"])
	_check("combo_title_by_elder_quest", "pindorama_hybrid_ember" in _progress.get("titles", [])
			and (_progress.get("skills", {}) as Dictionary).has("hybrid_spark_blade"), _progress.get("titles"))
	await _test_pindorama_signals()
	await _test_protect_trial()
	await _test_title_crafts_and_pilfer()


## Ofícios dos títulos (06/10/2026): Curativo de Mateiro (Facão Firme) faz poções; Surrupiar (Garra da Onça)
## recusa chefe, tira um item da tabela de um monstro de verdade e só uma vez por monstro.
func _test_title_crafts_and_pilfer() -> void:
	await _wait_out_of_combat()
	await _dbg(&"set_hp", [99999])
	var knows_dressing: bool = (_progress.get("skills", {}) as Dictionary).has("blade_field_dressing")
	await _dbg(&"give_item", [&"spinning_leaf", 3])
	var pots0: int = _inv_count(&"potion_hp_small")
	var leaves0: int = _inv_count(&"spinning_leaf")
	var c_bar: int = _cursor()
	NetProgress.send_hotbar_set(9, &"blade_field_dressing")
	await _wait_event(&"progress", c_bar, WAIT_SEC)
	await _prep_cast()
	NetProgress.send_cast(&"blade_field_dressing", NetProgress.NO_TARGET, _local.position)
	await _wait_until(func() -> bool: return _inv_count(&"potion_hp_small") >= pots0 + 2, LONG_WAIT_SEC)
	_check("title_machete_field_dressing_crafts_potions", knows_dressing
			and _inv_count(&"potion_hp_small") == pots0 + 2 and _inv_count(&"spinning_leaf") == leaves0 - 3,
			{"knows": knows_dressing, "pots": [pots0, _inv_count(&"potion_hp_small")],
			"leaves": [leaves0, _inv_count(&"spinning_leaf")]})
	# Surrupiar: título da Onça (herda o Curativo), nível 10 para o teste não depender da sorte.
	await _dbg(&"grant_title", [&"pindorama_blade_jaguar"])
	await _wait_until(func() -> bool: return (_progress.get("skills", {}) as Dictionary).has("blade_pilfer"), WAIT_SEC)
	var knows_pilfer: bool = (_progress.get("skills", {}) as Dictionary).has("blade_pilfer")
	await _dbg(&"skill_level", [&"blade_pilfer", 10])
	c_bar = _cursor()
	NetProgress.send_hotbar_set(9, &"blade_pilfer")
	await _wait_event(&"progress", c_bar, WAIT_SEC)
	await _dbg(&"equip_item", [&"machete"])
	Net.send_chat(&"local", "/dia")
	await _sleep(SETTLE_SEC)
	await _dbg(&"spawn_boss", [&"stone_armadillo", 0, 3.0, 0.0])
	await _wait_until(func() -> bool: return _find_boss(&"stone_armadillo") != null, WAIT_SEC)
	var boss: NetEntity = _find_boss(&"stone_armadillo")
	var refused: bool = false
	if boss != null:
		await _prep_cast()
		var c0: int = _cursor()
		NetProgress.send_cast(&"blade_pilfer", boss.entity_id, boss.position)
		refused = await _wait_until(func() -> bool: return _sys_since(c0, "PROG_MSG_STEAL_REFUSED"), WAIT_SEC)
		Net.send_chat(&"local", "/derrubar chefe")
		await _wait_until(func() -> bool: return _find_boss(&"stone_armadillo") == null, WAIT_SEC)
	_check("pilfer_refuses_boss", knows_pilfer and boss != null and refused, {"knows": knows_pilfer})
	await _dbg(&"spawn_rare", [&"prank_whirlwind", 2.0, 0.0])
	await _sleep(SETTLE_SEC)
	var victim: NetEntity = _find(&"prank_whirlwind", _local.position + Vector3(2.0 * Balance.cfg.cell_size, 0.0, 0.0))
	if not _check("pilfer_victim_spawned", victim != null):
		return
	var inv0: int = _inv_total()
	var ok: bool = false
	var tries: int = 0
	while not ok and tries < 12 and is_instance_valid(victim) and victim.hp_ratio > 0.0:
		tries += 1
		await _prep_cast()
		var c1: int = _cursor()
		NetProgress.send_cast(&"blade_pilfer", victim.entity_id, victim.position)
		await _wait_until(func() -> bool:
			return _sys_since(c1, "PROG_MSG_STEAL_OK") or _sys_since(c1, "PROG_MSG_STEAL_FAILED"), WAIT_SEC)
		ok = _sys_since(c1, "PROG_MSG_STEAL_OK")
	await _wait_until(func() -> bool: return _inv_total() == inv0 + 1, WAIT_SEC)
	_check("pilfer_steals_one_item_from_real_monster", ok and _inv_total() == inv0 + 1,
			{"tries": tries, "inv": [inv0, _inv_total()]})
	await _prep_cast()
	var c2: int = _cursor()
	if is_instance_valid(victim):
		NetProgress.send_cast(&"blade_pilfer", victim.entity_id, victim.position)
	var again: bool = await _wait_until(func() -> bool: return _sys_since(c2, "PROG_MSG_STEAL_ALREADY"), WAIT_SEC)
	_check("pilfer_once_per_monster", again and _inv_total() == inv0 + 1, {"inv": _inv_total()})
	await _shot("pilfer")
	Net.send_chat(&"local", "/derrubar")
	await _wait_until(func() -> bool: return not is_instance_valid(victim) or victim.hp_ratio <= 0.0, WAIT_SEC)


func _inv_total() -> int:
	var n: int = 0
	for st: Variant in Net.client_inventory:
		if st is Dictionary:
			n += int((st as Dictionary).get("qty", 0))
	return n


## Sinais para o agente de efeitos: status_changed (prender, provocar) e healed.
func _test_pindorama_signals() -> void:
	await _wait_out_of_combat()
	await _dbg(&"equip_item", [&"machete"])
	for sk: StringName in [&"blade_root_grip", &"tank_shell_knock", &"support_herb_tea", &"arcane_star_step"]:
		await _dbg(&"learn", [sk])
	var slots: Array[StringName] = [&"blade_root_grip", &"tank_shell_knock", &"support_herb_tea", &"arcane_star_step"]
	for i: int in slots.size():
		NetProgress.send_hotbar_set(i, slots[i])
	await _sleep(SETTLE_SEC * 2)
	await _dbg(&"spawn_dummy", [DUMMY, 2.0, 0.0])
	await _sleep(SETTLE_SEC)
	var dummy: NetEntity = _find(DUMMY, _local.position + Vector3(2.0, 0.0, 0.0))
	if not _check("pindorama_dummy_spawned", dummy != null):
		return
	await _prep_cast()
	var c: int = _cursor()
	NetProgress.send_cast(&"blade_root_grip", 0, _local.position)
	var root: Dictionary = await _wait_event(&"status", c, WAIT_SEC, func(a: Array) -> bool:
		return a[0] == dummy.entity_id and a[1] == &"root" and a[3] == true)
	_check("status_changed_root_replicated", not root.is_empty() and float(root["a"][4]) > 0.0, root)
	await _prep_cast()
	c = _cursor()
	NetProgress.send_cast(&"tank_shell_knock", 0, _local.position)
	var taunt: Dictionary = await _wait_event(&"status", c, WAIT_SEC, func(a: Array) -> bool:
		return a[0] == dummy.entity_id and a[1] == &"taunt" and a[2] == &"tank_shell_knock")
	_check("status_changed_taunt_replicated", not taunt.is_empty(), taunt)
	var ended: Dictionary = await _wait_event(&"status", c, LONG_WAIT_SEC, func(a: Array) -> bool:
		return a[0] == dummy.entity_id and a[1] == &"root" and a[3] == false)
	_check("status_changed_end_replicated", not ended.is_empty(), ended)
	await _dbg(&"set_hp", [10])
	await _prep_cast()
	c = _cursor()
	NetProgress.send_cast(&"support_herb_tea", _local.entity_id, _local.position)
	var heal: Dictionary = await _wait_event(&"healed", c, WAIT_SEC, func(a: Array) -> bool:
		return a[1] == _local.entity_id)
	_check("healed_signal", not heal.is_empty() and heal["a"][0] == _local.entity_id and int(heal["a"][2]) > 0, heal)
	await _prep_cast()
	var before: Vector3 = _local.position
	var dest: Vector3 = before + Vector3(-3.0 * Balance.cfg.cell_size, 0.0, 0.0)
	NetProgress.send_cast(&"arcane_star_step", 0, dest)
	var moved: bool = await _wait_until(func() -> bool: return _local.position.distance_to(before) > Balance.cfg.cell_size, WAIT_SEC)
	_check("blink_moves_player", moved, {"before": before, "after": _local.position})


## Provação da Vó Aninha (TITULOS-E-SKILLS.md §3.3): proteger 3 mudas. Mudas aliadas (cura e escudo
## valem, jogador não ataca), ondas vão nas mudas, falha com as 3 caídas (e dá para tentar de novo),
## sucesso com pelo menos 1 de pé no fim.
func _seedlings() -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	for e: NetEntity in _entities():
		if e.def_id == &"pequi_seedling" and e.hp_ratio > 0.0:
			out.append(e)
	return out


func _test_protect_trial() -> void:
	const Q: StringName = &"elder_aninha_root_fire"
	await _wait_out_of_combat()
	await _dbg(&"set_hp", [99999])
	await _dbg(&"grant_title", [&"pindorama_bow_cerrado"])
	await _dbg(&"quest_accept", [Q])
	await _dbg(&"quest_step", [Q, 5])
	await _dbg(&"quest_trial", [Q])
	var spawned: bool = await _wait_until(func() -> bool: return _seedlings().size() == 3, WAIT_SEC)
	_check("protect_trial_spawns_3_seedlings", spawned and _quest_step(Q) == 5, _seedlings().size())
	if not spawned:
		return
	var sd: NetEntity = _seedlings()[0]
	var c: int = _cursor()
	NetCombat.send_attack(sd.entity_id)
	await _sleep(SETTLE_SEC * 2)
	_check("seedling_click_inspects_not_attacks", _sys_since(c, "PROG_MSG_PROTECTED_HP") and sd.hp_ratio >= 1.0, sd.hp_ratio)
	await _dbg(&"hurt_protected", [120])
	await _wait_until(func() -> bool: return sd.hp_ratio < 1.0, WAIT_SEC)
	await _prep_cast()
	c = _cursor()
	NetProgress.send_cast(&"support_herb_tea", sd.entity_id, sd.position)
	var heal: Dictionary = await _wait_event(&"healed", c, WAIT_SEC, func(a: Array) -> bool: return a[1] == sd.entity_id)
	_check("heal_works_on_seedling", not heal.is_empty() and int(heal["a"][2]) > 0, heal)
	await _prep_cast()
	c = _cursor()
	NetProgress.send_cast(&"arcane_barrier", sd.entity_id, sd.position)
	var shield: Dictionary = await _wait_event(&"status", c, WAIT_SEC, func(a: Array) -> bool:
		return a[0] == sd.entity_id and a[1] == &"shield" and a[3] == true)
	_check("shield_works_on_seedling", not shield.is_empty(), shield)
	var ids: Array = _seedlings().map(func(e: NetEntity) -> int: return e.entity_id)
	var chased: bool = await _wait_until(func() -> bool:
		for e: NetEntity in _entities():
			if e.def_id == &"prank_whirlwind" and int(e.get(&"target_id")) in ids:
				return true
		return false, LONG_WAIT_SEC)
	_check("waves_attack_seedlings", chased)
	# Falha: as 3 mudas caem.
	c = _cursor()
	await _dbg(&"kill_protected", [3])
	var lost: bool = await _wait_until(func() -> bool: return _sys_since(c, "PROG_MSG_TRIAL_PROTECT_LOST"), WAIT_SEC)
	_check("protect_trial_fails_when_all_fall", lost and _quest_step(Q) == 5)
	await _wait_until(func() -> bool: return _seedlings().is_empty(), WAIT_SEC)
	# Tentar de novo e vencer: 1 muda cai, as outras aguentam até o fim.
	await _dbg(&"quest_trial", [Q])
	await _wait_until(func() -> bool: return _seedlings().size() == 3, WAIT_SEC)
	await _dbg(&"kill_protected", [1])
	c = _cursor()
	await _dbg(&"trial_time", [1.0])
	var won: bool = await _wait_until(func() -> bool: return _sys_since(c, "PROG_MSG_TRIAL_PROTECTED"), WAIT_SEC)
	_check("protect_trial_success_with_survivors", won and bool(_quest(Q).get("ready", false)), _quest(Q))
