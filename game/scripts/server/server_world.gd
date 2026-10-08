class_name ServerWorld
extends Node
## Mundo autoritativo do servidor (/root/Main/ServerWorld): instâncias (GDD §5: uma por mapa, compartilhada
## por todos desde 30/09/2026), entidades
## (jogadores e NPCs), sessões dos jogadores e tick (GDD §15.3). Um processo guarda todas as
## instâncias como subárvores; instâncias do mesmo mapa compartilham um único mapa de navegação.
##
## Serviços (RefCounted, recebem este nó): InteractionService, DialogueRunner, ItemService,
## ChatService. Componentes de entidade: GridMover (movimento por células, GDD §10.1) e NpcBrain
## (rotina de NPC). Cada map_id tem uma WalkGrid (cache compartilhado pelas instâncias do mapa).
## Persistência: CharacterStore (JsonCharacterStore neste marco).

## Mapa inicial (cidade: instance_id = map_id).
const START_MAP_ID: StringName = &"city_awakening"
const ENTITY_SCENE: String = "res://scenes/entities/net_entity.tscn"
const NPC_POINTS_NODE: String = "NpcPoints"
const INTERACTABLES_NODE: String = "Interactables"
const META_INTERACT_ID: String = "interact_id"
const META_INTERACT_TYPE: String = "interact_type"
## Yaw do NPC no marcador (meta de C); sem a meta, usa a rotação Y do Marker3D.
const META_FACING_YAW: String = "facing_yaw"
## Contrato city-walk: salvar a cada 60 s (e ao sair). GDD §15.5.
const SAVE_INTERVAL_SEC: float = 60.0
## Folga (m) além de interact_range antes de fechar diálogo/loja por distância.
const SESSION_RANGE_SLACK: float = 1.5
## Tolerância (m) ao encaixar um ponto (banco, marcador) no navmesh.
const SNAP_TOLERANCE: float = 3.0
## Raio (células) da busca da célula andável mais próxima ao encaixar spawns na grade.
const GRID_SNAP_SEARCH_CELLS: int = 6
## Script de dados de teste (só com --test-fixtures).
const FIXTURES_SCRIPT: String = "res://tests/server/fixtures/test_fixtures.gd"

# --- autoteste do servidor (--autotest)
const AUTOTEST_PARTY_ID: String = "party_autotest"
const AUTOTEST_GHOST_ENTITY_ID: int = 999001
const AUTOTEST_GHOST_NAME: String = "Ghost"
## O fantasma anda de um lado para o outro para gerar tráfego de sincronização.
const AUTOTEST_GHOST_STEP: Vector3 = Vector3(3.0, 0.0, 0.0)
const AUTOTEST_GHOST_INTERVAL_SEC: float = 1.5
## O servidor de autoteste encerra sozinho depois disso.
const AUTOTEST_DURATION_SEC: float = 150.0
const AUTOTEST_SAVE_DIR: String = "user://server_saves_autotest/"

## Definidos por main.gd antes de add_child.
var main_node: Node = null
var autotest: bool = false
var test_fixtures: bool = false
var save_dir: String = ""

var interaction: InteractionService = null
var dialogue: DialogueRunner = null
var items: ItemService = null
var chat: ChatService = null
## Combate e monstros (K, contrato arrival). Sinais monster_killed/player_killed (Q, N).
var combat: CombatService = null
var store: CharacterStore = null
## Agente N: regras de zona e troca de mapa (scripts/server/world/).
var zone_rules: ZoneRules = null
var map_transfer: MapTransfer = null
## Agente Q: progressão (XP, pontos, skills, barra 1–0, títulos, quests) — scripts/server/progression/.
var progression: Progression = null
## Grupo (GDD §5.2–5.4, 30/09/2026): convites, líder, XP dividida, posse de drop, chat /g, /online.
var party: PartyService = null
## Troca entre personagens (30/09/2026): pedido, janela, confirmação e troca atômica.
var trade: TradeService = null
## Sistema de Crendices (GDD §11): amuletos, encaixes e consagração no Altar.
var crendice: CrendiceService = null
## Dona Ana (06/10/2026): cidades conhecidas, ponto salvo e viagem entre cidades.
var waystones: WaystoneService = null
var mounts: MountService = null
var companions: CompanionService = null


var _instances: Dictionary[StringName, Node3D] = {}
var _instance_maps: Dictionary[StringName, StringName] = {}
## Instâncias cujos NPCs ainda não nasceram (esperando o navmesh sincronizar).
var _npc_spawn_pending: Array[StringName] = []
## map_id -> RID do mapa de navegação compartilhado pelas instâncias desse mapa.
var _nav_maps: Dictionary[StringName, RID] = {}
## map_id -> instância dona do navmesh (a primeira criada desse mapa).
var _nav_owner_instances: Dictionary[StringName, StringName] = {}
var _entities: Dictionary[int, NetEntity] = {}
var _sessions: Dictionary[int, PlayerSession] = {}
var _entity_scene: PackedScene = null
var _next_npc_index: int = 0
var _save_timer: float = 0.0
var _fixtures: Script = null
var _ghost: NetEntity = null
var _ghost_dir: float = 1.0

# Admin & Live State
var event_xp_mult: float = 1.0
var event_drop_mult: float = 1.0
var active_decorations: Dictionary = {}
var active_cosmetics: Dictionary = {}
var _admin_state_timer: float = 0.0
var _last_broadcast_msg: String = ""


func _ready() -> void:
	_entity_scene = load(ENTITY_SCENE) as PackedScene
	if test_fixtures:
		_fixtures = load(FIXTURES_SCRIPT) as Script if ResourceLoader.exists(FIXTURES_SCRIPT) else null
		if _fixtures != null:
			_fixtures.call("install_content")
	var dir: String = save_dir
	if dir.is_empty():
		dir = AUTOTEST_SAVE_DIR if autotest else JsonCharacterStore.DEFAULT_DIR
	if autotest:
		_wipe_dir(dir)
	store = JsonCharacterStore.new(dir)
	interaction = InteractionService.new(self)
	dialogue = DialogueRunner.new(self)
	items = ItemService.new(self)
	chat = ChatService.new(self)
	combat = CombatService.new(self)
	zone_rules = ZoneRules.new(self)
	map_transfer = MapTransfer.new(self)
	progression = Progression.new(self)
	party = PartyService.new(self)
	trade = TradeService.new(self)
	crendice = CrendiceService.new(self)
	waystones = WaystoneService.new(self)
	mounts = MountService.new(self)
	companions = CompanionService.new(self)
	NetFollowers.command_intent.connect(_on_follower_command)
	zone_rules.connect_combat.call_deferred()
	NetWorld.debug_intent.connect(_with_session2.bind(map_transfer.debug_command))
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_instance_ready.connect(_on_peer_instance_ready)
	Net.peer_left.connect(_on_peer_left)
	Net.move_intent.connect(_on_move_intent)
	Net.interact_intent.connect(_with_session.bind(_do_interact))
	Net.dialogue_choice_intent.connect(_with_session.bind(_do_dialogue_choice))
	Net.dialogue_close_intent.connect(_with_session_noarg.bind(_do_dialogue_close))
	Net.inventory_move_intent.connect(_with_session2.bind(_do_inventory_move))
	Net.use_item_intent.connect(_with_session.bind(_do_use_item))
	Net.equip_intent.connect(_with_session.bind(_do_equip))
	Net.unequip_intent.connect(_with_session.bind(_do_unequip))
	Net.shop_buy_intent.connect(_with_session2.bind(_do_shop_buy))
	Net.shop_sell_intent.connect(_with_session2.bind(_do_shop_sell))
	Net.shop_close_intent.connect(_with_session_noarg.bind(_do_shop_close))
	Net.chat_intent.connect(_with_session2.bind(_do_chat))
	Net.emote_intent.connect(_with_session.bind(_do_emote))
	Net.log_line("server_world_ready", {"save_dir": dir, "fixtures": _fixtures != null,
			"items": Content.all(&"items").size(), "npcs": Content.all(&"npcs").size()})
	# A cidade existe sempre.
	get_or_create_instance(Net.make_instance_id(START_MAP_ID), START_MAP_ID)
	if autotest:
		_setup_autotest()


func _wipe_dir(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		d.remove(f)


# ---------------------------------------------------------------- consultas (usadas pelos serviços)

func get_entity(entity_id: int) -> NetEntity:
	var e: NetEntity = _entities.get(entity_id)
	return e if is_instance_valid(e) else null


func get_session(peer_id: int) -> PlayerSession:
	return _sessions.get(peer_id)


func get_brain(npc: NetEntity) -> NpcBrain:
	return npc.get_node_or_null(NpcBrain.NODE_NAME) as NpcBrain if npc != null else null


## Distância máxima (m) para manter diálogo/loja abertos.
func session_range() -> float:
	return Balance.cfg.interact_range + SESSION_RANGE_SLACK


## Grade de células do mapa da instância (constrói e guarda em cache quando o navmesh sincroniza).
## null enquanto o navmesh não estiver pronto ou se o mapa não tiver navmesh.
func get_grid_for_instance(instance_id: StringName) -> WalkGrid:
	var map_id: StringName = _instance_maps.get(instance_id, &"")
	var cached: WalkGrid = WalkGrid.get_cached(map_id)
	if cached != null:
		return cached
	var nav: RID = get_nav_map_for_instance(instance_id)
	if not nav.is_valid() or not is_nav_ready(instance_id):
		return null
	var owner_map: Node = _get_map_node(_nav_owner_instances.get(map_id, instance_id))
	var g: WalkGrid = WalkGrid.for_map(map_id, owner_map, nav)
	if g != null:
		Net.log_line("walk_grid_built", {"map": String(map_id), "cells": g.cell_count(),
				"walkable": g.walkable_count(), "size": str(g.size), "origin": str(g.origin),
				"msec": g.build_msec})
	return g


## Encaixa um ponto no centro da célula andável mais próxima (sem grade: devolve o ponto).
func snap_to_grid(instance_id: StringName, point: Vector3) -> Vector3:
	var g: WalkGrid = get_grid_for_instance(instance_id)
	if g == null:
		return point
	var c: Vector2i = g.nearest_walkable(g.world_to_cell(point), GRID_SNAP_SEARCH_CELLS)
	return g.cell_to_world(c) if c.x >= 0 else point


func get_nav_map_for_instance(instance_id: StringName) -> RID:
	var map_id: StringName = _instance_maps.get(instance_id, &"")
	return _nav_maps.get(map_id, RID())


## map_id da instância (&"" se não existir).
func get_instance_map_id(instance_id: StringName) -> StringName:
	return _instance_maps.get(instance_id, &"")


func get_map_node(instance_id: StringName) -> Node:
	return _get_map_node(instance_id)


func get_spawn_point(instance_id: StringName) -> Vector3:
	return _get_spawn_point(instance_id)


func update_instance_visibility_for(instance_id: StringName, peer_id: int) -> void:
	_update_instance_visibility_for(instance_id, peer_id)


# --- entidades criadas por serviços (K: monstros e itens no chão)

## Entidade nova (ainda sem server_setup nem pai).
func new_entity() -> NetEntity:
	return _entity_scene.instantiate() as NetEntity


## Registra uma entidade (com server_setup feito) na instância dela e libera a replicação.
func spawn_entity(entity: NetEntity) -> void:
	_add_entity(entity)


## Remove uma entidade do mundo (os clientes recebem o despawn pelo MultiplayerSpawner).
func despawn_entity(entity: NetEntity) -> void:
	_entities.erase(entity.entity_id)
	entity.queue_free()


func get_instance_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_instances.keys())
	return out


func get_sessions() -> Array[PlayerSession]:
	var out: Array[PlayerSession] = []
	out.assign(_sessions.values())
	return out


func _get_map_node(instance_id: StringName) -> Node:
	var inst: Node3D = _instances.get(instance_id)
	return inst.get_node_or_null("Map") if inst != null else null


## Objetos interativos do mapa: id -> {type, position, meta}. Usa GameMap.get_interactables()
## (de C) e, se o mapa ainda não tiver o método, lê o nó Interactables pelas metas do contrato.
func get_interactables(instance_id: StringName) -> Dictionary:
	var map_node: Node = _get_map_node(instance_id)
	if map_node == null:
		return {}
	if map_node.has_method("get_interactables"):
		var d: Variant = map_node.call("get_interactables")
		if typeof(d) == TYPE_DICTIONARY:
			return d
	var out: Dictionary = {}
	var root: Node = map_node.get_node_or_null(INTERACTABLES_NODE)
	if root == null:
		return out
	for child: Node in root.get_children():
		if not child.has_meta(META_INTERACT_ID) or not (child is Node3D):
			continue
		var meta: Dictionary = {}
		for k: StringName in child.get_meta_list():
			meta[String(k)] = child.get_meta(k)
		out[str(child.get_meta(META_INTERACT_ID))] = {
			"type": StringName(str(child.get_meta(META_INTERACT_TYPE, ""))),
			"position": (child as Node3D).global_position,
			"meta": meta,
		}
	return out


## Navmesh da instância sincronizado e com regiões (sem mapa de navegação = "pronto", sem encaixe).
func is_nav_ready(instance_id: StringName) -> bool:
	var nav: RID = get_nav_map_for_instance(instance_id)
	if not nav.is_valid():
		return true
	return NavigationServer3D.map_get_iteration_id(nav) > 0 \
			and not NavigationServer3D.map_get_regions(nav).is_empty() \
			and NavigationServer3D.map_get_closest_point_owner(nav, _get_spawn_point(instance_id)).is_valid()


func snap_to_nav(instance_id: StringName, point: Vector3) -> Vector3:
	var nav: RID = get_nav_map_for_instance(instance_id)
	if not nav.is_valid() or NavigationServer3D.map_get_iteration_id(nav) == 0:
		return point
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(nav, point)
	return closest if closest.distance_to(point) <= SNAP_TOLERANCE else point


# ---------------------------------------------------------------- ações usadas pelos serviços

## ADENDO 1: recalcula a aparência replicada do jogador (a todos da instância).
func refresh_appearance(session: PlayerSession) -> void:
	var app: Dictionary = session.character.full_appearance()
	app[&"mount"] = session.mounted_id
	app[&"companion"] = session.character.companion_active if session.character.hp > 0 else &""
	app[&"companion_name"] = session.character.companion_names.get(String(session.character.companion_active), "")
	# Nível do bicho (rótulo e evolução visual nos marcos 10/25/50; PETS-E-MONTARIAS §0.1).
	app[&"companion_level"] = companions.level_of(session.character, session.character.companion_active) \
			if companions != null else 1
	session.entity.appearance = app


func stand_up(session: PlayerSession) -> void:
	if session.entity.anim == NetEntity.ANIM_SIT:
		session.entity.anim = NetEntity.ANIM_IDLE


## Emote &"sit": senta onde está.
func sit_here(session: PlayerSession) -> void:
	if mounts != null:
		mounts.dismount(session)
	interaction.cancel(session)
	session.entity.get_mover().halt()
	session.entity.anim = NetEntity.ANIM_SIT


## Objeto &"sit" do mapa: senta no lugar do objeto (seat_position de C, ou o ponto do navmesh
## mais próximo do objeto), virado para o yaw do marcador.
func sit_at(session: PlayerSession, point: Vector3, yaw: float, snap: bool) -> void:
	if mounts != null:
		mounts.dismount(session)
	var e: NetEntity = session.entity
	var p: Vector3 = snap_to_nav(e.instance_id, point) if snap else point
	e.get_mover().place(p)
	e.facing_yaw = yaw
	e.anim = NetEntity.ANIM_SIT
	Net.log_line("player_sat", {"peer": session.peer_id, "pos": str(p), "yaw": snappedf(yaw, 0.01)})


# ---------------------------------------------------------------- instâncias

func get_or_create_instance(instance_id: StringName, map_id: StringName) -> Node3D:
	if _instances.has(instance_id):
		return _instances[instance_id]
	var inst: Node3D = main_node.call("create_instance_node", instance_id, map_id)
	if inst == null:
		Net.log_line("instance_create_failed", {"instance": String(instance_id), "map": String(map_id)})
		return null
	_instances[instance_id] = inst
	_instance_maps[instance_id] = map_id
	_setup_navigation(inst, map_id)
	_npc_spawn_pending.append(instance_id)
	Net.log_line("instance_created", {"instance": String(instance_id), "map": String(map_id),
			"node": String(inst.get_path())})
	return inst


## GDD §15.3: instâncias do mesmo mapa compartilham o navmesh. A primeira instância de cada map_id
## fornece o mapa de navegação (GameMap.get_navigation_map()); nas seguintes as NavigationRegion3D
## são desativadas e as consultas usam o mapa da primeira. Obs.: quando houver destruição de
## instâncias (Fase 2), a dona do navmesh de um map_id não pode sumir sem transferir a posse.
func _setup_navigation(inst: Node3D, map_id: StringName) -> void:
	var map_node: Node = inst.get_node("Map")
	if _nav_maps.has(map_id):
		for r: Node in map_node.find_children("*", "NavigationRegion3D", true, false):
			(r as NavigationRegion3D).enabled = false
		return
	var nav_map: RID = RID()
	if map_node.has_method("get_navigation_map"):
		nav_map = map_node.call("get_navigation_map")
	if not nav_map.is_valid():
		Net.log_line("map_without_navmesh", {"map": String(map_id)})
		return
	_nav_maps[map_id] = nav_map
	_nav_owner_instances[map_id] = _instance_id_of(inst)


func _instance_id_of(inst: Node3D) -> StringName:
	for id: StringName in _instances:
		if _instances[id] == inst:
			return id
	return &""


func _get_spawn_point(instance_id: StringName) -> Vector3:
	var map_node: Node = _get_map_node(instance_id)
	if map_node != null and map_node.has_method("get_spawn_point"):
		return map_node.call("get_spawn_point")
	return Vector3.ZERO


func _get_entities_root(instance_id: StringName) -> Node3D:
	var inst: Node3D = _instances.get(instance_id)
	return inst.get_node("Entities") as Node3D if inst != null else null


## Reavalia a visibilidade de todas as entidades da instância para um peer (entrou/saiu).
func _update_instance_visibility_for(instance_id: StringName, peer_id: int) -> void:
	var root: Node3D = _get_entities_root(instance_id)
	if root == null:
		return
	for e: Node in root.get_children():
		if e is NetEntity:
			(e as NetEntity).get_sync().update_visibility(peer_id)


## Adiciona uma entidade (com server_setup já feito) à instância, liberando os peers do mundo;
## o filtro de instance_id decide quem de fato recebe.
func _add_entity(entity: NetEntity) -> void:
	for peer_id: int in Net.get_world_peer_ids():
		entity.server_set_peer_allowed(peer_id, true)
	_get_entities_root(entity.instance_id).add_child(entity)
	_entities[entity.entity_id] = entity
	entity.get_sync().update_visibility(0)


func _allow_peer_on_all_entities(peer_id: int, allowed: bool) -> void:
	for e: NetEntity in _entities.values():
		if is_instance_valid(e):
			e.server_set_peer_allowed(peer_id, allowed)


# ---------------------------------------------------------------- NPCs

## NPCs nascem quando o navmesh da instância já sincronizou (encaixe dos marcadores e rotinas).
func _spawn_pending_npcs() -> void:
	for instance_id: StringName in _npc_spawn_pending.duplicate():
		if not is_nav_ready(instance_id):
			continue
		_npc_spawn_pending.erase(instance_id)
		_spawn_npcs(instance_id)


func _spawn_npcs(instance_id: StringName) -> void:
	var map_id: StringName = _instance_maps[instance_id]
	var map_node: Node = _get_map_node(instance_id)
	var defs: Array[NpcDef] = []
	for def: Resource in Content.all(&"npcs").values():
		if def is NpcDef and (def as NpcDef).map_id == map_id:
			defs.append(def as NpcDef)
	defs.sort_custom(func(a: NpcDef, b: NpcDef) -> bool: return String(a.id) < String(b.id))
	if _fixtures != null:
		_fixtures.call("ensure_npc_markers", map_node, defs, get_nav_map_for_instance(instance_id))
	var points: Node = map_node.get_node_or_null(NPC_POINTS_NODE)
	var spawned: int = 0
	for def: NpcDef in defs:
		var marker: Node3D = points.get_node_or_null(String(def.spawn_marker)) as Node3D \
				if points != null else null
		if marker == null:
			push_warning("NPC '%s': marker %s/%s not found in map %s; skipped." % [def.id,
					NPC_POINTS_NODE, def.spawn_marker, map_id])
			Net.log_line("npc_marker_missing", {"npc": String(def.id),
					"marker": String(def.spawn_marker), "map": String(map_id)})
			continue
		var patrol: Array[Vector3] = []
		for m: StringName in def.patrol_markers:
			var pm: Node3D = points.get_node_or_null(String(m)) as Node3D
			if pm != null:
				patrol.append(snap_to_grid(instance_id, pm.global_position))
			else:
				Net.log_line("npc_patrol_marker_missing", {"npc": String(def.id), "marker": String(m)})
		var yaw: float = float(marker.get_meta(META_FACING_YAW, marker.global_rotation.y))
		_spawn_npc(instance_id, def, snap_to_grid(instance_id, marker.global_position), yaw, patrol)
		spawned += 1
	Net.log_line("npcs_spawned", {"instance": String(instance_id), "count": spawned,
			"defs": defs.size()})


func _spawn_npc(instance_id: StringName, def: NpcDef, pos: Vector3, yaw: float,
		patrol: Array[Vector3]) -> NetEntity:
	_next_npc_index += 1
	var e: NetEntity = _entity_scene.instantiate() as NetEntity
	e.server_setup(NetEntity.NPC_ID_BASE + _next_npc_index, NetEntity.KIND_NPC, def.name_key,
			def.id, instance_id, pos)
	e.server_ensure_mover(get_grid_for_instance(instance_id),
			GridMover.ms_per_cell_for_speed(def.move_speed))
	var brain := NpcBrain.new()
	brain.name = NpcBrain.NODE_NAME
	brain.setup(def, pos, yaw, patrol)
	e.add_child(brain)
	brain.apply_rest_pose()
	_add_entity(e)
	Net.log_line("npc_spawned", {"id": e.entity_id, "npc": String(def.id),
			"routine": NpcDef.Routine.keys()[def.routine], "instance": String(instance_id),
			"pos": str(pos)})
	return e


# ---------------------------------------------------------------- jogadores

func _on_peer_joined(peer_id: int, display_name: String, _body: StringName) -> void:
	var map_id: StringName = map_transfer.entry_map_for(peer_id)
	var instance_id: StringName = map_transfer.instance_id_for(map_id, display_name)
	if get_or_create_instance(instance_id, map_id) == null:
		return
	Net.send_enter_instance(peer_id, instance_id, map_id)


func _load_or_create_character(peer_id: int) -> CharacterData:
	if map_transfer != null:
		return map_transfer.load_or_create(peer_id)
	var char_name: String = Net.get_peer_display_name(peer_id)
	var c: CharacterData = store.load_character(char_name)
	if c != null:
		Net.log_line("character_loaded", {"peer": peer_id, "name": char_name, "stars": c.stars})
		return c
	c = CharacterData.create_new(char_name, Net.get_peer_body_type(peer_id))
	store.save_character(c)
	Net.log_line("character_created", {"peer": peer_id, "name": char_name, "stars": c.stars,
			"inventory": c.inventory.to_save().filter(func(s: Dictionary) -> bool: return not s.is_empty())})
	return c


func _on_peer_instance_ready(peer_id: int, instance_id: StringName) -> void:
	var old_instance: StringName = Net.get_peer_instance(peer_id)
	Net.set_peer_instance(peer_id, instance_id)
	var session: PlayerSession = _sessions.get(peer_id)
	var logging_in: bool = session == null
	if session != null:
		# Troca de instância (MapTransfer, Agente N): a entidade antiga some da instância velha e uma
		# nova nasce na nova (mover um nó replicado entre MultiplayerSpawners não é suportado).
		var old: NetEntity = session.entity
		dialogue.close(session, true)
		dialogue.close_shop(session, true)
		interaction.cancel(session)
		combat.on_player_left(session)
		_entities.erase(old.entity_id)
		old.get_parent().remove_child(old)
		old.queue_free()
		var c: CharacterData = session.character
		var player: NetEntity = _entity_scene.instantiate() as NetEntity
		player.server_setup(peer_id, NetEntity.KIND_PLAYER, c.char_name, c.body_type,
				instance_id, snap_to_grid(instance_id, map_transfer.take_arrival_point(peer_id, instance_id)))
		_watch_path_for_autotest(player.server_ensure_mover(get_grid_for_instance(instance_id),
				Balance.cfg.walk_ms_per_cell))
		player.appearance = c.full_appearance()
		session.entity = player
		combat.on_player_spawned(session)
		_add_entity(player)
	else:
		var c: CharacterData = _load_or_create_character(peer_id)
		var player: NetEntity = _entity_scene.instantiate() as NetEntity
		player.server_setup(peer_id, NetEntity.KIND_PLAYER, c.char_name, c.body_type,
				instance_id, snap_to_grid(instance_id, _get_spawn_point(instance_id)))
		_watch_path_for_autotest(player.server_ensure_mover(get_grid_for_instance(instance_id),
				Balance.cfg.walk_ms_per_cell))
		player.appearance = c.full_appearance()
		session = PlayerSession.new(peer_id, player, c)
		_sessions[peer_id] = session
		combat.on_player_spawned(session)
		_add_entity(player)
		# Moderação (S): aviso de chat bloqueado / personagem com perda aprovada.
		chat.on_player_ready(session)
	if old_instance.is_empty():
		_allow_peer_on_all_entities(peer_id, true)
	elif old_instance != instance_id:
		_update_instance_visibility_for(old_instance, peer_id)
	_update_instance_visibility_for(instance_id, peer_id)
	map_transfer.on_player_placed(session)
	progression.on_player_ready(session)
	if companions != null and logging_in:
		companions.restore(session)
	party.on_player_ready(session)
	Net.log_line("player_spawned", {"peer": peer_id, "name": session.entity.display_name,
			"instance": String(instance_id), "pos": str(session.entity.net_position),
			"appearance": session.entity.appearance})


func _on_peer_left(peer_id: int) -> void:
	if mounts != null:
		mounts.forget(peer_id)
	if companions != null:
		companions.forget(peer_id)
	var session: PlayerSession = _sessions.get(peer_id)
	_sessions.erase(peer_id)
	if session != null:
		combat.on_player_left(session)
	map_transfer.forget(peer_id)
	zone_rules.forget(peer_id)
	if session == null:
		return
	party.on_peer_left(peer_id, session.character.char_name)
	trade.on_peer_left(peer_id, session.character.char_name)
	dialogue.close(session, false)
	dialogue.close_shop(session, false)
	var saved: bool = store.save_character(session.character)
	Net.log_line("character_saved", {"peer": peer_id, "name": session.character.char_name,
			"ok": saved, "reason": "logout", "stars": session.character.stars})
	if autotest:
		_autotest_check_save(session.character)
	_entities.erase(session.entity.entity_id)
	# (Não dá para revogar set_visibility_for aqui: o peer já saiu do SceneMultiplayer.)
	session.entity.queue_free()
	Net.log_line("player_removed", {"peer": peer_id})


func _save_all(reason: String) -> void:
	for session: PlayerSession in _sessions.values():
		if not session.save_pending:
			continue
		session.save_pending = false
		var ok: bool = store.save_character(session.character)
		Net.log_line("character_saved", {"peer": session.peer_id,
				"name": session.character.char_name, "ok": ok, "reason": reason})


# ---------------------------------------------------------------- intenções

## Adaptadores: os sinais do Net trazem peer_id; aqui vira PlayerSession (ou log se não houver).
func _with_session(peer_id: int, arg: Variant, handler: Callable) -> void:
	var s: PlayerSession = _sessions.get(peer_id)
	if s == null:
		Net.log_invalid(peer_id, "intent_without_session")
		return
	handler.call(s, arg)


func _with_session2(peer_id: int, a: Variant, b: Variant, handler: Callable) -> void:
	var s: PlayerSession = _sessions.get(peer_id)
	if s == null:
		Net.log_invalid(peer_id, "intent_without_session")
		return
	handler.call(s, a, b)


func _with_session_noarg(peer_id: int, handler: Callable) -> void:
	var s: PlayerSession = _sessions.get(peer_id)
	if s == null:
		Net.log_invalid(peer_id, "intent_without_session")
		return
	handler.call(s)


func _on_move_intent(peer_id: int, target: Vector3) -> void:
	var s: PlayerSession = _sessions.get(peer_id)
	if s == null:
		Net.log_invalid(peer_id, "move_without_entity")
		return
	var mover: GridMover = s.entity.get_mover()
	var from: Vector3 = s.entity.net_position
	if mover.grid == null:
		mover.grid = get_grid_for_instance(s.entity.instance_id)
	if not combat.allow_player_action(s, "move"):
		return
	combat.on_player_moved(s)
	if mounts != null:
		mounts.cancel(s)
	if companions != null:
		companions.cancel(s)
	if not mover.move_to(target):
		Net.log_invalid(peer_id, "move_unreachable", {"target": str(target)})
		return
	interaction.cancel(s)
	# GDD §8.1: andar interrompe a conjuração (skill ou usável).
	progression.on_player_moved(s)
	Net.log_line("move_accepted", {"peer": peer_id, "from": str(from),
			"to": str(mover.get_destination())})


func _on_follower_command(peer: int, command: StringName, id: StringName, text: String) -> void:
	var s: PlayerSession = get_session(peer)
	if s == null:
		return
	var reason: String = ""
	match command:
		&"mount": reason = mounts.request(s, id)
		&"dismount": mounts.dismount(s)
		&"companion": reason = companions.request(s, id)
		&"name": reason = companions.name_companion(s, id, text)
	if not reason.is_empty():
		Net.push_system_message(peer, reason)


func _do_interact(s: PlayerSession, target_id: Variant) -> void:
	if not combat.allow_player_action(s, "interact") or combat.handle_interact(s, str(target_id)):
		return
	interaction.request(s, str(target_id))


func _do_dialogue_choice(s: PlayerSession, index: Variant) -> void:
	dialogue.choose(s, int(index))


func _do_dialogue_close(s: PlayerSession) -> void:
	if not s.has_dialogue():
		Net.log_invalid(s.peer_id, "dialogue_close_without_dialogue")
		return
	dialogue.close(s, true)


func _do_shop_close(s: PlayerSession) -> void:
	if not s.has_shop():
		Net.log_invalid(s.peer_id, "shop_close_without_shop")
		return
	dialogue.close_shop(s, true)


func _do_inventory_move(s: PlayerSession, from_slot: Variant, to_slot: Variant) -> void:
	items.inventory_move(s, int(from_slot), int(to_slot))


func _do_use_item(s: PlayerSession, slot: Variant) -> void:
	if not combat.allow_player_action(s, "use_item"):
		return
	items.use_item(s, int(slot))


func _do_equip(s: PlayerSession, slot: Variant) -> void:
	items.equip(s, int(slot))


func _do_unequip(s: PlayerSession, equip_slot: Variant) -> void:
	items.unequip(s, StringName(str(equip_slot)))


func _do_shop_buy(s: PlayerSession, item_id: Variant, qty: Variant) -> void:
	items.shop_buy(s, StringName(str(item_id)), int(qty))


func _do_shop_sell(s: PlayerSession, slot: Variant, qty: Variant) -> void:
	items.shop_sell(s, int(slot), int(qty))


func _do_chat(s: PlayerSession, channel: Variant, text: Variant) -> void:
	chat.chat(s, StringName(str(channel)), str(text))


func _do_emote(s: PlayerSession, emote_id: Variant) -> void:
	chat.emote(s, StringName(str(emote_id)))


# ---------------------------------------------------------------- tick

func _physics_process(delta: float) -> void:
	# Engine.physics_ticks_per_second = Balance.cfg.server_tick_hz no servidor (main.gd).
	if not _npc_spawn_pending.is_empty():
		_spawn_pending_npcs()
	_attach_missing_grids()
	# 1) decisões (rotinas de NPC), 2) movimento, 3) interações/sessões, 4) replicação privada.
	for e: NetEntity in _entities.values():
		if not is_instance_valid(e):
			continue
		var brain: NpcBrain = get_brain(e)
		if brain != null:
			brain.tick(delta)
	combat.tick(delta)
	for e: NetEntity in _entities.values():
		if is_instance_valid(e):
			e.server_tick(delta)
	zone_rules.tick()
	progression.tick(delta)
	if mounts != null:
		mounts.tick()
	if companions != null:
		companions.tick()
	party.tick()
	trade.tick()
	items.tick()
	for s: PlayerSession in _sessions.values():
		map_transfer.tick_portals(s)
		if Net.get_peer_instance(s.peer_id) != s.entity.instance_id:
			continue
		interaction.tick(s)
		dialogue.check_range(s)
		s.flush()
	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL_SEC:
		_save_timer = 0.0
		_save_all("periodic")
	_tick_admin_state(delta)


func _tick_admin_state(delta: float) -> void:
	_admin_state_timer += delta
	if _admin_state_timer < 1.0:
		return
	_admin_state_timer = 0.0

	var live_players: Array = []
	for s: PlayerSession in _sessions.values():
		if s != null and s.entity != null and is_instance_valid(s.entity):
			var pos: Vector3 = s.entity.net_position
			var st: Dictionary = s.character.compute_stats() if s.character != null else {}
			live_players.append({
				"name": s.character.char_name if s.character != null else "",
				"peer_id": s.peer_id,
				"level": s.character.level if s.character != null else 1,
				"stars": s.character.stars if s.character != null else 0,
				"hp": s.character.hp if s.character != null else 0,
				"max_hp": int(st.get(CharacterStats.K_MAX_HP, 100)),
				"mp": s.character.mp if s.character != null else 0,
				"max_mp": int(st.get(CharacterStats.K_MAX_MP, 50)),
				"instance": String(s.entity.instance_id),
				"map": String(get_instance_map_id(s.entity.instance_id)),
				"pos": [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1), snappedf(pos.z, 0.1)]
			})

	var live_drops: Array = []
	for e: NetEntity in _entities.values():
		if is_instance_valid(e) and e.kind == NetEntity.KIND_DROP:
			var pos: Vector3 = e.net_position
			var qty: int = int(e.appearance.get(DropService.APPEARANCE_QTY, 1)) if e.appearance != null else 1
			live_drops.append({
				"id": e.entity_id,
				"item": String(e.def_id),
				"qty": qty,
				"map": String(get_instance_map_id(e.instance_id)),
				"pos": [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1), snappedf(pos.z, 0.1)]
			})

	var live_dict: Dictionary = {
		"online_count": live_players.size(),
		"players": live_players,
		"drops": live_drops,
		"drops_count": live_drops.size(),
		"instances": _instances.keys().map(func(k: Variant) -> String: return String(k)),
		"server_uptime_sec": int(Time.get_ticks_msec() / 1000.0),
		"timestamp": int(Time.get_unix_time_from_system())
	}

	# Mesmo diretório do TradeService: --state-dir (testes) ou o de autoteste; senão o real. Assim servidores
	# de teste não leem os eventos do painel nem sobrescrevem o live_server.json de verdade.
	var state_dir: String = TradeService.AUTOTEST_STATE_DIR if autotest else TradeService.STATE_DIR
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(TradeService.ARG_STATE_DIR):
			state_dir = a.trim_prefix(TradeService.ARG_STATE_DIR).trim_suffix("/") + "/"
	if not DirAccess.dir_exists_absolute(state_dir):
		DirAccess.make_dir_recursive_absolute(state_dir)
	var live_path: String = state_dir + "live_server.json"
	var f := FileAccess.open(live_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(live_dict, "  "))
		f.close()

	# Ler eventos e decorações ativas configuradas pelo painel admin
	var events_path: String = state_dir + "active_events.json"
	if FileAccess.file_exists(events_path):
		var ef := FileAccess.open(events_path, FileAccess.READ)
		if ef != null:
			var text: String = ef.get_as_text()
			ef.close()
			var parsed: Variant = JSON.parse_string(text)
			if typeof(parsed) == TYPE_DICTIONARY:
				var events: Dictionary = parsed.get("events", {})
				var max_xp: float = 1.0
				var max_drop: float = 1.0
				for ev_val: Variant in events.values():
					if typeof(ev_val) == TYPE_DICTIONARY:
						var ev: Dictionary = ev_val
						if bool(ev.get("active", false)):
							var x: float = float(ev.get("xp_mult", 1.0))
							var d: float = float(ev.get("drop_mult", 1.0))
							if x > max_xp: max_xp = x
							if d > max_drop: max_drop = d
				event_xp_mult = max_xp
				event_drop_mult = max_drop
				active_decorations = parsed.get("active_decorations", {})
				# Painel antigo pode ter ids renomeados (ex. o broche da nação): LegacyIds.
				active_cosmetics = LegacyIds.migrate(parsed.get("active_cosmetics", {}))

				var bcast: String = str(parsed.get("broadcast_message", "")).strip_edges()
				if not bcast.is_empty() and bcast != _last_broadcast_msg:
					_last_broadcast_msg = bcast
					Net.log_line("admin_broadcast", {"message": bcast})
					for p_id: int in Net.get_world_peer_ids():
						Net.push_system_message(p_id, bcast)


## Entidades criadas antes do navmesh sincronizar ganham a grade assim que ela existir.
func _attach_missing_grids() -> void:
	for e: NetEntity in _entities.values():
		if not is_instance_valid(e):
			continue
		var mover: GridMover = e.get_mover()
		if mover != null and mover.grid == null:
			mover.grid = get_grid_for_instance(e.instance_id)


# ---------------------------------------------------------------- autoteste

## Autoteste: registra cada caminho novo do jogador (o run_autotest.sh compara com o que os
## clientes mostraram no mesmo instante do relógio do servidor).
func _watch_path_for_autotest(mover: GridMover) -> void:
	if not autotest or mover.path_changed.is_connected(_log_path):
		return
	mover.path_changed.connect(_log_path.bind(mover))


func _log_path(mover: GridMover) -> void:
	var p: MovePath = mover.get_move_path()
	var e: NetEntity = mover.get_entity()
	if p == null or e == null:
		return
	var pts: Array = []
	for v: Vector3 in p.points:
		pts.append([snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)])
	Net.log_line("autotest_path", {"entity": e.entity_id, "issued": NetClock.server_now_msec(),
			"start": p.start_msec,
			"ms_per_cell": p.ms_per_cell, "points": pts, "times": Array(p.times)})


## Cria uma segunda instância (caça, mesmo mapa) com uma entidade "fantasma" que nenhum cliente
## pode receber, e encerra o servidor após AUTOTEST_DURATION_SEC.
func _setup_autotest() -> void:
	var ghost_instance: StringName = Net.make_instance_id(START_MAP_ID, AUTOTEST_PARTY_ID)
	if get_or_create_instance(ghost_instance, START_MAP_ID) == null:
		return
	_ghost = _entity_scene.instantiate() as NetEntity
	_ghost.server_setup(AUTOTEST_GHOST_ENTITY_ID, NetEntity.KIND_PLAYER, AUTOTEST_GHOST_NAME,
			Net.DEFAULT_BODY_TYPE, ghost_instance, _get_spawn_point(ghost_instance))
	_ghost.server_ensure_mover(get_grid_for_instance(ghost_instance), Balance.cfg.walk_ms_per_cell)
	_add_entity(_ghost)
	Net.log_line("autotest_ghost_created", {"instance": String(ghost_instance),
			"node": String(_ghost.get_path()), "id": AUTOTEST_GHOST_ENTITY_ID})
	var t := Timer.new()
	t.wait_time = AUTOTEST_GHOST_INTERVAL_SEC
	t.autostart = true
	t.timeout.connect(_autotest_move_ghost)
	add_child(t)
	get_tree().create_timer(AUTOTEST_DURATION_SEC).timeout.connect(_autotest_quit)


func _autotest_move_ghost() -> void:
	_ghost.get_mover().move_to(_ghost.net_position + AUTOTEST_GHOST_STEP * _ghost_dir)
	_ghost_dir = -_ghost_dir


## Relê o save gravado no logout e compara com o estado em memória.
func _autotest_check_save(c: CharacterData) -> void:
	var loaded: CharacterData = store.load_character(c.char_name)
	var ok: bool = loaded != null and loaded.stars == c.stars \
			and JSON.stringify(loaded.inventory.to_save()) == JSON.stringify(c.inventory.to_save()) \
			and loaded.equipment.to_client() == c.equipment.to_client() \
			and loaded.once_flags == c.once_flags
	Net.log_line("autotest_save_roundtrip", {"pass": ok, "name": c.char_name, "stars": c.stars,
			"equipment": c.equipment.to_client(), "once_flags": c.once_flags.keys()})


func _autotest_quit() -> void:
	_save_all("shutdown")
	Net.log_line("autotest_server_done", {"players": _sessions.size()})
	get_tree().quit()
