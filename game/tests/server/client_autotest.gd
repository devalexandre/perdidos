extends Node
## Autoteste do cliente (headless), criado por main.gd com --autotest. Dois papéis:
##   shopper  — anda (Fase 1), testa condições de diálogo, NPC WANDER (anda e para ao falar),
##              mercador (diálogo -> loja), compra/usa/equipa/desequipa/vende, move no inventário,
##              ganha a coroa (give_item once), cosmético sobre o chapéu, chat, emotes, sentar no
##              banco, portão, e os testes negativos.
##   observer — anda (Fase 1) e confere que recebe o chat/emote/aparência do shopper e NUNCA o
##              inventário/Estrelas/diálogo/loja dele.
## Imprime "autotest_check {...}" por verificação e "autotest_result {"pass": ...}" no fim;
## código de saída 0 = passou.

const ROLE_SHOPPER: String = "shopper"
const ROLE_OBSERVER: String = "observer"
## Captura em janela (xvfb): walkshot anda (diagonal, reta e segurando o botão) clicando de verdade;
## watcher é o segundo cliente que vê o walkshot andar. Ambos gravam PNGs em --shot-dir.
const ROLE_WALKSHOT: String = "walkshot"
const ROLE_WATCHER: String = "watcher"
const ARG_SHOT_DIR: String = "shot-dir"
const SHOT_INTERVAL_SEC: float = 0.25
const WATCH_SHOT_INTERVAL_SEC: float = 0.5
const WALKSHOT_TRACE_SEC: float = 30.0
const WALK_DIAGONAL: Vector3 = Vector3(4.0, 0.0, 4.0)
const WALK_STRAIGHT: Vector3 = Vector3(-6.0, 0.0, 0.0)
const HOLD_STEPS: int = 12
const HOLD_STEP_SEC: float = 0.15
const HOLD_RADIUS: float = 4.0
const MARK_WALKSHOT_DONE: String = "[walkshot] done"
const WATCHER_TIMEOUT_SEC: float = 60.0
const ARG_ROLE: String = "autotest-role"
const ARG_MOVE: String = "autotest-move"
const ARG_BAD_PROTOCOL: String = "autotest-bad-protocol"

const SETTLE_SEC: float = 2.0
const OBSERVE_SEC: float = 4.0
const MID_SAMPLE_SEC: float = 0.6
const REJECT_WAIT_SEC: float = 3.0
const LINGER_SEC: float = 3.0
const CLOCK_SYNC_TIMEOUT_SEC: float = 10.0
const SHORT_WAIT_SEC: float = 3.0
const WALK_WAIT_SEC: float = 25.0
## Tempo para a replicação (20 Hz + interpolação) refletir uma mudança.
const REPLICATION_SEC: float = 0.5
const WANDER_OBSERVE_SEC: float = 12.0
const WANDER_MIN_MOVE: float = 0.3
const STOP_OBSERVE_SEC: float = 3.0
const STOP_EPSILON: float = 0.05
const FACING_TOLERANCE: float = 0.4
const CHAT_GAP_SEC: float = 1.2
const OBSERVER_TIMEOUT_SEC: float = 130.0
const MOVE_OFFSET: Vector3 = Vector3(4.0, 0.0, 3.0)
const INVALID_TARGET: Vector3 = Vector3(10000.0, 0.0, 10000.0)
const MIN_MOVE: float = 1.0
const BURST_EXTRA: int = 5
const GHOST_ID: int = 999001
const MAX_DIALOGUE_STEPS: int = 6
const MSEC_PER_SEC: float = 1000.0
## Movimento por células (GDD §10.1): amostras da posição dos jogadores no relógio do servidor
## durante o teste da Fase 1; o run_autotest.sh compara com o caminho autoritativo do servidor.
const TRACE_INTERVAL_MSEC: float = 50.0
## Toda posição mostrada fica no centro de uma célula quando parada (tolerância, m).
const CELL_CENTER_TOLERANCE: float = 0.01

const POTION: StringName = &"potion_hp_small"
const MACHETE: StringName = &"machete"
const HAT: StringName = &"straw_hat"
const CROWN: StringName = &"ipe_flower_crown"
const SAGE: StringName = &"test_sage"
const INVENTORY_MOVE_TARGET_SLOT: int = 20
const OVERSPEND_QTY: int = 99
const CHAT_HELLO: String = "Olá, autoteste!"
const CHAT_BANNED: String = "que merda de dia"
const CHAT_BANNED_WORD: String = "merda"
const MARK_WEAPON: String = "[autotest] weapon"
const MARK_DONE: String = "[autotest] done"
const LONG_CHAT_LENGTH: int = 201

var main_node: Node = null
var args: Dictionary[String, String] = {}

var _role: String = ROLE_OBSERVER
var _events: Array[Dictionary] = []
var _checks: Dictionary = {}
var _local: NetEntity = null
var _started: bool = false


func _ready() -> void:
	_role = args.get(ARG_ROLE, ROLE_OBSERVER)
	Net.inventory_changed.connect(func(a: Array) -> void: _rec(&"inventory", [a]))
	Net.equipment_changed.connect(func(a: Dictionary) -> void: _rec(&"equipment", [a]))
	Net.stats_changed.connect(func(a: Dictionary) -> void: _rec(&"stats", [a]))
	Net.currency_changed.connect(func(a: int) -> void: _rec(&"currency", [a]))
	Net.dialogue_opened.connect(func(n: int, s: String, t: String, o: Array[String]) -> void:
		_rec(&"dialogue_opened", [n, s, t, o]))
	Net.dialogue_closed.connect(func() -> void: _rec(&"dialogue_closed", []))
	Net.shop_opened.connect(func(s: StringName, i: Array[StringName]) -> void: _rec(&"shop_opened", [s, i]))
	Net.shop_closed.connect(func() -> void: _rec(&"shop_closed", []))
	Net.chat_received.connect(func(c: StringName, f: String, t: String, e: int) -> void:
		_rec(&"chat", [c, f, t, e]))
	Net.emote_received.connect(func(e: int, id: StringName) -> void: _rec(&"emote", [e, id]))
	Net.system_message.connect(func(k: String, a: Array) -> void: _rec(&"system", [k, a]))
	Net.local_player_spawned.connect(_on_local_player_spawned)
	if args.has(ARG_BAD_PROTOCOL):
		get_tree().create_timer(REJECT_WAIT_SEC).timeout.connect(_finish_rejected)


func _rec(type: StringName, a: Array) -> void:
	_events.append({"t": type, "a": a, "msec": Time.get_ticks_msec()})
	if type == &"system":
		Net.log_line("autotest_event_system", {"key": a[0], "args": a[1]})


func _on_local_player_spawned(player: Node3D) -> void:
	if _started or args.has(ARG_BAD_PROTOCOL):
		return
	_started = true
	_local = player as NetEntity
	await get_tree().create_timer(SETTLE_SEC).timeout
	if _role == ROLE_WALKSHOT:
		await _run_walkshot()
		_finish()
		return
	if _role == ROLE_WATCHER:
		await _run_watcher()
		_finish()
		return
	await _phase1_move_test()
	if _role == ROLE_SHOPPER:
		await _run_shopper()
	else:
		await _run_observer()
	_finish()


# ================================================================ utilidades

func _check(check_name: String, ok: bool, detail: Variant = null) -> bool:
	_checks[check_name] = "pass" if ok else "FAIL"
	Net.log_line("autotest_check", {"role": _role, "check": check_name, "pass": ok,
			"detail": detail})
	return ok


func _skip(check_name: String, why: String) -> void:
	_checks[check_name] = "skip"
	Net.log_line("autotest_check", {"role": _role, "check": check_name, "skip": why})


func _cursor() -> int:
	return _events.size()


## Espera um evento do tipo (a partir do cursor) que satisfaça pred(args). {} = tempo esgotado.
func _wait_event(type: StringName, from: int, timeout: float,
		pred: Callable = Callable()) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + int(timeout * MSEC_PER_SEC)
	var i: int = from
	while true:
		while i < _events.size():
			var e: Dictionary = _events[i]
			i += 1
			if e["t"] == type and (not pred.is_valid() or pred.call(e["a"])):
				return e
		if Time.get_ticks_msec() >= deadline:
			return {}
		await get_tree().process_frame
	return {}


func _count_events(type: StringName, from: int = 0) -> int:
	var n: int = 0
	for i: int in range(from, _events.size()):
		if _events[i]["t"] == type:
			n += 1
	return n


func _wait_sys(key: String, from: int, timeout: float = SHORT_WAIT_SEC) -> bool:
	var e: Dictionary = await _wait_event(&"system", from, timeout,
			func(a: Array) -> bool: return a[0] == key)
	return not e.is_empty()


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Espera até cond() ser verdadeira (ou o tempo acabar).
func _wait_until(cond: Callable, timeout: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * MSEC_PER_SEC)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _instance_node() -> Node:
	var root: Node = main_node.get("instances_root")
	return root.get_child(0) if root != null and root.get_child_count() > 0 else null


func _entities() -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	var inst: Node = _instance_node()
	if inst == null:
		return out
	for e: Node in inst.get_node("Entities").get_children():
		if e is NetEntity:
			out.append(e as NetEntity)
	return out


func _entity(entity_id: int) -> NetEntity:
	for e: NetEntity in _entities():
		if e.entity_id == entity_id:
			return e
	return null


func _npc_def(e: NetEntity) -> NpcDef:
	return Content.npc(e.def_id) if e.is_npc() else null


func _find_npc(pred: Callable) -> NetEntity:
	var list: Array[NetEntity] = _entities()
	list.sort_custom(func(a: NetEntity, b: NetEntity) -> bool: return a.entity_id < b.entity_id)
	for e: NetEntity in list:
		var d: NpcDef = _npc_def(e)
		if d != null and pred.call(d):
			return e
	return null


static func _dialogue_has_action(d: NpcDef, action: StringName) -> bool:
	if d.dialogue == null:
		return false
	for n: DialogueNode in d.dialogue.nodes:
		for o: DialogueOption in n.options:
			if o.action == action:
				return true
	return false


func _other_player() -> NetEntity:
	for e: NetEntity in _entities():
		if e.is_player() and e != _local:
			return e
	return null


func _inv() -> Array:
	return Net.client_inventory


func _count(item_id: StringName) -> int:
	var n: int = 0
	for s: Variant in _inv():
		if s is Dictionary and s.get("item", &"") == item_id:
			n += int(s["qty"])
	return n


func _slot_of(item_id: StringName) -> int:
	var inv: Array = _inv()
	for i: int in range(inv.size()):
		if inv[i] is Dictionary and inv[i].get("item", &"") == item_id:
			return i
	return -1


func _first_empty_slot() -> int:
	var inv: Array = _inv()
	for i: int in range(inv.size()):
		if (inv[i] as Dictionary).is_empty():
			return i
	return -1


func _stat(key: StringName) -> int:
	return int(Net.client_stats.get(key, -1))


func _visual(item_id: StringName) -> StringName:
	var d: ItemDef = Content.item(item_id)
	return d.visual_id if d != null else &""


## Interactables do mapa do cliente (GameMap.get_interactables() ou nó Interactables).
func _map_interactables() -> Dictionary:
	var inst: Node = _instance_node()
	var map_node: Node = inst.get_node_or_null("Map") if inst != null else null
	if map_node == null:
		return {}
	if map_node.has_method("get_interactables"):
		return map_node.call("get_interactables")
	var out: Dictionary = {}
	var root: Node = map_node.get_node_or_null("Interactables")
	if root == null:
		return out
	for c: Node in root.get_children():
		if c.has_meta("interact_id"):
			out[str(c.get_meta("interact_id"))] = {"type": StringName(str(c.get_meta("interact_type", ""))),
					"position": (c as Node3D).global_position,
					"meta": {"facing_yaw": c.get_meta("facing_yaw", 0.0)}}
	return out


func _find_interactable(type: StringName) -> String:
	var objs: Dictionary = _map_interactables()
	var ids: Array = objs.keys()
	ids.sort()
	for id: Variant in ids:
		if StringName(str((objs[id] as Dictionary).get("type", ""))) == type:
			return str(id)
	return ""


## Primeiro portão sem mapa de destino (fechado: só o aviso de nível recomendado), ou "".
func _find_closed_portal() -> String:
	var objs: Dictionary = _map_interactables()
	var ids: Array = objs.keys()
	ids.sort()
	for id: Variant in ids:
		var o: Dictionary = objs[id]
		if StringName(str(o.get("type", ""))) != &"portal":
			continue
		if str((o.get("meta", {}) as Dictionary).get(&"target_map", "")).is_empty():
			return str(id)
	return ""


## Fala com o NPC e espera o diálogo abrir. Devolve o evento ({} = não abriu).
func _talk_to(npc: NetEntity) -> Dictionary:
	var c: int = _cursor()
	Net.send_interact(npc.get_target_id())
	return await _wait_event(&"dialogue_opened", c, WALK_WAIT_SEC,
			func(a: Array) -> bool: return a[0] == npc.entity_id)


## Escolhe no diálogo aberto a opção que leva a `action` (segue next_node se preciso).
## Devolve o cursor anterior à última escolha (para esperar o resultado), ou -1.
func _navigate_to_action(npc: NetEntity, opened: Dictionary, action: StringName) -> int:
	var d: NpcDef = _npc_def(npc)
	var ev: Dictionary = opened
	var visited: Dictionary = {}
	for step: int in range(MAX_DIALOGUE_STEPS):
		var text_key: String = ev["a"][2]
		var options: Array[String] = ev["a"][3]
		visited[text_key] = true
		var node: DialogueNode = null
		for n: DialogueNode in d.dialogue.nodes:
			if n.text_key == text_key:
				node = n
		if node == null:
			return -1
		var pick: int = -1
		for i: int in range(options.size()):
			for o: DialogueOption in node.options:
				if o.text_key == options[i] and o.action == action:
					pick = i
		if pick >= 0:
			var c0: int = _cursor()
			Net.send_dialogue_choice(pick)
			return c0
		for i: int in range(options.size()):
			for o: DialogueOption in node.options:
				if pick < 0 and o.text_key == options[i] and not o.next_node.is_empty():
					var nxt: DialogueNode = d.dialogue.get_node_by_id(o.next_node)
					if nxt != null and not visited.has(nxt.text_key):
						pick = i
		if pick < 0:
			return -1
		var c: int = _cursor()
		Net.send_dialogue_choice(pick)
		ev = await _wait_event(&"dialogue_opened", c, SHORT_WAIT_SEC)
		if ev.is_empty():
			return -1
	return -1


func _close_dialogue_if_open() -> void:
	if Net.client_dialogue_npc_id != 0:
		var c: int = _cursor()
		Net.send_dialogue_close()
		await _wait_event(&"dialogue_closed", c, SHORT_WAIT_SEC)


# ================================================================ Fase 1 (movimento)

func _phase1_move_test() -> void:
	var clock_ready: bool = await _wait_until(func() -> bool: return NetClock.synced, CLOCK_SYNC_TIMEOUT_SEC)
	_check("clock_synced", clock_ready, {"offset_msec": NetClock.offset_msec,
			"rtt_msec": NetClock.rtt_msec})
	if not clock_ready:
		return
	var before: Dictionary[int, Vector3] = {}
	for p: NetEntity in _entities():
		if p.is_player():
			before[p.entity_id] = p.net_position
	Net.send_move_request(INVALID_TARGET)
	var target: Vector3 = _local.net_position + _move_offset()
	Net.send_move_request(target)
	await _trace_players(OBSERVE_SEC)
	var g: float = Balance.cfg.cell_size
	var frac := Vector2(fposmod(_local.net_position.x, g), fposmod(_local.net_position.z, g))
	var half: float = g * 0.5
	_check("grid_stops_on_cell_center", absf(frac.x - half) < CELL_CENTER_TOLERANCE
			and absf(frac.y - half) < CELL_CENTER_TOLERANCE,
			{"pos": str(_local.net_position)})
	var remote_moved: bool = false
	var remote_count: int = 0
	var foreign: bool = false
	for p: NetEntity in _entities():
		if p.instance_id != main_node.call("get_current_instance_id") or p.entity_id == GHOST_ID:
			foreign = true
		if not p.is_player() or p == _local:
			continue
		remote_count += 1
		if before.has(p.entity_id) and before[p.entity_id].distance_to(p.net_position) >= MIN_MOVE:
			remote_moved = true
	var self_moved: bool = before.get(_local.entity_id, _local.net_position).distance_to(
			_local.net_position) >= MIN_MOVE
	_check("phase1_move", remote_count >= 1 and remote_moved and self_moved,
			{"remote_players": remote_count, "remote_moved": remote_moved, "self_moved": self_moved})
	_check("phase1_no_foreign_instance_entity", not foreign and
			(main_node.get("instances_root") as Node).get_child_count() == 1)
	var npcs: int = _entities().filter(func(e: NetEntity) -> bool: return e.is_npc()).size()
	_check("npcs_replicated", npcs > 0, {"npcs": npcs})
	for i: int in range(Balance.cfg.max_client_msgs_per_sec + BURST_EXTRA):
		Net.send_move_request(_local.net_position)
	# Espera o fim da janela de taxa (1 s) antes de seguir.
	await _sleep(CHAT_GAP_SEC)


## Registra (a cada TRACE_INTERVAL_MSEC) a posição de cada jogador no relógio do servidor.
func _trace_players(sec: float) -> void:
	var end: float = NetClock.local_now_msec() + sec * MSEC_PER_SEC
	var next: float = 0.0
	while NetClock.local_now_msec() < end:
		var now: float = NetClock.local_now_msec()
		if now >= next:
			next = now + TRACE_INTERVAL_MSEC
			var t: float = NetClock.server_now_msec()
			for p: NetEntity in _entities():
				if not p.is_player():
					continue
				# Mesma conta que o _process da entidade faz para desenhar neste instante.
				var path: MovePath = p.get_client_path()
				var pos: Vector3 = path.sample(t) if path != null else p.position
				Net.log_line("autotest_trace", {"viewer": _local.entity_id, "entity": p.entity_id,
						"t": snappedf(t, 0.01), "x": snappedf(pos.x, 0.001), "z": snappedf(pos.z, 0.001),
						"shown_x": snappedf(p.position.x, 0.001), "shown_z": snappedf(p.position.z, 0.001)})
		await get_tree().process_frame


func _move_offset() -> Vector3:
	var parts: PackedStringArray = args.get(ARG_MOVE, "").split(",")
	if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
		return Vector3(parts[0].to_float(), 0.0, parts[1].to_float())
	return MOVE_OFFSET


# ================================================================ shopper

func _run_shopper() -> void:
	await _wait_until(func() -> bool: return _inv().size() == CharacterData.INVENTORY_SIZE \
			and not Net.client_stats.is_empty() and not Net.client_equipment.is_empty(), SHORT_WAIT_SEC)
	await _test_initial_state()
	await _test_negatives_before_shop()
	await _test_dialogue_conditions()
	await _test_wander_npc()
	await _test_merchant_and_items()
	await _test_gift_and_cosmetic()
	await _test_chat_and_emotes()
	await _test_map_objects()
	await _sleep(CHAT_GAP_SEC)
	Net.send_chat(&"local", MARK_DONE)
	await _sleep(LINGER_SEC)


func _test_initial_state() -> void:
	var eq_empty: bool = true
	for k: Variant in Net.client_equipment:
		if not StringName(Net.client_equipment[k]).is_empty():
			eq_empty = false
	var expected_hp: int = CharacterStats.HP_BASE + CharacterStats.BASE_ATTRIBUTE \
			* CharacterStats.HP_PER_VIT + CharacterStats.START_LEVEL * CharacterStats.HP_PER_LEVEL
	var expected_atk: int = CharacterStats.BASE_ATTRIBUTE * CharacterStats.ATK_PER_STR \
			+ CharacterStats.START_LEVEL
	_check("starting_kit", Net.client_stars == CharacterData.STARTING_STARS
			and _count(POTION) == CharacterData.STARTING_ITEMS[POTION] and eq_empty
			and _inv().size() == CharacterData.INVENTORY_SIZE,
			{"stars": Net.client_stars, "potions": _count(POTION), "equip_empty": eq_empty})
	_check("equipment_slot_count_matches_contract", Net.client_equipment.size() == Equipment.SLOTS.size(),
			Net.client_equipment.keys())
	_check("initial_stats", _stat(&"level") == 1 and _stat(&"max_hp") == expected_hp
			and _stat(&"hp") == expected_hp and _stat(&"atk") == expected_atk
			and _stat(&"str") == CharacterStats.BASE_ATTRIBUTE, Net.client_stats)
	_check("initial_appearance", _local.appearance.get(&"outfit") == Equipment.DEFAULT_OUTFIT
			and _local.appearance.get(&"body") == _local.def_id, _local.appearance)


func _test_negatives_before_shop() -> void:
	var c: int = _cursor()
	Net.send_shop_buy(POTION, 1)
	_check("neg_buy_without_shop_rejected", await _wait_sys(SysMsg.SHOP_NOT_OPEN, c))
	c = _cursor()
	Net.send_interact("e:%d" % GHOST_ID)
	_check("neg_interact_other_instance_rejected", await _wait_sys(SysMsg.TARGET_INVALID, c))
	c = _cursor()
	Net.send_use_item(_first_empty_slot())
	Net.send_equip(_first_empty_slot())
	await _sleep(REPLICATION_SEC)
	_check("neg_use_equip_empty_slot_no_change", _count_events(&"inventory", c) == 0
			and _count_events(&"equipment", c) == 0)


func _test_dialogue_conditions() -> void:
	var sage: NetEntity = _find_npc(func(d: NpcDef) -> bool: return d.id == SAGE)
	if sage == null:
		_skip("dialogue_conditions", "test_sage fixture not loaded")
		return
	_check("npc_sit_routine", sage.anim == NetEntity.ANIM_SIT, String(sage.anim))
	var ev: Dictionary = await _talk_to(sage)
	if not _check("dialogue_opened_sage", not ev.is_empty()):
		return
	var opts: Array[String] = ev["a"][3]
	var expected: Array[String] = ["TEST_OPT_SAGE_POTION", "TEST_OPT_SAGE_BYE"]
	_check("dialogue_conditions_filtered", opts == expected, opts)
	var c: int = _cursor()
	Net.send_dialogue_choice(opts.size() + 3)
	await _sleep(REPLICATION_SEC)
	_check("neg_dialogue_choice_out_of_range_ignored", _count_events(&"dialogue_opened", c) == 0
			and _count_events(&"dialogue_closed", c) == 0)
	c = _cursor()
	Net.send_dialogue_choice(0) # -> nó "more"
	var nxt: Dictionary = await _wait_event(&"dialogue_opened", c, SHORT_WAIT_SEC)
	_check("dialogue_next_node", not nxt.is_empty() and nxt["a"][2] == "TEST_DLG_SAGE_MORE")
	c = _cursor()
	Net.send_dialogue_choice(0) # opção sem next_node -> fecha
	_check("dialogue_option_without_next_closes",
			not (await _wait_event(&"dialogue_closed", c, SHORT_WAIT_SEC)).is_empty())


func _test_wander_npc() -> void:
	var w: NetEntity = _find_npc(func(d: NpcDef) -> bool:
		return d.routine == NpcDef.Routine.WANDER and d.dialogue != null)
	if w == null:
		_check("wander_npc_exists", false)
		return
	var start: Vector3 = w.net_position
	var moved: bool = await _wait_until(func() -> bool:
		return w.net_position.distance_to(start) >= WANDER_MIN_MOVE, WANDER_OBSERVE_SEC)
	_check("wander_npc_moves", moved, {"npc": String(w.def_id),
			"moved": snappedf(w.net_position.distance_to(start), 0.01)})
	var ev: Dictionary = await _talk_to(w)
	if not _check("wander_dialogue_opened", not ev.is_empty()):
		return
	await _sleep(REPLICATION_SEC)
	var p0: Vector3 = w.net_position
	await _sleep(STOP_OBSERVE_SEC)
	var p1: Vector3 = w.net_position
	var to_me := Vector3(_local.net_position.x - p1.x, 0.0, _local.net_position.z - p1.z)
	var want_yaw: float = atan2(-to_me.x, -to_me.z)
	var yaw_err: float = absf(angle_difference(w.facing_yaw, want_yaw))
	_check("wander_npc_stops_while_talking", p0.distance_to(p1) < STOP_EPSILON
			and w.anim != NetEntity.ANIM_WALK, {"drift": p0.distance_to(p1), "anim": String(w.anim)})
	_check("npc_faces_player_while_talking", yaw_err < FACING_TOLERANCE, {"yaw_err": yaw_err})
	await _close_dialogue_if_open()


func _test_merchant_and_items() -> void:
	var m: NetEntity = _find_npc(func(d: NpcDef) -> bool:
		return d.shop != null and _dialogue_has_action(d, &"open_shop"))
	if not _check("merchant_exists", m != null):
		return
	var shop_def: ShopDef = _npc_def(m).shop
	var ev: Dictionary = await _talk_to(m)
	if not _check("merchant_dialogue_opened", not ev.is_empty()):
		return
	var c: int = await _navigate_to_action(m, ev, &"open_shop")
	var shop_ev: Dictionary = await _wait_event(&"shop_opened", maxi(c, 0), SHORT_WAIT_SEC)
	var closed_dialogue: bool = _count_events(&"dialogue_closed", maxi(c, 0)) > 0
	if not _check("shop_opened_via_dialogue", c >= 0 and not shop_ev.is_empty() and closed_dialogue
			and shop_ev["a"][0] == shop_def.id, shop_ev.get("a", [])):
		return
	# --- comprar poção
	var potion: ItemDef = Content.item(POTION)
	var stars0: int = Net.client_stars
	var count0: int = _count(POTION)
	c = _cursor()
	Net.send_shop_buy(POTION, 1)
	await _wait_event(&"currency", c, SHORT_WAIT_SEC)
	await _wait_until(func() -> bool: return _count(POTION) == count0 + 1, SHORT_WAIT_SEC)
	_check("buy_potion", Net.client_stars == stars0 - potion.buy_price and _count(POTION) == count0 + 1,
			{"stars": Net.client_stars, "potions": _count(POTION)})
	# --- usar poção (GDD §8.1/§11.3, 28/09/2026: poções são instantâneas e sem recarga)
	c = _cursor()
	Net.send_use_item(_slot_of(POTION))
	await _wait_event(&"inventory", c, SHORT_WAIT_SEC)
	_check("use_potion", _count(POTION) == count0, {"potions": _count(POTION)})
	# Outra logo em seguida (antes valia a recarga compartilhada de 10 s): aceita na hora.
	Net.send_shop_buy(POTION, 1)
	await _wait_until(func() -> bool: return _count(POTION) == count0 + 1, SHORT_WAIT_SEC)
	c = _cursor()
	Net.send_use_item(_slot_of(POTION))
	await _wait_until(func() -> bool: return _count(POTION) == count0, SHORT_WAIT_SEC)
	_check("potion_instant_no_cooldown", _count(POTION) == count0
			and not await _wait_sys(SysMsg.ITEM_ON_COOLDOWN, c, 0.5), {"potions": _count(POTION)})
	# --- comprar sem dinheiro
	var machete: ItemDef = Content.item(MACHETE)
	stars0 = Net.client_stars
	c = _cursor()
	Net.send_shop_buy(MACHETE, OVERSPEND_QTY)
	_check("neg_buy_without_money", await _wait_sys(SysMsg.NOT_ENOUGH_STARS, c)
			and Net.client_stars == stars0 and _count(MACHETE) == 0)
	c = _cursor()
	Net.send_shop_buy(&"spinning_leaf_not_in_shop", 1)
	_check("neg_buy_item_not_in_shop", await _wait_sys(SysMsg.ITEM_NOT_SOLD_HERE, c))
	# --- comprar e equipar o facão
	c = _cursor()
	Net.send_shop_buy(MACHETE, 1)
	await _wait_until(func() -> bool: return _count(MACHETE) == 1, SHORT_WAIT_SEC)
	_check("buy_machete", _count(MACHETE) == 1 and Net.client_stars == stars0 - machete.buy_price)
	var atk0: int = _stat(&"atk")
	c = _cursor()
	Net.send_equip(_slot_of(MACHETE))
	await _wait_event(&"equipment", c, SHORT_WAIT_SEC)
	await _wait_event(&"stats", c, SHORT_WAIT_SEC)
	_check("equip_machete", Net.client_equipment.get(&"weapon") == MACHETE and _count(MACHETE) == 0,
			Net.client_equipment)
	_check("equip_changes_stats", _stat(&"atk") == atk0 + int(machete.stats.get(&"atk", 0)),
			{"atk_before": atk0, "atk_after": _stat(&"atk")})
	await _sleep(REPLICATION_SEC)
	if _visual(MACHETE).is_empty():
		_skip("appearance_weapon_self", "machete.visual_id is empty in data (C)")
	else:
		_check("appearance_weapon_self", _local.appearance.get(&"weapon") == _visual(MACHETE),
				_local.appearance)
	Net.send_chat(&"local", MARK_WEAPON)
	await _sleep(CHAT_GAP_SEC)
	# --- vender poções
	stars0 = Net.client_stars
	var n: int = _count(POTION)
	var potion_stacks: Array[Dictionary] = []
	for slot: int in range(_inv().size()):
		var stack: Dictionary = _inv()[slot]
		if stack.get("item", &"") == POTION:
			potion_stacks.append({"slot": slot, "qty": int(stack["qty"])})
	for stack: Dictionary in potion_stacks:
		c = _cursor()
		Net.send_shop_sell(int(stack["slot"]), int(stack["qty"]))
		await _wait_event(&"currency", c, SHORT_WAIT_SEC)
		await _wait_event(&"inventory", c, SHORT_WAIT_SEC)
	_check("sell_potions", Net.client_stars == stars0 + potion.sell_price * n and _count(POTION) == 0,
			{"stars": Net.client_stars, "sold": n})
	# --- vender espaço vazio / quantidade maior que a pilha
	stars0 = Net.client_stars
	c = _cursor()
	Net.send_shop_sell(_first_empty_slot(), 1)
	Net.send_shop_sell(-1, 1)
	await _sleep(REPLICATION_SEC)
	_check("neg_sell_unowned_slot", _count_events(&"currency", c) == 0 and Net.client_stars == stars0)
	# --- desequipar (volta ao inventário, atributos voltam) e vender o facão
	c = _cursor()
	Net.send_unequip(&"weapon")
	await _wait_event(&"equipment", c, SHORT_WAIT_SEC)
	await _wait_event(&"stats", c, SHORT_WAIT_SEC)
	_check("unequip_machete", StringName(Net.client_equipment.get(&"weapon")).is_empty()
			and _count(MACHETE) == 1 and _stat(&"atk") == atk0)
	c = _cursor()
	Net.send_shop_sell(_slot_of(MACHETE), 1)
	await _wait_event(&"currency", c, SHORT_WAIT_SEC)
	_check("sell_machete", _count(MACHETE) == 0 and Net.client_stars == stars0 + machete.sell_price)
	# --- chapéu: comprar, mover no inventário, equipar
	var hat: ItemDef = Content.item(HAT)
	if hat == null or not (HAT in shop_def.items) or Net.client_stars < hat.buy_price:
		_skip("buy_equip_hat", "straw_hat unavailable/unaffordable")
	else:
		c = _cursor()
		Net.send_shop_buy(HAT, 1)
		await _wait_until(func() -> bool: return _count(HAT) == 1, SHORT_WAIT_SEC)
		var from: int = _slot_of(HAT)
		c = _cursor()
		Net.send_inventory_move(from, INVENTORY_MOVE_TARGET_SLOT)
		await _wait_event(&"inventory", c, SHORT_WAIT_SEC)
		_check("inventory_move", _slot_of(HAT) == INVENTORY_MOVE_TARGET_SLOT
				and (_inv()[from] as Dictionary).is_empty(), {"from": from})
		c = _cursor()
		Net.send_equip(INVENTORY_MOVE_TARGET_SLOT)
		await _wait_event(&"equipment", c, SHORT_WAIT_SEC)
		_check("equip_hat", Net.client_equipment.get(&"head") == HAT)
	# --- fechar a loja (extra send_shop_close)
	c = _cursor()
	Net.send_shop_close()
	_check("shop_close", not (await _wait_event(&"shop_closed", c, SHORT_WAIT_SEC)).is_empty())
	c = _cursor()
	Net.send_shop_buy(POTION, 1)
	_check("neg_buy_after_shop_closed", await _wait_sys(SysMsg.SHOP_NOT_OPEN, c))


func _test_gift_and_cosmetic() -> void:
	var g: NetEntity = _find_npc(func(d: NpcDef) -> bool: return _dialogue_has_action(d, &"give_item"))
	if not _check("gifter_exists", g != null):
		return
	var ev: Dictionary = await _talk_to(g)
	if not _check("gifter_dialogue_opened", not ev.is_empty()):
		return
	var c: int = await _navigate_to_action(g, ev, &"give_item")
	await _wait_until(func() -> bool: return _count(CROWN) == 1, SHORT_WAIT_SEC)
	_check("give_item_crown", c >= 0 and _count(CROWN) == 1)
	await _close_dialogue_if_open()
	# once: falando de novo, a opção de presente não aparece mais.
	ev = await _talk_to(g)
	var again: int = -1
	if not ev.is_empty():
		again = await _navigate_to_action(g, ev, &"give_item")
	await _sleep(REPLICATION_SEC)
	_check("give_item_once", not ev.is_empty() and again < 0 and _count(CROWN) == 1)
	await _close_dialogue_if_open()
	# cosmético: vai em cosmetic_head, não muda atributos, sobrepõe o chapéu na aparência.
	var stats0: Dictionary = Net.client_stats.duplicate()
	c = _cursor()
	Net.send_equip(_slot_of(CROWN))
	await _wait_event(&"equipment", c, SHORT_WAIT_SEC)
	await _sleep(REPLICATION_SEC)
	_check("equip_cosmetic_slot", Net.client_equipment.get(&"cosmetic_head") == CROWN
			and (Net.client_equipment.get(&"head") == HAT or Content.item(HAT) == null),
			Net.client_equipment)
	_check("cosmetic_no_stats", Net.client_stats == stats0)
	_check("appearance_cosmetic_overrides_head", _local.appearance.get(&"head") == _visual(CROWN),
			_local.appearance)
	# tirar a coroa mostra o chapéu de novo; depois recoloca (estado final para o observer).
	c = _cursor()
	Net.send_unequip(&"cosmetic_head")
	await _wait_event(&"equipment", c, SHORT_WAIT_SEC)
	await _sleep(REPLICATION_SEC)
	_check("appearance_head_after_cosmetic_removed",
			_local.appearance.get(&"head") == _visual(HAT), _local.appearance)
	c = _cursor()
	Net.send_equip(_slot_of(CROWN))
	await _wait_event(&"equipment", c, SHORT_WAIT_SEC)


func _test_chat_and_emotes() -> void:
	await _sleep(CHAT_GAP_SEC)
	var c: int = _cursor()
	Net.send_chat(&"local", CHAT_HELLO)
	Net.send_chat(&"local", CHAT_HELLO + " (spam)")
	var echo: Dictionary = await _wait_event(&"chat", c, SHORT_WAIT_SEC,
			func(a: Array) -> bool: return a[2] == CHAT_HELLO and a[3] == _local.entity_id)
	_check("chat_local_echo", not echo.is_empty() and echo["a"][0] == &"local"
			and echo["a"][1] == _local.display_name)
	_check("neg_chat_spam_rejected", await _wait_sys(SysMsg.CHAT_TOO_FAST, c)
			and _count_events(&"chat", c) == 1)
	await _sleep(CHAT_GAP_SEC)
	c = _cursor()
	Net.send_chat(&"local", CHAT_BANNED)
	var filtered: Dictionary = await _wait_event(&"chat", c, SHORT_WAIT_SEC)
	_check("chat_banned_word_filtered", not filtered.is_empty()
			and not String(filtered["a"][2]).contains(CHAT_BANNED_WORD)
			and String(filtered["a"][2]).contains("*"), filtered.get("a", []))
	await _sleep(CHAT_GAP_SEC)
	c = _cursor()
	Net.send_chat(&"local", "x".repeat(LONG_CHAT_LENGTH))
	_check("neg_chat_too_long", await _wait_sys(SysMsg.CHAT_TOO_LONG, c))
	c = _cursor()
	Net.send_chat(&"whisper", "oi")
	Net.send_emote(&"dance")
	await _sleep(REPLICATION_SEC)
	_check("neg_bad_channel_and_emote_ignored", _count_events(&"chat", c) == 0
			and _count_events(&"emote", c) == 0)
	c = _cursor()
	Net.send_emote(&"wave")
	var em: Dictionary = await _wait_event(&"emote", c, SHORT_WAIT_SEC)
	_check("emote_wave", not em.is_empty() and em["a"][0] == _local.entity_id and em["a"][1] == &"wave")
	Net.send_emote(&"sit")
	var sat: bool = await _wait_until(func() -> bool: return _local.anim == NetEntity.ANIM_SIT,
			SHORT_WAIT_SEC)
	Net.send_emote(&"sit")
	var stood: bool = await _wait_until(func() -> bool: return _local.anim == NetEntity.ANIM_IDLE,
			SHORT_WAIT_SEC)
	_check("emote_sit_toggles", sat and stood)


func _test_map_objects() -> void:
	var bench: String = _find_interactable(&"sit")
	if bench.is_empty():
		_check("bench_exists", false)
	else:
		var yaw: float = float(InteractionService.meta_get(
				(_map_interactables()[bench] as Dictionary).get("meta", {}), "facing_yaw", 0.0))
		Net.send_interact("m:" + bench)
		var sat: bool = await _wait_until(func() -> bool: return _local.anim == NetEntity.ANIM_SIT,
				WALK_WAIT_SEC)
		await _sleep(REPLICATION_SEC)
		_check("sit_on_bench", sat and absf(angle_difference(_local.facing_yaw, yaw)) < FACING_TOLERANCE,
				{"bench": bench, "yaw": _local.facing_yaw, "want": yaw})
	if _find_interactable(&"portal").is_empty():
		_check("gate_exists", false)
		return
	# Portões com target_map (ex.: portal norte → fields_pindorama) trocam de mapa; o aviso de nível
	# recomendado só vale para os que continuam fechados. Sem nenhum fechado, não há o que checar aqui.
	var gate: String = _find_closed_portal()
	var c: int = _cursor()
	if gate.is_empty():
		_check("portal_recommended_level", true, {"skipped": "todos os portões abertos"})
	else:
		Net.send_interact("m:" + gate)
		_check("portal_recommended_level", await _wait_sys(SysMsg.PORTAL_CLOSED, c, WALK_WAIT_SEC))
	c = _cursor()
	Net.send_interact("m:does_not_exist")
	_check("neg_interact_unknown_object", await _wait_sys(SysMsg.TARGET_INVALID, c))


# ================================================================ observer

func _run_observer() -> void:
	var shopper_id: int = 0
	var weapon_seen: Variant = null
	var mark: Dictionary = await _wait_event(&"chat", 0, OBSERVER_TIMEOUT_SEC,
			func(a: Array) -> bool: return a[2] == MARK_WEAPON)
	if not mark.is_empty():
		shopper_id = mark["a"][3]
		await _sleep(REPLICATION_SEC)
		var sh: NetEntity = _entity(shopper_id)
		weapon_seen = sh.appearance.get(&"weapon") if sh != null else null
		if _visual(MACHETE).is_empty():
			_skip("observer_sees_weapon_appearance", "machete.visual_id is empty in data (C)")
		else:
			_check("observer_sees_weapon_appearance", weapon_seen == _visual(MACHETE),
					{"seen": weapon_seen})
	var done: Dictionary = await _wait_event(&"chat", 0, OBSERVER_TIMEOUT_SEC,
			func(a: Array) -> bool: return a[2] == MARK_DONE)
	if not _check("observer_got_done_marker", not done.is_empty()):
		return
	shopper_id = done["a"][3]
	var shopper: NetEntity = _entity(shopper_id)
	_check("observer_sees_cosmetic_head", shopper != null
			and shopper.appearance.get(&"head") == _visual(CROWN),
			shopper.appearance if shopper != null else null)
	var hello: bool = false
	var masked: bool = false
	for e: Dictionary in _events:
		if e["t"] == &"chat" and e["a"][3] == shopper_id:
			hello = hello or e["a"][2] == CHAT_HELLO
			masked = masked or (String(e["a"][2]).contains("*")
					and not String(e["a"][2]).contains(CHAT_BANNED_WORD))
	_check("observer_receives_chat", hello)
	_check("observer_receives_filtered_chat", masked)
	var wave: bool = false
	for e: Dictionary in _events:
		if e["t"] == &"emote" and e["a"][0] == shopper_id and e["a"][1] == &"wave":
			wave = true
	_check("observer_receives_emote", wave)
	# Privacidade: só o próprio estado inicial (1 evento de cada), nunca o do shopper.
	var foreign_item: bool = false
	for e: Dictionary in _events:
		if e["t"] == &"inventory":
			for s: Variant in e["a"][0]:
				if s is Dictionary and s.get("item", &"") in [MACHETE, HAT, CROWN]:
					foreign_item = true
	_check("observer_no_foreign_inventory", _count_events(&"inventory") == 1 and not foreign_item
			and _count_events(&"currency") == 1 and Net.client_stars == CharacterData.STARTING_STARS
			and _count_events(&"equipment") == 1,
			{"inventory_events": _count_events(&"inventory"),
			"currency_events": _count_events(&"currency"), "foreign_item": foreign_item})
	_check("observer_no_foreign_dialogue_or_shop", _count_events(&"dialogue_opened") == 0
			and _count_events(&"shop_opened") == 0 and _count_events(&"system") == 0)


# ================================================================ capturas em janela (xvfb)

var _shot_index: int = 0


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%02d_%s.png" % [dir, _role, _shot_index, label]
	_shot_index += 1
	img.save_png(path)
	var view: ClientView = main_node.get("client_view") as ClientView
	Net.log_line("autotest_shot", {"file": path, "t": snappedf(NetClock.server_now_msec(), 0.01),
			"pos": str(_local.position), "marker": view.is_marker_visible() if view != null else false,
			"marker_pos": str(view.get_marker_position()) if view != null else ""})


func _window_pos(view: ClientView, world: Vector3) -> Vector2:
	var internal: Vector2 = view.get_camera().unproject_position(world)
	return internal * view.get_view_scale() + view.get_view_offset()


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)


func _mouse_move(pos: Vector2, held: bool) -> void:
	Input.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(ev)


## Clique de verdade no chão (passa pelo ClientView: encaixe na célula, marcador, move_requested).
func _click_world(world: Vector3) -> void:
	var view: ClientView = main_node.get("client_view") as ClientView
	var p: Vector2 = _window_pos(view, world)
	_mouse_move(p, false)
	await get_tree().process_frame
	_mouse_button(p, true)
	await get_tree().process_frame
	_mouse_button(p, false)


func _walk_and_shoot(label: String) -> void:
	await _sleep(SHOT_INTERVAL_SEC)
	var i: int = 0
	while true:
		var path: MovePath = _local.get_client_path()
		var moving: bool = path != null and path.is_moving_at(NetClock.server_now_msec())
		await _shot("%s_%d" % [label, i])
		i += 1
		if not moving:
			break
		await _sleep(SHOT_INTERVAL_SEC)


func _run_walkshot() -> void:
	var view: ClientView = main_node.get("client_view") as ClientView
	await _wait_until(func() -> bool: return view.get_walk_grid() != null and NetClock.synced,
			SHORT_WAIT_SEC)
	_trace_players(WALKSHOT_TRACE_SEC)
	await _shot("start")
	await _click_world(_local.net_position + WALK_DIAGONAL)
	await _walk_and_shoot("diagonal")
	await _click_world(_local.net_position + WALK_STRAIGHT)
	await _walk_and_shoot("straight")
	# Segurar o botão: o cursor gira em volta do jogador e ele segue.
	var center: Vector3 = _local.net_position
	var p0: Vector2 = _window_pos(view, center + Vector3(0.0, 0.0, -HOLD_RADIUS))
	_mouse_move(p0, false)
	await get_tree().process_frame
	_mouse_button(p0, true)
	for k: int in range(HOLD_STEPS):
		var ang: float = PI * float(k) / float(HOLD_STEPS)
		var w: Vector3 = center + Vector3(sin(ang) * HOLD_RADIUS, 0.0, -cos(ang) * HOLD_RADIUS)
		_mouse_move(_window_pos(view, w), true)
		await _sleep(HOLD_STEP_SEC)
		if k % 3 == 0:
			await _shot("hold_%d" % k)
	_mouse_button(_window_pos(view, center), false)
	await _walk_and_shoot("hold_end")
	_check("walkshot_moved", _local.net_position.distance_to(center) > MIN_MOVE,
			{"pos": str(_local.net_position)})
	Net.send_chat(&"local", MARK_WALKSHOT_DONE)
	await _sleep(LINGER_SEC)


func _run_watcher() -> void:
	_trace_players(WATCHER_TIMEOUT_SEC)
	var deadline: float = NetClock.local_now_msec() + WATCHER_TIMEOUT_SEC * MSEC_PER_SEC
	var i: int = 0
	while NetClock.local_now_msec() < deadline:
		var done: bool = false
		for e: Dictionary in _events:
			if e["t"] == &"chat" and e["a"][2] == MARK_WALKSHOT_DONE:
				done = true
		if done:
			break
		var other: NetEntity = _other_player()
		var path: MovePath = other.get_client_path() if other != null else null
		if path != null and path.is_moving_at(NetClock.server_now_msec()):
			await _shot("remote_%d" % i)
			i += 1
		await _sleep(WATCH_SHOT_INTERVAL_SEC)
	_check("watcher_saw_remote_walk", i > 0, {"shots": i})


# ================================================================ fim

func _finish() -> void:
	var failed: Array = []
	for k: String in _checks:
		if _checks[k] == "FAIL":
			failed.append(k)
	var ok: bool = failed.is_empty() and not _checks.is_empty()
	Net.log_line("autotest_result", {"pass": ok, "role": _role, "checks": _checks.size(),
			"failed": failed})
	await _sleep(LINGER_SEC)
	get_tree().quit(0 if ok else 1)


func _finish_rejected() -> void:
	Net.log_line("autotest_result", {"pass": _entities().is_empty(), "role": "bad_protocol",
			"test": "protocol_mismatch_rejected"})
	get_tree().quit()
