"""Aranha de Bétula / Tecelã do Bosque Branco / Tecelã da Geada Negra.
Fauna e florestas de bétulas da região; criatura original, sem atribuição folclórica literal.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('birch_spider', stage)
