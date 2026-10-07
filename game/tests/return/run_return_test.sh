#!/usr/bin/env bash
# Autoteste do Pergaminho de Retorno (pedido do dono em 30/09/2026): servidor + cliente real.
#   novo:  personagem novo no Campo de Treino (kit com 3; não funciona no treino);
#   volta: save pronto no Porto (Campos, Mata, Chapada → Porto; combate; provação; barra; last_city no save).
# Uso: GODOT=/caminho/godot [OUT=.work/retorno] [PORT=8501] [SHOTS=1] game/tests/return/run_return_test.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$(cd "$GAME_DIR/.." && pwd)/.work/retorno}"
PORT="${PORT:-8501}"
TMP="$(mktemp -d)"
mkdir -p "$TMP/saves" "$TMP/state" "$OUT"
cat >"$TMP/saves/rvolta.json" <<JSON
{"format": 1, "name": "RVolta", "body": "female", "level": 8, "attributes": {}, "hp": 300, "mp": 80,
 "stars": 150, "inventory": [], "equipment": {}, "once_flags": [], "left_training": true, "home_map": "city_awakening"}
JSON
"$GODOT" --headless --path "$GAME_DIR" -- --server --port="$PORT" --save-dir="$TMP/saves" \
	--state-dir="$TMP/state" --dev-commands >"$TMP/server.log" 2>&1 &
SP=$!
sleep 4
RC=0
run() { # nome fase
	local cmd=("$GODOT" --headless --path "$GAME_DIR")
	if [[ "${SHOTS:-1}" == "1" ]]; then
		cmd=(xvfb-run -n "$((PORT + 30))" -s "-screen 0 1280x720x24" "$GODOT" --path "$GAME_DIR" --resolution 1280x720)
	fi
	timeout 500 "${cmd[@]}" -- --name="$1" --body=female --port="$PORT" --autotest \
		--autotest-script=res://tests/return/return_client.gd --return-phase="$2" --shot-dir="$OUT" >"$TMP/$2.log" 2>&1 || RC=1
}
run RNovo novo
run RVolta volta
sleep 2
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
grep -h "return_check\|return_combat_try" "$TMP"/{novo,volta}.log | sed -E 's/^\[client\] //'
grep -h "return_done" "$TMP"/{novo,volta}.log | sed -E 's/^\[client\] //'
grep -h "SCRIPT ERROR" -A2 "$TMP"/*.log | head -20
LAST=$(grep -o '"last_city": *"[^"]*"' "$TMP/saves/rvolta.json")
echo "  save RVolta: $LAST"
[[ "$LAST" == *city_awakening* ]] || RC=1
grep -h "return_scroll" "$TMP/server.log" | sed -E 's/^\[server\] /  servidor: /' | head -8
for f in server novo volta; do cp "$TMP/$f.log" "$OUT/$f.log"; done
rm -rf "$TMP"
if [[ $RC -eq 0 ]]; then echo "RETURN TEST: PASS"; exit 0; fi
echo "RETURN TEST: FAIL"; exit 1
