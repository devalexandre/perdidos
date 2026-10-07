"""Touro de Bronze / Touro do Labirinto / Touro da Forja Negra.
Touro autômato de fantasia inspirado em labirintos e bronze do imaginário grego.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('bronze_bull', stage)
