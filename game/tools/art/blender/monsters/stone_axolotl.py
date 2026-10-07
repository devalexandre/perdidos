"""Axolote de Turquesa / Axolote da Gruta / Axolote da Fenda Negra.
Fauna mexicana e minerais locais; criação original sem representar divindades.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('stone_axolotl', stage)
