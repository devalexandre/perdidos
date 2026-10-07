#!/usr/bin/env python3
"""Kit de interface v2 (05/10/2026): moldura de madeira escura com cravos de ouro envelhecido, miolo de
pergaminho, botoes de couro vermelho-terroso, espacos de item em pergaminho rebaixado e dica em madeira escura.
So usa cores da paleta mestra (paleta-mestra.gpl). Reescreve SO as pecas do kit (nao mexe em emotes/cursores):
  ui_panel, ui_button_normal/hover/pressed, ui_item_slot(_selected), ui_tooltip, ui_dialogue_box, ui_name_plate.
Mesmos tamanhos e margens 9-slice do ui_kit.json. Rodar da raiz do projeto Godot:
  python3 tools/art/ui/gen_ui_kit_v2.py"""
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'ui')
C = {  # paleta mestra
    'm1': (58, 36, 24), 'm2': (107, 66, 38), 'm3': (156, 106, 60), 'm4': (201, 152, 94),
    'o1': (90, 58, 16), 'o2': (168, 116, 30), 'o3': (230, 180, 58), 'o4': (250, 229, 140),
    'v1': (74, 20, 20), 'v2': (156, 42, 38), 'v3': (217, 85, 58),
    'p1': (74, 58, 46), 'p2': (140, 116, 88), 'p3': (201, 176, 138), 'p4': (242, 230, 200),
    'e1': (59, 34, 25),  # pele escura 1 (contorno quente)
    'K': (22, 19, 28),
}


def img(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), C[c] + (255,))


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(im, x, y, c)


def hline(im, x0, x1, y, c):
    for x in range(x0, x1 + 1):
        px(im, x, y, c)


def vline(im, x, y0, y1, c):
    for y in range(y0, y1 + 1):
        px(im, x, y, c)


def stud(im, x, y):
    """Cravo de ouro envelhecido 3x3."""
    rect(im, x, y, x + 2, y + 2, 'o2')
    px(im, x, y, 'o4'); px(im, x + 1, y, 'o3'); px(im, x, y + 1, 'o3')
    px(im, x + 2, y + 2, 'o1')


def wood_frame(w, h, border, fill='p4', studs=True):
    """Moldura de madeira chanfrada (escura) com filete de ouro e miolo de pergaminho."""
    im = img(w, h)
    rect(im, 0, 0, w - 1, h - 1, 'K')
    rect(im, 1, 1, w - 2, h - 2, 'm2')
    hline(im, 1, w - 2, 1, 'm3'); vline(im, 1, 1, h - 2, 'm3')
    hline(im, 1, w - 2, h - 2, 'm1'); vline(im, w - 2, 1, h - 2, 'm1')
    # veio da madeira
    for y in range(2, border - 2):
        for x in range(3 + (y * 5) % 7, w - 3, 9):
            px(im, x, y, 'm1')
            px(im, x + 1, y, 'm1')
    for y in range(h - border + 2, h - 2):
        for x in range(5 + (y * 3) % 7, w - 3, 9):
            px(im, x, y, 'm1')
    for x in range(2, border - 2):
        for y in range(4 + (x * 5) % 7, h - 4, 9):
            px(im, x, y, 'm1')
            px(im, w - 1 - x, y + 2, 'm1')
    # filete de ouro + sombra interna
    b = border - 2
    rect(im, b, b, w - 1 - b, h - 1 - b, 'o2')
    hline(im, b, w - 1 - b, b, 'o3'); vline(im, b, b, h - 1 - b, 'o3')
    rect(im, b + 1, b + 1, w - 2 - b, h - 2 - b, 'e1')
    # miolo liso (sem filetes dentro da área do 9-slice: o centro é repetido e marcaria uma grade)
    rect(im, border, border, w - 1 - border, h - 1 - border, fill)
    if studs:
        for (x, y) in ((2, 2), (w - 5, 2), (2, h - 5), (w - 5, h - 5)):
            stud(im, x, y)
    return im


def panel():
    return wood_frame(48, 48, 8)


def dialogue_box():
    im = wood_frame(96, 48, 12)
    # ornamento de ouro no meio das bordas de cima e de baixo
    for cy, d in ((1, 1), (46, -1)):
        hline(im, 44, 51, cy, 'o2')
        hline(im, 45, 50, cy + d, 'o3')
        hline(im, 46, 49, cy + 2 * d, 'o4')
    return im


def button(state):
    w, h = 32, 16
    im = img(w, h)
    fill, hi, lo, rim = {
        'normal': ('v2', 'v3', 'v1', 'o2'),
        'hover': ('v2', 'o3', 'v1', 'o4'),
        'pressed': ('v1', 'v1', 'v2', 'o1'),
    }[state]
    rect(im, 1, 0, w - 2, h - 1, 'K'); rect(im, 0, 1, w - 1, h - 2, 'K')
    rect(im, 1, 1, w - 2, h - 2, rim)
    rect(im, 2, 2, w - 3, h - 3, fill)
    if state == 'pressed':
        hline(im, 2, w - 3, 2, 'K')
        vline(im, 2, 2, h - 3, 'K')
    else:
        hline(im, 2, w - 3, 2, hi)
        vline(im, 2, 3, h - 4, hi)
        hline(im, 2, w - 3, h - 3, lo)
        vline(im, w - 3, 3, h - 3, lo)
        # costura do couro
        for x in range(6, w - 6, 3):
            px(im, x, h - 5, lo)
    # cantos do aro em ouro mais claro
    for (x, y) in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        px(im, x, y, 'o4' if state == 'hover' else 'o3')
    return im


def item_slot(selected=False):
    im = img(36, 36)
    rect(im, 0, 0, 35, 35, 'o3' if selected else 'm2')
    rect(im, 1, 1, 34, 34, 'o2' if selected else 'p2')
    rect(im, 2, 2, 33, 33, 'p3')
    # rebaixo: sombra em cima/esquerda, luz embaixo/direita
    hline(im, 2, 33, 2, 'p2'); vline(im, 2, 2, 33, 'p2')
    hline(im, 3, 33, 33, 'p4'); vline(im, 33, 3, 33, 'p4')
    if selected:
        hline(im, 0, 35, 0, 'o4'); vline(im, 0, 0, 35, 'o4')
        for (x, y) in ((0, 0), (35, 0), (0, 35), (35, 35)):
            px(im, x, y, 'o1')
    return im


def tooltip():
    im = img(16, 16)
    rect(im, 0, 0, 15, 15, 'K')
    rect(im, 1, 1, 14, 14, 'o2')
    rect(im, 2, 2, 13, 13, 'm1')
    hline(im, 2, 13, 2, 'm2')
    for (x, y) in ((1, 1), (14, 1), (1, 14), (14, 14)):
        px(im, x, y, 'o4')
    return im


def name_plate():
    im = img(24, 12)
    rect(im, 1, 0, 22, 11, 'K'); rect(im, 0, 1, 23, 10, 'K')
    rect(im, 1, 1, 22, 10, 'o2')
    rect(im, 2, 2, 21, 9, 'v2')
    hline(im, 2, 21, 2, 'v3'); hline(im, 2, 21, 9, 'v1')
    for (x, y) in ((1, 1), (22, 1), (1, 10), (22, 10)):
        px(im, x, y, 'o4')
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {
        'ui_panel.png': panel(),
        'ui_dialogue_box.png': dialogue_box(),
        'ui_button_normal.png': button('normal'),
        'ui_button_hover.png': button('hover'),
        'ui_button_pressed.png': button('pressed'),
        'ui_item_slot.png': item_slot(False),
        'ui_item_slot_selected.png': item_slot(True),
        'ui_tooltip.png': tooltip(),
        'ui_name_plate.png': name_plate(),
    }
    for name, im in files.items():
        im.save(os.path.join(OUT, name))
        print('ok', name, im.size)


if __name__ == '__main__':
    main()
