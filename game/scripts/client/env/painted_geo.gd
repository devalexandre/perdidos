class_name PaintedGeo
extends RefCounted
## Geometria do kit de cenário pintado (GDD §17.0.A): árvores, arbustos, capim, props.
## Tudo gerado por código com SurfaceTool, com:
##  - cor de vértice RGB = oclusão pintada (base/interior mais escuros, pontas claras);
##  - cor de vértice A = peso do vento (0 no chão/tronco, 1 nas pontas) — lido por env_foliage.gdshader;
##  - normais "esféricas" nas copas (a partir do centro da copa) para sombreamento macio de volume.
## Usado por tools/art/env_kit/build_kit.gd (gera os .res) — não precisa rodar em tempo de jogo.

const UP := Vector3.UP


class Builder:
	var st := SurfaceTool.new()
	var tris: int = 0

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func vert(p: Vector3, n: Vector3, uv: Vector2, c: Color) -> void:
		st.set_normal(n)
		st.set_uv(uv)
		st.set_color(c)
		st.add_vertex(p)

	func tri(a: Array, b: Array, c: Array) -> void:
		# Cada vértice: [pos, normal, uv, cor]. Ordem corrigida automaticamente para a face da frente
		# ficar do lado das normais informadas (Godot: frente = sentido horário visto de frente).
		var n: Vector3 = a[1] + b[1] + c[1]
		if ((b[0] as Vector3) - (a[0] as Vector3)).cross((c[0] as Vector3) - (a[0] as Vector3)).dot(n) > 0.0:
			var t: Array = b
			b = c
			c = t
		vert(a[0], a[1], a[2], a[3])
		vert(b[0], b[1], b[2], b[3])
		vert(c[0], c[1], c[2], c[3])
		tris += 1

	func quad(a: Array, b: Array, c: Array, d: Array) -> void:
		tri(a, b, c)
		tri(a, c, d)

	func commit_to(mesh: ArrayMesh, mat: Material) -> void:
		if tris == 0:
			return
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


static func basis_from_axis(axis: Vector3) -> Basis:
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Cilindro afilado de a até b (tronco, galho, poste). Vento cresce de wind0 a wind1.
static func cylinder(bl: Builder, a: Vector3, b: Vector3, r0: float, r1: float, segs: int,
		ao0: float, ao1: float, wind0: float, wind1: float, u_tiles: float = 1.0, v_per_m: float = 0.5,
		cap_top: bool = false) -> void:
	var bs := basis_from_axis(b - a)
	var length := a.distance_to(b)
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var d0 := bs * Vector3(cos(t0 * TAU), 0.0, sin(t0 * TAU))
		var d1 := bs * Vector3(cos(t1 * TAU), 0.0, sin(t1 * TAU))
		var c0 := Color(ao0, ao0, ao0, wind0)
		var c1 := Color(ao1, ao1, ao1, wind1)
		var v1 := length * v_per_m
		bl.quad([a + d0 * r0, d0, Vector2(t0 * u_tiles, v1), c0], [b + d0 * r1, d0, Vector2(t0 * u_tiles, 0.0), c1],
				[b + d1 * r1, d1, Vector2(t1 * u_tiles, 0.0), c1], [a + d1 * r0, d1, Vector2(t1 * u_tiles, v1), c0])
		if cap_top:
			var n := bs.y
			bl.tri([b, n, Vector2(0.5, 0.5), c1], [b + d1 * r1, n, Vector2(0.5, 0.5) + Vector2(d1.x, d1.z) * 0.5, c1],
					[b + d0 * r1, n, Vector2(0.5, 0.5) + Vector2(d0.x, d0.z) * 0.5, c1])


## "Saia" de pinheiro: cone com borda serrilhada e caída. Normais puxadas para fora a partir de
## sphere_center (volume macio). Base (y0) mais escura por baixo; pontas claras.
static func conifer_skirt(bl: Builder, center: Vector3, y0: float, height: float, radius: float, segs: int,
		rng: RandomNumberGenerator, sphere_center: Vector3, tree_h: float, v_per_m: float = 0.55) -> void:
	# anéis: topo (quase ponta), meio (barriga convexa), borda serrilhada e caída, fundo recolhido
	var rings: Array = []
	var ring_def := [
		[0.10, 1.00, 0.0],   # raio relativo, altura relativa, serrilhado
		[0.62, 0.55, 0.15],
		[1.00, 0.06, 1.0],
		[0.55, -0.02, 0.2],
	]
	var jag: Array[float] = []
	var droop: Array[float] = []
	for s in segs + 1:
		var k := s % segs
		if jag.size() < segs:
			jag.append((1.0 if k % 2 == 0 else 0.72) * rng.randf_range(0.9, 1.1))
			droop.append((0.0 if k % 2 == 0 else 0.18) + rng.randf_range(0.0, 0.12))
	for rd: Array in ring_def:
		var ring: Array = []
		for s in segs + 1:
			var k := s % segs
			var ang := float(s) / segs * TAU
			var j: float = lerpf(1.0, jag[k], rd[2])
			var r: float = radius * float(rd[0]) * j
			var y: float = y0 + height * float(rd[1]) + (droop[k] * height * float(rd[2]) if rd[2] > 0.5 else 0.0)
			if rd[2] > 0.5:
				y -= (jag[k] - 0.72) * height * 0.35 # pontas compridas caem mais
			var p := center + Vector3(cos(ang) * r, y - center.y, sin(ang) * r)
			p.y = y
			ring.append(p)
		rings.append(ring)
	for ri in rings.size() - 1:
		var ra: Array = rings[ri]
		var rb: Array = rings[ri + 1]
		for s in segs:
			var pts: Array = [ra[s], rb[s], rb[s + 1], ra[s + 1]]
			var verts: Array = []
			for q in 4:
				var p: Vector3 = pts[q]
				var su := float(s + (1 if q >= 2 else 0)) / segs
				var radial := Vector3(p.x - center.x, 0.0, p.z - center.z)
				var n := (p - sphere_center).normalized().lerp(radial.normalized() + UP * 0.6, 0.35).normalized()
				var under := ri == 2
				var h_rel := clampf((p.y - y0) / maxf(height, 0.01), 0.0, 1.0)
				var ao := lerpf(0.42, 1.08, pow(h_rel, 0.7)) * lerpf(0.75, 1.05, clampf(p.y / tree_h, 0.0, 1.0))
				if under:
					ao *= 0.45
				var wind := clampf(p.y / tree_h, 0.0, 1.0) * clampf(radial.length() / maxf(radius, 0.01) + 0.2, 0.0, 1.0)
				var slant := (1.0 - float(ring_def[ri + (1 if q == 1 or q == 2 else 0)][1])) * height
				var uv := Vector2(su * maxf(2.0, roundf(radius * 2.2)), (slant + y0) * v_per_m)
				verts.append([p, n, uv, Color(ao, ao, ao, wind)])
			bl.quad(verts[0], verts[1], verts[2], verts[3])


## Blob de copa (esfera deformada). Normais misturadas com a direção a partir de crown_center.
static func blob(bl: Builder, c: Vector3, radius: float, squash: Vector3, rng: RandomNumberGenerator,
		crown_center: Vector3, crown_bottom: float, crown_top: float, tree_h: float,
		rings: int = 7, segs: int = 11, uv_scale: float = 0.45) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 1.3
	var grid: Array = []
	for r in rings + 1:
		var row: Array = []
		var phi := float(r) / rings * PI
		for s in segs + 1:
			var th := float(s % segs) / segs * TAU
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var bump := 1.0 + noise.get_noise_3dv(d * 2.0) * 0.22
			var p := c + d * squash * radius * bump
			var n := d.lerp((p - crown_center).normalized(), 0.65).normalized()
			var h_rel := clampf((p.y - crown_bottom) / maxf(crown_top - crown_bottom, 0.01), 0.0, 1.0)
			var outward := clampf((p - crown_center).normalized().dot(d) * 0.5 + 0.5, 0.0, 1.0)
			var ao := lerpf(0.42, 1.05, pow(h_rel, 0.8)) * lerpf(0.7, 1.0, outward)
			var wind := clampf(p.y / tree_h, 0.2, 1.0)
			var uv := Vector2(float(s) / segs * TAU * radius * uv_scale, phi * radius * uv_scale)
			row.append([p, n, uv, Color(ao, ao, ao, wind)])
		grid.append(row)
	for r in rings:
		for s in segs:
			bl.quad(grid[r][s], grid[r][s + 1], grid[r + 1][s + 1], grid[r + 1][s])


## Card (quad) de folhagem virado para "out", com normal esférica a partir de sphere_center.
static func card(bl: Builder, p: Vector3, out: Vector3, size: float, spin: float,
		sphere_center: Vector3, ao: float, wind: float, tilt_up: float = 0.35) -> void:
	var f := (out.normalized() + UP * tilt_up).normalized()
	var bs := basis_from_axis(f)
	var right := bs.x.rotated(f, spin)
	var up := f.cross(right).normalized() * -1.0
	var half := size * 0.5
	var n := (p - sphere_center).normalized().lerp(f, 0.3).normalized()
	var c_top := Color(ao, ao, ao, wind)
	var c_bot := Color(ao * 0.8, ao * 0.8, ao * 0.8, wind * 0.8)
	bl.quad([p - right * half + up * half, n, Vector2(0, 0), c_top],
			[p + right * half + up * half, n, Vector2(1, 0), c_top],
			[p + right * half - up * half, n, Vector2(1, 1), c_bot],
			[p - right * half - up * half, n, Vector2(0, 1), c_bot])


## Tufo em X (capim, flores, cogumelos): n quads cruzados com a base no chão.
static func tuft(bl: Builder, base: Vector3, width: float, height: float, planes: int, yaw: float,
		ao_base: float = 0.7, normal_up: float = 0.8) -> void:
	for i in planes:
		var a := yaw + PI * float(i) / planes
		var dx := Vector3(cos(a), 0.0, sin(a)) * width * 0.5
		var facing := Vector3(-sin(a), 0.0, cos(a))
		var n := facing.lerp(UP, normal_up).normalized()
		var c0 := Color(ao_base, ao_base, ao_base, 0.0)
		var c1 := Color(1.0, 1.0, 1.0, 1.0)
		var top := UP * height
		bl.quad([base - dx + top, n, Vector2(0, 0), c1], [base + dx + top, n, Vector2(1, 0), c1],
				[base + dx, n, Vector2(1, 1), c0], [base - dx, n, Vector2(0, 1), c0])


## Caixa com UV em metros por face (textura tileável), oclusão mais escura embaixo.
static func box(bl: Builder, center: Vector3, size: Vector3, ao_bottom: float = 0.6, ao_top: float = 1.0,
		basis: Basis = Basis.IDENTITY, tint: float = 1.0) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var fc := n * h
		var ue := u * h
		var ve := v * h
		var su := absf(u.dot(size))
		var sv := absf(v.dot(size))
		var corners := [fc - ue + ve, fc + ue + ve, fc + ue - ve, fc - ue - ve]
		var uvs := [Vector2(0, 0), Vector2(su, 0), Vector2(su, sv), Vector2(0, sv)]
		var vs: Array = []
		for k in 4:
			var p: Vector3 = corners[k]
			var t := clampf(p.y / size.y + 0.5, 0.0, 1.0)
			var ao := lerpf(ao_bottom, ao_top, t) * tint
			vs.append([center + basis * p, basis * n, uvs[k] + Vector2(center.x + center.z, center.y) * 0.37,
					Color(ao, ao, ao, 0.0)])
		bl.quad(vs[0], vs[1], vs[2], vs[3])


## Sólido de revolução (barril, toco): perfil [[y, r, ao], ...] em volta de "base".
static func lathe(bl: Builder, base: Vector3, profile: Array, segs: int, u_tiles: float, v_per_m: float,
		cap_top: bool = true, cap_ao: float = 0.9, axis_basis: Basis = Basis.IDENTITY) -> void:
	for i in profile.size() - 1:
		var p0: Array = profile[i]
		var p1: Array = profile[i + 1]
		var dr := float(p1[1]) - float(p0[1])
		var dy := float(p1[0]) - float(p0[0])
		for s in segs:
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var d0 := Vector3(cos(t0 * TAU), 0.0, sin(t0 * TAU))
			var d1 := Vector3(cos(t1 * TAU), 0.0, sin(t1 * TAU))
			var n0 := (d0 * dy - UP * dr).normalized()
			var n1 := (d1 * dy - UP * dr).normalized()
			var a0 := float(p0[2])
			var a1 := float(p1[2])
			bl.quad(
				[base + axis_basis * (d0 * float(p0[1]) + UP * float(p0[0])), axis_basis * n0, Vector2(t0 * u_tiles, -float(p0[0]) * v_per_m), Color(a0, a0, a0, 0)],
				[base + axis_basis * (d1 * float(p0[1]) + UP * float(p0[0])), axis_basis * n1, Vector2(t1 * u_tiles, -float(p0[0]) * v_per_m), Color(a0, a0, a0, 0)],
				[base + axis_basis * (d1 * float(p1[1]) + UP * float(p1[0])), axis_basis * n1, Vector2(t1 * u_tiles, -float(p1[0]) * v_per_m), Color(a1, a1, a1, 0)],
				[base + axis_basis * (d0 * float(p1[1]) + UP * float(p1[0])), axis_basis * n0, Vector2(t0 * u_tiles, -float(p1[0]) * v_per_m), Color(a1, a1, a1, 0)])
	if cap_top:
		var last: Array = profile[profile.size() - 1]
		var y := float(last[0])
		var r := float(last[1])
		var c := Color(cap_ao, cap_ao, cap_ao, 0)
		for s in segs:
			var t0 := float(s) / segs * TAU
			var t1 := float(s + 1) / segs * TAU
			var e0 := Vector3(cos(t0), 0, sin(t0)) * r
			var e1 := Vector3(cos(t1), 0, sin(t1)) * r
			bl.tri([base + axis_basis * (UP * y), axis_basis * UP, Vector2(0.5, 0.5), c],
					[base + axis_basis * (e1 + UP * y), axis_basis * UP, Vector2(0.5 + e1.x, 0.5 + e1.z), c],
					[base + axis_basis * (e0 + UP * y), axis_basis * UP, Vector2(0.5 + e0.x, 0.5 + e0.z), c])


## Pedra: icosfera deformada e achatada, com facetas suaves (estilo pintado).
static func rock(bl: Builder, center: Vector3, size: Vector3, rng: RandomNumberGenerator, subdiv: int = 2) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 10 + subdiv * 2
	sphere.rings = 6 + subdiv
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 1.6
	var moved := PackedVector3Array()
	moved.resize(verts.size())
	for i in verts.size():
		var d := verts[i].normalized()
		var k := 1.0 + noise.get_noise_3dv(d * 1.5) * 0.28
		var p := d * 0.5 * k * size
		p.y = maxf(p.y, -size.y * 0.15) # base achatada, enterrada
		moved[i] = p
	for t in idx.size() / 3:
		var ia := idx[t * 3]
		var ib := idx[t * 3 + 1]
		var ic := idx[t * 3 + 2]
		var pa := moved[ia]
		var pb := moved[ib]
		var pc := moved[ic]
		var fn := (pb - pa).cross(pc - pa).normalized()
		if fn.dot((pa + pb + pc) / 3.0) < 0.0:
			fn = -fn
		var arr: Array = []
		for p: Vector3 in [pa, pb, pc]:
			var sn := p.normalized()
			var n := sn.lerp(fn, 0.55).normalized()
			var ao := lerpf(0.55, 1.05, clampf(p.y / (size.y * 0.5) * 0.5 + 0.5, 0.0, 1.0))
			arr.append([center + p, n, Vector2(p.x + p.z, p.y) * 0.5, Color(ao, ao, ao, 0)])
		bl.tri(arr[0], arr[2], arr[1])


## Folha de palmeira: ráquis curvada com folíolos em pares (triângulos finos). fan = leque (buriti).
static func palm_frond(bl: Builder, base: Vector3, dir: Vector3, length: float, width: float, droop: float,
		segs: int, fan: bool, sphere_center: Vector3, tree_h: float) -> void:
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	var side := Vector3(-d.z, 0.0, d.x)
	var prev := base
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var p0 := base + d * length * t0 + Vector3.UP * (sin(t0 * PI * 0.6) * length * 0.25 - droop * t0 * t0 * length)
		var p1 := base + d * length * t1 + Vector3.UP * (sin(t1 * PI * 0.6) * length * 0.25 - droop * t1 * t1 * length)
		var w := width * (sin(t1 * PI) * 0.85 + 0.15) * (1.4 if fan else 1.0)
		var tip_back := (p1 - p0) * (0.2 if fan else 1.4)
		for s: float in [-1.0, 1.0]:
			var leaf_tip := p1 + side * s * w + tip_back + Vector3.DOWN * w * (0.15 if fan else 0.5)
			var n := (Vector3.UP + side * s * 0.25 + (p0 - sphere_center).normalized() * 0.4).normalized()
			var ao0 := lerpf(0.6, 1.0, t0)
			var ao1 := lerpf(0.65, 1.05, t1)
			bl.tri([p0, n, Vector2(0.5, t0), Color(ao0, ao0, ao0, clampf(p0.y / tree_h, 0.3, 1.0))],
					[p1, n, Vector2(0.5, t1), Color(ao1, ao1, ao1, clampf(p1.y / tree_h, 0.3, 1.0))],
					[leaf_tip, n, Vector2(0.5 + s * 0.5, t1), Color(ao1, ao1, ao1, 1.0)])
			bl.tri([p0, -n, Vector2(0.5, t0), Color(ao0 * 0.8, ao0 * 0.8, ao0 * 0.8, clampf(p0.y / tree_h, 0.3, 1.0))],
					[leaf_tip, -n, Vector2(0.5 + s * 0.5, t1), Color(ao1 * 0.8, ao1 * 0.8, ao1 * 0.8, 1.0)],
					[p1, -n, Vector2(0.5, t1), Color(ao1 * 0.8, ao1 * 0.8, ao1 * 0.8, clampf(p1.y / tree_h, 0.3, 1.0))])
		prev = p1


## Tronco curvado (palmeira): cilindros encadeados ao longo de uma curva suave.
static func curved_trunk(bl: Builder, base: Vector3, top: Vector3, bend: Vector3, r0: float, r1: float, segs: int,
		ring_segs: int = 8) -> void:
	var prev := base
	for i in segs:
		var t := float(i + 1) / segs
		var p := base.lerp(top, t) + bend * sin(t * PI)
		var ra := lerpf(r0, r1, float(i) / segs)
		var rb := lerpf(r0, r1, t)
		cylinder(bl, prev, p, ra, rb, ring_segs, lerpf(0.5, 0.9, float(i) / segs), lerpf(0.5, 0.9, t),
				float(i) / segs * 0.2, t * 0.2, 2.0, 1.0)
		prev = p
