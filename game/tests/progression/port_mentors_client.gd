extends Node
## Actual NPC dialogs and rewards; development commands only prepare the training save
## and supply kill credits. Navigation to each hidden NPC is covered by test_port_mentors.
var main_node: Node
var args: Dictionary[String, String] = {}
var player: NetEntity
var progress: Dictionary = {}
var options: Array = []
var dialogue_seq: int = 0
var progress_seq: int = 0
var failures: int = 0

func _ready() -> void:
	NetProgress.progress_changed.connect(func(p: Dictionary) -> void:
		progress = p
		progress_seq += 1)
	Net.dialogue_opened.connect(func(_id: int, _name: String, _key: String, opts: Array) -> void:
		options = opts
		dialogue_seq += 1)
	Net.local_player_spawned.connect(_placed)
	get_tree().create_timer(120).timeout.connect(func() -> void: get_tree().quit(1))

func wait_for(predicate: Callable) -> bool:
	var end: int = Time.get_ticks_msec() + 5000
	while not predicate.call() and Time.get_ticks_msec() < end:
		await get_tree().create_timer(0.1).timeout
	return predicate.call()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func debug(command: StringName, values: Array) -> void:
	var seq: int = progress_seq
	NetProgress.send_debug(command, values)
	await wait_for(func() -> bool: return progress_seq > seq)

func talk(mid: StringName) -> void:
	var npc: NetEntity = null
	for node: Node in player.get_parent().get_children():
		if node is NetEntity and node.def_id == mid:
			npc = node
	check(npc != null, "%s spawned in Porto" % mid)
	if npc == null:
		return
	var pos: Vector3 = npc.net_position + Vector3(1, 0, 0)
	await debug(&"teleport", [pos.x, pos.z])
	await wait_for(func() -> bool: return player.net_position.distance_to(pos) < 2)
	var seq: int = dialogue_seq
	Net.send_interact(npc.get_target_id())
	check(await wait_for(func() -> bool: return dialogue_seq > seq), "dialogue opens")

func choose(key: String, opens: bool = true) -> void:
	var index: int = options.find(key)
	check(index >= 0, "option: " + key)
	if index < 0:
		return
	var seq: int = dialogue_seq
	Net.send_dialogue_choice(index)
	if opens:
		check(await wait_for(func() -> bool: return dialogue_seq > seq), "next dialogue opens")
	else:
		await get_tree().create_timer(0.3).timeout

func _placed(entity: Node3D) -> void:
	if player != null:
		return
	player = entity as NetEntity
	await get_tree().create_timer(2).timeout
	# Reproduce leaving training as Facão Firme before seeking magic and archery.
	await debug(&"quest_accept", [&"tf_blade_title"])
	await debug(&"quest_step", [&"tf_blade_title", 2])
	await debug(&"quest_turn_in", [&"tf_blade_title"])
	check("tf_blade_title" in progress.get("quests_done", []), "training choice completed")
	for sid: StringName in [&"arcane_spark", &"bow_low_shot"]:
		var quest: QuestDef = Content.quest(StringName("lesson_" + String(sid)))
		await talk(quest.giver_npc)
		await choose(quest.option_text_key)
		await choose(QuestService.OPT_ACCEPT, false)
		for i: int in quest.steps[0].count:
			await debug(&"kill", [quest.steps[0].target_id, 0])
		await talk(quest.giver_npc)
		await choose(QuestService.OPT_REPORT)
		await choose(QuestService.OPT_TURN_IN, false)
		check(await wait_for(func() -> bool: return String(sid) in progress.get("skills", {})), "city teaches " + String(sid))
		check(String(quest.reward_title) in progress.get("titles", []), "city grants " + String(quest.reward_title))
		await debug(&"skill_level", [sid, 3])
		var next_id: StringName = &"lesson_arcane_frost_burst" if sid == &"arcane_spark" else &"lesson_bow_double_arrow"
		await talk(quest.giver_npc)
		check(Content.quest(next_id).option_text_key in options, "next lesson unlocked")
		print("PORT_MENTOR_LEARNED ", sid, " title=", quest.reward_title)
	print("PORT_MENTORS_NETWORK failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
