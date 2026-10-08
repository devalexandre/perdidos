shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform float phase = 0.0;
vec2 hash(vec2 p) { return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453); }
void fragment() {
 vec2 p = (UV - 0.5) * 2.0;
 vec2 cell = p * 7.0;
 vec2 base = floor(cell);
 vec2 f = fract(cell);
 float nearest = 10.0; float second = 10.0;
 for(int y=-1;y<=1;y++) { for(int x=-1;x<=1;x++) {
  vec2 offset = vec2(float(x),float(y));
  float d = length(offset + hash(base+offset) - f);
  if(d < nearest) { second=nearest; nearest=d; } else { second=min(second,d); }
 }}
 float cracks = 1.0-smoothstep(0.012,0.045,second-nearest);
 float hot = smoothstep(0.55,0.85,hash(base).x) * cracks;
 float edge = 1.0-smoothstep(0.74,0.98,length(p));
 float breath = 0.65+0.35*sin(TIME*0.75+phase+hash(base).y*3.0);
 ALBEDO = mix(vec3(0.075,0.066,0.060),vec3(0.025,0.019,0.016),cracks);
 ROUGHNESS = 0.92;
 EMISSION = vec3(0.62,0.14,0.022)*hot*breath*0.42;
 ALPHA = edge*0.86;
}
