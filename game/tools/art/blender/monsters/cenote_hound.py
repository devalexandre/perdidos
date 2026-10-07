"""Cão do Cenote / Fera da Cauda-Mão / Fera do Cenote Negro.
Releitura fantástica do ahuizotl, criatura aquática com mão na cauda; não é nahual ou alux.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('cenote_hound', stage)
