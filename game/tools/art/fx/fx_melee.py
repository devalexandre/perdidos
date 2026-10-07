"""Lamina da Terra do Sabia (30/09/2026): Amolar o Facao, Tronco de Aroeira e Garra da Onca.

Cada skill tem uma peca-chave propria: pedra de amolar no facao, escudo de casca de aroeira com cachos de
aroeira-vermelha, raizes rasgando o chao, casca grossa nas laterais do corpo, tronco que bate no chao,
onca-pintada saltando, tres unhadas, olhos de onca no escuro e a cabeca da onca rugindo."""
from __future__ import annotations

import math

import numpy as np

from fxdraw import Canvas, Frame, Spr, blit, ease_in, ease_out, layer, lerp, piece, rng
from fxsabia import (D, DUST, DUST_LINE, EMBER_G, JAG_EYES_PAL, JAG_EYES_TXT, JAGUAR_PAL, JAGUAR_TXT, LEAF,
                     LEAF_LINE, LEAFLET_PAL, LEAFLET_TXT, RAGE_G, SAP_G, STEEL, STEEL_LINE, TAU, W_GOLD, W_PALE,
                     W_WHITE, WHET_PAL, WHET_TXT, WOOD, WOOD_LINE, claw_marks, dither_alpha, glow_ramp, leaf_poly,
                     puff, solid_ramp, spr)

FEET = (64, 124)
GOLD_G = glow_ramp(["#3a2408", "#8a5414", "#d88c22", "#f4c252", "#fae8b8", "#ffffff"])
GOLD_GROUND = glow_ramp(["#3a2408", "#8a5414", "#d88c22", "#f4c252", "#fae8b8", "#ffffff"],
                        [36, 150, 255, 255, 255, 255])
BARK = solid_ramp(["#2e1c12", "#553624", "#7c5434", "#a47a50"])
BARK_LINE = "#140a06"
BERRY = solid_ramp(["#6e1010", "#b4201c", "#e8483a", "#ffb0a0"])


def machete_polys(cx, cy, ang, L):
    """Facao (lamina larga e curva na ponta) com o cabo em (cx, cy) apontando para ang. -> (lamina, cabo, fio)."""
    c, s = math.cos(ang), math.sin(ang)

    def P(u, o):
        return (cx + c * u - s * o, cy + s * u + c * o)
    hl = L * 0.26
    handle = [P(-hl, -2.2), P(0, -2.6), P(0, 2.6), P(-hl, 2.2)]
    blade = [P(0, -3.4), P(L * 0.7, -4.6), P(L * 0.93, -3.8), P(L, -1.0), P(L * 0.96, 3.0), P(L * 0.5, 4.6),
             P(0, 3.4)]
    edge = [P(L * 0.05, 3.0), P(L * 0.5, 4.0), P(L * 0.95, 2.4)]
    return blade, handle, edge


# ------------------------------------------------------------------ Amolar o Facao
def sharpen():
    """Facao em pe na frente do peito; a pedra de amolar corre o fio tres vezes soltando faiscas, e no fim um
    brilho corre a lamina toda."""
    frames = []
    whet = spr(WHET_TXT, WHET_PAL).scale(1)
    L = 58
    cx, cy, ang = 44, 104, D(-62)
    c, s = math.cos(ang), math.sin(ang)
    r = rng(1500)
    for f in range(12):
        fr = Frame(128)
        cv = Canvas(128)
        blade, handle, edge = machete_polys(cx, cy, ang, L)
        cv.poly(blade, 0.55)
        cv.stroke(edge, [1.6, 1.8, 1.2], [0.95] * 3)
        layer(fr, cv, STEEL, STEEL_LINE)
        hv = Canvas(128)
        hv.poly(handle, 0.6)
        layer(fr, hv, WOOD, WOOD_LINE)
        if f < 9:  # pedra: vai e volta tres vezes (0->1->0...)
            u = abs(((f / 3.0) % 2.0) - 1.0)
            u = 0.15 + 0.75 * (1 - u)
            px, py = cx + c * L * u + (-s) * 7, cy + s * L * u + c * 7
            blit(fr, whet.rot(-math.degrees(ang) - 90 + 90), px, py)
            ev = Canvas(128)
            for k in range(6):  # faiscas saindo do ponto de contato, para fora
                a = ang + D(90) + r.uniform(-0.7, 0.7)
                d0 = r.uniform(3, 8)
                d1 = d0 + r.uniform(8, 20)
                ev.stroke([(px + math.cos(a) * d0, py + math.sin(a) * d0),
                           (px + math.cos(a) * d1, py + math.sin(a) * d1 + 3)], [2.0, 0.4], [1.0, 0.5])
            ev.glow(1.6, 0.9, 0.2)
            layer(fr, ev, EMBER_G)
        else:  # brilho correndo o fio
            u = (f - 8) / 3.0
            gx, gy = cx + c * L * u, cy + s * L * u
            fr.twinkle(gx, gy, 4, W_WHITE, W_GOLD, W_PALE)
            fr.twinkle(cx + c * L * 0.98, cy + s * L * 0.98 - 1, 2 if f < 11 else 3, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("blade_sharpen_whet", frames, pivot=FEET, blend="mix", plane="billboard", fps=14)
    return frames


# ------------------------------------------------------------------ Tronco de Aroeira
def aroeira_reply():
    """Escudo de casca de aroeira na frente do corpo, com cachos de aroeira-vermelha e folhinhas: fica de
    guarda (1,5 s) com os frutos piscando, pronto para devolver o golpe."""
    frames = []
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        cx, cy = 64, 74 + round(math.sin(f / 8 * TAU) * 1.5)
        # tabua de casca alta e reta (escudo de pau), com a borda de cima lascada
        shape = [(cx - 18, cy - 28), (cx - 10, cy - 33), (cx - 2, cy - 30), (cx + 6, cy - 34), (cx + 18, cy - 29),
                 (cx + 19, cy + 26), (cx + 10, cy + 32), (cx - 10, cy + 32), (cx - 19, cy + 26)]
        cv.poly(shape, 0.5)
        for k in range(-3, 4):  # sulcos verticais da casca
            x = cx + k * 5.5
            pts = [(x + math.sin(i * 1.7 + k) * 1.2, cy - 28 + i * 7) for i in range(9)]
            cv.stroke(pts, [1.1] * 9, [0.25] * 9)
        cv.stroke([(cx - 18, cy - 24), (cx + 16, cy - 26)], [2.0, 2.0], [0.75, 0.75])
        cv.put((cv.Y > cy + 30).astype(np.float32), 1.0, "cut")
        layer(fr, cv, BARK, BARK_LINE)
        lv = Canvas(128)
        for (lx, ly, la) in ((cx + 18, cy - 24, D(-60)), (cx + 24, cy - 14, D(-5)), (cx - 18, cy + 20, D(160)),
                             (cx - 20, cy + 14, D(-160))):
            lv.poly(leaf_poly(lx, ly, la, 14, 6), 0.62)
        layer(fr, lv, LEAF, LEAF_LINE)
        bv = Canvas(128)
        for (bx, by) in ((cx + 17, cy - 22), (cx + 22, cy - 13), (cx - 18, cy + 18)):  # cachos nas bordas
            for k in range(6):
                a = k * TAU / 6
                bv.circle(bx + math.cos(a) * 3.2, by + math.sin(a) * 3.2, 2.0, 0.62)
            bv.circle(bx, by, 2.0, 0.85)
        layer(fr, bv, BERRY, "#3a0808")
        blink = [(cx + 17, cy - 24), (cx + 22, cy - 15), (cx - 18, cy + 16)][f % 3]
        fr.twinkle(blink[0], blink[1], 2, W_WHITE, "#ffb0a0")
        if f % 4 == 0:  # fio de "contragolpe" nas bordas
            for sx in (-1, 1):
                for i in range(5):
                    fr.px(cx + sx * (26 + i), cy - 6 - i * 2, "#ffb0a0" if i < 3 else "#e8483a")
        frames.append(fr)
    piece("blade_aroeira_reply_guard", frames, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return frames


def root_grip():
    """Deitada no chao: raizes grossas rasgam a terra do centro para fora, com torroes voando e rachaduras.
    Desenho para raio 2,5 (80 px)."""
    frames = []
    c = 96
    r = rng(1600)
    roots = []
    for k in range(9):
        a = k * TAU / 9 + r.uniform(-0.2, 0.2)
        pts, rr = [], 6.0
        while rr < 84:
            a += r.uniform(-0.3, 0.3)
            pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
            rr += r.uniform(7, 11)
        roots.append(pts)
    clods = [(r.uniform(0, TAU), r.uniform(20, 70), r.uniform(2.5, 4.5)) for _ in range(16)]
    for f in range(10):
        fr = Frame(192)
        g = ease_out(min(1.0, (f + 1) / 5.0))
        v = 1.0 if f < 7 else 1.0 - (f - 6) * 0.25
        sv = Canvas(192)
        for pts in roots:  # terra rasgada (sombra marrom embaixo das raizes)
            n = max(2, int(len(pts) * g))
            sv.stroke(pts[:n], [9 * (1 - i / 12) + 3 for i in range(n)], [0.5] * n)
        layer(fr, sv, solid_ramp(["#3a2a1a", "#5e4428", "#6e5232", "#86643c"], [90, 150, 180, 200]), None)
        cv = Canvas(192)
        for pts in roots:
            n = max(2, int(len(pts) * g))
            ws = [lerp(8.0, 2.0, i / max(len(pts) - 1, 1)) for i in range(n)]
            cv.stroke(pts[:n], ws, [0.55] * n)
            cv.stroke(pts[:n], [w * 0.35 for w in ws], [0.9] * n)
            if n >= 3:  # radicelas
                x, y = pts[n // 2]
                x2, y2 = pts[n // 2 + 1] if n // 2 + 1 < n else pts[-1]
                a = math.atan2(y2 - y, x2 - x) + 0.9
                cv.stroke([(x, y), (x + math.cos(a) * 10, y + math.sin(a) * 10)], [2.4, 0.6], [0.6, 0.6])
        layer(fr, cv, WOOD, WOOD_LINE)
        if f <= 6:
            dv = Canvas(192)
            for (a, d, sz) in clods:  # torroes voando para fora
                dd = d * (0.4 + 0.12 * f)
                dv.circle(c + math.cos(a) * dd, c + math.sin(a) * dd, sz, 0.6)
            layer(fr, dv, DUST, DUST_LINE)
        dither_alpha(fr, v)
        frames.append(fr)
    piece("blade_root_grip_roots", frames, pivot=(96, 96), blend="mix", plane="flat", fps=14, texel=2.5 / 80.0)
    return frames


def thick_bark():
    """Casca Grossa: placas de casca de arvore crescendo nas LATERAIS e atras do corpo (o rosto fica livre),
    com musgo; em laco pela duracao. _back atras, _front nas laterais da frente."""
    front, back = [], []
    for f in range(8):
        breath = math.sin(f / 8 * TAU)
        for part, dst in (("back", back), ("front", front)):
            fr = Frame(128)
            cv = Canvas(128)
            if part == "back":
                slabs = [(-30, 0), (-18, -4), (-6, -6), (6, -6), (18, -4), (30, 0)]
            else:
                slabs = [(-34, 6), (-26, 10), (26, 10), (34, 6)]
            for (dx, dy) in slabs:
                x = 64 + dx * (1 + 0.03 * breath)
                top = 44 + dy + (abs(dx) > 28) * 10
                w = 11
                pts = [(x - w / 2, 120), (x - w / 2 + 1, top + 6), (x, top), (x + w / 2 - 1, top + 5), (x + w / 2, 120)]
                cv.poly(pts, 0.5 if part == "front" else 0.4)
                for i in range(3):
                    gx = x - 3 + i * 3
                    cv.stroke([(gx, top + 6), (gx + 1, 118)], [0.9, 0.9], [0.22, 0.22])
                cv.stroke([(x - w / 2 + 1, top + 6), (x - w / 2 + 1, 116)], [1.4, 1.4], [0.75, 0.75])
            layer(fr, cv, BARK, BARK_LINE)
            mv = Canvas(128)
            for (dx, dy) in slabs[::2]:
                mv.ellipse(64 + dx, 44 + dy + (abs(dx) > 28) * 10 + 8, 4, 2.4, 0.6)
            layer(fr, mv, LEAF, LEAF_LINE)
            if part == "front" and f in (2, 6):
                fr.twinkle(64 - 30, 58, 2, W_WHITE, W_GOLD)
            dst.append(fr)
    piece("blade_thick_bark_back", back, pivot=FEET, blend="mix", plane="billboard", fps=6, loop=True)
    piece("blade_thick_bark_front", front, pivot=FEET, blend="mix", plane="billboard", fps=6, loop=True)
    return back, front


def trunk_call():
    """Chamado do Tronco: um tronco de aroeira sobe do chao atras do conjurador e BATE no chao (3 batidas),
    soltando folhas e poeira. Em pe, uma vez."""
    frames = []
    lf = spr(LEAFLET_TXT, LEAFLET_PAL, LEAF_LINE)
    r = rng(1700)
    leaves = [(r.uniform(-1, 1), r.uniform(0.5, 1.2), r.uniform(0, 360)) for _ in range(10)]
    ys = [80, 50, 30, 30, 60, 30, 60, 34, 64, 64, 64, 64]
    for f in range(12):
        fr = Frame(128)
        top = ys[f]
        hit = f in (4, 6, 8)
        cv = Canvas(128)
        cv.poly([(50, 124), (48, top + 10), (54, top), (74, top), (80, top + 10), (78, 124)], 0.5)
        for k in range(5):
            x = 52 + k * 6
            cv.stroke([(x, top + 6), (x + math.sin(k) * 2, 122)], [1.0, 1.0], [0.22, 0.22])
        cv.ellipse(64, top + 3, 12, 3, 0.8)
        cv.ellipse(64, top + 3, 7, 1.6, 0.3)
        layer(fr, cv, BARK, BARK_LINE)
        if hit or f in (5, 7, 9):
            k = 1.0 if hit else 0.6
            dv = Canvas(128)
            for i in range(4):
                puff(dv, 64 + (i - 1.5) * 17 * k, 118 - abs(i - 1.5) * 3, 10 * k)
            dv.noise_erode(0.0 if hit else 0.35, seed=1710 + f, scale=3)
            layer(fr, dv, DUST, DUST_LINE)
        if f >= 4:
            t = (f - 4) / 7
            for (sx, sp, rot) in leaves:
                x = 64 + sx * 50 * t
                y = 110 - sp * 70 * t + 60 * t * t
                blit(fr, lf.rot(rot + f * 30), x, y, alpha=1.0 if t < 0.7 else 0.5)
        if hit:
            for sx in (-1, 1):
                for i in range(4):
                    fr.px(64 + sx * (24 + i * 3), 112 - i * 3, "#fae8b8")
                    fr.px(64 + sx * (24 + i * 3), 108 - i * 3, "#fae8b8")
        frames.append(fr)
    piece("blade_trunk_call_trunk", frames, pivot=(64, 124), blend="mix", plane="billboard", fps=12)
    return frames


# ------------------------------------------------------------------ Garra da Onca
def jaguar_leap():
    """Bote da Onca: onca-pintada de luz dourada saltando (voa ate o alvo; o SkillFx gira na direcao)."""
    frames = []
    jag = spr(JAGUAR_TXT, JAGUAR_PAL, "#1a0e06")
    for f in range(6):
        fr = Frame(112, 56)
        cv = Canvas(112, 56)
        for k in range(3):  # rastro de luz atras, em faixas
            y = 26 + (k - 1) * 8
            cv.stroke([(4 + k * 6, y), (60, y)], [0.4, 5.0 - k], [0.2, 0.5])
        cv.glow(2.4, 0.8, 0.16)
        fr.paint_canvas(cv, GOLD_G)
        stretch = [1.0, 1.08, 1.12, 1.08, 1.0, 0.96][f]
        j = jag.squash(stretch, 1.0 / stretch ** 0.5)
        blit(fr, j, 104, 28 + [0, -1, -2, -1, 0, 1][f], (1.0, 0.5))
        if f % 2 == 0:
            fr.twinkle(100, 16, 2, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("blade_jaguar_leap_spirit", frames, pivot=(96, 28), blend="mix", plane="billboard", fps=14, loop=True)
    return frames


def claw_impact():
    """Tres rasgos de garra dourados cruzando o alvo na diagonal, com lascas — impacto do Bote."""
    frames = []
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        v = 1.0 if f < 4 else 1.0 - (f - 3) * 0.2
        g = ease_out(min(1.0, (f + 1) / 3.0))
        claw_marks(cv, 64, 64, D(-55), 80 * g, 12, 3, 4.2 * v, 0.6 * v, curve=0.07)
        claw_marks(cv, 64, 64, D(-55), 74 * g, 12, 3, 1.6 * v, 1.0 * v, curve=0.07)
        cv.glow(2.4, 0.9, 0.16 * v)
        fr.paint_canvas(cv, GOLD_G)
        if 1 <= f <= 5:
            r = rng(1800 + f)
            for k in range(7):
                a = D(35) + r.uniform(-0.6, 0.6)
                d = 20 + f * 7 + r.uniform(-4, 4)
                fr.twinkle(64 + math.cos(a) * d * (1 if k % 2 else -1), 64 + math.sin(a) * d * (1 if k % 2 else -1),
                           2 if f < 4 else 1, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("blade_jaguar_leap_impact", frames, pivot=(64, 64), blend="add", plane="billboard", fps=18)
    return frames


def claw_rake():
    """Unhada: tres unhadas seguidas (esquerda, direita, de cima), cada uma com 3 riscos que ficam vermelhos."""
    frames = []
    swipes = [(0, D(-35), -6), (4, D(-145), 6), (8, D(-90), 0)]
    for f in range(14):
        fr = Frame(128)
        cv = Canvas(128)
        rv = Canvas(128)
        for (start, ang, ox) in swipes:
            t = f - start
            if t < 0:
                continue
            g = ease_out(min(1.0, (t + 1) / 2.0))
            v = 1.0 if t < 3 else max(0.0, 1.0 - (t - 2) * 0.22)
            if v <= 0:
                continue
            claw_marks(cv, 64 + ox, 64, ang, 66 * g, 10, 3, 3.6 * v, 0.55 * v, curve=0.1)
            claw_marks(cv, 64 + ox, 64, ang, 60 * g, 10, 3, 1.4 * v, 1.0 * v, curve=0.1)
            if t >= 2:
                claw_marks(rv, 64 + ox, 64, ang, 52, 10, 3, 2.0 * v, 0.7 * v, curve=0.1)
        cv.glow(2.2, 0.9, 0.16)
        layer(fr, rv, RAGE_G)
        layer(fr, cv, GOLD_G)
        for (start, ang, ox) in swipes:
            if f == start + 1:
                fr.twinkle(64 + ox + math.cos(ang) * 32, 64 + math.sin(ang) * 32, 3, W_WHITE, W_GOLD, W_PALE)
        frames.append(fr)
    piece("blade_claw_rake_claws", frames, pivot=(64, 64), blend="add", plane="billboard", fps=20)
    return frames


def blood_scent():
    """Faro de Sangue: olhos de onca acesos atras da cabeca e fiapos vermelhos de cheiro correndo para o
    focinho. Em laco (8 s); os olhos piscam."""
    frames = []
    eyes = spr(JAG_EYES_TXT, JAG_EYES_PAL, "#1a0806").scale(2)
    closed = Spr(eyes.a.copy())
    closed.a[:, :, 3][:] = 0
    closed.a[6:10] = eyes.a[6:10]
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        for k in range(4):
            u = (f / 8 + k / 4) % 1.0
            side = -1 if k % 2 else 1
            x0 = 64 + side * (44 - 30 * u)
            y0 = 60 + math.sin(u * 5 + k) * 6
            pts = [(x0 + side * i * 4, y0 + math.sin(u * 6 + i) * 2) for i in range(6)]
            cv.stroke(pts, [1.6, 1.4, 1.2, 0.9, 0.6, 0.3], [0.7 * (1 - u) + 0.2] * 6)
        cv.glow(2.4, 0.8, 0.14)
        fr.paint_canvas(cv, RAGE_G)
        blit(fr, closed if f == 5 else eyes, 64, 22)
        frames.append(fr)
    piece("blade_blood_scent_eyes", frames, pivot=FEET, blend="mix", plane="billboard", fps=8, loop=True)
    return frames


JAG_HEAD_TXT = """
.oo..................oo.
oyyo................oyyo
oywyooooooooooooooooywyo
.oyyyyyyykyyyyyykyyyyyo.
.oyykyyyyyyyyyyyyyykyyo.
oyyyyyGGyyyyyyyyGGyyyyyo
oyykyGkGyyyyyyyyGkGykyyo
oyyyyyyyyyykkyyyyyyyyyyo
.oyyyyyyyykkkkyyyyyyyyo.
.oyyyywwwwwwwwwwwwyyyyo.
..oyywrrrrrrrrrrrrwyyo..
..oyywTrrrrrrrrrrTwyyo..
...oywTrrrrrrrrrrTwyo...
...oywrrrrrrrrrrrrwyo...
....owTrrrrrrrrrrTwo....
.....owwTwwwwwwTwwo.....
......oowwwwwwwwoo......
........oooooooo........
"""
JAG_HEAD_PAL = {"o": "#3a2412", "y": "#e8a83a", "w": "#fae8b8", "k": "#3a2412", "G": "#d8e050",
                "r": "#5a0c0c", "T": "#ffffff"}


def jaguar_roar():
    """Rugido da Onca: cabeca da onca de luz rugindo acima do conjurador (em pe, uma vez)."""
    frames = []
    head = spr(JAG_HEAD_TXT, JAG_HEAD_PAL, "#1a0e06")
    for f in range(10):
        fr = Frame(128)
        k = [1, 1, 2, 2, 2, 2, 2, 2, 2, 2][f]
        cv = Canvas(128)
        if 1 <= f <= 7:
            for i in range(3):  # tres frentes de som em ziguezague, saindo da boca
                rr = 14 + ((f - 1) * 6 + i * 9) % 30
                pts = []
                for j in range(9):
                    a = D(40) + j * D(100) / 8
                    z = rr + (2 if j % 2 else -2)
                    pts.append((64 + math.cos(a) * z * 1.6, 60 + math.sin(a) * z * 0.9))
                cv.stroke(pts, [1.8] * 9, [0.7 - i * 0.15] * 9)
        cv.glow(2.0, 0.8, 0.14)
        fr.paint_canvas(cv, GOLD_G)
        blit(fr, head.scale(k), 64, 40, alpha=1.0 if f < 8 else 0.5)
        frames.append(fr)
    piece("blade_jaguar_roar_head", frames, pivot=(64, 124), blend="mix", plane="billboard", fps=12)
    return frames


def cone_frames(name, ramp, draw, n=8, fps=16, radius_px=150, R_design=3.0, spread=D(90), size=192,
                blend="add"):
    """Cone deitado no chao (vertice embaixo, abre para cima = frente). draw(cv, fr, f, ox, oy, R, a0, a1)."""
    frames = []
    ox, oy = size // 2, size - 8
    a0, a1 = D(-90) - spread / 2, D(-90) + spread / 2
    for f in range(n):
        cv = Canvas(size)
        fr = Frame(size)
        draw(cv, fr, f, ox, oy, radius_px, a0, a1)
        frames.append(fr)
    piece(name, frames, pivot=(ox, oy), blend=blend, plane="flat", fps=fps, texel=R_design / radius_px)
    return frames


def jaguar_roar_cone():
    """Rugido no chao: frentes de som denteadas (como dentes) correndo pelo cone de 90 graus + poeira."""
    def draw(cv, fr, f, ox, oy, R, a0, a1):
        v = 1.0 if f < 5 else 1.0 - (f - 4) * 0.25
        dx, dy = cv.X - ox, cv.Y - oy
        d = np.sqrt(dx * dx + dy * dy)
        a = np.arctan2(dy, dx)
        inside = (a >= a0) & (a <= a1)
        for i in range(3):
            rr = R * min(1.0, ease_out((f + 1) / 6.0) - i * 0.18)
            if rr <= 10:
                continue
            teeth = rr + 5 * np.abs(((a - a0) / (a1 - a0) * 9) % 1.0 - 0.5) * 2
            m = inside & (np.abs(d - teeth) < 3.0 - i * 0.6)
            cv.put(m.astype(np.float32), (0.85 - i * 0.2) * v)
        cv.put((inside & (d < R * ease_out((f + 1) / 6.0))).astype(np.float32), 0.06 * v)
        cv.glow(2.4, 0.9, 0.12 * v)
        fr.paint_canvas(cv, GOLD_GROUND)
    return cone_frames("blade_jaguar_roar_cone", GOLD_GROUND, draw, radius_px=150, R_design=3.0)


ALL = [sharpen, aroeira_reply, root_grip, thick_bark, trunk_call, jaguar_leap, claw_impact, claw_rake,
       blood_scent, jaguar_roar, jaguar_roar_cone]
_ = (ease_in, SAP_G, DUST)
