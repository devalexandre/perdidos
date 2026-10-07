shader_type spatial;
// Folhagem pintada do kit (GDD §17.0.A): copas volumosas, cards de folhas, capim, flores.
// - Albedo = textura pintada × cor de vértice (RGB = oclusão/tinta pintada na geração da malha).
// - COLOR.a = peso do vento (0 no tronco/base, 1 nas pontas).
// - Normais "esféricas" gravadas na malha (a partir do centro da copa) → sombreamento macio de volume.
// - Translucidez (luz passando pelas folhas quando o sol está atrás) e luz "enrolada" (lambert wrap).
// - Variação de cor por instância: pela posição no mundo (hash) ou INSTANCE_CUSTOM (MultiMesh).
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec2 uv_scale = vec2(1.0);
// Recorte por alfa (cards). 0 = opaco (malhas de copa).
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform bool use_alpha = true;
// Vento.
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.3;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind_gust_scale = 0.08;
// Translucidez e variação.
uniform vec3 backlight_color : source_color = vec3(0.45, 0.50, 0.18);
uniform float hue_variation = 0.10;
uniform float value_variation = 0.14;
// Base escurecida (capim/flores "saindo" do chão) — usa UV.y do card (1 = base).
uniform float base_darken = 0.0;
uniform vec3 base_color : source_color = vec3(0.30, 0.38, 0.16);
// Desbotar ao longe (cards pequenos somem suavemente antes do corte da MultiMesh).
uniform float fade_start = 1000.0;
uniform float fade_end = 1100.0;
uniform bool use_instance_custom = false;
// Recolorir (ipê, sakura, outono...): cor = gradiente escuro→claro pela luminância da textura original.
uniform float recolor_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 recolor_dark : source_color = vec3(0.55, 0.30, 0.05);
uniform vec3 recolor_light : source_color = vec3(1.0, 0.85, 0.25);
// Pontinhos de outra cor espalhados (folhinhas verdes no meio das flores, flores no arbusto).
// Quanto a oclusão pintada (cor de vértice) comanda o gradiente (topo da copa claro, dentro/baixo escuro).
uniform float recolor_ao_mix : hint_range(0.0, 1.0) = 0.7;
uniform float speckle_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 speckle_color : source_color = vec3(0.35, 0.55, 0.2);
uniform float speckle_scale = 9.0;

varying vec4 vcolor;
varying float var_seed;
varying float var_dist;
varying float var_wy;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vcolor = COLOR;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	var_seed = use_instance_custom ? INSTANCE_CUSTOM.r : hash12(origin.xz);
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = dot(wpos.xz, wind_dir) * 0.35 + var_seed * 6.2831;
	float gust = 0.6 + 0.4 * sin(TIME * 0.37 + dot(origin.xz, vec2(wind_gust_scale)));
	float sway = sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.3;
	vec3 disp = vec3(wind_dir.x, 0.0, wind_dir.y) * sway * wind_strength * gust * COLOR.a;
	// Deslocamento no espaço do mundo convertido para o do modelo (escala/rotação da instância).
	VERTEX += (inverse(MODEL_MATRIX) * vec4(disp, 0.0)).xyz;
	var_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	var_wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	UV *= uv_scale;
}

// Copas entre a câmera e o jogador (centro da tela) ficam pontilhadas/transparentes para não esconder o personagem.
uniform float occlude_near_m = 15.5;
uniform float occlude_radius = 0.2;

void fragment() {
	{
		vec2 dc = (SCREEN_UV - vec2(0.5, 0.52)) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		float rad = length(dc);
		// só copas (acima de ~2 m) na frente/em volta do jogador no centro da tela
		float near_f = smoothstep(1.6, 2.6, var_wy) * (1.0 - smoothstep(occlude_near_m + 12.0, occlude_near_m + 16.0, -VERTEX.z));
		float hole = (1.0 - smoothstep(occlude_radius * 0.6, occlude_radius, rad)) * near_f;
		if (hole > 0.0) {
			// pontilhado ordenado 4x4
			ivec2 q = ivec2(FRAGCOORD.xy) % 4;
			float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
			if (hole * 0.85 > (bayer[q.y * 4 + q.x] + 0.5) / 16.0) {
				discard;
			}
		}
	}
	// Folhas de face dupla: mantém a normal "esférica" da malha também na face de trás.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec4 tex = texture(albedo_tex, UV);
	vec3 base = tex.rgb;
	if (recolor_amount > 0.0) {
		float l = smoothstep(0.08, 0.75, dot(base, vec3(0.3, 0.55, 0.15)));
		l = mix(l, smoothstep(0.45, 1.05, vcolor.r), recolor_ao_mix);
		base = mix(base, mix(recolor_dark, recolor_light, l), recolor_amount);
		if (speckle_amount > 0.0) {
			float h = fract(sin(dot(floor(UV * speckle_scale), vec2(12.9898, 78.233))) * 43758.5453);
			base = mix(base, speckle_color * (0.6 + l * 0.6), step(1.0 - speckle_amount, h));
		}
	}
	vec3 col = base * mix(vec3(1.0), vcolor.rgb, 1.0 - recolor_amount * 0.65) * tint;
	// Variação por instância: leve giro de matiz para o amarelo/azul e de valor.
	float v = var_seed - 0.5;
	col *= 1.0 + v * value_variation * 2.0;
	col = mix(col, col * vec3(1.08, 1.04, 0.82), clamp(v * hue_variation * 8.0, 0.0, 1.0));
	col = mix(col, col * vec3(0.88, 0.98, 1.06), clamp(-v * hue_variation * 8.0, 0.0, 1.0));
	if (base_darken > 0.0) {
		float b = smoothstep(0.45, 1.0, UV.y / uv_scale.y);
		col = mix(col, base_color, b * base_darken);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	BACKLIGHT = backlight_color;
	if (use_alpha) {
		float fade = 1.0 - smoothstep(fade_start, fade_end, var_dist);
		ALPHA = tex.a * fade;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	}
}
