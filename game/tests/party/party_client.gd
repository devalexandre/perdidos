extends Node
## Autoteste do GRUPO e dos MAPAS COMPARTILHADOS (decisão do dono em 30/09/2026), no cliente real.
## Criado pelo main.gd com --autotest --autotest-script=res://tests/party/party_client.gd e:
##   --party-role=ana|bia|caio   papel no roteiro (o nome do personagem vem de --name)
##   --party-names=A,B,C         nomes dos três (na ordem ana, bia, caio)
##   --party-phase=training|hunt roteiro (Campo de Treino com personagens novos | Porto → Campos de Pindorama)
##   --sync-dir=DIR              pasta das barreiras entre os processos (um arquivo por papel e passo)
##   --shot-dir=DIR              capturas (só com janela; sem janela não captura)
## Servidor: --dev-commands (atalhos de teleporte, XP e provação) e --drop-chance-mult (drop sempre cai).
## Imprime "party_check {...}" por verificação e "party_done {...}"; código 0 = tudo passou.
## Rodar com tests/party/run_party_test.sh.

const ARG_ROLE: String = "party-role"
const ARG_NAMES: String = "party-names"
const ARG_PHASE: String = "party-phase"
const ARG_SYNC: String = "sync-dir"
const ARG_SHOT: String = "shot-dir"
const ROLE_ANA: String = "ana"
const ROLE_BIA: String = "bia"
const ROLE_CAIO: String = "caio"
const PHASE_HUNT: String = "hunt"
const WAIT_SEC: float = 12.0
const BARRIER_SEC: float = 240.0
const SETTLE_SEC: float = 0.8
const KIND_MONSTER: StringName = &"monster"
const KIND_DROP: StringName = &"drop"
const KIND_PLAYER: StringName = &"player"
const WHIRL: StringName = &"prank_whirlwind"
const TRIAL_QUEST: StringName = &"tf_blade_title"
const TRIAL_MONSTER: StringName = &"stone_armadillo"

var main_node: Node = null
var args: Dictionary[String, String] = {}

var _role: String = ""
var _names: Dictionary[String, String] = {}
var _local: NetEntity = null
var _started: bool = false
var _spawn_seq: int = 0
var _progress: Dictionary = {}
var _progress_seq: int = 0
var _inventory: Array = []
var _system: Array[String] = []
var _chats: Array[Dictionary] = []
var _lists: Array[Dictionary] = []
var _deaths: Dictionary[int, bool] = {}
## entity_id do alvo -> golpes deste cliente (amount > 0).
var _my_hits: Dictionary[int, int] = {}
## Golpes recebidos por este cliente: source_id -> quantos.
var _hits_on_me: Dictionary[int, int] = {}
var _checks: Dictionary = {}
var _shot_index: int = 0


func _ready() -> void:
	_role = args.get(ARG_ROLE, ROLE_ANA)
	var list: PackedStringArray = args.get(ARG_NAMES, "PAna,PBia,PCaio").split(",")
	for i: int in [ROLE_ANA, ROLE_BIA, ROLE_CAIO].size():
		_names[[ROLE_ANA, ROLE_BIA, ROLE_CAIO][i]] = list[i] if i < list.size() else ""
	Net.local_player_spawned.connect(func(p: Node3D) -> void:
		_local = p as NetEntity
		_spawn_seq += 1
		if not _started:
			_started = true
			_run.call_deferred())
	NetProgress.progress_changed.connect(func(p: Dictionary) -> void:
		_progress = p
		_progress_seq += 1)
	Net.inventory_changed.connect(func(slots: Array) -> void: _inventory = slots)
	Net.system_message.connect(func(key: String, _a: Array) -> void: _system.append(key))
	Net.chat_received.connect(func(ch: StringName, from: String, text: String, _id: int) -> void:
		_chats.append({"channel": ch, "from": from, "text": text}))
	NetParty.player_list_received.connect(func(kind: StringName, entries: Array) -> void:
		_lists.append({"kind": kind, "entries": entries}))
	NetCombat.entity_died.connect(func(id: int) -> void: _deaths[id] = true)
	NetCombat.hit.connect(func(src: int, dst: int, amount: int, _c: bool, _d: int, _r: float) -> void:
		if _local == null:
			return
		if src == _local.entity_id and amount > 0:
			_my_hits[dst] = int(_my_hits.get(dst, 0)) + 1
		if dst == _local.entity_id:
			_hits_on_me[src] = int(_hits_on_me.get(src, 0)) + 1)
	get_tree().create_timer(1100.0).timeout.connect(func() -> void:
		_check("tempo_esgotado", false, "o roteiro passou do tempo")
		_finish())


# ================================================================ utilitários

func _me() -> String:
	return _names[_role]


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _wait(cond: Callable, timeout: float = WAIT_SEC) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(0.1).timeout
	return cond.call()


func _check(name: String, ok: bool, detail: Variant = null) -> void:
	_checks[name] = ok
	Net.log_line("party_check", {"role": _role, "check": name, "pass": ok, "map": String(NetWorld.client_map_id),
			"detail": str(detail) if detail != null else ""})


func _ui() -> GameUI:
	var cv: Node = main_node.get("client_view") if main_node != null else null
	return cv.call(&"get_game_ui") as GameUI if cv != null and cv.has_method(&"get_game_ui") else null


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot_index += 1
	var path: String = "%s/%s_%02d_%s.png" % [dir, _role, _shot_index, label]
	get_viewport().get_texture().get_image().save_png(path)
	Net.log_line("party_shot", {"role": _role, "file": path})


func _sync_path(role: String, step: String) -> String:
	return "%s/%s.%s" % [args.get(ARG_SYNC, "/tmp"), role, step]


## Grava um dado para os outros processos (valor de texto).
func _put(step: String, value: String = "1") -> void:
	var f := FileAccess.open(_sync_path(_role, step), FileAccess.WRITE)
	f.store_string(value)
	f.close()


func _get_from(role: String, step: String) -> String:
	var p: String = _sync_path(role, step)
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func _wait_from(role: String, step: String, timeout: float = BARRIER_SEC) -> String:
	await _wait(func() -> bool: return FileAccess.file_exists(_sync_path(role, step)), timeout)
	return _get_from(role, step)


## Barreira: todos os papéis vivos chegam ao passo antes de seguir.
func _barrier(step: String, roles: Array = []) -> void:
	_put("barrier_" + step)
	var who: Array = roles if not roles.is_empty() else _roles()
	var ok: bool = await _wait(func() -> bool:
		for r: String in who:
			if not FileAccess.file_exists(_sync_path(r, "barrier_" + step)):
				return false
		return true, BARRIER_SEC)
	if not ok:
		_check("barreira_" + step, false, who)


func _roles() -> Array:
	var out: Array = []
	for r: String in [ROLE_ANA, ROLE_BIA, ROLE_CAIO]:
		if not _names[r].is_empty():
			out.append(r)
	return out


func _dbg(cmd: StringName, a: Array = []) -> void:
	var seq: int = _progress_seq
	NetProgress.send_debug(cmd, a)
	await _wait(func() -> bool: return _progress_seq > seq, 5.0)
	await _sleep(0.3)


func _chat(text: String, channel: StringName = &"local") -> void:
	Net.send_chat(channel, text)
	await _sleep(1.15)


func _tp(p: Vector3) -> void:
	if not p.is_finite():
		Net.log_line("party_tp_skipped", {"role": _role})
		return
	await _dbg(&"teleport", [p.x, p.z])
	await _sleep(SETTLE_SEC)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _entities(kind: StringName, def_id: StringName = &"", alive: bool = true) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Node3D in NetCombat.all_entities():
		if StringName(str(e.get(&"kind"))) != kind:
			continue
		if not def_id.is_empty() and StringName(str(e.get(&"def_id"))) != def_id \
				and MonsterDef.species_of(StringName(str(e.get(&"def_id")))) != def_id:
			continue
		if alive and float(e.get(&"hp_ratio")) <= 0.0:
			continue
		out.append(e)
	return out


func _nearest(list: Array[Node3D], to: Vector3 = Vector3.INF) -> Node3D:
	var at: Vector3 = to if to != Vector3.INF else _local.global_position
	var best: Node3D = null
	for e: Node3D in list:
		if best == null or _flat(e.global_position, at) < _flat(best.global_position, at):
			best = e
	return best


func _player(name: String) -> NetEntity:
	for e: Node3D in _entities(KIND_PLAYER, &"", false):
		if str(e.get(&"display_name")) == name:
			return e as NetEntity
	return null


func _total_xp() -> int:
	return int(_progress.get("total_xp", 0))


func _items_total() -> int:
	var n: int = 0
	for s: Variant in _inventory:
		if s is Dictionary:
			n += int((s as Dictionary).get("qty", 0))
	return n


func _quest(id: StringName) -> Dictionary:
	for e: Variant in _progress.get("quests", []):
		if StringName(str((e as Dictionary).get("id", ""))) == id:
			return e
	return {}


func _sys_since(mark: int, key: String) -> bool:
	return key in _system.slice(mark)


func _wait_sys(mark: int, key: String, timeout: float = WAIT_SEC) -> bool:
	return await _wait(func() -> bool: return _sys_since(mark, key), timeout)


func _party_size() -> int:
	return (NetParty.client_party.get(NetParty.K_MEMBERS, []) as Array).size()


func _spend_points() -> void:
	var pts: int = int(_progress.get("attribute_points", 0))
	if pts <= 0:
		return
	var strength: int = pts * 3 / 5
	var seq: int = _progress_seq
	NetProgress.send_allocate_stats({"str": strength, "vit": pts - strength})
	await _wait(func() -> bool: return _progress_seq > seq, 5.0)


func _vec_str(v: Vector3) -> String:
	return "%f,%f,%f" % [v.x, v.y, v.z]


func _str_vec(s: String) -> Vector3:
	var p: PackedStringArray = s.split(",")
	return Vector3(p[0].to_float(), p[1].to_float(), p[2].to_float()) if p.size() == 3 else Vector3.INF


func _portal(portal_id: String, dest: StringName) -> bool:
	var m: Node = _map()
	var area: Node3D = m.get_node_or_null(NodePath("Interactables/" + portal_id)) as Node3D if m != null else null
	if area == null:
		_check("portal_%s_existe" % portal_id, false)
		return false
	# Conta a chegada desde antes do teleporte: a frente do portal pode já estar dentro da área dele.
	var seq: int = _spawn_seq
	await _tp(area.get_meta(&"approach_position", area.global_position))
	if NetWorld.client_map_id != dest:
		Net.send_interact("m:" + portal_id)
	var ok: bool = await _wait(func() -> bool: return _spawn_seq > seq and NetWorld.client_map_id == dest, 60.0)
	await _sleep(3.0)
	_check("portal_%s_para_%s" % [portal_id, dest], ok, NetWorld.client_map_id)
	return ok


func _map() -> Node:
	if _local == null or not is_instance_valid(_local) or _local.get_parent() == null:
		return null
	return _local.get_parent().get_parent().get_node_or_null(^"Map")


## Ponto de nascimento dos redemoinhos (marcador Spawns/ da espécie), ou INF.
func _whirl_spawn() -> Vector3:
	var m: Node = _map()
	var spawns: Node = m.get_node_or_null(^"Spawns") if m != null else null
	if spawns == null:
		return Vector3.INF
	for s: Node in spawns.get_children():
		var mid := StringName(str(s.get_meta(&"monster_id", "")))
		if (mid == WHIRL or MonsterDef.species_of(mid) == WHIRL) and int(s.get_meta(&"stage", 1)) < CombatRules.STAGE_BOSS:
			return (s as Node3D).global_position
	return Vector3.INF


# ================================================================ roteiro

func _run() -> void:
	await _sleep(3.0)
	await _wait(func() -> bool: return not _progress.is_empty(), 15.0)
	if args.get(ARG_PHASE, "training") == PHASE_HUNT:
		await _hunt()
	else:
		await _training()
	_finish()


## Campo de Treino (personagens novos): ver os outros, convites, painel, erros, chat, /online, XP dividida,
## posse do drop, provação não roubável, liderança, expulsar e sair.
func _training() -> void:
	_check("personagem_novo_no_treino", NetWorld.client_map_id == &"training_field", NetWorld.client_map_id)
	# Todos juntos perto do ponto de nascimento.
	var base: Vector3 = _local.net_position
	if _role == ROLE_ANA:
		_put("base", _vec_str(base))
	else:
		base = _str_vec(await _wait_from(ROLE_ANA, "base"))
	var offset: Dictionary = {ROLE_ANA: Vector3.ZERO, ROLE_BIA: Vector3(2, 0, 0), ROLE_CAIO: Vector3(4, 0, 1)}
	await _tp(base + offset[_role])
	await _barrier("juntos")
	var others: Array[String] = []
	for r: String in _roles():
		if r != _role:
			others.append(_names[r])
	var seen: bool = await _wait(func() -> bool:
		for n: String in others:
			if _player(n) == null:
				return false
		return true, 20.0)
	_check("treino_ve_os_outros_no_mesmo_mapa", seen, others)
	await _shot("treino_juntos")
	await _barrier("visto")
	await _invites()
	await _errors()
	await _party_chat()
	await _online()
	await _xp_and_drops()
	await _trial()
	await _leadership()
	await _barrier("fim")


## Convite por /grupo (recusado) e pelo menu do jogador (aceito na janela).
func _invites() -> void:
	var ui: GameUI = _ui()
	match _role:
		ROLE_ANA:
			var mark: int = _system.size()
			await _chat("/grupo " + _names[ROLE_BIA])
			_check("convite_por_chat_enviado", await _wait_sys(mark, "PARTY_INVITE_SENT"))
			_check("recusa_avisada_ao_lider", await _wait_sys(mark, "PARTY_DECLINED", 30.0))
			await _barrier("recusado", [ROLE_ANA, ROLE_BIA])
			await _sleep(Balance.cfg.party_invite_cooldown_sec + 0.5)
			# Clique no outro jogador: o mesmo caminho do clique no mundo (NetParty.player_menu_requested).
			var bia: NetEntity = _player(_names[ROLE_BIA])
			NetParty.player_menu_requested.emit(bia.entity_id if bia != null else 0, _names[ROLE_BIA])
			await _sleep(0.3)
			var opened: bool = ui.player_menu.visible and ui.player_menu.button_for(PlayerMenu.ITEM_INVITE) != null
			_check("menu_do_jogador_tem_convidar", opened)
			await _shot("menu_convidar")
			if opened:
				ui.player_menu.button_for(PlayerMenu.ITEM_INVITE).pressed.emit()
			_check("convite_pelo_menu_aceito", await _wait(func() -> bool: return _party_size() == 2, 30.0),
					NetParty.client_party)
		ROLE_BIA:
			var got: bool = await _wait(func() -> bool: return NetParty.client_invite_from == _names[ROLE_ANA], 30.0)
			await _sleep(0.3)
			_check("convite_chega_com_janela", got and ui.party_invite.visible, NetParty.client_invite_from)
			await _shot("janela_convite")
			ui.party_invite.decline_button.pressed.emit()
			await _wait(func() -> bool: return NetParty.client_invite_from.is_empty(), 5.0)
			_check("recusar_fecha_a_janela", not ui.party_invite.visible)
			await _barrier("recusado", [ROLE_ANA, ROLE_BIA])
			got = await _wait(func() -> bool: return NetParty.client_invite_from == _names[ROLE_ANA], 30.0)
			await _sleep(0.3)
			_check("segundo_convite_chega", got and ui.party_invite.visible)
			ui.party_invite.accept_button.pressed.emit()
			_check("aceitou_e_entrou", await _wait(func() -> bool: return _party_size() == 2, 15.0))
	if _role != ROLE_CAIO:
		await _wait(func() -> bool: return ui.party_panel.member_count() == 2, 5.0)
		await _sleep(1.0)
		var panel: PartyPanel = ui.party_panel
		var other: String = _names[ROLE_BIA] if _role == ROLE_ANA else _names[ROLE_ANA]
		var row: Control = panel.row_for(other)
		var hp: ProgressBar = row.get_node_or_null(^"Hp") as ProgressBar if row != null else null
		_check("painel_mostra_2_membros_com_vida", panel.visible and panel.member_count() == 2 and hp != null \
				and hp.value > 0.0, {"count": panel.member_count(), "hp": hp.value if hp != null else -1})
		var lead_row: Control = panel.row_for(_names[ROLE_ANA])
		var crown: Control = lead_row.find_child("Crown", true, false) as Control if lead_row != null else null
		_check("coroa_no_lider", crown != null and crown.modulate.a > 0.5)
		var vis: Node = _player(other).get_visual() if _player(other) != null else null
		_check("nome_do_membro_na_cor_do_grupo", vis != null and vis.get(&"_nameplate") != null \
				and (vis.get(&"_nameplate") as Node3D).get(&"modulate") == UIKit.COLOR_NAME_PARTY)
		await _shot("grupo_formado")
	await _barrier("grupo")


## Mensagens de erro: já tem grupo, não encontrado, sem grupo, não é líder.
func _errors() -> void:
	match _role:
		ROLE_CAIO:
			var mark: int = _system.size()
			await _chat("/grupo " + _names[ROLE_ANA])
			_check("erro_ja_tem_grupo", await _wait_sys(mark, "PARTY_ERR_TARGET_IN_PARTY"))
			mark = _system.size()
			await _chat("/grupo Ninguem123")
			_check("erro_jogador_nao_encontrado", await _wait_sys(mark, "PARTY_ERR_NOT_FOUND"))
			mark = _system.size()
			await _chat("/g alguem ai?")
			_check("erro_chat_de_grupo_sem_grupo", await _wait_sys(mark, "PARTY_ERR_NO_PARTY"))
			mark = _system.size()
			await _chat("/grupo aceitar")
			_check("erro_aceitar_sem_convite", await _wait_sys(mark, "PARTY_ERR_NO_INVITE"))
		ROLE_BIA:
			var mark: int = _system.size()
			await _chat("/grupo " + _names[ROLE_CAIO])
			_check("erro_so_o_lider_convida", await _wait_sys(mark, "PARTY_ERR_NOT_LEADER"))
	await _barrier("erros")


## Chat do grupo: /g e a aba "Grupo"; quem está fora não recebe.
func _party_chat() -> void:
	var ui: GameUI = _ui()
	match _role:
		ROLE_BIA:
			await _chat("/g oi grupo")
			var got: bool = await _wait(func() -> bool:
				for c: Dictionary in _chats:
					if c["channel"] == &"party" and c["from"] == _names[ROLE_ANA] and c["text"] == "pela aba":
						return true
				return false, 15.0)
			_check("aba_grupo_envia_para_o_grupo", got)
		ROLE_ANA:
			var got: bool = await _wait(func() -> bool:
				for c: Dictionary in _chats:
					if c["channel"] == &"party" and c["from"] == _names[ROLE_BIA] and c["text"] == "oi grupo":
						return true
				return false, 15.0)
			_check("chat_de_grupo_chega_no_membro", got)
			ui.chat.set_tab(ChatBox.TAB_PARTY)
			await _sleep(1.2)
			ui.chat.submit("pela aba")
			await _sleep(1.0)
			var lines: PackedStringArray = ui.chat.visible_lines()
			var only_party: bool = lines.size() > 0
			for l: String in lines:
				if not (l.contains(ChatBox.COLOR_PARTY.to_html(false)) or l.contains(UIKit.COLOR_CHAT_SYSTEM.to_html(false))):
					only_party = false
			_check("aba_grupo_filtra_o_historico", only_party, lines.size())
			await _shot("chat_aba_grupo")
			ui.chat.set_tab(ChatBox.TAB_ALL)
		ROLE_CAIO:
			await _sleep(6.0)
			var leaked: bool = false
			for c: Dictionary in _chats:
				if c["channel"] == &"party":
					leaked = true
			_check("chat_de_grupo_nao_vaza_para_quem_esta_fora", not leaked)
	await _barrier("chat")


func _online() -> void:
	if _role == ROLE_CAIO:
		var n: int = _lists.size()
		await _chat("/online")
		var ok: bool = await _wait(func() -> bool: return _lists.size() > n, 10.0)
		var names: Array = []
		if ok:
			for e: Variant in _lists[-1]["entries"]:
				names.append(str((e as Dictionary).get("name", "")))
		var all_in: bool = ok and _lists[-1]["kind"] == &"online"
		for r: String in _roles():
			all_in = all_in and _names[r] in names
		_check("online_lista_todos_com_mapa_e_nivel", all_in and str((_lists[-1]["entries"][0] as Dictionary).get("map", "")) != "",
				_lists[-1] if ok else null)
		await _shot("online")
	if _role == ROLE_ANA:
		var n2: int = _lists.size()
		await _chat("/grupo")
		var ok2: bool = await _wait(func() -> bool: return _lists.size() > n2 and _lists[-1]["kind"] == &"party", 10.0)
		_check("grupo_sem_argumento_lista_os_membros", ok2 and (_lists[-1]["entries"] as Array).size() == 2,
				_lists[-1] if ok2 else null)
	await _barrier("online")


## Ana mata um redemoinho com Bia (grupo) e Caio (fora) por perto: XP dividida só no grupo; o drop é do grupo
## por alguns segundos e depois fica livre.
func _xp_and_drops() -> void:
	if _role == ROLE_ANA:
		NetParty.send_xp_mode(&"individual")
	if _role == ROLE_ANA or _role == ROLE_BIA:
		_check("xp_mode_individual_replicado", await _wait(func() -> bool:
			return str(NetParty.client_party.get(NetParty.K_XP_MODE, "")) == "individual", 6.0))
	else:
		_check("fora_do_grupo_sem_modo_xp", not NetParty.in_party())
	await _barrier("xp_mode_individual")
	if _role == ROLE_ANA:
		NetParty.send_xp_mode(&"split")
	if _role == ROLE_ANA or _role == ROLE_BIA:
		_check("xp_mode_dividida_replicado", await _wait(func() -> bool:
			return str(NetParty.client_party.get(NetParty.K_XP_MODE, "")) == "split", 6.0))
	else:
		_check("fora_do_grupo_sem_modo_xp", not NetParty.in_party())
	await _barrier("xp_mode_split")
	var mode_error_mark: int = _system.size()
	if _role == ROLE_BIA:
		NetParty.send_xp_mode(&"individual")
	if _role == ROLE_BIA:
		_check("membro_nao_altera_modo_xp", await _wait_sys(mode_error_mark, "PARTY_ERR_NOT_LEADER", 3.0)
				and str(NetParty.client_party.get(NetParty.K_XP_MODE, "")) == "split")
	elif _role == ROLE_ANA:
		_check("lider_mantem_modo_apos_recusa", await _wait(func() -> bool:
			return str(NetParty.client_party.get(NetParty.K_XP_MODE, "")) == "split", 3.0))
	else:
		_check("fora_do_grupo_sem_modo_xp", not NetParty.in_party())
	await _barrier("xp_mode_leader_only")
	var xp0: int = _total_xp()
	var items0: int = _items_total()
	if _role == ROLE_ANA:
		var target: Node3D = _nearest(_entities(KIND_MONSTER, WHIRL))
		if target == null or _flat(target.global_position, _local.global_position) > 25.0:
			var spot: Vector3 = _whirl_spawn()
			if spot != Vector3.INF:
				await _tp(spot + Vector3(0, 0, 4))
			await _wait(func() -> bool: return not _entities(KIND_MONSTER, WHIRL).is_empty(), 12.0)
			target = _nearest(_entities(KIND_MONSTER, WHIRL))
		_put("target", _vec_str(target.global_position) if target != null else "")
	var spot2: Vector3 = _str_vec(await _wait_from(ROLE_ANA, "target"))
	if _role != ROLE_ANA and spot2 != Vector3.INF:
		await _tp(spot2 + (Vector3(2, 0, 2) if _role == ROLE_BIA else Vector3(-2, 0, 3)))
	# Ninguém cai durante a conferência (monstros agressivos por perto derrubam um nível 1).
	await _dbg(&"set_hp", [99999])
	await _barrier("no_alvo")
	xp0 = _total_xp()
	items0 = _items_total()
	if _role == ROLE_ANA:
		var target2: Node3D = _nearest(_entities(KIND_MONSTER, WHIRL), spot2)
		var tid2: int = int(target2.get(&"entity_id")) if target2 != null else 0
		await _tp(target2.global_position + Vector3(1.4, 0, 1.4))
		await _dbg(&"set_hp", [99999])
		NetCombat.send_attack(tid2)
		var end: int = Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < end and not _deaths.has(tid2):
			await _sleep(0.5)
			if not _deaths.has(tid2) and Time.get_ticks_msec() % 4000 < 500:
				NetCombat.send_attack(tid2)
		_check("ana_derrubou_o_redemoinho", _deaths.has(tid2))
		var def_id: String = str(target2.get(&"def_id")) if is_instance_valid(target2) else String(WHIRL)
		var stage: int = int(target2.get(&"stage")) if is_instance_valid(target2) else 1
		_put("killed", "%s,%d,%s" % [def_id, maxi(stage, 1), _vec_str(target2.global_position) if is_instance_valid(target2) else ""])
	var killed: String = await _wait_from(ROLE_ANA, "killed", 90.0)
	var parts: PackedStringArray = killed.split(",")
	var mdef: MonsterDef = Content.monster(StringName(parts[0])) if parts.size() >= 2 else null
	var st: MonsterStage = MonsterEvolution.stage_by_number(mdef, parts[1].to_int()) if mdef != null else null
	var xp_total: int = st.xp_reward if st != null else 0
	var share: int = floori(float(xp_total) * (1.0 + Balance.cfg.party_xp_bonus_per_member) / 2.0)
	match _role:
		ROLE_ANA, ROLE_BIA:
			await _wait(func() -> bool: return _total_xp() > xp0, 8.0)
			_check("xp_dividida_%s" % _role, _total_xp() - xp0 == share,
					{"ganho": _total_xp() - xp0, "esperado": share, "total_do_monstro": xp_total})
		ROLE_CAIO:
			await _sleep(4.0)
			_check("xp_nao_vai_para_quem_esta_fora_do_grupo", _total_xp() == xp0, _total_xp() - xp0)
	var kill_pos: Vector3 = Vector3(parts[2].to_float(), parts[3].to_float(), parts[4].to_float()) if parts.size() >= 5 else _local.global_position
	await _wait(func() -> bool: return _entities(KIND_DROP).size() >= 2, 6.0)
	var drops: Array[Node3D] = _entities(KIND_DROP)
	drops.sort_custom(func(a: Node3D, b: Node3D) -> bool: return int(a.get(&"entity_id")) < int(b.get(&"entity_id")))
	match _role:
		ROLE_CAIO:
			_check("drop_caiu", drops.size() >= 2, drops.size())
			if drops.size() >= 2:
				var mark: int = _system.size()
				NetCombat.send_pickup(int(drops[0].get(&"entity_id")))
				_check("drop_do_grupo_recusado_para_quem_esta_fora", await _wait_sys(mark, "SYS_DROP_NOT_YOURS", 5.0))
				await _shot("drop_recusado")
				# Depois da posse (drop_owner_sec), o drop fica livre.
				await _sleep(Balance.cfg.drop_owner_sec + 1.0)
				var free: Node3D = null
				for d: Node3D in _entities(KIND_DROP):
					if d.get(&"def_id") != null and _flat(d.global_position, kill_pos) < 6.0:
						free = d
				var t0: int = Time.get_ticks_msec()
				if free != null:
					NetCombat.send_pickup(int(free.get(&"entity_id")))
				var got_free: bool = await _wait(func() -> bool: return _items_total() > items0, 20.0)
				_check("drop_fica_livre_depois_da_posse", got_free,
						{"antes": items0, "depois": _items_total(), "tinha_drop": free != null,
						"ms": Time.get_ticks_msec() - t0, "id": int(free.get(&"entity_id")) if free != null else 0})
		ROLE_BIA:
			if drops.size() >= 2:
				NetCombat.send_pickup(int(drops[-1].get(&"entity_id")))
			_check("membro_do_grupo_pega_o_drop", await _wait(func() -> bool: return _items_total() > items0, 8.0),
					{"antes": items0, "depois": _items_total()})
	await _barrier("drops")


## Provação da Ana (quest de título = solo, TITULOS-E-SKILLS §1.4 regra 6): ao aceitar ela sai do grupo e não
## convida ninguém enquanto a etapa estiver em andamento; Bia (agora fora do grupo) e Caio não atacam a provação
## dela. Com a quest pronta para entregar, o grupo Ana + Bia volta (Ana líder) para as fases seguintes.
func _trial() -> void:
	if _role != ROLE_CAIO:
		await _dbg(&"grant_xp", [3000])
		await _spend_points()
		await _dbg(&"set_hp", [99999])
		await _dbg(&"equip_item", [&"machete"])
	if _role == ROLE_ANA:
		var mark: int = _system.size()
		await _dbg(&"quest_accept", [TRIAL_QUEST])
		_check("missao_de_titulo_sai_do_grupo", await _wait(func() -> bool: return not NetParty.in_party(), 8.0)
				and await _wait_sys(mark, "PROG_MSG_TITLE_SOLO_LEFT_PARTY", 5.0))
		var mark_inv: int = _system.size()
		await _chat("/grupo " + _names[ROLE_BIA])
		_check("missao_de_titulo_bloqueia_convite", await _wait_sys(mark_inv, "PARTY_ERR_SOLO_QUEST", 5.0))
		await _dbg(&"quest_step", [TRIAL_QUEST, 3])
		var before: Dictionary = {}
		for e: Node3D in _entities(KIND_MONSTER, TRIAL_MONSTER):
			before[int(e.get(&"entity_id"))] = true
		await _dbg(&"quest_trial", [TRIAL_QUEST])
		var found: Array[Node3D] = []
		await _wait(func() -> bool:
			for e: Node3D in _entities(KIND_MONSTER, TRIAL_MONSTER):
				if not before.has(int(e.get(&"entity_id"))):
					found.append(e)
					return true
			return false, 10.0)
		var tatu: Node3D = found[0] if not found.is_empty() else null
		_check("provacao_nasce", tatu != null)
		_put("trial", "%d,%s" % [int(tatu.get(&"entity_id")) if tatu != null else 0,
				_vec_str(tatu.global_position) if tatu != null else ""])
	var info: PackedStringArray = (await _wait_from(ROLE_ANA, "trial", 120.0)).split(",")
	var tid: int = info[0].to_int() if info.size() > 0 else 0
	var tpos := Vector3(info[1].to_float(), info[2].to_float(), info[3].to_float()) if info.size() >= 4 else Vector3.INF
	match _role:
		ROLE_CAIO, ROLE_BIA:
			await _dbg(&"set_hp", [99999])
			var off: Vector3 = Vector3(1.4, 0, -1.4) if _role == ROLE_CAIO else Vector3(-1.4, 0, 1.4)
			await _tp(tpos + off)
			var mark2: int = _system.size()
			var hits0: int = int(_my_hits.get(tid, 0))
			NetCombat.send_attack(tid)
			_check("provacao_de_outro_recusada" if _role == ROLE_CAIO else "provacao_solo_recusa_ex_membro",
					await _wait_sys(mark2, "SYS_TRIAL_NOT_YOURS", 6.0))
			await _sleep(4.0)
			if _role == ROLE_CAIO:
				await _shot("provacao_de_outro")
			_check("nao_acerta_a_provacao_de_outro" if _role == ROLE_CAIO else "ex_membro_nao_acerta_a_provacao",
					int(_my_hits.get(tid, 0)) == hits0, int(_my_hits.get(tid, 0)) - hits0)
			if _role == ROLE_CAIO:
				_check("provacao_de_outro_nao_ataca_quem_esta_fora", int(_hits_on_me.get(tid, 0)) == 0, _hits_on_me.get(tid, 0))
			await _tp(tpos + off * 6.0)
		ROLE_ANA:
			NetCombat.send_attack(tid)
			await _sleep(2.0)
			await _shot("provacao_solo")
			var end2: int = Time.get_ticks_msec() + 110000
			while Time.get_ticks_msec() < end2 and not bool(_quest(TRIAL_QUEST).get("ready", false)):
				if not _deaths.has(tid):
					NetCombat.send_attack(tid)
				await _sleep(3.0)
			_check("provacao_vencida_sozinha", bool(_quest(TRIAL_QUEST).get("ready", false)), _quest(TRIAL_QUEST))
	var mark_back: int = _system.size()
	await _barrier("provacao")
	# Quest pronta: o grupo pode voltar (Ana convida, Bia aceita pelo chat).
	match _role:
		ROLE_ANA:
			await _sleep(Balance.cfg.party_invite_cooldown_sec)
			await _chat("/grupo " + _names[ROLE_BIA])
			_check("grupo_volta_depois_da_provacao", await _wait(func() -> bool: return _party_size() == 2, 30.0))
		ROLE_BIA:
			await _wait_sys(mark_back, "PARTY_INVITED", 40.0)
			await _chat("/grupo aceitar")
			await _wait(func() -> bool: return _party_size() == 2, 30.0)
	await _barrier("regrupo")


## Passar a liderança, convidar o terceiro (aceita pelo chat), expulsar e sair (o grupo some com 1).
func _leadership() -> void:
	match _role:
		ROLE_ANA:
			await _chat("/grupo líder " + _names[ROLE_BIA])
			_check("lideranca_passada", await _wait(func() -> bool: return NetParty.leader_name() == _names[ROLE_BIA], 8.0))
			await _barrier("lider", [ROLE_ANA, ROLE_BIA, ROLE_CAIO])
			_check("terceiro_entrou", await _wait(func() -> bool: return _party_size() == 3, 30.0))
			await _barrier("tres")
			await _wait(func() -> bool: return _party_size() == 2, 20.0)
			await _barrier("expulso")
			var mark: int = _system.size()
			await _chat("/grupo sair")
			_check("sair_do_grupo", await _wait(func() -> bool: return not NetParty.in_party(), 8.0) \
					and _sys_since(mark, "PARTY_YOU_LEFT"))
			await _sleep(0.5)
			_check("painel_some_sem_grupo", not _ui().party_panel.visible)
		ROLE_BIA:
			await _wait(func() -> bool: return NetParty.leader_name() == _names[ROLE_BIA], 8.0)
			await _barrier("lider", [ROLE_ANA, ROLE_BIA, ROLE_CAIO])
			await _sleep(Balance.cfg.party_invite_cooldown_sec)
			await _chat("/grupo " + _names[ROLE_CAIO])
			_check("novo_lider_convida", await _wait(func() -> bool: return _party_size() == 3, 30.0))
			await _sleep(1.0)
			await _shot("grupo_de_tres")
			await _barrier("tres")
			await _chat("/grupo expulsar " + _names[ROLE_CAIO])
			_check("lider_expulsa", await _wait(func() -> bool: return _party_size() == 2, 8.0))
			await _barrier("expulso")
			var mark2: int = _system.size()
			_check("grupo_some_quando_sobra_1", await _wait(func() -> bool: return not NetParty.in_party(), 15.0)
					and await _wait_sys(mark2, "PARTY_DISBANDED", 5.0))
		ROLE_CAIO:
			await _barrier("lider", [ROLE_ANA, ROLE_BIA, ROLE_CAIO])
			var got: bool = await _wait(func() -> bool: return NetParty.client_invite_from == _names[ROLE_BIA], 30.0)
			_check("convite_do_novo_lider_chega", got)
			await _chat("/grupo aceitar")
			_check("aceitar_pelo_chat", await _wait(func() -> bool: return _party_size() == 3, 10.0))
			var mark3: int = _system.size()
			await _barrier("tres")
			_check("expulso_sai_do_grupo", await _wait(func() -> bool: return not NetParty.in_party(), 15.0)
					and await _wait_sys(mark3, "PARTY_YOU_WERE_KICKED", 5.0))
			await _barrier("expulso")


## Porto → Campos de Pindorama (saves prontos): grupo pelo chat no Porto, painel mostra o mapa do outro, os dois
## se veem nos Campos, lutam juntos e a XP sai dividida.
func _hunt() -> void:
	_check("comeca_no_porto", NetWorld.client_map_id == &"city_awakening", NetWorld.client_map_id)
	var ui: GameUI = _ui()
	await _barrier("porto")
	match _role:
		ROLE_ANA:
			await _wait(func() -> bool: return _player(_names[ROLE_BIA]) != null, 20.0)
			await _chat("/grupo " + _names[ROLE_BIA])
		ROLE_BIA:
			await _wait(func() -> bool: return NetParty.client_invite_from == _names[ROLE_ANA], 30.0)
			await _chat("/grupo aceitar")
	if _role != ROLE_CAIO:
		_check("grupo_no_porto", await _wait(func() -> bool: return _party_size() == 2, 20.0))
	await _barrier("grupo_porto")
	# Ana vai primeiro: o painel de cada um mostra o mapa do outro.
	if _role == ROLE_ANA:
		await _portal("gate_north", &"fields_pindorama")
		_put("ana_nos_campos")
	elif _role == ROLE_BIA:
		await _wait_from(ROLE_ANA, "ana_nos_campos", 120.0)
	if _role != ROLE_CAIO:
		await _sleep(2.0)
		var other: String = _names[ROLE_BIA] if _role == ROLE_ANA else _names[ROLE_ANA]
		var row: Control = ui.party_panel.row_for(other)
		var map_label: Label = row.get_node_or_null(^"Map") as Label if row != null else null
		_check("painel_mostra_o_mapa_do_membro_em_outro_mapa", map_label != null and not map_label.text.is_empty(),
				map_label.text if map_label != null else "")
		await _shot("painel_outro_mapa")
	# Divisão de XP só no mesmo mapa: Ana (Campos) derruba um redemoinho sozinha e leva a XP cheia;
	# Bia (ainda no Porto, mesmo grupo) não recebe nada.
	if _role == ROLE_ANA:
		var spot0: Vector3 = _whirl_spawn()
		if spot0 != Vector3.INF:
			await _tp(spot0 + Vector3(0, 0, 4))
		await _dbg(&"set_hp", [99999])
		await _wait(func() -> bool: return not _entities(KIND_MONSTER, WHIRL).is_empty(), 12.0)
		var solo: Node3D = _nearest(_entities(KIND_MONSTER, WHIRL))
		var solo_id: int = int(solo.get(&"entity_id")) if solo != null else 0
		var xp_a: int = _total_xp()
		var end0: int = Time.get_ticks_msec() + 60000
		while solo_id != 0 and Time.get_ticks_msec() < end0 and not _deaths.has(solo_id):
			NetCombat.send_attack(solo_id)
			await _sleep(2.0)
		await _wait(func() -> bool: return _total_xp() > xp_a, 8.0)
		var whirl_def: MonsterDef = Content.monster(WHIRL)
		var full: int = whirl_def.stages[0].xp_reward if whirl_def != null else 1
		_check("xp_cheia_com_membro_em_outro_mapa", _total_xp() - xp_a >= full, {"ganho": _total_xp() - xp_a, "minimo": full})
		_put("solo_kill_done")
	elif _role == ROLE_BIA:
		var xp_b: int = _total_xp()
		await _wait_from(ROLE_ANA, "solo_kill_done", 90.0)
		await _sleep(3.0)
		_check("xp_nao_vai_para_membro_em_outro_mapa", _total_xp() == xp_b, _total_xp() - xp_b)
	await _barrier("ana_foi")
	if _role != ROLE_ANA:
		await _portal("gate_north", &"fields_pindorama")
	await _barrier("campos")
	var others: Array[String] = []
	for r: String in _roles():
		if r != _role:
			others.append(_names[r])
	_check("campos_todos_se_veem_no_mesmo_mapa_de_caca", await _wait(func() -> bool:
		for n: String in others:
			if _player(n) == null:
				return false
		return true, 20.0), others)
	# Luta junto: Ana e Bia batem no mesmo redemoinho.
	if _role == ROLE_ANA:
		var spot: Vector3 = _whirl_spawn()
		if spot != Vector3.INF:
			await _tp(spot + Vector3(0, 0, 4))
		await _wait(func() -> bool: return not _entities(KIND_MONSTER, WHIRL).is_empty(), 12.0)
		var t: Node3D = _nearest(_entities(KIND_MONSTER, WHIRL))
		_put("hunt_target", "%d,%s" % [int(t.get(&"entity_id")) if t != null else 0, _vec_str(t.global_position) if t != null else ""])
	var info: PackedStringArray = (await _wait_from(ROLE_ANA, "hunt_target", 60.0)).split(",")
	var tid: int = info[0].to_int() if info.size() > 0 else 0
	var tpos := Vector3(info[1].to_float(), info[2].to_float(), info[3].to_float()) if info.size() >= 4 else Vector3.INF
	var offs: Dictionary = {ROLE_ANA: Vector3(1.4, 0, 1.4), ROLE_BIA: Vector3(-1.4, 0, 1.4), ROLE_CAIO: Vector3(0, 0, 6)}
	await _tp(tpos + offs[_role])
	await _dbg(&"set_hp", [99999])
	await _barrier("luta")
	var xp0: int = _total_xp()
	if _role != ROLE_CAIO:
		# Bia abre a luta; Ana entra depois do primeiro golpe dela (as duas batem no mesmo monstro).
		if _role == ROLE_ANA:
			await _wait_from(ROLE_BIA, "hunt_hit", 30.0)
		NetCombat.send_attack(tid)
		await _wait(func() -> bool: return int(_my_hits.get(tid, 0)) > 0, 15.0)
		if _role == ROLE_BIA:
			# Um golpe e espera a Ana acertar também (para o monstro não cair antes de ela chegar).
			NetCombat.send_stop_attack()
			_put("hunt_hit")
			await _wait_from(ROLE_ANA, "hunt_hit", 20.0)
			NetCombat.send_attack(tid)
		else:
			_put("hunt_hit")
		await _sleep(0.4)
		await _shot("luta_junto")
		var end: int = Time.get_ticks_msec() + 60000
		while Time.get_ticks_msec() < end and not _deaths.has(tid):
			NetCombat.send_attack(tid)
			await _sleep(2.0)
		_check("lutaram_juntos", _deaths.has(tid) and int(_my_hits.get(tid, 0)) > 0, _my_hits.get(tid, 0))
		var t_def: MonsterDef = Content.monster(WHIRL)
		var xp_total: int = t_def.stages[0].xp_reward if t_def != null else 0
		var share: int = floori(float(xp_total) * (1.0 + Balance.cfg.party_xp_bonus_per_member) / 2.0)
		await _wait(func() -> bool: return _total_xp() > xp0, 8.0)
		_check("campos_xp_dividida_%s" % _role, _total_xp() - xp0 == share, {"ganho": _total_xp() - xp0, "esperado": share})
		await _sleep(0.5)
		await _shot("depois_da_luta")
	else:
		await _sleep(8.0)
		var n: int = _lists.size()
		await _chat("/online")
		await _wait(func() -> bool: return _lists.size() > n, 10.0)
		var maps_ok: bool = _lists.size() > n
		if maps_ok:
			for e: Variant in _lists[-1]["entries"]:
				maps_ok = maps_ok and str((e as Dictionary).get("map", "")) == "fields_pindorama"
		_check("online_mostra_o_mapa_de_caca", maps_ok, _lists[-1] if _lists.size() > n else null)
	await _barrier("fim_campos")


func _finish() -> void:
	var failed: Array = []
	for k: String in _checks:
		if not _checks[k]:
			failed.append(k)
	Net.log_line("party_done", {"role": _role, "checks": _checks.size(), "failed": failed})
	_put("done")
	await _sleep(0.5)
	get_tree().quit(0 if failed.is_empty() else 1)
