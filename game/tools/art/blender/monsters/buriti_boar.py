"""Queixada de Buriti / Queixada do Veredão / Queixada das Raízes Negras.
Fauna do cerrado e veredas; criatura original, com presas e folhas de buriti.
Active in Pindorama hunting maps; exported through the native sprite pipeline."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('buriti_boar', stage)
