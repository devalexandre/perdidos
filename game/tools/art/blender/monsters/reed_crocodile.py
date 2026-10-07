"""Crocodilo dos Juncos / Crocodilo do Banco de Areia / Crocodilo do Lodo Negro.
Fauna do Nilo transformada em criatura de fantasia; sem símbolos religiosos.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('reed_crocodile', stage)
