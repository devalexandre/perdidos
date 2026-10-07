class_name WorldRegionDef
extends Resource
## Uma região (reino) do mapa-múndi (GDD §4.0): nome, gancho, posição do rótulo e seus lugares.
## data/world/regions/<id>.tres — gerado por docs/mundo/gerar_dados_atlas.py.

@export var id: StringName = &""
@export var name_key: String = ""
@export var hook_key: String = ""
## País/povo de inspiração (só para a equipe; não aparece no jogo).
@export var inspiration: String = ""
@export var label_pos: Vector2 = Vector2(0.5, 0.5)
## Região já alcançável no jogo (a do MVP).
@export var reached: bool = false
@export var places: Array[WorldPlaceDef] = []
