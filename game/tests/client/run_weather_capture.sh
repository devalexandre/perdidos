#!/usr/bin/env bash
# Capturas do clima integrado (chuva molhando o chão, poças, fogueira, água) no Campo de Treino, cliente real.
# Uso: GODOT=/caminho/godot [OUT=.work/weather] [PORT=8197] [PHASE=dry] [RES=1280x720] tests/client/run_weather_capture.sh
# PHASE=dry: só as fotos em seco (referência). Servidor próprio numa porta separada (não mexe no do dono).
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$P/../.work/weather}"
PORT="${PORT:-8197}"
PHASE="${PHASE:-full}"
RES="${RES:-1280x720}"
LOG_DIR="$(mktemp -d)"
SAVES="$LOG_DIR/saves"
mkdir -p "$OUT" "$SAVES"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT
cat >"$SAVES/capweather.json" <<'JSON'
{"format": 1, "name": "CapWeather", "body": "female", "level": 5, "attributes": {}, "hp": 300, "mp": 60,
 "stars": 0, "inventory": [], "equipment": {}, "once_flags": []}
JSON
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --dev-commands --save-dir="$SAVES" \
	--state-dir="$LOG_DIR/state" >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!)
sleep 3
xvfb-run -a -s "-screen 0 2000x1200x24" "$GODOT" --path "$P" --resolution "$RES" -- --name=CapWeather \
	--body=female --port="$PORT" --autotest --autotest-script=res://tests/client/weather_capture.gd \
	--shot-dir="$OUT" --weather-phase="$PHASE" >"$LOG_DIR/client.log" 2>&1
echo "=== logs em $LOG_DIR"
grep -h "weather_capture\|SCRIPT ERROR\|SHADER ERROR\|global" "$LOG_DIR/client.log" | head -40
