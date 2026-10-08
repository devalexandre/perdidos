// Clima compartilhado (08/10/2026): uniforms GLOBAIS (project.godot [shader_globals]) alimentados num ponto só,
// WeatherWetness.publish (day_night_light.gd), a partir da meta &"weather_visual" que o RainOverlay grava no mapa.
//  env_rain           chuva agora (0..1, já com a rampa de ~6 s do RainOverlay)
//  env_wetness        umidade acumulada (sobe ~30 s com chuva forte, seca ~75 s depois)
//  env_weather_detail 1 = respingos/anéis animados; 0 = preset Baixa (só escurecer/poças paradas)
#ifndef ENV_WEATHER_INC
#define ENV_WEATHER_INC

global uniform float env_rain;
global uniform float env_wetness;
global uniform float env_weather_detail;

float env_weather_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Quanto a chuva abafa fogo (0..1): a chuva agora manda; depois dela a lenha molhada segura a chama um tempo.
// Mesma conta de WeatherWetness.fire_damp (GDScript) para a luz da fogueira.
float env_fire_damp() {
	return clamp(max(env_rain, env_wetness * 0.6), 0.0, 1.0);
}

// Anéis de pingos: cada célula (cell_m metros) tem um pingo que nasce num ponto sorteado e abre um anel que some.
// Retorna (brilho do anel, inclinação x, inclinação z) para clarear a cor e entortar a normal. Duas camadas
// defasadas para não pulsar em bloco.
vec3 env_rain_rings(vec2 p, float time, float cell_m) {
	vec3 acc = vec3(0.0);
	for (int layer = 0; layer < 2; layer++) {
		vec2 q = p / cell_m + vec2(float(layer) * 0.37, float(layer) * 0.71);
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float h = env_weather_hash(cell + float(layer) * 17.0);
		vec2 c = vec2(0.25) + vec2(h, env_weather_hash(cell.yx + 3.1)) * 0.5;
		float t = fract(time * (0.9 + h * 0.5) + h * 7.0);
		vec2 d = f - c;
		float r = length(d);
		float ring = 1.0 - smoothstep(0.0, 0.05, abs(r - t * 0.42));
		ring *= (1.0 - t) * (1.0 - t);
		vec2 dir = r > 0.001 ? d / r : vec2(0.0);
		acc += vec3(ring, dir * ring);
	}
	return acc;
}

// Chão molhado + poças (terrenos). Entradas: p = XZ (m); level = 1 no plano, 0 na encosta; low = 1 na baixada;
// n_big/n_small = ruídos 0..1 do próprio chão; trail = máscara de terra/trilha (0 na grama, flores, calçamento, rocha).
// Grama: só escurece e ganha um brilho leve de molhado. Terra: fica marrom escura e saturada, e nas partes baixas da
// trilha abrem poças esparsas (borda macia, halo de terra mais escura, centro azul-acinzentado suave refletindo o
// céu, realce fino na borda virada para a luz e anéis de pingo).
// Mexe em col; devolve (rugosidade, especular, inclinação x, inclinação z) para o fragment aplicar.
// Seco (env_wetness = 0): col intacta, rugosidade 1 e especular 0 (igual ao chão antigo).
vec4 env_wet_ground(inout vec3 col, vec2 p, float level, float low, float n_big, float n_small, float trail, float time) {
	float w = clamp(env_wetness, 0.0, 1.0);
	// campo das poças e suas derivadas de tela (antes de qualquer desvio: derivadas pedem fluxo uniforme)
	float field = n_big * 0.8 + n_small * 0.2 + low * 0.1;
	vec2 grad = vec2(dFdx(field), dFdy(field));
	if (w <= 0.001) {
		return vec4(1.0, 0.0, 0.0, 0.0);
	}
	float dirt = clamp(trail, 0.0, 1.0);
	// 1) molhado: grama um pouco mais escura e viva; terra marrom escura e saturada (nada de cinza)
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 wet_grass = mix(vec3(l), col, 1.12) * 0.84;
	vec3 wet_dirt = col * vec3(0.70, 0.57, 0.43);
	col = mix(col, mix(wet_grass, wet_dirt, dirt), w * 0.9);
	float rough = mix(1.0, mix(0.72, 0.5, dirt), w);
	float spec = mix(0.10, 0.2, dirt) * w;
	// 2) poças: só na terra plana; o limiar desce com a umidade (~10–15% da trilha encharcada no máximo)
	float th = mix(1.05, 0.67, smoothstep(0.4, 1.0, w));
	float mask = smoothstep(0.55, 0.9, dirt) * level;
	float halo = smoothstep(th - 0.12, th, field) * mask;
	float pool = smoothstep(th, th + 0.07, field) * mask;
	col *= mix(1.0, 0.78, halo * w); // halo de terra mais encharcada em volta
	vec2 tilt = vec2(0.0);
	if (pool > 0.001) {
		vec3 sky = vec3(0.56, 0.64, 0.72);
		float center = smoothstep(th + 0.03, th + 0.16, field);
		// fundo marrom-terra escuro, refletindo um pouco do céu; azul-acinzentado suave só no centro
		vec3 puddle = col * 0.62;
		puddle = mix(puddle, mix(puddle, sky * 0.8, 0.22), 0.35 + 0.65 * center);
		// realce claro e fino na borda virada para a luz (sol do alto à esquerda na tela)
		float edge_band = smoothstep(th, th + 0.02, field) * (1.0 - smoothstep(th + 0.025, th + 0.06, field));
		float facing = clamp(dot(normalize(grad + vec2(1e-6)), normalize(vec2(-0.6, -0.8))), 0.0, 1.0);
		puddle = mix(puddle, sky * 1.15, edge_band * facing * 0.45);
		// pingos: anéis só enquanto chove e se a qualidade permitir
		if (env_weather_detail > 0.5 && env_rain > 0.02) {
			vec3 rr = env_rain_rings(p, time, 0.5);
			float k = smoothstep(0.02, 0.6, env_rain);
			puddle += vec3(0.16, 0.18, 0.2) * rr.x * k * (0.4 + 0.6 * center);
			tilt = rr.yz * 0.3 * k * pool;
		}
		col = mix(col, puddle, pool);
		rough = mix(rough, 0.18, pool);
		spec = mix(spec, 0.3, pool);
	}
	return vec4(rough, spec, tilt);
}

// --- Sombras de nuvem (cenário vivo, 08/10/2026) -------------------------------------------------------------
// Global env_clouds publicado por SceneryLife (scenery_life.gd) só no mapa em que o jogador está:
//  x = força (0 = desligado: caverna, noite, neblina forte, preset Baixa); y = cobertura 0..1 (chuva = mais nuvem);
//  z, w = deriva das nuvens (m/s no plano XZ).
// Manchas grandes (~40 m) e de borda bem macia, andando devagar; o chão, as plantas e as paredes escurecem juntos.
global uniform vec4 env_clouds;

float env_value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = env_weather_hash(i);
	float b = env_weather_hash(i + vec2(1.0, 0.0));
	float c = env_weather_hash(i + vec2(0.0, 1.0));
	float d = env_weather_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Multiplicador de cor (1 = sol pleno; ~0.7 debaixo da nuvem). p = XZ do mundo (m).
float env_cloud_shade(vec2 p, float time) {
	if (env_clouds.x <= 0.001) {
		return 1.0;
	}
	vec2 q = (p - env_clouds.zw * time) / 38.0;
	float n = env_value_noise(q) * 0.62 + env_value_noise(q * 2.13 + vec2(17.3, 5.1)) * 0.38;
	float cover = clamp(env_clouds.y, 0.0, 1.0);
	float th = mix(0.78, 0.36, cover);
	float c = smoothstep(th - 0.16, th + 0.16, n);
	return 1.0 - c * env_clouds.x;
}

#endif
