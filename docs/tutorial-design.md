# Área de tutorial — "Margem do Despertar" (design)

> Status: `[PROVISÓRIO]` — design para o **próximo marco** (não implementar o mapa agora).
> Base: GDD §9.3 (tutorial), §1.2 e `docs/lore/chegada-do-viajante.md` (lore), §6.2/§7/§8 (atributos,
> skills, barra 1–0, títulos), §10.1 (controles), §10.6 (evolução dos monstros), §12 (Marca da Alma), §3.3
> (métricas). Autor: agente I, 27/09/2026.

## 1. Resumo

- **Instância individual** (1 jogador), mapa `tutorial_riverbank`. Começa exatamente onde a cinemática
  termina: o Viajante acorda na areia, com o **Barqueiro Benedito** chegando de barco.
- Ensina, nesta ordem: comandos → itens → combate (boneco, depois monstro fraco) → barra de atalhos e
  pontos → Marca da Alma (sem forçar morte) → lore → ponte para as docas do Porto do Despertar.
- **Duração alvo: 8 a 12 min.** Nenhum passo bloqueia por nível; só por ação feita (GDD §8.4).
- Termina na ponte: o jogador entra na cidade (instância compartilhada) nas docas, perto do Benedito
  "da cidade", e é convidado a conhecer os dois Mestres. Nada de escolher escola no tutorial.

## 2. Mapa (esboço)

Mapa pequeno e linear, ~70 x 40 unidades, rio a leste, luz de amanhecer (paleta da ficha `brasil.md`:
rosa/ouro, verde-água, madeira). 3 pontos de vista "dignos de print" (GDD §17.11): a margem com névoa,
o alto do barranco sobre o campinho, e a ponte com a cidade ao fundo.

```
  N ↑
  ┌──────────────────────────────────────────────────────────────────────┐
  │  mata baixa / barranco (não andável)                                  │
  │                                                                       │
  │   [C] CAMPINHO DO REDEMOINHO          [B] TERREIRO DE TREINO          │
  │   cerrado aberto, 1 ipê roxo,         cerca de bambu, 2 bonecos de    │
  │   cupinzeiros; 1 Redemoinho           palha, baú com facão e cajado,  │
  │   Arteiro (passivo) + folhas          "Marca de treino" (túmulo de    │
  │   no chão              ◄── trilha ──► demonstração), banco p/ sentar  │
  │        │                                   ▲                          │
  │        │ trilha de terra                   │ escadinha de pedra       │
  │        ▼                                   │                          │
  │   [D] PONTE DE MADEIRA ═══════►    [A] MARGEM DO RIO (início)         │
  │   (portão/portal para as           areia clara, juncos, flores;       │
  │    DOCAS do Porto do Despertar)    ponto de despertar ✱, mochila      │
  │   cidade visível ao fundo          caída, poção e flor no chão;       │
  │                                    Benedito ancora o barco aqui ≈≈≈   │
  │ ≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈ RIO LARGO (não andável) ≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈ │
  └──────────────────────────────────────────────────────────────────────┘
```

Ordem física: **A (margem) → B (terreiro) → C (campinho) → D (ponte)**. Cada área é fechada por um
elemento natural leve (juncos altos, cancela de bambu, tronco caído) que o Benedito "abre" ao terminar o
passo — nunca uma parede invisível sem explicação. Quem pula o tutorial vai direto para a cidade.

## 3. Guia: Barqueiro Benedito

- **Quem é:** o barqueiro que "acha" Viajantes na margem ao amanhecer e os leva até as docas. Já viu
  dezenas chegarem. É a silhueta com a vara no último plano da cinemática, e o mesmo **NPC Barqueiro
  Benedito** que já existe nas docas da cidade (`data/npcs/boatman.tres`).
- **Visual:** senhor de uns 60 anos, pele morena queimada de sol, barba branca curta, **chapéu de palha
  gasto**, camisa de linho clara com as mangas dobradas, calça arregaçada até a canela, pés descalços,
  **vara de barqueiro** comprida e uma lamparina de latão pendurada no cinto. Sprite 96x96, 5 direções
  (idle, walk, gesto "apontar"). Retrato de diálogo opcional.
- **Personalidade:** calmo, bem-humorado, fala por comparações com o rio; nunca apressa ("o rio não
  corre mais porque você quer"). Carinhoso, mas não mente: avisa do perigo sem dramatizar.
- **Fala de exemplo (tom):** "Ô, acordou, afinal! Dormiu feito pedra de fundo de rio."

Todas as falas abaixo são **chaves de tradução** novas (`localization/content.csv`, prefixo `DLG_TUT_`);
o texto é o valor pt-BR provisório.

## 4. Roteiro passo a passo

Formato de cada passo: **objetivo** (o que o jogo espera), **aviso na tela** (dica fixa no topo, chave
`TUT_HINT_*`), **fala do guia**, **sistemas necessários**, **conclusão**. Avisos de PC / celular diferem
quando necessário (`_PC` / `_TOUCH`).

### Passo 0 — Despertar (automático, ~15 s)
- Fim da cinemática → fade do preto; câmera começa baixa e sobe até a altura normal (1,5 s).
- Benedito encosta o barco e fala: **DLG_TUT_WAKE** — "Ô, acordou, afinal! O rio te trouxe, igual traz
  todo Viajante. Calma, que ninguém aqui morde... bom, quase ninguém. Vem cá, vem."
- Sistemas: diálogo com NPC (já existe), câmera, spawn do jogador em marcador `tutorial_wake`.

### Passo 1 — Andar (~30 s)
- **Objetivo:** chegar até o Benedito (área de 2 células ao redor dele).
- **Aviso:** TUT_HINT_MOVE_PC "Clique no chão para andar. Segure o botão para seguir o cursor." /
  TUT_HINT_MOVE_TOUCH "Toque no chão para andar."
- Marcador pulsante (círculo dourado) no chão ao lado do guia. Conclui ao chegar.
- Sistemas: movimento por células (§10.1), marcador de objetivo no chão.

### Passo 2 — Câmera e zoom (~20 s)
- **Objetivo:** girar a câmera pelo menos 90° **e** usar o zoom uma vez (qualquer ordem).
- **Aviso:** TUT_HINT_CAMERA_PC "Clique direito e arraste (ou Q/E) para girar a câmera. Role a roda
  do mouse para aproximar." / TUT_HINT_CAMERA_TOUCH "Arraste com dois dedos para girar. Faça pinça para
  aproximar."
- **Fala:** DLG_TUT_CAMERA — "Olha em volta. Lá do outro lado do rio é o Porto do Despertar. Bonito, né?
  Vamos chegar lá — mas antes você precisa aprender a se virar."
- Checklist visual no aviso (☐ girar ☐ zoom → ☑). Sistemas: câmera orbital, eventos de câmera.

### Passo 3 — Falar com NPC (~20 s)
- **Objetivo:** clicar no Benedito e escolher uma opção do diálogo.
- **Aviso:** TUT_HINT_TALK "Clique em uma pessoa para conversar."
- **Fala:** DLG_TUT_TALK — "Sua mochila caiu ali na areia, junto de umas coisas que o rio trouxe. Vai
  buscar." Opções: "Que lugar é este?" (→ fala curta de lore, ver §5, fala L1) / "Vou buscar."
- Sistemas: diálogo com opções (existe).

### Passo 4 — Pegar itens do chão (~30 s)
- **Objetivo:** pegar os 2 itens brilhando na areia: **Poção de Vida Pequena** ×2 e **Flor de Ipê**
  (item de lembrança, sem uso).
- **Aviso:** TUT_HINT_PICKUP "Clique em um item brilhando no chão para pegá-lo."
- Sistemas: itens no chão (drops, §10.5), coleta, feedback `sfx_pickup` e toast "+1 Poção de Vida
  Pequena".

### Passo 5 — Inventário (~20 s)
- **Objetivo:** abrir o inventário.
- **Aviso:** TUT_HINT_INVENTORY_PC "Aperte I (ou o botão Mochila) para abrir o inventário." /
  TUT_HINT_INVENTORY_TOUCH "Toque no botão Mochila."
- Seta apontando o botão da mochila na HUD. **Fala:** DLG_TUT_INVENTORY — "Tudo o que vai na mochila
  fica com você, aconteça o que acontecer. Guarda isso: vai ser importante."
- Sistemas: janela de inventário (existe), destaque de botão da HUD (novo: "spotlight" de tutorial).

### Passo 6 — Equipar a primeira arma (~40 s)
- Benedito aponta o baú da cerca: **DLG_TUT_CHEST** — "Nesse baú tem um facão e um cajado velho. Pega
  os dois. Qual usar? Isso é você quem decide — aqui ninguém nasce com caminho marcado."
- **Objetivo:** abrir o baú (recebe **Facão** e **Cajado de Madeira**) e **equipar um dos dois**.
- **Aviso:** TUT_HINT_EQUIP "Clique duas vezes numa arma do inventário (ou arraste para o espaço de
  arma) para equipá-la."
- Sistemas: baú/interação com objeto, janela de equipamento (existe), `sfx_equip`.
- Nota de design: dar as duas armas reforça "sem classes" (GDD §1). A escolha não prende a nada.

### Passo 7 — Boneco de treino (~45 s)
- **Objetivo:** derrotar 1 **Boneco de Palha** (monstro "alvo": não anda, não ataca, 3–5 golpes).
- **Aviso:** TUT_HINT_ATTACK_PC "Clique no boneco para atacar. Você continua atacando até ele cair." /
  TUT_HINT_ATTACK_TOUCH "Toque no boneco para atacar."
- **Fala (depois):** DLG_TUT_DUMMY_DONE — "Isso! Golpe torto, mas golpe."
- Sistemas: alvo, ataque básico em ciclo, números de dano, barra de vida do alvo (F3).

### Passo 8 — Barra de atalhos (1 a 0) e poção (~40 s)
- A poção é colocada **automaticamente no espaço 1** da barra e o guia explica. (Não se causa dano
  arbitrário ao jogador só para ele ter motivo de beber a poção.)
- **Objetivo:** usar a poção pela barra (tecla **1** ou toque no botão), mesmo com vida cheia (o
  tutorial permite; ver sistemas).
- **Aviso:** TUT_HINT_HOTBAR_PC "Sua barra de atalhos tem 10 espaços: teclas 1 a 0. Aperte 1 para usar a
  poção." / TUT_HINT_HOTBAR_TOUCH "Toque no botão da poção na barra."
- **Fala:** DLG_TUT_HOTBAR — "Nessa barra cabe o que você precisa na hora do aperto: poções e, quando
  aprender, as técnicas dos Mestres. Dez espaços, do 1 ao 0. Arrume do seu jeito — só não dá pra
  mexer no meio de uma briga."
- Sistemas: barra de 10 espaços (F4), arrastar item/skill para a barra, recarga compartilhada de poção
  (10 s, §11.3), regra "trocar só fora de combate".

### Passo 9 — Habilidade de demonstração (~40 s)
- **Objetivo:** usar a habilidade de demonstração **"Sopro do Rio"** (espaço 2 da barra) no segundo
  boneco. Ela empurra o alvo 2 células e causa dano leve.
- **Aviso:** TUT_HINT_SKILL "Habilidades também vão na barra. Aperte 2 com o boneco selecionado."
- **Fala:** DLG_TUT_SKILL — "Isso aí não é seu, é um empréstimo do rio. Some quando você atravessar a
  ponte. Técnica de verdade, que fica, só se aprende com um Mestre."
- Regra: a skill é marcada `tutorial_only` — não conta para títulos, não recebe pontos de skill e é
  removida ao sair do tutorial (respeita GDD §7: skills só por quest). **Pergunta ao dono** no §9.
- Sistemas: skills com recarga e mana (F4), marcação `tutorial_only`.

### Passo 10 — Monstro fraco (~1 min 30 s)
- Benedito abre a cancela do campinho: **DLG_TUT_MONSTER** — "Tá vendo aquele redemoinho de folhas com
  um gorrinho? É arte do Saci. Não faz mal a ninguém... a não ser que você deixe. Vai lá."
- **Objetivo:** derrotar 1 **Redemoinho Arteiro** (nível 1, passivo; dá pulinhos e some/reaparece perto,
  §10.3). Garantir o drop de 1 **Folha Rodopiante**.
- **Aviso:** TUT_HINT_MONSTER "Monstros revidam. Fique de olho na sua barra de vida."
- Balanceamento: o redemoinho do tutorial não consegue matar (dano mínimo; vida do jogador nunca cai
  abaixo de 30% na instância de tutorial) e **não absorve Eco** (flag `can_evolve = false`, §10.6).
- **Fala (depois):** DLG_TUT_MONSTER_DONE — "Viu? Ele virou folha de novo. Pega o que ele deixou."
- Sistemas: IA de monstro (F3), drops garantidos, XP.

### Passo 11 — Subir de nível: atributos e ponto de skill (~1 min)
- A XP do boneco + redemoinho + recompensa do passo leva o jogador ao **nível 2** (100 XP, §6.3).
- **Objetivo:** abrir a janela de personagem e **distribuir os 3 pontos de atributo** (qualquer
  combinação; botão "Confirmar").
- **Aviso:** TUT_HINT_ATTRIBUTES_PC "Você subiu de nível! Aperte C para abrir o Personagem e distribua
  3 pontos de atributo." (celular: botão Personagem).
- **Fala:** DLG_TUT_LEVEL — "Cada vez que você cresce, ganha três pontos pra pôr onde quiser: Força
  pra bater, Destreza pra ser rápido, Vitalidade pra aguentar, Intelecto pra magia, Espírito pra
  recuperar. Não tem jeito errado. Só tem o seu jeito."
- **Ponto de skill:** o jogador também ganha **1 ponto de skill**. Como ainda não conhece skill de
  verdade, a interface mostra "1 ponto de skill guardado". **Fala:** DLG_TUT_SKILLPOINT — "E esse
  pontinho aí de skill, guarda. Quando um Mestre te ensinar a primeira técnica, você coloca nela pra
  ficar mais forte."
- Tooltip de cada atributo com o efeito (§6.2). Redistribuição não existe: mostrar confirmação
  TUT_CONFIRM_ATTRIBUTES "Os pontos não podem ser trocados depois. Confirmar?"
- Sistemas: nível/XP, distribuição de atributos, contador de pontos de skill (F4, `SkillProgression`).

### Passo 12 — Morte e Marca da Alma (diálogo + demonstração, ~1 min)
- No terreiro existe uma **"Marca de treino"**: um túmulo de luz de demonstração com um **Chapéu de
  Palha com Flor** dentro (só existe no tutorial, só o jogador vê).
- **Fala:** DLG_TUT_DEATH — "Agora escuta, que isso é sério. Se você cair em luta, o cristal da cidade
  te traz de volta. Mas tudo o que você estiver **vestindo** fica pra trás, numa Marca da Alma, no lugar
  onde você caiu. O que tá na mochila, não: esse fica contigo."
- **Objetivo:** clicar na Marca de treino e **recolher** o chapéu (vai para o inventário, não é
  reequipado — igual à regra real, §12.2).
- **Fala (depois):** DLG_TUT_DEATH_2 — "A marca some em três horas, e só você enxerga. Se o lugar for
  perigoso, chama os amigos pra abrir caminho. Na arena é diferente: lá, quem te derrubou também vê a
  marca — e pode levar o que tá nela."
- **Aviso:** TUT_HINT_GRAVE "Clique na Marca da Alma para recolher seus itens."
- Sistemas: objeto túmulo e janela de recolher (F3, reutilizado com dados de demonstração). O jogador
  **nunca é forçado a morrer**.

### Passo 13 — Lore e títulos (conversa livre, ~1 min; pode ser encurtada)
- Benedito senta no banco (animação `sit`) e oferece um menu de perguntas (todas opcionais; o passo
  conclui ao escolher "Vamos pra cidade"). Falas no §5.

### Passo 14 — A ponte (~40 s)
- **Objetivo:** atravessar a ponte até o portal das docas.
- **Aviso:** TUT_HINT_BRIDGE "Atravesse a ponte para chegar ao Porto do Despertar."
- **Fala:** DLG_TUT_BRIDGE — "Na casa de azulejos, perto da praça, ficam a Mestra Brisa, da Lâmina, e o
  Mestre Orvalho, do Arcano. Fala com os dois, ou com nenhum. O caminho é seu. E ó: nenhum lugar deste
  mundo te barra a entrada — mas alguns vão te cobrar caro. Vai com calma."
- Ao cruzar o portal: remove "Sopro do Rio", marca o tutorial como concluído no personagem, mostra o
  aviso TUT_DONE "Tutorial concluído! Procure os Mestres na Casa dos Mestres." e entra na cidade nas
  docas (spawn `docks_arrival`).

## 5. Falas de lore do guia (Passo 3 e Passo 13)

Curtas, uma por pergunta; ensinam GDD §1.2, §8.5, §10.6 e §12 sem aula.

| Pergunta (opção) | Chave | Resposta do Benedito |
|---|---|---|
| "Que lugar é este?" | DLG_TUT_LORE_WORLD | "Terra do Sabiá. Um dos reinos deste mundo. Cada reino parece um pedaço do seu mundo, com as histórias de lá... só que aqui as histórias são de verdade." |
| "Por que eu vim parar aqui?" | DLG_TUT_LORE_WHY | "Viu uma flor dourada caindo, não viu? Todo Viajante vê. A gente chama de Florada. Por que acontece... ninguém sabe. O rio traz, e pronto." |
| "Quem são os Mestres?" | DLG_TUT_LORE_MASTERS | "Gente que sabe uma arte e ensina. Vocês, Viajantes, chegam em branco e aprendem qualquer coisa — mas só com alguém mostrando. Livro nenhum ensina técnica." |
| "Eu tenho uma classe?" | DLG_TUT_LORE_TITLES | "Classe? Aqui não tem isso. Tem o que você aprende. Quem junta certas técnicas ganha um título — Facão Firme, Luz de Vaga-lume, cada terra tem os seus — e alguns Mestres só ensinam o melhor pra quem tem título." |
| "Por que os monstros são perigosos?" | DLG_TUT_LORE_ECHO | "As criaturas daqui são lendas vivas, e lenda come história. Tudo o que você vive vira Eco. Se um bicho te derruba, bebe o reflexo do seu Eco inteiro e cresce — vira coisa pior, com nome novo e bando. Você não perde nada... mas ele ganha tudo." |
| "E se eu morrer?" | DLG_TUT_LORE_DEATH | "O cristal te traz de volta. O que você vestia fica na Marca da Alma. Vai buscar antes de três horas." |
| "Vamos pra cidade." | DLG_TUT_LORE_GO | (fecha e libera a ponte) |

## 6. Sistemas necessários por passo

| Passo | Sistemas | Existe hoje? |
|---|---|---|
| 0 | Cinemática → spawn em marcador; diálogo | Cinemática ✔, diálogo ✔ |
| 1 | Movimento por células; marcador de objetivo no chão | Movimento (agente M, em refatoração); marcador ✘ |
| 2 | Câmera orbital + eventos de giro/zoom | Câmera ✔; eventos ✘ |
| 3 | Diálogo com opções | ✔ |
| 4 | Itens no chão, coleta, toasts | Parcial (inventário ✔; itens no chão F3 ✘) |
| 5 | Inventário; destaque de botão da HUD | Inventário ✔; destaque ✘ |
| 6 | Baú/objeto interativo; equipamento | Equipamento ✔; baú ✘ |
| 7 | Alvo, ataque básico em ciclo, dano, vida do alvo | F3 ✘ |
| 8 | Barra de atalhos 10 espaços (1–0), poções, recarga | F4 ✘ (poções como item ✔) |
| 9 | Skill com recarga/mana; flag `tutorial_only` | F4 ✘ |
| 10 | IA de monstro, drops garantidos, XP; `can_evolve=false` | F3/F4 ✘ |
| 11 | Nível, atributos, pontos de skill, janela Personagem | F4 ✘ |
| 12 | Marca da Alma (objeto + recolher) com dados de demonstração | F3 ✘ |
| 13 | Diálogo; animação `sit` | ✔ / sit ✔ |
| 14 | Portal entre mapas; flag de tutorial concluído | Portal F2 ✘; flag ✘ |

**Novo, específico do tutorial:** `TutorialDirector` (cliente, lê uma lista de passos em dados:
`data/tutorial/steps.tres` com objetivo, aviso, fala, condição de conclusão e bloqueios a abrir),
eventos de objetivo vindos do servidor (autoridade continua no servidor), aviso fixo de tutorial na HUD,
"spotlight" de botão, marcador no chão, bloqueios naturais que abrem com animação.

## 7. Critérios de conclusão

- O tutorial está **concluído** quando o jogador cruza o portal da ponte (Passo 14) — gravado no
  personagem (`characters.tutorial_done = true`) e na conta (`accounts.has_finished_tutorial = true`).
- Cada passo conclui por **ação do jogador** detectada pelo servidor (nunca por tempo).
- Nenhum passo exige nível de personagem, só a ação.
- Se o jogador sair no meio: ao voltar, recomeça **no início do passo em que parou** (progresso por
  passo salvo no personagem), com itens já recebidos mantidos (sem duplicar baú nem drops).

## 8. Regras de pular

- **Pular a cinemática:** sempre possível (Esc / botão "Pular").
- **Pular o tutorial:** só aparece para contas que **já concluíram o tutorial com outro personagem**
  (GDD §9.3). Botão "Pular tutorial" no aviso do Passo 0, com confirmação TUT_SKIP_CONFIRM "Ir direto
  para o Porto do Despertar? Você recebe os itens iniciais." Quem pula recebe o mesmo kit (Facão,
  Cajado de Madeira, 2 Poções de Vida Pequena, Flor de Ipê), vai para o nível 2 com 3 pontos de
  atributo e 1 ponto de skill a distribuir, e aparece nas docas.
- Primeira conta/primeiro personagem: sem botão de pular, mas passos de conversa podem ser acelerados
  (clique avança o texto) e o Passo 13 é opcional.
- Um personagem que já concluiu nunca volta ao tutorial. ("Rever abertura" nas configurações revê só a
  cinemática.)

## 9. Métricas a registrar (GDD §3.3)

Eventos (servidor, com `character_id`, `account_id`, plataforma PC/mobile, timestamp):

| Evento | Dados | Para quê |
|---|---|---|
| `cutscene_arrival_end` | `skipped` (bool), segundo em que pulou | Quantos veem a abertura inteira |
| `tutorial_start` | primeira conta? | Funil |
| `tutorial_step_complete` | passo, duração do passo (s), tentativas | Onde as pessoas travam (meta: nenhum passo com mediana > 2 min) |
| `tutorial_abandon` | passo, tempo total | Onde as pessoas desistem (saem do jogo) |
| `tutorial_skip` | — | Uso do pular por contas veteranas |
| `tutorial_complete` | tempo total, plataforma | Duração real vs. alvo de 8–12 min |
| `tutorial_weapon_equipped` | facão / cajado | Primeira inclinação (Lâmina x Arcano) |
| `tutorial_attributes_spent` | distribuição dos 3 pontos | Primeiras escolhas de build |
| `tutorial_lore_question` | pergunta escolhida | Interesse pela lore |
| `first_master_talk` | Mestre, tempo após o tutorial | Se o tutorial leva aos Mestres |

Ligação com §3.3: duração de sessão (primeira sessão inclui o tutorial), retenção D1/D7 separada por
"concluiu o tutorial" x "abandonou", e distribuição de skills (especialistas x generalistas) cruzada com
a arma escolhida no Passo 6.

## 10. O que precisa existir antes (dependências)

**Sistemas (código):**
1. Movimento por células estável (agente M) e portal entre mapas/instância individual (F2).
2. Combate básico, alvo, IA de monstro, drops no chão, XP e nível (F3/F4).
3. Barra de atalhos de 10 espaços (1–0), skills com recarga/mana, pontos de skill e atributos (F4).
4. Marca da Alma com objeto e janela de recolher (F3).
5. `TutorialDirector` + dados de passos + flags de tutorial na conta e no personagem (novo, ~12 h —
   corresponde à linha "tutorial nas docas" do `plano-mvp.md` F4, que deve crescer para ~20 h).
6. Métricas do §9 (entram no pacote de eventos de F5).

**Arte:**
- Mapa `tutorial_riverbank` (graybox → texturas pixel 48 px/un): areia, juncos, barranco, cerca de
  bambu, ponte de madeira, rio com névoa (reaproveitar texturas das docas e dos Campos).
- Sprites: Benedito com gesto "apontar" e barco (existe NPC barqueiro — conferir), Boneco de Palha
  (64x64, 1 direção + animação de "apanhar"), Redemoinho Arteiro (já previsto no MVP), baú, Marca da
  Alma (a mesma do jogo), marcador dourado no chão.
- Ícone da skill "Sopro do Rio" (32x32) e da Flor de Ipê.
- Retrato do Benedito para o diálogo (opcional).

**Áudio (catálogo `tools/audio/sound_catalog.json`):**
- Música: `mus_tutorial_dawn` (variação calma de `mus_city_docks`, amanhecer) — pode reaproveitar
  `mus_city_docks` no início.
- Efeitos: `sfx_chest_open`, `sfx_dummy_hit`, `sfx_level_up`, `sfx_grave_appear` (já listados no GDD
  §18 em parte), `sfx_skill_river_gust`; ambiente `amb_river` (existe).

**Texto:** ~60 chaves `DLG_TUT_*` / `TUT_HINT_*` / `TUT_*` em `localization/content.csv` (revisão pt-BR).

## 11. Perguntas para o dono

1. **Skill de demonstração:** tudo bem existir uma skill temporária do tutorial ("Sopro do Rio",
   `tutorial_only`, removida na ponte)? Alternativa sem skill: mostrar a barra só com a poção e um
   espaço "bloqueado" com o texto "Aprenda técnicas com os Mestres".
2. O tutorial deve **garantir nível 2** (para ensinar atributos e ponto de skill) ou deixar o jogador
   sair no nível 1 e ensinar atributos no primeiro nível real?
3. O jogador pode **morrer** no tutorial (monstro com dano real) ou mantemos o piso de 30% de vida?
4. As duas armas iniciais (facão e cajado) no baú: dar as duas, ou deixar escolher uma?
5. Nome do mapa: "Margem do Despertar"?
