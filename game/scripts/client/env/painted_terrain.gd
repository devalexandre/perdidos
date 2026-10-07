class_name PaintedTerrain
extends RefCounted
## Terreno pintado (GDD §17.0.A): malha em grade com relevo suave + mapa de mistura (splat) pintado
## por código. Usado pelos construtores de mapa/lookdev em tempo de build.
##   var hf := func(x, z): return ...            # altura
##   var mesh := PaintedTerrain.build_mesh(Rect2(-40,-40,80,80), 1.0, hf)
##   var splat := PaintedTerrain.paint_splat(Rect2(...), 4, func(x, z): return Color(dirt, cobble, sand, rock))
##   var mat := PaintedTerrain.material(splat_tex, rect)
## Canais do splat: R = terra/trilha, G = calçamento, B = areia, A = rocha (fundo = grama).

const BASE_MATERIAL: String = "res://assets/environment/painted/materials/mat_terrain.tres"


## Grade de step m na área; normais suavizadas pela própria função de altura.
static func build_mesh(area: Rect2, step: float, height: Callable) -> ArrayMesh:
	var nx := int(ceil(area.size.x / step))
	var nz := int(ceil(area.size.y / step))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e := step * 0.5
	for iz in nz + 1:
		for ix in nx + 1:
			var x := area.position.x + ix * step
			var z := area.position.y + iz * step
			var y: float = height.call(x, z)
			var dx: float = float(height.call(x + e, z)) - float(height.call(x - e, z))
			var dz: float = float(height.call(x, z + e)) - float(height.call(x, z - e))
			st.set_normal(Vector3(-dx, 2.0 * e, -dz).normalized())
			st.set_uv(Vector2(float(ix) / nx, float(iz) / nz))
			st.add_vertex(Vector3(x, y, z))
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	return st.commit()


## Colisão de altura (camada 1 = chão clicável) centrada na área.
static func build_collision(area: Rect2, step: float, height: Callable) -> StaticBody3D:
	var nx := int(ceil(area.size.x / step)) + 1
	var nz := int(ceil(area.size.y / step)) + 1
	var data := PackedFloat32Array()
	data.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			data[iz * nx + ix] = height.call(area.position.x + ix * step, area.position.y + iz * step)
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = data
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, 1.0, step)
	cs.position = Vector3(area.get_center().x, 0.0, area.get_center().y)
	body.add_child(cs)
	return body


## Pinta o splat (px_per_m pixels por metro). fn(x, z) -> Color(r=terra, g=calçamento, b=areia, a=rocha).
static func paint_splat(area: Rect2, px_per_m: int, fn: Callable) -> Image:
	var w := int(area.size.x * px_per_m)
	var h := int(area.size.y * px_per_m)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for py in h:
		for px in w:
			var x := area.position.x + (px + 0.5) / px_per_m
			var z := area.position.y + (py + 0.5) / px_per_m
			var c: Color = fn.call(x, z)
			img.set_pixel(px, py, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1), clampf(c.a, 0, 1)))
	return img


## Cópia do material de terreno do kit usando o splat em coordenadas de mundo.
static func material(splat: Texture2D, area: Rect2) -> ShaderMaterial:
	var m: ShaderMaterial = (load(BASE_MATERIAL) as ShaderMaterial).duplicate()
	m.set_shader_parameter(&"splat_source", 2)
	m.set_shader_parameter(&"splat_map", splat)
	m.set_shader_parameter(&"splat_origin", area.position)
	m.set_shader_parameter(&"splat_size", area.size)
	return m


## Distância de (x, z) a uma polilinha (trilhas). Retorna a menor distância.
static func dist_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p))
	return best
