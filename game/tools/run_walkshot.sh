#!/usr/bin/env bash
# Captura em janela (xvfb) do movimento por células (GDD §10.1): servidor headless + cliente
# "walkshot" (anda na diagonal, em reta e segurando o botão, com cliques de mouse de verdade) +
# cliente "watcher" (vê o outro andar). PNGs em OUT; confere a sincronia com check_move_sync.py.
# Uso: GODOT=/caminho/godot OUT=/tmp/shots tools/run_walkshot.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P="$TOOLS_DIR/.."
PORT="${PORT:-7863}"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
XV=(xvfb-run -a -s "-screen 0 1600x900x24")
"$GODOT" --headless --path "$P" -- --server --port="$PORT" --autotest --test-fixtures >"$OUT/server.log" 2>&1 & SP=$!
sleep 3
"${XV[@]}" "$GODOT" --path "$P" --resolution 1440x810 -- --name=Walker --body=female --port="$PORT" \
	--autotest --autotest-role=walkshot --shot-dir="$OUT" --test-fixtures >"$OUT/walkshot.log" 2>&1 & WP=$!
"${XV[@]}" "$GODOT" --path "$P" --resolution 1440x810 -- --name=Watcher --body=male --port="$PORT" \
	--autotest --autotest-role=watcher --shot-dir="$OUT" --test-fixtures >"$OUT/watcher.log" 2>&1 & VP=$!
wait "$WP"; wait "$VP"
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
echo "=== capturas em $OUT"
grep -h 'autotest_result' "$OUT/walkshot.log" "$OUT/watcher.log"
python3 "$TOOLS_DIR/check_move_sync.py" "$OUT/server.log" "$OUT/walkshot.log" "$OUT/watcher.log" --max-error=0.2
