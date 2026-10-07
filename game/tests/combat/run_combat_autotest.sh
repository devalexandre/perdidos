#!/usr/bin/env bash
# Autoteste do combate (Agente K): servidor headless com dados de teste (--combat-fixtures) +
# cliente "hero" + cliente "victim" (tests/combat/combat_autotest.gd) + testes de fórmulas.
# A cidade vira arena só em memória (combat_allowed = true) e ganha Spawns/ de teste.
#
# Uso:   GODOT=/caminho/godot tests/combat/run_combat_autotest.sh
#        PORT=7911 LOG_DIR=/tmp/x tests/combat/run_combat_autotest.sh
# Código de saída 0 = tudo passou. Mata só os processos que ele mesmo abriu.
set -uo pipefail
GODOT="${GODOT:-godot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P="$HERE/../.."
PORT="${PORT:-7911}"
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT

"$GODOT" --headless --path "$P" -- --server --port="$PORT" --autotest --combat-fixtures \
	--force-rare=test_critter --always-hit >"$LOG_DIR/server.log" 2>&1 &
SP=$!; PIDS+=($SP)
sleep 3
"$GODOT" --headless --path "$P" -- --name=Hero --body=female --port="$PORT" --combat-fixtures \
	--combat-autotest --combat-role=hero >"$LOG_DIR/hero.log" 2>&1 &
HP=$!; PIDS+=($HP)
sleep 1
"$GODOT" --headless --path "$P" -- --name=Victim --body=male --port="$PORT" --combat-fixtures \
	--combat-autotest --combat-role=victim >"$LOG_DIR/victim.log" 2>&1 &
VP=$!; PIDS+=($VP)
wait "$HP"; HRC=$?
wait "$VP"; VRC=$?
sleep 1
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null

echo "=== logs em $LOG_DIR"
echo "=== checks dos clientes"
grep -h 'combat_check' "$LOG_DIR/hero.log" "$LOG_DIR/victim.log" \
	| sed -E 's/^\[client\] combat_check //' \
	| python3 -c '
import sys, json
for line in sys.stdin:
    d = json.loads(line)
    st = "pass" if d["pass"] else "FAIL"
    extra = "" if d["pass"] else json.dumps(d.get("detail"), ensure_ascii=False)
    print("  [%-4s] %-6s %s %s" % (st, d["role"], d["check"], extra))
'
fail=0
need() { # need <arquivo> <padrão> <descrição>
	if grep -qE -- "$2" "$1"; then echo "  [pass] $3"; else echo "  [FAIL] $3"; fail=1; fi
}
S="$LOG_DIR/server.log"
need "$LOG_DIR/hero.log" 'combat_result .*"pass":true' "cliente hero terminou o roteiro"
need "$LOG_DIR/victim.log" 'combat_result .*"pass":true' "cliente victim terminou o roteiro"
echo "=== servidor"
need "$S" '"reason":"attack_other_instance"' "ataque a monstro de outra instância recusado"
need "$S" '"reason":"attack_target_dead"' "ataque a alvo morto recusado"
need "$S" '"reason":"attack_out_of_range"' "ataque fora de alcance recusado"
need "$S" '"reason":"action_while_dead"' "ação com o jogador morto recusada"
need "$S" 'monster_killed .*"monster":"test_critter".*"xp":12' "criatura morta dá a XP do estágio (evento monster_killed)"
need "$S" 'drop_picked ' "item pego do chão"
need "$S" 'monster_returned .*"monster":"test_sturdy"' "IA: monstro voltou à origem e recuperou a vida"
need "$S" 'player_killed .*"killer":2' "jogador morto por monstro (evento player_killed)"
if grep -qE 'monster_absorbed_xp|monster_evolved' "$S"; then echo "  [FAIL] monstro evoluiu (não há mais evolução)"; fail=1; else echo "  [pass] sem evolução: quem mata jogador não absorve XP nem muda de estágio"; fi
need "$S" 'player_revived' "jogador renasceu"
echo "=== sorte e acerto (Agente R, GDD §10.2)"
need "$S" 'monster_rare_spawned .*"monster":"test_critter"' "criatura rara forçada (--force-rare) nasceu rara"
need "$S" 'monster_killed .*"monster":"test_critter".*"rare":true' "criatura rara derrotada (drops melhores)"
need "$S" 'combat_miss .*"source":"basic_attack"' "golpe físico errado no esquivo (DES alta; --always-hit no resto)"
if grep -qE 'SCRIPT ERROR|Parse Error' "$LOG_DIR"/*.log; then
	echo "  [FAIL] erros de script nos logs:"; grep -hE 'SCRIPT ERROR|Parse Error' -A3 "$LOG_DIR"/*.log | head -30; fail=1
fi
echo "=== fórmulas (tests/combat/test_formulas.tscn)"
if "$GODOT" --headless --path "$P" res://tests/combat/test_formulas.tscn >"$LOG_DIR/formulas.log" 2>&1 \
		&& grep -q 'RESULT: PASS' "$LOG_DIR/formulas.log"; then
	echo "  [pass] $(grep 'test_combat_formulas:' "$LOG_DIR/formulas.log")"
else
	echo "  [FAIL] fórmulas (ver $LOG_DIR/formulas.log)"; grep FAIL "$LOG_DIR/formulas.log" | head; fail=1
fi
echo "=== resultado: hero rc=$HRC victim rc=$VRC"
if [[ $HRC -ne 0 || $VRC -ne 0 || $fail -ne 0 ]]; then echo "COMBAT AUTOTEST: FAIL"; exit 1; fi
echo "COMBAT AUTOTEST: PASS"
