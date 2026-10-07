class_name CombatAssist
extends Node
## Ações "inteligentes" do jogador sem mouse, compartilhadas pelo toque (MobileControlsOverlay) e pelo
## controle (GamepadInput): andar numa direção de tela (passo em grade, autoritativo no servidor), botão de
## ação (alvo travado → ataca; item/NPC perto → pega/conversa; senão o monstro mais perto), ciclo de alvo,
## poção rápida e re-mira automática quando o alvo morre. Uma instância por GameUI (o alvo é o mesmo).

## O botão de ação fez algo: &"attack", &"pickup", &"talk", &"use" (objeto do mapa: portal, altar…; id -1)
## ou &"target" (entity_id do alvo).
signal action_performed(kind: StringName, entity_id: int)

const WALK_STEP_DISTANCE: float = 1.6
const TARGET_SEARCH_MAX_DIST: float = 16.0
## Raio (m) em que item no chão / NPC tem prioridade sobre monstro no botão de ação.
const INTERACT_PRIORITY_DIST: float = 2.5
## Raio (m) para usar um objeto clicável do mapa (Map.get_interactables: portal, altar, banco…).
const MAP_OBJECT_DIST: float = 3.0
## Direção mínima (comprimento²) que conta como "andando".
const WALK_MIN_LENGTH_SQ: float = 0.02
const NO_TARGET: int = -1

var game_ui: GameUI = null
var client_view: ClientView = null
## Alvo travado (entity_id) ou NO_TARGET.
var current_target: int = NO_TARGET

var _next_move_msec: float = 0.0
var _last_walk_cell: Vector2i = Vector2i(-9999, -9999)


func _init(p_game_ui: GameUI = null) -> void:
	game_ui = p_game_ui
	name = &"CombatAssist"


func _ready() -> void:
	_find_view()
	if NetCombat.has_signal(&"entity_died") and not NetCombat.entity_died.is_connected(on_entity_died):
		NetCombat.entity_died.connect(on_entity_died)
	if NetCombat.has_signal(&"attack_target_changed") \
			and not NetCombat.attack_target_changed.is_connected(on_attack_target_changed):
		NetCombat.attack_target_changed.connect(on_attack_target_changed)


func _exit_tree() -> void:
	if NetCombat.has_signal(&"entity_died") and NetCombat.entity_died.is_connected(on_entity_died):
		NetCombat.entity_died.disconnect(on_entity_died)
	if NetCombat.has_signal(&"attack_target_changed") \
			and NetCombat.attack_target_changed.is_connected(on_attack_target_changed):
		NetCombat.attack_target_changed.disconnect(on_attack_target_changed)
	if client_view != null and is_instance_valid(client_view) \
			and client_view.interact_requested.is_connected(on_world_interact_requested):
		client_view.interact_requested.disconnect(on_world_interact_requested)


func _process(_delta: float) -> void:
	_check_current_target_alive()


## Quem recebe as intenções de interface (o Net do GameUI: autoload ou dublê nos testes).
func _net() -> Object:
	return game_ui.net if game_ui != null and game_ui.net != null and game_ui.net.has_method(&"send_interact") else Net


func progression() -> ProgressionHud:
	return game_ui.progression if game_ui != null and is_instance_valid(game_ui.progression) else null


func _find_view() -> void:
	if client_view != null and is_instance_valid(client_view):
		return
	client_view = null
	if not is_inside_tree():
		return
	# Primeiro subindo a árvore (GameUI vive no Hud do ClientView), depois na cena atual.
	var n: Node = get_parent()
	while n != null and client_view == null:
		if n is ClientView:
			client_view = n as ClientView
		n = n.get_parent()
	var root: Node = get_tree().current_scene
	if client_view == null and root != null:
		client_view = root.get_node_or_null(^"ClientView") as ClientView
		if client_view == null:
			for ch: Node in root.get_children():
				if ch is ClientView:
					client_view = ch as ClientView
					break
	if client_view != null and not client_view.interact_requested.is_connected(on_world_interact_requested):
		client_view.interact_requested.connect(on_world_interact_requested)


func get_player_entity() -> Node3D:
	_find_view()
	if client_view != null:
		var target: Node3D = client_view.get_follow_target()
		if target != null and is_instance_valid(target):
			return target
	var root: Node = get_node_or_null(^"/root/Main/World/Instances")
	if root != null:
		for inst: Node in root.get_children():
			var ents: Node = inst.get_node_or_null(^"Entities")
			if ents != null:
				for e: Node in ents.get_children():
					if e is NetEntity:
						var ne: NetEntity = e as NetEntity
						if ne.is_local_player() or ne.is_player():
							return ne
	return null


# --- Andar ----------------------------------------------------------------------------------------

## Um passo na direção da tela dir2d (x = direita, y = baixo; comprimento 0..1), relativo à câmera.
## Pede no máximo um movimento a cada Balance.cfg.hold_walk_repeat_ms. true = pediu agora.
func walk(dir2d: Vector2) -> bool:
	if dir2d.length_squared() < WALK_MIN_LENGTH_SQ:
		return false
	var player: Node3D = get_player_entity()
	if player == null or not is_instance_valid(player):
		return false
	var now_msec: float = NetClock.local_now_msec()
	if now_msec < _next_move_msec:
		return false
	_find_view()
	if client_view == null:
		return false
	var cam_yaw: float = client_view.camera_yaw
	var cam_forward := -Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
	var cam_right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var world_dir: Vector3 = (cam_right * dir2d.x + cam_forward * (-dir2d.y)).normalized()
	var target_world: Vector3 = player.global_position + world_dir * (WALK_STEP_DISTANCE * minf(1.0, dir2d.length()))
	var snapped: Vector3 = client_view.snap_to_cell(target_world)
	var grid: WalkGrid = client_view.get_walk_grid()
	_last_walk_cell = grid.world_to_cell(snapped) if grid != null else Vector2i(roundi(snapped.x), roundi(snapped.z))
	_next_move_msec = now_msec + float(Balance.cfg.hold_walk_repeat_ms)
	client_view.move_requested.emit(snapped)
	return true


## Soltou o analógico: o próximo passo sai na hora.
func stop_walk() -> void:
	_last_walk_cell = Vector2i(-9999, -9999)
	_next_move_msec = 0.0


# --- Alvos ----------------------------------------------------------------------------------------

static func is_entity_alive(e: Node) -> bool:
	if e == null or not is_instance_valid(e) or e.is_queued_for_deletion():
		return false
	if "hp_ratio" in e and float(e.get(&"hp_ratio")) <= 0.0:
		return false
	if e.has_method(&"is_dead") and bool(e.call(&"is_dead")):
		return false
	return true


static func is_monster(e: Node) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if e.has_method(&"is_monster"):
		return bool(e.call(&"is_monster"))
	return e.get(&"kind") == NetEntity.KIND_MONSTER


## Monstros vivos até max_range, do mais perto ao mais longe.
func get_nearby_monsters(max_range: float = TARGET_SEARCH_MAX_DIST, exclude_id: int = NO_TARGET) -> Array[Node3D]:
	var me: Node3D = get_player_entity()
	var my_pos: Vector3 = me.global_position if me != null else Vector3.ZERO
	var monsters: Array[Node3D] = []
	for e: Node3D in NetCombat.all_entities():
		if not is_monster(e):
			continue
		if exclude_id >= 0 and int(e.get(&"entity_id")) == exclude_id:
			continue
		if not is_entity_alive(e):
			continue
		if my_pos.distance_to(e.global_position) <= max_range:
			monsters.append(e)
	monsters.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return my_pos.distance_squared_to(a.global_position) < my_pos.distance_squared_to(b.global_position))
	return monsters


func find_nearest_monster(max_range: float = TARGET_SEARCH_MAX_DIST, exclude_id: int = NO_TARGET) -> Node3D:
	var list: Array[Node3D] = get_nearby_monsters(max_range, exclude_id)
	return list[0] if not list.is_empty() else null


## Item no chão ou NPC mais perto de from_pos até max_range (null = nenhum).
func find_nearest_interactable(from_pos: Vector3, max_range: float) -> Node3D:
	var best: Node3D = null
	var best_d: float = max_range
	for e: Node3D in NetCombat.all_entities():
		var kind: Variant = e.get(&"kind")
		if kind != NetEntity.KIND_DROP and kind != NetEntity.KIND_NPC:
			continue
		var d: float = from_pos.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## interact_id do objeto clicável do mapa mais perto até max_range ("" = nenhum).
func find_nearest_map_object(from_pos: Vector3, max_range: float) -> String:
	var me: Node3D = get_player_entity()
	var inst: Node = me.get_parent().get_parent() if me != null and me.get_parent() != null else null
	var map_node: Node = inst.get_node_or_null(^"Map") if inst != null else null
	if map_node == null or not map_node.has_method(&"get_interactables"):
		return ""
	var best: String = ""
	var best_d: float = max_range
	var objects: Dictionary = map_node.call(&"get_interactables")
	for id: Variant in objects:
		var d: float = from_pos.distance_to((objects[id] as Dictionary).get("position", Vector3.INF))
		if d < best_d:
			best_d = d
			best = String(id)
	return best


func select_target(target_id: int, send_intent: bool = true) -> void:
	var ent: Node3D = NetCombat.find_entity(target_id)
	if ent == null or not is_entity_alive(ent) or not is_monster(ent):
		clear_target()
		return
	current_target = target_id
	NetCombat.set_client_target(target_id)
	var prog: ProgressionHud = progression()
	if prog != null:
		prog._last_clicked_target = target_id
	if send_intent:
		NetCombat.send_attack(target_id)
	if game_ui != null:
		var dname: String = str(ent.get(&"display_name"))
		if not dname.is_empty():
			game_ui.show_system_message("Alvo: %s" % dname)


func clear_target() -> void:
	current_target = NO_TARGET
	NetCombat.set_client_target(0)
	var prog: ProgressionHud = progression()
	if prog != null:
		prog._last_clicked_target = 0


## Próximo (step = 1) ou anterior (step = -1) monstro vivo por perto; sem alvo, o mais perto.
func cycle_target(step: int = 1) -> void:
	var monsters: Array[Node3D] = get_nearby_monsters(TARGET_SEARCH_MAX_DIST)
	if monsters.is_empty():
		clear_target()
		if game_ui != null:
			game_ui.show_system_message("Nenhum monstro por perto.")
		return
	var next_idx: int = 0
	for i: int in monsters.size():
		if int(monsters[i].get(&"entity_id")) == current_target:
			next_idx = posmod(i + step, monsters.size())
			break
	select_target(int(monsters[next_idx].get(&"entity_id")), true)


## Botão de ação: alvo travado vivo → ataca; item/NPC muito perto → pega/conversa; objeto do mapa perto
## (portal, altar…) → usa; senão trava o monstro mais perto. Devolve o que fez: &"attack", &"pickup",
## &"talk", &"use", &"target" ou &"" (nada por perto).
func smart_action() -> StringName:
	var me: Node3D = get_player_entity()
	var my_pos: Vector3 = me.global_position if me != null else Vector3.ZERO
	var current: Node3D = NetCombat.find_entity(current_target) if current_target >= 0 else null
	if current != null and is_entity_alive(current):
		NetCombat.send_attack(current_target)
		action_performed.emit(&"attack", current_target)
		return &"attack"
	var interactable: Node3D = find_nearest_interactable(my_pos, INTERACT_PRIORITY_DIST)
	if interactable != null:
		var eid: int = int(interactable.get(&"entity_id"))
		if interactable.get(&"kind") == NetEntity.KIND_DROP:
			NetCombat.send_pickup(eid)
			action_performed.emit(&"pickup", eid)
			return &"pickup"
		_net().send_interact("e:%d" % eid)
		action_performed.emit(&"talk", eid)
		return &"talk"
	var object_id: String = find_nearest_map_object(my_pos, MAP_OBJECT_DIST)
	if not object_id.is_empty() and client_view != null:
		# Igual a clicar no objeto: o main.gd encaminha "m:<id>" ao servidor (NetCombat.route_interact).
		client_view.interact_requested.emit(ClientView.TARGET_MAP_PREFIX + object_id)
		action_performed.emit(&"use", -1)
		return &"use"
	var nearest: Node3D = find_nearest_monster(TARGET_SEARCH_MAX_DIST)
	if nearest != null:
		select_target(int(nearest.get(&"entity_id")), true)
		action_performed.emit(&"target", current_target)
		return &"target"
	return &""


## Primeira poção de vida do inventário. false = não tinha.
func quick_potion() -> bool:
	var inv: Array = Net.client_inventory
	for i: int in inv.size():
		if inv[i] is Dictionary and str((inv[i] as Dictionary).get("item", "")).begins_with("potion_hp"):
			Net.send_use_item(i)
			return true
	if game_ui != null:
		game_ui.show_system_message("Sem poções de vida no inventário!")
	return false


func auto_retarget_next() -> void:
	var old_id: int = current_target
	current_target = NO_TARGET
	var next_mon: Node3D = find_nearest_monster(TARGET_SEARCH_MAX_DIST, old_id)
	if next_mon != null:
		select_target(int(next_mon.get(&"entity_id")), true)
	else:
		clear_target()


func _check_current_target_alive() -> void:
	if current_target < 0:
		return
	var ent: Node3D = NetCombat.find_entity(current_target)
	if ent == null or not is_entity_alive(ent):
		auto_retarget_next()


func on_entity_died(dead_id: int) -> void:
	if dead_id == current_target:
		auto_retarget_next()


func on_attack_target_changed(target_id: int) -> void:
	if target_id > 0:
		var ent: Node3D = NetCombat.find_entity(target_id)
		if ent != null and is_monster(ent) and is_entity_alive(ent):
			current_target = target_id
			var prog: ProgressionHud = progression()
			if prog != null:
				prog._last_clicked_target = target_id
	elif target_id == 0 and current_target > 0:
		var ent: Node3D = NetCombat.find_entity(current_target)
		if ent == null or not is_entity_alive(ent):
			auto_retarget_next()
		else:
			current_target = NO_TARGET


## Clique/toque direto num monstro trava o alvo.
func on_world_interact_requested(target_id: String) -> void:
	var eid: int = NetCombat.parse_entity_id(target_id)
	if eid > 0:
		var ent: Node3D = NetCombat.find_entity(eid)
		if ent != null and is_monster(ent) and is_entity_alive(ent):
			select_target(eid, true)
