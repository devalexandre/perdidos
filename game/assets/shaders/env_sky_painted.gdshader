shader_type sky;
// Céu pintado (GDD §17.0.A; direção da tela de título): degradê em faixas suaves, nuvens pintadas em camadas
// com borda clara do lado do sol, halo quente do sol e névoa no horizonte. Barato: só ruído procedural.
uniform vec3 top_color : source_color = vec3(0.32, 0.5, 0.78);
uniform vec3 mid_color : source_color = vec3(0.62, 0.74, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.98, 0.86, 0.66);
uniform vec3 ground_color : source_color = vec3(0.5, 0.52, 0.38);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.95, 0.86);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.66, 0.8);
uniform float cloud_cover = 0.45;
uniform float cloud_speed = 0.004;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.18, y));
	col = mix(col, top_color, smoothstep(0.18, 0.75, y));
	col = mix(col, ground_color, smoothstep(0.0, -0.25, y));
	// halo do sol
	vec3 sd = normalize(LIGHT0_DIRECTION);
	float sun = max(dot(d, sd), 0.0);
	col += horizon_color * pow(sun, 8.0) * 0.35 + vec3(1.0, 0.95, 0.8) * pow(sun, 300.0) * 2.0;
	// nuvens pintadas (plano projetado)
	if (y > 0.0) {
		vec2 uv = d.xz / (y + 0.12) * 1.3 + vec2(TIME * cloud_speed, 0.0);
		float n = fbm(uv * 1.1);
		float m = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.18, n);
		float lit = clamp(fbm(uv * 1.1 + sd.xz * 0.12) - n + 0.55, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_light, lit);
		col = mix(col, cc, m * smoothstep(0.0, 0.12, y) * 0.9);
	}
	COLOR = col;
}
