extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("--- TEST TRAINING TITLES AND SCALING ---")
	_test_no_level_requirement()
	_test_single_training_title_rule()
	_test_outside_title_scaling()
	_test_all_titles_have_quests()
	print("test_training_titles_and_scaling: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String, detail: Variant = null) -> void:
	_checks += 1
	print(("ok   " if condition else "FAIL ") + description + ("" if detail == null else " %s" % str(detail)))
	if not condition:
		_failures += 1


## Quests de título nunca pedem nível (GDD §8.4): nem no Campo de Treino nem fora dele.
func _test_no_level_requirement() -> void:
	var world := ServerWorld.new()
	var progression := Progression.new(world)
	var novice := CharacterData.create_new("NoviceLow", &"male")
	novice.level = 1
	var session := PlayerSession.new(1, null, novice)
	for qid: StringName in [&"tf_blade_title", &"tf_arcane_title", &"tf_bow_title"]:
		var q: QuestDef = Content.quest(qid)
		_check(q != null and progression.quests.missing_requirements(session, q).is_empty(),
				"%s disponível no nível 1" % qid)
	novice.progression.titles[&"pindorama_blade_machete"] = 1
	var aroeira: QuestDef = Content.quest(&"pindorama_blade_aroeira_title")
	# No Campo de Treino só um título: o 2º (de qualquer Mestre, inclusive lição que dá título) espera a saída.
	novice.left_training = false
	var blocked_in_training := false
	for m: Array in progression.quests.missing_requirements(session, aroeira):
		blocked_in_training = blocked_in_training or m[0] == QuestService.REQ_LEAVE_TRAINING
	_check(blocked_in_training, "2º título bloqueado enquanto está no Campo de Treino")
	var lesson: QuestDef = Content.quest(&"lesson_bow_low_shot")
	var lesson_blocked := false
	for m: Array in progression.quests.missing_requirements(session, lesson):
		lesson_blocked = lesson_blocked or m[0] == QuestService.REQ_LEAVE_TRAINING
	_check(lesson_blocked, "lição que dá título também bloqueada no treino")
	novice.left_training = true
	_check(aroeira != null and progression.quests.missing_requirements(session, aroeira).is_empty(),
			"2º título disponível no nível 1 depois de sair do treino (só conhecimento)")
	for q: QuestDef in Content.all(&"quests").values():
		_check(not &"required_level" in q, "quest %s sem campo de nível" % q.id)
		break


func _test_single_training_title_rule() -> void:
	var world := ServerWorld.new()
	var progression := Progression.new(world)
	var char_done := CharacterData.create_new("TrainedHero", &"male")
	char_done.level = 5
	char_done.progression.quests_done[&"tf_blade_title"] = 1
	char_done.progression.titles[&"pindorama_blade_machete"] = 1
	var session := PlayerSession.new(3, null, char_done)

	_check(progression.quests.training_title_done(session), "training_title_done is true")

	# Other training title quests must now be blocked by REQ_TRAINING_TITLE
	for qid: StringName in [&"tf_arcane_title", &"tf_bow_title"]:
		var q: QuestDef = Content.quest(qid)
		var missing: Array = progression.quests.missing_requirements(session, q)
		var has_training_block := false
		for m: Array in missing:
			if m[0] == QuestService.REQ_TRAINING_TITLE:
				has_training_block = true
		_check(has_training_block, "%s blocked because 1 title already obtained in training" % qid)


## Cada título conquistado deixa a próxima quest de título mais difícil: mais abates/coletas e etapas de
## veterano (relíquias, chefe do covil, forma atroz). Sub-histórias dos anciãos pedem renome 3.
func _test_outside_title_scaling() -> void:
	var world := ServerWorld.new()
	var progression := Progression.new(world)
	var q: QuestDef = Content.quest(&"pindorama_blade_aroeira_title")
	_check(q != null, "pindorama_blade_aroeira_title existe")
	if q == null:
		return
	var n1: Array[int] = QuestService.needs_for(q, 1)
	var n2: Array[int] = QuestService.needs_for(q, 2)
	var n3: Array[int] = QuestService.needs_for(q, 3)
	var active := func(needs: Array[int]) -> int:
		return needs.filter(func(v: int) -> bool: return v != QuestService.SKIPPED_STEP).size()
	_check(active.call(n1) == 5 and active.call(n2) == 6 and active.call(n3) == 7,
			"etapas de veterano entram com 1, 2 e 3 títulos", [n1, n2, n3])
	var kill_i: int = -1
	var relic_i: int = -1
	for i: int in q.steps.size():
		if q.steps[i].type == QuestStep.StepType.KILL and q.steps[i].variant == &"any" and kill_i < 0:
			kill_i = i
		if q.steps[i].min_prior_titles == 1:
			relic_i = i
	_check(kill_i >= 0 and n2[kill_i] > n1[kill_i], "abates crescem a cada título", [n1[kill_i], n2[kill_i]])
	_check(relic_i >= 0 and q.steps[relic_i].type == QuestStep.StepType.COLLECT and n1[relic_i] == 2,
			"2º título já pede relíquias (itens raros)")
	# Save antigo (4 etapas de base, na 4ª = provação): continua na provação, sem as etapas novas.
	var c := CharacterData.create_new("OldSave", &"male")
	c.progression.titles[&"pindorama_blade_machete"] = 1
	c.progression.quests[q.id] = {ProgressionData.Q_STEP: 3, ProgressionData.Q_COUNT: 0,
			ProgressionData.Q_NEEDS: [1, 4, 6, 1]}
	var s := PlayerSession.new(5, null, c)
	var cur: QuestStep = progression.quests.current_step(s, q)
	_check(cur != null and cur.type == QuestStep.StepType.TRIAL, "save antigo continua na mesma etapa")
	# Renome nas sub-histórias.
	var elder: QuestDef = Content.quest(&"elder_ze_steel_song")
	var hero := CharacterData.create_new("Hero", &"male")
	hero.left_training = true
	hero.progression.titles[&"pindorama_blade_machete"] = 1
	hero.progression.titles[&"pindorama_arcane_firefly"] = 1
	var hs := PlayerSession.new(6, null, hero)
	var blocked := false
	for m: Array in progression.quests.missing_requirements(hs, elder):
		blocked = blocked or m[0] == QuestService.REQ_CAUSOS
	_check(blocked, "sub-história bloqueada sem renome 3")
	hero.causos = 3
	_check(progression.quests.missing_requirements(hs, elder).is_empty(), "sub-história liberada com renome 3")
	# Crédito solo: abate de outro membro do grupo não conta na quest de título.
	var solo := CharacterData.create_new("Solo", &"male")
	var ss := PlayerSession.new(7, null, solo)
	var tq: QuestDef = Content.quest(&"tf_blade_title")
	solo.progression.quests[tq.id] = {ProgressionData.Q_STEP: 2, ProgressionData.Q_COUNT: 0,
			ProgressionData.Q_NEEDS: QuestService.needs_for(tq, 0)}
	_check(QuestService.is_solo_quest(tq), "quest de título é solo")
	_check(progression.quests.active_solo_quest(ss) == tq.name_key, "quest de título ativa bloqueia grupo")


func _test_all_titles_have_quests() -> void:
	var expected_titles: Array[StringName] = [
		&"pindorama_blade_machete", &"pindorama_blade_aroeira", &"pindorama_blade_jaguar",
		&"pindorama_arcane_firefly", &"pindorama_arcane_crystal", &"pindorama_arcane_boitata",
		&"pindorama_bow_cerrado", &"pindorama_bow_brejo", &"pindorama_bow_gaviao",
		&"pindorama_hybrid_ember",
		&"pindorama_support_root", &"pindorama_support_buriti", &"pindorama_support_matinta",
		&"pindorama_tank_jabuti", &"pindorama_tank_anta", &"pindorama_tank_mapinguari"
	]

	var all_quests: Dictionary = Content.all(&"quests")
	for tid: StringName in expected_titles:
		var found_quest: QuestDef = null
		for q: QuestDef in all_quests.values():
			if q != null and q.reward_title == tid:
				found_quest = q
				break
		_check(found_quest != null, "title '%s' has rewarding quest '%s'" % [tid, found_quest.id if found_quest != null else "NONE"])
		if found_quest != null:
			_check(not found_quest.steps.is_empty(), "quest '%s' has steps" % found_quest.id)
			_check(not tr(found_quest.name_key).is_empty() and tr(found_quest.name_key) != found_quest.name_key, "quest '%s' name localized" % found_quest.id)
			_check(not tr(found_quest.offer_text_key).is_empty() and tr(found_quest.offer_text_key) != found_quest.offer_text_key, "quest '%s' offer localized" % found_quest.id)
			_check(not tr(found_quest.complete_text_key).is_empty() and tr(found_quest.complete_text_key) != found_quest.complete_text_key, "quest '%s' complete localized" % found_quest.id)
