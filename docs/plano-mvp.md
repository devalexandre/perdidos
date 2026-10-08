# Plano até o playtest fechado do MVP

> Base: GDD §19 (fases e critérios de pronto) e o estado do projeto em 27/09/2026.
> Ritmo assumido: 1 pessoa com 10 a 15 h/semana (o dono do projeto) + agentes de IA fazendo a implementação.
> As horas abaixo são **esforço total** (agentes + revisão do dono). O prazo é o que limita: revisão, aprovação de arte e testes em aparelho real dependem do dono.

## Resumo

> **Atualizado em 27/09/2026:** decisão do dono de rodar primeiro no PC; Android fica para depois do playtest. O M0 virou o marco "Passeio no Porto do Despertar" — detalhes em `docs/proximos-passos.md`.

| Marco | Período | Semanas | Critério de pronto |
|---|---|---|---|
| **M0 — Passeio no Porto do Despertar (PC)** | 28/09 → 01/11/2026 | 5 | `proximos-passos.md` §1: cidade jogável com NPCs, loja, inventário, aparência visível, áudio, chat e emotes; **movimento clássico por células** |
| **M1 — Chegada do Viajante** | 02/11 → 22/11/2026 | 3 | Cinemática da travessia + área de tutorial (GDD §9.3) com comandos, itens, **combate básico**, 1 monstro com os **3 estágios de evolução** (§10.6) e a lore; termina nas docas da cidade |
| **F2 — Base online** | 23/11 → 20/12/2026 | 4 | Grupos diferentes no mesmo mapa de caça não se veem; na cidade todos se veem; progresso salvo no PostgreSQL após reiniciar o servidor |
| Pausa de fim de ano | 21/12/2026 → 03/01/2027 | 2 | — |
| **F3 — Combate e mundo** | 04/01 → 07/02/2027 | 5 | Loop completo nos 3 mapas de caça + PVP: caçar, drop, equipar, morrer, recuperar túmulo; os 6 monstros com 3 estágios e bando do chefe |
| **F4 — Progressão** | 08/02 → 14/03/2027 | 5 | Jogador novo vai do nível 1 ao 25 aprendendo skills só por quests |
| **F5 — Deploy e polimento (PC)** | 15/03 → 11/04/2027 | 4 | 20 testadores simultâneos no PC por 2 h sem queda |
| Folga (20%) | 12/04 → 09/05/2027 | 4 | — |
| **Playtest fechado (PC)** | **até 09/05/2027** | | ~7,5 meses — dentro da estimativa de 6 a 9 meses do GDD |
| Android | depois do playtest | 4–6 | Interface de toque, build Android, desempenho |

> Atualizado em 27/09/2026: entraram o movimento clássico por células, a cinemática, a área de tutorial e a evolução dos monstros (GDD §9.3, §10.1, §10.6). O M1 adianta parte da F3 (combate básico e o sistema de evolução), por isso a F3 encolheu de 6 para 5 semanas.

Arte roda em paralelo a todas as fases (trilha própria abaixo), sempre um passo à frente do código que vai usá-la.

## O que já está pronto (27/09/2026)

- Fase 1 técnica: servidor headless autoritativo, 2+ clientes se vendo, clique para mover no navmesh, 8 direções a partir de 5, câmera orbital, renderização pixel-perfect 960x540, filtro de instância no servidor, recusa de versão. Testes automáticos passando.
- Cidade Porto do Despertar jogável (layout, navmesh, colisão, pontos de vista), ainda com visual de rascunho.
- Pipeline de arte com IA (Bria → recorte → redução → quantização) e Viajante masc./fem. com idle e walk nas 5 direções, no estilo da inspiração.
- Ficha da região Brasil (`game/data/regions/brasil.md`).

## Trilha de código

### M0 — Passeio no Porto do Despertar (≈ 145 h — detalhado em `proximos-passos.md`; a tabela abaixo é o subconjunto de polimento da Fase 1)
| Tarefa | Esforço |
|---|---|
| Passe visual da cidade guiado pela Âncora 4 (cores, luz, névoa, calçada, copa do ipê) | 10 h |
| Ajustes de câmera/zoom com a arte nova, pé do sprite alinhado à sombra | 3 h |
| Aplicar paleta v2 às texturas | 3 h |

### F2 — Base online (≈ 85 h)
| Tarefa | Esforço |
|---|---|
| API de contas (register/login/refresh/characters) + JWT curto + argon2 | 16 h |
| PostgreSQL: esquema §15.5 + migrações | 8 h |
| Tela de login e criação de personagem (§6.1, troca de cor por shader) | 14 h |
| Persistência do personagem (salvar nos eventos do §15.5 + a cada 60 s) | 10 h |
| Grupos: convidar, aceitar, sair, expulsar, liderança; regra de reconexão de 3 min | 12 h |
| Instâncias de caça por líder, ciclo de vida (5 min), troca de mapa por portal | 10 h |
| Chat (local, grupo, sussurro), filtro, 1 msg/s; amigos e bloqueio | 12 h |
| Mapa de caça 1 (Campos de Pindorama) em graybox para testar instâncias | 3 h |

### F3 — Combate e mundo (≈ 120 h)
| Tarefa | Esforço |
|---|---|
| Mapas: Campos de Pindorama (12 h), Mata Encantada (14 h), Chapada do Céu Partido — vitrine (20 h), Arena da Queimada (6 h) | 52 h |
| IA de monstros (ocioso → patrulha → perseguição → ataque → retorno), spawn e respawn | 12 h |
| Ataque básico, fórmulas §10.2, alvo, números de dano | 10 h |
| Tabelas de drop, itens no chão, moeda Estrelas | 8 h |
| Inventário (40), equipamento (7 espaços), raridades | 14 h |
| Morte e Marca da Alma: túmulo no banco, visível em qualquer instância, job de expiração, regras PVP | 14 h |
| HUD: vida/mana, barra do grupo, alvo | 6 h |
| Métricas de mortes por mapa e recuperação de túmulos | 4 h |

### F4 — Progressão (≈ 95 h)
| Tarefa | Esforço |
|---|---|
| Nível, XP (inclusive em grupo), atributos e distribuição de pontos | 8 h |
| 10 skills com mira de área, cone e linha, conjuração, recarga | 30 h |
| `SkillProgression` por uso + barra de 8 atalhos | 8 h |
| Sistema de quests (derrotar, coletar, explorar, conversar, provação) + 10 quests | 24 h |
| 4 Mestres com diálogos + tutorial nas docas | 12 h |
| Loja de NPC, armazém da conta, poções | 10 h |
| Revisão de textos pt_BR | 3 h |

### F5 — Deploy e polimento no PC (≈ 64 h; Android sai do MVP-PC: +26 h depois do playtest)
| Tarefa | Esforço |
|---|---|
| VPS São Paulo: Docker Compose, Caddy, UFW, fail2ban, backup diário, staging | 14 h |
| Eventos de métricas (retenção, sessão, quests, skills) | 6 h |
| Chefe Boitatá com 3 fases | 16 h |
| Teste de carga com 20 clientes por 2 h | 6 h |
| Correções e polimento | 22 h |

## Trilha de arte (paralela)

Aprendizado da produção do Viajante: uma personagem com idle e walk em 5 direções levou ~2 h de trabalho com agente e ~150 chamadas ao Bria. **A limpeza manual no Aseprite (GDD §17.5, passo 5) é trabalho humano** e entra no tempo do dono (ou de um artista, se houver).

| Pacote | Necessário para | Esforço (IA + limpeza) | Prazo |
|---|---|---|---|
| Fechar âncoras (Tatu-Pedra, ícones, praça) + paleta v2 | M0 | 6 h | 04/10/2026 |
| Viajante: attack, cast, hit, death, sit (2 corpos × 5 direções) | F3 | 20 h | 01/11/2026 |
| Cabelos (8) e olhos em camadas com troca de cor; 3 roupas iniciais (§17.4, alternativa do MVP) | F2 (criação) | 24 h | 25/10/2026 |
| 4 Mestres + ~6 moradores + lojista (idle e walk) | F4 | 30 h | 20/12/2026 |
| 6 monstros comuns (idle, walk, attack, hit, death) | F3 | 48 h | 29/11/2026 |
| Chefe Boitatá (7 animações, 240x240) | F5 | 20 h | 31/01/2027 |
| Texturas (~15), objetos de cenário (~60), 4 céus | F3 | 36 h | 06/12/2026 |
| Ícones (~70 itens + 10 skills) | F3/F4 | 12 h | 13/12/2026 |
| VFX (10 skills + impacto, cura, nível, morte, Marca da Alma) | F4 | 18 h | 24/01/2027 |
| Kit de interface PC + mobile, 6 emotes | F2–F5 | 20 h | 21/02/2027 |
| Música (7 faixas) e efeitos sonoros | F5 | 14 h | 28/02/2027 |

## Totais

| Trilha | Esforço |
|---|---|
| Código | ≈ 410 h |
| Arte e áudio | ≈ 250 h |
| **Total** | **≈ 660 h** |

Com agentes fazendo a maior parte da implementação, o tempo do dono fica em revisão, aprovação, limpeza de arte e testes. Isso é o que sustenta o calendário de ~28 semanas.

## Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| Consistência da arte gerada por IA entre quadros (animações de ataque/morte são mais difíceis que andar) | Alto | Gerar sempre por edição a partir do quadro aprovado; paleta única por personagem; reservar tempo de limpeza manual |
| Tempo de limpeza no Aseprite maior que o previsto | Alto | Aceitar arte provisória até a F4 (GDD §19); considerar um artista freelancer só para limpeza |
| Custo das chamadas ao Bria | Médio | Medir custo por personagem; gerar variações só em pranchas de aprovação |
| Desempenho em Android (sprites + 3D + névoa) | Médio (depois do playtest) | Manter entradas via InputMap e UI sem hover; perfil de qualidade para mobile quando o Android entrar |
| Escopo crescer além do §3.1 | Médio | Qualquer item fora do MVP vai para a lista pós-playtest |

## Decisões pendentes do dono

1. Aprovar o Viajante v2 (masculino #3 e feminino #11 da `prancha-personagens-v2.png`, que já estão no jogo) ou escolher outros números.
2. Aprovar a paleta v2 (`paleta-mestra-v2-proposta.gpl`) depois de refeita a partir das âncoras v2.
3. Linguagem da API de contas (GDD §15.6 deixa a critério). Sugestão: Go.
4. Quem faz a limpeza manual da arte: o dono ou um freelancer.

## Avaliação: monstros e cenários com Blender (entrou em 27/09/2026)

O Blender 5.2.2 já está no projeto (`.tools/blender`), rodando sem janela, com renderização e exportação glTF testadas.

| Etapa | O que fazer | Quando |
|---|---|---|
| 1. Critérios | Checklist do que é "atende a especificação": GDD §17.0.1 (DNA visual), §17.0.A (cenário pintado, obrigatório), §17.2 (tamanhos), §10.2.1 (combate vivo e tamanhos relativos), §10.6 (3 estágios distintos) | depois da entrega do Agente V |
| 2. Auditoria | Prancha de cada monstro (9 estágios de Pindorama + 18 das outras nações) e de cada zona/mapa, comparada às referências do dono; nota por item: **mantém / ajusta / redesenha** | 1 dia |
| 3. Protótipo de monstro em Blender | Pegar 1 monstro (Tatu-Pedra, os 3 estágios) e fazer em 3D estilizado no Blender, renderizado **para sprite pixel art** nas 5 direções e com todas as animações (câmera no ângulo do jogo, redução e quantização iguais às do Viajante). Comparar lado a lado com o sprite atual feito pela IA de imagem | 2–3 dias |
| 4. Protótipo de cenário | Peças que os pacotes CC0 não têm (ipê, buriti, cupinzeiro, casario colonial, cristal, marcos das nações) feitas em Blender com as texturas pintadas | junto com o Agente V |
| 5. Decisão do dono | Se o 3D→sprite for melhor: consistência entre direções e animações, estágios de evolução (mesmo modelo, maior e mais ameaçador), custo por monstro. Senão, seguir com a IA de imagem e só corrigir o que a auditoria apontar | depois do protótipo |
| 6. Aplicação | Redesenhar só o que for marcado "redesenha", começando pelos monstros do Campo de Treino e da Terra de Pindorama | a estimar após a decisão |

**Por que avaliar:** com a IA de imagem, cada direção e cada quadro é gerado separado, e isso já causou problemas de consistência (direções trocadas, poses diferentes entre animações). Com um modelo 3D no Blender, todas as direções e animações saem do mesmo modelo, sempre coerentes, e os 3 estágios podem ser variações do mesmo modelo. O risco é perder o traço "desenhado à mão"; o protótipo serve para medir isso antes de decidir.

## Dia e noite (entrou em 27/09/2026 — GDD §10.7)

| Etapa | O que fazer | Quando |
|---|---|---|
| 1. `WorldClock` | Hora do mundo no servidor, sincronizada com os clientes; ciclo configurável | F3 |
| 2. Visual | Céu, sol/lua, luz, névoa, luzes de janelas e lampiões; música noturna por região | F3 |
| 3. Monstros noturnos | Espécies/variantes noturnas por região (+30% a +50%), troca de spawns ao anoitecer | F3 (arte: pipeline de monstros, avaliar Blender) |
| 4. Forma atroz dos chefes | Arte, habilidades e +100% à noite (Boitatá primeiro) | F4/F5, junto com o Boitatá |
| 5. Quests de dia/noite | Condição `time_of_day` nas quests e diálogos | F4 |

Impacto estimado: +2 semanas no total (distribuídas entre F3 e F4).

## Aparição dos chefes por caça (entrou em 27/09/2026 — GDD §10.6.1)

| Etapa | O que fazer | Quando |
|---|---|---|
| 1 | Contador de abates por espécie e por mapa/instância no servidor; aviso na instância ao chegar perto e quando o chefe surge | F3 |
| 2 | Surgimento do estágio 3 com bando ao atingir 500 abates; nunca em zona TRAINING | F3 |
| 3 | Covis fixos de cada chefe (Ninho do Boitatá primeiro) | F3/F5 |

## Revisão dos sons de armas (entrou em 28/09/2026)

Problema relatado pelo dono: o som do facão parecia "barra de metal" (provisório errado). Regra: **o som tem que combinar com o tipo de golpe da arma.**

| Categoria | Armas | Som esperado |
|---|---|---|
| Corte | facão, espada curta, espadas, machados | lâmina cortando (chop/slice), assobio de lâmina no balanço |
| Impacto | cajado, borduna, maças, desarmado | pancada seca de madeira/soco |
| Perfuração | lanças, flechas, bodoque | estocada/assovio de projétil |
| Mágico | varinha, tomo, cajado com cristal | faísca/brilho no acerto |

| Etapa | O que fazer | Quando |
|---|---|---|
| 1. Auditoria | Ouvir cada arma e cada skill no jogo (balanço, acerto, crítico, erro) e marcar o que não combina | já (itens atuais) |
| 2. Categoria nos dados | Campo `sound_category` no `ItemDef` como fallback quando não houver som próprio da arma | F3 |
| 3. Sons finais | Gerar no ElevenLabs os sons próprios de cada arma e skill do catálogo (precisa da chave com permissão de efeitos) | assim que houver a chave |
| 4. Regra para itens novos | Toda arma nova entra com categoria e seus sons (balanço/acerto) | sempre |
