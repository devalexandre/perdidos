class_name WorldPlaceDef
extends Resource
## Um lugar do mapa-múndi (GDD §4.0.1): cidade, campo de caça, masmorra, mar, ilha, desenho de
## monstro... Posição normalizada (0..1) sobre a arte assets/worldmap/world_map.png.
## Gerado por docs/mundo/gerar_dados_atlas.py (edite lá, não aqui).

enum Kind { CAPITAL, TOWN, FIELD, DUNGEON, MYSTERY, BOSS, LANDMARK, PORT, PVP, TRAINING, SEA, ISLAND,
		DOODLE, FRONTIER }
## Aberto (existe no jogo) / em breve (planejado para o MVP) / terra ainda não alcançada.
enum Status { OPEN, SOON, UNREACHED }

@export var id: StringName = &""
@export var region_id: StringName = &""
@export var kind: Kind = Kind.TOWN
@export var status: Status = Status.UNREACHED
## Chaves de tradução (localization/world_atlas.csv).
@export var name_key: String = ""
@export var hook_key: String = ""
## Posição normalizada sobre a arte do mapa (0..1).
@export var pos: Vector2 = Vector2(0.5, 0.5)
## Faixa de nível recomendada (0 = não se aplica). Só indicativa (GDD §4.3).
@export var level_min: int = 0
@export var level_max: int = 0
## Mapa do jogo que corresponde a este lugar (para o "você está aqui"). Vazio = nenhum.
@export var map_id: StringName = &""
## Additional maps forming the same named place.
@export var map_ids: Array[StringName] = []
## Rótulo: deslocamento em px na escala 1,0 a partir do ícone; e se aparece sem passar o mouse.
@export var label_offset: Vector2 = Vector2.ZERO
@export var always_label: bool = true


func has_levels() -> bool:
	return level_max > 0


func is_marker() -> bool:
	return kind not in [Kind.SEA, Kind.ISLAND, Kind.DOODLE, Kind.FRONTIER]
