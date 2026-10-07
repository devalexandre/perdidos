#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Muda de pequizeiro da provação da Vó Aninha (TITULOS-E-SKILLS.md §3.3), no formato das folhas de
monstro (quadros de 96 px, 5 linhas de direção iguais: é planta, não vira).

Reaproveita o kit de ambiente pintado (assets/environment/painted/cards/card_broad_clump.png: arbusto
de folha larga, a cara do pequizeiro novo) e o chão de terra (_bria_src/dirt_1.jpg): reduz para pixel
art, limita a paleta, contorna em marrom-escuro como os monstros e monta as animações:
  idle/walk/attack: balanço leve das folhas (4 quadros)
  hit: pisca claro e treme (2 quadros)
  death: murcha, amarela e tomba; o último quadro fica (muda quebrada no chão).
Uso (python com Pillow):  /usr/bin/python3 game/tools/art/quest_props/gen_pequi_seedling.py
Saída: game/assets/quest_props/pequi_seedling/prop_pequi_seedling_<anim>.png
"""
import os
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
CARD = os.path.join(GAME, "assets/environment/painted/cards/card_broad_clump.png")
DIRT = os.path.join(GAME, "assets/environment/painted/_bria_src/dirt_1.jpg")
OUT = os.path.join(GAME, "assets/quest_props/pequi_seedling")
F = 96          # quadro
ROWS = 5        # direções (iguais)
GROUND_Y = 86   # base do chão no quadro (como os monstros)
OUTLINE = (42, 30, 22, 255)
PALETTE_COLORS = 28


def outline(img):
    a = img.split()[3].point(lambda v: 255 if v > 90 else 0)
    grown = a.filter(ImageFilter.MaxFilter(3))
    ring = Image.new("RGBA", img.size, OUTLINE)
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    base.paste(ring, (0, 0), grown)
    base.alpha_composite(img)
    return base


def pixelize(img, size):
    small = img.resize(size, Image.LANCZOS)
    alpha = small.split()[3].point(lambda v: 255 if v > 110 else 0)
    rgb = small.convert("RGB").quantize(PALETTE_COLORS, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def build_plant():
    card = Image.open(CARD).convert("RGBA")
    card = card.crop(card.getbbox())
    leaves = pixelize(card, (40, 40))
    leaves = ImageEnhance.Color(leaves).enhance(1.15)
    return leaves


def build_mound():
    dirt = Image.open(DIRT).convert("RGB").resize((60, 60), Image.LANCZOS).crop((10, 20, 46, 32))
    m = Image.new("RGBA", (36, 12), (0, 0, 0, 0))
    mask = Image.new("L", (36, 12), 0)
    ImageDraw.Draw(mask).ellipse((0, 1, 35, 11), fill=255)
    dirt = ImageEnhance.Brightness(dirt).enhance(0.62)
    dirt = Image.blend(dirt, Image.new("RGB", dirt.size, (104, 70, 42)), 0.45)
    m.paste(dirt.quantize(8).convert("RGB"), (0, 0), mask)
    shade = Image.new("RGBA", (36, 12), (60, 38, 20, 90))
    top = Image.new("L", (36, 12), 0)
    ImageDraw.Draw(top).ellipse((0, 5, 35, 11), fill=110)
    m.paste(shade, (0, 0), top)
    return m


def frame(plant, mound, sway=0, droop=0.0, wilt=0.0, flash=0.0, shake=0):
    """droop: 0..1 tomba a copa; wilt: 0..1 amarela/marrom; flash: 0..1 clareia."""
    img = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    mx = (F - mound.width) // 2 + shake
    img.alpha_composite(mound, (mx, GROUND_Y - mound.height + 2))
    p = plant
    if wilt > 0:
        gray = ImageEnhance.Color(p).enhance(1.0 - 0.8 * wilt)
        tint = Image.new("RGBA", p.size, (150, 110, 50, 255))
        p = Image.blend(gray, Image.composite(tint, gray, gray.split()[3]), 0.55 * wilt)
        p.putalpha(plant.split()[3])
    # Caule: tronquinho do próprio card (parte de baixo), desenhado em 2 px de largura.
    stem_h = 10 - int(4 * droop)
    cx = F // 2 + shake
    base_y = GROUND_Y - 4
    stem = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    d = ImageDraw.Draw(stem)
    lean = int(round(droop * 9))
    d.line((cx, base_y, cx + lean, base_y - stem_h), fill=(92, 62, 36, 255), width=3)
    d.line((cx + 1, base_y, cx + 1 + lean, base_y - stem_h), fill=(128, 88, 50, 255), width=1)
    img.alpha_composite(stem)
    # Copa: balanço (cisalhamento) e tombo (rotação a partir do pé da copa).
    q = p
    if sway:
        q = q.transform(q.size, Image.AFFINE, (1, sway * 0.04, -sway * 0.8, 0, 1, 0), Image.NEAREST)
    if droop > 0:
        q = q.rotate(-80 * droop, resample=Image.NEAREST, expand=True)
        q = q.resize((q.width, max(8, int(q.height * (1.0 - 0.25 * droop)))), Image.NEAREST)
    if flash > 0:
        white = Image.new("RGBA", q.size, (255, 255, 240, 255))
        q2 = Image.blend(q, Image.composite(white, q, q.split()[3]), flash)
        q2.putalpha(q.split()[3])
        q = q2
    qx = cx - q.width // 2 + int(round(droop * 14))
    qy = base_y - stem_h - q.height + 6
    if droop > 0:
        # Tomba para o lado e acaba deitada no chão, sempre dentro do quadro.
        qy = int(qy * (1.0 - droop) + (GROUND_Y - q.height + 1) * droop)
    qx = max(2, min(F - q.width - 2, qx))
    qy = max(2, min(GROUND_Y - q.height + 2, qy))
    img.alpha_composite(q, (qx, qy))
    # Fruto de pequi (verde-amarelo) pendurado na copa viva.
    if droop < 0.3:
        fr = Image.new("RGBA", (F, F), (0, 0, 0, 0))
        fd = ImageDraw.Draw(fr)
        fx, fy = cx + 7 + sway // 2, qy + q.height - 12
        fd.ellipse((fx, fy, fx + 4, fy + 4), fill=(186, 176, 58, 255) if wilt < 0.5 else (140, 112, 50, 255))
        fd.point((fx + 1, fy + 1), fill=(236, 226, 120, 255))
        img.alpha_composite(fr)
    return outline(img)


def sheet(frames):
    s = Image.new("RGBA", (F * len(frames), F * ROWS), (0, 0, 0, 0))
    for r in range(ROWS):
        for i, fr in enumerate(frames):
            s.alpha_composite(fr, (i * F, r * F))
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    plant = build_plant()
    mound = build_mound()
    idle = [frame(plant, mound, sway=s) for s in (0, 1, 0, -1)]
    hit = [frame(plant, mound, flash=0.3, shake=1), frame(plant, mound, flash=0.12, shake=-1)]
    death = [frame(plant, mound, wilt=w, droop=d) for w, d in
             ((0.2, 0.0), (0.45, 0.15), (0.7, 0.35), (0.85, 0.6), (1.0, 0.85), (1.0, 1.0))]
    for name, frames in (("idle", idle), ("walk", idle), ("attack", idle), ("hit", hit), ("death", death)):
        path = os.path.join(OUT, "prop_pequi_seedling_%s.png" % name)
        sheet(frames).save(path)
        print(path)


if __name__ == "__main__":
    main()
