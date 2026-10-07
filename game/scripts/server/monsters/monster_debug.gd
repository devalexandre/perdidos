class_name MonsterDebug
extends RefCounted
## Comandos de teste do dono para chefes, dia e noite e forma atroz (docs/chefes-dia-noite.md). Digitados
## no chat do jogo; só existem com o servidor em --dev-commands (make run-dev) ou --autotest. Nunca em jogo
## normal. Seguem o jeito do ProgressionDebug (constantes + match), mas pelo chat, para o dono usar no
## cliente real. A resposta volta como mensagem de sistema (SYS_DEV_INFO).
##
##   /chefe [espécie [dx dz]]  chefe (estágio 3) + bando do seu lado ou a dx,dz células de você (vale até no
##                         Campo de Treino, só teste)
##   /covil [espécie]      sem espécie: lista os covis fixos do mapa (vivo, atroz, renasce em N s); com espécie:
##                         o chefe daquele covil renasce já (se não estiver vivo)
##   /atroz [espécie [dx dz]]  chefe mais perto vira atroz e fica (de novo = volta ao normal); sem chefe perto
##                         ou com espécie: cria um já atroz do seu lado
##   /noite  /dia          força a noite / o dia (vale também no Campo de Treino)
##   /hora [normal]        mostra o relógio; "normal" tira a força
##   /anoitecer /amanhecer relógio 15 s antes da virada (para ver a transição da luz)
##   /derrubar [chefe]     derruba o monstro (ou o chefe) mais perto como se fosse golpe seu (drops, XP, quests;
##                         chefe de covil renasce no tempo normal)
##   /limpar               tira de cena (sem drops) os chefes e bandos a até 40 m de você (covil: renasce no tempo
##                         normal)
##   /ajuda                lista os comandos
## Espécie: id (stone_armadillo) ou apelido (tatu, vagalume, redemoinho). Padrão: a do monstro mais perto.

const ARG_DEV: String = "--dev-commands"
const PREFIX: String = "/"
const MSG_INFO: String = "SYS_DEV_INFO"
const MSG_BOSS: String = "SYS_BOSS_APPEARED"
const CMD_BOSS: String = "chefe"
const CMD_LAIR: String = "covil"
const CMD_ATROZ: String = "atroz"
const CMD_NIGHT: String = "noite"
const CMD_DAY: String = "dia"
const CMD_CLOCK: String = "hora"
const CMD_DUSK: String = "anoitecer"
const CMD_DAWN: String = "amanhecer"
const CMD_HELP: String = "ajuda"
const CMD_KILL: String = "derrubar"
const CMD_CLEAR: String = "limpar"
const CLEAR_M: float = 40.0
const SOURCE_DEBUG_KILL: StringName = &"debug_kill"
const CLOCK_NORMAL: String = "normal"
## Apelidos em português das espécies.
const ALIASES: Dictionary[String, StringName] = {"tatu": &"stone_armadillo", "tatu-pedra": &"stone_armadillo",
		"vagalume": &"enchanted_firefly", "vaga-lume": &"enchanted_firefly", "redemoinho": &"prank_whirlwind"}
const DEFAULT_SPECIES: StringName = &"stone_armadillo"
## Distância (m) da busca do monstro/chefe "mais perto" e do ponto em que o chefe nasce (células à frente).
const NEAR_M: float = 30.0
const SPAWN_AHEAD_CELLS: float = 5.0
## /anoitecer e /amanhecer: segundos antes da virada.
const TURN_LEAD_SEC: float = 15.0
const HELP: String = "/chefe [espécie [dx dz]] · /covil [espécie] · /atroz [espécie [dx dz]] · /noite · /dia · /hora [normal] · /anoitecer · /amanhecer · /derrubar [chefe] · /limpar"

var spawner: MonsterSpawner = null


static func enabled(world: ServerWorld) -> bool:
	return ARG_DEV in OS.get_cmdline_user_args() or (world != null and world.autotest)


func _init(p_spawner: MonsterSpawner) -> void:
	spawner = p_spawner
	CombatEvents.bus().monster_killed_info.connect(_on_kill_info)
	Net.log_line("monster_debug_ready", {"commands": HELP})


## Só registra (testes conferem que o evento de abate com detalhes chega a quem escuta, como o QuestService).
func _on_kill_info(killer_peer: int, monster_id: StringName, info: Dictionary) -> void:
	Net.log_line("kill_info_event", {"killer": killer_peer, "monster": String(monster_id), "stage": info.get("stage"),
			"form_stage": info.get("form_stage"), "boss": info.get("boss"), "atroz": info.get("atroz"),
			"rare": info.get("rare"), "map": String(info.get("map_id", ""))})


## Texto do chat começando com "/": true = era um comando daqui (não vai para o chat).
func handle_chat(session: PlayerSession, text: String) -> bool:
	if not text.begins_with(PREFIX):
		return false
	var parts: PackedStringArray = text.trim_prefix(PREFIX).strip_edges().split(" ", false)
	if parts.is_empty():
		return false
	var cmd: String = parts[0].to_lower()
	var args: PackedStringArray = parts.slice(1)
	if cmd not in [CMD_BOSS, CMD_LAIR, CMD_ATROZ, CMD_NIGHT, CMD_DAY, CMD_CLOCK, CMD_DUSK, CMD_DAWN,
			CMD_HELP, CMD_KILL, CMD_CLEAR]:
		return false
	Net.log_line("monster_debug", {"peer": session.peer_id, "cmd": cmd, "args": str(args)})
	run(session, cmd, args)
	return true


func run(session: PlayerSession, cmd: String, args: PackedStringArray) -> void:
	var me: NetEntity = session.entity
	match cmd:
		CMD_BOSS:
			var def: MonsterDef = _species(session, args, 0)
			var e: NetEntity = spawner.spawn_boss(me.instance_id, def, _spawn_pos(me, args), CombatRules.DEFAULT_ROAM_CELLS,
					"debug", MSG_BOSS) if def != null else null
			_say(session, "chefe %s: %s" % [def.id if def != null else "?", _desc(e)])
		CMD_LAIR:
			_lair(session, args)
		CMD_ATROZ:
			_atroz(session, args)
		CMD_NIGHT:
			DayNight.set_force(WorldClock.Force.NIGHT)
			_say(session, _clock())
		CMD_DAY:
			DayNight.set_force(WorldClock.Force.DAY)
			_say(session, _clock())
		CMD_CLOCK:
			if not args.is_empty() and args[0].to_lower() == CLOCK_NORMAL:
				DayNight.set_force(WorldClock.Force.NONE)
			_say(session, _clock())
		CMD_DUSK:
			DayNight.force = WorldClock.Force.NONE
			DayNight.set_time_of_cycle(DayNight.day_sec - TURN_LEAD_SEC)
			_say(session, _clock())
		CMD_DAWN:
			DayNight.force = WorldClock.Force.NONE
			DayNight.set_time_of_cycle(DayNight.day_sec + DayNight.night_sec - TURN_LEAD_SEC)
			_say(session, _clock())
		CMD_HELP:
			_say(session, HELP)
		CMD_CLEAR:
			var n: int = 0
			for m: NetEntity in spawner.combat.monsters_in_radius(me.instance_id, me.net_position, CLEAR_M):
				var mb: MonsterBrain = spawner.combat.get_brain(m)
				if mb != null and (mb.is_boss() or mb.boss_entity_id != 0):
					mb.mark_dead()
					if not mb.spawn_slot.is_empty():
						spawner.schedule_respawn(mb.spawn_slot)
					spawner.world.despawn_entity(m)
					n += 1
			_say(session, "limpar: %d chefes/bandos removidos" % n)
		CMD_KILL:
			var boss_only: bool = not args.is_empty() and args[0].to_lower() == CMD_BOSS
			var nb: MonsterBrain = _nearest_boss(me, false) if boss_only else null
			var t: NetEntity = nb.get_entity() if nb != null else (null if boss_only else _nearest_monster(me))
			var tb: MonsterBrain = spawner.combat.get_brain(t) if t != null else null
			if tb == null:
				_say(session, "nenhum monstro por perto")
				return
			var r: Dictionary = spawner.combat.deal_damage(me, t, CombatService.KIND_TRUE, float(tb.hp + 1),
					SOURCE_DEBUG_KILL)
			_say(session, "derrubar %s (#%d, atroz=%s): %s" % [tb.def.id, t.entity_id, tb.atroz,
					"ok" if r.get("killed", false) else str(r.get("reason", "?"))])


func _atroz(session: PlayerSession, args: PackedStringArray) -> void:
	var me: NetEntity = session.entity
	if args.is_empty():
		var near: MonsterBrain = _nearest_boss(me)
		if near != null:
			var on: bool = not near.atroz_pinned
			near.atroz_pinned = on
			if not on:
				near.set_atroz(false) # volta já (o relógio pode ligar de novo se for noite)
			near.update_atroz()
			_say(session, "%s: atroz=%s (fixo=%s)" % [near.def.id, near.atroz, near.atroz_pinned])
			return
	var def: MonsterDef = _species(session, args, 0)
	if def == null or def.atroz_stage() == null:
		_say(session, "espécie sem forma atroz: %s" % (def.id if def != null else "?"))
		return
	var e: NetEntity = spawner.spawn_boss(me.instance_id, def, _spawn_pos(me, args), CombatRules.DEFAULT_ROAM_CELLS,
			"debug_atroz", MSG_BOSS)
	var b: MonsterBrain = spawner.combat.get_brain(e) if e != null else null
	if b != null:
		b.atroz_pinned = true
		b.update_atroz()
	_say(session, "atroz %s: %s" % [def.id, _desc(e)])


# ---------------------------------------------------------------- auxiliares

func _say(session: PlayerSession, text: String) -> void:
	Net.push_system_message(session.peer_id, MSG_INFO, [text])
	Net.log_line("monster_debug_reply", {"peer": session.peer_id, "text": text})


func _clock() -> String:
	var d: Dictionary = DayNight.describe()
	var force: String = ["", " (forçado: dia)", " (forçado: noite)"][int(d["force"])]
	return "relógio %s, %s%s; próxima virada em %d s" % [d["clock"], "noite" if d["night"] else "dia", force,
			int(d["next_turn_sec"])]


## /covil: sem espécie lista os covis; com espécie faz o chefe daquele covil renascer já.
func _lair(session: PlayerSession, args: PackedStringArray) -> void:
	var lairs: Array[Dictionary] = spawner.lairs_of(session.entity.instance_id)
	if lairs.is_empty():
		_say(session, "este mapa não tem covil de chefe")
		return
	if args.is_empty():
		var parts: PackedStringArray = []
		for l: Dictionary in lairs:
			var b: MonsterBrain = spawner.combat.get_brain(l["alive"]) if l["alive"] != null else null
			var state: String = ("vivo" + (" (atroz)" if b.atroz else "")) if b != null \
					else "renasce em %d s" % int(l["respawn_in_sec"])
			parts.append("%s: %s" % [l["monster"], state])
		_say(session, "covis: " + ", ".join(parts))
		return
	var raw: String = args[0].to_lower()
	var want: StringName = ALIASES.get(raw, StringName(raw))
	for l: Dictionary in lairs:
		var mid: StringName = l["monster"]
		if mid == want or MonsterDef.species_of(mid) == want:
			var e: NetEntity = spawner.respawn_lair_now(l["slot"])
			_say(session, "covil %s: %s" % [mid, _desc(e)])
			return
	_say(session, "nenhum covil de %s neste mapa" % raw)


func _species(session: PlayerSession, args: PackedStringArray, index: int) -> MonsterDef:
	if args.size() > index:
		var raw: String = args[index].to_lower()
		var id: StringName = ALIASES.get(raw, StringName(raw))
		return Content.monster(id)
	var near: NetEntity = _nearest_monster(session.entity)
	var b: MonsterBrain = spawner.combat.get_brain(near) if near != null else null
	if b != null and MonsterEvolution.stage_by_number(b.def, CombatRules.STAGE_BOSS) != null:
		return b.def
	return Content.monster(DEFAULT_SPECIES)


func _nearest_monster(me: NetEntity) -> NetEntity:
	var best: NetEntity = null
	var best_d: float = NEAR_M
	for m: NetEntity in spawner.combat.monsters_in_radius(me.instance_id, me.net_position, NEAR_M):
		var d: float = me.flat_distance_to(m.net_position)
		if d <= best_d:
			best_d = d
			best = m
	return best


func _nearest_boss(me: NetEntity, needs_atroz_form: bool = true) -> MonsterBrain:
	var best: MonsterBrain = null
	var best_d: float = NEAR_M
	for m: NetEntity in spawner.combat.monsters_in_radius(me.instance_id, me.net_position, NEAR_M):
		var b: MonsterBrain = spawner.combat.get_brain(m)
		var d: float = me.flat_distance_to(m.net_position)
		if b != null and b.is_boss() and (b.def.atroz_stage() != null or not needs_atroz_form) and d <= best_d:
			best_d = d
			best = b
	return best


## args [espécie, dx, dz]: a dx,dz células do jogador; sem eles, SPAWN_AHEAD_CELLS à frente dele.
func _spawn_pos(me: NetEntity, args: PackedStringArray) -> Vector3:
	var grid: WalkGrid = spawner.world.get_grid_for_instance(me.instance_id)
	var cell: float = grid.cell_size if grid != null else Balance.cfg.cell_size
	if args.size() >= 3 and args[1].is_valid_float() and args[2].is_valid_float():
		var off := Vector3(args[1].to_float(), 0.0, args[2].to_float()) * cell
		return spawner.world.snap_to_grid(me.instance_id, me.net_position + off)
	return _ahead(me, cell)


## Ponto SPAWN_AHEAD_CELLS à frente do jogador (para onde ele olha), encaixado na grade.
func _ahead(me: NetEntity, cell: float) -> Vector3:
	var fwd := Vector3(-sin(me.facing_yaw), 0.0, -cos(me.facing_yaw)) # NetEntity.face_towards
	return spawner.world.snap_to_grid(me.instance_id, me.net_position + fwd * SPAWN_AHEAD_CELLS * cell)


func _desc(e: NetEntity) -> String:
	if e == null:
		return "falhou (ver log do servidor)"
	var b: MonsterBrain = spawner.combat.get_brain(e)
	return "#%d vida %d, ATQ %d, atroz=%s" % [e.entity_id, b.max_hp(), int(b.combat_stats().get(&"atk", 0)), b.atroz]
