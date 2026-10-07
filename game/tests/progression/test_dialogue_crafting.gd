extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	var character := CharacterData.create_new("ForjaTeste", &"male")
	character.causos = 0
	var session := PlayerSession.new(0, null, character)
	var runner := DialogueRunner.new(null)
	var recipe := DialogueOption.new()
	recipe.action_args = {
		&"item_id": &"ember_machete",
		&"qty": 1,
		&"causos_rank": 1,
		&"materials": {&"eternal_ember": 1, &"thick_leather": 3, &"pequi_root": 1},
	}
	_check(not runner.call("_can_craft", session, recipe), "receita bloqueada sem materiais e rank")
	character.inventory.add(&"eternal_ember", 1)
	character.inventory.add(&"thick_leather", 3)
	character.inventory.add(&"pequi_root", 1)
	_check(not runner.call("_can_craft", session, recipe), "materiais não ignoram rank mínimo")
	character.causos = CharacterData.CAUSOS_THRESHOLDS[1]
	_check(bool(runner.call("_can_craft", session, recipe)), "receita aparece com rank e materiais")
	_check(bool(runner.call("_craft_item", session, recipe)), "forja concede o item")
	_check(character.inventory.count(&"ember_machete") == 1 and character.inventory.count(&"eternal_ember") == 0
			and character.inventory.count(&"thick_leather") == 0 and character.inventory.count(&"pequi_root") == 0,
			"forja consome todos os materiais e entrega uma arma")
	_check(session.save_pending, "forja marca o personagem para salvar")
	print("test_dialogue_crafting: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	print(("ok   " if condition else "FAIL ") + description)
	if not condition:
		_failures += 1