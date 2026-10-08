extends Node
## Verificador de ligações de conteúdo do beta (docs/beta-checklist.md). Headless, sem servidor.
## Carrega todos os dados (Content) e todas as cenas de mapa e confere se cada referência aponta
## para algo que existe e pode acontecer no jogo de verdade:
##   quests, lições dos Mestres, quests dos anciãos (chefe, forma atroz, itens raros, provação), NPCs,
##   diálogos, skills, títulos (roupas nos 2 corpos), monstros (folhas e tamanhos), drops, itens,
##   lojas, textos pt_BR e mapas (portais, volta, alcance a partir do Campo de Treino, SpawnPoint,
##   ponto seguro, navegação e minimapa).
## Falha com uma lista por categoria ("FAIL [categoria] ..."); avisos ("WARN") não reprovam.
## Rodar: godot --headless --path game res://tests/beta/test_content_links.tscn

const MAP_DIR: String = "res://scenes/maps/"
const TRAINING_MAP: StringName = &"training_field"
const MONSTER_COLS: Dictionary[String, Array] = {"idle": [4, 8], "walk": [6, 8], "attack": [6, 8],
		"hit": [2, 4], "death": [6, 8]}
const NPC_ANIMS: Array[String] = ["idle", "walk"]
const QUEST_PROPS_DIR: String = "res://assets/quest_props/"
## Nenhuma folha de personagem tem "hit" (o cliente segura outra pose): não entra no aviso das roupas.
const OUTFIT_IGNORED: Array[StringName] = [&"hit"]
const NPC_FRAME: int = 96
const BODIES: Array[StringName] = [&"male", &"female"]
## Folhas de roupa sem as quais o cliente volta para o Viajante (EntityVisual.LAYER_REQUIRED_ANIMS + máscara).
const OUTFIT_REQUIRED: Array[String] = ["idle", "walk", "mask_idle"]
const SCHOOLS: Array[StringName] = [&"blade", &"arcane", &"bow", &"hybrid", &"support", &"tank"]
## Portões planejados que ficam fechados de propósito (o servidor mostra "Recomendado: ..."): aviso.
const PLANNED_PORTALS: Dictionary[StringName, String] = {&"arena_burning": "arena PVP (fase futura)"}
## O servidor encaixa pontos na célula andável mais próxima até este raio (ServerWorld.GRID_SNAP_SEARCH_CELLS).
const SNAP_CELLS: int = 6
const NAV_WAIT_FRAMES: int = 180
## Mapas reais que não precisam de lugar no mapa-múndi.
const ATLAS_EXEMPT_MAPS: Array[StringName] = [&"elder_trial_arena"]
const KEY_PATTERN: String = "^[A-Z][A-Z0-9_]+$"
## Ligações quebradas que dependem de decisão do dono (docs/beta-checklist.md, "bloqueia o beta"). Saem como
## PENDENTE e não reprovam; com --strict (depois de "--") reprovam. Trecho da mensagem -> motivo.
const PENDING_DECISIONS: Dictionary[String, String] = {
	"zona sem combate (não dá para lutar)": "onde acontece a provação dos anciãos (o Porto não tem combate)",
}

var _fails: Dictionary[String, Array] = {}
var _warns: Array[String] = []
var _checks: int = 0
## map_id -> {"node", "grid", "zone", "spawns": [{monster, stage, level, marker}], "lairs": [...],
##            "portals": [...], "npc_points": {name: Vector3}}
var _maps: Dictionary[StringName, Dictionary] = {}
## chave de tradução -> onde foi usada (primeiro uso)
var _keys: Dictionary[String, String] = {}
var _key_re: RegEx = RegEx.create_from_string(KEY_PATTERN)
## skill -> quests que a ensinam (só com NPC posicionado)
var _skill_sources: Dictionary[StringName, Array] = {}
var _title_sources: Dictionary[StringName, Array] = {}


func _ready() -> void:
	TranslationServer.set_locale("pt_BR")
	await _load_maps()
	_check_map_links()
	_check_items()
	_check_monsters()
	_check_shops()
	_check_npcs()
	_check_title_talks()
	_check_quests()
	_check_werewolf_beta_routes()
	_check_story_bosses()
	_check_skills()
	_check_titles()
	_check_material_sources()
	_check_zones()
	_check_translations()
	_report()


# ================================================================ util

func _ok(cond: bool, category: String, msg: String) -> bool:
	_checks += 1
	if not cond:
		if not _fails.has(category):
			_fails[category] = []
		_fails[category].append(msg)
	return cond


func _warn(category: String, msg: String) -> void:
	_warns.append("[%s] %s" % [category, msg])


func _key(key: String, where: String, required: bool = true) -> void:
	if key.is_empty():
		if required:
			_ok(false, "localização", "%s: chave de texto vazia" % where)
		return
	if not _keys.has(key):
		_keys[key] = where


func _res_exists(path: String) -> bool:
	return not path.is_empty() and ResourceLoader.exists(path)


## Espécie-base (variantes regionais contam como a espécie original nas quests).
func _species(monster_id: StringName) -> StringName:
	var d: MonsterDef = Content.monster(monster_id)
	var base: StringName = _base_of(d)
	return base if not base.is_empty() else monster_id


## MonsterDef.base_species (variante regional; vazio = espécie própria).
func _base_of(d: MonsterDef) -> StringName:
	var v: Variant = d.get(&"base_species") if d != null else null
	return StringName(str(v)) if v != null else &""


func _tr(key: String) -> String:
	return TranslationServer.translate(key)


## "" = andável; "snap:N" = encaixa a N células; "fora" = fora da navegação.
func _walk_state(grid: WalkGrid, pos: Vector3) -> String:
	if grid == null:
		return "sem grade"
	var c: Vector2i = grid.world_to_cell(pos)
	if grid.is_walkable(c):
		return ""
	var near: Vector2i = grid.nearest_walkable(c, SNAP_CELLS)
	if near.x < 0:
		return "fora"
	return "snap:%d" % maxi(absi(near.x - c.x), absi(near.y - c.y))


func _check_walk(grid: WalkGrid, pos: Vector3, category: String, what: String) -> void:
	var st: String = _walk_state(grid, pos)
	if st.begins_with("snap"):
		_warn(category, "%s em %s não é andável; o servidor encaixa a %s células" % [what, _v(pos), st.trim_prefix("snap:")])
	_ok(st == "" or st.begins_with("snap"), category, "%s em %s fora da navegação (%s)" % [what, _v(pos), st])


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f)" % [p.x, p.z]


# ================================================================ mapas

func _load_maps() -> void:
	for f: String in ResourceLoader.list_directory(MAP_DIR):
		if not f.ends_with(".tscn"):
			continue
		var map_id := StringName(f.get_basename())
		var ps: PackedScene = load(MAP_DIR + f) as PackedScene
		if not _ok(ps != null, "mapas", "%s: cena não carrega" % f):
			continue
		var node: Node = ps.instantiate()
		var map: GameMap = node as GameMap
		if not _ok(map != null, "mapas", "%s: raiz não é GameMap (scripts/shared/map.gd)" % f):
			node.free()
			continue
		_ok(map.map_id == map_id, "mapas", "%s: map_id da cena é '%s'" % [f, map.map_id])
		add_child(map)
		var grid: WalkGrid = null
		for i: int in NAV_WAIT_FRAMES:
			await get_tree().physics_frame
			if WalkGrid.is_nav_synced(map.get_navigation_map()):
				grid = WalkGrid.for_map(map_id, map, map.get_navigation_map())
				if grid != null:
					break
		var info: Dictionary = {"node": map, "grid": grid, "zone": Content.zone(map_id), "spawns": [],
				"lairs": [], "story_lairs": [], "portals": [], "npc_points": {}}
		_maps[map_id] = info
		_scan_map(map_id, info)


func _scan_map(map_id: StringName, info: Dictionary) -> void:
	var map: GameMap = info["node"]
	var grid: WalkGrid = info["grid"]
	var zone: ZoneDef = info["zone"]
	var cat: String = "mapa %s" % map_id
	_ok(zone != null, cat, "sem data/zones/%s.tres" % map_id)
	_ok(grid != null and grid.walkable_count() > 0, cat, "navegação não ficou pronta (NavigationRegion3D sem malha?)")
	var spawn := map.get_node_or_null(^"SpawnPoint") as Marker3D
	if _ok(spawn != null, cat, "sem Marker3D SpawnPoint") and grid != null:
		_check_walk(grid, spawn.global_position, cat, "SpawnPoint")
	if zone != null:
		_key(zone.name_key, "zona %s (name_key)" % map_id)
		var rm: Node3D = map.find_child(String(zone.respawn_marker), true, false) as Node3D
		if _ok(rm != null, cat, "ponto seguro (respawn_marker '%s') não existe na cena" % zone.respawn_marker) and grid != null:
			_check_walk(grid, rm.global_position, cat, "ponto seguro %s" % zone.respawn_marker)
		var mini: MinimapData = MinimapData.build(map_id, map, grid)
		_ok(mini.texture != null, cat, "minimapa: sem textura e sem grade para gerar")
		if mini.from_grid and not map is CaveLevel:
			_warn(cat, "minimapa gerado da grade de navegação (sem arte própria em assets/minimap/)")
		var atlas: WorldAtlasDef = load(WorldAtlasDef.DEFAULT_PATH) as WorldAtlasDef
		# Toda cidade e área de caça real aparece no Mapa do Mundo (andares via map_ids); a arena de
		# provação dos anciãos fica de fora de propósito.
		if atlas != null and zone.kind in [ZoneDef.Kind.CITY, ZoneDef.Kind.HUNT] and map_id not in ATLAS_EXEMPT_MAPS:
			_ok(atlas.place_for_map(map_id) != null, cat, "mapa-múndi não tem lugar para este mapa")
	# Monstros
	var spawns_root: Node = map.get_node_or_null(^"Spawns")
	var cap: int = CombatBridges.stage_cap_for_zone(zone)
	if spawns_root != null:
		for m: Node in spawns_root.get_children():
			if not (m is Node3D) or not m.has_meta(&"monster_id"):
				continue
			var mid := StringName(str(m.get_meta(&"monster_id")))
			var def: MonsterDef = Content.monster(mid)
			if not _ok(def != null and not def.stages.is_empty(), cat, "Spawns/%s: monstro '%s' não existe" % [m.name, mid]):
				continue
			var want: int = int(m.get_meta(&"stage", 1))
			var st_num: int = clampi(want, 1, mini(cap, CombatRules.STAGE_MEDIUM))
			_ok(want < CombatRules.STAGE_BOSS, cat, "Spawns/%s pede chefe: chefe só no covil (BossLairs/)" % m.name)
			if want > cap:
				_warn(cat, "Spawns/%s pede estágio %d mas a zona limita a %d" % [m.name, want, cap])
			var st: MonsterStage = MonsterEvolution.stage_by_number(def, st_num)
			if not _ok(st != null, cat, "Spawns/%s: '%s' não tem estágio %d" % [m.name, mid, st_num]):
				continue
			if grid != null:
				_check_walk(grid, (m as Node3D).global_position, cat, "Spawns/%s" % m.name)
			(info["spawns"] as Array).append({"monster": mid, "stage": st_num, "level": st.level,
					"marker": String(m.name)})
	var lairs: Node = map.get_node_or_null(^"BossLairs")
	if lairs != null:
		for m: Node in lairs.get_children():
			if not (m is Node3D):
				continue
			var mid := StringName(str(m.get_meta(&"monster_id", "")))
			_ok(not mid.is_empty(), cat, "BossLairs/%s: covil sem monster_id (cada covil é de um chefe)" % m.name)
			if not mid.is_empty():
				var ldef: MonsterDef = Content.monster(mid)
				if _ok(ldef != null, cat, "BossLairs/%s: monstro '%s' não existe" % [m.name, mid]):
					_ok(MonsterEvolution.stage_by_number(ldef, CombatRules.STAGE_BOSS) != null, cat,
							"BossLairs/%s: '%s' não tem estágio de chefe" % [m.name, mid])
			if grid != null:
				_check_walk(grid, (m as Node3D).global_position, cat, "covil BossLairs/%s" % m.name)
			(info["lairs"] as Array).append({"monster": mid, "marker": String(m.name)})
	# Chefes da história (Arco 1): covil só de chefe story_boss já liberado, bando >= 10, no máximo 1 por mapa.
	var story_lairs: Node = map.get_node_or_null(NodePath(MonsterSpawner.STORY_LAIRS_NODE))
	if story_lairs != null:
		_ok(MonsterSpawner.story_lairs_allowed(zone), cat, "StoryLairs/ em zona que não aceita chefe da história")
		for m: Node in story_lairs.get_children():
			if not (m is Node3D):
				continue
			var smid := StringName(str(m.get_meta(&"monster_id", "")))
			var problem: String = MonsterSpawner.story_lair_problem(Content.monster(smid), m.get_meta(&"escort", {}))
			_ok(problem.is_empty(), cat, "StoryLairs/%s ('%s'): %s" % [m.name, smid, problem])
			if grid != null:
				_check_walk(grid, (m as Node3D).global_position, cat, "covil da história StoryLairs/%s" % m.name)
			(info["story_lairs"] as Array).append({"monster": smid, "marker": String(m.name)})
		_ok((info["story_lairs"] as Array).size() <= 1, cat, "mais de um chefe da história no mesmo mapa (regra 5)")
	var points: Node = map.get_node_or_null(^"NpcPoints")
	if points != null:
		for p: Node in points.get_children():
			if p is Node3D:
				(info["npc_points"] as Dictionary)[StringName(p.name)] = (p as Node3D).global_position
	for id: String in map.get_interactables():
		var obj: Dictionary = map.get_interactables()[id]
		if StringName(str(obj.get("type", ""))) != &"portal":
			continue
		var meta: Dictionary = obj["meta"]
		var p: Dictionary = {"id": id, "dest": StringName(str(meta.get(&"target_map", ""))),
				"spawn": StringName(str(meta.get(&"target_spawn", "SpawnPoint"))),
				"approach": meta.get(&"approach_position", obj["position"]),
				"one_way": bool(meta.get(&"one_way", false)),
				"requires_boss_victory": bool(meta.get(&"requires_boss_victory", false)),
				"training_exit": bool(meta.get(&"training_exit", false)), "position": obj["position"]}
		(info["portals"] as Array).append(p)
		var area: Node = map.get_node_or_null(NodePath("Interactables/" + id))
		var label: Label3D = area.get_node_or_null(^"Name") as Label3D if area != null else null
		if label != null and _key_re.search(label.text) != null:
			_key(label.text, "%s: placa do portal %s" % [map_id, id])


func _check_map_links() -> void:
	var initial_starts: Array[StringName] = []
	for t: Resource in Content.all(&"titles").values():
		var td: TitleDef = t as TitleDef
		if td != null and not td.start_map_id.is_empty():
			if _ok(_maps.has(td.start_map_id), "títulos", "%s: start_map_id '%s' não existe" % [td.id, td.start_map_id]):
				if not initial_starts.has(td.start_map_id):
					initial_starts.append(td.start_map_id)
	var edges: Dictionary[StringName, Array] = {}
	for map_id: StringName in _maps:
		var info: Dictionary = _maps[map_id]
		var zone: ZoneDef = info["zone"]
		var cat: String = "mapa %s" % map_id
		var grid: WalkGrid = info["grid"]
		var map: GameMap = info["node"]
		edges[map_id] = []
		var portal_dests: Array[StringName] = []
		for p: Dictionary in info["portals"]:
			var dest: StringName = p["dest"]
			var pid: String = "portal %s → %s" % [p["id"], dest]
			if bool(p["training_exit"]):
				_ok(not initial_starts.is_empty(), cat, "%s: saída do treino sem nenhum título inicial com cidade" % pid)
				for s: StringName in initial_starts:
					(edges[map_id] as Array).append(s)
				continue
			if not _maps.has(dest):
				if PLANNED_PORTALS.has(dest):
					_warn(cat, "%s: destino ainda não existe (%s); o portão fica fechado" % [pid, PLANNED_PORTALS[dest]])
					_ok(zone == null or not (dest in zone.connected_maps), cat, "%s: destino inexistente listado em connected_maps" % pid)
				else:
					_ok(false, cat, "%s: mapa de destino não existe" % pid)
				continue
			portal_dests.append(dest)
			(edges[map_id] as Array).append(dest)
			_ok(zone != null and MapTransfer.portal_allowed(zone, dest), cat,
					"%s: servidor recusa (destino fora de connected_maps da zona)" % pid)
			var dinfo: Dictionary = _maps[dest]
			var dmap: GameMap = dinfo["node"]
			var marker: Node3D = dmap.get_node_or_null(NodePath(String(p["spawn"]))) as Node3D
			if _ok(marker != null, cat, "%s: spawn de chegada '%s' não existe em %s" % [pid, p["spawn"], dest]) \
					and dinfo["grid"] != null:
				_check_walk(dinfo["grid"], marker.global_position, "mapa %s" % dest, "chegada %s (vindo de %s)" % [p["spawn"], map_id])
			var dzone: ZoneDef = dinfo["zone"]
			var back_portal: bool = false
			for bp: Dictionary in dinfo["portals"]:
				if bp["dest"] == map_id:
					back_portal = true
			if p["one_way"]:
				# Fuga após chefe: o servidor (MapTransfer) só abre a saída quando morre o chefe de um
				# covil (BossLairs/) deste mapa; sem covil, a saída nunca abriria.
				_ok(p["requires_boss_victory"] and not (info["lairs"] as Array).is_empty(), cat,
						"%s: saída de sentido único deve ser fuga após chefe" % pid)
			else:
				_ok(dzone != null and map_id in dzone.connected_maps and back_portal, cat,
						"%s: conexão sem volta (%s não tem portal/connected_maps para %s)" % [pid, dest, map_id])
			var from: Vector3 = (map.get_node(^"SpawnPoint") as Node3D).global_position if map.has_node(^"SpawnPoint") else Vector3.ZERO
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map.get_navigation_map(), from, p["approach"], true)
			var reach: bool = path.size() >= 2 and path[path.size() - 1].distance_to(p["approach"]) < 3.0
			_ok(reach, cat, "%s: não dá para andar do SpawnPoint até o portal %s" % [pid, _v(p["approach"])])
			if grid != null:
				_check_walk(grid, p["approach"], cat, "frente do %s" % pid)
		if zone != null:
			for c: StringName in zone.connected_maps:
				_ok(_maps.has(c), cat, "connected_maps aponta para '%s', que não existe" % c)
				if _maps.has(c) and not portal_dests.has(c):
					_warn(cat, "connected_maps tem '%s' mas nenhum portal da cena leva para lá" % c)
	# Provações têm acesso por diálogo e retorno automático, sem portal público.
	for resource: Resource in Content.all(&"quests").values():
		var quest := resource as QuestDef
		var giver: NpcDef = Content.npc(quest.giver_npc) if quest != null else null
		if giver == null:
			continue
		for step: QuestStep in quest.steps:
			if not step.trial_map_id.is_empty() and edges.has(giver.map_id):
				edges[giver.map_id].append(step.trial_map_id)
	# Alcance a partir do Campo de Treino
	var seen: Dictionary[StringName, bool] = {TRAINING_MAP: true}
	var queue: Array[StringName] = [TRAINING_MAP]
	while not queue.is_empty():
		var cur: StringName = queue.pop_front()
		for n: Variant in edges.get(cur, []):
			var nid := StringName(str(n))
			if not seen.has(nid):
				seen[nid] = true
				queue.append(nid)
	for map_id: StringName in _maps:
		_ok(seen.has(map_id), "mapas", "%s não é alcançável a partir do Campo de Treino" % map_id)


func _check_zones() -> void:
	for z: Resource in Content.all(&"zones").values():
		var zd: ZoneDef = z as ZoneDef
		if zd != null:
			_ok(_maps.has(zd.map_id), "mapas", "data/zones/%s.tres sem cena em scenes/maps/" % zd.map_id)


# ================================================================ itens, monstros, lojas

func _check_items() -> void:
	for r: Resource in Content.all(&"items").values():
		var it: ItemDef = r as ItemDef
		var cat: String = "itens"
		_ok(it.icon != null, cat, "%s: sem ícone" % it.id)
		_key(it.name_key, "item %s (name_key)" % it.id)
		_key(it.desc_key, "item %s (desc_key)" % it.id)


func _drop_ok(d: DropEntry, where: String) -> void:
	_ok(d != null and Content.item(d.item_id) != null, "drops", "%s: drop '%s' não é item" % [where, d.item_id if d != null else &"null"])


func _check_monsters() -> void:
	for r: Resource in Content.all(&"monsters").values():
		var def: MonsterDef = r as MonsterDef
		var cat: String = "monstros"
		if not _base_of(def).is_empty():
			_ok(Content.monster(_base_of(def)) != null, cat, "%s: base_species '%s' não existe" % [def.id, _base_of(def)])
		if not _ok(not def.stages.is_empty(), cat, "%s: sem estágios" % def.id):
			continue
		var numbers: Array[int] = []
		for st: MonsterStage in def.stages:
			numbers.append(st.stage)
			var where: String = "%s estágio %d" % [def.id, st.stage]
			_key(st.name_key, where + " (name_key)")
			for d: DropEntry in st.drops:
				_drop_ok(d, where)
			for anim: String in MONSTER_COLS:
				var path: String = "%s_%s.png" % [st.sprite_base, anim]
				# Chefe da história com a arte esperando aprovação: só aviso (ele não pode estar em mapa nem em quest
				# liberada; ver _check_story_bosses e _check_step).
				if def.art_pending and not _res_exists(path):
					if anim == "idle":
						_warn(cat, "%s: arte pendente (folhas %s_* ainda não instaladas)" % [where, st.sprite_base.get_file()])
					continue
				if not _ok(_res_exists(path), cat, "%s: falta folha %s" % [where, path.get_file()]):
					continue
				var tex: Texture2D = load(path) as Texture2D
				var h: int = tex.get_height()
				var w: int = tex.get_width()
				var frame: int = h / 5
				var cols: int = w / frame if frame > 0 else 0
				# Objetos de provação (assets/quest_props/, ex. muda de pequi) ficam parados: qualquer nº de quadros.
				var prop: bool = st.sprite_base.begins_with(QUEST_PROPS_DIR)
				_ok(h % 5 == 0 and frame > 0 and w % frame == 0 and (prop or cols in MONSTER_COLS[anim]), cat,
						"%s: folha %s com tamanho %dx%d (quadro %d, %d colunas; esperado %s)" % [where, path.get_file(),
						w, h, frame, cols, str(MONSTER_COLS[anim])])
		if def.story_boss:
			# Arco 1: só a forma atroz (o 3 guarda os atributos, o 4 a aparência), sem estágios 1 e 2.
			_ok(3 in numbers and MonsterDef.ATROZ_STAGE in numbers and not 1 in numbers and not 2 in numbers, cat,
					"%s: chefe da história deve ter só os estágios 3 e 4" % def.id)
			_ok(not def.can_be_rare, cat, "%s: chefe da história não nasce raro" % def.id)
		else:
			_ok(1 in numbers, cat, "%s: sem estágio 1" % def.id)
		if MonsterDef.ATROZ_STAGE in numbers:
			_ok(3 in numbers, cat, "%s: forma atroz (4) sem chefe (3)" % def.id)
		for d: DropEntry in def.rare_extra_drops:
			_drop_ok(d, "%s (raro)" % def.id)
		if not def.rare_name_key.is_empty():
			_key(def.rare_name_key, "%s rare_name_key" % def.id)


func _check_shops() -> void:
	for r: Resource in Content.all(&"shops").values():
		var sh: ShopDef = r as ShopDef
		var all_stock: Array[StringName] = sh.items.duplicate()
		for tier: Array in [sh.causos_rank_1_items, sh.causos_rank_2_items, sh.causos_rank_3_items,
				sh.causos_rank_4_items, sh.causos_rank_5_items]:
			for id: StringName in tier:
				if id not in all_stock:
					all_stock.append(id)
		for id: StringName in all_stock:
			var it: ItemDef = Content.item(id)
			if _ok(it != null, "lojas", "%s: item '%s' não existe" % [sh.id, id]):
				_ok(it.buy_price > 0, "lojas", "%s: item '%s' com buy_price 0 (a loja não vende)" % [sh.id, id])
	var market: ShopDef = Content.shop(&"market")
	_ok(market != null and &"simple_bow" in market.items, "lojas", "market não vende o simple_bow")
	if market != null:
		var rank_zero: Array[StringName] = market.available_items(0)
		var rank_one: Array[StringName] = market.available_items(1)
		var rank_two: Array[StringName] = market.available_items(2)
		var rank_three: Array[StringName] = market.available_items(3)
		var rank_four: Array[StringName] = market.available_items(4)
		var rank_five: Array[StringName] = market.available_items(5)
		_ok(&"wooden_staff" in rank_zero and &"ipe_wand" in rank_zero, "lojas", "estoque inicial mantém as duas armas mágicas")
		_ok(&"pindorama_long_blade" not in rank_zero and &"pindorama_long_blade" in rank_one,
				"lojas", "primeiro rank de Causos libera armas novas")
		_ok(&"buriti_recurve" in rank_one and &"ember_machete" not in rank_one
				and &"ember_machete" in rank_two and &"firefly_wand" in rank_two,
				"lojas", "ranks 1 e 2 liberam as armas previstas sem antecipar a próxima")
		_ok(&"moss_crown" in rank_three and &"leather_gloves" in rank_three and &"buriti_ring" in rank_three
				and &"ipe_circlet" not in rank_three,
				"lojas", "rank 3 libera coroa, luvas e anel, não o estoque do rank 4")
		_ok(&"ipe_circlet" in rank_four and &"cinder_ring" in rank_four and &"mito_saber" not in rank_four,
				"lojas", "rank 4 libera seus acessórios sem antecipar a arma final")
		_ok(&"mito_saber" in rank_five and &"pindorama_long_blade" in rank_five
				and &"leather_gloves" in rank_five,
				"lojas", "rank 5 mantém o estoque cumulativo e libera a arma final")


# ================================================================ NPCs e diálogos

func _npc_placed(npc_id: StringName) -> bool:
	var n: NpcDef = Content.npc(npc_id)
	return n != null and _maps.has(n.map_id) and (_maps[n.map_id]["npc_points"] as Dictionary).has(n.spawn_marker)


func _check_npcs() -> void:
	var used_dialogues: Dictionary[StringName, bool] = {}
	for r: Resource in Content.all(&"npcs").values():
		var n: NpcDef = r as NpcDef
		var cat: String = "npcs"
		_key(n.name_key, "npc %s (name_key)" % n.id)
		if _ok(_maps.has(n.map_id), cat, "%s: map_id '%s' não existe" % [n.id, n.map_id]):
			var pts: Dictionary = _maps[n.map_id]["npc_points"]
			if _ok(pts.has(n.spawn_marker), cat, "%s: spawn_marker NpcPoints/%s não existe em %s" % [n.id, n.spawn_marker, n.map_id]):
				_check_walk(_maps[n.map_id]["grid"], pts[n.spawn_marker], cat, "%s (NpcPoints/%s)" % [n.id, n.spawn_marker])
			for pm: StringName in n.patrol_markers:
				_ok(pts.has(pm), cat, "%s: patrol_marker NpcPoints/%s não existe" % [n.id, pm])
		var base: String = n.resolved_sprite_base()
		if base != n.sprite_base:
			_warn(cat, "%s: sem folhas próprias (%s); usa a reserva %s" % [n.id, n.sprite_base.get_file(), base.get_file()])
		for anim: String in NPC_ANIMS:
			var path: String = "%s_%s.png" % [base, anim]
			if _ok(_res_exists(path), cat, "%s: falta folha %s" % [n.id, path.get_file()]):
				var tex: Texture2D = load(path) as Texture2D
				_ok(tex.get_height() == NPC_FRAME * 5 and tex.get_width() % NPC_FRAME == 0, cat,
						"%s: folha %s %dx%d (quadros de 96, 5 linhas)" % [n.id, path.get_file(), tex.get_width(), tex.get_height()])
		if _ok(n.dialogue != null, cat, "%s: sem diálogo" % n.id):
			used_dialogues[n.dialogue.id] = true
			_check_dialogue(n.dialogue, n)
		if n.shop != null:
			for id: StringName in n.shop.items:
				_ok(Content.item(id) != null, cat, "%s: loja com item '%s' inexistente" % [n.id, id])
	for r: Resource in Content.all(&"dialogues").values():
		var d: DialogueDef = r as DialogueDef
		if not used_dialogues.has(d.id):
			_warn("diálogos", "%s não é usado por nenhum NPC" % d.id)


func _check_dialogue(d: DialogueDef, n: NpcDef) -> void:
	var cat: String = "diálogos"
	_ok(d.get_node_by_id(d.start_node) != null, cat, "%s: start_node '%s' não existe" % [d.id, d.start_node])
	for node: DialogueNode in d.nodes:
		var where: String = "%s/%s" % [d.id, node.id]
		_key(node.text_key, where)
		for o: DialogueOption in node.options:
			_key(o.text_key, where + " (opção)")
			if not o.next_node.is_empty():
				_ok(d.get_node_by_id(o.next_node) != null, cat, "%s: opção leva a '%s', que não existe" % [where, o.next_node])
			if o.action == &"open_shop":
				_ok(n.shop != null, cat, "%s: open_shop mas o NPC %s não tem loja" % [where, n.id])
			if o.action_args.has(&"item_id"):
				_ok(Content.item(StringName(str(o.action_args[&"item_id"]))) != null, cat, "%s: item_id '%s' não existe" % [where, o.action_args[&"item_id"]])
			if o.action == &"craft_item":
				for material_id: Variant in o.action_args.get(&"materials", {}):
					_ok(Content.item(StringName(str(material_id))) != null, cat,
							"%s: material de craft '%s' não existe" % [where, material_id])
			for k: StringName in o.conditions:
				var v: Variant = o.conditions[k]
				if k == &"has_item":
					_ok(Content.item(StringName(str(v))) != null, cat, "%s: condição has_item '%s' não é item" % [where, v])
				elif k in [&"quest_locked", &"quest_taken", &"quest_done", &"quest_active", &"quest_available"]:
					_ok(Content.quest(StringName(str(v))) != null, cat, "%s: condição %s aponta para quest '%s' inexistente" % [where, k, v])
				elif k in [&"has_title", &"title"]:
					_ok(Content.title(StringName(str(v))) != null, cat, "%s: condição %s aponta para título '%s' inexistente" % [where, k, v])


func _check_title_talks() -> void:
	for r: Resource in Content.all(&"title_talks").values():
		var t: TitleTalkDef = r as TitleTalkDef
		var cat: String = "falas de título"
		_ok(Content.npc(t.npc_id) != null, cat, "%s: npc '%s' não existe" % [t.id, t.npc_id])
		if not t.title_id.is_empty():
			_ok(Content.title(t.title_id) != null, cat, "%s: título '%s' não existe" % [t.id, t.title_id])
		else:
			_key(t.title_name_key, "fala %s (title_name_key)" % t.id)
			_key(t.title_desc_key, "fala %s (title_desc_key)" % t.id)
			for k: String in t.skill_name_keys:
				_key(k, "fala %s (skill_name_keys)" % t.id)
		_key(t.style_key, "fala %s (style_key)" % t.id)


# ================================================================ quests

## Espawns fora do Campo de Treino da espécie (ou variante dela).
func _spawns_of(species: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for map_id: StringName in _maps:
		if map_id == TRAINING_MAP:
			continue
		var zone: ZoneDef = _maps[map_id]["zone"]
		if zone != null and not zone.combat_allowed:
			continue
		for s: Dictionary in _maps[map_id]["spawns"]:
			if species.is_empty() or _species(s["monster"]) == species:
				var e: Dictionary = s.duplicate()
				e["map"] = map_id
				out.append(e)
	return out


## Onde um chefe (estágio 3) da espécie vive: covil fixo (BossLairs/) numa zona que aceita chefe (decisão do dono,
## 30/09/2026: sem evolução e sem chefe por contagem de abates). Marcador comum de estágio 3 é erro.
func _boss_maps(species: StringName) -> Array[String]:
	var out: Array[String] = []
	for map_id: StringName in _maps:
		var info: Dictionary = _maps[map_id]
		var zone: ZoneDef = info["zone"]
		if map_id == TRAINING_MAP or zone == null or not zone.combat_allowed:
			continue
		if not MonsterSpawner.zone_allows_bosses(zone, CombatBridges.stage_cap_for_zone(zone)):
			continue
		for l: Dictionary in info["lairs"]:
			var mid: StringName = l["monster"]
			if mid.is_empty() or (not species.is_empty() and _species(mid) != species):
				continue
			var def: MonsterDef = Content.monster(mid)
			if def == null or MonsterEvolution.stage_by_number(def, CombatRules.STAGE_BOSS) == null:
				continue
			out.append("%s:%s (covil fixo)" % [map_id, mid])
	return out


## Mapas com covil da história (StoryLairs/) desse chefe.
func _story_lair_maps(monster_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for map_id: StringName in _maps:
		for l: Dictionary in _maps[map_id]["story_lairs"]:
			if l["monster"] == monster_id:
				out.append(map_id)
	return out


## Chefe da história: só em StoryLairs/; com arte pendente, em nenhum mapa.
func _check_story_bosses() -> void:
	for r: Resource in Content.all(&"monsters").values():
		var def: MonsterDef = r as MonsterDef
		if def == null or not def.story_boss:
			continue
		var placed: Array[String] = []
		for map_id: StringName in _maps:
			for key: String in ["spawns", "lairs", "story_lairs"]:
				for e: Dictionary in _maps[map_id][key]:
					if StringName(str(e["monster"])) == def.id:
						placed.append("%s/%s" % [map_id, key])
		if def.art_pending:
			_ok(placed.is_empty(), "monstros", "%s: arte pendente mas posicionado em %s" % [def.id, str(placed)])
		for p: String in placed:
			_ok(p.ends_with("story_lairs"), "monstros", "%s: chefe da história fora de StoryLairs/ (%s)" % [def.id, p])


func _atroz_maps(species: StringName) -> Array[String]:
	var out: Array[String] = []
	for tag: String in _boss_maps(species):
		var mid := StringName(tag.split(":")[1].split(" ")[0])
		var def: MonsterDef = Content.monster(mid)
		if def != null and def.atroz_stage() != null:
			out.append(tag)
	return out


func _drops_from_spawn(item_id: StringName) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in _spawns_of(&""):
		var def: MonsterDef = Content.monster(s["monster"])
		var st: MonsterStage = MonsterEvolution.stage_by_number(def, int(s["stage"]))
		var lists: Array = [st.drops if st != null else []]
		if def.can_be_rare:
			lists.append(def.rare_extra_drops)
		for l: Variant in lists:
			for d: DropEntry in l:
				if d.item_id == item_id:
					out.append("%s:%s" % [s["map"], s["monster"]])
	return out


func _sold(item_id: StringName) -> bool:
	for r: Resource in Content.all(&"shops").values():
		if item_id in (r as ShopDef).items:
			return true
	return false


func _check_quests() -> void:
	for r: Resource in Content.all(&"quests").values():
		var q: QuestDef = r as QuestDef
		var cat: String = "quests"
		var id: String = String(q.id)
		for k: String in [q.name_key, q.offer_text_key, q.progress_text_key, q.complete_text_key, q.option_text_key, q.desc_key]:
			_key(k, "quest %s" % id)
		var giver_ok: bool = _ok(Content.npc(q.giver_npc) != null, cat, "%s: giver_npc '%s' não existe" % [id, q.giver_npc])
		if giver_ok:
			giver_ok = _ok(_npc_placed(q.giver_npc), cat, "%s: giver_npc '%s' não está posicionado em nenhum mapa" % [id, q.giver_npc])
		if not q.turn_in_npc.is_empty():
			_ok(_npc_placed(q.turn_in_npc), cat, "%s: turn_in_npc '%s' não existe/posicionado" % [id, q.turn_in_npc])
		if not q.reward_skill.is_empty():
			if _ok(Content.skill(q.reward_skill) != null, cat, "%s: reward_skill '%s' não existe" % [id, q.reward_skill]) and giver_ok:
				if not _skill_sources.has(q.reward_skill):
					_skill_sources[q.reward_skill] = []
				_skill_sources[q.reward_skill].append(q.id)
		# Skills de vínculo vêm com o companheiro que a quest de vínculo concede (CompanionDef.bond_skills).
		if not q.reward_companion.is_empty() and giver_ok and Content.companion(q.reward_companion) != null:
			for bond: StringName in Content.companion(q.reward_companion).bond_skills:
				if not _skill_sources.has(bond):
					_skill_sources[bond] = []
				_skill_sources[bond].append(q.id)
		# Skills de ofício vêm com o título que a quest concede (TitleDef.bonus_skills).
		if not q.reward_title.is_empty() and giver_ok:
			for bonus: StringName in TitleService.bonus_skills_for_title(q.reward_title):
				if not _skill_sources.has(bonus):
					_skill_sources[bonus] = []
				_skill_sources[bonus].append(q.id)
		if not q.reward_title.is_empty():
			if _ok(Content.title(q.reward_title) != null, cat, "%s: reward_title '%s' não existe" % [id, q.reward_title]) and giver_ok:
				if not _title_sources.has(q.reward_title):
					_title_sources[q.reward_title] = []
				_title_sources[q.reward_title].append(q.id)
		for it: StringName in q.reward_items:
			_ok(Content.item(it) != null, cat, "%s: reward_items '%s' não existe" % [id, it])
		for s: StringName in q.required_skills:
			_ok(Content.skill(s) != null, cat, "%s: required_skills '%s' não existe" % [id, s])
		for s: StringName in q.required_skill_levels:
			_ok(Content.skill(s) != null, cat, "%s: required_skill_levels '%s' não existe" % [id, s])
		for t: StringName in q.required_titles:
			_ok(Content.title(t) != null, cat, "%s: required_titles '%s' não existe" % [id, t])
		for rq: StringName in q.required_quests:
			_ok(Content.quest(rq) != null, cat, "%s: required_quests '%s' não existe" % [id, rq])
		var n: int = 0
		for s: QuestStep in q.steps:
			n += 1
			_check_step(q, s, n)


func _check_step(q: QuestDef, s: QuestStep, n: int) -> void:
	var cat: String = "quests"
	var where: String = "%s etapa %d" % [q.id, n]
	_key(s.text_key, where)
	var is_lesson: bool = String(q.id).begins_with("lesson_")
	var is_elder: bool = String(q.id).begins_with("elder_")
	match s.type:
		QuestStep.StepType.KILL:
			if not (s.target_id.is_empty() or s.target_id == &"*"):
				if not _ok(Content.monster(s.target_id) != null, cat, "%s: monstro '%s' não existe" % [where, s.target_id]):
					return
			var species: StringName = &"" if s.target_id == &"*" else s.target_id
			match s.variant:
				&"boss":
					var bm: Array[String] = _boss_maps(species)
					_ok(not bm.is_empty(), "anciãos" if is_elder else cat,
							"%s: chefe de '%s' não tem covil fixo em nenhum mapa" % [where, species if not species.is_empty() else "qualquer"])
					if s.distinct_species and s.count > 1:
						var sp: Dictionary = {}
						for tag: String in bm:
							sp[_species(StringName(tag.split(":")[1].split(" ")[0]))] = true
						_ok(sp.size() >= s.count, "anciãos" if is_elder else cat, "%s: pede %d chefes de espécies diferentes; só %d espécies têm chefe alcançável %s" % [where, s.count, sp.size(), str(bm)])
				&"atroz":
					var am: Array[String] = _atroz_maps(species)
					_ok(not am.is_empty(), "anciãos" if is_elder else cat,
							"%s: forma atroz de '%s' não acontece em nenhum mapa (covil + noite)" % [where, species if not species.is_empty() else "qualquer"])
				&"rare":
					var found: bool = false
					for sp: Dictionary in _spawns_of(species):
						found = found or Content.monster(sp["monster"]).can_be_rare
					_ok(found, cat, "%s: variante rara de '%s' não nasce fora do treino" % [where, species])
				_:
					if is_lesson or is_elder:
						_check_lesson_hunt(q, s, where)
		QuestStep.StepType.COLLECT:
			if not _ok(Content.item(s.target_id) != null, cat, "%s: item '%s' não existe" % [where, s.target_id]):
				return
			if not s.drop_from.is_empty():
				_ok(Content.monster(s.drop_from) != null and s.drop_chance > 0.0, cat,
						"%s: drop_from '%s' inexistente ou sem chance" % [where, s.drop_from])
				if q.released:
					_ok(not _spawns_of(_species(s.drop_from)).is_empty(), cat,
							"%s: '%s' (que solta %s) não nasce fora do treino" % [where, s.drop_from, s.target_id])
			if is_lesson or is_elder:
				var src: Array[String] = _drops_from_spawn(s.target_id)
				_ok(not src.is_empty() or _sold(s.target_id), "lições" if is_lesson else "anciãos",
						"%s: '%s' não cai de nenhum monstro que nasce fora do treino nem é vendido" % [where, s.target_id])
				if is_elder:
					_check_rare_source(q, s, where)
		QuestStep.StepType.TALK:
			_ok(_npc_placed(s.target_id), cat, "%s: NPC '%s' não existe/posicionado" % [where, s.target_id])
		QuestStep.StepType.EXPLORE:
			var found: bool = false
			for map_id: StringName in _maps:
				found = found or (_maps[map_id]["node"] as Node).find_child(String(s.target_id), true, false) != null
			_ok(found, cat, "%s: marcador '%s' não existe em nenhum mapa" % [where, s.target_id])
		QuestStep.StepType.RITUAL:
			var rd: MonsterDef = Content.monster(s.target_id)
			if not _ok(rd != null and rd.story_boss, cat, "%s: ritual de '%s', que não é chefe da história" % [where, s.target_id]):
				return
			if not s.ritual_item.is_empty():
				_ok(Content.item(s.ritual_item) != null, cat, "%s: ritual_item '%s' não existe" % [where, s.ritual_item])
			if q.released:
				_ok(not rd.art_pending, cat, "%s: quest liberada com chefe de arte pendente '%s'" % [where, s.target_id])
				_ok(not _story_lair_maps(s.target_id).is_empty(), cat,
						"%s: '%s' não tem covil (StoryLairs/) em nenhum mapa" % [where, s.target_id])
		QuestStep.StepType.TRIAL:
			_ok(Content.monster(s.target_id) != null, cat, "%s: provação com monstro '%s' inexistente" % [where, s.target_id])
			if s.trial_mode == &"protect":
				_ok(Content.monster(s.protect_target) != null, cat, "%s: protect_target '%s' não existe" % [where, s.protect_target])
			# A provação nasce junto do jogador que fala com o NPC: o mapa dele precisa permitir combate.
			var npc: NpcDef = Content.npc(q.giver_npc)
			var trial_map: StringName = s.trial_map_id if not s.trial_map_id.is_empty() else (npc.map_id if npc != null else &"")
			var zone: ZoneDef = Content.zone(trial_map)
			_ok(_maps.has(trial_map), cat, "%s: mapa de provação inexistente '%s'" % [where, trial_map])
			_ok(zone == null or zone.combat_allowed, "anciãos" if is_elder else cat,
					"%s: provação começa junto de %s em %s, zona sem combate (não dá para lutar)" % [where, q.giver_npc, npc.map_id if npc != null else &"?"])


## Lição: o monstro pedido nasce fora do treino com nível dentro da faixa recomendada do mapa.
func _check_lesson_hunt(q: QuestDef, s: QuestStep, where: String) -> void:
	var cat: String = "lições" if String(q.id).begins_with("lesson_") else "anciãos"
	var spawns: Array[Dictionary] = _spawns_of(s.target_id)
	if not _ok(not spawns.is_empty(), cat, "%s: '%s' só nasce no Campo de Treino" % [where, s.target_id]):
		return
	var fit: bool = false
	for sp: Dictionary in spawns:
		var zone: ZoneDef = _maps[sp["map"]]["zone"]
		var lo: int = zone.recommended_level_min if zone != null else 0
		var hi: int = zone.recommended_level_max if zone != null and zone.recommended_level_max > 0 else 999
		fit = fit or (int(sp["level"]) >= lo and int(sp["level"]) <= hi)
	_ok(fit, cat, "%s: '%s' nasce só fora da faixa de nível do mapa %s" % [where, s.target_id, str(spawns)])


## Item raro do ancião: cai do monstro que o texto da etapa indica (raro ou chefe), e ele nasce fora do treino.
func _check_rare_source(q: QuestDef, s: QuestStep, where: String) -> void:
	var text: String = _tr(s.text_key)
	var named: Array[StringName] = []
	for r: Resource in Content.all(&"monsters").values():
		var def: MonsterDef = r as MonsterDef
		if not _base_of(def).is_empty() or def.stages.is_empty():
			continue
		var nm: String = _tr(def.stages[0].name_key)
		if not nm.is_empty() and nm != def.stages[0].name_key and text.contains(nm):
			named.append(def.id)
	if not _ok(not named.is_empty(), "anciãos", "%s: o texto '%s' não indica de qual monstro vem o item" % [where, text]):
		return
	for sp: StringName in named:
		var sources: Array[String] = []
		for r: Resource in Content.all(&"monsters").values():
			var def: MonsterDef = r as MonsterDef
			if _species(def.id) != sp:
				continue
			var lists: Array = [def.rare_extra_drops]
			for st: MonsterStage in def.stages:
				if st.stage >= CombatRules.STAGE_BOSS:
					lists.append(st.drops)
			for l: Variant in lists:
				for d: DropEntry in l:
					if d.item_id == s.target_id and not _spawns_of(sp).is_empty():
						sources.append(String(def.id))
		_ok(not sources.is_empty(), "anciãos", "%s: '%s' não cai do %s raro/chefe (o texto indica esse monstro)" % [where, s.target_id, sp])


# ================================================================ skills e títulos

func _check_skills() -> void:
	for r: Resource in Content.all(&"skills").values():
		var sk: SkillDef = r as SkillDef
		var cat: String = "skills"
		var id: String = String(sk.id)
		# O cliente usa assets/skills/<id>.png (HotbarSlot.SKILL_ICON_DIR); SkillDef.icon é opcional.
		_ok(sk.icon != null or _res_exists("%s%s.png" % [HotbarSlot.SKILL_ICON_DIR, id]), cat, "%s: sem ícone (%s%s.png)" % [id, HotbarSlot.SKILL_ICON_DIR, id])
		_ok(SkillFx.recipe_for(sk) != &"", cat, "%s: sem efeito visual (SkillFxBook/vfx)" % id)
		_key(sk.name_key, "skill %s (name_key)" % id)
		_key(sk.desc_key, "skill %s (desc_key)" % id)
		var school: StringName = SkillFxBook.school_of(sk)
		_ok(school in SCHOOLS, cat, "%s: escola '%s' inválida" % [id, school])
		if not sk.tree_title.is_empty():
			_ok(Content.title(sk.tree_title) != null, cat, "%s: tree_title '%s' não existe" % [id, sk.tree_title])
		if not sk.exclusive_to_title.is_empty():
			_ok(Content.title(sk.exclusive_to_title) != null, cat, "%s: exclusive_to_title '%s' não existe" % [id, sk.exclusive_to_title])
		for req: StringName in sk.required_skill_levels:
			var rd: SkillDef = Content.skill(req)
			if _ok(rd != null, cat, "%s: pré-requisito '%s' não existe" % [id, req]):
				_ok(req != sk.id and sk.required_skill_levels[req] <= rd.max_level, cat,
						"%s: pré-requisito %s nível %d impossível (máx %d)" % [id, req, sk.required_skill_levels[req], rd.max_level])
		_ok(_skill_sources.has(sk.id), cat, "%s: nenhuma quest (com NPC posicionado) ensina esta skill" % id)
	# Magias automáticas dos companheiros (data/companion_skills/): textos, efeito e dono.
	var used: Dictionary = {}
	for r: Resource in Content.all(&"companions").values():
		for spell: StringName in (r as CompanionDef).spells:
			used[spell] = true
			_ok(Content.companion_skill(spell) != null, "skills", "%s: magia '%s' não existe" % [(r as CompanionDef).id, spell])
	for r: Resource in Content.all(&"companion_skills").values():
		var sk: SkillDef = r as SkillDef
		_key(sk.name_key, "magia de companheiro %s (name_key)" % sk.id)
		_key(sk.desc_key, "magia de companheiro %s (desc_key)" % sk.id)
		_ok(SkillFx.recipe_for(sk) != &"", "skills", "%s: magia de companheiro sem efeito visual" % sk.id)
		_ok(used.has(sk.id), "skills", "%s: nenhum companheiro usa esta magia" % sk.id)


func _check_titles() -> void:
	for r: Resource in Content.all(&"titles").values():
		var t: TitleDef = r as TitleDef
		var cat: String = "títulos"
		var id: String = String(t.id)
		_key(t.name_key, "título %s (name_key)" % id)
		_key(t.desc_key, "título %s (desc_key)" % id, t.id != &"traveler")
		if not t.parent_title.is_empty():
			_ok(Content.title(t.parent_title) != null, cat, "%s: parent_title '%s' não existe" % [id, t.parent_title])
		if not t.master_npc.is_empty():
			_ok(_npc_placed(t.master_npc), cat, "%s: master_npc '%s' não existe/posicionado" % [id, t.master_npc])
		for s: StringName in t.required_skills:
			if _ok(Content.skill(s) != null, cat, "%s: required_skills '%s' não existe" % [id, s]) and not t.quest_only:
				_ok(_skill_sources.has(s), cat, "%s: pede a skill '%s', que nenhuma quest ensina" % [id, s])
		for rt: StringName in t.required_titles:
			_ok(Content.title(rt) != null, cat, "%s: required_titles '%s' não existe" % [id, rt])
		var auto: bool = not t.quest_only and not t.required_skills.is_empty()
		if t.id != &"traveler":
			_ok(auto or _title_sources.has(t.id), cat, "%s: não é automático e nenhuma quest dá este título" % id)
		if not t.outfit_id.is_empty():
			for body: StringName in BODIES:
				for anim: String in OUTFIT_REQUIRED:
					var path: String = "res://assets/characters/outfits/chr_%s_%s_%s.png" % [body, t.outfit_id, anim]
					_ok(_res_exists(path), cat, "%s: roupa %s sem folha %s (%s)" % [id, t.outfit_id, anim, body])
				var missing: Array[String] = []
				for anim: StringName in CharacterLayers.ANIMS:
					if not OUTFIT_IGNORED.has(anim) and not _res_exists("res://assets/characters/outfits/chr_%s_%s_%s.png" % [body, t.outfit_id, anim]):
						missing.append(String(anim))
				if not missing.is_empty():
					_warn(cat, "%s: roupa %s (%s) sem as folhas opcionais %s" % [id, t.outfit_id, body, ", ".join(missing)])


## Materiais de quest de título (etapa COLLECT de quest com reward_title) e de ofício (SkillDef CRAFT,
## extra.materials): têm de cair de um monstro posicionado num mapa de combate (fora do treino). A quest só conta
## item pego do chão pelo próprio personagem, então loja não basta. Material de ofício que outro ofício produz
## (extra.craft_item, ex.: Flecha Simples) vale pela receita, cujos materiais também passam por aqui.
func _check_material_sources() -> void:
	var cat: String = "materiais"
	var crafted: Dictionary[StringName, String] = {}
	var needs: Dictionary[StringName, Array] = {}  # item -> onde é pedido
	for r: Resource in Content.all(&"skills").values():
		var sk: SkillDef = r as SkillDef
		if sk.effect != SkillDef.Effect.CRAFT:
			continue
		var out_item := StringName(str(sk.extra.get(&"craft_item", "")))
		if not out_item.is_empty():
			crafted[out_item] = String(sk.id)
		var mats: Variant = sk.extra.get(&"materials", {})
		if mats is Dictionary:
			for m: Variant in (mats as Dictionary).keys():
				var item := StringName(str(m))
				if not needs.has(item):
					needs[item] = []
				needs[item].append("ofício %s" % sk.id)
	for r: Resource in Content.all(&"quests").values():
		var q: QuestDef = r as QuestDef
		if q.reward_title.is_empty():
			continue
		for s: QuestStep in q.steps:
			if s.type != QuestStep.StepType.COLLECT or s.target_id.is_empty():
				continue
			if not needs.has(s.target_id):
				needs[s.target_id] = []
			needs[s.target_id].append("quest de título %s" % q.id)
	var items: Array = needs.keys()
	items.sort()
	for item: StringName in items:
		if not _ok(Content.item(item) != null, cat, "'%s' não existe (pedido em %s)" % [item, ", ".join(needs[item])]):
			continue
		var only_craft: bool = true
		for where: String in needs[item]:
			only_craft = only_craft and where.begins_with("ofício")
		if only_craft and crafted.has(item):
			continue
		_ok(not _drops_from_spawn(item).is_empty(), cat,
				"'%s' não cai de nenhum monstro posicionado em mapa (pedido em %s)" % [item, ", ".join(needs[item])])


# ================================================================ textos

func _check_translations() -> void:
	var keys: Array = _keys.keys()
	keys.sort()
	for k: String in keys:
		_ok(_tr(k) != k, "localização", "%s sem tradução pt_BR (usada em %s)" % [k, _keys[k]])


func _check_werewolf_beta_routes() -> void:
	var routes: Dictionary = {
		&"werewolf_hunt": &"hunter",
		&"werewolf_heal": &"healer",
		&"werewolf_pact": &"pact",
	}
	for quest_id: StringName in routes:
		var q: QuestDef = Content.quest(quest_id)
		if not _ok(q != null, "lobisomem", "quest final %s carregada" % quest_id):
			continue
		_ok(q.reward_causo_id == &"lobisomem_arc", "lobisomem",
				"%s compartilha o Causo único do arco" % quest_id)
		_ok(q.required_story_id == &"lobisomem_arc" and q.required_story_clues == 3
				and q.required_story_route == routes[quest_id], "lobisomem",
				"%s exige pistas e sua rota" % quest_id)
	var hunt: QuestDef = Content.quest(&"werewolf_hunt")
	var heal: QuestDef = Content.quest(&"werewolf_heal")
	var pact: QuestDef = Content.quest(&"werewolf_pact")
	if hunt != null and not hunt.steps.is_empty():
		var hunt_step: QuestStep = hunt.steps[0]
		_ok(hunt_step.target_id == &"werewolf" and hunt_step.trial_stage == 3
				and hunt_step.trial_requires_full_moon, "lobisomem",
				"Caçador enfrenta o estágio 3 durante lua cheia")
	if heal != null and not heal.steps.is_empty():
		_ok(heal.steps[0].target_id == &"ThreeRoads", "lobisomem",
				"Benzedura usa o marcador da encruzilhada")
	if pact != null and not pact.steps.is_empty():
		_ok(pact.required_story_observations == 3 and pact.steps[0].target_id == &"PactOffering",
				"lobisomem", "Pacto exige três observações e a oferenda")


# ================================================================ relatório

func _report() -> void:
	var total: int = 0
	var strict: bool = "--strict" in OS.get_cmdline_user_args()
	var pending: Array[String] = []
	if not strict:
		for c: String in _fails.keys():
			var keep: Array = []
			for m: Variant in _fails[c]:
				var reason: String = ""
				for frag: String in PENDING_DECISIONS:
					if String(m).contains(frag):
						reason = PENDING_DECISIONS[frag]
				if reason.is_empty():
					keep.append(m)
				else:
					pending.append("[%s] %s — decisão: %s" % [c, m, reason])
			if keep.is_empty():
				_fails.erase(c)
			else:
				_fails[c] = keep
	print("\n=== CONTENT LINKS — mapas carregados: %s" % ", ".join(_maps.keys()))
	var cats: Array = _fails.keys()
	cats.sort()
	for c: String in cats:
		var list: Array = _fails[c]
		total += list.size()
		print("--- FAIL [%s] (%d)" % [c, list.size()])
		for m: Variant in list:
			print("  FAIL [%s] %s" % [c, m])
	if not pending.is_empty():
		print("--- PENDENTE: decisão do dono (%d; --strict reprova)" % pending.size())
		for m: String in pending:
			print("  PENDENTE %s" % m)
	if not _warns.is_empty():
		print("--- avisos (%d)" % _warns.size())
		for w: String in _warns:
			print("  WARN %s" % w)
	print("CONTENT LINKS: %d checks, %d failures, %d pending, %d warnings" % [_checks, total, pending.size(), _warns.size()])
	print("RESULT: %s" % ("PASS" if total == 0 else "FAIL"))
	for map_id: StringName in _maps:
		(_maps[map_id]["node"] as Node).queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if total == 0 else 1)
