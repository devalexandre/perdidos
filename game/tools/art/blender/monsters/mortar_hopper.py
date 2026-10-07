"""Pilão Saltador / Pilão da Floresta / Pilão do Bosque Sombrio.
Objeto encantado inspirado no pilão dos contos de Baba Yaga; espécie original.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('mortar_hopper', stage)
