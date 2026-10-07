class_name DropService
extends RefCounted
## Itens no chão (GDD §10.5): NetEntity kind &"drop" (def_id = item_id, appearance {"qty"}),
## visível a todos da instância, some depois de CombatRules.DROP_LIFETIME_SEC. Posse estilo Ragnarok (GDD §10.5,
## mapas compartilhados desde 30/09/2026): por Balance.cfg.drop_owner_sec o drop é só do dono do abate (quem
## causou mais dano) e do grupo dele; depois fica livre para qualquer um (owner 0 = livre desde o início).
## Pegar: dentro de Balance.cfg.pickup_range (o CombatService anda até lá antes). Inventory.add já marca itens
## presos à zona (N).

const APPEARANCE_QTY: StringName = &"qty"

var world: ServerWorld = null
var _next_index: int = 0
## entity_id -> {"entity": NetEntity, "owner": int, "expire_msec": int}
var _drops: Dictionary[int, Dictionary] = {}


func _init(p_world: ServerWorld) -> void:
	world = p_world


func spawn(instance_id: StringName, pos: Vector3, item_id: StringName, qty: int,
		owner_peer: int) -> NetEntity:
	var def: ItemDef = Content.item(item_id)
	if def == null or qty <= 0:
		Net.log_line("drop_item_unknown", {"item": String(item_id), "qty": qty})
		return null
	_next_index += 1
	var e: NetEntity = world.new_entity()
	e.server_setup(CombatRules.DROP_ID_BASE + _next_index, NetEntity.KIND_DROP, def.name_key,
			item_id, instance_id, pos)
	e.appearance = {APPEARANCE_QTY: qty}
	world.spawn_entity(e)
	var now: int = Time.get_ticks_msec()
	_drops[e.entity_id] = {"entity": e, "owner": owner_peer, "item": item_id, "qty": qty,
			"owner_until_msec": now + int(Balance.cfg.drop_owner_sec * CombatRules.MSEC_PER_SEC),
			"expire_msec": now + int(CombatRules.DROP_LIFETIME_SEC * CombatRules.MSEC_PER_SEC)}
	Net.log_line("drop_spawned", {"id": e.entity_id, "item": String(item_id), "qty": qty,
			"owner": owner_peer, "owner_sec": Balance.cfg.drop_owner_sec, "instance": String(instance_id),
			"pos": str(pos)})
	return e


func get_drop(entity_id: int) -> NetEntity:
	var v: Variant = _drops.get(entity_id, {}).get("entity")
	return v as NetEntity if is_instance_valid(v) else null


## "" = pode pegar; senão o motivo (log).
func check_pickup(session: PlayerSession, entity_id: int) -> String:
	var e: NetEntity = get_drop(entity_id)
	if e == null:
		return "pickup_target_invalid"
	if e.instance_id != session.entity.instance_id:
		return "pickup_other_instance"
	if not may_pick(session.peer_id, entity_id):
		return "pickup_not_owner"
	return ""


## O peer pode pegar agora? Livre (sem dono ou posse vencida), o dono ou alguém do grupo do dono.
func may_pick(peer_id: int, entity_id: int) -> bool:
	var d: Dictionary = _drops.get(entity_id, {})
	var owner: int = int(d.get("owner", 0))
	if owner == 0 or owner == peer_id or Time.get_ticks_msec() >= int(d.get("owner_until_msec", 0)):
		return true
	return world.party != null and world.party.same_party(peer_id, owner)


## Tenta pôr no inventário (dentro do alcance, já validado). "" = pegou; senão o motivo.
func pickup(session: PlayerSession, entity_id: int) -> String:
	var why: String = check_pickup(session, entity_id)
	if not why.is_empty():
		return why
	var d: Dictionary = _drops[entity_id]
	var item_id: StringName = d["item"]
	var qty: int = d["qty"]
	if not session.character.inventory.can_add(item_id, qty):
		return "pickup_inventory_full"
	# Antes de entrar na mochila: a coleta da quest de título só conta o que o próprio personagem pegou.
	if world.progression != null:
		world.progression.quests.on_item_looted(session, item_id, qty)
	session.character.inventory.add(item_id, qty)
	var e: NetEntity = d["entity"]
	_drops.erase(entity_id)
	world.despawn_entity(e)
	Net.log_line("drop_picked", {"peer": session.peer_id, "id": entity_id, "item": String(item_id),
			"qty": qty})
	return ""


func item_of(entity_id: int) -> StringName:
	return _drops.get(entity_id, {}).get("item", &"")


func qty_of(entity_id: int) -> int:
	return int(_drops.get(entity_id, {}).get("qty", 0))


func tick() -> void:
	if _drops.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	for id: int in _drops.keys():
		var d: Dictionary = _drops[id]
		if now < int(d["expire_msec"]) and is_instance_valid(d["entity"]):
			continue
		_drops.erase(id)
		if is_instance_valid(d["entity"]):
			world.despawn_entity(d["entity"] as NetEntity)
		Net.log_line("drop_expired", {"id": id, "item": String(d["item"])})
