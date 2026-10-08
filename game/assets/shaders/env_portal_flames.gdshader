shader_type spatial;
render_mode unshaded, cull_disabled, blend_premul_alpha, depth_draw_never, shadows_disabled;
// Línguas de chama em pé do portal (PortalFx): um cilindro aberto por anel. Ruído rolando para cima recorta as
// línguas; alfa cai para o topo; cor da base (clara) para as pontas (violeta). Premultiplicado: quase aditivo,
// sem contorno escuro. O lado virado para a câmera fica mais baixo e mais transparente (personagem legível).
uniform float height = 1.0;
uniform float tongues = 14.0;
uniform vec3 base_color : source_color = vec3(0.45, 0.52, 1.0);
uniform vec3 tip_color : source_color = vec3(0.56, 0.36, 1.0);
uniform float strength = 0.9;
uniform float seed = 0.0;
// Fase acumulada no script (velocidade muda com a aproximação sem pular).
uniform float flow = 0.0;
uniform float proximity : hint_range(0.0, 1.0) = 0.0;

varying vec3 local_pos;
varying float front;

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 31.7) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i.x + i.y * 57.0);
	float b = hash(i.x + 1.0 + i.y * 57.0);
	float c = hash(i.x + (i.y + 1.0) * 57.0);
	float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	local_pos = VERTEX;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec2 out_dir = normalize(world.xz - center.xz + vec2(1e-4));
	vec2 cam_dir = normalize(CAMERA_POSITION_WORLD.xz - center.xz + vec2(1e-4));
	front = clamp(dot(out_dir, cam_dir), 0.0, 1.0);
	// Coroa: abre um pouco para fora no topo.
	float h = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
	VERTEX.xz *= 1.0 + h * 0.1;
}

void fragment() {
	float h = clamp(local_pos.y / height + 0.5, 0.0, 1.0);
	float turn = atan(local_pos.z, local_pos.x) / 6.283185 + 0.5;
	float u = turn * tongues + flow * 0.15;
	float id = mod(floor(u), tongues);
	float x = fract(u) - 0.5;
	// Altura de cada língua: varia por língua e tremula; perto do jogador sobe; na frente fica mais baixa.
	float tip = mix(0.5, 1.0, proximity) * (0.62 + 0.38 * hash(id));
	tip *= 0.86 + 0.14 * sin(flow * 3.1 + hash(id + 7.0) * 6.283185);
	tip *= mix(1.0, 0.62, front);
	float rel = h / max(tip, 0.01);
	// Largura afinando para cima, ondulando de lado (duas escalas de ruído: línguas tortas, não triângulos).
	float sway = (noise(vec2(id * 1.7, h * 2.2 - flow * 1.6)) - 0.5) * 0.7 * h
			+ (noise(vec2(u * 3.1, h * 5.0 - flow * 2.6)) - 0.5) * 0.25;
	float width = 0.68 * pow(clamp(1.0 - rel, 0.0, 1.0), 0.7);
	float d = abs(x + sway);
	float tongue = 1.0 - smoothstep(width * 0.35, width, d);
	// Ruído rolando para cima rói a língua (mais perto da ponta: pedaços se soltam).
	float n = noise(vec2(u * 1.3, h * 3.0 - flow * 2.2)) * 0.6 + noise(vec2(u * 3.3, h * 7.0 - flow * 3.6)) * 0.4;
	float body = tongue * smoothstep(0.12, 0.42, n + (1.0 - rel) * 0.6);
	// Brilho fino no pé, também roído (sem faixa sólida).
	float foot = pow(1.0 - h, 5.0) * 0.5 * (0.5 + 0.5 * n);
	float a = clamp(body + foot, 0.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, h));
	a *= strength * mix(0.75, 1.0, proximity) * mix(1.0, 0.6, front);
	// Miolo da língua mais claro; bordas e pontas no violeta.
	float core = (1.0 - smoothstep(0.0, width * 0.7, d)) * clamp(1.0 - rel, 0.0, 1.0);
	vec3 col = mix(base_color, tip_color, smoothstep(0.2, 0.9, rel));
	col = mix(col * 0.85, col * 1.15, core);
	col = mix(col, vec3(0.82, 0.88, 1.0), clamp(core * mix(0.2, 0.45, proximity), 0.0, 1.0));
	col *= mix(0.95, 1.3, proximity);
	ALBEDO = col * a;
	ALPHA = a * 0.8;
}
