"""Gato do Urzal / Gato da Pedra Antiga / Gato da Lua Velada.
Gato feérico inspirado no imaginário do cat-sìth, com marca clara no peito.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('heather_cat', stage)
