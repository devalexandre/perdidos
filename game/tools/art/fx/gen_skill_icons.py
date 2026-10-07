#!/usr/bin/env python3
"""Ícones 32x32 das skills (barra de atalhos e janela de skills), a partir da arte dos efeitos.

Cada ícone = placa com borda na cor da escola + o quadro mais forte (mais pixels opacos) da folha de efeito
escolhida, reduzido para caber em ART_PX e com contorno escuro. Folhas "add" entram somadas na placa (como no
jogo); "mix" por cima. Saída: assets/skills/<skill_id>.png (lido por HotbarSlot.skill_icon).

Rodar depois do gen_skill_fx.py:  python3 tools/art/fx/gen_skill_icons.py
Depois: python3 tools/art/write_imports.py && godot --headless --import
"""
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
FX = os.path.join(GAME, 'assets', 'fx', 'skills')
OUT = os.path.join(GAME, 'assets', 'skills')
N = 32
ART_PX = 26

# skill -> (folha, blend, escola)
PICKS = {
    'blade_firm_strike': ('blade_firm_strike_slash', 'add'),
    'blade_charge': ('blade_charge_impact', 'add'),
    'blade_clearing_sweep': ('blade_clearing_sweep_arc', 'add'),
    'blade_horizon_cut': ('blade_horizon_cut_wave', 'add'),
    'blade_steel_spin': ('blade_steel_spin_whirl', 'add'),
    'blade_iron_stance': ('blade_iron_stance_front', 'mix'),
    'arcane_spark': ('arcane_spark_projectile', 'add'),
    'arcane_will_o_wisp': ('arcane_will_o_wisp_projectile', 'add'),
    'arcane_creeping_flame': ('arcane_creeping_flame_tongue', 'add'),
    'arcane_frost_burst': ('arcane_frost_burst_crystal', 'mix'),
    'arcane_star_fall': ('arcane_star_fall_star', 'add'),
    'arcane_barrier': ('arcane_barrier_shield', 'add'),
}
# escola -> (fundo escuro, fundo claro no centro, aro)
SCHOOL = {
    'blade': ((28, 22, 18), (74, 58, 40), (214, 160, 74)),
    'arcane': ((16, 22, 40), (34, 62, 84), (92, 206, 196)),
    # Terra do Sabia v0.4 (30/09/2026): arco verde-oliva, suporte verde-folha, tanque bronze, hibrido brasa.
    'bow': ((22, 26, 14), (60, 70, 32), (160, 172, 64)),
    'support': ((14, 30, 20), (38, 82, 46), (112, 200, 84)),
    'tank': ((30, 22, 14), (82, 58, 34), (196, 136, 64)),
    'hybrid': ((34, 16, 10), (92, 42, 20), (244, 124, 50)),
}
OUTLINE = (20, 14, 12)


def plate(school: str) -> np.ndarray:
    dark, light, rim = (np.array(c, dtype=float) for c in SCHOOL[school])
    y, x = np.mgrid[0:N, 0:N]
    d = np.sqrt((x - 15.5) ** 2 + (y - 13.5) ** 2) / 20.0
    t = np.clip(1 - d, 0, 1)[..., None]
    img = np.zeros((N, N, 4), dtype=float)
    img[..., :3] = dark + (light - dark) * t
    img[..., 3] = 255
    img[1, 1:-1, :3] = img[-2, 1:-1, :3] = img[1:-1, 1, :3] = img[1:-1, -2, :3] = rim
    img[2, 2:-2, :3] = np.minimum(255, rim * 0.55 + 90)  # brilho do aro em cima
    img[0, :, :3] = img[-1, :, :3] = img[:, 0, :3] = img[:, -1, :3] = OUTLINE
    for cy, cx in ((0, 0), (0, N - 1), (N - 1, 0), (N - 1, N - 1)):
        img[cy, cx, 3] = 0
    return img


def best_frame(sheet: str) -> Image.Image:
    im = Image.open(os.path.join(FX, sheet + '.png')).convert('RGBA')
    fh = im.height
    fw = SHEET_W.get(sheet) or (fh if im.width % fh == 0 else im.width)
    frames = [im.crop((i * fw, 0, (i + 1) * fw, fh)) for i in range(im.width // fw)]
    return max(frames, key=lambda f: int((np.array(f)[..., 3] > 40).sum()))


def fit(fr: Image.Image, px: int = ART_PX) -> Image.Image:
    bb = fr.getbbox()
    fr = fr.crop(bb)
    s = px / max(fr.width, fr.height)
    w, h = max(1, round(fr.width * s)), max(1, round(fr.height * s))
    a = np.array(fr).astype(float)
    a[..., :3] *= a[..., 3:4] / 255.0  # pré-multiplica para reduzir sem franja
    small = np.stack([np.array(Image.fromarray(a[..., c].astype(np.uint8)).resize((w, h), Image.LANCZOS),
                               dtype=float) for c in range(4)], axis=-1)
    alpha = small[..., 3:4]
    rgb = np.where(alpha > 0, small[..., :3] * 255.0 / np.maximum(alpha, 1), 0)
    out = np.concatenate([np.clip(rgb, 0, 255), np.clip(alpha, 0, 255)], axis=-1).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


def biggest_piece(fr: Image.Image) -> Image.Image:
    """Maior peça conectada do quadro (uma placa da Postura de Ferro)."""
    from scipy.ndimage import label
    a = np.array(fr)
    lab, n = label(a[..., 3] > 40)
    if n == 0:
        return fr
    sizes = [(lab == i).sum() for i in range(1, n + 1)]
    keep = lab == (int(np.argmax(sizes)) + 1)
    a[~keep] = 0
    return Image.fromarray(a, 'RGBA')


def weapon(name: str, px: int) -> Image.Image:
    im = Image.open(os.path.join(GAME, 'assets', 'items', 'icons', f'icon_item_{name}.png')).convert('RGBA')
    im = im.crop(im.getbbox())
    s = px / max(im.width, im.height)
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)


def paste(base: np.ndarray, art_img: Image.Image, blend: str, cx: float, cy: float) -> None:
    art = np.array(art_img).astype(float)
    h, w = art.shape[:2]
    oy, ox = int(round(cy - h / 2)), int(round(cx - w / 2))
    oy, ox = max(2, min(N - 2 - h, oy)), max(2, min(N - 2 - w, ox))
    a = art[..., 3:4] / 255.0
    solid = a[..., 0] > 0.35
    sm = Image.fromarray((solid * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
    ring = (np.array(sm) > 0) & ~solid
    region = base[oy:oy + h, ox:ox + w]
    region[ring, :3] = region[ring, :3] * 0.35 + np.array(OUTLINE) * 0.65
    if blend == 'add':
        region[..., :3] = np.minimum(255, region[..., :3] + art[..., :3] * a * 1.1)
        region[solid, :3] = region[solid, :3] * 0.3 + art[solid, :3] * 0.7
    else:
        region[..., :3] = region[..., :3] * (1 - a) + art[..., :3] * a
    base[oy:oy + h, ox:ox + w] = region


# Ícones de lâmina montados em camadas (efeito + facão), os demais só com o efeito.
LAYOUTS = {
    'blade_firm_strike': [('fx', 'blade_firm_strike_slash', 'add', 22, 19, 13), ('w', 'machete', 'mix', 18, 12, 20)],
    'blade_clearing_sweep': [('fx', 'blade_clearing_sweep_arc', 'add', 26, 16, 13), ('w', 'machete', 'mix', 15, 16, 22)],
    'blade_horizon_cut': [('fx', 'blade_horizon_cut_wave', 'add', 27, 16, 20), ('w', 'machete', 'mix', 16, 11, 11)],
    'blade_steel_spin': [('fx', 'blade_steel_spin_whirl', 'add', 26, 16, 16), ('w', 'machete', 'mix', 15, 16, 16)],
    'blade_iron_stance': [('fx', 'blade_iron_stance_glow', 'add', 26, 16, 16), ('piece', 'blade_iron_stance_front', 'mix', 22, 16, 16)],
}


def frame_of(sheet: str, idx: int) -> Image.Image:
    im = Image.open(os.path.join(FX, sheet + '.png')).convert('RGBA')
    fh = im.height
    w = SHEET_W.get(sheet, fh)
    n = im.width // w
    idx = idx % n
    return im.crop((idx * w, 0, (idx + 1) * w, fh))


def sprite_img(spr) -> Image.Image:
    return Image.fromarray(spr.a, 'RGBA')


def compose(skill: str, sheet: str, blend: str) -> Image.Image:
    school = skill.split('_')[0]
    base = plate(school)
    for layer_ in LAYOUTS.get(skill, [('fx', sheet, blend, ART_PX, 16, 16)]):
        kind, src, bl, px, cx, cy = layer_[:6]
        if kind == 'w':
            img = weapon(src, px)
        elif kind == 'piece':
            img = fit(biggest_piece(best_frame(src)), px)
        elif kind == 'spr':  # sprite desenhado a mao (fxsabia), em pixel nativo; px = escala inteira
            img = sprite_img(src() if callable(src) else src)
            if px != 1:
                img = img.resize((img.width * px, img.height * px), Image.NEAREST)
            if max(img.width, img.height) > N - 4:  # sprite maior que a placa: reduz para caber
                img = fit(img, N - 4)
        elif kind == 'fxf':  # quadro escolhido (layer_[6]) da folha
            img = fit(frame_of(src, layer_[6]), px)
        elif kind == 'draw':  # desenho proprio do icone (funcao -> Image)
            img = src()
        elif kind == 'fpiece':  # maior peca do quadro escolhido
            img = fit(biggest_piece(frame_of(src, layer_[6])), px)
        else:
            img = fit(best_frame(src), px)
        paste(base, img, bl, cx, cy)
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), 'RGBA')


# ------------------------------------------------------------------ Terra do Sabia v0.4 (68 skills novas)
import sys  # noqa: E402

sys.path.insert(0, HERE)
import fxsabia as SB  # noqa: E402

# largura do quadro das folhas que nao sao quadradas (flechas, projeteis, laco das bandeirinhas...)
SHEET_W = {}


def _load_sheet_widths():
    import re
    tab = open(os.path.join(GAME, 'scripts', 'client', 'combat', 'skill_fx_sheets.gd'), encoding='utf-8').read()
    for m in re.finditer(r'&"([a-z0-9_]+)": \{"frames": (\d+), "size": Vector2i\((\d+), (\d+)\)', tab):
        SHEET_W[m.group(1)] = int(m.group(3))


def _s(txt, pal, line='#1a120c'):
    return lambda: SB.spr(txt, pal, line)


A_GREEN = lambda: SB.arrow()  # noqa: E731
A_RED = lambda: SB.arrow(fletch=("#f07a5a", "#b4201c"), ribbon="#fff4e0")  # noqa: E731
A_WHITE = lambda: SB.arrow(fletch=("#fffcf0", "#c8c0b0"), head=("#ffffff", "#e6b43a"), ribbon="#e6b43a")  # noqa: E731
A_THORN = lambda: SB.arrow(fletch=("#a6d86a", "#2f6b3e"), head=("#c9a8ec", "#5a3a8c"), ribbon="#5a3a8c",  # noqa: E731
                           shaft=("#8cc860", "#3e7a34"))


def _rot(fn, deg):
    return lambda: fn().rot(deg)


def _crop(fn, x0, x1):
    """Parte do sprite (flecha longa demais para 28 px: fica a ponta e as penas encostadas)."""
    def f():
        a = fn().a
        keep = np.concatenate([a[:, :x0], a[:, x1:]], axis=1)
        return SB.Spr(keep.copy())
    return f


SHORT_ARROW = _crop(A_GREEN, 16, 30)
SHORT_RED = _crop(A_RED, 16, 30)
SHORT_WHITE = _crop(A_WHITE, 16, 30)
SHORT_THORN = _crop(A_THORN, 16, 30)
DROP_SAP = lambda: SB.drop("#fae58c", "#f0b640", "#c8801e").outlined("#3a2408")  # noqa: E731
DROP_BLOOD = lambda: SB.drop("#f07a5a", "#c83228", "#6e1010").outlined("#220404")  # noqa: E731
DROP_DEW = lambda: SB.drop("#e0f8b0", "#8ccc5a", "#3e8a3c").outlined("#12261a")  # noqa: E731
DROP_MP = lambda: SB.drop("#d2e8ff", "#84b8f6", "#3a78de").outlined("#0c1c48")  # noqa: E731
FEATHER_GOLD = lambda: SB.feather(SB.FEATHER_GOLD)  # noqa: E731
FEATHER_DARK = lambda: SB.feather(SB.FEATHER_DARK)  # noqa: E731
LEAFLET = _s(SB.LEAFLET_TXT, SB.LEAFLET_PAL, '#12261a')
FLAG = lambda c: (lambda: SB.flag(c))  # noqa: E731

LAYOUTS.update({
    # Facao Firme / Aroeira / Onca
    'blade_sharpen': [('spr', _rot(_s(SB.MACHETE_TXT, SB.MACHETE_PAL), 40), 'mix', 1, 17, 15),
                      ('spr', _s(SB.WHET_TXT, SB.WHET_PAL), 'mix', 1, 11, 24), ('fx', 'status_aura_crit', 'add', 10, 23, 9)],
    'blade_aroeira_reply': [('fxf', 'blade_aroeira_reply_guard', 'mix', 27, 16, 16, 0)],
    'blade_root_grip': [('fxf', 'blade_root_grip_roots', 'mix', 27, 16, 16, 5)],
    'blade_thick_bark': [('fxf', 'blade_thick_bark_back', 'mix', 26, 16, 16, 0)],
    'blade_trunk_call': [('fxf', 'blade_trunk_call_trunk', 'mix', 26, 13, 17, 4),
                         ('spr', _s(SB.TAUNT_TXT, SB.TAUNT_PAL), 'mix', 1, 23, 9)],
    'blade_jaguar_leap': [('spr', _s(SB.JAGUAR_TXT, SB.JAGUAR_PAL, '#1a0e06'), 'mix', 1, 16, 17)],
    'blade_claw_rake': [('fxf', 'blade_claw_rake_claws', 'add', 27, 16, 16, 5)],
    'blade_blood_scent': [('fxf', 'blade_blood_scent_eyes', 'mix', 28, 16, 16, 1)],
    'blade_jaguar_roar': [('spr', lambda: __import__('fx_melee').spr(__import__('fx_melee').JAG_HEAD_TXT,
                                                                    __import__('fx_melee').JAG_HEAD_PAL, '#1a0e06'),
                           'mix', 1, 16, 16)],
    # Vaga-lume / Cristal / Boitata
    'arcane_firefly_swarm': [('fx', 'arcane_firefly_swarm_bug', 'add', 13, 10, 10), ('fx', 'arcane_firefly_swarm_bug', 'add', 13, 22, 13),
                             ('fx', 'arcane_firefly_swarm_bug', 'add', 13, 13, 23)],
    'arcane_shared_crystal': [('fxf', 'arcane_shared_crystal_front', 'mix', 12, 9, 12, 2), ('fxf', 'arcane_shared_crystal_front', 'mix', 12, 23, 12, 2),
                              ('fxf', 'arcane_shared_crystal_front', 'mix', 13, 16, 22, 2)],
    'arcane_crystal_prison': [('fxf', 'arcane_crystal_prison_back', 'mix', 27, 16, 16, 7), ('fxf', 'arcane_crystal_prison_front', 'mix', 27, 16, 19, 7)],
    'arcane_crystal_wall': [('fxf', 'arcane_crystal_wall_spike', 'mix', 27, 16, 16, 3)],
    'arcane_crystal_glow': [('fxf', 'arcane_crystal_glow_gem', 'mix', 27, 16, 16, 0)],
    'arcane_star_step': [('fxf', 'arcane_star_step_out', 'add', 27, 16, 16, 3)],
    'arcane_fire_gaze': [('spr', _s(SB.SERPENT_EYE_TXT, SB.SERPENT_EYE_PAL, '#2a0806'), 'mix', 1, 16, 11),
                         ('fx', 'arcane_fire_gaze_beam', 'add', 14, 16, 24)],
    'arcane_fire_serpent': [('fxf', 'arcane_fire_serpent_head', 'add', 28, 16, 16, 2)],
    'arcane_ember_eyes': [('fxf', 'arcane_ember_eyes_glow', 'add', 26, 16, 16, 0)],
    # Flecha do Cerrado / Tocaia do Brejo / Gaviao-Real
    'bow_low_shot': [('fxf', 'bow_low_shot_skim', 'mix', 14, 10, 23, 2), ('spr', SHORT_ARROW, 'mix', 1, 16, 21)],
    'bow_double_arrow': [('spr', _rot(SHORT_ARROW, 35), 'mix', 1, 13, 13), ('spr', _rot(SHORT_ARROW, 35), 'mix', 1, 20, 20)],
    'bow_taut_draw': [('fxf', 'bow_taut_draw_charge', 'mix', 28, 16, 16, 2), ('spr', SHORT_ARROW, 'mix', 1, 16, 16)],
    'bow_warning_arrow': [('spr', _rot(SHORT_RED, 40), 'mix', 1, 16, 16), ('fxf', 'status_mark_vuln', 'mix', 12, 23, 7, 0)],
    'bow_arrow_flock': [('spr', _rot(SHORT_ARROW, -90), 'mix', 1, 9, 15), ('spr', _rot(SHORT_ARROW, -90), 'mix', 1, 16, 12),
                        ('spr', _rot(SHORT_ARROW, -90), 'mix', 1, 23, 16)],
    'bow_mud_skin': [('fxf', 'bow_mud_skin_splash', 'mix', 27, 16, 16, 4)],
    'bow_mud_hide': [('fxf', 'bow_mud_hide_mud', 'mix', 27, 16, 17, 5)],
    'bow_ambush_shot': [('fxf', 'bow_ambush_shot_reeds', 'mix', 27, 16, 16, 5), ('spr', _rot(SHORT_ARROW, 20), 'mix', 1, 17, 14)],
    'bow_vine_snare': [('fxf', 'bow_vine_snare_trap', 'mix', 27, 16, 16, 2)],
    'bow_thorn_arrow': [('spr', _rot(SHORT_THORN, 40), 'mix', 1, 15, 15),
                        ('spr', lambda: SB.drop("#c9a8ec", "#8e66c4", "#5a3a8c").outlined("#140c1e"), 'mix', 1, 23, 23)],
    'bow_still_eye': [('spr', _s(SB.HAWK_EYE_TXT, SB.HAWK_EYE_PAL, '#1a1418'), 'mix', 1, 16, 16)],
    'bow_true_arrow': [('fxf', 'bow_true_arrow_pierce', 'mix', 28, 16, 16, 2), ('spr', SHORT_WHITE, 'mix', 1, 15, 16)],
    'bow_sure_aim': [('spr', _rot(FEATHER_GOLD, 30), 'mix', 1, 9, 15), ('spr', FEATHER_GOLD, 'mix', 1, 16, 13),
                     ('spr', _rot(FEATHER_GOLD, -30), 'mix', 1, 23, 15)],
    'bow_hawk_dive': [('spr', _s(SB.HAWK_TXT, SB.HAWK_PAL, '#120e14'), 'mix', 1, 16, 16)],
    'bow_short_flight': [('fxf', 'bow_short_flight_wings', 'mix', 28, 16, 16, 3)],
    # Brasa no Facao
    'hybrid_spark_blade': [('fxf', 'hybrid_spark_blade_edge', 'mix', 27, 16, 16, 0)],
    'hybrid_ember_cut': [('fxf', 'hybrid_ember_cut_slash', 'add', 27, 16, 16, 3)],
    'hybrid_steel_spark': [('fxf', 'hybrid_steel_spark_impact', 'add', 22, 19, 13, 1),
                           ('spr', _rot(_s(SB.MACHETE_TXT, SB.MACHETE_PAL), 35), 'mix', 1, 12, 20)],
    'hybrid_sparks': [('spr', _s(SB.ANVIL_TXT, SB.ANVIL_PAL, '#120e14'), 'mix', 1, 16, 22), ('fxf', 'hybrid_sparks_anvil', 'mix', 26, 16, 14, 4)],
    'hybrid_ember_heart': [('fxf', 'hybrid_ember_heart_core', 'mix', 22, 16, 17, 0)],
    # Raiz do Cerrado / Seiva do Buriti / Assobio da Matinta
    'support_bottle_brew': [('spr', _s(SB.BOTTLE_TXT, SB.BOTTLE_PAL, '#12261a'), 'mix', 1, 16, 15)],
    'support_herb_tea': [('fxf', 'support_herb_tea_cup', 'mix', 27, 16, 15, 3)],
    'support_poultice': [('fxf', 'support_poultice_wrap', 'mix', 27, 16, 16, 6)],
    'support_pequi_shade': [('fxf', 'support_pequi_shade_tree', 'mix', 28, 16, 16, 0)],
    'support_mutirao': [('fxf', 'support_mutirao_flags', 'mix', 28, 16, 15, 0)],
    'support_broadleaf_tea': [('spr', lambda: SB.leaf(), 'mix', 1, 13, 14), ('spr', DROP_DEW, 'mix', 1, 22, 21),
                              ('spr', DROP_DEW, 'mix', 1, 17, 25)],
    'support_coconut_water': [('spr', _s(SB.COCO_TXT, SB.COCO_PAL, '#12261a'), 'mix', 1, 16, 16)],
    'support_running_sap': [('spr', DROP_SAP, 'mix', 1, 10, 11), ('spr', DROP_SAP, 'mix', 1, 17, 17), ('spr', DROP_SAP, 'mix', 1, 23, 10),
                            ('fxf', 'support_running_sap_flow', 'mix', 20, 16, 16, 2)],
    'support_holding_root': [('fxf', 'support_holding_root_front', 'mix', 27, 16, 17, 0),
                             ('fxf', 'support_holding_root_back', 'mix', 27, 16, 17, 0)],
    'support_new_breath': [('fxf', 'support_new_breath_wind', 'mix', 28, 16, 16, 6)],
    'support_ill_whistle': [('fxf', 'support_ill_whistle_cone', 'mix', 28, 16, 16, 4)],
    'support_omen': [('spr', _s(SB.BIRD_UP, SB.BIRD_PAL, '#0a0610'), 'mix', 1, 16, 13), ('spr', _rot(FEATHER_DARK, 60), 'mix', 1, 22, 23)],
    'support_owl_cry': [('spr', _s(SB.OWL_TXT, SB.OWL_PAL, '#1a1418'), 'mix', 1, 16, 16)],
    'support_bird_lime': [('fxf', 'support_bird_lime_glue', 'mix', 26, 16, 18, 0)],
    'support_bitter_smoke': [('fxf', 'support_bitter_smoke_cloud', 'mix', 27, 16, 16, 0)],
    # Casco de Jabuti / Couro de Anta / Furia do Mapinguari
    'tank_shell_knock': [('spr', _s(SB.SHELL_TXT, SB.SHELL_PAL, '#120c04'), 'mix', 1, 16, 19),
                         ('fxf', 'tank_shell_knock_shell', 'mix', 28, 16, 12, 3)],
    'tank_shell_retreat': [('fxf', 'tank_shell_retreat_dome', 'mix', 27, 16, 16, 7)],
    'tank_hard_shell': [('fxf', 'tank_hard_shell_back', 'mix', 26, 16, 16, 1)],
    'tank_patience': [('fxf', 'tank_patience_jabuti', 'mix', 26, 16, 18, 0)],
    'tank_shell_bash': [('fxf', 'tank_shell_bash_cone', 'mix', 28, 16, 16, 3)],
    'tank_thick_hide': [('fxf', 'tank_thick_hide_back', 'mix', 26, 16, 16, 0)],
    'tank_tapir_stomp': [('fxf', 'tank_tapir_stomp_print', 'mix', 27, 16, 16, 4)],
    'tank_tapir_ram': [('spr', _s(SB.TAPIR_TXT, SB.TAPIR_PAL, '#0e0a0a'), 'mix', 1, 16, 17)],
    'tank_living_wall': [('fxf', 'tank_living_wall_stake', 'mix', 26, 16, 16, 3)],
    'tank_stand_firm': [('fxf', 'tank_stand_firm_stones', 'mix', 28, 16, 18, 3)],
    'tank_fury': [('fxf', 'tank_fury_rage', 'mix', 27, 16, 16, 0)],
    'tank_mapinguari_howl': [('spr', _s(SB.MOUTH_TXT, SB.MOUTH_PAL, '#120202'), 'mix', 1, 16, 16)],
    'tank_heavy_claws': [('fxf', 'tank_heavy_claws_rend', 'mix', 28, 16, 16, 2)],
    'tank_battle_thirst': [('spr', DROP_BLOOD, 'mix', 1, 10, 12), ('spr', DROP_BLOOD, 'mix', 1, 22, 11), ('spr', DROP_BLOOD, 'mix', 1, 16, 21),
                           ('fxf', 'status_aura_lifesteal', 'mix', 22, 16, 16, 3)],
    'tank_last_blow': [('fxf', 'tank_last_blow_smash', 'mix', 28, 16, 16, 5)],
})
# ------------------------------------------------------------------ desenhos proprios de alguns icones
from fxdraw import Canvas as _Cv, Frame as _Fr, blit as _blit, layer as _layer  # noqa: E402


def _ember_gash():
    """Corte em Brasa: talho reto em brasa na diagonal, com linguinhas de fogo saindo dele."""
    fr = _Fr(28)
    cv = _Cv(28)
    cv.stroke([(4, 23), (14, 13), (24, 4)], [1.0, 5.0, 1.0], [0.55, 0.62, 0.55])
    cv.stroke([(5, 22), (14, 13), (23, 5)], [0.4, 2.0, 0.4], [1.0, 1.0, 1.0])
    for (x, y) in ((9, 18), (15, 12), (20, 7)):
        cv.spike(x, y, -2.0, 0, 7, 3, 0.7)
    cv.glow(1.2, 0.9, 0.2)
    fr.paint_canvas(cv, SB.EMBER_G)
    return fr.image()


def _flags():
    """Mutirao: cordao de bandeirinhas de festa caindo em curva."""
    fr = _Fr(28, 18)
    for i in range(29):
        y = 3 + (1 - ((i - 14) / 14) ** 2) * 4
        fr.px(i, int(y), '#6b4226')
    for k, c in enumerate(['#e8483a', '#fae58c', '#5aa048', '#5a90e0']):
        x = 3 + k * 7
        y = 3 + (1 - (((x + 3) - 14) / 14) ** 2) * 4
        _blit(fr, SB.flag(c), x + 3, y, (0.5, 0.0))
    return fr.image().resize((28 * 1, 18 * 1), Image.NEAREST)


def _big_drops():
    fr = _Fr(28)
    d = SB.drop("#fae58c", "#f0b640", "#c8801e").outlined("#3a2408").scale(2)
    for (x, y) in ((8, 9), (19, 13), (11, 21)):
        _blit(fr, d, x, y)
    return fr.image()


def _scute_fan():
    """Empurrao de Casco: uma placa grande de casco (hexagono) empurrando para a direita, com tracos de
    velocidade atras e poeira na frente."""
    import fx_status as FS
    fr = _Fr(28)
    sc = SB.spr(FS.SCUTE_TXT, {"a": "#ecc070", "b": "#c08a3a", "c": "#8a5a22"}, "#221406").scale(2)
    for i, y in enumerate((8, 14, 20)):
        for x in range(1, 8 - (i % 2) * 2):
            fr.px(x, y, '#e0aa4a' if x % 2 else '#b07a2e')
    _blit(fr, sc, 16, 14)
    for (x, y) in ((25, 9), (26, 14), (25, 19), (24, 23)):
        fr.px(x, y, '#eee2c4')
        fr.px(x + 1, y, '#b8a080')
    return fr.image()


def _ember_eyes():
    fr = _Fr(28)
    eye = SB.spr(""".oooo..
oyYYyo.
oyykyyo
.oykyo.
..ooo..""", {"o": "#8c1e12", "y": "#f4842a", "Y": "#fff4c8", "k": "#1a0806"}, "#2a0806").scale(2)
    _blit(fr, eye, 8, 16)
    _blit(fr, eye.flip(), 20, 16)
    for sd, x0 in ((-1, 2), (1, 26)):
        for i in range(4):
            fr.px(x0 - sd * i, 13 - i, '#fcc84a' if i < 2 else '#d2421e')
    return fr.image()


def _eyes_jaguar():
    fr = _Fr(28)
    e = SB.spr(SB.JAG_EYES_TXT, SB.JAG_EYES_PAL, '#1a0806')
    _blit(fr, e, 14, 12)
    for k in range(3):  # fiapos vermelhos do cheiro
        for i in range(8):
            fr.px(4 + i * 2 + k, 20 + k * 2 + (1 if (i + k) % 3 == 0 else 0), '#e8483a' if i % 3 else '#6e1010')
    return fr.image()


def _patience():
    import fx_tank as FT
    fr = _Fr(28)
    jb = SB.spr(FT.JABUTI_TXT, {"s": "#2a1c0a", "P": "#9c7a3a", "l": "#e0bc6a", "B": "#c8a050", "h": "#8a8a5a",
                                "H": "#6a6a3a", "k": "#1a1418"}, "#120c04")
    lf = SB.spr(SB.LEAFLET_TXT, SB.LEAFLET_PAL, '#12261a')
    _blit(fr, lf, 6, 8)
    _blit(fr, lf.rot(-30), 22, 6)
    _blit(fr, jb, 14, 20)
    return fr.image()


def _poultice():
    fr = _Fr(28)
    lf = SB.leaf()
    _blit(fr, lf.rot(35), 10, 14)
    _blit(fr, lf.rot(-35), 18, 14)
    for x in range(6, 23):  # tira de pano amarrando as folhas
        fr.px(x, 18, '#f4f0dc')
        fr.px(x, 19, '#c8c0b0')
    return fr.image()


def _wood_slice():
    """Casca Grossa: fatia de tronco com a casca bem grossa em volta e os aneis por dentro."""
    fr = _Fr(28)
    cv = _Cv(28)
    cv.ellipse(14, 14, 12, 11, 0.5)
    _layer(fr, cv, __import__('fx_melee').BARK, __import__('fx_melee').BARK_LINE)
    iv = _Cv(28)
    iv.ellipse(14, 14, 8, 7.4, 0.62)
    _layer(fr, iv, SB.WOOD, None)
    for r_ in (2.2, 4.4, 6.4):
        for k in range(24):
            import math as _m
            a = k * _m.tau / 24
            fr.px(int(14 + _m.cos(a) * r_), int(14 + _m.sin(a) * r_ * 0.92), '#6b4226')
    for (x, y) in ((3, 9), (24, 18), (8, 24)):
        fr.px(x, y, '#5aa048')
        fr.px(x + 1, y, '#a6d86a')
    return fr.image()


def _mud_skin():
    """Pele de Barro: lama escorrendo de cima em gotas grossas, com respingos."""
    fr = _Fr(28)
    cv = _Cv(28)
    cv.stroke([(2, 4), (26, 4)], [5, 5], [0.55, 0.55])
    for (x, ln) in ((6, 14), (12, 9), (18, 17), (23, 11)):
        cv.stroke([(x, 4), (x, 4 + ln)], [4.0, 2.6], [0.55, 0.55])
        cv.circle(x, 5 + ln, 2.6, 0.7)
    for (x, y) in ((4, 24), (15, 25), (24, 23)):
        cv.circle(x, y, 1.8, 0.8)
    _layer(fr, cv, SB.MUD, SB.MUD_LINE)
    return fr.image()


LAYOUTS.update({
    'blade_thick_bark': [('draw', _wood_slice, 'mix', 0, 16, 16)],
    'bow_mud_skin': [('draw', _mud_skin, 'mix', 0, 16, 16)],
    'blade_blood_scent': [('draw', _eyes_jaguar, 'mix', 0, 16, 16)],
    'arcane_shared_crystal': [('fpiece', 'arcane_crystal_prison_front', 'mix', 12, 9, 13, 7),
                              ('fpiece', 'arcane_crystal_prison_front', 'mix', 12, 23, 13, 7),
                              ('fpiece', 'arcane_crystal_prison_front', 'mix', 14, 16, 21, 7)],
    'arcane_crystal_glow': [('fpiece', 'arcane_crystal_glow_gem', 'mix', 18, 16, 12, 0), ('spr', DROP_MP, 'mix', 1, 10, 24),
                            ('spr', DROP_MP, 'mix', 1, 22, 24)],
    'arcane_ember_eyes': [('draw', _ember_eyes, 'add', 0, 16, 16)],
    'support_poultice': [('draw', _poultice, 'mix', 0, 16, 16)],
    'support_pequi_shade': [('fpiece', 'support_pequi_shade_tree', 'mix', 28, 16, 16, 0)],
    'support_mutirao': [('draw', _flags, 'mix', 0, 16, 16)],
    'support_running_sap': [('draw', _big_drops, 'mix', 0, 16, 16)],
    'tank_patience': [('draw', _patience, 'mix', 0, 16, 16)],
    'tank_shell_bash': [('draw', _scute_fan, 'mix', 0, 16, 16)],
    'hybrid_ember_heart': [('fpiece', 'hybrid_ember_heart_core', 'mix', 22, 16, 16, 0)],
    'hybrid_ember_cut': [('draw', _ember_gash, 'add', 0, 16, 16)],
})

NEW_SKILLS = [k for k in LAYOUTS if k.split('_')[0] in ('bow', 'support', 'tank', 'hybrid')
              or k in ('blade_sharpen', 'blade_aroeira_reply', 'blade_root_grip', 'blade_thick_bark', 'blade_trunk_call',
                       'blade_jaguar_leap', 'blade_claw_rake', 'blade_blood_scent', 'blade_jaguar_roar',
                       'arcane_firefly_swarm', 'arcane_shared_crystal', 'arcane_crystal_prison', 'arcane_crystal_wall',
                       'arcane_crystal_glow', 'arcane_star_step', 'arcane_fire_gaze', 'arcane_fire_serpent',
                       'arcane_ember_eyes')]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    _load_sheet_widths()
    for skill in NEW_SKILLS:
        PICKS.setdefault(skill, ('', 'mix'))
    for skill, (sheet, blend) in PICKS.items():
        p = os.path.join(OUT, skill + '.png')
        compose(skill, sheet, blend).save(p)
        print('ok', os.path.relpath(p, GAME))


if __name__ == '__main__':
    main()
