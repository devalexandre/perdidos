extends Node
## Autoteste em rede de chefes, dia e noite e forma atroz (docs/chefes-dia-noite.md). Criado pelo main.gd
## com --autotest --autotest-script=res://tests/monsters/night_client_test.gd; servidor com --autotest
## --combat-fixtures --always-hit --drop-chance-mult=10 (tests/monsters/run_night_test.sh).
## O cliente (nome "Hero*", forte pelos dados de teste) usa os comandos de teste do chat (MonsterDebug):
##  1. relógio replicado (começa de dia) e luz de dia no Porto;
##  2. covil fixo: o chefe já está no covil com o bando; derrubado, renasce ali (sem contagem de abates);
##  3. /noite: relógio e luz da noite no cliente; aviso da noite;
##  4. /chefe tatu à noite: nasce atroz (estágio 4 e appearance["atroz"] replicados), aviso, ataca;
##  5. /derrubar chefe: abate atroz com o item raro no chão (evento de abate com stage/atroz/rare no servidor);
##  6. chefe vivo quando anoitece vira atroz; amanhece em luta: continua atroz;
## Com --shot-dir e janela (SHOTS=1), tira fotos de dia, de noite, do chefe e da forma atroz.
## Imprime "night_check {...}" e "night_result {...}"; código 0 = passou.

const ARG_SHOT_DIR: String = "shot-dir"
const CRITTER: StringName = &"test_critter"
const ARMADILLO: StringName = &"stone_armadillo"
const FIREFLY: StringName = &"enchanted_firefly"
const RARE_ITEM: StringName = &"ancient_shell_shard"
const STAGE_BOSS: int = 3
const STAGE_ATROZ: int = 4
const MSG_LAIR: String = "SYS_BOSS_LAIR_APPEARED"
const MSG_ATROZ: String = "SYS_MONSTER_BECAME_ATROZ"
const MSG_NIGHT: String = "SYS_NIGHT_FALLS"
const MSG_INFO: String = "SYS_DEV_INFO"
## Luz: de noite o sol (luar) tem de ficar bem mais fraco que de dia.
const NIGHT_SUN_MAX_RATIO: float = 0.6

const SETTLE_SEC: float = 2.0
const SHORT_SEC: float = 6.0
const LONG_SEC: float = 20.0
const LIGHT_SEC: float = 6.0
const CMD_GAP_SEC: float = 1.1
const POLL_SEC: float = 0.1

var main_node: Node = null
var args: Dictionary[String, String] = {}

var _checks: Dictionary = {}
var _system: Array[String] = []
var _info: Array[String] = []
var _local: NetEntity = null
var _started: bool = false
var _shot_index: int = 0


func _ready() -> void:
	Net.system_message.connect(func(k: String, a: Array) -> void:
		_system.append(k)
		if k == MSG_INFO and not a.is_empty():
			_info.append(str(a[0]))
		Net.log_line("night_test_system", {"key": k, "args": str(a)}))
	Net.local_player_spawned.connect(_on_local_player_spawned)


func _on_local_player_spawned(player: Node3D) -> void:
	_local = player as NetEntity
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC)
	await _run()
	_finish()


func _run() -> void:
	# 1. relógio e luz de dia
	_check("clock_synced_day", await _wait_until(func() -> bool: return DayNight.synced, SHORT_SEC)
			and not DayNight.is_night(), DayNight.describe())
	var sun: DirectionalLight3D = _sun()
	var day_energy: float = sun.light_energy if sun != null else -1.0
	_check("map_has_sun", sun != null and day_energy > 0.0, day_energy)
	await _shot("porto_dia")
	# 2. covil fixo (dados de teste: BossLairs/critter_lair, renasce em 5 s): chefe com bando desde o início;
	#    derrubado, renasce no covil e o bando que sobrou volta a segui-lo.
	var boss: NetEntity = await _wait_entity(func(e: NetEntity) -> bool: return e.def_id == CRITTER \
			and e.stage == STAGE_BOSS and e.hp_ratio > 0.0, LONG_SEC)
	_check("lair_boss_present", boss != null)
	var escort: int = _count(func(e: NetEntity) -> bool: return e.def_id == CRITTER and e.stage < STAGE_BOSS \
			and e.hp_ratio > 0.0 and boss != null and e.net_position.distance_to(boss.net_position) < 8.0)
	_check("lair_boss_with_escort", escort >= 6, escort)
	await _cmd("/covil")
	_check("lair_listed", _last_info().contains("%s: vivo" % CRITTER), _last_info())
	await _shot("chefe_covil_dia")
	var mark: int = _system.size()
	await _cmd("/derrubar chefe")
	_check("lair_boss_killed", boss != null and await _wait_until(func() -> bool:
		return not is_instance_valid(boss) or boss.hp_ratio <= 0.0, SHORT_SEC))
	_check("lair_boss_respawned", await _wait_system(MSG_LAIR, mark, LONG_SEC), _system.slice(mark))
	var again: NetEntity = await _wait_entity(func(e: NetEntity) -> bool: return e.def_id == CRITTER \
			and e.stage == STAGE_BOSS and e.hp_ratio > 0.0 and e != boss, SHORT_SEC)
	_check("lair_boss_back_in_lair", again != null)
	# 3. noite
	var mark_n: int = _system.size()
	await _cmd("/noite")
	_check("night_forced_on_client", await _wait_until(func() -> bool: return DayNight.is_night(), SHORT_SEC),
			DayNight.describe())
	_check("night_announced", await _wait_system(MSG_NIGHT, mark_n, SHORT_SEC), _system.slice(mark_n))
	await _wait(LIGHT_SEC)
	var night_energy: float = sun.light_energy if sun != null else -1.0
	_check("night_light_darker", sun != null and night_energy < day_energy * NIGHT_SUN_MAX_RATIO,
			[day_energy, night_energy])
	await _shot("porto_noite")
	# 4. chefe à noite nasce atroz
	var mark_a: int = _system.size()
	await _cmd("/chefe tatu")
	var atroz: NetEntity = await _wait_entity(func(e: NetEntity) -> bool: return e.def_id == ARMADILLO \
			and e.stage == STAGE_ATROZ and e.hp_ratio > 0.0, SHORT_SEC)
	_check("night_boss_is_atroz", atroz != null)
	_check("atroz_appearance_replicated", atroz != null and bool(atroz.appearance.get(&"atroz", false)),
			atroz.appearance if atroz != null else {})
	_check("atroz_announced", await _wait_system(MSG_ATROZ, mark_a, SHORT_SEC), _system.slice(mark_a))
	var def: MonsterDef = Content.monster(ARMADILLO)
	_check("atroz_uses_stage4_data", def != null and def.atroz_stage() != null and atroz != null
			and atroz.display_name == def.atroz_stage().name_key, atroz.display_name if atroz != null else "")
	await _shot("atroz_noite")
	# 5. derrubar o atroz: item raro no chão
	await _cmd("/derrubar chefe")
	_check("atroz_killed", await _wait_until(func() -> bool: return atroz == null or not is_instance_valid(atroz) \
			or atroz.hp_ratio <= 0.0, SHORT_SEC))
	var shard: NetEntity = await _wait_entity(func(e: NetEntity) -> bool: return e.def_id == RARE_ITEM, SHORT_SEC)
	_check("atroz_dropped_rare_item", shard != null)
	# 6. chefe vivo de dia vira atroz ao anoitecer; amanhece em luta = continua atroz
	await _cmd("/dia")
	_check("day_forced_on_client", await _wait_until(func() -> bool: return not DayNight.is_night(), SHORT_SEC))
	await _cmd("/chefe vagalume")
	var ff: NetEntity = await _wait_entity(func(e: NetEntity) -> bool: return e.def_id == FIREFLY \
			and e.stage == STAGE_BOSS and e.hp_ratio > 0.0, SHORT_SEC)
	_check("day_boss_is_normal", ff != null and not bool(ff.appearance.get(&"atroz", false)))
	await _shot("chefe_dia")
	await _cmd("/noite")
	_check("live_boss_turns_atroz_at_night", ff != null and await _wait_until(func() -> bool:
		return is_instance_valid(ff) and ff.stage == STAGE_ATROZ, SHORT_SEC))
	await _wait(LIGHT_SEC)
	await _shot("chefe_e_atroz_noite")
	await _cmd("/dia")
	await _wait(SETTLE_SEC)
	_check("atroz_in_fight_stays_at_dawn", ff != null and is_instance_valid(ff) and ff.stage == STAGE_ATROZ,
			ff.stage if ff != null and is_instance_valid(ff) else -1)
	await _cmd("/hora normal")
	await _wait(SETTLE_SEC)


# ================================================================ utilidades

func _cmd(text: String) -> void:
	Net.send_chat(Net.CHANNEL_LOCAL, text)
	await _wait(CMD_GAP_SEC)


func _last_info() -> String:
	return _info.back() if not _info.is_empty() else ""


func _entities() -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	for inst: Node in main_node.get_node("World/Instances").get_children():
		var ents: Node = inst.get_node_or_null("Entities")
		if ents == null:
			continue
		for e: Node in ents.get_children():
			if e is NetEntity:
				out.append(e as NetEntity)
	return out


func _find(pred: Callable) -> NetEntity:
	var best: NetEntity = null
	var best_d: float = INF
	for e: NetEntity in _entities():
		if pred.call(e):
			var d: float = _local.flat_distance_to(e.net_position) if is_instance_valid(_local) else 0.0
			if d < best_d:
				best_d = d
				best = e
	return best


func _count(pred: Callable) -> int:
	var n: int = 0
	for e: NetEntity in _entities():
		if pred.call(e):
			n += 1
	return n


func _wait_entity(pred: Callable, timeout_sec: float) -> NetEntity:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_sec * 1000.0:
		var e: NetEntity = _find(pred)
		if e != null:
			return e
		await _wait(POLL_SEC)
	return _find(pred)


func _sun() -> DirectionalLight3D:
	if _local == null or _local.get_parent() == null:
		return null
	var map: Node = _local.get_parent().get_parent().get_node_or_null("Map")
	var best: DirectionalLight3D = null
	if map != null:
		for n: Node in map.find_children("*", "DirectionalLight3D", true, false):
			if best == null or (n as DirectionalLight3D).light_energy > best.light_energy:
				best = n as DirectionalLight3D
	return best


func _check(check_name: String, ok: bool, detail: Variant = null) -> bool:
	_checks[check_name] = ok
	Net.log_line("night_check", {"check": check_name, "pass": ok, "detail": str(detail)})
	return ok


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


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _wait(SETTLE_SEC)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/night_%02d_%s.png" % [dir, _shot_index, label]
	_shot_index += 1
	img.save_png(path)
	Net.log_line("night_test_shot", {"file": path})


func _finish() -> void:
	var ok: bool = not _checks.values().has(false)
	Net.log_line("night_result", {"pass": ok, "checks": _checks.size()})
	await _wait(0.5)
	get_tree().quit(0 if ok else 1)
