shader_type spatial;
// Pulso de cristal de caverna (cenário vivo, 08/10/2026): camada aditiva por cima do material do próprio cristal
// (material_overlay, SceneryLife). Brilho que sobe e desce devagar, mais forte na borda (fresnel) e correndo de baixo
// para cima; cada cristal com a sua fase (posição no mundo). Sem textura, sem luz extra.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(0.35, 0.8, 1.0);
uniform float strength = 0.75;
uniform float speed = 0.9;

varying float v_phase;
varying float v_y;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
	v_y = VERTEX.y;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulse = 0.5 + 0.5 * sin(TIME * speed + v_phase);
	float run = 0.5 + 0.5 * sin(TIME * speed * 2.2 - v_y * 3.0 + v_phase);
	pulse = pulse * pulse;
	ALBEDO = glow_color * (0.25 + fres * 0.75) * (0.35 + 0.65 * pulse) * (0.7 + 0.3 * run) * strength;
}
