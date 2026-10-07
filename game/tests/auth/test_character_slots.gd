extends Node
## Slots de personagem (05/10/2026): 1 personagem por conta no servidor (AuthGate) e a lembrança local
## do slot no cliente (CharacterSlots), separada por conta.

const SECRET: String = "test-secret-with-at-least-32-characters!!"
const Jwt: GDScript = preload("res://scripts/server/auth/jwt_hs256.gd")

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("--- TEST CHARACTER SLOTS ---")
	_test_auth_gate_one_slot()
	_test_client_slots()
	print("test_character_slots: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String, detail: Variant = null) -> void:
	_checks += 1
	print(("ok   " if condition else "FAIL ") + description + ("" if detail == null else " %s" % str(detail)))
	if not condition:
		_failures += 1


func _token(account_id: int) -> String:
	var now: int = int(Time.get_unix_time_from_system())
	return Jwt.sign({"account_id": account_id, "exp": now + 3600, "iat": now}, SECRET)


func _test_auth_gate_one_slot() -> void:
	var dir: String = "user://test_slots_%d/" % Time.get_ticks_usec()
	var gate: AuthGate = AuthGate.new(SECRET, dir)
	var first: Dictionary = gate.check(_token(7), "Iracema")
	_check(StringName(first["reason"]).is_empty(), "conta cria o 1º personagem", first)
	var again: Dictionary = gate.check(_token(7), "iracema")
	_check(StringName(again["reason"]).is_empty(), "o mesmo personagem entra de novo (nome sem caixa)", again)
	var second: Dictionary = gate.check(_token(7), "Jaci")
	_check(second["reason"] == AuthGate.REASON_SLOT_FULL and (second.get("owned", []) as Array) == ["iracema"],
			"2º personagem recusado: slot cheio, com o nome do que a conta já tem", second)
	var other: Dictionary = gate.check(_token(8), "Jaci")
	_check(StringName(other["reason"]).is_empty(), "outra conta usa o próprio slot", other)
	var steal: Dictionary = gate.check(_token(8), "Iracema")
	_check(steal["reason"] == AuthGate.REASON_NAME_OWNED, "nome de outra conta continua protegido", steal)
	var reloaded: AuthGate = AuthGate.new(SECRET, dir)
	_check(reloaded.check(_token(7), "Outro")["reason"] == AuthGate.REASON_SLOT_FULL, "slot ocupado persiste no disco")


func _test_client_slots() -> void:
	var old_path: String = CharacterSlots.path
	CharacterSlots.path = "user://test_character_slots_%d.cfg" % Time.get_ticks_usec()
	_check(CharacterSlots.slot_count() == 1, "1 slot por conta")
	_check(CharacterSlots.account_id_of(_token(42)) == 42 and CharacterSlots.account_key(_token(42)) == "account_42",
			"conta lida do JWT")
	_check(CharacterSlots.first_filled("account_42").is_empty() and CharacterSlots.has_free_slot("account_42"),
			"conta nova começa com o slot livre")
	var app: Dictionary = {&"body": &"female", &"hair_style": &"long"}
	_check(CharacterSlots.remember({"name": "Iracema", "body": "female", "appearance": app}, "account_42"),
			"personagem gravado no slot")
	_check(not CharacterSlots.remember({"name": "Jaci"}, "account_42"), "2º nome não cabe no slot")
	_check(CharacterSlots.remember({"name": "IRACEMA", "appearance": {}}, "account_42")
			and (CharacterSlots.first_filled("account_42")["appearance"] as Dictionary) == app,
			"atualizar o mesmo personagem sem aparência não apaga a salva")
	_check(CharacterSlots.first_filled("account_9").is_empty(), "slots separados por conta")
	DirAccess.remove_absolute(CharacterSlots.path)
	CharacterSlots.path = old_path
