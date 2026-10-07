"""Renderiza um NPC (Blender) reaproveitando o pipeline do personagem (characters/render_chr.py, C3) com as
configuracoes e pecas extras desta pasta (docs/arte-npcs-blender.md).

  .tools/blender/blender -b --python game/tools/art/blender/npcs/render_npc.py -- npc:<id> [--pitch 35]
        [--anims idle:8,walk:8] [--work .work/n2] [--threads 6]
Saida: <work>/npz/npc_<id>/npc__<id>.npz (+ .json). Nunca grava .blend na pasta do jogo (--no-blend)."""
import os, sys, runpy
HERE = os.path.dirname(os.path.abspath(__file__))
CHR = os.path.join(HERE, "..", "characters")
sys.path.insert(0, CHR)
sys.path.insert(0, HERE)
import chr_npc  # noqa: E402
import npc_parts  # noqa: E402
chr_npc.NPC_DIR = os.path.join(HERE, "configs")
npc_parts.register(chr_npc)
chr_npc.load = npc_parts.load     # configuracao + padroes do corpo (configs/_bodies.json)
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if "--work" not in argv:
    argv += ["--work", os.path.join(ROOT, ".work", "n2")]
if "--pitch" not in argv:
    argv += ["--pitch", "35"]
if "--no-blend" not in argv:
    argv += ["--no-blend"]
sys.argv = [sys.argv[0], "--"] + argv
runpy.run_path(os.path.join(CHR, "render_chr.py"), run_name="__main__")
