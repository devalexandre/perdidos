#!/usr/bin/env bash
# Autoteste da Dona Ana (06/10/2026): servidor + cliente real. Fala com a Dona Ana do Porto e salva, vai à Serra
# Dourada, fala com a de lá e volta ao Porto pela opção dela; Sumidouro; Pergaminho e morte levam à cidade salva.
# Uso: GODOT=/caminho/godot [OUT=.work/dona_ana] [PORT=8511] [SHOTS=1] game/tests/waystone/run_waystone_test.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$(cd "$GAME_DIR/.." && pwd)/.work/dona_ana}"
PORT="${PORT:-8511}"
TMP="$(mktemp -d)"
mkdir -p "$TMP/saves" "$TMP/state" "$OUT"
cat >"$TMP/saves/anavia.json" <<JSON
{"format": 1, "name": "AnaVia", "body": "female", "level": 8, "attributes": {}, "hp": 300, "mp": 80,
 "stars": 150, "inventory": [], "equipment": {}, "once_flags": [], "left_training": true, "home_map": "city_awakening"}
JSON
"$GODOT" --headless --path "$GAME_DIR" -- --server --port="$PORT" --save-dir="$TMP/saves" \
	--state-dir="$TMP/state" --dev-commands >"$TMP/server.log" 2>&1 &
SP=$!
sleep 4
RC=0
cmd=("$GODOT" --headless --path "$GAME_DIR")
if [[ "${SHOTS:-1}" == "1" ]]; then
	cmd=(xvfb-run -n "$((PORT + 30))" -s "-screen 0 1280x720x24" "$GODOT" --path "$GAME_DIR" --resolution 1280x720)
fi
timeout 500 "${cmd[@]}" -- --name=AnaVia --body=female --port="$PORT" --autotest \
	--autotest-script=res://tests/waystone/waystone_client.gd --shot-dir="$OUT" >"$TMP/client.log" 2>&1 || RC=1
sleep 2
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
grep -h "waystone_check\|waystone_done" "$TMP/client.log" | sed -E 's/^\[client\] //'
grep -h "SCRIPT ERROR" -A2 "$TMP"/*.log | head -20
FLAGS=$(grep -o '"waystone[^"]*"' "$TMP/saves/anavia.json" | tr '\n' ' ')
echo "  save AnaVia: $FLAGS"
[[ "$FLAGS" == *waystone_save:city_awakening* ]] || RC=1
grep -h "waystone_\|player_respawned\|return_scroll" "$TMP/server.log" | sed -E 's/^\[server\] /  servidor: /' | head -20
for f in server client; do cp "$TMP/$f.log" "$OUT/$f.log"; done
rm -rf "$TMP"
if [[ $RC -eq 0 ]]; then echo "WAYSTONE TEST: PASS"; exit 0; fi
echo "WAYSTONE TEST: FAIL"; exit 1
