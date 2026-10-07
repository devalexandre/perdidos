#!/usr/bin/env bash
# Renderiza (Blender) e pos-processa (paleta, contornos, folhas) os monstros feitos no Blender.
# Uso: game/tools/art/blender/monsters/build_all.sh [id ...]   (sem argumentos = todos)
#      PITCH=55 NO_INSTALL=1 JOBS=3 ...   (NO_INSTALL=1 so gera previas em .work/b3/preview)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../../.." && pwd)"
BL="${BLENDER:-$ROOT/.tools/blender/blender}"
PY="${PY:-$ROOT/.tools/pyvenv/bin/python}"
PITCH="${PITCH:-55}"
JOBS="${JOBS:-3}"
IDS=("$@"); [ ${#IDS[@]} -eq 0 ] && IDS=(stone_armadillo prank_whirlwind enchanted_firefly \
	spirit_fox_cub jaguar_cub trickster_tanuki lake_kelpie puca_trickster little_chimera sphinx_cub griffin_chick \
	obsidian_iguana dune_scorpion lindworm_hatchling zmey_hatchling moss_troll trasgo_imp hopping_jiangshi \
	kasa_obake walking_hut fountain_serpent)
EXTRA=(); [ -n "${NO_INSTALL:-}" ] && EXTRA=(--no-install)
one() {
	local id="$1" st="$2"
	"$BL" -b --python "$HERE/render_monster.py" -- "$id" "$st" --pitch "$PITCH" 2>&1 | grep -E "^\[mon\]|Error|Traceback" || true
	"$PY" "$HERE/post.py" "$id" "$st" "${EXTRA[@]}"
}
for id in "${IDS[@]}"; do
	# estagios da especie: STAGES = (1, 2) no modulo (padrao 1 2 3)
	sts=$( (grep -oE "^STAGES = \([0-9, ]+\)|stages=\([0-9, ]+\)" "$HERE/$id.py" || true) | grep -oE "[0-9]+" | tr "\n" " " || true)
	[ -z "$sts" ] && sts="1 2 3"
	for st in $sts; do
		one "$id" "$st" &
		while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
	done
done
wait
echo "ok: previas em $ROOT/.work/b3/preview"
