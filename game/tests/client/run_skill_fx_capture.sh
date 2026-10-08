#!/usr/bin/env bash
# Captura dos efeitos de skill no cliente real: servidor (--progression-autotest) + 1 cliente 1280x720
# com --skill-fx-capture, no Campo de Treino perto do ponto de nascimento. Depois monta a prancha e
# os GIFs (tools/art/fx/fx_board.py).
# Uso:  GODOT=/caminho/godot xvfb-run -a tests/client/run_skill_fx_capture.sh [SAIDA]   (padrão: ../.work/fx)
#       ONLY=bow_,tank_ ...  captura só as skills com esses prefixos (bow_basic_attack = ataque básico com arco).
# 30/09/2026: cobre as 12 do MVP, as da Terra de Pindorama v0.4 que já têm .tres e o ataque básico com arco.
set -uo pipefail
GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${1:-$GAME_DIR/../.work/fx}"
PORT="${PORT:-8031}"
LOG_DIR="$(mktemp -d)"
SHOTS="$OUT/shots"
rm -rf "$SHOTS"; mkdir -p "$SHOTS" "$LOG_DIR/saves"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT
"$GODOT" --headless --path "$GAME_DIR" -- --server --port="$PORT" --save-dir="$LOG_DIR/saves" \
	--progression-autotest >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!)
sleep 3
EXTRA=()
[ -n "${ONLY:-}" ] && EXTRA+=("--fx-only=$ONLY")
# MONSTER=buriti_boar: a Faísca cai num monstro de verdade; CLIENT_ARGS="--classic-fx" volta aos FX em pixel art.
[ -n "${MONSTER:-}" ] && EXTRA+=("--fx-monster=$MONSTER")
[ -n "${CLIENT_ARGS:-}" ] && EXTRA+=($CLIENT_ARGS)
"$GODOT" --path "$GAME_DIR" --resolution 1280x720 -- --name=Viajante --port="$PORT" --skill-fx-capture \
	--fx-shots="$SHOTS" "${EXTRA[@]}" >"$LOG_DIR/client.log" 2>&1 &
CLIENT=$!; PIDS+=($CLIENT)
wait "$CLIENT"; RC=$?
echo "=== logs em $LOG_DIR (cliente rc=$RC)"
grep -h "fx_capture\|SCRIPT ERROR" "$LOG_DIR/client.log" | head -120
# Python com numpy/PIL (o do pyenv pode não ter): tenta o do PATH, senão o do sistema.
PY=python3; "$PY" -c "import numpy, PIL" 2>/dev/null || PY=/usr/bin/python3
"$PY" "$GAME_DIR/tools/art/fx/fx_board.py" "$SHOTS" "$OUT"
