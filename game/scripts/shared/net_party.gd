extends Node
## Autoload "NetParty": grupo (GDD §5.2–5.4, decisão do dono em 30/09/2026), lista /online e o menu de
## jogador do cliente. Mesmo caminho (/root/NetParty) no servidor e no cliente. Validação de taxa e de
## "está no mundo" pelo Net; as regras (limites, líder, spam de convite) ficam no PartyService do servidor.
##
## Cliente -> servidor:
##   send_command(cmd, arg)   cmd em COMMANDS: invite <nome>, accept, decline, leave, kick <nome>,
##                            leader <nome>, list, online. O chat ("/grupo ...", "/online") chega ao mesmo
##                            PartyService pelo ChatService.
## Servidor -> cliente (só para o peer certo):
##   party_changed(state)                 estado do grupo ({} = sem grupo). Ver PartyService.state_for().
##   invite_received(from_name, sec)      convite pendente (janela Aceitar/Recusar).
##   invite_closed()                      o convite pendente acabou (aceito, recusado, expirado, cancelado).
##   player_list_received(kind, entries)  kind &"online" ou &"party"; entries [{name, level, map, leader?, online?}].
## Só no cliente:
##   player_menu_requested(entity_id, name)  clique (esquerdo ou direito) em outro jogador: abre o menu
##                                            "Convidar para o grupo" (GameUI).

## Servidor: comando validado quanto a formato e taxa (as regras ficam com o PartyService).
signal command_intent(peer_id: int, cmd: StringName, arg: String)
## Cliente.
signal party_changed(state: Dictionary)
signal invite_received(from_name: String, timeout_sec: float)
signal invite_closed()
signal player_list_received(kind: StringName, entries: Array)
signal player_menu_requested(entity_id: int, player_name: String)

const CMD_INVITE: StringName = &"invite"
const CMD_ACCEPT: StringName = &"accept"
const CMD_DECLINE: StringName = &"decline"
const CMD_LEAVE: StringName = &"leave"
const CMD_KICK: StringName = &"kick"
const CMD_LEADER: StringName = &"leader"
const CMD_XP_MODE: StringName = &"xp_mode"
const CMD_LIST: StringName = &"list"
const CMD_ONLINE: StringName = &"online"
const COMMANDS: Array[StringName] = [CMD_INVITE, CMD_ACCEPT, CMD_DECLINE, CMD_LEAVE, CMD_KICK,
		CMD_LEADER, CMD_XP_MODE, CMD_LIST, CMD_ONLINE]
const LIST_ONLINE: StringName = &"online"
const LIST_PARTY: StringName = &"party"
## Tamanho bruto máximo do argumento (nome) antes das regras.
const MAX_ARG_LENGTH: int = 64
## Chaves do estado (servidor e cliente).
const K_LEADER: String = "leader"
const K_MEMBERS: String = "members"
const K_MAX: String = "max"
const K_NAME: String = "name"
const K_LEVEL: String = "level"
const K_HP: String = "hp"
const K_MAX_HP: String = "max_hp"
const K_MP: String = "mp"
const K_MAX_MP: String = "max_mp"
const K_MAP: String = "map"
const K_ONLINE: String = "online"
const K_IS_LEADER: String = "is_leader"
const K_ENTITY: String = "entity_id"
const K_XP_MODE: String = "xp_mode"

## Cliente: último estado recebido ({} = sem grupo) e quem mandou o convite pendente ("" = nenhum).
var client_party: Dictionary = {}
var client_invite_from: String = ""


# ---------------------------------------------------------------- cliente

func _is_client_connected() -> bool:
	return not Net.is_server and multiplayer.multiplayer_peer != null \
			and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
			and multiplayer.multiplayer_peer.get_connection_status() \
			== MultiplayerPeer.CONNECTION_CONNECTED


func send_command(cmd: StringName, arg: String = "") -> void:
	if _is_client_connected():
		_srv_command.rpc_id(Net.SERVER_PEER_ID, String(cmd), arg)


func send_invite(player_name: String) -> void:
	send_command(CMD_INVITE, player_name)


func send_accept() -> void:
	send_command(CMD_ACCEPT)


func send_decline() -> void:
	send_command(CMD_DECLINE)


func send_leave() -> void:
	send_command(CMD_LEAVE)


func send_kick(player_name: String) -> void:
	send_command(CMD_KICK, player_name)


func send_make_leader(player_name: String) -> void:
	send_command(CMD_LEADER, player_name)


func send_xp_mode(mode: StringName) -> void:
	send_command(CMD_XP_MODE, String(mode))


func in_party() -> bool:
	return not client_party.is_empty()


## O nome está no grupo do jogador local (sem diferenciar maiúsculas)?
func is_member(player_name: String) -> bool:
	for m: Variant in client_party.get(K_MEMBERS, []):
		if str((m as Dictionary).get(K_NAME, "")).to_lower() == player_name.to_lower():
			return true
	return false


func leader_name() -> String:
	return str(client_party.get(K_LEADER, ""))


## O jogador local é o líder?
func is_local_leader(local_name: String) -> bool:
	return in_party() and leader_name().to_lower() == local_name.to_lower()


@rpc("authority", "call_remote", "reliable")
func _cli_party_state(state: Dictionary) -> void:
	var before: Array = _member_names(client_party)
	var leader_before: String = leader_name()
	client_party = state
	if before != _member_names(state) or leader_before != leader_name():
		Net.log_line("party_state", {"leader": leader_name(), "members": _member_names(state)})
	party_changed.emit(state)


static func _member_names(state: Dictionary) -> Array:
	return (state.get(K_MEMBERS, []) as Array).map(func(m: Dictionary) -> String: return str(m.get(K_NAME, "")))


@rpc("authority", "call_remote", "reliable")
func _cli_invite(from_name: String, timeout_sec: float) -> void:
	client_invite_from = from_name
	Net.log_line("party_invite_received", {"from": from_name})
	invite_received.emit(from_name, timeout_sec)


@rpc("authority", "call_remote", "reliable")
func _cli_invite_closed() -> void:
	client_invite_from = ""
	invite_closed.emit()


@rpc("authority", "call_remote", "reliable")
func _cli_player_list(kind: String, entries: Array) -> void:
	Net.log_line("player_list", {"kind": kind, "count": entries.size()})
	player_list_received.emit(StringName(kind), entries)


# ---------------------------------------------------------------- servidor

func push_state(peer_id: int, state: Dictionary) -> void:
	_cli_party_state.rpc_id(peer_id, state)


func push_invite(peer_id: int, from_name: String, timeout_sec: float) -> void:
	_cli_invite.rpc_id(peer_id, from_name, timeout_sec)


func push_invite_closed(peer_id: int) -> void:
	_cli_invite_closed.rpc_id(peer_id)


func push_player_list(peer_id: int, kind: StringName, entries: Array) -> void:
	_cli_player_list.rpc_id(peer_id, String(kind), entries)


@rpc("any_peer", "call_remote", "reliable")
func _srv_command(cmd: Variant, arg: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not Net._accept_world_intent(peer_id, "party"):
		return
	if not Net._is_text(cmd) or not Net._is_text(arg) or String(arg).length() > MAX_ARG_LENGTH \
			or StringName(cmd) not in COMMANDS:
		Net.log_invalid(peer_id, "party_bad_args", {"cmd": str(cmd).left(MAX_ARG_LENGTH)})
		return
	command_intent.emit(peer_id, StringName(cmd), String(arg).strip_escapes().strip_edges())
