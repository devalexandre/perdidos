shader_type spatial;
// Pecas solidas dos efeitos de skill (poeira, cristal, placas, estrelinhas): blend normal, sem luz.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://assets/shaders/skill_fx.gdshaderinc"
