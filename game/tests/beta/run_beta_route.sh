#!/usr/bin/env bash
# Percurso do beta no cliente real (docs/beta-checklist.md): personagem novo → título no Campo de Treino →
# Porto → Campos → Mata → Chapada → volta ao Porto, com luta, drop, XP, morte e renascimento em cada mapa,
# lição de Mestre cumprida caçando, chefe do covil, noite com a forma atroz e a provação do ancião no Porto.
# Servidor --dev-commands (saves e estado próprios, apagados no fim) + cliente com janela (xvfb, 1280x720).
# Uso: GODOT=/caminho/godot [OUT=.work/beta] [PORT=8391] xvfb-run -a game/tests/beta/run_beta_route.sh
#   (sem xvfb-run por fora ele mesmo chama xvfb-run). Código 0 = todas as verificações passaram.
set -uo pipefail
GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$(cd "$GAME_DIR/.." && pwd)/.work/beta}"
PORT="${PORT:-8491}"
TMP="$(mktemp -d)"
mkdir -p "$TMP/saves" "$TMP/state" "$OUT"
rm -f "$OUT"/[0-9][0-9]_*.png
NAME="BetaRota$((RANDOM % 900 + 100))"
"$GODOT" --headless --path "$GAME_DIR" -- --server --port="$PORT" --save-dir="$TMP/saves" --state-dir="$TMP/state" \
	--dev-commands --drop-chance-mult=50 >"$TMP/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null; wait $SP 2>/dev/null' EXIT
sleep 4
CLIENT=("$GODOT" --path "$GAME_DIR" --resolution 1280x720)
if [[ -z "${DISPLAY:-}" ]]; then
	CLIENT=(xvfb-run -a -s "-screen 0 1280x720x24" "${CLIENT[@]}")
fi
timeout 1600 "${CLIENT[@]}" -- --name="$NAME" --body=female --port="$PORT" \
	--autotest --autotest-script="${CLIENT_SCRIPT:-res://tests/beta/beta_route_client.gd}" --shot-dir="$OUT" >"$TMP/client.log" 2>&1
RC=$?
cp "$TMP/client.log" "$OUT/route_client.log"
cp "$TMP/server.log" "$OUT/route_server.log"
grep -h "beta_route_check" "$TMP/client.log" | sed -E 's/^\[client\] beta_route_check //' | python3 -c '
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
    except Exception:
        continue
    print("  [%s] %-18s %s %s" % ("pass" if d["pass"] else "FAIL", d["map"], d["check"], "" if d["pass"] else d["detail"]))
'
grep -h "beta_route_done" "$TMP/client.log"
if grep -qE "SCRIPT ERROR|Parse Error" "$TMP/client.log" "$TMP/server.log"; then
	RC=1
	echo "  erros de script:"; grep -hE "SCRIPT ERROR|Parse Error" -A2 "$TMP/client.log" "$TMP/server.log" | head -20
fi
grep -q 'beta_route_done .*"failed":\[\]' "$TMP/client.log" || RC=1
echo "capturas em $OUT; logs em $OUT/route_*.log"
rm -rf "$TMP"
[[ $RC -eq 0 ]] && echo "BETA ROUTE: PASS" || echo "BETA ROUTE: FAIL (rc=$RC)"
exit $RC
