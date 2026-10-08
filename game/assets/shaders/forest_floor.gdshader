shader_type spatial;
// Chão de mata (Mata Encantada, Brejo das Brumas): grama + folhiço em manchas.
// Cenário vivo (08/10/2026): molha com a chuva (env_wetness: escurece, brilho leve e poças nas manchas de folhiço
// baixas, anéis de pingo) e recebe a sombra de nuvem passando (env_clouds). Seco e sem nuvem = igual ao antigo.
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
#include "res://assets/shaders/env_weather.gdshaderinc"
uniform sampler2D grass : source_color, repeat_enable;
uniform sampler2D litter : source_color, repeat_enable;
varying vec3 world_position;
varying float world_up;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}
void fragment() {
	vec2 p = world_position.xz;
	float patches = smoothstep(-0.4, 0.65, sin(p.x * 0.19 + sin(p.y * 0.17)) * cos(p.y * 0.23));
	vec3 green = texture(grass, p / 4.0).rgb * vec3(0.40, 0.75, 0.32);
	vec3 leaves = texture(litter, p / 5.0).rgb * vec3(0.58, 0.68, 0.39);
	vec3 col = mix(green, leaves, patches * 0.48);
	// ruídos 0..1 sem textura extra para as poças (manchas grandes + detalhe)
	float n_big = env_value_noise(p / 6.0);
	float n_small = env_value_noise(p / 1.6 + vec2(3.7, 1.9));
	float level = smoothstep(0.93, 0.985, world_up);
	vec4 wet_g = env_wet_ground(col, p, level, 0.0, n_big, n_small, patches * 0.9, TIME);
	col *= env_cloud_shade(p, TIME);
	ALBEDO = col;
	ROUGHNESS = wet_g.x;
	SPECULAR = wet_g.y;
	if (wet_g.z != 0.0 || wet_g.w != 0.0) {
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(wet_g.z, 0.0, wet_g.w, 0.0)).xyz);
	}
}
