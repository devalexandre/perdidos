"""Gera folhas provisórias (descartáveis) para testar DirectionalSprite3D sem a arte do Agente C.
Linhas = S, SE, E, NE, N. Cada linha tem uma cor e um 'nariz' que indica o lado para onde olha."""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "_stub_b"
import sys

# Tamanho do quadro (Balance.cfg.character_frame_size); argumento opcional. Desenho base em 64 px,
# redimensionado para ALTURA_PERSONAGEM px com pés em (FRAME/2, FRAME-1).
FRAME = int(sys.argv[1]) if len(sys.argv) > 1 else 96
CHAR_HEIGHT = int(sys.argv[2]) if len(sys.argv) > 2 else round(FRAME * 80 / 96)
BASE_FEET_X, BASE_FEET_Y, BASE_HEIGHT = 32, 63, 60
K = CHAR_HEIGHT / BASE_HEIGHT


class Scaled:
    """Aplica a escala do gabarito de 64 px às coordenadas, mantendo os pés ancorados."""

    def __init__(self, d: ImageDraw.ImageDraw):
        self.d = d

    def rectangle(self, box, **kw):
        x0, y0, x1, y1 = box
        ox = (x0 // FRAME) * FRAME
        oy = (y0 // FRAME) * FRAME
        def tx(x): return ox + FRAME // 2 + round((x - ox - BASE_FEET_X) * K)
        def ty(y): return oy + FRAME - 1 - round((oy + BASE_FEET_Y - y) * K)
        self.d.rectangle([tx(x0), ty(y0), tx(x1), ty(y1)], **kw)
ROW_COLORS = [(220, 40, 40), (240, 140, 20), (240, 220, 30), (40, 190, 60), (40, 90, 230)]  # S SE E NE N
OUTLINE = (30, 20, 60)


def draw_frame(d: ImageDraw.ImageDraw, ox: int, oy: int, row: int, frame: int, frames: int) -> None:
    col = ROW_COLORS[row]
    bob = frame % 2
    # corpo: pés em (32, 63)
    d.rectangle([ox + 22, oy + 14 + bob, ox + 41, oy + 63], fill=col, outline=OUTLINE)
    # cabeça
    d.rectangle([ox + 24, oy + 4 + bob, ox + 39, oy + 16 + bob], fill=(250, 220, 190), outline=OUTLINE)
    eye = (10, 10, 10)
    y = oy + 9 + bob
    if row == 0:  # S: dois olhos centrados
        d.rectangle([ox + 27, y, ox + 28, y + 1], fill=eye); d.rectangle([ox + 35, y, ox + 36, y + 1], fill=eye)
    elif row == 1:  # SE: olhos deslocados para a direita
        d.rectangle([ox + 31, y, ox + 32, y + 1], fill=eye); d.rectangle([ox + 37, y, ox + 38, y + 1], fill=eye)
    elif row == 2:  # E: um olho + nariz para a direita
        d.rectangle([ox + 36, y, ox + 37, y + 1], fill=eye); d.rectangle([ox + 40, y + 2, ox + 45, y + 4], fill=(250, 220, 190), outline=OUTLINE)
    elif row == 3:  # NE: marca pequena atrás à direita
        d.rectangle([ox + 38, y, ox + 39, y + 3], fill=(120, 60, 20))
    # N: sem olhos (costas) — cabelo
    if row >= 3:
        d.rectangle([ox + 24, oy + 4 + bob, ox + 36 if row == 3 else ox + 39, oy + 12 + bob], fill=(120, 60, 20))
    # barra de quadro (largura = índice + 1) para ver a animação
    d.rectangle([ox + 1, oy + 1, ox + 1 + frame * 2, oy + 2], fill=(255, 255, 255))


def sheet(frames: int, name: str) -> None:
    img = Image.new("RGBA", (FRAME * frames, FRAME * 5), (0, 0, 0, 0))
    d = Scaled(ImageDraw.Draw(img))
    for r in range(5):
        for f in range(frames):
            draw_frame(d, f * FRAME, r * FRAME, r, f, frames)
    img.save(OUT / name)


OUT.mkdir(parents=True, exist_ok=True)
for body in ("male", "female"):
    sheet(4, f"chr_traveler_{body}_idle.png")
    sheet(8, f"chr_traveler_{body}_walk.png")
sw, sh = FRAME // 2, FRAME // 4
shadow = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
ImageDraw.Draw(shadow).ellipse([0, 0, sw - 1, sh - 1], fill=(20, 10, 40, 255))
shadow.save(OUT / "chr_shadow.png")
