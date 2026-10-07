shader_type spatial;
// Terreno pintado em MANCHA (clareira, trilha, areia, neve...) com borda macia: a malha tem uma franja externa com
// alfa 0 na cor de vértice; o ruído deixa a borda orgânica, como pintura. Transparente, sem sombra própria.
render_mode diffuse_lambert_wrap, specular_disabled, depth_draw_never, shadows_disabled, cull_disabled;
#define DECAL
#include "res://assets/shaders/env_terrain.gdshaderinc"
