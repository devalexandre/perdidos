#!/usr/bin/env bash
# Servidor dedicado headless (autoritativo).
#
# Uso:   tools/run_server.sh [--port=7777] [--save-dir=user://server_saves/] [--autotest] [--test-fixtures]
# Godot: defina GODOT com o caminho do binário (padrão: "godot" no PATH), ex.:
#        GODOT=/opt/godot/godot tools/run_server.sh
#
# --save-dir=DIR    pasta dos saves JSON dos personagens (padrão user://server_saves/).
# --autotest        cria uma instância falsa "city_awakening:party_autotest" com uma entidade "Ghost"
#                   (id 999001, que nenhum cliente da cidade pode receber), usa e limpa
#                   user://server_saves_autotest/ e encerra o servidor após ~150 s.
# --test-fixtures   completa os dados que faltam em data/ com tests/server/fixtures (NPC test_sage
#                   sempre; mercador/andarilho/presenteador/itens só se faltarem) e cria marcadores
#                   de NPC e objetos interativos de teste que faltem no mapa.
# Autoteste completo: tools/run_autotest.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$GODOT" --headless --path "$PROJECT_DIR" -- --server "$@"
