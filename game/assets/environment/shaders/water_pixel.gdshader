shader_type spatial;
// Agua pixel art: textura da paleta com rolagem em passos de 1 texel (sem borrar), leve brilho.
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec2 scroll_texels_per_sec = vec2(2.0, 3.0);
uniform float tex_size = 64.0;
uniform vec2 uv_scale = vec2(1.0);

void fragment() {
	vec2 offset = floor(scroll_texels_per_sec * TIME) / tex_size;
	vec2 uv = UV * uv_scale + offset;
	vec2 uv2 = UV * uv_scale * 0.5 - offset * 0.5 + vec2(0.37, 0.11);
	vec3 a = texture(albedo_tex, uv).rgb;
	vec3 b = texture(albedo_tex, uv2).rgb;
	// mistura por limiar (nao por media), mantendo cores da paleta
	ALBEDO = (dot(b, vec3(0.33)) > dot(a, vec3(0.33)) + 0.12) ? b : a;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
