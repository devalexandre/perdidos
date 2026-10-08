shader_type spatial;
// Brilho dos efeitos "anime" (assets/fx/anime/): blend aditivo, filtro linear com mipmaps, sem luz.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#define FX_SMOOTH
#include "res://assets/shaders/skill_fx.gdshaderinc"
