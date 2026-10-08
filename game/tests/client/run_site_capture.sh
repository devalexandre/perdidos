#!/usr/bin/env bash
# Capturas do site (sem interface) no cliente real: fotos e quadros de clipe (site_capture.gd).
# Uso: GODOT=/caminho/godot [OUT=.work/site-capture] [PORT=8341] [ONLY=fotos|clipes] [RES=1920x1080]
#      [FIXED_FPS=12] [CLIPS=portal,passaros] tests/client/run_site_capture.sh
# Para os clipes use ONLY=clipes FIXED_FPS=12 (cada quadro = 1/12 s). Servidor próprio numa porta separada.
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$P/../.work/site-capture}"
PORT="${PORT:-8341}"
ONLY="${ONLY:-}"
RES="${RES:-1920x1080}"
FIXED_FPS="${FIXED_FPS:-}"
CLIPS="${CLIPS:-}"
LOG_DIR="$(mktemp -d)"
SAVES="$LOG_DIR/saves"
mkdir -p "$OUT" "$SAVES"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT
cat >"$SAVES/viajante.json" <<'JSON'
{"format": 1, "name": "Viajante", "body": "female", "level": 40, "attributes": {}, "hp": 900, "mp": 90,
 "stars": 0, "inventory": [], "equipment": {}, "once_flags": []}
JSON
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --dev-commands --save-dir="$SAVES" \
	--state-dir="$LOG_DIR/state" >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!)
sleep 3
xvfb-run -a -s "-screen 0 2000x1200x24" "$GODOT" --path "$P" --resolution "$RES" ${FIXED_FPS:+--fixed-fps "$FIXED_FPS"} \
	-- --name=Viajante --body=female --port="$PORT" --autotest --autotest-script=res://tests/client/site_capture.gd \
	--shot-dir="$OUT" --hide-hud=1 ${ONLY:+--site-only="$ONLY"} ${CLIPS:+--site-clips="$CLIPS"} >"$LOG_DIR/client.log" 2>&1
echo "=== logs em $LOG_DIR"
grep -h "site_capture\|SCRIPT ERROR\|entered_map" "$LOG_DIR/client.log" | head -60
