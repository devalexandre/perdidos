class_name ZoneRules
extends RefCounted
## Regras de zona no servidor (GDD §4.1, §9.3, §12; contrato arrival, "Fluxo e navegação"), a partir
## do ZoneDef do mapa (data/zones/<map_id>.tres):
##   - teto de XP (xp_allowed, chamado por Q antes de dar XP);
##   - combate permitido (combat_allowed, consultado por K);
##   - itens presos à zona: Inventory.bind_zone marca tudo o que entra; purge_bound_items remove;
##   - morte e renascimento (sinal player_killed de K): renasce no respawn_marker, sem Marca da Alma
##     no treino (a Marca da Alma das outras zonas fica para a F3).
## Criado pelo ServerWorld (world.zone_rules).

## Emitido depois de reposicionar e curar um jogador morto.
signal player_respawned(peer_id: int)

## Espera entre a morte e o renascimento (s).
const RESPAWN_DELAY_SEC: float = 3.0
## GDD §4.4: renasce com 50% de vida e mana.
const RESPAWN_HP_FRACTION: float = 0.5
const RESPAWN_MP_FRACTION: float = 0.5
## Sinal de morte de jogador publicado por K em world.combat.
const COMBAT_PROP: StringName = &"combat"
const SIGNAL_PLAYER_KILLED: StringName = &"player_killed"
## K: CombatService.revive(peer_id, position, hp_fraction) (limpa o estado de morto de K).
const METHOD_REVIVE: StringName = &"revive"
## Mapa do Campo de Treino e regras usadas enquanto data/zones/training_field.tres não existir.
const TRAINING_MAP_ID: StringName = &"training_field"
const TRAINING_FALLBACK_XP_CAP: int = 10
## Sistema: chaves de localization/world.csv.
const MSG_RESPAWNED: String = "WORLD_RESPAWNED"

var world: ServerWorld = null
## peer_id -> msec em que renasce (mortos esperando).
var _respawn_at: Dictionary[int, int] = {}
var _fallback_training: ZoneDef = null


func _init(p_world: ServerWorld) -> void:
	world = p_world
	_fallback_training = ZoneDef.new()
	_fallback_training.map_id = TRAINING_MAP_ID
	_fallback_training.kind = ZoneDef.Kind.TRAINING
	_fallback_training.xp_level_cap = TRAINING_FALLBACK_XP_CAP
	_fallback_training.items_bound_to_zone = true
	_fallback_training.grave_on_death = false


# ---------------------------------------------------------------- consultas

## ZoneDef do mapa (ou o padrão do treino se W ainda não criou o arquivo). Pode ser null.
func zone_for_map(map_id: StringName) -> ZoneDef:
	var z: ZoneDef = Content.zone(map_id)
	if z == null and map_id == TRAINING_MAP_ID:
		return _fallback_training
	return z


func zone_for_instance(instance_id: StringName) -> ZoneDef:
	return zone_for_map(world.get_instance_map_id(instance_id))


func is_training(map_id: StringName) -> bool:
	var z: ZoneDef = zone_for_map(map_id)
	return z != null and z.kind == ZoneDef.Kind.TRAINING


## Q: pode ganhar XP agora? false quando o nível já chegou ao teto do mapa em que está.
func xp_allowed(peer_id: int) -> bool:
	var s: PlayerSession = world.get_session(peer_id)
	if s == null:
		return false
	var z: ZoneDef = zone_for_instance(s.entity.instance_id)
	if z == null or z.xp_level_cap <= 0:
		return true
	return s.character.level < z.xp_level_cap


## K: combate permitido na instância? (sem ZoneDef = permitido)
func combat_allowed(instance_id: StringName) -> bool:
	var z: ZoneDef = zone_for_instance(instance_id)
	return z == null or z.combat_allowed


# ---------------------------------------------------------------- itens presos à zona

## Chamado ao colocar o jogador num mapa: itens obtidos daqui em diante ficam marcados (ou não).
func on_player_entered(session: PlayerSession, map_id: StringName) -> void:
	var z: ZoneDef = zone_for_map(map_id)
	session.character.inventory.bind_zone = map_id if z != null and z.items_bound_to_zone else &""


## Remove do inventário e do equipamento todas as pilhas presas a map_id. Devolve os ids removidos.
func purge_bound_items(c: CharacterData, map_id: StringName) -> Array[String]:
	var removed: Array[String] = []
	for slot: int in c.inventory.size():
		var st: ItemStack = c.inventory.get_slot(slot)
		if st != null and st.bound_zone == map_id:
			c.inventory.replace_at(slot, null)
			removed.append("%s x%d" % [st.item_id, st.qty])
	for eslot: StringName in Equipment.SLOTS:
		var st: ItemStack = c.equipment.get_slot(eslot)
		if st != null and st.bound_zone == map_id:
			c.equipment.set_slot(eslot, null)
			removed.append("%s (%s)" % [st.item_id, eslot])
	c.inventory.bind_zone = &""
	return removed


# ---------------------------------------------------------------- morte

## Liga o sinal de morte de K (world.combat.player_killed), se já existir.
func connect_combat() -> void:
	var combat: Variant = world.get(COMBAT_PROP)
	if combat == null or not (combat is Object) or not (combat as Object).has_signal(SIGNAL_PLAYER_KILLED):
		Net.log_line("zone_rules_no_combat", {})
		return
	var cb := Callable(self, &"on_player_killed")
	if not (combat as Object).is_connected(SIGNAL_PLAYER_KILLED, cb):
		(combat as Object).connect(SIGNAL_PLAYER_KILLED, cb)
		Net.log_line("zone_rules_combat_connected", {})


## Morte de um jogador (K emite). Agenda o renascimento conforme a zona.
func on_player_killed(victim_peer: int, killer_entity: int) -> void:
	var s: PlayerSession = world.get_session(victim_peer)
	if s == null or _respawn_at.has(victim_peer):
		return
	var z: ZoneDef = zone_for_instance(s.entity.instance_id)
	_respawn_at[victim_peer] = Time.get_ticks_msec() + int(RESPAWN_DELAY_SEC * 1000.0)
	Net.log_line("player_died", {"peer": victim_peer, "killer": killer_entity,
			"instance": String(s.entity.instance_id),
			"grave": z != null and z.grave_on_death, "respawn_in_sec": RESPAWN_DELAY_SEC})


## Por tick do servidor: renasce quem já esperou.
func tick() -> void:
	if _respawn_at.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	for peer_id: int in _respawn_at.keys():
		if now < _respawn_at[peer_id]:
			continue
		_respawn_at.erase(peer_id)
		var s: PlayerSession = world.get_session(peer_id)
		if s != null:
			respawn(s)


func forget(peer_id: int) -> void:
	_respawn_at.erase(peer_id)


## Põe o jogador no marcador de renascimento da zona com 50% de vida e mana. Com cidade salva na Dona Ana
## (MapTransfer.respawn_city_of), renasce ao lado dela: na mesma cidade, ali mesmo; em outro mapa, é levado.
func respawn(s: PlayerSession) -> void:
	var instance_id: StringName = s.entity.instance_id
	var pos: Vector3 = respawn_point(instance_id)
	var home: StringName = world.map_transfer.respawn_city_of(s)
	var here: StringName = world.get_instance_map_id(instance_id)
	if home == here:
		pos = _marker_point(instance_id, WaystoneService.ARRIVAL_MARKER, pos)
	world.interaction.cancel(s)
	var stats: Dictionary = s.character.compute_stats()
	s.character.mp = int(stats[CharacterStats.K_MAX_MP] * RESPAWN_MP_FRACTION)
	var combat: Variant = world.get(COMBAT_PROP)
	if combat is Object and combat != null and (combat as Object).has_method(METHOD_REVIVE):
		(combat as Object).call(METHOD_REVIVE, s.peer_id, pos, RESPAWN_HP_FRACTION)
	else:
		s.entity.get_mover().place(world.snap_to_grid(instance_id, pos))
		s.character.hp = maxi(1, int(stats[CharacterStats.K_MAX_HP] * RESPAWN_HP_FRACTION))
	s.entity.anim = NetEntity.ANIM_IDLE
	s.mark_dirty(PlayerSession.DIRTY_STATS)
	Net.push_system_message(s.peer_id, MSG_RESPAWNED)
	Net.log_line("player_respawned", {"peer": s.peer_id, "instance": String(instance_id),
			"pos": str(s.entity.net_position), "hp": s.character.hp, "home": String(home)})
	player_respawned.emit(s.peer_id)
	if not home.is_empty() and home != here:
		world.map_transfer.transfer(s, home, WaystoneService.ARRIVAL_MARKER)


## Posição do Marker3D da raiz do mapa da instância; sem ele, fallback.
func _marker_point(instance_id: StringName, marker: StringName, fallback: Vector3) -> Vector3:
	var map_node: Node = world.get_map_node(instance_id)
	var m := map_node.get_node_or_null(NodePath(String(marker))) as Node3D if map_node != null else null
	return m.global_position if m != null else fallback


## Posição do respawn_marker do ZoneDef (procurado em qualquer profundidade do mapa); sem ele, o
## SpawnPoint do mapa.
func respawn_point(instance_id: StringName) -> Vector3:
	var z: ZoneDef = zone_for_instance(instance_id)
	var map_node: Node = world.get_map_node(instance_id)
	if z != null and map_node != null and not z.respawn_marker.is_empty():
		var m: Node3D = map_node.find_child(String(z.respawn_marker), true, false) as Node3D
		if m != null:
			return m.global_position
	return world.get_spawn_point(instance_id)
