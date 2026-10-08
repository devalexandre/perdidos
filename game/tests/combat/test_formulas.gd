extends Node
## Testes headless das fórmulas do combate (GDD §6.4, §10.2, §10.6): DamageFormula,
## MonsterEvolution, CombatBridges (curva de XP e teto de estágio) e a coerência dos dados reais de
## data/monsters (W). A IA e o fluxo em rede ficam no autoteste (tests/combat/run_combat_autotest.sh).
## Rodar: godot --headless --path game res://tests/combat/test_formulas.tscn

const EPS: float = 0.0001
const SAMPLES: int = 4000
## Tolerância da frequência de crítico medida (absoluta).
const CRIT_FREQ_TOLERANCE: float = 0.03
const SEED: int = 12345

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_test_defense()
	_test_crit_and_speed()
	_test_roll_bounds()
	_test_compute_types()
	_test_regen()
	_test_luck_and_accuracy()
	_test_evolution()
	_test_bridges()
	_test_real_monster_data()
	_test_folklore_vulnerabilities()
	_test_attribute_scaling()
	print("test_combat_formulas: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL %s %s" % [what, str(detail) if detail != null else ""])


func _near(a: float, b: float, what: String) -> void:
	_check(absf(a - b) < EPS, what, [a, b])


func _test_defense() -> void:
	_near(DamageFormula.defense_factor(0), 1.0, "def 0 -> x1")
	_near(DamageFormula.defense_factor(100), 0.5, "def 100 -> x0.5")
	_near(DamageFormula.defense_factor(-5), 1.0, "def negativa = 0")
	_near(DamageFormula.base_damage(100, 1.0, 100), 50.0, "ATK 100 x1 vs DEF 100 = 50")
	_near(DamageFormula.base_damage(40, 1.5, 0), 60.0, "multiplicador 150%")


func _test_crit_and_speed() -> void:
	_near(DamageFormula.crit_chance(0), 0.05, "crítico base 5%")
	_near(DamageFormula.crit_chance(100), 0.35, "crítico 5% + 100 x 0,3%")
	_near(DamageFormula.attacks_per_second(0), 1.0, "velocidade base 1/s")
	_near(DamageFormula.attacks_per_second(100), 2.0, "velocidade DES 100 = 2/s")
	_near(DamageFormula.attacks_per_second(500), 2.5, "velocidade máxima 2,5/s")
	_check(DamageFormula.attack_interval_msec(0) == 1000, "intervalo 1000 ms")
	_check(DamageFormula.attack_interval_msec(500) == 400, "intervalo mínimo 400 ms")


func _test_roll_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var base: float = 100.0
	var crits: int = 0
	var ok_normal: bool = true
	var ok_crit: bool = true
	var saw_low: bool = false
	var saw_high: bool = false
	for i: int in range(SAMPLES):
		var r: Dictionary = DamageFormula.roll(base, DamageFormula.crit_chance(100), rng)
		var a: int = r["amount"]
		if r["crit"]:
			crits += 1
			ok_crit = ok_crit and a >= roundi(base * 0.9 * 1.5) and a <= roundi(base * 1.1 * 1.5)
		else:
			ok_normal = ok_normal and a >= 90 and a <= 110
			saw_low = saw_low or a <= 92
			saw_high = saw_high or a >= 108
	_check(ok_normal, "variação ±10% sem crítico")
	_check(ok_crit, "crítico x1,5 dentro da variação")
	_check(saw_low and saw_high, "a variação cobre a faixa inteira")
	var freq: float = float(crits) / SAMPLES
	_check(absf(freq - 0.35) < CRIT_FREQ_TOLERANCE, "frequência de crítico ~35%", freq)
	var none: Dictionary = DamageFormula.roll(base, -1.0, rng)
	_check(not none["crit"], "sem chance = sem crítico")
	var tiny: Dictionary = DamageFormula.roll(0.1, -1.0, rng)
	_check(int(tiny["amount"]) == CombatRules.MIN_DAMAGE, "dano mínimo 1")


func _test_compute_types() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var atk: Dictionary = {&"atk": 10, &"matk": 200, &"dex": 1000, &"luk": 1000}
	var dfn: Dictionary = {&"def": 0, &"mdef": 100}
	var any_crit: bool = false
	var in_range: bool = true
	for i: int in range(200):
		var r: Dictionary = DamageFormula.compute(atk, dfn, 1.0, CombatRules.DamageType.MAGIC, rng)
		any_crit = any_crit or r["crit"]
		in_range = in_range and int(r["amount"]) >= 90 and int(r["amount"]) <= 110
	_check(not any_crit, "dano mágico nunca é crítico")
	_check(in_range, "mágico usa MATK e MDEF (200 x 0,5 = 100 ±10%)")
	var phys: Dictionary = {}
	for i: int in range(20):
		phys = DamageFormula.compute(atk, dfn, 1.0, CombatRules.DamageType.PHYSICAL, rng)
		if not phys["miss"]:
			break
	_check(not phys["miss"] and phys["crit"], "SOR 1000 = crítico garantido (chance limitada a 100%)")
	var mon: Dictionary = DamageFormula.compute({&"atk": 50}, {&"def": 0}, 1.0,
			CombatRules.DamageType.PHYSICAL, rng, 0.0)
	_check(not mon["crit"], "crit_override 0 = sem crítico")


## Agente R (GDD §6.2/§10.2, 27/09/2026): acerto/esquiva pela DES, crítico pela SOR, drop e raro.
func _test_luck_and_accuracy() -> void:
	_near(DamageFormula.hit_chance(5, 5), 0.80, "acerto base 80% (DES igual)")
	_near(DamageFormula.hit_chance(15, 5), 0.90, "acerto +1% por ponto de DES a mais")
	_near(DamageFormula.hit_chance(5, 15), 0.70, "esquiva: -1% por ponto de DES do alvo")
	_near(DamageFormula.hit_chance(500, 0), 0.95, "acerto máximo 95%")
	_near(DamageFormula.hit_chance(0, 500), 0.50, "acerto mínimo 50%")
	_near(DamageFormula.crit_chance(5), 0.065, "crítico 5% + SOR 5 × 0,3%")
	_near(DamageFormula.drop_luck_multiplier(0), 1.0, "drop sem SOR = ×1")
	_near(DamageFormula.drop_luck_multiplier(20), 1.2, "drop SOR 20 = ×1,2")
	_near(DamageFormula.rare_luck_multiplier(25), 1.5, "raro SOR 25 = ×1,5")
	_check(DamageFormula.monster_dex(-1, 10) == Balance.cfg.monster_dex_base + 10, "DES automática do monstro")
	_check(DamageFormula.monster_dex(7, 10) == 7, "DES do estágio manda")
	# Estatística: muitas rolagens físicas com DES 5 × 5 (80%) e 25 × 5 (95%); SOR 5 e 50 no crítico.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for case: Array in [[5, 5, 5, 0.80], [25, 5, 50, 0.95], [5, 40, 5, 0.50]]:
		var hits: int = 0
		var crits: int = 0
		var miss_ok: bool = true
		for i: int in range(SAMPLES):
			var r: Dictionary = DamageFormula.compute({&"atk": 50, &"dex": case[0], &"luk": case[2]},
					{&"def": 0, &"dex": case[1]}, 1.0, CombatRules.DamageType.PHYSICAL, rng)
			if r["miss"]:
				miss_ok = miss_ok and int(r["amount"]) == 0 and not r["crit"]
				continue
			hits += 1
			if r["crit"]:
				crits += 1
		_check(miss_ok, "errou = sem dano e sem crítico")
		var hit_freq: float = float(hits) / SAMPLES
		_check(absf(hit_freq - float(case[3])) < CRIT_FREQ_TOLERANCE,
				"frequência de acerto DES %d × %d ~%d%%" % [case[0], case[1], roundi(float(case[3]) * 100.0)], hit_freq)
		var crit_freq: float = float(crits) / maxf(1.0, float(hits))
		var want_crit: float = DamageFormula.crit_chance(case[2])
		_check(absf(crit_freq - want_crit) < CRIT_FREQ_TOLERANCE,
				"frequência de crítico SOR %d ~%.1f%%" % [case[2], want_crit * 100.0], crit_freq)
	var misses: int = 0
	for i: int in range(SAMPLES):
		var m: Dictionary = DamageFormula.compute({&"matk": 50, &"dex": 0}, {&"mdef": 0, &"dex": 500}, 1.0,
				CombatRules.DamageType.MAGIC, rng)
		if m["miss"] or int(m["amount"]) <= 0:
			misses += 1
	_check(misses == 0, "magia sempre acerta (mesmo contra DES 500)", misses)
	# Variante rara: atributos × 1,5 (padrão do Balance) ou o multiplicador próprio do MonsterDef.
	var brain := MonsterBrain.new()
	brain.def = MonsterDef.new()
	var st := MonsterStage.new()
	st.max_hp = 100
	st.atk = 10
	st.level = 4
	brain.stage = st
	_check(brain.max_hp() == 100 and int(brain.combat_stats()[&"atk"]) == 10, "monstro normal sem bônus")
	brain.rare = true
	_check(brain.max_hp() == roundi(100 * Balance.cfg.rare_stat_multiplier) \
			and int(brain.combat_stats()[&"atk"]) == roundi(10 * Balance.cfg.rare_stat_multiplier),
			"raro: vida e ATQ × rare_stat_multiplier", [brain.max_hp(), brain.combat_stats()])
	brain.def.rare_stat_multiplier = 2.0
	_check(brain.max_hp() == 200, "raro: multiplicador próprio do MonsterDef")
	_check(int(brain.combat_stats()[&"dex"]) == Balance.cfg.monster_dex_base + 4, "raro: DES do nível")
	brain.free()


func _test_regen() -> void:
	_near(DamageFormula.hp_regen_per_sec(5), (2.0 + 2.5) / 5.0, "regeneração de vida VIT 5")
	_near(DamageFormula.mp_regen_per_sec(5), (1.0 + 3.0) / 5.0, "regeneração de mana ESP 5")


func _stage(n: int, evolve: int, xp: int) -> MonsterStage:
	var st := MonsterStage.new()
	st.stage = n
	st.xp_reward = xp
	return st


## Sem evolução (decisão do dono, 30/09/2026): XP = a do estágio; bando do chefe do covil.
func _test_evolution() -> void:
	var def := MonsterDef.new()
	def.id = &"t"
	def.stages = [_stage(1, 0, 10), _stage(2, 0, 70), _stage(3, 0, 1400)]
	_check(MonsterEvolution.kill_xp(def.stages[1]) == 70, "recompensa = XP do estágio (médio)")
	_check(MonsterEvolution.kill_xp(def.stages[0]) == 10, "recompensa normal = XP do estágio")
	_check(MonsterEvolution.stage_by_number(def, 3).xp_reward == 1400, "estágio por número")
	var plan: Dictionary[int, int] = MonsterEvolution.escort_plan()
	_check(plan[1] == Balance.cfg.boss_escort_normals and plan[2] == Balance.cfg.boss_escort_mediums,
			"bando: 4 normais + 2 médios", plan)


func _test_bridges() -> void:
	_check(CombatBridges.curve_total_for_level(1) == 0, "XP total nível 1 = 0")
	_check(CombatBridges.curve_total_for_level(4) == 100 + 303 + 579, "XP total nível 4 = 982",
			CombatBridges.curve_total_for_level(4))
	var training := ZoneDef.new()
	training.kind = ZoneDef.Kind.TRAINING
	_check(CombatBridges.stage_cap_for_zone(training) == 2, "teto do treino = 2")
	_check(CombatBridges.stage_cap_for_zone(null) == 3, "sem zona = sem teto")
	var hunt := ZoneDef.new()
	hunt.kind = ZoneDef.Kind.HUNT
	_check(CombatBridges.stage_cap_for_zone(hunt) == 3, "caça = até chefe")


## Dados reais de W (se existirem): estágios em ordem, comportamentos conhecidos.
func _test_real_monster_data() -> void:
	var all: Dictionary = Content.all(&"monsters")
	if all.is_empty():
		print("  (sem data/monsters ainda)")
		return
	for id: Variant in all:
		var def: MonsterDef = all[id]
		# Chefe da história só existe na forma atroz: começa no estágio 3 (atributos) e não tem 1/2.
		var first: int = 3 if def.story_boss else 1
		var ok: bool = def.stages.size() >= 1 and def.stages[0].stage == first
		for i: int in range(1, def.stages.size()):
			ok = ok and def.stages[i].stage > def.stages[i - 1].stage
		_check(ok, "MonsterDef %s: estágios em ordem" % id)
		for st: MonsterStage in def.stages:
			for b: StringName in st.behaviors:
				_check(b in MonsterBehaviors.KNOWN, "comportamento conhecido %s/%s" % [id, b])


## Folclore do 1º arco: lobisomem e mortos-vivos recebem +10% de dano de armas de prata e +20% de magias de luz/sagrado.
func _test_folklore_vulnerabilities() -> void:
	var ww: MonsterDef = Content.monster(&"werewolf")
	if ww != null:
		_check(ww.is_werewolf(), "werewolf é lobisomem")
		_check(ww.is_vulnerable_to_silver(), "werewolf vulnerável a prata")
		_check(ww.is_vulnerable_to_holy(), "werewolf vulnerável a sagrado")

	var cww: MonsterDef = Content.monster(&"cave_werewolf")
	if cww != null:
		_check(cww.is_werewolf(), "cave_werewolf é lobisomem")
		_check(cww.is_vulnerable_to_silver(), "cave_werewolf vulnerável a prata")
		_check(cww.is_vulnerable_to_holy(), "cave_werewolf vulnerável a sagrado")

	var jiangshi: MonsterDef = Content.monster(&"hopping_jiangshi")
	if jiangshi != null:
		_check(jiangshi.is_undead(), "hopping_jiangshi é morto-vivo")
		_check(jiangshi.is_vulnerable_to_silver(), "hopping_jiangshi vulnerável a prata")
		_check(jiangshi.is_vulnerable_to_holy(), "hopping_jiangshi vulnerável a sagrado")

	var arma: MonsterDef = Content.monster(&"stone_armadillo")
	if arma != null:
		_check(not arma.is_werewolf(), "stone_armadillo não é lobisomem")
		_check(not arma.is_undead(), "stone_armadillo não é morto-vivo")
		_check(not arma.is_vulnerable_to_silver(), "stone_armadillo não vulnerável a prata")
		_check(not arma.is_vulnerable_to_holy(), "stone_armadillo não vulnerável a sagrado")

	# Armas e itens do 1º arco
	var s_sword: ItemDef = Content.item(&"silver_sword")
	_check(s_sword != null and s_sword.silver_effective, "silver_sword tem silver_effective")
	_check(s_sword != null and s_sword.stats.get(&"atk", 0) == 22, "silver_sword tem ATK 22")

	var s_bow: ItemDef = Content.item(&"silver_bow")
	_check(s_bow != null and s_bow.silver_effective, "silver_bow tem silver_effective")
	_check(s_bow != null and s_bow.two_handed, "silver_bow é de duas mãos")
	_check(s_bow != null and s_bow.is_projectile_weapon(), "silver_bow é arma de projétil")

	var s_arrow: ItemDef = Content.item(&"silver_arrow")
	_check(s_arrow != null and s_arrow.silver_effective, "silver_arrow tem silver_effective")
	_check(s_arrow != null and s_arrow.type == ItemDef.ItemType.OFFHAND, "silver_arrow é offhand")
	_check(s_arrow != null and s_arrow.is_ammo, "silver_arrow é munição")
	_check(s_arrow != null and s_arrow.get_equip_slot() == &"offhand", "silver_arrow equipa em offhand")
	_check(s_arrow != null and s_arrow.icon != null and s_arrow.icon != s_bow.icon, "silver_arrow tem ícone próprio diferente do arco")
	_check(s_arrow != null and s_arrow.icon.resource_path.ends_with("icon_item_silver_arrow.png"), "silver_arrow aponta para icon_item_silver_arrow.png")

	var smp_bow: ItemDef = Content.item(&"simple_bow")
	var smp_arrow: ItemDef = Content.item(&"simple_arrow")
	_check(smp_arrow != null and smp_arrow.type == ItemDef.ItemType.OFFHAND, "simple_arrow é offhand")
	_check(smp_arrow != null and smp_arrow.is_ammo, "simple_arrow é munição")
	_check(smp_arrow != null and smp_arrow.get_equip_slot() == &"offhand", "simple_arrow equipa em offhand")
	_check(smp_arrow != null and smp_arrow.icon != null and smp_arrow.icon != smp_bow.icon, "simple_arrow tem ícone próprio diferente do arco")
	_check(smp_arrow != null and smp_arrow.icon.resource_path.ends_with("icon_item_simple_arrow.png"), "simple_arrow aponta para icon_item_simple_arrow.png")

	var all_arrows: Array[StringName] = [
		&"simple_arrow", &"iron_arrow", &"silver_arrow", &"thorn_arrow",
		&"fire_arrow", &"poison_arrow", &"crystal_arrow", &"lightning_arrow"
	]
	for aid: StringName in all_arrows:
		var arr: ItemDef = Content.item(aid)
		_check(arr != null, "flecha existe: %s" % aid)
		if arr != null:
			_check(arr.is_ammo, "%s is_ammo é true" % aid)
			_check(arr.type == ItemDef.ItemType.OFFHAND, "%s type é OFFHAND" % aid)
			_check(arr.get_equip_slot() == &"offhand", "%s get_equip_slot é offhand" % aid)
			_check(arr.icon != null, "%s possui ícone" % aid)
			_check(arr.icon.resource_path.ends_with("icon_item_%s.png" % aid), "%s tem ícone exclusivo icon_item_%s.png" % [aid, aid])
			var n_tr: String = tr(arr.name_key)
			_check(n_tr != arr.name_key and not n_tr.is_empty(), "%s nome traduzido: %s" % [aid, n_tr])
			var d_tr: String = tr(arr.desc_key)
			_check(d_tr != arr.desc_key and not d_tr.is_empty(), "%s descrição traduzida" % aid)

	var s_machete: ItemDef = Content.item(&"silver_machete")
	_check(s_machete != null and s_machete.silver_effective, "silver_machete tem silver_effective")

	var s_tome: ItemDef = Content.item(&"silver_relic_tome")
	_check(s_tome != null and s_tome.silver_effective, "silver_relic_tome tem silver_effective")

	var plain_sword: ItemDef = Content.item(&"short_sword")
	_check(plain_sword != null and not plain_sword.silver_effective, "short_sword normal não é de prata")

	# Cosméticos
	for c_id: StringName in [&"silver_hunter_hat", &"silver_moon_circlet", &"silver_hunter_garb",
			&"silver_moon_cloak", &"silver_blade_cosmetic", &"silver_bow_cosmetic"]:
		var it: ItemDef = Content.item(c_id)
		_check(it != null and it.is_cosmetic, "cosmético %s registrado como is_cosmetic" % c_id)

	# Magias de luz e sagrado
	var holy: SkillDef = Content.skill(&"holy_light")
	_check(holy != null and holy.is_holy_or_light(), "holy_light é luz/sagrado")

	var star: SkillDef = Content.skill(&"arcane_star_fall")
	_check(star != null and star.is_holy_or_light(), "arcane_star_fall é luz/sagrado")

	var spark: SkillDef = Content.skill(&"arcane_spark")
	_check(spark != null and not spark.is_holy_or_light(), "arcane_spark não é luz/sagrado")

	# Multiplicadores
	_near(CombatRules.SILVER_BONUS_MULTIPLIER, 1.10, "bônus de prata = +10% (x1.10)")
	_near(CombatRules.HOLY_LIGHT_BONUS_MULTIPLIER, 1.20, "bônus de luz/sagrado = +20% (x1.20)")

	# Equipment helpers
	var eq := Equipment.new()
	_check(not eq.has_silver_weapon(), "sem arma = sem prata")
	_check(not eq.has_silver_equipped(), "sem equipamento = sem prata")
	eq.set_slot(Equipment.WEAPON, ItemStack.create(&"silver_sword", 1))
	_check(eq.has_silver_weapon(), "com silver_sword = has_silver_weapon")
	_check(eq.has_silver_equipped(), "com silver_sword = has_silver_equipped")
	eq.set_slot(Equipment.WEAPON, ItemStack.create(&"short_sword", 1))
	_check(not eq.has_silver_weapon(), "com short_sword = não has_silver_weapon")
	_check(not eq.has_silver_equipped(), "com short_sword = não has_silver_equipped")
	eq.set_slot(Equipment.OFFHAND, ItemStack.create(&"silver_arrow", 10))
	_check(not eq.has_silver_weapon(), "com flecha na mão secundária = arma não é de prata")
	_check(eq.has_silver_equipped(), "com flecha na mão secundária = has_silver_equipped")
	_check(eq.has_ammo_equipped(), "com flecha na mão secundária = has_ammo_equipped")
	_check(eq.get_ammo() != null and eq.get_ammo().qty == 10, "get_ammo retorna pilha de 10 flechas")
	_check(eq.consume_ammo(1), "consumir 1 flecha tem sucesso")
	_check(eq.get_ammo().qty == 9, "flechas restantes: 9")
	_check(eq.consume_ammo(9), "consumir 9 flechas esvazia a pilha")
	_check(not eq.has_ammo_equipped(), "sem flechas = has_ammo_equipped falso")
	_check(not eq.consume_ammo(1), "consumir sem munição falha")

	# Conflito de duas mãos com armas de projétil e munição
	var svc := ItemService.new(null)
	var session := PlayerSession.new(1, NetEntity.new(), CharacterData.new())
	var p_eq := session.character.equipment
	var p_inv := session.character.inventory
	p_eq.set_slot(Equipment.WEAPON, ItemStack.create(&"silver_bow", 1))

	# Equipando flechas em OFFHAND: não entra em conflito com arco
	var ok_ammo: bool = svc._clear_two_hand_conflict(session, Content.item(&"simple_arrow"), Equipment.OFFHAND)
	_check(ok_ammo, "flechas não entram em conflito com arco de duas mãos")
	_check(p_eq.get_slot(Equipment.WEAPON) != null, "arco permanece equipado ao checar flechas")

	# Equipando escudo em OFFHAND: entra em conflito com arco e desequipa o arco para o inventário
	var ok_shield: bool = svc._clear_two_hand_conflict(session, Content.item(&"leather_shield"), Equipment.OFFHAND)
	_check(ok_shield, "conflito resolvido desequipando arco")
	_check(p_eq.get_slot(Equipment.WEAPON) == null, "arco desequipado para colocar escudo")
	_check(p_inv.count(&"silver_bow") == 1, "arco devolvido ao inventário")

	# Inverso: tendo escudo equipado e equipando arco
	p_eq.set_slot(Equipment.OFFHAND, ItemStack.create(&"leather_shield", 1))
	var ok_bow: bool = svc._clear_two_hand_conflict(session, Content.item(&"silver_bow"), Equipment.WEAPON)
	_check(ok_bow, "conflito resolvido desequipando escudo")
	_check(p_eq.get_slot(Equipment.OFFHAND) == null, "escudo desequipado ao equipar arco")

	# Inverso: tendo flechas equipadas e equipando arco: flechas continuam!
	p_eq.set_slot(Equipment.OFFHAND, ItemStack.create(&"simple_arrow", 50))
	var ok_bow_with_arrows: bool = svc._clear_two_hand_conflict(session, Content.item(&"silver_bow"), Equipment.WEAPON)
	_check(ok_bow_with_arrows, "arco pode ser equipado com flechas em offhand")
	_check(p_eq.get_slot(Equipment.OFFHAND) != null, "flechas permanecem equipadas ao equipar arco")

	# Simulação do cálculo de dano
	var base_dmg: float = 100.0
	var dmg_silver: int = roundi(base_dmg * CombatRules.SILVER_BONUS_MULTIPLIER)
	var dmg_holy: int = roundi(base_dmg * CombatRules.HOLY_LIGHT_BONUS_MULTIPLIER)
	var dmg_both: int = roundi(base_dmg * CombatRules.SILVER_BONUS_MULTIPLIER * CombatRules.HOLY_LIGHT_BONUS_MULTIPLIER)
	_check(dmg_silver == 110, "dano com arma de prata: +10% (100 -> 110)")
	_check(dmg_holy == 120, "dano com magia de luz/sagrado: +20% (100 -> 120)")
	_check(dmg_both == 132, "dano acumulado prata + luz/sagrado: +32% (100 -> 132)")


func _test_attribute_scaling() -> void:
	# 1. Armas de projétil usam Destreza (dex)
	var eq_bow := Equipment.new()
	eq_bow.set_slot(Equipment.WEAPON, ItemStack.create(&"simple_bow", 1))
	_check(CharacterStats.atk_attribute(eq_bow) == &"dex", "simple_bow escala com DEX")

	var eq_silver_bow := Equipment.new()
	eq_silver_bow.set_slot(Equipment.WEAPON, ItemStack.create(&"silver_bow", 1))
	_check(CharacterStats.atk_attribute(eq_silver_bow) == &"dex", "silver_bow escala com DEX")

	var eq_buriti := Equipment.new()
	eq_buriti.set_slot(Equipment.WEAPON, ItemStack.create(&"buriti_recurve", 1))
	_check(CharacterStats.atk_attribute(eq_buriti) == &"dex", "buriti_recurve escala com DEX")

	# 2. Armas corpo a corpo usam Força (str)
	var eq_machete := Equipment.new()
	eq_machete.set_slot(Equipment.WEAPON, ItemStack.create(&"machete", 1))
	_check(CharacterStats.atk_attribute(eq_machete) == &"str", "machete escala com STR")

	var eq_sword := Equipment.new()
	eq_sword.set_slot(Equipment.WEAPON, ItemStack.create(&"silver_sword", 1))
	_check(CharacterStats.atk_attribute(eq_sword) == &"str", "silver_sword escala com STR")

	var eq_unarmed := Equipment.new()
	_check(CharacterStats.atk_attribute(eq_unarmed) == &"str", "desarmado sem título escala com STR")

	# 3. Armas arcanas usam Inteligência (int) por padrão
	var eq_wand := Equipment.new()
	eq_wand.set_slot(Equipment.WEAPON, ItemStack.create(&"firefly_wand", 1))
	_check(CharacterStats.atk_attribute(eq_wand) == &"int", "firefly_wand sem título sagrado escala com INT")

	# 4. Título sagrado faz ataque escalar com Sabedoria (spi)
	_check(CharacterStats.atk_attribute(eq_unarmed, &"pindorama_support_root") == &"spi", "desarmado com título sagrado escala com SPI")
	_check(CharacterStats.atk_attribute(eq_wand, &"pindorama_support_root") == &"spi", "arma arcana com título sagrado escala com SPI")
	_check(CharacterStats.atk_attribute(eq_bow, &"pindorama_support_root") == &"dex", "arco com título sagrado ainda escala com DEX")
	_check(CharacterStats.atk_attribute(eq_sword, &"pindorama_support_root") == &"str", "espada com título sagrado ainda escala com STR")

	# 5. Cálculo de estatísticas: INT aumenta max_mp e matk, SPI aumenta holy_matk mas NÃO max_mp
	var base_low: Dictionary[StringName, int] = {
		&"str": 5, &"dex": 5, &"vit": 5, &"int": 5, &"spi": 5, &"luk": 5
	}
	var base_high_int: Dictionary[StringName, int] = {
		&"str": 5, &"dex": 5, &"vit": 5, &"int": 25, &"spi": 5, &"luk": 5
	}
	var base_high_spi: Dictionary[StringName, int] = {
		&"str": 5, &"dex": 5, &"vit": 5, &"int": 5, &"spi": 25, &"luk": 5
	}
	var base_high_dex: Dictionary[StringName, int] = {
		&"str": 5, &"dex": 25, &"vit": 5, &"int": 5, &"spi": 5, &"luk": 5
	}
	var base_high_str: Dictionary[StringName, int] = {
		&"str": 25, &"dex": 5, &"vit": 5, &"int": 5, &"spi": 5, &"luk": 5
	}

	var st_low: Dictionary = CharacterStats.compute(1, base_low, eq_unarmed)
	var st_int: Dictionary = CharacterStats.compute(1, base_high_int, eq_unarmed)
	var st_spi: Dictionary = CharacterStats.compute(1, base_high_spi, eq_unarmed)
	var st_dex_bow: Dictionary = CharacterStats.compute(1, base_high_dex, eq_bow)
	var st_low_bow: Dictionary = CharacterStats.compute(1, base_low, eq_bow)
	var st_str_sword: Dictionary = CharacterStats.compute(1, base_high_str, eq_sword)
	var st_low_sword: Dictionary = CharacterStats.compute(1, base_low, eq_sword)

	# INT aumenta Max MP: +20 INT * 8 = +160 Max MP
	_check(st_int[CharacterStats.K_MAX_MP] == st_low[CharacterStats.K_MAX_MP] + 160, "INT aumenta max_mp em 8 por ponto")
	# SPI NÃO aumenta Max MP:
	_check(st_spi[CharacterStats.K_MAX_MP] == st_low[CharacterStats.K_MAX_MP], "SPI não aumenta max_mp")

	# INT aumenta MATK arcano: +20 INT * 2 = +40 MATK
	_check(st_int[CharacterStats.K_MATK] == st_low[CharacterStats.K_MATK] + 40, "INT aumenta MATK arcano")
	_check(st_int[CharacterStats.K_HOLY_MATK] == st_low[CharacterStats.K_HOLY_MATK], "INT não aumenta holy_matk")

	# SPI aumenta holy_matk: +20 SPI * 2 = +40 holy_matk
	_check(st_spi[CharacterStats.K_HOLY_MATK] == st_low[CharacterStats.K_HOLY_MATK] + 40, "SPI aumenta holy_matk")
	_check(st_spi[CharacterStats.K_MATK] == st_low[CharacterStats.K_MATK], "SPI não aumenta MATK arcano")

	# DEX aumenta ATK com arco:
	_check(st_dex_bow[CharacterStats.K_ATK] == st_low_bow[CharacterStats.K_ATK] + 40, "DEX aumenta ATK com arco (+40)")

	# STR aumenta ATK com espada:
	_check(st_str_sword[CharacterStats.K_ATK] == st_low_sword[CharacterStats.K_ATK] + 40, "STR aumenta ATK com espada (+40)")

	# SPI aumenta ATK quando título sagrado está equipado desarmado/arcano:
	var st_holy_title_low: Dictionary = CharacterStats.compute(1, base_low, eq_unarmed, &"pindorama_support_root")
	var st_holy_title_spi: Dictionary = CharacterStats.compute(1, base_high_spi, eq_unarmed, &"pindorama_support_root")
	_check(st_holy_title_spi[CharacterStats.K_ATK] == st_holy_title_low[CharacterStats.K_ATK] + 40, "SPI aumenta ATK de título sagrado (+40)")
	_check(st_holy_title_spi[CharacterStats.K_ATK_ATTR] == CharacterStats.ATTRIBUTES.find(&"spi"), "atk_attr de título sagrado é SPI")

	# 6. SkillCaster: Potência sagrada de cura, buff e debuff escalando com SPI
	var caster := SkillCaster.new(null)
	var session_low := PlayerSession.new(1, NetEntity.new(), CharacterData.new())
	session_low.character.base_attributes = base_low.duplicate()
	var session_spi := PlayerSession.new(2, NetEntity.new(), CharacterData.new())
	session_spi.character.base_attributes = base_high_spi.duplicate()

	# Wisdom factor
	_near(caster._holy_wisdom_factor(session_low), 1.0, "fator de sabedoria SPI 5 = 1.0")
	_near(caster._holy_wisdom_factor(session_spi), 1.4, "fator de sabedoria SPI 25 = 1.4 (+40%)")

	# Cura sagrada
	var sdef_heal: SkillDef = Content.skill(&"support_poultice")
	if sdef_heal != null:
		var heal_low: int = caster._heal_amount(session_low, sdef_heal, 1)
		var heal_spi: int = caster._heal_amount(session_spi, sdef_heal, 1)
		_check(heal_spi > heal_low, "cura sagrada aumenta com Sabedoria (SPI)")

	# 7. Dano mágico: magia sagrada com SPI alto vs magia arcana com INT baixo
	var dfn_zero: Dictionary = {&"mdef": 0, &"dex": 5}
	var rng_fixed := RandomNumberGenerator.new()
	rng_fixed.seed = 100
	var roll_normal: Dictionary = DamageFormula.compute(st_spi, dfn_zero, 1.0, CombatRules.DamageType.MAGIC, rng_fixed)
	var st_holy_active: Dictionary = st_spi.duplicate()
	st_holy_active[&"matk"] = st_holy_active[CharacterStats.K_HOLY_MATK]
	rng_fixed.seed = 100
	var roll_holy: Dictionary = DamageFormula.compute(st_holy_active, dfn_zero, 1.0, CombatRules.DamageType.MAGIC, rng_fixed)
	_check(roll_holy["amount"] > roll_normal["amount"], "holy_matk aumenta poder de magias sagradas para personagens sábios (SPI)")


