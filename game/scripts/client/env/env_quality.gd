class_name EnvQuality
extends RefCounted
## Presets de qualidade do cenário (GDD §17.0.A) — Alta / Média / Baixa. Só liga/desliga CUSTO;
## o "look" (cores, névoa, tonemap) é do Environment de cada mapa (ver EnvLook e docs/arte-cenario.md).
## Uso: EnvQuality.current = EnvQuality.Preset.MEDIA; client_view.apply_env_quality()

enum Preset { ALTA, MEDIA, BAIXA }

const PRESET_NAMES: Array[String] = ["Alta", "Média", "Baixa"]

## Preset em uso (a tela de opções pode trocar e chamar ClientView.apply_env_quality()).
static var current: Preset = Preset.ALTA

## Tabela dos presets. Chaves:
##  msaa: MSAA 3D da SubViewport; ssao/glow/fog/tilt_shift/vignette: efeitos;
##  shadow_atlas: lado do atlas da sombra direcional; soft_shadow: qualidade do filtro PCF;
##  shadow_distance: alcance da sombra (m); foliage_density: multiplicador de MultiMesh (capim/flores);
##  foliage_distance: distância de corte dos MultiMesh (m).
const TABLE: Dictionary = {
	Preset.ALTA: {
		"msaa": Viewport.MSAA_4X, "ssao": true, "glow": true, "fog": true, "tilt_shift": true, "vignette": true,
		"shadow_atlas": 4096, "soft_shadow": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "shadow_distance": 60.0,
		"foliage_density": 1.0, "foliage_distance": 60.0,
	},
	Preset.MEDIA: {
		"msaa": Viewport.MSAA_2X, "ssao": true, "glow": true, "fog": true, "tilt_shift": true, "vignette": true,
		"shadow_atlas": 2048, "soft_shadow": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "shadow_distance": 45.0,
		"foliage_density": 0.6, "foliage_distance": 45.0,
	},
	Preset.BAIXA: {
		"msaa": Viewport.MSAA_DISABLED, "ssao": false, "glow": false, "fog": true, "tilt_shift": false, "vignette": true,
		"shadow_atlas": 1024, "soft_shadow": RenderingServer.SHADOW_QUALITY_HARD, "shadow_distance": 30.0,
		"foliage_density": 0.3, "foliage_distance": 30.0,
	},
}


static func get_setting(key: String, preset: Preset = current) -> Variant:
	return (TABLE[preset] as Dictionary)[key]


## Aplica o preset à SubViewport do mundo e às configurações globais de sombra.
static func apply_viewport(vp: Viewport, preset: Preset = current) -> void:
	vp.msaa_3d = get_setting("msaa", preset)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED # FXAA/TAA borrariam os sprites nearest
	vp.use_taa = false
	vp.positional_shadow_atlas_size = int(get_setting("shadow_atlas", preset)) / 2
	RenderingServer.directional_shadow_atlas_set_size(int(get_setting("shadow_atlas", preset)), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(get_setting("soft_shadow", preset))
	RenderingServer.positional_soft_shadow_filter_set_quality(get_setting("soft_shadow", preset))


## Desliga no Environment os efeitos que o preset não comporta (não liga o que o mapa não pediu).
static func apply_environment(env: Environment, preset: Preset = current) -> void:
	if env == null:
		return
	var look_ssao: bool = bool(env.get_meta(&"look_ssao", env.ssao_enabled))
	var look_glow: bool = bool(env.get_meta(&"look_glow", env.glow_enabled))
	var look_fog: bool = bool(env.get_meta(&"look_fog", env.fog_enabled))
	env.set_meta(&"look_ssao", look_ssao)
	env.set_meta(&"look_glow", look_glow)
	env.set_meta(&"look_fog", look_fog)
	env.ssao_enabled = look_ssao and bool(get_setting("ssao", preset))
	env.glow_enabled = look_glow and bool(get_setting("glow", preset))
	env.fog_enabled = look_fog and bool(get_setting("fog", preset))


## Luzes direcionais do mundo: alcance da sombra conforme o preset.
static func apply_lights(root: Node, preset: Preset = current) -> void:
	if root == null:
		return
	for n: Node in root.find_children("*", "DirectionalLight3D", true, false):
		var l := n as DirectionalLight3D
		if l.shadow_enabled:
			l.directional_shadow_max_distance = minf(
					float(l.get_meta(&"look_shadow_distance", l.directional_shadow_max_distance)),
					float(get_setting("shadow_distance", preset)))
			if not l.has_meta(&"look_shadow_distance"):
				l.set_meta(&"look_shadow_distance", l.directional_shadow_max_distance)


## Material do pós-processo de tela (tilt-shift + vinheta).
static func apply_screen_material(mat: ShaderMaterial, preset: Preset = current) -> void:
	if mat == null:
		return
	mat.set_shader_parameter(&"enable_blur", bool(get_setting("tilt_shift", preset)))
	mat.set_shader_parameter(&"enable_vignette", bool(get_setting("vignette", preset)))
