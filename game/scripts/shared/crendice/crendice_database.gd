class_name CrendiceDatabase
extends RefCounted
## Base de dados de Amuletos de Crendice e Sinergias Folclóricas.
## Centraliza todas as definições temáticas, regras de drop por superstição e conjuntos.

static var _cache: Dictionary[StringName, CrendiceDef] = {}
static var _synergies: Dictionary[StringName, Dictionary] = {}

static func all() -> Dictionary[StringName, CrendiceDef]:
	if _cache.is_empty():
		_init_database()
	return _cache


static func get_crendice(id: StringName) -> CrendiceDef:
	if _cache.is_empty():
		_init_database()
	return _cache.get(id)


static func get_synergies() -> Dictionary[StringName, Dictionary]:
	if _synergies.is_empty():
		_init_synergies()
	return _synergies


static func _init_database() -> void:
	_cache.clear()

	# 1. Figa de Madeira
	var figa := CrendiceDef.new()
	figa.id = &"figa_de_madeira"
	figa.name_key = "CRENDICE_FIGA_NAME"
	figa.desc_key = "CRENDICE_FIGA_DESC"
	figa.lore_key = "CRENDICE_FIGA_LORE"
	figa.superstition_desc_key = "CRENDICE_FIGA_SUP"
	figa.valid_slots = [&"accessory_1", &"accessory_2", &"body", &"accessory"]
	figa.stats = {&"mdef": 8}
	figa.special_effects = {
		"shadow_resist_pct": 15,
		"curse_resist_pct": 15,
		"double_if_low_hp": true
	}
	figa.superstition_rule = &"low_hp_double"
	figa.drop_rules = {
		"monster_ids": [&"cave_skeleton", &"cave_zombie"],
		"chance": 0.035,
		"killer_low_hp": true
	}
	figa.synergy_group = &"protecao_total"
	_cache[figa.id] = figa

	# 2. Guia de Arruda e Espada de São Jorge
	var arruda := CrendiceDef.new()
	arruda.id = &"guia_de_arruda"
	arruda.name_key = "CRENDICE_ARRUDA_NAME"
	arruda.desc_key = "CRENDICE_ARRUDA_DESC"
	arruda.lore_key = "CRENDICE_ARRUDA_LORE"
	arruda.superstition_desc_key = "CRENDICE_ARRUDA_SUP"
	arruda.valid_slots = [&"body", &"accessory_1", &"accessory_2", &"accessory"]
	arruda.stats = {&"vit": 3}
	arruda.special_effects = {
		"poison_immunity": true,
		"hp_regen_idle_pct": 10
	}
	arruda.superstition_rule = &"no_water_or_poison"
	arruda.drop_rules = {
		"monster_ids": [&"jararaca_serpent", &"brown_recluse", &"coral_snake"],
		"chance": 0.03,
		"no_poison_kill": true
	}
	arruda.synergy_group = &"protecao_total"
	_cache[arruda.id] = arruda

	# 3. Dente de Onça-Pintada
	var onca := CrendiceDef.new()
	onca.id = &"dente_de_onca"
	onca.name_key = "CRENDICE_ONCA_NAME"
	onca.desc_key = "CRENDICE_ONCA_DESC"
	onca.lore_key = "CRENDICE_ONCA_LORE"
	onca.superstition_desc_key = "CRENDICE_ONCA_SUP"
	onca.valid_slots = [&"weapon"]
	onca.stats = {&"str": 3}
	onca.special_effects = {
		"crit_chance_pct": 8,
		"phys_dmg_pct": 5,
		"ignore_def_pct": 10
	}
	onca.superstition_rule = &"night_or_forest"
	onca.drop_rules = {
		"monster_ids": [&"sabia_jaguar", &"jaguar_cub"],
		"chance": 0.025,
		"night_or_forest": true
	}
	onca.synergy_group = &"espirito_da_caca"
	_cache[onca.id] = onca

	# 4. Pata de Quati da Sorte
	var quati := CrendiceDef.new()
	quati.id = &"pata_de_quati"
	quati.name_key = "CRENDICE_QUATI_NAME"
	quati.desc_key = "CRENDICE_QUATI_DESC"
	quati.lore_key = "CRENDICE_QUATI_LORE"
	quati.superstition_desc_key = "CRENDICE_QUATI_SUP"
	quati.valid_slots = [&"feet"]
	quati.stats = {&"luk": 5}
	quati.special_effects = {
		"drop_rate_pct": 15,
		"dormant_on_death": true
	}
	quati.superstition_rule = &"lucky_paw_death"
	quati.drop_rules = {
		"monster_ids": [&"buriti_boar", &"pequi_seedling", &"stone_armadillo"],
		"chance": 0.04,
		"day_or_crit": true
	}
	quati.synergy_group = &"espirito_da_caca"
	_cache[quati.id] = quati

	# 5. Moeda Furada de Réis
	var moeda := CrendiceDef.new()
	moeda.id = &"moeda_furada"
	moeda.name_key = "CRENDICE_MOEDA_NAME"
	moeda.desc_key = "CRENDICE_MOEDA_DESC"
	moeda.lore_key = "CRENDICE_MOEDA_LORE"
	moeda.superstition_desc_key = "CRENDICE_MOEDA_SUP"
	moeda.valid_slots = [&"accessory_1", &"accessory_2", &"accessory"]
	moeda.stats = {&"dex": 3}
	moeda.special_effects = {
		"flee_pct": 10,
		"first_strike_flee": true
	}
	moeda.superstition_rule = &"enemy_first_strike"
	moeda.drop_rules = {
		"monster_ids": [&"cave_zombie", &"moss_troll", &"trasgo_imp"],
		"chance": 0.03,
		"enemy_struck_first": true
	}
	moeda.synergy_group = &"protecao_total"
	_cache[moeda.id] = moeda

	# 6. Saquinho de Sal Grosso
	var sal := CrendiceDef.new()
	sal.id = &"saquinho_sal_grosso"
	sal.name_key = "CRENDICE_SAL_NAME"
	sal.desc_key = "CRENDICE_SAL_DESC"
	sal.lore_key = "CRENDICE_SAL_LORE"
	sal.superstition_desc_key = "CRENDICE_SAL_SUP"
	sal.valid_slots = [&"body"]
	sal.stats = {&"def": 12}
	sal.special_effects = {
		"slow_immunity": true
	}
	sal.superstition_rule = &"no_curse"
	sal.drop_rules = {
		"monster_ids": [&"cave_zombie", &"cave_skeleton"],
		"chance": 0.035,
		"killer_high_hp": true
	}
	sal.synergy_group = &"protecao_total"
	_cache[sal.id] = sal

	# 7. Dente de Cascavel
	var cascavel := CrendiceDef.new()
	cascavel.id = &"dente_de_cascavel"
	cascavel.name_key = "CRENDICE_CASCAVEL_NAME"
	cascavel.desc_key = "CRENDICE_CASCAVEL_DESC"
	cascavel.lore_key = "CRENDICE_CASCAVEL_LORE"
	cascavel.superstition_desc_key = "CRENDICE_CASCAVEL_SUP"
	cascavel.valid_slots = [&"weapon"]
	cascavel.stats = {&"dex": 2}
	cascavel.special_effects = {
		"poison_chance_pct": 12,
		"poison_double_if_target_high_hp": true
	}
	cascavel.superstition_rule = &"ambush_strike"
	cascavel.drop_rules = {
		"monster_ids": [&"rattlesnake"],
		"chance": 0.035
	}
	cascavel.synergy_group = &"espirito_da_caca"
	_cache[cascavel.id] = cascavel

	# 8. Lasca de Cristal de Ratanabá
	var ratanaba := CrendiceDef.new()
	ratanaba.id = &"lasca_cristal_ratanaba"
	ratanaba.name_key = "CRENDICE_RATANABA_NAME"
	ratanaba.desc_key = "CRENDICE_RATANABA_DESC"
	ratanaba.lore_key = "CRENDICE_RATANABA_LORE"
	ratanaba.superstition_desc_key = "CRENDICE_RATANABA_SUP"
	ratanaba.valid_slots = [&"weapon", &"offhand"]
	ratanaba.stats = {&"int": 3, &"matk": 10}
	ratanaba.special_effects = {
		"magic_dmg_pct": 10,
		"damage_to_shield_pct": 5
	}
	ratanaba.superstition_rule = &"mana_above_40"
	ratanaba.drop_rules = {
		"monster_ids": [&"ratanaba_sentinel", &"crystal_serpent", &"stone_armadillo", &"highland_stone_armadillo", &"obsidian_iguana"],
		"chance": 0.05
	}
	ratanaba.synergy_group = &"ancestralidade_mistica"
	_cache[ratanaba.id] = ratanaba

	# 9. Pedra de Raio (Fulgurito)
	var raio := CrendiceDef.new()
	raio.id = &"pedra_de_raio"
	raio.name_key = "CRENDICE_RAIO_NAME"
	raio.desc_key = "CRENDICE_RAIO_DESC"
	raio.lore_key = "CRENDICE_RAIO_LORE"
	raio.superstition_desc_key = "CRENDICE_RAIO_SUP"
	raio.valid_slots = [&"accessory_1", &"accessory_2", &"accessory"]
	raio.stats = {&"dex": 2, &"matk": 6}
	raio.special_effects = {
		"thunder_dmg_pct": 12,
		"thunder_boost_in_rain": 25
	}
	raio.superstition_rule = &"weather_rain"
	raio.drop_rules = {
		"monster_ids": [&"ember_mule", &"highland_ember_mule", &"prank_whirlwind"],
		"chance": 0.025,
		"rain_only": true
	}
	raio.synergy_group = &"ancestralidade_mistica"
	_cache[raio.id] = raio

	# 10. Cuia de Água de Cachoeira
	var cuia := CrendiceDef.new()
	cuia.id = &"cuia_agua_cachoeira"
	cuia.name_key = "CRENDICE_CUIA_NAME"
	cuia.desc_key = "CRENDICE_CUIA_DESC"
	cuia.lore_key = "CRENDICE_CUIA_LORE"
	cuia.superstition_desc_key = "CRENDICE_CUIA_SUP"
	cuia.valid_slots = [&"accessory_1", &"accessory_2", &"accessory"]
	cuia.stats = {&"spi": 4}
	cuia.special_effects = {
		"potion_efficiency_pct": 15,
		"mp_regen_calm": 10
	}
	cuia.superstition_rule = &"out_of_combat_5s"
	cuia.drop_rules = {
		"monster_ids": [&"fountain_serpent", &"lake_kelpie"],
		"chance": 0.03
	}
	cuia.synergy_group = &"ancestralidade_mistica"
	_cache[cuia.id] = cuia

	# 11. Casca do Escorpião-Amarelo Atroz
	var esc_atroz := CrendiceDef.new()
	esc_atroz.id = &"casca_escorpiao_atroz"
	esc_atroz.name_key = "CRENDICE_ESCORPIAO_ATROZ_NAME"
	esc_atroz.desc_key = "CRENDICE_ESCORPIAO_ATROZ_DESC"
	esc_atroz.lore_key = "CRENDICE_ESCORPIAO_ATROZ_LORE"
	esc_atroz.superstition_desc_key = "CRENDICE_ESCORPIAO_ATROZ_SUP"
	esc_atroz.valid_slots = [&"offhand", &"body"]
	esc_atroz.stats = {&"def": 14}
	esc_atroz.special_effects = {
		"reflect_poison_pct": 15
	}
	esc_atroz.superstition_rule = &"hp_above_50"
	esc_atroz.drop_rules = {
		"monster_ids": [&"yellow_scorpion", &"dune_scorpion"],
		"chance": 0.08,
		"atroz_only": true,
		"night_only": true
	}
	esc_atroz.synergy_group = &"plenilunio"
	_cache[esc_atroz.id] = esc_atroz

	# 12. Presa de Lobisomem Noturno
	var lobo := CrendiceDef.new()
	lobo.id = &"presa_lobisomem_noturno"
	lobo.name_key = "CRENDICE_LOBISOMEM_NAME"
	lobo.desc_key = "CRENDICE_LOBISOMEM_DESC"
	lobo.lore_key = "CRENDICE_LOBISOMEM_LORE"
	lobo.superstition_desc_key = "CRENDICE_LOBISOMEM_SUP"
	lobo.valid_slots = [&"weapon", &"accessory_1", &"accessory_2", &"accessory"]
	lobo.stats = {&"str": 4, &"atk": 8}
	lobo.special_effects = {
		"phys_dmg_pct": 10,
		"life_steal_pct": 8
	}
	lobo.superstition_rule = &"night_only"
	lobo.drop_rules = {
		"monster_ids": [&"werewolf", &"cave_werewolf"],
		"chance": 0.05,
		"night_only": true
	}
	lobo.synergy_group = &"plenilunio"
	_cache[lobo.id] = lobo

	# 13. Teia da Armadeira Rainha
	var teia := CrendiceDef.new()
	teia.id = &"teia_armadeira_rainha"
	teia.name_key = "CRENDICE_ARMADEIRA_NAME"
	teia.desc_key = "CRENDICE_ARMADEIRA_DESC"
	teia.lore_key = "CRENDICE_ARMADEIRA_LORE"
	teia.superstition_desc_key = "CRENDICE_ARMADEIRA_SUP"
	teia.valid_slots = [&"weapon", &"accessory_1", &"accessory_2", &"accessory"]
	teia.stats = {&"dex": 3}
	teia.special_effects = {
		"slow_on_hit_pct": 25
	}
	teia.superstition_rule = &"no_consecutive_miss"
	teia.drop_rules = {
		"monster_ids": [&"wandering_spider"],
		"chance": 0.06,
		"atroz_or_boss": true
	}
	teia.synergy_group = &"espirito_da_caca"
	_cache[teia.id] = teia

	# 14. Veneno Cristalizado da Surucucu
	var surucucu := CrendiceDef.new()
	surucucu.id = &"veneno_surucucu_chuva"
	surucucu.name_key = "CRENDICE_SURUCUCU_NAME"
	surucucu.desc_key = "CRENDICE_SURUCUCU_DESC"
	surucucu.lore_key = "CRENDICE_SURUCUCU_LORE"
	surucucu.superstition_desc_key = "CRENDICE_SURUCUCU_SUP"
	surucucu.valid_slots = [&"weapon"]
	surucucu.stats = {&"atk": 6}
	surucucu.special_effects = {
		"poison_spread_area": true,
		"poison_chance_pct": 15
	}
	surucucu.superstition_rule = &"weather_rain"
	surucucu.drop_rules = {
		"monster_ids": [&"surucucu_serpent"],
		"chance": 0.04,
		"rain_only": true
	}
	surucucu.synergy_group = &"espirito_da_caca"
	_cache[surucucu.id] = surucucu

	# 15. Cera de Abelha Mandaçaia
	var cera := CrendiceDef.new()
	cera.id = &"cera_abelha_mandacaia"
	cera.name_key = "CRENDICE_ABELHA_NAME"
	cera.desc_key = "CRENDICE_ABELHA_DESC"
	cera.lore_key = "CRENDICE_ABELHA_LORE"
	cera.superstition_desc_key = "CRENDICE_ABELHA_SUP"
	cera.valid_slots = [&"body", &"head"]
	cera.stats = {&"def": 8, &"mdef": 6}
	cera.special_effects = {
		"shield_after_crit_taken": 150
	}
	cera.superstition_rule = &"recharge_out_of_combat"
	cera.drop_rules = {
		"monster_ids": [&"killer_bee"],
		"chance": 0.035
	}
	cera.synergy_group = &"protecao_total"
	_cache[cera.id] = cera

	# 16. Casulo de Lonomia Urticante
	var lonomia := CrendiceDef.new()
	lonomia.id = &"casulo_lonomia_urticante"
	lonomia.name_key = "CRENDICE_LONOMIA_NAME"
	lonomia.desc_key = "CRENDICE_LONOMIA_DESC"
	lonomia.lore_key = "CRENDICE_LONOMIA_LORE"
	lonomia.superstition_desc_key = "CRENDICE_LONOMIA_SUP"
	lonomia.valid_slots = [&"body"]
	lonomia.stats = {&"def": 10}
	lonomia.special_effects = {
		"thorns_bleed_pct": 10
	}
	lonomia.superstition_rule = &"no_shield_equipped"
	lonomia.drop_rules = {
		"monster_ids": [&"lonomia_caterpillar"],
		"chance": 0.035
	}
	lonomia.synergy_group = &"espirito_da_caca"
	_cache[lonomia.id] = lonomia

	# 17. Coração de Obsidiana do Arquiteto (Boss Lendário)
	var arquiteto := CrendiceDef.new()
	arquiteto.id = &"coracao_obsidiana_arquiteto"
	arquiteto.name_key = "CRENDICE_ARQUITETO_NAME"
	arquiteto.desc_key = "CRENDICE_ARQUITETO_DESC"
	arquiteto.lore_key = "CRENDICE_ARQUITETO_LORE"
	arquiteto.superstition_desc_key = "CRENDICE_ARQUITETO_SUP"
	arquiteto.valid_slots = [&"body"]
	arquiteto.stats = {&"def": 25, &"mdef": 20}
	arquiteto.special_effects = {
		"petrify_immunity": true,
		"aoe_defense_pct": 15
	}
	arquiteto.superstition_rule = &"moving_state"
	arquiteto.drop_rules = {
		"monster_ids": [&"ratanaba_architect", &"trial_twin_shield_puppet", &"moss_troll"],
		"chance": 0.25,
		"boss_only": true
	}
	arquiteto.synergy_group = &"ancestralidade_mistica"
	_cache[arquiteto.id] = arquiteto

	# 18. Máscara Ritual de Kuarahy (Boss Lendário)
	var kuarahy := CrendiceDef.new()
	kuarahy.id = &"mascara_ritual_kuarahy"
	kuarahy.name_key = "CRENDICE_KUARAHY_NAME"
	kuarahy.desc_key = "CRENDICE_KUARAHY_DESC"
	kuarahy.lore_key = "CRENDICE_KUARAHY_LORE"
	kuarahy.superstition_desc_key = "CRENDICE_KUARAHY_SUP"
	kuarahy.valid_slots = [&"head"]
	kuarahy.stats = {&"str": 5, &"int": 5, &"matk": 15}
	kuarahy.special_effects = {
		"life_steal_pct": 15
	}
	kuarahy.superstition_rule = &"day_only"
	kuarahy.drop_rules = {
		"monster_ids": [&"trial_twin_shield_puppet"],
		"chance": 0.01,
		"boss_only": true
	}
	kuarahy.synergy_group = &"ancestralidade_mistica"
	_cache[kuarahy.id] = kuarahy

	# 19. Lenço do Pregoeiro do Silêncio (Boss Lendário)
	var pregoeiro := CrendiceDef.new()
	pregoeiro.id = &"lenco_do_pregoeiro"
	pregoeiro.name_key = "CRENDICE_PREGOEIRO_NAME"
	pregoeiro.desc_key = "CRENDICE_PREGOEIRO_DESC"
	pregoeiro.lore_key = "CRENDICE_PREGOEIRO_LORE"
	pregoeiro.superstition_desc_key = "CRENDICE_PREGOEIRO_SUP"
	pregoeiro.valid_slots = [&"head", &"accessory_1", &"accessory_2", &"accessory"]
	pregoeiro.stats = {&"spi": 6, &"mdef": 18}
	pregoeiro.special_effects = {
		"silence_immunity": true,
		"stun_immunity": true
	}
	pregoeiro.superstition_rule = &"mana_above_20"
	pregoeiro.drop_rules = {
		"monster_ids": [&"cave_werewolf", &"werewolf"],
		"chance": 0.01,
		"boss_only": true
	}
	pregoeiro.synergy_group = &"protecao_total"
	_cache[pregoeiro.id] = pregoeiro

	# 20. Olho do Titã das Profundezas (Boss Lendário)
	var tita := CrendiceDef.new()
	tita.id = &"olho_do_tita"
	tita.name_key = "CRENDICE_TITA_NAME"
	tita.desc_key = "CRENDICE_TITA_DESC"
	tita.lore_key = "CRENDICE_TITA_LORE"
	tita.superstition_desc_key = "CRENDICE_TITA_SUP"
	tita.valid_slots = [&"offhand"]
	tita.stats = {&"def": 20, &"vit": 5}
	tita.special_effects = {
		"emergency_shield_pct": 30
	}
	tita.superstition_rule = &"still_position"
	tita.drop_rules = {
		"monster_ids": [&"stone_armadillo", &"highland_stone_armadillo"],
		"chance": 0.01,
		"boss_only": true
	}
	tita.synergy_group = &"ancestralidade_mistica"
	_cache[tita.id] = tita

	# 21. Figa de Obsidiana de Ratanabá
	var figa_obs := CrendiceDef.new()
	figa_obs.id = &"figa_de_obsidiana"
	figa_obs.name_key = "CRENDICE_FIGA_OBSIDIANA_NAME"
	figa_obs.desc_key = "CRENDICE_FIGA_OBSIDIANA_DESC"
	figa_obs.lore_key = "CRENDICE_FIGA_OBSIDIANA_LORE"
	figa_obs.superstition_desc_key = "CRENDICE_FIGA_OBSIDIANA_SUP"
	figa_obs.valid_slots = [&"body", &"accessory_1", &"accessory_2", &"accessory"]
	figa_obs.stats = {&"def": 18, &"mdef": 14}
	figa_obs.special_effects = {
		"crowd_defense_pct": 20
	}
	figa_obs.superstition_rule = &"multiple_attackers"
	figa_obs.drop_rules = {
		"monster_ids": [&"ratanaba_sentinel"],
		"chance": 0.04
	}
	figa_obs.synergy_group = &"ancestralidade_mistica"
	_cache[figa_obs.id] = figa_obs

	# 22. Prisma da Serpente Cristalina
	var prisma := CrendiceDef.new()
	prisma.id = &"prisma_da_serpente"
	prisma.name_key = "CRENDICE_PRISMA_SERPENTE_NAME"
	prisma.desc_key = "CRENDICE_PRISMA_SERPENTE_DESC"
	prisma.lore_key = "CRENDICE_PRISMA_SERPENTE_LORE"
	prisma.superstition_desc_key = "CRENDICE_PRISMA_SERPENTE_SUP"
	prisma.valid_slots = [&"offhand", &"accessory_1", &"accessory_2", &"accessory"]
	prisma.stats = {&"mdef": 16, &"matk": 8}
	prisma.special_effects = {
		"reflect_magic_pct": 15
	}
	prisma.superstition_rule = &"facing_attacker"
	prisma.drop_rules = {
		"monster_ids": [&"crystal_serpent"],
		"chance": 0.04
	}
	prisma.synergy_group = &"ancestralidade_mistica"
	_cache[prisma.id] = prisma


	# 23. Teia da Matriarca Golias (Boss Aranha)
	var teia_golias := CrendiceDef.new()
	teia_golias.id = &"teia_matriarca_golias"
	teia_golias.name_key = "CRENDICE_TEIA_MATRIARCA_NAME"
	teia_golias.desc_key = "CRENDICE_TEIA_MATRIARCA_DESC"
	teia_golias.lore_key = "CRENDICE_TEIA_MATRIARCA_LORE"
	teia_golias.superstition_desc_key = "CRENDICE_TEIA_MATRIARCA_SUP"
	teia_golias.valid_slots = [&"offhand", &"accessory_1", &"accessory_2", &"accessory"]
	teia_golias.stats = {&"flee": 15, &"def": 8}
	teia_golias.special_effects = {
		"immune_slow": true,
		"evasion_pct": 15,
		"ambush_bonus": true
	}
	teia_golias.superstition_rule = &"standing_still_double"
	teia_golias.drop_rules = {
		"monster_ids": [&"spider_goliath"],
		"chance": 0.08,
		"boss_only": true
	}
	teia_golias.synergy_group = &"espirito_da_caca"
	_cache[teia_golias.id] = teia_golias

	# 24. Olho da Cobra-Grande (Boss Serpente)
	var olho_cobra := CrendiceDef.new()
	olho_cobra.id = &"olho_cobra_grande"
	olho_cobra.name_key = "CRENDICE_OLHO_COBRA_GRANDE_NAME"
	olho_cobra.desc_key = "CRENDICE_OLHO_COBRA_GRANDE_DESC"
	olho_cobra.lore_key = "CRENDICE_OLHO_COBRA_GRANDE_LORE"
	olho_cobra.superstition_desc_key = "CRENDICE_OLHO_COBRA_GRANDE_SUP"
	olho_cobra.valid_slots = [&"head", &"accessory_1", &"accessory_2", &"accessory"]
	olho_cobra.stats = {&"atk": 16, &"matk": 12}
	olho_cobra.special_effects = {
		"night_vision": true,
		"phys_dmg_pct": 12,
		"water_combat_bonus": true
	}
	olho_cobra.superstition_rule = &"water_or_rain_active"
	olho_cobra.drop_rules = {
		"monster_ids": [&"river_anaconda"],
		"chance": 0.08,
		"boss_only": true
	}
	olho_cobra.synergy_group = &"ancestralidade_mistica"
	_cache[olho_cobra.id] = olho_cobra

	_init_synergies()


static func _init_synergies() -> void:
	_synergies.clear()

	_synergies[&"protecao_total"] = {
		"name_key": "SYNERGY_PROTECAO_TOTAL_NAME",
		"desc_key": "SYNERGY_PROTECAO_TOTAL_DESC",
		"required_count": 3,
		"crendices": [&"figa_de_madeira", &"guia_de_arruda", &"saquinho_sal_grosso", &"moeda_furada", &"cera_abelha_mandacaia", &"lenco_do_pregoeiro"],
		"bonuses": {
			"all_def_pct": 15,
			"curse_resist_pct": 30,
			"debuff_duration_reduction_pct": 50
		}
	}

	_synergies[&"espirito_da_caca"] = {
		"name_key": "SYNERGY_ESPIRITO_CACA_NAME",
		"desc_key": "SYNERGY_ESPIRITO_CACA_DESC",
		"required_count": 3,
		"crendices": [&"dente_de_onca", &"pata_de_quati", &"dente_de_cascavel", &"teia_armadeira_rainha", &"veneno_surucucu_chuva", &"casulo_lonomia_urticante", &"teia_matriarca_golias"],
		"bonuses": {
			"crit_damage_pct": 10,
			"drop_rate_pct": 10,
			"phys_dmg_pct": 5
		}
	}

	_synergies[&"ancestralidade_mistica"] = {
		"name_key": "SYNERGY_MISTICA_NAME",
		"desc_key": "SYNERGY_MISTICA_DESC",
		"required_count": 3,
		"crendices": [&"lasca_cristal_ratanaba", &"pedra_de_raio", &"cuia_agua_cachoeira", &"coracao_obsidiana_arquiteto", &"mascara_ritual_kuarahy", &"olho_do_tita", &"figa_de_obsidiana", &"prisma_da_serpente", &"olho_cobra_grande"],
		"bonuses": {
			"magic_dmg_pct": 15,
			"mp_on_hit": 5,
			"mp_regen_pct": 20
		}
	}

	_synergies[&"plenilunio"] = {
		"name_key": "SYNERGY_PLENILUNIO_NAME",
		"desc_key": "SYNERGY_PLENILUNIO_DESC",
		"required_count": 2,
		"crendices": [&"presa_lobisomem_noturno", &"casca_escorpiao_atroz"],
		"bonuses": {
			"life_steal_pct": 10,
			"night_move_speed_pct": 10
		}
	}
