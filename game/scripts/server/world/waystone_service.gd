class_name WaystoneService
extends RefCounted
## Dona Ana (06/10/2026): a senhora que guarda os caminhos dos Viajantes, uma em cada cidade (como a Kafra).
##   - Falar com ela: a cidade dela fica conhecida (once_flags "waystone:<map_id>").
##   - "Salvar minha cidade": ponto salvo (once_flags "waystone_save:<map_id>", um só). Ele manda no
##     renascimento (MapTransfer.respawn_city_of) e no Pergaminho de Retorno (MapTransfer.return_city_of).
##     Sem ponto salvo (saves antigos), tudo segue como antes: last_city e o ponto seguro da zona.
##   - "Viajar": lista as outras cidades conhecidas; escolher leva para o lado da Dona Ana de lá
##     (marcador ARRIVAL_MARKER na raiz do mapa). Custo: Balance.cfg.waystone_teleport_stars (0 = grátis).
## Rede: toda zona CITY com uma NpcDef cujo diálogo é DIALOGUE_ID. O servidor valida tudo.
## Diálogo: as opções Salvar/Viajar estão no próprio DialogueDef (ações abaixo); o DialogueRunner delega
## a este serviço as ações que não conhece e chama extend_dialogue em cada nó mostrado.

const DIALOGUE_ID: StringName = &"dona_ana"
## Ações de diálogo (DialogueOption.action). waystone_go: action_args {"map_id": id}.
const ACTION_SAVE: StringName = &"waystone_save"
const ACTION_TRAVEL: StringName = &"waystone_travel"
const ACTION_GO: StringName = &"waystone_go"
const ACTIONS: Array[StringName] = [ACTION_SAVE, ACTION_TRAVEL, ACTION_GO]
const ARG_MAP_ID: StringName = &"map_id"
## Marcas em CharacterData.once_flags (formato do save inalterado).
const KNOWN_PREFIX: String = "waystone:"
const SAVE_PREFIX: String = "waystone_save:"
## Marker3D na raiz de cada cidade, ao lado da Dona Ana (chegada da viagem, do retorno e do renascimento).
const ARRIVAL_MARKER: StringName = &"WaystoneArrival"
## Nó gerado com a lista de destinos (não existe no DialogueDef).
const NODE_TRAVEL: StringName = &"_waystone_travel"
## Textos do diálogo (localization/content.csv).
const TEXT_TRAVEL: String = "DLG_DONA_ANA_TRAVEL"
const TEXT_TRAVEL_COST: String = "DLG_DONA_ANA_TRAVEL_COST"
const TEXT_TRAVEL_NONE: String = "DLG_DONA_ANA_TRAVEL_NONE"
const OPT_BACK: String = "DLG_DONA_ANA_OPT_BACK"
## Separador de argumentos do texto do diálogo (DialogueBox.resolve_text).
const TEXT_ARG_SEP: String = "|"
## Mensagens (localization/return.csv). SYS_ = recusa.
const MSG_LEARNED: String = "WAYSTONE_LEARNED"
const MSG_SAVED: String = "WAYSTONE_SAVED"
const MSG_TRAVELED: String = "WAYSTONE_TRAVELED"
const MSG_PAID: String = "WAYSTONE_PAID"
const MSG_UNKNOWN: String = "SYS_WAYSTONE_UNKNOWN"
const MSG_SAME: String = "SYS_WAYSTONE_SAME_CITY"
const MSG_COMBAT: String = "SYS_WAYSTONE_COMBAT"
const MSG_TRIAL: String = "SYS_WAYSTONE_TRIAL"
const MSG_DEAD: String = "SYS_WAYSTONE_DEAD"
const MSG_TRADE: String = "SYS_WAYSTONE_TRADE"
const MSG_NO_STARS: String = "SYS_WAYSTONE_NO_STARS"

var world: ServerWorld = null


func _init(p_world: ServerWorld) -> void:
	world = p_world


# ---------------------------------------------------------------- rede e marcas

static func is_waystone_npc(n: NpcDef) -> bool:
	return n != null and n.dialogue != null and n.dialogue.id == DIALOGUE_ID


## map_id -> NpcDef da Dona Ana de cada cidade (zona CITY com cena).
static func network() -> Dictionary[StringName, NpcDef]:
	var out: Dictionary[StringName, NpcDef] = {}
	for r: Resource in Content.all(&"npcs").values():
		var n: NpcDef = r as NpcDef
		if not is_waystone_npc(n):
			continue
		var z: ZoneDef = Content.zone(n.map_id)
		if z != null and z.kind == ZoneDef.Kind.CITY and MapTransfer.map_exists(n.map_id):
			out[n.map_id] = n
	return out


static func knows(c: CharacterData, map_id: StringName) -> bool:
	return c.once_flags.has(KNOWN_PREFIX + String(map_id))


## Marca a cidade como conhecida. true = era nova.
static func learn(c: CharacterData, map_id: StringName) -> bool:
	if map_id.is_empty() or knows(c, map_id):
		return false
	c.once_flags[KNOWN_PREFIX + String(map_id)] = true
	return true


## Cidade salva com a Dona Ana (&"" = nenhuma).
static func saved_city(c: CharacterData) -> StringName:
	if c == null:
		return &""
	for key: String in c.once_flags:
		if key.begins_with(SAVE_PREFIX):
			return StringName(key.substr(SAVE_PREFIX.length()))
	return &""


## Troca o ponto salvo (só um por personagem).
static func save_city(c: CharacterData, map_id: StringName) -> void:
	for key: String in c.once_flags.keys():
		if key.begins_with(SAVE_PREFIX):
			c.once_flags.erase(key)
	c.once_flags[SAVE_PREFIX + String(map_id)] = true


## Cidades conhecidas da rede, menos a atual, em ordem de map_id.
static func destinations(c: CharacterData, current_map: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for map_id: StringName in network():
		if map_id != current_map and knows(c, map_id):
			out.append(map_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


static func travel_cost() -> int:
	return maxi(0, Balance.cfg.waystone_teleport_stars)


static func zone_name(map_id: StringName) -> String:
	var z: ZoneDef = Content.zone(map_id)
	return z.name_key if z != null and not z.name_key.is_empty() else String(map_id)


# ---------------------------------------------------------------- ações (testáveis sem mundo)

## Conversou com a Dona Ana de map_id: a cidade fica conhecida.
func on_talk(session: PlayerSession, map_id: StringName) -> void:
	if not learn(session.character, map_id):
		return
	session.save_pending = true
	_tell(session, MSG_LEARNED, [zone_name(map_id)])
	Net.log_line("waystone_learned", {"peer": session.peer_id, "map": String(map_id)})


## "Salvar minha cidade" com a Dona Ana de map_id.
func save_here(session: PlayerSession, map_id: StringName) -> bool:
	if not network().has(map_id):
		Net.log_invalid(session.peer_id, "waystone_save_bad_city", {"map": String(map_id)})
		return false
	learn(session.character, map_id)
	save_city(session.character, map_id)
	session.save_pending = true
	_tell(session, MSG_SAVED, [zone_name(map_id)])
	Net.log_line("waystone_saved", {"peer": session.peer_id, "map": String(map_id)})
	return true


## Motivo da recusa (chave de mensagem) ou "" se pode viajar de current_map a dest pagando cost.
func check_travel(session: PlayerSession, current_map: StringName, dest: StringName, cost: int) -> String:
	var c: CharacterData = session.character
	var peer: int = session.peer_id
	if c.hp <= 0 or (world != null and world.combat != null and world.combat.is_dead(peer)):
		return MSG_DEAD
	if world != null:
		if world.combat != null and world.combat.is_in_combat(peer):
			return MSG_COMBAT
		if world.progression != null and world.progression.quests.has_trial(peer):
			return MSG_TRIAL
		if world.trade != null and world.trade.is_trading(peer):
			return MSG_TRADE
	if not network().has(dest) or not knows(c, dest):
		return MSG_UNKNOWN
	if dest == current_map:
		return MSG_SAME
	if cost > 0 and c.stars < cost:
		return MSG_NO_STARS
	return ""


## Viagem pedida à Dona Ana de current_map. Cobra, transfere (com mundo) e avisa. "" = foi; senão o motivo.
## cost < 0 = o custo do Balance.
func travel(session: PlayerSession, current_map: StringName, dest: StringName, cost: int = -1) -> String:
	if cost < 0:
		cost = travel_cost()
	var c: CharacterData = session.character
	var block: String = check_travel(session, current_map, dest, cost)
	if not block.is_empty():
		var args: Array = [cost, c.stars] if block == MSG_NO_STARS else [zone_name(dest)]
		_tell(session, block, args)
		Net.log_line("waystone_travel_refused", {"peer": session.peer_id, "from": String(current_map),
				"to": String(dest), "reason": block})
		return block
	if cost > 0:
		c.stars -= cost
		session.mark_dirty(PlayerSession.DIRTY_CURRENCY)
		session.save_pending = true
	if world != null and not world.map_transfer.transfer(session, dest, ARRIVAL_MARKER):
		if cost > 0:
			c.stars += cost
			session.mark_dirty(PlayerSession.DIRTY_CURRENCY)
		return MapTransfer.MSG_TRANSFER_FAILED
	if cost > 0:
		_tell(session, MSG_PAID, [cost])
	_tell(session, MSG_TRAVELED, [zone_name(dest)])
	Net.log_line("waystone_traveled", {"peer": session.peer_id, "from": String(current_map),
			"to": String(dest), "cost": cost, "stars": c.stars})
	return ""


func _tell(session: PlayerSession, key: String, args: Array = []) -> void:
	if Net.is_server and session.peer_id > 0:
		Net.push_system_message(session.peer_id, key, args)


# ---------------------------------------------------------------- diálogo

## Cidade da Dona Ana com quem o jogador fala (&"" = não é uma Dona Ana da rede).
func _npc_city(session: PlayerSession) -> StringName:
	var npc: NetEntity = world.get_entity(session.dialogue_npc_id)
	var def: NpcDef = Content.npc(npc.def_id) if npc != null else null
	if not is_waystone_npc(def) or not network().has(def.map_id):
		return &""
	return def.map_id


## Chamado pelo DialogueRunner em cada nó mostrado: no primeiro nó da Dona Ana, a cidade fica conhecida.
func extend_dialogue(session: PlayerSession, node: DialogueNode, _keys: Array[String]) -> void:
	if session.dialogue_def == null or session.dialogue_def.id != DIALOGUE_ID or node == null \
			or node.id != session.dialogue_def.start_node:
		return
	var map_id: StringName = _npc_city(session)
	if not map_id.is_empty():
		on_talk(session, map_id)


func handles_action(action: StringName) -> bool:
	return action in ACTIONS


## Executa a ação. Sempre tratada aqui (o DialogueRunner não segue para next_node).
func run_dialogue_action(session: PlayerSession, opt: DialogueOption) -> bool:
	var here: StringName = _npc_city(session)
	if here.is_empty():
		Net.log_invalid(session.peer_id, "waystone_action_without_dona_ana", {"action": String(opt.action)})
		world.dialogue.close(session, true)
		return true
	match opt.action:
		ACTION_SAVE:
			save_here(session, here)
			world.dialogue.close(session, true)
		ACTION_TRAVEL:
			_show_travel(session, here)
		ACTION_GO:
			var dest := StringName(str(opt.action_args.get(ARG_MAP_ID, "")))
			if not travel(session, here, dest).is_empty():
				world.dialogue.close(session, true)
	return true


func _show_travel(session: PlayerSession, here: StringName) -> void:
	var dests: Array[StringName] = destinations(session.character, here)
	var cost: int = travel_cost()
	var options: Array[DialogueOption] = []
	for map_id: StringName in dests:
		var o := DialogueOption.new()
		o.text_key = zone_name(map_id)
		o.action = ACTION_GO
		o.action_args = {ARG_MAP_ID: map_id}
		options.append(o)
	var back := DialogueOption.new()
	back.text_key = OPT_BACK
	back.action = DialogueRunner.ACTION_CLOSE
	options.append(back)
	var n := DialogueNode.new()
	n.id = NODE_TRAVEL
	if dests.is_empty():
		n.text_key = TEXT_TRAVEL_NONE
	elif cost > 0:
		n.text_key = TEXT_TRAVEL_COST + TEXT_ARG_SEP + str(cost)
	else:
		n.text_key = TEXT_TRAVEL
	n.options = options
	world.dialogue.show_node(session, n)
