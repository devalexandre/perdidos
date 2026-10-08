extends Node
## Migração dos ids renomeados (nação Sabiá -> Pindorama, 08/10/2026; docs/mundo/renomeacao-pindorama.md).
## Monta um save no formato ANTIGO numa pasta temporária (nunca a pasta de saves real), carrega pelo
## JsonCharacterStore e confere mapa, nação, títulos, quests, itens, companheiro, montaria, waystone e
## a regravação no formato novo (idempotente). Também a tabela LegacyIds e a aparência vinda da rede.
## Opcional: --legacy-dir=/pasta/com/cópias/*.json carrega cópias de saves e confere que nada antigo sobra.
## Rodar: godot --headless --path game res://tests/server/test_legacy_ids.tscn

const OLD_NATION: String = "sabia" # id antigo da nação (este teste está na lista de exceções do grep de controle)
var _checks: int = 0
var _failures: int = 0
var _dir: String = ""


func _ready() -> void:
	_dir = "user://legacy_ids_test_%d/" % OS.get_process_id()
	_test_table()
	_test_old_save()
	_test_network_and_cache()
	_test_copies()
	_cleanup()
	print("test_legacy_ids: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _old(id_new: String) -> String:
	return id_new.replace("pindorama", OLD_NATION)


func _test_table() -> void:
	_check(LegacyIds.id(OLD_NATION) == "pindorama", "nação antiga -> pindorama")
	_check(LegacyIds.id(_old("fields_pindorama_buriti")) == "fields_pindorama_buriti", "mapa antigo -> novo")
	_check(LegacyIds.id("fields_pindorama") == "fields_pindorama", "id novo é idempotente")
	_check(LegacyIds.id("city_awakening") == "city_awakening", "id sem relação passa direto")
	_check(LegacyIds.id(_old("causo_deed:title:pindorama_bow_gaviao")) == "causo_deed:title:pindorama_bow_gaviao",
			"marca composta com ':'")
	_check(LegacyIds.id(_old("waystone_save:fields_pindorama")) == "waystone_save:fields_pindorama", "marca de waystone")
	_check(LegacyIds.id(_old("pindorama_future_thing")) == "pindorama_future_thing", "fora da tabela: segmento troca")
	_check(LegacyIds.id("Sabia Teste") == "Sabia Teste", "texto com maiúscula/espaço (nome) não é id")
	_check(LegacyIds.sname(StringName(_old("pindorama_companion_harpy"))) == &"pindorama_companion_harpy", "StringName")
	for old_id: String in LegacyIds.RENAMED:
		var new_id: String = LegacyIds.RENAMED[old_id]
		_check(not new_id.contains(OLD_NATION) and LegacyIds.id(new_id) == new_id, "tabela sem id antigo no destino: " + new_id)


func _old_save() -> Dictionary:
	var blade: Dictionary = {"item": _old("pindorama_long_blade"), "qty": 1, "protected": false}
	var bound: Dictionary = {"item": "potion_hp_small", "qty": 5, "protected": false, "bound_zone": _old("fields_pindorama")}
	var inv: Array = [blade.duplicate(), bound]
	for i: int in CharacterData.INVENTORY_SIZE - inv.size():
		inv.append({})
	var nick: String = "sabia" # apelido do jogador em minúsculas: não pode virar "pindorama"
	return {
		"format": 3, "name": "Sabia Teste", "body": "female", "level": 12,
		"attributes": {"str": 9, "dex": 14, "vit": 8, "int": 5, "spi": 6, "luk": 7},
		"hp": 80, "mp": 30, "stars": 777, "causos": 4,
		"companions": {"owned": [_old("pindorama_companion_harpy")], "active": _old("pindorama_companion_harpy"),
				"names": {_old("pindorama_companion_harpy"): nick},
				"progress": {_old("pindorama_companion_harpy"): {"level": 6, "xp": 40}}},
		"mounts": {"owned": [_old("pindorama_mount_donkey")]},
		"inventory": inv,
		"equipment": {"weapon": blade.duplicate()},
		"once_flags": ["starting_kit_v2", "causos_fame_v1", _old("causo_deed:title:pindorama_bow_gaviao"),
				_old("waystone:fields_pindorama"), "waystone:city_awakening",
				_old("waystone_save:fields_pindorama_crossroads")],
		"left_training": true,
		"home_map": _old("fields_pindorama"),
		"last_city": "city_awakening",
		"appearance": {"skin": 1, "hair_style": "f_bob", "hair_color": 2, "eye_color": 0,
				"nationality": OLD_NATION, "title_look": _old("pindorama_bow_gaviao")},
		"progression": {"xp": 10, "total_xp": 900, "attribute_points": 0, "skill_points": 1,
				"skills": {"bow_true_arrow": 2},
				"hotbar": [_old("pindorama_long_blade"), "bow_true_arrow", "", "", "", "", "", "", "", ""],
				"titles": {"traveler": 1790000000, _old("pindorama_bow_cerrado"): 1790000100,
						_old("pindorama_bow_gaviao"): 1790000200},
				"displayed_title": _old("pindorama_bow_gaviao"),
				"quests": {_old("pindorama_bow_brejo_title"): {"step": 1, "count": 2}},
				"quests_done": {_old("pindorama_bow_gaviao_title"): 1790000150}},
	}


func _test_old_save() -> void:
	var store := JsonCharacterStore.new(_dir)
	var old: Dictionary = _old_save()
	var f := FileAccess.open(store.path_for("Sabia Teste"), FileAccess.WRITE)
	f.store_string(JSON.stringify(old, "\t"))
	f.close()
	var c: CharacterData = store.load_character("Sabia Teste")
	_check(c != null, "save antigo carrega")
	if c == null:
		return
	_check(c.char_name == "Sabia Teste", "nome do personagem intacto", c.char_name)
	_check(c.home_map == &"fields_pindorama" and MapTransfer.map_exists(c.home_map), "mapa de entrada existe", c.home_map)
	_check(c.custom_appearance.get(&"nationality") == &"pindorama", "nacionalidade", c.custom_appearance)
	_check(c.custom_appearance.get(&"title_look") == &"pindorama_bow_gaviao", "roupa de título", c.custom_appearance)
	var p: ProgressionData = c.progression
	_check(p.has_title(&"pindorama_bow_gaviao") and p.has_title(&"pindorama_bow_cerrado")
			and Content.title(&"pindorama_bow_gaviao") != null, "títulos migrados e existentes", p.titles.keys())
	_check(p.displayed_title == &"pindorama_bow_gaviao", "título exibido mantido", p.displayed_title)
	_check(p.quests.has(&"pindorama_bow_brejo_title") and Content.quest(&"pindorama_bow_brejo_title") != null
			and int(p.quests[&"pindorama_bow_brejo_title"]["count"]) == 2, "quest ativa com progresso", p.quests)
	_check(p.quests_done.has(&"pindorama_bow_gaviao_title"), "quest concluída", p.quests_done.keys())
	_check(p.skill_level(&"bow_true_arrow") == 2, "skills mantidas")
	_check(p.hotbar[0] == &"pindorama_long_blade", "barra 1–0", p.hotbar)
	_check(c.inventory.count(&"pindorama_long_blade") == 1 and Content.item(&"pindorama_long_blade") != null,
			"item renomeado não some do inventário")
	var eq: ItemStack = c.equipment.get_slot(Equipment.WEAPON)
	_check(eq != null and eq.item_id == &"pindorama_long_blade", "arma equipada mantida")
	var bound_ok: bool = false
	for s: Variant in c.inventory.to_save():
		if s is Dictionary and str(s.get("bound_zone", "")) == "fields_pindorama":
			bound_ok = true
	_check(bound_ok, "item preso à zona aponta o mapa novo")
	_check(c.companions_owned.has(&"pindorama_companion_harpy") and c.companion_active == &"pindorama_companion_harpy",
			"companheiro e ativo", c.companions_owned)
	_check(str(c.companion_names.get("pindorama_companion_harpy", "")) == "sabia", "apelido do jogador intacto",
			c.companion_names)
	_check(int((c.companion_progress.get("pindorama_companion_harpy", {}) as Dictionary).get("level", 0)) == 6,
			"nível do companheiro", c.companion_progress)
	_check(c.mounts_owned.has(&"pindorama_mount_donkey"), "montaria", c.mounts_owned)
	_check(WaystoneService.knows(c, &"fields_pindorama") and WaystoneService.saved_city(c) == &"fields_pindorama_crossroads",
			"waystone conhecida e ponto salvo", c.once_flags.keys())
	_check(c.once_flags.has("causo_deed:title:pindorama_bow_gaviao"), "marca de Causo do título")
	_check(c.stars == 777 and c.level == 12 and c.causos == 4, "estrelas, nível e Causos")
	# Regravado no formato novo já no carregamento.
	var text: String = FileAccess.get_file_as_string(store.path_for("Sabia Teste"))
	_check(text.contains('"pindorama_companion_harpy": "sabia"'), "apelido gravado como o jogador escreveu")
	text = text.replace('"pindorama_companion_harpy": "sabia"', "") # o apelido não conta como id antigo
	var leftovers: int = text.count('"' + OLD_NATION) + text.count("_" + OLD_NATION) + text.count(":" + OLD_NATION)
	_check(leftovers == 0 and text.contains("fields_pindorama"), "arquivo regravado sem ids antigos", leftovers)
	_check(not c.legacy_ids_migration_pending, "marca de migração limpa depois de gravar")
	var again: CharacterData = store.load_character("Sabia Teste")
	_check(again != null and not again.legacy_ids_migration_pending and again.to_save() == c.to_save(),
			"segunda carga não muda nada (idempotente)")


func _test_network_and_cache() -> void:
	var opts: CustomizationOptions = CustomizationOptions.get_default()
	_check(opts != null and opts.sanitize({&"body": &"male", &"nationality": OLD_NATION})[&"nationality"] == &"pindorama",
			"aparência de cliente antigo: nação migrada")
	_check(opts.nationalities.has(&"pindorama") and not opts.nationalities.has(StringName(OLD_NATION)), "lista de nações")
	var slot: Dictionary = LegacyIds.migrate({"name": "Sabia", "appearance": {&"title_look": StringName(_old("pindorama_tank_anta"))}})
	_check(slot["name"] == "Sabia" and slot["appearance"][&"title_look"] == &"pindorama_tank_anta", "cache de slots do cliente")
	var cos: Dictionary = LegacyIds.migrate({_old("cosmetic_broche_pindorama"): true, "straw_hat": false})
	_check(cos.has("cosmetic_broche_pindorama") and cos.size() == 2, "cosméticos do painel", cos)


## Cópias de saves reais (opcional): nada antigo sobra depois de carregar e regravar.
func _test_copies() -> void:
	var src: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--legacy-dir="):
			src = a.trim_prefix("--legacy-dir=")
	if src.is_empty():
		return
	var store := JsonCharacterStore.new(src)
	for file: String in DirAccess.get_files_at(src):
		if not file.ends_with(".json") or file == "character_owners.json":
			continue
		var before: Variant = JSON.parse_string(FileAccess.get_file_as_string(src.path_join(file)))
		if not (before is Dictionary) or typeof(before.get("name")) != TYPE_STRING:
			continue
		var c: CharacterData = store.load_character(str(before["name"]))
		var text: String = FileAccess.get_file_as_string(store.path_for(str(before["name"])))
		var left: int = text.count('"' + OLD_NATION) + text.count("_" + OLD_NATION) + text.count(":" + OLD_NATION)
		var titles_before: int = (before.get("progression", {}).get("titles", {}) as Dictionary).size()
		var ok: bool = c != null and left == 0 and c.progression.titles.size() == titles_before \
				and (c.home_map.is_empty() or MapTransfer.map_exists(c.home_map))
		_check(ok, "cópia %s: carrega, mapa %s existe, %d títulos, sem id antigo" % [file,
				String(c.home_map) if c != null else "?", titles_before], left)


func _cleanup() -> void:
	for file: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir + file)
	DirAccess.remove_absolute(_dir)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if ok:
		print("  [ok] " + what)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [what, "" if detail == null else str(detail)])
