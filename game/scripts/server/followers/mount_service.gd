class_name MountService
extends RefCounted

var world: ServerWorld
var _pending: Dictionary[int, Dictionary] = {}
var _blocked_until: Dictionary[int, int] = {}

func _init(p_world: ServerWorld) -> void:
	world = p_world

static func effective_ms(base: int, speed_multiplier: float) -> int:
	return maxi(Balance.cfg.mount_min_ms_per_cell, roundi(base / maxf(0.1, speed_multiplier)))

func zone_allowed(session: PlayerSession) -> bool:
	var zone: ZoneDef = Content.zone(Progression.map_of(session.entity.instance_id))
	return zone != null and zone.mount_allowed and zone.kind not in [ZoneDef.Kind.TRAINING, ZoneDef.Kind.PVP]

func block_reason(session: PlayerSession, id: StringName, now: int = -1) -> String:
	if now < 0:
		now = Time.get_ticks_msec()
	var def: MountDef = Content.mount(id)
	if def == null or id not in session.character.mounts_owned:
		return "FOLLOWER_NOT_OWNED"
	if session.character.hp <= 0 or world.progression.bridge.is_in_combat(session.peer_id) \
			or session.entity.anim == NetEntity.ANIM_SIT or session.entity.target_id != 0:
		return "FOLLOWER_OUT_OF_COMBAT"
	if not zone_allowed(session):
		return "MOUNT_ZONE_FORBIDDEN"
	if now < int(_blocked_until.get(session.peer_id, 0)):
		return "MOUNT_HIT_LOCKOUT"
	if session.entity.get_mover() != null and session.entity.get_mover().is_moving():
		return "FOLLOWER_STAND_STILL"
	if not world.progression.caster.casting_info(session.peer_id).is_empty() \
			or (world.items != null and not world.items.using_info(session.peer_id).is_empty()):
		return "FOLLOWER_BUSY"
	return ""

func request(session: PlayerSession, id: StringName, now: int = -1) -> String:
	if now < 0:
		now = Time.get_ticks_msec()
	var reason: String = block_reason(session, id, now)
	if not reason.is_empty():
		return reason
	if not session.mounted_id.is_empty() or _pending.has(session.peer_id):
		return "FOLLOWER_BUSY"
	_pending[session.peer_id] = {"id": id, "end": now + roundi(Balance.cfg.mount_cast_sec * 1000),
			"position": session.entity.net_position, "instance": session.entity.instance_id}
	world.progression.mark_dirty(session)
	return ""

func cancel(session: PlayerSession) -> void:
	if _pending.erase(session.peer_id):
		world.progression.mark_dirty(session)

func dismount(session: PlayerSession, hit: bool = false, now: int = -1) -> void:
	if now < 0:
		now = Time.get_ticks_msec()
	cancel(session)
	if hit:
		_blocked_until[session.peer_id] = now + roundi(Balance.cfg.mount_lockout_after_hit_sec * 1000)
	if session.mounted_id.is_empty():
		return
	session.mounted_id = &""
	refresh_speed(session)
	world.refresh_appearance(session)
	world.progression.mark_dirty(session)

func refresh_speed(session: PlayerSession) -> void:
	var mover: GridMover = session.entity.get_mover()
	if mover == null:
		return
	var def: MountDef = Content.mount(session.mounted_id)
	var base: int = def.walk_ms_per_cell if def != null else Balance.cfg.walk_ms_per_cell
	var mult: float = world.progression.statuses.move_speed_multiplier(session.entity)
	var ms: int = effective_ms(base, mult) if def != null else roundi(base / maxf(0.1, mult))
	mover.set_speed(ms)

func tick(now: int = -1) -> void:
	if now < 0:
		now = Time.get_ticks_msec()
	for session: PlayerSession in world.get_sessions():
		if not session.mounted_id.is_empty():
			if not zone_allowed(session) or session.character.hp <= 0 \
					or world.progression.bridge.is_in_combat(session.peer_id) or session.entity.anim == NetEntity.ANIM_SIT:
				dismount(session)
		var pending: Dictionary = _pending.get(session.peer_id, {})
		if pending.is_empty():
			continue
		if not block_reason(session, pending.id, now).is_empty() \
				or session.entity.instance_id != pending.instance \
				or session.entity.net_position.distance_to(pending.position) > 0.01:
			cancel(session)
		elif now >= int(pending.end):
			_pending.erase(session.peer_id)
			session.mounted_id = pending.id
			refresh_speed(session)
			world.refresh_appearance(session)
			world.progression.mark_dirty(session)

func snapshot(session: PlayerSession) -> Dictionary:
	var pending: Dictionary = _pending.get(session.peer_id, {})
	return {"owned": Array(session.character.mounts_owned), "active": String(session.mounted_id),
			"casting_ms": maxi(0, int(pending.get("end", 0)) - Time.get_ticks_msec()),
			"lockout_ms": maxi(0, int(_blocked_until.get(session.peer_id, 0)) - Time.get_ticks_msec())}

func forget(peer: int) -> void:
	_pending.erase(peer)
	_blocked_until.erase(peer)
