extends Node
## Arco 1 da história (ARCO-1-TERRA-DE-PINDORAMA.md), headless e sem rede:
##  - cadeia das quests (1→2→3→4; 5–9 depois do 4; final só com os 9) e a trava do final;
##  - capítulos ainda desligados (arte pendente) e o pulo do capítulo 2 no meio da cadeia;
##  - chefes da história como dados (só estágios 3 e 4, atroz fixo, níveis da §2, drops, crendices);
##  - regras do covil da história (só à noite, 1 h, some ao amanhecer, 1 por mapa, bando >= 10) e covis reais;
##  - ritual que nunca cria um segundo chefe;
##  - crédito de história para os participantes do combate (venha o chefe do ritual ou sozinho);
##  - item de quest que só cai com a quest, falas em páginas, conclusão por desfecho/item, recompensa por caminho.
## Rodar: godot --headless --path game res://tests/story/test_arc1.tscn

const CHAPTERS: Array[StringName] = [&"arc1_ch1_saci", &"arc1_ch2_mula", &"arc1_ch3_lobisomem", &"arc1_ch4_curupira",
		&"arc1_ch5_pisadeira", &"arc1_ch6_iara", &"arc1_ch7_mapinguari", &"arc1_ch8_cuca", &"arc1_ch9_boiuna"]
const FINAL: StringName = &"arc1_final_boitata"
const PROLOGUE: StringName = &"arc1_prologue_petals"
## Capítulo -> [chefe, nível da §2, peças garantidas na primeira vitória].
const BOSSES: Dictionary[StringName, Array] = {
	&"arc1_ch1_saci": [&"story_saci", 12, [&"whirlwind_cap"]],
	&"arc1_ch2_mula": [&"story_mula", 25, [&"crossroads_machete", &"black_fire_horseshoe"]],
	&"arc1_ch3_lobisomem": [&"story_lobisomem", 30, [&"full_moon_claws"]],
	&"arc1_ch4_curupira": [&"story_curupira", 32, [&"forest_boy_bow", &"backward_footprints"]],
	&"arc1_ch5_pisadeira": [&"story_pisadeira", 50, [&"light_sleep_cloak"]],
	&"arc1_ch6_iara": [&"story_iara", 36, [&"singing_waters_staff"]],
	&"arc1_ch7_mapinguari": [&"story_mapinguari", 38, [&"ratanaba_guardian_shield"]],
	&"arc1_ch8_cuca": [&"story_cuca", 54, [&"lullaby_tome"]],
	&"arc1_ch9_boiuna": [&"story_boiuna", 56, [&"black_storm_bow"]],
	&"arc1_final_boitata": [&"story_boitata", 60, []],
}
## Arte instalada (aprovada pelo dono): o resto fica desligado.
const INSTALLED: Array[StringName] = [&"story_saci", &"story_lobisomem", &"story_curupira", &"story_pisadeira",
		&"story_mula", &"story_mapinguari", &"story_cuca", &"story_boiuna", &"story_iara", &"story_boitata"]
## Fragmentos de Maria (§5): entregues na vitória do ritual.
const FRAGMENTS: Dictionary[StringName, StringName] = {&"arc1_ch6_iara": &"mother_of_pearl_comb",
		&"arc1_ch7_mapinguari": &"dolphin_rubbing", &"arc1_ch9_boiuna": &"boiuna_words", FINAL: &"river_memory"}
## Covis reais: mapa -> chefe.
const LAIR_MAPS: Dictionary[StringName, StringName] = {&"fields_pindorama_crossroads": &"story_saci",
		&"cave_reino_encoberto_4": &"story_lobisomem", &"enchanted_forest_heart": &"story_curupira",
		&"hoer_verde_4": &"story_pisadeira", &"split_sky_plateau_summit": &"story_mula",
		&"ruins_ratanaba_4": &"story_mapinguari", &"hollow_earth_cauldron": &"story_cuca",
		&"sumidouro_abyss": &"story_boiuna", &"jungle_z_river": &"story_iara",
		&"cave_reino_encoberto_5": &"story_boitata"}
## Mapas novos do arco: nível e mapa de onde se entra.
const NEW_MAPS: Dictionary[StringName, Array] = {&"sumidouro_abyss": [50, 56, &"city_sumidouro"],
		&"cave_reino_encoberto_5": [55, 60, &"cave_reino_encoberto_4"],
		&"hollow_earth_cauldron": [54, 60, &"hollow_earth_5"]}
const CRENDICES: Dictionary[StringName, StringName] = {&"no_de_crina_trancada": &"story_saci",
		&"ferradura_de_porta": &"story_mula", &"restia_de_alho": &"story_lobisomem",
		&"cipo_da_pegada_virada": &"story_curupira", &"travesseiro_de_macela": &"story_pisadeira",
		&"escama_dourada_do_rio": &"story_iara", &"unha_do_guardiao": &"story_mapinguari",
		&"cantiga_bordada": &"story_cuca", &"escama_da_tempestade": &"story_boiuna", &"brasa_que_nao_apaga": &"story_boitata"}

var _checks: int = 0
var _failures: int = 0
var world: ServerWorld = null
var quests: QuestService = null
var _entities: Array[NetEntity] = []


func _ready() -> void:
	TranslationServer.set_locale("pt_BR")
	Net.is_server = true
	world = ServerWorld.new()
	world.progression = Progression.new(world)
	quests = world.progression.quests
	_test_quest_data()
	_test_boss_data()
	_test_chain_and_final_lock()
	_test_lair_rules()
	_test_real_lairs()
	_test_story_brain()
	_test_ritual_credit()
	_test_quest_drop()
	_test_texts_and_rewards()
	_test_new_maps()
	_test_boitata_fight()
	for e: NetEntity in _entities:
		e.free()
	world.free()
	print("test_arc1: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL %s %s" % [what, str(detail) if detail != null else ""])


func _session(peer: int, name: String) -> PlayerSession:
	var entity := NetEntity.new()
	var sync := MultiplayerSynchronizer.new()
	sync.name = NetEntity.SYNC_NODE_NAME
	entity.add_child(sync)
	entity.server_setup(peer, &"player", name, &"male", &"city_awakening", Vector3(2, 0, 2))
	var c := CharacterData.create_new(name, &"male")
	c.left_training = true
	var s := PlayerSession.new(peer, entity, c)
	world._sessions[peer] = s
	world._entities[peer] = entity
	_entities.append(entity)
	return s


func _missing_keys(s: PlayerSession, id: StringName) -> Array[String]:
	var out: Array[String] = []
	for m: Array in quests.missing_requirements(s, Content.quest(id)):
		out.append(String(m[0]))
	return out


func _last_step(id: StringName) -> QuestStep:
	var q: QuestDef = Content.quest(id)
	return q.steps[q.steps.size() - 1] if q != null and not q.steps.is_empty() else null


# ================================================================ dados das quests

func _test_quest_data() -> void:
	var causos: Dictionary = {}
	for id: StringName in CHAPTERS + [FINAL, PROLOGUE]:
		var q: QuestDef = Content.quest(id)
		if not _check_bool(q != null, "quest %s existe" % id):
			continue
		if id == PROLOGUE:
			_check(q.reward_causo_id.is_empty() and q.required_quests.is_empty(), "prólogo é opcional e não dá Causo")
			continue
		_check(not q.reward_causo_id.is_empty() and not causos.has(q.reward_causo_id),
				"%s concede um Causo com story_id próprio" % id, q.reward_causo_id)
		causos[q.reward_causo_id] = true
		var last: QuestStep = _last_step(id)
		var boss: StringName = BOSSES[id][0]
		_check(last != null and last.type == QuestStep.StepType.RITUAL and last.target_id == boss,
				"%s termina no ritual de %s" % [id, boss])
		for item: StringName in BOSSES[id][2]:
			_check(q.reward_items.has(item), "%s garante %s na primeira vitória" % [id, item])
		var installed: bool = boss in INSTALLED
		_check(q.released == installed, "%s liberada só com a arte do chefe instalada" % id, [q.released, installed])
		if FRAGMENTS.has(id):
			_check(last.grant_items.has(FRAGMENTS[id]), "%s entrega o fragmento %s na vitória" % [id, FRAGMENTS[id]])
	_check(causos.size() == 10, "10 Causos próprios (9 capítulos + final)", causos.size())
	# Ordem (§2.1): 1→2→3→4; 5–9 depois do 4; final com os 9.
	_check(Content.quest(&"arc1_ch1_saci").required_quests.is_empty(), "capítulo 1 abre sem capítulo anterior")
	_check(Content.quest(&"arc1_ch2_mula").required_quests == [&"arc1_ch1_saci"], "capítulo 2 depois do 1")
	var ch3: QuestDef = Content.quest(&"arc1_ch3_lobisomem")
	_check(&"arc1_ch2_mula" in ch3.required_quests and &"arc1_ch1_saci" in ch3.required_quests, "capítulo 3 depois do 1 e do 2")
	_check(ch3.required_story_completed == [&"lobisomem_arc"], "capítulo 3 exige o Arco do Lobisomem concluído (qualquer rota)")
	_check(Content.quest(&"arc1_ch4_curupira").required_quests == [&"arc1_ch3_lobisomem"], "capítulo 4 depois do 3")
	for i: int in range(4, 9):
		_check(Content.quest(CHAPTERS[i]).required_quests == [&"arc1_ch4_curupira"], "%s abre depois do 4" % CHAPTERS[i])
	var fin: QuestDef = Content.quest(FINAL)
	var all9: bool = fin.required_quests.size() == 9
	for id: StringName in CHAPTERS:
		all9 = all9 and id in fin.required_quests
	_check(all9 and not fin.skip_unreleased_requirements, "final exige os 9 capítulos, sem exceção")
	_check(not fin.reward_by_archetype.is_empty(), "final entrega a arma Chama-Viva pelo caminho do jogador")
	# Regra cultural: Erevos só aparece a partir do capítulo 4.
	for id: StringName in [PROLOGUE, &"arc1_ch1_saci", &"arc1_ch2_mula", &"arc1_ch3_lobisomem"]:
		var q: QuestDef = Content.quest(id)
		var texts: Array[String] = [q.offer_text_key, q.progress_text_key, q.complete_text_key, q.desc_key]
		for v: String in q.complete_text_variants.values():
			texts.append(v)
		for st: QuestStep in q.steps:
			texts.append_array([st.text_key, st.lore_text_key, st.done_text_key])
		var named: bool = false
		for k: String in texts:
			for p: int in range(1, QuestService.page_count(k) + 1):
				named = named or TranslationServer.translate(QuestService.page_key(k, p)).contains("Erevos")
		_check(not named, "%s ainda não diz o nome de Erevos" % id)
	var ch4_named: bool = false
	var ck: String = Content.quest(&"arc1_ch4_curupira").complete_text_key
	for p: int in range(1, QuestService.page_count(ck) + 1):
		ch4_named = ch4_named or TranslationServer.translate(QuestService.page_key(ck, p)).contains("Erevos")
	_check(ch4_named, "o Curupira (capítulo 4) dá o nome de Erevos")
	_check(TranslationServer.translate("QUEST_ARC1_CH5_LORE_1_P3").contains("Mataram a filha dele")
			and TranslationServer.translate("QUEST_ARC1_CH5_DONE_6").contains("Mataram a filha dele"),
			"a Pisadeira repete \"Mataram a filha dele\"")
	var boitata: String = TranslationServer.translate("QUEST_ARC1_FINAL_DONE_2")
	_check(boitata.contains("A filha do Devorador nunca morreu.") and boitata.contains("Ela escolheu desaparecer."),
			"o Boitatá diz as falas exatas da memória")


# ================================================================ chefes como dados

func _test_boss_data() -> void:
	for chapter: StringName in BOSSES:
		var mid: StringName = BOSSES[chapter][0]
		var d: MonsterDef = Content.monster(mid)
		if not _check_bool(d != null, "chefe %s existe" % mid):
			continue
		var s3: MonsterStage = MonsterEvolution.stage_by_number(d, 3)
		var s4: MonsterStage = d.atroz_stage()
		_check(d.story_boss and d.stages.size() == 2 and s3 != null and s4 != null, "%s: só estágios 3 e 4" % mid)
		_check(is_equal_approx(MonsterEvolution.atroz_multiplier(d), 1.0), "%s: atributos já são os da forma atroz" % mid)
		_check(s4 != null and s4.level == int(BOSSES[chapter][1]), "%s no nível da §2" % mid, s4.level if s4 != null else -1)
		_check(s3 != null and s4 != null and s3.baked_life and s4.baked_life, "%s: baked_life" % mid)
		_check(not d.can_be_rare and is_equal_approx(d.respawn_sec, MonsterSpawner.STORY_RESPAWN_SEC), "%s: sem raro, 1 h" % mid)
		_check(d.art_pending == not (mid in INSTALLED), "%s: arte pendente só nos não instalados" % mid)
		if mid in INSTALLED:
			_check(ResourceLoader.exists(s4.sprite_base + "_idle.png"), "%s: folhas instaladas" % mid, s4.sprite_base)
		var drops: Array[StringName] = []
		for e: DropEntry in s4.drops:
			drops.append(e.item_id)
		for item: StringName in BOSSES[chapter][2]:
			_check(item in drops, "%s: revanche pode deixar %s" % [mid, item])
	for cid: StringName in CRENDICES:
		var c: CrendiceDef = CrendiceDatabase.get_crendice(cid)
		if not _check_bool(c != null, "crendice %s existe" % cid):
			continue
		_check(c.drop_rules.get("monster_ids", []) == [CRENDICES[cid]] and is_equal_approx(float(c.drop_rules.get("chance", 0.0)), 0.05),
				"%s cai só do %s, 5%%" % [cid, CRENDICES[cid]], c.drop_rules)
		var ctx: Dictionary = {"monster_id": CRENDICES[cid], "is_atroz": true, "is_boss": true, "is_night": true}
		var other: Dictionary = ctx.duplicate()
		other["monster_id"] = &"prank_whirlwind"
		_check(not CrendiceSystem.can_drop_crendice(c, other), "%s não cai de outro monstro" % cid)


# ================================================================ cadeia e trava do final

func _test_chain_and_final_lock() -> void:
	var s: PlayerSession = _session(101, "Cadeia")
	var data: ProgressionData = s.character.progression
	_check(quests.is_available(s, Content.quest(&"arc1_ch1_saci")), "capítulo 1 disponível para quem saiu do treino")
	_check(quests.is_available(s, Content.quest(PROLOGUE)), "prólogo disponível")
	_check(QuestService.REQ_QUEST in _missing_keys(s, &"arc1_ch2_mula"), "capítulo 2 trancado sem o 1")
	var m3: Array[String] = _missing_keys(s, &"arc1_ch3_lobisomem")
	_check(QuestService.REQ_QUEST in m3 and QuestService.REQ_STORY_COMPLETED in m3, "capítulo 3 trancado sem o 1 e sem o lobisomem", m3)
	data.quests_done[&"arc1_ch1_saci"] = 1
	var ch2: QuestDef = Content.quest(&"arc1_ch2_mula")
	_check(quests.is_available(s, ch2), "capítulo 2 (Mula) abre depois do 1")
	s.character.complete_story_arc(&"lobisomem_arc", &"killed")
	_check(_missing_keys(s, &"arc1_ch3_lobisomem") == [QuestService.REQ_QUEST], "capítulo 3 exige o 2",
			_missing_keys(s, &"arc1_ch3_lobisomem"))
	# Capítulo do meio desligado (arte refeita): o 3 pula só quest com released = false.
	ch2.released = false
	_check(quests.is_available(s, Content.quest(&"arc1_ch3_lobisomem")), "com o 2 desligado, o 3 abre só com o 1 e o lobisomem")
	ch2.released = true
	data.quests_done[&"arc1_ch2_mula"] = 1
	_check(quests.is_available(s, Content.quest(&"arc1_ch3_lobisomem")), "capítulo 3 abre com o 2 e qualquer rota concluída")
	_check(QuestService.REQ_QUEST in _missing_keys(s, &"arc1_ch4_curupira"), "capítulo 4 trancado sem o 3")
	data.quests_done[&"arc1_ch3_lobisomem"] = 1
	_check(quests.is_available(s, Content.quest(&"arc1_ch4_curupira")), "capítulo 4 abre depois do 3")
	for i: int in range(4, 9):
		_check(QuestService.REQ_QUEST in _missing_keys(s, CHAPTERS[i]), "%s trancado antes do 4" % CHAPTERS[i])
	data.quests_done[&"arc1_ch4_curupira"] = 1
	for id: StringName in [&"arc1_ch5_pisadeira", &"arc1_ch7_mapinguari", &"arc1_ch8_cuca", &"arc1_ch9_boiuna"]:
		_check(quests.is_available(s, Content.quest(id)), "%s abre depois do 4" % id, _missing_keys(s, id))
	_check(quests.is_available(s, Content.quest(&"arc1_ch6_iara")), "arc1_ch6_iara abre depois do 4")
	# Trava do final: com ele liberado, só abre com os 9 cumpridos (nunca pula capítulo desligado).
	var fin: QuestDef = Content.quest(FINAL)
	_check(fin.released, "final liberado (Boitatá com arte e andar 5)")
	for id: StringName in CHAPTERS:
		data.quests_done[id] = 1
	data.quests_done.erase(&"arc1_ch9_boiuna")
	_check(_missing_keys(s, FINAL) == [QuestService.REQ_QUEST], "final trancado com 8 de 9", _missing_keys(s, FINAL))
	_check(not quests.is_available(s, fin), "final não aparece com 8 de 9")
	data.quests_done[&"arc1_ch9_boiuna"] = 1
	data.quests_done.erase(&"arc1_ch2_mula")
	_check(QuestService.REQ_QUEST in _missing_keys(s, FINAL), "final não pula a Mula, mesmo desligada")
	data.quests_done[&"arc1_ch2_mula"] = 1
	_check(quests.is_available(s, fin), "final abre com os 9 cumpridos")
	fin.released = false
	_check(QuestService.REQ_NOT_RELEASED in _missing_keys(s, FINAL), "final desligado não abre")
	fin.released = true
	var lone: PlayerSession = _session(102, "Treino")
	lone.character.left_training = false
	_check(not quests.is_available(lone, Content.quest(&"arc1_ch1_saci")), "não abre no Campo de Treino")


# ================================================================ regras do covil da história

func _test_lair_rules() -> void:
	var N: StringName = MonsterSpawner.TIME_NIGHT
	var D: StringName = MonsterSpawner.TIME_DAY
	_check(is_equal_approx(MonsterSpawner.STORY_RESPAWN_SEC, 3600.0), "1 h para voltar (regra 5)")
	_check(MonsterSpawner.STORY_ESCORT_MIN == 10, "bando mínimo de 10 (regra 6)")
	_check(MonsterSpawner.timed_lair_action(N, true, false, false, false) == MonsterSpawner.LAIR_SPAWN, "noite, sem chefe: nasce")
	_check(MonsterSpawner.timed_lair_action(N, false, false, false, false) == &"", "de dia não nasce")
	_check(MonsterSpawner.timed_lair_action(N, true, false, false, true) == &"", "derrotado: espera a 1 h mesmo de noite")
	_check(MonsterSpawner.timed_lair_action(N, false, true, false, false) == MonsterSpawner.LAIR_VANISH, "amanheceu vivo: some")
	_check(MonsterSpawner.timed_lair_action(N, false, true, true, false) == &"", "amanheceu em luta: termina a luta")
	_check(MonsterSpawner.timed_lair_action(N, true, true, false, false) == &"", "noite e vivo: fica")
	_check(MonsterSpawner.timed_lair_action(N, true, false, false, false, true) == &"", "1 chefe da história por mapa")
	_check(MonsterSpawner.timed_lair_action(D, true, true, false, false) == MonsterSpawner.LAIR_VANISH,
			"covil day_only: o chefe de espécie some à noite")
	_check(MonsterSpawner.timed_lair_action(D, false, false, false, false) == MonsterSpawner.LAIR_SPAWN, "day_only volta de dia")
	# Ritual: nunca duplica.
	_check(MonsterSpawner.summon_decision(true, false, true, false) == MonsterSpawner.SUMMON_SPAWNED, "ritual à noite: nasce na hora")
	_check(MonsterSpawner.summon_decision(true, true, true, false) == MonsterSpawner.SUMMON_ALIVE, "ritual com o chefe vivo: não cria outro")
	_check(MonsterSpawner.summon_decision(true, false, false, false) == MonsterSpawner.SUMMON_DAY, "ritual de dia: nada")
	_check(MonsterSpawner.summon_decision(true, false, true, true) == MonsterSpawner.SUMMON_BLOCKED, "ritual com outro chefe da história vivo")
	_check(MonsterSpawner.summon_decision(false, false, true, false) == MonsterSpawner.SUMMON_NO_LAIR, "ritual fora do mapa do covil")
	var saci: MonsterDef = Content.monster(&"story_saci")
	_check(MonsterSpawner.story_lair_problem(saci, {"prank_whirlwind": 12}).is_empty(), "covil válido")
	_check(not MonsterSpawner.story_lair_problem(saci, {"prank_whirlwind": 9}).is_empty(), "bando de 9 recusado")
	var pending: MonsterDef = Content.monster(&"story_iara").duplicate()
	pending.art_pending = true
	_check(not MonsterSpawner.story_lair_problem(pending, {"river_anaconda": 12}).is_empty(),
			"chefe com arte pendente recusado")
	_check(not MonsterSpawner.story_lair_problem(Content.monster(&"prank_whirlwind"), {"prank_whirlwind": 12}).is_empty(),
			"monstro comum não é covil da história")
	var hunt := ZoneDef.new()
	hunt.kind = ZoneDef.Kind.HUNT
	hunt.bosses_allowed = false
	var city := ZoneDef.new()
	city.kind = ZoneDef.Kind.CITY
	city.combat_allowed = false
	var training := ZoneDef.new()
	training.kind = ZoneDef.Kind.TRAINING
	_check(MonsterSpawner.story_lairs_allowed(hunt), "chefe forte em mapa fraco: vale em zona sem covil de espécie")
	_check(not MonsterSpawner.story_lairs_allowed(city) and not MonsterSpawner.story_lairs_allowed(training),
			"nunca em cidade nem no Campo de Treino")


func _test_real_lairs() -> void:
	for map_id: StringName in LAIR_MAPS:
		var map: Node = (load("res://scenes/maps/%s.tscn" % map_id) as PackedScene).instantiate()
		var lairs: Node = map.get_node_or_null(MonsterSpawner.STORY_LAIRS_NODE)
		var spawned_species: Dictionary = {}
		var spawns: Node = map.get_node_or_null(MonsterSpawner.SPAWNS_NODE)
		for m: Node in spawns.get_children() if spawns != null else []:
			spawned_species[StringName(str(m.get_meta(&"monster_id", "")))] = true
		if _check_bool(lairs != null and lairs.get_child_count() == 1, "%s: um covil da história" % map_id):
			var m: Node = lairs.get_child(0)
			var mid := StringName(str(m.get_meta(&"monster_id", "")))
			var escort: Variant = m.get_meta(&"escort", {})
			_check(mid == LAIR_MAPS[map_id], "%s: covil de %s" % [map_id, LAIR_MAPS[map_id]], mid)
			_check(MonsterSpawner.story_lair_problem(Content.monster(mid), escort).is_empty(), "%s: covil válido" % map_id)
			_check(is_equal_approx(float(m.get_meta(&"respawn_sec", MonsterSpawner.STORY_RESPAWN_SEC)), 3600.0), "%s: 1 h" % map_id)
			var same_map: bool = true
			for sp: Variant in (escort as Dictionary):
				same_map = same_map and spawned_species.has(StringName(str(sp)))
			_check(same_map, "%s: bando com espécies que já vivem no mapa (nível do mapa)" % map_id, escort)
		map.free()
	var cave: Node = (load("res://scenes/maps/cave_reino_encoberto_4.tscn") as PackedScene).instantiate()
	var wolf: Node = cave.get_node_or_null(^"BossLairs/werewolf")
	_check(wolf != null and bool(wolf.get_meta(&"day_only", false)), "andar 4: o covil de espécie cede a noite ao Lobisomem da história")
	_check(cave.find_child("DeepPassage", true, false) != null, "andar 4: ponto da passagem do final")
	cave.free()


# ================================================================ cérebro do chefe da história

func _test_story_brain() -> void:
	var d: MonsterDef = Content.monster(&"story_saci")
	var b := MonsterBrain.new()
	b.def = d
	b.stage = MonsterEvolution.stage_by_number(d, 3)
	b.hp = b.stage.max_hp
	b.atroz_pinned = true
	b.update_atroz()
	_check(b.atroz and b.stage == d.atroz_stage(), "nasce na forma atroz (fixa)")
	_check(b.max_hp() == MonsterEvolution.stage_by_number(d, 3).max_hp, "vida = a do estágio 3 (multiplicador 1)")
	b.update_atroz()
	_check(b.atroz, "forma atroz não sai enquanto fixa")
	b.damage_by_peer[11] = 300
	b.engaged_peers[12] = true
	b.engaged_peers[11] = true
	var p: Array[int] = b.participant_peers()
	_check(p.size() == 2 and 11 in p and 12 in p, "participantes = dano + quem ele atacou", p)
	b.free()


# ================================================================ crédito do ritual

func _put_on_step(s: PlayerSession, id: StringName, step: int) -> void:
	var q: QuestDef = Content.quest(id)
	s.character.progression.quests[id] = {ProgressionData.Q_STEP: step, ProgressionData.Q_COUNT: 0,
			ProgressionData.Q_NEEDS: QuestService.needs_for(q, 0)}


func _test_ritual_credit() -> void:
	var ritual_i: int = Content.quest(&"arc1_ch1_saci").steps.size() - 1
	var a: PlayerSession = _session(201, "Ana")      # no ritual, lutou
	var b: PlayerSession = _session(202, "Bento")    # sem a quest, lutou
	var c: PlayerSession = _session(203, "Cida")     # no ritual, não lutou
	var e: PlayerSession = _session(204, "Edu")      # num passo anterior, lutou
	for s: PlayerSession in [a, c]:
		_put_on_step(s, &"arc1_ch1_saci", ritual_i)
		s.character.inventory.add(&"cross_sieve", 1)
	_put_on_step(e, &"arc1_ch1_saci", ritual_i - 2)
	_check(quests.on_story_boss_killed(&"story_curupira", [201, 202, 204]) == 0, "outro chefe não conta")
	_check(not quests.is_ready(a, &"arc1_ch1_saci"), "Ana ainda no ritual")
	var n: int = quests.on_story_boss_killed(&"story_saci", [201, 202, 204])
	_check(n == 1, "só quem está no passo do ritual e lutou ganha a vitória", n)
	_check(quests.is_ready(a, &"arc1_ch1_saci"), "Ana: vitória de história (pronta para entregar)")
	_check(a.character.inventory.count(&"cross_sieve") == 0, "a peneira foi usada no ritual")
	_check(not quests.is_ready(c, &"arc1_ch1_saci") and c.character.inventory.count(&"cross_sieve") == 1,
			"Cida não lutou: continua no ritual (pode repetir na próxima noite)")
	_check(not quests.is_ready(e, &"arc1_ch1_saci"), "Edu não estava no ritual: nada muda")
	_check(not b.character.progression.quests.has(&"arc1_ch1_saci"), "Bento sem a quest: nada muda")
	# Entrega: Causo próprio, equipamento garantido, uma vez só.
	var before: int = a.character.causos
	_check(quests.turn_in(a, &"arc1_ch1_saci", &"dona_jacinta"), "entrega na Dona Jacinta")
	_check(a.character.causos == before + CharacterData.CAUSO_POINTS_STORY, "1 Causo pelo capítulo", a.character.causos)
	_check(a.character.inventory.count(&"whirlwind_cap") == 1, "Gorro do Redemoinho garantido")
	_check(quests.is_done(a, &"arc1_ch1_saci") and not quests.is_available(a, Content.quest(&"arc1_ch1_saci")),
			"capítulo não repete (revanches só pelo nascimento natural)")
	# Ritual com item: a Iara entrega o pente na vitória (fragmento) mesmo vindo do nascimento natural.
	var f: PlayerSession = _session(205, "Fábio")
	_put_on_step(f, &"arc1_ch6_iara", Content.quest(&"arc1_ch6_iara").steps.size() - 1)
	quests.on_story_boss_killed(&"story_iara", [205])
	_check(f.character.inventory.count(&"mother_of_pearl_comb") == 1, "fragmento: pente de madrepérola na vitória")


# ================================================================ item de quest

func _test_quest_drop() -> void:
	var q: QuestDef = Content.quest(&"arc1_ch1_saci")
	var collect_i: int = 3
	var st: QuestStep = q.steps[collect_i]
	_check(st.type == QuestStep.StepType.COLLECT and st.target_id == &"whirlwind_wisp", "passo dos fiapos")
	_check(QuestService.quest_drop_matches(st, &"prank_whirlwind"), "fiapo cai do Redemoinho Arteiro")
	_check(QuestService.quest_drop_matches(st, &"highland_prank_whirlwind"), "variante regional também solta")
	_check(not QuestService.quest_drop_matches(st, &"enchanted_firefly"), "outro monstro não solta")
	var s: PlayerSession = _session(301, "Gil")
	var old: float = st.drop_chance
	st.drop_chance = 1.0
	quests.on_monster_killed(301, &"prank_whirlwind", {})
	_check(s.character.inventory.count(&"whirlwind_wisp") == 0, "sem a quest no passo, o fiapo não cai")
	_put_on_step(s, &"arc1_ch1_saci", collect_i)
	for i: int in 3:
		quests.on_monster_killed(301, &"prank_whirlwind", {})
	st.drop_chance = old
	var cur: QuestStep = quests.current_step(s, q)
	_check(cur != null and cur.type == QuestStep.StepType.TALK and cur.target_id == &"dona_jacinta",
			"3 fiapos: passo seguinte é levar à Dona Jacinta")
	# A Jacinta trança a peneira (grant_items da etapa).
	quests._add_count(s, q, cur, 1)
	_check(s.character.inventory.count(&"cross_sieve") == 1, "Dona Jacinta entrega a Peneira de Cruzeta")


# ================================================================ textos e recompensas

func _test_texts_and_rewards() -> void:
	_check(QuestService.page_count("QUEST_ARC1_CH1_OFFER") == 4, "oferta do capítulo 1 em 4 páginas",
			QuestService.page_count("QUEST_ARC1_CH1_OFFER"))
	_check(QuestService.page_count("QUEST_ARC1_CH2_STEP_1") == 1, "texto curto: 1 página")
	_check(QuestService.page_key("K", 1) == "K" and QuestService.page_key("K", 3) == "K_P3", "chaves das páginas")
	var s: PlayerSession = _session(401, "Hilda")
	var ch3: QuestDef = Content.quest(&"arc1_ch3_lobisomem")
	s.character.complete_story_arc(&"lobisomem_arc", &"healed")
	_check(quests.complete_text_for(s, ch3) == ch3.complete_text_key, "Benzedura: conclusão padrão (Eustáquio vivo)")
	var k: PlayerSession = _session(402, "Ivo")
	k.character.complete_story_arc(&"lobisomem_arc", &"killed")
	_check(quests.complete_text_for(k, ch3) == "QUEST_ARC1_CH3_COMPLETE_KILLED", "Caçador: conclusão própria")
	var ch8: QuestDef = Content.quest(&"arc1_ch8_cuca")
	_check(quests.complete_text_for(s, ch8) == ch8.complete_text_key, "Cuca sem o pente: conclusão padrão")
	s.character.inventory.add(&"mother_of_pearl_comb", 1)
	_check(quests.complete_text_for(s, ch8) == "QUEST_ARC1_CH8_COMPLETE_COMB", "Cuca com o pente: ela hesita (pista falsa)")
	var fin: QuestDef = Content.quest(FINAL)
	_check(QuestService.archetype_reward(fin, &"traveler") == &"living_flame_machete", "sem caminho: Facão Chama-Viva")
	var bow_title: StringName = &""
	for t: Resource in Content.all(&"titles").values():
		if (t as TitleDef).archetype == &"bow":
			bow_title = (t as TitleDef).id
	_check(QuestService.archetype_reward(fin, bow_title) == &"living_flame_bow", "caminho do arco: Arco Chama-Viva")
	for key: String in ["NPC_DONA_JACINTA_NAME", "NPC_FIRMINO_INSONE_NAME", "NPC_DONA_CELESTE_NAME", "MON_STORY_SACI_NAME",
			"PROG_MSG_RITUAL_DAY", "QUEST_OPT_CONTINUE"]:
		_check(TranslationServer.translate(key) != key, "texto %s traduzido" % key)


func _check_bool(ok: bool, what: String) -> bool:
	_check(ok, what)
	return ok


# ================================================================ mapas novos e passagem do andar 5

func _test_new_maps() -> void:
	for map_id: StringName in NEW_MAPS:
		var z: ZoneDef = Content.zone(map_id)
		var spec: Array = NEW_MAPS[map_id]
		if not _check_bool(z != null and ResourceLoader.exists("res://scenes/maps/%s.tscn" % map_id), "%s existe" % map_id):
			continue
		_check(z.recommended_level_min == int(spec[0]) and z.recommended_level_max == int(spec[1]) and z.combat_allowed,
				"%s: nível %d–%d" % [map_id, spec[0], spec[1]])
		var from: ZoneDef = Content.zone(spec[2])
		_check(spec[2] in z.connected_maps and from != null and map_id in from.connected_maps,
				"%s liga com %s nos dois sentidos" % [map_id, spec[2]])
	var abyss: Node = (load("res://scenes/maps/sumidouro_abyss.tscn") as PackedScene).instantiate()
	var species: Array[StringName] = []
	for m: Node in abyss.get_node(^"Spawns").get_children():
		species.append(StringName(str(m.get_meta(&"monster_id"))))
	_check(&"abyss_river_anaconda" in species and &"abyss_black_caiman" in species and &"abyss_water_serpent" in species,
			"Abismo: jacarés, sucuris e serpentes do rio", species)
	abyss.free()
	var ch9: QuestDef = Content.quest(&"arc1_ch9_boiuna")
	_check(ch9.steps[2].drop_from == &"abyss_river_anaconda", "Escamas Negras caem das Sucuris do Abismo")
	var grotto: Node = (load("res://scenes/maps/hollow_earth_cauldron.tscn") as PackedScene).instantiate()
	_check(grotto.find_child("CauldronChamber", true, false) != null, "câmara do caldeirão fica na Gruta do Caldeirão")
	grotto.free()
	var t5: Node = (load("res://scenes/maps/hollow_earth_5.tscn") as PackedScene).instantiate()
	_check(t5.find_child("CauldronChamber", true, false) == null and t5.get_node_or_null(^"StoryLairs") == null,
			"andar 5 da Terra Oca fica só com o Titã")
	t5.free()
	var cave: Node = (load("res://scenes/maps/cave_reino_encoberto_4.tscn") as PackedScene).instantiate()
	var portal: Node = cave.get_node_or_null(^"Interactables/DeepPassagePortal")
	_check(portal != null and StringName(str(portal.get_meta(&"target_map", ""))) == &"cave_reino_encoberto_5"
			and StringName(str(portal.get_meta(&"requires_quest", ""))) == FINAL, "passagem do andar 4 exige o final")
	cave.free()
	var f5: Node = (load("res://scenes/maps/cave_reino_encoberto_5.tscn") as PackedScene).instantiate()
	_check(f5.get_node_or_null(^"StoryLairs/boitata") != null, "andar 5 com o covil do Boitatá")
	f5.free()
	# Passagem: fechada enquanto o final não pode ser aceito; aberta com ele disponível, ativo ou feito.
	var mt := MapTransfer.new(world)
	var s: PlayerSession = _session(501, "Passagem")
	_check(not mt.story_passage_open(s, FINAL), "passagem fechada sem os 9 capítulos")
	var fin: QuestDef = Content.quest(FINAL)
	fin.released = true
	for id: StringName in CHAPTERS:
		s.character.progression.quests_done[id] = 1
	_check(mt.story_passage_open(s, FINAL), "passagem aberta com o final disponível")
	fin.released = false
	_check(not mt.story_passage_open(s, FINAL), "passagem fechada se o final for desligado")
	fin.released = true
	s.character.progression.quests_done[FINAL] = 1
	_check(mt.story_passage_open(s, FINAL), "quem já fez o final volta para as revanches")


# ================================================================ luta do Boitatá

func _test_boitata_fight() -> void:
	_check(BoitataFight.phase_for(1.0) == 1 and BoitataFight.phase_for(0.61) == 1, "fase 1 acima de 60%")
	_check(BoitataFight.phase_for(0.6) == 2 and BoitataFight.phase_for(0.31) == 2, "fase 2 de 60% a 30%")
	_check(BoitataFight.phase_for(0.3) == 3 and BoitataFight.phase_for(0.11) == 3, "fase 3 de 30% a 10%")
	_check(BoitataFight.phase_for(0.1) == 4 and BoitataFight.phase_for(0.01) == 4, "chama negra abaixo de 10%")
	var d: MonsterDef = Content.monster(&"story_boitata")
	_check(BoitataFight.wants(d.atroz_stage()) and BoitataFight.BEHAVIOR in MonsterBehaviors.KNOWN,
			"Boitatá luta por fases")
	for id: StringName in [BoitataFight.BREATH, BoitataFight.TRAIL, BoitataFight.RING]:
		_check(Content.monster_skill(id) != null and Content.skill(id) == null and Content.any_skill(id) != null,
				"habilidade %s em data/monster_skills (fora das skills de jogador)" % id)
	var breath: SkillDef = Content.monster_skill(BoitataFight.BREATH)
	_check(breath.target_type == SkillDef.TargetType.CONE and is_equal_approx(breath.ground_warning_sec, 1.0),
			"sopro em cone com aviso de 1 s")
	_check(Content.monster(BoitataFight.WISP_ID) != null and not Content.monster(BoitataFight.WISP_ID).can_be_rare,
			"fogo-fátuo existe")
	# Cone: quem está na frente leva, quem está atrás não.
	var origin := Vector3.ZERO
	var dir := Vector3(0, 0, -1)
	var point: Vector3 = origin + dir * 2.5
	_check(SkillCaster.in_shape(breath, origin, point, dir, Vector3(0.5, 0, -3), 1.0)
			and not SkillCaster.in_shape(breath, origin, point, dir, Vector3(0, 0, 3), 1.0), "acerto do cone")
