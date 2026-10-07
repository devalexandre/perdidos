shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform sampler2D grass : source_color, repeat_enable;
uniform sampler2D litter : source_color, repeat_enable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_position.xz;
 float patches = smoothstep(-0.4, 0.65, sin(p.x * 0.19 + sin(p.y * 0.17)) * cos(p.y * 0.23));
 vec3 green = texture(grass, p / 4.0).rgb * vec3(0.40, 0.75, 0.32);
 vec3 leaves = texture(litter, p / 5.0).rgb * vec3(0.58, 0.68, 0.39);
 ALBEDO = mix(green, leaves, patches * 0.48);
 ROUGHNESS = 1.0;
}
