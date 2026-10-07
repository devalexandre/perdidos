"""Carpa de Tinta / Carpa da Cascata / Carpa do Rio Noturno.
Carpa fantástica inspirada no imaginário de carpas e cascatas, com bigodes e nadadeiras em pincel.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('ink_carp', stage)
