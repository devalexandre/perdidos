class_name FollowerGather
extends Area3D
## Coleta do cenário; o servidor conserva a quantidade e o tempo de reuso por dono.
@export var item_id: StringName = &""
@export var quantity: int = 1
@export var gather_id: String = ""
var _icon: Sprite3D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	set_meta(&"interact_id", gather_id)
	set_meta(&"target_id", "m:" + gather_id)
	set_meta(&"interact_type", &"gather")
	set_meta(&"item_id", item_id)
	set_meta(&"quantity", quantity)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	shape.shape = sphere
	shape.position.y = 0.4
	add_child(shape)
	if Net.is_server:
		return
	_icon = Sprite3D.new()
	_icon.texture = UIKit.item_icon(Content.item(item_id))
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.pixel_size = 0.02
	_icon.position.y = 0.3
	_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_icon)
	var label := Label3D.new()
	var def: ItemDef = Content.item(item_id)
	label.text = tr(def.name_key) if def != null else String(item_id)
	label.position.y = 0.75
	label.pixel_size = 0.012
	label.font_size = 16
	label.modulate = Color(0.9, 0.85, 0.5)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	add_to_group(&"follower_gather")

func _process(_delta: float) -> void:
	if _icon != null:
		_icon.modulate = Color(1.5, 1.4, 0.65) if NetFollowers.highlights_gather(global_position) else Color.WHITE
