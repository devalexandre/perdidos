"""Lanterna Travessa / Lanterna do Desfile / Lanterna da Chama Violeta.
Objeto assombrado inspirado em lanternas do folclore japonês, sem escrita ritual.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('paper_lantern', stage)
