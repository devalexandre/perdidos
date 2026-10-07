shader_type spatial;
// Chao do Campo de Treino: textura pixel art repetivel (UV de mundo, 48 px/un.) + variacao em grande escala
// para quebrar a repeticao. A variacao e quantizada em 3 faixas com dithering ordenado na grade de pixels do
// mundo (sem gradiente suave, GDD 17.1).
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D macro_noise : repeat_enable, filter_linear;
uniform vec3 tint_dark : source_color = vec3(0.84, 0.86, 0.9);
uniform vec3 tint_light : source_color = vec3(1.08, 1.06, 0.96);
uniform float macro_scale = 0.018;
varying vec3 world_pos;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float n = texture(macro_noise, world_pos.xz * macro_scale).r;
	vec2 px = floor(world_pos.xz * 48.0);
	float lv = clamp(floor(n * 3.0 + (bayer4(px) - 0.5) * 0.9), 0.0, 2.0);
	vec3 t = lv < 0.5 ? tint_dark : (lv < 1.5 ? vec3(1.0) : tint_light);
	ALBEDO = c * t;
	ROUGHNESS = 1.0;
}
