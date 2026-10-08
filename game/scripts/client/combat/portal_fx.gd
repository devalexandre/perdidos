class_name PortalFx
extends Node3D
## Portal dos mapas no cliente, no espírito do warp do Ragnarok/Samsara (refeito em 08/10/2026, arte nossa, só
## shader): uma coroa de línguas de chama azul-violeta em pé, em 2–3 anéis concêntricos (o externo mais alto e
## mais violeta, o interno menor e mais claro), sobre um disco de luz macio quase branco no centro, com ondas
## concêntricas lentas e pontinhos de luz subindo. Tudo aditivo (premultiplicado), sem contornos escuros. Só
## visual: o servidor e a interação não mudam.
##
## decorate_map(map) acha todo Area3D com metadata/interact_type = &"portal" (Interactables), esconde a malha
## antiga ("Gate", o TorusMesh azul dos mapas de caça, ou qualquer MeshInstance3D do portal) e põe um PortalFx
## no chão, na base do Area. Vale para os mapas atuais e para os regenerados. O PortalDecorator (criado pelo
## SkillFx) chama isto em cada mapa carregado.
##
## Aproximação: só para o jogador local, cada portal calcula um "proximity" 0..1 (0 a partir de PROX_FAR m, 1 na
## borda do anel externo) amortecido no tempo. Longe as chamas ficam baixas e calmas; perto sobem, clareiam e as
## ondas do disco correm mais; as runas sutis do disco acendem em sequência; o zumbido sobe de volume/tom e a luz
## cresce. Só visual/som no cliente; headless não toca som.

const INTERACT_TYPE_PORTAL: StringName = &"portal"
const META_INTERACT_TYPE: StringName = &"interact_type"
const META_APPROACH: StringName = &"approach_position"
const META_DECORATED: StringName = &"portal_fx"
const NODE_NAME: StringName = &"PortalFx"
const INTERACTABLES: String = "Interactables"
const FLAME_SHADER: Shader = preload("res://assets/shaders/env_portal_flames.gdshader")
const DISC_SHADER: Shader = preload("res://assets/shaders/env_portal_disc.gdshader")
const PARTICLE_SHADER: Shader = preload("res://assets/shaders/env_ambient_particle.gdshader")
## Raio do portal no chão (m): o anel externo de chamas. Escala do warp da referência: o portal tem mais ou
## menos a largura de dois personagens (reduzido para ~65% em 08/10/2026, "muito grande"). Não passar disso.
const RADIUS: float = 1.05
## Anéis de chama: [raio (m), altura máxima (m), línguas na volta, cor da base, cor das pontas, força].
## O externo é o mais alto e mais violeta; o interno, menor e mais claro.
const FLAME_RINGS: Array = [
	[1.05, 0.7, 12.0, Color(0.36, 0.4, 1.0), Color(0.5, 0.3, 0.95), 0.95],
	[0.85, 0.52, 10.0, Color(0.44, 0.5, 1.0), Color(0.46, 0.36, 1.0), 0.85],
	[0.65, 0.34, 8.0, Color(0.6, 0.68, 1.0), Color(0.46, 0.48, 1.0), 0.8],
]
## O disco cobre um pouco além do anel externo (o brilho morre suave na borda).
const DISC_RADIUS: float = 1.2
## Raio do chão: procura o chão a partir de um pouco acima do Area.
const GROUND_RAY_UP: float = 4.0
const GROUND_RAY_DOWN: float = 12.0
const GROUND_MASK: int = 1
const LIFT: float = 0.04
## Ordem de desenho entre transparentes: disco depois das manchas de chão (até 5) e da sombra dos pés (6);
## chamas por cima do disco. O personagem é opaco (escreve profundidade): as chamas de trás ficam atrás dele, e as
## da frente descem e ficam mais transparentes no shader para ele continuar legível dentro do portal.
const DISC_PRIORITY: int = 7
const FLAME_PRIORITY: int = 8
## Zumbido baixo do portal: o do cristal do catálogo, mais grave e mais baixo (nenhum áudio novo).
const HUM_PATH: String = "res://assets/audio/sfx/sfx_crystal_hum.ogg"
## Volume e tom do zumbido: longe (proximity 0) → na entrada (proximity 1).
const HUM_DB_FAR: float = -22.0
const HUM_DB_NEAR: float = -8.0
const HUM_PITCH_FAR: float = 0.8
const HUM_PITCH_NEAR: float = 0.92
const HUM_UNIT_SIZE: float = 3.0
const HUM_MAX_DISTANCE: float = 14.0
## Aproximação: a partir de PROX_FAR m (no plano) o portal "dorme"; na borda do anel externo está todo aceso.
const PROX_FAR: float = 8.0
const PROX_NEAR: float = RADIUS + 0.05
## Diferença de altura acima da qual o jogador não conta (outro andar/plataforma).
const PROX_MAX_DY: float = 4.0
## Amortecimento (1/s): quanto maior, mais rápido o proximity alcança o alvo. Subir é um pouco mais rápido que apagar.
const PROX_RISE_RATE: float = 2.6
const PROX_FALL_RATE: float = 1.6
## Luz: longe → perto.
const LIGHT_ENERGY_FAR: float = 0.7
const LIGHT_ENERGY_NEAR: float = 1.5
## Velocidade das chamas subindo e das ondas do disco: longe → perto (fases acumuladas, sem pulo).
const FLOW_SPEED_FAR: float = 0.55
const FLOW_SPEED_NEAR: float = 1.4
const WAVE_SPEED_FAR: float = 0.6
const WAVE_SPEED_NEAR: float = 1.8
## Pontinhos de luz: nascem dentro do portal, sobem e são puxados de leve para o eixo.
const SPARK_RING_OUTER: float = 1.0
const SPARK_RING_INNER: float = 0.15
const SPARK_COLOR: Color = Color(0.62, 0.7, 1.0)

var hum: AudioStreamPlayer3D = null
## Aproximação amortecida (0..1) do jogador local; o alvo sem amortecimento fica em target_proximity.
var proximity: float = 0.0
var target_proximity: float = 0.0
## Para testes/capturas: quem conta como "jogador local" (senão NetWorld.client_player).
var focus_override: Node3D = null
var sparks: CPUParticles3D = null
var disc_material: ShaderMaterial = null
var flame_materials: Array[ShaderMaterial] = []
var _spark_material: ShaderMaterial = null
var _light: OmniLight3D = null
var _flow: float = 0.0
var _wave: float = 0.0
var _applied: float = -1.0


func _ready() -> void:
	_add_disc()
	var mobile: bool = GameSettings.is_mobile_platform()
	var rings: int = flame_ring_count(EnvQuality.current, mobile)
	for i: int in rings:
		_add_flame_ring(FLAME_RINGS[i] as Array, i)
	var light := OmniLight3D.new()
	light.name = &"PortalGlow"
	light.position.y = 0.4
	light.light_color = Color(0.45, 0.5, 1.0)
	light.light_energy = LIGHT_ENERGY_FAR
	light.omni_range = 2.4
	light.shadow_enabled = false
	add_child(light)
	_light = light
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists(HUM_PATH):
		var stream: AudioStream = (load(HUM_PATH) as AudioStream).duplicate() as AudioStream
		AudioDirector._set_loop(stream)
		hum = AudioStreamPlayer3D.new()
		hum.name = &"Hum"
		hum.stream = stream
		hum.bus = AudioDirector.BUS_SFX
		hum.volume_db = HUM_DB_FAR
		hum.pitch_scale = HUM_PITCH_FAR
		hum.unit_size = HUM_UNIT_SIZE
		hum.max_distance = HUM_MAX_DISTANCE
		hum.autoplay = true
		add_child(hum)
	_add_sparks(mobile)
	_apply_proximity()


## Disco de luz deitado no chão: gradiente radial forte no centro, ondas concêntricas e as runas sutis.
func _add_disc() -> void:
	disc_material = ShaderMaterial.new()
	disc_material.shader = DISC_SHADER
	disc_material.render_priority = DISC_PRIORITY
	var disc := MeshInstance3D.new()
	disc.name = &"Disc"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * DISC_RADIUS * 2.0
	plane.material = disc_material
	disc.mesh = plane
	disc.position.y = LIFT
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)


## Um anel de chamas: cilindro aberto (sem tampas) com o shader de línguas de chama.
func _add_flame_ring(ring: Array, index: int) -> void:
	var radius: float = float(ring[0])
	var height: float = float(ring[1])
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.render_priority = FLAME_PRIORITY + index # o interno (mais claro) por último
	material.set_shader_parameter(&"height", height)
	material.set_shader_parameter(&"tongues", float(ring[2]))
	material.set_shader_parameter(&"base_color", ring[3])
	material.set_shader_parameter(&"tip_color", ring[4])
	material.set_shader_parameter(&"strength", float(ring[5]))
	material.set_shader_parameter(&"seed", float(index) * 3.17)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius * 0.97
	cylinder.height = height
	cylinder.radial_segments = 48
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	cylinder.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = "Flames%d" % index
	mesh.mesh = cylinder
	mesh.position.y = LIFT + height * 0.5
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	flame_materials.append(material)


## Pontinhos de luz que nascem dentro do portal e sobem, puxados de leve para o eixo, com um giro lento. A
## quantidade é fixa por qualidade (mudar amount reinicia o sistema); o proximity controla opacidade e velocidade.
func _add_sparks(mobile: bool) -> void:
	var count: int = spark_amount(EnvQuality.current, mobile)
	if count <= 0:
		return
	sparks = CPUParticles3D.new()
	sparks.name = &"Sparks"
	sparks.amount = count
	sparks.lifetime = 1.8
	sparks.local_coords = true
	sparks.position.y = 0.1
	sparks.direction = Vector3.UP
	sparks.spread = 15.0
	sparks.gravity = Vector3(0, 0.25, 0)
	sparks.initial_velocity_min = 0.25
	sparks.initial_velocity_max = 0.55
	sparks.radial_accel_min = -0.35
	sparks.radial_accel_max = -0.15
	sparks.tangential_accel_min = 0.2
	sparks.tangential_accel_max = 0.5
	sparks.damping_min = 0.1
	sparks.damping_max = 0.3
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparks.emission_ring_radius = SPARK_RING_OUTER
	sparks.emission_ring_inner_radius = SPARK_RING_INNER
	sparks.emission_ring_height = 0.1
	sparks.emission_ring_axis = Vector3.UP
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(SPARK_COLOR, 0.0), Color(SPARK_COLOR, 0.9), Color(0.9, 0.94, 1.0, 0.8),
			Color(0.9, 0.94, 1.0, 0.0)])
	sparks.color_ramp = ramp
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spark_material = ShaderMaterial.new()
	_spark_material.shader = PARTICLE_SHADER
	_spark_material.render_priority = FLAME_PRIORITY + 3
	_spark_material.set_shader_parameter(&"kind", 3)
	_spark_material.set_shader_parameter(&"opacity", 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	quad.material = _spark_material
	sparks.mesh = quad
	add_child(sparks)


## Quantos anéis de chama: 3 em ALTA/MÉDIA, 2 em BAIXA ou mobile (fica o externo e o do meio).
static func flame_ring_count(preset: EnvQuality.Preset, mobile: bool) -> int:
	if mobile or preset == EnvQuality.Preset.BAIXA:
		return 2
	return FLAME_RINGS.size()


## Quantos pontinhos de luz por portal: mínimo em mobile/BAIXA.
static func spark_amount(preset: EnvQuality.Preset, mobile: bool) -> int:
	if mobile or preset == EnvQuality.Preset.BAIXA:
		return 6
	return 22 if preset == EnvQuality.Preset.ALTA else 12


## Alvo do proximity para uma distância no plano (m): 0 a partir de PROX_FAR, 1 na borda do anel, suave no meio.
static func proximity_for_distance(distance: float) -> float:
	return 1.0 - smoothstep(PROX_NEAR, PROX_FAR, distance)


## Amortecimento exponencial (independe do FPS): sobe com PROX_RISE_RATE, cai com PROX_FALL_RATE.
static func damp_proximity(current: float, target: float, delta: float) -> float:
	var rate: float = PROX_RISE_RATE if target > current else PROX_FALL_RATE
	var next: float = lerpf(current, target, 1.0 - exp(-rate * maxf(delta, 0.0)))
	return target if absf(next - target) < 0.001 else next


func _process(delta: float) -> void:
	target_proximity = _measure_target()
	proximity = damp_proximity(proximity, target_proximity, delta)
	# Fases acumuladas aqui (e não TIME * velocidade no shader): mudar a velocidade não faz a chama pular.
	_flow += delta * lerpf(FLOW_SPEED_FAR, FLOW_SPEED_NEAR, proximity)
	_wave += delta * lerpf(WAVE_SPEED_FAR, WAVE_SPEED_NEAR, proximity)
	for material: ShaderMaterial in flame_materials:
		material.set_shader_parameter(&"flow", _flow)
	if disc_material != null:
		disc_material.set_shader_parameter(&"wave", _wave)
	_apply_proximity()


## Alvo sem amortecimento: distância no plano até o jogador local (0 se não há jogador ou o portal está oculto).
func _measure_target() -> float:
	var focus: Node3D = focus_override
	if focus == null:
		focus = NetWorld.client_player
	if not is_instance_valid(focus) or not focus.is_inside_tree() or not is_visible_in_tree():
		return 0.0
	var d: Vector3 = focus.global_position - global_position
	if absf(d.y) > PROX_MAX_DY:
		return 0.0
	return proximity_for_distance(Vector2(d.x, d.z).length())


## Passa o proximity para chamas, disco, pontinhos, zumbido e luz (só quando mudou).
func _apply_proximity() -> void:
	if absf(proximity - _applied) < 0.0005:
		return
	_applied = proximity
	var p: float = proximity
	for material: ShaderMaterial in flame_materials:
		material.set_shader_parameter(&"proximity", p)
	if disc_material != null:
		disc_material.set_shader_parameter(&"proximity", p)
	if sparks != null:
		sparks.speed_scale = lerpf(0.7, 1.2, p)
		_spark_material.set_shader_parameter(&"opacity", lerpf(0.35, 1.0, p))
	if hum != null:
		hum.volume_db = lerpf(HUM_DB_FAR, HUM_DB_NEAR, p)
		hum.pitch_scale = lerpf(HUM_PITCH_FAR, HUM_PITCH_NEAR, p)
	if _light != null:
		_light.light_energy = lerpf(LIGHT_ENERGY_FAR, LIGHT_ENERGY_NEAR, p)


## Decora os portais de um mapa. Devolve quantos portais novos ganharam o PortalFx.
static func decorate_map(map: Node) -> int:
	if map == null:
		return 0
	var veil: MeshInstance3D = map.get_node_or_null(^"Decor/Geometry/Mesh_portal") as MeshInstance3D
	if veil != null and not veil.has_meta(&"portal_veil_done"):
		var material := ShaderMaterial.new()
		material.shader = load("res://assets/shaders/env_portal_veil.gdshader")
		veil.material_override = material
		veil.set_meta(&"portal_veil_done", true)
	var root: Node = map.get_node_or_null(INTERACTABLES)
	if root == null:
		return 0
	var n: int = 0
	for area: Node in root.get_children():
		if not area is Area3D or StringName(str(area.get_meta(META_INTERACT_TYPE, &""))) != INTERACT_TYPE_PORTAL:
			continue
		if bool(area.get_meta(&"hidden_waterfall_passage", false)):
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
	var ap: Variant = area.get_meta(META_APPROACH, Vector3(p.x, 0.0, p.z))
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
