"""Arco da Terra de Pindorama (30/09/2026): Flecha do Cerrado, Tocaia do Brejo e Gaviao-Real.

Flechas de taquara com penas (cada skill com a sua: dupla, pesada com vento, fita vermelha de aviso,
espinhenta, reta de luz), revoada caindo do ceu e fincando no chao, lama que cobre o corpo e borbulha,
taboas do brejo, laco de cipo no chao, olho do gaviao, penas douradas girando, gaviao-real mergulhando
e asas abrindo nas costas."""
from __future__ import annotations

import math

import numpy as np

from fxdraw import Canvas, Frame, Spr, blit, ease_in, ease_out, layer, lerp, piece, rng
from fxpindorama import (D, DUST, DUST_LINE, FEATHER_GOLD, FEATHER_WHITE, HAWK_EYE_PAL, HAWK_EYE_TXT, HAWK_PAL,
                     HAWK_TXT, LEAF, LEAF_LINE, LEAFLET_PAL, LEAFLET_TXT, MATINTA_G, MUD, MUD_LINE, OLIVE_G,
                     OLIVE_GROUND, SAP_G, TAU, W_GOLD, W_PALE, W_WHITE, arrow, claw_marks, dither_alpha, drop,
                     feather, leaf_poly, puff, spr, spiral_vine, vine)

FEET = (64, 124)


def _arrow_frames(name, spr_fn, w=96, h=32, trail=OLIVE_G, extra=None, n=4, fps=16):
    frames = []
    for f in range(n):
        fr = Frame(w, h)
        cv = Canvas(w, h)
        cv.stroke([(4, h / 2), (w - 44, h / 2)], [0.4, 2.8], [0.2, 0.45])
        cv.glow(1.6, 0.8, 0.1)
        fr.paint_canvas(cv, trail)
        if extra:
            extra(fr, f)
        blit(fr, spr_fn(f), w - 4, h / 2, (1.0, 0.5))
        frames.append(fr)
    piece(name, frames, pivot=(w - 4, h // 2), blend="mix", plane="billboard", fps=fps, loop=True)
    return frames


# ------------------------------------------------------------------ Flecha do Cerrado
def low_shot_skim():
    """Tiro Rasante: tufo de capim e poeira levantado pela flecha que passa rente ao chao."""
    frames = []
    r = rng(3000)
    blades = [(r.uniform(-14, 14), r.uniform(8, 16), r.uniform(-0.5, 0.5)) for _ in range(7)]
    for f in range(7):
        fr = Frame(64)
        dv = Canvas(64)
        s = 0.5 + 0.1 * f
        for k in range(3):
            puff(dv, 32 + (k - 1) * 9 * (1 + f * 0.1), 54 - f * 1.5, 6 * s)
        dv.noise_erode(max(0, (f - 2) * 0.2), seed=3010 + f)
        layer(fr, dv, DUST, DUST_LINE)
        gv = Canvas(64)
        for (x, ln, lean) in blades:  # capim deitando e voltando
            bend = lean + math.sin(min(f, 3) / 3 * math.pi) * 0.9
            gv.stroke([(32 + x, 60), (32 + x + math.sin(bend) * ln, 60 - math.cos(bend) * ln)], [2.2, 0.6],
                      [0.62, 0.62])
        layer(fr, gv, LEAF, LEAF_LINE)
        frames.append(fr)
    piece("bow_low_shot_skim", frames, pivot=(32, 60), blend="mix", plane="billboard", fps=14)
    return frames


def double_arrow():
    """Flecha Dupla: duas flechas lado a lado, uma um pouco atras da outra."""
    a = arrow()

    def s(f):
        img = Frame(60, 30)
        blit(img, a, 60, 8, (1.0, 0.5))
        blit(img, a, 50, 22, (1.0, 0.5))
        return Spr(img.rgba)
    return _arrow_frames("bow_double_arrow_pair", s, w=100, h=34)


def taut_charge():
    """Arco Tenso (conjuracao, 1 s): o vento do cerrado se enrola num ponto na frente do peito, folhas sendo
    puxadas para dentro. Em laco enquanto conjura."""
    frames = []
    lf = spr(LEAFLET_TXT, LEAFLET_PAL, LEAF_LINE)
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        cx, cy = 64, 64
        for k in range(3):
            a0 = k * TAU / 3 + f * 0.5
            pts = [(cx + math.cos(a0 + i * 0.35) * (40 - i * 3.2), cy + math.sin(a0 + i * 0.35) * (26 - i * 2))
                   for i in range(12)]
            cv.stroke(pts, [0.5 + i * 0.25 for i in range(12)], [0.3 + i * 0.05 for i in range(12)])
        cv.circle(cx, cy, 5 + (f % 2), 0.9)
        cv.glow(2.2, 0.9, 0.16)
        fr.paint_canvas(cv, OLIVE_G)
        for k in range(4):
            u = (f / 8 + k / 4) % 1.0
            a = k * 1.7 + u * 3
            rr = 44 * (1 - u)
            blit(fr, lf.rot(math.degrees(a)), cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.6,
                 alpha=1.0 if u < 0.8 else 0.5)
        fr.twinkle(cx, cy, 3 if f % 2 else 2, W_WHITE, "#e2e8a0", "#a8b44a")
        frames.append(fr)
    piece("bow_taut_draw_charge", frames, pivot=FEET, blend="mix", plane="billboard", fps=14, loop=True)
    return frames


def taut_arrow():
    """Flecha do Arco Tenso: maior, com espiral de vento verde-oliva enrolada no cabo."""
    a = arrow(fletch=("#e2e8a0", "#6e7e2e")).scale(1)

    def extra(fr, f):
        cv = Canvas(fr.w, fr.h)
        for k in range(2):
            pts = [(fr.w - 20 - i * 4, fr.h / 2 + math.sin(i * 0.9 + f * 1.6 + k * math.pi) * 7) for i in range(16)]
            cv.stroke(pts, [2.4 - i * 0.12 for i in range(16)], [0.8 - i * 0.03 for i in range(16)])
        cv.glow(1.8, 0.9, 0.14)
        m = Frame(fr.w, fr.h)
        m.paint_canvas(cv, OLIVE_G)
        mm = m.rgba[..., 3] > 0
        fr.rgba[mm] = m.rgba[mm]
    return _arrow_frames("bow_taut_draw_arrow", lambda f: a, w=112, h=36, extra=extra)


def taut_impact():
    """Impacto do Arco Tenso: estouro de vento (riscos em leque), lascas de taquara e folhas voando."""
    frames = []
    r = rng(3100)
    chips = [(r.uniform(0, TAU), r.uniform(10, 18)) for _ in range(10)]
    lf = spr(LEAFLET_TXT, LEAFLET_PAL, LEAF_LINE)
    for f in range(9):
        fr = Frame(128)
        cv = Canvas(128)
        v = 1.0 if f < 3 else 1 - (f - 2) * 0.16
        g = ease_out(min(1, (f + 1) / 4))
        rr = rng(3105)
        for k in range(14):  # riscos de vento em leque, tamanhos desiguais (nao uma flor)
            a = k * TAU / 14 + rr.uniform(-0.15, 0.15)
            ln = rr.uniform(0.6, 1.0)
            cv.stroke([(64 + math.cos(a) * (6 + 24 * g), 64 + math.sin(a) * (6 + 24 * g)),
                       (64 + math.cos(a) * (14 + 44 * g * ln), 64 + math.sin(a) * (14 + 44 * g * ln))],
                      [2.2 * v, 0.4], [0.8 * v, 0.4 * v])
        if f < 3:
            cv.circle(64, 64, [7, 9, 5][f], 1.0)
        cv.glow(2.4, 0.9, 0.16 * v)
        fr.paint_canvas(cv, OLIVE_G)
        for i, (a, sp) in enumerate(chips):
            d = sp * (f + 1) * 0.5
            x, y = 64 + math.cos(a) * d, 64 + math.sin(a) * d + 0.5 * f * f
            if i % 3 == 0:
                blit(fr, lf.rot(a * 60 + f * 40), x, y, alpha=1.0 if f < 6 else 0.5)
            else:
                fr.px(int(x), int(y), "#dcc07a")
                fr.px(int(x) + 1, int(y), "#a07c3e")
        frames.append(fr)
    piece("bow_taut_draw_impact", frames, pivot=(64, 64), blend="mix", plane="billboard", fps=16)
    return frames


def warning_arrow():
    """Flecha de Aviso: penas vermelhas e uma fita vermelha comprida ondulando atras."""
    a = arrow(fletch=("#f07a5a", "#b4201c"), ribbon="#fff4e0")

    def extra(fr, f):
        for i in range(40):
            x = fr.w - 44 - i
            y = fr.h / 2 + math.sin(i * 0.3 - f * 1.4) * (2 + i * 0.12)
            for dy in (0, 1):
                fr.px(int(x), int(y) + dy, "#e8483a" if (i // 4) % 2 else "#b4201c")
    return _arrow_frames("bow_warning_arrow_arrow", lambda f: a, w=112, h=36, extra=extra)


def flock_fall():
    """Revoada de Flechas: uma flecha caindo do ceu de ponta para baixo, com risco de ar."""
    frames = []
    a = arrow().rot(-90)
    for f in range(4):
        fr = Frame(32, 80)
        cv = Canvas(32, 80)
        cv.stroke([(16, 2), (16, 36)], [0.4, 2.4], [0.2, 0.4])
        cv.glow(1.4, 0.8, 0.1)
        fr.paint_canvas(cv, OLIVE_G)
        blit(fr, a, 16 + (f % 2), 78, (0.5, 1.0))
        frames.append(fr)
    piece("bow_arrow_flock_fall", frames, pivot=(16, 78), blend="mix", plane="billboard", fps=16, loop=True)
    return frames


def flock_stuck():
    """Flecha fincada no chao (inclinada), com poeirinha no pe e as penas tremendo; fica alguns segundos."""
    frames = []
    a = arrow().rot(-70)
    for f in range(8):
        fr = Frame(48, 64)
        if f < 3:
            dv = Canvas(48, 64)
            for k in range(3):
                puff(dv, 24 + (k - 1) * 8 * (1 + f * 0.3), 60 - f, 4 + f)
            dv.noise_erode(f * 0.25, seed=3200 + f)
            layer(fr, dv, DUST, DUST_LINE)
        wob = [0, 1, 0, -1, 0, 0, 0, 0][f]
        blit(fr, a.rot(wob * 3), 24, 60, (0.5, 0.95))
        frames.append(fr)
    piece("bow_arrow_flock_stuck", frames, pivot=(24, 60), blend="mix", plane="billboard", fps=14, loop=True)
    return frames


# ------------------------------------------------------------------ Tocaia do Brejo
def mud_skin():
    """Pele de Barro: lama do brejo espirra do chao e cobre o corpo em respingos, escorrendo."""
    frames = []
    r = rng(3300)
    blobs = [(r.uniform(-1, 1), r.uniform(0.6, 1.3), r.uniform(3, 6)) for _ in range(16)]
    for f in range(10):
        fr = Frame(128)
        cv = Canvas(128)
        t = f / 9
        for (sx, sp, sz) in blobs:
            u = min(1.0, t * 1.4)
            x = 64 + sx * 36 * u
            y = 122 - sp * 90 * u + 110 * max(0, u - 0.5) ** 2
            if y < 124:
                cv.circle(x, y, sz * (1 - 0.4 * t), 0.6)
                cv.circle(x - 1, y - 1, sz * 0.5 * (1 - 0.4 * t), 0.85)
        if f >= 4:  # escorridos no corpo
            for k in range(5):
                x = 48 + k * 8
                y0 = 60 + (k % 2) * 10
                ln = (f - 3) * 5
                cv.stroke([(x, y0), (x, y0 + ln)], [4, 2], [0.6, 0.6])
        cv.ellipse(64, 121, 30 * min(1, t * 3), 5, 0.5)
        layer(fr, cv, MUD, MUD_LINE)
        dither_alpha(fr, 1.0 if f < 7 else 0.5)
        frames.append(fr)
    piece("bow_mud_skin_splash", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def mud_hide():
    """Lama no Corpo: poca de lama se abre nos pes, borbulha e cinco fios de lama sobem se enrolando no corpo,
    pingando (depois o jogador fica meio transparente pelo estado de invisivel)."""
    frames = []
    for f in range(12):
        fr = Frame(128)
        cv = Canvas(128)
        t = f / 11
        w = 34 * min(1, t * 3)
        cv.ellipse(64, 120, w, 7, 0.45)
        cv.ellipse(64, 119, w * 0.7, 4.5, 0.62)
        rise = math.sin(min(1.0, t * 1.25) * math.pi * 0.5) if t < 0.8 else 1.0
        for k in range(5):
            x0 = 64 + (k - 2) * 12
            h = (60 + 16 * math.sin(k * 2.1)) * rise
            pts = [(x0 + math.sin(i * 0.9 + k + t * 4) * (4 + i * 0.6), 120 - i / 9 * h) for i in range(10)]
            cv.stroke(pts, [lerp(8, 2, i / 9) for i in range(10)], [0.55] * 10)
            cv.stroke(pts, [lerp(3, 0.8, i / 9) for i in range(10)], [0.82] * 10)
            if f >= 5 and k % 2 == 0:  # pingos caindo das pontas
                u = ((f - 5) % 4) / 4
                x, y = pts[-1]
                cv.circle(x, y + 6 + u * 30, 2.2, 0.62)
        for k in range(4):  # bolhas
            u = ((f + k * 3) % 6) / 6
            x = 64 + (k - 1.5) * 14
            cv.circle(x, 118 - u * 6, 2 + u * 3, 0.8)
        layer(fr, cv, MUD, MUD_LINE)
        dither_alpha(fr, 1.0 if f < 8 else (0.75 if f < 10 else 0.5))
        frames.append(fr)
    piece("bow_mud_hide_mud", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def ambush_reeds():
    """Tocaia: taboas do brejo (cabeca marrom, folha fina) brotam em volta do arqueiro e se abrem para a
    flecha sair."""
    frames = []
    r = rng(3400)
    reeds = [(r.uniform(-44, 44), r.uniform(50, 80), r.uniform(-0.15, 0.15)) for _ in range(9)]
    for f in range(12):
        fr = Frame(128)
        g = ease_out(min(1, (f + 1) / 4))
        part = max(0.0, (f - 6) / 5)
        lv = Canvas(128)
        hv = Canvas(128)
        for (x, h, lean) in reeds:
            side = 1 if x > 0 else -1
            ang = lean + side * part * 0.6 + math.sin(f * 0.8 + x) * 0.05
            top = (64 + x + math.sin(ang) * h * g, 124 - math.cos(ang) * h * g)
            lv.stroke([(64 + x, 124), top], [3.0, 1.0], [0.6, 0.6])
            lv.stroke([(64 + x + 3, 124), (64 + x + 3 + math.sin(ang + 0.3) * h * 0.6 * g,
                                           124 - math.cos(ang + 0.3) * h * 0.6 * g)], [2.2, 0.6], [0.5, 0.5])
            mx = 64 + x + math.sin(ang) * h * g * 0.82
            my = 124 - math.cos(ang) * h * g * 0.82
            hv.ellipse(mx, my, 2.6, 7 * g + 0.5, 0.6, rot=ang)
        layer(fr, lv, LEAF, LEAF_LINE)
        layer(fr, hv, MUD, MUD_LINE)
        if f in (7, 8):
            fr.twinkle(64, 64, 3, W_WHITE, "#e2e8a0", "#a8b44a")
        if f >= 9:
            dither_alpha(fr, 0.5)
        frames.append(fr)
    piece("bow_ambush_shot_reeds", frames, pivot=FEET, blend="mix", plane="billboard", fps=12)
    return frames


def vine_snare():
    """Armadilha de Cipo (deitada no chao, raio 2 = 72 px): laco de cipo que se fecha girando, com folhas e
    estacas; no fim o no aperta no meio."""
    frames = []
    c = 96
    lf = spr(LEAFLET_TXT, LEAFLET_PAL, LEAF_LINE)
    for f in range(10):
        fr = Frame(192)
        cv = Canvas(192)
        t = f / 9
        close = ease_in(min(1, t * 1.2))
        R = lerp(76, 30, close)
        for k in range(3):
            pts = spiral_vine(c, c, R, R * 0.55, 0.85, 1.0, a0=k * TAU / 3 + t * 2.5, n=30)
            vine(cv, pts, 6.0, 2.0, 0.55)
            vine(cv, pts, 2.0, 0.8, 0.9)
        for k in range(12):  # espinhos no cipo
            a = k * TAU / 12 + t * 2.5
            rr = R * (0.8 + 0.2 * math.sin(k))
            cv.spike(c + math.cos(a) * rr, c + math.sin(a) * rr, a + 1.2, 0, 7, 3, 0.7)
        layer(fr, cv, LEAF, LEAF_LINE)
        for k in range(6):
            a = k * TAU / 6 + t * 2.5
            blit(fr, lf.scale(2).rot(math.degrees(a) + 90), c + math.cos(a) * R, c + math.sin(a) * R)
        if f >= 7:
            dither_alpha(fr, 0.75 if f < 9 else 0.5)
        frames.append(fr)
    piece("bow_vine_snare_trap", frames, pivot=(96, 96), blend="mix", plane="flat", fps=12, texel=2.0 / 72.0)
    return frames


def thorn_arrow():
    """Flecha de Espinho: cabo verde de cipo com espinhos e gota roxa de veneno pingando."""
    a = arrow(fletch=("#a6d86a", "#2f6b3e"), head=("#c9a8ec", "#5a3a8c"), ribbon="#5a3a8c",
              shaft=("#8cc860", "#3e7a34"))
    dp = drop("#c9a8ec", "#8e66c4", "#5a3a8c")

    def extra(fr, f):
        for i in range(0, 28, 6):  # espinhos no cabo
            x = fr.w - 16 - i
            fr.px(x, fr.h // 2 - 3, "#2f6b3e")
            fr.px(x + 1, fr.h // 2 - 4, "#2f6b3e")
            fr.px(x, fr.h // 2 + 3, "#2f6b3e")
            fr.px(x + 1, fr.h // 2 + 4, "#2f6b3e")
        blit(fr, dp, fr.w - 30 - f * 3, fr.h // 2 + 8 + f, alpha=1.0 if f < 3 else 0.5)
    return _arrow_frames("bow_thorn_arrow_arrow", lambda f: a, w=104, h=36, extra=extra)


# ------------------------------------------------------------------ Gaviao-Real
def still_eye():
    """Olho Parado: o olho do gaviao-real abre acima da cabeca, com quatro tracos de mira apontando para ele
    (fecham devagar), e pisca uma vez."""
    frames = []
    eye = spr(HAWK_EYE_TXT, HAWK_EYE_PAL, "#1a1418").scale(2)
    for f in range(12):
        fr = Frame(128)
        cv = Canvas(128)
        op = [0.1, 0.5, 1, 1, 1, 1, 1, 1, 0.2, 1, 1, 1][f]
        d = lerp(48, 30, ease_out(min(1, f / 7)))
        for a in (D(20), D(160), D(200), D(340)):
            x, y = 64 + math.cos(a) * d, 34 + math.sin(a) * d * 0.55
            cv.stroke([(x, y), (x + math.cos(a) * 10, y + math.sin(a) * 5.5)], [3.0, 1.0], [0.85, 0.5])
        cv.glow(1.8, 0.9, 0.12)
        fr.paint_canvas(cv, SAP_G)
        blit(fr, eye.squash(1.0, op), 64, 34, alpha=1.0 if f < 10 else 0.5)
        frames.append(fr)
    piece("bow_still_eye_eye", frames, pivot=FEET, blend="mix", plane="billboard", fps=10)
    return frames


def true_arrow():
    """Flecha Sem Desvio: flecha de ponta branca e penas brancas, com uma linha de luz reta e comprida."""
    a = arrow(fletch=("#fffcf0", "#c8c0b0"), head=("#ffffff", "#e6b43a"), ribbon="#e6b43a")

    def extra(fr, f):
        cv = Canvas(fr.w, fr.h)
        cv.stroke([(0, fr.h / 2), (fr.w - 40, fr.h / 2)], [1.0, 3.0], [0.5, 1.0])
        cv.glow(1.6, 0.9, 0.14)
        m = Frame(fr.w, fr.h)
        m.paint_canvas(cv, SAP_G)
        mm = m.rgba[..., 3] > 0
        fr.rgba[mm] = m.rgba[mm]
    return _arrow_frames("bow_true_arrow_arrow", lambda f: a, w=144, h=28, extra=extra)


def true_pierce():
    """Impacto da Flecha Sem Desvio: a couraca do alvo estala em cacos (DEF ignorada) e a luz atravessa."""
    frames = []
    r = rng(3500)
    shards = [(r.uniform(0, TAU), r.uniform(8, 14), r.uniform(3, 6)) for _ in range(12)]
    for f in range(8):
        fr = Frame(128)
        cv = Canvas(128)
        v = 1.0 if f < 3 else 1 - (f - 2) * 0.18
        cv.stroke([(4, 64), (124, 64)], [2 + 5 * v, 2 + 5 * v], [0.55 * v, 0.55 * v])
        cv.stroke([(4, 64), (124, 64)], [1.5, 1.5], [1.0 * v, 1.0 * v])
        if f < 3:
            cv.circle(64, 64, [10, 14, 8][f], 1.0)
        cv.glow(2.0, 0.9, 0.16 * v)
        fr.paint_canvas(cv, SAP_G)
        sv = Canvas(128)
        for (a, sp, sz) in shards:
            d = 8 + sp * f * 0.9
            x, y = 64 + math.cos(a) * d, 64 + math.sin(a) * d + 0.4 * f * f
            k = sz * (1 - f / 12)
            sv.poly([(x - k, y), (x, y - k * 0.7), (x + k, y + k * 0.3), (x, y + k * 0.6)], 0.62)
        layer(fr, sv, solid_steel(), "#2e2834")
        dither_alpha(fr, 1.0 if f < 6 else 0.5)
        frames.append(fr)
    piece("bow_true_arrow_pierce", frames, pivot=(64, 64), blend="mix", plane="billboard", fps=16)
    return frames


def solid_steel():
    from fxpindorama import STEEL
    return STEEL


def sure_aim():
    """Mira Certeira: tres penas douradas de gaviao girando em volta do arqueiro (uma para cada tiro certo).
    _back e _front."""
    back, front = [], []
    fe = feather(FEATHER_GOLD).scale(2)
    for f in range(8):
        fb, ff = Frame(128), Frame(128)
        for k in range(3):
            ph = TAU * (f / 8 / 3 + k / 3)
            depth = math.sin(ph)
            x, y = 64 + math.cos(ph) * 42, 66 + depth * 10
            sp = fe.rot(-math.degrees(math.cos(ph)) * 0.5 - 20 + k * 5)
            if depth >= 0:
                blit(ff, sp, x, y)
                if f % 4 == k:
                    ff.twinkle(x + 2, y - 8, 2, W_WHITE, W_GOLD)
            else:
                blit(fb, sp, x, y, alpha=0.75)
        back.append(fb)
        front.append(ff)
    piece("bow_sure_aim_back", back, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    piece("bow_sure_aim_front", front, pivot=FEET, blend="mix", plane="billboard", fps=10, loop=True)
    return back, front


def hawk_dive():
    """Mergulho do Gaviao: gaviao-real de asas para cima caindo do ceu sobre o alvo (sem girar)."""
    frames = []
    hk = spr(HAWK_TXT, HAWK_PAL, "#120e14").scale(2)
    for f in range(4):
        fr = Frame(96)
        cv = Canvas(96)
        for k in range(3):
            x = 48 + (k - 1) * 22
            cv.stroke([(x, 4), (x, 30)], [0.4, 2.4], [0.2, 0.45])
        cv.glow(1.6, 0.8, 0.1)
        fr.paint_canvas(cv, SAP_G)
        h = hk.squash(1.0 - 0.05 * (f % 2), 1.0)
        blit(fr, h, 48, 92, (0.5, 1.0))
        frames.append(fr)
    piece("bow_hawk_dive_hawk", frames, pivot=(48, 70), blend="mix", plane="billboard", fps=12, loop=True)
    return frames


def hawk_impact():
    """Impacto do mergulho: garras rasgando de cima, penas brancas e cinzas espalhando, poeira."""
    frames = []
    r = rng(3600)
    feathers = [(r.uniform(0, TAU), r.uniform(0.6, 1.2), r.uniform(0, 360)) for _ in range(8)]
    fw = feather(FEATHER_WHITE)
    fg = feather({"a": "#8a8494", "b": "#5a5060", "c": "#2a2430"})
    for f in range(10):
        fr = Frame(128)
        cv = Canvas(128)
        v = 1.0 if f < 3 else max(0, 1 - (f - 2) * 0.2)
        if v > 0:
            claw_marks(cv, 64, 70, D(-90), 60 * ease_out(min(1, (f + 1) / 2)), 12, 3, 4 * v, 0.6 * v, curve=0.05)
            claw_marks(cv, 64, 70, D(-90), 54 * ease_out(min(1, (f + 1) / 2)), 12, 3, 1.5 * v, 1.0 * v, curve=0.05)
            cv.glow(2.0, 0.9, 0.14 * v)
            fr.paint_canvas(cv, SAP_G)
        if f < 5:
            dv = Canvas(128)
            for k in range(5):
                puff(dv, 64 + (k - 2) * 12 * (1 + f * 0.2), 118 - f, 6 + f * 1.5)
            dv.noise_erode(f * 0.18, seed=3610 + f)
            layer(fr, dv, DUST, DUST_LINE)
        for i, (a, sp, rot) in enumerate(feathers):
            t = f / 9
            x = 64 + math.cos(a) * 50 * sp * t
            y = 70 + math.sin(a) * 30 * sp * t - 20 * t + 50 * t * t
            blit(fr, (fw if i % 2 else fg).rot(rot + f * 25), x, y, alpha=1.0 if f < 7 else 0.5)
        frames.append(fr)
    piece("bow_hawk_dive_impact", frames, pivot=(64, 110), blend="mix", plane="billboard", fps=14)
    return frames


WING_TXT = """
..........................aa
.......................aaabb
....................aaabbbbb
.................aaabbbbbbbc
..............aaabbbbbbbbbc.
...........aaabbbbbbbbbbbcc.
........aaabbbbbbbbbbbbbcc..
......aabbbbbbbbbbbbbbbcc...
....aabbbbbbbbbbbbbbbccc....
...abbbbbwbbbbbbbbbccc......
..abbbbwwbbbbbbbccc.........
.abbbwwwbbbbbccc............
abbwwbwbbbccc...............
abwbwbwbcc..................
awbwbwcc....................
.w.w.w......................
"""


def _wing(cv_dark, cv_light, sx, sy, side, spread, k):
    """Asa aberta desenhada pena a pena: 7 remiges saindo do ombro (sx, sy) em leque, mais longas na ponta,
    e uma camada de coberteiras por cima. side = +1 (direita) / -1 (esquerda); spread = angulo de abertura."""
    for i in range(7):
        a = D(22) - spread * i / 6.0  # abre para os LADOS (asa de rapina planando), nao para cima
        ln = (30 + (6 - abs(i - 4)) * 4.0) * k
        ang = a if side > 0 else math.pi - a
        bx, by = sx + math.cos(ang) * 6 * k, sy + math.sin(ang) * 6 * k
        cv_dark.poly(leaf_poly(bx, by, ang, ln, 8 * k), 0.5)
        cv_dark.poly(leaf_poly(bx, by, ang, ln * 0.92, 4 * k), 0.75)
    for i in range(5):
        a = D(10) - spread * 0.8 * i / 4.0
        ang = a if side > 0 else math.pi - a
        cv_light.poly(leaf_poly(sx, sy, ang, (18 + i * 2) * k, 9 * k), 0.62)


def short_flight():
    """Voo Curto: asas de gaviao-real abrem nas costas (pena a pena), batem uma vez e somem; penas caem."""
    from fxpindorama import solid_ramp
    dark = solid_ramp(["#2a2430", "#4a4250", "#6e6676", "#9a92a2"])
    light = solid_ramp(["#5a5060", "#8a8494", "#b0aab8", "#d8d4e0"])
    frames = []
    fw = feather(FEATHER_WHITE)
    spreads = [D(25), D(45), D(62), D(70), D(50), D(35), D(55), D(65), D(65), D(65)]
    for f in range(10):
        fr = Frame(128)
        k = min(1.0, (f + 2) / 4)
        cd, cl = Canvas(128), Canvas(128)
        for side in (1, -1):
            _wing(cd, cl, 64 + side * 5, 78, side, spreads[f], k)
        layer(fr, cd, dark, "#120e14")
        layer(fr, cl, light, "#4a4250")
        for side in (1, -1):  # listras escuras nas remiges (gaviao-real)
            for i in range(0, 7, 2):
                a = D(22) - spreads[f] * i / 6.0
                ang = a if side > 0 else math.pi - a
                for d in (22, 30):
                    x, y = 64 + side * 5 + math.cos(ang) * d * k, 78 + math.sin(ang) * d * k
                    fr.px(int(x), int(y), "#1a1420")
                    fr.px(int(x) + 1, int(y), "#1a1420")
        if f >= 7:
            dither_alpha(fr, 0.75 if f < 9 else 0.5)
        for i in range(3):
            if f >= 3:
                t = (f - 3) / 6
                blit(fr, fw.rot(40 * i + f * 20), 50 + i * 14, 80 + t * 40, alpha=1.0 if t < 0.7 else 0.5)
        frames.append(fr)
    piece("bow_short_flight_wings", frames, pivot=FEET, blend="mix", plane="billboard", fps=14)
    return frames


ALL = [low_shot_skim, double_arrow, taut_charge, taut_arrow, taut_impact, warning_arrow, flock_fall, flock_stuck,
       mud_skin, mud_hide, ambush_reeds, vine_snare, thorn_arrow, still_eye, true_arrow, true_pierce, sure_aim,
       hawk_dive, hawk_impact, short_flight]
_ = (np, lerp, leaf_poly, MATINTA_G, OLIVE_GROUND, W_PALE)
