extends SceneTree
class FakeCaster extends Node3D:
	var hp_ratio: float = 1.0

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var caster := FakeCaster.new()
	root.add_child(caster)
	var fx: Node3D = (load("res://scripts/client/combat/skill_fx.gd") as Script).new()
	fx.set(&"find_entity", func(_id: int) -> Node3D: return caster)
	root.add_child(fx)
	fx.set_process(false)
	var def: Resource = load("res://data/skills/arcane_spark.tres")
	fx.call("play", def, 101, 0, Vector3.ZERO, 2000)
	var flows: Dictionary = fx.get(&"_charge_flows")
	var flow: Node3D = flows[101]
	flow.set_process(false)
	_check(is_equal_approx(float(flow.get(&"duration")), 2.0), "carga dura o tempo da skill")
	var charge_color: Color = flow.get(&"color")
	_check(charge_color.r > charge_color.g and charge_color.g > charge_color.b, "Lança de Fogo prepara energia laranja")
	var circles: Dictionary = fx.get(&"_cast_circles")
	var circle: Node3D = circles[101]
	var sprite_material: ShaderMaterial = circle.get(&"_mat")
	_check(bool(sprite_material.get_shader_parameter(&"charge_recolor")), "clarão antigo é recolorido durante carga")
	charge_color = sprite_material.get_shader_parameter(&"charge_color")
	_check(charge_color == flow.get(&"color"), "clarão e fluxo usam a mesma cor da magia")
	caster.position = Vector3(3, 0, 2)
	flow.call("_process", 0.5)
	_check(flow.global_position == caster.global_position, "energia acompanha conjurador")
	_check(not bool(flow.get(&"stopping")), "energia continua durante carga")
	fx.call("_on_cast_cancelled", 101, &"arcane_spark")
	_check(bool(flow.get(&"stopping")) and (fx.get(&"_charge_flows") as Dictionary).is_empty(), "cancelamento encerra energia")
	flow.call("_process", 0.2)
	await process_frame
	_check(not is_instance_valid(flow), "energia cancelada é removida após fade")
	for skill_id: String in ["arcane_frost_burst", "arcane_will_o_wisp", "support_bottle_brew", "bow_taut_draw"]:
		var skill: Resource = load("res://data/skills/%s.tres" % skill_id)
		fx.call("play", skill, 101, 0, Vector3.ZERO, 2000)
		flows = fx.get(&"_charge_flows")
		var active_flow: Node3D = flows[101]
		var tint: Color = active_flow.get(&"color")
		if skill_id == "arcane_frost_burst":
			_check(tint.b > tint.g and tint.g > tint.r, "gelo prepara energia azul")
		else:
			_check(tint.g > tint.r and tint.g > tint.b, "%s usa carga verde" % skill_id)
		circles = fx.get(&"_cast_circles")
		if circles.has(101):
			var active_circle: Node3D = circles[101]
			var mat: ShaderMaterial = active_circle.get(&"_mat")
			_check(mat.get_shader_parameter(&"charge_color") == tint, "%s mantém brilho e fluxo na mesma cor" % skill_id)
		fx.call("_on_cast_cancelled", 101, skill.get(&"id"))
		active_flow.call("_process", 0.2)
		await process_frame
	var blade: Resource = load("res://data/skills/blade_firm_strike.tres")
	fx.call("_start_charge_flow", 101, caster, blade, 0.4)
	flows = fx.get(&"_charge_flows")
	flow = flows[101]
	charge_color = flow.get(&"color")
	_check(charge_color.r > charge_color.g and charge_color.g > charge_color.b, "habilidade de lâmina prepara energia dourada")
	flow.set_process(false)
	flow.call("_process", 0.5)
	_check(bool(flow.get(&"stopping")), "liberação encerra a carga automaticamente")
	await process_frame
	fx.call("_start_charge_flow", 101, caster, load("res://data/skills/support_bottle_brew.tres"), 2.0)
	flows = fx.get(&"_charge_flows")
	flow = flows[101]
	flow.set_process(false)
	caster.hp_ratio = 0.0
	flow.call("_process", 0.2)
	await process_frame
	_check(not is_instance_valid(flow), "morte do conjurador limpa carga")
	caster.hp_ratio = 1.0
	fx.call("_start_charge_flow", 101, caster, load("res://data/skills/support_bottle_brew.tres"), 2.0)
	flows = fx.get(&"_charge_flows")
	flow = flows[101]
	flow.set_process(false)
	caster.free()
	flow.call("_process", 0.2)
	await process_frame
	_check(not is_instance_valid(flow), "remover conjurador limpa carga")
	fx.free()
	print("test_skill_charge_flow: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
