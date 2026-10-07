class_name MovePath
extends RefCounted
## Caminho com horário (GDD §10.1): pontos (centros de célula) + instante em que cada ponto é
## alcançado. O servidor cria e replica o estado (to_state); servidor e clientes calculam a posição
## no mesmo instante do relógio do servidor (sample), então todos veem o mesmo movimento sem atraso
## de interpolação. Velocidade constante por trecho, sem aceleração.
##
## Duração de um trecho: passo reto = ms_per_cell; passo diagonal = ms_per_cell × diagonal_cost;
## trecho fora da grade (ex.: do banco até o centro da célula) = ms_per_cell × distância / célula.

## Índices do Array replicado (NetEntity.move_state).
const STATE_START: int = 0
const STATE_MS_PER_CELL: int = 1
const STATE_POINTS: int = 2
const STATE_TIMES: int = 3
const STATE_SIZE: int = 4
## Tolerância (fração da célula) para reconhecer um passo de grade reto/diagonal.
const GRID_STEP_TOLERANCE: float = 0.01
## Abaixo disso (m) um trecho não define direção.
const MIN_FACING_STEP: float = 0.0001

## Relógio do servidor (ms) em que points[0] é deixado.
var start_msec: int = 0
var ms_per_cell: int = 0
var points: PackedVector3Array = PackedVector3Array()
## times[i] = ms após start_msec em que points[i] é alcançado (times[0] = 0, crescente).
var times: PackedInt32Array = PackedInt32Array()


## Parado em p (sem movimento) desde now_msec.
static func standing(p: Vector3, now_msec: int, p_ms_per_cell: int = 0) -> MovePath:
	var m := MovePath.new()
	m.start_msec = now_msec
	m.ms_per_cell = p_ms_per_cell
	m.points = PackedVector3Array([p])
	m.times = PackedInt32Array([0])
	return m


## Caminho pelos pontos a partir de p_start_msec, com as durações da regra acima.
static func create(p_points: PackedVector3Array, p_start_msec: int, p_ms_per_cell: int,
		cell_size: float, diagonal_cost: float) -> MovePath:
	var m := MovePath.new()
	m.start_msec = p_start_msec
	m.ms_per_cell = p_ms_per_cell
	m.points = p_points
	m.times = PackedInt32Array()
	m.times.resize(p_points.size())
	var acc: int = 0
	for i: int in range(1, p_points.size()):
		acc += segment_msec(p_points[i - 1], p_points[i], p_ms_per_cell, cell_size, diagonal_cost)
		m.times[i] = acc
	return m


static func segment_msec(a: Vector3, b: Vector3, p_ms_per_cell: int, cell_size: float,
		diagonal_cost: float) -> int:
	var dx: float = absf(b.x - a.x) / cell_size
	var dz: float = absf(b.z - a.z) / cell_size
	if absf(dx - 1.0) <= GRID_STEP_TOLERANCE and absf(dz - 1.0) <= GRID_STEP_TOLERANCE:
		return roundi(p_ms_per_cell * diagonal_cost)
	return roundi(p_ms_per_cell * sqrt(dx * dx + dz * dz))


static func from_state(state: Array) -> MovePath:
	if state.size() < STATE_SIZE:
		return null
	var m := MovePath.new()
	m.start_msec = int(state[STATE_START])
	m.ms_per_cell = int(state[STATE_MS_PER_CELL])
	m.points = state[STATE_POINTS] as PackedVector3Array
	m.times = state[STATE_TIMES] as PackedInt32Array
	if m.points.is_empty() or m.points.size() != m.times.size():
		return null
	return m


func to_state() -> Array:
	return [start_msec, ms_per_cell, points, times]


func end_msec() -> int:
	return start_msec + times[times.size() - 1]


func destination() -> Vector3:
	return points[points.size() - 1]


## Andando no instante t (relógio do servidor, ms)? (Antes de start_msec ainda está parado.)
func is_moving_at(t: float) -> bool:
	return points.size() > 1 and t >= float(start_msec) and t < float(end_msec())


## O caminho ainda não terminou em t (inclui a espera antes do início)?
func is_pending_at(t: float) -> bool:
	return points.size() > 1 and t < float(end_msec())


## Índice k do trecho points[k] -> points[k+1] em andamento no instante t (clamp nos extremos).
func segment_at(t: float) -> int:
	var rel: float = t - float(start_msec)
	var last: int = points.size() - 2
	if last < 0:
		return 0
	for k: int in range(last + 1):
		if rel < float(times[k + 1]):
			return k
	return last


## Posição no instante t (antes do início = primeiro ponto; depois do fim = último ponto).
func sample(t: float) -> Vector3:
	var rel: float = t - float(start_msec)
	if points.size() == 1 or rel <= 0.0:
		return points[0]
	if rel >= float(times[times.size() - 1]):
		return points[points.size() - 1]
	var k: int = segment_at(t)
	var span: float = float(times[k + 1] - times[k])
	var f: float = clampf((rel - float(times[k])) / span, 0.0, 1.0) if span > 0.0 else 1.0
	return points[k].lerp(points[k + 1], f)


## Yaw (0 = olhando -Z) do trecho em andamento em t, ou NAN se parado/sem direção.
func facing_at(t: float) -> float:
	if points.size() < 2:
		return NAN
	var k: int = segment_at(t)
	return yaw_of(points[k + 1] - points[k])


## Yaw de um passo (plano XZ), encaixado numa das 8 direções.
static func yaw_of(step: Vector3) -> float:
	var flat := Vector2(step.x, step.z)
	if flat.length() <= MIN_FACING_STEP:
		return NAN
	var yaw: float = atan2(-step.x, -step.z)
	var sector: float = TAU / WalkGrid.DIRECTIONS.size()
	return wrapf(roundf(yaw / sector) * sector, -PI, PI)
