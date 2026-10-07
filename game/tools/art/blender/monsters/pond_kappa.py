"""Kappa da Lagoa / Kappa do Remanso / Kappa do Poço Escuro.
Releitura do kappa: casco, bico e cavidade de água na cabeça.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('pond_kappa', stage)
