class_name CrendiceSystem
extends RefCounted
## Sistema central de Crendices e Superstições (GDD §11).
## Gerencia verificação de condições de superstição, bônus ativos,
## cálculo de sinergias, regras de drop temático e rituais no Altar.

const SUPERSTITION_LOW_HP_THRESHOLD: float = 0.30
const SUPERSTITION_HIGH_HP_THRESHOLD: float = 0.50
const SUPERSTITION_MANA_40_THRESHOLD: float = 0.40
const SUPERSTITION_MANA_20_THRESHOLD: float = 0.20


## Verifica se a condição de superstição de um amuleto está satisfeita
static func is_superstition_active(def: CrendiceDef, context: Dictionary, is_dormant: bool = false) -> bool:
	if def == null:
		return false
	if is_dormant:
		return false

	var rule: StringName = def.superstition_rule
	if rule.is_empty():
		return true

	match rule:
		&"low_hp_double":
			# Bônus base está sempre ativo; dobra quando HP < 30%
			return true

		&"no_water_or_poison":
			var in_water_mud: bool = bool(context.get("in_water_or_mud", false)) or bool(context.get("in_water", false)) or bool(context.get("in_mud", false))
			var poisoned: bool = bool(context.get("poisoned", false))
			return not in_water_mud and not poisoned

		&"night_or_forest":
			var is_night: bool = bool(context.get("is_night", false))
			var in_forest: bool = bool(context.get("in_forest", false))
			return is_night or in_forest

		&"lucky_paw_death":
			# Fica ativo até o jogador morrer (quando se torna dormant)
			return not is_dormant

		&"enemy_first_strike":
			# O monstro deve ter atacado primeiro no combate
			return bool(context.get("enemy_struck_first", true))

		&"no_curse":
			return not bool(context.get("has_curse", false))

		&"ambush_strike":
			return true

		&"mana_above_40":
			return float(context.get("mp_ratio", 1.0)) >= SUPERSTITION_MANA_40_THRESHOLD

		&"mana_above_20":
			return float(context.get("mp_ratio", 1.0)) >= SUPERSTITION_MANA_20_THRESHOLD

		&"weather_rain":
			return bool(context.get("is_raining", false))

		&"night_only":
			return bool(context.get("is_night", false))

		&"day_only":
			return not bool(context.get("is_night", false))

		&"hp_above_50":
			return float(context.get("hp_ratio", 1.0)) >= SUPERSTITION_HIGH_HP_THRESHOLD

		&"still_position", &"still_in_forest":
			return not bool(context.get("is_moving", false))

		&"moving_state":
			return bool(context.get("is_moving", false))

		&"out_of_combat_5s":
			return not bool(context.get("in_combat", false))

		&"no_shield_equipped":
			return bool(context.get("no_shield", false))

		&"no_consecutive_miss":
			return not bool(context.get("consecutive_miss", false))

		&"recharge_out_of_combat":
			return true

		&"multiple_attackers":
			return int(context.get("attackers_count", 1)) >= 2

		&"facing_attacker":
			return not bool(context.get("back_attack", false))

	return true


## Retorna os efeitos e stats ativos de um amuleto sob o contexto atual
static func get_effective_effects(def: CrendiceDef, context: Dictionary, is_dormant: bool = false) -> Dictionary:
	var out: Dictionary = {
		"active": false,
		"stats": {},
		"special": {},
		"superstition_boosted": false
	}
	if def == null or is_dormant:
		return out

	var active: bool = is_superstition_active(def, context, is_dormant)
	out["active"] = active
	if not active:
		return out

	var stats: Dictionary = def.stats.duplicate()
	var special: Dictionary = def.special_effects.duplicate()

	# Aplicação da regra da Figa: dobra se HP < 30%
	if def.superstition_rule == &"low_hp_double":
		var hp_r: float = float(context.get("hp_ratio", 1.0))
		if hp_r <= SUPERSTITION_LOW_HP_THRESHOLD:
			out["superstition_boosted"] = true
			for k in stats:
				stats[k] = stats[k] * 2
			if special.has("shadow_resist_pct"):
				special["shadow_resist_pct"] = int(special["shadow_resist_pct"]) * 2
			if special.has("curse_resist_pct"):
				special["curse_resist_pct"] = int(special["curse_resist_pct"]) * 2

	# Aplicação da regra da Pedra de Raio na Chuva
	if def.superstition_rule == &"weather_rain" and bool(context.get("is_raining", false)):
		out["superstition_boosted"] = true
		if special.has("thunder_boost_in_rain"):
			special["thunder_dmg_pct"] = int(special["thunder_boost_in_rain"])

	out["stats"] = stats
	out["special"] = special
	return out


## Calcula a soma total de atributos e efeitos de todos os amuletos equipados
static func calc_equipped_bonuses(equipment: Equipment, context: Dictionary) -> Dictionary:
	var total_stats: Dictionary[StringName, int] = {}
	var total_special: Dictionary = {}
	var active_crendice_ids: Array[StringName] = []

	if equipment == null:
		return {"stats": total_stats, "special": total_special, "synergies": []}

	for stack: ItemStack in equipment.gear_stacks():
		if stack == null or stack.crendices.is_empty():
			continue
		for i: int in stack.crendices.size():
			var cid: StringName = stack.crendices[i]
			var is_dormant: bool = stack.dormant_crendices[i] if i < stack.dormant_crendices.size() else false
			var def: CrendiceDef = CrendiceDatabase.get_crendice(cid)
			if def == null:
				continue

			var eff: Dictionary = get_effective_effects(def, context, is_dormant)
			if bool(eff.get("active", false)):
				active_crendice_ids.append(cid)
				var st: Dictionary = eff.get("stats", {})
				for k: StringName in st:
					total_stats[k] = total_stats.get(k, 0) + int(st[k])
				var sp: Dictionary = eff.get("special", {})
				for k: String in sp:
					if typeof(sp[k]) == TYPE_INT or typeof(sp[k]) == TYPE_FLOAT:
						total_special[k] = total_special.get(k, 0) + int(sp[k])
					elif typeof(sp[k]) == TYPE_BOOL and bool(sp[k]):
						total_special[k] = true

	# Avaliação de Sinergias Temáticas
	var synergies: Array[Dictionary] = get_active_synergies(active_crendice_ids)
	for syn: Dictionary in synergies:
		var b: Dictionary = syn.get("bonuses", {})
		for k: String in b:
			if typeof(b[k]) == TYPE_INT or typeof(b[k]) == TYPE_FLOAT:
				total_special[k] = total_special.get(k, 0) + int(b[k])
			elif typeof(b[k]) == TYPE_BOOL and bool(b[k]):
				total_special[k] = true

	return {
		"stats": total_stats,
		"special": total_special,
		"synergies": synergies,
		"active_crendices": active_crendice_ids
	}


## Avalia quais sinergias estão ativas a partir de uma lista de crendices ativas
static func get_active_synergies(active_ids: Array[StringName]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var syn_db: Dictionary[StringName, Dictionary] = CrendiceDatabase.get_synergies()

	for syn_id: StringName in syn_db:
		var syn_data: Dictionary = syn_db[syn_id]
		var required_count: int = int(syn_data.get("required_count", 3))
		var pool: Array = syn_data.get("crendices", [])
		var match_count: int = 0
		var found_crendices: Array[StringName] = []

		for cid: StringName in active_ids:
			if cid in pool and not (cid in found_crendices):
				match_count += 1
				found_crendices.append(cid)

		if match_count >= required_count:
			var syn_entry: Dictionary = syn_data.duplicate()
			syn_entry["id"] = syn_id
			syn_entry["matched_crendices"] = found_crendices
			out.append(syn_entry)

	return out


## Verifica se um amuleto pode dropar de um monstro abatido respeitando a condição de superstição
static func can_drop_crendice(def: CrendiceDef, kill_context: Dictionary) -> bool:
	if def == null or def.drop_rules.is_empty():
		return false

	var rules: Dictionary = def.drop_rules
	var monster_id: StringName = StringName(str(kill_context.get("monster_id", "")))
	var target_monsters: Array = rules.get("monster_ids", [])
	if not target_monsters.is_empty() and not (monster_id in target_monsters):
		return false

	if bool(rules.get("crit_kill", false)) and not bool(kill_context.get("is_crit", false)):
		return false

	if bool(rules.get("killer_low_hp", false)):
		if float(kill_context.get("killer_hp_ratio", 1.0)) >= SUPERSTITION_LOW_HP_THRESHOLD:
			return false

	if bool(rules.get("killer_high_hp", false)):
		if float(kill_context.get("killer_hp_ratio", 1.0)) < SUPERSTITION_HIGH_HP_THRESHOLD:
			return false

	if bool(rules.get("no_poison_kill", false)) and bool(kill_context.get("killer_poisoned", false)):
		return false

	if bool(rules.get("enemy_struck_first", false)) and not bool(kill_context.get("enemy_struck_first", false)):
		return false

	if bool(rules.get("night_only", false)) and not bool(kill_context.get("is_night", false)):
		return false

	if bool(rules.get("day_only", false)) and bool(kill_context.get("is_night", false)):
		return false

	if bool(rules.get("rain_only", false)) and not bool(kill_context.get("is_raining", false)):
		return false

	if bool(rules.get("atroz_only", false)) and not bool(kill_context.get("is_atroz", false)):
		return false

	if bool(rules.get("boss_only", false)) and not bool(kill_context.get("is_boss", false)):
		return false

	if bool(rules.get("atroz_or_boss", false)):
		var is_at: bool = bool(kill_context.get("is_atroz", false))
		var is_b: bool = bool(kill_context.get("is_boss", false))
		if not (is_at or is_b):
			return false

	if bool(rules.get("night_or_forest", false)):
		var is_n: bool = bool(kill_context.get("is_night", false))
		var in_f: bool = bool(kill_context.get("in_forest", false))
		if not (is_n or in_f):
			return false

	if bool(rules.get("day_or_crit", false)):
		var is_d: bool = not bool(kill_context.get("is_night", false))
		var is_c: bool = bool(kill_context.get("is_crit", false))
		if not (is_d or is_c):
			return false

	return true


## Rola possíveis drops de crendice após a morte de um monstro
static func roll_monster_crendice_drops(kill_context: Dictionary, rng: RandomNumberGenerator, luk: int = 0) -> Array[StringName]:
	var out: Array[StringName] = []
	var luck_mult: float = 1.0 + float(maxi(0, luk)) * 0.015
	var all_crendices: Dictionary[StringName, CrendiceDef] = CrendiceDatabase.all()

	for cid: StringName in all_crendices:
		var def: CrendiceDef = all_crendices[cid]
		if not can_drop_crendice(def, kill_context):
			continue

		var base_chance: float = float(def.drop_rules.get("chance", 0.02))
		if rng.randf() < (base_chance * luck_mult):
			out.append(cid)

	return out


## Tratamento da morte do jogador: anula a sorte da Pata de Quati (fica Adormecido)
static func on_player_death(equipment: Equipment) -> Array[StringName]:
	var adormecidos: Array[StringName] = []
	if equipment == null:
		return adormecidos

	for stack: ItemStack in equipment.gear_stacks():
		if stack == null or stack.crendices.is_empty():
			continue
		for i: int in stack.crendices.size():
			var cid: StringName = stack.crendices[i]
			var def: CrendiceDef = CrendiceDatabase.get_crendice(cid)
			if def != null and def.superstition_rule == &"lucky_paw_death":
				if i < stack.dormant_crendices.size():
					if not stack.dormant_crendices[i]:
						stack.dormant_crendices[i] = true
						adormecidos.append(cid)
				else:
					stack.dormant_crendices.append(true)
					adormecidos.append(cid)

	if not adormecidos.is_empty():
		equipment.changed.emit()

	return adormecidos


## Valida se um amuleto pode ser encaixado em um item de equipamento
static func can_insert_crendice(equip_stack: ItemStack, crendice_id: StringName, socket_idx: int = -1) -> String:
	if equip_stack == null:
		return "CRENDICE_ERR_NO_ITEM"
	var def: ItemDef = equip_stack.get_def()
	if def == null:
		return "CRENDICE_ERR_NO_ITEM"

	var max_sockets: int = equip_stack.get_max_sockets()
	if max_sockets <= 0:
		return "CRENDICE_ERR_NO_SOCKETS"

	if socket_idx >= 0 and socket_idx >= max_sockets:
		return "CRENDICE_ERR_SOCKET_INVALID"

	if socket_idx < 0 and equip_stack.crendices.size() >= max_sockets:
		return "CRENDICE_ERR_SOCKETS_FULL"

	var cdef: CrendiceDef = CrendiceDatabase.get_crendice(crendice_id)
	if cdef == null:
		return "CRENDICE_ERR_UNKNOWN"

	var equip_slot: StringName = def.get_equip_slot()
	var allowed: bool = false
	for v in cdef.valid_slots:
		if v == equip_slot or v == &"any":
			allowed = true
			break
		if equip_slot.begins_with("accessory") and String(v).begins_with("accessory"):
			allowed = true
			break
		# Capa/manto aceito em body
		if v == &"body" and equip_slot == &"body":
			allowed = true
			break

	if not allowed:
		return "CRENDICE_ERR_SLOT_MISMATCH"

	return ""


## Encaixa um amuleto em um item de equipamento
static func insert_crendice(equip_stack: ItemStack, crendice_id: StringName, socket_idx: int = -1) -> bool:
	var err: String = can_insert_crendice(equip_stack, crendice_id, socket_idx)
	if not err.is_empty():
		return false

	var max_s: int = equip_stack.get_max_sockets()
	while equip_stack.dormant_crendices.size() < equip_stack.crendices.size():
		equip_stack.dormant_crendices.append(false)

	if socket_idx >= 0 and socket_idx < equip_stack.crendices.size():
		equip_stack.crendices[socket_idx] = crendice_id
		equip_stack.dormant_crendices[socket_idx] = false
	elif equip_stack.crendices.size() < max_s:
		equip_stack.crendices.append(crendice_id)
		equip_stack.dormant_crendices.append(false)
	else:
		return false

	return true


## Remove um amuleto de um slot do equipamento
static func remove_crendice(equip_stack: ItemStack, socket_idx: int) -> StringName:
	if equip_stack == null or socket_idx < 0 or socket_idx >= equip_stack.crendices.size():
		return &""
	var removed_id: StringName = equip_stack.crendices[socket_idx]
	equip_stack.crendices.remove_at(socket_idx)
	if socket_idx < equip_stack.dormant_crendices.size():
		equip_stack.dormant_crendices.remove_at(socket_idx)
	return removed_id


## Reconsagra um amuleto adormecido no Altar de Crendice (gratuito)
static func consecrate_crendice(equip_stack: ItemStack, socket_idx: int) -> bool:
	if equip_stack == null or socket_idx < 0 or socket_idx >= equip_stack.crendices.size():
		return false
	if socket_idx < equip_stack.dormant_crendices.size():
		equip_stack.dormant_crendices[socket_idx] = false
		return true
	return false
