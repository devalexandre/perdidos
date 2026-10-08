extends RefCounted
## Dados de teste descartáveis (só com --test-fixtures, servidor e cliente). Completam o que
## ainda não existe em data/ (regra: nunca sobrescrevem um id real) para o autoteste rodar
## antes de C terminar o conteúdo, e sempre adicionam o NPC "test_sage" (condições de diálogo).
## Também criam, se faltarem no mapa, marcadores de NPC (NpcPoints) e objetos interativos.

const MAP_ID: StringName = &"city_awakening"
const SAGE_ID: StringName = &"test_sage"
const MERCHANT_ID: StringName = &"test_merchant"
const WANDERER_ID: StringName = &"test_wanderer"
const GIFTER_ID: StringName = &"test_gifter"
const CROWN_ID: StringName = &"ipe_flower_crown"
const MISSING_ITEM_ID: StringName = &"test_item_nobody_has"
## Marcadores de teste: anel em volta do SpawnPoint (m).
const MARKER_RING_RADIUS: float = 7.0
const PATROL_OFFSET: Vector3 = Vector3(3.0, 0.0, 0.0)
const BENCH_OFFSET: Vector3 = Vector3(-4.0, 0.0, 2.0)
const GATE_OFFSET: Vector3 = Vector3(4.0, 0.0, 2.0)
const BENCH_YAW: float = PI / 2.0
const GATE_LEVEL: String = "1-10"
const CLICK_LAYER: int = 2
const OBJECT_SIZE: Vector3 = Vector3(1.0, 1.0, 1.0)
const SNAP_TOLERANCE: float = 20.0


static func _item(id: StringName, type: ItemDef.ItemType, buy: int, sell: int) -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	d.name_key = "TEST_ITEM_%s" % String(id).to_upper()
	d.type = type
	d.buy_price = buy
	d.sell_price = sell
	return d


static func _opt(text_key: String, next_node: StringName = &"", action: StringName = &"",
		conditions: Dictionary[StringName, Variant] = {},
		action_args: Dictionary[StringName, Variant] = {}) -> DialogueOption:
	var o := DialogueOption.new()
	o.text_key = text_key
	o.next_node = next_node
	o.action = action
	o.conditions = conditions
	o.action_args = action_args
	return o


static func _node(id: StringName, text_key: String, options: Array[DialogueOption]) -> DialogueNode:
	var n := DialogueNode.new()
	n.id = id
	n.text_key = text_key
	n.options = options
	return n


static func _dialogue(id: StringName, nodes: Array[DialogueNode]) -> DialogueDef:
	var d := DialogueDef.new()
	d.id = id
	d.nodes = nodes
	return d


static func _npc(id: StringName, routine: NpcDef.Routine, dialogue: DialogueDef,
		shop: ShopDef = null) -> NpcDef:
	var n := NpcDef.new()
	n.id = id
	n.name_key = "TEST_NPC_%s" % String(id).to_upper()
	n.sprite_base = "res://assets/npcs/npc_merchant"
	n.map_id = MAP_ID
	n.spawn_marker = id
	n.routine = routine
	n.dialogue = dialogue
	n.shop = shop
	return n


static func _add(kind: StringName, id: StringName, res: Resource) -> void:
	var db: Dictionary = Content.all(kind)
	if not db.has(id):
		db[id] = res
		print("[fixtures] registered %s/%s" % [kind, id])


static func _any_npc(pred: Callable) -> bool:
	for d: Resource in Content.all(&"npcs").values():
		if d is NpcDef and pred.call(d):
			return true
	return false


static func _has_option_action(def: NpcDef, action: StringName) -> bool:
	if def.dialogue == null:
		return false
	for n: DialogueNode in def.dialogue.nodes:
		for o: DialogueOption in n.options:
			if o.action == action:
				return true
	return false


## Content: completa itens/loja/NPCs que faltam. (Content.all() devolve o dicionário interno.)
static func install_content() -> void:
	var potion := _item(&"potion_hp_small", ItemDef.ItemType.CONSUMABLE, 15, 5)
	potion.stackable = true
	potion.max_stack = 99
	potion.use_effect = {&"heal_hp": 60, &"cooldown_group": &"potion"}
	_add(&"items", potion.id, potion)
	var machete := _item(&"machete", ItemDef.ItemType.WEAPON, 60, 20)
	machete.stats = {&"atk": 8}
	machete.visual_id = &"blade"
	_add(&"items", machete.id, machete)
	var hat := _item(&"straw_hat", ItemDef.ItemType.HEAD, 40, 12)
	hat.stats = {&"def": 1}
	hat.visual_id = &"straw_hat"
	_add(&"items", hat.id, hat)
	var crown := _item(CROWN_ID, ItemDef.ItemType.HEAD, 0, 0)
	crown.is_cosmetic = true
	crown.visual_id = CROWN_ID
	_add(&"items", crown.id, crown)
	var shop := ShopDef.new()
	shop.id = &"market"
	shop.items = [&"potion_hp_small", &"machete", &"straw_hat"]
	_add(&"shops", shop.id, shop)
	var market: ShopDef = Content.shop(&"market")
	# NPC com condições (sempre): min_level 5 e item inexistente escondidos; has_item poção visível.
	var sage_dlg := _dialogue(SAGE_ID, [
		_node(&"start", "TEST_DLG_SAGE_START", [
			_opt("TEST_OPT_SAGE_SECRET", &"more", &"", {&"min_level": 5}),
			_opt("TEST_OPT_SAGE_POTION", &"more", &"", {&"has_item": &"potion_hp_small"}),
			_opt("TEST_OPT_SAGE_MISSING", &"more", &"", {&"has_item": MISSING_ITEM_ID}),
			_opt("TEST_OPT_SAGE_BYE", &"", &"close"),
		]),
		_node(&"more", "TEST_DLG_SAGE_MORE", [_opt("TEST_OPT_SAGE_BYE")]),
	])
	_add(&"dialogues", sage_dlg.id, sage_dlg)
	_add(&"npcs", SAGE_ID, _npc(SAGE_ID, NpcDef.Routine.SIT, sage_dlg))
	if not _any_npc(func(d: NpcDef) -> bool: return d.shop != null \
			and _has_option_action(d, &"open_shop")):
		var dlg := _dialogue(MERCHANT_ID, [_node(&"start", "TEST_DLG_MERCHANT", [
			_opt("TEST_OPT_SHOP", &"", &"open_shop"), _opt("TEST_OPT_BYE", &"", &"close")])])
		_add(&"dialogues", dlg.id, dlg)
		_add(&"npcs", MERCHANT_ID, _npc(MERCHANT_ID, NpcDef.Routine.IDLE, dlg, market))
	if not _any_npc(func(d: NpcDef) -> bool: return d.routine == NpcDef.Routine.WANDER \
			and d.dialogue != null):
		var dlg2 := _dialogue(WANDERER_ID, [_node(&"start", "TEST_DLG_WANDERER", [
			_opt("TEST_OPT_BYE", &"", &"close")])])
		_add(&"dialogues", dlg2.id, dlg2)
		var w := _npc(WANDERER_ID, NpcDef.Routine.WANDER, dlg2)
		w.wander_radius = 4.0
		_add(&"npcs", WANDERER_ID, w)
	if not _any_npc(func(d: NpcDef) -> bool: return _has_option_action(d, &"give_item")):
		var dlg3 := _dialogue(GIFTER_ID, [_node(&"start", "TEST_DLG_GIFTER", [
			_opt("TEST_OPT_GIFT", &"thanks", &"give_item", {},
					{&"item_id": CROWN_ID, &"qty": 1, &"once": true}),
			_opt("TEST_OPT_BYE", &"", &"close")]),
			_node(&"thanks", "TEST_DLG_GIFTER_THANKS", [_opt("TEST_OPT_BYE")])])
		_add(&"dialogues", dlg3.id, dlg3)
		_add(&"npcs", GIFTER_ID, _npc(GIFTER_ID, NpcDef.Routine.IDLE, dlg3))


static func _spawn_point(map_node: Node) -> Vector3:
	if map_node.has_method("get_spawn_point"):
		return map_node.call("get_spawn_point")
	return Vector3.ZERO


static func _snap(nav: RID, p: Vector3) -> Vector3:
	if not nav.is_valid() or NavigationServer3D.map_get_iteration_id(nav) == 0:
		return p
	var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, p)
	return c if c.distance_to(p) <= SNAP_TOLERANCE else p


static func _add_marker(parent: Node, marker_name: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	parent.add_child(m)
	m.global_position = pos
	print("[fixtures] test marker %s at %s" % [marker_name, pos])


## Servidor: cria em NpcPoints os marcadores que faltam (anel em volta do SpawnPoint).
static func ensure_npc_markers(map_node: Node, defs: Array[NpcDef], nav: RID) -> void:
	var points: Node = map_node.get_node_or_null("NpcPoints")
	if points == null:
		points = Node3D.new()
		points.name = "NpcPoints"
		map_node.add_child(points)
	var center: Vector3 = _spawn_point(map_node)
	var missing: Array[NpcDef] = []
	for d: NpcDef in defs:
		if points.get_node_or_null(String(d.spawn_marker)) == null:
			missing.append(d)
	for i: int in range(missing.size()):
		var d: NpcDef = missing[i]
		var angle: float = TAU * float(i) / float(maxi(missing.size(), 1))
		var pos: Vector3 = _snap(nav, center + Vector3(cos(angle), 0.0, sin(angle)) * MARKER_RING_RADIUS)
		_add_marker(points, String(d.spawn_marker), pos)
		var k: int = 0
		for pm: StringName in d.patrol_markers:
			k += 1
			if points.get_node_or_null(String(pm)) == null:
				_add_marker(points, String(pm), _snap(nav, pos + PATROL_OFFSET * float(k)))


## Servidor e cliente: se o mapa ainda não tem objetos interativos, cria um banco e um portão.
static func install_map(map_node: Node) -> void:
	if map_node.has_method("get_interactables") or map_node.get_node_or_null("Interactables") != null:
		return
	var root := Node3D.new()
	root.name = "Interactables"
	map_node.add_child(root)
	var center: Vector3 = _spawn_point(map_node)
	_add_object(root, "test_bench", &"sit", center + BENCH_OFFSET, {"facing_yaw": BENCH_YAW})
	_add_object(root, "test_gate", &"portal", center + GATE_OFFSET,
			{"target_map": &"fields_pindorama", "recommended_level": GATE_LEVEL})


static func _add_object(root: Node, id: String, type: StringName, pos: Vector3,
		extra: Dictionary) -> void:
	var a := Area3D.new()
	a.name = id
	a.collision_layer = CLICK_LAYER
	a.collision_mask = 0
	a.set_meta("interact_id", id)
	a.set_meta("interact_type", type)
	for k: String in extra:
		a.set_meta(k, extra[k])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = OBJECT_SIZE
	shape.shape = box
	a.add_child(shape)
	root.add_child(a)
	a.global_position = pos
	print("[fixtures] test interactable %s (%s) at %s" % [id, type, pos])
