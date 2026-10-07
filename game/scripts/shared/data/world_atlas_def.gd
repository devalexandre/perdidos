class_name WorldAtlasDef
extends Resource
## O mapa-múndi inteiro (GDD §4.0.1, tecla M): arte, regiões e elementos soltos (mares, ilhas,
## desenhos de monstros, terras além do mapa). data/world/atlas.tres.

const DEFAULT_PATH: String = "res://data/world/atlas.tres"

@export var map_texture: Texture2D
@export var regions: Array[WorldRegionDef] = []
## Mares, ilhas, desenhos e fronteiras que não pertencem a uma região.
@export var features: Array[WorldPlaceDef] = []


## Todos os lugares (das regiões e soltos).
func all_places() -> Array[WorldPlaceDef]:
	var out: Array[WorldPlaceDef] = []
	for r: WorldRegionDef in regions:
		out.append_array(r.places)
	out.append_array(features)
	return out


func region(id: StringName) -> WorldRegionDef:
	for r: WorldRegionDef in regions:
		if r.id == id:
			return r
	return null


## Lugar ligado a um mapa do jogo (map_id), ou null.
func place_for_map(map_id: StringName) -> WorldPlaceDef:
	if map_id == &"":
		return null
	for p: WorldPlaceDef in all_places():
		if p.map_id == map_id or map_id in p.map_ids:
			return p
	return null


func place(id: StringName) -> WorldPlaceDef:
	for p: WorldPlaceDef in all_places():
		if p.id == id:
			return p
	return null
