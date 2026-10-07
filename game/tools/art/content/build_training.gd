extends SceneTree
## Gera os dados do Campo de Treino (agente W) a partir de tools/art/content/training_src.json:
##   data/monsters/<id>.tres, data/npcs/<id>.tres, data/dialogues/<id>.tres, data/zones/<map_id>.tres,
##   data/items/<id>.tres (drops novos).
## Reexecutavel. Rodar depois de build_training.py:
##   godot --headless --path game --script res://tools/art/content/build_training.gd
## Folhas dos monstros: res://assets/monsters/<id>/mon_<id>_s<n>_{idle,walk,attack,hit,death}.png
## (estagio sem arte propria usa a folha do estagio anterior com visual_scale maior).

const SRC := "res://tools/art/content/training_src.json"
const MAP_ID := &"training_field"
## Padroes de MonsterStage para o que o JSON nao informa.
const STAGE_DEFAULTS := {"walk_ms": 420, "range": 1.5, "interval": 1600, "aggressive": false, "aggro": 5,
	"leash": 12, "evolve": 0, "matk": 0, "scale": 1.0}


func _initialize() -> void:
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SRC))
	var errs := 0
	for dir: String in ["monsters", "npcs", "dialogues", "zones", "items"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/" + dir))
	for it: Dictionary in src["items"]:
		errs += _save(_item(it), "res://data/items/%s.tres" % it["id"])
	for m: Dictionary in src["monsters"]:
		errs += _save(_monster(m), "res://data/monsters/%s.tres" % m["id"])
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
		d.move_speed = n.get("speed", 1.6)
		if dlgs.has(n["id"]):
			d.dialogue = load("res://data/dialogues/%s.tres" % n["id"]) as DialogueDef
		errs += _save(d, "res://data/npcs/%s.tres" % n["id"])
	for z: Dictionary in src["zones"]:
		var zd := ZoneDef.new()
		zd.map_id = StringName(z["map_id"])
		zd.kind = ZoneDef.Kind[z["kind"]]
		zd.name_key = "ZONE_%s_NAME" % String(z["map_id"]).to_upper()
		zd.xp_level_cap = int(z["xp_level_cap"])
		zd.items_bound_to_zone = z["items_bound_to_zone"]
		zd.combat_allowed = z["combat_allowed"]
		zd.grave_on_death = z["grave_on_death"]
		zd.respawn_marker = StringName(z["respawn_marker"])
		if ResourceLoader.exists(z["minimap"]):
			zd.minimap_texture = load(z["minimap"]) as Texture2D
		else:
			push_warning("minimapa ainda nao existe: " + z["minimap"])
		var r: Array = z["rect"]
		zd.minimap_world_rect = Rect2(r[0], r[1], r[2], r[3])
		errs += _save(zd, "res://data/zones/%s.tres" % z["map_id"])
	print("build_training: ", "OK" if errs == 0 else "%d erro(s)" % errs)
	quit(0 if errs == 0 else 1)


func _save(res: Resource, path: String) -> int:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("falhou salvar %s: %d" % [path, err])
		return 1
	res.take_over_path(path)
	return 0


func _monster(m: Dictionary) -> MonsterDef:
	var d := MonsterDef.new()
	var id: String = m["id"]
	d.id = StringName(id)
	d.region_id = StringName(m["region"])
	d.respawn_sec = float(m.get("respawn", 30))
	var stages: Array[MonsterStage] = []
	var art_base := ""
	var i := 0
	for s: Dictionary in m["stages"]:
		i += 1
		var st := MonsterStage.new()
		var g := func(k: String) -> Variant: return s.get(k, STAGE_DEFAULTS.get(k))
		st.stage = i
		st.name_key = "MON_%s_S%d_NAME" % [id.to_upper(), i]
		if s.has("frame"):
			art_base = "res://assets/monsters/%s/mon_%s_s%d" % [id, id, i]
		st.sprite_base = art_base
		st.visual_scale = float(g.call("scale"))
		st.level = int(s["level"])
		st.max_hp = int(s["hp"])
		st.atk = int(s["atk"])
		st.matk = int(g.call("matk"))
		st.def = int(s["def"])
		st.mdef = int(s["mdef"])
		st.walk_ms_per_cell = int(g.call("walk_ms"))
		st.attack_range_cells = float(g.call("range"))
		st.attack_interval_ms = int(g.call("interval"))
		st.aggressive = bool(g.call("aggressive"))
		st.aggro_range_cells = int(g.call("aggro"))
		st.leash_cells = int(g.call("leash"))
		st.xp_reward = int(s["xp"])
		st.stars_min = int(s["stars"][0])
		st.stars_max = int(s["stars"][1])
		var bh: Array[StringName] = []
		for b: String in s.get("behaviors", []):
			bh.append(StringName(b))
		st.behaviors = bh
		var drops: Array[DropEntry] = []
		for dr: Array in s.get("drops", []):
			var e := DropEntry.new()
			e.item_id = StringName(dr[0])
			e.chance = float(dr[1])
			e.min_qty = int(dr[2])
			e.max_qty = int(dr[3])
			drops.append(e)
		st.drops = drops
		stages.append(st)
	d.stages = stages
	return d


func _item(it: Dictionary) -> ItemDef:
	var d := ItemDef.new()
	var id: String = it["id"]
	d.id = StringName(id)
	d.name_key = "ITEM_%s_NAME" % id.to_upper()
	d.desc_key = "ITEM_%s_DESC" % id.to_upper()
	var icon_path := "res://assets/items/icons/icon_item_%s.png" % id
	if ResourceLoader.exists(icon_path):
		d.icon = load(icon_path) as Texture2D
	else:
		push_warning("icone ainda nao existe: " + icon_path)
	d.type = ItemDef.ItemType[it["type"]]
	d.rarity = ItemDef.Rarity[it.get("rarity", "COMMON")]
	d.max_stack = int(it.get("stack", 1))
	d.stackable = d.max_stack > 1
	d.buy_price = int(it.get("buy", 0))
	d.sell_price = int(it.get("sell", 0))
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
			op.action = &"close" if String(o[1]) == "" else &""
			opts.append(op)
			i += 1
		n.options = opts
		arr.append(n)
	d.nodes = arr
	return d
