# Ficha da região — Terra do Sabiá (Brasil)

Ficha exigida pelo GDD §4.0, regra 5. Status: `[PROVISÓRIO]`. Serve de base para mapas, monstros, Mestres,
itens, música e arte da região do MVP. Qualquer conteúdo novo da região deve ser conferido contra esta
ficha e contra as regras culturais do GDD §4.0.

## 1. País de inspiração

Brasil. Fantasia medieval "com alma brasileira": a região mistura uma cidade murada de sabor medieval com
a arquitetura colonial luso-brasileira, a fauna e a flora do cerrado e da mata, e as lendas do folclore
popular. **Inspiração, não caricatura**: nada de estereótipos de povos, sotaques ridicularizados ou
"Brasil de cartão-postal" (sem carnaval genérico, futebol ou bandeiras).

## 2. Lendas usadas e fontes (domínio público)

Só usamos as **lendas tradicionais** (patrimônio oral coletivo), nunca versões autorais modernas
(personagens de livros, TV, quadrinhos ou animações — p.ex. nada do "Sítio do Picapau Amarelo").

| Lenda | Uso no jogo | Registros antigos / domínio público |
|---|---|---|
| **Boitatá** (serpente de fogo que protege os campos) | Chefe da Chapada; é "enfurecido" pela fumaça das queimadas e, ao ser vencido, adormece — respeita o papel de protetor | José de Anchieta, *Carta de São Vicente* (1560), que registra o "baetatá"; tradição oral do Sul e Sudeste |
| **Curupira** (guardião da mata, pés virados) | NPC guardião da Mata Encantada, **não** inimigo | Anchieta, *Carta de São Vicente* (1560); Couto de Magalhães, *O Selvagem* (1876) |
| **Saci** (menino travesso de gorro vermelho que vive nos redemoinhos) | Inspira o monstro fraco *Redemoinho Arteiro* (redemoinho de folhas com gorrinho) — o Saci em si não é morto | tradição oral do Sudeste; inquérito popular de 1917–1918 publicado em livro em 1918 (autor falecido em 1948, obra em domínio público no Brasil); usar só os relatos populares, não personagens autorais |
| **Lobisomem** (homem que vira lobo em noites de lua) | Monstro *Lobisomem Jovem* (Mata) | tradição ibero-brasileira; Sílvio Romero, *Contos Populares do Brasil* (1883) |
| **Corpo-Seco** (morto que nem a terra aceita, seco como galho) | Monstro *Corpo-Seco* (Mata) | tradição oral do interior de SP e MG |
| **Iara / Ipupiara** (ser das águas) | Reservada: possível NPC/quest do rio (não inimiga no MVP) | Pero de Magalhães Gândavo, *História da Província de Santa Cruz* (1576), que descreve o "ipupiara" |
| **Mula sem Cabeça** | Reservada para um arco de maior escala; não usar na Caverna do Reino Encoberto. Se entrar, tratar como criatura de fogo, sem referência a padres ou pecado | tradição oral ibero-brasileira |
| **Mapinguari** | Reservado para região/expansão amazônica | tradição oral da Amazônia |

Criaturas "de fauna" (Tatu-Pedra, Vaga-lume Encantado, Harpia da Tempestade inspirada no gavião-real)
são invenções originais do projeto.

### Caverna do Reino Encoberto — quatro pisos implementados

A primeira aventura é uma investigação curta oferecida pelo guarda do Portão Norte. Pegadas no Bosque das Raízes levam a uma câmara sob a Mata; lá, o Viajante ouve um uivo vindo de uma passagem mais profunda e volta para avisar a guarda. A história termina nesse indício, sem afirmar que o Lobisomem foi encontrado ou derrotado.

A caverna segue `docs/mundo/arquitetura-masmorras-e-cavernas.md`: F1 (12–16) tem setores oeste/leste; F2 (16–20), corredores labirínticos; F3 (20–24), passarelas sobre o abismo e câmaras laterais; F4 (25–30), covil do Lobisomem com escolta e forma atroz noturna. Cada piso tem cena e navegação próprias. As descidas e subidas alternativas têm chegadas separadas; a Fenda de Luz do F4 só permite voltar à superfície após a derrota do chefe na instância compartilhada. Esse desbloqueio dura até reiniciar o servidor. Os minimapas vêm da grade caminhável. A missão `cave_root_howl` mantém os rastros na floresta e o marcador `CaveHowl` no F1.

**Beta fechado (02/10/2026):** o sprite original da Fera da Mata (estágios 1–4), o Coronel Tobias, Marcelina e o Curupira foram adicionados. A investigação mantém o gate de três pistas. A Rota A oferece uma provação exclusiva contra o estágio 3 durante a noite de lua cheia e concede um Causo ao entregar o final. B e C têm versões resumidas: encruzilhada + retorno a Marcelina; três observações lunares + oferenda + retorno ao Curupira. Os sprites desses três NPCs ainda usam folhas de reserva.

**Ainda pendente no arco narrativo completo:** Corpo-Seco, NPC Eustáquio no sítio, Capitão Eugênio, itens/ingredientes do ritual, imobilização e combate não letal, mini-quest do Curupira, mini-chefe dos caçadores, títulos/skills provisórios e consequências persistentes no mundo. A passagem para "outro reino" segue como rumor ficcional, sem atribuição cultural não validada. A Mula sem Cabeça permanece reservada para um arco maior.

**Regras culturais aplicadas (GDD §4.0):**

- Figuras de religiões vivas (orixás, entidades da umbanda/candomblé, divindades indígenas cultuadas hoje,
  santos católicos) **nunca** são monstros nem piada. Igrejas e capelas podem aparecer só como cenário, com
  respeito.
- Povos indígenas e afro-brasileiros não são "tema exótico" nem inimigos; elementos de origem tupi (nomes
  como *ipê*, *buriti*, *igarapé*, *Boitatá*) são usados como parte natural do mundo.
- Escravidão, genocídio indígena, ditadura e outras tragédias reais **não** viram inimigos, chefes ou humor.
- A queimada entra como ameaça ambiental (causa da fúria do Boitatá), sem culpar grupos reais.

## 3. Arquitetura de referência

- **Casario colonial luso-brasileiro** (cidades históricas como Ouro Preto, Paraty, São Luís, Salvador,
  Olinda): paredes caiadas de branco ou em cores pastel, **cunhais** (pilastras de canto), beirais brancos,
  **telhados de telha capa-e-canal** alaranjada, **janelas e portas com molduras coloridas**, sacadas de
  madeira, **faixas e painéis de azulejo azul e branco**, chaminés.
- **Calçada portuguesa em ondas** (pedrinhas claras e escuras) na praça central.
- Toque medieval de fantasia: **muralha baixa de pedra com torres e portões em arco** (para os mapas de
  caça e a arena), cais de madeira, lampiões.
- Feira livre: bancas de madeira com **toldos listrados**, caixotes de frutas (manga, laranja, banana,
  maracujá, açaí/uva), ervas em vasos; palmeiras em vasos de barro.
- Natureza: **ipê amarelo gigante** na praça, ipês roxos, rio largo com **barcos de vela**.

## 4. Paleta regional (subconjunto da paleta mestra)

Todas as cores vêm de `assets/_reference/style_anchor/paleta-mestra.gpl` (50 cores; também são subconjunto
da proposta v2 de 85 cores). Uso preferencial na região:

| Papel | Rampa / cores |
|---|---|
| Ipê amarelo, flores, ouro do círculo mágico | Ouro/amarelo `#a8741e` `#e6b43a` `#fae58c` |
| Telhas, cumeeira, toldos vermelhos | Vermelho `#9c2a26` `#d9553a` `#f59a6a` |
| Azulejos, cristal, céu | Azul céu `#1c2a5a` `#2f55a8` `#5a90e0` `#a8d4f5` |
| Rio, toldos verde-água, molduras | Verde água `#2a6e6e` `#4fa8a0` `#9ee0c8` |
| Mata, grama, palmeiras | Verde folha `#2f6b3e` `#5aa048` `#a6d86a` |
| Paredes caiadas, pedra clara | Pergaminho `#c9b08a` `#f2e6c8` + Base `#fcfaf5` |
| Calçamento, muralha | Pedra/metal `#56505e` `#8c8794` `#c7c3cc` |
| Madeira de bancas, cais, barcos | Madeira `#3a2418` `#6b4226` `#9c6a3c` `#c9985e` |
| Ipê roxo, detalhes de molduras | Roxo `#8e66c4` `#c9a8ec`, Rosa `#a8406a` `#e07aa0` |

A luz da região é de **fim de tarde**: sol quente vindo de cima-esquerda, sombras longas, ambiente frio
azulado, névoa rosada leve no horizonte.

## 5. Clima musical

- **Cidade (Porto do Despertar):** choro e seresta calmos — violão de 7 cordas, cavaquinho, flauta;
  andamento tranquilo, acolhedor.
- **Campos do Sabiá:** baião leve / toada de viola caipira, triângulo e zabumba suaves; canto de sabiá e
  bem-te-vi no ambiente.
- **Mata Encantada:** sons de mata (sapos, cigarras, igarapé), rabeca e flautas misteriosas, percussão
  grave.
- **Chapada do Céu Partido:** tema épico com pífanos e zabumba, cordas em crescendo; luta contra o Boitatá
  com percussão forte (maracatu-style de baque, sem samplear gravações existentes).
- **Arena da Queimada:** percussão seca, rabeca tensa.

Tudo composto do zero; nenhum trecho de música existente.

## 6. Monstros (GDD §10.3)

Redemoinho Arteiro (Campos, 1–3), Vaga-lume Encantado (Campos, 2–5), Tatu-Pedra (Campos, 5–9),
Lobisomem Jovem (Mata, 9–14), Corpo-Seco (Mata, 12–17), Harpia da Tempestade (Chapada, 17–23).
Arco de maior escala, pós-MVP: Mula sem Cabeça (reservada; não usar na caverna da Mata).

## 7. Chefe

**Boitatá** (Chapada, nível 25): serpente gigante de fogo laranja e azul, enfurecida pela fumaça das
queimadas; derrotá-lo o faz **adormecer** (chamas que se apagam), não "morrer" — mantém o respeito ao
papel de protetor dos campos. 3 fases (GDD §10.4).

## 8. Mestres (GDD §9.2)

- **Mestra Brisa Ferrenha** — Escola da Lâmina, na Casa dos Mestres (cidade).
- **Mestre Orvalho** — Escola do Arcano, na Casa dos Mestres (cidade).
- **Velho Aroeira** — Lâmina avançada, no ponto mais alto da Chapada.
- **Irmã Estela** — Arcano avançado, na chapada escondida. (Apesar do título "Irmã", é uma eremita
  astrônoma, sem vínculo com ordem religiosa real.)
- **Curupira** — guardião da mata (NPC de quests futuras).

## 9. Skills

Escolas gerais do MVP com sabor regional nos nomes (GDD §8):
Lâmina — Golpe Firme, Investida, Giro de Aço, Postura de Ferro, Corte do Horizonte.
Arcano — Faísca, Rajada Gélida, Chama Rastejante, Barreira Arcana, Queda Estelar.
Variações regionais futuras (pós-MVP): golpes de facão "Roçada", magia de "fogo-fátuo" (fogo azul do
Boitatá/Corpo-Seco).

## 10. Armas e itens típicos

**Facão** (arma de lâmina inicial), **borduna** (clava de madeira, origem indígena — tratada com respeito,
sem pinturas ou grafismos de povos específicos), **bodoque** (estilingue de arco), cajado de madeira com
cristal azul, chapéu de palha com flor (acessório de cabeça), gibão de couro (armadura leve).

## 11. Marcos do Porto do Despertar (mapa `city_awakening`)

Praça em calçada portuguesa com o **ipê amarelo gigante** e o **cristal azul** (renascimento) sobre um
círculo mágico dourado; feira de frutas e ervas na praça; **Casa dos Mestres** (sobrado com torre e
painéis de azulejo, noroeste da praça); casario colorido; cais com 3 píeres e barcos de vela no rio (leste);
portões: norte → Campos do Sabiá, sul → Mata Encantada/Chapada, oeste → Arena da Queimada.
Pontos de vista (GDD §17.11): ponta do píer principal, banco da praça olhando o ipê, prainha ao norte.
