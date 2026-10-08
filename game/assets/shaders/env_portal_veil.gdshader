shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	// La malha antiga do Campo foi consolidada em coordenadas do mapa, sem depender de UV.
	float flow = sin(local_position.y * 4.0 - TIME * 1.8 + sin(local_position.x * 3.0 + TIME));
	float fine = sin(local_position.y * 13.0 + local_position.z * 9.0 - TIME * 3.0);
	vec3 color = mix(vec3(0.08, 0.25, 0.62), vec3(0.32, 0.80, 0.94), flow * 0.5 + 0.5);
	ALBEDO = color;
	EMISSION = color * (0.45 + max(fine, 0.0) * 0.2);
	ALPHA = 0.48 + flow * 0.12;
}
