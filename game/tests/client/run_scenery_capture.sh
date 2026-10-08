#!/usr/bin/env bash
# Capturas do cenário vivo (vento nas plantas, sombras de nuvem, partículas de ar, caverna) em vários mapas, cliente real.
# Uso: GODOT=/caminho/godot [OUT=.work/scenery] [PORT=8289] [PHASE=antes|depois] [MAPS=a,b] [RES=1280x720] tests/client/run_scenery_capture.sh
# Servidor próprio numa porta separada (não mexe no do dono).
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$P/../.work/scenery}"
PORT="${PORT:-8289}"
PHASE="${PHASE:-depois}"
RES="${RES:-1280x720}"
LOG_DIR="$(mktemp -d)"
SAVES="$LOG_DIR/saves"
mkdir -p "$OUT" "$SAVES"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT
cat >"$SAVES/capscenery.json" <<'JSON'
{"format": 1, "name": "CapScenery", "body": "female", "level": 5, "attributes": {}, "hp": 300, "mp": 60,
 "stars": 0, "inventory": [], "equipment": {}, "once_flags": []}
JSON
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --dev-commands --save-dir="$SAVES" \
	--state-dir="$LOG_DIR/state" >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!)
sleep 3
xvfb-run -a -s "-screen 0 2000x1200x24" "$GODOT" --path "$P" --resolution "$RES" -- --name=CapScenery \
	--body=female --port="$PORT" --autotest --autotest-script=res://tests/client/scenery_capture.gd \
	--shot-dir="$OUT" --scenery-phase="$PHASE" ${MAPS:+--scenery-maps="$MAPS"} >"$LOG_DIR/client.log" 2>&1
echo "=== logs em $LOG_DIR"
grep -h "scenery_capture\|SCRIPT ERROR\|SHADER ERROR\|global" "$LOG_DIR/client.log" | head -40
