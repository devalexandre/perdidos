extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var saved: int = EnvQuality.current
	EnvQuality.current = EnvQuality.Preset.ALTA
	var script: Script = load("res://scripts/client/combat/spell_impact_layers.gd")
	var effect: Node3D = script.new()
	effect.set(&"style", &"ice")
	effect.set(&"cone", true)
	effect.set(&"radius", 2.0)
	root.add_child(effect)
	effect.set_process(false)
	var shards: Array = effect.get(&"_shards")
	check(shards.size() == 8, "alta usa oito cristais volumosos")
	var in_cone: bool = true
	for shard: MeshInstance3D in shards:
		in_cone = in_cone and shard.position.z < 0.0 and absf(shard.position.x / shard.position.z) < 0.7
	check(in_cone, "cristais respeitam direção do cone")
	effect.call("_process", 0.12)
	check(not is_equal_approx(shards[0].scale.y, shards[3].scale.y), "cristais surgem em tempos diferentes")
	check(shards[0].mesh.get_aabb().size.z > 0.0, "cristais têm profundidade real")
	check(is_zero_approx(shards[0].position.y), "base dos cristais permanece no chão ao surgir")
	effect.call("_process", float(effect.get(&"duration")) + 0.25)
	await process_frame
	check(not is_instance_valid(effect), "impacto se dissipa e limpa seus nós")
	effect = script.new()
	effect.set(&"style", &"ice")
	effect.set(&"cone", true)
	effect.set(&"wave", true)
	effect.set(&"radius", 6.0)
	effect.set(&"duration", 1.25)
	root.add_child(effect)
	effect.set_process(false)
	shards = effect.get(&"_shards")
	check(shards.size() == 12, "rajada usa doze cristais na qualidade alta")
	effect.call("_process", 0.15)
	check(shards[0].scale.y > 0.1 and shards.back().scale.y < 0.01, "onda cresce do início até a ponta do cone")
	effect.call("_process", 0.4)
	check(shards.back().scale.y > 1.0 and shards.back().position.length() <= 6.0, "cristais chegam ao fundo sem ultrapassar o alcance")
	effect.free()
	var electric: Node3D = script.new()
	electric.set(&"style", &"electric")
	root.add_child(electric)
	electric.set_process(false)
	var healing: Node3D = script.new()
	healing.set(&"style", &"nature")
	root.add_child(healing)
	healing.set_process(false)
	check(float(electric.get(&"duration")) < float(healing.get(&"duration")), "descarga acaba antes da cura")
	check((electric.get(&"_particles") as CPUParticles3D).explosiveness > (healing.get(&"_particles") as CPUParticles3D).explosiveness, "cura distribui partículas enquanto a descarga as solta juntas")
	electric.free()
	healing.free()
	var fire: Node3D = script.new()
	fire.set(&"style", &"fire")
	root.add_child(fire)
	fire.set_process(false)
	var plumes: Array = fire.get(&"_plumes")
	check(plumes.size() == 3 and plumes[0].mesh.get_aabb().size.z > 0.0, "fogo tem três línguas com profundidade")
	fire.call("_process", 0.1)
	var first_position: Vector3 = plumes[0].position
	fire.call("_process", 0.2)
	check(not plumes[0].position.is_equal_approx(first_position), "línguas de fogo mudam de posição durante a dissipação")
	fire.free()
	EnvQuality.current = EnvQuality.Preset.BAIXA
	effect = script.new()
	effect.set(&"style", &"ice")
	root.add_child(effect)
	effect.set_process(false)
	check((effect.get(&"_shards") as Array).size() == 5, "baixa reduz cristais")
	check((effect.get(&"_particles") as CPUParticles3D).amount == 6, "baixa reduz partículas")
	effect.free()
	var caster := Node3D.new()
	root.add_child(caster)
	effect = script.new()
	effect.set(&"persistent", true)
	effect.set(&"follow", caster)
	root.add_child(effect)
	effect.set_process(false)
	caster.free()
	effect.call("_process", 0.03)
	await process_frame
	check(not is_instance_valid(effect), "muralha desaparece se o conjurador sai da cena")
	var projectile := Node3D.new()
	root.add_child(projectile)
	var trail: MeshInstance3D = (load("res://scripts/client/combat/spell_trail.gd") as Script).new()
	trail.set(&"follow", projectile)
	root.add_child(trail)
	trail.set_process(false)
	for i: int in 30:
		projectile.position = Vector3(i * 0.2, 1.0, sin(i * 0.2))
		trail.call("_process", 0.03)
	var points: Array = trail.get(&"_points")
	check(points.size() == 7, "rastro mantém histórico limitado por qualidade")
	check(points.back() == projectile.global_position and trail.mesh.get_surface_count() == 1, "rastro segue trajetória real")
	projectile.free()
	trail.call("_process", 0.2)
	await process_frame
	check(not is_instance_valid(trail), "rastro se dissolve após fim do projétil")
	EnvQuality.current = EnvQuality.Preset.ALTA
	var origin := Node3D.new()
	root.add_child(origin)
	var fx: Node3D = (load("res://scripts/client/combat/skill_fx.gd") as Script).new()
	fx.set(&"find_entity", func(id: int) -> Node3D: return origin if id == 1 else null)
	root.add_child(fx)
	fx.set_process(false)
	var frost: Resource = load("res://data/skills/arcane_frost_burst.tres")
	var context: Dictionary = {"def": frost, "caster_id": 1, "target_id": 0, "pos": Vector3(6, 0, 0), "recipe": &"frost", "contacted": false}
	fx.call("_frost", context)
	var volume: Node3D = fx.get_node(^"FrostBurstVolume")
	check(absf(angle_difference(volume.rotation.y, -PI / 2.0)) < 0.05, "rajada volumosa acompanha a direção escolhida")
	check(float(volume.get(&"radius")) == float(frost.get(&"radius_cells")) * float(fx.call("_cell")), "onda principal preserva raio da skill")
	var sprites: int = 0
	var flashes: int = 0
	for child: Node in fx.get_children():
		if child is SkillFxSprite:
			sprites += 1
		if child.get_script() == load("res://scripts/client/combat/spell_contact_flash.gd"):
			flashes += 1
	check(sprites == 0 and flashes == 1, "rajada troca figuras planas por volume e um clarão de contato")
	fx.call("_add_spell_impact", {"def": load("res://data/skills/arcane_crystal_wall.tres"), "caster_id": 1, "target_id": 0}, Vector3.ZERO)
	flashes = 0
	for child: Node in fx.get_children():
		if child.get_script() == load("res://scripts/client/combat/spell_contact_flash.gd"):
			flashes += 1
	check(flashes == 2, "muralha também recebe clarão ao ativar")
	fx.free()
	origin.free()
	EnvQuality.current = saved
	print("test_spell_layers: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
