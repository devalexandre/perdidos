extends Node
## Captura dos efeitos de skill NO CLIENTE REAL (regra do dono: visual só é "pronto" com captura do jogo).
## Sobe com: servidor em --progression-autotest (comandos de teste) e cliente com
##   -- --skill-fx-capture --fx-shots=DIR [--fx-only=prefixo1,prefixo2]
## (NetProgress cria este nó). No Campo de Treino, perto do ponto de nascimento: aprende as skills,
## põe bonecos ao lado e lança uma por uma, salvando quadros seguidos (DIR/<skill>_NN.png) para a
## prancha e os GIFs (tools/art/fx/fx_board.py). Termina com "fx_capture_done".
## 30/09/2026: também as skills da Terra do Sabiá v0.4 que já têm .tres (SkillFxBook), com a arma
## certa (facão para as de lâmina, arco para as de arco) e o ataque básico com arco (bow_basic_attack).

const ARG_SHOTS: String = "--fx-shots="
const ARG_ONLY: String = "--fx-only="
const WAIT_SEC: float = 8.0
const DUMMY: StringName = &"q_test_dummy"
const SHOT_EVERY_SEC: float = 0.08
const MACHETE: StringName = &"machete"
const BOW: StringName = &"simple_bow"
const BOW_BASIC: StringName = &"bow_basic_attack"
const OLD_SKILLS: Array[StringName] = [&"blade_firm_strike", &"blade_charge", &"blade_clearing_sweep",
	&"blade_horizon_cut", &"blade_steel_spin", &"blade_iron_stance", &"arcane_spark", &"arcane_will_o_wisp",
	&"arcane_creeping_flame", &"arcane_frost_burst", &"arcane_star_fall", &"arcane_barrier"]
## 06/10/2026: ofícios dos títulos (recebem os materiais antes) e o Surrupiar (num monstro de verdade, por
## último: o boneco é de provação e recusa). Ex.: ONLY=blade_field,blade_pilfer.
const OFICIOS: Array[StringName] = [&"bow_fletching", &"blade_field_dressing", &"arcane_bottle_light",
	&"bow_poison_tips", &"bow_feathering", &"hybrid_ember_tips", &"support_garrafada", &"tank_shell_salve",
	&"blade_pilfer"]
const STEAL_VICTIM: StringName = &"prank_whirlwind"
## Quanto tempo capturar depois do lançamento (além da conjuração).
const CAPTURE_SEC: Dictionary[StringName, float] = {
	&"blade_iron_stance": 1.6, &"arcane_barrier": 1.6, &"arcane_creeping_flame": 2.0,
	&"arcane_frost_burst": 1.4, &"blade_charge": 1.2, &"bow_arrow_flock": 1.6, &"support_bottle_brew": 1.6,
	&"arcane_fire_serpent": 1.6, &"support_bitter_smoke": 1.6, &"tank_living_wall": 1.4,
	&"arcane_crystal_wall": 1.4, &"support_coconut_water": 1.4}
const DEFAULT_CAPTURE_SEC: float = 1.2
## Espera máxima entre uma skill e outra (laços longos não precisam acabar por inteiro).
const MAX_SETTLE_SEC: float = 3.0

var _shots: String = ""
var _only: PackedStringArray = []
var _local: NetEntity = null
var _progress_seen: int = 0
var _weapon: StringName = &""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(ARG_SHOTS):
			_shots = a.trim_prefix(ARG_SHOTS)
		elif a.begins_with(ARG_ONLY):
			_only = a.trim_prefix(ARG_ONLY).split(",", false)
	if _shots.is_empty():
		_shots = OS.get_user_data_dir() + "/fx_shots"
	DirAccess.make_dir_recursive_absolute(_shots)
	ProgressionDebug.install_dummy_def()
	NetProgress.progress_changed.connect(func(_p: Dictionary) -> void: _progress_seen += 1)
	Net.local_player_spawned.connect(_on_spawned)
	get_tree().create_timer(1500.0).timeout.connect(func() -> void:
		print("fx_capture_timeout")
		get_tree().quit(2))


func _on_spawned(p: Node3D) -> void:
	if _local != null:
		return
	_local = p as NetEntity
	await _sleep(3.0)
	await _run()
	print("fx_capture_done")
	get_tree().quit(0)


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _dbg(cmd: StringName, args: Array = []) -> void:
	var before: int = _progress_seen
	NetProgress.send_debug(cmd, args)
	var end: int = Time.get_ticks_msec() + int(WAIT_SEC * 1000)
	while _progress_seen == before and Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _find(near: Vector3) -> NetEntity:
	var best: NetEntity = null
	var best_d: float = INF
	for n: Node in _local.get_parent().get_children():
		if n is NetEntity and (n as NetEntity).def_id == DUMMY and (n as NetEntity).hp_ratio > 0.0:
			var v: Node = n.get_node_or_null(^"Visual")
			if v is EntityVisual and (v as EntityVisual).get_nameplate() != null:
				(v as EntityVisual).get_nameplate().visible = false # sem nome de teste nas capturas
			var d: float = (n as NetEntity).position.distance_to(near)
			if d < best_d:
				best_d = d
				best = n as NetEntity
	return best


func _wanted(id: StringName) -> bool:
	if _only.is_empty():
		return true
	for p: String in _only:
		if String(id).begins_with(p):
			return true
	return false


## Skills a capturar: as 12 do MVP + as do livro que já têm .tres, na ordem das árvores.
func _skill_list() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StringName in OLD_SKILLS:
		if _wanted(s):
			out.append(s)
	for s: StringName in SkillFxBook.BOOK.keys():
		if Content.skill(s) != null and _wanted(s):
			out.append(s)
		elif Content.skill(s) == null and _wanted(s):
			print("fx_capture_missing_tres %s" % s)
	for s2: StringName in OFICIOS:
		if Content.skill(s2) != null and _wanted(s2) and s2 not in out:
			out.append(s2)
	return out


func _equip_for(def: SkillDef) -> void:
	var want: StringName = _weapon
	if def.get(&"requires_bow") == true or String(def.id).begins_with("bow_"):
		want = BOW
	elif def.requires_melee_weapon or _weapon == &"" or def.effect == SkillDef.Effect.STEAL:
		want = MACHETE
	if want != _weapon:
		await _dbg(&"equip_item", [want])
		_weapon = want
		await _sleep(0.6)


func _capture(name: StringName, total: float) -> void:
	var n: int = ceili(total / SHOT_EVERY_SEC)
	for i: int in n:
		await _sleep(SHOT_EVERY_SEC)
		get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [_shots, name, i])
	print("fx_capture_skill %s frames=%d" % [name, n])


func _run() -> void:
	var skills: Array[StringName] = _skill_list()
	await _dbg(&"grant_xp", [60000])
	await _equip_for(Content.skill(skills[0]) if not skills.is_empty() else SkillDef.new())
	for s: StringName in skills:
		await _dbg(&"learn", [s])
	await _sleep(6.0) # avisos de "aprendeu"/"título" somem antes das capturas
	var home: Vector3 = _local.position
	await _dbg(&"spawn_dummy", [DUMMY, 2.0, 0.0])
	await _dbg(&"spawn_dummy", [DUMMY, 1.0, -4.0])
	await _sleep(1.0)
	var slot: int = 0
	for s: StringName in skills:
		var a: NetEntity = _find(home + Vector3(2, 0, 0))
		var b: NetEntity = _find(home + Vector3(1, 0, -4))
		if a == null or b == null: # o boneco caiu: põe outro
			await _dbg(&"spawn_dummy", [DUMMY, 2.0, 0.0])
			await _dbg(&"spawn_dummy", [DUMMY, 1.0, -4.0])
			await _sleep(0.8)
			a = _find(home + Vector3(2, 0, 0))
			b = _find(home + Vector3(1, 0, -4))
		if a == null or b == null:
			print("fx_capture_no_dummy %s" % s)
			continue
		var def: SkillDef = Content.skill(s)
		await _equip_for(def)
		NetProgress.send_hotbar_set(slot, s)
		slot = (slot + 1) % 10
		if _local.position.distance_to(home) > 0.6:
			await _dbg(&"teleport", [home.x, home.z])
			await _sleep(1.0)
		await _dbg(&"set_mp", [9999])
		await _dbg(&"reset_cooldowns")
		var target_id: int = 0
		var pos: Vector3 = a.position
		match def.target_type:
			SkillDef.TargetType.SINGLE:
				target_id = (b if s in [&"blade_charge", &"arcane_spark", &"arcane_will_o_wisp"] or String(s).begins_with("bow_")
						or s in [&"arcane_firefly_swarm", &"blade_jaguar_leap", &"hybrid_steel_spark", &"tank_tapir_ram",
							&"support_bird_lime", &"support_omen", &"arcane_crystal_prison"] else a).entity_id
				pos = _entity_pos(target_id, a.position)
			SkillDef.TargetType.ALLY_OR_SELF:
				target_id = _local.entity_id
				pos = _local.position
			SkillDef.TargetType.SELF, SkillDef.TargetType.SELF_AREA:
				pos = _local.position
			SkillDef.TargetType.LINE:
				pos = b.position if s == &"blade_horizon_cut" else a.position
			SkillDef.TargetType.GROUND_AREA:
				pos = a.position + Vector3(0.5, 0, -1.0)
				if s == &"arcane_star_step":
					pos = _local.position + Vector3(-2.0, 0, 1.0)
		# corpo a corpo (Unhada, Corte em Brasa, Última Pancada): chega perto do alvo antes
		if def.target_type == SkillDef.TargetType.SINGLE and target_id != 0:
			var reach: float = def.range_cells * Balance.cfg.cell_size
			var to_t: Vector3 = pos - _local.position
			to_t.y = 0.0
			if to_t.length() > reach - 0.3 and reach > 0.0:
				var stand: Vector3 = pos - to_t.normalized() * maxf(reach - 0.6, 0.8)
				await _dbg(&"teleport", [stand.x, stand.z])
				await _sleep(0.8)
		if def.effect == SkillDef.Effect.CRAFT:
			var mats: Dictionary = def.extra.get(SkillCaster.X_MATERIALS, {})
			for m: Variant in mats:
				await _dbg(&"give_item", [StringName(str(m)), int(mats[m])])
		elif def.effect == SkillDef.Effect.STEAL:
			var victim: NetEntity = await _steal_victim(home)
			if victim == null:
				print("fx_capture_no_victim %s" % s)
				continue
			target_id = victim.entity_id
			pos = victim.position
			await _dbg(&"teleport", [pos.x - 1.0, pos.z])
			await _sleep(0.8)
		NetProgress.send_cast(s, target_id, pos)
		var total: float = def.cast_time_sec + def.ground_warning_sec + CAPTURE_SEC.get(s, DEFAULT_CAPTURE_SEC)
		await _capture(s, total)
		# espera os laços acabarem (até MAX_SETTLE_SEC) para não misturar com a próxima
		await _sleep(clampf(def.duration_sec - CAPTURE_SEC.get(s, DEFAULT_CAPTURE_SEC), 0.0, MAX_SETTLE_SEC) + 0.6)
	if _wanted(BOW_BASIC):
		await _bow_basic(home)


## Monstro comum (não de provação) ao lado de casa para o Surrupiar.
func _steal_victim(home: Vector3) -> NetEntity:
	await _dbg(&"spawn_rare", [STEAL_VICTIM, 2.0, 2.0])
	await _sleep(1.0)
	var best: NetEntity = null
	var best_d: float = INF
	for n: Node in _local.get_parent().get_children():
		var e: NetEntity = n as NetEntity
		if e != null and e.def_id == STEAL_VICTIM and e.hp_ratio > 0.0:
			var d: float = e.position.distance_to(home + Vector3(2, 0, 2))
			if d < best_d:
				best_d = d
				best = e
	return best


## Ataque básico com arco: a flecha voa do arqueiro até o boneco.
func _bow_basic(home: Vector3) -> void:
	await _dbg(&"equip_item", [BOW])
	_weapon = BOW
	await _sleep(0.8)
	if _local.position.distance_to(home) > 0.6:
		await _dbg(&"teleport", [home.x, home.z])
		await _sleep(1.0)
	var b: NetEntity = _find(home + Vector3(1, 0, -4))
	if b == null:
		await _dbg(&"spawn_dummy", [DUMMY, 1.0, -4.0])
		await _sleep(0.8)
		b = _find(home + Vector3(1, 0, -4))
	if b == null:
		return
	NetCombat.send_attack(b.entity_id)
	await _capture(BOW_BASIC, 2.4)
	NetCombat.send_stop_attack()


func _entity_pos(id: int, fallback: Vector3) -> Vector3:
	for n: Node in _local.get_parent().get_children():
		if n is NetEntity and (n as NetEntity).entity_id == id:
			return (n as NetEntity).position
	return fallback
