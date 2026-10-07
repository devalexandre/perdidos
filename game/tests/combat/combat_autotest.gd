extends Node
## Autoteste do combate no cliente (Agente K). Criado pelo NetCombat com --combat-autotest.
## Papéis (--combat-role=):
##   hero    — negativos (outra instância, alvo morto, fora de alcance), mata uma criatura (números
##             de dano, anel do alvo, barra de vida), pega o drop (item + Estrelas), testa o retorno
##             do monstro resistente (volta à origem com a vida cheia).
##   victim  — anda até o bruto agressivo, morre (hp 0, evento de morte), tenta andar morto
##             (recusado), renasce e confere que o bruto NÃO evoluiu (sem evolução desde 30/09/2026).
##   shot    — (xvfb) no Campo de Treino com os monstros reais: ataca o mais próximo e grava PNGs em
##             --shot-dir.
##   anim_shot — (xvfb, servidor com --progression-autotest) combate vivo (Agente A): luta desarmado,
##             com facão e com cajado + conjura uma skill mágica; grava rajadas de quadros em
##             --shot-dir a cada golpe (avanço do golpe, animação por arma, empurrão do alvo).
## Imprime "combat_check {...}" por verificação e "combat_result {"pass": ...}" no fim.

const ARG_ROLE: String = "combat-role"
const ARG_SHOT_DIR: String = "shot-dir"
const ROLE_HERO: String = "hero"
const ROLE_VICTIM: String = "victim"
const ROLE_SHOT: String = "shot"
const ROLE_ANIM_SHOT: String = "anim_shot"
## anim_shot: estilos (item equipado via debug; &"" = desarmado), rajadas por estilo e quadros por rajada.
const ANIM_STYLES: Array = [[&"", &"attack_unarmed"], [&"machete", &"attack_blade"], [&"wooden_staff", &"attack_staff"]]
const ANIM_BURSTS: int = 2
const ANIM_BURST_FRAMES: int = 8
const ANIM_BURST_GAP_SEC: float = 0.055
const ANIM_CAST_SKILL: StringName = &"arcane_spark"
const CRITTER: StringName = &"test_critter"
const STURDY: StringName = &"test_sturdy"
const BRUTE: StringName = &"test_brute"
const DODGER: StringName = &"test_dodger"
const DROP_ITEM: StringName = &"spinning_leaf"
const KIND_MONSTER: StringName = &"monster"
const KIND_DROP: StringName = &"drop"
const MONSTER_ID_BASE: int = 2000000
const PROBE_IDS: int = 40
const PROBE_GAP_SEC: float = 0.07
const SETTLE_SEC: float = 3.0
const WAIT_SEC: float = 20.0
const LONG_WAIT_SEC: float = 60.0
const POLL_SEC: float = 0.1
const REPLICATION_SEC: float = 0.6
const FAR_DISTANCE: float = 20.0
## Retorno: o herói foge nesta distância do monstro resistente (m).
const FLEE_DISTANCE: float = 14.0
const HOME_TOLERANCE: float = 2.5
const SHOT_COUNT: int = 12
const SHOT_INTERVAL_SEC: float = 0.35
const SHOT_WARMUP_SEC: float = 1.2
const SHOT_APPROACH_DISTANCE: float = 10.0
const SHOT_APPROACH_STEPS: int = 12
const SHOT_APPROACH_STEP_SEC: float = 2.0
const MSG_BOSS: String = "SYS_MONSTER_BECAME_BOSS"
const MSG_TOO_FAR: String = "SYS_TOO_FAR"
const MSG_DEAD: String = "SYS_YOU_ARE_DEAD"

var _role: String = ROLE_HERO
var _args: Dictionary = {}
var _local: Node3D = null
var _checks: Dictionary = {}
var _hits: Array[Array] = []
var _deaths: Array[int] = []
var _system: Array[String] = []
var _stats: Dictionary = {}
var _inventory: Array = []
var _stars: int = -1
var _started: bool = false


func _ready() -> void:
	for raw: String in OS.get_cmdline_user_args():
		var a: String = raw.trim_prefix("--")
		var eq: int = a.find("=")
		_args[a.substr(0, eq) if eq >= 0 else a] = a.substr(eq + 1) if eq >= 0 else ""
	_role = str(_args.get(ARG_ROLE, ROLE_HERO))
	NetCombat.hit.connect(func(s: int, t: int, amt: int, c: bool, _d: int, r: float) -> void:
		_hits.append([s, t, amt, c, r]))
	NetCombat.entity_died.connect(func(id: int) -> void: _deaths.append(id))
	Net.system_message.connect(func(k: String, _a: Array) -> void: _system.append(k))
	Net.stats_changed.connect(func(s: Dictionary) -> void: _stats = s)
	Net.inventory_changed.connect(func(s: Array) -> void: _inventory = s)
	Net.currency_changed.connect(func(s: int) -> void: _stars = s)
	Net.local_player_spawned.connect(_on_spawned)


func _on_spawned(player: Node3D) -> void:
	if _started:
		return
	_started = true
	_local = player
	_stars = Net.client_stars
	await _wait(SETTLE_SEC)
	match _role:
		ROLE_VICTIM:
			await _run_victim()
		ROLE_SHOT:
			await _run_shot()
		ROLE_ANIM_SHOT:
			await _run_anim_shot()
		_:
			await _run_hero()
	_finish()


# ---------------------------------------------------------------- utilitários

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Espera cond() ficar true (ou o tempo acabar). Devolve cond() no fim.
func _until(cond: Callable, timeout: float) -> bool:
	var left: float = timeout
	while left > 0.0:
		if cond.call():
			return true
		await _wait(POLL_SEC)
		left -= POLL_SEC
	return bool(cond.call())


func _check(name: String, ok: bool, detail: Variant = null) -> void:
	_checks[name] = ok
	Net.log_line("combat_check", {"role": _role, "check": name, "pass": ok, "detail": detail})


func _finish() -> void:
	var ok: bool = true
	for k: String in _checks:
		ok = ok and _checks[k]
	Net.log_line("combat_result", {"role": _role, "pass": ok, "checks": _checks.size()})
	await _wait(REPLICATION_SEC)
	get_tree().quit(0 if ok else 1)


func _my_id() -> int:
	return multiplayer.get_unique_id()


func _monsters(def_id: StringName = &"", alive_only: bool = true) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Node3D in NetCombat.all_entities():
		if StringName(str(e.get(&"kind"))) != KIND_MONSTER:
			continue
		if not def_id.is_empty() and StringName(str(e.get(&"def_id"))) != def_id:
			continue
		if alive_only and float(e.get(&"hp_ratio")) <= 0.0:
			continue
		out.append(e)
	return out


func _nearest(list: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	for e: Node3D in list:
		if best == null or _dist(e) < _dist(best):
			best = e
	return best


func _dist(e: Node3D) -> float:
	var a: Vector3 = e.global_position
	var b: Vector3 = _local.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fx() -> CombatFx:
	return NetCombat.get_node_or_null(^"CombatFx") as CombatFx


func _find_drop(item_id: StringName) -> Node3D:
	for e: Node3D in NetCombat.all_entities():
		if StringName(str(e.get(&"kind"))) == KIND_DROP and StringName(str(e.get(&"def_id"))) == item_id:
			return e
	return null


func _is_stage(entity_id: int, stage: int) -> bool:
	var b: Node3D = NetCombat.find_entity(entity_id)
	return b != null and int(b.get(&"stage")) == stage


func _is_home(e: Node3D, origin: Vector3) -> bool:
	return is_instance_valid(e) and is_equal_approx(float(e.get(&"hp_ratio")), 1.0) \
			and e.global_position.distance_to(origin) <= HOME_TOLERANCE


func _count_item(item_id: StringName) -> int:
	var n: int = 0
	for s: Variant in _inventory:
		if s is Dictionary and StringName(str((s as Dictionary).get("item", ""))) == item_id:
			n += int((s as Dictionary).get("qty", 0))
	return n


# ---------------------------------------------------------------- herói

func _run_hero() -> void:
	var ok: bool = await _until(func() -> bool: return _monsters(CRITTER).size() > 0, WAIT_SEC)
	_check("monsters_visible", ok, _monsters().size())
	if not ok:
		return
	# Negativo: ids de monstros que este cliente não vê (a 2ª instância tem os seus).
	var visible: Dictionary = {}
	for e: Node3D in _monsters(&"", false):
		visible[int(e.get(&"entity_id"))] = true
	var probed: int = 0
	for i: int in range(1, PROBE_IDS + 1):
		if not visible.has(MONSTER_ID_BASE + i):
			NetCombat.send_attack(MONSTER_ID_BASE + i)
			probed += 1
			await _wait(PROBE_GAP_SEC)
	_check("probe_other_instance_sent", probed > 0, probed)
	# Matar uma criatura.
	var critter: Node3D = _nearest(_monsters(CRITTER))
	var cid: int = int(critter.get(&"entity_id"))
	var stars_before: int = _stars
	var leaf_before: int = _count_item(DROP_ITEM)
	NetCombat.send_attack(cid)
	var ring_seen: bool = await _until(func() -> bool: return _fx() != null and _fx().get_target_ring().visible, WAIT_SEC)
	_check("target_ring_visible", ring_seen)
	var bar_seen: bool = await _until(func() -> bool: return _fx() != null and _fx().bars_visible > 0, WAIT_SEC)
	_check("monster_hp_bar_visible", bar_seen)
	var died: bool = await _until(func() -> bool: return cid in _deaths, WAIT_SEC)
	_check("critter_killed", died)
	var my_hits: int = 0
	for h: Array in _hits:
		if h[0] == _my_id() and h[1] == cid and int(h[2]) > 0:
			my_hits += 1
	_check("damage_events_received", my_hits > 0, my_hits)
	_check("damage_numbers_spawned", _fx() != null and _fx().numbers_spawned > 0,
			_fx().last_number_text if _fx() != null else "")
	# Negativo: atacar o corpo (ainda na tela).
	NetCombat.send_attack(cid)
	# Drop: aparece, pega, vai para o inventário; Estrelas subiram.
	await _until(func() -> bool: return _find_drop(DROP_ITEM) != null, WAIT_SEC)
	var drop: Node3D = _find_drop(DROP_ITEM)
	_check("drop_spawned", drop != null)
	if drop != null:
		NetCombat.send_pickup(int(drop.get(&"entity_id")))
		var got: bool = await _until(func() -> bool: return _count_item(DROP_ITEM) > leaf_before, WAIT_SEC)
		_check("drop_picked_to_inventory", got, _count_item(DROP_ITEM))
	_check("stars_from_kill", _stars > stars_before, [stars_before, _stars])
	# Negativo: fora de alcance (monstro distante).
	var far: Node3D = null
	for e: Node3D in _monsters():
		if _dist(e) > FAR_DISTANCE:
			far = e
	if far != null:
		var mark: int = _system.size()
		NetCombat.send_attack(int(far.get(&"entity_id")))
		var refused: bool = await _until(func() -> bool: return MSG_TOO_FAR in _system.slice(mark), WAIT_SEC)
		_check("far_attack_refused", refused)
	else:
		_check("far_attack_refused", false, "no far monster")
	await _run_leash()
	await _run_luck_checks()


## Agente R (GDD §10.2): criaturas raras (servidor com --force-rare=test_critter) e golpes errados.
func _run_luck_checks() -> void:
	var rare: Node3D = null
	for e: Node3D in _monsters(CRITTER):
		if CombatVisuals.is_rare(e):
			rare = e
	var v: EntityVisual = rare.get_node_or_null(^"Visual") as EntityVisual if rare != null else null
	var def: MonsterDef = Content.monster(CRITTER)
	var want: String = CombatVisuals.rare_name(def, TranslationServer.translate(def.stages[0].name_key)) \
			if def != null else ""
	_check("rare_monster_visible", v != null and v.get_nameplate().text == want \
			and v.get_node_or_null(NodePath(String(RareVisual.NODE_NAME))) != null,
			v.get_nameplate().text if v != null else "none")
	_check("rare_monster_notice", "SYS_RARE_MONSTER_APPEARED" in _system, _system)
	# "Errou": o servidor roda com --always-hit (combate determinístico); só o esquivo (DES 1000,
	# acerto mínimo de 50%) faz errar.
	var dodger: Node3D = _nearest(_monsters(DODGER))
	var misses: int = 0
	if dodger != null:
		var did: int = int(dodger.get(&"entity_id"))
		NetCombat.send_attack(did)
		await _until(func() -> bool:
			for h: Array in _hits:
				if h[1] == did and int(h[2]) == NetCombat.MISS_AMOUNT:
					return true
			return false, WAIT_SEC)
		NetCombat.send_stop_attack()
	for h: Array in _hits:
		if int(h[2]) == NetCombat.MISS_AMOUNT:
			misses += 1
	_check("miss_events_received", dodger != null and misses > 0, misses)
	_check("miss_text_shown", _fx() != null and _fx().misses_spawned > 0)


## Retorno: fere o resistente, foge; ele persegue até a coleira, volta e recupera a vida.
func _run_leash() -> void:
	var sturdy: Node3D = _nearest(_monsters(STURDY))
	if sturdy == null:
		_check("leash_monster_found", false)
		return
	var sid: int = int(sturdy.get(&"entity_id"))
	var origin: Vector3 = sturdy.global_position
	NetCombat.send_attack(sid)
	var hurt: bool = await _until(func() -> bool: return float(sturdy.get(&"hp_ratio")) < 1.0, WAIT_SEC)
	_check("leash_monster_hurt", hurt, float(sturdy.get(&"hp_ratio")))
	# Foge para o leste (longe do bruto, que fica ao norte do SpawnPoint nos dados de teste).
	Net.send_move_request(origin + Vector3.RIGHT * FLEE_DISTANCE)
	var chased: bool = await _until(func() -> bool: return is_instance_valid(sturdy) and sturdy.global_position.distance_to(origin) > 1.0, WAIT_SEC)
	_check("leash_monster_chased", chased)
	var back: bool = await _until(_is_home.bind(sturdy, origin), LONG_WAIT_SEC)
	_check("leash_returned_and_healed", back,
			[float(sturdy.get(&"hp_ratio")), sturdy.global_position.distance_to(origin)] \
			if is_instance_valid(sturdy) else "gone")


# ---------------------------------------------------------------- vítima

func _run_victim() -> void:
	var ok: bool = await _until(func() -> bool: return _monsters(BRUTE).size() > 0, WAIT_SEC)
	_check("brute_visible", ok)
	if not ok:
		return
	var brute: Node3D = _monsters(BRUTE)[0]
	var bid: int = int(brute.get(&"entity_id"))
	Net.send_move_request(brute.global_position)
	var died: bool = await _until(func() -> bool: return _my_id() in _deaths, WAIT_SEC)
	_check("victim_died", died)
	_check("victim_hp_zero", int(_stats.get(&"hp", -1)) == 0, _stats.get(&"hp"))
	var mark: int = _system.size()
	Net.send_move_request(_local.global_position + Vector3(2.0, 0.0, 0.0))
	var refused: bool = await _until(func() -> bool: return MSG_DEAD in _system.slice(mark), WAIT_SEC)
	_check("move_while_dead_refused", refused)
	var revived: bool = await _until(func() -> bool: return int(_stats.get(&"hp", 0)) > 0, WAIT_SEC)
	_check("victim_revived", revived, _stats.get(&"hp"))
	# Sem evolução (decisão do dono, 30/09/2026): quem matou continua no estágio 1, sem aviso de chefe.
	await _wait(SETTLE_SEC)
	_check("killer_did_not_evolve", _is_stage(bid, 1) and not (MSG_BOSS in _system),
			int(NetCombat.find_entity(bid).get(&"stage")) if NetCombat.find_entity(bid) != null else -1)


# ---------------------------------------------------------------- capturas (xvfb)

func _run_shot() -> void:
	var dir: String = str(_args.get(ARG_SHOT_DIR, OS.get_user_data_dir()))
	var ok: bool = await _until(func() -> bool: return _monsters().size() > 0, LONG_WAIT_SEC)
	_check("shot_monsters_visible", ok, _monsters().size())
	if not ok:
		return
	# Nos dados de teste, o resistente dá luta longa (números, barra e anel na captura).
	var target: Node3D = _nearest(_monsters(STURDY))
	if target == null:
		target = _nearest(_monsters())
	var tid: int = int(target.get(&"entity_id"))
	if _dist(target) > SHOT_APPROACH_DISTANCE:
		# Longe demais para um clique de ataque: anda até perto primeiro (várias etapas).
		for i: int in range(SHOT_APPROACH_STEPS):
			if not is_instance_valid(target) or _dist(target) <= SHOT_APPROACH_DISTANCE:
				break
			Net.send_move_request(target.global_position)
			await _wait(SHOT_APPROACH_STEP_SEC)
	Net.log_line("shot_target", {"id": tid, "def": str(target.get(&"def_id")),
			"distance": snappedf(_dist(target), 0.1)})
	NetCombat.send_attack(tid)
	await _until(func() -> bool: return _hits.size() > 0, WAIT_SEC)
	await _wait(SHOT_WARMUP_SEC)
	for i: int in range(SHOT_COUNT):
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/combat_%02d.png" % [dir, i]
		img.save_png(path)
		await _wait(SHOT_INTERVAL_SEC)
	_check("shot_hits_seen", _hits.size() > 0, _hits.size())
	_check("shot_numbers", _fx() != null and _fx().numbers_spawned > 0)


# ---------------------------------------------------------------- combate vivo (Agente A)

func _local_visual() -> DirectionalSprite3D:
	return _local.get_node_or_null(^"Visual") as DirectionalSprite3D if _local != null else null


func _burst(dir: String, tag: String) -> Array[StringName]:
	var shown: Array[StringName] = []
	for f: int in range(ANIM_BURST_FRAMES):
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%02d.png" % [dir, tag, f])
		var v := _local_visual()
		if v != null:
			shown.append(v.get_oneshot())
		await _wait(ANIM_BURST_GAP_SEC)
	return shown


func _run_anim_shot() -> void:
	var dir: String = str(_args.get(ARG_SHOT_DIR, OS.get_user_data_dir()))
	var cam: Node = get_tree().get_first_node_in_group(DirectionalSprite3D.CAMERA_GROUP)
	var view: Node = cam.get_parent() if cam != null else null
	while view != null and not (&"camera_zoom" in view):
		view = view.get_parent()
	if view != null:
		view.set(&"camera_zoom", Balance.cfg.camera_zoom_max)
	var ok: bool = await _until(func() -> bool: return _monsters(STURDY).size() > 0 or _monsters().size() > 0, LONG_WAIT_SEC)
	_check("anim_monsters_visible", ok)
	if not ok:
		return
	NetProgress.send_debug(&"learn", [ANIM_CAST_SKILL])
	await _wait(0.5)
	NetProgress.send_hotbar_set(0, ANIM_CAST_SKILL)
	await _wait(0.5)
	for st: Array in ANIM_STYLES:
		var item: StringName = st[0]
		var want: StringName = st[1]
		NetCombat.send_stop_attack()
		if item.is_empty():
			Net.send_unequip(&"weapon")
		else:
			NetProgress.send_debug(&"equip_item", [item])
		var style_ok: bool = await _until(func() -> bool:
			var v := _local_visual()
			return v != null and v.resolve_anim(&"attack") == want, WAIT_SEC)
		_check("anim_style_%s" % want, style_ok, _local_visual().resolve_anim(&"attack") if _local_visual() != null else "")
		var target: Node3D = _nearest(_monsters(STURDY))
		if target == null:
			target = _nearest(_monsters())
		if target == null:
			_check("anim_target_%s" % want, false)
			continue
		var tid: int = int(target.get(&"entity_id"))
		var my: int = _my_id()
		var fx: CombatFx = _fx()
		var lunges0: int = fx.lunges_played if fx != null else 0
		NetCombat.send_attack(tid)
		var seen: Array[StringName] = []
		for b: int in range(ANIM_BURSTS):
			var n0: int = _hits.filter(func(h: Array) -> bool: return h[0] == my).size()
			await _until(func() -> bool: return _hits.filter(func(h: Array) -> bool: return h[0] == my).size() > n0, WAIT_SEC)
			seen.append_array(await _burst(dir, "%s_%d" % [want, b]))
		_check("anim_played_%s" % want, want in seen, str(seen))
		_check("anim_lunge_%s" % want, fx != null and fx.lunges_played > lunges0)
		_check("anim_knockback_%s" % want, fx != null and fx.knockbacks_played > 0)
	# conjuração (skill mágica): anim cast no conjurador
	NetCombat.send_stop_attack()
	NetProgress.send_debug(&"set_mp", [200])
	await _wait(0.6)
	var t2: Node3D = _nearest(_monsters())
	if t2 != null:
		var casts0: int = _fx().casts_played if _fx() != null else 0
		NetProgress.send_cast(ANIM_CAST_SKILL, int(t2.get(&"entity_id")), t2.global_position)
		await _until(func() -> bool: return _fx() != null and _fx().casts_played > casts0, WAIT_SEC)
		var cseen: Array[StringName] = await _burst(dir, "cast")
		_check("anim_cast", &"cast" in cseen, str(cseen))
	NetCombat.send_stop_attack()
