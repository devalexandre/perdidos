"""Title outfits / body cosmetics: outfit description -> full-body sheets + mask over the base body.

    python build.py edit <outfit|all> [body ...] [--seed N] [--only-bad]   AI edit of every key pose (Bria)
    python build.py assemble <outfit|all> [body ...]                       sheets + masks + previews + metrics
    python build.py keys                                                   key poses per body (poses.py)

Outfits: outfits.json ({id: {prompt, title}}). See README.md for the whole method.
Work dir: $TITLE_OUTFIT_WORK (default <repo>/.work/title_outfits).
"""
import concurrent.futures as cf
import glob
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import poses as P  # noqa: E402
from head import head_pixels, head_box, skin_table  # noqa: E402
from register import cutout, register, stretch_body  # noqa: E402

GAME = P.GAME
OUT_DIR = os.path.join(GAME, 'assets', 'characters', 'outfits')
WORK = os.environ.get('TITLE_OUTFIT_WORK', os.path.join(GAME, '..', '.work', 'title_outfits'))
OUTFITS = {k: v for k, v in json.load(open(os.path.join(HERE, 'outfits.json'))).items() if not k.startswith('_')}
FR = P.FR
SEEDS = [4242, 777, 31337]
# Key poses whose registered silhouette IoU is under this get another seed (edit --only-bad).
IOU_OK = 0.74
PALETTE = 34
# of those, colors reserved for the head's literal pixels (outline, mouth, ears)
PALETTE_HEAD = 10
# the AI chin may be cut at most this many rows below the base chin
CHIN_MAX = 10
# AI chin this many rows under the base chin: drop the AI head and stretch the AI body to the base chin
STRETCH_MIN = 3
STRETCH_MAX = 16
# rows without skin allowed inside the AI face when finding its chin (eyes, mouth, glasses)
FACE_GAP = 4
# penalty per row of AI chin below the base chin when choosing among seeds
CHIN_W = 0.02
# body_layer: AI pixels allowed outside the base silhouette; poses under IOU_SNAP get snapped to it.
SNAP_FAR = 5
# Weight of the color-design distance when choosing among seeds (IoU - DESIGN_W * L1 of the histograms).
DESIGN_W = 0.3
# Colors of the ground shadow painted in the base sheets (bottom rows).
BASE_SHADOW = [(153, 129, 131), (138, 102, 97), (122, 105, 109)]
IOU_SNAP = 0.66
# a mirrored AI drawing is used only when its silhouette IoU beats the original by this much
MIRROR_GAIN = 0.03
SKIN_DIST = 30
VIEW = {
    's': "front view, the character faces the viewer",
    'se': "three-quarter front view, the character faces the lower right",
    'e': "side view, the character faces right",
    'ne': "three-quarter back view, the character faces the upper right, the face is not visible",
    'n': "back view, the character faces away from the viewer, the face is not visible",
}
POSE = {
    'idle': "standing", 'walk': "walking", 'sit': "sitting on the ground",
    'attack_unarmed': "fighting bare-handed", 'attack_blade': "attacking with empty hands as if holding a short blade",
    'attack_staff': "attacking with empty hands as if holding a staff", 'cast': "casting a spell with the hands",
    'death': "collapsing to the ground",
}
KEEP = (" Keep exactly the same head, face, hair, pose, arm and leg positions, body proportions, size, facing "
        "direction and position in the image. Keep the same pixel art style with a colored 1-pixel outline, 3 to 4 "
        "shades per material, light from the top left, and the plain white background. Do not add weapons in the "
        "hands, do not add other characters.")


def w(*p):
    d = os.path.join(WORK, *p[:-1])
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, p[-1])


def key_frame(body, key):
    an, r, c = key
    b = P.load(P.base_path(body, an))[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR]
    m = P.load(P.mask_path(body, an))[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR]
    return b, m


def src_image(body, key, S=6):
    p = w('src', body, P.key_name(key) + '.png')
    if not os.path.exists(p):
        b, _ = key_frame(body, key)
        img = Image.new('RGB', (FR * S, FR * S), (255, 255, 255))
        im = Image.fromarray(b).resize((FR * S, FR * S), Image.NEAREST)
        img.paste(im, (0, 0), im)
        img.save(p)
    return p


# The AI tends to straighten the female body under the outfit (README, known limits): say it.
FIGURE = {'female': " The character is a slim young woman: keep her narrow waist, slightly wider hips and feminine "
                    "figure under the new clothes.", 'male': ""}


def instruction(outfit, key, body='male'):
    an, r, _ = key
    return (f"Pixel art game sprite of a character {POSE[an]} ({VIEW[P.DIRS[r]]}). Change only the clothes of the "
            f"character to {OUTFITS[outfit]['prompt']}" + FIGURE.get(body, "") + KEEP)


def ai_path(outfit, body, key, seed):
    return w('ai', outfit, body, f'{P.key_name(key)}__s{seed}.png')


# --- edit ---------------------------------------------------------------------------------------------

def cmd_edit(outfits, bodies, seed, only_bad):
    import bria
    jobs = []
    for o in outfits:
        for b in bodies:
            scores = _scores(o, b)
            for k in P.analyse_body(b)['keys']:
                if only_bad and scores.get(P.key_name(k), 0) >= float(os.environ.get("IOU_REDO", IOU_OK)):
                    continue
                out = ai_path(o, b, k, seed)
                if not os.path.exists(out):
                    jobs.append((src_image(b, k), instruction(o, k, b), out, seed))
    print(len(jobs), 'edits', flush=True)
    ok = err = 0
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '8'))) as ex:
        for f in cf.as_completed([ex.submit(bria.edit, *j) for j in jobs]):
            try:
                f.result(); ok += 1
            except Exception as e:  # noqa: BLE001
                err += 1; print('err', str(e)[:200], flush=True)
            if (ok + err) % 20 == 0:
                print(ok, 'ok', err, 'err', flush=True)
    print('done', ok, 'ok', err, 'err')


# --- assemble -----------------------------------------------------------------------------------------

def _scores(outfit, body):
    p = w('reg', outfit, body, 'scores.json')
    return json.load(open(p)) if os.path.exists(p) else {}


def candidates(outfit, body, key):
    """Every AI edit of this key pose, registered: [(frame96, iou, seed)]. Cached per candidate."""
    b, m = key_frame(body, key)
    hb = head_box(head_pixels(b, m))
    out = []
    for f in sorted(glob.glob(w('ai', outfit, body, P.key_name(key) + '__s*.png'))):
        seed = int(f.rsplit('__s', 1)[1][:-4])
        cp = w('reg', outfit, body, f'{P.key_name(key)}__s{seed}.v3.npz')
        if os.path.exists(cp) and os.path.getmtime(cp) > os.path.getmtime(f):
            d = np.load(cp); fr, iou = d['fr'], float(d['iou'])
        else:
            ai = cutout(f)
            fr, iou, prm = register(ai, b, hb[1] + 1 if hb else 0)
            # the AI often turns a side/three-quarter pose to the other side (punch to the left in the E row): the
            # mirrored drawing may fit the base pose much better
            if P.DIRS[key[1]] != 's' and P.DIRS[key[1]] != 'n' or iou < IOU_OK:
                aim = np.ascontiguousarray(ai[:, ::-1])
                frm, ioum, prmm = register(aim, b, hb[1] + 1 if hb else 0)
                if ioum > iou + MIRROR_GAIN:
                    ai, fr, iou, prm = aim, frm, ioum, prmm
            if hb is not None:
                chin = ai_chin(fr, b, m, hb)
                if STRETCH_MIN <= chin - hb[1] <= STRETCH_MAX:
                    feet = int(np.nonzero((b[..., 3] > 0).any(axis=1))[0].max())
                    st = stretch_body(ai, prm, chin, hb[1], feet)
                    if st is not None:
                        fr = st
            np.savez_compressed(cp, fr=fr, iou=iou)
        out.append((fr, iou, seed))
    return out


def _hist(fr, b, m, pal):
    sel = clean_body(fr, b, m)
    if not sel.any():
        return np.zeros(len(pal))
    qi, _ = quantize(fr[sel][:, :3], pal)
    h = np.bincount(qi, minlength=len(pal)).astype(float)
    return h / h.sum()


def _skin_like(ai96, b, m, dist=45):
    """AI pixels with a color close to the base skin tones."""
    t = skin_table(b, m)
    if not t:
        return np.zeros(ai96.shape[:2], bool)
    cols = np.array(list(t.keys()), int)
    px = ai96[..., :3].astype(int).reshape(-1, 1, 3)
    d = ((px - cols[None]) ** 2).sum(-1).min(1).reshape(ai96.shape[:2])
    return (ai96[..., 3] > 0) & (d < dist ** 2)


def ai_chin(ai96, b, m, hb=None, body=None):
    """Bottom row of the AI face (skin pieces that reach up into the base face), or the base chin if none.
    When the AI drew a bigger head its chin falls below the base chin."""
    if hb is None:
        hb = head_box(head_pixels(b, m))
        if hb is None:
            return 0
    y0, y1, x0, x1 = hb
    if body is None:
        body = ai96[..., 3] > 0
    skin = _skin_like(ai96, b, m, 30) & body
    cols = skin[:, max(0, x0 - 1):x1 + 2].sum(axis=1)
    # the AI face goes on while rows under the base chin still hold skin (gaps of up to FACE_GAP rows: eyes,
    # mouth, glasses the AI sometimes adds)
    chin, gap = y1, 0
    for r in range(y1 + 1, min(FR, y1 + 16)):
        if cols[r] >= 3:
            chin, gap = r, 0
        else:
            gap += 1
            if gap > FACE_GAP:
                break
    return chin


def clean_body(ai96, b, m):
    """AI pixels kept for the body: nothing around/above the base head, nothing below the feet (AI shadow)."""
    hp = head_pixels(b, m)
    body = ai96[..., 3] > 0
    hb = head_box(hp)
    if hb is not None:
        y0, y1, x0, x1 = hb
        # the AI head / hair: only around the base head, so raised arms and hands stay. When the AI drew a bigger
        # head its chin falls below the base chin: cut down to the AI chin (bottom of its face skin blob)
        chin = y1
        # only when the AI still has its own head up there (a stretched body starts right under the base chin)
        if body[max(0, y0):max(0, y1 - 4), max(0, x0):x1 + 1].sum() >= 20:
            chin = min(y1 + CHIN_MAX, ai_chin(ai96, b, m, hb, body))
        cut = np.zeros((FR, FR), bool)
        cut[max(0, y0 - 6):chin + 1, max(0, x0 - 3):x1 + 4] = True
        body &= ~cut
    ys = np.nonzero((b[..., 3] > 0).any(axis=1))[0]
    if len(ys):
        body[ys.max() + 1:] = False
    # leftover AI ground shadow at the feet: light, greyish pixels in the lowest rows of the body
    rows = np.nonzero(body.any(axis=1))[0]
    if len(rows):
        rgb = ai96[..., :3].astype(int)
        light = (rgb.max(axis=2) > 110) & (rgb.max(axis=2) - rgb.min(axis=2) < 60)
        low = np.zeros_like(body); low[rows.max() - 2:] = True
        bo = b[..., 3] > 0
        br = np.nonzero(bo.any(axis=1))[0]
        shadow = np.zeros_like(bo)
        if len(br):
            bc = b[..., :3].astype(int)
            sc = np.zeros_like(bo)
            for c in BASE_SHADOW:
                sc |= (np.abs(bc - np.array(c)).sum(axis=2) == 0)
            shadow[br.max() - 2:] = True
            shadow &= sc
        feet = ndi.binary_dilation(bo & ~shadow, np.ones((3, 3), bool))
        body &= ~(low & light & ~feet)
    # loose bits (hair strands cut from the AI head, shadow crumbs): keep the main body and big pieces
    lab, n = ndi.label(body, np.ones((3, 3), bool))
    if n > 1:
        sz = np.bincount(lab.ravel()); sz[0] = 0
        body &= (sz >= max(12, sz.max() * 0.03))[lab]
    return body


def quantize(px, pal):
    d = ((px[:, None, :].astype(int) - pal[None, :, :].astype(int)) ** 2).sum(-1)
    return d.argmin(1), d.min(1)


# Recolorable skin of the outfit only near the base skin (hands, forearms, neck): tan leather, straw and khaki are close
# to the skin tones and turned into skin (a dark-skinned player got dark patches on the jerkin). Outfits whose design
# shows bare skin elsewhere (bare chest) set "skin": "free" in outfits.json.
SKIN_NEAR = 6


def body_layer(ai96, b, m, pal, skin_cols, skin_vals, iou=1.0, free_skin=False):
    """-> 8-channel (RGBA frame + RGBA mask) of the outfit body, without the head.
    The AI body may pass the base silhouette by SNAP_FAR px (coats, capes). When the AI pose fits badly
    (iou < IOU_SNAP), the body is snapped to the base silhouette: what passes it goes away and the base limbs the AI
    left empty take the nearest outfit pixel, so arms and legs stay where the animation (and the weapon) expects."""
    keep = clean_body(ai96, b, m)
    sil = b[..., 3] > 0
    snap = iou < IOU_SNAP
    keep &= ndi.binary_dilation(sil, np.ones((3, 3), bool), iterations=1 if snap else SNAP_FAR)
    o = np.zeros((FR, FR, 8), np.uint8)
    px = ai96[keep][:, :3]
    if not len(px):
        return o
    qi, _ = quantize(px, pal)
    q = pal[qi]
    # skin: AI pixels close to a base skin color, in blobs (fingers, arms, neck), get the skin mask
    si, sd = quantize(px, skin_cols)
    cand = np.zeros((FR, FR), bool)
    cand[keep] = sd < SKIN_DIST ** 2
    if not free_skin:
        zone = (m[..., 0] > 5) & (b[..., 3] > 0) & ~head_pixels(b, m)
        cand &= ndi.binary_dilation(zone, np.ones((3, 3), bool), iterations=SKIN_NEAR) if zone.any() else False
    lab, n = ndi.label(cand)
    if n:
        sz = np.bincount(lab.ravel()); sz[0] = 0
        cand &= (sz >= 4)[lab]
    is_skin = cand[keep]
    q[is_skin] = skin_cols[si[is_skin]]
    o[keep, :3] = q
    o[keep, 3] = 255
    o[keep, 4] = np.where(is_skin, skin_vals[si], 0)
    o[keep, 7] = 255
    if snap:
        hole = sil & ~keep & ~head_pixels(b, m)
        kr = np.nonzero(keep.any(axis=1))[0]
        if len(kr):
            hole[kr.max() + 1:] = False          # the base ground shadow is not body
        if hole.any() and keep.any():
            _, (iy, ix) = ndi.distance_transform_edt(~keep, return_indices=True)
            o[hole] = o[iy[hole], ix[hole]]
    return o


WEAPON_DIR = os.path.join(GAME, 'assets', 'equipment', 'weapon')
# weapons whose handle marks the hand to keep. The bow is left out: its whole wooden body is warm and crosses the
# body, and bow.py places it on the outfit's own hand.
GRIP_KINDS = ('blade', 'staff')
_RAMPS = json.load(open(os.path.join(HERE, '..', 'customization', 'palettes.json')))


def canonical(m):
    """Literal RGB for the recolored pixels (the shader replaces them anyway): the default ramp color of the tone.
    R = skin, else G = eyes, else B = shaved hair (same priority as the shader). -> (rgb array, selected)"""
    out = np.zeros(m.shape[:2] + (3,), np.uint8)
    sel = np.zeros(m.shape[:2], bool)
    for ch, key in ((2, 'hair'), (1, 'eye'), (0, 'skin')):   # later wins = shader priority
        ramp = np.array(_RAMPS[key][0][1], np.uint8)
        on = m[..., ch] > 5
        t = np.clip(m[..., ch].astype(int) // 40, 0, 5)
        out[on] = ramp[np.minimum(t[on], len(ramp) - 1)]
        sel |= on
    return out, sel


def grip_sheet(body, anim):
    """Handles of the held weapons in this sheet (brown/wood pixels of every weapon layer, front and back): the
    hand that grips them must stay where the weapon layer expects it. None if there is no weapon layer."""
    acc = None
    for p in [q for kind in GRIP_KINDS for q in (os.path.join(WEAPON_DIR, kind, f'{body}_{anim}.png'),
                                                  os.path.join(WEAPON_DIR, kind, f'{body}_{anim}_back.png'))
              if os.path.exists(q)]:
        w_ = P.load(p)
        rgb = w_[..., :3].astype(float) / 255
        mx, mn = rgb.max(axis=2), rgb.min(axis=2)
        r_, g_ = rgb[..., 0], rgb[..., 1]
        warm = (mx == r_) & (r_ > g_) & (mx - mn > 0.12)   # brown handle / wood, not steel nor crystal
        a = (w_[..., 3] > 0) & warm
        acc = a if acc is None else (acc | a if acc.shape == a.shape else acc)
    return acc


def finalize(layer, b, m, grip=None, pal=None):
    """Outfit body + the real base frame: the base hands that hold weapons, base skin the AI left empty (neck,
    fingers) and the head on top."""
    out = layer[..., :4].copy()
    om = layer[..., 4:].copy()
    hp = head_pixels(b, m)
    if grip is not None and grip.any():
        # the weapon layers are drawn for the base hands: keep those hands (not the blue sleeve) under the grip
        from cloth_zone import blue_cloth
        hand = ndi.binary_dilation(grip, np.ones((3, 3), bool), iterations=2) & (b[..., 3] > 0) & ~blue_cloth(b)
        out[hand] = b[hand]
        om[hand] = m[hand]
    fill = (b[..., 3] > 0) & (m[..., 0] > 5) & (out[..., 3] == 0) \
        & ndi.binary_dilation(out[..., 3] > 0, np.ones((3, 3), bool))
    out[fill] = b[fill]
    om[fill] = m[fill]
    om[fill, 3] = 255
    out[hp] = b[hp]
    om[hp] = m[hp]
    # neck gap: base pixels between the head and the outfit that nobody covers take the nearest outfit pixel
    hb = head_box(hp)
    if hb is not None:
        gap = (b[..., 3] > 0) & (out[..., 3] == 0)
        band = np.zeros_like(gap)
        band[max(0, hb[1] - 4):hb[1] + 10, max(0, hb[2] - 2):hb[3] + 3] = True
        gap &= band
        src = (layer[..., 3] > 0)
        if gap.any() and src.any():
            _, (iy, ix) = ndi.distance_transform_edt(~src, return_indices=True)
            near = ndi.distance_transform_edt(~src) <= 5
            g = gap & near
            out[g] = layer[..., :4][iy[g], ix[g]]
            om[g] = layer[..., 4:][iy[g], ix[g]]
    om[..., 3] = np.where(out[..., 3] > 0, np.where(hp & (m[..., 3] == 128), 128, 255), 0)
    om[out[..., 3] == 0] = 0
    if pal is not None:
        # sheet palette (<= 48 colors, validate_art.py): recolored pixels get the canonical ramp color, the
        # rest (outlines, gloves under the grip...) the nearest color of the outfit palette
        op = out[..., 3] > 0
        can, cs = canonical(om)
        cs &= op
        out[cs, :3] = can[cs]
        lit = op & ~cs
        hl = lit & hp
        lit &= ~hp
        if lit.any():
            qi, _ = quantize(out[lit][:, :3], pal)
            out[lit, :3] = pal[qi]
        if hl.any():
            hpal = pal[-PALETTE_HEAD:]
            qi, _ = quantize(out[hl][:, :3], hpal)
            out[hl, :3] = hpal[qi]
    return out, om


IMPORT_PARAMS = {"compress/mode": "0", "mipmaps/generate": "false", "detect_3d/compress_to": "0",
                 "process/fix_alpha_border": "false"}


def write_import(png):
    """Same import settings as the base body sheets (lossless, no VRAM compression, no alpha border fix: the
    mask values must reach the shader untouched). Godot fills the rest on `--import`."""
    imp = png + '.import'
    if os.path.exists(imp):
        txt = open(imp, encoding='utf-8').read()
        import re
        for k, v in IMPORT_PARAMS.items():
            txt = re.sub(r'^' + re.escape(k) + r'=.*$', f'{k}={v}', txt, flags=re.M)
    else:
        txt = ('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
               + ''.join(f'{k}={v}\n' for k, v in IMPORT_PARAMS.items()))
    open(imp, 'w', encoding='utf-8').write(txt)


def outfit_palette(body, reg):
    """Palette of the outfit (all key poses, body only, plus the head's literal pixels) and the base skin table."""
    px = []
    skin = {}
    for k, (fr, iou, seed) in reg.items():
        b, m = key_frame(body, k)
        px.append(fr[clean_body(fr, b, m)][:, :3])
        skin.update(skin_table(b, m))
    px = np.concatenate(px)
    pim = Image.fromarray(px[None, :, :]).quantize(PALETTE - PALETTE_HEAD, method=Image.Quantize.MEDIANCUT,
                                                  dither=Image.Dither.NONE)
    pal = np.array(pim.getpalette()[:(PALETTE - PALETTE_HEAD) * 3], np.uint8).reshape(-1, 3)
    # the head's literal pixels (outlines, mouth, ears) get their own few colors, so they never take an outfit
    # color (a green outline on the face)
    hp_px = []
    for an in P.ANIMS:
        if os.path.exists(P.base_path(body, an)):
            bs_, ms_ = P.load(P.base_path(body, an)), P.load(P.mask_path(body, an))
            for r in range(bs_.shape[0] // FR):
                for c in range(bs_.shape[1] // FR):
                    sl = (slice(r * FR, (r + 1) * FR), slice(c * FR, (c + 1) * FR))
                    hp = head_pixels(bs_[sl], ms_[sl]) & (ms_[sl][..., :3].max(axis=2) <= 5)
                    hp_px.append(bs_[sl][hp][:, :3])
    hp_px = np.concatenate(hp_px)
    him = Image.fromarray(hp_px[None, :, :]).quantize(PALETTE_HEAD, method=Image.Quantize.MEDIANCUT,
                                                     dither=Image.Dither.NONE)
    hpal = np.array(him.getpalette()[:PALETTE_HEAD * 3], np.uint8).reshape(-1, 3)
    pal = np.concatenate([pal, hpal])
    return pal, np.array(list(skin.keys()), np.uint8), np.array(list(skin.values()), np.uint8)


def cmd_assemble(outfits, bodies):
    for o in outfits:
        for body in bodies:
            A = P.analyse_body(body)
            keys = A['keys']
            cands = {}
            missing = []
            for k in keys:
                c = candidates(o, body, k)
                if not c:
                    missing.append(P.key_name(k)); continue
                cands[k] = c
            if missing:
                print(o, body, 'MISSING AI edits for', len(missing), 'keys:', missing[:6]); continue
            # pass 1: best silhouette
            best = {k: int(np.argmax([t[1] for t in c])) for k, c in cands.items()}
            reg = {k: cands[k][i] for k, i in best.items()}
            pal, skin_cols, skin_vals = outfit_palette(body, reg)
            # pass 2: among the seeds, prefer the one whose colors match the outfit as drawn in the other poses of
            # the same direction (fewer "different design" jumps between poses)
            hists = {k: [_hist(fr, *key_frame(body, k), pal) for fr, _, _ in c] for k, c in cands.items()}
            for r in range(5):
                ks = [k for k in keys if k[1] == r]
                ref = np.mean([hists[k][best[k]] for k in ks], axis=0)
                for k in ks:
                    bk, mk = key_frame(body, k)
                    hbk = head_box(head_pixels(bk, mk))
                    y1 = hbk[1] if hbk else 0
                    sc = [c[1] - DESIGN_W * np.abs(h - ref).sum() - CHIN_W * (ai_chin(c[0], bk, mk) - y1)
                          for c, h in zip(cands[k], hists[k])]
                    reg[k] = cands[k][int(np.argmax(sc))]
            pal, skin_cols, skin_vals = outfit_palette(body, reg)
            json.dump({P.key_name(k): [round(v[1], 4), v[2]] for k, v in reg.items()},
                      open(w('reg', o, body, 'picks.json'), 'w'), indent=1)
            json.dump({P.key_name(k): round(max(t[1] for t in c), 4) for k, c in cands.items()},
                      open(w('reg', o, body, 'scores.json'), 'w'), indent=1)
            layers = {}
            for k, (fr, iou, seed) in reg.items():
                b, m = key_frame(body, k)
                layers[k] = body_layer(fr, b, m, pal, skin_cols, skin_vals, iou,
                                       OUTFITS[o].get('skin') == 'free')
            # sheets: every frame = its key layer with the frame transform + the real frame's head
            for an in P.ANIMS:
                bp = P.base_path(body, an)
                if not os.path.exists(bp):
                    continue
                bs, ms = P.load(bp), P.load(P.mask_path(body, an))
                gs = grip_sheet(body, an)
                S = np.zeros_like(bs)
                M = np.zeros_like(ms)
                for r in range(bs.shape[0] // FR):
                    for c in range(bs.shape[1] // FR):
                        ki, t = A['frames'][(an, r, c)]
                        lay = P.apply(layers[keys[ki]], t)
                        sl = (slice(r * FR, (r + 1) * FR), slice(c * FR, (c + 1) * FR))
                        S[sl], M[sl] = finalize(lay, bs[sl], ms[sl], gs[sl] if gs is not None else None, pal)
                for arr, name in ((S, f'chr_{body}_{o}_{an}.png'), (M, f'chr_{body}_{o}_mask_{an}.png')):
                    Image.fromarray(arr, 'RGBA').save(os.path.join(OUT_DIR, name))
                    write_import(os.path.join(OUT_DIR, name))
            ious = [v[1] for v in reg.values()]
            print(o, body, 'keys', len(reg), 'IoU min %.3f mean %.3f' % (min(ious), np.mean(ious)),
                  'bad(<%.2f): %d' % (IOU_OK, sum(i < IOU_OK for i in ious)), flush=True)


def main():
    a = sys.argv[1:]
    if not a or a[0] not in ('edit', 'assemble', 'keys'):
        print(__doc__); sys.exit(1)
    if a[0] == 'keys':
        for b in P.BODIES:
            print(b, len(P.analyse_body(b)['keys']), 'key poses')
        return
    seed = SEEDS[0]
    only_bad = '--only-bad' in a
    if '--seed' in a:
        seed = int(a[a.index('--seed') + 1]); a = a[:a.index('--seed')] + a[a.index('--seed') + 2:]
    a = [x for x in a if x != '--only-bad']
    outfits = list(OUTFITS) if a[1] == 'all' else a[1].split(',')
    bodies = a[2:] or P.BODIES
    if a[0] == 'edit':
        cmd_edit(outfits, bodies, seed, only_bad)
    else:
        cmd_assemble(outfits, bodies)


if __name__ == '__main__':
    main()
