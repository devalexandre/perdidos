#!/usr/bin/env bash
# Capturas da vida de ambiente (gestos de NPC, passarinhos, sinais de uso) no cliente real: Campo de Treino + 3 mapas.
# Uso: GODOT=/caminho/godot [OUT=.work/camp_life] [PORT=8261] [RES=1280x720] tests/client/run_camp_life_capture.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$P/../.work/camp_life}"
PORT="${PORT:-8261}"
RES="${RES:-1280x720}"
LOG_DIR="$(mktemp -d)"
SAVES="$LOG_DIR/saves"
mkdir -p "$OUT" "$SAVES"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT
cat >"$SAVES/capcamp.json" <<'JSON'
{"format": 1, "name": "CapCamp", "body": "female", "level": 5, "attributes": {}, "hp": 300, "mp": 60,
 "stars": 0, "inventory": [], "equipment": {}, "once_flags": []}
JSON
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --dev-commands --save-dir="$SAVES" \
	--state-dir="$LOG_DIR/state" >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!)
sleep 3
xvfb-run -a -s "-screen 0 2000x1200x24" "$GODOT" --path "$P" --resolution "$RES" -- --name=CapCamp \
	--body=female --port="$PORT" --autotest --autotest-script=res://tests/client/camp_life_capture.gd \
	--shot-dir="$OUT" >"$LOG_DIR/client.log" 2>&1
echo "=== logs em $LOG_DIR"
grep -h "camp_capture\|SCRIPT ERROR\|SHADER ERROR\|global" "$LOG_DIR/client.log" | head -40
