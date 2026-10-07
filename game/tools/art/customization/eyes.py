"""Camada de OLHOS (GDD §17.0.1 "olhos grandes estilo anime", §17.4 camada 7 "eyes"; contrato ADENDO 2).

    python eyes.py                  gera assets/characters/eyes/<body>_<anim>.png para TODAS as folhas do corpo-base
                                    (+ <body>_idle_blink.png, o idle com o olho fechado)
    python eyes.py --report         idem + imprime a ancora usada em cada quadro
    python eyes.py male             so um corpo

Reexecutavel e generico: le toda folha assets/characters/base/chr_<body>_base_<anim>.png (+ mascara) que existir.
Depois de refazer o corpo-base (edits/build.py do P ou build_combat.py do A), basta rodar de novo.

Como funciona
  1. Referencia: eyes_anchors.json guarda, para cada corpo e direcao com rosto (S, SE, L), onde ficam os olhos no
     quadro 0 do idle (canto superior esquerdo de cada olho + desenho). NE/N: sem olhos (nuca).
  2. Ancora da cabeca por quadro:
     a) tools/art/combat_anims/head_anchors.json (Agente A), quando o quadro estiver la: (dx, dy, mirror_idle);
     b) senao, rastreamento: o recorte da cabeca da referencia (rotulos da mascara: pele / raspado / resto) e
        procurado no quadro (+-SEARCH px, direto e espelhado); score = concordancia dos rotulos.
     Encaixe ruim (score < MIN_SCORE) = quadro SEM camada de olhos (fica o olho antigo do corpo-base, que
     continua recolorido pela mascara G).
  3. Desenho: cada olho e um desenho em pixel art (DESIGNS) colado na ancora. Antes, o olho antigo do corpo-base
     em volta vira PELE (tom da pele vizinha, codificado), para nao dobrar.
  4. Piscar: <body>_idle_blink.png = mesma folha do idle com o olho fechado; o cliente troca por ~0,12 s.

Codificacao dos pixels (shader char_palette_swap*.gdshader com layer_mode 3 = MODE_EYES; CharacterLayers.bake_image):
  (v, 0, 0)  -> pele, tom v // 40 da rampa de pele escolhida   (cobre o olho antigo)
  (0, v, 0)  -> iris, tom v // 40 da rampa de olhos (0 = aro/pupila, 1 = sombra do cilio, 2 = meio, 3 = brilho)
  outros     -> cor literal (cilios, branco do olho, reflexo). Nunca usar literal com dois canais zerados.
"""
import json, os, sys
import numpy as np
from PIL import Image
from common import GAME, FR, STEP

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(GAME, 'assets', 'characters', 'base')
OUT = os.path.join(GAME, 'assets', 'characters', 'eyes')
A_ANCHORS = os.path.join(GAME, 'tools', 'art', 'combat_anims', 'head_anchors.json')
DIRS = ['s', 'se', 'e', 'ne', 'n']
SEARCH = 16
MIN_SCORE = 0.78
# quadro quase no lugar da referencia (passos do andar, desenhados de outra imagem-chave): aceita encaixe mais frouxo
LOOSE_SCORE, LOOSE_D = 0.65, 4
# animacoes que terminam de olhos fechados (ultimos N quadros)
CLOSED_LAST = {'death': 2}

# Cores literais (paleta mestra v2: contorno #16131c puxado para o vinho; branco #fcfaf5).
LIT = {
    'K': (40, 22, 34),     # cilio / contorno do olho
    'k': (110, 58, 62),    # ponta do cilio / canto (mais suave)
    'W': (236, 230, 234),  # branco do olho
    'H': (252, 250, 245),  # reflexo
}

# Desenhos (linhas de cima para baixo), olho do lado ESQUERDO da imagem com o canto de fora a esquerda;
# 'mirror' nas ancoras espelha. '.' vazio; 0-3 iris; K k W H literais; 's' pele (tom da pele vizinha).
# 'closed' = olho fechado (piscar), mesmo tamanho; onde o fechado tem '.', vira pele.
DESIGNS = json.load(open(os.path.join(HERE, 'eyes_designs.json')))


def enc_iris(t): return (0, t * STEP + STEP // 2, 0)
def enc_skin(t): return (t * STEP + STEP // 2, 0, 0)


def load(p):
    return np.asarray(Image.open(p).convert('RGBA')).astype(np.int32) if os.path.exists(p) else None


def labels(img, mask):
    """0 fundo, 1 pele, 2 raspado, 3 resto (olho, roupa, contorno...)."""
    op = img[..., 3] > 0
    L = np.where(op, 3, 0)
    L = np.where(op & (mask[..., 2] > 5), 2, L)
    return np.where(op & (mask[..., 0] > 5), 1, L)


def head_box(L):
    """Recorte da cabeca na referencia: do topo do raspado ate 26 px abaixo, largura do raspado."""
    ys, xs = np.nonzero(L == 2)
    top = ys.min(); sel = ys < top + 14
    return top, top + 26, max(0, xs[sel].min() - 1), min(FR, xs[sel].max() + 2)


def track(Lref, box, L):
    """Melhor (score, dx, dy, mirror) do recorte da cabeca da referencia dentro do quadro L."""
    y0, y1, x0, x1 = box; best = (-1.0, 0, 0, False)
    for mirror in (False, True):
        R = Lref[:, ::-1] if mirror else Lref
        bx0, bx1 = (FR - x1, FR - x0) if mirror else (x0, x1)
        ref = R[y0:y1, bx0:bx1]
        for dy in range(-SEARCH, SEARCH + 12):
            for dx in range(-SEARCH, SEARCH + 1):
                if y0 + dy < 0 or bx0 + dx < 0 or y1 + dy > FR or bx1 + dx > FR: continue
                t = L[y0 + dy:y1 + dy, bx0 + dx:bx1 + dx]
                u = (ref > 0) | (t > 0)
                s = ((ref == t) & u).sum() / max(1, u.sum())
                if mirror: s -= 0.02  # prefere o sentido da referencia
                if s > best[0] + 1e-9 or (abs(s - best[0]) < 1e-9 and abs(dx) + abs(dy) < abs(best[1]) + abs(best[2])):
                    best = (s, dx, dy, mirror)
    return best


def grid(design, state, mirror):
    g = [list(r) for r in DESIGNS[design][state]]
    return [r[::-1] for r in g] if mirror else g


def skin_tone_near(img, mask, y, x):
    """Tom de pele (indice da rampa) predominante na vizinhanca (primeiro na mesma linha e na de baixo, que no
    rosto e a bochecha, sem a sombra da franja)."""
    for r in range(1, 7):
        ys, xs = slice(y, y + 2), slice(max(0, x - r), x + r + 1)
        m = mask[ys, xs, 0]; a = img[ys, xs, 3]
        v = m[(m > 5) & (a > 0)]
        if v.size >= 2: return int(np.bincount(v // STEP).argmax())
    for r in range(1, 7):
        ys, xs = slice(max(0, y - r), y + r + 1), slice(max(0, x - r), x + r + 1)
        m = mask[ys, xs, 0]; a = img[ys, xs, 3]
        v = m[(m > 5) & (a > 0)]
        if v.size: return int(np.bincount(v // STEP).argmax())
    return 3


def enclosed(mask, img, y, x, r=4):
    """Pixel dentro do rosto: ha pele a esquerda e a direita (ate r px) e acima ou abaixo."""
    sk = (mask[..., 0] > 5) & (img[..., 3] > 0)
    left = sk[y, max(0, x - r):x].any(); right = sk[y, x + 1:x + 1 + r].any()
    up = sk[max(0, y - r):y, x].any(); down = sk[y + 1:y + 1 + r, x].any()
    return left and right and (up or down)


def px(ch, img, mask, y, x):
    if ch in LIT: return LIT[ch]
    if ch.isdigit(): return enc_iris(int(ch))
    if ch == 's': return enc_skin(skin_tone_near(img, mask, y, x))
    raise ValueError(ch)


def draw_eye(out, blink, img, mask, x0, y0, design, mirror, cover=(0, 0, 1, 1)):
    """Pinta um olho no quadro out (aberto) e em blink (fechado). cover = margem (cima, baixo, esq, dir) da area
    onde o olho antigo vira pele."""
    go, gc = grid(design, 'open', mirror), grid(design, 'closed', mirror)
    h, w = len(go), len(go[0])
    ct, cb, cl, cr = cover
    if mirror: cl, cr = cr, cl
    for y in range(y0 - ct, y0 + h + cb):
        for x in range(x0 - cl, x0 + w + cr):
            if not (0 <= y < FR and 0 <= x < FR) or img[y, x, 3] == 0: continue
            if mask[y, x, 0] > 5 or mask[y, x, 2] > 5: continue
            if mask[y, x, 1] <= 5 and not enclosed(mask, img, y, x): continue
            out[y, x] = blink[y, x] = enc_skin(skin_tone_near(img, mask, y, x)) + (255,)
    for j in range(h):
        for i in range(w):
            y, x = y0 + j, x0 + i
            if not (0 <= y < FR and 0 <= x < FR) or img[y, x, 3] == 0: continue
            o, c = go[j][i], gc[j][i]
            if o != '.':
                out[y, x] = px(o, img, mask, y, x) + (255,)
            if c != '.':
                blink[y, x] = px(c, img, mask, y, x) + (255,)
            elif o != '.':
                blink[y, x] = enc_skin(skin_tone_near(img, mask, y, x)) + (255,)


def cover_leftover(out, blink, img, mask, boxes, pad=3):
    """Sobras do olho antigo (mascara G) entre/em volta dos olhos novos viram pele."""
    x0 = max(0, min(b[0] for b in boxes) - pad); x1 = min(FR, max(b[2] for b in boxes) + pad)
    y0 = max(0, min(b[1] for b in boxes) - pad); y1 = min(FR, max(b[3] for b in boxes) + pad)
    for y in range(y0, y1):
        for x in range(x0, x1):
            if out[y, x, 3] or img[y, x, 3] == 0 or mask[y, x, 1] <= 5 or mask[y, x, 0] > 5: continue
            out[y, x] = blink[y, x] = enc_skin(skin_tone_near(img, mask, y, x)) + (255,)


def place(spec_eyes, mirror, dx, dy):
    """Posicoes (x, y, design, mirror) dos olhos no quadro, a partir da referencia."""
    out = []
    for e in spec_eyes:
        w = len(DESIGNS[e['design']]['open'][0])
        x, m = e['x'], e.get('mirror', False)
        if mirror: x, m = FR - x - w, not m
        out.append((x + dx, e['y'] + dy, e['design'], m, tuple(e.get('cover', (2, 1, 2, 2)))))
    return out


def build(body, report=False):
    anch = json.load(open(os.path.join(HERE, 'eyes_anchors.json')))[body]
    a_anch = json.load(open(A_ANCHORS)).get(body, {}) if os.path.exists(A_ANCHORS) else {}
    ref_img = load(os.path.join(BASE, f'chr_{body}_base_idle.png'))
    ref_mask = load(os.path.join(BASE, f'chr_{body}_base_mask_idle.png'))
    anims = sorted(f[len(f'chr_{body}_base_'):-4] for f in os.listdir(BASE)
                   if f.startswith(f'chr_{body}_base_') and f.endswith('.png') and '_mask_' not in f)
    os.makedirs(OUT, exist_ok=True)
    for anim in anims:
        img = load(os.path.join(BASE, f'chr_{body}_base_{anim}.png'))
        mask = load(os.path.join(BASE, f'chr_{body}_base_mask_{anim}.png'))
        if img is None or mask is None or img.shape != mask.shape: continue
        cols = img.shape[1] // FR
        sheet = np.zeros((img.shape[0], img.shape[1], 4), np.uint8); bsheet = sheet.copy()
        for r, d in enumerate(DIRS):
            spec = anch.get(d)
            if not spec: continue
            own = anim in spec  # referencia propria (ex.: sit desenhado diferente)
            rs = spec[anim] if own else spec['idle']
            ri, rm = (img, mask) if own else (ref_img, ref_mask)
            rc = rs.get('col', 0)
            Lref = labels(ri[r * FR:(r + 1) * FR, rc * FR:(rc + 1) * FR], rm[r * FR:(r + 1) * FR, rc * FR:(rc + 1) * FR])
            box = head_box(Lref)
            for c in range(cols):
                sl = (slice(r * FR, (r + 1) * FR), slice(c * FR, (c + 1) * FR))
                f, m = img[sl], mask[sl]
                if f[..., 3].max() == 0: continue
                src = 'track'
                aa = a_anch.get(anim)
                if not own and aa and r < len(aa) and c < len(aa[r]) and aa[r][c]:
                    q = aa[r][c]; s, dx, dy, mir = q.get('fit', 1.0), q['dx'], q['dy'], q.get('mirror_idle', False)
                    src = 'A'
                else:
                    s, dx, dy, mir = track(Lref, box, labels(f, m))
                ok = src == 'A' or own or s >= MIN_SCORE or (s >= LOOSE_SCORE and abs(dx) <= LOOSE_D and abs(dy) <= LOOSE_D)
                if report:
                    print(f'{body} {anim:15s} {d:2s} c{c}: {src:5s} score {s:.2f} d=({dx:+d},{dy:+d}){" M" if mir else ""}'
                          + ('' if ok else '  -> sem olhos'))
                if not ok: continue
                o = np.zeros((FR, FR, 4), np.uint8); b = o.copy()
                boxes = []
                for x, y, des, mm, cov in place(rs['eyes'], mir, dx, dy):
                    draw_eye(o, b, f, m, x, y, des, mm, cov)
                    boxes.append((x, y, x + len(DESIGNS[des]['open'][0]), y + len(DESIGNS[des]['open'])))
                cover_leftover(o, b, f, m, boxes)
                closed = c >= cols - CLOSED_LAST.get(anim, 0)
                sheet[sl] = b if closed else o; bsheet[sl] = b
        Image.fromarray(sheet, 'RGBA').save(os.path.join(OUT, f'{body}_{anim}.png'))
        if anim == 'idle':
            Image.fromarray(bsheet, 'RGBA').save(os.path.join(OUT, f'{body}_idle_blink.png'))
    print('ok', body, anims)


if __name__ == '__main__':
    report = '--report' in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith('--')]
    for b in (only or ['male', 'female']):
        build(b, report)
