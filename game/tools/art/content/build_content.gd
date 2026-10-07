extends SceneTree
## Gera data/{items,shops,dialogues,npcs,audio}/*.tres a partir de tools/art/content/content_src.json.
## Reexecutavel. Rodar (depois de build_content.py e de um --import para os PNG/OGG existirem):
##   godot --headless --path game --script res://tools/art/content/build_content.gd
## Chaves de traducao: ver build_content.py (mesma convencao).

const SRC := "res://tools/art/content/content_src.json"
const MAP_ID := &"city_awakening"


func _initialize() -> void:
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SRC))
	var errs := 0
	for dir: String in ["items", "shops", "dialogues", "npcs", "audio"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/" + dir))
	for it: Dictionary in src["items"]:
		errs += _save(_item(it), "res://data/items/%s.tres" % it["id"])
	var shops := {}
	for sh: Dictionary in src["shops"]:
		var s := ShopDef.new()
		s.id = StringName(sh["id"])
		var arr: Array[StringName] = []
		for i: String in sh["items"]:
			arr.append(StringName(i))
		s.items = arr
		var p := "res://data/shops/%s.tres" % sh["id"]
		errs += _save(s, p)
		shops[sh["id"]] = p
	var dlgs: Dictionary = src["dialogues"]
	for npc_id: String in dlgs:
		errs += _save(_dialogue(npc_id, dlgs[npc_id]), "res://data/dialogues/%s.tres" % npc_id)
	for n: Dictionary in src["npcs"]:
		var d := NpcDef.new()
		d.id = StringName(n["id"])
		d.name_key = "NPC_%s_NAME" % String(n["id"]).to_upper()
		d.sprite_base = "res://assets/npcs/npc_%s" % n["id"]
		d.map_id = MAP_ID
		d.spawn_marker = StringName(n["id"])
		d.routine = NpcDef.Routine[n["routine"]]
		d.wander_radius = n.get("wander_radius", 4.0)
		var pm: Array[StringName] = []
		for m: String in n.get("patrol", []):
			pm.append(StringName(m))
		d.patrol_markers = pm
		d.move_speed = n.get("speed", 2.0)
		if dlgs.has(n["id"]):
			d.dialogue = load("res://data/dialogues/%s.tres" % n["id"]) as DialogueDef
		if n.has("shop"):
			d.shop = load(shops[n["shop"]]) as ShopDef
		errs += _save(d, "res://data/npcs/%s.tres" % n["id"])
	for z: Dictionary in src["audio_zones"]:
		var a := AudioZoneDef.new()
		a.id = StringName(z["id"])
		var mp := "res://assets/audio/music/%s.ogg" % z["music"]
		if ResourceLoader.exists(mp):
			a.music = load(mp) as AudioStream
		else:
			push_warning("musica ausente: " + mp)
		var amb: Array[AudioStream] = []
		for name: String in z["ambience"]:
			var ap := "res://assets/audio/sfx/%s.ogg" % name
			if ResourceLoader.exists(ap):
				amb.append(load(ap) as AudioStream)
			else:
				push_warning("ambiente ausente: " + ap)
		a.ambience = amb
		a.music_volume_db = z.get("music_volume_db", 0.0)
		a.priority = z.get("priority", 0)
		errs += _save(a, "res://data/audio/%s.tres" % z["id"])
	print("build_content: ", "OK" if errs == 0 else "%d erro(s)" % errs)
	quit(0 if errs == 0 else 1)


func _save(res: Resource, path: String) -> int:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("falhou salvar %s: %d" % [path, err])
		return 1
	res.take_over_path(path)
	return 0


func _item(it: Dictionary) -> ItemDef:
	var d := ItemDef.new()
	var id: String = it["id"]
	d.id = StringName(id)
	d.name_key = "ITEM_%s_NAME" % id.to_upper()
	d.desc_key = "ITEM_%s_DESC" % id.to_upper()
	var icon_path := "res://assets/items/icons/icon_item_%s.png" % id
	d.icon = load(icon_path) as Texture2D
	if d.icon == null:
		push_error("icone ausente: " + icon_path)
	d.type = ItemDef.ItemType[it["type"]]
	d.weapon_kind = ItemDef.WeaponKind[it.get("kind", "NONE")]
	d.rarity = ItemDef.Rarity[it.get("rarity", "COMMON")]
	d.max_stack = int(it.get("stack", 1))
	d.stackable = d.max_stack > 1
	d.buy_price = int(it.get("buy", 0))
	d.sell_price = int(it.get("sell", 0))
	var st: Dictionary[StringName, int] = {}
	var sd: Dictionary = it.get("stats", {})
	for k: String in sd:
		st[StringName(k)] = int(sd[k])
	d.stats = st
	var ue: Dictionary[StringName, Variant] = {}
	var ud: Dictionary = it.get("use", {})
	for k: String in ud:
		ue[StringName(k)] = StringName(ud[k]) if ud[k] is String else int(ud[k])
	d.use_effect = ue
	d.visual_id = StringName(it.get("visual_id", ""))
	d.is_cosmetic = it.get("cosmetic", false)
	return d


func _dialogue(npc_id: String, nodes: Dictionary) -> DialogueDef:
	var d := DialogueDef.new()
	d.id = StringName(npc_id)
	d.start_node = &"start"
	var arr: Array[DialogueNode] = []
	for nid: String in nodes:
		var n := DialogueNode.new()
		n.id = StringName(nid)
		var base := "DLG_%s_%s" % [npc_id.to_upper(), nid.to_upper()]
		n.text_key = base
		var opts: Array[DialogueOption] = []
		var i := 0
		for o: Array in nodes[nid]["options"]:
			var op := DialogueOption.new()
			op.text_key = "%s_OPT%d" % [base, i]
			op.next_node = StringName(o[1])
			op.action = StringName(o[2]) if o.size() > 2 else (&"close" if String(o[1]) == "" else &"")
			if o.size() > 3:
				var args: Dictionary[StringName, Variant] = {}
				for k: String in (o[3] as Dictionary):
					var v: Variant = o[3][k]
					args[StringName(k)] = StringName(v) if v is String else (int(v) if v is float else v)
				op.action_args = args
			opts.append(op)
			i += 1
		n.options = opts
		arr.append(n)
	d.nodes = arr
	return d
