class_name ModerationService
extends RefCounted
## Sanção progressiva do chat (GDD §13). Servidor. Guia: docs/moderacao.md.
##
## - Mensagem censurada com severidade >= count_min_severity entra numa janela móvel; ao chegar a
##   filtered_msgs_per_strike dentro de window_sec, vira 1 strike. Ofensa de ódio (severidade >=
##   immediate_strike_severity) = 1 strike na hora.
## - Cada strike sobe 1 degrau (SanctionConfig.ladder_mute_sec): aviso → 1 h → 6 h → 24 h →
##   7 dias → 30 dias → perda do personagem.
## - Degraus >= review_from_level NÃO valem sozinhos: abrem um caso PENDING_REVIEW no log e o chat
##   fica bloqueado até um humano aprovar ou rejeitar (tools/moderation_review.py). Nada é apagado
##   automaticamente; "perda do personagem" aprovada só bloqueia a entrada.
## - Decaimento: cada decay_clean_sec sem strike (contado depois do fim do bloqueio) desce 1 degrau.
## - Tudo vai para o log (quem, o quê, quando, hash da mensagem original, texto filtrado, termos).
## O relógio é injetável (testes usam um relógio falso).

const ACTION_NONE: String = "none"
## Censurada, mas não conta (severidade leve).
const ACTION_MASKED: String = "masked"
## Censurada e contada na janela, sem strike ainda.
const ACTION_COUNTED: String = "counted"
const ACTION_WARNING: String = "warning"
const ACTION_MUTE: String = "mute"
const ACTION_PENDING_REVIEW: String = "pending_review"

const REASON_MUTED: String = "muted"
const REASON_PENDING: String = "pending_review"
const REASON_LOST: String = "character_lost"

# Ações do log.
const LOG_FILTERED: String = "filtered"
const LOG_STRIKE: String = "strike"
const LOG_PENDING: String = "pending_review"
const LOG_BLOCKED: String = "chat_blocked"
const LOG_DECAY: String = "decay"
const LOG_REVIEW_APPROVED: String = "review_approved"
const LOG_REVIEW_REJECTED: String = "review_rejected"
const LOG_NAME_FLAGGED: String = "name_flagged"
const ACTOR_SYSTEM: String = "system"

var config: SanctionConfig = null
var store: ModerationStore = null
var _clock: Callable = Callable()


## `clock`: função sem argumentos que devolve o horário unix em segundos (padrão: relógio real).
func _init(p_config: SanctionConfig, p_store: ModerationStore, clock: Callable = Callable()) -> void:
	config = p_config
	store = p_store
	_clock = clock


func now() -> int:
	if _clock.is_valid():
		return int(_clock.call())
	return int(Time.get_unix_time_from_system())


func get_record(account: String) -> ModerationRecord:
	var rec: ModerationRecord = store.get_record(account)
	_apply_decay(rec)
	return rec


## Pode falar no chat? {allowed, reason, seconds_left (-1 = indefinido)}.
func check_chat(account: String) -> Dictionary:
	var rec: ModerationRecord = get_record(account)
	if rec.character_lost:
		return {"allowed": false, "reason": REASON_LOST, "seconds_left": -1}
	if rec.has_pending():
		return {"allowed": false, "reason": REASON_PENDING, "seconds_left": -1}
	var left: int = rec.mute_until - now()
	if left > 0:
		return {"allowed": false, "reason": REASON_MUTED, "seconds_left": left}
	return {"allowed": true, "reason": "", "seconds_left": 0}


func is_character_lost(account: String) -> bool:
	return get_record(account).character_lost


## Registra uma tentativa de falar bloqueada (vai para o log, sem o texto).
func log_blocked(account: String, character: String, raw: String, reason: String) -> void:
	_log(LOG_BLOCKED, get_record(account), {"character": character, "reason": reason,
			"msg_hash": store.hash_message(raw)})


## Processa uma mensagem já filtrada (`result` = ProfanityFilter.filter_text). Devolve
## {action, level, mute_sec, count, needed, case_id}.
func on_message(account: String, character: String, raw: String, result: Dictionary) -> Dictionary:
	var out: Dictionary = {"action": ACTION_NONE, "level": 0, "mute_sec": 0, "count": 0,
			"needed": config.filtered_msgs_per_strike, "case_id": ""}
	if not result.get("filtered", false):
		return out
	var rec: ModerationRecord = get_record(account)
	rec.character = character
	var sev: int = int(result.get("max_severity", 0))
	var t: int = now()
	var terms: Array = []
	for h: Dictionary in result.get("hits", []):
		terms.append(h["id"])
	var details: Dictionary = {"character": character, "msg_hash": store.hash_message(raw),
			"filtered_text": result.get("text", ""), "terms": terms, "severity": sev}
	_log(LOG_FILTERED, rec, details)
	out["level"] = rec.level
	if sev >= config.immediate_strike_severity:
		return _strike(rec, "immediate_severity_%d" % sev, details, out)
	if sev < config.count_min_severity:
		out["action"] = ACTION_MASKED
		store.save_record(rec)
		return out
	_prune_window(rec, t)
	rec.window.append(t)
	out["count"] = rec.window.size()
	if rec.window.size() >= config.filtered_msgs_per_strike:
		return _strike(rec, "window_%d_in_%ds" % [rec.window.size(), config.window_sec], details, out)
	out["action"] = ACTION_COUNTED
	store.save_record(rec)
	return out


## Nome de personagem suspeito (não bloqueia; vai para o log para um humano decidir).
func log_name_flagged(account: String, character: String, terms: Array) -> void:
	_log(LOG_NAME_FLAGGED, get_record(account), {"character": character, "terms": terms})


## Casos aguardando revisão humana.
func list_pending() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec: ModerationRecord in store.all_records():
		if rec.has_pending():
			var d: Dictionary = rec.pending.duplicate()
			d["account"] = rec.account
			d["character"] = rec.character
			out.append(d)
	return out


## Decisão humana sobre um caso. approve = o degrau vale (bloqueio de 30 dias a partir de agora, ou
## perda do personagem = entrada bloqueada); reject = falso positivo/sanção indevida: volta um
## degrau e libera o chat. false se o caso não existe.
func review(account: String, case_id: String, approve: bool, reviewer: String, note: String = "") -> bool:
	var rec: ModerationRecord = store.get_record(account)
	if not rec.has_pending() or str(rec.pending.get("case_id", "")) != case_id:
		return false
	var proposed: int = int(rec.pending.get("proposed_sec", 0))
	var t: int = now()
	if approve:
		if proposed == SanctionConfig.CHARACTER_LOSS:
			rec.character_lost = true
		else:
			rec.mute_until = maxi(rec.mute_until, t + proposed)
	else:
		rec.level = maxi(rec.level - 1, 0)
		rec.mute_until = 0
	rec.pending = {}
	# O tempo limpo do decaimento recomeça na decisão.
	rec.last_decay = t
	store.save_record(rec)
	_log(LOG_REVIEW_APPROVED if approve else LOG_REVIEW_REJECTED, rec,
			{"case_id": case_id, "actor": reviewer, "note": note, "proposed_sec": proposed})
	return true


## Texto de duração neutro de idioma para as mensagens de sistema: "HH:MM:SS" ou "Nd HH:MM:SS"
## (o cliente lê de volta para o contador do aviso de bloqueio).
static func format_duration(sec: int) -> String:
	sec = maxi(sec, 0)
	var d: int = sec / SanctionConfig.SEC_PER_DAY
	var rest: int = sec % SanctionConfig.SEC_PER_DAY
	var hms: String = "%02d:%02d:%02d" % [rest / 3600, (rest % 3600) / 60, rest % 60]
	return ("%dd %s" % [d, hms]) if d > 0 else hms


# ---------------------------------------------------------------- interno

func _strike(rec: ModerationRecord, reason: String, details: Dictionary, out: Dictionary) -> Dictionary:
	var t: int = now()
	rec.window.clear()
	rec.level = mini(rec.level + 1, config.max_level())
	rec.last_strike = t
	rec.strikes_total += 1
	var dur: int = config.mute_for_level(rec.level)
	out["level"] = rec.level
	var extra: Dictionary = details.duplicate()
	extra["reason"] = reason
	if config.needs_review(rec.level):
		if not rec.has_pending():
			rec.pending = {"case_id": "C%d-%s" % [t, Crypto.new().generate_random_bytes(3).hex_encode()],
					"level": rec.level, "proposed_sec": dur, "created": t, "reason": reason}
		out["action"] = ACTION_PENDING_REVIEW
		out["case_id"] = rec.pending["case_id"]
		store.save_record(rec)
		_log(LOG_STRIKE, rec, extra)
		_log(LOG_PENDING, rec, {"character": rec.character, "case_id": rec.pending["case_id"],
				"proposed_sec": dur})
		return out
	if dur > 0:
		rec.mute_until = maxi(rec.mute_until, t + dur)
		out["action"] = ACTION_MUTE
		out["mute_sec"] = rec.mute_until - t
	else:
		out["action"] = ACTION_WARNING
	store.save_record(rec)
	_log(LOG_STRIKE, rec, extra)
	return out


func _prune_window(rec: ModerationRecord, t: int) -> void:
	var keep: Array[int] = []
	for ts: int in rec.window:
		if t - ts < config.window_sec:
			keep.append(ts)
	rec.window = keep


## Desce 1 degrau a cada decay_clean_sec limpo. Casos em revisão e perda aprovada não decaem.
func _apply_decay(rec: ModerationRecord) -> void:
	if rec.level <= 0 or rec.has_pending() or rec.character_lost or config.decay_clean_sec <= 0:
		return
	var base: int = maxi(maxi(rec.last_strike, rec.mute_until), rec.last_decay)
	var t: int = now()
	if t - base < config.decay_clean_sec:
		return
	var steps: int = (t - base) / config.decay_clean_sec
	var old: int = rec.level
	rec.level = maxi(rec.level - steps, 0)
	rec.last_decay = base + steps * config.decay_clean_sec
	store.save_record(rec)
	_log(LOG_DECAY, rec, {"from_level": old, "steps": steps})


func _log(action: String, rec: ModerationRecord, extra: Dictionary) -> void:
	var t: int = now()
	var e: Dictionary = {"ts": t, "time": Time.get_datetime_string_from_unix_time(t, true) + "Z",
			"action": action, "actor": ACTOR_SYSTEM, "account": rec.account,
			"level": rec.level, "mute_until": rec.mute_until}
	e.merge(extra, true)
	store.append_log(e)
