class_name TradeService
extends RefCounted
## Troca entre personagens no servidor (pedido do dono em 30/09/2026; GDD §13). world.trade.
##
## Fluxo: pedido ("/troca nome" ou menu "Propor troca") -> Aceitar/Recusar -> janela com os dois lados ->
## cada um põe itens do inventário e Estrelas -> "Confirmar" trava a oferta -> com os dois confirmados, os dois
## apertam "Trocar" -> a troca sai de uma vez (atômica) ou não sai.
## Regras (todas aqui, o cliente só pede):
##  - os dois no mesmo mapa, a até Balance.cfg.trade_range_cells, vivos e fora de combate (pedido, aceite e
##    durante a troca: quem se afasta, morre, entra em combate, troca de mapa ou cai cancela);
##  - cada pilha oferecida precisa estar no inventário (item e quantidade); equipado não está no inventário;
##    ItemDef.tradeable = false e pilha protegida (ItemStack.protected) não entram;
##  - qualquer mudança (oferta, inventário ou Estrelas de um dos dois) desfaz a confirmação dos dois;
##  - na hora de trocar tudo é conferido de novo e simulado em cópias dos inventários (espaço); se algo
##    falhar, nada muda e a troca fecha com o motivo;
##  - antispam: Balance.cfg.trade_request_cooldown_sec entre pedidos, um pedido pendente por alvo.
## Log completo de cada troca (quem, o quê, quando) no log do servidor (trade_done) e em
## user://server_state/trades.jsonl (uma linha JSON por troca, para a moderação).

const MSG_REQUEST_SENT: String = "TRADE_REQUEST_SENT" # [nome]
const MSG_REQUESTED: String = "TRADE_REQUESTED" # [nome]
const MSG_OPENED: String = "TRADE_OPENED" # [nome]
const MSG_DECLINED: String = "TRADE_DECLINED" # [nome]
const MSG_YOU_DECLINED: String = "TRADE_YOU_DECLINED" # [nome]
const MSG_REQUEST_EXPIRED: String = "TRADE_REQUEST_EXPIRED" # [nome]
const MSG_CANCELLED: String = "TRADE_CANCELLED" # [nome]
const MSG_CANCELLED_FAR: String = "TRADE_CANCELLED_FAR"
const MSG_CANCELLED_COMBAT: String = "TRADE_CANCELLED_COMBAT"
const MSG_CANCELLED_DEAD: String = "TRADE_CANCELLED_DEAD"
const MSG_CANCELLED_LEFT: String = "TRADE_CANCELLED_LEFT" # [nome]
const MSG_DONE: String = "TRADE_DONE" # [nome]
const MSG_FAILED: String = "TRADE_FAILED"
const MSG_ERR_NOT_FOUND: String = "TRADE_ERR_NOT_FOUND" # [nome]
const MSG_ERR_SELF: String = "TRADE_ERR_SELF"
const MSG_ERR_BUSY: String = "TRADE_ERR_BUSY" # [nome]
const MSG_ERR_BUSY_SELF: String = "TRADE_ERR_BUSY_SELF"
const MSG_ERR_FAR: String = "TRADE_ERR_FAR" # [nome]
const MSG_ERR_COMBAT: String = "TRADE_ERR_COMBAT"
const MSG_ERR_DEAD: String = "TRADE_ERR_DEAD"
const MSG_ERR_TOO_FAST: String = "TRADE_ERR_TOO_FAST"
const MSG_ERR_NO_REQUEST: String = "TRADE_ERR_NO_REQUEST"
const MSG_ERR_NO_TRADE: String = "TRADE_ERR_NO_TRADE"
const MSG_ERR_NOT_OWNED: String = "TRADE_ERR_NOT_OWNED"
const MSG_ERR_NOT_TRADEABLE: String = "TRADE_ERR_NOT_TRADEABLE" # [item]
const MSG_ERR_TOO_MANY: String = "TRADE_ERR_TOO_MANY" # [máximo]
const MSG_ERR_NO_STARS: String = "TRADE_ERR_NO_STARS"
const MSG_ERR_NOT_CONFIRMED: String = "TRADE_ERR_NOT_CONFIRMED"
const MSG_ERR_NO_SPACE: String = "TRADE_ERR_NO_SPACE" # [nome]
const MSG_HELP: String = "TRADE_HELP"
## Palavras do chat ("/troca <palavra>"); sem palavra conhecida = pedido de troca para o nome.
const WORDS: Dictionary[String, StringName] = {
	"aceitar": NetTrade.CMD_ACCEPT, "accept": NetTrade.CMD_ACCEPT,
	"recusar": NetTrade.CMD_DECLINE, "decline": NetTrade.CMD_DECLINE,
	"cancelar": NetTrade.CMD_CANCEL, "cancel": NetTrade.CMD_CANCEL, "sair": NetTrade.CMD_CANCEL,
	"ajuda": &"help", "help": &"help", "?": &"help",
}
const STATE_DIR: String = "user://server_state/"
const AUTOTEST_STATE_DIR: String = "user://server_state_autotest/"
const ARG_STATE_DIR: String = "--state-dir="
const LOG_FILE: String = "trades.jsonl"
const TICK_MSEC: int = 250
const MSEC_PER_SEC: float = 1000.0


class TradeSide:
	var peer: int = 0
	var name: String = ""
	## [{"slot": int, "item": StringName, "qty": int}]
	var items: Array[Dictionary] = []
	var stars: int = 0
	var confirmed: bool = false
	var committed: bool = false


class Trade:
	var id: int = 0
	var a: TradeSide
	var b: TradeSide
	var map_id: StringName = &""
	var started_msec: int = 0

	func side_of(peer: int) -> TradeSide:
		return a if a.peer == peer else (b if b.peer == peer else null)

	func other_of(peer: int) -> TradeSide:
		return b if a.peer == peer else (a if b.peer == peer else null)


var world: ServerWorld = null
var log_path: String = ""
var _trades: Dictionary[int, Trade] = {}
## peer -> id da troca.
var _trade_of: Dictionary[int, int] = {}
## peer do convidado -> {"from": peer, "from_name": String, "expires": msec}
var _requests: Dictionary[int, Dictionary] = {}
var _last_request_msec: Dictionary[int, int] = {}
## peer -> Callable ligada ao Inventory.changed dele (enquanto troca).
var _watch: Dictionary[int, Callable] = {}
var _next_id: int = 0
var _next_tick_msec: int = 0


func _init(p_world: ServerWorld) -> void:
	world = p_world
	var dir: String = AUTOTEST_STATE_DIR if world.autotest else STATE_DIR
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(ARG_STATE_DIR):
			dir = a.trim_prefix(ARG_STATE_DIR).trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	log_path = dir + LOG_FILE
	NetTrade.command_intent.connect(_on_command_intent)
	Net.log_line("trade_ready", {"range_cells": Balance.cfg.trade_range_cells, "log": log_path})


# ================================================================ consultas

func is_trading(peer_id: int) -> bool:
	return _trade_of.has(peer_id)


func trade_of(peer_id: int) -> Trade:
	return _trades.get(_trade_of.get(peer_id, 0))


# ================================================================ comandos

func _on_command_intent(peer_id: int, cmd: StringName, a: Variant, b: Variant) -> void:
	var s: PlayerSession = world.get_session(peer_id)
	if s == null:
		Net.log_invalid(peer_id, "intent_without_session", {"intent": "trade"})
		return
	command(s, cmd, a, b)


## "/troca [palavra|nome]" do chat.
func chat_command(s: PlayerSession, rest: String) -> void:
	var text: String = rest.strip_edges()
	if text.is_empty():
		Net.push_system_message(s.peer_id, MSG_HELP)
		return
	var word: StringName = WORDS.get(text.get_slice(" ", 0).to_lower(), &"")
	if word.is_empty():
		command(s, NetTrade.CMD_REQUEST, text, 0)
	elif word == &"help":
		Net.push_system_message(s.peer_id, MSG_HELP)
	else:
		command(s, word, "", 0)


func command(s: PlayerSession, cmd: StringName, a: Variant, b: Variant) -> void:
	match cmd:
		NetTrade.CMD_REQUEST:
			request(s, str(a))
		NetTrade.CMD_ACCEPT:
			accept(s)
		NetTrade.CMD_DECLINE:
			decline(s)
		NetTrade.CMD_ITEM:
			set_item(s, int(a), int(b))
		NetTrade.CMD_STARS:
			set_stars(s, int(a))
		NetTrade.CMD_CONFIRM:
			confirm(s, true)
		NetTrade.CMD_UNCONFIRM:
			confirm(s, false)
		NetTrade.CMD_COMMIT:
			commit(s)
		NetTrade.CMD_CANCEL:
			cancel(s)
		_:
			Net.log_invalid(s.peer_id, "trade_unknown_command", {"cmd": String(cmd)})


func _fail(s: PlayerSession, reason: String, key: String, args: Array = [], data: Dictionary = {}) -> void:
	Net.log_invalid(s.peer_id, reason, data)
	Net.push_system_message(s.peer_id, key, args)


func request(s: PlayerSession, raw_name: String) -> void:
	var name: String = raw_name.strip_edges()
	if name.is_empty():
		Net.push_system_message(s.peer_id, MSG_HELP)
		return
	var t: PlayerSession = _session_by_name(name) if name.length() <= Net.MAX_NAME_LENGTH else null
	if t == null:
		_fail(s, "trade_request_not_found", MSG_ERR_NOT_FOUND, [name.left(Net.MAX_NAME_LENGTH)])
		return
	if t.peer_id == s.peer_id:
		_fail(s, "trade_request_self", MSG_ERR_SELF)
		return
	if is_trading(s.peer_id):
		_fail(s, "trade_request_busy_self", MSG_ERR_BUSY_SELF)
		return
	var now: int = Time.get_ticks_msec()
	var pending: Dictionary = _requests.get(t.peer_id, {})
	if is_trading(t.peer_id) or (not pending.is_empty() and int(pending["expires"]) > now \
			and int(pending["from"]) != s.peer_id):
		_fail(s, "trade_request_target_busy", MSG_ERR_BUSY, [t.character.char_name])
		return
	var why: Array = _pair_problem(s, t)
	if not why.is_empty():
		_fail(s, "trade_request_" + str(why[0]), str(why[1]), why[2])
		return
	if now - int(_last_request_msec.get(s.peer_id, -1000000)) < int(Balance.cfg.trade_request_cooldown_sec * MSEC_PER_SEC):
		_fail(s, "trade_request_too_fast", MSG_ERR_TOO_FAST)
		return
	_last_request_msec[s.peer_id] = now
	_requests[t.peer_id] = {"from": s.peer_id, "from_name": s.character.char_name,
			"expires": now + int(Balance.cfg.trade_request_timeout_sec * MSEC_PER_SEC)}
	NetTrade.push_request(t.peer_id, s.character.char_name, Balance.cfg.trade_request_timeout_sec)
	Net.push_system_message(t.peer_id, MSG_REQUESTED, [s.character.char_name])
	Net.push_system_message(s.peer_id, MSG_REQUEST_SENT, [t.character.char_name])
	Net.log_line("trade_request", {"from": s.character.char_name, "to": t.character.char_name,
			"map": String(world.get_instance_map_id(s.entity.instance_id))})


func accept(s: PlayerSession) -> void:
	var req: Dictionary = _take_request(s.peer_id)
	if req.is_empty():
		_fail(s, "trade_accept_without_request", MSG_ERR_NO_REQUEST)
		return
	NetTrade.push_request_closed(s.peer_id)
	var from: PlayerSession = world.get_session(int(req["from"]))
	if from == null:
		_fail(s, "trade_accept_requester_gone", MSG_ERR_NOT_FOUND, [req["from_name"]])
		return
	if is_trading(s.peer_id) or is_trading(from.peer_id):
		_fail(s, "trade_accept_busy", MSG_ERR_BUSY, [from.character.char_name])
		return
	var why: Array = _pair_problem(s, from)
	if not why.is_empty():
		_fail(s, "trade_accept_" + str(why[0]), str(why[1]), why[2])
		Net.push_system_message(from.peer_id, str(why[1]), why[2])
		return
	_open(from, s)


func decline(s: PlayerSession) -> void:
	var req: Dictionary = _take_request(s.peer_id)
	if req.is_empty():
		_fail(s, "trade_decline_without_request", MSG_ERR_NO_REQUEST)
		return
	NetTrade.push_request_closed(s.peer_id)
	Net.push_system_message(s.peer_id, MSG_YOU_DECLINED, [req["from_name"]])
	var from: PlayerSession = world.get_session(int(req["from"]))
	if from != null:
		Net.push_system_message(from.peer_id, MSG_DECLINED, [s.character.char_name])
	Net.log_line("trade_declined", {"by": s.character.char_name, "from": req["from_name"]})


func cancel(s: PlayerSession) -> void:
	var t: Trade = trade_of(s.peer_id)
	if t != null:
		_close(t, "cancel", MSG_CANCELLED, [s.character.char_name])
		return
	# Sem troca aberta: retira o pedido que fez (se houver).
	for target: int in _requests.keys():
		if int(_requests[target]["from"]) == s.peer_id:
			_requests.erase(target)
			NetTrade.push_request_closed(target)
			Net.push_system_message(target, MSG_CANCELLED, [s.character.char_name])
			Net.push_system_message(s.peer_id, MSG_CANCELLED, [s.character.char_name])
			Net.log_line("trade_request_withdrawn", {"from": s.character.char_name})
			return
	_fail(s, "trade_cancel_without_trade", MSG_ERR_NO_TRADE)


## Põe (qty > 0) ou tira (qty = 0) da oferta a pilha do espaço `slot` do inventário.
func set_item(s: PlayerSession, slot: int, qty: int) -> void:
	var t: Trade = _trade_for(s, "item")
	if t == null:
		return
	var side: TradeSide = t.side_of(s.peer_id)
	var inv: Inventory = s.character.inventory
	if not inv.is_valid_slot(slot) or qty < 0:
		_fail(s, "trade_item_bad_args", MSG_ERR_NOT_OWNED, [], {"slot": slot, "qty": qty})
		return
	var at: int = _entry_index(side, slot)
	if qty == 0:
		if at >= 0:
			side.items.remove_at(at)
			_changed(t, "item_removed", s)
		return
	var st: ItemStack = inv.get_slot(slot)
	if st == null or qty > st.qty:
		_fail(s, "trade_item_not_owned", MSG_ERR_NOT_OWNED, [],
				{"slot": slot, "qty": qty, "have": st.qty if st != null else 0, "item": String(st.item_id) if st != null else ""})
		return
	var def: ItemDef = st.get_def()
	if def == null or not def.tradeable or st.protected:
		_fail(s, "trade_item_not_tradeable", MSG_ERR_NOT_TRADEABLE, [def.name_key if def != null else String(st.item_id)],
				{"item": String(st.item_id), "protected": st.protected})
		return
	if at < 0 and side.items.size() >= Balance.cfg.trade_max_items:
		_fail(s, "trade_item_too_many", MSG_ERR_TOO_MANY, [Balance.cfg.trade_max_items])
		return
	var entry: Dictionary = {"slot": slot, "item": st.item_id, "qty": qty}
	if at >= 0:
		side.items[at] = entry
	else:
		side.items.append(entry)
	_changed(t, "item_set", s)


func set_stars(s: PlayerSession, amount: int) -> void:
	var t: Trade = _trade_for(s, "stars")
	if t == null:
		return
	if amount < 0 or amount > s.character.stars:
		_fail(s, "trade_stars_not_owned", MSG_ERR_NO_STARS, [], {"amount": amount, "have": s.character.stars})
		return
	t.side_of(s.peer_id).stars = amount
	_changed(t, "stars_set", s)


func confirm(s: PlayerSession, on: bool) -> void:
	var t: Trade = _trade_for(s, "confirm")
	if t == null:
		return
	var side: TradeSide = t.side_of(s.peer_id)
	side.confirmed = on
	if not on:
		t.a.committed = false
		t.b.committed = false
	Net.log_line("trade_confirm", {"trade": t.id, "name": s.character.char_name, "on": on})
	_push(t)


func commit(s: PlayerSession) -> void:
	var t: Trade = _trade_for(s, "commit")
	if t == null:
		return
	if not (t.a.confirmed and t.b.confirmed):
		_fail(s, "trade_commit_not_confirmed", MSG_ERR_NOT_CONFIRMED)
		return
	t.side_of(s.peer_id).committed = true
	Net.log_line("trade_commit", {"trade": t.id, "name": s.character.char_name})
	if t.a.committed and t.b.committed:
		_execute(t)
	else:
		_push(t)


func _trade_for(s: PlayerSession, what: String) -> Trade:
	var t: Trade = trade_of(s.peer_id)
	if t == null:
		_fail(s, "trade_%s_without_trade" % what, MSG_ERR_NO_TRADE)
	return t


# ================================================================ ciclo de vida (ServerWorld)

func on_peer_left(peer_id: int, char_name: String) -> void:
	var t: Trade = trade_of(peer_id)
	if t != null:
		_close(t, "disconnect", MSG_CANCELLED_LEFT, [char_name], peer_id)
	_requests.erase(peer_id)
	for target: int in _requests.keys():
		if int(_requests[target]["from"]) == peer_id:
			_requests.erase(target)
			NetTrade.push_request_closed(target)
	_last_request_msec.erase(peer_id)


func tick() -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_tick_msec:
		return
	_next_tick_msec = now + TICK_MSEC
	for target: int in _requests.keys():
		var req: Dictionary = _requests[target]
		if int(req["expires"]) > now:
			continue
		_requests.erase(target)
		NetTrade.push_request_closed(target)
		var from: PlayerSession = world.get_session(int(req["from"]))
		var ts: PlayerSession = world.get_session(target)
		if from != null:
			Net.push_system_message(from.peer_id, MSG_REQUEST_EXPIRED, [ts.character.char_name if ts != null else "?"])
	for t: Trade in _trades.values():
		var sa: PlayerSession = world.get_session(t.a.peer)
		var sb: PlayerSession = world.get_session(t.b.peer)
		if sa == null or sb == null:
			_close(t, "disconnect", MSG_CANCELLED_LEFT, [t.a.name if sa == null else t.b.name])
			continue
		var why: Array = _pair_problem(sa, sb)
		if not why.is_empty():
			var key: String = MSG_CANCELLED_FAR
			match str(why[0]):
				"combat":
					key = MSG_CANCELLED_COMBAT
				"dead":
					key = MSG_CANCELLED_DEAD
			_close(t, str(why[0]), key, [])
			continue
		# Estrelas gastas fora da troca: a oferta não pode passar do que tem.
		for side: TradeSide in [t.a, t.b]:
			var ss: PlayerSession = sa if side == t.a else sb
			if side.stars > ss.character.stars:
				side.stars = ss.character.stars
				_changed(t, "stars_clamped", ss)


# ================================================================ internos

## [motivo, chave, args] se o par não pode trocar agora; [] = pode.
func _pair_problem(s: PlayerSession, t: PlayerSession) -> Array:
	if s.entity == null or t.entity == null or s.entity.instance_id != t.entity.instance_id:
		return ["far", MSG_ERR_FAR, [t.character.char_name]]
	var range_m: float = Balance.cfg.trade_range_cells * Balance.cfg.cell_size
	if s.entity.flat_distance_to(t.entity.net_position) > range_m:
		return ["far", MSG_ERR_FAR, [t.character.char_name]]
	var combat: CombatService = world.combat
	if combat != null:
		if combat.is_dead(s.peer_id) or combat.is_dead(t.peer_id) or s.character.hp <= 0 or t.character.hp <= 0:
			return ["dead", MSG_ERR_DEAD, []]
		if Balance.cfg.trade_blocked_in_combat and (combat.is_in_combat(s.peer_id) or combat.is_in_combat(t.peer_id)):
			return ["combat", MSG_ERR_COMBAT, []]
	return []


func _session_by_name(name: String) -> PlayerSession:
	var k: String = name.strip_edges().to_lower()
	for s: PlayerSession in world.get_sessions():
		if s.character.char_name.to_lower() == k:
			return s
	return null


func _take_request(peer_id: int) -> Dictionary:
	var req: Dictionary = _requests.get(peer_id, {})
	_requests.erase(peer_id)
	if req.is_empty() or int(req["expires"]) <= Time.get_ticks_msec():
		return {}
	return req


func _entry_index(side: TradeSide, slot: int) -> int:
	for i: int in side.items.size():
		if int(side.items[i]["slot"]) == slot:
			return i
	return -1


func _open(from: PlayerSession, to: PlayerSession) -> void:
	_next_id += 1
	var t := Trade.new()
	t.id = _next_id
	t.a = TradeSide.new()
	t.a.peer = from.peer_id
	t.a.name = from.character.char_name
	t.b = TradeSide.new()
	t.b.peer = to.peer_id
	t.b.name = to.character.char_name
	t.map_id = world.get_instance_map_id(from.entity.instance_id)
	t.started_msec = Time.get_ticks_msec()
	_trades[t.id] = t
	_trade_of[from.peer_id] = t.id
	_trade_of[to.peer_id] = t.id
	for s: PlayerSession in [from, to]:
		var cb := _on_inventory_changed.bind(s.peer_id)
		_watch[s.peer_id] = cb
		s.character.inventory.changed.connect(cb)
	Net.push_system_message(from.peer_id, MSG_OPENED, [to.character.char_name])
	Net.push_system_message(to.peer_id, MSG_OPENED, [from.character.char_name])
	Net.log_line("trade_opened", {"trade": t.id, "a": t.a.name, "b": t.b.name, "map": String(t.map_id)})
	_push(t)


## O inventário de quem troca mudou: ofertas que não valem mais saem (ou diminuem) e as confirmações caem.
func _on_inventory_changed(peer_id: int) -> void:
	var t: Trade = trade_of(peer_id)
	var s: PlayerSession = world.get_session(peer_id)
	if t == null or s == null:
		return
	var side: TradeSide = t.side_of(peer_id)
	var keep: Array[Dictionary] = []
	for e: Dictionary in side.items:
		var st: ItemStack = s.character.inventory.get_slot(int(e["slot"]))
		if st == null or st.item_id != e["item"]:
			continue
		e["qty"] = mini(int(e["qty"]), st.qty)
		keep.append(e)
	side.items = keep
	_changed(t, "inventory_changed", s)


## Qualquer mudança desfaz a confirmação dos dois.
func _changed(t: Trade, why: String, by: PlayerSession) -> void:
	for side: TradeSide in [t.a, t.b]:
		side.confirmed = false
		side.committed = false
	Net.log_line("trade_offer", {"trade": t.id, "by": by.character.char_name, "why": why,
			"a": _side_log(t.a), "b": _side_log(t.b)})
	_push(t)


func _push(t: Trade) -> void:
	for side: TradeSide in [t.a, t.b]:
		if world.get_session(side.peer) != null:
			NetTrade.push_state(side.peer, state_for(t, side.peer))


## Estado para o cliente: {"partner", "mine", "theirs"}.
func state_for(t: Trade, peer_id: int) -> Dictionary:
	var mine: TradeSide = t.side_of(peer_id)
	var theirs: TradeSide = t.other_of(peer_id)
	return {NetTrade.K_PARTNER: theirs.name, NetTrade.K_MINE: _side_state(mine, true),
			NetTrade.K_THEIRS: _side_state(theirs, false)}


static func _side_state(side: TradeSide, with_slots: bool) -> Dictionary:
	var items: Array = []
	for e: Dictionary in side.items:
		items.append({NetTrade.K_SLOT: int(e["slot"]) if with_slots else -1, NetTrade.K_ITEM: String(e["item"]),
				NetTrade.K_QTY: int(e["qty"])})
	return {NetTrade.K_ITEMS: items, NetTrade.K_STARS: side.stars, NetTrade.K_CONFIRMED: side.confirmed,
			NetTrade.K_COMMITTED: side.committed}


static func _side_log(side: TradeSide) -> Dictionary:
	var items: Array = []
	for e: Dictionary in side.items:
		items.append("%s x%d" % [e["item"], int(e["qty"])])
	return {"name": side.name, "items": items, "stars": side.stars, "confirmed": side.confirmed}


func _close(t: Trade, reason: String, key: String, args: Array, skip_peer: int = 0) -> void:
	for side: TradeSide in [t.a, t.b]:
		_trade_of.erase(side.peer)
		var cb: Variant = _watch.get(side.peer)
		_watch.erase(side.peer)
		var s: PlayerSession = world.get_session(side.peer)
		if s != null and cb is Callable and s.character.inventory.changed.is_connected(cb):
			s.character.inventory.changed.disconnect(cb)
		if s != null and side.peer != skip_peer:
			NetTrade.push_state(side.peer, {})
			if not key.is_empty():
				Net.push_system_message(side.peer, key, args)
	_trades.erase(t.id)
	Net.log_line("trade_closed", {"trade": t.id, "reason": reason, "a": _side_log(t.a), "b": _side_log(t.b)})


## Troca de verdade: confere tudo de novo, simula em cópias dos inventários e só então aplica.
func _execute(t: Trade) -> void:
	var sa: PlayerSession = world.get_session(t.a.peer)
	var sb: PlayerSession = world.get_session(t.b.peer)
	if sa == null or sb == null:
		_close(t, "disconnect", MSG_CANCELLED_LEFT, [t.a.name if sa == null else t.b.name])
		return
	var why: Array = _pair_problem(sa, sb)
	var problem: String = str(why[0]) if not why.is_empty() else ""
	if problem.is_empty():
		problem = _side_problem(t.a, sa)
	if problem.is_empty():
		problem = _side_problem(t.b, sb)
	if not problem.is_empty():
		Net.log_invalid(sa.peer_id, "trade_execute_refused", {"trade": t.id, "problem": problem})
		_close(t, "refused_" + problem, MSG_FAILED, [])
		return
	var ca: Inventory = _simulate(sa.character.inventory, t.a, t.b)
	var cb: Inventory = _simulate(sb.character.inventory, t.b, t.a)
	if ca == null or cb == null:
		var who: String = t.a.name if ca == null else t.b.name
		Net.log_invalid(sa.peer_id if ca == null else sb.peer_id, "trade_execute_no_space", {"trade": t.id})
		_close(t, "no_space", MSG_ERR_NO_SPACE, [who])
		return
	# Aplica (sem os observadores, para não desfazer a confirmação no meio).
	for side: TradeSide in [t.a, t.b]:
		var s: PlayerSession = sa if side == t.a else sb
		var cbv: Variant = _watch.get(side.peer)
		if cbv is Callable and s.character.inventory.changed.is_connected(cbv):
			s.character.inventory.changed.disconnect(cbv)
	_apply(sa, t.a, sb, t.b)
	sa.character.stars += t.b.stars - t.a.stars
	sb.character.stars += t.a.stars - t.b.stars
	for s: PlayerSession in [sa, sb]:
		s.mark_dirty(PlayerSession.DIRTY_INVENTORY | PlayerSession.DIRTY_CURRENCY)
		world.store.save_character(s.character)
	var record: Dictionary = {"time": Time.get_datetime_string_from_system(true), "trade": t.id,
			"map": String(t.map_id), "a": _side_log(t.a), "b": _side_log(t.b),
			"stars_after": {t.a.name: sa.character.stars, t.b.name: sb.character.stars}}
	Net.log_line("trade_done", record)
	_append_log(record)
	_close(t, "done", MSG_DONE, [])


## "" = o lado ainda tem tudo o que oferece; senão o motivo.
func _side_problem(side: TradeSide, s: PlayerSession) -> String:
	if side.stars < 0 or side.stars > s.character.stars:
		return "stars"
	for e: Dictionary in side.items:
		var st: ItemStack = s.character.inventory.get_slot(int(e["slot"]))
		if st == null or st.item_id != e["item"] or int(e["qty"]) <= 0 or int(e["qty"]) > st.qty:
			return "item_missing"
		var def: ItemDef = st.get_def()
		if def == null or not def.tradeable or st.protected:
			return "item_not_tradeable"
	return ""


## Cópia do inventário com a troca aplicada (null = não cabe).
func _simulate(inv: Inventory, gives: TradeSide, gets: TradeSide) -> Inventory:
	var c := Inventory.new(inv.size())
	c.bind_zone = inv.bind_zone
	for i: int in inv.size():
		var st: ItemStack = inv.get_slot(i)
		if st != null:
			c.put_at(i, st.copy_with_qty(st.qty))
	for e: Dictionary in gives.items:
		if not c.remove_at(int(e["slot"]), int(e["qty"])):
			return null
	for e: Dictionary in gets.items:
		if not c.add(StringName(e["item"]), int(e["qty"])):
			return null
	return c


func _apply(sa: PlayerSession, a: TradeSide, sb: PlayerSession, b: TradeSide) -> void:
	for e: Dictionary in a.items:
		sa.character.inventory.remove_at(int(e["slot"]), int(e["qty"]))
	for e: Dictionary in b.items:
		sb.character.inventory.remove_at(int(e["slot"]), int(e["qty"]))
	for e: Dictionary in b.items:
		sa.character.inventory.add(StringName(e["item"]), int(e["qty"]))
	for e: Dictionary in a.items:
		sb.character.inventory.add(StringName(e["item"]), int(e["qty"]))


func _append_log(record: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE) if FileAccess.file_exists(log_path) \
			else FileAccess.open(log_path, FileAccess.WRITE)
	if f == null:
		Net.log_line("trade_log_failed", {"path": log_path})
		return
	f.seek_end()
	f.store_line(JSON.stringify(record))
	f.close()
