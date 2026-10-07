class_name DropEntry
extends Resource
## Linha da tabela de drops (GDD §10.5).
@export var item_id: StringName = &""
@export_range(0.0, 1.0) var chance: float = 0.1
@export var min_qty: int = 1
@export var max_qty: int = 1
