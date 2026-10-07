shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;
// Sprite de personagem/NPC/monstro no mundo 3D (GDD §17.0.C "não parecer papel", §17.2, ADENDO 2).
// Um só shader para todas as camadas do DirectionalSprite3D (corpo, roupa, cabelo, olhos, armas...):
//  - troca de paleta (layer_mode 0/1/3; 2 = cores literais da folha) — mesma codificação de char_palette_swap.gdshader;
//  - pixel art nítida em qualquer escala: "pixel AA" (cada texel é um bloco sólido; só a fronteira entre dois texels
//    ganha 1 px de transição). Em escala inteira equivale ao filtro nearest. filter_mode 1 = nearest puro, 2 = linear
//    (só para o controle negativo dos testes). Técnica adaptada de "Sub-Pixel Accurate Pixel-Sprite Filtering"
//    (mortarroad, godotshaders.com/shader/sub-pixel-accurate-pixel-sprite-filtering/, licença CC0): fator de mistura
//    clamp((f - 0.5) / fwidth + 0.5). Aqui a mistura é feita à mão com 4 texelFetch, DEPOIS de decodificar a paleta
//    de cada texel (a troca de cor precisa dos valores exatos da folha/máscara). Registro: assets/environment/LICENSES.md;
//  - recebe a luz da cena: cor/intensidade do sol e da luz ambiente, sombras projetadas (árvores, casas) e luzes
//    pontuais (fogueira, lampiões). Lado da sombra em 2–3 tons (normal "cilíndrica" falsa, constante por texel,
//    sem gradiente suave) e contorno de cima levemente aceso pelo céu (rim);
//  - sombra projetada própria: na passada de sombra o quadro vira para o sol, com a altura real (sem o esticão
//    da inclinação), e projeta a silhueta no chão pelo mapa de sombras (junta-se às sombras do cenário);
//  - flash branco do golpe (flash) e sumiço pontilhado (modulate.a × fade).
// O Sprite3D NÃO passa a própria textura para um ShaderMaterial: o DirectionalSprite3D define sheet_tex (= a mesma
// folha do sprite) e mask_tex. O UV do Sprite3D (hframes/vframes/frame/flip_h) já aponta para o quadro certo.
// Billboard: o Sprite3D com material_override perde o billboard próprio, por isso ele é feito aqui (eixo Y).

uniform int layer_mode = 2;
uniform bool billboard_y = true;
// Sem source_color: a folha e a máscara são lidas cruas (a máscara precisa dos valores exatos).
uniform sampler2D sheet_tex : filter_nearest, repeat_disable;
uniform sampler2D mask_tex : filter_nearest, repeat_disable;
uniform vec4 skin_ramp[6];
uniform vec4 hair_ramp[6];
uniform vec4 eye_ramp[6];
uniform vec4 modulate : source_color = vec4(1.0);
// Lado do quadro (texels; quadros quadrados). Limita as amostras ao quadro atual (sem vazar do vizinho).
uniform float frame_px = 96.0;
uniform int filter_mode = 0;
// Esticão vertical aplicado no nó (1/cos da inclinação da câmera): a sombra projetada usa a altura real.
uniform float pitch_comp = 1.0;
// Quanto o sprite está acima do chão agora (pulo/quique). Hoje só informativo (a sombra projetada sobe junto,
// como na física; a sombra dos pés fica no chão).
uniform float lift = 0.0;
uniform bool cast_planar_shadow = true;
// Resposta à luz.
uniform float sun_gain = 0.52;
uniform float shade_mid = 0.9;
uniform float shade_side = 0.78;
uniform float cast_shadow_floor = 0.3;
uniform float point_gain = 0.7;
uniform float emission_floor = 0.05;
// Meia largura do corpo (fração do quadro) para a normal falsa.
uniform float body_half_width = 0.22;
uniform vec3 rim_color : source_color = vec3(0.80, 0.90, 1.0);
uniform float rim_strength = 0.16;
uniform float flash = 0.0;
uniform float fade = 1.0;
// Só para testes automáticos: cores exatas da folha (sem luz, banda, contorno aceso).
uniform bool unlit = false;

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

varying float v_side_sign;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

int tone(float v) {
	return clamp(int(floor(v * 255.0 / STEP + 0.001)), 0, 5);
}

// Texel decodificado (rgb linear, a).
vec4 decode(ivec2 t) {
	vec4 c = texelFetch(sheet_tex, t, 0);
	vec3 rgb = to_linear(c.rgb);
	if (layer_mode == 1) {
		rgb = hair_ramp[tone(c.r)].rgb;
	} else if (layer_mode == 0) {
		vec4 m = texelFetch(mask_tex, t, 0);
		if (m.r > 0.02) {
			rgb = skin_ramp[tone(m.r)].rgb;
		} else if (m.g > 0.02) {
			rgb = eye_ramp[tone(m.g)].rgb;
		} else if (m.b > 0.02) {
			rgb = hair_ramp[tone(m.b)].rgb;
		} else if (cloth_on && m.a > 0.75) {
			rgb = to_linear(recolor_cloth(c.rgb));
		}
	} else if (layer_mode == 3) {
		if (c.g < 0.002 && c.b < 0.002 && c.r > 0.02) {
			rgb = skin_ramp[tone(c.r)].rgb;
		} else if (c.r < 0.002 && c.b < 0.002 && c.g > 0.02) {
			rgb = eye_ramp[tone(c.g)].rgb;
		}
	}
	if (layer_mode == 0 && archetype_mode > 0) {
		vec3 hsl = rgb2hsl(c.rgb);
		if (archetype_mode == 1) {
			// Tanque: realce metálico e placas reforçadas
			if (hsl.z > 0.40 && hsl.y < 0.45) {
				rgb = clamp(rgb * 1.06 + to_linear(vec3(0.02, 0.02, 0.015)), 0.0, 1.0);
			}
		} else if (archetype_mode == 2) {
			// Ágil: contraste refinado em couro batido e faixas
			if (hsl.y > 0.20 && hsl.z > 0.18 && hsl.z < 0.82) {
				rgb = clamp(mix(rgb, rgb * rgb * 1.12, 0.12), 0.0, 1.0);
			}
		} else if (archetype_mode == 3) {
			// Arcano: pulso suave em bordados e auras místicas
			if (hsl.z > 0.50 && ((hsl.x > 0.08 && hsl.x < 0.22) || (hsl.x > 0.45 && hsl.x < 0.68))) {
				float pulse = sin(TIME * 2.8) * 0.12 + 0.06;
				rgb = clamp(rgb * (1.0 + pulse) + to_linear(vec3(0.02, 0.04, 0.06)) * pulse, 0.0, 1.0);
			}
		} else if (archetype_mode == 4) {
			// Xamânico: calor orgânico terroso em peles e penas
			if (hsl.z > 0.22 && hsl.z < 0.78) {
				rgb = clamp(rgb * vec3(1.03, 1.01, 0.96), 0.0, 1.0);
			}
		}
	}
	return vec4(rgb, c.a);
}

void vertex() {
	if (IN_SHADOW_PASS) {
		// Quadro em pé virado para o sol, com a altura real (sem o esticão da inclinação da câmera): a silhueta
		// projetada no chão fica com o comprimento certo para a altura do sol.
		vec3 to_light = INV_VIEW_MATRIX[2].xyz;
		vec3 right = cross(vec3(0.0, 1.0, 0.0), to_light);
		right = length(right) > 0.001 ? normalize(right) : vec3(1.0, 0.0, 0.0);
		vec3 origin = MODEL_MATRIX[3].xyz;
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz) / max(pitch_comp, 0.001);
		vec3 p = origin + right * VERTEX.x * sx + vec3(0.0, VERTEX.y * sy, 0.0);
		if (!cast_planar_shadow) {
			p = origin - vec3(0.0, 1000.0, 0.0);
		}
		MODELVIEW_MATRIX = VIEW_MATRIX;
		VERTEX = p;
	} else if (billboard_y) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	}
}

// Pontilhado ordenado 4x4 (sumiço sem transparência "lavada").
float bayer4(vec2 frag) {
	ivec2 q = ivec2(frag) % 4;
	float b[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (b[q.y * 4 + q.x] + 0.5) / 16.0;
}

void fragment() {
	vec2 tsize = vec2(textureSize(sheet_tex, 0));
	vec2 tc = UV * tsize;
	// Quadro atual (a partir do centro do texel mais próximo).
	vec2 near_t = floor(tc);
	ivec2 lo = ivec2(floor((near_t + 0.5) / frame_px) * frame_px);
	ivec2 hi = lo + ivec2(int(frame_px)) - 1;
	hi = min(hi, ivec2(tsize) - 1);
	if (IN_SHADOW_PASS) {
		if (texelFetch(sheet_tex, clamp(ivec2(near_t), lo, hi), 0).a < 0.5) {
			discard;
		}
		ALBEDO = vec3(0.0);
	} else {
		vec4 c;
		if (filter_mode == 1) {
			c = decode(clamp(ivec2(near_t), lo, hi));
		} else {
			vec2 p = tc - 0.5;
			vec2 i = floor(p);
			vec2 f = p - i;
			vec2 s = f;
			if (filter_mode == 0) {
				vec2 fw = max(fwidth(tc), vec2(1e-4));
				s = clamp((f - 0.5) / fw + 0.5, 0.0, 1.0);
			}
			ivec2 i0 = ivec2(i);
			vec4 a = decode(clamp(i0, lo, hi));
			vec4 b = decode(clamp(i0 + ivec2(1, 0), lo, hi));
			vec4 d = decode(clamp(i0 + ivec2(0, 1), lo, hi));
			vec4 e = decode(clamp(i0 + ivec2(1, 1), lo, hi));
			vec4 top = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), s.x);
			vec4 bot = mix(vec4(d.rgb * d.a, d.a), vec4(e.rgb * e.a, e.a), s.x);
			vec4 m = mix(top, bot, s.y);
			c = vec4(m.rgb / max(m.a, 1e-4), m.a);
		}
		float vis = modulate.a * fade;
		if (c.a < 0.5 || (vis < 0.999 && vis <= bayer4(FRAGCOORD.xy))) {
			discard;
		}
		vec3 col = c.rgb * modulate.rgb;
		// Normal falsa (espaço da vista), constante por texel: cilindro vertical em volta do corpo, puxada para cima.
		vec2 q = (near_t + 0.5 - vec2(lo)) / frame_px; // 0..1 no quadro (y para baixo)
		float screen_dir = sign(dFdx(tc.x));
		screen_dir = screen_dir == 0.0 ? 1.0 : screen_dir;
		float nx = clamp((q.x - 0.5) * screen_dir / body_half_width, -1.0, 1.0);
		float ny = 0.35 + (0.55 - q.y) * 0.5;
		NORMAL = normalize(vec3(nx * 0.85, ny, sqrt(max(0.08, 1.0 - nx * nx * 0.7))));
		// Contorno de cima/lados aceso pelo céu: texel opaco com vizinho transparente acima (ou dos lados).
		ivec2 nt = ivec2(near_t);
		float up_a = texelFetch(sheet_tex, clamp(nt - ivec2(0, 1), lo, hi), 0).a;
		float l_a = texelFetch(sheet_tex, clamp(nt - ivec2(1, 0), lo, hi), 0).a;
		float r_a = texelFetch(sheet_tex, clamp(nt + ivec2(1, 0), lo, hi), 0).a;
		float edge = (up_a < 0.5 ? 1.0 : 0.0) + ((l_a < 0.5 || r_a < 0.5) ? 0.45 : 0.0);
		edge = min(edge, 1.0) * step(q.y, 0.8);
		ALBEDO = col * (1.0 - flash);
		EMISSION = col * (emission_floor + rim_color * rim_strength * edge) + vec3(flash * 0.85);
		if (unlit) {
			ALBEDO = vec3(0.0);
			EMISSION = col;
		}
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (unlit) {
		DIFFUSE_LIGHT += vec3(0.0);
	} else if (LIGHT_IS_DIRECTIONAL) {
		// 3 tons: luz cheia, meio-tom, lado da sombra. Sombra projetada nunca apaga tudo (cast_shadow_floor).
		float band = ndl > 0.2 ? 1.0 : (ndl > -0.25 ? shade_mid : shade_side);
		float shadow = mix(cast_shadow_floor, 1.0, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * sun_gain * band * shadow;
	} else {
		float wrap = ndl > -0.2 ? 1.0 : 0.6;
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * point_gain * wrap;
	}
}
