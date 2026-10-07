extends Node
## Agente R (GDD §6.2, 27/09/2026): save antigo (formato 1, sem Sorte) ganha SOR = 5 ao carregar;
## save novo grava e relê a SOR; a Sorte entra nos valores derivados e na distribuição de pontos.
## Rodar: godot --headless --path game res://tests/progression/test_save_migration.tscn

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	var old_save: Dictionary = {"format": 1, "name": "Antigo", "body": "male", "level": 7,
			"attributes": {"str": 12, "dex": 9, "vit": 8, "int": 5, "spi": 6}, "hp": 50, "mp": 20,
			"stars": 30, "inventory": [], "equipment": {}, "once_flags": [], "left_training": true}
	var c: CharacterData = CharacterData.from_save(old_save)
	_check(c != null, "save antigo carrega")
	if c != null:
		_check(c.base_attributes.get(&"luk", -1) == CharacterStats.BASE_ATTRIBUTE, "SOR ausente = 5",
				c.base_attributes)
		_check(c.base_attributes[&"str"] == 12 and c.base_attributes[&"spi"] == 6, "outros atributos mantidos")
		_check(c.inventory.count(&"potion_hp_small") == 100 and c.inventory.count(&"potion_mp_small") == 100
				and c.inventory.count(&"return_scroll") == 3 and c.once_flags.has(CharacterData.STARTING_KIT_FLAG),
				"kit atualizado no save antigo")
		var gloves: ItemDef = Content.item(&"leather_gloves")
		var stats_without_gloves: Dictionary = c.compute_stats()
		c.equipment.set_slot(Equipment.GLOVES, ItemStack.create(&"leather_gloves", 1))
		var stats_with_gloves: Dictionary = c.compute_stats()
		_check(gloves != null and Equipment.GLOVES in Equipment.SLOTS
				and Equipment.slots_for(gloves).has(Equipment.GLOVES), "luvas usam o slot de equipamento próprio")
		_check(int(stats_with_gloves[CharacterStats.K_DEF]) == int(stats_without_gloves[CharacterStats.K_DEF]) + 2,
				"bônus de DEF das luvas entra nos atributos")
		_check(int(c.compute_stats().get(&"luk", -1)) == CharacterStats.BASE_ATTRIBUTE, "SOR nos valores derivados")
		var saved: Dictionary = c.to_save()
		_check(int(saved.get("format", 0)) == CharacterData.SAVE_FORMAT_VERSION and CharacterData.SAVE_FORMAT_VERSION >= 2,
				"save regravado no formato novo", saved.get("format"))
		_check(int((saved["attributes"] as Dictionary).get("luk", -1)) == CharacterStats.BASE_ATTRIBUTE,
				"SOR gravada no save", saved["attributes"])
		c.base_attributes[&"luk"] = 11
		_check(c.grant_causo(&"werewolf_son"), "primeiro Causo da história é concedido")
		_check(not c.grant_causo(&"werewolf_son"), "a mesma história não concede Causos duas vezes")
		_check(c.record_story_clue(&"lobisomem_arc", &"ferreiro_bites"), "primeira pista oral é registrada")
		_check(not c.record_story_clue(&"lobisomem_arc", &"ferreiro_bites"), "a mesma pista não duplica")
		_check(not c.choose_story_route(&"lobisomem_arc", &"pact"), "rota bloqueada sem três pistas")
		c.record_story_clue(&"lobisomem_arc", &"market_shadow")
		c.record_story_clue(&"lobisomem_arc", &"fisherman_howl")
		_check(c.story_clue_count(&"lobisomem_arc") == 3 and c.causos == CharacterData.CAUSO_POINTS_STORY,
			"pistas são contadas separadamente dos Causos")
		_check(c.story_clue_count(&"lobisomem_arc") == 3 and c.choose_story_route(&"lobisomem_arc", &"pact"),
			"rota pode ser escolhida após três pistas")
		_check(c.record_story_observation(&"lobisomem_arc", "night-1") == 1
			and not c.story_route_locked(&"lobisomem_arc"), "primeira observação mantém rotas abertas")
		_check(c.record_story_observation(&"lobisomem_arc", "night-1") == 1, "mesma noite não duplica observação")
		_check(c.record_story_observation(&"lobisomem_arc", "night-2") == 2
			and c.story_route_locked(&"lobisomem_arc")
			and not c.choose_story_route(&"lobisomem_arc", &"healer"), "segunda observação fecha rotas alternativas")
		_check(c.record_story_observation(&"lobisomem_arc", "night-3") == 3
			and c.record_story_observation(&"lobisomem_arc", "night-4") == 3,
			"observações do Pacto param em três")
		var again: CharacterData = CharacterData.from_save(JSON.parse_string(JSON.stringify(c.to_save())))
		_check(again != null and again.inventory.count(&"potion_hp_small") == 100
				and again.inventory.count(&"potion_mp_small") == 100, "kit não duplica ao carregar save migrado")
		var saved_gloves: ItemStack = again.equipment.get_slot(Equipment.GLOVES) if again != null else null
		_check(saved_gloves != null and saved_gloves.item_id == &"leather_gloves",
				"luvas equipadas sobrevivem ao round-trip do save", saved_gloves.item_id if saved_gloves != null else "")
		_check(again != null and again.base_attributes[&"luk"] == 11, "SOR relida do JSON")
		_check(again != null and again.causos == CharacterData.CAUSO_POINTS_STORY and not again.grant_causo(&"werewolf_son"),
			"Causos e trava da história persistem")
		_check(again != null and again.story_clue_count(&"lobisomem_arc") == 3,
			"pista e trava de duplicação persistem no save")
		_check(again != null and again.story_clue_count(&"lobisomem_arc") == 3
			and again.story_observation_count(&"lobisomem_arc") == 3
			and again.story_route(&"lobisomem_arc") == &"pact"
			and again.story_route_locked(&"lobisomem_arc"), "rota e observações persistem no save")
		again.complete_story_arc(&"lobisomem_arc", &"pacted")
		_check(again.story_arc_completed(&"lobisomem_arc")
			and again.story_arc_ending(&"lobisomem_arc") == &"pacted"
			and not again.choose_story_route(&"lobisomem_arc", &"hunter"),
			"desfecho persiste e impede trocar a rota concluída")
	_check(CharacterData.causos_rank_index(0) == 0 and CharacterData.causos_rank_index(2) == 1
			and CharacterData.causos_rank_index(5) == 2 and CharacterData.causos_rank_index(30) == 5,
			"limiares das molduras de Causos (renome)")
	_check(CharacterData.causos_to_next(3) == 2 and CharacterData.causos_to_next(40) == 0, "pontos para o próximo renome")
	var deeds: CharacterData = CharacterData.create_new("Feitos", &"male")
	_check(deeds.grant_deed("boss:stone_armadillo", CharacterData.CAUSO_POINTS_BOSS)
			and not deeds.grant_deed("boss:stone_armadillo", CharacterData.CAUSO_POINTS_BOSS)
			and deeds.causos == CharacterData.CAUSO_POINTS_BOSS, "feito de chefe conta uma vez por espécie")
	var legacy: Dictionary = deeds.to_save()
	legacy["causos"] = 1
	legacy["once_flags"] = ["causo_story:werewolf_son"]
	var migrated: CharacterData = CharacterData.from_save(legacy)
	_check(migrated != null and migrated.causos == CharacterData.CAUSO_POINTS_STORY
			and migrated.once_flags.has(CharacterData.CAUSOS_FAME_FLAG), "save antigo: 1 Causo por história vira renome")
	var fresh: CharacterData = CharacterData.create_new("Novo", &"female")
	_check(fresh.base_attributes.get(&"luk", -1) == CharacterStats.BASE_ATTRIBUTE, "personagem novo com SOR 5")
	_check(fresh.inventory.count(&"potion_hp_small") == 100 and fresh.inventory.count(&"potion_mp_small") == 100
				and fresh.once_flags.has(CharacterData.STARTING_KIT_FLAG), "personagem novo nasce com kit de 100 poções")
	var version_1_kit: Dictionary = old_save.duplicate(true)
	var old_kit := Inventory.new(CharacterData.INVENTORY_SIZE)
	old_kit.add(&"potion_hp_small", 30)
	old_kit.add(&"potion_mp_small", 30)
	old_kit.add(&"return_scroll", 3)
	version_1_kit["inventory"] = old_kit.to_save()
	version_1_kit["once_flags"] = ["starting_kit_v1"]
	_test_kit_migration_is_saved(version_1_kit)
	_check(&"luk" in CharacterStats.ATTRIBUTES and CharacterStats.ATTRIBUTES.size() == 6, "6 atributos (FOR DES VIT INT ESP SOR)")
	print("test_save_migration: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL %s %s" % [what, str(detail) if detail != null else ""])

func _test_kit_migration_is_saved(legacy: Dictionary) -> void:
	var dir: String = "/tmp/perdidos_kit_migration_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var store := JsonCharacterStore.new(dir)
	var path: String = store.path_for("Antigo")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "save de teste abre para migração")
		return
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated: CharacterData = store.load_character("Antigo")
	_check(migrated != null and not migrated.starting_kit_migration_pending,
			"store grava a migração do kit ao carregar o personagem")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(saved is Dictionary and CharacterData.STARTING_KIT_FLAG in (saved as Dictionary).get("once_flags", []),
			"save migrado persiste a marca anti-duplicação")
	var reloaded: CharacterData = store.load_character("Antigo")
	_check(reloaded != null and reloaded.inventory.count(&"potion_hp_small") == 100
			and reloaded.inventory.count(&"potion_mp_small") == 100, "reload do store não repete nem perde o kit")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
