#!/usr/bin/env bash
# Cliente do jogo.
#
# Uso:   tools/run_client.sh                 -> tela de título (nome, corpo, servidor)
#        tools/run_client.sh <nome> [male|female] [--host=127.0.0.1] [--port=7777] [--autotest ...]
# Godot: defina GODOT com o caminho do binário (padrão: "godot" no PATH).
# HEADLESS=1 roda sem janela (para testes).
#
# --autotest                     roda tests/server/client_autotest.gd depois de entrar e sai
#                                (código 0 = passou; imprime "autotest_result {"pass": ...}").
# --autotest-role=shopper|observer   papel no autoteste (padrão observer).
# --autotest-move=x,z            deslocamento do movimento de teste da Fase 1 (padrão 4,3).
# --autotest-bad-protocol        conecta com protocol_version errado; deve ser recusado.
# --test-fixtures                carrega os dados de teste (use junto com o servidor).
#
# Autoteste completo (servidor + 2 clientes, com resumo): tools/run_autotest.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXTRA=()
if [[ "${HEADLESS:-0}" == "1" ]]; then
	EXTRA+=(--headless)
fi
if [[ $# -eq 0 ]]; then
	exec "$GODOT" "${EXTRA[@]}" --path "$PROJECT_DIR"
fi
NAME="${1:-}"
BODY="${2:-male}"
shift $(( $# > 2 ? 2 : $# ))
exec "$GODOT" "${EXTRA[@]}" --path "$PROJECT_DIR" -- --name="$NAME" --body="$BODY" "$@"
