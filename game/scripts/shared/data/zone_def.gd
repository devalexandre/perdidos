class_name ZoneDef
extends Resource
## Regras do mapa (GDD §4.1, §9.3). data/zones/<map_id>.tres
enum Kind { CITY, TRAINING, HUNT, PVP }
@export var map_id: StringName = &""
@export var kind: Kind = Kind.CITY
@export var name_key: String = ""
## Nível máximo em que ainda se ganha XP aqui (0 = sem teto). Campo de Treino = 10.
@export var xp_level_cap: int = 0
## Itens obtidos aqui somem ao sair (Campo de Treino).
@export var items_bound_to_zone: bool = false
@export var combat_allowed: bool = true
@export var grave_on_death: bool = true
## Marker3D do mapa onde se renasce.
@export var respawn_marker: StringName = &"SpawnPoint"
@export var minimap_texture: Texture2D
@export var minimap_world_rect: Rect2 = Rect2(-60, -60, 120, 120)   # x,z mínimos e tamanho em unidades

## Progressão geográfica: recomendações, nunca bloqueio de entrada por nível.
@export var region_id: StringName = &""
@export var recommended_level_min: int = 0
@export var recommended_level_max: int = 0
@export var connected_maps: Array[StringName] = []
## Evolução e surgimento de chefes são controlados por área, não pela região inteira.
@export_range(1, 3) var monster_stage_cap: int = 3
@export var bosses_allowed: bool = true
@export var mount_allowed: bool = true
@export var pets_allowed: bool = true
