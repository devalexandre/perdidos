extends Node
## Testes headless do movimento por células (GDD §10.1): WalkGrid, A* (GridPathfinder), MovePath
## (reprodução com horário), NetClock, GridMover (troca de caminho no meio do passo) e a grade do
## mapa real (construção determinística e tempo).
## Rodar: godot --headless --path game res://tests/grid/test_grid.tscn

const MAP_SCENE: String = "res://scenes/maps/city_awakening.tscn"
const ENTITY_SCENE: String = "res://scenes/entities/net_entity.tscn"
const EPS: float = 0.0001
const MS: int = 200
const DIAG: float = 1.4
## Limite de tempo para construir a grade do mapa (~120 x 120 m).
const MAX_BUILD_MSEC: int = 500
## Diferença tolerada entre a rasterização e a consulta ao NavigationServer (bordas).
const MAX_MISMATCH_FRACTION: float = 0.005
## Quadros de física para o navmesh sincronizar.
const NAV_SYNC_MAX_FRAMES: int = 60
## Erro de relógio simulado (ms) no teste de reprodução.
const CLOCK_ERROR_MSEC: float = 15.0
const OPEN_10: PackedStringArray = [
	"..........", "..........", "..........", "..........", "..........",
	"..........", "..........", "..........", "..........", "..........",
]

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_test_straight()
	_test_diagonal()
	_test_blocked_corners()
	_test_unreachable_nearest()
	_test_max_steps()
	_test_determinism()
	_test_goal_radius()
	_test_playback_timing()
	_test_clock_sample()
	await _test_real_map_and_mover()
	print("test_grid: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + msg)


func _path(g: WalkGrid, a: Vector2i, b: Vector2i, max_steps: int = 40, r: float = 0.0) -> Array[Vector2i]:
	return GridPathfinder.find_path(g, a, b, max_steps, r, DIAG)


func _steps_ok(g: WalkGrid, p: Array[Vector2i]) -> bool:
	for i: int in range(1, p.size()):
		var d: Vector2i = p[i] - p[i - 1]
		if absi(d.x) > 1 or absi(d.y) > 1 or d == Vector2i.ZERO or not g.can_step(p[i - 1], d):
			return false
	return true


func _test_straight() -> void:
	var g := WalkGrid.from_ascii(OPEN_10)
	var p: Array[Vector2i] = _path(g, Vector2i(1, 1), Vector2i(7, 1))
	_check(p.size() == 7 and p[0] == Vector2i(1, 1) and p[6] == Vector2i(7, 1), "reto: %s" % [p])
	var same_row: bool = true
	for c: Vector2i in p:
		same_row = same_row and c.y == 1
	_check(same_row and _steps_ok(g, p), "reto: sem desvio")
	_check(g.cell_to_world(Vector2i(1, 1)).is_equal_approx(Vector3(1.5, 0.0, 1.5)), "centro da célula")
	_check(g.world_to_cell(Vector3(1.99, 0.0, 1.01)) == Vector2i(1, 1), "mundo -> célula")


func _test_diagonal() -> void:
	var g := WalkGrid.from_ascii(OPEN_10)
	var p: Array[Vector2i] = _path(g, Vector2i(1, 1), Vector2i(6, 6))
	_check(p.size() == 6, "diagonal: 5 passos (%d células)" % p.size())
	var all_diag: bool = true
	for i: int in range(1, p.size()):
		var d: Vector2i = p[i] - p[i - 1]
		all_diag = all_diag and d == Vector2i(1, 1)
	_check(all_diag and _steps_ok(g, p), "diagonal pura: %s" % [p])
	# Movimento misto (3, 1): 1 diagonal + 2 retos = custo 14 + 20; 3 passos.
	var q: Array[Vector2i] = _path(g, Vector2i(1, 1), Vector2i(4, 2))
	_check(q.size() == 4 and _steps_ok(g, q), "misto: %s" % [q])


func _test_blocked_corners() -> void:
	var rows: PackedStringArray = [
		".....",
		"..#..",
		".....",
		".....",
	]
	var g := WalkGrid.from_ascii(rows)
	_check(not g.is_walkable(Vector2i(2, 1)), "célula bloqueada")
	# Diagonal que encosta na quina bloqueada não pode.
	_check(not g.can_step(Vector2i(1, 0), Vector2i(1, 1)), "sem cortar quina (1,0)->(2,1)")
	_check(not g.can_step(Vector2i(1, 2), Vector2i(1, -1)), "sem cortar quina (1,2)->(2,1)")
	_check(not g.can_step(Vector2i(1, 1), Vector2i(1, 1)), "sem cortar quina (1,1)->(2,2)")
	_check(g.can_step(Vector2i(0, 2), Vector2i(1, 1)), "diagonal livre longe do bloqueio")
	var p: Array[Vector2i] = _path(g, Vector2i(1, 1), Vector2i(3, 1))
	_check(not p.has(Vector2i(2, 1)) and p[p.size() - 1] == Vector2i(3, 1) and _steps_ok(g, p),
			"contorna o bloqueio: %s" % [p])
	# Parede com passagem só pela quina (diagonal entre dois bloqueios) deve ser fechada.
	var pinch: PackedStringArray = [
		"..#..",
		"..#..",
		"...#.",
		"...#.",
	]
	var g2 := WalkGrid.from_ascii(pinch)
	var p2: Array[Vector2i] = _path(g2, Vector2i(0, 0), Vector2i(4, 0))
	_check(p2[p2.size() - 1] != Vector2i(4, 0), "não passa espremido entre quinas: %s" % [p2])


func _test_unreachable_nearest() -> void:
	var rows: PackedStringArray = [
		"..........",
		"......###.",
		"......#.#.",
		"......###.",
		"..........",
	]
	var g := WalkGrid.from_ascii(rows)
	# Destino dentro da sala fechada: vai até a célula alcançável mais próxima dele.
	var p: Array[Vector2i] = _path(g, Vector2i(0, 2), Vector2i(7, 2))
	var end: Vector2i = p[p.size() - 1]
	_check(end == Vector2i(5, 2) and _steps_ok(g, p), "inalcançável -> mais próxima: %s" % [end])
	# Destino bloqueado: idem.
	var q: Array[Vector2i] = _path(g, Vector2i(0, 0), Vector2i(6, 1))
	var qe: Vector2i = q[q.size() - 1]
	_check((qe - Vector2i(6, 1)).length_squared() == 1, "destino bloqueado -> vizinho: %s" % [qe])
	# Início bloqueado: sem caminho.
	_check(_path(g, Vector2i(6, 1), Vector2i(0, 0)).is_empty(), "início bloqueado -> vazio")


func _test_max_steps() -> void:
	var rows: PackedStringArray = [".".repeat(60)]
	var g := WalkGrid.from_ascii(rows)
	var p: Array[Vector2i] = _path(g, Vector2i(0, 0), Vector2i(59, 0), 40)
	_check(p.size() == 41 and p[40] == Vector2i(40, 0), "longe demais: anda max_walk_cells na direção (%d)" % p.size())


func _test_determinism() -> void:
	var rows: PackedStringArray = [
		"............",
		"....#.......",
		"....#..##...",
		"....#...#...",
		"........#...",
		"............",
	]
	var g := WalkGrid.from_ascii(rows)
	var a: Array[Vector2i] = _path(g, Vector2i(0, 5), Vector2i(11, 0))
	var same: bool = true
	for i: int in range(20):
		var g2 := WalkGrid.from_ascii(rows)
		same = same and _path(g2, Vector2i(0, 5), Vector2i(11, 0)) == a
	_check(same and _steps_ok(g, a), "determinístico (mesma grade/pedido -> mesmo caminho)")
	_check(WalkGrid.from_ascii(rows).flags_hash() == g.flags_hash(), "grade determinística")
	# Empates simétricos resolvidos sempre igual.
	var o := WalkGrid.from_ascii(OPEN_10)
	_check(_path(o, Vector2i(0, 0), Vector2i(3, 0)) == _path(o, Vector2i(0, 0), Vector2i(3, 0)), "empate estável")


func _test_goal_radius() -> void:
	var g := WalkGrid.from_ascii(OPEN_10)
	var p: Array[Vector2i] = _path(g, Vector2i(0, 5), Vector2i(9, 5), 40, 3.0)
	var end: Vector2i = p[p.size() - 1]
	_check(end == Vector2i(6, 5), "alcance de interação: para a 3 células (%s)" % [end])


func _test_playback_timing() -> void:
	var pts := PackedVector3Array([Vector3(0.5, 0, 0.5), Vector3(1.5, 0, 0.5), Vector3(2.5, 0, 1.5)])
	var m := MovePath.create(pts, 1000, MS, 1.0, DIAG)
	_check(m.times == PackedInt32Array([0, 200, 480]), "tempos: reto 200, diagonal 280 (%s)" % [m.times])
	_check(m.sample(900.0).is_equal_approx(pts[0]), "antes do início = primeiro ponto")
	_check(m.sample(1100.0).is_equal_approx(Vector3(1.0, 0, 0.5)), "meio do passo reto")
	_check(m.sample(1340.0).is_equal_approx(Vector3(2.0, 0, 1.0)), "meio do passo diagonal")
	_check(m.sample(5000.0).is_equal_approx(pts[2]), "depois do fim = destino")
	_check(is_equal_approx(m.facing_at(1100.0), atan2(-1.0, 0.0)), "direção = passo (leste)")
	_check(is_equal_approx(m.facing_at(1300.0), MovePath.yaw_of(Vector3(1, 0, 1))), "direção diagonal")
	_check(m.is_moving_at(1479.0) and not m.is_moving_at(1480.0), "fim no tempo exato")
	var round_trip: MovePath = MovePath.from_state(m.to_state())
	_check(round_trip != null and round_trip.sample(1234.0).is_equal_approx(m.sample(1234.0)),
			"estado replicado reproduz o mesmo caminho")
	# Servidor x cliente com erro de relógio: diferença < 1 aresta de célula (e ~ velocidade × erro).
	var worst: float = 0.0
	for t: int in range(900, 1600, 7):
		var server_pos: Vector3 = m.sample(float(t))
		var client_pos: Vector3 = round_trip.sample(float(t) + CLOCK_ERROR_MSEC)
		worst = maxf(worst, server_pos.distance_to(client_pos))
	# Maior velocidade do caminho: diagonal (√2 m em MS × DIAG ms).
	var max_speed: float = maxf(1.0 / MS, sqrt(2.0) / (MS * DIAG))
	var bound: float = CLOCK_ERROR_MSEC * max_speed + EPS
	_check(worst < 1.0 and worst <= bound, "reprodução: erro %.3f m <= %.3f m (1 célula = 1 m)" % [worst, bound])


func _test_clock_sample() -> void:
	NetClock.reset()
	var now: float = NetClock.local_now_msec()
	# Ping mandado há 40 ms; servidor respondeu com relógio 100000 -> offset = 100000 + 20 - agora.
	NetClock.add_sample(now - 40.0, 100000.0)
	var expected: float = 100000.0 + 20.0 - now
	_check(NetClock.synced and absf(NetClock.offset_msec - expected) < 2.0,
			"offset do relógio: %.2f esperado %.2f" % [NetClock.offset_msec, expected])
	# Amostra pior (RTT maior) não substitui a melhor.
	NetClock.add_sample(NetClock.local_now_msec() - 300.0, 999999.0)
	_check(absf(NetClock.offset_msec - expected) < 2.0, "amostra de menor RTT vence")
	NetClock.reset()


func _test_real_map_and_mover() -> void:
	var packed: PackedScene = load(MAP_SCENE) as PackedScene
	var map_node: Node = packed.instantiate()
	add_child(map_node)
	var nav: RID = map_node.call(&"get_navigation_map")
	for i: int in range(NAV_SYNC_MAX_FRAMES):
		if WalkGrid.is_nav_synced(nav):
			break
		await get_tree().physics_frame
	_check(WalkGrid.is_nav_synced(nav), "navmesh sincronizou")
	var bounds: AABB = WalkGrid.navmesh_bounds(map_node)
	var g1: WalkGrid = WalkGrid.build_from_navmesh(map_node, Balance.cfg.cell_size)
	var g2: WalkGrid = WalkGrid.build_from_navmesh(map_node, Balance.cfg.cell_size)
	var ref: WalkGrid = WalkGrid.build(nav, bounds, Balance.cfg.cell_size)
	print("real map grid: size=%s cells=%d walkable=%d build=%d ms (referência closest_point: %d ms)" % [
			g1.size, g1.cell_count(), g1.walkable_count(), g1.build_msec, ref.build_msec])
	_check(g1.flags_hash() == g2.flags_hash(), "grade do mapa determinística")
	_check(g1.build_msec < MAX_BUILD_MSEC, "grade rápida (%d ms)" % g1.build_msec)
	# Mesma resposta que o NavigationServer3D (map_get_closest_point) célula a célula.
	var mismatch: int = 0
	for i: int in range(g1.cell_count()):
		var c: Vector2i = g1.cell_of_index(i)
		if g1.is_walkable(c) != ref.is_walkable(c):
			mismatch += 1
	_check(float(mismatch) <= MAX_MISMATCH_FRACTION * g1.walkable_count(),
			"rasterização = map_get_closest_point (%d células diferentes)" % mismatch)
	var spawn: Vector3 = map_node.call(&"get_spawn_point")
	var sc: Vector2i = g1.nearest_walkable(g1.world_to_cell(spawn), 4)
	_check(sc.x >= 0, "spawn na grade")
	# Todo passo do A* no mapa real fica sobre o navmesh (centro e ponto médio).
	var far: Array[Vector2i] = GridPathfinder.find_path(g1, sc, sc + Vector2i(30, -25), 40)
	var on_mesh: bool = far.size() > 1
	for i: int in range(far.size()):
		var w: Vector3 = g1.cell_to_world(far[i])
		on_mesh = on_mesh and _on_nav(nav, w)
		if i > 0:
			on_mesh = on_mesh and _on_nav(nav, (w + g1.cell_to_world(far[i - 1])) * 0.5)
	_check(on_mesh, "caminho real sobre o navmesh (%d células)" % far.size())
	await _test_mover(g1, g1.cell_to_world(sc))
	map_node.queue_free()


func _on_nav(nav: RID, p: Vector3) -> bool:
	var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, p)
	return Vector2(c.x - p.x, c.z - p.z).length() <= WalkGrid.ON_NAV_EPSILON


## GridMover no servidor: troca de caminho no meio do passo continua da próxima célula sem voltar.
func _test_mover(g: WalkGrid, start: Vector3) -> void:
	var was_server: bool = Net.is_server
	Net.is_server = true
	var e: NetEntity = (load(ENTITY_SCENE) as PackedScene).instantiate() as NetEntity
	e.server_setup(424242, NetEntity.KIND_NPC, "test", &"", &"test", start)
	add_child(e)
	var mover: GridMover = e.server_ensure_mover(g, MS)
	_check(mover.move_to(start + Vector3(8, 0, 0)), "move_to aceito")
	var first: MovePath = mover.get_move_path()
	await get_tree().create_timer(0.3).timeout
	mover.tick()
	var now: float = NetClock.server_now_msec()
	var before: Vector3 = first.sample(now)
	_check(mover.move_to(start + Vector3(0, 0, 8)), "novo pedido no meio do caminho aceito")
	var second: MovePath = mover.get_move_path()
	var k: int = first.segment_at(now)
	_check(second.points[0].is_equal_approx(first.points[k]) and second.points[1].is_equal_approx(first.points[k + 1])
			and second.start_msec == first.start_msec + first.times[k], "continua do passo atual")
	_check(second.sample(now).distance_to(before) < 0.01, "sem teleporte na troca (%.4f)" % second.sample(now).distance_to(before))
	var yaw_ok: bool = true
	for t: int in range(int(now), second.end_msec(), 10):
		var y: float = second.facing_at(float(t))
		var r: float = fposmod(y, TAU / 8.0)
		yaw_ok = yaw_ok and (is_equal_approx(r, 0.0) or is_equal_approx(r, TAU / 8.0))
	_check(yaw_ok, "direção sempre uma das 8")
	mover.stop()
	var stopped: MovePath = mover.get_move_path()
	_check(stopped.end_msec() - int(NetClock.server_now_msec()) <= roundi(MS * DIAG) + 1, "stop termina na próxima célula")
	var end: Vector3 = stopped.destination()
	var frac := Vector2(fposmod(end.x, g.cell_size), fposmod(end.z, g.cell_size))
	_check(frac.is_equal_approx(Vector2(g.cell_size, g.cell_size) * 0.5), "parado no centro da célula")
	e.queue_free()
	Net.is_server = was_server
