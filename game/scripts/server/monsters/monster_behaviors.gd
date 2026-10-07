class_name MonsterBehaviors
extends RefCounted
## Comportamentos especiais por nome (MonsterStage.behaviors, GDD §10.3). Ganchos chamados pelo
## MonsterBrain; nome desconhecido é ignorado (com aviso uma vez). Para criar um novo: some um
## nome aqui e trate no gancho certo.
##   &"hop_teleport"  patrulha "some e reaparece" perto (Redemoinho Arteiro)
##   &"fly_pattern"   patrulha em círculo em volta da origem (Vaga-lume Encantado)
##   &"roll_charge"   ao ser atacado, investe rolando (mais rápido) por um tempo (Tatu-Pedra)
##   &"ranged"        ataca de longe: só marca; o alcance vem de MonsterStage.attack_range_cells
##   &"boss"          marca o estágio chefe (dados de W); sem lógica extra neste marco

const HOP_TELEPORT: StringName = &"hop_teleport"
const FLY_PATTERN: StringName = &"fly_pattern"
const ROLL_CHARGE: StringName = &"roll_charge"
const RANGED: StringName = &"ranged"
const BOSS: StringName = &"boss"
const KNOWN: Array[StringName] = [HOP_TELEPORT, FLY_PATTERN, ROLL_CHARGE, RANGED, BOSS]

## hop_teleport: chance de cada passeio ser um "pulo" (teleporte curto) em vez de andar.
const HOP_CHANCE: float = 0.5
## fly_pattern: pontos do círculo de patrulha.
const FLY_POINTS: int = 6
## roll_charge: fator do tempo por célula durante a investida (0,5 = 2× mais rápido) e duração.
const ROLL_SPEED_FACTOR: float = 0.5
const ROLL_DURATION_SEC: float = 2.0

static var _warned: Dictionary[StringName, bool] = {}


static func has(stage: MonsterStage, behavior: StringName) -> bool:
	return stage != null and behavior in stage.behaviors


static func warn_unknown(stage: MonsterStage) -> void:
	if stage == null:
		return
	for b: StringName in stage.behaviors:
		if b not in KNOWN and not _warned.has(b):
			_warned[b] = true
			push_warning("MonsterBehaviors: unknown behavior '%s' ignored." % b)


## Patrulha: devolve o próximo destino (Vector3.INF = sortear normalmente). teleport = true pede
## para "pular" direto (place) em vez de andar.
static func patrol_target(brain: MonsterBrain, rng: RandomNumberGenerator) -> Dictionary:
	var stage: MonsterStage = brain.stage
	if has(stage, FLY_PATTERN):
		brain.pattern_index = (brain.pattern_index + 1) % FLY_POINTS
		var angle: float = TAU * float(brain.pattern_index) / float(FLY_POINTS)
		var r: float = brain.roam_radius_cells * brain.cell_size()
		return {"point": brain.origin + Vector3(cos(angle) * r, 0.0, sin(angle) * r), "teleport": false}
	if has(stage, HOP_TELEPORT) and rng.randf() < HOP_CHANCE:
		return {"point": Vector3.INF, "teleport": true}
	return {"point": Vector3.INF, "teleport": false}


## Foi atacado: ganchos de reação (roll_charge começa a investida uma vez por perseguição).
static func on_damaged(brain: MonsterBrain) -> void:
	if has(brain.stage, ROLL_CHARGE) and brain.charge_left_sec <= 0.0 and not brain.charged_once:
		brain.charged_once = true
		brain.charge_left_sec = ROLL_DURATION_SEC


## Tempo por célula efetivo (investida acelera).
static func ms_per_cell(brain: MonsterBrain) -> int:
	var base: int = brain.stage.walk_ms_per_cell if brain.stage != null else Balance.cfg.walk_ms_per_cell
	if brain.charge_left_sec > 0.0:
		return maxi(1, roundi(float(base) * ROLL_SPEED_FACTOR))
	return base
