class_name ChatService
extends RefCounted
## Chat e emotes (GDD §13). Canal &"local" = mesmo mapa; &"party" = membros do grupo em qualquer mapa
## ("/g <mensagem>" ou a aba "Grupo" do chat). Sussurro fica para depois.
## Comandos de grupo (pt-BR, PartyService): "/grupo <nome>", "/grupo aceitar|recusar|sair",
## "/grupo expulsar <nome>", "/grupo líder <nome>", "/grupo" (lista) e "/online". Comandos não são
## mensagem: não passam pelo limite de 1/s nem pelo bloqueio de chat (o convite tem antispam próprio).
## Limites: 1 mensagem/s por jogador e ≤ 200 caracteres.
## Moderação (docs/moderacao.md): ProfanityFilter troca palavrões/ofensas por "***" (qualquer
## idioma e forma de burla; listas em data/chat/profanity/) e a mensagem segue; ModerationService
## conta a insistência e aplica a sanção progressiva (data/chat/sanctions.tres). Jogador bloqueado
## não fala: o servidor recusa com uma mensagem de sistema com o tempo restante.
## Emotes vão para todos da instância; &"sit" alterna a animação de sentar.

## GDD §15.4: ≤ 200 caracteres.
const MAX_CHAT_LENGTH: int = 200
## GDD §13: limite de 1 mensagem por segundo.
const MIN_INTERVAL_MSEC: int = 1000
const CHANNELS: Array[StringName] = [Net.CHANNEL_LOCAL, Net.CHANNEL_PARTY]
## Comandos de grupo e lista de quem está online (sem diferenciar maiúsculas).
const CMD_PARTY: Array[String] = ["/grupo", "/group", "/party"]
const CMD_PARTY_CHAT: Array[String] = ["/g", "/p"]
const CMD_ONLINE: Array[String] = ["/online", "/quem"]
## Troca entre personagens (TradeService): "/troca <nome>", "/troca aceitar|recusar|cancelar".
const CMD_TRADE: Array[String] = ["/troca", "/trade"]
## Personagem com perda aprovada: tempo para a mensagem chegar antes de desconectar.
const LOST_KICK_DELAY_SEC: float = 1.0
## Servidor com --dev-commands: "/dev <comando> [args]" vai para o ProgressionDebug (nunca em produção;
## ver docs/debug-pindorama.md). Não passa pelo filtro nem aparece para ninguém.
const DEV_PREFIX: String = "/dev"
const MAX_DEV_ARGS: int = 8

var world: ServerWorld = null
var filter: ProfanityFilter = null
var moderation: ModerationService = null


func _init(p_world: ServerWorld) -> void:
	world = p_world
	filter = ProfanityFilter.new()
	var autotest: bool = world != null and world.autotest
	var store := ModerationStore.new(ModerationStore.AUTOTEST_DIR if autotest else ModerationStore.DEFAULT_DIR,
			autotest)
	moderation = ModerationService.new(SanctionConfig.load_default(), store)
	Net.log_line("chat_filter_loaded", {"terms": filter.terms.size(),
			"whitelist": filter.whitelist.size(), "moderation_dir": store.dir})


## Conta do jogador para a sanção. Hoje = personagem; com login de conta, trocar pelo id da conta.
static func account_id(session: PlayerSession) -> String:
	return session.character.char_name.to_lower()


## Texto com os trechos ofensivos trocados por "***".
func filter_text(text: String) -> String:
	return filter.filter_text(text)["text"]


## Chamado pelo ServerWorld quando o jogador entra no mundo: avisa bloqueio ativo, desconecta
## personagem com perda aprovada e registra nome suspeito para revisão.
func on_player_ready(session: PlayerSession) -> void:
	var account: String = account_id(session)
	var name_check: Dictionary = filter.check_name(session.character.char_name)
	if not name_check["allowed"]:
		var terms: Array = name_check["hits"].map(func(h: Dictionary) -> String: return h["id"])
		moderation.log_name_flagged(account, session.character.char_name, terms)
		Net.log_line("moderation_name_flagged", {"peer": session.peer_id, "terms": terms})
	_notify_block(session, moderation.check_chat(account), true)


func chat(session: PlayerSession, channel: StringName, raw_text: String) -> void:
	if not (channel in CHANNELS):
		Net.log_invalid(session.peer_id, "chat_bad_channel", {"channel": String(channel)})
		return
	var text: String = raw_text.strip_escapes().strip_edges()
	if text.is_empty():
		Net.log_invalid(session.peer_id, "chat_empty")
		return
	if NetProgress.dev_commands and text.begins_with(DEV_PREFIX):
		_dev_command(session, text.trim_prefix(DEV_PREFIX))
		return
	if text.begins_with("/") and world.party != null:
		var word: String = text.get_slice(" ", 0).to_lower()
		var rest: String = text.substr(word.length()).strip_edges()
		if word in CMD_PARTY:
			world.party.chat_command(session, rest)
			return
		if word in CMD_ONLINE:
			world.party.command(session, NetParty.CMD_ONLINE, "")
			return
		if word in CMD_TRADE and world.trade != null:
			world.trade.chat_command(session, rest)
			return
		if word in CMD_PARTY_CHAT:
			if rest.is_empty():
				Net.log_invalid(session.peer_id, "chat_empty")
				return
			channel = Net.CHANNEL_PARTY
			text = rest
	# Comandos de teste do dono (/chefe, /noite...): só com --dev-commands ou --autotest (MonsterDebug).
	var dbg: MonsterDebug = world.combat.spawner.debug if world.combat != null else null
	if dbg != null and dbg.handle_chat(session, text):
		return
	if text.length() > MAX_CHAT_LENGTH:
		Net.log_invalid(session.peer_id, "chat_too_long", {"length": text.length()})
		Net.push_system_message(session.peer_id, SysMsg.CHAT_TOO_LONG, [MAX_CHAT_LENGTH])
		return
	var account: String = account_id(session)
	var block: Dictionary = moderation.check_chat(account)
	if not block["allowed"]:
		Net.log_invalid(session.peer_id, "chat_muted", {"reason": block["reason"],
				"seconds_left": block["seconds_left"]})
		moderation.log_blocked(account, session.character.char_name, text, block["reason"])
		_notify_block(session, block, false)
		return
	var now: int = Time.get_ticks_msec()
	if now - session.last_chat_msec < MIN_INTERVAL_MSEC:
		Net.log_invalid(session.peer_id, "chat_too_fast")
		Net.push_system_message(session.peer_id, SysMsg.CHAT_TOO_FAST)
		return
	session.last_chat_msec = now
	var result: Dictionary = filter.filter_text(text)
	var clean: String = result["text"]
	var e: NetEntity = session.entity
	var peers: Array[int] = Net.get_instance_peer_ids(e.instance_id)
	if channel == Net.CHANNEL_PARTY:
		if world.party == null or world.party.party_of_peer(session.peer_id) == null:
			Net.log_invalid(session.peer_id, "chat_party_without_party")
			Net.push_system_message(session.peer_id, PartyService.MSG_ERR_NO_PARTY)
			return
		peers = world.party.member_peers(session.peer_id)
	Net.push_chat(peers, channel, e.display_name, clean, e.entity_id)
	# (O texto original não vai para o log do servidor: só o filtrado.)
	Net.log_line("chat", {"peer": session.peer_id, "channel": String(channel),
			"instance": String(e.instance_id), "text": clean, "filtered": result["filtered"],
			"recipients": peers.size()})
	if result["filtered"]:
		_apply_sanction(session, moderation.on_message(account, session.character.char_name, text,
				result))


func _apply_sanction(session: PlayerSession, r: Dictionary) -> void:
	Net.log_line("moderation", {"peer": session.peer_id, "action": r["action"], "level": r["level"],
			"mute_sec": r["mute_sec"], "count": r["count"], "case_id": r["case_id"]})
	match r["action"]:
		ModerationService.ACTION_COUNTED:
			Net.push_system_message(session.peer_id, ModMsg.FILTERED, [r["count"], r["needed"]])
		ModerationService.ACTION_WARNING:
			Net.push_system_message(session.peer_id, ModMsg.WARNING)
		ModerationService.ACTION_MUTE:
			Net.push_system_message(session.peer_id, ModMsg.MUTED_NOW,
					[ModerationService.format_duration(r["mute_sec"])])
		ModerationService.ACTION_PENDING_REVIEW:
			Net.push_system_message(session.peer_id, ModMsg.PENDING_REVIEW)


## Mensagem de bloqueio (e desconexão se a perda do personagem foi aprovada).
func _notify_block(session: PlayerSession, block: Dictionary, on_login: bool) -> void:
	if block["allowed"]:
		return
	match block["reason"]:
		ModerationService.REASON_MUTED:
			Net.push_system_message(session.peer_id, ModMsg.MUTED,
					[ModerationService.format_duration(block["seconds_left"])])
		ModerationService.REASON_PENDING:
			Net.push_system_message(session.peer_id, ModMsg.PENDING_REVIEW)
		ModerationService.REASON_LOST:
			Net.push_system_message(session.peer_id, ModMsg.CHARACTER_LOST)
			Net.log_line("moderation_character_lost_kick", {"peer": session.peer_id,
					"on_login": on_login})
			if world != null and world.is_inside_tree():
				world.get_tree().create_timer(LOST_KICK_DELAY_SEC).timeout.connect(
						_kick.bind(session.peer_id))


static func _kick(peer_id: int) -> void:
	var mp: MultiplayerAPI = Net.multiplayer
	if mp.multiplayer_peer != null and peer_id in mp.get_peers():
		mp.multiplayer_peer.disconnect_peer(peer_id)


func emote(session: PlayerSession, emote_id: StringName) -> void:
	var e: NetEntity = session.entity
	if emote_id == Net.EMOTE_SIT:
		if e.anim == NetEntity.ANIM_SIT:
			world.stand_up(session)
		else:
			world.sit_here(session)
	var peers: Array[int] = Net.get_instance_peer_ids(e.instance_id)
	Net.push_emote(peers, e.entity_id, emote_id)
	Net.log_line("emote", {"peer": session.peer_id, "emote": String(emote_id),
			"anim": String(e.anim), "recipients": peers.size()})


## "/dev learn_tree pindorama_bow_cerrado 5" -> NetProgress.debug_intent(peer, &"learn_tree", ["pindorama_bow_cerrado", 5]).
func _dev_command(session: PlayerSession, rest: String) -> void:
	var parts: PackedStringArray = rest.strip_edges().split(" ", false)
	if parts.is_empty():
		parts = PackedStringArray(["help"])
	var args: Array = []
	for i: int in range(1, mini(parts.size(), MAX_DEV_ARGS + 1)):
		var a: String = parts[i]
		args.append(a.to_int() if a.is_valid_int() else (a.to_float() if a.is_valid_float() else a))
	Net.log_line("dev_command", {"peer": session.peer_id, "cmd": parts[0], "args": str(args)})
	NetProgress.debug_intent.emit(session.peer_id, StringName(parts[0]), args)
