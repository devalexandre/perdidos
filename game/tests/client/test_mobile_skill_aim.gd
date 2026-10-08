extends Node

var failures: int = 0
var releases: Array[bool] = []
var casts: Array[Vector3] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _ready() -> void:
	var cluster := MobileActionCluster.new()
	add_child(cluster)
	cluster.position = Vector2(950, 410)
	cluster.slot_activated.connect(cluster.begin_aim)
	cluster.aim_finished.connect(func(cancelled: bool) -> void: releases.append(cancelled))
	var button: Vector2 = cluster._slot_positions[2]
	cluster._gui_input(touch(4, button, true))
	check(cluster._aim_slot == 2 and releases.is_empty(), "Press starts aiming without casting")
	cluster._input(touch(1, Vector2.ZERO, false))
	check(cluster._aim_slot == 2, "Releasing movement finger must not cast")
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = cluster.global_position + button + Vector2(35, 0)
	cluster._input(drag)
	check(cluster._aim_offset.is_equal_approx(Vector2(35, 0)), "Drag uses button-local coordinates")
	cluster._input(touch(4, drag.position, false))
	check(releases == [false] and cluster._aim_slot == -1, "Release casts once")
	cluster._input(touch(4, drag.position, false))
	check(releases.size() == 1, "Duplicate release does not cast")
	cluster._gui_input(touch(5, button, true))
	cluster._input(touch(5, cluster.global_position + cluster._cancel_position(), false))
	check(releases == [false, true], "Release on X cancels")
	cluster._gui_input(touch(6, button, true))
	cluster.hide()
	check(releases == [false, true, true], "Hiding controls cancels")
	cluster.show()
	cluster._gui_input(touch(7, button, true))
	cluster._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(releases == [false, true, true, true], "Focus loss cancels")
	var emulated := touch(0, button, true)
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	cluster._gui_input(emulated)
	check(cluster._aim_slot == -1, "Emulated duplicate does not start another cast")
	var player := Node3D.new()
	add_child(player)
	var view := ClientView.new()
	view.camera_yaw = 0
	var aim := HotbarAim.new()
	aim.view = view
	add_child(aim)
	aim.confirmed.connect(func(_id: StringName, point: Vector3) -> void: casts.append(point))
	var skill := SkillDef.new()
	skill.id = &"test_area"
	skill.target_type = SkillDef.TargetType.GROUND_AREA
	skill.range_cells = 10
	skill.radius_cells = 2
	aim.begin(skill, player, true)
	var area_mesh: MeshInstance3D = aim._preview.get_child(0)
	check(area_mesh.mesh is PlaneMesh and is_equal_approx((area_mesh.mesh as PlaneMesh).size.x, skill.radius_cells * Balance.cfg.cell_size * 2.08), "Rune preview preserves skill radius plus transparent margin")
	var rune_material: ShaderMaterial = area_mesh.material_override
	check(rune_material.get_shader_parameter(&"color") == SkillFx.charge_color_for(skill), "Preview runes use skill color")
	check(not aim.handle_input(touch(1, Vector2.ZERO, true)), "Other fingers do not confirm world aim")
	aim.update_mobile_direction(Vector2(0.5, 0))
	player.position = Vector3(2, 0, 3)
	aim.finish_mobile(false)
	check(casts.size() == 1 and casts[0].is_equal_approx(player.position + Vector3(5 * Balance.cfg.cell_size, 0, 0)), "Area follows player and thumb distance")
	aim.begin(skill, player, true)
	aim.update_mobile_direction(Vector2(5, 0))
	check(is_equal_approx(aim._mobile_point().distance_to(player.position), 10 * Balance.cfg.cell_size), "Area stays inside range")
	aim.finish_mobile(true)
	check(casts.size() == 1 and not aim.is_aiming(), "Cancellation sends no cast")
	for skill_id: StringName in [&"arcane_creeping_flame", &"arcane_star_fall", &"support_bottle_brew"]:
		var colored_skill: SkillDef = Content.skill(skill_id)
		aim.begin(colored_skill, player, true)
		var mesh: MeshInstance3D = aim._preview.get_child(0)
		var material: ShaderMaterial = mesh.material_override
		check(material.get_shader_parameter(&"color") == SkillFx.charge_color_for(colored_skill), "%s preview matches casting color" % skill_id)
		aim.cancel(false)
	skill.target_type = SkillDef.TargetType.CONE
	view.camera_yaw = PI / 2
	aim.begin(skill, player, true)
	aim.update_mobile_direction(Vector2.UP)
	check(aim._mobile_point().x < player.position.x, "Directional skills follow camera rotation")
	aim.finish_mobile(false)
	check(casts.size() == 2, "Directional release casts once")
	view.free()
	if "--shots" in OS.get_cmdline_user_args():
		cluster._gui_input(touch(8, button, true))
		drag.index = 8
		cluster._input(drag)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/mobile-skill-aim.png")
	print("MOBILE SKILL AIM: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)
