#!/usr/bin/env bash
# Autoteste em rede de chefes, dia e noite e forma atroz (docs/chefes-dia-noite.md):
#   servidor (--autotest --combat-fixtures, limite de abates 3, drops garantidos) + cliente "HeroNight"
#   (tests/monsters/night_client_test.gd) + testes unitários (tests/monsters/test_night.tscn).
# Com SHOTS=1 o cliente roda em janela (xvfb) e grava fotos em $SHOT_DIR (padrão .work/monsters_night/).
# Uso: GODOT=/caminho/godot [SHOTS=1] [PORT=8171] [LOG_DIR=/tmp/x] tests/monsters/run_night_test.sh
# Código de saída 0 = tudo passou. Mata só os processos que ele mesmo abriu.
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${PORT:-8171}"
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
SHOT_DIR="${SHOT_DIR:-$P/../.work/monsters_night}"
mkdir -p "$LOG_DIR"
SCRIPT=res://tests/monsters/night_client_test.gd
CLIENT=("$GODOT" --headless --path "$P")
SHOT_ARGS=()
if [[ "${SHOTS:-0}" == "1" ]]; then
	mkdir -p "$SHOT_DIR"
	CLIENT=(xvfb-run -n $((PORT + 70)) -s "-screen 0 1600x900x24" "$GODOT" --path "$P" --resolution 1280x720)
	SHOT_ARGS=(--shot-dir="$SHOT_DIR")
fi
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT

"$GODOT" --headless --path "$P" -- --server --port="$PORT" --autotest --combat-fixtures --always-hit \
	--drop-chance-mult=10 --save-dir="$LOG_DIR/saves" \
	>"$LOG_DIR/server.log" 2>&1 &
SP=$!; PIDS+=($SP)
sleep 3
"${CLIENT[@]}" -- --name=HeroNight --body=female --port="$PORT" --combat-fixtures --autotest \
	--autotest-script="$SCRIPT" "${SHOT_ARGS[@]}" >"$LOG_DIR/client.log" 2>&1 &
CP=$!; PIDS+=($CP)
wait "$CP"; CRC=$?
sleep 1
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null

echo "=== logs em $LOG_DIR"
echo "=== checks do cliente"
grep -h 'night_check' "$LOG_DIR/client.log" | sed -E 's/^\[client\] night_check //' | python3 -c '
import sys, json
for line in sys.stdin:
    d = json.loads(line)
    st = "pass" if d["pass"] else "FAIL"
    print("  [%-4s] %s %s" % (st, d["check"], "" if d["pass"] else d.get("detail", "")))
'
fail=0
need() { # need <arquivo> <padrão> <descrição>
	if grep -qE -- "$2" "$1"; then echo "  [pass] $3"; else echo "  [FAIL] $3"; fail=1; fi
}
S="$LOG_DIR/server.log"
echo "=== servidor"
need "$S" 'day_night_ready .*"night":false' "relógio começa de dia"
need "$S" 'boss_lairs_ready .*"bosses":1' "covil fixo de teste instalado (BossLairs/)"
need "$S" 'boss_escort_spawned .*"count":6,.*"monster":"test_critter"' "chefe do covil nasce com bando (4 + 2)"
need "$S" 'boss_lair_spawned .*"escort":6,.*"monster":"test_critter"' "chefe do covil renasce e o bando volta a segui-lo"
if [[ $(grep -c 'boss_lair_spawned .*"monster":"test_critter"' "$S") -ge 3 ]]; then echo "  [pass] covil renasce (respawn_sec do marcador)"; else echo "  [FAIL] covil não renasceu"; fail=1; fi
if grep -qE 'boss_kills|monster_evolved|monster_absorbed_xp' "$S"; then echo "  [FAIL] restos de evolução/contagem de abates"; fail=1; else echo "  [pass] sem evolução e sem contagem de abates"; fi
need "$S" 'kill_info_event \{"atroz":false,"boss":true,"form_stage":3,.*"monster":"test_critter","rare":false,"stage":3\}' "evento de abate do chefe (stage 3, boss)"
need "$S" 'day_night_force .*"night":true' "noite forçada pelo comando"
need "$S" 'monster_atroz \{.*"atroz":true,.*"monster":"stone_armadillo"' "chefe à noite virou atroz (ATQ e vida x2)"
need "$S" 'boss_spawned \{"atroz":true,.*"monster":"stone_armadillo"' "chefe que nasce de noite já nasce atroz"
need "$S" 'monster_atroz_call_escort \{"called":[1-9]' "atroz chamou o bando"
need "$S" 'monster_killed \{.*"atroz":true,.*"monster":"stone_armadillo".*"stage":3,' "abate da forma atroz (stage 3 + atroz)"
need "$S" 'kill_info_event \{"atroz":true,"boss":true,"form_stage":4,.*"monster":"stone_armadillo","rare":false,"stage":3\}' "evento de abate com stage/atroz/rare (QuestService)"
need "$S" 'drop_spawned .*"item":"ancient_shell_shard"' "atroz deixou o Caco de Casco Antigo"
need "$S" 'monster_atroz \{.*"atroz":true,.*"monster":"enchanted_firefly"' "chefe vivo virou atroz ao anoitecer"
if grep -qE 'SCRIPT ERROR|Parse Error' "$LOG_DIR"/*.log; then
	echo "  [FAIL] erros de script nos logs:"; grep -hE 'SCRIPT ERROR|Parse Error' -A3 "$LOG_DIR"/*.log | head -30; fail=1
fi
echo "=== unitários (tests/monsters/test_night.tscn)"
if "$GODOT" --headless --path "$P" res://tests/monsters/test_night.tscn >"$LOG_DIR/unit.log" 2>&1 \
		&& grep -q 'RESULT: PASS' "$LOG_DIR/unit.log"; then
	echo "  [pass] $(grep 'test_monsters_night:' "$LOG_DIR/unit.log")"
else
	echo "  [FAIL] unitários (ver $LOG_DIR/unit.log)"; grep FAIL "$LOG_DIR/unit.log" | head; fail=1
fi
echo "=== resultado: client rc=$CRC"
if [[ $CRC -ne 0 || $fail -ne 0 ]]; then echo "NIGHT AUTOTEST: FAIL"; exit 1; fi
echo "NIGHT AUTOTEST: PASS"
