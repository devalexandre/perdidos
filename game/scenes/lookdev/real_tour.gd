extends Node
## Tour de validação no CLIENTE REAL (docs/arte-cenario.md): roda o jogo normal (esta cena herda main.tscn) e, depois
## de entrar no Campo de Treino, anda com o personagem de verdade (pedidos de movimento ao servidor) até cada ponto e
## salva a tela inteira (mundo + interface).
##   godot --path game --resolution 1920x1080 res://scenes/lookdev/real_tour.tscn -- --name=X --port=P \
##       --tour-out=/dir [--tour=camp,pindorama,japao,...]
## Pontos: entradas das zonas (ao lado da trilha, fora dos grupos de monstros).

const STEP_M: float = 18.0
const SETTLE_SEC: float = 2.5
const POINTS := {"camp": Vector3(0, 0, 4), "rancho": Vector3(2, 0, 30), "pindorama": Vector3(1, 0, 50)}
## Zonas das nações: ângulo (graus) no anel; o personagem para a 58 m do centro e a câmera olha para fora
## (a vinheta fica à frente, o Mestre ao lado).
const ZONES := {"portugal": 145.0, "grecia": 177.0, "egito": 208.0, "celta": 239.0, "nordico": 270.0,
	"eslavo": 301.0, "china": 332.0, "japao": 3.0, "mexico": 34.0}
const ZONE_STAND_R: float = 58.5

var _out := "user://tour"
var _list: PackedStringArray = ["camp", "pindorama", "japao", "mexico", "egito", "grecia"]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tour-out="):
			_out = a.trim_prefix("--tour-out=")
		elif a.begins_with("--tour="):
			_list = a.trim_prefix("--tour=").split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var player: Node3D = null
	var view: ClientView = null
	for i in 600:
		await get_tree().process_frame
		view = get_tree().root.find_children("*", "ClientView", true, false).front() if not get_tree().root.find_children("*", "ClientView", true, false).is_empty() else null
		for n: Node in get_tree().root.find_children("*", "", true, false):
			if n is Node3D and n.has_method(&"is_local_player") and bool(n.call(&"is_local_player")):
				player = n
				break
		if player != null and view != null:
			break
	if player == null:
		print("tour: sem jogador local")
		get_tree().quit(1)
		return
	await get_tree().create_timer(4.0).timeout
	_shot("00_spawn")
	var k := 1
	for name: String in _list:
		var target: Vector3 = POINTS.get(name, Vector3.ZERO)
		var look_out := Vector3.ZERO
		if ZONES.has(name):
			var a := deg_to_rad(float(ZONES[name]))
			look_out = Vector3(cos(a), 0, sin(a))
			target = look_out * ZONE_STAND_R
		for step in 30:
			var pos := player.global_position
			var d := target - pos
			d.y = 0
			if d.length() < 1.5:
				break
			var goal := pos + d.normalized() * minf(d.length(), STEP_M)
			view.move_requested.emit(goal)
			await get_tree().create_timer(minf(d.length(), STEP_M) * 0.24 + 0.4).timeout
		if look_out != Vector3.ZERO:
			view.camera_yaw = atan2(-look_out.x, -look_out.z)
			view.camera_zoom = Balance.cfg.camera_zoom_min
		await get_tree().create_timer(SETTLE_SEC).timeout
		_shot("%02d_%s" % [k, name])
		view.camera_yaw = 0.0
		view.camera_zoom = 1.0
		k += 1
	get_tree().quit(0)


func _shot(name: String) -> void:
	var path := _out.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	var dc := 0
	var prim := 0
	for vp: Node in get_tree().root.find_children("*", "SubViewport", true, false):
		var rid: RID = (vp as SubViewport).get_viewport_rid()
		dc += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		prim += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	print("tour saved %s draw_calls=%d primitives=%d fps=%d" % [path, dc, prim, Engine.get_frames_per_second()])
