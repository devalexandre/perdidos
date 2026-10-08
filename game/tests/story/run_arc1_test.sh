#!/usr/bin/env bash
# Arco 1 em rede: covil do chefe da história (noite, 1 h, ritual sem duplicar, amanhecer, 1 por mapa) e crédito de
# história, com servidor --dev-commands e cliente headless (tests/story/arc1_client.gd), mais os testes unitários
# (tests/story/test_arc1.tscn). Uso: GODOT=/caminho/godot [PORT=8573] tests/story/run_arc1_test.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${PORT:-8573}"
TMP="$(mktemp -d)"
mkdir -p "$TMP/saves" "$TMP/state"
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --save-dir="$TMP/saves" --state-dir="$TMP/state" \
	--dev-commands >"$TMP/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; wait $SP 2>/dev/null' EXIT
sleep 4
timeout 600 "$GODOT" --headless --path "$P" -- --name="Arco$((RANDOM % 900 + 100))" --body=female --port="$PORT" \
	--autotest --autotest-script=res://tests/story/arc1_client.gd >"$TMP/client.log" 2>&1
RC=$?
echo "=== logs em $TMP"
grep -h "beta_route_check" "$TMP/client.log" | sed -E 's/^\[client\] beta_route_check //' | python3 -c '
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
    except Exception:
        continue
    print("  [%s] %-24s %s %s" % ("pass" if d["pass"] else "FAIL", d["map"], d["check"], "" if d["pass"] else d["detail"]))
'
echo "=== unitários"
"$GODOT" --headless --path "$P" res://tests/story/test_arc1.tscn 2>&1 | grep -E "^  FAIL|test_arc1:"
URC=${PIPESTATUS[0]}
if [[ $RC -eq 0 && $URC -eq 0 ]]; then echo "ARC1 TEST: PASS"; exit 0; fi
echo "ARC1 TEST: FAIL (cliente rc=$RC, unitários rc=$URC)"
exit 1
