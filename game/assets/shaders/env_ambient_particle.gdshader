shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

// 0 fumaça/névoa, 1 borboleta, 2 vaga-lume, 3 brasa. Sem texturas adicionais.
// Cenário vivo (08/10/2026, SceneryLife): 4 pontinho de luz/pólen/poeira (brilho macio que cintila devagar),
// 5 folha caindo (oval que gira e vira), 6 gota pingando (risco vertical claro), 7 morcego (silhueta batendo asa).
uniform int kind = 0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// false = quad deitado no chão (névoa rasteira em PlaneMesh): não vira para a câmera nem corta no chão.
uniform bool billboard = true;
varying vec4 particle_color;
varying float phase;

void vertex() {
	particle_color = COLOR;
	vec3 origin = MODEL_MATRIX[3].xyz;
	phase = dot(origin, vec3(7.1, 3.7, 5.3));
	if (billboard) {
		mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		bb[0].xyz *= length(MODEL_MATRIX[0].xyz);
		bb[1].xyz *= length(MODEL_MATRIX[1].xyz);
		bb[2].xyz *= length(MODEL_MATRIX[2].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	}
	if (kind == 1 || kind == 2) {
		VERTEX.x += sin(TIME * 1.7 + phase) * 0.25;
		VERTEX.y += sin(TIME * 2.1 + phase) * 0.15;
	} else if (kind == 4) {
		VERTEX.x += sin(TIME * 0.9 + phase) * 0.6;
		VERTEX.y += sin(TIME * 1.3 + phase * 1.7) * 0.35;
	} else if (kind == 5) {
		VERTEX.x += sin(TIME * 1.4 + phase) * 1.6;
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float mask = 1.0 - smoothstep(0.15, 1.0, length(p));
	vec3 col = particle_color.rgb;
	if (kind == 0) {
		float wisps = sin(p.x * 8.0 + p.y * 5.0 + TIME * 0.7 + phase) * 0.10;
		mask = 1.0 - smoothstep(0.1, 1.0, length(p) + wisps);
	} else if (kind == 1) {
		float flap = 0.25 + 0.75 * abs(sin(TIME * 12.0 + phase));
		vec2 wing = vec2((abs(p.x) - 0.38 * flap) / (0.45 * flap), p.y / 0.65);
		mask = 1.0 - smoothstep(0.75, 1.0, length(wing));
		col *= mix(0.55, 1.0, abs(p.x));
	} else if (kind == 2) {
		mask *= 0.25 + 0.75 * pow(0.5 + 0.5 * sin(TIME * 2.0 + phase), 2.0);
		col *= 1.7;
	} else if (kind == 4) {
		float r = length(p);
		mask = (1.0 - smoothstep(0.0, 1.0, r)) * 0.55 + (1.0 - smoothstep(0.0, 0.35, r)) * 0.45;
		mask *= 0.55 + 0.45 * sin(TIME * 1.6 + phase * 2.3);
		col *= 1.35;
	} else if (kind == 5) {
		// folha: largura vira com o giro (vê de frente/de lado), nervura escura e lado de baixo mais escuro
		float flip = sin(TIME * 3.1 + phase);
		float w = 0.22 + 0.78 * abs(flip);
		float c = cos(phase), sn = sin(phase);
		vec2 q = vec2(c * p.x - sn * p.y, sn * p.x + c * p.y);
		vec2 leaf = vec2(q.x / (0.55 * w), q.y / 0.95);
		mask = 1.0 - smoothstep(0.8, 1.0, length(leaf) + abs(q.y) * 0.25);
		col *= mix(0.62, 1.0, step(0.0, flip)) * (1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.06, abs(q.x))));
	} else if (kind == 6) {
		vec2 d = vec2(p.x / 0.28, p.y);
		mask = 1.0 - smoothstep(0.55, 1.0, length(d));
		col *= 1.6 + 0.6 * (1.0 - smoothstep(0.0, 0.5, length(p - vec2(0.0, -0.55))));
	} else if (kind == 7) {
		float flap = 0.35 + 0.65 * abs(sin(TIME * 9.0 + phase));
		float ax = abs(p.x);
		// asa: faixa que sobe para fora (curva do batimento) com borda de trás recortada em arcos
		float y_mid = (ax - 0.15) * (0.9 * flap - 0.35);
		float thick = 0.32 * (1.0 - smoothstep(0.55, 0.98, ax)) + 0.02;
		float scallop = 0.08 * abs(sin(ax * 14.0));
		// recorte em arcos só na borda de baixo (de trás) da asa
		float d_wing = abs(p.y - y_mid) + scallop * step(p.y, y_mid);
		float wing = 1.0 - smoothstep(thick - 0.04, thick, d_wing);
		float body = 1.0 - smoothstep(0.1, 0.16, length(vec2(p.x * 1.3, p.y + 0.05)));
		mask = max(wing * step(0.08, ax), body);
		col = vec3(0.07, 0.055, 0.09); // silhueta escura (o quad do morcego não tem cor de partícula)
	} else {
		col *= 1.8;
	}
	ALBEDO = col;
	ALPHA = mask * particle_color.a * opacity;
}
