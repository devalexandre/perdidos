"""Mula de Brasa / Mula da Queimada / Mula da Noite Ardente.
Mula de fogo: releitura fantástica sem o componente religioso da lenda.
Active in Pindorama hunting maps; exported through the native sprite pipeline."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('ember_mule', stage)
