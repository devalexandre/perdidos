# Próximos passos — Marco "Passeio no Porto do Despertar" (PC)

> Versão 1 — 27/09/2026. Complementa `docs/plano-mvp.md` e o GDD.
> Decisão do dono: **primeiro PC (Windows e Linux), Android depois do primeiro playtest.**

## 1. Objetivo

Abrir o jogo no PC, entrar na primeira cidade e **passear por ela com outros jogadores**:
- ouvir a trilha sonora e o ambiente;
- conversar com os moradores e os Mestres;
- comprar um item na loja, abrir o inventário e equipar a primeira arma;
- sentar num mirante, usar emotes e conversar no chat local.

Tudo construído com **mecânicas reutilizáveis**, que servirão sem retrabalho para os mapas de caça, o combate e as quests das próximas fases.

### Critério de pronto

0. **Obrigatório:** a cidade e toda área jogável no estilo de cenário do GDD §17.0.A (pintado à mão, como nas referências do dono). Mapa no estilo antigo = marco não entregue.

1. Um build de PC exportado (Windows e Linux) e um servidor rodando. Um jogador novo vai da tela de título até a cidade sem ajuda.
2. O jogador acorda nas docas, anda pela cidade e ouve música, ambiente e passos que mudam conforme o chão (pedra, madeira, grama).
3. Pelo menos **8 NPCs** com arte no estilo aprovado e diálogo; alguns andam pela cidade.
4. A loja vende e compra itens com a moeda Estrelas. O inventário tem 40 espaços e o equipamento muda os atributos.
5. Chat local, nome sobre a cabeça, 6 emotes e sentar nos 3 mirantes.
6. O visual da cidade está próximo da Âncora 4 (praça, ipê, cristal, casario, feira, docas).
7. **Teste com 5 pessoas por 30 minutos, sem quedas.**

### Fora deste marco

Contas e banco de dados (Fase 2), combate, monstros, quests completas e interface de toque. O inventário fica salvo só no servidor local por enquanto; o banco entra na Fase 2 sem mudar a interface do sistema.

## 2. Mecânicas reutilizáveis (arquitetura)

Princípios, que valem para todo o jogo:
- **Dados fora do código:** todo conteúdo é um `Resource` em `game/data/` (GDD §0).
- **Composição:** comportamentos são nós-componente anexados às entidades, não heranças profundas.
- **Servidor autoritativo:** o cliente só manda intenções (`req_*`) e o servidor valida e decide (GDD §15.2).
- **Mesmo padrão em todo lugar:** um mesmo componente serve para jogador, NPC e, depois, monstro.

| Sistema | O que é | Reusado depois em |
|---|---|---|
| **`NetEntity` + `EntitySpawner`** | Base de toda entidade em rede. Tem `entity_id`, `instance_id`, posição interpolada e visual direcional (a partir do `PlayerEntity` atual). | NPCs, monstros, drops, túmulos, projéteis |
| **`NavMover`** (componente) | Movimento por navmesh no servidor, com velocidade e `facing`. Extraído do código do jogador. | NPCs, monstros, investida da skill L2 |
| **`Interactable`** (componente) | Clicar → andar até o alcance → `req_interact` → o servidor valida a distância → dispara a ação. Tipos: falar, loja, sentar, portal, pegar. | Mestres de quest, drops, túmulo, portais dos mapas de caça |
| **`DialogueDef` + `DialogueRunner`** | Diálogo em dados: falas, opções e condições (nível, item, quest). O texto sai de chaves de tradução. | Quests com Mestres, tutorial, a fala "Volte quando conhecer 2 técnicas" |
| **`NpcDef`** | Nome, aparência (folhas de sprite), diálogo, rotina (parado, vagar numa área ou seguir pontos) e loja opcional. | Todos os NPCs de todas as regiões |
| **`ItemDef` + `ItemStack`** | Definição do item: ícone, tipo, espaço de equipamento, atributos, raridade, se empilha (até 99) e preço. | Drops, túmulo, armazém, loja, recompensas de quest |
| **`Inventory`** (componente de servidor) | Contêiner genérico com N espaços: adicionar, remover, mover e dividir pilhas, com replicação só para o dono. | Inventário (40), armazém (60), loja do NPC, túmulo |
| **`Equipment` + `Stats`** | 7 espaços (GDD §11.1). Recalcula os atributos derivados (§6.4 e §10.2) e expõe hooks para o visual (paper doll) e para `should_drop_on_death` (§12.4). | Combate, morte, cosméticos |
| **`AudioDirector`** | Música por mapa ou zona com transição suave, som ambiente em camadas, passos por tipo de chão, efeitos por evento e volumes separados. Tudo configurado em `AudioZoneDef`. | Todos os mapas, tema do chefe, combate |
| **`ChatService`** | Canais (local, grupo, sussurro), limite de 1 msg/s, filtro de palavrões e bloqueio. | Fase 2 (grupo e amigos) |
| **`Nameplate` + `EmoteBubble`** | Nome e balões sobre a entidade, em pixel art. | NPCs, monstros (barra de vida) |
| **`UIKit`** | Painéis 9-slice, janela arrastável, grade de itens com dica, barra de atalhos. | Toda a interface do jogo |
| **`GameSettings`** | Resolução, tela cheia, volumes e teclas; salvo por jogador. | Tudo |

Todas as novas mensagens de rede seguem a tabela §15.4 (`req_interact`, `req_use_item`, `req_equip`, `req_chat`...) com validação e limite de taxa já existentes.

## 3. Conteúdo

### 3.1 NPCs da cidade (idle e walk, 5 direções, mesmo pipeline do Viajante)

| NPC | Onde | Função | Rotina |
|---|---|---|---|
| **Mestra Brisa Ferrenha** | Casa dos Mestres | Lâmina (as quests entram na Fase 4). Por enquanto, apresentação e dica. | Parada |
| **Mestre Orvalho** | Casa dos Mestres | Arcano (idem). Luzes flutuando ao redor. | Parado |
| **Mercador da feira** | Barraca principal | **Loja**: poções, armas e roupas iniciais; compra itens do jogador. | Parado |
| **Barqueiro das docas** | Píer central | Recebe o Viajante que acorda nas docas (início do tutorial §9.3). | Parado |
| **Vendedora de frutas** | Feira | Diálogo de ambientação (lendas da região). | Vaga pela feira |
| **Guarda do portão** | Portão norte | Explica os mapas de caça ("Recomendado: nível 1–10"). O portal fica fechado neste marco. | Patrulha curta |
| **Pescador** | Píer norte | Conversa e dica de mirante. | Sentado |
| **Criança curiosa** | Praça | Corre ao redor do ipê e comenta sobre o cristal. | Vaga pela praça |

Os nomes e falas são provisórios (GDD §9.2). As regras culturais do §4.0 valem para todos: inspiração, sem caricatura.

### 3.2 Itens iniciais (~16, ícones 32x32, pipeline da Âncora 5)

| Tipo | Itens |
|---|---|
| Consumíveis | Poção de vida pequena e média, poção de mana pequena e média (a recarga de 10 s já fica definida, mesmo sem combate) |
| Armas | Facão, espada curta, cajado de madeira, varinha de ipê |
| Mão secundária | Escudo de couro, tomo simples |
| Cabeça / corpo / pés | Chapéu de palha com flor, gibão de couro, botas de caminhada |
| Acessórios | Colar de sementes, pulseira de fita |
| Outros | Folha Rodopiante (item de venda, prepara os drops) |

**Atualizado (27/09):** o equipamento e os cosméticos **mudam a aparência** já neste marco (roupa, chapéu e arma visíveis; um cosmético de exemplo, a coroa de flores de ipê, dado pela criança da praça). Detalhes técnicos no adendo 1 de `contracts-city-walk.md`.

### 3.3 Trilha sonora e áudio (GDD §18)

Direção musical: **fantasia medieval com alma brasileira**. Instrumentos acústicos (viola caipira, rabeca, flautas de bambu, pífano, zabumba e pandeiro suaves, harpa), melodias modais e clima acolhedor. Loops de 2 a 3 minutos.

| Faixa | Clima | Uso |
|---|---|---|
| Tema de título | Esperançoso, curioso ("fui arrancado do meu mundo") | Tela de título e criação |
| Porto do Despertar — dia | Calmo, alegre, com cheiro de feira | Cidade |
| Porto do Despertar — docas | Variação mais leve, com água | Zona das docas (transição suave) |

**Ambiente:** rio, vento no ipê, burburinho da feira, gaivotas e sinos de barco.

**Efeitos:**
- passos em pedra, madeira e grama;
- abrir e fechar interface, clique, comprar e vender, equipar, pegar item;
- mensagem de chat, emote, sentar;
- zumbido do cristal (som posicional).

**Fonte do áudio — decidido em 27/09/2026:** música, ambiente e efeitos gerados com **ElevenLabs** (plano pago, licença comercial), a partir do catálogo `game/tools/audio/sound_catalog.json` e do script `game/tools/audio/gen_audio.py`. Até a chave estar configurada, o jogo usa a versão CC0 provisória já instalada (registrada em `assets/audio/LICENSES.md`).

Toda faixa e todo efeito são registrados com fonte e licença em `assets/audio/LICENSES.md`.

### 3.4 Arte da cidade

- Passe visual guiado pela Âncora 4: cores da paleta v2, luz de fim de tarde, menos névoa, calçada em escala menor, copa do ipê mais cheia e fachadas com mais detalhe.
- Props pequenos como sprites: vasos, caixotes de frutas, lampiões, redes de pesca e flores.
- Animação `sit` do Viajante (1 quadro × 5 direções) para os mirantes.
- 6 emotes (acenar, sentar, rir, chorar, raiva, coração).
- Kit de interface PC: painéis, botões, grade do inventário, janela de loja, caixa de diálogo, chat e cursores.

## 4. Organização do trabalho (3 agentes, como na Fase 1)

| Agente | Responsável por |
|---|---|
| **A — Sistemas e servidor** | `NetEntity`/`NavMover` (refatorando o `PlayerEntity`), `Interactable`, NPCs no servidor, `Inventory`/`Equipment`/`Stats`, loja, `ChatService`, persistência local, testes automáticos |
| **B — Cliente e interface** | `UIKit`, janelas (inventário, loja, diálogo, chat, configurações), `Nameplate`/`EmoteBubble`, tela de título e criação, `AudioDirector`, `GameSettings`, export de PC |
| **C — Conteúdo e arte** | NPCs (arte + `NpcDef` + diálogos), itens (ícones + `ItemDef`), passe visual da cidade, props, `sit`, emotes, kit de UI, áudio (conforme a fonte escolhida) |

O contrato entre os agentes fica em `docs/contracts-city-walk.md`, escrito antes de começar, como na Fase 1.

## 5. Cronograma

| Semana | Período | Entregas | Esforço |
|---|---|---|---|
| **1** | 28/09 → 04/10 | Contratos; refatoração para `NetEntity`/`NavMover`/`Interactable`; `ItemDef`/`Inventory`; início do `UIKit`; 2 Mestres e o mercador (arte); paleta v2; direção musical e fonte de áudio decididas | ~35 h |
| **2** | 05/10 → 11/10 | NPCs no servidor com rotina; `DialogueRunner` e caixa de diálogo; loja e inventário jogáveis; `AudioDirector` com música provisória; +5 NPCs (arte); 16 ícones | ~40 h |
| **3** | 12/10 → 18/10 | `Equipment`/`Stats`; chat local, nomes e emotes; sentar; tela de título e criação simples; passe visual da cidade; música e efeitos finais | ~40 h |
| **4** | 19/10 → 25/10 | Tutorial curto nas docas (acordar → andar → falar → comprar → equipar); configurações; export Windows/Linux; teste com 5 pessoas; correções | ~30 h |
| **5** | 26/10 → 01/11 | Aparência visível: roupas, chapéu e armas em camadas; cosmético de exemplo; ajustes finais e teste com 5 pessoas | ~30 h |
| **Marco** | **01/11/2026** | **Passeio no Porto do Despertar (PC)** | **~175 h** |

## 6. Decisões do dono antes de começar

1. ~~**Fonte da trilha sonora**~~ — decidido: ElevenLabs (falta configurar a chave do plano pago).
2. **Aprovar o Viajante v2** que já está no jogo.
3. **Nomes dos NPCs:** usar os provisórios desta lista ou definir os seus.
4. **Teste com 5 pessoas:** quem participa (Discord ou canal do YouTube?).

## 7. Impacto no plano geral

Este marco substitui o **M0** de `plano-mvp.md` e adianta partes da Fase 3 (itens, inventário e equipamento) e da Fase 4 (diálogo e NPCs), que ficam prontas como mecânicas reutilizáveis.

| Marco | Novo prazo |
|---|---|
| Passeio no Porto do Despertar (PC) | 01/11/2026 (+1 semana pela aparência visível) |
| F2 — Base online (contas, banco, grupos, instâncias) | 22/11/2026 |
| F3 — Combate e mundo | 17/01/2027 (com a pausa de fim de ano) |
| F4 — Progressão | 21/02/2027 |
| F5 — Deploy e polimento **(PC)** | 21/03/2027 |
| Folga | → 18/04/2027 |
| M1 — Chegada do Viajante (cinemática + tutorial + combate básico + evolução de monstros) | 22/11/2026 |
| **Playtest fechado no PC** | **até 09/05/2027** (ver `plano-mvp.md`) |
| Android (interface de toque, build, desempenho) | Depois do playtest, estimativa de 4 a 6 semanas |

**Para não gerar retrabalho no Android depois:**
- Toda entrada continua passando pelas ações do `InputMap`, e o toque já existente no `ClientView` fica como está.
- A interface usa âncoras e escala e não depende de hover para funcionar.
- O áudio e a arte já respeitam os limites de memória de celular.
