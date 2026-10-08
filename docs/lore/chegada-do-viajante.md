# A Chegada do Viajante — lore base e roteiro da cinemática

> Status: `[PROVISÓRIO]` — texto de lore que expande o GDD §1.2 (e conversa com §4.0, §9.3, §10.6, §12).
> Escrito para roteiristas e agentes de conteúdo: use os termos em **negrito** de forma consistente.
> Autor: agente I, 27/09/2026. Implementação da cinemática: `game/scenes/cutscenes/arrival.tscn`.

---

## Parte 1 — Lore

### 1. Os Viajantes

Pessoas comuns do nosso mundo — estudantes, entregadores, gente voltando do trabalho — que num fim de
tarde qualquer **somem** e acordam na margem de um rio de outro mundo. Chegam com a roupa do corpo
(o moletom azul, a mochila, o tênis) e nenhuma habilidade. Os habitantes os chamam de **Viajantes**:
"quem aparece do nada, com roupa diferente e cara de espanto".

Ninguém sabe por que vêm, nem quem os chama. Os barqueiros dizem que o rio traz; os Mestres dizem que
a terra chama quando precisa; as crianças dizem que foi o Saci. O jogo **nunca responde por completo**.

### 2. A Florada (o evento misterioso)

Todo Viajante lembra da mesma coisa: **uma flor de ipê dourada caindo onde não existe árvore nenhuma**.
Quem a vê sente o tempo parar — o barulho da rua some, os carros congelam, a luz fica cinza — e só a
pétala continua brilhando. Depois vem uma queda longa **entre as estrelas**, um vislumbre de terras que
ele nunca viu, escuridão, e o som de água.

O povo chama isso de **Florada**. No Porto do Despertar há um **ipê amarelo gigante** sobre o **cristal
azul** da praça; dizem que ele floresce fora de época sempre que um Viajante está para chegar. Se a
pétala vem dele, ninguém provou. (Mistério reservado: não explicar a origem da Florada no MVP.)

### 3. O mundo: reinos que ecoam o nosso

Este mundo é feito de **reinos cujas terras parecem ecos do nosso planeta**. Em cada reino, as lendas e
os contos de um povo real **são verdade**: foram contadas por tanto tempo, por tanta gente, que criaram
raiz aqui. O mundo "é feito de histórias" — por isso as criaturas dele são lendas vivas.

Os moradores chamam o nosso mundo de **o Outro Lado**. Nomes próprios do mundo como um todo ficam
`[EM ABERTO]` (ver perguntas no fim).

**Terra de Pindorama** (região do MVP, inspirada no Brasil): rios largos, cerrado com ipês e buritis, mata
fechada, chapadas vermelhas acima de um mar de nuvens. O saci ri nos redemoinhos, o Curupira guarda a
mata, o Boitatá protege os campos do fogo. Regras (GDD §4.0, obrigatórias):

- É **inspiração, não caricatura**: lugares e pessoas com dignidade, sem "Brasil de cartão-postal".
- Só **folclore tradicional de domínio público** (ver `game/data/regions/brasil.md`, com fontes).
- **Figuras de religiões vivas nunca são monstros nem piada**; o Curupira é guardião, não inimigo; o
  Saci não é morto (o monstro é o *Redemoinho Arteiro*, redemoinho "contaminado" pela travessura dele).
- **Nenhuma tragédia real** vira inimigo, chefe, humor ou pano de fundo "exótico".

### 4. Por que os Mestres ensinam

Os nativos nascem com **um** caminho: quem nasce ferreiro é ferreiro, quem nasce com o dom do Arcano
passa a vida nele. Os Viajantes chegam **em branco** — e por isso conseguem aprender **qualquer arte**,
de qualquer escola, desde que alguém ensine.

Mas uma arte só passa **de pessoa para pessoa**: não se aprende em livro nem "subindo de nível". O
Mestre mostra, o aprendiz prova que entendeu (a quest), e a técnica "pega" (GDD §7, §8: skills só por
quest). Os Mestres ensinam por um costume antigo dos portos — **"quem chega pelo rio aprende com quem
ficou"** — e também por necessidade: cada Viajante que aprende a lutar protege a terra dos monstros
que ficaram fortes demais (ver §6).

Com o tempo o povo reconhece o caminho de cada Viajante por **títulos** (GDD §8.5): não são classes,
são nomes que o mundo dá a quem juntou certas artes ("quem domina os golpes básicos da Lâmina é
chamado de Facão Firme"). Alguns Mestres só ensinam suas técnicas mais raras a quem carrega um título.

### 5. A Marca da Alma

A pétala da Florada **amarra a alma do Viajante ao cristal** da cidade. Quando um Viajante morre, o
corpo se refaz junto ao cristal (renascimento), mas a alma deixa no lugar da queda uma **Marca da Alma**:
um túmulo de luz que guarda **tudo o que ele vestia** naquele instante — as coisas "presas ao corpo" não
atravessam de volta; as que estavam na mochila, sim (inventário intacto, GDD §12).

A Marca dura pouco (três horas) e **só o dono a enxerga**, porque é um pedaço da própria alma dele. Na
arena, onde as almas se enfrentam de frente, quem venceu também a vê — e pode tomar o que ela guarda.

### 6. O Eco: por que os monstros crescem ao matar Viajantes

Tudo o que um Viajante vive aqui — cada luta, cada lição — vira **Eco**: experiência feita de memória,
brilhante e "nova", porque vem de alguém do Outro Lado. As criaturas deste mundo são lendas vivas, e
lendas **se alimentam de histórias**. Quando um monstro derruba um Viajante, ele **bebe o reflexo do Eco
inteiro** dele (GDD §10.6: toda a XP total do jogador).

- O Viajante **não perde nada**: o Eco é um reflexo, como a imagem num rio — a lembrança fica com quem
  a viveu; o monstro leva a cópia.
- Cheio de Eco, o monstro **vira uma lenda maior**: cresce, ganha outro nome e outro corpo (estágios
  **Normal → Médio → Chefe**). Um chefe nascido assim reúne um **bando** da própria espécie.
- Quem derrota um monstro inchado de Eco **recolhe parte dele** (a recompensa de 50% da XP absorvida).
- Por isso os moradores temem Viajantes descuidados — e respeitam os que caçam em grupo.

Frase-guia para diálogos: *"Aqui as lendas comem histórias, Viajante. E a sua é a mais fresca de todas."*

### 7. Vocabulário (manter consistente)

| Termo | Significado |
|---|---|
| **Viajante** | O jogador; pessoa vinda do Outro Lado |
| **Outro Lado** | Como os nativos chamam o nosso mundo |
| **Florada** | O evento da travessia (a pétala dourada, o tempo parado, a queda) |
| **Ipê do Despertar** / **cristal** | Árvore gigante e cristal da praça; ponto de renascimento |
| **Mestres** | NPCs que ensinam skills por quests |
| **Títulos** | Nomes dados a quem reuniu certas artes; liberam quests exclusivas |
| **Marca da Alma** | Túmulo com o equipamento vestido na hora da morte |
| **Eco** | A experiência de um Viajante; o que os monstros absorvem para evoluir |

---

## Parte 2 — Roteiro da cinemática da travessia

Duração: **52,5 s** (8 planos). Pulável (Esc ou botão "Pular"). Mostra o **corpo escolhido** (planos 1,
2, 3 e 8 têm variante masculina e feminina; os demais não mostram o Viajante de perto). Dados dos planos:
`game/assets/cutscenes/arrival/shots.json`; legendas: `game/localization/cutscene.csv`.

| # | Plano (id) | Tempo | Imagem | Câmera / efeito | Legenda (pt-BR) | Som |
|---|---|---|---|---|---|---|
| 1 | Cidade (`city`) | 7,0 s | Rua moderna ao entardecer; Viajante de costas, fones, celular, voltando para casa | Surge do preto; zoom lento 1,0→1,1 descendo até o Viajante | "Era só mais um fim de tarde." / "O mesmo caminho de sempre para casa." | `mus_arrival` começa (provisório: `mus_title`) |
| 2 | A pétala (`petal`) | 6,5 s | A rua congelada em cinza-azulado; o Viajante parado olhando uma **pétala dourada** flutuando | Fusão cruzada; brilho dourado pulsando sobre a pétala; poeira parada no ar | "Até que uma flor dourada caiu..." / "...de uma árvore que não estava ali." | `sfx_event_chime` |
| 3 | O tempo para (`stillness`) | 4,5 s | Mesma cena | Zoom forte na pétala; o brilho cresce e engole a tela em **branco** | "E o mundo prendeu a respiração." | (a música suspende — na trilha) |
| 4 | A queda (`fall`) | 8,0 s | Céu de estrelas e nuvens; espiral de pétalas; silhueta minúscula caindo | Sai do branco; zoom se abrindo 1,4→1,05; estrelas passando para cima (sensação de queda) | "Você caiu entre as estrelas," / "atravessando o sono de dois mundos." | `sfx_fall_whoosh` |
| 5 | A terra (`land`) | 7,0 s | Chapadas vermelhas sobre o mar de nuvens, cachoeiras, rio, a cidade sob o **ipê gigante com o cristal** | Fusão; câmera desce das chapadas até a cidade; pétalas ao vento | "Lá embaixo, uma terra antiga acordava em cores..." / "...rios largos e chapadas acima das nuvens." | — |
| 6 | As lendas (`legends`) | 6,5 s | Cerrado ao crepúsculo, ipês roxos e amarelos, cupinzeiros, vaga-lumes e um **redemoinho com gorrinho vermelho** | Fusão; aproximação lenta do redemoinho; escurece para o preto | "Uma terra onde as lendas ainda andam, riem..." / "...e guardam seus segredos." | — |
| 7 | Escuridão (`darkness`) | 4,0 s | Preto | Só texto | "Depois, só o som da água." | `sfx_wake_river` |
| 8 | Margem do rio (`riverbank`) | 9,0 s | Amanhecer rosado; o Viajante dormindo na areia; no rio enevoado, a **silhueta do barqueiro** com a vara | Surge do preto devagar (2,5 s); zoom se abre do Viajante até o barco; fade final | "— Acorda, Viajante. O rio te trouxe." / "Bem-vindo à Terra de Pindorama." | — |

Notas de direção:
- A cinemática termina onde o **tutorial começa** (ver `docs/tutorial-design.md`): o barqueiro da
  silhueta é o **Barqueiro Benedito**, guia do tutorial.
- Legendas curtas, no máximo 2 por plano, sem narrador explicando a lore: a lore vem depois, nos
  diálogos do guia.
- O redemoinho com gorrinho é só uma **pista** do Saci (nunca o Saci inteiro na tela).

---

## Perguntas em aberto (para o dono do projeto)

1. O mundo inteiro precisa de um nome próprio? (Hoje: "este mundo" / "o Outro Lado" para o nosso.)
2. "Florada" e "Eco" podem virar termos oficiais (aparecer na interface, ex.: "Eco absorvido" no aviso
   de evolução do monstro)?
3. O Viajante pode voltar para casa algum dia? (Gancho de temporada; hoje a resposta é "ninguém sabe".)
4. A fala atual do Barqueiro Benedito na cidade diz "te achei num bote à deriva"; com o tutorial na
   margem do rio, sugerimos trocar para "te achei dormindo na areia" quando o tutorial existir.


## Narrador da abertura (decisão do dono, 27/09/2026)

Quem conta a história na abertura é **o deus supremo deste mundo** — uma divindade **inventada para o jogo** (nome em aberto; nunca o nome de uma divindade de religião real, GDD §4.0 regra 3). Voz de homem velho, lenta e solene, como quem conta um conto antigo à beira do fogo. A narração está em `game/assets/cutscenes/arrival/voice/<idioma>/` (pt-BR, en, es, fr, de, ja), gerada por `game/tools/audio/narration.py`.
