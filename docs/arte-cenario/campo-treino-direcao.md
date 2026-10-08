# Campo de Treino — direção de arte e reprodução

Revisão 6, 28/09/2026. Referência aprovada: tela de entrada de Perdidos.

## Intenção

Um acampamento de viajantes numa manhã clara, cercado por caminhos que levam a pequenos lugares de lendas. O mistério vem do portal, da distância e das descobertas; não de escurecer a imagem. A referência de Ragnarok está na leitura imediata dos caminhos e dos personagens sobre um cenário tridimensional pintado. A delicadeza de ilustração de fantasia deve aparecer nas cores e silhuetas, sem copiar mapas ou personagens de outro jogo.

O cenário é 3D em resolução nativa, com filtragem linear das texturas. Os viajantes continuam em pixel art com filtragem nearest. Pintura de cenário e pixel art de personagem são tratamentos distintos e intencionais.

## Composição implementada

O gerador é `game/tools/art/build_training_field.gd`; a saída jogável é `game/scenes/maps/training_field.tscn`. Não editar somente a cena gerada: a próxima execução substituiria a alteração.

- A clareira de terra foi reduzida de raio 6,6 m para 4,8 m, com centro em `(0, 0, -1)`. A fogueira permanece em `(0, 0, -1.5)`. Isso aproxima o gramado do ponto de chegada e reduz a massa contínua de terra.
- As trilhas radiais começam a 4,2 m, têm largura configurada de 1,1 m e encontram as saídas originais. O caminho sul conserva largura de 2 m. Trilhas externas, locais de treino, NPCs, portal e obstruções são preservados.
- A vegetação ornamental do acampamento deixa de usar três dispersões sobrepostas de centenas de tentativas. Agora são seis canteiros, cada um com 35 tentativas, raio de 2 m e uma única família de flor, intercalada com capim baixo. Dois terços das tentativas usam capim e um terço flores. A filtragem por caminho/obstrução pode reduzir o total efetivo.
- Centros dos canteiros em coordenadas polares `(ângulo, distância)`: `(115°,9.4)`, `(62°,8.8)`, `(185°,12)`, `(350°,12)`, `(242°,12.8)`, `(298°,12.8)`. Flores roxas e claras alternam entre grupos; não entre cada planta.
- Escalas de 0,4–0,65 mantêm os canteiros abaixo da leitura do viajante. O gerador próprio usa seed `2809202606`, sem consumir o RNG que posiciona as vinhetas.
- As pétalas do acampamento passam de 80 para 18, em tom creme. O efeito deve ser percebido em movimento, sem cobrir o chão de pontos amarelos.

## Vegetação nas regiões

Após montar os elementos do mapa, o gerador filtra capins, flores e samambaias fora do acampamento com `FastNoiseLite`, seed `28092026`, frequência `0.11`. Capins/samambaias permanecem quando o ruído é pelo menos `-0.08`; flores exigem `0.08`. Isso produz grupos mais concentrados de cor, com intervalos de chão livre. Áreas de exclusão de NPCs e spawns também removem essas plantas. Árvores, arquitetura, rochas e peças culturais não passam por esse filtro. O terreno sob as plantas continua pintado: uma clareira não vira chão sem textura.

## Pintura e materiais

O terreno continua sendo uma malha contínua com relevo e onze camadas, mescladas por três mapas de pesos. Preserva as margens, cristas, lagoas e identidades de bioma da revisão 5. Não foram criadas novas texturas raster nesta revisão: o trabalho reorganiza os assets existentes e ajusta sua aplicação.

Em `env_terrain_world.gdshader`:

- Grama: mistura de 24% de verde `(0.30,0.47,0.23)` à textura existente, para controlar a tendência amarela e a variação excessiva.
- Terra: textura em escala de 3,2 m, com mistura de 40% de tom `(0.66,0.55,0.39)`. O desenho fica mais discreto e a repetição menos dominante junto ao personagem.
- Variação ampla de cor: intensidade 0,22, antes 0,45.
- Pinceladas de ruído: intensidade 0,075, antes 0,16.
- Ruído das transições: 0,28, antes 0,45. As bordas mantêm irregularidade, com menor aspecto recortado.

Esses números são parâmetros de shader em espaço de cor declarado pelo material; não são instruções para aplicar filtros numa captura de tela.

## Luz e acabamento

A luz do campo é definida no próprio gerador, sem substituir os presets de outras regiões. Sol `(1.0,0.96,0.86)`, energia 1,2; ambiente `(0.72,0.8,0.79)`. Névoa `(0.83,0.9,0.86)`, densidade de altura 0,025. O resultado pretendido é luz de dia com distância suave e sombras ligeiramente frias.

Oclusão ambiente: intensidade 1,3, raio 1,2, potência 1,2. Glow 0,22. O contato dos objetos com o chão continua visível sem sujar grandes áreas.

O pós-processamento compartilhado `env_screen_post.gdshader` usa faixa nítida central 0,34, desfoque máximo 1,2 px, vinheta 0,16 e traço de borda 0,10. Esta alteração também afeta outros mapas que usam o shader. A interface permanece fora desse efeito. Não usar desfoque como substituto para acabamento da geometria.

## Blender e assets preservados

`game/tools/art/blender/camp.py` contém a modelagem original já existente de tendas, fogueira, placas, lampiões, poço e rancho. `vignettes.py` contém os elementos das nações; `landmarks.py` contém os marcos maiores. Esta revisão reutiliza essas malhas, não reivindica nova modelagem Blender.

O importador `game/tools/art/env_kit/build_pack_kit.gd` associa materiais pelos nomes (como `Cloth_*`, `Stone_*`, `Wood_*`) às texturas pintadas e agrupa instâncias. Alterações futuras de silhueta devem ser feitas no script Blender e exportadas novamente; alterações de composição pertencem ao gerador do campo. Evitar acrescentar detalhes pequenos que só apareçam em close de editor.

## Reprodução e verificação

Na raiz do repositório:

```sh
.tools/godot-4.7.2 --headless --path game --script res://tools/art/build_training_field.gd
.tools/godot-4.7.2 --headless --path game res://tools/art/verify_training_field.tscn
```

Para atualizar também o minimapa (requer tela/GPU; `xvfb-run` funciona na validação automatizada):

```sh
mkdir -p /tmp/perdidos-minimap
xvfb-run -a .tools/godot-4.7.2 --path game --resolution 1024x1024 --script res://tools/art/render_minimap.gd -- --map=training_field --out=/tmp/perdidos-minimap
.tools/pyvenv/bin/python game/tools/art/minimap_pixel.py /tmp/perdidos-minimap/minimap_raw_training_field.png training_field
.tools/godot-4.7.2 --headless --editor --path game --import --quit
```

A construção recria terreno, materiais e navegação. Esperar terminar antes de abrir outro processo que leia a cena gerada.

A aprovação visual deve usar servidor local e cliente com personagem novo no nascimento. `game/scenes/lookdev/real_tour.tscn` permite percorrer as regiões por solicitações reais de movimento ao servidor. A captura inicial `00_spawn` usa a câmera normal; as capturas de nações orientam a câmera para suas vinhetas e não devem ser confundidas com a vista inicial.

Evidências desta revisão ficam em `docs/arte-cenario/v6/`. Comparar clareza das trilhas, separação personagem/chão, densidade das flores e leitura nas bordas. Não aprovar apenas pela vista aérea do editor.

## Resultado e limites da validação

- Gerador: conclusão com `err=0`; 33 peças culturais posicionadas, nenhuma pulada.
- Navegação: 2.872 vértices e 3.332 polígonos; grade 184×184 com 20.885 células andáveis. `verify_training_field`: **OK, zero falhas**. Estes números pertencem à cena regenerada atual, não à cena antiga que estava salva antes de executar o gerador.
- Decoração: 13.412 instâncias em 541 MultiMeshes, contra 21.734 instâncias da primeira regeneração desta revisão antes de agrupar a vegetação das regiões. Essa comparação mede o filtro regional; não compara dois projetos diferentes.
- Minimapa: renderizado novamente da cena final, processado pela paleta mestra com `.tools/pyvenv/bin/python game/tools/art/minimap_pixel.py` e reimportado no Godot. O Python do sistema não contém SciPy; usar o ambiente de arte já existente.
- Capturas: cliente 1920×1080, servidor local, save novo, corpo feminino. O percurso inclui nascimento, rancho, Pindorama e as nove nações. A interface capturada é a interface realmente instalada nesta revisão.
- Desempenho: o teste sob Xvfb apresentou aproximadamente 8–9 FPS no início, inclusive com VSync desativado. O perfil de GPU no nascimento registrou aproximadamente 12–14 ms, o que não explica sozinho o tempo total por quadro. **A meta de fluidez não está validada**: falta investigar o tempo restante de CPU/sincronização e repetir em sessão interativa. Reduzir plantas não autoriza afirmar que esse gargalo foi resolvido.
- Encerramento: os clientes de tour registraram avisos de recursos gráficos não liberados ao sair (`Texture RID` e `RenderingServer` nulo); não houve falha da verificação do mapa. Não classificar esses avisos como teste gráfico totalmente limpo.

Esta revisão não redesenha as folhas de animação dos viajantes. Elas continuam usando o sistema de camadas existente. Um novo conjunto de personagens exige manter alinhados corpo, roupa, cabelo, olhos e equipamentos em todas as direções.

### Evidências para revisão

- [Antes/depois do nascimento](v6/comparacao.jpg).
- [Nascimento na versão final](v6/00_spawn.jpg).
- [Terra de Pindorama](v6/03_pindorama.jpg), [Portugal](v6/04_portugal.jpg), [Grécia](v6/05_grecia.jpg), [Egito](v6/06_egito.jpg).
- [Celta](v6/07_celta.jpg), [Nórdico](v6/08_nordico.jpg), [Eslavo](v6/09_eslavo.jpg), [China](v6/10_china.jpg), [Japão](v6/11_japao.jpg), [México](v6/12_mexico.jpg).
- [Verificação do mapa](v6/verificacao.txt) e [métricas do percurso final](v6/percurso.txt). No percurso final, as capturas registraram 74–142 draw calls e 8–9 FPS; são medidas do ambiente de teste, não promessa de desempenho em outra máquina.

## Revisão 7 — "não parecer papel" (GDD §17.0.C), 28/09/2026 (Agente P2)

Composição, paleta, canteiros, trilhas e luz da revisão 6 foram mantidos. O que mudou:

**Câmera e escala** (`balance_config.gd`, `client_view.gd`): inclinação 57° (era 45°), distância base 26 m, Viajante com
≈10% da altura em 1080p (`character_screen_fraction = 0.10`, era 0,135 ≈ 16%). A escala de texel fica inteira quando
o valor exato está a até 0,15 de um inteiro (720p → 1); em 1080p ela é 1,286 e o shader dos sprites faz "pixel AA":
cada texel continua um bloco sólido e só a fronteira ganha 1 px de transição (sem o serrilhado irregular do nearest em
escala fracionária). Zoom livre 0,8–1,25. A compensação vertical 1/cos(57°) mantém o sprite 1:1 no foco; o clique
continua pelo mesmo raycast. Nome/números/balões no mundo: 1 px de fonte = 1 px de tela no foco.

**Sprites com a luz da cena** (`assets/shaders/char_palette_swap_3d.gdshader`, usado por TODAS as camadas):
cor/intensidade do sol e ambiente, sombras do cenário (árvore/casa escurecem o personagem, com piso de 30%), lado da
sombra em 3 tons por texel (normal cilíndrica falsa, sem gradiente), contorno de cima levemente aceso pelo céu e luzes
pontuais (fogueira/lampiões). Cada sprite projeta a própria silhueta no chão (na passada de sombra o quadro vira para o
sol, com a altura real). Sombra macia colada aos pés (`char_blob_shadow.gdshader`): elipse que escurece e se desloca
um pouco para o lado da sombra conforme o sol; desenhada depois das manchas de chão transparentes.

**Vida procedural** (`directional_sprite_3d.gd`, serve para qualquer folha): respiração parada, balanço do andar no
ritmo dos passos, quique uma vez por célula com achatamento na aterrissagem para monstros `hop`/`hop_teleport`,
flutuação para `fly_pattern`, tranco + flash branco no golpe recebido (humanos sutis, monstros elásticos) e morte que
achata e some em pontilhado. `CombatVisuals.life_profile()` escolhe o perfil pelo `MonsterStage.behaviors`.

**Vegetação** (`build_training_field.gd`, `_ground_hugging_pass`; RNG próprio, seed `2809202617`): metade do capim
espalhado sai e o resto fica 45% mais baixo (flores 22%, samambaia 20%); planta rasteira sem 2 vizinhas a 1,4 m sai
(516 tufos isolados). Entram 289 moitas baixas e cheias (1.952 peças): intercaladas nas bordas das trilhas (45), em
manchas de ruído pelo campo (168) e ao pé de árvores/pedras (76). As moitas usam `bush_low_a/b/c`
(`tools/art/env_kit/build_bush_low.gd`: copas pintadas do kit + arbusto CC0 do Quaternius, materiais com verde mais
próximo do gramado e vento suave), achatadas e sobrepostas, sem sombra projetada (custo). Nos seis canteiros do
acampamento o "capim baixo" virou folhagem baixa; flores, centros e raios da revisão 6 ficaram iguais. A cidade
(`build_city.gd`) recebeu o mesmo achatamento/raleamento, sem moitas novas. Navmesh inalterado (2.872 vértices /
3.332 polígonos); `verify_training_field` e `verify_city`: OK.

**Fluidez**: 164 entidades do mapa são replicadas ao cliente; cada uma processava o sprite todo quadro. Agora sprite
fora da visão da câmera só avança o relógio da animação, e a câmera é procurada uma vez por quadro (não 2× por
entidade). Medido na GPU real (RTX 2060, 1920×1080, preset Alta, cliente real + servidor local, com outros processos
pesados na máquina): **VSync ligado: 59,9 fps em todos os trechos, p99 ≤ 18 ms**; VSync desligado: 91–100 fps
(GPU ≈ 8,5–10 ms, CPU de renderização ≈ 1,3 ms). Os 8–9 fps da revisão 6 eram do Xvfb (renderização por software,
llvmpipe) e não representam a máquina. Dados: `v7/desempenho.jsonl`.

Reprodução da validação (servidor + personagem novo, GPU real):
`game/scenes/lookdev/p2_tour.tscn -- --name=X --port=P --p2-out=/dir --p2-steps=perf,spawn,seq,fight,zones [--p2-vsync=0]`.
Isolados: `game/tools/p2/sprite_lookdev.tscn` (luz/sombra dos sprites) e `game/tools/p2/veg_gallery.tscn` (vegetação na
câmera do jogo). Evidências: `v7/` — lado a lado com a referência, v6×v7, nascimento (normal, zoom mín./máx., câmera
girada), luta, Japão, Egito, Nórdico e sequências (respiração, balanço do andar, golpe com flash e achatamento).

## Revisão 8 — leitura de mapa e resposta ao movimento, 01/10/2026

Referência de direção explicitada: **Ragnarok Online** — caminhos de leitura imediata atravessando massas de vegetação, marcos visuais reconhecíveis e personagem caminhando em oito direções. A referência orienta densidade e leitura; mapas, personagens e assets continuam próprios de Perdidos.

No Campo de Treino (`build_training_field.gd`), as manchas determinísticas de moitas baixas passaram a usar grade de amostragem 3,0 m (antes 3,2 m) e limiar de ruído 0,25 (antes 0,30). O filtro continua preservando trilhas, obstáculos, NPCs e áreas de exclusão; o centro do acampamento e a navmesh não mudam.

No movimento, `hold_walk_repeat_ms` passou de 200 para 120 ms. Clique segurado e joystick atualizam o destino com menor intervalo; velocidade por célula, passos em oito direções e caminho/posição autoritativos do servidor permanecem iguais. Isso melhora a resposta ao redirecionar, sem acelerar o personagem nem suavizar curvas fora do caminho andável.

Validação: campo regenerado e captura feita no cliente real conectado a servidor local. O verificador completo ainda termina com falhas nas dimensões de folhas de monstros e em uma chave de localização, fora dos arquivos desta revisão; não declarar o conjunto inteiro aprovado por esse resultado.

## Revisão 9 — clareira viva e preparação azul, 08/10/2026

O acampamento recebe dez grupos de vegetação que enquadram a clareira: 28 árvores novas com troncos bloqueados, moitas e samambaias sobrepostas e bordas baixas nos canteiros internos. A distribuição usa RNG próprio, seed `8102026`, preservando caminhos, obstáculos e espaços de interação. O terreno central ganha verdes mais densos e terra mais quente; o efeito radial termina a 38 m. As barracas usam tecidos ocre e azul esverdeado, com costuras, desgaste e movimento sutil. Os materiais são cópias exclusivas do Campo, geradas pelo mesmo script do mapa. Ambiente, contraste e oclusão reforçam a separação entre volumes. Mapa, navmesh e minimapa foram regenerados; navegação: 3.086 vértices / 3.602 polígonos.

A preparação das skills usa azul, incluindo o antigo clarão quente da Lança de Fogo e as peças de carga do arco. Arcos, anéis fragmentados em rotação contrária, pontos luminosos e partículas convergentes acompanham o personagem. O efeito evolui continuamente a cada quadro de renderização, pelo tempo real de conjuração; o aviso de área é descontado desse tempo. A pose do corpo também acompanha a duração recebida do servidor. Cancelar, morrer ou remover o conjurador encerra a energia e limpa seus nós. Os sprites de carga são recoloridos no shader, preservando recortes e variações de luminosidade, sem alterar as cores dos impactos.

A referência de Samsara orienta ritmo e continuidade; a composição da clareira e o desenho de energia azul têm direção própria. Esta revisão não aumenta a quantidade de quadros desenhados nas folhas do corpo: mantém os quadros existentes e acrescenta movimento procedural contínuo.

Evidências: [campo no cliente real](v9/campo-treino.png), [preparação azul em vídeo](v9/carga-azul.mp4), [imagem da carga](v9/carga-azul.png) e [medições](v9/desempenho.jsonl). No cliente real conectado a servidor local, RTX 2060, 1920×1080, VSync desligado: média de 98,8 fps na chegada e ao girar a câmera; p99 de 11,26 ms e 14,06 ms, respectivamente. Essa medição caracteriza esses trechos e essa máquina.

Validação: direção/animação, 168 verificações aprovadas; teste específico da carga aprovado (duração, azul nas peças antigas, acompanhamento, cancelamento, morte, remoção e reutilização após descarte). O verificador do mapa aprova 111 verificações de camadas, posições andáveis, alcance e espaço livre. O conjunto completo termina com 1.485 falhas: 1.277 dimensões de folhas, 207 chaves de tradução e contagem antiga de Mestres (11 esperados, 13 presentes). A suíte geral de FX acusa seis falhas de aparição em skills de companheiros; registrar esse resultado separadamente do teste da carga.

Reproduzir a prévia: `./godot --path game --fixed-fps 24 --resolution 1280x720 --script res://tools/art/render_skill_charge.gd -- --out=/pasta`; codificar os PNGs a 24 fps. Teste da carga: `./godot --headless --path game --script res://tests/client/test_skill_charge_flow.gd`.

## Revisão 10 — som da preparação e fogo com volume, 08/10/2026

A preparação ganha um laço sonoro original de energia, sintetizado pelo projeto sem amostras externas (`tools/audio/gen_skill_charge.py`). `CombatAudio` inicia uma voz 3D no bus SFX, ancorada no conjurador: volume e pitch crescem com a carga, com entrada de 80 ms e saída de 120 ms. O laço acompanha qualquer duração, descontando o aviso no chão. Cancelamento, morte, remoção e nova conjuração encerram a voz anterior. As configurações de volume e silêncio do bus SFX continuam controlando o som. Os sons curtos de cada skill permanecem; o som de impacto, que antes tocava junto com o início da carga, espera agora a liberação e é descartado quando a preparação é cancelada.

No Campo, o cliente oculta os planos antigos da fogueira e os substitui por línguas de chama com geometria em três eixos. Turbulência move as superfícies em direções diferentes; ruído tridimensional quebra sua transparência enquanto sobe. Nenhuma língua gira para acompanhar a câmera. A paleta solicitada é laranja avermelhada, com centro laranja mais claro e bordas vermelhas. Fumaça, brasas, pedras, troncos e luz tremulante com sombras continuam. Alta/Média/Baixa usam sete/cinco/três línguas por fogueira, com distância de visibilidade por preset. A construção é exclusivamente visual e local ao cliente; navegação e obstáculos permanecem os do mapa regenerado na revisão 9.

Evidências: [carga azul com som e fogo laranja avermelhado](v10/carga-som-fogueira.mp4), [fogueira à noite](v10/fogueira-noite.mp4) e [imagem noturna](v10/fogueira-noite.png). A prévia sonora usa um ouvinte na posição do personagem, como o cliente; o vídeo noturno demonstra a chama e não inclui o ambiente sonoro.

Validação: `test_skill_charge_audio.tscn` aprova 12 verificações, incluindo crescimento, acompanhamento, sequência temporal, cancelamento sem impacto posterior, morte e remoção. `test_living_environment.gd` também aprova a geometria em três eixos e a redução de camadas na qualidade Baixa. A renderização Vulkan foi conferida durante o dia e à noite. O teste visual da carga continua aprovado. As falhas gerais registradas na revisão 9 não são cobertas por esses testes específicos.

Para gravar imagem e áudio reais da prévia, usar `--write-movie /pasta/preview.avi` com `render_skill_charge.gd` a 24 fps; o Movie Maker do Godot grava a mistura sonora junto dos quadros. Converter o AVI para MP4 com vídeo H.264 e áudio AAC. Teste de áudio: `./godot --headless --path game res://tests/client/test_skill_charge_audio.tscn`.
