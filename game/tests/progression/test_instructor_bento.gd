extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("--- TEST INSTRUCTOR BENTO ---")
	_test_npc_def()
	_test_dialogue_structure()
	_test_localization()
	_test_training_field_scene()
	_test_dialogue_navigation()
	print("test_instructor_bento: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	print(("ok   " if condition else "FAIL ") + description)
	if not condition:
		_failures += 1


func _test_npc_def() -> void:
	var def: NpcDef = Content.npc(&"instructor_bento")
	_check(def != null, "NpcDef 'instructor_bento' registered in Content")
	if def == null:
		return
	_check(def.id == &"instructor_bento", "id is 'instructor_bento'")
	_check(def.map_id == &"training_field", "map_id is 'training_field'")
	_check(def.spawn_marker == &"instructor_bento", "spawn_marker is 'instructor_bento'")
	_check(def.dialogue != null, "has dialogue definition")
	_check(not def.name_key.is_empty(), "has name_key: %s" % def.name_key)


func _test_dialogue_structure() -> void:
	var def: NpcDef = Content.npc(&"instructor_bento")
	if def == null or def.dialogue == null:
		_check(false, "dialogue definition missing")
		return

	var dlg: DialogueDef = def.dialogue
	_check(dlg.id == &"instructor_bento", "dialogue id is 'instructor_bento'")

	var node_ids: Array[StringName] = []
	for node in dlg.nodes:
		node_ids.append(node.id)

	var expected_nodes: Array[StringName] = [
		&"start", &"combat", &"combat_ammo", &"titles",
		&"titles_masters", &"crendices", &"altars", &"synergies"
	]
	for exp in expected_nodes:
		_check(node_ids.has(exp), "dialogue contains node '%s'" % exp)

	# Verify every option has a valid target node or action
	for node in dlg.nodes:
		_check(not node.text_key.is_empty(), "node '%s' has text_key" % node.id)
		_check(not node.options.is_empty(), "node '%s' has options" % node.id)
		for opt in node.options:
			_check(not opt.text_key.is_empty(), "node '%s' option has text_key" % node.id)
			if opt.action.is_empty():
				_check(node_ids.has(opt.next_node), "node '%s' option next_node '%s' exists" % [node.id, opt.next_node])
			else:
				_check(opt.action == &"close", "option action '%s' is valid" % opt.action)


func _test_localization() -> void:
	var def: NpcDef = Content.npc(&"instructor_bento")
	if def == null or def.dialogue == null:
		return

	# Test NPC name
	var name_tr: String = tr(def.name_key)
	_check(name_tr != def.name_key and name_tr.contains("Bento"), "NPC name localized: '%s'" % name_tr)

	# Test all dialogue nodes and options
	for node in def.dialogue.nodes:
		var node_tr: String = tr(node.text_key)
		_check(node_tr != node.text_key and not node_tr.is_empty(), "node '%s' text localized" % node.id)
		for opt in node.options:
			var opt_tr: String = tr(opt.text_key)
			_check(opt_tr != opt.text_key and not opt_tr.is_empty(), "option '%s' text localized" % opt.text_key)


func _test_training_field_scene() -> void:
	var scene: PackedScene = load("res://scenes/maps/training_field.tscn")
	_check(scene != null, "training_field.tscn loads cleanly")
	if scene == null:
		return

	var inst: Node = scene.instantiate()
	_check(inst != null, "training_field instantiated")
	if inst == null:
		return

	var npc_points: Node = inst.get_node_or_null("NpcPoints")
	_check(npc_points != null, "NpcPoints exists in training_field")
	if npc_points != null:
		var marker: Marker3D = npc_points.get_node_or_null("instructor_bento") as Marker3D
		_check(marker != null, "instructor_bento Marker3D exists in NpcPoints")
		if marker != null:
			_check(marker.position.distance_to(Vector3(2.4, 0, 1.8)) < 0.1, "instructor_bento placed near camp")

	var interactables: Node = inst.get_node_or_null("Interactables")
	_check(interactables != null, "Interactables exists in training_field")
	if interactables != null:
		var altar: Area3D = interactables.get_node_or_null("altar_crendice") as Area3D
		_check(altar != null, "altar_crendice exists in Interactables")
		if altar != null:
			_check(StringName(str(altar.get_meta(&"interact_type", ""))) == &"altar_crendice", "altar interact_type is 'altar_crendice'")

	inst.queue_free()


func _test_dialogue_navigation() -> void:
	var def: NpcDef = Content.npc(&"instructor_bento")
	if def == null or def.dialogue == null:
		return

	var dlg: DialogueDef = def.dialogue
	var start_node: DialogueNode = dlg.get_node_by_id(dlg.start_node)
	_check(start_node != null, "start_node exists")
	if start_node == null:
		return

	# Navigate from start to combat
	var combat_opt: DialogueOption = start_node.options[0]
	_check(combat_opt.next_node == &"combat", "option 0 leads to combat")
	var combat_node: DialogueNode = dlg.get_node_by_id(combat_opt.next_node)
	_check(combat_node != null, "combat node exists")

	# Navigate from combat to combat_ammo
	var ammo_opt: DialogueOption = combat_node.options[0]
	_check(ammo_opt.next_node == &"combat_ammo", "ammo option leads to combat_ammo")
	var ammo_node: DialogueNode = dlg.get_node_by_id(ammo_opt.next_node)
	_check(ammo_node != null, "combat_ammo node exists")

	# Navigate from start to crendices
	var crendices_opt: DialogueOption = start_node.options[2]
	_check(crendices_opt.next_node == &"crendices", "option 2 leads to crendices")
	var crendices_node: DialogueNode = dlg.get_node_by_id(crendices_opt.next_node)
	_check(crendices_node != null, "crendices node exists")

	# Navigate from crendices to altars
	var altars_opt: DialogueOption = crendices_node.options[0]
	_check(altars_opt.next_node == &"altars", "altars option leads to altars")
	var altars_node: DialogueNode = dlg.get_node_by_id(altars_opt.next_node)
	_check(altars_node != null, "altars node exists")

	# Navigate from crendices to synergies
	var synergies_opt: DialogueOption = crendices_node.options[1]
	_check(synergies_opt.next_node == &"synergies", "synergies option leads to synergies")
	var synergies_node: DialogueNode = dlg.get_node_by_id(synergies_opt.next_node)
	_check(synergies_node != null, "synergies node exists")
