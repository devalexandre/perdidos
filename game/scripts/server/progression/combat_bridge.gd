class_name CombatBridge
extends RefCounted
## Ponte entre a progressão (Q) e o combate (K). Tudo o que Q precisa do combate passa por aqui:
## dano (CombatService.apply_damage), "pode atacar?", "em combate?" e busca de entidades numa área.
## Enquanto world.combat (K) não existir, usa um substituto mínimo com as fórmulas do GDD §10.2 e
## bonecos de teste (só para os testes de Q; ver docs/contracts-arrival.md, Apêndice Q).

signal monster_killed(killer_peer: int, monster_id: StringName, stage: int, xp: int)

const KIND_MONSTER: StringName = &"monster"
const DAMAGE_PHYSICAL: StringName = &"physical"
const DAMAGE_MAGIC: StringName = &"magic"
## Nome da propriedade do serviço de K no ServerWorld e seus métodos (Interface K→Q).
const COMBAT_PROP: StringName = &"combat"
const M_APPLY_DAMAGE: StringName = &"apply_damage"
const M_CAN_ATTACK: StringName = &"can_attack"
const M_IN_COMBAT: StringName = &"is_in_combat"
const M_SPAWN_MONSTER: StringName = &"spawn_monster"
const M_MARK_COMBAT: StringName = &"mark_combat"
const M_HEAL: StringName = &"heal"
const M_GET_BRAIN: StringName = &"get_brain"
# --- substituto (sem K)
## GDD §10.2: variação aleatória ±10% e fórmula de redução por DEF.
const DAMAGE_VARIANCE: float = 0.1
const DEFENSE_BASE: float = 100.0
const MIN_DAMAGE: int = 1
const STUB_ID_BASE: int = 2000000
const STUB_STAGE: int = 1
const ENTITY_SCENE: String = "res://scenes/entities/net_entity.tscn"

var world: ServerWorld = null
## peer_id -> Time.get_ticks_msec() do último dano causado/recebido (quando K não informa).
var _last_combat_msec: Dictionary[int, int] = {}
# Bonecos do substituto: entity_id -> dados.
var _stub_hp: Dictionary[int, int] = {}
var _stub_xp: Dictionary[int, int] = {}
var _stub_def: Dictionary[int, int] = {}
var _next_stub: int = 0
var _rng := RandomNumberGenerator.new()


func _init(p_world: ServerWorld) -> void:
	world = p_world


## Serviço de combate de K (null enquanto não existir).
func k_service() -> Object:
	var c: Variant = world.get(COMBAT_PROP)
	return c as Object if c is Object else null


func has_k() -> bool:
	return k_service() != null


## Dano de skill: kind = DAMAGE_PHYSICAL/DAMAGE_MAGIC, multiplier = 1.5 para 150%.
func apply_damage(attacker: NetEntity, target: NetEntity, kind: StringName, multiplier: float,
		source_id: StringName) -> int:
	if attacker == null or target == null:
		return 0
	mark_combat(attacker)
	var k: Object = k_service()
	if k != null and k.has_method(M_APPLY_DAMAGE):
		return int(k.call(M_APPLY_DAMAGE, attacker, target, kind, multiplier, source_id))
	return _stub_damage(attacker, target, kind, multiplier, source_id)


## Cura (skills de suporte, roubo de vida, cura contínua). Com K: CombatService.heal (avisa a
## instância com NetCombat.healed). Sem K: cura direto no personagem. Devolve quanto curou.
func heal(target: NetEntity, amount: int, source: NetEntity = null) -> int:
	if target == null or amount <= 0 or not is_instance_valid(target):
		return 0
	var k: Object = k_service()
	if k != null and k.has_method(M_HEAL):
		return int(k.call(M_HEAL, target, amount, source))
	var s: PlayerSession = world.get_session(target.get_peer_id()) if target.is_player() else null
	if s == null:
		return 0
	var max_hp: int = s.character.compute_stats()[CharacterStats.K_MAX_HP]
	var before: int = s.character.hp
	s.character.hp = mini(max_hp, s.character.hp + amount)
	s.mark_dirty(PlayerSession.DIRTY_STATS)
	var healed: int = s.character.hp - before
	if healed > 0:
		NetCombat.push_healed(Net.get_instance_peer_ids(target.instance_id),
				source.entity_id if source != null else 0, target.entity_id, healed)
	return healed


## Devolve mana a um jogador (Fôlego Novo, Brilho do Cristal). Devolve quanto recuperou.
func restore_mp(target: NetEntity, amount: int) -> int:
	if target == null or amount <= 0 or not is_instance_valid(target) or not target.is_player():
		return 0
	var s: PlayerSession = world.get_session(target.get_peer_id())
	if s == null or s.character.hp <= 0:
		return 0
	var max_mp: int = s.character.compute_stats()[CharacterStats.K_MAX_MP]
	var before: int = s.character.mp
	s.character.mp = mini(max_mp, s.character.mp + amount)
	s.mark_dirty(PlayerSession.DIRTY_STATS)
	return s.character.mp - before


## Aliados vivos da mesma instância a até radius (m) de center (skills de suporte: cura, escudo, reforço).
## Desde 30/09/2026 (grupo de verdade, mapas compartilhados): quem lançou e os membros do grupo dele; outros
## jogadores do mapa não contam. Mais os protegidos de provação de quem lançou (ou do grupo dele).
func allies_near(me: NetEntity, center: Vector3, radius: float) -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	var prog: Progression = world.get(&"progression") as Progression
	for e: NetEntity in entities_in(me.instance_id):
		if e.flat_distance_to(center) > radius:
			continue
		if e.is_player():
			var s: PlayerSession = world.get_session(e.get_peer_id())
			if s != null and s.character.hp > 0 and is_ally(me, e):
				out.append(e)
		elif prog != null and prog.is_protected_ally(me, e) and e.hp_ratio > 0.0:
			# Mudas da provação da Vó Aninha contam como aliadas de quem faz a quest.
			out.append(e)
	return out


## Aliado para suporte: a própria entidade ou um jogador do mesmo grupo (PartyService.is_ally).
func is_ally(me: NetEntity, other: NetEntity) -> bool:
	if me == null or other == null:
		return false
	if me == other:
		return true
	var party: Variant = world.get(&"party")
	if party is PartyService:
		return (party as PartyService).is_ally(me, other)
	return false


func can_attack(attacker: NetEntity, target: NetEntity) -> bool:
	if attacker == null or target == null or target == attacker \
			or target.instance_id != attacker.instance_id:
		return false
	var k: Object = k_service()
	if k != null and k.has_method(M_CAN_ATTACK):
		return bool(k.call(M_CAN_ATTACK, attacker, target))
	return _stub_hp.get(target.entity_id, 0) > 0


func is_in_combat(peer_id: int) -> bool:
	var k: Object = k_service()
	if k != null and k.has_method(M_IN_COMBAT):
		return bool(k.call(M_IN_COMBAT, peer_id))
	var last: int = _last_combat_msec.get(peer_id, -1)
	return last >= 0 and Time.get_ticks_msec() - last < int(Balance.cfg.out_of_combat_sec * 1000.0)


func mark_combat(entity: NetEntity) -> void:
	if entity == null or not entity.is_player():
		return
	_last_combat_msec[entity.get_peer_id()] = Time.get_ticks_msec()
	var k: Object = k_service()
	if k != null and k.has_method(M_MARK_COMBAT):
		k.call(M_MARK_COMBAT, entity.get_peer_id())


## Entidades vivas da instância (jogadores, NPCs, monstros).
func entities_in(instance_id: StringName) -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	var main: Node = world.main_node
	var root: Node = main.get(&"instances_root") as Node if main != null else null
	var inst: Node = root.get_node_or_null(Net.instance_node_name(instance_id)) if root != null else null
	var ents: Node = inst.get_node_or_null(^"Entities") if inst != null else null
	if ents == null:
		return out
	for c: Node in ents.get_children():
		if c is NetEntity and not c.is_queued_for_deletion():
			out.append(c as NetEntity)
	return out


## Alvos hostis ao atacante, para skills de área.
func hostile_targets(attacker: NetEntity) -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	for e: NetEntity in entities_in(attacker.instance_id):
		if can_attack(attacker, e):
			out.append(e)
	return out


## Boneco/monstro de provação: pede a K (spawn_monster) ou cria um boneco do substituto.
func spawn_trial_target(instance_id: StringName, monster_id: StringName, pos: Vector3,
		owner_peer: int, stage_number: int = 1) -> NetEntity:
	var k: Object = k_service()
	if k != null and k.has_method(M_SPAWN_MONSTER):
		return k.call(M_SPAWN_MONSTER, instance_id, monster_id, pos, owner_peer, stage_number) as NetEntity
	return spawn_stub_dummy(instance_id, monster_id, pos)


# ---------------------------------------------------------------- substituto (sem K, só testes)

## Boneco parado com vida própria (não anda, não ataca). hp/xp/def vêm do MonsterDef, se existir.
func spawn_stub_dummy(instance_id: StringName, monster_id: StringName, pos: Vector3,
		hp: int = 200, xp: int = 10, def_value: int = 0) -> NetEntity:
	var mdef: MonsterDef = Content.monster(monster_id)
	if mdef != null and not mdef.stages.is_empty():
		var st: MonsterStage = mdef.stages[0]
		hp = int(st.get(&"max_hp")) if st.get(&"max_hp") != null else hp
		xp = int(st.get(&"xp")) if st.get(&"xp") != null else xp
	_next_stub += 1
	var e: NetEntity = (load(ENTITY_SCENE) as PackedScene).instantiate() as NetEntity
	e.server_setup(STUB_ID_BASE + _next_stub, KIND_MONSTER, String(monster_id), monster_id,
			instance_id, pos)
	_stub_hp[e.entity_id] = hp
	_stub_xp[e.entity_id] = xp
	_stub_def[e.entity_id] = def_value
	world.call(&"_add_entity", e)
	Net.log_line("progression_stub_dummy", {"id": e.entity_id, "monster": String(monster_id),
			"hp": hp, "pos": str(pos)})
	return e


func stub_hp(entity_id: int) -> int:
	return _stub_hp.get(entity_id, 0)


func _stub_damage(attacker: NetEntity, target: NetEntity, kind: StringName, multiplier: float,
		source_id: StringName) -> int:
	if not _stub_hp.has(target.entity_id) or _stub_hp[target.entity_id] <= 0:
		return 0
	var s: PlayerSession = world.get_session(attacker.get_peer_id())
	if s == null:
		return 0
	var st: Dictionary = s.character.compute_stats()
	var power: int = st[CharacterStats.K_MATK] if kind == DAMAGE_MAGIC else st[CharacterStats.K_ATK]
	var reduction: float = DEFENSE_BASE / (DEFENSE_BASE + _stub_def.get(target.entity_id, 0))
	var roll: float = _rng.randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)
	var dmg: int = maxi(MIN_DAMAGE, roundi(power * multiplier * reduction * roll))
	_stub_hp[target.entity_id] = maxi(0, _stub_hp[target.entity_id] - dmg)
	Net.log_line("progression_stub_damage", {"attacker": attacker.entity_id,
			"target": target.entity_id, "kind": String(kind), "mult": snappedf(multiplier, 0.01),
			"damage": dmg, "hp": _stub_hp[target.entity_id], "source": String(source_id)})
	if _stub_hp[target.entity_id] == 0:
		var xp: int = _stub_xp.get(target.entity_id, 0)
		_stub_hp.erase(target.entity_id)
		target.queue_free()
		monster_killed.emit(attacker.get_peer_id(), target.def_id, STUB_STAGE, xp)
	return dmg
