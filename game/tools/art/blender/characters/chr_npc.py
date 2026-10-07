"""NPCs pelo mesmo esqueleto do personagem jogavel (docs/arte-personagens-blender.md, secao NPCs).

Um NPC e so CONFIGURACAO: npcs/<id>.json com
  body        "male" | "female"
  props       proporcoes que sobrepoem chr_body.BODY (h = altura relativa, sh = ombros, chest/waist/pelvis
              = raios do tronco, head_scale, arm_r/leg_r ...)
  pose        ajuste de postura somado a toda animacao (ex.: {"spine": 0.12} = curvado)
  parts       lista de pecas da biblioteca abaixo ({"type": ..., "mat": ..., parametros})
  colors      rampas: skin (4), hair (5), eyes (4) e familias novas de material {"nome": [4 tons, contorno]}
  anims       animacoes da folha (padrao idle:8, walk:8)
Sai uma folha INTEIRA por animacao (sem camadas de paper doll), no formato de assets/npcs/npc_<id>_<anim>.png.

A biblioteca reaproveita os construtores das roupas do jogador (chr_body): casca de tronco, saia/casaco,
mangas/pernas, botas, cabelos, armas."""
import json, math, os
from mathutils import Vector as V
import chr_lib as C
import chr_body as B

HERE = os.path.dirname(os.path.abspath(__file__))
NPC_DIR = os.path.join(HERE, "npcs")


def load(npc_id):
    return json.load(open(os.path.join(NPC_DIR, f"{npc_id}.json")))


def build(npc_id):
    cfg = load(npc_id)
    g = f"npc:{npc_id}"

    def extra(rig, body, P, W, J):
        for spec in cfg["parts"]:
            PARTS[spec["type"]](rig, W, J, g, spec)
    if cfg.get("base", "q") == "q":
        import chr_qbody as QB
        rig = QB.build(cfg["body"], want=set(), props=cfg.get("props"), extra=extra, name=f"npc_{npc_id}")
    else:
        rig = B.build(cfg["body"], want=set(), props=cfg.get("props"), extra=extra, name=f"npc_{npc_id}")
    rig.npc = cfg
    return rig


# ------------------------------------------------------------------ biblioteca de pecas
def _k(rig):
    return rig.k


def p_shirt(rig, W, J, g, sp):
    k = rig.k
    top = sp.get("top", 1.40)
    zs = [z for z in (0.84, 0.90, 0.98, 1.08, 1.20, 1.30, 1.365, 1.40) if z >= sp.get("bottom", 0.84) - 1e-6 and z <= top + 1e-6]
    sh = B._shell(rig, W, f"{g}_shirt", zs, sp.get("grow", 0.012))
    if sp.get("vneck"):
        rig.face_parts(sh, lambda c, n: (f"{g}_vneck", "skin", {}) if c.y < -0.05 * k and abs(c.x) < (c.z / k - 1.25) * 0.35 * k and c.z > 1.27 * k else None, g)
    rig.add(sh, f"{g}_shirt", sp["mat"], J["chest"], g)
    sleeves = sp.get("sleeves", "long")
    for s, nm in ((1, "L"), (-1, "R")):
        if sleeves == "short":
            B._limb_cloth(rig, W, J, nm, f"{g}_slv", sp["mat"], sp.get("sleeve_grow", 0.026), g, lower=False)
        elif sleeves == "rolled":
            B._limb_cloth(rig, W, J, nm, f"{g}_slv", sp["mat"], 0.020, g, z_end=0.45, cuff=sp.get("cuff", sp["mat"]))
        elif sleeves == "long":
            B._limb_cloth(rig, W, J, nm, f"{g}_slv", sp["mat"], sp.get("sleeve_grow", 0.016), g, z_end=0.88, cuff=sp.get("cuff"))


def p_vest(rig, W, J, g, sp):
    gap = sp.get("gap", 0.42)
    v = B._shell(rig, W, f"{g}_vest", [sp.get("bottom", 0.97), 1.05, 1.15, 1.25, 1.32, 1.37, 1.405], sp.get("grow", 0.024),
                 arc=(gap, math.tau - gap))
    if sp.get("edge"):
        rig.face_parts(v, lambda c, n: (f"{g}_vest_edge", sp["edge"], {}) if abs(B._ang(c)) < gap + 0.13 else None, g)
    rig.add(v, f"{g}_vest", sp["mat"], J["chest"], g, prio=1.05)


def p_coat(rig, W, J, g, sp):
    """Casaco/tunica longa: parte de cima (aberta ou fechada) + saia ate z_bot."""
    gap = sp.get("gap", 0.34)
    up = B._shell(rig, W, f"{g}_coat", [0.96, 1.05, 1.15, 1.25, 1.32, 1.37, 1.405], sp.get("grow", 0.024),
                  arc=(gap, math.tau - gap) if gap > 0 else None)
    if sp.get("trim"):
        rig.face_parts(up, lambda c, n: (f"{g}_coat_trim", sp["trim"], {"prio": 1.4}) if gap > 0 and abs(B._ang(c)) < gap + 0.11 else None, g)
    rig.add(up, f"{g}_coat", sp["mat"], J["chest"], g, prio=1.05)
    B._skirt(rig, W, J, g, f"{g}_skirt", sp["mat"], 1.00, sp.get("z_bot", 0.45), sp.get("r_top", 0.160) + sp.get("belly", 0.0),
             sp.get("r_bot", 0.215) + sp.get("belly", 0.0), max(gap, 0.0), trim=sp.get("trim"), emb=sp.get("emb"))
    if sp.get("sleeves", True):
        for s, nm in ((1, "L"), (-1, "R")):
            B._limb_cloth(rig, W, J, nm, f"{g}_cslv", sp["mat"], sp.get("sleeve_grow", 0.018), g, z_end=sp.get("sleeve_end", 0.88),
                          cuff=sp.get("cuff"))


def p_skirt(rig, W, J, g, sp):
    B._skirt(rig, W, J, g, f"{g}_lskirt", sp["mat"], sp.get("z_top", 1.02), sp.get("z_bot", 0.10), sp.get("r_top", 0.150),
             sp.get("r_bot", 0.230), 0.0, trim=sp.get("trim"), hem_h=sp.get("hem_h", 0.05), prio=1.05)


def p_apron(rig, W, J, g, sp):
    B._skirt(rig, W, J, g, f"{g}_apron", sp["mat"], sp.get("z_top", 1.12), sp.get("z_bot", 0.52), 0.160 + sp.get("belly", 0.0),
             0.185 + sp.get("belly", 0.0), 0.0, yb=-0.02, prio=1.2, cut=lambda c, n: abs(B._ang(c)) > sp.get("half", 0.95))


def p_sash(rig, W, J, g, sp):
    k = rig.k
    sa = B._shell(rig, W, f"{g}_sash", [0.94, 0.98, 1.02, 1.06], sp.get("grow", 0.032))
    rig.add(sa, f"{g}_sash", sp["mat"], J["pelvis"], g, prio=1.2)
    if sp.get("tail", True):
        x = sp.get("side", 1) * 0.12
        tail = C.strip(f"{g}_sash_tail", [W((x, -0.110, 0.97)), W((x * 1.15, -0.118, 0.82)), W((x * 1.2, -0.110, 0.66))],
                       0.060 * k, normal=(0.3, -1, 0), thick=0.008)
        rig.add(tail, f"{g}_sash_tail", sp["mat"], J["pelvis"], g, prio=1.3)


def p_belt(rig, W, J, g, sp):
    k = rig.k
    b = B._shell(rig, W, f"{g}_belt", [0.975, 1.00, 1.03], sp.get("grow", 0.036))
    rig.add(b, f"{g}_belt", sp["mat"], J["pelvis"], g, prio=1.3)
    if sp.get("buckle"):
        rig.add(C.box(f"{g}_buckle", W((0, -0.128 - sp.get("grow", 0.036) + 0.036, 1.003)), (0.046 * k, 0.018 * k, 0.038 * k)),
                f"{g}_buckle", sp["buckle"], J["pelvis"], g, prio=2.0)
    for i, pos in enumerate(sp.get("pouches", [])):
        rig.add(C.box(f"{g}_pouch{i}", W(tuple(pos)), (0.055 * k, 0.040 * k, 0.065 * k), bevel=0.45), f"{g}_pouch", sp.get("pouch_mat", sp["mat"]),
                J["pelvis"], g, prio=1.4)


def p_pants(rig, W, J, g, sp):
    B._pants(rig, W, J, g, sp["mat"], grow=sp.get("grow", 0.012))


def p_boots(rig, W, J, g, sp):
    B._shoes(rig, W, J, g, sp["mat"], sp.get("sole", "boot_sole"), f"{g}_boot", height=0.090, toe_cap=sp.get("toe"),
             boot_top=sp.get("top", 0.25), boot_mat=(sp["mat"], sp.get("rim", sp["mat"])), boot_r=(0.058, 0.066))


def p_shoes(rig, W, J, g, sp):
    B._shoes(rig, W, J, g, sp["mat"], sp.get("sole", "boot_sole"), f"{g}_shoe", height=0.080)


def p_shawl(rig, W, J, g, sp):
    """Xale/poncho sobre os ombros (casca larga do peito ao meio das costas)."""
    k = rig.k
    zs = [1.10, 1.18, 1.26, 1.32, 1.36, 1.385]
    sw = B._shell(rig, W, f"{g}_shawl", zs, sp.get("grow", 0.038))
    if sp.get("trim"):
        rig.face_parts(sw, lambda c, n: (f"{g}_shawl_trim", sp["trim"], {"prio": 1.3}) if c.z < 1.15 * k else None, g)
    rig.add(sw, f"{g}_shawl", sp["mat"], J["chest"], g, prio=1.15)
    for s, nm in ((1, "L"), (-1, "R")):
        sh = rig.world_loc[f"uarm_{nm}"]
        cap = C.ellipsoid(f"{g}_shcap_{nm}", sh + W((s * 0.006, 0.0, -0.020)), (0.062 * k, 0.064 * k, 0.058 * k))
        rig.add(cap, f"{g}_shawl", sp["mat"], J["chest"], g, prio=1.15)


def p_neckerchief(rig, W, J, g, sp):
    k = rig.k
    nr = rig.P["neck_r"]
    sc = C.loft(f"{g}_kerch", [(W((0, 0.012, 1.355)), nr * k + 0.040, nr * k + 0.040), (W((0, 0.010, 1.405)), nr * k + 0.028, nr * k + 0.028)], seg=20)
    rig.add(sc, f"{g}_kerch", sp["mat"], J["chest"], g, prio=1.4)
    tip = C.ellipsoid(f"{g}_kerch_tip", W((0.0, -0.115, 1.33)), (0.040 * k, 0.012 * k, 0.045 * k))
    rig.add(tip, f"{g}_kerch", sp["mat"], J["chest"], g, prio=1.4)


def p_pauldrons(rig, W, J, g, sp):
    k = rig.k
    sides = {"both": ((1, "L"), (-1, "R")), "R": ((-1, "R"),), "L": ((1, "L"),)}[sp.get("side", "both")]
    for s, nm in sides:
        sh = rig.world_loc[f"uarm_{nm}"]
        for i, (dz, r) in enumerate(((0.024, 0.078), (-0.022, 0.066))[: sp.get("plates", 2)]):
            pl = C.ellipsoid(f"{g}_pd{nm}{i}", sh + W((s * 0.014, 0.0, dz)), (r * k, r * 0.95 * k, r * 0.52 * k), rot=(0, s * 0.45, 0))
            rig.add(pl, f"{g}_pd{nm}{i}", sp["mat"], J[f"uarm_{nm}"], g, prio=1.3)


def p_bracers(rig, W, J, g, sp):
    k = rig.k; P = rig.P
    for s, nm in ((1, "L"), (-1, "R")):
        a1, a2 = rig.world_loc[f"farm_{nm}"], rig.world_loc[f"hand_{nm}"]
        br = C.capsule(f"{g}_br_{nm}", a1.lerp(a2, 0.35), a1.lerp(a2, 0.92), P["arm_r"][1] * k + 0.014, P["arm_r"][2] * k + 0.014)
        rig.add(br, f"{g}_br_{nm}", sp["mat"], J[f"farm_{nm}"], g, prio=1.2)


def p_hat_wide(rig, W, J, g, sp):
    """Chapeu de abas largas: na cabeca, ou pendurado nas costas (pos = back)."""
    k = rig.k
    if sp.get("pos") == "back":
        c = W((0, 0.140, 1.22))
        brim = C.ellipsoid(f"{g}_hbrim", c, (0.200 * k, 0.012 * k, 0.200 * k), seg=24, rings=8)
        crown = C.ellipsoid(f"{g}_hcrown", c + W((0, 0.035, 0.015)), (0.110 * k, 0.050 * k, 0.105 * k))
        rig.add(brim, f"{g}_hbrim", sp["mat"], J["chest"], g, prio=1.2)
        rig.add(crown, f"{g}_hcrown", sp["mat"], J["chest"], g, prio=1.2)
        rig.add(C.strip(f"{g}_hcord", [W((-0.07, -0.08, 1.38)), W((0.0, -0.118, 1.30)), W((0.07, -0.08, 1.38))], 0.008 * k, thick=0.005),
                f"{g}_hcord", sp.get("band", sp["mat"]), J["chest"], g, prio=1.5)
        return
    z = sp.get("z", 1.712)
    r = sp.get("r", 0.225)
    brim = C.ellipsoid(f"{g}_hbrim", W((0, 0.010, z)), (r * k, (r + 0.01) * k, 0.014 * k), seg=28, rings=8)
    rig.add(brim, f"{g}_hbrim", sp["mat"], J["head"], g, prio=1.3)
    if sp.get("pointy"):
        cr = C.lock(f"{g}_hcrown", W((0, 0.02, z - 0.01)), W((0.02, 0.06, z + 0.20)), 0.112 * k, flat=1.0, r1=0.012 * k,
                    bend=W((0, 0.03, 0)))
    else:
        cr = C.loft(f"{g}_hcrown", [(W((0, 0.022, z - 0.007)), 0.118 * k, 0.126 * k), (W((0, 0.030, z + 0.053)), 0.112 * k, 0.118 * k),
                                    (W((0, 0.034, z + 0.088)), 0.100 * k, 0.106 * k), (W((0, 0.036, z + 0.103)), 0.060 * k, 0.064 * k)], seg=24)
    if sp.get("band"):
        rig.face_parts(cr, lambda c, n: (f"{g}_hband", sp["band"], {}) if c.z < (z + 0.030) * k and abs(n.z) < 0.8 else None, g)
    rig.add(cr, f"{g}_hcrown", sp["mat"], J["head"], g, prio=1.3)


def p_glasses(rig, W, J, g, sp):
    k = rig.k
    for s in (1, -1):
        c = W((s * 0.041, -0.112, 1.546))
        ring = C.loft(f"{g}_gl{s}", [(c + W((0.020 * math.cos(t), 0, 0.020 * math.sin(t))), 0.0035 * k, 0.0035 * k,
                                       (-math.sin(t), 0, math.cos(t))) for t in [i * math.tau / 12 for i in range(13)]],
                      seg=5, cap0=False, cap1=False)
        rig.add(ring, f"{g}_glasses", sp["mat"], J["head"], g, prio=3.0)
    rig.add(C.strip(f"{g}_glb", [W((-0.020, -0.114, 1.550)), W((0.020, -0.114, 1.550))], 0.005 * k, thick=0.003),
            f"{g}_glasses", sp["mat"], J["head"], g, prio=3.0)


def p_beard(rig, W, J, g, sp):
    """Barba: casca na parte de baixo do rosto (queixo e bochechas), boca livre."""
    k = rig.k
    secs = B.head_sections(W, grow=sp.get("grow", 0.008))[:5]
    bd = C.loft(f"{g}_beard", secs, seg=20, cap0=True, cap1=False)
    full = sp.get("style", "full") == "full"
    zc = (1.535 if full else 1.50) * k
    B._cut(bd, lambda c, n: c.y > 0.02 * k or c.z > zc or (abs(c.x) < 0.028 * k and 1.466 * k < c.z < 1.492 * k and c.y < 0))
    rig.add(bd, f"{g}_beard", sp.get("mat", "hair"), J["head"], g, prio=1.2, clump=f"{g}:beard")


def p_hair(rig, W, J, g, sp):
    """Cabelo do jogador (estilo) ou coque (bun)."""
    style = sp["style"]
    if style == "bun":
        k = rig.k
        B._scalp(rig, W, J, g, f"{g}_bcap", sp.get("grow", 0.012), 1.650, 1.590, 1.50)
        pos = sp.get("at", [0.0, 0.080, 1.715])
        bun = C.ellipsoid(f"{g}_bun", W(tuple(pos)), (0.055 * k, 0.050 * k, 0.050 * k))
        rig.add(bun, f"{g}_bun", "hair", J["head"], g, prio=1.2, clump=f"{g}:mass")
        B._bangs(rig, W, J, g, [(-0.05, -0.080, 1.640, 0.030, 0.0), (0.0, 0.0, 1.640, 0.030, 0.0), (0.05, 0.080, 1.640, 0.030, 0.0)],
                 prefix=f"{g}_bb")
        if sp.get("flower"):
            rig.add(C.ellipsoid(f"{g}_flower", W(tuple(sp["flower_at"])), (0.024 * k, 0.020 * k, 0.024 * k)), f"{g}_flower", sp["flower"],
                    J["head"], g, prio=2.5)
        return
    # estilos do jogador, com o grupo do NPC
    fn = B.HAIR_BUILD[style]
    before = set(rig.groups.keys())
    fn(rig, rig.body, rig.P, W, J)
    for gg in set(rig.groups.keys()) - before:
        for o in rig.groups.pop(gg):
            o["group"] = g
            rig.groups.setdefault(g, []).append(o)
            info = rig.part_info[int(o["pid"])]
            info["group"] = g


def p_weapon_hip(rig, W, J, g, sp):
    """Facao/espada na bainha no quadril (esquerdo)."""
    k = rig.k
    s = sp.get("side", 1)
    top = W((s * 0.150, -0.020, 1.00)); bot = W((s * 0.185, 0.080, 0.52))
    rig.add(C.capsule(f"{g}_sheath", top, bot, 0.020 * k, 0.014 * k, seg=8, rings=3), f"{g}_sheath", sp.get("mat", "leather"), J["pelvis"], g, prio=1.4)
    rig.add(C.capsule(f"{g}_hilt", top, top + W((s * -0.01, -0.030, 0.10)), 0.013 * k, 0.013 * k, seg=8, rings=3), f"{g}_hilt",
            sp.get("hilt", "wood"), J["pelvis"], g, prio=1.6)


def p_staff(rig, W, J, g, sp):
    k = rig.k
    grip = rig.world_loc["grip_R"]
    hd = (rig.world_loc["hand_R"] - rig.world_loc["farm_R"]).normalized()   # antebraco (caido ou em T)
    up = (-hd + V((0, -0.08, 0))).normalized()
    a = grip - up * 0.50 * k; b = grip + up * 0.95 * k
    rig.add(C.capsule(f"{g}_pole", a, b, 0.017 * k, 0.015 * k, seg=8, rings=3), f"{g}_pole", sp.get("mat", "wood"), J["hand_R"], g, prio=1.6)
    if sp.get("top") == "flame":
        rig.add(C.ellipsoid(f"{g}_cup", b + up * 0.01, (0.030 * k, 0.030 * k, 0.020 * k)), f"{g}_cup", "brass", J["hand_R"], g, prio=1.8)
        rig.add(C.lock(f"{g}_flame", b + up * 0.02, b + up * 0.12 * k, 0.030 * k, flat=0.8), f"{g}_flame", "flame", J["hand_R"], g,
                prio=2.5, noline=True)


def p_lights(rig, W, J, g, sp):
    """Luzinhas flutuando ao redor (Orvalho): esferas acesas presas ao 'root' (o pos anima o brilho)."""
    k = rig.k
    for i, pos in enumerate(sp.get("at", [[0.30, 0.05, 1.50], [-0.28, 0.10, 1.25], [0.22, -0.10, 1.05]])):
        o = C.ellipsoid(f"{g}_light{i}", W(tuple(pos)), (0.022 * k,) * 3, seg=8, rings=6)
        rig.add(o, f"{g}_light", "glow", rig.root, g, prio=3.0, noline=True)


def p_pockets(rig, W, J, g, sp):
    k = rig.k
    for i, pos in enumerate(sp["at"]):
        o = C.box(f"{g}_pk{i}", W(tuple(pos)), (0.050 * k, 0.020 * k, 0.050 * k), bevel=0.4)
        rig.add(o, f"{g}_pocket", sp["mat"], J["chest"] if pos[2] > 1.05 else J["pelvis"], g, prio=1.6)


def p_q(rig, W, J, g, sp):
    """Peca modular Quaternius recolorida: {"part": "Peasant_Body", "cmap": {classe: material}, "only": [...],
    "mirror": false, "hands": "skin", "cut_above": z (m, apaga faces acima), "cut_below": z}."""
    import chr_qbody as QB
    ca, cb = sp.get("cut_above"), sp.get("cut_below")
    drop = None
    if ca is not None or cb is not None:
        drop = lambda c, cls, bn: (ca is not None and c.z > ca * rig.g) or (cb is not None and c.z < cb * rig.g)  # noqa
    QB.qpart(rig, sp["part"], g, sp["cmap"], only=sp.get("only"), mirror=sp.get("mirror", False),
             hands=sp.get("hands", "skin"), drop=drop)


def p_skin(rig, W, J, g, sp):
    """Partes do proprio corpo: pele a mostra ou roupa justa ({"bones": [...], "mat": "denim", "inflate": 0.01})."""
    import chr_qbody as QB
    QB.body_skin(rig, g, set(sp["bones"]), mat=sp.get("mat"), inflate=sp.get("inflate", 0.0) * rig.g)


PARTS = {"shirt": p_shirt, "vest": p_vest, "coat": p_coat, "skirt": p_skirt, "apron": p_apron, "sash": p_sash, "belt": p_belt,
         "pants": p_pants, "boots": p_boots, "shoes": p_shoes, "shawl": p_shawl, "neckerchief": p_neckerchief,
         "pauldrons": p_pauldrons, "bracers": p_bracers, "hat_wide": p_hat_wide, "glasses": p_glasses, "beard": p_beard,
         "hair": p_hair, "weapon_hip": p_weapon_hip, "staff": p_staff, "lights": p_lights, "pockets": p_pockets,
         "q": p_q, "skin": p_skin}
