extends Node
## Autoload "NetCombat": canal de RPCs do combate (contrato arrival, dono K). Mesmo caminho
## (/root/NetCombat) no servidor e no cliente. Validação de formato e limite de taxa via Net;
## as regras de jogo ficam no CombatService (servidor).
##
## Intenções (cliente -> servidor):
##   send_attack(entity_id)   clicar num monstro: anda até o alcance e ataca em ciclo (GDD §10.1)
##   send_stop_attack()       para de atacar (o movimento no chão também para)
##   send_pickup(entity_id)   pegar item do chão (anda até Balance.cfg.pickup_range)
##   route_interact(target_id) clique numa coisa clicável: monstro -> ataque, item -> pegar, outro
##                            jogador -> NetParty.player_menu_requested (menu do grupo), o resto ->
##                            Net.send_interact (ligado ao ClientView pelo main.gd)
## Eventos (servidor -> cliente), como sinais no cliente:
##   hit(source_id, target_id, amount, crit, damage_type, target_hp_ratio)  (todos da instância;
##       amount = MISS_AMOUNT (-1) = errou)
##   entity_died(entity_id)                                                  (todos da instância)
##   attack_target_changed(entity_id)   alvo do ataque do jogador local (0 = nenhum; só o dono)
##   healed(source_id, target_id, amount)                                  (todos da instância)

# ---------------------------------------------------------------- sinais do servidor
signal attack_intent(peer_id: int, entity_id: int)
signal stop_attack_intent(peer_id: int)
signal pickup_intent(peer_id: int, entity_id: int)

# ---------------------------------------------------------------- sinais do cliente
signal hit(source_id: int, target_id: int, amount: int, crit: bool, damage_type: int,
		target_hp_ratio: float)
signal entity_died(entity_id: int)
signal attack_target_changed(entity_id: int)
## Cura aplicada (skills de Q, CombatService.heal). source_id = quem curou (0 = sem fonte). Todos da
## instância (contrato: docs/contracts-city-walk.md, ADENDO 4).
signal healed(source_id: int, target_id: int, amount: int)

const SERVER_PEER_ID: int = 1
## Agente R (GDD §10.2): hit com amount = MISS_AMOUNT = golpe errado (o cliente mostra "Errou").
const MISS_AMOUNT: int = -1
const TARGET_ENTITY_PREFIX: String = "e:"
const ARG_COMBAT_FIXTURES: String = "combat-fixtures"
const ARG_COMBAT_AUTOTEST: String = "combat-autotest"
const FIXTURES_SCRIPT: String = "res://tests/combat/fixtures/combat_fixtures.gd"
const AUTOTEST_SCRIPT: String = "res://tests/combat/combat_autotest.gd"
const FX_SCRIPT: String = "res://scripts/client/combat/combat_fx.gd"
const INSTANCES_PATH: NodePath = ^"/root/Main/World/Instances"
const ENTITIES_NODE: String = "Entities"

## Cliente: alvo atual do ataque do jogador local (0 = nenhum).
var client_attack_target: int = 0
var _fx: Node = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if ("--" + ARG_COMBAT_FIXTURES) in args and ResourceLoader.exists(FIXTURES_SCRIPT):
		(load(FIXTURES_SCRIPT) as Script).call("install_content")
	Net.local_player_spawned.connect(_on_local_player_spawned)
	if ("--" + ARG_COMBAT_AUTOTEST) in args and not ("--server" in args) \
			and ResourceLoader.exists(AUTOTEST_SCRIPT):
		var t: Node = (load(AUTOTEST_SCRIPT) as Script).new()
		t.name = "CombatAutotest"
		add_child(t)


static func has_arg(arg: String) -> bool:
	return ("--" + arg) in OS.get_cmdline_user_args()


# ================================================================ servidor

@rpc("any_peer", "call_remote", "reliable")
func req_attack(entity_id: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not Net._accept_world_intent(peer_id, "attack"):
		return
	if typeof(entity_id) != TYPE_INT:
		Net.log_invalid(peer_id, "attack_bad_args")
		return
	attack_intent.emit(peer_id, int(entity_id))


@rpc("any_peer", "call_remote", "reliable")
func req_stop_attack() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not Net._accept_world_intent(peer_id, "stop_attack"):
		return
	stop_attack_intent.emit(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func req_pickup(entity_id: Variant) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not Net._accept_world_intent(peer_id, "pickup"):
		return
	if typeof(entity_id) != TYPE_INT:
		Net.log_invalid(peer_id, "pickup_bad_args")
		return
	pickup_intent.emit(peer_id, int(entity_id))


func push_hit(peer_ids: Array[int], source_id: int, target_id: int, amount: int, crit: bool,
		damage_type: int, target_hp_ratio: float) -> void:
	for p: int in peer_ids:
		_cli_hit.rpc_id(p, source_id, target_id, amount, crit, damage_type, target_hp_ratio)


func push_death(peer_ids: Array[int], entity_id: int) -> void:
	for p: int in peer_ids:
		_cli_death.rpc_id(p, entity_id)


func push_healed(peer_ids: Array[int], source_id: int, target_id: int, amount: int) -> void:
	for p: int in peer_ids:
		_cli_healed.rpc_id(p, source_id, target_id, amount)


func push_attack_target(peer_id: int, entity_id: int) -> void:
	_cli_attack_target.rpc_id(peer_id, entity_id)


# ================================================================ cliente

func _is_client_connected() -> bool:
	return not Net.is_server and multiplayer.multiplayer_peer != null \
			and multiplayer.multiplayer_peer.get_connection_status() \
			== MultiplayerPeer.CONNECTION_CONNECTED


func send_attack(entity_id: int) -> void:
	if _is_client_connected():
		req_attack.rpc_id(SERVER_PEER_ID, entity_id)


func send_stop_attack() -> void:
	if _is_client_connected():
		req_stop_attack.rpc_id(SERVER_PEER_ID)


func send_pickup(entity_id: int) -> void:
	if _is_client_connected():
		req_pickup.rpc_id(SERVER_PEER_ID, entity_id)


func set_client_target(entity_id: int) -> void:
	if client_attack_target == entity_id:
		return
	client_attack_target = entity_id
	attack_target_changed.emit(entity_id)


## Clique numa coisa clicável (ClientView.interact_requested): monstro vivo -> ataque; item no
## chão -> pegar; o resto (NPC, objeto do mapa) -> Net.send_interact.
func route_interact(target_id: String) -> void:
	var e: Node = find_entity(parse_entity_id(target_id))
	if e != null and e.get(&"kind") == NetEntity.KIND_MONSTER:
		var eid: int = int(e.get(&"entity_id"))
		set_client_target(eid)
		send_attack(eid)
		return
	if e != null and e.get(&"kind") == NetEntity.KIND_DROP:
		send_pickup(int(e.get(&"entity_id")))
		return
	# Outro jogador: menu "Convidar para o grupo" (GameUI), não vai ao servidor.
	if e != null and e.get(&"kind") == NetEntity.KIND_PLAYER:
		if not (e as NetEntity).is_local_player():
			NetParty.player_menu_requested.emit(int(e.get(&"entity_id")), str(e.get(&"display_name")))
		return
	Net.send_interact(target_id)


static func parse_entity_id(target_id: String) -> int:
	if not target_id.begins_with(TARGET_ENTITY_PREFIX):
		return -1
	var rest: String = target_id.trim_prefix(TARGET_ENTITY_PREFIX)
	return rest.to_int() if rest.is_valid_int() else -1


## Cliente: a entidade com esse id na instância atual (null se não existe/invisível).
func find_entity(entity_id: int) -> Node3D:
	if entity_id < 0:
		return null
	var root: Node = get_node_or_null(INSTANCES_PATH)
	if root == null:
		return null
	for inst: Node in root.get_children():
		var ents: Node = inst.get_node_or_null(ENTITIES_NODE)
		if ents == null:
			continue
		var e: Node = ents.get_node_or_null(str(entity_id))
		if e is Node3D:
			return e as Node3D
	return null


## Cliente: todas as entidades da instância atual.
func all_entities() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var root: Node = get_node_or_null(INSTANCES_PATH)
	if root == null:
		return out
	for inst: Node in root.get_children():
		var ents: Node = inst.get_node_or_null(ENTITIES_NODE)
		if ents == null:
			continue
		for e: Node in ents.get_children():
			if e is Node3D:
				out.append(e as Node3D)
	return out


func _on_local_player_spawned(_player: Node3D) -> void:
	if Net.is_server or _fx != null or not ResourceLoader.exists(FX_SCRIPT):
		return
	_fx = (load(FX_SCRIPT) as Script).new()
	_fx.name = "CombatFx"
	add_child(_fx)
	# Efeito de subir de nível (NetProgress.level_up), visto por todos da instância.
	var lvl := LevelUpFx.new()
	lvl.name = &"LevelUpFx"
	add_child(lvl)
	# Efeitos das skills (NetProgress.skill_cast): folhas de assets/fx/skills/.
	var sfx := SkillFx.new()
	sfx.name = &"SkillFx"
	add_child(sfx)


@rpc("authority", "call_remote", "reliable")
func _cli_hit(source_id: int, target_id: int, amount: int, crit: bool, damage_type: int,
		target_hp_ratio: float) -> void:
	hit.emit(source_id, target_id, amount, crit, damage_type, target_hp_ratio)


@rpc("authority", "call_remote", "reliable")
func _cli_death(entity_id: int) -> void:
	entity_died.emit(entity_id)


@rpc("authority", "call_remote", "reliable")
func _cli_attack_target(entity_id: int) -> void:
	client_attack_target = entity_id
	attack_target_changed.emit(entity_id)


@rpc("authority", "call_remote", "reliable")
func _cli_healed(source_id: int, target_id: int, amount: int) -> void:
	healed.emit(source_id, target_id, amount)
