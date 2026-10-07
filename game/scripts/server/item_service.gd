class_name ItemService
extends RefCounted
## Regras de itens no servidor: mover no inventário, usar consumível (poção instantânea; demais
## usáveis com conjuração e recarga por grupo, GDD §8.1 "Tempo de uso na barra"),
## equipar/desequipar (7 espaços + 3 cosméticos), comprar e vender na loja aberta (Estrelas).
## Toda recusa é registrada em log (Net.log_invalid) e, se for erro "honesto" do jogador,
## também avisada com Net.push_system_message (chaves em SysMsg).

## GDD §8.1/§11.3 (28/09/2026): poções de vida/mana são instantâneas e sem recarga. Os demais
## usáveis têm conjuração e recarga por grupo (ItemDef.use_effect "cast_sec", "cooldown_sec",
## "cooldown_group"; padrões em Balance, grupo "Cast & cooldown"). Fórmulas em CastTiming.
const EFFECT_HEAL_HP: StringName = &"heal_hp"
const EFFECT_HEAL_MP: StringName = &"heal_mp"
## Pergaminho de Retorno (30/09/2026): leva à cidade salva com a Dona Ana, ao lado dela; sem ela, à última
## cidade visitada (CharacterData.last_city), no SpawnPoint (MapTransfer.return_city_of / return_marker_of).
const EFFECT_RETURN_CITY: StringName = &"return_city"
## Reforço de defesa por item (Unguento de Casco, 06/10/2026): def_buff_pct (0,2 = +20% DEF) por buff_sec,
## o mesmo DEF_BUFF das skills (StatusEffects). Usar de novo renova o tempo.
const EFFECT_DEF_BUFF_PCT: StringName = &"def_buff_pct"
const EFFECT_BUFF_SEC: StringName = &"buff_sec"
const MSG_RETURN_DEAD: String = "SYS_RETURN_DEAD"
const MSG_RETURN_TRIAL: String = "SYS_RETURN_TRIAL"
const MSG_RETURN_TRADE: String = "SYS_RETURN_TRADE"
const MSG_RETURN_TRAINING: String = "SYS_RETURN_TRAINING"
const MSG_RETURN_DONE: String = "SYS_RETURN_DONE"
const INTERRUPT_DAMAGE: StringName = &"damage"
const MSG_CAST_INTERRUPTED: String = "PROG_MSG_CAST_INTERRUPTED"
## Quantidade máxima por compra/venda (uma pilha cheia, GDD §11.3).
const MAX_TRADE_QTY: int = 99
const MSEC_PER_SEC: float = 1000.0

var world: ServerWorld = null
## Uso com conjuração em andamento: peer_id -> {"item", "resolve_msec", "total_ms", "cooldown_ms", "group"}.
var _pending_use: Dictionary[int, Dictionary] = {}
## peer_id -> {grupo: recarga total (ms)} (a sombra da barra usa o total certo).
var _group_totals: Dictionary[int, Dictionary] = {}


func _init(p_world: ServerWorld) -> void:
	world = p_world
	CombatEvents.bus().damage_applied.connect(_on_damage_applied)


func _reject(session: PlayerSession, reason: String, data: Dictionary = {},
		sys_key: String = "", sys_args: Array = []) -> void:
	Net.log_invalid(session.peer_id, reason, data)
	if not sys_key.is_empty():
		Net.push_system_message(session.peer_id, sys_key, sys_args)


# ---------------------------------------------------------------- inventário

func inventory_move(session: PlayerSession, from_slot: int, to_slot: int) -> void:
	if not session.character.inventory.move(from_slot, to_slot):
		_reject(session, "inventory_move_invalid", {"from": from_slot, "to": to_slot})
		return
	Net.log_line("inventory_moved", {"peer": session.peer_id, "from": from_slot, "to": to_slot})


func use_item(session: PlayerSession, slot: int) -> void:
	var c: CharacterData = session.character
	var st: ItemStack = c.inventory.get_slot(slot)
	if st == null:
		_reject(session, "use_item_empty_slot", {"slot": slot})
		return
	var def: ItemDef = st.get_def()
	if def == null or def.type != ItemDef.ItemType.CONSUMABLE:
		_reject(session, "use_item_not_consumable", {"slot": slot, "item": String(st.item_id)},
				SysMsg.ITEM_NOT_USABLE)
		return
	if CastTiming.is_instant_item(def):
		# Poção: instantânea, sem conjuração e sem recarga (pode ser usada até conjurando).
		_apply_use(session, slot, def, &"", 0)
		return
	var is_return: bool = def.use_effect.has(EFFECT_RETURN_CITY)
	if is_return:
		var block: Array = return_block(session)
		if not block.is_empty():
			_reject(session, "use_return_" + str(block[0]), {"item": String(def.id)}, str(block[1]))
			return
	var group: StringName = CastTiming.item_group(def)
	var now: int = Time.get_ticks_msec()
	var until: int = c.cooldown_until_msec.get(group, 0)
	if now < until:
		var left_sec: int = ceili(float(until - now) / MSEC_PER_SEC)
		_reject(session, "use_item_on_cooldown", {"item": String(st.item_id),
				"group": String(group), "left_sec": left_sec}, SysMsg.ITEM_ON_COOLDOWN, [left_sec])
		return
	if _pending_use.has(session.peer_id) or _skill_casting(session):
		_reject(session, "use_item_busy_casting", {"item": String(st.item_id)})
		return
	var stats: Dictionary = c.compute_stats()
	var cast_ms: int = CastTiming.to_ms(CastTiming.item_cast_sec(def, stats))
	var cooldown_ms: int = CastTiming.to_ms(CastTiming.item_cooldown_sec(def, stats))
	if is_return:
		# Fora de combate é na hora; em combate, leitura curta que o dano interrompe.
		var fighting: bool = world.combat != null and world.combat.is_in_combat(session.peer_id)
		cast_ms = CastTiming.to_ms(Balance.cfg.return_scroll_combat_cast_sec) if fighting else 0
	if cast_ms <= 0:
		_apply_use(session, slot, def, group, cooldown_ms)
		return
	# Conjuração: o item só é gasto no fim (andar ou ser atordoado interrompe).
	_pending_use[session.peer_id] = {"item": def.id, "resolve_msec": now + cast_ms, "total_ms": cast_ms,
			"cooldown_ms": cooldown_ms, "group": group, "interrupt_on_damage": is_return}
	var me: NetEntity = session.entity
	if me.get_mover() != null:
		me.get_mover().halt()
	NetProgress.push_skill_cast(Net.get_instance_peer_ids(me.instance_id), me.entity_id, def.id,
			NetProgress.NO_TARGET, me.net_position, cast_ms)
	_mark_progress(session)
	Net.log_line("item_use_started", {"peer": session.peer_id, "item": String(def.id),
			"cast_ms": cast_ms, "cooldown_ms": cooldown_ms})


func _skill_casting(session: PlayerSession) -> bool:
	return world.progression != null and world.progression.caster.casting_ms(session.peer_id) > 0


func _mark_progress(session: PlayerSession) -> void:
	if world.progression != null:
		world.progression.mark_dirty(session)


## Aplica o efeito, gasta 1 unidade e começa a recarga do grupo (0 = sem recarga).
func _apply_use(session: PlayerSession, slot: int, def: ItemDef, group: StringName, cooldown_ms: int) -> void:
	var c: CharacterData = session.character
	var dest: StringName = &""
	if def.use_effect.has(EFFECT_RETURN_CITY):
		# Confere de novo na hora (pode ter caído, aberto troca ou provação durante a leitura).
		var block: Array = return_block(session)
		if not block.is_empty():
			_reject(session, "use_return_" + str(block[0]), {"item": String(def.id)}, str(block[1]))
			_mark_progress(session)
			return
		dest = world.map_transfer.return_city_of(c)
	if not group.is_empty() and cooldown_ms > 0:
		c.cooldown_until_msec[group] = Time.get_ticks_msec() + cooldown_ms
		var tot: Dictionary = _group_totals.get(session.peer_id, {})
		tot[group] = cooldown_ms
		_group_totals[session.peer_id] = tot
		_mark_progress(session)
	var st: Dictionary = c.compute_stats()
	c.hp = mini(c.hp + int(def.use_effect.get(EFFECT_HEAL_HP, 0)), int(st[CharacterStats.K_MAX_HP]))
	c.mp = mini(c.mp + int(def.use_effect.get(EFFECT_HEAL_MP, 0)), int(st[CharacterStats.K_MAX_MP]))
	_apply_buffs(session, def)
	c.inventory.remove_at(slot, 1)
	session.mark_dirty(PlayerSession.DIRTY_STATS)
	Net.log_line("item_used", {"peer": session.peer_id, "item": String(def.id),
			"group": String(group), "cooldown_ms": cooldown_ms, "instant": CastTiming.is_instant_item(def),
			"hp": c.hp, "mp": c.mp, "return_to": String(dest)})
	if not dest.is_empty():
		var z: ZoneDef = world.zone_rules.zone_for_map(dest)
		Net.log_line("return_scroll", {"peer": session.peer_id, "from": String(world.get_instance_map_id(session.entity.instance_id)),
				"to": String(dest), "last_city": String(c.last_city)})
		if world.map_transfer.transfer(session, dest, world.map_transfer.return_marker_of(c)):
			Net.push_system_message(session.peer_id, MSG_RETURN_DONE, [z.name_key if z != null and not z.name_key.is_empty() else String(dest)])


## Reforços do item (StatusEffects de Q): por enquanto só a defesa.
func _apply_buffs(session: PlayerSession, def: ItemDef) -> void:
	var pct: float = float(def.use_effect.get(EFFECT_DEF_BUFF_PCT, 0.0))
	var sec: float = float(def.use_effect.get(EFFECT_BUFF_SEC, 0.0))
	if pct == 0.0 or sec <= 0.0 or world.progression == null or session.entity == null:
		return
	world.progression.statuses.add(session.entity, StatusEffects.Kind.DEF_BUFF, sec, pct, def.id, session.entity)


## Pergaminho de Retorno: [motivo, chave] se não pode usar agora; [] = pode. Morto, Campo de Treino (a saída
## é pelo portal, com o título), provação em andamento ou troca aberta.
func return_block(session: PlayerSession) -> Array:
	if session.character.hp <= 0 or (world.combat != null and world.combat.is_dead(session.peer_id)):
		return ["dead", MSG_RETURN_DEAD]
	var map_id: StringName = world.get_instance_map_id(session.entity.instance_id)
	if world.zone_rules.is_training(map_id):
		return ["training", MSG_RETURN_TRAINING]
	if world.progression != null and world.progression.quests.has_trial(session.peer_id):
		return ["trial", MSG_RETURN_TRIAL]
	if world.trade != null and world.trade.is_trading(session.peer_id):
		return ["trade", MSG_RETURN_TRADE]
	return []


## Dano num jogador com leitura que o dano interrompe (Pergaminho de Retorno em combate).
func _on_damage_applied(_source_id: int, target_id: int, amount: int, _crit: bool, _type: int) -> void:
	if amount <= 0 or not _pending_use.has(target_id):
		return
	var p: Dictionary = _pending_use[target_id]
	var s: PlayerSession = world.get_session(target_id)
	if s != null and bool(p.get("interrupt_on_damage", false)):
		interrupt_use(s, INTERRUPT_DAMAGE)


## Recargas restantes dos grupos de usáveis (ms) e os totais, para o snapshot da progressão.
func cooldowns_for(session: PlayerSession) -> Dictionary:
	var left: Dictionary = {}
	var totals: Dictionary = {}
	var now: int = Time.get_ticks_msec()
	var tot: Dictionary = _group_totals.get(session.peer_id, {})
	for g: StringName in session.character.cooldown_until_msec:
		var ms: int = session.character.cooldown_until_msec[g] - now
		if ms > 0:
			left[String(g)] = ms
			totals[String(g)] = int(tot.get(g, ms))
	return {"left": left, "totals": totals}


## Uso com conjuração em andamento: {"item", "total_ms", "left_ms"} ou {}.
func using_info(peer_id: int) -> Dictionary:
	var p: Dictionary = _pending_use.get(peer_id, {})
	if p.is_empty():
		return {}
	return {"item": String(p["item"]), "total_ms": p["total_ms"],
			"left_ms": maxi(0, int(p["resolve_msec"]) - Time.get_ticks_msec())}


## Chamado a cada tick do servidor: conclui usos cuja conjuração terminou; atordoado/morto interrompe.
func tick() -> void:
	if _pending_use.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	for peer_id: int in _pending_use.keys():
		var s: PlayerSession = world.get_session(peer_id)
		if s == null or s.entity == null:
			_pending_use.erase(peer_id)
			continue
		var p: Dictionary = _pending_use[peer_id]
		var stunned: bool = world.progression != null and world.progression.statuses.is_stunned(s.entity)
		if stunned or s.character.hp <= 0:
			interrupt_use(s, &"stun" if stunned else &"dead")
			continue
		if now < int(p["resolve_msec"]):
			continue
		_pending_use.erase(peer_id)
		var item_id: StringName = p["item"]
		var slot: int = _slot_of(s.character.inventory, item_id)
		var def: ItemDef = Content.item(item_id)
		if slot < 0 or def == null:
			Net.log_invalid(peer_id, "use_item_gone_after_cast", {"item": String(item_id)})
			_mark_progress(s)
			continue
		_apply_use(s, slot, def, p["group"], int(p["cooldown_ms"]))


## Interrompe um uso com conjuração (andar, atordoado). O item não é gasto e a recarga não começa.
func interrupt_use(session: PlayerSession, reason: StringName) -> bool:
	var p: Dictionary = _pending_use.get(session.peer_id, {})
	if p.is_empty():
		return false
	_pending_use.erase(session.peer_id)
	var def: ItemDef = Content.item(p["item"])
	if session.entity != null and is_instance_valid(session.entity):
		NetProgress.push_cast_cancelled(Net.get_instance_peer_ids(session.entity.instance_id),
				session.entity.entity_id, p["item"])
	Net.push_system_message(session.peer_id, MSG_CAST_INTERRUPTED, [def.name_key if def != null else ""])
	_mark_progress(session)
	Net.log_line("item_use_interrupted", {"peer": session.peer_id, "item": String(p["item"]),
			"reason": String(reason)})
	return true


static func _slot_of(inv: Inventory, item_id: StringName) -> int:
	for i: int in inv.size():
		var st: ItemStack = inv.get_slot(i)
		if st != null and st.item_id == item_id:
			return i
	return -1


# ---------------------------------------------------------------- equipamento

func equip(session: PlayerSession, slot: int) -> void:
	var c: CharacterData = session.character
	var st: ItemStack = c.inventory.get_slot(slot)
	if st == null:
		_reject(session, "equip_empty_slot", {"slot": slot})
		return
	var def: ItemDef = st.get_def()
	var eslot: StringName = c.equipment.choose_slot(def)
	if eslot.is_empty():
		_reject(session, "equip_not_equippable", {"slot": slot, "item": String(st.item_id)},
				SysMsg.ITEM_NOT_EQUIPPABLE)
		return
	if not _clear_two_hand_conflict(session, def, eslot):
		return
	var old: ItemStack = c.equipment.get_slot(eslot)
	if def.is_ammo:
		# Munição: equipa a pilha inteira no espaço do escudo (offhand).
		c.inventory.replace_at(slot, old)
		c.equipment.set_slot(eslot, st)
	elif st.qty == 1:
		# Troca direta: o item que estava equipado vai para o espaço de onde o novo saiu.
		c.inventory.replace_at(slot, old)
		c.equipment.set_slot(eslot, st)
	else:
		# Pilha de equipáveis (raro): separa um e devolve o antigo ao inventário.
		if old != null and not c.inventory.can_add(old.item_id, old.qty):
			_reject(session, "equip_inventory_full", {"slot": slot}, SysMsg.INVENTORY_FULL)
			return
		c.inventory.remove_at(slot, 1)
		c.equipment.set_slot(eslot, st.copy_with_qty(1))
		if old != null:
			c.inventory.add(old.item_id, old.qty)
	world.refresh_appearance(session)
	Net.log_line("item_equipped", {"peer": session.peer_id, "item": String(def.id),
			"equip_slot": String(eslot), "stats": c.compute_stats()})


## Arma de duas mãos (arco, ItemDef.two_handed) e mão secundária não andam juntas, EXCETO munição
## para arma de projéteis (arco usa a munição equipada no espaço do escudo).
func _clear_two_hand_conflict(session: PlayerSession, def: ItemDef, eslot: StringName) -> bool:
	var c: CharacterData = session.character
	var other: StringName = &""
	if eslot == Equipment.OFFHAND:
		var w: ItemStack = c.equipment.get_slot(&"weapon")
		if w != null and w.get_def() != null and w.get_def().two_handed:
			# Se o item no offhand é munição e a arma é de projéteis (arco), coexistem perfeitamente.
			if def.is_ammo and w.get_def().is_projectile_weapon():
				return true
			other = &"weapon"
	elif def.two_handed and c.equipment.get_slot(Equipment.OFFHAND) != null:
		var off: ItemStack = c.equipment.get_slot(Equipment.OFFHAND)
		# Se a arma sendo equipada é de projéteis e o offhand tem munição, coexistem perfeitamente.
		if def.is_projectile_weapon() and off != null and off.get_def() != null and off.get_def().is_ammo:
			return true
		other = Equipment.OFFHAND
	if other.is_empty():
		return true
	var st: ItemStack = c.equipment.get_slot(other)
	if not c.inventory.can_add(st.item_id, st.qty):
		_reject(session, "equip_two_handed_inventory_full", {"item": String(def.id)}, SysMsg.INVENTORY_FULL)
		return false
	c.equipment.set_slot(other, null)
	c.inventory.add(st.item_id, st.qty)
	Net.log_line("item_unequipped_two_handed", {"peer": session.peer_id, "item": String(st.item_id),
			"equip_slot": String(other)})
	return true


func unequip(session: PlayerSession, equip_slot: StringName) -> void:
	var c: CharacterData = session.character
	if not Equipment.is_valid_slot(equip_slot):
		_reject(session, "unequip_bad_slot", {"equip_slot": String(equip_slot)})
		return
	var st: ItemStack = c.equipment.get_slot(equip_slot)
	if st == null:
		_reject(session, "unequip_empty_slot", {"equip_slot": String(equip_slot)})
		return
	var free: int = c.inventory.first_free_slot()
	if free < 0:
		_reject(session, "unequip_inventory_full", {"equip_slot": String(equip_slot)},
				SysMsg.INVENTORY_FULL)
		return
	c.equipment.set_slot(equip_slot, null)
	c.inventory.put_at(free, st)
	world.refresh_appearance(session)
	Net.log_line("item_unequipped", {"peer": session.peer_id, "item": String(st.item_id),
			"equip_slot": String(equip_slot), "to_slot": free})


# ---------------------------------------------------------------- loja

## Loja aberta e NPC da loja perto. false = recusado (já logado/avisado).
func _check_shop(session: PlayerSession, intent: String) -> bool:
	if not session.has_shop():
		_reject(session, intent + "_shop_not_open", {}, SysMsg.SHOP_NOT_OPEN)
		return false
	var npc: NetEntity = world.get_entity(session.shop_npc_id)
	if npc == null or npc.flat_distance_to(session.entity.net_position) > world.session_range():
		_reject(session, intent + "_too_far", {"npc": session.shop_npc_id}, SysMsg.TOO_FAR)
		world.dialogue.close_shop(session, true)
		return false
	return true


func shop_buy(session: PlayerSession, item_id: StringName, qty: int) -> void:
	if not _check_shop(session, "shop_buy"):
		return
	var shop: ShopDef = Content.shop(session.shop_id)
	var def: ItemDef = Content.item(item_id)
	var rank: int = CharacterData.causos_rank_index(session.character.causos)
	var stock: Array[StringName] = shop.available_items(rank) if shop != null else []
	if shop == null or def == null or item_id not in stock or def.buy_price <= 0:
		_reject(session, "shop_buy_item_not_sold", {"item": String(item_id),
				"shop": String(session.shop_id)}, SysMsg.ITEM_NOT_SOLD_HERE)
		return
	if qty < 1 or qty > MAX_TRADE_QTY:
		_reject(session, "shop_buy_bad_qty", {"qty": qty})
		return
	var c: CharacterData = session.character
	var cost: int = def.buy_price * qty
	if c.stars < cost:
		_reject(session, "shop_buy_not_enough_stars", {"item": String(item_id), "qty": qty,
				"cost": cost, "stars": c.stars}, SysMsg.NOT_ENOUGH_STARS)
		return
	if not c.inventory.add(item_id, qty):
		_reject(session, "shop_buy_inventory_full", {"item": String(item_id), "qty": qty},
				SysMsg.INVENTORY_FULL)
		return
	c.stars -= cost
	session.mark_dirty(PlayerSession.DIRTY_CURRENCY)
	Net.log_line("shop_bought", {"peer": session.peer_id, "item": String(item_id), "qty": qty,
			"cost": cost, "stars": c.stars})


func shop_sell(session: PlayerSession, slot: int, qty: int) -> void:
	if not _check_shop(session, "shop_sell"):
		return
	var c: CharacterData = session.character
	var st: ItemStack = c.inventory.get_slot(slot)
	if st == null:
		_reject(session, "shop_sell_empty_slot", {"slot": slot})
		return
	if qty < 1 or qty > st.qty:
		_reject(session, "shop_sell_bad_qty", {"slot": slot, "qty": qty, "have": st.qty})
		return
	var def: ItemDef = st.get_def()
	if def == null or def.sell_price <= 0:
		_reject(session, "shop_sell_not_sellable", {"item": String(st.item_id)},
				SysMsg.ITEM_NOT_SELLABLE)
		return
	var item_id: StringName = st.item_id
	var gain: int = def.sell_price * qty
	c.inventory.remove_at(slot, qty)
	c.stars += gain
	session.mark_dirty(PlayerSession.DIRTY_CURRENCY)
	Net.log_line("shop_sold", {"peer": session.peer_id, "item": String(item_id), "qty": qty,
			"gain": gain, "stars": c.stars})
