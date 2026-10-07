class_name DialogueRunner
extends RefCounted
## Executa DialogueDef no servidor, um diálogo por jogador (PlayerSession). Filtra as opções pelas
## condições (min_level, has_item), manda ao cliente só as visíveis e executa as ações
## (open_shop, close, give_item) quando o jogador escolhe. O NPC fica "ocupado" (NpcBrain.engage) enquanto
## o diálogo ou a loja estiverem abertos.

const ACTION_NONE: StringName = &""
const ACTION_OPEN_SHOP: StringName = &"open_shop"
const ACTION_CLOSE: StringName = &"close"
## ADENDO 1: dá um item; action_args {"item_id": StringName, "qty": int, "once": bool}.
const ACTION_GIVE_ITEM: StringName = &"give_item"
const ACTION_CRAFT_ITEM: StringName = &"craft_item"
const ACTION_COLLECT_STORY_CLUE: StringName = &"collect_story_clue"
const ACTION_CHOOSE_STORY_ROUTE: StringName = &"choose_story_route"
const ACTION_RECORD_STORY_OBSERVATION: StringName = &"record_story_observation"
const ARG_ITEM_ID: StringName = &"item_id"
const ARG_QTY: StringName = &"qty"
const ARG_ONCE: StringName = &"once"
const ARG_STORY_ID: StringName = &"story_id"
const ARG_CLUE_ID: StringName = &"clue_id"
const ARG_CLUE_NAME_KEY: StringName = &"clue_name_key"
const ARG_ROUTE_ID: StringName = &"route_id"
const ARG_MATERIALS: StringName = &"materials"
const ARG_CRAFT_RANK: StringName = &"causos_rank"
const STORY_CLUE_LIMIT: int = 7
const STORY_CLUE_TARGET: int = 3
const DEFAULT_GIVE_QTY: int = 1
const COND_MIN_LEVEL: StringName = &"min_level"
const COND_HAS_ITEM: StringName = &"has_item"

var world: ServerWorld = null


func _init(p_world: ServerWorld) -> void:
	world = p_world


## Começa o diálogo do NPC (ou abre a loja direto, se o NPC só tiver loja).
func start(session: PlayerSession, npc: NetEntity) -> void:
	var def: NpcDef = Content.npc(npc.def_id)
	if def == null:
		return
	close(session, true)
	close_shop(session, true)
	if def.dialogue != null:
		var brain: NpcBrain = world.get_brain(npc)
		if brain != null:
			brain.engage(session.peer_id, session.entity)
		session.dialogue_npc_id = npc.entity_id
		session.dialogue_def = def.dialogue
		Net.log_line("dialogue_started", {"peer": session.peer_id, "npc": npc.entity_id,
				"dialogue": String(def.dialogue.id)})
		_show_node(session, def.dialogue.get_node_by_id(def.dialogue.start_node))
	elif def.shop != null:
		open_shop(session, npc)


## Mostra um nó (também nós gerados em código, como os de quest do Agente Q).
func show_node(session: PlayerSession, node: DialogueNode) -> void:
	_show_node(session, node)


func _show_node(session: PlayerSession, node: DialogueNode) -> void:
	if node == null:
		Net.log_line("dialogue_node_missing", {"peer": session.peer_id,
				"dialogue": String(session.dialogue_def.id)})
		close(session, true)
		return
	session.dialogue_node = node
	session.dialogue_options.clear()
	var keys: Array[String] = []
	for opt: DialogueOption in node.options:
		if is_option_visible(session, opt):
			session.dialogue_options.append(opt)
			keys.append(opt.text_key)
	# Agente Q: opções de quest do Mestre (entram sozinhas no primeiro nó).
	if world.progression != null:
		world.progression.quests.extend_dialogue(session, node, keys)
	# Dona Ana: falar com ela faz a cidade dela conhecida.
	if world.waystones != null:
		world.waystones.extend_dialogue(session, node, keys)
	# Agente R (GDD §9.3): Mestre no nível 10 fala do título que ensina (TitleTalk, min_level).
	TitleTalk.extend_dialogue(self, session, node, keys)
	var npc: NetEntity = world.get_entity(session.dialogue_npc_id)
	var def: NpcDef = Content.npc(npc.def_id) if npc != null else null
	var speaker: String = def.name_key if def != null else ""
	Net.push_dialogue_opened(session.peer_id, session.dialogue_npc_id, speaker, node.text_key, keys)


func is_option_visible(session: PlayerSession, opt: DialogueOption) -> bool:
	if opt.action == ACTION_CRAFT_ITEM and not _can_craft(session, opt):
		return false
	# give_item "once" já recebido: a opção some.
	if opt.action == ACTION_GIVE_ITEM and bool(opt.action_args.get(ARG_ONCE, false)) \
			and session.character.once_flags.has(_once_key(session, opt)):
		return false
	if opt.action == ACTION_COLLECT_STORY_CLUE:
		var story_id := StringName(str(opt.action_args.get(ARG_STORY_ID, "")))
		var clue_id := StringName(str(opt.action_args.get(ARG_CLUE_ID, "")))
		if story_id.is_empty() or clue_id.is_empty() \
				or session.character.story_clue_count(story_id) >= STORY_CLUE_LIMIT \
				or session.character.once_flags.has(_clue_key(story_id, clue_id)):
			return false
	if opt.action == ACTION_CHOOSE_STORY_ROUTE:
		var route_story := StringName(str(opt.action_args.get(ARG_STORY_ID, "")))
		if route_story.is_empty() or session.character.story_clue_count(route_story) < STORY_CLUE_TARGET \
				or session.character.story_arc_completed(route_story):
			return false
		if session.character.story_route_locked(route_story) \
				and session.character.story_route(route_story) != StringName(str(opt.action_args.get(ARG_ROUTE_ID, ""))):
			return false
	if opt.action == ACTION_RECORD_STORY_OBSERVATION:
		var observation_story := StringName(str(opt.action_args.get(ARG_STORY_ID, "")))
		var map_id: StringName = Progression.map_of(session.entity.instance_id)
		if observation_story.is_empty() or session.character.story_route(observation_story) != &"pact" \
				or not DayNight.is_full_moon_night(map_id) or not _is_forest_map(map_id) \
				or session.character.story_observation_count(observation_story) >= 3 \
				or session.character.has_story_observation(observation_story, DayNight.story_night_id()):
			return false
	for key: StringName in opt.conditions:
		var value: Variant = opt.conditions[key]
		match key:
			COND_MIN_LEVEL:
				if session.character.level < int(value):
					return false
			COND_HAS_ITEM:
				var item_id := StringName(str(value))
				if not session.character.inventory.has_item(item_id) \
						and not _is_equipped(session, item_id):
					return false
			_:
				# Agente Q: quest_available/active/ready/done, has_title, knows_skill.
				if world.progression != null and world.progression.quests.handles_condition(key):
					if not world.progression.quests.check_condition(session, key, value):
						return false
					continue
				# Condição desconhecida (fases futuras): esconde, por segurança.
				push_warning("Unknown dialogue condition '%s'" % key)
				return false
	return true


func _can_craft(session: PlayerSession, opt: DialogueOption) -> bool:
	var item_id := StringName(str(opt.action_args.get(ARG_ITEM_ID, "")))
	var qty: int = int(opt.action_args.get(ARG_QTY, 1))
	var output: ItemDef = Content.item(item_id)
	var materials: Variant = opt.action_args.get(ARG_MATERIALS, {})
	var required_rank: int = int(opt.action_args.get(ARG_CRAFT_RANK, 0))
	if output == null or qty <= 0 or typeof(materials) != TYPE_DICTIONARY \
			or (materials as Dictionary).is_empty() \
			or CharacterData.causos_rank_index(session.character.causos) < required_rank \
			or not session.character.inventory.can_add(item_id, qty):
		return false
	for raw_id: Variant in materials:
		var material_id := StringName(str(raw_id))
		var amount: int = int(materials[raw_id])
		if Content.item(material_id) == null or amount <= 0 \
				or not session.character.inventory.has_item(material_id, amount):
			return false
	return true


func _craft_item(session: PlayerSession, opt: DialogueOption) -> bool:
	if not _can_craft(session, opt):
		return false
	var inv: Inventory = session.character.inventory
	var materials: Dictionary = opt.action_args[ARG_MATERIALS]
	for raw_id: Variant in materials:
		var material_id := StringName(str(raw_id))
		var remaining: int = int(materials[raw_id])
		for slot: int in inv.size():
			var stack: ItemStack = inv.get_slot(slot)
			if stack == null or stack.item_id != material_id:
				continue
			var take: int = mini(stack.qty, remaining)
			inv.remove_at(slot, take)
			remaining -= take
			if remaining <= 0:
				break
	var item_id := StringName(str(opt.action_args[ARG_ITEM_ID]))
	var qty: int = int(opt.action_args.get(ARG_QTY, 1))
	var def: ItemDef = Content.item(item_id)
	if not inv.add(item_id, qty):
		push_warning("DialogueRunner: crafted item failed capacity check after consuming materials")
		return false
	session.save_pending = true
	if Net.is_server and session.peer_id > 0:
		Net.push_system_message(session.peer_id, "PROG_MSG_CRAFTED", [def.name_key, qty])
	Net.log_line("item_crafted", {"peer": session.peer_id, "item": String(item_id),
			"qty": qty, "materials": materials})
	return true


## Chave da marca "uma vez": diálogo + item (o mesmo presente não se repete nesse diálogo).
func _once_key(session: PlayerSession, opt: DialogueOption) -> String:
	var dlg: StringName = session.dialogue_def.id if session.dialogue_def != null else &""
	return "give:%s:%s" % [dlg, str(opt.action_args.get(ARG_ITEM_ID, ""))]


func _give_item(session: PlayerSession, opt: DialogueOption) -> bool:
	var item_id := StringName(str(opt.action_args.get(ARG_ITEM_ID, "")))
	var qty: int = int(opt.action_args.get(ARG_QTY, DEFAULT_GIVE_QTY))
	if Content.item(item_id) == null or qty <= 0:
		push_warning("give_item with invalid item '%s' in dialogue %s" % [item_id,
				session.dialogue_def.id])
		return false
	if not session.character.inventory.add(item_id, qty):
		Net.push_system_message(session.peer_id, SysMsg.INVENTORY_FULL)
		return false
	if bool(opt.action_args.get(ARG_ONCE, false)):
		session.character.once_flags[_once_key(session, opt)] = true
	session.save_pending = true
	Net.log_line("dialogue_give_item", {"peer": session.peer_id, "item": String(item_id),
			"qty": qty})
	return true


func _collect_story_clue(session: PlayerSession, opt: DialogueOption) -> void:
	var story_id := StringName(str(opt.action_args.get(ARG_STORY_ID, "")))
	var clue_id := StringName(str(opt.action_args.get(ARG_CLUE_ID, "")))
	if not session.character.record_story_clue(story_id, clue_id):
		return
	session.save_pending = true
	var count: int = session.character.story_clue_count(story_id)
	var clue_name: String = str(opt.action_args.get(ARG_CLUE_NAME_KEY, ""))
	Net.push_system_message(session.peer_id, "PROG_MSG_STORY_CLUE_FOUND", [clue_name, count, STORY_CLUE_TARGET])
	if count == STORY_CLUE_TARGET:
		Net.push_system_message(session.peer_id, "PROG_MSG_STORY_CLUES_COMPLETE", [])
	Net.log_line("story_clue_found", {"peer": session.peer_id, "story": String(story_id),
			"clue": String(clue_id), "count": count})


func _choose_story_route(session: PlayerSession, opt: DialogueOption) -> bool:
	var story_id := StringName(str(opt.action_args.get(ARG_STORY_ID, "")))
	var route_id := StringName(str(opt.action_args.get(ARG_ROUTE_ID, "")))
	if not session.character.choose_story_route(story_id, route_id):
		return false
	session.save_pending = true
	Net.push_system_message(session.peer_id, "PROG_MSG_STORY_ROUTE_SELECTED", [])
	Net.log_line("story_route_selected", {"peer": session.peer_id, "story": String(story_id),
			"route": String(route_id)})
	return true


func _record_story_observation(session: PlayerSession, opt: DialogueOption) -> bool:
	var story_id := StringName(str(opt.action_args.get(ARG_STORY_ID, "")))
	var night_id: String = DayNight.story_night_id()
	var count: int = session.character.record_story_observation(story_id, night_id)
	if count <= 0:
		return false
	session.save_pending = true
	Net.push_system_message(session.peer_id, "PROG_MSG_STORY_OBSERVATION", [count, 3])
	if session.character.story_route_locked(story_id) and count == 2:
		Net.push_system_message(session.peer_id, "PROG_MSG_STORY_ROUTE_LOCKED", [])
	Net.log_line("story_observation", {"peer": session.peer_id, "story": String(story_id),
			"night": night_id, "count": count, "route_locked": session.character.story_route_locked(story_id)})
	return true


static func _is_forest_map(map_id: StringName) -> bool:
	return map_id in [&"enchanted_forest", &"enchanted_forest_glade", &"enchanted_forest_roots",
			&"enchanted_forest_heart"]


static func _clue_key(story_id: StringName, clue_id: StringName) -> String:
	return "story_clue:%s:%s" % [story_id, clue_id]


func _is_equipped(session: PlayerSession, item_id: StringName) -> bool:
	for st: ItemStack in session.character.equipment.equipped_stacks():
		if st.item_id == item_id:
			return true
	return false


func choose(session: PlayerSession, option_index: int) -> void:
	if not session.has_dialogue():
		Net.log_invalid(session.peer_id, "dialogue_choice_without_dialogue")
		return
	if option_index < 0 or option_index >= session.dialogue_options.size():
		Net.log_invalid(session.peer_id, "dialogue_choice_out_of_range", {"index": option_index})
		return
	var opt: DialogueOption = session.dialogue_options[option_index]
	# As condições são revalidadas na escolha (o estado pode ter mudado desde a exibição).
	if not is_option_visible(session, opt):
		Net.log_invalid(session.peer_id, "dialogue_choice_hidden", {"index": option_index})
		return
	var npc: NetEntity = world.get_entity(session.dialogue_npc_id)
	if npc == null:
		close(session, true)
		return
	Net.log_line("dialogue_choice", {"peer": session.peer_id, "npc": npc.entity_id,
			"option": opt.text_key, "action": String(opt.action), "next": String(opt.next_node)})
	match opt.action:
		ACTION_OPEN_SHOP:
			close(session, true, false)
			open_shop(session, npc)
			return
		ACTION_CLOSE:
			close(session, true)
			return
		ACTION_GIVE_ITEM:
			if not _give_item(session, opt):
				close(session, true)
				return
		ACTION_CRAFT_ITEM:
			if not _craft_item(session, opt):
				Net.log_invalid(session.peer_id, "craft_recipe_rejected", {"dialogue": String(session.dialogue_def.id)})
				return
		ACTION_COLLECT_STORY_CLUE:
			_collect_story_clue(session, opt)
		ACTION_CHOOSE_STORY_ROUTE:
			if not _choose_story_route(session, opt):
				Net.log_invalid(session.peer_id, "story_route_rejected", {"peer": session.peer_id})
				return
		ACTION_RECORD_STORY_OBSERVATION:
			if not _record_story_observation(session, opt):
				Net.log_invalid(session.peer_id, "story_observation_rejected", {"peer": session.peer_id})
				return
		TitleTalk.ACTION:
			TitleTalk.run(self, session, opt)
			return
		_:
			# Dona Ana: salvar a cidade, lista de destinos e viagem.
			if world.waystones != null and world.waystones.handles_action(opt.action):
				world.waystones.run_dialogue_action(session, opt)
				return
			# Agente Q: accept_quest, turn_in_quest, start_trial (e os nós gerados de quest).
			if world.progression != null and world.progression.quests.handles_action(opt.action):
				if world.progression.quests.run_dialogue_action(session, opt):
					return
	if opt.next_node.is_empty():
		close(session, true)
		return
	_show_node(session, session.dialogue_def.get_node_by_id(opt.next_node))


## Fecha o diálogo. release_npc = false mantém o NPC ocupado (ex.: vai abrir a loja em seguida).
func close(session: PlayerSession, notify: bool, release_npc: bool = true) -> void:
	if not session.has_dialogue():
		return
	var npc_id: int = session.dialogue_npc_id
	session.dialogue_npc_id = 0
	session.dialogue_def = null
	session.dialogue_node = null
	session.dialogue_options.clear()
	if release_npc and session.shop_npc_id != npc_id:
		_release_npc(session, npc_id)
	if notify:
		Net.push_dialogue_closed(session.peer_id)
	Net.log_line("dialogue_closed", {"peer": session.peer_id, "npc": npc_id})


func open_shop(session: PlayerSession, npc: NetEntity) -> void:
	var def: NpcDef = Content.npc(npc.def_id)
	if def == null or def.shop == null:
		Net.log_line("npc_without_shop", {"peer": session.peer_id, "npc": npc.entity_id})
		_release_npc(session, npc.entity_id)
		return
	var brain: NpcBrain = world.get_brain(npc)
	if brain != null:
		brain.engage(session.peer_id, session.entity)
	session.shop_id = def.shop.id
	session.shop_npc_id = npc.entity_id
	var rank: int = CharacterData.causos_rank_index(session.character.causos)
	var stock: Array[StringName] = def.shop.available_items(rank)
	Net.push_shop_opened(session.peer_id, def.shop.id, stock)
	Net.log_line("shop_opened", {"peer": session.peer_id, "shop": String(def.shop.id),
			"npc": npc.entity_id, "causos_rank": rank, "items": stock.size()})


func close_shop(session: PlayerSession, notify: bool) -> void:
	if not session.has_shop():
		return
	var npc_id: int = session.shop_npc_id
	session.shop_id = &""
	session.shop_npc_id = 0
	if session.dialogue_npc_id != npc_id:
		_release_npc(session, npc_id)
	if notify:
		Net.push_shop_closed(session.peer_id)
	Net.log_line("shop_closed", {"peer": session.peer_id, "npc": npc_id})


func _release_npc(session: PlayerSession, npc_id: int) -> void:
	var npc: NetEntity = world.get_entity(npc_id)
	var brain: NpcBrain = world.get_brain(npc) if npc != null else null
	if brain != null:
		brain.disengage(session.peer_id)


## Fecha diálogo/loja se o jogador se afastou do NPC (ou o NPC sumiu). Chamado a cada tick.
func check_range(session: PlayerSession) -> void:
	var max_dist: float = world.session_range()
	if session.has_dialogue():
		var npc: NetEntity = world.get_entity(session.dialogue_npc_id)
		if npc == null or npc.flat_distance_to(session.entity.net_position) > max_dist:
			close(session, true)
	if session.has_shop():
		var npc2: NetEntity = world.get_entity(session.shop_npc_id)
		if npc2 == null or npc2.flat_distance_to(session.entity.net_position) > max_dist:
			close_shop(session, true)
