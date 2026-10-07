class_name DialogueNode
extends Resource
## Uma fala de NPC com suas opções de resposta.

@export var id: StringName = &""
@export var text_key: String = ""
@export var options: Array[DialogueOption] = []
