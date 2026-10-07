extends Node
## Autoload "NetTrade": troca entre personagens (pedido do dono em 30/09/2026). Mesmo caminho (/root/NetTrade)
## no servidor e no cliente. Formato e taxa validados aqui (via Net); as regras (posse, quantidades, espaço,
## distância, combate) ficam no TradeService do servidor, que é a única autoridade.
##
## Cliente -> servidor: send_command(cmd, a, b)
##   request <nome>            pede troca (mesmo mapa, perto, fora de combate)
##   accept / decline          responde ao pedido pendente
##   item <slot> <qty>         põe (qty > 0) ou tira (qty = 0) a pilha do espaço do inventário da oferta
##   stars <quantia>           Estrelas oferecidas
##   confirm / unconfirm       trava / destrava a própria oferta
##   commit                    "Trocar" (só vale com os dois confirmados; a troca sai quando os dois apertam)
##   cancel                    fecha a troca (ou retira o próprio pedido)
## Servidor -> cliente:
##   request_received(from_name, timeout_sec) / request_closed()
##   trade_changed(state)      {} = sem troca; senão {"partner": nome, "mine": lado, "theirs": lado}, lado =
##                             {"items": [{"slot", "item", "qty"}], "stars", "confirmed", "committed"}

signal command_intent(peer_id: int, cmd: StringName, a: Variant, b: Variant)
signal request_received(from_name: String, timeout_sec: float)
signal request_closed()
signal trade_changed(state: Dictionary)

const CMD_REQUEST: StringName = &"request"
const CMD_ACCEPT: StringName = &"accept"
const CMD_DECLINE: StringName = &"decline"
const CMD_ITEM: StringName = &"item"
const CMD_STARS: StringName = &"stars"
const CMD_CONFIRM: StringName = &"confirm"
const CMD_UNCONFIRM: StringName = &"unconfirm"
const CMD_COMMIT: StringName = &"commit"
const CMD_CANCEL: StringName = &"cancel"
const COMMANDS: Array[StringName] = [CMD_REQUEST, CMD_ACCEPT, CMD_DECLINE, CMD_ITEM, CMD_STARS,
		CMD_CONFIRM, CMD_UNCONFIRM, CMD_COMMIT, CMD_CANCEL]
const MAX_ARG_LENGTH: int = 64
const K_PARTNER: String = "partner"
const K_MINE: String = "mine"
const K_THEIRS: String = "theirs"
const K_ITEMS: String = "items"
const K_STARS: String = "stars"
const K_CONFIRMED: String = "confirmed"
const K_COMMITTED: String = "committed"
const K_SLOT: String = "slot"
const K_ITEM: String = "item"
const K_QTY: String = "qty"

## Cliente: troca aberta ({} = nenhuma) e quem pediu troca ("" = nenhum pedido pendente).
var client_trade: Dictionary = {}
var client_request_from: String = ""


# ---------------------------------------------------------------- cliente

func _is_client_connected() -> bool:
	return not Net.is_server and multiplayer.multiplayer_peer != null \
			and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
			and multiplayer.multiplayer_peer.get_connection_status() \
			== MultiplayerPeer.CONNECTION_CONNECTED


func send_command(cmd: StringName, a: Variant = "", b: Variant = 0) -> void:
	if _is_client_connected():
		_srv_trade.rpc_id(Net.SERVER_PEER_ID, String(cmd), a, b)


func send_request(player_name: String) -> void:
	send_command(CMD_REQUEST, player_name)


func send_accept() -> void:
	send_command(CMD_ACCEPT)


func send_decline() -> void:
	send_command(CMD_DECLINE)


func send_item(slot: int, qty: int) -> void:
	send_command(CMD_ITEM, slot, qty)


func send_stars(amount: int) -> void:
	send_command(CMD_STARS, amount)


func send_confirm(on: bool) -> void:
	send_command(CMD_CONFIRM if on else CMD_UNCONFIRM)


func send_commit() -> void:
	send_command(CMD_COMMIT)


func send_cancel() -> void:
	send_command(CMD_CANCEL)


func is_open() -> bool:
	return not client_trade.is_empty()


@rpc("authority", "call_remote", "reliable")
func _cli_request(from_name: String, timeout_sec: float) -> void:
	client_request_from = from_name
	Net.log_line("trade_request_received", {"from": from_name})
	request_received.emit(from_name, timeout_sec)


@rpc("authority", "call_remote", "reliable")
func _cli_request_closed() -> void:
	client_request_from = ""
	request_closed.emit()


@rpc("authority", "call_remote", "reliable")
func _cli_state(state: Dictionary) -> void:
	var was_open: bool = is_open()
	client_trade = state
	if was_open != is_open():
		Net.log_line("trade_window", {"open": is_open(), "partner": str(state.get(K_PARTNER, ""))})
	trade_changed.emit(state)


# ---------------------------------------------------------------- servidor

func push_request(peer_id: int, from_name: String, timeout_sec: float) -> void:
	_cli_request.rpc_id(peer_id, from_name, timeout_sec)


func push_request_closed(peer_id: int) -> void:
	_cli_request_closed.rpc_id(peer_id)


func push_state(peer_id: int, state: Dictionary) -> void:
	_cli_state.rpc_id(peer_id, state)


@rpc("any_peer", "call_remote", "reliable")
func _srv_trade(cmd: Variant, a: Variant, b: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not Net._accept_world_intent(peer_id, "trade"):
		return
	if not Net._is_text(cmd) or StringName(cmd) not in COMMANDS:
		Net.log_invalid(peer_id, "trade_bad_args", {"cmd": str(cmd).left(MAX_ARG_LENGTH)})
		return
	var c := StringName(cmd)
	match c:
		CMD_REQUEST:
			if not Net._is_text(a) or String(a).length() > MAX_ARG_LENGTH:
				Net.log_invalid(peer_id, "trade_bad_args", {"cmd": String(c)})
				return
			a = String(a).strip_escapes().strip_edges()
		CMD_ITEM:
			if typeof(a) != TYPE_INT or typeof(b) != TYPE_INT:
				Net.log_invalid(peer_id, "trade_bad_args", {"cmd": String(c)})
				return
		CMD_STARS:
			if typeof(a) != TYPE_INT:
				Net.log_invalid(peer_id, "trade_bad_args", {"cmd": String(c)})
				return
	command_intent.emit(peer_id, c, a, b)
