class_name MapTransfer
extends RefCounted
## Fluxo de chegada e troca de mapa no servidor (GDD §5.1, §9.3; contrato arrival, "Fluxo e
## navegação"). Criado pelo ServerWorld (world.map_transfer).
##   - Entrada: personagem novo (ou que ainda não saiu do treino) → training_field; quem já saiu →
##     home_map (start_map_id do título inicial; padrão a cidade).
##   - Troca de mapa autoritativa: esconde tudo do peer, manda enter_instance e o ServerWorld
##     reposiciona a entidade quando o cliente confirma (_on_peer_instance_ready).
##   - Portal de saída do Campo de Treino: exige o título inicial (Q), remove os itens do treino,
##     grava left_training e leva à cidade do título. Não há volta.
##   - Personalização (ADENDO 2): a aparência mandada por NetWorld.send_appearance é validada com
##     CustomizationOptions na criação do personagem.

const TRAINING_MAP_ID: StringName = ZoneRules.TRAINING_MAP_ID
const MAP_SCENE_DIR: String = "res://scenes/maps/"
const MAP_SCENE_EXT: String = ".tscn"
## Covil original da fuga após chefe (mensagens próprias da Fenda de Luz).
const CAVE_ESCAPE_MAP_ID: StringName = &"cave_reino_encoberto_4"
## Argumentos (depois de "--"): com --autotest o servidor mantém o fluxo antigo (personagem novo
## direto na cidade) a menos que --training-flow seja passado; --world-debug liga os comandos de teste.
const ARG_TRAINING_FLOW: String = "training-flow"
const ARG_WORLD_DEBUG: String = "world-debug"
## Q: título inicial do jogador (ver Apêndice N do contrato).
const PROGRESSION_PROP: StringName = &"progression"
const Q_INITIAL_TITLE: StringName = &"initial_title"
const Q_TITLE_LISTS: Array[StringName] = [&"get_titles", &"titles", &"get_earned_titles"]
# Mensagens (localization/world.csv).
const MSG_NEED_TITLE: String = "SYS_WORLD_PORTAL_NEED_TITLE"
const MSG_TRAINING_LEFT: String = "WORLD_TRAINING_LEFT"
const MSG_TRANSFER_FAILED: String = "SYS_WORLD_TRANSFER_FAILED"
const PORTAL_WALK_RADIUS: float = 1.6
## Comandos de teste e quantos argumentos exigem.
const DEBUG_ARG_COUNT: Dictionary[StringName, int] = {&"give_item": 2, &"grant_xp": 2,
		&"grant_title": 1, &"die": 0, &"report": 0}
const DEBUG_XP_REASON: StringName = &"world_debug"

var world: ServerWorld = null
## Personagem novo vai direto para a cidade (autoteste antigo do city-walk).
var skip_training: bool = false
## peer_id -> personagem já lido do save no handshake (para escolher o mapa de entrada).
var _loaded: Dictionary[int, CharacterData] = {}
var _arrival_markers: Dictionary[int, StringName] = {}
## peer_id -> aparência mandada pelo cliente (usada só se o personagem for criado agora).
var _appearance: Dictionary[int, Dictionary] = {}
## peer_id -> título inicial concedido por comando de teste (enquanto Q não existir).
var _debug_titles: Dictionary[int, StringName] = {}
## Portais ocupados: ativa só na entrada, sem repetir avisos ou voltar ao nascer no destino.
var _occupied_portals: Dictionary[int, Dictionary] = {}
var _cleared_cave_instances: Dictionary[StringName, bool] = {}
## map_id -> ids dos chefes dos covis (BossLairs/) do mapa, lidos da cena uma vez.
var _lair_bosses: Dictionary[StringName, Array] = {}


func _init(p_world: ServerWorld) -> void:
	world = p_world
	var args: Dictionary = world.main_node.call("parse_user_args") if world.main_node != null else {}
	skip_training = world.autotest and not args.has(ARG_TRAINING_FLOW)
	NetWorld.debug_enabled = world.autotest and args.has(ARG_WORLD_DEBUG)
	NetWorld.appearance_received.connect(_on_appearance_received)
	if world.combat != null:
		world.combat.monster_killed_info.connect(_on_cave_boss_killed)
	Net.log_line("map_transfer_ready", {"skip_training": skip_training,
			"debug": NetWorld.debug_enabled})


# ---------------------------------------------------------------- entrada

static func map_exists(map_id: StringName) -> bool:
	return not map_id.is_empty() and ResourceLoader.exists(MAP_SCENE_DIR + String(map_id) + MAP_SCENE_EXT)


## Mapa de entrada do peer que acabou de fazer o handshake (lê o save agora).
func entry_map_for(peer_id: int) -> StringName:
	var char_name: String = Net.get_peer_display_name(peer_id)
	var c: CharacterData = world.store.load_character(char_name)
	if c != null:
		_loaded[peer_id] = c
	var map_id: StringName = home_map_of(c) if c != null and c.left_training else TRAINING_MAP_ID
	if c == null and skip_training:
		map_id = ServerWorld.START_MAP_ID
	if not map_exists(map_id):
		Net.log_line("entry_map_missing", {"peer": peer_id, "map": String(map_id)})
		map_id = ServerWorld.START_MAP_ID
	Net.log_line("entry_map_chosen", {"peer": peer_id, "name": char_name, "map": String(map_id),
			"existing": c != null, "left_training": c.left_training if c != null else false})
	return map_id


func home_map_of(c: CharacterData) -> StringName:
	return c.home_map if map_exists(c.home_map) else ServerWorld.START_MAP_ID


## GDD §5.1 (decisão do dono em 30/09/2026): todo mapa tem uma instância só, compartilhada por todos
## (cidade, Campo de Treino, caça e PVP): instance_id = map_id. O grupo não cria cópia.
func instance_id_for(map_id: StringName, _char_name: String = "") -> StringName:
	if map_id == &"elder_trial_arena":
		return Net.make_instance_id(map_id, _char_name.to_lower())
	return Net.make_instance_id(map_id)


## Personagem do peer: o lido no handshake, ou um novo com a aparência validada.
func load_or_create(peer_id: int) -> CharacterData:
	var char_name: String = Net.get_peer_display_name(peer_id)
	var c: CharacterData = _loaded.get(peer_id)
	_loaded.erase(peer_id)
	if c == null:
		c = world.store.load_character(char_name)
	if c != null:
		Net.log_line("character_loaded", {"peer": peer_id, "name": char_name, "stars": c.stars,
				"left_training": c.left_training, "home": String(c.home_map)})
		_appearance.erase(peer_id)
		return c
	c = CharacterData.create_new(char_name, Net.get_peer_body_type(peer_id))
	c.custom_appearance = validated_appearance(_appearance.get(peer_id, {}), c.body_type, peer_id)
	_appearance.erase(peer_id)
	if skip_training:
		c.left_training = true
		c.home_map = ServerWorld.START_MAP_ID
	world.store.save_character(c)
	Net.log_line("character_created", {"peer": peer_id, "name": char_name, "stars": c.stars,
			"appearance": c.custom_appearance, "left_training": c.left_training,
			"inventory": c.inventory.to_save().filter(func(s: Dictionary) -> bool: return not s.is_empty())})
	return c


## ADENDO 2: valida contra data/customization/options.tres (sem o arquivo: aparência padrão = {}).
func validated_appearance(raw: Dictionary, body: StringName, peer_id: int) -> Dictionary:
	var opts: CustomizationOptions = CustomizationOptions.get_default()
	if opts == null:
		if not raw.is_empty():
			Net.log_line("appearance_ignored_no_options", {"peer": peer_id})
		return {}
	var with_body: Dictionary = raw.duplicate()
	with_body[CustomizationOptions.KEY_BODY] = body
	var clean: Dictionary = opts.sanitize(with_body)
	if not raw.is_empty() and not opts.is_valid(with_body):
		Net.log_invalid(peer_id, "appearance_invalid", {"sent": str(raw), "used": str(clean)})
	clean.erase(CustomizationOptions.KEY_BODY)
	return clean


func _on_appearance_received(peer_id: int, appearance: Dictionary) -> void:
	_appearance[peer_id] = appearance
	Net.log_line("appearance_received", {"peer": peer_id, "appearance": appearance})


func forget(peer_id: int) -> void:
	_occupied_portals.erase(peer_id)
	_loaded.erase(peer_id)
	_arrival_markers.erase(peer_id)
	_appearance.erase(peer_id)
	_debug_titles.erase(peer_id)


## Chamado pelo ServerWorld quando a entidade do jogador acabou de entrar numa instância.
func on_player_placed(session: PlayerSession) -> void:
	if world.mounts != null:
		world.mounts.cancel(session)
		if not world.mounts.zone_allowed(session):
			world.mounts.dismount(session)
	if world.companions != null:
		world.companions.cancel(session)
		world.refresh_appearance(session)
	_occupied_portals[session.peer_id] = _portals_at_player(session)
	var map_id: StringName = world.get_instance_map_id(session.entity.instance_id)
	world.zone_rules.on_player_entered(session, map_id)
	# Pergaminho de Retorno: lembra a última cidade em que entrou.
	var zone: ZoneDef = world.zone_rules.zone_for_map(map_id)
	if zone != null and zone.kind == ZoneDef.Kind.CITY and session.character.last_city != map_id:
		session.character.last_city = map_id
		session.save_pending = true
	NetWorld.push_zone_changed(session.peer_id, map_id)
	world.progression.quests.on_player_placed(session)
	Net.log_line("player_entered_map", {"peer": session.peer_id, "map": String(map_id),
			"instance": String(session.entity.instance_id),
			"bind_zone": String(session.character.inventory.bind_zone)})


# ---------------------------------------------------------------- Pergaminho de Retorno

## Cidade para onde o Pergaminho de Retorno leva: a cidade salva com a Dona Ana; sem ela, a última cidade
## visitada (last_city, que muda sozinho ao entrar numa cidade); sem nenhuma, a cidade inicial.
func return_city_of(c: CharacterData) -> StringName:
	var saved: StringName = WaystoneService.saved_city(c)
	if map_exists(saved):
		return saved
	if map_exists(c.last_city):
		return c.last_city
	return home_map_of(c)


## Ponto de chegada do Pergaminho de Retorno: ao lado da Dona Ana na cidade salva; senão o SpawnPoint.
func return_marker_of(c: CharacterData) -> StringName:
	return WaystoneService.ARRIVAL_MARKER if map_exists(WaystoneService.saved_city(c)) else &"SpawnPoint"


## Cidade onde o jogador caído renasce: a salva com a Dona Ana (ao lado dela). &"" = renasce no ponto
## seguro da própria zona, como antes (sem cidade salva, PVP, Campo de Treino ou provação em andamento).
func respawn_city_of(session: PlayerSession) -> StringName:
	var saved: StringName = WaystoneService.saved_city(session.character)
	if not map_exists(saved):
		return &""
	var zone: ZoneDef = world.zone_rules.zone_for_instance(session.entity.instance_id)
	if zone != null and zone.kind in [ZoneDef.Kind.PVP, ZoneDef.Kind.TRAINING]:
		return &""
	if world.progression != null and world.progression.quests.has_trial(session.peer_id):
		return &""
	return saved


# ---------------------------------------------------------------- troca de mapa

## O ponto de aproximação é a parte caminhável da entrada (alguns portais são decorativos).
static func is_on_portal(position: Vector3, obj: Dictionary) -> bool:
	if StringName(str(obj.get("type", ""))) != &"portal":
		return false
	var meta: Dictionary = obj.get("meta", {})
	var center: Vector3 = meta.get(&"approach_position", obj.get("position", Vector3.INF))
	return Vector2(position.x, position.z).distance_to(Vector2(center.x, center.z)) <= PORTAL_WALK_RADIUS


func _portals_at_player(session: PlayerSession) -> Dictionary:
	var found: Dictionary = {}
	var objects: Dictionary = world.get_interactables(session.entity.instance_id)
	for id: Variant in objects:
		var obj: Dictionary = objects[id]
		if is_on_portal(session.entity.net_position, obj):
			found[id] = obj
	return found


## Executado depois do movimento autoritativo; independe do dispositivo de entrada.
func tick_portals(session: PlayerSession) -> void:
	if session.entity == null or not is_instance_valid(session.entity):
		return
	if Net.get_peer_instance(session.peer_id) != session.entity.instance_id or world.combat.is_dead(session.peer_id):
		return
	var occupied: Dictionary = _portals_at_player(session)
	var previous: Dictionary = _occupied_portals.get(session.peer_id, {})
	_occupied_portals[session.peer_id] = occupied
	for id: Variant in occupied:
		if previous.has(id):
			continue
		if handle_portal(session, occupied[id]):
			return
		var meta: Dictionary = (occupied[id] as Dictionary).get("meta", {})
		Net.push_system_message(session.peer_id, SysMsg.PORTAL_CLOSED, [str(meta.get(&"recommended_level", ""))])

## Portal com requires_quest: aberto se a quest já foi feita, está ativa ou pode ser aceita agora.
func story_passage_open(session: PlayerSession, quest_id: StringName) -> bool:
	var quests: QuestService = world.progression.quests if world.progression != null else null
	var q: QuestDef = Content.quest(quest_id)
	if quests == null or q == null:
		return false
	return quests.is_done(session, quest_id) or quests.is_active(session, quest_id) or quests.is_available(session, q)


## Leva o jogador a map_id (instância única do mapa, §5.1). false = mapa inexistente.
func transfer(session: PlayerSession, map_id: StringName, arrival_marker: StringName = &"SpawnPoint") -> bool:
	var instance_id: StringName = instance_id_for(map_id, session.character.char_name)
	if not map_exists(map_id) or world.get_or_create_instance(instance_id, map_id) == null:
		Net.log_invalid(session.peer_id, "transfer_failed", {"map": String(map_id)})
		Net.push_system_message(session.peer_id, MSG_TRANSFER_FAILED)
		return false
	_arrival_markers[session.peer_id] = arrival_marker
	var old_instance: StringName = session.entity.instance_id
	world.dialogue.close(session, true)
	world.dialogue.close_shop(session, true)
	world.interaction.cancel(session)
	session.entity.get_mover().halt()
	# Some tudo da instância antiga para o peer antes de o cliente desmontar a subárvore.
	Net.set_peer_instance(session.peer_id, &"")
	world.update_instance_visibility_for(old_instance, session.peer_id)
	Net.send_enter_instance(session.peer_id, instance_id, map_id)
	Net.log_line("map_transfer", {"peer": session.peer_id, "from": String(old_instance),
			"to": String(instance_id), "map": String(map_id)})
	return true


## Portal (Interactables, interact_type &"portal"). true = tratado aqui (o InteractionService não
## mostra o aviso de portal fechado).
func handle_portal(session: PlayerSession, obj: Dictionary) -> bool:
	# Clique e passagem podem chegar no mesmo tick; não inicia outra troca durante a carga.
	if Net.get_peer_instance(session.peer_id) != session.entity.instance_id:
		return true
	var map_id: StringName = world.get_instance_map_id(session.entity.instance_id)
	if not world.zone_rules.is_training(map_id):
		var meta: Dictionary = obj.get("meta", {})
		if bool(meta.get(&"requires_boss_victory", false)) and not _cleared_cave_instances.get(session.entity.instance_id, false):
			Net.push_system_message(session.peer_id, "SYS_CAVE_BOSS_GATE" if map_id == CAVE_ESCAPE_MAP_ID else "SYS_BOSS_ESCAPE_GATE")
			return true
		# Passagem da história (Arco 1, andar 5 da Caverna): só para quem tem a quest disponível, ativa ou feita.
		var needs_quest := StringName(str(meta.get(&"requires_quest", "")))
		if not needs_quest.is_empty() and not story_passage_open(session, needs_quest):
			Net.push_system_message(session.peer_id, "SYS_STORY_PASSAGE_SEALED")
			return true
		var dest := StringName(str(meta.get(&"target_map", "")))
		var zone: ZoneDef = world.zone_rules.zone_for_map(map_id)
		if not portal_allowed(zone, dest):
			return false
		transfer(session, dest, StringName(str(meta.get(&"target_spawn", "SpawnPoint"))))
		return true
	var title_id: StringName = initial_title(session.peer_id)
	if title_id.is_empty():
		Net.log_invalid(session.peer_id, "portal_without_title", {"portal": str(obj.get("meta", {}).get(&"interact_id", ""))})
		Net.push_system_message(session.peer_id, MSG_NEED_TITLE)
		return true
	var title: TitleDef = Content.title(title_id)
	var dest: StringName = title.start_map_id if title != null else &""
	if not map_exists(dest):
		dest = ServerWorld.START_MAP_ID
	exit_training(session, map_id, dest, title_id)
	return true


## Destinos vêm dos metadados do mapa no servidor; conexões são explícitas.
static func portal_allowed(source: ZoneDef, destination: StringName) -> bool:
	return source != null and destination in source.connected_maps \
			and destination != TRAINING_MAP_ID and map_exists(destination)


## Saída de fuga (portal one_way + requires_boss_victory): abre na instância quando morre, como chefe,
## um monstro de um covil (BossLairs/) daquele mapa.
func _on_cave_boss_killed(_peer_id: int, monster_id: StringName, info: Dictionary) -> void:
	if not bool(info.get("boss", false)):
		return
	var map_id := StringName(str(info.get("map_id", "")))
	if map_id.is_empty() or not (monster_id in _bosses_of_lairs(map_id)):
		return
	var instance_id := StringName(str(info.get("instance_id", "")))
	if instance_id.is_empty() or _cleared_cave_instances.has(instance_id):
		return
	_cleared_cave_instances[instance_id] = true
	Net.log_line("cave_surface_unlocked", {"instance": String(instance_id), "map": String(map_id)})
	var msg: String = "SYS_CAVE_SURFACE_OPEN" if map_id == CAVE_ESCAPE_MAP_ID else "SYS_BOSS_ESCAPE_OPEN"
	for peer: int in Net.get_instance_peer_ids(instance_id):
		Net.push_system_message(peer, msg)


func _bosses_of_lairs(map_id: StringName) -> Array:
	if _lair_bosses.has(map_id):
		return _lair_bosses[map_id]
	var out: Array = []
	var path: String = MAP_SCENE_DIR + String(map_id) + MAP_SCENE_EXT
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	var map: Node = packed.instantiate() if packed != null else null
	# Covis de espécie e, à noite, o do chefe da história (andar 4 da Caverna: o Lobisomem da história também abre a fuga).
	for node_path: NodePath in [^"BossLairs", ^"StoryLairs"]:
		var lairs: Node = map.get_node_or_null(node_path) if map != null else null
		if lairs == null:
			continue
		for m: Node in lairs.get_children():
			var mid := StringName(str(m.get_meta(&"monster_id", "")))
			if not mid.is_empty():
				out.append(mid)
	if map != null:
		map.free()
	_lair_bosses[map_id] = out
	return out


func take_arrival_point(peer_id: int, instance_id: StringName) -> Vector3:
	var marker_name: StringName = _arrival_markers.get(peer_id, &"SpawnPoint")
	_arrival_markers.erase(peer_id)
	var map_node: Node = world.get_map_node(instance_id)
	var marker := map_node.get_node_or_null(NodePath(String(marker_name))) as Marker3D if map_node != null else null
	return marker.global_position if marker != null else world.get_spawn_point(instance_id)


## Sai do treino: remove os itens presos, grava e leva à cidade do título.
func exit_training(session: PlayerSession, training_map: StringName, dest: StringName,
		title_id: StringName) -> void:
	var c: CharacterData = session.character
	var removed: Array[String] = world.zone_rules.purge_bound_items(c, training_map)
	c.left_training = true
	c.home_map = dest
	world.refresh_appearance(session)
	var ok: bool = world.store.save_character(c)
	Net.log_line("training_exit", {"peer": session.peer_id, "title": String(title_id),
			"dest": String(dest), "removed": removed, "saved": ok,
			"inventory": c.inventory.to_save().filter(func(s: Dictionary) -> bool: return not s.is_empty()),
			"equipment": c.equipment.to_client()})
	Net.push_system_message(session.peer_id, MSG_TRAINING_LEFT, [removed.size()])
	transfer(session, dest)


# ---------------------------------------------------------------- título inicial (Q)

## Título inicial conquistado (&"" = nenhum). Usa world.progression de Q; senão o de teste.
func initial_title(peer_id: int) -> StringName:
	var prog: Variant = world.get(PROGRESSION_PROP)
	if prog is Object and prog != null:
		var p: Object = prog
		if p.has_method(Q_INITIAL_TITLE):
			var t: StringName = StringName(str(p.call(Q_INITIAL_TITLE, peer_id)))
			if not t.is_empty():
				return t
		for m: StringName in Q_TITLE_LISTS:
			if not p.has_method(m):
				continue
			var list: Variant = p.call(m, peer_id)
			if list is Array:
				for id: Variant in list:
					var def: TitleDef = Content.title(StringName(str(id)))
					if def != null and not def.start_map_id.is_empty():
						return def.id
	return _debug_titles.get(peer_id, &"")


# ---------------------------------------------------------------- comandos de teste

## Só com --autotest --world-debug (NetWorld.debug_enabled).
func debug_command(session: PlayerSession, cmd: StringName, args: Array) -> void:
	var c: CharacterData = session.character
	if not DEBUG_ARG_COUNT.has(cmd) or args.size() < DEBUG_ARG_COUNT[cmd]:
		Net.log_invalid(session.peer_id, "debug_bad_command", {"cmd": String(cmd)})
		return
	match cmd:
		&"give_item":
			var ok: bool = c.inventory.add(StringName(str(args[0])), int(args[1]))
			Net.log_line("debug_give_item", {"peer": session.peer_id, "item": str(args[0]), "ok": ok})
		&"grant_xp":
			# XP de verdade pelo Q (que consulta ZoneRules.xp_allowed): args = [vezes, quantidade].
			var prog: Variant = world.get(PROGRESSION_PROP)
			if prog is Object and prog != null and (prog as Object).has_method(&"grant_xp"):
				for i: int in int(args[0]):
					(prog as Object).call(&"grant_xp", session.peer_id, int(args[1]), DEBUG_XP_REASON)
			Net.log_line("debug_grant_xp", {"peer": session.peer_id, "level": c.level,
					"xp_allowed": world.zone_rules.xp_allowed(session.peer_id)})
		&"grant_title":
			var id := StringName(str(args[0]))
			var prog: Variant = world.get(PROGRESSION_PROP)
			var titles: Variant = (prog as Object).get(&"titles") if prog is Object and prog != null else null
			if titles is Object and titles != null and (titles as Object).has_method(&"grant"):
				(titles as Object).call(&"grant", session, id)
			_debug_titles[session.peer_id] = id
			Net.log_line("debug_grant_title", {"peer": session.peer_id, "title": String(id),
					"initial": String(initial_title(session.peer_id))})
		&"die":
			world.zone_rules.on_player_killed(session.peer_id, 0)
		&"report":
			Net.log_line("debug_report", {"peer": session.peer_id, "level": c.level,
					"xp_allowed": world.zone_rules.xp_allowed(session.peer_id),
					"combat_allowed": world.zone_rules.combat_allowed(session.entity.instance_id),
					"instance": String(session.entity.instance_id),
					"left_training": c.left_training, "home": String(c.home_map),
					"bind_zone": String(c.inventory.bind_zone),
					"inventory": c.inventory.to_save().filter(func(s: Dictionary) -> bool: return not s.is_empty()),
					"equipment": c.equipment.to_client(), "appearance": session.entity.appearance})
		_:
			Net.log_invalid(session.peer_id, "debug_unknown", {"cmd": String(cmd)})
