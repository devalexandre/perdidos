"""Pecas extras dos NPCs (roupas regionais, armas e objetos de mao), somadas a biblioteca de characters/chr_npc.py,
e carga das configuracoes com os PADROES DE CORPO (configs/_bodies.json): proporcao encorpada do jogador (C3) com
correcoes dos NPCs (postura ereta, bracos mais curtos, maos menores) e tipos adulto/idoso/crianca."""
import json, math, os
from mathutils import Vector as V
import chr_lib as C
import chr_body as B

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = os.path.join(HERE, "configs")


def _merge_thin(a, b):
    out = dict(a)
    for bn, f in b.items():
        if bn in out:
            x = out[bn]; x = x if isinstance(x, list) else [x, x]; y = f if isinstance(f, list) else [f, f]
            if len(x) == 2: x = [x[0], 1.0, x[1]]
            if len(y) == 2: y = [y[0], 1.0, y[1]]
            out[bn] = [p * q for p, q in zip(x, y)]
        else:
            out[bn] = f
    return out


def load(npc_id):
    cfg = json.load(open(os.path.join(CFG, f"{npc_id}.json")))
    bodies = json.load(open(os.path.join(CFG, "_bodies.json")))
    kind = cfg.get("kind", "adult")
    base = dict(bodies.get("_all", {}))
    over = bodies.get(kind, {})
    q = dict(cfg.get("props", {}).get("q", {}))
    thin = _merge_thin(_merge_thin(base.get("thin", {}), over.get("thin", {})), q.get("thin", {}))
    q["thin"] = thin
    q["height"] = q.get("height", 1.0) * over.get("height", 1.0)
    q["head"] = q.get("head", 1.0) * over.get("head", 1.0)
    cfg.setdefault("props", {})["q"] = q
    pose = dict(base.get("pose", {}))
    for kk, v in over.get("pose", {}).items():
        pose[kk] = [pose.get(kk, [0, 0, 0])[0] + v[0], 0, 0]
    for kk, v in cfg.get("pose", {}).items():
        pose[kk] = [pose.get(kk, [0, 0, 0])[0] + v[0], 0, 0]
    cfg["pose"] = pose
    return cfg


def register(npc_mod):
    npc_mod.PARTS.update(PARTS)


PARTS = {}
