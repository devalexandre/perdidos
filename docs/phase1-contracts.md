# Fase 1 — Contratos entre módulos (Área 1: Porto do Despertar)

Objetivo (GDD §19, Fase 1): câmera 2.5D, personagem billboard em 8 direções, movimento por clique,
servidor headless autoritativo, 2 clientes se vendo. Critério de pronto: *dois jogadores andando na mesma
cena, vendo um ao outro, com direções corretas ao girar a câmera.* Mapa: cidade `city_awakening`.

Engine: Godot 4.7.2, GDScript **tipado**. Binário: `$GODOT` (ver `tools/`). Projeto em `game/`.
Constantes: `Balance.cfg.<campo>` (`scripts/shared/balance_config.gd`, `data/balance.tres`). Não editar
esses dois arquivos; se precisar de uma constante nova, use `@export` local no seu script e reporte.

## Donos (cada agente só cria/edita os arquivos do seu módulo)

| Módulo | Dono | Arquivos |
|---|---|---|
| Rede/servidor | Agente A | `scenes/main.tscn`, `scripts/main.gd`, `scripts/shared/net.gd`, `scripts/shared/player_entity.gd`, `scenes/entities/player.tscn`, `scripts/server/**`, `tools/*.sh` |
| Cliente/render | Agente B | `scenes/ui/client_view.tscn`, `scripts/client/**`, `scenes/ui/**`, `localization/**` |
| Arte/mapa | Agente C | `assets/**` (exceto `_reference/style_anchor` já pronto), `scenes/maps/**`, `scripts/shared/map.gd`, `data/regions/**`, `data/maps/**`, `tools/art/**` |

## Árvore de cena (idêntica em servidor e cliente — caminhos de rede dependem disso)

```
/root/Main                         (main.gd — decide servidor ou cliente)
  World (Node3D)
    Instances (Node3D)
      <instance_node_name> (Node3D)   ex.: "city_awakening"  (":" vira "__" no nome do nó)
        Map        (instância da cena do mapa, ver abaixo)
        Entities   (Node3D; spawn_path do MultiplayerSpawner da instância)
  ClientView  (só no cliente; instanciado por main.gd a partir de scenes/ui/client_view.tscn)
```

- Servidor tem todas as instâncias; cliente só tem a instância em que está.
- `instance_id`: cidade/PVP = `map_id`; caça = `map_id + ":" + party_id` (GDD §5.1). Filtro de visibilidade
  no servidor com `MultiplayerSynchronizer.public_visibility = false` + `add_visibility_filter()` (GDD §5.6).

## Mapa (Agente C → consumido por A e B)

- Cena `res://scenes/maps/city_awakening.tscn`, raiz `Node3D` com script `res://scripts/shared/map.gd`
  (`class_name GameMap`), campos: `@export var map_id: StringName = &"city_awakening"`.
- Métodos: `get_spawn_point() -> Vector3`, `get_navigation_map() -> RID` (o `NavigationRegion3D` filho com
  navmesh **já assado** e salvo na cena — o servidor headless não deve precisar assar em runtime).
- Chão/colisores para o clique: `StaticBody3D` na **camada de colisão 1**. Nada mais na camada 1.
- Tamanho ~120 x 120 unidades (1 un. = 1 m = **48 px**, GDD §17.2 revisado). Origem do mapa no centro. Y = 0 é o chão da praça.
- Deve carregar no servidor headless (sem depender de nada visual para funcionar).

## Sprites do personagem (Agente C → consumido por B)

- `res://assets/characters/chr_traveler_male_idle.png` (4 quadros) e `..._walk.png` (8 quadros);
  idem `chr_traveler_female_*`. Quadro **96x96** (GDD §17.2 revisado; antes 64x64); **linhas = direções S, SE, L, NE, N**; colunas = quadros;
  fundo transparente; pés no centro inferior do quadro (x=48, y=95), personagem ~80 px.
  Durações: idle 200 ms/quadro, walk 100 ms/quadro (GDD §17.3).
- `res://assets/characters/chr_shadow.png`: sombra oval, será desenhada com 50% de opacidade.
- Somente cores da paleta mestra (`assets/_reference/style_anchor/paleta-mestra.gpl`). Contorno colorido, nunca preto puro.
- Arte provisória é aceitável (GDD §19), mas deve seguir tamanho, origem, direções e paleta.

## Entidade jogador (Agente A → consumido por B)

- `res://scenes/entities/player.tscn`, raiz `Node3D` com `res://scripts/shared/player_entity.gd`
  (`class_name PlayerEntity`), nome do nó = str(peer_id).
- Propriedades replicadas: `peer_id: int`, `display_name: String`, `body_type: StringName` (&"male"/&"female"),
  `instance_id: StringName`, `net_position: Vector3`, `facing_yaw: float` (radianos, direção para onde
  olha, yaw no plano XZ, 0 = olhando para -Z), `anim: StringName` (&"idle" / &"walk").
- No cliente, a posição visual é interpolada a partir de `net_position` com atraso de `client_interp_delay_ms`.
- Filho `Visual` = instância de `res://scenes/entities/directional_sprite_3d.tscn`? **Não** — para evitar
  dependência cruzada de cena: o PlayerEntity, **no cliente**, cria em `_ready()`:
  `var v := DirectionalSprite3D.new()` (classe de B em `scripts/client/directional_sprite_3d.gd`),
  chama `v.setup(body_type)`, adiciona como filho `Visual`, e a cada frame define `v.facing_yaw` e `v.anim`.
- `is_local_player() -> bool` (peer_id == multiplayer.get_unique_id()).

## Visual direcional (Agente B)

- `class_name DirectionalSprite3D extends Node3D` com `setup(body_type: StringName)`, props `facing_yaw`, `anim`.
- Sprite3D/AnimatedSprite3D com billboard eixo Y, `pixel_size = Balance.cfg.sprite_pixel_size`,
  filtro nearest, pés na origem do nó. Sombra separada no chão com 50% opacidade.
- Direção exibida = ângulo entre `facing_yaw` e a posição da câmera, setor de 45° mais próximo; 8 direções
  a partir de 5 (SO = SE espelhado, O = L espelhado, NO = NE espelhado) (GDD §17.3).

## ClientView (Agente B → usado por A)

- `res://scenes/ui/client_view.tscn`, script `scripts/client/client_view.gd` (`class_name ClientView`).
- Renderiza o `World` numa `SubViewport` de 960x540 (`Balance.cfg.internal_resolution`) ampliada por múltiplo inteiro (GDD §17.2), interface
  por cima em resolução própria. Como `World` fica em `/root/Main/World` (não dentro da SubViewport), a
  SubViewport deve compartilhar o `World3D` do viewport raiz, e o raiz não deve renderizar 3D.
- API: `set_follow_target(target: Node3D)`, `signal move_requested(world_pos: Vector3)` (clique/toque no
  chão, raycast na camada 1), `show_status(text: String)`.
- Câmera orbital: perspectiva, inclinação ~45°, yaw livre (Q/E, arrastar botão direito, 2 dedos), zoom
  0,8x–1,3x (roda do mouse, pinça). Registra as ações de input em runtime (InputMap) — não editar project.godot.
- Todo texto visível via `tr("CHAVE")`, strings em `localization/strings.csv` (coluna `pt_BR`), gerando
  `localization/strings.pt_BR.translation` na importação.

## Rede (Agente A)

- ENet UDP, porta `Balance.cfg.default_port`. Servidor: feature tag `dedicated_server` **ou** argumento
  de usuário `--server` (`OS.get_cmdline_user_args()`). Cliente: `--host=`, `--port=`, `--name=`, `--body=male|female`.
- Handshake com `protocol_version`; versão diferente → servidor recusa e cliente mostra `tr("NET_UPDATE_REQUIRED")`.
- Intenção `req_move(target: Vector3)`: servidor valida (ponto alcançável no navmesh), calcula caminho com
  `NavigationServer3D.map_get_path`, move a `player_move_speed` no tick de 20 Hz. Sem colisão entre entidades.
- Limite de 30 mensagens/s por cliente; mensagem inválida é ignorada e registrada em log.
- `main.gd` no cliente conecta `ClientView.move_requested` → RPC `req_move`, e chama `set_follow_target` no
  jogador local quando ele aparecer.
- Scripts: `tools/run_server.sh`, `tools/run_client.sh <name> [male|female]` usando `${GODOT:-godot}`.
