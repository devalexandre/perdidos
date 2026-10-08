shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform vec4 water_color : source_color = vec4(0.07, 0.32, 0.40, 1.0);
uniform float phase = 0.0;
uniform float opacity = 0.78;
uniform bool mist = false;
uniform bool impact = false;
void fragment() {
 vec2 p = (UV - 0.5) * 2.0;
 float shore = length(p) + sin(p.x * 9.0 + p.y * 6.0 + phase) * 0.045;
 float mask = 1.0 - smoothstep(0.72, 0.98, shore);
 float w = sin(p.x * 13.0 + p.y * 7.0 - TIME * 1.3 + phase) * sin(p.y * 11.0 - p.x * 4.0 + TIME * 0.8);
 float rings = pow(max(0.0, sin(length(p - vec2(0.1, -0.15)) * 38.0 - TIME * 3.4 + phase)), 16.0);
 if (mist) {
  float wisps = sin(p.x * 5.0 + TIME * 0.22 + phase) * sin(p.y * 7.0 - TIME * 0.18);
  ALBEDO = water_color.rgb;
  EMISSION = water_color.rgb * 0.15;
  ALPHA = mask * (0.45 + wisps * 0.3) * opacity;
 } else {
  ALBEDO = water_color.rgb * (0.48 + w * 0.15) + vec3(0.06, 0.12, 0.13) * rings;
  EMISSION = water_color.rgb * (0.03 + rings * 0.08);
  if (impact) {
   float froth = (1.0 - smoothstep(0.15, 0.8, length(vec2(p.x * 1.1, p.y * 2.2 + 0.5)))) * (0.6 + w * 0.4);
   ALBEDO += vec3(0.52, 0.66, 0.67) * froth;
   EMISSION += vec3(0.12, 0.17, 0.18) * froth;
  }
  ROUGHNESS = 0.19;
  METALLIC = 0.25;
  NORMAL_MAP = vec3(0.5 + w * 0.09, 0.5 + sin(p.y * 18.0 + TIME) * 0.06, 1.0);
  ALPHA = mask * opacity;
 }
}
