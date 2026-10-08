# Ambiente vivo — Campo de Treino

Referência visual: [Gullwing Camp, Samsara Saga](https://samsarasaga.com/art/daycycle/loop/gullwing-camp-day-loop-8.webm).
A referência usa a passagem do dia para mudar a atmosfera e o destaque da fogueira.
Esta etapa acrescenta movimento local ao cenário existente.

- Vegetação e bandeiras usam a mesma frente de brisa, com ondulação local para evitar sincronização rígida.
- As fogueiras do acampamento e do rancho soltam fumaça suave; o rancho recebe brasas ascendentes.
- Borboletas aparecem nos canteiros durante o dia. Vagalumes aparecem nos canteiros do acampamento à noite.
- A troca dos insetos usa a rampa do relógio existente, com opacidade gradual.
- Qualidade Alta/Média/Baixa reduz quantidade e distância das novas partículas.
- Chamas com cinco línguas, turbulência e variação de cor; leito de brasas e sombras das luzes das fogueiras em Alta/Média.
- Chuva leve/forte e neblina sorteadas por região, com cache enquanto o clima está vigente e transições de 6–10 segundos.
- Temporais reduzem a iluminação, esfriam o céu e suavizam sombras; neblina é aplicada no Environment 3D.
- Portais de mudança de mapa recebem anéis de runas, moldura, cristais flutuantes e luz local. O arco do Campo recebe um véu animado.

O Campo de Treino continua sempre de dia pela configuração existente. A prévia noturna força a noite
somente durante a captura. Pétalas, faíscas, vagalumes da vereda e iluminação existentes continuam ativos.

## Implementação

`game/scripts/client/env/living_environment.gd` define posições, quantidades, tamanhos e cores.
`GameMap` cria esse nó para o Campo de Treino no cliente com renderização; servidor e headless não criam os efeitos.
Não há colisões, entidades de combate ou replicação de partículas. Os efeitos são filhos do mapa e saem com ele.

`env_ambient_particle.gdshader` desenha fumaça, asas, brilho e brasas sem novas texturas.
`env_wind.gdshaderinc` compartilha a brisa dos shaders de vegetação e bandeiras em todos os mapas que os usam.

`weather_regions.gd` define chances por região: acampamento ameno, Pindorama/selva úmidos, região egípcia seca,
terras nórdicas/celtas com mais neblina. `RainOverlay` mantém o clima cosmético local e publica intensidade
e névoa no metadado `weather_visual` do mapa. `day_night_light.gd` compõe esses valores com o ciclo de luz
a partir das bases originais, sem acumular escurecimento. Chuva e neblina externas não entram nas cavernas.
O clima é sorteado por cliente; não afeta combate e não é sincronizado entre jogadores.

`PortalFx` mantém os efeitos de sprites existentes e os destinos/áreas de interação; os detalhes novos não têm colisão.

## Verificação e prévia

```bash
./godot --headless --path game --script res://tests/client/test_living_environment.gd
./godot --headless --path game res://tests/monsters/test_night.tscn
./godot --path game --resolution 960x540 --script res://tools/art/render_living_environment.gd -- --out=/tmp/camp-day
./godot --path game --resolution 960x540 --script res://tools/art/render_living_environment.gd -- --night --out=/tmp/camp-night
./godot --path game --resolution 960x540 --script res://tools/art/render_living_environment.gd -- --weather=storm --out=/tmp/camp-storm
./godot --path game --resolution 960x540 --script res://tools/art/render_living_environment.gd -- --weather=fog --out=/tmp/camp-fog
./godot --path game --resolution 960x540 --script res://tools/art/render_living_environment.gd -- --portal --night --out=/tmp/camp-portal
```

A ferramenta grava 48 PNGs para uma prévia de quatro segundos a 12 fps. Essa taxa é da captura;
os efeitos do jogo usam o tempo contínuo do renderizador.
