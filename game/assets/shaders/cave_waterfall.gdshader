shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float phase = 0.0;
uniform float opacity = 0.78;
uniform vec4 water_color : source_color = vec4(0.21, 0.61, 0.69, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash(i), hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 VERTEX.z += sin(UV.x * 20.0 + UV.y * 13.0 - TIME * 4.5 + phase) * 0.11;
 VERTEX.x += sin(UV.y * 14.0 - TIME * 3.0 + phase) * 0.045;
}
void fragment() {
 vec2 flow = vec2(UV.x * 34.0, UV.y * 4.0 - TIME * 2.0 + phase);
 float lanes = noise(flow) * 0.65 + noise(flow * vec2(2.6, 1.7)) * 0.35;
 float thread = smoothstep(0.48, 0.76, lanes);
 float foam = smoothstep(0.66, 1.0, UV.y) * noise(vec2(UV.x * 18.0, UV.y * 18.0 - TIME * 4.0));
 float edges = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
 float head = smoothstep(0.0, 0.035, UV.y);
 vec3 color = mix(water_color.rgb * 0.50, vec3(0.76, 0.89, 0.91), thread * 0.6 + foam * 0.35);
 ALBEDO = color;
 EMISSION = color * 0.18;
 ALPHA = edges * head * (0.13 + thread * 0.5 + foam * 0.3) * opacity;
}
