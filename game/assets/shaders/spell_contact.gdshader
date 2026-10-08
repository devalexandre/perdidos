shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(0.2, 0.6, 1.0);
uniform float strength = 1.0;
uniform float progress = 0.0;
uniform bool billboard = false;
void vertex() {
	if (billboard) {
		mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		bb[0].xyz *= length(MODEL_MATRIX[0].xyz);
		bb[1].xyz *= length(MODEL_MATRIX[1].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	}
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float core = exp(-r * r * 35.0);
	float halo = exp(-r * r * 5.5) * 0.28;
	float rays = exp(-abs(p.x) * 65.0) * exp(-abs(p.y) * 4.5)
		+ exp(-abs(p.y) * 65.0) * exp(-abs(p.x) * 4.5);
	float rim = exp(-abs(r - mix(0.15, 0.85, progress)) * 70.0) * 0.24;
	float mask = core + halo + rays * (billboard ? 0.45 : 0.18) + rim;
	ALBEDO = mix(color, vec3(1.0), core * 0.75) * 1.7;
	ALPHA = clamp(mask, 0.0, 1.0) * strength * (1.0 - smoothstep(0.8, 1.0, r));
}
