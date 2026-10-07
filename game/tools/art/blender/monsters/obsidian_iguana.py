"""Iguana de Obsidiana / Lagarto de Obsidiana (obsidian_iguana) — Selvas de Obsidiana (lagarto de pedra vulcanica
preta com espinhos turquesa e olhos laranja). Base: esqueleto, patas e animacoes do "Fox" (Quaternius Ultimate
Animated Animals, CC0) com corpo baixo e comprido nosso, cabeca de lagarto nossa e espinhos."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage, c, r):
    mid, bc, br = rig.body
    n = 5 + 2 * (stage > 1)
    for k in range(n):   # espinhos turquesa ao longo das costas
        y = -br[1] * 0.75 + 1.5 * br[1] * k / (n - 1)
        p = bc + Vector((0, y, br[2] * 0.92))
        h = (0.28 + 0.1 * (k % 2)) * r
        PS.add(rig, pk, mid, R.cone(f"spike{k}", p, p + Vector((0, 0.08 * r, h)), 0.11 * r, 0.015 * r, seg=5, rings=1),
               f"spike{k}", "turquoise")
    piv = rig.head_pivot
    for k in range(3):
        p = c + Vector((0, 0.2 * r + 0.25 * r * k, 0.85 * r - 0.1 * r * k))
        rig.add_mesh(R.cone(f"hspike{k}", p, p + Vector((0, 0.05 * r, 0.25 * r)), 0.09 * r, 0.015 * r, seg=5, rings=1),
                     f"hspike{k}", "turquoise", piv)
    for k, (a, b) in enumerate(PS.tail_ring(pk)):
        PS.add(rig, pk, f"Tail{k + 1}", R.ellipsoid(f"tseg{k}", (a + b) / 2, (0.16 * r * (1 - k / 10),) * 2 + (0.14 * r,)),
               f"tseg{k}", "obsidian", group="tail")


S = PS.animal_cub("obsidian_iguana", "Fox.gltf", {1: 0.71, 2: 1.05}, "obsidian",
                  {"Main": ("legs", "obsidian"), "Main_Light": ("legs2", "obsidian"), "Black": ("paws", "obsidian"),
                   "Grey": ("tailtip", "turquoise"), "Eyes": ("e", "eye")},
                  head=dict(muzzle="obsidian", nose=None, ear="none", snout=0.75, snout_w=1.5, snout_h=0.8,
                            eye_mat="eye_orange", brows=lambda st: True, cheeks=False),
                  extra=extra, fat=1.3)
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
