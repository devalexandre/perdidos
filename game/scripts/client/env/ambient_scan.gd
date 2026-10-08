extends RefCounted
## Leitura automática do mapa para a vida de ambiente (08/10/2026), só no cliente e sem rede:
## acha poleiros (cercas, bancos, caixas, barris, telhados, barracas, pedras), moradias (barracas, ranchos, casas,
## portas do kit colonial), fogueiras, áreas proibidas (nascimento, portais, NPCs, interações) e trilhas/calçadas.
## Tudo pelos NOMES dos nós e das malhas do kit (Decor/Kit/<malha>_<cx>_<cz>, Decor/CampTent, Trail...), sem
## posicionar nada à mão em cada mapa. Usado por AmbientLife (pássaros) e CampDressing (detalhes de uso).

## Poleiros: trechos do nome (minúsculo) → tipo. Ordem importa (o primeiro que casar vence).
const PERCH_KEYS: Array = [
	["fence", &"fence"], ["bench", &"bench"], ["crate", &"crate"], ["barrel", &"crate"], ["wagon", &"crate"],
	["cart", &"crate"], ["chest", &"crate"], ["table", &"bench"], ["stall", &"roof"],
	["tent", &"roof"], ["rancho", &"roof"], ["roof", &"roof"], ["well", &"crate"], ["signpost", &"fence"],
	["carved_post", &"fence"], ["log", &"bench"], ["stump", &"bench"], ["hut", &"roof"], ["izba", &"roof"],
	["longhouse", &"roof"], ["adobe", &"roof"], ["pk_rock", &"rock"], ["fld_rock", &"rock"], ["rock_moss", &"rock"],
	["termite", &"rock"], ["boat", &"crate"],
]
## Trechos que NUNCA são poleiro (pedrinhas, calçamento, trilha, cristal, chão).
const PERCH_SKIP: Array[String] = ["pk_bag", "pebble", "rockpath", "trail", "path", "crystal", "floor", "ground", "terrain",
	"water", "wall", "pillar", "_door", "window", "chimney", "corner", "balcony", "vine", "frame"]
## Moradias: trecho do nome → tipo. "door" = porta do kit colonial (fachada para +Z da peça).
const DWELLING_KEYS: Array = [
	["camp_tent", &"tent"], ["lm_camp_tent", &"tent"], ["camptent", &"tent"], ["camp_rancho", &"rancho"],
	["celta_hut", &"hut"], ["eslavo_izba", &"hut"], ["hut_legs", &"hut"], ["nordico_longhouse", &"hut"],
	["japao_house", &"hut"], ["egito_adobe", &"hut"], ["portugal_house", &"hut"], ["pkv_door_", &"door"],
]
const FIRE_KEYS: Array[String] = ["camp_fire", "campfire", "campflame", "ranchoflame", "fogueira"]
const TRAIL_KEYS: Array[String] = ["trail", "flagstonepath", "calcada", "cobble", "rockpath", "road", "street"]
## Raios (m) das áreas que a vida de ambiente evita.
const KEEPOUT_SPAWN: float = 4.0
const KEEPOUT_PORTAL: float = 4.0
const KEEPOUT_NPC: float = 1.8
const KEEPOUT_INTERACT: float = 1.6
## Célula (m) da grade de trilhas e limite de células (mapas enormes).
const TRAIL_CELL: float = 0.75
const TRAIL_MAX_CELLS: int = 250000
## Poleiros por mapa (amostra) e altura máxima (m) de um poleiro (telhados de casas altas não servem).
const MAX_PERCHES: int = 600
const MAX_PERCH_HEIGHT: float = 7.5
const GROUND_LAYER: int = 1


## Resultado da leitura (mesmo mapa = mesmo resultado, para todos verem igual).
class Result:
	## [{pos: Vector3 (topo), kind: StringName, name: String}]
	var perches: Array[Dictionary] = []
	## [{pos: Vector3 (centro no chão), fwd: Vector3 (frente/porta), half: Vector2 (meia largura x, meia prof. z), kind}]
	var dwellings: Array[Dictionary] = []
	var fires: Array[Vector3] = []
	## [[Vector3, raio]]
	var keepout: Array = []
	## células (Vector2i) de trilha/calçada
	var trail_cells: Dictionary = {}


static func scan(map: Node3D) -> Result:
	var r := Result.new()
	if map == null:
		return r
	_scan_keepout(map, r)
	_scan_node(map, map, r)
	r.perches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _key(a["pos"]) < _key(b["pos"]))
	r.dwellings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _key(a["pos"]) < _key(b["pos"]))
	r.fires.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _key(a) < _key(b))
	# a mesma fogueira aparece no kit e no nó antigo (CampFlame): uma só
	var fires: Array[Vector3] = []
	for f: Vector3 in r.fires:
		var dup: bool = false
		for g: Vector3 in fires:
			dup = dup or Vector2(f.x - g.x, f.z - g.z).length() < 1.5
		if not dup:
			fires.append(f)
	r.fires = fires
	if r.perches.size() > MAX_PERCHES:
		var step: float = float(r.perches.size()) / MAX_PERCHES
		var kept: Array[Dictionary] = []
		for i: int in MAX_PERCHES:
			kept.append(r.perches[int(i * step)])
		r.perches = kept
	return r


## Ponto proibido para enfeite/pouso (nascimento, portal, NPC, interação) ou em cima de trilha?
static func is_blocked(r: Result, p: Vector3, margin: float = 0.0, avoid_trails: bool = true) -> bool:
	for k: Array in r.keepout:
		var c: Vector3 = k[0]
		if Vector2(p.x - c.x, p.z - c.z).length() < float(k[1]) + margin:
			return true
	if avoid_trails and is_on_trail(r, p):
		return true
	return false


static func is_on_trail(r: Result, p: Vector3) -> bool:
	return r.trail_cells.has(Vector2i(floori(p.x / TRAIL_CELL), floori(p.z / TRAIL_CELL)))


## Chão (raio de cima para baixo na física do mapa). null se não achou.
static func ground_at(map: Node3D, p: Vector3, up: float = 12.0, down: float = 20.0) -> Variant:
	if map == null or not map.is_inside_tree():
		return null
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	if space == null:
		return null
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * up, p - Vector3.UP * down, GROUND_LAYER)
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else null


## O ponto está na malha de navegação (chão andável)? Sem malha sincronizada, aceita.
static func is_walkable(map: Node3D, p: Vector3, tolerance: float = 0.5) -> bool:
	if map == null or not map.is_inside_tree():
		return true
	var nav: RID = map.get_world_3d().navigation_map
	if not nav.is_valid() or NavigationServer3D.map_get_iteration_id(nav) == 0:
		return true
	var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, p)
	return Vector2(c.x - p.x, c.z - p.z).length() <= tolerance and absf(c.y - p.y) < 1.5


# --- internos -------------------------------------------------------------------------------------

static func _key(p: Vector3) -> float:
	return snappedf(p.x, 0.01) * 100000.0 + snappedf(p.z, 0.01)


static func _scan_keepout(map: Node3D, r: Result) -> void:
	for child: Node in map.get_children():
		if child is Marker3D:
			var n: String = String(child.name).to_lower()
			if n.contains("spawn") or n.contains("respawn") or n.contains("arrival"):
				r.keepout.append([(child as Node3D).global_position, KEEPOUT_SPAWN])
	var npcs: Node = map.get_node_or_null(^"NpcPoints")
	if npcs != null:
		for m: Node in npcs.get_children():
			if m is Node3D:
				r.keepout.append([(m as Node3D).global_position, KEEPOUT_NPC])
	var inter: Node = map.get_node_or_null(^"Interactables")
	if inter != null:
		for a: Node in inter.get_children():
			if a is Node3D:
				var portal: bool = a.get_meta(&"interact_type", &"") == &"portal" or a.has_meta(&"target_map")
				r.keepout.append([(a as Node3D).global_position, KEEPOUT_PORTAL if portal else KEEPOUT_INTERACT])


static func _scan_node(map: Node3D, node: Node, r: Result) -> void:
	for child: Node in node.get_children():
		var n: String = String(child.name).to_lower()
		# ambiente do cliente (este mesmo sistema), entidades e áudio não entram
		if n in ["ambientlife", "campdressing", "livingenvironment", "audiozones", "spawns", "npcpoints", "interactables"]:
			continue
		if child is MultiMeshInstance3D:
			_scan_multimesh(child as MultiMeshInstance3D, n, r)
		elif child is MeshInstance3D:
			_scan_mesh(child as MeshInstance3D, n, r)
		if child.get_child_count() > 0 and not (child is MultiMeshInstance3D):
			_scan_node(map, child, r)


static func _mesh_name(n: String, mesh: Mesh) -> String:
	var out: String = n
	if mesh != null and not mesh.resource_path.is_empty() and not mesh.resource_path.contains("::"):
		out = mesh.resource_path.get_file().get_basename().to_lower() + " " + n
	return out


static func _scan_multimesh(mmi: MultiMeshInstance3D, n: String, r: Result) -> void:
	var mm: MultiMesh = mmi.multimesh
	if mm == null or mm.mesh == null or mm.instance_count == 0:
		return
	var label: String = _mesh_name(n, mm.mesh)
	var perch: StringName = _perch_kind(label)
	var dwell: StringName = _dwelling_kind(label)
	var fire: bool = _is_fire(label)
	var trail: bool = _is_trail(label)
	if perch.is_empty() and dwell.is_empty() and not fire and not trail:
		return
	var box: AABB = mm.mesh.get_aabb()
	var count: int = mm.instance_count if mm.visible_instance_count < 0 else mini(mm.instance_count, mm.visible_instance_count)
	for i: int in count:
		var xf: Transform3D = mmi.global_transform * mm.get_instance_transform(i)
		_register(xf, box, label, perch, dwell, fire, r)
	if trail:
		_mark_trail(mmi.global_transform, mm.mesh, r)


static func _scan_mesh(mi: MeshInstance3D, n: String, r: Result) -> void:
	if mi.mesh == null:
		return
	var label: String = _mesh_name(n, mi.mesh)
	# "Decor/CampTent" (fields_pindorama) etc.: o nome do nó já diz o que é.
	var perch: StringName = _perch_kind(label)
	var dwell: StringName = _dwelling_kind(label)
	var fire: bool = _is_fire(label)
	if _is_trail(label):
		_mark_trail(mi.global_transform, mi.mesh, r)
		return
	if perch.is_empty() and dwell.is_empty() and not fire:
		return
	_register(mi.global_transform, mi.mesh.get_aabb(), label, perch, dwell, fire, r)


static func _register(xf: Transform3D, box: AABB, label: String, perch: StringName, dwell: StringName, fire: bool,
		r: Result) -> void:
	var world_box: AABB = xf * box
	var base: Vector3 = xf.origin
	var center := Vector3(world_box.get_center().x, base.y, world_box.get_center().z)
	if fire:
		r.fires.append(center)
	if not dwell.is_empty():
		var sx: float = xf.basis.x.length()
		var sz: float = xf.basis.z.length()
		var fwd: Vector3 = xf.basis.z.normalized()
		# barracas do kit (camp_tent_v2): a entrada fica no -X local (conferido nas capturas do acampamento)
		if dwell == &"tent":
			fwd = -xf.basis.x.normalized()
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var half := Vector2(maxf(absf(box.size.x) * sx, 1.0) * 0.5, maxf(absf(box.size.z) * sz, 1.0) * 0.5)
		if dwell == &"tent":
			half = Vector2(half.y, half.x)
		r.dwellings.append({"pos": center, "fwd": fwd, "half": half, "kind": dwell, "name": label})
	if not perch.is_empty():
		var top: float = world_box.end.y
		if top - base.y > MAX_PERCH_HEIGHT:
			return
		var c: Vector3 = world_box.get_center()
		r.perches.append({"pos": Vector3(c.x, top, c.z), "kind": perch, "name": label,
			"span": Vector2(world_box.size.x, world_box.size.z)})


static func _perch_kind(label: String) -> StringName:
	for s: String in PERCH_SKIP:
		if label.contains(s):
			return &""
	for k: Array in PERCH_KEYS:
		if label.contains(String(k[0])):
			return k[1]
	return &""


static func _dwelling_kind(label: String) -> StringName:
	for k: Array in DWELLING_KEYS:
		if label.contains(String(k[0])):
			return k[1]
	return &""


static func _is_fire(label: String) -> bool:
	if label.contains("firefly"):
		return false
	for k: String in FIRE_KEYS:
		if label.contains(k):
			return true
	return false


static func _is_trail(label: String) -> bool:
	for k: String in TRAIL_KEYS:
		if label.contains(k):
			return true
	return false


## Marca na grade as células cobertas pelos triângulos da malha (no plano XZ).
static func _mark_trail(xf: Transform3D, mesh: Mesh, r: Result) -> void:
	for s: int in mesh.get_surface_count():
		var faces: PackedVector3Array = PackedVector3Array()
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			faces = verts
		else:
			for i: int in idx:
				faces.append(verts[i])
		for t: int in range(0, faces.size() - 2, 3):
			if r.trail_cells.size() > TRAIL_MAX_CELLS:
				return
			var a: Vector3 = xf * faces[t]
			var b: Vector3 = xf * faces[t + 1]
			var c: Vector3 = xf * faces[t + 2]
			var tri := PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
			var x0: int = floori(minf(a.x, minf(b.x, c.x)) / TRAIL_CELL)
			var x1: int = floori(maxf(a.x, maxf(b.x, c.x)) / TRAIL_CELL)
			var z0: int = floori(minf(a.z, minf(b.z, c.z)) / TRAIL_CELL)
			var z1: int = floori(maxf(a.z, maxf(b.z, c.z)) / TRAIL_CELL)
			for zi: int in range(z0, z1 + 1):
				for xi: int in range(x0, x1 + 1):
					var p := Vector2((xi + 0.5) * TRAIL_CELL, (zi + 0.5) * TRAIL_CELL)
					if Geometry2D.is_point_in_polygon(p, tri):
						r.trail_cells[Vector2i(xi, zi)] = true
