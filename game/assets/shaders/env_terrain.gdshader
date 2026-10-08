shader_type spatial;
// Terreno pintado do kit de cenário (GDD §17.0.A). Camadas tileáveis pintadas à mão misturadas por um
// mapa de mistura (splat) em coordenadas de mundo ou pela cor de vértice:
//   base = grama; R = terra (trilha); G = pedra portuguesa/calçamento; B = areia; A = rocha.
// Anti-repetição: variação macro de cor (manchas quentes/frias), 2ª amostra da grama em outra escala
// e rotação, e bordas de mistura "comidas" pelo ruído e pela altura pintada (luminância) de cada camada.
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://assets/shaders/env_terrain.gdshaderinc"
