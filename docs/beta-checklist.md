# Checklist do primeiro beta

Conferido em 30/09/2026. Pergunta do dono: "Criamos os demais monstros e áreas; está tudo ligado para o nosso primeiro beta?"

**Resposta curta:** quase. O caminho inteiro funciona no jogo de verdade:

- personagem novo;
- título no Campo de Treino;
- Porto;
- Campos, Mata e Chapada;
- volta ao Porto;
- lição de Mestre cumprida caçando;
- chefe e forma atroz na Chapada;
- dois jogadores pela internet (WebSocket);
- **mapas compartilhados e grupo** (decisão do dono em 30/09/2026): todos se veem em todos os mapas, grupo de até 5 pelo chat (`/grupo nome`) ou pelo clique no jogador, XP dividida, drop com posse, provação que ninguém rouba.

Uma coisa ainda bloqueia as quests dos anciãos: **a provação delas começa no Porto, onde não há combate**. Isso precisa de uma decisão sua (ver "Bloqueia o beta").

## Como conferir de novo

| O quê | Comando | Resultado hoje |
|---|---|---|
| Ligações de conteúdo | `godot --headless --path game res://tests/beta/test_content_links.tscn` (também roda no `make test`) | PASS: 3976 verificações, 0 falhas, 3 pendentes (decisão), 4 avisos |
| Percurso no cliente real | `GODOT=$PWD/.tools/godot-4.7.2 game/tests/beta/run_beta_route.sh` (xvfb, 1280x720, cerca de 8 min) | 50 de 51. A única falha é a provação no Porto |
| Internet (WebSocket) com 2 clientes | `GODOT=$PWD/.tools/godot-4.7.2 game/tests/beta/run_ws_duo.sh` | PASS (agora formam grupo pelo chat e se veem nos Campos) |
| Pergaminho de Retorno | `GODOT=$PWD/.tools/godot-4.7.2 game/tests/return/run_return_test.sh` (xvfb, cerca de 3 min) | PASS: 15 verificações; `last_city` no save |
| Troca entre personagens (2 clientes) | `GODOT=$PWD/.tools/godot-4.7.2 game/tests/trade/run_trade_test.sh` (xvfb, cerca de 3 min) | PASS: 27 verificações, troca registrada em `trades.jsonl` |
| Grupo e mapas compartilhados (3 clientes) | `GODOT=$PWD/.tools/godot-4.7.2 game/tests/party/run_party_test.sh` (xvfb, cerca de 15 min; `PHASES=training` ou `hunt` para uma fase só) | PASS: 73 verificações (Campo de Treino 55, Campos 18) |
| Testes de sempre | `make test`, `run_progression_test.sh`, `run_combat_autotest.sh`, `run_world_test.sh` | PASS |

- **Onde ficam as capturas:** `.work/beta/` (35 fotos, numeradas pela ordem do percurso), `.work/beta/ws/`, `.work/grupo/`, `.work/troca/` e `.work/retorno/` (`lado_a_lado_*.png` juntam as telas de dois jogadores).
- **Logs:** `.work/beta/route_*.log`.
- **Pendentes:** o verificador mostra as ligações que esperam decisão como `PENDENTE`. Elas não reprovam o teste. Com `-- --strict`, reprovam.

## O que está pronto

- **Mapas.** Os 5 mapas carregam e têm SpawnPoint, ponto seguro de renascimento e navegação pronta.
  - Todo portal tem destino e ponto de chegada.
  - Toda ligação tem volta.
  - Todos os mapas são alcançáveis a partir do Campo de Treino.
  - A volta de uma área chega pelo lado norte.
  - A volta ao Porto chega no cristal.
- **Percurso real.** Nos 4 mapas com combate, o personagem lutou de verdade, ganhou XP, pegou o drop, morreu e renasceu no ponto seguro:
  - Campo de Treino: renasce no acampamento;
  - Campos, Mata e Chapada: renasce no SpawnPoint.
- **Título no Campo de Treino.** Feito de verdade: conversa com o Mestre Jatobá, 5 Redemoinhos, provação do tatu, entrega e título Facão Firme. Depois, o portal de saída leva ao Porto.
- **Lição de Mestre.** A Mestra Brisa oferece a Investida no Porto. O personagem cumpre caçando nos Campos, entrega e aprende a skill.
- **Chapada.**
  - O Tatu-Montanha e a Rainha-Lume ficam nos seus covis fixos (Subida Vermelha), cada um com bando, e renascem 10 min depois de derrotados.
  - À noite, a forma atroz aparece: Tatu-Montanha Atroz e Ventania Atroz.
  - As derrotas contam nas etapas da quest do Seu Zé.
- **Dados.**
  - Todas as 80 quests apontam para monstros, itens, NPCs e títulos que existem, com o NPC posicionado no mapa.
  - Todos os monstros das lições nascem fora do Campo de Treino, com nível dentro da faixa do mapa.
  - Os itens das lições caem de monstros desses mapas.
  - Os itens raros dos anciãos caem do monstro que o texto indica (raro ou chefe).
- **Skills.** As 80 skills têm ícone, efeito, textos, escola e pré-requisitos válidos, e todas são ensinadas por alguma quest.
- **Títulos.** Os 17 títulos têm requisitos válidos. As 16 roupas têm folhas nos 2 corpos.
- **Monstros e itens.** Todos os monstros têm as 5 folhas em todos os estágios, no tamanho certo. Os drops existem. Os itens têm ícone e texto.
- **Loja.** A loja do mercado vende tudo o que lista, inclusive o `simple_bow`.
- **Textos.** Todo texto usado tem tradução pt_BR.
- **Internet.**
  - O servidor `--transport=ws` e 2 clientes em `ws://` funcionaram.
  - Os dois se veem no Porto, formam grupo com `/grupo`, entram nos Campos (mapa compartilhado), se veem, lutam, ganham XP e pegam o drop.
- **Mapas compartilhados e grupo (30/09/2026).** Ver GDD §5 e `docs/contracts-city-walk.md`, ADENDO 6.
  - Um mapa = uma instância (`instance_id = map_id`): Campo de Treino, Porto, Campos, Mata e Chapada.
  - Monstro é de quem causou mais dano; XP e crédito de quest vão para ele e para o grupo dele por perto; o drop é do grupo por 10 s.
  - Provação: o monstro só luta com o dono e o grupo dele.
  - `/grupo`, `/g`, `/online`, painel do grupo, janela de convite, menu no clique do jogador e aba "Grupo" do chat.
- **Pergaminho de Retorno (30/09/2026).** Volta à última cidade (Porto) no ponto seguro; kit inicial com 3, à venda no mercado; em combate leva 1 s; não funciona no treino, em provação nem em troca. Ver GDD §11.3.
- **Troca entre personagens (30/09/2026).** Clique no jogador → "Propor troca" ou `/troca nome`; janela com os dois lados, Estrelas, Confirmar e Trocar; servidor confere tudo e troca de uma vez; cada troca fica em `trades.jsonl`. Ver GDD §13.1 e `docs/contracts-city-walk.md`, ADENDO 7.

## O que foi corrigido

1. **Variantes da Chapada não contavam nas quests.** Os monstros da Chapada têm outro id (`highland_*`). Por isso, duas etapas nunca aconteciam em jogo normal:
   - "Derrote o chefe Rainha-Lume do Brejo" (Seu Zé);
   - "Derrote o Tatu-Pedra chefe em forma atroz" (Velho Tião).

   As lições também não contavam as caçadas na Chapada. Correções:
   - campo novo `MonsterDef.base_species`;
   - `QuestService.kill_matches` passou a contar a variante como a espécie original;
   - "espécies diferentes" passou a contar pela espécie original;
   - `base_species` foi posto nos 3 `highland_*.tres` e no gerador `game/tools/world/build_hunt_areas.py`.

   Conferido no cliente: o chefe da Chapada avança as etapas do Seu Zé.
2. **Erro de script ao trocar de mapa.** `AudioDirector._free_voice_3d` usava vozes de som que já tinham sido apagadas junto com o mapa anterior. Agora ele descarta essas vozes antes (`game/scripts/client/audio_director.gd`).
3. **Exportação dos clientes.** O `export_presets.cfg` passou a incluir `assets/ui/ui_kit.json` e `assets/cutscenes/*/*.json`. O jogo lê esses arquivos em tempo de execução.
4. **`make test`** agora roda o verificador de ligações.

Arquivos novos:

- `game/tests/beta/test_content_links.gd` e `.tscn`;
- `game/tests/beta/beta_route_client.gd`;
- `game/tests/beta/run_beta_route.sh`;
- `game/tests/beta/run_ws_duo.sh`.

## O que falta

### Bloqueia o beta

1. **As provações dos anciãos não funcionam.** Isso vale para o fantoche do Seu Zé, as mudas da Vó Aninha e os seis tatus do Velho Tião.
   - A provação começa junto do ancião, no Porto, e o Porto é zona sem combate.
   - No cliente, o fantoche nasce, mas o golpe é recusado com "Não dá para lutar aqui" (captura `.work/beta/35_porto_provacao_ze.png`).
   - Nas provações de aguentar e de proteger, os monstros também não conseguem atacar. Então elas "passariam" sem luta.
   - **Decisão sua.** Opções:
     - (a) o ancião manda a provação acontecer num mapa de caça;
     - (b) liberar combate só entre o jogador e os monstros da provação dele;
     - (c) levar o jogador a uma arena própria.

   Sem isso, os 3 títulos de combinação não saem em jogo normal.

   Desde 30/09/2026 (mapas compartilhados) o monstro da provação já tem dono: só luta com o jogador e o grupo dele. Isso deixa a opção (b) mais perto, mas continua sem decisão; nada mudou no Porto.

### Pode ficar para depois

- **Cenário final dos mapas de caça (pendente).** Campos, Mata e Chapada ainda são protótipos: chão chapado, trilha reta e pedras e buritis simples.
- **Buriti na frente do personagem na chegada** (Campos e Mata; `12_campos_chegada.png`, `17_mata_chegada.png`). Um buriti enfeite fica entre a câmera e o SpawnPoint e cobre a tela.
- **Telhado na frente do personagem junto do Seu Zé** (`35_porto_provacao_ze.png`). O telhado da casa não fica transparente e esconde o jogador.
- **Minimapa dos mapas de caça.** Ele sai da grade, sem arte própria, e aparece quase vazio (uma cor lisa com uma faixa escura).
- **Sombras dos monstros nos mapas de caça.** Aparecem como manchas pretas duras ao lado de cada monstro (`13_campos_luta.png`, `18_mata_luta.png`).
- **Folhagem e nomes cobrindo monstros.**
  - Na borda do Campo de Treino, as palmeiras cobrem os monstros (`03_treino_luta.png`).
  - O tatu da provação nasce em cima do Mestre Jatobá, e os nomes se sobrepõem (`05_treino_provacao.png`).
- **Portal oeste do Porto → `arena_burning`.** O mapa não existe, então o portão fica fechado com o aviso de "Recomendado: PVP". Isso é esperado.
- **Chapada (resolvido em 30/09/2026).** O dono removeu a evolução: morrer perto dos monstros não cria chefe. Os chefes são fixos nos covis.
- **Visual dos portais.** Está sendo trocado pelo agente de efeitos (PortalFx).
- **Grupo (30/09/2026), para depois:**
  - o grupo não sobrevive a reinício do servidor (decisão: não precisa);
  - membro que cai fica no grupo como "desconectado" até sair ou ser expulso (não há tempo-limite para membro comum, só para o líder);
  - ainda não existe "bloquear jogador" (GDD §13); quando existir, deve esconder convites de quem foi bloqueado;
  - sussurro (chat privado) continua para depois;
  - Estrelas do monstro vão só para o dono (maior dano), sem divisão no grupo.

Não foi encontrado texto de chave sem tradução nem HUD quebrado nas capturas.

## Como rodar o beta

1. **Servidor e túnel** (na máquina do dono):

   ```
   make serve-ngrok            # servidor WebSocket + túnel ngrok (Ctrl+C derruba os dois)
   make serve-ngrok DEV=1      # igual, com os comandos de teste (/dev, /chefe, /noite) — só para testar
   ```

   O endereço público fica fixo em `wss://poetic-calculably-nayeli.ngrok-free.dev` (variável `NGROK_URL` do Makefile).
2. **Clientes para os jogadores:**

   ```
   make clients                # gera build/Perdidos-windows.zip e build/Perdidos-linux.zip
   ```

   - O `make clients` grava `game/client_config.cfg` com o endereço do ngrok. Os clientes já entram conectando nele.
   - **Os templates de exportação ainda não estão nesta máquina.** A primeira vez baixa cerca de 1,3 GB para `~/.local/share/godot/export_templates/4.7.2.stable/`.
   - Os presets e os filtros estão prontos:
     - Windows Client, Linux Client e Linux Dedicated Server;
     - `tests/` e `tools/` ficam fora;
     - os JSON lidos pelo jogo e `client_config.cfg` entram.
3. ~~Mande os zips.~~ **Desde 01/10/2026: mande o launcher** (ver "Launcher e login" abaixo). O `.exe` aberto direto mostra "Abra pelo launcher" e o servidor do `make serve-ngrok` recusa quem entra sem conta. Para o modo antigo, sem login: `make serve-ngrok NO_AUTH=1`.
4. **Para conferir o túnel da sua máquina:** `make run-ngrok-client`.

## Launcher e login (01/10/2026)

Pedido do dono: launcher com cadastro por e-mail e senha, que sempre confere a última versão e baixa da pasta pública do Drive. Detalhes em `launcher/README.md`.

| Passo | Como | Status |
|---|---|---|
| Compilar o launcher | `make launcher` (Linux) e `make launcher-windows` (Windows, compila no Linux sem mingw) → `build/launcher/` | pronto |
| Publicar versão | `make release VERSION=x.y.z NOTES="…"` → subir os 2 zips e depois o `latest.json` na pasta do Drive (`build/release/COMO-PUBLICAR.txt`) | pronto; **a pasta do Drive ainda não tem `latest.json`**: hoje ela tem só `windows/Perdidos.exe` e `linux/Perdidos.x86_64` soltos, e o launcher mostra "Nenhuma versão publicada ainda" |
| Servidor com login | `make serve-ngrok` (jogo com `--require-auth` na 7777 + API/porteiro na 8080 + ngrok → 8080) | pronto |
| Segredo do JWT | `~/.config/perdidos/secrets.env` (criado sozinho, `chmod 600`) | criado na 1ª vez do `make serve-ngrok` |
| Contas | `.run/accounts.db` (SQLite) | — |
| Donos dos nomes | `character_owners.json` na pasta dos saves | o 1º que entra com um nome vira dono |

Conferir de novo:

| O quê | Comando | Resultado em 01/10/2026 |
|---|---|---|
| Go (API, JWT, argon2id, limites, proxy WebSocket, parser do Drive, download com retomada, SHA-256, troca atômica) | `make launcher-test` (parte Go) | PASS |
| Ponta a ponta: API + porteiro + servidor Godot `--require-auth` + clientes headless | `GODOT=$PWD/.tools/godot-4.7.2 launcher/tests/auth_integration.sh` | PASS: 11 verificações (token de verdade entra no mundo; sem token, token adulterado e nome de outra conta são recusados; nada de senha/token/segredo nos logs) |
| Drive real (só leitura) | `cd launcher && PERDIDOS_DRIVE_LIVE=1 go test -run Live -v ./internal/drive/` | PASS: lista a pasta, acha `windows/Perdidos.exe` e baixa os primeiros bytes ("MZ") com retomada (HTTP 206) |
| Telas | capturas em `.work/launcher/` (entrar, criar conta, principal, atualizando, pronto, sem versão, jogo aberto sem o launcher) | conferidas |

**Antes de chamar os amigos:** publicar a primeira versão (`make release VERSION=0.1.0`), subir no Drive, rodar `make serve-ngrok` e mandar o launcher.
