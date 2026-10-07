class_name LevelUpFx
extends Node3D
## Efeito de subir de nível (visto por todos da instância): coluna de luz dourada, pétalas da Florada
## subindo, anel no chão, "NÍVEL X!" flutuando e o som sfx_level_up. Escuta NetProgress.level_up.

const DURATION_SEC: float = 2.2
const COLUMN_HEIGHT: float = 3.4
const COLUMN_RADIUS: float = 0.38
const RING_RADIUS: float = 1.1
const LABEL_RISE: float = 1.2
const LABEL_HEIGHT: float = 2.6
const GOLD: Color = Color(1.0, 0.82, 0.35)
const GOLD_SOFT: Color = Color(1.0, 0.85, 0.45, 0.22)
const PETAL_COUNT: int = 36
const PETAL_SIZE: float = 0.14
const PETAL_TEXTURE: String = "res://assets/ui/title/petal.png"
const TEXT_KEY: String = "FX_LEVEL_UP"

## Contador para testes.
var effects_spawned: int = 0


func _ready() -> void:
	var prog: Node = get_node_or_null(^"/root/NetProgress")
	if prog != null and prog.has_signal(&"level_up"):
		prog.connect(&"level_up", _on_level_up)


func _on_level_up(entity_id: int, level: int) -> void:
	var net: Node = get_node_or_null(^"/root/NetCombat")
	var e: Node3D = net.call(&"find_entity", entity_id) if net != null else null
	if e == null:
		return
	play_at(e, level)


func play_at(target: Node3D, level: int) -> void:
	effects_spawned += 1
	var root := Node3D.new()
	root.name = &"LevelUp"
	target.add_child(root)
	root.add_child(_column())
	root.add_child(_ring())
	root.add_child(_petals())
	root.add_child(_label(level))
	var light := OmniLight3D.new()
	light.light_color = GOLD
	light.omni_range = 4.0
	light.light_energy = 1.6
	light.position = Vector3(0, 1.2, 0)
	root.add_child(light)
	var tw := root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, DURATION_SEC)
	get_tree().create_timer(DURATION_SEC + 0.6).timeout.connect(root.queue_free)
	AudioDirector.play_sfx(&"level_up", target.global_position)


func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	return m


func _column() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = COLUMN_RADIUS * 0.6
	mesh.bottom_radius = COLUMN_RADIUS
	mesh.height = COLUMN_HEIGHT
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = COLUMN_HEIGHT * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := _unshaded(GOLD_SOFT)
	mi.material_override = mat
	mi.scale = Vector3(0.2, 0.05, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(DURATION_SEC * 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.0, DURATION_SEC * 0.45)
	return mi


func _ring() -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = RING_RADIUS * 0.85
	mesh.outer_radius = RING_RADIUS
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = 0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := _unshaded(GOLD)
	mi.material_override = mat
	mi.scale = Vector3(0.3, 0.3, 0.3)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(1.6, 1.0, 1.6), DURATION_SEC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, DURATION_SEC)
	return mi


func _petals() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.35
	p.amount = PETAL_COUNT
	p.lifetime = DURATION_SEC
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = COLUMN_RADIUS * 1.4
	p.emission_ring_inner_radius = COLUMN_RADIUS * 0.6
	p.emission_ring_height = 0.1
	p.emission_ring_axis = Vector3.UP
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var mesh := QuadMesh.new()
	mesh.size = Vector2(PETAL_SIZE, PETAL_SIZE)
	var mat := _unshaded(GOLD)
	if ResourceLoader.exists(PETAL_TEXTURE):
		mat.albedo_texture = load(PETAL_TEXTURE)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	ramp.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
	p.color_ramp = ramp
	p.emitting = true
	return p


func _label(level: int) -> Label3D:
	var l := Label3D.new()
	l.text = tr(TEXT_KEY) % level
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0022
	l.font_size = 40
	l.outline_size = 12
	l.modulate = GOLD
	l.outline_modulate = Color(0.25, 0.12, 0.02)
	l.position.y = LABEL_HEIGHT
	l.scale = Vector3(0.5, 0.5, 0.5)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", LABEL_HEIGHT + LABEL_RISE, DURATION_SEC)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	return l
