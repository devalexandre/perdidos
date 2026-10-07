#!/usr/bin/env bash
# Captura do combate vivo (Agente A, GDD §10.2.1) em janela (xvfb): servidor headless com os dados de
# teste e os comandos de debug (--progression-autotest) + cliente "anim_shot" que luta desarmado, com
# facão e com cajado e conjura uma skill mágica, gravando rajadas de quadros (70 ms) em OUT.
# Uso: GODOT=/caminho/godot OUT=/tmp/shots [PORT=7951] [BODY=female] tests/combat/run_combat_anim_shot.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P="$HERE/../.."
PORT="${PORT:-7951}"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --autotest --combat-fixtures \
	--progression-autotest --always-hit >"$OUT/server.log" 2>&1 & SP=$!
sleep 3
xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path "$P" --resolution 1280x720 -- \
	--name="Anim$RANDOM" --body="${BODY:-female}" --port="$PORT" --combat-fixtures --combat-autotest \
	--combat-role=anim_shot --shot-dir="$OUT" >"$OUT/anim_shot.log" 2>&1 & CP=$!
wait "$CP"; RC=$?
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
echo "=== capturas em $OUT (rc=$RC)"
grep -h 'combat_check\|combat_result' "$OUT/anim_shot.log"
exit $RC
