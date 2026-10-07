"""Morcego do Cacau / Asa da Caverna / Asa da Obsidiana Viva.
Fauna de selvas e cavernas mesoamericanas; criatura original, sem deuses ou sacrifícios.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('cacao_bat', stage)
