class_name MonsterEvolution
extends RefCounted
## Regras puras dos estágios dos monstros (GDD §10.6). Decisão do dono (30/09/2026): **não há evolução**.
## Monstro que mata jogador não absorve XP nem muda de estágio. Cada estágio nasce de um lugar fixo:
##  - 1 normal e 2 médio: marcadores Spawns/ dos mapas (o médio onde o desenho de áreas manda);
##  - 3 chefe: só no covil fixo (BossLairs/ do mapa), com bando, renascendo em Balance.cfg.boss_respawn_sec;
##  - 4 forma atroz: o mesmo chefe à noite (MonsterBrain.set_atroz).
## Recompensa por derrotar: a XP do estágio.

## Forma atroz = MonsterStage com este número em MonsterDef.stages.
const STAGE_ATROZ: int = MonsterDef.ATROZ_STAGE


## MonsterStage com esse número (null se não existir).
static func stage_by_number(def: MonsterDef, number: int) -> MonsterStage:
	if def == null:
		return null
	for st: MonsterStage in def.stages:
		if st.stage == number:
			return st
	return null


## XP dada a quem derrota o monstro (a do estágio).
static func kill_xp(stage: MonsterStage) -> int:
	return stage.xp_reward if stage != null else 0


## Quantos de cada estágio formam o bando do chefe (GDD §10.6: 4 normais + 2 médios).
static func escort_plan() -> Dictionary[int, int]:
	return {CombatRules.STAGE_NORMAL: Balance.cfg.boss_escort_normals,
			CombatRules.STAGE_MEDIUM: Balance.cfg.boss_escort_mediums}


## Atributos da forma atroz = os do chefe × isto (MonsterDef.atroz_stat_multiplier ou o do Balance).
static func atroz_multiplier(def: MonsterDef) -> float:
	if def != null and def.atroz_stat_multiplier > 0.0:
		return def.atroz_stat_multiplier
	return Balance.cfg.atroz_stat_multiplier
