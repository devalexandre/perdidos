"""Tanque da Terra de Pindorama (30/09/2026) — o Velho Tiao do Casco: Casco de Jabuti, Couro de Anta e Furia do
Mapinguari.

Pecas-chave: casco de jabuti batido (toc-toc), cupula de casco fechando, carapaca nas costas, jabutizinho
andando devagar entre brotos, empurrao em leque de placas; couro de anta costurado nos ombros, pegada de anta
afundando o chao, anta de luz investindo, estacas de pau-a-pique subindo, pedras que prendem os pes;
Mapinguari: fumaca vermelha de furia com pelos, a boca da barriga urrando, garras rasgando o chao, gotas de
sangue voltando e o punho de garras esmagando."""
from __future__ import annotations

import math

import numpy as np

from fxdraw import Canvas, Frame, Spr, blit, ease_in, ease_out, layer, lerp, piece, rng
from fxpindorama import (BLOOD, BLOOD_LINE, BRONZE, BRONZE_G, BRONZE_GROUND, BRONZE_LINE, CLAW_HAND_PAL, CLAW_HAND_TXT,
                     D, DUST, DUST_LINE, HIDE, HIDE_LINE, LEAF, LEAF_LINE, LEAFLET_PAL, LEAFLET_TXT, MOUTH_PAL,
                     MOUTH_TXT, MUD, MUD_LINE, RAGE_G, RAGE_GROUND, SHELL, SHELL_LINE, SHELL_PAL, SHELL_TXT, TAPIR_PAL,
                     TAPIR_TXT, TAU, W_GOLD, W_PALE, W_WHITE, WOOD, WOOD_LINE, claw_marks, dither_alpha, drop,
                     puff, solid_ramp, spr)
from fx_melee import cone_frames

FEET = (64, 124)
SHELL_T = solid_ramp(["#3a2a12", "#6a4e22", "#9c7a3a", "#d0aa5c"], [190, 200, 210, 220])
STONE = solid_ramp(["#3a3440", "#5a5462", "#8e8a98", "#c8c4d0"])


def _scutes(cv, cx, cy, rx, ry, v, seam=None, rows=3, areola=None):
    """Carapaca (domo visto de tras) com placas hexagonais de jabuti: corpo em 'cv', costuras entre as placas em
    'seam' e o miolo claro de cada placa (areola) em 'areola'."""
    cv.ellipse(cx, cy, rx, ry, v)
    cv.put((cv.Y > cy).astype(np.float32), 1.0, "cut")
    if seam is None:
        return
    s = rx / 3.2
    h = s * math.sqrt(3)
    for col in range(-4, 5):
        for row in range(-1, 5):
            hx = cx + col * s * 1.5
            hy = cy - 4 - row * h - (h / 2 if col % 2 else 0)
            # dentro do domo?
            if ((hx - cx) / rx) ** 2 + ((hy - cy) / ry) ** 2 > 0.92 or hy > cy - 2:
                continue
            pts = [(hx + math.cos(a) * s, hy + math.sin(a) * s * 0.9) for a in [k * math.pi / 3 for k in range(7)]]
            seam.stroke(pts, [1.6] * 7, [0.9] * 7)
            if areola is not None:
                areola.ellipse(hx, hy, s * 0.42, s * 0.36, 0.8)


# ------------------------------------------------------------------ Casco de Jabuti
def shell_knock():
    """Batida no Casco: o casco de jabuti aparece acima da cabeca e leva duas batidas (desce, estala com
    tracos de impacto) — o barulho chama os monstros."""
    frames = []
    sh = spr(SHELL_TXT, SHELL_PAL, "#120c04").scale(2)
    ys = [30, 24, 20, 28, 20, 20, 28, 22, 22, 22]
    for f in range(10):
        fr = Frame(128)
        y = ys[f]
        hit = f in (3, 6)
        s_ = sh.squash(1.08, 0.88) if hit else sh
        blit(fr, s_, 64, y, (0.5, 0.5), alpha=1.0 if f < 8 else 0.5)
        if hit or f in (4, 7):
            ln = 14 if hit else 9
            for a in (D(200), D(230), D(310), D(340), D(160), D(20)):
                x0, y0 = 64 + math.cos(a) * 34, y + math.sin(a) * 18
                for i in range(ln // 2):
                    fr.px(int(x0 + math.cos(a) * i * 2), int(y0 + math.sin(a) * i * 2), "#fae58c" if i < 3 else "#e6b43a")
        frames.append(fr)
    piece("tank_shell_knock_shell", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def shell_retreat():
    """Recolher no Casco: uma cupula de casco de jabuti (meio transparente) desce e cobre o corpo; as placas
    brilham de leve. Em laco (4 s)."""
    frames = []
    for f in range(8):
        fr = Frame(128)
        g = min(1.0, ease_out((f + 1) / 3.0))
        cv, sv, av = Canvas(128), Canvas(128), Canvas(128)
        _scutes(cv, 64, 121, 48, (84 * g) + 6, 0.55, sv, areola=av)
        layer(fr, cv, SHELL_T, None)
        pul = 0.5 + 0.5 * math.sin(f / 8 * TAU)
        av.f *= 0.7 + 0.3 * pul
        layer(fr, av, solid_ramp(["#6a4e22", "#9c7a3a", "#d0aa5c", "#f0d090"], [200, 210, 220, 230]), None)
        sv.put((cv.f > 0).astype(np.float32), 1.0, "mul")
        layer(fr, sv, solid_ramp(["#1a1206", "#2a1c0a", "#3a2a12", "#4a3418"]), None)
        rim = Canvas(128)
        rim.stroke([(18, 120), (110, 120)], [6, 6], [0.62, 0.62])
        layer(fr, rim, SHELL, SHELL_LINE)
        frames.append(fr)
    piece("tank_shell_retreat_dome", frames, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return frames


def hard_shell():
    """Casco Duro: carapaca grande de jabuti nas COSTAS do tanque (atras do corpo), com costuras de bronze
    pulsando. Em laco (12 s)."""
    frames = []
    for f in range(8):
        fr = Frame(128)
        cv, sv, av = Canvas(128), Canvas(128), Canvas(128)
        _scutes(cv, 64, 112, 44, 72, 0.55, sv, areola=av)
        layer(fr, cv, SHELL, SHELL_LINE)
        pul = 0.5 + 0.5 * math.sin(f / 8 * TAU)
        layer(fr, av, solid_ramp(["#6a4e22", "#9c7a3a", "#d0aa5c", "#f0d090"]), None)
        sv.put((cv.f > 0).astype(np.float32), 1.0, "mul")
        sv.f *= 0.55 + 0.45 * pul
        layer(fr, sv, BRONZE_G)
        if f in (1, 5):
            fr.twinkle(44 + f * 4, 60, 2, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("tank_hard_shell_back", frames, pivot=FEET, blend="mix", plane="billboard", fps=8, loop=True)
    return frames


JABUTI_TXT = """
.....ssssss.......
...ssPlPPlPss.....
..sPPlPPPPlPPs....
.sPPPPsPPsPPPPs.hh
ssssssssssssssssHkh
.BBBBBBBBBBBBBBsHHh
..hh.hh....hh.hhhh.
..hh.hh....hh.hh...
"""


def patience():
    """Paciencia de Jabuti: um jabutizinho anda devagar em volta dos pes enquanto brotos e florzinhas nascem
    e bolhas de vida sobem. Em laco (8 s)."""
    frames = []
    jb = spr(JABUTI_TXT, {"s": "#2a1c0a", "P": "#9c7a3a", "l": "#e0bc6a", "B": "#c8a050", "h": "#8a8a5a",
                          "H": "#6a6a3a", "k": "#1a1418"}, "#120c04").scale(2)
    lf = spr(LEAFLET_TXT, LEAFLET_PAL, LEAF_LINE)
    for f in range(8):
        fr = Frame(128)
        a = f / 8 * TAU
        x = 64 + math.cos(a) * 34
        y = 118 + math.sin(a) * 6
        depth = math.sin(a)
        sprouts = [(-30, 0), (-12, 3), (14, 2), (30, -1), (0, -3)]
        for k, (dx, dy) in enumerate(sprouts):  # brotos crescendo devagar e florzinhas
            h = 4 + ((f + k * 2) % 8) * 0.8
            for i in range(int(h)):
                fr.px(64 + dx, 121 + dy - i, "#5aa048" if i < h - 2 else "#a6d86a")
            if k % 2 == 0:
                blit(fr, lf.rot(30), 64 + dx + 3, 121 + dy - h)
            else:
                fr.px(64 + dx, int(121 + dy - h - 1), "#f4f0dc")
                fr.px(64 + dx - 1, int(121 + dy - h), "#f4f0dc")
                fr.px(64 + dx + 1, int(121 + dy - h), "#f4f0dc")
                fr.px(64 + dx, int(121 + dy - h), "#fae58c")
        j = jb if math.cos(a + math.pi / 2) > 0 else jb.flip()
        blit(fr, j, x, y, (0.5, 1.0), alpha=1.0 if depth > -0.2 else 0.75)
        for k in range(4):  # bolhas de vida subindo
            u = (f / 8 + k / 4) % 1.0
            cx, cy = 64 + (k - 1.5) * 16 + math.sin(u * 6) * 2, 110 - u * 80
            fr.px(int(cx), int(cy), "#e0f8b0")
            fr.px(int(cx) + 1, int(cy), "#a6d86a")
            fr.px(int(cx), int(cy) + 1, "#a6d86a")
        frames.append(fr)
    piece("tank_patience_jabuti", frames, pivot=FEET, blend="mix", plane="billboard", fps=6, loop=True)
    return frames


def shell_bash_cone():
    """Empurrao de Casco (cone 90 graus, 2 cel = 110 px): frente de placas de casco empurrando o chao, com
    poeira levantando na borda."""
    r = rng(6100)

    def draw(cv, fr, f, ox, oy, R, a0, a1):
        v = 1.0 if f < 5 else 1.0 - (f - 4) * 0.28
        rr = R * ease_out(min(1.0, (f + 1) / 4.0))
        n = 7
        sv = Canvas(cv.w)
        for k in range(n):  # placas hexagonais na frente da onda
            a = lerp(a0, a1, (k + 0.5) / n)
            x, y = ox + math.cos(a) * rr, oy + math.sin(a) * rr
            s = 11
            pts = [(x + math.cos(a + D(60) * i) * s, y + math.sin(a + D(60) * i) * s) for i in range(6)]
            sv.poly(pts, 0.55)
            sv.poly([(x + math.cos(a + D(60) * i) * s * 0.5, y + math.sin(a + D(60) * i) * s * 0.5) for i in range(6)],
                    0.85)
        dx, dy = cv.X - ox, cv.Y - oy
        d = np.sqrt(dx * dx + dy * dy)
        ang = np.arctan2(dy, dx)
        inside = (ang >= a0) & (ang <= a1)
        cv.put((inside & (d < rr) & (d > rr - 30)).astype(np.float32) * np.clip((d - rr + 30) / 30, 0, 1), 0.4 * v)
        cv.glow(2.0, 0.8, 0.1 * v)
        fr.paint_canvas(cv, BRONZE_GROUND)
        layer(fr, sv, SHELL, SHELL_LINE)
        if f >= 2:
            dv = Canvas(cv.w)
            for k in range(5):
                a = lerp(a0, a1, (k + 0.5) / 5) + r.uniform(-0.05, 0.05)
                puff(dv, ox + math.cos(a) * (rr + 10), oy + math.sin(a) * (rr + 10), 7)
            dv.noise_erode(0.1 + 0.15 * (f - 2), seed=6110 + f)
            layer(fr, dv, DUST, DUST_LINE)
        dither_alpha(fr, v if v < 1 else 1.0)
    return cone_frames("tank_shell_bash_cone", BRONZE_GROUND, draw, n=8, fps=16, radius_px=110, R_design=2.0,
                       blend="mix")


# ------------------------------------------------------------------ Couro de Anta
def thick_hide():
    """Couro Grosso: manto de couro de anta costurado cai sobre os ombros e as costas (_back) e duas abas nas
    laterais da frente (_front), com pontos de costura. Em laco (15 s)."""
    back, front = [], []
    for f in range(8):
        sway = math.sin(f / 8 * TAU) * 1.5
        for part, dst in (("back", back), ("front", front)):
            fr = Frame(128)
            cv = Canvas(128)
            st = []
            if part == "back":
                pts = [(30 + sway, 112), (34, 60), (48, 44), (80, 44), (94, 60), (98 + sway, 112), (80, 106),
                       (64, 114), (48, 106)]
                cv.poly(pts, 0.5)
                st = [((48, 50), (48, 104)), ((80, 50), (80, 104))]
            else:
                for sd in (-1, 1):
                    pts = [(64 + sd * 24, 58), (64 + sd * 36, 64), (64 + sd * (38 + sway * sd), 100),
                           (64 + sd * 28, 104), (64 + sd * 22, 80)]
                    cv.poly(pts, 0.55)
                    st.append(((64 + sd * 30, 64), (64 + sd * 32, 98)))
            cv.noise_erode(0.0, seed=1)
            layer(fr, cv, HIDE, HIDE_LINE)
            for (a, b) in st:  # costura em tracinhos
                n = int(abs(b[1] - a[1]) / 4)
                for i in range(n):
                    u = i / max(n - 1, 1)
                    x, y = lerp(a[0], b[0], u), lerp(a[1], b[1], u)
                    fr.px(int(x) - 1, int(y), "#c9b08a")
                    fr.px(int(x) + 1, int(y) + 1, "#c9b08a")
            dst.append(fr)
    piece("tank_thick_hide_back", back, pivot=FEET, blend="mix", plane="billboard", fps=6, loop=True)
    piece("tank_thick_hide_front", front, pivot=FEET, blend="mix", plane="billboard", fps=6, loop=True)
    return back, front


def tapir_print():
    """Pisada de Anta (deitada, raio 2,5 = 80 px): pegada enorme de anta (tres dedos e a sola) afunda o chao,
    com a borda de barro levantada, tracinhos de rachadura soltos e poeira."""
    frames = []
    c = 96
    r = rng(6200)
    cracks = []
    for k in range(9):
        a = k * TAU / 9 + r.uniform(-0.2, 0.2)
        d0 = r.uniform(52, 62)
        pts = [(c + math.cos(a) * d0, c + math.sin(a) * d0)]
        for i in range(3):
            a2 = a + r.uniform(-0.35, 0.35)
            d0 += r.uniform(5, 8)
            pts.append((c + math.cos(a2) * d0, c + math.sin(a2) * d0))
        cracks.append(pts)
    toes = ((-26, -30, 13, 16), (0, -44, 14, 17), (26, -30, 13, 16))
    for f in range(10):
        fr = Frame(192)
        v = 1.0 if f < 7 else 1 - (f - 6) * 0.25
        g = ease_out(min(1, (f + 1) / 3))
        rim = Canvas(192)  # barro levantado em volta (claro)
        rim.ellipse(c, c + 14, 34 * g + 4, 30 * g + 4, 0.8)
        for (dx, dy, sx, sy) in toes:
            rim.ellipse(c + dx * g, c + dy * g, sx * g + 4, sy * g + 4, 0.8)
        layer(fr, rim, MUD, MUD_LINE)
        pv = Canvas(192)  # fundo da pegada (escuro)
        pv.ellipse(c, c + 14, 34 * g, 30 * g, 0.3)
        for (dx, dy, sx, sy) in toes:
            pv.ellipse(c + dx * g, c + dy * g, sx * g, sy * g, 0.3)
        pv.ellipse(c - 6, c + 8, 16 * g, 12 * g, 0.12)
        layer(fr, pv, solid_ramp(["#1e140a", "#2e2012", "#3a2a1a", "#4a3622"]), None)
        cv = Canvas(192)
        for pts in cracks:
            n = max(2, int(len(pts) * g))
            cv.stroke(pts[:n], [2.0] * n, [0.5] * n)
        layer(fr, cv, solid_ramp(["#2a1e12", "#3a2a1a", "#5e4428", "#86643c"]), None)
        if f < 6:
            dv = Canvas(192)
            for k in range(8):
                a = k * TAU / 8 + 0.2
                d = 58 + f * 7
                puff(dv, c + math.cos(a) * d, c + 10 + math.sin(a) * d, 10 - f)
            dv.noise_erode(0.15 + f * 0.12, seed=6210 + f)
            layer(fr, dv, DUST, DUST_LINE)
        dither_alpha(fr, v)
        frames.append(fr)
    piece("tank_tapir_stomp_print", frames, pivot=(96, 96), blend="mix", plane="flat", fps=12, texel=2.5 / 80.0)
    return frames


def tapir_ram():
    """Trombada: anta de luz de bronze investindo junto do tanque (segue o corpo no avanco)."""
    frames = []
    tp = spr(TAPIR_TXT, TAPIR_PAL, "#0e0a0a").scale(2)
    tp = tp.recolor({"#6e6068": "#b07a2e", "#3a3036": "#6a4214", "#1e1818": "#3a2410"})
    for f in range(4):
        fr = Frame(128, 80)
        cv = Canvas(128, 80)
        for k in range(4):
            y = 20 + k * 12
            cv.stroke([(2 + k * 4, y), (40, y)], [0.4, 3.0], [0.2, 0.45])
        cv.glow(1.8, 0.8, 0.1)
        fr.paint_canvas(cv, BRONZE_G)
        blit(fr, tp, 120, 76 - (1 if f % 2 else 0), (1.0, 1.0))
        frames.append(fr)
    piece("tank_tapir_ram_spirit", frames, pivot=(80, 78), blend="mix", plane="billboard", fps=12, loop=True)
    return frames


def tapir_impact():
    """Impacto da Trombada: pancada pesada — tracos de choque de bronze e poeira grossa espirrando."""
    frames = []
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        v = 1.0 if f < 3 else 1 - (f - 2) * 0.18
        g = ease_out(min(1, (f + 1) / 3))
        for k in range(8):
            a = k * TAU / 8 + 0.2
            cv.stroke([(64 + math.cos(a) * (10 + 16 * g), 64 + math.sin(a) * (10 + 16 * g)),
                       (64 + math.cos(a) * (20 + 34 * g), 64 + math.sin(a) * (20 + 34 * g))], [4 * v, 1], [0.9 * v] * 2)
        if f < 2:
            cv.circle(64, 64, 12, 1.0)
        cv.glow(2.0, 0.9, 0.16 * v)
        fr.paint_canvas(cv, BRONZE_G)
        if f < 6:
            dv = Canvas(128)
            for k in range(6):
                a = D(180) + k * D(36)
                d = 20 + f * 7
                puff(dv, 64 + math.cos(a) * d, 100 + math.sin(a) * d * 0.3, 10 - f)
            dv.noise_erode(f * 0.12, seed=6300 + f)
            layer(fr, dv, DUST, DUST_LINE)
        frames.append(fr)
    piece("tank_tapir_ram_impact", frames, pivot=(64, 64), blend="mix", plane="billboard", fps=16)
    return frames


def living_wall_stake():
    """Muralha Viva: pedaco de pau-a-pique (tres estacas amarradas com tira de couro) brotando da terra com
    um monte de barro. Varios em volta do tanque. Em laco (8 s)."""
    frames = []
    grow = [0.2, 0.6, 1.05, 1.0, 1.0, 1.0, 1.0, 1.0]
    for f in range(8):
        fr = Frame(96)
        g = grow[f]
        cv = Canvas(96)
        for (dx, h) in ((-12, 50), (0, 60), (12, 46)):
            top = 90 - h * g
            cv.poly([(48 + dx - 5, 90), (48 + dx - 5, top + 6), (48 + dx, top), (48 + dx + 5, top + 6), (48 + dx + 5, 90)],
                    0.55)
            cv.stroke([(48 + dx - 2, top + 8), (48 + dx - 2, 88)], [1.2, 1.2], [0.8, 0.8])
        layer(fr, cv, WOOD, WOOD_LINE)
        bv = Canvas(96)
        yb = 90 - 26 * g
        bv.stroke([(28, yb), (68, yb - 3)], [4, 4], [0.6, 0.6])
        layer(fr, bv, HIDE, HIDE_LINE)
        mv = Canvas(96)
        mv.ellipse(48, 90, 26, 7, 0.55)
        mv.ellipse(44, 88, 14, 3, 0.8)
        layer(fr, mv, MUD, MUD_LINE)
        frames.append(fr)
    piece("tank_living_wall_stake", frames, pivot=(48, 90), blend="mix", plane="billboard", fps=12, loop=True)
    return frames


def stand_firm():
    """Aguentar Firme: pedras brotam em volta dos pes e travam o tanque no chao; aros de bronze nas pedras
    brilham. Em laco (6 s)."""
    frames = []
    stones = [(-34, 14, 0), (-18, 18, 1), (18, 17, 2), (34, 14, 3), (-4, 10, 4), (8, 11, 5)]
    for f in range(8):
        fr = Frame(128)
        g = min(1.0, (f + 1) / 3)
        cv = Canvas(128)
        for (dx, s, k) in stones:
            h = s * 1.8 * g
            x = 64 + dx
            cv.poly([(x - s, 122), (x - s * 0.8, 122 - h * 0.7), (x - s * 0.2, 122 - h), (x + s * 0.6, 122 - h * 0.8),
                     (x + s, 122)], 0.55)
            cv.poly([(x - s * 0.8, 122 - h * 0.7), (x - s * 0.2, 122 - h), (x, 122 - h * 0.5)], 0.85)
        layer(fr, cv, STONE, "#1a1620")
        bv = Canvas(128)
        pul = 0.5 + 0.5 * math.sin(f / 8 * TAU)
        for (dx, s, k) in stones[:4]:
            bv.stroke([(64 + dx - s * 0.9, 122 - s * 0.6 * g), (64 + dx + s * 0.9, 122 - s * 0.6 * g)], [2, 2],
                      [0.5 + 0.4 * pul] * 2)
        layer(fr, bv, BRONZE, BRONZE_LINE)
        if f % 4 == 2:
            fr.twinkle(64 - 30, 108, 2, W_WHITE, W_GOLD)
            fr.twinkle(64 + 30, 110, 2, W_WHITE, W_GOLD)
        frames.append(fr)
    piece("tank_stand_firm_stones", frames, pivot=FEET, blend="mix", plane="billboard", fps=8, loop=True)
    return frames


# ------------------------------------------------------------------ Furia do Mapinguari
def fury():
    """Furia: fumaca vermelha de raiva subindo do corpo em linguas, com tufos de pelo escuro do Mapinguari
    e riscos vermelhos (marcas de guerra) piscando. Em laco (10 s)."""
    frames = []
    r = rng(6400)
    # linguas mais altas nas laterais (a peca fica ATRAS do corpo e emoldura a silhueta)
    tongues = [(sd * r.uniform(12, 40), r.uniform(56, 96), r.uniform(0, TAU)) for sd in (-1, 1) for _ in range(5)]
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        ph = f / 8 * TAU
        for (dx, h, p) in tongues:
            pts = []
            for i in range(10):
                t = i / 9
                pts.append((64 + dx + math.sin(ph + p + t * 4) * 5 * t, 122 - t * h))
            cv.stroke(pts, [lerp(8, 1, i / 9) for i in range(10)], [0.45 + 0.1 * math.sin(ph + p)] * 10)
        cv.glow(2.4, 0.9, 0.14)
        fr.paint_canvas(cv, RAGE_G)
        if f % 4 < 2:  # marcas de guerra (tres riscos) dos dois lados
            for sd in (-1, 1):
                for i in range(3):
                    for j in range(5):
                        fr.px(64 + sd * (30 + i * 3), 70 + i * 2 + j, "#e8483a" if j < 4 else "#6e1010")
        frames.append(fr)
    piece("tank_fury_rage", frames, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return frames


def howl_mouth():
    """Urro do Mapinguari: a boca enorme da barriga (conta a lenda) abre na frente do tanque e URRA — dentes,
    baba e tracos vermelhos tremendo."""
    frames = []
    mo = spr(MOUTH_TXT, MOUTH_PAL, "#120202").scale(2)
    for f in range(10):
        fr = Frame(128)
        k = [0.2, 0.6, 1.0, 1.1, 1.0, 1.1, 1.0, 1.1, 0.8, 0.4][f]
        shake = (1 if f % 2 else -1) if 2 <= f <= 7 else 0
        cv = Canvas(128)
        if 2 <= f <= 8:
            for a in range(-4, 5):
                an = D(-90) + a * D(22)
                ln = 16 + 6 * ((f + a) % 3)
                x0, y0 = 64 + math.cos(an) * 38, 78 + math.sin(an) * 22
                cv.stroke([(x0, y0), (x0 + math.cos(an) * ln, y0 + math.sin(an) * ln * 0.7)], [3.0, 0.6], [0.9, 0.5])
        cv.glow(2.0, 0.9, 0.14)
        fr.paint_canvas(cv, RAGE_G)
        blit(fr, mo.squash(1.0, max(0.1, k)), 64 + shake, 78, alpha=1.0 if f < 9 else 0.5)
        frames.append(fr)
    piece("tank_mapinguari_howl_mouth", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def howl_ground():
    """Urro no chao (deitado, raio 4 = 120 px): frente de choque vermelha denteada correndo para fora e
    marcas de garra riscadas no chao."""
    frames = []
    c = 128
    r = rng(6500)
    marks = [(r.uniform(0, TAU), r.uniform(50, 110)) for _ in range(9)]
    for f in range(9):
        fr = Frame(256)
        cv = Canvas(256)
        v = 1.0 if f < 5 else 1 - (f - 4) * 0.24
        rr = 120 * ease_out(min(1, (f + 1) / 5))
        dx, dy = cv.X - c, cv.Y - c
        d = np.sqrt(dx * dx + dy * dy)
        a = np.arctan2(dy, dx)
        rr0 = rng(6510)
        for k in range(28):  # riscos de choque vermelhos correndo para fora (sem aro)
            an = k * TAU / 28 + rr0.uniform(-0.08, 0.08)
            ln = rr0.uniform(14, 30)
            cv.stroke([(c + math.cos(an) * (rr - ln), c + math.sin(an) * (rr - ln)),
                       (c + math.cos(an) * rr, c + math.sin(an) * rr)], [0.6, 3.4 * v + 0.6], [0.4 * v, 0.95 * v])
        for (ma, md) in marks:
            if md < rr:
                claw_marks(cv, c + math.cos(ma) * md, c + math.sin(ma) * md, ma + 1.2, 24, 5, 3, 2.2, 0.6 * v, 0.1)
        cv.glow(2.4, 0.9, 0.1 * v)
        fr.paint_canvas(cv, RAGE_GROUND)
        frames.append(fr)
    piece("tank_mapinguari_howl_ground", frames, pivot=(128, 128), blend="mix", plane="flat", fps=14,
          texel=4.0 / 120.0)
    return frames


def heavy_claws():
    """Garras Pesadas: a mao de garras do Mapinguari passa DUAS vezes na frente (ida e volta), deixando
    rastros vermelhos."""
    frames = []
    hand = spr(CLAW_HAND_TXT, CLAW_HAND_PAL, "#120202").scale(2)
    for f in range(12):
        fr = Frame(128)
        cv = Canvas(128)
        sw = 0 if f < 6 else 1
        t = min(1.0, (f % 6) / 3.0)
        if sw == 0:
            x0, y0, x1, y1, ang = 20, 30, 104, 100, -30
        else:
            x0, y0, x1, y1, ang = 108, 32, 22, 104, 30
        x, y = lerp(x0, x1, ease_in(t)), lerp(y0, y1, ease_in(t))
        if t > 0:
            for k in range(4):
                o = (k - 1.5) * 9
                cv.stroke([(x0 + o, y0), ((x0 + x) / 2 + o, (y0 + y) / 2 - 4), (x + o, y)], [0.5, 3.0, 4.0],
                          [0.4, 0.7, 1.0])
        cv.glow(2.0, 0.9, 0.16)
        fr.paint_canvas(cv, RAGE_G)
        if f % 6 < 4:
            blit(fr, hand.rot(ang), x, y)
        frames.append(fr)
    piece("tank_heavy_claws_rend", frames, pivot=(64, 70), blend="mix", plane="billboard", fps=16)
    return frames


def heavy_claws_ground():
    """Garras no chao (cone 90 graus, 2 cel = 110 px): quatro sulcos vermelhos fundos cruzando o leque."""
    def draw(cv, fr, f, ox, oy, R, a0, a1):
        v = 1.0 if f < 6 else 1.0 - (f - 5) * 0.3
        for i, ang in enumerate((D(-60), D(-120))):
            if f < i * 3:
                continue
            g = ease_out(min(1.0, (f - i * 3 + 1) / 2.0))
            claw_marks(cv, ox, oy - R * 0.55, ang, R * 1.1 * g, 13, 4, 5.0 * v, 0.6 * v, 0.06)
            claw_marks(cv, ox, oy - R * 0.55, ang, R * 1.0 * g, 13, 4, 1.8 * v, 1.0 * v, 0.06)
        cv.glow(2.0, 0.9, 0.12 * v)
        fr.paint_canvas(cv, RAGE_GROUND)
    return cone_frames("tank_heavy_claws_marks", RAGE_GROUND, draw, n=9, fps=16, radius_px=110, R_design=2.0)


def thirst_drop():
    """Sede de Luta: gota de sangue voando do alvo de volta para o berserker (para +x)."""
    frames = []
    dp = drop("#f07a5a", "#c83228", "#6e1010").outlined("#220404").rot(-90).scale(2)
    for f in range(4):
        fr = Frame(64, 32)
        cv = Canvas(64, 32)
        cv.stroke([(4, 16), (38, 16 + math.sin(f) * 1)], [0.4, 3.0], [0.2, 0.5])
        cv.glow(1.4, 0.8, 0.1)
        fr.paint_canvas(cv, RAGE_G)
        blit(fr, dp, 50, 16)
        frames.append(fr)
    piece("tank_battle_thirst_drop", frames, pivot=(50, 16), blend="mix", plane="billboard", fps=12, loop=True)
    return frames


def last_blow():
    """Ultima Pancada: o punho de garras do Mapinguari desce do alto e esmaga o alvo — cratera de poeira,
    rachaduras e tres marcas vermelhas."""
    frames = []
    hand = spr(CLAW_HAND_TXT, CLAW_HAND_PAL, "#120202").scale(3).flipv()
    for f in range(12):
        fr = Frame(128, 160)
        t = f / 11
        if f < 5:
            y = lerp(10, 100, ease_in(min(1, (f + 1) / 5)))
            cv = Canvas(128, 160)
            cv.stroke([(64, max(0, y - 60)), (64, y - 16)], [2, 22], [0.2, 0.5])
            cv.glow(2.0, 0.8, 0.1)
            fr.paint_canvas(cv, RAGE_G)
            blit(fr, hand, 64, y, (0.5, 1.0))
        else:
            k = f - 5
            v = 1.0 if k < 3 else 1 - (k - 2) * 0.2
            cv = Canvas(128, 160)
            for i in range(12):
                a = D(180) + i * D(15)
                cv.stroke([(64 + math.cos(a) * (10 + k * 6), 146 + math.sin(a) * (4 + k * 2)),
                           (64 + math.cos(a) * (26 + k * 9), 146 + math.sin(a) * (10 + k * 4))], [4 * v, 1], [0.9 * v] * 2)
            claw_marks(cv, 64, 110, D(-80), 56, 12, 3, 4 * v, 0.7 * v, 0.05)
            cv.glow(2.0, 0.9, 0.16 * v)
            fr.paint_canvas(cv, RAGE_G)
            if k < 5:
                dv = Canvas(128, 160)
                for i in range(6):
                    puff(dv, 64 + (i - 2.5) * 16 * (1 + k * 0.15), 150 - k * 2, 11 - k)
                dv.noise_erode(k * 0.15, seed=6600 + k)
                layer(fr, dv, DUST, DUST_LINE)
            if k < 2:
                blit(fr, hand.squash(1.1, 0.9), 64, 150, (0.5, 1.0))
        frames.append(fr)
        _ = t
    piece("tank_last_blow_smash", frames, pivot=(64, 154), blend="mix", plane="billboard", fps=16)
    return frames


ALL = [shell_knock, shell_retreat, hard_shell, patience, shell_bash_cone, thick_hide, tapir_print, tapir_ram,
       tapir_impact, living_wall_stake, stand_firm, fury, howl_mouth, howl_ground, heavy_claws, heavy_claws_ground,
       thirst_drop, last_blow]
_ = (Spr, BLOOD, BLOOD_LINE, BRONZE_G, LEAF, W_PALE)
