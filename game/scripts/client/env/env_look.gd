class_name EnvLook
extends RefCounted
## "Look" de luz e pós do cenário pintado (GDD §17.0.A): sol quente com sombra macia, céu/ambiente
## quentes, oclusão ambiente, bloom suave, névoa de distância quente, tonemap fílmico ajustado.
## O tilt-shift e a vinheta ficam no ClientView (env_screen_post.gdshader), valendo para todo mapa.
## Cada mapa guarda o seu Environment (WorldEnvironment) — use estes como ponto de partida:
##   env_warm_day.tres (campos/florestas) e env_warm_city.tres (cidade), gerados por build_kit.gd.

const SUN_COLOR: Color = Color(1.0, 0.92, 0.78)


## Environment quente de dia. "city" deixa a névoa um pouco mais longe e o ambiente mais claro.
static func make_environment(variant: String = "day") -> Environment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.58, 0.86)
	sky_mat.sky_horizon_color = Color(0.95, 0.88, 0.76)
	sky_mat.ground_horizon_color = Color(0.82, 0.76, 0.66)
	sky_mat.ground_bottom_color = Color(0.35, 0.32, 0.22)
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.70, 0.68, 0.76)
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_energy = 0.74 if variant == "day" else 0.78
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Tonemap fílmico suave e quente (os sprites são unshaded: exposição/branco escolhidos para não
	# lavar nem escurecer demais a pixel art — conferido nas capturas de lookdev).
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.0
	env.ssao_power = 1.6
	env.ssao_detail = 0.5
	env.ssao_light_affect = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.40
	env.glow_strength = 0.95
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.92
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.95, 0.86, 0.70)
	env.fog_light_energy = 0.95
	env.fog_sun_scatter = 0.28
	env.fog_depth_begin = 28.0 if variant == "day" else 36.0
	env.fog_depth_end = 95.0 if variant == "day" else 125.0
	env.fog_depth_curve = 1.6
	env.fog_density = 0.50
	env.fog_sky_affect = 0.35
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.10
	return env


## Sol dourado quente, ~40° de altura, sombra nítida de RPG clássico.
static func make_sun(yaw_deg: float = -35.0, pitch_deg: float = -42.0) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = SUN_COLOR
	sun.light_energy = 1.45
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.shadow_blur = 0.95
	sun.shadow_opacity = 0.88
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.rotation_degrees = Vector3(pitch_deg, yaw_deg, 0.0)
	return sun

