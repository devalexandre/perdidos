"""Serpente-Fagulha / Serpente do Fogo Errante / Serpente da Cinza Viva.
Serpente de fogo inspirada no imaginário do Boitatá; não é o chefe único da região.
Active in Pindorama hunting maps; exported through the native sprite pipeline."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('cinder_serpent', stage)
