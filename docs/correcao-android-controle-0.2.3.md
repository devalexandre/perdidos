# Android e controle USB — 0.2.3

Relato: GameSir X5 Lite USB-C no smartphone sem resposta a comandos, janela de skills vazia e NPCs com sprite do personagem.

O APK anterior contém 90 skills e 31 NPCs. O teste dos assets extraídos dele passou nas 800 verificações de conteúdo e sprites; isso não reproduz a execução do backend Android nem confirma qual APK está instalado no celular. Nenhum dispositivo está conectado ao ADB neste ambiente.

Alterações:

- Content também aceita arquivos `.tres.remap` da listagem física, sem depender exclusivamente da listagem de ResourceLoader. Arquivos que falham no carregamento e categorias vazias agora produzem erro no log.
- O catálogo mobile usa apenas as skills aprendidas. Foi removida uma chamada a `Content.all_skills()`, método inexistente, que quebrava o catálogo quando o progresso estava vazio.
- RT+B e LT+B acionam os atalhos 5 e 9. Antes B era interceptado como voltar antes de consultar os gatilhos. B continua cancelando a mira e fechando janelas.
- Controles criados ao atualizar a árvore de skills ganham foco mesmo quando outro botão da janela já está focado.
- Configurações mostram versão, controles detectados e último evento de botão/analógico recebido.
- APK passa a identificar a versão como 0.2.3, com versionCode 2; o anterior usava versionName 0.1.0 e versionCode 1, apesar da versão 0.2.2 do projeto.
- Orientação no projeto e no export Android passa de paisagem fixa para paisagem pelo sensor: aceita as duas posições horizontais, inclusive com o USB-C do controle no lado oposto.

Artefato local: `build/android/Perdidos-0.2.3.apk`. Não foi publicado e os pacotes/manifesto de release 0.2.2 permanecem disponíveis.

Validação: testes da janela de skills em 1600×720, controles mobile e gamepad com eventos simulados. O APK foi exportado e assinado com a chave debug existente. A confirmação física exige instalar este APK e observar Configurações com o GameSir conectado. Se a mensagem indicar nenhum controle ou se nenhum evento chegar, o problema de detecção continua pendente e precisa dos dados do dispositivo.
