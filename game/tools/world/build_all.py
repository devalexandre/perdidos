#!/usr/bin/env python3
"""Run every world generator in dependency order, in one process, then validate the whole world.

Later generators refine what earlier ones wrote (build_hunt_areas lays out the hunt maps, build_fields /
build_forest / build_plateau re-form them, build_ratanaba_expansion links the Chapada summit to Serra Dourada, ...), so
a single generator run on its own can rewrite a map that a later one owns. This script replays the
whole chain; with --check nothing is written and the result is compared with the files on disk.

Usage (from game/):
  ../.tools/pyvenv/bin/python3 tools/world/build_all.py --check   # dry run: what would change + validation
  ../.tools/pyvenv/bin/python3 tools/world/build_all.py           # regenerate everything
  WORLDGEN_DUMP=/tmp/out ... --check                              # also dump the generated files
"""

import runpy
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import worldgen as wg  # noqa: E402

# Historical order (each step may rewrite what the previous ones produced).
PIPELINE = [
    "build_sabia_monsters.py",
    "build_hunt_areas.py",
    "build_forest.py",
    "build_venom_monsters.py",
    "build_cave_monsters.py",
    "build_cave.py",
    "build_fields.py",
    "build_plateau.py",
    "build_ratanaba.py",
    "build_ratanaba_expansion.py",
    "build_folklore_native_monsters.py",
    "build_city_of_z_expansion.py",
    "build_hoer_verde_expansion.py",
    "build_hollow_earth_expansion.py",
]


def main() -> None:
    wg.ORCHESTRATED = True
    wg.install()
    for script in PIPELINE:
        print(f"===== {script}")
        runpy.run_path(str(wg.TOOLS_DIR / script), run_name="__main__")
    wg.ORCHESTRATED = False
    wg.finish(None, "build_all")


if __name__ == "__main__":
    main()
