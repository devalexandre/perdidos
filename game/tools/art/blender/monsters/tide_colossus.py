"""Pedregulho da Maré / Colosso do Cabo / Colosso da Maré Negra.
Criatura original de rocha e espuma inspirada nos cabos de Adamastor, sem representar o personagem único.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('tide_colossus', stage)
