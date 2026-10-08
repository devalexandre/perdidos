#!/usr/bin/env python3
"""Monta as folhas do efeito "anime" da Faisca (arcane_spark) em game/assets/fx/anime/.

  .tools/blender/blender -b --factory-startup -P game/tools/art/fx/anime/fire_lance_blender.py -- .work/fx-pilot/raw
  .tools/pyvenv/bin/python game/tools/art/fx/anime/build_anime_fx.py [.work/fx-pilot/raw] [KENNEY_PNG_DIR]

Entradas: quadros do Blender (explosao, lanca) e, para o brilho da conjuracao e as particulas, texturas
do Kenney Particle Pack (CC0; KENNEY_PNG_DIR = pasta "PNG (Transparent)" do pacote; sem ela, reaproveita
as copias ja guardadas em game/assets/fx/anime/particles/).

Saidas (folha em grade de `cols` colunas, com <peca>.json ao lado — o SkillFxSprite le o json):
  arcane_spark_anime_blast   explosao toon com contorno (blend mix), 24 quadros 320 px
  arcane_spark_anime_glow    brilho aditivo tirado das partes mais quentes da explosao (blend glow), 160 px
  arcane_spark_anime_lance   lanca de fogo em laco (mix) + arcane_spark_anime_lance_glow (glow)
  arcane_spark_anime_cast    clarao da conjuracao no mago (glow): nucleo pulsando + estrelas girando
  particles/*.png            brasa, estrelinha, risco de faisca e pedrinha (CPUParticles3D)
Nada aqui e quantizado: degrade e alfa suaves, filtro linear com mipmaps no jogo (filter = linear).
"""
from __future__ import annotations

import json
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
ROOT = os.path.dirname(GAME)
OUT = os.path.join(GAME, "assets", "fx", "anime")
PART = os.path.join(OUT, "particles")
RAW = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ROOT, ".work", "fx-pilot", "raw")
KENNEY = sys.argv[2] if len(sys.argv) > 2 else ""
PREVIEW = os.path.join(ROOT, ".work", "fx-pilot", "sheets")

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"
metadata={{
"vram_texture": false
}}

[params]

compress/mode=0
mipmaps/generate={mip}
process/fix_alpha_border=true
process/premult_alpha=false
detect_3d/compress_to=0
"""


def write_import(png, mip=True):
    p = png + ".import"
    if os.path.exists(p):
        txt = open(p).read()
        if ("mipmaps/generate=%s" % ("true" if mip else "false")) in txt:
            return  # o Godot ja completou (uid, caminhos): nao mexe
    with open(p, "w") as fh:
        fh.write(IMPORT.format(mip="true" if mip else "false"))


def load_frames(name):
    d = os.path.join(RAW, name)
    meta = json.load(open(os.path.join(d, "meta.json")))
    frames = [np.asarray(Image.open(os.path.join(d, "%04d.png" % i)).convert("RGBA"), dtype=np.float32) / 255.0
              for i in range(meta["frames"])]
    return frames, meta


def pack(piece, frames, cols, info):
    h, w = frames[0].shape[:2]
    rows = (len(frames) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), np.float32)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = f
    img = Image.fromarray((np.clip(sheet, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    os.makedirs(OUT, exist_ok=True)
    png = os.path.join(OUT, piece + ".png")
    img.save(png, optimize=True)
    write_import(png)
    meta = {"frames": len(frames), "cols": cols, "size": [w, h], "filter": "linear", "plane": "billboard",
            "loop": False}
    meta.update(info)
    with open(os.path.join(OUT, piece + ".json"), "w") as fh:
        json.dump(meta, fh)
    os.makedirs(PREVIEW, exist_ok=True)
    bg = Image.new("RGBA", img.size, (88, 124, 58, 255))
    bg.alpha_composite(img)
    bg.convert("RGB").save(os.path.join(PREVIEW, piece + ".png"))
    print("  %-34s %2d quadros %dx%d  folha %dx%d" % (piece, len(frames), w, h, img.width, img.height))


def blur(a, sigma):
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(sigma)), dtype=np.float32) / 255.0


def half(a):
    h, w = a.shape[:2]
    return a.reshape(h // 2, 2, w // 2, 2, -1).mean(axis=(1, 3))


def glow_of(frames, hot_lo, sigma, gain, color, extra=None):
    """Brilho aditivo: so as partes quentes (creme/amarelo) do quadro, borradas e tingidas; meia resolucao."""
    out = []
    col = np.array(color, np.float32)
    for i, f in enumerate(frames):
        rgb, a = f[..., :3], f[..., 3]
        hot = np.clip((rgb[..., 1] - hot_lo) / (1.0 - hot_lo), 0, 1) * (rgb[..., 0] > 0.85) * a
        g = blur(hot, sigma) * gain
        if extra is not None:
            g = np.maximum(g, extra(i, g.shape))
        g = np.clip(g, 0, 1)
        rgba = np.dstack([np.broadcast_to(col, g.shape + (3,)) * 1.0, g])
        # aditivo: o shader soma cor * alfa ao fundo
        out.append(half(rgba))
    return out


# --------------------------------------------------------------------------------------------- pecas

def build_blast():
    frames, meta = load_frames("blast")
    n = len(frames)
    # fim: some aos poucos (a fumaca e as brasas viram particulas no jogo)
    for i in range(n):
        k = 1.0 - max(0.0, (i - (n - 8)) / 8.0)
        frames[i][..., 3] *= k ** 1.5
    info = {"pivot": meta["pivot"], "texel": meta["texel"], "blend": "mix", "fps": 18.0}
    pack("arcane_spark_anime_blast", frames, 6, info)

    w = frames[0].shape[1]
    yy, xx = np.mgrid[0:w, 0:w].astype(np.float32)
    px, py = meta["pivot"]
    cy = py - 0.62 / meta["texel"]  # centro da bola (0,62 m acima do chao)

    def flash(i, shape):
        # clarao redondo nos 4 primeiros quadros (o estouro "acende" o chao em volta)
        if i > 4:
            return np.zeros(shape, np.float32)
        r = (0.45 + 0.25 * i) / meta["texel"]
        d = np.sqrt((xx - px) ** 2 + ((yy - cy) * 1.15) ** 2) / r
        return np.clip(1.0 - d, 0, 1) ** 1.6 * (1.0 - i / 5.0) * 0.95

    glow = glow_of(frames, 0.70, 14, 1.25, (1.0, 0.62, 0.22), flash)
    info = {"pivot": [px / 2, py / 2], "texel": meta["texel"] * 2, "blend": "glow", "fps": 18.0}
    pack("arcane_spark_anime_glow", glow, 6, info)


def build_lance():
    frames, meta = load_frames("lance")
    h = frames[0].shape[0]
    fade = np.clip(np.linspace(0, 1, h) / 0.28, 0, 1) ** 1.3  # rabo some no alto (vem do ceu)
    for f in frames:
        f[..., 3] *= fade[:, None]
    info = {"pivot": meta["pivot"], "texel": meta["texel"], "blend": "mix", "fps": 16.0, "loop": True}
    pack("arcane_spark_anime_lance", frames, 6, info)
    glow = glow_of(frames, 0.55, 9, 1.1, (1.0, 0.7, 0.3))
    info = {"pivot": [meta["pivot"][0] / 2, meta["pivot"][1] / 2], "texel": meta["texel"] * 2, "blend": "glow",
            "fps": 16.0, "loop": True}
    pack("arcane_spark_anime_lance_glow", glow, 6, info)


def kenney(name, size):
    """Textura branca do Kenney Particle Pack (CC0) -> alfa, guardada em particles/<name>.png."""
    os.makedirs(PART, exist_ok=True)
    dst = os.path.join(PART, "kenney_%s.png" % name)
    if KENNEY:
        im = Image.open(os.path.join(KENNEY, name + ".png")).convert("RGBA")
        a = np.asarray(im.convert("L"), np.float32) / 255.0 * np.asarray(im, np.float32)[..., 3] / 255.0
        a = np.asarray(Image.fromarray((a * 255).astype(np.uint8), "L").resize((size, size), Image.LANCZOS),
                       np.float32) / 255.0
        rgba = np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a])
        Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA").save(dst)
        write_import(dst)
    return np.asarray(Image.open(dst).convert("RGBA"), np.float32)[..., 3] / 255.0


def stamp(canvas, tex, cx, cy, scale, rot_deg, color, alpha):
    s = max(2, int(tex.shape[0] * scale))
    im = Image.fromarray((tex * 255).astype(np.uint8), "L").resize((s, s), Image.LANCZOS).rotate(
        rot_deg, resample=Image.BICUBIC)
    a = np.asarray(im, np.float32) / 255.0 * alpha
    x0, y0 = int(cx - s / 2), int(cy - s / 2)
    H, W = canvas.shape[:2]
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + s), min(H, y0 + s)
    if xa >= xb or ya >= yb:
        return
    sub = a[ya - y0:yb - y0, xa - x0:xb - x0]
    canvas[ya:yb, xa:xb, :3] += sub[..., None] * np.array(color, np.float32)
    canvas[ya:yb, xa:xb, 3] = np.maximum(canvas[ya:yb, xa:xb, 3], sub)


def build_cast():
    """Clarao da conjuracao (12 quadros em laco): halo quente pulsando, estrela de 4 pontas girando e
    fagulhas orbitando — feito com light_01/star_06/circle_05 do Kenney (CC0), tudo aditivo."""
    light = kenney("light_01", 256)
    star = kenney("star_06", 256)
    dot = kenney("circle_05", 64)
    kenney("star_07", 64)
    kenney("trace_01", 64)
    S, N = 192, 12
    frames = []
    for i in range(N):
        ph = i / N * math.tau
        c = np.zeros((S, S, 4), np.float32)
        pulse = 0.85 + 0.15 * math.sin(ph * 2)
        stamp(c, light, S / 2, S / 2, 0.62 * pulse, ph * 20, (1.0, 0.55, 0.18), 0.55)
        stamp(c, dot, S / 2, S / 2, 1.5 * pulse, 0, (1.0, 0.85, 0.5), 0.9)
        stamp(c, star, S / 2, S / 2, 0.55 + 0.08 * math.sin(ph * 3), ph * 15, (1.0, 0.92, 0.7), 0.9)
        stamp(c, star, S / 2, S / 2, 0.35, 45 - ph * 25, (1.0, 0.6, 0.25), 0.7)
        for k in range(5):
            a = ph + k / 5 * math.tau
            r = 52 + 10 * math.sin(ph * 2 + k)
            stamp(c, dot, S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r * 0.55, 0.32, 0,
                  (1.0, 0.7 + 0.1 * (k % 2), 0.3), 0.95)
        # a soma dos carimbos ja e "cor x alfa": volta para cor pura (o shader aditivo multiplica pelo alfa)
        c[..., :3] = np.clip(c[..., :3] / np.maximum(c[..., 3:], 1e-3), 0, 1)
        frames.append(c)
    info = {"pivot": [S / 2, S / 2], "texel": 1.5 / S, "blend": "glow", "fps": 14.0, "loop": True}
    pack("arcane_spark_anime_cast", frames, 6, info)


def build_rock():
    """Pedrinha voando da explosao (particula, blend normal): poligono com contorno, 4x reduzido."""
    os.makedirs(PART, exist_ok=True)
    S = 32 * 4
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(S * (0.5 + 0.38 * math.cos(a) * r), S * (0.5 + 0.34 * math.sin(a) * r))
           for a, r in zip([k / 7 * math.tau for k in range(7)], [1.0, 0.8, 0.95, 0.75, 1.0, 0.85, 0.9])]
    d.polygon(pts, fill=(58, 40, 34, 255))
    inner = [((x - S / 2) * 0.78 + S / 2, (y - S / 2) * 0.78 + S / 2) for x, y in pts]
    d.polygon(inner, fill=(126, 92, 70, 255))
    d.polygon(inner[:4] + [(S / 2, S / 2)], fill=(160, 124, 96, 255))
    dst = os.path.join(PART, "rock.png")
    im.resize((32, 32), Image.LANCZOS).save(dst)
    write_import(dst)


def copy_license():
    if KENNEY:
        lic = os.path.join(os.path.dirname(KENNEY.rstrip("/")), "License.txt")
        if os.path.exists(lic):
            shutil.copy(lic, os.path.join(PART, "KENNEY_LICENSE.txt"))


if __name__ == "__main__":
    print("build_anime_fx: %s -> %s" % (RAW, OUT))
    build_blast()
    build_lance()
    build_cast()
    build_rock()
    copy_license()
