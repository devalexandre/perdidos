class_name NpcDef
extends Resource
## NPC em dados: data/npcs/<id>.tres (GDD §9, §17.7).

enum Routine { IDLE, WANDER, PATROL, SIT }
## Quando o NPC está no mundo (relógio do DayNight, no mapa dele). Fora do horário o servidor não abre
## diálogo/loja/quest com ele e o cliente o apaga devagar (EntityVisual).
enum Presence { ALWAYS, DAY_ONLY, NIGHT_ONLY }

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
## Rotina por horário (ex.: o menino Curupira some à noite, quando o Curupira Atroz anda na mata).
@export var presence: Presence = Presence.ALWAYS


## Base das folhas que existe de fato: sprite_base, ou fallback_sprite_base sem a folha _idle.
func resolved_sprite_base() -> String:
	if sprite_base.is_empty() or ResourceLoader.exists(sprite_base + "_idle.png") \
			or fallback_sprite_base.is_empty():
		return sprite_base
	return fallback_sprite_base


## Está no mundo com esta hora? (night = é noite no mapa do NPC.)
func is_present(night: bool) -> bool:
	match presence:
		Presence.DAY_ONLY:
			return not night
		Presence.NIGHT_ONLY:
			return night
	return true


## Está no mundo agora (autoload DayNight, igual no servidor e no cliente)? Sem relógio = sempre.
func is_present_now() -> bool:
	if presence == Presence.ALWAYS:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	var clock: Node = tree.root.get_node_or_null(^"/root/DayNight") if tree != null else null
	if clock == null:
		return true
	return is_present(bool(clock.call(&"is_night_on_map", map_id)))
