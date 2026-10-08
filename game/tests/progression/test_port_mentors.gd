extends Node

const MENTORS: Array[StringName] = [&"master_brisa", &"master_orvalho", &"master_taquari", &"elder_ze_ferreiro", &"elder_aninha", &"elder_tiao"]
const ENTRY_SKILLS: Array[StringName] = [&"blade_firm_strike", &"arcane_spark", &"bow_low_shot"]
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var city: GameMap = load("res://scenes/maps/city_awakening.tscn").instantiate()
	add_child(city)
	for frame: int in 180:
		await get_tree().physics_frame
		if WalkGrid.is_nav_synced(city.get_navigation_map()):
			break
	var grid: WalkGrid = WalkGrid.for_map(&"city_awakening", city, city.get_navigation_map())
	check(grid != null, "city navigation ready")
	for mid: StringName in MENTORS:
		var npc: NpcDef = Content.npc(mid)
		var marker: Marker3D = city.get_npc_point(npc.spawn_marker)
		check(npc.map_id == &"city_awakening" and marker != null, "%s in Porto" % mid)
		if marker == null:
			continue
		check(marker.position.distance_to(city.get_spawn_point()) > 25, "%s outside central plaza" % mid)
		check(grid != null and grid.is_walkable(grid.world_to_cell(marker.position)), "%s on walkable ground" % mid)
		var route: PackedVector3Array = NavigationServer3D.map_get_path(city.get_navigation_map(), city.get_spawn_point(), marker.position, true)
		check(route.size() > 1 and route[-1].distance_to(marker.position) < 1, "%s reachable" % mid)
		check(marker.get_meta(&"minimap_icon", &"") == &"none", "%s discovered by exploring" % mid)
		for other: StringName in MENTORS:
			if other != mid:
				check(marker.position.distance_to(city.get_npc_point(other).position) > 15, "mentors spread apart")
	for resource: Resource in Content.all(&"titles").values():
		var title: TitleDef = resource as TitleDef
		if title != null and String(title.id).begins_with("pindorama_"):
			check(title.master_npc in MENTORS, "%s has a local teacher" % title.id)
	var world := ServerWorld.new()
	var progression := Progression.new(world)
	for training: StringName in [&"tf_blade_title", &"tf_arcane_title"]:
		var character := CharacterData.create_new("PortMentorTest", &"male")
		character.left_training = true
		character.progression.quests_done[training] = 1
		var session := PlayerSession.new(0, null, character)
		for sid: StringName in ENTRY_SKILLS:
			var quest: QuestDef = SkillTree.quest_for_skill(sid, &"city_awakening")
			check(quest != null and not quest.training_title_quest, "%s has a permanent lesson" % sid)
			if quest == null:
				continue
			check(progression.quests.missing_requirements(session, quest).is_empty(), "%s available after %s" % [sid, training])
			check(quest.reward_title == Content.skill(sid).tree_title, "%s unlocks its title" % sid)
			character.progression.skills[sid] = 1
			check(progression.quests.missing_requirements(session, quest).is_empty(), "legacy skill without title can recover")
			character.progression.titles[quest.reward_title] = 1
			check(not progression.quests.missing_requirements(session, quest).is_empty(), "already learned initiation is hidden")
		check(SkillTree.quest_for_skill(&"arcane_spark", &"training_field").id == &"tf_arcane_title", "training still points to Candeia")
		check(SkillTree.quest_for_skill(&"blade_firm_strike", &"training_field").id == &"tf_blade_title", "training still points to Jatoba")
	world.free()
	print("PORT MENTORS: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
