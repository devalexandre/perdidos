// Corpo comum de env_terrain.gdshader (opaco) e env_terrain_decal.gdshader (manchas com borda macia).

uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_grass_alt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_cobble : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Ruído suave e tileável (NoiseTexture2D seamless) para variação macro e bordas.
uniform sampler2D tex_noise : filter_linear_mipmap, repeat_enable;

// Metros cobertos por uma repetição de cada textura.
uniform float grass_tile_m = 6.0;
uniform float dirt_tile_m = 5.0;
uniform float cobble_tile_m = 3.0;
uniform float sand_tile_m = 6.0;
uniform float rock_tile_m = 5.0;

// Fonte da mistura: 0 = só grama; 1 = cor de vértice (COLOR); 2 = mapa em coordenadas de mundo (XZ).
uniform int splat_source : hint_range(0, 2) = 2;
uniform sampler2D splat_map : filter_linear, repeat_disable;
uniform vec2 splat_origin = vec2(-32.0, -32.0);
uniform vec2 splat_size = vec2(64.0, 64.0);

// Variação macro da grama.
uniform float macro_scale_m = 38.0;
uniform vec3 macro_warm : source_color = vec3(1.10, 1.02, 0.72);
uniform vec3 macro_cool : source_color = vec3(0.70, 0.86, 0.72);
uniform float macro_strength = 0.55;
uniform float grass_alt_amount = 0.35;
// Tinta geral de cada camada (ajuste fino por mapa sem regerar textura).
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform vec3 dirt_tint : source_color = vec3(1.0);
uniform vec3 cobble_tint : source_color = vec3(1.0);
uniform vec3 sand_tint : source_color = vec3(1.0);
uniform vec3 rock_tint : source_color = vec3(1.0);
// Largura da borda "pintada" das transições.
uniform float blend_softness = 0.22;
uniform float edge_noise = 0.35;

varying vec3 world_pos;
varying vec4 vcolor;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcolor = COLOR;
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Mistura por "altura": a camada de cima invade pelas partes claras (pedras/torrões) primeiro.
float hblend(float w, float h, float n) {
	float x = w + (h - 0.5) * 0.45 + (n - 0.5) * edge_noise;
	return smoothstep(0.5 - blend_softness, 0.5 + blend_softness, x);
}

void fragment() {
	vec2 p = world_pos.xz;
	float n_macro = texture(tex_noise, p / macro_scale_m).r;
	float n_mid = texture(tex_noise, p / 7.0 + vec2(0.37, 0.71)).r;
	float n_fine = texture(tex_noise, p / 1.7).r;

	// Grama: duas escalas + variante, tingidas por manchas macro quentes/frias.
	vec3 g1 = texture(tex_grass, p / grass_tile_m).rgb;
	vec3 g2 = texture(tex_grass, rot(p, 1.1) / (grass_tile_m * 2.7)).rgb;
	vec3 g3 = texture(tex_grass_alt, rot(p, -0.6) / (grass_tile_m * 1.3)).rgb;
	vec3 grass = mix(g1, g2, smoothstep(0.3, 0.7, n_mid) * 0.5);
	grass = mix(grass, g3, smoothstep(0.55, 0.85, n_macro) * grass_alt_amount);
	vec3 macro = mix(macro_cool, macro_warm, smoothstep(0.25, 0.75, n_macro));
	grass *= mix(vec3(1.0), macro, macro_strength) * grass_tint;

	vec3 dirt = texture(tex_dirt, p / dirt_tile_m).rgb * dirt_tint;
	dirt = mix(dirt, texture(tex_dirt, rot(p, 0.8) / (dirt_tile_m * 2.3)).rgb * dirt_tint, 0.35);
	vec3 cobble = texture(tex_cobble, p / cobble_tile_m).rgb * cobble_tint;
	vec3 sand = texture(tex_sand, p / sand_tile_m).rgb * sand_tint;
	vec3 rock = texture(tex_rock, p / rock_tile_m).rgb * rock_tint;

	vec4 w = vec4(0.0);
	if (splat_source == 1) {
		w = vcolor;
	} else if (splat_source == 2) {
		vec2 suv = (p - splat_origin) / splat_size;
		w = texture(splat_map, suv);
	}
	float edge_n = mix(n_fine, n_mid, 0.5);
	vec3 col = grass;
	col = mix(col, sand, hblend(w.b, lum(sand), edge_n));
	col = mix(col, dirt, hblend(w.r, lum(dirt), edge_n));
	col = mix(col, cobble, hblend(w.g, lum(cobble), edge_n));
	col = mix(col, rock, hblend(w.a, lum(rock), edge_n));

	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
#ifdef DECAL
	// Borda macia pintada: alfa da cor de vértice (0 na franja externa) "comido" por ruído.
	ALPHA = clamp(smoothstep(0.0, 1.0, vcolor.a * 1.25 + (edge_n - 0.5) * 0.7), 0.0, 1.0);
#endif
}
