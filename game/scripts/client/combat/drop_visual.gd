class_name DropVisual
extends Node3D
## Item no chão (GDD §10.5): ícone do item em billboard, quicando de leve, com a quantidade e uma
## área de clique na camada 2 (meta target_id "e:<id>"). Criado pelo CombatVisuals.

const PICK_LAYER: int = 1 << 1
const META_TARGET_ID: StringName = &"target_id"
const APPEARANCE_QTY: StringName = &"qty"
const ICON_DIR: String = "res://assets/items/icons/icon_item_"
const ICON_EXT: String = ".png"
## Altura (m) do ícone acima do chão, quique (m, Hz) e raio da área de clique (m).
const ICON_HEIGHT: float = 0.35
const BOB_AMPLITUDE: float = 0.06
const BOB_HZ: float = 1.2
const PICK_RADIUS: float = 0.45
const PICK_HEIGHT: float = 0.8
const LABEL_OFFSET: float = 0.4
const FALLBACK_ICON_SIZE: int = 16
const FALLBACK_COLOR: Color = Color8(250, 229, 140)
const HOVER_TINT: Color = Color(1.35, 1.35, 1.35)
const PRIORITY_LABEL: int = 10

## Propriedades que a entidade repassa a todo visual (sem efeito aqui).
var facing_yaw: float = 0.0
var anim: StringName = &"idle"
var target_id: String = ""

var _icon: Sprite3D
var _label: Label3D
var _area: Area3D
var _time: float = 0.0


func setup(entity: Node) -> void:
	var item_id := StringName(str(entity.get(&"def_id")))
	target_id = EntityVisualFactory.entity_target_id(int(entity.get(&"entity_id")))
	var qty: int = 1
	var app: Variant = entity.get(&"appearance")
	if app is Dictionary:
		qty = int((app as Dictionary).get(APPEARANCE_QTY, 1))
	_icon = Sprite3D.new()
	_icon.name = &"Icon"
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_icon.shaded = false
	_icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_icon.pixel_size = Balance.cfg.sprite_pixel_size
	_icon.texture = _icon_for(item_id)
	_icon.position.y = ICON_HEIGHT
	add_child(_icon)
	_label = Label3D.new()
	_label.name = &"Qty"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = Balance.cfg.sprite_pixel_size
	_label.font = UIKit.world_font()
	_label.font_size = UIKit.NAMEPLATE_FONT_SIZE
	_label.outline_size = UIKit.OUTLINE_SIZE
	_label.outline_modulate = UIKit.COLOR_OUTLINE
	_label.no_depth_test = true
	_label.render_priority = PRIORITY_LABEL
	_label.text = "x%d" % qty if qty > 1 else ""
	_label.position.y = ICON_HEIGHT + LABEL_OFFSET
	add_child(_label)
	_area = Area3D.new()
	_area.name = &"PickArea"
	_area.collision_layer = PICK_LAYER
	_area.collision_mask = 0
	_area.monitoring = false
	_area.input_ray_pickable = false
	_area.set_meta(META_TARGET_ID, target_id)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = PICK_RADIUS
	cyl.height = PICK_HEIGHT
	shape.shape = cyl
	shape.position.y = PICK_HEIGHT * 0.5
	_area.add_child(shape)
	add_child(_area)
	set_meta(META_TARGET_ID, target_id)


func set_hovered(value: bool) -> void:
	_icon.modulate = HOVER_TINT if value else Color.WHITE


func _process(delta: float) -> void:
	_time += delta
	_icon.position.y = ICON_HEIGHT + sin(_time * TAU * BOB_HZ) * BOB_AMPLITUDE


static func _icon_for(item_id: StringName) -> Texture2D:
	var def: ItemDef = Content.item(item_id)
	if def != null and def.icon != null:
		return def.icon
	var path: String = ICON_DIR + String(item_id) + ICON_EXT
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.create(FALLBACK_ICON_SIZE, FALLBACK_ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(FALLBACK_COLOR)
	return ImageTexture.create_from_image(img)
