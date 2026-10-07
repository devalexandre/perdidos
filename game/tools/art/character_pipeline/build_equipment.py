"""Aparencia do Viajante (contrato, ADENDO 1): roupas (folha inteira) e camadas (cabeca, arma) alinhadas
quadro a quadro com chr_traveler_<body>_{idle,walk,sit}.png.

Metodo: cada imagem-fonte aprovada do Viajante (picks do build_sheets.py + "sit" da pasta de trabalho) e
EDITADA pela IA ("add a straw hat..."). A imagem editada e alinhada a original (deslocamento pelas pernas),
passa pela MESMA transformacao da original (recorte, escala BOX, posicao) e o item sai pela diferenca.

  build_equipment.py sitsheet <body>                 folha sit do Viajante (chr_traveler_<body>_sit.png)
  build_equipment.py edit <body> <visual> [--only f] edicoes IA (+ remocao de fundo) das fontes
  build_equipment.py build <body> <visual>           monta a camada/roupa em assets/
Visuais: VISUALS abaixo. Pasta de trabalho: $NPC_WORK/traveler_<body> (fontes e picks.json).
"""
import json, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import label, binary_fill_holes, binary_dilation
HERE = os.path.dirname(os.path.abspath(__file__)); GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, HERE)
FR = 96; DIRS = ['s', 'se', 'e', 'ne', 'n']; H_IDLE = 84; H_WALK = 83; H_SIT = 62
KEEP = (" Keep everything else exactly the same: the same character, face, hair, outfit, the same pose, the same body "
        "position and size in the image, the same camera angle, colors, pixel art style and plain white background. Single character, full body.")
VISUALS = {
    'straw_hat': dict(kind='layer', slot='head', region='head',
        text="Put a wide-brimmed woven straw hat with a thin red band and a small pink flower tucked in the band on the character's head, sitting naturally on the hair."),
    'ipe_flower_crown': dict(kind='layer', slot='head', region='head',
        text="Put a small flower crown on top of the character's head: a thin woven wreath of small bright yellow ipe tree flowers with a few green leaves, resting on the hair."),
    'blade': dict(kind='layer', slot='weapon', region='any', back_rows=['ne', 'n'],
        text="The character now holds a short steel machete in one hand, a broad slightly curved blade with a wooden handle, held low at the side with the blade pointing down. Do not change the arms more than needed to hold it."),
    'staff': dict(kind='layer', slot='weapon', region='any', back_rows=['ne', 'n'],
        text="The character now holds a wooden walking staff in one hand, a straight light-brown wooden staff as tall as the character's shoulders with a small glowing blue crystal on top, held upright at the side. Do not change the arms more than needed to hold it."),
    'leather_jerkin': dict(kind='outfit',
        text="Replace the blue hoodie with a brown leather jerkin: a sleeveless laced leather doublet with stitched seams and a belt, worn over a cream linen long-sleeved shirt. Keep the backpack, legs, trousers and sneakers."),
}
SIT_TXT = ("sitting on the ground with legs crossed, hands resting on the knees; for the weapon, it lies across the lap")


def work(body): return os.path.join(os.environ['NPC_WORK'], f'traveler_{body}')


def frames(body):
    """[(anim, dir, tag, src, flip, H)] na ordem das folhas."""
    P = json.load(open(os.path.join(work(body), 'picks.json'))); out = []
    for d in DIRS:
        p = P['dirs'][d]; fe = p.get('flip_each', {})
        out.append(('idle', d, 'idle', p['idle'], fe.get('idle', False), H_IDLE))
        for t in ('wl', 'wr'):
            out.append(('walk', d, t, p[t], fe.get(t, False), H_WALK))
        out.append(('walk', d, 'widle', p['idle'], fe.get('idle', False), H_IDLE))  # build_sheets reusa o idle (84)
    for d in DIRS:
        out.append(('sit', d, 'sit', P['sit'][d], d in P.get('sit_flip', []), H_SIT))
    return out


def prep(path, flip):
    """Como build_sheets.load, mas na imagem inteira: alfa binario, remove sujeira, espelha."""
    a = np.asarray(Image.open(path).convert('RGBA')).copy()
    a[..., 3] = np.where(a[..., 3] > 150, 255, 0)
    lab, n = label(a[..., 3] > 0)
    if n > 1:
        sz = np.bincount(lab.ravel()); keep = sz >= sz[1:].max() * 0.01; keep[0] = False; a[~keep[lab]] = 0
    if flip: a = a[:, ::-1].copy()
    return a


def params(a, H):
    ys, xs = np.nonzero(a[..., 3] > 0); B = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    bw, bh = B[2] - B[0], B[3] - B[1]; W = max(1, round(bw * H / bh))
    return dict(B=B, W=W, H=H)


def render(a, pr, m=0, cx=None):
    """Transformacao do build_sheets (BOX + posicao pelo centro de massa); m = margem extra em px finais."""
    B, W, H = pr['B'], pr['W'], pr['H']; sx = W / (B[2] - B[0]); sy = H / (B[3] - B[1])
    P = int(m / min(sx, sy)) + 2 if m else 0  # moldura transparente para a margem nao sair da imagem
    im = Image.fromarray(np.pad(a, ((P, P), (P, P), (0, 0))) if P else a, 'RGBA')
    box = (B[0] + P - m / sx, B[1] + P - m / sy, B[2] + P + m / sx, B[3] + P + m / sy)
    r = im.resize((W + 2 * m, H + 2 * m), Image.BOX, box=box)
    # (sem binarizar: igual ao build_sheets, que mantem o alfa parcial do BOX)
    if cx is None:
        cx = int(round(np.nonzero(np.asarray(r)[m:m + H, m:m + W, 3] > 0)[1].mean()))
    o = Image.new('RGBA', (FR, FR)); o.alpha_composite(r, (FR // 2 - cx - m, FR - H - m) if FR // 2 - cx - m >= 0 and FR - H - m >= 0 else (0, 0))
    if FR // 2 - cx - m < 0 or FR - H - m < 0:  # margem saiu do quadro: cola recortando
        o = Image.new('RGBA', (FR, FR)); ox, oy = FR // 2 - cx - m, FR - H - m
        o.paste(r.crop((max(0, -ox), max(0, -oy), r.width, r.height)), (max(0, ox), max(0, oy)))
    return o, cx


def align(orig, ed, pr):
    """Deslocamento (dx, dy) da editada em relacao a original, pelo alfa da metade de baixo (pernas)."""
    B = pr['B']; y0 = B[1] + (B[3] - B[1]) // 2
    A = orig[y0:B[3], B[0]:B[2], 3] > 0
    best = (-1, 0, 0); E = ed[..., 3] > 0
    for step, rng, cen in ((4, 48, (0, 0)), (1, 4, None)):
        c = cen if cen is not None else (best[1], best[2])
        for dy in range(c[1] - rng, c[1] + rng + 1, step):
            for dx in range(c[0] - rng, c[0] + rng + 1, step):
                ys0, ys1, xs0, xs1 = y0 + dy, B[3] + dy, B[0] + dx, B[2] + dx
                if ys0 < 0 or xs0 < 0 or ys1 > E.shape[0] or xs1 > E.shape[1]: continue
                s = (A & E[ys0:ys1, xs0:xs1]).sum() * 2 - A.sum() - E[ys0:ys1, xs0:xs1].sum()
                if s > best[0] or best[0] == -1: best = (s, dx, dy)
    return best[1], best[2]


def shift(a, dx, dy):
    o = np.zeros_like(a); h, w = a.shape[:2]
    o[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)] = a[max(0, dy):h - max(0, -dy), max(0, dx):w - max(0, -dx)]
    return o


def edited_frame(body, visual, src, flip, H):
    wd = work(body); o = prep(os.path.join(wd, 'rb_' + src), flip); pr = params(o, H)
    base, cx = render(o, pr)
    ep = os.path.join(wd, 'eq', visual, 'rb_' + src)
    if not os.path.exists(ep): return base, None
    e = prep(ep, flip); dx, dy = align(o, e, pr); e = shift(e, dx, dy)
    ef, _ = render(e, pr, m=24, cx=cx)
    return base, ef


def extract(base, ef, region, thr=48, rad=2, grow=4, grow_thr=30):
    """Pixels do item: um pixel da editada e "do corpo" se alguma cor da original a ate rad px for parecida
    (tolera a re-renderizacao e pequenos deslocamentos da IA); senao e do item. Depois limpeza."""
    from scipy.ndimage import binary_closing
    b = np.asarray(base).astype(int); e = np.asarray(ef).astype(int)
    ba, ea = b[..., 3] > 0, e[..., 3] > 0
    best = np.full(ba.shape, 1e9)
    H, W = ba.shape
    for dy in range(-rad, rad + 1):
        for dx in range(-rad, rad + 1):
            sb = np.zeros_like(b); sb[max(0, dy):H + min(0, dy), max(0, dx):W + min(0, dx)] = b[max(0, -dy):H - max(0, dy), max(0, -dx):W - max(0, dx)]
            d = np.sqrt(((sb[..., :3] - e[..., :3]) ** 2).sum(-1)); d[sb[..., 3] == 0] = 1e9
            best = np.minimum(best, d)
    m = ea & (best > thr)
    ys = np.nonzero(ba.any(1))[0]; top, bot = ys.min(), ys.max()
    if region == 'head':
        m[top + int((bot - top) * 0.36):] = False
    m = binary_closing(m, iterations=1) & ea
    lab, n = label(m)
    if n:
        sz = np.bincount(lab.ravel()); sz[0] = 0; big = sz.max()
        keep = sz >= max(8, big * 0.15); keep[0] = False; m = keep[lab]
    # crescimento: vizinhos que mudaram no MESMO pixel (ou nao existiam na original) entram no item
    same = np.sqrt(((b[..., :3] - e[..., :3]) ** 2).sum(-1))
    grow_ok = ea & (~ba | (same > grow_thr))
    if region == 'head':
        grow_ok[top + int((bot - top) * 0.36):] = False
    for _ in range(grow):
        m = m | (binary_dilation(m) & grow_ok)
    # buracos pequenos (ate 12 px) dentro do item entram
    holes = binary_fill_holes(m) & ~m; hl, hn = label(holes)
    if hn:
        hs = np.bincount(hl.ravel()); small = hs <= 12; small[0] = False; m |= small[hl]
    m &= ea
    out = np.zeros_like(e); out[m] = e[m]; return Image.fromarray(out.astype(np.uint8), 'RGBA')


def breathe_like(fr, body_fr):
    a = np.asarray(fr).copy(); bb = np.asarray(body_fr)[..., 3] > 0; ys = np.nonzero(bb.any(1))[0]
    top, bot = ys.min(), ys.max(); cut = top + int((bot - top) * 0.55)
    lo = min(top, np.nonzero(a[..., 3].any(1))[0].min()) if a[..., 3].any() else top
    up = a[lo:cut].copy(); a[lo:cut] = 0; a[lo + 1:cut + 1] = np.where(up[..., 3:] > 0, up, a[lo + 1:cut + 1])
    return Image.fromarray(a, 'RGBA')


def bob(fr, dy):
    o = Image.new('RGBA', (FR, FR)); o.alpha_composite(fr, (0, dy)); return o


def quant(frames_, n):
    fs = [f for f in frames_ if np.asarray(f)[..., 3].any()]
    strip = Image.new('RGB', (FR * max(1, len(fs)), FR))
    for i, f in enumerate(fs): strip.paste(f.convert('RGB'), (i * FR, 0), f)
    pal = strip.quantize(n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    def q(f):
        r = f.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE).convert('RGBA'); r.putalpha(f.getchannel('A')); return r
    return q


def assemble(per, body_frames, name_rows=None):
    """per[(anim, dir, tag)] -> quadro. Devolve {anim: [[quadros por coluna] por linha]} como o build_sheets."""
    sheets = {'idle': [], 'walk': [], 'sit': []}
    for d in DIRS:
        i = per[('idle', d, 'idle')]; bi = body_frames[('idle', d, 'idle')]
        b = breathe_like(i, bi); sheets['idle'].append([i, i, b, b])
        wi = per[('walk', d, 'widle')]; wl = per[('walk', d, 'wl')]; wr = per[('walk', d, 'wr')]
        sheets['walk'].append([wl, wl, bob(wi, -1), wi, wr, wr, bob(wi, -1), wi])
        sheets['sit'].append([per[('sit', d, 'sit')]])
    return sheets


def save(sheets, base, q, rows_mask=None):
    for anim, rows in sheets.items():
        sh = Image.new('RGBA', (FR * len(rows[0]), FR * 5))
        for r, row in enumerate(rows):
            if rows_mask is not None and not rows_mask(DIRS[r]): continue
            for c, f in enumerate(row): sh.alpha_composite(q(f), (c * FR, r * FR))
        os.makedirs(os.path.dirname(base), exist_ok=True); sh.save(f'{base}_{anim}.png'); print('saved', f'{base}_{anim}.png')


def cmd_sitsheet(body):
    fs = frames(body); per = {}; bodyf = {}
    for an, d, t, src, fl, H in fs:
        o = prep(os.path.join(work(body), 'rb_' + src), fl); f, _ = render(o, params(o, H)); per[(an, d, t)] = f; bodyf[(an, d, t)] = f
    ref = os.path.join(GAME, 'assets', 'characters', f'chr_traveler_{body}_idle.png')
    cols = {tuple(c[:3]) for c in np.asarray(Image.open(ref).convert('RGBA')).reshape(-1, 4) if c[3] > 0}
    pal = Image.new('P', (1, 1)); flat = [v for c in sorted(cols) for v in c]; pal.putpalette(flat + [0] * (768 - len(flat)))
    q = lambda f: (lambda r: (r.putalpha(f.getchannel('A')), r)[1])(f.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE).convert('RGBA'))
    sh = assemble(per, bodyf)
    save({'sit': sh['sit']}, os.path.join(GAME, 'assets', 'characters', f'chr_traveler_{body}'), q)


def cmd_edit(body, visual, only=None):
    from npc_pipeline import run_edits
    from rmbg import rmbg
    V = VISUALS[visual]; wd = work(body); od = os.path.join(wd, 'eq', visual); os.makedirs(od, exist_ok=True)
    srcs = {}
    for an, d, t, src, fl, H in frames(body):
        if only and src != only: continue
        txt = V['text'] + (' The character stays ' + SIT_TXT + '.' if an == 'sit' else '') + KEEP
        srcs[src] = [os.path.join(wd, src), txt, os.path.join(od, src), 4242]
    run_edits(list(srcs.values()))
    import concurrent.futures as cf, time
    def rb(s):
        for t in range(6):
            try: return rmbg(os.path.join(od, s), os.path.join(od, 'rb_' + s))
            except Exception as e:
                if '429' not in str(e) or t == 5: raise
                time.sleep(10 * (t + 1))
    todo = [s for s in srcs if os.path.exists(os.path.join(od, s)) and not os.path.exists(os.path.join(od, 'rb_' + s))]
    with cf.ThreadPoolExecutor(3) as ex:
        for f in cf.as_completed([ex.submit(rb, s) for s in todo]):
            try: f.result()
            except Exception as e: print('rmbg err', str(e)[:120])
    print('edits:', len(srcs))


def cmd_build(body, visual):
    V = VISUALS[visual]; per = {}; bodyf = {}; missing = 0
    for an, d, t, src, fl, H in frames(body):
        base, ef = edited_frame(body, visual, src, fl, H); bodyf[(an, d, t)] = base
        if ef is None: missing += 1; ef = Image.new('RGBA', (FR, FR)) if V['kind'] == 'layer' else base
        per[(an, d, t)] = ef if V['kind'] == 'outfit' else extract(base, ef, V['region'])
    if missing: print('AVISO: %d quadro(s) sem edicao' % missing)
    sheets = assemble(per, bodyf)
    if V['kind'] == 'outfit':
        allf = [f for rows in sheets.values() for r in rows for f in r]
        save(sheets, os.path.join(GAME, 'assets', 'characters', 'outfits', f'chr_{body}_{visual}'), quant(allf, 48))
        return
    allf = [f for rows in sheets.values() for r in rows for f in r]; q = quant(allf, 32)
    base = os.path.join(GAME, 'assets', 'equipment', V['slot'], visual, body)
    back = V.get('back_rows')
    if back:
        save(sheets, base, q, lambda d: d not in back)
        save(sheets, base + '_back'.replace(body + '_back', body + '_back'), q, lambda d: d in back) if False else None
        for anim, rows in sheets.items():
            sh = Image.new('RGBA', (FR * len(rows[0]), FR * 5))
            for r, row in enumerate(rows):
                if DIRS[r] in back:
                    for c, f in enumerate(row): sh.alpha_composite(q(f), (c * FR, r * FR))
            sh.save(f'{base}_{anim}_back.png'); print('saved', f'{base}_{anim}_back.png')
    else:
        save(sheets, base, q)


def sides(body, visual):
    """Lado (L/R da imagem, pelo centroide do item em relacao ao centro do corpo) de cada quadro de arma."""
    V = VISUALS[visual]; out = {}
    for an, d, t, src, fl, H in frames(body):
        if t == 'widle': continue
        base, ef = edited_frame(body, visual, src, fl, H)
        if ef is None: continue
        ov = np.asarray(extract(base, ef, V['region']))[..., 3] > 0
        bx = np.nonzero(np.asarray(base)[..., 3] > 0)[1].mean()
        out[(an, d, t)] = (src, fl, ('L' if np.nonzero(ov)[1].mean() < bx else 'R') if ov.any() else '?')
    return out


def cmd_fixsides(body, visual):
    """Refaz (com lado explicito) os quadros cuja arma esta do lado oposto ao da maioria da linha idle/wl/wr."""
    from npc_pipeline import run_edits
    import shutil
    S = sides(body, visual); wd = work(body); od = os.path.join(wd, 'eq', visual); jobs = []
    for d in DIRS:
        row = [S.get((an, d, t)) for an, t in (('walk', 'wl'), ('idle', 'idle'), ('walk', 'wr'))]
        got = [r[2] for r in row if r]
        want = max(set(got), key=got.count) if got else None
        todo = [r for r in row if r and r[2] != want]
        sit = S.get(('sit', d, 'sit'))
        if sit and sit[2] not in (want, '?') and False: todo.append(sit)
        print(body, visual, d, [r[2] for r in row if r], '->', want, [r[0] for r in todo])
        for src, fl, side in todo:
            img_side = want if not fl else ('L' if want == 'R' else 'R')  # a fonte nao esta espelhada
            txt = VISUALS[visual]['text'] + (' It is held in the hand on the %s side of the image.' % ('LEFT' if img_side == 'L' else 'RIGHT')) + KEEP
            os.makedirs(os.path.join(od, 'rejected'), exist_ok=True)
            for f in (src, 'rb_' + src):
                if os.path.exists(os.path.join(od, f)): shutil.move(os.path.join(od, f), os.path.join(od, 'rejected', f))
            jobs.append([os.path.join(wd, src), txt, os.path.join(od, src), 5151])
    run_edits(jobs)
    from rmbg import rmbg
    for j in jobs:
        if os.path.exists(j[2]): rmbg(j[2], os.path.join(od, 'rb_' + os.path.basename(j[2])))


if __name__ == '__main__':
    c, body, *rest = sys.argv[1:]
    if c == 'sitsheet': cmd_sitsheet(body)
    elif c == 'edit': cmd_edit(body, rest[0], rest[2] if len(rest) > 2 and rest[1] == '--only' else None)
    elif c == 'build': cmd_build(body, rest[0])
    elif c == 'fixsides': cmd_fixsides(body, rest[0])
