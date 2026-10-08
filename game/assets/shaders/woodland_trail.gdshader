shader_type spatial;
// Trilha de terra das matas e campos (terrain_trail.gd): faixa com franja comida pelo grão da terra.
// Cenário vivo (08/10/2026): molha com a chuva (env_wetness: terra escura e saturada, poças no meio da trilha, anéis
// de pingo) e recebe a sombra de nuvem passando (env_clouds). Seco e sem nuvem = igual ao antigo.
render_mode cull_disabled, depth_draw_opaque;
#include "res://assets/shaders/env_weather.gdshaderinc"
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
 vec3 col = soil * soil_tint.rgb * (0.9 + 0.2 * grain);
 // poças só no miolo da trilha (longe da franja)
 float n_big = env_value_noise(world_uv / 5.0);
 float n_small = env_value_noise(world_uv / 1.4 + vec2(5.3, 2.1));
 vec4 wet_g = env_wet_ground(col, world_uv, 1.0, 0.0, n_big, n_small, smoothstep(0.12, 0.32, edge), TIME);
 col *= env_cloud_shade(world_uv, TIME);
 ALBEDO = col;
 ROUGHNESS = wet_g.x;
 if (env_wetness > 0.001) {
  SPECULAR = wet_g.y;
  if (wet_g.z != 0.0 || wet_g.w != 0.0) {
   NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(wet_g.z, 0.0, wet_g.w, 0.0)).xyz);
  }
 }
 ALPHA = smoothstep(0.015, fringe, edge + (grain - 0.5) * 0.12);
}
