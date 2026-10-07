class_name DialogueOption
extends Resource
## Opção de resposta num nó de diálogo.

@export var text_key: String = ""
## Próximo nó (id em DialogueDef.nodes). Vazio = encerra o diálogo.
@export var next_node: StringName = &""
## Ação executada NO SERVIDOR ao escolher: &"" (nada), &"open_shop", &"close".
@export var action: StringName = &""
## Condições para a opção aparecer (vazio = sempre). Chaves: min_level (int), has_item (StringName).
@export var conditions: Dictionary[StringName, Variant] = {}
## Parâmetros da ação. give_item: {"item_id": StringName, "qty": int, "once": bool}
## (once = só uma vez por personagem).
@export var action_args: Dictionary[StringName, Variant] = {}
