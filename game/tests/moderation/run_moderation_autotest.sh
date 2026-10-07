#!/usr/bin/env bash
# Autoteste de moderação do chat (docs/moderacao.md): testes de unidade do filtro/sanções +
# servidor real + cliente headless que insiste em palavrões até ser bloqueado, e depois entra de
# novo com o mesmo nome (o bloqueio continua). Mata só os processos que criou.
#
# Uso:   GODOT=/caminho/godot game/tests/moderation/run_moderation_autotest.sh
#        PORT=8391 LOG_DIR=/tmp/x game/tests/moderation/run_moderation_autotest.sh
# Código de saída 0 = tudo passou.
set -uo pipefail
GODOT="${GODOT:-godot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$HERE/../.." && pwd)"
PORT="${PORT:-8391}"
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
NAME="${MOD_NAME:-Boca}"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT
fail=0

echo "=== testes de unidade (filtro + sanções com relógio falso)"
if "$GODOT" --headless --path "$GAME_DIR" res://tests/moderation/test_moderation.tscn >"$LOG_DIR/unit.log" 2>&1 \
		&& grep -q 'RESULT: PASS' "$LOG_DIR/unit.log"; then
	echo "  [pass] $(grep 'test_moderation:' "$LOG_DIR/unit.log") ($(grep -o 'filter avg.*' "$LOG_DIR/unit.log"))"
else
	echo "  [FAIL] test_moderation (ver $LOG_DIR/unit.log)"; grep 'FAIL' "$LOG_DIR/unit.log" | head -20; fail=1
fi

echo "=== servidor + cliente (spam -> strike -> bloqueio -> mensagem recusada -> reentrada)"
"$GODOT" --headless --path "$GAME_DIR" -- --server --port="$PORT" --autotest >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!); SERVER_PID=$!
sleep 3
run_client() { # run_client <fase> <log>
	"$GODOT" --headless --path "$GAME_DIR" res://tests/moderation/live_client.tscn -- \
		--name="$NAME" --body=male --port="$PORT" --mod-phase="$1" >"$LOG_DIR/$2" 2>&1 &
	local pid=$!; PIDS+=($pid); wait "$pid"; return $?
}
run_client spam client_spam.log; SPAM_RC=$?
sleep 2
run_client relogin client_relogin.log; RELOGIN_RC=$?
sleep 1
kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null

for f in client_spam.log client_relogin.log; do
	grep -h '^moderation_check' "$LOG_DIR/$f" | sed 's/^moderation_check //' | python3 -c '
import sys, json
for line in sys.stdin:
    d = json.loads(line)
    print("  [%-4s] %s %s" % ("pass" if d["pass"] else "FAIL", d["check"], "" if d["pass"] else d["detail"]))
'
done
need() { if grep -q -- "$2" "$1"; then echo "  [pass] $3"; else echo "  [FAIL] $3"; fail=1; fi; }
echo "=== servidor/logs"
need "$LOG_DIR/server.log" '"action":"warning"' "strike 1 = aviso"
need "$LOG_DIR/server.log" '"action":"mute"' "strike 2 = bloqueio"
need "$LOG_DIR/server.log" '"reason":"chat_muted"' "mensagem de jogador bloqueado recusada"
if grep -q '"text":"[^"]*porra' "$LOG_DIR/server.log"; then
	echo "  [FAIL] texto sem filtro no log do servidor"; fail=1
else
	echo "  [pass] log do servidor só com texto filtrado"
fi
if grep -qE 'SCRIPT ERROR|Parse Error' "$LOG_DIR"/*.log; then
	echo "  [FAIL] erros de script:"; grep -hE 'SCRIPT ERROR|Parse Error' -A2 "$LOG_DIR"/*.log | head -20; fail=1
fi
echo "=== resultado (logs em $LOG_DIR)"
echo "  spam rc=$SPAM_RC relogin rc=$RELOGIN_RC"
if [[ $SPAM_RC -ne 0 || $RELOGIN_RC -ne 0 || $fail -ne 0 ]]; then
	echo "MODERATION AUTOTEST: FAIL"; exit 1
fi
echo "MODERATION AUTOTEST: PASS"
