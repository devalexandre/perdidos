extends Node
## Teste de validação das espécies nativas da fauna e flora brasileira para a Nação Sabiá
## Inclui a Caranguejeira-Golias (Boss Aranha), a Sucuri/Cobra-Grande (Boss Serpente),
## Tamanduá-Bandeira, Lobo-Guará, Jacaré-Açu, Harpia-Real, Cipó-Matador e Mandacaru.

const FAUNA_FLORA_SPECIES: Array[StringName] = [
	&"spider_goliath",
	&"river_anaconda",
	&"giant_anteater",
	&"maned_wolf",
	&"black_caiman",
	&"harpy_eagle",
	&"strangler_vine",
	&"mandacaru_guardian"
]

const FAUNA_FLORA_ITEMS: Array[StringName] = [
	&"tarantula_bristle",
	&"anaconda_scale",
	&"anteater_claw",
	&"guara_pelt",
	&"caiman_plate",
	&"harpy_feather",
	&"strangler_root",
	&"mandacaru_thorn"
]

const BOSS_CRENDICES: Array[StringName] = [
	&"teia_matriarca_golias",
	&"olho_cobra_grande"
]

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("--- TESTE DA FAUNA E FLORA BRASILEIRA (NAÇÃO SABIÁ) ---")
	_test_items()
	_test_monsters()
	_test_boss_crendices()
	print("test_brazilian_fauna_flora: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL: %s %s" % [what, str(detail) if detail != null else ""])
	else:
		print("  PASS: %s" % what)


func _test_items() -> void:
	print("\n-- Test Materiais Nativos --")
	for item_id: StringName in FAUNA_FLORA_ITEMS:
		var item: ItemDef = Content.item(item_id)
		_check(item != null, "Item %s carregado no Content" % item_id)
		if item != null:
			_check(item.stackable, "Item %s é empilhável" % item_id)
			_check(item.sell_price > 0, "Item %s tem valor de venda" % item_id)


func _test_monsters() -> void:
	print("\n-- Test Monstros da Fauna e Flora (4 Estágios) --")
	for mid: StringName in FAUNA_FLORA_SPECIES:
		var mon: MonsterDef = Content.monster(mid)
		_check(mon != null, "MonsterDef '%s' existe no Content" % mid)
		if mon == null:
			continue

		_check(mon.stages.size() == 4, "%s possui exatamente 4 estágios" % mid)

		for st: int in range(1, 5):
			var stage: MonsterStage = mon.stages[st - 1]
			_check(stage != null, "%s estágio %d existe" % [mid, st])
			if stage == null:
				continue

			_check(stage.level >= 10, "%s s%d nível compatível (%d)" % [mid, st, stage.level])
			_check(stage.max_hp > 200, "%s s%d HP válido (%d)" % [mid, st, stage.max_hp])
			_check(stage.atk > 0, "%s s%d ATK válido (%d)" % [mid, st, stage.atk])
			_check(not stage.drops.is_empty(), "%s s%d possui tabela de drops" % [mid, st])

			if st >= 3:
				_check(&"boss" in stage.behaviors, "%s s%d marcado como chefe (boss)" % [mid, st])

		# Checa se o Boss Aranha e Boss Serpente têm os drops de crendice no estágio 3 e 4
		if mid == &"spider_goliath":
			var s3_drops: Array = mon.stages[2].drops
			var has_crendice: bool = false
			for d: DropEntry in s3_drops:
				if d.item_id == &"teia_matriarca_golias":
					has_crendice = true
					break
			_check(has_crendice, "Golias s3 tem drop de amuleto 'teia_matriarca_golias'")
		elif mid == &"river_anaconda":
			var s3_drops: Array = mon.stages[2].drops
			var has_crendice: bool = false
			for d: DropEntry in s3_drops:
				if d.item_id == &"olho_cobra_grande":
					has_crendice = true
					break
			_check(has_crendice, "Cobra-Grande s3 tem drop de amuleto 'olho_cobra_grande'")


func _test_boss_crendices() -> void:
	print("\n-- Test Amuletos de Crendice dos Chefes --")
	for cid: StringName in BOSS_CRENDICES:
		var item: ItemDef = Content.item(cid)
		_check(item != null, "Item amuleto '%s' existe" % cid)
		if item != null:
			_check(item.type == ItemDef.ItemType.CRENDICE, "%s é tipo CRENDICE" % cid)
			_check(item.buy_price == 0, "%s não é vendido por NPC (buy_price = 0)" % cid)

		var cdef: CrendiceDef = CrendiceDatabase.get_crendice(cid)
		_check(cdef != null, "CrendiceDatabase define '%s'" % cid)
		if cdef != null:
			_check(not cdef.valid_slots.is_empty(), "%s define slots válidos" % cid)
			_check(cdef.superstition_rule != &"", "%s define regra de superstição" % cid)
