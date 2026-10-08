extends Node
## Companheiros de título que lutam e têm nível (PETS-E-MONTARIAS.md §0.1, 08/10/2026):
## ataque automático no alvo do dono (só em combate, alcance por espécie, zona sem combate), o bicho
## não é alvo (aggro e drop do dono), crítico pela SOR do dono, XP bônus de 20% sem tirar do dono,
## nível 1–50 com marcos 10/25/50, magias com recarga, PVP pela metade, save e equilíbrio (15–25%).
## Rodar: godot --headless --path game res://tests/progression/test_companion_combat.tscn

const MAP: StringName = &"fields_pindorama"
const ARENA: StringName = &"test_companion_arena"
const PEER: int = 7
var checks: int = 0
var failures: int = 0
var world: ServerWorld
var session: PlayerSession
var companions: CompanionService
var _entities: Array[NetEntity] = []
var _next_monster_id: int = 900000


func check(ok: bool, message: String, detail: Variant = null) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("  FAIL %s %s" % [message, str(detail) if detail != null else ""])
	return ok


func _ready() -> void:
	TranslationServer.set_locale("pt_BR")
	Net.is_server = true
	DamageFormula.test_force_hit = true
	world = ServerWorld.new()
	world.combat = CombatService.new(world)
	world.progression = Progression.new(world)
	world.companions = CompanionService.new(world)
	companions = world.companions
	companions.rng.seed = 4242
	world._instance_maps[MAP] = MAP
	world._instance_maps[&"city_awakening"] = &"city_awakening"
	session = _player(PEER, "Teste")
	_test_formulas()
	_test_balance()
	_test_save()
	_test_auto_attack()
	_test_not_target()
	_test_no_combat_zone()
	_test_crit_luck()
	_test_spells()
	_test_lume()
	_test_pvp_half()
	_test_bond_no_double()
	_test_xp_bonus()
	_test_levels()
	_test_client_hits()
	_test_client_ui()
	DamageFormula.test_force_hit = false
	for e: NetEntity in _entities:
		if is_instance_valid(e):
			e.free()
	world.free()
	print("test_companion_combat: %d checks, %d failures" % [checks, failures])
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(0 if failures == 0 else 1)


# ================================================================ apoio

func _player(peer: int, nick: String) -> PlayerSession:
	var entity := NetEntity.new()
	var sync := MultiplayerSynchronizer.new()
	sync.name = NetEntity.SYNC_NODE_NAME
	entity.add_child(sync)
	entity.server_setup(peer, &"player", nick, &"male", MAP, Vector3(2, 0, 2))
	var c := CharacterData.create_new(nick, &"male")
	c.left_training = true
	var s := PlayerSession.new(peer, entity, c)
	world._sessions[peer] = s
	world._entities[peer] = entity
	_entities.append(entity)
	world.combat.on_player_spawned(s)
	return s


func _monster(pos: Vector3, monster_id: StringName = &"maned_wolf") -> NetEntity:
	var def: MonsterDef = Content.monster(monster_id)
	_next_monster_id += 1
	var e := NetEntity.new()
	var sync := MultiplayerSynchronizer.new()
	sync.name = NetEntity.SYNC_NODE_NAME
	e.add_child(sync)
	e.server_setup(_next_monster_id, NetEntity.KIND_MONSTER, "M", def.id, MAP, pos)
	var brain := MonsterBrain.new()
	brain.name = MonsterBrain.NODE_NAME
	e.add_child(brain)
	brain.setup(world.combat, def, def.stages[0], pos, 3.0)
	world._entities[e.entity_id] = e
	world.combat.register_monster(e)
	_entities.append(e)
	return e


func _brain(e: NetEntity) -> MonsterBrain:
	return world.combat.get_brain(e)


## Vida alta para a luta não acabar no meio do teste.
func _tough(e: NetEntity) -> void:
	var b: MonsterBrain = _brain(e)
	b.stage = b.stage.duplicate() as MonsterStage
	b.stage.max_hp = 100000
	b.hp = 100000
	b.apply_to_entity()


func _activate(id: StringName, level: int = 1) -> CompanionDef:
	var def: CompanionDef = Content.companion(id)
	session.character.progression.titles[def.title_id] = 1
	if id not in session.character.companions_owned:
		session.character.companions_owned.append(id)
	companions._activate(session, id)
	session.character.companion_progress[String(id)] = {"level": level, "xp": 0}
	companions.forget(PEER)
	return def


## Põe o dono em combate com o alvo (como se tivesse acabado de acertá-lo).
func _engage(target: NetEntity, now: int) -> void:
	companions.on_hit(session.entity, target, &"bow_low_shot", 0, now)
	world.combat.mark_combat(PEER)


func _hp(e: NetEntity) -> int:
	return _brain(e).hp


func _stats(level: int, attrs: Dictionary, weapon: StringName) -> Dictionary:
	var base: Dictionary[StringName, int] = CharacterStats.base_attributes()
	for k: StringName in attrs:
		base[k] = int(attrs[k])
	var eq := Equipment.new()
	eq.set_slot(&"weapon", ItemStack.create(weapon, 1))
	return CharacterStats.compute(level, base, eq)


# ================================================================ fórmulas

func _test_formulas() -> void:
	var b: BalanceConfig = Balance.cfg
	check(b.companion_max_level == 50 and is_equal_approx(b.companion_xp_share, 0.2)
			and b.companion_spell_levels == [1, 10, 25] and b.companion_milestones == [10, 25, 50],
			"constantes de companheiro no Balance")
	check(is_equal_approx(CompanionService.crit_chance(0, 1), 0.011), "crítico: 1% + nível 1 × 0,1%",
			CompanionService.crit_chance(0, 1))
	check(is_equal_approx(CompanionService.crit_chance(50, 1), 0.161), "crítico: + SOR 50 × 0,3%",
			CompanionService.crit_chance(50, 1))
	check(CompanionService.crit_chance(50, 40) > CompanionService.crit_chance(50, 1)
			and CompanionService.crit_chance(100, 1) > CompanionService.crit_chance(50, 1), "mais SOR/nível = mais crítico")
	check(CompanionService.crit_chance(1000, 50) == 1.0, "crítico limitado a 100%")
	check(CompanionService.xp_to_next(1) == 4 and CompanionService.xp_to_next(10) == floori(4.0 * pow(10, 1.5))
			and CompanionService.xp_to_next(50) == 0, "curva própria de XP (4 × nível^1,5; 0 no 50)")
	var harpy: CompanionDef = Content.companion(CompanionService.HARPY)
	var guara: CompanionDef = Content.companion(CompanionService.GUARA)
	var lume: CompanionDef = Content.companion(CompanionService.LUME)
	check(harpy.owner_attribute == &"dex" and guara.owner_attribute == &"str" and lume.owner_attribute == &"int",
			"atributo do dono: Harpia DES, Guará FOR, Lume INT")
	check(is_equal_approx(harpy.attack_range_cells, 6.0) and is_equal_approx(guara.attack_range_cells, 1.0)
			and lume.attack_interval_sec <= 0.0, "alcance: Harpia 6, Guará 1; Lume sem ataque corpo a corpo")
	check(CompanionService.power(harpy, 10, {&"dex": 50}) > CompanionService.power(harpy, 10, {&"dex": 5})
			and CompanionService.power(harpy, 20, {&"dex": 5}) > CompanionService.power(harpy, 10, {&"dex": 5}),
			"poder sobe com o nível e com o atributo do dono")
	check(CompanionService.power(guara, 10, {&"dex": 90, &"str": 5}) == CompanionService.power(guara, 10, {&"dex": 5, &"str": 5}),
			"guará ignora a DES (usa a FOR)")
	for def: CompanionDef in [harpy, guara, lume]:
		check(def.spells.size() == 3, "%s: 3 magias" % def.id)
		check(CompanionService.unlocked_spells(def, 1).size() == 1 and CompanionService.unlocked_spells(def, 9).size() == 1
				and CompanionService.unlocked_spells(def, 10).size() == 2 and CompanionService.unlocked_spells(def, 24).size() == 2
				and CompanionService.unlocked_spells(def, 25).size() == 3, "%s: magias nos níveis 1/10/25" % def.id)
		for spell: StringName in def.spells:
			var sd: SkillDef = Content.companion_skill(spell)
			check(sd != null and sd.cooldown_sec > 0.0 and Content.skill(spell) == null and Content.any_skill(spell) == sd,
					"%s em data/companion_skills, com recarga" % spell)
	check(CompanionService.evolution_stage(9) == 0 and CompanionService.evolution_stage(10) == 1
			and CompanionService.evolution_stage(25) == 2 and CompanionService.evolution_stage(50) == 3, "marcos 10/25/50")
	check(CompanionService.visual_scale_for(harpy, 50) > CompanionService.visual_scale_for(harpy, 25)
			and CompanionService.visual_scale_for(harpy, 25) > CompanionService.visual_scale_for(harpy, 1)
			and is_equal_approx(CompanionService.visual_scale_for(harpy, 1), harpy.visual_scale), "evolução visual cresce")
	var parsed: Dictionary = CompanionService.parse_source(CompanionService.source_for(CompanionService.HARPY, "comp_harpy_feather_gust"))
	check(parsed.id == CompanionService.HARPY and parsed.tag == "comp_harpy_feather_gust"
			and CompanionService.parse_source(&"basic_attack").is_empty(), "fonte companion_<id>:<magia>")


## Teste de equilíbrio: o bicho rende 15–25% do dano do dono no mesmo nível e equipamento. Dono no
## nível L com 60% dos pontos no atributo principal e 10% em SOR/secundário; arma real da faixa; bicho
## no nível 2L − 1 (ele vai a 50 quando o dono vai a 25). Dano do dono = ataque básico (com crítico).
func _test_balance() -> void:
	var bows: Dictionary = {1: &"simple_bow", 5: &"buriti_recurve", 10: &"crystal_recurve_bow", 15: &"forest_boy_bow",
			20: &"arco_do_sussurro_noturno", 25: &"living_flame_bow"}
	var wands: Dictionary = {1: &"wooden_staff", 5: &"ipe_wand", 10: &"firefly_wand", 15: &"rootweave_staff",
			20: &"singing_waters_staff", 25: &"living_flame_staff"}
	var rng := RandomNumberGenerator.new()
	var report: Array[String] = []
	for id: StringName in [CompanionService.HARPY, CompanionService.GUARA, CompanionService.LUME]:
		var def: CompanionDef = Content.companion(id)
		for level: int in [1, 5, 10, 15, 20, 25]:
			var pts: int = 3 * (level - 1)
			var main: int = 5 + int(0.6 * pts)
			var minor: int = 5 + int(0.1 * pts)
			var owner_dps: float
			var aps: float = 0.0
			var st: Dictionary
			if id == CompanionService.LUME:
				st = _stats(level, {&"int": main, &"dex": minor, &"luk": minor}, wands[level])
				owner_dps = float(st[CharacterStats.K_MATK]) * DamageFormula.attacks_per_second(int(st[&"dex"]))
			else:
				st = _stats(level, {&"dex": main, &"str": minor, &"luk": minor}, bows[level])
				aps = DamageFormula.attacks_per_second(int(st[&"dex"]))
				owner_dps = float(st[CharacterStats.K_ATK]) * aps \
						* (1.0 + DamageFormula.crit_chance(int(st[&"luk"])) * (CombatRules.CRIT_MULTIPLIER - 1.0))
			var clevel: int = clampi(2 * level - 1, 1, 50)
			rng.seed = 77 + level
			var mine: float = CompanionService.simulate_dps(def, clevel, st, aps, 300.0, rng)
			var ratio: float = mine / owner_dps
			report.append("%s L%d/c%d %.0f%%" % [String(id).trim_prefix("pindorama_companion_"), level, clevel, ratio * 100.0])
			check(ratio >= 0.15 and ratio <= 0.25, "equilíbrio %s dono %d / bicho %d: 15–25%% do dano do dono" % [id, level, clevel],
					"%.3f (bicho %.1f/s, dono %.1f/s)" % [ratio, mine, owner_dps])
	print("  equilíbrio: " + ", ".join(report))


# ================================================================ save

func _test_save() -> void:
	var c: CharacterData = session.character
	c.companions_owned = [CompanionService.HARPY, CompanionService.GUARA]
	c.companion_active = CompanionService.HARPY
	c.companion_progress = {String(CompanionService.HARPY): {"level": 12, "xp": 30},
			String(CompanionService.GUARA): {"level": 3, "xp": 1}}
	var saved: Dictionary = c.to_save()
	var loaded: CharacterData = CharacterData.from_save(saved)
	check(loaded.companion_progress.get(String(CompanionService.HARPY), {}).get("level") == 12
			and loaded.companion_progress[String(CompanionService.HARPY)].xp == 30
			and loaded.companion_progress[String(CompanionService.GUARA)].level == 3, "nível/XP por companheiro persistem")
	check(int(saved.format) == CharacterData.SAVE_FORMAT_VERSION, "formato do save inalterado (chave nova opcional)")
	var old: Dictionary = saved.duplicate(true)
	(old.companions as Dictionary).erase("progress")
	loaded = CharacterData.from_save(old)
	check(loaded != null and loaded.companion_progress.is_empty() and companions.level_of(loaded, CompanionService.HARPY) == 1,
			"save antigo sem progresso: nível 1")
	var bad: Dictionary = saved.duplicate(true)
	bad.companions.progress = {"nao_existe": {"level": 9}, String(CompanionService.HARPY): {"level": 999, "xp": -5}}
	loaded = CharacterData.from_save(bad)
	check(not loaded.companion_progress.has("nao_existe") and loaded.companion_progress[String(CompanionService.HARPY)].level == 50
			and loaded.companion_progress[String(CompanionService.HARPY)].xp == 0, "save inválido é saneado")
	c.companion_progress.clear()
	c.companions_owned.clear()
	c.companion_active = &""


# ================================================================ ataque automático

func _test_auto_attack() -> void:
	var def: CompanionDef = _activate(CompanionService.HARPY)
	var m: NetEntity = _monster(Vector3(6, 0, 2)) # 4 células
	_tough(m)
	var start: int = _hp(m)
	# Sem combate: só segue.
	world.combat._players[PEER].last_combat_msec = -1000000
	companions.tick(1000)
	check(_hp(m) == start, "fora de combate o bicho não ataca")
	_engage(m, 2000)
	companions._spell_ready[PEER] = {&"comp_harpy_feather_gust": 1000000}
	companions.tick(2000)
	var after: int = _hp(m)
	check(after < start, "em combate o bicho ataca o alvo atual do dono", [start, after])
	companions.tick(2500)
	check(_hp(m) == after, "respeita o intervalo da espécie (2 s)")
	companions.tick(4000)
	check(_hp(m) < after, "ataca de novo depois do intervalo")
	# Fora do alcance (harpia 6 células).
	var far: NetEntity = _monster(Vector3(12, 0, 2)) # 10 células
	_tough(far)
	var far_hp: int = _hp(far)
	world.combat._players[PEER].target = null
	_engage(far, 5000)
	companions.tick(7000)
	check(_hp(far) == far_hp, "harpia não alcança a 10 células")
	# Guará: corre até 5 células do dono e morde a 1.
	_activate(CompanionService.GUARA)
	companions._spell_ready[PEER] = {&"comp_guara_howl": 1000000}
	var near: NetEntity = _monster(Vector3(7, 0, 2)) # 5 células
	_tough(near)
	var near_hp: int = _hp(near)
	_engage(near, 8000)
	companions.tick(8000)
	check(_hp(near) < near_hp, "guará corre e morde a 5 células do dono")
	_engage(far, 9000)
	companions.tick(12000)
	check(_hp(far) == far_hp, "guará não vai a 10 células")
	# O dano é o do bicho, não o ATK do dono (FOR baixa, DES altíssima, arco forte).
	session.character.base_attributes[&"dex"] = 300
	session.character.equipment.set_slot(&"weapon", ItemStack.create(&"living_flame_bow", 1))
	var power: int = CompanionService.power(Content.companion(CompanionService.GUARA), 1, session.character.compute_stats())
	var before: int = _hp(near)
	_engage(near, 13000)
	companions.tick(13000)
	var dealt: int = before - _hp(near)
	check(dealt > 0 and dealt <= ceili(power * CombatRules.CRIT_MULTIPLIER * 1.1) + 1,
			"dano pelo poder do bicho (não pelo ATK do dono)", [dealt, power, session.character.compute_stats()[&"atk"]])
	session.character.base_attributes[&"dex"] = CharacterStats.BASE_ATTRIBUTE
	session.character.equipment.set_slot(&"weapon", null)
	check(def.attack_interval_sec > 0.0, "harpia tem intervalo próprio")


func _test_not_target() -> void:
	_activate(CompanionService.HARPY)
	var m: NetEntity = _monster(Vector3(5, 0, 2))
	_tough(m)
	var owner_hp: int = session.character.hp
	_engage(m, 20000)
	companions._spell_ready[PEER] = {&"comp_harpy_feather_gust": 1000000}
	# O dono só "marcou" o alvo (golpe 0): quem bate é o bicho.
	_brain(m).damage_by_peer.clear()
	_brain(m).last_hitter_peer = 0
	companions.tick(20000)
	var b: MonsterBrain = _brain(m)
	check(b.last_hitter_peer == PEER and int(b.damage_by_peer.get(PEER, 0)) > 0, "aggro e dano do bicho vão para o dono")
	check(b.top_damage_peer() == PEER, "drop/posse do monstro é do dono")
	var others: int = 0
	for e: Variant in world._entities.values():
		if is_instance_valid(e) and not ((e as NetEntity).is_player() or (e as NetEntity).is_monster()):
			others += 1
	check(others == 0, "o companheiro não é entidade do servidor (não pode ser alvo)")
	check(session.character.hp == owner_hp, "o dono não perde vida com o golpe do bicho")
	check(not companions.on_hit(session.entity, m, CompanionService.source_for(CompanionService.HARPY), 10, 30000),
			"golpe do bicho não aciona proc nem troca o alvo")


func _test_no_combat_zone() -> void:
	_activate(CompanionService.HARPY)
	var m: NetEntity = _monster(Vector3(5, 0, 2))
	_tough(m)
	m.instance_id = &"city_awakening"
	session.entity.instance_id = &"city_awakening"
	var hp: int = _hp(m)
	_engage(m, 31000)
	companions.tick(31000)
	check(_hp(m) == hp, "zona sem combate: o bicho não ataca")
	session.entity.instance_id = MAP


# ================================================================ crítico

func _test_crit_luck() -> void:
	_activate(CompanionService.HARPY, 20)
	session.character.base_attributes[&"luk"] = 60
	var mods: Dictionary = {"crit_override": -1.0, "dmg_mult": 1.0}
	var atk: Dictionary = {&"atk": 999, &"luk": 60}
	var dfn: Dictionary = {&"def": 40}
	companions.pre_hit(session.entity, CompanionService.source_for(CompanionService.HARPY), mods, atk, dfn)
	var expected: float = 0.01 + 60 * 0.003 + 20 * 0.001
	check(is_equal_approx(float(mods.crit_override), expected) and is_equal_approx(float(mods.magic_crit), expected),
			"crítico do bicho = 1% + 0,3% × SOR do dono + nível", mods)
	check(int(atk[&"atk"]) == CompanionService.power(Content.companion(CompanionService.HARPY), 20, session.character.compute_stats()),
			"ATK do golpe = poder do bicho")
	check(int(dfn[&"def"]) == 20, "mergulho da harpia ignora metade da DEF")
	# Amostra: chance observada ≈ esperada; crítico multiplica pela regra do jogo.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var crits: int = 0
	var weak_crits: int = 0
	for i: int in 10000:
		var r: Dictionary = DamageFormula.compute({&"atk": 100, &"dex": 50}, {&"def": 0, &"dex": 0}, 1.0,
				CombatRules.DamageType.PHYSICAL, rng, expected)
		if r.crit:
			crits += 1
			if int(r.amount) < roundi(100 * 0.9 * CombatRules.CRIT_MULTIPLIER) - 1:
				weak_crits += 1
	check(weak_crits == 0, "crítico multiplica pela regra do jogo (×1,5)")
	check(absf(crits / 10000.0 - expected) < 0.015, "10 mil golpes: crítico pela SOR", crits)
	session.character.base_attributes[&"luk"] = 0
	var low: Dictionary = {"crit_override": -1.0}
	companions.pre_hit(session.entity, CompanionService.source_for(CompanionService.HARPY), low, {&"atk": 1}, {&"def": 0})
	check(float(low.crit_override) < expected, "SOR menor, crítico menor")
	session.character.base_attributes[&"luk"] = CharacterStats.BASE_ATTRIBUTE


# ================================================================ magias

func _test_spells() -> void:
	_activate(CompanionService.HARPY, 1)
	var m: NetEntity = _monster(Vector3(5, 0, 2))
	_tough(m)
	_engage(m, 40000)
	companions.tick(40000)
	var ready: Dictionary = companions._spell_ready.get(PEER, {})
	check(int(ready.get(&"comp_harpy_feather_gust", 0)) == 49000, "Rajada de Penas lançada, recarga de 9 s", ready)
	check(not ready.has(&"comp_harpy_high_cry"), "nível 1: só a 1ª magia")
	companions.tick(45000)
	check(int(companions._spell_ready[PEER][&"comp_harpy_feather_gust"]) == 49000, "não relança na recarga")
	_engage(m, 49000)
	companions.tick(49000)
	check(int(companions._spell_ready[PEER][&"comp_harpy_feather_gust"]) == 58000, "relança depois da recarga")
	# Nível 10: Grito do Alto (alvo perde esquiva).
	_activate(CompanionService.HARPY, 10)
	companions._spell_ready[PEER] = {&"comp_harpy_feather_gust": 1000000}
	_engage(m, 60000)
	companions.tick(60000)
	var statuses: StatusEffects = world.progression.statuses
	check(is_equal_approx(statuses.mod(m, StatusEffects.M_EVADE), -0.15), "Grito do Alto: −15% de esquiva no alvo")
	var dfn: Dictionary = {&"dex": 30, &"def": 0}
	statuses.pre_hit(session.entity, m, &"physical", &"basic_attack", {&"atk": 10}, dfn)
	check(int(dfn[&"dex"]) == 15, "esquiva negativa vira DES menor no acerto", dfn)
	# Guará: Uivo (lentidão em área) no nível 1, Bote (atordoa) no 10.
	_activate(CompanionService.GUARA, 10)
	var a: NetEntity = _monster(Vector3(5, 0, 2))
	var b: NetEntity = _monster(Vector3(5, 0, 4)) # 2 células de a
	_tough(a)
	_tough(b)
	_engage(a, 70000)
	companions.tick(70000)
	check(statuses.has(a, StatusEffects.Kind.SLOW) and statuses.has(b, StatusEffects.Kind.SLOW), "Uivo do Cerrado: lentidão em área")
	_engage(a, 70100)
	companions.tick(70100)
	check(statuses.is_stunned(a), "Bote: atordoamento curto")
	check(companions._spell_ready[PEER].has(&"comp_guara_pounce") and not companions._spell_ready[PEER].has(&"comp_guara_deep_bite"),
			"nível 10: 2 magias, a 3ª só no 25")


func _test_lume() -> void:
	_activate(CompanionService.LUME, 25)
	var m: NetEntity = _monster(Vector3(5, 0, 2))
	_tough(m)
	var hp: int = _hp(m)
	_engage(m, 80000)
	companions.tick(80000)
	check(_hp(m) < hp, "Lume: Centelha (dano mágico) no nível 1")
	companions._next_attack.erase(PEER)
	companions._spell_ready[PEER] = {&"comp_lume_spark": 1000000, &"comp_lume_swarm": 1000000}
	var after: int = _hp(m)
	_engage(m, 81000)
	companions.tick(81000)
	check(_hp(m) == after, "Lume não ataca corpo a corpo")
	var max_hp: int = int(session.character.compute_stats()[CharacterStats.K_MAX_HP])
	session.character.hp = roundi(max_hp * 0.9)
	_engage(m, 82000)
	companions.tick(82000)
	check(session.character.hp == roundi(max_hp * 0.9), "Luz que Cura não cura acima de 70%")
	session.character.hp = roundi(max_hp * 0.3)
	_engage(m, 82100)
	companions.tick(82100)
	check(session.character.hp > roundi(max_hp * 0.3), "Luz que Cura cura o dono abaixo de 70%")
	session.character.hp = max_hp
	# Enxame (área) no 25.
	companions._spell_ready[PEER] = {&"comp_lume_spark": 1000000, &"comp_lume_heal": 1000000}
	var other: NetEntity = _monster(Vector3(5, 0, 3))
	_tough(other)
	var other_hp: int = _hp(other)
	_engage(m, 83000)
	companions.tick(83000)
	check(_hp(other) < other_hp, "Enxame acerta em área")


# ================================================================ PVP

func _test_pvp_half() -> void:
	var arena := ZoneDef.new()
	arena.kind = ZoneDef.Kind.PVP
	Content._db[&"zones"][ARENA] = arena
	check(is_equal_approx(companions.pvp_multiplier(ARENA), 0.5) and is_equal_approx(companions.pvp_multiplier(MAP), 1.0),
			"multiplicador PVP do bicho: metade")
	_activate(CompanionService.HARPY, 5)
	var mods: Dictionary = {"dmg_mult": 1.0}
	session.entity.instance_id = ARENA
	companions.pre_hit(session.entity, CompanionService.source_for(CompanionService.HARPY), mods, {&"atk": 1}, {&"def": 0})
	check(is_equal_approx(float(mods.dmg_mult), 0.5), "na Arena da Queimada o golpe do bicho sai pela metade", mods)
	var spell_mods: Dictionary = {"dmg_mult": 1.0}
	companions.pre_hit(session.entity, CompanionService.source_for(CompanionService.HARPY, "comp_harpy_feather_gust"),
			spell_mods, {&"atk": 1}, {&"def": 0})
	check(is_equal_approx(float(spell_mods.dmg_mult), 0.5), "magias do bicho também pela metade no PVP")
	session.entity.instance_id = MAP
	var normal: Dictionary = {"dmg_mult": 1.0}
	companions.pre_hit(session.entity, CompanionService.source_for(CompanionService.HARPY), normal, {&"atk": 1}, {&"def": 0})
	check(is_equal_approx(float(normal.dmg_mult), 1.0), "fora do PVP, dano cheio")
	Content._db[&"zones"].erase(ARENA)


# ================================================================ vínculo

func _test_bond_no_double() -> void:
	_activate(CompanionService.HARPY, 1)
	session.character.equipment.set_slot(&"weapon", ItemStack.create(&"simple_bow", 1))
	session.character.base_attributes[&"dex"] = 200 # chance no teto (20%)
	var m: NetEntity = _monster(Vector3(5, 0, 2))
	_tough(m)
	companions._spell_ready[PEER] = {&"comp_harpy_feather_gust": 10000000}
	_engage(m, 100000)
	companions.tick(100000) # golpe automático
	check(int(companions._last_attack.get(PEER, 0)) == 100000, "golpe automático registrado")
	var early: int = 0
	for t: int in range(100100, 100900, 100):
		if companions.on_hit(session.entity, m, CombatService.SOURCE_BASIC_ATTACK, 10, t):
			early += 1
	check(early == 0, "Garra do Alto não dobra o golpe logo depois do automático")
	var procs: int = 0
	var t2: int = 101000
	while procs == 0 and t2 < 160000:
		if companions.on_hit(session.entity, m, CombatService.SOURCE_BASIC_ATTACK, 10, t2):
			procs += 1
			check(int(companions._next_attack[PEER]) == t2 + 2000, "Garra do Alto adianta o mergulho e reinicia o relógio")
			var hp: int = _hp(m)
			companions.tick(t2 + 100)
			check(_hp(m) == hp, "sem golpe automático logo depois do adiantado")
		t2 += 1000
	check(procs == 1, "Garra do Alto aciona com chance pela DES")
	session.character.base_attributes[&"dex"] = CharacterStats.BASE_ATTRIBUTE
	session.character.equipment.set_slot(&"weapon", null)


# ================================================================ XP e nível

func _test_xp_bonus() -> void:
	_activate(CompanionService.HARPY, 1)
	var c: CharacterData = session.character
	var data: ProgressionData = c.progression
	var m: NetEntity = _monster(Vector3(5, 0, 2))
	var before_total: int = data.total_xp
	world.progression._on_monster_killed(PEER, &"maned_wolf", 1, 100)
	var owner_with: int = data.total_xp - before_total
	var entry: Dictionary = c.companion_progress[String(CompanionService.HARPY)]
	var companion_xp: int = int(entry.level) * 0 + int(entry.xp)
	for l: int in range(1, int(entry.level)):
		companion_xp += CompanionService.xp_to_next(l)
	check(companion_xp == 20, "bicho ganha 20% do XP do monstro", entry)
	# Sem companheiro: o dono ganha exatamente o mesmo.
	companions._activate(session, &"")
	before_total = data.total_xp
	world.progression._on_monster_killed(PEER, &"maned_wolf", 1, 100)
	var owner_without: int = data.total_xp - before_total
	check(owner_with == owner_without and owner_with > 0, "o XP do dono não diminui com o bônus do bicho",
			[owner_with, owner_without])
	# Quem não participou (outro jogador sem golpe nem grupo) não dá XP ao bicho dele.
	var other: PlayerSession = _player(8, "Outro")
	other.character.companions_owned = [CompanionService.HARPY]
	other.character.companion_active = CompanionService.HARPY
	world.progression._on_monster_killed(PEER, &"maned_wolf", 1, 100)
	check(not other.character.companion_progress.has(String(CompanionService.HARPY)), "sem participar, sem XP para o bicho")
	check(m != null, "monstro de apoio")


func _test_levels() -> void:
	_activate(CompanionService.HARPY, 1)
	var c: CharacterData = session.character
	companions.grant_xp(session, CompanionService.HARPY, CompanionService.xp_to_next(1))
	check(companions.level_of(c, CompanionService.HARPY) == 2, "sobe de nível com a curva própria")
	var total: int = 0
	for l: int in range(2, 10):
		total += CompanionService.xp_to_next(l)
	companions.grant_xp(session, CompanionService.HARPY, total)
	check(companions.level_of(c, CompanionService.HARPY) == 10, "nível 10 (marco)")
	world.refresh_appearance(session)
	check(int(session.entity.appearance.get(&"companion_level", 0)) == 10, "aparência leva o nível (evolução visual)")
	check(CompanionService.unlocked_spells(Content.companion(CompanionService.HARPY), 10).size() == 2, "marco 10 libera a 2ª magia")
	companions.grant_xp(session, CompanionService.HARPY, 10000000)
	check(companions.level_of(c, CompanionService.HARPY) == 50 and int(c.companion_progress[String(CompanionService.HARPY)].xp) == 0,
			"nível máximo 50")
	check(companions.grant_xp(session, CompanionService.HARPY, 100) == 0, "no 50 não ganha mais XP")
	var snap: Dictionary = companions.snapshot(session)
	var entry: Dictionary = snap.progress.get(String(CompanionService.HARPY), {})
	check(int(entry.get("level", 0)) == 50 and int(entry.get("stage", 0)) == 3 and (entry.get("spells", []) as Array).size() == 3,
			"janela de Seguidores recebe nível, marco e magias", entry)


## Cliente: o golpe do bicho chega antes do NetCombat.hit; os N golpes seguintes do dono são do bicho
## (número turquesa, sem animar o dono).
func _test_client_hits() -> void:
	NetFollowers._cli_strike(PEER, 1234, String(CompanionService.HARPY), "comp_harpy_feather_gust", 2)
	check(NetFollowers.take_companion_hit(PEER) and NetFollowers.take_companion_hit(PEER)
			and not NetFollowers.take_companion_hit(PEER), "dois golpes do bicho, o terceiro é do dono")
	NetFollowers._cli_strike(PEER, PEER, String(CompanionService.LUME), "comp_lume_heal", 0)
	check(not NetFollowers.take_companion_hit(PEER), "cura não marca golpe")
	check(Color(CombatFx.COLOR_COMPANION) != CombatFx.COLOR_DEALT, "cor própria para o dano do bicho")


## Janela de Seguidores e medidor do retrato com o nível/XP do bicho.
func _test_client_ui() -> void:
	for path: String in ["res://scripts/client/follower_visual.gd", "res://scripts/client/ui/followers_window.gd",
			"res://scripts/client/combat/player_bars.gd", "res://scripts/client/entity_visual.gd",
			"res://scripts/client/combat/skill_fx.gd", "res://scripts/client/combat/combat_fx.gd",
			"res://scripts/server/progression/progression_debug.gd"]:
		var script: Script = load(path) as Script
		check(script != null and script.can_instantiate(), "script do cliente compila: " + path)
	_activate(CompanionService.HARPY, 12)
	var progress: Dictionary = {"companions": companions.snapshot(session), "quests": [], "mounts": {}}
	var window := FollowersWindow.new(1.0)
	add_child(window)
	window.set_progress(progress)
	var bar: ProgressBar = window.find_child("CompanionXp_" + String(CompanionService.HARPY), true, false) as ProgressBar
	check(bar != null and int(bar.max_value) == CompanionService.xp_to_next(12), "janela mostra a barra de XP do bicho")
	window.free()
	var bars := PlayerBars.new(1.0, null)
	bars.set_companion_progress(progress)
	check(bars.companion_bar.visible and bars.companion_label.text.contains("12"), "medidor ao lado do retrato com o nível",
			bars.companion_label.text)
	bars.set_companion_progress({"companions": {"active": ""}})
	check(not bars.companion_bar.visible, "sem companheiro, sem medidor")
	bars.free()
	check(FollowerVisual.label_text("Asa", 7).contains("7") and FollowerVisual.label_text("Asa", 7).begins_with("Asa"),
			"rótulo do bicho com nome e nível")
