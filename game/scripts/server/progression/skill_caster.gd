class_name SkillCaster
extends RefCounted
## Lançamento de skills no servidor (GDD §8.1, §10.1): valida (conhecida, na barra, mana, recarga,
## alcance, arma de corpo a corpo, alvo), conjura (tempo de conjuração + aviso no chão) e aplica o
## efeito pelos tipos de alvo do SkillDef: alvo único, área no chão, área ao redor, cone, linha,
## si mesmo e aliado/si mesmo. Dano pelo pipeline de K (CombatBridge); status pelo StatusEffects.
## Tempo de uso (GDD §8.1 "Tempo de uso na barra", CastTiming): conjuração pelo nível da skill,
## DES/INT e cast_reduction dos itens; recarga (ESP + cooldown_reduction) começa quando a conjuração
## termina. Andar ou ser atordoado durante a conjuração interrompe (NetProgress.cast_cancelled).

const MSG_COOLDOWN: String = "PROG_MSG_SKILL_COOLDOWN"
const MSG_NO_MANA: String = "PROG_MSG_NO_MANA"
const MSG_NEEDS_MELEE: String = "PROG_MSG_NEEDS_MELEE"
const MSG_NEEDS_BOW: String = "PROG_MSG_NEEDS_BOW"
const MSG_NO_AMMO: String = "PROG_MSG_NO_AMMO"
const MSG_BLINK_BLOCKED: String = "PROG_MSG_BLINK_BLOCKED"
const MSG_STUNNED: String = "PROG_MSG_STUNNED"
const MSG_NO_TARGET: String = "PROG_MSG_NO_TARGET"
const MSG_NO_COMBAT_HERE: String = "PROG_MSG_NO_COMBAT_HERE"
const MSG_CAST_INTERRUPTED: String = "PROG_MSG_CAST_INTERRUPTED"
## Motivos de interrupção (log).
const INTERRUPT_MOVE: StringName = &"move"
const INTERRUPT_STUN: StringName = &"stun"
const INTERRUPT_DEAD: StringName = &"dead"
## Folga de alcance (células) pela latência entre o clique e o servidor.
const RANGE_SLACK_CELLS: float = 1.0
const MSEC_PER_SEC: float = 1000.0
const NO_TARGET: int = 0
# Parâmetros em SkillDef.extra (números nos dados, GDD §8.1).
const X_STUN_SEC: StringName = &"stun_sec"
const X_STUN_PER_LEVEL: StringName = &"stun_per_level"
const X_SLOW_PCT: StringName = &"slow_pct"
const X_DEF_PCT: StringName = &"def_pct"
const X_DEF_PCT_PER_LEVEL: StringName = &"def_pct_per_level"
const X_SELF_SLOW_PCT: StringName = &"self_slow_pct"
const X_DURATION_PER_LEVEL: StringName = &"duration_per_level"
const X_SHIELD_BASE: StringName = &"shield_base"
const X_SHIELD_MATK_RATIO: StringName = &"shield_matk_ratio"
const X_SHIELD_PER_LEVEL: StringName = &"shield_per_level"
const X_KNOCKBACK_CELLS: StringName = &"knockback_cells"
const X_DAMAGE_KIND: StringName = &"damage_kind"
# --- Terra de Pindorama v0.4 (TITULOS-E-SKILLS.md §3.5). Toda chave aceita "<chave>_per_level".
## Riders de golpe (qualquer efeito com dano, e ROOT/STUN/KNOCKBACK/PULL mesmo sem dano).
const X_ROOT_SEC: StringName = &"root_sec"
const X_PULL_CELLS: StringName = &"pull_cells"
const X_DASH: StringName = &"dash"
const X_DOT_MULT: StringName = &"dot_mult"
const X_DOT_SEC: StringName = &"dot_sec"
const X_DOT_KIND: StringName = &"dot_kind"
const X_HITS: StringName = &"hits"
const X_STEALTH_BONUS: StringName = &"stealth_bonus"
const X_MISSING_HP_BONUS: StringName = &"missing_hp_bonus"
## Cura: base + MATK × razão, × (1 + por nível). cleanse = remove efeitos negativos; cleanse_dot = só veneno.
const X_HEAL_BASE: StringName = &"heal_base"
const X_HEAL_MATK_RATIO: StringName = &"heal_matk_ratio"
const X_HEAL_PER_LEVEL: StringName = &"heal_per_level"
const X_CLEANSE: StringName = &"cleanse"
const X_CLEANSE_DOT: StringName = &"cleanse_dot"
## Cura contínua por segundo: base + MATK × razão + vida máxima × pct.
const X_HOT_BASE: StringName = &"hot_base"
const X_HOT_MATK_RATIO: StringName = &"hot_matk_ratio"
const X_HOT_MAX_HP_PCT: StringName = &"hot_max_hp_pct"
const X_HOT_PER_LEVEL: StringName = &"hot_per_level"
## Mana: fração da mana máxima (em duration_sec, se > 0).
const X_MP_PCT: StringName = &"mp_pct"
## Alvos aliados no máximo (áreas de grupo; 0 = todos).
const X_MAX_TARGETS: StringName = &"max_targets"
## BUFF: próximos N golpes físicos críticos.
const X_CRIT_CHARGES: StringName = &"crit_charges"
## COUNTER: multiplicador do revide (× ATQ).
const X_REFLECT_MULT: StringName = &"reflect_mult"
## BACKSTEP: células para trás.
const X_DISTANCE_CELLS: StringName = &"distance_cells"
## Áreas no chão com enfraquecimento: chaves "zone_<mod>" viram mods do DEBUFF de quem estiver dentro.
const X_ZONE_PREFIX: String = "zone_"
const PER_LEVEL_SUFFIX: String = "_per_level"
## CRAFT (ofícios dos títulos: Fazer Flechas, Curativo de Mateiro...): extra {"craft_item": id, "craft_qty": n, "craft_qty_per_level": n,
## "materials": {item_id: qtd}}. Confere materiais e espaço antes de conjurar; entrega no fim.
const X_CRAFT_ITEM: StringName = &"craft_item"
const X_CRAFT_QTY: StringName = &"craft_qty"
const X_MATERIALS: StringName = &"materials"
const MSG_CRAFT_MISSING: String = "PROG_MSG_CRAFT_MISSING"
const MSG_CRAFTED: String = "PROG_MSG_CRAFTED"
const MSG_CRAFT_IN_COMBAT: String = "PROG_MSG_CRAFT_IN_COMBAT"
## Folga do arredondamento para baixo (0,334 × 3 = 1,002 conta como 1).
const CRAFT_QTY_EPSILON: float = 0.001
## STEAL (Surrupiar): alvo único, monstro vivo e perto. Chance = steal_chance (+ por nível) + (DES + SOR) ×
## steal_stat_ratio, até STEAL_MAX_CHANCE. Recusa chefe, atroz e provação; um por monstro (CombatService.steal).
const X_STEAL_CHANCE: StringName = &"steal_chance"
const X_STEAL_STAT_RATIO: StringName = &"steal_stat_ratio"
const STEAL_MAX_CHANCE: float = 0.95
const MSG_STEAL_OK: String = "PROG_MSG_STEAL_OK"
const MSG_STEAL_FAILED: String = "PROG_MSG_STEAL_FAILED"
const MSG_STEAL_ALREADY: String = "PROG_MSG_STEAL_ALREADY"
const MSG_STEAL_REFUSED: String = "PROG_MSG_STEAL_REFUSED"
const MSG_STEAL_NOTHING: String = "PROG_MSG_STEAL_NOTHING"
## Motivo de CombatService.steal -> mensagem ao jogador.
const STEAL_MESSAGES: Dictionary[String, String] = {
	CombatService.STEAL_BOSS: MSG_STEAL_REFUSED, CombatService.STEAL_TRIAL: MSG_STEAL_REFUSED,
	CombatService.STEAL_ALREADY: MSG_STEAL_ALREADY, CombatService.STEAL_NOTHING: MSG_STEAL_NOTHING,
	CombatService.STEAL_FAILED: MSG_STEAL_FAILED, CombatService.STEAL_INVENTORY_FULL: SysMsg.INVENTORY_FULL,
	CombatService.STEAL_INVALID: MSG_NO_TARGET}
## Efeitos que não são ofensivos (podem em cidade, não marcam combate).
const SUPPORT_EFFECTS: Array[int] = [SkillDef.Effect.SHIELD, SkillDef.Effect.BUFF_DEF, SkillDef.Effect.HEAL,
		SkillDef.Effect.HOT, SkillDef.Effect.BUFF, SkillDef.Effect.BACKSTEP, SkillDef.Effect.BLINK,
		SkillDef.Effect.COUNTER, SkillDef.Effect.STEALTH, SkillDef.Effect.CLEANSE, SkillDef.Effect.MP_RESTORE,
		SkillDef.Effect.CRAFT]
## Efeitos mágicos por padrão (os demais novos seguem a escola: arcane/support = mágico).
const MAGIC_SCHOOLS: Array[StringName] = [&"arcane", &"support"]

class PendingCast:
	var peer_id: int = 0
	var skill: SkillDef = null
	var level: int = 1
	var target_id: int = 0
	var point: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3.FORWARD
	var resolve_msec: int = 0
	## Fim da conjuração (depois disso vem só o aviso no chão, que não é interrompido).
	var cast_end_msec: int = 0
	var cast_ms: int = 0
	var cooldown_ms: int = 0
	var cooldown_started: bool = false

var progression: Progression = null
var world: ServerWorld = null
var bridge: CombatBridge = null
var statuses: StatusEffects = null
## Conjurações em andamento (uma por jogador; interrompíveis).
var _pending: Dictionary[int, PendingCast] = {}
## Já lançadas, esperando o impacto depois do aviso no chão (Queda Estelar). O jogador está livre.
var _released: Array[PendingCast] = []
## peer_id -> {skill_id: msec em que libera}
var _cooldowns: Dictionary[int, Dictionary] = {}
## peer_id -> {skill_id: recarga efetiva total (ms)} (a sombra da barra usa o total certo).
var _cooldown_totals: Dictionary[int, Dictionary] = {}


func _init(p_progression: Progression) -> void:
	progression = p_progression
	if p_progression != null:
		world = p_progression.world
		bridge = p_progression.bridge
		statuses = p_progression.statuses


static func scaled(base: float, per_level: float, level: int) -> float:
	return base + per_level * (level - 1)


static func _x(def: SkillDef, key: StringName, fallback: float = 0.0) -> float:
	return float(def.extra.get(key, fallback))


## Parâmetro de extra no nível: extra[key] + extra[key_per_level] × (nível − 1).
static func param(def: SkillDef, key: StringName, level: int, fallback: float = 0.0) -> float:
	return float(def.extra.get(key, fallback)) \
			+ float(def.extra.get(StringName(String(key) + PER_LEVEL_SUFFIX), 0.0)) * (level - 1)


static func damage_kind_of(def: SkillDef) -> StringName:
	if def.extra.has(X_DAMAGE_KIND):
		return StringName(str(def.extra[X_DAMAGE_KIND]))
	match def.effect:
		SkillDef.Effect.PHYSICAL_DAMAGE, SkillDef.Effect.DASH_STUN, SkillDef.Effect.BUFF_DEF:
			return CombatBridge.DAMAGE_PHYSICAL
		SkillDef.Effect.MAGIC_DAMAGE, SkillDef.Effect.DAMAGE_OVER_TIME, SkillDef.Effect.SHIELD, \
				SkillDef.Effect.SLOW:
			return CombatBridge.DAMAGE_MAGIC
	return CombatBridge.DAMAGE_MAGIC if def.school in MAGIC_SCHOOLS else CombatBridge.DAMAGE_PHYSICAL


## Quantas unidades o CRAFT entrega neste nível. Fração arredonda para baixo (0,5 por nível = +1 a cada 2).
static func craft_qty(def: SkillDef, level: int) -> int:
	return maxi(1, floori(param(def, X_CRAFT_QTY, level, 1.0) + CRAFT_QTY_EPSILON))


## Chance do Surrupiar no nível, com DES e SOR de quem tenta (0..STEAL_MAX_CHANCE).
static func steal_chance(def: SkillDef, level: int, dex: int, luk: int) -> float:
	var stat_bonus: float = float(maxi(0, dex) + maxi(0, luk)) * _x(def, X_STEAL_STAT_RATIO)
	return clampf(param(def, X_STEAL_CHANCE, level) + stat_bonus, 0.0, STEAL_MAX_CHANCE)


## Antes de conjurar o Surrupiar: o alvo aceita? "" = aceita; senão avisa e devolve o motivo.
func steal_block(session: PlayerSession, target_id: int) -> String:
	var k: Object = bridge.k_service()
	var t: NetEntity = world.get_entity(target_id)
	var brain: MonsterBrain = null
	if k != null and t != null and t.is_monster() and k.has_method(CombatBridge.M_GET_BRAIN):
		brain = k.call(CombatBridge.M_GET_BRAIN, t) as MonsterBrain
	var why: String = CombatService.steal_block_reason(brain)
	if why.is_empty():
		return ""
	Net.push_system_message(session.peer_id, STEAL_MESSAGES.get(why, MSG_NO_TARGET))
	return "cast_" + why


## Fim da conjuração do Surrupiar: tenta (CombatService.steal), avisa e o monstro reage a quem tentou.
func _steal(session: PlayerSession, def: SkillDef, pc: PendingCast) -> bool:
	var me: NetEntity = session.entity
	var t: NetEntity = world.get_entity(pc.target_id)
	var k: Object = bridge.k_service()
	if not _alive(t) or k == null or not k.has_method(&"steal"):
		return false
	var stats: Dictionary = session.character.compute_stats()
	var chance: float = steal_chance(def, pc.level, int(stats.get(&"dex", 0)), int(stats.get(&"luk", 0)))
	var res: Dictionary = k.call(&"steal", me, t, chance)
	_provoke(me, t)
	if bool(res.get("ok", false)):
		var item: ItemDef = Content.item(StringName(str(res["item"])))
		Net.push_system_message(session.peer_id, MSG_STEAL_OK, [item.name_key if item != null else str(res["item"])])
		return true
	Net.push_system_message(session.peer_id, STEAL_MESSAGES.get(str(res.get("reason", "")), MSG_STEAL_FAILED))
	return false


## Por que não dá para fabricar agora ("" = dá): falta material ou não cabe na mochila. Avisa o jogador.
func craft_block(session: PlayerSession, def: SkillDef, level: int) -> String:
	if bridge.is_in_combat(session.peer_id):
		Net.push_system_message(session.peer_id, MSG_CRAFT_IN_COMBAT)
		return "cast_craft_in_combat"
	var inv: Inventory = session.character.inventory
	var out_id := StringName(str(def.extra.get(X_CRAFT_ITEM, "")))
	var out_def: ItemDef = Content.item(out_id)
	if out_def == null:
		return "cast_craft_bad_item"
	var materials: Dictionary = def.extra.get(X_MATERIALS, {})
	for raw: Variant in materials:
		var mat := StringName(str(raw))
		var need: int = int(materials[raw])
		if inv.count(mat) < need:
			var md: ItemDef = Content.item(mat)
			Net.push_system_message(session.peer_id, MSG_CRAFT_MISSING,
					[md.name_key if md != null else String(mat), need, inv.count(mat)])
			return "cast_craft_missing_materials"
	if not inv.can_add(out_id, craft_qty(def, level)):
		Net.push_system_message(session.peer_id, SysMsg.INVENTORY_FULL)
		return "cast_craft_inventory_full"
	return ""


## Fim da conjuração do CRAFT: revalida, gasta os materiais e entrega o item.
func _craft(session: PlayerSession, def: SkillDef, level: int) -> bool:
	if not craft_block(session, def, level).is_empty():
		return false
	var inv: Inventory = session.character.inventory
	var materials: Dictionary = def.extra.get(X_MATERIALS, {})
	for raw: Variant in materials:
		var left: int = int(materials[raw])
		for slot: int in inv.size():
			if left <= 0:
				break
			var st: ItemStack = inv.get_slot(slot)
			if st != null and st.item_id == StringName(str(raw)):
				var n: int = mini(left, st.qty)
				inv.remove_at(slot, n)
				left -= n
	var out_id := StringName(str(def.extra[X_CRAFT_ITEM]))
	var qty: int = craft_qty(def, level)
	inv.add(out_id, qty)
	var out_def: ItemDef = Content.item(out_id)
	Net.push_system_message(session.peer_id, MSG_CRAFTED, [out_def.name_key, qty])
	Net.log_line("skill_crafted", {"peer": session.peer_id, "skill": String(def.id), "item": String(out_id),
			"qty": qty, "level": level})
	return true


static func is_offensive(def: SkillDef) -> bool:
	return def.effect not in SUPPORT_EFFECTS


## Recargas restantes (ms) do jogador, para o snapshot.
func cooldowns_for(peer_id: int) -> Dictionary:
	var out: Dictionary = {}
	var now: int = Time.get_ticks_msec()
	var cd: Dictionary = _cooldowns.get(peer_id, {})
	for id: StringName in cd:
		var left: int = int(cd[id]) - now
		if left > 0:
			out[String(id)] = left
	return out


## Recarga efetiva total (ms) das skills em recarga, para o snapshot.
func cooldown_totals_for(peer_id: int) -> Dictionary:
	var out: Dictionary = {}
	var now: int = Time.get_ticks_msec()
	var cd: Dictionary = _cooldowns.get(peer_id, {})
	var tot: Dictionary = _cooldown_totals.get(peer_id, {})
	for id: StringName in cd:
		if int(cd[id]) > now:
			out[String(id)] = int(tot.get(id, int(cd[id]) - now))
	return out


## Conjuração restante (ms), só a fase interrompível (sem o aviso no chão).
func casting_ms(peer_id: int) -> int:
	var p: PendingCast = _pending.get(peer_id)
	return maxi(0, p.cast_end_msec - Time.get_ticks_msec()) if p != null else 0


## Conjuração em andamento: {"skill", "total_ms", "left_ms"} ou {}.
func casting_info(peer_id: int) -> Dictionary:
	var p: PendingCast = _pending.get(peer_id)
	if p == null or casting_ms(peer_id) <= 0:
		return {}
	return {"skill": String(p.skill.id), "total_ms": p.cast_ms, "left_ms": casting_ms(peer_id)}


## Tempos efetivos (s) de uma skill para este jogador: {"cast": s, "cooldown": s}.
static func effective_times(session: PlayerSession, def: SkillDef) -> Dictionary:
	var stats: Dictionary = session.character.compute_stats()
	var level: int = session.character.progression.skill_level(def.id)
	return {"cast": CastTiming.skill_cast_sec(def, level, stats),
			"cooldown": CastTiming.skill_cooldown_sec(def, stats)}


## Pedido de lançamento. Devolve "" (aceito) ou o motivo (log de intenção inválida).
func cast(session: PlayerSession, skill_id: StringName, target_entity_id: int,
		ground_pos: Vector3) -> String:
	var def: SkillDef = Content.skill(skill_id)
	var data: ProgressionData = session.character.progression
	var me: NetEntity = session.entity
	if def == null:
		return "cast_unknown_skill"
	if not data.knows(skill_id):
		return "cast_not_known"
	if def.passive:
		return "cast_passive_skill"
	if not def.companion_id.is_empty() and session.character.companion_active != def.companion_id:
		return "cast_companion_inactive"
	if data.hotbar_index_of(skill_id) < 0:
		return "cast_not_on_hotbar"
	if session.character.hp <= 0:
		return "cast_dead"
	if _pending.has(session.peer_id) or (world.items != null \
			and not world.items.using_info(session.peer_id).is_empty()):
		return "cast_busy"
	if statuses.is_stunned(me):
		Net.push_system_message(session.peer_id, MSG_STUNNED)
		return "cast_stunned"
	var now: int = Time.get_ticks_msec()
	var ready_at: int = int(_cooldowns.get(session.peer_id, {}).get(skill_id, 0))
	if now < ready_at:
		Net.push_system_message(session.peer_id, MSG_COOLDOWN,
				[def.name_key, ceili((ready_at - now) / MSEC_PER_SEC)])
		return "cast_on_cooldown"
	if session.character.mp < def.mana_cost:
		Net.push_system_message(session.peer_id, MSG_NO_MANA)
		return "cast_no_mana"
	if def.requires_melee_weapon and not _has_melee_weapon(session):
		Net.push_system_message(session.peer_id, MSG_NEEDS_MELEE)
		return "cast_needs_melee_weapon"
	if def.requires_bow:
		if not has_weapon_kind(session, ItemDef.WeaponKind.BOW):
			Net.push_system_message(session.peer_id, MSG_NEEDS_BOW)
			return "cast_needs_bow"
		if not session.character.equipment.has_ammo_equipped():
			Net.push_system_message(session.peer_id, MSG_NO_AMMO)
			return "cast_needs_ammo"
	if def.effect == SkillDef.Effect.CRAFT:
		var why: String = craft_block(session, def, data.skill_level(skill_id))
		if not why.is_empty():
			return why
	if is_offensive(def) and not _combat_allowed(me):
		Net.push_system_message(session.peer_id, MSG_NO_COMBAT_HERE)
		return "cast_combat_not_allowed"
	var pc := PendingCast.new()
	pc.peer_id = session.peer_id
	pc.skill = def
	pc.level = data.skill_level(skill_id)
	var reason: String = _resolve_target(session, def, target_entity_id, ground_pos, pc)
	if not reason.is_empty():
		return reason
	if def.effect == SkillDef.Effect.STEAL:
		reason = steal_block(session, pc.target_id)
		if not reason.is_empty():
			return reason
	# Aceito: gasta mana, conjura (tempo efetivo, GDD §8.1) e avisa a instância (prévia/efeito no
	# cliente). A recarga começa quando a conjuração termina.
	if world.mounts != null:
		world.mounts.dismount(session)
	if world.companions != null:
		world.companions.cancel(session)
	session.character.mp -= def.mana_cost
	session.mark_dirty(PlayerSession.DIRTY_STATS)
	var times: Dictionary = effective_times(session, def)
	pc.cast_ms = CastTiming.to_ms(times["cast"])
	pc.cooldown_ms = CastTiming.to_ms(times["cooldown"])
	pc.cast_end_msec = now + pc.cast_ms
	var delay_sec: float = pc.cast_ms / MSEC_PER_SEC + def.ground_warning_sec
	pc.resolve_msec = now + roundi(delay_sec * MSEC_PER_SEC)
	if pc.cast_ms <= 0:
		_start_cooldown(pc, now)
	me.face_towards(pc.point)
	if me.get_mover() != null and delay_sec > 0.0:
		me.get_mover().halt()
	NetProgress.push_skill_cast(Net.get_instance_peer_ids(me.instance_id), me.entity_id, skill_id,
			pc.target_id, pc.point, roundi(delay_sec * MSEC_PER_SEC))
	Net.log_line("skill_cast", {"peer": session.peer_id, "skill": String(skill_id),
			"level": pc.level, "target": pc.target_id, "point": str(pc.point.snappedf(0.01)),
			"type": SkillDef.TargetType.keys()[def.target_type], "delay_ms": roundi(delay_sec * MSEC_PER_SEC),
			"cast_ms": pc.cast_ms, "cooldown_ms": pc.cooldown_ms})
	if is_offensive(def):
		bridge.mark_combat(me)
	if delay_sec <= 0.0:
		_resolve(pc)
	elif pc.cast_ms <= 0:
		_released.append(pc)
	else:
		_pending[session.peer_id] = pc
	progression.mark_dirty(session)
	return ""


func _has_melee_weapon(session: PlayerSession) -> bool:
	return has_weapon_kind(session, ItemDef.WeaponKind.BLADE)


static func has_weapon_kind(session: PlayerSession, kind: ItemDef.WeaponKind) -> bool:
	for st: ItemStack in session.character.equipment.gear_stacks():
		var d: ItemDef = st.get_def()
		if d != null and d.type == ItemDef.ItemType.WEAPON and d.weapon_kind == kind:
			return true
	return false


func _combat_allowed(me: NetEntity) -> bool:
	var zr: Variant = world.get(&"zone_rules")
	if zr is Object and (zr as Object).has_method(&"combat_allowed"):
		return bool((zr as Object).call(&"combat_allowed", me.instance_id))
	var zone: ZoneDef = Content.zone(Progression.map_of(me.instance_id))
	return zone == null or zone.combat_allowed


func _max_range(def: SkillDef, me: NetEntity = null) -> float:
	var bonus: float = statuses.range_bonus_cells(me) if me != null and def.requires_bow else 0.0
	return (def.range_cells + bonus + RANGE_SLACK_CELLS) * Balance.cfg.cell_size


## Preenche alvo/ponto/direção conforme o tipo de alvo. "" = ok.
func _resolve_target(session: PlayerSession, def: SkillDef, target_entity_id: int,
		ground_pos: Vector3, pc: PendingCast) -> String:
	var me: NetEntity = session.entity
	var facing := Vector3(-sin(me.facing_yaw), 0.0, -cos(me.facing_yaw))
	if def.id == &"bow_companion_guara_track" and target_entity_id == me.entity_id and not bridge.is_in_combat(session.peer_id):
		pc.target_id = 0
		pc.point = me.net_position
		return ""
	match def.target_type:
		SkillDef.TargetType.SINGLE:
			var t: NetEntity = world.get_entity(target_entity_id)
			if t == null or not bridge.can_attack(me, t):
				Net.push_system_message(session.peer_id, MSG_NO_TARGET)
				return "cast_target_invalid"
			if me.flat_distance_to(t.net_position) > _max_range(def, me):
				Net.push_system_message(session.peer_id, SysMsg.TOO_FAR)
				return "cast_out_of_range"
			pc.target_id = t.entity_id
			pc.point = t.net_position
		SkillDef.TargetType.GROUND_AREA:
			if me.flat_distance_to(ground_pos) > _max_range(def, me):
				Net.push_system_message(session.peer_id, SysMsg.TOO_FAR)
				return "cast_out_of_range"
			pc.point = ground_pos
			if def.effect == SkillDef.Effect.BLINK:
				var cell: Variant = _blink_cell(me, ground_pos)
				if cell == null:
					Net.push_system_message(session.peer_id, MSG_BLINK_BLOCKED)
					return "cast_blink_blocked"
				pc.point = cell as Vector3
		SkillDef.TargetType.CONE, SkillDef.TargetType.LINE:
			pc.point = me.net_position
			var d := Vector3(ground_pos.x - me.net_position.x, 0.0, ground_pos.z - me.net_position.z)
			var t2: NetEntity = world.get_entity(target_entity_id)
			if d.length() < Balance.cfg.cell_size * 0.5 and t2 != null:
				d = Vector3(t2.net_position.x - me.net_position.x, 0.0, t2.net_position.z - me.net_position.z)
			pc.dir = d.normalized() if d.length() > 0.0 else facing
			pc.point = me.net_position + pc.dir * Balance.cfg.cell_size
		SkillDef.TargetType.ALLY_OR_SELF:
			var ally: NetEntity = world.get_entity(target_entity_id)
			if ally != null and ((ally.is_player() and bridge.is_ally(me, ally)) or progression.is_protected_ally(me, ally)) \
					and ally.instance_id == me.instance_id \
					and me.flat_distance_to(ally.net_position) <= _max_range(def, me):
				pc.target_id = ally.entity_id
			else:
				pc.target_id = me.entity_id
			pc.point = world.get_entity(pc.target_id).net_position
		_:
			# SELF e SELF_AREA: centro no próprio jogador.
			pc.target_id = me.entity_id
			pc.point = me.net_position
	if pc.dir == Vector3.FORWARD and def.target_type not in [SkillDef.TargetType.CONE, SkillDef.TargetType.LINE]:
		var d3 := Vector3(pc.point.x - me.net_position.x, 0.0, pc.point.z - me.net_position.z)
		pc.dir = d3.normalized() if d3.length() > 0.0 else facing
	return ""


func _start_cooldown(pc: PendingCast, now: int) -> void:
	pc.cooldown_started = true
	var cd: Dictionary = _cooldowns.get(pc.peer_id, {})
	cd[pc.skill.id] = now + pc.cooldown_ms
	_cooldowns[pc.peer_id] = cd
	var tot: Dictionary = _cooldown_totals.get(pc.peer_id, {})
	tot[pc.skill.id] = pc.cooldown_ms
	_cooldown_totals[pc.peer_id] = tot


func tick() -> void:
	var now: int = Time.get_ticks_msec()
	for peer_id: int in _pending.keys():
		var pc: PendingCast = _pending[peer_id]
		var session: PlayerSession = world.get_session(peer_id)
		if session == null or session.entity == null:
			_pending.erase(peer_id)
			continue
		if not pc.cooldown_started:
			# Ainda conjurando: atordoado ou morto interrompe.
			if statuses.is_stunned(session.entity):
				interrupt(peer_id, INTERRUPT_STUN)
				continue
			if session.character.hp <= 0:
				interrupt(peer_id, INTERRUPT_DEAD)
				continue
			if now >= pc.cast_end_msec:
				_start_cooldown(pc, now)
				progression.mark_dirty(session)
		if now >= pc.resolve_msec:
			_pending.erase(peer_id)
			_resolve(pc)
		elif pc.cooldown_started:
			# Conjuração terminou; falta só o aviso no chão: libera o jogador para a próxima.
			_pending.erase(peer_id)
			_released.append(pc)
	for i: int in range(_released.size() - 1, -1, -1):
		if now >= _released[i].resolve_msec:
			var done: PendingCast = _released[i]
			_released.remove_at(i)
			_resolve(done)


## Descarta a conjuração (e impactos ainda no aviso) sem mensagem ao dono (troca de instância, morte).
func cancel(peer_id: int) -> void:
	if _pending.has(peer_id) and not _pending[peer_id].cooldown_started:
		interrupt(peer_id, INTERRUPT_DEAD, false)
	_pending.erase(peer_id)
	_released = _released.filter(func(p: PendingCast) -> bool: return p.peer_id != peer_id)


## Interrompe a conjuração em andamento (andar, atordoamento). A fase de aviso no chão (depois da
## conjuração) não é interrompida. Mana gasta não volta; a recarga não começa. true = interrompeu.
func interrupt(peer_id: int, reason: StringName, notify_owner: bool = true) -> bool:
	var pc: PendingCast = _pending.get(peer_id)
	if pc == null or pc.cooldown_started:
		return false
	_pending.erase(peer_id)
	var session: PlayerSession = world.get_session(peer_id)
	if session != null and session.entity != null and is_instance_valid(session.entity):
		NetProgress.push_cast_cancelled(Net.get_instance_peer_ids(session.entity.instance_id),
				session.entity.entity_id, pc.skill.id)
		if notify_owner:
			Net.push_system_message(peer_id, MSG_CAST_INTERRUPTED, [pc.skill.name_key])
		progression.mark_dirty(session)
	Net.log_line("skill_cast_interrupted", {"peer": peer_id, "skill": String(pc.skill.id),
			"reason": String(reason), "left_ms": maxi(0, pc.cast_end_msec - Time.get_ticks_msec())})
	return true


# ---------------------------------------------------------------- efeitos

func _resolve(pc: PendingCast) -> void:
	var session: PlayerSession = world.get_session(pc.peer_id)
	if session == null:
		return
	var me: NetEntity = session.entity
	var def: SkillDef = pc.skill
	if not def.companion_id.is_empty():
		if world.companions != null and not def.passive and session.character.companion_active == def.companion_id:
			world.companions.use_active(session, def.id, pc.target_id)
		return
	if def.requires_bow:
		if not session.character.consume_ammo(1):
			Net.push_system_message(session.peer_id, MSG_NO_AMMO)
			return
		var k_refill: Object = bridge.k_service()
		if k_refill != null and k_refill.has_method(&"tell_ammo_refill"):
			k_refill.call(&"tell_ammo_refill", session)
		session.mark_dirty(PlayerSession.DIRTY_EQUIPMENT | PlayerSession.DIRTY_STATS)
		var k: Object = bridge.k_service()
		if k != null and k.has_method(&"_sync_player"):
			k.call(&"_sync_player", session)
	var mult: float = scaled(def.base_multiplier, def.multiplier_per_level, pc.level)
	var duration: float = scaled(def.duration_sec, _x(def, X_DURATION_PER_LEVEL), pc.level)
	var kind: StringName = damage_kind_of(def)
	var hits: int = 0
	match def.effect:
		SkillDef.Effect.SHIELD:
			var stats: Dictionary = session.character.compute_stats()
			var is_holy: bool = _is_holy_or_sacred(session, def)
			var matk: int = stats.get(CharacterStats.K_HOLY_MATK, stats[CharacterStats.K_MATK]) if is_holy else stats[CharacterStats.K_MATK]
			var w_factor: float = _holy_wisdom_factor(session) if is_holy else 1.0
			var amount: float = (_x(def, X_SHIELD_BASE) + matk * _x(def, X_SHIELD_MATK_RATIO)) \
					* (1.0 + _x(def, X_SHIELD_PER_LEVEL) * (pc.level - 1)) * w_factor
			for ally: NetEntity in _ally_targets(me, def, pc):
				statuses.add(ally, StatusEffects.Kind.SHIELD, duration, amount, def.id, me)
				hits += 1
		SkillDef.Effect.BUFF_DEF:
			var def_pct: float = scaled(_x(def, X_DEF_PCT), _x(def, X_DEF_PCT_PER_LEVEL), pc.level)
			if _is_holy_or_sacred(session, def):
				def_pct *= _holy_wisdom_factor(session)
			statuses.add(me, StatusEffects.Kind.DEF_BUFF, duration, def_pct, def.id, me)
			if _x(def, X_SELF_SLOW_PCT) > 0.0:
				statuses.add(me, StatusEffects.Kind.SLOW, duration, _x(def, X_SELF_SLOW_PCT), def.id, me)
			hits = 1
		SkillDef.Effect.DAMAGE_OVER_TIME:
			if def.target_type in [SkillDef.TargetType.GROUND_AREA, SkillDef.TargetType.LINE]:
				var line: bool = def.target_type == SkillDef.TargetType.LINE
				statuses.add_ground_zone(me, pc.point, def.radius_cells * Balance.cfg.cell_size,
						duration, mult, kind, def.id, def if line else null, me.net_position, pc.dir,
						zone_mods_for(def, pc.level))
				hits = 1
			else:
				for t: NetEntity in _targets(me, def, pc):
					statuses.add(t, StatusEffects.Kind.DOT, duration, mult, def.id, me, kind)
					hits += 1
		SkillDef.Effect.DASH_STUN:
			var t: NetEntity = world.get_entity(pc.target_id)
			if t == null or not bridge.can_attack(me, t):
				return
			_dash_next_to(me, t)
			bridge.apply_damage(me, t, kind, mult, def.id)
			var stun: float = scaled(_x(def, X_STUN_SEC), _x(def, X_STUN_PER_LEVEL), pc.level)
			if is_instance_valid(t):
				statuses.add(t, StatusEffects.Kind.STUN, stun, 0.0, def.id, me)
			hits = 1
		SkillDef.Effect.HEAL, SkillDef.Effect.CLEANSE:
			var heal: int = _heal_amount(session, def, pc.level)
			for ally: NetEntity in _ally_targets(me, def, pc):
				if def.effect == SkillDef.Effect.CLEANSE or _x(def, X_CLEANSE) > 0.0:
					statuses.cleanse(ally)
				elif _x(def, X_CLEANSE_DOT) > 0.0:
					statuses.cleanse(ally, StatusEffects.Kind.DOT)
				if heal > 0:
					bridge.heal(ally, heal, me)
				hits += 1
		SkillDef.Effect.HOT:
			var stats: Dictionary = session.character.compute_stats()
			var is_holy: bool = _is_holy_or_sacred(session, def)
			var matk2: int = stats.get(CharacterStats.K_HOLY_MATK, stats[CharacterStats.K_MATK]) if is_holy else stats[CharacterStats.K_MATK]
			var w_factor: float = _holy_wisdom_factor(session) if is_holy else 1.0
			for ally: NetEntity in _ally_targets(me, def, pc):
				var per_tick: float = (param(def, X_HOT_BASE, pc.level) + matk2 * param(def, X_HOT_MATK_RATIO, pc.level)
						+ _max_hp_of(ally) * param(def, X_HOT_MAX_HP_PCT, pc.level)) \
						* (1.0 + _x(def, X_HOT_PER_LEVEL) * (pc.level - 1)) * w_factor
				statuses.add(ally, StatusEffects.Kind.HOT, duration, per_tick, def.id, me)
				hits += 1
		SkillDef.Effect.BUFF:
			var mods: Dictionary = mods_for(def, pc.level)
			if _is_holy_or_sacred(session, def):
				var w_factor: float = _holy_wisdom_factor(session)
				var scaled_mods: Dictionary = {}
				for k: Variant in mods.keys():
					scaled_mods[k] = float(mods[k]) * w_factor
				mods = scaled_mods
			var charges: int = roundi(param(def, X_CRIT_CHARGES, pc.level))
			for ally: NetEntity in _ally_targets(me, def, pc):
				statuses.add(ally, StatusEffects.Kind.BUFF, duration, 0.0, def.id, me, &"", mods, charges)
				hits += 1
			if _x(def, X_SELF_SLOW_PCT) > 0.0:
				statuses.add(me, StatusEffects.Kind.SLOW, duration, _x(def, X_SELF_SLOW_PCT), def.id, me)
		SkillDef.Effect.MP_RESTORE:
			for ally: NetEntity in _ally_targets(me, def, pc):
				var total: float = _max_mp_of(ally) * param(def, X_MP_PCT, pc.level)
				if duration > 0.0:
					statuses.add(ally, StatusEffects.Kind.MP_REGEN, duration,
							total / maxf(1.0, floorf(duration / StatusEffects.DOT_TICK_SEC)), def.id, me)
				else:
					bridge.restore_mp(ally, roundi(total))
				hits += 1
		SkillDef.Effect.CRAFT:
			hits = 1 if _craft(session, def, pc.level) else 0
		SkillDef.Effect.STEAL:
			hits = 1 if _steal(session, def, pc) else 0
		SkillDef.Effect.COUNTER:
			statuses.add(me, StatusEffects.Kind.COUNTER, duration, param(def, X_REFLECT_MULT, pc.level, mult),
					def.id, me)
			hits = 1
		SkillDef.Effect.STEALTH:
			statuses.add(me, StatusEffects.Kind.STEALTH, duration, 0.0, def.id, me)
			hits = 1
		SkillDef.Effect.BACKSTEP:
			var back := Vector3(-pc.dir.x, 0.0, -pc.dir.z)
			var target_e: NetEntity = world.get_entity(pc.target_id)
			if target_e != null and target_e != me:
				back = Vector3(me.net_position.x - target_e.net_position.x, 0.0,
						me.net_position.z - target_e.net_position.z).normalized()
			slide(me, back, param(def, X_DISTANCE_CELLS, pc.level))
			hits = 1
		SkillDef.Effect.BLINK:
			var dest: Variant = _blink_cell(me, pc.point)
			if dest != null and me.get_mover() != null:
				me.get_mover().place(dest as Vector3)
				hits = 1
		_:
			# Dano (PHYSICAL/MAGIC/SLOW/MULTI_HIT/KNOCKBACK/PULL) e controle (DEBUFF/TAUNT/ROOT/STUN),
			# com os "riders" de extra em cada alvo.
			hits = _resolve_hostile(session, def, pc, mult, duration, kind)
	Net.log_line("skill_resolved", {"peer": pc.peer_id, "skill": String(def.id),
			"type": SkillDef.TargetType.keys()[def.target_type], "hits": hits,
			"mult": snappedf(mult, 0.01), "effect": SkillDef.Effect.keys()[def.effect]})


func _resolve_hostile(session: PlayerSession, def: SkillDef, pc: PendingCast, mult: float,
		duration: float, kind: StringName) -> int:
	var me: NetEntity = session.entity
	var hits: int = 0
	var targets: Array[NetEntity] = _targets(me, def, pc)
	if _x(def, X_DASH) > 0.0 and not targets.is_empty():
		_dash_next_to(me, targets[0])
	# Bônus lidos antes do primeiro golpe (o golpe tira a invisibilidade).
	var bonus: float = 0.0
	if _x(def, X_STEALTH_BONUS) > 0.0 and statuses.is_hidden(me):
		bonus += param(def, X_STEALTH_BONUS, pc.level)
	if _x(def, X_MISSING_HP_BONUS) > 0.0:
		var max_hp: float = maxf(1.0, _max_hp_of(me))
		bonus += param(def, X_MISSING_HP_BONUS, pc.level) * clampf(1.0 - session.character.hp / max_hp, 0.0, 1.0)
	var is_holy: bool = _is_holy_or_sacred(session, def)
	var w_factor: float = _holy_wisdom_factor(session) if is_holy else 1.0
	var deals_damage: bool = mult > 0.0 and def.effect not in [SkillDef.Effect.TAUNT]
	var strikes: int = maxi(1, roundi(param(def, X_HITS, pc.level, 1.0))) \
			if def.effect == SkillDef.Effect.MULTI_HIT else 1
	var mods: Dictionary = mods_for(def, pc.level)
	for t: NetEntity in targets:
		if deals_damage:
			for i: int in strikes:
				if not _alive(t):
					break
				bridge.apply_damage(me, t, kind, (mult + bonus) * (w_factor if is_holy else 1.0), def.id)
		else:
			_provoke(me, t)
		hits += 1
		if not _alive(t):
			continue
		match def.effect:
			SkillDef.Effect.SLOW:
				statuses.add(t, StatusEffects.Kind.SLOW, duration, _x(def, X_SLOW_PCT) * w_factor, def.id, me)
			SkillDef.Effect.DEBUFF:
				var debuff_mods: Dictionary = mods
				if is_holy and w_factor != 1.0 and not mods.is_empty():
					debuff_mods = {}
					for mk: Variant in mods.keys():
						debuff_mods[mk] = float(mods[mk]) * w_factor
				if not debuff_mods.is_empty():
					statuses.add(t, StatusEffects.Kind.DEBUFF, duration, 0.0, def.id, me, &"", debuff_mods)
				if _x(def, X_SLOW_PCT) > 0.0:
					statuses.add(t, StatusEffects.Kind.SLOW, duration, param(def, X_SLOW_PCT, pc.level) * w_factor, def.id, me)
			SkillDef.Effect.TAUNT:
				statuses.add(t, StatusEffects.Kind.TAUNT, duration, 0.0, def.id, me)
			SkillDef.Effect.ROOT:
				statuses.add(t, StatusEffects.Kind.ROOT, duration, 0.0, def.id, me)
			SkillDef.Effect.STUN:
				statuses.add(t, StatusEffects.Kind.STUN, duration, 0.0, def.id, me)
		_apply_riders(me, t, def, pc.level)
	return hits


## Efeitos extras de um golpe: atordoar, prender, empurrar, puxar e dano contínuo.
func _apply_riders(me: NetEntity, t: NetEntity, def: SkillDef, level: int) -> void:
	if not _alive(t):
		return
	var stun: float = scaled(_x(def, X_STUN_SEC), _x(def, X_STUN_PER_LEVEL), level)
	if stun > 0.0 and def.effect != SkillDef.Effect.DASH_STUN:
		statuses.add(t, StatusEffects.Kind.STUN, stun, 0.0, def.id, me)
	var root: float = param(def, X_ROOT_SEC, level)
	if root > 0.0:
		statuses.add(t, StatusEffects.Kind.ROOT, root, 0.0, def.id, me)
	var dot: float = param(def, X_DOT_MULT, level)
	if dot > 0.0 and _x(def, X_DOT_SEC) > 0.0:
		var dk: StringName = StringName(str(def.extra.get(X_DOT_KIND, damage_kind_of(def))))
		statuses.add(t, StatusEffects.Kind.DOT, param(def, X_DOT_SEC, level), dot, def.id, me, dk)
	if statuses.is_cc_immune(t):
		return
	var push: float = param(def, X_KNOCKBACK_CELLS, level)
	var d := Vector3(t.net_position.x - me.net_position.x, 0.0, t.net_position.z - me.net_position.z)
	if push > 0.0 and d.length() > 0.0:
		slide(t, d.normalized(), push)
	var pull: float = param(def, X_PULL_CELLS, level)
	if pull > 0.0 and d.length() > 0.0:
		# Puxa até ficar ao lado de quem puxou (nunca passa por cima).
		var cells: float = minf(pull, maxf(0.0, d.length() / Balance.cfg.cell_size - 1.0))
		slide(t, -d.normalized(), cells)


func _alive(t: NetEntity) -> bool:
	return t != null and is_instance_valid(t) and not t.is_queued_for_deletion()


## Monstro atingido só por controle (sem dano) também reage a quem lançou.
func _provoke(me: NetEntity, t: NetEntity) -> void:
	bridge.mark_combat(me)
	var k: Object = bridge.k_service()
	if k == null or not t.is_monster() or not k.has_method(CombatBridge.M_GET_BRAIN):
		return
	var brain: Object = k.call(CombatBridge.M_GET_BRAIN, t)
	if brain != null and brain.has_method(&"on_damaged"):
		brain.call(&"on_damaged", me)


## Aliados atingidos: SELF = quem lançou; ALLY_OR_SELF = o alvo escolhido; SELF_AREA/GROUND_AREA =
## jogadores vivos na área (mais perto primeiro, até max_targets).
func _ally_targets(me: NetEntity, def: SkillDef, pc: PendingCast) -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	match def.target_type:
		SkillDef.TargetType.SELF_AREA, SkillDef.TargetType.GROUND_AREA:
			var center: Vector3 = me.net_position if def.target_type == SkillDef.TargetType.SELF_AREA else pc.point
			out = bridge.allies_near(me, center, def.radius_cells * Balance.cfg.cell_size)
			out.sort_custom(func(a: NetEntity, b: NetEntity) -> bool:
				return a.flat_distance_to(center) < b.flat_distance_to(center))
			var cap: int = roundi(_x(def, X_MAX_TARGETS))
			if cap > 0 and out.size() > cap:
				out.resize(cap)
		SkillDef.TargetType.ALLY_OR_SELF, SkillDef.TargetType.SELF:
			var ally: NetEntity = world.get_entity(pc.target_id)
			out.append(ally if ally != null else me)
		_:
			out.append(me)
	return out


## Modificadores de BUFF/DEBUFF (StatusEffects.MOD_KEYS) lidos de extra no nível da skill.
static func mods_for(def: SkillDef, level: int) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in StatusEffects.MOD_KEYS:
		if def.extra.has(key):
			out[key] = param(def, key, level)
	return out


## Modificadores das áreas no chão: chaves "zone_<mod>" (Fumaça Amarga: zone_heal_received_pct).
static func zone_mods_for(def: SkillDef, level: int) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in StatusEffects.MOD_KEYS:
		var zk := StringName(X_ZONE_PREFIX + String(key))
		if def.extra.has(zk):
			out[key] = param(def, zk, level)
	return out


func _is_holy_or_sacred(session: PlayerSession, def: SkillDef) -> bool:
	if def != null:
		if def.is_holy_or_light():
			return true
		if def.school in [&"support", &"holy", &"shamanic"]:
			return true
	if session != null and session.character != null and session.character.progression != null:
		var title_id: StringName = session.character.progression.displayed_title
		if TitleDef.is_holy_title_id(title_id):
			return true
	return false


func _holy_wisdom_factor(session: PlayerSession) -> float:
	if session == null or session.character == null:
		return 1.0
	var stats: Dictionary = session.character.compute_stats()
	var spi: int = int(stats.get(&"spi", CharacterStats.BASE_ATTRIBUTE))
	return maxf(0.1, 1.0 + float(spi - CharacterStats.BASE_ATTRIBUTE) * 0.02)


func _heal_amount(session: PlayerSession, def: SkillDef, level: int) -> int:
	var stats: Dictionary = session.character.compute_stats()
	var is_holy: bool = _is_holy_or_sacred(session, def)
	var matk: int = stats.get(CharacterStats.K_HOLY_MATK, stats[CharacterStats.K_MATK]) if is_holy else stats[CharacterStats.K_MATK]
	var base: float = param(def, X_HEAL_BASE, level) + matk * param(def, X_HEAL_MATK_RATIO, level)
	var amount: float = base * (1.0 + _x(def, X_HEAL_PER_LEVEL) * (level - 1))
	if is_holy:
		amount *= _holy_wisdom_factor(session)
	return roundi(amount)



func _max_hp_of(e: NetEntity) -> float:
	var s: PlayerSession = world.get_session(e.get_peer_id()) if e.is_player() else null
	return float(s.character.compute_stats()[CharacterStats.K_MAX_HP]) if s != null else 0.0


func _max_mp_of(e: NetEntity) -> float:
	var s: PlayerSession = world.get_session(e.get_peer_id()) if e.is_player() else null
	return float(s.character.compute_stats()[CharacterStats.K_MAX_MP]) if s != null else 0.0


## Passo Estelar: célula andável exatamente no ponto (encaixada na grade). null = bloqueada.
func _blink_cell(me: NetEntity, point: Vector3) -> Variant:
	var grid: WalkGrid = world.get_grid_for_instance(me.instance_id)
	if grid == null:
		return null
	var c: Vector2i = grid.world_to_cell(point)
	return grid.cell_to_world(c) if grid.is_walkable(c) else null


## Alvos hostis dentro da forma da skill (plano XZ).
func _targets(me: NetEntity, def: SkillDef, pc: PendingCast) -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	var cell: float = Balance.cfg.cell_size
	if def.target_type == SkillDef.TargetType.SINGLE:
		var t: NetEntity = world.get_entity(pc.target_id)
		if t != null and bridge.can_attack(me, t):
			out.append(t)
		return out
	for e: NetEntity in bridge.hostile_targets(me):
		if in_shape(def, me.net_position, pc.point, pc.dir, e.net_position, cell):
			out.append(e)
	return out


## Geometria compartilhada (servidor e testes): o ponto p está dentro da forma?
static func in_shape(def: SkillDef, origin: Vector3, point: Vector3, dir: Vector3, p: Vector3,
		cell: float) -> bool:
	match def.target_type:
		SkillDef.TargetType.SELF_AREA:
			return _xz(origin).distance_to(_xz(p)) <= def.radius_cells * cell
		SkillDef.TargetType.GROUND_AREA:
			return _xz(point).distance_to(_xz(p)) <= def.radius_cells * cell
		SkillDef.TargetType.CONE:
			var v: Vector2 = _xz(p) - _xz(origin)
			if v.length() > def.radius_cells * cell:
				return false
			if v.length() <= 0.001:
				return true
			var d2 := Vector2(dir.x, dir.z).normalized()
			return rad_to_deg(absf(d2.angle_to(v))) <= def.cone_deg * 0.5
		SkillDef.TargetType.LINE:
			var v2: Vector2 = _xz(p) - _xz(origin)
			var d3 := Vector2(dir.x, dir.z).normalized()
			var along: float = v2.dot(d3)
			var across: float = absf(v2.cross(d3))
			return along >= 0.0 and along <= def.line_length_cells * cell \
					and across <= def.line_width_cells * cell * 0.5
	return false


static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Investida: para na célula ao lado do alvo, do lado de quem avança.
func _dash_next_to(me: NetEntity, t: NetEntity) -> void:
	var mover: GridMover = me.get_mover()
	if mover == null:
		return
	var d := Vector3(me.net_position.x - t.net_position.x, 0.0, me.net_position.z - t.net_position.z)
	var dir: Vector3 = d.normalized() if d.length() > 0.0 else Vector3.BACK
	var p: Vector3 = world.snap_to_grid(me.instance_id, t.net_position + dir * Balance.cfg.cell_size)
	mover.place(p)
	me.face_towards(t.net_position)


## Desloca a entidade até `cells` células na direção dir, passo a passo pela grade: para antes
## de parede ou borda (empurrar, puxar, recuo). Devolve as células andadas.
func slide(e: NetEntity, dir: Vector3, cells: float) -> int:
	var mover: GridMover = e.get_mover() if e != null else null
	var grid: WalkGrid = mover.grid if mover != null else null
	if grid == null or cells <= 0.0 or dir.length() <= 0.0:
		return 0
	var start: Vector2i = grid.world_to_cell(e.net_position)
	var cur: Vector2i = start
	var d2 := Vector2(dir.x, dir.z).normalized()
	var moved: int = 0
	for i: int in range(1, roundi(cells) + 1):
		var want: Vector2i = start + Vector2i(roundi(d2.x * i), roundi(d2.y * i))
		var step := Vector2i(clampi(want.x - cur.x, -1, 1), clampi(want.y - cur.y, -1, 1))
		if step == Vector2i.ZERO:
			continue
		if not grid.can_step(cur, step):
			break
		cur += step
		moved += 1
	if moved > 0:
		mover.place(grid.cell_to_world(cur))
	return moved


## Só testes (ProgressionDebug).
func reset_cooldowns(peer_id: int) -> void:
	_cooldowns.erase(peer_id)
	_cooldown_totals.erase(peer_id)
