"""Gera camadas sobrepostas DESCARTÁVEIS (paper doll) para o teste de UI/visual de B, alinhadas quadro
a quadro com a arte real do Viajante (assets/characters/chr_traveler_<body>_{idle,walk}.png):
- head/test_hat: retângulo "chapéu" magenta sobre o topo da cabeça de cada quadro;
- weapon/test_stick: bastão ciano na lateral (frente) e variante _back azul-escura (costas).
Saída: tests/_stub_b/equipment/<slot>/<visual_id>/<body>_<anim>[_back].png
A C entrega as reais em assets/equipment/. Rodar: python3 tests/client/make_stub_overlays.py"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent.parent
SRC = ROOT / "assets" / "characters"
OUT = ROOT / "tests" / "_stub_b" / "equipment"
ROWS = 5
HAT = (230, 40, 200, 255)
HAT_EDGE = (90, 20, 80, 255)
STICK_FRONT = (40, 220, 230, 255)
STICK_BACK = (28, 42, 90, 255)
HAT_HEIGHT = 8
BRIM = 3
STICK_LEN = 44
STICK_W = 4


def head_box(im, x0, y0, fs):
    """Topo (primeira linha opaca) e centro horizontal da cabeça no quadro."""
    top = None
    for y in range(fs):
        xs = [x for x in range(fs) if im.getpixel((x0 + x, y0 + y))[3] > 0]
        if xs:
            if top is None:
                top = y
            if y - top >= 6:
                return top, (min(xs) + max(xs)) // 2, xs
    return None, None, None


def body_center(im, x0, y0, fs):
    xs = [x for y in range(fs // 2, fs) for x in range(fs) if im.getpixel((x0 + x, y0 + y))[3] > 0]
    return ((min(xs) + max(xs)) // 2, min(xs), max(xs)) if xs else (fs // 2, fs // 2, fs // 2)


def make(body, anim):
    im = Image.open(SRC / f"chr_traveler_{body}_{anim}.png").convert("RGBA")
    fs = im.height // ROWS
    cols = im.width // fs
    hat = Image.new("RGBA", im.size, (0, 0, 0, 0))
    front = Image.new("RGBA", im.size, (0, 0, 0, 0))
    back = Image.new("RGBA", im.size, (0, 0, 0, 0))
    dh, df, db = ImageDraw.Draw(hat), ImageDraw.Draw(front), ImageDraw.Draw(back)
    for r in range(ROWS):
        for c in range(cols):
            x0, y0 = c * fs, r * fs
            top, cx, xs = head_box(im, x0, y0, fs)
            if top is None:
                continue
            half = (max(xs) - min(xs)) // 2 + BRIM
            dh.rectangle([x0 + cx - half, y0 + top - 2, x0 + cx + half, y0 + top + 1], fill=HAT, outline=HAT_EDGE)
            dh.rectangle([x0 + cx - half + BRIM + 2, y0 + top - HAT_HEIGHT, x0 + cx + half - BRIM - 2, y0 + top - 2],
                         fill=HAT, outline=HAT_EDGE)
            bx, lo, hi = body_center(im, x0, y0, fs)
            # Mão "direita" na tela: lado +x; S/SE/E na frente, NE/N atrás (costas).
            sx = x0 + hi - 2
            sy = y0 + fs - 12 - STICK_LEN
            df.rectangle([sx, sy, sx + STICK_W - 1, sy + STICK_LEN], fill=STICK_FRONT)
            db.rectangle([sx, sy, sx + STICK_W - 1, sy + STICK_LEN], fill=STICK_BACK)
    for slot, vid, img, suffix in [("head", "test_hat", hat, ""), ("weapon", "test_stick", front, ""),
                                   ("weapon", "test_stick", back, "_back")]:
        d = OUT / slot / vid
        d.mkdir(parents=True, exist_ok=True)
        img.save(d / f"{body}_{anim}{suffix}.png")


for body in ("male", "female"):
    for anim in ("idle", "walk"):
        make(body, anim)
print("ok", OUT)
