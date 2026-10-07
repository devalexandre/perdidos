# O que falta terminar

Pausado em 01/10/2026. Três frentes pararam no meio. Cada uma tem uma nota de retomada em `.work/handoff/`, com o que está pronto, o que ficou pela metade e o próximo passo.

## Primeiro, ao voltar

1. Ler as notas em `.work/handoff/`: `grupo.md`, `monstros.md` e `launcher.md`.
2. Rodar `make test` e corrigir o que quebrou. O código pode ter ficado no meio de mudanças.
3. Reiniciar o servidor (Ctrl+C e `make serve-ngrok`) e gerar clientes novos (`make clients`). Isso só depois que as três frentes terminarem.

## Frentes que pararam no meio

### Mapas compartilhados, grupo, troca e pergaminho de retorno
Nota: `.work/handoff/grupo.md`.
- **Mapas sem instância:** todos os jogadores do mesmo mapa se veem.
- **Grupo, pela interface e pelo chat:**
  - comandos `/grupo nome`, aceitar, recusar, sair, expulsar e líder, e `/g` para falar só com o grupo;
  - até 5 membros, com o XP dividido;
  - painel com a vida de cada membro;
  - o drop fica alguns segundos reservado para quem mais causou dano.
- **`/online`:** lista quem está conectado e em qual mapa.
- **Troca entre personagens:** pelo clique direito ou por `/troca nome`, com janela dos dois lados, confirmação dupla e validação no servidor.
- **Pergaminho de Retorno:** leva à última cidade visitada, está à venda no Porto e o kit inicial traz 3.

### Chefes fixos, sem evolução: PRONTO, falta conferir
Nota: `.work/handoff/monstros.md`.
- **Pronto:**
  - a evolução e o chefe por 500 abates saíram;
  - na Chapada (Subida Vermelha), os 3 chefes do Sabiá moram em covis fixos com bando e renascem a cada 10 min;
  - à noite viram a forma atroz;
  - os documentos foram atualizados.
- **Falta:** rodar de novo `make test`, que falhou só em `grid_stops_on_cell_center` e `clock_synced`, testes de movimento que já falhavam às vezes. Também falta rodar `run_beta_route.sh`, que parou no meio.

### Launcher (pasta `launcher/`, Wails v3): COMPILADO, versão 0.1.0 pronta para publicar
Nota: `.work/handoff/launcher.md`. Guia: `launcher/README.md`. Os testes passaram e o `make test` está verde.
- **Pacotes gerados em 01/10/2026:** `build/release/Perdidos-0.1.0-windows.zip`, `Perdidos-0.1.0-linux.zip` e `latest.json`. Integridade dos ZIPs, SHA-256, tamanho, executável e `version.txt` conferidos.
- **Launchers gerados:** `build/launcher/PerdidosLauncher.exe` e `build/launcher/perdidos-launcher`. O Linux abriu em tela virtual; o Windows ainda precisa ser conferido num Windows real.
- **Falta publicar no Drive:** suba os 2 zips e, por último, o `latest.json` na raiz da pasta pública; veja `build/release/COMO-PUBLICAR.txt`. A publicação não foi feita nesta sessão, que não tem acesso autenticado à conta dona da pasta. Depois, distribua os launchers aos amigos.
- **Validação do launcher:** `make launcher-test` passou, incluindo os 11 cenários de integração. Corrigida a compilação do teste para funcionar também numa cópia sem metadados Git (`-buildvcs=false`). Logs desta retomada em `.work/launcher-final/`.
- **Suíte geral reexecutada:** `make test` terminou com código 0; interface e 447 verificações de efeitos passaram. Permanecem as 3 pendências dos anciãos e mensagens de liberação de texturas ao encerrar o teste de UI, sem reprovar a suíte.
- **Servidor:** o `make serve-ngrok` agora exige login (a API e o porteiro ficam na porta 8080, e o ngrok aponta para ela). Para voltar ao modo antigo, sem login: `make serve-ngrok NO_AUTH=1`.
- **Executáveis antigos:** os do `make clients` agora abrem com "Abra pelo launcher".
- **Ainda não testado:**
  - o túnel ngrok real com o porteiro;
  - o launcher num Windows de verdade (precisa do WebView2, que já vem no Windows 10/11).

## Decisões que esperam o dono

- **Provações dos 3 anciãos:** hoje começam no Porto, onde não há combate, e não funcionam. Opções:
  - (a) num mapa de caça;
  - (b) combate liberado só com os monstros da provação;
  - (c) arena particular. Recomendado: **(c)**.
  Sem isso, os títulos Brasa no Facão, Raiz do Cerrado e Casco de Jabuti não saem jogando normalmente.
- **Personagem "TesteConexao":** foi criado sem querer no servidor durante um teste. Pode ser apagado.

## Pendências conhecidas (podem esperar)

- **Diferenciação dos Sprites de Títulos (Roupas):** hoje quase todos os títulos de ramo compartilham o mesmo modelo 3D base (`branch_coat`) do pipeline do Blender, variando somente as cores com shader de paleta. Por isso, todos os títulos parecem vestir a mesma roupa. Planejado: criar silhuetas e cortes visuais únicos por arquétipo (Tanque com placas/carapaça pesada, Ágil/Lâmina com couro batido e faixas, Arcano com túnicas longas e mangas largas, Xamânico com peles rústicas e mantos de penas).
- **Redesign da Tela de Criação de Personagem:** modernizar o visual de `title_screen.gd` para o layout 2.5D com pedestal rúnico de pedra e iluminação celestial à esquerda (zoom 3x e rotação suave), e painel de pergaminho/madeira estilo Sun Haven à direita (seleção visual de cortes de cabelo, olhos, cor de pele, nacionalidade e nome).
- Os mapas de caça ainda são protótipos: chão liso, minimapa quase vazio e sombras duras dos monstros.
- **Masmorra da Mata Encantada — Caverna do Reino Encoberto (planejamento):** validar a fonte da lenda amazônica da passagem subterrânea antes de atribuir o motivo a uma tradição real; criar o mapa de andares, monstros originais de esqueleto/raiz e o Corpo-Seco; integrar o Lobisomem como chefe de covil (estágio 3) e sua forma Atroz noturna (estágio 4) com sprite próprio. A Mula sem Cabeça fica reservada para um arco maior e não deve entrar nesta masmorra.
- Na animação de arco, a mão de trás não puxa a corda.
- Em algumas roupas de título, detalhes pequenos trocam de lado entre as poses.
- A Ventania Atroz se perde no fundo perto da fogueira.
- As outras 18 espécies não têm chefe nem forma atroz.
- Exportar para Android ainda não começou. O primeiro passo seria um APK de teste; depois, adaptar a interface ao toque.
- A tela de título com a lista de servidores ("Teste"), o arrasto de skill para a barra e a correção do personagem que andava ao arrastar estão prontos no código, mas ainda não chegaram ao `.exe` dos amigos.
