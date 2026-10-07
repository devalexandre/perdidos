"""Louva-a-deus de Jade / Foice do Bambuzal / Foice da Jade Negra.
Fauna e bambuzais reinterpretados com placas minerais; criatura original.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('jade_mantis', stage)
