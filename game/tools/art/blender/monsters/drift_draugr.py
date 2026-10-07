"""Armadura à Deriva / Vigia do Naufrágio / Vigia do Mar Morto.
Armadura vazia inspirada em contos de assombrações marítimas e draugr, sem restos humanos ou runas reais.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('drift_draugr', stage)
