"""Draguinha da Charneca / Dragoa das Ruínas / Dragoa do Breu.
Coca como dragoa de fantasia, sem procissão; charnecas e ruínas portuguesas.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('coca_drake', stage)
