class_name MobileControlsOverlay
extends Control
## Overlay mestre de controles mobile (GDD §9.5, Touch Standard):
## Integra o VirtualJoystick (à esquerda) e o MobileActionCluster (à direita)
## com o ClientView, NetCombat e ProgressionHud.

signal move_direction_updated(dir: Vector2)

const MARGIN_PX: float = 20.0
const JOYSTICK_BOTTOM_PX: float = 76.0
const TARGET_SEARCH_MAX_DIST: float = CombatAssist.TARGET_SEARCH_MAX_DIST

var ui_scale: float = 1.0
var game_ui: GameUI = null
var progression: ProgressionHud = null
## Andar, alvo e botão de ação (o do GameUI, compartilhado com o controle; sem GameUI, um próprio).
var assist: CombatAssist = null

var joystick: MobileVirtualJoystick
var action_cluster: MobileActionCluster
const VIRTUAL_JOYSTICK_SCRIPT: GDScript = preload("res://scripts/client/ui/virtual_joystick.gd")
const MOBILE_ACTION_CLUSTER_SCRIPT: GDScript = preload("res://scripts/client/ui/mobile_action_cluster.gd")
const MOBILE_CONFIG_DIALOG_SCRIPT: GDScript = preload("res://scripts/client/ui/mobile_config_dialog.gd")

var config_dialog: MobileConfigDialog

## Alvo travado (atalho para assist.current_target; testes antigos leem daqui).
var _current_target_entity: int:
	get:
		return assist.current_target if assist != null else CombatAssist.NO_TARGET
	set(value):
		if assist != null:
			assist.current_target = value


func _init(p_game_ui: GameUI = null, p_scale: float = 1.0) -> void:
	game_ui = p_game_ui
	ui_scale = p_scale
	name = &"MobileControlsOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game_ui != null and game_ui.combat_assist != null:
		assist = game_ui.combat_assist
	else:
		assist = CombatAssist.new(game_ui)
		add_child(assist)

	# 1. Analógico Virtual no canto inferior esquerdo
	joystick = (VIRTUAL_JOYSTICK_SCRIPT as Script).new(ui_scale)
	joystick.direction_changed.connect(_on_joystick_direction)
	add_child(joystick)

	# 2. Cluster de Ação no canto inferior direito
	action_cluster = (MOBILE_ACTION_CLUSTER_SCRIPT as Script).new(ui_scale)
	action_cluster.attack_activated.connect(_on_attack_pressed)
	action_cluster.slot_activated.connect(_on_slot_pressed)
	action_cluster.aim_direction_changed.connect(_on_aim_direction)
	action_cluster.aim_finished.connect(_on_aim_finished)
	action_cluster.target_cycle_activated.connect(_on_target_cycle_pressed)
	action_cluster.quick_potion_activated.connect(_on_quick_potion_pressed)
	action_cluster.config_requested.connect(_on_config_requested)
	add_child(action_cluster)

	# 3. Diálogo de Configuração dos 4 Slots
	config_dialog = (MOBILE_CONFIG_DIALOG_SCRIPT as Script).new(ui_scale)
	config_dialog.slot_assigned.connect(_on_slot_assigned)
	add_child(config_dialog)
	config_dialog.visible = false

	_update_positions()


func _ready() -> void:
	_update_positions()
	if game_ui != null:
		progression = game_ui.progression
	if NetProgress.has_signal(&"progress_changed"):
		NetProgress.progress_changed.connect(func(_p: Dictionary) -> void: _sync_slots())
	if Net.has_signal(&"inventory_changed"):
		Net.inventory_changed.connect(func(_inv: Array) -> void: _sync_potion())
	_sync_slots()
	_sync_potion()


func set_ui_scale(p_scale: float) -> void:
	ui_scale = p_scale
	if joystick != null:
		joystick.set_ui_scale(ui_scale)
	if action_cluster != null:
		action_cluster.set_ui_scale(ui_scale)
	if config_dialog != null:
		config_dialog.ui_scale = ui_scale
	_update_positions()


func _update_positions() -> void:
	var margin: float = MARGIN_PX * ui_scale
	var vp_size: Vector2 = size if size != Vector2.ZERO else (get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720))
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1280, 720)

	if joystick != null:
		var j_size: Vector2 = joystick.size
		joystick.position = Vector2(margin, maxf(margin, vp_size.y - j_size.y - JOYSTICK_BOTTOM_PX * ui_scale))

	if action_cluster != null:
		var a_size: Vector2 = action_cluster.size
		action_cluster.position = Vector2(vp_size.x - a_size.x - margin, vp_size.y - a_size.y - margin)

	if config_dialog != null:
		config_dialog.position = (vp_size - config_dialog.size) * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_positions()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_handle_joystick_movement()
	_update_slot_cooldowns()


func _handle_joystick_movement() -> void:
	if joystick == null or not joystick.is_active():
		return
	assist.walk(joystick.get_direction())


func _on_joystick_direction(dir: Vector2) -> void:
	move_direction_updated.emit(dir)
	if dir == Vector2.ZERO:
		assist.stop_walk()


# --- Combate e Habilidades Mobile (Estilo Albion Online) --------------------------------------------
# A lógica fica no CombatAssist (compartilhada com o controle/GamepadInput); aqui só os atalhos de antes.

func is_entity_alive(e: Node) -> bool:
	return CombatAssist.is_entity_alive(e)


func is_monster(e: Node) -> bool:
	return CombatAssist.is_monster(e)


func get_nearby_monsters(max_range: float = TARGET_SEARCH_MAX_DIST, exclude_id: int = -1) -> Array[Node3D]:
	return assist.get_nearby_monsters(max_range, exclude_id)


func select_target(target_id: int, send_intent: bool = true) -> void:
	assist.select_target(target_id, send_intent)


func clear_target() -> void:
	assist.clear_target()


func _auto_retarget_next() -> void:
	assist.auto_retarget_next()


func _on_entity_died(dead_id: int) -> void:
	assist.on_entity_died(dead_id)


func _on_world_interact_requested(target_id: String) -> void:
	assist.on_world_interact_requested(target_id)


func _on_attack_pressed() -> void:
	assist.smart_action()


func _on_slot_pressed(index: int) -> void:
	if progression != null:
		if is_instance_valid(progression.aim):
			progression.aim.cancel(false)
		progression.use_slot(index, true)
		if is_instance_valid(progression.aim) and progression.aim.is_aiming() and progression.aim.mobile_drag:
			action_cluster.begin_aim(index)


func _on_aim_direction(direction: Vector2) -> void:
	if progression != null and is_instance_valid(progression.aim):
		progression.aim.update_mobile_direction(direction)


func _on_aim_finished(cancelled_gesture: bool) -> void:
	if progression != null and is_instance_valid(progression.aim):
		progression.aim.finish_mobile(cancelled_gesture)


func _on_target_cycle_pressed() -> void:
	assist.cycle_target(1)


func _on_quick_potion_pressed() -> void:
	assist.quick_potion()


func _on_config_requested() -> void:
	if config_dialog == null:
		return
	var hotbar: Array = NetProgress.client_progress.get("hotbar", [])
	var known_skills: Array = _get_known_skills()
	var inv: Array = Net.client_inventory
	config_dialog.set_data(hotbar, known_skills, inv)
	config_dialog.open()
	config_dialog.position = (size - config_dialog.size) * 0.5


func _on_slot_assigned(slot_idx: int, entry_id: StringName) -> void:
	NetProgress.send_hotbar_set(slot_idx, entry_id)
	if action_cluster != null:
		action_cluster.set_slot_entry(slot_idx, entry_id)


func _get_known_skills() -> Array:
	var out: Array = []
	var prog_skills: Dictionary = NetProgress.client_progress.get("skills", {})
	for sk in prog_skills.keys():
		out.append(StringName(str(sk)))
	return out


func _sync_slots() -> void:
	if action_cluster == null:
		return
	var hotbar: Array = NetProgress.client_progress.get("hotbar", [])
	for i: int in 4:
		var entry: StringName = &""
		if i < hotbar.size():
			entry = StringName(str(hotbar[i]))
		action_cluster.set_slot_entry(i, entry)


func _sync_potion() -> void:
	if action_cluster == null:
		return
	var count: int = 0
	var pot_icon: Texture2D = null
	var inv: Array = Net.client_inventory
	for slot in inv:
		if slot is Dictionary:
			var iid: String = str((slot as Dictionary).get("item", ""))
			if iid.begins_with("potion_hp"):
				var q: int = int((slot as Dictionary).get("quantity", 1))
				count += q
				if pot_icon == null:
					var def: ItemDef = Content.item(StringName(iid))
					if def != null:
						pot_icon = def.icon
	action_cluster.set_potion_info(count, pot_icon)


func _update_slot_cooldowns() -> void:
	if action_cluster == null or progression == null:
		return
	var hotbar_node: Hotbar = progression.hotbar
	if hotbar_node == null:
		return
	for i: int in mini(4, hotbar_node.slots.size()):
		var slot: HotbarSlot = hotbar_node.slots[i]
		if slot != null:
			var left_ms: float = maxf(0.0, slot._cd_end_msec - Time.get_ticks_msec())
			var left_sec: float = left_ms / 1000.0
			var pct: float = slot.cooldown_fraction()
			action_cluster.set_slot_cooldown(i, pct, ceili(left_sec))
