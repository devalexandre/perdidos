extends SceneTree
## Captura da cidade com os NPCs (quadro idle S de cada NpcDef) nos marcadores de NpcPoints e o Viajante
## no SpawnPoint. So para conferencia de arte e posicao (o jogo usa o visual do cliente, de B).
##   xvfb-run godot --path game --resolution 960x540 --script res://tools/art/render_npcs.gd -- --out=/dir

var shots := [
	["npcs_masters", Vector3(-12, 1, -11), 20.0, 13.0],
	["npcs_market", Vector3(6, 1, 5), -10.0, 14.0],
	["npcs_docks", Vector3(40, 1, -8), -30.0, 18.0],
	["npcs_gate", Vector3(0, 1, -52), 0.0, 12.0],
	["npcs_plaza", Vector3(1, 1, 1), 0.0, 20.0],
]


func _initialize() -> void:
	var out := "."
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var map := (load("res://scenes/maps/city_awakening.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(map)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 50.0
	_run.call_deferred(cam, out, map)


func _sprite(parent: Node3D, sheet: String, pos: Vector3) -> void:
	var s := Sprite3D.new()
	s.texture = load(sheet) as Texture2D
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 96, 96)
	s.pixel_size = 1.0 / 48.0
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.scale = Vector3(1, 1.41, 1) # compensa o achatamento do billboard eixo Y com a camera a 45 graus
	s.position = pos + Vector3(0, 1.0 * 1.41, 0)
	parent.add_child(s)


func _run(cam: Camera3D, out: String, map: Node3D) -> void:
	await process_frame # autoload Content pronto
	var npcs: Dictionary = root.get_node("Content").call(&"all", &"npcs")
	print("npcs: ", npcs.size())
	for id: StringName in npcs:
		var n: NpcDef = npcs[id]
		var m := map.get_node("NpcPoints/" + String(n.spawn_marker)) as Node3D
		var sheet := n.sprite_base + ("_sit.png" if n.routine == NpcDef.Routine.SIT else "_idle.png")
		_sprite(map, sheet, m.position)
	_sprite(map, "res://assets/characters/chr_traveler_male_idle.png", map.get_node("SpawnPoint").position)
	for sh: Array in shots:
		var target: Vector3 = sh[1]
		var yaw := deg_to_rad(sh[2])
		var dist: float = sh[3]
		var pitch := deg_to_rad(45.0)
		cam.look_at_from_position(target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist, target, Vector3.UP)
		for i in 8:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out, sh[0]])
		print("shot ", sh[0])
	quit()
