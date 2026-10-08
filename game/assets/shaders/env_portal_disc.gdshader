shader_type spatial;
render_mode unshaded, cull_disabled, blend_premul_alpha, depth_draw_never, shadows_disabled;
// Disco de luz do portal (PortalFx), deitado no chão: centro muito claro (branco-azulado), corpo macio azul,
// ondas concêntricas lentas e runas sutis que acendem em sequência com a aproximação. Premultiplicado.
uniform vec3 core_color : source_color = vec3(0.78, 0.83, 1.0);
uniform vec3 rim_color : source_color = vec3(0.3, 0.36, 1.0);
uniform float proximity : hint_range(0.0, 1.0) = 0.0;
// Fase acumulada no script (as ondas correm mais rápido perto, sem pular).
uniform float wave = 0.0;
const float SECTORS = 16.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float body = 1.0 - smoothstep(0.55, 0.92, r);
	float core = exp(-r * r * 6.0);
	float waves = pow(0.5 + 0.5 * sin(r * 22.0 - wave * 4.0), 6.0) * body * (0.22 + 0.25 * proximity);
	// Runas: 16 marcas num anel; acendem em ordem angular, com um pulso correndo pelo trecho aceso.
	float turn = fract((angle + TIME * 0.1) / 6.283185);
	float sector = fract(turn * SECTORS);
	float index = floor(turn * SECTORS);
	float lit = clamp(proximity * (SECTORS + 1.0) - index, 0.0, 1.0);
	float pulse = pow(0.5 + 0.5 * cos((turn - TIME * 0.3) * 6.283185), 12.0) * lit;
	float glyph = (1.0 - smoothstep(0.08, 0.16, abs(sector - 0.5))) * exp(-abs(r - 0.66) * 90.0);
	float runes = glyph * (mix(0.04, 0.35, lit) + pulse * 0.3 + lit * (1.0 - lit) * 0.6);
	vec3 col = mix(rim_color, core_color, clamp(core * 1.2 + (1.0 - r) * 0.45, 0.0, 1.0));
	// Aros de luz macios no pé dos anéis de chama (0,65 m e 1,05 m, sobre o raio do disco de 1,2 m).
	float rims = (exp(-abs(r - 0.54) * 30.0) + exp(-abs(r - 0.875) * 30.0) * 0.7) * mix(0.2, 0.4, proximity);
	float glow = body * mix(0.55, 0.8, proximity) + core * mix(0.45, 0.75, proximity) + waves + runes + rims;
	ALBEDO = col * glow * mix(1.0, 1.25, proximity);
	ALPHA = clamp(glow * 0.75, 0.0, 0.85);
}
