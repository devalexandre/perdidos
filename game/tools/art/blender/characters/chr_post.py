#!/usr/bin/env python3
"""Pos-processamento dos personagens (docs/arte-personagens-blender.md). Mesmo metodo do pos dos monstros do
B3 (monsters/post.py: cel shading por faixa de N.L em rampas, contorno interno seletivo, contorno externo
colorido), acrescido do que o paper doll precisa:
  * DONO de cada pixel (peca que o gerou, inclusive linhas e contorno) -> separa as camadas pelo grupo;
  * mascara de personalizacao do corpo (R = tom da pele, B = cabelo raspado; tom i -> i*40+20);
  * cabelo em rampa de cinza (tom i -> i*40+20) para o shader recolorir;
  * rosto (boca/nariz) e camada de OLHOS desenhados em pixel art nas ancoras projetadas de cada quadro;
  * recorte fixo por corpo (pes na ultima linha), folhas no formato do jogo, previas (pranchas + GIFs).

  .tools/pyvenv/bin/python game/tools/art/blender/characters/chr_post.py <male|female> [--sets ...]
        [--work .work/c3] [--no-install] [--preview-only]
"""
import argparse, json, os, sys, glob
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
ROOT = os.path.dirname(GAME)
sys.path.insert(0, os.path.join(HERE, "..", "monsters"))
import post as MP  # noqa: E402  (pipeline do B3: shift)

shift = MP.shift
FRAME = 96
STEP = 40
LIGHT = np.array([-0.55, 0.62, 0.58])
THRESH4 = (0.02, 0.40, 0.80)   # 4 tons
THRESH3 = (0.10, 0.62)         # 3 tons

CUSTOM = json.load(open(os.path.join(GAME, "tools", "art", "customization", "palettes.json")))
SKIN0 = [tuple(c) for c in CUSTOM["skin"][0][1]]   # rampa do Viajante (tom 0 = contorno)
HAIR0 = [tuple(c) for c in CUSTOM["hair"][0][1]]   # 5 tons (0 = contorno)


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def R(*hs):
    return [hx(h) for h in hs]


# Familias de cor (4 tons escuro -> claro + contorno externo; a linha interna usa o tom 0 da propria rampa), tiradas
# da referencia title-evolution-v1.png e clareadas um pouco para ler sobre a grama. 5 cores por familia: cada folha
# (pele 4 + cabelo 5 + olhos 8 + familias da roupa) fica abaixo de 48 cores (validate_art).
def FAM(ramp, out):
    return dict(ramp=R(*ramp), out=hx(out))


TEAL = FAM(("1f4a52", "2f6b72", "3f8a8c", "5aa8a2"), "122a33")
WHITE = FAM(("a89a8c", "cfc4b4", "e8e0d2", "f7f3ea"), "4a4448")
GRAY = FAM(("6a6e76", "9a9ea4", "c6c8c8", "e8e6e0"), "2e3038")
DENIM = FAM(("1e2438", "2b3450", "3a4768", "4f5f84"), "10131f")
LEATHER = FAM(("5a321f", "7e4a2c", "a0663a", "c0854e"), "2a150e")
OLIVE = FAM(("2e3420", "444c2c", "5e663a", "7a824c"), "181c12")
RED = FAM(("5a1a1c", "862a28", "a8403a", "c85e4c"), "2e0c0e")
NAVY = FAM(("1a2440", "243458", "32467a", "465e98"), "0c1224")
GOLDF = FAM(("8a5a14", "c08a24", "e6b43a", "fae68c"), "4a2c0c")
IRON = FAM(("26222a", "3a343e", "504852", "6c6470"), "120e14")
CRIM = FAM(("4a1418", "6e1e22", "8e2c2c", "ae4438"), "24080c")
JADE = FAM(("1a3a2c", "285440", "3a6e52", "548c68"), "0c1c14")


def M(f, fill=None, **kw):
    d = dict(ramp=f["ramp"], line=0, out=f["out"])
    if fill:
        d["fill"] = fill
    d.update(kw)
    return d


# Materiais: ramp (escuro -> claro), line (linha interna), out (contorno externo). kind: skin/hair/buzz = cores
# por indice de rampa (recoloridas no jogo).
MATS = {
    "skin": dict(kind="skin", ramp=SKIN0, fill=(1, 2, 3), line=0, out=0),
    "buzz": dict(kind="buzz", ramp=HAIR0, fill=(1, 2, 3, 4), line=0, out=0),
    "hair": dict(kind="hair", ramp=HAIR0, fill=(1, 2, 3, 4), line=0, out=0),
    "hair_tie": dict(kind="hair", ramp=HAIR0, fill=(0, 1, 1, 2), line=0, out=0),
    # 0 Viajante (moletom verde-agua, camiseta branca, jeans escuro, tenis, bolsa marrom)
    "hoodie": M(TEAL), "hoodie_rib": M(TEAL, (0, 1, 2)), "hoodie_edge": M(TEAL, (0, 1, 2)),
    "cord": M(WHITE, (1, 2, 3)), "tee": M(WHITE), "shirt": M(WHITE),
    "denim": M(DENIM), "denim_hem": M(DENIM, (0, 1, 2)),
    "sneaker": M(GRAY), "sole": M(WHITE, (1, 2, 3)), "lace": M(DENIM, (1, 2, 3)),
    "strap": M(LEATHER, (0, 1, 2)), "bag": M(LEATHER), "bag_flap": M(LEATHER, (1, 2, 3)),
    # 1 Aprendiz
    "vest": M(OLIVE), "vest_edge": M(LEATHER, (1, 2, 3)), "leather": M(LEATHER), "strap_dark": M(LEATHER, (0, 1, 2)),
    "sash": M(RED), "sash_stripe": M(WHITE, (1, 2, 3)), "olive_pants": M(OLIVE, (0, 1, 2)),
    "boot": M(LEATHER), "boot_sole": M(LEATHER, (0, 1)),
    # 2 Ramo
    "navy": M(NAVY), "belt": M(LEATHER, (0, 1, 2)), "char_pants": M(IRON, (0, 1, 2)), "navy_boot": M(NAVY),
    # 3 Apice
    "iron": M(IRON), "crimson": M(CRIM), "jade": M(JADE), "glove": M(IRON, (0, 1, 2)), "scarf": M(WHITE),
    "iron_boot": M(IRON),
    "gem_amber": dict(ramp=R("c8641a", "c8641a", "f09a2c", "fcd070"), fill=(2, 3), line=0, out=hx("4a2c0c")),
    # brincos, chapeus, armas
    "gold": M(GOLDF),
    "seed": dict(ramp=R("5a1e1a", "8c2e24", "b8483a", "d8765a"), line=hx("3a1410"), out=hx("2a0e0c")),
    "feather": dict(ramp=R("8a9aa0", "c4ccc8", "e8ece4", "fbfaf4"), line=hx("5a6468"), out=hx("3e4648")),
    "feather_tip": dict(ramp=R("1f4a52", "2f6b72", "3f8a8c", "5aa8a2"), line=hx("163840"), out=hx("122a33")),
    "straw": dict(ramp=R("8a6424", "b8903c", "dcb85c", "f0da8a"), line=hx("5e4218"), out=hx("4a3010")),
    "hat_band": dict(ramp=R("6a1e1e", "9a2e28", "c2463a", "dc6a50"), line=hx("4a1414"), out=hx("3a0e0e")),
    "ipe": dict(ramp=R("b0801c", "dca628", "f4cc3c", "fce878"), line=hx("7a5410"), out=hx("5e400c")),
    "ipe_core": dict(ramp=R("8a3a18", "b85a20", "d8802c", "eca448"), line=hx("5a2410"), out=hx("4a1c0c")),
    "leaf": dict(ramp=R("1f4a2c", "2f6b3e", "4a9050", "74b464"), line=hx("16361f"), out=hx("10281a")),
    "wood": dict(ramp=R("4a2c18", "6e4424", "946034", "b47e48"), line=hx("33200f"), out=hx("26170b")),
    "wood_dark": dict(ramp=R("33200f", "4a2c18", "6e4424", "8e5c32"), line=hx("22150a"), out=hx("1a1008")),
    "brass": dict(ramp=R("6a4a18", "9a7228", "c49a3a", "e4c464"), line=hx("4a3210"), out=hx("3a260c")),
    "steel": dict(ramp=R("4e5662", "7e8894", "b4bcc6", "e6ecf0"), line=hx("323842"), out=hx("262a32")),
    "flame": dict(ramp=R("e8601c", "f08a2c", "f8c040", "fff0a0"), fill=(1, 2, 3), line=1, out=hx("8a3a10"), unlit=True),
    "glow": dict(ramp=R("f0c040", "f8dc70", "fff0a8", "fffce0"), fill=(2, 3), line=1, out=hx("b8801c")),
    "gem_green": dict(ramp=R("1c7a44", "1c7a44", "3cb05e", "9ae8a0"), fill=(2, 3), line=0, out=hx("082818")),
}
# Camadas: grupo da peca -> camada. Corpo e roupa ficam juntos na folha do corpo.


def mat_of(parts, i):
    return parts[i]["mat"]


def shade_set(ids, dep, nx, ny, parts, light=LIGHT):
    """Um quadro -> (mat_idx HxW int16, code HxW int8, owner HxW uint8). code 0..k = tom da rampa, 10 = linha,
    11 = contorno externo; mat -1 = vazio."""
    H, W = ids.shape
    names = sorted(MATS)
    mid = {n: i for i, n in enumerate(names)}
    NPID = len(parts) + 1
    pm = np.full(NPID, -1, np.int16)
    fills = {}
    for i in range(1, len(parts)):
        m = parts[i]["mat"]
        pm[i] = mid[m]
    nxf = nx.astype(np.float32); nyf = ny.astype(np.float32)
    nz = np.sqrt(np.clip(1 - nxf * nxf - nyf * nyf, 0, 1))
    L = light / np.linalg.norm(light)
    ndl = nxf * L[0] + nyf * L[1] + nz * L[2]
    mat = np.where(ids > 0, pm[ids], -1).astype(np.int16)
    code = np.zeros((H, W), np.int8)
    for n, i in mid.items():
        sel = mat == i
        if not sel.any():
            continue
        f = MATS[n].get("fill", (0, 1, 2, 3))
        th = THRESH4 if len(f) == 4 else THRESH3
        t = np.digitize(ndl[sel], th)
        code[sel] = np.array(f, np.int8)[np.clip(t, 0, len(f) - 1)]
    code = _smooth_codes(ids, code)
    owner = ids.copy()
    opaque = ids > 0
    noline = np.zeros(NPID, bool)
    clump = np.zeros(NPID, np.int16)
    cid = {}
    for i in range(1, len(parts)):
        noline[i] = bool(parts[i].get("noline"))
        if parts[i].get("clump"):
            clump[i] = cid.setdefault(parts[i]["clump"], len(cid) + 1)
    # linha interna: pixel atras de um vizinho de outra peca; dono = a peca da frente
    line = np.zeros((H, W), bool); lown = np.zeros((H, W), ids.dtype); best = np.ones((H, W), np.float32) * 9
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        q = shift(ids, dy, dx, 0)
        dq = shift(dep, dy, dx, 1.0)
        m = opaque & (q > 0) & (q != ids) & ~noline[ids] & ~noline[q] & (dep > dq + 2e-4) & (dq < best)
        m &= ~((clump[ids] > 0) & (clump[ids] == clump[q]))   # mesmo tufo: sem linha (massa unica)
        line |= m
        lown[m] = q[m]; best[m] = dq[m]
    # mesma peca/material dos dois lados -> linha no tom mais escuro da propria rampa; senao contorno do de tras
    same = line & (pm[lown] == mat)
    code[line] = 11
    code[same] = 10
    # quem e dono da linha: a peca da frente se for de OUTRO grupo de camada (ex.: franja sobre a testa)
    grp = [None] + [p.get("group") for p in parts[1:]]
    gid = {}
    garr = np.zeros(NPID, np.int16)
    for i in range(1, len(parts)):
        garr[i] = gid.setdefault(grp[i], len(gid) + 1)
    cross = line & (garr[lown] != garr[ids])
    owner[cross] = lown[cross]
    # a linha cruzada vira linha do material da frente (ex.: tom 0 do cabelo sobre a pele)
    mat[cross] = pm[lown[cross]]
    code[cross] = 10
    # contorno externo
    ext = ~opaque
    bestd = np.full((H, W), 9.0); oo = np.zeros((H, W), ids.dtype)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        q = shift(ids, dy, dx, 0)
        dq = shift(dep, dy, dx, 1.0)
        m = ext & (q > 0) & (dq < bestd)
        oo[m] = q[m]; bestd[m] = dq[m]
    e = ext & (bestd < 9.0)
    mat[e] = pm[oo[e]]; code[e] = 12; owner[e] = oo[e]
    return mat, code, owner


def _smooth_codes(ids, code):
    """Tira pixels orfaos de tom (um pixel sozinho de outro tom dentro da mesma peca vira a maioria vizinha)."""
    H, W = ids.shape
    out = code.copy()
    for _ in range(1):
        cnt = {}
        votes = np.zeros((H, W, 16), np.int8)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            q = shift(ids, dy, dx, 0); c = shift(out, dy, dx, 0)
            same = (q == ids) & (ids > 0)
            np.add.at(votes, (np.nonzero(same)[0], np.nonzero(same)[1], c[same].astype(np.int64)), 1)
        own = np.take_along_axis(votes, out[..., None].astype(np.int64), 2)[..., 0]
        maj = votes.argmax(2).astype(np.int8)
        n = votes.sum(2)
        fix = (ids > 0) & (own <= 1) & (n >= 5) & (votes.max(2) >= 5)
        out[fix] = maj[fix]
    return out


def colorize(mat, code, names):
    H, W = mat.shape
    rgb = np.zeros((H, W, 4), np.uint8)
    for i, n in enumerate(names):
        sel = mat == i
        if not sel.any():
            continue
        m = MATS[n]
        ramp = np.array(m["ramp"], np.uint8)
        for c in np.unique(code[sel]):
            s2 = sel & (code == c)
            if c < 10:
                col = ramp[c]
            elif c == 10:
                col = ramp[m["line"]] if isinstance(m["line"], int) else m["line"]
            elif c == 11:
                col = ramp[m["out"]] if isinstance(m["out"], int) else m["out"]
                if not isinstance(m["out"], int) and not isinstance(m["line"], int):
                    col = m["line"]
            else:
                col = ramp[m["out"]] if isinstance(m["out"], int) else m["out"]
            rgb[s2, :3] = col
            rgb[s2, 3] = 255
    return rgb


def tone_index(mat, code, names, kind):
    """Indice de tom (0..) dos pixels de materiais do tipo kind (pele/cabelo), -1 fora."""
    out = np.full(mat.shape, -1, np.int16)
    for i, n in enumerate(names):
        m = MATS[n]
        if m.get("kind") != kind:
            continue
        sel = mat == i
        c = code[sel].astype(np.int16)
        t = np.where(c < 10, c, m["line"] if c.size and False else 0)
        t = np.where(c == 10, m["line"], t)
        t = np.where(c >= 11, m["out"], t)
        out[sel] = t
    return out


# ------------------------------------------------------------------ carga e montagem
def load_set(work, body, s):
    base = os.path.join(work, "npz", body, s.replace(":", "__"))
    meta = json.load(open(base + ".json"))
    z = np.load(base + ".npz")
    return meta, z


def crop_box(work, body, ref_set="outfit:traveler"):
    """Recorte fixo do corpo (mesmo em todas as animacoes/camadas): pes do idle na ultima linha."""
    p = os.path.join(work, "npz", body, "crop.json")
    if os.path.exists(p):
        return json.load(open(p))
    meta, z = load_set(work, body, ref_set)
    ids = z["idle_id"]
    C = meta["canvas"]
    op = (ids > 0).any((0, 1))
    ys = np.nonzero(op.any(1))[0]
    y1 = int(ys.max()) + 2          # +1 do contorno externo; ultima linha do quadro = contorno do pe
    box = dict(y0=y1 - FRAME, y1=y1, x0=C // 2 - FRAME // 2, x1=C // 2 + FRAME // 2)
    json.dump(box, open(p, "w"))
    return box


def render_set(meta, z, anim, light=LIGHT):
    """-> (mat, code, owner) [dirs, frames, C, C] de uma animacao."""
    ids, dep, nx, ny = z[f"{anim}_id"], z[f"{anim}_d"], z[f"{anim}_nx"], z[f"{anim}_ny"]
    ND, NF = ids.shape[:2]
    out = [[shade_set(ids[r, f], dep[r, f], nx[r, f], ny[r, f], meta["parts"], light) for f in range(NF)]
           for r in range(ND)]
    mat = np.array([[o[0] for o in row] for row in out]); code = np.array([[o[1] for o in row] for row in out])
    own = np.array([[o[2] for o in row] for row in out])
    return mat, code, own


# ------------------------------------------------------------------ rosto e olhos
FACE = json.load(open(os.path.join(HERE, "face_designs.json")))
LIT = {"K": (40, 22, 34), "k": (110, 58, 62), "W": (236, 230, 234), "H": (252, 250, 245)}
EYE0 = [tuple(c) for c in CUSTOM["eye"][0][1]]
DEPTH_NEAR, DEPTH_RANGE = 30.0, 12.0
CLOSED_LAST = {"death": 3}
BIG_EYES = os.environ.get("CHR_STYLE", "chunky") == "chunky"   # olhos grandes de anime para a cabeca grande   # ultimos quadros da morte com os olhos fechados
EYE_TOL = 0.0009   # profundidade normalizada (~2 cm): olho atras da cabeca = escondido


def _dnorm(z):
    return min(1.0, max(0.0, (z - (DEPTH_NEAR - DEPTH_RANGE)) / (2 * DEPTH_RANGE))) * 0.998


def face_view(anc):
    """Tipo de vista do rosto pelo 'frente' da cabeca na camera: ('front'|'q'|'side'|None, lado +1 = vira para
    a direita da imagem)."""
    fx, fy, fz = anc["eye_L"][3:6]      # camera: +z = para a camera
    side = 1 if fx > 0 else -1
    a = abs(fx)
    if a >= 0.85:
        return "side", side
    if fz <= 0.10:
        return None, 0
    return ("front" if a < 0.30 else "q"), side


def _visible(pt, ids, dep, head_pids):
    x, y = int(round(pt[0] - 0.5)), int(round(pt[1] - 0.5))
    H, W = ids.shape
    if not (0 <= x < W and 0 <= y < H):
        return False
    best = False
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            yy, xx = y + dy, x + dx
            if 0 <= yy < H and 0 <= xx < W and ids[yy, xx] in head_pids and dep[yy, xx] >= _dnorm(pt[2]) - EYE_TOL:
                best = True
    return best


def _paste(dst, design, x0, y0, fn, mirror=False):
    for r, row in enumerate(design):
        row = row[::-1] if mirror else row
        for c, ch in enumerate(row):
            if ch == ".":
                continue
            y, x = y0 + r, x0 + c
            if 0 <= y < dst.shape[0] and 0 <= x < dst.shape[1]:
                fn(y, x, ch)


def face_plan(anc, ids, dep, head_pids):
    """Lista de (item, design, x0, y0, mirror) em coordenadas do canvas."""
    view, side = face_view(anc)
    if view is None:
        return []
    out = []
    eyes = []
    big = "_big" if BIG_EYES else ""
    for nm in ("eye_L", "eye_R"):
        p = anc[nm]
        if view == "side":
            p = anc["eye_s" + nm[-1]]
            p = [p[0] + (-0.6 if side < 0 else 0.6), p[1]] + list(p[2:])
        if not _visible(p, ids, dep, head_pids):
            continue
        # olho da esquerda da imagem = desenho normal; direita = espelhado
        # perfil virado para a direita: canto de fora do olho (desenho) fica atras = a esquerda, sem espelhar
        img_left = p[0] < anc["nose"][0] if view != "side" else (side > 0)
        eyes.append((nm, p, img_left))
    for nm, p, img_left in eyes:
        if view == "front":
            d = "front" + big
        elif view == "q":
            # olho de longe = o do lado para onde a cabeca vira
            far = (not img_left) if side > 0 else img_left
            d = ("far" if far else "front") + big
        else:
            d = "side" + big
        des = FACE[d]
        cx, cy = des["c"]
        x0 = int(round(p[0] - 0.5)) - (cx if img_left else (len(des["open"][0]) - 1 - cx))
        y0 = int(round(p[1] - 0.5)) - cy
        out.append(("eye", d, x0, y0, not img_left))
        bn = "brow_" + nm[-1]
        b = anc[bn]
        bd = FACE["brow"][d][0]
        bx = int(round(b[0] - 0.5)) - len(bd) // 2
        out.append(("brow", d, bx, int(round(b[1] - 0.5)) - 1, not img_left))
    if eyes:
        m = anc["mouth"]
        md = ("front" if view == "front" else ("far" if view == "q" else "side")) + big
        mw = len(FACE["mouth"][md][0])
        out.append(("mouth", md, int(round(m[0] - 0.5)) - mw // 2, int(round(m[1] - 0.5)), False))
        if view != "side":
            n = anc["nose"]
            out.append(("nose", "front", int(round(n[0] - 0.5)) + (1 if side > 0 else -1) * (view == "q"),
                        int(round(n[1] - 0.5)), False))
    return out


def draw_base_face(rgba, mask, plan, skin_ramp=SKIN0, hair_ramp=HAIR0):
    """Boca/nariz (pele, mascara R) e sobrancelhas (cabelo, mascara B) no corpo-base."""
    for item, d, x0, y0, mir in plan:
        if item == "mouth":
            def f(y, x, ch):
                if rgba[y, x, 3]:
                    rgba[y, x, :3] = skin_ramp[0]; mask[y, x] = (0 * STEP + STEP // 2, 0, 0, 255)
            _paste(rgba, FACE["mouth"][d], x0, y0, f, mir)
        elif item == "nose":
            def f(y, x, ch):
                if rgba[y, x, 3]:
                    rgba[y, x, :3] = skin_ramp[1]; mask[y, x] = (1 * STEP + STEP // 2, 0, 0, 255)
            _paste(rgba, ["n"], x0, y0, f, mir)
        elif item == "brow":
            def f(y, x, ch):
                if rgba[y, x, 3]:
                    rgba[y, x, :3] = hair_ramp[1]; mask[y, x] = (0, 0, 1 * STEP + STEP // 2, 255)
            _paste(rgba, FACE["brow"][d], x0, y0, f, mir)


def draw_eyes(out, plan, closed=False, encode=True, eye_ramp=EYE0):
    for item, d, x0, y0, mir in plan:
        if item != "eye":
            continue
        des = FACE[d]["closed" if closed else "open"]

        def f(y, x, ch):
            if ch in "0123":
                t = int(ch)
                out[y, x] = (0, t * STEP + STEP // 2, 0, 255) if encode else (*eye_ramp[t], 255)
            elif ch in LIT:
                out[y, x] = (*LIT[ch], 255)
        _paste(out, des, x0, y0, f, mir)


# ------------------------------------------------------------------ folhas
def to_sheet(frames):
    """frames [dirs][cols] de (96,96,4) -> folha (5*96, cols*96, 4)."""
    nd, nc = len(frames), len(frames[0])
    sh = np.zeros((nd * FRAME, nc * FRAME, 4), np.uint8)
    for r in range(nd):
        for c in range(nc):
            sh[r * FRAME:(r + 1) * FRAME, c * FRAME:(c + 1) * FRAME] = frames[r][c]
    return sh


def hair_code_to_rgb(code_img, ramp=HAIR0):
    out = code_img.copy()
    op = out[..., 3] > 0
    t = np.clip(out[..., 0] // STEP, 0, len(ramp) - 1)
    out[op, :3] = np.array(ramp, np.uint8)[t[op]]
    return out


def skin_mask_to_rgb(rgba, mask, skin=SKIN0, hair=HAIR0):
    out = rgba.copy()
    for ch, ramp in ((0, skin), (2, hair)):
        sel = (mask[..., ch] > 5) & (out[..., 3] > 0)
        t = np.clip(mask[..., ch] // STEP, 0, len(ramp) - 1)
        out[sel, :3] = np.array(ramp, np.uint8)[t[sel]]
    return out


def eyes_to_rgb(eyes, skin=SKIN0, eye=EYE0):
    out = eyes.copy()
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    op = out[..., 3] > 0
    iris = op & (r == 0) & (b == 0) & (g > 5)
    sk = op & (g == 0) & (b == 0) & (r > 5)
    out[iris, :3] = np.array(eye, np.uint8)[np.clip(g[iris] // STEP, 0, 3)]
    out[sk, :3] = np.array(skin, np.uint8)[np.clip(r[sk] // STEP, 0, 3)]
    return out


MAX_COLORS = 46   # validate_art: folhas de personagem <= 48 cores (margem de 2)


def limit_colors(sh, maxc=MAX_COLORS):
    """Funde as cores mais raras na cor mais proxima ja usada ate a folha ter <= maxc cores (in-place)."""
    op = sh[..., 3] > 0
    px = sh[op][:, :3].astype(np.int32)
    if len(px) == 0:
        return sh
    cols, inv, cnt = np.unique(px, axis=0, return_inverse=True, return_counts=True)
    if len(cols) <= maxc:
        return sh
    order = np.argsort(-cnt)
    keep = cols[order[:maxc]]
    mapped = cols.copy()
    for i in order[maxc:]:
        d = ((keep - cols[i]) ** 2).sum(1)
        mapped[i] = keep[int(np.argmin(d))]
    sh[op, :3] = mapped[inv.reshape(-1)].astype(np.uint8)
    return sh


def over(dst, src):
    m = src[..., 3] > 0
    dst[m] = src[m]
    return dst


# ------------------------------------------------------------------ principal
ASSETS = os.path.join(GAME, "assets", "characters")
# animacoes em que cada arma aparece (nas outras a camada some: guardada na morte/sentado; golpe de outro tipo)
WEAPON_ANIMS = {"blade": ("idle", "walk", "attack_blade", "cast", "hit"),
                "staff": ("idle", "walk", "attack_staff", "cast", "hit")}
DEFAULT_HAIR = {"male": "spiky", "female": "ponytail"}
GIF_MS = {"idle": 200, "walk": 100, "attack_unarmed": 70, "attack_blade": 70, "attack_staff": 70, "cast": 90,
          "hit": 120, "death": 150, "sit": 400}
BG = (118, 158, 86, 255)


def backup_once(work):
    import shutil
    dst = os.path.join(work, "backup")
    if os.path.exists(os.path.join(dst, "characters")):
        return
    os.makedirs(dst, exist_ok=True)
    for d in ("characters", "equipment"):
        src = os.path.join(GAME, "assets", d)
        shutil.copytree(src, os.path.join(dst, d), ignore=shutil.ignore_patterns("*.import"))
    print("[post] backup em", dst)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(img, "RGBA").save(path)


def process(work, body, sets, install=True):
    box = crop_box(work, body)
    y0, y1, x0, x1 = box["y0"], box["y1"], box["x0"], box["x1"]
    names = sorted(MATS)
    out = {}          # (kind, id) -> anim -> sheet
    eyes_out, blink = {}, None
    face_plans = {}
    for s in sets:
        meta, z = load_set(work, body, s)
        parts = meta["parts"]
        kind, vid = s.split(":")
        head_pids = {i for i in range(1, len(parts)) if parts[i]["name"] == "head"}
        pgroup = np.array([""] + [p.get("group", "") for p in parts[1:]], dtype=object)
        for anim, n in meta["anims"]:
            mat, code, own = render_set(meta, z, anim)
            ids, dep = z[f"{anim}_id"], z[f"{anim}_d"]
            ND = mat.shape[0]
            fr, mk, ey, bl = [], [], [], []
            for r in range(ND):
                fr.append([]); mk.append([]); ey.append([]); bl.append([])
                for f in range(n):
                    rgba = colorize(mat[r, f], code[r, f], names)
                    if kind == "outfit":
                        mask = np.zeros_like(rgba)
                        st = tone_index(mat[r, f], code[r, f], names, "skin")
                        bt = tone_index(mat[r, f], code[r, f], names, "buzz")
                        sel = st >= 0
                        mask[sel, 0] = st[sel] * STEP + STEP // 2; mask[sel, 3] = 255
                        sel = bt >= 0
                        mask[sel, 2] = bt[sel] * STEP + STEP // 2; mask[sel, 3] = 255
                        anc = meta["anchors"][anim][r][f]
                        plan = face_plan(anc, ids[r, f], dep[r, f], head_pids)
                        face_plans[(anim, r, f)] = plan
                        draw_base_face(rgba, mask, plan)
                        mk[r].append(mask[y0:y1, x0:x1])
                        if vid == "traveler":
                            shut = f >= n - CLOSED_LAST.get(anim, 0)
                            e = np.zeros_like(rgba); draw_eyes(e, plan, closed=shut); ey[r].append(e[y0:y1, x0:x1])
                            b = np.zeros_like(rgba); draw_eyes(b, plan, closed=True); bl[r].append(b[y0:y1, x0:x1])
                        fr[r].append(rgba[y0:y1, x0:x1])
                    else:
                        o = own[r, f]
                        sel = (o > 0) & (pgroup[o] == s)
                        if kind == "hair":
                            ht = tone_index(mat[r, f], code[r, f], names, "hair")
                            img = np.zeros_like(rgba)
                            ok = sel & (ht >= 0)
                            v = (ht[ok] * STEP + STEP // 2).astype(np.uint8)
                            img[ok, 0] = v; img[ok, 1] = v; img[ok, 2] = v; img[ok, 3] = 255
                        else:
                            img = np.zeros_like(rgba); img[sel] = rgba[sel]
                        fr[r].append(img[y0:y1, x0:x1])
            out.setdefault((kind, vid), {})[anim] = to_sheet(fr)
            if kind == "outfit":
                out.setdefault(("mask", vid), {})[anim] = to_sheet(mk)
                if vid == "traveler":
                    eyes_out[anim] = to_sheet(ey)
                    if anim == "idle":
                        blink = to_sheet(bl)
            print(f"[post] {body} {s} {anim}", flush=True)
    files = {}
    for (kind, vid), d in out.items():
        for anim, sh in d.items():
            if kind == "outfit":
                p = (f"base/chr_{body}_base_{anim}.png" if vid == "traveler" else f"outfits/chr_{body}_{vid}_{anim}.png")
            elif kind == "mask":
                p = (f"base/chr_{body}_base_mask_{anim}.png" if vid == "traveler" else f"outfits/chr_{body}_{vid}_mask_{anim}.png")
            elif kind == "hair":
                p = f"hair/{vid}/{body}_{anim}.png"
            elif kind == "ear":
                p = f"face/{vid}/{body}_{anim}.png"
            elif kind == "head":
                p = os.path.join("..", "equipment", "head", vid, f"{body}_{anim}.png")
            elif kind == "weapon":
                if anim not in WEAPON_ANIMS.get(vid, ()):
                    continue
                p = os.path.join("..", "equipment", "weapon", vid, f"{body}_{anim}.png")
            else:
                continue
            files[os.path.join(ASSETS, p)] = sh
    for p_, sh in files.items():
        if "/outfits/" in p_ and "_mask_" not in p_:
            limit_colors(sh)
    for anim, sh in eyes_out.items():
        files[os.path.join(ASSETS, f"eyes/{body}_{anim}.png")] = sh
    if blink is not None:
        files[os.path.join(ASSETS, f"eyes/{body}_idle_blink.png")] = blink
    # folha inteira do Viajante (sem personalizacao): corpo + olhos + cabelo padrao, cores padrao
    hd = out.get(("hair", DEFAULT_HAIR[body]), {})
    comp = {}
    for anim, sh in out.get(("outfit", "traveler"), {}).items():
        c = skin_mask_to_rgb(sh, out[("mask", "traveler")][anim])
        if anim in eyes_out:
            over(c, eyes_to_rgb(eyes_out[anim]))
        if anim in hd:
            over(c, hair_code_to_rgb(hd[anim]))
        comp[anim] = limit_colors(c)
        files[os.path.join(ASSETS, f"chr_traveler_{body}_{anim}.png")] = c
    # quadro vazio numa folha de corpo = render falhou (nao instala)
    bad = []
    for p_, sh in files.items():
        if ("/base/" in p_ or "/outfits/" in p_) and "_mask_" not in p_:
            for r in range(sh.shape[0] // FRAME):
                for c in range(sh.shape[1] // FRAME):
                    if not (sh[r * FRAME:(r + 1) * FRAME, c * FRAME:(c + 1) * FRAME, 3] > 0).any():
                        bad.append(f"{os.path.basename(p_)} linha {r} coluna {c}")
    if bad:
        print(f"[post] ERRO: {len(bad)} quadros vazios (ex.: {bad[:4]}) - nada instalado")
        install = False
    if install:
        backup_once(work)
        for p, sh in files.items():
            save(sh, p)
        print(f"[post] {len(files)} folhas instaladas")
    pv = os.path.join(work, "preview"); os.makedirs(pv, exist_ok=True)
    write_previews(pv, f"{body}_traveler", comp)
    for (kind, vid), d in out.items():
        if kind == "outfit" and vid != "traveler":
            cc = {}
            for anim, sh in d.items():
                c = skin_mask_to_rgb(sh, out[("mask", vid)][anim])
                if anim in eyes_out:
                    over(c, eyes_to_rgb(eyes_out[anim]))
                if anim in hd:
                    over(c, hair_code_to_rgb(hd[anim]))
                cc[anim] = c
            write_previews(pv, f"{body}_{vid}", cc)
    return out, comp


def write_previews(pv, name, sheets, k=4):
    if not sheets:
        return
    Wd = max(sh.shape[1] for sh in sheets.values()); gap = 6
    H = sum(sh.shape[0] + gap for sh in sheets.values())
    board = Image.new("RGBA", (Wd, H), BG)
    y = 0
    for anim, sh in sheets.items():
        board.alpha_composite(Image.fromarray(sh, "RGBA"), (0, y)); y += sh.shape[0] + gap
    board.save(os.path.join(pv, f"{name}_board_1x.png"))
    board.resize((Wd * k, H * k), Image.NEAREST).save(os.path.join(pv, f"{name}_board.png"))
    for anim, sh in sheets.items():
        n = sh.shape[1] // FRAME; nd = sh.shape[0] // FRAME
        frames = []
        for f in range(n):
            im = Image.new("RGBA", (nd * FRAME, FRAME), BG)
            for r in range(nd):
                im.alpha_composite(Image.fromarray(sh[r * FRAME:(r + 1) * FRAME, f * FRAME:(f + 1) * FRAME], "RGBA"), (r * FRAME, 0))
            frames.append(im.resize((nd * FRAME * k, FRAME * k), Image.NEAREST).convert("RGB"))
        durs = [GIF_MS.get(anim, 120)] * n
        if anim == "death":
            durs[-1] = 1200
        frames[0].save(os.path.join(pv, f"{name}_{anim}.gif"), save_all=True, append_images=frames[1:],
                       duration=durs, loop=0, disposal=1)


# ------------------------------------------------------------------ NPCs (folha inteira, cores fixas)
NPC_DIR = os.path.join(HERE, "npcs")


def process_npc(work, npc_id, install=True):
    """NPC do mesmo esqueleto: folha inteira por animacao, cores da configuracao (npcs/<id>.json)."""
    global MATS
    cfg = json.load(open(os.path.join(NPC_DIR, f"{npc_id}.json")))
    body = f"npc_{npc_id}"
    saved = MATS
    M2 = dict(MATS)
    col = cfg.get("colors", {})
    skin = R(*col["skin"]) if "skin" in col else SKIN0
    hair = R(*col["hair"]) if "hair" in col else HAIR0
    eyes = R(*col["eyes"]) if "eyes" in col else EYE0
    M2["skin"] = dict(MATS["skin"], ramp=skin)
    for kk in ("hair", "buzz"):
        M2[kk] = dict(MATS[kk], ramp=hair)
    M2["hair_tie"] = dict(MATS["hair_tie"], ramp=hair)
    for name, fam in col.get("mats", {}).items():
        base = dict(ramp=R(*fam[:4]), line=0, out=hx(fam[4]))
        if len(fam) > 5:
            base["fill"] = tuple(fam[5])
        M2[name] = base
    MATS = M2
    try:
        names = sorted(MATS)
        s = f"npc:{npc_id}"
        meta, z = load_set(work, body, s)
        box = crop_box(work, body, s)
        y0, y1, x0, x1 = box["y0"], box["y1"], box["x0"], box["x1"]
        parts = meta["parts"]
        head_pids = {i for i in range(1, len(parts)) if parts[i]["name"] == "head"}
        sheets = {}
        for anim, n in meta["anims"]:
            mat, code, own = render_set(meta, z, anim)
            ids, dep = z[f"{anim}_id"], z[f"{anim}_d"]
            fr = []
            for r in range(mat.shape[0]):
                fr.append([])
                for f in range(n):
                    rgba = colorize(mat[r, f], code[r, f], names)
                    mask = np.zeros_like(rgba)
                    plan = face_plan(meta["anchors"][anim][r][f], ids[r, f], dep[r, f], head_pids)
                    draw_base_face(rgba, mask, plan, skin_ramp=skin, hair_ramp=hair)
                    e = np.zeros_like(rgba)
                    draw_eyes(e, plan, closed=f >= n - CLOSED_LAST.get(anim, 0), encode=False, eye_ramp=eyes)
                    over(rgba, e)
                    fr[r].append(rgba[y0:y1, x0:x1])
            sheets[anim] = limit_colors(to_sheet(fr))
        dst = os.path.join(GAME, "assets", "npcs")
        if install:
            backup_npcs(work)
            for anim, sh in sheets.items():
                save(sh, os.path.join(dst, f"npc_{npc_id}_{anim}.png"))
            print(f"[post] {npc_id}: {len(sheets)} folhas instaladas")
        pv = os.path.join(work, "preview"); os.makedirs(pv, exist_ok=True)
        write_previews(pv, f"npc_{npc_id}", sheets)
        return sheets
    finally:
        MATS = saved


def backup_npcs(work):
    import shutil
    dst = os.path.join(work, "backup", "npcs")
    if os.path.exists(dst):
        return
    shutil.copytree(os.path.join(GAME, "assets", "npcs"), dst, ignore=shutil.ignore_patterns("*.import"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("body")
    ap.add_argument("--sets", default="")
    ap.add_argument("--work", default=os.path.join(ROOT, ".work", "c3"))
    ap.add_argument("--no-install", action="store_true")
    a = ap.parse_args()
    if a.body.startswith("npc:"):
        process_npc(a.work, a.body.split(":", 1)[1], install=not a.no_install)
        return
    if a.sets:
        sets = a.sets.split(",")
    else:
        sets = sorted(os.path.basename(p)[:-4].replace("__", ":") for p in glob.glob(os.path.join(a.work, "npz", a.body, "*__*.npz")))
    sets.sort(key=lambda s: (s != "outfit:traveler", s))
    process(a.work, a.body, sets, install=not a.no_install)


if __name__ == "__main__":
    main()
