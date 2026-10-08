shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.35, 0.08);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform float phase = 0.0;
varying float altitude;
void vertex() {
	altitude = UV.y;
	float sway = altitude * altitude;
	VERTEX.x += (sin(altitude * 9.0 - age * 17.0 + phase) * 0.15 + sin(age * 11.0 + phase) * 0.06) * sway;
	VERTEX.z += sin(altitude * 12.0 - age * 14.0 + phase) * 0.14 * sway;
	VERTEX.y *= 0.88 + 0.12 * sin(age * 15.0 + phase);
}
void fragment() {
	float turbulence = sin(UV.x * 31.0 + altitude * 17.0 - age * 21.0 + phase)
		+ sin(UV.x * 19.0 - altitude * 23.0 + age * 29.0) * 0.45;
	float breakup = smoothstep(-0.55, 0.45 + altitude * 0.6, turbulence);
	float ends = smoothstep(0.0, 0.08, altitude) * (1.0 - smoothstep(0.6, 1.0, altitude));
	vec3 heat = mix(color, vec3(1.0, 0.8, 0.32), (1.0 - altitude) * 0.65);
	ALBEDO = heat;
	EMISSION = heat * 0.65;
	ALPHA = breakup * ends * opacity * 0.75;
}
