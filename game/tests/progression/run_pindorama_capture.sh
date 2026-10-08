#!/usr/bin/env bash
# Capturas no cliente real da Terra de Pindorama (anciãos sem/com títulos, Mestre Taquari, árvore do arco).
# Servidor --dev-commands com save de teste próprio (QVitrine, nível 10, na cidade) + cliente com janela.
# Uso: GODOT=/caminho/godot [OUT=.work/servidor] xvfb-run -a game/tests/progression/run_pindorama_capture.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$(cd "$GAME_DIR/.." && pwd)/.work/servidor}"
TMP="$(mktemp -d)"
mkdir -p "$TMP/saves" "$OUT"
cat > "$TMP/saves/qvitrine.json" <<'JSON'
{"format": 1, "name": "QVitrine", "body": "male", "level": 10, "attributes": {}, "hp": 300, "mp": 100,
 "stars": 150, "inventory": [], "equipment": {}, "once_flags": []}
JSON
"$GODOT" --headless --path "$GAME_DIR" -- --server --port="${PORT:-8214}" --save-dir="$TMP/saves" --dev-commands \
	>"$TMP/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null' EXIT
sleep 4
timeout 240 "$GODOT" --path "$GAME_DIR" --resolution 1280x720 -- --name=QVitrine --body=male --port="${PORT:-8214}" \
	--autotest --autotest-script=res://tests/progression/pindorama_capture.gd --shot-dir="$OUT" >"$TMP/client.log" 2>&1
RC=$?
# Provação das mudas: personagem novo no Campo de Treino (zona com combate).
timeout 240 "$GODOT" --path "$GAME_DIR" --resolution 1280x720 -- --name=QMudas --body=female --port="${PORT:-8214}" \
	--autotest --autotest-script=res://tests/progression/pindorama_capture.gd --pindorama-role=trial --shot-dir="$OUT" \
	>"$TMP/client_trial.log" 2>&1
RC2=$?
[[ $RC -eq 0 ]] && RC=$RC2
grep -h "pindorama_capture_check\|pindorama_capture_done" "$TMP/client.log" "$TMP/client_trial.log" | sed -E 's/,"text".*//'
echo "logs em $TMP; capturas em $OUT"
exit $RC
