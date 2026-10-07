class_name SanctionConfig
extends Resource
## Constantes da sanção progressiva do chat (GDD §13) — [PROVISÓRIO], ajustáveis sem código em
## data/chat/sanctions.tres. Explicação completa: docs/moderacao.md.

const DEFAULT_PATH: String = "res://data/chat/sanctions.tres"
## Valor especial em ladder_mute_sec: perda do personagem.
const CHARACTER_LOSS: int = -1
const SEC_PER_HOUR: int = 3600
const SEC_PER_DAY: int = 86400

@export_group("Strikes")
## Janela móvel (s) em que as mensagens censuradas são contadas.
@export var window_sec: int = 600
## Mensagens censuradas dentro da janela que geram 1 strike.
@export var filtered_msgs_per_strike: int = 3
## Só termos com severidade >= esta contam para a janela (1 = leve só é censurado).
@export var count_min_severity: int = 2
## Termos com severidade >= esta dão 1 strike na hora (ofensa de ódio).
@export var immediate_strike_severity: int = 3

@export_group("Ladder")
## Degraus, na ordem do 1º strike em diante: 0 = só aviso, N = bloqueio de chat de N s,
## -1 = perda do personagem. Padrão do GDD: aviso → 1 h → 6 h → 24 h → 7 dias → 30 dias → perda.
@export var ladder_mute_sec: PackedInt64Array = PackedInt64Array([0, 3600, 21600, 86400, 604800,
		2592000, -1])
## Degraus a partir deste (1 = primeiro) exigem revisão humana antes de valer; até lá o jogador
## fica com o chat bloqueado. Padrão: os dois últimos (30 dias e perda do personagem).
@export var review_from_level: int = 6

@export_group("Decay")
## Cada período limpo (sem strike, depois do fim do último bloqueio) desce 1 degrau.
@export var decay_clean_sec: int = 2592000

@export_group("Log")
## Dias que o log de moderação é guardado (LGPD: minimização). Usado por
## tools/moderation_review.py purge.
@export var log_retention_days: int = 365


func max_level() -> int:
	return ladder_mute_sec.size()


## Duração do degrau `level` (1..max). 0 = aviso; -1 = perda do personagem.
func mute_for_level(level: int) -> int:
	if level <= 0:
		return 0
	return ladder_mute_sec[mini(level, ladder_mute_sec.size()) - 1]


func needs_review(level: int) -> bool:
	return level >= review_from_level


static func load_default() -> SanctionConfig:
	if ResourceLoader.exists(DEFAULT_PATH):
		var r: Resource = load(DEFAULT_PATH)
		if r is SanctionConfig:
			return r as SanctionConfig
	push_warning("Sanction config missing, using defaults: %s" % DEFAULT_PATH)
	return SanctionConfig.new()
