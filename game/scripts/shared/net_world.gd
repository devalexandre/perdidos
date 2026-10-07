extends Node
## Autoload "NetWorld": canal de RPCs do marco "Chegada do Viajante" (docs/contracts-arrival.md).
## Mesmo caminho (/root/NetWorld) no servidor e no cliente. Validação e limite de taxa via Net.
## Dono: Agente N (fluxo e navegação).
##
## Cliente -> servidor:
##   send_appearance(dict)  personalização escolhida na criação (ADENDO 2). Mandada logo depois de
##                          conectar (antes do servidor criar o personagem); o servidor valida contra
##                          data/customization/options.tres e só usa num personagem NOVO.
##   send_debug(cmd, args)  só em teste: o servidor ignora se não estiver com --world-debug.
## Servidor -> cliente:
##   zone_changed(map_id)   o jogador entrou num mapa (depois do enter_instance); a UI usa para o
##                          minimapa e para o aviso do nome da zona.

## Servidor: aparência recebida de um peer (antes do personagem existir).
signal appearance_received(peer_id: int, appearance: Dictionary)
## Servidor: comando de teste (só com --world-debug).
signal debug_intent(peer_id: int, cmd: StringName, args: Array)
## Cliente: o servidor confirmou o mapa atual.
signal zone_changed(map_id: StringName)

## Chaves aceitas em send_appearance (ADENDO 2) e limites brutos antes da validação de P.
const APPEARANCE_KEYS: Array[StringName] = [&"body", &"skin", &"hair_style", &"hair_color",
		&"eye_color", &"earrings", &"nationality"]
const MAX_APPEARANCE_KEYS: int = 16
const MAX_DEBUG_ARGS: int = 8

## Cliente: aparência a mandar ao conectar (definida pelo main.gd a partir da tela de título).
var client_appearance: Dictionary = {}
## Cliente: mapa atual (último zone_changed / enter_instance).
var client_map_id: StringName = &""
## Cliente: jogador local (para o "você está aqui" do atlas do mundo, Agente G).
var client_player: Node3D = null
## Servidor: aceita comandos de teste (definido pelo MapTransfer com --world-debug).
var debug_enabled: bool = false


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	Net.enter_instance_requested.connect(_on_enter_instance_requested)
	Net.local_player_spawned.connect(func(p: Node3D) -> void: client_player = p)


## Cliente: onde o jogador está agora — {"map_id": StringName, "position": Vector3 (mundo)}. Para o
## atlas do mundo (Agente G) marcar "você está aqui"; escute zone_changed para saber quando muda.
func where_am_i() -> Dictionary:
	var pos: Vector3 = client_player.global_position \
			if client_player != null and is_instance_valid(client_player) and client_player.is_inside_tree() \
			else Vector3.ZERO
	return {&"map_id": client_map_id, &"position": pos}


# ---------------------------------------------------------------- cliente

func _is_client_connected() -> bool:
	return not Net.is_server and multiplayer.multiplayer_peer != null \
			and multiplayer.multiplayer_peer.get_connection_status() \
			== MultiplayerPeer.CONNECTION_CONNECTED


func _on_connected_to_server() -> void:
	# O Net manda o hello no mesmo sinal (autoload anterior): a aparência chega logo depois dele,
	# bem antes do _srv_instance_ready que cria o personagem.
	if not client_appearance.is_empty():
		send_appearance(client_appearance)


func send_appearance(appearance: Dictionary) -> void:
	if _is_client_connected():
		var raw: Dictionary = {}
		for k: Variant in appearance:
			var v: Variant = appearance[k]
			raw[str(k)] = String(v) if v is StringName else v
		_srv_appearance.rpc_id(Net.SERVER_PEER_ID, raw)


func send_debug(cmd: StringName, args: Array = []) -> void:
	if _is_client_connected():
		_srv_debug.rpc_id(Net.SERVER_PEER_ID, String(cmd), args)


func _on_enter_instance_requested(_instance_id: StringName, map_id: StringName) -> void:
	client_map_id = map_id


@rpc("authority", "call_remote", "reliable")
func _cli_zone_changed(map_id: String) -> void:
	client_map_id = StringName(map_id)
	Net.log_line("zone_changed", {"map": map_id})
	zone_changed.emit(client_map_id)


# ---------------------------------------------------------------- servidor

func push_zone_changed(peer_id: int, map_id: StringName) -> void:
	_cli_zone_changed.rpc_id(peer_id, String(map_id))


@rpc("any_peer", "call_remote", "reliable")
func _srv_appearance(appearance: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not Net._accept_message(peer_id):
		return
	if typeof(appearance) != TYPE_DICTIONARY or (appearance as Dictionary).size() > MAX_APPEARANCE_KEYS:
		Net.log_invalid(peer_id, "appearance_bad_args")
		return
	var clean: Dictionary = {}
	for k: Variant in appearance:
		var key := StringName(str(k))
		var v: Variant = (appearance as Dictionary)[k]
		if key not in APPEARANCE_KEYS:
			continue
		if v is String and (v as String).length() <= Net.MAX_RAW_ID_LENGTH:
			clean[key] = StringName(v)
		elif v is int or v is float:
			clean[key] = v
	appearance_received.emit(peer_id, clean)


@rpc("any_peer", "call_remote", "reliable")
func _srv_debug(cmd: Variant, args: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not Net._accept_world_intent(peer_id, "world_debug"):
		return
	if not debug_enabled:
		Net.log_invalid(peer_id, "debug_disabled")
		return
	if not Net._is_text(cmd) or typeof(args) != TYPE_ARRAY or (args as Array).size() > MAX_DEBUG_ARGS:
		Net.log_invalid(peer_id, "debug_bad_args")
		return
	debug_intent.emit(peer_id, StringName(cmd), args as Array)
