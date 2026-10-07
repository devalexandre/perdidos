class_name MonsterStage
extends Resource
## Um estágio de evolução do monstro (GDD §10.6): 1 normal, 2 médio, 3 chefe.
@export var stage: int = 1
@export var name_key: String = ""
## Base das folhas (mesmo formato dos personagens; sufixos _idle, _walk, _attack, _hit, _death).
@export var sprite_base: String = ""
## Escala visual relativa ao quadro (estágios maiores podem usar quadro maior; ver GDD §17.2).
@export var visual_scale: float = 1.0
## Folhas renderizadas no Blender (docs/arte-monstros-blender.md) já trazem respiração, quique e squash & stretch:
## o cliente usa a vida procedural BAKED (só tranco curto + flash do golpe).
@export var baked_life: bool = false
@export var level: int = 1
@export var max_hp: int = 50
@export var atk: int = 5
@export var matk: int = 0
@export var def: int = 0
@export var mdef: int = 0
@export var walk_ms_per_cell: int = 400
@export var attack_range_cells: float = 1.5
@export var attack_interval_ms: int = 1500
@export var aggressive: bool = false
@export var aggro_range_cells: int = 6
## Distância máxima da origem antes de voltar e recuperar a vida (GDD §10.3).
@export var leash_cells: int = 14
@export var xp_reward: int = 10
@export var stars_min: int = 0
@export var stars_max: int = 0
@export var drops: Array[DropEntry] = []
## Comportamentos especiais por nome (ex.: &"hop_teleport", &"roll_charge", &"fly_pattern", &"ranged").
@export var behaviors: Array[StringName] = []
## --- Acrescentado pelo Agente R (GDD §6.2/§10.2, 27/09/2026) ---
## Destreza (acerto, esquiva). -1 = automática: Balance.cfg.monster_dex_base + nível × monster_dex_per_level.
@export var dex: int = -1
