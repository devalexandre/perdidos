# Arco do Lobisomem — Terra do Sabiá

> **Versão:** 1.0 — outubro de 2026
> **Base:** GDD §4.0, §4.2, §8, §9; TITULOS-E-SKILLS §1–§3; regras culturais GDD §4.0.
> **Status:** lore e regras de Causos são `[FECHADO]`. Títulos e skills são `[PROVISÓRIO]` até revisão do dono.
> **Regra de ouro:** nenhum nome, sprite ou mecânica de Ragnarok Online ou de outro jogo. Tudo aqui é original.

---

## 0. Antes de ler

Este documento define **um arco de quest completo**: narrativa canônica, o sistema de **Causos** (mecânica de rumor oral), as três rotas de desfecho, as recompensas, os títulos e as regras de jogo. Cada seção está marcada com o que é **lore** e o que é **mecânica implementável**.

---

## 1. Antecedentes — A Sina da Família Sete-Estrelas

### 1.1 A Maldição `[LORE]`

Há três gerações, o velho **Generoso Sete-Estrelas** era o sétimo filho homem de uma família de tropeiros que cruzava o cerrado entre o sertão e a beira do rio. Quando o sétimo filho nasceu sem ser batizado até a décima lua cheia — porque o vigário estava doente e não havia quem fizesse o sacramento —, a sina caiu: o menino carregaria a **marca da fera** até que um remédio maior que a maldição fosse encontrado.

Generoso cresceu, casou, trabalhou a terra. Mas em cada noite de lua cheia, quando o gado ficava inquieto e os cachorros uivavam antes do escurecer, ele sumia. Na manhã seguinte aparecia nas pedras da beira do córrego, nu e sujo de lama, com arranhões no corpo e a memória apagada. Os vizinhos começaram a murmurar. Os filhos aprenderam a trancar as janelas.

Generoso morreu sem cura. Passou a sina adiante.

Hoje quem carrega a maldição é **Eustáquio Sete-Estrelas**, neto de Generoso, homem de meia-idade que mora sozinho em um sítio afastado, na borda da **Mata Encantada**. De dia é um homem quieto, trabalhador, conhecido por ajudar quem passa pelo caminho. De noite de lua cheia — não fica mais no sítio.

A vila de Porto do Despertar fala baixo sobre os últimos meses: gado morto com marcas que não são de onça. Trilhas na lama de pés que começam humanos e se tornam outra coisa. Uma rezadeira que desapareceu na mata uma noite de lua cheia e voltou com os cabelos brancos sem contar o que viu.

### 1.2 O que é o Lobisomem neste mundo `[LORE]`

O Lobisomem da Terra do Sabiá não é um monstro criado por experimento ou por bruxaria maligna de inimigo. Ele é **o produto de uma falha humana antiga** — um sacramento que não veio, uma sina herdada que ninguém soube quebrar. A criatura não tem consciência própria na forma animal: é o corpo de Eustáquio guiado por um instinto de fera que ele não controla. Quando volta a si, ele não sabe o que fez. Só sente dor.

Isso importa para as rotas: **o Lobisomem não é um vilão**. Mas também é perigoso de verdade.

---

## 2. A Regra de Causos `[MECÂNICA]`

### 2.1 O que é um Causo

No folclore brasileiro, histórias não são quests de quadro de avisos. São **causos**: contados ao redor da fogueira, no balcão da venda, na calçada depois da missa. Cada um que conta acrescenta um detalhe. Cada geração esquece uma parte e inventa outra.

> **"Quem conta um conto aumenta um ponto."**

No jogo, os **Causos** têm duas camadas: os relatos dos NPCs são pistas da investigação; o contador de Causos é a reputação narrativa do personagem. Ouvir uma pista não aumenta o contador. Cada arco concluído concede **1 Causo**, uma única vez por `story_id`; finais alternativos do mesmo arco usam o mesmo ID e não duplicam a recompensa. Os Causos não são gastáveis.

As faixas usam os limiares persistidos em `CharacterData`: **Forasteiro** (0), **Falado** (1), **Assunto da Vila** (3), **Causo de Fogueira** (6), **Lenda** (10) e **Mito** (15). O total e a faixa aparecem no Diário de Missões.

### 2.2 Como coletar Causos `[MECÂNICA]`

O Viajante inicia o arco ao ouvir **qualquer** relato sobre o Lobisomem — não existe um "aceitar quest" claro. Esses relatos são pistas marcadas individualmente por NPC; não são pontos de Causo. As primeiras pistas chegam sem que o jogador procure; quem quiser entender mais fundo precisa investigar.

**Fontes de pistas no mundo:**

| NPC | Local | Relato/pista que conta |
|---|---|---|
| Seu Dorival, o ferreiro | Porto do Despertar, ferraria | "Gado morto com marca de dente que não é de cachorro nem de onça." |
| Dona Jacinta, quitandeira | Feira de Porto do Despertar | "Vi uma sombra grande atravessar o campo antes do sol nascer. Andava em quatro, mas ficou em dois." |
| Sebastião, o tropeiro | Estrada dos Campos do Sabiá | "Já perdi duas reses num mês. Meu pai falava em lobisomem, mas eu nunca acreditei. Tô começando." |
| Crispim, o pescador | Beira do rio, Porto do Despertar | "Pesquei às três da manhã e ouvi um uivo que partia pedra. Veio da direção do sítio do Eustáquio." |
| Marcelina, a benzedeira | Casa nos fundos da vila | Só fala depois de o Viajante reunir três pistas. "Eu sei o que é. E sei o que pode ser feito. Mas é perigoso." |
| Coronel Tobias, o fazendeiro | Sede da fazenda, Campos do Sabiá | "Pago bem quem trouxer a cabeça da fera. Ou prova de que ela não vai mais atacar." |
| Eustáquio Sete-Estrelas | Sítio na borda da Mata Encantada (dia) | Não fala sobre a fera. Mas o Viajante pode notar cicatrizes no braço dele, a gaiola trancada no quarto de fundo, a lua marcada no calendário. |

### 2.3 Verdades e exageros nos Causos `[MECÂNICA]`

Cada relato tem uma **parte verdadeira** (pista real) e uma **parte de exagero** (ruído folclórico). O Viajante que investigar verá que algumas versões contradizem outras. Isso é intencional: faz parte da investigação distinguir o essencial.

| Causo | Parte verdadeira | Exagero |
|---|---|---|
| "Tem dez metros de altura." | A criatura é grande e assustadora de noite | Tamanho exagerado pelo medo |
| "Só aparece na sexta-feira." | A transformação ocorre em qualquer noite de lua cheia | O dia da semana é superstição |
| "Come criança." | Atacou gado e um cachorro | Nenhuma criança foi atacada; medo amplificou |
| "Nasceu de mãe que vendeu a alma." | É o sétimo filho sem batismo | A venda da alma é invenção posterior |
| "Bala de chumbo não pega." | Pele resistente na forma animal | Errado: a vulnerabilidade real é outra |

### 2.4 Rastro de Lua — o ciclo lunar `[MECÂNICA]`

O mundo tem um **ciclo lunar de sete dias em tempo real** (configurável). A lua passa por quatro fases visíveis: nova, crescente, cheia, minguante.

- **Lua cheia:** Eustáquio transforma-se. O sítio está vazio (ele foge para a mata antes). A criatura aparece na Mata Encantada à noite. É o único momento em que o Viajante pode encontrá-la diretamente.
- **Demais noites:** o sítio de Eustáquio está habitado. O Viajante pode conversar com ele (e notar pistas nos objetos do ambiente).
- **Indicador visual:** a lua aparece no HUD do jogo como ícone pequeno com a fase atual. Na semana de lua cheia, o ícone pulsa suavemente.

**Regra de jogo:** as três rotas só se desbloqueiam **depois que o Viajante reuniu pelo menos três pistas** e falou com Marcelina. Ela filtra o ruído e indica o que é verdade. O contador de Causos só sobe quando um desfecho final é entregue.

---

## 3. Fraquezas Reais — o que os Causos revelam `[MECÂNICA + LORE]`

Ao reunir e cruzar os Causos com Marcelina, ela revela as fraquezas reais da criatura e as condições para cada rota:

| Fraqueza | Como usar | Mecânica |
|---|---|---|
| **Bala de chumbo batizada** | Munição abençoada por benzedeiro | Item especial que pode ser obtido com Marcelina (rota do Caçador) |
| **Rama de arruda** | Planta que repele a criatura quando em chamas | Cria uma área de repulsão temporária no chão (rota da Benzedura) |
| **Ferradura de sete cravos** | Objeto de ferro fincado na encruzilhada | Abre o ritual de cura se colocado no lugar certo na noite certa (rota da Benzedura) |
| **Encruzilhada de três caminhos** | Local de poder no folclore brasileiro | Onde o ritual de quebra da maldição deve acontecer (rota da Benzedura) |
| **Chamar pelo nome** | A fera hesita um momento ao ouvir seu nome humano | Interrompe o ataque por 2 s (rota do Pacto) |
| **Sangue e respeito** | Oferecer carne crua e curvar a cabeça | Gesto que sinaliza reconhecimento, não submissão (rota do Pacto) |

---

## 4. As Três Rotas `[MECÂNICA + LORE]`

O Viajante pode percorrer uma única rota ou começar uma e mudar de direção — mas algumas portas fecham se outra for adiantada demais.

### 4.1 Rota A — O Caçador Implacável

**Premissa:** O Coronel Tobias está perdendo gado e dinheiro. Outros fazendeiros da região pressionam. O delegado da vila quer a "ameaça resolvida". Para eles, a solução mais simples é matar a fera.

**Quem guia:** Coronel Tobias (Campos do Sabiá) e o Capitão Eugênio (delegado, Porto do Despertar).

**Arco narrativo:**
1. Coronel Tobias oferece recompensa em ouro.
2. O Viajante coleta as pistas nos Causos e aprende as fraquezas com Marcelina (ou força o caminho sem ela, o que torna o combate mais difícil).
3. Obtém munição batizada de Marcelina (ela avisa: "Não vou rezar a bala pra quem não me ouviu. Vai por sua conta."). Sem o favor de Marcelina a munição é só chumbo normal — ainda funciona, mas a criatura tem mais resistência.
4. Na noite de lua cheia, enfrenta o Lobisomem na Mata Encantada — **Chefe: A Fera da Mata**.
5. Ao matar, recebe a orelha da fera como prova. Coronel Tobias paga. Capitão Eugênio reconhece o Viajante.
6. Na manhã seguinte, o corpo de Eustáquio é encontrado na beira do rio. A vila fica em silêncio por uns dias.

**Consequências narrativas:**
- A maldição da família Sete-Estrelas está quebrada pela morte do portador.
- Alguns NPCs agradecem (o fazendeiro, os tropeiros). Marcelina não fala com o Viajante por um ciclo lunar.
- Não bloqueia outras quests, mas fecha a Rota B e a Rota C permanentemente neste personagem.

**Recompensas:**
- Título: **Dente de Prata** `[PROVISÓRIO]` (estilo caçador solitário)
- Ouro do Coronel Tobias
- 5 skills da árvore Dente de Prata (ver Seção 5.1)
- Item cosmético: Capa Manchada de Barro

---

### 4.2 Rota B — A Benzedura / Quebra da Maldição

**Premissa:** Marcelina sabe desde sempre o que é. Conhece o remédio. Mas o remédio exige ingredientes raros, o momento certo (meia-noite, encruzilhada dos três caminhos, lua cheia), e que a criatura esteja viva e imobilizada — não morta. É o caminho mais longo e mais perigoso.

**Quem guia:** Marcelina, a benzedeira.

**Arco narrativo:**
1. Marcelina revela a verdade sobre Eustáquio depois de ouvir os Causos do Viajante.
2. Lista os ingredientes do ritual:
   - **Raiz de jurema branca** — no fundo da Mata Encantada, guardada pelo Curupira (NPC; ele entrega se o Viajante provar que não vai maltratar a mata — mini-quest de respeito: devolver madeira cortada, curar uma árvore envenenada).
   - **Ferradura de sete cravos batizada** — forjada por Seu Dorival na ferraria, batizada por Marcelina (requer 7 cravos de ferro antigo coletados na Chapada).
   - **Água do rio antes do sol nascer** — coleta simples, mas precisa ser feita no próprio dia do ritual.
3. Na noite de lua cheia, o Viajante deve:
   - Atrair a fera até a encruzilhada dos três caminhos (item de atração: carne crua temperada com rama de arruda).
   - Usar rama de arruda em chamas para criar o círculo de contenção (área de slow e dano mágico que segura a criatura no lugar).
   - Imobilizá-la por 60 segundos (o Viajante pode lutar, usar habilidades de controle, pedir ajuda de grupo).
   - Marcelina chega e executa a benzedura: ritual de 15 segundos durante o qual o Viajante protege ela de qualquer monstro menor que surgir ao redor.
4. No instante em que a benzedura termina, a fera ruge e cai. Eustáquio acorda nu na encruzilhada, confuso e chorando.

**Consequências narrativas:**
- Eustáquio vive. Nos dias seguintes aparece na feira de Porto do Despertar, tímido. Agradece ao Viajante com um item de família.
- Marcelina se torna Mestre do Viajante para uma linha de skills de conhecimento popular.
- O Coronel Tobias fica insatisfeito (não recebeu o que queria), e suas falas mudam.
- O Curupira reconhece o Viajante como "amigo da mata" (abre diálogos futuros).

**Recompensas:**
- Título: **Quebra-Sina** `[PROVISÓRIO]` (estilo rezadeiro, curador, conhecedor)
- 5 skills da árvore Quebra-Sina (ver Seção 5.2)
- Item: **Poção da Benzedeira** (consumível raro, cura estado negativo grave uma vez)
- Item: **Ferradura Batizada** (cosméticos no inventário; aura visual de proteção)
- Acesso à missão secundária de Marcelina

---

### 4.3 Rota C — O Pacto Selvagem

**Premissa:** Há algo que os Causos não contam: a mata ao redor do sítio de Eustáquio está mais viva e mais protegida do que antes. Árvores derrubadas por caçadores furtivos foram espancadas. Laçadores que entravam na reserva sumiram por uma noite e voltaram com medo de tudo. A criatura não apenas ataca o gado dos fazendeiros — ela guarda a mata contra quem quer destruí-la.

O Curupira, ao perceber que o Viajante investiga com respeito, sussurra isso: *"A fera sofre. Mas ela protege. Poucos monstros que vivem na minha mata protegem o que eu protejo."*

**Quem guia:** O Curupira (NPC da Mata Encantada) e a própria fera — pela observação.

**Arco narrativo:**
1. Para descobrir esta rota, o Viajante precisa completar a mini-quest do Curupira (a mesma da Rota B, mas chegar antes de Marcelina encaminhar).
2. O Curupira mostra ao Viajante um rastro de destruição que caçadores furtivos deixaram — animais mortos, mudas arrancadas. E depois mostra o que a fera fez: perseguiu os caçadores para fora da mata.
3. O Viajante precisa **observar** a fera em três noites de lua cheia sem atacar — escondido, usando itens de camuflagem ou habilidades furtivas. Cada observação revela um comportamento: a fera afasta caçadores, cura animais feridos (de forma animal, lambendo), dorme na encruzilhada.
4. Na quarta noite, com o item **Oferenda da Mata** (carne crua + rama de arruda + folha de ipê, montado pelo Viajante), ele deixa a oferenda na encruzilhada e recua. A fera cheira, hesita e não ataca.
5. O Viajante avança devagar, diz o nome de Eustáquio em voz alta. A fera baixa a cabeça.
6. **Mini-boss:** caçadores furtivos contratados pelo Coronel Tobias aparecem para matar a fera enquanto o Viajante está perto. O Viajante precisa defender a fera (ou ao menos sobreviver junto com ela até os caçadores recuarem).
7. Após o combate, a fera olha para o Viajante, rosna suavemente e desaparece na mata. Na manhã seguinte, Eustáquio aparece no sítio, lúcido, com uma folha de arruda presa na mão. Ele não sabe o que aconteceu, mas parece em paz.

**Consequências narrativas:**
- Eustáquio não está curado: a maldição continua, mas a relação entre ele e o Viajante é de aliança. Nas próximas luas, o Viajante pode voltar à mata e a fera reconhece e não ataca — e às vezes ajuda em combates próximos à área protegida.
- O Coronel Tobias fica furioso e passa a ser um antagonista menor em quests futuras.
- O Curupira dá ao Viajante o título de **Amigo da Mata** (pré-requisito cosmético para futuros diálogos profundos).
- Abre linha de quests futuras: **O Guardião da Vereda** (arco expansão, pós-MVP).

**Recompensas:**
- Título: **Voz da Vereda** `[PROVISÓRIO]` (estilo xamânico, comunicador com o selvagem)
- 5 skills da árvore Voz da Vereda (ver Seção 5.3)
- Item: **Dente de Fera** (amuleto cosmético com aura verde selvagem)
- Mascote cosmético: **Filhote de Lobo-Guará** (só visual, sem efeito de jogo)

---

## 5. Títulos e Skills do Arco `[PROVISÓRIO]`

> Estes títulos são `[PROVISÓRIO]`. Os nomes e números precisam de revisão do dono conforme TITULOS-E-SKILLS §1.1.

### 5.1 Dente de Prata (Rota A — O Caçador)

**Estilo:** perseguidor solitário, caçador de presas grandes, sobrevivente noturno.

**Mestre:** Capitão Eugênio (delegado de Porto do Despertar; aceita virar Mestre após o desfecho da Rota A).

| # | Skill (id) | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Rastro (`hunt_track`) | si mesmo | 8 | 20 | revela pegadas e rastros de monstros próximos por 30 s | — |
| 2 | Tiro Certeiro da Caça (`hunt_kill_shot`) | alvo (12) | 20 | 14 | 200% ATK; +50% se o alvo estiver com HP abaixo de 40% | Rastro 3 |
| 3 | Marcação (`hunt_mark`) | alvo (10) | 12 | 18 | o alvo recebe +15% de todo dano por 8 s | Rastro 3 |
| 4 | Armadilha de Espinho (`hunt_spike_trap`) | área no chão (1) | 16 | 20 | prende e sangra o alvo por 4 s | Tiro 1 |
| 5 | Faro do Predador (`hunt_predator_sense`) | si mesmo | 20 | 40 | por 12 s, ataques críticos também revelam posição de inimigos furtivos | Marcação 3 |

---

### 5.2 Quebra-Sina (Rota B — A Benzedura)

**Estilo:** suporte conhecedor, rezadeiro de campo, aquele que cura o que outros não veem.

**Mestre:** Marcelina, a benzedeira (torna-se Mestre da escola popular após o desfecho da Rota B).

| # | Skill (id) | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Reza Brava (`folk_ward`) | aliado (8) | 10 | 16 | remove 1 estado negativo do alvo | — |
| 2 | Fumaça de Erva (`folk_herb_smoke`) | área no chão (3) | 18 | 22 | aliados na área regeneram 3% HP por 3 s (3 pulsos) | Reza 3 |
| 3 | Quebranto (`folk_evil_eye`) | alvo (8) | 14 | 18 | reduz ATK e MATK do alvo em 20% por 6 s | Reza 3 |
| 4 | Arruda Brava (`folk_arruda`) | área no chão (3) | 20 | 25 | área em chamas que repele monstros (não jogadores) por 5 s; dano leve | Fumaça 3 |
| 5 | Benzedura Maior (`folk_great_blessing`) | aliado (8) | 30 | 45 | remove todos os estados negativos e concede imunidade a debuffs por 5 s | Quebranto 3 |

---

### 5.3 Voz da Vereda (Rota C — O Pacto)

**Estilo:** xamânico selvagem, comunicador com criaturas, guardião da mata.

**Mestre:** O Curupira (torna-se Mestre da escola selvagem após o desfecho da Rota C; o acesso ao diálogo aprofundado se abre).

| # | Skill (id) | Tipo | Mana | Rec. | Efeito nv 1 | Pré-req. |
|---|---|---|---|---|---|---|
| 1 | Chamado da Mata (`wild_call`) | área em volta (6) | 14 | 20 | monstros comuns na área param de atacar o Viajante por 4 s | — |
| 2 | Uivo de Aviso (`wild_warning_howl`) | cone 90°, 5 cél. | 18 | 16 | assusta monstros comuns (eles recuam); causa medo em monstro-chefe por 1,5 s | Chamado 3 |
| 3 | Pele da Vereda (`wild_bark_skin`) | si mesmo | 16 | 22 | +25% de DEF e regeneração de HP de 2% por 5 s por 10 s | Chamado 3 |
| 4 | Marca da Fera (`wild_beast_mark`) | alvo (8) | 20 | 20 | marca o alvo: monstros comuns próximos atacam o alvo, ignorando o Viajante por 6 s | Uivo 3 |
| 5 | Forma da Vereda (`wild_vereda_form`) | si mesmo | 35 | 60 | por 10 s: +30% de FOR, velocidade +20%, ataque básico causa knockback; visual de aura verde selvagem | Pele 3 |

---

## 6. Chefes do Arco `[MECÂNICA]`

### 6.1 A Fera da Mata (Lobisomem — forma agressiva)

Usada apenas na Rota A (combate) e na Rota B (imobilização). Na Rota C nunca é tratada como inimiga.

| Atributo | Valor |
|---|---|
| HP | 8.000 `[PROVISÓRIO]` |
| ATK | 180% do dano de um inimigo de nível 12 |
| Resistência | Física normal; mágica moderada; bala não batizada −30% de eficácia |
| Habilidades | Investida (avança 4 cél. e derruba); Rugido (medo 1,5 s em área 3 cél.); Faro (detecta furtivos) |
| Fraqueza | Bala batizada: eficácia +40%. Arruda em chamas: slow 50% e dano +20% |
| Comportamento | Persegue quem mais machucou. Foge ao atingir 20% de HP se não for Rota A |
| Localização | Mata Encantada, noite de lua cheia |
| Renasce | No próximo ciclo de lua cheia |

### 6.2 Caçadores do Coronel (mini-boss — Rota C)

Três NPCs inimigos contratados. Não são criaturas: são humanos armados com bestas e tochas.

| Atributo | Valor |
|---|---|
| HP por caçador | 1.200 `[PROVISÓRIO]` |
| Comportamento | Atacam a fera primeiro; atacam o Viajante se ele interpor |
| Condição de retirada | Dois dos três derrubados: o terceiro foge e conta ao Coronel |

---

## 7. Regras de Causos — Resumo Implementável `[MECÂNICA]`

```
Sistema de Causos
│
├── Fontes: NPCs espalhados no mundo (diálogos opcionais, não forcados)
├── Coleta: flag booleana por NPC (causo_dorival, causo_jacinta, etc.)
├── Gatilho narrativo: 3 causos coletados → Marcelina desbloqueia diálogo especial
│
├── Verdades e Exageros:
│   └── Cada causo tem campo "verdade" e campo "exagero" no dado do NPC
│       Marcelina revela as verdades quando gatilho ativo
│
├── Ciclo Lunar:
│   ├── Ciclo: 7 dias reais (configurável em data/world/lunar_cycle.tres)
│   ├── Fases: nova, crescente, cheia, minguante
│   ├── Eustáquio: presente no sítio em noites não-cheias
│   └── Fera: aparece na Mata Encantada apenas em noites de lua cheia
│
└── Rotas:
    ├── A (matar): habilitada após 3 causos + conversa com Tobias/Eugênio
    ├── B (curar): habilitada após 3 causos + conversa com Marcelina
    └── C (pacto): habilitada após mini-quest do Curupira + 3 observações noturnas
        └── Rotas A e B fecham permanentemente se C iniciada após 2ª observação
```

### 7.1 Variáveis de estado do arco (servidor) `[MECÂNICA]`

```gdscript
# data/quests/lobisomem_arc.tres ou QuestState no servidor
var pistas_coletadas: Dictionary = {} # source_id -> true; relatos do arco
var causos: int = 0                  # +1 por arco finalizado
var historias_concluidas: Dictionary = {} # story_id -> true; impede duplicatas
var marcelina_desbloqueada: bool = false
var rota_escolhida: String = ""      # "hunter" | "healer" | "pact" | ""
var observacoes_noturnas: int = 0    # Rota C: 0 a 3
var ritual_iniciado: bool = false    # Rota B: ritual em andamento
var arco_concluido: bool = false
var desfecho: String = ""            # "killed" | "healed" | "pacted"
```

**Integração de recompensa:** a quest final de cada arco define `QuestDef.reward_causo_id`. Todas as rotas finais do mesmo arco usam o mesmo `story_id` (por exemplo, `lobisomem_arc`); `CharacterData.grant_causo()` persiste a conclusão e impede receber o segundo ponto ao concluir outro final alternativo. Quests intermediárias, incluindo a investigação inicial da Caverna do Reino Encoberto, não definem esse campo.

---

## 8. Itens do Arco `[PROVISÓRIO]`

| Item (id) | Como obter | Uso |
|---|---|---|
| `silver_bullet` | Marcelina (Rota A, custo: 3 pratas + favor) | Munição com eficácia bônus contra a fera |
| `arruda_torch` | Crafting: rama de arruda + tocha simples | Cria área de slow/dano/repulsão |
| `seven_nail_horseshoe` | Seu Dorival (7 cravos de ferro antigo) | Ingrediente do ritual (Rota B) |
| `jurema_root` | Curupira (após mini-quest) | Ingrediente do ritual (Rota B) |
| `river_water_dawn` | Coleta no rio antes do amanhecer (Rota B) | Ingrediente do ritual (Rota B) |
| `wild_offering` | Craft: carne crua + rama de arruda + folha de ipê | Ativa o Pacto na Rota C |
| `family_heirloom` | Eustáquio (recompensa da Rota B) | Cosmético com história |
| `beast_tooth` | Recompensa da Rota C | Amuleto cosmético |
| `hunter_ear` | Drop da fera morta (Rota A) | Entregue ao Coronel pela recompensa |

---

## 9. Impacto Mundial e Quests Futuras `[LORE + PLANEJAMENTO]`

O arco do Lobisomem não termina quando o Viajante fecha uma das rotas. Cada desfecho muda o estado do mundo de formas diferentes:

| Desfecho | Mudança no mundo |
|---|---|
| **Rota A (morte)** | Coronel Tobias torna-se aliado; Marcelina fecha o coração; Curupira fica neutro. O sítio de Eustáquio vira ponto de descanso da milícia. |
| **Rota B (cura)** | Eustáquio abre o sítio para descanso de Viajantes; Marcelina torna-se Mestre; Coronel Tobias torna-se antagonista menor. A encruzilhada dos três caminhos ganha marco narrativo. |
| **Rota C (pacto)** | A fera passa a patrulhar a Mata Encantada com comportamento neutro-aliado; o Coronel Tobias contrata matadores; o Curupira abre diálogos profundos; linha de quest **O Guardião da Vereda** (pós-MVP) fica disponível. |

---

## 10. Ficha Cultural — Lobisomem no Folclore Brasileiro `[LORE — REFERÊNCIAS]`

Esta seção garante que o arco respeita as regras culturais do GDD §4.0.

**Origens da lenda:**
- O Lobisomem brasileiro é influência do folclore ibérico (Lobishomem português), mas ganhou características próprias no Brasil: é sempre o **sétimo filho homem**, a transformação ocorre em **noites de lua cheia** (especialmente sextas-feiras, na crença popular), e a cura envolve **sangue próprio** ou **bênção religiosa**.
- A lenda varia por região: no sul, no sertão e no cerrado há diferenças. Este arco usa a versão do **cerrado e do Brasil Central**, compatível com a Terra do Sabiá.

**Elementos folclóricos usados neste arco:**
- Sétimo filho varão sem batismo → transformação involuntária ✅
- Cura pelo sacramento ou pela benzedura ✅ (Rota B)
- Bala de prata/chumbo batizado como fraqueza ✅ (Rota A)
- Rama de arruda como proteção ✅ (Rotas B e C)
- Encruzilhada como ponto de poder ✅ (Rota B)
- A criatura não tem consciência durante a transformação ✅

**Elementos evitados (por respeito ou por conflito com o GDD):**
- Religiões vivas: o ritual de Marcelina é de **benzedeira leiga** (tradição popular, não religiosa formal) — nunca pastores, padres, igrejas identificáveis
- Nenhum genocídio ou tragédia real como mecânica de jogo
- O Lobisomem não é vilão — é uma pessoa sofrendo

---

## 11. Estado da implementação para o beta fechado — 02/10/2026

O beta tem um caminho jogável de investigação e três quests finais com o mesmo `reward_causo_id = lobisomem_arc`:

- As pistas persistem por personagem; três liberam a investigação da Caverna e a conversa de Marcelina.
- A escolha A oferece a Coronel Tobias uma provação contra a Fera da Mata original (estágio 3), somente em noite de lua cheia na Mata. A entrega grava `killed`, concede um Causo e toca a trilha triste uma vez.
- A escolha B é uma versão curta de beta: visitar a encruzilhada e retornar a Marcelina. A entrega grava `healed` e concede o Causo.
- A escolha C exige três observações únicas em noites diferentes de lua cheia, visitar o ponto da oferenda e retornar ao Curupira. A entrega grava `pacted` e concede o Causo.
- `CharacterData` persiste rota, observações, conclusão e desfecho; rotas alternativas não concedem outro Causo.

**Não considerar o arco completo ainda:** faltam a quest de ingredientes e o combate não letal da Rota B, a mini-quest e os caçadores da Rota C, o NPC Eustáquio de dia, Capitão Eugênio, itens/recompensas cosméticas, títulos e skills provisórios, patrulha aliada e demais consequências mundiais. Marcelina, Tobias e Curupira usam sprites de reserva no beta. A música está pronta, mas a apresentação visual/cinemática do luto ainda não existe.

---

*Fim do documento. Versão 1.0 — outubro de 2026.*
