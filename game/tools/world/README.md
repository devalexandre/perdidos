# Geradores do mundo (tools/world)

Scripts Python que geram cenas de mapa (`scenes/maps`), zonas (`data/zones`), monstros, itens,
folhas de sprite e textos (`localization/*.csv`). Rode a partir de `game/`, com o Python que tem
PIL/numpy:

```sh
cd game
../.tools/pyvenv/bin/python3 tools/world/build_all.py --check   # simula tudo, mostra o que mudaria e valida
../.tools/pyvenv/bin/python3 tools/world/build_all.py           # regenera tudo (só grava arquivos que mudam)
../.tools/pyvenv/bin/python3 tools/world/build_hoer_verde_expansion.py --check   # um gerador só
python3 tools/world/validate_world.py [map_id ...]              # só a validação (todos os mapas sem args)
WORLDGEN_DUMP=/tmp/gen ../.tools/pyvenv/bin/python3 tools/world/build_all.py --check   # grava a saída simulada em /tmp/gen para comparar
```

Depois de gerar: `godot --headless --path game --import` e
`godot --headless --path game res://tests/beta/test_content_links.tscn`.

## Ordem

Geradores posteriores refinam o que os anteriores escreveram (por exemplo, `build_fields.py`,
`build_forest.py` e `build_plateau.py` refazem os mapas de `build_hunt_areas.py`, e `build_ratanaba_expansion.py` liga o
Alto das Brasas à Serra Dourada). Por isso `build_all.py` roda a cadeia inteira, em ordem, num processo
só (`PIPELINE`). Rodar só `build_hunt_areas.py`, sem os seguintes, volta campos, mata e Chapada ao rascunho.
`build_plateau.py` pinta o chão da Chapada com `env_terrain_world.gdshader` e mapas de mistura próprios
(`assets/environment/painted/terrain/<mapa>_splat_{a,b,c}.png`, material `mat_ground_<mapa>.tres`).

Cada mapa tem um dono. A Serra Dourada (cidade-polo) é gerada só por `build_ratanaba_expansion.py`,
com todos os portões dela (Chapada, Ratanabá, Z e Sumidouro). Os geradores de Z e de Hoer Verde só
conferem a ligação.

## `worldgen.py` (regras comuns)

- Toda escrita passa por `wg.write_text` / `wg.save_image` (ou por `wg.install()`, que redireciona
  `Path.write_text` e `Image.save`). Com `--check` nada vai para o disco. Um arquivo igual ao do
  disco não é regravado.
- `wg.require_res(path)` falha alto se um `res://` não existe (material de chão, ícone, script). No
  fim, `finish()` confere também todo `ext_resource` e `sprite_base` dos `.tres`/`.tscn` gravados.
- O chão é feito de células de 2 m × 2 m. A malha de navegação é gerada com as mesmas células
  (`wg.navmesh_body`, um quad por célula, `cell_size` 0.2, como espera `GameMap`).
- `wg.ensure_connected` liga ao SpawnPoint todo portal, ponto de chegada, covil, NPC e altar. Quando
  a área fica partida, abre uma ponte de 3 células (desviando de pilares) e avisa no log. Se não
  houver caminho possível, falha.
- `wg.snap_to_walkable` põe cada grupo de monstros (`Spawns/`) numa célula alcançável, com as 8
  vizinhas andáveis (espaço para o raio do grupo).
- `wg.csv_add` acrescenta chaves sem duplicar; se a chave já existe, o texto do arquivo prevalece.
  `wg.csv_set` serve para chaves de que o gerador é dono: troca o texto no lugar e mantém a ordem.
  Itens, crendices e diálogos vão para `content.csv`; zonas e `WA_*` para `world.csv`; monstros para
  `monsters.csv`. Não existem `items.csv`, `zones.csv` nem `crendice.csv`.
- `wg.portal_id(map, node)` gera `interact_id` únicos no mundo (`<map_id>_<nó em snake_case>`).

## Validação (`validate_world.py`, roda no fim de cada gerador; erro = saída 1)

Ela espelha as regras de mapa de `tests/beta/test_content_links.gd`:

- A raiz é `GameMap` (`res://scripts/shared/map.gd`, ou um script com `extends GameMap`) e
  `map_id` é igual ao nome do arquivo. Todo `res://` existe.
- Toda zona tem cena e toda cena tem zona. O `name_key` da zona tem tradução.
- Navegação em grade: o SpawnPoint é andável. Portais, chegadas usadas por algum portal, grupos e
  covis são alcançáveis a partir do SpawnPoint. Grupo na borda da área andável só gera aviso.
- `Spawns/`: o monstro existe em `data/monsters`, o estágio é 1 ou 2 (3 e 4 só em `BossLairs/`) e o
  nível fica entre `min − 10` e `max + 5` da faixa da zona.
- `BossLairs/`: o monstro tem estágio de chefe (3) e a zona tem `bosses_allowed`.
- Portais:
  - o destino existe e está em `connected_maps`;
  - o ponto de chegada (`target_spawn`) existe na raiz do destino (`*Return`, `DescentLanding`, ...);
  - portal de mão dupla tem portal de volta, e o destino lista este mapa;
  - portal de sentido único é a fuga após o chefe: `requires_boss_victory` mais um covil no mapa
    (o servidor abre a fuga quando morre o chefe do covil);
  - nenhum portal leva ao próprio mapa.
- `connected_maps`: cada entrada existe. Entrada sem portal correspondente gera aviso.
- `interact_id` único no mapa (erro). Portal com id repetido no mundo gera só aviso, porque os mapas
  antigos reutilizam `back` e `forward`.

## Gerar um mapa novo

1. Copie o padrão de um gerador de expansão (`build_hollow_earth_expansion.py` para cavernas e
   andares, ou `build_ratanaba_expansion.py` para cidade, selva e ruínas): salas (`rooms`), rotas,
   pilares, `spawn_pos`, portais, grupos, covis e `extra_markers` (pontos de chegada).
2. Em mapas novos, use `LEGACY_ROUTES = False`. Mapas antigos com `True` mantêm a planta publicada,
   cujos corredores miravam `(x, y)` em vez de `(x, z)`.
3. Para cada portal de mão dupla, crie o portal de volta no destino e um ponto de chegada perto dele
   (`<Origem>Return`, ou `DescentLanding` para quem sobe de andar). Atualize `connected_maps` dos dois
   lados.
4. A fuga do último andar é `{"is_escape": True}` (ou `"gate": True`) num mapa com `boss_lairs`.
5. Use só espécies que existem em `data/monsters`, com nível compatível com a faixa da zona. Estágio
   3 ou 4 só no covil.
6. Escreva as traduções com `wg.csv_add` e termine o gerador com `wg.finish([mapas], "nome")`.
7. Inclua o gerador em `build_all.py` (`PIPELINE`), rode `--check` e depois gere de verdade.
