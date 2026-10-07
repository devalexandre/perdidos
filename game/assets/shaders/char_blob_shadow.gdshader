shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

// Sombra macia colada aos pés dos sprites (GDD §17.0.C).
// Desenha uma elipse suave com blend_mix e canal alpha, garantindo que
// qualquer área fora da elipse seja 100% transparente em todas as plataformas
// (desktop, mobile, Vulkan, OpenGL/Compatibility), sem nunca gerar quadrados pretos.

uniform vec3 shadow_tint : source_color = vec3(0.08, 0.1, 0.14);
uniform float opacity = 0.55;
uniform vec3 sun_dir = vec3(0.35, -0.8, 0.45);
uniform float sun_strength = 1.0;
uniform float sun_shift = 0.15;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	// Leve deslocamento na direção oposta à luz do sol
	vec2 sh = sun_dir.xz;
	float horiz = length(sh);
	vec2 sdir = horiz > 0.0001 ? sh / horiz : vec2(0.0, 1.0);
	uv -= sdir * (sun_shift * clamp(sun_strength, 0.0, 1.0) * 0.35);

	// Proporção elíptica da sombra (ligeiramente achatada em Y para a projeção isométrica)
	uv.y *= 1.4;
	float dist = length(uv) * 2.0; // 0.0 no centro, 1.0 na borda do círculo

	// Núcleo suave com borda macia (decaimento radial para alpha zero na borda)
	float a = clamp(1.0 - smoothstep(0.15, 0.95, dist), 0.0, 1.0);
	a *= opacity * mix(0.55, 1.0, clamp(sun_strength, 0.0, 1.0));

	ALBEDO = shadow_tint;
	ALPHA = a;
}

