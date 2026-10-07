"""Cão da Bruma / Cão do Urzal / Cão da Névoa Negra.
Cão feérico de fantasia inspirado em contos das brumas escocesas.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('mist_hound', stage)
