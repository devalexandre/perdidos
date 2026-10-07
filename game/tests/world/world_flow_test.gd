extends Node
## Autoteste do fluxo de chegada (Agente N; contrato arrival, testes "N"). Criado pelo main.gd com
## --autotest --autotest-script=res://tests/world/world_flow_test.gd. Papéis (--autotest-role):
##   newbie  — personagem novo com aparência personalizada: entra no training_field, ganha itens do
##             treino (comandos de teste), equipa um, chega ao nível 10 (XP travada), morre e renasce
##             no acampamento, tenta o portal sem título (recusado), ganha o título, atravessa o
##             portal e chega à cidade SEM os itens do treino (com o kit inicial). Fotos do minimapa,
##             do mapa grande e da cidade com --shot-dir.
##   veteran — save antigo (sem left_training): entra direto na cidade e vê o newbie chegar com a
##             aparência personalizada (appearance replicado + camadas Hair/FaceAccessory no visual).
##   relog   — o newbie de novo: entra direto na cidade, nível e itens preservados.
## Imprime "autotest_check {...}" e "autotest_result {"pass": ...}"; código 0 = passou.
## O servidor precisa de --autotest --training-flow --world-debug (tests/world/run_world_test.sh).

const ROLE_NEWBIE: String = "newbie"
const ROLE_VETERAN: String = "veteran"
const ROLE_RELOG: String = "relog"
const ARG_ROLE: String = "autotest-role"
const ARG_SHOT_DIR: String = "shot-dir"
const ARG_WATCH_NAME: String = "watch-name"

const TRAINING: StringName = &"training_field"
const CITY: StringName = &"city_awakening"
const STAFF: StringName = &"wooden_staff"
const POTION: StringName = &"potion_hp_small"
const TRAINING_POTIONS: int = 3
var STARTING_POTIONS: int = CharacterData.STARTING_ITEMS[&"potion_hp_small"]  # kit inicial
const LEVEL_CAP: int = 10
## XP de teste: bem mais do que o necessário para o nível 10 (o teto da zona segura no 10).
const XP_GRANTS: int = 30
const XP_PER_GRANT: int = 5000
const DEBUG_TITLE_FALLBACK: StringName = &"debug_initial_title"
const EXPECT_APPEARANCE: Dictionary = {&"skin": 3, &"hair_style": &"bob", &"hair_color": 4,
		&"eye_color": 2, &"earrings": &"hoop"}
const MSG_NEED_TITLE: String = "SYS_WORLD_PORTAL_NEED_TITLE"
const MSG_RESPAWNED: String = "WORLD_RESPAWNED"
const MSG_LEFT: String = "WORLD_TRAINING_LEFT"
const PORTAL_TYPE: StringName = &"portal"

const SETTLE_SEC: float = 2.0
const SHORT_SEC: float = 5.0
const WALK_SEC: float = 60.0
const RESPAWN_SEC: float = 8.0
const TRANSFER_SEC: float = 15.0
const WATCH_SEC: float = 140.0
const LINGER_SEC: float = 12.0
const POLL_SEC: float = 0.1

var main_node: Node = null
var args: Dictionary[String, String] = {}

var _role: String = ROLE_NEWBIE
var _checks: Dictionary = {}
var _maps: Array[StringName] = []
var _system: Array[String] = []
var _local: NetEntity = null
var _started: bool = false
var _shot_index: int = 0


func _ready() -> void:
	_role = args.get(ARG_ROLE, ROLE_NEWBIE)
	Net.enter_instance_requested.connect(func(_i: StringName, m: StringName) -> void: _maps.append(m))
	Net.system_message.connect(func(k: String, _a: Array) -> void:
		_system.append(k)
		Net.log_line("world_test_system", {"key": k}))
	Net.local_player_spawned.connect(_on_local_player_spawned)


func _on_local_player_spawned(player: Node3D) -> void:
	_local = player as NetEntity
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC)
	match _role:
		ROLE_NEWBIE:
			await _run_newbie()
		ROLE_VETERAN:
			await _run_veteran()
		ROLE_RELOG:
			await _run_relog()
	_finish()


# ================================================================ papéis

func _run_newbie() -> void:
	var has_training: bool = ResourceLoader.exists("res://scenes/maps/training_field.tscn")
	if has_training:
		_check("new_character_enters_training", _maps.size() > 0 and _maps[0] == TRAINING, _maps)
	else:
		_skip("new_character_enters_training", "scenes/maps/training_field.tscn ainda não existe")
	await _shot("arrival_minimap")
	var mm: Minimap = _minimap()
	_check("minimap_present", mm != null)
	if mm != null:
		_check("minimap_has_map", await _wait_until(func() -> bool:
			return mm.data != null and mm.data.texture != null, SHORT_SEC * 2.0), mm.data)
		mm.toggle_world_map()
		await _shot("world_map")
		mm.toggle_world_map()
	# Itens obtidos no treino (marcados) + um equipado.
	NetWorld.send_debug(&"give_item", [String(STAFF), 1])
	NetWorld.send_debug(&"give_item", [String(POTION), TRAINING_POTIONS])
	var got: bool = await _wait_until(func() -> bool: return _count(STAFF) == 1, SHORT_SEC)
	_check("training_items_received", got and _count(POTION) == STARTING_POTIONS + TRAINING_POTIONS,
			Net.client_inventory.filter(func(s: Variant) -> bool: return not (s as Dictionary).is_empty()))
	Net.send_equip(_slot_of(STAFF))
	_check("training_item_equipped", await _wait_until(func() -> bool:
		return Net.client_equipment.get(&"weapon", &"") == STAFF, SHORT_SEC), Net.client_equipment)
	# Teto de XP (o servidor registra xp_allowed=false no nível 10).
	NetWorld.send_debug(&"grant_xp", [XP_GRANTS, XP_PER_GRANT])
	_check("level_cap_reached", await _wait_until(func() -> bool:
		return int(Net.client_stats.get(&"level", 0)) == LEVEL_CAP, SHORT_SEC), Net.client_stats)
	# Morte no treino: renasce no acampamento (sem Marca da Alma).
	var mark: int = _system.size()
	NetWorld.send_debug(&"die", [])
	_check("death_respawns_at_camp", await _wait_system(MSG_RESPAWNED, mark, RESPAWN_SEC), _system)
	# Portal sem título: recusado.
	var portal: String = _portal_id()
	if not _check("exit_portal_found", not portal.is_empty(), portal):
		return
	mark = _system.size()
	Net.send_interact("m:" + portal)
	_check("portal_refused_without_title", await _wait_system(MSG_NEED_TITLE, mark, WALK_SEC), _system)
	_check("still_in_training_after_refusal", _maps.size() == 1, _maps)
	# Com o título inicial: atravessa e chega à cidade sem os itens do treino.
	NetWorld.send_debug(&"grant_title", [String(_initial_title_id())])
	await _wait(SHORT_SEC * 0.2)
	mark = _system.size()
	var maps_before: int = _maps.size()
	Net.send_interact("m:" + portal)
	var moved: bool = await _wait_until(func() -> bool: return _maps.size() > maps_before, WALK_SEC)
	_check("portal_transfers_to_city", moved and _maps.back() == CITY, _maps)
	_check("training_left_message", await _wait_system(MSG_LEFT, mark, SHORT_SEC), _system)
	var spawned: bool = await _wait_until(func() -> bool:
		return is_instance_valid(_local) and _local.is_inside_tree() and _map_id() == CITY, TRANSFER_SEC)
	_check("player_spawned_in_city", spawned, _map_id())
	await _wait(SETTLE_SEC)
	_check("training_items_removed", _count(STAFF) == 0 and _count(POTION) == STARTING_POTIONS,
			Net.client_inventory.filter(func(s: Variant) -> bool: return not (s as Dictionary).is_empty()))
	_check("training_equipment_removed", Net.client_equipment.get(&"weapon", &"") == &"", Net.client_equipment)
	_check("level_kept_after_exit", int(Net.client_stats.get(&"level", 0)) == LEVEL_CAP, Net.client_stats)
	NetWorld.send_debug(&"report", [])
	await _shot("city_minimap")
	await _wait(LINGER_SEC)


func _run_veteran() -> void:
	_check("old_character_enters_city", _maps.size() > 0 and _maps[0] == CITY, _maps)
	var watch: String = args.get(ARG_WATCH_NAME, "")
	if watch.is_empty():
		return
	var other: NetEntity = null
	var t0: int = Time.get_ticks_msec()
	while other == null and Time.get_ticks_msec() - t0 < WATCH_SEC * 1000.0:
		await _wait(POLL_SEC * 5.0)
		other = _find_player(watch)
	if not _check("sees_newbie_in_city", other != null, watch):
		return
	await _wait(SETTLE_SEC)
	var app: Dictionary = other.appearance
	var same: bool = true
	for k: StringName in EXPECT_APPEARANCE:
		same = same and app.has(k) and app[k] == EXPECT_APPEARANCE[k]
	_check("custom_appearance_replicated", same, app)
	var v: DirectionalSprite3D = other.get_visual() as DirectionalSprite3D
	# C3 (GDD §17.0.B): com título, a roupa do título (folha com máscara em outfits/) é o corpo recolorível.
	var outfit_body: bool = CharacterLayers.outfit_has_body(StringName(str(app.get(&"outfit", ""))),
			StringName(str(app.get(&"body", ""))))
	_check("custom_layers_rendered", v != null and v.get_overlay_sprite(&"Hair") != null
			and v.get_overlay_sprite(&"FaceAccessory") != null
			and (v.sprite_base.contains("/base/") or (outfit_body and v.sprite_base.contains("/outfits/"))),
			v.sprite_base if v != null else "no visual")
	# Enquadra o newbie para a foto.
	if _local != null:
		Net.send_move_request(other.net_position + Vector3(1.0, 0.0, 1.0))
	await _wait(SHORT_SEC)
	await _shot("sees_custom_newbie")


func _run_relog() -> void:
	_check("relog_enters_city_directly", _maps.size() > 0 and _maps[0] == CITY, _maps)
	await _wait(SETTLE_SEC)
	_check("relog_level_kept", int(Net.client_stats.get(&"level", 0)) == LEVEL_CAP, Net.client_stats)
	_check("relog_no_training_items", _count(STAFF) == 0 and _count(POTION) == STARTING_POTIONS,
			Net.client_inventory.filter(func(s: Variant) -> bool: return not (s as Dictionary).is_empty()))
	_check("relog_appearance_kept", is_instance_valid(_local) and _local.appearance.get(&"hair_style", &"") == EXPECT_APPEARANCE[&"hair_style"],
			_local.appearance)


# ================================================================ utilidades

func _check(check_name: String, ok: bool, detail: Variant = null) -> bool:
	_checks[check_name] = "pass" if ok else "FAIL"
	Net.log_line("autotest_check", {"role": _role, "check": check_name, "pass": ok, "detail": str(detail)})
	return ok


func _skip(check_name: String, why: String) -> void:
	_checks[check_name] = "skip"
	Net.log_line("autotest_check", {"role": _role, "check": check_name, "skip": why})


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _wait_until(cond: Callable, timeout_sec: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_sec * 1000.0:
		if cond.call():
			return true
		await _wait(POLL_SEC)
	return bool(cond.call())


func _wait_system(key: String, from: int, timeout_sec: float) -> bool:
	return await _wait_until(func() -> bool: return _system.slice(from).has(key), timeout_sec)


func _count(item: StringName) -> int:
	var n: int = 0
	for s: Variant in Net.client_inventory:
		if s is Dictionary and (s as Dictionary).get("item", &"") == item:
			n += int((s as Dictionary).get("qty", 0))
	return n


func _slot_of(item: StringName) -> int:
	for i: int in Net.client_inventory.size():
		var s: Variant = Net.client_inventory[i]
		if s is Dictionary and (s as Dictionary).get("item", &"") == item:
			return i
	return -1


func _map_node() -> Node:
	if _local == null or not is_instance_valid(_local) or _local.get_parent() == null:
		return null
	return _local.get_parent().get_parent().get_node_or_null("Map")


func _map_id() -> StringName:
	var m: Node = _map_node()
	return StringName(str(m.get(&"map_id"))) if m != null else &""


func _portal_id() -> String:
	var m: Node = _map_node()
	var inter: Node = m.get_node_or_null("Interactables") if m != null else null
	if inter == null:
		return ""
	for c: Node in inter.get_children():
		if StringName(str(c.get_meta(&"interact_type", ""))) == PORTAL_TYPE and c.has_meta(&"interact_id"):
			return str(c.get_meta(&"interact_id"))
	return ""


## Um TitleDef com start_map_id (de Q); sem nenhum, um id de teste (o servidor usa a cidade padrão).
func _initial_title_id() -> StringName:
	for def: Resource in Content.all(&"titles").values():
		var t: TitleDef = def as TitleDef
		if t != null and not t.start_map_id.is_empty():
			return t.id
	return DEBUG_TITLE_FALLBACK


func _find_player(player_name: String) -> NetEntity:
	for inst: Node in main_node.get_node("World/Instances").get_children():
		var ents: Node = inst.get_node_or_null("Entities")
		if ents == null:
			continue
		for e: Node in ents.get_children():
			if e is NetEntity and (e as NetEntity).is_player() and (e as NetEntity).display_name == player_name:
				return e as NetEntity
	return null


func _minimap() -> Minimap:
	var view: Node = main_node.get("client_view")
	return view.get_node_or_null("Hud/Minimap") as Minimap if view != null else null


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _wait(SETTLE_SEC)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%02d_%s.png" % [dir, _role, _shot_index, label]
	_shot_index += 1
	img.save_png(path)
	Net.log_line("world_test_shot", {"file": path, "map": String(_map_id())})


func _finish() -> void:
	var ok: bool = not _checks.values().has("FAIL")
	Net.log_line("autotest_result", {"pass": ok, "role": _role, "checks": _checks.size(),
			"failed": _checks.keys().filter(func(k: Variant) -> bool: return _checks[k] == "FAIL")})
	get_tree().quit(0 if ok else 1)
