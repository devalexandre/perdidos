shader_type spatial;
// Terreno orgânico do Campo de Treino (GDD §17.0.A, revisão 5): UMA malha com relevo (morros, cristas entre as
// zonas, margens de rio e lagoas) e 11 camadas pintadas à mão misturadas por 3 mapas de mistura em coordenadas de
// mundo (splat_a/b/c). Encostas íngremes viram rocha automaticamente; partes baixas (margens) escurecem e ficam
// úmidas; pinceladas grandes de ruído dão o aspecto "pintado" e quebram a repetição.
//  base = grama
//  splat_a: R terra (trilha)   G calçamento   B areia      A rocha
//  splat_b: R neve             G capim seco   B chão de mata  A cascalho
//  splat_c: R terra vermelha   G grama viçosa B urze/prado  A (livre)
render_mode diffuse_lambert_wrap, specular_disabled;

uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_lush : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_paving : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_snow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_dry : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_jungle : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_red : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D splat_a : filter_linear, repeat_disable;
uniform sampler2D splat_b : filter_linear, repeat_disable;
uniform sampler2D splat_c : filter_linear, repeat_disable;
uniform vec2 splat_origin = vec2(-120.0, -120.0);
uniform vec2 splat_size = vec2(240.0, 240.0);

uniform float tile_m = 6.0;
uniform float blend_softness = 0.2;
uniform float edge_noise = 0.28;
uniform vec3 macro_warm : source_color = vec3(1.08, 1.0, 0.78);
uniform vec3 macro_cool : source_color = vec3(0.78, 0.9, 0.8);
uniform float macro_strength = 0.22;
// "Pinceladas": manchas alongadas claras/escuras em duas escalas.
uniform float brush_strength = 0.075;
uniform float slope_rock_start = 0.86;
uniform float slope_rock_end = 0.66;
uniform vec3 heather_tint : source_color = vec3(0.86, 0.78, 0.95);
uniform float wet_depth = 0.6;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 rot(vec2 p, float a) {
	return vec2(cos(a) * p.x - sin(a) * p.y, sin(a) * p.x + cos(a) * p.y);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hb(float w, vec3 c, float n) {
	float bs = max(blend_softness, 0.01);
	float en = max(edge_noise, 0.0);
	float x = w + (lum(c) - 0.5) * 0.4 + (n - 0.5) * en;
	return smoothstep(0.5 - bs, 0.5 + bs, x);
}

vec3 tex2(sampler2D t, vec2 p, float m) {
	float sc = max(m, 0.01);
	return mix(texture(t, p / sc).rgb, texture(t, rot(p, 1.3) / (sc * 2.3)).rgb, 0.35);
}

void fragment() {
	vec2 p = wp.xz;
	float nm = texture(tex_noise, p / 40.0).r;
	float nmid = texture(tex_noise, p / 9.0 + vec2(0.31, 0.77)).r;
	float nf = texture(tex_noise, p / 2.1).r;
	float en = mix(nf, nmid, 0.5);
	vec2 s_size = max(splat_size, vec2(0.1, 0.1));
	vec2 suv = (p - splat_origin) / s_size;
	vec4 a = texture(splat_a, suv);
	vec4 b = texture(splat_b, suv);
	vec4 c = texture(splat_c, suv);

	float tm = max(tile_m, 0.01);
	vec3 m_cool = macro_cool.rgb;
	vec3 m_warm = macro_warm.rgb;
	vec3 h_tint = heather_tint.rgb;

	vec3 grass = mix(tex2(tex_grass, p, tm), vec3(0.30, 0.47, 0.23), 0.24);
	grass *= mix(vec3(1.0), mix(m_cool, m_warm, smoothstep(0.25, 0.75, nm)), macro_strength);
	vec3 col = grass;
	col = mix(col, tex2(tex_lush, p, tm * 1.1) * vec3(0.92, 1.02, 0.9), hb(c.g, grass, en));
	col = mix(col, tex2(tex_grass, p, tm) * h_tint, hb(c.b, grass, en));
	col = mix(col, tex2(tex_dry, p, tm), hb(b.g, col, en));
	col = mix(col, tex2(tex_jungle, p, tm * 0.9), hb(b.b, col, en));
	col = mix(col, tex2(tex_snow, p, tm * 1.2), hb(b.r, col, en));
	col = mix(col, tex2(tex_sand, p, tm), hb(a.b, col, en));
	col = mix(col, tex2(tex_gravel, p, 3.0), hb(b.a, col, en));
	col = mix(col, tex2(tex_paving, p, 4.0), hb(a.g, col, en));
	col = mix(col, tex2(tex_red, p, 5.0), hb(c.r, col, en));
	col = mix(col, mix(tex2(tex_dirt, p, 3.2), vec3(0.66, 0.55, 0.39), 0.40), hb(a.r, col, en));
	// rocha: pintada no mapa ou automática nas encostas (triplanar simples nas faces íngremes)
	float s_end = min(slope_rock_end, slope_rock_start - 0.01);
	float slope = 1.0 - smoothstep(s_end, slope_rock_start, wn.y);
	vec3 rock_side = mix(texture(tex_rock, wp.zy / 5.0).rgb, texture(tex_rock, wp.xy / 5.0).rgb, abs(wn.z));
	vec3 rock = mix(tex2(tex_rock, p, 5.0), rock_side, slope);
	col = mix(col, rock * vec3(1.0, 0.97, 0.92), clamp(hb(a.a, col, en) + slope * 1.2, 0.0, 1.0));
	// margens baixas: terra úmida escura
	float wd = max(wet_depth, 0.01);
	float wet = 1.0 - smoothstep(-wd, -0.05, wp.y);
	col = mix(col, col * vec3(0.55, 0.52, 0.45), wet * 0.8);
	// topo dos morros um pouco mais claro e quente (luz pintada)
	col *= 1.0 + clamp(wp.y / 12.0, 0.0, 0.25) * vec3(1.0, 0.9, 0.6);
	// pinceladas
	float br = texture(tex_noise, rot(p, 0.6) * vec2(0.09, 0.35)).r * 0.6 + texture(tex_noise, rot(p, -0.9) * vec2(0.25, 0.8)).r * 0.4;
	col *= 1.0 + (br - 0.5) * 2.0 * brush_strength;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
