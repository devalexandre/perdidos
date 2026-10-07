extends Node
var checks: int = 0
var failures: int = 0
var world: ServerWorld
var session: PlayerSession
const DONKEY: StringName = &"sabia_mount_donkey"

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	Net.is_server = true
	world = ServerWorld.new()
	world.progression = Progression.new(world)
	world.mounts = MountService.new(world)
	world.companions = CompanionService.new(world)
	var entity := NetEntity.new()
	var sync := MultiplayerSynchronizer.new()
	sync.name = NetEntity.SYNC_NODE_NAME
	entity.add_child(sync)
	entity.server_setup(7, &"player", "Teste", &"male", &"city_awakening", Vector3(2,0,2))
	var grid: WalkGrid = WalkGrid.from_ascii(PackedStringArray(["..........","..........","..........","..........","..........","..........","..........","..........","..........",".........."]))
	entity.server_ensure_mover(grid, 200)
	session = PlayerSession.new(7, entity, CharacterData.create_new("Teste", &"male"))
	world._sessions[7] = session
	world._entities[7] = entity
	_test_save()
	_test_gates()
	_test_mount()
	_test_companions()
	_test_probability()
	entity.free()
	world.free()
	print("test_followers: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _test_save() -> void:
	var c: CharacterData = session.character
	var old: Dictionary = c.to_save()
	old.erase("companions")
	old.erase("mounts")
	old["format"] = 2
	var loaded: CharacterData = CharacterData.from_save(old)
	check(loaded != null and loaded.companions_owned.is_empty() and loaded.mounts_owned.is_empty(), "old save empty collections")
	c.companions_owned = [CompanionService.HARPY]
	c.companion_active = CompanionService.HARPY
	c.companion_names[String(CompanionService.HARPY)] = "Asa"
	c.mounts_owned = [DONKEY]
	session.mounted_id = DONKEY
	var saved: Dictionary = c.to_save()
	loaded = CharacterData.from_save(saved)
	check(loaded.companion_active == CompanionService.HARPY and loaded.companion_names[String(CompanionService.HARPY)] == "Asa", "companion/name persisted")
	check(loaded.mounts_owned == [DONKEY] and not saved.mounts.has("active") and not saved.has("mounted_id"), "mounted state never saved")
	check(int(saved.format) == 3, "save version increment")
	session.mounted_id = &""
	c.companion_active = &""
	c.companions_owned.clear()

func _test_gates() -> void:
	for id: StringName in [&"quest_bond_harpy", &"quest_bond_guara", &"quest_bond_lume", &"quest_mount_donkey"]:
		var q: QuestDef = Content.quest(id)
		check(q != null and q.required_causos == 2 and q.requires_left_training, "quest renown/leave training: " + String(id))
		check(not world.progression.quests.missing_requirements(session,q).is_empty(), "quest gate enforced")
		session.character.left_training = true
		session.character.causos = 2
		for title: StringName in q.required_titles:
			session.character.progression.titles[title] = 1
		check(world.progression.quests.missing_requirements(session,q).is_empty(), "no level gate: " + String(id))
		for step: QuestStep in q.steps:
			check(not step.scale_with_titles and QuestService.needs_for(q,20)[q.steps.find(step)] == step.count, "fixed solo quest quantities")
		session.character.left_training = false
		session.character.causos = 0
		session.character.progression.titles.clear()
	var city := load("res://scenes/maps/city_awakening.tscn") as PackedScene
	var map := city.instantiate() as GameMap
	check(map.get_npc_point(&"tropeiro") != null, "tropeiro has real map spawn")
	map.free()

func _test_mount() -> void:
	check(MountService.effective_ms(160,1) == 160 and MountService.effective_ms(160,2) == 130, "mounted speed and cap")
	check(MovePath.segment_msec(Vector3.ZERO,Vector3(1,0,1),160,1,Balance.cfg.diagonal_cost) == roundi(160 * Balance.cfg.diagonal_cost), "diagonal scaling preserved")
	check(world.mounts.request(session,DONKEY,10000).is_empty(), "mount channel accepted")
	world.mounts.tick(11499)
	check(session.mounted_id.is_empty(), "mount requires 1.5 seconds")
	world.mounts.tick(11500)
	check(session.mounted_id == DONKEY and session.entity.get_mover().ms_per_cell == 160, "mount activates and speed replicates")
	world.mounts.dismount(session,true,12000)
	check(session.mounted_id.is_empty() and session.entity.get_mover().ms_per_cell == 200, "damage dismounts immediately")
	check(world.mounts.block_reason(session,DONKEY,16999) == "MOUNT_HIT_LOCKOUT", "hit lockout 5 seconds")
	check(world.mounts.request(session,DONKEY,17000).is_empty(), "lockout expires")
	session.entity.net_position += Vector3(1,0,0)
	world.mounts.tick(18500)
	check(session.mounted_id.is_empty(), "moving interrupts mount")
	session.entity.instance_id = &"cave_reino_encoberto"
	check(world.mounts.block_reason(session,DONKEY,19000) == "MOUNT_ZONE_FORBIDDEN", "caves forbid mount")
	session.entity.instance_id = &"city_awakening"
	world.mounts.request(session,DONKEY,20000)
	session.character.hp = 0
	world.mounts.tick(21500)
	check(session.mounted_id.is_empty(), "death cancels mount")
	session.character.hp = 100
	# Changing speed midway keeps the position and current step, including stop/reroute.
	var mover: GridMover = session.entity.get_mover()
	var now: int = NetClock.server_now_msec_int()
	mover._set_path(MovePath.create(PackedVector3Array([Vector3(2,0,2),Vector3(3,0,2),Vector3(4,0,2)]),now-100,200,1,Balance.cfg.diagonal_cost))
	var before: Vector3 = mover.get_move_path().sample(now)
	mover.set_speed(160)
	check(mover.get_move_path().sample(now).is_equal_approx(before) and mover.get_move_path().times[1] == 200 and mover.get_move_path().times[2] == 360, "speed change preserves current interpolation")
	mover.move_to(Vector3(6,0,2))
	check(mover.get_move_path().sample(now).is_equal_approx(before), "reroute after speed change preserves position")
	mover.halt()

func _test_companions() -> void:
	for id: StringName in [CompanionService.HARPY,CompanionService.GUARA,CompanionService.LUME]:
		var def: CompanionDef = Content.companion(id)
		session.character.progression.titles[def.title_id] = 1
		check(SkillTree.tree_skills(def.title_id).size() == 5, "bond does not extend base tree")
		check(world.companions.grant(session,id), "companion grant")
		check(Content.title(def.title_id).bonus_skills.all(func(skill: StringName)->bool:return skill not in def.bond_skills), "bond not in title bonuses")
	var harpy: CompanionDef = Content.companion(CompanionService.HARPY)
	check(session.character.companion_active == harpy.id, "one active companion")
	for skill: StringName in harpy.bond_skills:
		var def: SkillDef = Content.skill(skill)
		check(session.character.progression.skill_level(skill) == 1 and def.max_level == 1, "fixed bond level")
		if def.passive:
			check(not world.progression.skills.is_hotbar_entry_valid(session,skill), "passive cannot be assigned")
			check(world.progression.caster.cast(session,skill,0,Vector3.ZERO) == "cast_passive_skill", "passive cannot be cast")
	check(world.companions.request(session,CompanionService.GUARA,1000).is_empty(), "swap accepted")
	world.companions.tick(2999)
	check(session.character.companion_active == harpy.id, "swap requires two seconds")
	world.companions.tick(3000)
	check(session.character.companion_active == CompanionService.GUARA, "swap selects exactly one companion")
	for skill: StringName in harpy.bond_skills:
		check(not session.character.progression.knows(skill) and session.character.progression.hotbar_index_of(skill) < 0, "old bond/hotbar removed")
	check(world.companions.request(session,CompanionService.LUME,62999) == "COMPANION_SWAP_COOLDOWN", "swap cooldown sixty seconds")
	check(world.companions.request(session,CompanionService.LUME,63000).is_empty(), "swap cooldown expires")
	world.companions.cancel(session)
	world.companions.tick(65000)
	check(session.character.companion_active == CompanionService.GUARA, "canceled swap stays unchanged")
	var mods: Dictionary = {"crit_override":-1.0}
	var attack: Dictionary = {&"luk":10}
	var defence: Dictionary = {&"def":100}
	world.companions.pre_hit(session.entity,StringName(CompanionService.SOURCE_PREFIX+String(CompanionService.HARPY)),mods,attack,defence)
	check(defence[&"def"] == 50, "harpy ignores half defence")
	check(not world.companions.on_hit(session.entity,session.entity,&"companion_test",1), "companion damage cannot recursively trigger")

func _test_probability() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73001
	for dex: int in [0,30,1000]:
		var chance: float = CompanionService.harpy_chance(dex)
		var hits: int = 0
		for _sample: int in 10000:
			if rng.randf() < chance:
				hits += 1
		check(absf(hits / 10000.0 - chance) < 0.015, "10k independent harpy rolls DES="+str(dex))
	check(CompanionService.harpy_chance(1000) == 0.2, "harpy probability cap")
