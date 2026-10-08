extends Node3D
## Portal que responde à aproximação (PortalFx, 08/10/2026): cálculo do proximity, amortecimento e o estado de
## runas/fagulhas/luz/cristais. Roda headless: res://tests/client/test_portal_proximity.tscn

var _failures: int = 0


func _ready() -> void:
	# 1) Alvo pela distância no plano.
	_check(is_equal_approx(PortalFx.proximity_for_distance(PortalFx.PROX_FAR), 0.0), "longe (8 m) = 0")
	_check(is_equal_approx(PortalFx.proximity_for_distance(20.0), 0.0), "bem longe = 0")
	_check(is_equal_approx(PortalFx.proximity_for_distance(PortalFx.PROX_NEAR), 1.0), "borda do aro = 1")
	_check(is_equal_approx(PortalFx.proximity_for_distance(0.0), 1.0), "no centro = 1")
	var mid: float = PortalFx.proximity_for_distance(4.8)
	_check(mid > 0.3 and mid < 0.7, "meio do caminho fica no meio (%.2f)" % mid)
	var mono: bool = true
	var last: float = 1.0
	for i: int in 41:
		var v: float = PortalFx.proximity_for_distance(float(i) * 0.25)
		mono = mono and v <= last + 0.00001
		last = v
	_check(mono, "proximity só cai com a distância")
	# 2) Amortecimento: não pula, converge, independe do FPS.
	var one_step: float = PortalFx.damp_proximity(0.0, 1.0, 1.0 / 60.0)
	_check(one_step > 0.0 and one_step < 0.1, "um quadro sobe pouco (%.3f)" % one_step)
	var fast: float = 0.0
	var slow: float = 0.0
	for i: int in 120:
		fast = PortalFx.damp_proximity(fast, 1.0, 1.0 / 120.0)
	for i: int in 30:
		slow = PortalFx.damp_proximity(slow, 1.0, 1.0 / 30.0)
	_check(absf(fast - slow) < 0.01, "mesmo resultado a 120 e 30 FPS (%.3f / %.3f)" % [fast, slow])
	var conv: float = 0.0
	for i: int in 300:
		conv = PortalFx.damp_proximity(conv, 1.0, 1.0 / 60.0)
	_check(is_equal_approx(conv, 1.0), "converge para o alvo")
	_check(PortalFx.damp_proximity(1.0, 0.0, 1.0 / 60.0) > 0.95, "apagar também é suave")
	# 3) Quantidade de fagulhas por qualidade.
	_check(PortalFx.spark_amount(EnvQuality.Preset.BAIXA, false) <= 6, "BAIXA: poucas fagulhas")
	_check(PortalFx.spark_amount(EnvQuality.Preset.ALTA, true) <= 6, "mobile: poucas fagulhas")
	_check(PortalFx.spark_amount(EnvQuality.Preset.ALTA, false) > PortalFx.spark_amount(EnvQuality.Preset.MEDIA, false),
			"ALTA tem mais que MÉDIA")
	_check(PortalFx.flame_ring_count(EnvQuality.Preset.BAIXA, false) < PortalFx.flame_ring_count(EnvQuality.Preset.ALTA, false)
			and PortalFx.flame_ring_count(EnvQuality.Preset.ALTA, true) < 3, "BAIXA/mobile: menos anéis de chama")
	# 4) Um portal de verdade com um "jogador" de teste.
	var player := Node3D.new()
	add_child(player)
	var fx := PortalFx.new()
	fx.focus_override = player
	add_child(fx)
	await get_tree().process_frame
	player.global_position = Vector3(12.0, 0.0, 0.0)
	_step(fx, 1.0, 10)
	_check(fx.proximity < 0.001, "longe: portal calmo")
	_check(fx.flame_materials.size() == PortalFx.flame_ring_count(EnvQuality.current, false), "anéis de chama conforme a qualidade")
	_check(fx.get_node_or_null(^"PortalRim") == null and fx.get_node_or_null(^"Crystal0") == null,
			"sem o aro escuro e sem os cristais antigos")
	var far_opacity: float = float((fx.sparks.mesh.surface_get_material(0) as ShaderMaterial).get_shader_parameter(&"opacity"))
	var light: OmniLight3D = fx.get_node(^"PortalGlow") as OmniLight3D
	var far_light: float = light.light_energy
	player.global_position = Vector3(1.0, 0.0, 0.5)
	fx._process(1.0 / 60.0)
	_check(fx.target_proximity > 0.99 and fx.proximity < 0.1, "chegar perto não pula (%.3f)" % fx.proximity)
	_step(fx, 3.0, 60)
	_check(fx.proximity > 0.99, "perto: proximity ~1 (%.3f)" % fx.proximity)
	var near_opacity: float = float((fx.sparks.mesh.surface_get_material(0) as ShaderMaterial).get_shader_parameter(&"opacity"))
	_check(fx.sparks.emitting and near_opacity > far_opacity, "perto: pontinhos de luz mais fortes")
	_check(light.light_energy > far_light + 0.5, "perto: luz mais forte")
	var disc_p: float = float(fx.disc_material.get_shader_parameter(&"proximity"))
	var flame_p: float = float(fx.flame_materials[0].get_shader_parameter(&"proximity"))
	_check(disc_p > 0.99 and flame_p > 0.99, "disco e chamas recebem o proximity")
	var flow_a: float = float(fx.flame_materials[0].get_shader_parameter(&"flow"))
	_step(fx, 1.0, 10)
	var flow_b: float = float(fx.flame_materials[0].get_shader_parameter(&"flow"))
	_check(absf(flow_b - flow_a - PortalFx.FLOW_SPEED_NEAR) < 0.01, "perto: chamas sobem mais rápido")
	player.global_position = Vector3(0.0, 6.0, 0.0)
	_step(fx, 4.0, 60)
	_check(fx.proximity < 0.01, "outro andar (dy > 4 m) não conta")
	fx.focus_override = null
	_step(fx, 0.5, 10)
	_check(fx.proximity < 0.01, "sem jogador local não quebra")
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _step(fx: PortalFx, seconds: float, steps: int) -> void:
	for i: int in steps:
		fx._process(seconds / float(steps))


func _check(condition: bool, description: String) -> void:
	print(("ok   " if condition else "FAIL ") + description)
	if not condition:
		_failures += 1
