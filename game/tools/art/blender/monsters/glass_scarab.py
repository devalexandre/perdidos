"""Escaravelho de Vidro / Escaravelho das Dunas / Escaravelho do Eclipse.
Besouro fantástico de dunas com élitros de vidro; sem personificar divindades.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('glass_scarab', stage)
