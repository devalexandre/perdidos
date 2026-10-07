extends RefCounted
## Relevo e chão pintado ORGÂNICOS do Campo de Treino (revisão 5, GDD §17.0.A).
## - height(x, z): 0 em todo o chão andável; cristas (entre as zonas) e morros da borda sobem; lagoas e o rio descem.
##   As cristas/lagoas/rio são obstruções no navmesh (registradas pelo construtor), então o jogo continua plano
##   onde se anda e o relevo só aparece onde não se pisa.
## - paint(): 3 mapas de mistura (splat_a/b/c do env_terrain_world.gdshader) com manchas de contorno irregular
##   (ruído), trilhas curvas e margens de areia — nada de disco/retângulo visível.
## - build_mesh(): malha única do terreno com normais do próprio grid.

## Camada de cada material antigo de chão: [imagem 0..2, canal 0..3, força]
const LAYER := {
	"dirt": [0, 0, 1.0], "cobble": [0, 1, 1.0], "stone_paving": [0, 1, 1.0], "paving": [0, 1, 1.0],
	"sand": [0, 2, 1.0], "desert_sand": [0, 2, 1.0], "rock": [0, 3, 1.0],
	"snow": [1, 0, 1.0], "cerrado": [1, 1, 1.0], "dry_meadow": [1, 1, 0.8], "jungle_floor": [1, 2, 1.0],
	"moss_gravel": [2, 1, 0.9], "gravel": [1, 3, 1.0],
	"red_earth": [2, 0, 1.0], "lush_grass": [2, 1, 1.0], "birch_meadow": [2, 1, 0.55], "heather": [2, 2, 1.0],
}

var noise := FastNoiseLite.new()
var rim_r: float = 93.0
## [PackedVector2Array pontos, pico (m), largura (m), Rect2 bbox]
var ridges: Array = []
## [Vector2 centro, raio, profundidade]
var ponds: Array = []
var stream := PackedVector2Array()
## trechos do rio sem mergulho (vau seco): [Vector2 centro, raio]
var stream_dry: Array = []
## manchas: [material, Vector2 centro, raio, wobble]; faixas: [material, a, b, largura]; fitas: [material, pts, largura]
var shapes: Array = []
var strips: Array = []
var ribbons: Array = []
## Curvatura das trilhas (m, amplitude máxima no meio do trecho).
var curve_amp: float = 0.7


func _init() -> void:
	noise.seed = 5207
	noise.frequency = 0.05
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


# ------------------------------------------------------------------ relevo

func add_ridge(pts: PackedVector2Array, peak: float, width: float) -> void:
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	ridges.append([pts, peak, width, box.grow(width + 1.0)])


static func _poly_dist(p: Vector2, pts: PackedVector2Array) -> Vector2:
	## .x = distância, .y = parâmetro ao longo (0..1 da polilinha inteira)
	var best := INF
	var best_t := 0.0
	var total := 0.0
	var acc: Array[float] = []
	for i in pts.size() - 1:
		acc.append(total)
		total += pts[i].distance_to(pts[i + 1])
	for i in pts.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		var d := q.distance_to(p)
		if d < best:
			best = d
			best_t = (acc[i] + pts[i].distance_to(q)) / maxf(total, 0.001)
	return Vector2(best, best_t)


func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var r := p.length()
	var h := 0.0
	if r > rim_r:
		var t := smoothstep(rim_r, rim_r + 22.0, r)
		h = t * (7.0 + 5.0 * noise.get_noise_2d(x * 0.6, z * 0.6)) + t * t * 3.0
	for rd: Array in ridges:
		if not (rd[3] as Rect2).has_point(p):
			continue
		var dt := _poly_dist(p, rd[0])
		var w: float = rd[2]
		if dt.x > w:
			continue
		var ramp := smoothstep(0.0, 0.18, dt.y)
		var pk: float = float(rd[1]) * (0.75 + 0.45 * noise.get_noise_2d(x * 1.7 + 40.0, z * 1.7))
		var prof := 1.0 - smoothstep(w * 0.12, w, dt.x)
		prof = prof * prof * (3.0 - 2.0 * prof)
		h = maxf(h, pk * prof * ramp)
	for pd: Array in ponds:
		var c: Vector2 = pd[0]
		var pr: float = pd[1]
		var d := p.distance_to(c)
		if d > pr * 1.5:
			continue
		var ang := atan2(z - c.y, x - c.x)
		# o contorno só ENCOLHE (fator ≥ 1): a margem nunca passa da obstrução do navmesh
		var nn := noise.get_noise_2d(c.x * 7.0 + cos(ang) * 3.0, c.y * 7.0 + sin(ang) * 3.0)
		var dw := d * (1.0 + 0.4 * (0.5 + 0.5 * nn) + 0.06 * (0.5 + 0.5 * noise.get_noise_2d(x * 3.0, z * 3.0)))
		h -= float(pd[2]) * (1.0 - smoothstep(pr * 0.45, pr * 1.02, dw))
	if stream.size() > 1:
		var dry := false
		for sd: Array in stream_dry:
			if p.distance_to(sd[0]) < float(sd[1]):
				dry = true
		if not dry:
			var ds := _poly_dist(p, stream).x
			if ds < 1.7:
				h -= 0.9 * (1.0 - smoothstep(0.55, 1.5, ds + noise.get_noise_2d(x * 3.0, z * 3.0) * 0.12))
	return h


## Malha do terreno (grade step m) com normais pelas diferenças do próprio grid.
func build_mesh(area: Rect2, step: float) -> ArrayMesh:
	var nx := int(ceil(area.size.x / step)) + 1
	var nz := int(ceil(area.size.y / step)) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			hs[iz * nx + ix] = height(area.position.x + ix * step, area.position.y + iz * step)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	uvs.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var i := iz * nx + ix
			var hl := hs[iz * nx + maxi(ix - 1, 0)]
			var hr := hs[iz * nx + mini(ix + 1, nx - 1)]
			var hd := hs[maxi(iz - 1, 0) * nx + ix]
			var hu := hs[mini(iz + 1, nz - 1) * nx + ix]
			verts[i] = Vector3(area.position.x + ix * step, hs[i], area.position.y + iz * step)
			norms[i] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			uvs[i] = Vector2(float(ix) / (nx - 1), float(iz) / (nz - 1))
	var idx := PackedInt32Array()
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return im.get_mesh()


# ------------------------------------------------------------------ pintura (splat)

var _data: Array = []
var _w: int = 0
var _h: int = 0
var _area: Rect2
var _ppm: float = 2.0


func _put(px: int, py: int, layer: Array, v: float) -> void:
	if px < 0 or py < 0 or px >= _w or py >= _h or v <= 0.0:
		return
	var buf: PackedByteArray = _data[layer[0]]
	var i := (py * _w + px) * 4 + int(layer[1])
	var nv := int(clampf(v * float(layer[2]), 0.0, 1.0) * 255.0)
	if nv > buf[i]:
		buf[i] = nv
		_data[layer[0]] = buf


func _paint_fn(bbox: Rect2, layer: Array, fn: Callable) -> void:
	var x0 := int(floor((bbox.position.x - _area.position.x) * _ppm))
	var y0 := int(floor((bbox.position.y - _area.position.y) * _ppm))
	var x1 := int(ceil((bbox.end.x - _area.position.x) * _ppm))
	var y1 := int(ceil((bbox.end.y - _area.position.y) * _ppm))
	var buf: PackedByteArray = _data[layer[0]]
	var ch: int = layer[1]
	var k: float = layer[2]
	for py in range(maxi(y0, 0), mini(y1, _h)):
		for px in range(maxi(x0, 0), mini(x1, _w)):
			var x := _area.position.x + (px + 0.5) / _ppm
			var z := _area.position.y + (py + 0.5) / _ppm
			var v: float = fn.call(x, z)
			if v <= 0.0:
				continue
			var i := (py * _w + px) * 4 + ch
			var nv := int(clampf(v * k, 0.0, 1.0) * 255.0)
			if nv > buf[i]:
				buf[i] = nv
	_data[layer[0]] = buf


func paint(area: Rect2, ppm: float) -> Array[Image]:
	_area = area
	_ppm = ppm
	_w = int(area.size.x * ppm)
	_h = int(area.size.y * ppm)
	_data = []
	for i in 3:
		var b := PackedByteArray()
		b.resize(_w * _h * 4)
		b.fill(0)
		_data.append(b)
	for s: Array in shapes:
		if not LAYER.has(s[0]):
			continue
		var c: Vector2 = s[1]
		var r: float = s[2]
		var wob: float = s[3]
		var fn := func(x: float, z: float) -> float:
			var d := Vector2(x, z).distance_to(c)
			var edge := r * (1.0 + wob * noise.get_noise_2d(x * 1.3, z * 1.3) * 2.2)
			return 1.0 - smoothstep(edge * 0.78, edge * 1.04, d)
		_paint_fn(Rect2(c - Vector2.ONE * r * 1.5, Vector2.ONE * r * 3.0), LAYER[s[0]], fn)
		if s[0] == "moss_gravel": # cascalho + musgo
			_paint_fn(Rect2(c - Vector2.ONE * r * 1.5, Vector2.ONE * r * 3.0), [1, 3, 0.55], fn)
	for s: Array in strips:
		if not LAYER.has(s[0]):
			continue
		var a: Vector2 = s[1]
		var b: Vector2 = s[2]
		var hw: float = float(s[3]) * 0.5
		var box := Rect2(a, Vector2.ZERO).expand(b).grow(hw + 3.0 + curve_amp * 4.0)
		var fn := func(x: float, z: float) -> float:
			var p := Vector2(x, z)
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			var dir := (b - a).normalized()
			var side := signf(dir.cross(p - q)) * p.distance_to(q)
			# curva suave ao longo do caminho (some nas pontas, que encostam nas outras trilhas/praças)
			var tt := clampf(a.distance_to(q) / maxf(a.distance_to(b), 0.01), 0.0, 1.0)
			var bend := sin(tt * PI) * curve_amp * noise.get_noise_2d(a.x * 3.1 + b.y, a.y * 3.1 + b.x)
			var off := noise.get_noise_2d(q.x * 0.9, q.y * 0.9) * 0.9 + bend * 4.0
			var d := absf(side - off)
			# pontas arredondadas: a distância ao segmento já é redonda nas pontas
			var edge := hw + 0.25 * noise.get_noise_2d(x * 4.0, z * 4.0)
			return 1.0 - smoothstep(edge * 0.6, edge + 0.55, d)
		_paint_fn(box, LAYER[s[0]], fn)
	for s: Array in ribbons:
		if not LAYER.has(s[0]):
			continue
		var pts: PackedVector2Array = s[1]
		var hw: float = float(s[2]) * 0.5
		var box := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			box = box.expand(p)
		var fn := func(x: float, z: float) -> float:
			var d := _poly_dist(Vector2(x, z), pts).x + noise.get_noise_2d(x * 2.0, z * 2.0) * 0.5
			return 1.0 - smoothstep(hw * 0.7, hw + 0.6, d)
		_paint_fn(box.grow(hw + 2.0), LAYER[s[0]], fn)
	# rocha nas cristas (a encosta íngreme vira rocha sozinha no shader)
	for rd: Array in ridges:
		var pts: PackedVector2Array = rd[0]
		var w: float = rd[2]
		var fn := func(x: float, z: float) -> float:
			var dt := _poly_dist(Vector2(x, z), pts)
			var n := noise.get_noise_2d(x * 1.1, z * 1.1)
			return (1.0 - smoothstep(w * 0.25, w * 0.75, dt.x + n * 1.2)) * smoothstep(0.05, 0.25, dt.y)
		_paint_fn(rd[3], [0, 3, 0.85], fn)
	var out: Array[Image] = []
	for i in 3:
		out.append(Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, _data[i]))
	return out
