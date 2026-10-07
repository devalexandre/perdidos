# Caverna do Reino Encoberto — implementação

Aplica a arquitetura canônica de cavernas aos quatro pisos. Gerador determinístico: `python3 game/tools/world/build_cave.py`. Ele grava cenas independentes com a mesma silhueta para chão, colisão e navmesh. A navegação tem pilares bloqueados, corredores e abismos; o minimapa usa `WalkGrid`, sem imagem genérica.

| Piso | Níveis | Topologia |
|---|---|---|
| F1 | 12–16 | Dois setores em circuito, pilares, câmara do eco e descidas oeste/leste |
| F2 | 16–20 | Corredores sinuosos, câmaras e conexões transversais |
| F3 | 20–24 | Ilhas de pedra ligadas por passarelas, câmara secundária e bandos |
| F4 | 25–30 | Salão do covil, altar, flancos e Fenda de Luz |

`cave_firefly` e `cave_werewolf` usam as folhas das espécies originais, com atributos/níveis próprios, preservando as espécies usadas pelas quests externas. Os pontos de nascimento deixam margem em torno das chegadas. O covil `BossLairs/werewolf` usa o serviço existente de chefes: escolta, respawn e transformação atroz à noite.

A saída `cave_surface_escape` é de sentido único e exige vitória contra o chefe do F4. O servidor desbloqueia a passagem ao receber o evento real de abate, para todos na instância compartilhada. O desbloqueio fica em memória até reiniciar o servidor. Não é possível desbloquear matando escoltas ou chefes de outros mapas.

Validação:

```sh
.tools/godot-4.7.2 --headless --path game res://tests/world/test_cave_architecture.tscn
.tools/godot-4.7.2 --headless --path game res://tests/beta/test_content_links.tscn
QUICK_ROUTE=1 WALK_PORTALS=1 bash game/tests/world/run_hunt_route.sh
```

`tests/world/cave_boss_client.gd` é um cliente de integração para servidor isolado `--autotest --dev-commands`: confirma o bloqueio da fuga, força a noite, verifica a transformação, derrota o chefe por comando de teste (pipeline real de abate) e atravessa a fuga. Não testa a dificuldade de combate de um grupo humano.

Para capturas gerais, rode `test_cave_architecture.tscn` com renderização e `-- --shots`. A saída fica em `/tmp/cave-floor-{1,2,3,4}.png`.
