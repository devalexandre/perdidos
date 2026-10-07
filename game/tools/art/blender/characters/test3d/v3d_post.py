#!/usr/bin/env python3
"""TESTE Viajante 3D: pos-processamento (cel shading em rampas, linha interna, contorno colorido) reaproveitando o
chr_post.py, com a tabela de materiais deste teste. Nada e desenhado aqui: rosto, olhos e boca sao pecas
renderizadas pelo Blender (v3d_model.py); o pos so escolhe a cor de cada peca e o tom pela luz.

  .tools/pyvenv/bin/python game/tools/art/blender/characters/test3d/v3d_post.py [--work .work/v3d]
        [--out game/assets/characters/_test3d]
"""
import argparse, glob, json, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import chr_post as CP  # noqa: E402

GAME = CP.GAME
ROOT = CP.ROOT
FAM, M, hx, R = CP.FAM, CP.M, CP.hx, CP.R
FRAME = 96


def flat(col, out=None):
    c = hx(col)
    return dict(ramp=[c, c, c, c], fill=(0,), line=0, out=hx(out) if out else c)


BLUE = FAM(("173f60", "1f5a88", "2a74a6", "4a96c6"), "0b1f36")
FOREST = FAM(("1f3a26", "2b5233", "3c6c40", "5a8c50"), "0e1d12")
CAPE = FAM(("2c2a1c", "41402a", "5a5a38", "767a4c"), "171610")
PANTS = FAM(("2a2532", "3a3346", "4d465c", "665e78"), "14111a")
LEGGINGS = FAM(("1c1822", "282230", "373042", "4a4256"), "0e0c12")
BROWNP = FAM(("3a2a1e", "523c2a", "6a4e36", "846446"), "1c140e")
BOOTD = FAM(("2c1c16", "422a1e", "5a3c2a", "765236"), "160e0a")
SOLE = FAM(("3a2a24", "4e3a30", "665044", "806a5c"), "1a120e")
EYE = CP.EYE0 if hasattr(CP, "EYE0") else [(52, 24, 22), (112, 56, 34), (176, 102, 50), (230, 162, 88)]

MATS = {
    "skin": dict(CP.MATS["skin"], fill=(1, 2, 3, 3)), "hair": CP.MATS["hair"],
    "brow": dict(kind="hair", ramp=CP.HAIR0, fill=(1,), line=0, out=0),
    "tie": M(CP.RED, (0, 1, 2, 3)),
    "sclera": flat("f4eef0"), "iris": dict(ramp=[EYE[2]] * 4, fill=(0,), line=0, out=hx("000000")),
    "iris_dark": dict(ramp=[EYE[1]] * 4, fill=(0,), line=0, out=hx("000000")),
    "pupil": flat("2a1418"), "shine": flat("fffcf4"), "lash": flat("2a1620"), "lash_low": flat("7a3e44"),
    "mouth": flat("9a4848"), "nose": dict(kind="skin", ramp=CP.SKIN0, fill=(1,), line=0, out=0),
    "blush": flat("f0a080"),
    "tunic": M(BLUE), "tunic_trim": M(BLUE, (1, 2, 3)), "tunic_dark": M(BLUE, (0, 1, 2)),
    "belt": M(CP.LEATHER, (0, 1, 2)), "brass": M(CP.GOLDF), "strap": M(CP.LEATHER, (0, 1, 2)),
    "bag": M(CP.LEATHER), "bag_flap": M(CP.LEATHER, (1, 2, 3)),
    "pants": M(PANTS), "leggings": M(LEGGINGS), "boot": M(CP.LEATHER), "sole": M(SOLE, (0, 1, 2)),
    "forest": M(FOREST), "forest_trim": M(FOREST, (1, 2, 3)), "cape": M(CAPE), "cape_trim": M(CP.LEATHER, (1, 2, 3)),
    "leather": M(CP.LEATHER), "leather_dark": M(CP.LEATHER, (0, 1, 2)), "pants_brown": M(BROWNP),
    "boot_dark": M(BOOTD), "fletch": M(CP.WHITE, (1, 2, 3)), "fletch_red": M(CP.RED, (1, 2, 3)),
    "wood": CP.MATS["wood"], "bow_grip": M(CP.LEATHER, (0, 1, 2)), "string": flat("e8e0d2", "6a6058"),
    "arrow": dict(ramp=CP.MATS["wood"]["ramp"], fill=(2, 3), line=0, out=CP.MATS["wood"]["out"]),
    "steel": CP.MATS["steel"],
}
# chr_post.shade_set/colorize leem o MATS do proprio modulo
CP.MATS.clear()
CP.MATS.update(MATS)
NAMES = sorted(MATS)
BG = (118, 158, 86, 255)


def frames_of(meta, z, anim):
    ids, dep, nx, ny = z[f"{anim}_id"], z[f"{anim}_d"], z[f"{anim}_nx"], z[f"{anim}_ny"]
    ND, NF = ids.shape[:2]
    out = []
    for r in range(ND):
        row = []
        for f in range(NF):
            mat, code, own = CP.shade_set(ids[r, f], dep[r, f], nx[r, f], ny[r, f], meta["parts"])
            row.append(CP.colorize(mat, code, NAMES))
        out.append(row)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=os.path.join(ROOT, ".work", "v3d"))
    ap.add_argument("--out", default=os.path.join(GAME, "assets", "characters", "_test3d"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    pv = os.path.join(a.work, "preview"); os.makedirs(pv, exist_ok=True)
    for fn in sorted(glob.glob(os.path.join(a.work, "npz", "*", "*.npz"))):
        body = os.path.basename(os.path.dirname(fn))
        var = os.path.basename(fn)[:-4]
        meta = json.load(open(fn[:-4] + ".json"))
        z = np.load(fn)
        Cv = meta["canvas"]
        # recorte fixo: origem (pes) da camera na penultima linha, como as folhas atuais
        ref = z["idle_id"] if "idle_id" in z.files else z[f"{meta['anims'][0][0]}_id"]
        y1 = int(np.nonzero((ref > 0).any((0, 1)).any(1))[0].max()) + 2; y0 = y1 - FRAME; x0 = Cv // 2 - FRAME // 2; x1 = x0 + FRAME
        for anim, n in meta["anims"]:
            fr = frames_of(meta, z, anim)
            sh = CP.to_sheet([[f[y0:y1, x0:x1] for f in row] for row in fr])
            p = os.path.join(a.out, f"chr_v3d_{body}_{var}_{anim}.png")
            Image.fromarray(sh, "RGBA").save(p)
            ncol = len(set(map(tuple, sh[sh[..., 3] > 0][:, :3].tolist())))
            print(f"[v3d-post] {p} cores={ncol}", flush=True)


if __name__ == "__main__":
    main()
