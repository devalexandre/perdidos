shader_type spatial;
// Água pintada do kit (GDD §17.0.A): cor em faixas suaves (fundo → claro), ondulação pintada rolando
// devagar, brilhos quentes do sol e espuma leve nas cristas. Sem reflexo real (barato e estilizado).
// 08/10/2026: reflexo pintado do céu em faixas (fresnel + pinceladas que correm com a água), espuma de margem
// que chega em ondinhas, e chuva pelo uniform global env_rain (anéis de pingos; Baixa = ondulação simples).
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_disabled, depth_draw_never;
#include "res://assets/shaders/env_wind.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.13, 0.36, 0.42);
uniform vec3 shallow_color : source_color = vec3(0.35, 0.62, 0.58);
uniform vec3 foam_color : source_color = vec3(0.98, 0.95, 0.85);
uniform sampler2D tex_noise : filter_linear_mipmap, repeat_enable;
uniform float scale_m = 16.0;
uniform float speed = 0.03;
uniform float foam_amount = 0.18;
uniform float sparkle = 0.6;
// Chuva extra por material (somada à global env_rain, que vem do RainOverlay via WeatherWetness).
uniform float rain_amount : hint_range(0.0, 1.0) = 0.0;
// Reflexo pintado (céu claro em faixas suaves) e força das pinceladas de luz correndo com a correnteza.
uniform vec3 sky_tint : source_color = vec3(0.80, 0.92, 0.97);
uniform float reflect_amount : hint_range(0.0, 1.0) = 0.22;
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
	vec2 breeze = environment_breeze(wpos.xz, TIME);
	VERTEX.y += sin(TIME * 1.1 + dot(wpos.xz, vec2(0.65, 0.23))) * (0.018 + length(breeze) * 0.018);
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
	float shore_wave = sin(TIME * 1.15 - edge_v * 9.0 + n1 * 2.0);
	float foam = (1.0 - smoothstep(0.025, 0.14, abs(edge_v - 0.48 - shore_wave * 0.10))) * (0.45 + 0.25 * shore_wave);
	// ondinhas de espuma chegando na margem: duas linhas defasadas que andam do raso para a beira e somem
	float breakup = smoothstep(0.38, 0.62, n2);
	for (int k = 0; k < 2; k++) {
		float ph = fract(TIME * 0.22 + float(k) * 0.5 + n1 * 0.35);
		float line_at = mix(0.62, 0.10, ph);
		float lap = (1.0 - smoothstep(0.0, 0.045, abs(edge_v - line_at))) * sin(ph * 3.14159) * breakup;
		foam = max(foam, lap * 0.85);
	}
	col = mix(col, foam_color, foam * (use_depth_edge ? 0.42 : 0.7));
	ALPHA = clamp(smoothstep(0.05, 0.5, edge_v + (n1 - 0.5) * 0.15), 0.0, 1.0);
	float rain = clamp(max(rain_amount, env_rain), 0.0, 1.0);
	// reflexo pintado: céu em faixas pelo fresnel + pinceladas de luz alongadas correndo com a água
	float grazing = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float fres_band = floor(grazing * 3.0 + 0.5) / 3.0;
	float streak_n = texture(tex_noise, wpos.xz * vec2(0.035, 0.16) + vec2(TIME * speed * 1.6, 0.0)).r;
	float streak = floor(smoothstep(0.55, 0.78, streak_n) * 2.0 + 0.35) / 2.0;
	float open_water = smoothstep(0.35, 0.9, edge_v);
	col = mix(col, shallow_color * 1.12, grazing * 0.18);
	col = mix(col, sky_tint, clamp(fres_band * 0.35 + streak * 0.55, 0.0, 1.0) * reflect_amount * open_water * (1.0 - rain * 0.6));
	// chuva: céu fechado deixa a água mais cinza-azulada e os pingos abrem anéis claros
	col = mix(col, col * vec3(0.86, 0.92, 0.98), rain * 0.35);
	vec2 rain_tilt = vec2(0.0);
	if (rain > 0.02) {
		if (env_weather_detail > 0.5) {
			vec3 rr = env_rain_rings(wpos.xz, TIME, 0.75) + env_rain_rings(wpos.xz * 1.7 + 11.0, TIME * 1.3, 0.75) * 0.6;
			float k = smoothstep(0.02, 0.5, rain);
			col = mix(col, foam_color, clamp(rr.x, 0.0, 1.0) * 0.3 * k);
			rain_tilt = rr.yz * 0.22 * k;
		} else {
			float rain_ripple = sin(length(fract(wpos.xz * 1.5) - 0.5) * 42.0 - TIME * 13.0) * rain;
			rain_tilt = vec2(rain_ripple) * 0.055;
		}
	}
	ALBEDO = col;
	float wave = sin(dot(wpos.xz, vec2(2.1, 0.74)) - TIME * 1.7);
	float cross_wave = sin(dot(wpos.xz, vec2(-0.62, 1.8)) - TIME * 1.1);
	ROUGHNESS = 0.25 + rain * 0.12;
	SPECULAR = 0.5 * sparkle;
	// normal pintada leve a partir do ruído (brilho do sol quebrado)
	float dx = texture(tex_noise, p * 2.3 + vec2(0.01, 0.0) - vec2(TIME * speed * 0.7, -TIME * speed)).r - n2;
	float dz = texture(tex_noise, p * 2.3 + vec2(0.0, 0.01) - vec2(TIME * speed * 0.7, -TIME * speed)).r - n2;
	vec2 breeze = environment_breeze(wpos.xz, TIME);
	vec2 ripple = vec2(wave, cross_wave) * (0.026 + length(breeze) * 0.05) + rain_tilt;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(dx * 6.0 + ripple.x, 0.0, dz * 6.0 + ripple.y, 0.0)).xyz);
}
