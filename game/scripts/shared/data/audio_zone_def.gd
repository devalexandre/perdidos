class_name AudioZoneDef
extends Resource
## Zona de áudio (só cliente): data/audio/<map_id>_<zone>.tres. Ligada a uma Area3D do mapa
## em <mapa>/AudioZones com meta "zone_id" igual a id. Zona "default" vale para o mapa todo.

@export var id: StringName = &""
@export var music: AudioStream
@export var ambience: Array[AudioStream] = []
@export var music_volume_db: float = 0.0
@export var priority: int = 0            # a zona de maior prioridade em que o jogador está vence
