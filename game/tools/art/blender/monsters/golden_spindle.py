"""Fuso Saltitante / Roca do Tesouro / Roca dos Fios Sombrios.
Objeto encantado inspirado no ouro fiado das mouras; as guardiãs não são inimigas.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('golden_spindle', stage)
