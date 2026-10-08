class_name CombatService
extends RefCounted
## Combate no servidor (contrato arrival, "Combate (K)"; GDD §6.4, §10, §12). world.combat.
##
## - Ataque básico: NetCombat.send_attack(id) -> anda até o alcance e ataca em ciclo pela velocidade
##   de ataque (GDD §10.1/§10.2) até o alvo morrer ou chegar outra ordem (andar, NPC, parar).
## - Pipeline único de dano: apply_damage() (ataque básico, monstros e skills de Q).
## - Vida e mana dos jogadores: CharacterData.hp/mp (replicação privada via PlayerSession) +
##   NetEntity.hp_ratio para todos; regeneração do GDD §6.4.
## - Monstros: MonsterSpawner (Spawns/ do mapa), MonsterBrain (IA), MonsterEvolution (§10.6).
## - Drops no chão: DropService. Pegar: NetCombat.send_pickup(id) ou req_interact("d:<id>").
## - Morte do jogador: emite player_killed; N (world.zone_rules) renasce. Sem N, K renasce no
##   SpawnPoint depois de CombatRules.FALLBACK_RESPAWN_DELAY_SEC.
## Sinais iguais aos do CombatEvents.bus() (os dois são emitidos). Interface K→Q/N: ver
## docs/contracts-arrival.md, "Apêndice K".

signal monster_killed(killer_peer: int, monster_id: StringName, stage: int, xp: int)
signal player_killed(victim_peer: int, killer_entity: int)
signal player_revived(peer: int)
## Mesmo abate de monster_killed, com os detalhes (ver kill_info / CombatEvents.monster_killed_info).
signal monster_killed_info(killer_peer: int, monster_id: StringName, info: Dictionary)

const KIND_PHYSICAL: StringName = &"physical"
const KIND_MAGIC: StringName = &"magic"
const KIND_TRUE: StringName = &"true"
const SOURCE_BASIC_ATTACK: StringName = &"basic_attack"
const ANIM_DEATH: StringName = &"death"
const PREFIX_ENTITY: String = "e:"
const PREFIX_DROP: String = "d:"
## Tentativas de refazer o caminho até um item que não se alcança.
const MAX_PICKUP_REPATHS: int = 3
## Mensagens (localization/strings.csv).
const MSG_NO_COMBAT: String = "SYS_NO_COMBAT_HERE"
const MSG_DEAD: String = "SYS_YOU_ARE_DEAD"
const MSG_TOO_FAR: String = "SYS_TOO_FAR"
const MSG_INVENTORY_FULL: String = "SYS_INVENTORY_FULL"
const MSG_TARGET_INVALID: String = "SYS_TARGET_INVALID"
const MSG_NOT_YOURS: String = "SYS_DROP_NOT_YOURS"
## Monstro da provação de outro jogador (localization/party.csv).
const MSG_TRIAL_NOT_YOURS: String = "SYS_TRIAL_NOT_YOURS"
const MSG_NO_AMMO: String = "SYS_NO_AMMO"
## A pilha de flechas acabou e a próxima do mesmo tipo entrou sozinha: [item, quantidade].
const MSG_AMMO_REFILLED: String = "SYS_AMMO_REFILLED"
const BOSS_WEAPON_DROP_ID: StringName = &"boss_gale_blade"
const ATROZ_WEAPON_DROP_ID: StringName = &"atroz_soul_staff"
const BOSS_WEAPON_DROP_CHANCE: float = 0.02
const ATROZ_WEAPON_DROP_CHANCE: float = 0.05
## Q: vida de uma muda protegida ("%s: %d/%d de vida").
const MSG_PROTECTED_HP: String = "PROG_MSG_PROTECTED_HP"
## Surrupiar: motivos de recusa/falha (CombatService.steal; o SkillCaster traduz em mensagem).
const STEAL_INVALID: String = "steal_target_invalid"
const STEAL_BOSS: String = "steal_boss"
const STEAL_TRIAL: String = "steal_trial"
const STEAL_ALREADY: String = "steal_already"
const STEAL_NOTHING: String = "steal_nothing"
const STEAL_FAILED: String = "steal_failed"
const STEAL_INVENTORY_FULL: String = "steal_inventory_full"
## Testes (Agente R): --always-hit = golpes físicos sempre acertam (menos no alvo "esquivo").
const ARG_ALWAYS_HIT: String = "always-hit"


## Estado de combate de um jogador (só memória).
class PlayerCombat:
	var target: NetEntity = null
	var next_attack_msec: int = 0
	var next_repath_msec: int = 0
	var last_target_cell: Vector2i = Vector2i(-1, -1)
	## Último dano causado ou recebido (regra dos 6 s, GDD §6.4).
	var last_combat_msec: int = -1000000
	var dead: bool = false
	var respawn_at_msec: int = 0
	var hp_acc: float = 0.0
	var mp_acc: float = 0.0
	var pickup_id: int = 0
	var pickup_repaths: int = 0


var world: ServerWorld = null
var spawner: MonsterSpawner = null
var drops: DropService = null
## Dados de teste (--combat-fixtures): tests/combat/fixtures/combat_fixtures.gd.
var fixtures: Script = null
var _players: Dictionary[int, PlayerCombat] = {}
## entity_id -> monstro (vivo ou morrendo).
var _monsters: Dictionary[int, NetEntity] = {}
## Corpos esperando a animação de morte: entity_id -> msec em que somem.
var _dying: Dictionary[int, int] = {}
var _rng := RandomNumberGenerator.new()
## Detalhes do abate sendo avisado agora (válido durante a emissão de monster_killed; ver kill_info()).
var last_kill: Dictionary = {}


func _init(p_world: ServerWorld) -> void:
	world = p_world
	_rng.randomize()
	spawner = MonsterSpawner.new(self)
	drops = DropService.new(p_world)
	NetCombat.attack_intent.connect(_on_attack_intent)
	NetCombat.stop_attack_intent.connect(_on_stop_attack_intent)
	NetCombat.pickup_intent.connect(_on_pickup_intent)
	if NetCombat.has_arg(ARG_ALWAYS_HIT):
		DamageFormula.test_force_hit = true # só testes: acerto garantido (ver DamageFormula)
	if NetCombat.has_arg(NetCombat.ARG_COMBAT_FIXTURES) and ResourceLoader.exists(NetCombat.FIXTURES_SCRIPT):
		fixtures = load(NetCombat.FIXTURES_SCRIPT) as Script


static func special_weapon_drop(stage: int, atroz: bool) -> Dictionary:
	if atroz:
		return {"item": ATROZ_WEAPON_DROP_ID, "chance": ATROZ_WEAPON_DROP_CHANCE}
	if stage >= CombatRules.STAGE_BOSS:
		return {"item": BOSS_WEAPON_DROP_ID, "chance": BOSS_WEAPON_DROP_CHANCE}
	return {}


# ================================================================ API (Interface K→Q / K→N)

## Pipeline de dano (Q chama para skills). kind: &"physical" | &"magic" | &"true" (sem fórmula:
## multiplier = dano fixo). multiplier: ×ATK/MATK (1.5 = 150%). source_id: skill ou &"basic_attack".
## Aplica fórmula §10.2 (defesa, ±10%, crítico só físico), escudos/DEF de Q, aggro, morte, números
## de dano (clientes da instância). Devolve o dano causado (0 = inválido/não acertou).
func apply_damage(attacker: NetEntity, target: NetEntity, kind: StringName = KIND_PHYSICAL,
		multiplier: float = 1.0, source_id: StringName = SOURCE_BASIC_ATTACK) -> int:
	return int(deal_damage(attacker, target, kind, multiplier, source_id).get("amount", 0))


## Igual a apply_damage, com o resultado completo:
## {"ok": bool, "reason": String, "amount": int, "crit": bool, "killed": bool[, "miss": true]}.
## Físico pode errar (GDD §10.2: acerto por DES): ok = true, amount = 0, miss = true.
func deal_damage(attacker: NetEntity, target: NetEntity, kind: StringName, multiplier: float,
		source_id: StringName) -> Dictionary:
	var why: String = attack_block_reason(attacker, target)
	if not why.is_empty():
		return {"ok": false, "reason": why, "amount": 0, "crit": false, "killed": false}
	var atk: Dictionary = get_combat_stats(attacker).duplicate()
	var dfn: Dictionary = get_combat_stats(target).duplicate()
	var def_mult: float = CombatBridges.def_multiplier(world, target)
	dfn[&"def"] = roundi(float(dfn.get(&"def", 0)) * def_mult)
	dfn[&"mdef"] = roundi(float(dfn.get(&"mdef", 0)) * def_mult)
	# Q (Terra do Sabiá v0.4): reforços/enfraquecimentos, contragolpe, esquiva, crítico garantido.
	var mods: Dictionary = CombatBridges.pre_hit(world, attacker, target, kind, source_id, atk, dfn)
	if world.companions != null:
		world.companions.pre_hit(attacker, source_id, mods, atk, dfn)
	if bool(mods.get("countered", false)) or bool(mods.get("force_miss", false)):
		return _miss(attacker, target, kind, source_id)
	var dtype: int = damage_type_of(kind)
	var sdef: SkillDef = Content.skill(source_id)
	var attacker_session: PlayerSession = world.get_session(attacker.get_peer_id()) if attacker.is_player() else null
	var is_holy_attack: bool = false
	if sdef != null and (sdef.is_holy_or_light() or sdef.school in [&"support", &"holy", &"shamanic"]):
		is_holy_attack = true
	if not is_holy_attack and attacker_session != null and attacker_session.character != null and attacker_session.character.progression != null:
		if TitleDef.is_holy_title_id(attacker_session.character.progression.displayed_title):
			is_holy_attack = true
	if is_holy_attack and dtype == CombatRules.DamageType.MAGIC:
		if atk.has(CharacterStats.K_HOLY_MATK):
			atk[&"matk"] = atk[CharacterStats.K_HOLY_MATK]
	# Folclore do 1º arco: armas de prata (+10%) e magias de luz/sagrado (+20%) contra lobisomens e mortos-vivos.
	var folklore_mult: float = 1.0
	var target_brain: MonsterBrain = get_brain(target) if target.is_monster() else null
	var target_def: MonsterDef = target_brain.def if target_brain != null else null
	if target_def != null:
		if target_def.is_vulnerable_to_silver() and attacker_session != null:
			if attacker_session.character != null and attacker_session.character.equipment != null:
				if attacker_session.character.equipment.has_silver_equipped():
					folklore_mult *= CombatRules.SILVER_BONUS_MULTIPLIER
		if target_def.is_vulnerable_to_holy():
			var holy_src: bool = sdef != null and sdef.is_holy_or_light()
			if not holy_src and attacker_session != null and attacker_session.character != null and attacker_session.character.progression != null:
				holy_src = TitleDef.is_holy_title_id(attacker_session.character.progression.displayed_title)
			if holy_src:
				folklore_mult *= CombatRules.HOLY_LIGHT_BONUS_MULTIPLIER
	if folklore_mult != 1.0:
		mods["dmg_mult"] = float(mods.get("dmg_mult", 1.0)) * folklore_mult

	# Contexto e Efeitos de Crendices Folclóricas (GDD §11)
	var map_id: StringName = world.get_instance_map_id(attacker.instance_id) if world != null else &""
	var is_night: bool = DayNight.is_night_on_map(map_id) if DayNight != null else false
	var in_forest: bool = String(map_id).begins_with("enchanted_forest") or String(map_id).begins_with("fields_sabia")
	var target_session: PlayerSession = world.get_session(target.get_peer_id()) if target.is_player() else null

	# Defensor: Crendices (ex: Moeda Furada, Figa de Madeira, Saquinho de Sal Grosso, Olho do Titã)
	if target_session != null and target_session.character != null and target_session.character.equipment != null:
		var def_ctx: Dictionary = {
			"hp_ratio": target.hp_ratio,
			"is_night": is_night,
			"in_forest": in_forest,
			"enemy_struck_first": true
		}
		var def_crendice: Dictionary = target_session.character.equipment.calc_crendice_bonuses(def_ctx)
		var def_sp: Dictionary = def_crendice.get("special", {})
		if bool(def_sp.get("first_strike_flee", false)):
			var pc: PlayerCombat = _players.get(target_session.peer_id)
			if pc != null and not pc.in_combat:
				return _miss(attacker, target, kind, source_id)
		if dtype == CombatRules.DamageType.MAGIC and def_sp.has("shadow_resist_pct"):
			var res_pct: float = float(def_sp["shadow_resist_pct"]) / 100.0
			mods["dmg_mult"] = float(mods.get("dmg_mult", 1.0)) * maxf(0.1, 1.0 - res_pct)
		if def_sp.has("all_def_pct"):
			var def_pct: float = float(def_sp["all_def_pct"]) / 100.0
			dfn[&"def"] = roundi(float(dfn.get(&"def", 0)) * (1.0 + def_pct))
			dfn[&"mdef"] = roundi(float(dfn.get(&"mdef", 0)) * (1.0 + def_pct))

	# Atacante: Crendices (ex: Dente de Onça, Dente de Cascavel, Pedra de Raio, etc.)
	var atk_sp: Dictionary = {}
	if attacker_session != null and attacker_session.character != null and attacker_session.character.equipment != null:
		var max_mp: int = int(attacker_session.character.compute_stats().get("max_mp", 100))
		var atk_ctx: Dictionary = {
			"hp_ratio": attacker.hp_ratio,
			"mp_ratio": float(attacker_session.character.mp) / maxf(1.0, float(max_mp)),
			"is_night": is_night,
			"in_forest": in_forest,
			"no_shield": attacker_session.character.equipment.get_slot(Equipment.OFFHAND) == null
		}
		var atk_crendice: Dictionary = attacker_session.character.equipment.calc_crendice_bonuses(atk_ctx)
		atk_sp = atk_crendice.get("special", {})
		if atk_sp.has("crit_chance_pct"):
			atk[&"luk"] = atk.get(&"luk", 0) + int(atk_sp["crit_chance_pct"]) * 3
		if atk_sp.has("phys_dmg_pct") and dtype == CombatRules.DamageType.PHYSICAL:
			mods["dmg_mult"] = float(mods.get("dmg_mult", 1.0)) * (1.0 + float(atk_sp["phys_dmg_pct"]) / 100.0)
		if atk_sp.has("magic_dmg_pct") and dtype == CombatRules.DamageType.MAGIC:
			mods["dmg_mult"] = float(mods.get("dmg_mult", 1.0)) * (1.0 + float(atk_sp["magic_dmg_pct"]) / 100.0)
		if atk_sp.has("ignore_def_pct"):
			var ign: float = clampf(float(atk_sp["ignore_def_pct"]) / 100.0, 0.0, 1.0)
			dfn[&"def"] = roundi(float(dfn.get(&"def", 0)) * (1.0 - ign))

	var roll: Dictionary
	if dtype == CombatRules.DamageType.TRUE:
		roll = {"amount": maxi(CombatRules.MIN_DAMAGE, roundi(multiplier)), "crit": false}
	else:
		var crit_override: float = CombatRules.MONSTER_CRIT_CHANCE if attacker.is_monster() \
				else float(mods.get("crit_override", -1.0))
		roll = DamageFormula.compute(atk, dfn, multiplier, dtype, _rng, crit_override)
	if bool(roll.get("miss", false)):
		return _miss(attacker, target, kind, source_id)
	var taken: int = maxi(CombatRules.MIN_DAMAGE, roundi(float(roll["amount"]) * float(mods.get("dmg_mult", 1.0))))
	var amount: int = CombatBridges.absorb_damage(world, target, taken)
	var killed: bool = _apply_hp_loss(attacker, target, amount)
	if world.mounts != null and target.is_player():
		var victim: PlayerSession = world.get_session(target.get_peer_id())
		if victim != null:
			world.mounts.dismount(victim, amount > 0)
			if world.companions != null:
				world.companions.cancel(victim)
			if amount > 0:
				world.progression.quests.interrupt_wait(victim.peer_id)
			world.refresh_appearance(victim)
	_mark_combat_entity(attacker)
	_mark_combat_entity(target)
	var ratio: float = target.hp_ratio
	NetCombat.push_hit(Net.get_instance_peer_ids(target.instance_id), attacker.entity_id,
			target.entity_id, amount, bool(roll["crit"]), dtype, ratio)
	Net.log_line("combat_hit", {"src": attacker.entity_id, "dst": target.entity_id, "amount": amount,
			"crit": roll["crit"], "kind": String(kind), "source": String(source_id),
			"hp_ratio": snappedf(ratio, 0.001)})
	CombatEvents.bus().damage_applied.emit(attacker.entity_id, target.entity_id, amount,
			bool(roll["crit"]), dtype)

	# Efeitos pós-golpe de Crendice (Life Steal, Veneno, Escudo de Dano)
	if attacker_session != null and amount > 0 and not String(source_id).begins_with(CompanionService.SOURCE_PREFIX):
		if atk_sp.has("life_steal_pct"):
			var steal: int = roundi(float(amount) * float(atk_sp["life_steal_pct"]) / 100.0)
			if steal > 0:
				heal(attacker, steal, attacker)
		if atk_sp.has("poison_chance_pct") and _rng.randf() < float(atk_sp["poison_chance_pct"]) / 100.0:
			CombatBridges.apply_poison(world, attacker, target, 4.0, 5)
		if atk_sp.has("damage_to_shield_pct"):
			var sh: int = roundi(float(amount) * float(atk_sp["damage_to_shield_pct"]) / 100.0)
			if sh > 0:
				CombatBridges.add_shield(world, attacker, sh, 5.0)

	if killed:
		if target.is_monster():
			var b: MonsterBrain = get_brain(target)
			if b != null:
				b.last_hit_was_crit = bool(roll["crit"])
			_kill_monster(b, attacker, bool(roll["crit"]))
		else:
			_kill_player(world.get_session(target.get_peer_id()), attacker)
	if not String(source_id).begins_with(CompanionService.SOURCE_PREFIX):
		CombatBridges.post_hit(world, attacker, target, kind, source_id, amount)
	if world.companions != null and not killed:
		world.companions.on_hit(attacker, target, source_id, amount)
	return {"ok": true, "reason": "", "amount": amount, "crit": roll["crit"], "killed": killed}



## Agente R (GDD §10.2): golpe físico errado (esquiva pela DES). Não tira vida, mas conta como
## combate e provoca o monstro; os clientes mostram "Errou" (NetCombat.MISS_AMOUNT).
func _miss(attacker: NetEntity, target: NetEntity, kind: StringName, source_id: StringName) -> Dictionary:
	_mark_combat_entity(attacker)
	_mark_combat_entity(target)
	if target.is_monster():
		var b: MonsterBrain = get_brain(target)
		if b != null:
			b.on_damaged(attacker)
	NetCombat.push_hit(Net.get_instance_peer_ids(target.instance_id), attacker.entity_id,
			target.entity_id, NetCombat.MISS_AMOUNT, false, damage_type_of(kind), target.hp_ratio)
	Net.log_line("combat_miss", {"src": attacker.entity_id, "dst": target.entity_id,
			"kind": String(kind), "source": String(source_id)})
	return {"ok": true, "reason": "", "amount": 0, "crit": false, "killed": false, "miss": true}


## Cura (skills/poções de Q). source = quem curou (null = sem fonte). A cura recebida passa pelo
## multiplicador de Q (Fumaça Amarga) e vai para a instância (NetCombat.healed). Devolve quanto curou.
func heal(target: NetEntity, amount: int, source: NetEntity = null) -> int:
	if target == null or amount <= 0 or is_entity_dead(target):
		return 0
	amount = roundi(float(amount) * CombatBridges.heal_multiplier(world, target))
	if amount <= 0:
		return 0
	var healed: int = 0
	if target.is_monster():
		var b: MonsterBrain = get_brain(target)
		var before: int = b.hp
		b.hp = mini(b.max_hp(), b.hp + amount)
		b.apply_to_entity()
		healed = b.hp - before
	else:
		var s: PlayerSession = world.get_session(target.get_peer_id())
		if s == null:
			return 0
		var max_hp: int = s.character.compute_stats()[CharacterStats.K_MAX_HP]
		var before_hp: int = s.character.hp
		s.character.hp = mini(max_hp, s.character.hp + amount)
		_sync_player(s)
		healed = s.character.hp - before_hp
	if healed > 0:
		var src_id: int = source.entity_id if source != null and is_instance_valid(source) else 0
		NetCombat.push_healed(Net.get_instance_peer_ids(target.instance_id), src_id, target.entity_id, healed)
		Net.log_line("combat_heal", {"src": src_id, "dst": target.entity_id, "amount": healed})
	return healed


## Q: attacker pode causar dano em target? (mesma instância, vivos, hostis, zona com combate)
func can_attack(attacker: NetEntity, target: NetEntity) -> bool:
	return attack_block_reason(attacker, target).is_empty()


## "" = pode; senão o motivo (para log).
func attack_block_reason(attacker: NetEntity, target: NetEntity) -> String:
	if attacker == null or target == null or not is_instance_valid(attacker) \
			or not is_instance_valid(target) or target.is_queued_for_deletion():
		return "attack_target_invalid"
	if attacker == target:
		return "attack_self"
	if attacker.instance_id != target.instance_id:
		return "attack_other_instance"
	if not (target.is_monster() or target.is_player()) or not (attacker.is_monster() or attacker.is_player()):
		return "attack_target_not_attackable"
	# Q (provação da Vó Aninha): muda protegida é aliada do jogador e alvo dos monstros.
	var protected: bool = CombatBridges.is_protected(world, target)
	if protected and attacker.is_player():
		return "attack_target_protected"
	if attacker.is_player() == target.is_player() and not (protected and attacker.is_monster()):
		return "attack_not_hostile" # sem PVP neste marco; monstros não se atacam
	for p: NetEntity in [attacker, target]:
		if p.is_player() and world.get_session(p.get_peer_id()) == null:
			return "attack_target_invalid" # entidade de jogador sem sessão (ex.: fantasma do autoteste)
	# Provação (mapas compartilhados, 30/09/2026): monstro com dono só luta com o dono e o grupo dele.
	if not _owner_allows(attacker, target) or not _owner_allows(target, attacker):
		return "attack_not_owner"
	if is_entity_dead(attacker):
		return "attack_while_dead"
	if is_entity_dead(target):
		return "attack_target_dead"
	if not CombatBridges.combat_allowed(world, target.instance_id):
		return "attack_zone_no_combat"
	if attacker.is_player():
		var s: PlayerSession = world.get_session(attacker.get_peer_id())
		if s != null and s.character != null and s.character.equipment != null:
			var w: ItemStack = s.character.equipment.get_slot(Equipment.WEAPON)
			var wdef: ItemDef = w.get_def() if w != null else null
			if wdef != null and wdef.is_projectile_weapon() and not s.character.equipment.has_ammo_equipped():
				return "attack_no_ammo"
	return ""


## monster (se for monstro de provação) aceita lutar com other? Só o dono e o grupo dele.
func _owner_allows(monster: NetEntity, other: NetEntity) -> bool:
	if not monster.is_monster() or not other.is_player():
		return true
	var b: MonsterBrain = get_brain(monster)
	if b == null or b.owner_peer == 0:
		return true
	var peer: int = other.get_peer_id()
	return peer == b.owner_peer or (world.party != null and world.party.same_party(peer, b.owner_peer))


## Regra dos 6 s (GDD §6.4). Q: a barra de skills só muda fora de combate.
func is_in_combat(peer_id: int) -> bool:
	var pc: PlayerCombat = _players.get(peer_id)
	return pc != null and Time.get_ticks_msec() - pc.last_combat_msec \
			< int(Balance.cfg.out_of_combat_sec * CombatRules.MSEC_PER_SEC)


## Marca o jogador como "em combate" agora (ex.: lançou uma skill ofensiva).
func mark_combat(peer_id: int) -> void:
	var pc: PlayerCombat = _players.get(peer_id)
	if pc != null:
		pc.last_combat_msec = Time.get_ticks_msec()


func is_dead(peer_id: int) -> bool:
	var pc: PlayerCombat = _players.get(peer_id)
	return pc != null and pc.dead


func is_entity_dead(e: NetEntity) -> bool:
	if e == null or not is_instance_valid(e):
		return true
	if e.is_monster():
		var b: MonsterBrain = get_brain(e)
		return b == null or b.is_dead()
	if e.is_player():
		return is_dead(e.get_peer_id())
	return false


## N (ou o padrão de K): o jogador morto volta à vida em position (Vector3.INF = onde está) com
## hp_fraction da vida máxima. N também pode só pôr hp > 0 e mover: K detecta no tick seguinte.
func revive(peer_id: int, position: Vector3 = Vector3.INF, hp_fraction: float = 1.0) -> void:
	var s: PlayerSession = world.get_session(peer_id)
	var pc: PlayerCombat = _players.get(peer_id)
	if s == null or pc == null:
		return
	if position != Vector3.INF:
		s.entity.get_mover().place(world.snap_to_grid(s.entity.instance_id, position))
	var max_hp: int = s.character.compute_stats()[CharacterStats.K_MAX_HP]
	s.character.hp = maxi(1, roundi(float(max_hp) * hp_fraction))
	_on_revived(s, pc)


## Atributos de combate de uma entidade: atk, matk, def, mdef, dex, level.
func get_combat_stats(e: NetEntity) -> Dictionary:
	if e == null:
		return {}
	if e.is_monster():
		var b: MonsterBrain = get_brain(e)
		return b.combat_stats() if b != null else {}
	var s: PlayerSession = world.get_session(e.get_peer_id())
	return s.character.compute_stats() if s != null else {}


func get_brain(e: NetEntity) -> MonsterBrain:
	if e == null or not is_instance_valid(e):
		return null
	return e.get_node_or_null(MonsterBrain.NODE_NAME) as MonsterBrain


## Monstros vivos da instância a até radius (m) de center (skills de área de Q).
func monsters_in_radius(instance_id: StringName, center: Vector3, radius: float) -> Array[NetEntity]:
	var out: Array[NetEntity] = []
	for e: NetEntity in _monsters.values():
		if is_instance_valid(e) and e.instance_id == instance_id and not is_entity_dead(e) \
				and e.flat_distance_to(center) <= radius:
			out.append(e)
	return out


## Q (provação) e testes: cria um monstro (estágio 1) que não renasce. owner_peer != 0 = monstro da
## provação desse jogador: só ele (e o grupo dele) luta com o monstro, mesmo no mapa compartilhado.
func spawn_monster(instance_id: StringName, monster_id: StringName, pos: Vector3,
		owner_peer: int = 0, stage_number: int = 1) -> NetEntity:
	var def: MonsterDef = Content.monster(monster_id)
	if def == null or def.stages.is_empty():
		Net.log_line("monster_def_missing", {"monster": String(monster_id), "owner": owner_peer})
		return null
	var stage: MonsterStage = MonsterEvolution.stage_by_number(def, stage_number)
	if stage == null:
		stage = def.stages[0]
	var e: NetEntity = spawner.spawn(instance_id, def, stage, world.snap_to_grid(instance_id, pos),
			CombatRules.DEFAULT_ROAM_CELLS)
	var b: MonsterBrain = get_brain(e)
	if b != null and owner_peer != 0:
		b.owner_peer = owner_peer
		Net.log_line("monster_owned", {"id": e.entity_id, "monster": String(monster_id), "owner": owner_peer})
	return e


# ================================================================ ganchos do ServerWorld

func on_player_spawned(session: PlayerSession) -> void:
	var pc := PlayerCombat.new()
	_players[session.peer_id] = pc
	if session.character.hp <= 0:
		# Save de alguém que saiu morto: volta com a vida cheia.
		session.character.hp = session.character.compute_stats()[CharacterStats.K_MAX_HP]
	if fixtures != null:
		fixtures.call("prepare_player", session)
	_sync_player(session)


func on_player_left(session: PlayerSession) -> void:
	_players.erase(session.peer_id)
	_release_player_target(session.entity)


## Movimento no chão: cancela ataque e coleta pendentes.
func on_player_moved(session: PlayerSession) -> void:
	cancel_attack(session)
	_cancel_pickup(session)


## false = recusado (morto). Log com o nome da intenção.
func allow_player_action(session: PlayerSession, intent: String) -> bool:
	if not is_dead(session.peer_id):
		return true
	Net.log_invalid(session.peer_id, "action_while_dead", {"intent": intent})
	Net.push_system_message(session.peer_id, MSG_DEAD)
	return false


## req_interact em monstro ("e:<id>") -> ataque; item no chão ("e:<id>" ou "d:<id>") -> pegar.
## true = tratado aqui. Interagir com outra coisa (NPC, objeto) cancela o ataque e devolve false.
func handle_interact(session: PlayerSession, target_id: String) -> bool:
	var id: int = -1
	var raw: String = ""
	if target_id.begins_with(PREFIX_DROP):
		raw = target_id.trim_prefix(PREFIX_DROP)
		if raw.is_valid_int():
			request_pickup(session, raw.to_int())
			return true
	if target_id.begins_with(PREFIX_ENTITY):
		raw = target_id.trim_prefix(PREFIX_ENTITY)
		id = raw.to_int() if raw.is_valid_int() else -1
	var e: NetEntity = world.get_entity(id) if id >= 0 else null
	if e != null and e.is_monster():
		request_attack(session, id)
		return true
	if e != null and e.is_drop():
		request_pickup(session, id)
		return true
	cancel_attack(session)
	_cancel_pickup(session)
	return false


# ================================================================ ataque básico do jogador

func request_attack(session: PlayerSession, entity_id: int) -> void:
	var pc: PlayerCombat = _players.get(session.peer_id)
	if pc == null or not allow_player_action(session, "attack"):
		return
	var target: NetEntity = world.get_entity(entity_id)
	if target != null and CombatBridges.is_protected(world, target):
		_inspect_protected(session, target)
		return
	var why: String = attack_block_reason(session.entity, target)
	if why.is_empty() and session.entity.flat_distance_to(target.net_position) \
			> CombatRules.ATTACK_MAX_ENGAGE_CELLS * _cell_size(session.entity):
		why = "attack_out_of_range"
	if not why.is_empty():
		Net.log_invalid(session.peer_id, why, {"target": entity_id,
				"instance": String(session.entity.instance_id)})
		var key: String = MSG_NO_COMBAT if why == "attack_zone_no_combat" \
				else (MSG_TOO_FAR if why == "attack_out_of_range" \
				else (MSG_NO_AMMO if why == "attack_no_ammo" else MSG_TARGET_INVALID))
		if why == "attack_not_owner":
			key = MSG_TRIAL_NOT_YOURS
		Net.push_system_message(session.peer_id, key)
		return
	world.interaction.cancel(session)
	_cancel_pickup(session)
	world.stand_up(session)
	if world.mounts != null:
		world.mounts.dismount(session)
	if world.companions != null:
		world.companions.cancel(session)
	if pc.target != target:
		pc.target = target
		pc.next_repath_msec = 0
		pc.last_target_cell = Vector2i(-1, -1)
		session.entity.target_id = entity_id
		NetCombat.push_attack_target(session.peer_id, entity_id)
	Net.log_line("attack_started", {"peer": session.peer_id, "target": entity_id,
			"distance": snappedf(session.entity.flat_distance_to(target.net_position), 0.01)})
	_tick_player_attack(session, pc)


func cancel_attack(session: PlayerSession) -> void:
	var pc: PlayerCombat = _players.get(session.peer_id)
	if pc == null or pc.target == null:
		return
	pc.target = null
	session.entity.target_id = 0
	NetCombat.push_attack_target(session.peer_id, 0)


func _on_attack_intent(peer_id: int, entity_id: int) -> void:
	var s: PlayerSession = world.get_session(peer_id)
	if s == null:
		Net.log_invalid(peer_id, "intent_without_session")
		return
	request_attack(s, entity_id)


func _on_stop_attack_intent(peer_id: int) -> void:
	var s: PlayerSession = world.get_session(peer_id)
	if s != null:
		cancel_attack(s)


## Alcance do ataque básico (m) e tipo pela arma: Arcano = mágico à distância; resto = físico.
func basic_attack_profile(session: PlayerSession) -> Dictionary:
	var weapon: ItemStack = session.character.equipment.get_slot(&"weapon")
	var def: ItemDef = weapon.get_def() if weapon != null else null
	var cell: float = _cell_size(session.entity)
	var bonus: float = CombatBridges.range_bonus_cells(world, session.entity)
	if def != null and def.weapon_kind == ItemDef.WeaponKind.ARCANE:
		return {"kind": KIND_MAGIC, "range": (CombatRules.BASIC_RANGED_RANGE_CELLS + bonus) * cell}
	if def != null and def.weapon_kind == ItemDef.WeaponKind.BOW:
		return {"kind": KIND_PHYSICAL, "range": (CombatRules.BASIC_BOW_RANGE_CELLS + bonus) * cell}
	return {"kind": KIND_PHYSICAL, "range": CombatRules.BASIC_MELEE_RANGE_CELLS * cell}


func _tick_player_attack(session: PlayerSession, pc: PlayerCombat) -> void:
	var target: NetEntity = pc.target
	var why: String = attack_block_reason(session.entity, target)
	if not why.is_empty():
		if why == "attack_no_ammo":
			Net.push_system_message(session.peer_id, MSG_NO_AMMO)
		cancel_attack(session)
		return
	var profile: Dictionary = basic_attack_profile(session)
	var reach: float = profile["range"]
	var mover: GridMover = session.entity.get_mover()
	var dist: float = session.entity.flat_distance_to(target.net_position)
	var slack: float = CombatRules.RANGE_SLACK_CELLS * _cell_size(session.entity) if not mover.is_moving() else 0.0
	if dist > reach + slack:
		var now_r: int = Time.get_ticks_msec()
		var cell: Vector2i = mover.grid.world_to_cell(target.net_position) if mover.grid != null else Vector2i.ZERO
		if (not mover.is_moving() or cell != pc.last_target_cell) and now_r >= pc.next_repath_msec:
			pc.next_repath_msec = now_r + CombatRules.REPATH_INTERVAL_MSEC
			pc.last_target_cell = cell
			if not mover.move_to(target.net_position, reach) and not mover.is_moving() \
					and dist > reach + CombatRules.CHASE_WAIT_CELLS * _cell_size(session.entity):
				Net.log_invalid(session.peer_id, "attack_unreachable", {"target": target.entity_id})
				Net.push_system_message(session.peer_id, MSG_TOO_FAR)
				cancel_attack(session)
		return
	if mover.is_moving():
		mover.stop()
	session.entity.face_towards(target.net_position)
	var now: int = Time.get_ticks_msec()
	if now < pc.next_attack_msec:
		return
	var dex: int = int(get_combat_stats(session.entity).get(&"dex", 0))
	pc.next_attack_msec = now + DamageFormula.attack_interval_msec(dex)
	var weapon: ItemStack = session.character.equipment.get_slot(Equipment.WEAPON)
	var wdef: ItemDef = weapon.get_def() if weapon != null else null
	if wdef != null and wdef.is_projectile_weapon():
		if not session.character.consume_ammo(1):
			Net.push_system_message(session.peer_id, MSG_NO_AMMO)
			cancel_attack(session)
			return
		tell_ammo_refill(session)
		_sync_player(session)
	deal_damage(session.entity, target, profile["kind"], 1.0, SOURCE_BASIC_ATTACK)


func _release_player_target(player: NetEntity) -> void:
	for m: NetEntity in _monsters.values():
		if is_instance_valid(m):
			var b: MonsterBrain = get_brain(m)
			if b != null:
				b.drop_target(player)


# ================================================================ itens no chão

func request_pickup(session: PlayerSession, entity_id: int) -> void:
	var pc: PlayerCombat = _players.get(session.peer_id)
	if pc == null or not allow_player_action(session, "pickup"):
		return
	var why: String = drops.check_pickup(session, entity_id)
	if not why.is_empty():
		_reject_pickup(session, entity_id, why)
		return
	cancel_attack(session)
	world.interaction.cancel(session)
	pc.pickup_id = entity_id
	pc.pickup_repaths = 0
	_tick_pickup(session, pc)


func _on_pickup_intent(peer_id: int, entity_id: int) -> void:
	var s: PlayerSession = world.get_session(peer_id)
	if s == null:
		Net.log_invalid(peer_id, "intent_without_session")
		return
	request_pickup(s, entity_id)


func _cancel_pickup(session: PlayerSession) -> void:
	var pc: PlayerCombat = _players.get(session.peer_id)
	if pc != null:
		pc.pickup_id = 0


func _reject_pickup(session: PlayerSession, entity_id: int, why: String) -> void:
	Net.log_invalid(session.peer_id, why, {"target": entity_id})
	var key: String = MSG_TARGET_INVALID
	match why:
		"pickup_not_owner":
			key = MSG_NOT_YOURS
		"pickup_inventory_full":
			key = MSG_INVENTORY_FULL
		"pickup_out_of_range":
			key = MSG_TOO_FAR
	Net.push_system_message(session.peer_id, key)


func _tick_pickup(session: PlayerSession, pc: PlayerCombat) -> void:
	var drop: NetEntity = drops.get_drop(pc.pickup_id)
	if drop == null:
		pc.pickup_id = 0
		return
	var mover: GridMover = session.entity.get_mover()
	if session.entity.flat_distance_to(drop.net_position) <= Balance.cfg.pickup_range:
		var id: int = pc.pickup_id
		pc.pickup_id = 0
		mover.stop()
		var item_id: StringName = drops.item_of(id)
		var qty: int = drops.qty_of(id)
		var why: String = drops.pickup(session, id)
		if not why.is_empty():
			_reject_pickup(session, id, why)
			return
		CombatEvents.bus().drop_picked.emit(session.peer_id, item_id, qty, session.entity.instance_id)
		return
	if mover.is_moving():
		return
	pc.pickup_repaths += 1
	if pc.pickup_repaths > MAX_PICKUP_REPATHS or not mover.move_to(drop.net_position, Balance.cfg.pickup_range):
		var id2: int = pc.pickup_id
		pc.pickup_id = 0
		_reject_pickup(session, id2, "pickup_out_of_range")


# ================================================================ monstros

func register_monster(e: NetEntity) -> void:
	_monsters[e.entity_id] = e


## O MonsterBrain pede um golpe no alvo (já no alcance).
func monster_attack(brain: MonsterBrain, target: NetEntity) -> void:
	if CombatBridges.is_stunned(world, brain.get_entity()):
		return
	deal_damage(brain.get_entity(), target, KIND_PHYSICAL, 1.0, SOURCE_BASIC_ATTACK)


## Alvo válido para o monstro (jogador vivo na mesma instância, zona com combate).
func is_valid_victim(brain: MonsterBrain, e: NetEntity) -> bool:
	return e != null and is_instance_valid(e) and (e.is_player() or CombatBridges.is_protected(world, e)) \
			and attack_block_reason(brain.get_entity(), e).is_empty() \
			and not CombatBridges.is_hidden(world, e)


## Agressivos: jogador vivo mais próximo a até radius (m).
func find_aggro_target(brain: MonsterBrain, radius: float) -> NetEntity:
	var me: NetEntity = brain.get_entity()
	var best: NetEntity = null
	var best_d: float = radius
	for s: PlayerSession in world.get_sessions():
		var p: NetEntity = s.entity
		if p.instance_id != me.instance_id or not is_valid_victim(brain, p):
			continue
		var d: float = me.flat_distance_to(p.net_position)
		if d <= best_d:
			best_d = d
			best = p
	return best


func _kill_monster(brain: MonsterBrain, killer: NetEntity, is_crit: bool = false) -> void:
	var e: NetEntity = brain.get_entity()
	if CombatBridges.is_protected(world, e):
		_kill_protected(brain)
		return
	brain.hp = 0
	brain.mark_dead()
	e.hp_ratio = 0.0
	e.anim = ANIM_DEATH
	# Mapas compartilhados (GDD §5, 30/09/2026): o dono do abate é quem causou mais dano (estilo Ragnarok);
	# a XP e o crédito de quest vão para ele e para o grupo dele por perto (Progression), o drop é dele e do
	# grupo por Balance.cfg.drop_owner_sec (DropService).
	var hitter_peer: int = killer.get_peer_id() if killer != null and killer.is_player() else brain.last_hitter_peer
	if hitter_peer != 0 and brain.last_hitter_peer == 0:
		brain.last_hitter_peer = hitter_peer
	var killer_peer: int = brain.top_damage_peer()
	if killer_peer == 0:
		killer_peer = hitter_peer
	var xp: int = MonsterEvolution.kill_xp(brain.stage)
	var killer_session: PlayerSession = world.get_session(killer_peer)
	var stars: int = 0
	if killer_session != null and brain.stage.stars_max > 0:
		stars = _rng.randi_range(brain.stage.stars_min, brain.stage.stars_max)
		killer_session.character.stars += stars
		killer_session.mark_dirty(PlayerSession.DIRTY_CURRENCY)
	var dropped: Array[String] = []
	# Agente R (GDD §10.2): chance × (1 + SOR de quem derrotou × 0,01); raro: chance × 2 e +1 rolagem
	# por linha, mais MonsterDef.rare_extra_drops.
	var luk: int = int(killer_session.character.compute_stats().get(&"luk", 0)) if killer_session != null else 0
	var chance_mult: float = DamageFormula.drop_luck_multiplier(luk) * spawner.test_drop_chance_mult
	if world != null and "event_drop_mult" in world and world.event_drop_mult > 1.0:
		chance_mult *= world.event_drop_mult
	var rolls: int = 1
	var table: Array[DropEntry] = brain.stage.drops.duplicate()
	if brain.rare:
		chance_mult *= Balance.cfg.rare_drop_chance_multiplier
		rolls += Balance.cfg.rare_extra_drop_rolls
		table.append_array(brain.def.rare_extra_drops)
	for entry: DropEntry in table:
		if entry == null:
			continue
		for _r: int in range(rolls):
			if _rng.randf() >= entry.chance * chance_mult:
				continue
			var qty: int = _rng.randi_range(entry.min_qty, maxi(entry.min_qty, entry.max_qty))
			var d: NetEntity = drops.spawn(e.instance_id, _drop_position(e), entry.item_id, qty, killer_peer)
			if d != null:
				dropped.append("%s x%d" % [entry.item_id, qty])
	var special_drop: Dictionary = special_weapon_drop(brain.stage.stage, brain.atroz)
	var special_item: StringName = StringName(str(special_drop.get("item", "")))
	if not special_item.is_empty() and _rng.randf() < float(special_drop["chance"]) * chance_mult:
		var weapon_drop: NetEntity = drops.spawn(e.instance_id, _drop_position(e), special_item, 1, killer_peer)
		if weapon_drop != null:
			dropped.append("%s x1" % special_item)
	# Drop de Crendices do Folclore (Sistema de Crendices com condições temáticas de superstição)
	if killer_session != null:
		var map_id: StringName = world.get_instance_map_id(e.instance_id)
		var is_night: bool = DayNight.is_night_on_map(map_id) if DayNight != null else false
		var map_str: String = String(map_id).to_lower()
		var in_forest: bool = map_str.contains("forest") or map_str.contains("floresta")
		var is_rain: bool = world.weather_service.is_raining() if ("weather_service" in world and world.weather_service != null) else false
		var kill_ctx := {
			"monster_id": brain.def.id,
			"is_boss": brain.is_boss(),
			"is_atroz": brain.atroz,
			"killer_hp_ratio": killer_session.entity.hp_ratio,
			"killer_poisoned": killer_session.character.has_status(&"poison") if killer_session.character.has_method("has_status") else false,
			"is_night": is_night,
			"is_raining": is_rain,
			"in_forest": in_forest,
			"is_crit": is_crit or brain.last_hit_was_crit,
			"killer_surprised": not brain.player_initiated,
		}
		var crendice_drops: Array[StringName] = CrendiceSystem.roll_monster_crendice_drops(kill_ctx, _rng, luk)
		for c_item: StringName in crendice_drops:
			var c_drop: NetEntity = drops.spawn(e.instance_id, _drop_position(e), c_item, 1, killer_peer)
			if c_drop != null:
				dropped.append("%s x1" % c_item)
	for s: PlayerSession in world.get_sessions():
		var pc: PlayerCombat = _players.get(s.peer_id)
		if pc != null and pc.target == e:
			cancel_attack(s)
	NetCombat.push_death(Net.get_instance_peer_ids(e.instance_id), e.entity_id)
	_dying[e.entity_id] = Time.get_ticks_msec() + int(CombatRules.MONSTER_DEATH_LINGER_SEC * CombatRules.MSEC_PER_SEC)
	if not brain.spawn_slot.is_empty():
		spawner.schedule_respawn(brain.spawn_slot)
	var info: Dictionary = kill_info(brain, killer_peer, xp)
	Net.log_line("monster_killed", {"id": e.entity_id, "monster": String(brain.def.id),
			"stage": info["stage"], "killer": killer_peer, "last_hitter": hitter_peer,
			"damage": brain.damage_by_peer, "owner": brain.owner_peer, "xp": xp,
			"stars": stars, "drops": dropped, "escort": brain.boss_entity_id != 0, "rare": brain.rare,
			"atroz": brain.atroz, "luk": luk})
	# Q lê last_kill (ou CombatEvents.bus().last_kill) dentro do monster_killed de 4 argumentos, ou liga
	# monster_killed_info (3 argumentos, com o dicionário).
	last_kill = info
	CombatEvents.bus().last_kill = info
	monster_killed.emit(killer_peer, brain.def.id, info["stage"], xp)
	CombatEvents.bus().monster_killed.emit(killer_peer, brain.def.id, info["stage"], xp)
	monster_killed_info.emit(killer_peer, brain.def.id, info)
	CombatEvents.bus().monster_killed_info.emit(killer_peer, brain.def.id, info)
	last_kill = {}
	CombatEvents.bus().last_kill = {}


## Detalhes de um abate (TITULOS-E-SKILLS §3.3: quests de chefe, chefe atroz e itens raros):
##   stage (1..3; a forma atroz conta como chefe = 3), form_stage (1..4), boss, atroz, rare, escort,
##   entity_id, instance_id, map_id, level, xp, killer_peer.
func kill_info(brain: MonsterBrain, killer_peer: int, xp: int) -> Dictionary:
	var e: NetEntity = brain.get_entity()
	return {"stage": brain.evolution_stage(), "form_stage": brain.stage.stage, "boss": brain.is_boss(),
			"atroz": brain.atroz, "rare": brain.rare, "escort": brain.boss_entity_id != 0,
			"entity_id": e.entity_id, "instance_id": e.instance_id,
			"map_id": world.get_instance_map_id(e.instance_id), "level": brain.stage.level, "xp": xp,
			"killer_peer": killer_peer, "position": e.net_position, "trial_owner": brain.owner_peer}


## Surrupiar (Q, ofício da Garra da Onça): por que não dá para surrupiar deste monstro ("" = dá).
## Chefe (normal ou atroz) e monstro de provação recusam; só uma vez por monstro; tabela vazia não tem o quê.
static func steal_block_reason(brain: MonsterBrain) -> String:
	if brain == null or brain.is_dead():
		return STEAL_INVALID
	if brain.is_boss() or brain.atroz:
		return STEAL_BOSS
	if brain.owner_peer != 0:
		return STEAL_TRIAL
	if brain.stolen_by != 0:
		return STEAL_ALREADY
	if brain.stage == null or brain.stage.drops.is_empty():
		return STEAL_NOTHING
	return ""


## Sorteia UMA linha da tabela de drop (peso = chance da linha). roll em [0, 1). null = tabela vazia.
static func steal_pick(table: Array[DropEntry], roll: float) -> DropEntry:
	var total: float = 0.0
	for entry: DropEntry in table:
		if entry != null:
			total += maxf(0.0, entry.chance)
	if total <= 0.0:
		return null
	var at: float = clampf(roll, 0.0, 0.999999) * total
	for entry: DropEntry in table:
		if entry == null:
			continue
		at -= maxf(0.0, entry.chance)
		if at < 0.0:
			return entry
	return null


## Q: tentativa de Surrupiar com a chance já calculada (skill, nível, DES e SOR). Rola uma vez a tabela do
## estágio atual do monstro (a mesma do abate) e põe 1 unidade direto na mochila. Deu certo = o monstro fica
## marcado (MonsterBrain.stolen_by). Devolve {"ok": bool, "reason": String, "item": StringName}.
func steal(thief: NetEntity, target: NetEntity, chance: float) -> Dictionary:
	var session: PlayerSession = world.get_session(thief.get_peer_id()) if thief != null and thief.is_player() else null
	var brain: MonsterBrain = get_brain(target) if target != null and target.is_monster() else null
	if session == null or brain == null or CombatBridges.is_protected(world, target):
		return {"ok": false, "reason": STEAL_INVALID, "item": &""}
	var why: String = steal_block_reason(brain)
	if why.is_empty() and not can_attack(thief, target):
		why = STEAL_INVALID
	if not why.is_empty():
		return {"ok": false, "reason": why, "item": &""}
	if _rng.randf() >= chance:
		Net.log_line("steal_failed", {"peer": session.peer_id, "monster": String(brain.def.id),
				"id": target.entity_id, "chance": snappedf(chance, 0.001)})
		return {"ok": false, "reason": STEAL_FAILED, "item": &""}
	var entry: DropEntry = steal_pick(brain.stage.drops, _rng.randf())
	if entry == null or Content.item(entry.item_id) == null:
		return {"ok": false, "reason": STEAL_NOTHING, "item": &""}
	if not session.character.inventory.can_add(entry.item_id, 1):
		return {"ok": false, "reason": STEAL_INVENTORY_FULL, "item": entry.item_id}
	# Como pegar do chão: a coleta da quest conta o que o próprio personagem obteve.
	if world.progression != null:
		world.progression.quests.on_item_looted(session, entry.item_id, 1)
	session.character.inventory.add(entry.item_id, 1)
	brain.stolen_by = session.peer_id
	Net.log_line("steal_ok", {"peer": session.peer_id, "monster": String(brain.def.id), "id": target.entity_id,
			"stage": brain.stage.stage, "item": String(entry.item_id), "chance": snappedf(chance, 0.001)})
	return {"ok": true, "reason": "", "item": entry.item_id}


## Q: clicar numa muda protegida seleciona (anel e barra de vida no cliente) e mostra a vida, sem atacar.
func _inspect_protected(session: PlayerSession, target: NetEntity) -> void:
	cancel_attack(session)
	session.entity.target_id = target.entity_id
	NetCombat.push_attack_target(session.peer_id, target.entity_id)
	var b: MonsterBrain = get_brain(target)
	if b != null:
		Net.push_system_message(session.peer_id, MSG_PROTECTED_HP, [b.stage.name_key, b.hp, b.max_hp()])


## Q: muda protegida caiu. Sem XP, drops nem contagem; o corpo murcho fica até a provação acabar.
func _kill_protected(brain: MonsterBrain) -> void:
	var e: NetEntity = brain.get_entity()
	brain.hp = 0
	brain.mark_dead()
	e.hp_ratio = 0.0
	e.anim = ANIM_DEATH
	for s: PlayerSession in world.get_sessions():
		var pc: PlayerCombat = _players.get(s.peer_id)
		if pc != null and pc.target == e:
			cancel_attack(s)
	NetCombat.push_death(Net.get_instance_peer_ids(e.instance_id), e.entity_id)
	Net.log_line("protected_killed", {"id": e.entity_id, "def": String(brain.def.id)})
	CombatBridges.protected_killed(world, e)


func _drop_position(e: NetEntity) -> Vector3:
	var grid: WalkGrid = e.get_mover().grid
	if grid == null:
		return e.net_position
	var c: Vector2i = grid.world_to_cell(e.net_position)
	var r: int = CombatRules.DROP_SCATTER_CELLS
	var off := Vector2i(_rng.randi_range(-r, r), _rng.randi_range(-r, r))
	var cell: Vector2i = c + off if grid.is_walkable(c + off) else c
	return grid.cell_to_world(cell)


# ================================================================ vida, morte e regeneração do jogador

## Tira vida; true = morreu agora.
func _apply_hp_loss(_attacker: NetEntity, target: NetEntity, amount: int) -> bool:
	if target.is_monster():
		var b: MonsterBrain = get_brain(target)
		var lost: int = mini(amount, b.hp)
		b.hp = maxi(0, b.hp - amount)
		target.hp_ratio = float(b.hp) / float(b.max_hp())
		if _attacker != null and is_instance_valid(_attacker) and _attacker.is_player():
			b.add_damage(_attacker.get_peer_id(), lost)
		b.on_damaged(_attacker)
		return b.hp == 0
	var s: PlayerSession = world.get_session(target.get_peer_id())
	amount = CombatBridges.lethal_guard(world, target, amount, s.character.hp)
	s.character.hp = maxi(0, s.character.hp - amount)
	_sync_player(s)
	return s.character.hp == 0


func _kill_player(session: PlayerSession, killer: NetEntity) -> void:
	if session == null:
		return
	var pc: PlayerCombat = _players.get(session.peer_id)
	if pc == null or pc.dead:
		return
	pc.dead = true
	pc.pickup_id = 0
	cancel_attack(session)
	world.interaction.cancel(session)
	var e: NetEntity = session.entity
	e.get_mover().halt()
	e.anim = ANIM_DEATH
	e.hp_ratio = 0.0
	_release_player_target(e)
	var killer_id: int = killer.entity_id if killer != null and is_instance_valid(killer) else 0
	NetCombat.push_death(Net.get_instance_peer_ids(e.instance_id), e.entity_id)
	Net.log_line("player_killed", {"peer": session.peer_id, "killer": killer_id,
			"instance": String(e.instance_id)})
	if not CombatBridges.respawn_is_external(world):
		pc.respawn_at_msec = Time.get_ticks_msec() + int(CombatRules.FALLBACK_RESPAWN_DELAY_SEC * CombatRules.MSEC_PER_SEC)
	if session.character != null and session.character.equipment != null:
		var adormecidos: Array[StringName] = CrendiceSystem.on_player_death(session.character.equipment)
		if not adormecidos.is_empty():
			session.character.compute_stats()
			_sync_player(session)
			session.mark_dirty(PlayerSession.DIRTY_EQUIPMENT | PlayerSession.DIRTY_STATS)
			Net.push_system_message(session.peer_id, "SYS_CRENDICE_DORMANT_DEATH")
	player_killed.emit(session.peer_id, killer_id)
	CombatEvents.bus().player_killed.emit(session.peer_id, killer_id)


func _on_revived(session: PlayerSession, pc: PlayerCombat) -> void:
	pc.dead = false
	if world.companions != null:
		world.refresh_appearance(session)
	pc.respawn_at_msec = 0
	pc.last_combat_msec = -1000000
	if session.entity.anim == ANIM_DEATH:
		session.entity.anim = NetEntity.ANIM_IDLE
	_sync_player(session)
	Net.log_line("player_revived", {"peer": session.peer_id, "hp": session.character.hp,
			"pos": str(session.entity.net_position)})
	player_revived.emit(session.peer_id)
	CombatEvents.bus().player_revived.emit(session.peer_id)


## Espelha vida/nível do personagem na entidade e marca as estatísticas para o dono.
func _sync_player(session: PlayerSession) -> void:
	var max_hp: int = maxi(1, int(session.character.compute_stats()[CharacterStats.K_MAX_HP]))
	session.entity.hp_ratio = clampf(float(session.character.hp) / float(max_hp), 0.0, 1.0)
	session.entity.level = session.character.level
	session.mark_dirty(PlayerSession.DIRTY_STATS)


func _mark_combat_entity(e: NetEntity) -> void:
	if e != null and e.is_player():
		mark_combat(e.get_peer_id())


func _tick_player(session: PlayerSession, pc: PlayerCombat, delta: float) -> void:
	var c: CharacterData = session.character
	if pc.dead:
		if c.hp > 0:
			_on_revived(session, pc) # N (ou alguém) já pôs vida: renasceu.
		elif pc.respawn_at_msec > 0 and Time.get_ticks_msec() >= pc.respawn_at_msec:
			revive(session.peer_id, world.get_spawn_point(session.entity.instance_id))
		return
	if pc.target != null:
		_tick_player_attack(session, pc)
	if pc.pickup_id != 0:
		_tick_pickup(session, pc)
	_tick_regen(session, pc, delta)
	session.entity.level = c.level


## GDD §6.4: vida só fora de combate; mana sempre.
func _tick_regen(session: PlayerSession, pc: PlayerCombat, delta: float) -> void:
	var c: CharacterData = session.character
	var st: Dictionary = c.compute_stats()
	var changed: bool = false
	if c.hp < int(st[CharacterStats.K_MAX_HP]) and not is_in_combat(session.peer_id):
		pc.hp_acc += DamageFormula.hp_regen_per_sec(int(st[&"vit"])) * delta
		var add_hp: int = floori(pc.hp_acc)
		if add_hp > 0:
			pc.hp_acc -= add_hp
			c.hp = mini(int(st[CharacterStats.K_MAX_HP]), c.hp + add_hp)
			changed = true
	else:
		pc.hp_acc = 0.0
	if c.mp < int(st[CharacterStats.K_MAX_MP]):
		pc.mp_acc += DamageFormula.mp_regen_per_sec(int(st[&"spi"])) * delta
		var add_mp: int = floori(pc.mp_acc)
		if add_mp > 0:
			pc.mp_acc -= add_mp
			c.mp = mini(int(st[CharacterStats.K_MAX_MP]), c.mp + add_mp)
			changed = true
	else:
		pc.mp_acc = 0.0
	if changed:
		_sync_player(session)


# ================================================================ tick

## Um tick do servidor, depois das rotinas de NPC e antes do movimento.
func tick(delta: float) -> void:
	spawner.tick()
	for id: int in _monsters.keys():
		var mv: Variant = _monsters[id]
		if not is_instance_valid(mv):
			_monsters.erase(id)
			continue
		var m: NetEntity = mv
		var b: MonsterBrain = get_brain(m)
		if b == null:
			continue
		var stunned: bool = CombatBridges.is_stunned(world, m)
		if stunned:
			if m.get_mover().is_moving():
				m.get_mover().halt()
			continue
		b.tick(delta)
		if CombatBridges.is_rooted(world, m) and m.get_mover().is_moving():
			m.get_mover().halt() # preso (Q): ataca, mas não anda
		var mult: float = CombatBridges.move_speed_multiplier(world, m)
		if mult != CombatBridges.NEUTRAL_MULTIPLIER:
			m.get_mover().ms_per_cell = roundi(float(m.get_mover().ms_per_cell) / mult)
	for s: PlayerSession in world.get_sessions():
		var pc: PlayerCombat = _players.get(s.peer_id)
		if pc != null:
			_tick_player(s, pc, delta)
	drops.tick()
	if not _dying.is_empty():
		var now: int = Time.get_ticks_msec()
		for id: int in _dying.keys():
			if now < _dying[id]:
				continue
			_dying.erase(id)
			var dv: Variant = _monsters.get(id)
			_monsters.erase(id)
			if is_instance_valid(dv):
				world.despawn_entity(dv as NetEntity)


# ================================================================ utilitários

static func damage_type_of(kind: StringName) -> int:
	match kind:
		KIND_MAGIC:
			return CombatRules.DamageType.MAGIC
		KIND_TRUE:
			return CombatRules.DamageType.TRUE
	return CombatRules.DamageType.PHYSICAL


func _cell_size(e: NetEntity) -> float:
	var m: GridMover = e.get_mover() if e != null else null
	return m.grid.cell_size if m != null and m.grid != null else Balance.cfg.cell_size


## Dados de teste (--combat-fixtures): marcadores Spawns/ extras no mapa da instância.
func install_test_spawns(map_node: Node, instance_id: StringName) -> void:
	if fixtures != null:
		fixtures.call("install_spawns", map_node, instance_id, world)


## Avisa (e atualiza a aparência) quando consume_ammo puxou uma pilha nova do inventário.
func tell_ammo_refill(session: PlayerSession) -> void:
	var c: CharacterData = session.character
	if c.ammo_refilled.is_empty():
		return
	var def: ItemDef = Content.item(c.ammo_refilled)
	var ammo: ItemStack = c.equipment.get_ammo()
	Net.push_system_message(session.peer_id, MSG_AMMO_REFILLED,
			[def.name_key if def != null else String(c.ammo_refilled), ammo.qty if ammo != null else 0])
	Net.log_line("ammo_refilled", {"peer": session.peer_id, "item": String(c.ammo_refilled),
			"qty": ammo.qty if ammo != null else 0})
	world.refresh_appearance(session)
