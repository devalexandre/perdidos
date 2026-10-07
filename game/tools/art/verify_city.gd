extends SceneTree
## Verificacao headless do mapa: carrega a cena, pega spawn/nav map, espera sincronizar e pede
## caminhos do spawn ate pontos distantes (fim do pier, portoes, Casa dos Mestres).
##   godot --headless --path game --script res://tools/art/verify_city.gd

const SCENE := "res://scenes/maps/city_awakening.tscn"

var failures: int = 0


func _initialize() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		push_error("nao carregou " + SCENE)
		quit(1)
		return
	var map := packed.instantiate() as Node3D
	root.add_child(map)
	_run.call_deferred(map)


func _check(label: String, ok: bool, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, info])
	if not ok:
		failures += 1


func _run(map: Node3D) -> void:
	_check("script GameMap", map.get_script() != null and map.has_method(&"get_spawn_point"))
	_check("map_id", map.get(&"map_id") == &"city_awakening", str(map.get(&"map_id")))
	var spawn: Vector3 = map.call(&"get_spawn_point")
	var nav: RID = map.call(&"get_navigation_map")
	_check("nav map valido", nav.is_valid())
	_check("nav map proprio (nao o padrao do World3D)", nav != map.get_world_3d().navigation_map)
	# camada 1: somente o chao (StaticBody3D com meta surface); camada 2: somente Interactables
	var surfaces := {}
	var bad_layers := 0
	for n: Node in map.find_children("*", "CollisionObject3D", true, false):
		var co := n as CollisionObject3D
		var parent_name := String(co.get_parent().name)
		if co.collision_layer & 1:
			if not (co is StaticBody3D and parent_name == "Ground" and co.collision_layer == 1 and co.has_meta(&"surface")):
				bad_layers += 1
				print("  camada 1 indevida: ", co.get_path())
			else:
				surfaces[co.get_meta(&"surface")] = true
		if co.collision_layer & 2:
			if not (co is Area3D and parent_name == "Interactables" and co.collision_layer == 2):
				bad_layers += 1
				print("  camada 2 indevida: ", co.get_path())
		if parent_name == "Interactables" and co.collision_layer != 2:
			bad_layers += 1
			print("  interactable fora da camada 2: ", co.get_path())
		if parent_name == "AudioZones" and co.collision_layer != 0:
			bad_layers += 1
	_check("camadas: 1 = chao, 2 = clicaveis", bad_layers == 0, "%d problema(s)" % bad_layers)
	_check("pisos stone/wood/grass/sand", surfaces.has(&"stone") and surfaces.has(&"wood") and surfaces.has(&"grass") and surfaces.has(&"sand"), str(surfaces.keys()))
	var inter: Dictionary = map.call(&"get_interactables")
	var n_sit := 0
	var n_portal := 0
	for k: String in inter:
		var t: StringName = inter[k]["type"]
		n_sit += 1 if t == &"sit" else 0
		n_portal += 1 if t == &"portal" and (inter[k]["meta"] as Dictionary).has(&"target_map") and (inter[k]["meta"] as Dictionary).has(&"recommended_level") else 0
	_check("interactables: 3 sit + 3 portal", n_sit == 3 and n_portal == 3, str(inter.keys()))
	for z: String in ["default", "docks", "market"]:
		_check("AudioZones/" + z, map.has_node("AudioZones/" + z) and map.get_node("AudioZones/" + z).get_meta(&"zone_id", &"") == StringName(z))
	var dz: Array = map.call(&"get_audio_zone_ids_at", Vector3(45, 0, 0))
	_check("zona de audio nas docas", dz.has(&"city_awakening_docks") and dz.has(&"city_awakening_default"), str(dz))
	# a sincronizacao do mapa e assincrona: esperar ate a regiao aparecer nas consultas
	var frames := 0
	while frames < 120:
		await physics_frame
		frames += 1
		if NavigationServer3D.map_get_iteration_id(nav) > 0 \
				and NavigationServer3D.map_get_closest_point(nav, spawn).distance_to(spawn) < 0.5:
			break
	print("nav sincronizado apos %d quadros de fisica (iteration %d)" % [frames, NavigationServer3D.map_get_iteration_id(nav)])
	var targets := {
		"pier principal (ponta)": Vector3(48.0, 0, 0.8),
		"pier norte": Vector3(48.0, 0, -22),
		"portao norte (fora)": Vector3(0, 0, -59),
		"portao oeste (fora)": Vector3(-59, 0, 0),
		"porta Casa dos Mestres": (map.get_node("PointsOfInterest/MastersHouseDoor") as Node3D).position,
		"feira": Vector3(7.5, 0, 7.0),
	}
	var snapped_spawn := NavigationServer3D.map_get_closest_point(nav, spawn)
	_check("spawn no navmesh", snapped_spawn.distance_to(spawn) < 0.3, "spawn=%s snapped=%s" % [spawn, snapped_spawn])
	for k: String in targets:
		var t: Vector3 = targets[k]
		var path := NavigationServer3D.map_get_path(nav, spawn, t, true)
		var end_ok := path.size() > 0 and path[path.size() - 1].distance_to(t) < 0.8
		_check("caminho ate " + k, path.size() > 1 and end_ok, "pontos=%d fim=%s" % [path.size(), path[path.size() - 1] if path.size() > 0 else Vector3.INF])
	# pontos de NPC e de aproximacao dos interactables no navmesh e alcancaveis do spawn
	var probes := {}
	for m: Node in map.get_node("NpcPoints").get_children():
		probes["NpcPoints/" + m.name] = (m as Node3D).position
	for k: String in inter:
		probes["approach " + k] = (inter[k]["meta"] as Dictionary)[&"approach_position"]
	for k: String in probes:
		var pt: Vector3 = probes[k]
		var sp := NavigationServer3D.map_get_closest_point(nav, pt)
		var path := NavigationServer3D.map_get_path(nav, spawn, pt, true)
		var ok := sp.distance_to(pt) < 0.35 and path.size() > 0 and path[path.size() - 1].distance_to(pt) < 0.5
		_check("no navmesh: " + k, ok, "pos=%s snapped=%s" % [pt, sp])
	# agua nao e caminhavel
	var w := Vector3(55, 0, 12)
	var cw := NavigationServer3D.map_get_closest_point(nav, w)
	_check("agua fora do navmesh", cw.distance_to(w) > 2.0, "mais proximo de %s = %s" % [w, cw])
	# dentro de uma casa nao e caminhavel
	var hsp := Vector3(cos(PI / 4.0), 0, sin(PI / 4.0)) * 23.0 # casa da praca (sudeste)
	var ch := NavigationServer3D.map_get_closest_point(nav, hsp)
	_check("casa fora do navmesh", ch.distance_to(hsp) > 3.0, "mais proximo de %s = %s" % [hsp, ch])
	var tp := (map.get_node("PointsOfInterest/IpeTree") as Node3D).position
	var ct := NavigationServer3D.map_get_closest_point(nav, tp)
	_check("tronco do ipe fora do navmesh", ct.distance_to(tp) > 1.5, "mais proximo de %s = %s" % [tp, ct])
	print("RESULT: %s (%d falha(s))" % ["OK" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
