class_name GridMover
extends Node
## Componente de SERVIDOR: movimento clássico por células (GDD §10.1). Substitui o NavMover.
## Serve para jogador, NPC e, depois, monstro.
##
## - move_to(): A* 8 direções na WalkGrid do mapa (GridPathfinder), até Balance.cfg.max_walk_cells;
##   destino inalcançável/longe -> anda até a célula alcançável mais próxima dele.
## - Velocidade constante: ms_per_cell por passo reto (diagonal × Balance.cfg.diagonal_cost).
## - Pedido novo no meio do caminho: termina o passo atual (até a próxima célula) e segue o caminho
##   novo a partir dela, sem voltar nem "teleportar".
## - Replica o CAMINHO (NetEntity.move_state = MovePath.to_state()), não posições interpoladas:
##   cada cliente calcula a posição no relógio do servidor (NetClock).
## - A posição autoritativa (net_position) e a célula (get_cell) são recalculadas a cada tick.
##
## Uso: entity.server_ensure_mover(grid, ms_per_cell); mover.move_to(destino) -> bool;
##      o ServerWorld chama tick() a cada tick do servidor.

## Emitido quando o caminho termina (chegou ao último ponto).
signal arrived
## Emitido sempre que o caminho replicado muda (novo caminho, parada, teleporte).
signal path_changed

const NODE_NAME: String = "GridMover"
## Raio (em células) da busca da célula andável mais próxima quando o ponto de partida/destino cai
## fora da grade andável (ex.: sentado no banco, marcador fora do navmesh).
const SNAP_SEARCH_CELLS: int = 4
## Partindo do repouso, o caminho começa um intervalo de replicação depois do pedido: os clientes
## recebem o caminho antes do primeiro passo e ninguém vê um "salto" no começo.
const START_LEAD_TICKS: int = 1
## Distância (m) abaixo da qual a entidade já está "no centro" da célula.
const ON_CENTER_EPSILON: float = 0.001

## Grade do mapa da instância (compartilhada pelas instâncias do mesmo mapa).
var grid: WalkGrid = null
## Tempo por célula reta (jogador: Balance.cfg.walk_ms_per_cell; NPC: pela velocidade do NpcDef).
var ms_per_cell: int = 0

var _path: MovePath = null
var _moving: bool = false


## ms por célula equivalente a uma velocidade em m/s (NPCs definem velocidade no NpcDef).
static func ms_per_cell_for_speed(speed_mps: float) -> int:
	if speed_mps <= 0.0:
		return Balance.cfg.walk_ms_per_cell
	return roundi(Balance.cfg.cell_size / speed_mps * 1000.0)


func get_entity() -> NetEntity:
	return get_parent() as NetEntity


func get_move_path() -> MovePath:
	return _path


func is_moving() -> bool:
	return _moving


## Destino final do caminho atual (Vector3.INF se parado).
func get_destination() -> Vector3:
	return _path.destination() if _moving and _path != null else Vector3.INF


## Conserva o passo corrente e recalcula o restante com a nova velocidade.
func set_speed(value: int) -> void:
	if value == ms_per_cell:
		return
	ms_per_cell = value
	if _moving and _path != null and grid != null:
		var now: float = NetClock.server_now_msec()
		var k: int = _path.segment_at(now)
		var next: MovePath = MovePath.create(_path.points, _path.start_msec, value, grid.cell_size, Balance.cfg.diagonal_cost)
		for i: int in range(mini(k + 2, next.times.size())):
			next.times[i] = _path.times[i]
		for i: int in range(k + 2, next.times.size()):
			next.times[i] = next.times[i - 1] + MovePath.segment_msec(next.points[i - 1], next.points[i], value, grid.cell_size, Balance.cfg.diagonal_cost)
		_set_path(next)


## Célula autoritativa atual (a da posição no último tick).
func get_cell() -> Vector2i:
	var e: NetEntity = get_entity()
	if grid == null or e == null:
		return Vector2i(-1, -1)
	return grid.world_to_cell(e.net_position)


## Calcula o caminho até target e começa a andar. stop_within (m) > 0 aceita parar em qualquer
## célula a essa distância do alvo (interação). false = nenhum progresso possível (nada muda).
func move_to(target: Vector3, stop_within: float = 0.0) -> bool:
	var e: NetEntity = get_entity()
	if e == null or grid == null:
		return false
	var goal: Vector2i = grid.world_to_cell(target)
	if not grid.in_bounds(goal):
		return false
	var now: int = NetClock.server_now_msec_int()
	# Prefixo que não pode ser desfeito: o passo em andamento (ou o encaixe no centro da célula).
	var prefix := PackedVector3Array()
	var prefix_start: int = now + roundi(START_LEAD_TICKS * 1000.0 / Balance.cfg.server_tick_hz)
	var from_point: Vector3 = _path.sample(float(now)) if _path != null else e.net_position
	if _moving and _path != null and _path.is_moving_at(float(now)):
		var k: int = _path.segment_at(float(now))
		prefix.append(_path.points[k])
		prefix_start = _path.start_msec + _path.times[k]
		from_point = _path.points[k + 1]
	var start_cell: Vector2i = grid.nearest_walkable(grid.world_to_cell(from_point), SNAP_SEARCH_CELLS)
	if start_cell.x < 0:
		return false
	var radius_cells: float = stop_within / grid.cell_size
	var cells: Array[Vector2i] = GridPathfinder.find_path(grid, start_cell, goal,
			Balance.cfg.max_walk_cells, radius_cells)
	if cells.is_empty():
		return false
	var points := PackedVector3Array(prefix)
	points.append(from_point)
	var start_center: Vector3 = grid.cell_to_world(start_cell)
	if from_point.distance_to(start_center) > ON_CENTER_EPSILON:
		points.append(start_center)
	for i: int in range(1, cells.size()):
		points.append(grid.cell_to_world(cells[i]))
	if points.size() < 2:
		# Já está no destino (ou nada a fazer) e parado: nenhum movimento.
		return false
	var next: MovePath = MovePath.create(points, prefix_start, ms_per_cell, grid.cell_size, Balance.cfg.diagonal_cost)
	if not prefix.is_empty():
		var k: int = _path.segment_at(float(now))
		var correction: int = (_path.times[k + 1] - _path.times[k]) - next.times[1]
		for i: int in range(1, next.times.size()):
			next.times[i] += correction
	_set_path(next)
	return true


## Para na próxima célula (termina o passo em andamento; sem voltar para trás).
func stop() -> void:
	if not _moving or _path == null:
		return
	var now: float = NetClock.server_now_msec()
	if now < float(_path.start_msec):
		place(_path.points[0]) # ainda nem saiu do lugar
		return
	var k: int = _path.segment_at(now)
	if k + 2 >= _path.points.size():
		return # já está no último passo
	var pts: PackedVector3Array = _path.points.slice(0, k + 2)
	var stopped: MovePath = MovePath.create(pts, _path.start_msec, _path.ms_per_cell,
			grid.cell_size if grid != null else Balance.cfg.cell_size, Balance.cfg.diagonal_cost)
	stopped.times = _path.times.slice(0, k + 2)
	_set_path(stopped)


## Para imediatamente onde está (sentar, trocar de instância...).
func halt() -> void:
	var e: NetEntity = get_entity()
	if e != null:
		place(e.net_position)


## Coloca a entidade parada em p (teleporte: banco, renascer, troca de instância).
func place(p: Vector3) -> void:
	var e: NetEntity = get_entity()
	var was_moving: bool = _moving
	_path = MovePath.standing(p, NetClock.server_now_msec_int(), ms_per_cell)
	_moving = false
	if e != null:
		e.net_position = p
		e.position = p
		e.move_state = _path.to_state()
		if was_moving and e.anim == NetEntity.ANIM_WALK:
			e.anim = NetEntity.ANIM_IDLE
	path_changed.emit()
	if was_moving:
		arrived.emit()


func _set_path(p: MovePath) -> void:
	_path = p
	_moving = p.points.size() > 1
	var e: NetEntity = get_entity()
	if e == null:
		return
	e.move_state = _path.to_state()
	if _moving:
		e.anim = NetEntity.ANIM_WALK
	path_changed.emit()
	tick()


## Um tick do servidor: posição/direção/anim no relógio do servidor. Só mexe na anim quando anda
## (sit/idle definidos por fora são mantidos).
func tick() -> void:
	var e: NetEntity = get_entity()
	if e == null or _path == null:
		return
	if not _moving:
		return
	var now: float = NetClock.server_now_msec()
	var pos: Vector3 = _path.sample(now)
	e.net_position = pos
	e.position = pos
	var yaw: float = _path.facing_at(now)
	if not is_nan(yaw):
		e.facing_yaw = yaw
	if _path.is_pending_at(now):
		e.anim = NetEntity.ANIM_WALK
		return
	_moving = false
	if e.anim == NetEntity.ANIM_WALK:
		e.anim = NetEntity.ANIM_IDLE
	arrived.emit()
