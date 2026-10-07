shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Uma única célula da WalkGrid. O miolo é suave; a borda deixa a grade legível sem cobrir a pintura.
void fragment() {
	vec2 edge = abs(UV - vec2(0.5)) * 2.0;
	float square = max(edge.x, edge.y);
	float rim = smoothstep(0.84, 0.93, square) * (1.0 - smoothstep(0.96, 1.0, square));
	float fill = (1.0 - smoothstep(0.78, 1.0, square)) * 0.10;
	ALBEDO = vec3(1.0, 0.94, 0.69);
	ALPHA = fill + rim * 0.32;
}
