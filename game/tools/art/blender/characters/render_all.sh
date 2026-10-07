#!/bin/bash
# Renderiza (Blender) e pos-processa/instala (chr_post.py) o personagem jogavel: os dois corpos, todas as
# animacoes, todas as roupas/cabelos/brincos/chapeus/armas. Reexecutavel.
#   game/tools/art/blender/characters/render_all.sh [pitch=35] [corpos="male female"] [--no-install]
# Logs em .work/c3/logs/. ~10 min por corpo (12 nucleos).
P=${1:-35}
BODIES=${2:-"male female"}
EXTRA=$3
ROOT=$(cd "$(dirname "$0")/../../../../.." && pwd)
cd "$ROOT"
mkdir -p .work/c3/logs
for B in $BODIES; do
  if [ "$B" = male ]; then H=hair:spiky,hair:neat,hair:ponytail,hair:curly; else H=hair:ponytail,hair:bob,hair:waves,hair:braid; fi
  S=outfit:traveler,outfit:apprentice,outfit:branch_coat,outfit:master_armor,outfit:leather_jerkin,$H
  S=$S,ear:hoop,ear:seed,ear:feather,head:straw_hat,head:ipe_flower_crown,weapon:blade,weapon:staff
  rm -rf ".work/c3/npz/$B"
  .tools/blender/blender -b --python game/tools/art/blender/characters/render_chr.py -- "$B" --sets "$S" --pitch "$P" \
      --work .work/c3 > ".work/c3/logs/render_$B.log" 2>&1 || { echo "falhou render $B"; exit 1; }
  grep -E "\[chr\]" ".work/c3/logs/render_$B.log"
  .tools/pyvenv/bin/python game/tools/art/blender/characters/chr_post.py "$B" --work .work/c3 $EXTRA \
      > ".work/c3/logs/post_$B.log" 2>&1 || { echo "falhou pos $B"; tail -5 ".work/c3/logs/post_$B.log"; exit 1; }
  tail -1 ".work/c3/logs/post_$B.log"
done
