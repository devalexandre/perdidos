# Perdidos

MMORPG 2.5D em pixel art (Godot 4.7.2). Documentos em `docs/` (comece pelo `GDD-projeto-isekai.md` e pelo `proximos-passos.md`).

## Comandos (`make help` lista todos)

| Comando | O que faz |
|---|---|
| `make run` | Sobe o servidor local e abre o jogo na tela de título. Fechar o jogo derruba o servidor. |
| `make run-duo` | Servidor + 2 jogos lado a lado (Ana e Bia), para testar multiplayer. |
| `make run-dev` | Igual ao `run`, com os comandos de teste do dono no chat (`/dev ...` para títulos, árvores e quests dos anciãos; `/chefe`, `/noite`... para chefes). Ver `docs/debug-sabia.md`. |
| `make test` | Testes automáticos (servidor + clientes). |
| `make build` | Gera os executáveis em `build/` (Windows, Linux e servidor dedicado). Na primeira vez baixa os templates de export (~1,3 GB). |
| `make up` / `make down` | Sobe/derruba o servidor do jogo + PostgreSQL no Docker (`infra/docker-compose.yml`). |
| `make db-shell` | Abre o `psql` no banco do Docker. |
| `make launcher` / `make launcher-windows` | Launcher (conta + atualização + jogar) para Linux / Windows → `build/launcher/`. |
| `make release VERSION=x.y.z` | Gera os zips da versão + `latest.json` em `build/release/` e o passo a passo para subir no Drive. |
| `make launcher-test` | Testes do launcher, da API de contas e do login no servidor do jogo. |

A Godot 4.7.2 é baixada sozinha para `.tools/` no primeiro comando.
`make run` e `make up` usam a mesma porta (7777/udp): rode um de cada vez, ou use `make run PORT=7790`.

## Banco de dados

- Esquema de produção: `infra/db/schema.sql` (PostgreSQL 16+). Aplicar num banco vazio:
  `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f infra/db/schema.sql`
- No Docker ele roda sozinho na primeira subida do postgres.
- Credenciais: `infra/.env` (criado a partir de `infra/.env.example` no primeiro `make up`). Troque a senha antes de produção.
- O servidor do jogo ainda salva os personagens em JSON (volume `saves`). A troca para o PostgreSQL entra na Fase 2, com as contas.

## Launcher, contas e atualização

Desde 01/10/2026 os jogadores entram pelo **launcher** (`launcher/`, Wails v3): criam conta com
e-mail e senha, o launcher baixa/atualiza o jogo a partir da pasta pública do Google Drive e abre o
jogo já com a sessão. O servidor da internet (`make serve-ngrok`) **exige** essa sessão; o `.exe`
aberto direto mostra "Abra pelo launcher". `make run`, `make run-dev` e `make test` seguem sem login.

1. `make launcher-windows` e `make launcher` → mande `build/launcher/PerdidosLauncher.exe` (Windows) ou
   `build/launcher/perdidos-launcher` (Linux) para os amigos (uma vez só).
2. Nova versão do jogo: `make release VERSION=0.1.3 NOTES="o que mudou"` e suba os arquivos de
   `build/release/` no Drive seguindo `build/release/COMO-PUBLICAR.txt`.
3. `make serve-ngrok` sobe o jogo **com login** + a API de contas (porta 8080) e aponta o ngrok para ela.

Detalhes (onde instala, formato do `latest.json`, API, segurança, SQLite): `launcher/README.md`.

## Testar com outras pessoas pelo ngrok

O servidor roda no seu computador e o ngrok o abre na internet em `poetic-calculably-nayeli.ngrok-free.dev`. O túnel do ngrok é HTTP, então nesse modo o jogo conecta por **WebSocket** (`--transport=ws`); o `make run` local continua em UDP (ENet).

1. Uma vez só: `ngrok config add-authtoken <seu token>`.
2. Gere os clientes (a primeira vez baixa os templates de export, ~1,3 GB):
   ```
   make clients
   ```
   Saem `build/Perdidos-windows.zip` e `build/Perdidos-linux.zip`, já apontando para o servidor do ngrok. Para outro endereço: `make clients SERVER_URL=wss://outro.dominio`.
3. Abra o servidor na internet (Ctrl+C derruba o túnel e o servidor):
   ```
   make serve-ngrok            # com comandos de teste no chat: make serve-ngrok DEV=1
   ```
4. Mande o **launcher** para quem vai testar (ver acima); os zips do `make clients` sozinhos agora
   mostram "Abra pelo launcher". Para voltar ao modo antigo, sem login: `make serve-ngrok NO_AUTH=1`.
   Para conferir o túnel da sua máquina: `make run-ngrok-client`.

O `make serve-ngrok` agora sobe três coisas: o jogo (WebSocket, porta 7777, `--require-auth`), a API de
contas + porteiro (porta 8080, log em `.run/auth.log`, contas em `.run/accounts.db`) e o ngrok apontando
para a **8080**. O porteiro manda `/api/*` para a API e o resto (o WebSocket do jogo) para a 7777.

No campo de servidor da tela de título também dá para digitar `wss://…` ou só o domínio do ngrok.

### Meta de escala: 50 mil jogadores

**Premissa deste planejamento:** 50 mil contas cadastradas, com pico inicial estimado em 5% simultâneo
(2.500 jogadores). Se a meta for 50 mil simultâneos, esta recomendação não se aplica: será necessário
redesenhar e dimensionar a arquitetura para esse pico específico.

- O servidor atual ainda é um único processo Godot. Os mapas são compartilhados dentro de cada processo;
   não há roteador de shards, autoscaling, nem limites de CPU/memória definidos no Compose.
- O transporte ENet tem teto de 64 conexões por processo. A produção usa WebSocket e não tem um teto
   equivalente configurado na aplicação. Esse teto não é uma promessa de desempenho: ainda não há teste
   de carga que prove quantos clientes um processo sustenta.
- Recomendação de arquitetura para a meta: proxy TLS/WebSocket e API de contas redundantes, PostgreSQL
   gerenciado com alta disponibilidade e vários processos de jogo Linux atrás de um roteador de shards.
   Com 2.500 CCU, 40 processos é apenas o piso aritmético se cada um fosse limitado a 64 conexões; o
   número real e a quantidade de máquinas dependem do teste. Os mapas compartilhados exigem que o
   roteador mantenha juntos os jogadores que precisam se encontrar.
- Perfil de referência para o primeiro worker de benchmark: Linux dedicado, 8 vCPU, 16 GiB de RAM e
   rede de 1 Gbps. É um ponto de partida para medir um processo, não uma especificação de produção aprovada.

**Teste de carga planejado para 03/10/2026:** executar no hardware de referência com 3, 10, 25, 50 e
64 clientes por processo; manter cada degrau por 15 minutos e fazer um soak final de 30 minutos. Medir
CPU/RAM, p95/p99 do tick (servidor configurado em 20 Hz; orçamento de 50 ms por tick), latência,
desconexões e crescimento de memória. Manter pelo menos 30% de folga; qualquer degrau que exceda 35 ms
no p95 do tick ou apresente crescimento contínuo de memória reprova o worker. Registrar o maior degrau
aprovado e então recalcular shards e máquinas para 2.500 CCU. Até esse teste, a única validação
multiplayer simultânea registrada é de 3 clientes.

### Jogar junto: mapas compartilhados e grupo

Desde 30/09/2026 todo mapa (Campo de Treino, Porto, Campos, Mata, Chapada) é **um só para todos**: quem está no mesmo mapa se vê e enfrenta os mesmos monstros. Para jogar junto, monte um **grupo** (até 5):

- **Convidar:** clique (esquerdo ou direito) no outro jogador → **Convidar para o grupo**, ou digite no chat `/grupo Nome` (funciona em qualquer mapa).
- **Responder:** aparece uma janela com **Aceitar** e **Recusar** (ou `/grupo aceitar` / `/grupo recusar`).
- **No grupo:** painel na esquerda com vida, mana, nível, a coroa do líder e o mapa de quem estiver em outro lugar. `/g mensagem` (ou a aba **Grupo** do chat) fala só com o grupo.
- **O que o grupo dá:** a XP do monstro se divide entre quem está perto (com bônus de 10% por membro a mais), o abate conta nas quests de todos por perto, o drop fica reservado ao grupo por 10 s e cura, escudo e reforços valem para os membros.
- **Líder:** só ele convida; `/grupo expulsar Nome` e `/grupo líder Nome` (ou clique no membro no painel). Se o líder cair, tem 3 min para voltar; depois a liderança passa ao membro mais antigo.
- **Sair:** botão **Sair do grupo** no painel ou `/grupo sair`. O grupo some quando sobra 1. `/grupo` lista os membros.
- **Quem está online:** `/online` mostra quem está conectado, em que mapa e o nível.
- Fora do grupo vale a regra do Ragnarok: o monstro é de quem causou mais dano. A provação de quest de alguém só luta com ele e com o grupo dele.

### Trocar itens e Estrelas

- **Pedir:** fique perto do outro jogador (mesmo mapa, poucos passos, fora de combate) e clique nele → **Propor troca**, ou digite `/troca Nome`. Ele recebe **Aceitar** / **Recusar** (ou `/troca aceitar` / `/troca recusar`).
- **Oferecer:** a janela da troca abre ao lado do inventário. Arraste itens do inventário para o seu lado (ou botão direito no item); botão direito num item da sua oferta tira. Ajuste as **Estrelas** no campo.
- **Fechar o negócio:** os dois apertam **Confirmar**; qualquer mudança desfaz as confirmações. Com os dois confirmados, os dois apertam **Trocar**. **Cancelar** (ou Esc) desiste; afastar-se, cair ou entrar em combate também cancela.
- Item equipado não entra na troca. Cada troca fica registrada no servidor para a moderação.

### Pergaminho de Retorno

Leva você de volta à última cidade em que esteve (hoje, o Porto), no ponto seguro. Personagem novo ganha 3; o mercado do Porto vende. Use pelo inventário ou arraste para a barra 1–0. Fora de combate é na hora; em combate leva 1 s e um golpe interrompe. Não funciona no Campo de Treino, em provação nem com troca aberta.

O servidor precisa ser reiniciado (Ctrl+C e `make serve-ngrok`) e os amigos precisam do cliente novo (`make clients`) depois de qualquer mudança no jogo; cliente antigo recebe "atualize o jogo".

## Sistemas do Jogo e Documentação Detalhada

Todas as mecânicas, regras e especificações do projeto estão organizadas e documentadas em `docs/`:

- **[Sistema de Crendices e Amuletos Folclóricos](docs/crendices-e-amuletos.md)**: Encaixes de crendice em equipamentos, 20 amuletos folclóricos, condições de superstição viva, dormência da sorte na morte, altares de consagração gratuita e sinergias temáticas (sem venda em NPCs).
- **[Combate, Atributos e Mira Mobile](docs/combate-e-atributos.md)**: Fórmulas de combate atualizadas (FOR corpo a corpo, DES longo alcance com obrigatoriedade de flechas na mão secundária/offhand, INT para magia/mana, SAB para sagrado/curas/buffs, VIT para vida/defesa, SOR para crítico/drops), títulos de mestria e sistema de mira inteligente para celular no estilo Albion Online (mira por proximidade, retargeting automático na morte e toque na tela).
- **[Fauna Peçonhenta e Monstros Perigosos do Brasil](docs/fauna-peconhenta-e-monstros.md)**: Escorpião-amarelo, aranhas armadeira e marrom, serpentes (jararaca, cascavel, surucucu e coral), taturana lonomia, abelhas e mosquito Aedes aegypti em 3 variantes (Comum, Atroz da noite e Chefe de Covil).
- **[Mapas, Cavernas e Campo de Treinamento](docs/mundo/mapas-e-treinamento.md)**: O Campo de Treinamento reformulado com o novo mentor **Instrutor Bento** (ensina atributos, munição, títulos e crendices) e o Altar de Crendice do acampamento, além do padrão visual das veredas e galerias de caverna.
- **[Roadmap das Próximas Expansões](docs/mundo/roadmap-expansoes.md)**: As 4 grandes expansões temáticas do backlog: Ruínas de Ratanabá, A Cidade Perdida de Z, O Vilarejo Fantasma de Hoer Verde e Túneis da Terra Oca.
- **[Site Oficial / Landing Page](site/index.html)**: Vitrine pública com prévia das criaturas, títulos, combate interativo, crendices, fauna peçonhenta, roadmap de expansões e lista de espera.

