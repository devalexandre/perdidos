class_name RareVisual
extends Node3D
## Agente R (GDD §10.2, 27/09/2026): visual da variante rara de um monstro. Filho do EntityVisual:
##  - tinta dourada pulsando no sprite (reaplicada a cada quadro, respeitando o destaque do mouse e o
##    sumiço da morte);
##  - aura: quad billboard com shader aditivo (brilho radial pulsando) atrás do monstro;
##  - faíscas: CPUParticles3D subindo em volta do corpo.
## Cor: MonsterDef.rare_tint (alfa 0 = dourado padrão). Criado por CombatVisuals.refresh_monster.

const NODE_NAME: StringName = &"RareFx"
const DEFAULT_TINT: Color = Color(1.0, 0.82, 0.3, 1.0)
## Quanto a tinta puxa o sprite para a cor (0 = nada, 1 = cor pura) e o pulso (s).
const TINT_STRENGTH: float = 0.35
const TINT_BRIGHTNESS: float = 1.15
const PULSE_SEC: float = 1.6
const PULSE_AMOUNT: float = 0.12
const HOVER_BOOST: float = 1.2
## Aura: tamanho relativo à altura do sprite e altura do centro (fração).
const AURA_SIZE_FACTOR: float = 1.35
const AURA_CENTER_FRACTION: float = 0.45
const AURA_ALPHA: float = 0.55
const AURA_PRIORITY: int = -1
## Faíscas.
const SPARKLE_AMOUNT: int = 14
const SPARKLE_LIFETIME_SEC: float = 1.1
const SPARKLE_SIZE: float = 0.06
const SPARKLE_RISE: float = 0.6
const SPARKLE_SPREAD_FACTOR: float = 0.35
const FALLBACK_HEIGHT: float = 1.0

const AURA_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float alpha = 0.55;
uniform float pulse_sec = 1.6;
void vertex() {
	// Billboard: o quad sempre de frente para a câmera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	float pulse = 0.75 + 0.25 * sin(TIME * 6.2831 / pulse_sec);
	ALBEDO = tint.rgb * glow * pulse * alpha;
}
"""

static var _aura_shader: Shader = null

var visual: DirectionalSprite3D = null
var tint: Color = DEFAULT_TINT
var _aura: MeshInstance3D = null
var _sparkles: CPUParticles3D = null
var _time: float = 0.0
var _last_height: float = -1.0


## Põe (ou atualiza) o visual raro no EntityVisual do monstro.
static func apply(v: DirectionalSprite3D, color: Color) -> RareVisual:
	var fx: RareVisual = v.get_node_or_null(NodePath(String(NODE_NAME))) as RareVisual
	if fx == null:
		fx = RareVisual.new()
		fx.name = NODE_NAME
		fx.visual = v
		v.add_child(fx)
	fx.tint = color if color.a > 0.0 else DEFAULT_TINT
	fx._rebuild()
	return fx


static func remove(v: Node) -> void:
	var fx: Node = v.get_node_or_null(NodePath(String(NODE_NAME)))
	if fx != null:
		fx.queue_free()
		if v is DirectionalSprite3D:
			(v as DirectionalSprite3D).set_tint(Color.WHITE)


func _rebuild() -> void:
	if _aura == null:
		_aura = MeshInstance3D.new()
		_aura.name = &"Aura"
		_aura.mesh = QuadMesh.new()
		_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = _shader()
		mat.render_priority = AURA_PRIORITY
		_aura.material_override = mat
		add_child(_aura)
	var mat2: ShaderMaterial = _aura.material_override as ShaderMaterial
	mat2.set_shader_parameter(&"tint", tint)
	mat2.set_shader_parameter(&"alpha", AURA_ALPHA)
	mat2.set_shader_parameter(&"pulse_sec", PULSE_SEC)
	if _sparkles == null:
		_sparkles = CPUParticles3D.new()
		_sparkles.name = &"Sparkles"
		_sparkles.amount = SPARKLE_AMOUNT
		_sparkles.lifetime = SPARKLE_LIFETIME_SEC
		_sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_sparkles.direction = Vector3.UP
		_sparkles.spread = 25.0
		_sparkles.gravity = Vector3.ZERO
		_sparkles.initial_velocity_min = SPARKLE_RISE * 0.5
		_sparkles.initial_velocity_max = SPARKLE_RISE
		_sparkles.scale_amount_min = 0.6
		_sparkles.scale_amount_max = 1.2
		var quad := QuadMesh.new()
		quad.size = Vector2(SPARKLE_SIZE, SPARKLE_SIZE)
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.vertex_color_use_as_albedo = true
		quad.material = pm
		_sparkles.mesh = quad
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
		ramp.set_color(1, Color(1.0, 0.8, 0.3, 0.0))
		_sparkles.color_ramp = ramp
		add_child(_sparkles)
	_sparkles.color = tint
	_last_height = -1.0
	_layout()


func _shader() -> Shader:
	if _aura_shader == null:
		_aura_shader = Shader.new()
		_aura_shader.code = AURA_SHADER_CODE
	return _aura_shader


func _layout() -> void:
	var h: float = visual.get_world_height() if visual != null else 0.0
	if h <= 0.0:
		h = FALLBACK_HEIGHT
	if is_equal_approx(h, _last_height):
		return
	_last_height = h
	var size: float = h * AURA_SIZE_FACTOR
	(_aura.mesh as QuadMesh).size = Vector2(size, size)
	_aura.position = Vector3(0.0, h * AURA_CENTER_FRACTION, 0.0)
	_sparkles.position = Vector3(0.0, h * AURA_CENTER_FRACTION, 0.0)
	_sparkles.emission_box_extents = Vector3(h * SPARKLE_SPREAD_FACTOR, h * AURA_CENTER_FRACTION,
			h * SPARKLE_SPREAD_FACTOR)


## Cor do sprite agora (tinta + pulso; mais clara com o mouse em cima).
func current_tint() -> Color:
	var pulse: float = 1.0 + PULSE_AMOUNT * sin(_time * TAU / PULSE_SEC)
	var c: Color = Color.WHITE.lerp(tint, TINT_STRENGTH) * (TINT_BRIGHTNESS * pulse)
	if visual is EntityVisual and (visual as EntityVisual).is_hovered():
		c *= HOVER_BOOST
	c.a = 1.0
	return c


func _process(delta: float) -> void:
	if visual == null:
		return
	_time += delta
	_layout()
	var entity: Node = visual.get_parent()
	var alive: bool = entity == null or not (&"hp_ratio" in entity) or float(entity.get(&"hp_ratio")) > 0.0
	_aura.visible = alive
	_sparkles.emitting = alive
	# Morto: o CombatFx cuida da tinta (sumiço); vivo: a tinta rara manda.
	if alive:
		visual.set_tint(current_tint())
