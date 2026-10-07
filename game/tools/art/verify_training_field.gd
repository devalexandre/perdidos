extends Node
## Verificador de conteudo do Campo de Treino (agente W, contrato docs/contracts-arrival.md "Testes W").
##   godot --headless --path game res://tools/art/verify_training_field.tscn [-- --verbose]
## (cena, nao --script: WalkGrid usa o autoload Balance)
## Confere: estrutura do mapa (camadas, marcadores), grade de celulas (WalkGrid do navmesh) com spawns,
## Mestres, portal e bancos no chao andavel e ALCANCAVEIS a partir do SpawnPoint; referencias de dados
## (MonsterDef/NpcDef/DialogueDef/ZoneDef/itens dos drops), folhas de sprite (tamanhos) e chaves de traducao.

const SCENE := "res://scenes/maps/training_field.tscn"
const MON_ANIMS := {"idle": 4, "walk": 6, "attack": 6, "hit": 2, "death": 6}
## Quadro por estagio (GDD 10.2.1 + 17.2): estagio 1 = 96 (pequeno, ~70% do Viajante); chefes 240.
const STAGE_FRAMES := {"prank_whirlwind": [96, 96, 240], "enchanted_firefly": [96, 144, 240], "stone_armadillo": [96, 144, 240]}

var failures := 0
var verbose := false
var keys := {}


func _ready() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	for f: String in ["res://localization/content.csv"]:
		var fa := FileAccess.open(f, FileAccess.READ)
		while not fa.eof_reached():
			var row := fa.get_csv_line()
			if row.size() > 0:
				keys[row[0]] = true
	var map := (load(SCENE) as PackedScene).instantiate() as Node3D
	add_child(map)
	_run.call_deferred(map)


func _check(label: String, ok: bool, info: String = "") -> void:
	if not ok or verbose:
		print("%s %s %s" % ["PASS" if ok else "FAIL", label, info])
	if not ok:
		failures += 1


func _key(k: String, where: String) -> void:
	_check("chave %s (%s)" % [k, where], k != "" and keys.has(k))


func _run(map: Node3D) -> void:
	var content: Node = get_node_or_null(^"/root/Content")
	_check("autoload Content", content != null)
	_check("map_id", map.get(&"map_id") == &"training_field")
	for n: String in ["SpawnPoint", "CampRespawn", "NavigationRegion3D", "NpcPoints", "Spawns", "Interactables", "AudioZones", "Ground", "PointsOfInterest"]:
		_check("no " + n, map.has_node(n))
	# camadas
	var bad := 0
	var surfaces := {}
	for n: Node in map.find_children("*", "CollisionObject3D", true, false):
		var co := n as CollisionObject3D
		var pn := String(co.get_parent().name)
		if co.collision_layer & 1:
			if co is StaticBody3D and pn == "Ground" and co.collision_layer == 1 and co.has_meta(&"surface"):
				surfaces[co.get_meta(&"surface")] = true
			else:
				bad += 1
		if co.collision_layer & 2 and not (co is Area3D and pn == "Interactables" and co.collision_layer == 2):
			bad += 1
		if pn == "AudioZones" and co.collision_layer != 0:
			bad += 1
	_check("camadas: 1 = chao (meta surface), 2 = clicaveis", bad == 0, "%d problema(s), pisos %s" % [bad, surfaces.keys()])
	# grade
	var nav: RID = map.call(&"get_navigation_map")
	for i in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(nav) > 0:
			break
	var grid := WalkGrid.build_from_navmesh(map, Balance.cfg.cell_size)
	print("grade: %dx%d, %d andaveis (%d ms)" % [grid.size.x, grid.size.y, grid.walkable_count(), grid.build_msec])
	var spawn: Vector3 = map.call(&"get_spawn_point")
	var start := grid.world_to_cell(spawn)
	_check("SpawnPoint andavel", grid.is_walkable(start), str(spawn))
	var reach := _flood(grid, start)
	var respawn := (map.get_node("CampRespawn") as Node3D).position
	_check("CampRespawn alcancavel", reach.has(grid.world_to_cell(respawn)))
	# spawns
	var n_spawns := 0
	for m: Node in map.get_node("Spawns").get_children():
		var mk := m as Marker3D
		n_spawns += 1
		var mid: StringName = mk.get_meta(&"monster_id", &"")
		var cnt: int = mk.get_meta(&"count", 0)
		var rad: int = mk.get_meta(&"radius_cells", 0)
		_check("spawn %s: metas" % mk.name, mid != &"" and cnt > 0 and rad > 0)
		_check("spawn %s: MonsterDef %s" % [mk.name, mid], content != null and content.call(&"monster", mid) != null)
		var c := grid.world_to_cell(mk.position)
		_check("spawn %s: centro alcancavel" % mk.name, reach.has(c), str(mk.position))
		var free := 0
		for dx in range(-rad, rad + 1):
			for dz in range(-rad, rad + 1):
				if dx * dx + dz * dz <= rad * rad and reach.has(c + Vector2i(dx, dz)):
					free += 1
		_check("spawn %s: celulas livres no raio >= 3 x count" % mk.name, free >= cnt * 3, "%d livres" % free)
	_check("spawns >= 24", n_spawns >= 24, str(n_spawns))
	# NPCs do mapa
	var npcs: Dictionary = content.call(&"all", &"npcs") if content else {}
	var n_masters := 0
	for id: StringName in npcs:
		var d: NpcDef = npcs[id]
		if d.map_id != &"training_field":
			continue
		n_masters += 1
		var mk := map.get_node_or_null("NpcPoints/" + String(d.spawn_marker)) as Node3D
		_check("NpcPoint de %s" % id, mk != null)
		if mk:
			_check("NPC %s alcancavel" % id, reach.has(grid.world_to_cell(mk.position)), str(mk.position))
		_key(d.name_key, String(id))
		for anim: String in ["idle", "walk"]:
			_sheet("%s_%s.png" % [d.sprite_base, anim], 96, 5, -1, String(id))
		_check("dialogo de %s" % id, d.dialogue != null)
		if d.dialogue:
			for nd: DialogueNode in d.dialogue.nodes:
				_key(nd.text_key, String(id))
				for op: DialogueOption in nd.options:
					_key(op.text_key, String(id))
	_check("11 Mestres no Campo", n_masters == 11, str(n_masters))
	# interactables
	var inter: Dictionary = map.call(&"get_interactables")
	var exit_ok := false
	for k: String in inter:
		var meta: Dictionary = inter[k]["meta"]
		var ap: Vector3 = meta.get(&"approach_position", Vector3.INF)
		_check("interactable %s: aproximacao alcancavel" % k, ap != Vector3.INF and reach.has(grid.world_to_cell(ap)), str(ap))
		if inter[k]["type"] == &"portal" and meta.get(&"training_exit", false):
			exit_ok = true
	_check("portal de saida (training_exit)", exit_ok)
	# zonas
	for zid: StringName in [&"training_field", &"city_awakening"]:
		var z: ZoneDef = content.call(&"zone", zid) if content else null
		_check("ZoneDef %s" % zid, z != null)
		if z:
			_key(z.name_key, String(zid))
			_check("minimapa %s" % zid, z.minimap_texture != null)
	var tz: ZoneDef = content.call(&"zone", &"training_field") if content else null
	if tz:
		_check("training_field: TRAINING, teto 10, itens presos, sem tumulo", tz.kind == ZoneDef.Kind.TRAINING and tz.xp_level_cap == 10 and tz.items_bound_to_zone and not tz.grave_on_death)
		_check("respawn_marker existe", map.has_node(String(tz.respawn_marker)))
	# monstros
	var mons: Dictionary = content.call(&"all", &"monsters") if content else {}
	_check("21 especies", mons.size() >= 21, str(mons.size()))
	for id: StringName in mons:
		var md: MonsterDef = mons[id]
		var fr: Array = STAGE_FRAMES.get(String(id), [96, 96, 96])
		var seen := {}
		for st: MonsterStage in md.stages:
			_key(st.name_key, String(id))
			for dr: DropEntry in st.drops:
				_check("drop %s de %s existe" % [dr.item_id, id], content.call(&"item", dr.item_id) != null)
			if seen.has(st.sprite_base):
				continue
			seen[st.sprite_base] = true
			for anim: String in MON_ANIMS:
				_sheet("%s_%s.png" % [st.sprite_base, anim], fr[mini(st.stage, fr.size()) - 1], 5, MON_ANIMS[anim], "%s s%d" % [id, st.stage])
	print("RESULT: %s (%d falha(s))" % ["OK" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)


func _sheet(path: String, frame: int, rows: int, cols: int, where: String) -> void:
	if not ResourceLoader.exists(path):
		_check("folha existe " + path.get_file(), false, where)
		return
	var tex := load(path) as Texture2D
	var ok := tex.get_height() == frame * rows and (cols < 0 or tex.get_width() == frame * cols) and tex.get_width() % frame == 0
	_check("folha %s (quadro %d)" % [path.get_file(), frame], ok, str(tex.get_size()))


func _flood(grid: WalkGrid, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	var i := 0
	while i < q.size():
		var c := q[i]
		i += 1
		for d: Vector2i in WalkGrid.DIRECTIONS:
			var nc := c + d
			if not seen.has(nc) and grid.can_step(c, d):
				seen[nc] = true
				q.append(nc)
	return seen
