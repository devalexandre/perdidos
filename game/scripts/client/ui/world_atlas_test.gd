extends SceneTree
## Teste visual do atlas do mundo (Agente G). Renderiza a tela em 1920x1080 e 1280x720, com zoom e
## com a dica aberta, e salva capturas. Também confere os dados (posições dentro do mapa, chaves
## traduzidas, "você está aqui" pelo map_id).
## Uso: xvfb-run -a -s "-screen 0 2560x1440x24" godot --path game -s res://scripts/client/ui/world_atlas_test.gd -- <pasta>

var _out: String = "user://"
var _fail: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0].trim_suffix("/") + "/"
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fail += 1
		printerr("FALHOU: ", msg)


func _run() -> void:
	var atlas_def: WorldAtlasDef = load(WorldAtlasDef.DEFAULT_PATH) as WorldAtlasDef
	_check(atlas_def != null and atlas_def.map_texture != null, "atlas.tres e textura carregam")
	_check(atlas_def.regions.size() == 10, "10 regiões")
	var ids: Dictionary = {}
	for p: WorldPlaceDef in atlas_def.all_places():
		_check(not ids.has(p.id), "id repetido %s" % p.id)
		ids[p.id] = true
		_check(p.pos.x > 0.02 and p.pos.x < 0.98 and p.pos.y > 0.02 and p.pos.y < 0.98, "posição fora %s" % p.id)
		_check(tr(p.name_key) != p.name_key, "sem tradução %s" % p.name_key)
		_check(tr(p.hook_key) != p.hook_key, "sem tradução %s" % p.hook_key)
	for r: WorldRegionDef in atlas_def.regions:
		_check(tr(r.name_key) != r.name_key, "sem tradução %s" % r.name_key)
	_check(atlas_def.place_for_map(&"training_field").id == &"campo_treino", "training_field → Campo de Treino")
	_check(atlas_def.place_for_map(&"city_awakening").id == &"porto_despertar", "city_awakening → Porto")
	_check_zone_coverage(atlas_def)
	print("atlas: %d lugares" % ids.size())

	for res: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = res
		DisplayServer.window_set_size(res)
		await _frames(4)
		var atlas := WorldAtlas.new()
		atlas.map_id_override = &"city_awakening"
		WorldAtlas.keep_open = false
		WorldAtlas.saved_zoom = 1.0
		WorldAtlas.saved_center = Vector2(0.5, 0.5)
		root.add_child(atlas)
		atlas.open()
		await _frames(6)
		_check(atlas.current_place() != null and atlas.current_place().id == &"porto_despertar", "você está aqui")
		_check(atlas._sidebar.get_rect().end.y <= atlas.size.y - 20, "índice não cobre a legenda")
		_check(atlas._region_buttons.size() == 10, "índice das dez regiões")
		_check(atlas._hits.size() < 30, "visão geral sem excesso de marcadores")
		_check_labels(atlas)
		_shot("atlas_%d_fit.png" % res.y)
		atlas.focus_place(atlas_def.place(&"porto_despertar"), 2.2)
		atlas.hover_place(atlas_def.place(&"vagao_adormecido"))
		await _frames(6)
		_check_labels(atlas)
		_shot("atlas_%d_zoom_pindorama.png" % res.y)
		atlas.focus_place(atlas_def.place(&"capsula_estrela"), 2.6)
		atlas.hover_place(atlas_def.place(&"capsula_estrela"))
		await _frames(6)
		_shot("atlas_%d_zoom_areias.png" % res.y)
		atlas.set_zoom(4.0)
		atlas.hover_place(null)
		await _frames(4)
		_shot("atlas_%d_zoom_max.png" % res.y)
		atlas.close()
		_check(not atlas.visible, "fecha")
		atlas.queue_free()
		await _frames(2)
	# Telas largas de celular e PC, com o jogador no Porto e na Serra Dourada (zoom na Terra de Pindorama).
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(800, 360), Vector2i(1600, 720)]:
		for map_id: StringName in [&"city_awakening", &"city_serra_dourada"]:
			root.size = res
			DisplayServer.window_set_size(res)
			await _frames(4)
			var atlas := WorldAtlas.new()
			atlas.map_id_override = map_id
			WorldAtlas.keep_open = false
			WorldAtlas.saved_zoom = 1.0
			WorldAtlas.saved_center = Vector2(0.5, 0.5)
			root.add_child(atlas)
			atlas.open()
			await _frames(4)
			_check(atlas.current_place() == atlas_def.place_for_map(map_id), "você está aqui em %s" % map_id)
			_shot("atlas_%dx%d_%s_fit.png" % [res.x, res.y, map_id])
			atlas.focus_place(atlas_def.place(&"chapada_ceu_partido"), 2.4)
			await _frames(4)
			_check_labels(atlas)
			_shot("atlas_%dx%d_%s_pindorama.png" % [res.x, res.y, map_id])
			atlas.queue_free()
			await _frames(2)
	print("world_atlas_test: %s" % ("OK" if _fail == 0 else "%d falha(s)" % _fail))
	quit(1 if _fail else 0)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(file: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(_out + file)
	print("captura: ", _out + file, " ", img.get_size())


func _check_labels(atlas: WorldAtlas) -> void:
	var boxes: Array[Rect2] = atlas._label_boxes
	var bounds := Rect2(Vector2.ZERO, atlas._view.size)
	for i: int in boxes.size():
		_check(bounds.encloses(boxes[i]), "rótulo inteiro dentro do mapa")
		for j: int in range(i + 1, boxes.size()):
			_check(not boxes[i].intersects(boxes[j]), "rótulos sem sobreposição")


## Toda cidade e área de caça real (data/zones, menos a arena de provação) tem lugar no atlas, e o
## "você está aqui" reconhece cada andar (map_ids).
func _check_zone_coverage(atlas_def: WorldAtlasDef) -> void:
	var dir: String = "res://data/zones/"
	var n: int = 0
	for file: String in ResourceLoader.list_directory(dir):
		if not file.ends_with(".tres"):
			continue
		var zone := load(dir + file) as ZoneDef
		if zone == null or zone.kind not in [ZoneDef.Kind.CITY, ZoneDef.Kind.HUNT] or zone.map_id == &"elder_trial_arena":
			continue
		n += 1
		var place: WorldPlaceDef = atlas_def.place_for_map(zone.map_id)
		_check(place != null, "mapa %s sem lugar no atlas" % zone.map_id)
		if place != null:
			_check(place.status == WorldPlaceDef.Status.OPEN, "lugar de %s aberto" % zone.map_id)
			if zone.recommended_level_max > 0:
				_check(place.level_min <= zone.recommended_level_min and place.level_max >= zone.recommended_level_max,
						"níveis de %s cobrem %s" % [place.id, zone.map_id])
	_check(n >= 46, "zonas CITY/HUNT carregadas (%d)" % n)
	_check(atlas_def.place_for_map(&"city_serra_dourada").id == &"serra_dourada", "Serra Dourada")
	_check(atlas_def.place_for_map(&"city_sumidouro").id == &"arraial_sumidouro", "Arraial do Sumidouro")
	_check(atlas_def.place_for_map(&"hollow_earth_5").id == &"terra_oca", "andar F5 da Terra Oca")
	_check(atlas_def.place_for_map(&"elder_trial_arena") == null, "arena de provação fora do atlas")
