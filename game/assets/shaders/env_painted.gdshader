shader_type spatial;
// Superfícies pintadas do kit (GDD §17.0.A): paredes caiadas, telhado, madeira, pedra, props.
// - Textura pintada à mão por UV da malha ou triplanar em coordenadas de mundo (paredes/rochas longas).
// - Cor de vértice = oclusão pintada (cantos/base mais escuros), gerada pelos construtores do kit.
// - "Topo" opcional: musgo/grama em superfícies viradas para cima (pedras com musgo, muros velhos).
// - Sujeira na base (escurece perto do chão, como nas pinturas de cenário).
render_mode diffuse_lambert_wrap, specular_disabled;

#include "res://assets/shaders/env_painted.gdshaderinc"
