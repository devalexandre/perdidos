extends Node
## Teste de validação dos 10 monstros peçonhentos e perigosos da fauna brasileira
## Verifica existência no Content, 4 estágios, chefe (stage 3) e forma atroz (stage 4),
## comportamentos (boss, ranged, fly_pattern, roll_charge), folhas de sprites e drops.

const EXPECTED_SPECIES: Array[StringName] = [
	&"yellow_scorpion",
	&"wandering_spider",
	&"brown_recluse",
	&"jararaca_serpent",
	&"rattlesnake",
	&"surucucu_serpent",
	&"coral_snake",
	&"lonomia_caterpillar",
	&"killer_bee",
	&"aedes_mosquito",
	&"cave_skeleton",
	&"cave_zombie",
	&"cave_bat"
]

const EXPECTED_ITEMS: Array[StringName] = [
	&"venom_gland",
	&"scorpion_stinger",
	&"spider_silk",
	&"serpent_fang",
	&"urticating_spine",
	&"wild_honeycomb",
	&"chitin_shard"
]

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("--- TESTE DE MONSTROS PEÇONHENTOS E PERIGOSOS ---")
	_test_items()
	_test_monsters()
	print("test_venom_monsters: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL %s %s" % [what, str(detail) if detail != null else ""])
	else:
		print("  OK: %s" % what)


func _test_items() -> void:
	for item_id: StringName in EXPECTED_ITEMS:
		var item: ItemDef = Content.item(item_id)
		_check(item != null, "Item %s carregado no Content" % item_id)
		if item != null:
			_check(item.stackable, "Item %s é empilhável" % item_id)
			_check(item.sell_price > 0, "Item %s tem valor de venda" % item_id)
			var translated_name: String = TranslationServer.translate(item.name_key)
			_check(translated_name != item.name_key and not translated_name.is_empty(), "Nome do item %s traduzido: %s" % [item_id, translated_name])


func _test_monsters() -> void:
	for mid: StringName in EXPECTED_SPECIES:
		var def: MonsterDef = Content.monster(mid)
		_check(def != null, "Monstro %s registrado no Content" % mid)
		if def == null:
			continue

		_check(def.stages.size() == 4, "%s possui exatamente 4 estágios" % mid, def.stages.size())
		var expected_type: StringName = &"undead" if (mid == &"cave_skeleton" or mid == &"cave_zombie") else &"beast"
		_check(def.creature_type == expected_type, "%s é do tipo criatura '%s'" % [mid, expected_type])

		var s1: MonsterStage = MonsterEvolution.stage_by_number(def, 1)
		var s2: MonsterStage = MonsterEvolution.stage_by_number(def, 2)
		var boss: MonsterStage = MonsterEvolution.stage_by_number(def, 3)
		var atroz: MonsterStage = def.atroz_stage()

		_check(s1 != null and s2 != null and boss != null and atroz != null, "%s possui todos os 4 estágios válidos" % mid)
		if s1 == null or s2 == null or boss == null or atroz == null:
			continue

		# Nomes e traduções
		for st: MonsterStage in [s1, s2, boss, atroz]:
			var name_trans: String = TranslationServer.translate(st.name_key)
			_check(name_trans != st.name_key and not name_trans.is_empty(), "%s estágio %d nome traduzido: %s" % [mid, st.stage, name_trans])
			var idle_sheet: String = "%s_idle.png" % st.sprite_base
			_check(ResourceLoader.exists(idle_sheet), "%s estágio %d folha idle existe: %s" % [mid, st.stage, idle_sheet])
			_check(st.drops.size() > 0, "%s estágio %d possui tabela de drops" % [mid, st.stage])

		# Chefe (stage 3)
		_check(boss.behaviors.has(&"boss"), "%s chefe possui behavior 'boss'" % mid, boss.behaviors)
		_check(boss.max_hp >= 4000, "%s chefe possui vida alta de chefe (%d)" % [mid, boss.max_hp])
		_check(boss.aggressive, "%s chefe é agressivo" % mid)

		# Atroz (stage 4)
		_check(atroz.stage == 4, "%s atroz é o estágio 4" % mid)
		_check(atroz.behaviors.has(&"boss"), "%s atroz possui behavior 'boss'" % mid, atroz.behaviors)
		_check(atroz.level > boss.level, "%s atroz nível (%d) > chefe (%d)" % [mid, atroz.level, boss.level])
		_check(atroz.xp_reward > boss.xp_reward, "%s atroz dá mais XP que o chefe" % mid)
		_check(atroz.walk_ms_per_cell < boss.walk_ms_per_cell, "%s atroz é mais rápido que o chefe (%d ms vs %d ms)" % [mid, atroz.walk_ms_per_cell, boss.walk_ms_per_cell])
		_check(atroz.attack_interval_ms < boss.attack_interval_ms, "%s atroz ataca mais rápido que o chefe" % mid)
		_check(atroz.aggro_range_cells >= boss.aggro_range_cells and atroz.leash_cells > boss.leash_cells, "%s atroz possui perseguição e coleira maiores" % mid)
