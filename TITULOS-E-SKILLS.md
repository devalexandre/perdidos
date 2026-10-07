# Títulos e Skills — Projeto Isekai

> **Versão:** 0.6 — 05/10/2026 (sem nível nas quests de título, etapas de veterano, quest de título solo, sub-histórias dos anciãos e Causos como renome). 0.5 — 01/10/2026 (quest por título, árvore de cinco skills concedida com o título, escala global de dificuldade; caverna da Mata reservada para planejamento cultural). v0.4 em `.work/TITULOS-E-SKILLS.v04.md`.
> **Base:** GDD §1–2, §4.0, §6.2, §7, §8 (§8.1, §8.4 e §8.5), §9, §10.6 e §14.
> **Status:** as **regras** dos títulos são `[FECHADO]` (decisões do dono, GDD §8.5). **Nomes, listas e números** são `[PROVISÓRIO]`. As questões pendentes estão na seção 7, com padrão recomendado.
> **Regra de ouro (GDD §0.5):** nenhum nome de classe ou de skill de Ragnarok Online nem de outro jogo. Tudo aqui é original.

---

## 1. Como os títulos funcionam

### 1.1 Regras `[FECHADO]`

| Regra | Definição |
|---|---|
| Classes | **Não existem.** Nenhuma skill ou magia depende de classe. |
| Aprender skill | Ao concluir a **quest de conquista do título**, o personagem recebe as cinco skills da árvore no nível 1, sem gastar pontos. Títulos de ramo também concedem as árvores ancestrais. Pontos de skill servem para subir níveis. |
| Nível e quests | **Campo de Treino exige Nível 5** e limita a conquista a **1 único título** no campo. Ao sair para o mundo, cada novo título adquirido escala em dificuldade: o 2º título exige Nível 10, o 3º Nível 15, o 4º Nível 20, acompanhado de missões mais complexas, abates adicionais e itens raros. |
| Conquista | **Por quest**, nunca automática por aprender skills. Cada título exige uma quest com narrativa folclórica e objetivos próprios (abates, coleta, conversas, provações); ao concluir, entra no painel e concede sua árvore de skills. |
| O que libera | Quests de **skills exclusivas** do título. No futuro, também diálogos, itens com requisito de título e cosméticos. |
| **Regionais** | O nome vem da **cultura da região** onde o título é conquistado. O mesmo arquétipo (lâmina, arco, magia, cura, furtividade…) tem **skills diferentes** em cada nação. |
| **Ramos** | O **primeiro título** de um caminho abre **dois ramos**, cada um com skills exclusivas. Depois do MVP, quem tiver os dois ramos pode chegar a um **ápice**. |
| Vários títulos | Um personagem pode acumular quantos quiser, de qualquer região e escola, mas **exibe um** sob o nome. |
| Híbridos | Títulos de escolas diferentes, combinados, podem liberar títulos híbridos. |
| Justiça (GDD §14) | Título nunca é vendido nem acelerado com dinheiro. No máximo, pode haver moldura cosmética para um título que o jogador já conquistou jogando. |

### 1.2 Progressão ao redor dos títulos `[FECHADO]`

- **Por nível de personagem:** 3 pontos de atributo (FOR, DES, VIT, INT, ESP; cada um melhora coisas específicas, GDD §6.2) e 1 ponto de skill.
- **Pontos de skill:** vão para qualquer skill já conhecida, até o nível 10 dela. No nível máximo do MVP (25), o personagem soma **cerca de 24 pontos**. Maximizar uma única skill custa 9. **Onde investir é a decisão de build.**
- **Barra de atalhos:** 10 espaços (teclas 1 a 0). O jogador conhece mais skills do que cabem na barra, e isso é intencional.
- Premissa deste documento: a skill aprendida começa no **nível 1**. Um requisito como "L1 no nível 5" pede pontos de skill, não nível de personagem.

### 1.3 Forma de um caminho

```
            ┌── Ramo A (título) ── skill(s) exclusiva(s)
Primeiro ───┤                                          ├── Ápice (pós-MVP, opcional)
 título     └── Ramo B (título) ── skill(s) exclusiva(s)
```

| Camada | Como se conquista | Cor do título (paleta mestra) |
|---|---|---|
| 0 — Chegada ("Viajante") | Todo personagem começa com ela | Pergaminho `#c9b08a` |
| 1 — Primeiro título | Quest de título da escola na região | Verde água `#4fa8a0` |
| 2 — Ramo | Quest do ramo, após o título pai | Azul céu `#5a90e0` |
| 3 — Ápice (pós-MVP) | Os dois ramos + uma skill de ápice | Ouro `#e6b43a` |
| H — Híbrido | Títulos de duas escolas | Roxo `#8e66c4` (borda na cor da camada) |

### 1.4 Regras de desenho

1. **O título libera, não dá poder por si.** O poder vem das skills exclusivas, que ainda exigem quest e pontos de skill.
2. **Os ramos não se excluem** (padrão recomendado, seção 7): o jogador pode fazer os dois. Os limites são o tempo de quest, os pontos de skill e a barra de 10 espaços.
3. **A quest de uma exclusiva fica em lugar perigoso**, nunca atrás de nível. A área citada é só recomendação.
4. **Cinco skills por título**, numa árvore própria com pré-requisitos (v0.4, §3.0); as cinco são concedidas ao conquistar o título.
5. **Dificuldade progressiva (05/10/2026), nunca por nível.** Quest de título não pede nível de personagem em lugar nenhum (nem no Campo de Treino). A cada título não inicial já conquistado: abates comuns e coletas da lição crescem **50%** (1 título ×1,5; 2 ×2; 3 ×2,5) e entram **etapas de veterano** (`QuestStep.min_prior_titles`): com 1 título, trazer 2 relíquias raras (Caco de Casco Antigo, Raiz de Pequi ou Brasa Eterna, de raro/chefe/atroz); com 2, derrotar o chefe do covil da espécie da lição; com 3, derrotar qualquer chefe na forma atroz.
6. **Um título no Campo de Treino (05/10/2026).** No treino o personagem conquista só UM título; qualquer outra quest de título (de Mestre, ancião ou lição que dá título) fica bloqueada até ele sair do Campo de Treino.
7. **Quest de título é solo (05/10/2026).** Ao aceitar, o personagem sai do grupo e não entra em outro enquanto houver etapa em andamento. Só contam os abates dele (crédito de grupo não vale) e os itens que ele mesmo pegar do chão durante a etapa de coleta (troca, loja e mochila antiga não contam).
8. **Sub-histórias dos anciãos (05/10/2026).** As quests de combinação (2–3 títulos) são sub-histórias com lore própria: pedem **renome 3** (`required_causos`), têm duas etapas de causo falado (o NPC ganha a opção "[Causo]" e conta um trecho; `QuestStep.lore_text_key`) e, ao concluir, rendem um Causo próprio (+3 de renome).

### 1.5 Causos = renome `[05/10/2026]`

Causos são a fama do personagem pelos seus feitos (pontos, uma vez por feito):

| Feito | Renome |
|---|---|
| História/sub-história concluída | +3 |
| Título conquistado | +1 |
| 1ª vitória sobre o chefe (estágio 3) de uma espécie, com nível acima do seu | +1 |
| 1ª vitória sobre a forma atroz de uma espécie, com nível acima do seu | +2 |

Monstros de provação não contam; o crédito é de quem causou mais dano. Molduras: Forasteiro 0 · Falado 2 · Assunto da Vila 5 · Causo de Fogueira 10 · Lenda 18 · Mito 30. Cada moldura libera itens nas lojas (`ShopDef.causos_rank_N_items`) e o renome libera sub-histórias de título. Saves antigos: 1 Causo por história vira 3 pontos, e cada título já conquistado soma 1.
6. **O nome do título indica o estilo de jogo** (defesa, dano concentrado, emboscada, precisão, proteção, cura…).

---

## 2. Como nomear títulos

**Princípio** (um item por linha):
1. **Curto e memorável:** de 1 a 3 palavras, fácil de pronunciar para qualquer jogador brasileiro, e que faça sentido já na primeira leitura.
2. **A cara da região:** o nome vem do folclore, da paisagem, dos bichos, das armas e dos ofícios da região ("Garra da Onça", "Tocaia do Brejo", "Olho do Boitatá").
3. **Diz como se joga:** quem lê o nome adivinha o estilo (quem é tronco segura, quem é garra ataca, quem é tocaia embosca).
4. **Palavras de origem tupi só se forem do dia a dia do português** (onça, ipê, sabiá, jabuti, caipora, curupira, buriti, cerrado, pororoca…), sem termos que peçam dicionário.
5. **Respeito:** figuras do folclore em domínio público podem batizar títulos com respeito ("Amigo do Curupira"). **Nunca** divindades de religiões vivas, caricaturas, nem nomes de classes ou skills de Ragnarok ou de outros jogos.

**Palavras que evitamos mesmo sendo comuns**, porque são nomes de classes de Ragnarok na versão brasileira: Espadachim, Mago, Arqueiro, Cavaleiro, Caçador, Aprendiz, Guardião, Andarilho, Ninja, Sacerdote, Monge, Bardo, Mercador, Gatuno, Ferreiro e Sábio, entre outras. Por isso nomes como "Caçador de Trolls" e "Aprendiz do Curupira" viraram "Quebra-Trolls" e "Amigo do Curupira". Também evitamos **"Mestre"** nos títulos, para não confundir com os Mestres, os NPCs que ensinam.

**Termos estrangeiros para conferir antes do lançamento:** Samurai, Shinobi, Rōnin, Hoplita, Skald e Kappa são conhecidos do público. Mesmo assim, vale revisar a grafia e o contexto com quem conhece cada cultura. Cada região nova passa pela revisão cultural do GDD §4.0.

---

## 3. Terra do Sabiá — árvores de skills (v0.4, 30/09/2026)

### 3.0 Regras novas do dono `[FECHADO em 30/09/2026]`

1. **5 skills por título.** Cada título tem a sua **árvore separada** de 5 skills, com pré-requisitos entre elas (uma skill pede outra em certo nível).
2. **Herança.** O título de ramo herda a árvore do título anterior e soma as próprias 5. Quem foca num título só tem um kit completo.
3. **Suporte e tanque são títulos de combinação.** Cada um exige **3 títulos**. Ao conquistar, abre **2 ramos**:
   - suporte → **cura** ou **debuff**;
   - tanque → **guerreiro pesado** ou **berserker**.
4. **Combinações são contadas por um ancião.** Um NPC idoso conta a **lenda** do título e dá **pistas** de quais títulos ele exige, sem entregar a lista pronta. O mesmo ancião dá a **quest de conquista** a quem já tem os títulos.
5. **A quest de combinação é difícil:** derrotar um **chefe**, derrotar um chefe em **forma atroz**, coletar **itens raros** e fechar com uma provação.
   - **Chefe:** o 3º estágio da espécie, com desenho próprio. É um **chefe fixo**: mora no seu covil na Chapada do Céu Partido, anda com um bando e renasce 10 min depois de derrotado (GDD §10.6.1). Nunca aparece no Campo de Treino. Não há evolução nem chefe por contagem de abates (decisão do dono, 30/09/2026).
   - **Forma atroz:** o **mesmo chefe à noite**, mais forte (≈ +100% nos atributos) e mais agressivo (persegue mais longe, ataca mais rápido, chama a escolta). Tem **desenho próprio e detalhado**, diferente do chefe de dia. Depende do ciclo de dia e noite (GDD §10.7), que entra junto.
   - **Itens raros:** caem de monstros raros e de chefes (a chance é maior na forma atroz).
6. **Nomes pelo folclore.** Cada nação tem os **seus** títulos de suporte e de tanque, com nomes da lenda e da cultura local (seção 5.10).
7. Cada **título** é conquistado por quest com seu Mestre/ancião. A recompensa concede as cinco skills da árvore no nível 1; skills herdadas vêm junto em títulos de ramo. Skills de títulos de combinação também vêm na quest do ancião. Não existem quests separadas para aprender as skills dessa árvore.

### 3.1 Mapa dos títulos

| ID | Título | Estilo | Camada | Como se conquista | Mestre / ancião |
|---|---|---|---|---|---|
| `traveler` | **Viajante** | — | 0 | todos começam | — |
| `sabia_blade_machete` | **Facão Firme** | lâmina de base | 1 | quest do Campo de Treino | Mestra Brisa |
| `sabia_blade_aroeira` | **Tronco de Aroeira** | defesa e contragolpe | 2 — ramo A | Facão Firme + Postura de Ferro | Mestra Brisa |
| `sabia_blade_jaguar` | **Garra da Onça** | dano concentrado | 2 — ramo B | Facão Firme + Corte do Horizonte | Mestra Brisa |
| `sabia_arcane_firefly` | **Luz de Vaga-lume** | magia de base | 1 | quest do Campo de Treino | Mestre Orvalho |
| `sabia_arcane_crystal` | **Guarda do Cristal** | proteção do grupo | 2 — ramo A | Luz de Vaga-lume + Barreira Arcana | Mestre Orvalho |
| `sabia_arcane_boitata` | **Olho do Boitatá** | destruição à distância | 2 — ramo B | Luz de Vaga-lume + Queda Estelar | Mestre Orvalho |
| `sabia_bow_cerrado` | **Flecha do Cerrado** | arco de base | 1 | Tiro Rasante + Flecha Dupla + Arco Tenso | Mestre Taquari (novo) |
| `sabia_bow_brejo` | **Tocaia do Brejo** | emboscada e camuflagem | 2 — ramo A | Flecha do Cerrado + Pele de Barro | Mestre Taquari |
| `sabia_bow_gaviao` | **Gavião-Real** | tiro certeiro | 2 — ramo B | Flecha do Cerrado + Olho Parado | Mestre Taquari |
| `sabia_hybrid_ember` | **Brasa no Facão** | lâmina + magia | H | Facão Firme + Luz de Vaga-lume + quest do ancião | Seu Zé Ferreiro (ancião, novo) |
| `sabia_support_root` | **Raiz do Cerrado** | suporte | C (combinação) | Luz de Vaga-lume + Guarda do Cristal + Flecha do Cerrado + quest do ancião | Vó Aninha, a raizeira (anciã, nova) |
| `sabia_support_buriti` | **Seiva do Buriti** | cura | C — ramo A | Raiz do Cerrado + Chá de Folha Larga | Vó Aninha |
| `sabia_support_matinta` | **Assobio da Matinta** | debuff | C — ramo B | Raiz do Cerrado + Assobio Agourento | Vó Aninha |
| `sabia_tank_jabuti` | **Casco de Jabuti** | tanque | C (combinação) | Facão Firme + Tronco de Aroeira + Garra da Onça + quest do ancião | Velho Tião do Casco (ancião, novo) |
| `sabia_tank_anta` | **Couro de Anta** | guerreiro pesado | C — ramo A | Casco de Jabuti + Couro Grosso | Velho Tião |
| `sabia_tank_mapinguari` | **Fúria do Mapinguari** | berserker | C — ramo B | Casco de Jabuti + Fúria | Velho Tião |

Cores: combinação usa **roxo `#8e66c4`** com a borda da camada (§1.3).

### 3.2 As lendas dos anciãos (pistas das combinações)

Cada ancião conta uma história curta, em linguagem simples, e termina dizendo com clareza o que o jogador precisa ter. As falas do jogo usam estes textos.

**Seu Zé Ferreiro — Brasa no Facão**
> Quando eu era menino, a forja apagou no meio de um serviço. Sem fogo não tinha facão. Aí entrou pela janela um enxame de vaga-lumes e pousou no carvão. O carvão acendeu de novo, com uma luz que eu nunca tinha visto. O facão que saiu daquela brasa cortava e soltava faísca ao mesmo tempo.
> Só consegue usar um facão desses quem aprendeu as duas coisas: segurar a lâmina com firmeza e acender a luz dos vaga-lumes.

Pistas: **Facão Firme** e **Luz de Vaga-lume**.

**Vó Aninha, a raizeira — Raiz do Cerrado**
> Todo ano o fogo passa pelo cerrado e deixa tudo preto. Quem olha acha que nada vai voltar. Mas, debaixo da terra, as raízes guardaram água. Na primeira chuva, tudo brota de novo. Eu aprendi a cuidar das pessoas do jeito que essas raízes cuidam do cerrado.
> Para aprender comigo, você precisa saber três coisas: acender uma luz no escuro, proteger os amigos com um escudo de cristal e acertar de longe com o arco.

Pistas: **Luz de Vaga-lume**, **Guarda do Cristal** e **Flecha do Cerrado**.

**Velho Tião do Casco — Casco de Jabuti**
> Conhece a história da festa no céu? Todos os bichos foram convidados, mas o jabuti não sabia voar. Ele se escondeu dentro da viola do urubu e subiu junto. Na volta, o urubu descobriu e jogou o jabuti lá de cima. O casco quebrou em mil pedaços. Os amigos juntaram pedaço por pedaço, e o casco ficou todo marcado, mas mais duro do que antes.
> Até hoje é assim: quem cai e levanta fica forte como o jabuti. Eu só ensino quem já provou três coisas: segurar o facão sem tremer, aguentar golpes como a aroeira e atacar certeiro como a onça.

Pistas: **Facão Firme**, **Tronco de Aroeira** e **Garra da Onça**.

**Como o ancião responde:**
- Sem os títulos: conta a lenda e fecha com *"Volte quando tiver aprendido essas três coisas."* (ou "duas", no caso do ferreiro).
- Com os títulos: conta a lenda e oferece a quest.

### 3.3 Quests de combinação (difíceis)

Todo "chefe" destas quests é um **chefe fixo de covil** (GDD §10.6.1). Os três do Sabiá moram na **Subida Vermelha**,
o primeiro setor da Chapada: Tatu-Montanha, Rainha-Lume do Brejo e Ventania do Gorro Vermelho. À noite cada um vira a
sua forma atroz.

| Quest | Ancião | Passos | Recompensa |
|---|---|---|---|
| **Aço que Canta** | Seu Zé Ferreiro | (1) coletar 2 **Brasas Eternas** (raro de Vaga-lume Encantado raro ou chefe); (2) derrotar o **chefe** Vaga-lume Encantado (a Rainha-Lume do Brejo, no covil da Subida Vermelha); (3) derrotar um chefe em **forma atroz**; (4) provação: derrubar o fantoche de dois escudos (físico e mágico) | título Brasa no Facão + skill Lâmina Faiscante |
| **A Raiz Debaixo do Fogo** | Vó Aninha | (1) coletar 3 **Raízes de Pequi** (raro de Redemoinho Travesso raro ou chefe); (2) derrotar um **chefe** sem que ninguém do grupo caia (sozinho vale); (3) derrotar um chefe em **forma atroz**; (4) provação: **proteger 3 mudas de pequizeiro por 60 s** contra ondas de redemoinhos (os monstros atacam as mudas; cura, escudo e Sombra de Pequizeiro valem nelas; basta 1 de pé no fim; se as 3 caírem, fala de novo com a Vó e tenta outra vez) | título Raiz do Cerrado + skill Garrafada |
| **O Casco da Festa no Céu** | Velho Tião do Casco | (1) coletar 3 **Cacos de Casco Antigo** (raro de Tatu-Pedra raro ou chefe); (2) derrotar **2 chefes** de espécies diferentes (os covis da Subida Vermelha têm 3); (3) derrotar o Tatu-Pedra em **forma atroz**; (4) provação: **sobreviver 45 s contra 6 tatus** ao mesmo tempo, sem cair | título Casco de Jabuti + skill Batida no Casco |

Itens raros novos: `eternal_ember`, `pequi_root`, `ancient_shell_shard` (drop só de monstro raro ou de chefe, com chance maior na forma atroz).

### 3.4 Árvores (5 skills por título)

Legenda: **Tipo** (alvo), **Mana**, **Recarga (s)**, **Efeito no nível 1** e **Pré-requisito** na árvore. O número por nível segue o padrão atual (+8–12% do multiplicador por nível, ou +duração). Skills marcadas com ★ já existem.

#### Facão Firme (Mestra Brisa)
| # | Skill (id) | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | ★ Golpe Firme (`blade_firm_strike`) | alvo | 6 | 4 | 150% ATK | — |
| 2 | ★ Investida (`blade_charge`) | alvo, avanço | 12 | 10 | avança e atordoa | Golpe Firme 3 |
| 3 | ★ Giro de Aço (`blade_steel_spin`) | área em volta | 14 | 8 | giro 3 cél. | Golpe Firme 3 |
| 4 | ★ Roçada (`blade_clearing_sweep`) | cone 90° | 12 | 9 | cone que empurra | Giro de Aço 3 |
| 5 | Amolar o Facão (`blade_sharpen`) | si mesmo | 10 | 30 | +20% ATK e +10% crítico por 12 s | Investida 3 |

#### Tronco de Aroeira (Mestra Brisa)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | ★ Postura de Ferro (`blade_iron_stance`) | si mesmo | — | — | +DEF por 10 s | (porta do ramo) |
| 2 | Resposta da Aroeira (`blade_aroeira_reply`) | si mesmo | 20 | 18 | por 1,5 s anula o próximo golpe corpo a corpo e devolve 200% ATK | Postura 3 |
| 3 | Raiz Presa (`blade_root_grip`) | área em volta (2,5) | 16 | 14 | prende os inimigos por 2 s | Postura 3 |
| 4 | Casca Grossa (`blade_thick_bark`) | si mesmo | 14 | 20 | −30% de dano recebido por 6 s | Resposta 3 |
| 5 | Chamado do Tronco (`blade_trunk_call`) | área em volta (4) | 12 | 16 | provoca: monstros atacam você por 4 s | Raiz Presa 3 |

#### Garra da Onça (Mestra Brisa)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | ★ Corte do Horizonte (`blade_horizon_cut`) | linha | — | — | 320% em linha | (porta do ramo) |
| 2 | Bote da Onça (`blade_jaguar_leap`) | alvo (6), salto | 24 | 14 | salta e causa 160% ATK, +30% de crítico | Corte 3 |
| 3 | Unhada (`blade_claw_rake`) | alvo | 14 | 7 | 3 golpes de 70% ATK | Bote 1 |
| 4 | Faro de Sangue (`blade_blood_scent`) | si mesmo | 12 | 25 | +25% de crítico por 8 s | Unhada 3 |
| 5 | Rugido da Onça (`blade_jaguar_roar`) | cone 90°, 3 cél. | 16 | 18 | −20% ATK nos inimigos por 6 s | Bote 3 |

#### Luz de Vaga-lume (Mestre Orvalho)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | ★ Faísca (`arcane_spark`) | alvo | — | — | projétil mágico | — |
| 2 | ★ Rajada Gélida (`arcane_frost_burst`) | cone | — | — | dano + lentidão | Faísca 3 |
| 3 | ★ Chama Rastejante (`arcane_creeping_flame`) | área no chão | — | — | queimadura no chão | Faísca 3 |
| 4 | ★ Fogo-Fátuo (`arcane_will_o_wisp`) | alvo | — | — | chama que persegue | Chama 3 |
| 5 | Enxame de Vaga-lumes (`arcane_firefly_swarm`) | alvo | 20 | 10 | 4 luzes de 40% MATK | Fogo-Fátuo 3 |

#### Guarda do Cristal (Mestre Orvalho)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | ★ Barreira Arcana (`arcane_barrier`) | aliado | — | — | escudo | (porta) |
| 2 | Cristal Repartido (`arcane_shared_crystal`) | área em volta (6) | 34 | 30 | até 3 aliados: escudo `30 + MATK×0,8` por 6 s | Barreira 3 |
| 3 | Prisão de Cristal (`arcane_crystal_prison`) | alvo | 22 | 16 | atordoa 2,5 s | Barreira 3 |
| 4 | Muralha de Cristal (`arcane_crystal_wall`) | área em volta (3) | 26 | 24 | aliados −25% de dano por 6 s | Repartido 3 |
| 5 | Brilho do Cristal (`arcane_crystal_glow`) | área em volta (6) | 10 | 40 | aliados recuperam 15% de MP em 8 s | Prisão 3 |

#### Olho do Boitatá (Mestre Orvalho)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | ★ Queda Estelar (`arcane_star_fall`) | área no chão | — | — | estrela cai | (porta) |
| 2 | Passo Estelar (`arcane_star_step`) | célula (5) | 24 | 16 | teleporta para a célula | Queda 3 |
| 3 | Olhar de Fogo (`arcane_fire_gaze`) | linha (12) | 28 | 12 | raio de 200% MATK | Queda 3 |
| 4 | Serpente de Fogo (`arcane_fire_serpent`) | linha no chão | 30 | 18 | rastro que queima por 5 s | Olhar 3 |
| 5 | Olhos em Brasa (`arcane_ember_eyes`) | si mesmo | 16 | 30 | +25% MATK por 10 s | Passo 3 |

#### Flecha do Cerrado (Mestre Taquari) — precisa de arco
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Tiro Rasante (`bow_low_shot`) | alvo (10) | 6 | 4 | 130% ATK | — |
| 2 | Flecha Dupla (`bow_double_arrow`) | alvo (10) | 12 | 8 | 2 × 75% ATK | Tiro 3 |
| 3 | Arco Tenso (`bow_taut_draw`) | alvo (12), conjura 1 s | 16 | 10 | 250% ATK | Tiro 3 |
| 4 | Flecha de Aviso (`bow_warning_arrow`) | alvo (10) | 14 | 16 | marca: o alvo recebe +10% de dano de todos por 6 s | Dupla 3 |
| 5 | Revoada de Flechas (`bow_arrow_flock`) | área no chão (3) | 24 | 16 | 120% ATK na área | Tenso 3 |

#### Tocaia do Brejo (Mestre Taquari)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Pele de Barro (`bow_mud_skin`) | si mesmo | 12 | 20 | +30% de esquiva por 8 s | (porta do ramo) |
| 2 | Lama no Corpo (`bow_mud_hide`) | si mesmo | 18 | 25 | invisível para monstros até atacar ou 10 s | Pele 3 |
| 3 | Tocaia (`bow_ambush_shot`) | alvo (10) | 20 | 14 | 200% ATK (+100% se invisível) e prende 1,5 s | Lama 1 |
| 4 | Armadilha de Cipó (`bow_vine_snare`) | área no chão (2) | 16 | 18 | prende 2,5 s | Pele 3 |
| 5 | Flecha de Espinho (`bow_thorn_arrow`) | alvo (10) | 14 | 12 | veneno de 6 s (60% ATK por s) | Tocaia 3 |

#### Gavião-Real (Mestre Taquari)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Olho Parado (`bow_still_eye`) | si mesmo | 12 | 25 | +20% de crítico e +2 cél. de alcance por 10 s | (porta do ramo) |
| 2 | Flecha Sem Desvio (`bow_true_arrow`) | alvo (14) | 20 | 10 | 180% ATK ignorando 40% da DEF | Olho 3 |
| 3 | Mira Certeira (`bow_sure_aim`) | si mesmo | 16 | 30 | os próximos 3 ataques são críticos | Olho 3 |
| 4 | Mergulho do Gavião (`bow_hawk_dive`) | alvo (12) | 22 | 16 | flecha do alto: 180% ATK e atordoa 1 s | Sem Desvio 3 |
| 5 | Voo Curto (`bow_short_flight`) | si mesmo | 14 | 14 | salta 4 cél. para trás | Mira 1 |

#### Brasa no Facão (Seu Zé Ferreiro)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Lâmina Faiscante (`hybrid_spark_blade`) | si mesmo | 22 | 30 | por 8 s, ataque básico +20% MATK mágico | (quest do ancião) |
| 2 | Corte em Brasa (`hybrid_ember_cut`) | alvo | 18 | 8 | 150% ATK + queimadura 4 s | Lâmina 1 |
| 3 | Faísca no Aço (`hybrid_steel_spark`) | alvo (6), avanço | 20 | 12 | avança; 120% MATK | Lâmina 3 |
| 4 | Fagulhas (`hybrid_sparks`) | área em volta (3) | 22 | 12 | 140% MATK | Corte 3 |
| 5 | Coração de Brasa (`hybrid_ember_heart`) | si mesmo | 18 | 35 | +10% ATK e MATK por 12 s | Faísca 3 |

#### Raiz do Cerrado — suporte (Vó Aninha)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Garrafada (`support_bottle_brew`) | área em volta (4) | 26 | 20 | cura contínua `8 + MATK×0,2` por s, 10 s | (quest da anciã) |
| 2 | Chá de Erva (`support_herb_tea`) | aliado (8) | 18 | 6 | cura `40 + MATK×1,6` | Garrafada 1 |
| 3 | Emplastro (`support_poultice`) | aliado (8) | 14 | 12 | remove efeitos negativos e cura `20 + MATK×0,6` | Chá 3 |
| 4 | Sombra de Pequizeiro (`support_pequi_shade`) | aliado (8) | 16 | 18 | −20% de dano recebido por 6 s | Chá 3 |
| 5 | Mutirão (`support_mutirao`) | área em volta (6) | 30 | 45 | grupo +10% ATK e MATK por 15 s | Emplastro 3 |

#### Seiva do Buriti — cura (Vó Aninha)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Chá de Folha Larga (`support_broadleaf_tea`) | aliado (8) | 30 | 10 | cura grande `80 + MATK×2,4` e remove veneno | (porta do ramo) |
| 2 | Água de Coco (`support_coconut_water`) | área em volta (6) | 34 | 18 | cura o grupo `40 + MATK×1,0` | Folha Larga 3 |
| 3 | Seiva que Corre (`support_running_sap`) | aliado (8) | 20 | 12 | cura contínua forte por 12 s | Folha Larga 3 |
| 4 | Raiz que Segura (`support_holding_root`) | aliado (8) | 28 | 60 | o aliado não cai abaixo de 1 de vida por 3 s | Água de Coco 3 |
| 5 | Fôlego Novo (`support_new_breath`) | aliado (8) | 10 | 40 | devolve 20% do MP máximo | Seiva 3 |

#### Assobio da Matinta — debuff (Vó Aninha)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Assobio Agourento (`support_ill_whistle`) | cone 90°, 4 cél. | 18 | 14 | −20% DEF nos inimigos por 8 s | (porta do ramo) |
| 2 | Agouro (`support_omen`) | alvo (10) | 16 | 12 | −25% ATK e −15% MATK por 10 s | Assobio 3 |
| 3 | Pio da Rasga-Mortalha (`support_owl_cry`) | área no chão (3) | 22 | 16 | lentidão de 40% por 5 s | Assobio 3 |
| 4 | Visgo (`support_bird_lime`) | alvo (10) | 16 | 14 | prende 3 s | Agouro 3 |
| 5 | Fumaça Amarga (`support_bitter_smoke`) | área no chão (3) | 24 | 18 | dano contínuo `MATK×0,3` por s e −50% de cura recebida, 6 s | Pio 3 |

#### Casco de Jabuti — tanque (Velho Tião do Casco)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Batida no Casco (`tank_shell_knock`) | área em volta (4) | 14 | 12 | provoca por 5 s | (quest do ancião) |
| 2 | Recolher no Casco (`tank_shell_retreat`) | si mesmo | 16 | 20 | −50% de dano recebido e −50% de velocidade por 4 s | Batida 1 |
| 3 | Casco Duro (`tank_hard_shell`) | si mesmo | 14 | 25 | +30% DEF por 12 s | Batida 3 |
| 4 | Paciência de Jabuti (`tank_patience`) | si mesmo | 18 | 30 | recupera 3% da vida por s por 8 s | Recolher 3 |
| 5 | Empurrão de Casco (`tank_shell_bash`) | cone 90°, 2 cél. | 16 | 12 | empurra 2 cél. e atordoa 1 s | Casco Duro 3 |

#### Couro de Anta — guerreiro pesado (Velho Tião)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Couro Grosso (`tank_thick_hide`) | si mesmo | 16 | 30 | +40% DEF por 15 s | (porta do ramo) |
| 2 | Pisada de Anta (`tank_tapir_stomp`) | área em volta (2,5) | 18 | 14 | atordoa 1,5 s | Couro 3 |
| 3 | Trombada (`tank_tapir_ram`) | alvo (6), avanço | 18 | 14 | avança, 130% ATK e empurra 3 cél. | Pisada 1 |
| 4 | Muralha Viva (`tank_living_wall`) | área em volta (3) | 24 | 30 | aliados −20% de dano por 8 s | Couro 3 |
| 5 | Aguentar Firme (`tank_stand_firm`) | si mesmo | 20 | 40 | imune a atordoar, prender e empurrar por 6 s | Muralha 3 |

#### Fúria do Mapinguari — berserker (Velho Tião)
| # | Skill | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Fúria (`tank_fury`) | si mesmo | 10 | 30 | +40% ATK e −30% DEF por 10 s | (porta do ramo) |
| 2 | Urro do Mapinguari (`tank_mapinguari_howl`) | área em volta (4) | 16 | 18 | −25% DEF nos inimigos por 8 s | Fúria 3 |
| 3 | Garras Pesadas (`tank_heavy_claws`) | cone 90°, 2 cél. | 18 | 9 | 2 × 120% ATK | Fúria 1 |
| 4 | Sede de Luta (`tank_battle_thirst`) | si mesmo | 14 | 30 | 20% do dano causado volta como vida, por 10 s | Garras 3 |
| 5 | Última Pancada (`tank_last_blow`) | alvo | 20 | 20 | 150% ATK, +até 150% conforme a vida que falta | Urro 3 |

**Totais:** 16 títulos na Terra do Sabiá, 12 skills existentes e **68 skills novas**.

### 3.5 Mecânicas novas que as árvores pedem (servidor)

| Mecânica | Onde aparece |
|---|---|
| Cura instantânea e cura contínua (alvo e área) | suporte, Paciência de Jabuti |
| Reforço genérico de atributos (ATK, MATK, DEF, crítico, esquiva, alcance, dano recebido, roubo de vida) | vários |
| Debuff genérico nos inimigos (ATK, MATK, DEF, dano recebido, cura recebida) | Rugido, Flecha de Aviso, Matinta, Urro |
| Chefes fixos nos covis da Chapada, ciclo de dia e noite, forma atroz do chefe à noite | quests dos anciãos |
| Provocar (monstros trocam de alvo) | Chamado do Tronco, Batida no Casco |
| Prender (sem mover) e atordoar genérico | Raiz Presa, Prisão de Cristal, Visgo, Pisada |
| Vários golpes, empurrar, puxar, recuo | Unhada, Roçada, Trombada, Voo Curto |
| Contragolpe | Resposta da Aroeira |
| Invisível para monstros | Lama no Corpo |
| Teleporte para célula | Passo Estelar |
| Remover efeitos negativos | Emplastro, Chá de Folha Larga |
| Não cair abaixo de 1 de vida | Raiz que Segura |
| Imunidade a controle | Aguentar Firme |
| Devolver MP | Brilho do Cristal, Fôlego Novo |
| Ataque básico à distância com **arco** (arma nova) | Flecha do Cerrado |
| Ofício (fabricar item com materiais, fora de combate) e Surrupiar (tirar item de monstro vivo) | ofícios dos títulos (§3.6) |

### 3.6 Ofícios dos títulos `[06/10/2026]`

Skills de ofício (`TitleDef.bonus_skills`), fora da árvore de 5, inspiradas nos ofícios do Ragnarok. Vêm com o título; os ramos herdam as da base (Aroeira e Onça ficam com o Curativo; Cristal e Boitatá com Engarrafar Luz; Tocaia e Gavião com Fazer Flechas; Buriti e Matinta com a Garrafada; Anta e Mapinguari com o Unguento). Títulos de combinação não herdam dos títulos exigidos. Ofício de fabricar não funciona em combate; a fração por nível arredonda para baixo.

| Título | Ofício (`id`) | Receita | Quantidade (nv 1 / 3 / 10) |
|---|---|---|---|
| Flecha do Cerrado | Fazer Flechas (`bow_fletching`) | 1 Vara de Taquara → Flechas Simples | 10 / 14 / 28 (+2 por nível) |
| Facão Firme | Curativo de Mateiro (`blade_field_dressing`) | 3 Folhas Rodopiantes → Poções de Vida Pequenas | 2 / 3 / 6 (+1 a cada 2 níveis) |
| Luz de Vaga-lume | Engarrafar Luz (`arcane_bottle_light`) | 3 Luzes de Vaga-lume → Poções de Mana Pequenas | 2 / 3 / 6 |
| Tocaia do Brejo | Envenenar Pontas (`bow_poison_tips`) | 10 Flechas Simples + 1 Bolsa de Peçonha → Flechas Envenenadas | 10 / 11 / 14 |
| Gavião-Real | Emplumar (`bow_feathering`) | 10 Flechas Simples + 1 Pena de Harpia → Flechas de Ferro | 10 / 11 / 14 |
| Brasa no Facão | Forjar Pontas de Brasa (`hybrid_ember_tips`) | 10 Flechas Simples + 1 Brasa Eterna → Flechas de Fogo | 10 / 11 / 14 |
| Raiz do Cerrado | Garrafada (`support_garrafada`) | 1 Raiz de Pequi + 1 Favo Selvagem → Poções de Vida Médias | 2 / 3 / 6 |
| Casco de Jabuti | Unguento de Casco (`tank_shell_salve`) | 2 Cascos de Tatu-Pedra + 1 Couro Grosso → Unguento de Casco | 1 / 1 / 4 (+1 a cada 3 níveis) |
| Garra da Onça | Surrupiar (`blade_pilfer`) | — (ver abaixo) | — |

**Unguento de Casco** (`shell_salve`, item novo): consumível, +20% de DEF por 90 s (o mesmo reforço de defesa das skills), 1 s de uso e 90 s de recarga própria; não se compra, vende por 30.

**Surrupiar** (efeito `STEAL`, o Steal do gatuno): alvo único, monstro vivo a até 1,5 célula, só onde há combate (é ofensivo e o monstro reage). Chance = 20% + 5% por nível + (DES + SOR) × 0,3%, até 95%. Se acertar, rola uma vez a tabela de drop do estágio atual do monstro (peso = chance de cada linha) e põe 1 unidade direto na mochila; conta para a coleta de quest como item pego. Um sucesso por monstro (falhar pode tentar de novo). Recusa chefe, forma atroz e monstro de provação.

**Fontes:** Bolsa de Peçonha e Favo Selvagem ainda não caem de monstro posicionado em mapa nem são vendidos (as cobras/aranhas/abelhas que soltam não estão em nenhum mapa). Pena de Harpia vem do Gavião da Mata (Selva de Ratanabá · Igarapé dos Glifos); Brasa Eterna e Raiz de Pequi só do chefe (estágio 3+) do Vaga-lume Encantado e do Redemoinho Arteiro.

---

## 4. Pós-MVP — Terra do Sabiá (outros caminhos)

O arco, o suporte (antigo caminho das Ervas) e o tanque entraram na §3 em 30/09/2026.

**Cuidados da região** (`data/regions/brasil.md`):
- A cura vem do saber popular das ervas e das garrafadas. Nada de benzimento, pajé ou práticas religiosas vivas.
- A **Iara** aparece só como ser das águas do folclore, sem nenhuma mistura com orixás.
- **Saci**, **Curupira** e **Caipora** ensinam e nunca são mortos.
- Armas indígenas aparecem sem grafismos de povos específicos.

### 4.2 Outros caminhos da Terra do Sabiá

| Caminho (arquétipo) | Primeiro título | Ramo A | Ramo B | Ápice |
|---|---|---|---|---|
| **Redemoinho** (furtividade e truques, inspirado no Saci) | **Rastro do Saci** — **Sumiço**: invisível por 4 s | **Pé-de-Vento** (truques e controle) — **Nó na Crina**: prende o alvo por 2 s | **Dente de Jararaca** (emboscada venenosa) — **Bote Venenoso**: veneno de 6 s que reduz a cura recebida | **Gorro Vermelho** |
| **Mata** (utilidade e exploração; quest com o Curupira) | **Amigo do Curupira** — **Rastro Invertido**: os monstros perdem o rastro do grupo por 5 s | **Pegada Trocada** (fuga e evasão) — **Trilha Ligeira**: +20% de velocidade fora de combate para o grupo | **Faro da Caipora** (rastreio) — **Faro**: mostra no mapa monstros e itens de quest por perto | — |
| **Águas** (controle, inspirado na Iara) | **Canto do Rio** — **Canto das Águas**: puxa um monstro 3 células | **Espelho do Igarapé** (defesa) — **Espelho d'Água**: devolve o próximo projétil | **Força da Pororoca** (empurrão) — **Correnteza**: empurra todos em linha | — |

**Híbridos da região (exemplos):**

| Título | Exige | Exclusiva (efeito) |
|---|---|---|
| **Onça em Brasa** | Garra da Onça + Luz de Vaga-lume | **Fio de Brasa** — o Bote da Onça deixa um rastro de fogo |
| **Seiva e Aço** | Facão Firme + Folha que Cura | **Golpe que Cura** — 30% do dano do próximo golpe cura os aliados em volta |
| **Brejo Sem Rastro** | Tocaia do Brejo + Rastro do Saci | **Trilha Perdida** — o grupo fica invisível para monstros enquanto anda devagar, por 6 s |

---

## 5. Pós-MVP — outras regiões (GDD §4.0)

Os nomes usam termos que o público **já conhece** daquela cultura ou nomes descritivos em português ligados ao folclore local. O mesmo arquétipo tem skills diferentes em cada nação. Formato: primeiro título → ramo A / ramo B, com a exclusiva principal de cada um.

### 5.1 Ilhas do Sol Nascente (Japão)

**Cuidados:**
- Divindades xintoístas não viram NPCs nem fonte de poder.
- A kitsune é só a raposa trapaceira do folclore.
- Nada de papéis ou rituais de religiões vivas.
- O Yamata no Orochi é só um monstro.
- Usar **Shinobi**, nunca "Ninja".

| Arquétipo | Primeiro título | Ramo A | Ramo B |
|---|---|---|---|
| Katana | **Samurai** — **Saque Rápido**: +50% de dano no primeiro golpe depois de sacar a espada | **Rōnin** (mobilidade) — **Passo Errante**: avança 3 células e golpeia duas vezes | **Guarda do Estandarte** (defesa) — **Estandarte Firme**: aliados por perto ganham +20% de DEF |
| Furtividade | **Shinobi** — **Fumaça de Bambu**: esconde o grupo por 3 s | **Sombra no Capim** (emboscada) — **Deitar no Capim**: invisível e parado; o primeiro golpe prende o alvo | **Raposa Trapaceira** (truques) — **Pista Falsa**: uma cópia que atrai os monstros |
| Naginata | **Lua da Naginata** — **Arco de Lua**: varrida de 180° | **Guarda da Ponte** (controle) — **Ninguém Passa**: bloqueia o avanço dos inimigos | **Vento da Montanha** (dano) — **Corte de Vento Alto**: salta até o alvo |
| Cura (inspirada no kappa que ensina a curar ossos) | **Remédio do Kappa** — **Tala de Bambu**: cura e remove lentidão | **Água do Prato** (cura em área) — **Emplastro do Rio** | **Osso no Lugar** (resistência) — **Tala Firme**: aliado imune a atordoamento por 4 s |

### 5.2 Reino das Mouras (Portugal)

**Cuidados:** as mouras encantadas são personagens de lenda (guardiãs que fiam ouro), não retratos de povos. A Coca aparece só como dragão, sem a procissão religiosa. O Adamastor vem de Camões, em domínio público.

| Arquétipo | Primeiro título | Ramo A | Ramo B |
|---|---|---|---|
| Alabarda | **Alabarda da Muralha** — **Varrida de Haste**: arco com 3 un. de alcance | **Muralha de Hastes** (defesa) — **Ninguém Entra**: bloqueia uma fileira de células | **Gancho da Alabarda** (controle) — **Puxão**: traz um alvo 2 células para perto |
| Besta | **Virote do Castelo** — **Virote Pesado**: empurra 1 célula | **Atalaia da Torre** (alcance) — **Olhar do Alto**: +3 un. de alcance para o grupo | **Tiro Travado** (dano) — **Garrucha**: tiro lento que causa 250% de dano |
| Apoio mágico | **Fio de Moura** — **Fio de Ouro**: divide com um aliado o dano que ele recebe | **Véu Encantado** (ilusão) — **Véu da Fonte**: esconde um aliado | **Tesouro da Moura** (proteção) — **Selo de Ouro**: aliado imune a dano por 1,5 s |
| Navegação (utilidade) | **Rosa-dos-Ventos** — **Rumo Certo**: +15% de velocidade para o grupo | **Carta de Marear** (exploração) — revela os pontos do mapa | **Cabo das Tormentas** (ápice, depois do Adamastor) — **Muralha de Tormenta**: bloqueia projéteis |

### 5.3 Fiordes de Gelo (Noruega/Islândia)

**Cuidados:** a religião nórdica tem praticantes hoje, por isso nenhum deus nórdico entra como fonte de poder. Também não usar **runas reais**, que sofrem apropriação extremista; criar glifos originais.

| Arquétipo | Primeiro título | Ramo A | Ramo B |
|---|---|---|---|
| Machado e escudo | **Escudo do Fiorde** — **Parede de Escudos**: +25% de DEF para aliados colados | **Quebra-Gelo** (defesa) — **Escudo Erguido**: bloqueia projéteis frontais | **Machado Andante** (dano) — **Machadada Arremessada**: machado que volta |
| Furtividade | **Proscrito do Gelo** (os fora da lei das sagas) — **Viver no Ermo**: invisível parado na neve | **Sombra na Neve** (emboscada) — **Emboscada Gelada** | **Quebra-Trolls** (anti-monstro) — **Luz da Aurora**: dano extra contra mortos-vivos e trolls |
| Apoio | **Voz da Saga** (poeta de corte, o "skald") — **Verso de Coragem**: +10% de ATK para o grupo | **Saga Antiga** (reforço longo) — remove o medo | **Mão de Lã** (cura) — **Atadura de Lã**: cura contínua |

### 5.4 Costa das Colunas (Grécia antiga)

**Cuidados:** os deuses do Olimpo não entram como inimigos nem como fonte direta de poder.

| Arquétipo | Primeiro título | Ramo A | Ramo B |
|---|---|---|---|
| Lança e escudo | **Hoplita** — **Muralha de Lanças**: bloqueio frontal com contragolpe | **Escudo de Bronze** (defesa) — **Ordem Cerrada**: aliados em linha ganham DEF | **Linha de Frente** (avanço) — **Avanço de Escudo** |
| Distância | **Dardo da Costa** — **Dardo Longo** | **Pé Ligeiro** (escaramuça) — **Dardo e Recuo** | **Funda de Pedra** (controle) — **Pedra Certeira**: atordoa |
| Cura | **Bálsamo de Mel** — cura contínua | **Raiz Amarga** (limpeza) — remove venenos | **Vinho e Tala** (cura grande) — cura forte e lenta |
| Exploração | **Fio do Labirinto** — **Novelo de Retorno**: marca uma célula e volta a ela em até 60 s | **Olho do Vigia** (visão) — **Mapa Mental** | **Escudo Espelhado** (antimagia, lembra a Medusa) — **Reflexo de Bronze**: devolve a próxima magia |

### 5.5 Areias do Nilo (Egito antigo)

**Cuidados:** Apep aparece só como criatura. Nenhum deus entra como fonte de poder. A cura vem dos registros médicos antigos (mel e linho), e múmias não viram piada.

| Arquétipo | Primeiro título | Ramo A | Ramo B |
|---|---|---|---|
| Khopesh | **Gancho do Deserto** — **Corte em Gancho** | **Guarda do Portão** (controle) — **Gancho Desarmador**: desarma por 2 s | **Carro de Guerra** (investida) — **Investida de Areia** |
| Mente | **Escriba** — **Pergunta sem Resposta**: o alvo não usa skills por 3 s | **Enigma da Esfinge** (confusão) — **Enigma**: o alvo ataca a esmo | **Leitor de Estrelas** (alcance) — **Mapa do Céu**: aumenta o alcance mágico |
| Cura | **Mel e Linho** — **Atadura de Linho**: cura contínua e escudo leve | **Mel na Ferida** (cura forte) | **Sombra Fresca** (proteção) — área que reduz dano de fogo |
| Furtividade | **Sombra de Duna** — **Enterrar-se na Areia**: invisível parado | **Miragem** (ilusão) — cria uma cópia | **Picada de Escorpião** (emboscada) — veneno |

### 5.6 Brumas Verdes (Irlanda/Escócia)

**Cuidados:** a harpa é mágica, mas genérica (não é a harpa de nenhuma divindade). O Balor é um gigante de lenda.

| Arquétipo | Primeiro título | Ramo A | Ramo B |
|---|---|---|---|
| Espada longa | **Espada das Brumas** — **Corte Largo** | **Machado das Ilhas** (dano pesado) — **Golpe de Duas Mãos** | **Golpe do Nevoeiro** (controle) — cega o alvo |
| Música e apoio | **Harpa das Brumas** — **Canção de Três Tons**: pranto que cura, riso que dá força, sono para os inimigos | **Contador de Histórias** (reforço longo) — **Conto Longo** | **Lamento da Banshee** (aviso) — **Lamento Prévio**: mostra os ataques de área 1 s antes |
| Mobilidade | **Pele de Selkie** — **Mergulho de Selkie**: avança 6 células e remove efeitos negativos | — | — |

### 5.7 Estepe de Ferro (povos eslavos)

**Cuidados:** a fé nativa eslava tem praticantes hoje, então nenhum deus eslavo entra. Baba Yaga, Koschei, o pássaro de fogo e a água viva e morta vêm de contos populares.

| Arquétipo | Primeiro título | Ramo A | Ramo B |
|---|---|---|---|
| Machado | **Herói da Estepe** — **Golpe de Herói** | **Escudo da Estepe** (defesa) — **Muro de Escudos** | **Agulha de Koschei** (sobrevivência) — **Vida Escondida**: sobrevive a um golpe fatal a cada 5 min |
| Arco | **Pena de Fogo** — **Flecha de Pena Ardente**: atravessa e queima | **Tiro a Galope** (mobilidade) | **Olho da Estepe** (alcance) — **Tiro Longo** |
| Cura | **Água Viva** — **Duas Águas**: fecha a ferida e depois cura | **Água Morta** (limpeza) — remove sangramento e veneno | **Pilão da Baba Yaga** (utilidade) — **Voo no Pilão**: voa 6 células |

### 5.8 Império de Jade (China)

**Cuidados:** nada de sacerdotes taoístas ou de imagens budistas como mecânica. Guan Yu não aparece. O Nian é vencido com vermelho e barulho, como no conto popular.

| Arquétipo | Primeiro título | Ramo A | Ramo B |
|---|---|---|---|
| Jian | **Espada de Jade** — **Ponto Exato**: ignora 50% da DEF | **Passo de Garça** (mobilidade) — **Passo Leve** | **Escolta de Caravana** (proteção) — **Escolta**: aliado recebe −20% de dano |
| Fogos | **Fogos contra o Nian** — **Estouro Vermelho**: os monstros fogem por 2 s | **Tambor de Ano-Novo** (controle) — **Rufar**: atordoa em área | **Lanterna Vermelha** (anti-morto-vivo) — **Luz que Espanta** |
| Cura | **Agulha Fina** — cura contínua | **Ervas da Montanha** (cura forte) | **Fôlego Contido** (furtividade) — **Prender o Fôlego**: mortos-vivos não te enxergam |

### 5.9 Selvas de Obsidiana (México antigo)

**Cuidados:** os **aluxes** fazem parte de crenças maias atuais, então aparecem como NPCs respeitados, nunca como inimigos. Nada de deuses astecas nem de sacrifício.

| Arquétipo | Primeiro título | Ramo A | Ramo B |
|---|---|---|---|
| Macuahuitl | **Lâmina de Obsidiana** — **Corte Vidrado**: sangramento por 6 s | **Pele de Jaguar** (fúria) — **Forma de Jaguar**: +30% de velocidade de movimento e de ataque por 10 s | **Mergulho de Águia** (salto) — ataque vindo do alto |
| Cura | **Mel de Melipona** — **Favo Curativo**: área de cura no chão | **Cacau Morno** (reforço) — aumenta ESP | **Folha da Selva** (limpeza) — remove venenos |

---

### 5.10 Suporte e tanque em cada nação (v0.4) `[PROVISÓRIO — revisão cultural antes de cada região]`

Mesma regra da Terra do Sabiá (§3.0): cada título é de **combinação de 3 títulos da nação**, contado por um **ancião** com uma lenda. O suporte abre **cura** e **debuff**. O tanque abre **guerreiro pesado** e **berserker**. As 5 skills de cada árvore são desenhadas quando a região entrar.

| Nação | Suporte → cura / debuff | Lenda do suporte | Tanque → pesado / berserker | Lenda do tanque |
|---|---|---|---|---|
| Ilhas do Sol Nascente (Japão) | **Remédio do Kappa** → **Água do Prato** / **Riso da Kitsune** | o kappa que, para ter o braço de volta, ensinou a arte de pôr ossos no lugar; a raposa que confunde viajantes | **Muro do Castelo** → **Armadura Laqueada** / **Fúria do Oni** | as muralhas de pedra que nenhum cerco derrubou; o oni das montanhas que arranca árvores |
| Reino das Mouras (Portugal) | **Botica da Vila** → **Água da Fonte** / **Feitiço da Moura** | a fonte onde a moura encantada deixava água que curava; o encanto que prende quem cobiça o ouro dela | **Muralha de Granito** → **Couraça de Ferro** / **Fúria do Adamastor** | o castelo de granito na fronteira; o gigante do cabo que ergue tormentas (Camões) |
| Fiordes de Gelo (Noruega/Islândia) | **Fogo da Casa Longa** → **Atadura de Lã** / **Frio do Draugr** | o fogo que nunca apagava no inverno; o morto-vivo das sagas que gela quem chega perto | **Parede de Escudos** → **Casco de Troll** / **Fúria do Urso** | a linha de escudos na praia; o troll que vira pedra e não sente golpe; os guerreiros de pele de urso das sagas |
| Costa das Colunas (Grécia antiga) | **Ânfora de Óleo** → **Bálsamo de Mel** / **Olhar da Górgona** | o óleo e o mel dos médicos antigos; o olhar que endurece quem o encara | **Falange** → **Couraça de Bronze** / **Fúria do Minotauro** | a fileira de lanças que avançava como um só; o touro do labirinto |
| Areias do Nilo (Egito antigo) | **Papiro dos Remédios** → **Mel na Ferida** / **Veneno de Escorpião** | os rolos de papiro com receitas de mel e linho; o escorpião do deserto | **Pedra da Pirâmide** → **Escama de Crocodilo** / **Fúria do Leão do Deserto** | os blocos que ninguém move; o crocodilo do rio; o leão das areias |
| Brumas Verdes (Irlanda/Escócia) | **Mel de Urze** → **Chá de Urze** / **Encanto do Kelpie** | o mel das charnecas que curava; o cavalo d'água que arrasta para o lago | **Muralha de Turfa** → **Escudo de Carvalho** / **Fúria do Campeão de Ulster** | os muros de turfa das ilhas; o herói das lendas que se transformava em fúria na batalha |
| Estepe de Ferro (povos eslavos) | **Água Viva** → **Duas Águas** / **Riso da Baba Yaga** | a água morta que fecha a ferida e a água viva que devolve a vida (contos populares); a velha da isbá de pés de galinha | **Muro de Carvalho** → **Força de Bogatyr** / **Fúria do Urso da Taiga** | a paliçada de carvalho; os heróis das canções épicas; o urso da floresta fria |
| Império de Jade (China) | **Agulha Fina** → **Ervas da Montanha** / **Sopro do Jiangshi** | as agulhas e ervas dos remédios antigos; o morto que pula e gela o fôlego | **Grande Muralha** → **Armadura de Terracota** / **Fúria do Nian** | a muralha que atravessa montanhas; os soldados de barro; a fera do Ano-Novo |
| Selvas de Obsidiana (México antigo) | **Mel de Melipona** → **Favo Curativo** / **Espinho de Maguey** | o mel da abelha sem ferrão; o espinho do agave | **Algodão Acolchoado** → **Escudo de Plumas** / **Fúria do Jaguar** | a armadura de algodão grosso dos guerreiros antigos; o jaguar da selva |

Cuidados (além dos de cada região em §5.1–5.9):
- **Nórdicos:** "berserker" é termo histórico conhecido, mas o título usa "Fúria do Urso" para não virar nome de classe de outro jogo.
- **Eslavos:** heróis como Ilya Muromets são também venerados como santos; por isso o título usa só o termo genérico *bogatyr*.
- **Egito:** o leão não representa nenhuma divindade leoa.
- **México:** nada de copal, nahualismo ou rituais vivos; o debuff usa só o espinho do agave.
- **Assobio da Matinta (Sabiá):** a Matinta Pereira entra como figura do folclore, na mesma regra do Saci e do Curupira; revisar com gente do Norte antes do lançamento.

---

## 6. Apêndice — modelo de dados e regras do servidor

### 6.1 `data/titles/<id>.tres` (`TitleDef`)

| Campo | Tipo | Exemplo (`sabia_blade_jaguar`) |
|---|---|---|
| `id` | StringName | `&"sabia_blade_jaguar"` |
| `name_key` / `name_key_f` | String | `"TITLE_SABIA_JAGUAR"` → "Garra da Onça" / vazio quando o nome é neutro |
| `desc_key` | String | descrição curta do estilo e da origem do nome |
| **`region_id`** | StringName | `&"sabia"` |
| `archetype` | StringName | `&"blade"` |
| `tier` | int | `2` (0 chegada, 1 primeiro, 2 ramo, 3 ápice) |
| **`parent_title`** | StringName | `&"sabia_blade_machete"` (vazio no primeiro título) |
| **`branch`** | StringName | `&"b"` (`&""` no primeiro título e no ápice) |
| `is_hybrid` | bool | `false` |
| `required_skills` | Array[StringName] | `[&"blade_horizon_cut"]` |
| `required_titles` | Array[StringName] | `[&"sabia_blade_machete"]` (inclui o `parent_title`) |
| `unlocks_quests` | Array[StringName] | `[&"quest_jaguar_leap"]` |
| `unlocks_flags` | Array[StringName] | diálogos e, no futuro, itens e cosméticos |
| `display_color` | Color | cor da camada (§1.3) |
| `sort_order` | int | ordem no painel |

- **Na quest** (`data/quests/<id>.tres`): `required_skills`, `required_skill_levels`, `required_titles` e `required_quests`. **Nenhum campo de nível de personagem.**
- **IDs das skills:** usar os de `data/skills/` se já existirem. Sugestão:
  - Lâmina: `blade_firm_strike`, `blade_charge`, `blade_steel_spin`, `blade_iron_stance`, `blade_horizon_cut`.
  - Arcano: `arcane_spark`, `arcane_frost_burst`, `arcane_creeping_flame`, `arcane_barrier`, `arcane_star_fall`.
  - Exclusivas: `blade_aroeira_reply`, `blade_jaguar_leap`, `arcane_shared_crystal`, `arcane_star_step`, `hybrid_spark_blade`. Cada uma tem o campo `exclusive_to_title`.

### 6.2 Regras que o servidor aplica

1. **Conquista:** a quest de título confere seus pré-requisitos, concede o título e entrega as cinco skills da árvore no nível 1. Títulos de ramo incluem as árvores ancestrais. `required_skills`/`required_titles` em `TitleDef` descrevem a árvore e suas pistas, não concedem títulos.
2. **Persistência e migração:** salvar `titles_earned` (id + data) e `displayed_title`. Ao carregar, `TitleService.recalc()` só completa skills das árvores de títulos já salvos; nunca concede título novo por skill.
3. **Aceitar quest:** conferir títulos, skills e níveis de skill, **nunca o nível do personagem**. Se faltar algo, devolver o que falta para a NPC mostrar. Quest com `required_titles` fica escondida sem o título (`show_locked = false`, o padrão das exclusivas).
4. **Concluir quest:** conferir os requisitos de novo; ao entregar quest com `reward_title`, conceder título e todas as skills da árvore.
5. **Exibir título:** `set_displayed_title(id)` só é aceito se o id estiver em `titles_earned`. O título vai no estado da entidade e respeita a visibilidade por instância (GDD §5.6).
6. **Evento `title_earned(id)`:** o cliente mostra o aviso e oferece "Exibir agora?".
7. **Números em dados, lógica isolada:** números em `data/skills/*.tres` (GDD §8.1) e lógica no módulo `TitleService`, separado de `SkillProgression`.

---

## 7. Questões em aberto para o dono

| # | Pergunta | Padrão recomendado |
|---|---|---|
| 1 | Os ramos se **excluem** (A **ou** B)? | **Não.** Pode fazer os dois (pilar da liberdade); o custo é tempo, pontos e espaço na barra. Se o dono quiser escolha definitiva, é só uma regra no `TitleService` |
| 2 | Aprovar o ajuste do §8.4 (L5/A5 sem exigir L4/A4) para os ramos serem independentes? | **Sim** (§3.2) |
| 3 | O arco (Flecha do Cerrado) entra no MVP? | **Não.** Seria a 3ª escola (GDD §3.2). Entra na primeira atualização da Terra do Sabiá |
| 4 | Aprovar os nomes do MVP (Facão Firme, Tronco de Aroeira, Garra da Onça, Luz de Vaga-lume, Guarda do Cristal, Olho do Boitatá, Brasa no Facão)? | **Sim**, como nomes de trabalho. Dá para trocar a qualquer momento, porque ficam em chaves de tradução |
| 5 | Títulos com nome de figura do folclore (Olho do Boitatá, Amigo do Curupira, Rastro do Saci) | **Sim**, sempre como homenagem, nunca como caricatura |
| 6 | Títulos com forma masculina e feminina | **Nomes neutros** (todos os propostos são); `name_key_f` fica disponível para quando precisar |
| 7 | O título dá **bônus de atributo**? | **Não.** Só libera quests, diálogos e cosméticos |
| 8 | Título pode ser **perdido**? | **Nunca.** É conquista |
| 9 | Quantos títulos aparecem sob o nome? | **1.** A lista completa fica na ficha do personagem |
| 10 | Títulos de **feito** (ex.: acalmar o Boitatá)? | Depois do MVP, como **alcunhas** só cosméticas |
| 11 | Exclusivas de primeiro título (Roçada, Fogo-Fátuo)? | **Pós-MVP.** No MVP, o primeiro título só abre os ramos |
| 12 | Nomes das skills do GDD parecidos com os de outros jogos (ex.: "Rajada Gélida") | Revisar as 10 antes do playtest |
| 13 | Quantas exclusivas no MVP? | **2 primeiro** (Bote da Onça e Cristal Repartido); as outras 3 depois do primeiro playtest |
| 14 | Revisão cultural das outras regiões | Antes de cada região entrar, com gente que conheça aquela cultura (GDD §4.0) |
