extends Node
## Autoteste da TROCA entre personagens (pedido do dono em 30/09/2026), no cliente real, 2 clientes.
## Criado pelo main.gd com --autotest --autotest-script=res://tests/trade/trade_client.gd e:
##   --trade-role=ana|bia  --trade-names=A,B  --sync-dir=DIR  --shot-dir=DIR
## Servidor: --dev-commands (dar item, equipar, teleporte). Saves prontos no Porto (sem combate).
## Roteiro: pedido pelo menu do jogador (recusado), pedido por /troca (aceito na janela), trapaças recusadas
## pelo servidor (item que não tem, quantidade a mais, Estrelas a mais, item que foi equipado sai da oferta),
## oferta pelo arrastar e pelo botão direito, confirmar, mudança desfaz as confirmações, troca de item e Estrelas,
## cancelamento ao se afastar. Imprime "trade_check {...}" e "trade_done {...}"; código 0 = tudo passou.

const ARG_ROLE: String = "trade-role"
const ARG_NAMES: String = "trade-names"
const ARG_SYNC: String = "sync-dir"
const ARG_SHOT: String = "shot-dir"
const ANA: String = "ana"
const BIA: String = "bia"
const WAIT_SEC: float = 12.0
const POTION: StringName = &"potion_hp_small"
const LEAF: StringName = &"spinning_leaf"
const CAP: StringName = &"red_cap"
const SWORD: StringName = &"short_sword"

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _role: String = ""
var _names: Dictionary[String, String] = {}
var _local: NetEntity = null
var _started: bool = false
var _progress_seq: int = 0
var _inventory: Array = []
var _stars: int = 0
var _equipment: Dictionary = {}
var _system: Array[String] = []
var _checks: Dictionary = {}
var _shot_index: int = 0


func _ready() -> void:
	_role = args.get(ARG_ROLE, ANA)
	var list: PackedStringArray = args.get(ARG_NAMES, "TAna,TBia").split(",")
	_names[ANA] = list[0]
	_names[BIA] = list[1] if list.size() > 1 else ""
	Net.local_player_spawned.connect(func(p: Node3D) -> void:
		_local = p as NetEntity
		if not _started:
			_started = true
			_run.call_deferred())
	NetProgress.progress_changed.connect(func(_p: Dictionary) -> void: _progress_seq += 1)
	Net.inventory_changed.connect(func(slots: Array) -> void: _inventory = slots)
	Net.currency_changed.connect(func(s: int) -> void: _stars = s)
	Net.equipment_changed.connect(func(e: Dictionary) -> void: _equipment = e)
	Net.system_message.connect(func(key: String, _a: Array) -> void: _system.append(key))
	get_tree().create_timer(600.0).timeout.connect(func() -> void:
		_check("tempo_esgotado", false)
		_finish())


# ================================================================ utilitários

func _other() -> String:
	return _names[BIA] if _role == ANA else _names[ANA]


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
	Net.log_line("trade_check", {"role": _role, "check": name, "pass": ok,
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
	Net.log_line("trade_shot", {"role": _role, "file": path})


func _sync_path(role: String, step: String) -> String:
	return "%s/%s.%s" % [args.get(ARG_SYNC, "/tmp"), role, step]


func _put(step: String, value: String = "1") -> void:
	var f := FileAccess.open(_sync_path(_role, step), FileAccess.WRITE)
	f.store_string(value)
	f.close()


func _wait_from(role: String, step: String, timeout: float = 180.0) -> String:
	await _wait(func() -> bool: return FileAccess.file_exists(_sync_path(role, step)), timeout)
	var p: String = _sync_path(role, step)
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func _barrier(step: String) -> void:
	_put("barrier_" + step)
	var ok: bool = await _wait(func() -> bool:
		return FileAccess.file_exists(_sync_path(ANA, "barrier_" + step)) \
				and FileAccess.file_exists(_sync_path(BIA, "barrier_" + step)), 180.0)
	if not ok:
		_check("barreira_" + step, false)


func _dbg(cmd: StringName, a: Array = []) -> void:
	var seq: int = _progress_seq
	NetProgress.send_debug(cmd, a)
	await _wait(func() -> bool: return _progress_seq > seq, 5.0)
	await _sleep(0.3)


func _chat(text: String) -> void:
	Net.send_chat(&"local", text)
	await _sleep(1.15)


func _count(item: StringName) -> int:
	var n: int = 0
	for s: Variant in _inventory:
		if s is Dictionary and StringName(str((s as Dictionary).get("item", ""))) == item:
			n += int((s as Dictionary).get("qty", 0))
	return n


func _slot_of(item: StringName) -> int:
	for i: int in _inventory.size():
		var s: Variant = _inventory[i]
		if s is Dictionary and StringName(str((s as Dictionary).get("item", ""))) == item:
			return i
	return -1


func _empty_slot() -> int:
	for i: int in _inventory.size():
		if not (_inventory[i] is Dictionary) or (_inventory[i] as Dictionary).is_empty():
			return i
	return -1


func _mine() -> Dictionary:
	return NetTrade.client_trade.get(NetTrade.K_MINE, {})


func _theirs() -> Dictionary:
	return NetTrade.client_trade.get(NetTrade.K_THEIRS, {})


func _offer_has(side: Dictionary, item: StringName, qty: int = -1) -> bool:
	for e: Variant in side.get(NetTrade.K_ITEMS, []):
		var d: Dictionary = e
		if StringName(str(d.get(NetTrade.K_ITEM, ""))) == item and (qty < 0 or int(d.get(NetTrade.K_QTY, 0)) == qty):
			return true
	return false


func _sys_after(mark: int, key: String, timeout: float = 6.0) -> bool:
	return await _wait(func() -> bool: return key in _system.slice(mark), timeout)


func _player(name: String) -> NetEntity:
	for e: Node3D in NetCombat.all_entities():
		if StringName(str(e.get(&"kind"))) == &"player" and str(e.get(&"display_name")) == name:
			return e as NetEntity
	return null


# ================================================================ roteiro

func _run() -> void:
	await _sleep(3.0)
	await _wait(func() -> bool: return not _inventory.is_empty(), 15.0)
	var ui: GameUI = _ui()
	# Juntos no Porto e com os itens do teste.
	if _role == ANA:
		_put("pos", "%f,%f" % [_local.net_position.x, _local.net_position.z])
		await _dbg(&"give_item", [POTION, 5])
		await _dbg(&"give_item", [LEAF, 3])
		await _dbg(&"give_item", [SWORD, 1])
	else:
		var p: PackedStringArray = (await _wait_from(ANA, "pos")).split(",")
		await _dbg(&"teleport", [p[0].to_float() + 2.0, p[1].to_float()])
		await _dbg(&"give_item", [CAP, 2])
	await _sleep(1.0)
	_check("ve_o_outro", await _wait(func() -> bool: return _player(_other()) != null, 20.0))
	await _barrier("pronto")
	# 1) Pedido pelo menu do jogador, recusado na janela.
	if _role == ANA:
		var mark: int = _system.size()
		var items: Array[StringName] = ui.open_player_menu(_other(), Vector2(500, 300))
		_check("menu_tem_propor_troca", PlayerMenu.ITEM_TRADE in items, items)
		await _shot("menu_troca")
		if ui.player_menu.button_for(PlayerMenu.ITEM_TRADE) != null:
			ui.player_menu.button_for(PlayerMenu.ITEM_TRADE).pressed.emit()
		_check("pedido_recusado_avisa", await _sys_after(mark, "TRADE_DECLINED", 20.0))
	else:
		var got: bool = await _wait(func() -> bool: return NetTrade.client_request_from == _other(), 20.0)
		await _sleep(0.3)
		_check("pedido_abre_janela", got and ui.trade_request.visible)
		await _shot("pedido_troca")
		ui.trade_request.decline_button.pressed.emit()
	await _barrier("recusa")
	# 2) Pedido por /troca, aceito.
	if _role == ANA:
		await _sleep(Balance.cfg.trade_request_cooldown_sec)
		await _chat("/troca " + _other())
	else:
		await _wait(func() -> bool: return NetTrade.client_request_from == _other(), 20.0)
		ui.trade_request.accept_button.pressed.emit()
	_check("troca_abre_nos_dois", await _wait(func() -> bool: return NetTrade.is_open() and ui.trade_window.visible, 15.0))
	await _barrier("aberta")
	# 3) Trapaças (servidor recusa) — Ana.
	if _role == ANA:
		var mark: int = _system.size()
		NetTrade.send_item(_empty_slot(), 1)
		_check("recusa_item_que_nao_tem", await _sys_after(mark, "TRADE_ERR_NOT_OWNED"))
		mark = _system.size()
		NetTrade.send_item(_slot_of(POTION), 99)
		_check("recusa_quantidade_a_mais", await _sys_after(mark, "TRADE_ERR_NOT_OWNED"))
		mark = _system.size()
		NetTrade.send_stars(_stars + 1000)
		_check("recusa_estrelas_a_mais", await _sys_after(mark, "TRADE_ERR_NO_STARS"))
		# Espada oferecida e depois equipada: sai da oferta (equipado não entra na troca).
		NetTrade.send_item(_slot_of(SWORD), 1)
		await _wait(func() -> bool: return _offer_has(_mine(), SWORD), 5.0)
		_check("espada_entrou_na_oferta", _offer_has(_mine(), SWORD))
		Net.send_equip(_slot_of(SWORD))
		await _wait(func() -> bool: return StringName(str(_equipment.get(&"weapon", ""))) == SWORD, 5.0)
		await _wait(func() -> bool: return not _offer_has(_mine(), SWORD), 5.0)
		_check("item_equipado_sai_da_oferta", not _offer_has(_mine(), SWORD), _mine())
		mark = _system.size()
		NetTrade.send_command(NetTrade.CMD_ITEM, 999, 1)
		_check("recusa_espaco_invalido", await _sys_after(mark, "TRADE_ERR_NOT_OWNED"))
	await _barrier("trapaca")
	# 4) Ofertas pela interface: Ana arrasta 3 poções e põe 20 Estrelas; Bia põe os gorros pelo botão direito.
	var stars0: int = _stars
	var potions0: int = _count(POTION)
	var caps0: int = _count(CAP)
	if _role == ANA:
		ui.trade_window._drop_offer(Vector2.ZERO, {"source": ItemSlot.SOURCE_INVENTORY, "index": _slot_of(POTION), "qty": 3})
		ui.trade_window.stars_spin.value = 20
		await _wait(func() -> bool: return _offer_has(_mine(), POTION, 3) and int(_mine().get(NetTrade.K_STARS, 0)) == 20, 6.0)
		_check("oferta_por_arrastar_e_estrelas", _offer_has(_mine(), POTION, 3) and int(_mine().get(NetTrade.K_STARS, 0)) == 20, _mine())
	else:
		ui.inventory._on_slot_activated(ui.inventory.get_slot(_slot_of(CAP)), true)
		await _wait(func() -> bool: return _offer_has(_mine(), CAP, 2), 6.0)
		_check("oferta_pelo_botao_direito", _offer_has(_mine(), CAP, 2), _mine())
	_check("ve_a_oferta_do_outro", await _wait(func() -> bool:
		return _offer_has(_theirs(), CAP if _role == ANA else POTION), 8.0), _theirs())
	await _barrier("ofertas")
	# 5) Confirmar; a Bia muda a oferta e as confirmações caem; confirmam de novo; "Trocar".
	ui.trade_window.confirm_button.pressed.emit()
	var both: bool = await _wait(func() -> bool:
		return bool(_mine().get(NetTrade.K_CONFIRMED, false)) and bool(_theirs().get(NetTrade.K_CONFIRMED, false)), 10.0)
	await _sleep(0.3)
	_check("os_dois_confirmam_e_trocar_liga", both and not ui.trade_window.commit_button.disabled)
	await _shot("confirmados")
	await _barrier("confirmados")
	if _role == BIA:
		NetTrade.send_stars(5)
	var reset: bool = await _wait(func() -> bool:
		return not bool(_mine().get(NetTrade.K_CONFIRMED, true)) and not bool(_theirs().get(NetTrade.K_CONFIRMED, true)) \
				and int((_theirs() if _role == ANA else _mine()).get(NetTrade.K_STARS, 0)) == 5, 8.0)
	_check("mudanca_desfaz_as_confirmacoes", reset and ui.trade_window.commit_button.disabled)
	await _barrier("mudou")
	ui.trade_window.confirm_button.pressed.emit()
	await _wait(func() -> bool:
		return bool(_mine().get(NetTrade.K_CONFIRMED, false)) and bool(_theirs().get(NetTrade.K_CONFIRMED, false)), 10.0)
	await _sleep(0.5)
	await _shot("prontos_para_trocar")
	await _barrier("reconfirmados")
	var mark2: int = _system.size()
	ui.trade_window.commit_button.pressed.emit()
	var done: bool = await _sys_after(mark2, "TRADE_DONE", 12.0)
	await _sleep(1.0)
	_check("troca_feita", done and not NetTrade.is_open() and not ui.trade_window.visible)
	if _role == ANA:
		_check("ana_recebeu_itens_e_estrelas", _count(CAP) == caps0 + 2 and _count(POTION) == potions0 - 3
				and _stars == stars0 - 20 + 5, {"cap": _count(CAP), "potion": _count(POTION), "stars": [stars0, _stars]})
	else:
		_check("bia_recebeu_itens_e_estrelas", _count(POTION) == potions0 + 3 and _count(CAP) == caps0 - 2
				and _stars == stars0 + 20 - 5, {"cap": _count(CAP), "potion": _count(POTION), "stars": [stars0, _stars]})
	await _shot("depois_da_troca")
	await _barrier("trocado")
	# 6) Nova troca e a Bia se afasta: cancela.
	if _role == ANA:
		await _sleep(Balance.cfg.trade_request_cooldown_sec)
		await _chat("/troca " + _other())
	else:
		await _wait(func() -> bool: return NetTrade.client_request_from == _other(), 20.0)
		await _chat("/troca aceitar")
	await _wait(func() -> bool: return NetTrade.is_open(), 10.0)
	await _barrier("aberta2")
	var mark3: int = _system.size()
	if _role == BIA:
		await _dbg(&"teleport", [_local.net_position.x + 20.0, _local.net_position.z])
	_check("afastar_cancela", await _sys_after(mark3, "TRADE_CANCELLED_FAR", 12.0) and not NetTrade.is_open())
	await _barrier("fim")
	_finish()


func _finish() -> void:
	var failed: Array = []
	for k: String in _checks:
		if not _checks[k]:
			failed.append(k)
	Net.log_line("trade_done_test", {"role": _role, "checks": _checks.size(), "failed": failed})
	_put("done")
	await _sleep(0.5)
	get_tree().quit(0 if failed.is_empty() else 1)
