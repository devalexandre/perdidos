extends Node

const TITLE_ID: StringName = &"sabia_blade_machete"
const SKILLS_WINDOW_SCRIPT: GDScript = preload("res://scripts/client/ui/skills_window.gd")
const HOTBAR_SCRIPT: GDScript = preload("res://scripts/client/ui/hotbar.gd")

var _failures: int = 0


func _ready() -> void:
	var window: SkillsWindow = SKILLS_WINDOW_SCRIPT.new() as SkillsWindow
	var hotbar: Hotbar = HOTBAR_SCRIPT.new() as Hotbar
	add_child(window)
	add_child(hotbar)
	await _frames(2)

	var skill_bundle: Array[StringName] = TitleService.skills_for_title(TITLE_ID)
	_check(not skill_bundle.is_empty(), "título de teste tem skills")
	if skill_bundle.is_empty():
		get_tree().quit(1)
		return
	var skill_id: StringName = skill_bundle[0]

	var progress := {
		"skill_points": 2,
		"titles": [TITLE_ID],
		"displayed_title": TITLE_ID,
		"skills": {String(skill_id): 1},
		"hotbar": [&"", &"", &"", &"", &"", &"", &"", &"", &"", &""],
	}
	window.set_progress(progress)
	window.open()
	hotbar.set_state(progress, 100, [], {}, {}, {})
	await _frames(3)

	# 1. Obter a linha da habilidade
	var page: Control = window.find_child("Page_" + String(TITLE_ID), true, false) as Control
	_check(page != null, "página da árvore encontrada")
	var list: GridContainer = page.find_child("SkillList", true, false) as GridContainer
	_check(list != null, "lista de skills encontrada")
	var row: SkillsWindow.SkillRow = list.find_child(String(skill_id), true, false) as SkillsWindow.SkillRow
	_check(row != null, "linha de skill é do tipo SkillRow")

	var row_instance_id := row.get_instance_id()

	# 2. Testar seleção não-destrutiva
	window._select(skill_id)
	await _frames(2)
	var row_after_select: Node = list.find_child(String(skill_id), true, false)
	_check(row_after_select != null and row_after_select.get_instance_id() == row_instance_id,
			"selecionar habilidade não recria nós da lista")

	# 3. Testar _get_drag_data da linha (nome / fundo)
	var drag_data_row: Variant = row._get_drag_data(Vector2(50, 10))
	_check(drag_data_row is Dictionary, "row._get_drag_data retorna Dictionary")
	if drag_data_row is Dictionary:
		var d: Dictionary = drag_data_row
		_check(d.has(HotbarSlot.SKILL_DRAG_KEY) and d[HotbarSlot.SKILL_DRAG_KEY] == true,
				"drag data contém chave de skill válida")
		_check(StringName(str(d.get("entry", ""))) == skill_id,
				"drag data contém skill_id correto")

	# 4. Testar _get_drag_data do ícone (HotbarSlot)
	var slot: HotbarSlot = row.get_child(0) as HotbarSlot
	_check(slot != null, "ícone HotbarSlot existe na linha")
	var drag_data_slot: Variant = slot._get_drag_data(Vector2(10, 10))
	_check(drag_data_slot is Dictionary, "slot._get_drag_data retorna Dictionary")
	if drag_data_slot is Dictionary:
		var d: Dictionary = drag_data_slot
		_check(StringName(str(d.get("entry", ""))) == skill_id,
				"slot drag data contém skill_id correto")

	# 5. Testar aceitação e atribuição no HotbarSlot
	var target_slot: HotbarSlot = hotbar.slots[0]
	_check(target_slot._can_drop_data(Vector2.ZERO, drag_data_row), "HotbarSlot aceita drag da linha")
	var assigned := {"emitted": false, "slot": -1, "entry": &""}
	hotbar.slot_assigned.connect(func(idx: int, entry: StringName) -> void:
		assigned.emitted = true
		assigned.slot = idx
		assigned.entry = entry
	)
	target_slot._drop_data(Vector2.ZERO, drag_data_row)
	_check(assigned.emitted, "hotbar emitiu slot_assigned ao soltar skill")
	_check(assigned.slot == 0 and assigned.entry == skill_id,
			"hotbar atribuiu slot 0 com a habilidade correta")
	_check(target_slot.entry_id == skill_id, "HotbarSlot atualizou localmente de forma otimista")

	# 6. Testar soltar na bandeja (Hotbar tray) para o slot mais próximo
	var drag_data_slot1: Dictionary = {HotbarSlot.SKILL_DRAG_KEY: true, "entry": skill_id, "from_slot": -1}
	_check(hotbar._can_drop_data(Vector2.ZERO, drag_data_slot1), "Hotbar container aceita drop_data")
	var slot1_pos: Vector2 = hotbar.slots[1].global_position - hotbar.global_position + hotbar.slots[1].size * 0.5
	assigned.emitted = false
	hotbar._drop_data(slot1_pos, drag_data_slot1)
	_check(assigned.emitted and assigned.slot == 1 and assigned.entry == skill_id,
			"Hotbar tray encaminha drop para o slot 1 mais próximo")
	_check(hotbar.slots[1].entry_id == skill_id, "slot 1 atualizado localmente")

	# 7. Simular drag-and-drop completo com eventos de mouse sob viewport
	var target_slot2: HotbarSlot = hotbar.slots[2]
	var row_name_label: Label = row.find_child("NameLabel", true, false) as Label
	_check(row_name_label != null, "NameLabel encontrado na linha")
	_check(row_name_label.mouse_filter == Control.MOUSE_FILTER_PASS, "NameLabel tem mouse_filter MOUSE_FILTER_PASS")

	var start_pos: Vector2 = row_name_label.global_position + row_name_label.size * 0.5
	var drop_pos: Vector2 = target_slot2.global_position + target_slot2.size * 0.5

	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = start_pos
	press_event.global_position = start_pos
	get_viewport().push_input(press_event)
	await _frames(2)

	# Mover para além da distância mínima de arrasto
	var drag_event := InputEventMouseMotion.new()
	drag_event.position = start_pos + Vector2(25, 25)
	drag_event.global_position = start_pos + Vector2(25, 25)
	drag_event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(drag_event)
	await _frames(2)

	# Se viewport estiver sob display ativo (Xvfb), verificar se iniciou drag
	if get_viewport().gui_is_dragging():
		print("ok   Godot iniciou arrasto através do clique no NameLabel")
		var move_to_slot := InputEventMouseMotion.new()
		move_to_slot.position = drop_pos
		move_to_slot.global_position = drop_pos
		move_to_slot.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(move_to_slot)
		await _frames(2)

		var release_event := InputEventMouseButton.new()
		release_event.button_index = MOUSE_BUTTON_LEFT
		release_event.pressed = false
		release_event.position = drop_pos
		release_event.global_position = drop_pos
		get_viewport().push_input(release_event)
		await _frames(2)

		_check(target_slot2.entry_id == skill_id, "arrastar via mouse input atribuiu slot 2 com sucesso")
	else:
		print("info (gui_is_dragging requer suporte de janela completa sob display)")

	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	print(("ok   " if condition else "FAIL ") + description)
	if not condition:
		_failures += 1
