"""Etapa 2a: quadros alinhados (96x96) de cada fonte: original, corpo-base (raspado) e cada estilo de cabelo.
Tudo passa pela transformacao DA ORIGINAL (params/render de common.py); as edicoes sao antes alinhadas a
original pela cabeca/tronco (align_color). Resultado em cache (pickle) no CUSTOM_WORK.
"""
import os, pickle
import numpy as np
from PIL import Image
from common import (frames, prep, params, render, shift, align_color, binarize, src_dir, work, CUSTOM_WORK)

MARGIN = 24


def frame_set(body, variant, only_tags=None):
    """{(anim, dir, tag): quadro RGBA 96x96 binarizado} da variante ('orig' = a imagem-chave aprovada)."""
    out = {}; info = {}
    for an, d, t, src, fl, H in frames(body):
        if only_tags and t not in only_tags: continue
        o = prep(os.path.join(src_dir(body), 'rb_' + src), fl); pr = params(o, H)
        of, cx = render(o, pr)
        if variant == 'orig':
            out[(an, d, t)] = binarize(of); continue
        ep = os.path.join(work(body, variant), 'rb_' + src)
        if not os.path.exists(ep): continue
        e = prep(ep, fl); dx, dy = align_color(o, e, pr); e = shift(e, dx, dy)
        ef, _ = render(e, pr, m=MARGIN, cx=cx)
        out[(an, d, t)] = binarize(ef); info[(an, d, t)] = (dx, dy)
    return out, info


def cached(body, variant, only_tags=None):
    p = os.path.join(CUSTOM_WORK, body, f'_frames_{variant}.pkl')
    srcs = [os.path.join(work(body, variant), f) for f in os.listdir(work(body, variant))] if variant != 'orig' else []
    # picks.json entra na validade do cache: trocar a fonte ou o espelhamento (flip_each) refaz os quadros
    srcs.append(os.path.join(src_dir(body), 'picks.json'))
    newest = max([os.path.getmtime(s) for s in srcs if os.path.exists(s)] + [0])
    if os.path.exists(p) and os.path.getmtime(p) > newest:
        d = pickle.load(open(p, 'rb'))
        return {k: Image.fromarray(v, 'RGBA') for k, v in d.items()}
    fs, info = frame_set(body, variant, only_tags)
    pickle.dump({k: np.asarray(v) for k, v in fs.items()}, open(p, 'wb'))
    print(body, variant, 'align', info)
    return fs
