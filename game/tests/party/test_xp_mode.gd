extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	var total: int = 120
	var divided: int = PartyService.share_xp(total, 2)
	_check(PartyService.xp_for_recipient(total, 2, PartyService.XP_MODE_SPLIT, 0) == divided,
			"modo Dividida preserva bônus e rateio atual para dono")
	_check(PartyService.xp_for_recipient(total, 2, PartyService.XP_MODE_SPLIT, 1) == divided,
			"modo Dividida entrega cota ao membro próximo")
	_check(PartyService.xp_for_recipient(total, 2, PartyService.XP_MODE_INDIVIDUAL, 0) == total,
			"modo Individual entrega XP total ao dono do abate")
	_check(PartyService.xp_for_recipient(total, 2, PartyService.XP_MODE_INDIVIDUAL, 1) == 0,
			"modo Individual não entrega XP aos demais membros")
	_check(PartyService.xp_for_recipient(total, 1, PartyService.XP_MODE_SPLIT, 0) == total,
			"solo continua recebendo XP integral")
	print("test_xp_mode: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	print(("ok   " if condition else "FAIL ") + description)
	if not condition:
		_failures += 1