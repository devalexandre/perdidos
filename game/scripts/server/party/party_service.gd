class_name PartyService
extends RefCounted
## Grupo no servidor (GDD §5.2–5.4 e §6.3 "XP dividida no grupo"; decisão do dono em 30/09/2026). world.party.
##
## - Mapas são compartilhados (instance_id = map_id): o grupo NÃO cria instância. Ele serve para dividir XP,
##   crédito de abate e posse de drop, para as skills de suporte (aliados) e para o chat /g.
## - Até Balance.cfg.party_max_size membros. Só o líder convida, expulsa e passa a liderança (quem está sem
##   grupo convida e vira líder quando o convidado aceita).
## - O líder que desconecta tem Balance.cfg.leader_reconnect_grace_sec de tolerância; depois (ou se sair do
##   grupo) a liderança passa ao membro mais antigo que estiver online. O grupo some quando sobra 1.
## - Membros são guardados pelo nome do personagem (minúsculo): quem cai e volta continua no grupo enquanto o
##   servidor não reiniciar (o grupo não é salvo em disco).
## - Tudo validado aqui; cada recusa vai para o log (Net.log_invalid) e volta ao jogador como mensagem de
##   sistema (localization/party.csv).
## Comandos chegam pelo NetParty (botões da interface) ou pelo chat (ChatService: "/grupo", "/g", "/online").

# Mensagens (localization/party.csv). Argumentos em ordem para tr(key) % args.
const MSG_HELP: String = "PARTY_HELP"
const MSG_INVITE_SENT: String = "PARTY_INVITE_SENT" # [nome]
const MSG_INVITED: String = "PARTY_INVITED" # [quem convidou]
const MSG_ERR_NOT_FOUND: String = "PARTY_ERR_NOT_FOUND" # [nome]
const MSG_ERR_SELF: String = "PARTY_ERR_SELF"
const MSG_ERR_TARGET_IN_PARTY: String = "PARTY_ERR_TARGET_IN_PARTY" # [nome]
const MSG_ERR_ALREADY: String = "PARTY_ERR_ALREADY_IN_PARTY"
const MSG_ERR_FULL: String = "PARTY_ERR_FULL" # [máximo]
const MSG_ERR_NOT_LEADER: String = "PARTY_ERR_NOT_LEADER"
const MSG_ERR_NO_PARTY: String = "PARTY_ERR_NO_PARTY"
const MSG_ERR_NO_INVITE: String = "PARTY_ERR_NO_INVITE"
const MSG_ERR_PENDING: String = "PARTY_ERR_PENDING" # [nome]
const MSG_ERR_TOO_FAST: String = "PARTY_ERR_TOO_FAST"
const MSG_ERR_NOT_MEMBER: String = "PARTY_ERR_NOT_MEMBER" # [nome]
const MSG_ERR_ONLINE_OFF: String = "PARTY_ERR_ONLINE_DISABLED"
const MSG_JOINED: String = "PARTY_JOINED" # [nome]
const MSG_LEFT: String = "PARTY_LEFT" # [nome]
const MSG_YOU_LEFT: String = "PARTY_YOU_LEFT"
const MSG_KICKED: String = "PARTY_KICKED" # [nome]
const MSG_YOU_KICKED: String = "PARTY_YOU_WERE_KICKED" # [líder]
const MSG_NEW_LEADER: String = "PARTY_NEW_LEADER" # [nome]
const MSG_DISBANDED: String = "PARTY_DISBANDED"
const MSG_DECLINED: String = "PARTY_DECLINED" # [nome]
const MSG_YOU_DECLINED: String = "PARTY_YOU_DECLINED" # [nome]
const MSG_INVITE_EXPIRED: String = "PARTY_INVITE_EXPIRED" # [nome]
const MSG_LEADER_OFFLINE: String = "PARTY_LEADER_OFFLINE" # [nome, minutos]
const MSG_MEMBER_OFFLINE: String = "PARTY_MEMBER_OFFLINE" # [nome]
const MSG_MEMBER_ONLINE: String = "PARTY_MEMBER_ONLINE" # [nome]
const MSG_ERR_XP_MODE: String = "PARTY_ERR_XP_MODE"
## Missão de título em andamento é feita sozinho (QuestService.active_solo_quest).
const MSG_ERR_SOLO_QUEST: String = "PARTY_ERR_SOLO_QUEST" # [missão]
const MSG_ERR_TARGET_SOLO_QUEST: String = "PARTY_ERR_TARGET_SOLO_QUEST" # [nome]
const XP_MODE_SPLIT: StringName = &"split"
const XP_MODE_INDIVIDUAL: StringName = &"individual"
## Palavras do chat ("/grupo <palavra> [nome]"), sem diferenciar maiúsculas. Sem palavra conhecida = convite.
const WORDS: Dictionary[String, StringName] = {
	"aceitar": NetParty.CMD_ACCEPT, "accept": NetParty.CMD_ACCEPT,
	"recusar": NetParty.CMD_DECLINE, "decline": NetParty.CMD_DECLINE,
	"sair": NetParty.CMD_LEAVE, "leave": NetParty.CMD_LEAVE,
	"expulsar": NetParty.CMD_KICK, "kick": NetParty.CMD_KICK,
	"líder": NetParty.CMD_LEADER, "lider": NetParty.CMD_LEADER, "leader": NetParty.CMD_LEADER,
	"xp": NetParty.CMD_XP_MODE,
	"convidar": NetParty.CMD_INVITE, "invite": NetParty.CMD_INVITE,
	"lista": NetParty.CMD_LIST, "list": NetParty.CMD_LIST,
	"ajuda": &"help", "help": &"help", "?": &"help",
}
const CMD_HELP: StringName = &"help"
const MSEC_PER_SEC: float = 1000.0


class Party:
	var id: int = 0
	## Chaves (nome em minúsculas) na ordem de entrada: o primeiro é o mais antigo.
	var members: Array[String] = []
	## chave -> nome como o jogador escreveu.
	var names: Dictionary[String, String] = {}
	var leader: String = ""
	var xp_mode: StringName = &"split"
	## Quando o líder caiu (msec; -1 = online).
	var leader_offline_msec: int = -1


var world: ServerWorld = null
var _parties: Dictionary[int, Party] = {}
## chave do personagem -> id do grupo.
var _party_of: Dictionary[String, int] = {}
## chave do convidado -> {"from": chave, "from_name": String, "expires": msec}
var _invites: Dictionary[String, Dictionary] = {}
## chave de quem convidou -> msec do último convite (anti-spam).
var _last_invite_msec: Dictionary[String, int] = {}
## peer -> último estado mandado (só manda de novo se mudou).
var _sent: Dictionary[int, Dictionary] = {}
var _next_id: int = 0
var _next_tick_msec: int = 0


func _init(p_world: ServerWorld) -> void:
	world = p_world
	NetParty.command_intent.connect(_on_command_intent)
	Net.log_line("party_ready", {"max": Balance.cfg.party_max_size,
			"grace_sec": Balance.cfg.leader_reconnect_grace_sec, "drop_owner_sec": Balance.cfg.drop_owner_sec})


# ================================================================ consultas (combate, progressão, chat)

static func key_of(char_name: String) -> String:
	return char_name.strip_edges().to_lower()


func party_of_peer(peer_id: int) -> Party:
	var s: PlayerSession = world.get_session(peer_id)
	return party_of_name(s.character.char_name) if s != null else null


func party_of_name(char_name: String) -> Party:
	return _parties.get(_party_of.get(key_of(char_name), 0))


func party_id_of_peer(peer_id: int) -> int:
	var p: Party = party_of_peer(peer_id)
	return p.id if p != null else 0


## Mesmo jogador ou mesmo grupo.
func same_party(peer_a: int, peer_b: int) -> bool:
	if peer_a == 0 or peer_b == 0:
		return false
	if peer_a == peer_b:
		return true
	var pa: int = party_id_of_peer(peer_a)
	return pa != 0 and pa == party_id_of_peer(peer_b)


## Aliado para skills de suporte (cura, escudo, reforço): ele mesmo ou um membro do grupo.
func is_ally(a: NetEntity, b: NetEntity) -> bool:
	return a != null and b != null and a.is_player() and b.is_player() \
			and same_party(a.get_peer_id(), b.get_peer_id())


## Peers online do grupo do peer (ele incluso). Sem grupo = só ele.
func member_peers(peer_id: int) -> Array[int]:
	var out: Array[int] = []
	var p: Party = party_of_peer(peer_id)
	if p == null:
		if world.get_session(peer_id) != null:
			out.append(peer_id)
		return out
	for k: String in p.members:
		var s: PlayerSession = _session_by_key(k)
		if s != null:
			out.append(s.peer_id)
	return out


## Quem recebe a XP e o crédito de abate de um monstro cujo dono é owner_peer (GDD §6.3): o dono e os membros
## do grupo dele vivos no mesmo mapa a até Balance.cfg.party_share_range_cells do monstro. O dono sempre conta.
func credit_peers(owner_peer: int, instance_id: StringName, pos: Vector3) -> Array[int]:
	var out: Array[int] = []
	if world.get_session(owner_peer) == null:
		return out
	out.append(owner_peer)
	var range_m: float = Balance.cfg.party_share_range_cells * Balance.cfg.cell_size
	for peer: int in member_peers(owner_peer):
		if peer == owner_peer:
			continue
		var s: PlayerSession = world.get_session(peer)
		if s == null or s.entity == null or s.entity.instance_id != instance_id or s.character.hp <= 0:
			continue
		if pos != Vector3.INF and s.entity.flat_distance_to(pos) > range_m:
			continue
		out.append(peer)
	return out


func xp_mode_for(peer_id: int) -> StringName:
	var p: Party = party_of_peer(peer_id)
	return p.xp_mode if p != null else XP_MODE_INDIVIDUAL


## XP de cada um quando n jogadores dividem xp_total: XP_total × (1 + bônus × (n − 1)) / n (mínimo 1).
static func share_xp(xp_total: int, n: int) -> int:
	if xp_total <= 0:
		return 0
	if n <= 1:
		return xp_total
	return maxi(1, floori(float(xp_total) * (1.0 + Balance.cfg.party_xp_bonus_per_member * float(n - 1)) / float(n)))


static func xp_for_recipient(xp_total: int, n: int, mode: StringName, index: int) -> int:
	if mode == XP_MODE_INDIVIDUAL:
		return xp_total if index == 0 else 0
	return share_xp(xp_total, n)


# ================================================================ comandos

func _on_command_intent(peer_id: int, cmd: StringName, arg: String) -> void:
	var s: PlayerSession = world.get_session(peer_id)
	if s == null:
		Net.log_invalid(peer_id, "intent_without_session", {"intent": "party"})
		return
	command(s, cmd, arg)


## "/grupo [palavra] [nome]" do chat (rest = o que vem depois de "/grupo").
func chat_command(s: PlayerSession, rest: String) -> void:
	var text: String = rest.strip_edges()
	if text.is_empty():
		command(s, NetParty.CMD_LIST, "")
		return
	var first: String = text.get_slice(" ", 0)
	var word: StringName = WORDS.get(first.to_lower(), &"")
	if word.is_empty():
		command(s, NetParty.CMD_INVITE, text)
		return
	command(s, word, text.substr(first.length()).strip_edges())


func command(s: PlayerSession, cmd: StringName, arg: String) -> void:
	Net.log_line("party_command", {"peer": s.peer_id, "cmd": String(cmd), "arg": arg})
	match cmd:
		NetParty.CMD_INVITE:
			invite(s, arg)
		NetParty.CMD_ACCEPT:
			accept(s)
		NetParty.CMD_DECLINE:
			decline(s)
		NetParty.CMD_LEAVE:
			leave(s)
		NetParty.CMD_KICK:
			kick(s, arg)
		NetParty.CMD_LEADER:
			make_leader(s, arg)
		NetParty.CMD_XP_MODE:
			set_xp_mode(s, arg)
		NetParty.CMD_LIST:
			send_list(s)
		NetParty.CMD_ONLINE:
			send_online(s)
		CMD_HELP:
			Net.push_system_message(s.peer_id, MSG_HELP, [Balance.cfg.party_max_size])
		_:
			Net.log_invalid(s.peer_id, "party_unknown_command", {"cmd": String(cmd)})


func _fail(s: PlayerSession, reason: String, key: String, args: Array = [], data: Dictionary = {}) -> void:
	Net.log_invalid(s.peer_id, reason, data)
	Net.push_system_message(s.peer_id, key, args)


## Missão de título em andamento (chave do nome) ou "".
func _solo_quest(s: PlayerSession) -> String:
	if world.progression == null:
		return ""
	return world.progression.quests.active_solo_quest(s)


func invite(s: PlayerSession, raw_name: String) -> void:
	var me: String = key_of(s.character.char_name)
	var name: String = raw_name.strip_edges()
	if name.is_empty():
		Net.push_system_message(s.peer_id, MSG_HELP, [Balance.cfg.party_max_size])
		return
	var target: PlayerSession = _session_by_key(key_of(name)) if name.length() <= Net.MAX_NAME_LENGTH else null
	if target == null:
		_fail(s, "party_invite_not_found", MSG_ERR_NOT_FOUND, [name.left(Net.MAX_NAME_LENGTH)])
		return
	var them: String = key_of(target.character.char_name)
	if them == me:
		_fail(s, "party_invite_self", MSG_ERR_SELF)
		return
	var p: Party = party_of_name(s.character.char_name)
	if p != null and p.leader != me:
		_fail(s, "party_invite_not_leader", MSG_ERR_NOT_LEADER)
		return
	if p != null and p.members.size() >= Balance.cfg.party_max_size:
		_fail(s, "party_invite_full", MSG_ERR_FULL, [Balance.cfg.party_max_size])
		return
	if _party_of.has(them):
		_fail(s, "party_invite_target_in_party", MSG_ERR_TARGET_IN_PARTY, [target.character.char_name])
		return
	var my_solo: String = _solo_quest(s)
	if not my_solo.is_empty():
		_fail(s, "party_invite_solo_quest", MSG_ERR_SOLO_QUEST, [my_solo])
		return
	if not _solo_quest(target).is_empty():
		_fail(s, "party_invite_target_solo_quest", MSG_ERR_TARGET_SOLO_QUEST, [target.character.char_name])
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_invite_msec.get(me, -1000000)) < int(Balance.cfg.party_invite_cooldown_sec * MSEC_PER_SEC):
		_fail(s, "party_invite_too_fast", MSG_ERR_TOO_FAST)
		return
	var pending: Dictionary = _invites.get(them, {})
	if not pending.is_empty() and int(pending["expires"]) > now and pending["from"] != me:
		_fail(s, "party_invite_pending", MSG_ERR_PENDING, [target.character.char_name])
		return
	_last_invite_msec[me] = now
	_invites[them] = {"from": me, "from_name": s.character.char_name,
			"expires": now + int(Balance.cfg.party_invite_timeout_sec * MSEC_PER_SEC)}
	NetParty.push_invite(target.peer_id, s.character.char_name, Balance.cfg.party_invite_timeout_sec)
	Net.push_system_message(target.peer_id, MSG_INVITED, [s.character.char_name])
	Net.push_system_message(s.peer_id, MSG_INVITE_SENT, [target.character.char_name])
	Net.log_line("party_invite", {"from": s.peer_id, "to": target.peer_id, "party": p.id if p != null else 0})


func accept(s: PlayerSession) -> void:
	var me: String = key_of(s.character.char_name)
	var inv: Dictionary = _take_invite(me)
	if inv.is_empty():
		_fail(s, "party_accept_without_invite", MSG_ERR_NO_INVITE)
		return
	NetParty.push_invite_closed(s.peer_id)
	if _party_of.has(me):
		_fail(s, "party_accept_already_in_party", MSG_ERR_ALREADY)
		return
	var my_solo: String = _solo_quest(s)
	if not my_solo.is_empty():
		_fail(s, "party_accept_solo_quest", MSG_ERR_SOLO_QUEST, [my_solo])
		return
	var inviter: String = inv["from"]
	var p: Party = _parties.get(_party_of.get(inviter, 0))
	if p == null:
		var inviter_session: PlayerSession = _session_by_key(inviter)
		if inviter_session == null:
			_fail(s, "party_accept_inviter_gone", MSG_ERR_NOT_FOUND, [inv["from_name"]])
			return
		p = _create_party(inviter_session)
	if p.members.size() >= Balance.cfg.party_max_size:
		_fail(s, "party_accept_full", MSG_ERR_FULL, [Balance.cfg.party_max_size])
		return
	_add_member(p, s)
	_broadcast(p, MSG_JOINED, [s.character.char_name])
	Net.log_line("party_joined", {"peer": s.peer_id, "party": p.id, "members": p.members})
	push_states(p)


func decline(s: PlayerSession) -> void:
	var inv: Dictionary = _take_invite(key_of(s.character.char_name))
	if inv.is_empty():
		_fail(s, "party_decline_without_invite", MSG_ERR_NO_INVITE)
		return
	NetParty.push_invite_closed(s.peer_id)
	Net.push_system_message(s.peer_id, MSG_YOU_DECLINED, [inv["from_name"]])
	var inviter: PlayerSession = _session_by_key(inv["from"])
	if inviter != null:
		Net.push_system_message(inviter.peer_id, MSG_DECLINED, [s.character.char_name])
	Net.log_line("party_declined", {"peer": s.peer_id, "from": inv["from"]})


func leave(s: PlayerSession) -> void:
	var p: Party = party_of_name(s.character.char_name)
	if p == null:
		_fail(s, "party_leave_without_party", MSG_ERR_NO_PARTY)
		return
	_remove_member(p, key_of(s.character.char_name), false)


func kick(s: PlayerSession, raw_name: String) -> void:
	var p: Party = _leader_party(s, "kick")
	if p == null:
		return
	var them: String = key_of(raw_name)
	if them == key_of(s.character.char_name):
		_fail(s, "party_kick_self", MSG_ERR_SELF)
		return
	if them.is_empty() or them not in p.members:
		_fail(s, "party_kick_not_member", MSG_ERR_NOT_MEMBER, [raw_name.left(Net.MAX_NAME_LENGTH)])
		return
	_remove_member(p, them, true)


func make_leader(s: PlayerSession, raw_name: String) -> void:
	var p: Party = _leader_party(s, "leader")
	if p == null:
		return
	var them: String = key_of(raw_name)
	if them == key_of(s.character.char_name):
		_fail(s, "party_leader_self", MSG_ERR_SELF)
		return
	if them.is_empty() or them not in p.members:
		_fail(s, "party_leader_not_member", MSG_ERR_NOT_MEMBER, [raw_name.left(Net.MAX_NAME_LENGTH)])
		return
	_set_leader(p, them)


func set_xp_mode(s: PlayerSession, raw_mode: String) -> void:
	var p: Party = _leader_party(s, "xp_mode")
	if p == null:
		return
	var mode := StringName(raw_mode.strip_edges().to_lower())
	if mode not in [XP_MODE_SPLIT, XP_MODE_INDIVIDUAL]:
		_fail(s, "party_xp_mode_invalid", MSG_ERR_XP_MODE)
		return
	if p.xp_mode == mode:
		return
	p.xp_mode = mode
	push_states(p)
	Net.log_line("party_xp_mode_changed", {"party": p.id, "leader": s.peer_id, "mode": String(mode)})


## Lista dos membros (/grupo sem argumento).
func send_list(s: PlayerSession) -> void:
	var p: Party = party_of_name(s.character.char_name)
	if p == null:
		Net.push_system_message(s.peer_id, MSG_ERR_NO_PARTY)
		Net.push_system_message(s.peer_id, MSG_HELP, [Balance.cfg.party_max_size])
		return
	var entries: Array = []
	for m: Dictionary in state_for(p)[NetParty.K_MEMBERS]:
		entries.append({NetParty.K_NAME: m[NetParty.K_NAME], NetParty.K_LEVEL: m[NetParty.K_LEVEL],
				NetParty.K_MAP: m[NetParty.K_MAP], NetParty.K_IS_LEADER: m[NetParty.K_IS_LEADER],
				NetParty.K_ONLINE: m[NetParty.K_ONLINE]})
	NetParty.push_player_list(s.peer_id, NetParty.LIST_PARTY, entries)


## /online: quem está conectado, em que mapa e o nível. Balance.cfg.online_list_public = false restringe a
## servidores com --dev-commands.
func send_online(s: PlayerSession) -> void:
	if not Balance.cfg.online_list_public and not NetProgress.dev_commands:
		_fail(s, "online_list_disabled", MSG_ERR_ONLINE_OFF)
		return
	var entries: Array = []
	for o: PlayerSession in world.get_sessions():
		if o.entity == null:
			continue
		entries.append({NetParty.K_NAME: o.character.char_name, NetParty.K_LEVEL: o.character.level,
				NetParty.K_MAP: String(world.get_instance_map_id(o.entity.instance_id)),
				NetParty.K_IS_LEADER: false, NetParty.K_ONLINE: true})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a[NetParty.K_NAME]).to_lower() < str(b[NetParty.K_NAME]).to_lower())
	NetParty.push_player_list(s.peer_id, NetParty.LIST_ONLINE, entries)
	Net.log_line("online_list", {"peer": s.peer_id, "count": entries.size()})


func _leader_party(s: PlayerSession, what: String) -> Party:
	var p: Party = party_of_name(s.character.char_name)
	if p == null:
		_fail(s, "party_%s_without_party" % what, MSG_ERR_NO_PARTY)
		return null
	if p.leader != key_of(s.character.char_name):
		_fail(s, "party_%s_not_leader" % what, MSG_ERR_NOT_LEADER)
		return null
	return p


# ================================================================ ciclo de vida (ServerWorld)

## O jogador entrou no mundo ou trocou de mapa: volta a valer como online, o painel de todos se atualiza.
func on_player_ready(s: PlayerSession) -> void:
	var p: Party = party_of_name(s.character.char_name)
	_sent.erase(s.peer_id)
	if p == null:
		NetParty.push_state(s.peer_id, {})
		return
	var me: String = key_of(s.character.char_name)
	if p.leader == me and p.leader_offline_msec >= 0:
		p.leader_offline_msec = -1
		_broadcast(p, MSG_MEMBER_ONLINE, [s.character.char_name], me)
	push_states(p)


## O peer saiu do servidor: convites dele somem; no grupo fica como offline (o líder ganha a tolerância).
func on_peer_left(peer_id: int, char_name: String) -> void:
	_sent.erase(peer_id)
	var me: String = key_of(char_name)
	_invites.erase(me)
	for k: String in _invites.keys():
		if _invites[k]["from"] == me:
			_invites.erase(k)
			var t: PlayerSession = _session_by_key(k)
			if t != null:
				NetParty.push_invite_closed(t.peer_id)
	var p: Party = party_of_name(char_name)
	if p == null:
		return
	if p.leader == me:
		p.leader_offline_msec = Time.get_ticks_msec()
		_broadcast(p, MSG_LEADER_OFFLINE, [char_name, roundi(Balance.cfg.leader_reconnect_grace_sec / 60.0)], me)
	else:
		_broadcast(p, MSG_MEMBER_OFFLINE, [char_name], me)
	Net.log_line("party_member_offline", {"name": char_name, "party": p.id, "leader": p.leader == me})
	push_states(p, peer_id)


func tick() -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_tick_msec:
		return
	_next_tick_msec = now + int(Balance.cfg.party_state_interval_sec * MSEC_PER_SEC)
	for k: String in _invites.keys():
		var inv: Dictionary = _invites[k]
		if int(inv["expires"]) > now:
			continue
		_invites.erase(k)
		var t: PlayerSession = _session_by_key(k)
		if t != null:
			NetParty.push_invite_closed(t.peer_id)
		var from: PlayerSession = _session_by_key(inv["from"])
		if from != null:
			Net.push_system_message(from.peer_id, MSG_INVITE_EXPIRED, [t.character.char_name if t != null else k])
		Net.log_line("party_invite_expired", {"to": k, "from": inv["from"]})
	for p: Party in _parties.values():
		if p.leader_offline_msec >= 0 and now - p.leader_offline_msec \
				>= int(Balance.cfg.leader_reconnect_grace_sec * MSEC_PER_SEC):
			var heir: String = _oldest_online(p, p.leader)
			if not heir.is_empty():
				Net.log_line("party_leader_grace_over", {"party": p.id, "old": p.leader, "new": heir})
				_set_leader(p, heir)
		push_states(p)


# ================================================================ estado para o painel

## {"leader": nome, "max": 5, "members": [{name, level, hp, max_hp, mp, max_mp, map, online, is_leader,
## entity_id}]} na ordem de entrada (o mais antigo primeiro).
func state_for(p: Party) -> Dictionary:
	var members: Array = []
	for k: String in p.members:
		var s: PlayerSession = _session_by_key(k)
		var m: Dictionary = {NetParty.K_NAME: p.names.get(k, k), NetParty.K_LEVEL: 0, NetParty.K_HP: 0,
				NetParty.K_MAX_HP: 1, NetParty.K_MP: 0, NetParty.K_MAX_MP: 1, NetParty.K_MAP: "",
				NetParty.K_ONLINE: false, NetParty.K_IS_LEADER: k == p.leader, NetParty.K_ENTITY: 0}
		if s != null and s.entity != null:
			var st: Dictionary = s.character.compute_stats()
			m[NetParty.K_LEVEL] = s.character.level
			m[NetParty.K_HP] = s.character.hp
			m[NetParty.K_MAX_HP] = int(st[CharacterStats.K_MAX_HP])
			m[NetParty.K_MP] = s.character.mp
			m[NetParty.K_MAX_MP] = int(st[CharacterStats.K_MAX_MP])
			m[NetParty.K_MAP] = String(world.get_instance_map_id(s.entity.instance_id))
			m[NetParty.K_ONLINE] = true
			m[NetParty.K_ENTITY] = s.entity.entity_id
		members.append(m)
	return {NetParty.K_LEADER: p.names.get(p.leader, p.leader), NetParty.K_MAX: Balance.cfg.party_max_size,
			NetParty.K_MEMBERS: members, NetParty.K_XP_MODE: String(p.xp_mode)}


## Manda o estado aos membros online (só se mudou para cada um). skip_peer = quem acabou de sair.
func push_states(p: Party, skip_peer: int = 0) -> void:
	var st: Dictionary = state_for(p)
	for k: String in p.members:
		var s: PlayerSession = _session_by_key(k)
		if s == null or s.peer_id == skip_peer:
			continue
		if _sent.get(s.peer_id, {}) == st:
			continue
		_sent[s.peer_id] = st
		NetParty.push_state(s.peer_id, st)


# ================================================================ internos

func _session_by_key(k: String) -> PlayerSession:
	if k.is_empty():
		return null
	for s: PlayerSession in world.get_sessions():
		if key_of(s.character.char_name) == k:
			return s
	return null


func _take_invite(k: String) -> Dictionary:
	var inv: Dictionary = _invites.get(k, {})
	_invites.erase(k)
	if inv.is_empty() or int(inv["expires"]) <= Time.get_ticks_msec():
		return {}
	return inv


func _create_party(leader: PlayerSession) -> Party:
	_next_id += 1
	var p := Party.new()
	p.id = _next_id
	_parties[p.id] = p
	_add_member(p, leader)
	p.leader = key_of(leader.character.char_name)
	Net.log_line("party_created", {"party": p.id, "leader": leader.character.char_name})
	return p


func _add_member(p: Party, s: PlayerSession) -> void:
	var k: String = key_of(s.character.char_name)
	if k in p.members:
		return
	p.members.append(k)
	p.names[k] = s.character.char_name
	_party_of[k] = p.id
	# Convite pendente para quem acabou de entrar não vale mais.
	_invites.erase(k)


func _remove_member(p: Party, k: String, kicked: bool) -> void:
	var name: String = p.names.get(k, k)
	var leader_name: String = p.names.get(p.leader, p.leader)
	p.members.erase(k)
	p.names.erase(k)
	_party_of.erase(k)
	var gone: PlayerSession = _session_by_key(k)
	if gone != null:
		_sent.erase(gone.peer_id)
		NetParty.push_state(gone.peer_id, {})
		if kicked:
			Net.push_system_message(gone.peer_id, MSG_YOU_KICKED, [leader_name])
		else:
			Net.push_system_message(gone.peer_id, MSG_YOU_LEFT)
	Net.log_line("party_left", {"name": name, "party": p.id, "kicked": kicked, "left": p.members})
	if p.members.size() <= 1:
		_disband(p)
		return
	_broadcast(p, MSG_KICKED if kicked else MSG_LEFT, [name])
	if p.leader == k:
		var heir: String = _oldest_online(p, "")
		_set_leader(p, heir if not heir.is_empty() else p.members[0])
	push_states(p)


func _disband(p: Party) -> void:
	for k: String in p.members:
		_party_of.erase(k)
		var s: PlayerSession = _session_by_key(k)
		if s != null:
			_sent.erase(s.peer_id)
			NetParty.push_state(s.peer_id, {})
			Net.push_system_message(s.peer_id, MSG_DISBANDED)
	_parties.erase(p.id)
	Net.log_line("party_disbanded", {"party": p.id})


func _set_leader(p: Party, k: String) -> void:
	p.leader = k
	p.leader_offline_msec = -1 if _session_by_key(k) != null else Time.get_ticks_msec()
	_broadcast(p, MSG_NEW_LEADER, [p.names.get(k, k)])
	Net.log_line("party_leader", {"party": p.id, "leader": k})
	push_states(p)


## Membro mais antigo online (fora `except`). "" = ninguém.
func _oldest_online(p: Party, except: String) -> String:
	for k: String in p.members:
		if k != except and _session_by_key(k) != null:
			return k
	return ""


func _broadcast(p: Party, key: String, args: Array, except: String = "") -> void:
	for k: String in p.members:
		if k == except:
			continue
		var s: PlayerSession = _session_by_key(k)
		if s != null:
			Net.push_system_message(s.peer_id, key, args)
