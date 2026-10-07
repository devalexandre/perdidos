shader_type spatial;
// Chama pintada da fogueira: billboard com 3 línguas que ondulam, núcleo amarelo, corpo laranja, pontas vermelhas
// escurecendo; borda suave. Cores saturadas (sobrevivem ao tonemap/glow sem virar "bolha branca").
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 core_color : source_color = vec3(1.0, 0.86, 0.35);
uniform vec3 body_color : source_color = vec3(1.0, 0.45, 0.08);
uniform vec3 tip_color : source_color = vec3(0.78, 0.14, 0.04);
uniform float glow = 1.4;
uniform float push = 0.55;

void vertex() {
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
	float sway = sin(y * 6.0 - TIME * 5.0 + ph) * 0.07 * y + sin(TIME * 2.3 + ph) * 0.02 * y;
	float shape = w * pow(max(0.0, 1.0 - y), 0.65) * (0.9 + 0.1 * sin(TIME * 7.0 + ph));
	float d = abs(p.x - cx - sway);
	return (1.0 - smoothstep(shape * 0.7, shape, d)) * smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.9, 1.0, y));
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	float body = max(tongue(p, 0.0, 0.95 + 0.04 * sin(TIME * 3.1), 0.24, 0.0),
			max(tongue(p, -0.17, 0.7 + 0.06 * sin(TIME * 2.7), 0.15, 1.9), tongue(p, 0.18, 0.76 + 0.05 * sin(TIME * 3.7), 0.15, 3.3)));
	float core = tongue(p, 0.0, 0.55, 0.13, 0.8);
	vec3 col = mix(body_color, tip_color, smoothstep(0.35, 0.9, p.y));
	col = mix(col, core_color, core);
	ALBEDO = col * glow;
	ALPHA = clamp(body * 1.1, 0.0, 1.0);
}
