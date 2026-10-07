# Monstros feitos no Blender — pipeline de sprites (GDD §10.2.1, §10.6, §17.0.C, §17.2, §17.3)

Decisão do dono (28/09/2026): monstros (e depois personagens) passam a ser **modelados e animados no Blender** e
renderizados como **pixel art**, para acabar com o efeito "cartão de papel": animação viva (quique, squash &
stretch, reação ao golpe), igual em todas as direções. Complemento (mesmo dia): **"o que der para pegar pronto,
pega e modifica"** — antes de modelar do zero, procurar base em packs CC0 (seção 7).

Primeiras espécies prontas (3 estágios cada, todas as animações, 5 direções):

| Espécie | Estágio 1 (quadro) | Estágio 2 | Estágio 3 — chefe |
|---|---|---|---|
| `stone_armadillo` | Tatu-Pedra (96) | Tatu-Rochedo (144): mais placas, musgo, pedras, cristais de âmbar, chifrinho | Tatu-Montanha (240): picos de pedra com musgo, rachaduras brilhando, olhos acesos |
| `prank_whirlwind` | Redemoinho Arteiro (96) | Rodamoinho Traquinas (144): gravetos, pedrinhas, gorro com borla | Ventania do Gorro Vermelho (240): tornado dourado, olhos acesos, cachimbo com fumaça |
| `enchanted_firefly` | Vaga-lume Encantado (96) | Vaga-lume Candeeiro (144): abdômen-lanterna, antenas acesas, luzinhas | Rainha-Lume do Brejo (240): coroa, asas grandes douradas, fogos-fátuos |

Prévias: `.work/b3/preview/<id>_s<n>_board.png` (todas as animações), `_sample.png` (poses-chave ampliadas) e
`_<anim>.gif` (as 5 direções lado a lado). Captura no cliente real: `.work/b3/shots/`.

---

## 1. Como rodar

```bash
# tudo (3 espécies x 3 estágios), 3 processos em paralelo; instala as folhas em game/assets/monsters/<id>/
game/tools/art/blender/monsters/build_all.sh
# só uma espécie, sem instalar (só prévias), com a câmera mais inclinada
NO_INSTALL=1 PITCH=60 game/tools/art/blender/monsters/build_all.sh stone_armadillo
# passo a passo (um estágio)
.tools/blender/blender -b --python game/tools/art/blender/monsters/render_monster.py -- stone_armadillo 1 --pitch 55
.tools/pyvenv/bin/python game/tools/art/blender/monsters/post.py stone_armadillo 1          # --no-install
```

Um estágio leva de 15 s (quadro 96) a 60 s (quadro 240). Depois: abrir o Godot uma vez (`--import`) para
reimportar as folhas e rodar `game/tools/art/validate_art.py`.

Arquivos (tudo em `game/tools/art/blender/monsters/`, pasta com `.gdignore`):

| Arquivo | Papel |
|---|---|
| `mon_rig.py` | lado Blender: cena Cycles de passes, primitivas (elipsoide, placa abaulada, cone curvo, superfície paramétrica), `Rig` (peças + pivôs), câmera ortográfica, render + redução, `squash`/`tilt`/`keys` |
| `<especie>.py` | `build(estagio)` (modelo, variações por estágio) e `pose(rig, anim, i, n, estagio)` (pose de cada quadro) |
| `render_monster.py` | entrada do Blender: tamanhos (FRAME), animações, grava `.work/b3/npz/<id>_s<n>.npz/.json` e o `.blend` em `blend/` |
| `post.py` | cel shading com rampas da paleta, contornos, recorte, folhas no formato do jogo, prévias |
| `pack_model.py` | adaptador de modelos prontos (glTF/FBX/OBJ de packs CC0) — seção 7 |
| `pack_selftest.py` | exemplo/teste do adaptador com um modelo animado gerado (`.work/b3/packs/_selftest/`) |
| `build_all.sh` | roda tudo |
| `blend/<id>_s<n>.blend` | o modelo de cada estágio em pose de descanso (para abrir e mexer à mão) |

## 2. Por que não sai com "cara de 3D"

O Blender **não decide a cor final**. Cada peça do modelo (placa do casco, olho, orelha, folha...) tem um id, e
um único material de passes emite, numa renderização Cycles de 1 amostra:
`R = id da peça + profundidade`, `G, B = normal na câmera`. Com isso o `post.py` desenha como um pixel artista:

1. **Redução por voto**: renderiza 2–4× maior e cada pixel final fica com a peça que mais ocupa o bloco
   (peças pequenas importantes — brilho do olho, pupila, sobrancelha — têm peso maior, `prio`). Sem média de
   cores = sem borrão e sem antialiasing.
2. **Cel shading com rampas da paleta mestra**: tom = faixa de N·L (luz de cima-esquerda, `LIGHT` em
   `post.py`), 4 tons por material (`MATS`), limiares `THRESH`. Peças `unlit` (olhos, brilhos, boca, clarões)
   usam cor chapada.
3. **Contorno interno seletivo**: o pixel de uma peça que está **atrás** de outra vira linha — tom escuro da
   própria rampa (mesmo material: junta entre placas) ou o contorno do material (materiais diferentes).
   Peças `noline` não geram linha (olhos, brilhos, bochechas); peças do mesmo `group` também não.
4. **Contorno externo de 1 px colorido** (o tom escuro do material vizinho; nunca preto puro). Material de luz
   (`lamp*`) tem contorno claro = halo de brilho.
5. Todas as cores vêm da `paleta-mestra.gpl` (o validador confere).

## 3. Câmera, tamanho e pés

- Ortográfica, inclinada **55° para baixo** (`--pitch`, padrão 55; o jogo pode ir a 55–60°, GDD §17.0.C).
  Mudou a câmera do jogo? Re-renderizar com o novo `PITCH`.
- Densidade do jogo: **48 px = 1 m**. O modelo é feito em metros; `SCALE[estagio]` na espécie define o tamanho.
- Quadros: 96 (estágio 1), 144 (estágio 2), 240 (chefe). O §17.2 pedia 64 para pequenos, mas em 64 px o
  monstro ficava com ~45% da altura do Viajante (o §10.2.1, fechado, pede ~70% e "nunca minúsculo");
  por isso o estágio 1 usa 96. `visual_scale` continua 1,0 (mesma densidade de pixel do Viajante).
- **Pés no centro de baixo**: a origem do modelo (chão) cai na coluna central. O recorte vertical é fixo por
  estágio: o ponto mais baixo de todos os quadros fica na última linha − 1 (nada é cortado; parado pode sobrar
  1–3 px). O `post.py` imprime a extensão por animação e avisa se algo sair do quadro.
- **"lean"**: criaturas verticais/voadoras (redemoinho, vaga-lume) são inclinadas 16–22° para longe da câmera
  (`rig.set_lean`) para o rosto ler melhor de cima. Cabeças são levantadas (`HEAD_TILT`) pelo mesmo motivo.
- Squash & stretch **ancorado como no 2D** (`mon_rig.squash`): ao achatar, a borda de baixo na tela não desce
  (o pivô horizontal é o ponto do chão mais perto da câmera). Não mova a criatura para frente/trás dentro do
  quadro: o avanço do golpe e o empurrão do golpe recebido são do motor (`play_lunge`/`play_knockback`).

## 4. Formato entregue (o jogo lê sem mudança de motor)

`assets/monsters/<id>/mon_<id>_s<n>_<anim>.png`, linhas **S, SE, E, NE, N** (O/SO/NO = espelho), colunas =
quadros, fundo transparente, alfa binário. O `DirectionalSprite3D` tira o quadro de `altura/5` e o número de
quadros de `largura/quadro`.

| Animação | Quadros | Duração no jogo | Conteúdo |
|---|---|---|---|
| idle | 8 | ciclo de 0,8 s | respiração/quique, piscar, orelhas/antenas, folhas em órbita, abdômen pulsando |
| walk | 8 | ciclo do andar (2 células) | trote/pulinhos/voo com quique duplo, squash no apoio |
| attack | 8 | 100 ms/quadro | preparação → golpe → volta (tatu vira bola e rola; redemoinho gira e solta folhas; vaga-lume dispara clarão) |
| hit | 4 | ciclo de 0,24 s | achata + olhos apertados, estica, assenta |
| death | 8 | 150 ms/quadro, segura o último | tatu vira de barriga para cima; redemoinho desmancha e sobra o gorro; vaga-lume cai e apaga |

Mudanças mínimas no cliente para isso funcionar bem (feitas por este agente):
- `DirectionalSprite3D.ANIM_REF_FRAMES`: folhas com mais quadros que o padrão (idle 4, hit 2) mantêm a duração
  do ciclo (idle 8 quadros → 100 ms cada). Viajante/NPCs/monstros antigos não mudam.
- `MonsterStage.baked_life = true` nos três `.tres` → perfil de vida `Life.BAKED`: o motor não soma a
  respiração/quique/flutuação procedural por cima da animação que já vem no desenho (fica só o tranco curto e o
  flash branco do golpe e o sumiço da morte).
- `validate_art.py` aceita idle 8 / walk 8 / attack 8 / hit 4 / death 8 e sheets só com cores da paleta mestra.

## 5. Fazer uma espécie nova (ou um personagem)

1. Copie `stone_armadillo.py` (bicho de 4 patas), `prank_whirlwind.py` (criatura de "partículas") ou
   `enchanted_firefly.py` (voador) — ou, de preferência, parta de um pack (seção 7).
2. `build(stage)`: `R.reset()`, `rig = R.Rig(id)`, `rig.turn.scale = SCALE[stage]`, pivôs com `rig.empty(nome,
   posição, pai)` e peças com `rig.add_mesh(malha, "nome_peca", "material", pivo, noline=..., unlit=..., prio=...,
   group=...)`. Variações de estágio = o mesmo modelo + peças extras/escala/cores. Termine com `rig.save_rest()`.
3. `pose(rig, anim, i, n, stage)`: a cada quadro o rig volta ao descanso; mexa nos pivôs (rotação, posição,
   `R.squash`, `R.tilt`, `R.keys` para curvas). Loops (idle/walk) devem fechar: use `t = i / n`.
4. Materiais novos: acrescente em `MATS` do `post.py` (4 nomes da `paleta-mestra.gpl` + `line` + `out`).
5. `FRAME = {1: 96, 2: 144, 3: 240}`; rode `NO_INSTALL=1 build_all.sh <id>`, olhe `_sample.png` e os GIFs,
   ajuste `SCALE` até não haver aviso de corte e o tamanho bater com o §10.2.1; depois instale e rode o validador.
6. Marque `baked_life = true` nos estágios do `.tres` e registre a origem em `assets/monsters/LICENSES.md`.

**Personagens**: o mesmo caminho serve (rig humanoide de pack + ações Idle/Walk/Attack; recortar por camadas
exige renderizar cada camada — corpo, cabelo, roupa, arma — com as outras peças marcadas como "máscara": ainda
não implementado; o `post.py` já trata qualquer número de peças).

## 6. Checklist de revisão (olhar, não só medir)

- Lê como **criatura fofa de pixel art** (contorno, 3–4 tons, olhos grandes com brilho), não como render 3D liso.
- As 5 direções são a mesma criatura (o modelo é um só — consistente por construção).
- Loops sem salto; golpe com preparação clara; morte termina num quadro que "fica bem" parado.
- Tamanho relativo ao Viajante (§10.2.1): pequeno ~60–70% da altura, médio ~igual, grande ~1,5×, chefe ~2,5×.
- Captura no cliente real (GDD, memória do projeto): `scenes/lookdev/monster_shot.tscn` (abaixo).

```bash
G=.tools/godot-4.7.2
$G --headless --path game -- --server --port=8912 --progression-autotest --always-hit &
xvfb-run -a -s "-screen 0 1920x1080x24" $G --path game --resolution 1920x1080 \
    res://scenes/lookdev/monster_shot.tscn -- --name=B3Shot --port=8912 --shot-out=.work/b3/shots --burst=20
```

## 7. Partindo de packs prontos (CC0) — como foram feitas as 18 especies das nacoes

Packs (CC0, registro em `game/assets/monsters/LICENSES.md`): Quaternius *Ultimate Animated Animals*, *Cute Animated
Monsters* e *Ultimate Monsters*, extraidos em `.work/b3/packs/`. Ver os modelos: `.work/b3/packs/_probe/sheet0.png` e
`sheet1.png`.

Ferramentas:
- `pack_probe.py -- <modelo.gltf> [yaw] [acao]`: renderiza as cores do pack (S/E/N) e lista as cores do atlas e os
  materiais -> base do `COLORMAP`/`MATMAP`.
- `pack_model.py`: importa (glTF: animacao ja "assada", sem IK; o `.blend` tem IK e nao aceita encurtar ossos),
  remove o cubo auxiliar, liga sombreamento liso, repinta (material liso -> `MATMAP`; atlas com textura -> 2a
  renderizacao "albedo" e cor mais proxima do `COLORMAP`), `fit()` (altura/pes no chao), `bone_scale` (eixo do
  comprimento escolhido pela direcao do osso), `bone_rot` (rotacao fixa somada), `attach` (peca nossa presa a osso),
  `play` (amostra a acao e congela a pose antes do render), `delete_group_verts` (tira a cabeca original).
- `pack_species.py`: `PackSpecies` (declarativo: base, alturas, cores, ossos, acoes, extras, movimento hop/fly) e
  `animal_cub` (esqueleto/patas/rabo/animacoes do animal + **corpo gordinho e cabeca de filhote nossos** —
  `fluff_body`, `chibi_head` com olhos grandes, focinho/bico, orelhas pontudas/redondas/compridas, bochechas).
- `species_view.py` (Workbench, cor por peca) e `render_monster.py --zoom 3` + `post.py --zoom` para revisar a forma
  ampliada antes de gerar as folhas.

Licao aprendida: os bichos do pack sao realistas (compridos, pernas finas); encolher coluna/pernas por osso deforma a
animacao. O que funcionou foi manter patas, rabo e animacao do pack e **cobrir** o corpo/cabeca com as nossas formas
de filhote (mesmo padrao do Tatu-Pedra). Criaturas que ja sao "fofas" no pack (dragoes, yeti, monkroose, caranguejo)
so ganham repintura e acessorios. Tres especies sem base nos packs (guarda-chuva, cabana, serpente-mola) sao modelos
proprios por script.

Como recomecar uma especie de pack: `NO_INSTALL=1 build_all.sh <id>`, olhar `_sample.png`/GIFs, ajustar, instalar
(`build_all.sh <id>`), `apply_data.py <id>` (estagio n -> `_s<n>`, `visual_scale` 1,0, `baked_life`).

## 8. Forma atroz (estágio 4) — o chefe à noite

Regra do dono (30/09/2026): "Os monstros atrozes são a versão do chefe, mas à noite: mais fortes e mais agressivos.
Ambos devem ter desenhos únicos e detalhados." A forma atroz **não é recolor** do estágio 3: é o mesmo modelo do
chefe com peças trocadas/acrescentadas (silhueta nova) e rampas noturnas.

Como renderizar (só o estágio 4 — não re-renderizar nem reinstalar 1–3):

```bash
.tools/blender/blender -b --python game/tools/art/blender/monsters/render_monster.py -- stone_armadillo 4 --pitch 55
.tools/pyvenv/bin/python game/tools/art/blender/monsters/post.py stone_armadillo 4 --no-install   # prévias + folhas em .work/b3/sheets/<id>/
.tools/pyvenv/bin/python game/tools/art/blender/monsters/post.py stone_armadillo 4                # instala mon_<id>_s4_*.png
```

- No módulo: `SCALE/FRAME/BANDS` têm a chave 4 (quadro 240, igual ao chefe), `STAGES = (1, 2, 3, 4)`, `build(4)` =
  modelo do s3 + peças `_atroz_*`, e `pose(..., stage=4)` = poses do s3 + `_atroz_pose` (movimento das peças novas).
  Toda mudança fica atrás de `if stage == 4` (as folhas s1–s3 continuam idênticas byte a byte).
- Troca de material: dicionário `NIGHT` no módulo (material do s3 → material noturno), aplicado no fim do `build(4)`.
- `post.py`: materiais noturnos em `MATS` (bloco "forma atroz") e **aro de luar**: no estágio 4 cada quadro ganha um
  aro de 1 px `Roxo 2` por fora do contorno escuro (`RIM`; `--rim none` desliga). Peças de luz (brasa, fogo-fátuo,
  raio) ficam sem aro. É o que mantém a silhueta legível no mapa escuro.

Linguagem visual (checklist):
- **Silhueta mais agressiva**: espinhos/picos/chifres/pontas saindo do contorno do s3; o bicho continua o mesmo
  (rosto, orelhas, proporção chibi) — tem que ler como "o chefe, à noite, bravo".
- **Paleta noturna** (só `paleta-mestra.gpl`): corpo em anil/roxo (`Base 1`, `Roxo 1–3`, `Azul ceu 1–2`), sombras
  puxando para o roxo; acentos de luz chapada: brasa (`Vermelho 3`, `Ouro/amarelo 3–4`) e luz fria (`Verde agua 3–4`,
  `Roxo 4`). Contorno escuro + aro de luar.
- **Olhos acesos** e sobrancelha brava; bochecha rosada sai; presas/mandíbulas/dentes entram.
- **Partículas próprias** em loop: brasas subindo, fogos-fátuos com rastro, raios piscando, detritos em órbita.
- Revisar sobre fundo escuro (`.work/monsters_night/art_check/`: `review.py <id> 3,4 ... work` e `zoom.py`).

| Espécie | Forma atroz | O que muda em relação ao chefe (s3) |
|---|---|---|
| `stone_armadillo` | Tatu-Montanha Atroz | placas de obsidiana roxa; crista de picos altos de basalto com colar de brasa (no lugar dos picos com musgo); magma em todas as juntas; pele cinza-lilás; olhos de brasa que tremulam; chifre pesado no focinho + par de chifres de marfim; presas; garras longas; ferrão no rabo; líquen ciano; brasas subindo; picos eriçam na preparação, a bola do ataque tem espinhos e magma e solta brasas no impacto; na morte as rachaduras apagam |
| `enchanted_firefly` | Rainha-Lume Atroz | quitina anil; asas roxas rasgadas com veias de luz fria; lanterna-gaiola ciano com miolo de brasa aparecendo entre os anéis; ferrão de brasa; coroa de espinhos em ouro velho com joia roxa; mandíbulas em pinça (abrem no ataque); olhos fendidos acesos; antenas em gancho com ponta de luz; 4 fogos-fátuos (roxo/ciano) com chama e rastro |
| `prank_whirlwind` | Ventania Atroz | tempestade anil/roxa com segundo funil (mais largo, girando ao contrário); nuvem carregada com calombos; olhos de brasa com pupila escura; sorriso de dentes; capuz carmim-negro rasgado com pontas de chifre (no lugar do gorro com borla); cachimbo com brasa; raios piscando em volta e um raio grande que cai na frente no golpe; espinhos, galhos, pedras de basalto e brasas em órbita |

Pendentes: as outras 18 espécies ainda não têm estágio 3 (chefe), então também não têm forma atroz.

Ícones dos drops noturnos (32×32, `game/tools/art/icons/draw_icons.py`, desenhados por código só com a paleta):
`icon_item_eternal_ember.png` (Brasa Eterna), `icon_item_pequi_root.png` (Raiz de Pequi),
`icon_item_ancient_shell_shard.png` (Caco de Casco Antigo).

## 9. Fauna peçonhenta redesenhada (07/10/2026)

As três espécies que eram recolor no `tools/world/build_venom_monsters.py` (aranhas = iguana de obsidiana; taturana =
tatu-pedra) agora saem deste pipeline. Modelos próprios por script (os packs CC0 extraídos não têm aranha nem lagarta);
olhos/sobrancelha/bochecha seguem o `stone_armadillo.py`. Quadros: s1 = 96, s2 = 144 e **chefe (s3) e atroz (s4) = 240
com `visual_scale` 1,0**, como os chefes aprovados. Regra do dono: chefe e atroz têm arte ÚNICA (silhueta própria),
nunca o s1/s2 maior ou recolorido.

| Espécie | s1/s2 | Chefe (s3) | Atroz (s4) |
|---|---|---|---|
| `wandering_spider` Aranha-Armadeira | cinza-amarronzada, faixas em V, patas listradas, quelíceras ruivas; ergue as patas da frente | Matriarca: sempre empinada com 2 pares erguidos e canelas-foice de marfim, manto de teia até o chão, 6 filhotes no dorso, coroa alta de cerdas ruivas/douradas; golpe = crava as foices | mutação: baixa e larga, 10 patas eriçadas de cerdas roxas com espinho no joelho, abdômen erguido como lanterna de luz fria, crista de espinhos, presas-sabre com peçonha |
| `brown_recluse` Aranha-Marrom | canela, violino escuro no dorso, patas finas; bote rente ao chão; s2 com teia | Rainha do Violino: violino de verdade erguido nas costas (madeira, cordas, voluta, efes roxos), arco na pata, pústulas de necrose acesas, teia grande; golpe = toca (ondas de som) e dá o bote | Fantasma: flutua dentro de um lençol de teia lilás com barra rasgada e fiapos de luz fria; só cabeça e patas finas saem; olhos/efes ciano; mergulho |
| `lonomia_caterpillar` Taturana | cabeçona chibi + anéis com "pinheirinhos" verdes; anda em onda | Mãe-Lagarta: gigante empinada como naja, coroa de 3 pinheirinhos, floresta de pinheirinhos em brasa, casulo em pé na cauda; golpe = desaba a frente | Mariposa do Casulo: a mariposa saindo do casulo rachado, antenas plumosas, 2 pares de asas (ocelos de brasa, veias de luz fria), 2 anéis de fogo frio; golpe = bate as asas |

Peças e poses comuns em `venom_common.py` (aranha, `add_leg`, `boss_spider_pose` com empinar/bote/arco/mergulho/
flutuar, `web_cape`, `spiderling`, partículas `add_motes`); materiais em `<id>_mats.json`.
Refazer: `game/tools/art/blender/monsters/build_all.sh wandering_spider brown_recluse lonomia_caterpillar`, depois
`--import`. O gerador `build_venom_monsters.py` marca essas espécies como `BLENDER` (não recolore; s3/s4 com
`visual_scale` 1,0). Recolores derivados da armadeira (`spider_goliath`, `shadow_weaver`) mantêm o tamanho de antes na
tela (`stage_visual_scale` nos geradores), mas continuam recolor (ver levantamento).
Captura de chefes ao lado de um chefe aprovado: `game/tests/client/boss_look_capture.gd` (`spawn_boss`).
