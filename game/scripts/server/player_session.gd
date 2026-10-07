class_name PlayerSession
extends RefCounted
## Estado de servidor de um jogador conectado: entidade, personagem e sessões abertas
## (interação pendente, diálogo, loja). Replicação privada: marca o que mudou (dirty) e o
## ServerWorld manda só para este peer no fim do tick (flush).

const DIRTY_INVENTORY: int = 1
const DIRTY_EQUIPMENT: int = 2
const DIRTY_STATS: int = 4
const DIRTY_CURRENCY: int = 8
const DIRTY_ALL: int = DIRTY_INVENTORY | DIRTY_EQUIPMENT | DIRTY_STATS | DIRTY_CURRENCY

var peer_id: int = 0
var entity: NetEntity = null
var character: CharacterData = null
## Estado transitório: nunca vai para o save.
var mounted_id: StringName = &""

## Interação pendente (andando até o alcance): target_id e quantas vezes o caminho foi refeito.
var pending_target_id: String = ""
var pending_repaths: int = 0

## Diálogo aberto (0 = nenhum).
var dialogue_npc_id: int = 0
var dialogue_def: DialogueDef = null
var dialogue_node: DialogueNode = null
## Opções visíveis do nó atual, na ordem enviada ao cliente.
var dialogue_options: Array[DialogueOption] = []

## Loja aberta (&"" = nenhuma) e o NPC dono dela.
var shop_id: StringName = &""
var shop_npc_id: int = 0

var last_chat_msec: int = -1000000
var _dirty: int = 0
## Precisa salvar (mudou algo persistente desde o último save).
var save_pending: bool = false


func _init(p_peer_id: int, p_entity: NetEntity, p_character: CharacterData) -> void:
	peer_id = p_peer_id
	entity = p_entity
	character = p_character
	character.inventory.changed.connect(mark_dirty.bind(DIRTY_INVENTORY))
	character.equipment.changed.connect(mark_dirty.bind(DIRTY_EQUIPMENT | DIRTY_STATS))
	_dirty = DIRTY_ALL


func mark_dirty(flags: int) -> void:
	_dirty |= flags
	save_pending = true


func has_dialogue() -> bool:
	return dialogue_npc_id != 0


func has_shop() -> bool:
	return not shop_id.is_empty()


## Manda ao dono tudo o que mudou (RPC direcionado — ninguém mais recebe).
func flush() -> void:
	if _dirty == 0:
		return
	if _dirty & DIRTY_INVENTORY:
		Net.push_inventory(peer_id, character.inventory.to_client())
	if _dirty & DIRTY_EQUIPMENT:
		Net.push_equipment(peer_id, character.equipment.to_client())
	if _dirty & DIRTY_STATS:
		Net.push_stats(peer_id, character.refresh_stats())
	if _dirty & DIRTY_CURRENCY:
		Net.push_currency(peer_id, character.stars)
	_dirty = 0
