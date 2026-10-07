shader_type spatial;
// env_painted em MANCHA de chão com borda macia (alfa da cor de vértice + ruído). Ver env_terrain_decal.
render_mode diffuse_lambert_wrap, specular_disabled, depth_draw_never, shadows_disabled, cull_disabled;
#define DECAL
#include "res://assets/shaders/env_painted.gdshaderinc"
