shader_type spatial;
// Sprites de cenario agrupados numa malha por textura (1 draw call): os 4 vertices de cada quad ficam na
// origem do sprite (VERTEX) e o canto vem em UV2 (unidades do mundo). O quad gira so em Y para a camera.
// Pixel art (nearest), recorte de alfa, sem sombreamento (como os Sprite3D de enfeite da cidade).
render_mode unshaded, cull_disabled, depth_prepass_alpha, skip_vertex_transform;
uniform sampler2D tex : source_color, filter_nearest;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 right = normalize(vec3(to_cam.z, 0.0, -to_cam.x));
	vec3 world = origin + right * UV2.x + vec3(0.0, UV2.y, 0.0);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(to_cam, 0.0)).xyz);
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) discard;
	ALBEDO = c.rgb;
}
