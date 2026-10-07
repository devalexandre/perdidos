extends Node
## Captura das janelas da interface NO CLIENTE REAL (regra do dono: visual só é "pronto" com captura do
## jogo no ponto de nascimento). Criado pelo main.gd com --autotest
## --autotest-script=res://tests/client/ui_capture.gd --shot-dir=DIR [--ui-mobile] [--ui-tag=nome]
## (tests/client/run_ui_capture.sh). Abre uma janela por vez (skills, diário, inventário + personagem,
## loja, atributos, diálogo, menu) com dados de exemplo por cima do estado real e salva DIR/<tag>_<janela>.png.

const ARG_SHOT_DIR: String = "shot-dir"
const ARG_MOBILE: String = "ui-mobile"
const ARG_TAG: String = "ui-tag"
const SETTLE_SEC: float = 4.0
const STEP_SEC: float = 0.6
const SAMPLE_TITLES: Array[StringName] = [&"sabia_blade_machete", &"sabia_blade_jaguar", &"sabia_bow_cerrado",
	&"sabia_arcane_firefly", &"sabia_support_buriti", &"sabia_tank_jabuti", &"sabia_hybrid_ember",
	&"sabia_arcane_boitata", &"sabia_tank_mapinguari"]
const SAMPLE_ITEMS: Array[StringName] = [&"potion_hp_small", &"potion_mp_small", &"machete", &"simple_bow",
	&"straw_hat", &"leather_jerkin", &"seed_necklace", &"return_scroll", &"simple_arrow"]
const DIALOGUE_NPC: StringName = &"fruit_vendor"

var main_node: Node = null
var args: Dictionary[String, String] = {}
var _started: bool = false
var _ui: GameUI = null
var _tag: String = ""
var _was_mobile: bool = false


func _ready() -> void:
	Net.local_player_spawned.connect(_on_spawned)
	get_tree().create_timer(180.0).timeout.connect(func() -> void:
		print("ui_capture_timeout")
		get_tree().quit(2))


func _on_spawned(_p: Node3D) -> void:
	if _started:
		return
	_started = true
	await _wait(SETTLE_SEC)
	var view: Node = main_node.get("client_view") if main_node != null else null
	_ui = view.call(&"get_game_ui") as GameUI if view != null else null
	if _ui == null:
		print("ui_capture_no_ui")
		get_tree().quit(1)
		return
	_was_mobile = GameSettings.get_instance().mobile_controls
	var size: Vector2 = _ui.get_viewport_rect().size
	_tag = args.get(ARG_TAG, "%s_%dx%d" % ["mobile" if args.has(ARG_MOBILE) else "desktop", int(size.x), int(size.y)])
	# Modo pedido (celular ou não), só em memória: nada aqui chama GameSettings.save().
	var want_mobile: bool = args.has(ARG_MOBILE)
	if want_mobile != _was_mobile:
		GameSettings.get_instance().mobile_controls = want_mobile
		_ui.set_mobile_mode(want_mobile)
		await _wait(STEP_SEC)
	await _shot("hud")
	var hud: ProgressionHud = _ui.progression
	# Skills: várias árvores (títulos de exemplo) e algumas skills conhecidas.
	var progress: Dictionary = NetProgress.client_progress.duplicate(true)
	var titles: Array = []
	for t: StringName in SAMPLE_TITLES:
		if Content.title(t) != null:
			titles.append(String(t))
	progress["titles"] = titles
	progress["displayed_title"] = titles[0] if not titles.is_empty() else ""
	progress["skill_points"] = 3
	var skills: Dictionary = {}
	for t: Variant in titles.slice(0, 2):
		var tree: Array = SkillTree.tree_skills(StringName(str(t)))
		for i: int in mini(2, tree.size()):
			skills[String((tree[i] as SkillDef).id)] = 2
		# Ofícios do título (bonus_skills) aparecem na árvore dele, depois das 5.
		for b: StringName in Content.title(StringName(str(t))).bonus_skills:
			skills[String(b)] = 1
	progress["skills"] = skills
	# Diário: algumas missões reais e causos.
	var quests: Array = []
	for id: Variant in [&"tf_blade_title", &"tf_arcane_title", &"sabia_blade_aroeira_title", &"lesson_arcane_spark"]:
		if Content.quest(id) != null:
			quests.append({"id": String(id), "step": 2, "count": 3, "need": 8})
	if not quests.is_empty():
		quests[0]["step"] = 0
		quests[1]["ready"] = true
	progress["quests"] = quests
	progress["causos"] = 7
	progress["causos_next"] = 3
	hud.skills_window.set_progress(progress)
	hud.quest_log.set_progress(progress)
	hud.tracker.set_progress(progress)
	await _shot("tracker")
	hud.attributes_window.set_points(4)
	await _show(hud.skills_window, "skills")
	# Ofício na árvore de um título (06/10/2026): Garra da Onça com o Surrupiar selecionado.
	hud.skills_window.open()
	await _wait(STEP_SEC)
	hud.skills_window._select_tree(&"sabia_blade_jaguar")
	await _wait(0.3)
	hud.skills_window._select(&"blade_pilfer")
	await _wait(STEP_SEC)
	await _shot("skills_oficio")
	hud.skills_window.close()
	await _wait(0.2)
	await _show(hud.quest_log, "quests")
	await _show(hud.attributes_window, "attributes")
	# Inventário + personagem.
	var slots: Array = []
	for i: int in UIKit.INVENTORY_SIZE:
		slots.append({"item": String(SAMPLE_ITEMS[i]), "qty": 3 if i < 2 else 1} if i < SAMPLE_ITEMS.size() else null)
	_ui._on_inventory_changed(slots)
	_ui.inventory.open()
	_ui.equipment.open()
	await _wait(STEP_SEC)
	await _shot("inventory_character")
	_ui.close_top()
	_ui.close_top()
	# Loja (abre junto com o inventário).
	var shop: ShopDef = Content.shop(&"market")
	var items: Array = shop.items.slice(0, 8) if shop != null else SAMPLE_ITEMS
	_ui._on_shop_opened(&"market", items)
	await _wait(STEP_SEC)
	await _shot("shop")
	_ui._on_shop_closed()
	_ui.inventory.close()
	# Diálogo com um NPC de verdade.
	var dlg: DialogueDef = Content.dialogue(DIALOGUE_NPC)
	var npc: NpcDef = Content.npc(DIALOGUE_NPC)
	if dlg != null and dlg.get_node_by_id(dlg.start_node) != null:
		var node: DialogueNode = dlg.get_node_by_id(dlg.start_node)
		var options: Array = []
		for o: DialogueOption in node.options:
			options.append(o.text_key)
		_ui._on_dialogue_opened(1, npc.name_key if npc != null else "NPC", node.text_key, options)
		await _wait(STEP_SEC)
		await _shot("dialogue")
		_ui._on_dialogue_closed()
	# Configurações: esconde sem close() (close() grava o settings.cfg do jogador).
	_ui.settings.open()
	await _wait(STEP_SEC)
	await _shot("settings")
	_ui.settings.visible = false
	GameSettings.get_instance().mobile_controls = _was_mobile
	print("ui_capture_done")
	get_tree().quit(0)


func _show(w: GameWindow, label: String) -> void:
	w.open()
	await _wait(STEP_SEC)
	await _shot(label)
	w.close()
	await _wait(0.2)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(label: String) -> void:
	var dir: String = args.get(ARG_SHOT_DIR, "")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s_%s.png" % [dir, _tag, label]
	get_viewport().get_texture().get_image().save_png(path)
	print("ui_capture_shot ", path)
