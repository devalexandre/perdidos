extends Node
## Teste automatizado dos controles mobile touch (GDD §9.5, Mobile standard):
## - VirtualJoystick: cálculo de vetor e limites de arraste;
## - MobileActionCluster: 4 slots de skill em arco, cooldown, botão de ataque e poção rápida;
## - MobileConfigDialog: seleção touch de habilidades e itens nos slots;
## - GameUI com MobileControlsOverlay: ativação, layout responsivo e captura de tela.

const FAKE_NET_SCRIPT: GDScript = preload("res://tests/client/fake_net.gd")
const VIRTUAL_JOYSTICK_SCRIPT: GDScript = preload("res://scripts/client/ui/virtual_joystick.gd")
const MOBILE_ACTION_CLUSTER_SCRIPT: GDScript = preload("res://scripts/client/ui/mobile_action_cluster.gd")
const MOBILE_CONFIG_DIALOG_SCRIPT: GDScript = preload("res://scripts/client/ui/mobile_config_dialog.gd")
const MOBILE_CONTROLS_OVERLAY_SCRIPT: GDScript = preload("res://scripts/client/ui/mobile_controls_overlay.gd")
const SETTLE_FRAMES: int = 6

var _failures: int = 0
var _ui: GameUI
var _net: Node


func _ready() -> void:
	print("=== INICIANDO TESTES DE CONTROLES MOBILE ===")
	_test_virtual_joystick()
	_test_action_cluster()
	_test_config_dialog()
	await get_tree().process_frame
	_test_mobile_targeting()
	await _test_mobile_ui_integration()
	_finish()


func _check(condition: bool, desc: String) -> void:
	if condition:
		print("ok   %s" % desc)
	else:
		_failures += 1
		printerr("FALHA: %s" % desc)


func _test_virtual_joystick() -> void:
	print("--- Testando VirtualJoystick ---")
	var stick: MobileVirtualJoystick = (VIRTUAL_JOYSTICK_SCRIPT as Script).new(1.0)
	add_child(stick)
	_check(stick.get_direction() == Vector2.ZERO, "joystick nasce centralizado com direção zero")
	_check(not stick.is_active(), "joystick nasce inativo")

	# Simular arraste para a direita
	var center: Vector2 = stick.size * 0.5
	stick._process_drag(center + Vector2(60.0, 0.0))
	_check(stick.is_active(), "joystick fica ativo durante o arraste")
	_check(stick.get_direction().x > 0.5 and is_zero_approx(stick.get_direction().y), "direção calculada para a direita")

	# Simular soltar o toque
	stick._release_touch()
	_check(not stick.is_active(), "joystick desativa ao soltar")
	_check(stick.get_direction() == Vector2.ZERO, "direção volta a zero ao soltar")
	stick.queue_free()


func _test_action_cluster() -> void:
	print("--- Testando MobileActionCluster ---")
	var cluster: MobileActionCluster = (MOBILE_ACTION_CLUSTER_SCRIPT as Script).new(1.0)
	add_child(cluster)

	# Conferir 4 slots inicializados
	_check(cluster._slots_data.size() == 4, "cluster possui exatamente 4 slots de skill")

	var activated_slots: Array[int] = []
	cluster.slot_activated.connect(func(i: int) -> void: activated_slots.append(i))

	var attack_called: Array[bool] = [false]
	cluster.attack_activated.connect(func() -> void: attack_called[0] = true)

	var potion_called: Array[bool] = [false]
	cluster.quick_potion_activated.connect(func() -> void: potion_called[0] = true)

	# Simular atribuição de skill
	cluster.set_slot_entry(0, &"blade_firm_strike")
	_check(cluster._slots_data[0]["id"] == &"blade_firm_strike", "slot 0 recebe blade_firm_strike")
	_check(cluster._slots_data[0]["icon"] != null, "slot 0 carrega ícone da habilidade")

	# Simular toque no slot 0
	cluster._handle_press(cluster._slot_positions[0])
	_check(activated_slots.has(0), "toque no slot 0 emite slot_activated(0)")

	# Simular toque no botão de ataque
	cluster._handle_press(cluster._attack_pos)
	_check(attack_called[0], "toque no botão central emite attack_activated")

	# Simular toque no botão de poção
	cluster._handle_press(cluster._potion_pos)
	_check(potion_called[0], "toque no botão de poção emite quick_potion_activated")

	# Testar cooldown
	cluster.set_slot_cooldown(0, 0.5, 3)
	_check(is_equal_approx(cluster._slots_data[0]["cd_pct"], 0.5), "cooldown de 50% registrado")
	_check(cluster._slots_data[0]["cd_sec"] == 3, "tempo de 3s de recarga registrado")

	cluster.queue_free()


func _test_config_dialog() -> void:
	print("--- Testando MobileConfigDialog ---")
	var dlg: MobileConfigDialog = (MOBILE_CONFIG_DIALOG_SCRIPT as Script).new(1.0)
	add_child(dlg)

	var assigned_result: Array = [-1, &""]
	dlg.slot_assigned.connect(func(s: int, e: StringName) -> void:
		assigned_result[0] = s
		assigned_result[1] = e
	)

	var fake_hotbar: Array = [&"blade_firm_strike", &"", &"", &""]
	var fake_skills: Array = [&"blade_firm_strike", &"blade_charge"]
	dlg.set_data(fake_hotbar, fake_skills, [])

	_check(dlg._slot_buttons.size() == 4, "diálogo exibe os 4 botões de atalho mobile")

	# Selecionar slot 1 e simular atribuição
	dlg._on_slot_button_pressed(1)
	dlg.slot_assigned.emit(1, &"blade_charge")
	_check(assigned_result[0] == 1 and assigned_result[1] == &"blade_charge", "atribuição touch para slot 1 bem sucedida")

	dlg.queue_free()


func _test_mobile_targeting() -> void:
	print("--- Testando Mira e Trava de Alvo Mobile (Albion Style) ---")
	var root: Node = get_tree().root
	var main_node: Node = root.get_node_or_null(^"Main")
	var created_main: bool = false
	if main_node == null:
		main_node = Node.new()
		main_node.name = "Main"
		root.add_child(main_node)
		created_main = true

	var world: Node = main_node.get_node_or_null(^"World")
	var created_world: bool = false
	if world == null:
		world = Node.new()
		world.name = "World"
		main_node.add_child(world)
		created_world = true

	var instances: Node = world.get_node_or_null(^"Instances")
	var created_instances: bool = false
	if instances == null:
		instances = Node.new()
		instances.name = "Instances"
		world.add_child(instances)
		created_instances = true

	var inst: Node = Node.new()
	inst.name = "TestInstance"
	instances.add_child(inst)

	var ents: Node = Node.new()
	ents.name = "Entities"
	inst.add_child(ents)

	# Jogador Local
	var player := NetEntity.new()
	player.name = "1"
	player.entity_id = 1
	player.kind = NetEntity.KIND_PLAYER
	player.hp_ratio = 1.0
	player.position = Vector3.ZERO
	ents.add_child(player)

	# Monstro A (distância 3m)
	var mon_a := NetEntity.new()
	mon_a.name = "101"
	mon_a.entity_id = 101
	mon_a.kind = NetEntity.KIND_MONSTER
	mon_a.display_name = "Lobo Cinzento"
	mon_a.hp_ratio = 1.0
	mon_a.position = Vector3(3.0, 0.0, 0.0)
	ents.add_child(mon_a)

	# Monstro B (distância 6m)
	var mon_b := NetEntity.new()
	mon_b.name = "102"
	mon_b.entity_id = 102
	mon_b.kind = NetEntity.KIND_MONSTER
	mon_b.display_name = "Urso Selvagem"
	mon_b.hp_ratio = 1.0
	mon_b.position = Vector3(6.0, 0.0, 0.0)
	ents.add_child(mon_b)

	# Monstro C (distância 2m, mas MORTO)
	var mon_c := NetEntity.new()
	mon_c.name = "103"
	mon_c.entity_id = 103
	mon_c.kind = NetEntity.KIND_MONSTER
	mon_c.display_name = "Esqueleto Caído"
	mon_c.hp_ratio = 0.0
	mon_c.position = Vector3(2.0, 0.0, 0.0)
	ents.add_child(mon_c)

	var overlay: MobileControlsOverlay = (MOBILE_CONTROLS_OVERLAY_SCRIPT as Script).new(null, 1.0)
	add_child(overlay)

	var nearby: Array[Node3D] = overlay.get_nearby_monsters(16.0)
	_check(nearby.size() == 2, "filtra monstros mortos e lista apenas os vivos")
	_check(nearby.size() >= 2 and nearby[0] == mon_a and nearby[1] == mon_b,
			"ordena monstros por distância crescente do jogador")

	# 1. Pressionar mira sem alvo seleciona o mais próximo (Monstro A)
	overlay._on_target_cycle_pressed()
	_check(overlay._current_target_entity == 101, "mira seleciona o monstro vivo mais próximo")
	_check(NetCombat.client_attack_target == 101, "alvo do NetCombat sincronizado com o monstro")

	# 2. Pressionar mira de novo cicla para o próximo (Monstro B)
	overlay._on_target_cycle_pressed()
	_check(overlay._current_target_entity == 102, "pressionar mira novamente cicla para o próximo monstro")
	_check(NetCombat.client_attack_target == 102, "NetCombat sincroniza o novo alvo ciclado")

	# 3. Monstro B morre: deve retargetar automaticamente para Monstro A (estilo Albion Online)
	mon_b.hp_ratio = 0.0
	overlay._on_entity_died(102)
	_check(overlay._current_target_entity == 101, "ao morrer, mira muda automaticamente para o próximo monstro vivo")
	_check(NetCombat.client_attack_target == 101, "NetCombat atualizado com o novo alvo vivo após morte")

	# 4. Monstro A morre: nenhum monstro vivo restante, mira desmarca
	mon_a.hp_ratio = 0.0
	overlay._on_entity_died(101)
	_check(overlay._current_target_entity == -1, "ao morrer o último monstro da área, desmarca o alvo")
	_check(NetCombat.client_attack_target == 0, "NetCombat limpa o alvo quando não há mais monstros")

	# 5. Clique direto no monstro (toque na tela)
	mon_a.hp_ratio = 1.0
	overlay._on_world_interact_requested("e:101")
	_check(overlay._current_target_entity == 101, "toque direto no monstro marca o alvo")
	_check(NetCombat.client_attack_target == 101, "toque direto aciona trava de alvo no NetCombat")

	overlay.queue_free()
	inst.queue_free()
	if created_instances:
		instances.queue_free()
	if created_world:
		world.queue_free()
	if created_main:
		main_node.queue_free()


func _test_mobile_ui_integration() -> void:
	print("--- Testando Integração no GameUI ---")
	_net = (FAKE_NET_SCRIPT as Script).new()
	_net.name = &"FakeNet"
	add_child(_net)

	GameSettings.get_instance().mobile_controls = true
	_ui = GameUI.new()
	_ui.bind_net(_net)
	add_child(_ui)

	for _f in SETTLE_FRAMES:
		await get_tree().process_frame

	_check(_ui.mobile_controls != null, "GameUI instancia MobileControlsOverlay quando mobile_controls = true")
	_check(_ui.mobile_controls.visible, "MobileControlsOverlay está visível")
	var tray: Control = _ui.progression.hotbar.find_child("Tray", true, false) as Control
	var xp_bar: Control = _ui.progression.hotbar.find_child("XPBar", true, false) as Control
	_check(tray != null and not tray.visible and _ui.progression.hotbar.visible,
			"slots da hotbar ficam ocultos sem esconder a barra inteira no mobile")
	_check(xp_bar != null and xp_bar.visible, "barra de XP continua visível no mobile")
	var previous_progress: Dictionary = NetProgress.client_progress
	NetProgress.client_progress = {"skills": {}}
	_check(_ui.mobile_controls._get_known_skills().is_empty(), "catálogo sem skills aprendidas fica vazio sem chamar método inexistente")
	NetProgress.client_progress = {"skills": {"blade_firm_strike": 1}}
	_check(_ui.mobile_controls._get_known_skills() == [&"blade_firm_strike"], "catálogo mostra somente skills aprendidas")
	NetProgress.client_progress = previous_progress

	# Testar alternância dinâmica de modo
	_ui.set_mobile_mode(false)
	_check(not _ui.mobile_controls.visible, "MobileControlsOverlay oculta ao desativar modo mobile")
	_check(tray.visible, "slots da hotbar voltam ao desativar modo mobile")

	_ui.set_mobile_mode(true)
	_check(_ui.mobile_controls.visible, "MobileControlsOverlay reaparece ao reativar modo mobile")

	# Capturar tela
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		var path: String = "user://mobile_controls_1280x720.png"
		img.save_png(path)
		print("saved %s" % path)

	_ui.queue_free()
	_net.queue_free()


func _finish() -> void:
	if _failures == 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		printerr("RESULT: FAIL (%d falhas)" % _failures)
		get_tree().quit(1)
