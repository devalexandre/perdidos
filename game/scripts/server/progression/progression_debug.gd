class_name ProgressionDebug
extends RefCounted
## Comandos de teste da progressão. Só existe com --progression-autotest ou --dev-commands no
## servidor (NetProgress.debug_enabled); nunca em jogo normal. Usado por tests/progression/ e, com
## --dev-commands, pelo chat: "/dev <comando> [args]" (ChatService). Lista: docs/debug-sabia.md.

const CMD_GRANT_XP: StringName = &"grant_xp"
const CMD_SET_CAP: StringName = &"set_cap"
const CMD_SPAWN_DUMMY: StringName = &"spawn_dummy"
const CMD_KILL: StringName = &"kill"
const CMD_GIVE_ITEM: StringName = &"give_item"
const CMD_EQUIP_ITEM: StringName = &"equip_item"
const CMD_LEARN: StringName = &"learn"
const CMD_SET_MP: StringName = &"set_mp"
const CMD_RESET_COOLDOWNS: StringName = &"reset_cooldowns"
const CMD_TELEPORT: StringName = &"teleport"
## goto <map_id> [marcador=SpawnPoint]: troca de mapa direto (testes do Pergaminho de Retorno e dos mapas).
const CMD_GOTO: StringName = &"goto"
# --- Terra do Sabiá v0.4 (docs/debug-sabia.md)
## grant_title <title_id>: concede o título (e os pais, pela herança).
const CMD_GRANT_TITLE: StringName = &"grant_title"
## learn_tree <title_id> [nível=3]: aprende as 5 skills da árvore com pelo menos esse nível.
const CMD_LEARN_TREE: StringName = &"learn_tree"
## skill_level <skill_id> <nível>: põe a skill (conhecida ou não) direto no nível.
const CMD_SKILL_LEVEL: StringName = &"skill_level"
## spawn_boss <monster_id> [atroz=0|1] [dx=3] [dz=0]: chefe (estágio 3, sem bando) ao lado; 1 = forma atroz.
const CMD_SPAWN_BOSS: StringName = &"spawn_boss"
## spawn_rare <monster_id> [dx=3] [dz=0]: variante rara do estágio 1.
const CMD_SPAWN_RARE: StringName = &"spawn_rare"
## set_hour <0..24>: muda a hora do mundo (DayNight, ciclo de dia e noite do agente de monstros).
const CMD_SET_HOUR: StringName = &"set_hour"
## kill_variant <monster_id|*> <any|rare|boss|atroz>: conta uma derrota com essa variante (quests).
const CMD_KILL_VARIANT: StringName = &"kill_variant"
## quest_step <quest_id> <etapa>: pula a quest ativa para a etapa (0 = primeira).
const CMD_QUEST_STEP: StringName = &"quest_step"
## quest_accept <quest_id> / quest_turn_in <quest_id> / quest_trial <quest_id>: aceita, entrega (no
## NPC que entrega) ou começa a provação sem ir até o NPC (os requisitos continuam valendo).
const CMD_QUEST_ACCEPT: StringName = &"quest_accept"
const CMD_QUEST_TURN_IN: StringName = &"quest_turn_in"
const CMD_QUEST_TRIAL: StringName = &"quest_trial"
## Provação de proteger (Vó Aninha): hurt_protected <dano> tira vida das mudas do jogador (mínimo 1);
## kill_protected [n=1] derruba n mudas; trial_time <s> faz a provação ativa acabar em s segundos.
const CMD_HURT_PROTECTED: StringName = &"hurt_protected"
const CMD_KILL_PROTECTED: StringName = &"kill_protected"
const CMD_TRIAL_TIME: StringName = &"trial_time"
## set_hp <n>: vida atual.
const CMD_SET_HP: StringName = &"set_hp"
## skill_points <n>: soma pontos de skill.
const CMD_SKILL_POINTS: StringName = &"skill_points"
const CMD_HELP: StringName = &"help"
## leave_training: marca que o personagem saiu do Campo de Treino (libera o 2º título).
const CMD_LEAVE_TRAINING: StringName = &"leave_training"
const DEFAULT_TREE_LEVEL: int = 3
const BOSS_OFFSET_CELLS: float = 3.0
const MSG_DEV: String = "PROG_DEV_REPLY"
const DEFAULT_DUMMY_HP: int = 100000
## Boneco de teste: não anda (passo lentíssimo), não bate, não dá XP.
const DUMMY_ID: StringName = &"q_test_dummy"
const DUMMY_WALK_MS: int = 100000000
## Visual emprestado para o boneco de teste.
const DUMMY_LOOK: StringName = &"stone_armadillo"
## Usável de teste (não poção): conjuração e recarga por grupo (GDD §8.1). Só em --progression-autotest.
const TEST_SCROLL_ID: StringName = &"q_test_scroll"
const TEST_SCROLL_CAST_SEC: float = 1.0
const TEST_SCROLL_COOLDOWN_SEC: float = 3.0
const TEST_SCROLL_GROUP: StringName = &"q_scroll"


## Também chamado pelo cliente do teste (dica/ícone na barra).
static func install_test_items() -> void:
	var db: Dictionary = Content.all(&"items")
	if db.has(TEST_SCROLL_ID):
		return
	var d := ItemDef.new()
	d.id = TEST_SCROLL_ID
	d.name_key = "Q_TEST_SCROLL"
	d.type = ItemDef.ItemType.CONSUMABLE
	d.stackable = true
	d.max_stack = 99
	d.use_effect = {&"cast_sec": TEST_SCROLL_CAST_SEC, &"cooldown_sec": TEST_SCROLL_COOLDOWN_SEC,
			&"cooldown_group": TEST_SCROLL_GROUP}
	db[TEST_SCROLL_ID] = d


## Também chamado pelo cliente do teste (visual do boneco).
static func install_dummy_def() -> void:
	var db: Dictionary = Content.all(&"monsters")
	if db.has(DUMMY_ID):
		return
	var st := MonsterStage.new()
	st.name_key = "Q_TEST_DUMMY"
	st.max_hp = DEFAULT_DUMMY_HP
	st.atk = 0
	st.walk_ms_per_cell = DUMMY_WALK_MS
	st.xp_reward = 0
	st.aggro_range_cells = 0
	var look: MonsterDef = Content.monster(DUMMY_LOOK)
	if look != null and not look.stages.is_empty():
		st.sprite_base = look.stages[0].sprite_base
	var d := MonsterDef.new()
	d.id = DUMMY_ID
	d.stages = [st]
	db[DUMMY_ID] = d

var progression: Progression = null


func _init(p_progression: Progression) -> void:
	progression = p_progression
	install_test_items()
	NetProgress.debug_intent.connect(_on_debug)


func _arg(args: Array, i: int, fallback: Variant) -> Variant:
	return args[i] if i < args.size() else fallback


func _on_debug(peer_id: int, command: StringName, args: Array) -> void:
	var world: ServerWorld = progression.world
	var s: PlayerSession = world.get_session(peer_id)
	if s == null:
		return
	Net.log_line("progression_debug", {"peer": peer_id, "cmd": String(command), "args": str(args)})
	var me: NetEntity = s.entity
	match command:
		CMD_GRANT_XP:
			progression.grant_xp(peer_id, int(_arg(args, 0, 0)), Progression.REASON_DEBUG)
		CMD_SET_CAP:
			progression.set_debug_cap(peer_id, int(_arg(args, 0, 0)))
		CMD_SPAWN_DUMMY:
			var off := Vector3(float(_arg(args, 1, 2.0)), 0.0, float(_arg(args, 2, 0.0)))
			var pos: Vector3 = world.snap_to_grid(me.instance_id, me.net_position + off)
			var mid := StringName(str(_arg(args, 0, DUMMY_ID)))
			if mid == DUMMY_ID:
				install_dummy_def()
			if progression.bridge.has_k():
				progression.bridge.spawn_trial_target(me.instance_id, mid, pos, peer_id)
			else:
				progression.bridge.spawn_stub_dummy(me.instance_id, mid, pos, DEFAULT_DUMMY_HP)
		CMD_KILL:
			progression.call(&"_on_monster_killed", peer_id, StringName(str(_arg(args, 0, ""))), 1,
					int(_arg(args, 1, 0)))
		CMD_GIVE_ITEM:
			s.character.inventory.add(StringName(str(_arg(args, 0, ""))), int(_arg(args, 1, 1)))
		CMD_EQUIP_ITEM:
			var item_id := StringName(str(_arg(args, 0, "")))
			if not s.character.inventory.has_item(item_id):
				s.character.inventory.add(item_id, 1)
			for slot: int in s.character.inventory.size():
				var st: ItemStack = s.character.inventory.get_slot(slot)
				if st != null and st.item_id == item_id:
					world.items.equip(s, slot)
					break
		CMD_LEARN:
			progression.skills.learn(s, StringName(str(_arg(args, 0, ""))), true)
			progression.titles.recalc(s)
		CMD_GRANT_TITLE:
			_grant_title(s, StringName(str(_arg(args, 0, ""))))
		CMD_LEARN_TREE:
			_learn_tree(s, StringName(str(_arg(args, 0, ""))), int(_arg(args, 1, DEFAULT_TREE_LEVEL)))
		CMD_SKILL_LEVEL:
			var sid := StringName(str(_arg(args, 0, "")))
			if Content.skill(sid) != null:
				s.character.progression.skills[sid] = clampi(int(_arg(args, 1, 1)), 1, Balance.cfg.max_skill_level)
				progression.titles.recalc(s)
		CMD_SPAWN_BOSS:
			_spawn_variant(s, StringName(str(_arg(args, 0, ""))), CombatRules.STAGE_BOSS, false,
					int(_arg(args, 1, 0)) != 0, float(_arg(args, 2, BOSS_OFFSET_CELLS)), float(_arg(args, 3, 0.0)))
		CMD_SPAWN_RARE:
			_spawn_variant(s, StringName(str(_arg(args, 0, ""))), CombatRules.STAGE_NORMAL, true, false,
					float(_arg(args, 1, BOSS_OFFSET_CELLS)), float(_arg(args, 2, 0.0)))
		CMD_SET_HOUR:
			_set_hour(s, float(_arg(args, 0, 0.0)))
		CMD_KILL_VARIANT:
			var variant := StringName(str(_arg(args, 1, "any")))
			var info: Dictionary = {QuestService.INFO_STAGE: CombatRules.STAGE_BOSS if variant in [
					QuestService.VARIANT_BOSS, QuestService.VARIANT_ATROZ] else 1,
					QuestService.INFO_RARE: variant == QuestService.VARIANT_RARE,
					QuestService.INFO_ATROZ: variant == QuestService.VARIANT_ATROZ,
					QuestService.INFO_NO_DEATH: true}
			progression.quests.on_monster_killed(peer_id, StringName(str(_arg(args, 0, ""))), info)
		CMD_QUEST_STEP:
			var qid := StringName(str(_arg(args, 0, "")))
			var st: Dictionary = s.character.progression.quests.get(qid, {})
			if not st.is_empty():
				st[ProgressionData.Q_STEP] = int(_arg(args, 1, 0))
				st[ProgressionData.Q_COUNT] = 0
				st.erase(ProgressionData.Q_SEEN)
		CMD_QUEST_ACCEPT:
			progression.quests.accept(s, StringName(str(_arg(args, 0, ""))))
		CMD_LEAVE_TRAINING:
			s.character.left_training = true
		CMD_QUEST_TURN_IN:
			var q: QuestDef = Content.quest(StringName(str(_arg(args, 0, ""))))
			if q != null:
				progression.quests.turn_in(s, q.id, QuestService.turn_in_npc_of(q))
		CMD_QUEST_TRIAL:
			progression.quests.start_trial(s, StringName(str(_arg(args, 0, ""))))
		CMD_HURT_PROTECTED, CMD_KILL_PROTECTED:
			var k: Object = progression.bridge.k_service()
			var left: int = int(_arg(args, 0, 1))
			for eid: int in progression.protected.keys():
				var e: NetEntity = world.get_entity(eid)
				if progression.protected[eid] != peer_id or e == null or e.hp_ratio <= 0.0 or k == null:
					continue
				var brain: Object = k.call(CombatBridge.M_GET_BRAIN, e)
				if command == CMD_KILL_PROTECTED:
					if left <= 0:
						break
					left -= 1
					k.call(&"_kill_monster", brain, null)
				else:
					brain.set(&"hp", maxi(1, int(brain.get(&"hp")) - int(_arg(args, 0, 1))))
					e.hp_ratio = float(brain.get(&"hp")) / float(brain.call(&"max_hp"))
		CMD_TRIAL_TIME:
			progression.quests.set_trial_deadline(peer_id, float(_arg(args, 0, 1.0)))
		CMD_SET_HP:
			s.character.hp = clampi(int(_arg(args, 0, 1)), 1, s.character.compute_stats()[CharacterStats.K_MAX_HP])
			s.mark_dirty(PlayerSession.DIRTY_STATS)
		CMD_SKILL_POINTS:
			s.character.progression.skill_points += int(_arg(args, 0, 1))
		CMD_HELP:
			_reply(peer_id, "grant_title learn_tree skill_level skill_points spawn_boss spawn_rare set_hour "
					+ "kill_variant quest_step quest_accept quest_turn_in quest_trial learn give_item equip_item "
					+ "grant_xp set_hp set_mp reset_cooldowns teleport hurt_protected kill_protected trial_time")
		CMD_SET_MP:
			s.character.mp = int(_arg(args, 0, 0))
			s.mark_dirty(PlayerSession.DIRTY_STATS)
		CMD_RESET_COOLDOWNS:
			progression.caster.call(&"reset_cooldowns", peer_id)
		CMD_TELEPORT:
			var p := Vector3(float(_arg(args, 0, 0.0)), me.net_position.y, float(_arg(args, 1, 0.0)))
			me.get_mover().place(world.snap_to_grid(me.instance_id, p))
		CMD_GOTO:
			var dest := StringName(str(_arg(args, 0, "")))
			if MapTransfer.map_exists(dest):
				world.map_transfer.transfer(s, dest, StringName(str(_arg(args, 1, "SpawnPoint"))))
			else:
				_reply(peer_id, "mapa não existe: %s" % dest)
	progression.mark_dirty(s)


func _reply(peer_id: int, text: String) -> void:
	Net.push_system_message(peer_id, MSG_DEV, [text])


## Concede o título e os pais (herança), sem mexer em skills.
func _grant_title(s: PlayerSession, title_id: StringName) -> void:
	var chain: Array[StringName] = []
	var t: StringName = title_id
	while not t.is_empty() and Content.title(t) != null and t not in chain:
		chain.push_front(t)
		t = Content.title(t).parent_title
	if chain.is_empty():
		_reply(s.peer_id, "título desconhecido: %s" % title_id)
		return
	for id: StringName in chain:
		progression.titles.grant(s, id)
	progression.titles.recalc(s)


## Aprende as skills da árvore (na ordem) com pelo menos `level`, cumprindo os pré-requisitos.
func _learn_tree(s: PlayerSession, title_id: StringName, level: int) -> void:
	var skills: Array[SkillDef] = SkillTree.tree_skills(title_id)
	if skills.is_empty():
		_reply(s.peer_id, "árvore vazia: %s" % title_id)
		return
	var data: ProgressionData = s.character.progression
	var lvl: int = clampi(level, 1, Balance.cfg.max_skill_level)
	for d: SkillDef in skills:
		for req: StringName in d.required_skill_levels:
			data.skills[req] = maxi(data.skill_level(req), d.required_skill_levels[req])
		if not data.knows(d.id):
			progression.skills.learn(s, d.id, true)
		data.skills[d.id] = maxi(data.skill_level(d.id), lvl)
	progression.titles.recalc(s)
	_reply(s.peer_id, "árvore %s: %d skills" % [title_id, skills.size()])


## Chefe (estágio 3, sem bando) ou raro ao lado do jogador. Forma atroz:
## MonsterBrain.atroz_pinned + update_atroz (agente de monstros; vale também de dia).
func _spawn_variant(s: PlayerSession, monster_id: StringName, stage_number: int, rare: bool,
		atroz: bool, dx: float, dz: float) -> void:
	var def: MonsterDef = Content.monster(monster_id)
	var k: Object = progression.bridge.k_service()
	var spawner: Object = k.get(&"spawner") if k != null else null
	if def == null or def.stages.is_empty() or spawner == null:
		_reply(s.peer_id, "monstro desconhecido ou sem combate: %s" % monster_id)
		return
	var me: NetEntity = s.entity
	var world: ServerWorld = progression.world
	var pos: Vector3 = world.snap_to_grid(me.instance_id,
			me.net_position + Vector3(dx, 0.0, dz) * Balance.cfg.cell_size)
	# Sem bando (o /chefe do agente de monstros traz o bando): chefe sozinho para testar as quests.
	var st: MonsterStage = def.stages[0]
	for cand: MonsterStage in def.stages:
		if cand.stage == stage_number:
			st = cand
	var e: NetEntity = spawner.call(&"spawn", me.instance_id, def, st, pos, CombatRules.DEFAULT_ROAM_CELLS,
			rare) as NetEntity
	if e == null:
		_reply(s.peer_id, "não nasceu (sem estágio de chefe ou sem grade)")
		return
	var brain: Object = k.call(CombatBridge.M_GET_BRAIN, e)
	var atroz_ok: bool = false
	if atroz and brain != null and &"atroz_pinned" in brain and brain.has_method(&"update_atroz"):
		brain.set(&"atroz_pinned", true)
		brain.call(&"update_atroz")
		atroz_ok = bool(brain.get(&"atroz"))
	Net.log_line("debug_spawn_variant", {"peer": s.peer_id, "monster": String(monster_id),
			"stage": stage_number, "rare": rare, "atroz": atroz_ok, "entity": e.entity_id})
	_reply(s.peer_id, "%s estágio %d%s%s (id %d)" % [monster_id, stage_number, " raro" if rare else "",
			" atroz" if atroz_ok else (" (sem forma atroz)" if atroz else ""), e.entity_id])


## Hora do mundo (0–24; o dia vai das 6h às 18h, WorldClock): acerta o relógio do DayNight (agente de
## monstros) e tira a força de dia/noite.
func _set_hour(s: PlayerSession, hour: float) -> void:
	var h: float = fposmod(hour, WorldClock.HOURS_PER_DAY)
	var day_len: float = DayNight.day_sec if DayNight.day_sec > 0.0 else WorldClock.day_sec()
	var night_len: float = DayNight.night_sec if DayNight.night_sec > 0.0 else WorldClock.night_sec()
	var since_dawn: float = fposmod(h - WorldClock.DAY_START_HOUR, WorldClock.HOURS_PER_DAY)
	var t: float = since_dawn / WorldClock.DAY_HOURS * day_len if since_dawn < WorldClock.DAY_HOURS \
			else day_len + (since_dawn - WorldClock.DAY_HOURS) / WorldClock.DAY_HOURS * night_len
	DayNight.set_force(WorldClock.Force.NONE)
	DayNight.set_time_of_cycle(t)
	_reply(s.peer_id, "hora = %.1f (%s)" % [h, "noite" if DayNight.is_night() else "dia"])
	Net.log_line("debug_set_hour", {"peer": s.peer_id, "hour": h, "t": snappedf(t, 0.1),
			"night": DayNight.is_night()})
