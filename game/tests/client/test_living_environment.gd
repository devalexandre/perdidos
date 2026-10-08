extends SceneTree
## godot --headless --path game --script res://tests/client/test_living_environment.gd

const WeatherWetness = preload("res://scripts/client/env/weather_wetness.gd")
## Carregados em tempo de execução (os autoloads ainda não existem quando este script compila).
var AmbientLife: GDScript
var AmbientScan: GDScript
var CampDressing: GDScript
var BirdArt: GDScript
var Factory: GDScript
const ARRIVING: int = 0
const LANDED: int = 1
const LEAVING: int = 2
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _run() -> void:
	var map: Node3D = (load("res://scripts/shared/map.gd") as Script).new()
	map.map_id = &"training_field"
	root.add_child(map)
	_check(not map.has_node(^"LivingEnvironment"), "Headless não cria efeitos visuais do cliente")
	var atmosphere: Node3D = (load("res://scripts/client/env/living_environment.gd") as Script).new()
	map.add_child(atmosphere)
	atmosphere.set_process(false)
	atmosphere.update_daylight(0.0)
	var butterfly := atmosphere.get_node(^"CampButterflies") as CPUParticles3D
	var firefly := atmosphere.get_node(^"CampFireflies") as CPUParticles3D
	var smoke := atmosphere.get_node(^"CampSmoke") as CPUParticles3D
	_check(butterfly.visible and butterfly.emitting, "Borboletas ativas durante o dia")
	_check(not firefly.visible and not firefly.emitting, "Vagalumes desligados durante o dia")
	_check(smoke.visible and smoke.emitting, "Fogueira solta fumaça durante o dia")
	atmosphere.update_daylight(0.5)
	var bm := butterfly.mesh.material as ShaderMaterial
	var fm := firefly.mesh.material as ShaderMaterial
	_check(float(bm.get_shader_parameter(&"opacity")) > 0.0 and float(bm.get_shader_parameter(&"opacity")) < 1.0,
		"Borboletas desaparecem suavemente na transição")
	_check(float(fm.get_shader_parameter(&"opacity")) > 0.0 and float(fm.get_shader_parameter(&"opacity")) < 1.0,
		"Vagalumes aparecem suavemente na transição")
	atmosphere.update_daylight(1.0)
	_check(not butterfly.visible and not butterfly.emitting, "Borboletas desligadas à noite")
	_check(firefly.visible and firefly.emitting, "Vagalumes ativos à noite")
	_check(smoke.visible and smoke.emitting, "Fumaça continua à noite")
	_check(bm != fm, "Opacidade de cada efeito possui material independente")
	var saved: EnvQuality.Preset = EnvQuality.current
	EnvQuality.current = EnvQuality.Preset.ALTA
	atmosphere.apply_quality()
	var high_amount: int = smoke.amount
	var camp_fire: Node3D = atmosphere.get_node(^"CampFlameVolume")
	_check(camp_fire.get_child_count() == 7, "Fogueira tem múltiplas línguas de chama")
	var tongue := camp_fire.get_child(0) as MeshInstance3D
	var box: AABB = tongue.mesh.get_aabb()
	_check(box.size.x > 0.0 and box.size.z > 0.0 and box.size.y > 0.0, "Chama possui geometria em três eixos")
	var high_range: float = smoke.visibility_range_end
	EnvQuality.current = EnvQuality.Preset.BAIXA
	atmosphere.apply_quality()
	var visible_tongues: int = 0
	for child: Node3D in camp_fire.get_children():
		visible_tongues += 1 if child.visible else 0
	_check(visible_tongues == 3, "Baixa mantém chama volumosa com menos camadas")
	_check(smoke.amount < high_amount and smoke.amount >= 2, "Baixa reduz partículas mantendo fumaça")
	_check(smoke.visibility_range_end < high_range, "Baixa reduz distância dos efeitos")
	EnvQuality.current = saved
	atmosphere.update_weather(1.0, 1.0)
	atmosphere.update_daylight(0.0)
	var smoke_mat := smoke.mesh.material as ShaderMaterial
	_check(smoke.visible and float(smoke_mat.get_shader_parameter(&"opacity")) < 0.5,
		"Chuva forte rareia a fumaça sem apagar")
	_check(not butterfly.visible, "Borboletas se escondem na chuva")
	atmosphere.update_weather(0.0, 0.0)
	atmosphere.update_daylight(0.0)
	_check(is_equal_approx(float(smoke_mat.get_shader_parameter(&"opacity")), 1.0) and butterfly.visible,
		"Tempo seco devolve fumaça e borboletas")
	_test_weather()
	_test_wetness_curve()
	_test_portal(map)
	await _test_real_portals()
	AmbientLife = load("res://scripts/client/env/ambient_life.gd")
	AmbientScan = load("res://scripts/client/env/ambient_scan.gd")
	CampDressing = load("res://scripts/client/env/camp_dressing.gd")
	BirdArt = load("res://scripts/client/env/ambient_bird_art.gd")
	Factory = load("res://scripts/client/entity_visual_factory.gd")
	_test_gestures()
	await _test_birds()
	await _test_dressing()
	await _test_real_scan()
	await _test_scenery()
	map.free()
	print("test_living_environment: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _test_weather() -> void:
	var regions: Script = load("res://scripts/client/env/weather_regions.gd")
	var dry: Dictionary = regions.profile(&"training_field", Vector3(-54, 0, -29))
	var wet: Dictionary = regions.profile(&"training_field", Vector3(50, 0, 34))
	_check(float(wet["rain_factor"]) > float(dry["rain_factor"]), "Microclima úmido tem mais chuva que o deserto")
	var model: Node3D = (load("res://scripts/shared/map.gd") as Script).new()
	root.add_child(model)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	model.add_child(sun)
	var world := WorldEnvironment.new()
	var original := Environment.new()
	original.fog_depth_begin = 30.0
	original.fog_depth_end = 120.0
	original.fog_density = 0.5
	world.environment = original
	model.add_child(world)
	var light: Script = load("res://scripts/client/env/day_night_light.gd")
	var fire := OmniLight3D.new()
	fire.light_energy = 2.0
	fire.set_meta(&"rain_dim", WeatherWetness.FIRE_LIGHT_RAIN_DIM)
	model.add_child(fire)
	light.apply(model, 0.0)
	var blur: float = sun.shadow_blur
	var fire_dry: float = fire.light_energy
	model.set_meta(&"weather_visual", Vector2.ONE)
	light.apply(model, 0.0)
	_check(sun.light_energy < 1.2 and sun.shadow_enabled, "Temporal reduz luz sem remover sombras")
	_check(sun.shadow_blur > blur, "Temporal suaviza sombras")
	_check(is_equal_approx(fire.light_energy, fire_dry * (1.0 - WeatherWetness.FIRE_LIGHT_RAIN_DIM)),
		"Chuva forte abaixa a luz da fogueira (%.2f -> %.2f)" % [fire_dry, fire.light_energy])
	model.set_meta(&"weather_visual", Vector2.ZERO)
	model.set_meta(WeatherWetness.META_WETNESS, 1.0)
	light.apply(model, 0.0)
	_check(fire.light_energy < fire_dry and fire.light_energy > fire_dry * (1.0 - WeatherWetness.FIRE_LIGHT_RAIN_DIM),
		"Lenha molhada segura a chama um pouco depois da chuva")
	model.set_meta(WeatherWetness.META_WETNESS, 0.0)
	model.set_meta(&"weather_visual", Vector2.ONE)
	light.apply(model, 0.0)
	_check(world.environment.fog_enabled and world.environment.fog_depth_end < 120.0, "Neblina aparece no espaço 3D")
	_check(not original.fog_enabled and original.fog_depth_end == 120.0, "Clima não altera recurso original")
	light.apply(model, 1.0)
	_check(world.environment.fog_enabled and sun.light_energy < 0.5, "Clima combina com iluminação noturna")
	model.set_meta(&"weather_visual", Vector2.ZERO)
	light.apply(model, 0.0)
	_check(is_equal_approx(sun.light_energy, 1.2) and not world.environment.fog_enabled,
		"Tempo aberto restaura luz e neblina originais")
	model.free()


## Curva da umidade do chão: sobe ~30 s com chuva forte, seca ~75 s, chuva fraca só umedece.
func _test_wetness_curve() -> void:
	var wet: float = 0.0
	for i: int in 150: # 15 s de chuva forte
		wet = WeatherWetness.step(wet, 1.0, 0.1)
	_check(wet > 0.4 and wet < 0.6, "Chão a meio caminho de encharcado em 15 s (%.2f)" % wet)
	for i: int in 100: # +10 s
		wet = WeatherWetness.step(wet, 1.0, 0.1)
	_check(wet < 1.0, "Ainda não encharcado em 25 s (%.2f)" % wet)
	for i: int in 150: # 40 s no total
		wet = WeatherWetness.step(wet, 1.0, 0.1)
	_check(is_equal_approx(wet, 1.0), "Encharcado depois de 40 s de chuva forte")
	for i: int in 300: # 30 s sem chuva
		wet = WeatherWetness.step(wet, 0.0, 0.1)
	_check(wet > 0.5 and wet < 0.7, "Seca devagar: 30 s depois ainda úmido (%.2f)" % wet)
	for i: int in 500: # 80 s no total
		wet = WeatherWetness.step(wet, 0.0, 0.1)
	_check(wet == 0.0, "Seco 80 s depois da chuva")
	for i: int in 600:
		wet = WeatherWetness.step(wet, 0.4, 0.1)
	_check(wet > 0.4 and wet < 0.6, "Chuva fraca deixa o chão só úmido (%.2f)" % wet)
	var wet_before: float = wet
	wet = WeatherWetness.step(wet, 0.0, 1.0)
	_check(wet < wet_before and wet_before - wet < 0.02, "Secagem não salta")
	_check(is_equal_approx(WeatherWetness.fire_damp(0.0, 1.0), WeatherWetness.FIRE_WET_FACTOR)
		and WeatherWetness.fire_damp(1.0, 0.0) == 1.0 and WeatherWetness.fire_damp(0.0, 0.0) == 0.0,
		"Fogo abafado pela chuva e pela lenha molhada")
	var map := Node3D.new()
	map.set_meta(&"weather_visual", Vector2(1.0, 0.0))
	for i: int in 10:
		WeatherWetness.advance(map, 1.0)
	_check(float(map.get_meta(WeatherWetness.META_WETNESS)) > 0.3, "Umidade acumulada fica no mapa")
	map.free()
	WeatherWetness.publish(0.5, 0.25) # servidor de renderização dummy: só não pode quebrar


func _test_portal(map: Node3D) -> void:
	var interactables := Node3D.new()
	interactables.name = &"Interactables"
	map.add_child(interactables)
	var area := Area3D.new()
	area.set_meta(&"interact_type", &"portal")
	area.set_meta(&"target_map", &"fields_pindorama")
	interactables.add_child(area)
	var portals: Script = load("res://scripts/client/combat/portal_fx.gd")
	_check(portals.decorate_map(map) == 1, "Portal recebe decoração")
	var fx: Node3D = area.get_node(^"PortalFx")
	_check(fx.has_node(^"Disc") and fx.has_node(^"Flames0") and fx.has_node(^"Sparks"), "Portal recebe disco, chamas e fagulhas")
	_check(portals.decorate_map(map) == 0 and area.get_meta(&"target_map") == &"fields_pindorama",
		"Decoração não duplica e preserva destino do portal")


func _test_real_portals() -> void:
	var portals: Script = load("res://scripts/client/combat/portal_fx.gd")
	for id: String in ["training_field", "city_awakening", "fields_pindorama", "enchanted_forest", "split_sky_plateau"]:
		var map: Node3D = (load("res://scenes/maps/%s.tscn" % id) as PackedScene).instantiate()
		root.add_child(map)
		await physics_frame
		var destinations: Dictionary = {}
		for area: Node in map.get_node(^"Interactables").get_children():
			if area.get_meta(&"interact_type", &"") == &"portal":
				destinations[area] = area.get_meta(&"target_map", &"")
		_check(portals.decorate_map(map) == destinations.size() and not destinations.is_empty(),
			"%s: todos os portais decorados" % id)
		for area: Node in destinations:
			_check(area.has_node(^"PortalFx/Disc") and area.get_meta(&"target_map", &"") == destinations[area],
				"%s: detalhes e destino preservados" % id)
		_check(portals.decorate_map(map) == 0, "%s: decoração idempotente" % id)
		map.free()



# --- vida no acampamento (08/10/2026): gestos de NPC, passarinhos e sinais de uso ----------------------------

func _test_gestures() -> void:
	var v: Node3D = Factory.call(&"create_from", &"npc", &"__sem_def__", 1000001, "Teste")
	root.add_child(v)
	var g: Node = v.get_node_or_null(^"Gestures")
	_check(g != null, "Todo NPC ganha o nó de gestos pela fábrica")
	var player: Node3D = Factory.call(&"create_from", &"player", &"male", 7, "Jogador")
	_check(player.get_node_or_null(^"Gestures") == null, "Jogador não ganha gestos de NPC")
	player.free()
	if g == null:
		v.free()
		return
	g.set_process(false)
	_check(v.process_priority > 0, "Visual do NPC roda depois do nó de gestos (virada vale no mesmo quadro)")
	v.facing_yaw = 0.3
	g.set(&"rest_yaw", 0.3)
	_check(bool(g.call(&"force_gesture", &"look")), "NPC parado aceita gesto")
	g.call(&"step", 0.5)
	_check(absf(absf(v.facing_yaw - 0.3) - TAU / 8.0) < 0.001, "Olhar para o lado vira um setor (%.2f)" % v.facing_yaw)
	for i: int in 30:
		g.call(&"step", 0.1)
	_check(is_equal_approx(v.facing_yaw, 0.3) and g.get(&"gesture") == &"", "Depois do gesto volta à direção de antes")
	g.call(&"force_gesture", &"stretch")
	g.call(&"step", 0.75)
	_check(v.scale.y > 1.02, "Espreguiçar estica o corpo (%.3f)" % v.scale.y)
	for i: int in 20:
		g.call(&"step", 0.1)
	v.call(&"cancel_cast") # sem quadros de verdade aqui, a folha de conjuração não termina sozinha
	_check(v.scale.is_equal_approx(Vector3.ONE) and v.position.is_equal_approx(Vector3.ZERO), "Gesto termina no idle sem escala nem deslocamento")
	g.call(&"force_gesture", &"scratch")
	g.call(&"step", 0.3)
	v.anim = &"walk"
	g.call(&"step", 0.05)
	_check(g.get(&"gesture") == &"" and v.scale.is_equal_approx(Vector3.ONE), "Andando cancela o gesto")
	_check(not bool(g.call(&"force_gesture", &"look")), "Andando não começa gesto")
	v.anim = &"idle"
	g.set(&"player_override", v.global_position + Vector3(2.0, 0.0, 0.0))
	g.call(&"step", 0.1)
	_check(bool(g.get(&"facing_player")) and is_equal_approx(v.facing_yaw, atan2(-2.0, 0.0)), "Vira para o jogador a 2 m")
	g.set(&"player_override", v.global_position + Vector3(6.0, 0.0, 0.0))
	g.call(&"step", 0.1)
	_check(not bool(g.get(&"facing_player")) and is_equal_approx(v.facing_yaw, 0.3), "Jogador longe: volta à direção de rede")
	var before: int = int(g.call(&"gesture_count"))
	for i: int in 170: # 17 s parado: pelo menos um gesto sozinho
		g.call(&"step", 0.1)
	_check(int(g.call(&"gesture_count")) > before, "Gesto sozinho a cada 6–15 s")
	var other: Node3D = Factory.call(&"create_from", &"npc", &"__sem_def__", 1000002, "Outro")
	root.add_child(other)
	var waits: Array[float] = []
	for n: Node in [g, other.get_node(^"Gestures")]:
		waits.append(float(n.get(&"_wait")))
	_check(not is_equal_approx(waits[0], waits[1]), "NPCs dessincronizados (%.2f x %.2f)" % [waits[0], waits[1]])
	other.free()
	v.free()


func _test_birds() -> void:
	_check(&"pombo" in (AmbientLife.call(&"profile_for", &"city_awakening")["species"] as Array), "Cidade: pombos/pardais")
	_check(&"sabia" in (AmbientLife.call(&"profile_for", &"fields_pindorama")["species"] as Array), "Campo: sabiá")
	_check(&"periquito" in (AmbientLife.call(&"profile_for", &"jungle_z_trail")["species"] as Array), "Selva: aves coloridas")
	_check(AmbientLife.call(&"profile_for", &"cave_reino_encoberto").is_empty() and not AmbientLife.call(&"supports", &"hollow_earth_2")
		and not AmbientLife.call(&"supports", &"elder_trial_arena"), "Caverna, subterrâneo e arena sem passarinhos")
	_check(AmbientLife.call(&"supports", &"mapa_novo_qualquer"), "Mapa externo fora da tabela usa o padrão")
	var tex: Texture2D = BirdArt.call(&"sheet", &"sabia")
	_check(tex != null and tex.get_width() == 16 * 5 and tex.get_height() == 12,
		"Folha do passarinho com 5 quadros")
	_check(BirdArt.call(&"sheet", &"pombo") != tex, "Cada espécie com sua paleta")
	var map: Node3D = _ground_map(&"fields_pindorama")
	var life: Node3D = AmbientLife.new()
	life.set(&"map_id", &"fields_pindorama")
	map.add_child(life)
	life.set_process(false)
	life.set(&"auto_spawn", false)
	await physics_frame
	await physics_frame
	var saved: EnvQuality.Preset = EnvQuality.current
	EnvQuality.current = EnvQuality.Preset.ALTA
	_check(int(life.call(&"max_flocks")) >= 2 and int(life.call(&"max_birds")) >= 3, "ALTA: até 2 bandos de até 4")
	EnvQuality.current = EnvQuality.Preset.BAIXA
	_check(int(life.call(&"max_flocks")) == 1 and int(life.call(&"max_birds")) == 2, "BAIXA: um bandinho de 2")
	EnvQuality.current = saved
	life.call(&"force_flock", {"pos": Vector3(0, 0, 0), "kind": &"ground"}, 3, &"sabia")
	_check(int(life.call(&"bird_count")) == 3 and int(life.call(&"count_in_state", ARRIVING)) == 3,
		"Bando chega voando")
	for i: int in 50:
		life.call(&"step", 0.1)
	_check(int(life.call(&"count_in_state", LANDED)) == 3, "Pousam no chão")
	var near_ground: bool = true
	for f: Dictionary in life.get(&"_flocks"):
		for b: Dictionary in f["birds"]:
			near_ground = near_ground and absf((b["node"] as Node3D).position.y) < 0.2
	_check(near_ground, "Pousados no nível do chão (raio na física)")
	_check(int(life.call(&"scare", Vector3(1.0, 0, 0))) == 1, "Alguém chega perto: o bando se espanta")
	for i: int in 40:
		life.call(&"step", 0.1)
	_check(int(life.call(&"bird_count")) == 0 and int(life.call(&"flock_count")) == 0, "Levantam voo e somem")
	life.call(&"force_flock", {"pos": Vector3(3, 1.0, 0), "kind": &"fence", "span": Vector2(2.0, 0.1)}, 3, &"anu", true)
	map.set_meta(&"weather_visual", Vector2(1.0, 0.0))
	life.call(&"set_weather", 1.0)
	_check(not bool(life.call(&"can_land")), "Chuva forte: não pousam")
	life.call(&"step", 0.2)
	_check(int(life.call(&"count_in_state", LEAVING)) == 3, "Chuva forte: quem estava pousado vai embora")
	map.set_meta(&"weather_visual", Vector2.ZERO)
	life.call(&"set_weather", 0.0)
	life.call(&"set_night", 1.0)
	_check(not bool(life.call(&"can_land")), "À noite não pousam")
	map.free()


func _test_dressing() -> void:
	var map: Node3D = _ground_map(&"teste_acampamento")
	for spec: Array in [["camp_tent_v2_a", Vector3(10, 0, 10)], ["camp_tent_v2_b", Vector3(-12, 0, 6)],
			["camp_fire_v2", Vector3(0, 0, 0)], ["camp_tent_v2_a", Vector3(24, 0, 0)]]:
		var mi := MeshInstance3D.new()
		mi.name = spec[0]
		mi.mesh = load("res://assets/environment/painted/meshes/" + String(spec[0]) + ".res")
		mi.position = spec[1]
		map.add_child(mi)
	var spawn := Marker3D.new()
	spawn.name = &"SpawnPoint"
	spawn.position = Vector3(24, 0, 0)
	map.add_child(spawn)
	await physics_frame
	var scan = AmbientScan.call(&"scan", map)
	_check(scan.dwellings.size() == 3 and scan.fires.size() == 1, "Acha barracas e fogueira pelos nomes do kit")
	var a: Node3D = CampDressing.new()
	a.set(&"map_id", &"teste_acampamento")
	map.add_child(a)
	a.set_process(false)
	a.call(&"build")
	for kind: StringName in [&"mat", &"firewood", &"pot", &"mug"]:
		_check(int(a.call(&"count", kind)) >= 1, "Sinal de uso colocado: %s" % kind)
	var near_spawn: int = 0
	for n: Node in a.find_children("*", "Node3D", false, false):
		if n is Node3D and (n as Node3D).position.distance_to(Vector3(24, 0, 0)) < 4.0:
			near_spawn += 1
	_check(near_spawn == 0, "Nada no ponto de nascimento (%d)" % near_spawn)
	var no_collision: bool = a.find_children("*", "CollisionObject3D", true, false).is_empty()
	_check(no_collision, "Detalhes sem colisão (não mexem na navegação)")
	var b: Node3D = CampDressing.new()
	b.set(&"map_id", &"teste_acampamento")
	map.add_child(b)
	b.set_process(false)
	b.call(&"build")
	_check(_layout(a) == _layout(b), "Mesma semente por mapa: todos veem igual")
	var cloth_ok: bool = true
	for c: Node in a.find_children("Cloth*", "MeshInstance3D", true, false):
		var m := (c as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
		cloth_ok = cloth_ok and m != null and m.shader.resource_path.ends_with("env_banner.gdshader")
	_check(cloth_ok, "Roupa do varal usa o vento do env_banner")
	var saved: EnvQuality.Preset = EnvQuality.current
	EnvQuality.current = EnvQuality.Preset.ALTA
	a.call(&"apply_quality")
	a.call(&"update_daylight", 0.0)
	var lit: int = 0
	for l: OmniLight3D in a.call(&"lights"):
		lit += 1 if l.visible else 0
	_check(lit == 0, "Lanternas apagadas de dia")
	a.call(&"update_daylight", 1.0)
	lit = 0
	for l: OmniLight3D in a.call(&"lights"):
		lit += 1 if l.visible else 0
	_check(int(a.call(&"count", &"lantern")) == 0 or lit > 0, "Lanterna acesa à noite na entrada")
	EnvQuality.current = EnvQuality.Preset.BAIXA
	a.call(&"apply_quality")
	a.call(&"update_daylight", 0.9)
	lit = 0
	for l: OmniLight3D in a.call(&"lights"):
		lit += 1 if l.visible else 0
	_check(lit == 0, "BAIXA: sem luzes extras")
	EnvQuality.current = saved
	var fires: int = 0
	for n: Node in get_nodes_in_group(&"env_fire_spot"):
		fires += 1 if a.is_ancestor_of(n) else 0
	_check(fires == 1, "Fogueira registrada para os NPCs mexerem no fogo")
	map.free()


## Mapas reais: o leitor acha poleiros e moradias sem nada posicionado à mão.
func _test_real_scan() -> void:
	for id: String in ["training_field", "city_awakening", "fields_pindorama"]:
		var map: Node3D = (load("res://scenes/maps/%s.tscn" % id) as PackedScene).instantiate()
		root.add_child(map)
		await physics_frame
		var r = AmbientScan.call(&"scan", map)
		_check(r.perches.size() > 0, "%s: poleiros achados (%d)" % [id, r.perches.size()])
		_check(r.dwellings.size() > 0, "%s: moradias achadas (%d)" % [id, r.dwellings.size()])
		_check(r.keepout.size() > 0, "%s: áreas proibidas (nascimento/portais/NPCs)" % id)
		map.free()


func _ground_map(id: StringName) -> Node3D:
	var map: Node3D = (load("res://scripts/shared/map.gd") as Script).new()
	map.map_id = id
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	map.add_child(body)
	root.add_child(map)
	return map


func _layout(n: Node) -> Array:
	var out: Array = []
	for c: Node in n.get_children():
		if c is Node3D:
			out.append([String(c.name), (c as Node3D).position.snapped(Vector3.ONE * 0.001)])
	return out


# --- cenário vivo (08/10/2026): vento só em planta, sombra de nuvem, partículas de ar por bioma, caverna ----------

func _test_scenery() -> void:
	var SceneryLife: GDScript = load("res://scripts/client/env/scenery_life.gd")
	var biome := func(id: StringName) -> StringName: return SceneryLife.call(&"profile_for", id)["biome"]
	_check(biome.call(&"cave_reino_encoberto") == &"cave" and biome.call(&"hollow_earth_2") == &"cave"
		and biome.call(&"sumidouro_abyss") == &"cave", "Cavernas com perfil de caverna")
	_check(biome.call(&"jungle_z_trail") == &"jungle" and biome.call(&"enchanted_forest_glade") == &"jungle", "Selva e mata")
	_check(biome.call(&"city_awakening") == &"city" and biome.call(&"fog_moor_swamp") == &"moor", "Cidade e brejo")
	_check(biome.call(&"fields_pindorama") == &"field" and biome.call(&"mapa_novo_qualquer") == &"field",
		"Campo é o padrão de mapa externo")
	# sombra de nuvem
	var A: int = EnvQuality.Preset.ALTA
	var day: Vector4 = SceneryLife.call(&"cloud_params", true, true, 0.0, 0.0, 0.0, A)
	_check(day.x > 0.1, "Nuvem passando de dia em mapa externo (%.2f)" % day.x)
	_check(SceneryLife.call(&"cloud_params", true, true, 1.0, 0.0, 0.0, A).x == 0.0, "Nuvem some à noite")
	_check(SceneryLife.call(&"cloud_params", true, true, 0.0, 0.0, 1.0, A).x == 0.0, "Nuvem some na neblina forte")
	_check(SceneryLife.call(&"cloud_params", true, true, 0.0, 0.0, 0.0, EnvQuality.Preset.BAIXA).x == 0.0,
		"Nuvem desligada no preset Baixa")
	_check(SceneryLife.call(&"cloud_params", false, true, 0.0, 0.0, 0.0, A).x == 0.0
		and SceneryLife.call(&"cloud_params", true, false, 0.0, 0.0, 0.0, A).x == 0.0, "Sem nuvem em caverna nem sem sol")
	var wet: Vector4 = SceneryLife.call(&"cloud_params", true, true, 0.0, 1.0, 0.0, A)
	_check(wet.y > day.y and wet.x >= day.x, "Chuva: nuvens mais densas (%.2f -> %.2f)" % [day.y, wet.y])
	for f: String in ["env_terrain.gdshaderinc", "env_terrain_world.gdshader", "forest_floor.gdshader",
			"env_painted.gdshaderinc", "env_foliage.gdshader", "woodland_trail.gdshader"]:
		var src: String = FileAccess.get_file_as_string("res://assets/shaders/" + f)
		_check(src.contains("env_cloud_shade("), "%s recebe a sombra de nuvem" % f)
	var floor_src: String = FileAccess.get_file_as_string("res://assets/shaders/forest_floor.gdshader")
	_check(floor_src.contains("env_wet_ground(") and FileAccess.get_file_as_string("res://assets/shaders/woodland_trail.gdshader").contains("env_wet_ground("), "Chão de mata e trilha molham com a chuva")
	var painted: String = FileAccess.get_file_as_string("res://assets/shaders/env_painted.gdshaderinc")
	_check(painted.contains("instance uniform float veg_bend = 0.0;"), "env_painted: balanço desligado por padrão (só por nó)")
	# vento só em planta, nos mapas reais
	for id: String in ["training_field", "fields_pindorama_buriti", "enchanted_forest", "city_awakening", "split_sky_plateau"]:
		var m: Node3D = (load("res://scenes/maps/%s.tscn" % id) as PackedScene).instantiate()
		root.add_child(m)
		var plants: Array = SceneryLife.call(&"apply_plant_wind", m)
		_check(plants.size() > 0, "%s: árvores/palmeiras balançando (%d)" % [id, plants.size()])
		var wrong: Array[String] = []
		for gi: GeometryInstance3D in plants:
			var label: String = _mesh_label(gi)
			for bad: String in ["wall", "house", "roof", "rock", "stone", "tent", "fence", "crate", "barrel", "ground",
					"terrain", "pebble", "termite"]:
				if label.contains(bad):
					wrong.append(label)
			if float(gi.get_instance_shader_parameter(&"veg_bend")) <= 0.0:
				wrong.append(label + " (sem força)")
		_check(wrong.is_empty(), "%s: vento só em vegetação %s" % [id, wrong.slice(0, 4)])
		var non_plant_bent: int = 0
		for n: Node in m.find_children("*", "GeometryInstance3D", true, false):
			var gi := n as GeometryInstance3D
			if not (gi in plants) and gi.get_instance_shader_parameter(&"veg_bend") != null \
					and float(gi.get_instance_shader_parameter(&"veg_bend")) > 0.0:
				non_plant_bent += 1
		_check(non_plant_bent == 0, "%s: nada fora das plantas ganhou balanço" % id)
		m.free()
	# palmeira balança mais que árvore comum (por metro)
	var palm := MeshInstance3D.new()
	palm.mesh = load("res://assets/environment/painted/meshes/palm_buriti_a.res")
	var tree := MeshInstance3D.new()
	tree.mesh = load("res://assets/environment/painted/meshes/tree_jungle_a.res")
	var rock := MeshInstance3D.new()
	rock.mesh = load("res://assets/environment/painted/meshes/rock_moss_a.res")
	var holder := Node3D.new()
	for n: Node3D in [palm, tree, rock]:
		holder.add_child(n)
	root.add_child(holder)
	var bent: Array = SceneryLife.call(&"apply_plant_wind", holder)
	_check(palm in bent and tree in bent and not (rock in bent), "Palmeira e árvore balançam; pedra não")
	var per_m := func(gi: GeometryInstance3D) -> float:
		return float(gi.get_instance_shader_parameter(&"veg_bend")) / float(gi.get_instance_shader_parameter(&"veg_height"))
	_check(per_m.call(palm) > per_m.call(tree), "Palmeira mais solta que árvore de copa")
	holder.free()
	# partículas de ar por bioma
	var saved: EnvQuality.Preset = EnvQuality.current
	EnvQuality.current = EnvQuality.Preset.ALTA
	var field: Node3D = _ground_map(&"fields_pindorama")
	var life: Node3D = SceneryLife.new()
	life.set(&"map_id", &"fields_pindorama")
	field.add_child(life)
	life.set_process(false)
	var MOTE: int = SceneryLife.K_MOTE
	var FIREFLY: int = SceneryLife.K_FIREFLY
	life.call(&"set_conditions", 0.0, 0.0)
	life.call(&"update_daylight", 0.0)
	var mote: CPUParticles3D = life.call(&"layer", MOTE)
	var fly: CPUParticles3D = life.call(&"layer", FIREFLY)
	_check(mote != null and mote.emitting and fly != null and not fly.emitting, "Campo de dia: pólen/luz no ar, sem vaga-lume")
	_check(mote != null and not mote.local_coords, "Partículas no mundo (a câmera anda e elas ficam)")
	life.call(&"update_daylight", 1.0)
	_check(not mote.emitting and fly.emitting, "Campo à noite: vaga-lumes")
	life.call(&"set_conditions", 1.0, 1.0)
	life.call(&"update_daylight", 1.0)
	_check(not fly.emitting, "Chuva forte esconde os vaga-lumes")
	var high: int = mote.amount
	EnvQuality.current = EnvQuality.Preset.BAIXA
	life.call(&"apply_quality")
	_check(mote.amount < high and mote.amount >= 2, "Baixa: menos partículas (%d -> %d)" % [high, mote.amount])
	EnvQuality.current = EnvQuality.Preset.ALTA
	life.set(&"publish_always", true)
	life.call(&"set_conditions", 0.0, 0.0)
	_check((life.call(&"current_clouds") as Vector4).x == 0.0, "Mapa de teste sem sol: sem sombra de nuvem")
	field.free()
	for spec: Array in [[&"jungle_z_trail", SceneryLife.K_LEAF], [&"fog_moor_swamp", SceneryLife.K_MIST],
			[&"city_awakening", MOTE]]:
		var gm: Node3D = _ground_map(spec[0])
		var l2: Node3D = SceneryLife.new()
		l2.set(&"map_id", spec[0])
		gm.add_child(l2)
		l2.set_process(false)
		l2.call(&"set_conditions", 0.0, 0.0)
		l2.call(&"update_daylight", 0.0)
		var p: CPUParticles3D = l2.call(&"layer", spec[1])
		_check(p != null and p.emitting, "%s: camada de ar do bioma (%d)" % [spec[0], spec[1]])
		gm.free()
	# caverna real: gotas, poeira nas luzes, cristais pulsando, morcegos
	var cave: Node3D = (load("res://scenes/maps/cave_reino_encoberto.tscn") as PackedScene).instantiate()
	root.add_child(cave)
	var cl: Node3D = SceneryLife.new()
	cl.set(&"map_id", &"cave_reino_encoberto")
	cave.add_child(cl)
	cl.set_process(false)
	var info: Dictionary = cl.call(&"debug_info")
	_check(cl.has_node(^"AirAnchor/Drips"), "Caverna: gotas pingando")
	_check(int(info["cave"]) >= 3, "Caverna: poeira em volta das luzes (%d)" % int(info["cave"]))
	_check(int(info["crystals"]) > 0, "Caverna: cristais pulsando (%d)" % int(info["crystals"]))
	var crystal: MeshInstance3D = (cl.get(&"crystals") as Array)[0]
	_check(crystal.material_overlay is ShaderMaterial, "Cristal ganha a camada de pulso")
	_check(int(cl.call(&"spawn_bats", 2)) == 2 and int(cl.call(&"bat_count")) == 2, "Morcegos cruzando")
	cl.set(&"_bat_wait", 999.0) # sem nova passagem sorteada durante a conta
	for i: int in 80:
		cl.call(&"_step_bats", 0.1)
	_check(int(cl.call(&"bat_count")) == 0, "Morcegos passam e somem")
	_check((cl.call(&"current_clouds") as Vector4).x == 0.0, "Caverna sem sombra de nuvem")
	EnvQuality.current = EnvQuality.Preset.BAIXA
	cl.call(&"apply_quality")
	_check(crystal.material_overlay == null, "Baixa: cristal sem a camada extra")
	EnvQuality.current = saved
	cave.free()


func _mesh_label(gi: GeometryInstance3D) -> String:
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
	elif gi is MultiMeshInstance3D:
		mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	return ((mesh.resource_path.get_file() if mesh != null else "") + " " + String(gi.name)).to_lower()
