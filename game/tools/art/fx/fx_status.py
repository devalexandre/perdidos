"""Efeitos de ESTADO (30/09/2026): cura, aura de reforco por tipo, marcas de debuff sobre a cabeca,
provocacao, cipos de prisao nos pes e a flecha do ataque basico com arco.

Auras: cada tipo tem um MOTIVO proprio subindo do chao (nada de anel liso): ataque = divisas vermelhas,
defesa = escamas de bronze, magia = pontinhos turquesa de vaga-lume, critico = lascas douradas, esquiva = fiapos
de vento com folha, protecao = placas de casca, vida = folhas e brotos, mana = gotas azuis, roubo de vida =
gotas vermelhas girando para dentro."""
from __future__ import annotations

import math

from fxdraw import Canvas, Frame, Spr, blit, ease_out, layer, lerp, piece, rng
from fxsabia import (BLOOD, BLOOD_LINE, BRONZE, BRONZE_LINE, CRYSTAL_G, D, DUST, DUST_LINE, EMBER_G,
                     FEATHER_DARK, K, LEAF, LEAF_G, LEAF_LINE, LEAFLET_PAL, LEAFLET_TXT, MANA_G, MATINTA_G,
                     OLIVE_G, RAGE_G, SAP_G, TAU, TAUNT_PAL, TAUNT_TXT, W_GOLD, W_PALE, W_WHITE, WOOD, WOOD_LINE,
                     arrow, dither_alpha, drop, feather, leaf, leaf_poly, spr, spiral_vine, vine)

B = 128          # quadro das auras (em pe, pivo nos pes)
FEET = (64, 124)


# ------------------------------------------------------------------ cura
def heal_leaves():
    """Cura: folhinhas e sementes verdes subindo em espiral em volta do corpo, riscos de luz curtos subindo e
    um brotar de luz nos pes."""
    frames = []
    r = rng(1100)
    parts = [(r.uniform(0, TAU), r.uniform(0.0, 0.45), r.integers(0, 3)) for _ in range(14)]
    dashes = [(r.uniform(-30, 30), r.uniform(0, 0.5), r.uniform(10, 18)) for _ in range(9)]
    leaflet = spr(LEAFLET_TXT, LEAFLET_PAL, LEAF_LINE)
    big = leaf()
    for f in range(10):
        t = f / 9.0
        fr = Frame(B)
        cv = Canvas(B)
        v = 1.0 if f < 6 else 1.0 - (f - 5) * 0.22
        for (dx, d0, ln) in dashes:  # riscos curtos de luz verde subindo
            u = (t - d0) / 0.5
            if 0 <= u <= 1:
                y = 120 - u * 96
                cv.stroke([(64 + dx, y + ln), (64 + dx, y)], [0.4, 2.2], [0.25 * v, 0.8 * v])
        g = ease_out(min(1, t * 2.5))
        for k in range(6):  # brotinhos de luz nos pes
            a = k * TAU / 6 + 0.4
            x = 64 + math.cos(a) * 26 * g
            cv.poly(leaf_poly(x, 121 + math.sin(a) * 6, D(-90), 9 * g * v + 0.5, 5 * g), 0.6 * v)
        cv.glow(2.0, 0.8, 0.12 * v)
        fr.paint_canvas(cv, LEAF_G)
        for (a0, delay, kind) in parts:
            u = (t - delay) / 0.55
            if not 0 <= u <= 1:
                continue
            a = a0 + u * 3.0
            x = 64 + math.cos(a) * (20 + 12 * u)
            y = 116 - u * 88
            sp = big if kind == 0 else leaflet.rot(math.degrees(a) * 0.6)
            blit(fr, sp, x, y, alpha=1.0 if u < 0.75 else 0.5)
            if kind == 2 and u < 0.8:
                fr.twinkle(x + 5, y - 4, 2, W_WHITE, "#a6d86a")
        frames.append(fr)
    piece("status_heal", frames, pivot=FEET, blend="mix", plane="billboard", fps=14)
    return frames


# ------------------------------------------------------------------ auras
CHEVRON_TXT = """
....a....
...aba...
..abcba..
.abc.cba.
abc...cba
bc.....cb
"""
SCUTE_TXT = """
..aaaaa..
.abbbbba.
abbcccbba
abcccccba
abcccccba
abbcccbba
.abbbbba.
..aaaaa..
"""
GLINT_TXT = """
....a
...ab
..ab.
.ab..
ab...
b....
"""
BARK_TXT = """
.aaaa.
abbcba
abcbba
abbcba
abcbba
abbcba
.aaaa.
"""
MOTE_TXT = """
.a.
aba
.a.
"""


def _aura(name, sprites, ramp, seed, n=9, fps=10, streak=True, wobble=3.0):
    """Aura em laco (8 quadros): MOTIVOS desenhados (sprites) subindo em volta do corpo, cada um com um risco
    de luz curto embaixo, e alguns parados no chao nos pes. Some em pontilhado no alto."""
    frames = []
    r = rng(seed)
    parts = [(r.uniform(0, 1), r.uniform(-1, 1), int(r.integers(0, len(sprites)))) for _ in range(n)]
    for f in range(8):
        ph = f / 8.0
        cv = Canvas(B)
        fr = Frame(B)
        pos = []
        for (p0, side, si) in parts:
            u = (ph + p0) % 1.0
            x = 64 + side * 30 + math.sin(u * TAU + p0 * 7) * wobble
            y = 118 - u * 100
            pos.append((x, y, u, si))
            if streak:
                cv.stroke([(x, y + 12), (x, y + 5)], [0.3, 1.2], [0.12, 0.4 * math.sin(u * math.pi) + 0.06])
        cv.glow(1.8, 0.8, 0.12)
        fr.paint_canvas(cv, ramp)
        for (x, y, u, si) in pos:
            blit(fr, sprites[si], x, y, alpha=1.0 if u < 0.7 else (0.75 if u < 0.85 else 0.5))
        frames.append(fr)
    piece(name, frames, pivot=FEET, blend="mix", plane="billboard", fps=fps, loop=True)
    return frames


def aura_atk():
    ch = spr(CHEVRON_TXT, {"a": "#ffd0b0", "b": "#e8483a", "c": "#8c1a16"}, "#3a0a0a")
    return _aura("status_aura_atk", [ch, ch.scale(1.0)], RAGE_G, 1200)


def aura_def():
    sc = spr(SCUTE_TXT, {"a": "#ecc070", "b": "#c08a3a", "c": "#8a5a22"}, "#221406")
    return _aura("status_aura_def", [sc, sc.scale(1.5)], BRONZE_G_LOCAL, 1210, n=8, streak=False)


def aura_matk():
    mo = spr(MOTE_TXT, {"a": "#46dcd2", "b": "#ffffff"}, "#0a2a36")
    ff = spr("""
.a.
aba
aba
.a.
""", {"a": "#46dcd2", "b": "#e0fffa"}, "#0a2a36")
    return _aura("status_aura_matk", [mo, ff], CRYSTAL_G, 1220, n=12, wobble=5.0)


def aura_crit():
    gl = spr(GLINT_TXT, {"a": "#fffcf0", "b": "#e6b43a"}, "#5a3a08")
    return _aura("status_aura_crit", [gl, gl.flip(), gl.scale(1.5)], SAP_G, 1230, n=9)


def aura_evade():
    lf = spr(LEAFLET_TXT, {"a": "#c8d08a", "b": "#8a9a4a", "c": "#5a6a2a"}, "#1e2410")
    wisp = spr("""
..aaaa.....
.a....bb...
a.......bb.
..........b
""", {"a": "#e2e8a0", "b": "#a8b44a"}, None)
    return _aura("status_aura_evade", [lf, lf.rot(90), wisp, wisp.flip()], OLIVE_G, 1240, n=8, wobble=7.0, streak=False)


def aura_guard():
    """Protecao (menos dano recebido): plaquinhas de casca de arvore subindo devagar."""
    bk = spr(BARK_TXT, {"a": "#c9985e", "b": "#9c6a3c", "c": "#6b4226"}, "#1e120a")
    return _aura("status_aura_guard", [bk, bk.scale(1.4)], BRONZE_G_LOCAL, 1250, n=7, fps=8, streak=False)


def aura_regen():
    lf = spr(LEAFLET_TXT, LEAFLET_PAL, LEAF_LINE)
    return _aura("status_aura_regen", [lf, lf.rot(30), lf.rot(-30), lf.rot(60)], LEAF_G, 1260, n=9, streak=False)


def aura_mana():
    dp = drop("#d2e8ff", "#84b8f6", "#3a78de").outlined("#0c1c48")
    return _aura("status_aura_mana", [dp, dp.scale(1.4)], MANA_G, 1270, n=10)


def aura_lifesteal():
    """Roubo de vida: gotas vermelhas girando para DENTRO (do largo para o corpo), em laco."""
    frames = []
    dsp = drop("#f07a5a", "#c83228", "#6e1010")
    for f in range(8):
        cv = Canvas(B)
        fr = Frame(B)
        for k in range(7):
            u = (f / 8.0 + k / 7.0) % 1.0
            a = k * 2.1 + u * 2.4
            rad = lerp(46, 10, u)
            x, y = 64 + math.cos(a) * rad, 76 + math.sin(a) * rad * 0.45 - u * 10
            cv.stroke([(x, y), (64 + math.cos(a - 0.4) * (rad + 10), 76 + math.sin(a - 0.4) * (rad + 10) * 0.45)],
                      [2.4, 0.4], [0.5, 0.2])
        cv.glow(2.4, 0.8, 0.14)
        fr.paint_canvas(cv, RAGE_G)
        for k in range(7):
            u = (f / 8.0 + k / 7.0) % 1.0
            a = k * 2.1 + u * 2.4
            rad = lerp(46, 10, u)
            blit(fr, dsp, 64 + math.cos(a) * rad, 76 + math.sin(a) * rad * 0.45 - u * 10, alpha=1.0 if u < 0.8 else 0.5)
        frames.append(fr)
    piece("status_aura_lifesteal", frames, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return frames


# bronze da aura (glow)
from fxsabia import BRONZE_G as BRONZE_G_LOCAL  # noqa: E402


# ------------------------------------------------------------------ marcas de debuff (sobre a cabeca)
M = 64
MARK_PIVOT = (32, 58)
## Marcas desenhadas em pixel maior (1/24 m, 30/09 depois da captura) para ler sobre a cabeca na camera do jogo.
MARK_TEXEL = 1.0 / 24.0


def _mark(name, draw, fps=8, seed=0):
    """Marca em laco sobre a cabeca: balanca devagar (1 px) e pulsa o brilho em volta."""
    frames = []
    for f in range(8):
        fr = Frame(M)
        bob = round(math.sin(f / 8 * TAU) * 1.5)
        draw(fr, f, bob)
        frames.append(fr)
    piece(name, frames, pivot=MARK_PIVOT, blend="mix", plane="billboard", fps=fps, loop=True, texel=MARK_TEXEL)
    return frames


def _down_chevrons(fr, x, y, f, col_a, col_b):
    """Duas divisas para BAIXO descendo em laco (atributo diminuido)."""
    for k in range(2):
        yy = y + ((f + k * 4) % 8) * 1.2
        for i in range(-4, 5):
            fr.px(int(x + i), int(yy - abs(i) * -0.0 + (4 - abs(i)) * 0.9), col_a if k else col_b)
            fr.px(int(x + i), int(yy + 1 + (4 - abs(i)) * 0.9), "#1a0806")


SHIELD_TXT = """
bbbbbbbbbbbbb
bhhhhhhlhhhhb
bhBBBBBlBBBBb
bhBBBBlBBBBBb
bhBBBBBlBBBBb
bhBBBBBBlBBBb
bhBBBBBlBBBBb
.bBBBBlBBBBb.
.bBBBBBlBBBb.
..bBBBBlBBb..
...bBBlBBb...
....bBBlb....
.....bbb.....
"""


def mark_def_down():
    """DEF reduzida: escudo de bronze rachado ao meio, com divisas vermelhas descendo."""
    sh = spr(SHIELD_TXT, {"b": "#221406", "B": "#c08a3a", "h": "#ecc070", "l": "#1a0806"})
    left = Spr(sh.a[:, : sh.w // 2 + 1].copy())
    right = Spr(sh.a[:, sh.w // 2 + 1:].copy())

    def d(fr, f, bob):
        gap = 1 + (1 if f % 4 < 2 else 0)
        blit(fr, left, 24 - gap, 26 + bob, (0.5, 0.5))
        blit(fr, right, 32 + gap, 26 + bob, (0.0, 0.5))
        _down_chevrons(fr, 45, 30 + bob, f, "#e8483a", "#ff9a7a")
    return _mark("status_mark_def_down", d)


def mark_atk_down():
    """ATK reduzido: facao quebrado (ponta caindo) + divisas descendo."""
    from fxsabia import MACHETE_PAL, MACHETE_TXT
    m = spr(MACHETE_TXT, MACHETE_PAL).rot(35)
    hilt = Spr(m.a[:, : m.w // 2].copy())
    tip = Spr(m.a[:, m.w // 2:].copy())

    def d(fr, f, bob):
        blit(fr, hilt, 24, 30 + bob)
        blit(fr, tip.rot(-10 - (f % 4) * 3), 34 + (f % 4), 22 + bob + (f % 4))
        _down_chevrons(fr, 48, 30 + bob, f, "#e8483a", "#ff9a7a")
    return _mark("status_mark_atk_down", d)


SNAIL_TXT = """
.....ssss....
...ssSSSSs...
..sSSsssSSs..
.sSSsSSSsSSs.
.sSsSSsSSsSs.
.sSsSsSsSsSs.
.sSsSSSsSSSs.
.sSSsssSSSs..
bbsSSSSSSsbbb
bBbbssssbbBBBb
bBBBBBBBBBBBBb
.bbbbbbbbbbbb.
"""


def mark_slow():
    """Lentidao: caramujo de lama andando devagar, com baba de lama pingando."""
    sn = spr(SNAIL_TXT, {"s": "#3a2a1a", "S": "#a88a5c", "b": "#5e4428", "B": "#86643c"})
    eye = "#1c140a"

    def d(fr, f, bob):
        x = 32 + (f % 8) * 0.5 - 2
        blit(fr, sn, x, 28 + bob)
        for k in (0, 1):  # anteninhas
            fr.px(int(x + 5 + k * 2), int(28 + bob - 1 - k), eye)
            fr.px(int(x + 5 + k * 2), int(28 + bob - 2 - k), eye)
        dy = (f % 4) * 2
        fr.px(int(x - 6), 36 + bob + dy, "#86643c")
        fr.px(int(x - 6), 37 + bob + dy, "#5e4428")
    return _mark("status_mark_slow", d)


def mark_poison():
    """Veneno: espinho de cipo com gotas verdes-arroxeadas pingando."""
    thorn = spr("""
....a....
...aba...
...abb...
..aabbc..
..abbbc..
.aabbbcc.
.abbbbbc.
aabbbbbcc
""", {"a": "#a6d86a", "b": "#5aa048", "c": "#2f6b3e"})
    dp = drop("#c9a8ec", "#8e66c4", "#5a3a8c")

    def d(fr, f, bob):
        blit(fr, thorn.flipv(), 32, 20 + bob)
        for k in range(2):
            u = ((f + k * 4) % 8) / 8
            blit(fr, dp, 30 + k * 5, 30 + bob + u * 18, alpha=1.0 if u < 0.6 else 0.5)
    return _mark("status_mark_poison", d)


def mark_heal_down():
    """Cura reduzida: folha murcha e escura, com fiapo de fumaca amarga."""
    wl = spr("""
aa...........
abaa.........
.abbaa.......
.abcbbaa.....
..abbcbbaa...
..abbbcbbba..
...abbbbccbb.
....aabbbb.c.
......aaa...c
""", {"a": "#a89858", "b": "#7a6a3a", "c": "#4a3e22"}, "#1e180c")

    def d(fr, f, bob):
        blit(fr, wl, 32, 30 + bob)
        for k in range(3):
            u = ((f + k * 3) % 8) / 8
            fr.px(int(38 + math.sin(u * 6 + k) * 2), int(24 - u * 14 + bob), "#6a6272" if u < 0.5 else "#46404e")
        _down_chevrons(fr, 20, 30 + bob, f, "#8e9a5a", "#c8d08a")
    return _mark("status_mark_heal_down", d)


def mark_vuln():
    """Alvo marcado (recebe mais dano): ponta de flecha vermelha apontando para baixo, com fita, pulsando."""
    tip = spr("""
rrrrrrrrr
.rRRRRRr.
..rRRRr..
...rRr...
....r....
""", {"r": "#6e1010", "R": "#e8483a"})

    def d(fr, f, bob):
        s = 2 if f % 4 < 2 else 1
        t = tip.scale(s) if s > 1 else tip
        blit(fr, t, 32, 32 + bob + (f % 4 < 2) * 0)
        for k in range(-1, 2, 2):  # fitinhas balancando
            for i in range(6):
                fr.px(int(32 + k * (7 + i)), int(24 + bob + math.sin(f / 8 * TAU + i * 0.8) * 1.5 + i * 0.3),
                      "#e8483a" if i % 2 else "#fff4e0")
    return _mark("status_mark_vuln", d)


def mark_debuff():
    """Debuff generico: pena escura da Matinta girando devagar, com poeirinha roxa."""
    fe = feather(FEATHER_DARK)

    def d(fr, f, bob):
        blit(fr, fe.rot(-25 + math.sin(f / 8 * TAU) * 20), 32, 30 + bob)
        for k in range(3):
            u = ((f + k * 3) % 8) / 8
            fr.px(int(26 + k * 6), int(38 + u * 8), "#8e66c4" if u < 0.5 else "#5a3a8c")
    return _mark("status_mark_debuff", d)


def taunt():
    """Provocacao: balao espinhudo vermelho com '!' sobre o monstro — pulsa (cresce 1 px) e balanca."""
    t0 = spr(TAUNT_TXT, TAUNT_PAL)
    t1 = t0.scale(1.25)

    def d(fr, f, bob):
        blit(fr, t1 if f in (0, 1) else t0, 32, 32 + bob)
    return _mark("status_taunt", d, fps=10)


# ------------------------------------------------------------------ cipos de prisao (nos pes)
def root_vines():
    """Presa: tres cipos saindo do chao e subindo em espiral pelas pernas (frente e tras do personagem),
    com folhinhas nas pontas. _back fica atras do corpo, _front na frente."""
    back, front = [], []
    lf = spr(LEAFLET_TXT, LEAFLET_PAL, LEAF_LINE)
    for f in range(8):
        wig = math.sin(f / 8 * TAU)
        for part, dst in (("back", back), ("front", front)):
            cv = Canvas(96)
            fr = Frame(96)
            tips = []
            for k in range(3):
                a0 = k * TAU / 3 + 0.3
                n = 30
                turns = 1.25
                for i in range(n - 1):
                    t0, t1 = i / (n - 1), (i + 1) / (n - 1)
                    a = a0 + t0 * turns * TAU + wig * 0.12 * t0
                    in_front = math.sin(a) > 0
                    if in_front != (part == "front"):
                        continue
                    pts = []
                    for t in (t0, t1):
                        aa = a0 + t * turns * TAU + wig * 0.12 * t
                        rr = lerp(20, 11, t)
                        pts.append((48 + math.cos(aa) * rr, 88 + math.sin(aa) * rr * 0.32 - t * (34 + 4 * k)))
                    w = lerp(4.6, 1.6, t0)
                    cv.stroke(pts, [w, lerp(4.6, 1.6, t1)], [0.5, 0.5])
                    cv.stroke(pts, [w * 0.4, lerp(4.6, 1.6, t1) * 0.4], [0.85, 0.85])
                aa = a0 + turns * TAU + wig * 0.12
                tip = (48 + math.cos(aa) * 11, 88 + math.sin(aa) * 11 * 0.32 - (34 + 4 * k))
                if (math.sin(aa) > 0) == (part == "front"):
                    tips.append((tip, k))
            layer(fr, cv, LEAF, LEAF_LINE)
            for (x, y), k in tips:
                blit(fr, lf.rot(30 * (k - 1) + wig * 12), x, y - 3)
            dst.append(fr)
    piece("status_root_back", back, pivot=(48, 90), blend="mix", plane="billboard", fps=8, loop=True)
    piece("status_root_front", front, pivot=(48, 90), blend="mix", plane="billboard", fps=8, loop=True)
    return back, front


# ------------------------------------------------------------------ flecha do ataque basico com arco
def bow_arrow():
    """Flecha de taquara em voo (aponta para +x): penas tremendo e um risco de ar verde-oliva atras."""
    frames = []
    ar = arrow()
    for f in range(4):
        fr = Frame(80, 24)
        cv = Canvas(80, 24)
        cv.stroke([(4, 12), (30, 12)], [0.4, 2.6], [0.2, 0.42])
        cv.glow(1.6, 0.8, 0.1)
        fr.paint_canvas(cv, OLIVE_G)
        a = ar if f % 2 == 0 else ar.recolor({"#8cc860": "#a6d86a"})
        blit(fr, a, 76, 12 + (1 if f == 2 else 0) * 0, (1.0, 0.5))
        frames.append(fr)
    piece("bow_arrow", frames, pivot=(76, 12), blend="mix", plane="billboard", fps=16, loop=True)
    return frames


def bow_arrow_impact():
    """Impacto da flecha: lascas de taquara e poeirinha, pequeno clarao."""
    frames = []
    r = rng(1400)
    chips = [(r.uniform(D(150), D(250)), r.uniform(8, 16)) for _ in range(6)]
    for f in range(6):
        fr = Frame(64)
        cv = Canvas(64)
        v = 1.0 if f < 2 else 1 - (f - 1) * 0.22
        if f < 3:
            for k in range(6):
                cv.spike(32, 32, k * TAU / 6 + D(15), 2, [14, 20, 16][f], 3.2 - f, 0.7 * v)
            cv.circle(32, 32, [6, 4, 2][f], 1.0)
        cv.glow(2.0, 0.8, 0.14 * v)
        fr.paint_canvas(cv, SAP_G)
        for (a, sp) in chips:
            d = sp * (f + 1) * 0.55
            x, y = 32 + math.cos(a) * d, 32 + math.sin(a) * d + 0.8 * f * f
            fr.px(int(x), int(y), "#dcc07a")
            fr.px(int(x) + 1, int(y), "#a07c3e")
        dither_alpha(fr, 1.0 if f < 4 else 0.5)
        frames.append(fr)
    piece("bow_arrow_impact", frames, pivot=(32, 32), blend="mix", plane="billboard", fps=18)
    return frames


ALL = [heal_leaves, aura_atk, aura_def, aura_matk, aura_crit, aura_evade, aura_guard, aura_regen, aura_mana,
       aura_lifesteal, mark_def_down, mark_atk_down, mark_slow, mark_poison, mark_heal_down, mark_vuln,
       mark_debuff, taunt, root_vines, bow_arrow, bow_arrow_impact]
_ = (BLOOD, BLOOD_LINE, BRONZE, BRONZE_LINE, DUST, DUST_LINE, EMBER_G, K, LEAF_G, MATINTA_G, WOOD, WOOD_LINE,
     SAP_G, MANA_G)
