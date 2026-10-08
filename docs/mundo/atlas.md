# Atlas do mundo — geografia, cidades, masmorras e mistérios

> Status: `[PROVISÓRIO]` — nomes, posições e níveis são propostas (GDD §4.0.1: "FECHADO: existe; PROVISÓRIO: nomes e posições").
> Autor: agente G, 27/09/2026. Base: GDD §1, §4.0, §4.0.1, §4.1–4.3, §9.3, §10.3, §10.6, §17; `docs/lore/chegada-do-viajante.md`; `TITULOS-E-SKILLS.md` §5.
> **Fonte única dos dados:** `docs/mundo/gerar_dados_atlas.py`. Ele gera `game/data/world/*.tres`, `game/localization/world_atlas.csv` e as tabelas da seção 3 deste arquivo. Para mudar um nome, uma posição ou um nível, edite o script e rode `python3 docs/mundo/gerar_dados_atlas.py` e depois `make check-names`.
> Arte: `game/assets/worldmap/` (registro de prompts e seeds em `game/assets/worldmap/REGISTRO.md`). Tela no jogo: tecla **M** (`game/scripts/client/ui/world_atlas.gd`).

---

## 1. O nome do mundo (para o dono escolher)

Hoje a lore diz só "este mundo" e chama o nosso de "o Outro Lado" (pergunta 1 de `chegada-do-viajante.md`). Três propostas, todas curtas, fáceis de falar em português e sem colisão com nomes sagrados ou de outros jogos que conheçamos (fazer checagem de marca antes de fechar):

| # | Nome | Ideia | Como soa na boca dos NPCs |
|---|---|---|---|
| 1 | **Contária** | De *conto*: "a terra onde os contos são verdade". Liga direto ao "mundo feito de histórias" e ao Eco (lendas que comem histórias). | "Bem-vindo a Contária, Viajante. Aqui toda história tem dono." |
| 2 | **Achadouro** | O contrário de *Perdidos*: o lugar onde os perdidos são achados. Brinca com o título do jogo e soa como nome de terra antiga (*-douro*, como "Fiandouro"). | "Todo perdido um dia chega ao Achadouro." |
| 3 | **Ecoar** | Do **Eco** e dos "reinos que ecoam o nosso planeta". Verbo que vira nome próprio: fácil de lembrar e bonito em trailer. | "Em Ecoar, o que você vive ecoa para sempre." |

Recomendação do agente G: **Contária** (mais claro para quem nunca leu a lore; funciona bem traduzido: *Contaria*, *Tale-land* como subtítulo). **Achadouro** é a melhor dupla com o título "Perdidos" se o dono quiser um trocadilho.

Enquanto não houver decisão, a interface mostra "O mundo dos Viajantes" (chave `WA_WORLD_NAME`).

---

## 2. Visão geral do mapa

O mapa-múndi é um pergaminho ilustrado no estilo medieval fantasia (arte sem texto; os nomes são desenhados pela engine e são traduzíveis). As terras se abrem em volta de um mar interno calmo, o **Mar do Meio**, cheio de ilhotas: todas as nações conseguem chegar umas às outras por barco, o que justifica o comércio, os Mestres de todas as nações no Campo de Treino e os Viajantes começando em qualquer capital.

```
                 Norte Nublado (não alcançado)
  Brumas Verdes    Fiordes de Gelo   Estepe de Ferro   Império de Jade   Ilhas do
  (ilhas de névoa) (geleiras)        (bétulas)         (terraços)        Sol Nascente
              Reino das Mouras ─── Costa das Colunas                      (vulcões)
  Selvas de      Terra de Pindorama        ~~ Mar do Meio ~~              Areias do Nilo
  Obsidiana      (chapadas e rio)                                     (dunas)
      ~ Mar das Pétalas ~                   Areias Sem Fim (não alcançado)
```

| Região | Onde fica no mapa | Clima que a arte mostra |
|---|---|---|
| Terra de Pindorama (MVP) | centro-sudoeste | chapadas vermelhas, cerrado verde, rio largo, mata escura, fumaça de queimada |
| Selvas de Obsidiana | extremo sudoeste | selva densa, vulcão fumegante |
| Brumas Verdes | noroeste | ilhas de colinas verdes, névoa |
| Fiordes de Gelo | norte | geleiras e gelo branco, pinheiros |
| Estepe de Ferro | centro-norte | pinheiros e bétulas, picos brancos, colinas escuras |
| Reino das Mouras | centro | planalto seco de oliveiras e cardos, litoral recortado |
| Costa das Colunas | centro-leste | península seca e um arquipélago de ilhotas no Mar do Meio |
| Império de Jade | nordeste | terraços de arroz, montanhas verdes altas |
| Ilhas do Sol Nascente | leste | ilhas de pedra, pinheiros e um vulcão |
| Areias do Nilo | sudeste | dunas douradas e picos de areia (as pirâmides do vale) |

**Nomes das regiões:** mantidos como no GDD §4.0. Alternativas opcionais (só se o dono quiser):
- *Estepe de Ferro* → **Bosques de Bétula** ou **Terra das Isbás** (a arte mostra mais floresta que estepe).
- *Areias do Nilo* → **Areias do Rio Verde** (evita o nome de um rio real e fica mais "reino de fantasia").
- *Império de Jade* → **Terraços de Jade** (sem a ideia de império/conquista; descreve o que se vê).
- *Selvas de Obsidiana*, *Brumas Verdes*, *Fiordes de Gelo*, *Costa das Colunas*, *Ilhas do Sol Nascente*, *Reino das Mouras*: bons como estão.

### 2.1 Faixas de nível

Nenhum mapa é bloqueado (GDD §4.3); a faixa é só indicação. Como o título inicial define a cidade onde o Viajante começa (GDD §9.3), **toda região tem campos para nível 10–20 logo ao lado da capital**. A escada padrão de cada região:

| Faixa | O quê |
|---|---|
| 1–10 | Campo de Treino (todos) e, no Brasil, Campos de Pindorama |
| 10–20 | primeiro campo de caça de cada região, perto da capital |
| 20–30 | segundo campo de caça |
| 25–45 | masmorras de folclore |
| 40–55 | chefe da região (com bando, GDD §10.6) |
| 40–65 | masmorras de mistério (Viajantes perdidos) |

A Terra de Pindorama segue o GDD: Campos 1–10, Mata 8–18, Chapada 15–25 e Boitatá no 25.

### 2.2 O que já existe no jogo

| Lugar | Estado | `map_id` |
|---|---|---|
| **Campo de Treino dos Viajantes** | aberto | `training_field` |
| **Porto do Despertar** | aberto | `city_awakening` |
| Campos de Pindorama, Mata Encantada, Chapada do Céu Partido, Ninho do Boitatá, Arena da Queimada | em breve (MVP, GDD §4.2) | — |
| Todo o resto | terra ainda não alcançada | — |

O marcador "você está aqui" usa o `map_id` do mapa atual (ver seção 6).

---

## 3. Regiões, cidades, campos e masmorras

Estados: **aberto** = existe no jogo; **em breve** = previsto no MVP; **não alcançada** = aparece no mapa, mas ainda não se chega lá. Posições normalizadas (0 a 1) sobre `world_map.png`.

Cuidados culturais por região (resumo; valem os de `TITULOS-E-SKILLS.md` §5 e do GDD §4.0):
- **Pindorama:** o Curupira é guardião (NPC), não inimigo; o Saci não é morto (o monstro é o Redemoinho Arteiro); a Iara é tratada como encanto do rio, sem sexualização. A Mula sem Cabeça, se entrar, só como a mula de fogo, sem a parte religiosa da lenda.
- **Mouras:** mouras encantadas são personagens de lenda (guardiãs que fiam ouro), nunca retrato de povos. A Coca só como dragoa, sem a procissão. Adamastor vem de Camões (domínio público).
- **Colunas:** nenhum deus do Olimpo como inimigo ou fonte de poder. Medusa aparece como "ela" na Gruta das Estátuas.
- **Areias:** Apep só como criatura (sensível: aviso no `check-names`). Nada de múmias como piada; pirâmides são obra do povo do rio e aparecem como marco, não como masmorra.
- **Jade:** jiangshi aparecem como "Saltadores"; nada de sacerdotes ou imagens budistas/taoístas como mecânica. O Nian se vence com vermelho e barulho.
- **Sol Nascente:** kami não viram NPC nem fonte de poder. O Orochi é só um monstro; **não** usar a história do herói que o derrota (é uma divindade xintoísta).
- **Fiordes:** nenhum deus nórdico; glifos originais, nunca runas reais. Fenrir é sensível (aviso), mantido como no GDD.
- **Estepe:** nenhum deus eslavo; nada de cúpulas de igreja ortodoxa na arquitetura da capital (Zharogrado é de isbás e torres de madeira).
- **Brumas:** a harpa é mágica genérica. Balor é sensível (aviso), mantido como no GDD.
- **Obsidiana:** **aluxes** são NPCs respeitados, nunca inimigos (crença maia atual); **nahuales** também ficam fora da lista de monstros pelo mesmo motivo. Nada de deuses astecas nem de sacrifício. Cipactli é sensível (aviso), mantido como no GDD; se a revisão pedir, trocar por "o Crocodilo da Terra".

<!-- GERADO-INICIO -->
#### Terra de Pindorama (Brasil) — `pindorama`

*Rios largos, cerrado de ipês e chapadas acima das nuvens: onde os Viajantes acordam.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Porto do Despertar** | Capital | — | **aberto (existe no jogo)** | Cidade do rio onde os Viajantes acordam, sob o ipê amarelo gigante e o cristal azul. | 0.315, 0.790 |
| Campo de Treino dos Viajantes | Área inicial | 1–10 | **aberto (existe no jogo)** | Planalto sobre o Mar do Meio onde Mestres de todas as nações recebem os recém-chegados. | 0.405, 0.612 |
| Campos de Pindorama | Campo de caça | 1–10 | **aberto (existe no jogo)** | Cerrado de ipês em flor, buritis e cupinzeiros: os primeiros passos longe da cidade. | 0.420, 0.690 |
| Mata Encantada | Campo de caça | 6–12 | **aberto (existe no jogo)** | Mata fechada de cipós e igarapés, com um velho forte engolido pelo musgo. | 0.350, 0.725 |
| Chapada do Céu Partido | Campo de caça | 12–25 | **aberto (existe no jogo)** | Chapadas vermelhas sobre um mar de nuvens; cachoeiras caem no vazio. | 0.318, 0.585 |
| Ninho do Boitatá | Chefe | 25 | em breve (MVP) | A serpente de fogo, enfurecida pela fumaça das queimadas, guarda o alto da chapada. | 0.286, 0.648 |
| Arena da Queimada | Arena PVP | — | em breve (MVP) | Clareira de cerrado queimado onde os Viajantes se enfrentam. | 0.245, 0.765 |
| Vila do Buriti | Vila | — | não alcançada | Casas de palafita entre buritis, na foz do grande rio. | 0.360, 0.865 |
| Mirante do Ipê Solitário | Marco | — | não alcançada | Um ipê roxo no topo das chapadas: dizem que dele se vê o mundo inteiro. | 0.245, 0.515 |
| Caverna do Reino Encoberto | Masmorra | 12–60 | **aberto (existe no jogo)** | Sob as raízes da Mata, pegadas fundas levam a uma câmara de pedra de onde vem um uivo. | 0.335, 0.742 |
| Serra Dourada | Vila | — | **aberto (existe no jogo)** | A Serra Resplandecente: casario de pedra no pico mais alto, acima do mar de nuvens da Chapada. | 0.292, 0.505 |
| Selva de Ratanabá | Campo de caça | 20–30 | **aberto (existe no jogo)** | Trilhas de pirâmides engolidas pela selva e igarapés cheios de glifos que brilham. | 0.250, 0.565 |
| Ruínas de Ratanabá | Masmorra | 24–38 | **aberto (existe no jogo)** | Uma escadaria submersa desce à cidade de pedra polida, onde sentinelas de obsidiana ainda montam guarda. | 0.218, 0.590 |
| Dossel de Z | Campo de caça | 30–38 | **aberto (existe no jogo)** | Mata tão fechada que a luz quase não chega ao chão; olhos acompanham cada passo na picada. | 0.268, 0.608 |
| Cidade Perdida de Z | Masmorra | 35–44 | **aberto (existe no jogo)** | Terraços de murais cobertos de musgo, guardados por onças de sombra, até o santuário de Kuarahy. | 0.236, 0.667 |
| Arraial do Sumidouro | Vila | — | **aberto (existe no jogo)** | Último arraial antes da névoa, no alto da serra; dali partem as trilhas para a Charneca e para a Boca do Sumidouro. | 0.340, 0.530 |
| Vilarejo de Hoer Verde | Masmorra | 38–52 | **aberto (existe no jogo)** | Uma vila abandonada na névoa, de sinos que dobram sozinhos. Na entrada: “Não há salvação”. | 0.378, 0.543 |
| Charneca da Névoa | Campo de caça | 34–42 | **aberto (existe no jogo)** | Brejos e urzes cobertos de névoa leitosa; a Trilha dos Lamentos leva ao vilarejo esquecido. | 0.373, 0.610 |
| Serra do Sumidouro | Campo de caça | 40–48 | **aberto (existe no jogo)** | Trilhas de cristal à beira da Garganta do Abismo, até a boca que engole a montanha. | 0.352, 0.648 |
| Túneis da Terra Oca | Masmorra | 44–60 | **aberto (existe no jogo)** | Galerias titânicas de cristal sob a serra, onde tecelãs de sombra fiam no escuro e um titã dorme. | 0.316, 0.674 |
| Abismo do Sumidouro | Masmorra | 50–56 | **aberto (existe no jogo)** | Um poço de pedra molhada sob o arraial, onde uma nuvem preta chove sozinha e barcos somem. | 0.352, 0.505 |
| Brejo do Corpo-Seco | Masmorra | 20–30 | não alcançada | Charco de árvores mortas onde brasas frias vagam à noite. | 0.266, 0.702 |
| Remanso da Iara | Masmorra | 25–35 | não alcançada | Um palácio afogado no fundo do rio; o canto que sobe dele confunde os barqueiros. | 0.283, 0.880 |
| Toca do Mapinguari | Masmorra | 30–40 | não alcançada | Pegadas enormes levam a uma gruta no coração da mata. O cheiro chega antes do dono. | 0.395, 0.800 |
| Vagão Adormecido | Masmorra de mistério | 40–55 | não alcançada | Um vagão de trem do Outro Lado, coberto de raízes, com o relógio parado nas 18h40. | 0.420, 0.748 |

#### Reino das Mouras (Portugal) — `mouras`

*Muralhas caiadas, azulejos e fontes onde mouras encantadas fiam ouro ao luar.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Fiandouro** | Capital | — | não alcançada | Cidade de muralhas brancas e azulejos azuis; o fio de ouro das mouras é o seu brasão. | 0.455, 0.435 |
| Vila das Andorinhas | Vila | — | não alcançada | Aldeia de pescadores com barcos pintados de olhos na proa. | 0.375, 0.470 |
| Cais das Naus | Porto | — | não alcançada | Estaleiros de onde saem as naus que cruzam o Mar do Meio. | 0.430, 0.515 |
| Olival dos Ventos | Campo de caça | 10–20 | não alcançada | Olivais retorcidos e moinhos de vento; bichos pequenos e travessos. | 0.400, 0.370 |
| Serra dos Cardos | Campo de caça | 20–30 | não alcançada | Encostas secas de cardos e pedras soltas, com lobos nas cristas. | 0.475, 0.385 |
| Cova da Moura Encantada | Masmorra | 25–35 | não alcançada | Uma fonte guardada por uma moura que fia ouro; quem cobiça o tesouro fica preso ao fio. | 0.478, 0.490 |
| Toca da Coca | Masmorra | 30–40 | não alcançada | O ninho da dragoa das lendas do reino, cheio de cascas de ovo e escamas verdes. | 0.392, 0.508 |
| Cabo do Gigante | Chefe | 40–50 | não alcançada | Adamastor, o gigante de pedra do cabo, ergue tempestades contra os navios. | 0.372, 0.430 |

#### Costa das Colunas (Grécia antiga) — `colunas`

*Colunas brancas, teatros voltados para o mar e ilhas cheias de monstros de lenda.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Heptástila** | Capital | — | não alcançada | A cidade das sete colunas brancas, com teatros de pedra voltados para o Mar do Meio. | 0.565, 0.455 |
| Ilha dos Figos | Vila | — | não alcançada | Casinhas brancas e figueiras: parada obrigatória dos barcos do Mar do Meio. | 0.585, 0.705 |
| Olivais do Promontório | Campo de caça | 10–20 | não alcançada | Terraços de oliveiras onde pastam cabras de chifres de bronze. | 0.600, 0.555 |
| Recifes das Sereias | Campo de caça | 20–30 | não alcançada | Ilhotas de pedra onde cantos trazidos pelo vento desviam os barcos. | 0.515, 0.665 |
| Labirinto do Minotauro | Masmorra | 25–40 | não alcançada | Corredores que mudam de lugar; só sai quem leva um fio. | 0.535, 0.420 |
| Gruta das Estátuas | Masmorra | 30–40 | não alcançada | Estátuas de rostos assustados demais para serem obra de escultor. Não olhe nos olhos dela. | 0.705, 0.700 |
| Pântano da Hidra | Chefe | 40–50 | não alcançada | Numa ilha de juncos, a serpente de muitas cabeças renasce a cada golpe descuidado. | 0.730, 0.645 |

#### Areias do Nilo (Egito antigo) — `areias`

*Dunas douradas, um rio verde e as pirâmides que o povo do rio ergueu pedra por pedra.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Sesháris** | Capital | — | não alcançada | A cidade dos escribas, à beira de um rio verde no meio das dunas. | 0.830, 0.745 |
| Oásis das Tamareiras | Vila | — | não alcançada | Poços frescos e caravanas descansando à sombra das tamareiras. | 0.870, 0.722 |
| Vale das Pirâmides | Marco | — | não alcançada | As pirâmides erguidas pelos construtores de Sesháris; suas paredes contam a história do povo do rio. | 0.860, 0.800 |
| Delta dos Juncos | Campo de caça | 10–20 | não alcançada | Canais de papiro, íbis e hipopótamos mal-humorados. | 0.735, 0.835 |
| Dunas do Escorpião | Campo de caça | 20–30 | não alcançada | Dunas altas onde escorpiões do tamanho de carroças caçam ao entardecer. | 0.800, 0.875 |
| Galerias da Esfinge | Masmorra | 30–45 | não alcançada | Quem entra precisa responder aos enigmas da esfinge, ou se perde para sempre nas galerias. | 0.895, 0.855 |
| Fenda de Apep | Chefe | 45–55 | não alcançada | A serpente das trevas que, nas histórias, tenta engolir o sol ao fim de cada dia. | 0.905, 0.735 |
| Cápsula da Estrela Caída | Masmorra de mistério | 50–65 | não alcançada | Uma cápsula de metal queimado no alto de uma duna, ainda piscando luzes que ninguém entende. | 0.925, 0.800 |

#### Império de Jade (China) — `jade`

*Terraços de arroz, bambuzais que cantam e montanhas verdes onde a fera do Ano-Novo dorme.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Mil Degraus** | Capital | — | não alcançada | Capital em terraços, subindo a montanha degrau por degrau, cheia de lanternas e casas de chá. | 0.625, 0.335 |
| Porto dos Juncos | Porto | — | não alcançada | Juncos de velas vermelhas trazem chá, seda e fogos de artifício. | 0.735, 0.575 |
| Ponte das Nove Curvas | Marco | — | não alcançada | Uma ponte em zigue-zague sobre o desfiladeiro. Dizem que monstros só andam em linha reta. | 0.665, 0.430 |
| Terraços do Arrozal | Campo de caça | 10–20 | não alcançada | Terraços alagados que refletem o céu; sapos gordos e raposas espirituais. | 0.600, 0.395 |
| Bambuzal Sussurrante | Campo de caça | 20–30 | não alcançada | Um bambuzal tão alto que o vento toca música nele. | 0.735, 0.470 |
| Vale dos Saltadores | Masmorra | 30–40 | não alcançada | Mortos-vivos de túnica que andam aos saltos; só sinos e lanternas os fazem parar. | 0.785, 0.370 |
| Covil do Nian | Chefe | 40–50 | não alcançada | A fera do Ano-Novo desce das montanhas; só o vermelho e o barulho a espantam. | 0.695, 0.280 |
| Jardim do Autômato Paciente | Masmorra de mistério | 50–65 | não alcançada | Um jardim perfeito no alto da montanha, cuidado há trezentos anos por mãos de metal. | 0.800, 0.170 |

#### Ilhas do Sol Nascente (Japão) — `sol`

*Ilhas vulcânicas de cerejeiras, pontes vermelhas e picos onde os tengu desafiam os ousados.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Akarimachi** | Capital | — | não alcançada | A Vila das Lanternas: casas de madeira e papel, pontes vermelhas e cerejeiras. | 0.872, 0.428 |
| Vila do Kappa | Vila | — | não alcançada | Aldeia de pescadores onde os kappa trocam remédios para ossos por pepinos. | 0.900, 0.315 |
| Praia das Raposas | Campo de caça | 10–20 | não alcançada | Areia negra e raposas que trocam de forma ao luar. | 0.915, 0.440 |
| Passo dos Oni | Campo de caça | 20–30 | não alcançada | Trilhas de lava fria onde os oni de chifre torto cobram pedágio. | 0.875, 0.575 |
| Monte do Tengu | Masmorra | 30–40 | não alcançada | Pilares de pedra onde os tengu de nariz comprido desafiam quem ousa subir. | 0.880, 0.370 |
| Ilha do Orochi | Chefe | 40–50 | não alcançada | Uma serpente de oito cabeças e oito caudas dorme enrolada no vulcão. | 0.888, 0.512 |

#### Fiordes de Gelo (Noruega e Islândia) — `fiordes`

*Geleiras, auroras e salões de madeira onde as sagas são cantadas junto ao fogo.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Lumefiorde** | Capital | — | não alcançada | Salões de madeira com fogueiras sempre acesas, no fundo de um fiorde azul. | 0.400, 0.285 |
| Vila das Auroras | Vila | — | não alcançada | Casas de turfa no gelo, onde o céu dança em verde nas noites longas. | 0.300, 0.340 |
| Geleira Uivante | Campo de caça | 10–25 | não alcançada | Um mar de gelo onde o vento uiva como lobo. | 0.330, 0.245 |
| Pinheiral dos Trolls | Campo de caça | 20–30 | não alcançada | Pinheiros escuros onde trolls viram pedra ao primeiro raio de sol. | 0.440, 0.215 |
| Túmulos dos Draugr | Masmorra | 30–40 | não alcançada | Montes de pedra onde os mortos das sagas ainda guardam seus tesouros. | 0.265, 0.205 |
| Covil do Lindworm | Masmorra | 35–45 | não alcançada | Uma serpente-dragão sem asas dorme sob a geleira, enrolada no próprio frio. | 0.370, 0.135 |
| Fenda do Lobo Acorrentado | Chefe | 45–55 | não alcançada | Fenrir, o lobo do tamanho de uma colina, puxa correntes presas no fundo do gelo. | 0.405, 0.195 |
| Casco Preso no Gelo | Masmorra de mistério | 50–65 | não alcançada | O casco negro de um navio que anda debaixo d'água, preso numa geleira há sessenta invernos. | 0.255, 0.290 |

#### Estepe de Ferro (povos eslavos) — `estepe`

*Bosques de bétulas, isbás entalhadas e contos de feiticeiros imortais e pássaros de fogo.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Zharogrado** | Capital | — | não alcançada | Cidade de isbás entalhadas e torres de madeira, cercada por paliçadas e campos de girassol. | 0.505, 0.265 |
| Isbá dos Pés de Galinha | Masmorra | 25–40 | não alcançada | A cabana da Baba Yaga anda pelo bosque; ninguém a encontra duas vezes no mesmo lugar. | 0.540, 0.210 |
| Bosque das Bétulas | Campo de caça | 10–20 | não alcançada | Bétulas brancas e clareiras de flores; lobos cinzentos e plumas de fogo no chão. | 0.478, 0.185 |
| Colinas de Ferro | Campo de caça | 20–30 | não alcançada | Colinas escuras de minério onde o vento arrasta a neve de lado. | 0.495, 0.340 |
| Ninho do Zmey | Masmorra | 35–45 | não alcançada | O dragão de três cabeças faz ninho nos picos brancos. | 0.600, 0.155 |
| Castelo de Koschei | Chefe | 45–55 | não alcançada | O feiticeiro imortal esconde a própria morte numa agulha, dentro de um ovo, dentro de um pato... | 0.447, 0.325 |
| A Antena que Escuta | Masmorra de mistério | 50–65 | não alcançada | Uma enorme concha de metal virada para o céu, no meio do bosque, zumbindo sozinha à noite. | 0.572, 0.245 |

#### Brumas Verdes (Irlanda e Escócia) — `brumas`

*Ilhas de colinas verdes e névoa, onde harpas choram e cavalos d'água convidam a montar.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Dúnbruma** | Capital | — | não alcançada | Fortaleza de pedra verde no alto de um morro, sempre envolta em névoa. | 0.215, 0.228 |
| Porto das Focas | Porto | — | não alcançada | Onde as selkies deixam a pele na praia para dançar em forma de gente. | 0.085, 0.250 |
| Colinas da Névoa | Campo de caça | 10–20 | não alcançada | Colinas de urze e muros de pedra; ovelhas que somem na névoa e voltam diferentes. | 0.140, 0.225 |
| Lago do Kelpie | Campo de caça | 20–30 | não alcançada | Um cavalo d'água convida os viajantes a montar e mergulha com eles. | 0.205, 0.445 |
| Estrada do Cocheiro sem Cabeça | Masmorra | 30–40 | não alcançada | Uma carruagem negra passa à meia-noite; o cocheiro carrega a própria cabeça. | 0.160, 0.160 |
| Olho de Balor | Chefe | 45–55 | não alcançada | O gigante de um olho só: quando a pálpebra se abre, tudo o que ele olha queima. | 0.195, 0.125 |
| Oficina das Horas Tortas | Masmorra de mistério | 50–65 | não alcançada | Uma máquina de latão e vidro no meio de um círculo de pedras; lá dentro os relógios andam para trás. | 0.100, 0.430 |

#### Selvas de Obsidiana (México antigo) — `obsidiana`

*Selva fumegante, vulcões e cidades de pirâmides escalonadas erguidas pelo povo da selva.*

| Lugar | Tipo | Níveis | Estado | Gancho | Posição (x, y) |
|---|---|---|---|---|---|
| **Itzcalli** | Capital | — | não alcançada | Cidade de pirâmides escalonadas, jardins flutuantes e mercados de cacau, erguida pelo povo da selva. | 0.125, 0.650 |
| Mercado das Penas | Vila | — | não alcançada | Vila de artesãos de plumas, jade e obsidiana. | 0.095, 0.690 |
| Trilha dos Jaguares | Campo de caça | 10–20 | não alcançada | Trilhas sob a copa, onde olhos amarelos acompanham cada passo. | 0.178, 0.660 |
| Manguezal Esmeralda | Campo de caça | 20–30 | não alcançada | Raízes altas sobre a água verde, caranguejos-armadura e garças de crista. | 0.200, 0.745 |
| Poço das Mil Vozes | Masmorra | 30–40 | não alcançada | Um poço natural de água azul; lá embaixo, a água responde com a voz de quem já passou. | 0.130, 0.720 |
| Boca do Vulcão Fumegante | Chefe | 45–55 | não alcançada | Cipactli, o grande crocodilo da terra das lendas antigas, desperta dentro do vulcão. | 0.165, 0.585 |
| Nave Albatroz | Masmorra de mistério | 50–65 | não alcançada | Um navio que navegava no céu, encalhado na copa das árvores, ainda estalando relâmpagos. | 0.225, 0.622 |

#### Mares, ilhas, desenhos e terras além do mapa

| Elemento | Tipo | Texto | Posição (x, y) |
|---|---|---|---|
| Mar do Meio | Mar | O mar calmo no centro do mundo, cheio de ilhotas e rotas de comércio. | 0.600, 0.765 |
| Mar das Brumas | Mar | Águas frias e cinzentas; a névoa esconde ilhas que não estavam lá ontem. | 0.060, 0.330 |
| Mar das Pétalas | Mar | Na época da Florada, pétalas douradas boiam nestas águas sem ninguém saber de onde vêm. | 0.200, 0.835 |
| Mar do Sol Nascente | Mar | Correntes quentes que levam às ilhas vulcânicas do leste. | 0.815, 0.675 |
| Arquipélago dos Mil Recifes | Ilha | Ninguém nunca contou as ilhotas. Os barqueiros dizem que algumas mudam de lugar. | 0.540, 0.770 |
| Ilha do Farol Torto | Ilha | Um farol inclinado que ilumina para o lado errado: e mesmo assim ninguém naufraga. | 0.245, 0.922 |
| Baleia-Ilha | Desenho de monstro | Uma baleia que dorme há tanto tempo que os marinheiros a desenham como ilha. | 0.142, 0.790 |
| Serpente-Pato | Desenho de monstro | Cabeça de pato, corpo de serpente, humor péssimo. Os pescadores juram que existe. | 0.085, 0.565 |
| Sapo-Gigante do Mar | Desenho de monstro | Um sapo do tamanho de um barco, que boia de olhos abertos à espera de moscas grandes. | 0.160, 0.880 |
| Baleia-Velha e a Enguia de Tinta | Desenho de monstro | Uma baleia cansada carrega nas costas uma enguia negra que cospe tinta nos navios. | 0.640, 0.805 |
| Serpente das Brumas | Desenho de monstro | Enrolada numa ilhota, só aparece quando a névoa fica azul. | 0.112, 0.370 |
| Fera da Charneca | Desenho de monstro | Um bicho negro que os pastores do reino desenham para assustar as crianças. Talvez seja filhote da Coca. | 0.415, 0.470 |
| Galeão Errante | Desenho de monstro | Um navio que ninguém tripula e que sempre chega um dia antes da tempestade. | 0.463, 0.855 |
| Revoada dos Corvos de Ferro | Desenho de monstro | Pássaros escuros que voam para o leste antes de cada inverno. | 0.925, 0.130 |
| Norte Nublado | Terra além do mapa | Terra ainda não alcançada. Além das nuvens do norte, os mapas ficam em branco. | 0.500, 0.075 |
| Além do Sol Nascente | Terra além do mapa | Terra ainda não alcançada. Ninguém que navegou para lá voltou para contar. | 0.935, 0.595 |
| Areias Sem Fim | Terra além do mapa | Terra ainda não alcançada. Dizem que o deserto do sul não termina nunca. | 0.600, 0.935 |
<!-- GERADO-FIM -->

---

## 4. Masmorras de mistério: os Viajantes que vieram antes

**Regra (GDD §4.0.1, obrigatória):** os monumentos e as cidades são **sempre obra dos povos** de cada região. O que é estranho vem de **Viajantes perdidos de outras épocas e de outros mundos**, que caíram pela Florada antes do jogador. A tecnologia deles ficou para trás, quebrou, "bebeu Eco" (ver lore §6) e virou masmorra. Nunca "alienígenas construíram X"; nunca um povo retratado como incapaz ou primitivo. Em todas as histórias, **o povo local acolhe, ensina e registra** o Viajante perdido.

Cada masmorra de mistério traz um pedaço da pergunta que o jogo não responde por completo: *por que a Florada chama gente de fora, e de quando?* Juntas, formam uma linha de quests de temporada ("os diários dos que vieram antes").

| Masmorra | Região | Níveis | Quem caiu aqui | A história | O que tem lá dentro |
|---|---|---|---|---|---|
| **Vagão Adormecido** | Terra de Pindorama | 40–55 | Os passageiros do **Noturno das 18h40**, um trem de passageiros do Outro Lado de uns noventa anos atrás, e o maquinista **Seu Aristides**. | O vagão atravessou a Florada inteiro e parou no meio da mata. Os barqueiros do Porto do Despertar resgataram os passageiros, que viraram gente da cidade: por isso o povo do porto sabe receber Viajantes e usa a palavra. O relógio do vagão parou na hora da travessia. | Corredores de vagão tomados por raízes; malas e lanternas que "lembram" os donos (monstros de memória); o apito do trem chama o chefe: o **Maquinista de Brasa**, a caldeira que bebeu Eco demais. |
| **Oficina das Horas Tortas** | Brumas Verdes | 50–65 | **Professor Honório Valença**, relojoeiro e inventor de uma época de lampiões a gás. | Construiu uma máquina para ver o futuro; no meio do salto, a Florada a puxou para cá. Caiu no meio de um **círculo de pedras erguido pelos antepassados do povo das Brumas**, cujo calendário de pedra ele passou anos estudando e admirando (os cadernos dele elogiam a precisão). A máquina ainda vaza tempo. | Salas em que o tempo anda para trás ou repete; inimigos que voltam alguns segundos; cópias atrasadas do próprio grupo. Chefe: **O Pêndulo**, a máquina desperta. |
| **Casco Preso no Gelo** | Fiordes de Gelo | 50–65 | A tripulação do **Narval**, um navio que anda debaixo d'água, de um Outro Lado de uns sessenta invernos atrás. | Emergiu debaixo da geleira e ficou preso. O povo de Lumefiorde abrigou os doze tripulantes nos salões; alguns ficaram e ensinaram a consertar motores, outros aprenderam as sagas. O diário de bordo está em Lumefiorde. | Corredores de metal congelados, portas estanques, luzes vermelhas; o frio e o Eco criaram criaturas de gelo no casco. Chefe: o **Polvo Branco** abraçado ao casco. |
| **A Antena que Escuta** | Estepe de Ferro | 50–65 | **Doutora Vera Lune**, astrônoma que estudava sinais do céu num observatório do Outro Lado. | A grande concha de metal do observatório atravessou junto com ela. As tecelãs e os marceneiros de Zharogrado a ajudaram a firmar a antena no bosque. Ela descobriu que a Florada tem um "som" e passou a vida anotando-o: **os cadernos dela são a melhor pista sobre a origem da Florada** (gancho de temporada; não responder no MVP). | A antena ainda escuta e atrai criaturas que seguem o som; andaimes viram trilhas no alto; sala de máquinas que zumbe. Chefe: **Coro de Estática**, uma revoada de pássaros de fogo presa no sinal. |
| **Jardim do Autômato Paciente** | Império de Jade | 50–65 | **Jardineiro Sete**, um autômato cuidador de um mundo do futuro onde não havia mais ninguém para cuidar. | Caiu há trezentos anos. Os calígrafos e jardineiros de Mil Degraus lhe ensinaram a escrever com pincel, a podar e a fazer chá; ele é gentil e ainda cuida de um jardim perfeito. Mas os pequenos ajudantes dele beberam Eco e saíram do controle. | Terraços de jardim com ajudantes mecânicos enlouquecidos. O Jardineiro Sete é **NPC** (pede ajuda); o chefe é o **Enxame de Podadeiras**. |
| **Cápsula da Estrela Caída** | Areias do Nilo | 50–65 | **Comandante Dalva Siqueira**, astronauta de um Outro Lado de um futuro próximo. | Na volta para casa, a cápsula entrou na Florada e caiu nas dunas. Os escribas de Sesháris a acolheram; ela se espantou ao ver que **os mapas do céu dos escribas eram mais precisos que os dela** e passou a estudar com eles. A voz de bordo da cápsula, **CORA**, continua ligada e tenta "consertar" o deserto. | Corredores de metal meio enterrados; robôs de areia montados por CORA; tempestades de areia dentro da masmorra. Chefe: **CORA desperta** (resolver em vez de destruir pode ser uma quest). |
| **Nave Albatroz** | Selvas de Obsidiana | 50–65 | **Capitã Rosália Ventania** e sua tripulação, de **outro mundo** (não da Terra) onde navios voavam com balões de gás e relâmpago preso em garrafas. | A nave rasgou o céu na Florada e encalhou na copa da selva. O povo de Itzcalli resgatou a tripulação, que aprendeu a viver na selva e ensinou a remendar velas. O motor ainda solta raios. | Conveses pendurados entre as árvores; pontes de corda; criaturas feitas de relâmpago. Chefe: o **Motor Trovejante**. |

Todas começam como "terra ainda não alcançada". Ordem sugerida de abertura: a do Brasil (Vagão Adormecido) junto com a expansão pós-MVP da Terra de Pindorama; as outras junto com cada região.

---

## 5. Mares, ilhas, desenhos de monstros e terras não alcançadas

As tabelas geradas no fim da seção 3 listam posições e textos. Resumo:

**Mares:** Mar do Meio (centro, rotas de comércio), Mar das Brumas (noroeste), Mar das Pétalas (sudoeste; pétalas douradas boiam nele na época da Florada) e Mar do Sol Nascente (leste).

**Ilhas:** Arquipélago dos Mil Recifes (ilhotas que "mudam de lugar"), Ilha do Farol Torto, além das ilhas de cada região (Brumas, Sol Nascente, Ilha dos Figos, Pântano da Hidra).

**Terras ainda não alcançadas (bordas do mapa):** Norte Nublado, Além do Sol Nascente e Areias Sem Fim. Servem de gancho para regiões futuras (ex.: novas nações em temporadas).

**Desenhos de monstros na arte** (os "supostos monstros" dos cartógrafos; podem ou não existir):

| Desenho | Onde | Pode virar monstro de verdade? |
|---|---|---|
| **Baleia-Ilha** | Mar das Pétalas | Sim: **chefe de evento** mundial (a "ilha" acorda); ótimo para temporada. |
| **Serpente-Pato** | costa oeste da Selva | Sim: monstro raro e engraçado de praia (fofo + ameaçador, GDD §17.0.1). |
| **Sapo-Gigante do Mar** | sudoeste | Sim: elite de manguezal (Selvas ou Pindorama). |
| **Baleia-Velha e a Enguia de Tinta** | Mar do Meio | A enguia sim (monstro de navegação); a baleia fica como NPC/paisagem. |
| **Serpente das Brumas** | ilha da Oficina das Horas Tortas | Sim: monstro de campo das Brumas (aparece com a névoa azul). |
| **Fera da Charneca** | Reino das Mouras | Sim: filhote da Coca (estágio Normal da espécie da dragoa, GDD §10.6). |
| **Galeão Errante** | Mar do Meio, perto da foz do grande rio | Talvez: masmorra-navio fantasma pós-MVP (sem piratas reais nem tragédias reais). |
| **Revoada dos Corvos de Ferro** | nordeste | Só decoração (ou mensageiros de quest). |

---

## 6. Como o mapa funciona no jogo (resumo técnico)

- Tecla **M** abre/fecha o atlas em tela cheia (Esc também fecha). O mapa grande da área atual, do agente N, ficou em **Shift+M**.
- Arrastar com o mouse ou setas/WASD: mover. Roda ou +/−: zoom. 0: centralizar. Sem sons de interface.
- Rótulos de regiões e lugares desenhados pela engine (chaves `WA_*`), com contorno legível sobre o pergaminho; lugares não alcançados aparecem esmaecidos. Dica ao passar o mouse: nome, tipo, região, níveis recomendados, estado e gancho.
- **"Você está aqui":** o atlas pergunta primeiro ao gancho do agente N (`NetWorld.get_world_place_id()` ou a propriedade `NetWorld.world_place_id`, se existirem); senão usa `NetWorld.client_map_id` e procura o lugar com aquele `map_id` (Campo de Treino → `training_field`, Porto do Despertar → `city_awakening`).
- Dados: `game/data/world/atlas.tres` (`WorldAtlasDef`) + `game/data/world/regions/<id>.tres` (`WorldRegionDef` com `WorldPlaceDef`).

---

## 7. Perguntas em aberto (para o dono)

1. Qual nome do mundo: **Contária**, **Achadouro** ou **Ecoar**? (ou nenhum, e fica "o mundo dos Viajantes")
2. Aceita as alternativas de nome de região (seção 2) ou mantém as do GDD?
3. As masmorras de mistério podem virar a linha de temporada "os diários dos que vieram antes", com os cadernos da Doutora Vera Lune como a pista principal da Florada?
4. Cipactli, Apep, Fenrir e Balor passam no `check-names` só com aviso (sensíveis). Mantemos como chefes (como no GDD) ou trocamos por nomes descritivos ("o Crocodilo da Terra", "a Serpente do Crepúsculo", "o Lobo Acorrentado", "o Gigante de Um Olho")?
5. O Campo de Treino foi posto no planalto verde ao lado das chapadas, virado para o Mar do Meio (de onde se veem todas as nações). Tudo bem, ou ele deve ficar numa ilha própria no meio do mar?
