# Controles: teclado/mouse, toque e controle (joypad)

O jogo aceita três jeitos de jogar ao mesmo tempo, sem precisar trocar nada nas configurações:

- **Teclado e mouse** (PC);
- **Toque** (celular: analógico virtual + botões de ação, "Controles touch para celular" nas Configurações);
- **Controle** com layout Xbox (A/B/X/Y, D-pad, 2 analógicos, LB/RB, LT/RT, Start/Select). Testado em
  simulação; feito para o **GameSir X5 Lite (USB-C, Android)**, controle de Xbox/8BitDo no PC e qualquer joypad
  que o sistema reconheça como controle padrão.

## Controle: mapeamento

| Botão | No mundo | Em menu, janela ou diálogo |
|---|---|---|
| Analógico esquerdo / D-pad | Andar (em grade, como o analógico do celular) | Mover o foco |
| **A** | Agir: ataca o alvo travado; senão pega o item no chão ou conversa com o NPC ao lado; senão usa o objeto do mapa ao lado (portal, altar…); senão trava o monstro mais perto | Escolher (apertar o botão em foco) |
| **B** | Voltar: cancela a mira, fecha o que estiver aberto, solta o alvo | Fechar / voltar |
| **X** / **Y** | Atalhos **1** e **2** da barra | — |
| **RT** segurado + X / Y / B / A | Atalhos **3 / 4 / 5 / 6** | — |
| **LT** segurado + X / Y / B / A | Atalhos **7 / 8 / 9 / 0** | — |
| **LB** / **RB** | Alvo anterior / próximo (monstros por perto) | — |
| **R3** (clicar o analógico direito) | Trava o monstro mais perto (de novo: solta) | — |
| **L3** (clicar o analógico esquerdo) | Poção de vida rápida | — |
| Analógico direito | Girar a câmera (esquerda/direita) e zoom (cima/baixo) | — |
| **Start** | Abre/fecha o menu (engrenagem: Skills, Atributos, Missões, Inventário, Personagem, Menu) | Abre/fecha o menu |
| **Select** | Mapa (local → atlas → fechado) | Mapa |

Skills de área, cone ou linha: ao apertar o atalho, a mira aparece; o **analógico esquerdo** aponta,
**A** (ou o mesmo atalho) lança e **B** cancela.

Inventário/loja: o foco anda pelos espaços; **A** num item = o mesmo que o botão direito do mouse
(usar/vestir; com a loja aberta, vender 1; numa troca, oferecer). Na loja, **A** em "Comprar" compra.

Dentro do jogo a ajuda fica em **Menu → Configurações → Controle → Ver botões**.

### O que muda na tela com o controle

- Assim que o controle conecta (ou qualquer botão dele é usado) os **controles de toque somem**, a barra de
  atalhos volta a aparecer mostrando **X, Y, RT+X…** no lugar das teclas 1–0 e aparece uma **faixa de dicas**
  logo acima do chat (muda conforme o contexto: mundo, menu/diálogo ou mira).
- Uma **moldura dourada** mostra o botão em foco.
- **Tocar a tela** (ou teclar/clicar) devolve o modo anterior: no celular, os controles de toque voltam — o
  toque fica opcional com o controle conectado. Apertar qualquer botão do controle volta ao modo controle.
- **Desconectar** o controle devolve tudo como estava. A opção "Controles touch para celular" não é alterada.

### Tela de título (criação e seleção de personagem)

| Botão | Ação |
|---|---|
| Primeiro botão apertado | Põe o foco em **Criar personagem / Jogar** |
| D-pad / analógico | Mover o foco (abas, cores, corpo, nome, servidor, botões) |
| **A** | Escolher; no campo de **nome**, abre a edição (no Android abre o teclado virtual) |
| **A** ou **B** no nome | Termina a edição |
| **LB** / **RB** | Aba anterior / próxima (Corpo, Cabelo, Nacionalidade) |
| **Y** | Aparência aleatória |
| **LT** / **RT** | Girar o Viajante |
| **Start** | **Jogar / Criar personagem** |
| **B** | Fecha as Configurações |

Na tela de conta do Android, o primeiro botão põe o foco em "Entrar"; o resto é igual (D-pad + A, A no campo
abre o teclado).

## Teclado e mouse (sem mudança)

Clique no chão anda (segurar segue o cursor), clique em monstro/NPC/item interage, botão direito arrastando
gira a câmera, roda = zoom, Q/E giram. 1–0 barra, I inventário, C personagem, K skills, A atributos, L missões,
M mapa, Enter chat, Esc fecha/abre o menu, Alt+1..6 emotes, 1..9 opções do diálogo.

## Toque (sem mudança)

Analógico virtual à esquerda; à direita botão de ação (mesma lógica do **A**), 4 atalhos em arco, mira/ciclo
de alvo, poção rápida e engrenagem dos 4 atalhos. Tocar no chão anda, tocar em algo interage, dois dedos giram
e dão zoom.

## Para quem mexe no código

- `scripts/client/ui/gamepad_input.gd` (`GamepadInput`): ações `pad_*` registradas em tempo de execução (o
  `project.godot` não tem `[input]`), A/B acrescentados a `ui_accept`/`ui_cancel`, modo controle, foco da
  interface, mapeamento acima e a moldura de foco (`GamepadInput.FocusRing`).
- `scripts/client/ui/combat_assist.gd` (`CombatAssist`): andar por direção, botão de ação, ciclo/trava de alvo
  e poção — **o mesmo** usado pelo toque (`MobileControlsOverlay`) e pelo controle.
- `scripts/client/ui/gamepad_hints.gd` (`GamepadHints`): faixa de dicas.
- Testes: `tests/client/test_gamepad.tscn` (eventos `InputEventJoypadButton`/`InputEventJoypadMotion` via
  `Input.parse_input_event`, controle simulado com `GamepadInput.simulate_connected`).
- Capturas no cliente real: `tests/client/run_gamepad_capture.sh`.
