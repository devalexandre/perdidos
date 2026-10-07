extends Node
## Testes headless da moderação do chat (GDD §13, docs/moderacao.md):
##   - ProfanityFilter: burlas (leet, separadores, acentos, alfabetos parecidos, largura cheia,
##     invisíveis, letras repetidas, abreviações) em vários idiomas + falsos positivos (whitelist);
##   - nomes de personagem;
##   - ModerationService com relógio falso: janela móvel, escada, revisão humana, decaimento, log.
## Rodar: godot --headless --path game res://tests/moderation/test_moderation.tscn

const TEST_DIR: String = "user://moderation_unit_test/"
const MASK: String = ProfanityFilter.MASK
## Tempo médio máximo (ms) para filtrar uma mensagem de 200 caracteres.
const MAX_FILTER_MSEC: float = 4.0
const PERF_RUNS: int = 200

## Devem ser censurados (texto -> severidade mínima esperada).
const MUST_FILTER: Dictionary[String, int] = {
	# pt-BR
	"porra": 2, "PORRA": 2, "p0rr4": 2, "p o r r a": 2, "p.o.r.r.a": 2, "p-o-r-r-a": 2,
	"p_o_r_r_a": 2, "pôrrrrraaa": 2, "cáráƚho": 2, "c@r@lh0": 2, "karalho": 2, "caralhoooo": 2,
	"docaralho": 2, "caraio mano": 2, "vai tomar no cu": 2, "vtnc": 2, "v.t.n.c": 2, "fdp": 2,
	"f.d.p": 2, "FDP!": 2, "pqp": 2, "vsf": 2, "krl": 2, "tnc": 2, "seu filho da puta": 2,
	"filhodaputa": 2, "fi-lho da pu-ta": 2, "me​rda": 2, "ｐｏｒｒａ": 2, "рorra": 2,
	"b u c e t a": 2, "arrombado": 2, "que merda de dia": 2, "b0st4": 2, "m e r d a": 2,
	"viado": 3, "v1ad0": 3, "cu": 1,
	# en
	"fuck": 2, "f.u.c.k": 2, "fvck": 2, "ƒuck": 2, "f u c k": 2, "FUCK": 2, "fuuuuck": 2,
	"phuck": 2, "motherfucker": 2, "sh1t": 2, "$hit": 2, "b!tch": 2, "a$$hole": 2,
	"𝐟𝐮𝐜𝐤": 2, "ⓕⓤⓒⓚ": 2, "f​u​c​k": 2, "fúck": 2, "ｆｕｃｋ": 2,
	"fυck": 2, "𝓯𝓾𝓬𝓴": 2, "🅵🆄🅲🅺": 2, "f\u00a0u\u00a0c\u00a0k": 2, "F*U*C*K": 2, "wtf": 1,
	"саrаlhо": 2, "ｃａｒａｌｈｏ": 2, "P.U.T.A": 2, "puuuuta": 2, "c-a-r-a-l-h-o": 2,
	"p\u00adu\u00adt\u00ada": 2, "vai se f0d3r": 2, "\u200bf\u200bd\u200bp\u200b": 2, "nigger": 3, "n1gg3r": 3, "kys": 3,
	# es / fr / de / it
	"mierda": 2, "hijo de puta": 2, "coño": 2, "gilipollas": 2, "hdp": 2,
	"putain": 2, "merde": 2, "connard": 2, "salope": 2,
	"scheiße": 2, "arschloch": 2, "hurensohn": 2,
	"cazzo": 2, "vaffanculo": 2, "stronzo": 2,
	# ja
	"kuso": 1, "baka": 1, "ばか": 1, "バカ": 1, "ﾊﾞｶ": 1, "死ね": 2, "シネ": 2,
}

## Não podem ser censurados (Scunthorpe e palavras comuns do jogo).
var MUST_PASS: PackedStringArray = [
	"computador", "disputa", "reputação", "cuidado", "escuro", "Curupira", "fica aqui",
	"ficção científica", "o Saci pulou", "Olá, autoteste!", "picanha", "cuscuz", "putativo",
	"vamos vadiar", "porrete", "assim", "passar", "assado", "análise", "casa", "cacetinho",
	"merecer", "mercado", "cumprimento", "curso", "acumular", "documento", "Boitatá",
	"Mapinguari", "Iara", "vai tomar banho", "pau-brasil", "Porto do Despertar", "sucesso",
	"[autotest] weapon", "[autotest] done", "a e i o u", "Scunthorpe", "cocktail", "cockpit",
	"assassin", "class", "passion", "shiitake", "Dickens", "therapist", "analysis", "button",
	"hello there", "classic", "cucumber", "Sussex", "pussycat", "Hancock", "con leche", "cono",
	"computadora", "je suis en retard", "ばかりです", "しねまに行く", "Ana", "Bia", "Viajante",
	"x".repeat(200), "Eu comprei 3 poções por 45 Estrelas", "vamos caçar no bosque",
	"fodder", "pica-pau", "o cara lá", "é o fim", "vou ali e já volto",
	"Pedro", "assunto", "classe", "bosque", "cachorro", "porta", "portão", "merenda", "punho",
	"Hitchcock", "peacock", "bitter", "fuchsia", "sexta-feira", "Essex", "espírito", "cubo",
	"curar", "pacu", "caju", "Cuiabá", "fiscal", "ficou", "cacique", "costas", "pois é",
]

## Nomes de personagem.
const NAMES_DENIED: PackedStringArray = ["XxPorraxX", "Fuckmaster", "Caralh0", "FdP", "SrViado"]
const NAMES_ALLOWED: PackedStringArray = ["Viajante", "Ana", "Bia", "Scunthorpe", "Assis",
		"Cassandra", "Picasso", "Boitatá"]

var _checks: int = 0
var _failures: int = 0
var _t: int = 1_000_000


func _ready() -> void:
	var f := ProfanityFilter.new()
	_check("filter_loaded", f.is_ready() and f.terms.size() > 200, "terms=%d" % f.terms.size())
	_test_must_filter(f)
	_test_must_pass(f)
	_test_masking(f)
	_test_names(f)
	_test_perf(f)
	_test_sanctions()
	_test_decay()
	_test_config_resource()
	print("test_moderation: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(name: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL %s %s" % [name, detail])


func _test_must_filter(f: ProfanityFilter) -> void:
	for text: String in MUST_FILTER:
		var r: Dictionary = f.filter_text(text)
		_check("filter[%s]" % text, r["filtered"] and r["max_severity"] >= MUST_FILTER[text],
				"-> %s sev=%d" % [r["text"], r["max_severity"]])


func _test_must_pass(f: ProfanityFilter) -> void:
	for text: String in MUST_PASS:
		var r: Dictionary = f.filter_text(text)
		_check("pass[%s]" % text.left(30), not r["filtered"], "-> %s %s" % [r["text"], str(r["hits"])])


func _test_masking(f: ProfanityFilter) -> void:
	var cases: Dictionary[String, String] = {
		"que porra é essa": "que *** é essa",
		"olha: p o r r a!": "olha: ***!",
		"ｆｕｃｋ you": "*** you",
		"isso é m​e​rda mesmo": "isso é *** mesmo",
		"vai tomar no cu, fdp": "***, ***",
		"Olá, autoteste!": "Olá, autoteste!",
	}
	for text: String in cases:
		var out: String = f.filter_text(text)["text"]
		_check("mask[%s]" % text, out == cases[text], "-> '%s'" % out)
	# O log recebe o id do termo, nunca o texto do jogador.
	var hits: Array = f.filter_text("seu fdp")["hits"]
	_check("hit_has_term_id", hits.size() == 1 and hits[0]["id"] == "pt_BR:fdp", str(hits))


func _test_names(f: ProfanityFilter) -> void:
	for n: String in NAMES_DENIED:
		_check("name_denied[%s]" % n, not f.is_name_allowed(n))
	for n: String in NAMES_ALLOWED:
		_check("name_allowed[%s]" % n, f.is_name_allowed(n), str(f.check_name(n)["hits"]))


func _test_perf(f: ProfanityFilter) -> void:
	var msg: String = ("olá pessoal, alguém quer caçar no bosque? p0rr4 que lugar " \
			+ "lindo, vamos juntos até o portão ").repeat(3).left(200)
	var t0: int = Time.get_ticks_usec()
	for i: int in PERF_RUNS:
		f.filter_text(msg)
	var avg_ms: float = (Time.get_ticks_usec() - t0) / 1000.0 / PERF_RUNS
	print("  filter avg %.3f ms / 200 chars" % avg_ms)
	_check("filter_perf", avg_ms < MAX_FILTER_MSEC, "%.3f ms" % avg_ms)


# ---------------------------------------------------------------- sanções

func _clock() -> int:
	return _t


func _new_service(wipe: bool) -> ModerationService:
	var cfg: SanctionConfig = SanctionConfig.load_default()
	return ModerationService.new(cfg, ModerationStore.new(TEST_DIR, wipe), _clock)


func _say(svc: ModerationService, f: ProfanityFilter, account: String, text: String) -> Dictionary:
	return svc.on_message(account, account.capitalize(), text, f.filter_text(text))


func _test_sanctions() -> void:
	var f := ProfanityFilter.new()
	var svc: ModerationService = _new_service(true)
	var cfg: SanctionConfig = svc.config
	var acc: String = "spammer"
	# Leve: só censura, não conta.
	var r: Dictionary = _say(svc, f, acc, "wtf")
	_check("mild_masked_only", r["action"] == ModerationService.ACTION_MASKED, str(r))
	# Mensagem limpa: nada.
	r = _say(svc, f, acc, "olá")
	_check("clean_none", r["action"] == ModerationService.ACTION_NONE, str(r))
	# Janela: 3 palavrões em 10 min -> aviso (degrau 1).
	r = _say(svc, f, acc, "porra")
	_check("counted_1", r["action"] == ModerationService.ACTION_COUNTED and r["count"] == 1, str(r))
	_t += 10
	r = _say(svc, f, acc, "merda")
	_check("counted_2", r["action"] == ModerationService.ACTION_COUNTED and r["count"] == 2, str(r))
	_t += 10
	r = _say(svc, f, acc, "fdp")
	_check("strike_1_warning", r["action"] == ModerationService.ACTION_WARNING and r["level"] == 1, str(r))
	_check("warning_can_chat", svc.check_chat(acc)["allowed"])
	# Janela móvel: mensagens antigas saem.
	_say(svc, f, acc, "porra")
	_t += cfg.window_sec + 1
	r = _say(svc, f, acc, "porra")
	_check("window_expired", r["action"] == ModerationService.ACTION_COUNTED and r["count"] == 1, str(r))
	_t += 5
	_say(svc, f, acc, "porra")
	_t += 5
	r = _say(svc, f, acc, "porra")
	_check("strike_2_mute_1h", r["action"] == ModerationService.ACTION_MUTE and r["level"] == 2
			and r["mute_sec"] == 3600, str(r))
	var c: Dictionary = svc.check_chat(acc)
	_check("muted_rejects", not c["allowed"] and c["reason"] == ModerationService.REASON_MUTED
			and c["seconds_left"] == 3600, str(c))
	_t += 1800
	_check("muted_time_left", svc.check_chat(acc)["seconds_left"] == 1800)
	_t += 1800
	_check("mute_expires", svc.check_chat(acc)["allowed"])
	# Ofensa de ódio: strike imediato -> 6 h.
	r = _say(svc, f, acc, "seu viado")
	_check("slur_immediate_6h", r["action"] == ModerationService.ACTION_MUTE and r["level"] == 3
			and r["mute_sec"] == 21600, str(r))
	_t += 21600
	r = _say(svc, f, acc, "n1gg3r")
	_check("strike_4_24h", r["level"] == 4 and r["mute_sec"] == 86400, str(r))
	_t += 86400
	r = _say(svc, f, acc, "kys")
	_check("strike_5_7d", r["level"] == 5 and r["mute_sec"] == 604800, str(r))
	_t += 604800
	# Degrau 6 (30 dias): exige revisão, fica bloqueado até lá.
	r = _say(svc, f, acc, "nigger")
	_check("strike_6_pending", r["action"] == ModerationService.ACTION_PENDING_REVIEW
			and r["level"] == 6 and not str(r["case_id"]).is_empty(), str(r))
	c = svc.check_chat(acc)
	_check("pending_blocks_chat", not c["allowed"] and c["reason"] == ModerationService.REASON_PENDING)
	_t += 90 * SanctionConfig.SEC_PER_DAY
	_check("pending_does_not_decay_or_expire", not svc.check_chat(acc)["allowed"]
			and svc.get_record(acc).level == 6)
	var pend: Array[Dictionary] = svc.list_pending()
	_check("list_pending", pend.size() == 1 and pend[0]["account"] == acc, str(pend))
	_check("review_wrong_case", not svc.review(acc, "nope", true, "tester"))
	_check("review_approve", svc.review(acc, r["case_id"], true, "tester", "confirmado"))
	c = svc.check_chat(acc)
	_check("approved_30d", not c["allowed"] and c["seconds_left"] == 2592000, str(c))
	_t += 2592000
	_check("30d_expires", svc.check_chat(acc)["allowed"])
	# Degrau 7 (perda do personagem): revisão; rejeitar volta 1 degrau e libera.
	r = _say(svc, f, acc, "nigger")
	_check("strike_7_pending_loss", r["action"] == ModerationService.ACTION_PENDING_REVIEW
			and r["level"] == 7, str(r))
	_check("review_reject", svc.review(acc, r["case_id"], false, "tester", "falso positivo"))
	var rec: ModerationRecord = svc.get_record(acc)
	_check("rejected_back_to_6", rec.level == 6 and not rec.has_pending() and svc.check_chat(acc)["allowed"])
	r = _say(svc, f, acc, "nigger")
	_check("strike_7_again", r["action"] == ModerationService.ACTION_PENDING_REVIEW and r["level"] == 7)
	_check("never_auto_lost", not svc.is_character_lost(acc))
	svc.review(acc, r["case_id"], true, "tester")
	c = svc.check_chat(acc)
	_check("character_lost", svc.is_character_lost(acc) and c["reason"] == ModerationService.REASON_LOST)
	# Persistência: outro serviço (novo processo) lê o mesmo estado.
	var svc2: ModerationService = _new_service(false)
	_check("persisted", svc2.get_record(acc).character_lost and svc2.get_record(acc).level == 7)
	# Log: ações registradas, com hash e sem o texto original.
	var log_text: String = FileAccess.get_file_as_string(svc.store.log_path())
	var entries: Array[Dictionary] = svc.store.read_log()
	var actions: Dictionary = {}
	for e: Dictionary in entries:
		actions[e["action"]] = true
	for a: String in [ModerationService.LOG_FILTERED, ModerationService.LOG_STRIKE,
			ModerationService.LOG_PENDING, ModerationService.LOG_REVIEW_APPROVED,
			ModerationService.LOG_REVIEW_REJECTED]:
		_check("log_has_%s" % a, actions.has(a))
	var filtered_entry: Dictionary = {}
	for e: Dictionary in entries:
		if e["action"] == ModerationService.LOG_FILTERED:
			filtered_entry = e
			break
	_check("log_entry_fields", filtered_entry.get("msg_hash", "").length() == 64
			and filtered_entry.has("filtered_text") and filtered_entry.has("terms")
			and filtered_entry.has("time") and filtered_entry.get("actor") == "system", str(filtered_entry))
	_check("log_no_raw_text", not log_text.contains("n1gg3r") and not log_text.contains("seu viado"))
	_check("format_duration", ModerationService.format_duration(3600) == "01:00:00"
			and ModerationService.format_duration(2592000) == "30d 00:00:00"
			and ChatBox.parse_duration("30d 00:00:00") == 2592000
			and ChatBox.parse_duration("01:02:03") == 3723)


func _test_decay() -> void:
	var f := ProfanityFilter.new()
	var svc: ModerationService = _new_service(true)
	var acc: String = "arrependido"
	for i: int in 6:
		_say(svc, f, acc, "porra")
		_t += 5
	var rec: ModerationRecord = svc.get_record(acc)
	_check("decay_setup_level2", rec.level == 2 and rec.mute_until > _t)
	var day: int = SanctionConfig.SEC_PER_DAY
	# 30 dias contados a partir do FIM do bloqueio.
	_t = rec.mute_until + 29 * day
	_check("no_decay_before_30d", svc.get_record(acc).level == 2)
	_t = rec.mute_until + 30 * day + 1
	_check("decay_one_level", svc.get_record(acc).level == 1)
	_t += 60 * day
	_check("decay_to_zero", svc.get_record(acc).level == 0)
	# Depois de limpo, recomeça no aviso.
	for i: int in 3:
		_say(svc, f, acc, "merda")
	_check("after_decay_warning_again", svc.get_record(acc).level == 1)


func _test_config_resource() -> void:
	var cfg: SanctionConfig = SanctionConfig.load_default()
	_check("config_ladder", Array(cfg.ladder_mute_sec) == [0, 3600, 21600, 86400, 604800, 2592000, -1]
			and cfg.review_from_level == 6 and cfg.max_level() == 7, str(cfg.ladder_mute_sec))
	_check("config_review_last_two", not cfg.needs_review(5) and cfg.needs_review(6) and cfg.needs_review(7))
