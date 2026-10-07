# Licenças — base 3D dos personagens

As folhas de personagem jogável (`assets/characters/**`, `assets/equipment/**`) e dos NPCs refeitos no pipeline 3D
(`tools/art/blender/characters/`, doc `docs/arte-personagens-blender.md`) são **renderizadas** a partir de modelos e
animações prontos, modificados (proporção, roupas recoloridas e remodeladas, cabelos, rosto em pixel art) e
convertidos em pixel art. Os arquivos originais não são distribuídos com o jogo: ficam em `.work/c3/packs/` (os zips em
`game/downloads/`, pasta ignorada pela Godot).

| Pacote | Autor | Onde | Licença | Uso aqui | Data |
|---|---|---|---|---|---|
| Universal Base Characters [Standard] | Quaternius | https://quaternius.com/packs/universalbasecharacters.html (itch: quaternius.itch.io/universal-base-characters) | CC0 1.0 Universal (domínio público) — `License_Standard.txt` | corpo masculino e feminino (Superhero) + esqueleto humanoide de 65 ossos | 28/09/2026 |
| Universal Animation Library [Standard] (UAL1) | Quaternius | https://quaternius.com/packs/universalanimationlibrary.html | CC0 1.0 Universal — `License.txt` | andar, soco, golpe de espada, magia, dano, morte, sentar | 28/09/2026 |
| Universal Animation Library 2 [Standard] (UAL2) | Quaternius | https://quaternius.com/packs/universalanimationlibrary2.html | CC0 1.0 Universal — `License.txt` | combos de espada (golpes com lâmina e cajado) | 28/09/2026 |
| Modular Character Outfits – Fantasy [Standard] | Quaternius | https://quaternius.com/packs/modularcharacteroutfitsfantasy.html | CC0 1.0 Universal — `License_Standard.txt` | peças Peasant e Ranger (braços, tronco, pernas, botas, ombreira, braçadeiras) recoloridas/recortadas nas 4 roupas por título | 28/09/2026 |

CC0: sem obrigação de atribuição; registramos mesmo assim (autor: Quaternius — https://quaternius.com).
Downloads feitos manualmente pelo dono do projeto em 28/09/2026 (versões Standard, gratuitas).

## Trajes de título (`outfits/chr_<body>_title_*`, 29/09/2026)

Feitos por `tools/art/title_outfits/` sobre as próprias folhas do corpo-base (`base/chr_<body>_base_*`). Cada pose-chave foi
editada pela IA de imagem Bria (`v2/image/edit`), com a descrição da roupa em `outfits.json`, e o resultado foi reduzido e
alinhado ao corpo-base. A cabeça (pixels e máscara) vem do corpo-base. Nenhum sprite de outro jogo entrou como entrada
ou referência. As edições e registros ficam em `.work/title_outfits/`.

Em 30/09/2026 entraram mais 9 trajes pelo mesmo método (arco: `title_cerrado`, `title_brejo`, `title_gaviao`;
suporte: `title_root`, `title_buriti`, `title_matinta`; tanque: `title_jabuti`, `title_anta`, `title_mapinguari`).

## Arco (`equipment/weapon/bow/`, `*_attack_bow.png`, 30/09/2026)

- O arco vem de uma imagem gerada pela Bria (`v2/image/generate`, licença comercial) a partir de texto ("a simple
  longbow made of light yellow bamboo cane..."), guardada em `tools/art/title_outfits/bow_source.png`. A corda e a
  flecha são linhas de 1 px desenhadas por `tools/art/title_outfits/bow.py`.
- As folhas `attack_bow` de todas as camadas são cópias de quadros de `attack_unarmed` das próprias camadas.
- O ícone `items/icons/icon_item_simple_bow.png` sai da mesma imagem, pela redução do `tools/art/icons/gen_icons.py`
  (paleta mestra e contorno), com a corda redesenhada em 1 px.
