extends Node
## Rotina de NPC por horário, diário da história e cena da fala da lenda (ARCO-1-TERRA-DE-PINDORAMA.md §5, §10.6):
##  - NpcDef.presence: o menino Curupira some à noite; oculto, o servidor não resolve o alvo, não abre diálogo
##    e fecha a conversa aberta; o cliente apaga o visual devagar e tira o clique;
##  - aba "Fragmentos" do diário (4 fragmentos, silhueta "???" para o que falta) e o objetivo aberto
##    "Onde está Maria?" depois de entregar arc1_final_boitata;
##  - cena da vitória de história só para quem ganhou o crédito (lenda comum e a memória do rio do Boitatá).
## Rodar (sem tela): godot --headless --path game res://tests/story/test_story_journal.tscn
## Capturas (com tela): xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --resolution 1280x720 \
##     res://tests/story/test_story_journal.tscn -- --out=/caminho

const NPC_ID: int = NetEntity.NPC_ID_BASE + 900
const FOREST: StringName = &"enchanted_forest_roots"
const FINAL: StringName = &"arc1_final_boitata"

var _checks: int = 0
var _failures: int = 0
var _out_dir: String = ""
var world: ServerWorld = null
var quests: QuestService = null
var _entities: Array[NetEntity] = []
var _pushed: Array[Array] = []


func _ready() -> void:
	TranslationServer.set_locale("pt_BR")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	Net.is_server = true
	world = ServerWorld.new()
	world.progression = Progression.new(world)
	quests = world.progression.quests
	NetProgress.story_scene_pushed.connect(func(peer: int, scene: Dictionary) -> void: _pushed.append([peer, scene]))
	_test_npc_presence_data()
	_test_npc_presence_server()
	_test_npc_presence_client()
	_test_fragments()
	_test_goal()
	await _test_quest_log_ui()
	_test_scene_credit()
	await _test_scene_ui()
	DayNight.set_force(WorldClock.Force.NONE)
	for e: NetEntity in _entities:
		e.free()
	world.free()
	print("test_story_journal: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String, detail: Variant = null) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL %s %s" % [what, str(detail) if detail != null else ""])


func _entity(id: int, kind: StringName, name: String, def_id: StringName, instance: StringName) -> NetEntity:
	var entity := NetEntity.new()
	var sync := MultiplayerSynchronizer.new()
	sync.name = NetEntity.SYNC_NODE_NAME
	entity.add_child(sync)
	entity.server_setup(id, kind, name, def_id, instance, Vector3(2, 0, 2))
	world._entities[id] = entity
	_entities.append(entity)
	return entity


func _session(peer: int, name: String, instance: StringName = &"city_awakening") -> PlayerSession:
	var entity: NetEntity = _entity(peer, &"player", name, &"male", instance)
	var c := CharacterData.create_new(name, &"male")
	c.left_training = true
	var s := PlayerSession.new(peer, entity, c)
	world._sessions[peer] = s
	return s


func _put_on_step(s: PlayerSession, id: StringName, step: int) -> void:
	var q: QuestDef = Content.quest(id)
	s.character.progression.quests[id] = {ProgressionData.Q_STEP: step, ProgressionData.Q_COUNT: 0,
			ProgressionData.Q_NEEDS: QuestService.needs_for(q, 0)}


func _ritual_index(id: StringName) -> int:
	return Content.quest(id).steps.size() - 1


func _shot(file: String) -> void:
	if _out_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var path: String = _out_dir.path_join(file + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved " + path)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


# ================================================================ NPC por horário

func _test_npc_presence_data() -> void:
	var d := NpcDef.new()
	_check(d.presence == NpcDef.Presence.ALWAYS and d.is_present(true) and d.is_present(false), "padrão: sempre")
	d.presence = NpcDef.Presence.DAY_ONLY
	_check(d.is_present(false) and not d.is_present(true), "só de dia")
	d.presence = NpcDef.Presence.NIGHT_ONLY
	_check(d.is_present(true) and not d.is_present(false), "só de noite")
	var boy: NpcDef = Content.npc(&"curupira")
	_check(boy != null and boy.presence == NpcDef.Presence.DAY_ONLY, "o menino Curupira só aparece de dia")
	DayNight.set_force(WorldClock.Force.NIGHT)
	_check(not boy.is_present_now(), "à noite (relógio) o menino some")
	DayNight.set_force(WorldClock.Force.DAY)
	_check(boy.is_present_now(), "de dia o menino volta")
	_check(Content.npc(&"dona_jacinta").is_present_now(), "NPC sem rotina continua de noite e de dia")


func _test_npc_presence_server() -> void:
	var interaction := InteractionService.new(world)
	var dialogue := DialogueRunner.new(world)
	world.dialogue = dialogue
	var npc: NetEntity = _entity(NPC_ID, NetEntity.KIND_NPC, "NPC_CURUPIRA_NAME", &"curupira", FOREST)
	var s: PlayerSession = _session(501, "Lia", FOREST)
	s.entity.net_position = npc.net_position + Vector3(0.5, 0, 0)
	var target: String = npc.get_target_id()
	DayNight.set_force(WorldClock.Force.DAY)
	_check(not interaction.resolve(s, target).is_empty(), "de dia: o menino é um alvo válido")
	dialogue.start(s, npc)
	_check(s.has_dialogue(), "de dia: conversa abre (quest oferecida)")
	DayNight.set_force(WorldClock.Force.NIGHT)
	dialogue.check_range(s)
	_check(not s.has_dialogue(), "anoiteceu: a conversa aberta fecha")
	_check(interaction.resolve(s, target).is_empty(), "à noite: o menino não é alvo (não oferece diálogo/quest)")
	dialogue.start(s, npc)
	_check(not s.has_dialogue(), "à noite: diálogo não abre nem por chamada direta")
	DayNight.set_force(WorldClock.Force.DAY)
	dialogue.start(s, npc)
	_check(s.has_dialogue(), "amanheceu: volta a conversar")
	dialogue.close(s, false)


func _test_npc_presence_client() -> void:
	var v: EntityVisual = EntityVisualFactory.create_from(NetEntity.KIND_NPC, &"curupira", NPC_ID, "")
	add_child(v)
	_check(v.presence_def != null, "visual do menino liga a rotina por horário")
	DayNight.set_force(WorldClock.Force.NIGHT)
	v._update_presence(0.5)
	_check(v.presence > 0.0 and v.presence < 1.0 and v.visible, "anoitecer: some devagar (não pisca)", v.presence)
	v._update_presence(EntityVisual.PRESENCE_FADE_SEC)
	_check(v.presence == 0.0 and not v.visible, "à noite: sumiu", v.presence)
	_check(v.get_pick_area().collision_layer == 0, "à noite: não dá para clicar")
	DayNight.set_force(WorldClock.Force.DAY)
	v._update_presence(EntityVisual.PRESENCE_FADE_SEC)
	_check(v.presence == 1.0 and v.visible and v.get_pick_area().collision_layer == EntityVisual.PICK_LAYER,
			"de dia: voltou e é clicável")
	var other: EntityVisual = EntityVisualFactory.create_from(NetEntity.KIND_NPC, &"dona_jacinta", NPC_ID + 1, "")
	_check(other.presence_def == null, "NPC sem rotina não liga o apagar")
	other.free()
	v.queue_free()


# ================================================================ fragmentos e objetivo

func _test_fragments() -> void:
	var list: Array[Dictionary] = StoryFragments.list({}, [])
	var ids: Array[StringName] = []
	for f: Dictionary in list:
		ids.append(f["item"])
		_check(not f["obtained"], "sem progresso: %s falta" % f["item"])
		_check(f["icon"] != null, "fragmento %s tem ícone" % f["item"])
		for k: String in [str(f["name_key"]), str(f["lore_key"]), str(f["kind_key"])]:
			_check(TranslationServer.translate(k) != k, "texto %s traduzido" % k)
		_check(not TranslationServer.translate(str(f["lore_key"])).contains("Maria"),
				"o texto do fragmento não revela o nome (só o final revela)", f["item"])
	_check(ids == [&"mother_of_pearl_comb", &"dolphin_rubbing", &"boiuna_words", &"river_memory"],
			"os 4 fragmentos na ordem da história", ids)
	var iara_r: int = _ritual_index(&"arc1_ch6_iara")
	var p: Dictionary = {"quests": [{"id": "arc1_ch6_iara", "step": iara_r, "ready": false}]}
	_check(not StoryFragments.is_obtained(StoryFragments.FRAGMENTS[0], p), "no ritual da Iara: pente ainda não")
	p = {"quests": [{"id": "arc1_ch6_iara", "step": iara_r + 1, "ready": true}]}
	_check(StoryFragments.is_obtained(StoryFragments.FRAGMENTS[0], p), "venceu a Iara: pente obtido")
	p = {"quests_done": ["arc1_ch7_mapinguari"]}
	_check(StoryFragments.is_obtained(StoryFragments.FRAGMENTS[1], p), "Mapinguari entregue: decalque obtido")
	_check(StoryFragments.is_obtained(StoryFragments.FRAGMENTS[2], {}, [{"item": &"boiuna_words", "qty": 1}]),
			"na mochila: palavras da Boiúna obtidas")
	# Pelo servidor de verdade: vitória sobre a Iara entrega o pente e o diário mostra.
	var s: PlayerSession = _session(601, "Rui")
	_put_on_step(s, &"arc1_ch6_iara", iara_r)
	quests.on_story_boss_killed(&"story_iara", [601])
	var snap: Dictionary = {"quests": quests.snapshot(s), "quests_done": []}
	_check(StoryFragments.obtained_count(snap) == 1 and StoryFragments.list(snap)[0]["obtained"],
			"servidor: vitória da Iara -> 1 fragmento no diário")


func _test_goal() -> void:
	_check(StoryFragments.open_goals({}).is_empty(), "sem o final: nenhum objetivo aberto")
	_check(StoryFragments.open_goals({"quests": [{"id": String(FINAL), "step": 2, "ready": true}]}).is_empty(),
			"final vencido mas não entregue: ainda não")
	var goals: Array[Dictionary] = StoryFragments.open_goals({"quests_done": [String(FINAL)]})
	_check(goals.size() == 1 and goals[0]["id"] == &"arc1_where_is_maria", "final entregue: \"Onde está Maria?\"")
	_check(TranslationServer.translate("JOURNAL_GOAL_WHERE_IS_MARIA") == "Onde está Maria?", "título do objetivo")


func _test_quest_log_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color8(46, 70, 52)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var w := QuestLogWindow.new(1.0)
	add_child(w)
	var progress: Dictionary = {"causos": 11, "causos_rank": "CAUSOS_FORASTEIRO",
			"quests": [], "quests_done": ["arc1_ch6_iara", "arc1_ch7_mapinguari", String(FINAL)]}
	w.inventory_slots = [{"item": &"boiuna_words", "qty": 1}]
	w.open()
	w.set_progress(progress)
	await get_tree().process_frame
	_check(w.find_child("Goal_arc1_where_is_maria", true, false) != null, "aba Missões: objetivo \"Onde está Maria?\"")
	await _shot("journal_goal")
	w.set_tab(QuestLogWindow.TAB_FRAGMENTS)
	await get_tree().process_frame
	await get_tree().process_frame
	var cards: int = 0
	for f: Dictionary in StoryFragments.FRAGMENTS:
		var card: Node = w.find_child("Fragment_" + String(f["item"]), true, false)
		if card != null:
			cards += 1
			_check(bool(card.get_meta(&"obtained")), "aba Fragmentos: %s obtido" % f["item"])
	_check(cards == 4, "aba Fragmentos: 4 cartões", cards)
	await _shot("journal_fragments")
	progress["quests_done"] = ["arc1_ch6_iara"]
	w.inventory_slots = [{"item": &"potion_hp_small", "qty": 1}]
	w.set_progress(progress)
	await get_tree().process_frame
	var missing: Node = w.find_child("Fragment_dolphin_rubbing", true, false)
	var title: Label = missing.find_child("Name", true, false) as Label if missing != null else null
	_check(missing != null and not bool(missing.get_meta(&"obtained")) and title != null and title.text == "???",
			"fragmento que falta: silhueta e ???")
	_check(w.find_child("FragmentsIntro", true, false) != null
			and (w.find_child("FragmentsIntro", true, false) as Label).text.contains("1 de 4"), "contagem 1 de 4")
	await _shot("journal_fragments_missing")
	w.queue_free()
	bg.queue_free()


# ================================================================ cena da vitória

func _test_scene_credit() -> void:
	_pushed.clear()
	var r: int = _ritual_index(&"arc1_ch4_curupira")
	var a: PlayerSession = _session(701, "Ana")       # no ritual, lutou
	var b: PlayerSession = _session(702, "Bento")     # sem a quest, lutou
	var c: PlayerSession = _session(703, "Cida")      # no ritual, não lutou
	for x: PlayerSession in [a, c]:
		_put_on_step(x, &"arc1_ch4_curupira", r)
		var item: StringName = Content.quest(&"arc1_ch4_curupira").steps[r].ritual_item
		if not item.is_empty():
			x.character.inventory.add(item, 1)
	quests.on_story_boss_killed(&"story_curupira", [701, 702])
	var peers: Array[int] = []
	for e: Array in _pushed:
		peers.append(int(e[0]))
	_check(peers == [701], "cena só para quem ganhou o crédito (Ana)", peers)
	var scene: Dictionary = _pushed[0][1] if not _pushed.is_empty() else {}
	_check(scene.get("style") == "legend" and scene.get("monster") == "story_curupira"
			and "QUEST_ARC1_CH4_DONE_4" in scene.get("pages", []), "cena do Curupira: fala da lenda", scene)
	_check(quests.is_ready(a, &"arc1_ch4_curupira") and not quests.is_ready(c, &"arc1_ch4_curupira"), "crédito igual")
	_pushed.clear()
	var d: PlayerSession = _session(704, "Davi")
	_put_on_step(d, FINAL, _ritual_index(FINAL))
	quests.on_story_boss_killed(&"story_boitata", [704, 701])
	_check(_pushed.size() == 1 and int(_pushed[0][0]) == 704, "Boitatá: só Davi (Ana não está no final)")
	var mem: Dictionary = _pushed[0][1] if not _pushed.is_empty() else {}
	_check(mem.get("style") == "memory" and "river_memory" in mem.get("items", []), "Boitatá: memória do rio", mem)


func _test_scene_ui() -> void:
	var legend: Dictionary = StoryFragments.make_scene(&"arc1_ch6_iara", &"story_iara", "QUEST_ARC1_CH6_DONE_5",
			["QUEST_ARC1_CH6_DONE_5"], [&"mother_of_pearl_comb"])
	var pages: Array[Dictionary] = StoryScene.build_pages(legend)
	_check(pages.size() >= 2, "fala longa vira páginas", pages.size())
	var joined: String = ""
	for p: Dictionary in pages:
		joined += str(p["text"]) + " "
		_check(str(p["text"]).length() <= StoryScene.PAGE_MAX_CHARS + 60, "página curta", str(p["text"]).length())
	_check(joined.contains("Pegue isto") and joined.contains("O canto quebra"), "nenhum pedaço da fala se perde")
	var memory: Dictionary = StoryFragments.make_scene(FINAL, &"story_boitata", "QUEST_ARC1_FINAL_DONE_2",
			["QUEST_ARC1_FINAL_DONE_2"], [&"river_memory"])
	var mp: Array[Dictionary] = StoryScene.build_pages(memory)
	var kinds: Array[StringName] = []
	for p: Dictionary in mp:
		kinds.append(p["kind"])
	_check(kinds == [StoryScene.PAGE_LEGEND, StoryScene.PAGE_VISION, StoryScene.PAGE_LINE, StoryScene.PAGE_LINE],
			"memória: fala, lembrança e as duas falas", kinds)
	_check(TranslationServer.translate("STORY_MEMORY_LINE_1") == "A filha do Devorador nunca morreu."
			and TranslationServer.translate("STORY_MEMORY_LINE_2") == "Ela escolheu desaparecer.", "falas exatas")
	_check(StoryScene.portrait_for(Content.monster(&"story_curupira").atroz_stage()) != null, "retrato do Curupira")

	var bg := ColorRect.new()
	bg.color = Color8(52, 88, 60)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sc := StoryScene.new()
	add_child(sc)
	var done: Array[int] = [0]
	sc.finished.connect(func() -> void: done[0] += 1)
	sc.play(StoryFragments.make_scene(&"arc1_ch4_curupira", &"story_curupira", "QUEST_ARC1_CH4_DONE_4",
			["QUEST_ARC1_CH4_DONE_4"], []))
	sc.play(memory)
	_check(sc.is_playing() and sc.describe()["queued"] == 1, "segunda cena entra na fila")
	_check(sc.describe()["name"] == "Curupira", "placa com o nome da lenda calma", sc.describe()["name"])
	await _wait(0.6)
	await _shot("scene_legend")
	var guard: int = 0
	while sc.describe()["style"] == "legend" and guard < 20:
		sc.advance()
		sc.advance()
		await _wait(0.05)
		guard += 1
	await _wait(0.6)
	_check(done[0] == 1 and sc.is_playing() and sc.describe()["style"] == "memory", "Curupira fechou; começa a memória")
	_check(sc.describe()["name"] == "Boitatá", "memória: placa do Boitatá")
	await _wait(0.5)
	await _shot("scene_memory_intro")
	sc.advance()
	sc.advance()
	_check(sc.describe()["kind"] == StoryScene.PAGE_VISION, "lembrança com escurecimento", sc.describe())
	await _wait(1.9)
	await _shot("scene_memory_vision")
	sc.advance()
	await _wait(1.0)
	_check(sc.describe()["line1"] == "A filha do Devorador nunca morreu." and sc.describe()["line2"] == "",
			"1ª fala em destaque (sozinha)")
	await _shot("scene_memory_line1")
	sc.advance()
	await _wait(1.0)
	_check(sc.describe()["line2"] == "Ela escolheu desaparecer.", "2ª fala em destaque")
	_check(str(sc.describe()["fragment"]).contains("Memória do Rio"), "fragmento recebido na última página")
	await _shot("scene_memory_lines")
	sc.advance()
	await _wait(0.6)
	_check(not sc.is_playing() and not sc.visible and done[0] == 2, "última página fecha a cena")
	sc.play(legend)
	sc.skip()
	await _wait(0.6)
	_check(not sc.is_playing() and done[0] == 3, "Esc pula a cena")
	sc.queue_free()
	bg.queue_free()
