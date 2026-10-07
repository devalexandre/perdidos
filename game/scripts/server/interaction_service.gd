class_name InteractionService
extends RefCounted
## req_interact (contrato city-walk, "Clique e interação"): valida o alvo na MESMA instância; se
## estiver longe, anda pela grade (GridMover) até uma célula a Balance.cfg.interact_range do alvo e
## executa ao chegar ao alcance (parando na célula seguinte, sem voltar).
##   "e:<entity_id>"  NPC -> diálogo (ou loja, se só tiver loja)
##   "m:<interact_id>" objeto do mapa -> sit (senta virado para o yaw do marcador) / portal (aviso)

const PREFIX_ENTITY: String = "e:"
const PREFIX_MAP: String = "m:"
const TYPE_SIT: StringName = &"sit"
const TYPE_PORTAL: StringName = &"portal"
const META_FACING_YAW: String = "facing_yaw"
const META_RECOMMENDED_LEVEL: String = "recommended_level"
## Metas opcionais de C: onde parar para interagir e onde sentar (sit).
const META_APPROACH_POSITION: String = "approach_position"
const META_SEAT_POSITION: String = "seat_position"
## Quantas vezes o caminho até um alvo que se move (NPC vagando) pode ser refeito.
const MAX_REPATHS: int = 3

var world: ServerWorld = null
var _gather_ready: Dictionary = {}


func _init(p_world: ServerWorld) -> void:
	world = p_world


## Lê uma meta aceitando chave String ou StringName (GameMap devolve StringName).
static func meta_get(meta: Dictionary, key: String, default: Variant = null) -> Variant:
	if meta.has(StringName(key)):
		return meta[StringName(key)]
	return meta.get(key, default)


func _range() -> float:
	return Balance.cfg.interact_range


## Posição do alvo e se ele é válido para este jogador (mesma instância). {} = inválido.
## Retorno: {"kind": &"entity"|&"map", "position": Vector3, "entity": NetEntity, "object": Dictionary}
func resolve(session: PlayerSession, target_id: String) -> Dictionary:
	var instance_id: StringName = session.entity.instance_id
	if target_id.begins_with(PREFIX_ENTITY):
		var raw: String = target_id.trim_prefix(PREFIX_ENTITY)
		if not raw.is_valid_int():
			return {}
		var e: NetEntity = world.get_entity(raw.to_int())
		if e == null or e.instance_id != instance_id or e == session.entity or not e.is_npc():
			return {}
		return {"kind": &"entity", "position": e.net_position, "entity": e,
				"approach": e.net_position}
	if target_id.begins_with(PREFIX_MAP):
		var objects: Dictionary = world.get_interactables(instance_id)
		var obj: Variant = objects.get(target_id.trim_prefix(PREFIX_MAP))
		if typeof(obj) != TYPE_DICTIONARY:
			return {}
		var o: Dictionary = obj
		var meta: Dictionary = o.get("meta", {})
		var pos: Vector3 = o.get("position", Vector3.INF)
		var approach: Variant = meta_get(meta, META_APPROACH_POSITION)
		return {"kind": &"map", "position": pos, "object": o,
				"approach": approach if approach is Vector3 else pos}
	return {}


func request(session: PlayerSession, target_id: String) -> void:
	cancel(session)
	var t: Dictionary = resolve(session, target_id)
	if t.is_empty():
		Net.log_invalid(session.peer_id, "interact_target_invalid", {"target": target_id,
				"instance": String(session.entity.instance_id)})
		Net.push_system_message(session.peer_id, SysMsg.TARGET_INVALID)
		return
	world.stand_up(session)
	if session.entity.flat_distance_to(t["position"]) <= _range():
		session.entity.get_mover().stop()
		_execute(session, target_id, t)
		return
	if not session.entity.get_mover().move_to(t["approach"], _approach_range(t)):
		Net.log_invalid(session.peer_id, "interact_unreachable", {"target": target_id})
		Net.push_system_message(session.peer_id, SysMsg.TOO_FAR)
		return
	session.pending_target_id = target_id
	session.pending_repaths = 0
	Net.log_line("interact_walking", {"peer": session.peer_id, "target": target_id,
			"distance": snappedf(session.entity.flat_distance_to(t["position"]), 0.01)})


## Com approach_position (meta de C/W) anda até o ponto; sem ela, para a interact_range do alvo.
func _approach_range(t: Dictionary) -> float:
	return _range() if t["approach"] == t["position"] else 0.0


func cancel(session: PlayerSession) -> void:
	session.pending_target_id = ""
	session.pending_repaths = 0


## Por tick: se há interação pendente, executa ao entrar no alcance.
func tick(session: PlayerSession) -> void:
	if session.pending_target_id.is_empty():
		return
	var target_id: String = session.pending_target_id
	var t: Dictionary = resolve(session, target_id)
	if t.is_empty():
		cancel(session)
		Net.push_system_message(session.peer_id, SysMsg.TARGET_INVALID)
		return
	var mover: GridMover = session.entity.get_mover()
	if session.entity.flat_distance_to(t["position"]) <= _range():
		cancel(session)
		mover.stop()
		_execute(session, target_id, t)
		return
	if mover.is_moving():
		return
	# Chegou ao fim do caminho e o alvo (que se moveu) ainda está longe: refaz o caminho.
	session.pending_repaths += 1
	if session.pending_repaths > MAX_REPATHS or not mover.move_to(t["approach"], _approach_range(t)):
		cancel(session)
		Net.log_invalid(session.peer_id, "interact_out_of_range", {"target": target_id})
		Net.push_system_message(session.peer_id, SysMsg.TOO_FAR)


func _execute(session: PlayerSession, target_id: String, t: Dictionary) -> void:
	Net.log_line("interact_execute", {"peer": session.peer_id, "target": target_id})
	if t["kind"] == &"entity":
		var npc: NetEntity = t["entity"]
		session.entity.face_towards(npc.net_position)
		world.dialogue.start(session, npc)
		return
	var obj: Dictionary = t["object"]
	var meta: Dictionary = obj.get("meta", {})
	match StringName(str(obj.get("type", ""))):
		&"gather":
			_gather(session, target_id, meta)
		TYPE_SIT:
			var yaw: float = float(meta_get(meta, META_FACING_YAW, 0.0))
			var seat: Variant = meta_get(meta, META_SEAT_POSITION)
			if seat is Vector3:
				world.sit_at(session, seat, yaw, false)
			else:
				world.sit_at(session, obj.get("position", session.entity.net_position), yaw, true)
		TYPE_PORTAL:
			# Portal de saída do Campo de Treino (Agente N): troca de mapa de verdade.
			if world.map_transfer != null and world.map_transfer.handle_portal(session, obj):
				return
			# Neste marco os portões ficam fechados: só o aviso "Recomendado: nível X".
			var level: Variant = meta_get(meta, META_RECOMMENDED_LEVEL, "")
			Net.push_system_message(session.peer_id, SysMsg.PORTAL_CLOSED, [str(level)])
		&"altar_crendice", &"altar":
			if NetCrendice != null:
				NetCrendice.push_open_altar(session.peer_id)
		_:
			if target_id.contains("altar"):
				if NetCrendice != null:
					NetCrendice.push_open_altar(session.peer_id)
				return
			Net.log_line("interact_unknown_type", {"peer": session.peer_id, "target": target_id,
					"type": str(obj.get("type", ""))})



func _gather(session: PlayerSession, target: String, meta: Dictionary) -> void:
	if session.character.hp <= 0:
		return
	var key: String = "%d:%s:%s" % [session.peer_id, session.entity.instance_id, target]
	var now: int = Time.get_ticks_msec()
	if now < int(_gather_ready.get(key, 0)):
		Net.push_system_message(session.peer_id, "FOLLOWER_GATHER_COOLDOWN")
		return
	var item: StringName = StringName(str(meta_get(meta, "item_id", "")))
	var qty: int = clampi(int(meta_get(meta, "quantity", 1)), 1, 8)
	if Content.item(item) == null or not session.character.inventory.can_add(item, qty):
		Net.push_system_message(session.peer_id, SysMsg.INVENTORY_FULL)
		return
	world.progression.quests.on_item_looted(session, item, qty)
	session.character.inventory.add(item, qty)
	_gather_ready[key] = now + 30000
	session.mark_dirty(PlayerSession.DIRTY_INVENTORY)
	world.progression.mark_dirty(session)
