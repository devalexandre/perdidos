"""Luz do Brejo / Candeeiro da Turfeira / Lume da Turfa Negra.
Fogo-fátuo dos pântanos e contos de luzes errantes; sem representar uma divindade.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('bog_wisp', stage)
