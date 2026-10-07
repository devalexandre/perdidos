"""Ave-Fagulha / Ave da Pluma Ardente / Ave da Brasa Azul.
Ave mágica inspirada no pássaro de fogo dos contos eslavos; não é uma divindade.
Art only: not registered in runtime data."""
from reserve_species import STAGES, FRAME, ANIMS, pose
from reserve_species import build as _build

def build(stage):
    return _build('ember_bird', stage)
