#!/usr/bin/env python3
"""Gerador PROVISORIO (GDD 19) de texturas de terreno repetiveis 64x64 (48 px/unidade -> 1,33 un.;
escala aplicada pelos UVs em build_city.gd).

Todas as cores vem da paleta mestra (validado por palette.py). Deterministico (seed fixa).
Uso: python3 tools/art/gen_textures.py
"""
from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402

OUT = os.path.join(P.GAME_DIR, "assets", "environment", "textures")
N = 64

PED = P.ramp("Pedra/metal")
PERG = P.ramp("Pergaminho")
VF = P.ramp("Verde folha")
VA = P.ramp("Verde agua")
CEU = P.ramp("Azul ceu")
MD = P.ramp("Madeira/cabelo")
RED = P.ramp("Vermelho")
OURO = P.ramp("Ouro/amarelo")
ROSA = P.ramp("Rosa")
ROXO = P.ramp("Roxo")
WHITE = P.hexc("fcfaf5")


def value_noise(seed: int, period: int):
    rnd = random.Random(seed)
    g = [[rnd.random() for _ in range(period)] for _ in range(period)]

    def f(x: float, y: float) -> float:
        fx, fy = x * period / N, y * period / N
        x0, y0 = int(math.floor(fx)), int(math.floor(fy))
        tx, ty = fx - x0, fy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[y0 % period][x0 % period]
        b = g[y0 % period][(x0 + 1) % period]
        c = g[(y0 + 1) % period][x0 % period]
        d = g[(y0 + 1) % period][(x0 + 1) % period]
        return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty

    return f


def img_from(fn) -> Image.Image:
    im = Image.new("RGBA", (N, N))
    px = im.load()
    for y in range(N):
        for x in range(N):
            px[x, y] = (*fn(x, y), 255)
    return im


def wrapd(a: float, b: float) -> float:
    d = abs(a - b) % N
    return min(d, N - d)


def cobblestone() -> Image.Image:
    rnd = random.Random(11)
    # pedras em grade irregular (voronoi com repeticao)
    pts = []
    for gy in range(5):
        for gx in range(5):
            pts.append(((gx + 0.5 + rnd.uniform(-0.3, 0.3)) * N / 5, (gy + 0.5 + rnd.uniform(-0.3, 0.3)) * N / 5,
                        rnd.choice([0, 0, 1, 1, 2])))
    nz = value_noise(3, 16)

    def f(x: int, y: int):
        ds = sorted(((math.hypot(wrapd(x, px_), wrapd(y, py)), i) for i, (px_, py, _) in enumerate(pts)))
        (d1, i1), (d2, _) = ds[0], ds[1]
        if d2 - d1 < 1.6:
            return PED[1] if nz(x, y) > 0.4 else PERG[1]
        px_, py, tone = pts[i1]
        # direcao ate o centro: luz de cima-esquerda
        dx = ((x - px_ + N / 2) % N) - N / 2
        dy = ((y - py + N / 2) % N) - N / 2
        edge = d2 - d1
        pal = [PED[2], PERG[2], PED[3]][tone]
        if edge < 3.5 and dx + dy > 2:
            return PED[2] if tone != 0 else PED[1]
        if edge < 3.5 and dx + dy < -3:
            return PERG[3] if tone == 1 else PED[3] if tone == 0 else WHITE if nz(x, y) > 0.8 else PERG[3]
        if nz(x * 2 % N, y * 2 % N) > 0.75:
            return PERG[2] if tone != 1 else PED[3]
        return pal

    return img_from(f)


def grass_flowers() -> Image.Image:
    nz = value_noise(5, 4)
    rnd = random.Random(7)

    def f(x: int, y: int):
        v = nz(x, y)
        if v < 0.25 and (x + y) % 2 == 0:
            return VF[1]
        if v > 0.8 and (x * 3 + y) % 4 == 0:
            return VF[3]
        return VF[2]

    im = img_from(f)
    px = im.load()
    # laminas de grama: traco claro de 2 px com base escura
    for _ in range(60):
        x, y = rnd.randrange(N), rnd.randrange(N)
        px[x, y] = (*VF[3], 255)
        px[x, (y + 1) % N] = (*VF[3], 255)
        px[(x + 1) % N, (y + 2) % N] = (*VF[1], 255)
    # flores: cruz de petalas + miolo
    cols = [OURO[3], WHITE, ROSA[2], ROXO[3]]
    for i in range(6):
        x, y = rnd.randrange(N), rnd.randrange(N)
        c = cols[i % len(cols)]
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            px[(x + dx) % N, (y + dy) % N] = (*c, 255)
        px[x, y] = (*(OURO[2] if c != OURO[3] else RED[2]), 255)
        px[x % N, (y + 2) % N] = (*VF[1], 255)
    return im


def wet_sand() -> Image.Image:
    nz = value_noise(9, 8)
    nz2 = value_noise(10, 32)
    rnd = random.Random(4)

    def f(x: int, y: int):
        w = nz(x, y) + 0.25 * math.sin((y + 6 * nz(x, x)) * 2 * math.pi * 3 / N)
        if w < 0.3:
            return PERG[1] if (x + y) % 2 else PERG[2]
        if nz2(x, y) > 0.82:
            return PERG[3]
        return PERG[2]

    im = img_from(f)
    px = im.load()
    for _ in range(40):
        x, y = rnd.randrange(N), rnd.randrange(N)
        px[x, y] = (*rnd.choice([PERG[1], PERG[3], PED[2]]), 255)
    return im


def whitewash_wall() -> Image.Image:
    nz = value_noise(12, 8)
    nz2 = value_noise(13, 32)

    def f(x: int, y: int):
        v = nz(x, y)
        if v < 0.12 and (x + y) % 2:
            return PERG[2]
        if nz2(x, y) > 0.85:
            return WHITE
        return PERG[3]

    im = img_from(f)
    return im


def clay_roof_tile() -> Image.Image:
    # telhas coloniais: canais verticais de 8 px, fiadas de 16 px desencontradas
    def f(x: int, y: int):
        row = y // 16
        xo = (x + (4 if row % 2 else 0)) % N
        cx = xo % 8
        cy = y % 16
        if cy >= 14:
            return RED[0] if cy == 15 else RED[1]
        if cx == 0:
            return RED[1]
        if cx in (1, 2):
            return RED[3] if cy < 11 else RED[2]
        if cx == 7:
            return RED[1]
        if cx == 6:
            return RED[2] if cy > 3 else RED[2]
        return RED[2] if cy > 9 and cx > 4 else RED[2] if cy > 12 else (RED[3] if cx == 3 and cy < 6 else RED[2])

    return img_from(f)


def azulejo() -> Image.Image:
    # 4x4 azulejos de 16 px com motivo floral simetrico azul e branco
    motif = [
        "................",
        ".b............b.",
        "..b....bb....b..",
        "...b..bLLb..b...",
        "......bLLb......",
        ".....b.bb.b.....",
        "..bb..bddb..bb..",
        ".bLLbbdLLdbbLLb.",
        ".bLLbbdLLdbbLLb.",
        "..bb..bddb..bb..",
        ".....b.bb.b.....",
        "......bLLb......",
        "...b..bLLb..b...",
        "..b....bb....b..",
        ".b............b.",
        "................",
    ]

    def f(x: int, y: int):
        tx, ty = x % 16, y % 16
        if tx == 15 or ty == 15:
            return PED[3]
        ch = motif[ty][tx]
        if ch == "b":
            return CEU[1]
        if ch == "d":
            return CEU[0]
        if ch == "L":
            return CEU[2]
        if (tx in (0, 14) or ty in (0, 14)) and (tx + ty) % 2 == 0:
            return CEU[3]
        return WHITE

    return img_from(f)


def wood_planks() -> Image.Image:
    rnd = random.Random(21)
    nz = value_noise(22, 16)
    ends = {r: rnd.randrange(N) for r in range(8)}

    def f(x: int, y: int):
        r, cy = y // 8, y % 8
        if cy == 7:
            return MD[0]
        if (x - ends[r]) % N in (0,):
            return MD[0]
        if (x - ends[r]) % N == 1:
            return MD[3]
        if cy == 0:
            return MD[3]
        g = nz((x * 1) % N, (y * 4 + r * 9) % N)
        if cy == 6:
            return MD[1]
        if g > 0.7 or (cy == 3 and (x + r * 7) % 13 < 5):
            return MD[1]
        return MD[2]

    return img_from(f)


def water() -> Image.Image:
    nz = value_noise(31, 4)
    rnd = random.Random(33)

    def f(x: int, y: int):
        v = nz(x, y)
        if v < 0.28 and (x + y) % 2 == 0:
            return VA[1]
        if v > 0.7 and (x + y) % 2 == 0:
            return VA[3]
        return VA[2]

    im = img_from(f)
    px = im.load()
    for i in range(22):
        x, y = rnd.randrange(N), rnd.randrange(N)
        ln = rnd.randint(3, 6)
        for k in range(ln):
            px[(x + k) % N, y] = (*(VA[3] if i % 4 else WHITE), 255)
        for k in range(1, ln - 1):
            px[(x + k) % N, (y + 1) % N] = (*VA[1], 255)
    return im

def painted_wall(ramp_name: str, seed: int):
    r = P.ramp(ramp_name)

    def make() -> Image.Image:
        nz = value_noise(seed, 8)
        nz2 = value_noise(seed + 1, 32)

        def f(x: int, y: int):
            v = nz(x, y)
            if v < 0.14 and (x + y) % 2:
                return r[2]
            if nz2(x, y) > 0.86:
                return WHITE if ramp_name != "Pergaminho" else r[3]
            return r[3]

        return img_from(f)

    return make


def stone_wall() -> Image.Image:
    rnd = random.Random(41)
    offs = [rnd.randrange(16) for _ in range(8)]
    tones = {}

    def f(x: int, y: int):
        row, cy = y // 8, y % 8
        xo = (x + offs[row]) % N
        col, cx = xo // 16, xo % 16
        key = (row, col)
        if key not in tones:
            tones[key] = rnd.choice([PED[2], PED[2], PERG[2], PED[3]])
        if cy == 7 or cx == 15:
            return PED[1]
        if cy == 6 or cx == 14:
            return PED[2] if tones[key] != PED[2] else PERG[1]
        if cy == 0 or cx == 0:
            return PED[3] if tones[key] != PED[3] else WHITE
        return tones[key]

    return img_from(f)


def foliage(ramp_a, ramp_b, seed: int, dots) -> Image.Image:
    """Copa: tufos arredondados sobrepostos, luz de cima-esquerda, sombra so na borda inferior-direita."""
    rnd = random.Random(seed)
    im = Image.new("RGBA", (N, N), (*ramp_a[1], 255))
    px = im.load()
    for _ in range(60):
        cx, cy = rnd.uniform(0, N), rnd.uniform(0, N)
        r = rnd.uniform(3.5, 6.0)
        ri = int(r) + 2
        for dy in range(-ri, ri + 1):
            for dx in range(-ri, ri + 1):
                d = math.hypot(dx, dy)
                if d > r:
                    continue
                x, y = int(cx + dx) % N, int(cy + dy) % N
                if d > r - 1.0 and dx + dy > 1:
                    c = ramp_a[1]
                elif math.hypot(dx + r * 0.3, dy + r * 0.3) < r * 0.5:
                    c = ramp_a[3]
                else:
                    c = ramp_a[2]
                px[x, y] = (*c, 255)
    for _ in range(40):
        x, y = rnd.randrange(N), rnd.randrange(N)
        px[x, y] = (*rnd.choice(dots), 255)
    for _ in range(12):
        x, y = rnd.randrange(N), rnd.randrange(N)
        px[x, y] = (*ramp_b[1], 255)
    return im


def calcada_waves() -> Image.Image:
    """Calcada portuguesa em ondas (pedrinhas claras e escuras), 128x128, comum nas pracas brasileiras."""
    S = 128
    nz = value_noise(71, 16)
    im = Image.new("RGBA", (S, S))
    px = im.load()
    for y in range(S):
        for x in range(S):
            sx, sy = x % 4, (y + (2 if (x // 4) % 2 else 0)) % 4
            # passe visual (ancora 4): ondas menores, 2 ciclos por ladrilho e faixa escura mais fina
            wave = (y + 5.0 * math.sin(4 * math.pi * x / S)) % 32
            dark = wave < 4
            if sx == 3 or sy == 3:
                c = PED[1] if dark else PERG[2]
            elif dark:
                c = PED[2] if (sx == 0 and sy == 0) else PED[1]
            elif sx == 0 and sy == 0:
                c = WHITE
            else:
                c = PERG[3] if nz(x % N, y % N) > 0.35 else PED[3]
            px[x, y] = (*c, 255)
    return im


def awning(ramp_c):
    """Toldo listrado (cor + branco)."""
    def make() -> Image.Image:
        def f(x: int, y: int):
            band = (x // 8) % 2
            edge = y % 32 >= 29
            if band == 0:
                c = ramp_c[2] if not edge else ramp_c[1]
            else:
                c = WHITE if not edge else PERG[3]
            if x % 8 == 7:
                c = ramp_c[1] if band == 0 else PERG[3]
            return c

        return img_from(f)

    return make


def magic_circle() -> Image.Image:
    """Circulo magico sob o cristal (128x128, fundo transparente, alpha binario)."""
    S = 128
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = im.load()
    c = (S - 1) / 2.0

    def put(x: float, y: float, col) -> None:
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < S and 0 <= yi < S:
            px[xi, yi] = (*col, 255)

    for y in range(S):
        for x in range(S):
            d = math.hypot(x - c, y - c)
            if 61.0 <= d < 62.5 or 44.0 <= d < 45.2 or 21.0 <= d < 22.2:
                px[x, y] = (*OURO[3], 255)
            elif 59.5 <= d < 60.6:
                px[x, y] = (*OURO[2], 255)
    # 30/09/2026: sem hexagrama (GDD §4.0 regra 3). Mesma linguagem do circulo de conjuracao das skills
    # (tools/art/fx/gen_skill_fx.py, cast_circle): flor de ipe de 5 petalas e runas do Sabia (semente,
    # broto e ziguezague de rio) entre os aneis externos.
    runes = [[".#.", "#.#", "#.#", ".#."], ["#.#", ".#.", ".#.", "##."], ["##.", ".#.", ".##", "..#"]]
    for i in range(20):
        a = 2 * math.pi * i / 20
        g = runes[i % len(runes)]
        x0, y0 = c + math.cos(a) * 52.5 - 3, c + math.sin(a) * 52.5 - 4
        for j, row in enumerate(g):
            for k, ch in enumerate(row):
                if ch == "#":  # runa em pixel 2x2 para ler de longe
                    for ox in (0, 1):
                        for oy in (0, 1):
                            put(x0 + k * 2 + ox, y0 + j * 2 + oy, WHITE if j in (1, 2) else OURO[3])
    # flor de ipe: 5 petalas em lente do anel interno (r=22) ate o anel do meio (r=44)
    for p_ in range(5):
        a0 = -math.pi / 2 + p_ * 2 * math.pi / 5
        for side in (1, -1):
            for t in range(0, 101):
                u = t / 100
                rr = 22 + u * 21
                off = side * math.sin(u * math.pi) ** 0.8 * 0.52
                put(c + math.cos(a0 + off) * rr, c + math.sin(a0 + off) * rr, OURO[3])
                off2 = side * math.sin(u * math.pi) ** 0.8 * 0.3
                if 0.15 < u < 0.9:
                    put(c + math.cos(a0 + off2) * rr, c + math.sin(a0 + off2) * rr, OURO[2])
        for t in range(0, 15):  # nervura central da petala
            rr = 26 + t
            put(c + math.cos(a0) * rr, c + math.sin(a0) * rr, OURO[2])
        put(c + math.cos(a0) * 44, c + math.sin(a0) * 44, WHITE)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            put(c + math.cos(a0) * 44 + dx, c + math.sin(a0) * 44 + dy, WHITE)
    # miolo da flor: pontinhos (estames) no anel interno
    for k in range(10):
        a = 2 * math.pi * k / 10 + math.pi / 10
        put(c + math.cos(a) * 16, c + math.sin(a) * 16, WHITE if k % 2 else OURO[3])
    return im


TEXTURES = {
    "tex_cobblestone_01": cobblestone,
    "tex_grass_flowers_01": grass_flowers,
    "tex_wet_sand_01": wet_sand,
    "tex_whitewash_wall_01": whitewash_wall,
    "tex_clay_roof_tile_01": clay_roof_tile,
    "tex_azulejo_01": azulejo,
    "tex_wood_planks_01": wood_planks,
    "tex_water_01": water,
    "tex_painted_wall_yellow_01": painted_wall("Ouro/amarelo", 51),
    "tex_painted_wall_pink_01": painted_wall("Rosa", 52),
    "tex_painted_wall_blue_01": painted_wall("Azul ceu", 53),
    "tex_painted_wall_green_01": painted_wall("Verde agua", 54),
    "tex_stone_wall_01": stone_wall,
    "tex_leaves_01": lambda: foliage(VF, VA, 61, [VF[3], OURO[3], ROSA[2]]),
    "tex_ipe_yellow_01": lambda: foliage((OURO[1], OURO[2], OURO[3], OURO[3]), VF, 62, [WHITE, WHITE, OURO[2]]),
    "tex_ipe_purple_01": lambda: foliage(ROXO, ROSA, 63, [ROSA[3], ROXO[3], WHITE]),
    "tex_magic_circle_01": magic_circle,
    "tex_calcada_waves_01": calcada_waves,
    "tex_awning_red_01": awning(RED),
    "tex_awning_teal_01": awning(VA),
    "tex_awning_yellow_01": awning(OURO),
    "tex_awning_blue_01": awning(CEU),
    "tex_awning_green_01": awning(VF),
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, fn in TEXTURES.items():
        fn().save(os.path.join(OUT, name + ".png"))
    if "--preview" in sys.argv:
        d = sys.argv[sys.argv.index("--preview") + 1]
        pv = Image.new("RGBA", (len(TEXTURES) * (N * 2 * 3 + 8), N * 2 * 3), (0, 0, 0, 255))
        for i, name in enumerate(TEXTURES):
            t = Image.open(os.path.join(OUT, name + ".png"))
            tile = Image.new("RGBA", (N * 2, N * 2))
            for a in range(2):
                for b in range(2):
                    tile.paste(t, (a * N, b * N))
            pv.paste(tile.resize((N * 6, N * 6), Image.NEAREST), (i * (N * 6 + 8), 0))
        pv.save(os.path.join(d, "tex_preview.png"))
    print("ok:", ", ".join(TEXTURES))


if __name__ == "__main__":
    main()
