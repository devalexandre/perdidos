"""Caranguejo do Fiorde / Couraça do Iceberg / Couraça do Abismo Frio.
Fauna costeira fantástica com armadura de gelo; criação original.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('fjord_crab', stage)
