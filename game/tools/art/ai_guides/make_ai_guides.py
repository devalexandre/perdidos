#!/usr/bin/env python3
"""Pranchas-guia de pose PROPRIAS para a IA de imagem (ChatGPT), a partir do nosso manequim no Blender.

    blender -b --python tools/art/ai_guides/render_guides.py -- male --out <render>      (e female)
    python3 tools/art/ai_guides/make_ai_guides.py <render> <saida_png> [male female]

Entrada: <render>/<body>.npz/.json (ids por pixel e juntas 2D do render_guides.py; canvas 144 x ss).
Saida:
  <saida_png>/<body>_<parte>.png                      pranchas-guia (as do kit do dono)
  tools/art/ai_guides/<body>_layout.json              grade de cada parte, escala e origem de cada celula,
                                                      pescoco por quadro (quadro 96 do jogo)
  tools/art/ai_guides/<body>_masks.npz                silhueta da guia por quadro no quadro 96 do jogo
O importador (tools/art/import_ai_sheet.py) usa layout + mascaras para fatiar e alinhar o que a IA devolve.

Escala: o corpo da guia e posto no quadro 96 do jogo com o pescoco onde o corpo-base do jogo tem o queixo
(menos 2 px) e os pes na linha do chao (GROUND_Y), para a cabeca do jogo encaixar sem outra reescala.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import import_ai_sheet as IM  # noqa: E402

RENDER_ANIM = {'idle': 'idle', 'walk': 'walk', 'attack': 'attack_unarmed', 'cast': 'cast', 'hit': 'hit',
               'death': 'death', 'sit': 'sit'}
BG = (255, 255, 255)
C_TORSO, C_NEAR, C_FAR = (168, 168, 168), (200, 200, 200), (122, 122, 122)
C_EDGE, C_BONE, C_NECK, C_CELL, C_TXT = (64, 64, 64), (86, 86, 86), (225, 30, 30), (214, 214, 214), (60, 60, 60)
LIMBS = {'uarm', 'farm', 'hand', 'thigh', 'shin', 'foot'}
BONES = [('pelvis', 'spine'), ('spine', 'chest'), ('chest', 'neck'),
         ('chest', 'uarm_L'), ('uarm_L', 'farm_L'), ('farm_L', 'hand_L'),
         ('chest', 'uarm_R'), ('uarm_R', 'farm_R'), ('farm_R', 'hand_R'),
         ('pelvis', 'thigh_L'), ('thigh_L', 'shin_L'), ('shin_L', 'foot_L'),
         ('pelvis', 'thigh_R'), ('thigh_R', 'shin_R'), ('shin_R', 'foot_R')]
FONT = '/usr/share/fonts/TTF/DejaVuSans.ttf'
FONT_B = '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'


def font(sz, bold=False):
    try:
        return ImageFont.truetype(FONT_B if bold else FONT, sz)
    except OSError:
        return ImageFont.load_default()


def base_neck(body):
    """Queixo do corpo-base no idle S (quadro 0): onde o pescoco do corpo novo tem de chegar."""
    _, _, chin = IM.base_head(body, 'idle', 0, 0)
    return float(chin[0]), float(chin[1]) - 2.0


def build(render, out_png, body, fake_dir=None):
    z = np.load(os.path.join(render, f'{body}.npz')); meta = json.load(open(os.path.join(render, f'{body}.json')))
    ss = meta['ss']; parts = meta['parts']
    CX = meta['origin'][0]              # centro horizontal do canvas (a origem dos pes)
    names = [p['name'] if p else '' for p in parts]
    group = np.array([0] + [0 if n in ('torso', 'pelvis', 'neck') else
                            (1 if n.endswith('_L') else 2) if n.split('_')[0] in LIMBS else 3
                            for n in names[1:]])     # 0 tronco, 1 membro esq, 2 membro dir, 3 cabeca/outros (fora)
    ids = {a: z[f'{RENDER_ANIM[a]}_id'] for a in IM.GUIDE_ANIMS}
    dirs = list(z['idle_dirs'])
    assert dirs == IM.DIRS, dirs
    joints = {a: meta['joints'][RENDER_ANIM[a]] for a in IM.GUIDE_ANIMS}
    # escala: pescoco da guia (idle S 0) -> queixo do corpo-base - 2; pes -> GROUND_Y
    bx, by = base_neck(body)
    nk = joints['idle']['S'][0]['head_base']
    idle0 = ids['idle'][0, 0] > 0
    ground_c = (np.nonzero(idle0.any(1))[0].max() + 0.5) / ss
    k = (IM.GROUND_Y - by) / (ground_c - nk[1])

    def fmap(xc, yc, sx, dy):          # canvas -> quadro do jogo
        return (xc - CX) * k + 48 + sx, (yc - ground_c) * k + IM.GROUND_Y + dy

    def keep_ids(a, di, f):
        I = ids[a][di, f].copy()
        I[group[I] == 3] = 0
        # tira o que sobrou acima da base do cranio (restos da cabeca): o pescoco termina reto ali
        # (so tronco/pescoco: bracos erguidos acima do pescoco ficam)
        hb = joints[a][IM.DIRS[di]][f]['head_base']
        top = I[: int(np.ceil(hb[1] * ss)), :]
        top[group[top] == 0] = 0
        return I

    # deslocamentos: por quadro (pes no chao, animacoes em pe) e por animacao (x, para caber no quadro)
    frame_dy, anim_sx = {}, {}
    cache = {}
    for a, (_, n, _) in IM.GUIDE_ANIMS.items():
        xs_all, bots = [], []
        for di in range(5):
            for f in range(n):
                I = keep_ids(a, di, f); cache[(a, di, f)] = I
                ys, xs = np.nonzero(I)
                bot = (ys.max() + 0.5) / ss
                frame_dy[(a, di, f)] = ((ground_c - bot) * k) if a in IM.STANDING else 0.0
                bots.append((bot - ground_c) * k + IM.GROUND_Y)
                xs_all += [xs.min() / ss, xs.max() / ss]
        u0, u1 = (min(xs_all) - CX) * k + 48, (max(xs_all) - CX) * k + 48
        anim_sx[a] = 0.0 if (u0 >= 2 and u1 <= 93) else (47.5 - (u0 + u1) / 2)
        if a not in IM.STANDING:     # sentar/caido: a figura inteira sobe se passar da linha do chao
            up = min(0.0, IM.GROUND_Y - 0.5 - max(bots))
            for di in range(5):
                for f in range(n):
                    frame_dy[(a, di, f)] = up

    # mascaras no quadro 96 (4x4 amostras por pixel, maioria)
    masks, neck = {}, {}
    sub = (np.arange(4) + 0.5) / 4
    uu = (np.arange(96)[:, None] + sub[None]).ravel()
    for a, (_, n, _) in IM.GUIDE_ANIMS.items():
        M = np.zeros((5, n, 96, 96), bool)
        neck[a] = {}
        for di, d in enumerate(IM.DIRS):
            neck[a][d] = []
            for f in range(n):
                I = cache[(a, di, f)]; sx = anim_sx[a]; dy = frame_dy[(a, di, f)]
                xc = (uu - 48 - sx) / k + CX; yc = (uu - IM.GROUND_Y - dy) / k + ground_c
                xi = np.clip((xc * ss).astype(int), 0, I.shape[1] - 1); yi = np.clip((yc * ss).astype(int), 0, I.shape[0] - 1)
                S = I[yi[:, None], xi[None, :]] > 0
                M[di, f] = S.reshape(96, 4, 96, 4).mean((1, 3)) >= 0.5
                hb = joints[a][d][f]['head_base']
                u, v = fmap(hb[0], hb[1], sx, dy)
                neck[a][d].append([round(u, 2), round(v, 2)])
        masks[a] = M
    # prancha por parte
    layout = dict(body=body, k=round(k, 4), ground_y=IM.GROUND_Y, base_neck=[bx, by], anim_shift_x=anim_sx,
                  neck=neck, parts={})
    for part, P in IM.PARTS.items():
        W, H = P['size']
        cells, labels, rows = IM.grid(part)
        anims = [a for b in P['blocks'] for a in b]
        # janela comum (px do jogo) a todas as figuras da parte
        un = np.zeros((96, 96), bool)
        for a in anims:
            un |= masks[a].any((0, 1))
        ys, xs = np.nonzero(un)
        wx0, wx1, wy0, wy1 = xs.min() - 2, xs.max() + 3, ys.min() - 3, min(96, ys.max() + 3)
        cw, ch = cells[next(iter(cells))][2:]
        s = min((cw - 2 * IM.PAD) / (wx1 - wx0), (ch - 2 * IM.PAD) / (wy1 - wy0))
        img = Image.new('RGB', (W, H), BG)
        dr = ImageDraw.Draw(img)
        pc = {}
        arr = np.asarray(img).copy()
        fake = arr.copy() if fake_dir else None
        for (a, d, f), (x, y, w, h) in cells.items():
            ox = x + IM.PAD + ((w - 2 * IM.PAD) - (wx1 - wx0) * s) / 2 - wx0 * s
            oy = y + IM.PAD + ((h - 2 * IM.PAD) - (wy1 - wy0) * s) / 2 - wy0 * s
            pc['%s|%s|%d' % (a, d, f)] = dict(rect=[round(x, 2), round(y, 2), round(w, 2), round(h, 2)],
                                              scale=round(s, 4), ox=round(ox, 3), oy=round(oy, 3))
            di = IM.DIRS.index(d); I = cache[(a, di, f)]; sx = anim_sx[a]; dy = frame_dy[(a, di, f)]
            X0, Y0, X1, Y1 = int(x), int(y), int(x + w), int(y + h)
            Xs = np.arange(X0, X1) + 0.5; Ys = np.arange(Y0, Y1) + 0.5
            xc = ((Xs - ox) / s - 48 - sx) / k + CX; yc = ((Ys - oy) / s - IM.GROUND_Y - dy) / k + ground_c
            xi = (xc * ss).astype(int); yi = (yc * ss).astype(int)
            ok = (xi[None] >= 0) & (xi[None] < I.shape[1]) & (yi[:, None] >= 0) & (yi[:, None] < I.shape[0])
            Pid = np.where(ok, I[np.clip(yi, 0, I.shape[0] - 1)[:, None], np.clip(xi, 0, I.shape[1] - 1)[None]], 0)
            G = group[Pid]
            jf = joints[a][d][f]
            far_arm = 1 if jf['uarm_L'][2] > jf['uarm_R'][2] else 2
            far_leg = 1 if jf['thigh_L'][2] > jf['thigh_R'][2] else 2
            is_leg = np.isin(np.array([n.split('_')[0] for n in names])[Pid], ['thigh', 'shin', 'foot'])
            far = np.where(is_leg, G == far_leg, G == far_arm) & (G > 0)
            fg = Pid > 0
            # rotulos: 1 tronco, 2 braco perto, 3 braco longe, 4 perna perto, 5 perna longe
            K = np.where(fg, 1, 0)
            K = np.where(fg & (G > 0) & ~is_leg, np.where(far, 3, 2), K)
            K = np.where(fg & (G > 0) & is_leg, np.where(far, 5, 4), K)
            # suaviza as bordas serrilhadas das faces (maioria com peso gaussiano); o fundo pesa um pouco menos
            # (a silhueta engorda ~0,5 px do jogo: roupa)
            sig = max(1.0, s * 0.55)
            Wt = np.stack([ndi.gaussian_filter((K == l).astype(np.float32), sig) * (0.8 if l == 0 else 1.0)
                           for l in range(6)])
            K = Wt.argmax(0)
            fg = K > 0
            col = np.zeros(K.shape + (3,), np.uint8); col[:] = BG
            col[K == 1] = C_TORSO
            col[(K == 2) | (K == 4)] = C_NEAR
            col[(K == 3) | (K == 5)] = C_FAR
            edge = np.zeros_like(fg)
            for sy, sx_ in ((0, 1), (1, 0), (0, -1), (-1, 0)):
                edge |= fg & (np.roll(K, (sy, sx_), (0, 1)) != K)
            edge = ndi.binary_dilation(edge, iterations=1) & fg
            col[edge] = C_EDGE
            arr[Y0:Y1, X0:X1] = col
            if fake is not None:
                u, v = neck[a][d][f]
                fake[Y0:Y1, X0:X1] = paint_uniform(Pid, fg, far, names, s, u * s + ox - X0, v * s + oy - Y0)
        img = Image.fromarray(arr); dr = ImageDraw.Draw(img)
        for (a, d, f), (x, y, w, h) in cells.items():
            dr.rectangle([x, y, x + w, y + h], outline=C_CELL, width=2)
            c = pc['%s|%s|%d' % (a, d, f)]; sx = anim_sx[a]; dy = frame_dy[(a, IM.DIRS.index(d), f)]
            jf = joints[a][d][f]

            def P2(nm):
                u, v = fmap(jf[nm][0], jf[nm][1], sx, dy)
                return (u * c['scale'] + c['ox'], v * c['scale'] + c['oy'])
            lw = max(2, int(round(c['scale'] * 0.9)))
            for j0, j1 in BONES:
                if j0 in jf and j1 in jf:
                    dr.line([P2(j0), P2(j1)], fill=C_BONE, width=lw)
            for nm in ('uarm_L', 'farm_L', 'hand_L', 'uarm_R', 'farm_R', 'hand_R', 'thigh_L', 'shin_L', 'foot_L',
                       'thigh_R', 'shin_R', 'foot_R'):
                px, py = P2(nm); rr = lw * 0.9
                dr.ellipse([px - rr, py - rr, px + rr, py + rr], fill=C_BONE)
            u, v = neck[a][d][f]
            nx, ny = u * c['scale'] + c['ox'], v * c['scale'] + c['oy']
            r = max(4, c['scale'] * 2.2)
            dr.line([nx - r, ny, nx + r, ny], fill=C_NECK, width=2); dr.line([nx, ny - r, nx, ny + r], fill=C_NECK, width=2)
        fl, fb = font(15), font(20, True)
        sexo = 'masculino' if body == 'male' else 'feminino'
        idx = IM.PART_ORDER.index(part) + 1
        dr.text((IM.MARGIN_L, 10), f'PERDIDOS - guia de pose (nossa) - corpo {sexo} - parte {idx}/4: {P["title"]}',
                fill=C_TXT, font=fb)
        dr.text((IM.MARGIN_L, 40), 'Linhas: S (frente), SE, L (perfil), NE, N (costas). Corpo SEM cabeca; '
                'cruz vermelha = pescoco.', fill=C_TXT, font=fl)
        dr.text((IM.MARGIN_L, 60), 'Cinza claro = lado de perto; escuro = lado de longe. Mantenha grade, '
                'posicoes e quadros.', fill=C_TXT, font=fl)
        fs = font(14)
        for t, x, y in labels:
            dr.text((x, y), t, fill=C_TXT, font=fs, anchor='mm')
        for t, x, y in rows:
            dr.text((x, y), t, fill=C_TXT, font=font(16, True), anchor='mm')
        os.makedirs(out_png, exist_ok=True)
        img.save(os.path.join(out_png, f'{body}_{part}.png'))
        layout['parts'][part] = dict(size=[W, H], window=[int(wx0), int(wy0), int(wx1), int(wy1)], cells=pc)
        if fake is not None:
            # "devolucao" falsa: deslocada (+9, -7) e noutra resolucao, como o ChatGPT faria
            fim = Image.fromarray(fake); fd = ImageDraw.Draw(fim)
            for (x, y, w, h) in cells.values():
                fd.rectangle([x, y, x + w, y + h], outline=(222, 222, 218), width=2)
            fake = np.asarray(fim)
            fk = np.full_like(fake, 255); fk[0:H - 7, 9:W] = fake[7:H, 0:W - 9]
            os.makedirs(fake_dir, exist_ok=True)
            Image.fromarray(fk).resize((int(W * 0.8165), int(H * 0.8165)), Image.LANCZOS).save(
                os.path.join(fake_dir, f'{body}_{part}.png'))
    json.dump(layout, open(os.path.join(HERE, f'{body}_layout.json'), 'w'), indent=1)
    np.savez_compressed(os.path.join(HERE, f'{body}_masks.npz'), **masks)
    print(body, 'k', round(k, 3), 'shift x', {a: round(v, 1) for a, v in anim_sx.items() if v})


UNIFORM = {'torso': (238, 238, 232), 'neck': (232, 184, 146), 'pelvis': (38, 50, 92), 'uarm': (238, 238, 232),
           'farm': (232, 184, 146), 'hand': (232, 184, 146), 'thigh': (38, 50, 92), 'shin': (232, 184, 146),
           'foot': (246, 246, 246)}
GREEN, YELLOW = (28, 140, 72), (244, 198, 38)


def paint_uniform(Pid, fg, far, names, s, nx, ny):
    """Teste do importador: pinta a silhueta como se fosse o uniforme (camiseta branca com gola verde e barra amarela
    na manga, bermuda azul-marinho, tenis branco), com contorno escuro colorido e sombra do lado de longe."""
    base = np.array([n.split('_')[0] if n else '' for n in names])
    _, (iy, ix) = ndi.distance_transform_edt(Pid == 0, return_indices=True)
    P = Pid[iy, ix]
    cat = base[P]
    h, w = Pid.shape
    col = np.full((h, w, 3), 255, np.float32)
    for c, rgb in UNIFORM.items():
        col[fg & (cat == c)] = rgb
    Y, X = np.mgrid[0:h, 0:w]
    collar = fg & np.isin(cat, ['torso', 'neck']) & (Y < ny + 3.0 * s) & (np.abs(X - nx) < 5.0 * s)
    col[collar] = GREEN
    farm = np.isin(cat, ['farm', 'hand'])
    near_farm = ndi.distance_transform_edt(~farm) < 1.6 * s
    col[fg & (cat == 'uarm') & near_farm] = YELLOW
    farp = fg & far[iy, ix]
    col[farp] *= 0.80
    # luz de cima-esquerda: 1 px claro no topo/esquerda de cada peca, 1 px escuro embaixo/direita
    lab = np.where(fg, (col[..., 0] // 4) * 4096 + (col[..., 1] // 4) * 64 + col[..., 2] // 4, -1)
    hi = fg & ((np.roll(lab, 2, 0) != lab) | (np.roll(lab, 2, 1) != lab))
    lo = fg & ((np.roll(lab, -3, 0) != lab) | (np.roll(lab, -3, 1) != lab))
    col[lo] *= 0.82
    col[hi & ~lo] = np.minimum(255, col[hi & ~lo] * 1.08 + 8)
    edge = np.zeros_like(fg)
    for sy, sx_ in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        edge |= fg & (np.roll(lab, (sy, sx_), (0, 1)) != lab)
    edge = ndi.binary_dilation(edge, iterations=max(1, int(s * 0.45))) & fg
    col[edge] = col[edge] * 0.38 + np.array([0, 4, 14])
    return np.clip(col, 0, 255).astype(np.uint8)


if __name__ == '__main__':
    args = sys.argv[1:]
    fake = None
    if '--fake' in args:          # teste: tambem escreve uma "devolucao" falsa pintada com o uniforme
        i = args.index('--fake'); fake = args[i + 1]; del args[i:i + 2]
    render, out_png = args[0], args[1]
    for b in (args[2:] or ['male', 'female']):
        build(render, out_png, b, fake)
