#!/usr/bin/env bash
# Autoteste do fluxo de chegada (Agente N; contrato arrival, testes "N"):
#   servidor (--autotest --training-flow --world-debug) + save antigo "Bia" (sem left_training) +
#   cliente "Nova" (personagem novo, aparência personalizada: treino → portal → cidade) +
#   cliente "Bia" (entra direto na cidade e vê a Nova personalizada) + "Nova" de novo (relog na cidade).
# Com SHOTS=1 os clientes rodam em janela (xvfb) e gravam PNGs (minimapa, mapa grande, cidade).
# Uso: GODOT=/caminho/godot [SHOTS=1] [PORT=8111] [LOG_DIR=/tmp/x] tests/world/run_world_test.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${PORT:-8111}"
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
SAVES="$LOG_DIR/saves"
mkdir -p "$SAVES"
SCRIPT=res://tests/world/world_flow_test.gd
APPEARANCE="skin:3,hair_style:bob,hair_color:4,eye_color:2,earrings:hoop"
CLIENT_A=("$GODOT" --headless --path "$P")
CLIENT_B=("$GODOT" --headless --path "$P")
if [[ "${SHOTS:-0}" == "1" ]]; then
	# Um display fixo por cliente (com -a os dois xvfb-run podem disputar o mesmo número).
	CLIENT_A=(xvfb-run -n $((PORT + 70)) -s "-screen 0 1600x900x24" "$GODOT" --path "$P" --resolution 1280x720)
	CLIENT_B=(xvfb-run -n $((PORT + 71)) -s "-screen 0 1600x900x24" "$GODOT" --path "$P" --resolution 1280x720)
fi
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT

"$GODOT" --headless --path "$P" -- --server --port="$PORT" --autotest --training-flow --world-debug \
	--save-dir="$SAVES" >"$LOG_DIR/server.log" 2>&1 &
PIDS+=($!); SERVER_PID=$!
sleep 3
# Save do marco anterior (sem left_training/appearance): tem de entrar direto na cidade.
cat >"$SAVES/bia.json" <<'JSON'
{"format": 1, "name": "Bia", "body": "male", "level": 3, "attributes": {}, "hp": 60, "mp": 30,
 "stars": 150, "inventory": [], "equipment": {}, "once_flags": []}
JSON
"${CLIENT_A[@]}" -- --name=Bia --body=male --port="$PORT" --autotest --autotest-script="$SCRIPT" \
	--autotest-role=veteran --watch-name=Nova --shot-dir="$LOG_DIR" >"$LOG_DIR/veteran.log" 2>&1 &
PIDS+=($!); VET_PID=$!
"${CLIENT_B[@]}" -- --name=Nova --body=female --port="$PORT" --autotest --autotest-script="$SCRIPT" \
	--autotest-role=newbie --appearance="$APPEARANCE" --shot-dir="$LOG_DIR" >"$LOG_DIR/newbie.log" 2>&1 &
PIDS+=($!); NEW_PID=$!
wait "$NEW_PID"; NEW_RC=$?
wait "$VET_PID"; VET_RC=$?
# Dá tempo do servidor registrar a saída da Nova (senão "nome em uso").
sleep 5
timeout 60 "$GODOT" --headless --path "$P" -- --name=Nova --body=female --port="$PORT" --autotest \
	--autotest-script="$SCRIPT" --autotest-role=relog >"$LOG_DIR/relog.log" 2>&1 &
PIDS+=($!); REL_PID=$!
wait "$REL_PID"; REL_RC=$?
sleep 1
kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null

echo "=== logs em $LOG_DIR"
grep -h 'autotest_check' "$LOG_DIR"/{newbie,veteran,relog}.log | sed -E 's/^\[client\] autotest_check //' \
	| python3 -c '
import sys, json
for line in sys.stdin:
    d = json.loads(line)
    st = "SKIP" if "skip" in d else ("pass" if d["pass"] else "FAIL")
    extra = d.get("skip") or ("" if d.get("pass") else d.get("detail"))
    print("  [%-4s] %-8s %s %s" % (st, d["role"], d["check"], extra))
'
fail=0
need() { if grep -q -- "$2" "$1"; then echo "  [pass] $3"; else echo "  [FAIL] $3"; fail=1; fi; }
echo "=== servidor"
need "$LOG_DIR/server.log" '"xp_allowed":false' "teto de XP: nível 10 no treino não ganha XP"
need "$LOG_DIR/server.log" '"reason":"portal_without_title"' "portal sem título recusado"
need "$LOG_DIR/server.log" 'training_exit.*"removed":\[[^]]*wooden_staff (weapon)' "itens do treino removidos na saída (inventário e equipamento)"
need "$LOG_DIR/server.log" 'character_created.*"hair_style":"bob"' "aparência validada e salva na criação"
need "$LOG_DIR/server.log" 'entry_map_chosen.*"map":"city_awakening","name":"Bia"' "save antigo vai para a cidade"
if grep -qE 'SCRIPT ERROR|Parse Error' "$LOG_DIR"/*.log; then
	echo "  [FAIL] erros de script:"; grep -hE 'SCRIPT ERROR|Parse Error' -A2 "$LOG_DIR"/*.log | head -20; fail=1
fi
ls "$LOG_DIR"/*.png 2>/dev/null | sed 's/^/  foto: /'
echo "  newbie rc=$NEW_RC veteran rc=$VET_RC relog rc=$REL_RC"
if [[ $NEW_RC -ne 0 || $VET_RC -ne 0 || $REL_RC -ne 0 || $fail -ne 0 ]]; then echo "WORLD TEST: FAIL"; exit 1; fi
echo "WORLD TEST: PASS"
