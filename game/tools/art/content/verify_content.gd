extends SceneTree
## Verificacao headless do conteudo do Agente C (docs/contracts-city-walk.md, "Testes obrigatorios").
##   godot --headless --path game --script res://tools/art/content/verify_content.gd
## Carrega tudo pelo autoload Content e confere: icones e folhas de sprite existem (e tamanhos),
## chaves de traducao existem em localization/content.csv, marcadores de NPC existem no mapa e ficam
## no navmesh, interactables so na camada 2, arquivos de audio do contrato existem.

const MAP_SCENE := "res://scenes/maps/city_awakening.tscn"
const FR := 96
const EXPECTED_ITEMS := [&"potion_hp_small", &"potion_hp_medium", &"potion_mp_small", &"potion_mp_medium",
	&"machete", &"short_sword", &"wooden_staff", &"ipe_wand", &"leather_shield", &"simple_tome", &"straw_hat",
	&"leather_jerkin", &"walking_boots", &"seed_necklace", &"ribbon_bracelet", &"spinning_leaf", &"ipe_flower_crown"]
const EXPECTED_NPCS := [&"master_brisa", &"master_orvalho", &"merchant", &"boatman", &"fruit_vendor",
	&"gate_guard", &"fisherman", &"curious_child"]
const SFX := ["sfx_ui_click", "sfx_ui_open", "sfx_ui_close", "sfx_buy", "sfx_sell", "sfx_equip", "sfx_pickup",
	"sfx_chat", "sfx_emote", "sfx_sit", "sfx_crystal_hum"]
const EMOTES := ["wave", "sit", "laugh", "cry", "angry", "heart"]

var failures := 0
var keys := {}


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, info: String = "") -> void:
	if not ok or OS.get_cmdline_user_args().has("--verbose"):
		print("%s %s %s" % ["PASS" if ok else "FAIL", label, info])
	if not ok:
		failures += 1


func _key(k: String, where: String) -> void:
	_check("chave %s (%s)" % [k, where], k != "" and keys.has(k))


func _sheet(path: String, cols: int, where: String) -> void:
	if not ResourceLoader.exists(path):
		_check("folha existe " + path, false, where)
		return
	var tex := load(path) as Texture2D
	_check("folha %s = %dx%d" % [path.get_file(), FR * cols, FR * 5], tex != null and tex.get_width() == FR * cols and tex.get_height() == FR * 5,
		"%s" % [tex.get_size() if tex else "null"])


## Arquivos de aparencia (ADENDO 1 do contrato) para o visual_id do item, nos dois corpos.
func _appearance(it: ItemDef) -> void:
	var slot := it.get_equip_slot()
	for body: String in ["male", "female"]:
		for anim: String in ["idle", "walk", "sit"]:
			var cols: int = {"idle": 4, "walk": 8, "sit": 1}[anim]
			if slot == &"body":
				_sheet("res://assets/characters/outfits/chr_%s_%s_%s.png" % [body, it.visual_id, anim], cols, it.id)
			else:
				_sheet("res://assets/equipment/%s/%s/%s_%s.png" % [slot, it.visual_id, body, anim], cols, it.id)
				if slot in [&"weapon", &"offhand"]:
					_sheet("res://assets/equipment/%s/%s/%s_%s_back.png" % [slot, it.visual_id, body, anim], cols, it.id)


func _run() -> void:
	var content: Node = root.get_node_or_null(^"Content")
	_check("autoload Content", content != null)
	if content == null:
		quit(1)
		return
	var csv := FileAccess.open("res://localization/content.csv", FileAccess.READ)
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() >= 2 and row[0] != "keys":
			_check("traducao nao vazia " + row[0], row[1].strip_edges() != "")
			keys[row[0]] = true
	# --- itens
	var items: Dictionary = content.call(&"all", &"items")
	for id: StringName in EXPECTED_ITEMS:
		_check("item " + id, items.has(id))
	for id: StringName in items:
		var it: ItemDef = items[id]
		_check("item id = arquivo " + id, it.id == id)
		_key(it.name_key, id)
		_key(it.desc_key, id)
		var ip := "res://assets/items/icons/icon_item_%s.png" % id
		_check("icone %s 32x32" % id, it.icon != null and it.icon.resource_path == ip and it.icon.get_size() == Vector2(32, 32))
		if it.type == ItemDef.ItemType.CONSUMABLE:
			_check("consumivel %s tem efeito e grupo" % id, it.use_effect.has(&"cooldown_group") and (it.use_effect.has(&"heal_hp") or it.use_effect.has(&"heal_mp")))
		_check("preco coerente " + id, it.sell_price >= 0 and (it.buy_price == 0 or it.sell_price < it.buy_price))
		_check("pilha coerente " + id, it.stackable == (it.max_stack > 1) and it.max_stack <= 99)
		if it.is_cosmetic:
			_check("cosmetico sem atributos " + id, it.stats.is_empty() and it.visual_id != &"")
		if it.visual_id != &"":
			_appearance(it)
		for k: StringName in it.stats:
			_check("stat valido %s.%s" % [id, k], k in [&"atk", &"matk", &"def", &"mdef", &"str", &"dex", &"vit", &"int", &"spi", &"luk"])
	# --- lojas
	var shop: ShopDef = content.call(&"shop", &"market")
	_check("loja market", shop != null)
	if shop:
		for i: StringName in shop.items:
			_check("loja vende item existente " + i, items.has(i) and (items[i] as ItemDef).buy_price > 0)
	# --- dialogos
	for id: StringName in (content.call(&"all", &"dialogues") as Dictionary):
		var d: DialogueDef = content.call(&"dialogue", id)
		_check("dialogo %s start" % id, d.get_node_by_id(d.start_node) != null)
		for n: DialogueNode in d.nodes:
			_key(n.text_key, "%s/%s" % [id, n.id])
			_check("no %s/%s tem opcoes" % [id, n.id], n.options.size() > 0)
			for o: DialogueOption in n.options:
				_key(o.text_key, "%s/%s" % [id, n.id])
				_check("destino %s -> %s" % [o.text_key, o.next_node], o.next_node == &"" or d.get_node_by_id(o.next_node) != null)
				_check("acao valida " + o.text_key, o.action in [&"", &"open_shop", &"close", &"give_item"])
				if o.action == &"give_item":
					_check("give_item com item existente " + o.text_key, items.has(o.action_args.get(&"item_id", &"")) and int(o.action_args.get(&"qty", 0)) > 0)
	# --- mapa + NPCs
	var map := (load(MAP_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(map)
	var nav: RID = map.call(&"get_navigation_map")
	var spawn: Vector3 = map.call(&"get_spawn_point")
	for i in 120:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav) > 0 and NavigationServer3D.map_get_closest_point(nav, spawn).distance_to(spawn) < 0.5:
			break
	var npcs: Dictionary = content.call(&"all", &"npcs")
	for id: StringName in EXPECTED_NPCS:
		_check("npc " + id, npcs.has(id))
	for id: StringName in npcs:
		var n: NpcDef = npcs[id]
		# NPCs de outros mapas (ex.: Mestres do Campo de Treino) têm verificador próprio
		# (tools/art/verify_training_field.tscn).
		if n.map_id != map.get(&"map_id"):
			continue
		_key(n.name_key, id)
		_check("npc %s tem dialogo" % id, n.dialogue != null)
		_sheet(n.sprite_base + "_idle.png", 4, id)
		_sheet(n.sprite_base + "_walk.png", 8, id)
		if n.routine == NpcDef.Routine.SIT:
			_sheet(n.sprite_base + "_sit.png", 1, id)
		var markers: Array[StringName] = [n.spawn_marker]
		markers.append_array(n.patrol_markers)
		if n.routine == NpcDef.Routine.PATROL:
			_check("npc %s patrulha com 2+ pontos" % id, n.patrol_markers.size() >= 2)
		for mk: StringName in markers:
			var m: Marker3D = map.call(&"get_npc_point", mk)
			_check("marcador NpcPoints/%s" % mk, m != null)
			if m:
				var p := m.global_position
				var c := NavigationServer3D.map_get_closest_point(nav, p)
				var path := NavigationServer3D.map_get_path(nav, spawn, p, true)
				_check("marcador %s no navmesh e alcancavel" % mk, c.distance_to(p) < 0.35 and path.size() > 0 and path[path.size() - 1].distance_to(p) < 0.5, "%s -> %s" % [p, c])
		if n.shop:
			var has_open := false
			for nd: DialogueNode in n.dialogue.nodes:
				for o: DialogueOption in nd.options:
					has_open = has_open or o.action == &"open_shop"
			_check("npc %s com loja tem opcao open_shop" % id, has_open)
	# --- interactables (camada 2)
	var inter: Dictionary = map.call(&"get_interactables")
	_check("6 interactables", inter.size() == 6, str(inter.keys()))
	for k: String in inter:
		var a := map.get_node("Interactables/" + k) as Area3D
		_check("interactable %s so na camada 2" % k, a != null and a.collision_layer == 2)
	for n: Node in map.find_children("*", "CollisionObject3D", true, false):
		var co := n as CollisionObject3D
		if co.collision_layer & 2:
			_check("camada 2 so em Interactables", co.get_parent().name == "Interactables", str(co.get_path()))
		if co.collision_layer & 1:
			_check("camada 1 so no chao com surface", co.get_parent().name == "Ground" and co.has_meta(&"surface"), str(co.get_path()))
	# --- audio
	var zones: Dictionary = content.call(&"all", &"audio")
	for z: Node in map.get_node("AudioZones").get_children():
		var zid := StringName("%s_%s" % [map.get(&"map_id"), z.get_meta(&"zone_id")])
		var def: AudioZoneDef = zones.get(zid)
		_check("AudioZoneDef " + zid, def != null)
		if def:
			_check("musica da zona " + zid, def.music != null)
			_check("ambiente da zona " + zid, def.ambience.size() > 0 and not def.ambience.has(null))
	var names: Array = SFX.duplicate()
	for s: String in ["stone", "wood", "grass", "sand"]:
		for i in range(1, 5):
			names.append("sfx_step_%s_%d" % [s, i])
	# arquivos de audio do contrato: o audio final passou para o coordenador (ElevenLabs); aqui so AVISO
	var missing: Array[String] = []
	for s: String in names:
		if not ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % s):
			missing.append(s)
	for m: String in ["mus_title", "mus_city_day", "mus_city_docks"]:
		if not ResourceLoader.exists("res://assets/audio/music/%s.ogg" % m):
			missing.append(m)
	if not missing.is_empty():
		print("AVISO audio do contrato ausente (dono: coordenador): ", missing)
	# --- viajante sit + emotes
	for b: String in ["male", "female"]:
		_sheet("res://assets/characters/chr_traveler_%s_sit.png" % b, 1, b)
	for e: String in EMOTES:
		var ep := "res://assets/ui/emotes/emote_%s.png" % e
		_check("emote " + e, ResourceLoader.exists(ep) and (load(ep) as Texture2D).get_width() in [24, 32])
	print("RESULT: %s (%d falha(s))" % ["OK" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
