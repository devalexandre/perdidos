"""Harpia do Penhasco / Harpia das Colunas / Harpia da Tempestade.
Harpia reinterpretada como ave fantástica chibi, sem sexualização.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('cliff_harpy', stage)
