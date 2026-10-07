extends Node

var main_node: Node
var args: Dictionary[String, String] = {}
var started: bool = false
var locked: bool = false
var unlocked: bool = false
var placed_map: StringName = &""

func _ready() -> void:
	Net.system_message.connect(func(key: String, _values: Array) -> void:
		locked = locked or key == "SYS_CAVE_BOSS_GATE"
		unlocked = unlocked or key == "SYS_CAVE_SURFACE_OPEN")
	Net.local_player_spawned.connect(_placed)
	get_tree().create_timer(60).timeout.connect(func() -> void:
		push_error("CAVE BOSS timeout")
		get_tree().quit(1))


func wait_until(condition: Callable, label: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	if not condition.call():
		push_error(label)
		get_tree().quit(1)
		return false
	return true


func boss_is_atroz() -> bool:
	for entity: Node3D in NetCombat.all_entities():
		if entity is NetEntity and entity.def_id == &"cave_werewolf" and entity.stage == 4:
			return true
	return false


func _placed(_player: Node3D) -> void:
	placed_map = (_player as NetEntity).instance_id
	if started:
		return
	started = true
	await get_tree().create_timer(1).timeout
	NetProgress.send_debug(&"goto", ["cave_reino_encoberto_4"])
	if not await wait_until(func() -> bool: return NetWorld.client_map_id == &"cave_reino_encoberto_4", "F4 not loaded"):
		return
	await get_tree().create_timer(1).timeout
	NetProgress.send_debug(&"teleport", [34, -22])
	if not await wait_until(func() -> bool: return locked, "Escape was not locked before boss victory"):
		return
	NetProgress.send_debug(&"teleport", [20, -24])
	Net.send_chat(&"local", "/noite")
	if not await wait_until(boss_is_atroz, "Boss did not become atroz at night"):
		return
	await get_tree().create_timer(1).timeout
	Net.send_chat(&"local", "/derrubar chefe")
	if not await wait_until(func() -> bool: return unlocked, "Boss death did not unlock escape"):
		return
	NetProgress.send_debug(&"teleport", [34, -22])
	if not await wait_until(func() -> bool: return placed_map == &"enchanted_forest_roots", "Unlocked escape did not reach surface"):
		return
	await get_tree().create_timer(0.5).timeout
	print("CAVE BOSS PASS: locked escape, night form, victory, automatic surface return")
	get_tree().quit()
