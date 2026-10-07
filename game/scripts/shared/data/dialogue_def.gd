class_name DialogueDef
extends Resource
## Diálogo em dados: data/dialogues/<id>.tres. Começa em start_node.

@export var id: StringName = &""
@export var start_node: StringName = &"start"
@export var nodes: Array[DialogueNode] = []

func get_node_by_id(node_id: StringName) -> DialogueNode:
	for n: DialogueNode in nodes:
		if n.id == node_id:
			return n
	return null
