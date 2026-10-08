# Perdidos — Game Design Document e Especificação Técnica

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
4. **Social por natureza:** mapas compartilhados, grupos com XP dividida e posse de drop, resgate entre amigos.
5. **Mundo bonito:** mapas pensados para serem "dignos de print".
6. **Justo com todos:** dinheiro compra aparência, nunca poder.

---

## 3. Escopo do MVP

O MVP existe para responder uma pergunta: **o loop principal é divertido a ponto de as pessoas voltarem?** Tudo que não ajuda a responder isso fica para depois.

### 3.1 Dentro do MVP

- 1 cidade (mapa compartilhado)
- 3 mapas de caça (compartilhados por todos; seção 5), sendo 1 deles o mapa vitrine "digno de print"
- 1 mapa PVP pequeno (compartilhado)
- Nível de personagem e nível de skill
- 2 escolas de habilidades com 5 skills cada (seção 8)
- Quests de aprendizado com Mestres (seção 9)
- 6 tipos de monstros comuns + 1 chefe (seção 10)
- Inventário, equipamento e drops
- Sistema de morte com túmulo (Marca da Alma)
- Grupos (até 5, XP dividida, posse de drop; seção 5), chat (mapa, grupo, sussurro)
- Contas, login, persistência completa
- Interface para mouse/teclado e para toque
- Servidor dedicado hospedado em São Paulo

### 3.2 Fora do MVP (não implementar agora)

- Comércio entre jogadores, lojas de jogadores, leilão
- Guildas
- Loja de cosméticos, passe de batalha, temporadas
- Crafting e profissões
- Clima com efeito em gameplay (o ciclo dia/noite entrou no escopo, ver §10.7)
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
3. **Religiões vivas — em todos os idiomas** `[FECHADO, reforçado em 27/09/2026]`. Divindades, figuras sagradas, santos, profetas, orixás, espíritos cultuados e termos litúrgicos de **qualquer religião praticada hoje** (tradições indígenas, afro-brasileiras, cristãs, islâmicas, judaicas, hindus, budistas, xintoístas, pagãs contemporâneas e outras) **não viram** nome de título, skill, item, monstro, NPC ou lugar, nem monstros a serem mortos nem piada. Preferir criaturas do folclore, espíritos da natureza e heróis lendários; figuras sagradas podem, no máximo, ser referências respeitosas no cenário.
   - Vale para **todos os idiomas** do jogo: cada nome é revisado também no idioma de destino (um nome inofensivo em português pode ser sagrado ou ofensivo em outra língua). Nomes podem ser **adaptados** na tradução, não só transliterados.
   - Processo: lista de termos sensíveis em `game/data/cultural/sensitive_terms.txt`, checagem automática (`make check-names`) sobre todas as traduções e documentos de conteúdo, e revisão humana por idioma antes de cada lançamento (guia em `docs/cultural/revisao-cultural.md`).
4. **Tragédias reais** (escravidão, genocídios, guerras recentes) não viram inimigos, chefes ou humor.
5. **Ficha da região:** antes de produzir conteúdo, criar uma ficha em `data/regions/{pais}.md` com país de inspiração, lendas usadas e suas fontes, arquitetura de referência, paleta regional (subconjunto da paleta mestra), clima musical, monstros, chefe, Mestres, skills e armas típicas.

**Planejamento de regiões `[PROVISÓRIO]`:**

| Região | Inspiração | Lendas e elementos | Chefe possível | Armas típicas |
|---|---|---|---|---|
| **Terra de Pindorama (MVP)** | Brasil | Saci, Curupira, Boitatá, Iara, Mula sem Cabeça, Lobisomem, Corpo-Seco, Mapinguari | Boitatá | facão, borduna, bodoque |
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

### 4.0.1 Mapa-múndi, masmorras e mistérios `[FECHADO em 27/09/2026: existe; PROVISÓRIO: nomes e posições]`

- **Mapa-múndi (tecla M):** mapa ilustrado no estilo **medieval fantasia** (pergaminho, rosa dos ventos, bordas decoradas, **desenhos de supostos monstros** nos mares e ermos, que podem ou não existir no jogo), com **todas as regiões, cidades, campos e masmorras** — mesmo as que ainda não estão abertas (marcadas como "terras ainda não alcançadas"). Nomes de lugares **chamativos e fáceis de lembrar**, sobrepostos pela engine (traduzíveis), nunca escritos na arte.
- **Masmorras** baseadas no **folclore** de cada região e algumas em **mistérios e "teorias"** populares (viagem no tempo, visitantes das estrelas, civilizações perdidas).
- **Regra para os mistérios (cultural, obrigatória):** monumentos e feitos dos povos (pirâmides, cidades maias etc.) são **sempre obra desses povos**. O estranho vem de **Viajantes perdidos de outras épocas e de outros mundos** que caíram aqui pela Florada antes do jogador — uma máquina do tempo enferrujada, a cápsula de um astronauta, uma nave encalhada — cujas ruínas e tecnologia viraram masmorras. Nada de "alienígenas construíram X" nem de retratar povos vivos como incapazes ou primitivos.
- Dados do mapa em `data/world/` (regiões, lugares, tipo, faixa de nível recomendada, estado aberto/fechado); documento de design em `docs/mundo/atlas.md`.

### 4.1 Tipos de mapa `[FECHADO]`

| Tipo | Instância | Quem se vê | Regras |
|---|---|---|---|
| **Cidade** | Uma única, compartilhada | Todos | Sem combate. Mestres básicos, loja de NPC, armazém |
| **Caça** | Uma única, compartilhada (desde 30/09/2026) | Todos | Monstros e drops são do mapa; disputa justa pela seção 5.2 (dono = maior dano; drop do dono e do grupo por 10 s) |
| **PVP** | Uma única, compartilhada | Todos | Combate livre entre jogadores; quem mata pode saquear o equipamento caído |

Sem cópia por grupo: o grupo divide XP, crédito e drops (seção 5).

### 4.2 Mapas do MVP — região Terra de Pindorama (Brasil) `[PROVISÓRIO — nomes podem mudar]`

Fantasia medieval com alma brasileira: muros caiados, telhados de telha, azulejos, janelas coloridas, feiras cheias de frutas, ipês floridos, rios largos e matas densas.

**Cidade — "Porto do Despertar"**
Cidade portuária à beira de um grande rio, onde os Viajantes costumam aparecer. Praça central com um grande cristal (ponto de renascimento) sob um ipê amarelo gigante, casario colonial-medieval colorido, feira de frutas e ervas, docas com barcos de vela, casa dos Mestres, portões para os mapas de caça e para a arena. Tamanho aproximado: 120 x 120 unidades.

**Caça 1 — "Campos de Pindorama"** (nível 1 a 10)
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

> **Decisão do dono em 30/09/2026:** "Vamos remover o esquema de instância e pôr o recurso de grupo, tanto na UI quanto usando o chat /grupo nome." Esta seção substitui a regra antiga de instância por grupo (`map_id:party_id`, instância do líder, `solo_<id>` para quem jogava sozinho).

### 5.1 Regra de instância: um mapa, uma instância `[FECHADO em 30/09/2026]`

- **Todo mapa tem uma instância só**, compartilhada por todos: `instance_id = map_id` (ex.: `"fields_pindorama"`). Vale para cidade, Campo de Treino, mapas de caça (Campos, Mata, Chapada e os que vierem) e PVP.
- Todos os jogadores do mesmo mapa se veem. Monstros, drops e chefes são os mesmos para todos.
- O grupo **não** cria cópia de mapa. Ele serve para dividir XP e crédito de abate, para a posse dos drops, para as skills de suporte e para o chat do grupo (5.2–5.5).

### 5.2 Disputa justa (estilo Ragnarok) `[FECHADO em 30/09/2026: regra; PROVISÓRIO: números]`

- **Dono do monstro:** quem causou **mais dano** nele (empate: quem bateu por último). Se o monstro volta para casa e recupera a vida, o placar de dano zera.
- **XP:** vai para o dono e para os membros do grupo dele que estão **vivos, no mesmo mapa e perto** do monstro (`party_share_range_cells`, 30 células). Cada um recebe `XP_total * (1 + 0.1 * (membros - 1)) / membros` (bônus em `party_xp_bonus_per_member`).
- **Crédito de quest** (derrotar X): o dono e os mesmos membros do grupo por perto. A regra "sem cair" das quests dos anciãos vale para cada um.
- **Drop:** pertence ao dono e ao grupo dele por **10 s** (`drop_owner_sec`); depois fica livre para qualquer um. Quem tenta pegar antes recebe "Esse item não é seu".
- **Estrelas** do monstro vão para o dono.
- **Provações** (Campo de Treino, lições e anciãos): os monstros e fantoches que nascem para a provação de um jogador **só atacam e só podem ser atacados por ele e pelo grupo dele**, mesmo no mapa compartilhado. Outro jogador que tenta atacar recebe "Esse monstro é da provação de outro jogador" e o monstro não o ataca. A provação só fecha com o monstro dela (outro do mesmo tipo derrubado no mapa não conta).
- **Pendência:** as provações dos anciãos no Porto não funcionam porque o Porto não tem combate. Espera decisão do dono.

### 5.3 Grupo `[FECHADO em 30/09/2026: regra; PROVISÓRIO: números]`

- Até **5** jogadores (`party_max_size`).
- **Só o líder** convida, expulsa e passa a liderança. Quem está sem grupo pode convidar; quando o convidado aceita, o grupo nasce com quem convidou como líder.
- O convite vale **60 s** (`party_invite_timeout_sec`); um jogador só tem um convite pendente por vez; quem convida espera **3 s** entre convites (`party_invite_cooldown_sec`).
- **Líder que desconecta:** tem **3 minutos** de tolerância (`leader_reconnect_grace_sec`). Se não voltar, ou se sair do grupo, a liderança passa ao **membro mais antigo** que estiver online.
- **O grupo some quando sobra 1.**
- Quem cai e volta continua no grupo enquanto o servidor estiver ligado. O grupo **não** é salvo em disco (não sobrevive a reinício do servidor).
- **Aliados:** nas skills de suporte (cura, escudo, reforço, mana) contam o próprio jogador, os membros do grupo dele e os protegidos da provação dele ou do grupo. Jogadores fora do grupo não recebem.

### 5.4 Comandos e interface `[FECHADO em 30/09/2026]`

| Chat | O que faz |
|---|---|
| `/grupo <nome>` | Convida o jogador pelo nome, em qualquer mapa |
| `/grupo aceitar` / `/grupo recusar` | Responde ao convite pendente |
| `/grupo sair` | Sai do grupo |
| `/grupo expulsar <nome>` | Tira o membro (só o líder) |
| `/grupo líder <nome>` | Passa a liderança (só o líder) |
| `/grupo` | Lista os membros (nível e mapa) |
| `/g <mensagem>` | Fala só com o grupo, em qualquer mapa |
| `/online` | Lista quem está conectado, o mapa e o nível (liberado no beta; `online_list_public` restringe) |

Erros com mensagem clara: jogador não encontrado, já tem grupo, grupo cheio, só o líder pode, sem convite, convite pendente, rápido demais.

Interface:
- **Painel do grupo** na lateral esquerda, abaixo das barras de vida e mana: nome, nível, vida e mana de cada membro, **coroa no líder**, o **mapa** do membro quando ele está em outro mapa (ou "desconectado"). Botão **Sair do grupo**.
- **Convite** em janela com **Aceitar** e **Recusar** e a contagem do tempo.
- **Clique** (esquerdo ou direito) em outro jogador abre o menu com **Convidar para o grupo**; no painel, o líder clica num membro para **Passar a liderança** ou **Expulsar**.
- **Chat** com abas **Todos** e **Grupo**; na aba Grupo o que se digita vai para o grupo.
- O nome dos membros sobre a cabeça fica na cor do grupo.

### 5.5 Ciclo de vida da instância

- A instância de cada mapa nasce quando o primeiro jogador entra (a cidade existe desde que o servidor liga) e não é destruída no MVP. Monstros e drops no chão pertencem a ela. Túmulos **não** (seção 12).

### 5.6 Implementação obrigatória

- Toda a filtragem e todas as regras acontecem **no servidor**. O servidor nunca envia estado de entidades de outra instância ao cliente (evita trapaça). A filtragem por `instance_id` continua (`MultiplayerSynchronizer.public_visibility = false` + filtro de visibilidade), agora por mapa.
- Monstros, drops e projéteis pertencem à instância do mapa.
- Convites, limites, líder e spam são validados no `PartyService` do servidor; cada recusa vai para o log (`Net.log_invalid`). O chat do grupo respeita o bloqueio de chat da moderação e o limite de 1 mensagem por segundo; os comandos de grupo não são mensagem e não passam por esses limites.
- Contratos de rede: `docs/contracts-city-walk.md`, ADENDO 6 (NetParty).

---

## 6. Personagem

### 6.1 Criação e personalização `[FECHADO: existe personalização; PROVISÓRIO: quantidades]` (atualizado em 27/09/2026)

- Nome (3 a 16 caracteres, único no servidor)
- Corpo: masculino ou feminino
- **Tom de pele:** 6 opções
- **Cabelo:** estilos × **10 cores** (uma única arte por estilo, colorida por shader — seção 17.4). MVP: **4 estilos por corpo**; meta do GDD: 8.
- **Cor dos olhos:** 6 opções
- **Acessórios de rosto:** brincos (nenhum, argola, pingente de semente, pena), e depois outros (sardas, pintas, óculos redondos, fitas de cabelo). MVP: **brincos com 3 modelos + nenhum**.
- Roupa inicial: 3 variações de "roupa de Viajante" (roupas modernas simples: moletom, camiseta, jaqueta — reforça o isekai)

Técnica (seção 17.4): o personagem é montado em camadas — **corpo-base** (cabelo raspado, pele e olhos em máscaras recoloríveis) + **cabelo** + **acessórios de rosto** + roupa/equipamento. As escolhas ficam em `characters.appearance` (JSON) e são replicadas a todos pela aparência da entidade. Opções de personalização obtidas jogando ou como cosmético pago no futuro seguem a seção 14 (só visual).

### 6.2 Atributos `[FECHADO: pontos por nível, cada atributo melhora coisas específicas; PROVISÓRIO: nomes e números]` (reforçado em 27/09/2026)

Ao subir de nível o jogador ganha **pontos de atributo** e escolhe onde colocar; cada atributo aumenta coisas específicas (vida, resistência a dano, crítico, velocidade de ataque, mana etc.). Nomes e efeitos próprios deste jogo (não copiar os de Ragnarok):

| Atributo | Sigla | Efeito |
|---|---|---|
| Força | FOR | Dano físico **das armas corpo a corpo e sem arma** (facão, espada), capacidade de carga |
| Destreza | DES | **Velocidade de ataque**, **esquiva** e **chance de acerto** (atualizado em 27/09/2026); **dano do arco** (30/09/2026) |
| Vitalidade | VIT | **Vida máxima**, **resistência a dano físico**, regeneração de vida |
| Intelecto | INT | Dano mágico, **mana máxima**; ATQ das **armas arcanas** (cajado, varinha, tomo) (30/09/2026) |
| Espírito | ESP | Regeneração de mana, **resistência a dano mágico**, redução de recarga |
| Sorte | SOR | **Chance de crítico**, **chance de drop** de itens e chance de encontrar **monstros raros** (novo em 27/09/2026) |

- Todos começam com 5 em cada.
- **3 pontos de atributo** por nível de personagem, distribuídos livremente.
- **Atributo da arma** (regra do dono, 30/09/2026): cada arma escala com o atributo ligado a ela (`ItemDef.scaling_attribute`, em dados). `ATQ = bônus de ATQ dos itens + atributo da arma × 2 + nível`; o MATQ continua `INT × 2 + nível + bônus`.

  | Arma | Atributo do ATQ | Ataque básico |
  |---|---|---|
  | Sem arma, facão, espada e demais corpo a corpo | FOR | físico, corpo a corpo (usa o ATQ) |
  | Arco (`simple_bow`) | DES | físico, à distância (8 células; usa o ATQ) |
  | Cajado, varinha (e tomo, na mão secundária) | INT | **mágico** à distância (usa o MATQ, que já vem de INT); o ATQ também vem de INT, para as skills físicas usadas com essas armas |

  Skills físicas usam o ATQ da arma equipada (as da escola do arco exigem arco, logo escalam com DES); magias usam o MATQ. Só a arma da mão principal decide o atributo. As janelas de atributos e de equipamento mostram o ATQ que o servidor calculou e o atributo usado.
- Redistribuição: não existe no MVP.

### 6.3 Nível de personagem `[FECHADO: existe; PROVISÓRIO: números]`

- Nível máximo no MVP: **25**.
- Ganho de XP: derrotar monstros e completar quests.
- XP necessária para o próximo nível: `floor(100 * nivel^1.6)`.
- XP dividida no grupo: o dono do monstro (maior dano) e cada membro do grupo dele vivo, no mesmo mapa e perto (30 células) recebem `XP_total * (1 + 0.1 * (membros - 1)) / membros` (seção 5.2; números em `balance_config`).
- Nível de personagem **não ensina habilidades** e **não é requisito de quests**; dá pontos de atributo e de skill.

### 6.4 Valores derivados `[PROVISÓRIO]`

- Vida máxima = `100 + VIT * 12 + nivel * 8`
- Mana máxima = `50 + INT * 8 + nivel * 4`
- Regeneração de vida (fora de combate, por 5 s) = `2 + VIT * 0.5`
- Regeneração de mana (por 5 s) = `1 + ESP * 0.6`
- "Fora de combate" = 6 segundos sem causar ou receber dano.

---

## 7. Visão geral da progressão `[FECHADO]`

Três camadas independentes:

1. **Nível do personagem** — sobe com XP de monstros e quests. Dá **3 pontos de atributo e 1 ponto de skill** por nível. **Não é requisito de quests** (seção 8.4).
2. **Nível da skill** — cada skill evolui individualmente com os pontos de skill e fica mais forte.
3. **Conquistar título e aprender skills** — a quest de conquista concede o título e as cinco skills da árvore no nível 1. Títulos de ramo também concedem as árvores ancestrais. Nenhum nível, item ou compra concede título ou skill.

Quanto mais o jogador se aprofunda numa escola, mais quests daquela escola ficam disponíveis. Não existem classes: um jogador pode conhecer skills de todas as escolas.

---

## 8. Escolas e skills

### 8.1 Regras gerais

- **Nível máximo de skill:** 10 `[PROVISÓRIO]`.
- **Conquistar árvore: somente por quest de título** `[FECHADO]`. Ao obter o título, o personagem recebe as cinco skills da árvore no nível 1; ramos incluem árvores ancestrais. Nenhuma skill ou título é aprendido por nível.
- **Como a skill sobe de nível** `[FECHADO em 27/09/2026]`: por **pontos de skill**. O personagem ganha **1 ponto de skill por nível** e o coloca em qualquer skill que já conheça (até o nível máximo dela). Lógica isolada no módulo `SkillProgression`.
- **Barra de atalhos** `[FECHADO em 27/09/2026]`: a barra tradicional com **10 espaços, teclas 1 a 0**.
- **Tempo de uso na barra** `[FECHADO em 28/09/2026; PROVISÓRIO: números]`: a barra é **animada** — cada espaço mostra a conjuração (barra enchendo), a recarga (sombra girando com segundos) e um brilho quando fica pronto.
  - **Poções de vida e de mana não têm tempo**: uso instantâneo, sem conjuração e sem recarga (substitui a recarga compartilhada de 10 s do §11.3).
  - **Todo o resto tem tempo** (skills e demais usáveis): conjuração e recarga.
  - **Nível da skill:** quanto **menor** o nível da skill, **mais rápida** a conjuração; a skill evoluída fica mais forte e um pouco mais lenta: `conjuração = base × (1 + 0,06 × (nível_skill − 1))`.
  - **Atributos reduzem a conjuração:** `× (1 − min(DES × 0,5% + INT × 0,3%, 50%))`.
  - **Itens reduzem a conjuração:** atributo de item `cast_reduction` (%), somado dos itens equipados, limite total de 60% junto com os atributos.
  - **Recarga:** reduzida pelo Espírito (§6.2) e por itens com `cooldown_reduction`: `recarga = base × (1 − min(ESP × 0,4% + cooldown_reduction dos itens, 40%))`. A recarga começa quando a conjuração termina.
  - **Interrupção:** andar ou ser atordoado durante a conjuração a interrompe (a mana gasta não volta; a recarga não começa). Todos da instância veem a conjuração (barrinha sobre a cabeça).
  - Números no `Balance` (grupo "Cast & cooldown"); fórmulas em `CastTiming` (implementado em 28/09/2026).
 O jogador pode conhecer quantas skills quiser, mas só usa as que estão na barra. Trocar skills da barra só fora de combate.
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

### 8.4 Requisitos de aprendizado `[PROVISÓRIO]`

**Quests não exigem nível de personagem** `[FECHADO em 27/09/2026]`. A coluna "Nível" das tabelas 8.2 e 8.3 passa a ser só a **faixa recomendada** (onde ficam os monstros e itens da quest). As áreas podem ser perigosas para um personagem de nível baixo, mas **nada é bloqueado por nível**: é um MMO de espírito *soulslike*, o risco é do jogador.

Não há quests individuais por skill. A quest de título confere seus requisitos de conhecimento e concede a árvore de cinco skills no nível 1. Pré-requisitos da árvore continuam valendo para subir níveis com pontos de skill. Nenhuma quest exige nível de personagem.

### 8.5 Títulos `[FECHADO: existem e funcionam assim; PROVISÓRIO: lista]` (27/09/2026)

Não existem classes, mas o caminho do jogador é reconhecido por **títulos**:
- Cada título é **conquistado por uma quest própria**; aprender skills não concede título automaticamente. A quest concede também as cinco skills da árvore no nível 1 (e as árvores ancestrais nos ramos).
- Um título **desbloqueia coisas específicas**: quests de outros títulos, e no futuro itens, cosméticos e diálogos próprios.
- Um personagem pode ter **vários títulos ao mesmo tempo** (generalistas acumulam títulos de escolas diferentes); escolhe um para exibir sob o nome.
- Títulos combinados (skills de mais de uma escola) podem liberar caminhos híbridos.
- **Títulos são regionais** `[FECHADO em 27/09/2026]`: o nome vem da cultura da região onde o título é conquistado (ex.: no reino inspirado no Japão, títulos como ninja e samurai; na Terra de Pindorama, nomes de origem tupi e do folclore brasileiro). Um arqueiro da Terra de Pindorama tem **skills diferentes** de um arqueiro de outra nação.
- **Títulos evoluem em ramos:** o primeiro título de um caminho numa região abre **ramificações** (ex.: arqueiro da Terra de Pindorama → ramo de camuflagem e emboscada **ou** ramo de tiro certeiro), cada uma com suas skills exclusivas. Quem tem o título pode buscar as evoluções; nenhuma exige nível.
- **Nomes seguem as regras culturais (§4.0):** conferidos em fontes do próprio povo (ex.: dicionários de tupi antigo); **nomes próprios de divindades de religiões vivas não viram títulos** (ex.: Tupã, Nhanderu, Rudá, Guaraci, Jaci como entidades) — usar palavras descritivas (sol, lua, trovão, gavião, flecha).
- A lista de títulos, as skills que concedem cada um e as skills exclusivas de cada título ficam no documento **`TITULOS-E-SKILLS.md`** (raiz do projeto) e depois em dados (`data/titles/*.tres`).

---

## 9. Quests de aprendizado

### 9.1 Regras `[FECHADO: títulos e árvores por quest; PROVISÓRIO: formato]`

- Quests são dadas por **Mestres** (NPCs). Mestres básicos ficam na cidade ou no mapa inicial; os avançados ficam escondidos em mapas perigosos.
- Quests de título devem ter objetivos graduais (abates, coleta de itens, exploração e provações). Cada título já conquistado, exceto Viajante, aumenta globalmente os requisitos das próximas quests: +1 abate comum por título anterior; coletas aumentam à metade desse ritmo, arredondada para cima. A meta fica fixa ao aceitar a quest.
- Devem ser simples, mas com algum desafio. Duração alvo: 5 a 20 minutos cada.
- Cada quest tem de 1 a 3 etapas, usando estes tipos de objetivo: **derrotar** (X monstros de um tipo), **coletar** (itens que caem de monstros), **explorar** (chegar a um ponto do mapa), **entregar/conversar**, **provação** (desafio de combate contra um oponente controlado pelo Mestre; no mapa compartilhado o oponente só luta com o jogador e o grupo dele — seção 5.2).
- O NPC mostra requisitos que faltam ("Volte quando conhecer 2 técnicas da Lâmina").
- Quests podem ser feitas em grupo; o abate conta para o dono do monstro e para os membros do grupo dele vivos no mesmo mapa e perto (seção 5.2). Coletar conta para quem pega o item.

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

### 9.3 Chegada do Viajante: cinemática e área de tutorial `[FECHADO: existem; PROVISÓRIO: roteiro e mapa]` (atualizado em 27/09/2026)

**Cinemática da travessia.** Toca uma vez, logo depois de criar o personagem (e pode ser revista nas configurações). Mostra o Viajante no mundo moderno, o evento misterioso e a queda no mundo de fantasia, terminando com ele acordando.
- 40 a 60 s, **pulável** (Esc/clique), legendas por chave de tradução, música e efeitos próprios.
- Feita **dentro da engine** como sequência de ilustrações em pixel art (pan/zoom, camadas, partículas, texto), não como arquivo de vídeo: assim o texto é traduzível e a arte segue a âncora de estilo.

**Campo de Treino dos Viajantes — área inicial** `[FECHADO em 27/09/2026: regras; PROVISÓRIO: mapa e números]`

Depois da cinemática o Viajante **não cai direto na cidade**: ele acorda no **Campo de Treino**, uma área grande onde aprende a jogar e conhece os Mestres de todas as nações.
- **Nível 1 a 10.** O jogador sobe até o **nível 10** ali. Ao chegar no 10, **não ganha mais XP** nessa área.
- **Itens da área somem ao sair.** Tudo o que for obtido no Campo de Treino (drops, equipamentos, consumíveis) é marcado como "do treino" e **desaparece quando o jogador vai para a cidade**. Nível, atributos, skills e título ficam.
- **Um Mestre de cada nação** espalhado pela área, cada um no seu canto com o clima da sua região (arquitetura, vegetação, monstros).
- **Monstros iniciais de todas as regiões**, cada grupo perto do Mestre da sua nação. Servem para aprender o combate e conhecer o estilo de cada região. Têm formas normal e média (seção 10.6); não há evolução nem chefe ali.
- **Mestres no nível 10** `[novo em 27/09/2026]`: ao chegar ao nível 10, **cada Mestre ganha uma opção de conversa sobre o título que ele passa** (o que é, estilo de jogo, skills que libera, cidade inicial), para o jogador escolher com informação.
- **Uma quest de título.** No Campo de Treino o jogador pode fazer **uma** quest de título com um dos Mestres. O **título inicial define a cidade onde ele começa**: título de um Mestre da Terra de Pindorama → começa no Porto do Despertar; de outra nação → começa na cidade daquela nação.
- **Saída:** quando quiser (depois de conquistar o título inicial), o jogador atravessa o portal/ponte do Campo e vai para a cidade do seu título. Não há volta ao Campo de Treino com o mesmo personagem.
- Ensina, ao longo do caminho: **comandos básicos** (andar, câmera, minimapa, falar), **itens** (pegar, inventário, equipar, poção), **combate** (ataque, alvo, barra 1 a 0, primeira skill do título), **pontos** de atributo e de skill, **morte e Marca da Alma** (explicada), e a **lore** (seção 1.2 e `docs/lore/`).
- Instância: **uma só, compartilhada** por todos os novatos (decisão do dono em 30/09/2026): todos se veem e os monstros são os mesmos para todos, com a disputa justa da seção 5.2. As provações continuam individuais (o monstro da provação só luta com o dono e o grupo dele).

**Padrões para implementar agora `[EM ABERTO]`:**
- **MVP:** só a Terra de Pindorama existe como cidade. Os Mestres e monstros das outras nações aparecem no Campo (para o mundo parecer grande), mas **só as quests de título da Terra de Pindorama** ficam jogáveis; os outros Mestres dizem que "a travessia para a terra deles ainda não está aberta".
- Morte no Campo de Treino: renasce no acampamento central, **sem Marca da Alma** (não há equipamento permanente a perder).
- Monstros do Campo vão só até o estágio 2 (médio); o estágio 3 (chefe com bando) mora nos covis fixos da Chapada (seção 10.6.1).

### 9.5 Tela e interface `[FECHADO em 27/09/2026]`
- **O jogo ocupa a janela inteira**; interface desenhada **por cima** do mundo, sem faixas cinzas.
- **Botões de menu agrupados numa engrenagem** (os atalhos de teclado continuam), liberando espaço na tela.

### 9.4 Minimapa `[FECHADO em 27/09/2026]`
Minimapa no canto superior direito, no estilo dos MMOs clássicos: imagem do mapa vista de cima, posição e direção do jogador, membros do grupo, NPCs importantes (Mestres, loja, portais), a própria Marca da Alma com tempo restante (seção 12.2). Alterna entre tamanhos e um mapa grande em tela cheia (tecla configurável). Gira junto com a câmera ou fica fixo com o norte para cima (opção).

---

## 10. Combate, monstros e drops

### 10.1 Controles `[FECHADO: clique para atacar; FECHADO em 27/09/2026: movimento clássico por células]`

**Mecânica de movimento — igual à dos MMOs clássicos em células (referência direta: Ragnarok Online; mecânica não é propriedade intelectual, só os assets são).**
- O chão de cada mapa é uma **grade de células** (`cell_size` `[PROVISÓRIO]`). Uma célula é andável ou não.
- Clicar numa célula calcula um caminho **A\* em 8 direções** pela grade. O personagem anda de célula em célula, em velocidade constante, sem aceleração nem desaceleração.
- **Velocidade em milissegundos por célula** (`walk_ms_per_cell` `[PROVISÓRIO]`); passo diagonal custa ×1,4.
- A direção do sprite é a direção do passo atual (sempre uma das 8), sem tremer.
- **Segurar o botão** faz o personagem seguir o cursor continuamente.
- O servidor valida e devolve o caminho com o instante de início; **todos os clientes reproduzem o mesmo caminho** a partir desse instante (sem atraso artificial de interpolação para o movimento).
- A animação de andar é sincronizada com a velocidade (um ciclo de passos a cada 2 células).
- NPCs e monstros usam exatamente o mesmo sistema.


**PC:**
- Clique esquerdo no chão: mover (pathfinding).
- Clique esquerdo em inimigo: mover até o alcance e atacar automaticamente em ciclo até o alvo morrer ou o jogador dar outra ordem.
- Teclas 1 a 0 (10 espaços): skills da barra. Skills de alvo usam o alvo atual; skills de área pedem um clique no chão (com pré-visualização da área).
- Clique direito arrastando ou Q/E: girar câmera. Roda do mouse: zoom (limitado).

**Mobile:**
- Toque no chão: mover. Toque no inimigo: selecionar e atacar.
- Botões de skill no canto inferior direito (10 botões em arco, grandes o bastante para dedo: mínimo 56 dp).
- Skills de área: tocar no botão entra no modo de mira; tocar no chão confirma.
- Dois dedos arrastando: girar câmera. Pinça: zoom.
- Toda a interface deve ser utilizável em uma tela de 6 polegadas em modo paisagem.

### 10.2 Fórmulas `[PROVISÓRIO]`

- `ATK = ataque_da_arma + FOR * 2 + nivel`
- `MATK = poder_magico_da_arma + INT * 2 + nivel`
- `DEF = soma_def_equipamento + VIT * 1`
- `MDEF = soma_mdef_equipamento + ESP * 1`
- Dano físico = `ATK * multiplicador * (100 / (100 + DEF_alvo))`
- Dano mágico = `MATK * multiplicador * (100 / (100 + MDEF_alvo))`
- Variação aleatória: ±10%.
- Crítico (só físico): chance = `5% + SOR * 0,3%`, dano x1,5 `[atualizado: crítico vem da Sorte]`.
- **Acerto e esquiva** `[novo em 27/09/2026, PROVISÓRIO]`: chance de acerto = `clamp(80% + (DES_atacante - DES_alvo) * 1%, 50%, 95%)`; ataque errado mostra "Errou". Skills mágicas sempre acertam.
- **Drop:** chance final = `chance_da_tabela * (1 + SOR * 0,01)` `[PROVISÓRIO]`.
- **Monstros raros** `[novo em 27/09/2026, PROVISÓRIO]`: ao renascer, um monstro tem chance de surgir como variante rara (visual diferente, mais forte, drops melhores). Chance base 1%, multiplicada por `1 + SOR * 0,02` do jogador mais próximo com sorte mais alta.
- Velocidade de ataque básico: `1,0 + DES * 0,01` ataques por segundo, máximo 2,5.
- ~~Precisão/esquiva: não existe no MVP~~ — substituído pela regra de acerto e esquiva acima.

### 10.2.1 Combate vivo `[FECHADO em 27/09/2026]`
- Ataques têm **movimento** (o personagem avança um passo curto no golpe e recua; o alvo sofre um leve empurrão/tremida).
- **Animações de ataque armado e desarmado** para os personagens (desarmado = socos/chutes; armado = por tipo de arma: lâmina, cajado), nas 5 direções.
- **Som** em todo golpe, acerto, crítico, erro e morte (catálogo em `game/tools/audio/sound_catalog.json`).
- **Cada arma e cada skill têm o próprio som** (balanço e acerto por arma; lançamento e impacto por skill), e **cada monstro tem o próprio som** de ataque, dano e morte. Armas e skills novas entram sempre com seus sons.
- **Tamanho relativo:** monstros pequenos ~70% da altura do Viajante, médios ~igual, grandes ~1,5x, chefes ~2,5x (ver §17.2). Nenhum monstro comum pode parecer minúsculo ao lado do jogador.

### 10.3 Monstros do MVP `[PROVISÓRIO]`

| Monstro | Inspiração | Mapa | Nível | Comportamento | Drops principais |
|---|---|---|---|---|---|
| Redemoinho Arteiro | redemoinhos do Saci | Campos | 1–3 | Passivo; dá pulinhos e some/reaparece perto | Folha Rodopiante, Gorrinho Vermelho (raro) |
| Vaga-lume Encantado | fauna mágica | Campos | 2–5 | Passivo; voa em padrão | Luz de Vaga-lume |
| Tatu-Pedra | fauna do cerrado | Campos | 5–9 | Passivo; rola em investida quando atacado | Casco de Tatu-Pedra, Couro Grosso |
| Lobisomem Jovem | lenda do Lobisomem | Mata | 9–14 | Agressivo; anda em duplas | Presa de Lobisomem, Couro Grosso |
| Corpo-Seco | lenda do Corpo-Seco | Mata | 12–17 | Agressivo, lento, muita vida | Brasa Fátua, Casca Seca |
| Harpia da Tempestade | gavião-real + tempestade | Chapada | 17–23 | Agressiva, ataque à distância | Pena de Tempestade, Fragmento Estelar (raro) |
| **Chefe: Boitatá** | lenda do Boitatá | Chapada | 25 | Chefe com 3 fases (seção 10.4) | Equipamento raro/épico, Escama de Boitatá, Fragmento Estelar |

- Reaparecimento de monstros comuns: 30 s após morrer. Chefe: 10 min por instância.
- IA: estados `ocioso → patrulha → perseguição → ataque → retorno`. Monstros que se afastam demais do ponto de origem voltam e recuperam a vida.
- **Mula sem Cabeça:** reservada para um arco de maior escala; não usar na Caverna do Reino Encoberto. Se entrar, tratar como criatura de fogo, sem componente religioso da lenda.

**Implementação atual da Caverna do Reino Encoberto:** quatro pisos independentes para níveis 12–30, com bifurcações, passarelas sobre abismos e covil do Lobisomem no F4. A forma atroz aparece à noite e a fuga para a superfície exige derrotar o chefe. A primeira quest investigativa (rastros na Mata, câmara do uivo e retorno ao guarda) permanece no F1; os rituais narrativos posteriores continuam pendentes. Consulte a [arquitetura canônica](mundo/arquitetura-masmorras-e-cavernas.md) e os [detalhes da implementação](mundo/caverna-implementacao.md).

### 10.4 Chefe: Boitatá `[PROVISÓRIO]`

Na lenda, o Boitatá é a serpente de fogo que protege os campos de quem os incendeia. No jogo, ele foi **enfurecido** pela fumaça das queimadas da região e ataca qualquer um que se aproxime do alto da Chapada. Derrotá-lo acalma o espírito (a morte dele é um "adormecer" em chamas que se apagam), mantendo o respeito à lenda.

Serpente gigante feita de fogo, com olhos enormes e brilhantes, 5 vezes o comprimento de um jogador.
- Fase 1 (100–60%): mordidas e sopro de fogo em cone (aviso visual no chão 1 s antes).
- Fase 2 (60–30%): invoca 3 fogos-fátuos que perseguem jogadores; deixa rastros de fogo no chão por onde passa.
- Fase 3 (30–0%): mais rápido; anéis de fogo se fecham em partes da arena, forçando movimentação.
Pensado para 3 a 5 jogadores de nível 20+, mas possível tentar com menos.

### 10.6 Estágios dos monstros (sem evolução) `[FECHADO em 30/09/2026: regra; PROVISÓRIO: números]`

**Decisão do dono (30/09/2026):** *"vamos remover a evolução e deixar só o chefe fixo e as outras formas."* Ela substitui
a regra de 27/09/2026 em que o monstro absorvia a XP de quem matava e evoluía.

- **Não existe evolução.** Monstro que mata jogador não ganha XP, não muda de estágio e não chama bando.
- **Cada espécie tem formas fixas**, cada uma com nome, arte e atributos próprios:
  1. **Normal:** nasce nos pontos de monstros dos mapas.
  2. **Médio:** nasce nos pontos de monstros onde o desenho de áreas manda (`docs/mundo/progressao-areas.md`).
  3. **Chefe:** só no seu covil fixo (§10.6.1).
  4. **Forma atroz:** o mesmo chefe à noite (§10.7).
- **Todo chefe anda com um bando fixo** da mesma espécie em volta dele.
  - O bando tem **4 normais e 2 médios** (`boss_escort_normals` e `boss_escort_mediums` em `Balance`).
  - O bando não renasce sozinho. Quando o chefe renasce, quem sobrou do bando volta a segui-lo, e só nascem os que faltam.
- **Recompensa por derrotar:** a XP do estágio, dividida pelas regras de grupo (§6.3), e os drops da tabela do estágio.

### 10.6.1 Chefes fixos nos covis `[FECHADO em 30/09/2026: regra; PROVISÓRIO: números e lugares]`

O chefe de uma espécie é o **estágio 3** dela. Ele **mora num covil fixo**: um marcador `BossLairs/` no mapa, um por chefe.

- **Renascimento.** O chefe renasce **10 minutos** depois de derrotado (`Balance.boss_respawn_sec = 600`). Um covil pode
  ter tempo próprio com a meta `respawn_sec`.
- **Os covis são independentes.** Vários chefes de espécies diferentes podem estar vivos no mesmo mapa.
- **Não existe chefe por contagem de abates.** A regra dos "500 abates" saiu junto com a evolução.
- **Covis só na Chapada do Céu Partido** (mapas com `bosses_allowed` e teto de estágio 3):
  - **Subida Vermelha:** Tatu-Montanha, Rainha-Lume do Brejo e Ventania do Gorro Vermelho, os 3 chefes de Pindorama que as
    quests dos anciãos pedem;
  - **Cristas do Vento:** Queixada;
  - **Alto das Brasas:** Serpente-Fagulha e Mula de Brasa.
- **Nunca no Campo de Treino.** Ali o teto continua sendo o estágio 2 (§9.3).
- O Boitatá continua planejado como chefe próprio da Chapada (§10.4), com covil.

### 10.7 Dia e noite `[FECHADO em 27/09/2026: regra; PROVISÓRIO: números e duração]`

- O mundo tem **ciclo de dia e noite** com efeito no jogo (substitui a linha do §3.2 que deixava o ciclo apenas visual para depois).
- **À noite os monstros mudam:** surgem **espécies e variantes noturnas diferentes** das do dia, **30% a 50% mais fortes** (atributos). Os **chefes à noite ficam 100% mais fortes** e assumem a sua **forma atroz** (arte e habilidades próprias).
- **Quests também mudam à noite:** há quests que só existem ou só avançam à noite (e outras só de dia).
- Números padrão `[PROVISÓRIO]`: ciclo de 2 h reais (1 h 30 de dia, 30 min de noite); bônus noturno sorteado por espécie entre 30% e 50%; chefe atroz +100%. Isolado num serviço `WorldClock` + dados por espécie (`MonsterDef`: estágios diurnos e noturnos, forma atroz do chefe).
- Luz, céu, névoa e música mudam com a hora; o Campo de Treino fica sempre de dia (área de aprendizado).
- **Implementado em 30/09/2026 (`docs/chefes-dia-noite.md`).**
  - Números em uso, pela sugestão do dono: 40 min de dia e 20 min de noite (`Balance`).
  - Já funcionam o chefe atroz (+100%, agressivo, desenho próprio), a luz e o céu.
  - Faltam as espécies noturnas, o bônus de 30–50% dos monstros comuns e as quests por hora.

### 10.5 Drops

- Cada monstro tem uma tabela de drops (item, chance, quantidade) em arquivo de dados.
- Drops aparecem no chão e pertencem ao dono do monstro (maior dano) e ao grupo dele por 10 s; depois qualquer um pode pegar (seção 5.2). Somem após 60 s.
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
- Poções: vida pequena/média, mana pequena/média. **Uso instantâneo, sem recarga** (decisão de 28/09/2026, §8.1).
- **Troca entre personagens:** itens do inventário e Estrelas, de jogador para jogador (seção 13.1).
- **Pergaminho de Retorno** `[FECHADO em 30/09/2026: pedido do dono; PROVISÓRIO: preço e tempos]` (estilo asa de borboleta do Ragnarok): consumível empilhável (`return_scroll`, `use_effect` `return_city`), vendido no mercado do Porto por 20 Estrelas; o kit inicial traz 3. Leva o jogador à **última cidade** em que esteve (`CharacterData.last_city`, gravada ao entrar num mapa de zona cidade; sem nenhuma, a cidade inicial), no ponto seguro (SpawnPoint). Fora de combate é na hora; **em combate**, leitura de 1 s (`return_scroll_combat_cast_sec`) interrompida por dano, por andar ou por atordoamento. Recarga de 10 s (`cooldown_sec` no item). **Não funciona** caído, em provação ativa, com troca aberta nem no Campo de Treino (a saída de lá é pelo portal, com o título). Vai na barra 1–0 como as poções. O servidor valida tudo, no começo e no fim da leitura.

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
- **Resgate com amigos:** o mapa é compartilhado; o dono pode montar um grupo e os amigos ajudam a limpar o caminho. Só o dono (ou quem matou, no PVP) recolhe os itens.

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

- **Grupos** (implementado em 30/09/2026, seção 5): convidar (`/grupo <nome>` ou clique no jogador), aceitar, recusar, sair, expulsar (só líder), passar liderança. Até 5 membros. Painel com vida e mana dos membros na tela.
- **Chat:** canal do mapa atual (local), grupo (`/g` ou aba "Grupo", em qualquer mapa; seção 5.4), sussurro (privado, depois). Limite de 1 mensagem por segundo.
- **Censura de palavrões** `[FECHADO em 27/09/2026]`: em **qualquer idioma** e **qualquer formato** de burla (leet/números no lugar de letras, espaços, pontos ou símbolos entre letras, letras repetidas, acentos, caracteres de outros alfabetos parecidos, abreviações conhecidas). A palavra é substituída por `***` e a mensagem segue.
- **Menores de idade** `[FECHADO — exigência legal, ECA Digital; detalhes em docs/monetizacao-proposta.md]`: contas de menores começam com a configuração mais protetiva (chat limitado e compras bloqueadas) até o responsável vinculado consentir. Entra junto com o sistema de contas (Fase 2). Requer validação jurídica.
- **Sanção progressiva por insistência** `[FECHADO: existe e é progressiva até a perda do personagem; PROVISÓRIO: degraus]`: quem insiste recebe **bloqueio de chat de 1 h**, e os bloqueios **aumentam** a cada reincidência até a **perda do personagem**. Degraus padrão (configuráveis): aviso → 1 h → 6 h → 24 h → 7 dias → 30 dias → perda do personagem. Reincidência conta numa janela móvel; o histórico diminui com bom comportamento. Os **dois últimos degraus exigem revisão humana** antes de valer (evita punição por falso positivo; ver cuidados legais na seção 14.2). Tudo registrado em log de moderação.
- **Amigos:** lista simples (adicionar, remover, ver se está online e em qual mapa). Facilita o resgate de túmulos. Enquanto ela não existe, `/online` mostra quem está conectado, o mapa e o nível (seção 5.4).
- **Emotes:** 6 emotes básicos (acenar, sentar, rir, chorar, raiva, coração) mostrados como balão pixel art sobre o personagem.
- **Bloquear jogador:** esconde chat e convites daquele jogador (convites de grupo e pedidos de troca; ainda não implementado).

### 13.1 Troca entre personagens `[FECHADO em 30/09/2026: pedido do dono; PROVISÓRIO: números]`

- **Começar:** clique (esquerdo ou direito) no outro jogador → **Propor troca**, ou `/troca <nome>`. O outro recebe uma janela com **Aceitar** e **Recusar** (ou `/troca aceitar` / `/troca recusar`). O pedido vale 30 s; quem pede espera 3 s entre pedidos.
- **Condições:** os dois no **mesmo mapa** e a até **6 células** (`trade_range_cells`), vivos e **fora de combate** (6 s sem causar ou receber dano). Durante a troca, quem se afasta, cai, entra em combate, troca de mapa ou desconecta cancela a troca.
- **Janela:** dois lados ("Você" e o outro), com ícone, nome e quantidade de cada item e as **Estrelas** (a moeda do jogo). Põe item arrastando do inventário ou com o botão direito no item; tira com o botão direito na própria oferta. Até 10 itens diferentes por lado.
- **Confirmar e Trocar:** "Confirmar" trava a oferta. **Qualquer mudança** (oferta, inventário ou Estrelas de um dos dois) **desfaz a confirmação dos dois**. "Trocar" só liga com os dois confirmados, e a troca sai quando os dois apertam.
- **Servidor autoritativo e atômico:** confere posse e quantidade de cada item (pelo espaço do inventário), Estrelas, espaço no inventário de quem recebe (simulado antes) e só então aplica tudo de uma vez e salva os dois personagens. Se algo falhar, nada muda. Item **equipado** não está no inventário e não entra; item com `ItemDef.tradeable = false` ou pilha protegida (`ItemStack.protected`, §12.4) também não.
- **Moderação:** cada troca vai para o log do servidor (`trade_done`) e para `user://server_state/trades.jsonl` (quem, o quê, quantas Estrelas, mapa e hora). Pedidos, ofertas, recusas e cancelamentos também ficam no log.
- Contratos: `docs/contracts-city-walk.md`, ADENDO 7 (NetTrade).

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

- Tick do servidor: **20 Hz**. Movimento: o servidor envia o **caminho de células com o horário de início** e todos os clientes o reproduzem com o relógio sincronizado por ping (seção 10.1) — sem atraso artificial de interpolação.
- **Sem colisão física entre entidades** (como nos MMOs clássicos): jogadores e monstros atravessam uns aos outros. Movimento por **grade de células** (seção 10.1), derivada do navmesh de cada mapa.
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

### 17.0.A Direção de arte do CENÁRIO — revisada em 27/09/2026 `[FECHADO]`

> **REQUISITO OBRIGATÓRIO (dono do projeto, 27/09/2026):** nenhum mapa é considerado pronto — nem entra em teste com jogadores — enquanto não estiver no estilo desta seção (cenário 3D pintado à mão, vegetação cheia, luz quente, conforme as referências em `env_refs/`). Mapas no estilo antigo (texturas pixel "ruidosas", blocos lisos, paredes azuladas, cristais/objetos provisórios) contam como **não entregues**. Vale para a cidade, o Campo de Treino e todo mapa futuro.

Referências do dono (só sensação, nunca copiar): `game/assets/_reference/style_anchor/env_refs/` — cenário 3D **estilizado com texturas pintadas à mão**, como nos MMOs clássicos em 2.5D e suas versões modernas.
- **Personagens, NPCs e monstros continuam em pixel art** (sprites, como está aprovado).
- **Cenário deixa de usar texturas pixel art "ruidosas" e blocos low-poly lisos.** Passa a ser: terreno com textura pintada (grama com variação de cor, trilhas de terra macias, bordas orgânicas), **vegetação cheia e estilizada** (árvores com copas volumosas, arbustos, capim, flores, cogumelos espalhados), props com volume (caixotes, barris, cercas, pedras com musgo), paredes com textura pintada (cal, pedra, madeira, telha), luz **quente e suave** com sombras macias, oclusão ambiente, leve bloom, névoa de distância, **profundidade de campo sutil** nas bordas e vinheta.
- **Renderização:** o mundo 3D é desenhado na **resolução nativa** da tela (não mais reduzido para 960×540); os sprites continuam com filtro "nearest" e escala inteira sempre que possível. A seção 17.2 continua valendo para o tamanho dos sprites (96 px, 48 px por unidade).
- Esta seção **substitui** as partes de 17.1, 17.2 e 17.11 que falam de textura pixel art no cenário e de renderização 960×540 para o mundo.
- **Origem dos modelos 3D do cenário** `[FECHADO em 27/09/2026]`: podem vir de **pacotes profissionais estilizados com licença CC0** (ex.: Quaternius, KayKit, Kenney), sempre re-texturizados e ajustados à nossa paleta e à nossa luz, com cada pacote registrado em `game/assets/environment/LICENSES.md`. Só CC0 (nada de CC-BY-SA, NC ou licença incerta). A IA de imagem (Bria) segue para texturas, folhas recortadas, ícones e personagens — ela não gera 3D.

### 17.0 Âncora de estilo (fazer ANTES de qualquer outra arte)

A âncora de estilo é um pequeno conjunto de artes aprovadas que servem de referência para todas as gerações seguintes. Ela fica em `/assets/_reference/style_anchor/` e é composta por:

- `paleta-mestra.gpl` e `paleta-mestra.png` — paleta oficial (fornecida junto com este documento; o `.gpl` abre direto no Aseprite)
- `gabarito-proporcao-64px.png` — gabarito original de 64 x 64 (substituído pela escala de 96 x 96 de 17.2; refazer o gabarito a partir da Âncora 2 aprovada)
- As **5 imagens-âncora** descritas em 17.0.3, geradas por IA, tratadas e aprovadas

#### 17.0.1 DNA visual: o que herdar da *sensação* de Ragnarok

- Personagens pequenos com **cabeça grande e traços de anime/mangá**, cerca de **3 cabeças de altura**, expressivos mesmo em poucos pixels.
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
- Aparência: jovem adulto, ~3 cabeças de altura, olhos grandes estilo anime, cabelo castanho bagunçado (masc.) e rabo de cavalo castanho (fem.).
- Roupa (o toque isekai): **moletom com capuz azul** (`#2f55a8` / `#5a90e0`), calça jeans escura, tênis branco com detalhe vermelho, **pequena mochila marrom**. Contraste proposital com o mundo medieval.
- Expressão: curiosa e um pouco surpresa.

```
pixel art character reference sheet of a young adult isekai traveler, anime-inspired face with large expressive eyes,
cute proportions about 3 heads tall, messy brown hair, blue hoodie, dark jeans, white sneakers with red details,
small brown leather backpack, curious surprised expression, three views side by side: front, side, back,
neutral standing pose, 3/4 top-down game view, soft bright slightly pastel colors, clean 1px colored outline,
3-4 tone soft cel shading, light from top-left, flat plain background, crisp pixels, no anti-aliasing
```

**Âncora 2 — Viajante em tamanho real de jogo, 5 direções**
A partir da âncora 1 aprovada (usar como imagem de referência). Quadros de 96 x 96 (ver 17.2), pose parada, direções S, SE, L, NE, N numa linha.

```
pixel art game sprite sheet, the same young traveler character from the reference, idle standing pose,
5 frames in one row facing: front, front-right, right, back-right, back, 96x96 pixel frames,
character about 80 pixels tall with big head, 3/4 top-down view, soft pastel colors, 1px colored outline,
light from top-left, transparent background, consistent design in every direction
```

**Âncora 3 — Monstro-âncora: Tatu-Pedra**
Define o equilíbrio "fofo, mas ameaçador" de todos os monstros.

```
pixel art monster sprite, a chubby armadillo with shell plates made of smooth reddish stone, small moss patches,
big round shiny eyes, cute but slightly grumpy, fantasy MMORPG field enemy, 3/4 top-down view,
front-right facing, 96x96 frame, soft bright colors, 1px colored outline, 3-4 tone shading,
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

### 17.0.B Novo padrão de personagem e roupa por título `[FECHADO em 28/09/2026 pelo dono]`

Referência aprovada: `game/assets/_reference/wardrobe/title-evolution-v1.png` (masculino e feminino, 4 estágios).
- **Novo desenho do Viajante:** proporção **encorpada no estilo chibi dos MMOs clássicos** (≈3–3,5 cabeças: cabeça grande, ombros e tronco largos, braços e pernas grossos, mãos e botas grandes, pernas curtas) — revisto em 28/09/2026 pelo dono, que achou a versão esbelta "magrinha"; as roupas da prancha continuam valendo sobre essa proporção, rosto anime detalhado, pixel art rica em tons, contorno escuro colorido. Substitui o Viajante chibi atual (e todas as camadas: corpo, cabelos, olhos, brincos, chapéus, armas, animações).
- **A roupa muda de acordo com o título** (seção 8.5), em 4 estágios:
  0. **Viajante** (sem título): roupa do nosso mundo — moletom, camiseta, jeans, tênis, bolsa a tiracolo.
  1. **Primeiro título** (ex.: Facão Firme): roupa de aprendiz — colete de couro, ombreira, faixa na cintura, botas.
  2. **Ramo** (ex.: Tronco de Aroeira): casaco longo bordado com detalhes dourados.
  3. **Ápice**: armadura/casaco de mestre com placas e bordados.
- **NPCs usam os mesmos esqueletos e o mesmo pipeline** (corpo base + roupa + cabelo + acessórios + paleta), renderizados como folha inteira; só o jogador usa camadas separadas.
- A roupa do título aparece automaticamente no personagem; equipamento de corpo e cosméticos podem sobrepor (regras de aparência do §14.3). Cada título define sua roupa (`TitleDef.outfit_id`), para que títulos de regiões/escolas diferentes tenham visuais próprios.

### 17.0.C "Não parecer papel" — leitura dos sprites no cenário 3D `[FECHADO em 28/09/2026]`

Referência de sensação: vídeo do dono (Ragnarok clássico). Regras:
- Câmera mais inclinada para baixo (≈55–60°) e personagens menores na tela (≈9–11% da altura em 1080p), como nos MMOs 2.5D clássicos.
- Sprites recebem a luz da cena (tom e sombra suaves), sombra macia colada aos pés; nada de cartão "colado por cima".
- Monstros com animação viva: quicar, achatar e esticar (squash & stretch), reação de impacto; mais quadros onde fizer diferença.
- Vegetação em moitas cheias e baixas, grama contínua no chão; evitar tufos isolados espetados que viram recortes ao girar a câmera.
- Fluidez: meta de 60 fps estáveis no PC de referência.

### 17.0.D Reaproveitar antes de criar `[FECHADO em 28/09/2026 pelo dono]`
Tudo o que puder ser pego pronto é pego pronto e **alterado** para ficar nosso: modelos, esqueletos, animações, roupas, vegetação, shaders, sons. Só entram licenças que permitem uso comercial sem restrição (preferência CC0; MIT para código/shaders), com registro de cada pacote no `LICENSES.md` da pasta. Nada que lembre personagens, monstros ou mapas de outros jogos (§0 regra 5); peças prontas sempre passam por ajuste de forma, paleta e acabamento antes de entrar no jogo.

### 17.1 Guia de estilo `[PROVISÓRIO até aprovar as primeiras artes]`

- **Estilo:** pixel art colorida e luminosa, fantasia medieval aconchegante com um toque de aventura, com a sensação descrita em 17.0.1. Nunca citar jogos ou artistas específicos nos prompts.
- **Paleta mestra:** uma única paleta de 50 cores para o jogo inteiro (`paleta-mestra.gpl`, 12 rampas de 4 tons + contorno base `#16131c` + branco `#fcfaf5`). Todo asset final é quantizado para ela. Regiões usam subconjuntos dela, nunca cores novas sem atualizar o arquivo.
- **Luz:** sempre vindo de **cima e da esquerda**. Sombra projetada suave e oval sob personagens e monstros (sprite separado, 50% de opacidade).
- **Contorno:** 1 pixel, **seletivo e colorido** (tom mais escuro da cor vizinha), nunca preto puro. Contorno externo levemente mais escuro que o interno.
- **Sombreamento:** 3 a 4 tons por material. Sem gradientes suaves, sem antialiasing contra o fundo, sem pixels órfãos, dithering apenas em céus e grandes áreas.
- **Proporção dos personagens:** cerca de **3 cabeças de altura** total, cabeça grande, traços de anime (ver gabarito).
- **Ângulo de visão dos sprites:** três quartos de cima, cerca de 35° de inclinação, compatível com a câmera do jogo.

### 17.2 Escala e renderização `[PROVISÓRIO — revisado em 27/09/2026 pelo dono do projeto]`

- **Densidade:** 48 pixels = 1 unidade do mundo (≈ 1 metro). No `Sprite3D`: `pixel_size = 1/48`, `texture_filter = nearest`. Texturas de cenário usam a mesma densidade.
- Personagem adulto: ~80 px de altura (≈ 1,7 m), em quadro de **96 x 96 px**. Motivo da revisão: com 51 px o rosto, o cabelo e a roupa perdiam a leitura que é a alma do visual (referência de densidade: Samsara Saga e a sensação de 17.0.1).
- Monstros pequenos: quadro 64 x 64; médios: 96 x 96; grandes: 144 x 144; chefe: 240 x 240.
- Resolução interna do jogo: a cena é renderizada numa `SubViewport` de **960 x 540** e ampliada por múltiplo inteiro para a tela (2x em 1080p). Interface desenhada por cima em resolução própria.
- Câmera: perspectiva, inclinação fixa de ~45° para baixo, giro livre em torno do jogador (yaw), zoom limitado entre 0,8x e 1,3x. Com zoom 1,0 o personagem deve aparecer em ~1:1 (1 texel ≈ 1 pixel interno).
- **Atualização 28/09/2026 (§17.0.C, implementado):** inclinação 57°, Viajante ≈10% da altura em 1080p, zoom 0,8x–1,25x. Escala de texel inteira sempre que o valor exato fica a até 0,15 de um inteiro; fora disso (ex.: 1080p = 1,29) o shader dos sprites usa "pixel AA" (texel continua bloco sólido). Detalhes em `docs/arte-cenario/campo-treino-direcao.md`, revisão 7.

### 17.3 Direções e animações

**Direções:** 8 no jogo (S, SE, L, NE, N, NO, O, SO). Gerar e desenhar apenas **5**: **S, SE, L, NE, N**. As outras 3 são o espelho horizontal (SO = SE espelhado, O = L espelhado, NO = NE espelhado).

A direção exibida é calculada pelo ângulo entre para onde a entidade olha e a posição da câmera, arredondado para o setor de 45° mais próximo.

**Animações de personagem jogável** (quadros por direção, duração por quadro):

| Animação | Quadros | ms/quadro | Loop |
|---|---|---|---|
| idle (parado, respiração) | 4 | 200 | sim |
| walk (andar) | 8 | 100 | sim |
| attack_melee (golpe com arma) | 6 | 70 | não |
| cast (conjurar, mãos à frente) | 6 | 90 | não |
| hit (receber dano) | 2 | 100 | não |
| death (cair) | 6 | 120 | não (fica no último quadro) |
| sit (sentado) | 1 | — | — |

**Monstros comuns:** idle 4, walk 6, attack 6, hit 2, death 6.
**Chefe:** idle 6, walk 8, attack_melee 8, attack_area 10, summon 8, hit 2, death 10.

Formato de entrega: uma folha (sprite sheet) por animação, **linhas = direções na ordem S, SE, L, NE, N**, colunas = quadros. Fundo transparente. Exportar do Aseprite com JSON de metadados.

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

**Atenção para a IA:** gerar camadas separadas e alinhadas é o ponto mais difícil. Processo recomendado:
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
pixel art character reference sheet, {descrição do personagem}, anime-inspired face, cute proportions about 3 heads tall,
three views: front, side, back, standing neutral pose, 3/4 top-down game perspective,
limited palette, clean 1px colored outline, 3-4 tone cel shading, light from top-left,
flat transparent background, crisp pixels, no anti-aliasing, cozy medieval fantasy MMORPG style, soft bright slightly pastel colors
```

**Quadros de animação:**
```
pixel art sprite sheet, {personagem}, {animação} animation, {n} frames in a single row,
facing {direção}, consistent character design matching the reference, 96x96 frame grid,
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
top-down view, 96x96, limited palette, subtle variation, no strong directional pattern, no outline
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

- [ ] **Cenário:** segue §17.0.A (pintado à mão, sem textura pixel no ambiente) — obrigatório

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

- Mapas são **geometria 3D simples** (terreno + blocos de baixa contagem de polígonos) com **texturas pixel art** a 48 px/unidade. Vegetação pequena, flores e detalhes: sprites billboard.
- Priorizar composição: pontos altos com vista, silhuetas no horizonte, água, contraste de luz.
- Luz direcional quente + ambiente frio; névoa volumétrica leve em distância; partículas (pólen, folhas, faíscas).
- Cada mapa tem ao menos **3 "pontos de vista"** planejados, com um banco ou mirante onde o jogador pode sentar (animação `sit`) e tirar foto.
- Modo foto `[PROVISÓRIO]`: tecla/botão que esconde a interface.

---

## 18. Áudio `[PROVISÓRIO]`

- Música: 1 faixa por mapa (cidade calma, campos leves, floresta misteriosa, penhascos épicos e melancólicos, arena tensa) + tema do chefe + tema da tela de título. Loops de 2 a 3 minutos.
- **Menus e interface não têm som** (decisão de 27/09/2026). Passos, se existirem, bem discretos: nos MMOs clássicos de referência o personagem anda em silêncio.
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
| 1 | Skill sobe de nível por… | uso / pontos | **Decidido (27/09/2026):** pontos — 1 ponto de skill por nível do personagem |
| 2 | Limite de skills | barra de 8 / escolas opostas / limite de maestria | **Decidido (27/09/2026):** barra de 10 (teclas 1 a 0) |
| 3 | Morrer com túmulo pendente | túmulo anterior some / acumulam | acumulam |
| 4 | Proteção de itens | vínculo de alma / amuleto / proteção de iniciante / desgaste | nenhuma (só infraestrutura) |
| 5 | Saída do líder | liderança passa / grupo fecha | **Decidido (30/09/2026):** liderança passa ao membro mais antigo depois de 3 min (sem instância por grupo; seção 5.3) |
| 6 | Nome do jogo e do mundo | — | **Decidido (27/09/2026): o jogo se chama "Perdidos".** Nome do mundo: em aberto |
| 7 | Paleta mestra | paleta própria ou ajustes após as âncoras | **Decidido em 27/09/2026: expandir** a paleta (≈6 tons por rampa + tons intermediários) a partir das âncoras aprovadas |
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
