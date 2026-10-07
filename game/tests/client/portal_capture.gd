extends Node
## Captura dos portais no cliente real (PortalFx, 30/09/2026). Criado pelo main.gd com --autotest
## --autotest-script=res://tests/client/portal_capture.gd --shot-dir=DIR; servidor com --dev-commands
## (tests/client/run_portal_capture.sh). Começa no Porto e atravessa os próprios portais: Porto (portal da
## cidade) → Campos do Sabiá → Mata Encantada → Chapada, de dia e de noite em cada um.

const ARG_SHOT_DIR: String = "shot-dir"
const INSTANCES: NodePath = ^"/root/Main/World/Instances"
const SETTLE_SEC: float = 3.0
const LIGHT_SEC: float = 4.0
const CMD_GAP_SEC: float = 1.2
## Onde o jogador fica em relação ao portal (m, na direção do approach_position): o portal fica no quadro.
const STAND_OFF: float = 3.0
## Sequência: [rótulo, id do portal para fotografar, id do portal para atravessar depois ("" = fim)].
const ROUTE: Array = [["cidade", "gate_north", "gate_north"], ["campos", "forward", "forward"],
	["mata", "forward", "forward"], ["chapada", "back", ""]]

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC * 2.0)
	_hide_chat()
	for step: Array in ROUTE:
		await _visit(step[0], step[1])
		if String(step[2]).is_empty():
			break
		var before: StringName = NetWorld.client_map_id
		await _go_near(step[2])
		Net.send_interact("m:" + String(step[2]))
		await _wait(SETTLE_SEC * 2.5)
		_hide_chat()
		Net.log_line("portal_capture_crossed", {"from": String(before), "portal": step[2]})
	await _cmd("/hora normal")
	Net.log_line("portal_capture_done", {})
	get_tree().quit(0)


func _visit(label: String, portal: String) -> void:
	await _go_near(portal)
	await _cmd("/dia")
	await _wait(LIGHT_SEC)
	await _shot("%s_dia" % label)
	await _cmd("/noite")
	await _wait(LIGHT_SEC)
	await _shot("%s_noite" % label)
	await _cmd("/dia")


## Teleporta para perto do portal (na direção do approach_position), com o portal à frente na tela.
func _go_near(portal: String) -> void:
	var area: Area3D = _find_portal(portal)
	if area == null:
		Net.log_line("portal_capture_missing", {"portal": portal})
		return
	var p: Vector3 = area.global_position
	var ap: Variant = area.get_meta(&"approach_position", null)
	var dir := Vector3(0, 0, 1)
	if ap is Vector3:
		var v: Vector3 = (ap as Vector3) - p
		v.y = 0.0
		if v.length() > 0.2:
			dir = v.normalized()
	var stand: Vector3 = p + dir * STAND_OFF
	NetProgress.send_debug(&"teleport", [stand.x, stand.z])
	await _wait(SETTLE_SEC)
	var fx: Node = area.get_node_or_null(^"PortalFx")
	var gate: Node = area.get_node_or_null(^"Gate")
	Net.log_line("portal_capture_near", {"portal": portal, "fx": fx != null,
		"gate_hidden": gate == null or not (gate as Node3D).visible, "pos": str(stand)})


func _find_portal(portal: String) -> Area3D:
	var root: Node = get_node_or_null(INSTANCES)
	if root == null:
		return null
	for inst: Node in root.get_children():
		var a: Node = inst.get_node_or_null("Map/Interactables/" + portal)
		if a is Area3D:
			return a as Area3D
	return null


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
	Net.log_line("portal_capture_shot", {"file": path})
