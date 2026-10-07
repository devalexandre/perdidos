"""Limpeza de folhas de sprite (GDD §17.1 / §17.10: "sem antialiasing contra o fundo", "sem pixels orfaos",
"fundo transparente, sem pixels semitransparentes soltos"). Idempotente: pode rodar de novo depois de qualquer
regeracao (ex.: build_combat.py do Agente A reescreve os chapeus/brincos das animacoes de combate).

    python cleanup_sheets.py [--dry] [--islands N] <png ou pasta> ...
    python cleanup_sheets.py --flip-row <png> <linha 0-4> [--dry]     espelha uma linha inteira (direcao trocada)

O que faz em cada PNG (RGBA):
  1. alfa binario no MESMO corte do renderizador (Sprite3D ALPHA_CUT_DISCARD / shader: 0,5): >= 128 -> 255, senao 0.
     No jogo 3D o resultado e identico; nas previas 2D some o halo semitransparente.
  2. remove pixels orfaos (sem nenhum vizinho opaco nas 8 direcoes);
  3. com --islands N (padrao 2): remove ilhas (8-conexas) de ate N px dentro de cada quadro 96x96.
     Use --islands 0 em folhas com detalhes minusculos soltos de proposito (brincos, fios de pesca...).
A sombra oval embutida em algumas folhas antigas (alfa < 128) some - o jogo ja desenha a sombra separada.
"""
import os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import convolve, label

FR = 96


def clean(a, islands):
    a = a.copy(); stats = {}
    al = a[..., 3]
    stats['semi'] = int(((al > 0) & (al < 255)).sum())
    op = al >= 128
    a[..., 3] = np.where(op, 255, 0); a[~op, :3] = 0
    n = convolve(op.astype(int), np.ones((3, 3), int), mode='constant') - op
    orphan = op & (n == 0)
    stats['orphan'] = int(orphan.sum())
    a[orphan] = 0; op &= ~orphan
    rem = 0
    if islands > 0:
        H, W = op.shape
        for y0 in range(0, H, FR):
            for x0 in range(0, W, FR):
                sub = op[y0:y0 + FR, x0:x0 + FR]
                lab, k = label(sub, structure=np.ones((3, 3), int))
                if k <= 1: continue
                sz = np.bincount(lab.ravel()); big = sz[1:].max()
                for i in range(1, k + 1):
                    if sz[i] <= islands and sz[i] < big:
                        m = lab == i; a[y0:y0 + FR, x0:x0 + FR][m] = 0; rem += int(sz[i])
    stats['island_px'] = rem
    return a, stats


def flip_row(p, row, dry):
    a = np.asarray(Image.open(p).convert('RGBA')).copy()
    r = a[row * FR:(row + 1) * FR]
    for c in range(a.shape[1] // FR):
        r[:, c * FR:(c + 1) * FR] = r[:, c * FR:(c + 1) * FR][:, ::-1]
    if not dry: Image.fromarray(a, 'RGBA').save(p)
    print(('(dry) ' if dry else '') + f'flip row {row}: {p}')


def main(argv):
    dry = '--dry' in argv; argv = [x for x in argv if x != '--dry']
    if argv and argv[0] == '--flip-row':
        return flip_row(argv[1], int(argv[2]), dry)
    islands = 2
    if '--islands' in argv:
        i = argv.index('--islands'); islands = int(argv[i + 1]); del argv[i:i + 2]
    files = []
    for p in argv:
        if os.path.isdir(p):
            files += sorted(os.path.join(dp, f) for dp, _, fs in os.walk(p) for f in fs if f.endswith('.png'))
        else:
            files.append(p)
    for p in files:
        a = np.asarray(Image.open(p).convert('RGBA'))
        b, s = clean(a, islands)
        changed = not np.array_equal(a, b)
        if changed and not dry: Image.fromarray(b, 'RGBA').save(p)
        if changed: print(('(dry) ' if dry else '') + f'{p}: semi {s["semi"]}, orfaos {s["orphan"]}, ilhas {s["island_px"]} px')


if __name__ == '__main__':
    main(sys.argv[1:])
