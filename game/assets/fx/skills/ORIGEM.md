# Origem e licença das folhas de efeitos de skill

28/09/2026. Regra de origem: GDD §0 regra 5 e `docs/briefing-sprites-personagem.md` §0 e §4.

## Folhas desenhadas por script (todas as atuais)

| Item | Valor |
|---|---|
| Ferramenta | `game/tools/art/fx/gen_skill_fx.py` + `fxdraw.py` (Python, numpy, scipy, Pillow) |
| Método | cada quadro é desenhado com formas vetoriais (arcos com rastro que afina, raios, estrelas, prismas, placas, hexágonos, runas) em 4× e reduzido, com as cores em faixas de rampas próprias (pixel art sem degradê). Peças sólidas ganham contorno colorido de 1 px |
| Imagens de entrada | **nenhuma** (nem de jogos, nem de IA, nem de packs) |
| Autor | Projeto (agente de efeitos, 28/09/2026) |
| Licença | do projeto |

Para refazer: `python3 game/tools/art/fx/gen_skill_fx.py` (gera as folhas, os `.import` e a tabela
`game/scripts/client/combat/skill_fx_sheets.gd`; prévias em `.work/fx/sheets/`).

## Terra do Sabiá v0.4 (30/09/2026)

As 119 folhas novas (estados, flecha do arco e as 68 skills das árvores) e os 68 ícones novos em
`game/assets/skills/` também são **desenhados por script, sem imagem de entrada**: campos de intensidade
(`fxdraw.py`) e sprites desenhados à mão em texto, 1 caractere = 1 pixel (`fxsabia.py`: onça, gavião,
coruja, passarinho, vaga-lume, anta, jabuti, casco, garrafa, cuia, coco, pequi, bigorna, martelo, facão,
olhos, boca do Mapinguari, mão de garras, flecha, penas, folhas). Módulos: `fx_status.py`, `fx_melee.py`,
`fx_arcane2.py`, `fx_bow.py`, `fx_hybrid.py`, `fx_support.py`, `fx_tank.py`. Licença: do projeto.

## Folhas importadas de GIF (`tools/art/fx/import_fx_gif.py`)

Nenhuma até agora. Cada folha importada tem um `<peça>.json` ao lado e precisa de uma linha aqui:

| Peça | Arquivo de origem | Autor / ferramenta | Licença (link conferido) | Data |
|---|---|---|---|---|

Só entram GIFs **próprios** (feitos por nós, inclusive por IA com prompt nosso e sem imagem de outro
jogo) ou com licença **CC0 ou CC-BY** conferida na página oficial. **Nunca** GIFs, ripagens ou edições
de Ragnarok, Samsara Saga ou qualquer outro jogo.
