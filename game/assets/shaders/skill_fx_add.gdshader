shader_type spatial;
// Brilho dos efeitos de skill: blend aditivo, sem luz, sem escrever profundidade.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://assets/shaders/skill_fx.gdshaderinc"
