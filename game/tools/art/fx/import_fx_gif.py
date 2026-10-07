#!/usr/bin/env python3
"""Importa um GIF/APNG/WebP animado como folha de efeito de skill (opcional; a arte principal e a de
gen_skill_fx.py, desenhada quadro a quadro).

  python3 game/tools/art/fx/import_fx_gif.py ENTRADA.gif <skill>_<peca> [--size 96|192] [--colors 24]
        [--anchor center|bottom] [--blend add|mix] [--plane billboard|flat] [--bg auto|none|#rrggbb]
        [--tolerance 40] [--texel 0.020833] [--out game/assets/fx/skills]

Faz: 1) recorta o fundo (usa o alfa do arquivo; sem alfa, a cor dos cantos ou --bg); 2) acha a caixa
que cobre TODOS os quadros e centraliza (ou apoia no pe, --anchor bottom); 3) reduz para 96 ou 192 px
com filtro nearest, sem esticar; 4) limita a paleta (--colors, paleta unica para a animacao inteira,
alfa binario); 5) escreve <peca>.png (quadros em linha), <peca>.png.import (sem compressao) e
<peca>.json (quadros, duracao de cada quadro em ms, fps medio, pivo, blend, plano, texel, origem).

O SkillFx PREFERE a folha importada: se existir <peca>.json, ele vale no lugar da tabela gerada, e o
gen_skill_fx.py nao sobrescreve essa peca.

REGRA DE ORIGEM (GDD §0 regra 5): so GIFs proprios (feitos por nos, inclusive por IA com prompt nosso)
ou com licenca CC0/CC-BY conferida e registrada em game/assets/fx/skills/ORIGEM.md (fonte, autor,
licenca, data). NUNCA GIFs, ripagens ou "fan edits" de Ragnarok, Samsara Saga ou qualquer outro jogo.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageSequence

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
detect_3d/compress_to=0
process/fix_alpha_border=false
"""


def load_frames(path):
    im = Image.open(path)
    frames, durs = [], []
    for fr in ImageSequence.Iterator(im):
        frames.append(fr.convert("RGBA"))
        durs.append(int(fr.info.get("duration", im.info.get("duration", 80)) or 80))
    return frames, durs


def key_out(frames, bg, tol):
    arrs = [np.asarray(f, dtype=np.int16).copy() for f in frames]
    has_alpha = any((a[..., 3] < 250).any() for a in arrs)
    if bg == "none" or (bg == "auto" and has_alpha):
        return arrs
    if bg == "auto":
        a = arrs[0]
        corners = np.array([a[0, 0, :3], a[0, -1, :3], a[-1, 0, :3], a[-1, -1, :3]])
        key = np.median(corners, axis=0)
    else:
        s = bg.lstrip("#")
        key = np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)])
    from scipy import ndimage
    for a in arrs:
        d = np.abs(a[..., :3] - key).sum(axis=-1)
        a[d <= tol, 3] = 0
        # borda contaminada pela cor de fundo (halo misturado): tira ate 3 px de franja parecida com o fundo
        for _ in range(3):
            clear = a[..., 3] == 0
            edge = ndimage.binary_dilation(clear) & ~clear
            a[edge & (d <= tol * 5), 3] = 0
    return arrs


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("piece", help="<skill>_<peca>, ex.: arcane_spark_impact")
    ap.add_argument("--size", type=int, default=96, choices=[96, 192])
    ap.add_argument("--colors", type=int, default=24)
    ap.add_argument("--anchor", default="center", choices=["center", "bottom"])
    ap.add_argument("--blend", default="add", choices=["add", "mix"])
    ap.add_argument("--plane", default="billboard", choices=["billboard", "flat"])
    ap.add_argument("--bg", default="auto")
    ap.add_argument("--tolerance", type=int, default=40)
    ap.add_argument("--texel", type=float, default=1.0 / 48.0)
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--out", default=os.path.join(GAME, "assets", "fx", "skills"))
    a = ap.parse_args()

    frames, durs = load_frames(a.src)
    arrs = key_out(frames, a.bg, a.tolerance)
    alpha_any = np.zeros(arrs[0].shape[:2], dtype=bool)
    for x in arrs:
        alpha_any |= x[..., 3] > 16
    ys, xs = np.nonzero(alpha_any)
    if len(xs) == 0:
        sys.exit("nada visivel depois de recortar o fundo (ajuste --bg/--tolerance)")
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    w, h = x1 - x0, y1 - y0
    S = a.size
    k = min((S - 2) / w, (S - 2) / h)
    nw, nh = max(1, int(round(w * k))), max(1, int(round(h * k)))
    ox = (S - nw) // 2
    oy = (S - nh) // 2 if a.anchor == "center" else S - 2 - nh
    cells = []
    for x in arrs:
        crop = Image.fromarray(np.clip(x, 0, 255).astype(np.uint8), "RGBA").crop((x0, y0, x1, y1))
        small = crop.resize((nw, nh), Image.NEAREST)
        cell = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        cell.paste(small, (ox, oy))
        cells.append(cell)
    # paleta unica para a animacao inteira; alfa binario
    strip = Image.new("RGBA", (S * len(cells), S), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        strip.paste(c, (i * S, 0))
    arr = np.asarray(strip).copy()
    opaque = arr[..., 3] >= 128
    rgb = Image.fromarray(arr[..., :3], "RGB").quantize(colors=a.colors, method=Image.Quantize.MEDIANCUT,
                                                        dither=Image.Dither.NONE).convert("RGB")
    out = np.zeros_like(arr)
    out[..., :3] = np.asarray(rgb)
    out[..., 3] = np.where(opaque, 255, 0)
    os.makedirs(a.out, exist_ok=True)
    png = os.path.join(a.out, a.piece + ".png")
    Image.fromarray(out, "RGBA").save(png)
    if not os.path.exists(png + ".import"):
        open(png + ".import", "w").write(IMPORT)
    pivot = [S / 2, S / 2] if a.anchor == "center" else [S / 2, S - 2]
    meta = {"frames": len(cells), "durations_ms": durs, "fps": round(1000.0 * len(durs) / max(sum(durs), 1), 3),
            "size": [S, S], "pivot": pivot, "blend": a.blend, "plane": a.plane, "texel": a.texel,
            "loop": a.loop, "source": os.path.basename(a.src)}
    json.dump(meta, open(os.path.join(a.out, a.piece + ".json"), "w"), indent=1)
    print(f"{png}: {len(cells)} quadros {S}x{S}, {a.colors} cores, fps {meta['fps']}")


if __name__ == "__main__":
    main()
