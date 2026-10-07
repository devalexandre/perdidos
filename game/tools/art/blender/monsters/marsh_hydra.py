"""Hidrinha do Charco / Hidra dos Juncos / Hidra do Pântano Negro.
Hidra de três cabeças: criatura de mito grego adaptada como espécie, sem deuses.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('marsh_hydra', stage)
