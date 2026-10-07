# Projeto Isekai (nome provisório) — Game Design Document e Especificação Técnica

> **Versão:** 0.2 — setembro de 2026 (tema medieval, cidades inspiradas em países, âncora de estilo)
> **Autor do projeto:** Alexandre
> **Público deste documento:** agentes de IA (código, arte, design) e colaboradores humanos que vão construir o MVP.

---

## 0. Como usar este documento (leia primeiro)

Este arquivo é a fonte da verdade do projeto. Regras para qualquer agente que trabalhe nele:

1. **Decisões marcadas como `[FECHADO]`** foram tomadas pelo dono do projeto. Não altere, não "melhore" e não substitua por alternativas.
2. **Decisões marcadas como `[PROVISÓRIO]`** são valores iniciais para permitir o desenvolvimento. Implemente exatamente como descrito, mas sempre como **constante configurável** (arquivo de configuração ou `const` centralizada), nunca como número mágico espalhado no código.
3. **Decisões marcadas como `[EM ABERTO]`** ainda não foram tomadas. Implemente o comportamento padrão indicado, isole a lógica para ser trocada facilmente e **não invente regras adicionais**.
4. Não adicione sistemas fora do escopo do MVP (seção 3) sem pedido explícito.
5. **Propriedade intelectual:** o jogo é *inspirado* no estilo de Ragnarok Online, mas é proibido usar nomes, sprites, mapas, músicas, sons, ícones, monstros ou textos de Ragnarok ou de qualquer outro jogo. Tudo deve ser original.
6. Idioma do jogo no MVP: **português do Brasil**. Todo texto visível ao jogador deve passar por um sistema de tradução (chaves de texto), para permitir outros idiomas depois.
7. Código, nomes de arquivos, variáveis e commits: **inglês**. Comentários podem ser em português.

---

## 1. Visão geral

| Item | Definição |
|---|---|
| Gênero | MMORPG isekai `[FECHADO]` |
| Tema | Fantasia medieval. Cada região do mundo tem uma cidade inspirada num país real, com lendas, contos e mitologia desse país gerando quests, inimigos, armas, skills e chefes `[FECHADO]` |
| Referência de estilo | **Inspirado** em Ragnarok Online (sensação, proporções, clima), sem copiar nada dele `[FECHADO]` |
| Visual | Pixel art em 2.5D: mapas 3D com personagens e monstros em sprites 2D (billboard), câmera orbital, no espírito dos MMOs clássicos dos anos 2000 `[FECHADO]` |
| Combate | Clique para mover e atacar (point-and-click), estilo Ragnarok `[FECHADO]` |
| Classes | **Não existem classes pré-definidas.** Progressão livre por escolas de habilidades `[FECHADO]` |
| Plataformas | PC e mobile juntos, com cross-play `[FECHADO]` |
| Engine | Godot 4 (versão estável mais recente da série 4.x) `[FECHADO]` |
| Modelo | Gratuito para jogar; monetização **apenas cosmética** + passe de batalha cosmético. Sem pay-to-win, sem RMT `[FECHADO]` |
| Objetivo do projeto | Divertir, não lucrar `[FECHADO]` |

### 1.1 Frase de visão

> "Você foi arrancado do seu mundo e caiu num lugar lindo e perigoso. Ninguém te dá uma classe: você se torna aquilo que tiver coragem de aprender."

### 1.2 Premissa isekai `[PROVISÓRIO — texto de lore pode ser reescrito]`

O jogador é uma pessoa do mundo moderno que desperta em um mundo de **fantasia medieval** após um evento misterioso. Esse mundo é formado por reinos cujas terras parecem ecos do nosso planeta: em cada um, as lendas e contos de um povo real são verdade. O saci ri nos redemoinhos, a serpente de fogo guarda os campos, os yokai andam pelas montanhas de outro reino, os trolls pelas florestas geladas de mais outro.

Os habitantes chamam as pessoas vindas de fora de **Viajantes**. Viajantes não nascem com um caminho definido, mas têm uma afinidade incomum para aprender qualquer arte, desde que encontrem quem a ensine. Por isso os **Mestres** espalhados pelos reinos são tão importantes: cada técnica é aprendida com alguém, em algum lugar.

Elementos de lore que os sistemas usam (manter consistentes):

- **Viajante:** o jogador.
- **Mestres:** NPCs que ensinam habilidades através de quests.
- **Marca da Alma:** o túmulo deixado quando o Viajante morre (ver seção 12). Só o dono a enxerga fora de áreas PVP.

---

## 2. Pilares de design

1. **Liberdade de construção:** especialista ou generalista, a escolha é do jogador.
2. **Aprender é uma jornada:** habilidades novas vêm de quests com Mestres, não de menus.
3. **Risco real, perda justa:** o mundo não é bloqueado por nível; morrer custa o equipamento usado, nunca o inventário.
4. **Social por natureza:** cidade compartilhada, grupos com instância própria, resgate entre amigos.
5. **Mundo bonito:** mapas pensados para serem "dignos de print".
6. **Justo com todos:** dinheiro compra aparência, nunca poder.

---

## 3. Escopo do MVP

O MVP existe para responder uma pergunta: **o loop principal é divertido a ponto de as pessoas voltarem?** Tudo que não ajuda a responder isso fica para depois.

### 3.1 Dentro do MVP

- 1 cidade (mapa compartilhado)
- 3 mapas de caça (instanciados por grupo), sendo 1 deles o mapa vitrine "digno de print"
- 1 mapa PVP pequeno (compartilhado)
- Nível de personagem e nível de skill
- 2 escolas de habilidades com 5 skills cada (seção 8)
- Quests de aprendizado com Mestres (seção 9)
- 6 tipos de monstros comuns + 1 chefe (seção 10)
- Inventário, equipamento e drops
- Sistema de morte com túmulo (Marca da Alma)
- Grupos com instância do líder, chat (global da cidade, grupo, sussurro)
- Contas, login, persistência completa
- Interface para mouse/teclado e para toque
- Servidor dedicado hospedado em São Paulo

### 3.2 Fora do MVP (não implementar agora)

- Comércio entre jogadores, lojas de jogadores, leilão
- Guildas
- Loja de cosméticos, passe de batalha, temporadas
- Crafting e profissões
- Clima e ciclo dia/noite com efeito em gameplay (ciclo apenas visual é opcional)
- Montarias, casas, pets
- Mais de 2 escolas de habilidades

### 3.3 Critérios de sucesso do MVP

Playtest fechado com a comunidade (Discord e canal do YouTube do autor). Métricas a registrar desde o primeiro dia:

- Retenção D1 e D7 (jogadores que voltam após 1 e 7 dias)
- Duração média de sessão, separada por PC e mobile
- Mortes por mapa e taxa de recuperação de túmulos
- Tempo médio para completar cada quest de aprendizado
- Distribuição de skills aprendidas (especialistas x generalistas)

---

## 4. Mundo e mapas

### 4.0 Tema e estrutura do mundo `[FECHADO: tema e conceito; PROVISÓRIO: lista e ordem das regiões]`

- **Tema:** fantasia medieval.
- O mundo é dividido em **regiões**. **Cada região tem uma cidade inspirada em um país real**, construída a partir das lendas, contos populares, mitologia e arquitetura histórica desse país.
- Cada região fornece o seu próprio pacote de conteúdo: Mestres e quests, monstros, armas e equipamentos, skills (variações regionais ou uma escola própria), um chefe, música, arquitetura e paleta regional.
- Isso também é uma característica de Ragnarok (cidades com sabores culturais diferentes), aqui aplicada de forma sistemática e com identidade própria.
- **MVP:** 1 região (Brasil). Novas regiões entram em atualizações e temporadas.

**Regras de inspiração cultural (obrigatórias para qualquer agente de conteúdo):**

1. **Inspiração, não caricatura.** Evitar estereótipos de povos e culturas. Pesquisar fontes do próprio país sempre que possível.
2. **Folclore de domínio público.** Usar lendas e contos tradicionais. Não usar versões autorais modernas (personagens de livros, filmes, séries, animes ou quadrinhos protegidos).
3. **Religiões vivas.** Divindades e figuras sagradas de religiões praticadas hoje não viram monstros a serem mortos nem piada. Preferir criaturas do folclore, espíritos da natureza e heróis lendários; figuras sagradas podem, no máximo, ser referências respeitosas no cenário.
4. **Tragédias reais** (escravidão, genocídios, guerras recentes) não viram inimigos, chefes ou humor.
5. **Ficha da região:** antes de produzir conteúdo, criar uma ficha em `data/regions/{pais}.md` com país de inspiração, lendas usadas e suas fontes, arquitetura de referência, paleta regional (subconjunto da paleta mestra), clima musical, monstros, chefe, Mestres, skills e armas típicas.

**Planejamento de regiões `[PROVISÓRIO]`:**

| Região | Inspiração | Lendas e elementos | Chefe possível | Armas típicas |
|---|---|---|---|---|
| **Terra do Sabiá (MVP)** | Brasil | Saci, Curupira, Boitatá, Iara, Mula sem Cabeça, Lobisomem, Corpo-Seco, Mapinguari | Boitatá | facão, borduna, bodoque |
| Reino das Mouras | Portugal | mouras encantadas, Coca, gigante Adamastor | Adamastor | alabarda, espada de marinheiro |
| Ilhas do Sol Nascente | Japão | kappa, tengu, kitsune, oni | Yamata no Orochi | katana, naginata |
| Fiordes de Gelo | Noruega/Islândia | trolls, draugr, lindworm, Fenrir | Fenrir | machado, escudo redondo |
| Costa das Colunas | Grécia antiga | Hidra, Minotauro, Medusa, sereias | Hidra | lança, escudo hoplita |
| Areias do Nilo | Egito antigo | esfinge, escorpiões gigantes, Apep | Apep | khopesh |
| Brumas Verdes | Irlanda/Escócia | banshee, selkie, kelpie, dullahan | Balor | espada longa, harpa mágica |
| Estepe de Ferro | povos eslavos | Baba Yaga, Koschei, Zmey Gorynych | Koschei | machado, arco |
| Império de Jade | China | jiangshi, Nian, raposas espirituais | Nian | jian, guandao |
| Selvas de Obsidiana | México antigo | nahuales, alux, Cipactli | Cipactli | macuahuitl |

A ordem de lançamento e os detalhes de cada região serão definidos depois do MVP. Cada região nova deve ser revisada contra as regras culturais acima.

### 4.0.2 Progressão geográfica de caça — decisão do dono (30/09/2026)

Cada região deve ter várias áreas conectadas: saída da cidade com monstros de nível baixo → área intermediária de nível maior → área avançada com monstros fortes e chefes. Referência de experiência: exploração e progressão por mapas do Ragnarok, mantendo nomes, arte e culturas próprios do projeto. Uma região não deve ser reduzida a uma única arena que mistura todas as dificuldades.

As faixas de nível são recomendações, não travas. Portais de ida e volta, chegada segura e dificuldade reconhecível por área. Chefes e formas atrozes ficam nas áreas avançadas; áreas iniciais limitam evolução e não acumulam abates para invocar chefes. O Campo de Treino continua separado e sua saída exige título.

Primeiro incremento: Porto do Despertar ↔ Campos do Sabiá (1–10; monstros 2–7) ↔ Mata Encantada (6–12; monstros 6–10) ↔ Chapada do Céu Partido (12–25; comuns 12–16, veteranos 16–20 e chefes 20–22; atrozes 26–28 à noite). As faixas sobrepõem-se para permitir exploração. Os cenários novos começam como mapas de protótipo jogáveis e recebem acabamento artístico depois. Demais regiões seguem planejadas no atlas e receberão cadeias próprias; setores culturais do treino não contam como regiões jogáveis completas.

Detalhamento e estado: `docs/mundo/progressao-areas.md`.

### 4.1 Tipos de mapa `[FECHADO]`

| Tipo | Instância | Quem se vê | Regras |
|---|---|---|---|
| **Cidade** | Uma única, compartilhada | Todos | Sem combate. Mestres básicos, loja de NPC, armazém |
| **Caça** | Uma cópia por grupo | Apenas membros do mesmo grupo | Monstros, drops e túmulos pertencem à instância (túmulos: ver seção 12) |
| **PVP** | Uma única, compartilhada | Todos | Combate livre entre jogadores; quem mata pode saquear o equipamento caído |

Jogador sem grupo = grupo de uma pessoa, com instância própria.

### 4.2 Mapas do MVP — região Terra do Sabiá (Brasil) `[PROVISÓRIO — nomes podem mudar]`

Fantasia medieval com alma brasileira: muros caiados, telhados de telha, azulejos, janelas coloridas, feiras cheias de frutas, ipês floridos, rios largos e matas densas.

**Cidade — "Porto do Despertar"**
Cidade portuária à beira de um grande rio, onde os Viajantes costumam aparecer. Praça central com um grande cristal (ponto de renascimento) sob um ipê amarelo gigante, casario colonial-medieval colorido, feira de frutas e ervas, docas com barcos de vela, casa dos Mestres, portões para os mapas de caça e para a arena. Tamanho aproximado: 120 x 120 unidades.

**Caça 1 — "Campos do Sabiá"** (nível 1 a 10)
Campos abertos de cerrado, com ipês amarelos e roxos em flor, buritis, riachos claros e cupinzeiros. Monstros fracos e passivos. Mestres das quests iniciais mandam o jogador para cá.

**Caça 2 — "Mata Encantada"** (nível 8 a 18)
Mata fechada com cipós, raízes enormes, igarapés e as ruínas de um velho forte coberto de musgo. Feixes de luz entre as copas. Monstros agressivos. Lar do Curupira (NPC, não inimigo; pode aparecer em quests futuras como guardião da mata).

**Caça 3 — "Chapada do Céu Partido"** — **mapa vitrine** (nível 15 a 25, acessível a qualquer nível)
Chapadas de rocha avermelhada erguendo-se sobre um mar de nuvens, pontes naturais, cachoeiras caindo no vazio, pôr do sol permanente. Monstros fortes e o chefe Boitatá. Um Mestre avançado escondido no ponto mais alto. É o mapa das capturas de tela e do trailer: priorizar qualidade visual acima de tudo.

**PVP — "Arena da Queimada"**
Clareira de cerrado queimado com troncos retorcidos e pedras para cobertura. Pequena (60 x 60 unidades).

### 4.3 Acesso `[FECHADO]`

Nenhum mapa é bloqueado por nível. A faixa de nível é apenas indicativa e deve aparecer no portal de entrada ("Recomendado: nível 15+").

### 4.4 Ponto de renascimento `[PROVISÓRIO]`

Ao morrer, o jogador renasce no cristal da cidade com 50% de vida e mana.

---

## 5. Visibilidade, grupos e instâncias

### 5.1 Regra de instância `[FECHADO]`

Cada jogador tem um `instance_id`. Dois jogadores só se veem e interagem se tiverem o mesmo `instance_id`.

- Cidade e PVP: `instance_id = map_id` (ex.: `"city_awakening"`)
- Caça: `instance_id = map_id + ":" + party_id` (ex.: `"field_cliffs:party_42"`)

### 5.2 Líder do grupo `[FECHADO]`

A instância de caça **sempre pertence ao líder do grupo**. Quando um membro entra num mapa de caça, ele vai para a instância do líder naquele mapa.

### 5.3 Saída ou desconexão do líder `[PROVISÓRIO]`

Se o líder desconectar, há uma tolerância de **3 minutos** para reconexão. Se não voltar, ou se sair do grupo, a liderança passa para o membro mais antigo do grupo e **a instância continua a mesma**, com todos dentro.

### 5.4 Tamanho do grupo `[PROVISÓRIO]`

Máximo de **5** jogadores.

### 5.5 Ciclo de vida da instância

- Criada quando o primeiro jogador do grupo entra no mapa.
- Destruída **5 minutos** `[PROVISÓRIO]` depois que o último jogador sair.
- Monstros e drops no chão são destruídos com a instância. Túmulos **não** (seção 12).

### 5.6 Implementação obrigatória

- Toda a filtragem acontece **no servidor**. O servidor nunca envia estado de entidades de outra instância ao cliente (evita trapaça).
- Usar `MultiplayerSynchronizer.public_visibility = false` + `add_visibility_filter()` comparando `instance_id`, e chamar `update_visibility()` ao trocar de mapa, entrar ou sair de grupo.
- Monstros, drops e projéteis também pertencem a uma instância.

---

## 6. Personagem

### 6.1 Criação `[PROVISÓRIO]`

- Nome (3 a 16 caracteres, único no servidor)
- Corpo: masculino ou feminino
- Tom de pele: 6 opções
- Cabelo: 8 estilos x 10 cores
- Cor dos olhos: 6 opções
- Roupa inicial: 3 variações de "roupa de Viajante" (roupas modernas simples: moletom, camiseta, jaqueta — reforça o isekai)

### 6.2 Atributos `[PROVISÓRIO]`

Nomes e efeitos próprios deste jogo (não copiar os de Ragnarok):

| Atributo | Sigla | Efeito |
|---|---|---|
| Força | FOR | Dano físico, capacidade de carga |
| Destreza | DES | Precisão, velocidade de ataque, chance de crítico |
| Vitalidade | VIT | Vida máxima, defesa física, regeneração de vida |
| Intelecto | INT | Dano mágico, mana máxima |
| Espírito | ESP | Regeneração de mana, defesa mágica, redução de recarga |

- Todos começam com 5 em cada.
- **3 pontos** por nível de personagem, distribuídos livremente.
- Redistribuição: não existe no MVP.

### 6.3 Nível de personagem `[FECHADO: existe; PROVISÓRIO: números]`

- Nível máximo no MVP: **25**.
- Ganho de XP: derrotar monstros e completar quests.
- XP necessária para o próximo nível: `floor(100 * nivel^1.6)`.
- XP dividida no grupo: cada membro presente na instância recebe `XP_total * (1 + 0.1 * (membros - 1)) / membros`.
- Nível de personagem **não ensina habilidades**; serve de requisito para quests e aumenta atributos.

### 6.4 Valores derivados `[PROVISÓRIO]`

- Vida máxima = `100 + VIT * 12 + nivel * 8`
- Mana máxima = `50 + INT * 8 + nivel * 4`
- Regeneração de vida (fora de combate, por 5 s) = `2 + VIT * 0.5`
- Regeneração de mana (por 5 s) = `1 + ESP * 0.6`
- "Fora de combate" = 6 segundos sem causar ou receber dano.

---

## 7. Visão geral da progressão `[FECHADO]`

Três camadas independentes:

1. **Nível do personagem** — sobe com XP de monstros e quests. Dá pontos de atributo e é requisito de quests.
2. **Nível da skill** — cada skill evolui individualmente e fica mais forte.
3. **Conquistar título e aprender skills** — a quest de conquista concede o título e as cinco skills da árvore no nível 1. Títulos de ramo também concedem as árvores ancestrais. Nenhum nível, item ou compra concede título ou skill.

Quanto mais o jogador se aprofunda numa escola, mais quests daquela escola ficam disponíveis. Não existem classes: um jogador pode conhecer skills de todas as escolas.

---

## 8. Escolas e skills

### 8.1 Regras gerais

- **Nível máximo de skill:** 10 `[PROVISÓRIO]`.
- **Como a skill sobe de nível:** `[EM ABERTO]` — pelo uso ou por pontos distribuídos ao subir de nível.
  - **Padrão para implementar agora:** **por uso**. Cada uso bem-sucedido (que acerte ao menos um alvo, ou que seja aplicado, no caso de buffs) concede XP de skill. XP para o próximo nível da skill = `20 * nivel_skill^2`. Isolar essa lógica num único módulo (`SkillProgression`) para poder trocar por pontos depois.
- **Limite para não "aprender tudo":** `[EM ABERTO]`.
  - **Padrão para implementar agora:** barra de atalhos com **8 espaços** de skills equipadas. O jogador pode conhecer quantas quiser, mas só usa as 8 equipadas. Trocar skills da barra só fora de combate.
- Toda skill tem: custo de mana, recarga (cooldown), tempo de conjuração (0 = instantânea), alcance, tipo de alvo (alvo único, área no chão, área ao redor de si, cone, linha, si mesmo) e escalonamento por nível.
- Os números abaixo são `[PROVISÓRIO]` e devem viver num arquivo de dados (`data/skills/*.tres` ou JSON), nunca no código.

### 8.2 Escola da Lâmina (combate físico corpo a corpo)

| # | Skill | Nível | Tipo | Mana | Recarga | Alcance | Efeito base (nv 1) | Por nível |
|---|---|---|---|---|---|---|---|---|
| L1 | **Golpe Firme** | 1 | Alvo único | 8 | 4 s | Corpo a corpo | 150% ATK | +12% ATK |
| L2 | **Investida** | 4 | Alvo único | 14 | 10 s | 8 un. | Avança até o alvo, 120% ATK e atordoa 0,8 s | +8% ATK, +0,05 s |
| L3 | **Giro de Aço** | 8 | Área ao redor (raio 3) | 20 | 8 s | — | 110% ATK em todos ao redor | +10% ATK |
| L4 | **Postura de Ferro** | 12 | Si mesmo | 25 | 30 s | — | +40% DEF por 10 s, −20% velocidade de movimento | +4% DEF, +0,5 s |
| L5 | **Corte do Horizonte** | 18 | Linha (12 x 2 un.) | 40 | 20 s | — | 0,6 s de conjuração, 320% ATK | +25% ATK |

### 8.3 Escola do Arcano (magia elemental à distância)

| # | Skill | Nível | Tipo | Mana | Recarga | Alcance | Efeito base (nv 1) | Por nível |
|---|---|---|---|---|---|---|---|---|
| A1 | **Faísca** | 1 | Alvo único (projétil) | 6 | 1,5 s | 12 un. | 0,4 s de conjuração, 130% MATK | +10% MATK |
| A2 | **Rajada Gélida** | 4 | Cone (6 un., 60°) | 16 | 9 s | — | 100% MATK e −35% vel. de movimento por 3 s | +8% MATK |
| A3 | **Chama Rastejante** | 8 | Área no chão (raio 3) | 22 | 12 s | 10 un. | 40% MATK por segundo durante 5 s | +4% MATK/s |
| A4 | **Barreira Arcana** | 12 | Si mesmo ou aliado | 28 | 25 s | 8 un. | Escudo que absorve `50 + MATK * 1,5` por 8 s | +10% absorção |
| A5 | **Queda Estelar** | 18 | Área no chão (raio 4) | 45 | 24 s | 12 un. | 1,2 s de conjuração, 1 s de aviso visual no chão, 380% MATK | +30% MATK |

### 8.4 Requisitos de aprendizado `[FECHADO]`

As cinco skills de uma árvore são concedidas juntas, no nível 1, quando o jogador termina a quest do título. Ramos incluem as árvores ancestrais. Não há nível mínimo de personagem nem quest individual por skill; pontos de skill são usados para subir os níveis, respeitando os pré-requisitos da árvore.

---

## 9. Quests de aprendizado

### 9.1 Regras `[FECHADO: títulos e árvores por quest; PROVISÓRIO: formato]`

- Quests são dadas por **Mestres** (NPCs). Mestres básicos ficam na cidade ou no mapa inicial; os avançados ficam escondidos em mapas perigosos.
- Quests de título devem ter objetivos graduais (abates, coleta de itens, exploração e provações). Cada título já conquistado, exceto Viajante, aumenta globalmente os requisitos das próximas quests de título: +1 abate comum por título anterior; coletas aumentam à metade desse ritmo, arredondada para cima. A meta fica fixa ao aceitar a quest.
- Devem ser simples, mas com algum desafio. Duração alvo: 5 a 20 minutos cada.
- Cada quest tem de 1 a 3 etapas, usando estes tipos de objetivo: **derrotar** (X monstros de um tipo), **coletar** (itens que caem de monstros), **explorar** (chegar a um ponto do mapa), **entregar/conversar**, **provação** (desafio de combate numa instância individual contra um oponente controlado pelo Mestre).
- O NPC mostra requisitos que faltam ("Volte quando conhecer 2 técnicas da Lâmina").
- Quests podem ser feitas em grupo; objetivos de derrotar e coletar contam para todos os membros presentes na instância.

### 9.2 Mestres e quests do MVP `[PROVISÓRIO — nomes e falas podem ser reescritos]`

**Escola da Lâmina — Mestra Brisa Ferrenha** (cidade) e **Velho Aroeira** (topo da Chapada)

| Skill | Mestre | Etapas |
|---|---|---|
| L1 Golpe Firme | Brisa (cidade) | Derrotar 8 Redemoinhos Arteiros nos Campos → voltar e conversar |
| L2 Investida | Brisa (cidade) | Coletar 5 Cascos de Tatu-Pedra → provação: alcançar 3 alvos de treino em 20 s |
| L3 Giro de Aço | Brisa (cidade) | Derrotar 15 Lobisomens Jovens → coletar 1 Lâmina Enferrujada nas ruínas do forte da Mata |
| L4 Postura de Ferro | Brisa (cidade) | Provação: sobreviver 45 s contra o Boneco de Treino da Mestra sem sair do círculo |
| L5 Corte do Horizonte | Aroeira (Chapada, ponto mais alto) | Explorar: encontrar Aroeira → derrotar 3 Harpias da Tempestade → provação: duelo contra a sombra de Aroeira |

**Escola do Arcano — Mestre Orvalho** (cidade) e **Irmã Estela** (chapada escondida)

| Skill | Mestre | Etapas |
|---|---|---|
| A1 Faísca | Orvalho (cidade) | Coletar 5 Luzes de Vaga-lume (Vaga-lumes Encantados, Campos) → conversar |
| A2 Rajada Gélida | Orvalho (cidade) | Explorar: tocar 3 marcos de pedra antigos nos Campos → derrotar 10 Tatus-Pedra |
| A3 Chama Rastejante | Orvalho (cidade) | Coletar 6 Brasas Fátuas dos Corpos-Secos (Mata) |
| A4 Barreira Arcana | Orvalho (cidade) | Provação: proteger um cristal por 60 s contra ondas de fantoches arcanos |
| A5 Queda Estelar | Estela (Chapada) | Explorar: achar a chapada oculta → coletar 3 Fragmentos Estelares (Harpias ou Boitatá) → provação: aguentar uma chuva de meteoros por 30 s |

### 9.3 Quest de introdução `[PROVISÓRIO]`

Tutorial no Porto do Despertar: o Viajante acorda nas docas do rio, aprende a mover, conversar, atacar, abrir o inventário e equipar a primeira arma. Termina apresentando os dois Mestres da cidade e deixando a escolha livre.

---

## 10. Combate, monstros e drops

### 10.1 Controles `[FECHADO: clique para atacar]`

**PC:**
- Clique esquerdo no chão: mover (pathfinding).
- Clique esquerdo em inimigo: mover até o alcance e atacar automaticamente em ciclo até o alvo morrer ou o jogador dar outra ordem.
- Teclas 1–8: skills da barra. Skills de alvo usam o alvo atual; skills de área pedem um clique no chão (com pré-visualização da área).
- Clique direito arrastando ou Q/E: girar câmera. Roda do mouse: zoom (limitado).

**Mobile:**
- Referência de UX: **Albion Online mobile**. Priorizar uso em paisagem com dois polegares, centro livre para ler o combate e menus legíveis ao toque, mantendo a identidade visual de Perdidos.
- Joystick virtual à esquerda; ataque principal maior à direita, habilidades em arco interno e ações auxiliares separadas. As áreas de toque devem ficar inteiras na tela e não se sobrepor.
- Chat recolhido ao entrar; inventário, personagem e demais menus sob demanda, fora da área de combate. Informações essenciais (vida, recurso e alvo) permanecem visíveis.
- Toque no chão: mover. Toque no inimigo: selecionar e atacar.
- Botões de skill no canto inferior direito (8 botões em arco, grandes o bastante para dedo: mínimo 56 dp).
- Skills de área: tocar no botão entra no modo de mira; tocar no chão confirma.
- Dois dedos arrastando: girar câmera. Pinça: zoom.
- Toda a interface deve ser utilizável em uma tela de 6 polegadas em modo paisagem.

Referências: [controles e HUD específicos para mobile](https://albiononline.com/news/mobile-pre-register-now) e [personalização do HUD](https://albiononline.com/news/dev-talk-horizons-ui).
Referência visual principal fornecida pelo usuário: `image copy.png` (raiz do projeto). Composição desejada: retrato/vida/recurso e alvo no alto à esquerda, objetivos abaixo, minimapa no alto à direita, atalhos na lateral direita, joystick amplo e translúcido embaixo à esquerda, ataque e habilidades embaixo à direita e chat recolhido próximo à base. A mira por arraste com indicador de direção/área e cancelamento, visível na referência, é uma evolução pendente dos controles de habilidades.
Estado da implementação: o controle atual oferece quatro atalhos configuráveis; ampliar para os oito previstos, validar dimensões físicas em aparelhos e adaptar todos os painéis continuam pendentes. O primeiro ajuste aumenta os botões, mantém o arco dentro da área de toque e interrompe o joystick ao ocultar os controles ou perder o foco.

### 10.2 Fórmulas `[PROVISÓRIO]`

- `ATK = ataque_da_arma + FOR * 2 + nivel`
- `MATK = poder_magico_da_arma + INT * 2 + nivel`
- `DEF = soma_def_equipamento + VIT * 1`
- `MDEF = soma_mdef_equipamento + ESP * 1`
- Dano físico = `ATK * multiplicador * (100 / (100 + DEF_alvo))`
- Dano mágico = `MATK * multiplicador * (100 / (100 + MDEF_alvo))`
- Variação aleatória: ±10%.
- Crítico (só físico): chance = `5% + DES * 0,3%`, dano x1,5.
- Velocidade de ataque básico: `1,0 + DES * 0,01` ataques por segundo, máximo 2,5.
- Precisão/esquiva: não existe no MVP (todo ataque acerta).

### 10.3 Monstros do MVP `[PROVISÓRIO]`

| Monstro | Inspiração | Mapa | Nível | Comportamento | Drops principais |
|---|---|---|---|---|---|
| Redemoinho Arteiro | redemoinhos do Saci | Campos | 1–3 | Passivo; dá pulinhos e some/reaparece perto | Folha Rodopiante, Gorrinho Vermelho (raro) |
| Vaga-lume Encantado | fauna mágica | Campos | 2–5 | Passivo; voa em padrão | Luz de Vaga-lume |
| Tatu-Pedra | fauna do cerrado | Campos | 5–9 | Passivo; rola em investida quando atacado | Casco de Tatu-Pedra, Couro Grosso |
| Lobisomem Jovem | lenda do Lobisomem | Mata | 9–14 | Agressivo; anda em duplas | Presa de Lobisomem, Couro Grosso |
| Esqueleto de Raiz (nome provisório) | criatura original de ossos cobertos por raízes, sem atribuição a uma tradição específica | Masmorra da Mata | 12–18 | Morto-vivo comum; lento, guarda passagens | Osso Antigo, fibra de raiz |
| Corpo-Seco | lenda do Corpo-Seco | Mata | 12–17 | Agressivo, lento, muita vida | Brasa Fátua, Casca Seca |
| Harpia da Tempestade | gavião-real + tempestade | Chapada | 17–23 | Agressiva, ataque à distância | Pena de Tempestade, Fragmento Estelar (raro) |
| **Chefe: Boitatá** | lenda do Boitatá | Chapada | 25 | Chefe com 3 fases (seção 10.4) | Equipamento raro/épico, Escama de Boitatá, Fragmento Estelar |

- Reaparecimento de monstros comuns: 30 s após morrer. Chefe: 10 min por instância.
- IA: estados `ocioso → patrulha → perseguição → ataque → retorno`. Monstros que se afastam demais do ponto de origem voltam e recuperam a vida.
- **Masmorra em planejamento — Caverna do Reino Encoberto (nome provisório):** entrada nas raízes profundas da Mata Encantada, com vários andares. O rumor de uma passagem subterrânea para outro reino é, por enquanto, mistério ficcional do projeto; a fonte da lenda amazônica mencionada pelo dono precisa ser identificada e revisada antes de atribuir esse motivo a uma tradição real. O elenco pode incluir Esqueleto de Raiz (original) e Corpo-Seco (folclore já documentado). Nos andares profundos, o Lobisomem retorna como chefe de covil (estágio 3); sua forma Atroz (estágio 4, arte própria) só aparece à noite, seguindo §10.7. A Mula sem Cabeça **não** entra nesta masmorra: fica reservada para um arco de maior escala e sem componente religioso.

### 10.4 Chefe: Boitatá `[PROVISÓRIO]`

Na lenda, o Boitatá é a serpente de fogo que protege os campos de quem os incendeia. No jogo, ele foi **enfurecido** pela fumaça das queimadas da região e ataca qualquer um que se aproxime do alto da Chapada. Derrotá-lo acalma o espírito (a morte dele é um "adormecer" em chamas que se apagam), mantendo o respeito à lenda.

Serpente gigante feita de fogo, com olhos enormes e brilhantes, 5 vezes o comprimento de um jogador.
- Fase 1 (100–60%): mordidas e sopro de fogo em cone (aviso visual no chão 1 s antes).
- Fase 2 (60–30%): invoca 3 fogos-fátuos que perseguem jogadores; deixa rastros de fogo no chão por onde passa.
- Fase 3 (30–0%): mais rápido; anéis de fogo se fecham em partes da arena, forçando movimentação.
Pensado para 3 a 5 jogadores de nível 20+, mas possível tentar com menos.

### 10.5 Drops

- Cada monstro tem uma tabela de drops (item, chance, quantidade) em arquivo de dados.
- Drops aparecem no chão e pertencem ao grupo; qualquer membro pode pegar. Some após 60 s.
- Moeda do jogo: **Estrelas** `[PROVISÓRIO]` — cai de monstros e vem de venda a NPCs.

---

## 11. Itens, inventário e equipamento

### 11.1 Espaços de equipamento `[PROVISÓRIO]`

Arma (mão principal), mão secundária (escudo ou tomo), cabeça, corpo, botas, acessório 1, acessório 2.

- Armas de Lâmina (espadas, machados) dão ATK. Armas de Arcano (cajados, varinhas) dão MATK e um pouco de ATK. Qualquer um pode usar qualquer arma; skills da Lâmina exigem arma corpo a corpo equipada, skills do Arcano não exigem nada.

### 11.2 Raridade `[PROVISÓRIO]`

| Raridade | Cor do nome | Atributos extras |
|---|---|---|
| Comum | Branco | 0 |
| Incomum | Verde | 1 |
| Raro | Azul | 2 |
| Épico | Roxo | 3 (só do chefe) |

### 11.3 Inventário e armazém `[PROVISÓRIO]`

- Inventário: 40 espaços. Itens empilháveis até 99.
- Armazém na cidade: 60 espaços, compartilhado entre personagens da mesma conta.
- Loja de NPC na cidade: compra itens básicos (poções, armas iniciais) e compra drops dos jogadores.
- Poções: vida pequena/média, mana pequena/média. Recarga compartilhada de 10 s.

### 11.4 Lista mínima de equipamentos do MVP `[PROVISÓRIO]`

Por faixa (1–10, 10–18, 18–25): 2 armas de Lâmina, 2 armas de Arcano, 1 escudo, 1 tomo, 2 cabeças, 2 corpos, 2 botas, 2 acessórios. Mais 3 itens épicos do chefe. Total aproximado: 45 itens.

---

## 12. Morte e Marca da Alma (túmulo)

### 12.1 Regras `[FECHADO]`

- Ao morrer, **o inventário fica intacto**.
- **Todo o equipamento vestido cai** e fica num túmulo (Marca da Alma) no local da morte.
- O túmulo dura **3 horas**. Depois disso, desaparece com os itens.
- **Fora da área PVP:** só o dono pode pegar os itens do túmulo.
- **Na área PVP:** quem matou o jogador também pode pegar os itens.
- **Resgate com amigos:** o dono pode montar um grupo; os amigos entram na instância do líder e ajudam a limpar o caminho. Só o dono (ou quem matou, no PVP) recolhe os itens.

### 12.2 Implementação obrigatória

- O túmulo **não pertence à instância**. Ele é salvo no banco de dados com: dono, mapa, posição, itens, horário de expiração e, no PVP, o id de quem matou.
- Sempre que o dono entrar em **qualquer instância** daquele mapa, o servidor cria o túmulo para ele naquela posição. Se ele estiver num grupo, os membros do grupo também veem o túmulo (mas não podem pegar).
- No mapa PVP (instância única), o túmulo é visível para todos, mas só dono e quem matou podem pegar.
- Um job no servidor remove túmulos expirados.
- Ao pegar, os itens voltam para o inventário (não são reequipados automaticamente). Se o inventário estiver cheio, os itens que não couberem ficam no túmulo.
- Mostrar no mapa/minimapa do dono um ícone da própria Marca da Alma e um contador de tempo restante.

### 12.3 Morrer de novo antes de recuperar `[EM ABERTO]`

As opções são: o túmulo anterior some, ou os túmulos se acumulam.
**Padrão para implementar agora:** os túmulos **se acumulam**, cada um com seu próprio prazo de 3 horas. Deixar controlado por uma constante `GRAVES_STACK = true`.

### 12.4 Proteção de itens ("seguro") `[EM ABERTO]`

Regra fechada: qualquer proteção **só pode ser obtida jogando**, nunca comprada. Ideias em avaliação:
1. **Vínculo de Alma:** vincular itens via quest; itens vinculados não caem. Espaços de vínculo liberados por quests.
2. **Amuleto de proteção:** consumível obtido no jogo, protege o equipamento em uma morte e se quebra.
3. **Proteção de iniciante:** até certo nível o equipamento não cai.
4. **Desgaste em vez de perda** para itens protegidos.

**Padrão para implementar agora:** apenas a infraestrutura — um campo `protected` por item equipado e uma função `should_drop_on_death(item, context)` onde as regras futuras serão plugadas. Nenhuma proteção ativa no MVP até decisão.

---

## 13. Social

- **Grupos:** convidar, aceitar, sair, expulsar (só líder), passar liderança. Até 5 membros. Barra de vida dos membros na tela.
- **Chat:** canal da instância atual (local), grupo, sussurro (privado). Filtro básico de palavrões. Limite de 1 mensagem por segundo.
- **Amigos:** lista simples (adicionar, remover, ver se está online e em qual mapa). Facilita o resgate de túmulos.
- **Emotes:** 6 emotes básicos (acenar, sentar, rir, chorar, raiva, coração) mostrados como balão pixel art sobre o personagem.
- **Bloquear jogador:** esconde chat e convites daquele jogador.

---

## 14. Monetização (fora do MVP, mas guia a arquitetura)

### 14.1 Regras `[FECHADO]`

- **Nada de pay-to-win.** Dinheiro nunca compra poder, progressão, XP, proteção de itens ou vantagem.
- Receita apenas por **cosméticos** e **passe de batalha cosmético**.
- **Sem RMT:** não existe venda de itens entre jogadores por dinheiro real, nem integração com mercados externos.
- O objetivo do projeto é divertir, não lucrar.

### 14.2 Cuidados legais e de design `[PROVISÓRIO — requer validação jurídica]`

- No Brasil, o ECA Digital (Lei 15.211/2025) proíbe loot boxes em jogos acessíveis a menores, e o Marco Legal dos Jogos exige consentimento dos responsáveis para compras de menores. Portanto: **nenhuma recompensa aleatória ligada a dinheiro**. O passe de batalha deve dar recompensas garantidas; se houver bônus, usar sistema determinístico (fragmentos trocáveis por cosméticos escolhidos), não aumento de chance de drop.
- Cosméticos comprados ficam presos à conta. Cosméticos obtidos jogando poderão ser negociados por moeda do jogo quando o comércio existir.
- Classificação indicativa, verificação de idade e controle parental nas compras antes de qualquer loja entrar no ar.

### 14.3 Preparação no MVP

O sistema de sprites em camadas (seção 17.4) já deve suportar uma camada de "aparência" que se sobrepõe ao equipamento real, para cosméticos futuros.

---

## 15. Arquitetura técnica

### 15.1 Visão geral

```
[Cliente Godot (PC/Android/iOS)]
     │ 1. login HTTPS
     ▼
[API de contas] ──► [PostgreSQL]
     │ 2. devolve token assinado (JWT, 5 min)
     ▼
[Cliente] ── 3. conecta via ENet (UDP) com o token ──► [Servidor de jogo Godot headless] ──► [PostgreSQL]
```

### 15.2 Decisões `[FECHADO]`

- Engine: **Godot 4.x**, linguagem **GDScript tipado**.
- Visual 2.5D: cena **3D**, personagens/monstros/itens no chão como `Sprite3D`/`AnimatedSprite3D` com **billboard** (eixo Y), câmera orbital.
- Servidor **autoritativo**: o cliente só envia intenções; o servidor decide tudo (movimento, dano, drops, XP).
- Servidor = o mesmo projeto Godot exportado como servidor dedicado (`--headless`, feature tag `dedicated_server`), sem renderização.
- Rede: **ENet (UDP)** com a API de alto nível de multiplayer da Godot (RPCs, `MultiplayerSpawner`, `MultiplayerSynchronizer`).
- Banco: **PostgreSQL**.
- Hospedagem: VPS em **São Paulo**.

### 15.3 Decisões técnicas `[PROVISÓRIO]`

- Tick do servidor: **20 Hz**. Clientes interpolam posições com atraso de 100 ms.
- **Sem colisão física entre entidades** (como nos MMOs clássicos): jogadores e monstros atravessam uns aos outros. Movimento usa `NavigationServer3D`.
- **Um único processo de servidor** no MVP cuida da cidade, do PVP e de todas as instâncias. Cada instância é uma subárvore de nós; como não há física entre entidades, todas as instâncias do mesmo mapa **compartilham o mesmo navmesh**. Distâncias e áreas de skills são calculadas por matemática simples, filtrando por `instance_id`.
- Protocolo com número de versão: o servidor recusa clientes com versão diferente e o cliente mostra "Atualize o jogo".
- Plataformas de build no MVP: **Windows e Android** primeiro (iOS depois, por exigir Mac e conta de desenvolvedor Apple).

### 15.4 Mensagens cliente → servidor (intenções)

| RPC | Parâmetros | Validação no servidor |
|---|---|---|
| `req_move` | posição destino | ponto alcançável no navmesh |
| `req_attack` | id do alvo | alvo na mesma instância, vivo, atacável |
| `req_cast` | id da skill, alvo ou posição | skill conhecida e na barra, mana, recarga, alcance |
| `req_use_item` | id do item | item no inventário, recarga de poção |
| `req_equip` / `req_unequip` | id do item, espaço | item válido para o espaço |
| `req_pickup` | id do drop ou túmulo | distância ≤ 2 un., permissão (seção 12) |
| `req_interact` | id do NPC | distância ≤ 3 un. |
| `req_quest_accept` / `req_quest_turn_in` | id da quest | requisitos (seção 8.4) |
| `req_chat` | canal, texto | limite de taxa, tamanho ≤ 200 caracteres |
| `req_party_*` | convidar, aceitar, sair, expulsar, passar liderança | permissões |
| `req_change_map` | id do portal | distância do portal |
| `req_hotbar_set` | espaço, id da skill | fora de combate |
| `req_allocate_stats` | pontos por atributo | pontos disponíveis |

Toda mensagem inválida é ignorada e registrada em log (possível trapaça). Limite geral de 30 mensagens por segundo por cliente.

### 15.5 Persistência

Salvar no banco: ao sair, ao trocar de mapa, ao subir de nível, ao aprender skill, ao morrer, ao pegar túmulo, e a cada 60 s para jogadores ativos.

Tabelas mínimas:

- `accounts` (id, email, hash_senha [argon2], criado_em, ultimo_login, flags)
- `characters` (id, account_id, nome, aparência [json], nivel, xp, atributos [json], pontos_livres, vida, mana, mapa, posição, estrelas, criado_em)
- `character_skills` (character_id, skill_id, nivel, xp)
- `character_hotbar` (character_id, slot, skill_id)
- `items` (id, character_id ou storage_account_id, item_def_id, quantidade, raridade, atributos_extras [json], local: inventario/equipado/armazem/tumulo, slot, protected)
- `quests_progress` (character_id, quest_id, etapa, progresso [json], concluida_em)
- `graves` (id, owner_character_id, map_id, posição, killer_character_id nulo, criado_em, expira_em)
- `grave_items` (grave_id, item_id)
- `friends`, `blocks`
- `metrics_events` (id, character_id, tipo, dados [json], criado_em) — para as métricas do playtest

### 15.6 API de contas

Serviço HTTP leve, separado do servidor de jogo (linguagem a critério do desenvolvedor). Endpoints: `POST /register`, `POST /login`, `POST /token/refresh`, `GET /characters`, `POST /characters`, `DELETE /characters/{id}`. O `login` devolve um token de sessão; ao entrar no jogo, o cliente pede um token curto de 5 minutos, que o servidor de jogo valida pela assinatura (chave pública), sem nunca receber senha.

### 15.7 Infraestrutura `[PROVISÓRIO]`

- VPS: 2 vCPU, 4 GB RAM, 40–80 GB SSD, Ubuntu Server 24.04 LTS, região São Paulo.
- **Docker Compose** com os serviços: `game-server`, `accounts-api`, `postgres`, `caddy` (HTTPS automático para a API).
- Portas abertas: 22/tcp (SSH só com chave), 443/tcp (API), 7777/udp (jogo). Banco nunca exposto.
- UFW + fail2ban.
- Backup diário do PostgreSQL enviado para armazenamento externo, com retenção de 14 dias.
- Ambiente de staging na mesma máquina, em portas diferentes, para testar atualizações.
- Logs estruturados (JSON) e painel simples com CPU, memória e jogadores online.

---

## 16. Estrutura do projeto

```
/game                      # projeto Godot (cliente e servidor)
  /addons                  # plugins (ex.: importador do Aseprite)
  /assets
    /characters            # camadas de personagem (seção 17.4)
    /monsters
    /items/icons
    /skills/icons
    /vfx
    /environment
      /textures
      /props
      /skyboxes
    /ui
    /audio/music
    /audio/sfx
    /fonts
  /data                    # dados de design (nada de número mágico no código)
    /skills
    /items
    /monsters
    /drops
    /quests
    /npcs
    /maps
    /balance.tres          # todas as constantes [PROVISÓRIO] deste documento
  /localization            # textos pt_BR (e outros depois)
  /scenes
    /maps
    /entities
    /ui
  /scripts
    /shared                # código usado por cliente e servidor
    /server
    /client
/accounts-api
/infra
  docker-compose.yml
  /caddy
  /backups
/docs
  GDD-projeto-isekai.md    # este arquivo
```

---

## 17. Direção de arte e pipeline de geração por IA

As artes serão criadas com ferramentas de IA de imagem e depois tratadas. Esta seção é a especificação que todas as artes devem seguir. **Consistência é mais importante que detalhe**: um jogo com arte simples e coerente parece profissional; um jogo com artes lindas mas desencontradas parece amador.

### 17.0 Âncora de estilo (fazer ANTES de qualquer outra arte)

A âncora de estilo é um pequeno conjunto de artes aprovadas que servem de referência para todas as gerações seguintes. Ela fica em `/assets/_reference/style_anchor/` e é composta por:

- `paleta-mestra.gpl` e `paleta-mestra.png` — paleta oficial (fornecida junto com este documento; o `.gpl` abre direto no Aseprite)
- `gabarito-proporcao-64px.png` — gabarito técnico legado (64×64, 3 cabeças); o padrão atual de produção é 96×96 e aproximadamente 3 cabeças, documentado em `docs/arte-personagens-blender.md`
- As **5 imagens-âncora** descritas em 17.0.3, geradas por IA, tratadas e aprovadas

#### 17.0.1 DNA visual: o que herdar da *sensação* de Ragnarok

- Personagens pequenos com **cabeça grande e traços de anime/mangá**, cerca de **3 cabeças de altura**, com corpo compacto e robusto e silhueta expressiva mesmo em poucos pixels. A referência fornecida para proporção é registrada em docs/arte-personagens-blender.md; serve de guia de tamanho e volume, sem copiar arte ou identidade.
- Cores **claras, alegres e levemente pastel**, com sombreamento suave; o mundo parece acolhedor mesmo quando é perigoso.
- Sprites 2D sobre **cenários 3D com texturas pintadas**, câmera de cima que gira em volta do personagem.
- **Monstros fofos convivendo com monstros ameaçadores**; mesmo os perigosos têm formas simples e legíveis.
- **Chapéus e acessórios de cabeça** como a principal forma de expressão visual do jogador (base para os cosméticos futuros).
- Cidades com **sabores culturais bem distintos** entre si.

#### 17.0.2 O que NÃO copiar (nunca)

- Nenhum sprite, monstro, NPC, chapéu, arma, roupa de classe, mapa, interface, fonte, ícone, música ou som de Ragnarok ou de qualquer outro jogo.
- Nada de geleias rosadas redondas como monstro inicial, nem qualquer criatura que lembre um monstro conhecido do jogo.
- Nenhum nome de cidade, item ou habilidade de Ragnarok.
- Nos prompts, nunca escrever "Ragnarok", "in the style of" ou nomes de artistas. Descrever as características com palavras próprias (como em 17.0.1).

#### 17.0.3 As 5 imagens-âncora

Para cada uma: gerar de 8 a 16 variações, escolher a melhor, reduzir, quantizar para a paleta mestra e limpar (processo 17.5). Depois, **colocar as cinco lado a lado numa prancha única**: se alguma parecer de outro jogo, refazer essa. Só depois da aprovação da prancha começa qualquer animação.

**Âncora 1 — Folha de referência do Viajante (masculino e feminino)**
Três vistas (frente, lado, costas), em pose neutra, em alta resolução, para servir de modelo de design.
- Aparência: jovem adulto, aproximadamente 3 cabeças de altura, olhos grandes estilo anime, cabelo castanho bagunçado (masc.) e rabo de cavalo castanho (fem.).
- Roupa (o toque isekai): **moletom com capuz azul** (`#2f55a8` / `#5a90e0`), calça jeans escura, tênis branco com detalhe vermelho, **pequena mochila marrom**. Contraste proposital com o mundo medieval.
- Expressão: curiosa e um pouco surpresa.

```
pixel art character reference sheet of a young adult isekai traveler, anime-inspired face with large expressive eyes,
compact proportions about 3 heads tall, broad torso and shoulders, short sturdy limbs and readable boots, messy brown hair, blue hoodie, dark jeans, white sneakers with red details,
small brown leather backpack, curious surprised expression, three views side by side: front, side, back,
neutral standing pose, 3/4 top-down game view, soft bright slightly pastel colors, clean 1px colored outline,
3-4 tone soft cel shading, light from top-left, flat plain background, crisp pixels, no anti-aliasing
```

**Âncora 2 — Viajante em tamanho real de jogo, 5 direções**
A partir da âncora 1 aprovada (usar como imagem de referência). Quadros de 96 x 96, personagem com ~84–87 px de altura, proporção de aproximadamente 3 cabeças, pose parada, direções S, SE, L, NE, N numa linha.

```
pixel art game sprite sheet, the same young traveler character from the reference, idle standing pose,
5 views in one row facing: front, front-right, right, back-right, back, 96x96 pixel frames,
character about 84 pixels tall and 3 heads high, compact strong silhouette, big expressive head, 3/4 top-down view, soft pastel colors, 1px colored outline,
light from top-left, transparent background, consistent design in every direction
```

**Âncora 3 — Monstro-âncora: Tatu-Pedra**
Define o equilíbrio "fofo, mas ameaçador" de todos os monstros.

```
pixel art monster sprite, a chubby armadillo with shell plates made of smooth reddish stone, small moss patches,
big round shiny eyes, cute but slightly grumpy, fantasy MMORPG field enemy, 3/4 top-down view,
front-right facing, 64x64 frame, soft bright colors, 1px colored outline, 3-4 tone shading,
light from top-left, transparent background, simple readable silhouette
```

**Âncora 4 — Cena de ambiente: praça do Porto do Despertar**
Define cor, luz e arquitetura dos cenários (e como o Viajante se encaixa neles).

```
pixel art scene of a medieval fantasy riverside town square with Brazilian colonial flavor, whitewashed walls,
clay tile roofs, blue and white decorative tiles, colorful window frames, a giant yellow flowering ipe tree
in the center over a glowing blue crystal, fruit market stalls, river docks with small sailing boats in the back,
seen from a 3/4 top-down elevated camera, warm afternoon light from top-left, soft bright slightly pastel palette,
cozy and inviting, crisp pixels, no text, no characters
```

**Âncora 5 — Prancha de ícones**
Define o padrão dos ícones de itens e skills. Seis ícones 32 x 32 lado a lado: facão, cajado de madeira com cristal, poção vermelha, casco de tatu-pedra, pena de tempestade, chapéu de palha com flor.

```
pixel art game icon set, six separate icons in a row on a plain background: a short machete, a wooden staff
with a blue crystal, a red health potion, a reddish stone armadillo shell plate, a dark blue feather crackling
with electricity, a straw hat with a small flower, each icon 32x32, bold readable silhouettes,
soft bright colors, 1px dark colored outline, light from top-left, no text
```

#### 17.0.4 Registro

Para cada âncora aprovada, salvar junto: a imagem original gerada, a versão final tratada, o prompt exato, a ferramenta/modelo, a seed (se houver) e a data. Toda geração futura deve anexar as âncoras 1 a 5 como referência de estilo quando a ferramenta permitir.

### 17.1 Guia de estilo `[PROVISÓRIO até aprovar as primeiras artes]`

- **Estilo:** pixel art colorida e luminosa, fantasia medieval aconchegante com um toque de aventura, com a sensação descrita em 17.0.1. Nunca citar jogos ou artistas específicos nos prompts.
- **Paleta mestra:** uma única paleta de 50 cores para o jogo inteiro (`paleta-mestra.gpl`, 12 rampas de 4 tons + contorno base `#16131c` + branco `#fcfaf5`). Todo asset final é quantizado para ela. Regiões usam subconjuntos dela, nunca cores novas sem atualizar o arquivo.
- **Luz:** sempre vindo de **cima e da esquerda**. Sombra projetada suave e oval sob personagens e monstros (sprite separado, 50% de opacidade).
- **Contorno:** 1 pixel, **seletivo e colorido** (tom mais escuro da cor vizinha), nunca preto puro. Contorno externo levemente mais escuro que o interno.
- **Sombreamento:** 3 a 4 tons por material. Sem gradientes suaves, sem antialiasing contra o fundo, sem pixels órfãos, dithering apenas em céus e grandes áreas.
- **Proporção dos personagens:** cerca de **3 cabeças de altura** total, cabeça expressiva, ombros e tronco largos, braços e pernas compactos e calçados legíveis. Aplicação e valores exatos no Blender: docs/arte-personagens-blender.md.
- **Rosto:** queixo curto, bochechas arredondadas, nariz pouco projetado e olhos próximos ao centro. Esculpir a malha antes de ampliar a cabeça. A prancha anterior de 28/09 foi rejeitada; detalhes e nova revisão em `docs/arte-personagens-blender.md`.
- **Ângulo de visão dos sprites:** três quartos de cima, cerca de 35° de inclinação, compatível com a câmera do jogo.

### 17.2 Escala e renderização `[PROVISÓRIO]`

- **Densidade:** 32 pixels = 1 unidade do mundo (≈ 1 metro). No `Sprite3D`: `pixel_size = 0.03125`, `texture_filter = nearest`.
- Personagem adulto: ~84–87 px de altura, em quadro de **96 x 96 px**; reservar margem para cabelo, chapéus e animação.
- Monstros pequenos: quadro 48 x 48; médios: 64 x 64; grandes: 96 x 96; chefe: 160 x 160.
- Resolução interna do jogo: a cena é renderizada numa `SubViewport` de **640 x 360** e ampliada por múltiplo inteiro para a tela (efeito pixel-perfect uniforme). Interface desenhada por cima em resolução própria.
- Câmera: perspectiva, inclinação fixa de ~45° para baixo, giro livre em torno do jogador (yaw), zoom limitado entre 0,8x e 1,3x.

### 17.3 Direções e animações

**Direções:** 8 no jogo (S, SE, L, NE, N, NO, O, SO). Gerar e desenhar apenas **5**: **S, SE, L, NE, N**. As outras 3 são o espelho horizontal (SO = SE espelhado, O = L espelhado, NO = NE espelhado).

A direção exibida é calculada pelo ângulo entre para onde a entidade olha e a posição da câmera, arredondado para o setor de 45° mais próximo.

**Animações de personagem jogável** (quadros por direção, duração por quadro):

| Animação | Quadros | ms/quadro | Loop |
|---|---|---|---|
| idle (parado, respiração) | 8 | 100 (ciclo de 800 ms) | sim |
| walk (andar) | 8 | 100 (ciclo de 800 ms) | sim |
| attack_unarmed / attack_blade / attack_staff | 8 | 70 | não |
| cast (conjurar, mãos à frente) | 8 | 90 | não |
| hit (receber dano) | 4 | 60 (ciclo de 240 ms) | não |
| death (cair) | 8 | 150 | não (fica no último quadro) |
| sit (sentado) | 1 | — | — |

**Monstros comuns:** idle 4, walk 6, attack 6, hit 2, death 6.
**Chefe:** idle 6, walk 8, attack_melee 8, attack_area 10, summon 8, hit 2, death 10.

Formato de entrega do jogador: folha por animação com altura 480 px e largura de 96 px × número de quadros, **linhas = direções na ordem S, SE, L, NE, N**, colunas = quadros de 96×96. Fundo transparente; quadros de idle, ataques e morte têm 8 colunas, hit 4, walk 8 e sit 1. O pipeline Blender → pixel art está em `docs/arte-personagens-blender.md`; NPCs antigos podem manter suas contagens documentadas separadamente.

### 17.4 Personagem em camadas (paper doll)

Para permitir equipamentos visíveis e cosméticos futuros, o personagem é montado em camadas que se sobrepõem, **todas com o mesmo tamanho de quadro, mesmos quadros e mesmo ponto de origem (pés no centro inferior)**:

| Ordem (de trás para frente) | Camada | Observação |
|---|---|---|
| 1 | shadow | sombra oval |
| 2 | offhand_back | escudo/tomo quando visto de costas |
| 3 | weapon_back | arma quando o personagem olha para N, NE ou NO |
| 4 | body | corpo base com tom de pele (roupa íntima neutra) |
| 5 | outfit | roupa / armadura do espaço "corpo" |
| 6 | boots | botas |
| 7 | eyes | olhos |
| 8 | hair | cabelo |
| 9 | head_gear | chapéu, elmo |
| 10 | weapon_front | arma quando olha para S, SE, L (e espelhos) |
| 11 | offhand_front | escudo/tomo de frente |

- **Troca de cor por shader:** pele, cabelo e olhos são desenhados numa rampa de cinza de referência e coloridos por um shader de troca de paleta. Assim, uma única arte de cabelo serve para as 10 cores.
- No MVP, cada equipamento de corpo, cabeça e botas pode ter apenas **3 variações visuais por faixa de nível** (itens diferentes podem compartilhar a mesma aparência). Armas: 1 aparência por tipo (espada, machado, cajado, varinha).
- Camada de aparência cosmética (futuro): cada espaço terá um "visual sobreposto" opcional.

**Camadas de personagem:** a implementação atual gera camadas alinhadas e recoloríveis no pipeline descrito em `docs/arte-personagens-blender.md`; roupa cosmética prevalece sobre roupa do título, depois vem equipamento de corpo e Viajante. Para novos assets fora desse pipeline, gerar camadas separadas e alinhadas continua sendo o ponto mais difícil. Processo recomendado:
1. Gerar primeiro o **corpo base** completo, em todas as direções e animações, e aprovar.
2. Usar esses quadros aprovados como **imagem de referência/controle** (pose e silhueta) para gerar cada roupa, cabelo e arma por cima.
3. Recortar cada camada à mão no Aseprite, removendo o que pertence a outras camadas.
Se o custo for alto demais, a alternativa de MVP é gerar o personagem **completo** para as 3 roupas iniciais e só separar cabelo e arma.

### 17.5 Pipeline de produção de cada asset

1. **Folha de referência (model sheet):** para cada personagem/monstro, gerar primeiro uma folha com a criatura vista de frente, lado e costas, com a paleta. Aprovar antes de animar. Guardar em `/assets/_reference/` junto com o prompt, a ferramenta e a seed usados.
2. **Geração:** usar sempre a mesma ferramenta, o mesmo modelo e imagens de referência de estilo fixas (uma "âncora de estilo" com 3 a 5 artes aprovadas). Gerar em múltiplo exato do tamanho final (ex.: 768 x 768 para um quadro de 96 x 96 = fator 8).
3. **Redução:** reduzir pelo fator exato com vizinho mais próximo (nearest), nunca bilinear.
4. **Quantização:** converter para a paleta mestra, sem dithering.
5. **Limpeza manual (Aseprite ou LibreSprite):** corrigir contorno, remover pixels órfãos, alinhar o ponto de origem, igualar proporções entre direções, verificar o loop das animações.
6. **Exportação:** sprite sheet + JSON, nomes conforme 17.9.
7. **Revisão** com o checklist 17.10.

### 17.6 Modelos de prompt

Prompts em inglês funcionam melhor na maioria das ferramentas. Substituir o que está entre chaves.

**Personagem (folha de referência):**
```
pixel art character reference sheet, {descrição do personagem}, anime-inspired face, compact proportions about 3 heads tall, broad torso and shoulders, short sturdy limbs and readable boots,
three views: front, side, back, standing neutral pose, 3/4 top-down game perspective,
limited palette, clean 1px colored outline, 3-4 tone cel shading, light from top-left,
flat transparent background, crisp pixels, no anti-aliasing, cozy medieval fantasy MMORPG style, soft bright slightly pastel colors
```

**Quadros de animação:**
```
pixel art sprite sheet, {personagem}, {animação} animation, {n} frames in a single row,
facing {direção}, consistent character design matching the reference, 64x64 frame grid,
3/4 top-down view, limited palette, 1px colored outline, light from top-left, transparent background
```

**Monstro:**
```
pixel art monster sprite, {descrição}, cute but threatening, fantasy MMORPG enemy,
3/4 top-down view, {tamanho} frame, limited palette, 1px colored outline, 3-4 tone shading,
light from top-left, transparent background, readable silhouette
```

**Ícone de item (32 x 32):**
```
pixel art game icon, {item}, centered, 32x32, bold readable silhouette, limited palette,
1px dark colored outline, light from top-left, transparent background, no text
```

**Textura de terreno (repetível):**
```
seamless tileable pixel art texture, {material: grass with small flowers / cobblestone / wet sand},
top-down view, 64x64, limited palette, subtle variation, no strong directional pattern, no outline
```

**Céu / paisagem de fundo (skybox panorâmico):**
```
pixel art panoramic sky background, {cena}, wide horizontal composition, soft layered clouds,
atmospheric perspective, limited palette, painterly pixel shading, no characters, no text
```

**Prompt negativo (quando a ferramenta aceitar):**
```
blurry, anti-aliasing, gradient, photorealistic, 3d render, text, watermark, signature, logo,
extra limbs, deformed hands, inconsistent proportions, jpeg artifacts, background scenery (for sprites)
```

**Proibido nos prompts:** nomes de jogos, franquias, personagens existentes ou artistas ("in the style of ..."). Descrever sempre com palavras próprias.

### 17.7 Descrições dos personagens e monstros do MVP `[PROVISÓRIO]`

- **Viajante (jogador):** ver Âncora 1 (17.0.3). Roupas modernas simples, em contraste com o mundo medieval.
- **Mestra Brisa Ferrenha (Lâmina):** guerreira de meia-idade, cabelo curto grisalho preso, gibão de couro com ombreiras de metal, lenço vermelho no pescoço, cicatriz no queixo, facão longo na cintura, postura firme.
- **Velho Aroeira (Lâmina avançada):** ancião magro e queimado de sol, barba branca rala, chapéu de couro de abas largas, gibão de couro gasto, espada fina e longa, sentado em meditação sobre uma rocha na beira da chapada.
- **Mestre Orvalho (Arcano):** homem gordinho e alegre, óculos redondos, túnica verde-água cheia de bolsos com frascos de ervas, chapéu de palha pontudo, pequenas luzes flutuando ao redor.
- **Irmã Estela (Arcano avançado):** mulher alta e serena, cabelo prateado longo em trança, vestido branco e azul-noite bordado com constelações, cajado de madeira clara com uma estrela presa na ponta.
- **Redemoinho Arteiro:** pequeno redemoinho de folhas secas e poeira com um gorrinho vermelho girando no topo e dois olhinhos travessos.
- **Vaga-lume Encantado:** vaga-lume do tamanho de um gato, corpo verde-escuro, abdômen que brilha em amarelo quente.
- **Tatu-Pedra:** ver Âncora 3 (17.0.3).
- **Lobisomem Jovem:** lobo bípede magro e desajeitado, pelagem cinza-amarronzada arrepiada, orelhas grandes, olhos amarelos, mais assustador que forte.
- **Corpo-Seco:** figura humanoide seca e retorcida como um galho morto, pele de casca de árvore, brasas azuladas (fogo-fátuo) no lugar dos olhos e nas rachaduras.
- **Harpia da Tempestade:** grande ave de rapina inspirada no gavião-real, penas azul-escuras com faíscas elétricas, penacho na cabeça, garras amarelas.
- **Boitatá (chefe):** serpente gigante feita de fogo laranja e azul, corpo em espiral, olhos enormes e luminosos como faróis, fagulhas soltando do corpo.

### 17.8 Lista de assets do MVP (estimativa)

| Categoria | Quantidade aproximada |
|---|---|
| Camadas do personagem (corpo x2, 8 cabelos, 3 roupas iniciais, ~9 roupas de equipamento, ~6 cabeças, ~6 botas, 4 armas, escudo, tomo) | ~40 camadas, cada uma com todas as animações |
| NPCs (4 Mestres + ~6 moradores + lojista) | 11, apenas idle e walk |
| Monstros | 6 comuns + 1 chefe |
| Ícones de itens | ~70 (equipamentos, drops, poções) |
| Ícones de skills | 10 |
| Efeitos visuais de skills (VFX) | 10 folhas + impacto, cura, subir de nível, morte, Marca da Alma |
| Texturas de terreno repetíveis | ~15 |
| Objetos de cenário (árvores, pedras, casas, ruínas, pontes, cristal) | ~60 |
| Céus panorâmicos | 4 (um por mapa externo, o da Chapada com pôr do sol) |
| Interface (painéis 9-slice, botões, barras, molduras, cursores) | 1 kit completo, versão PC e mobile |
| Emotes | 6 |

### 17.9 Convenção de nomes

`{categoria}_{nome}_{variante}_{animação}.png` em minúsculas, sem acentos, separado por `_`.
Exemplos: `chr_body_female_walk.png`, `chr_hair_03_idle.png`, `mon_stone_armadillo_attack.png`, `icon_item_werewolf_fang.png`, `icon_skill_spark.png`, `vfx_starfall.png`, `tex_grass_flowers_01.png`, `prop_tree_oak_02.png`, `sky_cliffs_sunset.png`.

### 17.10 Checklist de aprovação de cada asset

- [ ] Usa apenas cores da paleta mestra
- [ ] Contorno de 1 px colorido, sem preto puro
- [ ] Luz vindo de cima-esquerda
- [ ] Tamanho de quadro e ponto de origem corretos
- [ ] Proporções iguais em todas as direções
- [ ] Animação faz loop sem "pulo"
- [ ] Silhueta legível a 1x no tamanho real do jogo
- [ ] Fundo transparente, sem pixels semitransparentes soltos
- [ ] Nada que lembre personagens ou marcas existentes
- [ ] Prompt, ferramenta e seed registrados em `/assets/_reference/`
- [ ] Termos de uso da ferramenta de IA permitem uso comercial

### 17.11 Cenários "dignos de print"

- Mapas são **geometria 3D simples** (terreno + blocos de baixa contagem de polígonos) com **texturas pixel art** a 32 px/unidade. Vegetação pequena, flores e detalhes: sprites billboard.
- Priorizar composição: pontos altos com vista, silhuetas no horizonte, água, contraste de luz.
- Luz direcional quente + ambiente frio; névoa volumétrica leve em distância; partículas (pólen, folhas, faíscas).
- Cada mapa tem ao menos **3 "pontos de vista"** planejados, com um banco ou mirante onde o jogador pode sentar (animação `sit`) e tirar foto.
- Modo foto `[PROVISÓRIO]`: tecla/botão que esconde a interface.

---

## 18. Áudio `[PROVISÓRIO]`

- Música: 1 faixa por mapa (cidade calma, campos leves, floresta misteriosa, penhascos épicos e melancólicos, arena tensa) + tema do chefe + tema da tela de título. Loops de 2 a 3 minutos.
- Efeitos: passos (grama, pedra, madeira), golpe, conjurar, cada skill, acerto, crítico, receber dano, morrer, subir de nível, aprender skill, pegar item, abrir interface, chat, Marca da Alma aparecendo.
- Verificar licença de qualquer música ou efeito (próprio, gerado com licença comercial ou CC0).

---

## 19. Plano de desenvolvimento

Estimativa para 1 desenvolvedor com 10 a 15 h por semana usando agentes de IA: **6 a 9 meses até o playtest fechado**. Cada fase só termina quando o critério de pronto é atendido.

| Fase | Conteúdo | Critério de pronto |
|---|---|---|
| 1. Protótipo técnico | Câmera 2.5D, personagem billboard em 8 direções, movimento por clique, servidor headless, 2 clientes se vendo | Dois jogadores andando na mesma cena, vendo um ao outro, com direções corretas ao girar a câmera |
| 2. Base online | API de contas, banco, criação de personagem, persistência, grupos, instâncias, troca de mapa, chat | Jogadores em grupos diferentes no mesmo mapa de caça não se veem; na cidade todos se veem; progresso salvo após reiniciar o servidor |
| 3. Combate e mundo | Monstros e IA, ataque, drops, inventário, equipamento, morte, Marca da Alma, mapa PVP | Loop completo: caçar, pegar drop, equipar, morrer, recuperar túmulo em outra instância |
| 4. Progressão | Níveis, atributos, 10 skills, progressão de skill, barra de atalhos, 10 quests, Mestres, tutorial | Um jogador novo chega do nível 1 ao 25 aprendendo skills só por quests |
| 5. Mobile, deploy e polimento | Interface de toque, build Android, VPS com Docker, backups, métricas, chefe | 20 testadores simultâneos (PC e Android) por 2 horas sem queda do servidor |

Paralelamente, desde a fase 1: produção de arte seguindo a seção 17, **começando obrigatoriamente pelas 5 imagens-âncora (17.0)**. Arte provisória é aceitável até a fase 4.

---

## 20. Decisões em aberto

| # | Tema | Opções | Padrão implementado até decidir |
|---|---|---|---|
| 1 | Skill sobe de nível por… | uso / pontos | uso |
| 2 | Limite de skills | barra de 8 / escolas opostas / limite de maestria | barra de 8 |
| 3 | Morrer com túmulo pendente | túmulo anterior some / acumulam | acumulam |
| 4 | Proteção de itens | vínculo de alma / amuleto / proteção de iniciante / desgaste | nenhuma (só infraestrutura) |
| 5 | Saída do líder | liderança passa, instância continua / instância fecha | liderança passa após 3 min |
| 6 | Nome do jogo e do mundo | — | "Projeto Isekai" |
| 7 | Paleta mestra | paleta própria ou ajustes após as âncoras | paleta própria de 50 cores (`paleta-mestra.gpl`) |
| 8 | Ordem das próximas regiões | tabela da seção 4.0 | Brasil no MVP; demais depois |

Ao ser tomada uma decisão, atualizar esta tabela, trocar a marcação da seção correspondente para `[FECHADO]` e registrar a data.

---

## 21. Referências de mercado

- **Ravendawn:** MMO pixel art indie, lançado em janeiro de 2024, passou de 200 mil usuários ativos mensais; sem classes fixas (três arquétipos combinados) e monetização sem impacto no equilíbrio. Prova que o formato tem público.
- **Old School RuneScape — Leagues e Deadman Mode:** temporadas com recomeço do zero trazem jogadores de volta; o risco de perder itens funciona melhor como escolha (servidor/área específica). Base para as futuras temporadas e para a regra do mapa PVP.
- **Brighter Shores:** pico de cerca de 20 mil jogadores simultâneos no lançamento e queda para cerca de 2 mil em semanas. Lição: medir retenção no MVP antes de crescer; acertos a copiar: quests de exploração e resposta rápida ao feedback.
- **Samsara Saga:** RPG online 2.5D em pixel art, feito por equipe no tempo livre, com foco social e economia de jogadores. Referência de divulgação: clipes curtos de devlog, Discord e newsletter antes dos playtests. Diferenças: eles têm classes e são só PC.

---

- **Ragnarok Online:** referência de *sensação* (seção 17.0.1): sprites anime sobre cenários 3D, cores alegres, cidades com sabores culturais, chapéus como expressão do jogador. Nada é copiado.

---

*Fim do documento. Em caso de conflito entre este arquivo e qualquer outra instrução, perguntar ao dono do projeto.*
