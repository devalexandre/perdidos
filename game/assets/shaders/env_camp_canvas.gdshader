shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;
// Lona tingida: costuras, tecido e desgaste nas saias. Crista e borda inferior presas.
#include "res://assets/shaders/env_wind.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.64, 0.51, 0.31);
varying vec3 cloth_position;
varying vec3 cloth_normal;
void vertex() {
	cloth_position = VERTEX;
	cloth_normal = abs(NORMAL);
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float pinned = smoothstep(0.15, 0.6, VERTEX.y) * (1.0 - smoothstep(1.8, 2.4, VERTEX.y));
	VERTEX += NORMAL * environment_breeze(wp, TIME).x * sin(VERTEX.x * 4.0 + TIME * 1.8) * 0.035 * pinned;
}
void fragment() {
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	vec3 weights = pow(cloth_normal, vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 paint = texture(albedo_tex, cloth_position.zy / 1.8).rgb * weights.x
		+ texture(albedo_tex, cloth_position.xz / 1.8).rgb * weights.y
		+ texture(albedo_tex, cloth_position.xy / 1.8).rgb * weights.z;
	float seam = 1.0 - smoothstep(0.008, 0.035, abs(fract(cloth_position.x / 0.9) - 0.5));
	float hem = 1.0 - smoothstep(0.03, 0.09, abs(cloth_position.y - 0.25));
	float wear = 1.0 - smoothstep(0.0, 0.75, cloth_position.y);
	vec3 col = tint * mix(vec3(0.75), paint, 0.35);
	col *= 1.0 - seam * 0.15 - hem * 0.14 - wear * 0.16;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
