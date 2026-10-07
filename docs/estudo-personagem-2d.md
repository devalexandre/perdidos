# Estudo de referência — personagem 2D (passo 1)

28/09/2026. Decisão do dono: **o personagem é desenho 2D** (como Ragnarok Online e Samsara Saga). O 3D renderizado fica para monstros e cenário.

**Regra:** os sprites de terceiros servem só para **medir e estudar**. Nenhum pixel deles entra no projeto, nem como base para decalque (GDD §0 regra 5). Arquivos de estudo ficam em `.work/estudo_ro/` e `.work/ref_samsara/`, fora do git e do jogo.

## O que o Ragnarok faz (folha do Novice masculino)

- **O corpo não tem cabeça.** A folha do corpo termina na gola; a cabeça e o cabelo são outro sprite, encaixado por um ponto de âncora em cada quadro. Por isso um penteado serve para todas as roupas e títulos.
- **Proporção do corpo sem cabeça** (quadro parado, medido na folha): ~76 px de altura × ~40 px de largura.
  - Ombros/tronco: a parte mais larga, ~33 px (≈ 45% da altura do corpo).
  - Cintura: ~24 px; quadril e calça voltam a ~26 px.
  - Pernas: começam por volta de 55–60% da altura; pés pequenos e juntos (~10–13 px cada).
  - Com a cabeça por cima (≈ um terço da altura total), o personagem inteiro fica com **~3 cabeças**.
- **Quadros por animação observados:** andar **8** por direção; parado poucos quadros (respiração discreta); sentar 1–2; ataques ~6–10; conjurar, dano e caído em poucos quadros bem marcados.
- **Direções:** algumas desenhadas e as outras por espelho, como já fazemos (S, SE, L, NE, N + espelho).
- **Leitura:** contorno escuro colorido, 3–4 tons por material, luz de cima-esquerda, silhueta simples.

## Samsara Saga (sprites em pé)

- Altura total ÷ cabeça: **3,4 a 3,7**.
- Largura da cabeça (com cabelo): **65–80%** da largura total do sprite.
- Ombros ≈ largura da cabeça; braços grossos, mãos grandes na altura do quadril; pernas curtas, botas grandes e arredondadas; postura ereta.

## Ficha do NOSSO Viajante (alvo)

| Item | Valor |
|---|---|
| Quadro | 96 × 96 px (atual) |
| Altura total | ~80–84 px |
| Cabeça com cabelo | ~30 px de altura, ~34–40 px de largura (≈ 3 cabeças de altura total) |
| Corpo sem cabeça | ~52 px, ombros ~26–30 px |
| Pernas | ~40% da altura do corpo; botas grandes e arredondadas |
| Mãos | visíveis a 1x, na altura do quadril |
| Estrutura | **corpo e cabeça separados** (como o Ragnarok): corpo por roupa/título; cabeça com rosto, olhos e cabelo por penteado; âncora da cabeça por quadro |
| Animações | parado 4, andar 8, ataque 6–8 por tipo de arma, conjurar 6, dano 2–4, caído 4–6, sentar 1 |
| Direções | S, SE, L, NE, N desenhadas; SO, O, NO por espelho |
| Estilo | contorno colorido, 3–4 tons, luz de cima-esquerda, roupas da prancha `title-evolution-v1.png` |

## Passo 2 (a decidir)

Desenhar o nosso Viajante seguindo esta ficha: com a IA de imagem (pose por pose, corpo e cabeça separados) ou com um artista de pixel art para as poses-chave.
