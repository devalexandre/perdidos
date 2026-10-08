shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// Chuva (env_fire_damp, global): brasas apagam pela metade e o leito escurece.
#include "res://assets/shaders/env_weather.gdshaderinc"
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float grain = sin(p.x * 24.0 + sin(p.y * 13.0)) * sin(p.y * 19.0 + p.x * 7.0);
	float hot = smoothstep(0.1, 0.8, grain) * (0.7 + 0.3 * sin(TIME * 2.0 + p.x * 8.0)) * (1.0 - env_fire_damp() * 0.55);
	vec3 col = mix(vec3(0.06, 0.025, 0.015), vec3(0.85, 0.20, 0.025), hot);
	ALBEDO = col;
	EMISSION = vec3(1.0, 0.23, 0.025) * hot * 0.8;
	ALPHA = 1.0 - smoothstep(0.6, 1.0, r);
}
