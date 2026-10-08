shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(0.2, 0.6, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float opacity = 1.0;
uniform float phase = 0.0;
uniform bool healing = false;
uniform bool cone = false;
uniform float cone_width = 0.57735;
// 0 energia, 1 eletricidade, 2 fogo, 3 gelo, 4 cura.
uniform int element = 0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float travel = 1.0 - pow(1.0 - progress, 3.0);
	if (element == 1) travel = 1.0 - pow(1.0 - progress, 7.0);
	if (element == 3) travel = smoothstep(0.0, 0.55, progress);
	if (element == 4) travel = smoothstep(0.0, 1.0, progress);
	float wave = mix(0.13, 0.88, travel);
	if (element == 2) wave += (sin(angle * 11.0 - progress * 32.0) + sin(angle * 17.0 + progress * 21.0) * 0.5) * 0.028 * (1.0 - progress);
	if (element == 1) wave += sin(angle * 23.0 + progress * 90.0) * 0.016;
	float ring = exp(-abs(r - wave) * (element == 4 ? 65.0 : 110.0));
	float echo = exp(-abs(r - wave * 0.72) * 160.0) * 0.35;
	float sector = fract((angle + phase) / 6.283185 * 7.0);
	float fractures = exp(-abs(sector - 0.5) * 65.0) * smoothstep(0.18, 0.38, r)
		* (1.0 - smoothstep(wave * 0.85, wave, r));
	float breaks = smoothstep(-0.7, 0.2, sin(angle * 5.0 + phase));
	float mask = (ring * breaks + echo + fractures * (healing ? 0.12 : 0.5));
	if (cone) {
		mask *= (1.0 - smoothstep(cone_width * 0.88, cone_width, abs(p.x) / max(-p.y, 0.001))) * step(0.0, -p.y);
	}
	float fade = (1.0 - smoothstep(0.28, 1.0, progress)) * smoothstep(0.0, 0.04, progress);
	if (element == 1) fade = (1.0 - smoothstep(0.12, 0.65, progress));
	if (element == 4) fade = sin(progress * 3.141593) * 0.75;
	ALBEDO = color;
	EMISSION = color * (element == 1 ? 0.8 : 0.4);
	ALPHA = clamp(mask, 0.0, 1.0) * fade * opacity * 0.70;
}
