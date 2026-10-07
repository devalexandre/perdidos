#!/usr/bin/env python3
"""Kit de cenário pintado (GDD §17.0.A): trata as imagens brutas da Bria e grava as texturas finais.

Entrada: assets/environment/painted/_bria_src/  (brutos, fora do import da Godot via .gdignore)
Saída:   assets/environment/painted/textures/tex_*.png  (tileáveis)  e  cards/card_*.png (com alfa)

Uso:  python tools/art/env_kit/process_textures.py [nome ...]
Precisa de Pillow e numpy. Prompts, seeds e origem de cada textura: assets/environment/painted/REGISTRO.md
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC = os.path.join(ROOT, "assets/environment/painted/_bria_src")
TEX_OUT = os.path.join(ROOT, "assets/environment/painted/textures")
CARD_OUT = os.path.join(ROOT, "assets/environment/painted/cards")

# nome -> (arquivo bruto, lado final, matiz(graus), saturação×, valor×, contraste×, desfoque px, detalhe×)
# "detalhe" < 1 achata o ruído de alta frequência (texturas de terreno calmas, sem "chiado").
TILES = {
    "grass":      ("grass3_1.jpg", 1024, 14, 1.05, 0.92, 0.80, 1.2, 0.65),
    "grass_lush": ("grass_0.jpg", 1024, 4, 0.95, 0.95, 0.75, 1.5, 0.55),
    "dirt":       ("dirt_1.jpg", 1024, 7, 0.80, 0.95, 0.80, 1.0, 0.70),
    "cobble":     ("cobble_0.jpg", 1024, 0, 0.90, 0.96, 0.90, 0.6, 0.90),
    "sand":       ("sand_1.jpg", 1024, 0, 0.90, 1.00, 0.80, 1.0, 0.70),
    "rock":       ("rock2_1.jpg", 1024, 0, 0.85, 0.95, 0.90, 0.6, 0.85),
    "plaster":    ("plaster_1.jpg", 1024, 0, 0.55, 0.98, 0.70, 0.8, 0.70),
    "roof":       ("roof_0.jpg", 1024, 0, 0.90, 0.95, 0.95, 0.4, 0.95),
    "roof_canal": ("roof2_1.jpg", 1024, -2, 1.05, 0.92, 1.05, 0.3, 0.95),
    "snow":       ("snow_1.jpg", 1024, 0, 0.80, 1.00, 0.75, 1.0, 0.70),
    "red_earth":  ("red_earth_1.jpg", 1024, 0, 0.85, 0.95, 0.80, 1.0, 0.70),
    "thatch":     ("thatch_0.jpg", 1024, 0, 0.90, 0.95, 0.95, 0.4, 0.95),
    "gravel":     ("gravel_1.jpg", 1024, 0, 0.90, 0.97, 0.85, 0.5, 0.80),
    "ice":        ("ice_1.jpg", 1024, 0, 0.85, 1.00, 0.85, 0.8, 0.80),
    "dry_grass":  ("dry_grass_1.jpg", 1024, 0, 0.90, 0.97, 0.80, 1.0, 0.65),
    "jungle_floor": ("jungle_floor_0.jpg", 1024, 0, 0.85, 0.92, 0.75, 1.2, 0.55),
    "paving":     ("cobble2_1.jpg", 1024, 0, 0.90, 0.97, 0.90, 0.4, 0.90),
    "wood":       ("wood_1.jpg", 1024, 0, 0.90, 0.92, 0.95, 0.4, 0.95),
    "azulejo":    ("azulejo_0.jpg", 1024, 0, 0.90, 0.97, 0.95, 0.3, 1.00),
    "bark":       ("bark_0.jpg", 512, 0, 0.85, 0.85, 0.90, 0.5, 0.90),
    "stonewall":  ("stonewall_1.jpg", 1024, 0, 0.85, 0.96, 0.90, 0.5, 0.90),
    "needles":    ("canopy_conifer_0.jpg", 1024, 0, 0.95, 0.95, 0.95, 0.4, 0.95),
    "needles_b":  ("canopy_conifer_1.jpg", 1024, 0, 0.95, 0.95, 0.95, 0.4, 0.95),
    "ipe_bloom":  ("canopy_ipe_0.jpg", 1024, 0, 1.00, 1.00, 0.95, 0.4, 0.95),
}

# Cards com alfa (recortados pela Bria "remove background"): nome -> (arquivo, lado final)
CARDS = {
    "conifer_tuft": ("leaf_conifer_1_cut.webp", 512),
    "conifer_tuft_b": ("leaf_conifer_0_cut.webp", 512),
    "broad_clump": ("leaf_broad_1_cut.webp", 512),
    "ipe_clump": ("leaf_ipe_0_cut.webp", 512),
    "ipe_clump_b": ("leaf_ipe_1_cut.webp", 512),
    "flowers": ("flowers_0_cut.webp", 256),
    "flowers_b": ("flowers_1_cut.webp", 256),
    "grass_tuft": ("grassblades_0_cut.webp", 256),
    "grass_tuft_b": ("grassblades_1_cut.webp", 256),
    "mushrooms": ("mushrooms_0_cut.webp", 256),
    "mushrooms_b": ("mushrooms_1_cut.webp", 256),
    "palm_fan": ("fanleaf_1_cut.webp", 512),
    "palm_frond": ("frond_1_cut.webp", 512),
    "reeds": ("reeds_1_cut.webp", 256),
}


def adjust(img, hue, sat, val, contrast):
    hsv = np.asarray(img.convert("HSV"), dtype=np.float32)
    hsv[..., 0] = (hsv[..., 0] + hue * 255.0 / 360.0) % 255.0
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    hsv[..., 2] = np.clip(hsv[..., 2] * val, 0, 255)
    out = Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB")
    a = np.asarray(out, dtype=np.float32)
    mean = a.reshape(-1, 3).mean(axis=0)
    a = (a - mean) * contrast + mean
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def flatten_detail(img, amount):
    """Reduz o detalhe fino: mistura com uma versão desfocada (amount=1 mantém)."""
    if amount >= 0.999:
        return img
    blur = img.filter(ImageFilter.GaussianBlur(3.0))
    return Image.blend(blur, img, amount)


def make_seamless(img):
    """Mistura a imagem com ela mesma deslocada meia volta, com peso que zera nas bordas."""
    a = np.asarray(img, dtype=np.float32)
    h, w = a.shape[:2]
    shifted = np.roll(np.roll(a, h // 2, axis=0), w // 2, axis=1)
    y = np.abs(np.linspace(-1, 1, h))[:, None]
    x = np.abs(np.linspace(-1, 1, w))[None, :]
    # Peso 1 no centro, 0 nas bordas (onde a versão deslocada é contínua ao dar a volta).
    wgt = np.clip(1.0 - np.maximum(x, y), 0, 1) ** 0.7
    wgt = np.clip(wgt * 1.6, 0, 1)[..., None]
    out = a * wgt + shifted * (1 - wgt)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def process_tile(name, spec):
    src, side, hue, sat, val, con, blur, detail = spec
    img = Image.open(os.path.join(SRC, src)).convert("RGB")
    img = adjust(img, hue, sat, val, con)
    img = flatten_detail(img, detail)
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    img = make_seamless(img)
    img = img.resize((side, side), Image.LANCZOS)
    os.makedirs(TEX_OUT, exist_ok=True)
    out = os.path.join(TEX_OUT, "tex_%s.png" % name)
    img.save(out, optimize=True)
    write_import(out)
    print("tex", out)


def bleed_alpha(img, iterations=16):
    """Espalha a cor das bordas para os pixels transparentes (sem franja escura nos mipmaps)."""
    a = np.asarray(img, dtype=np.float32)
    rgb, alpha = a[..., :3].copy(), a[..., 3] / 255.0
    known = alpha > 0.5
    for _ in range(iterations):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(alpha.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                acc += np.roll(np.roll(rgb * known[..., None], dy, 0), dx, 1)
                cnt += np.roll(np.roll(known.astype(np.float32), dy, 0), dx, 1)
        grow = (~known) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        known = known | grow
    out = np.dstack([rgb, alpha * 255.0])
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def process_card(name, spec):
    src, side = spec
    img = Image.open(os.path.join(SRC, src)).convert("RGBA")
    bbox = img.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    img = img.crop(bbox)
    w, h = img.size
    s = max(w, h)
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    # Base do card encostada embaixo (pés no chão), centralizado na horizontal.
    canvas.paste(img, ((s - w) // 2, s - h))
    canvas = canvas.resize((side, side), Image.LANCZOS)
    canvas = bleed_alpha(canvas)
    os.makedirs(CARD_OUT, exist_ok=True)
    out = os.path.join(CARD_OUT, "card_%s.png" % name)
    canvas.save(out, optimize=True)
    write_import(out)
    print("card", out)


IMPORT_PARAMS = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0",
                 "process/fix_alpha_border": "true"}


def write_import(png):
    """.import com compressão VRAM + mipmaps (cenário NÃO é pixel art: filtro linear com mipmaps)."""
    imp = png + ".import"
    if os.path.exists(imp):
        txt = open(imp, encoding="utf-8").read()
        for k, v in IMPORT_PARAMS.items():
            lines = [ln for ln in txt.split("\n") if not ln.startswith(k + "=")]
            txt = "\n".join(lines).rstrip("\n") + "\n%s=%s\n" % (k, v)
    else:
        txt = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n' + \
            "".join("%s=%s\n" % kv for kv in IMPORT_PARAMS.items())
    open(imp, "w", encoding="utf-8").write(txt)


def main():
    only = set(sys.argv[1:])
    for name, spec in TILES.items():
        if not only or name in only:
            process_tile(name, spec)
    for name, spec in CARDS.items():
        if not only or name in only:
            process_card(name, spec)


if __name__ == "__main__":
    main()
