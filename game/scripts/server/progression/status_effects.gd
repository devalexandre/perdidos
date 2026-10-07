class_name StatusEffects
extends RefCounted
## Efeitos de status das skills (Q é o dono; ver Apêndice Q do contrato): escudo, reforço de DEF,
## lentidão, atordoamento, dano contínuo (em entidade) e áreas no chão que causam dano por segundo.
## Terra do Sabiá v0.4 (TITULOS-E-SKILLS.md §3.5): prender, reforço e enfraquecimento genéricos
## (BUFF/DEBUFF com `mods`), provocar, cura e mana contínuas, contragolpe e invisibilidade.
## K consulta absorb_damage / def_multiplier / is_stunned / move_speed_multiplier / pre_hit /
## post_hit / lethal_guard / heal_multiplier / is_hidden / is_rooted no pipeline dele
## (CombatBridges). Nos jogadores, Q mesmo aplica o atordoamento, a prisão e a lentidão no GridMover.
## Todo efeito que começa ou acaba vai para a instância: NetProgress.status_changed.

enum Kind { SHIELD, DEF_BUFF, SLOW, STUN, DOT, ROOT, BUFF, DEBUFF, TAUNT, HOT, MP_REGEN, COUNTER, STEALTH }

## Intervalo do dano contínuo (GDD §8.3: "por segundo").
const DOT_TICK_SEC: float = 1.0
const MSEC_PER_SEC: float = 1000.0
const NEUTRAL_MULTIPLIER: float = 1.0
## Nunca deixa a velocidade chegar a zero por lentidão acumulada.
const MIN_SPEED_MULTIPLIER: float = 0.1
## Piso dos multiplicadores de atributo (DEF, ATQ...) somados de vários efeitos.
const MIN_STAT_MULTIPLIER: float = 0.1
## Dano recebido nunca cai abaixo disto (−90%), mesmo somando reduções.
const MIN_DAMAGE_TAKEN_MULTIPLIER: float = 0.1
## Chance de crítico nunca passa disto.
const MAX_CRIT_CHANCE: float = 1.0
## Área no chão com enfraquecimento: o efeito dura isto a cada tique (renova enquanto estiver dentro).
const ZONE_DEBUFF_SEC: float = 1.5
## Chaves de `mods` dos efeitos BUFF/DEBUFF (mesmos nomes em SkillDef.extra).
const M_ATK_PCT: StringName = &"atk_pct"
const M_MATK_PCT: StringName = &"matk_pct"
const M_DEF_PCT: StringName = &"def_pct"
const M_CRIT: StringName = &"crit"
const M_EVADE: StringName = &"evade"
const M_RANGE: StringName = &"range_cells"
const M_DMG_TAKEN: StringName = &"dmg_taken_pct"
const M_LIFESTEAL: StringName = &"lifesteal"
const M_HEAL_RECEIVED: StringName = &"heal_received_pct"
const M_CC_IMMUNE: StringName = &"cc_immune"
const M_DEATH_WARD: StringName = &"death_ward"
const M_IMBUE_MATK: StringName = &"imbue_matk"
const M_MOVE_SPEED: StringName = &"move_speed_pct"
const MOD_KEYS: Array[StringName] = [M_ATK_PCT, M_MATK_PCT, M_DEF_PCT, M_CRIT, M_EVADE, M_RANGE,
		M_DMG_TAKEN, M_LIFESTEAL, M_HEAL_RECEIVED, M_CC_IMMUNE, M_DEATH_WARD, M_IMBUE_MATK, M_MOVE_SPEED]
## Efeitos negativos (Emplastro remove; Aguentar Firme bloqueia os de controle).
const NEGATIVE_KINDS: Array[int] = [Kind.SLOW, Kind.STUN, Kind.DOT, Kind.ROOT, Kind.DEBUFF]
const CONTROL_KINDS: Array[int] = [Kind.STUN, Kind.ROOT]
const SOURCE_BASIC_ATTACK: StringName = &"basic_attack"
const DAMAGE_PHYSICAL: StringName = &"physical"
const DAMAGE_MAGIC: StringName = &"magic"

class Effect:
	var kind: int = Kind.SHIELD
	var until_msec: int = 0
	## SHIELD: absorção restante. DOT: multiplicador por tique. DEF_BUFF/SLOW: fração (0,4 = 40%).
	## HOT/MP_REGEN: quanto recupera por tique. COUNTER: multiplicador do revide.
	var value: float = 0.0
	var source_skill: StringName = &""
	var attacker_id: int = 0
	var damage_kind: StringName = &""
	var next_tick_msec: int = 0
	## BUFF/DEBUFF: {M_*: valor}. BUFF com crit_charges: próximos N golpes críticos.
	var mods: Dictionary = {}
	var charges: int = 0

class GroundZone:
	var instance_id: StringName = &""
	var center: Vector3 = Vector3.ZERO
	var radius: float = 0.0
	var until_msec: int = 0
	var next_tick_msec: int = 0
	var attacker_id: int = 0
	var multiplier: float = 0.0
	var damage_kind: StringName = &""
	var source_skill: StringName = &""
	## Forma em linha (Serpente de Fogo): SkillDef + origem/direção; null = círculo.
	var shape_def: SkillDef = null
	var origin: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3.FORWARD
	## Enfraquecimento aplicado a quem está dentro a cada tique (Fumaça Amarga).
	var debuff_mods: Dictionary = {}

var world: ServerWorld = null
var bridge: CombatBridge = null
## entity_id -> efeitos ativos.
var _effects: Dictionary[int, Array] = {}
var _zones: Array[GroundZone] = []
## entity_id do jogador -> ms_per_cell original (antes da lentidão).
var _base_ms_per_cell: Dictionary[int, int] = {}
var _rng := RandomNumberGenerator.new()


func _init(p_world: ServerWorld, p_bridge: CombatBridge) -> void:
	world = p_world
	bridge = p_bridge
	_rng.randomize()


static func now_msec() -> int:
	return Time.get_ticks_msec()


static func status_id(kind: int) -> StringName:
	return StringName(String(Kind.keys()[kind]).to_lower())


## Aplica (ou renova) um efeito. false = recusado (duração 0 ou imune a controle).
func add(target: NetEntity, kind: Kind, duration_sec: float, value: float,
		source_skill: StringName, attacker: NetEntity = null, damage_kind: StringName = &"",
		mods: Dictionary = {}, charges: int = 0) -> bool:
	if target == null or duration_sec <= 0.0 or not is_instance_valid(target):
		return false
	if kind in CONTROL_KINDS and is_cc_immune(target):
		Net.log_line("status_immune", {"target": target.entity_id, "kind": Kind.keys()[kind],
				"skill": String(source_skill)})
		return false
	var e := Effect.new()
	e.kind = kind
	e.until_msec = now_msec() + roundi(duration_sec * MSEC_PER_SEC)
	e.value = value
	e.source_skill = source_skill
	e.attacker_id = attacker.entity_id if attacker != null else 0
	e.damage_kind = damage_kind
	e.next_tick_msec = now_msec() + roundi(DOT_TICK_SEC * MSEC_PER_SEC)
	e.mods = mods.duplicate()
	e.charges = charges
	var list: Array = _effects.get(target.entity_id, [])
	# O mesmo efeito da mesma skill não acumula: renova.
	for old: Effect in list.duplicate():
		if old.kind == kind and old.source_skill == source_skill:
			list.erase(old)
	list.append(e)
	_effects[target.entity_id] = list
	Net.log_line("status_applied", {"target": target.entity_id, "kind": Kind.keys()[kind],
			"sec": snappedf(duration_sec, 0.01), "value": snappedf(value, 0.01),
			"skill": String(source_skill), "mods": str(mods) if not mods.is_empty() else ""})
	_notify(target, e, true, duration_sec)
	if target.is_player():
		_apply_player_movement(target)
	elif kind in CONTROL_KINDS and target.get_mover() != null and target.get_mover().is_moving():
		target.get_mover().halt()
	if kind == Kind.TAUNT:
		_enforce_taunt(target, e)
	return true


func add_ground_zone(attacker: NetEntity, center: Vector3, radius: float, duration_sec: float,
		multiplier: float, damage_kind: StringName, source_skill: StringName,
		shape_def: SkillDef = null, origin: Vector3 = Vector3.ZERO, dir: Vector3 = Vector3.FORWARD,
		debuff_mods: Dictionary = {}) -> void:
	var z := GroundZone.new()
	z.instance_id = attacker.instance_id
	z.center = center
	z.radius = radius
	z.until_msec = now_msec() + roundi(duration_sec * MSEC_PER_SEC)
	z.next_tick_msec = now_msec() + roundi(DOT_TICK_SEC * MSEC_PER_SEC)
	z.attacker_id = attacker.entity_id
	z.multiplier = multiplier
	z.damage_kind = damage_kind
	z.source_skill = source_skill
	z.shape_def = shape_def
	z.origin = origin
	z.dir = dir
	z.debuff_mods = debuff_mods.duplicate()
	_zones.append(z)


func has(entity: NetEntity, kind: Kind) -> bool:
	if entity == null:
		return false
	for e: Effect in _effects.get(entity.entity_id, []):
		if e.kind == kind and e.until_msec > now_msec():
			return true
	return false


## Remove os efeitos negativos (Emplastro). only_kind >= 0 = só esse tipo (Folha Larga: veneno).
func cleanse(target: NetEntity, only_kind: int = -1) -> int:
	var removed: int = 0
	for e: Effect in (_effects.get(target.entity_id, []) as Array).duplicate():
		if e.kind in NEGATIVE_KINDS and (only_kind < 0 or e.kind == only_kind):
			_remove(target, e)
			removed += 1
	if removed > 0 and target.is_player():
		_apply_player_movement(target)
	return removed


func _remove(target: NetEntity, e: Effect) -> void:
	var list: Array = _effects.get(target.entity_id, [])
	if not list.has(e):
		return
	list.erase(e)
	if list.is_empty():
		_effects.erase(target.entity_id)
	_notify(target, e, false, 0.0)


func _remove_kind(target: NetEntity, kind: int) -> void:
	for e: Effect in (_effects.get(target.entity_id, []) as Array).duplicate():
		if e.kind == kind:
			_remove(target, e)


func _notify(target: NetEntity, e: Effect, active: bool, duration_sec: float) -> void:
	if not is_instance_valid(target):
		return
	NetProgress.push_status_changed(Net.get_instance_peer_ids(target.instance_id), target.entity_id,
			status_id(e.kind), e.source_skill, active, duration_sec)


# ---------------------------------------------------------------- consultas (K usa)

## Dano que sobra depois do escudo (consome o escudo).
func absorb_damage(target: NetEntity, amount: int) -> int:
	var left: int = amount
	for e: Effect in _effects.get(target.entity_id, []):
		if e.kind != Kind.SHIELD or left <= 0:
			continue
		var used: int = mini(left, int(e.value))
		e.value -= used
		left -= used
		if e.value <= 0.0:
			e.until_msec = 0
	return left


## Escudo restante (soma).
func shield_amount(target: NetEntity) -> int:
	var total: float = 0.0
	for e: Effect in _effects.get(target.entity_id, []):
		if e.kind == Kind.SHIELD:
			total += e.value
	return int(total)


## Soma de um modificador em todos os BUFF/DEBUFF ativos da entidade.
func mod(entity: NetEntity, key: StringName) -> float:
	var total: float = 0.0
	if entity == null:
		return total
	var now: int = now_msec()
	for e: Effect in _effects.get(entity.entity_id, []):
		if (e.kind == Kind.BUFF or e.kind == Kind.DEBUFF) and e.until_msec > now:
			total += float(e.mods.get(key, 0.0))
	return total


func def_multiplier(entity: NetEntity) -> float:
	var m: float = NEUTRAL_MULTIPLIER
	for e: Effect in _effects.get(entity.entity_id, []):
		if e.kind == Kind.DEF_BUFF:
			m += e.value
	m += mod(entity, M_DEF_PCT)
	return maxf(m, MIN_STAT_MULTIPLIER)


func is_stunned(entity: NetEntity) -> bool:
	return has(entity, Kind.STUN)


func is_rooted(entity: NetEntity) -> bool:
	return has(entity, Kind.ROOT)


## Invisível para monstros (Lama no Corpo).
func is_hidden(entity: NetEntity) -> bool:
	return has(entity, Kind.STEALTH)


func is_cc_immune(entity: NetEntity) -> bool:
	return mod(entity, M_CC_IMMUNE) > 0.0


## Células a mais de alcance (Olho Parado): ataque básico e skills.
func range_bonus_cells(entity: NetEntity) -> float:
	return maxf(0.0, mod(entity, M_RANGE))


## Cura recebida × isto (Fumaça Amarga: −50%).
func heal_multiplier(entity: NetEntity) -> float:
	return maxf(0.0, NEUTRAL_MULTIPLIER + mod(entity, M_HEAL_RECEIVED))


## 1,0 = normal; 0,65 = 35% mais lento (o ms_per_cell fica ms / mult).
func move_speed_multiplier(entity: NetEntity) -> float:
	var m: float = maxf(MIN_SPEED_MULTIPLIER, NEUTRAL_MULTIPLIER + mod(entity, M_MOVE_SPEED))
	for e: Effect in _effects.get(entity.entity_id, []):
		if e.kind == Kind.SLOW:
			m *= NEUTRAL_MULTIPLIER - e.value
	return maxf(m, MIN_SPEED_MULTIPLIER)


## Não cai abaixo de 1 de vida (Raiz que Segura): dano que mataria vira hp - 1.
func lethal_guard(target: NetEntity, amount: int, hp: int) -> int:
	if amount >= hp and hp > 0 and mod(target, M_DEATH_WARD) > 0.0:
		Net.log_line("status_death_ward", {"target": target.entity_id, "amount": amount, "hp": hp})
		return hp - 1
	return amount


## Antes do golpe (CombatService.deal_damage). Mexe nos atributos do golpe (atk/dfn são cópias) e
## devolve {"crit_override": float (< 0 = padrão), "force_miss": bool, "countered": bool,
## "dmg_mult": float}.
func pre_hit(attacker: NetEntity, target: NetEntity, kind: StringName, source_id: StringName,
		atk: Dictionary, dfn: Dictionary) -> Dictionary:
	var out: Dictionary = {"crit_override": -1.0, "force_miss": false, "countered": false,
			"dmg_mult": NEUTRAL_MULTIPLIER}
	# Quem ataca sai da invisibilidade (Tocaia já leu o bônus antes).
	if attacker.is_player() and is_hidden(attacker):
		_remove_kind(attacker, Kind.STEALTH)
		Net.log_line("status_stealth_broken", {"entity": attacker.entity_id, "source": String(source_id)})
	# Contragolpe (Resposta da Aroeira): anula o próximo golpe corpo a corpo de monstro e revida.
	if attacker.is_monster() and source_id == SOURCE_BASIC_ATTACK:
		for e: Effect in _effects.get(target.entity_id, []):
			if e.kind == Kind.COUNTER and e.until_msec > now_msec():
				_remove(target, e)
				out["countered"] = true
				Net.log_line("status_counter", {"entity": target.entity_id, "attacker": attacker.entity_id,
						"mult": e.value, "skill": String(e.source_skill)})
				bridge.apply_damage(target, attacker, DAMAGE_PHYSICAL, e.value, e.source_skill)
				return out
	atk[&"atk"] = roundi(float(atk.get(&"atk", 0)) * maxf(MIN_STAT_MULTIPLIER, 1.0 + mod(attacker, M_ATK_PCT)))
	atk[&"matk"] = roundi(float(atk.get(&"matk", 0)) * maxf(MIN_STAT_MULTIPLIER, 1.0 + mod(attacker, M_MATK_PCT)))
	var sd: SkillDef = Content.skill(source_id)
	var def_ignore: float = float(sd.extra.get(&"def_ignore", 0.0)) if sd != null else 0.0
	if def_ignore > 0.0:
		dfn[&"def"] = roundi(float(dfn.get(&"def", 0)) * (1.0 - clampf(def_ignore, 0.0, 1.0)))
		dfn[&"mdef"] = roundi(float(dfn.get(&"mdef", 0)) * (1.0 - clampf(def_ignore, 0.0, 1.0)))
	if kind == DAMAGE_PHYSICAL and attacker.is_player():
		var crit_add: float = mod(attacker, M_CRIT) + (float(sd.extra.get(&"crit_bonus", 0.0)) if sd != null else 0.0)
		if _consume_crit_charge(attacker):
			out["crit_override"] = MAX_CRIT_CHANCE
		elif crit_add > 0.0:
			out["crit_override"] = minf(MAX_CRIT_CHANCE,
					DamageFormula.crit_chance(int(atk.get(&"luk", 0))) + crit_add)
	var evade: float = mod(target, M_EVADE)
	if kind == DAMAGE_PHYSICAL and evade > 0.0 and _rng.randf() < evade:
		out["force_miss"] = true
	out["dmg_mult"] = maxf(MIN_DAMAGE_TAKEN_MULTIPLIER, NEUTRAL_MULTIPLIER + mod(target, M_DMG_TAKEN))
	return out


func _consume_crit_charge(attacker: NetEntity) -> bool:
	for e: Effect in _effects.get(attacker.entity_id, []):
		if e.kind == Kind.BUFF and e.charges > 0 and e.until_msec > now_msec():
			e.charges -= 1
			if e.charges <= 0 and e.mods.is_empty():
				e.until_msec = 0
			return true
	return false


## Depois do golpe (já aplicado e, se matou, já processado): roubo de vida e lâmina encantada.
func post_hit(attacker: NetEntity, target: NetEntity, _kind: StringName, source_id: StringName,
		amount: int) -> void:
	if amount <= 0 or not is_instance_valid(attacker):
		return
	var steal: float = mod(attacker, M_LIFESTEAL)
	if steal > 0.0:
		bridge.heal(attacker, roundi(amount * steal), attacker)
	var imbue: float = mod(attacker, M_IMBUE_MATK)
	if imbue > 0.0 and source_id == SOURCE_BASIC_ATTACK and is_instance_valid(target) \
			and bridge.can_attack(attacker, target):
		bridge.apply_damage(attacker, target, DAMAGE_MAGIC, imbue, _imbue_skill(attacker))


func _imbue_skill(entity: NetEntity) -> StringName:
	for e: Effect in _effects.get(entity.entity_id, []):
		if e.kind == Kind.BUFF and e.mods.has(M_IMBUE_MATK):
			return e.source_skill
	return SOURCE_BASIC_ATTACK


## Resumo para o dono (HUD): [{kind, skill, ms}].
func summary(entity: NetEntity) -> Array:
	var out: Array = []
	var now: int = now_msec()
	for e: Effect in _effects.get(entity.entity_id, []):
		out.append({"kind": String(Kind.keys()[e.kind]).to_lower(), "skill": String(e.source_skill),
				"ms": maxi(0, e.until_msec - now), "value": int(e.value)})
	return out


# ---------------------------------------------------------------- tick

func tick() -> void:
	var now: int = now_msec()
	for entity_id: int in _effects.keys():
		var target: NetEntity = world.get_entity(entity_id)
		if target == null or not is_instance_valid(target):
			_effects.erase(entity_id)
			_base_ms_per_cell.erase(entity_id)
			continue
		var list: Array = _effects[entity_id]
		var changed_move: bool = false
		for e: Effect in list.duplicate():
			if now >= e.next_tick_msec and now < e.until_msec:
				_tick_effect(target, e)
			if now >= e.until_msec:
				list.erase(e)
				_notify(target, e, false, 0.0)
				changed_move = changed_move or e.kind in [Kind.SLOW, Kind.STUN, Kind.ROOT]
			elif e.kind == Kind.TAUNT:
				_enforce_taunt(target, e)
		if list.is_empty():
			_effects.erase(entity_id)
		if target.is_player() and is_instance_valid(target):
			if changed_move:
				_apply_player_movement(target)
			if (is_stunned(target) or is_rooted(target)) and target.get_mover() != null \
					and target.get_mover().is_moving():
				target.get_mover().halt()
	for z: GroundZone in _zones.duplicate():
		if now >= z.next_tick_msec and now < z.until_msec:
			z.next_tick_msec += roundi(DOT_TICK_SEC * MSEC_PER_SEC)
			_tick_zone(z)
		if now >= z.until_msec:
			_zones.erase(z)


func _tick_effect(target: NetEntity, e: Effect) -> void:
	match e.kind:
		Kind.DOT:
			e.next_tick_msec += roundi(DOT_TICK_SEC * MSEC_PER_SEC)
			var attacker: NetEntity = world.get_entity(e.attacker_id)
			if attacker != null and bridge.can_attack(attacker, target):
				bridge.apply_damage(attacker, target, e.damage_kind, e.value, e.source_skill)
		Kind.HOT:
			e.next_tick_msec += roundi(DOT_TICK_SEC * MSEC_PER_SEC)
			bridge.heal(target, roundi(e.value), world.get_entity(e.attacker_id))
		Kind.MP_REGEN:
			e.next_tick_msec += roundi(DOT_TICK_SEC * MSEC_PER_SEC)
			bridge.restore_mp(target, roundi(e.value))


## Provocado: o monstro troca o alvo para quem provocou (e fica nele até o efeito acabar).
func _enforce_taunt(target: NetEntity, e: Effect) -> void:
	if not target.is_monster():
		return
	var taunter: NetEntity = world.get_entity(e.attacker_id)
	var k: Object = bridge.k_service()
	if taunter == null or k == null or not k.has_method(&"get_brain"):
		return
	var brain: Object = k.call(&"get_brain", target)
	if brain == null or bool(brain.call(&"is_dead")) or brain.get(&"target") == taunter:
		return
	if k.has_method(&"is_valid_victim") and not bool(k.call(&"is_valid_victim", brain, taunter)):
		return
	if brain.has_method(&"_engage"):
		brain.call(&"_engage", taunter)
		Net.log_line("status_taunt_retarget", {"monster": target.entity_id, "taunter": taunter.entity_id})


func _tick_zone(z: GroundZone) -> void:
	var attacker: NetEntity = world.get_entity(z.attacker_id)
	if attacker == null:
		return
	var cell: float = Balance.cfg.cell_size
	for e: NetEntity in bridge.hostile_targets(attacker):
		var inside: bool = e.flat_distance_to(z.center) <= z.radius if z.shape_def == null \
				else SkillCaster.in_shape(z.shape_def, z.origin, z.center, z.dir, e.net_position, cell)
		if not inside:
			continue
		if not z.debuff_mods.is_empty():
			add(e, Kind.DEBUFF, ZONE_DEBUFF_SEC, 0.0, z.source_skill, attacker, &"", z.debuff_mods)
		if z.multiplier > 0.0:
			bridge.apply_damage(attacker, e, z.damage_kind, z.multiplier, z.source_skill)


## Jogador: lentidão muda o ms_per_cell do GridMover; volta ao original quando acaba.
func _apply_player_movement(player: NetEntity) -> void:
	if world != null and world.mounts != null:
		var session: PlayerSession = world.get_session(player.get_peer_id())
		if session != null:
			world.mounts.refresh_speed(session)
			if is_stunned(player) or is_rooted(player):
				player.get_mover().halt()
			return
	var mover: GridMover = player.get_mover()
	if mover == null:
		return
	if not _base_ms_per_cell.has(player.entity_id):
		_base_ms_per_cell[player.entity_id] = mover.ms_per_cell
	var base: int = _base_ms_per_cell[player.entity_id]
	var mult: float = move_speed_multiplier(player)
	mover.ms_per_cell = roundi(base / mult)
	if is_equal_approx(mult, NEUTRAL_MULTIPLIER):
		_base_ms_per_cell.erase(player.entity_id)
	if is_stunned(player) or is_rooted(player):
		mover.halt()
