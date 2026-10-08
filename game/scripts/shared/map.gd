class_name GameMap
extends Node3D
## Raiz de toda cena de mapa (cidade, caca, PVP). Carrega igual no servidor headless e no cliente.
##
## Contrato (docs/phase1-contracts.md):
##  - Marker3D "SpawnPoint" -> get_spawn_point()
##  - NavigationRegion3D "NavigationRegion3D" com navmesh ja assado -> get_navigation_map()
##  - Chao clicavel: StaticBody3D na camada de colisao 1 (e nada mais na camada 1).
##
## Cada instancia de mapa recebe o SEU PROPRIO mapa de navegacao (RID) em vez de usar o mapa
## padrao do World3D: varias instancias (ex.: copias de mapas de caca) ficam na mesma posicao
## do mundo e nao podem ter os navmeshes fundidos.

@export var map_id: StringName = &"city_awakening"
## Deve bater com cell_size/cell_height do navmesh assado (tools/art/build_city.gd).
@export var nav_cell_size: float = 0.2
@export var nav_cell_height: float = 0.2

var _nav_map: RID = RID()


func _enter_tree() -> void:
	_ensure_nav_map()


func _exit_tree() -> void:
	if _nav_map.is_valid():
		var region := _get_region()
		if region != null:
			region.set_navigation_map(RID())
		NavigationServer3D.free_rid(_nav_map)
		_nav_map = RID()


func _ensure_nav_map() -> void:
	if _nav_map.is_valid():
		return
	_nav_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_nav_map, nav_cell_size)
	NavigationServer3D.map_set_cell_height(_nav_map, nav_cell_height)
	NavigationServer3D.map_set_up(_nav_map, Vector3.UP)
	NavigationServer3D.map_set_active(_nav_map, true)
	var region := _get_region()
	if region != null:
		region.set_navigation_map(_nav_map)


func _get_region() -> NavigationRegion3D:
	return get_node_or_null(^"NavigationRegion3D") as NavigationRegion3D


## Posicao global de nascimento/renascimento (ao lado do cristal da praca).
func get_spawn_point() -> Vector3:
	var m := get_node_or_null(^"SpawnPoint") as Marker3D
	if m == null:
		push_warning("GameMap %s: sem SpawnPoint" % map_id)
		return global_position if is_inside_tree() else Vector3.ZERO
	return m.global_position if m.is_inside_tree() else m.position


## RID do mapa de navegacao desta instancia (sincroniza no proximo quadro de fisica).
func get_navigation_map() -> RID:
	_ensure_nav_map()
	return _nav_map


## Pontos de vista planejados (GDD 17.11): Marker3D "Viewpoint1".."ViewpointN".
func get_viewpoints() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	var i: int = 1
	while has_node(NodePath("Viewpoint%d" % i)):
		out.append(get_node(NodePath("Viewpoint%d" % i)) as Marker3D)
		i += 1
	return out


## Objetos clicaveis do mapa (Interactables/, Area3D na camada 2), para o servidor.
## Retorna interact_id (String) -> {"type": StringName, "position": Vector3, "meta": Dictionary}.
## meta traz todas as metas do no: interact_id, interact_type, target_id ("m:<id>"), facing_yaw,
## seat_position e approach_position (sit); target_map, recommended_level (String) e
## approach_position (portal). "position" e a posicao global da area (centro do clique).
func get_interactables() -> Dictionary:
	var out: Dictionary = {}
	var parent := get_node_or_null(^"Interactables")
	if parent == null:
		return out
	for a: Node in parent.get_children():
		var n3 := a as Node3D
		if n3 == null or not n3.has_meta(&"interact_id"):
			continue
		var meta: Dictionary = {}
		for k: StringName in n3.get_meta_list():
			meta[k] = n3.get_meta(k)
		var pos: Vector3 = n3.global_position if n3.is_inside_tree() else n3.position
		out[String(n3.get_meta(&"interact_id"))] = {"type": n3.get_meta(&"interact_type", &""), "position": pos, "meta": meta}
	return out


## Marker3D de NpcPoints/ pelo nome (spawn_marker / patrol_markers do NpcDef), ou null.
func get_npc_point(marker_name: StringName) -> Marker3D:
	return get_node_or_null(NodePath("NpcPoints/" + String(marker_name))) as Marker3D


## Zonas de audio (AudioZones/) que contem o ponto global pos, como ids de AudioZoneDef
## ("<map_id>_<zone_id>"). Teste geometrico (caixa da forma), sem fisica: serve no cliente.
func get_audio_zone_ids_at(pos: Vector3) -> Array[StringName]:
	var out: Array[StringName] = []
	var parent := get_node_or_null(^"AudioZones")
	if parent == null:
		return out
	for a: Node in parent.get_children():
		var area := a as Area3D
		if area == null:
			continue
		for cs: Node in area.get_children():
			var shape := (cs as CollisionShape3D).shape as BoxShape3D if cs is CollisionShape3D else null
			if shape == null:
				continue
			var local: Vector3 = (cs as Node3D).global_transform.affine_inverse() * pos
			var h := shape.size * 0.5
			if absf(local.x) <= h.x and absf(local.y) <= h.y and absf(local.z) <= h.z:
				out.append(StringName("%s_%s" % [map_id, area.get_meta(&"zone_id", &"")]))
				break
	return out


func _ready() -> void:
	if map_id == &"training_field" and DisplayServer.get_name() != "headless" and not DayNight.is_server:
		var atmosphere: Node3D = (load("res://scripts/client/env/living_environment.gd") as Script).new()
		atmosphere.name = &"LivingEnvironment"
		add_child(atmosphere)
	# Vida de ambiente de todo mapa externo (só cliente): passarinhos e sinais de uso perto das moradias.
	if DisplayServer.get_name() != "headless" and not DayNight.is_server:
		var fauna: Script = load("res://scripts/client/env/ambient_life.gd")
		if fauna.call(&"supports", map_id):
			var life: Node3D = fauna.new()
			life.set(&"map_id", map_id)
			add_child(life)
			var dressing: Node3D = (load("res://scripts/client/env/camp_dressing.gd") as Script).new()
			dressing.set(&"map_id", map_id)
			add_child(dressing)
		# Cenário vivo de todo mapa (só cliente): plantas balançando, sombra de nuvem, partículas de ar, caverna.
		var scenery: Node3D = (load("res://scripts/client/env/scenery_life.gd") as Script).new()
		scenery.set(&"map_id", map_id)
		scenery.name = &"SceneryLife"
		add_child(scenery)

		if String(map_id).begins_with("cave_reino_encoberto"):
			var cave: Node3D = (load("res://scripts/client/env/cave_atmosphere.gd") as Script).new()
			cave.name = &"CaveAtmosphere"
			add_child(cave)
