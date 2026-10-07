"""Nian das Colinas / Nian do Vale Rubro / Nian da Noite Ruidosa.
Nian como fera fantástica de chifre e juba; sem imagens de sacerdotes.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('nian_cub', stage)
