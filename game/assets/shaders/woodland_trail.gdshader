shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 soil_tint : source_color = vec4(0.56, 0.43, 0.28, 1.0);
varying vec2 world_uv;
void vertex() {
 world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
 vec3 soil = texture(dirt, world_uv / 3.0).rgb;
 float grain = texture(dirt, world_uv * 1.7).r;
 float fringe = 0.18 + 0.045 * sin(UV.y * 19.0) + 0.04 * sin(UV.y * 43.0 + UV.x * 7.0);
 float edge = min(UV.x, 1.0 - UV.x);
 ALBEDO = soil * soil_tint.rgb * (0.9 + 0.2 * grain);
 ROUGHNESS = 1.0;
 ALPHA = smoothstep(0.015, fringe, edge + (grain - 0.5) * 0.12);
}
