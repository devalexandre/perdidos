# Briefing — sprites do personagem, roupas por nacionalidade e por título, efeitos de skills

28/09/2026. Para quem vai produzir a arte (artista de pixel art ou geração por IA). Base técnica: `docs/estudo-personagem-2d.md`.

## 0. Regra de origem (obrigatória, GDD §0 regra 5)

- **Nenhuma folha de Ragnarok Online, Samsara Saga ou outro jogo entra como imagem de entrada, molde, grade ou referência de pose** — nem para IA, nem para decalque.
- Motivo: as pranchas "estudante-base" e "títulos" de 28/09 (ChatGPT) repetem a folha do Novice do Ragnarok **pose por pose, na mesma grade e ordem**. Isso é obra derivada da Gravity e não pode ser publicado. Elas ficam em `game/downloads/` (ignorado pelo Godot, git e Docker) apenas como registro, **fora do jogo**.
- Referência permitida: **as nossas próprias poses** (guias de pose renderizados no Blender pelo `.work/d/tools/guide_render.py`), a prancha `game/assets/_reference/wardrobe/title-evolution-v1.png` e descrições em texto do estilo ("chibi, ~3 cabeças, contorno colorido, luz de cima-esquerda").
- Cada entrega vem com um arquivo `ORIGEM.md`: ferramenta, prompt, imagens de entrada usadas e autor.
- **(Arquivado em 28/09: o dono preferiu o Viajante recolorido.)** Para gerar no ChatGPT, use o kit `docs/kit-chatgpt-student-sabia.md`.** Ele traz as nossas pranchas-guia (`docs/guias/student_sabia/`), o prompt exato e o importador (`game/tools/art/import_ai_sheet.py`), que transforma a imagem devolvida nas folhas do jogo. O kit substitui a folha do Novice.

## 1. Formato técnico (o que o jogo lê hoje)

| Item | Valor |
|---|---|
| Quadro | **96 × 96 px**, PNG com transparência (não 64 × 64) |
| Linhas (direções) | S, SE, L, NE, N — nessa ordem. SO, O e NO são espelhadas pelo jogo |
| Colunas | os quadros da animação, da esquerda para a direita |
| Corpo | **sem cabeça**; a cabeça, os olhos e o cabelo são camadas separadas |
| Âncora da cabeça | ponto (x, y) do pescoço em cada quadro, num `anchors.json` junto das folhas |
| Pés | no mesmo ponto em todos os quadros (sem "deslizar") |
| Altura | corpo ~52 px; com a cabeça o personagem fica com ~80–84 px |

Animações e quadros por direção: parado 4, andar 8, ataque 6–8 (por tipo de arma), conjurar 6, dano 2–4, caído 4–6, sentar 1.

Nome do arquivo: `game/assets/characters/outfits/chr_<corpo>_<roupa>_<anim>.png`, com `<corpo>` = `male` ou `female`. Máscara opcional para pele recolorível: `chr_<corpo>_<roupa>_mask_<anim>.png`.

## 2. Roupa-base por nacionalidade (tela de criação)

O jogador escolhe a nacionalidade na criação. A escolha é validada no servidor e salva.

**Decisão do dono (28/09): a roupa por nacionalidade é o Viajante recolorido com as cores da região**, e não folhas geradas no ChatGPT. As cores ficam em `nationality_colors` (`game/data/customization/options.tres`), no formato [tecido, detalhe]. Terra do Sabiá mantém as cores originais. A troca aparece na prévia da tela de criação e no mundo. Um quadro abaixo da prévia mostra o nome da região, a frase do atlas e as duas cores. Detalhes técnicos: `game/tools/art/customization/README.md`, seção "Roupa por nacionalidade". O campo `nationality_outfits` continua disponível se um dia uma região ganhar folha própria.

| Nacionalidade (id) | Região | Roupa (id sugerido) |
|---|---|---|
| sabia | Terra do Sabiá (Brasil) — **MVP** | student_sabia |
| mouras | Reino das Mouras (Portugal) | student_mouras |
| sol | Ilhas do Sol Nascente (Japão) | student_sol |
| fiordes | Fiordes de Gelo (Noruega/Islândia) | student_fiordes |
| colunas | Costa das Colunas (Grécia antiga) | student_colunas |
| areias | Areias do Nilo (Egito antigo) | student_areias |
| brumas | Brumas Verdes (Irlanda/Escócia) | student_brumas |
| estepe | Estepe de Ferro (povos eslavos) | student_estepe |
| jade | Império de Jade (China) | student_jade |
| obsidiana | Selvas de Obsidiana (México antigo) | student_obsidiana |

Regras culturais (GDD §4.0): inspiração e não caricatura; nada de símbolo religioso vivo na roupa. As regiões são as do GDD; "África", "Europa", "Oriente Médio" e similares como bloco único não entram.

**Prioridade:** `student_sabia`, masculino e feminino, todas as animações.

**Arquivado** (o dono preferiu o recolor). Se um dia for preciso: o kit `docs/kit-chatgpt-student-sabia.md` traz as pranchas-guia `docs/guias/student_sabia/<corpo>_p1_parado|p2_andar|p3_combate|p4_dano.png`, o prompt, o passo a passo e onde salvar (`game/downloads/sprits/student_sabia/<corpo>_<parte>.png`). O importador é `game/tools/art/import_ai_sheet.py`. A instalação ainda depende da camada de cabeça por âncora: ver "Instalar no jogo" no kit.

## 3. Roupas por título

Uma roupa por título. A do título exibido substitui a de nacionalidade. **Regra do dono: cada roupa muda a forma, e não só
a cor.** As 16 roupas da Terra do Sabiá estão prontas nos dois corpos e em todas as animações do corpo-base, com máscara
(pele, olhos e cabelo continuam personalizáveis). O título liga a roupa por `outfit_id` em `data/titles/<id>.tres`.

- **Como foram feitas:** `game/tools/art/title_outfits/` (README). Cada pose-chave do corpo-base é editada pela IA (Bria),
  a cabeça do corpo-base é restaurada e a folha sai alinhada quadro a quadro. Descrições em `outfits.json`.
- **Arquivos:** `game/assets/characters/outfits/chr_<corpo>_<outfit_id>_<anim>.png` + `chr_<corpo>_<outfit_id>_mask_<anim>.png`.
- **Nenhum capuz na cabeça:** a cabeça é sempre a do corpo-base (o cabelo é camada). Capuzes ficam abaixados nos ombros.

| Título (id) | outfit_id | Caminho | Roupa |
|---|---|---|---|
| sabia_blade_machete (Facão Firme) | title_machete | Lâmina, base | túnica de lona cinza, cinto com facão, bandagem no braço |
| sabia_blade_aroeira (Tronco de Aroeira) | title_aroeira | Lâmina, ramo A | gibão acolchoado cor de casca, ombreiras de madeira, faixa musgo |
| sabia_blade_jaguar (Garra da Onça) | title_jaguar | Lâmina, ramo B | colete ocre com rosetas de onça, braçadeiras, faixa preta |
| sabia_arcane_firefly (Luz de Vaga-lume) | title_firefly | Arcano, base | capa curta índigo, túnica com barra verde, pingentes de vaga-lume |
| sabia_arcane_crystal (Guarda do Cristal) | title_crystal | Arcano, ramo A | sobretudo azul-gelo de gola alta, placas de cristal nos ombros |
| sabia_arcane_boitata (Olho do Boitatá) | title_boitata | Arcano, ramo B | manto azul-noite com chamas na barra, faixa com olho laranja |
| sabia_hybrid_ember (Brasa no Facão) | title_ember | híbrido | casaco carvão com costura em brasa, meia capa vermelha |
| sabia_bow_cerrado (Flecha do Cerrado) | title_cerrado | Arco, base | gibão curto de couro cru, aljava de taquara nas costas, faixa de palha, braçadeiras |
| sabia_bow_brejo (Tocaia do Brejo) | title_brejo | Arco, ramo A | capa de folhas e barro seco, capuz de palha abaixado, tons de lama e musgo |
| sabia_bow_gaviao (Gavião-Real) | title_gaviao | Arco, ramo B | casaco claro, ombreiras de penas cinza e brancas, luva de falcoeiro, faixa de penas |
| sabia_support_root (Raiz do Cerrado) | title_root | Suporte | avental de raizeira com bolsos de ervas, xale, cordões de sementes, garrafa na cintura |
| sabia_support_buriti (Seiva do Buriti) | title_buriti | Suporte, cura | túnica clara de palha de buriti trançada, faixa verde, folhas na barra |
| sabia_support_matinta (Assobio da Matinta) | title_matinta | Suporte, debuff | manto escuro longo com penas de coruja, capuz abaixado, franjas |
| sabia_tank_jabuti (Casco de Jabuti) | title_jabuti | Tanque | peitoral e costas em placas de casco, ombreiras redondas |
| sabia_tank_anta (Couro de Anta) | title_anta | Tanque, guerreiro pesado | couro grosso em camadas, cinturão largo, saiote de couro, grevas |
| sabia_tank_mapinguari (Fúria do Mapinguari) | title_mapinguari | Tanque, berserker | colete de pele desgrenhada sem camisa, garras de osso, marcas vermelhas |

### 3.1 Arco (item `simple_bow`, estilo de golpe `bow`)

- Camada da arma: `game/assets/equipment/weapon/bow/<corpo>_{idle,walk,sit,attack_bow}[_back].png`. Qualquer visual de
  arma terminado em `bow` usa essa pasta e o golpe `attack_bow` (`EntityVisual.weapon_attack_style`).
- `attack_bow` (6 quadros, 80 ms): guarda, braço do arco estendido com a corda puxada e a flecha, soltar, guarda. Existe
  em **todas** as camadas (corpo-base, Viajante, olhos, cabelos, brincos, chapéus e as 16 roupas), montada por
  `game/tools/art/title_outfits/bow.py` a partir dos quadros de `attack_unarmed`.
- **Pendência:** a mão de trás não puxa a corda (a corda vai até o queixo). Uma pose de puxar de verdade pede
  poses-chave novas no corpo-base e uma nova passada de IA nas 16 roupas.
- Ícone: `game/assets/items/icons/icon_item_simple_bow.png`.

## 4. Efeitos de skills e magias — **feito em 28/09/2026** (1ª versão, esperando o olhar do dono)

Folhas separadas do corpo, desenhadas pelo jogo por cima do mundo. Quadro 96 × 96 (192 × 192 para áreas no chão), fundo transparente, 6–10 quadros. Todas desenhadas **por script, quadro a quadro, sem imagem de entrada** (`game/tools/art/fx/gen_skill_fx.py`; origem em `game/assets/fx/skills/ORIGEM.md`). Paleta: lâmina em aço e âmbar; arcano em turquesa e dourado; fogo-fátuo verde-amarelado; gelo ciano e branco; fogo laranja e vermelho.

| Skill (id) | Como aparece no jogo | Folhas (`game/assets/fx/skills/`) |
|---|---|---|
| blade_firm_strike | arco de corte com rastro que afina e faíscas no alvo (lado sorteado), depois estouro em 8 pontas | `_slash`, `_impact` |
| blade_charge | nuvens de poeira ao longo da corrida, X de cortes com onda de choque no alvo e 3 estrelinhas girando na cabeça pelo tempo do atordoamento | `_dust`, `_impact`, `_stun` |
| blade_clearing_sweep | arco de 90° deitado no chão, do conjurador para o alvo: fio da lâmina na frente, riscos de velocidade e aro de corte com faíscas | `_arc` |
| blade_horizon_cut | meia-lua de corte deitada que corre os 12 m da linha deixando ecos para trás, poeira no caminho, estouro em quem é atingido | `_wave` |
| blade_steel_spin | três rastros de lâmina girando em volta do conjurador (raio 3), anel no fim | `_whirl` |
| blade_iron_stance | 5 placas de aço girando em volta do corpo (as de trás atrás do personagem), anel âmbar nos pés e fios de luz subindo; em laço pela duração; **30/09: quadro 128, placas de 34 px, mais afastadas** | `_back`, `_front`, `_glow` |
| arcane_spark | círculo de conjuração nos pés; faísca (núcleo branco, 4 raios, cauda turquesa, pontos dourados) voa até o alvo e explode num clarão de 4 raios inclinados; **30/09: quadro 128, forma 1,45×** | `_projectile`, `_impact` |
| arcane_will_o_wisp | fogo-fátuo com chama, dois "olhos" e cauda ondulante voa balançando até o alvo e estoura em línguas de fogo verde; **30/09: quadro 128, forma 1,4×** | `_projectile`, `_impact` |
| arcane_creeping_flame | círculo de conjuração; no ponto: chão em brasa (aro ondulado, rachaduras incandescentes, brasas) com 7 línguas de fogo em pé, em laço por 5 s | `_ground`, `_tongue` |
| arcane_frost_burst | cone de 60° deitado (raio 6) com frente de geada e estilhaços; cristais facetados brotam do chão e quebram; geada nos pés de quem ficou lento | `_cone`, `_crystal`, `_chill` |
| arcane_star_fall | círculo de conjuração; **aviso (30/09): a sombra da pedra-estrela cresce no chão, que racha e brilha turquesa por baixo, com pedrinhas pulando** (substitui a estrela dentro do círculo e o disco vermelho); a pedra-estrela com rastro cai do céu; impacto deitado (raio 4): cratera com rachaduras em brasa, frente de poeira quebrada e cacos dourados espalhados, sem estrela desenhada no chão; pilar de luz em pé | `_star`, `_warning`, `_impact`, `_burst` |
| arcane_barrier | bolha com grade de hexágonos, reflexo e 6 runas douradas girando no alvo, em laço por 8 s | `_shield` |
| (toda skill arcana com conjuração) | círculo de conjuração com a flor de ipê de 5 pétalas e runas | `arcane_cast_circle` |

**Nome da skill:** ao lançar (qualquer skill, física ou mágica), o nome traduzido aparece acima do conjurador na cor da escola, sobe e some em ~1,2 s — para todos da instância.

**Código:** `SkillFx` (`game/scripts/client/combat/skill_fx.gd`, criado pelo `NetCombat` junto do `CombatFx`) escuta `NetProgress.skill_cast`/`cast_cancelled` e `NetCombat.hit`; escolhe a receita pelo id da skill e usa o `SkillDef.vfx` (e o tipo de alvo) como reserva. Cada peça é um `SkillFxSprite` (shaders `assets/shaders/skill_fx_*.gdshader`): sem luz, filtro nearest, na resolução nativa; em pé (virada para a câmera, projéteis girando na direção do voo) ou deitada no chão com o raio da skill; laços somem com `duration_sec` ou quando o alvo morre. Peças de brilho = forma em blend normal + a mesma folha somada em aditivo (só aditivo virava mancha branca no chão claro do Campo). O `HotbarAim` deixou de desenhar o "flash" colorido da forma; só mostra o aviso da Queda Estelar. Só visual; o `CombatAudio` não mudou.

**Testes e capturas:** `tests/client/test_skill_fx.tscn` (em `make test`) lança as 12 skills e confere nome, efeito aparecendo e sumindo, orientação do cone/linha, raio das áreas, laço que some com a morte do alvo, geada no alvo lento e conjuração cancelada. Captura no cliente real (Campo de Treino, ponto de nascimento, 1280×720): `GODOT=... xvfb-run -a game/tests/client/run_skill_fx_capture.sh` → `.work/fx/board.png` e `.work/fx/<skill>.gif`.

**Trocar ou acrescentar uma animação por GIF (opcional):** `python3 game/tools/art/fx/import_fx_gif.py arquivo.gif <skill>_<peça> [--size 96|192] [--colors 24] [--anchor center|bottom] [--blend add|mix] [--plane billboard|flat] [--loop]`. O importador recorta pelo alfa (ou pela cor dos cantos / `--bg`), centraliza, reduz com nearest e paleta limitada e grava a folha `.png` + um `.json` com a duração de cada quadro. Quando o `.json` existe, o jogo usa essa folha no lugar da gerada e o `gen_skill_fx.py` não a sobrescreve. Prefira GIF com fundo transparente: fundo de cor deixa franja no halo. **Regra:** só GIFs próprios (feitos por nós) ou com licença CC0/CC-BY conferida e registrada em `game/assets/fx/skills/ORIGEM.md`; **nunca** GIFs de Ragnarok, Samsara ou de qualquer outro jogo.

### 4.1 Terra do Sabiá v0.4 — as 68 skills novas, estados e ícones — **feito em 30/09/2026** (esperando o olhar do dono)

Mesmo método (tudo por script, quadro a quadro, sem imagem de entrada), agora com **sprites desenhados à mão pixel a pixel** (texto → pixel, `game/tools/art/fx/fxsabia.py`) para as peças-chave: onça, gavião-real, rasga-mortalha, passarinho da Matinta, vaga-lume, anta, jabuti, casco, garrafada, cuia, coco de canudinho, pequi, bigorna e martelo, facão, pedra de amolar, olhos (cobra de fogo, gavião, onça), boca do Mapinguari, mão de garras, flecha de taquara, penas e folhas. Peças maiores que as do MVP: quadro 128 (em pé, pivô nos pés) e 192/256 no chão, desenhadas para ler na câmera atual. **Nada de símbolo religioso:** sem cruz, hexagrama ou pentagrama; as runas do círculo de conjuração e da Barreira viraram semente, broto e ziguezague (a antiga tinha forma de "+").

Geradores: `gen_skill_fx.py` (entrada; chama os módulos) + `fx_status.py` (estados e flecha), `fx_melee.py`, `fx_arcane2.py`, `fx_bow.py`, `fx_hybrid.py`, `fx_support.py`, `fx_tank.py`. `--only nome1,nome2` refaz só essas peças e mescla a tabela. Receitas (dados): `game/scripts/client/combat/skill_fx_book.gd` (`SkillFxBook.BOOK` = passos por skill; `LOOK` = visual do estado; `HIT` = impacto por golpe).

| Árvore | Como aparece (peça-chave de cada skill) |
|---|---|
| Facão Firme | **Amolar o Facão:** facão em pé no peito, a pedra de amolar corre o fio 3× soltando faíscas, brilho corre a lâmina; aura de ataque (divisas vermelhas subindo) |
| Tronco de Aroeira | **Resposta:** escudo de tábua de casca com cachos de aroeira-vermelha piscando nas bordas; **Raiz Presa:** raízes rasgam o chão do centro para fora com torrões + cipós nos pés dos presos; **Casca Grossa:** placas de casca nas laterais e nas costas (o rosto fica livre); **Chamado do Tronco:** tronco sobe atrás e bate 3× no chão com folhas e poeira + balão "!" sobre os monstros |
| Garra da Onça | **Bote:** onça-pintada dourada salta até o alvo + 3 rasgos de garra; **Unhada:** três unhadas seguidas (esquerda, direita, de cima) que ficam vermelhas; **Faro de Sangue:** olhos de onça acesos sobre a cabeça, fiapos vermelhos de cheiro; **Rugido:** cabeça da onça rugindo + frentes de som denteadas no leque + marca de ATQ reduzido |
| Luz de Vaga-lume | **Enxame:** quatro vaga-lumes (asas batendo, lanterna acesa) voam em fila até o alvo e estouram em flor de luz |
| Guarda do Cristal | **Cristal Repartido:** três cacos saem do conjurador e ficam girando em volta de quem recebe o escudo; **Prisão:** colunas de cristal brotam em volta do alvo (trás e frente); **Muralha:** blocos de pontas de cristal brotam em roda + aura de proteção nos aliados; **Brilho:** pedra de cristal flutuando e pingando gotas de mana + aura de mana |
| Olho do Boitatá | **Passo Estelar:** o corpo vira poeira de estrela na saída e junta na chegada; **Olhar de Fogo:** olho em fenda da cobra de fogo abre acima e solta o raio de fogo na linha; **Serpente de Fogo:** a cobra de fogo rasteja pela linha deixando escamas de brasa que queimam 5 s; **Olhos em Brasa:** dois olhos acesos com rastro para os lados e brasinhas subindo |
| Flecha do Cerrado | flecha de taquara (ponta de ferro, gomos, amarração vermelha, penas) em todas; **Rasante:** rente ao chão levantando capim e poeira; **Dupla:** duas flechas lado a lado, dois impactos; **Arco Tenso:** vento enrolando folhas na frente do peito enquanto conjura, flecha com espiral de vento, estouro de vento e lascas; **Aviso:** penas e fita vermelha comprida + ponta vermelha pulsando sobre o alvo; **Revoada:** flechas caem do céu e fincam no chão com poeira |
| Tocaia do Brejo | **Pele de Barro:** lama espirra do chão e escorre no corpo + aura de esquiva; **Lama no Corpo:** poça borbulha e fios de lama sobem se enrolando; o jogador fica **meio transparente e puxado para o barro** enquanto invisível; **Tocaia:** taboas brotam em volta e se abrem para a flecha; **Armadilha de Cipó:** laço de cipó com espinhos se fechando no chão; **Espinho:** flecha de cipó espinhenta pingando veneno roxo + marca de veneno |
| Gavião-Real | **Olho Parado:** olho do gavião abre sobre a cabeça com traços de mira fechando; **Sem Desvio:** flecha branca com linha de luz reta; a couraça do alvo estala em cacos; **Mira Certeira:** três penas douradas girando em volta; **Mergulho:** gavião-real de asas para cima cai sobre o alvo, garras, penas e poeira; **Voo Curto:** asas de rapina abrem nas costas pena a pena e batem |
| Brasa no Facão | **Lâmina Faiscante:** facão de aço com o fio em brasa e labaredas flutuando ao lado (e brasinhas no alvo a cada golpe básico); **Corte em Brasa:** corte laranja com borda branca, brasas caindo + fogo nos pés do alvo; **Faísca no Aço:** chuveiro de faíscas de esmeril no avanço + estouro com gotas de metal; **Fagulhas:** bigorna e martelo batem (TAN) + leque de fagulhas no chão; **Coração de Brasa:** carvão aceso pulsando no peito |
| Raiz do Cerrado | **Garrafada:** garrafa de ervas inclina e derrama + poça de ervas com folhas boiando por 10 s; **Chá de Erva:** cuia fumegando sobre o aliado; **Emplastro:** folhas largas enrolam o aliado e levam fiapos escuros embora; **Sombra de Pequizeiro:** copa com pequis sobre o aliado e sombra no chão; **Mutirão:** cordão de bandeirinhas de festa girando sobre o grupo |
| Seiva do Buriti | **Folha Larga:** folha desce balançando e pinga orvalho; **Água de Coco:** coco verde de canudinho vira e derrama + coroa de gotas no chão; **Seiva que Corre:** fios de seiva âmbar escorrendo; **Raiz que Segura:** raízes grossas com veios dourados abraçando as pernas; **Fôlego Novo:** folha de buriti abana e o sopro sobe em espiral |
| Assobio da Matinta | **Assobio:** fitas de vento roxo e penas pretas no leque + marca de DEF reduzida; **Agouro:** passarinho preto de olho vermelho voando em roda sobre a cabeça; **Pio da Rasga-Mortalha:** coruja branca mergulha e grita + riscos e penas brancas no chão + marca de lentidão (caramujo); **Visgo:** bolota de visgo voa e gruda nos pés com fios; **Fumaça Amarga:** rolos de fumaça verde-cinza rolando pela área + marca de cura reduzida (folha murcha) |
| Casco de Jabuti | **Batida:** casco de jabuti sobre a cabeça leva duas batidas (toc-toc) + "!" nos monstros; **Recolher:** cúpula de casco meio transparente cobre o corpo; **Casco Duro:** carapaça com placas e aréolas nas costas, costuras de bronze pulsando; **Paciência:** jabutizinho anda em volta dos pés entre brotos e florzinhas + aura de vida; **Empurrão:** frente de placas de casco empurrando no leque + estrelinhas |
| Couro de Anta | **Couro Grosso:** manto de couro costurado nas costas e abas nas laterais; **Pisada:** pegada enorme afunda o chão com borda de barro e rachaduras + estrelinhas; **Trombada:** anta de bronze investe junto + poeira + impacto; **Muralha Viva:** estacas de pau-a-pique amarradas com couro brotam em roda; **Aguentar Firme:** pedras brotam em volta dos pés com aros de bronze |
| Fúria do Mapinguari | **Fúria:** línguas de fumaça vermelha atrás do corpo e marcas de guerra piscando; **Urro:** a boca da barriga (dentes, baba) abre e urra + riscos vermelhos correndo pelo chão com marcas de garra; **Garras Pesadas:** a mão de garras passa duas vezes + quatro sulcos vermelhos no chão; **Sede de Luta:** gotas de sangue voltando ao corpo (também a cada golpe básico enquanto dura); **Última Pancada:** o punho de garras desce do alto e esmaga, cratera de poeira |

**Estados** (`NetProgress.status_changed(entity_id, status_id, skill_id, active, duration_sec)`; conecta com `has_signal`): o visual da skill (`LOOK`) quando existe; senão, pelo status: `stun` estrelinhas girando na cabeça, `root` cipós enrolando nos pés (atrás e na frente), `taunt` balão espinhudo vermelho com "!" sobre o monstro, `slow`/`dot`/`debuff` **marcas sobre a cabeça, lado a lado** (escudo rachado = DEF, facão quebrado = ATQ, caramujo de lama = lentidão, espinho pingando = veneno, folha murcha = cura reduzida, ponta de flecha vermelha = recebe mais dano, pena da Matinta = genérico), `buff` **aura por tipo** (a chave de mods em `SkillDef.extra`: divisas vermelhas = ATQ, escamas de bronze = DEF, pontinhos turquesa = ATQM, lascas douradas = crítico/alcance, fiapos de vento com folha = esquiva, plaquinhas de casca = menos dano, folhas = vida, gotas azuis = mana, gotas vermelhas girando para dentro = roubo de vida), `hot`/`mp_regen` auras de vida/mana, `shield` bolha, `stealth` **meio transparente (alfa 0,42, puxado para o barro)** para quem recebe o sinal (o próprio e o grupo). Relançar ou receber o sinal de novo estica o laço; `active = false` apaga.

**Depois da 1ª captura real (retomada de 30/09):** marcas sobre a cabeça em pixel de 1/24 m (maiores), vaga-lume do Enxame 3× com lanterna maior, anta da Trombada redesenhada com tromba, poeira mais macia (não parece pedra), Emplastro virou uma faixa de folhas que enrola a cintura e aperta, Fôlego Novo virou duas rajadas saindo do leque de buriti, escama da aura de defesa sem miolo em "+", ícone do Empurrão de Casco novo (placa empurrando).

**Forma atroz** (chefe à noite): nome em vermelho-escuro (cor do estágio 4 em `CombatVisuals.STAGE_COLORS`) e aura noturna vermelho-escura pulsando com brasas (`AtrozVisual`, não tinge o sprite), lendo `appearance["atroz"]`; o `CombatFx` refaz o visual quando a forma muda.

**Círculo mágico da praça do Porto** (`game/tools/art/gen_textures.py`, `magic_circle()`): o hexagrama saiu; agora é a flor de ipê de 5 pétalas com runas do Sabiá (semente, broto e ziguezague), a mesma linguagem do círculo de conjuração.

**Cura** (`NetCombat.healed(source_id, target_id, amount)`): número **verde "+N"** subindo (`CombatFx`) e folhinhas e sementes subindo em espiral no curado (`SkillFx`, no máximo uma a cada 0,8 s por alvo). **Arco:** o ataque básico com arco (estilo de golpe `bow`) solta a flecha de taquara do arqueiro até o alvo, com estalo de lascas.

**Ícones 32×32** (`game/tools/art/fx/gen_skill_icons.py` → `game/assets/skills/<id>.png`, 80 ao todo): placa com a borda da escola — lâmina âmbar, arcano turquesa, **arco verde-oliva, suporte verde-folha, tanque bronze, híbrido laranja-brasa** — e o desenho da peça-chave (sprite à mão em pixel nativo quando cabe, quadro escolhido da folha ou desenho próprio do ícone). Prancha: `.work/fx2/icons.png`.

**Testes e capturas:** `test_skill_fx` (em `make test`, acelerado 5×) lança as 12 do MVP + as 68 novas (as que ainda não têm `.tres` são montadas no teste com o tipo de alvo da §3.4 de TITULOS-E-SKILLS.md), confere ícone, nome, efeito aparecendo e sumindo, cone/linha virados, raio das áreas, os estados (atordoar, prender, provocar, duas marcas lado a lado, invisível e volta), a cura, a flecha do ataque com arco e o aviso novo da Queda Estelar. Captura no cliente real: `ONLY=prefixos GODOT=... xvfb-run -a game/tests/client/run_skill_fx_capture.sh .work/fx2` (usa o comando de debug `learn`, troca facão/arco conforme a skill, captura `bow_basic_attack`) → `.work/fx2/board.png`, `board_NN.png` e GIFs.

### 4.2 Portais dos mapas — **feito em 30/09/2026** (pedido do dono: "como no Ragnarok", arte nossa)

Redemoinho de luz **deitado no chão** (raio 1,3 m, ~2,6 células): seis braços finos em espiral azul-claro e branco girando devagar (laço de 12 quadros = 1/6 de volta), anéis finos correndo para o centro, borda em traços e pontinhos piscando (`portal_ground`), mais uma **coluna de luz bem transparente** com fagulhas subindo (`portal_column`, atrás de quem pisa). Gerador: `game/tools/art/fx/fx_portal.py` (mesmo pipeline das skills). Sem estrela, hexagrama, pentagrama ou cruz. Zumbido baixo: o `sfx_crystal_hum` do catálogo, mais grave e a −16 dB (nenhum áudio novo).

**Como entra no jogo, sem mexer nas cenas:** `PortalFx.decorate_map(map)` (`game/scripts/client/combat/portal_fx.gd`) acha todo Area3D com `interact_type = &"portal"`, esconde a malha antiga (o `Gate` TorusMesh dos mapas de caça) e põe o `PortalFx` no chão (raio para baixo na camada do chão; reserva: altura do `approach_position`). O `PortalDecorator` (criado pelo `SkillFx`, só no cliente) varre os mapas carregados a cada 0,5 s. Vale para cidade, Campo de Treino, Campos, Mata e Chapada, e para mapas regenerados. Servidor e interação não mudam.

**Validação:** `test_skill_fx` confere, nos 5 mapas, que todo portal ganha o `PortalFx` e o `Gate` fica escondido (e que decorar de novo não duplica). Captura no cliente real atravessando os portais: `GODOT=... game/tests/client/run_portal_capture.sh` → `.work/portal/{cidade,campos,mata,chapada}_{dia,noite}.png` e `board.png`.

## 5. Checklist de entrega

- [ ] `ORIGEM.md` preenchido; nenhuma folha de outro jogo usada.
- [ ] 96 × 96, linhas S, SE, L, NE, N, corpo sem cabeça.
- [ ] `anchors.json` com o pescoço em cada quadro.
- [ ] Pés parados no mesmo ponto; sem "fervura" entre quadros.
- [ ] Captura no cliente real, no ponto de nascimento, antes de dar como pronto.
