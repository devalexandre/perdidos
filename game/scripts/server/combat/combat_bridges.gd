class_name CombatBridges
extends RefCounted
## Pontes para serviços de outros agentes (contrato arrival, apêndices Q e N). Cada função tenta
## o serviço "de verdade" e, se ele ainda não existir, usa um padrão documentado.
##
##  - XP total do jogador (Q): world.progression.total_xp(peer) ou Progression.total_xp(peer)
##    (estático). Padrão: soma da curva do GDD §6.3 até o nível atual (sem a XP parcial).
##  - ZoneDef da instância (N): world.zone_rules.zone_for_instance(id). Padrão: Content.zone(map).
##  - Teto de estágio dos monstros: ZoneDef.kind TRAINING -> 2 (GDD §9.3), senão 3.
##  - Combate permitido (N): world.zone_rules.combat_allowed(instance_id). Padrão:
##    ZoneDef.combat_allowed (mapa sem ZoneDef = permitido).
##  - Efeitos de status (Q): world.progression.statuses — absorb_damage, def_multiplier,
##    is_stunned, move_speed_multiplier; Terra do Sabiá v0.4: pre_hit, post_hit, lethal_guard,
##    heal_multiplier, is_hidden, is_rooted, range_bonus_cells. Sem Q: sem efeito.
##  - Renascimento (N): world.zone_rules.on_player_killed existe -> N renasce o jogador.

const PROP_PROGRESSION: StringName = &"progression"
const PROP_ZONE_RULES: StringName = &"zone_rules"
const PROP_STATUSES: StringName = &"statuses"
const PROGRESSION_CLASS: StringName = &"Progression"
const METHOD_TOTAL_XP: StringName = &"total_xp"
const METHOD_ZONE_FOR_INSTANCE: StringName = &"zone_for_instance"
const METHOD_COMBAT_ALLOWED: StringName = &"combat_allowed"
const METHOD_ON_PLAYER_KILLED: StringName = &"on_player_killed"
const METHOD_ABSORB: StringName = &"absorb_damage"
const METHOD_DEF_MULT: StringName = &"def_multiplier"
const METHOD_STUNNED: StringName = &"is_stunned"
const METHOD_SPEED_MULT: StringName = &"move_speed_multiplier"
const METHOD_PRE_HIT: StringName = &"pre_hit"
const METHOD_POST_HIT: StringName = &"post_hit"
const METHOD_LETHAL_GUARD: StringName = &"lethal_guard"
const METHOD_HEAL_MULT: StringName = &"heal_multiplier"
const METHOD_HIDDEN: StringName = &"is_hidden"
const METHOD_ROOTED: StringName = &"is_rooted"
const METHOD_RANGE_BONUS: StringName = &"range_bonus_cells"
const METHOD_IS_PROTECTED: StringName = &"is_protected"
const METHOD_PROTECTED_KILLED: StringName = &"on_protected_killed"
const NEUTRAL_MULTIPLIER: float = 1.0

static var _progression_script: Script = null
static var _progression_looked_up: bool = false


## XP total acumulada do jogador (cópia que o monstro absorve, GDD §10.6).
static func total_xp(world: Node, session: PlayerSession) -> int:
	if session == null:
		return 0
	var svc: Object = _service(world, PROP_PROGRESSION)
	if svc != null and svc.has_method(METHOD_TOTAL_XP):
		return int(svc.call(METHOD_TOTAL_XP, session.peer_id))
	var script: Script = _progression_class()
	if script != null and _script_has_static(script, METHOD_TOTAL_XP):
		return int(script.call(METHOD_TOTAL_XP, session.peer_id))
	return curve_total_for_level(session.character.level)


## Soma de floor(base × n^expoente) para n = 1 .. level-1 (GDD §6.3).
static func curve_total_for_level(level: int) -> int:
	var total: int = 0
	for n: int in range(1, maxi(level, 1)):
		total += floori(Balance.cfg.xp_curve_base * pow(float(n), Balance.cfg.xp_curve_exponent))
	return total


static func zone_for_instance(world: ServerWorld, instance_id: StringName) -> ZoneDef:
	var svc: Object = _service(world, PROP_ZONE_RULES)
	if svc != null and svc.has_method(METHOD_ZONE_FOR_INSTANCE):
		return svc.call(METHOD_ZONE_FOR_INSTANCE, instance_id) as ZoneDef
	return Content.zone(world.get_instance_map_id(instance_id))


static func monster_stage_cap(world: ServerWorld, instance_id: StringName) -> int:
	return stage_cap_for_zone(zone_for_instance(world, instance_id))


static func stage_cap_for_zone(zone: ZoneDef) -> int:
	if zone != null and zone.kind == ZoneDef.Kind.TRAINING:
		return CombatRules.TRAINING_MONSTER_STAGE_CAP
	if zone != null:
		return mini(zone.monster_stage_cap, CombatRules.STAGE_BOSS if zone.bosses_allowed else CombatRules.STAGE_MEDIUM)
	return CombatRules.STAGE_BOSS


static func combat_allowed(world: ServerWorld, instance_id: StringName) -> bool:
	var svc: Object = _service(world, PROP_ZONE_RULES)
	if svc != null and svc.has_method(METHOD_COMBAT_ALLOWED):
		return bool(svc.call(METHOD_COMBAT_ALLOWED, instance_id))
	var zone: ZoneDef = zone_for_instance(world, instance_id)
	return zone == null or zone.combat_allowed


## N cuida do renascimento?
static func respawn_is_external(world: ServerWorld) -> bool:
	if CombatEvents.bus().respawn_managed_externally:
		return true
	var svc: Object = _service(world, PROP_ZONE_RULES)
	return svc != null and svc.has_method(METHOD_ON_PLAYER_KILLED)


# ---------------------------------------------------------------- efeitos de status (Q)

static func absorb_damage(world: Node, target: NetEntity, amount: int) -> int:
	var st: Object = _statuses(world)
	if st != null and st.has_method(METHOD_ABSORB):
		return int(st.call(METHOD_ABSORB, target, amount))
	return amount


static func def_multiplier(world: Node, entity: NetEntity) -> float:
	var st: Object = _statuses(world)
	if st != null and st.has_method(METHOD_DEF_MULT):
		return float(st.call(METHOD_DEF_MULT, entity))
	return NEUTRAL_MULTIPLIER


static func is_stunned(world: Node, entity: NetEntity) -> bool:
	var st: Object = _statuses(world)
	return st != null and st.has_method(METHOD_STUNNED) and bool(st.call(METHOD_STUNNED, entity))


static func move_speed_multiplier(world: Node, entity: NetEntity) -> float:
	var st: Object = _statuses(world)
	if st != null and st.has_method(METHOD_SPEED_MULT):
		return maxf(float(st.call(METHOD_SPEED_MULT, entity)), 0.01)
	return NEUTRAL_MULTIPLIER


## Terra do Sabiá v0.4 (Q): reforços/enfraquecimentos, contragolpe, esquiva e crítico antes do golpe.
## atk/dfn são cópias que Q pode alterar. Sem Q: nada muda.
static func pre_hit(world: Node, attacker: NetEntity, target: NetEntity, kind: StringName,
		source_id: StringName, atk: Dictionary, dfn: Dictionary) -> Dictionary:
	var st: Object = _statuses(world)
	if st != null and st.has_method(METHOD_PRE_HIT):
		return st.call(METHOD_PRE_HIT, attacker, target, kind, source_id, atk, dfn) as Dictionary
	return {}


## Depois do golpe já aplicado (roubo de vida, lâmina encantada).
static func post_hit(world: Node, attacker: NetEntity, target: NetEntity, kind: StringName,
		source_id: StringName, amount: int) -> void:
	var st: Object = _statuses(world)
	if st != null and st.has_method(METHOD_POST_HIT):
		st.call(METHOD_POST_HIT, attacker, target, kind, source_id, amount)


## Dano que o alvo de fato perde (Raiz que Segura: não cai abaixo de 1).
static func lethal_guard(world: Node, target: NetEntity, amount: int, hp: int) -> int:
	var st: Object = _statuses(world)
	if st != null and st.has_method(METHOD_LETHAL_GUARD):
		return int(st.call(METHOD_LETHAL_GUARD, target, amount, hp))
	return amount


static func heal_multiplier(world: Node, target: NetEntity) -> float:
	var st: Object = _statuses(world)
	if st != null and st.has_method(METHOD_HEAL_MULT):
		return float(st.call(METHOD_HEAL_MULT, target))
	return NEUTRAL_MULTIPLIER


## Invisível para monstros (não é alvo de aggro nem de perseguição).
static func is_hidden(world: Node, entity: NetEntity) -> bool:
	var st: Object = _statuses(world)
	return st != null and st.has_method(METHOD_HIDDEN) and bool(st.call(METHOD_HIDDEN, entity))


## Preso: ataca, mas não anda.
static func is_rooted(world: Node, entity: NetEntity) -> bool:
	var st: Object = _statuses(world)
	return st != null and st.has_method(METHOD_ROOTED) and bool(st.call(METHOD_ROOTED, entity))


## Células de alcance a mais (reforço de alcance) para o ataque básico.
static func range_bonus_cells(world: Node, entity: NetEntity) -> float:
	var st: Object = _statuses(world)
	if st != null and st.has_method(METHOD_RANGE_BONUS):
		return float(st.call(METHOD_RANGE_BONUS, entity))
	return 0.0


## Protegido de provação (muda da Vó Aninha): jogador não ataca, monstro ataca, cura e escudo valem.
static func is_protected(world: Node, entity: NetEntity) -> bool:
	var prog: Object = _service(world, PROP_PROGRESSION)
	return prog != null and prog.has_method(METHOD_IS_PROTECTED) and bool(prog.call(METHOD_IS_PROTECTED, entity))


## Avisa Q que um protegido caiu.
static func protected_killed(world: Node, entity: NetEntity) -> void:
	var prog: Object = _service(world, PROP_PROGRESSION)
	if prog != null and prog.has_method(METHOD_PROTECTED_KILLED):
		prog.call(METHOD_PROTECTED_KILLED, entity)


## Aplica veneno (DOT) através de StatusEffects se existir.
static func apply_poison(world: Node, attacker: NetEntity, target: NetEntity, duration_sec: float = 4.0, tick_damage: int = 5) -> void:
	var st: Object = _statuses(world)
	if st != null and st.has_method(&"add"):
		st.call(&"add", target, 4, duration_sec, float(tick_damage), &"poison", attacker, &"nature")


## Adiciona escudo temporário ao alvo através de StatusEffects se existir.
static func add_shield(world: Node, target: NetEntity, amount: int, duration_sec: float = 5.0) -> void:
	var st: Object = _statuses(world)
	if st != null and st.has_method(&"add"):
		st.call(&"add", target, 0, duration_sec, float(amount), &"crendice_shield", null, &"")


static func _statuses(world: Node) -> Object:
	var prog: Object = _service(world, PROP_PROGRESSION)
	if prog == null or not (PROP_STATUSES in prog):
		return null
	var v: Variant = prog.get(PROP_STATUSES)
	return v as Object if v is Object else null


static func _service(world: Node, prop: StringName) -> Object:
	if world == null or not (prop in world):
		return null
	var v: Variant = world.get(prop)
	return v as Object if v is Object else null


static func _progression_class() -> Script:
	if _progression_looked_up:
		return _progression_script
	_progression_looked_up = true
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(info.get("class", "")) == PROGRESSION_CLASS:
			_progression_script = load(String(info.get("path", ""))) as Script
	return _progression_script


static func _script_has_static(script: Script, method: StringName) -> bool:
	for m: Dictionary in script.get_script_method_list():
		if StringName(m.get("name", "")) == method and (int(m.get("flags", 0)) & METHOD_FLAG_STATIC):
			return true
	return false
