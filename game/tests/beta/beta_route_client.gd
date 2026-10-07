extends Node
## Percurso do beta no cliente real (docs/beta-checklist.md). Criado pelo main.gd com
##   --autotest --autotest-script=res://tests/beta/beta_route_client.gd --shot-dir=DIR
## O servidor precisa de --dev-commands (atalhos de teste só para XP, vida, teleporte e hora) e, para o drop
## sempre aparecer, --drop-chance-mult. Rodar com tests/beta/run_beta_route.sh (xvfb, 1280x720).
## Roteiro, personagem novo:
##   Campo de Treino: conversa com o Mestre Jatobá, aceita a quest do título, caça 5 redemoinhos de verdade,
##   provação do tatu, entrega (título Facão Firme), morte e renascimento no acampamento, portal de saída;
##   Porto: aceita a lição Investida do Facão com a Mestra Brisa;
##   Campos, Mata e Chapada: luta (golpes de verdade), drop apanhado, XP, morte e renascimento no ponto seguro;
##   Campos: cumpre a lição caçando; Chapada: chefes dos covis fixos (Tatu-Montanha e Rainha-Lume, esta contando para
##   a quest do Seu Zé — variante da Chapada = espécie original), noite com a forma atroz;
##   volta Chapada → Mata → Campos → Porto (chegada pelo norte), entrega a lição;
##   Porto: provação do Seu Zé junto do ancião (confere se dá para lutar no Porto).
## Imprime "beta_route_check {...}" por verificação, "beta_route_shot {...}" por captura e
## "beta_route_done {...}"; código 0 = tudo passou.

const ARG_SHOT_DIR: String = "shot-dir"
## --beta-role=duo --watch-name=<outro>: teste de WebSocket com 2 clientes (run_ws_duo.sh). Save pronto na cidade.
const ARG_ROLE: String = "beta-role"
const ROLE_DUO: String = "duo"
const ARG_WATCH: String = "watch-name"
const WAIT_SEC: float = 10.0
const SETTLE_SEC: float = 0.8
const FIGHT_SEC: float = 75.0
const NEAR_OFFSET := Vector3(1.4, 0.0, 1.4)
const KIND_MONSTER: StringName = &"monster"
const KIND_DROP: StringName = &"drop"
const KIND_NPC: StringName = &"npc"
const SAFE_RADIUS_M: float = 3.5

var main_node: Node = null
var args: Dictionary[String, String] = {}

var _local: NetEntity = null
var _started: bool = false
var _spawn_seq: int = 0
var _opts: Array = []
var _text: String = ""
var _dialogue_seq: int = 0
var _progress_seq: int = 0
var _progress: Dictionary = {}
var _inventory: Array = []
var _deaths: Dictionary[int, bool] = {}
var _my_hits: int = 0
var _system: Array[String] = []
var _shot_index: int = 0
var _checks: Dictionary = {}
var _map_label: String = ""


func _ready() -> void:
	Net.local_player_spawned.connect(func(p: Node3D) -> void:
		_local = p as NetEntity
		_spawn_seq += 1
		if not _started:
			_started = true
			_run.call_deferred())
	Net.dialogue_opened.connect(func(_npc: int, _sp: String, tk: String, opts: Array) -> void:
		_text = tk
		_opts = opts
		_dialogue_seq += 1)
	NetProgress.progress_changed.connect(func(p: Dictionary) -> void:
		_progress = p
		_progress_seq += 1)
	Net.inventory_changed.connect(func(slots: Array) -> void: _inventory = slots)
	NetCombat.entity_died.connect(func(id: int) -> void: _deaths[id] = true)
	NetCombat.hit.connect(func(src: int, _t: int, amount: int, _c: bool, _d: int, _r: float) -> void:
		if _local != null and src == _local.entity_id and amount > 0:
			_my_hits += 1)
	Net.system_message.connect(func(key: String, _a: Array) -> void: _system.append(key))
	get_tree().create_timer(1500.0).timeout.connect(func() -> void:
		_check("tempo_esgotado", false, "o roteiro passou de 25 min")
		_finish())


# ================================================================ util

func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _wait(cond: Callable, timeout: float = WAIT_SEC) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(0.1).timeout
	return cond.call()


func _dbg(cmd: StringName, a: Array = []) -> void:
	var seq: int = _progress_seq
	NetProgress.send_debug(cmd, a)
	await _wait(func() -> bool: return _progress_seq > seq, 5.0)
	await _sleep(0.3)


## Gasta os pontos de atributo (FOR e VIT), como um jogador faria na janela de atributos.
func _spend_points() -> void:
	var pts: int = int(_progress.get("attribute_points", 0))
	if pts <= 0:
		return
	var strength: int = pts * 3 / 5
	var seq: int = _progress_seq
	NetProgress.send_allocate_stats({"str": strength, "vit": pts - strength})
	await _wait(func() -> bool: return _progress_seq > seq, 5.0)


func _chat(text: String) -> void:
	Net.send_chat(&"local", text)
	await _sleep(1.2)


func _check(name: String, ok: bool, detail: Variant = null) -> void:
	_checks[name] = ok
	Net.log_line("beta_route_check", {"check": name, "pass": ok, "map": _map_label,
			"detail": str(detail) if detail != null else ""})


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	_shot_index += 1
	var path: String = "%s/%02d_%s.png" % [dir, _shot_index, label]
	get_viewport().get_texture().get_image().save_png(path)
	Net.log_line("beta_route_shot", {"file": path, "map": _map_label, "text": _text})


func _map() -> Node:
	if _local == null or not is_instance_valid(_local) or _local.get_parent() == null:
		return null
	return _local.get_parent().get_parent().get_node_or_null(^"Map")


func _marker(path: String) -> Vector3:
	var m: Node = _map()
	var n: Node3D = m.get_node_or_null(NodePath(path)) as Node3D if m != null else null
	return n.global_position if n != null else Vector3.INF


func _tp(p: Vector3) -> void:
	await _dbg(&"teleport", [p.x, p.z])
	await _sleep(SETTLE_SEC)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _entities(kind: StringName, def_id: StringName = &"", alive: bool = true) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Node3D in NetCombat.all_entities():
		if StringName(str(e.get(&"kind"))) != kind:
			continue
		if not def_id.is_empty() and StringName(str(e.get(&"def_id"))) != def_id:
			continue
		if alive and float(e.get(&"hp_ratio")) <= 0.0:
			continue
		out.append(e)
	return out


func _nearest(list: Array[Node3D]) -> Node3D:
	var best: Node3D = null
	for e: Node3D in list:
		if best == null or _flat(e.global_position, _local.global_position) < _flat(best.global_position, _local.global_position):
			best = e
	return best


func _total_xp() -> int:
	return int(_progress.get("total_xp", 0))


func _count_item(item_id: StringName) -> int:
	var n: int = 0
	for s: Variant in _inventory:
		if s is Dictionary and StringName(str((s as Dictionary).get("item", ""))) == item_id:
			n += int((s as Dictionary).get("qty", 0))
	return n


func _items_total() -> int:
	var n: int = 0
	for s: Variant in _inventory:
		if s is Dictionary:
			n += int((s as Dictionary).get("qty", 0))
	return n


func _quest(id: StringName) -> Dictionary:
	for e: Variant in _progress.get("quests", []):
		if StringName(str((e as Dictionary).get("id", ""))) == id:
			return e
	return {}


# ================================================================ passos

## Anda até o NPC (teleporte perto do marcador), abre o diálogo.
func _talk(npc_id: StringName) -> bool:
	var def: NpcDef = Content.npc(npc_id)
	var spot: Vector3 = _marker("NpcPoints/" + String(def.spawn_marker)) if def != null else Vector3.INF
	if spot == Vector3.INF:
		return false
	Net.send_dialogue_close()
	await _tp(spot + NEAR_OFFSET * 2.0)
	await _wait(func() -> bool: return _npc(npc_id) != null, 15.0)
	var npc: NetEntity = _npc(npc_id)
	if npc == null:
		return false
	await _tp(npc.global_position + NEAR_OFFSET)
	var seq: int = _dialogue_seq
	Net.send_interact(npc.get_target_id())
	var ok: bool = await _wait(func() -> bool: return _dialogue_seq > seq)
	await _sleep(SETTLE_SEC)
	return ok


func _npc(npc_id: StringName) -> NetEntity:
	for e: Node3D in _entities(KIND_NPC, npc_id, false):
		return e as NetEntity
	return null


func _choose(key: String) -> bool:
	var i: int = _opts.find(key)
	if i < 0:
		Net.log_line("beta_route_missing_option", {"key": key, "options": _opts, "text": _text})
		return false
	var seq: int = _dialogue_seq
	Net.send_dialogue_choice(i)
	await _wait(func() -> bool: return _dialogue_seq > seq, 3.0)
	await _sleep(SETTLE_SEC)
	return true


## Aceita a quest pela conversa (opção da quest → Aceitar).
func _accept(npc_id: StringName, quest_id: StringName) -> bool:
	var q: QuestDef = Content.quest(quest_id)
	if not await _talk(npc_id):
		return false
	if not await _choose(q.option_text_key):
		return false
	await _shot("%s_oferta" % quest_id)
	await _choose("QUEST_OPT_ACCEPT")
	await _wait(func() -> bool: return not _quest(quest_id).is_empty(), 5.0)
	Net.send_dialogue_close()
	return not _quest(quest_id).is_empty()


## Entrega pela conversa (Relatar → Entregar).
func _turn_in(npc_id: StringName, quest_id: StringName) -> bool:
	if not await _talk(npc_id):
		return false
	if not await _choose("QUEST_OPT_REPORT"):
		return false
	await _shot("%s_entrega" % quest_id)
	await _choose("QUEST_OPT_TURN_IN")
	await _wait(func() -> bool: return StringName(quest_id) in _progress.get("quests_done", []) \
			or String(quest_id) in _progress.get("quests_done", []), 5.0)
	Net.send_dialogue_close()
	return String(quest_id) in _progress.get("quests_done", [])


## Luta de verdade (ataque básico, o servidor anda até o alvo). Devolve o id do monstro derrubado (0 = falhou).
## species vazio = o mais perto. Sem monstro à vista, vai até o marcador de Spawns da espécie.
func _fight(species: StringName, label: String, shots: bool = true) -> int:
	var list: Array[Node3D] = _monsters_of(species)
	if list.is_empty():
		var m: Node = _map()
		var spawns: Node = m.get_node_or_null(^"Spawns") if m != null else null
		if spawns != null:
			for s: Node in spawns.get_children():
				var mid := StringName(str(s.get_meta(&"monster_id", "")))
				if species.is_empty() or mid == species or MonsterDef.species_of(mid) == species:
					if int(s.get_meta(&"stage", 1)) < CombatRules.STAGE_BOSS:
						await _tp((s as Node3D).global_position + Vector3(0, 0, 5))
						break
		await _wait(func() -> bool: return not _monsters_of(species).is_empty(), 12.0)
		list = _monsters_of(species)
	var target: Node3D = _nearest(list)
	if target == null:
		return 0
	var tid: int = int(target.get(&"entity_id"))
	await _tp(target.global_position + NEAR_OFFSET)
	var hits_before: int = _my_hits
	NetCombat.send_attack(tid)
	var shot_taken: bool = not shots
	var end: int = Time.get_ticks_msec() + int(FIGHT_SEC * 1000.0)
	var last_send: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() < end and not _deaths.has(tid):
		if not shot_taken and _my_hits > hits_before:
			await _sleep(0.3)
			await _shot("%s_luta" % label)
			shot_taken = true
		if Time.get_ticks_msec() - last_send > 4000:
			NetCombat.send_attack(tid)
			last_send = Time.get_ticks_msec()
		await _sleep(0.2)
	Net.log_line("beta_route_fight", {"map": _map_label, "monster": str(target.get(&"def_id")),
			"level": int(target.get(&"level")), "killed": _deaths.has(tid), "hits": _my_hits - hits_before})
	return tid if _deaths.has(tid) else 0


func _monsters_of(species: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Node3D in _entities(KIND_MONSTER):
		var d := StringName(str(e.get(&"def_id")))
		if int(e.get(&"stage")) >= CombatRules.STAGE_BOSS:
			continue
		if species.is_empty() or d == species or MonsterDef.species_of(d) == species:
			out.append(e)
	return out


## Luta + XP + drop apanhado (o servidor roda com --drop-chance-mult).
func _fight_xp_drop(species: StringName, label: String) -> void:
	var xp0: int = _total_xp()
	var items0: int = _items_total()
	var tid: int = await _fight(species, label)
	_check("%s_derrubou_monstro" % label, tid != 0)
	if tid == 0:
		return
	await _wait(func() -> bool: return _total_xp() > xp0, 5.0)
	_check("%s_ganhou_xp" % label, _total_xp() > xp0, [xp0, _total_xp()])
	await _wait(func() -> bool: return _nearest(_entities(KIND_DROP)) != null, 6.0)
	var drop: Node3D = _nearest(_entities(KIND_DROP))
	_check("%s_drop_apareceu" % label, drop != null)
	if drop == null:
		return
	await _shot("%s_drop" % label)
	var drop_item: String = str(drop.get(&"def_id"))
	NetCombat.send_pickup(int(drop.get(&"entity_id")))
	var got: bool = await _wait(func() -> bool: return _items_total() > items0, 8.0)
	# Mapa compartilhado: o drop mais perto pode ser de outro jogador (posse por alguns segundos); tenta os outros.
	if not got:
		for d: Node3D in _entities(KIND_DROP):
			NetCombat.send_pickup(int(d.get(&"entity_id")))
			if await _wait(func() -> bool: return _items_total() > items0, 6.0):
				got = true
				break
	_check("%s_drop_no_inventario" % label, got, [items0, _items_total(), drop_item])


## Morte de verdade (vida 1, um monstro revida) e renascimento no ponto seguro do mapa.
func _death(label: String, safe_marker: String) -> void:
	var safe: Vector3 = _marker(safe_marker)
	var me: int = _local.entity_id
	_deaths.erase(me)
	var mark: int = _system.size()
	await _dbg(&"set_hp", [1])
	var list: Array[Node3D] = _monsters_of(&"")
	var t: Node3D = _nearest(list)
	if t == null:
		await _fight(&"", label + "_morte", false)
		t = _nearest(_monsters_of(&""))
	if t != null:
		await _tp(t.global_position + NEAR_OFFSET)
		NetCombat.send_attack(int(t.get(&"entity_id")))
	var died: bool = await _wait(func() -> bool: return _deaths.has(me), 40.0)
	if died:
		await _sleep(0.6)
		await _shot("%s_caiu" % label)
	_check("%s_morreu" % label, died)
	var back: bool = await _wait(func() -> bool: return "WORLD_RESPAWNED" in _system.slice(mark), 15.0)
	await _sleep(1.5)
	var dist: float = _flat(_local.net_position, safe) if safe != Vector3.INF else INF
	_check("%s_renasceu_no_ponto_seguro" % label, back and dist <= SAFE_RADIUS_M,
			{"marker": safe_marker, "dist": snappedf(dist, 0.1), "pos": _local.net_position})
	await _shot("%s_renasceu" % label)
	await _dbg(&"set_hp", [99999])


## Portal (interação de verdade com o objeto do mapa). Espera o novo mapa e o personagem nele.
func _portal(portal_id: String, dest: StringName) -> bool:
	var m: Node = _map()
	var area: Node3D = m.get_node_or_null(NodePath("Interactables/" + portal_id)) as Node3D if m != null else null
	if area == null:
		_check("portal_%s_existe" % portal_id, false)
		return false
	var approach: Vector3 = area.get_meta(&"approach_position", area.global_position)
	await _tp(approach)
	var seq: int = _spawn_seq
	Net.send_interact("m:" + portal_id)
	var ok: bool = await _wait(func() -> bool: return _spawn_seq > seq and NetWorld.client_map_id == dest, 60.0)
	await _sleep(3.0)
	_map_label = String(dest)
	_check("portal_%s_para_%s" % [portal_id, dest], ok, NetWorld.client_map_id)
	return ok


# ================================================================ roteiro

func _run() -> void:
	await _sleep(3.0)
	await _wait(func() -> bool: return not _progress.is_empty(), 15.0)
	_map_label = String(NetWorld.client_map_id)
	if args.get(ARG_ROLE, "") == ROLE_DUO:
		await _duo()
		_finish()
		return
	_check("personagem_novo_no_treino", NetWorld.client_map_id == &"training_field", NetWorld.client_map_id)
	await _shot("treino_chegada")
	await _training()
	if not await _portal("training_exit", &"city_awakening"):
		_finish()
		return
	_check("titulo_leva_ao_porto", NetWorld.client_map_id == &"city_awakening")
	await _shot("porto_chegada")
	# Lição da Mestra Brisa: Investida do Facão (6 redemoinhos) — pré-requisito da árvore pelo atalho.
	for req: StringName in Content.skill(&"blade_charge").required_skill_levels:
		await _dbg(&"skill_level", [req, Content.skill(&"blade_charge").required_skill_levels[req]])
	var lesson_ok: bool = await _accept(&"master_brisa", &"lesson_blade_charge")
	_check("licao_aceita_no_porto", lesson_ok, _opts)
	# Campos do Sabiá
	if not await _portal("gate_north", &"fields_sabia"):
		_finish()
		return
	await _shot("campos_chegada")
	await _fight_xp_drop(&"prank_whirlwind", "campos")
	var guard: int = 0
	while int(_quest(&"lesson_blade_charge").get("step", 0)) < 1 and guard < 10:
		guard += 1
		await _fight(&"prank_whirlwind", "campos_licao_%d" % guard, false)
		await _sleep(0.5)
	_check("licao_cumprida_cacando_nos_campos", bool(_quest(&"lesson_blade_charge").get("ready", false)), _quest(&"lesson_blade_charge"))
	await _death("campos", "SpawnPoint")
	for fields_map: StringName in [&"fields_sabia_buriti", &"fields_sabia_crossroads"]:
		if not await _portal("forward", fields_map):
			_finish()
			return
	# Mata Encantada
	await _dbg(&"grant_xp", [6000])
	await _spend_points()
	await _dbg(&"set_hp", [99999])
	if not await _portal("forward", &"enchanted_forest"):
		_finish()
		return
	await _shot("mata_chegada")
	await _fight_xp_drop(&"", "mata")
	await _death("mata", "SpawnPoint")
	for forest_map: StringName in [&"enchanted_forest_glade", &"enchanted_forest_roots", &"enchanted_forest_heart"]:
		if not await _portal("forward", forest_map):
			_finish()
			return
	# Chapada do Céu Partido
	for i: int in 4:
		await _dbg(&"grant_xp", [20000])
	await _spend_points()
	await _dbg(&"equip_item", [&"short_sword"])
	await _dbg(&"set_hp", [99999])
	if not await _portal("forward", &"split_sky_plateau"):
		_finish()
		return
	await _shot("chapada_chegada")
	await _fight_xp_drop(&"", "chapada")
	await _death("chapada", "SpawnPoint")
	await _bosses()
	# Volta
	for step: Array in [["back", &"enchanted_forest_heart"], ["back", &"enchanted_forest_roots"], ["back", &"enchanted_forest_glade"], ["back", &"enchanted_forest"], ["back", &"fields_sabia_crossroads"], ["back", &"fields_sabia_buriti"], ["back", &"fields_sabia"], ["back", &"city_awakening"]]:
		if not await _portal(step[0], step[1]):
			_finish()
			return
		if step[1] != &"city_awakening":
			_check("volta_chega_pelo_norte_%s" % step[1], _local.net_position.z < -25.0, _local.net_position)
		else:
			_check("volta_ao_porto_no_ponto_seguro", _flat(_local.net_position, _marker("SpawnPoint")) <= 6.0, _local.net_position)
		await _shot("volta_%s" % step[1])
	var learned: bool = await _turn_in(&"master_brisa", &"lesson_blade_charge")
	_check("licao_entregue_ensina_skill", learned and (_progress.get("skills", {}) as Dictionary).has("blade_charge"),
			_progress.get("skills"))
	await _elder_trial_in_city()
	_finish()


## Campo de Treino: título de verdade com o Mestre Jatobá.
func _training() -> void:
	const Q: StringName = &"tf_blade_title"
	var ok: bool = await _accept(&"master_jatoba", Q)
	_check("treino_quest_do_titulo_aceita", ok, _opts)
	await _dbg(&"equip_item", [&"machete"])
	await _fight_xp_drop(&"prank_whirlwind", "treino")
	var guard: int = 0
	while int(_quest(Q).get("step", 0)) < 1 and guard < 12:
		guard += 1
		await _fight(&"prank_whirlwind", "treino_%d" % guard, false)
	_check("treino_5_redemoinhos", int(_quest(Q).get("step", 0)) >= 1, _quest(Q))
	# Provação: derrubar o tatu no tempo (nível do treino ajuda; vida cheia).
	await _dbg(&"grant_xp", [3000])
	await _spend_points()
	await _dbg(&"set_hp", [99999])
	if await _talk(&"master_jatoba"):
		await _choose("QUEST_OPT_START_TRIAL")
		Net.send_dialogue_close()
		await _wait(func() -> bool: return not _entities(KIND_MONSTER, &"stone_armadillo").is_empty(), 8.0)
		await _shot("treino_provacao")
		var tatu: Node3D = _nearest(_entities(KIND_MONSTER, &"stone_armadillo"))
		if tatu != null:
			var tid: int = int(tatu.get(&"entity_id"))
			NetCombat.send_attack(tid)
			var end: int = Time.get_ticks_msec() + 110000
			while Time.get_ticks_msec() < end and not bool(_quest(Q).get("ready", false)):
				if not _deaths.has(tid):
					NetCombat.send_attack(tid)
				else:
					var t2: Node3D = _nearest(_entities(KIND_MONSTER, &"stone_armadillo"))
					if t2 != null:
						tid = int(t2.get(&"entity_id"))
				await _sleep(3.0)
	_check("treino_provacao_vencida", bool(_quest(Q).get("ready", false)), _quest(Q))
	var done: bool = await _turn_in(&"master_jatoba", Q)
	_check("treino_titulo_conquistado", done and "sabia_blade_machete" in _progress.get("titles", []), _progress.get("titles"))
	await _shot("treino_titulo")
	await _death("treino", "CampRespawn")


## Chapada: chefes fixos dos covis (sem evolução nem contagem de abates), noite (forma atroz) e a quest do Seu Zé.
func _bosses() -> void:
	const ZE: StringName = &"elder_ze_steel_song"
	await _dbg(&"grant_title", [&"sabia_arcane_firefly"])
	await _dbg(&"quest_accept", [ZE])
	await _dbg(&"give_item", [&"eternal_ember", 2])
	await _sleep(1.0)
	_check("ze_aceita_e_brasas_coletadas", int(_quest(ZE).get("step", -1)) == 1, _quest(ZE))
	# Chefe fixo: Tatu-Montanha no covil do sudeste.
	var lair: Vector3 = _marker("BossLairs/highland_stone_armadillo")
	await _tp(lair + Vector3(0, 0, 9))
	var boss_ok: bool = await _wait(func() -> bool: return _boss(&"stone_armadillo") != null, 15.0)
	_check("chapada_chefe_fixo_tatu_montanha", boss_ok)
	await _shot("chapada_chefe_dia")
	# Chefe fixo do covil da Rainha-Lume (mesmo setor).
	await _tp(_marker("BossLairs/highland_enchanted_firefly") + Vector3(0, 0, 9))
	var lume: bool = await _wait(func() -> bool: return _boss(&"enchanted_firefly") != null, 15.0)
	_check("chapada_covil_rainha_lume", lume)
	if lume:
		await _tp(_boss(&"enchanted_firefly").global_position + Vector3(0, 0, 6))
		await _shot("chapada_covil_rainha_lume")
		await _chat("/derrubar chefe")
		await _wait(func() -> bool: return int(_quest(ZE).get("step", -1)) >= 2, 6.0)
	_check("ze_chefe_da_chapada_conta_como_rainha_lume", int(_quest(ZE).get("step", -1)) >= 2, _quest(ZE))
	# Noite: o chefe fixo vira atroz.
	await _tp(lair + Vector3(0, 0, 9))
	await _dbg(&"set_hour", [22])
	var atroz: bool = await _wait(func() -> bool: return _boss(&"stone_armadillo") != null \
			and int(_boss(&"stone_armadillo").get(&"stage")) == MonsterDef.ATROZ_STAGE, 20.0)
	_check("chapada_noite_forma_atroz", atroz)
	await _sleep(3.0)
	await _shot("chapada_noite_atroz")
	await _chat("/derrubar chefe")
	await _wait(func() -> bool: return int(_quest(ZE).get("step", -1)) >= 3, 6.0)
	_check("ze_atroz_conta", int(_quest(ZE).get("step", -1)) >= 3, _quest(ZE))
	await _shot("chapada_noite_depois")
	await _dbg(&"set_hour", [12])
	await _sleep(2.0)


func _boss(species: StringName) -> Node3D:
	for e: Node3D in _entities(KIND_MONSTER):
		if int(e.get(&"stage")) >= CombatRules.STAGE_BOSS and MonsterDef.species_of(StringName(str(e.get(&"def_id")))) == species:
			return e
	return null


## Provação do Seu Zé junto dele, no Porto: o fantoche nasce, mas dá para lutar?
func _elder_trial_in_city() -> void:
	const ZE: StringName = &"elder_ze_steel_song"
	if int(_quest(ZE).get("step", -1)) != 3:
		await _dbg(&"quest_step", [ZE, 3])
	if not await _talk(&"elder_ze_ferreiro"):
		_check("porto_provacao_ze_conversa", false)
		return
	await _choose("QUEST_OPT_START_TRIAL")
	Net.send_dialogue_close()
	_check("provacao_entra_na_arena", await _wait(func() -> bool: return NetWorld.client_map_id == &"elder_trial_arena", 15.0))
	var appeared: bool = await _wait(func() -> bool: return not _entities(KIND_MONSTER, &"trial_twin_shield_puppet").is_empty(), 8.0)
	_check("porto_provacao_fantoche_nasce", appeared)
	if not appeared:
		return
	var p: Node3D = _nearest(_entities(KIND_MONSTER, &"trial_twin_shield_puppet"))
	var mark: int = _system.size()
	var hits0: int = _my_hits
	NetCombat.send_attack(int(p.get(&"entity_id")))
	await _sleep(4.0)
	await _shot("porto_provacao_ze")
	var refused: bool = "SYS_NO_COMBAT_HERE" in _system.slice(mark)
	Net.log_line("beta_route_city_trial", {"refused_no_combat": refused, "hits": _my_hits - hits0,
			"system": _system.slice(mark)})
	_check("porto_provacao_ze_da_para_lutar", _my_hits > hits0 and not refused,
			{"recusado_sem_combate": refused, "golpes": _my_hits - hits0})
	await _dbg(&"kill", [&"trial_twin_shield_puppet", 0])
	_check("provacao_volta_ao_porto", await _wait(func() -> bool: return NetWorld.client_map_id == &"city_awakening", 15.0))


## WebSocket: os dois se veem no Porto, formam grupo pelo chat (/grupo), vão aos Campos (mapa compartilhado
## desde 30/09/2026), se veem lá, lutam, ganham XP (dividida no grupo) e pegam o drop (do grupo).
func _duo() -> void:
	var me: String = args.get("name", "x")
	var other: String = args.get(ARG_WATCH, "")
	var seen: bool = await _wait(func() -> bool: return _player_named(other) != null, 30.0)
	_check("ws_ve_o_outro_no_porto", seen, other)
	await _shot("ws_porto_%s" % me)
	if me < other:
		await _chat("/grupo " + other)
	else:
		await _wait(func() -> bool: return NetParty.client_invite_from == other, 20.0)
		await _chat("/grupo aceitar")
	_check("ws_grupo_formado", await _wait(func() -> bool:
		return (NetParty.client_party.get(NetParty.K_MEMBERS, []) as Array).size() == 2, 20.0), NetParty.client_party)
	await _sleep(4.0)
	if not await _portal("gate_north", &"fields_sabia"):
		return
	_check("ws_ve_o_outro_nos_campos", await _wait(func() -> bool: return _player_named(other) != null, 30.0), other)
	await _shot("ws_campos_%s" % me)
	await _fight_xp_drop(&"prank_whirlwind", "ws_campos")
	await _sleep(2.0)


func _player_named(n: String) -> Node3D:
	for e: Node3D in NetCombat.all_entities():
		if StringName(str(e.get(&"kind"))) == &"player" and str(e.get(&"display_name")) == n:
			return e
	return null


func _finish() -> void:
	var failed: Array = []
	for k: String in _checks:
		if not _checks[k]:
			failed.append(k)
	Net.log_line("beta_route_done", {"checks": _checks.size(), "failed": failed})
	await _sleep(0.5)
	get_tree().quit(0 if failed.is_empty() else 1)
