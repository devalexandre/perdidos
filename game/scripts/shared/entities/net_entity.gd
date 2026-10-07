class_name NetEntity
extends Node3D
## Base de toda entidade replicada (contrato city-walk, "Entidades"). Generaliza o PlayerEntity da
## Fase 1. Criada pelo servidor (scenes/entities/net_entity.tscn), nome do nó = str(entity_id),
## replicada pelo MultiplayerSpawner da instância com filtro de visibilidade por instance_id (GDD §5.6).
##
## Servidor: componentes filhos (GridMover, NpcBrain...) decidem o estado; o ServerWorld chama
## server_tick(). Movimento (GDD §10.1): o servidor replica o CAMINHO com horário (move_state, ver
## MovePath) e cada cliente calcula a posição no relógio do servidor (NetClock), sem atraso de
## interpolação. O jogador local mantém o relógio sincronizado com pings (_clock_*).
## Cliente: cria o visual com EntityVisualFactory.create(self) (de B), repassando facing_yaw/anim a
## cada quadro e show_emote/show_chat quando chegam os eventos.

const KIND_PLAYER: StringName = &"player"
const KIND_NPC: StringName = &"npc"
## Contrato arrival (K): monstro (def_id = id do MonsterDef) e item no chão (def_id = id do ItemDef).
const KIND_MONSTER: StringName = &"monster"
const KIND_DROP: StringName = &"drop"
const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_SIT: StringName = &"sit"
## entity_id dos NPCs = NPC_ID_BASE + n (jogador = peer_id).
const NPC_ID_BASE: int = 1000000
const VISUAL_NODE_NAME: String = "Visual"
const SYNC_NODE_NAME: String = "Sync"
## Classe de B que cria o visual; procurada pelo nome global para não quebrar se ainda não existir.
const VISUAL_FACTORY_CLASS: StringName = &"EntityVisualFactory"
const VISUAL_FACTORY_METHOD: StringName = &"create"
## Fallback da Fase 1 (só jogador) se a fábrica de B não existir.
const FALLBACK_VISUAL_SCRIPT: String = "res://scripts/client/directional_sprite_3d.gd"
## GDD §10.1: um ciclo completo da animação de andar a cada 2 células.
const WALK_CYCLE_CELLS: float = 2.0
## Propriedade do visual que recebe a duração (ms) do ciclo de andar (DirectionalSprite3D).
const VISUAL_WALK_CYCLE_PROP: StringName = &"walk_cycle_ms"
## Servidor: intervalo mínimo entre pings de relógio atendidos por entidade (anti-abuso).
const CLOCK_PING_MIN_INTERVAL_MSEC: float = 50.0

## Cliente: o caminho replicado mudou (novo pedido aceito, parada, teleporte).
signal path_changed

# --- propriedades replicadas (ver net_entity.tscn / SceneReplicationConfig)
var entity_id: int = 0
var kind: StringName = KIND_PLAYER
## Jogador = nome; NPC = chave de tradução no servidor, traduzida (tr) no cliente em _ready.
var display_name: String = ""
## Jogador = body_type (&"male"/&"female"); NPC = id do NpcDef.
var def_id: StringName = &""
var instance_id: StringName = &""
## ADENDO 1: aparência visível a todos da instância. Jogador: {body, outfit, head, weapon, offhand}
## -> visual_id (ou &""), outfit padrão &"traveler" (ver Equipment.get_appearance). NPC: {}.
## Sempre atribuir um dicionário novo (a replicação detecta a troca). No cliente, repassa para
## visual.set_appearance(appearance).
var appearance: Dictionary = {}:
	set = _set_appearance
## Yaw no plano XZ, radianos; 0 = olhando para -Z (mesma convenção de rotation.y do Godot).
var facing_yaw: float = 0.0
var anim: StringName = ANIM_IDLE
## Posição autoritativa no servidor (recalculada a cada tick pelo GridMover). Replicada só no
## spawn; no cliente é a posição calculada do caminho a cada quadro (a mesma que aparece na tela).
var net_position: Vector3 = Vector3.ZERO
## Caminho com horário (MovePath.to_state()): [start_msec, ms_per_cell, points, times]. Sempre
## atribuir um Array novo (a replicação "on change" detecta a troca).
var move_state: Array = []:
	set = _set_move_state
# --- combate (contrato arrival, K): replicados só quando mudam
## Estágio de evolução do monstro (1–3; 0 = não é monstro). GDD §10.6.
var stage: int = 0
## Vida atual / máxima (0–1). Jogador e monstro. 0 = morto.
var hp_ratio: float = 1.0
## entity_id do alvo que está atacando (0 = nenhum).
var target_id: int = 0
## Nível (monstro: do estágio; jogador: do personagem).
var level: int = 0
## Agente Q: título exibido sob o nome (TitleDef.id; &"" = nenhum). GDD §8.5.
var title_id: StringName = &"":
	set = _set_title_id

# --- cliente
var _visual: Node3D = null
var _client_path: MovePath = null
var _last_walk_cycle_ms: float = -1.0
# --- servidor
var _last_clock_ping_msec: float = -INF


func is_player() -> bool:
	return kind == KIND_PLAYER


func is_npc() -> bool:
	return kind == KIND_NPC


func is_monster() -> bool:
	return kind == KIND_MONSTER


func is_drop() -> bool:
	return kind == KIND_DROP


func is_dead() -> bool:
	return hp_ratio <= 0.0



## peer_id do jogador (0 para NPC).
func get_peer_id() -> int:
	return entity_id if is_player() else 0


func is_local_player() -> bool:
	return is_player() and not Net.is_server and multiplayer.has_multiplayer_peer() \
			and entity_id == multiplayer.get_unique_id()


func get_sync() -> MultiplayerSynchronizer:
	return get_node(SYNC_NODE_NAME) as MultiplayerSynchronizer


## Componente GridMover (só no servidor; null no cliente).
func get_mover() -> GridMover:
	return get_node_or_null(GridMover.NODE_NAME) as GridMover


## Caminho atual como o cliente o reproduz (null antes do primeiro estado).
func get_client_path() -> MovePath:
	return _client_path


## "e:<entity_id>" — o target_id desta entidade para interação.
func get_target_id() -> String:
	return "e:%d" % entity_id


func get_visual() -> Node3D:
	return _visual


func _ready() -> void:
	position = net_position
	if Net.is_server:
		return
	if is_npc():
		var def: NpcDef = Content.npc(def_id)
		if def != null and not def.name_key.is_empty():
			display_name = tr(def.name_key)
	_create_visual()
	_update_from_path()
	Net.emote_received.connect(_on_emote_received)
	Net.chat_received.connect(_on_chat_received)
	if is_local_player():
		NetClock.reset()
		Net.local_player_spawned.emit(self)


# ---------------------------------------------------------------- servidor

## Chamado pelo servidor ANTES de add_child: dados iniciais e filtro de visibilidade por instância.
func server_setup(p_entity_id: int, p_kind: StringName, p_name: String, p_def_id: StringName,
		p_instance: StringName, p_position: Vector3) -> void:
	entity_id = p_entity_id
	name = str(p_entity_id)
	kind = p_kind
	display_name = p_name
	def_id = p_def_id
	instance_id = p_instance
	net_position = p_position
	position = p_position
	move_state = MovePath.standing(p_position, NetClock.server_now_msec_int()).to_state()
	var sync: MultiplayerSynchronizer = get_sync()
	sync.replication_interval = 1.0 / float(Balance.cfg.server_tick_hz)
	sync.delta_interval = sync.replication_interval
	# GDD §5.6: public_visibility = false + filtro por instance_id. No Godot 4 o filtro é combinado
	# (E lógico) com a lista explícita de peers: o ServerWorld libera cada peer que entrou no mundo
	# (set_visibility_for) e o filtro abaixo restringe à mesma instância.
	sync.public_visibility = false
	sync.visibility_update_mode = MultiplayerSynchronizer.VISIBILITY_PROCESS_NONE
	sync.add_visibility_filter(_is_visible_to_peer)


## Servidor: cria (se preciso) e devolve o GridMover desta entidade.
func server_ensure_mover(grid: WalkGrid, ms_per_cell: int) -> GridMover:
	var mover: GridMover = get_mover()
	if mover == null:
		mover = GridMover.new()
		mover.name = GridMover.NODE_NAME
		add_child(mover)
		mover.ms_per_cell = ms_per_cell
		mover.place(net_position)
	mover.grid = grid
	mover.ms_per_cell = ms_per_cell
	return mover


func server_set_peer_allowed(p_peer: int, allowed: bool) -> void:
	get_sync().set_visibility_for(p_peer, allowed)


## GDD §5.6: só peers na mesma instância recebem esta entidade (spawn e estado).
func _is_visible_to_peer(p_peer: int) -> bool:
	return not instance_id.is_empty() and Net.get_peer_instance(p_peer) == instance_id


## Um tick do servidor (Balance.cfg.server_tick_hz).
func server_tick(_delta: float) -> void:
	var mover: GridMover = get_mover()
	if mover != null:
		mover.tick()


## Servidor: vira para um ponto (plano XZ).
func face_towards(point: Vector3) -> void:
	var d := Vector3(point.x - net_position.x, 0.0, point.z - net_position.z)
	if d.length() > MovePath.MIN_FACING_STEP:
		facing_yaw = atan2(-d.x, -d.z)


## Distância no plano XZ (alcance de interação ignora a altura).
func flat_distance_to(point: Vector3) -> float:
	return Vector2(net_position.x - point.x, net_position.z - point.z).length()


# ---------------------------------------------------------------- cliente

## Agente Q: placa do título sob o nome (NetProgress.apply_title_plate).
func _set_title_id(value: StringName) -> void:
	title_id = value
	if not Net.is_server and _visual != null:
		NetProgress.apply_title_plate(self, value)


func _create_visual() -> void:
	var v: Node3D = _create_visual_from_factory()
	if v == null:
		v = _create_fallback_visual()
	if v == null:
		return
	v.name = VISUAL_NODE_NAME
	if v.get_parent() == null:
		add_child(v)
	_visual = v
	_apply_visual(facing_yaw, anim)
	_set_title_id(title_id)


func _create_visual_from_factory() -> Node3D:
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(info.get("class", "")) != VISUAL_FACTORY_CLASS:
			continue
		var script: Script = load(String(info.get("path", ""))) as Script
		if script == null:
			return null
		return script.call(VISUAL_FACTORY_METHOD, self) as Node3D
	return null


func _create_fallback_visual() -> Node3D:
	if not is_player() or not ResourceLoader.exists(FALLBACK_VISUAL_SCRIPT):
		return null
	var script: Script = load(FALLBACK_VISUAL_SCRIPT)
	if script == null or not script.can_instantiate():
		return null
	var v: Node3D = script.new() as Node3D
	if v != null and v.has_method("setup"):
		v.call("setup", def_id)
	return v


func _apply_visual(yaw: float, anim_name: StringName) -> void:
	if _visual == null:
		return
	_visual.set("facing_yaw", yaw)
	_visual.set("anim", anim_name)


func _set_appearance(value: Dictionary) -> void:
	appearance = value
	# Só jogadores usam paper doll. NPCs mantêm as folhas de NpcDef;
	# monstros leem suas variantes em CombatVisuals.
	if Net.is_server or _visual == null or not is_player():
		return
	if _visual.has_method("set_appearance"):
		_visual.call("set_appearance", value)


func _on_emote_received(p_entity_id: int, emote_id: StringName) -> void:
	if p_entity_id == entity_id and _visual != null and _visual.has_method("show_emote"):
		_visual.call("show_emote", emote_id)


func _on_chat_received(_channel: StringName, _from_name: String, text: String,
		from_entity_id: int) -> void:
	if from_entity_id == entity_id and _visual != null and _visual.has_method("show_chat"):
		_visual.call("show_chat", text)


func _set_move_state(value: Array) -> void:
	move_state = value
	if Net.is_server:
		return
	var p: MovePath = MovePath.from_state(value)
	if p == null:
		return
	_client_path = p
	if is_inside_tree():
		_update_from_path()
	path_changed.emit()


func _process(_delta: float) -> void:
	if Net.is_server:
		return
	if is_local_player() and NetClock.should_ping():
		NetClock.mark_ping_sent()
		_srv_clock_ping.rpc_id(Net.SERVER_PEER_ID, NetClock.local_now_msec())
	_update_from_path()


## Cliente: posição/direção/anim no relógio do servidor, direto do caminho (sem atraso).
func _update_from_path() -> void:
	if _client_path == null:
		position = net_position
		_apply_visual(facing_yaw, anim)
		return
	var t: float = NetClock.server_now_msec()
	var pos: Vector3 = _client_path.sample(t)
	net_position = pos
	position = pos
	var shown_anim: StringName = anim
	var yaw: float = facing_yaw
	if _client_path.is_moving_at(t):
		shown_anim = ANIM_WALK
		var step_yaw: float = _client_path.facing_at(t)
		if not is_nan(step_yaw):
			yaw = step_yaw
	elif shown_anim == ANIM_WALK:
		# O servidor ainda não mandou o idle (diferença de relógio de poucos ms): já chegou aqui.
		shown_anim = ANIM_IDLE
		var last_yaw: float = _client_path.facing_at(t)
		if not is_nan(last_yaw):
			yaw = last_yaw
	_apply_walk_cycle()
	_apply_visual(yaw, shown_anim)


func _apply_walk_cycle() -> void:
	if _visual == null or _client_path == null or _client_path.ms_per_cell <= 0:
		return
	var cycle: float = WALK_CYCLE_CELLS * _client_path.ms_per_cell
	if cycle != _last_walk_cycle_ms:
		_last_walk_cycle_ms = cycle
		_visual.set(VISUAL_WALK_CYCLE_PROP, cycle)


# ---------------------------------------------------------------- relógio (GDD §10.1)

## Cliente (jogador local) -> servidor: ping com o relógio local do cliente.
@rpc("any_peer", "call_remote", "unreliable")
func _srv_clock_ping(client_msec: Variant) -> void:
	if not Net.is_server:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != get_peer_id() or typeof(client_msec) != TYPE_FLOAT or not is_finite(client_msec):
		Net.log_invalid(sender, "clock_ping_bad", {"entity": entity_id})
		return
	var now: float = NetClock.server_now_msec()
	if now - _last_clock_ping_msec < CLOCK_PING_MIN_INTERVAL_MSEC:
		return
	_last_clock_ping_msec = now
	_cli_clock_pong.rpc_id(sender, client_msec, now)


## Servidor -> cliente: resposta do ping (relógio do cliente ecoado + relógio do servidor).
@rpc("authority", "call_remote", "unreliable")
func _cli_clock_pong(client_msec: float, server_msec: float) -> void:
	NetClock.add_sample(client_msec, server_msec)
