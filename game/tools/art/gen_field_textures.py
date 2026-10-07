#!/usr/bin/env python3
"""Texturas de chao repetiveis 64x64 do Campo de Treino (mesmo metodo e paleta mestra de gen_textures.py).
Uma por regiao (GDD 4.0: paleta regional) + trilhas, telhado de sape e gelo.
Uso: python3 tools/art/gen_field_textures.py [--preview DIR]"""
from __future__ import annotations
import os, random, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import gen_textures as T  # noqa: E402
from gen_textures import N, value_noise, img_from, PED, PERG, VF, VA, CEU, MD, RED, OURO, ROSA, ROXO, WHITE  # noqa: E402


def speckle(im, rnd, n, cols, size=1):
    px = im.load()
    for _ in range(n):
        x, y = rnd.randrange(N), rnd.randrange(N)
        c = rnd.choice(cols)
        for dx in range(size):
            px[(x + dx) % N, y] = (*c, 255)
    return im


def blades(im, rnd, n, hi, lo):
    px = im.load()
    for _ in range(n):
        x, y = rnd.randrange(N), rnd.randrange(N)
        px[x, y] = (*hi, 255); px[x, (y + 1) % N] = (*hi, 255); px[(x + 1) % N, (y + 2) % N] = (*lo, 255)
    return im


def base3(seed, period, lo, mid, hi, t_lo=0.28, t_hi=0.78):
    nz = value_noise(seed, period)
    def f(x, y):
        v = nz(x, y)
        if v < t_lo and (x + y) % 2 == 0: return lo
        if v > t_hi and (x * 3 + y) % 4 == 0: return hi
        return mid
    return img_from(f)


def cerrado_grass():
    # capim do cerrado: verde com manchas douradas de capim seco, pouco contraste
    rnd = random.Random(101)
    nz = value_noise(102, 8)
    nz2 = value_noise(103, 4)
    def f(x, y):
        v = nz(x, y); w = nz2(x, y)
        if w > 0.42:
            return OURO[1] if (x + y) % 2 == 0 else (OURO[2] if v > 0.6 else VF[2])
        if v < 0.3 and (x + y) % 2 == 0: return VF[1]
        return VF[2]
    im = img_from(f)
    blades(im, rnd, 60, OURO[2], OURO[1])
    blades(im, rnd, 40, VF[3], VF[1])
    speckle(im, rnd, 4, [WHITE, ROXO[2]])
    return im


SKD = T.P.ramp("Pele escura")


def red_earth():
    rnd = random.Random(111)
    im = base3(112, 8, SKD[1], SKD[2], SKD[3], 0.25, 0.8)
    speckle(im, rnd, 40, [MD[1], SKD[1], PERG[2]])
    return im


def packed_dirt():
    rnd = random.Random(121)
    im = base3(122, 8, MD[1], MD[2], MD[3], 0.25, 0.8)
    speckle(im, rnd, 50, [PERG[1], MD[1], PERG[2]])
    return im


def snow():
    rnd = random.Random(131)
    im = base3(132, 4, CEU[3], WHITE, PED[3], 0.3, 0.75)
    speckle(im, rnd, 30, [CEU[3], PED[3]])
    return im


def ice():
    nz = value_noise(141, 4)
    def f(x, y):
        v = nz(x, y)
        if (x - y) % 23 == 0 and v > 0.4: return WHITE
        return CEU[2] if v < 0.35 else CEU[3]
    return img_from(f)


def desert_sand():
    rnd = random.Random(151)
    im = base3(152, 8, PERG[1], PERG[2], PERG[3], 0.25, 0.8)
    speckle(im, rnd, 40, [OURO[2], PERG[1], OURO[3]])
    return im


def lush_grass():
    rnd = random.Random(161)
    im = base3(162, 4, VF[1], VF[2], VF[3], 0.3, 0.8)
    blades(im, rnd, 70, VF[3], VF[1])
    speckle(im, rnd, 6, [WHITE, ROXO[2], OURO[3]])
    return im


def moss_gravel():
    rnd = random.Random(171)
    im = base3(172, 8, VA[1], VF[2], VA[2], 0.35, 0.75)
    speckle(im, rnd, 60, [PED[2], PED[3], PED[1]])
    return im


def jungle_floor():
    rnd = random.Random(181)
    im = base3(182, 4, VF[0], VF[1], VA[1], 0.35, 0.75)
    blades(im, rnd, 50, VF[2], VF[0])
    speckle(im, rnd, 20, [MD[1], MD[2]])
    return im


def dry_meadow():
    # capim claro mediterraneo
    rnd = random.Random(191)
    im = base3(192, 4, PERG[1], PERG[2], OURO[3], 0.3, 0.8)
    blades(im, rnd, 60, VF[2], PERG[1])
    speckle(im, rnd, 6, [WHITE, RED[2]])
    return im


def birch_meadow():
    rnd = random.Random(201)
    im = base3(202, 4, VF[1], VF[2], OURO[2], 0.3, 0.85)
    blades(im, rnd, 60, VF[3], VF[1])
    speckle(im, rnd, 8, [OURO[3], WHITE, CEU[2]])
    return im


def stone_paving():
    # lajes retangulares claras (Imperio de Jade, Costa das Colunas)
    nz = value_noise(211, 16)
    def f(x, y):
        row = y // 16
        off = 8 if row % 2 else 0
        if y % 16 == 0 or (x + off) % 21 == 0: return PED[1]
        if y % 16 == 1 or (x + off) % 21 == 1: return PED[3]
        return PED[2] if nz(x, y) > 0.55 else PERG[2]
    return img_from(f)


def thatch():
    # sape: palha em faixas horizontais (telhado do rancho)
    rnd = random.Random(221)
    nz = value_noise(222, 16)
    def f(x, y):
        if y % 8 == 7: return MD[1]
        v = nz(x, y)
        return OURO[2] if (x + (y // 8) * 3) % 4 == 0 else (OURO[1] if v < 0.4 else PERG[2])
    im = img_from(f)
    blades(im, rnd, 40, OURO[3], MD[2])
    return im


TEXTURES = {
    "tex_cerrado_grass_01": cerrado_grass,
    "tex_red_earth_01": red_earth,
    "tex_packed_dirt_01": packed_dirt,
    "tex_snow_01": snow,
    "tex_ice_01": ice,
    "tex_desert_sand_01": desert_sand,
    "tex_lush_grass_01": lush_grass,
    "tex_moss_gravel_01": moss_gravel,
    "tex_jungle_floor_01": jungle_floor,
    "tex_dry_meadow_01": dry_meadow,
    "tex_birch_meadow_01": birch_meadow,
    "tex_stone_paving_01": stone_paving,
    "tex_thatch_01": thatch,
}


def main():
    os.makedirs(T.OUT, exist_ok=True)
    for name, fn in TEXTURES.items():
        fn().save(os.path.join(T.OUT, name + ".png"))
    if "--preview" in sys.argv:
        d = sys.argv[sys.argv.index("--preview") + 1]
        S = N * 2 * 3
        pv = Image.new("RGBA", (len(TEXTURES) * (S + 8), S), (0, 0, 0, 255))
        for i, name in enumerate(TEXTURES):
            t = Image.open(os.path.join(T.OUT, name + ".png"))
            tile = Image.new("RGBA", (N * 2, N * 2))
            for a in range(2):
                for b in range(2):
                    tile.paste(t, (a * N, b * N))
            pv.paste(tile.resize((S, S), Image.NEAREST), (i * (S + 8), 0))
        pv.save(os.path.join(d, "field_tex_preview.png"))
    print("ok:", ", ".join(TEXTURES))


if __name__ == "__main__":
    main()
