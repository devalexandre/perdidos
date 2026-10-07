#!/usr/bin/env bash
# Autoteste da troca entre personagens (pedido do dono em 30/09/2026): servidor + 2 clientes reais no Porto
# (TAna e TBia), com janela (xvfb) para as capturas em .work/troca/. Ver tests/trade/trade_client.gd.
# Uso: GODOT=/caminho/godot [OUT=.work/troca] [PORT=8481] [SHOTS=1] game/tests/trade/run_trade_test.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$(cd "$GAME_DIR/.." && pwd)/.work/troca}"
PORT="${PORT:-8481}"
NAMES="TAna,TBia"
TMP="$(mktemp -d)"
mkdir -p "$TMP/saves" "$TMP/state" "$TMP/sync" "$OUT"
for n in TAna TBia; do
	low=$(echo "$n" | tr '[:upper:]' '[:lower:]')
	cat >"$TMP/saves/$low.json" <<JSON
{"format": 1, "name": "$n", "body": "female", "level": 5, "attributes": {}, "hp": 200, "mp": 60,
 "stars": 150, "inventory": [], "equipment": {}, "once_flags": [], "left_training": true, "home_map": "city_awakening"}
JSON
done
"$GODOT" --headless --path "$GAME_DIR" -- --server --port="$PORT" --save-dir="$TMP/saves" \
	--state-dir="$TMP/state" --dev-commands >"$TMP/server.log" 2>&1 &
SP=$!
sleep 4
PIDS=()
i=0
for role in ana bia; do
	if [[ "${SHOTS:-1}" == "1" ]]; then
		cmd=(xvfb-run -n "$((PORT + 20 + i))" -s "-screen 0 1280x720x24" "$GODOT" --path "$GAME_DIR" --resolution 1280x720)
	else
		cmd=("$GODOT" --headless --path "$GAME_DIR")
	fi
	name=$([[ $role == ana ]] && echo TAna || echo TBia)
	timeout 700 "${cmd[@]}" -- --name="$name" --body=$([[ $role == bia ]] && echo male || echo female) \
		--port="$PORT" --autotest --autotest-script=res://tests/trade/trade_client.gd --trade-role="$role" \
		--trade-names="$NAMES" --sync-dir="$TMP/sync" --shot-dir="$OUT" >"$TMP/$role.log" 2>&1 &
	PIDS+=($!)
	i=$((i + 1))
	sleep 1
done
RC=0
for p in "${PIDS[@]}"; do wait "$p" || RC=1; done
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
grep -h "trade_check" "$TMP"/{ana,bia}.log | sed -E 's/^\[client\] trade_check //'
grep -h "trade_done_test" "$TMP"/{ana,bia}.log | sed -E 's/^\[client\] //'
grep -h "SCRIPT ERROR" -A2 "$TMP"/*.log | head -20
DONE=$(grep -c '"trade_done"\|\] trade_done {' "$TMP/server.log")
LINES=$(wc -l <"$TMP/state/trades.jsonl" 2>/dev/null || echo 0)
echo "  servidor: trade_done no log = $DONE; linhas em trades.jsonl = $LINES"
[[ "$LINES" -ge 1 ]] || RC=1
for f in server ana bia; do cp "$TMP/$f.log" "$OUT/$f.log"; done
cp "$TMP/state/trades.jsonl" "$OUT/trades.jsonl" 2>/dev/null
rm -rf "$TMP"
if [[ $RC -eq 0 ]]; then echo "TRADE TEST: PASS"; exit 0; fi
echo "TRADE TEST: FAIL"; exit 1
