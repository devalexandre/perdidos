#!/usr/bin/env bash
# Capturas no cliente real de dia, noite, chefe e forma atroz (docs/chefes-dia-noite.md): Porto do Despertar e
# Campo de Treino (Terra do Sabiá). Servidor com --dev-commands; clientes em janela (xvfb) com
# tests/monsters/night_capture.gd. Depois monta pranchas lado a lado (chefe de dia | atroz de noite).
# Uso: GODOT=/caminho/godot [OUT=.work/monsters_night] [PORT=8181] [ONLY=covis] tests/monsters/run_night_capture.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$P/../.work/monsters_night}"
PORT="${PORT:-8181}"
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
SAVES="$LOG_DIR/saves"
mkdir -p "$OUT" "$SAVES"
SCRIPT=res://tests/monsters/night_capture.gd
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT

start_server() { # start_server <log> [args extras]
	local log="$1"; shift
	"$GODOT" --headless --path "$P" -- --server --port="$PORT" --dev-commands --save-dir="$SAVES" --state-dir="$LOG_DIR/state" "$@" \
		>"$LOG_DIR/$log" 2>&1 &
	SP=$!; PIDS+=($SP)
	sleep 3
}
# Save antigo (sem left_training): entra direto no Porto.
cat >"$SAVES/capporto.json" <<'JSON'
{"format": 1, "name": "CapPorto", "body": "female", "level": 12, "attributes": {}, "hp": 400, "mp": 60,
 "stars": 0, "inventory": [], "equipment": {}, "once_flags": []}
JSON
run_client() { # run_client <nome> <papel> <display> [args extras]
	local n="$1" role="$2" disp="$3"; shift 3
	xvfb-run -n "$disp" -s "-screen 0 1600x900x24" "$GODOT" --path "$P" --resolution 1280x720 -- --name="$n" \
		--body=female --port="$PORT" --autotest --autotest-script="$SCRIPT" --autotest-role="$role" \
		--shot-dir="$OUT" "$@" >"$LOG_DIR/$role.log" 2>&1
}
if [[ "${ONLY:-}" == "covis" ]]; then
	# Só os covis fixos da Chapada (Subida Vermelha): chefes de dia e formas atrozes à noite.
	start_server server_covis.log --combat-fixtures
	run_client HeroCovis covis $((PORT + 72)) --combat-fixtures
	kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
	grep -h "night_capture_shot" "$LOG_DIR"/*.log | sed -E 's/^\[client\] night_capture_shot //'
	exit 0
fi
# Porto: sem dados de teste (a cidade continua sem combate: os chefes ficam parados para a foto).
start_server server_porto.log
run_client CapPorto porto $((PORT + 70))
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
# Campo: jogador "Hero*" forte (dados de teste de combate) para aguentar a forma atroz durante as fotos.
start_server server_campo.log --combat-fixtures
run_client HeroCampo campo $((PORT + 71)) --combat-fixtures
kill "$SP" 2>/dev/null; wait "$SP" 2>/dev/null
echo "=== logs em $LOG_DIR"
grep -h "night_capture_shot" "$LOG_DIR"/*.log | sed -E 's/^\[client\] night_capture_shot //'
if grep -qE 'SCRIPT ERROR|Parse Error' "$LOG_DIR"/*.log; then
	echo "erros de script:"; grep -hE 'SCRIPT ERROR|Parse Error' -A3 "$LOG_DIR"/*.log | head -30
fi
# Pranchas: chefe de dia | forma atroz de noite (e o dia/noite dos mapas).
"${PY:-$P/../.tools/pyvenv/bin/python}" - "$OUT" <<'PY'
import sys, os
from PIL import Image, ImageDraw
out = sys.argv[1]
def pair(a, b, name, la, lb):
    pa, pb = os.path.join(out, a), os.path.join(out, b)
    if not (os.path.exists(pa) and os.path.exists(pb)):
        return
    A, B = Image.open(pa).convert("RGB"), Image.open(pb).convert("RGB")
    W = Image.new("RGB", (A.width + B.width + 8, max(A.height, B.height) + 28), (20, 20, 28))
    W.paste(A, (0, 28)); W.paste(B, (A.width + 8, 28))
    d = ImageDraw.Draw(W); d.text((8, 8), la, fill=(255, 240, 200)); d.text((A.width + 16, 8), lb, fill=(200, 215, 255))
    W.save(os.path.join(out, name)); print("prancha", name)
pair("porto_dia.png", "porto_noite.png", "prancha_porto_dia_noite.png", "Porto - dia", "Porto - noite")
pair("campo_dia.png", "campo_noite_forcada.png", "prancha_campo_dia_noite.png", "Campo (Sabia) - dia", "Campo - noite forcada (/noite)")
for sp in ("tatu", "vagalume", "redemoinho"):
    pair(f"{sp}_chefe_dia.png", f"{sp}_atroz_noite.png", f"prancha_{sp}_chefe_dia_atroz_noite.png",
         f"{sp}: chefe de dia", f"{sp}: forma atroz de noite")
PY
