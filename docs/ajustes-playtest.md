# Ajustes do playtest do dono

Origem: `analise-game.md` e capturas enviadas em 27/09/2026. Regras registradas no GDD.

| # | Anotação | GDD | Responsável | Estado |
|---|---|---|---|---|
| 1 | Combate com movimento: avanço no golpe e empurrão no alvo | §10.2.1 | Agente A | em andamento |
| 2 | Animações de ataque armado e desarmado | §10.2.1 | Agente A (corpo-base + todas as camadas) | em andamento |
| 3 | Som nos golpes, acertos, críticos, erros e mortes; **cada arma, cada skill e cada monstro com o próprio som** | §10.2.1 | coordenador | **código pronto** (`CombatAudio`) + provisórios CC0; sons próprios esperando a chave do ElevenLabs com permissão de efeitos |
| 4 | Jogo ocupando a janela inteira, com a interface por cima e sem faixas cinzas | §9.5 | Agente V (renderização) | em andamento |
| 5 | Botões de menu numa engrenagem, mantendo os atalhos | §9.5 | Agente R | **pronto** |
| 6 | No nível 10, cada Mestre fala sobre o título que ensina | §9.3 | Agente R | **pronto** |
| 7 | DES: velocidade de ataque, esquiva e acerto | §6.2, §10.2 | Agente R | **pronto** |
| 8 | Novo atributo SOR (Sorte): crítico, drop e monstros raros | §6.2, §10.2 | Agente R | **pronto** |
| 9 | Personagem maior que os monstros | §10.2.1, §17.2 | Agente W (tamanho dos monstros: **pronto**) + Agente V (zoom e tamanho na tela) | em andamento |
| 10 | Cenário pintado no estilo das referências | §17.0.A | Agente V | em andamento |
| 11 | Narração da abertura em 6 idiomas (narrador: o deus supremo, voz de velho) | §9.3 | coordenador | **pronto** |
| 12 | Teste instável: falar com a criança que anda pela praça às vezes falha | — | coordenador | a fazer (fazer o NPC esperar no teste) |
| 13 | Legendas em japonês sem fonte com caracteres japoneses | — | coordenador | a fazer (fonte livre Noto Sans JP) |
| 14 | Avaliar refazer monstros e cenários com Blender (protótipo com o Tatu-Pedra, auditoria contra a especificação) | §17 | coordenador | no roadmap (`plano-mvp.md`), começa depois do Agente V |
| 15 | Kit inicial: 30 poções de vida e 30 de mana (as 999 do personagem de teste do dono ficam até ele pedir para tirar) | — | coordenador | **pronto** |
| 16 | Mais monstros no Campo de Treino + 1–2 médios por área | §9.3 | coordenador | **pronto** |
| 17 | Chefe surge após 500 abates da espécie no mesmo mapa; covil fixo; nunca no Campo de Treino | §10.6.1 | roadmap F3 | anotado |
| 18 | Dia e noite: monstros noturnos diferentes e 30–50% mais fortes; chefes +100% em forma atroz; quests de dia/noite | §10.7 | roadmap F3/F4 | anotado |
| 19 | Brasões das cidades nas bandeiras | §4.0.1 | coordenador | **pronto** (10 brasões em `assets/ui/crests/`) |
| 20 | Som do facão parecia barra de metal; revisar todas as armas por categoria (corte, impacto, perfuração, mágico) | §10.2.1 | coordenador | **parcial**: provisórios de corte trocados (facão = "chop", espada = "slice") e o crítico deixou de substituir o som da arma; auditoria das outras armas no roadmap |
| 21 | Efeito de subir de nível (luz, anel, pétalas, "NÍVEL X!", som), visto por todos da área | — | coordenador | **pronto** (`LevelUpFx`) |
| 22 | Sons e músicas definitivos (ElevenLabs): 105 de combate, cidade, progressão, abertura, título noturno, Campo de Treino e temas das 10 capitais | §18 | coordenador | **pronto** — créditos do ciclo quase esgotados (38,5 mil de 39,7 mil) |
| 23 | Campo de Treino: cada zona toca o tema da sua cidade | §18 | coordenador | **pronto** |
| 24 | Campo de Treino redesenhado no Blender: relevo orgânico, cada nação com sua cena própria, visual pintado à mão como a tela de título | §17.0.A | Agente V | em andamento |
| 25 | Skills e magias sem efeito visual ("está bem ruim", "só círculos coloridos"); nome da skill ao usar | §10.2.1, §17.0 | agente de efeitos | **1ª versão pronta** (`SkillFx`, 25 folhas em `assets/fx/skills/`, nome gritado acima do conjurador; ver `briefing-sprites-personagem.md` §4) — esperando o olhar do dono |
| 26 | Ícones das skills: a barra mostrava só as iniciais | §9.5 | coordenador | **pronto** (12 ícones 32×32 em `assets/skills/`, gerados de `tools/art/fx/gen_skill_icons.py` a partir da arte dos efeitos) |
| 27 | Roupa por nacionalidade (Viajante recolorido por região) e quadro da região na criação | §4.0, §6.1 | coordenador | **pronto** |
| 28 | Roupa própria por título (forma, não só cor), base dos cosméticos | §8.5, §14 | agente de roupas | **pronto** (7 títulos × 2 corpos, `tools/art/title_outfits/`; pontos fracos no relatório de 29/09) |
| 29 | **Caminho do arqueiro na Terra de Pindorama**: hoje só há lâmina (guerreiro) e arcano (mago); falta o título de arco com seus ramos, skills, arma e roupa | §8.5 | próxima sessão (29/09) | anotado pelo dono em 28/09 |
| 30 | **Mais skills por título**: hoje cada título tem 1 skill exclusiva, o que é pouco. Meta: até ~10 por título, para quem quiser focar em um só título conseguir jogar só com ele (inclui o futuro caminho do arqueiro). **Decidido:** o título herda as skills do título anterior e ainda ganha várias próprias (herdar não substitui ter mais). Cada título tem a sua árvore de skills separada, com pré-requisitos entre as skills da árvore | §8.5, TITULOS-E-SKILLS.md | próxima sessão (29/09) | anotado pelo dono em 29/09 |
| 31 | Títulos v0.4 da Terra de Pindorama: 5 skills por título, arco, suporte e tanque, anciãos com lenda e quest difícil | TITULOS-E-SKILLS.md §3 | 4 agentes | **pronto** (30/09): 68 skills novas, 16 roupas, chefe/atroz, dia e noite, ícones e efeitos |
| 32 | Cliente para Windows e Linux conectando pelo ngrok (WebSocket) | — | coordenador | **pronto** (`make clients`, `make serve-ngrok`) |
| 33 | Provações das quests dos anciãos: Vó Aninha = **proteger 3 mudas de pequizeiro por 60 s** (mudas aliadas: cura e escudo valem; ondas atacam as mudas; basta 1 viva; falhou = tentar de novo); Velho Tião = **sobreviver 45 s contra 6 tatus** | §3.3 | decidido pelo dono (30/09/2026) | feito |
| 34 | Mapa de caça de Pindorama (`fields_pindorama`): sem ele o chefe só aparece por comando de teste | §10.6.1 | roadmap | pendente |
