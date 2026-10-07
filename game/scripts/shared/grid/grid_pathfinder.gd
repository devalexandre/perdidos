class_name GridPathfinder
extends RefCounted
## A* em 8 direções sobre uma WalkGrid (GDD §10.1). Custos inteiros (reto = WalkGrid.ORTHO_COST,
## diagonal = round(reto × Balance.cfg.diagonal_cost)), sem cortar quina (WalkGrid.can_step) e com
## limite de passos (Balance.cfg.max_walk_cells). Determinístico: mesma grade + mesma consulta ->
## mesmo caminho (desempate por f, depois h, depois índice da célula; vizinhos em ordem fixa).
##
## Se o destino for inalcançável ou estiver além do limite, devolve o caminho até a célula
## alcançável mais próxima do destino (como nos MMOs clássicos: anda "até onde dá" na direção).

## Bits reservados na chave do heap (f | h | índice), todos inteiros não negativos.
const INDEX_BITS: int = 24
const H_BITS: int = 20
const UNVISITED: int = -1


## Caminho de start até goal (inclusive os dois). goal_radius (em células) > 0 aceita qualquer
## célula a essa distância euclidiana do goal. Vazio se start não for andável.
## Sem caminho até o goal: termina na célula explorada mais próxima dele (pode ser só [start]).
static func find_path(grid: WalkGrid, start: Vector2i, goal: Vector2i, max_steps: int,
		goal_radius: float = 0.0, diagonal_cost: float = -1.0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if grid == null or not grid.is_walkable(start):
		return out
	var diag_mult: float = Balance.cfg.diagonal_cost if diagonal_cost < 0.0 else diagonal_cost
	var ortho: int = WalkGrid.ORTHO_COST
	var diag: int = roundi(ortho * diag_mult)
	var radius2: float = goal_radius * goal_radius
	var radius_cost: int = ceili(goal_radius * diag)
	var n: int = grid.cell_count()
	var g_cost := PackedInt32Array()
	g_cost.resize(n)
	g_cost.fill(UNVISITED)
	var steps := PackedInt32Array()
	steps.resize(n)
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(UNVISITED)
	var closed := PackedByteArray()
	closed.resize(n)
	var heap: Array[int] = []
	var s_idx: int = grid.index_of(start)
	g_cost[s_idx] = 0
	steps[s_idx] = 0
	var h0: int = _heuristic(start, goal, ortho, diag, radius_cost)
	_heap_push(heap, _key(h0, h0, s_idx))
	var best_idx: int = s_idx
	var best_dist: int = _dist2(start, goal)
	var best_g: int = 0
	var found: int = UNVISITED
	while not heap.is_empty():
		var key: int = _heap_pop(heap)
		var idx: int = key & ((1 << INDEX_BITS) - 1)
		if closed[idx] == 1:
			continue
		closed[idx] = 1
		var c: Vector2i = grid.cell_of_index(idx)
		var d2: int = _dist2(c, goal)
		if float(d2) <= radius2:
			found = idx
			break
		if d2 < best_dist or (d2 == best_dist and (g_cost[idx] < best_g
				or (g_cost[idx] == best_g and idx < best_idx))):
			best_idx = idx
			best_dist = d2
			best_g = g_cost[idx]
		if steps[idx] >= max_steps:
			continue
		for i: int in range(WalkGrid.DIRECTIONS.size()):
			var d: Vector2i = WalkGrid.DIRECTIONS[i]
			if not grid.can_step(c, d):
				continue
			var nc: Vector2i = c + d
			var ni: int = grid.index_of(nc)
			if closed[ni] == 1:
				continue
			var ng: int = g_cost[idx] + (diag if d.x != 0 and d.y != 0 else ortho)
			if g_cost[ni] != UNVISITED and ng >= g_cost[ni]:
				continue
			g_cost[ni] = ng
			steps[ni] = steps[idx] + 1
			parent[ni] = idx
			var h: int = _heuristic(nc, goal, ortho, diag, radius_cost)
			_heap_push(heap, _key(ng + h, h, ni))
	var end_idx: int = found if found != UNVISITED else best_idx
	var i: int = end_idx
	while i != UNVISITED:
		out.append(grid.cell_of_index(i))
		i = parent[i]
	out.reverse()
	return out


## Distância octil (admissível) até o goal, descontando o raio de chegada.
static func _heuristic(c: Vector2i, goal: Vector2i, ortho: int, diag: int, radius_cost: int) -> int:
	var dx: int = absi(c.x - goal.x)
	var dz: int = absi(c.y - goal.y)
	var octile: int = diag * mini(dx, dz) + ortho * (maxi(dx, dz) - mini(dx, dz))
	return maxi(0, octile - radius_cost)


static func _dist2(a: Vector2i, b: Vector2i) -> int:
	var dx: int = a.x - b.x
	var dz: int = a.y - b.y
	return dx * dx + dz * dz


static func _key(f: int, h: int, idx: int) -> int:
	return (f << (INDEX_BITS + H_BITS)) | (mini(h, (1 << H_BITS) - 1) << INDEX_BITS) | idx


# --- heap binário mínimo de inteiros

static func _heap_push(heap: Array[int], v: int) -> void:
	heap.append(v)
	var i: int = heap.size() - 1
	while i > 0:
		var p: int = (i - 1) >> 1
		if heap[p] <= v:
			break
		heap[i] = heap[p]
		i = p
	heap[i] = v


static func _heap_pop(heap: Array[int]) -> int:
	var top: int = heap[0]
	var last: int = heap.pop_back()
	var n: int = heap.size()
	if n == 0:
		return top
	var i: int = 0
	while true:
		var l: int = 2 * i + 1
		if l >= n:
			break
		var r: int = l + 1
		var m: int = r if r < n and heap[r] < heap[l] else l
		if heap[m] >= last:
			break
		heap[i] = heap[m]
		i = m
	heap[i] = last
	return top
