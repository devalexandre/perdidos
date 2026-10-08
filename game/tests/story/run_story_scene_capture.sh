#!/usr/bin/env bash
# Capturas do diário da história (aba Fragmentos, "Onde está Maria?") e da cena da fala da lenda no cliente real
# (tests/story/story_scene_capture.gd): servidor local + cliente com xvfb.
# Uso: GODOT=/caminho/godot [OUT=.work/story] [PORT=8574] [RES=1280x720] tests/story/run_story_scene_capture.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$P/../.work/story}"
PORT="${PORT:-8574}"
RES="${RES:-1280x720}"
TMP="$(mktemp -d)"
mkdir -p "$OUT" "$TMP/saves" "$TMP/state"
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --save-dir="$TMP/saves" --state-dir="$TMP/state" \
	>"$TMP/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; wait $SP 2>/dev/null' EXIT
sleep 4
xvfb-run -a -s "-screen 0 2000x1200x24" "$GODOT" --path "$P" --resolution "$RES" -- --name="Story$((RANDOM % 900 + 100))" \
	--body=female --port="$PORT" --autotest --autotest-script=res://tests/story/story_scene_capture.gd \
	--shot-dir="$OUT" >"$TMP/client.log" 2>&1
RC=$?
grep -h "story_capture\|SCRIPT ERROR" "$TMP/client.log" | head -20
echo "=== logs em $TMP (rc=$RC)"
exit $RC
