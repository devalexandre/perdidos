# Pets e Montarias — Projeto Isekai

> **Versão:** 0.1 — 06/10/2026 (primeiro plano: companheiros de título, montaria básica, pets domesticáveis e técnica de alto nível). Nada disto está implementado.
> **Base:** GDD §3.2 (montarias e pets fora do MVP), §5, §10, §13, §14, §15, §17.3–17.4; TITULOS-E-SKILLS.md v0.6 (§1.4, §1.5, §3.1, §3.4, §5, §6).
> **Status:** tudo aqui é `[PROVISÓRIO]` até o dono aprovar. Regras herdadas do GDD e do TITULOS-E-SKILLS ficam `[FECHADO]`. As escolhas pendentes estão na seção 9, com o padrão recomendado.
> **Regra de ouro (GDD §0.5):** o Ragnarok é só referência de *sensação*. Nenhum nome de classe, skill, pet, item ou mecânica nominal dele entra no jogo. Os nomes daqui são originais e de trabalho, guardados em chaves de tradução.

---

## 0. Resumo

| Camada | O que é | Quando entra |
|---|---|---|
| **Companheiro de título** | Bicho ligado a um título, que se ganha numa **quest de vínculo** com o Mestre ou ancião. Tem 1 ou 2 skills de vínculo **fora da árvore de 5**, como os ofícios. Não pode ser alvo. | Fase 1: 3 companheiros |
| **Montaria** | Estado do jogador que reduz o `walk_ms_per_cell`. É de viagem: desmonta em combate. | Fase 1: 1 montaria básica para todos (Jumento do Sertão) |
| **Pet** | Monstro domesticado com item de captura e comida. Tem intimidade, fome, acessório, bônus pequeno e evolução cosmética. | Fase 2 |
| **Montaria rara e montaria de guerra** | Visual próprio por nação ou evento; a montaria de guerra fica em combate e é ligada a título de tanque. | Fase 3 |

**Princípios** `[PROVISÓRIO]`:
1. **O conteúdo é balanceado sem bicho.** O companheiro soma **no máximo 10–15%** do poder efetivo do título, ou só utilidade. Quem não fizer a quest de vínculo continua completo.
2. **Nada atrás de nível** (TITULOS §1.4, regra 5). O acesso vem por título, quest e renome (Causos).
3. **Reaproveitar a arte antes de criar.** A fase 1 só usa folhas de monstros que já existem. A única arte nova é a montaria.
4. **Nada é vendido por dinheiro real** (GDD §14). No máximo, há visual cosmético de algo já conquistado jogando.

---

## 0.1 Revisão de 08/10/2026 — companheiros que lutam e têm nível `[FECHADO — dono]`

O dono decidiu que o companheiro **ataca**, alguns **usam magias**, **sorte aumenta a chance de crítico** e eles **têm nível**. Isso substitui, para os companheiros de título, o princípio "sem criatura de combate autônoma" (seção 1) e o "nível fixo 1" (seção 2.1). Decisões tomadas junto:

- **XP do companheiro:** bônus de **+20% do XP do monstro**, só para ele, quando o monstro morre com o companheiro ativo e o dono participou. **Não sai do XP do dono.**
- **Não pode ser alvo**, não segura monstro, não recebe dano nem pega drop (como antes). O aggro do que ele acerta vai para o dono.

Desenho proposto `[PROVISÓRIO]` (números de partida, ajustáveis no `balance`):

| Item | Regra |
|---|---|
| Ataque automático | O companheiro ataca o **alvo atual do dono** (o último que o dono atacou) sozinho, com intervalo próprio. Fora de combate, só segue. Alcance por espécie: Harpia 6 células (mergulho), Guará 1 célula (mordida). |
| Quem ataca e quem lança magia | **Harpia:** ataque físico + magia. **Guará:** ataque físico + magia de controle. **Lume:** não ataca corpo a corpo; só **magias** (dano mágico de luz e suporte). |
| Dano | Base do companheiro pelo nível + uma fração do atributo do dono ligado ao título: Harpia **DES**, Guará **FOR**, Lume **INT**. Teto de equilíbrio: o companheiro rende **15–25% do dano do dono** no mesmo nível de equipamento. |
| Crítico | Chance = **1% + 0,3% × SOR do dono** (+ bônus por nível do companheiro), dano crítico pela regra de crítico do jogo. Quanto maior a sorte, mais crítico, como no Ragnarok. |
| Magias | 1 magia automática por companheiro no nível 1, mais 1 no nível 10 e outra no 25, cada uma com recarga própria. Exemplos: Harpia — *Rajada de Penas* (área pequena) e *Grito do Alto* (o alvo perde esquiva); Guará — *Uivo do Cerrado* (lentidão em área) e *Bote* (dano + atordoamento curto); Lume — *Centelha* (dano mágico), *Luz que Cura* (cura pequena no dono) e *Enxame* (área). As skills de vínculo atuais (passiva e ativa do dono) continuam. |
| Nível | **1 a 50**, com curva própria. Cada nível: + dano, + vida de referência para fórmulas, + crítico pequeno. Marcos **10 / 25 / 50**: magia nova e **evolução visual** (o companheiro cresce ou ganha detalhe, só cosmético). |
| Onde vale | Em todo lugar, inclusive masmorra; na Arena da Queimada (PVP), dano pela metade. |
| Interface | Nível e barra de XP do companheiro na janela de Seguidores e um medidor pequeno ao lado do retrato do dono. |
| Pets domesticáveis (seção 4) | Continuam como planejado (fase 2, sem combate); a decisão de combate vale para os **companheiros de título**. Se o dono quiser os pets domesticáveis lutando também, reavaliar depois. |

### 0.1.1 Implementado (08/10/2026) — números finais

Código: `CompanionService` (servidor), `CompanionDef` (campos de combate), `data/companion_skills/` (magias, `SkillDef` fora das skills do jogador, como `data/monster_skills/`), `Balance` (grupo "Companheiros que lutam"), `CharacterData.companion_progress` (save), `NetFollowers` (golpe do bicho), `FollowerVisual`, `FollowersWindow`, `PlayerBars`, `CombatFx`/`SkillFx`. Teste: `tests/progression/test_companion_combat.tscn`.

**Como funciona**

| Item | Implementação |
|---|---|
| Alvo | O do ataque básico do dono; se não houver, o último que o dono acertou nos últimos 6 s (`out_of_combat_sec`). Só com o dono **em combate**; fora disso o bicho só segue. Valem as regras do ataque (mesma instância, zona com combate, hostil, vivo, provação só do dono e do grupo). Não há linha de visão no servidor (as skills também não têm): o limite é a distância. O bicho não gasta as flechas do dono. |
| Alcance | Distância **dono → alvo** ≤ alcance do golpe + quanto o bicho se afasta do dono (+0,5 de folga). Harpia: 6 + 0 (mergulha do ombro). Guará: 1 + 5 (corre até o alvo e morde). Lume: 6 (só magias). |
| Dano | Pipeline normal (`CombatService.deal_damage`) com o **dono como atacante** e fonte `companion_<id>[:<magia>|:bond]`: defesa, ±10%, acerto pela DES do dono, números para todos. O `CompanionService.pre_hit` troca o ATK/ATQM pelo **poder do bicho**. As Crendices do dono, o crítico garantido e a quebra de invisibilidade **não** valem para o golpe do bicho. |
| Poder | `power_base + power_per_level × nível + attribute_frac × atributo do dono`. Harpia **3 + 1,0/nível + 0,4 × DES**; Guará **3 + 1,3/nível + 0,4 × FOR**; Lume **6 + 1,5/nível + 0,5 × INT**. |
| Golpe automático | Harpia: a cada **2,0 s**, 100% do poder, ignora **50% da DEF** (mergulho). Guará: a cada **1,8 s**, 100%. Lume: não ataca. |
| Crítico | **1% + 0,3% × SOR do dono + 0,1% × nível do bicho** (teto 100%), ×1,5 (`CombatRules.CRIT_MULTIPLIER`). Vale também para as magias de dano mágico do bicho (as mágicas do jogador seguem sem crítico). |
| Não é alvo | O bicho não é entidade do servidor: não recebe dano, não segura monstro, não pega drop. Aggro, dano para a posse do drop, crédito de quest e "primeiro golpe" são do **dono**. |
| PVP | Na zona `PVP` (Arena da Queimada) todo dano do bicho × **0,5** (`companion_pvp_damage_mult`). |
| Nível | **1 a 50**. XP para o próximo = **4 × nível^1,5** (nível 1→2: 4; 10→11: 126; 49→50: 1372; total até 50 ≈ 27,5 mil). |
| XP | Ao morrer um monstro, cada jogador creditado (dono do abate e grupo perto) **que bateu no monstro** e tem companheiro ativo dá ao bicho **20% do XP do monstro** (`companion_xp_share`), à parte. O XP do dono não muda (testado). |
| Marcos | **10 / 25 / 50**: 2ª magia no 10, 3ª no 25; evolução visual em cada marco. Sem arte nova: o bicho cresce **+8% de escala por marco** (0,70 → 0,756 → 0,812 → 0,868). O nível vai no `appearance` (`companion_level`). |
| Mensagens | "*Nome* subiu para o nível N!" e, no marco, "*Nome* cresceu!". |
| Interface | Janela de Seguidores: nível, barra de XP (turquesa), magias liberadas (dica com a descrição) e o nível da próxima magia. Medidor fino sob as barras do retrato (nome · Nv N). Números de dano do bicho em **turquesa** (crítico mais claro); o dono não anima nem avança no golpe do bicho. O bicho corre/mergulha até o alvo com a folha `attack`, toca `cast` (ou `attack`) nas magias, mostra o nome da magia acima dele e o efeito vem do `SkillFxBook` (só peças que já existiam). Rótulo do bicho: "Nome Nv N". |
| Protocolo | `protocol_version` 4 → **5** (o RPC do golpe do bicho mudou): cliente e servidor precisam ser atualizados juntos. |

**Magias** (recarga própria; uma ação por tique; liberadas nos níveis 1 / 10 / 25)

| Bicho | Nível 1 | Nível 10 | Nível 25 |
|---|---|---|---|
| Harpia | **Rajada de Penas**: 130% em área de 1,5 célula no alvo, recarga 9 s | **Grito do Alto**: 60% e −15% de esquiva por 6 s (= −15 DES no acerto), recarga 15 s | **Mergulho Real**: 220%, ignora toda a DEF, recarga 18 s |
| Guará | **Uivo do Cerrado**: lentidão de 30% por 3 s em 3 células, sem dano, recarga 14 s | **Bote**: 160% e atordoamento de 0,8 s, recarga 12 s | **Dentada Funda**: 200%, recarga 16 s |
| Lume | **Centelha**: 100% mágico, recarga 3 s (é o "ataque" da Lume) | **Luz que Cura**: cura 80% do poder no dono abaixo de 70% da vida, em combate, recarga 15 s | **Enxame**: 100% mágico em 2 células, recarga 12 s |

A Harpia e o Guará tinham só 2 magias na proposta; a 3ª (Mergulho Real, Dentada Funda) é nova, para cumprir "1 magia no nível 1, mais 1 no 10 e outra no 25".

**Skills de vínculo (sem duplicar com o golpe automático)**

- **Garra do Alto**: os mergulhos ignoram metade da DEF. No ataque básico com arco, a chance pela DES (4% + DES × 0,2%, teto 20%, recarga interna 1,5 s) agora **adianta o próximo mergulho** em vez de criar um golpe extra; o relógio do golpe recomeça e o adiantamento só vale se já passou metade do intervalo desde o último mergulho (`companion_bond_min_gap = 0,5`). Assim a harpia nunca bate duas vezes seguidas.
- **Mordida do Guará**: Tocaia e Armadilha de Cipó adiantam a próxima mordida (mesma regra), com lentidão de 20% por 2 s; recarga interna 4 s.
- Olho no Céu, Faro do Guará, Luz que Acompanha e Lume Guia não mudaram.

**Equilíbrio** (teste `_test_balance`: dono no nível L com 60% dos pontos no atributo principal e 10% em SOR/secundário, arma real da faixa; bicho no nível 2L − 1; dano do dono = ataque básico com crítico; 300 s simulados com o mesmo relógio do servidor, incluindo a Garra do Alto)

| Dono / bicho | 1/1 | 5/9 | 10/19 | 15/29 | 20/39 | 25/49 |
|---|---|---|---|---|---|---|
| Harpia | 18% | 21% | 18% | 21% | 21% | 19% |
| Guará | 15% | 17% | 17% | 19% | 20% | 17% |
| Lume | 15% | 19% | 18% | 22% | 21% | 19% |

Todos dentro de **15–25%**. Bicho com nível abaixo do "par" do dono rende menos (o poder cresce com o nível). O teto antigo de 10–15% (Princípio 1) vale só para pets.

**Como testar no jogo** (servidor com `--dev-commands`): `/dev leave_training`, `/dev companion pindorama_companion_harpy 25` (dá o título, o bicho e o nível), equipar arco, `/dev spawn_dummy` (boneco de 100 mil de vida) e atacar: a harpia mergulha a cada 2 s, solta Rajada/Grito/Mergulho Real com números turquesa. `/dev companion pindorama_companion_lume 10` e `/dev set_hp 30` para ver a Luz que Cura. `/dev kill maned_wolf 100` dá 20 XP ao bicho (o dono recebe os 100 dele).

**Limitações conhecidas**: sem linha de visão (só distância, como as skills); a posição do bicho é só do cliente (o servidor mede do dono); a evolução visual é escala (sem arte de estágio); os ícones das 6 skills de vínculo são cópias provisórias de ícones de skills parecidas (`assets/skills/`), e as magias do bicho não têm ícone (não vão para a barra); a Arena da Queimada ainda não existe nos dados, então o PVP só foi testado com uma zona de teste.

## 1. Referência: o que o Ragnarok tinha e por que funcionava

| Sistema (RO) | Como era | Por que funcionava | O que levamos |
|---|---|---|---|
| **Falcão do Caçador** | O falcão ficava no ombro. O *Blitz Beat* tinha chance automática a cada ataque básico com arco (chance pela SORTE), e havia uma versão ativa. O dano era pela DES/INT e ignorava a defesa. O falcão também detectava invisíveis e desarmava armadilhas. | Era identidade visual imediata: você via um caçador de longe. O ataque automático recompensava o ataque básico sem gastar a barra, e o falcão tinha utilidade além do dano. | Ataque automático com chance e recarga interna, batedor que revela invisíveis, identidade visual. |
| **Lobo (Warg) do Ranger** | Lobo que mordia sozinho, tinha skills de ordem e podia ser montado (exclusivo com o falcão). | Dava escolha de estilo dentro da mesma classe. | Duas linhas no arco: ave (precisão) **ou** bicho de chão (emboscada), uma por ramo. |
| **Peco Peco do Cavaleiro e do Templário** | Ave-montaria que dava mais velocidade e mais peso carregável. Reduzia a velocidade de ataque até treinar uma maestria e somava bônus com lança. | Velocidade era o luxo do meio do jogo, e a montaria era a silhueta da classe. | Montaria como estado com velocidade; a montaria de guerra fica só para títulos de tanque (fase 3). |
| **Carrinho do Mercador** | Inventário extra puxado pelo personagem, com custo de velocidade no início. Era a base da lojinha de rua e de uma skill de dano (Cart Revolution). | Era a fantasia de "caixeiro-viajante" e a logística do grupo. | Alforje do jumento (inventário extra), na fase 2 (questão 5). |
| **Homúnculo do Alquimista** | Criatura com nível, fome, intimidade, evolução e IA própria, controlada pelo dono. | Dava apego e progressão paralela, mas custava muito: IA, balanceamento e exploits (lutar com o homúnculo enquanto o dono fica longe). | Só a **ideia** de apego e evolução vai para os pets. **Não** teremos criatura de combate autônoma, porque o custo e o risco são altos. |
| **Pets domesticáveis** | Item de captura por espécie (minijogo de chance), ovo, comida própria e fome. A intimidade tinha 5 faixas, um acessório por espécie dava visual e o bônus pequeno vinha com intimidade alta. O nome podia ser trocado 1 vez, o ovo era negociável e a evolução veio depois. | Era coleção, apego e comércio: os ovos raros movimentavam a economia. O bônus pequeno não quebrava o jogo, e o pet não podia ser atacado. | Quase tudo, com fauna e folclore nossos (seção 4). |

**Lições**: (1) o bicho tem que ser **visível** e combinar com a roupa do título; (2) o dano automático precisa de **teto e recarga interna**; (3) o pet **não pode ser alvo** nem tanque; (4) o "carrinho" é logística, não combate.

---

## 2. Companheiros de título (fase 1 e seguintes)

### 2.1 Regras `[PROVISÓRIO]`

| Regra | Definição |
|---|---|
| Como se ganha | Uma **quest de vínculo** com o Mestre ou ancião do título, **depois** de conquistar o título. É solo, como a quest de título (TITULOS §1.4, regra 7). Não pede nível nem cresce com o número de títulos (é vínculo, não título). |
| Renome mínimo (`required_causos`) | Primeiro título: **2** (Falado). Ramo: **2**. Combinação (suporte e tanque): **5** (Assunto da Vila). |
| Onde vale | Em qualquer mapa, inclusive cidade e masmorra. **Fora do Campo de Treino:** a quest exige `left_training`. Na Arena da Queimada (PVP), o efeito automático vale pela metade (seção 5.4). |
| Quantos ativos | **1 companheiro de título por vez**, entre os que o personagem tem, de qualquer título conquistado (o título exibido é só cosmético). Trocar leva 2 s parado, fora de combate, com recarga de 60 s. |
| Skills de vínculo | **No máximo 2 por companheiro** (1 passiva + 1 ativa), **fora da árvore de 5**, no mesmo mecanismo do `TitleDef.bonus_skills` (ofícios, como Fazer Flechas). A passiva não ocupa a barra; a ativa disputa os 10 espaços, de propósito. Nível fixo 1 na fase 1 (questão 3). |
| Alvo e aggro | O companheiro **não pode ser alvo**, não recebe aggro, não tanka e não pega drop. Ele só aparece e dispara efeitos do dono. |
| Sem dono | Se o dono morre, o companheiro some e volta quando ele ressuscitar. Ao trocar de mapa, o companheiro vai junto. |
| Persistência | Fica salvo no personagem (seção 6.3). É **intransferível**: não entra em troca. |

### 2.2 Quem tem companheiro (Terra de Pindorama)

| Título (id) | Companheiro (id) | Folclore e fauna | Papel | Arte | Fase |
|---|---|---|---|---|---|
| **Gavião-Real** (`pindorama_bow_gaviao`) | **Harpia** (`pindorama_companion_harpy`) | A harpia (gavião-real) da Mata Atlântica e da Amazônia; a roupa do título já tem luva de falcoeiro (briefing de sprites) | Ataque automático e batedor aéreo | Sprite próprio 2D `harpy_companion` (harpia humanoide chibi, 08/10/2026), 70% | **1** |
| **Tocaia do Brejo** (`pindorama_bow_brejo`) | **Guará** (`pindorama_companion_guara`) | O lobo-guará do cerrado, que come lobeira (fruta-do-lobo) | Marca a presa e morde na emboscada | **Reaproveita** `maned_wolf` s1 | **1** |
| **Luz de Vaga-lume** (`pindorama_arcane_firefly`) | **Lume** (`pindorama_companion_lume`) | O enxame que reacendeu a forja do Seu Zé (lenda do §3.2) | Utilidade: luz e coleta, **sem dano** | **Reaproveita** `enchanted_firefly` s1 | **1** |
| **Olho do Boitatá** (`pindorama_arcane_boitata`) | **Fagulha do Boitatá** (`pindorama_companion_ember`) | A cobra de fogo que protege os campos | Disparo mágico automático | Reaproveita `cinder_serpent` s1 (Serpente-Fagulha) com recolor de brasa | 2 |
| **Raiz do Cerrado** (`pindorama_support_root`) e ramos | **Sabiá-laranjeira** (`pindorama_companion_thrush`) | A ave que dá nome à região | Descanso do grupo e alerta | **Nova** (ave pequena, barata) | 2 |
| **Assobio da Matinta** (`pindorama_support_matinta`) | **Rasga-mortalha** (`pindorama_companion_owl`) | A suindara, ave agourenta ligada à Matinta Pereira. **A Matinta nunca vira bicho de estimação.** | Prolonga o debuff e revela o alvo | **Nova** (coruja) | 2 |
| **Garra da Onça** (`pindorama_blade_jaguar`) | **Pintada** (`pindorama_companion_jaguar`) | A onça-pintada | Golpe em dupla no Bote | Reaproveita a folha de `pindorama_jaguar` (a mesma de `jaguar_cub`) | 2 |
| **Couro de Anta** (`pindorama_tank_anta`) | **Anta de Guerra** (montaria, `pindorama_mount_tapir`) | A anta, o maior bicho da terra | Montaria de guerra (seção 3.6) | **Nova e grande** | 3 |

A Seiva do Buriti herda o sabiá. O ramo de cura não ganha um segundo bicho.

### 2.3 Fichas da fase 1

#### Harpia — Gavião-Real (Mestre Taquari)

| Item | Definição |
|---|---|
| Quest de vínculo | **"Ninho na Sumaúma"** (`quest_bond_harpy`): (1) achar o ninho caído (conversa e inspeção); (2) juntar 6 **Penas de Gavião** pegas do chão (drop da Harpia Jovem, `harpy_eagle` s1); (3) derrotar 3 **Harpias Caçadoras** (`harpy_eagle` s2) que disputam o ninho; (4) dar nome ao filhote. Renome ≥ 2. |
| Passiva | **Garra do Alto** (`bow_companion_hawk_strike`): no ataque básico com arco, há chance de a harpia descer e causar **80% ATK físico ignorando 50% da DEF**. Chance = 4% + DES × 0,2%, teto de **20%**, recarga interna de **1,5 s**. |
| Ativa | **Olho no Céu** (`bow_companion_sky_eye`, mana 14, recarga 30 s): por 8 s revela, num raio de 12 células, monstros **raros** e alvos **invisíveis** (Lama no Corpo, Sumiço). O primeiro alvo atacado leva +10% de crítico contra ele. |
| Sinergia com a árvore | O **Mergulho do Gavião** (`bow_hawk_dive`) passa a mostrar a harpia mergulhando, só no visual. Não ganha número. |
| Equilíbrio | Ganho estimado de **+8 a 12%** de dano contínuo no ataque básico, sem efeito nas skills. Sem a harpia, o Gavião-Real continua sendo o melhor tiro único. |

#### Guará — Tocaia do Brejo (Mestre Taquari)

| Item | Definição |
|---|---|
| Quest de vínculo | **"Fruta-do-Lobo"** (`quest_bond_guara`): (1) juntar 8 **Lobeiras** (nova coleta de chão no cerrado); (2) seguir o rastro do guará (3 pontos de inspeção, de dia); (3) espantar 5 **Guarás da Alta Mata** (`maned_wolf` s2) que cercam o filhote; (4) deixar a lobeira e esperar 10 s parado e escondido (Lama no Corpo vale). Renome ≥ 2. |
| Passiva | **Mordida do Guará** (`bow_companion_guara_bite`): quando **Tocaia** ou **Armadilha de Cipó** acerta, o guará morde o alvo: **60% ATK** e lentidão de 20% por 2 s. Recarga interna de 4 s. |
| Ativa | **Faro do Guará** (`bow_companion_guara_track`, mana 10, recarga 25 s): marca 1 alvo por 15 s. O alvo marcado não fica invisível para o dono e aparece no minimapa. Fora de combate, o faro também mostra coletas de chão num raio de 10 células. |
| Equilíbrio | Ganho de **+6 a 10%** no ciclo de emboscada, mais controle leve. Dá identidade ao estilo "caçador com bicho de chão", sem aumentar o dano do tiro. |

#### Lume — Luz de Vaga-lume (Mestre Orvalho)

| Item | Definição |
|---|---|
| Quest de vínculo | **"Pote de Luz"** (`quest_bond_lume`): (1) **à noite**, juntar 10 **Luzinhas** (drop do Vaga-lume Encantado, `enchanted_firefly` s1); (2) trazer 1 **Pote de Vidro** comprado na vila; (3) soltar as luzes perto da forja do Seu Zé (causo curto). Renome ≥ 2 e já ter saído do Campo de Treino. |
| Passiva | **Luz que Acompanha** (`arcane_companion_lume_light`): um raio de luz de 4 células em cavernas e à noite, só visual (para o próprio jogador). O **Enxame de Vaga-lumes** ganha +1 luz, só no visual. |
| Ativa | **Lume Guia** (`arcane_companion_lume_guide`, sem mana, recarga 60 s): por 20 s, as coletas e os baús num raio de 15 células brilham. |
| Equilíbrio | **Zero dano.** É utilidade e conforto, coerente com o primeiro título. É o companheiro mais barato de fazer. |

### 2.4 Fichas da fase 2 (resumo)

| Companheiro | Passiva | Ativa | Teto |
|---|---|---|---|
| **Fagulha do Boitatá** | **Fagulha Errante**: quando uma skill mágica acerta, há 12% de chance de disparar uma fagulha de **50% MATK** de fogo (recarga interna de 2 s) | — | +6 a 9% |
| **Sabiá** | **Canto da Manhã**: fora de combate, o grupo a até 8 células regenera vida e MP **+50%** (descanso) | **Canto de Alerta** (recarga 30 s): mostra no minimapa, por 10 s, os monstros agressivos num raio de 15 células | sem dano |
| **Rasga-mortalha** | **Pouso Agourento**: os debuffs da árvore da Matinta duram **+1 s**, e o alvo do Agouro não fica invisível enquanto durar | — | +1 s de controle |
| **Pintada** | **Bote em Dupla**: o **Bote da Onça** faz a onça saltar junto (**+60% ATK** no alvo) | — | +5 a 8% |

### 2.5 Títulos sem companheiro (e por quê)

| Título | Motivo |
|---|---|
| **Facão Firme** e **Flecha do Cerrado** | São o primeiro título do Campo de Treino. O jogador precisa aprender o kit sem distração, e o companheiro é recompensa de ramo, como na 2ª classe do RO. O Lume é a exceção porque é só utilidade. |
| **Tronco de Aroeira** e **Casco de Jabuti** | Defesa e provocar dependem de o tanque ser o centro das atenções, e um bicho ao lado confunde a leitura. A fantasia do jabuti é a carapaça dele mesmo. |
| **Fúria do Mapinguari** | O berserker *é* o bicho. Pôr outro bicho ao lado dilui a fantasia. |
| **Guarda do Cristal** | A proteção do grupo já é forte. Um bicho automático pediria escudo automático, que é perigoso de balancear. |
| **Brasa no Facão** | É híbrido, e o kit já tem 5 skills e duas escolas. O monstro natural seria a Mula de Brasa (`ember_mule`), mas **montar a mula-sem-cabeça** tem peso religioso e de gênero na lenda: fica fora, salvo decisão do dono (questão 8). |
| **Seiva do Buriti** | Herda o sabiá da Raiz do Cerrado. |

### 2.6 Como entra no limite de 5 skills (sem quebrar a regra)

- A árvore continua com **5 skills** (TITULOS §3.0, regra 1). As skills de vínculo são **`bonus_skills` concedidas pela quest de vínculo**, e não pelo título.
- Proposta de dados: `CompanionDef.bond_skills` e `QuestDef.reward_companion`. O `TitleService` não muda. O novo `CompanionService` concede e retira as skills de vínculo conforme o companheiro ativo: **trocar o companheiro troca a passiva**.
- As passivas não sobem com pontos de skill (questão 3). Assim, não competem com os 24 pontos da build.

---

## 3. Montarias

### 3.1 Regras `[PROVISÓRIO]`

| Regra | Definição |
|---|---|
| Velocidade | O jogador anda a pé com `walk_ms_per_cell = 200`. **Montado: 160 ms/célula (+25%).** A diagonal continua ×1,4 (`diagonal_cost`). Todas as montarias da fase 1 e da fase 3 têm **a mesma velocidade**: a montaria rara é só visual, para não haver corrida de poder. |
| Teto | Bônus de velocidade se multiplicam (Trilha Ligeira +20%, Rumo Certo +15% etc.), com **piso de 130 ms/célula** numa constante do `Balance`. |
| Montar | Leva **1,5 s parado**, fora de combate (`in_combat = false`). Dano ou movimento cancela. Montar não tem custo. |
| Desmontar | É instantâneo, por botão. Também desmonta sozinho ao **atacar, usar skill, receber dano**, sentar, entrar em interior ou falar com NPC de loja (opcional). |
| Ser atingido | A montaria de viagem desmonta na hora, e o jogador fica **5 s sem poder montar**. Não há dano extra nem atordoamento. |
| Cidade | **Pode** andar montado nas ruas. Não pode em interiores (casas, loja, guilda). |
| Masmorra e caverna | **Não pode.** O jogador desmonta na entrada (o `ZoneDef` ganha `mount_allowed = false`). |
| Campo de Treino | **Não pode.** |
| PVP (Arena da Queimada) | **Não pode.** O jogador desmonta ao entrar. |
| Quest de título | Pode, mas não muda nada, porque o combate já desmonta. |
| Peso e carga | **O jogo não tem peso**: o inventário é por espaços. A carga vira o **alforje** (fase 2, questão 5): um baú de 20 espaços preso ao jumento, que só se abre com ele chamado. Os itens ficam no alforje mesmo depois de desmontar. |
| Morte | Desmonta. A montaria não entra no túmulo (Marca da Alma) e não se perde. |
| Login | O personagem sempre entra **desmontado**. |

### 3.2 Montaria básica da fase 1: **Jumento do Sertão** (`pindorama_mount_donkey`)

| Item | Definição |
|---|---|
| Por que o jumento | É o ícone do sertão ("Apologia ao Jumento"), humilde e de todo mundo. É neutro de título e combina com a fantasia de viajante. |
| Como se ganha | Uma quest com um NPC novo, o **Tropeiro** (Seu Benedito, nome de trabalho), na cidade. É preciso ter saído do Campo de Treino e ter renome ≥ 2. A quest pede: (1) juntar capim e rapadura (coleta); (2) levar uma carga a outro ponto do mapa; (3) pagar **Estrelas** (valor a definir, `ShopDef`). |
| Para quem | **Todos**, independente do título. |
| Alternativa | O **cavalo pantaneiro** é mais "herói", mas sai mais cara de arte (é maior e tem crina). Fica para a fase 3 (questão 4). |

### 3.3 Montaria de guerra (fase 3)

Ela é exclusiva de título de tanque, como o Peco do Cavaleiro: a **Anta de Guerra** do Couro de Anta.

- **Não desmonta** ao receber dano nem ao usar skill **corpo a corpo**.
- Velocidade de 175 ms/célula, menor que a do jumento: a anta é pesada.
- Com a anta: **+10% DEF**, Trombada e Pisada de Anta com +1 célula de alcance. Ataque à distância e conjuração desmontam.
- **Não entra no PVP** na fase 3.

### 3.4 Visual em camadas

A ordem das camadas parte da tabela do GDD §17.4:

| Ordem | Camada nova ou existente | Conteúdo |
|---|---|---|
| 0 | `mount_shadow` (nova) | A sombra oval maior. Substitui `shadow` quando montado. |
| 1 | `mount_back` (nova) | O corpo inteiro da montaria (folha por direção, idle e walk). |
| 2–11 | Camadas do personagem (existentes) | Usam a pose **`sit`**, que já existe para todo corpo, roupa e cabelo, deslocada para cima (`ride_offset` por direção) e com balanço vertical sincronizado aos quadros da montaria. |
| 12 | `mount_front` (nova) | A sela e o flanco ou o pescoço, que **cobrem as pernas** do sentado nas direções em que a pose `sit` não encaixa. |

- **Direções:** as mesmas 5 desenhadas (S, SE, L, NE, N) e os 3 espelhos (GDD §17.3).
- **Quadro:** a montaria precisa de um quadro **maior que 96 px**. A proposta é **144×144**, com origem nos pés da montaria. O cavaleiro mantém 96 px e só sobe pelo `ride_offset`.
- **Animações da montaria:** idle 4 quadros e walk 6, como monstro comum (GDD §17.3). Não precisa de ataque, hit nem morte, porque a montaria de viagem desmonta. A montaria de guerra pede attack 6.
- **Validação:** a montaria só está pronta com captura no **cliente real**, no ponto de nascimento, nas 8 direções e com os dois corpos.

### 3.5 Custo de arte e como reduzir

| Opção | Custo | Qualidade | Recomendação |
|---|---|---|---|
| A. Animação `ride` própria em todas as camadas (2 corpos × ~80 conjuntos de roupa × cabelos) | **Muito alto** | Ótima | Não |
| B. Pose `sit` existente + `mount_front` cobrindo as pernas + balanço | **Baixo**: só a montaria | Boa, se o recorte da sela for bem feito | **Sim (fase 1)** |
| C. Pose `ride` só para os 2 corpos base e a roupa Viajante, com as demais caindo em `sit` | Médio | Melhor nas roupas iniciais | Plano B, se a opção B ficar ruim em N ou S |
| D. Personagem "some" e só a montaria aparece com um boneco genérico | Baixo | Ruim: perde a roupa do título | Não |

Outras formas de reduzir o custo:
- **Uma base, várias montarias.** O jumento sai do modelo da **Mula de Brasa** (`ember_mule`) no pipeline Blender (`docs/arte-monstros-blender.md`), sem o fogo e com pelagem cinza.
- **Recolor por shader** para variações: jumento pardo, jumento branco "de festa", pelagens por nação, sem desenhar de novo.
- **Arreio como acessório.** A camada `mount_front` (sela e arreio) pode trocar sozinha, com recolor, em vez de redesenhar o bicho.
- **Fase 1: uma montaria só.**

### 3.6 Velocidade e outras regras do jogo

| Fonte | ms/célula | Observação |
|---|---|---|
| A pé | 200 | `Balance.walk_ms_per_cell` |
| Jumento e montarias raras | 160 | +25% |
| Anta de Guerra | 175 | fica em combate |
| Monstros comuns (referência) | 310–450 | ex.: `harpy_eagle` 360, `stone_armadillo` 450 |
| Piso absoluto | 130 | constante nova `mount_min_ms_per_cell` |

Como a montaria desmonta ao receber dano, fugir montado de monstro não é trivial. Andar montado também não muda o aggro: os monstros continuam vendo e perseguindo.

---

## 4. Pets (fase 2, sistema completo)

### 4.1 Ciclo

```
item de captura (no monstro, estágio 1) → Cesto com o bicho (item) → chamar → alimentar → intimidade sobe
→ Fiel: bônus pequeno, acessório e evolução cosmética
```

### 4.2 Regras `[PROVISÓRIO]`

| Regra | Definição |
|---|---|
| Quem pode | Qualquer personagem que tenha saído do Campo de Treino. Não depende de título. |
| Captura | O jogador usa o **item de captura** da espécie no monstro, que precisa ser de **estágio 1**. Nunca chefe, atroz, raro nem monstro de provação. Chance = base da espécie × (1 + vida que falta no monstro). Errar consome o item e o monstro fica bravo. **Acertar tira o monstro do mapa sem drop nem XP.** |
| Cesto | O sucesso gera o item **Cesto de Vime** com o bicho dentro (o "ovo" do RO), que ocupa 1 espaço e guarda os dados do pet. |
| Fome | Vai de 0 a 100 e cai 1 ponto a cada 2 min com o pet chamado. Cada espécie tem a **sua comida**, comprada ou coletada. Com fome abaixo de 25, a intimidade cai. **O pet nunca morre nem foge** (questão 11). |
| Intimidade | Vai de 0 a 1000, em faixas: **Arisco** 0–99 · **Desconfiado** 100–249 · **Manso** 250–749 · **Chegado** 750–899 · **Fiel** 900–1000. Sobe ao alimentar na hora certa (fome entre 25 e 75) e cai se o pet passar fome ou se o dono morrer com ele chamado. |
| Bônus | **Só em Chegado e Fiel**, sempre pequeno: +1 em um atributo, +2% de esquiva ou +3% de cura recebida. Um pet ativo por vez. **Nunca soma** com o efeito do companheiro de título. |
| Acessório | Um por espécie, como lacinho de chita, chapéu de palha mini ou fitinha de festa junina. É camada única do pet. Exige Manso. |
| Evolução | Com **Fiel** + itens raros da espécie, o pet troca a folha para um estágio maior em **miniatura**. É **só cosmética**, e o bônus não muda. |
| Seguir | O pet segue o dono no mapa compartilhado, com pose idle e walk. Não ataca, não pode ser alvo e não pega drop. |
| Limites | **1 pet chamado** + **1 companheiro de título** ao mesmo tempo (questão 6). A montaria não conta. |
| Onde | Em todo lugar, exceto o Campo de Treino e a Arena da Queimada. Na masmorra, o pet vai junto. |
| Nome | É dado na captura e pode ser trocado **1 vez**. Passa pelo filtro de moderação (`moderation.csv`) e tem 2 a 12 caracteres. |
| Comércio | **O Cesto é negociável pela troca existente** (`TradeService`), mas só com o pet **guardado** e com intimidade **reiniciada para Manso** ao trocar de dono. O nome se mantém, e o novo dono ganha 1 troca de nome. A loja de jogador e o leilão continuam fora (GDD §3.2). |
| Proteção | Cesto com pet Chegado ou Fiel nasce `protected` (não cai no túmulo). |

### 4.3 Pets da Terra de Pindorama (proposta inicial)

| Pet (espécie) | Monstro de origem | Captura | Comida | Bônus (Fiel) | Acessório |
|---|---|---|---|---|---|
| **Tatuzinho** | Tatu-Pedra (`stone_armadillo`) | **Cupim Seco** | Larva de Coqueiro | +2% DEF | Lenço de chita |
| **Queixadinha** | Queixada de Buriti (`buriti_boar`) | **Cacho de Buriti** | Coquinho | +1 VIT | Sininho de pescoço |
| **Tamanduazinho** | Tamanduá do Cerrado (`giant_anteater`) | **Pedaço de Cupinzeiro** | Formigueiro em Pote | +2% de crítico | Chapéu de palha mini |
| **Vaga-lume de Pote** | Vaga-lume Encantado (`enchanted_firefly`) | **Pote de Vidro** | Néctar | +2% MP máximo | Tampinha colorida |
| **Muda de Pequi** | Muda de Pequi (`pequi_seedling`) | **Regador de Cabaça** | Água de Chuva | +3% de cura recebida | Florzinha de pequi |
| **Capivara** *(nova arte)* | — (bicho manso; captura por quest, sem combate) | — | Capim | +1 ESP | Laranja na cabeça (meme brasileiro, opcional) |

Ficam **fora** como pet: harpia, guará, onça (para não esvaziar o companheiro de título), cobras peçonhentas (Jararaca, Surucucu, Coral; o jogo ensina a respeitá-las, ver `docs/fauna-peconhenta-e-monstros.md`), o Redemoinho Travesso (ligado ao Saci) e todo chefe.

### 4.4 Outras nações (só ideias, **com revisão cultural antes**)

Segue o processo de `docs/cultural/revisao-cultural.md` e as cautelas do TITULOS §5.

| Nação | Pet (monstro existente) | Montaria rara (fase 3) | Cuidado |
|---|---|---|---|
| Ilhas do Sol Nascente (Japão) | Tanuki (`trickster_tanuki`); kitsune, só como ideia | Cavalo de lavoura com crina trançada | A **kitsune** é mensageira de Inari, **divindade de religião viva**. Usar só a raposa trapaceira dos contos, nunca a de santuário. |
| Império de Jade (China) | Filhote de raposa-espírito (`spirit_fox_cub`) | Cavalo da estepe | A raposa-espírito chinesa (huli jing) não é a kitsune: são **duas** fichas. |
| Reino das Mouras (Portugal) | Serpente da fonte mini (`fountain_serpent`) | **Cavalo lusitano** | Nada de cristianismo e islamismo na lenda das mouras. |
| Fiordes de Gelo (Noruega/Islândia) | Lindworm filhote (`lindworm_hatchling`) | **Cavalo dos fiordes** (baixo e forte) | Evitar Sleipnir e qualquer coisa de Odin (religião viva, Ásatrú). |
| Brumas Verdes (Irlanda/Escócia) | Púca (`puca_trickster`) | **Kelpie** como montaria de evento: "o cavalo que tenta te levar ao lago" | O kelpie já é debuff no TITULOS §5.10. Uma montaria com risco cômico (desmonta perto da água) é opcional. |
| Estepe de Ferro (eslavos) | Zmey filhote (`zmey_hatchling`) | Troica de neve (veículo para 1) | Usar só os contos populares. |
| Costa das Colunas (Grécia) | Filhote de grifo (`griffin_chick`), mini-quimera (`little_chimera`) | Grifo (fase 3+, voa só no visual) | Nada de Pégaso ligado a deuses. |
| Areias do Nilo (Egito) | Esfinge filhote (`sphinx_cub`) | **Dromedário** | Nenhum animal sagrado de divindade (gato de Bastet, chacal de Anúbis). |
| Selvas de Obsidiana (México antigo) | Iguana de obsidiana (`obsidian_iguana`) | **Sem cavalo**, que seria anacrônico antes de 1519. Montaria só de festa, ou nenhuma. | Sem nahualismo (TITULOS §5): o filhote de jaguar (`jaguar_cub`) não vira "espírito animal" do jogador. |

---

## 5. Servidor e técnica (alto nível)

### 5.1 Seguidores (companheiro e pet)

| Decisão | Proposta | Por quê |
|---|---|---|
| Entidade replicada? | **Não.** O seguidor é **visual no cliente**. O servidor só replica no `NetEntity.appearance` do dono as chaves `companion` (id) e `pet` (espécie, estágio, acessório, nome). | Como o seguidor não pode ser alvo, não precisa de posição autoritativa. Custo de rede quase zero, sem IA no servidor e sem `GridMover` extra. |
| Seguir | Cada cliente posiciona o seguidor **atrás do dono**: célula oposta à direção, com atraso de 1 a 2 células, no ritmo do `ms_per_cell` do dono. Se ficar a mais de 8 células, teleporta. As aves (harpia, Lume, sabiá, coruja) voam em linha reta, sem caminho. Os de chão (guará, onça, pets) usam a `WalkGrid` local do cliente. | É a mesma grade que o cliente já tem. |
| Ataque automático | É **calculado no servidor**, no `CombatService`, como efeito do dono (fonte `companion_<id>`). O servidor emite um evento novo, `NetCombat.companion_strike(owner_id, target_id, companion_id)`, e o cliente anima o bicho até o alvo. O dano chega pelo `hit` normal. | A autoridade de dano não muda e os exploits continuam fechados. |
| Recarga interna | Fica guardada no servidor, por dono (`CompanionService`). | Impede proc em rajada. |
| Visibilidade | Quem não vê o dono (mapa ou instância diferente) também não vê o bicho. | Segue o GDD §5.6. |

### 5.2 Montaria como estado do jogador

- O estado `mounted_id` fica no servidor (`MountService`). Montar troca o `GridMover.ms_per_cell` do jogador para o da montaria (com o piso) e põe `mount` no `appearance`.
- Os gatilhos de desmontar (dano, ataque, skill, `in_combat`, mudar para zona proibida, morte) ficam **todos no servidor**, por sinais já existentes do `CombatService` e do `MapTransfer`.
- Ao trocar a velocidade no meio de um caminho, o servidor recalcula o restante do `MovePath` a partir da célula atual, com o mesmo `START_LEAD_TICKS`, para não dar "salto".
- O cliente troca as camadas para a pose montada (seção 3.4), ao ler `appearance.mount`.

### 5.3 Custo de rede

| Item | Custo |
|---|---|
| Seguidor | 2 a 4 chaves a mais no `appearance`, enviadas **só na mudança** |
| Proc do companheiro | 1 evento pequeno por proc. No pior caso (harpia), 1 a cada 1,5 s por arqueiro em combate |
| Montaria | 1 chave no `appearance` e o caminho com outro ms/célula (mesmo pacote de hoje) |
| Pets no mapa compartilhado | Zero posição replicada. Com 50 jogadores e 50 pets, o custo de rede é o mesmo; o custo é de **desenho no cliente** (limite de seguidores visíveis no mobile, questão 10). |

### 5.4 Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Hack de velocidade | O movimento já é autoritativo. O servidor ignora velocidade vinda do cliente e só aceita a do `MountService` e do `StatusEffects`, com o piso de 130 ms. |
| Montaria presa no lugar errado | Desmontar é a **regra por padrão** em toda transição de mapa sem `mount_allowed`, e o login entra desmontado. |
| *Kiting* montado | Montaria de viagem desmonta ao atacar ou usar skill. A anta de guerra só vale para o corpo a corpo. |
| Proc empilhado (arqueiro + harpia + Flecha de Aviso) | Teto de chance de 20%, recarga interna, e o proc não aciona outros procs. |
| Revelar invisível no PVP | Olho no Céu e Faro do Guará revelam por pouco tempo e com recarga. Na arena, o efeito automático cai a 50%. Testar contra Lama no Corpo e Sumiço. |
| Farm de captura | O monstro capturado não dá drop nem XP, e o item de captura custa Estrelas. |
| Pet como moeda paralela | O Cesto troca só pela troca direta e é registrado no log (`trades.jsonl`). A intimidade reinicia ao trocar de dono. |
| Nome ofensivo | Filtro de moderação e uma troca de nome. A moderação pode apagar o nome. |
| Poluição visual no mobile | Opção "mostrar seguidores dos outros: todos / só do grupo / nenhum". |

### 5.5 Como testar

| Teste | Tipo |
|---|---|
| `tests/mounts/test_mount_speed.gd`: ms/célula montado, piso de 130 ms, acúmulo com buffs | unidade (headless) |
| `test_dismount_rules.gd`: dano, skill, zona proibida, morte, login | unidade |
| `test_companion_proc.gd`: taxa média de proc em 10 mil ataques dentro do teto, recarga interna respeitada | estatístico |
| `test_bond_quest.gd`: renome mínimo, solo, `left_training`, sem nível | unidade (padrão de `quest_service`) |
| `test_pet_save_roundtrip.gd`: Cesto → save → load → troca → intimidade reiniciada | unidade |
| Playtest com 3 clientes (ngrok): seguidores no mapa compartilhado, montar e desmontar à vista dos outros | manual |
| **Captura no cliente real, no ponto de nascimento**: 8 direções × 2 corpos × montado e a pé | visual, obrigatório |

---

## 6. Modelo de dados (só proposta, não implementar)

### 6.1 Definições

| Arquivo | Campos principais |
|---|---|
| `data/companions/<id>.tres` (`CompanionDef`) | `id`, `name_key`, `title_id`, `bond_quest_id`, `sprite_base` (reaproveita a do monstro), `scale`, `flies` (bool), `bond_skills: Array[StringName]`, `pvp_proc_mult = 0.5` |
| `data/mounts/<id>.tres` (`MountDef`) | `id`, `name_key`, `sprite_base`, `frame_px = 144`, `ride_offset` (por direção), `walk_ms_per_cell`, `war_mount` (bool), `def_bonus_pct`, `title_id` (vazio = todos), `bag_slots` (alforje) |
| `data/pets/<species>.tres` (`PetDef`) | `species`, `monster_id`, `capture_item`, `capture_base_chance`, `food_item`, `bonus` (chave do `StatusEffects`), `accessory_item`, `evolve_items`, `evolved_sprite_base` |
| `ZoneDef` | Mais `mount_allowed: bool` e `pets_allowed: bool` |
| `QuestDef` | Mais `reward_companion` e `reward_mount` |

### 6.2 Constantes novas (`Balance`)

`mount_walk_ms_per_cell = 160`, `mount_min_ms_per_cell = 130`, `mount_cast_sec = 1.5`, `mount_lockout_after_hit_sec = 5`, `companion_swap_cooldown_sec = 60`, `pet_hunger_tick_sec = 120`, `follower_teleport_cells = 8`.

### 6.3 Save (`CharacterData.to_save`, com o `format` incrementado)

```json
"companions": { "owned": ["pindorama_companion_harpy"], "active": "pindorama_companion_harpy",
                "names": { "pindorama_companion_harpy": "Ventania" } },
"mounts":     { "owned": ["pindorama_mount_donkey"] },
"active_pet": "<uid do cesto>"
```

- O **pet mora no item** Cesto (`ItemStack`, campo novo `pet`, como já existem `crendices`): `{ "uid", "species", "name", "renamed", "intimacy", "hunger", "stage", "accessory", "caught_at" }`. Assim ele viaja pela troca e pelo armazém sem tabela nova.
- O estado montado **não é salvo**.
- Na migração de saves antigos, as listas ficam vazias.

---

## 7. Fases e entregas

| Fase | Entrega | Dependências de arte | Esforço relativo |
|---|---|---|---|
| **1** | **Harpia** (Gavião-Real), **Guará** (Tocaia do Brejo), **Lume** (Luz de Vaga-lume) com as quests de vínculo e as skills de vínculo; **Jumento do Sertão** para todos; `CompanionService`, `MountService` e as camadas `mount_*` | Seguidores: **nenhuma arte nova** (reduzir `harpy_eagle`, `maned_wolf` e `enchanted_firefly` s1). Jumento: **1 montaria nova** em 144 px (idle 4, walk 6, 5 direções, `mount_back` + `mount_front`), a partir do modelo da Mula de Brasa. NPC Tropeiro. | **M** (código ~60%, arte ~40%) |
| **2** | **Pets** (6 espécies de Pindorama, Cesto, fome, intimidade, acessório, troca); companheiros **Fagulha do Boitatá**, **Sabiá**, **Rasga-mortalha** e **Pintada**; **alforje** do jumento | Sabiá e coruja **novos** (pequenos). Capivara nova. 6 acessórios (camada pequena). 6 evoluções mini (reaproveitam s2 reduzidas). | **G** |
| **3** | Montarias raras por nação e evento (mesma velocidade, só visual), **Anta de Guerra** (Couro de Anta), recolors de festa (São João, Carnaval), pets das outras nações depois da revisão cultural | Anta **nova e grande** (com attack). Cada montaria rara = 1 folha nova ou recolor. | **G** (cresce com cada nação) |

**Ordem dentro da fase 1:** (1) o `MountService` com um retângulo de teste no lugar da arte; (2) a validação da opção B de camadas (seção 3.5) com o modelo do jumento; (3) a harpia (o pedido do dono); (4) o guará; (5) o Lume, se sobrar tempo.

---

## 8. Integração com o que já existe

| Sistema | Ponto de contato |
|---|---|
| `TitleDef.bonus_skills` / `TitleService` | É o modelo das skills de vínculo. Elas vêm do `CompanionDef.bond_skills`, e não do título. |
| `QuestService` / `required_causos` | Quests de vínculo e do Tropeiro, com renome mínimo. |
| `StatusEffects` (`Kind.SLOW`, `STEALTH`, `DEBUFF`, `M_CRIT`) | Lentidão da mordida, revelar invisível (encerra ou ignora `STEALTH` para o dono), bônus dos pets. |
| `CombatService` | Proc do companheiro como fonte de dano do dono. Gatilhos de desmontar. |
| `GridMover.ms_per_cell` / `Balance.walk_ms_per_cell` | Velocidade montada. |
| `CharacterLayers` / `DirectionalSprite3D` | Camadas `mount_*`, pose `sit` com `ride_offset`, seguidor reaproveitando a folha de monstro (5 direções × quadros de 96 px). |
| `TradeService` | Troca do Cesto de pet. |
| Ciclo de dia e noite | Quest do Lume (à noite) e luz do Lume. |

---

## 9. Questões em aberto para o dono

| # | Pergunta | Padrão recomendado |
|---|---|---|
| 1 | Companheiro só para ramo ou combinação, com o Lume como exceção de utilidade no primeiro título? | **Sim.** Primeiro título sem bicho de combate. O Lume entra porque não causa dano. |
| 2 | Tocaia do Brejo com **lobo-guará** ou **cão de caça** (veadeiro)? | **Lobo-guará**: a arte já existe e é fauna do cerrado. O cão fica como pet comum na fase 2. |
| 3 | As skills de vínculo sobem de nível? | **Não na fase 1** (nível fixo 1). Na fase 2, podem subir com "nível de vínculo" por uso, nunca com pontos de skill. |
| 4 | Montaria básica: **jumento** ou **cavalo pantaneiro**? | **Jumento** (mais barato a partir da Mula de Brasa, e mais "nosso"). O pantaneiro fica como montaria rara na fase 3. |
| 5 | A carga (alforje / "carrinho") existe, e para quem? | **Sim, na fase 2**: alforje de 20 espaços no jumento, para todos. Se um dia vier um caminho de mascate, ele ganha a lojinha. |
| 6 | Quantos seguidores ao mesmo tempo? | **1 companheiro + 1 pet.** A montaria não conta. |
| 7 | A montaria pode ser usada na cidade? | **Sim** nas ruas, **não** em interiores, masmorras, Campo de Treino e PVP. |
| 8 | A **Mula de Brasa** pode ser montaria do Brasa no Facão? | **Não.** A lenda da mula-sem-cabeça tem carga religiosa e de gênero; ela fica só como monstro. Revisão cultural, se o dono quiser. |
| 9 | Pet negociável? | **Sim**, pela troca direta, com intimidade reiniciada para Manso. Sem leilão (fora do MVP). |
| 10 | Mostrar os seguidores dos outros no mobile? | **Opção do jogador**: padrão "todos" no PC e "só do grupo" no mobile. |
| 11 | O pet pode fugir se passar fome demais (como no RO)? | **Não.** Perder um bicho de estimação frustra mais do que ensina; ele só fica Arisco. |
| 12 | A **Capivara** com laranja na cabeça (meme) | **Sim** como acessório opcional, cômico e brasileiro. Sem afetar o bônus. |
| 13 | A Anta de Guerra pode entrar no PVP? | **Não na fase 3.** Reavaliar depois de medir a arena. |
| 14 | Montaria rara com velocidade maior? | **Nunca.** A rara é só visual; mais velocidade seria vantagem paga ou de sorte (GDD §14). |
| 15 | A kitsune e os bichos das outras nações | **Só depois da revisão cultural** de cada região. A kitsune nunca é a de santuário. |
