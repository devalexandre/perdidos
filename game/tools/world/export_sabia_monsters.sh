#!/usr/bin/env bash
# Run from the repository root. Preserve the editable, animated source .blend files.
set -euo pipefail
for species in buriti_boar cinder_serpent ember_mule; do
 for stage in 1 3 4; do
  .tools/blender/blender -b -t 2 --python game/tools/art/blender/monsters/render_monster.py -- "$species" "$stage" --work .work/sabia-live --no-blend
  .tools/pyvenv/bin/python game/tools/art/blender/monsters/post.py "$species" "$stage" --work .work/sabia-live
 done
done
python3 game/tools/world/build_sabia_monsters.py
