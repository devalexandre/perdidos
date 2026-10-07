shader_type canvas_item;
// Troca de paleta do personagem (GDD §6.1 e §17.4; contrato ADENDO 2). 2D (Control/Sprite2D/TextureRect).
// Para Sprite3D use char_palette_swap_3d.gdshader (mesma lógica) ou CharacterLayers.bake_* (CPU).
//
// Codificação (tools/art/customization/common.py, STEP = 40): tom i -> valor 8 bits i*40+20
// (0 = mais escuro/contorno ... 5 = mais claro). Valor 0 = "não é desta rampa".
//   layer_mode 0 (corpo-base): cor da própria folha, exceto onde a máscara (mask_tex, mesma folha e mesmo
//                quadro) marca: R = pele, G = olhos, B = cabelo raspado (usa a rampa do cabelo).
//   layer_mode 1 (cabelo):     folha em rampa de cinza; o canal R é o tom da rampa do cabelo.
//   layer_mode 2 (normal):     sem troca (brincos, roupas, itens).
//   layer_mode 3 (olhos):      camada de olhos (tools/art/customization/eyes.py): (v,0,0) = pele tom v, (0,v,0) = íris
//                tom v (rampa dos olhos), demais cores literais (cílios, branco, reflexo).
// Amostragem sempre nearest; alfa binário (corte em 0.5); sem mistura entre tons -> pixels nítidos.

uniform int layer_mode = 0;
uniform sampler2D mask_tex : filter_nearest, repeat_disable;
uniform vec4 skin_ramp[6];
uniform vec4 hair_ramp[6];
uniform vec4 eye_ramp[6];

const float STEP = 40.0;

// Roupa por nacionalidade (CharacterLayers.recolor_cloth): tecido azul -> cloth_color, detalhe vermelho ->
// accent_color, mantendo o sombreado. Só no corpo-base, fora da máscara e fora da zona da cabeça
// (alfa 128 na máscara, tools/art/customization/cloth_zone.py).
uniform bool cloth_on = false;
uniform vec4 cloth_color = vec4(1.0);
uniform vec4 accent_color = vec4(1.0);

// Arquétipos visuais (1: Tanque, 2: Ágil/Lâmina, 3: Arcano, 4: Xamânico/Selvagem)
uniform int archetype_mode = 0;

vec3 rgb2hsl(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float l = (mx + mn) * 0.5;
	float d = mx - mn;
	float s = (l <= 0.0 || l >= 1.0) ? 0.0 : d / (1.0 - abs(2.0 * l - 1.0));
	float h = 0.0;
	if (d > 1e-5) {
		if (mx == c.r) { h = mod((c.g - c.b) / d, 6.0); }
		else if (mx == c.g) { h = (c.b - c.r) / d + 2.0; }
		else { h = (c.r - c.g) / d + 4.0; }
		h /= 6.0;
	}
	return vec3(h, s, l);
}

vec3 hsl2rgb(vec3 hsl) {
	vec3 k = mod(vec3(0.0, 8.0, 4.0) + hsl.x * 12.0, 12.0);
	float a = hsl.y * min(hsl.z, 1.0 - hsl.z);
	return hsl.z - a * max(vec3(-1.0), min(min(k - 3.0, 9.0 - k), vec3(1.0)));
}

vec3 recolor_cloth(vec3 c) {
	vec3 hsl = rgb2hsl(c);
	if (hsl.y < 0.2 || hsl.z < 0.08 || hsl.z > 0.92) {
		return c;
	}
	vec3 t;
	if (hsl.x >= 0.45 && hsl.x < 0.70) {
		t = rgb2hsl(cloth_color.rgb);
	} else if (hsl.x < 0.09 || hsl.x > 0.90) {
		t = rgb2hsl(accent_color.rgb);
	} else {
		return c;
	}
	float nl = clamp(t.z + (hsl.z - 0.29) * 1.1, 0.04, 0.96);
	float ns = clamp(t.y * (0.6 + 0.4 * hsl.y / 0.55), 0.0, 1.0);
	return hsl2rgb(vec3(t.x, ns, nl));
}

// No fragment() do canvas_item, COLOR já chega multiplicado pela textura: guarda só a modulação do vértice.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

int tone(float v) {
	return clamp(int(floor(v * 255.0 / STEP + 0.001)), 0, 5);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		discard;
	}
	vec3 rgb = c.rgb;
	if (layer_mode == 1) {
		rgb = hair_ramp[tone(c.r)].rgb;
	} else if (layer_mode == 0) {
		vec4 m = texture(mask_tex, UV);
		if (m.r > 0.02) {
			rgb = skin_ramp[tone(m.r)].rgb;
		} else if (m.g > 0.02) {
			rgb = eye_ramp[tone(m.g)].rgb;
		} else if (m.b > 0.02) {
			rgb = hair_ramp[tone(m.b)].rgb;
		} else if (cloth_on && m.a > 0.75) {
			rgb = recolor_cloth(rgb);
		}
	} else if (layer_mode == 3) {
		if (c.g < 0.002 && c.b < 0.002 && c.r > 0.02) {
			rgb = skin_ramp[tone(c.r)].rgb;
		} else if (c.r < 0.002 && c.b < 0.002 && c.g > 0.02) {
			rgb = eye_ramp[tone(c.g)].rgb;
		}
	}
	if (layer_mode == 0 && archetype_mode > 0) {
		vec3 hsl = rgb2hsl(rgb);
		if (archetype_mode == 1) {
			// Tanque: reforça áreas metálicas/placas com ligeiro ganho de contraste e brilho de carapaça
			if (hsl.z > 0.40 && hsl.y < 0.45) {
				rgb = clamp(rgb * 1.06 + vec3(0.02, 0.02, 0.015), 0.0, 1.0);
			}
		} else if (archetype_mode == 2) {
			// Ágil: contraste refinado em couro batido e faixas de tecido
			if (hsl.y > 0.20 && hsl.z > 0.18 && hsl.z < 0.82) {
				rgb = clamp(mix(rgb, rgb * rgb * 1.12, 0.12), 0.0, 1.0);
			}
		} else if (archetype_mode == 3) {
			// Arcano: pulso suave em bordados dourados/cianas místicas
			if (hsl.z > 0.50 && ((hsl.x > 0.08 && hsl.x < 0.22) || (hsl.x > 0.45 && hsl.x < 0.68))) {
				float pulse = sin(TIME * 2.8) * 0.12 + 0.06;
				rgb = clamp(rgb * (1.0 + pulse) + vec3(0.02, 0.04, 0.06) * pulse, 0.0, 1.0);
			}
		} else if (archetype_mode == 4) {
			// Xamânico: calor orgânico terroso em peles e penas
			if (hsl.z > 0.22 && hsl.z < 0.78) {
				rgb = clamp(rgb * vec3(1.03, 1.01, 0.96), 0.0, 1.0);
			}
		}
	}
	COLOR = vec4(rgb, 1.0) * v_modulate;
}
