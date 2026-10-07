"""Corvo da Montanha / Tengu do Vendaval / Tengu da Asa Noturna.
Criatura aviária inspirada no tengu, com leque de penas e nariz em bico; sem objetos religiosos.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('mountain_tengu', stage)
