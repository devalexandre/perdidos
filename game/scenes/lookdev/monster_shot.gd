extends Node
## Captura no CLIENTE REAL dos monstros feitos no Blender (Agente B3, docs/arte-monstros-blender.md): roda o jogo
## normal (herda main.tscn), teleporta (comando de debug; servidor com --progression-autotest) para perto de cada
## grupo do Campo de Treino, tira uma foto parado e uma rajada enquanto luta com o monstro mais perto.
##   servidor: godot --headless --path game -- --server --port=P --progression-autotest --always-hit
##   cliente:  godot --path game --resolution 1920x1080 res://scenes/lookdev/monster_shot.tscn -- --name=X --port=P \
##             --shot-out=/dir [--targets=stone_armadillo,prank_whirlwind,enchanted_firefly] [--burst=24]

const SPOTS := {
	&"stone_armadillo": Vector3(-12, 0, 79), &"prank_whirlwind": Vector3(-17, 0, 42),
	&"enchanted_firefly": Vector3(-27, 0, 63), &"dune_scorpion": Vector3(-53.8, 0, -19.4),
	&"fountain_serpent": Vector3(-42.2, 0, 38.9), &"griffin_chick": Vector3(-56.1, 0, 11.1),
	&"hopping_jiangshi": Vector3(46.6, 0, -33.5), &"jaguar_cub": Vector3(42.4, 0, 38.4),
	&"kasa_obake": Vector3(56.9, 0, -5.1), &"lake_kelpie": Vector3(-22.2, 0, -52.7),
	&"lindworm_hatchling": Vector3(8.1, 0, -56.6), &"little_chimera": Vector3(-56.9, 0, -5.1),
	&"moss_troll": Vector3(-8.1, 0, -56.6), &"obsidian_iguana": Vector3(51.5, 0, 24.9),
	&"puca_trickster": Vector3(-36.1, 0, -44.3), &"sphinx_cub": Vector3(-46.2, 0, -33.7),
	&"spirit_fox_cub": Vector3(53.8, 0, -20.0), &"trasgo_imp": Vector3(-51.0, 0, 26.4),
	&"trickster_tanuki": Vector3(56.1, 0, 11.1), &"walking_hut": Vector3(36.1, 0, -44.3),
	&"zmey_hatchling": Vector3(22.2, 0, -52.7),
}
const BURST_EVERY_SEC: float = 0.12
const WAIT_SEC: float = 8.0

var _out := "user://monster_shot"
var _targets: PackedStringArray = ["stone_armadillo", "prank_whirlwind", "enchanted_firefly"]
var _burst: int = 24
var _local: NetEntity = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot-out="):
			_out = a.trim_prefix("--shot-out=")
		elif a.begins_with("--targets="):
			_targets = a.trim_prefix("--targets=").split(",")
		elif a.begins_with("--burst="):
			_burst = int(a.trim_prefix("--burst="))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	for i in 900:
		await get_tree().process_frame
		for n: Node in get_tree().root.find_children("*", "", true, false):
			if n is NetEntity and (n as NetEntity).is_local_player():
				_local = n
				break
		if _local != null:
			break
	if _local == null:
		print("monster_shot: sem jogador local")
		get_tree().quit(1)
		return
	await _sleep(4.0)
	for t: String in _targets:
		var spot: Vector3 = SPOTS.get(StringName(t), Vector3.ZERO)
		# fica ao sul do grupo (a câmera olha para +Z... o bando fica à frente na tela)
		# ao sul do grupo; se o servidor recusar (ponto bloqueado), tenta outros lados
		for off: Vector3 in [Vector3(0, 0, -4.5), Vector3(0, 0, 4.5), Vector3(4.5, 0, 0), Vector3(-4.5, 0, 0),
				Vector3(0, 0, -2.0), Vector3(2.0, 0, 2.0)]:
			if await _teleport(spot + off):
				break
		await _sleep(3.0)
		var mon: NetEntity = _find(StringName(t), _local.position)
		if mon == null:
			print("monster_shot: nenhum %s perto" % t)
			continue
		_shot("%s_00_idle" % t)
		NetCombat.send_attack(mon.entity_id)
		for k in _burst:
			await _sleep(BURST_EVERY_SEC)
			_shot("%s_%02d_fight" % [t, k + 1])
		NetCombat.send_stop_attack()
		await _sleep(1.0)
	print("monster_shot: ok")
	get_tree().quit(0)


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _teleport(p: Vector3) -> bool:
	NetProgress.send_debug(&"teleport", [p.x, p.z])
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(3.0 * 1000):
		if Vector2(_local.position.x - p.x, _local.position.z - p.z).length() < 1.5:
			return true
		await get_tree().process_frame
	return false


func _find(def_id: StringName, near: Vector3) -> NetEntity:
	var best: NetEntity = null
	var best_d: float = INF
	for n: Node in _local.get_parent().get_children():
		var e := n as NetEntity
		if e == null or e.is_queued_for_deletion() or e.def_id != def_id or e.hp_ratio <= 0.0 or e.stage > 1:
			continue
		var d: float = e.position.distance_to(near)
		if d < best_d:
			best_d = d
			best = e
	return best


func _shot(name: String) -> void:
	var path := _out.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("monster_shot saved %s fps=%d" % [path, Engine.get_frames_per_second()])
