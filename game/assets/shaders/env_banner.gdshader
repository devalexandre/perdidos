shader_type spatial;
// Bandeira com brasão (GDD §4.0.1 / brasões das cidades): tecido tremulando, dupla face, recorte por alfa.
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D banner_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float wave_amp = 0.08;
uniform float wave_speed = 2.2;
uniform float wave_freq = 5.0;
void vertex() {
	// UV.x = 0 no mastro; a ponta livre ondula mais.
	float free = UV.x;
	VERTEX.z += sin(TIME * wave_speed + UV.x * wave_freq + NODE_POSITION_WORLD.x) * wave_amp * free;
	VERTEX.y += sin(TIME * wave_speed * 0.7 + UV.x * 3.0) * wave_amp * 0.3 * free;
}
void fragment() {
	vec4 c = texture(banner_tex, UV);
	if (c.a < 0.5) { discard; }
	ALBEDO = c.rgb * (FRONT_FACING ? 1.0 : 0.85);
	ROUGHNESS = 0.9;
}
