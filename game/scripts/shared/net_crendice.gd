extends Node
## Autoload "NetCrendice": canal de RPCs do Sistema de Crendices (GDD §11).
## Permite engastar amuletos folclóricos em equipamentos, removê-los e
## reconsagrá-los em Altares de Crendice.

signal insert_intent(peer_id: int, equip_slot: StringName, inv_slot: int, socket_idx: int)
signal remove_intent(peer_id: int, equip_slot: StringName, socket_idx: int)
signal consecrate_intent(peer_id: int, equip_slot: StringName, socket_idx: int)

# Sinais no cliente
signal altar_opened
signal altar_closed
signal crendice_result(ok: bool, message: String)

const SERVER_PEER_ID: int = 1


func _is_client_connected() -> bool:
	return not Net.is_server and multiplayer.multiplayer_peer != null \
			and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
			and multiplayer.multiplayer_peer.get_connection_status() \
			== MultiplayerPeer.CONNECTION_CONNECTED


# ================================================================ cliente -> servidor

func send_insert(equip_slot: StringName, inv_slot: int, socket_idx: int = -1) -> void:
	if _is_client_connected():
		req_insert.rpc_id(SERVER_PEER_ID, String(equip_slot), inv_slot, socket_idx)


func send_remove(equip_slot: StringName, socket_idx: int) -> void:
	if _is_client_connected():
		req_remove.rpc_id(SERVER_PEER_ID, String(equip_slot), socket_idx)


func send_consecrate(equip_slot: StringName, socket_idx: int) -> void:
	if _is_client_connected():
		req_consecrate.rpc_id(SERVER_PEER_ID, String(equip_slot), socket_idx)


# ================================================================ servidor (RPCs)

@rpc("any_peer", "call_remote", "reliable")
func req_insert(equip_slot_str: String, inv_slot: int, socket_idx: int) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	insert_intent.emit(peer_id, StringName(equip_slot_str), inv_slot, socket_idx)


@rpc("any_peer", "call_remote", "reliable")
func req_remove(equip_slot_str: String, socket_idx: int) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	remove_intent.emit(peer_id, StringName(equip_slot_str), socket_idx)


@rpc("any_peer", "call_remote", "reliable")
func req_consecrate(equip_slot_str: String, socket_idx: int) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	consecrate_intent.emit(peer_id, StringName(equip_slot_str), socket_idx)


# ================================================================ servidor -> cliente

func push_open_altar(peer_id: int) -> void:
	_cli_open_altar.rpc_id(peer_id)


func push_result(peer_id: int, ok: bool, message: String) -> void:
	_cli_result.rpc_id(peer_id, ok, message)


@rpc("authority", "call_remote", "reliable")
func _cli_open_altar() -> void:
	altar_opened.emit()


@rpc("authority", "call_remote", "reliable")
func _cli_result(ok: bool, message: String) -> void:
	crendice_result.emit(ok, message)
