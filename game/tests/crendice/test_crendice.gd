extends Node
## Testes automatizados do Sistema de Crendices e Superstições do Folclore Brasileiro.
## Valida integridade do banco de dados, regras de superstição, engastes de equipamento,
## dormência por morte, consagração em altares, sinergias e condições de drop.
## Rodar: godot --headless --path game res://tests/crendice/test_crendice.tscn

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("--- INICIANDO TESTES DO SISTEMA DE CRENDICES ---")
	_test_database_integrity()
	_test_no_commercial_npcs()
	_test_socket_insertion_and_removal()
	_test_superstition_conditions()
	_test_death_dormancy_and_altar_consecration()
	_test_thematic_synergies()
	_test_superstition_drop_rules()
	print("--- TESTES CONCLUÍDOS ---")
	print("test_crendice: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL: %s %s" % [what, str(detail) if detail != null else ""])
	else:
		print("  PASS: %s" % what)


func _test_database_integrity() -> void:
	var all_crendices: Dictionary[StringName, CrendiceDef] = CrendiceDatabase.all()
	_check(all_crendices.size() >= 20, "Banco de Crendices contém pelo menos 20 amuletos folclóricos", all_crendices.size())

	for cid: StringName in all_crendices:
		var c: CrendiceDef = all_crendices[cid]
		_check(c.id == cid, "ID do amuleto confere com a chave do banco: %s" % cid)
		_check(not c.name_key.is_empty(), "Amuleto tem chave de nome: %s" % cid)
		_check(not c.lore_key.is_empty(), "Amuleto tem chave de lore folclórico: %s" % cid)
		_check(not c.valid_slots.is_empty(), "Amuleto define valid_slots de equipamento: %s" % cid)

		# Verifica se o arquivo .tres do item existe
		var item_res: ItemDef = Content.item(cid)
		_check(item_res != null, "Recurso ItemDef existe para o amuleto: %s" % cid)
		if item_res != null:
			_check(item_res.type == ItemDef.ItemType.CRENDICE, "ItemDef type é CRENDICE: %s" % cid)
			_check(item_res.crendice_id == cid, "ItemDef crendice_id aponta corretamente: %s" % cid)


func _test_no_commercial_npcs() -> void:
	# Regra do GDD: Itens de crendice só podem ser dropados ou trocados, NENHUM NPC vende!
	var all_crendices: Dictionary[StringName, CrendiceDef] = CrendiceDatabase.all()
	for cid: StringName in all_crendices:
		var item_res: ItemDef = Content.item(cid)
		if item_res != null:
			_check(item_res.buy_price == 0, "Amuleto %s não pode ser comprado de NPCs (buy_price == 0)" % cid, item_res.buy_price)


func _test_socket_insertion_and_removal() -> void:
	# Usa o item real leather_jerkin que existe no jogo
	var stack := ItemStack.create(&"leather_jerkin", 1)
	var max_s: int = stack.get_max_sockets()
	_check(max_s >= 1, "Equipamento possui slots de encaixe de crendice (leather_jerkin)", max_s)

	# Valida inserção válida: Figa de Madeira em body
	var figa_err: String = CrendiceSystem.can_insert_crendice(stack, &"figa_de_madeira", 0)
	_check(figa_err.is_empty(), "Figa de Madeira pode ser encaixada em body/armadura", figa_err)

	# Valida inserção inválida: Dente de Onça (só arma) em body
	var onca_err: String = CrendiceSystem.can_insert_crendice(stack, &"dente_de_onca", 0)
	_check(not onca_err.is_empty(), "Dente de Onça não pode ser encaixado em body (apenas em arma)", onca_err)

	# Testa inserção
	var ok_insert: bool = CrendiceSystem.insert_crendice(stack, &"figa_de_madeira", 0)
	_check(ok_insert, "Inserção no slot 0 retornou sucesso")
	_check(stack.crendices.size() == 1 and stack.crendices[0] == &"figa_de_madeira", "Stack agora contém figa_de_madeira no índice 0")

	# Testa remoção
	var removed_id: StringName = CrendiceSystem.remove_crendice(stack, 0)
	_check(removed_id == &"figa_de_madeira", "Remoção devolveu o id do amuleto", removed_id)
	_check(stack.crendices.is_empty(), "Stack está limpo após remoção")


func _test_superstition_conditions() -> void:
	var figa: CrendiceDef = CrendiceDatabase.get_crendice(&"figa_de_madeira")
	_check(figa != null, "Figa de Madeira encontrada")

	# HP alto (> 30%): bônus normal
	var ctx_high_hp := {"hp_ratio": 0.8}
	var eff_high: Dictionary = CrendiceSystem.get_effective_effects(figa, ctx_high_hp, false)
	_check(bool(eff_high.get("active", false)), "Figa ativa com HP alto")
	_check(int(eff_high["special"].get("shadow_resist_pct", 0)) == 15, "Resistência a dano sombrio base é 15%")

	# HP baixo (< 30%): a figa 'protege no desespero' e o bônus dobra!
	var ctx_low_hp := {"hp_ratio": 0.2}
	var eff_low: Dictionary = CrendiceSystem.get_effective_effects(figa, ctx_low_hp, false)
	_check(int(eff_low["special"].get("shadow_resist_pct", 0)) == 30, "Superstição ativada: resistência dobra para 30% com HP < 30%")

	# Guia de Arruda: perde o efeito se pisar na água ou lama
	var arruda: CrendiceDef = CrendiceDatabase.get_crendice(&"guia_de_arruda")
	var ctx_mud := {"in_water": true}
	var eff_mud: Dictionary = CrendiceSystem.get_effective_effects(arruda, ctx_mud, false)
	_check(not bool(eff_mud.get("active", true)), "Guia de Arruda perde efeito em água/lama")

	# Dente de Onça: só ativa à noite ou na floresta
	var onca: CrendiceDef = CrendiceDatabase.get_crendice(&"dente_de_onca")
	var ctx_day_plains := {"is_night": false, "in_forest": false}
	var eff_day: Dictionary = CrendiceSystem.get_effective_effects(onca, ctx_day_plains, false)
	_check(not bool(eff_day.get("active", true)), "Dente de Onça inativo de dia em campo aberto")

	var ctx_night := {"is_night": true, "in_forest": false}
	var eff_night: Dictionary = CrendiceSystem.get_effective_effects(onca, ctx_night, false)
	_check(bool(eff_night.get("active", false)), "Dente de Onça ativo durante a noite")

	var ctx_forest := {"is_night": false, "in_forest": true}
	var eff_forest: Dictionary = CrendiceSystem.get_effective_effects(onca, ctx_forest, false)
	_check(bool(eff_forest.get("active", false)), "Dente de Onça ativo dentro da floresta")


func _test_death_dormancy_and_altar_consecration() -> void:
	var equip := Equipment.new()
	var boots_stack := ItemStack.create(&"walking_boots", 1)

	# Encaixa Pata de Quati na bota
	CrendiceSystem.insert_crendice(boots_stack, &"pata_de_quati", 0)
	equip.set_slot(&"feet", boots_stack)

	# Bônus antes da morte: SOR +5 e drop_rate_pct +15%
	var b_before: Dictionary = equip.calc_crendice_bonuses()
	_check(int(b_before["stats"].get(&"luk", 0)) == 5, "Pata de Quati concede +5 LUK")
	_check(int(b_before["special"].get("drop_rate_pct", 0)) == 15, "Pata de Quati concede +15% de taxa de drop")

	# Simula morte do jogador: a sorte da pata acaba e ela adormece
	var adormecidos: Array[StringName] = CrendiceSystem.on_player_death(equip)
	_check(adormecidos.has(&"pata_de_quati"), "Pata de Quati ficou adormecida após a morte")

	# Bônus após a morte: deve ser 0!
	var b_after_death: Dictionary = equip.calc_crendice_bonuses()
	_check(int(b_after_death["stats"].get(&"luk", 0)) == 0, "Pata de Quati adormecida não concede LUK")
	_check(int(b_after_death["special"].get("drop_rate_pct", 0)) == 0, "Pata de Quati adormecida não concede drop")

	# Jogador visita o Altar de Crendice para consagrar e reativar a sorte (gratuito)
	var ok_consecrate: bool = CrendiceSystem.consecrate_crendice(boots_stack, 0)
	_check(ok_consecrate, "Consagração no Altar de Crendice teve sucesso")

	# Bônus recuperados!
	var b_after_consecrate: Dictionary = equip.calc_crendice_bonuses()
	_check(int(b_after_consecrate["stats"].get(&"luk", 0)) == 5, "Sorte reativada: +5 LUK recuperado")
	_check(int(b_after_consecrate["special"].get("drop_rate_pct", 0)) == 15, "Sorte reativada: +15% taxa de drop recuperada")


func _test_thematic_synergies() -> void:
	# Testa sinergia "Proteção Total": Figa de Madeira + Guia de Arruda + Saquinho de Sal Grosso
	var active_ids: Array[StringName] = [&"figa_de_madeira", &"guia_de_arruda", &"saquinho_sal_grosso"]
	var synergies: Array[Dictionary] = CrendiceSystem.get_active_synergies(active_ids)
	_check(synergies.size() == 1, "Detectou exatamente 1 sinergia para o conjunto de proteção", synergies.size())
	if not synergies.is_empty():
		_check(synergies[0]["id"] == &"protecao_total", "Sinergia ativada é Proteção Total", synergies[0]["id"])
		_check(int(synergies[0]["bonuses"].get("all_def_pct", 0)) == 15, "Proteção Total concede +15% de defesa geral")
		_check(int(synergies[0]["bonuses"].get("curse_resist_pct", 0)) == 30, "Proteção Total concede resistência a maldições")

	# Testa sinergia "Espírito da Caça": Dente de Onça + Dente de Cascavel + Pata de Quati
	var hunt_ids: Array[StringName] = [&"dente_de_onca", &"dente_de_cascavel", &"pata_de_quati"]
	var hunt_synergies: Array[Dictionary] = CrendiceSystem.get_active_synergies(hunt_ids)
	_check(hunt_synergies.size() == 1, "Detectou sinergia de Caça")
	if not hunt_synergies.is_empty():
		_check(hunt_synergies[0]["id"] == &"espirito_da_caca", "Sinergia ativada é Espírito da Caça")
		_check(int(hunt_synergies[0]["bonuses"].get("crit_damage_pct", 0)) == 10, "Espírito da Caça concede +10% Dano Crítico")


func _test_superstition_drop_rules() -> void:
	var figa: CrendiceDef = CrendiceDatabase.get_crendice(&"figa_de_madeira")
	# Figa só cai se o jogador estiver com menos de 30% de HP ("a proteção só se manifesta no desespero")
	var drop_ctx_full_hp := {
		"monster_id": &"cave_skeleton",
		"killer_hp_ratio": 1.0,
		"is_night": false
	}
	_check(not CrendiceSystem.can_drop_crendice(figa, drop_ctx_full_hp), "Figa não dropa se jogador tiver HP alto (> 30%)")

	var drop_ctx_despair := {
		"monster_id": &"cave_skeleton",
		"killer_hp_ratio": 0.25,
		"is_night": false
	}
	_check(CrendiceSystem.can_drop_crendice(figa, drop_ctx_despair), "Figa dropa quando jogador está no desespero (HP < 30%)")

	# Pata de Quati: só cai com crítico ou durante o dia
	var pata: CrendiceDef = CrendiceDatabase.get_crendice(&"pata_de_quati")
	var drop_ctx_night_nocrit := {
		"monster_id": &"buriti_boar",
		"is_night": true,
		"is_crit": false
	}
	_check(not CrendiceSystem.can_drop_crendice(pata, drop_ctx_night_nocrit), "Pata de Quati não dropa de noite sem crítico")

	var drop_ctx_day := {
		"monster_id": &"buriti_boar",
		"is_night": false,
		"is_crit": false
	}
	_check(CrendiceSystem.can_drop_crendice(pata, drop_ctx_day), "Pata de Quati dropa durante o dia")

	# Casca do Escorpião Atroz: só cai de monstro Atroz à noite
	var casca: CrendiceDef = CrendiceDatabase.get_crendice(&"casca_escorpiao_atroz")
	var ctx_normal_scorpion := {
		"monster_id": &"yellow_scorpion",
		"is_atroz": false,
		"is_boss": false,
		"is_night": true
	}
	_check(not CrendiceSystem.can_drop_crendice(casca, ctx_normal_scorpion), "Casca atroz não dropa de escorpião comum")

	var ctx_atroz_scorpion := {
		"monster_id": &"yellow_scorpion",
		"is_atroz": true,
		"is_boss": false,
		"is_night": true
	}
	_check(CrendiceSystem.can_drop_crendice(casca, ctx_atroz_scorpion), "Casca atroz dropa de escorpião em forma atroz à noite")
