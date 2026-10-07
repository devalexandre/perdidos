extends Node
## RPCs da fase 1: comandos privados, efeitos apenas para quem vê o dono.
signal command_intent(peer_id: int, command: StringName, id: StringName, text: String)
signal companion_strike(owner_id: int, target_id: int, companion_id: StringName)
signal revealed(entity_ids: Array, duration_sec: float, gathering: bool)

func send_command(command: StringName, id: StringName = &"", text: String = "") -> void:
	if not Net.is_server and multiplayer.has_multiplayer_peer() \
			and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		req_command.rpc_id(Net.SERVER_PEER_ID, String(command), String(id), text)

@rpc("any_peer", "call_remote", "reliable")
func req_command(command: Variant, id: Variant, text: Variant) -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	if not Net._accept_world_intent(peer, "followers"):
		return
	if not command is String or command not in ["mount", "dismount", "companion", "name"] \
			or not id is String or id.length() > 80 or not text is String or text.length() > 48:
		Net.log_invalid(peer, "followers_bad_args")
		return
	command_intent.emit(peer, StringName(command), StringName(id), text)

func push_strike(peers: Array[int], owner: int, target: int, companion: StringName) -> void:
	for peer: int in peers:
		_cli_strike.rpc_id(peer, owner, target, String(companion))

func push_reveal(peer: int, ids: Array, duration: float, gathering: bool = false) -> void:
	_cli_reveal.rpc_id(peer, ids, duration, gathering)

@rpc("authority", "call_remote", "reliable")
func _cli_strike(owner: int, target: int, companion: String) -> void:
	companion_strike.emit(owner, target, StringName(companion))

@rpc("authority", "call_remote", "reliable")
func _cli_reveal(ids: Array, duration: float, gathering: bool) -> void:
	revealed.emit(ids, duration, gathering)

