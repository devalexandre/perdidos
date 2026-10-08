class_name FollowersWindow
extends GameWindow

var _progress: Dictionary = {}
var _collection := VBoxContainer.new()
var _status := Label.new()
var _names := LineEdit.new()
var _naming := OptionButton.new()
var _naming_ids: Array[StringName] = []
var _state_at: int = 0

func _init(p_scale: float = 1.0) -> void:
	super._init("UI_FOLLOWERS", p_scale)
	name = &"FollowersWindow"
	custom_minimum_size.x = UIKit.px(380, ui_scale)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	content.add_child(_collection)
	var names := HBoxContainer.new()
	_naming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(_naming)
	_names.placeholder_text = tr("FOLLOWER_NAME_HINT")
	_names.max_length = 12
	_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(_names)
	content.add_child(names)
	var save := Button.new()
	save.text = tr("FOLLOWER_NAME_SAVE")
	save.pressed.connect(func() -> void:
		if _naming.selected >= 0 and _naming.selected < _naming_ids.size():
			NetFollowers.send_command(&"name", _naming_ids[_naming.selected], _names.text)
	)
	content.add_child(save)
	var visibility := OptionButton.new()
	for key: String in ["FOLLOWERS_ALL", "FOLLOWERS_PARTY", "FOLLOWERS_NONE"]:
		visibility.add_item(tr(key))
	visibility.select(GameSettings.get_instance().follower_visibility)
	visibility.item_selected.connect(func(index: int) -> void:
		GameSettings.get_instance().follower_visibility = index
		GameSettings.get_instance().save()
	)
	content.add_child(visibility)

func set_progress(value: Dictionary) -> void:
	_progress = value
	_state_at = Time.get_ticks_msec()
	for child: Node in _collection.get_children():
		_collection.remove_child(child)
		child.queue_free()
	_naming.clear()
	_naming_ids.clear()
	var state: Dictionary = value.get("companions", {})
	var owned: Array = state.get("owned", [])
	var active: StringName = StringName(str(state.get("active", "")))
	var label := Label.new()
	label.text = tr("FOLLOWER_BONDS_HINT") if owned.is_empty() else tr("FOLLOWER_ACTIVE_HINT")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_collection.add_child(label)
	for raw: Variant in owned:
		var id: StringName = StringName(str(raw))
		var def: CompanionDef = Content.companion(id)
		if def == null:
			continue
		_add_name(id, def)
		var button := Button.new()
		button.text = tr(def.name_key) + (" · " + tr("FOLLOWER_ACTIVE") if id == active else "")
		button.pressed.connect(func() -> void: NetFollowers.send_command(&"companion", id))
		_collection.add_child(button)
		_add_level(def, (state.get("progress", {}) as Dictionary).get(String(id), {}), id == active)
		if id == active:
			for skill: StringName in def.bond_skills:
				_add_skill(skill)
	if not active.is_empty():
		var dismiss := Button.new()
		dismiss.text = tr("FOLLOWER_DISMISS")
		dismiss.pressed.connect(func() -> void: NetFollowers.send_command(&"companion"))
		_collection.add_child(dismiss)
	# A harpia é nomeada antes da entrega da quest, ainda sem constar na coleção.
	var quests: Array = value.get("quests", [])
	for entry: Dictionary in quests:
		var quest: QuestDef = Content.quest(StringName(str(entry.get("id", ""))))
		var step_index: int = int(entry.get("step", 0))
		if quest != null and step_index < quest.steps.size():
			var step: QuestStep = quest.steps[step_index]
			if step.type == QuestStep.StepType.NAME_COMPANION and step.target_id not in _naming_ids:
				_add_name(step.target_id, Content.companion(step.target_id))
	var mounts: Dictionary = value.get("mounts", {})
	for raw: Variant in mounts.get("owned", []):
		var id: StringName = StringName(str(raw))
		var def: MountDef = Content.mount(id)
		if def == null:
			continue
		var mounted: bool = str(mounts.get("active", "")) == String(id)
		var button := Button.new()
		button.text = tr("MOUNT_DISMOUNT" if mounted else "MOUNT_RIDE") + ": " + tr(def.name_key)
		button.pressed.connect(func() -> void: NetFollowers.send_command(&"dismount" if mounted else &"mount", id))
		_collection.add_child(button)

## Nível, barra de XP e magias do companheiro (PETS-E-MONTARIAS §0.1).
func _add_level(def: CompanionDef, entry: Dictionary, active: bool) -> void:
	var level: int = int(entry.get("level", 1))
	var xp: int = int(entry.get("xp", 0))
	var next: int = int(entry.get("xp_next", 0))
	var label := Label.new()
	label.text = tr("FOLLOWER_LEVEL_MAX") % level if next <= 0 else tr("FOLLOWER_LEVEL") % [level, xp, next]
	_collection.add_child(label)
	var bar := ProgressBar.new()
	bar.name = &"CompanionXp_" + String(def.id)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(UIKit.px(340, ui_scale), UIKit.px(8, ui_scale))
	bar.max_value = maxi(1, next)
	bar.value = bar.max_value if next <= 0 else xp
	var fill := StyleBoxFlat.new()
	fill.bg_color = CombatFx.COLOR_COMPANION
	bar.add_theme_stylebox_override(&"fill", fill)
	_collection.add_child(bar)
	if not active:
		return
	var names: Array[String] = []
	for raw: Variant in entry.get("spells", []):
		var sd: SkillDef = Content.companion_skill(StringName(str(raw)))
		if sd != null:
			names.append(tr(sd.name_key))
	var spells := Label.new()
	spells.text = tr("FOLLOWER_SPELLS") % (", ".join(names) if not names.is_empty() else "—")
	spells.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tips: Array[String] = []
	for spell: StringName in def.spells:
		var sd: SkillDef = Content.companion_skill(spell)
		if sd != null:
			tips.append(tr(sd.name_key) + ": " + tr(sd.desc_key))
	spells.tooltip_text = "\n".join(tips)
	spells.mouse_filter = Control.MOUSE_FILTER_PASS
	_collection.add_child(spells)
	for gate: int in Balance.cfg.companion_spell_levels:
		if gate > level and Balance.cfg.companion_spell_levels.find(gate) < def.spells.size():
			var next_label := Label.new()
			next_label.text = tr("FOLLOWER_NEXT_SPELL") % gate
			_collection.add_child(next_label)
			break
	var hint := Label.new()
	hint.text = tr("FOLLOWER_COMBAT_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_collection.add_child(hint)


func _add_name(id: StringName, def: CompanionDef) -> void:
	if def != null:
		_naming_ids.append(id)
		_naming.add_item(tr(def.name_key))

func _add_skill(id: StringName) -> void:
	var def: SkillDef = Content.skill(id)
	if def == null:
		return
	var label := Label.new()
	label.text = tr(def.name_key) + (" · " + tr("FOLLOWER_PASSIVE") if def.passive else "")
	label.tooltip_text = tr(def.desc_key)
	_collection.add_child(label)
	if def.passive:
		return
	var row := HBoxContainer.new()
	var slots := OptionButton.new()
	for i: int in 10:
		slots.add_item(tr("FOLLOWER_SLOT") % (i + 1 if i < 9 else 0))
	row.add_child(slots)
	var assign := Button.new()
	assign.text = tr("FOLLOWER_ASSIGN")
	assign.pressed.connect(func() -> void: NetProgress.send_hotbar_set(slots.selected, id))
	row.add_child(assign)
	_collection.add_child(row)

func _process(_delta: float) -> void:
	if not visible:
		return
	var companions: Dictionary = _progress.get("companions", {})
	var mounts: Dictionary = _progress.get("mounts", {})
	var elapsed: int = Time.get_ticks_msec() - _state_at
	var left: int = maxi(int(companions.get("casting_ms", 0)), int(mounts.get("casting_ms", 0))) - elapsed
	if left > 0:
		_status.text = tr("FOLLOWER_CHANNEL") % (left / 1000.0)
	elif int(companions.get("swap_ms", 0)) > elapsed:
		_status.text = tr("FOLLOWER_SWAP_TIMER") % ceili((int(companions.swap_ms) - elapsed) / 1000.0)
	else:
		_status.text = tr("FOLLOWER_WINDOW_HINT")
