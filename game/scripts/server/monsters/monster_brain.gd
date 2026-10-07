class_name MonsterBrain
extends Node
## Componente de SERVIDOR anexado ao NetEntity de um monstro (kind &"monster"): estado de combate
## (espécie, estágio, vida) e IA do GDD §10.3:
##   IDLE -> PATROL -> CHASE -> ATTACK -> RETURN (volta à origem e recupera a vida) ; DEAD.
## Agressivos procuram jogadores vivos a aggro_range_cells; passivos só reagem a quem os ataca.
## Quem se afasta mais de leash_cells da origem volta (sem aceitar novos alvos até chegar).
## Movimento pelo GridMover (mesma grade dos jogadores). O CombatService chama tick() antes do
## movimento e resolve os golpes (apply_damage).
##
## Forma atroz (TITULOS-E-SKILLS §3.0 item 5, GDD §10.7): o chefe (estágio 3) de uma espécie com estágio 4
## em MonsterDef.stages vira atroz quando é noite no mapa (DayNight.is_night_on_map) — ao nascer ou já vivo.
##  - stage passa a ser o estágio 4 (nome, folhas _s4, nível, aggro/leash maiores, golpe mais rápido, XP,
##    Estrelas e drops melhores); os atributos são os do chefe × MonsterEvolution.atroz_multiplier (+100%).
##  - Mais agressivo: ao entrar em combate chama o bando (Balance.cfg.atroz_call_escort_radius_cells) e
##    prefere o jogador mais fraco (menos vida) por perto, revendo o alvo a cada atroz_retarget_interval_sec.
##  - Amanheceu: se estiver fora de combate (parado, patrulhando ou voltando), volta a ser o chefe normal na
##    hora; em combate, continua atroz até a luta acabar (decisão documentada em docs/chefes-dia-noite.md).
##    Nunca some. A proporção da vida é mantida nas duas trocas.

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD }

const NODE_NAME: String = "MonsterBrain"

var combat: CombatService = null
var def: MonsterDef = null
var stage: MonsterStage = null
var hp: int = 0
## Ponto de origem (spawn) e raio de patrulha em células.
var origin: Vector3 = Vector3.ZERO
var roam_radius_cells: float = CombatRules.DEFAULT_ROAM_CELLS
## Vaga do spawner que renasce quando este morre ("" = não renasce: bando do chefe).
var spawn_slot: String = ""
## entity_id do chefe deste bando (0 = não é bando).
var boss_entity_id: int = 0
## Agente R (GDD §10.2): variante rara (atributos × rare_multiplier(), drops melhores). Definido
## pelo MonsterSpawner ANTES do setup; vale para a vida toda (também depois de evoluir).
var rare: bool = false
## Forma atroz ativa (chefe à noite). Replicada em NetEntity.appearance["atroz"] e no NetEntity.stage (4).
var atroz: bool = false
## Comando de teste: fica atroz mesmo de dia (MonsterDebug "atroz").
var atroz_pinned: bool = false
var state: State = State.IDLE
## Alvo atual (jogador) e quem deu o último golpe (crédito da morte).
var target: NetEntity = null
var last_hitter_peer: int = 0
## GDD §5 / §10.5 (30/09/2026, mapas compartilhados): dano causado por jogador (peer -> dano). Quem causou
## mais é o dono do monstro: leva o crédito do abate, a XP (dividida com o grupo dele) e a posse do drop.
## Zera quando o monstro volta para casa e recupera a vida.
var damage_by_peer: Dictionary[int, int] = {}
## Provação (QuestService): o peer dono. 0 = monstro comum. Monstro com dono só ataca e só pode ser atacado
## por esse jogador e pelo grupo dele (CombatService.attack_block_reason).
var owner_peer: int = 0
## Surrupiar (ofício da Garra da Onça): peer que já surrupiou deste monstro (0 = ninguém). Um por monstro.
var stolen_by: int = 0
## Comportamentos (MonsterBehaviors).
var pattern_index: int = -1
var charge_left_sec: float = 0.0
var charged_once: bool = false
## Superstições de Crendice: rastreia se o jogador atacou primeiro ou se foi emboscado pelo monstro
var player_initiated: bool = false
var last_hit_was_crit: bool = false

var _pause_left: float = 0.0
var _next_attack_msec: int = 0
var _next_repath_msec: int = 0
var _last_target_cell: Vector2i = Vector2i(-1, -1)
var _rng := RandomNumberGenerator.new()
## Estágio do chefe guardado enquanto está atroz (atributos e volta ao amanhecer).
var _boss_stage: MonsterStage = null
var _map_id: StringName = &""
var _next_retarget_msec: int = 0


func setup(p_combat: CombatService, p_def: MonsterDef, p_stage: MonsterStage, p_origin: Vector3,
		p_roam_cells: float) -> void:
	combat = p_combat
	def = p_def
	origin = p_origin
	roam_radius_cells = p_roam_cells
	_rng.randomize()
	_pause_left = _rng.randf_range(CombatRules.PATROL_PAUSE_MIN_SEC, CombatRules.PATROL_PAUSE_MAX_SEC)
	var e: NetEntity = get_entity()
	if e != null and combat != null and combat.world != null:
		_map_id = combat.world.get_instance_map_id(e.instance_id)
	set_stage(p_stage)
	update_atroz()


func get_entity() -> NetEntity:
	return get_parent() as NetEntity


func cell_size() -> float:
	var mover: GridMover = get_entity().get_mover() if get_entity() != null else null
	return mover.grid.cell_size if mover != null and mover.grid != null else Balance.cfg.cell_size


func is_dead() -> bool:
	return state == State.DEAD


func max_hp() -> int:
	var src: MonsterStage = stat_stage()
	return maxi(1, roundi(float(src.max_hp) * stat_multiplier())) if src != null else 1


## Estágio de onde vêm vida/ATQ/DEF: o do chefe quando atroz, senão o atual.
func stat_stage() -> MonsterStage:
	return _boss_stage if atroz and _boss_stage != null else stage


## Raro × atroz.
func stat_multiplier() -> float:
	return rare_multiplier() * (MonsterEvolution.atroz_multiplier(def) if atroz else 1.0)


## Estágio de evolução (1..3). A forma atroz conta como chefe (3).
func evolution_stage() -> int:
	if stage == null:
		return 0
	return mini(stage.stage, CombatRules.STAGE_BOSS)


## É o chefe da espécie (normal ou atroz)?
func is_boss() -> bool:
	return evolution_stage() == CombatRules.STAGE_BOSS


## Multiplicador dos atributos: 1 normal; raro = MonsterDef.rare_stat_multiplier ou o do Balance.
func rare_multiplier() -> float:
	if not rare:
		return 1.0
	if def != null and def.rare_stat_multiplier > 0.0:
		return def.rare_stat_multiplier
	return Balance.cfg.rare_stat_multiplier


## Troca de estágio (nascer ou evoluir): atributos do estágio, vida cheia, nome e nível replicados.
func set_stage(p_stage: MonsterStage) -> void:
	atroz = false
	_boss_stage = null
	stage = p_stage
	MonsterBehaviors.warn_unknown(stage)
	hp = max_hp()
	var e: NetEntity = get_entity()
	if e != null:
		apply_to_entity()


## Replica estágio, nome, nível e vida na entidade.
func apply_to_entity() -> void:
	var e: NetEntity = get_entity()
	if e == null or stage == null:
		return
	e.stage = stage.stage
	e.level = stage.level
	e.display_name = stage.name_key
	e.hp_ratio = float(hp) / float(max_hp())
	var mover: GridMover = e.get_mover()
	if mover != null:
		mover.ms_per_cell = MonsterBehaviors.ms_per_cell(self)


## Atributos de combate (mesmas chaves do CharacterStats): atk, matk, def, mdef, dex, level.
func combat_stats() -> Dictionary:
	var src: MonsterStage = stat_stage()
	if src == null:
		return {}
	var m: float = stat_multiplier()
	return {&"atk": roundi(src.atk * m), &"matk": roundi(src.matk * m), &"def": roundi(src.def * m),
			&"mdef": roundi(src.mdef * m), &"dex": DamageFormula.monster_dex(stage.dex, stage.level),
			&"luk": 0, &"level": stage.level}


func attack_range_world() -> float:
	return stage.attack_range_cells * cell_size() if stage != null else cell_size()


## Chamado pelo CombatService quando leva dano (antes de checar a morte).
func on_damaged(attacker: NetEntity) -> void:
	if attacker != null and attacker.is_player():
		last_hitter_peer = attacker.get_peer_id()
		if not player_initiated and state in [State.IDLE, State.PATROL]:
			player_initiated = true
	MonsterBehaviors.on_damaged(self)
	if state in [State.IDLE, State.PATROL] and attacker != null and combat.is_valid_victim(self, attacker):
		_engage(attacker)


## Conta o dano de um jogador (dono = quem causou mais).
func add_damage(peer_id: int, amount: int) -> void:
	if peer_id != 0 and amount > 0:
		damage_by_peer[peer_id] = int(damage_by_peer.get(peer_id, 0)) + amount


## Dono do monstro agora: o jogador online que causou mais dano (empate: quem bateu por último entre eles).
## Sem ninguém online na lista: quem deu o último golpe.
func top_damage_peer() -> int:
	var best: int = 0
	var best_dmg: int = -1
	for peer: int in damage_by_peer:
		if combat != null and combat.world != null and combat.world.get_session(peer) == null:
			continue
		var d: int = damage_by_peer[peer]
		if d > best_dmg or (d == best_dmg and peer == last_hitter_peer):
			best = peer
			best_dmg = d
	return best if best != 0 else last_hitter_peer


## O alvo morreu ou saiu: volta para casa.
func drop_target(entity: NetEntity) -> void:
	if target == entity and state in [State.CHASE, State.ATTACK]:
		_start_return()


func mark_dead() -> void:
	state = State.DEAD
	target = null
	var e: NetEntity = get_entity()
	e.target_id = 0
	e.get_mover().halt()


## Um tick de decisão (antes do GridMover).
func tick(delta: float) -> void:
	if state == State.DEAD or stage == null:
		return
	var e: NetEntity = get_entity()
	var mover: GridMover = e.get_mover()
	if mover == null or mover.grid == null:
		return
	if charge_left_sec > 0.0:
		charge_left_sec -= delta
	update_atroz()
	mover.ms_per_cell = MonsterBehaviors.ms_per_cell(self)
	match state:
		State.IDLE:
			_tick_idle(delta, mover)
		State.PATROL:
			if _try_aggro():
				return
			if not mover.is_moving():
				state = State.IDLE
		State.CHASE:
			_tick_chase(mover)
		State.ATTACK:
			_tick_attack(mover)
		State.RETURN:
			_tick_return(mover)


func _tick_idle(delta: float, mover: GridMover) -> void:
	if _try_aggro():
		return
	_pause_left -= delta
	if _pause_left > 0.0:
		return
	_pause_left = _rng.randf_range(CombatRules.PATROL_PAUSE_MIN_SEC, CombatRules.PATROL_PAUSE_MAX_SEC)
	var plan: Dictionary = MonsterBehaviors.patrol_target(self, _rng)
	var point: Vector3 = plan["point"]
	if point == Vector3.INF:
		point = _random_roam_point(mover.grid)
	if point == Vector3.INF:
		return
	if plan["teleport"]:
		mover.place(mover.grid.snap(point))
		return
	if mover.move_to(point):
		state = State.PATROL


func _random_roam_point(grid: WalkGrid) -> Vector3:
	var r: float = roam_radius_cells * grid.cell_size
	for i: int in range(CombatRules.PATROL_PICK_ATTEMPTS):
		var angle: float = _rng.randf_range(0.0, TAU)
		var dist: float = _rng.randf_range(0.0, r)
		var c: Vector2i = grid.world_to_cell(origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist))
		if grid.is_walkable(c):
			return grid.cell_to_world(c)
	return Vector3.INF


func _try_aggro() -> bool:
	if not stage.aggressive:
		return false
	var victim: NetEntity = weakest_target_near(stage.aggro_range_cells * cell_size()) if atroz \
			else combat.find_aggro_target(self, stage.aggro_range_cells * cell_size())
	if victim == null:
		return false
	_engage(victim)
	return true


func _engage(victim: NetEntity) -> void:
	var was_fighting: bool = state in [State.CHASE, State.ATTACK]
	target = victim
	get_entity().target_id = victim.entity_id
	state = State.CHASE
	_next_repath_msec = 0
	_last_target_cell = Vector2i(-1, -1)
	if atroz and not was_fighting:
		call_escort(victim)


func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and combat.is_valid_victim(self, target)


func _beyond_leash() -> bool:
	return get_entity().flat_distance_to(origin) > float(stage.leash_cells) * cell_size()


func _tick_chase(mover: GridMover) -> void:
	if not _target_ok() or _beyond_leash():
		_start_return()
		return
	_atroz_retarget()
	var e: NetEntity = get_entity()
	var reach: float = attack_range_world()
	if e.flat_distance_to(target.net_position) <= reach:
		mover.stop()
		state = State.ATTACK
		_tick_attack(mover)
		return
	var now: int = Time.get_ticks_msec()
	var cell: Vector2i = mover.grid.world_to_cell(target.net_position)
	if (not mover.is_moving() or cell != _last_target_cell) and now >= _next_repath_msec:
		_next_repath_msec = now + CombatRules.REPATH_INTERVAL_MSEC
		_last_target_cell = cell
		if not mover.move_to(target.net_position, reach) and not mover.is_moving() \
				and e.flat_distance_to(target.net_position) > reach + CombatRules.CHASE_WAIT_CELLS * cell_size():
			# Sem caminho e longe: desiste. (Perto: o alvo está no meio de um passo; espera o próximo.)
			_start_return()


func _tick_attack(mover: GridMover) -> void:
	if not _target_ok():
		_start_return()
		return
	if _atroz_retarget():
		return
	var e: NetEntity = get_entity()
	if e.flat_distance_to(target.net_position) > attack_range_world() \
			+ CombatRules.RANGE_SLACK_CELLS * cell_size():
		state = State.CHASE
		_next_repath_msec = 0
		return
	if mover.is_moving():
		return
	e.face_towards(target.net_position)
	var now: int = Time.get_ticks_msec()
	if now < _next_attack_msec:
		return
	_next_attack_msec = now + stage.attack_interval_ms
	combat.monster_attack(self, target)


func _start_return() -> void:
	target = null
	var e: NetEntity = get_entity()
	e.target_id = 0
	state = State.RETURN
	var mover: GridMover = e.get_mover()
	if e.flat_distance_to(origin) <= CombatRules.HOME_EPSILON_CELLS * cell_size():
		_arrive_home()
		return
	if not mover.move_to(origin):
		mover.place(mover.grid.snap(origin))
		_arrive_home()


func _tick_return(mover: GridMover) -> void:
	if mover.is_moving():
		return
	if get_entity().flat_distance_to(origin) > CombatRules.HOME_EPSILON_CELLS * cell_size():
		# Chegou ao fim de um caminho parcial: tenta de novo, senão volta direto.
		if not mover.move_to(origin):
			mover.place(mover.grid.snap(origin))
			_arrive_home()
		return
	_arrive_home()


## GDD §10.3: voltou para a origem -> recupera toda a vida.
func _arrive_home() -> void:
	hp = max_hp()
	damage_by_peer.clear()
	charged_once = false
	charge_left_sec = 0.0
	player_initiated = false
	last_hit_was_crit = false
	state = State.IDLE
	apply_to_entity()
	Net.log_line("monster_returned", {"id": get_entity().entity_id, "monster": String(def.id),
			"hp": hp, "pos": str(get_entity().net_position)})



# ================================================================ forma atroz

## Liga/desliga a forma atroz conforme a hora no mapa (chamado ao nascer e a cada tick).
func update_atroz() -> void:
	if stage == null or def == null or state == State.DEAD:
		return
	if not atroz and stage.stage != CombatRules.STAGE_BOSS:
		return
	var want: bool = atroz_pinned or DayNight.is_night_on_map(_map_id)
	if want and not atroz:
		set_atroz(true)
	elif not want and atroz and state in [State.IDLE, State.PATROL, State.RETURN]:
		set_atroz(false)


## Troca para a forma atroz (on) ou de volta para o chefe. false = a espécie não tem estágio 4 / não é chefe.
func set_atroz(on: bool) -> bool:
	if on == atroz:
		return true
	var ratio: float = float(hp) / float(max_hp()) if stage != null else 1.0
	if on:
		var st: MonsterStage = def.atroz_stage() if def != null else null
		if st == null or stage == null or stage.stage != CombatRules.STAGE_BOSS:
			return false
		_boss_stage = stage
		stage = st
		atroz = true
	else:
		stage = _boss_stage if _boss_stage != null else MonsterEvolution.stage_by_number(def, CombatRules.STAGE_BOSS)
		_boss_stage = null
		atroz = false
	MonsterBehaviors.warn_unknown(stage)
	hp = maxi(1, roundi(float(max_hp()) * clampf(ratio, 0.0, 1.0)))
	var e: NetEntity = get_entity()
	if e == null:
		return true
	apply_to_entity()
	var app: Dictionary = e.appearance.duplicate()
	if atroz:
		app[MonsterSpawner.APPEARANCE_ATROZ] = true
	else:
		app.erase(MonsterSpawner.APPEARANCE_ATROZ)
	e.appearance = app
	Net.log_line("monster_atroz", {"id": e.entity_id, "monster": String(def.id), "atroz": atroz,
			"stage": stage.stage, "hp": hp, "max_hp": max_hp(), "atk": int(combat_stats().get(&"atk", 0)),
			"instance": String(e.instance_id), "clock": DayNight.clock_text(), "pinned": atroz_pinned})
	if atroz:
		for p: int in Net.get_instance_peer_ids(e.instance_id):
			Net.push_system_message(p, MonsterSpawner.MSG_ATROZ, [stage.name_key])
	return true


## Jogador vivo com menos vida a até radius (m); empate = menor nível; null = ninguém.
func weakest_target_near(radius: float) -> NetEntity:
	var me: NetEntity = get_entity()
	var best: NetEntity = null
	var best_key: Vector2 = Vector2(INF, INF)
	for s: PlayerSession in combat.world.get_sessions():
		var p: NetEntity = s.entity
		if p == null or p.instance_id != me.instance_id or not combat.is_valid_victim(self, p):
			continue
		if me.flat_distance_to(p.net_position) > radius:
			continue
		var key := Vector2(float(s.character.hp), float(s.character.level))
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best_key = key
			best = p
	return best


## Atroz em luta: a cada atroz_retarget_interval_sec troca para o mais fraco por perto. true = trocou.
func _atroz_retarget() -> bool:
	if not atroz:
		return false
	var now: int = Time.get_ticks_msec()
	if now < _next_retarget_msec:
		return false
	_next_retarget_msec = now + int(Balance.cfg.atroz_retarget_interval_sec * CombatRules.MSEC_PER_SEC)
	var weakest: NetEntity = weakest_target_near(stage.aggro_range_cells * cell_size())
	if weakest == null or weakest == target:
		return false
	Net.log_line("monster_atroz_retarget", {"id": get_entity().entity_id, "from": target.entity_id if target != null else 0,
			"to": weakest.entity_id})
	_engage(weakest)
	return true


## Chama o bando (monstros com boss_entity_id = este) por perto para cima do alvo. Devolve quantos vieram.
func call_escort(victim: NetEntity) -> int:
	var me: NetEntity = get_entity()
	var called: int = 0
	var r: float = Balance.cfg.atroz_call_escort_radius_cells * cell_size()
	for m: NetEntity in combat.monsters_in_radius(me.instance_id, me.net_position, r):
		var b: MonsterBrain = combat.get_brain(m)
		if b == null or b == self or b.boss_entity_id != me.entity_id:
			continue
		if b.state in [State.CHASE, State.ATTACK] or not combat.is_valid_victim(b, victim):
			continue
		b._engage(victim)
		called += 1
	Net.log_line("monster_atroz_call_escort", {"id": me.entity_id, "target": victim.entity_id, "called": called})
	return called
