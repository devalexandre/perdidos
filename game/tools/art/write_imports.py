#!/usr/bin/env python3
"""Escreve/atualiza os .import das PNGs geradas: sem compressao com perdas (preserva a paleta),
sem conversao automatica para VRAM ao detectar uso em 3D. Texturas de ambiente ganham mipmaps
(amostragem nearest_with_mipmaps no material); sprites nao.
Rodar ANTES de `godot --headless --import`.
"""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402

# assets/characters agora e de outro pipeline: nao mexer.
DIRS = {"assets/environment/textures": True, "assets/environment/field": False, "assets/monsters": False,
        "assets/minimap": False, "assets/fx": False,
        "assets/skills": False}  # campo de treino (agente W): sprites e minimapas sem mipmaps


def patch(path: str, mipmaps: bool) -> None:
    imp = path + ".import"
    params = {"compress/mode": "0", "mipmaps/generate": "true" if mipmaps else "false",
              "detect_3d/compress_to": "0", "process/fix_alpha_border": "false"}
    if os.path.exists(imp):
        txt = open(imp, encoding="utf-8").read()
        for k, v in params.items():
            pat = re.compile(r"^" + re.escape(k) + r"=.*$", re.M)
            if pat.search(txt):
                txt = pat.sub(f"{k}={v}", txt)
            else:
                txt = txt.replace("[params]\n", f"[params]\n\n{k}={v}\n", 1)
    else:
        txt = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n' + \
            "".join(f"{k}={v}\n" for k, v in params.items())
    open(imp, "w", encoding="utf-8").write(txt)


def main() -> None:
    for d, mip in DIRS.items():
        full = os.path.join(P.GAME_DIR, d)
        if not os.path.isdir(full):
            continue
        for dp, _, fns in sorted(os.walk(full)):
            for fn in sorted(fns):
                if fn.endswith(".png"):
                    patch(os.path.join(dp, fn), mip)
    print("imports ok")


if __name__ == "__main__":
    main()
