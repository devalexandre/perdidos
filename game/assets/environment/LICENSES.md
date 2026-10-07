# Licenças dos assets de cenário de terceiros

Regra do projeto (dono, 27/09/2026): só pacotes **CC0** (domínio público: uso comercial livre, sem atribuição
obrigatória). CC-BY, CC-BY-SA, NC ou licença pouco clara = recusado. A licença foi conferida na página oficial
de cada pacote **e** no arquivo de licença dentro do pacote (copiado como `LICENSE.txt` na pasta).
Crédito voluntário (não obrigatório) fica nos créditos do jogo.

| Pasta | Pacote | Autor | Página oficial (download) | Licença (conferida em) | Baixado em |
|---|---|---|---|---|---|
| `packs/quaternius_nature/` | Stylized Nature MegaKit (versão Standard, gratuita, 68 modelos) | Quaternius | https://quaternius.com/packs/stylizednaturemegakit.html — https://quaternius.itch.io/stylized-nature-megakit | CC0 1.0 — página diz "CC0 License" / "Creative Commons Zero v1.0 Universal"; `License_Standard.txt`: "CC0 1.0 Universal (CC0 1.0) Public Domain Dedication" | 27/09/2026 |
| `packs/quaternius_village/` | Medieval Village MegaKit (Standard) — só as peças usadas (paredes de reboco, telhados de telha, janelas, portas, venezianas, cercas, chaminés, props) | Quaternius | https://quaternius.itch.io/medieval-village-megakit | CC0 1.0 — página: "Creative Commons Zero v1.0 Universal"; `License_Standard.txt`: CC0 1.0 | 27/09/2026 |
| `packs/quaternius_props/` | Fantasy Props MegaKit (Standard) — só os props usados (barris, caixotes, bancas, carroça, bancos, lanternas, tochas, estandartes, vasos) | Quaternius | https://quaternius.itch.io/fantasy-props-megakit | CC0 1.0 — página: "Creative Commons Zero v1.0 Universal"; `License_Standard.txt`: CC0 1.0 | 27/09/2026 |
| `packs/kenney_pirate/` | Pirate Kit 2.1 — barcos, píer, palmeiras | Kenney | https://kenney.nl/assets/pirate-kit | CC0 — página: "Creative Commons CC0"; `License.txt`: "License: (Creative Commons Zero, CC0)" | 27/09/2026 |

Avaliado e não usado (também CC0): KayKit Medieval Hexagon Pack (Kay Lousberg,
https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0, `LICENSE.txt` CC0) — escala de miniatura
para tabuleiro hexagonal, não combinou com a câmera do jogo.

Tudo o que foi **modificado** (retingido, retexturizado com nossas texturas pintadas, reescalado, recombinado em
Blender/Godot) continua coberto: CC0 permite modificar sem restrição. Nossas próprias texturas estão em
`painted/REGISTRO.md`; modelos que fizemos em Blender (ipê, buriti, cristal, cupinzeiro, marcos das nações) são
originais e ficam em `blender/` com os scripts em `tools/art/blender/`.

## Derivados e shaders (GDD §17.0.C, Agente P2, 28/09/2026)

Regra do dono (28/09/2026): o que der para pegar pronto (CC0/MIT), pegar e modificar — registrando aqui.

| Arquivo | Origem | Licença | Modificação |
|---|---|---|---|
| `painted/meshes/bush_low_a.res`, `bush_low_b.res` | copas pintadas do nosso kit (`bush_round_a`, `bush_jungle_a`; `tools/art/env_kit/build_kit.gd`) | originais do projeto | materiais próprios (verde próximo do gramado, vento suave, variação por instância) — `tools/art/env_kit/build_bush_low.gd` |
| `painted/meshes/bush_low_c.res` | Quaternius Stylized Nature MegaKit, `Bush_Common` (via `pk_bush_jungle`) | CC0 1.0 (ver tabela acima) | mesmos ajustes de material; nos mapas é achatado e sobreposto em moitas baixas |
| `assets/shaders/char_palette_swap_3d.gdshader` (amostragem "pixel AA") | "Sub-Pixel Accurate Pixel-Sprite Filtering", mortarroad — https://godotshaders.com/shader/sub-pixel-accurate-pixel-sprite-filtering/ | CC0 (página: "The shader code and all code snippets in this post are under CC0 license") — conferido em 28/09/2026 | fator de mistura adaptado para 4 leituras manuais depois da troca de paleta; luz da cena, sombra e vida procedural são código do projeto |

Avaliado e não usado: "Smooth 3D pixel filtering" (CptPotato/Calinou, godotshaders.com, MIT) — mesma ideia, mas com
uma leitura filtrada da textura, incompatível com a troca de paleta por máscara.
