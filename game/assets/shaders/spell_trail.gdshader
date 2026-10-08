shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(0.2, 0.6, 1.0);
uniform float fade = 1.0;
void fragment() {
	float edge = pow(max(0.0, 1.0 - abs(UV.y - 0.5) * 2.0), 1.5);
	float taper = smoothstep(0.0, 0.55, UV.x);
	ALBEDO = mix(color, vec3(0.70, 0.94, 1.0), pow(edge, 6.0) * 0.45);
	EMISSION = color * 0.25;
	ALPHA = edge * taper * fade * 0.65;
}
