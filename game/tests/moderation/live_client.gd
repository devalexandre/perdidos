extends Node
## Autoteste de moderação com servidor de verdade (tests/moderation/run_moderation_autotest.sh).
## Sobe o jogo normal (scenes/main.tscn como /root/Main, cliente com --name) e, depois de nascer:
##   --mod-phase=spam    (padrão) palavrões em sequência → censura "***" → contagem → aviso (strike 1)
##                       → bloqueio de 1 h (strike 2) → mensagem limpa recusada com o tempo restante;
##                       confere o aviso de bloqueio do ChatBox e o registro gravado pelo servidor.
##   --mod-phase=relogin mesmo nome de novo: o servidor avisa o bloqueio já na entrada e recusa chat.
## Imprime "moderation_check {...}" por verificação e "RESULT: PASS|FAIL"; código de saída 0 = passou.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const ARG_PHASE: String = "mod-phase"
const PHASE_SPAM: String = "spam"
const PHASE_RELOGIN: String = "relogin"
const SETTLE_SEC: float = 2.0
const GAP_SEC: float = 1.3
const WAIT_SEC: float = 4.0
const SPAWN_TIMEOUT_SEC: float = 40.0
const RECORDS_DIR: String = "user://moderation_autotest/records/"
const MUTE_1H: int = 3600
## Seis mensagens com palavrão (3 = aviso, 6 = bloqueio de 1 h, janela padrão de 3).
const SPAM: PackedStringArray = ["que porra é essa", "m e r d a", "seu fdp", "p0rr4 de novo",
		"cáráƚho", "vai tomar no cu"]
const CLEAN: String = "desculpa, pessoal"

var _args: Dictionary[String, String] = {}
var _events: Array[Dictionary] = []
var _failures: int = 0
var _checks: int = 0
var _spawned: bool = false
var _name: String = ""


func _ready() -> void:
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with("--"):
			var kv: PackedStringArray = raw.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_name = _args.get("name", "Boca")
	Net.chat_received.connect(func(c: StringName, f: String, t: String, e: int) -> void:
		_events.append({"t": "chat", "from": f, "text": t}))
	Net.system_message.connect(func(k: String, a: Array) -> void:
		_events.append({"t": "sys", "key": k, "args": a})
		print("[mod] system ", k, " ", a))
	Net.local_player_spawned.connect(func(_p: Node3D) -> void: _spawned = true)
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	_run.call_deferred()


func _run() -> void:
	var t0: int = Time.get_ticks_msec()
	while not _spawned and Time.get_ticks_msec() - t0 < SPAWN_TIMEOUT_SEC * 1000:
		await get_tree().process_frame
	if not _check("spawned", _spawned):
		_finish()
		return
	await _wait(SETTLE_SEC)
	if _args.get(ARG_PHASE, PHASE_SPAM) == PHASE_RELOGIN:
		await _run_relogin()
	else:
		await _run_spam()
	_finish()


func _run_spam() -> void:
	for i: int in SPAM.size():
		_events.clear()
		Net.send_chat(&"local", SPAM[i])
		await _wait(GAP_SEC)
		var echo: Dictionary = _find("chat")
		_check("filtered_echo_%d" % i, not echo.is_empty() and echo["text"].contains("***")
				and not echo["text"].to_lower().contains("porra") and not echo["text"].contains("fdp"),
				echo)
		match i:
			0, 1, 3, 4:
				var sys: Dictionary = _find("sys", ModMsg.FILTERED)
				_check("counted_%d" % i, not sys.is_empty(), _events)
			2:
				_check("strike1_warning", not _find("sys", ModMsg.WARNING).is_empty(), _events)
			5:
				var mute: Dictionary = _find("sys", ModMsg.MUTED_NOW)
				_check("strike2_mute_1h", not mute.is_empty() and mute["args"] == ["01:00:00"], _events)
	# Bloqueado: mensagem limpa é recusada com o tempo restante e não chega a ninguém.
	_events.clear()
	# (O ChatBox não deixa enviar enquanto bloqueado; o teste chama a rede direto.)
	Net.send_chat(&"local", CLEAN)
	await _wait(GAP_SEC + 0.5)
	var rej: Dictionary = _find("sys", ModMsg.MUTED)
	_check("muted_message_rejected", not rej.is_empty() and _find("chat").is_empty(), _events)
	if not rej.is_empty():
		var left: int = ChatBox.parse_duration(str(rej["args"][0]))
		_check("rejection_has_time_left", left > MUTE_1H - 60 and left <= MUTE_1H, rej)
	_check("chatbox_banner_muted", ChatBox.is_muted() and ChatBox.muted_seconds_left() > MUTE_1H - 60,
			ChatBox.muted_seconds_left())
	var box: Node = get_tree().root.find_child("ChatBox", true, false)
	if box != null:
		var banner: Label = box.find_child("MutedBanner", true, false) as Label
		await _wait(0.5)
		_check("chatbox_banner_visible", banner != null and banner.visible
				and banner.text.contains("00:"), banner.text if banner != null else "no banner")
		_check("chatbox_blocks_locally", not (box as ChatBox).submit("oi"))
	# Registro gravado pelo servidor (mesma pasta user:// neste computador).
	var path: String = RECORDS_DIR + _name.to_lower() + ".json"
	var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) \
			if FileAccess.file_exists(path) else null
	_check("record_persisted", rec is Dictionary and int(rec["level"]) == 2
			and int(rec["mute_until"]) > int(Time.get_unix_time_from_system()), rec)


func _run_relogin() -> void:
	# O aviso chega logo na entrada (antes do SETTLE).
	var at_login: Dictionary = _find("sys", ModMsg.MUTED)
	_check("relogin_notified_muted", not at_login.is_empty(), _events)
	_events.clear()
	Net.send_chat(&"local", CLEAN)
	await _wait(GAP_SEC + 0.5)
	_check("relogin_chat_rejected", not _find("sys", ModMsg.MUTED).is_empty()
			and _find("chat").is_empty(), _events)


func _find(t: String, key: String = "") -> Dictionary:
	for e: Dictionary in _events:
		if e["t"] == t and (key.is_empty() or e.get("key", "") == key):
			return e
	return {}


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _check(check_name: String, ok: bool, detail: Variant = null) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
	print("moderation_check ", JSON.stringify({"check": check_name, "pass": ok,
			"detail": str(detail).left(300)}))
	return ok


func _finish() -> void:
	print("moderation_result: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)
