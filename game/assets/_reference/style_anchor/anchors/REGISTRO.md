# Registro das âncoras de estilo (GDD §17.0.4)

- **Data:** 27/09/2026
- **Ferramenta/modelo:** Bria.ai — FIBO Generate (`POST /v2/image/generate`), licença comercial segura.
- **Status:** AGUARDANDO APROVAÇÃO do dono do projeto (prancha: `prancha-ancoras-v1.png`).
- **Pipeline:** `tools/art/anchor_pipeline/` — `gen.py` (geração), `pix.py` (recorte do fundo), `board.py` (redução BOX para o tamanho de jogo + quantização em Lab para a paleta expandida + remoção de pixels órfãos + prancha).
- **Escala:** personagem 80 px em quadro 96x96; Tatu-Pedra 56 px em quadro 96x96; ícones 32x32; cena 960x540 (GDD §17.2 revisado).
- **Paleta:** `../paleta-mestra-v2-proposta.gpl` = 50 cores originais + 35 extraídas das âncoras (k-means em Lab, ΔE > 7). Decisão #7 do GDD.

| Âncora | Prompt | Seed escolhida | Original | Final |
|---|---|---|---|---|
| 1 — Viajante masc. (frente/lado/costas) | `p_a1m.txt` | 2000 | `original/a1m_0.png` | `final/proc_a1m_{0,1,2}.png` |
| 1 — Viajante fem. | `p_a1f.txt` | 3000 | `original/a1f_0.png` | `final/proc_a1f_{0,1,2}.png` |
| 2 — 5 direções | `p_a2m.txt` | 4000–4003 | `original/a2m_*.png` | **refazer**: nenhuma variação acertou as 5 direções; próxima tentativa via edição a partir da Âncora 1 |
| 3 — Tatu-Pedra | `p_a3.txt` | 5003 | `original/a3_3.png` | `final/proc_a3_0.png` |
| 4 — Praça do Porto do Despertar | `p_a4.txt` | 6001 | `original/a4_1.png` | `final/proc_a4_0.png` |
| 5 — Ícones | `p_a5.txt` | 7000 | `original/a5_0.png` | `final/proc_a5_{0..5}.png` |

Limpeza manual no Aseprite (GDD §17.5 passo 5) ainda não foi feita: contorno, olhos e sombra de chão precisam de retoque antes da versão final.

## v2 — 27/09/2026 (substitui a Âncora 1 da v1, rejeitada por parecer "chibi bebê")

- Prompts: `original/v2/p_c1m.txt`, `p_c1f.txt`, negativo `neg.txt` (magro, ~3,5 cabeças, olhos médios e afiados, contorno marrom escuro, sombreamento quente de alto contraste).
- Escolhidos: masculino `c1m_2.png` (seed 11002), feminino `c1f_2.png` (seed 12002).
- Direções e poses de caminhada geradas por edição (Bria FIBO-Edit) a partir do escolhido; fundo removido com RMBG-2.0.
- Pipeline e escolhas: `tools/art/character_pipeline/` (`picks.json`, `flips.json`, `build_sheets.py`).
- Folhas no jogo: `assets/characters/chr_traveler_{male,female}_{idle,walk}.png` (96x96, linhas S, SE, L, NE, N). Paleta própria de 48 cores por personagem, até a paleta v2 ser fechada.
- Pendente: limpeza manual no Aseprite (costas em caminhada perdem a legging em 2 quadros; pequenas variações de detalhe entre quadros).
