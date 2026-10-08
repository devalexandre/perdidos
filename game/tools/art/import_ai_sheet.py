#!/usr/bin/env python3
"""Importa a prancha que o ChatGPT (ou outra IA) devolve a partir das NOSSAS pranchas-guia de pose e escreve as folhas
de roupa do jogo (corpo sem cabeca), com o anchors.json do pescoco. Kit do dono: docs/kit-chatgpt-student-pindorama.md.

    python3 tools/art/import_ai_sheet.py <body> <outfit_id> <imagem_p1> <imagem_p2> ... [--out DIR] [--work DIR]
            [--colors 32] [--compose-head] [--preview]

Cada imagem e uma parte da prancha-guia (p1_parado, p2_andar, p3_combate, p4_dano); a parte sai do nome do arquivo
(`<body>_<parte>.png`, ex. male_p2_andar.png) ou da ordem dos argumentos. Guias e grade: tools/art/ai_guides/
(<body>_layout.json + <body>_masks.npz, gerados por tools/art/ai_guides/make_ai_guides.py).

Passos por quadro:
  1. fundo: alfa da imagem, se houver; senao a cor da borda da prancha, removida por preenchimento a partir das
     bordas de cada celula (o branco da camiseta cercado de contorno continua);
  2. fatia pela grade conhecida, com um deslocamento global (correlacao com as silhuetas da guia, +-48 px) e
     tolerancia por celula (a figura pode passar um pouco da celula);
  3. escala unica por prancha (mediana figura/guia) -> quadro 96x96, reducao BOX com alfa binario;
  4. pes: nas animacoes em pe a base da figura vai para a linha do chao do jogo (GROUND_Y); na queda e no sentar,
     para a base da guia; x pelo melhor encaixe (IoU) com a silhueta da guia;
  5. paleta unica por corpo+roupa (corte mediano, sem pontilhado, <= --colors) e contorno colorido de 1 px
     (a borda da silhueta vira o tom escuro da propria cor);
  6. pescoco: topo da gola perto do pescoco da guia -> anchors.json.

Saida (formato do jogo, docs/briefing-sprites-personagem.md §1):
  <out>/chr_<body>_<outfit>_<anim>.png   linhas S, SE, L, NE, N; quadros 96x96
      idle 4, walk 8, sit 1, attack_unarmed 6, cast 6, hit 4, death 6   (ver ADAPTACOES)
  <out>/chr_<outfit>_anchors.json        formato de tools/art/combat_anims/head_anchors.json:
      [body][anim][linha][coluna] = {dx, dy, mirror_idle, key, fit}; dx, dy = deslocamento do pescoco em relacao ao
      quadro 0 do idle da mesma linha; "_neck_idle0"[body][linha] = pescoco absoluto (x, y) desse quadro 0.
  <work>/report_<body>.json, <work>/contact_<body>.png (e preview_<body>_*.gif com --preview); <work> padrao =
  .work/import_<outfit> (fora do jogo). --check: so confere as partes dadas, nada vai para o jogo.

--compose-head (so para instalar no jogo hoje): o jogo ainda desenha a cabeca DENTRO da folha do corpo (corpo-base +
mascara; olhos e cabelo sao camadas presas a posicao da cabeca do corpo-base). Com esta opcao a cabeca raspada do
corpo-base (mesma animacao, linha e quadro) e colada sobre o corpo importado e sai tambem a mascara
chr_<body>_<outfit>_mask_<anim>.png (R pele, G olhos, B raspado; pele do corpo por cor). So as animacoes que o
corpo-base tem (idle, walk, sit, attack_unarmed, cast, death); o relatorio mede o desencontro pescoco x cabeca.

ADAPTACOES guia -> jogo (o jogo manda):
  guia "ataque" 6  -> attack_unarmed 6 (com arma o jogo cai no attack_unarmed quando nao ha attack_<arma>);
  guia "dano" 3    -> hit 4 (quadros 0,1,2,1: o validador aceita 2 ou 4 e o 4o volta suave para o idle);
  guia "caido" 5   -> death 6 (repete o ultimo; o jogo segura o ultimo quadro da morte);
  linha "L" da guia = linha "E" (3a) das folhas.

Erros claros: quadro vazio ou faltando ("p2_andar: quadro walk SE 3 vazio") -> nada e escrito (exit 2).
"""
import argparse, json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, '..', '..'))
GUIDE_DIR = os.path.join(HERE, 'ai_guides')
FRAME = 96
GROUND_Y = 94                          # linha dos pes no quadro 96 (a do corpo-base do jogo)
DIRS = ['S', 'SE', 'E', 'NE', 'N']     # ordem das linhas das folhas (E = "L" na guia)
DIR_LABEL = {'S': 'S', 'SE': 'SE', 'E': 'L', 'NE': 'NE', 'N': 'N'}
# animacao da guia -> (animacao do jogo, quadros da guia, indices dos quadros na folha do jogo)
GUIDE_ANIMS = {
    'idle': ('idle', 4, [0, 1, 2, 3]),
    'walk': ('walk', 8, list(range(8))),
    'sit': ('sit', 1, [0]),
    'attack': ('attack_unarmed', 6, list(range(6))),
    'cast': ('cast', 6, list(range(6))),
    'hit': ('hit', 3, [0, 1, 2, 1]),
    'death': ('death', 5, [0, 1, 2, 3, 4, 4]),
}
STANDING = {'idle', 'walk', 'attack', 'cast', 'hit'}
MIN_MEDIAN_IOU = 0.65   # abaixo disto a IA nao seguiu a guia (pose/direcao/tamanho) e a importacao e recusada
# partes da prancha: tamanho (px, os da geracao do ChatGPT) e blocos (cada bloco = 5 linhas de direcoes; as animacoes
# do bloco ficam lado a lado)
PARTS = {
    'p1_parado': dict(size=(1536, 1024), blocks=[['idle', 'sit']], title='parado (4) e sentar (1)'),
    'p2_andar': dict(size=(1536, 1024), blocks=[['walk']], title='andar (8)'),
    'p3_combate': dict(size=(1024, 1536), blocks=[['attack'], ['cast']], title='ataque (6) e conjurar (6)'),
    'p4_dano': dict(size=(1536, 1024), blocks=[['hit', 'death']], title='dano (3) e caido (5)'),
}
PART_ORDER = ['p1_parado', 'p2_andar', 'p3_combate', 'p4_dano']
ANIM_LABEL = {'idle': 'parado', 'walk': 'andar', 'sit': 'sentar', 'attack': 'ataque', 'cast': 'conjurar',
              'hit': 'dano', 'death': 'caido'}
# geometria da grade (px da prancha)
MARGIN_L, MARGIN_R, MARGIN_B = 44, 16, 16
HEADER = 84          # titulo e instrucoes
BLOCK_LABEL = 30     # nomes das colunas acima de cada bloco
GUTTER = 16          # espaco branco entre celulas
PAD = 8              # folga interna da celula ate a figura


def grid(part):
    """Retangulos das celulas: {(anim, dir, frame): (x, y, w, h)} (area desenhavel, sem a calha) + rotulos."""
    P = PARTS[part]; W, H = P['size']; blocks = P['blocks']
    ncols = max(sum(GUIDE_ANIMS[a][1] for a in b) for b in blocks)
    cw = (W - MARGIN_L - MARGIN_R) / ncols
    rh = (H - HEADER - MARGIN_B - BLOCK_LABEL * len(blocks)) / (5 * len(blocks))
    cells, labels, rows = {}, [], []
    y = HEADER
    for b in blocks:
        col = 0
        for a in b:
            n = GUIDE_ANIMS[a][1]
            for f in range(n):
                labels.append((f'{ANIM_LABEL[a]} {f + 1}' if n > 1 else ANIM_LABEL[a],
                               MARGIN_L + (col + f) * cw + cw / 2, y + BLOCK_LABEL / 2))
            for r, d in enumerate(DIRS):
                for f in range(n):
                    x0 = MARGIN_L + (col + f) * cw + GUTTER / 2
                    y0 = y + BLOCK_LABEL + r * rh + GUTTER / 2
                    cells[(a, d, f)] = (x0, y0, cw - GUTTER, rh - GUTTER)
            col += n
        for r, d in enumerate(DIRS):
            rows.append((DIR_LABEL[d], MARGIN_L / 2, y + BLOCK_LABEL + r * rh + rh / 2))
        y += BLOCK_LABEL + 5 * rh
    return cells, labels, rows


def _js(o):
    return o.item() if hasattr(o, 'item') else str(o)


def load_guides(body, guide_dir=GUIDE_DIR):
    lay = json.load(open(os.path.join(guide_dir, f'{body}_layout.json')))
    z = np.load(os.path.join(guide_dir, f'{body}_masks.npz'))
    masks = {a: z[a] for a in z.files}          # [5, F, 96, 96] bool (quadro do jogo)
    return lay, masks


def cell_map(lay, part, key):
    """Transformacao quadro-96 -> prancha para a celula: (sx, ox, oy): prancha = frame * sx + (ox, oy)."""
    c = lay['parts'][part]['cells']['%s|%s|%d' % key]
    return c['scale'], c['ox'], c['oy'], c['rect']


# ------------------------------------------------------------------------------------------------ fundo
def foreground(img, part_size):
    """RGBA uint8 -> mascara de figura (bool) na resolucao da prancha."""
    a = np.asarray(img.convert('RGBA').resize(part_size, Image.LANCZOS)).astype(np.int16)
    if (a[..., 3] < 128).mean() > 0.2:                       # veio com transparencia
        return a, a[..., 3] >= 128
    rgb = a[..., :3]
    border = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3), rgb[:, :6].reshape(-1, 3),
                             rgb[:, -6:].reshape(-1, 3)])
    bg = np.median(border, 0)
    dist = np.abs(rgb - bg).max(-1)
    mx, mn = rgb.max(-1), rgb.min(-1)
    grey = (mx - mn) < 24
    near = (dist < 34) | (grey & (mn > 185))                  # fundo e linhas claras da grade
    return a, near


def cell_figure(near, rect, grow):
    """Figura dentro de um retangulo (x, y, w, h) ampliado por grow: fundo = regiao 'near' ligada a borda."""
    H, W = near.shape
    x, y, w, h = rect
    x0, y0 = max(0, int(x - grow)), max(0, int(y - grow))
    x1, y1 = min(W, int(x + w + grow)), min(H, int(y + h + grow))
    nb = near[y0:y1, x0:x1]
    lab, n = ndi.label(nb)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, edge[edge > 0])
    fg = ~bg
    fg = ndi.binary_opening(fg, iterations=1)
    return fg, (x0, y0)


def keep_main(fg, prior):
    """Fica com os pedacos que tocam a regiao da guia (prior) ou que sao grandes; tira rabiscos e rotulos soltos."""
    lab, n = ndi.label(fg, np.ones((3, 3), bool))
    if n == 0:
        return fg
    sz = np.bincount(lab.ravel()); sz[0] = 0
    hit = np.bincount(lab[prior].ravel(), minlength=n + 1); hit[0] = 0
    keep = (hit > 0.25 * sz) & (sz > 0.004 * sz.max()) | (sz >= 0.5 * sz.max()) & (hit > 0)
    keep[0] = False
    return keep[lab]


# ------------------------------------------------------------------------------------------------ reducao
def box96(rgba, mask, scale, ox, oy):
    """Recorte da prancha -> quadro 96 (px da prancha = frame*scale + (ox, oy)), BOX com alfa pre-multiplicado."""
    n = int(round(FRAME * scale))
    H, W = mask.shape
    can = np.zeros((n, n, 4), np.float32)
    x0, y0 = int(round(ox)), int(round(oy))
    sx0, sy0 = max(0, x0), max(0, y0); sx1, sy1 = min(W, x0 + n), min(H, y0 + n)
    if sx1 > sx0 and sy1 > sy0:
        src = rgba[sy0:sy1, sx0:sx1].astype(np.float32)
        m = mask[sy0:sy1, sx0:sx1].astype(np.float32)
        can[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0, :3] = src[..., :3] * m[..., None]
        can[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0, 3] = m * 255
    ch = [np.asarray(Image.fromarray(np.ascontiguousarray(can[..., c]), 'F').resize((FRAME, FRAME), Image.BOX))
          for c in range(4)]
    al = ch[3]
    out = np.zeros((FRAME, FRAME, 4), np.uint8)
    m = al > 127
    for c in range(3):
        out[..., c][m] = np.clip(ch[c][m] / (al[m] / 255.0), 0, 255)
    out[m, 3] = 255
    return out


def clean_small(fr, min_px=4):
    m = fr[..., 3] > 0
    lab, n = ndi.label(m, np.ones((3, 3), bool))
    if n > 1:
        sz = np.bincount(lab.ravel()); sz[0] = 0
        drop = (sz < min_px) & (sz < sz.max()); drop[0] = False
        fr = fr.copy(); fr[drop[lab]] = 0
    return fr


def shift(img, dx, dy):
    o = np.zeros_like(img); h, w = img.shape[:2]
    o[max(0, dy):min(h, h + dy), max(0, dx):min(w, w + dx)] = img[max(0, -dy):min(h, h - dy), max(0, -dx):min(w, w - dx)]
    return o


def place(fr, gmask, anim):
    """Pes no chao (em pe) ou na base da guia (caido/sentar); x (e y fora do chao) pelo melhor IoU com a guia."""
    al = fr[..., 3] > 0
    if not al.any():
        return fr, (0, 0), 0.0
    ys = np.nonzero(al.any(1))[0]
    gys = np.nonzero(gmask.any(1))[0]
    base = GROUND_Y if anim in STANDING else gys.max()
    dy0 = base - ys.max()
    gx = np.nonzero(gmask)[1].mean(); fx = np.nonzero(al)[1].mean()
    dx0 = int(round(gx - fx))
    best = (-1.0, dx0, dy0)
    dys = [dy0] if anim in STANDING else range(dy0 - 3, dy0 + 4)
    for dy in dys:
        for dx in range(dx0 - 6, dx0 + 7):
            m = shift(al, dx, dy)
            iou = (m & gmask).sum() / max(1, (m | gmask).sum())
            if iou > best[0]:
                best = (iou, dx, dy)
    iou, dx, dy = best
    return shift(fr, dx, dy), (dx, dy), float(iou)


def neck_point(fr, gneck):
    """Topo da gola perto do pescoco da guia: (x, y, fit). Procura so de 3 px acima a 6 px abaixo do pescoco da guia;
    se ja ha figura no topo da janela (braco erguido por cima do pescoco, corpo deitado...), o pescoco esta coberto e
    vale o da guia (a figura ja foi encaixada na silhueta da guia), com fit 0,5. Sem pixels perto: guia, fit 0."""
    al = fr[..., 3] > 0
    gx, gy = gneck
    x0, x1 = max(0, int(round(gx)) - 4), min(FRAME, int(round(gx)) + 5)
    y0, y1 = max(0, int(round(gy)) - 3), min(FRAME, int(round(gy)) + 7)
    win = al[y0:y1, x0:x1]
    if not win.any():
        return float(gx), float(gy), 0.0
    if win[0].any():
        return float(gx), float(gy), 0.5
    top = np.nonzero(win.any(1))[0].min()
    cols = np.nonzero(win[top:top + 2].any(0))[0]
    x = x0 + cols.mean(); y = y0 + top
    d = float(np.hypot(x - gx, y - gy))
    return float(x), float(y), round(max(0.0, 1.0 - d / 8.0), 2)


# ------------------------------------------------------------------------------------------------ paleta
def palette_quantize(frames, ncolors):
    """Uma paleta para todos os quadros (corte mediano sobre os pixels opacos), sem pontilhado."""
    px = np.concatenate([f[f[..., 3] > 0][:, :3] for f in frames if (f[..., 3] > 0).any()])
    side = int(np.ceil(np.sqrt(len(px))))
    strip = np.zeros((side * side, 3), np.uint8); strip[:len(px)] = px; strip[len(px):] = px[0]
    pal = Image.fromarray(strip.reshape(side, side, 3)).quantize(ncolors, method=Image.Quantize.MEDIANCUT,
                                                                   dither=Image.Dither.NONE)
    out = []
    for f in frames:
        q = np.asarray(Image.fromarray(f[..., :3]).quantize(palette=pal, dither=Image.Dither.NONE).convert('RGB'))
        o = np.zeros_like(f); o[..., :3] = q; o[..., 3] = f[..., 3]; o[f[..., 3] == 0] = 0
        out.append(o)
    return out, np.asarray(pal.getpalette()[:ncolors * 3], np.uint8).reshape(-1, 3)


def outline(fr, pal):
    """Contorno colorido: pixel opaco na borda da silhueta vira a cor da paleta mais proxima de (propria cor * 0.45),
    se ele ja nao for escuro. Mantem a silhueta (nao cresce) e fica dentro da paleta."""
    al = fr[..., 3] > 0
    er = ndi.binary_erosion(al, np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool), border_value=0)
    edge = al & ~er
    o = fr.copy()
    lum = fr[..., :3].astype(np.float32) @ np.array([0.3, 0.59, 0.11], np.float32)
    sel = edge & (lum > 70)
    if sel.any():
        want = fr[sel][:, :3].astype(np.float32) * 0.45
        want[:, 2] += 6                                    # puxa um pouco para o frio (contorno nunca preto puro)
        d = ((want[:, None, :] - pal[None].astype(np.float32)) ** 2).sum(-1)
        o[sel, :3] = pal[d.argmin(1)]
    return o


# ------------------------------------------------------------------------------------------------ cabeca (opcional)
def base_head(body, anim, row, col):
    """Cabeca raspada do corpo-base (pixels + mascara) no quadro do jogo; None se a animacao nao existir."""
    bp = os.path.join(GAME, 'assets', 'characters', 'base', f'chr_{body}_base_{anim}.png')
    mp = os.path.join(GAME, 'assets', 'characters', 'base', f'chr_{body}_base_mask_{anim}.png')
    if not (os.path.exists(bp) and os.path.exists(mp)):
        return None
    B = np.asarray(Image.open(bp).convert('RGBA'))[row * 96:(row + 1) * 96, col * 96:(col + 1) * 96]
    M = np.asarray(Image.open(mp).convert('RGBA'))[row * 96:(row + 1) * 96, col * 96:(col + 1) * 96]
    sk = (M[..., :3] > 5).any(-1) & (M[..., 3] > 0)
    if not sk.any():
        return None
    lab, n = ndi.label(sk, np.ones((3, 3), bool))
    ys = np.nonzero(sk.any(1))[0]
    top_lab = lab[ys.min()][sk[ys.min()]][0]
    comp = lab == top_lab
    hy = np.nonzero(comp.any(1))[0]
    # contorno escuro do cabelo/rosto em volta da pele (1-2 px)
    head = ndi.binary_dilation(comp, iterations=2) & (B[..., 3] > 0)
    head &= np.arange(96)[:, None] <= hy.max()
    chin = np.array([np.nonzero(comp[hy.max() - 2:hy.max() + 1])[1].mean(), hy.max()], np.float32)
    Hc = B.copy(); Hc[~head] = 0
    Mc = M.copy(); Mc[~head] = 0
    return Hc, Mc, chin


def skin_mask_tone(fr):
    """Pele a mostra no corpo (maos, bracos, pernas): matiz 5-40, saturacao media, clara. Valor = tom (0-4)."""
    rgb = fr[..., :3].astype(np.float32) / 255
    mx, mn = rgb.max(-1), rgb.min(-1); d = mx - mn + 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = d / (mx + 1e-6)
    skin = (fr[..., 3] > 0) & (h > 5) & (h < 38) & (s > 0.22) & (s < 0.62) & (mx > 0.55) & (r > g) & (g > b)
    tone = np.clip(((mx - 0.5) / 0.5 * 5).astype(int), 0, 4)
    return skin, tone


# ------------------------------------------------------------------------------------------------ principal
def part_of(path, i):
    b = os.path.basename(path)
    for p in PART_ORDER:
        if p in b:
            return p
    return PART_ORDER[i] if i < len(PART_ORDER) else None


def import_body(body, outfit, images, out_dir, work_dir, ncolors=32, compose_head=False, preview=False,
                guide_dir=GUIDE_DIR, check=False):
    lay, gmasks = load_guides(body, guide_dir)
    os.makedirs(work_dir, exist_ok=True)
    frames, report, errors = {}, {'body': body, 'outfit': outfit, 'parts': {}, 'frames': {}}, []
    given = {}
    for i, p in enumerate(images):
        part = part_of(p, i)
        if part is None:
            errors.append(f'{p}: parte desconhecida (use o nome <body>_<parte>.png, partes {PART_ORDER})')
            continue
        given[part] = p
    for part in PART_ORDER:
        if part not in given and not check:
            errors.append(f'{part}: imagem faltando')
    if errors:
        return None, errors
    for part in [p for p in PART_ORDER if p in given]:
        P = PARTS[part]; W, H = P['size']
        img = Image.open(given[part])
        ar_in = img.size[0] / img.size[1]; ar = W / H
        rgba, near = foreground(img, (W, H))
        pl = lay['parts'][part]
        # deslocamento global: silhuetas da guia x figura (em 1/4 da resolucao)
        gsil = np.zeros((H, W), bool)
        for k, c in pl['cells'].items():
            a, d, f = k.split('|'); f = int(f)
            m = gmasks[a][DIRS.index(d), f]
            ys, xs = np.nonzero(m)
            gsil[np.clip((ys * c['scale'] + c['oy']).astype(int), 0, H - 1),
                 np.clip((xs * c['scale'] + c['ox']).astype(int), 0, W - 1)] = True
        gsil = ndi.binary_dilation(gsil, iterations=2)
        fg_all = ~near
        q = 4
        gs = gsil[::q, ::q].astype(np.float32); fs = fg_all[::q, ::q].astype(np.float32)
        best = (-1, 0, 0)
        R = 48 // q
        for dy in range(-R, R + 1):
            for dx in range(-R, R + 1):
                s = (np.roll(gs, (dy, dx), (0, 1)) * fs).sum()
                if s > best[0]:
                    best = (s, dx * q, dy * q)
        _, gdx, gdy = best
        ratios, cellfig = [], {}
        for k, c in pl['cells'].items():
            a, d, f = k.split('|'); f = int(f)
            x, y, w, h = c['rect']
            rect = (x + gdx, y + gdy, w, h)
            fg, (x0, y0) = cell_figure(near, rect, GUTTER * 0.45)
            gm = gmasks[a][DIRS.index(d), f]
            prior = np.zeros_like(fg)
            ys, xs = np.nonzero(ndi.binary_dilation(gm, iterations=3))
            py = np.clip((ys * c['scale'] + c['oy'] + gdy - y0).astype(int), 0, fg.shape[0] - 1)
            px = np.clip((xs * c['scale'] + c['ox'] + gdx - x0).astype(int), 0, fg.shape[1] - 1)
            prior[py, px] = True
            fg = keep_main(fg, prior)
            area_g = gm.sum() * c['scale'] ** 2
            if fg.sum() < 0.12 * area_g:
                errors.append(f'{part}: quadro {a} {DIR_LABEL[d]} {f + 1} vazio ou faltando '
                              f'(figura {int(fg.sum())} px, esperado ~{int(area_g)} px)')
                continue
            fy = np.nonzero(fg.any(1))[0]; gy = np.nonzero(gm.any(1))[0]
            ratios.append((fy.max() - fy.min() + 1) / ((gy.max() - gy.min() + 1) * c['scale']))
            full = np.zeros(near.shape, bool); full[y0:y0 + fg.shape[0], x0:x0 + fg.shape[1]] = fg
            cellfig[k] = full
        if not ratios:
            continue
        r = float(np.median(ratios))
        r = r if 0.6 < r < 1.6 else 1.0
        report['parts'][part] = dict(file=given[part], size_in=list(img.size), aspect_warn=abs(ar_in - ar) > 0.03,
                                     offset=[gdx, gdy], scale_ratio=round(r, 3))
        for k, full in cellfig.items():
            a, d, f = k.split('|'); f = int(f)
            c = pl['cells'][k]
            ys, xs = np.nonzero(full)
            # figura centrada no mesmo ponto da guia, escala r
            sc = c['scale'] * r
            gm = gmasks[a][DIRS.index(d), f]
            gy, gx = np.nonzero(gm)
            cx_s = gx.mean() * c['scale'] + c['ox'] + gdx; by_s = gy.max() * c['scale'] + c['oy'] + gdy
            ox = cx_s - gx.mean() * sc; oy = by_s - gy.max() * sc
            fr = clean_small(box96(rgba, full, sc, ox, oy))
            fr, (dx, dy), iou = place(fr, gm, a)
            frames[(a, d, f)] = fr
            report['frames'][k] = dict(iou=round(iou, 3), shift=[dx, dy])
    # qualidade: a IA seguiu a pose? desenhou cabeca?
    warn = []
    ious = [f['iou'] for f in report['frames'].values()]
    if ious and np.median(ious) < MIN_MEDIAN_IOU:
        errors.append(f'a figura nao segue a guia (IoU mediano {np.median(ious):.2f} < {MIN_MEDIAN_IOU}): pose, direcao '
                      'ou tamanho diferentes; gere de novo pedindo para manter as poses (kit, passo 5)')
    heads = 0
    for (a, d, f), fr in frames.items():
        gx, gy = lay['neck'][a][d][f]
        top = fr[:max(0, int(gy) - 6), max(0, int(gx) - 5):int(gx) + 6, 3] > 0
        heads += top.sum() > 25
    if frames and heads > 0.3 * len(frames):
        errors.append(f'parece que a IA desenhou cabeca em {heads} de {len(frames)} quadros (o corpo tem de parar na gola)')
    low = sorted(k for k, f in report['frames'].items() if f['iou'] < 0.6)
    if low:
        warn.append(f'{len(low)} quadros com IoU < 0,6: ' + ', '.join(low[:12]) + (' ...' if len(low) > 12 else ''))
    report['warnings'] = warn
    if check:          # conferencia de uma parte so: quadros 96 lado a lado, nada vai para o jogo
        os.makedirs(work_dir, exist_ok=True)
        for part in given:
            cells = [k for k in lay['parts'][part]['cells']]
            anims = [a for b in PARTS[part]['blocks'] for a in b]
            cols = sum(GUIDE_ANIMS[a][1] for a in anims)
            board = Image.new('RGBA', (96 * cols, 96 * 5), (88, 112, 80, 255))
            c0 = 0
            for a in anims:
                for f in range(GUIDE_ANIMS[a][1]):
                    for r, d in enumerate(DIRS):
                        if (a, d, f) in frames:
                            board.alpha_composite(Image.fromarray(frames[(a, d, f)]), ((c0 + f) * 96, r * 96))
                c0 += GUIDE_ANIMS[a][1]
            board.resize((board.width * 3, board.height * 3), Image.NEAREST).convert('RGB').save(
                os.path.join(work_dir, f'check_{body}_{part}.png'))
        json.dump(report, open(os.path.join(work_dir, f'check_{body}.json'), 'w'), indent=1, default=_js)
        return report, errors
    if errors:
        return None, errors
    # paleta unica + contorno
    keys = sorted(frames)
    qf, pal = palette_quantize([frames[k] for k in keys], ncolors)
    for k, f in zip(keys, qf):
        frames[k] = outline(f, pal)
    # pescoco
    necks = {}
    for k, fr in frames.items():
        a, d, f = k
        gn = lay['neck'][a][d][f]
        necks[k] = neck_point(fr, gn)
        report['frames']['%s|%s|%d' % k]['neck'] = [round(necks[k][0], 1), round(necks[k][1], 1)]
        report['frames']['%s|%s|%d' % k]['neck_fit'] = necks[k][2]
        report['frames']['%s|%s|%d' % k]['neck_guide'] = [round(gn[0], 1), round(gn[1], 1)]
    # folhas do jogo
    os.makedirs(out_dir, exist_ok=True)
    anchors_path = os.path.join(out_dir, f'chr_{outfit}_anchors.json')
    anchors = json.load(open(anchors_path)) if os.path.exists(anchors_path) else {}
    anchors['_doc'] = ('Pescoco (ponto onde a cabeca encaixa) por quadro das folhas chr_<body>_' + outfit + '_<anim>.png, '
                       'no formato de tools/art/combat_anims/head_anchors.json: [body][anim][linha S,SE,E,NE,N][coluna] = '
                       '{dx, dy} em relacao ao quadro 0 do idle da mesma linha; _neck_idle0[body][linha] = esse ponto '
                       'absoluto (x, y) no quadro 96x96. Gerado por tools/art/import_ai_sheet.py.')
    anchors.setdefault('_neck_idle0', {})[body] = {d: [round(necks[('idle', d, 0)][0], 1), round(necks[('idle', d, 0)][1], 1)]
                                                   for d in DIRS}
    anchors[body] = {}
    written, sheets = [], {}
    for ga, (game_anim, n, cols) in GUIDE_ANIMS.items():
        sheet = np.zeros((96 * 5, 96 * len(cols), 4), np.uint8)
        rows = []
        for r, d in enumerate(DIRS):
            ref = necks[('idle', d, 0)]
            row = []
            for c, f in enumerate(cols):
                sheet[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96] = frames[(ga, d, f)]
                nk = necks[(ga, d, f)]
                row.append(dict(dx=int(round(nk[0] - ref[0])), dy=int(round(nk[1] - ref[1])), mirror_idle=False,
                                key=f'{ga}_{f}', fit=nk[2]))
            rows.append(row)
        anchors[body][game_anim] = rows
        sheets[game_anim] = sheet
    mask_sheets = {}
    if compose_head:
        sheets, mask_sheets, comp_rep = compose_heads(body, sheets, anchors[body], anchors['_neck_idle0'][body], pal)
        report['compose_head'] = comp_rep
    for game_anim, sheet in sheets.items():
        p = os.path.join(out_dir, f'chr_{body}_{outfit}_{game_anim}.png')
        Image.fromarray(sheet).save(p); written.append(p)
        if game_anim in mask_sheets:
            p = os.path.join(out_dir, f'chr_{body}_{outfit}_mask_{game_anim}.png')
            Image.fromarray(mask_sheets[game_anim]).save(p); written.append(p)
    json.dump(anchors, open(anchors_path, 'w'), indent=1, default=_js)
    written.append(anchors_path)
    report['written'] = written
    report['colors'] = int(len(pal))
    json.dump(report, open(os.path.join(work_dir, f'report_{body}.json'), 'w'), indent=1, default=_js)
    contact(sheets, anchors[body], anchors['_neck_idle0'][body], os.path.join(work_dir, f'contact_{body}.png'))
    if preview:
        gifs(sheets, body, work_dir)
    return report, []


def compose_heads(body, sheets, anc, neck0, pal):
    """Cola a cabeca do corpo-base (mesmo quadro) e escreve a mascara. Mede o desencontro pescoco x queixo e,
    quando passa de 1 px, desloca o CORPO para encaixar na cabeca (a cabeca do jogo, olhos e cabelo ficam
    onde ja estao)."""
    out, masks, rep = {}, {}, {}
    for anim, sheet in sheets.items():
        ncol = sheet.shape[1] // 96
        if base_head(body, anim, 0, 0) is None:
            rep[anim] = 'sem corpo-base: folha omitida'
            continue
        S = np.zeros_like(sheet); M = np.zeros_like(sheet)
        mis = []
        bw = Image.open(os.path.join(GAME, 'assets', 'characters', 'base', f'chr_{body}_base_{anim}.png')).size[0] // 96
        for r in range(5):
            for c in range(ncol):
                fr = sheet[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96]
                bh = base_head(body, anim, r, min(c, bw - 1))
                if bh is None:
                    S[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96] = fr; mis.append(None); continue
                Hc, Mc, chin = bh
                x0, y0 = neck0[DIRS[r]]
                nx, ny = x0 + anc[anim][r][c]['dx'], y0 + anc[anim][r][c]['dy']
                # o pescoco do corpo sobe ate 2 px por dentro do queixo (sem fresta)
                dx = int(round(chin[0] - nx)); dy = int(round(chin[1] - 2 - ny))
                mis.append(round(float(np.hypot(dx, dy)), 1))
                if abs(dx) > 1 or abs(dy) > 1:
                    fr = shift(fr, dx, dy)
                sk, tone = skin_mask_tone(fr)
                body_mask = np.zeros_like(fr)
                body_mask[..., 0] = np.where(sk, tone * 40 + 20, 0)
                body_mask[..., 3] = np.where(fr[..., 3] > 0, 255, 0)
                o = fr.copy(); hm = Hc[..., 3] > 0
                o[hm] = Hc[hm]
                mk = body_mask.copy(); mk[hm] = Mc[hm]; mk[hm, 3] = 255
                S[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96] = o
                M[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96] = mk
        out[anim] = S; masks[anim] = M
        vals = [m for m in mis if m is not None]
        rep[anim] = dict(max_mismatch=max(vals) if vals else None, mean_mismatch=round(float(np.mean(vals)), 2) if vals else None)
    return out, masks, rep


def contact(sheets, anc, neck0, path, z=3):
    """Prancha de conferencia: todas as folhas, fundo de grama, pescoco em vermelho, linha do chao em amarelo."""
    order = ['idle', 'walk', 'sit', 'attack_unarmed', 'cast', 'hit', 'death']
    order = [a for a in order if a in sheets]
    W = max(sheets[a].shape[1] for a in order)
    H = sum(sheets[a].shape[0] for a in order)
    board = Image.new('RGBA', (W, H), (88, 112, 80, 255))
    y = 0
    for a in order:
        sh = sheets[a]
        board.alpha_composite(Image.fromarray(sh), (0, y))
        px = board.load()
        for r in range(5):
            for c in range(sh.shape[1] // 96):
                for xx in range(c * 96, c * 96 + 96, 2):
                    px[xx, y + r * 96 + GROUND_Y + 1] = (240, 220, 60, 255)
                x0, y0 = neck0[DIRS[r]]
                e = anc[a][r][c] if a in anc else {'dx': 0, 'dy': 0}
                nx, ny = int(round(x0 + e['dx'])) + c * 96, int(round(y0 + e['dy'])) + y + r * 96
                for q in (-1, 0, 1):
                    if 0 <= nx + q < W: px[nx + q, ny] = (230, 30, 30, 255)
                    if 0 <= ny + q < H: px[nx, ny + q] = (230, 30, 30, 255)
        y += sh.shape[0]
    board.resize((W * z, H * z), Image.NEAREST).convert('RGB').save(path)


def gifs(sheets, body, work_dir, z=3):
    """preview_<body>_<anim>.gif: as 5 direcoes lado a lado (3x, fundo de grama), no ritmo do jogo."""
    ms = {'idle': 200, 'walk': 100, 'sit': 1000, 'attack_unarmed': 100, 'cast': 90, 'hit': 120, 'death': 150}
    for a, sh in sheets.items():
        n = sh.shape[1] // 96
        seq = []
        for c in range(n):
            im = Image.new('RGBA', (96 * 5, 96), (88, 112, 80, 255))
            for r in range(5):
                im.alpha_composite(Image.fromarray(sh[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96].copy()), (r * 96, 0))
            seq.append(im.convert('RGB').resize((96 * 5 * z, 96 * z), Image.NEAREST))
        seq[0].save(os.path.join(work_dir, f'preview_{body}_{a}.gif'), save_all=True, append_images=seq[1:],
                    duration=ms.get(a, 120), loop=0)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('body', choices=['male', 'female'])
    ap.add_argument('outfit')
    ap.add_argument('images', nargs='+')
    ap.add_argument('--out', default=os.path.join(GAME, 'assets', 'characters', 'outfits'))
    ap.add_argument('--work', default=None, help='relatorio e pranchas de conferencia (padrao: .work/import_<outfit> na '
                    'raiz do projeto, fora do jogo)')
    ap.add_argument('--colors', type=int, default=32)
    ap.add_argument('--compose-head', action='store_true')
    ap.add_argument('--preview', action='store_true')
    ap.add_argument('--guides', default=GUIDE_DIR)
    ap.add_argument('--check', action='store_true', help='so confere as partes dadas (IoU com a guia, quadros 96 em '
                    '<work>/check_<body>_<parte>.png); nao escreve folhas')
    a = ap.parse_args()
    work = a.work or os.path.abspath(os.path.join(GAME, '..', '.work', f'import_{a.outfit}'))
    rep, errs = import_body(a.body, a.outfit, a.images, a.out, work, a.colors, a.compose_head, a.preview, a.guides,
                            a.check)
    if a.check:
        ious = [f['iou'] for f in rep['frames'].values()]
        print(f"conferencia {a.body}: {len(ious)} quadros lidos" + (f", IoU com a guia min {min(ious):.2f} media "
              f"{np.mean(ious):.2f}" if ious else '') + f"; pranchas em {work}")
        for e in errs:
            print('  -', e)
        sys.exit(2 if errs else 0)
    if errs:
        print('ERRO: a importacao foi recusada, nada foi escrito:', file=sys.stderr)
        for e in errs:
            print('  -', e, file=sys.stderr)
        sys.exit(2)
    ious = [f['iou'] for f in rep['frames'].values()]
    fits = [f['neck_fit'] for f in rep['frames'].values()]
    print(f"ok {a.body}/{a.outfit}: {len(rep['frames'])} quadros, {rep['colors']} cores, "
          f"IoU guia min {min(ious):.2f} media {np.mean(ious):.2f}, pescoco fit medio {np.mean(fits):.2f}")
    for w in rep.get('warnings', []):
        print('  aviso:', w)
    for p in rep['written']:
        print('  ', os.path.relpath(p))
    print('   relatorio:', os.path.join(work, f'report_{a.body}.json'))


if __name__ == '__main__':
    main()
