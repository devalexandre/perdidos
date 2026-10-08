extends Node
## Captura da vida de ambiente no cliente real (08/10/2026): acampamento do Campo de Treino (nascimento, fogueira e
## barracas) de dia e de noite, uma sequência de gesto de NPC, passarinhos chegando, pousados e levantando voo quando
## o jogador chega perto; depois cidade (city_awakening), campo (fields_pindorama) e mata (enchanted_forest).
## Criado pelo main.gd com --autotest --autotest-script=res://tests/client/camp_life_capture.gd --shot-dir=DIR;
## servidor com --dev-commands (tests/client/run_camp_life_capture.sh).

const ARG_SHOT_DIR: String = "shot-dir"
const CAMP_XZ: Vector2 = Vector2(0.0, 4.0)
const TENTS_EAST_XZ: Vector2 = Vector2(8.0, -1.0)
const TENTS_WEST_XZ: Vector2 = Vector2(-8.5, -2.0)
## Onde o jogador fica para os passarinhos do acampamento (longe do Instrutor Bento).
const BIRDS_XZ: Vector2 = Vector2(-5.0, 9.0)
const SETTLE_SEC: float = 6.0
const MOVE_SEC: float = 2.5
const CMD_GAP_SEC: float = 1.2
const OTHER_MAPS: Array[String] = ["city_awakening", "fields_pindorama", "enchanted_forest"]

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false
var _player: Node3D = null


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)


func _on_spawned(p: Node3D) -> void:
	_player = p
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC)
	if NetWorld.client_map_id != &"training_field":
		NetProgress.send_debug(&"goto", ["training_field"])
		await _wait(SETTLE_SEC)
	_hide_chat()
	await _cmd("/dia")
	var rain: Node = _overlay()
	if rain != null:
		rain.call(&"force_weather", 0.0, 0.0, true)
	await _wait(2.0)
	var life: Node = _map_node(&"AmbientLife")
	if life != null:
		life.set(&"auto_spawn", false)
	_log_scan()
	# acampamento e barracas de dia
	await _go(CAMP_XZ)
	await _shot("tf_nascimento_dia")
	# barracas do leste do acampamento (entrada virada para a fogueira) e as do oeste
	await _go(TENTS_EAST_XZ)
	await _shot("tf_barracas_leste_dia")
	await _go(TENTS_WEST_XZ)
	await _shot("tf_barracas_oeste_dia")
	# gesto de NPC (o mais perto do acampamento), jogador a ~6 m
	await _npc_gesture_sequence()
	# passarinhos: chegam, pousam, ciscam e levantam voo
	await _go(BIRDS_XZ)
	await _bird_sequence("tf")
	# noite
	await _cmd("/noite")
	await _wait(4.0)
	await _go(CAMP_XZ)
	await _shot("tf_nascimento_noite")
	await _go(TENTS_EAST_XZ)
	await _shot("tf_barracas_leste_noite")
	await _go(TENTS_WEST_XZ)
	await _shot("tf_barracas_oeste_noite")
	await _cmd("/dia")
	await _wait(3.0)
	for id: String in OTHER_MAPS:
		NetProgress.send_debug(&"goto", [id])
		await _wait(SETTLE_SEC + 2.0)
		_hide_chat()
		life = _map_node(&"AmbientLife")
		if life != null:
			life.set(&"auto_spawn", false)
		_log_scan()
		# moradia com a frente virada para o sul (a câmera vem do sul), a mais perto do nascimento
		var home: Dictionary = _first_dwelling([&"tent", &"rancho", &"hut", &"door"], true)
		if home.is_empty():
			home = _first_dwelling([&"tent", &"rancho", &"hut", &"door"])
		if not home.is_empty():
			var hp: Vector3 = home["pos"] + (home["fwd"] as Vector3) * 2.5 + Vector3(0, 0, 1.5)
			await _go(Vector2(hp.x, hp.z))
			await _shot("%s_moradia" % id)
		await _bird_sequence(id, true)
	Net.log_line("camp_capture_done", {})
	get_tree().quit(0)


func _npc_gesture_sequence() -> void:
	var npc: Node3D = _nearest_npc(Vector3(CAMP_XZ.x, 0, CAMP_XZ.y))
	if npc == null:
		Net.log_line("camp_capture_no_npc", {})
		return
	var p: Vector3 = npc.global_position
	await _go(Vector2(p.x + 3.8, p.z + 2.0))
	var g: Node = npc.get_node_or_null(^"Visual/Gestures")
	if g == null:
		Net.log_line("camp_capture_no_gestures", {"npc": npc.name})
		return
	for gesture: StringName in [&"stretch", &"look", &"lean"]:
		await _wait(0.6)
		g.call(&"force_gesture", gesture)
		for i: int in 4:
			await _wait(0.35)
			await _shot("tf_npc_%s_%d" % [gesture, i])
	# jogador chega perto: o NPC vira para ele
	await _go(Vector2(p.x - 2.0, p.z + 1.2))
	await _wait(0.6)
	await _shot("tf_npc_vira_para_jogador")


func _bird_sequence(prefix: String, short: bool = false) -> void:
	var life: Node = _map_node(&"AmbientLife")
	if life == null or _player == null:
		Net.log_line("camp_capture_no_life", {"map": prefix})
		return
	var me: Vector3 = _player.global_position
	var cam: Camera3D = get_viewport().get_camera_3d()
	var right: Vector3 = cam.global_basis.x if cam != null else Vector3.RIGHT
	right.y = 0.0
	right = right.normalized()
	var site: Dictionary = {}
	# um poleiro achado no mapa (cerca, banco, caixa, telhado), se houver perto e na tela
	var scan = life.get(&"scan_result")
	if scan != null:
		var best: float = 1e9
		for perch: Dictionary in scan.perches:
			var pos: Vector3 = perch["pos"]
			var d: float = Vector2(pos.x - me.x, pos.z - me.z).length()
			if d > 4.5 and d < 10.0 and (cam == null or cam.is_position_in_frustum(pos)) and perch["kind"] != &"rock" and d < best \
					and bool(life.call(&"_perch_height_ok", perch)):
				best = d
				site = perch
	if site.is_empty():
		var p: Vector3 = me + right * 5.0
		site = {"pos": Vector3(p.x, me.y, p.z), "kind": &"ground"}
	Net.log_line("camp_capture_site", {"map": prefix, "kind": site["kind"], "pos": str(site["pos"]), "name": site.get("name", "")})
	var species: Array = (life.get(&"profile") as Dictionary).get("species", [&"sabia"])
	life.call(&"force_flock", site, 3, species[1 % species.size()])
	if not short:
		for t: float in [0.7, 1.4, 2.2]:
			await _wait(0.75)
			await _shot("%s_passaros_chegando_%.1f" % [prefix, t])
	await _wait(3.0)
	await _shot("%s_passaros_pousados" % prefix)
	# chão: um segundo bando no chão perto, para ver ciscando
	var ground: Vector3 = me - right * 4.5
	life.call(&"force_flock", {"pos": Vector3(ground.x, me.y, ground.z), "kind": &"ground"}, 3,
			species[0], true)
	await _wait(1.5)
	await _shot("%s_passaros_ciscando" % prefix)
	if short:
		return
	await _wait(1.2)
	await _shot("%s_passaros_ciscando_b" % prefix)
	# o jogador vai até o bando do chão: levantam voo
	await _go(Vector2(ground.x + 0.5, ground.z), 0.0)
	for i: int in 4:
		await _wait(0.3)
		await _shot("%s_passaros_voando_%d" % [prefix, i])


## Primeiro sinal de uso colocado (lanterna, balde, lenha...) perto do nascimento.
func _first_dressing_spot() -> Variant:
	var dressing: Node = _map_node(&"CampDressing")
	if dressing == null:
		return null
	for prefix: String in ["Lantern", "Bucket", "Firewood", "Mat"]:
		for c: Node in dressing.get_children():
			if String(c.name).begins_with(prefix):
				return (c as Node3D).global_position
	return null


func _first_dwelling(kinds: Array, facing_south: bool = false) -> Dictionary:
	var dressing: Node = _map_node(&"CampDressing")
	var scan = dressing.get(&"scan_result") if dressing != null else null
	if scan == null:
		return {}
	var spawn: Vector3 = _player.global_position if _player != null else Vector3.ZERO
	var best: Dictionary = {}
	var best_d: float = 1e9
	for d: Dictionary in scan.dwellings:
		if not (d["kind"] in kinds) or (facing_south and (d["fwd"] as Vector3).z < 0.6):
			continue
		var dd: float = (d["pos"] as Vector3).distance_to(spawn)
		if dd < best_d:
			best_d = dd
			best = d
	return best


func _log_scan() -> void:
	var dressing: Node = _map_node(&"CampDressing")
	var life: Node = _map_node(&"AmbientLife")
	Net.log_line("camp_capture_scan", {"map": String(NetWorld.client_map_id),
		"perches": int(life.call(&"perch_count")) if life != null else -1,
		"dwellings": (dressing.get(&"scan_result").dwellings as Array).size() if dressing != null and dressing.get(&"scan_result") != null else -1,
		"placed": str(dressing.get(&"placed")) if dressing != null else ""})


func _nearest_npc(at: Vector3) -> Node3D:
	var map: Node = _current_map()
	var ents: Node = map.get_parent().get_node_or_null(^"Entities") if map != null else null
	if ents == null:
		return null
	var best: Node3D = null
	var best_d: float = 1e9
	for e: Node in ents.get_children():
		if e is NetEntity and (e as NetEntity).is_npc():
			var d: float = (e as Node3D).global_position.distance_to(at)
			if d < best_d:
				best_d = d
				best = e as Node3D
	return best


func _map_node(n: StringName) -> Node:
	var map: Node = _current_map()
	return map.get_node_or_null(NodePath(String(n))) if map != null else null


func _overlay() -> Node:
	var view: Node = main_node.get("client_view") if main_node != null else null
	return view.find_child("RainOverlay", true, false) if view != null else null


func _go(xz: Vector2, settle: float = MOVE_SEC) -> void:
	NetProgress.send_debug(&"teleport", [xz.x, xz.y])
	await _wait(maxf(settle, 0.35))


func _cmd(text: String) -> void:
	Net.send_chat(Net.CHANNEL_LOCAL, text)
	await _wait(CMD_GAP_SEC)


func _hide_chat() -> void:
	var view: Node = main_node.get("client_view") if main_node != null else null
	if view == null:
		return
	for n: Node in view.find_children("*Chat*", "Control", true, false):
		(n as Control).modulate.a = 0.0


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [dir, label]
	get_viewport().get_texture().get_image().save_png(path)
	Net.log_line("camp_capture_shot", {"file": path})


func _current_map() -> Node:
	var root: Node = get_node_or_null(^"/root/Main/World/Instances")
	if root == null:
		return null
	for inst: Node in root.get_children():
		var map: Node = inst.get_node_or_null(^"Map")
		if map != null and &"map_id" in map and map.get(&"map_id") == NetWorld.client_map_id:
			return map
	return null
