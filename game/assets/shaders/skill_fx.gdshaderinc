// Efeitos de skill (SkillFx): folha em linha (hframes quadros) ou em grade (hframes colunas x vframes
// linhas, quadro a quadro da esquerda para a direita, de cima para baixo), filtro nearest, sem luz.
// FX_SMOOTH (skill_fx_*_smooth.gdshader, efeitos "anime" de assets/fx/anime/): filtro linear com mipmaps.
// billboard = vira para a camera (com giro "roll" na tela e deslocamento em profundidade);
// senao, o quad fica como a malha foi montada (deitado no chao).
#ifdef FX_SMOOTH
uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
#else
uniform sampler2D sheet : source_color, filter_nearest, repeat_disable;
#endif
uniform int hframes = 1;
uniform int vframes = 1;
uniform int frame = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float fade = 1.0;
uniform bool billboard = true;
uniform float roll = 0.0;
uniform float depth_bias = 0.0;
uniform float flip = 1.0;
uniform bool charge_recolor = false;
uniform vec3 charge_color : source_color = vec3(0.18, 0.56, 1.0);

void vertex() {
	int hf = max(hframes, 1);
	UV = vec2((UV.x + float(frame % hf)) / float(hf), (UV.y + float(frame / hf)) / float(max(vframes, 1)));
	if (billboard) {
		vec2 sc = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
		vec2 v = VERTEX.xy * sc * vec2(flip, 1.0);
		float c = cos(roll);
		float s = sin(roll);
		v = vec2(v.x * c - v.y * s, v.x * s + v.y * c);
		vec4 vp = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
		vp.xy += v;
		vp.z += depth_bias;
		POSITION = PROJECTION_MATRIX * vp;
	} else {
		// Quem escreve POSITION num ramo precisa escrever em todos (senão o quad deitado some).
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	}
}

void fragment() {
	vec4 t = texture(sheet, UV);
	vec3 rgb = charge_recolor ? charge_color * max(t.r, max(t.g, t.b)) : t.rgb;
	ALBEDO = rgb * tint.rgb;
	ALPHA = t.a * tint.a * fade;
}
