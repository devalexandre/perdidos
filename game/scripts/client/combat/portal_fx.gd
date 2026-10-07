class_name PortalFx
extends Node3D
## Portal dos mapas no cliente (30/09/2026, "como no Ragnarok", arte nossa): redemoinho de luz deitado no chão
## girando devagar (folha portal_ground) + coluna de luz bem transparente com fagulhas subindo (portal_column).
## Folhas geradas por tools/art/fx/fx_portal.py. Só visual: o servidor e a interação não mudam.
##
## decorate_map(map) acha todo Area3D com metadata/interact_type = &"portal" (Interactables), esconde a malha
## antiga ("Gate", o TorusMesh azul dos mapas de caça, ou qualquer MeshInstance3D do portal) e põe um PortalFx
## no chão, na base do Area. Vale para os mapas atuais e para os regenerados. O PortalDecorator (criado pelo
## SkillFx) chama isto em cada mapa carregado.

const INTERACT_TYPE_PORTAL: StringName = &"portal"
const META_INTERACT_TYPE: StringName = &"interact_type"
const META_APPROACH: StringName = &"approach_position"
const META_DECORATED: StringName = &"portal_fx"
const NODE_NAME: StringName = &"PortalFx"
const INTERACTABLES: String = "Interactables"
const GROUND_PIECE: StringName = &"portal_ground"
const COLUMN_PIECE: StringName = &"portal_column"
## Raio do portal no chão (m); a folha foi desenhada para este raio.
const RADIUS: float = 1.3
## Raio do chão: procura o chão a partir de um pouco acima do Area.
const GROUND_RAY_UP: float = 4.0
const GROUND_RAY_DOWN: float = 12.0
const GROUND_MASK: int = 1
const LIFT: float = 0.06
## Zumbido baixo do portal: o do cristal do catálogo, mais grave e mais baixo (nenhum áudio novo).
const HUM_PATH: String = "res://assets/audio/sfx/sfx_crystal_hum.ogg"
const HUM_DB: float = -16.0
const HUM_PITCH: float = 0.8
const HUM_UNIT_SIZE: float = 3.0
const HUM_MAX_DISTANCE: float = 14.0

var ground: SkillFxSprite = null
var column: SkillFxSprite = null
var hum: AudioStreamPlayer3D = null


func _ready() -> void:
	ground = SkillFxSprite.create(GROUND_PIECE)
	if ground != null:
		add_child(ground)
		ground.position = Vector3.UP * LIFT
	column = SkillFxSprite.create(COLUMN_PIECE)
	if column != null:
		add_child(column)
		column.set_depth_bias(-0.3) # atrás de quem pisa no portal: nunca cobre o personagem
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists(HUM_PATH):
		var stream: AudioStream = (load(HUM_PATH) as AudioStream).duplicate() as AudioStream
		AudioDirector._set_loop(stream)
		hum = AudioStreamPlayer3D.new()
		hum.name = &"Hum"
		hum.stream = stream
		hum.bus = AudioDirector.BUS_SFX
		hum.volume_db = HUM_DB
		hum.pitch_scale = HUM_PITCH
		hum.unit_size = HUM_UNIT_SIZE
		hum.max_distance = HUM_MAX_DISTANCE
		hum.autoplay = true
		add_child(hum)


## Decora os portais de um mapa. Devolve quantos portais novos ganharam o PortalFx.
static func decorate_map(map: Node) -> int:
	if map == null:
		return 0
	var root: Node = map.get_node_or_null(INTERACTABLES)
	if root == null:
		return 0
	var n: int = 0
	for area: Node in root.get_children():
		if not area is Area3D or StringName(str(area.get_meta(META_INTERACT_TYPE, &""))) != INTERACT_TYPE_PORTAL:
			continue
		if area.has_meta(META_DECORATED):
			continue
		hide_old_gate(area)
		var fx := PortalFx.new()
		fx.name = NODE_NAME
		area.add_child(fx)
		fx.global_position = ground_point(area as Area3D)
		fx.global_rotation = Vector3.ZERO
		fx.scale = Vector3.ONE
		area.set_meta(META_DECORATED, true)
		n += 1
	return n


## Esconde a malha antiga do portal (o "Gate" em pé e qualquer outra MeshInstance3D do Area).
static func hide_old_gate(area: Node) -> void:
	for c: Node in area.get_children():
		if c is MeshInstance3D and not c is SkillFxSprite:
			(c as MeshInstance3D).visible = false


## Ponto do chão sob o portal: raio para baixo na camada do chão; senão a altura do approach_position; senão a
## altura do Area menos o que ele sobe (as áreas de portal ficam 2–2,5 m acima do chão).
static func ground_point(area: Area3D) -> Vector3:
	var p: Vector3 = area.global_position
	var y: float = 0.0
	var ap: Variant = area.get_meta(META_APPROACH, null)
	if ap is Vector3:
		y = (ap as Vector3).y
	if area.is_inside_tree() and area.get_world_3d() != null:
		var space: PhysicsDirectSpaceState3D = area.get_world_3d().direct_space_state
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * GROUND_RAY_UP, p + Vector3.DOWN * GROUND_RAY_DOWN,
					GROUND_MASK)
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				y = (hit["position"] as Vector3).y
	return Vector3(p.x, y, p.z)
