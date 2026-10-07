extends SceneTree
## Captura screenshots do mapa (precisa de GPU/tela: DISPLAY=:0 ou xvfb-run).
##   godot --path game --resolution 960x540 --script res://tools/art/render_city.gd -- --out=/dir [--scene=res://...]
## Camera perspectiva a 45 graus, como no jogo (GDD 17.2).

var shots := [
	# nome, alvo, yaw (graus), distancia, fov
	["plaza", Vector3(0, 1, 5.5), 0.0, 16.0, 50.0],
	["plaza_rot", Vector3(4, 1, 8), 135.0, 16.0, 50.0],
	["overview", Vector3(0, 0, 0), 20.0, 70.0, 50.0],
	["docks", Vector3(38, 0, 0), -60.0, 20.0, 50.0],
	["market", Vector3(6, 0, 6), -35.0, 15.0, 50.0],
	["ipe_anchor4", Vector3(0, 3, 0), 25.0, 30.0, 50.0],
	["masters", Vector3(-19, 2, -15), 60.0, 16.0, 50.0],
]


func _initialize() -> void:
	var out := "."
	var scene := "res://scenes/maps/city_awakening.tscn"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--scene="):
			scene = a.trim_prefix("--scene=")
	var map := (load(scene) as PackedScene).instantiate()
	root.add_child(map)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	_run.call_deferred(cam, out)


func _run(cam: Camera3D, out: String) -> void:
	for s: Array in shots:
		var target: Vector3 = s[1]
		var yaw := deg_to_rad(s[2])
		var dist: float = s[3]
		cam.fov = s[4]
		var pitch := deg_to_rad(45.0)
		var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
		cam.look_at_from_position(target + off, target, Vector3.UP)
		for i in 8:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/city_%s.png" % [out, s[0]])
		print("shot ", s[0])
	quit()
