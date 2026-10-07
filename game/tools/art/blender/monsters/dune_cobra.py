"""Naja de Areia / Naja da Duna Rubra / Naja da Noite de Vidro.
Naja da fauna regional com capuz mineral; criatura original, não Apep.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('dune_cobra', stage)
