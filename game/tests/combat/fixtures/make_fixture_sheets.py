"""Folhas PROVISÓRIAS (descartáveis) de monstros de teste do combate (Agente K), até W entregar a
arte de assets/monsters/. Mesmo formato das folhas de personagem: 5 linhas (S, SE, E, NE, N),
quadro quadrado, sufixos _idle, _walk, _attack, _hit, _death. Um "slime" com olhos que indicam o
lado para onde olha. Uso: python3 tests/combat/fixtures/make_fixture_sheets.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent / "art"
FRAME = 64
ROWS = 5  # S, SE, E, NE, N
SPECIES = {
    "critter": (126, 196, 90),
    "sturdy": (150, 120, 90),
    "brute": (200, 70, 60),
}
ANIMS = {"idle": 2, "walk": 4, "attack": 3, "hit": 2, "death": 4}
OUTLINE = (22, 19, 28, 255)
EYE = (252, 250, 245, 255)
PUPIL = (22, 19, 28, 255)
# deslocamento horizontal dos olhos por linha (S, SE, E, NE, N); None = de costas
EYE_SHIFT = [0, 6, 12, 7, None]
EYE_Y = [0, 0, 0, -3, 0]


def blob(d: ImageDraw.ImageDraw, ox: int, oy: int, color, w: int, h: int, lift: int = 0,
         lean: int = 0, alpha: int = 255):
    feet_y = oy + FRAME - 4 - lift
    cx = ox + FRAME // 2 + lean
    box = [cx - w // 2, feet_y - h, cx + w // 2, feet_y]
    d.ellipse(box, fill=color + (alpha,), outline=OUTLINE[:3] + (alpha,), width=2)
    # brilho
    d.ellipse([cx - w // 4, feet_y - h + 4, cx - w // 4 + 5, feet_y - h + 8], fill=(255, 255, 255, alpha // 2))
    return cx, feet_y - h


def eyes(d, cx, top, row, h, alpha=255):
    shift = EYE_SHIFT[row]
    if shift is None:
        return
    y = top + h // 3 + EYE_Y[row]
    for dx in (-6, 6):
        if row == 2 and dx < 0:
            continue
        x = cx + dx + shift // 2
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=EYE[:3] + (alpha,))
        d.ellipse([x - 1 + (1 if shift else 0), y - 1, x + 1 + (1 if shift else 0), y + 1], fill=PUPIL[:3] + (alpha,))


def frame(d, ox, oy, color, anim, i, row):
    w, h, lift, lean, alpha, tint = 40, 30, 0, 0, 255, color
    face = EYE_SHIFT[row] if EYE_SHIFT[row] is not None else 0
    if anim == "idle":
        h += (0, 2)[i]
    elif anim == "walk":
        lift = (0, 3, 0, 3)[i]
        w += (0, -4, 0, -4)[i]
        h += (0, 4, 0, 4)[i]
    elif anim == "attack":
        lean = (0, face, face // 2)[i]
        w += (0, 8, 2)[i]
        h += (4, -4, 0)[i]
    elif anim == "hit":
        tint = (255, 90, 90) if i == 0 else color
        lean = (-3, 0)[i]
    elif anim == "death":
        h = (30, 20, 10, 5)[i]
        w = (40, 46, 50, 52)[i]
        alpha = (255, 220, 170, 120)[i]
    cx, top = blob(d, ox, oy, tint, w, h, lift, lean, alpha)
    if anim != "death" or i < 2:
        eyes(d, cx, top, row, h, alpha)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, color in SPECIES.items():
        for anim, frames in ANIMS.items():
            img = Image.new("RGBA", (FRAME * frames, FRAME * ROWS), (0, 0, 0, 0))
            d = ImageDraw.Draw(img)
            for row in range(ROWS):
                for i in range(frames):
                    frame(d, i * FRAME, row * FRAME, color, anim, i, row)
            img.save(OUT / f"mon_test_{name}_{anim}.png")
    print("ok", OUT)


if __name__ == "__main__":
    main()
