shader_type spatial;
// Igual a env_painted.gdshader, com as duas faces (telhados, toldos, velas, cascos, tendas).
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;

#include "res://assets/shaders/env_painted.gdshaderinc"
