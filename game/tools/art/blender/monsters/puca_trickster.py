"""Puca Travesso / Puca Galopante (puca_trickster) — Brumas Verdes (o puca do folclore irlandes, que aparece como
bode preto peludo). Base: esqueleto/corpo/animacoes do "Alpaca" (Quaternius Ultimate Animated Animals, CC0)
reformado em bodinho (pescoco curto, pelo desgrenhado); cabeca nossa com chifres curvos e olhos dourados."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage, c, r):
    piv = rig.head_pivot
    for sx, nm in ((1, "L"), (-1, "R")):   # chifres enrolados
        b0 = c + Vector((0.35 * r * sx, 0.1 * r, 0.7 * r))
        b1 = b0 + Vector((0.55 * r * sx, 0.45 * r, 0.05 * r))
        rig.add_mesh(R.cone(f"horn{nm}", b0, b1, 0.14 * r, 0.04 * r, seg=8, rings=6, bend=(0.1 * r * sx, 0.1 * r, 0.45 * r)),
                     f"horn{nm}", "horn", piv)
    rig.add_mesh(R.ellipsoid("goatee", c + Vector((0, -0.95 * r, -0.62 * r)), (0.1 * r, 0.08 * r, 0.2 * r)), "goatee",
                 "fur_black", piv)
    # tufos de pelo desgrenhado pelo corpo
    mid, bc, br = rig.body
    for k in range(7):
        sx = 1 if k % 2 else -1
        p = bc + Vector((0.8 * br[0] * sx, br[1] * (-0.6 + 0.2 * k), -0.35 * br[2]))
        PS.add(rig, pk, mid, R.ellipsoid(f"tuft{k}", p, (0.22 * r, 0.26 * r, 0.32 * r), rot=(0, 0.3 * sx, 0)), f"tuft{k}", "fur_black")


S = PS.animal_cub("puca_trickster", "Alpaca.gltf", {1: 0.98, 2: 1.45}, "fur_black", 
                  matmap={"Main": ("body", "fur_black"), "Main_Dark": ("dark", "fur_black"), "Main_Light": ("light", "fur_black"),
                          "Hooves": ("hoof", "horn"), "Muzzle": ("muzzle", "fur_black"),
                          "Eyes_Black": ("e1", "eye"), "Eyes_White": ("e2", "white")},
                  head=dict(muzzle="fur_black", nose="hoof", ear="long", eye_mat="eye_gold", snout=0.5,
                            brows=lambda st: True, cheeks=False),
                  extra=extra, actions={"attack": "Attack_Headbutt"})
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
