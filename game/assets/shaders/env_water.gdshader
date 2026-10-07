shader_type spatial;
// Água pintada do kit (GDD §17.0.A): cor em faixas suaves (fundo → claro), ondulação pintada rolando
// devagar, brilhos quentes do sol e espuma leve nas cristas. Sem reflexo real (barato e estilizado).
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_disabled, depth_draw_never;

uniform vec3 deep_color : source_color = vec3(0.13, 0.36, 0.42);
uniform vec3 shallow_color : source_color = vec3(0.35, 0.62, 0.58);
uniform vec3 foam_color : source_color = vec3(0.98, 0.95, 0.85);
uniform sampler2D tex_noise : filter_linear_mipmap, repeat_enable;
uniform float scale_m = 16.0;
uniform float speed = 0.03;
uniform float foam_amount = 0.18;
uniform float sparkle = 0.6;
// Margem pela profundidade real (plano d'água único sobre relevo): perto da margem fica raso, claro, com espuma
// e transparente; no fundo, escuro. Com false usa o alfa da cor de vértice (malhas com franja, cidade).
uniform bool use_depth_edge = false;
uniform float shore_depth = 0.55;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wpos;
varying float edge;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge = COLOR.a;
	VERTEX.y += sin(TIME * 0.8 + wpos.x * 0.4 + wpos.z * 0.3) * 0.03;
}

void fragment() {
	float edge_v = edge;
	if (use_depth_edge) {
		float d = texture(depth_tex, SCREEN_UV).r;
		vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		v.xyz /= v.w;
		edge_v = clamp((VERTEX.z - v.z) / shore_depth, 0.0, 1.0);
	}
	vec2 p = wpos.xz / scale_m;
	float n1 = texture(tex_noise, p + vec2(TIME * speed, TIME * speed * 0.6)).r;
	float n2 = texture(tex_noise, p * 2.3 - vec2(TIME * speed * 0.7, -TIME * speed)).r;
	float n = n1 * 0.6 + n2 * 0.4;
	vec3 col = mix(deep_color, shallow_color, smoothstep(0.35, 0.7, n));
	if (use_depth_edge) {
		col = mix(shallow_color * 1.1, col, smoothstep(0.2, 1.0, edge_v));
	}
	float crest = smoothstep(0.78, 0.9, n2 * 0.6 + n1 * 0.4);
	col = mix(col, foam_color, crest * foam_amount);
	// margem: água rasa clara + espuma macia + borda que se funde com o chão (cor de vértice alfa 0 na franja)
	float shore = 1.0 - smoothstep(0.35, 1.0, edge_v + (n1 - 0.5) * 0.25);
	col = mix(col, shallow_color * 1.15, shore * 0.6);
	float foam = smoothstep(0.2, 0.0, abs(edge_v - 0.55 + (n2 - 0.5) * 0.2)) * (0.6 + 0.4 * sin(TIME * 1.3 + n1 * 6.0));
	col = mix(col, foam_color, foam * (use_depth_edge ? 0.3 : 0.7));
	ALPHA = clamp(smoothstep(0.05, 0.5, edge_v + (n1 - 0.5) * 0.15), 0.0, 1.0);
	ALBEDO = col;
	ROUGHNESS = 0.25;
	SPECULAR = 0.5 * sparkle;
	// normal pintada leve a partir do ruído (brilho do sol quebrado)
	float dx = texture(tex_noise, p * 2.3 + vec2(0.01, 0.0) - vec2(TIME * speed * 0.7, -TIME * speed)).r - n2;
	float dz = texture(tex_noise, p * 2.3 + vec2(0.0, 0.01) - vec2(TIME * speed * 0.7, -TIME * speed)).r - n2;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(dx * 6.0, 0.0, dz * 6.0, 0.0)).xyz);
}
