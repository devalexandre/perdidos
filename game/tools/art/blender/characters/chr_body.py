"""Modelo do personagem jogavel (GDD §17.0.B): corpo masculino/feminino esbelto (~5,7 cabecas), mesmo esqueleto
para os dois, e todas as pecas que viram camadas: roupas (outfit:*), cabelos (hair:*), chapeus (head:*),
armas (weapon:*) e brincos (ear:*). Tudo parametrico: rodar de novo recria o .blend.

Referencia de desenho: game/assets/_reference/wardrobe/title-evolution-v1.png.
Pecas e materiais: nomes de material = chaves de MATS em chr_post.py."""
import math
from mathutils import Vector
import chr_lib as C

V = Vector
TAU = math.tau

# Proporcoes (metros). Feminino = mais baixo, ombros estreitos, quadril mais largo.
BODY = {
    "male": dict(h=1.0, sh=0.156, hip=0.084, chest=(0.142, 0.094), waist=(0.118, 0.082), pelvis=(0.132, 0.092),
                 arm_r=(0.040, 0.034, 0.028), leg_r=(0.068, 0.050, 0.036), neck_r=0.041, bust=0.0),
    "female": dict(h=0.965, sh=0.136, hip=0.088, chest=(0.128, 0.090), waist=(0.100, 0.076), pelvis=(0.142, 0.096),
                   arm_r=(0.037, 0.031, 0.026), leg_r=(0.066, 0.046, 0.032), neck_r=0.035, bust=0.022),
}
HEAD_SCALE = 1.24
import os as _os
BANG_LIFT = 0.040 if _os.environ.get("CHR_STYLE", "chunky") == "chunky" else 0.026   # testa a mostra no chibi
# Cabelo: as mechas sao construidas no espaco da cabeca procedural e escaladas junto com a cabeca importada; com a
# cabeca grande (estilo atarracado) elas ficam mais finas e com mais segmentos para ler como fios, nao como blocos.
_CHUNKY = _os.environ.get("CHR_STYLE", "chunky") == "chunky"
LOCK_R = 1.0                             # raio das mechas
LOCK_LEN = 1.0                           # comprimento das mechas
HAIR_GROW = 0.8 if _CHUNKY else 1.0      # folga da casca do cabelo sobre o cranio
LOCK_SEG, LOCK_RINGS, SCALP_SEG = (12, 9, 32) if _os.environ.get("CHR_STYLE", "chunky") == "chunky" else (8, 6, 24)
OUTFITS = ["traveler", "apprentice", "branch_coat", "master_armor", "leather_jerkin"]
HAIR = {"male": ["spiky", "neat", "ponytail", "curly"], "female": ["ponytail", "bob", "waves", "braid"]}


def build(body, want=None, props=None, extra=None, name=None):
    """Cria o rig com todas as pecas. want: conjunto de grupos a construir (None = todos).
    NPCs (chr_npc.py): props sobrepoe as proporcoes do corpo e extra(rig, body, P, W, J) monta as pecas proprias;
    com want = set() nenhuma peca do jogador e construida."""
    C.MR.reset()
    P = dict(BODY[body])
    if props:
        P.update(props)
    k = P["h"]
    rig = C.Rig(name or f"chr_{body}")
    rig.body = body
    rig.k = k
    J = {}

    def jp(name, loc, parent):
        J[name] = rig.joint(name, tuple(x * k for x in loc), J[parent] if parent else rig.root)
        return J[name]

    sh, hp = P["sh"] / k, P["hip"] / k
    jp("pelvis", (0, 0, 0.94), None)
    jp("spine", (0, 0.0, 1.04), "pelvis")
    jp("chest", (0, 0.0, 1.22), "spine")
    jp("neck", (0, 0.012, 1.395), "chest")
    jp("head", (0, 0.006, 1.465), "neck")
    for s, nm in ((1, "L"), (-1, "R")):
        jp(f"uarm_{nm}", (s * sh, 0.004, 1.345), "chest")
        jp(f"farm_{nm}", (s * (sh + 0.032), 0.022, 1.085), f"uarm_{nm}")
        jp(f"hand_{nm}", (s * (sh + 0.050), 0.004, 0.850), f"farm_{nm}")
        jp(f"thigh_{nm}", (s * hp, 0.0, 0.885), "pelvis")
        jp(f"shin_{nm}", (s * (hp + 0.006), -0.004, 0.490), f"thigh_{nm}")
        jp(f"foot_{nm}", (s * (hp + 0.010), 0.018, 0.085), f"shin_{nm}")
    rig.J = J
    W = lambda loc: V(tuple(x * k for x in loc))  # noqa: E731  ponto do modelo em metros ja escalado

    # ancoras do rosto (projetadas por quadro para a camada de olhos)
    rig.anchor("eye_L", W((0.041, -0.099, 1.546)), J["head"])
    rig.anchor("eye_R", W((-0.041, -0.099, 1.546)), J["head"])
    rig.anchor("eye_sL", W((0.074, -0.080, 1.548)), J["head"])   # olho visto de perfil (na lateral do rosto)
    rig.anchor("eye_sR", W((-0.074, -0.080, 1.548)), J["head"])
    rig.anchor("mouth", W((0.0, -0.090, 1.478)), J["head"])
    rig.anchor("nose", W((0.0, -0.106, 1.512)), J["head"])
    rig.anchor("brow_L", W((0.043, -0.101, 1.578)), J["head"])
    rig.anchor("brow_R", W((-0.043, -0.101, 1.578)), J["head"])
    rig.anchor("head_top", W((0.0, 0.0, 1.73)), J["head"])
    for nm in ("L", "R"):
        hd = (rig.world_loc[f"hand_{nm}"] - rig.world_loc[f"farm_{nm}"]).normalized()
        rig.anchor(f"grip_{nm}", rig.world_loc[f"hand_{nm}"] + hd * 0.055 * k + V((0, -0.012, 0)), J[f"hand_{nm}"])
    for s, nm in ((1, "L"), (-1, "R")):  # pontos do chao (trava os pes no chao)
        fl = rig.world_loc[f"foot_{nm}"]
        rig.anchor(f"heel_{nm}", V((fl.x, fl.y + 0.05 * k, 0.0)), J[f"foot_{nm}"])
        rig.anchor(f"toe_{nm}", V((fl.x, fl.y - 0.15 * k, 0.0)), J[f"foot_{nm}"])

    rig.W = W
    rig.P = P
    _body_parts(rig, body, P, W, J)
    groups = want
    if groups is None or any(g.startswith("outfit:") for g in groups):
        for o in OUTFITS:
            if groups is None or f"outfit:{o}" in groups:
                OUTFIT_BUILD[o](rig, body, P, W, J)
    for h in HAIR[body]:
        if groups is None or f"hair:{h}" in groups:
            HAIR_BUILD[h](rig, body, P, W, J)
    if groups is None:
        earrings(rig, body, P, W, J)
        heads(rig, body, P, W, J)
        weapons(rig, body, P, W, J)
    if extra:
        extra(rig, body, P, W, J)
    # cabeca anime: um pouco maior que a anatomica (tudo preso ao pivo da cabeca escala junto: rosto, cabelos,
    # chapeus, brincos e ancoras)
    J["head"].scale = (P.get("head_scale", HEAD_SCALE),) * 3
    rig.save_rest()
    return rig


# ------------------------------------------------------------------ corpo (grupo "body")
def head_sections(W, grow=0.0, zs=None):
    """Secoes do cranio/rosto (anime: cranio redondo, queixo pequeno)."""
    t = [  # z, y, rx, ry
        (1.436, -0.050, 0.014, 0.012),
        (1.452, -0.042, 0.042, 0.040),
        (1.478, -0.026, 0.070, 0.068),
        (1.510, -0.010, 0.088, 0.088),
        (1.550, 0.000, 0.099, 0.102),
        (1.595, 0.006, 0.104, 0.110),
        (1.640, 0.010, 0.101, 0.108),
        (1.680, 0.012, 0.088, 0.095),
        (1.708, 0.012, 0.062, 0.068),
        (1.724, 0.012, 0.028, 0.032),
        (1.729, 0.012, 0.004, 0.004),
    ]
    return [(W((0, y, z)), rx * W((1, 0, 0)).x + grow, ry * W((1, 0, 0)).x + grow) for z, y, rx, ry in t]


def _body_parts(rig, body, P, W, J):
    k = rig.k
    s1 = W((1, 0, 0)).x
    head = C.loft("head", head_sections(W), seg=20)
    rig.add(head, "head", "skin", J["head"], "body", prio=1.2)
    for s, nm in ((1, "L"), (-1, "R")):
        ear = C.ellipsoid(f"ear_{nm}", W((s * 0.100, 0.012, 1.548)), (0.014 * s1, 0.022 * s1, 0.030 * s1), rot=(0.1, 0, 0))
        rig.add(ear, f"ear_{nm}", "skin", J["head"], "body")
    neck = C.capsule("neck", W((0, 0.014, 1.37)), W((0, 0.008, 1.47)), P["neck_r"], P["neck_r"] * 0.95)
    rig.add(neck, "neck", "skin", J["neck"], "body")
    # cabelo raspado (buzz): casca fina no cranio, aberta no rosto (mascara B)
    buzz = C.loft("buzz", head_sections(W, grow=0.006)[4:], seg=20, cap0=False)
    _cut(buzz, lambda c, n: c.y < -0.035 * s1 and c.z < 1.668 * k or (c.z < 1.585 * k and abs(c.x) > 0.07 * s1 and c.y < 0.03 * s1)
         or (c.z < 1.56 * k))
    rig.add(buzz, "buzz", "buzz", J["head"], "body", group_line="hair")
    # tronco (pele; sempre coberto pelas roupas)
    ch, wa, pe = P["chest"], P["waist"], P["pelvis"]
    bust = P["bust"]
    up = C.loft("torso_up", [
        (W((0, 0.0, 1.00)), wa[0] * k, wa[1] * k),
        (W((0, -0.004, 1.10)), (wa[0] + ch[0]) / 2 * k, (wa[1] + ch[1]) / 2 * k),
        (W((0, -0.008 - bust * 0.6, 1.20)), ch[0] * k, (ch[1] + bust) * k),
        (W((0, -0.004 - bust * 0.3, 1.28)), ch[0] * 1.02 * k, (ch[1] + bust * 0.4) * k),
        (W((0, 0.004, 1.345)), ch[0] * 0.86 * k, ch[1] * 0.82 * k),
        (W((0, 0.010, 1.385)), ch[0] * 0.42 * k, ch[1] * 0.55 * k),
    ], seg=20)
    rig.add(up, "torso", "skin", J["chest"], "body")
    lo = C.loft("torso_lo", [
        (W((0, 0.004, 0.83)), pe[0] * 0.55 * k, pe[1] * 0.7 * k),
        (W((0, 0.004, 0.87)), pe[0] * 0.92 * k, pe[1] * 0.95 * k),
        (W((0, 0.004, 0.94)), pe[0] * k, pe[1] * k),
        (W((0, 0.0, 1.04)), wa[0] * k, wa[1] * k),
    ], seg=20)
    rig.add(lo, "pelvis", "skin", J["pelvis"], "body")
    ar = P["arm_r"]; lr = P["leg_r"]
    for s, nm in ((1, "L"), (-1, "R")):
        sh = J[f"uarm_{nm}"]; el = J[f"farm_{nm}"]; wr = J[f"hand_{nm}"]
        pa = rig.world_loc[sh.name]; pb = rig.world_loc[el.name]; pc = rig.world_loc[wr.name]
        rig.add(C.capsule(f"uarm_{nm}", pa, pb, ar[0] * k, ar[1] * k), f"uarm_{nm}", "skin", sh, "body")
        rig.add(C.capsule(f"farm_{nm}", pb, pc, ar[1] * k, ar[2] * k), f"farm_{nm}", "skin", el, "body")
        hand = C.ellipsoid(f"hand_{nm}", pc + W((s * 0.004, -0.004, -0.050)), (0.029 * k, 0.041 * k, 0.057 * k), rot=(0.08, 0.1 * s, 0))
        rig.add(hand, f"hand_{nm}", "skin", wr, "body", prio=1.3)
        th = J[f"thigh_{nm}"]; kn = J[f"shin_{nm}"]; an = J[f"foot_{nm}"]
        qa = rig.world_loc[th.name]; qb = rig.world_loc[kn.name]; qc = rig.world_loc[an.name]
        rig.add(C.capsule(f"thigh_{nm}", qa, qb, lr[0] * k, lr[1] * k), f"thigh_{nm}", "skin", th, "body")
        rig.add(C.capsule(f"shin_{nm}", qb, qc, lr[1] * k, lr[2] * k), f"shin_{nm}", "skin", kn, "body")
        foot = C.box(f"foot_{nm}", qc + W((0, -0.045, -0.050)), (0.075 * k, 0.20 * k, 0.07 * k), bevel=0.35)
        rig.add(foot, f"foot_{nm}", "skin", an, "body")


def _cut(obj, pred):
    """Apaga faces cujo (centro, normal) satisfaz pred (coordenadas do modelo)."""
    import bmesh
    me = obj.data
    bm = bmesh.new(); bm.from_mesh(me)
    kill = [f for f in bm.faces if pred(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.to_mesh(me); bm.free(); me.update()


# ------------------------------------------------------------------ roupas
def _limb_cloth(rig, W, J, nm, part, mat, grow, group, upper=True, lower=True, z_end=None, flare=0.0,
                arms=True, legs=False, prio=1.0, cuff=None):
    """Mangas/pernas de roupa: tubos maiores que o membro."""
    P = rig.P; k = rig.k
    if arms:
        a0, a1, a2 = (rig.world_loc[f"uarm_{nm}"], rig.world_loc[f"farm_{nm}"], rig.world_loc[f"hand_{nm}"])
        r = P["arm_r"]
    else:
        a0, a1, a2 = (rig.world_loc[f"thigh_{nm}"], rig.world_loc[f"shin_{nm}"], rig.world_loc[f"foot_{nm}"])
        r = P["leg_r"]
    j0, j1 = (J[f"uarm_{nm}"], J[f"farm_{nm}"]) if arms else (J[f"thigh_{nm}"], J[f"shin_{nm}"])
    out = []
    if upper:
        o = C.capsule(f"{part}_u_{nm}", a0, a1, r[0] * k + grow, r[1] * k + grow * 0.9)
        out.append(rig.add(o, f"{part}_u_{nm}", mat, j0, group, prio=prio))
    if lower:
        end = a2 if z_end is None else a1.lerp(a2, z_end)
        o = C.capsule(f"{part}_l_{nm}", a1, end, r[1] * k + grow * 0.9, r[2] * k + grow + flare)
        if cuff:
            ax = (end - a1).normalized()   # ao longo do membro (vale para braco caido ou em T)
            rig.face_parts(o, lambda c, n, e=end, ax=ax: (f"{part}_cuff_{nm}", cuff, {}) if (c - e).dot(ax) > -0.035 * k else None, group)
        out.append(rig.add(o, f"{part}_l_{nm}", mat, j1, group, prio=prio))
    return out


def _shoes(rig, W, J, group, mat_upper, mat_sole, prefix, height=0.085, lace=None, toe_cap=None, boot_top=None,
           boot_mat=None, boot_r=None):
    k = rig.k
    for s, nm in ((1, "L"), (-1, "R")):
        an = J[f"foot_{nm}"]; qc = rig.world_loc[an.name]
        if hasattr(rig, "shoe_box"):     # base Quaternius: caixa do calcado pelos ossos do pe
            cen, ln, zsole = rig.shoe_box(nm, height)
            sh = C.box(f"{prefix}_{nm}", cen, (0.100 * k, ln, height * k), bevel=0.4)
        else:
            sh = C.box(f"{prefix}_{nm}", qc + W((0, -0.052, -0.044)), (0.100 * k, 0.245 * k, height * k), bevel=0.4)
            zsole = qc.z - 0.074 * k

        def fp(c, n, nm=nm):
            if c.z < zsole:
                return (f"{prefix}_sole_{nm}", mat_sole, {})
            if toe_cap and c.y < getattr(rig, "toe_y", {}).get(nm, qc.y - 0.12 * k):
                return (f"{prefix}_toe_{nm}", toe_cap, {})
            if lace and abs(c.x - qc.x) < 0.022 * k and c.y < qc.y - 0.02 * k and n.z > 0.3:
                return (f"{prefix}_lace_{nm}", lace, {})
            return None
        rig.face_parts(sh, fp, group)
        rig.add(sh, f"{prefix}_{nm}", mat_upper, an, group, prio=1.1)
        if boot_top:
            kn = J[f"shin_{nm}"]
            qb = rig.world_loc[kn.name]
            top = qb.lerp(qc, boot_top)
            b = C.capsule(f"{prefix}_shaft_{nm}", qc + W((0, 0.004, 0.0)), top, boot_r[0] * k, boot_r[1] * k, seg=14)
            rig.face_parts(b, lambda c, n, tz=top.z: (f"{prefix}_rim_{nm}", boot_mat[1], {}) if c.z > tz - 0.03 * k else None, group)
            rig.add(b, f"{prefix}_shaft_{nm}", boot_mat[0], kn, group, prio=1.05)


def outfit_traveler(rig, body, P, W, J):
    """0 Viajante: moletom verde-agua aberto, camiseta branca, jeans escuro, tenis, bolsa carteiro marrom."""
    g = "outfit:traveler"; k = rig.k; s1 = W((1, 0, 0)).x
    ch, wa, pe, bust = P["chest"], P["waist"], P["pelvis"], P["bust"]
    # camiseta (aparece na abertura do moletom)
    tee = C.loft("tee", [
        (W((0, 0.0, 0.96)), wa[0] * k + 0.012, wa[1] * k + 0.012),
        (W((0, -0.004, 1.10)), (wa[0] + ch[0]) / 2 * k + 0.012, (wa[1] + ch[1]) / 2 * k + 0.012),
        (W((0, -0.008 - bust * 0.6, 1.20)), ch[0] * k + 0.012, (ch[1] + bust) * k + 0.012),
        (W((0, -0.002, 1.30)), ch[0] * k + 0.010, (ch[1] + bust * 0.4) * k + 0.010),
        (W((0, 0.006, 1.37)), ch[0] * 0.62 * k, ch[1] * 0.7 * k),
    ], seg=20)
    rig.add(tee, "tee", "tee", J["chest"], g)
    # moletom: aberto na frente (arco), capuz nas costas
    gr = 0.012
    secs = [
        (W((0, 0.004, 0.875)), pe[0] * k + gr + 0.006, pe[1] * k + gr),
        (W((0, 0.002, 0.95)), pe[0] * k + gr, pe[1] * k + gr * 0.9),
        (W((0, -0.002, 1.06)), (wa[0] + ch[0]) / 2 * k + gr, (wa[1] + ch[1]) / 2 * k + gr),
        (W((0, -0.008 - bust * 0.5, 1.20)), ch[0] * k + gr, (ch[1] + bust) * k + gr),
        (W((0, -0.002, 1.30)), ch[0] * 1.03 * k + gr, (ch[1] + bust * 0.3) * k + gr * 0.9),
        (W((0, 0.006, 1.36)), ch[0] * 0.80 * k + gr * 0.8, ch[1] * 0.80 * k + gr * 0.8),
        (W((0, 0.012, 1.40)), ch[0] * 0.46 * k + 0.012, ch[1] * 0.60 * k + 0.012),
    ]
    hood_body = C.loft("hoodie", secs, seg=28, arc=(0.30, TAU - 0.30))
    rig.face_parts(hood_body, lambda c, n: ("hoodie_rib", "hoodie_rib", {}) if c.z < 0.905 * k else None, g)
    rig.add(hood_body, "hoodie", "hoodie", J["chest"], g, prio=1.05)
    # bordas do ziper (fitas) e cordoes
    for s in (1, -1):
        pts = [W((s * 0.052, -0.118 - bust * 0.5, 0.88)), W((s * 0.055, -0.128 - bust, 1.08)),
               W((s * 0.056, -0.134 - bust, 1.20)), W((s * 0.052, -0.118, 1.33)), W((s * 0.040, -0.075, 1.40))]
        rig.add(C.strip(f"zip_{s}", pts, 0.020 * k, normal=(0, -1, 0), thick=0.010), f"zip_{'L' if s > 0 else 'R'}", "hoodie_edge", J["chest"], g, prio=1.4)
        cord = [W((s * 0.030, -0.120, 1.37)), W((s * 0.034, -0.140 - bust, 1.27)), W((s * 0.032, -0.142 - bust, 1.20))]
        rig.add(C.strip(f"cord_{s}", cord, 0.010 * k, normal=(0, -1, 0), thick=0.012), f"cord_{'L' if s > 0 else 'R'}", "cord", J["chest"], g, prio=1.2, noline=False)
    hood = C.ellipsoid("hood", W((0, 0.088, 1.385)), (0.110 * k, 0.055 * k, 0.062 * k), rot=(0.35, 0, 0))
    rig.add(hood, "hood", "hoodie", J["chest"], g, prio=1.0)
    collar = C.loft("collar", [
        (W((0, 0.020, 1.365)), P["neck_r"] * k + 0.036, P["neck_r"] * k + 0.034),
        (W((0, 0.024, 1.415)), P["neck_r"] * k + 0.030, P["neck_r"] * k + 0.028),
    ], seg=20, arc=(0.55, TAU - 0.55), cap0=False, cap1=False)
    rig.add(collar, "hood_collar", "hoodie", J["chest"], g)
    for s, nm in ((1, "L"), (-1, "R")):
        _limb_cloth(rig, W, J, nm, "sleeve", "hoodie", 0.013, g, cuff="hoodie_rib", z_end=0.86)
    # jeans
    jeans = C.loft("jeans_top", [
        (W((0, 0.004, 0.80)), pe[0] * 0.62 * k + 0.012, pe[1] * 0.75 * k + 0.012),
        (W((0, 0.004, 0.87)), pe[0] * 0.95 * k + 0.012, pe[1] * k + 0.012),
        (W((0, 0.002, 0.95)), pe[0] * k + 0.012, pe[1] * k + 0.010),
        (W((0, 0.0, 1.00)), wa[0] * 1.05 * k + 0.012, wa[1] * k + 0.010),
    ], seg=20)
    rig.add(jeans, "jeans_top", "denim", J["pelvis"], g)
    for s, nm in ((1, "L"), (-1, "R")):
        _limb_cloth(rig, W, J, nm, "jeans", "denim", 0.014, g, arms=False, flare=0.008, z_end=0.93, cuff="denim_hem")
    _shoes(rig, W, J, g, "sneaker", "sole", "sneaker", lace="lace")
    # bolsa carteiro: alca do ombro esquerdo (+X) ate o quadril direito (-X)
    fr = [W((0.118, -0.050, 1.395)), W((0.100, -0.122 - bust * 0.4, 1.30)), W((0.030, -0.140 - bust, 1.17)),
          W((-0.070, -0.132, 1.05)), W((-0.150, -0.110, 0.955))]
    bk = [W((0.124, 0.030, 1.395)), W((0.090, 0.118, 1.28)), W((-0.020, 0.122, 1.12)), W((-0.140, 0.100, 0.98)),
          W((-0.170, 0.050, 0.93))]
    rig.add(C.strip("strap_f", fr, 0.030 * k, normal=(0, -1, 0.2), thick=0.008), "strap_f", "strap", J["chest"], g, prio=1.6)
    rig.add(C.strip("strap_b", bk, 0.030 * k, normal=(0, 1, 0.2), thick=0.008), "strap_b", "strap", J["chest"], g, prio=1.6)
    bag = C.box("bag", W((-0.192, -0.040, 0.885)), (0.070 * k, 0.190 * k, 0.160 * k), rot=(0, 0, -0.25), bevel=0.45)
    rig.face_parts(bag, lambda c, n: ("bag_flap", "bag_flap", {}) if c.z > 0.905 * k and n.x < 0.5 else None, g)
    rig.add(bag, "bag", "bag", J["pelvis"], g, prio=1.2)


# perfil do tronco (z do modelo -> (rx, ry, y) relativos ao corpo), para roupas que seguem o corpo
def _torso_r(P, z):
    ch, wa, pe, bust = P["chest"], P["waist"], P["pelvis"], P["bust"]
    pts = [(0.80, pe[0] * 0.55, pe[1] * 0.72, 0.004), (0.87, pe[0] * 0.95, pe[1] * 0.98, 0.004), (0.94, pe[0], pe[1], 0.002),
           (1.04, wa[0], wa[1], 0.0), (1.10, (wa[0] + ch[0]) / 2, (wa[1] + ch[1]) / 2, -0.004),
           (1.20, ch[0], ch[1] + bust, -0.008 - bust * 0.6), (1.28, ch[0] * 1.02, ch[1] + bust * 0.4, -0.004 - bust * 0.3),
           (1.345, ch[0] * 0.86, ch[1] * 0.82, 0.004), (1.385, ch[0] * 0.46, ch[1] * 0.58, 0.010)]
    if z <= pts[0][0]:
        return pts[0][1:]
    for (z0, *a0), (z1, *a1) in zip(pts, pts[1:]):
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            return tuple(x + (y - x) * t for x, y in zip(a0, a1))
    return pts[-1][1:]


def _shell(rig, W, name, zs, grow, arc=None, cap0=True, cap1=True, flare=None):
    """Casca de roupa seguindo o tronco entre as alturas zs (grow em metros). flare(z) soma ao raio."""
    P, k = rig.P, rig.k
    secs = []
    for z in zs:
        rx, ry, y = _torso_r(P, z)
        f = flare(z) if flare else 0.0
        secs.append((W((0, y, z)), rx * k + grow + f, ry * k + grow + f))
    return C.loft(name, secs, seg=28, arc=arc, cap0=cap0 and arc is None, cap1=cap1 and arc is None)


def _ang(c):
    """Angulo em volta do corpo: 0 = frente (-Y), +pi/2 = esquerda do personagem (+X)."""
    return math.atan2(c.x, -c.y)


def _skirt(rig, W, J, g, name, mat, z_top, z_bot, r_top, r_bot, gap, trim=None, emb=None, trim_w=0.10, hem_h=0.045,
           parent="pelvis", yb=0.02, prio=1.0, cut=None):
    """Saia/aba de casaco aberta na frente (gap = meio angulo da abertura). Pintura: barra e bordas (trim),
    bordado em pontos (emb) perto da barra."""
    k = rig.k
    n = 7
    secs = []
    for i in range(n):
        t = i / (n - 1)
        z = z_top + (z_bot - z_top) * t
        r = r_top + (r_bot - r_top) * (t ** 1.3)
        secs.append((W((0, yb * t, z)), r * k, (r * 0.92) * k))
    sk = C.loft(name, secs, seg=36, arc=(gap, math.tau - gap))
    zb = z_bot * k

    def fp(c, nrm):
        a = abs(_ang(c))
        if trim and (c.z < zb + hem_h * k or a < gap + trim_w):
            return (f"{name}_trim", trim, {"prio": 1.4})
        if emb and c.z < zb + 0.20 * k and math.sin(a * 11.0 + c.z / k * 38.0) > 0.86:
            return (f"{name}_emb", emb, {"prio": 1.2})
        return None
    rig.face_parts(sk, fp, g)
    if cut:            # recorte no espaco do modelo (antes de entortar para uma base importada)
        _cut(sk, cut)
    return rig.add(sk, name, mat, J[parent], g, prio=prio)


def _pants(rig, W, J, g, mat, grow=0.012, hem=None):
    P, k = rig.P, rig.k
    top = _shell(rig, W, f"{g}_pants_top".replace(":", "_"), [0.80, 0.87, 0.95, 1.00], 0.012)
    rig.add(top, f"{g}_pants_top", mat, J["pelvis"], g)
    for s, nm in ((1, "L"), (-1, "R")):
        _limb_cloth(rig, W, J, nm, f"{g}_pants".replace(":", "_"), mat, grow, g, arms=False, z_end=0.93, cuff=hem)


def outfit_apprentice(rig, body, P, W, J):
    """1 Aprendiz (primeiro titulo): camisa branca de manga curta, colete de couro verde-oliva, ombreira na direita,
    faixa vermelha na cintura com ponta pendurada, aba branca na frente, calca oliva, bracadeiras e botas altas."""
    g = "outfit:apprentice"; k = rig.k
    shirt = _shell(rig, W, "app_shirt", [0.90, 0.98, 1.08, 1.20, 1.30, 1.365, 1.40], 0.012)
    rig.face_parts(shirt, lambda c, n: ("app_vneck", "skin", {}) if c.y < -0.05 * k and abs(c.x) < (c.z / k - 1.25) * 0.35 * k and c.z > 1.27 * k else None, g)
    rig.add(shirt, "app_shirt", "shirt", J["chest"], g)
    for s, nm in ((1, "L"), (-1, "R")):
        _limb_cloth(rig, W, J, nm, "app_sleeve", "shirt", 0.030, g, lower=False)
    vest = _shell(rig, W, "app_vest", [0.97, 1.05, 1.15, 1.25, 1.32, 1.37, 1.405], 0.024, arc=(0.42, math.tau - 0.42))
    rig.face_parts(vest, lambda c, n: ("app_vest_edge", "vest_edge", {}) if abs(_ang(c)) < 0.55 or c.z < 0.99 * k else None, g)
    rig.add(vest, "app_vest", "vest", J["chest"], g, prio=1.05)
    # ombreira de couro no ombro direito (-X): duas placas
    sh = rig.world_loc["uarm_R"]
    for i, (dz, r) in enumerate(((0.020, 0.080), (-0.030, 0.066))):
        pl = C.ellipsoid(f"app_pauld{i}", sh + W((-0.018, 0.0, dz)), (r * k, r * 0.95 * k, r * 0.55 * k), rot=(0, -0.45, 0))
        rig.add(pl, f"app_pauld{i}", "leather", J["uarm_R"], g, prio=1.3)
    # alca diagonal: ombro direito -> quadril esquerdo
    fr = [W((-0.105, -0.060, 1.395)), W((-0.090, -0.122, 1.30)), W((0.0, -0.132, 1.16)), W((0.090, -0.118, 1.04)), W((0.140, -0.080, 0.98))]
    bk = [W((-0.110, 0.030, 1.395)), W((-0.080, 0.115, 1.28)), W((0.030, 0.118, 1.12)), W((0.140, 0.080, 0.99))]
    rig.add(C.strip("app_strap_f", fr, 0.026 * k, normal=(0, -1, 0.2), thick=0.008), "app_strap_f", "strap_dark", J["chest"], g, prio=1.5)
    rig.add(C.strip("app_strap_b", bk, 0.026 * k, normal=(0, 1, 0.2), thick=0.008), "app_strap_b", "strap_dark", J["chest"], g, prio=1.5)
    # faixa vermelha + ponta pendurada no quadril esquerdo
    sash = _shell(rig, W, "app_sash", [0.94, 0.98, 1.02, 1.06], 0.032)
    rig.add(sash, "app_sash", "sash", J["pelvis"], g, prio=1.2)
    knot = C.ellipsoid("app_knot", W((0.110, -0.105, 0.985)), (0.040 * k, 0.030 * k, 0.040 * k))
    rig.add(knot, "app_knot", "sash", J["pelvis"], g, prio=1.3)
    tail = C.strip("app_sash_tail", [W((0.120, -0.110, 0.97)), W((0.140, -0.118, 0.80)), W((0.150, -0.110, 0.60)), W((0.152, -0.100, 0.52))],
                   0.070 * k, normal=(0.3, -1, 0), thick=0.008)
    rig.face_parts(tail, lambda c, n: ("app_sash_stripe", "sash_stripe", {}) if 0.60 * k < c.z < 0.66 * k else None, g)
    rig.add(tail, "app_sash_tail", "sash", J["pelvis"], g, prio=1.3)
    # aba branca na frente (ate o meio da coxa), levemente assimetrica
    _skirt(rig, W, J, g, "app_flap", "shirt", 0.95, 0.60, 0.150, 0.170, 0.0, yb=-0.01,
           cut=lambda c, n: abs(_ang(c)) > 1.15 or (c.z < (0.62 + 0.10 * max(0.0, c.x / k) * 3) * k))
    _pants(rig, W, J, g, "olive_pants")
    for s, nm in ((1, "L"), (-1, "R")):
        a1, a2 = rig.world_loc[f"farm_{nm}"], rig.world_loc[f"hand_{nm}"]
        br = C.capsule(f"app_bracer_{nm}", a1.lerp(a2, 0.35), a1.lerp(a2, 0.92), P["arm_r"][1] * k + 0.014, P["arm_r"][2] * k + 0.014)
        rig.add(br, f"app_bracer_{nm}", "leather", J[f"farm_{nm}"], g, prio=1.2)
    _shoes(rig, W, J, g, "boot", "boot_sole", "app_boot", height=0.090, boot_top=0.22, boot_mat=("boot", "leather"),
           boot_r=(0.058, 0.066))


def outfit_branch_coat(rig, body, P, W, J):
    """2 Ramo: casaco longo azul-marinho aberto, bordas e bordados dourados, gola alta, camisa branca,
    cinto com fivela e borlas douradas, broche de pedra verde, calca escura, botas azuis com biqueira dourada."""
    g = "outfit:branch_coat"; k = rig.k
    shirt = _shell(rig, W, "bc_shirt", [0.84, 0.90, 0.98, 1.08, 1.20, 1.30, 1.365, 1.40], 0.012)
    rig.add(shirt, "bc_shirt", "shirt", J["chest"], g)
    coat = _shell(rig, W, "bc_coat", [0.96, 1.05, 1.15, 1.25, 1.32, 1.37, 1.405], 0.024, arc=(0.34, math.tau - 0.34))
    rig.face_parts(coat, lambda c, n: ("bc_lapel", "gold", {"prio": 1.4}) if abs(_ang(c)) < 0.45 else None, g)
    rig.add(coat, "bc_coat", "navy", J["chest"], g, prio=1.05)
    collar = C.loft("bc_collar", [(W((0, 0.018, 1.360)), P["neck_r"] * k + 0.050, P["neck_r"] * k + 0.046),
                                  (W((0, 0.022, 1.470)), P["neck_r"] * k + 0.040, P["neck_r"] * k + 0.036)],
                    seg=24, arc=(0.75, math.tau - 0.75))
    rig.face_parts(collar, lambda c, n: ("bc_collar_rim", "gold", {"prio": 1.4}) if c.z > 1.455 * k or abs(_ang(c)) < 0.85 else None, g)
    rig.add(collar, "bc_collar", "navy", J["chest"], g, prio=1.1)
    _skirt(rig, W, J, g, "bc_skirt", "navy", 1.00, 0.40, 0.160, 0.215, 0.36, trim="gold", emb="gold")
    for s, nm in ((1, "L"), (-1, "R")):
        _limb_cloth(rig, W, J, nm, "bc_sleeve", "navy", 0.018, g, z_end=0.90, cuff="gold")
    belt = _shell(rig, W, "bc_belt", [0.975, 1.00, 1.03], 0.036)
    rig.add(belt, "bc_belt", "belt", J["pelvis"], g, prio=1.3)
    rig.add(C.box("bc_buckle", W((0, -0.128, 1.003)), (0.050 * k, 0.018 * k, 0.040 * k)), "bc_buckle", "gold", J["pelvis"], g, prio=2.0)
    for x in (-0.012, 0.012):
        t = C.strip(f"bc_tassel{x}", [W((x, -0.132, 0.985)), W((x * 1.5, -0.135, 0.88)), W((x * 2, -0.130, 0.80))], 0.012 * k,
                    normal=(0, -1, 0), thick=0.006)
        rig.add(t, f"bc_tassel{x}", "gold", J["pelvis"], g, prio=1.8)
    rig.add(C.ellipsoid("bc_brooch", W((0, -0.108, 1.360)), (0.016 * k, 0.010 * k, 0.020 * k)), "bc_brooch", "gem_green", J["chest"], g, prio=3.0, noline=True)
    _pants(rig, W, J, g, "char_pants")
    _shoes(rig, W, J, g, "navy_boot", "boot_sole", "bc_boot", height=0.090, toe_cap="gold", boot_top=0.62,
           boot_mat=("navy_boot", "gold"), boot_r=(0.056, 0.060))


def outfit_master_armor(rig, body, P, W, J):
    """3 Apice: casaco longo carmim com paineis verdes e bordas douradas, armadura escura (peitoral, ombreiras em
    placas, bracais, joelheiras), cinto com joia laranja, cachecol branco, botas escuras com placas."""
    g = "outfit:master_armor"; k = rig.k
    tunic = _shell(rig, W, "ma_tunic", [0.84, 0.90, 0.98, 1.08, 1.20, 1.30, 1.365, 1.40], 0.012)
    rig.add(tunic, "ma_tunic", "iron", J["chest"], g)
    coat = _shell(rig, W, "ma_coat", [0.96, 1.05, 1.15, 1.25, 1.32, 1.37, 1.405], 0.024, arc=(0.40, math.tau - 0.40))
    rig.face_parts(coat, lambda c, n: ("ma_coat_trim", "gold", {"prio": 1.4}) if abs(_ang(c)) < 0.50 else None, g)
    rig.add(coat, "ma_coat", "crimson", J["chest"], g, prio=1.05)
    # peitoral escuro (frente) com borda dourada
    plate = _shell(rig, W, "ma_plate", [1.08, 1.16, 1.24, 1.31], 0.036, arc=(-1.05, 1.05))
    rig.face_parts(plate, lambda c, n: ("ma_plate_rim", "gold", {"prio": 1.5}) if c.z > 1.29 * k or c.z < 1.10 * k or abs(_ang(c)) > 0.9 else None, g)
    rig.add(plate, "ma_plate", "iron", J["chest"], g, prio=1.2)
    rig.add(C.ellipsoid("ma_crest", W((0, -0.146, 1.215)), (0.020 * k, 0.010 * k, 0.026 * k)), "ma_crest", "gold", J["chest"], g, prio=2.5)
    _skirt(rig, W, J, g, "ma_skirt", "crimson", 1.00, 0.42, 0.165, 0.225, 0.42, trim="gold", emb="gold")
    # paineis verdes (tabardo) na frente, da cintura ate o joelho
    for s in (1, -1):
        pn = C.strip(f"ma_panel{s}", [W((s * 0.060, -0.140, 0.99)), W((s * 0.066, -0.150, 0.80)), W((s * 0.070, -0.150, 0.52))],
                     0.070 * k, normal=(0, -1, 0), thick=0.008)
        rig.face_parts(pn, lambda c, n: ("ma_panel_rim", "gold", {"prio": 1.5}) if c.z < 0.55 * k else None, g)
        rig.add(pn, f"ma_panel{s}", "jade", J["pelvis"], g, prio=1.3)
    # ombreiras: 3 placas em cada ombro
    for s, nm in ((1, "L"), (-1, "R")):
        sh = rig.world_loc[f"uarm_{nm}"]
        for i, (dz, r) in enumerate(((0.030, 0.085), (-0.012, 0.074), (-0.050, 0.062))):
            pl = C.ellipsoid(f"ma_pauld{nm}{i}", sh + W((s * 0.016, 0.0, dz)), (r * k, r * 0.95 * k, r * 0.50 * k), rot=(0, s * 0.50, 0))
            rig.face_parts(pl, lambda c, n, zz=sh.z + dz * k: ("ma_pauld_rim", "gold", {"prio": 1.4}) if c.z < zz - 0.012 * k else None, g)
            rig.add(pl, f"ma_pauld{nm}{i}", "iron", J[f"uarm_{nm}"], g, prio=1.3)
        _limb_cloth(rig, W, J, nm, "ma_sleeve", "crimson", 0.018, g, z_end=0.55)
        a1, a2 = rig.world_loc[f"farm_{nm}"], rig.world_loc[f"hand_{nm}"]
        br = C.capsule(f"ma_bracer_{nm}", a1.lerp(a2, 0.25), a1.lerp(a2, 0.95), P["arm_r"][1] * k + 0.018, P["arm_r"][2] * k + 0.018)
        rig.face_parts(br, lambda c, n, z0=a1.lerp(a2, 0.3).z: ("ma_bracer_rim", "gold", {}) if c.z > z0 - 0.01 else None, g)
        rig.add(br, f"ma_bracer_{nm}", "iron", J[f"farm_{nm}"], g, prio=1.2)
        hd = (a2 - a1).normalized()
        glove = C.capsule(f"ma_glove_{nm}", a2 + hd * 0.012 * k, a2 + hd * 0.085 * k, 0.033 * k, 0.030 * k, squash=(1.0, 0.8))
        rig.add(glove, f"ma_glove_{nm}", "glove", J[f"hand_{nm}"], g, prio=1.35)
    belt = _shell(rig, W, "ma_belt", [0.975, 1.00, 1.03], 0.040)
    rig.add(belt, "ma_belt", "belt", J["pelvis"], g, prio=1.3)
    rig.add(C.box("ma_buckle", W((0, -0.132, 1.003)), (0.056 * k, 0.018 * k, 0.046 * k)), "ma_buckle", "gold", J["pelvis"], g, prio=2.0)
    rig.add(C.ellipsoid("ma_gem", W((0, -0.143, 1.003)), (0.014 * k, 0.008 * k, 0.016 * k)), "ma_gem", "gem_amber", J["pelvis"], g, prio=3.0, noline=True)
    # cachecol branco volumoso
    sc = C.loft("ma_scarf", [(W((0, 0.012, 1.355)), P["neck_r"] * k + 0.060, P["neck_r"] * k + 0.058),
                             (W((0, 0.010, 1.395)), P["neck_r"] * k + 0.052, P["neck_r"] * k + 0.050),
                             (W((0, 0.010, 1.440)), P["neck_r"] * k + 0.034, P["neck_r"] * k + 0.032)], seg=24)
    rig.add(sc, "ma_scarf", "scarf", J["chest"], g, prio=1.4)
    _pants(rig, W, J, g, "char_pants")
    _shoes(rig, W, J, g, "iron_boot", "boot_sole", "ma_boot", height=0.092, toe_cap="iron", boot_top=0.20,
           boot_mat=("glove", "gold"), boot_r=(0.058, 0.066))
    for s, nm in ((1, "L"), (-1, "R")):
        kn = rig.world_loc[f"shin_{nm}"]
        kp = C.ellipsoid(f"ma_knee_{nm}", kn + W((0, -0.045, 0.0)), (0.050 * k, 0.030 * k, 0.055 * k))
        rig.add(kp, f"ma_knee_{nm}", "iron", J[f"shin_{nm}"], g, prio=1.4)


def outfit_leather_jerkin(rig, body, P, W, J):
    """Item 'Gibao de Couro' (visual leather_jerkin): Viajante sem o moletom, com gibao de couro fechado por
    tiras, camiseta, jeans, tenis e bracadeiras."""
    g = "outfit:leather_jerkin"; k = rig.k
    tee = _shell(rig, W, "lj_tee", [0.90, 0.98, 1.08, 1.20, 1.30, 1.365, 1.40], 0.012)
    rig.add(tee, "lj_tee", "tee", J["chest"], g)
    for s, nm in ((1, "L"), (-1, "R")):
        _limb_cloth(rig, W, J, nm, "lj_sleeve", "tee", 0.018, g, lower=False)
    vest = _shell(rig, W, "lj_vest", [0.88, 0.95, 1.05, 1.15, 1.25, 1.32, 1.37, 1.405], 0.026, arc=(0.10, math.tau - 0.10))
    rig.face_parts(vest, lambda c, n: ("lj_ties", "strap_dark", {"prio": 1.4}) if abs(_ang(c)) < 0.30 and int(c.z / k * 30) % 3 == 0
                   else (("lj_hem", "vest_edge", {}) if c.z < 0.91 * k else None), g)
    rig.add(vest, "lj_vest", "leather", J["chest"], g, prio=1.05)
    for s, nm in ((1, "L"), (-1, "R")):
        sh = rig.world_loc[f"uarm_{nm}"]
        pl = C.ellipsoid(f"lj_pad_{nm}", sh + W((s * 0.012, 0.0, 0.018)), (0.066 * k, 0.064 * k, 0.034 * k), rot=(0, s * 0.45, 0))
        rig.add(pl, f"lj_pad_{nm}", "leather", J[f"uarm_{nm}"], g, prio=1.2)
        a1, a2 = rig.world_loc[f"farm_{nm}"], rig.world_loc[f"hand_{nm}"]
        br = C.capsule(f"lj_bracer_{nm}", a1.lerp(a2, 0.4), a1.lerp(a2, 0.92), P["arm_r"][1] * k + 0.012, P["arm_r"][2] * k + 0.012)
        rig.add(br, f"lj_bracer_{nm}", "leather", J[f"farm_{nm}"], g, prio=1.2)
    jeans = _shell(rig, W, "lj_jeans_top", [0.80, 0.87, 0.95, 1.00], 0.012)
    rig.add(jeans, "lj_jeans_top", "denim", J["pelvis"], g)
    for s, nm in ((1, "L"), (-1, "R")):
        _limb_cloth(rig, W, J, nm, "lj_jeans", "denim", 0.014, g, arms=False, flare=0.008, z_end=0.93, cuff="denim_hem")
    _shoes(rig, W, J, g, "sneaker", "sole", "lj_sneaker", lace="lace")


OUTFIT_BUILD = {"traveler": outfit_traveler, "apprentice": outfit_apprentice, "branch_coat": outfit_branch_coat,
                "master_armor": outfit_master_armor, "leather_jerkin": outfit_leather_jerkin}


# ------------------------------------------------------------------ cabelos
def _scalp(rig, W, J, g, name, grow, cut_front_z, cut_side_z, back_z, mat="hair", clump="mass"):
    """Casca de cabelo sobre o cranio, aberta no rosto (linha da franja cut_front_z)."""
    k = rig.k; s1 = W((1, 0, 0)).x
    secs = head_sections(W, grow=grow * HAIR_GROW)
    cap = C.loft(name, secs[3:], seg=SCALP_SEG, cap0=False)
    _cut(cap, lambda c, n: (c.y < -0.02 * s1 and c.z < cut_front_z * k)
         or (c.y < -0.030 * s1 and abs(c.x) > 0.058 * s1 and c.z < 1.662 * k)     # temporas livres (perfil)
         or (c.z < cut_side_z * k and c.y < 0.035 * s1) or c.z < back_z * k)
    return rig.add(cap, name, mat, J["head"], g, prio=1.1, clump=f"{g}:{clump}")


def _locks(rig, J, g, prefix, specs, mat="hair", clump="mass"):
    """specs: [(root, tip, r0, bend, flat[, clump])] em coordenadas W. Mechas do mesmo tufo (clump) nao
    ganham linha entre si: o cabelo le como massas grandes, com a silhueta e as pontas dando o desenho."""
    for i, sp in enumerate(specs):
        root, tip, r0, bend = sp[:4]
        flat = sp[4] if len(sp) > 4 else 0.55
        if tip.y < -0.09 * rig.k and tip.z < 1.64 * rig.k:   # franja: pontas um pouco acima (olhos livres de cima)
            tip = tip + V((0, 0.006 * rig.k, BANG_LIFT * rig.k))
        tip = root + (tip - root) * LOCK_LEN
        cl = sp[5] if len(sp) > 5 else clump
        o = C.lock(f"{prefix}{i}", root, tip, r0 * LOCK_R, bend=bend, flat=flat, seg=LOCK_SEG, rings=LOCK_RINGS,
                   twist_axis=(0, 0, 1) if abs((tip - root).normalized().z) < 0.7 else (1, 0, 0))
        rig.add(o, f"{prefix}{i}", mat, J["head"], g, prio=1.15, clump=f"{g}:{cl}")


def hair_spiky(rig, body, P, W, J):
    """Masculino padrao (referencia): volumoso, bagunçado, franja em mechas pontudas sobre a testa."""
    g = "hair:spiky"
    _scalp(rig, W, J, g, "spiky_cap", 0.024, 1.628, 1.580, 1.50)
    Lk = []
    # franja: 5 mechas largas que se sobrepoem; pontas acima dos olhos
    for x, tipz, tipx, r in ((-0.070, 1.604, -0.090, 0.034), (-0.036, 1.590, -0.046, 0.036), (0.000, 1.598, -0.004, 0.036),
                             (0.036, 1.588, 0.046, 0.036), (0.070, 1.606, 0.092, 0.033)):
        Lk.append((W((x * 0.85, -0.060, 1.712)), W((tipx, -0.110, tipz)), r, W((0, -0.028, 0.010)), 0.45))
    # laterais: costeleta fina na frente da orelha e volume atras dela; o perfil fica livre
    for s in (1, -1):
        Lk.append((W((s * 0.094, -0.010, 1.645)), W((s * 0.112, -0.028, 1.545)), 0.024, W((s * 0.012, -0.01, 0.0)), 0.5))
        Lk.append((W((s * 0.094, 0.045, 1.650)), W((s * 0.128, 0.052, 1.515)), 0.036, W((s * 0.022, 0.01, 0.0)), 0.55))
    # topo: espetos para cima/lados/tras (silhueta bagunçada)
    for x, y, tx, ty, tz in ((0.0, -0.03, 0.01, -0.05, 1.805), (-0.055, -0.01, -0.105, -0.03, 1.775), (0.055, -0.01, 0.110, -0.02, 1.780),
                             (-0.03, 0.05, -0.06, 0.09, 1.800), (0.035, 0.05, 0.07, 0.10, 1.795), (-0.085, 0.02, -0.14, 0.01, 1.70),
                             (0.085, 0.02, 0.145, 0.02, 1.705)):
        Lk.append((W((x, y, 1.690)), W((tx, ty, tz)), 0.042, W((0, 0.0, 0.0)), 0.7))
    # nuca: espetos para tras/baixo
    for x, tz in ((-0.07, 1.54), (0.0, 1.515), (0.07, 1.54), (-0.035, 1.60), (0.04, 1.60)):
        Lk.append((W((x * 0.9, 0.070, 1.650)), W((x * 1.25, 0.150, tz)), 0.040, W((0, 0.025, 0.02)), 0.6))
    _locks(rig, J, g, "spk", Lk)


def hair_ponytail_f(rig, body, P, W, J):
    """Feminino padrao (referencia): rabo de cavalo alto e volumoso, ondulado; franja lateral e mechas no rosto."""
    g = "hair:ponytail"
    _scalp(rig, W, J, g, "pony_cap", 0.013, 1.612, 1.570, 1.52)
    Lk = []
    for x, tipz, tipx, r in ((-0.062, 1.602, -0.082, 0.026), (-0.024, 1.594, -0.030, 0.027), (0.018, 1.598, 0.030, 0.026),
                             (0.058, 1.612, 0.085, 0.024)):
        Lk.append((W((x * 0.8, -0.060, 1.705)), W((tipx, -0.110, tipz)), r * 1.2, W((0.01, -0.028, 0.012)), 0.45))
    for s in (1, -1):  # mechas que emolduram o rosto ate o queixo
        Lk.append((W((s * 0.088, -0.020, 1.640)), W((s * 0.100, -0.034, 1.455)), 0.019, W((s * 0.018, -0.008, 0.0)), 0.5))
        Lk.append((W((s * 0.095, 0.040, 1.640)), W((s * 0.114, 0.050, 1.500)), 0.030, W((s * 0.016, 0.0, 0.0)), 0.55))
    _locks(rig, J, g, "pny", Lk)
    # prendedor + rabo: nasce no alto da nuca, sobe um pouco e cai ondulado ate as costas
    base = W((0.0, 0.085, 1.700))
    tie = C.ellipsoid("pony_tie", base, (0.030 * rig.k, 0.028 * rig.k, 0.026 * rig.k))
    rig.add(tie, "pony_tie", "hair_tie", J["head"], g, prio=1.8)
    tails = [(W((0.000, 0.135, 1.760)), W((0.010, 0.200, 1.330)), 0.070, W((0.03, 0.06, 0.0))),
             (W((0.025, 0.125, 1.740)), W((0.070, 0.180, 1.360)), 0.052, W((0.05, 0.03, 0.0))),
             (W((-0.025, 0.125, 1.740)), W((-0.060, 0.185, 1.380)), 0.050, W((-0.04, 0.04, 0.0))),
             (W((0.0, 0.110, 1.780)), W((0.0, 0.150, 1.800)), 0.050, W((0.0, 0.0, 0.0)))]
    for i, (r0, tip, rad, bend) in enumerate(tails):
        o = C.lock(f"ptail{i}", r0, tip, rad, bend=bend, flat=0.75, twist_axis=(1, 0, 0), rings=8, seg=10)
        rig.add(o, f"ptail{i}", "hair", J["head"], g, prio=1.1)


def _bangs(rig, W, J, g, specs, prefix="bng"):
    Lk = [(W((x0, -0.060, 1.705)), W((tx, -0.110, tz)), r, W((bx, -0.026, 0.010)), 0.45) for x0, tx, tz, r, bx in specs]
    _locks(rig, J, g, prefix, Lk)


def hair_neat(rig, body, P, W, J):
    """Curto e arrumado, risca de lado, franja varrida para a esquerda da imagem."""
    g = "hair:neat"
    _scalp(rig, W, J, g, "neat_cap", 0.016, 1.625, 1.585, 1.505)
    _bangs(rig, W, J, g, [(0.05, -0.040, 1.628, 0.040, -0.03), (0.00, -0.075, 1.615, 0.036, -0.03),
                          (-0.04, -0.098, 1.630, 0.030, -0.02), (0.07, 0.030, 1.625, 0.034, -0.02)])
    Lk = []
    for s in (1, -1):
        Lk.append((W((s * 0.092, 0.010, 1.650)), W((s * 0.108, 0.010, 1.560)), 0.030, W((s * 0.008, 0.0, 0.0)), 0.5))
    Lk.append((W((0.0, 0.060, 1.690)), W((0.0, 0.118, 1.560)), 0.060, W((0, 0.02, 0.0)), 0.5))
    _locks(rig, J, g, "nt", Lk)


def hair_ponytail_m(rig, body, P, W, J):
    """Masculino: franja solta e rabinho baixo na nuca."""
    g = "hair:ponytail"
    _scalp(rig, W, J, g, "mpony_cap", 0.018, 1.622, 1.578, 1.50)
    _bangs(rig, W, J, g, [(-0.06, -0.085, 1.600, 0.032, 0.0), (-0.02, -0.030, 1.588, 0.034, 0.0),
                          (0.025, 0.035, 1.592, 0.033, 0.0), (0.065, 0.090, 1.605, 0.030, 0.0)])
    Lk = []
    for s in (1, -1):
        Lk.append((W((s * 0.094, -0.005, 1.645)), W((s * 0.112, -0.022, 1.515)), 0.024, W((s * 0.01, -0.01, 0.0)), 0.5))
    _locks(rig, J, g, "mp", Lk)
    tie = C.ellipsoid("mpony_tie", W((0.0, 0.112, 1.545)), (0.022 * rig.k, 0.020 * rig.k, 0.020 * rig.k))
    rig.add(tie, "mpony_tie", "hair_tie", J["head"], g, prio=1.6)
    o = C.lock("mpony_tail", W((0.0, 0.122, 1.545)), W((0.0, 0.150, 1.380)), 0.040, bend=W((0.0, 0.03, 0.0)), flat=0.8,
               twist_axis=(1, 0, 0), rings=6, seg=10)
    rig.add(o, "mpony_tail", "hair", J["head"], g, prio=1.1, clump=f"{g}:mass")


def hair_curly(rig, body, P, W, J):
    """Cachos: massa arredondada de cachos pequenos, franja de cachos na testa."""
    import random
    g = "hair:curly"
    _scalp(rig, W, J, g, "curly_cap", 0.030, 1.630, 1.585, 1.50)
    rnd = random.Random(7)
    k = rig.k
    i = 0
    for z in (1.60, 1.64, 1.68, 1.72, 1.755):
        n = 14 if z < 1.7 else 9
        for j in range(n):
            ang = math.tau * (j + 0.5 * (z > 1.65)) / n
            y = -math.cos(ang); x = math.sin(ang)
            if y < -0.55 and z < 1.66:
                continue  # rosto livre (a franja vem separada)
            rr = {1.60: 0.125, 1.64: 0.128, 1.68: 0.120, 1.72: 0.098, 1.755: 0.060}[z]
            c = W((x * rr, y * rr * 1.03 + 0.008, z + rnd.uniform(-0.01, 0.01)))
            o = C.ellipsoid(f"curl{i}", c, (0.034 * k, 0.034 * k, 0.030 * k), seg=10, rings=7)
            rig.add(o, f"curl_c{i % 3}", "hair", J["head"], g, prio=1.1, clump=f"{g}:c{i % 3}")
            i += 1
    for x in (-0.07, -0.035, 0.0, 0.035, 0.07):
        o = C.ellipsoid(f"curlb{x}", W((x, -0.105, 1.625 + 0.01 * abs(x) / 0.07)), (0.026 * k, 0.022 * k, 0.026 * k), seg=10, rings=7)
        rig.add(o, "curl_b", "hair", J["head"], g, prio=1.2, clump=f"{g}:b")


def hair_bob(rig, body, P, W, J):
    """Chanel: franja reta e volume ate o queixo, arredondado nas pontas."""
    g = "hair:bob"
    k = rig.k
    _scalp(rig, W, J, g, "bob_cap", 0.018, 1.622, 1.600, 1.49)
    _bangs(rig, W, J, g, [(-0.06, -0.075, 1.598, 0.032, 0.0), (-0.02, -0.025, 1.592, 0.034, 0.0),
                          (0.02, 0.025, 1.592, 0.034, 0.0), (0.06, 0.075, 1.598, 0.032, 0.0)])
    secs = []
    for z, r, yb in ((1.64, 0.118, 0.008), (1.58, 0.128, 0.012), (1.52, 0.130, 0.018), (1.47, 0.122, 0.024), (1.445, 0.108, 0.028)):
        secs.append((W((0, yb, z)), r * k, (r + 0.004) * k))
    skirt = C.loft("bob_skirt", secs, seg=28, arc=(1.05, math.tau - 1.05), cap0=False, cap1=False)
    rig.add(skirt, "bob_skirt", "hair", J["head"], g, prio=1.1, clump=f"{g}:mass")
    for s in (1, -1):
        o = C.lock(f"bob_side{s}", W((s * 0.100, -0.030, 1.640)), W((s * 0.112, -0.050, 1.455)), 0.030, bend=W((s * 0.02, -0.01, 0)), flat=0.5, twist_axis=(0, 1, 0))
        rig.add(o, f"bob_side{s}", "hair", J["head"], g, prio=1.15, clump=f"{g}:mass")


def hair_waves(rig, body, P, W, J):
    """Longo e ondulado, solto ate o meio das costas."""
    g = "hair:waves"
    _scalp(rig, W, J, g, "wave_cap", 0.016, 1.622, 1.575, 1.52)
    _bangs(rig, W, J, g, [(-0.06, -0.090, 1.605, 0.030, 0.0), (-0.015, -0.035, 1.594, 0.034, 0.0),
                          (0.03, 0.045, 1.598, 0.032, 0.0), (0.066, 0.092, 1.612, 0.028, 0.0)])
    Lk = []
    for s in (1, -1):
        Lk.append((W((s * 0.088, -0.020, 1.640)), W((s * 0.118, -0.030, 1.380)), 0.028, W((s * 0.03, -0.02, 0.0)), 0.55))
        Lk.append((W((s * 0.095, 0.040, 1.650)), W((s * 0.140, 0.070, 1.300)), 0.040, W((s * 0.03, 0.02, 0.0)), 0.6))
    for x in (-0.07, -0.023, 0.023, 0.07):
        Lk.append((W((x, 0.080, 1.660)), W((x * 1.4, 0.150, 1.230)), 0.048, W((x * 0.3, 0.035, 0.0)), 0.55))
    _locks(rig, J, g, "wv", Lk)


def hair_braid(rig, body, P, W, J):
    """Franja de lado e uma tranca grossa caindo por cima do ombro esquerdo (da personagem)."""
    g = "hair:braid"
    k = rig.k
    _scalp(rig, W, J, g, "braid_cap", 0.015, 1.625, 1.580, 1.50)
    _bangs(rig, W, J, g, [(0.05, -0.030, 1.610, 0.038, -0.02), (0.0, -0.070, 1.600, 0.034, -0.02),
                          (-0.045, -0.100, 1.622, 0.028, -0.02)])
    Lk = []
    for s in (1, -1):
        Lk.append((W((s * 0.090, -0.012, 1.640)), W((s * 0.108, -0.028, 1.500)), 0.022, W((s * 0.012, -0.01, 0.0)), 0.5))
    _locks(rig, J, g, "br", Lk)
    # tranca: nasce atras da orelha esquerda e cai por cima do ombro, a frente do peito
    pts = [W((0.080, 0.060, 1.540)), W((0.110, 0.030, 1.460)), W((0.120, -0.040, 1.400)), W((0.118, -0.085, 1.330)),
           W((0.112, -0.105, 1.260)), W((0.108, -0.110, 1.200))]
    for i in range(len(pts) - 1):
        for h in range(2):
            c = pts[i].lerp(pts[i + 1], 0.25 + 0.5 * h)
            r = (0.034 - 0.003 * i) * k
            o = C.ellipsoid(f"braid{i}_{h}", c, (r, r * 0.8, r * 1.15), seg=10, rings=7)
            rig.add(o, f"braid{i}_{h}", "hair", J["chest"] if i >= 1 else J["head"], g, prio=1.15)
    tie = C.ellipsoid("braid_tie", W((0.108, -0.110, 1.215)), (0.018 * k, 0.016 * k, 0.012 * k))
    rig.add(tie, "braid_tie", "hair_tie", J["chest"], g, prio=1.7)


HAIR_BUILD = {"spiky": hair_spiky, "neat": hair_neat, "curly": hair_curly, "bob": hair_bob, "waves": hair_waves,
              "braid": hair_braid,
              "ponytail": lambda rig, body, P, W, J: (hair_ponytail_f if body == "female" else hair_ponytail_m)(rig, body, P, W, J)}


# ------------------------------------------------------------------ brincos, chapeus e armas
EARRINGS = ["hoop", "seed", "feather"]
HEADS = ["straw_hat", "ipe_flower_crown"]
WEAPONS = ["blade", "staff"]


def earrings(rig, body, P, W, J):
    k = rig.k
    for s, nm in ((1, "L"), (-1, "R")):
        lobe = W((s * 0.104, 0.004, 1.522))
        g = "ear:hoop"
        tor = C.loft(f"hoop_{nm}", [(lobe + W((s * 0.004, 0, -0.018 + 0.018 * math.cos(t))) + W((0, 0.018 * math.sin(t), 0)),
                                      0.005 * k, 0.005 * k, (0, math.cos(t), -math.sin(t))) for t in [i * math.tau / 10 for i in range(11)]],
                     seg=6, cap0=False, cap1=False)
        rig.add(tor, f"hoop_{nm}", "gold", J["head"], g, prio=3.0)
        g = "ear:seed"
        rig.add(C.ellipsoid(f"seedc_{nm}", lobe + W((s * 0.004, 0, -0.008)), (0.006 * k,) * 3), f"seedc_{nm}", "gold", J["head"], g, prio=3.0)
        rig.add(C.ellipsoid(f"seed_{nm}", lobe + W((s * 0.006, 0, -0.030)), (0.011 * k, 0.010 * k, 0.016 * k)), f"seed_{nm}", "seed", J["head"], g, prio=3.0)
        g = "ear:feather"
        rig.add(C.ellipsoid(f"feaa_{nm}", lobe + W((s * 0.004, 0, -0.008)), (0.006 * k,) * 3), f"feaa_{nm}", "gold", J["head"], g, prio=3.0)
        fe = C.ellipsoid(f"fea_{nm}", lobe + W((s * 0.008, 0.004, -0.045)), (0.006 * k, 0.012 * k, 0.034 * k), rot=(0.2, 0, 0))
        rig.face_parts(fe, lambda c, n, lz=lobe.z: ("fea_tip", "feather_tip", {"prio": 3.0}) if c.z < lz - 0.062 * k else None, g)
        rig.add(fe, f"fea_{nm}", "feather", J["head"], g, prio=3.0)


def heads(rig, body, P, W, J):
    k = rig.k
    g = "head:straw_hat"
    tilt = (0, 0, 0)
    brim = C.ellipsoid("hat_brim", W((0, 0.010, 1.712)), (0.215 * k, 0.225 * k, 0.014 * k), seg=28, rings=8, rot=tilt)
    rig.add(brim, "hat_brim", "straw", J["head"], g, prio=1.3)
    crown = C.loft("hat_crown", [(W((0, 0.022, 1.705)), 0.118 * k, 0.126 * k), (W((0, 0.030, 1.765)), 0.112 * k, 0.118 * k),
                                 (W((0, 0.034, 1.800)), 0.100 * k, 0.106 * k), (W((0, 0.036, 1.815)), 0.060 * k, 0.064 * k)], seg=24)
    rig.face_parts(crown, lambda c, n: ("hat_band", "hat_band", {}) if c.z < 1.742 * k and abs(n.z) < 0.7 else None, g)
    rig.add(crown, "hat_crown", "straw", J["head"], g, prio=1.3)
    g = "head:ipe_flower_crown"
    for i in range(12):
        t = math.tau * i / 12
        c = W((math.sin(t) * 0.118, -math.cos(t) * 0.124 + 0.010, 1.690 + 0.012 * math.cos(t)))
        if i % 2 == 0:
            rig.add(C.ellipsoid(f"ipe{i}", c, (0.024 * k, 0.024 * k, 0.018 * k), seg=10, rings=6), "ipe_flower", "ipe", J["head"], g, prio=2.0)
            rig.add(C.ellipsoid(f"ipec{i}", c + W((math.sin(t) * 0.012, -math.cos(t) * 0.012, 0.012)), (0.008 * k,) * 3), "ipe_center", "ipe_core", J["head"], g, prio=2.5)
        else:
            rig.add(C.ellipsoid(f"ipel{i}", c, (0.020 * k, 0.012 * k, 0.010 * k), seg=8, rings=5, rot=(0, 0, t)), "ipe_leaf", "leaf", J["head"], g, prio=1.6)


def weapons(rig, body, P, W, J):
    k = rig.k
    grip = rig.world_loc["grip_R"] if "grip_R" in rig.world_loc else rig.world_loc["hand_R"]
    hand = J["hand_R"]
    g = "weapon:blade"
    hd = (rig.world_loc["hand_R"] - rig.world_loc["farm_R"]).normalized()   # direcao da mao (caida ou em T)
    d = (V((0, -1.0, 0)) + hd * 1.6).normalized()   # lamina para frente e para baixo com o braco relaxado
    pom = grip - d * 0.070 * k
    rig.add(C.capsule("bl_handle", pom, grip + d * 0.040 * k, 0.014 * k, 0.014 * k, seg=8, rings=3), "bl_handle", "wood", hand, g, prio=1.6)
    gd = grip + d * 0.050 * k
    rig.add(C.box("bl_guard", gd, (0.075 * k, 0.020 * k, 0.018 * k), rot=(math.atan2(d.y, -d.z), 0, 0), bevel=0.5), "bl_guard", "brass", hand, g, prio=1.8)
    tip = gd + d * 0.520 * k
    blade = C.loft("bl_blade", [(gd + d * 0.01, 0.010 * k, 0.020 * k, tuple(d)), (gd.lerp(tip, 0.5), 0.008 * k, 0.026 * k, tuple(d)),
                                (gd.lerp(tip, 0.88), 0.006 * k, 0.020 * k, tuple(d)), (tip, 0.002 * k, 0.004 * k, tuple(d))], seg=8)
    rig.add(blade, "bl_blade", "steel", hand, g, prio=1.7)
    g = "weapon:staff"
    up = (-hd + V((0, -0.08, 0))).normalized()     # cajado ao longo do antebraco (vertical com o braco caido)
    a = grip - up * 0.45 * k; b = grip + up * 1.05 * k
    rig.add(C.capsule("st_pole", a, b, 0.017 * k, 0.015 * k, seg=8, rings=3), "st_pole", "wood", hand, g, prio=1.6)
    rig.add(C.ellipsoid("st_knot", b + up * 0.02, (0.030 * k, 0.030 * k, 0.040 * k)), "st_knot", "wood_dark", hand, g, prio=1.8)
    rig.add(C.ellipsoid("st_gem", b + up * 0.075 * k, (0.024 * k, 0.024 * k, 0.034 * k), seg=8, rings=6), "st_gem", "gem_green", hand, g, prio=2.2)
    for sgn in (1, -1):
        rig.add(C.lock(f"st_prong{sgn}", b + up * 0.01, b + up * 0.11 * k + V((sgn * 0.035 * k, 0, 0)), 0.010 * k, flat=0.8),
                f"st_prong{sgn}", "wood_dark", hand, g, prio=1.8)


def _todo_hair(style):
    def f(rig, body, P, W, J):
        pass
    return f
