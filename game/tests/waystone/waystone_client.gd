extends Node
## Autoteste da DONA ANA (06/10/2026), no cliente real com servidor (--dev-commands).
## Criado pelo main.gd com --autotest --autotest-script=res://tests/waystone/waystone_client.gd --shot-dir=DIR.
## Save pronto no Porto (já saiu do treino). Roteiro:
##   Porto: fala com a Dona Ana (cidade conhecida), salva, "Viajar" sem outra cidade conhecida;
##   Serra Dourada (goto): fala com a Dona Ana de lá e viaja de volta ao Porto pela opção dela (chega ao lado dela);
##   Sumidouro (goto): fala com a Dona Ana (a lista tem Porto e Serra);
##   Campos do Sabiá: Pergaminho de Retorno e morte levam ao lado da Dona Ana do Porto (cidade salva).
## Imprime "waystone_check {...}" e "waystone_done {...}"; código 0 = tudo passou.

const ARG_SHOT: String = "shot-dir"
const PORTO: StringName = &"city_awakening"
const SERRA: StringName = &"city_serra_dourada"
const SUMIDOURO: StringName = &"city_sumidouro"
const HUNT: StringName = &"fields_sabia"
const NPC_OF: Dictionary[StringName, StringName] = {PORTO: &"dona_ana_porto", SERRA: &"dona_ana_serra_dourada",
		SUMIDOURO: &"dona_ana_sumidouro"}
const ARRIVAL: String = "WaystoneArrival"
const OPT_SAVE: String = "DLG_DONA_ANA_OPT_SAVE"
const OPT_TRAVEL: String = "DLG_DONA_ANA_OPT_TRAVEL"
const SCROLL: StringName = &"return_scroll"
const WAIT_SEC: float = 12.0
const NEAR_RADIUS_M: float = 2.5
## Onde o jogador fica para a foto e a conversa (ao lado da Dona Ana, um pouco à frente da câmera).
const TALK_OFFSET: Vector3 = Vector3(1.8, 0.0, 0.6)
const KIND_MONSTER: StringName = &"monster"

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _local: NetEntity = null
var _started: bool = false
var _spawn_seq: int = 0
var _progress_seq: int = 0
var _inventory: Array = []
var _system: Array[String] = []
var _dialogue_seq: int = 0
var _dialogue_text: String = ""
var _dialogue_opts: Array = []
var _dialogue_open: bool = false
var _deaths: Dictionary[int, bool] = {}
var _checks: Dictionary = {}
var _shot_index: int = 0


func _ready() -> void:
	Net.local_player_spawned.connect(func(p: Node3D) -> void:
		_local = p as NetEntity
		_spawn_seq += 1
		if not _started:
			_started = true
			_run.call_deferred())
	NetProgress.progress_changed.connect(func(_p: Dictionary) -> void: _progress_seq += 1)
	Net.inventory_changed.connect(func(slots: Array) -> void: _inventory = slots)
	Net.system_message.connect(func(key: String, _a: Array) -> void: _system.append(key))
	Net.dialogue_opened.connect(func(_npc: int, _sp: String, tk: String, opts: Array) -> void:
		_dialogue_text = tk
		_dialogue_opts = opts
		_dialogue_open = true
		_dialogue_seq += 1)
	Net.dialogue_closed.connect(func() -> void: _dialogue_open = false)
	NetCombat.entity_died.connect(func(id: int) -> void: _deaths[id] = true)
	get_tree().create_timer(400.0).timeout.connect(func() -> void:
		_check("tempo_esgotado", false)
		_finish())


# ---------------------------------------------------------------- ajudantes

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
	Net.log_line("waystone_check", {"check": name, "pass": ok, "map": String(NetWorld.client_map_id),
			"detail": str(detail) if detail != null else ""})


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot_index += 1
	var path: String = "%s/%02d_%s.png" % [dir, _shot_index, label]
	get_viewport().get_texture().get_image().save_png(path)
	Net.log_line("waystone_shot", {"file": path})


func _dbg(cmd: StringName, a: Array = []) -> void:
	var seq: int = _progress_seq
	NetProgress.send_debug(cmd, a)
	await _wait(func() -> bool: return _progress_seq > seq, 5.0)
	await _sleep(0.3)


func _map_node() -> Node:
	if _local == null or not is_instance_valid(_local) or _local.get_parent() == null:
		return null
	return _local.get_parent().get_parent().get_node_or_null(^"Map")


func _marker(path: String) -> Vector3:
	var m: Node = _map_node()
	var n: Node3D = m.get_node_or_null(NodePath(path)) as Node3D if m != null else null
	return n.global_position if n != null else Vector3.INF


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _near_arrival() -> float:
	var p: Vector3 = _marker(ARRIVAL)
	return _flat(_local.net_position, p) if p != Vector3.INF else INF


func _entities() -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	if _local == null or _local.get_parent() == null:
		return out
	for n: Node in _local.get_parent().get_children():
		if n is NetEntity and not n.is_queued_for_deletion():
			out.append(n as NetEntity)
	return out


func _find(def_id: StringName) -> NetEntity:
	for e: NetEntity in _entities():
		if e.def_id == def_id:
			return e
	return null


func _goto(map_id: StringName) -> bool:
	var seq: int = _spawn_seq
	NetProgress.send_debug(&"goto", [map_id])
	var ok: bool = await _wait(func() -> bool: return _spawn_seq > seq and NetWorld.client_map_id == map_id, 40.0)
	await _sleep(2.0)
	return ok


func _slot_of(item: StringName) -> int:
	for i: int in _inventory.size():
		var s: Variant = _inventory[i]
		if s is Dictionary and StringName(str((s as Dictionary).get("item", ""))) == item:
			return i
	return -1


## Vai para o lado da Dona Ana da cidade e abre o diálogo. Retorna a Dona Ana (null = não achou/abriu).
func _talk(map_id: StringName) -> NetEntity:
	# Lambdas copiam as variáveis locais: busca de novo depois da espera.
	await _wait(func() -> bool: return _find(NPC_OF[map_id]) != null, 10.0)
	var ana: NetEntity = _find(NPC_OF[map_id])
	if ana == null:
		Net.log_line("waystone_debug", {"missing_npc": NPC_OF[map_id],
				"seen": _entities().map(func(e: NetEntity) -> String: return String(e.def_id))})
		return null
	var p: Vector3 = ana.position + TALK_OFFSET
	await _dbg(&"teleport", [p.x, p.z])
	await _wait(func() -> bool: return _flat(_local.position, p) < 1.5, 6.0)
	await _sleep(0.8)
	var seq: int = _dialogue_seq
	Net.send_interact(ana.get_target_id())
	if not await _wait(func() -> bool: return _dialogue_seq > seq and _dialogue_open, 10.0):
		return null
	await _sleep(0.4)
	return ana


## Escolhe a opção com essa chave; espera o próximo nó, o fechamento ou a troca de mapa.
func _choose(key: String) -> bool:
	var i: int = _dialogue_opts.find(key)
	if i < 0:
		Net.log_line("waystone_debug", {"missing_option": key, "options": _dialogue_opts})
		return false
	var seq: int = _dialogue_seq
	Net.send_dialogue_choice(i)
	await _wait(func() -> bool: return _dialogue_seq > seq or not _dialogue_open, 6.0)
	await _sleep(0.4)
	return true


# ---------------------------------------------------------------- roteiro

func _run() -> void:
	await _sleep(3.0)
	await _wait(func() -> bool: return not _inventory.is_empty(), 15.0)
	_check("comeca_no_porto", NetWorld.client_map_id == PORTO, NetWorld.client_map_id)
	await _porto()
	await _serra()
	await _sumidouro()
	await _ponto_salvo()
	_finish()


func _porto() -> void:
	var mark: int = _system.size()
	var ana: NetEntity = await _talk(PORTO)
	_check("porto_dona_ana_existe_e_fala", ana != null and _dialogue_text == "DLG_DONA_ANA_START",
			{"text": _dialogue_text, "opts": _dialogue_opts})
	_check("porto_opcoes_salvar_viajar", OPT_SAVE in _dialogue_opts and OPT_TRAVEL in _dialogue_opts, _dialogue_opts)
	_check("porto_cidade_conhecida_ao_falar", "WAYSTONE_LEARNED" in _system.slice(mark), _system.slice(mark))
	if ana != null:
		_check("porto_dona_ana_no_centro", _flat(ana.position, Vector3.ZERO) < 10.0, ana.position)
		await _shot("porto_dialogo_dona_ana")
	mark = _system.size()
	await _choose(OPT_SAVE)
	_check("porto_salvou", await _wait(func() -> bool: return "WAYSTONE_SAVED" in _system.slice(mark), 5.0))
	await _talk(PORTO)
	await _choose(OPT_TRAVEL)
	_check("porto_viajar_sem_outra_cidade", _dialogue_text == "DLG_DONA_ANA_TRAVEL_NONE"
			and _dialogue_opts == ["DLG_DONA_ANA_OPT_BACK"], {"text": _dialogue_text, "opts": _dialogue_opts})
	Net.send_dialogue_close()
	await _sleep(0.6)
	await _shot("porto_dona_ana_no_centro")


func _serra() -> void:
	if not await _goto(SERRA):
		_check("chegou_na_serra", false)
		return
	var mark: int = _system.size()
	var ana: NetEntity = await _talk(SERRA)
	_check("serra_dona_ana_fala", ana != null and _dialogue_text == "DLG_DONA_ANA_START", _dialogue_text)
	_check("serra_cidade_conhecida", "WAYSTONE_LEARNED" in _system.slice(mark))
	await _shot("serra_dialogo_dona_ana")
	await _choose(OPT_TRAVEL)
	_check("serra_lista_o_porto", _dialogue_text == "DLG_DONA_ANA_TRAVEL" and "ZONE_CITY_AWAKENING_NAME" in _dialogue_opts,
			{"text": _dialogue_text, "opts": _dialogue_opts})
	await _shot("serra_lista_destinos")
	var seq: int = _spawn_seq
	mark = _system.size()
	await _choose("ZONE_CITY_AWAKENING_NAME")
	var ok: bool = await _wait(func() -> bool: return _spawn_seq > seq and NetWorld.client_map_id == PORTO, 30.0)
	await _sleep(2.0)
	var dist: float = _near_arrival()
	_check("serra_viajou_ao_porto_ao_lado_da_dona_ana", ok and dist <= NEAR_RADIUS_M
			and "WAYSTONE_TRAVELED" in _system.slice(mark), {"map": NetWorld.client_map_id, "dist": snappedf(dist, 0.1)})
	await _shot("porto_chegada_pela_dona_ana")
	# Foto da Dona Ana da Serra no centro (volta de goto, sem diálogo).
	if await _goto(SERRA):
		var a2: NetEntity = await _talk(SERRA)
		Net.send_dialogue_close()
		await _sleep(0.6)
		_check("serra_dona_ana_no_centro", a2 != null and _flat(a2.position, Vector3.ZERO) < 10.0,
				a2.position if a2 != null else null)
		await _shot("serra_dona_ana_no_centro")


func _sumidouro() -> void:
	if not await _goto(SUMIDOURO):
		_check("chegou_no_sumidouro", false)
		return
	var mark: int = _system.size()
	var ana: NetEntity = await _talk(SUMIDOURO)
	_check("sumidouro_dona_ana_fala", ana != null and _dialogue_text == "DLG_DONA_ANA_START", _dialogue_text)
	_check("sumidouro_cidade_conhecida", "WAYSTONE_LEARNED" in _system.slice(mark))
	await _shot("sumidouro_dialogo_dona_ana")
	await _choose(OPT_TRAVEL)
	_check("sumidouro_lista_porto_e_serra", "ZONE_CITY_AWAKENING_NAME" in _dialogue_opts
			and "ZONE_SERRA_DOURADA_NAME" in _dialogue_opts and not "ZONE_SUMIDOURO_NAME" in _dialogue_opts, _dialogue_opts)
	Net.send_dialogue_close()
	await _sleep(0.6)
	_check("sumidouro_dona_ana_no_centro", ana != null and _flat(ana.position, Vector3.ZERO) < 10.0,
			ana.position if ana != null else null)
	await _shot("sumidouro_dona_ana_no_centro")


## A cidade salva (Porto) manda no Pergaminho de Retorno e no renascimento, mesmo depois de entrar no Sumidouro.
func _ponto_salvo() -> void:
	if not await _goto(HUNT):
		_check("chegou_nos_campos", false)
		return
	await _dbg(&"give_item", [SCROLL, 2])
	await _wait(func() -> bool: return _slot_of(SCROLL) >= 0, 5.0)
	await _dbg(&"set_hp", [99999])
	var seq: int = _spawn_seq
	var mark: int = _system.size()
	Net.send_use_item(_slot_of(SCROLL))
	var ok: bool = await _wait(func() -> bool: return _spawn_seq > seq and NetWorld.client_map_id == PORTO, 20.0)
	await _sleep(2.0)
	var dist: float = _near_arrival()
	_check("pergaminho_leva_a_cidade_salva", ok and dist <= NEAR_RADIUS_M and "SYS_RETURN_DONE" in _system.slice(mark),
			{"map": NetWorld.client_map_id, "dist": snappedf(dist, 0.1), "sys": _system.slice(mark)})
	# Morte nos Campos: renasce no Porto, ao lado da Dona Ana.
	if not await _goto(HUNT):
		return
	var me: int = _local.entity_id
	_deaths.erase(me)
	seq = _spawn_seq
	mark = _system.size()
	await _dbg(&"set_hp", [1])
	var end: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < end and not _deaths.has(me) and NetWorld.client_map_id == HUNT:
		var t: NetEntity = _nearest_monster()
		if t != null:
			var p: Vector3 = t.position + Vector3(1.0, 0.0, 0.0)
			await _dbg(&"teleport", [p.x, p.z])
			NetCombat.send_attack(t.entity_id)
		await _sleep(3.0)
	var back: bool = await _wait(func() -> bool: return _spawn_seq > seq and NetWorld.client_map_id == PORTO, 25.0)
	await _sleep(2.0)
	dist = _near_arrival()
	_check("morte_renasce_na_cidade_salva", back and dist <= NEAR_RADIUS_M and "WORLD_RESPAWNED" in _system.slice(mark),
			{"map": NetWorld.client_map_id, "dist": snappedf(dist, 0.1)})
	await _shot("porto_renasceu_ao_lado_da_dona_ana")


func _nearest_monster() -> NetEntity:
	var best: NetEntity = null
	for e: NetEntity in _entities():
		if StringName(str(e.get(&"kind"))) != KIND_MONSTER or e.hp_ratio <= 0.0 or int(e.get(&"stage")) >= CombatRules.STAGE_BOSS:
			continue
		if best == null or _flat(e.position, _local.position) < _flat(best.position, _local.position):
			best = e
	return best


func _finish() -> void:
	var failed: Array = []
	for k: String in _checks:
		if not _checks[k]:
			failed.append(k)
	Net.log_line("waystone_done", {"checks": _checks.size(), "failed": failed})
	await _sleep(1.0)
	get_tree().quit(0 if failed.is_empty() else 1)
