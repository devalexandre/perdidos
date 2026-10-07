class_name MountedVisual
extends Node3D
## Jumento em duas camadas, cavaleiro paper doll sentado com offset por direção.
var owner_visual: EntityVisual
var definition: MountDef
var back: DirectionalSprite3D
var front: DirectionalSprite3D

func configure(owner_view: EntityVisual, def: MountDef) -> void:
	owner_visual = owner_view
	definition = def
	back = DirectionalSprite3D.new()
	back.life = DirectionalSprite3D.Life.BAKED
	back.setup_sheets(def.sprite_base + "_back")
	add_child(back)
	front = DirectionalSprite3D.new()
	front.life = DirectionalSprite3D.Life.BAKED
	front.setup_sheets(def.sprite_base + "_front")
	add_child(front)
	front.get_node("Shadow").hide()

func _process(_delta: float) -> void:
	if owner_visual == null:
		return
	for layer: DirectionalSprite3D in [back, front]:
		layer.facing_yaw = owner_visual.facing_yaw
		layer.anim = &"walk" if owner_visual.anim == &"walk" else &"idle"
		layer.walk_cycle_ms = owner_visual.walk_cycle_ms
	var cam: Camera3D = get_viewport().get_camera_3d()
	var toward: Vector3 = (cam.global_position - global_position).normalized() if cam != null else Vector3.FORWARD
	back.position = -toward * 0.05
	front.position = toward * 0.05
	var row: int = DirectionalSprite3D.sheet_row_for_sector(owner_visual.get_sector())
	var ride: Vector2 = definition.ride_offset[row] if row < definition.ride_offset.size() else Vector2(0,26)
	var bob: float = 0
	if back.anim == &"walk" and back.walk_cycle_ms > 0:
		bob = sin(back._anim_time * TAU / (back.walk_cycle_ms / 1000.0) * 2) * 1.5
	var offset: Vector3 = Vector3(ride.x, ride.y + bob, 0) * Balance.cfg.sprite_pixel_size
	owner_visual.get_body_sprite().position += offset
	for overlay: DirectionalSprite3D.Overlay in owner_visual._overlays:
		overlay.sprite.position += offset
	owner_visual.get_node("Shadow").hide()
