# Arco 1 da História Principal — A Terra de Pindorama

> **Versão:** 0.3 — 07/10/2026 (quests, chefes como dados e covis implementados; ver seção 10)
> **Base:** `lore.md` (lore principal), GDD §1.2, §4.0, §4.2; `ARCO-DO-LOBISOMEM.md`; `docs/mundo/progressao-areas.md`; `docs/mundo/caverna-implementacao.md`.
> **Status:** regras da seção 1 `[FECHADO]` (decisão do dono, 07/10/2026). Capítulos e quests `[PROVISÓRIO]`. Pontos em aberto na seção 9.
> **Spoilers:** este documento contém toda a verdade do arco. **Nada das seções 3 a 5 vai para o site** (ver seção 8).

---

## 0. Resumo em uma linha

O Viajante chega à Terra de Pindorama achando que precisa derrotar lendas enfurecidas. Ao vencer todas, descobre que elas foram corrompidas por Erevos e que a guerra começou por uma mentira: **a filha do Devorador nunca morreu.**

---

## 1. Regras do arco `[FECHADO — dono, 07/10/2026]`

1. **Chefes da história só existem na forma atroz** e **só aparecem à noite**. Não têm forma normal, veterana nem de covil diurno.
2. **Cada chefe tem uma quest de ativação.** A quest leva o jogador até ele, faz o chefe nascer na hora pelo ritual e é o que conta a vitória para a história. Fora isso, o chefe também nasce sozinho no mapa (regra 5).
3. **O Curupira é um chefe**: o chefe das áreas da floresta (Mata Encantada). De dia aparece como **um menino comum**, sem nada de monstruoso.
4. **O chefe final, Boitatá, aparece no andar 5 da Caverna do Reino Encoberto** (a dungeon do lobisomem), e só depois que o jogador derrotou **todos** os chefes da história.

5. **Os chefes da história também nascem sozinhos nos mapas** (dono, 07/10/2026), sem precisar do ritual:
   - **só à noite**: se amanhece com o chefe vivo, ele some, e o próximo nasce na noite seguinte;
   - **1 hora** para voltar depois de derrotado (contra 10 min dos chefes de espécie);
   - **no máximo 1 chefe da história por mapa**. A tabela da seção 2 já põe cada um num mapa diferente.

   O ritual da quest continua existindo: ele **antecipa** o nascimento quando o chefe daquele mapa não está vivo (zera a espera de 1h), mas nunca cria um segundo. Se o chefe já está vivo, o ritual só marca o ponto no mapa. A vitória conta para a história de quem estiver com a quest no passo do ritual, venha o chefe do ritual ou do nascimento natural. O Boitatá só nasce sozinho para quem já tem o andar 5 aberto.

6. **Chefe forte em mapa fraco, com bando** (dono, 07/10/2026). O chefe da história pode ficar num mapa de nível menor que o dele, desde que nasça com um **bando de no mínimo 10 monstros do nível do mapa**. O nível do chefe segue o rank e a ordem da história; o do bando segue o mapa. Como os chefes da história não têm forma normal, o bando é de **outras espécies** que combinam com a lenda (ver seção 2).
7. **Mapas temáticos.** Cada chefe pode ganhar um mapa próprio, ligado ao mapa de caça onde a história o põe e com o mesmo nível dele. Lista e prioridade na seção 2.1.

Consequências no jogo que já existe:

- Implementação: cada chefe da história é um covil (`BossLairs/`) com `respawn_sec = 3600`, forma atroz (estágio 4) fixa e uma meta nova de "só à noite". O `MonsterSpawner` já lê `respawn_sec` por covil. Faltam a meta de noite, o estágio atroz fixo, a trava de 1 por mapa e um **bando configurável por covil** (lista de espécies, estágio e quantidade, no mínimo 10). Hoje o bando é sempre da espécie do chefe (`boss_escort_normals = 4`, `boss_escort_mediums = 2`).
- Como os mapas são compartilhados desde 30/09, o chefe da história é um **chefe de mundo**: todos no mapa veem o mesmo. A recompensa de história vale para quem participou do combate.
- No andar 4 da Caverna já existe o covil do lobisomem (chefe de espécie com forma atroz à noite). À noite, esse covil passa a ser o Lobisomem Atroz da história, com a regra de 1h. De dia, continua o chefe de espécie atual.

- O andar 5 da Caverna é novo. Ele só abre a partir do covil do lobisomem (andar 4) para quem cumpriu o arco.
- O GDD §10.4 punha o Boitatá no topo da Chapada. Isso deixa de valer: a Chapada continua com os chefes de espécie atuais (Tatu-Montanha, Queixada, Mula de Brasa etc.).
- O GDD §4.2 dizia "Curupira: NPC, não inimigo". Passa a ser NPC de dia e chefe atroz de noite.

---

## 2. Mapa do arco

Níveis do chefe: os mesmos usados nos itens da seção 6.1. Níveis do mapa: `recommended_level_*` das zonas atuais.

| # | Chefe (rank) | Nível do chefe | Onde nasce (à noite) | Nível do mapa | Bando (≥ 10, nível do mapa) | Quest de ativação |
|---|---|---|---|---|---|---|
| 1 | Saci Atroz (C) | ~12 | Campos — Passo dos Ipês → *Redemoinho do Passo* | 1–10 | Redemoinhos Arteiros | A Peneira de Cruzeta |
| 2 | Mula-sem-Cabeça Atroz (B) | ~25 | Chapada — Alto das Brasas → *Encruzilhada das Brasas* | 12–25 | Mulas de Brasa e Serpentes-Fagulha | Ferraduras em Brasa |
| 3 | Lobisomem Atroz (A) | ~30 | Caverna do Reino Encoberto — covil do andar 4 | 25–30 | Lobisomens da caverna e morcegos | O Causo do Lobisomem |
| 4 | Curupira Atroz (A+) | ~32 | Mata Encantada — Coração da Mata → *Clareira das Pegadas* | 6–12 | Bichos da mata corrompidos: vaga-lumes, onças, lobos-guará | Pegadas ao Contrário |
| 5 | Pisadeira Atroz (B) | ~50 | Vilarejo de Hoer Verde — andar 4, estalagem | 46–52 | Possuídos e sombras sussurrantes | Barriga Cheia, Sono Pesado |
| 6 | Iara Atroz (A) | ~36 | Cidade Perdida de Z — Rio → *Remanso da Iara* | 32–36 | Sucuris e jacarés | O Canto no Rio |
| 7 | Mapinguari Atroz (S) | ~38 | Ruínas de Ratanabá — andar 4, sala dos registros | 35–38 | Sentinelas de Obsidiana | Os Selos do Arquiteto |
| 8 | Cuca Atroz (S) | ~54 | Túneis da Terra Oca — andar 5 → *Gruta do Caldeirão* | 54–60 | Aranhas tecelãs e morcegos | Nana, Nenê |
| 9 | Boiúna Atroz (S+) | ~56 | *Abismo do Sumidouro* (novo, sai do Arraial do Sumidouro) | ~50–56 | Jacarés, sucuris e serpentes do rio | A Tempestade Negra |
| F | Boitatá Atroz (SS) | ~60 | Caverna do Reino Encoberto — *andar 5* (novo) | ~55–60 | Serpentes-Fagulha, Mulas de Brasa e vaga-lumes da caverna | Todos os 9 derrotados |

Nomes em *itálico* são mapas temáticos novos (seção 2.1). O bando é uma proposta: as espécies exatas e os níveis saem dos monstros que já existem em cada mapa.

### 2.1 Mapas temáticos

Cada mapa temático é pequeno: uma arena com cara da lenda, um portal de ida e volta para o mapa de caça de origem, o covil do chefe e o bando. O nível é o do mapa de origem.

| Prioridade | Mapa | Sai de | Por quê |
|---|---|---|---|
| **Obrigatório** | Abismo do Sumidouro | Arraial do Sumidouro (cidade, sem combate) | A Boiúna não tem mapa de caça onde ficar |
| **Obrigatório** | Caverna do Reino Encoberto — andar 5 | Covil do andar 4 | Lugar do chefe final (regra 4) |
| Recomendado | Clareira das Pegadas | Coração da Mata | O Curupira é o chefe da floresta; arena de mata fechada com pegadas viradas |
| Recomendado | Encruzilhada das Brasas | Alto das Brasas | A lenda da Mula é ligada à encruzilhada; tira o chefe do meio dos covis de espécie da Chapada |
| Recomendado | Remanso da Iara | Rio da Cidade Perdida de Z | Arena de água com margem e pedras, para o empurrão do canto |
| Recomendado | Gruta do Caldeirão | Andar 5 da Terra Oca | Separa a Cuca do Titã das Profundezas, que já mora no andar 5 |
| Opcional | Redemoinho do Passo | Passo dos Ipês | Clareira de poeira e ipês; pode ficar no próprio Passo |

O Lobisomem, a Pisadeira e o Mapinguari ficam nos mapas que já existem, porque a história já os põe num lugar fechado (covil, estalagem, sala dos registros).

**Ordem.** Os capítulos 1 a 4 seguem a rota Campos → Mata → Chapada → Caverna e são feitos em sequência: cada um destrava a quest do próximo. Os capítulos 5 a 9 abrem juntos depois do capítulo 4 (quando o Curupira revela o nome de Erevos) e podem ser feitos em qualquer ordem. O final só abre com os 9.

**Ranks.** O rank mede a força do chefe, não do mapa (regra 6): o Curupira (A+, ~32) mora na Mata (6–12) e a Pisadeira (B na lore, ~50) mora em Hoer Verde (46–52). O bando é que acompanha o nível do mapa. Ver seção 9 sobre mostrar o rank na interface.

---

## 3. A história do arco `[LORE — não publicar]`

### Prólogo — As pétalas douradas

O Viajante acorda num bote coberto de pétalas do ipê dourado, como o Barqueiro já conta hoje. Nova camada: na primeira noite, ao tocar o cristal da praça, o Viajante ouve uma voz cansada. É **Eleonor**, que não pode agir no mundo e por isso chama gente de fora. "As lendas desta terra estão doentes. Elas só mostram a doença quando escurece."

Isso explica no próprio jogo por que os chefes só aparecem à noite.

### Capítulo 1 — O Saci

Os Redemoinhos Arteiros estão violentos. Dizem que "o Saci perdeu o juízo". O Saci Atroz é o Saci tomado pela corrupção: um redemoinho escuro com o gorro em brasa. Vencido, ele cai sem o gorro e volta a ser só arteiro. Rindo, conta que "uma fumaça preta subiu da terra e deixou todo mundo azedo". **Primeira pista: alguém está corrompendo as lendas.**

### Capítulo 2 — A Mula-sem-Cabeça

Tropeiros não passam pela encruzilhada do Alto das Brasas à noite. A Mula Atroz tem o fogo **preto nas pontas**, o mesmo sinal que o Boitatá terá no final. Vencida, deixa uma **brasa negra** que não se apaga. Mestre Orvalho reconhece: não é fogo desta terra.

### Capítulo 3 — O Lobisomem

É o arco de `ARCO-DO-LOBISOMEM.md`. A fera foge para a Caverna do Reino Encoberto, e a luta acontece no covil do andar 4, à noite. As três rotas mudam o desfecho (caçar, curar, pacto), mas **em todas o Lobisomem Atroz é enfrentado** para contar para o arco. Ao final, Eustáquio, já humano, conta que a sina **piorou** "desde que a fumaça subiu da caverna". A maldição é antiga e humana; a fúria nova não é.

Ele também conta que, nas noites piores, ouvia algo **mais embaixo** do covil, "como uma fogueira respirando". É o primeiro sinal do andar 5.

### Capítulo 4 — O Curupira

De dia, o Curupira é um menino comum na Mata Encantada. Fala pouco e pergunta muito. Desconfia do Viajante: acha que é mais um humano que veio queimar a mata. À noite, a corrupção o domina e ele vira o **Curupira Atroz**, o protetor da mata transformado em caçador de qualquer forasteiro.

Vencido, volta a ser menino e vira aliado. É ele quem dá o nome que os bichos sussurram: **Erevos, o Devorador de Lendas**. É a primeira vez que o nome aparece no jogo. O diário muda de "acalmar as lendas" para "descobrir o que Erevos quer", e os capítulos 5 a 9 abrem.

### Capítulo 5 — A Pisadeira

No Vilarejo de Hoer Verde, ninguém consegue dormir. A Pisadeira sobe no peito de quem dorme de barriga cheia. É o capítulo de terror: a luta acontece num pesadelo. Ela não dá pista de Maria. Só repete a frase que Erevos ouviu: **"Mataram a filha dele."** É a mentira, ainda sem contexto.

### Capítulo 6 — A Iara

Barqueiros somem no rio da Cidade Perdida de Z. A Iara Atroz puxa quem a escuta para a água. Vencida, volta ao fundo do rio e deixa um **pente de madrepérola com um golfinho entalhado**, que não é dela. **Fragmento de Maria: o objeto.**

### Capítulo 7 — O Mapinguari

Nas Ruínas de Ratanabá, o Mapinguari guarda a sala dos registros. Vencido, deixa o Viajante entrar: há registros na pedra de **uma mulher que andava entre os vilarejos, ouvindo histórias e festas**, e de um homem do rio que sempre a acompanhava. **Fragmento de Maria: o símbolo**, o mesmo golfinho do pente.

### Capítulo 8 — A Cuca

Nos Túneis da Terra Oca mora a Cuca, uma feiticeira de beleza que não envelhece e que conhece Erevos de outros tempos. Ela fala muito e mente um pouco. Conta que Erevos tinha uma filha e que "os humanos a mataram". Se o Viajante mostrar o pente da Iara, a Cuca hesita e muda de assunto. **Pista falsa deliberada** ("nem todo aliado está dizendo a verdade"). O arco não revela se foi ela quem espalhou a mentira.

### Capítulo 9 — A Boiúna

A Boiúna, serpente negra dos rios e tempestades, vive no abismo do Sumidouro. Ela **viu Maria passar** durante a fuga, e Erevos a corrompeu para que ninguém chegasse àquele ponto do rio. Vencida, diz só: "Ela subiu o rio. Não estava sozinha. Não estava com medo." **Fragmento de Maria: a testemunha.**

### Final — O Boitatá

Com os nove chefes vencidos, o Curupira, de novo menino, leva o Viajante ao covil do lobisomem. Debaixo dele há uma passagem que antes não existia: o **andar 5**, uma câmara de pedra quente onde a "fogueira que respira" de Eustáquio é o Boitatá.

Antes da guerra, o Boitatá protegia os campos das queimadas. Erevos o corrompeu com a própria fumaça e o enterrou sob a caverna. **A fumaça preta de que o Saci, o Lobisomem e o Curupira falaram saía daqui.**

A luta usa as três fases do GDD §10.4 mais uma quarta fase, a **chama negra**, quando a corrupção chega ao limite. Derrotado, o Boitatá não morre. As chamas apagam, ele recobra a consciência e mostra a memória:

> Uma mulher caminhando junto a um grande rio. Ela sorri. Ao lado dela, um homem desconhecido. Por alguns segundos, os olhos dele brilham em rosa.
>
> "A filha do Devorador nunca morreu."
> "Ela escolheu desaparecer."

**Fragmento de Maria: a memória.** O diário troca o objetivo para **"Onde está Maria?"** e o arco termina.

---

## 4. Quests de ativação `[MECÂNICA — PROVISÓRIO]`

Regras comuns a todas:

- A quest termina com um **ritual** num ponto marcado do mapa. O ritual só funciona **à noite** (relógio do jogo). De dia, o ponto mostra uma fala ("Aqui não acontece nada enquanto há sol").
- O ritual faz o chefe daquele mapa nascer na hora, se ele não estiver vivo (regra 5 da seção 1). Todos que participarem do combate e estiverem com a quest naquele passo ganham a vitória.
- Se o grupo perde ou o dia nasce, o ritual pode ser repetido na noite seguinte, **sem refazer a quest inteira**.
- Depois da primeira vitória, o jogador caça o chefe pelo nascimento natural (1h, só à noite), com drops de chefe atroz e sem progresso de história.
- Usam os sistemas que já existem: quests com etapas (matar, coletar, conversar, explorar), relatos de NPC, noite e forma atroz (`test_night`), covis de chefe.

| # | Quest | Quem dá | Etapas | Ritual (à noite) |
|---|---|---|---|---|
| 1 | **A Peneira de Cruzeta** | Dona Jacinta (feira do Porto) | Ouvir 2 relatos sobre o Saci → derrotar 12 Redemoinhos Arteiros nos Campos → coletar 3 Fiapos de Palha (drop) → Jacinta trança a peneira | Jogar a Peneira de Cruzeta num redemoinho no Passo dos Ipês |
| 2 | **Ferraduras em Brasa** | Sebastião, o tropeiro | Ir ao Alto das Brasas → coletar 5 Ferraduras em Brasa (Mulas de Brasa) → mostrar a brasa ao Mestre Orvalho | Deixar as ferraduras na encruzilhada do Alto das Brasas à meia-noite |
| 3 | **O Causo do Lobisomem** | Relatos do Porto (Arco do Lobisomem) | As 3 pistas e a rota escolhida, como em `ARCO-DO-LOBISOMEM.md` | Lua cheia (noite do jogo): a fera entra no covil do andar 4 da Caverna |
| 4 | **Pegadas ao Contrário** | O menino (Curupira, de dia) | Proteger 5 bichos feridos na Mata sem atacar animais marcados → seguir as pegadas viradas até o Coração da Mata → deixar uma oferenda (Mel de Jataí) na raiz grande | Esperar a noite junto à raiz no Coração da Mata |
| 5 | **Barriga Cheia, Sono Pesado** | Morador insone de Hoer Verde | Chegar ao andar 4 de Hoer Verde → cozinhar o Banquete Pesado (itens de drop) → comer | Sentar (descansar) na estalagem abandonada do andar 4 |
| 6 | **O Canto no Rio** | Pescador do Porto | Achar 3 pertences de barqueiros sumidos no rio de Z → ouvir a Concha que Canta | Tocar a concha na margem do rio de Z |
| 7 | **Os Selos do Arquiteto** | Mestre ou ancião ligado a Ratanabá | Derrotar o Arquiteto → coletar 4 Selos de Obsidiana das Sentinelas | Encaixar os selos na porta da sala dos registros (andar 4) |
| 8 | **Nana, Nenê** | Mãe da Criança Curiosa (Porto) | A criança some à noite → seguir os brinquedos deixados nos Túneis da Terra Oca → achar a câmara do caldeirão | Cantar a cantiga de ninar diante do caldeirão |
| 9 | **A Tempestade Negra** | Dona Ana do Sumidouro | Ouvir 3 relatos de barcos tragados → coletar 5 Escamas Negras no abismo → esperar o trovão | Lançar as escamas no abismo numa noite (efeito de tempestade) |
| F | **Debaixo do Covil** | O Curupira (menino) | Ter derrotado os 9 chefes → falar com o Curupira → ir ao covil do andar 4 | Abrir a passagem para o andar 5 à noite |

Os nomes de NPCs novos (morador de Hoer Verde, mãe da criança) são provisórios. Onde há um NPC existente que serve (pescador, Dona Ana do Sumidouro, tropeiro, Criança Curiosa), ele foi usado.

**Implementado (07/10/2026):** as etapas reais de cada quest, com ids, estão na seção 10.2. Mudanças em relação à tabela acima: no capítulo 3 quem dá a quest é a Marcelina (relatos do Guarda Tomé e do Lindolfo); no 4 os "bichos feridos" viraram a provação de proteger mudas de pequi (o sistema já tem); no 5 o Seu Firmino mora no próprio andar 4 de Hoer Verde; no 7 quem dá é o Velho Tião do Casco (o Mestre do título Mapinguari); no 8 a criança "some" à noite e volta de manhã (o Tico continua no Porto).

---

## 5. Fragmentos de Maria `[MECÂNICA]`

| Fragmento | Capítulo | Item no diário |
|---|---|---|
| Objeto | 6 — Iara | Pente de madrepérola com golfinho |
| Símbolo | 7 — Mapinguari | Decalque do golfinho de Ratanabá |
| Testemunha | 9 — Boiúna | Palavras da Boiúna |
| Memória | Final — Boitatá | A memória do rio (cena) |

Fragmentos são itens de história: não vendáveis, não negociáveis, não perdidos na morte. Ficam numa aba "Fragmentos" do diário. Eles **não** destravam o final; quem destrava é a regra dos 9 chefes.

---

## 6. Recompensas e Causos `[MECÂNICA]`

- Cada capítulo concluído concede **1 Causo** pela regra existente (uma vez por `story_id`). O arco rende até 11 Causos, o que leva o jogador de "Forasteiro" a "Lenda".
- Lendas que não morrem (Saci, Curupira, Iara, Boitatá) recuperam a consciência na cena final da luta; a recompensa vem no diálogo, além do drop atroz.
- Sugestão de recompensa única por chefe: um cosmético ou acessório com a cara da lenda (gorro do Saci, ferradura em brasa, folha do Curupira…). Fica para a fase de itens.

### 6.1 Itens do arco `[PROVISÓRIO]`

**Itens de quest** (material, não negociáveis, não vendáveis):

| Item | id | Capítulo | Como se obtém |
|---|---|---|---|
| Fiapo de Redemoinho | `whirlwind_wisp` | 1 | Drop dos Redemoinhos Arteiros com a quest ativa |
| Peneira de Cruzeta | `cross_sieve` | 1 | Dona Jacinta trança com 3 fiapos |
| Ferradura em Brasa | `ember_horseshoe` | 2 | Drop das Mulas de Brasa com a quest ativa |
| Mel de Jataí | `jatai_honey` | 4 | Colmeias da Mata Encantada |
| Banquete Pesado | `heavy_feast` | 5 | Cozinhado com drops de Hoer Verde |
| Concha que Canta | `singing_shell` | 6 | Pescador do Porto, depois dos 3 pertences |
| Selo de Obsidiana | `obsidian_seal` | 7 | Drop das Sentinelas de Ratanabá com a quest ativa |
| Brinquedo Perdido | `lost_toy` | 8 | Trilha nos Túneis da Terra Oca |
| Escama Negra | `black_scale` | 9 | Abismo do Sumidouro |

Todos foram criados como itens novos (`MATERIAL`, `tradeable = false`, `sell_price = 0`; empilháveis os que a quest pede em quantidade). Não reaproveitei `red_cap`, `spinning_leaf`, `wild_honeycomb` nem `obsidian_shard` porque são drops comuns, negociáveis e vendáveis, já usados em outras quests e ofícios. **Drops ligados (07/10/2026):** pela etapa de coletar da própria quest (`QuestStep.drop_from` + `drop_chance`): o item só cai para quem tem crédito no abate e está naquela etapa, e vai direto para a mochila. A Peneira, a Concha e o Banquete são entregues pelo NPC (`QuestStep.grant_items`); os fragmentos, na vitória do ritual.

**Fragmentos de Maria** (seção 5), não empilháveis e presos ao personagem: Pente de Madrepérola (`mother_of_pearl_comb`), Decalque do Golfinho (`dolphin_rubbing`), Palavras da Boiúna (`boiuna_words`), Memória do Rio (`river_memory`).

**Equipamento dos chefes** (raridade épica; a primeira vitória garante 1 peça, as revanches têm chance):

| Chefe | Peça | id | Tipo | Atributos (nível de referência) |
|---|---|---|---|---|
| Saci | Gorro do Redemoinho | `whirlwind_cap` | Cabeça — esquiva e velocidade | DEF 6, MDEF 4, DES 4, SOR 3 (~12) |
| Mula | Facão da Encruzilhada | `crossroads_machete` | Arma de lâmina — dano de fogo | ATK 42, MATK 10, FOR 5, INT 2 (~25) |
| Mula | Ferradura de Fogo Negro | `black_fire_horseshoe` | Acessório | ATK 10, MATK 10, FOR 3, SOR 3 (~25) |
| Lobisomem | Garras da Lua Cheia | `full_moon_claws` | Luvas | DEF 14, ATK 14, FOR 5, DES 2 (~30) |
| Curupira | Arco do Menino da Mata | `forest_boy_bow` | Arco | ATK 46, DES 7, SOR 2 (~32) |
| Curupira | Pegadas Viradas | `backward_footprints` | Pés — mobilidade | DEF 12, MDEF 12, DES 6, SOR 3 (~32) |
| Pisadeira | Manto do Sono Leve | `light_sleep_cloak` | Corpo — resistência a controle | DEF 44, MDEF 36, VIT 6, ESP 7 (~50) |
| Iara | Cajado das Águas Cantantes | `singing_waters_staff` | Arma arcana | MATK 52, ATK 6, INT 7, ESP 4, conjuração −10% (~36) |
| Mapinguari | Escudo do Guardião de Ratanabá | `ratanaba_guardian_shield` | Mão secundária | DEF 34, MDEF 24, VIT 6 (~38) |
| Cuca | Tomo da Cantiga de Ninar | `lullaby_tome` | Mão secundária (arcano) | MATK 32, INT 8, ESP 5, MDEF 14, conjuração −14% (~54) |
| Boiúna | Arco da Tempestade Negra | `black_storm_bow` | Arco | ATK 66, DES 10, SOR 3 (~56) |
| Boitatá | Facão Chama-Viva, Arco Chama-Viva, Cajado Chama-Viva | `living_flame_machete`, `living_flame_bow`, `living_flame_staff` | Uma das três por vitória, conforme o caminho do jogador | Facão ATK 72; Arco ATK 74; Cajado MATK 76 (~60) |

Notas da implementação (07/10/2026):
- Nível de referência = mapa do chefe (seção 2). O Curupira ficou em ~32, pelo rank A+ e por vir depois da Caverna, e não na faixa 6–12 da Mata. A Pisadeira (rank B) ficou em ~50 porque nasce no andar 4 de Hoer Verde.
- O jogo não tem atributo de esquiva, velocidade, dano de fogo nem resistência a controle em itens. Foram aproximados com os atributos que existem: DES/SOR (esquiva, mobilidade), ATK+MATK (fogo), MDEF/ESP/VIT (controle).
- Garras da Lua Cheia não usam a Presa de Lobisomem como material: não existe ofício de forja de equipamento de chefe. A presa continua sendo a crendice que já existe.
- Visuais de mão: `blade` (facões), `simple_bow` (arcos), `staff` (cajados). Gorro, manto, pés, luvas, escudo e tomo ficam sem `visual_id` até haver arte.

### 6.2 Crendices novas `[PROVISÓRIO]`

Seguem o sistema atual (`CrendiceDatabase`): cada crendice tem atributos, um efeito especial e uma **regra de superstição** que liga ou dobra o efeito. Todas usam regras que já existem no código. As dos chefes caem raramente do chefe atroz da história; as populares caem de monstros comuns.

| Crendice | De onde cai | Regra (já existe) | Ideia do efeito |
|---|---|---|---|
| Nó de Crina Trançada | Saci | `moving_state` | Esquiva enquanto se move. Diz o povo que o Saci dá nó na crina dos cavalos; quem guarda o nó o confunde |
| Ferradura de Porta | Mula-sem-Cabeça | `hp_above_50` | Mais chance de drop. Ferradura atrás da porta traz sorte |
| Réstia de Alho | Lobisomem | `night_only` | Resistência a sombra e maldição à noite |
| Cipó da Pegada Virada | Curupira | `night_or_forest` | Velocidade de movimento na mata ou à noite |
| Travesseiro de Macela | Pisadeira | `low_hp_double` | Resistência a paralisia e sono; dobra com pouca vida |
| Escama Dourada do Rio | Iara | `water_or_rain_active` | Recuperação de mana perto da água ou na chuva |
| Unha do Guardião | Mapinguari | `still_position` | Defesa enquanto parado |
| Cantiga Bordada | Cuca | `mana_above_40` | Defesa mágica e resistência a maldição |
| Escama da Tempestade | Boiúna | `weather_rain` | Dano extra na chuva |
| Brasa que Não Apaga | Boitatá | `night_only` | Dano de fogo à noite |
| Vaso de Pimenta | Monstros da Mata (Cipó Estrangulador) | `no_curse` | Contra mau-olhado: resistência a maldição |
| Comigo-Ninguém-Pode | Monstros da Mata | `multiple_attackers` | Defesa quando cercado |
| Trevo de Quatro Folhas | Monstros dos Campos | `lucky_paw_death` | Sorte: chance de drop |

**Sinergia nova — "Lendas Libertas":** usar 3 crendices dos chefes da história ao mesmo tempo dá um bônus pequeno a todos os atributos. Fica no sistema de sinergias existente.

**Implementação (07/10/2026)** — `CrendiceDatabase`, itens `.tres` com o mesmo id:

| Crendice | id | Regra usada | Atributos | Efeito especial (chaves já lidas pelo combate) |
|---|---|---|---|---|
| Nó de Crina Trançada | `no_de_crina_trancada` | `enemy_first_strike` ⚠ | DES 3, SOR 3 | `first_strike_flee` (desvia o 1º golpe fora de combate) |
| Ferradura de Porta | `ferradura_de_porta` | `hp_above_50` | SOR 6, DEF 6 | `crit_chance_pct` 5 ⚠ |
| Réstia de Alho | `restia_de_alho` | `night_only` | MDEF 14, ESP 4 | `shadow_resist_pct` 20 |
| Cipó da Pegada Virada | `cipo_da_pegada_virada` | `night_or_forest` | DES 5, SOR 2 | `crit_chance_pct` 6, `phys_dmg_pct` 6 ⚠ |
| Travesseiro de Macela | `travesseiro_de_macela` | `low_hp_double` | MDEF 16, VIT 4 | `shadow_resist_pct` 12 ⚠ |
| Escama Dourada do Rio | `escama_dourada_do_rio` | `mana_above_20` ⚠ | ESP 6, INT 4 | `magic_dmg_pct` 8 ⚠ |
| Unha do Guardião | `unha_do_guardiao` | `still_position` | DEF 22, VIT 5 | `all_def_pct` 8 |
| Cantiga Bordada | `cantiga_bordada` | `mana_above_40` | MDEF 24, ESP 6 | `shadow_resist_pct` 18 |
| Escama da Tempestade | `escama_da_tempestade` | `night_only` ⚠ | ATK 12, MATK 12 | `ignore_def_pct` 12, `magic_dmg_pct` 8 |
| Brasa que Não Apaga | `brasa_que_nao_apaga` | `night_only` | ATK 16, MATK 16 | `phys_dmg_pct` 12, `magic_dmg_pct` 12 |
| Vaso de Pimenta | `vaso_de_pimenta` | `no_curse` | MDEF 8 | `shadow_resist_pct` 10 |
| Comigo-Ninguém-Pode | `comigo_ninguem_pode` | `low_hp_double` ⚠ | DEF 10, VIT 2 | `all_def_pct` 5 |
| Trevo de Quatro Folhas | `trevo_de_quatro_folhas` | `lucky_paw_death` | SOR 4 | `crit_chance_pct` 3 ⚠ |

⚠ = trocado em relação à tabela acima, porque o original não funcionaria com o código atual:
- `moving_state` (Nó de Crina), `weather_rain` (Escama da Tempestade) e `multiple_attackers` (Comigo-Ninguém-Pode) existem no `CrendiceSystem`, mas nenhum contexto do servidor envia `is_moving`, `is_raining` ou `attackers_count`. Nunca ligariam. Trocadas por `enemy_first_strike`, `night_only` e `low_hp_double`.
- `water_or_rain_active` (Escama Dourada) não está no `match` do `CrendiceSystem` (cai no "sempre ativo"). Trocada por `mana_above_20`.
- `still_position` (Unha do Guardião) e `no_curse` (Vaso de Pimenta) foram mantidas, mas hoje ficam **sempre ativas**, porque o contexto não envia movimento nem maldição.
- Não existem efeitos de esquiva contínua, velocidade de movimento, chance de drop, resistência a sono/paralisia nem regeneração de mana no combate (`flee_pct`, `drop_rate_pct`, `stun_immunity`, `curse_resist_pct` etc. estão nos dados mas nenhum código lê). Foram usados só `first_strike_flee`, `shadow_resist_pct`, `all_def_pct`, `crit_chance_pct`, `phys_dmg_pct`, `magic_dmg_pct` e `ignore_def_pct`, mais SOR (que já pesa no drop e no crítico) e ESP (que já pesa na regeneração de mana).
- **Lendas Libertas**: sinergias só dão efeitos especiais, não atributos. Ficou +5% defesa geral, +5% dano físico, +5% dano mágico e +3% crítico. Comigo-Ninguém-Pode e Vaso de Pimenta entraram na sinergia Proteção Total; o Trevo, na Espírito da Caça.
- **Drops:** Vaso de Pimenta cai de `strangler_vine`, `wandering_spider` e `brown_recluse`; Comigo-Ninguém-Pode de `strangler_vine`, `coral_snake`, `harpy_eagle` e `pindorama_jaguar`; Trevo de `prank_whirlwind`, `enchanted_firefly` e `buriti_boar` (só de dia). Todas a 3%. O Cipó Estrangulador (`strangler_vine`) existe mas não está posicionado em nenhum mapa hoje. **As 10 dos chefes estão ligadas (07/10/2026):** `monster_ids = [&"story_<chefe>"]`, `chance = 0.05`, só atroz e à noite. As dos chefes com arte pendente só caem quando eles forem ligados (não nascem em mapa).

Todas são crendices populares, sem objetos de religiões vivas (nada de fitas de santo, búzios ou guias de terreiro), seguindo o GDD §4.0.

Os atributos ficam um degrau acima dos itens atrozes atuais da mesma faixa de nível. Os visuais de mão reaproveitam os existentes (`visual_id`) até haver arte própria de arma. Os ícones saem pelo pipeline de `game/tools/art/icons/gen_icons.py`.

---

## 7. Regras culturais aplicadas (GDD §4.0)

- **Curupira:** folclore de domínio público, não é divindade de religião viva. Como decidido pelo dono, de dia é um menino comum. Se quiser uma única marca do folclore, os **pés virados para trás** podem aparecer só nas pegadas da quest, nunca no sprite de dia.
- **Saci, Iara, Boitatá:** não morrem. São libertados da corrupção ao fim da luta.
- **Cuca:** decisão do dono (07/10/2026): **bruxa jovem, bonita e misteriosa**, não uma velha. A referência de clima é a Cuca de *Cidade Invisível* (Netflix), mas o design é **original**: não copiar figurino, penteado nem o rosto da atriz, porque é obra autoral recente (regra 2) e envolve direito de imagem. Sem sensualização. Continua proibida a Cuca jacaré do *Sítio do Picapau Amarelo*. A ligação com a Coca portuguesa segue como gancho para o Reino das Mouras.
- **Mula-sem-Cabeça:** sem o componente religioso da lenda, como já está na Mula de Brasa.
- **Boto:** só aparece como "o homem do rio" e pelo brilho rosado. O nome fica para o Arco 2.
- **Eleonor e Erevos** são entidades criadas pelo projeto, não divindades de religiões vivas.

---

## 8. O que o site pode contar

Decisão do dono (07/10/2026): o site conta a **premissa da lore**, mas **nunca que Maria está viva**. A seção "A história" (`site/index.html#historia`) foi escrita com essa regra.

**Pode:**
- Eleonor (o mundo e o Deus da Criação), Erevos e a guerra contra a humanidade, as lendas corrompidas.
- Maria como filha de Erevos que amava os humanos e **desapareceu**, e a notícia de que foi morta por humanos, que Erevos acreditou.
- O Viajante chamado por Eleonor, chegando pelo rio nas pétalas do ipê.
- "Nem todo monstro é inimigo, e nem todo aliado diz a verdade"; as lendas só mostram a corrupção à noite.
- Os Causos, lugares, monstros comuns, chefes de espécie, Mestres e títulos.

**Não pode:**
- Que Maria está viva, que fugiu, o Boto ("homem do rio"), que a notícia da morte é mentira, os fragmentos e a revelação do Boitatá.
- Quais lendas são os chefes da história, os rituais e o andar 5.
- A identidade de quem é o lobisomem ou o desfecho de qualquer causo.

No jogo, o nome de Erevos continua aparecendo só a partir do capítulo 4: o site apresenta o vilão, e o jogo revela aos poucos a ligação dele com cada lenda.

## 9. Pontos em aberto para o dono

1. **Um herói ou muitos?** A lore fala de "nosso herói" convocado. Em MMO, todo jogador é Viajante. Proposta: Eleonor chama muitos; a história é a mesma para cada um.
2. **Ranks na interface:** mostrar C/B/A/S/SS no jogo ou deixar só na documentação?
3. **Rota do pacto do Lobisomem:** em `ARCO-DO-LOBISOMEM.md` a rota do pacto pode terminar sem luta. Com a regra "derrotar todos", proposta: no pacto, a luta acontece contra a fera para contê-la, sem matá-la. Confirmar.
4. **Quem espalhou a mentira?** Deixei a Cuca como suspeita sem confirmar. Confirmar ou trocar o suspeito?
5. **Mapinguari:** já existe o título "Mapinguari" (caminho do Tanque). Manter o nome do título agora que o Mapinguari é um chefe da história, ou renomear?
6. **Kuarahy Soberano** (chefe da Cidade Perdida de Z): Kuarahy é o Sol para povos Guarani, em tradição religiosa viva. Pela regra 3 do GDD §4.0, convém trocar o nome ou a natureza desse chefe. Fica fora do Arco 1, mas é a mesma revisão cultural.
7. **Arte:** são 10 chefes atrozes novos (o Lobisomem já tem forma atroz). Eles devem seguir o mesmo padrão de qualidade decidido para os monstros regionais (o do Tatu-Pedra), em quadro de chefe (240 px).

---

## 10. Implementação `[07/10/2026]`

### 10.1 Como a cadeia e a trava funcionam

- Cada capítulo é uma `QuestDef` em `game/data/quests/arc1_*.tres`. A ordem usa `required_quests`: 1 → 2 → 3 → 4; os capítulos 5 a 9 pedem só o 4; o final pede os 9.
- **Trava do final:** `arc1_final_boitata.required_quests` tem os 9 capítulos e **não** usa `skip_unreleased_requirements`, então só abre com os 9 entregues de verdade.
- **Capítulo desligado no meio da cadeia:** enquanto a Mula espera arte, o capítulo 3 usa `skip_unreleased_requirements = true` (pula só quest com `released = false`). Assim o jogador vai do 1 ao 3. Quando a Mula for liberada, o 3 volta a exigir o 2 e o 2 abre para quem já fez o 1 (inclusive quem já passou do 3).
- **Capítulo 3:** exige o Arco do Lobisomem concluído por qualquer rota (`required_story_completed = [&"lobisomem_arc"]`, novo campo). As três rotas não foram mexidas. A fala de conclusão muda pelo desfecho (`complete_text_variants`: `ending:killed`, `ending:pacted`; a Benzedura usa a padrão).
- **Causos:** cada capítulo e o final têm `reward_causo_id` próprio (`arc1_saci`, `arc1_mula`, `arc1_lobisomem`, `arc1_curupira`, `arc1_pisadeira`, `arc1_iara`, `arc1_mapinguari`, `arc1_cuca`, `arc1_boiuna`, `arc1_boitata`). Com o `lobisomem_arc`, o arco rende 11. O prólogo é opcional e não dá Causo.
- **Equipamento:** a peça do chefe é `reward_items` da entrega (primeira vitória, garantida); a forma atroz tem a mesma peça como drop de revanche (4–8%). O Boitatá entrega Facão, Arco ou Cajado Chama-Viva pelo arquétipo do título exibido (`reward_by_archetype`).
- **Ritual** (`QuestStep.StepType.RITUAL`, sempre a última etapa de cada capítulo): no covil do chefe (`StoryLairs/`, raio de 6 células), à noite, chama `MonsterSpawner.summon_story_boss`: se o chefe não está vivo, ele nasce na hora (zera a 1 h); se já está vivo, só avisa; de dia responde "Aqui não acontece nada enquanto há sol". Nunca cria um segundo. Se a etapa tem `ritual_item` (peneira, ferraduras, mel, banquete, concha, selos, escamas), ele precisa estar na mochila e só é gasto na vitória: perder ou amanhecer não obriga a refazer a quest.
- **Crédito de história:** quando um chefe `story_boss` cai, `Progression.story_participants` junta quem já tem crédito no abate (dono e grupo por perto), quem bateu e quem foi atacado por ele. Todos que estiverem com a quest na etapa RITUAL daquele chefe ganham a vitória (`QuestService.on_story_boss_killed`), venha o chefe do ritual ou do nascimento natural. A fala da lenda depois da luta aparece na hora (`done_text_key` da etapa).
- **Falas longas em páginas:** chave `KEY`, `KEY_P2`, `KEY_P3`…; o diálogo mostra "Continue..." até a última página (`QuestService.page_count`). Vale para oferta, progresso, conclusão e causos.

### 10.2 Quests criadas

| id | Nome | Quem dá (entrega) | Etapas | Recompensa |
|---|---|---|---|---|
| `arc1_prologue_petals` | As Pétalas Douradas | Barqueiro Benedito | À noite, tocar o cristal da praça (`EleonorCrystal`): a voz de Eleonor | XP |
| `arc1_ch1_saci` | A Peneira de Cruzeta | Dona Jacinta | Causo da Jandira → causo do Seu Benedito → 12 Redemoinhos → 3 Fiapos (drop da quest) → Jacinta trança a Peneira → ritual no Passo dos Ipês | Gorro do Redemoinho |
| `arc1_ch2_mula` | Ferraduras em Brasa | Seu Benedito, o tropeiro (entrega: Mestre Orvalho) | Encruzilhada do Alto das Brasas (`BrasasCrossroads`) → 5 Ferraduras em Brasa (Mulas de Brasa) → Orvalho examina → ritual | Facão da Encruzilhada + Ferradura de Fogo Negro |
| `arc1_ch3_lobisomem` | O Causo do Lobisomem | Marcelina | Causo do Guarda Tomé (fumaça preta) → causo do Lindolfo → ritual no covil do andar 4 | Garras da Lua Cheia |
| `arc1_ch4_curupira` | Pegadas ao Contrário | Curupira (menino) | Proteger 3 mudas dos vaga-lumes (provação) → pegadas viradas no Coração da Mata (`BackwardTracks`) → Mel de Jataí (porcos-do-mato) → ritual na raiz grande. **Erevos aparece aqui.** | Arco do Menino da Mata + Pegadas Viradas |
| `arc1_ch5_pisadeira` | Barriga Cheia, Sono Pesado | Seu Firmino (Hoer Verde 4) | Causo da estalagem ("Mataram a filha dele") → 8 Possuídos → cozinha (`StoryInn`) → Firmino cozinha o Banquete → deitar à noite, quieto, 8 s → ritual | Manto do Sono Leve |
| `arc1_ch6_iara` | O Canto no Rio | Pescador Lindolfo | Chapéu, remo e rede no rio de Z (`BoatmanHat`, `BoatmanOar`, `BoatmanNet`) → Lindolfo faz a Concha que Canta → ritual na margem | Cajado das Águas Cantantes; **Pente de Madrepérola** na vitória |
| `arc1_ch7_mapinguari` | Os Selos do Arquiteto | Velho Tião do Casco | Arquiteto (chefe do covil) → 4 Selos de Obsidiana (Sentinelas) → ritual na sala dos registros | Escudo do Guardião; **Decalque do Golfinho** na vitória |
| `arc1_ch8_cuca` | Nana, Nenê | Dona Celeste, mãe do Tico | Sonho do Tico → 3 Brinquedos Perdidos (Tecelãs da Sombra) → câmara do caldeirão (`CauldronChamber`) → ritual. A Cuca mente ("os humanos a mataram"); com o pente na mochila, a conclusão conta que ela hesitou | Tomo da Cantiga de Ninar |
| `arc1_ch9_boiuna` | A Tempestade Negra | Dona Ana do Sumidouro | Causo do Barqueiro → causo do Lindolfo → 5 Escamas Negras → ritual no abismo | Arco da Tempestade Negra; **Palavras da Boiúna** na vitória |
| `arc1_final_boitata` | Debaixo do Covil | Curupira (menino) | Passagem atrás do covil do andar 4 (`DeepPassage`) → ritual do andar 5 (memória do rio e as falas exatas) → "Onde está Maria?" | Arma Chama-Viva pelo caminho; **Memória do Rio** na vitória |

Textos: `game/localization/story_arc1.csv` (264 chaves, pt-BR). Diálogo de cada NPC novo: `game/data/dialogues/<id>.tres`.

### 10.3 NPCs criados

| id | Nome | Onde | Sprite |
|---|---|---|---|
| `dona_jacinta` | Dona Jacinta, a peneireira | Porto, feira (`NpcPoints/dona_jacinta`) | **falta arte** (`npc_dona_jacinta`); reserva `npc_master_candeia` |
| `firmino_insone` | Seu Firmino, o que não dorme | Hoer Verde, andar 4, perto da entrada | **falta arte** (`npc_firmino_insone`); reserva `npc_elder_ze_ferreiro` |
| `dona_celeste` | Dona Celeste, mãe do Tico | Porto, perto do Tico | **falta arte** (`npc_dona_celeste`); reserva `npc_master_guiomar` |

### 10.4 Chefes da história e covis

- `game/data/monsters/story_*.tres`: `story_boss = true`, só os estágios 3 (atributos) e 4 (nome, folhas, nível, drops), `atroz_stat_multiplier = 1.0`, `baked_life = true`, sem raro, `respawn_sec = 3600`. Níveis da seção 2.
- Covil: `StoryLairs/<nome>` no mapa, com metas `monster_id`, `radius_cells`, `escort` (`{espécie: quantidade}`, mínimo 10) e `escort_stage`. `respawn_sec` padrão 3600. O `MonsterSpawner` faz nascer só à noite, já atroz e fixo (`atroz_pinned`); ao amanhecer, vivo e fora de luta, some com o bando; derrotado, volta em 1 h na próxima noite; no máximo 1 vivo por mapa. Vale em qualquer zona de caça, mesmo sem covil de espécie (regra 6).
- Covis colocados: Passo dos Ipês (`story_saci`, 12 Redemoinhos), Coração da Mata (`story_curupira`, vaga-lumes + onças + queixadas), Caverna andar 4 (`story_lobisomem`, 4 lobisomens + 6 morcegos) e Hoer Verde 4 (`story_pisadeira`, 5 Possuídos + 5 Vultos Sussurrantes, na estalagem).
- Caverna andar 4: o covil de espécie (`BossLairs/werewolf`) ganhou `day_only = true`: de dia é o chefe de espécie de sempre; à noite ele some (fora de luta) e o Lobisomem Atroz da história nasce no mesmo lugar. A saída de fuga do andar 4 também abre com a vitória sobre ele.
- Desvio da seção 2: o bando do Curupira troca lobo-guará por queixada, porque o lobo-guará da Mata é nível 17+ e o bando segue o nível do mapa (6–12).

### 10.5 Chefes ligados `[08/10/2026]`

**Os 10 chefes da história estão ligados** (arte instalada, sem `art_pending`, quests liberadas, covil no mapa). Todos os capítulos e o final são jogáveis; o final continua só abrindo com os 9 capítulos entregues.

| Chefe | Covil (mapa) | Bando (>= 10) |
|---|---|---|
| Saci | Passo dos Ipês (`fields_pindorama_crossroads`) | `prank_whirlwind` 12, estágio 1 |
| Curupira | Coração da Mata (`enchanted_forest_heart`) | vaga-lumes 4 + onças 3 + queixadas 3, estágio 2 |
| Lobisomem | Caverna andar 4 (`cave_reino_encoberto_4`), no lugar do covil de espécie à noite | `cave_werewolf` 4 + `cave_bat` 6, estágio 2 |
| Pisadeira | Hoer Verde 4, estalagem | Possuídos 5 + Vultos 5, estágio 2 |
| Mula | Alto das Brasas (`split_sky_plateau_summit`), encruzilhada `BrasasCrossroads` | `highland_ember_mule` 6 + `highland_cinder_serpent` 4, estágio 1 |
| Mapinguari | Ruínas de Ratanabá 4, sala dos registros (-12, -24), ao lado do covil do Arquiteto | `ratanaba_sentinel` 6 + `crystal_serpent` 4, estágio 2 |
| Iara | Rio de Z (`jungle_z_river`), margem em (-8, 2) | `river_anaconda` 5 + `black_caiman` 5, estágio 2 |
| Cuca | **Gruta do Caldeirão** (`hollow_earth_cauldron`, mapa novo) | `shadow_weaver` 6 + `living_crystal` 4, estágio 2 |
| Boiúna | **Abismo do Sumidouro** (`sumidouro_abyss`, mapa novo) | `abyss_black_caiman` 4 + `abyss_river_anaconda` 4 + `abyss_water_serpent` 4 |
| Boitatá | **Câmara da Fogueira, Caverna F5** (`cave_reino_encoberto_5`, mapa novo), (0, -16) | `deep_cinder_serpent` 5 + `deep_ember_mule` 5 |

**Quem gera o quê:** `game/tools/world/build_story_arc1.py` (último passo do `build_all.py`) cria os mapas novos e as variantes de monstro, e remenda os mapas que já existem: covis `StoryLairs/`, marcadores das quests, NPCs novos, portais novos, `connected_maps` e o `day_only` do andar 4. Ele tira e põe de novo só os nós dele, então rodar o `build_all` não apaga nada do arco. Chefe com `art_pending = true` não ganha covil (para desligar um chefe de novo: pôr `art_pending = true` no monstro e `released = false` na quest, e rodar o gerador).

### 10.5.1 Mapas novos `[08/10/2026]`

| Mapa | Nome | Nível | Entrada (e volta) | Conteúdo |
|---|---|---|---|---|
| `sumidouro_abyss` | Abismo do Sumidouro | 50–56 | Portal `GateAbyss` no Arraial do Sumidouro (chegada `AbyssReturn`) | Funil de pedra molhada até o poço; jacarés, sucuris e serpentes do Abismo (variantes recoloridas, `base_species` = a original); covil da Boiúna. As Escamas Negras do capítulo 9 caem da Sucuri do Abismo |
| `cave_reino_encoberto_5` | Câmara da Fogueira (Caverna, F5) | 55–60 | Portal `DeepPassagePortal` atrás do covil do andar 4 (chegada `DeepPassageReturn`). **Só passa quem tem o final disponível, ativo ou feito** (`requires_quest = arc1_final_boitata`, `MapTransfer.story_passage_open`); os outros veem "A fenda está quente demais para passar" | Garganta estreita até a câmara de terra vermelha; serpentes-fagulha e mulas de brasa profundas; covil do Boitatá |
| `hollow_earth_cauldron` | Gruta do Caldeirão | 54–60 | Portal `CauldronPassage` no andar 5 da Terra Oca (chegada `CauldronReturn`) | Tecelãs e cristais; marcador `CauldronChamber` (capítulo 8) e covil da Cuca, longe do Titã |

São protótipos jogáveis no mesmo motor dos andares da Terra Oca (salas, corredores, pilares, chão pintado e luz do tema), com minimapa gerado da grade. Estão no atlas: o Abismo como lugar próprio; o F5 dentro da Caverna; a Gruta dentro da Terra Oca.

**Para depois (mapas temáticos recomendados/opcionais da seção 2.1):** Clareira das Pegadas (Curupira, sai do Coração da Mata), Encruzilhada das Brasas (Mula, sai do Alto das Brasas), Remanso da Iara (sai do rio de Z) e Redemoinho do Passo (Saci, sai do Passo dos Ipês). Hoje esses chefes ficam nos mapas de caça; para mudar, basta trocar o mapa do covil no `STORY_LAIRS` do gerador.

### 10.5.2 Luta do Boitatá por fases `[08/10/2026]`

`game/scripts/server/monsters/boitata_fight.gd` (comportamento `&"boitata_phases"` no `story_boitata`):

| Fase | Vida | O que faz |
|---|---|---|
| 1 | 100–60% | Mordida (golpe normal) e **Sopro de Fogo** em cone de 90°, 5 células, com aviso no chão 1 s antes (a cada 7 s) |
| 2 | 60–30% | Invoca **3 fogos-fátuos** (`boitata_wisp`) que perseguem; cada um deixa **rastro de fogo** no chão (zona de dano de 4 s, a cada 2 s) |
| 3 | 30–10% | Mais rápido (passo ×0,7, golpe ×0,75) e **Anéis de Fogo**: dois círculos de 3 células (um embaixo do alvo) com aviso de 1,5 s que queimam por 5 s (a cada 9 s) |
| 4 | < 10% | **Chama negra**: dano ×1,5 (golpe e habilidades) e aparência `black_flame` (aura quase preta, roxa e pulsando rápido no cliente) |

- As fases não voltam; só quando ele volta para casa e recupera a vida (os fogos-fátuos somem). Morto, os fogos-fátuos somem.
- As habilidades são `SkillDef` em `game/data/monster_skills/` (novo diretório do `Content`, fora das skills de jogador), tocadas pelo mesmo `NetProgress.skill_cast` das skills: o cliente mostra o aviso no chão (`ground_warning_sec`) e o fogo do *Fogo Rastejante*. O dano no chão usa as zonas do `StatusEffects`.
- Efeito visual novo mínimo: tinta e pulso da aura atroz trocados na chama negra (`AtrozVisual`). Sem arte nova de efeito; quando o Boitatá ganhar arte própria, vale um efeito de chama negra dedicado.
- Comandos de teste (`--dev-commands`): `/vida <0-100>` põe o chefe mais perto naquela porcentagem; `/imortal` dá 10 min sem cair.

### 10.6 Pendências conhecidas

- **Curupira de dia e de noite:** o NPC menino (Raízes da Mata) continua visível à noite enquanto o Curupira Atroz anda no Coração da Mata. Esconder o NPC à noite precisa de rotina de NPC por hora (não existe).
- **Diário "Onde está Maria?":** não há objetivo de diário fora das quests; a pergunta fecha a fala de conclusão do final. Uma aba "Fragmentos" no diário também não existe (os fragmentos são itens presos ao personagem).
- **Fala da lenda depois da luta:** vai como mensagem do sistema (sem cena).
- Arte dos 3 NPCs novos (reserva em uso, ver 10.3).
- Testes: `tests/story/test_arc1.tscn` (unitários) e `tests/story/run_arc1_test.sh` (servidor + cliente: noite, 1 h, ritual sem duplicar, amanhecer, andar 4, falas em páginas, chefes liberados nos covis novos, passagem selada do andar 4 e as 4 fases do Boitatá).
- Rotina do NPC por hora, aba de Fragmentos / "Onde está Maria?" e cena da fala da lenda: com outro agente.
