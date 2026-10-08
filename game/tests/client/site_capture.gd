extends Node
## Capturas para o site (08/10/2026), no cliente real e sem interface: com --hide-hud=1 esconde o Hud inteiro
## (barras, atalhos, minimapa, chat, nome do mapa); a chuva (RainOverlay, fora do Hud) continua na tela.
## Fotos: Campos de Pindorama refeitos (chegada, pontos de caça e perto de ipês, buritis e cupinzeiros), portal novo do
## Campo de Treino de dia e de noite, acampamento na chuva (chão molhado e poças) e moradia com varal/lanterna à noite.
## Clipes: quadros PNG em sequência (rodar com --fixed-fps 12: cada quadro = 1/12 s de jogo) em <shot-dir>/clips/<nome>/.
## Criado pelo main.gd com --autotest --autotest-script=res://tests/client/site_capture.gd --shot-dir=DIR;
## servidor com --dev-commands (tests/client/run_site_capture.sh). --site-only=fotos|clipes limita a parte;
## --site-clips=portal,chuva-acampamento,campos,passaros escolhe os clipes.

const ARG_SHOT_DIR: String = "shot-dir"
const ARG_HIDE_HUD: String = "hide-hud"
const ARG_ONLY: String = "site-only"
const ARG_CLIP: String = "site-clips"
const SETTLE_SEC: float = 7.0
const MOVE_SEC: float = 3.0
const CMD_GAP_SEC: float = 1.2
const SOAK_SEC: float = 40.0
const CLIP_FRAMES: int = 48
const CAMP_XZ: Vector2 = Vector2(0.0, 4.0)
const FIELD_MAPS: Array[String] = ["fields_pindorama", "fields_pindorama_buriti", "fields_pindorama_crossroads"]
const FIELD_SPOTS: Array[Vector2] = [Vector2(-12, 8), Vector2(12, -10)]
## Malhas (MultiMeshInstance3D) dos Campos para posar perto: a árvore fica acima e à esquerda do jogador.
const FIELD_LANDMARKS: Array[String] = ["Multi_fld_tree_ipe_yellow_a", "Multi_fld_tree_ipe_purple_a",
	"Multi_fld_palm_buriti_a", "Multi_fld_termite_mound_a"]
const LANDMARK_OFFSET: Vector2 = Vector2(2.5, 3.5)

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
	_hide_ui()
	var only: String = args.get(ARG_ONLY, "")
	if only != "clipes":
		await _photos()
	if only != "fotos":
		await _clips()
	_weather(0.0)
	await _cmd("/hora normal")
	Net.log_line("site_capture_done", {})
	get_tree().quit(0)


func _photos() -> void:
	# Campos de Pindorama: chegada, pontos de caça e marcos (ipê, buriti, cupinzeiro), de dia
	for map_id: String in FIELD_MAPS:
		await _goto(map_id)
		await _cmd("/dia")
		_weather(0.0)
		await _wait(2.0)
		await _shot("%s_chegada" % map_id)
		for i: int in FIELD_SPOTS.size():
			await _go(FIELD_SPOTS[i])
			await _shot("%s_caca%d" % [map_id, i + 1])
		for mm: String in FIELD_LANDMARKS:
			var at: Variant = _landmark(mm)
			if at == null:
				continue
			var v: Vector3 = at
			await _go(Vector2(v.x + LANDMARK_OFFSET.x, v.z + LANDMARK_OFFSET.y))
			await _shot("%s_%s" % [map_id, mm.trim_prefix("Multi_fld_")])
		# moradia do campo (varal) de dia e com lanterna à noite
		var home: Dictionary = _first_dwelling()
		if not home.is_empty():
			var hp: Vector3 = home["pos"] + (home["fwd"] as Vector3) * 2.5 + Vector3(0, 0, 1.5)
			await _go(Vector2(hp.x, hp.z))
			await _shot("%s_moradia_dia" % map_id)
			await _cmd("/noite")
			await _wait(4.0)
			await _shot("%s_moradia_noite" % map_id)
			await _cmd("/dia")
	# Campo de Treino: portal novo e acampamento
	await _goto("training_field")
	await _cmd("/dia")
	_weather(0.0)
	await _wait(2.0)
	for stand: float in [3.2, 5.0]:
		await _go_near_portal("training_exit", stand)
		await _shot("tf_portal_dia_%d" % int(stand))
	await _cmd("/noite")
	await _wait(4.0)
	for stand: float in [3.2, 5.0]:
		await _go_near_portal("training_exit", stand)
		await _shot("tf_portal_noite_%d" % int(stand))
	await _go(CAMP_XZ)
	await _shot("tf_acampamento_noite")
	await _cmd("/dia")
	await _wait(3.0)
	# canto de Pindorama no Campo de Treino (rancho do Mestre Jatobá e a vereda)
	await _go(Vector2(1.8, 39.5))
	await _shot("tf_pindorama_rancho")
	await _go(Vector2(-6.0, 44.0))
	await _shot("tf_pindorama_vereda")
	await _go(CAMP_XZ)
	await _shot("tf_acampamento_seco")
	_weather(1.0)
	await _wait(SOAK_SEC)
	await _shot("tf_acampamento_chuva")
	await _go(Vector2(-5.0, 9.0))
	await _shot("tf_acampamento_chuva_b")
	_weather(0.0)


func _clips() -> void:
	var want: PackedStringArray = args.get(ARG_CLIP, "portal,chuva-acampamento,campos,passaros").split(",", false)
	# portal novo nos Campos de Pindorama: o jogador chega perto (do lado de trás, para não tapar o portal na câmera)
	# e as chamas sobem
	if "portal" in want:
		await _goto("fields_pindorama")
		_weather(0.0)
		await _cmd("/dia")
		await _go_near_portal("back", -7.0)
		await _go_near_portal("back", -2.8, 0.3)
		await _record("portal")
	# chuva molhando o acampamento: já encharcado
	if "chuva-acampamento" in want:
		await _goto("training_field")
		await _cmd("/dia")
		await _go(CAMP_XZ)
		_weather(1.0)
		await _wait(SOAK_SEC)
		await _record("chuva-acampamento")
		_weather(0.0)
		await _wait(2.0)
	await _goto("fields_pindorama")
	await _cmd("/dia")
	await _wait(2.0)
	# campo ao vento perto da chegada: ipês balançando, sombras de nuvem, pólen (o portal embaixo do quadro)
	if "campos" in want:
		_weather(0.0)
		await _go_near_portal("back", -7.0)
		await _wait(2.0)
		await _record("campos")
	# pássaros chegando e pousando no Campo de Treino (sem monstros por perto)
	if "passaros" in want:
		await _goto("training_field")
		await _cmd("/dia")
		await _go(Vector2(-5.0, 9.0))
		await _wait(1.0)
		_flock()
		await _wait(0.4)
		await _record("passaros")


func _flock() -> void:
	var life: Node = _map_node(&"AmbientLife")
	if life == null or _player == null:
		Net.log_line("site_capture_no_life", {})
		return
	life.set(&"auto_spawn", false)
	var me: Vector3 = _player.global_position
	var species: Array = (life.get(&"profile") as Dictionary).get("species", [&"pindorama"])
	life.call(&"force_flock", {"pos": me + Vector3(2.4, 0.0, 0.8), "kind": &"ground"}, 4, species[0])
	life.call(&"force_flock", {"pos": me + Vector3(-2.2, 0.0, -0.6), "kind": &"ground"}, 4,
			species[1 % species.size()])
	life.call(&"force_flock", {"pos": me + Vector3(0.6, 0.0, 2.6), "kind": &"ground"}, 3, species[0], true)


## Grava CLIP_FRAMES quadros seguidos (com --fixed-fps 12 = 4 s de jogo).
func _record(clip: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var out: String = "%s/clips/%s" % [dir, clip]
	DirAccess.make_dir_recursive_absolute(out)
	for i: int in CLIP_FRAMES:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/frame_%03d.png" % [out, i])
	Net.log_line("site_capture_clip", {"dir": out, "fps": Engine.max_fps, "physics": Engine.physics_ticks_per_second})


## Posição (global) da instância da MultiMesh mais perto do jogador, a mais de 4 m da borda do mapa.
func _landmark(node_name: String) -> Variant:
	var map: Node = _current_map()
	if map == null or _player == null:
		return null
	var mmi: MultiMeshInstance3D = map.find_child(node_name, true, false) as MultiMeshInstance3D
	if mmi == null or mmi.multimesh == null or mmi.multimesh.instance_count == 0:
		return null
	var me: Vector3 = _player.global_position
	var best: Variant = null
	var best_d: float = 1e9
	for i: int in mmi.multimesh.instance_count:
		var pos: Vector3 = mmi.global_transform * mmi.multimesh.get_instance_transform(i).origin
		var d: float = Vector2(pos.x - me.x, pos.z - me.z).length()
		if d < best_d:
			best_d = d
			best = pos
	Net.log_line("site_capture_landmark", {"map": String(NetWorld.client_map_id), "node": node_name, "pos": str(best)})
	return best


func _first_dwelling() -> Dictionary:
	var dressing: Node = _map_node(&"CampDressing")
	var scan = dressing.get(&"scan_result") if dressing != null else null
	if scan == null:
		return {}
	var spawn: Vector3 = _player.global_position if _player != null else Vector3.ZERO
	var best: Dictionary = {}
	var best_d: float = 1e9
	for d: Dictionary in scan.dwellings:
		if (d["fwd"] as Vector3).z < 0.6:
			continue
		var dd: float = (d["pos"] as Vector3).distance_to(spawn)
		if dd < best_d:
			best_d = dd
			best = d
	return best


func _go_near_portal(portal: String, stand_off: float, settle: float = MOVE_SEC) -> void:
	var map: Node = _current_map()
	var area: Area3D = map.get_node_or_null("Interactables/" + portal) as Area3D if map != null else null
	if area == null:
		Net.log_line("site_capture_no_portal", {"portal": portal})
		return
	var p: Vector3 = area.global_position
	var dir := Vector3(0, 0, 1)
	var ap: Variant = area.get_meta(&"approach_position", null)
	if ap is Vector3:
		var v: Vector3 = (ap as Vector3) - p
		v.y = 0.0
		if v.length() > 0.2:
			dir = v.normalized()
	var stand: Vector3 = p + dir * stand_off
	await _go(Vector2(stand.x, stand.z), settle)


func _goto(map_id: String) -> void:
	if NetWorld.client_map_id != StringName(map_id):
		NetProgress.send_debug(&"goto", [map_id])
		await _wait(SETTLE_SEC)
		_hide_ui()


func _go(xz: Vector2, settle: float = MOVE_SEC) -> void:
	NetProgress.send_debug(&"teleport", [xz.x, xz.y])
	await _wait(settle)


func _cmd(text: String) -> void:
	Net.send_chat(Net.CHANNEL_LOCAL, text)
	await _wait(CMD_GAP_SEC)


func _weather(rain: float) -> void:
	var view: Node = main_node.get("client_view") if main_node != null else null
	var overlay: Node = view.find_child("RainOverlay", true, false) if view != null else null
	if overlay != null and overlay.has_method(&"force_weather"):
		overlay.call(&"force_weather", rain, 0.0, rain <= 0.0)


## Sem --hide-hud=1 só some o chat (como nos outros roteiros); com ele, o Hud inteiro.
func _hide_ui() -> void:
	var view: Node = main_node.get("client_view") if main_node != null else null
	if view == null:
		return
	for n: Node in view.find_children("*Chat*", "Control", true, false):
		(n as Control).modulate.a = 0.0
	if args.get(ARG_HIDE_HUD, "") == "1":
		var hud: Control = view.get_node_or_null(^"Hud") as Control
		if hud != null:
			hud.visible = false


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [dir, label]
	get_viewport().get_texture().get_image().save_png(path)
	Net.log_line("site_capture_shot", {"file": path, "map": String(NetWorld.client_map_id)})


func _map_node(n: StringName) -> Node:
	var map: Node = _current_map()
	return map.get_node_or_null(NodePath(String(n))) if map != null else null


func _current_map() -> Node:
	var root: Node = get_node_or_null(^"/root/Main/World/Instances")
	if root == null:
		return null
	for inst: Node in root.get_children():
		var map: Node = inst.get_node_or_null(^"Map")
		if map != null and &"map_id" in map and map.get(&"map_id") == NetWorld.client_map_id:
			return map
	return null
