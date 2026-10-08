# Origem e licença dos efeitos "anime" (alta resolução)

07/10/2026 — piloto da Lança de Fogo (skill `arcane_spark`, Faísca). Como fazer o próximo: `docs/fx-anime.md`.

| Peça | Como foi feita | Entrada | Licença |
|---|---|---|---|
| `arcane_spark_anime_blast` | Blender 5.2 EEVEE: metaballs + cones, sombreamento toon por rampa constante, contorno por casco invertido (`tools/art/fx/anime/fire_lance_blender.py`) | nenhuma imagem | do projeto |
| `arcane_spark_anime_lance` | idem (fuso + labaredas) | nenhuma imagem | do projeto |
| `arcane_spark_anime_glow`, `arcane_spark_anime_lance_glow` | tirados dos quadros acima (partes quentes borradas), `build_anime_fx.py` | quadros acima | do projeto |
| `arcane_spark_anime_cast` | carimbos de `light_01`, `star_06`, `circle_05` do **Kenney Particle Pack 1.1** recoloridos, `build_anime_fx.py` | Kenney | CC0 (https://kenney.nl/assets/particle-pack, `particles/KENNEY_LICENSE.txt`) |
| `particles/kenney_*.png` | texturas do Kenney Particle Pack reduzidas (só alfa, branco) | Kenney | CC0 |
| `particles/rock.png` | polígono desenhado por script (`build_anime_fx.py`) | nenhuma | do projeto |

A referência de estilo (animação "Lança de Fogo" do Defeat the Evil) foi só **inspiração**: nenhum quadro,
recorte ou traço dela entrou nos arquivos.

Esta pasta fica **fora** da regra de paleta/alfa binário da pixel art (`tools/art/validate_art.py` não varre
`assets/fx/`): degradê e alfa suaves são o ponto do efeito. Personagens e monstros continuam pixel art.
