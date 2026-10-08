#!/usr/bin/env bash
# Capturas dos portais (PortalFx) no cliente real: Porto, Campos, Mata e Chapada, de dia e de noite.
# Uso: GODOT=/caminho/godot [OUT=.work/portal] [PORT=8193] [APPROACH=1] tests/client/run_portal_capture.sh
# APPROACH=1: só a aproximação no Porto (longe, meio, entrada), de dia e de noite.
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$P/../.work/portal}"
PORT="${PORT:-8193}"
APPROACH="${APPROACH:-0}"
LOG_DIR="$(mktemp -d)"
SAVES="$LOG_DIR/saves"
mkdir -p "$OUT" "$SAVES"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT
# Save antigo (sem left_training): entra direto no Porto; nível alto para os portais de caça abrirem.
cat >"$SAVES/capportal.json" <<'JSON'
{"format": 1, "name": "CapPortal", "body": "female", "level": 40, "attributes": {}, "hp": 900, "mp": 90,
 "stars": 0, "inventory": [], "equipment": {}, "once_flags": []}
JSON
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --dev-commands --save-dir="$SAVES" \
	--state-dir="$LOG_DIR/state" >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!)
sleep 3
xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path "$P" --resolution 1280x720 -- --name=CapPortal \
	--body=female --port="$PORT" --autotest --autotest-script=res://tests/client/portal_capture.gd \
	--shot-dir="$OUT" --portal-approach="$APPROACH" >"$LOG_DIR/client.log" 2>&1
echo "=== logs em $LOG_DIR"
grep -h "portal_capture\|SCRIPT ERROR\|entered_map\|portal" "$LOG_DIR/client.log" | head -40
grep -h "player_entered_map\|portal_\|invalid" "$LOG_DIR/server.log" | head -20
