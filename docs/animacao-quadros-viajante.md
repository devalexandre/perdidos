# Viajante com mais quadros (deformação por partes)

Aprovado em 07/10/2026. As folhas do Viajante ganharam mais quadros sem redesenhar o personagem. Cada quadro novo é
um quadro antigo deformado por partes, ou seja, um skin 2D: cabeça, tronco, barra, mãos, braços e pernas; no cabelo,
a massa, as pontas e as mechas.

## Contagens e tempos

| Animação | Antes | Agora | Duração (cliente) |
|---|---|---|---|
| idle | 4 × 200 ms | 12 | 1,4 s de ciclo (~117 ms) |
| cast | 6 × 90 ms | 16 | 0,9 s (~56 ms) |
| attack_unarmed / blade / staff | 6 × 70 ms | 12 | 0,42 s (35 ms); impacto no quadro 4 = 140 ms, como antes |
| attack_bow | 6 × 80 ms | 12 | 0,48 s (40 ms) |
| walk / death | 8 / 6 | iguais | iguais; só ganham movimento secundário (cabelo e barra atrasados). Walk do corpo-base e das roupas de título: 8 desenhos distintos desde 08/10 (`game/tools/art/character_pipeline/walk8_legs.py`, chamado pelo rollout; ver `arte-personagens-movimento.md`) |

- **Tempos:** ficam em `DirectionalSprite3D.TRAVELER_CYCLE_MS`. Só valem para folhas do Viajante com mais quadros
  que `TRAVELER_REF_FRAMES`; folhas antigas, NPCs e monstros continuam como antes.
- **Respiração procedural:** o perfil HUMAN fica desligado no Viajante com idle desenhado, porque a respiração já
  vem nos quadros.
- **Camadas com outra contagem:** uma camada com contagem diferente da do corpo (arma ou chapéu antigos) segue o
  corpo pelo tempo proporcional (`overlay_column`).

## Técnica (`game/tools/art/character_pipeline/rollout.py`)

- **Fonte:** as folhas ORIGINAIS, de 4/6 quadros, em `.work/char-frames-pilot/backup_originals/` (fora do git). Para
  recriar essa pasta, rode `game/tools/art/character_pipeline/fetch_rollout_sources.sh`: ele extrai as originais do
  commit `f328083`. Nunca deforme uma folha que já foi deformada.
- **Versionado em 08/10/2026.** O `rollout.py` antigo de `.work/` virou um atalho para o do repositório. Rodar a fase
  `body` reproduz bit a bit as folhas instaladas. As roupas de equipamento com folhas próprias (`apprentice`,
  `branch_coat`, `leather_jerkin`, `master_armor`) ficam fora do rollout (`OWN_FRAMES_OUTFITS`).
- **Python:** use o `.tools/pyvenv/bin/python3`, que tem numpy, scipy e Pillow.
- **Geometria de cada quadro (lida do corpo-base):**
  - topo da cabeça: o cabelo raspado (canal B) da máscara;
  - queixo: o topo da cabeça mais a altura da cabeça do corpo;
  - cintura: 47% do caminho do queixo até os pés;
  - largura do tronco: a das pernas;
  - olhos: a camada de olhos.
- **Um único plano por quadro**, aplicado igual em todas as camadas daquele quadro:
  - corpo-base e máscara, olhos e olho fechado, cabelos, brincos;
  - chapéus (com a cabeça);
  - armas (com as luvas no idle e rígidas com o tronco nos golpes; o rastro do golpe também entra na arma);
  - roupas de título e máscara;
  - o composto `chr_traveler_*`.
  Amostragem por vizinho mais próximo: nenhuma cor nova, e os códigos de rampa e de máscara ficam intactos.
- **Campos contínuos:**
  - a respiração desce em rampa do ombro até a cintura, e a costura de 1 px desliza;
  - o cabelo anda mais nas pontas;
  - a barra anda mais embaixo;
  - fases senoidais com atraso por parte.
  - Perto dos olhos o peso é 0: a franja acompanha a cabeça e o rosto não muda.
- **Cast:**
  - mãos juntas que se abrem (na frente);
  - braços que giram em torno do ombro (frente e costas) ou que se encurtam para a frente (vistas de lado);
  - brilho nas mãos e faíscas;
  - olhos fechados na concentração.
- **Golpes:**
  - antecipação e inclinação no sentido do golpe, medido pela diferença entre as poses;
  - rastro em pontilhado claro só nos membros e na arma;
  - impacto segurado;
  - cabelo como mola.
- **Retoque automático:**
  - frestas fechadas pelo vizinho;
  - pedaços soltos de até 8 px apagados;
  - contorno refeito nos braços girados.
  - Brilho e rastro usam a paleta mestra, com máscara de alfa 128 (sem recolor).
  - No composto e nas roupas, que o `validate_art` limita a 48 cores, as cores que não cabem viram a cor mais
    próxima da própria folha.
- **Roupa longa** (saia, capa, manto): o que passa da silhueta do corpo-base abaixo da cintura vira uma barra própria
  (`L_HEMX`), que balança.

## Refazer ou incluir uma roupa ou camada nova

1. A roupa nova sai do `title_outfits` com as contagens ANTIGAS (idle 4, golpes e cast 6), nas folhas e na máscara.
2. Copie a folha antiga para `backup_originals/` com o mesmo caminho relativo de `game/assets`. Como roupas novas
   não estão no commit `f328083`, guarde também a saída do `title_outfits` (4/6 quadros), que é regenerável.
3. Gere o stage:
   - roupas: `.tools/pyvenv/bin/python3 game/tools/art/character_pipeline/rollout.py <stage> --phase=outfits --bodies=male,female`;
   - camadas de aparência: `--phase=body`;
   - armas e chapéus: `--phase=equip`.
   Use `--only=<nome>` para gerar uma camada só (ex.: `outfit_title_x`, `hair_bob`).
4. Instale e teste com `.work/char-frames-pilot/phase_test.sh <stage> <logs>`. Ele copia o stage para
   `game/assets` e roda `--import`, `test_direction`, `test_ui`, `test_mobile_controls` e `validate_art.py`.
5. Confira as pranchas (`rollout_preview.py`, `face_board.py`, `outfit_preview.py`) e depois capture o cliente real.

**Para voltar atrás:** `git checkout game/assets/characters game/assets/equipment` ou copie de `backup_originals/`.
