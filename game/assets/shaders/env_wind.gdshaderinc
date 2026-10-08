// Brisa compartilhada: rajadas atravessam o cenário, detalhes locais evitam movimento em bloco.
// Com chuva forte (env_rain, global) o vento engrossa: só a amplitude cresce (mudar a frequência com o tempo
// global acumulado faria a fase disparar durante a rampa da chuva).
#ifndef ENV_WIND_INC
#define ENV_WIND_INC
#include "res://assets/shaders/env_weather.gdshaderinc"

float environment_storm() {
	return 1.0 + clamp(env_rain, 0.0, 1.0) * 0.85;
}

vec2 environment_breeze(vec2 world_xz, float time) {
	float storm = environment_storm();
	float front = dot(world_xz, normalize(vec2(1.0, 0.35)));
	float gust = 0.55 + 0.45 * sin(time * 0.43 - front * 0.09);
	float sway = sin(time * 1.3 - front * 0.22);
	return normalize(vec2(1.0, 0.35)) * (0.28 + sway * 0.42) * gust * storm;
}

// Balanço da planta inteira (cenário vivo, 08/10/2026): tronco firme no pé e copa indo e voltando junto.
// Mesma conta no tronco (env_painted) e nas folhas (env_foliage), pela posição de mundo SEM deslocamento, então as
// duas partes andam juntas. Média zero (a pose parada é a da malha). Peso = (altura acima do pé / altura da planta)²,
// a força vem por nó (instance uniform veg_bend, em metros no topo; 0 = não é planta, nada muda).
// Devolve o deslocamento XZ no mundo.
vec2 environment_plant_bend(vec2 world_xz, float height_above_base, float plant_height, float amount, float time) {
	float k = clamp(height_above_base / max(plant_height, 0.5), 0.0, 1.4);
	k *= k;
	float front = dot(world_xz, normalize(vec2(1.0, 0.35)));
	float gust = 0.55 + 0.45 * sin(time * 0.31 - front * 0.045);
	float sway = sin(time * 0.95 - front * 0.06) * 0.72 + sin(time * 1.85 - front * 0.11 + 1.3) * 0.28;
	vec2 dir = normalize(vec2(1.0, 0.35));
	// um pouco de giro de lado para a copa "rodar" em vez de só ir e vir
	vec2 side = vec2(-dir.y, dir.x) * sin(time * 0.7 - front * 0.05 + 2.1) * 0.3;
	return (dir * sway + side) * gust * environment_storm() * amount * k;
}
#endif
