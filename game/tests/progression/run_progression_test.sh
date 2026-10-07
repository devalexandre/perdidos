#!/usr/bin/env bash
# Teste da progressão (Agente Q): servidor + 1 cliente em --progression-autotest.
# Uso:   GODOT=/caminho/godot tests/progression/run_progression_test.sh
#        HEADLESS=1 ...   (sem janela: pula as capturas)
#        PORT=8010 LOG_DIR=/tmp/x SHOT_DIR=/tmp/x/shots ...
# Com janela precisa de display (use xvfb-run -a no CI). Código de saída 0 = tudo passou.
set -uo pipefail
GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${PORT:-8010}"
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
SHOT_DIR="${SHOT_DIR:-$LOG_DIR/shots}"
SAVE_DIR="$LOG_DIR/saves"
NAME="${NAME:-QTester}"
mkdir -p "$SHOT_DIR" "$SAVE_DIR"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT

"$GODOT" --headless --path "$GAME_DIR" -- --server --port="$PORT" --save-dir="$SAVE_DIR" \
	--progression-autotest --always-hit --dev-commands >"$LOG_DIR/server.log" 2>&1 &
SERVER_PID=$!; PIDS+=($SERVER_PID)
sleep 3
CLIENT=("$GODOT" --path "$GAME_DIR" --resolution 1280x720)
if [[ "${HEADLESS:-0}" == "1" ]]; then CLIENT=("$GODOT" --headless --path "$GAME_DIR"); fi
"${CLIENT[@]}" -- --name="$NAME" --port="$PORT" --progression-autotest --q-shots="$SHOT_DIR" \
	>"$LOG_DIR/client.log" 2>&1 &
CLIENT_PID=$!; PIDS+=($CLIENT_PID)
wait "$CLIENT_PID"; CLIENT_RC=$?
sleep 3
kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null

echo "=== logs em $LOG_DIR"
echo "=== checks do cliente"
grep -h 'q_check' "$LOG_DIR/client.log" | sed -E 's/^\[client\] q_check //' | python3 -c '
import sys, json
for line in sys.stdin:
    d = json.loads(line)
    extra = "" if d["pass"] else json.dumps(d.get("detail"), ensure_ascii=False)[:300]
    print("  [%-4s] %s %s" % ("pass" if d["pass"] else "FAIL", d["check"], extra))
'
fail=0
[[ $CLIENT_RC -eq 0 ]] || fail=1
grep -q '"pass":true' <(grep q_result "$LOG_DIR/client.log") || fail=1
echo "=== servidor"
python3 - "$LOG_DIR/server.log" "$SAVE_DIR" "$NAME" <<'PY' || fail=1
import sys, json, re, os, glob
log, save_dir, name = sys.argv[1], sys.argv[2], sys.argv[3]
resolved = {}
for line in open(log, errors="replace"):
    m = re.match(r"\[server\] skill_resolved (\{.*\})", line.strip())
    if m:
        d = json.loads(m.group(1))
        resolved.setdefault(d["type"], 0)
        resolved[d["type"]] = max(resolved[d["type"]], d["hits"])
ok = True
for t in ["SINGLE", "GROUND_AREA", "SELF_AREA", "CONE", "LINE", "SELF", "ALLY_OR_SELF"]:
    good = resolved.get(t, 0) >= 1
    ok &= good
    print("  [%s] skill do tipo %s resolvida com alvo (hits=%s)" % ("pass" if good else "FAIL", t, resolved.get(t, 0)))
errors = [l for l in open(log, errors="replace") if "SCRIPT ERROR" in l]
print("  [%s] sem SCRIPT ERROR no servidor (%d)" % ("pass" if not errors else "FAIL", len(errors)))
ok &= not errors
path = os.path.join(save_dir, name.lower() + ".json")
try:
    s = json.load(open(path))
    p = s.get("progression", {})
    good = s.get("level") == 10 and "blade_firm_strike" in p.get("skills", {}) \
        and "sabia_blade_machete" in p.get("titles", {}) and "tf_blade_title" in p.get("quests_done", {}) \
        and len(p.get("hotbar", [])) == 10
except Exception as e:
    good = False
print("  [%s] save JSON com a progressão (nível, skills, títulos, quests, barra)" % ("pass" if good else "FAIL"))
ok &= good
try:
    good = s.get("format", 0) >= 2 and s.get("attributes", {}).get("luk") == 7
except Exception:
    good = False
print("  [%s] save JSON com a Sorte (SOR 5 + 2 pontos; formato >= 2)" % ("pass" if good else "FAIL"))
ok &= good
talks = sum(1 for l in open(log, errors="replace") if "title_talk " in l)
print("  [%s] conversa de título no nível 10 registrada no servidor (%d)" % ("pass" if talks >= 3 else "FAIL", talks))
ok &= talks >= 3
sys.exit(0 if ok else 1)
PY
if grep -q "SCRIPT ERROR" "$LOG_DIR/client.log"; then echo "  [FAIL] SCRIPT ERROR no cliente"; fail=1; fi
echo "=== migração do save (Sorte, tests/progression/test_save_migration.tscn)"
if "$GODOT" --headless --path "$GAME_DIR" res://tests/progression/test_save_migration.tscn >"$LOG_DIR/migration.log" 2>&1 \
		&& grep -q 'RESULT: PASS' "$LOG_DIR/migration.log"; then
	echo "  [pass] $(grep 'test_save_migration:' "$LOG_DIR/migration.log")"
else
	echo "  [FAIL] migração do save (ver $LOG_DIR/migration.log)"; grep FAIL "$LOG_DIR/migration.log" | head; fail=1
fi
echo "=== fórmulas de conjuração/recarga (GDD §8.1, tests/progression/test_cast_timing.tscn)"
if "$GODOT" --headless --path "$GAME_DIR" res://tests/progression/test_cast_timing.tscn >"$LOG_DIR/cast_timing.log" 2>&1 \
		&& grep -q 'RESULT: PASS' "$LOG_DIR/cast_timing.log"; then
	echo "  [pass] $(grep 'test_cast_timing:' "$LOG_DIR/cast_timing.log")"
else
	echo "  [FAIL] fórmulas de tempo de uso (ver $LOG_DIR/cast_timing.log)"; grep FAIL "$LOG_DIR/cast_timing.log" | head; fail=1
fi
echo "=== Terra do Sabiá: árvores, anciãos, variantes e mecânicas (tests/progression/test_sabia_trees.tscn)"
if "$GODOT" --headless --path "$GAME_DIR" res://tests/progression/test_sabia_trees.tscn >"$LOG_DIR/sabia_trees.log" 2>&1 \
		&& grep -q 'RESULT: PASS' "$LOG_DIR/sabia_trees.log"; then
	echo "  [pass] $(grep 'test_sabia_trees:' "$LOG_DIR/sabia_trees.log")"
else
	echo "  [FAIL] árvores do Sabiá (ver $LOG_DIR/sabia_trees.log)"; grep FAIL "$LOG_DIR/sabia_trees.log" | head -20; fail=1
fi
echo "=== capturas em $SHOT_DIR"; ls "$SHOT_DIR" 2>/dev/null | sed 's/^/  /'
[[ $fail -eq 0 ]] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $fail
