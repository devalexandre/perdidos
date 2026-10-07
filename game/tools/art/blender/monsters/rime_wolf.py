"""Lobo da Geada / Lobo da Aurora / Lobo da Aurora Sombria.
Lobo fantástico dos fiordes e contos do norte; não é Fenrir.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('rime_wolf', stage)
