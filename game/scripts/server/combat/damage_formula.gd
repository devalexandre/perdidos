class_name DamageFormula
extends RefCounted
## Fórmulas puras do GDD §10.2 (testadas em tests/combat/test_formulas.gd). Sem estado; a sorte
## vem de um RandomNumberGenerator passado pelo chamador (testes usam semente fixa).


## Testes (--always-hit, CombatService): todo golpe físico acerta, menos contra alvos com DES >=
## TEST_EVASIVE_DEX (o monstro "esquivo" do autoteste, para o teste dedicado do "Errou").
static var test_force_hit: bool = false
const TEST_EVASIVE_DEX: int = 1000


## Redução pela defesa: 100 / (100 + DEF). DEF negativa é tratada como 0.
static func defense_factor(defense: int) -> float:
	return CombatRules.DEFENSE_CONSTANT / (CombatRules.DEFENSE_CONSTANT + maxf(0.0, float(defense)))


## Dano antes da variação e do crítico: poder × multiplicador × fator da defesa.
static func base_damage(power: int, multiplier: float, defense: int) -> float:
	return maxf(0.0, float(power)) * multiplier * defense_factor(defense)


## Chance de crítico (0–1) do atacante com essa SOR (só dano físico). GDD §10.2: 5% + SOR × 0,3%.
static func crit_chance(luk: int) -> float:
	return clampf(Balance.cfg.crit_base_chance + float(luk) * Balance.cfg.crit_chance_per_luk, 0.0, 1.0)


## Chance de acertar (0–1) um golpe físico: clamp(80% + (DES_atacante − DES_alvo) × 1%, 50%, 95%).
## O que falta para 100% é a esquiva do alvo. Dano mágico/verdadeiro sempre acerta (não usa isto).
static func hit_chance(attacker_dex: int, defender_dex: int) -> float:
	return clampf(Balance.cfg.hit_base_chance + float(attacker_dex - defender_dex) * Balance.cfg.hit_chance_per_dex,
			Balance.cfg.hit_chance_min, Balance.cfg.hit_chance_max)


## Multiplicador da chance de drop pela SOR de quem derrotou: 1 + SOR × 0,01.
static func drop_luck_multiplier(luk: int) -> float:
	return 1.0 + maxf(0.0, float(luk)) * Balance.cfg.drop_chance_per_luk


## Multiplicador da chance de monstro raro pela maior SOR por perto: 1 + SOR × 0,02.
static func rare_luck_multiplier(luk: int) -> float:
	return 1.0 + maxf(0.0, float(luk)) * Balance.cfg.rare_chance_per_luk


## DES de um monstro: a do estágio (>= 0) ou base + nível × por_nível (Balance).
static func monster_dex(stage_dex: int, level: int) -> int:
	if stage_dex >= 0:
		return stage_dex
	return Balance.cfg.monster_dex_base + roundi(float(level) * Balance.cfg.monster_dex_per_level)


## Ataques por segundo do ataque básico: 1,0 + DES × 0,01, máximo 2,5.
static func attacks_per_second(dex: int) -> float:
	return minf(CombatRules.ATTACK_SPEED_BASE + float(dex) * CombatRules.ATTACK_SPEED_PER_DEX,
			CombatRules.ATTACK_SPEED_MAX)


## Intervalo (ms) entre ataques básicos.
static func attack_interval_msec(dex: int) -> int:
	return roundi(CombatRules.MSEC_PER_SEC / attacks_per_second(dex))


## Rola a variação (±10%) e o crítico. crit_rate < 0 = sem crítico (dano mágico/verdadeiro).
## Retorna {"amount": int (>= MIN_DAMAGE), "crit": bool}.
static func roll(base: float, crit_rate: float, rng: RandomNumberGenerator) -> Dictionary:
	var variance: float = rng.randf_range(-CombatRules.DAMAGE_VARIANCE, CombatRules.DAMAGE_VARIANCE)
	var value: float = base * (1.0 + variance)
	var crit: bool = crit_rate > 0.0 and rng.randf() < crit_rate
	if crit:
		value *= CombatRules.CRIT_MULTIPLIER
	return {"amount": maxi(CombatRules.MIN_DAMAGE, roundi(value)), "crit": crit}


## Dano completo de um golpe. attacker: {atk, matk, dex, luk}; defender: {def, mdef, dex}.
## damage_type: CombatRules.DamageType. crit_override >= 0 troca a chance de crítico (monstros).
## Físico: rola o acerto primeiro (DES × DES); errou = {"amount": 0, "crit": false, "miss": true}.
## Retorna sempre a chave "miss".
static func compute(attacker: Dictionary, defender: Dictionary, multiplier: float, damage_type: int,
		rng: RandomNumberGenerator, crit_override: float = -1.0) -> Dictionary:
	var base: float = 0.0
	var crit_rate: float = -1.0
	match damage_type:
		CombatRules.DamageType.PHYSICAL:
			var def_dex: int = int(defender.get(&"dex", 0))
			if not (test_force_hit and def_dex < TEST_EVASIVE_DEX):
				if rng.randf() >= hit_chance(int(attacker.get(&"dex", 0)), def_dex):
					return {"amount": 0, "crit": false, "miss": true}
			base = base_damage(int(attacker.get(&"atk", 0)), multiplier, int(defender.get(&"def", 0)))
			crit_rate = crit_override if crit_override >= 0.0 else crit_chance(int(attacker.get(&"luk", 0)))
		CombatRules.DamageType.MAGIC:
			base = base_damage(int(attacker.get(&"matk", 0)), multiplier, int(defender.get(&"mdef", 0)))
		_:
			base = maxf(0.0, float(attacker.get(&"atk", 0)) * multiplier)
	var r: Dictionary = roll(base, crit_rate, rng)
	r["miss"] = false
	return r


## Regeneração por segundo (GDD §6.4: valores "por 5 s").
static func hp_regen_per_sec(vit: int) -> float:
	return (CombatRules.HP_REGEN_BASE + float(vit) * CombatRules.HP_REGEN_PER_VIT) / CombatRules.REGEN_PERIOD_SEC


static func mp_regen_per_sec(spi: int) -> float:
	return (CombatRules.MP_REGEN_BASE + float(spi) * CombatRules.MP_REGEN_PER_SPI) / CombatRules.REGEN_PERIOD_SEC
