extends Node
## Captura do efeito de subir de nível sobre a cena de lookdev (uso: xvfb-run godot --path game res://tests/client/test_level_up_fx.tscn -- --out=DIR).
func _ready() -> void:
	var out := "user://"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var scene: Node = (load("res://scenes/lookdev/forest_clearing.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().create_timer(1.0).timeout
	var target: Node3D = null
	for n: Node in scene.find_children("*", "Node3D", true, false):
		if String(n.name).to_lower().contains("viajante") or String(n.name).to_lower().contains("traveler") or String(n.name).to_lower().contains("hero"):
			target = n as Node3D
			break
	if target == null:
		target = Node3D.new(); scene.add_child(target)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.global_position = target.global_position + Vector3(0, 5.5, 5.5)
	cam.look_at(target.global_position + Vector3(0, 1.0, 0))
	cam.fov = 45.0
	cam.make_current()
	var fx := LevelUpFx.new()
	add_child(fx)
	fx.play_at(target, 5)
	for i: int in 3:
		await get_tree().create_timer(0.35).timeout
		get_viewport().get_texture().get_image().save_png("%s/level_up_%d.png" % [out, i])
	print("RESULT: %s (efeitos=%d, alvo=%s)" % ["PASS" if fx.effects_spawned == 1 else "FAIL", fx.effects_spawned, target.name])
	get_tree().quit()
