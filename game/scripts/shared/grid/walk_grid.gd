class_name WalkGrid
extends RefCounted
## Grade de células andáveis de um mapa (GDD §10.1: movimento clássico por células).
##
## Cada célula tem Balance.cfg.cell_size de lado e é andável quando o seu centro está sobre o navmesh
## (a menos de ON_NAV_EPSILON no plano XZ). for_map() rasteriza os polígonos do NavigationMesh
## (rápido: ~0,1 s num mapa de 120 x 120 m); build() faz a mesma pergunta ao NavigationServer3D
## (map_get_closest_point, ~20x mais lento) e serve de referência nos testes. A grade é
## construída de forma determinística depois que o navmesh sincroniza e fica em cache por map_id:
## todas as instâncias do mesmo mapa (servidor) usam a mesma grade; o cliente constrói a sua para
## encaixar o clique/destino no centro da célula.
##
## Passos entre vizinhas também são validados: o ponto médio do passo precisa estar no navmesh
## (evita "pular" paredes finas) e a diagonal só vale se as duas células laterais forem andáveis e
## ligadas (sem cortar quina).
##
## Coordenadas: célula = Vector2i(x, z); x cresce para +X e z para +Z do mundo.

## Bits de _flags por célula.
const FLAG_WALKABLE: int = 1
## Passo livre para (x+1, z).
const FLAG_EDGE_E: int = 2
## Passo livre para (x, z+1).
const FLAG_EDGE_S: int = 4
## Passo livre para (x+1, z+1).
const FLAG_EDGE_SE: int = 8
## Passo livre para (x-1, z+1).
const FLAG_EDGE_SW: int = 16
## Distância máxima (m, plano XZ) entre a amostra e o ponto mais próximo do navmesh.
const ON_NAV_EPSILON: float = 0.05
## Maior desnível (m) aceito entre células vizinhas (e entre célula e ponto médio do passo).
const MAX_STEP_HEIGHT: float = 0.6
## Abaixo disso a normal do polígono é considerada vertical (sem altura definida).
const EPSILON_NORMAL: float = 0.000001
## Amostras por célula em cada eixo: centros, pontos médios das arestas e quinas.
const SAMPLES_PER_CELL: int = 2
## Custo inteiro de um passo reto (o diagonal é round(ORTHO_COST × Balance.cfg.diagonal_cost)).
const ORTHO_COST: int = 10
## As 8 direções em ordem fixa (desempate determinístico do A*): N, L, S, O, NE, SE, SO, NO.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## Grades construídas, por chave (normalmente o map_id).
static var _cache: Dictionary[StringName, WalkGrid] = {}

var cell_size: float = 1.0
## Canto mínimo (x, z) da grade no mundo.
var origin: Vector2 = Vector2.ZERO
## Número de células em x e z.
var size: Vector2i = Vector2i.ZERO
## Tempo de construção (ms), para diagnóstico.
var build_msec: int = 0
var _flags: PackedByteArray = PackedByteArray()
var _heights: PackedFloat32Array = PackedFloat32Array()


# ---------------------------------------------------------------- cache / construção

## Grade em cache para a chave, ou null.
static func get_cached(key: StringName) -> WalkGrid:
	return _cache.get(key)


static func clear_cache() -> void:
	_cache.clear()


## Grade do mapa (cache por map_id). null se o navmesh ainda não sincronizou.
## map_node: raiz do mapa (GameMap), usada só para achar os limites do navmesh.
static func for_map(map_id: StringName, map_node: Node, nav_map: RID) -> WalkGrid:
	var cached: WalkGrid = _cache.get(map_id)
	if cached != null:
		return cached
	var bounds: AABB = navmesh_bounds(map_node)
	if bounds.size == Vector3.ZERO or not is_nav_synced(nav_map):
		return null
	var g: WalkGrid = build_from_navmesh(map_node, Balance.cfg.cell_size)
	_cache[map_id] = g
	return g


## Navmesh sincronizado e com polígonos (a primeira iteração pode ainda não ter a malha).
static func is_nav_synced(nav_map: RID) -> bool:
	return nav_map.is_valid() and NavigationServer3D.map_get_iteration_id(nav_map) > 0 \
			and not NavigationServer3D.map_get_regions(nav_map).is_empty() \
			and NavigationServer3D.map_get_closest_point_owner(nav_map, Vector3.ZERO).is_valid()


## Limites (mundo) de todos os NavigationMesh das NavigationRegion3D do mapa.
static func navmesh_bounds(map_node: Node) -> AABB:
	var out := AABB()
	var first: bool = true
	if map_node == null:
		return out
	for n: Node in map_node.find_children("*", "NavigationRegion3D", true, false):
		var region := n as NavigationRegion3D
		if region.navigation_mesh == null:
			continue
		var xf: Transform3D = region.global_transform if region.is_inside_tree() else region.transform
		for v: Vector3 in region.navigation_mesh.get_vertices():
			var p: Vector3 = xf * v
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out


## Constrói a grade rasterizando os polígonos (convexos) dos NavigationMesh do mapa: uma amostra de
## meia célula é "no navmesh" se estiver dentro (ou a ON_NAV_EPSILON da borda) de algum polígono;
## a altura vem do plano do polígono. Determinístico (ordem fixa de regiões e polígonos).
static func build_from_navmesh(map_node: Node, p_cell_size: float) -> WalkGrid:
	var t0: int = Time.get_ticks_msec()
	var bounds: AABB = navmesh_bounds(map_node)
	var g := WalkGrid.new()
	g._init_layout(bounds, p_cell_size)
	var sw: int = g.size.x * SAMPLES_PER_CELL + 1
	var sh: int = g.size.y * SAMPLES_PER_CELL + 1
	var step: float = p_cell_size / SAMPLES_PER_CELL
	var on_nav := PackedByteArray()
	on_nav.resize(sw * sh)
	var sample_y := PackedFloat32Array()
	sample_y.resize(sw * sh)
	for n: Node in map_node.find_children("*", "NavigationRegion3D", true, false):
		var region := n as NavigationRegion3D
		var mesh: NavigationMesh = region.navigation_mesh
		if mesh == null:
			continue
		var xf: Transform3D = region.global_transform if region.is_inside_tree() else region.transform
		var verts: PackedVector3Array = mesh.get_vertices()
		for vi: int in range(verts.size()):
			verts[vi] = xf * verts[vi]
		for pi: int in range(mesh.get_polygon_count()):
			var poly: PackedInt32Array = mesh.get_polygon(pi)
			if poly.size() < 3:
				continue
			g._raster_polygon(verts, poly, on_nav, sample_y, sw, sh, step)
	g._fill_from_samples(on_nav, sample_y, sw)
	g.build_msec = Time.get_ticks_msec() - t0
	return g


func _init_layout(bounds: AABB, p_cell_size: float) -> void:
	cell_size = p_cell_size
	var min_x: float = floorf(bounds.position.x / p_cell_size) * p_cell_size
	var min_z: float = floorf(bounds.position.z / p_cell_size) * p_cell_size
	var max_x: float = ceilf(bounds.end.x / p_cell_size) * p_cell_size
	var max_z: float = ceilf(bounds.end.z / p_cell_size) * p_cell_size
	origin = Vector2(min_x, min_z)
	size = Vector2i(maxi(1, roundi((max_x - min_x) / p_cell_size)),
			maxi(1, roundi((max_z - min_z) / p_cell_size)))


func _raster_polygon(verts: PackedVector3Array, poly: PackedInt32Array, on_nav: PackedByteArray,
		sample_y: PackedFloat32Array, sw: int, sh: int, step: float) -> void:
	var n: int = poly.size()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i: int in range(n):
		var v: Vector3 = verts[poly[i]]
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.z))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.z))
	var sx0: int = maxi(0, ceili((lo.x - ON_NAV_EPSILON - origin.x) / step))
	var sx1: int = mini(sw - 1, floori((hi.x + ON_NAV_EPSILON - origin.x) / step))
	var sz0: int = maxi(0, ceili((lo.y - ON_NAV_EPSILON - origin.y) / step))
	var sz1: int = mini(sh - 1, floori((hi.y + ON_NAV_EPSILON - origin.y) / step))
	if sx0 > sx1 or sz0 > sz1:
		return
	var a: Vector3 = verts[poly[0]]
	var normal: Vector3 = (verts[poly[1]] - a).cross(verts[poly[2]] - a)
	for sz: int in range(sz0, sz1 + 1):
		var z: float = origin.y + sz * step
		for sx: int in range(sx0, sx1 + 1):
			var idx: int = sz * sw + sx
			if on_nav[idx] == 1:
				continue
			var x: float = origin.x + sx * step
			if not _inside_convex(verts, poly, x, z):
				continue
			on_nav[idx] = 1
			# Altura no plano do polígono (malha plana/inclinada); vertical degenerado -> vértice 0.
			sample_y[idx] = a.y - (normal.x * (x - a.x) + normal.z * (z - a.z)) / normal.y \
					if absf(normal.y) > EPSILON_NORMAL else a.y


## Ponto (x, z) dentro do polígono convexo (qualquer sentido de giro), com folga ON_NAV_EPSILON.
static func _inside_convex(verts: PackedVector3Array, poly: PackedInt32Array, x: float, z: float) -> bool:
	var n: int = poly.size()
	var pos: bool = true
	var neg: bool = true
	for i: int in range(n):
		var p0: Vector3 = verts[poly[i]]
		var p1: Vector3 = verts[poly[(i + 1) % n]]
		var ex: float = p1.x - p0.x
		var ez: float = p1.z - p0.z
		var len: float = sqrt(ex * ex + ez * ez)
		if len <= 0.0:
			continue
		var d: float = (ex * (z - p0.z) - ez * (x - p0.x)) / len
		if d < -ON_NAV_EPSILON:
			pos = false
		if d > ON_NAV_EPSILON:
			neg = false
		if not pos and not neg:
			return false
	return true


## Constrói a grade consultando o NavigationServer3D (referência lenta; mesma pergunta que
## build_from_navmesh). Determinístico: mesma malha -> mesma grade.
static func build(nav_map: RID, bounds: AABB, p_cell_size: float) -> WalkGrid:
	var t0: int = Time.get_ticks_msec()
	var g := WalkGrid.new()
	g._init_layout(bounds, p_cell_size)
	var min_x: float = g.origin.x
	var min_z: float = g.origin.y
	# Amostras em meia célula: índice par = borda/quina, ímpar = centro.
	var sw: int = g.size.x * SAMPLES_PER_CELL + 1
	var sh: int = g.size.y * SAMPLES_PER_CELL + 1
	var step: float = p_cell_size / SAMPLES_PER_CELL
	var query_y: float = bounds.get_center().y
	var eps2: float = ON_NAV_EPSILON * ON_NAV_EPSILON
	var on_nav := PackedByteArray()
	on_nav.resize(sw * sh)
	var sample_y := PackedFloat32Array()
	sample_y.resize(sw * sh)
	for sz: int in range(sh):
		var z: float = min_z + sz * step
		for sx: int in range(sw):
			var x: float = min_x + sx * step
			var c: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, Vector3(x, query_y, z))
			var dx: float = c.x - x
			var dz: float = c.z - z
			if dx * dx + dz * dz <= eps2:
				on_nav[sz * sw + sx] = 1
				sample_y[sz * sw + sx] = c.y
	g._fill_from_samples(on_nav, sample_y, sw)
	g.build_msec = Time.get_ticks_msec() - t0
	return g


## Grade a partir de uma máscara (testes): rows[z][x] == "." andável, qualquer outro = bloqueado.
static func from_ascii(rows: PackedStringArray, p_cell_size: float = 1.0,
		p_origin: Vector2 = Vector2.ZERO) -> WalkGrid:
	var g := WalkGrid.new()
	g.cell_size = p_cell_size
	g.origin = p_origin
	g.size = Vector2i(rows[0].length(), rows.size())
	var sw: int = g.size.x * SAMPLES_PER_CELL + 1
	var sh: int = g.size.y * SAMPLES_PER_CELL + 1
	var on_nav := PackedByteArray()
	on_nav.resize(sw * sh)
	var sample_y := PackedFloat32Array()
	sample_y.resize(sw * sh)
	# Uma amostra está "no navmesh" se todas as células que ela toca existirem e forem andáveis.
	for sz: int in range(sh):
		for sx: int in range(sw):
			var ok: bool = true
			for cz: int in _touching_cells(sz):
				for cx: int in _touching_cells(sx):
					if cx < 0 or cz < 0 or cx >= g.size.x or cz >= g.size.y or rows[cz][cx] != ".":
						ok = false
			on_nav[sz * sw + sx] = 1 if ok else 0
	g._fill_from_samples(on_nav, sample_y, sw)
	return g


## Células (em um eixo) tocadas pela amostra de meia célula s: centro = 1 célula, borda = 2.
static func _touching_cells(s: int) -> Array[int]:
	if s % SAMPLES_PER_CELL == 1:
		return [(s - 1) / SAMPLES_PER_CELL]
	return [s / SAMPLES_PER_CELL - 1, s / SAMPLES_PER_CELL]


func _fill_from_samples(on_nav: PackedByteArray, sample_y: PackedFloat32Array, sw: int) -> void:
	var n: int = size.x * size.y
	_flags = PackedByteArray()
	_flags.resize(n)
	_heights = PackedFloat32Array()
	_heights.resize(n)
	for z: int in range(size.y):
		for x: int in range(size.x):
			var s: int = (z * SAMPLES_PER_CELL + 1) * sw + x * SAMPLES_PER_CELL + 1
			if on_nav[s] == 1:
				_flags[z * size.x + x] = FLAG_WALKABLE
				_heights[z * size.x + x] = sample_y[s]
	# Passos retos: as duas células andáveis, ponto médio no navmesh, desnível pequeno.
	for z: int in range(size.y):
		for x: int in range(size.x):
			var i: int = z * size.x + x
			if _flags[i] & FLAG_WALKABLE == 0:
				continue
			var sc: int = (z * SAMPLES_PER_CELL + 1) * sw + x * SAMPLES_PER_CELL + 1
			if x + 1 < size.x and _flags[i + 1] & FLAG_WALKABLE != 0 \
					and _sample_links(on_nav, sample_y, sc + 1, _heights[i], _heights[i + 1]):
				_flags[i] |= FLAG_EDGE_E
			if z + 1 < size.y and _flags[i + size.x] & FLAG_WALKABLE != 0 \
					and _sample_links(on_nav, sample_y, sc + sw, _heights[i], _heights[i + size.x]):
				_flags[i] |= FLAG_EDGE_S
	# Diagonais: sem cortar quina (as 4 arestas retas em volta livres) e quina no navmesh.
	for z: int in range(size.y - 1):
		for x: int in range(size.x):
			var i: int = z * size.x + x
			if _flags[i] & FLAG_WALKABLE == 0:
				continue
			var sc: int = (z * SAMPLES_PER_CELL + 1) * sw + x * SAMPLES_PER_CELL + 1
			if x + 1 < size.x and _flags[i] & FLAG_EDGE_E != 0 and _flags[i] & FLAG_EDGE_S != 0 \
					and _flags[i + 1] & FLAG_EDGE_S != 0 and _flags[i + size.x] & FLAG_EDGE_E != 0 \
					and _sample_links(on_nav, sample_y, sc + sw + 1, _heights[i], _heights[i + size.x + 1]):
				_flags[i] |= FLAG_EDGE_SE
			if x - 1 >= 0 and _flags[i - 1] & FLAG_EDGE_E != 0 and _flags[i] & FLAG_EDGE_S != 0 \
					and _flags[i - 1] & FLAG_EDGE_S != 0 and _flags[i + size.x - 1] & FLAG_EDGE_E != 0 \
					and _sample_links(on_nav, sample_y, sc + sw - 1, _heights[i], _heights[i + size.x - 1]):
				_flags[i] |= FLAG_EDGE_SW


static func _sample_links(on_nav: PackedByteArray, sample_y: PackedFloat32Array, s: int,
		h_from: float, h_to: float) -> bool:
	if on_nav[s] != 1:
		return false
	return absf(h_to - h_from) <= MAX_STEP_HEIGHT and absf(sample_y[s] - h_from) <= MAX_STEP_HEIGHT


# ---------------------------------------------------------------- consultas

func cell_count() -> int:
	return size.x * size.y


func walkable_count() -> int:
	var n: int = 0
	for f: int in _flags:
		if f & FLAG_WALKABLE != 0:
			n += 1
	return n


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func index_of(c: Vector2i) -> int:
	return c.y * size.x + c.x


func cell_of_index(i: int) -> Vector2i:
	return Vector2i(i % size.x, i / size.x)


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and _flags[index_of(c)] & FLAG_WALKABLE != 0


## Célula que contém o ponto (pode estar fora dos limites; ver in_bounds).
func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell_size), floori((p.z - origin.y) / cell_size))


## Centro da célula no mundo (altura do navmesh se andável, senão 0).
func cell_to_world(c: Vector2i) -> Vector3:
	var h: float = _heights[index_of(c)] if in_bounds(c) else 0.0
	return Vector3(origin.x + (c.x + 0.5) * cell_size, h, origin.y + (c.y + 0.5) * cell_size)


## Ponto encaixado no centro da sua célula.
func snap(p: Vector3) -> Vector3:
	return cell_to_world(world_to_cell(p))


## Passo de uma célula na direção d (um dos DIRECTIONS) é permitido?
func can_step(c: Vector2i, d: Vector2i) -> bool:
	var to: Vector2i = c + d
	if not in_bounds(c) or not in_bounds(to):
		return false
	# Normaliza para as 4 arestas guardadas (E, S, SE, SW) a partir da célula "de cima/esquerda".
	var base: Vector2i = c
	var flag: int = 0
	match d:
		Vector2i(1, 0):
			flag = FLAG_EDGE_E
		Vector2i(-1, 0):
			base = to
			flag = FLAG_EDGE_E
		Vector2i(0, 1):
			flag = FLAG_EDGE_S
		Vector2i(0, -1):
			base = to
			flag = FLAG_EDGE_S
		Vector2i(1, 1):
			flag = FLAG_EDGE_SE
		Vector2i(-1, -1):
			base = to
			flag = FLAG_EDGE_SE
		Vector2i(-1, 1):
			flag = FLAG_EDGE_SW
		Vector2i(1, -1):
			base = to
			flag = FLAG_EDGE_SW
		_:
			return false
	return _flags[index_of(base)] & flag != 0


## Célula andável mais próxima de c (anéis quadrados crescentes; desempate pela distância
## euclidiana e depois pelo índice). Vector2i(-1, -1) se nenhuma até max_radius.
func nearest_walkable(c: Vector2i, max_radius: int) -> Vector2i:
	if is_walkable(c):
		return c
	var best := Vector2i(-1, -1)
	var best_d2: int = 0
	for r: int in range(1, max_radius + 1):
		for dz: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var p := Vector2i(c.x + dx, c.y + dz)
				if not is_walkable(p):
					continue
				var d2: int = dx * dx + dz * dz
				if best.x < 0 or d2 < best_d2 or (d2 == best_d2 and index_of(p) < index_of(best)):
					best = p
					best_d2 = d2
		# Um anel mais externo ainda pode ter distância euclidiana menor que a do atual; basta
		# olhar até r * sqrt(2).
		if best.x >= 0 and float(r) >= sqrt(float(best_d2)):
			return best
	return best


## Assinatura do conteúdo da grade (determinismo: servidor e cliente devem dar o mesmo valor).
func flags_hash() -> int:
	return hash(_flags) ^ hash(size) ^ hash(origin)
