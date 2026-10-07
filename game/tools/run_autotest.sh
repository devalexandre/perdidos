#!/usr/bin/env bash
# Autoteste headless completo do marco city-walk: servidor + 2 clientes (shopper e observer) +
# 1 cliente com protocolo errado. Imprime um resumo pass/fail e mata todos os processos.
#
# Uso:   GODOT=/caminho/godot tools/run_autotest.sh
#        FIXTURES=0 tools/run_autotest.sh   (só dados reais de data/, sem tests/server/fixtures)
#        PORT=7790 LOG_DIR=/tmp/x tools/run_autotest.sh
# Código de saída 0 = tudo passou.
set -uo pipefail
GODOT="${GODOT:-godot}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-7811}"
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
FIX=()
if [[ "${FIXTURES:-1}" == "1" ]]; then FIX=(--test-fixtures); fi
export GODOT HEADLESS=1
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT

"$TOOLS_DIR/run_server.sh" --port="$PORT" --autotest "${FIX[@]}" >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!); SERVER_PID=$!
sleep 3
"$TOOLS_DIR/run_client.sh" Ana female --port="$PORT" --autotest --autotest-role=shopper "${FIX[@]}" \
	>"$LOG_DIR/shopper.log" 2>&1 &
PIDS+=($!); SHOP_PID=$!
"$TOOLS_DIR/run_client.sh" Bia male --port="$PORT" --autotest --autotest-role=observer \
	--autotest-move=-8,-10 "${FIX[@]}" >"$LOG_DIR/observer.log" 2>&1 &
PIDS+=($!); OBS_PID=$!
"$TOOLS_DIR/run_client.sh" Old male --port="$PORT" --autotest-bad-protocol \
	>"$LOG_DIR/badproto.log" 2>&1 &
PIDS+=($!); BAD_PID=$!

wait "$SHOP_PID"; SHOP_RC=$?
wait "$OBS_PID"; OBS_RC=$?
wait "$BAD_PID"
# Dá tempo do servidor salvar/reler os saves dos logouts e encerra.
sleep 3
kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null

echo "=== logs em $LOG_DIR"
echo "=== checks"
grep -h 'autotest_check' "$LOG_DIR/shopper.log" "$LOG_DIR/observer.log" \
	| sed -E 's/^\[client\] autotest_check //' \
	| python3 -c '
import sys, json
for line in sys.stdin:
    d = json.loads(line)
    st = "SKIP" if "skip" in d else ("pass" if d["pass"] else "FAIL")
    extra = d.get("skip") or ("" if d.get("pass") else json.dumps(d.get("detail"), ensure_ascii=False))
    print("  [%-4s] %-8s %s %s" % (st, d["role"], d["check"], extra))
'
echo "=== servidor: recusas registradas (invalid_message)"
grep -o '"reason":"[a-z_]*"' "$LOG_DIR/server.log" | sort | uniq -c | sed 's/^/  /'
fail=0
need() { # need <arquivo> <padrão> <descrição>
	if grep -q -- "$2" "$1"; then echo "  [pass] $3"; else echo "  [FAIL] $3"; fail=1; fi
}
echo "=== servidor/logs"
need "$LOG_DIR/server.log" '"reason":"rate_limited"' "rate limit registrado"
need "$LOG_DIR/server.log" '"reason":"move_unreachable"' "movimento inválido recusado"
need "$LOG_DIR/server.log" '"reason":"shop_buy_not_enough_stars"' "compra sem Estrelas recusada"
need "$LOG_DIR/server.log" '"reason":"shop_sell_empty_slot"' "venda de espaço vazio recusada"
need "$LOG_DIR/server.log" '"reason":"chat_too_fast"' "spam de chat recusado"
need "$LOG_DIR/server.log" '"reason":"interact_target_invalid"' "interação com outra instância recusada"
need "$LOG_DIR/server.log" 'peer_rejected' "protocolo errado recusado"
need "$LOG_DIR/server.log" 'walk_grid_built' "grade de células construída (GDD §10.1)"
echo "=== movimento por células: cliente x caminho do servidor no mesmo instante (limite 0,2 m)"
if ! python3 "$TOOLS_DIR/check_move_sync.py" "$LOG_DIR/server.log" "$LOG_DIR/shopper.log" \
		"$LOG_DIR/observer.log" --max-error=0.2; then
	echo "  [FAIL] sincronia do movimento"; fail=1
fi
if [[ $(grep -c 'autotest_save_roundtrip.*"pass":true' "$LOG_DIR/server.log") -eq 2 ]]; then
	echo "  [pass] save JSON relido igual nos 2 logouts"
else
	echo "  [FAIL] save JSON relido igual nos 2 logouts"; fail=1
fi
need "$LOG_DIR/badproto.log" '"test":"protocol_mismatch_rejected"' "cliente de protocolo errado não entrou"
if grep -q '"pass":false' "$LOG_DIR/badproto.log" "$LOG_DIR/server.log"; then
	echo "  [FAIL] algum pass:false nos logs"; fail=1
fi
if grep -qE 'SCRIPT ERROR|Parse Error' "$LOG_DIR"/*.log; then
	echo "  [FAIL] erros de script nos logs:"; grep -hE 'SCRIPT ERROR|Parse Error' -A2 "$LOG_DIR"/*.log | head -20; fail=1
fi
echo "=== testes da grade (tests/grid/test_grid.tscn: A*, reprodução, grade do mapa)"
if "$GODOT" --headless --path "$TOOLS_DIR/.." res://tests/grid/test_grid.tscn >"$LOG_DIR/grid.log" 2>&1 \
		&& grep -q 'RESULT: PASS' "$LOG_DIR/grid.log"; then
	echo "  [pass] $(grep 'test_grid:' "$LOG_DIR/grid.log")"
else
	echo "  [FAIL] test_grid (ver $LOG_DIR/grid.log)"; fail=1
fi
echo "=== resultado"
echo "  shopper rc=$SHOP_RC observer rc=$OBS_RC"
grep -h 'autotest_result' "$LOG_DIR/shopper.log" "$LOG_DIR/observer.log" | sed 's/^/  /'
if [[ $SHOP_RC -ne 0 || $OBS_RC -ne 0 || $fail -ne 0 ]]; then
	echo "AUTOTEST: FAIL"; exit 1
fi
echo "AUTOTEST: PASS"
