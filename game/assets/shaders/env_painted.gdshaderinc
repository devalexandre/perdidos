// Corpo comum de env_painted.gdshader (face única) e env_painted_2s.gdshader (duas faces).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform bool triplanar = false;
// Metros por repetição no modo triplanar; no modo UV, multiplicador de UV.
uniform float tile_m = 3.0;
uniform vec2 uv_scale = vec2(1.0);
uniform bool use_vertex_ao = false;
// Topo com musgo/grama.
uniform sampler2D top_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float top_amount : hint_range(0.0, 1.0) = 0.0;
uniform float top_sharpness = 6.0;
uniform float top_tile_m = 2.0;
uniform vec3 top_tint : source_color = vec3(1.0);
// Sujeira na base (altura em metros acima de base_y, no mundo).
uniform float grime_height = 0.0;
uniform float base_y = 0.0;
uniform vec3 grime_color : source_color = vec3(0.55, 0.45, 0.35);
// Variação de cor macro no mundo (quebra repetição em paredes longas).
uniform sampler2D tex_noise : filter_linear_mipmap, repeat_enable;
uniform float macro_strength = 0.12;
uniform float roughness = 1.0;
// < 1 acalma texturas "ocupadas" (mistura com a cor média local, de um mip alto).
uniform float detail : hint_range(0.0, 1.0) = 1.0;
// Cor por instância do MultiMesh (INSTANCE_CUSTOM.gba): paredes de cores diferentes com 1 draw call.
uniform bool use_instance_tint = false;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 vcolor;
varying vec3 inst_tint;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcolor = COLOR;
	inst_tint = use_instance_tint ? INSTANCE_CUSTOM.gba : vec3(1.0);
}

vec3 tri(sampler2D t, vec3 p, vec3 n, float scale) {
	vec3 b = pow(abs(n), vec3(4.0));
	float b_sum = b.x + b.y + b.z;
	b = b_sum > 0.0001 ? b / b_sum : vec3(0.0, 1.0, 0.0);
	float sc = max(scale, 0.001);
	vec3 x = texture(t, p.zy / sc).rgb;
	vec3 y = texture(t, p.xz / sc).rgb;
	vec3 z = texture(t, p.xy / sc).rgb;
	return x * b.x + y * b.y + z * b.z;
}

vec3 tri_lod(sampler2D t, vec3 p, vec3 n, float scale, float lod) {
	vec3 b = pow(abs(n), vec3(4.0));
	float b_sum = b.x + b.y + b.z;
	b = b_sum > 0.0001 ? b / b_sum : vec3(0.0, 1.0, 0.0);
	float sc = max(scale, 0.001);
	return textureLod(t, p.zy / sc, lod).rgb * b.x + textureLod(t, p.xz / sc, lod).rgb * b.y
			+ textureLod(t, p.xy / sc, lod).rgb * b.z;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 col;
	vec3 avg;
	float det = clamp(detail, 0.0, 1.0);
	if (triplanar) {
		col = tri(albedo_tex, wpos, wnrm, tile_m);
		avg = det < 1.0 ? tri_lod(albedo_tex, wpos, wnrm, tile_m, 5.0) : col;
	} else {
		col = texture(albedo_tex, UV * uv_scale).rgb;
		avg = det < 1.0 ? textureLod(albedo_tex, UV * uv_scale, 5.0).rgb : col;
	}
	col = mix(avg, col, det);
	col *= tint * inst_tint;
	float n = texture(tex_noise, wpos.xz / 23.0 + wpos.y / 31.0).r;
	float n2 = texture(tex_noise, wpos.xz / 7.3 - wpos.y / 17.0).r;
	float n_comb = n * 0.7 + n2 * 0.3;
	vec3 warm_shift = mix(vec3(0.96, 0.94, 0.91), vec3(1.04, 1.02, 0.98), n_comb);
	col *= warm_shift * (1.0 + (n_comb - 0.5) * 2.0 * macro_strength);
	if (top_amount > 0.0) {
		vec3 top = texture(top_tex, wpos.xz / max(top_tile_m, 0.001)).rgb * top_tint;
		float t = clamp((wnrm.y - (1.0 - top_amount)) * top_sharpness + (n - 0.5), 0.0, 1.0);
		col = mix(col, top, t);
	}
	if (grime_height > 0.0) {
		float g = 1.0 - smoothstep(0.0, grime_height, wpos.y - base_y);
		col = mix(col, col * grime_color, g * 0.8);
	}
	if (use_vertex_ao && dot(vcolor.rgb, vcolor.rgb) > 0.001) {
		col *= vcolor.rgb;
	}
	ALBEDO = col;
#ifdef DECAL
	float en = texture(tex_noise, wpos.xz / 4.0).r * 0.6 + texture(tex_noise, wpos.xz / 1.3).r * 0.4;
	ALPHA = clamp(smoothstep(0.0, 1.0, vcolor.a * 1.25 + (en - 0.5) * 0.7), 0.0, 1.0);
#endif
#ifdef ALPHA_CUT
	ALPHA = texture(albedo_tex, UV * uv_scale).a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
	ROUGHNESS = max(roughness, 0.0);
	SPECULAR = 0.0;
}
