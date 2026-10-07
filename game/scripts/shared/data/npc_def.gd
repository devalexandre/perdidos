class_name NpcDef
extends Resource
## NPC em dados: data/npcs/<id>.tres (GDD §9, §17.7).

enum Routine { IDLE, WANDER, PATROL, SIT }

@export var id: StringName = &""
@export var name_key: String = ""
## Base das folhas de sprite, sem sufixo: ex. "res://assets/npcs/npc_brisa" →
## npc_brisa_idle.png, npc_brisa_walk.png (e _sit.png opcional). Mesmo formato do Viajante.
@export var sprite_base: String = ""
@export var map_id: StringName = &""
## Nome do Marker3D em <mapa>/NpcPoints onde o NPC nasce (e para onde volta).
@export var spawn_marker: StringName = &""
@export var routine: Routine = Routine.IDLE
@export var wander_radius: float = 4.0
## PATROL: nomes de Marker3D em NpcPoints, em ordem.
@export var patrol_markers: Array[StringName] = []
@export var move_speed: float = 2.0
@export var dialogue: DialogueDef
@export var shop: ShopDef
## Visual de reserva enquanto as folhas de sprite_base não existem (NPC novo sem arte ainda).
@export var fallback_sprite_base: String = ""


## Base das folhas que existe de fato: sprite_base, ou fallback_sprite_base sem a folha _idle.
func resolved_sprite_base() -> String:
	if sprite_base.is_empty() or ResourceLoader.exists(sprite_base + "_idle.png") \
			or fallback_sprite_base.is_empty():
		return sprite_base
	return fallback_sprite_base
