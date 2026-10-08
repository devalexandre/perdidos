shader_type spatial;
// Corpo dos efeitos "anime" (assets/fx/anime/): blend normal, filtro linear com mipmaps, sem luz.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#define FX_SMOOTH
#include "res://assets/shaders/skill_fx.gdshaderinc"
