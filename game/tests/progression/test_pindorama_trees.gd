extends Node
## Testes unitários da Terra de Pindorama v0.4 (TITULOS-E-SKILLS.md §3): dados das 16 árvores (5 skills
## cada, pré-requisitos, lições, anciãos, títulos, NPCs, textos), herança de título, filtro de
## variante das quests, título de combinação só por quest, atributo do ATQ pela arma e as mecânicas
## genéricas do StatusEffects (reforço/enfraquecimento, prender/atordoar com imunidade, crítico
## garantido, esquiva, dano recebido, não cair abaixo de 1, cura recebida, limpeza).
## Rodar: godot --headless --path game res://tests/progression/test_pindorama_trees.tscn

const TREES: Array[StringName] = [&"pindorama_blade_machete", &"pindorama_blade_aroeira", &"pindorama_blade_jaguar",
	&"pindorama_arcane_firefly", &"pindorama_arcane_crystal", &"pindorama_arcane_boitata", &"pindorama_bow_cerrado",
	&"pindorama_bow_brejo", &"pindorama_bow_gaviao", &"pindorama_hybrid_ember", &"pindorama_support_root",
	&"pindorama_support_buriti", &"pindorama_support_matinta", &"pindorama_tank_jabuti", &"pindorama_tank_anta",
	&"pindorama_tank_mapinguari"]
const EXISTING: Array[StringName] = [&"blade_firm_strike", &"blade_charge", &"blade_steel_spin",
	&"blade_clearing_sweep", &"blade_iron_stance", &"blade_horizon_cut", &"arcane_spark",
	&"arcane_frost_burst", &"arcane_creeping_flame", &"arcane_will_o_wisp", &"arcane_barrier", &"arcane_star_fall"]
## Ensinadas por outra quest (treino do Campo e anciãos): sem lição própria.
const TAUGHT_ELSEWHERE: Array[StringName] = [&"blade_firm_strike", &"arcane_spark", &"hybrid_spark_blade",
	&"support_bottle_brew", &"tank_shell_knock"]
const COMBO_TITLES: Array[StringName] = [&"pindorama_hybrid_ember", &"pindorama_support_root", &"pindorama_tank_jabuti"]
const NEW_NPCS: Array[StringName] = [&"master_taquari", &"elder_ze_ferreiro", &"elder_aninha", &"elder_tiao"]
const ELDER_QUESTS: Array[StringName] = [&"elder_ze_steel_song", &"elder_aninha_root_fire", &"elder_tiao_sky_feast"]
## Itens raros do agente de monstros (só referenciados aqui).
const RARE_ITEMS: Array[StringName] = [&"eternal_ember", &"pequi_root", &"ancient_shell_shard"]
const OUTFITS: Dictionary = {&"pindorama_bow_cerrado": &"title_cerrado", &"pindorama_bow_brejo": &"title_brejo",
	&"pindorama_bow_gaviao": &"title_gaviao", &"pindorama_support_root": &"title_root",
	&"pindorama_support_buriti": &"title_buriti", &"pindorama_support_matinta": &"title_matinta",
	&"pindorama_tank_jabuti": &"title_jabuti", &"pindorama_tank_anta": &"title_anta",
	&"pindorama_tank_mapinguari": &"title_mapinguari"}
const CITY_SCENE: String = "res://scenes/maps/city_awakening.tscn"
const ENTITY_SCENE: String = "res://scenes/entities/net_entity.tscn"

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_test_data()
	_test_heritage_and_prereqs()
	_test_title_skill_bundles()
	_test_title_quest_scaling()
	_test_title_challenges()
	_test_quest_need_save()
	_test_variant_filter()
	_test_combo_titles()
	_test_weapon_attribute()
	_test_status_mechanics()
	_test_skill_params()
	print("test_pindorama_trees: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL %s %s" % [what, str(detail) if detail != null else ""])


func _tr_ok(key: String) -> bool:
	return not key.is_empty() and TranslationServer.translate(key) != key


# ---------------------------------------------------------------- dados

func _test_data() -> void:
	var total: int = 0
	var new_count: int = 0
	var bad_order: Array = []
	var bad_prereq: Array = []
	var bad_text: Array = []
	for t: StringName in TREES:
		var skills: Array[SkillDef] = SkillTree.tree_skills(t)
		total += skills.size()
		var orders: Array = skills.map(func(d: SkillDef) -> int: return d.tree_order)
		if orders != [1, 2, 3, 4, 5]:
			bad_order.append([t, orders])
		var td: TitleDef = Content.title(t)
		for d: SkillDef in skills:
			if d.id not in EXISTING:
				new_count += 1
			for r: StringName in d.required_skill_levels:
				var rd: SkillDef = Content.skill(r)
				if rd == null or not (rd.tree_title == t or (td != null and rd.tree_title == td.parent_title)):
					bad_prereq.append([d.id, r])
			for k: String in [d.name_key, d.desc_key]:
				if not _tr_ok(k):
					bad_text.append(k)
	_check(total == 80, "16 árvores × 5 skills = 80", total)
	_check(new_count == 68, "68 skills novas", new_count)
	_check(bad_order.is_empty(), "cada árvore com ordem 1..5", bad_order)
	_check(bad_prereq.is_empty(), "pré-requisitos na mesma árvore (ou na do pai)", bad_prereq)
	_check(bad_text.is_empty(), "nomes e descrições das skills traduzidos", bad_text.slice(0, 8))
	var bow_ok: bool = true
	for d: SkillDef in SkillTree.tree_skills(&"pindorama_bow_cerrado") + SkillTree.tree_skills(&"pindorama_bow_brejo") \
			+ SkillTree.tree_skills(&"pindorama_bow_gaviao"):
		bow_ok = bow_ok and d.requires_bow and d.school == &"bow"
	_check(bow_ok, "escola do arco exige arco")
	# Lições: uma por skill, do Mestre da árvore, escondidas até cumprir título e pré-requisitos.
	var missing_lessons: Array = []
	var bad_steps: Array = []
	for t: StringName in TREES:
		for d: SkillDef in SkillTree.tree_skills(t):
			if d.id in TAUGHT_ELSEWHERE:
				continue
			var q: QuestDef = Content.quest(StringName("lesson_%s" % d.id))
			if q == null or q.reward_skill != d.id or Content.npc(q.giver_npc) == null \
					or q.giver_npc != Content.title(t).master_npc or not q.hidden_until_eligible:
				missing_lessons.append(d.id)
				continue
			for s: QuestStep in q.steps:
				var ok: bool = (s.type == QuestStep.StepType.KILL and Content.monster(s.target_id) != null) \
						or (s.type == QuestStep.StepType.COLLECT and Content.item(s.target_id) != null)
				if not ok or not _tr_ok(s.text_key):
					bad_steps.append([q.id, s.target_id])
			for k: String in [q.name_key, q.offer_text_key, q.progress_text_key, q.complete_text_key,
					q.option_text_key, q.desc_key]:
				if not _tr_ok(k):
					bad_steps.append([q.id, k])
	_check(missing_lessons.is_empty(), "uma lição por skill com o Mestre da árvore", missing_lessons)
	_check(bad_steps.is_empty(), "lições com monstros/itens de Pindorama e textos", bad_steps.slice(0, 8))
	# Anciãos = sub-histórias: causo falado, itens raros, chefe, causo falado, atroz, provação; renome 3 e
	# Causo próprio; recompensa = título de combinação + skill 1.
	for qid: StringName in ELDER_QUESTS:
		var q: QuestDef = Content.quest(qid)
		var ok: bool = q != null and q.steps.size() == 6 and q.steps[0].type == QuestStep.StepType.TALK \
				and _tr_ok(q.steps[0].lore_text_key) and _tr_ok(q.steps[3].lore_text_key) \
				and Content.npc(q.steps[0].target_id) != null and Content.npc(q.steps[3].target_id) != null \
				and q.steps[1].type == QuestStep.StepType.COLLECT \
				and q.steps[1].target_id in RARE_ITEMS and q.steps[2].variant == &"boss" \
				and q.steps[4].variant == &"atroz" and q.steps[5].type == QuestStep.StepType.TRIAL \
				and q.required_causos == 3 and not q.reward_causo_id.is_empty() \
				and q.reward_title in COMBO_TITLES and Content.title(q.reward_title).quest_only \
				and Content.skill(q.reward_skill) != null and Content.skill(q.reward_skill).tree_order == 1 \
				and Content.skill(q.reward_skill).tree_title == q.reward_title
		_check(ok, "quest do ancião %s" % qid)
	var tiao: QuestDef = Content.quest(&"elder_tiao_sky_feast")
	_check(tiao != null and tiao.steps[2].distinct_species and tiao.steps[2].count == 2, "Tião: 2 chefes de espécies diferentes")
	var aninha: QuestDef = Content.quest(&"elder_aninha_root_fire")
	_check(aninha != null and aninha.steps[2].no_death and aninha.steps[5].trial_mode == &"protect" and aninha.steps[5].protect_target == &"pequi_seedling" and aninha.steps[5].protect_count == 3 and Content.monster(&"pequi_seedling") != null,
			"Aninha: chefe sem cair e provação de proteger 3 mudas")
	_check(Content.monster(&"trial_twin_shield_puppet") != null, "fantoche de dois escudos (provação do Seu Zé)")
	# Títulos.
	for t: StringName in OUTFITS:
		var td: TitleDef = Content.title(t)
		_check(td != null and td.outfit_id == OUTFITS[t] and td.cloth_colors.size() == 2 and _tr_ok(td.name_key)
				and _tr_ok(td.desc_key), "título %s (outfit, cores de reserva, textos)" % t)
	for t: StringName in COMBO_TITLES:
		var td2: TitleDef = Content.title(t)
		_check(td2 != null and td2.quest_only and td2.required_titles.size() >= 2, "combinação %s só por quest" % t)
	# NPCs novos no Porto, com marcador no mapa e diálogo.
	var city: String = FileAccess.get_file_as_string(CITY_SCENE)
	for n: StringName in NEW_NPCS:
		var nd: NpcDef = Content.npc(n)
		_check(nd != null and nd.map_id == &"city_awakening" and nd.dialogue != null and _tr_ok(nd.name_key)
				and city.contains('[node name="%s" type="Marker3D" parent="NpcPoints"' % n)
				and not nd.fallback_sprite_base.is_empty() and ResourceLoader.exists(nd.resolved_sprite_base() + "_idle.png"),
				"NPC %s (marcador, diálogo, visual)" % n)
	# Anciãos (§3.2): lenda em balões; sem os títulos, "Volte quando..."; com os títulos, a oferta.
	for pair: Array in [[&"elder_ze_ferreiro", &"elder_ze_steel_song", "duas"], [&"elder_aninha", &"elder_aninha_root_fire", "três"],
			[&"elder_tiao", &"elder_tiao_sky_feast", "três"]]:
		var dlg: DialogueDef = Content.npc(pair[0]).dialogue
		var need: DialogueNode = dlg.get_node_by_id(&"need")
		var back: DialogueNode = dlg.get_node_by_id(&"come_back")
		var offer_ok: bool = false
		var locked_ok: bool = false
		for o: DialogueOption in need.options if need != null else []:
			offer_ok = offer_ok or (o.action == QuestService.ACTION_OFFER and o.conditions.get(QuestService.COND_QUEST_AVAILABLE) == pair[1])
			locked_ok = locked_ok or (o.next_node == &"come_back" and o.conditions.get(QuestService.COND_QUEST_LOCKED) == pair[1])
		_check(dlg.get_node_by_id(&"legend_1") != null and dlg.get_node_by_id(&"legend_2") != null and offer_ok and locked_ok
				and back != null and TranslationServer.translate(back.text_key).contains("renome 3"),
				"lenda do ancião %s (balões, oferta com os títulos, 'Volte quando...')" % pair[0], [offer_ok, locked_ok, TranslationServer.translate(back.text_key) if back != null else ""])
	# Arco.
	var bow: ItemDef = Content.item(&"simple_bow")
	_check(bow != null and bow.weapon_kind == ItemDef.WeaponKind.BOW and bow.two_handed
			and bow.scaling_attribute == &"dex" and bow.visual_id == &"simple_bow" and _tr_ok(bow.name_key),
			"arco simples (duas mãos, DES, visual simple_bow)")
	var shop: ShopDef = Content.shop(&"market")
	_check(shop != null and &"simple_bow" in shop.items, "arco à venda no mercado do Porto")


# ---------------------------------------------------------------- herança e pré-requisitos

func _test_heritage_and_prereqs() -> void:
	_check(SkillTree.holds_title([&"pindorama_blade_aroeira"], &"pindorama_blade_machete"), "ramo vale pelo pai (herança)")
	_check(not SkillTree.holds_title([&"pindorama_blade_machete"], &"pindorama_blade_aroeira"), "pai não vale pelo ramo")
	_check(SkillTree.holds_title({&"pindorama_support_buriti": 1}, &"pindorama_support_root"), "herança com dicionário de títulos")
	var trees: Array[StringName] = SkillTree.visible_trees([&"pindorama_bow_gaviao"])
	_check(trees == [&"pindorama_bow_cerrado", &"pindorama_bow_gaviao"], "árvore do pai aparece com o ramo", trees)
	var charge: SkillDef = Content.skill(&"blade_charge")
	_check(charge.missing_prerequisites({&"blade_firm_strike": 2}).size() == 1
			and charge.missing_prerequisites({"blade_firm_strike": 3}).is_empty(), "Investida pede Golpe Firme 3")
	var gates: Array = [Content.skill(&"blade_iron_stance"), Content.skill(&"bow_mud_skin"),
			Content.skill(&"support_broadleaf_tea"), Content.skill(&"tank_fury")]
	var gates_ok: bool = true
	for g: SkillDef in gates:
		var parent: StringName = Content.title(g.tree_title).parent_title
		gates_ok = gates_ok and g.tree_order == 1 and g.exclusive_to_title == parent
	_check(gates_ok, "porta do ramo se aprende com o título pai")


func _test_title_skill_bundles() -> void:
	var root := TitleService.skills_for_title(&"pindorama_blade_machete")
	var branch := TitleService.skills_for_title(&"pindorama_blade_aroeira")
	_check(root.size() == 5 and root.has(&"blade_firm_strike"), "título base concede a árvore de cinco skills", root)
	_check(branch.size() == 10 and branch.has(&"blade_firm_strike") and branch.has(&"blade_iron_stance"),
		"título de ramo concede a árvore própria e a herdada", branch)
	var combo := TitleService.skills_for_title(&"pindorama_support_root")
	_check(combo.size() == 5 and combo.has(&"support_bottle_brew"), "título de combinação concede sua árvore", combo)


func _test_title_quest_scaling() -> void:
	var kill := QuestStep.new()
	kill.type = QuestStep.StepType.KILL
	kill.count = 5
	_check(QuestService.scaled_title_step_count(kill, 0) == 5 and QuestService.scaled_title_step_count(kill, 1) == 8
			and QuestService.scaled_title_step_count(kill, 3) == 13, "abates crescem 50% por título global")
	var collect := QuestStep.new()
	collect.type = QuestStep.StepType.COLLECT
	collect.count = 2
	_check(QuestService.scaled_title_step_count(collect, 0) == 2 and QuestService.scaled_title_step_count(collect, 2) == 4,
		"coletas crescem 50% por título global")
	var titles := ProgressionData.new()
	titles.titles[&"pindorama_blade_machete"] = 1
	titles.titles[&"pindorama_arcane_firefly"] = 1
	_check(QuestService.earned_title_count(titles) == 2, "escala global conta títulos reais, não Viajante")
	kill.variant = &"boss"
	_check(QuestService.scaled_title_step_count(kill, 5) == 5, "abates de chefe não viram repetição de chefe")


func _test_title_challenges() -> void:
	var rewards: Dictionary[StringName, QuestDef] = {}
	var collected: Dictionary[StringName, bool] = {}
	var valid_steps := true
	var avoids_reserved_mule := true
	for resource: Resource in Content.all(&"quests").values():
		var q := resource as QuestDef
		if q == null or q.reward_title.is_empty():
			continue
		rewards[q.reward_title] = q
		for step: QuestStep in q.steps:
			if step.target_id == &"ember_mule":
				avoids_reserved_mule = false
			if step.type == QuestStep.StepType.KILL:
				valid_steps = valid_steps and (step.target_id.is_empty() or step.target_id == QuestService.ANY_SPECIES
						or Content.monster(step.target_id) != null)
			elif step.type == QuestStep.StepType.COLLECT:
				valid_steps = valid_steps and Content.item(step.target_id) != null
				collected[step.target_id] = true
	for title_id: StringName in TREES:
		_check(rewards.has(title_id), "quest de conquista do título %s" % title_id)
	_check(valid_steps, "objetivos das quests de título referenciam conteúdo válido")
	_check(collected.has(&"spinning_leaf") and collected.has(&"firefly_light")
			and collected.has(&"armadillo_shell"), "quests de título variam entre coleta de itens específicos", collected.keys())
	_check(avoids_reserved_mule, "Mula sem Cabeça fica reservada fora das quests de título")
	var character := CharacterData.create_new("TitleAutoTest", &"male")
	for skill_id: StringName in Content.title(&"pindorama_blade_machete").required_skills:
		character.progression.skills[skill_id] = 1
	var session := PlayerSession.new(0, null, character)
	var earned := TitleService.new(null).recalc(session)
	_check(earned.is_empty() and not character.progression.has_title(&"pindorama_blade_machete"),
		"skills sozinhas não concedem títulos")


func _test_quest_need_save() -> void:
	var data := ProgressionData.new()
	data.quests[&"title_scale_test"] = {ProgressionData.Q_STEP: 1, ProgressionData.Q_COUNT: 2,
		ProgressionData.Q_NEEDS: [9, 4]}
	var restored := ProgressionData.new()
	restored.load_save(data.to_save())
	_check(restored.quests[&"title_scale_test"].get(ProgressionData.Q_NEEDS, []) == [9, 4],
		"metas escaladas permanecem estáveis no save")


# ---------------------------------------------------------------- filtro de variante

func _test_variant_filter() -> void:
	var s := QuestStep.new()
	s.type = QuestStep.StepType.KILL
	s.target_id = &"stone_armadillo"
	_check(QuestService.kill_matches(s, &"stone_armadillo", {}), "KILL comum conta")
	_check(not QuestService.kill_matches(s, &"prank_whirlwind", {}), "outra espécie não conta")
	s.variant = &"boss"
	_check(not QuestService.kill_matches(s, &"stone_armadillo", {"stage": 1}), "chefe: estágio 1 não conta")
	_check(QuestService.kill_matches(s, &"stone_armadillo", {"stage": 3}), "chefe: estágio 3 conta")
	s.variant = &"rare"
	_check(not QuestService.kill_matches(s, &"stone_armadillo", {"rare": false}), "raro: comum não conta")
	_check(QuestService.kill_matches(s, &"stone_armadillo", {"rare": true}), "raro conta")
	s.variant = &"atroz"
	s.target_id = &""
	_check(not QuestService.kill_matches(s, &"enchanted_firefly", {"stage": 3, "atroz": false}), "atroz: chefe de dia não conta")
	_check(QuestService.kill_matches(s, &"enchanted_firefly", {"stage": 3, "atroz": true}), "atroz de qualquer espécie conta")
	s.variant = &"boss"
	s.no_death = true
	_check(not QuestService.kill_matches(s, &"prank_whirlwind", {"stage": 3, "no_death": false}), "sem cair: caiu não conta")
	_check(QuestService.kill_matches(s, &"prank_whirlwind", {"stage": 3, "no_death": true}), "sem cair: conta")


# ---------------------------------------------------------------- títulos de combinação

func _test_combo_titles() -> void:
	for title_id: StringName in COMBO_TITLES:
		var q: QuestDef = null
		for resource: Resource in Content.all(&"quests").values():
			var candidate := resource as QuestDef
			if candidate != null and candidate.reward_title == title_id:
				q = candidate
				break
		_check(q != null and Content.title(title_id).quest_only, "combinação %s exige sua quest" % title_id)


# ---------------------------------------------------------------- atributo do ATQ pela arma

func _atk_with(weapon: StringName) -> Dictionary:
	var eq := Equipment.new()
	if not weapon.is_empty():
		eq.set_slot(&"weapon", ItemStack.create(weapon, 1))
	var base: Dictionary[StringName, int] = CharacterStats.base_attributes()
	base[&"str"] = 20
	base[&"dex"] = 30
	base[&"int"] = 40
	return CharacterStats.compute(10, base, eq)


func _test_weapon_attribute() -> void:
	var none: Dictionary = _atk_with(&"")
	var machete: Dictionary = _atk_with(&"machete")
	var bow: Dictionary = _atk_with(&"simple_bow")
	var staff: Dictionary = _atk_with(&"wooden_staff")
	var idx: Callable = func(a: StringName) -> int: return CharacterStats.ATTRIBUTES.find(a)
	_check(int(none[&"atk"]) == 20 * 2 + 10 and int(none[CharacterStats.K_ATK_ATTR]) == idx.call(&"str"),
			"sem arma: ATQ de FOR", none[&"atk"])
	_check(int(machete[&"atk"]) == 8 + 20 * 2 + 10 and int(machete[CharacterStats.K_ATK_ATTR]) == idx.call(&"str"),
			"facão: ATQ de FOR", machete[&"atk"])
	_check(int(bow[&"atk"]) == 7 + (30 + 1) * 2 + 10 and int(bow[CharacterStats.K_ATK_ATTR]) == idx.call(&"dex"),
			"arco: ATQ de DES", bow[&"atk"])
	var staff_def: ItemDef = Content.item(&"wooden_staff")
	_check(int(staff[CharacterStats.K_ATK_ATTR]) == idx.call(&"int")
			and int(staff[&"atk"]) == int(staff_def.stats.get(&"atk", 0)) + (40 + int(staff_def.stats.get(&"int", 0))) * 2 + 10,
			"cajado: ATQ de INT", staff[&"atk"])
	_check(int(bow[&"matk"]) == int(machete[&"matk"]), "MATQ continua de INT (não muda com a arma)")
	_check(int(bow[&"atk"]) != int(machete[&"atk"]), "trocar a arma troca o atributo do ATQ")


# ---------------------------------------------------------------- mecânicas (StatusEffects)

func _entity(id: int, kind: StringName) -> NetEntity:
	var e: NetEntity = (load(ENTITY_SCENE) as PackedScene).instantiate() as NetEntity
	e.server_setup(id, kind, "t", &"t", &"test_instance", Vector3.ZERO)
	return e


func _test_status_mechanics() -> void:
	var st := StatusEffects.new(null, null)
	var player: NetEntity = _entity(4000001, &"player")
	var mon: NetEntity = _entity(4000002, &"monster")
	# Reforço e enfraquecimento somam; DEF por BUFF e DEBUFF.
	st.add(player, StatusEffects.Kind.BUFF, 5.0, 0.0, &"tank_fury", player, &"", {&"atk_pct": 0.4, &"def_pct": -0.3})
	st.add(player, StatusEffects.Kind.BUFF, 5.0, 0.0, &"tank_hard_shell", player, &"", {&"def_pct": 0.3})
	_check(is_equal_approx(st.mod(player, &"atk_pct"), 0.4) and is_equal_approx(st.def_multiplier(player), 1.0),
			"BUFF soma ATQ e DEF", [st.mod(player, &"atk_pct"), st.def_multiplier(player)])
	var atk: Dictionary = {&"atk": 100, &"matk": 50, &"luk": 0}
	var dfn: Dictionary = {&"def": 10, &"mdef": 10}
	var r: Dictionary = st.pre_hit(player, mon, &"physical", &"basic_attack", atk, dfn)
	_check(int(atk[&"atk"]) == 140 and int(atk[&"matk"]) == 50, "pre_hit aplica +40% de ATQ", atk)
	# Flecha Sem Desvio ignora 40% da DEF (lido do SkillDef pelo source_id).
	var dfn2: Dictionary = {&"def": 100, &"mdef": 0}
	st.pre_hit(player, mon, &"physical", &"bow_true_arrow", {&"atk": 10}, dfn2)
	_check(int(dfn2[&"def"]) == 60, "ignorar 40% da DEF", dfn2)
	# Flecha de Aviso: +10% de dano recebido.
	st.add(mon, StatusEffects.Kind.DEBUFF, 5.0, 0.0, &"bow_warning_arrow", player, &"", {&"dmg_taken_pct": 0.1})
	r = st.pre_hit(player, mon, &"physical", &"basic_attack", {&"atk": 10}, {&"def": 0})
	_check(is_equal_approx(float(r["dmg_mult"]), 1.1), "dano recebido +10%", r)
	# Mira Certeira: 3 críticos garantidos e acaba.
	st.add(player, StatusEffects.Kind.BUFF, 15.0, 0.0, &"bow_sure_aim", player, &"", {}, 3)
	var crits: Array = []
	for i: int in 4:
		crits.append(float(st.pre_hit(player, mon, &"physical", &"basic_attack", {&"atk": 1, &"luk": 0}, {&"def": 0})["crit_override"]))
	_check(crits.slice(0, 3) == [1.0, 1.0, 1.0] and crits[3] < 1.0, "3 críticos garantidos", crits)
	# Esquiva de 100% força o erro; mágico não se esquiva.
	st.add(player, StatusEffects.Kind.BUFF, 5.0, 0.0, &"bow_mud_skin", player, &"", {&"evade": 1.0})
	_check(bool(st.pre_hit(mon, player, &"physical", &"skill_x", {&"atk": 1}, {&"def": 0})["force_miss"]), "esquiva evita golpe físico")
	_check(not bool(st.pre_hit(mon, player, &"magic", &"skill_x", {&"matk": 1}, {&"mdef": 0})["force_miss"]), "magia não se esquiva")
	# Imunidade a controle (Aguentar Firme) bloqueia atordoar e prender.
	st.add(player, StatusEffects.Kind.BUFF, 5.0, 0.0, &"tank_stand_firm", player, &"", {&"cc_immune": 1})
	var stunned: bool = st.add(player, StatusEffects.Kind.STUN, 2.0, 0.0, &"x", mon)
	var rooted: bool = st.add(player, StatusEffects.Kind.ROOT, 2.0, 0.0, &"x", mon)
	_check(not stunned and not rooted and not st.is_stunned(player) and not st.is_rooted(player), "imune a atordoar e prender")
	_check(st.add(mon, StatusEffects.Kind.ROOT, 2.0, 0.0, &"blade_root_grip", player) and st.is_rooted(mon), "prender funciona sem imunidade")
	# Raiz que Segura.
	_check(st.lethal_guard(player, 500, 120) == 500, "sem proteção o golpe mata")
	st.add(player, StatusEffects.Kind.BUFF, 3.0, 0.0, &"support_holding_root", player, &"", {&"death_ward": 1})
	_check(st.lethal_guard(player, 500, 120) == 119 and st.lethal_guard(player, 50, 120) == 50, "não cai abaixo de 1")
	# Fumaça Amarga: −50% de cura recebida.
	st.add(mon, StatusEffects.Kind.DEBUFF, 3.0, 0.0, &"support_bitter_smoke", player, &"", {&"heal_received_pct": -0.5})
	_check(is_equal_approx(st.heal_multiplier(mon), 0.5), "cura recebida −50%")
	# Emplastro tira os negativos (prender, enfraquecer) e mantém os positivos.
	var removed: int = st.cleanse(mon)
	_check(removed >= 2 and not st.is_rooted(mon) and is_equal_approx(st.heal_multiplier(mon), 1.0), "limpar efeitos negativos", removed)
	# Invisível: some ao atacar.
	st.add(player, StatusEffects.Kind.STEALTH, 10.0, 0.0, &"bow_mud_hide", player)
	_check(st.is_hidden(player), "invisível para monstros")
	st.pre_hit(player, mon, &"physical", &"bow_ambush_shot", {&"atk": 1}, {&"def": 0})
	_check(not st.is_hidden(player), "atacar quebra a invisibilidade")
	# Alcance a mais (Olho Parado).
	st.add(player, StatusEffects.Kind.BUFF, 10.0, 0.0, &"bow_still_eye", player, &"", {&"range_cells": 2})
	_check(is_equal_approx(st.range_bonus_cells(player), 2.0), "alcance +2 células")
	player.free()
	mon.free()


func _test_skill_params() -> void:
	var sharpen: SkillDef = Content.skill(&"blade_sharpen")
	_check(is_equal_approx(SkillCaster.param(sharpen, &"atk_pct", 3), 0.24), "parâmetro por nível (+2% ATQ/nível)")
	var mods: Dictionary = SkillCaster.mods_for(sharpen, 1)
	_check(mods.has(&"atk_pct") and mods.has(&"crit") and not mods.has(&"duration_per_level"), "mods do reforço", mods)
	var smoke: SkillDef = Content.skill(&"support_bitter_smoke")
	var zm: Dictionary = SkillCaster.zone_mods_for(smoke, 1)
	_check(is_equal_approx(float(zm.get(&"heal_received_pct", 0.0)), -0.5), "área no chão com enfraquecimento", zm)
	_check(not SkillCaster.is_offensive(Content.skill(&"support_herb_tea"))
			and SkillCaster.is_offensive(Content.skill(&"support_omen")), "cura não é ofensiva; agouro é")
	_check(SkillCaster.damage_kind_of(Content.skill(&"bow_thorn_arrow")) == &"physical"
			and SkillCaster.damage_kind_of(Content.skill(&"hybrid_sparks")) == &"magic"
			and SkillCaster.damage_kind_of(Content.skill(&"tank_heavy_claws")) == &"physical",
			"tipo de dano por escola/extra")
