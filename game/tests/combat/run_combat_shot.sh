#!/usr/bin/env bash
# Captura de uma luta (xvfb): servidor headless + cliente em janela no papel "shot"
# (tests/combat/combat_autotest.gd), que ataca um monstro e grava PNGs em OUT.
# Uso: GODOT=/caminho/godot OUT=/tmp/shots [PORT=7931] [TRAINING=1] tests/combat/run_combat_shot.sh
#   padrão: cidade como arena com os monstros de teste (--combat-fixtures);
#   TRAINING=1: Campo de Treino com os monstros reais de W (personagem novo entra no treino).
#   RARE=all (ou ids separados por vírgula): monstros nascem na variante rara (Agente R).
set -uo pipefail
GODOT="${GODOT:-godot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P="$HERE/../.."
PORT="${PORT:-7931}"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
SERVER_ARGS=(--server --port="$PORT" --combat-fixtures)
if [[ -n "${RARE:-}" ]]; then SERVER_ARGS+=(--force-rare="$RARE"); fi
if [[ "${TRAINING:-0}" == "1" ]]; then
	SERVER_ARGS+=(--save-dir="$OUT/saves")
else
	SERVER_ARGS+=(--autotest)
fi
"$GODOT" --headless --path "$P" -- "${SERVER_ARGS[@]}" >"$OUT/server.log" 2>&1 & SP=$!
sleep 3
xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path "$P" --resolution 1280x720 -- \
	--name="Shooter$RANDOM" --body=female --port="$PORT" --combat-fixtures --combat-autotest \
	--combat-role=shot --shot-dir="$OUT" >"$OUT/shot.log" 2>&1 & CP=$!
wait "$CP"; RC=$?
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
echo "=== capturas em $OUT (rc=$RC)"
grep -h 'combat_check\|combat_result\|shot_target' "$OUT/shot.log"
exit $RC
