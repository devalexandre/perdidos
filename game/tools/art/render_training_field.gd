extends SceneTree
## Capturas do Campo de Treino (precisa de GPU/tela: DISPLAY=:0 ou xvfb-run).
##   godot --path game --resolution 960x540 --script res://tools/art/render_training_field.gd -- --out=/dir [--only=nome,nome]
## Camera perspectiva a 45 graus, como no jogo (GDD 17.2). Uma captura por zona + visao geral.

const BF := preload("res://tools/art/build_training_field.gd")

var shots := [
	# nome, alvo, yaw (graus), distancia, fov
	["overview", Vector3(0, 0, 0), 0.0, 190.0, 50.0],
	["camp", Vector3(0, 0, 0), 20.0, 24.0, 50.0],
	["portal", Vector3(5.5, 1, -14), 160.0, 14.0, 50.0],
	["pindorama_rancho", Vector3(0, 1, 36), 15.0, 22.0, 50.0],
	["pindorama_vereda", Vector3(-12, 0, 56), -25.0, 22.0, 50.0],
	["pindorama_south", Vector3(0, 0, 74), 10.0, 26.0, 50.0],
	["pindorama_wide", Vector3(0, 0, 55), 0.0, 60.0, 50.0],
]


func _initialize() -> void:
	var out := "."
	var only := []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	for n: Array in BF.NATIONS:
		var c: Vector3 = BF.pol(n[1], BF.ZONE_R)
		# camera do lado do acampamento olhando para fora (o Mestre de frente)
		var yaw := rad_to_deg(atan2(-c.x, -c.z)) + 180.0
		shots.append(["nation_" + String(n[0]), c, yaw + 180.0, 26.0, 50.0])
	var map := (load("res://scenes/maps/training_field.tscn") as PackedScene).instantiate()
	root.add_child(map)
	var cam := Camera3D.new()
	cam.far = 600.0
	root.add_child(cam)
	cam.current = true
	_run.call_deferred(cam, out, only)


func _run(cam: Camera3D, out: String, only: Array) -> void:
	for s: Array in shots:
		if not only.is_empty() and not only.has(s[0]):
			continue
		var target: Vector3 = s[1]
		var yaw := deg_to_rad(s[2])
		var dist: float = s[3]
		cam.fov = s[4]
		var pitch := deg_to_rad(45.0 if s[0] != "overview" else 70.0)
		var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
		cam.look_at_from_position(target + off, target, Vector3.UP)
		for i in 10:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/tf_%s.png" % [out, s[0]])
		print("shot ", s[0])
	quit()
