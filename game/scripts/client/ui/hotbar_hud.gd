class_name ProgressionHud
extends Control
## Interface da progressão (Agente Q) por cima do jogo: barra 1–0 (Hotbar) com XP, janelas de
## skills (K), atributos (A) e missões (L), acompanhamento de missões e a mira das skills de chão.
## Criado pelo GameUI a cada reconstrução (mudança de escala). Escuta NetProgress/Net e chama as
## intenções NetProgress.send_*.
##
## Teclas 1..0: usa o espaço da barra. Alvo único = alvo do ataque (NetCombat), senão o último
## monstro clicado, senão o mais perto no alcance. Área no chão, cone e linha: mira com prévia.
## Tempo de uso (GDD §8.1): a barra anima tecla/clique, conjuração, recarga e "pronto"; quem conjura
## na instância ganha uma barrinha sobre a cabeça (CastBarsOverlay).

const ACTION_SKILLS: StringName = &"ui_toggle_skills"
const ACTION_ATTRIBUTES: StringName = &"ui_toggle_attributes"
const ACTION_QUESTS: StringName = &"ui_toggle_quests"
const ACTION_HOTBAR_PREFIX: String = "hotbar_"
const HOTBAR_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const ANY_DEVICE: int = -1
## Posição preferida das janelas na área útil (GameWindow.place): skills à esquerda, atributos no meio,
## diário à direita — logo abaixo das barras de vida.
const SKILLS_ANCHOR: Vector2 = Vector2(0.0, 0.0)
const ATTRIBUTES_ANCHOR: Vector2 = Vector2(0.5, 0.0)
const QUESTS_ANCHOR: Vector2 = Vector2(1.0, 0.0)
const TARGET_PREFIX: String = "e:"
const KIND_MONSTER: StringName = &"monster"
const MSEC_PER_SEC: float = 1000.0
const RANGE_SLACK_CELLS: float = 0.5
const NET_COMBAT_TARGET: StringName = &"client_attack_target"
const MSG_NO_MANA: String = "PROG_MSG_NO_MANA"
const MSG_COOLDOWN: String = "PROG_MSG_SKILL_COOLDOWN"
const MSG_NO_TARGET: String = "PROG_MSG_NO_TARGET"
const MSG_AIM_HINT: String = "UI_AIM_HINT"
## Equipamento da barra que não está no inventário (já vestido).
const MSG_ALREADY_EQUIPPED: String = "UI_HOTBAR_ALREADY_EQUIPPED"
## Diferença (ms) a partir da qual uma recarga do snapshot substitui a que a barra já mostra.
const COOLDOWN_RESYNC_MS: float = 150.0

## Janelas abertas antes da reconstrução (a interface inteira é refeita ao mudar a escala).
static var _reopen: Dictionary[StringName, bool] = {}

var game_ui: GameUI = null
var ui_scale: float = 1.0
var hotbar: Hotbar
var skills_window: SkillsWindow
var attributes_window: AttributesWindow
var quest_log: QuestLogWindow
var tracker: QuestTracker
var aim: HotbarAim
var cast_overlay: CastBarsOverlay
var _progress: Dictionary = {}
var _cd_ends: Dictionary = {}
var _cd_totals: Dictionary = {}
var _last_clicked_target: int = 0
var _view: ClientView = null


func _init(p_game_ui: GameUI) -> void:
	game_ui = p_game_ui
	ui_scale = p_game_ui.ui_scale
	name = &"ProgressionHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_register_actions()
	cast_overlay = CastBarsOverlay.new(ui_scale)
	add_child(cast_overlay)
	hotbar = Hotbar.new(ui_scale)
	hotbar.slot_activated.connect(use_slot)
	hotbar.slot_assigned.connect(func(i: int, id: StringName) -> void: NetProgress.send_hotbar_set(i, id))
	add_child(hotbar)
	tracker = QuestTracker.new(ui_scale)
	tracker.open_log_requested.connect(func() -> void: quest_log.open())
	add_child(tracker)
	skills_window = SkillsWindow.new(ui_scale)
	skills_window.level_up_requested.connect(NetProgress.send_skill_level_up)
	skills_window.title_requested.connect(NetProgress.send_set_title)
	attributes_window = AttributesWindow.new(ui_scale)
	attributes_window.allocate_requested.connect(NetProgress.send_allocate_stats)
	quest_log = QuestLogWindow.new(ui_scale)
	quest_log.abandon_requested.connect(NetProgress.send_quest_abandon)
	skills_window.default_anchor = SKILLS_ANCHOR
	attributes_window.default_anchor = ATTRIBUTES_ANCHOR
	quest_log.default_anchor = QUESTS_ANCHOR
	var layer: Control = game_ui.windows_layer if game_ui.windows_layer != null else self
	for w: GameWindow in [skills_window, attributes_window, quest_log]:
		layer.add_child(w)
	_add_hud_buttons()
	NetProgress.progress_changed.connect(_on_progress_changed)
	NetProgress.skill_cast.connect(_on_skill_cast)
	NetProgress.cast_cancelled.connect(_on_cast_cancelled)
	for sig: StringName in [&"stats_changed", &"inventory_changed"]:
		Net.connect(sig, _on_net_state_changed)
	_view = _find_view()
	cast_overlay.view = _view
	if _view != null:
		aim = HotbarAim.new()
		aim.name = &"HotbarAim"
		aim.view = _view
		_view.get_camera().get_parent().add_child(aim)
		aim.confirmed.connect(_on_aim_confirmed)
		if not _view.interact_requested.is_connected(_on_interact_requested):
			_view.interact_requested.connect(_on_interact_requested)
	_on_progress_changed(NetProgress.client_progress)
	await get_tree().process_frame
	if not is_instance_valid(skills_window):
		return
	skills_window.place(SKILLS_ANCHOR)
	attributes_window.place(ATTRIBUTES_ANCHOR)
	quest_log.place(QUESTS_ANCHOR)
	for w: GameWindow in [skills_window, attributes_window, quest_log]:
		if _reopen.get(w.name, false):
			w.visible = true


func _exit_tree() -> void:
	for w: GameWindow in [skills_window, attributes_window, quest_log]:
		if w != null and is_instance_valid(w):
			_reopen[w.name] = w.visible
	if aim != null and is_instance_valid(aim):
		aim.queue_free()
	if NetProgress.progress_changed.is_connected(_on_progress_changed):
		NetProgress.progress_changed.disconnect(_on_progress_changed)
		NetProgress.skill_cast.disconnect(_on_skill_cast)
		NetProgress.cast_cancelled.disconnect(_on_cast_cancelled)
	for sig: StringName in [&"stats_changed", &"inventory_changed"]:
		if Net.is_connected(sig, _on_net_state_changed):
			Net.disconnect(sig, _on_net_state_changed)


func _find_view() -> ClientView:
	var n: Node = self
	while n != null:
		if n is ClientView:
			return n as ClientView
		n = n.get_parent()
	return null


func _add_hud_buttons() -> void:
	# Agente R (GDD §9.5): entradas no menu da engrenagem do GameUI, antes de Inventário/Personagem/Menu.
	if game_ui.gear == null:
		return
	var specs: Array[Array] = [
		["UI_SKILLS", "K", MenuIcons.SKILLS, func() -> void: skills_window.toggle()],
		["UI_ATTRIBUTES_WINDOW", "A", MenuIcons.ATTRIBUTES, func() -> void: attributes_window.toggle()],
		["UI_QUEST_LOG", "L", MenuIcons.QUESTS, func() -> void: quest_log.toggle()]]
	for i: int in specs.size():
		game_ui.add_menu_entry(specs[i][0], specs[i][1], specs[i][2], specs[i][3], i)


# ---------------------------------------------------------------- estado

func _on_progress_changed(progress: Dictionary) -> void:
	_progress = progress
	var now: float = Time.get_ticks_msec()
	# Recargas efetivas (GDD §8.1): o servidor manda o que falta e o total (Espírito/itens já aplicados).
	var cds: Dictionary = {}
	var totals: Dictionary = {}
	var skill_cds: Dictionary = progress.get("cooldowns", {})
	var skill_totals: Dictionary = progress.get("cooldown_totals", {})
	for id: Variant in skill_cds:
		cds[str(id)] = skill_cds[id]
		totals[str(id)] = skill_totals.get(id, skill_cds[id])
	var item_cds: Dictionary = progress.get("item_cooldowns", {})
	var item_totals: Dictionary = progress.get("item_cooldown_totals", {})
	for g: Variant in item_cds:
		cds[Hotbar.ITEM_COOLDOWN_PREFIX + str(g)] = item_cds[g]
		totals[Hotbar.ITEM_COOLDOWN_PREFIX + str(g)] = item_totals.get(g, item_cds[g])
	for key: String in cds:
		var end: float = now + float(cds[key])
		# Não reinicia a sombra por diferença de latência entre snapshots.
		if absf(float(_cd_ends.get(key, 0.0)) - end) > COOLDOWN_RESYNC_MS:
			_cd_ends[key] = end
		_cd_totals[key] = maxf(float(totals[key]), 1.0)
	for key: Variant in _cd_ends.keys():
		if not cds.has(key) and float(_cd_ends[key]) > now:
			_cd_ends.erase(key)
	_refresh()


func _on_net_state_changed(_arg: Variant) -> void:
	_refresh()


func _refresh() -> void:
	if hotbar == null:
		return
	hotbar.set_state(_progress, int(Net.client_stats.get(&"mp", 0)), Net.client_inventory,
			_cd_ends, _cd_totals, Net.client_stats)
	skills_window.set_stats(Net.client_stats)
	skills_window.set_progress(_progress)
	attributes_window.set_points(int(_progress.get("attribute_points", 0)))
	attributes_window.set_stats(Net.client_stats)
	quest_log.set_progress(_progress)
	tracker.set_progress(_progress)
	var minimap: Minimap = _view.find_child("Minimap", true, false) as Minimap if _view != null else null
	if minimap != null:
		minimap.set_quest_progress(_progress)
	if game_ui.world_atlas != null:
		game_ui.world_atlas.set_quest_maps(minimap.quest_map_ids() if minimap != null else [])


func get_progress() -> Dictionary:
	return _progress


# ---------------------------------------------------------------- usar a barra

func use_slot(index: int, mobile_drag: bool = false) -> void:
	var bar: Array = _progress.get("hotbar", [])
	if index < 0 or index >= bar.size():
		return
	var entry := StringName(str(bar[index]))
	if entry.is_empty():
		return
	var slot: HotbarSlot = hotbar.slots[index]
	var def: SkillDef = Content.skill(entry)
	if def == null:
		_use_item(entry, slot)
		return
	if slot.is_cooling_down():
		slot.deny()
		var left: float = float(_cd_ends.get(String(entry), 0.0)) - Time.get_ticks_msec()
		game_ui.show_system_message(MSG_COOLDOWN, [def.name_key, ceili(left / MSEC_PER_SEC)])
		return
	if int(Net.client_stats.get(&"mp", 0)) < def.mana_cost:
		slot.deny()
		game_ui.show_system_message(MSG_NO_MANA)
		return
	if hotbar.is_casting():
		slot.deny()
		return
	slot.press()
	var me: Node3D = _local_player()
	match def.target_type:
		SkillDef.TargetType.SINGLE:
			var t: int = _pick_target(def, me)
			if t == 0:
				game_ui.show_system_message(MSG_NO_TARGET)
				return
			NetProgress.send_cast(def.id, t, Vector3.ZERO)
		SkillDef.TargetType.GROUND_AREA, SkillDef.TargetType.CONE, SkillDef.TargetType.LINE:
			if aim != null and me != null:
				aim.begin(def, me, mobile_drag)
				if not mobile_drag:
					game_ui.show_system_message(MSG_AIM_HINT)
		_:
			NetProgress.send_cast(def.id, NetProgress.NO_TARGET,
					me.global_position if me != null else Vector3.ZERO)


func _use_item(item_id: StringName, slot: HotbarSlot = null) -> void:
	var def: ItemDef = Content.item(item_id)
	if def != null and def.type != ItemDef.ItemType.CONSUMABLE and def.is_equippable():
		_equip_from_bar(item_id, slot)
		return
	var instant: bool = CastTiming.is_instant_item(def)
	if slot != null and not instant and (slot.is_cooling_down() or hotbar.is_casting()):
		slot.deny()
		return
	var inv: Array = Net.client_inventory
	for i: int in inv.size():
		if inv[i] is Dictionary and StringName(str((inv[i] as Dictionary).get("item", ""))) == item_id:
			if slot != null:
				# Poção: "pop" rápido (instantânea, sem sombra). Demais usáveis: afunda como skill.
				if instant:
					slot.pop()
				else:
					slot.press()
			Net.send_use_item(i)
			return
	if slot != null:
		slot.deny()


## Equipamento na barra: veste (troca com o que estava no espaço). Já vestido / sem no inventário = nega.
func _equip_from_bar(item_id: StringName, slot: HotbarSlot = null) -> void:
	var inv: Array = Net.client_inventory
	for i: int in inv.size():
		if inv[i] is Dictionary and StringName(str((inv[i] as Dictionary).get("item", ""))) == item_id:
			if slot != null:
				slot.pop()
			Net.send_equip(i)
			return
	if slot != null:
		slot.deny()
	game_ui.show_system_message(MSG_ALREADY_EQUIPPED)


func _on_aim_confirmed(skill_id: StringName, point: Vector3) -> void:
	NetProgress.send_cast(skill_id, _current_target(), point)


func _on_interact_requested(target_id: String) -> void:
	if target_id.begins_with(TARGET_PREFIX) and target_id.substr(TARGET_PREFIX.length()).is_valid_int():
		var id: int = target_id.substr(TARGET_PREFIX.length()).to_int()
		var e: Node = _entity(id)
		if e != null and StringName(str(e.get(&"kind"))) == KIND_MONSTER:
			_last_clicked_target = id
			NetCombat.set_client_target(id)



func _current_target() -> int:
	var t: int = int(NetCombat.get(NET_COMBAT_TARGET)) if NET_COMBAT_TARGET in NetCombat else 0
	if t != 0 and _entity(t) != null:
		return t
	return _last_clicked_target if _entity(_last_clicked_target) != null else 0


func _pick_target(def: SkillDef, me: Node3D) -> int:
	var t: int = _current_target()
	if t != 0:
		return t
	if me == null:
		return 0
	var best: int = 0
	var best_d: float = (def.range_cells + RANGE_SLACK_CELLS) * Balance.cfg.cell_size
	for e: Node in me.get_parent().get_children():
		if StringName(str(e.get(&"kind"))) != KIND_MONSTER or float(e.get(&"hp_ratio")) <= 0.0:
			continue
		var d: float = (e as Node3D).global_position.distance_to(me.global_position)
		if d <= best_d:
			best_d = d
			best = int(e.get(&"entity_id"))
	return best


func _local_player() -> Node3D:
	var root: Node = get_tree().root.get_node_or_null(^"Main/World/Instances")
	if root == null:
		return null
	for inst: Node in root.get_children():
		var ents: Node = inst.get_node_or_null(^"Entities")
		if ents == null:
			continue
		for e: Node in ents.get_children():
			if e is NetEntity and (e as NetEntity).is_local_player():
				return e as Node3D
	return null


func _entity(entity_id: int) -> Node:
	if entity_id == 0:
		return null
	var me: Node3D = _local_player()
	if me == null or me.get_parent() == null:
		return null
	return me.get_parent().get_node_or_null(NodePath(str(entity_id)))


func _on_skill_cast(entity_id: int, skill_id: StringName, target_entity_id: int, pos: Vector3,
		cast_ms: int) -> void:
	var def: SkillDef = Content.skill(skill_id)
	var caster: Node3D = _entity(entity_id) as Node3D
	var me: Node3D = _local_player()
	# cast_ms inclui o aviso no chão (Queda Estelar); a barra mostra só a conjuração.
	var bar_ms: int = cast_ms - (roundi(def.ground_warning_sec * MSEC_PER_SEC) if def != null else 0)
	if me != null and entity_id == int(me.get(&"entity_id")):
		if bar_ms > 0:
			hotbar.start_cast(bar_ms, skill_id)
	elif caster != null and bar_ms > 0:
		cast_overlay.start(entity_id, caster, bar_ms)
	var target: Node3D = _entity(target_entity_id) as Node3D
	var point: Vector3 = target.global_position if target != null \
			and def != null and def.target_type == SkillDef.TargetType.SINGLE else pos
	if aim != null:
		aim.show_cast(def, caster, point, cast_ms)


func _on_cast_cancelled(entity_id: int, _skill_id: StringName) -> void:
	var me: Node3D = _local_player()
	if me != null and entity_id == int(me.get(&"entity_id")):
		hotbar.cancel_cast()
	else:
		cast_overlay.cancel(entity_id)


# ---------------------------------------------------------------- teclado

func _input(event: InputEvent) -> void:
	if aim != null and aim.handle_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or (event as InputEventKey).echo:
		return
	if game_ui.is_typing():
		return
	var key: InputEventKey = event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		for w: GameWindow in [quest_log, attributes_window, skills_window]:
			if w.visible and not game_ui.dialogue.visible:
				w.close()
				get_viewport().set_input_as_handled()
				return
		return
	if not game_ui.dialogue.visible:
		for i: int in HOTBAR_KEYS.size():
			if event.is_action_pressed(StringName(ACTION_HOTBAR_PREFIX + str(i + 1)), false, true):
				use_slot(i)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed(ACTION_SKILLS, false, true):
		skills_window.toggle()
	elif event.is_action_pressed(ACTION_ATTRIBUTES, false, true):
		attributes_window.toggle()
	elif event.is_action_pressed(ACTION_QUESTS, false, true):
		quest_log.toggle()
	else:
		return
	get_viewport().set_input_as_handled()


func _register_actions() -> void:
	_add_key(ACTION_SKILLS, KEY_K)
	_add_key(ACTION_ATTRIBUTES, KEY_A)
	_add_key(ACTION_QUESTS, KEY_L)
	for i: int in HOTBAR_KEYS.size():
		_add_key(StringName(ACTION_HOTBAR_PREFIX + str(i + 1)), HOTBAR_KEYS[i])


func _add_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == key:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.device = ANY_DEVICE
	InputMap.action_add_event(action, ev)
