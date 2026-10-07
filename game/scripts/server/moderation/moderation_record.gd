class_name ModerationRecord
extends RefCounted
## Estado de sanção de UMA conta (hoje conta = nome do personagem em minúsculas; quando existir o
## login de conta, a chave passa a ser o id da conta). Formato JSON compartilhado com
## tools/moderation_review.py — mudou aqui, mude lá.

const FORMAT_VERSION: int = 1

var account: String = ""
## Último personagem visto nesta conta.
var character: String = ""
## Degrau atual da escada (0 = limpo; 1 = aviso; ...).
var level: int = 0
## Horários (unix s) das mensagens censuradas que contam, dentro da janela móvel.
var window: Array[int] = []
## Fim do bloqueio de chat (unix s; 0 = sem bloqueio).
var mute_until: int = 0
## Caso aguardando revisão humana ({} = nenhum): case_id, level, proposed_sec, created.
var pending: Dictionary = {}
## Perda do personagem aprovada por um revisor: entrada no jogo bloqueada. Nada é apagado.
var character_lost: bool = false
var last_strike: int = 0
var last_decay: int = 0
var strikes_total: int = 0


func to_dict() -> Dictionary:
	return {
		"format": FORMAT_VERSION,
		"account": account,
		"character": character,
		"level": level,
		"window": window,
		"mute_until": mute_until,
		"pending": pending,
		"character_lost": character_lost,
		"last_strike": last_strike,
		"last_decay": last_decay,
		"strikes_total": strikes_total,
	}


static func from_dict(d: Dictionary) -> ModerationRecord:
	var r := ModerationRecord.new()
	r.account = str(d.get("account", ""))
	r.character = str(d.get("character", ""))
	r.level = maxi(int(d.get("level", 0)), 0)
	var w: Variant = d.get("window", [])
	if typeof(w) == TYPE_ARRAY:
		for t: Variant in w:
			r.window.append(int(t))
	r.mute_until = int(d.get("mute_until", 0))
	var p: Variant = d.get("pending", {})
	r.pending = p if typeof(p) == TYPE_DICTIONARY else {}
	r.character_lost = bool(d.get("character_lost", false))
	r.last_strike = int(d.get("last_strike", 0))
	r.last_decay = int(d.get("last_decay", 0))
	r.strikes_total = int(d.get("strikes_total", 0))
	return r


func has_pending() -> bool:
	return not pending.is_empty()
