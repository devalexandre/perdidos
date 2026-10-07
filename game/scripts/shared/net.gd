extends Node
## Autoload "Net": transporte ENet, handshake com protocol_version, limite de taxa por cliente,
## RPCs de intenção (GDD §15.4) e eventos servidor→cliente (contrato city-walk, "Mensagens de rede").
## Mesmo script no servidor e no cliente (caminho /root/Net).
##
## Fluxo:
##   cliente conecta -> _srv_hello(versão, nome, corpo) -> servidor valida
##   servidor -> _cli_enter_instance(instance_id, map_id) -> cliente monta a subárvore da instância
##   cliente -> _srv_instance_ready(instance_id) -> servidor cria/mostra a entidade do jogador
##   cliente -> req_*(...) (intenções; o Net valida formato/taxa e o ServerWorld valida as regras)
##   servidor -> _cli_*(...) (eventos; estado privado vai SÓ para o dono, via rpc_id)
##
## Cliente (interface de B): chama Net.send_*() e escuta os sinais da seção "Sinais do cliente".

# ================================================================ sinais do servidor
## Peer terminou o handshake (ServerWorld decide a instância).
signal peer_joined(peer_id: int, display_name: String, body_type: StringName)
## Cliente confirmou que montou a subárvore da instância.
signal peer_instance_ready(peer_id: int, instance_id: StringName)
## Peer saiu (só emitido para peers que completaram o handshake).
signal peer_left(peer_id: int)
## Intenções já validadas quanto a formato, taxa e "está no mundo" (não quanto às regras de jogo).
signal move_intent(peer_id: int, target: Vector3)
signal interact_intent(peer_id: int, target_id: String)
signal dialogue_choice_intent(peer_id: int, option_index: int)
signal dialogue_close_intent(peer_id: int)
signal inventory_move_intent(peer_id: int, from_slot: int, to_slot: int)
signal use_item_intent(peer_id: int, slot: int)
signal equip_intent(peer_id: int, slot: int)
signal unequip_intent(peer_id: int, equip_slot: StringName)
signal shop_buy_intent(peer_id: int, item_id: StringName, qty: int)
signal shop_sell_intent(peer_id: int, slot: int, qty: int)
signal shop_close_intent(peer_id: int)
signal chat_intent(peer_id: int, channel: StringName, text: String)
signal emote_intent(peer_id: int, emote_id: StringName)

# ================================================================ sinais do cliente
## O servidor mandou entrar numa instância.
signal enter_instance_requested(instance_id: StringName, map_id: StringName)
## A entidade do jogador local apareceu (um NetEntity).
signal local_player_spawned(player: Node3D)
## Texto de status para a interface (já traduzido).
signal status_changed(text: String)
## A conexão acabou (falha, recusa ou queda). reason_key = chave de tradução do motivo.
signal connection_closed(reason_key: String)
## 40 posições, cada uma {} ou {"item": StringName, "qty": int}.
signal inventory_changed(slots: Array)
## weapon, offhand, head, body, feet, accessory_1, accessory_2 -> item_id ou &"".
signal equipment_changed(equip: Dictionary)
## level, hp, max_hp, mp, max_mp, atk, matk, def, mdef, str, dex, vit, int, spi.
signal stats_changed(stats: Dictionary)
signal currency_changed(stars: int)
## Opções já filtradas pelo servidor; o índice escolhido refere-se a esta lista.
signal dialogue_opened(npc_entity_id: int, speaker_key: String, text_key: String, options: Array[String])
signal dialogue_closed()
signal shop_opened(shop_id: StringName, items: Array[StringName])
signal shop_closed()
signal chat_received(channel: StringName, from_name: String, text: String, from_entity_id: int)
signal emote_received(entity_id: int, emote_id: StringName)
## Erros e avisos: chave de tradução (localization/strings.csv, B) + argumentos para format.
signal system_message(key: String, args: Array)

const MAX_CLIENTS: int = 64
const MAX_NAME_LENGTH: int = 16
const HANDSHAKE_TIMEOUT_MSEC: int = 5000
const REJECT_DISCONNECT_DELAY_SEC: float = 0.5
const RATE_WINDOW_MSEC: int = 1000
const BODY_TYPES: Array[StringName] = [&"male", &"female"]
const DEFAULT_BODY_TYPE: StringName = &"male"
const REJECT_PROTOCOL_MISMATCH: StringName = &"protocol_mismatch"
const REJECT_NAME_IN_USE: StringName = &"name_in_use"
const REJECT_NAME_OFFENSIVE: StringName = &"name_offensive"
## Login (servidor com --require-auth; motivos vêm do AuthGate): sem token, token inválido/vencido,
## nome de personagem que pertence a outra conta.
const REJECT_AUTH_REQUIRED: StringName = &"auth_required"
const REJECT_AUTH_INVALID: StringName = &"auth_invalid"
const REJECT_AUTH_EXPIRED: StringName = &"auth_expired"
const REJECT_NAME_OWNED: StringName = &"name_owned"
## Conta sem slot livre. O motivo vai como "slot_full|<nome do personagem da conta>".
const REJECT_SLOT_FULL: StringName = &"slot_full"
const REJECT_DETAIL_SEP: String = "|"
## Separador do instance_id de caça (GDD §5.1) e sua forma segura em nome de nó.
const INSTANCE_SEPARATOR: String = ":"
const INSTANCE_NODE_SEPARATOR: String = "__"
const SERVER_PEER_ID: int = 1
## Tamanho bruto máximo aceito num req_chat/target_id antes de qualquer regra (anti-abuso);
## o limite de jogo (200) é do ChatService.
const MAX_RAW_TEXT_LENGTH: int = 1024
const MAX_RAW_ID_LENGTH: int = 128
## Emotes válidos (contrato): &"sit" alterna a animação de sentar.
const EMOTES: Array[StringName] = [&"wave", &"sit", &"laugh", &"cry", &"angry", &"heart"]
const EMOTE_SIT: StringName = &"sit"
const CHANNEL_LOCAL: StringName = &"local"
## Chat do grupo (/g ou aba "Grupo"): só os membros, em qualquer mapa (PartyService).
const CHANNEL_PARTY: StringName = &"party"

# Chaves de tradução de status/conexão (strings.csv, B).
const KEY_CONNECTING: String = "NET_CONNECTING"
const KEY_CONNECTION_FAILED: String = "NET_CONNECTION_FAILED"
const KEY_DISCONNECTED: String = "NET_DISCONNECTED"
const KEY_UPDATE_REQUIRED: String = "NET_UPDATE_REQUIRED"
const KEY_NAME_IN_USE: String = "NET_NAME_IN_USE"
const KEY_NAME_OFFENSIVE: String = "NET_NAME_OFFENSIVE"
const KEY_AUTH_REQUIRED: String = "NET_AUTH_REQUIRED"
const KEY_AUTH_INVALID: String = "NET_AUTH_INVALID"
const KEY_NAME_OWNED: String = "NET_NAME_OWNED"
const KEY_SLOT_FULL: String = "NET_SLOT_FULL"

## Estado por peer, só no servidor.
class PeerState:
	var connected_msec: int = 0
	var handshaken: bool = false
	var display_name: String = ""
	var body_type: StringName = &"male"
	## Instância em que o peer está de fato (usado no filtro de visibilidade).
	var instance_id: StringName = &""
	## Instância para a qual o peer foi mandado e ainda não confirmou.
	var pending_instance_id: StringName = &""
	var rate_window_start_msec: int = 0
	var rate_count: int = 0
	var rate_logged: bool = false
	## Conta dona do token (0 = servidor sem --require-auth).
	var account_id: int = 0

var is_server: bool = false
var _peers: Dictionary[int, PeerState] = {}
## Servidor: AuthGate (scripts/server/auth) quando sobe com --require-auth; null = sem login.
var auth_gate: RefCounted = null

# Estado do cliente.
var _client_name: String = ""
var _client_body: StringName = DEFAULT_BODY_TYPE
var _client_protocol: int = 0
var _rejected: bool = false
## Última recusa do servidor (motivo e detalhe, ex. slot_full + nome do personagem da conta).
var last_rejection: StringName = &""
var rejection_detail: String = ""
## Cliente: JWT recebido do launcher (--token=...), mandado no handshake.
var client_auth_token: String = ""

## Cliente: último estado recebido (para janelas abertas depois do evento).
var client_inventory: Array = []
var client_equipment: Dictionary = {}
var client_stats: Dictionary = {}
var client_stars: int = 0
## NPC com diálogo aberto (0 = nenhum) e loja aberta (&"" = nenhuma).
var client_dialogue_npc_id: int = 0
var client_shop_id: StringName = &""


# ================================================================ utilitários compartilhados

## instance_id conforme GDD §5.1 (30/09/2026): todo mapa = map_id (uma instância compartilhada). O sufixo
## ":" + party_id só existe em testes (instância extra para conferir o filtro de visibilidade do §5.6).
static func make_instance_id(map_id: StringName, party_id: String = "") -> StringName:
	if party_id.is_empty():
		return map_id
	return StringName(String(map_id) + INSTANCE_SEPARATOR + party_id)


## Nome do nó da instância (":" não é permitido em nomes de nó).
static func instance_node_name(instance_id: StringName) -> String:
	return String(instance_id).replace(INSTANCE_SEPARATOR, INSTANCE_NODE_SEPARATOR)


func log_line(event: String, data: Dictionary = {}) -> void:
	var role: String = "server" if is_server else "client"
	print("[%s] %s %s" % [role, event, JSON.stringify(data)])


func log_invalid(peer_id: int, reason: String, data: Dictionary = {}) -> void:
	var d: Dictionary = data.duplicate()
	d["peer"] = peer_id
	d["reason"] = reason
	log_line("invalid_message", d)


static func _is_text(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME


# ================================================================ transporte

const TRANSPORT_ENET: StringName = &"enet"
const TRANSPORT_WS: StringName = &"ws"
## Domínios de túnel HTTP que só aceitam WebSocket (UDP não passa).
const WS_TUNNEL_SUFFIXES: PackedStringArray = [".ngrok-free.dev", ".ngrok-free.app", ".ngrok.app", ".ngrok.dev", ".ngrok.io"]
## Mensagens grandes (mapa, inventário, aparência) passam do buffer padrão de 64 KB.
const WS_BUFFER_BYTES: int = 4 * 1024 * 1024
const WS_MAX_QUEUED_PACKETS: int = 16384


## URL WebSocket para o host digitado, ou "" para usar ENet (UDP).
## "wss://x" / "ws://x" viram URL direta; domínio de túnel (ngrok) vira "wss://<domínio>".
static func websocket_url(host: String) -> String:
	var h: String = host.strip_edges()
	if h.begins_with("ws://") or h.begins_with("wss://"):
		return h
	if h.begins_with("https://"):
		return "wss://" + h.trim_prefix("https://").trim_suffix("/")
	if h.begins_with("http://"):
		return "ws://" + h.trim_prefix("http://").trim_suffix("/")
	for suffix: String in WS_TUNNEL_SUFFIXES:
		if h.ends_with(suffix):
			return "wss://" + h
	return ""


static func _tune_ws(ws: WebSocketMultiplayerPeer) -> void:
	ws.inbound_buffer_size = WS_BUFFER_BYTES
	ws.outbound_buffer_size = WS_BUFFER_BYTES
	ws.max_queued_packets = WS_MAX_QUEUED_PACKETS


# ================================================================ servidor

## transport: TRANSPORT_ENET (UDP, padrão) ou TRANSPORT_WS (WebSocket em TCP; passa por túnel HTTP como o ngrok).
func start_server(port: int, transport: StringName = TRANSPORT_ENET) -> Error:
	is_server = true
	var peer: MultiplayerPeer
	var err: Error
	if transport == TRANSPORT_WS:
		var ws := WebSocketMultiplayerPeer.new()
		_tune_ws(ws)
		err = ws.create_server(port)
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		err = enet.create_server(port, MAX_CLIENTS)
		peer = enet
	if err != OK:
		log_line("server_start_failed", {"port": port, "transport": String(transport), "error": err})
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	log_line("server_started", {"port": port, "transport": String(transport), "protocol": Balance.cfg.protocol_version})
	return OK


## Instância em que o peer está (vazio se nenhuma). Usado pelos filtros de visibilidade.
func get_peer_instance(peer_id: int) -> StringName:
	var st: PeerState = _peers.get(peer_id)
	return st.instance_id if st != null else &""


func get_peer_display_name(peer_id: int) -> String:
	var st: PeerState = _peers.get(peer_id)
	return st.display_name if st != null else ""


## Conta do peer (0 = sem login).
func get_peer_account_id(peer_id: int) -> int:
	var st: PeerState = _peers.get(peer_id)
	return st.account_id if st != null else 0


func get_peer_body_type(peer_id: int) -> StringName:
	var st: PeerState = _peers.get(peer_id)
	return st.body_type if st != null else DEFAULT_BODY_TYPE


## Peers que já estão numa instância (handshake feito e subárvore montada).
func get_world_peer_ids() -> Array[int]:
	var out: Array[int] = []
	for peer_id: int in _peers:
		if not _peers[peer_id].instance_id.is_empty():
			out.append(peer_id)
	return out


## Peers numa instância específica.
func get_instance_peer_ids(instance_id: StringName) -> Array[int]:
	var out: Array[int] = []
	for peer_id: int in _peers:
		if _peers[peer_id].instance_id == instance_id and not instance_id.is_empty():
			out.append(peer_id)
	return out


## Servidor: manda o cliente montar a instância; ele responde com _srv_instance_ready.
func send_enter_instance(peer_id: int, instance_id: StringName, map_id: StringName) -> void:
	var st: PeerState = _peers.get(peer_id)
	if st == null:
		return
	st.pending_instance_id = instance_id
	_cli_enter_instance.rpc_id(peer_id, String(instance_id), String(map_id))


## Servidor: confirma a instância efetiva do peer (depois disso os filtros o incluem).
func set_peer_instance(peer_id: int, instance_id: StringName) -> void:
	var st: PeerState = _peers.get(peer_id)
	if st != null:
		st.instance_id = instance_id
		st.pending_instance_id = &""


func _process(_delta: float) -> void:
	if not is_server:
		return
	# Derruba quem não fez handshake a tempo.
	var now: int = Time.get_ticks_msec()
	for peer_id: int in _peers.keys():
		var st: PeerState = _peers[peer_id]
		if not st.handshaken and now - st.connected_msec > HANDSHAKE_TIMEOUT_MSEC:
			log_invalid(peer_id, "handshake_timeout")
			_peers.erase(peer_id)
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	var st := PeerState.new()
	st.connected_msec = Time.get_ticks_msec()
	st.rate_window_start_msec = st.connected_msec
	_peers[peer_id] = st
	log_line("peer_connected", {"peer": peer_id})


func _on_peer_disconnected(peer_id: int) -> void:
	var st: PeerState = _peers.get(peer_id)
	_peers.erase(peer_id)
	log_line("peer_disconnected", {"peer": peer_id})
	if st != null and st.handshaken:
		peer_left.emit(peer_id)


## Conta a mensagem na janela de 1 s; false = descartar (GDD §15.4).
func _accept_message(peer_id: int) -> bool:
	if not is_server:
		return false
	var st: PeerState = _peers.get(peer_id)
	if st == null:
		log_invalid(peer_id, "unknown_peer")
		return false
	var now: int = Time.get_ticks_msec()
	if now - st.rate_window_start_msec >= RATE_WINDOW_MSEC:
		st.rate_window_start_msec = now
		st.rate_count = 0
		st.rate_logged = false
	st.rate_count += 1
	if st.rate_count > Balance.cfg.max_client_msgs_per_sec:
		if not st.rate_logged:
			st.rate_logged = true
			log_invalid(peer_id, "rate_limited", {"limit": Balance.cfg.max_client_msgs_per_sec})
		return false
	return true


## Taxa + handshake + instância montada. Usado por todas as intenções de jogo.
func _accept_world_intent(peer_id: int, intent: String) -> bool:
	if not _accept_message(peer_id):
		return false
	var st: PeerState = _peers[peer_id]
	if not st.handshaken or st.instance_id.is_empty():
		log_invalid(peer_id, "intent_before_ready", {"intent": intent})
		return false
	return true


func _sanitize_name(raw: String, peer_id: int) -> String:
	var clean: String = raw.strip_edges().strip_escapes()
	if clean.length() > MAX_NAME_LENGTH:
		clean = clean.substr(0, MAX_NAME_LENGTH)
	if clean.is_empty():
		clean = "Player%d" % peer_id
	return clean


## Nomes são únicos entre os conectados (o save é por nome).
func _is_name_online(p_name: String) -> bool:
	for st: PeerState in _peers.values():
		if st.handshaken and st.display_name.to_lower() == p_name.to_lower():
			return true
	return false


func _reject_peer(peer_id: int, reason: StringName, detail: String = "") -> void:
	_cli_rejected.rpc_id(peer_id, String(reason) + (REJECT_DETAIL_SEP + detail if not detail.is_empty() else ""))
	_peers.erase(peer_id)
	get_tree().create_timer(REJECT_DISCONNECT_DELAY_SEC).timeout.connect(
			_disconnect_peer_if_connected.bind(peer_id))


@rpc("any_peer", "call_remote", "reliable")
func _srv_hello(protocol_version: Variant, display_name: Variant, body_type: Variant,
		auth_token: Variant = "") -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_message(peer_id):
		return
	var st: PeerState = _peers[peer_id]
	if st.handshaken:
		log_invalid(peer_id, "duplicate_hello")
		return
	if typeof(protocol_version) != TYPE_INT or typeof(display_name) != TYPE_STRING \
			or typeof(body_type) != TYPE_STRING:
		log_invalid(peer_id, "hello_bad_types")
		return
	if int(protocol_version) != Balance.cfg.protocol_version:
		log_line("peer_rejected", {"peer": peer_id, "client_protocol": protocol_version,
				"server_protocol": Balance.cfg.protocol_version})
		_reject_peer(peer_id, REJECT_PROTOCOL_MISMATCH)
		return
	var body := StringName(body_type)
	if body not in BODY_TYPES:
		log_invalid(peer_id, "bad_body_type", {"body": body_type})
		body = DEFAULT_BODY_TYPE
	var clean_name: String = _sanitize_name(display_name, peer_id)
	# Nome ofensivo em qualquer idioma/burla (GDD §13; filtro do Agente S).
	if not _name_filter().is_name_allowed(clean_name):
		log_line("peer_rejected", {"peer": peer_id, "reason": String(REJECT_NAME_OFFENSIVE)})
		_reject_peer(peer_id, REJECT_NAME_OFFENSIVE)
		return
	if _is_name_online(clean_name):
		log_line("peer_rejected", {"peer": peer_id, "reason": String(REJECT_NAME_IN_USE),
				"name": clean_name})
		_reject_peer(peer_id, REJECT_NAME_IN_USE)
		return
	if auth_gate != null:
		var auth: Dictionary = auth_gate.call(&"check", auth_token, clean_name)
		if not StringName(auth["reason"]).is_empty():
			log_line("peer_rejected", {"peer": peer_id, "reason": String(auth["reason"]), "name": clean_name})
			var owned: Array = auth.get("owned", [])
			_reject_peer(peer_id, StringName(auth["reason"]), str(owned[0]) if not owned.is_empty() else "")
			return
		st.account_id = int(auth["account_id"])
	st.handshaken = true
	st.display_name = clean_name
	st.body_type = body
	log_line("peer_handshake_ok", {"peer": peer_id, "name": st.display_name, "body": String(body)})
	peer_joined.emit(peer_id, st.display_name, st.body_type)


var _profanity: ProfanityFilter = null

func _name_filter() -> ProfanityFilter:
	if _profanity == null:
		_profanity = ProfanityFilter.new()
	return _profanity


func _disconnect_peer_if_connected(peer_id: int) -> void:
	if multiplayer.multiplayer_peer != null and peer_id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _srv_instance_ready(instance_id: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_message(peer_id):
		return
	var st: PeerState = _peers[peer_id]
	if not st.handshaken or typeof(instance_id) != TYPE_STRING \
			or StringName(instance_id) != st.pending_instance_id:
		log_invalid(peer_id, "unexpected_instance_ready", {"instance": str(instance_id)})
		return
	peer_instance_ready.emit(peer_id, st.pending_instance_id)


# ---------------------------------------------------------------- intenções (cliente -> servidor)

## GDD §15.4 req_move. Validação de navmesh fica no ServerWorld.
@rpc("any_peer", "call_remote", "reliable")
func req_move(target: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "move"):
		return
	if typeof(target) != TYPE_VECTOR3 or not (target as Vector3).is_finite():
		log_invalid(peer_id, "move_bad_target", {"target": str(target)})
		return
	move_intent.emit(peer_id, target as Vector3)


@rpc("any_peer", "call_remote", "reliable")
func req_interact(target_id: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "interact"):
		return
	if not _is_text(target_id) or String(target_id).length() > MAX_RAW_ID_LENGTH:
		log_invalid(peer_id, "interact_bad_args")
		return
	interact_intent.emit(peer_id, String(target_id))


@rpc("any_peer", "call_remote", "reliable")
func req_dialogue_choice(option_index: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "dialogue_choice"):
		return
	if typeof(option_index) != TYPE_INT:
		log_invalid(peer_id, "dialogue_choice_bad_args")
		return
	dialogue_choice_intent.emit(peer_id, int(option_index))


@rpc("any_peer", "call_remote", "reliable")
func req_dialogue_close() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "dialogue_close"):
		return
	dialogue_close_intent.emit(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func req_inventory_move(from_slot: Variant, to_slot: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "inventory_move"):
		return
	if typeof(from_slot) != TYPE_INT or typeof(to_slot) != TYPE_INT:
		log_invalid(peer_id, "inventory_move_bad_args")
		return
	inventory_move_intent.emit(peer_id, int(from_slot), int(to_slot))


@rpc("any_peer", "call_remote", "reliable")
func req_use_item(slot: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "use_item"):
		return
	if typeof(slot) != TYPE_INT:
		log_invalid(peer_id, "use_item_bad_args")
		return
	use_item_intent.emit(peer_id, int(slot))


@rpc("any_peer", "call_remote", "reliable")
func req_equip(slot: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "equip"):
		return
	if typeof(slot) != TYPE_INT:
		log_invalid(peer_id, "equip_bad_args")
		return
	equip_intent.emit(peer_id, int(slot))


@rpc("any_peer", "call_remote", "reliable")
func req_unequip(equip_slot: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "unequip"):
		return
	if not _is_text(equip_slot) or String(equip_slot).length() > MAX_RAW_ID_LENGTH:
		log_invalid(peer_id, "unequip_bad_args")
		return
	unequip_intent.emit(peer_id, StringName(equip_slot))


@rpc("any_peer", "call_remote", "reliable")
func req_shop_buy(item_id: Variant, qty: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "shop_buy"):
		return
	if not _is_text(item_id) or String(item_id).length() > MAX_RAW_ID_LENGTH \
			or typeof(qty) != TYPE_INT:
		log_invalid(peer_id, "shop_buy_bad_args")
		return
	shop_buy_intent.emit(peer_id, StringName(item_id), int(qty))


@rpc("any_peer", "call_remote", "reliable")
func req_shop_sell(slot: Variant, qty: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "shop_sell"):
		return
	if typeof(slot) != TYPE_INT or typeof(qty) != TYPE_INT:
		log_invalid(peer_id, "shop_sell_bad_args")
		return
	shop_sell_intent.emit(peer_id, int(slot), int(qty))


@rpc("any_peer", "call_remote", "reliable")
func req_shop_close() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "shop_close"):
		return
	shop_close_intent.emit(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func req_chat(channel: Variant, text: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "chat"):
		return
	if not _is_text(channel) or not _is_text(text) \
			or String(channel).length() > MAX_RAW_ID_LENGTH \
			or String(text).length() > MAX_RAW_TEXT_LENGTH:
		log_invalid(peer_id, "chat_bad_args")
		return
	chat_intent.emit(peer_id, StringName(channel), String(text))


@rpc("any_peer", "call_remote", "reliable")
func req_emote(emote_id: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _accept_world_intent(peer_id, "emote"):
		return
	if not _is_text(emote_id) or StringName(emote_id) not in EMOTES:
		log_invalid(peer_id, "emote_bad_args", {"emote": str(emote_id)})
		return
	emote_intent.emit(peer_id, StringName(emote_id))


# ---------------------------------------------------------------- eventos (servidor -> cliente)
# Estado privado (inventário, equipamento, atributos, Estrelas, diálogo, loja, avisos) vai só
# para o peer dono. Chat e emote vão para os peers da mesma instância (lista dada pelo chamador).

func push_inventory(peer_id: int, slots: Array) -> void:
	_cli_inventory.rpc_id(peer_id, slots)


func push_equipment(peer_id: int, equip: Dictionary) -> void:
	_cli_equipment.rpc_id(peer_id, equip)


func push_stats(peer_id: int, stats: Dictionary) -> void:
	_cli_stats.rpc_id(peer_id, stats)


func push_currency(peer_id: int, stars: int) -> void:
	_cli_currency.rpc_id(peer_id, stars)


func push_dialogue_opened(peer_id: int, npc_entity_id: int, speaker_key: String, text_key: String,
		options: Array[String]) -> void:
	_cli_dialogue_opened.rpc_id(peer_id, npc_entity_id, speaker_key, text_key, Array(options))


func push_dialogue_closed(peer_id: int) -> void:
	_cli_dialogue_closed.rpc_id(peer_id)


func push_shop_opened(peer_id: int, shop_id: StringName, items: Array[StringName]) -> void:
	var raw: Array = []
	for i: StringName in items:
		raw.append(String(i))
	_cli_shop_opened.rpc_id(peer_id, String(shop_id), raw)


func push_shop_closed(peer_id: int) -> void:
	_cli_shop_closed.rpc_id(peer_id)


func push_system_message(peer_id: int, key: String, args: Array = []) -> void:
	_cli_system_message.rpc_id(peer_id, key, args)


func push_chat(peer_ids: Array[int], channel: StringName, from_name: String, text: String,
		from_entity_id: int) -> void:
	for p: int in peer_ids:
		_cli_chat.rpc_id(p, String(channel), from_name, text, from_entity_id)


func push_emote(peer_ids: Array[int], entity_id: int, emote_id: StringName) -> void:
	for p: int in peer_ids:
		_cli_emote.rpc_id(p, entity_id, String(emote_id))


# ================================================================ cliente

func start_client(host: String, port: int, display_name: String, body_type: StringName,
		protocol_override: int = -1) -> Error:
	is_server = false
	_rejected = false
	last_rejection = &""
	rejection_detail = ""
	_client_name = display_name
	_client_body = body_type
	_client_protocol = protocol_override if protocol_override >= 0 else Balance.cfg.protocol_version
	var peer: MultiplayerPeer
	var err: Error
	var ws_url: String = websocket_url(host)
	if not ws_url.is_empty():
		var ws := WebSocketMultiplayerPeer.new()
		_tune_ws(ws)
		# ngrok grátis mostra um aviso a navegadores; o cabeçalho pula o aviso.
		ws.handshake_headers = PackedStringArray(["ngrok-skip-browser-warning: 1"])
		err = ws.create_client(ws_url, TLSOptions.client() if ws_url.begins_with("wss://") else null)
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		err = enet.create_client(host, port)
		peer = enet
	if err != OK:
		log_line("client_start_failed", {"host": host, "port": port, "error": err})
		status_changed.emit(tr(KEY_CONNECTION_FAILED))
		connection_closed.emit(KEY_CONNECTION_FAILED)
		return err
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	log_line("client_connecting", {"host": host, "port": port})
	status_changed.emit(tr(KEY_CONNECTING))
	return OK


func _is_client_connected() -> bool:
	return not is_server and multiplayer.multiplayer_peer != null \
			and multiplayer.multiplayer_peer.get_connection_status() \
			== MultiplayerPeer.CONNECTION_CONNECTED


## Intenção de movimento (ligado ao ClientView.move_requested).
func send_move_request(target: Vector3) -> void:
	if _is_client_connected():
		req_move.rpc_id(SERVER_PEER_ID, target)


## target_id: "e:<entity_id>" (entidade) ou "m:<interact_id>" (objeto do mapa).
func send_interact(target_id: String) -> void:
	if _is_client_connected():
		req_interact.rpc_id(SERVER_PEER_ID, target_id)


## Índice na lista de opções recebida em dialogue_opened.
func send_dialogue_choice(option_index: int) -> void:
	if _is_client_connected():
		req_dialogue_choice.rpc_id(SERVER_PEER_ID, option_index)


func send_dialogue_close() -> void:
	if _is_client_connected():
		req_dialogue_close.rpc_id(SERVER_PEER_ID)


func send_inventory_move(from_slot: int, to_slot: int) -> void:
	if _is_client_connected():
		req_inventory_move.rpc_id(SERVER_PEER_ID, from_slot, to_slot)


func send_use_item(slot: int) -> void:
	if _is_client_connected():
		req_use_item.rpc_id(SERVER_PEER_ID, slot)


## Equipa o item do espaço do inventário (o servidor escolhe o espaço de equipamento).
func send_equip(slot: int) -> void:
	if _is_client_connected():
		req_equip.rpc_id(SERVER_PEER_ID, slot)


func send_unequip(equip_slot: StringName) -> void:
	if _is_client_connected():
		req_unequip.rpc_id(SERVER_PEER_ID, String(equip_slot))


func send_shop_buy(item_id: StringName, qty: int) -> void:
	if _is_client_connected():
		req_shop_buy.rpc_id(SERVER_PEER_ID, String(item_id), qty)


func send_shop_sell(slot: int, qty: int) -> void:
	if _is_client_connected():
		req_shop_sell.rpc_id(SERVER_PEER_ID, slot, qty)


## Extra (fora da tabela do contrato): fechar a janela da loja avisa o servidor, que libera o NPC.
## O servidor também fecha sozinho se o jogador se afastar.
func send_shop_close() -> void:
	if _is_client_connected():
		req_shop_close.rpc_id(SERVER_PEER_ID)


func send_chat(channel: StringName, text: String) -> void:
	if _is_client_connected():
		req_chat.rpc_id(SERVER_PEER_ID, String(channel), text)


func send_emote(emote_id: StringName) -> void:
	if _is_client_connected():
		req_emote.rpc_id(SERVER_PEER_ID, String(emote_id))


## Cliente: avisa que a subárvore da instância está montada.
func notify_instance_ready(instance_id: StringName) -> void:
	_srv_instance_ready.rpc_id(SERVER_PEER_ID, String(instance_id))


func _on_connected_to_server() -> void:
	log_line("connected", {"peer": multiplayer.get_unique_id()})
	status_changed.emit("")
	_srv_hello.rpc_id(SERVER_PEER_ID, _client_protocol, _client_name, String(_client_body), client_auth_token)


func _on_connection_failed() -> void:
	log_line("connection_failed")
	status_changed.emit(tr(KEY_CONNECTION_FAILED))
	connection_closed.emit(KEY_CONNECTION_FAILED)


func _on_server_disconnected() -> void:
	log_line("server_disconnected")
	if not _rejected:
		status_changed.emit(tr(KEY_DISCONNECTED))
		connection_closed.emit(KEY_DISCONNECTED)


@rpc("authority", "call_remote", "reliable")
func _cli_rejected(raw_reason: String) -> void:
	_rejected = true
	var reason: String = raw_reason.get_slice(REJECT_DETAIL_SEP, 0)
	rejection_detail = raw_reason.get_slice(REJECT_DETAIL_SEP, 1) if raw_reason.contains(REJECT_DETAIL_SEP) else ""
	last_rejection = StringName(reason)
	var info: Dictionary = {"reason": reason}
	if not rejection_detail.is_empty():
		info["detail"] = rejection_detail
	log_line("rejected", info)
	var key: String = KEY_DISCONNECTED
	match StringName(reason):
		REJECT_PROTOCOL_MISMATCH:
			key = KEY_UPDATE_REQUIRED
		REJECT_NAME_IN_USE:
			key = KEY_NAME_IN_USE
		REJECT_NAME_OFFENSIVE:
			key = KEY_NAME_OFFENSIVE
		REJECT_AUTH_REQUIRED:
			key = KEY_AUTH_REQUIRED
		REJECT_AUTH_INVALID, REJECT_AUTH_EXPIRED:
			key = KEY_AUTH_INVALID
		REJECT_NAME_OWNED:
			key = KEY_NAME_OWNED
		REJECT_SLOT_FULL:
			key = KEY_SLOT_FULL
	status_changed.emit(tr(key))
	connection_closed.emit(key)


@rpc("authority", "call_remote", "reliable")
func _cli_enter_instance(instance_id: String, map_id: String) -> void:
	log_line("enter_instance", {"instance": instance_id, "map": map_id})
	enter_instance_requested.emit(StringName(instance_id), StringName(map_id))


@rpc("authority", "call_remote", "reliable")
func _cli_inventory(slots: Array) -> void:
	var out: Array = []
	for s: Variant in slots:
		if typeof(s) == TYPE_DICTIONARY and not (s as Dictionary).is_empty():
			out.append({"item": StringName(str(s.get("item", ""))), "qty": int(s.get("qty", 0))})
		else:
			out.append({})
	client_inventory = out
	inventory_changed.emit(out)


@rpc("authority", "call_remote", "reliable")
func _cli_equipment(equip: Dictionary) -> void:
	var out: Dictionary = {}
	for k: Variant in equip:
		out[StringName(str(k))] = StringName(str(equip[k]))
	client_equipment = out
	equipment_changed.emit(out)


@rpc("authority", "call_remote", "reliable")
func _cli_stats(stats: Dictionary) -> void:
	var out: Dictionary = {}
	for k: Variant in stats:
		out[StringName(str(k))] = int(stats[k])
	client_stats = out
	stats_changed.emit(out)


@rpc("authority", "call_remote", "reliable")
func _cli_currency(stars: int) -> void:
	client_stars = stars
	currency_changed.emit(stars)


@rpc("authority", "call_remote", "reliable")
func _cli_dialogue_opened(npc_entity_id: int, speaker_key: String, text_key: String,
		options: Array) -> void:
	var opts: Array[String] = []
	for o: Variant in options:
		opts.append(str(o))
	client_dialogue_npc_id = npc_entity_id
	dialogue_opened.emit(npc_entity_id, speaker_key, text_key, opts)


@rpc("authority", "call_remote", "reliable")
func _cli_dialogue_closed() -> void:
	client_dialogue_npc_id = 0
	dialogue_closed.emit()


@rpc("authority", "call_remote", "reliable")
func _cli_shop_opened(shop_id: String, items: Array) -> void:
	var list: Array[StringName] = []
	for i: Variant in items:
		list.append(StringName(str(i)))
	client_shop_id = StringName(shop_id)
	shop_opened.emit(client_shop_id, list)


@rpc("authority", "call_remote", "reliable")
func _cli_shop_closed() -> void:
	client_shop_id = &""
	shop_closed.emit()


@rpc("authority", "call_remote", "reliable")
func _cli_system_message(key: String, args: Array) -> void:
	system_message.emit(key, args)


@rpc("authority", "call_remote", "reliable")
func _cli_chat(channel: String, from_name: String, text: String, from_entity_id: int) -> void:
	chat_received.emit(StringName(channel), from_name, text, from_entity_id)


@rpc("authority", "call_remote", "reliable")
func _cli_emote(entity_id: int, emote_id: String) -> void:
	emote_received.emit(entity_id, StringName(emote_id))
