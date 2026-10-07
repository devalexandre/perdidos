# Trajes de título e cosméticos de corpo

Entrada: a descrição da roupa (`outfits.json`). Saída: folhas de corpo inteiro com máscara, alinhadas ao corpo-base:

```
assets/characters/outfits/chr_<body>_<outfit>_<anim>.png        (quadros 96x96, linhas S, SE, L, NE, N)
assets/characters/outfits/chr_<body>_<outfit>_mask_<anim>.png   (R = pele, G = olhos, B = raspado; alfa 128 = cabeça)
```

Com a máscara, `CharacterLayers.outfit_has_body` usa a folha como corpo recolorível. Pele, olhos, cabelo e brinco
continuam personalizáveis. O título liga o traje por `TitleDef.outfit_id` (`data/titles/<id>.tres`). O cosmético de
corpo usa o mesmo formato e tem prioridade (`Equipment.get_appearance`).

## Método

1. **Poses-chave** (`poses.py`). As folhas do corpo-base são montadas com poucas poses. Os quadros repetidos são
   a mesma pose deslocada (passo do andar, golpes segurados) ou com o tronco 1 px abaixo (respiração do idle). A
   pose de "passagem" do andar é o próprio idle deslocado. São 84 poses no masculino e 85 no feminino, em todas as
   animações e direções. Para cada quadro, `poses.py` guarda a pose de origem e a transformação.
2. **Edição por IA de cada pose** (`build.py edit`, Bria `v2/image/edit`). A pose é ampliada 6x sobre fundo branco.
   O pedido traz a descrição da roupa e manda manter a cabeça, a pose, a direção e o estilo pixel art.
   - Cada pose é editada sozinha, porque em tiras ou grades a IA refaz as poses e até muda o número de figuras.
   - No corpo feminino, o pedido lembra a cintura fina e o quadril (`FIGURE`), porque a IA endireitava o corpo.
   - Com `--seed N --only-bad`, a ferramenta tenta outra semente nas poses com silhueta ruim. Vence a melhor.
3. **Registro** (`register.py`). A ferramenta recorta o fundo, inclusive a sombra no chão e o branco entre as pernas.
   Depois acha a escala e o deslocamento que melhor põem a figura da IA sobre a pose do corpo-base, pelo IoU da
   silhueta abaixo da cabeça. Por fim, reduz com BOX pré-multiplicado para o quadro 96x96.
4. **Montagem** (`build.py assemble`):
   - **Escolha da semente**, por pose. Na 1ª passada vence a melhor silhueta (IoU). Na 2ª, o placar é
     `IoU − 0,3 × diferença de cores` em relação às outras poses da mesma direção, menos uma penalidade quando a IA
     desenhou uma cabeça maior (queixo da IA abaixo do queixo do corpo-base). Isso deixa o traje mais igual entre as
     poses e evita cabeça dupla.
   - **Cabeça grande da IA**. Quando o queixo da IA fica 3 a 16 linhas abaixo do queixo do corpo-base, a cabeça da IA
     sai. O corpo da IA é então esticado na vertical, do queixo do corpo-base até os pés (`register.stretch_body`).
   - **Cabeça do corpo-base** (`head.py`): o pedaço conectado de rosto, olhos e cabelo raspado da máscara, até o
     pescoço, mais o contorno encostado nele. Gola, camiseta e alças do Viajante que caem na zona da cabeça **não**
     entram: o traje as substitui.
   - A cabeça da IA sai (só em volta da cabeça do corpo-base, para os braços erguidos ficarem). Também saem a sombra
     que a IA pintou no chão e os pedaços soltos.
   - **Pose que encaixa mal** (IoU < 0,66): o corpo é colado na silhueta do corpo-base. O que passa dela sai. Braço ou
     perna que a IA deixou vazio recebe o pixel de roupa mais próximo, para ficar onde a animação e a arma esperam.
   - Nas folhas com arma (idle, walk, sit e golpes), a mão do corpo-base volta sob o cabo da arma, porque a camada da
     arma foi desenhada para essa mão. Só o facão e o cajado contam (`GRIP_KINDS`); o arco inteiro é de madeira e
     cruza o corpo.
   - **Paleta** de 34 cores por traje e corpo, tirada de todas as poses. Dessas, 10 ficam reservadas para o contorno,
     a boca e as orelhas da cabeça, para o rosto nunca pegar cor da roupa. Os pixels recoloridos pela máscara recebem a
     cor padrão da rampa. Assim a folha fica com 48 cores ou menos (`validate_art.py`).
   - **Desenho espelhado:** a IA às vezes vira a pose de perfil para o outro lado (soco para a esquerda na linha L). A
     ferramenta registra também o desenho espelhado e fica com ele quando o IoU sobe 0,03 ou mais (`MIRROR_GAIN`).
   - Pele recolorível só até 6 px da pele do corpo-base (`SKIN_NEAR`): couro cru, palha e cáqui não viram "pele".
     A roupa com pele à mostra em outro lugar (peito nu) usa `"skin": "free"` em `outfits.json`.
   - Pele: pixels próximos dos tons de pele do corpo-base, em manchas de 4 px ou mais, viram pele recolorível (R).
   - Cada quadro = camada da pose-chave com a transformação do quadro, mais a cabeça **do quadro real**. A roupa não
     muda entre quadros da mesma pose, sem "fervura".
   - O `.import` segue o do corpo-base: sem perdas, sem VRAM e sem `fix_alpha_border`.
5. **Conferência** (`preview.py`). Gera pranchas de todas as animações, GIFs (andar, idle, golpe de lâmina e magia) e
   a métrica. A métrica é a distância L1 entre os histogramas de cor do corpo em quadros vizinhos (média e máximo).
   Mede-se também o corpo-base como referência: na mesma pose dá cerca de 0,01; entre poses, cerca de 0,2 no
   corpo-base e 0,2 a 0,3 nos trajes.
6. **Cliente real** (`capture_titles.sh`). Sobe um servidor com saves prontos, com o título conquistado e exibido.
   Captura o jogo no ponto de nascimento com um personagem de cada título nos dois corpos. `shots_board.py` monta a
   prancha das capturas.
7. **Site** (`render_site_titles.tscn`). Gera `site/img/titles/<título>_m.png` e `_f.png` em 48x92: a prévia do jogo
   (`LayeredCharacterPreview`, escala 1, idle S, com sombra).

8. **Arco** (`bow.py`). Monta `attack_bow` em todas as camadas que têm `attack_unarmed` e `cast` (corpo-base e máscara,
   Viajante, olhos, cabelos, brincos, chapéus e todas as roupas), copiando quadros de `attack_unarmed`: guarda, braço
   estendido (x4) e guarda. Como os quadros são cópias, tudo continua alinhado. Monta também a camada da arma
   `assets/equipment/weapon/bow/` (idle, walk, sit, attack_bow, com `_back`). O arco vem de uma imagem da IA
   (`bow_source.png`, Bria texto-imagem): a corda fina sai, o arco é espelhado e girado na resolução cheia, reduzido e
   posto na paleta mestra com contorno. A corda e a flecha são linhas de 1 px desenhadas por quadro. A mão vem do cabo
   do facão (idle, walk e sit) ou do punho estendido (golpe). A corda vai até o queixo: a mão de trás não puxa (não há
   pose nova). **Rode `bow.py sheets` depois de todo `assemble`**, para a roupa nova ganhar o golpe de arco.

## Uso

Python: use um interpretador com numpy, scipy e Pillow (nesta máquina, `~/.pyenv/versions/3.13.11/bin/python3`; o
`python3` padrão do pyenv 3.11 não tem numpy). Lotes longos: `setsid nohup`, porque as tarefas em segundo plano do
agente morrem em 30 min.


```bash
cd game/tools/art/title_outfits
python3 build.py edit title_machete            # IA (chave: $BK ou BRIA_API_KEy no ~/.zshrc; nunca impressa)
python3 build.py edit title_machete --seed 777 --only-bad
python3 build.py assemble title_machete        # folhas + máscaras + .import; imprime o IoU por corpo
python3 preview.py title_machete               # .work/title_outfits/preview/
python3 preview.py board --out <dir>           # prancha de todos os trajes x 2 corpos x 5 direções + GIF do andar
python3 bow.py all                             # attack_bow de todas as camadas + camada do arco (depois do assemble)
../../../../.tools/godot-4.7.2 --headless --path ../../.. --import   # SEMPRE depois de assemble
# a partir da raiz do repositório:
game/tools/art/title_outfits/capture_titles.sh <saida> [titulo ...]
python3 game/tools/art/title_outfits/shots_board.py <saida> <saida>/game_board.png
xvfb-run -a .tools/godot-4.7.2 --path game res://tools/art/title_outfits/render_site_titles.tscn -- --out=$PWD/site/img/titles
```

Trabalho: `.work/title_outfits/` (fontes ampliadas, edições da IA, registros em cache, pranchas).
Tudo é reexecutável: as etapas pulam o que já existe.

## Novo traje ou cosmético

1. Acrescente `{"<id>": {"prompt": "...", "title": "<título ou vazio>"}}` em `outfits.json`.
   - Descreva só a roupa, em inglês, com cores e peças.
   - Termine com "No backpack." se a mochila do Viajante não fizer parte da roupa.
   - Não use símbolos religiosos (GDD §4.0, regra 3).
2. Rode `edit`, depois `edit --seed 777 --only-bad` e `IOU_REDO=0.66 edit --seed 31337 --only-bad`. Em seguida,
   `assemble`, `preview` e `--import`, e confira as pranchas e os GIFs.
3. Ligue o traje:
   - para título, preencha `outfit_id` no `.tres` só quando os dois corpos estiverem completos;
   - atualize as imagens do site;
   - capture o cliente real.

## Limites conhecidos

- A IA redesenha um pouco o corpo em cada pose. Mãos e pés ficam a 1 ou 2 px da pose original. Nos golpes com arma,
  a camada da arma (desenhada para o corpo-base) pode ficar um pouco fora da mão.
- Os detalhes pequenos (fivela, bandagem, pingentes) podem trocar de lado entre poses diferentes. A cor não muda,
  porque a paleta é única.
- A sombra do chão não vem da folha: o jogo usa `chr_shadow.png`.
- Nas poses coladas à silhueta (golpes e morte com IoU baixo), o preenchimento pelo pixel mais próximo deixa riscos.
- O corpo feminino sai com menos curvas que o do Viajante: a IA desenha a roupa sobre a cabeça raspada (o pedido
  agora lembra a cintura e o quadril, o que ajuda um pouco).
- Capuz na cabeça não existe: a cabeça é sempre a do corpo-base. Capuzes ficam abaixados nos ombros.
- A aljava e as capas que saem mais de 5 px da silhueta do corpo-base são cortadas (`SNAP_FAR`).
