class_name ModMsg
extends RefCounted
## Chaves de tradução das mensagens de moderação (localization/moderation.csv). Usadas pelo
## servidor (Net.push_system_message) e pelo cliente (aviso de bloqueio no ChatBox).
## Durações vão como texto neutro "HH:MM:SS" / "Nd HH:MM:SS" (ModerationService.format_duration).

## args: [contadas (int), limite (int)]
const FILTERED: String = "SYS_MOD_FILTERED"
const WARNING: String = "SYS_MOD_WARNING"
## args: [duração (String)]
const MUTED_NOW: String = "SYS_MOD_MUTED_NOW"
## args: [tempo restante (String)] — mensagem recusada por bloqueio.
const MUTED: String = "SYS_MOD_MUTED"
const PENDING_REVIEW: String = "SYS_MOD_PENDING_REVIEW"
const CHARACTER_LOST: String = "SYS_MOD_CHARACTER_LOST"
## Aviso local do cliente (sem argumentos).
const MUTED_LOCAL: String = "SYS_MOD_MUTED_LOCAL"
## args: [tempo restante (String)]
const UI_BANNER: String = "UI_MOD_BANNER"
const UI_BANNER_REVIEW: String = "UI_MOD_BANNER_REVIEW"
