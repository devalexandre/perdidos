shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(0.25, 0.65, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform bool billboard = true;
void vertex() {
	if (billboard) {
		vec2 scale = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
		vec4 center = VIEW_MATRIX * MODEL_MATRIX[3];
		center.xy += VERTEX.xy * scale;
		center.z -= 0.12;
		POSITION = PROJECTION_MATRIX * center;
	} else {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float speed = 2.0 + progress * 2.0;
	float swirl = sin(angle * 3.0 - radius * 9.0 - TIME * speed);
	float ribbon = smoothstep(0.35, 0.9, swirl) * smoothstep(0.42, 0.60, radius) * (1.0 - smoothstep(0.8, 1.0, radius));
	// Anéis quebrados giram em sentidos opostos; o externo converge conforme a carga cresce.
	float ring_radius = mix(0.90, 0.80, progress);
	float segments = smoothstep(-0.2, 0.15, sin(angle * 6.0 + TIME * 1.7));
	float outer = exp(-abs(radius - ring_radius) * 110.0) * segments;
	float inner = exp(-abs(radius - 0.68) * 95.0) * smoothstep(0.2, 0.5, cos(angle * 3.0 - TIME * 2.4));
	float beads = pow(max(0.0, cos(angle * 6.0 + TIME * 1.7)), 36.0)
		* exp(-abs(radius - ring_radius) * 55.0);
	float mask = billboard ? ribbon * 0.65 + outer * 0.45 + beads : outer + inner + beads;
	vec3 highlight = mix(color, vec3(0.40, 0.88, 1.0), beads * 0.65);
	ALBEDO = highlight * (0.75 + progress * 0.4);
	EMISSION = highlight * 0.35;
	ALPHA = mask * fade * (0.42 + progress * 0.30);
}
