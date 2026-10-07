"""Etapa 3: brincos (acessorios de rosto) desenhados em pixel art, pendurados no lobulo da orelha.

    python earrings.py [all|male|female]  -> assets/characters/face/<id>/<body>_{idle,walk,sit}.png

Brinco tem poucos pixels: recorte por IA seria ruido, entao e desenhado a mao (SPRITES) e posicionado pela
ancora do lobulo de cada quadro (anchors.json: escolhidas olhando a mascara do corpo-base em ASCII, ver
README). Nos passos a ancora segue a cabeca (mesmo deslocamento medido no corpo-base usado pelo cabelo).
Mesma montagem de quadros do build_sheets (respiracao no idle, balanco no andar).
"""
import json, os, pickle, sys
import numpy as np
from PIL import Image
from common import DIRS, FR, GAME, CUSTOM_WORK, assemble, sheet_image, save_png
from build import head_offset

HERE = os.path.dirname(os.path.abspath(__file__))
ANCHORS = json.load(open(os.path.join(HERE, 'anchors.json')))
# Paleta mestra v2: ouro 1-4, vermelho 1-3, verde-agua 1-3, base branca.
C = {
    'g1': (90, 58, 16), 'g2': (168, 116, 30), 'g3': (230, 180, 58), 'g4': (250, 229, 140),
    'r1': (74, 20, 20), 'r2': (156, 42, 38), 'r3': (217, 85, 58),
    't1': (24, 58, 68), 't2': (42, 110, 110), 't3': (79, 168, 160), 'ww': (252, 250, 245), 'p3': (201, 176, 138),
}
# Desenho a partir do lobulo (coluna do meio = x da ancora; primeira linha = logo abaixo do lobulo).
SPRITES = {  # tokens separados por espaco; ".." = vazio
    'hoop': [".. g4 ..",
             "g2 .. g3",
             "g2 .. g3",
             ".. g2 .."],
    'seed': [".. g2 ..",
             ".. r2 ..",
             "r1 r3 ..",
             "r1 r2 .."],
    'feather': [".. g2 ..",
                ".. ww ..",
                "t2 ww ..",
                "t2 t3 ..",
                ".. t1 .."],
}


def parse(rows):
    return [[None if t == '..' else C[t] for t in r.split()] for r in rows]


def draw(fr, x, y, sprite):
    a = np.asarray(fr).copy(); cells = parse(SPRITES[sprite]); w = max(len(r) for r in cells); x0 = x - w // 2
    for dy, row in enumerate(cells):
        for dx, c in enumerate(row):
            if c is None: continue
            px, py = x0 + dx, y + 1 + dy
            if 0 <= px < FR and 0 <= py < FR: a[py, px] = (*c, 255)
    return Image.fromarray(a)


def build(body):
    B, scalp, oh = pickle.load(open(os.path.join(CUSTOM_WORK, body, '_base.pkl'), 'rb'))
    base = {k: Image.fromarray(v) for k, v in B.items()}
    A = ANCHORS[body]
    for sprite in SPRITES:
        per = {}
        for d in DIRS:
            for anim, tags in (('idle', ['idle']), ('sit', ['sit'])):
                for t in tags:
                    f = Image.new('RGBA', (FR, FR))
                    for x, y in A[anim][d]: f = draw(f, x, y, sprite)
                    per[(anim, d, t)] = f
            ki = ('idle', d, 'idle')
            for t in ('wl', 'wr'):
                dx, dy = head_offset(base[ki], base[('walk', d, t)])
                f = Image.new('RGBA', (FR, FR))
                # walk_override: passos cuja cabeca esta em outro angulo que o idle (feminino N: idle de perfil,
                # passos de costas) -> ancoras proprias (lista vazia = orelha escondida, sem brinco)
                pts = A.get('walk_override', {}).get(d)
                for x, y in (pts if pts is not None else [(x + dx, y + dy) for x, y in A['idle'][d]]):
                    f = draw(f, x, y, sprite)
                per[('walk', d, t)] = f
        for anim, rows in assemble(per, ref=base).items():
            p = os.path.join(GAME, 'assets', 'characters', 'face', sprite, f'{body}_{anim}.png')
            save_png(sheet_image(rows), p); print('  ', p)


if __name__ == '__main__':
    for b in (['male', 'female'] if len(sys.argv) < 2 or sys.argv[1] == 'all' else [sys.argv[1]]):
        build(b)
