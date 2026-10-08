extends Node
## Autoteste do PERGAMINHO DE RETORNO (pedido do dono em 30/09/2026), no cliente real.
## Criado pelo main.gd com --autotest --autotest-script=res://tests/return/return_client.gd e:
##   --return-phase=novo|volta  --shot-dir=DIR
## Servidor: --dev-commands (goto, teleporte, provação, vida).
##   novo:  personagem novo no Campo de Treino — o kit traz 3 pergaminhos e eles não funcionam no treino.
##   volta: save pronto no Porto — usa o pergaminho nos Campos, na Mata e na Chapada e volta ao Porto (ponto
##          seguro); em combate a leitura leva 1 s (andar interrompe); não usa em provação; barra de atalhos.
## Imprime "return_check {...}" e "return_done {...}"; código 0 = tudo passou.

const ARG_PHASE: String = "return-phase"
const ARG_SHOT: String = "shot-dir"
const SCROLL: StringName = &"return_scroll"
const CITY: StringName = &"city_awakening"
const HUNTS: Array[StringName] = [&"fields_pindorama", &"enchanted_forest", &"split_sky_plateau"]
const ZE: StringName = &"elder_ze_steel_song"
const WAIT_SEC: float = 12.0
const SAFE_RADIUS_M: float = 3.5

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _local: NetEntity = null
var _started: bool = false
var _spawn_seq: int = 0
var _progress: Dictionary = {}
var _progress_seq: int = 0
var _inventory: Array = []
var _system: Array[String] = []
var _casts: Array[StringName] = []
var _checks: Dictionary = {}
var _shot_index: int = 0


func _ready() -> void:
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
	NetProgress.skill_cast.connect(func(eid: int, sid: StringName, _t: int, _p: Vector3, _ms: int) -> void:
		if _local != null and eid == _local.entity_id:
			_casts.append(sid))
	get_tree().create_timer(400.0).timeout.connect(func() -> void:
		_check("tempo_esgotado", false)
		_finish())


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
	Net.log_line("return_check", {"check": name, "pass": ok, "map": String(NetWorld.client_map_id),
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
	Net.log_line("return_shot", {"file": path})


func _dbg(cmd: StringName, a: Array = []) -> void:
	var seq: int = _progress_seq
	NetProgress.send_debug(cmd, a)
	await _wait(func() -> bool: return _progress_seq > seq, 5.0)
	await _sleep(0.3)


func _slot_of(item: StringName) -> int:
	for i: int in _inventory.size():
		var s: Variant = _inventory[i]
		if s is Dictionary and StringName(str((s as Dictionary).get("item", ""))) == item:
			return i
	return -1


func _count(item: StringName) -> int:
	var n: int = 0
	for s: Variant in _inventory:
		if s is Dictionary and StringName(str((s as Dictionary).get("item", ""))) == item:
			n += int((s as Dictionary).get("qty", 0))
	return n


func _map_node() -> Node:
	if _local == null or not is_instance_valid(_local) or _local.get_parent() == null:
		return null
	return _local.get_parent().get_parent().get_node_or_null(^"Map")


func _spawn_point() -> Vector3:
	var m: Node = _map_node()
	var n: Node3D = m.get_node_or_null(^"SpawnPoint") as Node3D if m != null else null
	return n.global_position if n != null else Vector3.INF


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _goto(map_id: StringName) -> bool:
	var seq: int = _spawn_seq
	NetProgress.send_debug(&"goto", [map_id])
	var ok: bool = await _wait(func() -> bool: return _spawn_seq > seq and NetWorld.client_map_id == map_id, 40.0)
	await _sleep(2.0)
	return ok


## Usa o pergaminho e espera chegar à cidade. true = voltou.
func _use_and_return(label: String, timeout: float = 15.0) -> bool:
	var seq: int = _spawn_seq
	var mark: int = _system.size()
	Net.send_use_item(_slot_of(SCROLL))
	var ok: bool = await _wait(func() -> bool: return _spawn_seq > seq and NetWorld.client_map_id == CITY, timeout)
	await _sleep(1.5)
	var sp: Vector3 = _spawn_point()
	var dist: float = _flat(_local.net_position, sp) if sp != Vector3.INF else INF
	_check("volta_ao_porto_de_" + label, ok and dist <= SAFE_RADIUS_M and "SYS_RETURN_DONE" in _system.slice(mark),
			{"map": NetWorld.client_map_id, "dist": snappedf(dist, 0.1)})
	return ok


func _run() -> void:
	await _sleep(3.0)
	await _wait(func() -> bool: return not _inventory.is_empty() and not _progress.is_empty(), 15.0)
	if args.get(ARG_PHASE, "volta") == "novo":
		await _novo()
	else:
		await _volta()
	_finish()


func _novo() -> void:
	_check("personagem_novo_no_treino", NetWorld.client_map_id == &"training_field", NetWorld.client_map_id)
	_check("kit_inicial_tem_3_pergaminhos", _count(SCROLL) == 3, _count(SCROLL))
	var mark: int = _system.size()
	Net.send_use_item(_slot_of(SCROLL))
	_check("nao_funciona_no_treino", await _wait(func() -> bool: return "SYS_RETURN_TRAINING" in _system.slice(mark), 6.0)
			and NetWorld.client_map_id == &"training_field" and _count(SCROLL) == 3)


func _volta() -> void:
	_check("comeca_no_porto", NetWorld.client_map_id == CITY, NetWorld.client_map_id)
	await _dbg(&"give_item", [SCROLL, 5])
	await _wait(func() -> bool: return _count(SCROLL) >= 5, 5.0)
	NetProgress.send_hotbar_set(2, SCROLL)
	await _sleep(1.0)
	_check("pergaminho_vai_na_barra", str((_progress.get("hotbar", []) as Array)[2]) == String(SCROLL), _progress.get("hotbar"))
	# Campos, Mata e Chapada (fora de combate: na hora).
	for map_id: StringName in HUNTS:
		if not await _goto(map_id):
			_check("chegou_em_" + map_id, false)
			continue
		await _dbg(&"set_hp", [99999])
		await _shot("em_" + map_id)
		await _sleep(Balance.cfg.item_default_cooldown_sec)
		await _use_and_return(String(map_id))
	# Em combate: leitura de 1 s; andar interrompe; parado, volta.
	await _goto(&"fields_pindorama")
	await _dbg(&"set_hp", [99999])
	await _sleep(10.0)
	var fought: bool = await _enter_combat()
	_check("entrou_em_combate", fought, _progress.get("in_combat"))
	var mark: int = _system.size()
	var casts0: int = _casts.size()
	Net.send_use_item(_slot_of(SCROLL))
	await _sleep(0.3)
	_check("em_combate_tem_leitura", _casts.size() > casts0 and _casts[-1] == SCROLL, _casts)
	Net.send_move_request(_local.net_position + Vector3(3, 0, 0))
	_check("andar_interrompe_a_leitura", await _wait(func() -> bool: return "PROG_MSG_CAST_INTERRUPTED" in _system.slice(mark), 4.0)
			and NetWorld.client_map_id == &"fields_pindorama")
	var back: bool = false
	for i: int in 4:
		await _enter_combat()
		NetCombat.send_stop_attack()
		await _sleep(0.3)
		var m2: int = _system.size()
		var seq: int = _spawn_seq
		Net.send_use_item(_slot_of(SCROLL))
		back = await _wait(func() -> bool: return _spawn_seq > seq and NetWorld.client_map_id == CITY, 4.0)
		var hit: bool = "PROG_MSG_CAST_INTERRUPTED" in _system.slice(m2)
		Net.log_line("return_combat_try", {"try": i, "back": back, "interrupted_by_damage": hit})
		if back:
			break
	_check("em_combate_volta_depois_da_leitura", back)
	# Provação: não usa.
	await _goto(&"fields_pindorama")
	await _dbg(&"set_hp", [99999])
	await _dbg(&"grant_title", [&"pindorama_blade_machete"])
	await _dbg(&"grant_title", [&"pindorama_arcane_firefly"])
	# Sub-história do Seu Zé: renome 3 (cada título rende 1 Causo) e a provação é a 6ª etapa (índice 5).
	await _dbg(&"grant_title", [&"pindorama_bow_cerrado"])
	await _dbg(&"quest_accept", [ZE])
	await _dbg(&"quest_step", [ZE, 5])
	await _dbg(&"quest_trial", [ZE])
	await _sleep(1.0)
	await _sleep(Balance.cfg.item_default_cooldown_sec)
	var m3: int = _system.size()
	Net.send_use_item(_slot_of(SCROLL))
	_check("provacao_comecou", not (_progress.get("quests", []) as Array).is_empty(), _progress.get("quests"))
	_check("nao_funciona_em_provacao", await _wait(func() -> bool: return "SYS_RETURN_TRIAL" in _system.slice(m3), 6.0)
			and NetWorld.client_map_id == &"elder_trial_arena")
	await _shot("provacao_bloqueia")
	await _dbg(&"trial_time", [0.5])
	await _sleep(2.0)
	await _use_and_return("depois_da_provacao")
	await _sleep(1.0)
	await _shot("de_volta_ao_porto")


## Bate num monstro até o servidor marcar "em combate".
func _enter_combat() -> bool:
	if bool(_progress.get("in_combat", false)):
		return true
	var best: Node3D = null
	for e: Node3D in NetCombat.all_entities():
		if StringName(str(e.get(&"kind"))) == &"monster" and float(e.get(&"hp_ratio")) > 0.0 \
				and (best == null or _flat(e.global_position, _local.global_position) < _flat(best.global_position, _local.global_position)):
			best = e
	if best == null:
		return false
	await _dbg(&"teleport", [best.global_position.x + 1.4, best.global_position.z + 1.4])
	NetCombat.send_attack(int(best.get(&"entity_id")))
	return await _wait(func() -> bool: return bool(_progress.get("in_combat", false)), 10.0)


func _finish() -> void:
	var failed: Array = []
	for k: String in _checks:
		if not _checks[k]:
			failed.append(k)
	Net.log_line("return_done", {"checks": _checks.size(), "failed": failed})
	await _sleep(1.0)
	get_tree().quit(0 if failed.is_empty() else 1)
