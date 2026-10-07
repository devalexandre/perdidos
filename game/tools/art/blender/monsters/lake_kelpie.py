"""Kelpie do Lago / Kelpie das Brumas (lake_kelpie) — Brumas Verdes (cavalo d'agua do folclore escoces).
Base: esqueleto/corpo/animacoes do "Horse" (Quaternius Ultimate Animated Animals, CC0) reformado em potrinho;
cabeca nossa de potro; corpo de agua verde-azulada, crina de algas e olhos verdes brilhando."""
from mathutils import Vector
import mon_rig as R
import pack_species as PS


def extra(rig, pk, stage, c, r):
    piv = rig.head_pivot
    # crina de algas: tufos ao longo do pescoco e na testa
    for k in range(4):
        p = c + Vector((0, 0.35 * r + 0.25 * r * k, 0.75 * r - 0.28 * r * k))
        rig.add_mesh(R.ellipsoid(f"mane{k}", p, (0.16 * r, 0.3 * r, 0.22 * r), rot=(0.6, 0, 0)), f"mane{k}", "seaweed", piv)
    # gotas d'agua
    for k in range(2 + stage):
        p = c + Vector(((-1) ** k * 0.9 * r, 0.3 * r * k, -0.2 * r + 0.3 * r * k))
        rig.add_mesh(R.ellipsoid(f"drop{k}", p, (0.08 * r, 0.08 * r, 0.11 * r)), f"drop{k}", "fur_blue", piv, noline=True)


S = PS.animal_cub("lake_kelpie", "Horse.gltf", {1: 0.92, 2: 1.38}, "water", 
                  matmap={"Main": ("body", "water"), "Main_Dark": ("dark", "water"), "Main_Light": ("light", "water"),
                          "Hair": ("hair", "seaweed"), "Hooves": ("hoof", "hoof"), "Muzzle": ("muzzle", "water"),
                          "Eye_Black": ("e1", "eye"), "Eye_White": ("e2", "white")},
                  head=dict(muzzle="water", nose="hoof", ear="long", eye_mat="eye_green", snout=0.62,
                            brows=lambda st: st >= 2),
                  extra=extra, actions={"attack": "Attack_Kick"})
STAGES = (1, 2)
FRAME, ANIMS, _ST, build, pose = S.FRAME, S.ANIMS, S.STAGES, S.build, S.pose
