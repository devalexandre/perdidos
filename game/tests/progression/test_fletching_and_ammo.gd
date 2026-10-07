extends Node
## 06/10/2026: Fazer Flechas (ofício do título inicial do arco), reabastecer a munição com o mesmo tipo do
## inventário quando a pilha equipada acaba e equipamento na barra de atalhos.
## Ofícios dos títulos (06/10/2026): receitas, título que concede, herança, quantidade por nível, fontes dos
## materiais, Unguento de Casco e Surrupiar (chance, uma vez por monstro, recusa chefe/atroz/provação).

## skill -> [título que concede, ramos que herdam, item feito, {material: qtd}, qtd nv1, nv3, nv10]
const CRAFTS: Dictionary = {
	&"blade_field_dressing": [&"sabia_blade_machete", [&"sabia_blade_aroeira", &"sabia_blade_jaguar"],
			&"potion_hp_small", {&"spinning_leaf": 3}, 2, 3, 6],
	&"arcane_bottle_light": [&"sabia_arcane_firefly", [&"sabia_arcane_crystal", &"sabia_arcane_boitata"],
			&"potion_mp_small", {&"firefly_light": 3}, 2, 3, 6],
	&"bow_poison_tips": [&"sabia_bow_brejo", [], &"poison_arrow", {&"simple_arrow": 10, &"venom_gland": 1}, 10, 11, 14],
	&"bow_feathering": [&"sabia_bow_gaviao", [], &"iron_arrow", {&"simple_arrow": 10, &"harpy_feather": 1}, 10, 11, 14],
	&"hybrid_ember_tips": [&"sabia_hybrid_ember", [], &"fire_arrow", {&"simple_arrow": 10, &"eternal_ember": 1}, 10, 11, 14],
	&"support_garrafada": [&"sabia_support_root", [&"sabia_support_buriti", &"sabia_support_matinta"],
			&"potion_hp_medium", {&"pequi_root": 1, &"wild_honeycomb": 1}, 2, 3, 6],
	&"tank_shell_salve": [&"sabia_tank_jabuti", [&"sabia_tank_anta", &"sabia_tank_mapinguari"],
			&"shell_salve", {&"armadillo_shell": 2, &"thick_leather": 1}, 1, 1, 4],
}
## Materiais que hoje não caem de monstro posicionado em mapa nem são vendidos (avisados ao dono).
## Materiais ainda sem monstro posicionado (07/10/2026: a fauna peçonhenta deu fonte a todos).
const NO_SOURCE_YET: Array[StringName] = []
const MAP_DIR: String = "res://scenes/maps/"

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	print("--- TEST FLETCHING AND AMMO ---")
	_test_fletching_skill()
	_test_ammo_refill()
	_test_hotbar_items()
	_test_title_crafts()
	_test_shell_salve()
	_test_pilfer()
	print("test_fletching_and_ammo: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String, detail: Variant = null) -> bool:
	_checks += 1
	print(("ok   " if condition else "FAIL ") + description + ("" if detail == null else " %s" % str(detail)))
	if not condition:
		_failures += 1
	return condition


func _test_fletching_skill() -> void:
	var def: SkillDef = Content.skill(&"bow_fletching")
	_check(def != null and def.effect == SkillDef.Effect.CRAFT and def.target_type == SkillDef.TargetType.SELF,
			"Fazer Flechas existe (CRAFT, em si mesmo)")
	if def == null:
		return
	_check(Content.item(StringName(str(def.extra["craft_item"]))) != null
			and Content.item(&"taquara_cane") != null and (def.extra["materials"] as Dictionary).has(&"taquara_cane"),
			"faz Flecha Simples com Vara de Taquara")
	_check(SkillCaster.craft_qty(def, 1) == 10 and SkillCaster.craft_qty(def, 5) == 18,
			"10 flechas no nível 1, +2 por nível", [SkillCaster.craft_qty(def, 1), SkillCaster.craft_qty(def, 5)])
	_check(not SkillCaster.is_offensive(def), "ofício não é ofensivo (pode na cidade)")
	_check(&"bow_fletching" in TitleService.bonus_skills_for_title(&"sabia_bow_cerrado"),
			"título inicial do arco concede Fazer Flechas")
	_check(&"bow_fletching" in TitleService.bonus_skills_for_title(&"sabia_bow_brejo"),
			"ramos do arco herdam o ofício")
	_check(&"bow_fletching" not in TitleService.skills_for_title(&"sabia_bow_cerrado"),
			"o ofício fica fora da árvore de 5")
	var whirl: MonsterDef = Content.monster(&"prank_whirlwind")
	var drops_it: bool = false
	for st: MonsterStage in whirl.stages:
		if st.stage == 1:
			for d: DropEntry in st.drops:
				drops_it = drops_it or (d.item_id == &"taquara_cane" and d.chance >= 0.3)
	_check(drops_it, "Redemoinho Arteiro (comum dos Campos) solta Vara de Taquara com frequência")
	var shop: ShopDef = Content.shop(&"market")
	_check(shop != null and &"taquara_cane" in shop.available_items(0), "Mercado vende a Vara de Taquara")


func _test_ammo_refill() -> void:
	var c := CharacterData.create_new("Arqueira", &"female")
	c.inventory.add(&"simple_arrow", 2)
	var slot: int = -1
	for i: int in c.inventory.size():
		var st: ItemStack = c.inventory.get_slot(i)
		if st != null and st.item_id == &"simple_arrow":
			slot = i
	c.equipment.set_slot(Equipment.OFFHAND, c.inventory.get_slot(slot))
	c.inventory.replace_at(slot, null)
	c.inventory.add(&"simple_arrow", 30)
	c.inventory.add(&"fire_arrow", 5)
	_check(c.consume_ammo(1) and c.ammo_refilled.is_empty() and c.equipment.get_ammo().qty == 1, "gasta 1 flecha")
	_check(c.consume_ammo(1) and c.ammo_refilled == &"simple_arrow", "pilha acabou: puxou a próxima do mesmo tipo")
	var ammo: ItemStack = c.equipment.get_ammo()
	_check(ammo != null and ammo.item_id == &"simple_arrow" and ammo.qty == 30
			and c.inventory.count(&"simple_arrow") == 0 and c.inventory.count(&"fire_arrow") == 5,
			"30 flechas simples equipadas; as de fogo (outro tipo) ficam no inventário",
			[ammo.qty if ammo != null else 0, c.inventory.count(&"fire_arrow")])
	for i: int in 30:
		c.consume_ammo(1)
	_check(c.equipment.get_ammo() == null and c.inventory.count(&"fire_arrow") == 5,
			"sem mais do mesmo tipo: fica sem munição (não troca de tipo sozinho)")


func _test_hotbar_items() -> void:
	_check(Content.item(&"potion_hp_small").is_hotbar_item(), "poção vai para a barra")
	_check(Content.item(&"machete").is_hotbar_item() and Content.item(&"simple_bow").is_hotbar_item(),
			"armas vão para a barra (usar = equipar/trocar)")
	_check(Content.item(&"simple_arrow").is_hotbar_item(), "flechas vão para a barra (usar = equipar)")
	_check(not Content.item(&"taquara_cane").is_hotbar_item(), "material não vai para a barra")


func _test_title_crafts() -> void:
	for id: StringName in CRAFTS:
		var spec: Array = CRAFTS[id]
		var def: SkillDef = Content.skill(id)
		if not _check(def != null and def.effect == SkillDef.Effect.CRAFT and def.target_type == SkillDef.TargetType.SELF,
				"%s existe (CRAFT, em si mesmo)" % id):
			continue
		var mats: Dictionary = def.extra.get(SkillCaster.X_MATERIALS, {})
		var same_mats: bool = mats.size() == (spec[3] as Dictionary).size()
		for m: Variant in spec[3]:
			same_mats = same_mats and int(mats.get(m, 0)) == int(spec[3][m]) and Content.item(m) != null
		_check(StringName(str(def.extra[SkillCaster.X_CRAFT_ITEM])) == spec[2] and Content.item(spec[2]) != null
				and same_mats, "%s: receita %s -> %s" % [id, spec[3], spec[2]])
		var q: Array = [SkillCaster.craft_qty(def, 1), SkillCaster.craft_qty(def, 3), SkillCaster.craft_qty(def, 10)]
		_check(q == [spec[4], spec[5], spec[6]], "%s: quantidade por nível (1, 3, 10)" % id, q)
		_check(not SkillCaster.is_offensive(def), "%s: ofício não é ofensivo" % id)
		var title: StringName = spec[0]
		_check(id in (Content.title(title).bonus_skills as Array) and id in TitleService.bonus_skills_for_title(title)
				and id not in TitleService.skills_for_title(title), "%s: concedido por %s, fora da árvore de 5" % [id, title])
		for branch: StringName in spec[1]:
			_check(id in TitleService.bonus_skills_for_title(branch), "%s: o ramo %s herda" % [id, branch])
		_check(ResourceLoader.exists("res://assets/skills/%s.png" % id), "%s: ícone" % id)
		_check(SkillFx.recipe_for(def) == &"craft"
				and SkillFxSprite.has_piece(StringName(String(id) + SkillFx.CRAFT_PIECE_SUFFIX)), "%s: efeito de ofício" % id)
		for m: Variant in spec[3]:
			var src: bool = _has_source(StringName(str(m)))
			if StringName(str(m)) in NO_SOURCE_YET:
				_check(not src, "%s: '%s' segue sem fonte posicionada (avisado; tirar de NO_SOURCE_YET quando tiver)" % [id, m])
			else:
				_check(src, "%s: '%s' cai de monstro posicionado ou é vendido" % [id, m])
	# Herança dos ramos do arco: ficam com Fazer Flechas e ganham o próprio.
	for pair: Array in [[&"sabia_bow_brejo", &"bow_poison_tips"], [&"sabia_bow_gaviao", &"bow_feathering"]]:
		var got: Array[StringName] = TitleService.bonus_skills_for_title(pair[0])
		_check(&"bow_fletching" in got and pair[1] in got, "%s: Fazer Flechas + o próprio ofício" % pair[0], got)
	var jaguar: Array[StringName] = TitleService.bonus_skills_for_title(&"sabia_blade_jaguar")
	_check(&"blade_field_dressing" in jaguar and &"blade_pilfer" in jaguar, "Garra da Onça: Curativo + Surrupiar", jaguar)
	_check(&"blade_pilfer" not in TitleService.bonus_skills_for_title(&"sabia_blade_aroeira"),
			"Surrupiar é só da Onça (a Aroeira não tem)")
	# Títulos de combinação não herdam o ofício dos títulos exigidos para eles.
	for pair2: Array in [[&"sabia_hybrid_ember", &"hybrid_ember_tips"], [&"sabia_support_root", &"support_garrafada"],
			[&"sabia_tank_jabuti", &"tank_shell_salve"]]:
		var got2: Array[StringName] = TitleService.bonus_skills_for_title(pair2[0])
		_check(got2.size() == 1 and got2[0] == pair2[1], "%s: só o próprio ofício (não herda dos exigidos)" % pair2[0], got2)


func _test_shell_salve() -> void:
	var d: ItemDef = Content.item(&"shell_salve")
	if not _check(d != null and d.type == ItemDef.ItemType.CONSUMABLE, "Unguento de Casco existe (consumível)"):
		return
	_check(float(d.use_effect.get(ItemService.EFFECT_DEF_BUFF_PCT, 0.0)) > 0.0
			and float(d.use_effect.get(ItemService.EFFECT_BUFF_SEC, 0.0)) > 0.0, "dá defesa temporária", d.use_effect)
	_check(not CastTiming.is_instant_item(d) and CastTiming.item_group(d) == &"shell_salve",
			"tem conjuração e recarga própria (não é poção)")
	_check(d.buy_price == 0 and d.sell_price > 0 and d.icon != null, "não se compra; vende; tem ícone")


func _test_pilfer() -> void:
	var def: SkillDef = Content.skill(&"blade_pilfer")
	if not _check(def != null and def.effect == SkillDef.Effect.STEAL and def.target_type == SkillDef.TargetType.SINGLE,
			"Surrupiar existe (STEAL, alvo único)"):
		return
	_check(SkillDef.Effect.STEAL == SkillDef.Effect.size() - 1 and SkillDef.Effect.CRAFT == 23,
			"STEAL no fim do enum (os .tres usam o índice)")
	_check(SkillCaster.is_offensive(def) and def.range_cells <= 2.0, "ofensivo (só onde há combate) e de perto")
	var b: float = float(CharacterStats.BASE_ATTRIBUTE)
	var c1: float = SkillCaster.steal_chance(def, 1, 0, 0)
	var c10: float = SkillCaster.steal_chance(def, 10, 0, 0)
	_check(is_equal_approx(c1, 0.2) and is_equal_approx(c10, 0.65), "chance 20% + 5% por nível", [c1, c10])
	var base_stats: float = SkillCaster.steal_chance(def, 1, int(b), int(b))
	var high: float = SkillCaster.steal_chance(def, 1, 40, 20)
	_check(high > base_stats and base_stats > c1, "DES e SOR aumentam a chance", [base_stats, high])
	_check(SkillCaster.steal_chance(def, 10, 999, 999) <= SkillCaster.STEAL_MAX_CHANCE, "chance tem teto")
	_check(&"blade_pilfer" in TitleService.bonus_skills_for_title(&"sabia_blade_jaguar")
			and ResourceLoader.exists("res://assets/skills/blade_pilfer.png")
			and SkillFx.recipe_for(def) == &"steal" and SkillFxSprite.has_piece(SkillFx.STEAL_PIECE),
			"título da Onça concede; ícone e efeito (brilho no alvo)")
	# Recusas e "uma vez por monstro" (MonsterBrain sem cena: só os campos que a regra lê).
	var whirl: MonsterDef = Content.monster(&"prank_whirlwind")
	var brain := MonsterBrain.new()
	brain.def = whirl
	brain.stage = _stage(whirl, 1)
	_check(CombatService.steal_block_reason(brain) == "", "monstro comum vivo: pode surrupiar")
	brain.stolen_by = 7
	_check(CombatService.steal_block_reason(brain) == CombatService.STEAL_ALREADY, "uma vez por monstro")
	brain.stolen_by = 0
	brain.owner_peer = 7
	_check(CombatService.steal_block_reason(brain) == CombatService.STEAL_TRIAL, "monstro de provação recusa")
	brain.owner_peer = 0
	brain.stage = _stage(whirl, CombatRules.STAGE_BOSS)
	_check(CombatService.steal_block_reason(brain) == CombatService.STEAL_BOSS, "chefe recusa")
	brain.stage = _stage(whirl, 1)
	brain.atroz = true
	_check(CombatService.steal_block_reason(brain) == CombatService.STEAL_BOSS, "forma atroz recusa")
	brain.atroz = false
	brain.state = MonsterBrain.State.DEAD
	_check(CombatService.steal_block_reason(brain) == CombatService.STEAL_INVALID, "morto não")
	_check(CombatService.steal_block_reason(null) == CombatService.STEAL_INVALID, "sem monstro não")
	brain.free()
	# Rola UMA linha da tabela do estágio, com peso pela chance da linha.
	var a := DropEntry.new()
	a.item_id = &"spinning_leaf"
	a.chance = 0.75
	var z := DropEntry.new()
	z.item_id = &"red_cap"
	z.chance = 0.25
	var table: Array[DropEntry] = [a, z]
	_check(CombatService.steal_pick(table, 0.0) == a and CombatService.steal_pick(table, 0.74) == a
			and CombatService.steal_pick(table, 0.76) == z and CombatService.steal_pick(table, 0.999) == z,
			"sorteio pela chance de cada linha (75/25)")
	_check(CombatService.steal_pick([] as Array[DropEntry], 0.5) == null, "tabela vazia: nada")


func _stage(def: MonsterDef, n: int) -> MonsterStage:
	for st: MonsterStage in def.stages:
		if st.stage == n:
			return st
	return def.stages[0]


## Fonte acessível: vendido numa loja ou cai (em qualquer estágio) de monstro posicionado num mapa.
func _has_source(item_id: StringName) -> bool:
	for r: Resource in Content.all(&"shops").values():
		var shop: ShopDef = r as ShopDef
		if shop != null and item_id in shop.available_items(0):
			return true
	var placed: Dictionary = {}
	for f: String in ResourceLoader.list_directory(MAP_DIR):
		if not f.ends_with(".tscn"):
			continue
		var txt: String = FileAccess.get_file_as_string(MAP_DIR + f)
		for r2: Resource in Content.all(&"monsters").values():
			var m: MonsterDef = r2 as MonsterDef
			if m != null and txt.contains('monster_id = &"%s"' % m.id):
				placed[m.id] = true
	for mid: Variant in placed:
		for st: MonsterStage in Content.monster(StringName(str(mid))).stages:
			for d: DropEntry in st.drops:
				if d != null and d.item_id == item_id:
					return true
	return false
