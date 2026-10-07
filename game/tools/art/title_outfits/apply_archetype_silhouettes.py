#!/usr/bin/env python3
"""Aplica diferenciacao de silhuetas e texturas para os 4 arquetipos principais
nas roupas de titulos em game/assets/characters/outfits/:
  1. Tanque: Armadura pesada de carapaca/placas, ombreiras volumosas.
  2. Agil / Lamina: Gibao de couro batido, cinturoes cruzados e faixas de tecido leve.
  3. Arcano: Tunicas longas, mangas amplas de tecido refinado com bordados misticos.
  4. Xamanico / Selvagem: Mantos com detalhes de peles rusticas e penas.
"""
import glob
import os
import sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
OUTFITS_DIR = os.path.join(GAME, 'assets', 'characters', 'outfits')

# Color constants
OUTLINE_DARK = np.array([28, 24, 20, 255], dtype=np.uint8)

# Tank colors (Carapace / Plates)
TANK_OUTLINE = np.array([26, 22, 18, 255], dtype=np.uint8)
TANK_PLATE_DARK = np.array([65, 60, 48, 255], dtype=np.uint8)
TANK_PLATE_MID = np.array([112, 102, 76, 255], dtype=np.uint8)
TANK_PLATE_LIGHT = np.array([172, 156, 116, 255], dtype=np.uint8)
TANK_GOLD = np.array([214, 172, 68, 255], dtype=np.uint8)

# Agile colors (Leather / Sash)
AGILE_LEATHER_DARK = np.array([48, 24, 16, 255], dtype=np.uint8)
AGILE_LEATHER_MID = np.array([96, 52, 32, 255], dtype=np.uint8)
AGILE_BRASS = np.array([224, 172, 56, 255], dtype=np.uint8)
AGILE_SASH_OUT = np.array([32, 48, 36, 255], dtype=np.uint8)
AGILE_SASH_MID = np.array([76, 152, 116, 255], dtype=np.uint8)
AGILE_SASH_LIGHT = np.array([120, 192, 156, 255], dtype=np.uint8)

# Arcane colors (Robe / Mystical embroidery)
ARCANE_ROBE_OUT = np.array([20, 16, 42, 255], dtype=np.uint8)
ARCANE_ROBE_DARK = np.array([46, 34, 86, 255], dtype=np.uint8)
ARCANE_ROBE_MID = np.array([76, 58, 134, 255], dtype=np.uint8)
ARCANE_ROBE_LIGHT = np.array([112, 90, 184, 255], dtype=np.uint8)
ARCANE_RUNIC_GLOW = np.array([140, 220, 240, 255], dtype=np.uint8)
ARCANE_GOLD_TRIM = np.array([235, 185, 60, 255], dtype=np.uint8)

# Shamanic colors (Fur / Feathers)
SHAMAN_FUR_OUT = np.array([32, 20, 16, 255], dtype=np.uint8)
SHAMAN_FUR_DARK = np.array([72, 42, 28, 255], dtype=np.uint8)
SHAMAN_FUR_MID = np.array([124, 76, 44, 255], dtype=np.uint8)
SHAMAN_FUR_LIGHT = np.array([184, 128, 72, 255], dtype=np.uint8)
SHAMAN_FEATHER_PALE = np.array([238, 234, 222, 255], dtype=np.uint8)
SHAMAN_FEATHER_TIP = np.array([54, 38, 48, 255], dtype=np.uint8)


def detect_zones(frame, mask):
    """Detecta as zonas anatomicas de forma dinamica e segura em qualquer pose."""
    alpha = frame[..., 3] > 40
    if not alpha.any():
        return None
    ys, xs = np.where(alpha)
    y_min, y_max = ys.min(), ys.max()
    h = y_max - y_min + 1

    # Head cutoff: upper 45% of character height
    head_cutoff = y_min + int(h * 0.45)
    # Head pixels: where alpha is low or skin (ch 0) / hair (ch 2) are present
    head_sub = mask[:head_cutoff, :, :]
    head_mask = ((head_sub[..., 3] > 0) & (head_sub[..., 3] < 191)) | (head_sub[..., 0] > 5) | (head_sub[..., 2] > 5)
    head_ys = np.where(head_mask)[0]
    head_bottom = head_ys.max() if len(head_ys) > 0 else y_min + int(h * 0.35)

    sh_y0 = head_bottom + 1
    sh_y1 = min(y_max, head_bottom + int(h * 0.14) + 1)
    torso_y0 = sh_y1 + 1
    torso_y1 = min(y_max, head_bottom + int(h * 0.32) + 1)
    lower_y0 = torso_y1 + 1
    lower_y1 = max(lower_y0, y_max - 2)

    return {
        'y_min': y_min, 'y_max': y_max,
        'head_bottom': head_bottom,
        'sh_y0': sh_y0, 'sh_y1': sh_y1,
        'torso_y0': torso_y0, 'torso_y1': torso_y1,
        'lower_y0': lower_y0, 'lower_y1': lower_y1
    }


def enhance_tank(frame, mask, z, direction):
    """Tanque: Armadura pesada de carapaca/placas, ombreiras volumosas."""
    res = frame.copy()
    m_res = mask.copy()

    # 1. Ombreiras volumosas nos ombros
    for y in range(z['sh_y0'], z['sh_y1'] + 1):
        if y >= 96:
            break
        xs = np.where(frame[y, :, 3] > 50)[0]
        if len(xs) < 8:
            continue
        xl, xr = xs.min(), xs.max()
        mid_y = (z['sh_y0'] + z['sh_y1']) // 2
        dy = abs(y - mid_y)
        bulge = max(1, 3 - dy // 2)

        # In S, SE, NE, N: both shoulders or dominant shoulder get heavy pauldrons
        for dx in range(1, bulge + 1):
            px_l = xl - dx
            if 0 <= px_l < 96:
                if dx == bulge:
                    res[y, px_l] = TANK_OUTLINE
                elif y == z['sh_y0'] or dx >= bulge - 1:
                    res[y, px_l] = TANK_PLATE_LIGHT
                elif y >= mid_y + 1:
                    res[y, px_l] = TANK_PLATE_DARK
                else:
                    res[y, px_l] = TANK_PLATE_MID
                m_res[y, px_l] = [0, 0, 0, 255]

            px_r = xr + dx
            if 0 <= px_r < 96:
                if dx == bulge:
                    res[y, px_r] = TANK_OUTLINE
                elif y == z['sh_y0'] or dx >= bulge - 1:
                    res[y, px_r] = TANK_PLATE_LIGHT
                elif y >= mid_y + 1:
                    res[y, px_r] = TANK_PLATE_DARK
                else:
                    res[y, px_r] = TANK_PLATE_MID
                m_res[y, px_r] = [0, 0, 0, 255]

    # Gold accent / rivet on the pauldron crest
    crest_y = min(95, z['sh_y0'] + 2)
    xs_crest = np.where(res[crest_y, :, 3] > 50)[0]
    if len(xs_crest) > 12:
        for p in [xs_crest.min() + 1, xs_crest.max() - 1]:
            if 0 <= p < 96:
                res[crest_y, p] = TANK_GOLD

    # 2. Peitoral / Carapaca pesada
    for y in range(z['torso_y0'], z['torso_y1'] + 1, 4):
        if y >= 96:
            break
        xs = np.where(frame[y, :, 3] > 50)[0]
        if len(xs) > 10:
            xl, xr = xs[len(xs) // 4], xs[3 * len(xs) // 4]
            for x in range(xl, xr + 1):
                if mask[y, x, 0] <= 5: # non-skin
                    res[y, x] = TANK_PLATE_DARK
                    if y - 1 >= 0 and mask[y - 1, x, 0] <= 5:
                        res[y - 1, x] = TANK_PLATE_LIGHT

    # 3. Grevas pesadas nas pernas
    for y in range(z['lower_y0'] + 3, z['lower_y1']):
        if y >= 96:
            break
        xs = np.where(frame[y, :, 3] > 50)[0]
        if len(xs) > 6:
            xl, xr = xs.min(), xs.max()
            if xl - 1 >= 0 and frame[y, xl, 3] > 50:
                res[y, xl - 1] = TANK_OUTLINE
                res[y, xl] = TANK_PLATE_MID
                m_res[y, xl - 1] = [0, 0, 0, 255]
            if xr + 1 < 96 and frame[y, xr, 3] > 50:
                res[y, xr + 1] = TANK_OUTLINE
                res[y, xr] = TANK_PLATE_MID
                m_res[y, xr + 1] = [0, 0, 0, 255]

    return res, m_res


def enhance_agile(frame, mask, z, direction):
    """Agil / Lamina: Gibao de couro batido, cinturoes cruzados e faixas de tecido leve."""
    res = frame.copy()
    m_res = mask.copy()

    # 1. Cinturoes cruzados no peito
    t_y0, t_y1 = z['sh_y1'], z['torso_y1']
    xs_top = np.where(frame[t_y0, :, 3] > 50)[0] if t_y0 < 96 else []
    xs_bot = np.where(frame[t_y1, :, 3] > 50)[0] if t_y1 < 96 else []
    if len(xs_top) > 8 and len(xs_bot) > 8:
        l_top, r_top = xs_top[len(xs_top) // 4], xs_top[3 * len(xs_top) // 4]
        l_bot, r_bot = xs_bot[len(xs_bot) // 4], xs_bot[3 * len(xs_bot) // 4]
        span = max(1, t_y1 - t_y0)
        for y in range(t_y0, t_y1 + 1):
            if y >= 96:
                break
            t = (y - t_y0) / float(span)
            x1 = int(round(l_top + (r_bot - l_top) * t))
            x2 = int(round(r_top + (l_bot - r_top) * t))
            for x in [x1, x2]:
                if 0 <= x < 96 and mask[y, x, 0] <= 5:
                    res[y, x] = AGILE_LEATHER_DARK
                    if x + 1 < 96 and mask[y, x + 1, 0] <= 5:
                        res[y, x + 1] = AGILE_LEATHER_MID

        # Brass buckle at cross
        mid_y = (t_y0 + t_y1) // 2
        mid_x = (l_top + r_bot) // 2
        if 0 <= mid_x < 95 and 0 <= mid_y < 96:
            res[mid_y, mid_x] = AGILE_BRASS
            res[mid_y, mid_x + 1] = AGILE_BRASS

    # 2. Faixas de tecido leve (Sash tail) no quadril
    w_y = z['torso_y1']
    xs_w = np.where(frame[w_y, :, 3] > 50)[0] if w_y < 96 else []
    if len(xs_w) > 8:
        sash_x0 = xs_w.min()
        sash_len = min(15, z['lower_y1'] - w_y)
        for y in range(w_y, min(95, w_y + sash_len)):
            offset = int(np.sin((y - w_y) * 0.4) * 1.5)
            sx = sash_x0 - 1 + offset
            if 0 <= sx < 94:
                res[y, sx - 1] = AGILE_SASH_OUT
                res[y, sx] = AGILE_SASH_MID
                res[y, sx + 1] = AGILE_SASH_LIGHT
                m_res[y, sx - 1:sx + 2] = [0, 0, 0, 255]
        tip_y = min(95, w_y + sash_len)
        if 0 <= sash_x0 - 1 < 96:
            res[tip_y, sash_x0 - 1] = AGILE_SASH_OUT

    return res, m_res


def enhance_arcane(frame, mask, z, direction):
    """Arcano: Tunicas longas, mangas amplas de tecido refinado com bordados misticos."""
    res = frame.copy()
    m_res = mask.copy()

    # 1. Tunica longa: preenche o vao das pernas e alarga a barra
    r_y0, r_y1 = z['torso_y1'], z['lower_y1']
    for y in range(r_y0, min(95, r_y1 + 1)):
        xs = np.where(frame[y, :, 3] > 50)[0]
        if len(xs) >= 2:
            xl, xr = xs.min(), xs.max()
            flare = int((y - r_y0) * 0.22) # +3..4 px flare
            fl_l = max(0, xl - flare)
            fl_r = min(95, xr + flare)

            for x in range(fl_l, fl_r + 1):
                if x == fl_l or x == fl_r:
                    res[y, x] = ARCANE_ROBE_OUT
                elif y >= r_y1 - 1:
                    res[y, x] = ARCANE_GOLD_TRIM if (x % 3 != 0) else ARCANE_RUNIC_GLOW
                elif x % 7 == 0:
                    res[y, x] = ARCANE_ROBE_DARK
                elif (x + 1) % 7 == 0:
                    res[y, x] = ARCANE_ROBE_LIGHT
                else:
                    res[y, x] = ARCANE_ROBE_MID
                m_res[y, x] = [0, 0, 0, 255] # robe covers legs

    # Central mystic vertical rune stripe
    mid_x = 48
    for y in range(z['sh_y1'] + 2, min(94, r_y1), 3):
        if res[y, mid_x, 3] > 50 and mask[y, mid_x, 0] <= 5:
            res[y, mid_x] = ARCANE_RUNIC_GLOW
            if y + 1 < 96:
                res[y + 1, mid_x] = ARCANE_GOLD_TRIM

    # 2. Mangas amplas nos antebracos
    for y in range(z['torso_y0'], min(95, z['torso_y1'] + 3)):
        xs = np.where(frame[y, :, 3] > 50)[0]
        if len(xs) > 10:
            xl, xr = xs.min(), xs.max()
            for dx in range(1, 3):
                px_l = xl - dx
                if 0 <= px_l < 96:
                    res[y, px_l] = ARCANE_ROBE_OUT if dx == 2 else ARCANE_ROBE_MID
                    m_res[y, px_l] = [0, 0, 0, 255]
                px_r = xr + dx
                if 0 <= px_r < 96:
                    res[y, px_r] = ARCANE_ROBE_OUT if dx == 2 else ARCANE_ROBE_MID
                    m_res[y, px_r] = [0, 0, 0, 255]

    return res, m_res


def enhance_shamanic(frame, mask, z, direction):
    """Xamanico / Selvagem: Mantos com detalhes de peles rusticas e penas."""
    res = frame.copy()
    m_res = mask.copy()

    # 1. Manto de peles rusticas com tufos organicos nos ombros
    for y in range(z['sh_y0'], min(95, z['sh_y1'] + 2)):
        xs = np.where(frame[y, :, 3] > 50)[0]
        if len(xs) < 8:
            continue
        xl, xr = xs.min(), xs.max()
        tuft_l = ((y * 7 + 3) % 4)
        tuft_r = ((y * 11 + 5) % 4)

        for dx in range(1, tuft_l + 1):
            px = xl - dx
            if 0 <= px < 96:
                res[y, px] = SHAMAN_FUR_OUT if dx == tuft_l else (SHAMAN_FUR_LIGHT if (y + dx) % 2 == 0 else SHAMAN_FUR_MID)
                m_res[y, px] = [0, 0, 0, 255]

        for dx in range(1, tuft_r + 1):
            px = xr + dx
            if 0 <= px < 96:
                res[y, px] = SHAMAN_FUR_OUT if dx == tuft_r else (SHAMAN_FUR_LIGHT if (y + dx) % 2 == 0 else SHAMAN_FUR_MID)
                m_res[y, px] = [0, 0, 0, 255]

    # 2. Penas cerimoniais penduradas no peito
    f_y0 = z['sh_y1']
    xs_f = np.where(frame[f_y0, :, 3] > 50)[0] if f_y0 < 96 else []
    if len(xs_f) > 8:
        fx = xs_f.min() + 3
        for fy in range(f_y0, min(95, f_y0 + 9)):
            if 0 <= fx < 95:
                res[fy, fx] = SHAMAN_FEATHER_TIP if fy >= f_y0 + 7 else SHAMAN_FEATHER_PALE
                res[fy, fx + 1] = SHAMAN_FUR_OUT
                if fy >= f_y0 + 2:
                    res[fy, fx + 2] = SHAMAN_FEATHER_TIP if fy >= f_y0 + 7 else SHAMAN_FEATHER_PALE

    # 3. Barra rustica com pontas irregulares
    for y in range(z['lower_y0'], min(95, z['lower_y0'] + 6)):
        xs = np.where(frame[y, :, 3] > 50)[0]
        if len(xs) > 6:
            for x in xs:
                if (x + y) % 3 == 0 and mask[y, x, 0] <= 5:
                    res[y, x] = SHAMAN_FUR_DARK

    return res, m_res


ARCHETYPE_FUNCS = {
    'tank': enhance_tank,
    'agile': enhance_agile,
    'arcane': enhance_arcane,
    'shamanic': enhance_shamanic
}

TITLE_TO_ARCHETYPE = {
    # Tanque
    'title_jabuti': 'tank',
    'title_anta': 'tank',
    'title_mapinguari': 'tank',
    'master_armor': 'tank',
    # Ágil / Lâmina
    'title_machete': 'agile',
    'title_aroeira': 'agile',
    'title_jaguar': 'agile',
    'title_cerrado': 'agile',
    'title_brejo': 'agile',
    'title_gaviao': 'agile',
    'leather_jerkin': 'agile',
    # Arcano
    'title_firefly': 'arcane',
    'title_crystal': 'arcane',
    'title_boitata': 'arcane',
    'title_ember': 'arcane',
    'branch_coat': 'arcane',
    # Xamânico / Selvagem
    'title_root': 'shamanic',
    'title_buriti': 'shamanic',
    'title_matinta': 'shamanic',
}


def limit_colors(sh, maxc=46):
    """Garante que a folha tenha no maximo maxc cores solidas (respeita validate_art.py)."""
    op = sh[..., 3] > 0
    px = sh[op][:, :3].astype(np.int32)
    if len(px) == 0:
        return sh
    cols, inv, cnt = np.unique(px, axis=0, return_inverse=True, return_counts=True)
    if len(cols) <= maxc:
        return sh
    order = np.argsort(-cnt)
    keep = cols[order[:maxc]]
    diff = px[:, None, :] - keep[None, :, :]
    dist = (diff * diff).sum(axis=-1)
    best = np.argmin(dist, axis=1)
    sh[op, :3] = keep[best].astype(np.uint8)
    return sh


def process_sheet(sheet_path, mask_path, archetype):
    """Processa uma folha de sprites completa de 5 linhas e N colunas."""
    func = ARCHETYPE_FUNCS.get(archetype)
    if not func:
        return False
    if not os.path.exists(sheet_path) or not os.path.exists(mask_path):
        return False

    im = Image.open(sheet_path).convert('RGBA')
    mim = Image.open(mask_path).convert('RGBA')
    sh = np.array(im)
    msh = np.array(mim)

    nrows = sh.shape[0] // 96
    ncols = sh.shape[1] // 96

    for r in range(nrows):
        for c in range(ncols):
            frame = sh[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96]
            mframe = msh[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96]
            z = detect_zones(frame, mframe)
            if z is None:
                continue
            new_f, new_m = func(frame, mframe, z, r)
            sh[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96] = new_f
            msh[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96] = new_m

    # Limitar cores para obedecer a regra de 48 cores
    limit_colors(sh, maxc=46)

    # Salva
    Image.fromarray(sh).save(sheet_path)
    Image.fromarray(msh).save(mask_path)
    return True


def run_all():
    print(f"=== Aplicando silhuetas e texturas dos 4 arquétipos em {OUTFITS_DIR} ===")
    total = 0
    for outfit_name, arch in TITLE_TO_ARCHETYPE.items():
        pattern = os.path.join(OUTFITS_DIR, f"chr_*_{outfit_name}_*.png")
        files = [f for f in glob.glob(pattern) if '_mask_' not in f]
        for f in sorted(files):
            # Mask path
            basename = os.path.basename(f)
            # e.g. chr_male_title_jabuti_idle.png -> chr_male_title_jabuti_mask_idle.png
            parts = basename.rsplit('_', 1)
            mask_name = parts[0] + "_mask_" + parts[1]
            mf = os.path.join(OUTFITS_DIR, mask_name)
            if os.path.exists(mf):
                ok = process_sheet(f, mf, arch)
                if ok:
                    total += 1
        print(f"[{arch.upper()}] Processado outfit {outfit_name} ({len(files)} folhas)")
    print(f"Total de {total} folhas aprimoradas com sucesso.")


if __name__ == '__main__':
    run_all()
