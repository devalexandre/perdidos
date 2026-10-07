shader_type canvas_item;
// Pós-processo de tela do mundo 3D (GDD §17.0.A), aplicado no TextureRect que mostra a SubViewport.
// - Tilt-shift: desfoque suave só nas faixas de cima e de baixo (a faixa central, onde fica o
//   jogador, é amostrada sem filtro e fica 100% nítida: sprites continuam "nearest").
// - Vinheta: escurece e esquenta os cantos; o centro fica intacto (fator exatamente 1).
// A interface é desenhada por cima e não passa por aqui.

// Mesma textura do nó (a imagem da SubViewport), com filtro linear para os toques do desfoque.
uniform sampler2D scene_linear : filter_linear, repeat_disable;
// Metade da altura da faixa nítida (0..1 em UV.y, a partir do centro).
uniform float focus_half_band = 0.34;
// Distância (em UV.y) para o desfoque ir de 0 ao máximo depois da faixa nítida.
uniform float blur_ramp = 0.30;
// Raio máximo do desfoque em pixels da tela (em cima); embaixo usa near_blur_scale disso.
uniform float max_blur_px = 1.2;
uniform float near_blur_scale = 0.55;
// Vinheta: raio (em UV, corrigido pelo aspecto) onde começa, largura da transição e força.
uniform float vignette_start = 0.52;
uniform float vignette_width = 0.55;
uniform float vignette_strength = 0.16;
uniform vec3 vignette_tint : source_color = vec3(0.30, 0.20, 0.12);
uniform bool enable_blur = true;
// "Traço de pincel": escurece levemente onde a luminância muda bruscamente (contornos pintados à mão).
uniform float ink_strength = 0.10;
uniform float ink_threshold = 0.06;
uniform bool enable_vignette = true;

const int TAPS = 16;
const float GOLDEN_ANGLE = 2.39996323;

void fragment() {
	vec4 sharp = texture(TEXTURE, UV);
	vec3 col = sharp.rgb;
	if (ink_strength > 0.0) {
		vec2 px = SCREEN_PIXEL_SIZE;
		float lc = dot(col, vec3(0.3, 0.59, 0.11));
		float l1 = dot(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb, vec3(0.3, 0.59, 0.11));
		float l2 = dot(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb, vec3(0.3, 0.59, 0.11));
		float l3 = dot(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb, vec3(0.3, 0.59, 0.11));
		float l4 = dot(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb, vec3(0.3, 0.59, 0.11));
		// só o lado escuro da borda escurece (traço fino, sem halo claro)
		float e = max(max(l1, l2), max(l3, l4)) - lc;
		float ink = smoothstep(ink_threshold, ink_threshold + 0.18, e);
		col *= 1.0 - ink * ink_strength;
	}
	float dy = abs(UV.y - 0.5);
	float t = clamp((dy - focus_half_band) / blur_ramp, 0.0, 1.0);
	t = t * t * (3.0 - 2.0 * t);
	if (enable_blur && t > 0.0) {
		float radius = max_blur_px * t * (UV.y > 0.5 ? near_blur_scale : 1.0);
		vec3 acc = vec3(0.0);
		for (int i = 0; i < TAPS; i++) {
			float fi = float(i) + 0.5;
			float r = sqrt(fi / float(TAPS)) * radius;
			float a = fi * GOLDEN_ANGLE;
			acc += texture(scene_linear, UV + vec2(cos(a), sin(a)) * r * SCREEN_PIXEL_SIZE).rgb;
		}
		col = acc / float(TAPS);
	}
	if (enable_vignette) {
		// Normalizado pela largura: borda lateral = 1, borda de cima/baixo = altura/largura.
		vec2 d = (UV - 0.5) * 2.0 * vec2(1.0, SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y);
		float v = clamp((length(d) - vignette_start) / vignette_width, 0.0, 1.0);
		v = v * v * (3.0 - 2.0 * v) * vignette_strength;
		col = mix(col, col * vignette_tint * 1.6, v);
	}
	COLOR = vec4(col, 1.0);
}
