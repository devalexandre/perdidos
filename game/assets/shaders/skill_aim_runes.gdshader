shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(0.2, 0.6, 1.0);
uniform float opacity = 0.85;
uniform float rune_count = 12.0;

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}
void fragment() {
	// PlaneMesh tem margem de 4%; o limite circular continua no raio exato da habilidade.
	vec2 p = (UV - 0.5) * 2.08;
	float radius = length(p);
	float aa = max(fwidth(radius), 0.003);
	float outer = 1.0 - smoothstep(aa, aa * 2.0, abs(radius - 1.0));
	float inner = 1.0 - smoothstep(aa * 0.75, aa * 1.5, abs(radius - 0.66));
	float angle = atan(p.y, p.x);
	float turn = (angle + 3.141593 + TIME * 0.035) / 6.283185 * rune_count;
	float index = floor(turn);
	vec2 q = vec2((fract(turn) - 0.5) * 2.0, (radius - 0.82) / 0.105);
	float mark = segment(q, vec2(0.0, -0.72), vec2(0.0, 0.72));
	mark = min(mark, segment(q, vec2(-0.45, -0.28), vec2(0.45, 0.28)));
	float variant = mod(index, 4.0);
	if (variant < 1.0) mark = min(mark, segment(q, vec2(0.0, 0.65), vec2(0.40, 0.28)));
	else if (variant < 2.0) mark = min(mark, segment(q, vec2(-0.40, -0.65), vec2(0.40, -0.65)));
	else if (variant < 3.0) mark = min(mark, segment(q, vec2(-0.40, 0.65), vec2(0.40, 0.65)));
	else mark = min(mark, segment(q, vec2(0.0, -0.65), vec2(-0.40, -0.28)));
	float rune_aa = max(fwidth(q.x), fwidth(q.y));
	float runes = (1.0 - smoothstep(0.035, 0.035 + rune_aa, mark)) * (1.0 - smoothstep(0.85, 1.0, abs(q.y)));
	float rune_glow = exp(-mark * mark * 70.0) * (1.0 - smoothstep(0.80, 1.0, abs(q.y)));
	float ticks = pow(max(0.0, cos(angle * 4.0)), 60.0)
		* (1.0 - smoothstep(0.015, 0.028, abs(radius - 0.94)));
	float fill = (1.0 - smoothstep(0.90, 1.0, radius)) * 0.018;
	float pulse = 0.85 + sin(TIME * 2.2) * 0.15;
	float soft_circle = outer * 0.18 + inner * 0.08 + ticks * 0.35 + fill;
	float mask = soft_circle + (runes * 0.90 + rune_glow * 0.14) * pulse;
	ALBEDO = color;
	EMISSION = color * (0.25 + runes * 3.2 + rune_glow * 0.4);
	ALPHA = clamp(mask * opacity, 0.0, 1.0);
}
