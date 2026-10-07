shader_type spatial;
// Cristal mágico (renascimento): facetas lapidadas com gradiente de cor por altura e por faceta, brilho interno
// pulsando devagar e borda fresnel clara. Emissivo: o glow do Environment faz o halo.
render_mode diffuse_lambert, specular_schlick_ggx, cull_back;

uniform vec3 deep_color : source_color = vec3(0.12, 0.42, 0.92);
uniform vec3 light_color : source_color = vec3(0.58, 0.94, 1.0);
uniform vec3 rim_color : source_color = vec3(0.92, 0.98, 1.0);
uniform float emission_strength = 2.6;
uniform float pulse_speed = 1.1;
uniform float height_m = 3.6;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

float hash(vec3 p) {
	return fract(sin(dot(floor(p * 7.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	float h = clamp(lpos.y / height_m, 0.0, 1.0);
	// cada faceta (normal diferente) recebe um tom levemente diferente → aspecto lapidado
	float facet = hash(NORMAL * 3.0 + vec3(0.3));
	vec3 col = mix(deep_color, light_color, clamp(h * 0.8 + facet * 0.35, 0.0, 1.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed + lpos.y * 1.5);
	ALBEDO = col * 0.6;
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.8;
	EMISSION = (col * (0.55 + 0.45 * h) + rim_color * fres * 0.9) * emission_strength * pulse;
}
