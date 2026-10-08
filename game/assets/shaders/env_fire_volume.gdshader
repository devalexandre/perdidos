shader_type spatial;
// Línguas com superfície tridimensional. Turbulência atravessa o volume e rompe a pele da chama.
// Chuva (env_fire_damp, global): chama mais baixa, mais vermelha e mais rala.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#include "res://assets/shaders/env_weather.gdshaderinc"
uniform float height = 1.4;
uniform float radius = 0.28;
uniform float phase = 0.0;
uniform bool core = false;
varying vec3 flame_pos;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float noise3(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
		mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
		mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	flame_pos = VERTEX;
	float y = VERTEX.y;
	float t = TIME + phase;
	VERTEX.xz *= radius * (0.86 + 0.14 * sin(y * 11.0 - t * 7.0));
	VERTEX.x += (sin(y * 5.0 - t * 3.9) * 0.17 + sin(t * 1.7) * 0.08) * y * y;
	VERTEX.z += sin(y * 7.0 - t * 3.1 + phase) * 0.14 * y * y;
	VERTEX.y *= height * (0.88 + 0.12 * sin(t * 4.3)) * (1.0 - env_fire_damp() * 0.22);
}
void fragment() {
	float y = flame_pos.y;
	vec3 flow = flame_pos * vec3(3.1, 4.6, 3.1) + vec3(phase, -TIME * 2.5, phase * 0.7);
	float n = noise3(flow) * 0.65 + noise3(flow * 2.1) * 0.35;
	float heat = clamp((1.0 - y) * 0.75 + n * 0.45, 0.0, 1.0);
	vec3 orange = vec3(1.0, 0.065, 0.005);
	vec3 hot = core ? vec3(1.0, 0.30, 0.025) : vec3(1.0, 0.18, 0.012);
	vec3 color = mix(orange, hot, smoothstep(0.25, 0.90, heat));
	float breakup = smoothstep(0.20 + y * 0.34, 0.54 + y * 0.27, n);
	float ends = smoothstep(0.0, 0.06, y) * (1.0 - smoothstep(0.65, 1.0, y));
	float damp = env_fire_damp();
	color = mix(color, color * vec3(0.92, 0.7, 0.7), damp * 0.5);
	ALBEDO = color;
	EMISSION = color * (core ? 0.50 : 0.35) * (1.0 - damp * 0.45);
	ALPHA = breakup * ends * (core ? 0.82 : 0.65) * (1.0 - damp * 0.2);
}
