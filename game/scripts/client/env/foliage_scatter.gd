class_name FoliageScatter
extends Node3D
## Espalhamento de capim/flores/cogumelos/pedrinhas por MultiMesh (GDD §17.0.A).
##
## Uso em construtores de mapa (tempo de build, determinístico):
##   var node := FoliageScatter.new(); node.name = "Foliage"; decor.add_child(node)
##   node.add_layer(mesh, Rect2(-30,-30,60,60), 1.2, rng, accept, height)
## Cada camada vira MultiMeshInstance3D por pedaço (chunk_size m) — culling por pedaço, 1 draw call
## por pedaço visível. As instâncias são embaralhadas: o preset de qualidade reduz a densidade só
## mudando visible_instance_count (EnvQuality "foliage_density") e corta a distância
## (visibility_range_end = "foliage_distance").

## Lado (m) de cada pedaço de MultiMesh.
@export var chunk_size: float = 16.0


## Metadado do MultiMesh com as instâncias (12 floats do Transform3D + semente + tinta RGB = 16 cada). O servidor de
## renderização "dummy" (--headless, onde os construtores rodam) não guarda o buffer do MultiMesh, então
## os dados vão no metadado e o MultiMesh é preenchido aqui, em tempo de jogo.
const META_INSTANCES: StringName = &"foliage_instances"
const FLOATS_PER_INSTANCE: int = 16


func _ready() -> void:
	for n: Node in find_children("*", "MultiMeshInstance3D", true, false):
		fill_from_meta((n as MultiMeshInstance3D).multimesh)
	apply_quality()


static func fill_from_meta(mm: MultiMesh) -> void:
	if mm == null or not mm.has_meta(META_INSTANCES):
		return
	var data: PackedFloat32Array = mm.get_meta(META_INSTANCES)
	var count := data.size() / FLOATS_PER_INSTANCE
	mm.instance_count = 0
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = count
	for i in count:
		var o := i * FLOATS_PER_INSTANCE
		var b := Basis(Vector3(data[o], data[o + 1], data[o + 2]), Vector3(data[o + 3], data[o + 4], data[o + 5]),
				Vector3(data[o + 6], data[o + 7], data[o + 8]))
		mm.set_instance_transform(i, Transform3D(b, Vector3(data[o + 9], data[o + 10], data[o + 11])))
		mm.set_instance_custom_data(i, Color(data[o + 12], data[o + 13], data[o + 14], data[o + 15]))


## Reaplica densidade e distância do preset atual em todos os MultiMesh filhos.
func apply_quality(preset: EnvQuality.Preset = EnvQuality.current) -> void:
	var density: float = EnvQuality.get_setting("foliage_density", preset)
	var dist: float = EnvQuality.get_setting("foliage_distance", preset)
	for n: Node in find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var mm := mmi.multimesh
		if mm == null:
			continue
		if mmi.has_meta(&"keep_distance"):
			continue
		mm.visible_instance_count = int(ceil(mm.instance_count * density))
		mmi.visibility_range_end = dist
		mmi.visibility_range_end_margin = 4.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Espalha "mesh" com densidade (instâncias/m²) na área XZ. accept(x, z) -> float em 0..1 (probabilidade
## de manter; ex.: 0 na trilha). height(x, z) -> y do chão. Retorna o total de instâncias.
func add_layer(mesh: Mesh, area: Rect2, density: float, rng: RandomNumberGenerator, accept: Callable,
		height: Callable, scale_min: float = 0.8, scale_max: float = 1.25, layer_name: String = "",
		cast_shadow: bool = false) -> int:
	var items := sample(area, density, rng, accept, height, scale_min, scale_max)
	var base_name := layer_name if not layer_name.is_empty() else (mesh.resource_path.get_file().get_basename()
			if not mesh.resource_path.is_empty() else "layer")
	return add_instances(mesh, items, base_name, rng, cast_shadow)


## Sorteia instâncias ([Transform3D, semente]) sem criar nós — para juntar várias áreas numa camada só.
static func sample(area: Rect2, density: float, rng: RandomNumberGenerator, accept: Callable, height: Callable,
		scale_min: float = 0.8, scale_max: float = 1.25) -> Array:
	var items: Array = []
	var n := int(area.get_area() * density)
	for i in n:
		var x := rng.randf_range(area.position.x, area.end.x)
		var z := rng.randf_range(area.position.y, area.end.y)
		var keep: float = accept.call(x, z)
		if keep <= 0.0 or rng.randf() > keep:
			continue
		var s := rng.randf_range(scale_min, scale_max) * lerpf(0.75, 1.0, keep)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s * rng.randf_range(0.85, 1.15), s))
		var y: float = height.call(x, z)
		items.append([Transform3D(basis, Vector3(x, y, z)), rng.randf()])
	return items


## Adiciona instâncias prontas ([Transform3D, semente 0..1, (opcional) Color tinta] cada) em pedaços de chunk_size m.
## A tinta vai em INSTANCE_CUSTOM.gba (env_painted: use_instance_tint), a semente em INSTANCE_CUSTOM.r.
## Serve para árvores/props repetidos (cast_shadow ligado) e para camadas já sorteadas por outro código.
func add_instances(mesh: Mesh, items: Array, base_name: String, rng: RandomNumberGenerator,
		cast_shadow: bool = false) -> int:
	var chunks: Dictionary = {}
	for it: Array in items:
		var t: Transform3D = it[0]
		# pedaços centrados na origem (o ponto de nascimento/praça fica num pedaço só: menos draw calls)
		var key := Vector2i(floori(t.origin.x / chunk_size + 0.5), floori(t.origin.z / chunk_size + 0.5))
		if not chunks.has(key):
			chunks[key] = []
		(chunks[key] as Array).append(it)
	var total := 0
	for key: Vector2i in chunks:
		var list: Array = chunks[key]
		# embaralhado: reduzir visible_instance_count afina por igual
		for i in range(list.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Variant = list[i]
			list[i] = list[j]
			list[j] = tmp
		var mm := MultiMesh.new()
		mm.mesh = mesh
		var data := PackedFloat32Array()
		var aabb := AABB()
		for i in list.size():
			var t: Transform3D = list[i][0]
			var tc: Color = list[i][2] if (list[i] as Array).size() > 2 else Color.WHITE
			data.append_array([t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
					t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z, float(list[i][1]),
					tc.r, tc.g, tc.b])
			var box := t * mesh.get_aabb()
			aabb = box if i == 0 else aabb.merge(box)
		mm.set_meta(META_INSTANCES, data)
		mm.custom_aabb = aabb
		fill_from_meta(mm)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [base_name, key.x, key.y]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if cast_shadow:
			mmi.set_meta(&"keep_distance", true) # árvores/props: sem corte por distância do preset
		add_child(mmi)
		total += list.size()
	return total


## Instâncias e MultiMeshes (para o orçamento de desempenho).
func stats() -> Dictionary:
	var inst := 0
	var mms := 0
	for n: Node in find_children("*", "MultiMeshInstance3D", true, false):
		mms += 1
		var mm := (n as MultiMeshInstance3D).multimesh
		inst += (mm.get_meta(META_INSTANCES) as PackedFloat32Array).size() / FLOATS_PER_INSTANCE \
				if mm.has_meta(META_INSTANCES) else mm.instance_count
	return {"multimeshes": mms, "instances": inst}
