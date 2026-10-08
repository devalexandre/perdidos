shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Chuva (env_fire_damp, global): menos brilho e chama mais rala.
#include "res://assets/shaders/env_weather.gdshaderinc"
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
float tongue(vec2 p, float center, float height, float width, float phase) {
	float y = p.y / height;
	float sway = sin(y * 5.0 - TIME * 4.0 + phase) * 0.075 * y;
	float shape = width * pow(max(0.0, 1.0 - y), 0.7);
	float mask = 1.0 - smoothstep(shape - 0.04, shape + 0.02, abs(p.x - center - sway));
	return mask * smoothstep(0.0, 0.10, y) * (1.0 - smoothstep(0.92, 1.0, y));
}
void fragment() {
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	float silhouette = max(tongue(p, 0.0, 0.96, 0.23, 0.0), max(
		tongue(p, -0.20, 0.67 + 0.05 * sin(TIME * 3.0), 0.16, 1.8),
		tongue(p, 0.19, 0.74 + 0.05 * sin(TIME * 3.5), 0.16, 3.2)));
	float core = tongue(p, 0.0, 0.58, 0.13, 0.7);
	vec3 amber = mix(vec3(1.0, 0.25, 0.035), vec3(1.0, 0.70, 0.15), 1.0 - p.y);
	ALBEDO = mix(amber, vec3(1.0, 0.93, 0.56), core);
	EMISSION = ALBEDO * 0.7 * (1.0 - env_fire_damp() * 0.55);
	ALPHA = silhouette * 0.9 * (1.0 - env_fire_damp() * 0.3);
}
