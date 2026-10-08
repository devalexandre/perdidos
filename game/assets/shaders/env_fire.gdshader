shader_type spatial;
// Chama pintada da fogueira: billboard com 3 línguas que ondulam, núcleo amarelo, corpo laranja, pontas vermelhas
// escurecendo; borda suave. Cores saturadas (sobrevivem ao tonemap/glow sem virar "bolha branca").
// Chuva (env_fire_damp, global): chama encolhe e perde brilho.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/shaders/env_weather.gdshaderinc"

uniform vec3 core_color : source_color = vec3(1.0, 0.86, 0.35);
uniform vec3 body_color : source_color = vec3(1.0, 0.45, 0.08);
uniform vec3 tip_color : source_color = vec3(0.78, 0.14, 0.04);
uniform float glow = 1.4;
uniform float push = 0.55;
varying float fire_phase;

void vertex() {
	fire_phase = dot(MODEL_MATRIX[3].xz, vec2(2.7, 4.1));
	// billboard só em Y (plano vertical virado para a câmera): não afunda no chão com a câmera inclinada
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 fwd = vec3(-right.z, 0.0, right.x);
	float sx = length(MODEL_MATRIX[0].xyz);
	// puxa o plano um pouco para a câmera: as pedras de trás do anel não cortam a chama
	vec3 to_cam = CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz;
	to_cam.y = 0.0;
	vec4 origin = MODEL_MATRIX[3] + vec4(normalize(to_cam) * push, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(0.0, sx, 0.0, 0.0), vec4(fwd * sx, 0.0), origin);
}

float tongue(vec2 p, float cx, float h, float w, float ph) {
	float y = p.y / h;
	float t = TIME + fire_phase;
	float sway = sin(y * 6.0 - t * 5.0 + ph) * 0.085 * y + sin(t * 2.3 + ph) * 0.04 * y;
	float turbulence = sin(y * 18.0 - t * 8.0 + ph) * sin(y * 9.0 + t * 3.0) * 0.12 * y;
	float shape = w * pow(max(0.0, 1.0 - y), 0.65) * (0.9 + 0.1 * sin(t * 7.0 + ph) + turbulence);
	float d = abs(p.x - cx - sway);
	return (1.0 - smoothstep(shape * 0.7, shape, d)) * smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.9, 1.0, y));
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	float t = TIME + fire_phase;
	float body = max(tongue(p, 0.0, 0.90 + 0.09 * sin(t * 3.1), 0.24, 0.0),
			max(tongue(p, -0.17, 0.64 + 0.10 * sin(t * 2.7), 0.15, 1.9), tongue(p, 0.18, 0.70 + 0.10 * sin(t * 3.7), 0.15, 3.3)));
	body = max(body, max(tongue(p, -0.07, 0.84 + 0.1 * sin(t * 4.1), 0.10, 4.7), tongue(p, 0.10, 0.8 + 0.08 * sin(t * 3.3), 0.09, 5.8)));
	float core = tongue(p, 0.0, 0.55, 0.13, 0.8);
	vec3 col = mix(body_color, tip_color, smoothstep(0.35, 0.9, p.y));
	col = mix(col, core_color, core);
	float folds = sin(p.y * 21.0 - t * 7.0 + p.x * 9.0) * 0.5 + 0.5;
	col *= mix(0.72, 1.08, folds);
	float damp = env_fire_damp();
	ALBEDO = col * glow * (1.0 - damp * 0.3);
	EMISSION = col * 0.35 * (1.0 - damp * 0.55);
	ALPHA = clamp(body * 1.1, 0.0, 1.0) * (1.0 - damp * 0.3);
}
