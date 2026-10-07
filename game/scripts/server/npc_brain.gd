class_name NpcBrain
extends Node
## Componente de SERVIDOR anexado ao NetEntity de um NPC: executa a rotina do NpcDef
## (IDLE, WANDER, PATROL, SIT) usando o GridMover. Enquanto algum jogador conversa com o NPC
## (diálogo ou loja aberta), ele para e se vira para o jogador (contrato city-walk).

const NODE_NAME: String = "NpcBrain"
## WANDER: pausa aleatória entre passeios (s).
const WANDER_PAUSE_MIN_SEC: float = 1.5
const WANDER_PAUSE_MAX_SEC: float = 4.0
## WANDER: tentativas de sortear um ponto alcançável por passeio.
const WANDER_PICK_ATTEMPTS: int = 6
## WANDER: distância mínima (m) de um passeio (evita passinhos imperceptíveis).
const WANDER_MIN_STEP: float = 1.0
## PATROL: pausa em cada marcador (s).
const PATROL_PAUSE_SEC: float = 2.0

var def: NpcDef = null
var spawn_position: Vector3 = Vector3.ZERO
var spawn_yaw: float = 0.0
var patrol_points: Array[Vector3] = []

## peer_id -> entidade do jogador que está conversando.
var _talkers: Dictionary[int, NetEntity] = {}
var _last_talker: int = 0
var _pause_left: float = 0.0
var _patrol_index: int = -1
var _rng := RandomNumberGenerator.new()


func setup(p_def: NpcDef, p_spawn: Vector3, p_yaw: float, p_patrol: Array[Vector3]) -> void:
	def = p_def
	spawn_position = p_spawn
	spawn_yaw = p_yaw
	patrol_points = p_patrol
	_rng.randomize()
	_pause_left = _rng.randf_range(WANDER_PAUSE_MIN_SEC, WANDER_PAUSE_MAX_SEC)


func get_entity() -> NetEntity:
	return get_parent() as NetEntity


## Chamado quando o NPC entra na árvore: pose inicial.
func apply_rest_pose() -> void:
	var e: NetEntity = get_entity()
	e.facing_yaw = spawn_yaw
	e.anim = NetEntity.ANIM_SIT if def.routine == NpcDef.Routine.SIT else NetEntity.ANIM_IDLE


func engage(peer_id: int, player: NetEntity) -> void:
	_talkers[peer_id] = player
	_last_talker = peer_id
	var e: NetEntity = get_entity()
	var mover: GridMover = e.get_mover()
	if mover != null:
		# Para na hora (não termina o passo): o jogador já está falando com ele.
		mover.halt()
	e.face_towards(player.net_position)


func disengage(peer_id: int) -> void:
	if not _talkers.has(peer_id):
		return
	_talkers.erase(peer_id)
	if _talkers.is_empty():
		_on_released()


func is_engaged() -> bool:
	return not _talkers.is_empty()


func is_engaged_with(peer_id: int) -> bool:
	return _talkers.has(peer_id)


func _on_released() -> void:
	match def.routine:
		NpcDef.Routine.IDLE, NpcDef.Routine.SIT:
			apply_rest_pose()
		_:
			_pause_left = _rng.randf_range(WANDER_PAUSE_MIN_SEC, WANDER_PAUSE_MAX_SEC)


## Decisão de um tick (antes do movimento do GridMover).
func tick(delta: float) -> void:
	var e: NetEntity = get_entity()
	if is_engaged():
		for p: int in _talkers.keys():
			if not is_instance_valid(_talkers[p]):
				_talkers.erase(p)
		if _talkers.is_empty():
			_on_released()
			return
		var talker: NetEntity = _talkers.get(_last_talker, _talkers.values()[0])
		e.face_towards(talker.net_position)
		return
	var mover: GridMover = e.get_mover()
	if mover == null or mover.is_moving():
		return
	match def.routine:
		NpcDef.Routine.WANDER:
			_tick_wander(delta, mover)
		NpcDef.Routine.PATROL:
			_tick_patrol(delta, mover)


func _tick_wander(delta: float, mover: GridMover) -> void:
	_pause_left -= delta
	if _pause_left > 0.0:
		return
	_pause_left = _rng.randf_range(WANDER_PAUSE_MIN_SEC, WANDER_PAUSE_MAX_SEC)
	var e: NetEntity = get_entity()
	var grid: WalkGrid = mover.grid
	if grid == null:
		return
	# Sorteia uma célula andável dentro do raio (o A* leva até lá pela grade).
	for i: int in range(WANDER_PICK_ATTEMPTS):
		var angle: float = _rng.randf_range(0.0, TAU)
		var dist: float = _rng.randf_range(0.0, def.wander_radius)
		var target: Vector3 = spawn_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var cell: Vector2i = grid.world_to_cell(target)
		if not grid.is_walkable(cell):
			continue
		target = grid.cell_to_world(cell)
		if e.flat_distance_to(target) < WANDER_MIN_STEP:
			continue
		if mover.move_to(target):
			return


func _tick_patrol(delta: float, mover: GridMover) -> void:
	if patrol_points.is_empty():
		return
	_pause_left -= delta
	if _pause_left > 0.0:
		return
	_pause_left = PATROL_PAUSE_SEC
	_patrol_index = (_patrol_index + 1) % patrol_points.size()
	mover.move_to(patrol_points[_patrol_index])
