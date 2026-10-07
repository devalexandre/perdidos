#!/usr/bin/env python3
"""Paleta mestra: carregador (.gpl), quantizador e validador.

Uso:
  python3 tools/art/palette.py validate [arquivos.png|diretorios ...]
      Falha (exit 1) se qualquer pixel opaco estiver fora da paleta mestra
      ou se houver pixel semitransparente (alpha diferente de 0 e 255).
  python3 tools/art/palette.py quantize entrada.png saida.png
      Converte para a paleta (vizinho mais proximo, sem dithering, alpha binario).
"""
from __future__ import annotations

import os
import sys
from functools import lru_cache
from typing import Iterable

from PIL import Image

GAME_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PALETTE_PATH = os.path.join(GAME_DIR, "assets", "_reference", "style_anchor", "paleta-mestra.gpl")

RGB = tuple[int, int, int]


@lru_cache(maxsize=None)
def load_palette(path: str = PALETTE_PATH) -> tuple[tuple[RGB, str], ...]:
    """Retorna ((r,g,b), nome) na ordem do arquivo .gpl."""
    out: list[tuple[RGB, str]] = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("GIMP") or ":" in s.split("\t")[0]:
                continue
            parts = s.split(None, 3)
            if len(parts) < 3 or not all(p.isdigit() for p in parts[:3]):
                continue
            name = parts[3].strip() if len(parts) > 3 else ""
            out.append(((int(parts[0]), int(parts[1]), int(parts[2])), name))
    return tuple(out)


def colors() -> list[RGB]:
    return [c for c, _ in load_palette()]


def ramps() -> dict[str, list[RGB]]:
    """Agrupa as rampas pelo nome sem o numero final: {'Azul ceu': [t1..t4], ...} (t1 = mais escuro)."""
    r: dict[str, list[RGB]] = {}
    for c, name in load_palette():
        base = name.rsplit(" ", 1)[0] if name[-1:].isdigit() else name
        r.setdefault(base, []).append(c)
    return r


def ramp(name: str) -> list[RGB]:
    return ramps()[name]


def hexc(h: str) -> RGB:
    h = h.lstrip("#")
    c = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
    if c not in set(colors()):
        raise ValueError(f"#{h} nao esta na paleta mestra")
    return c


@lru_cache(maxsize=65536)
def nearest(c: RGB) -> RGB:
    best = None
    bd = 1 << 30
    for p in colors():
        # distancia ponderada (percepcao aproximada)
        dr, dg, db = c[0] - p[0], c[1] - p[1], c[2] - p[2]
        d = 2 * dr * dr + 4 * dg * dg + 3 * db * db
        if d < bd:
            bd, best = d, p
    assert best is not None
    return best


def quantize(img: Image.Image, alpha_threshold: int = 128) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < alpha_threshold:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (*nearest((r, g, b)), 255)
    return img


def validate_image(path: str) -> list[str]:
    errs: list[str] = []
    pal = set(colors())
    img = Image.open(path).convert("RGBA")
    bad_color: dict[RGB, int] = {}
    semi = 0
    data = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
    for (r, g, b, a) in data:
        if a == 0:
            continue
        if a != 255:
            semi += 1
            continue
        if (r, g, b) not in pal:
            bad_color[(r, g, b)] = bad_color.get((r, g, b), 0) + 1
    if semi:
        errs.append(f"{path}: {semi} pixels semitransparentes")
    for c, n in sorted(bad_color.items(), key=lambda kv: -kv[1])[:10]:
        errs.append(f"{path}: cor fora da paleta #{c[0]:02x}{c[1]:02x}{c[2]:02x} ({n} px)")
    return errs


def iter_pngs(targets: Iterable[str]) -> Iterable[str]:
    for t in targets:
        if os.path.isdir(t):
            for root, _dirs, files in os.walk(t):
                if "_reference" in root.split(os.sep):
                    continue
                for fn in sorted(files):
                    if fn.lower().endswith(".png"):
                        yield os.path.join(root, fn)
        else:
            yield t


def main(argv: list[str]) -> int:
    if len(argv) >= 1 and argv[0] == "quantize" and len(argv) == 3:
        quantize(Image.open(argv[1])).save(argv[2])
        return 0
    if len(argv) >= 1 and argv[0] == "validate":
        targets = argv[1:] or [os.path.join(GAME_DIR, "assets")]
        n = 0
        errs: list[str] = []
        for p in iter_pngs(targets):
            n += 1
            errs += validate_image(p)
        for e in errs:
            print("FAIL", e)
        print(f"{n} PNG(s) verificados, {len(errs)} problema(s)")
        return 1 if errs or n == 0 else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
