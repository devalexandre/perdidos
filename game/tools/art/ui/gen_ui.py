#!/usr/bin/env python3
"""Gera o kit de interface em pixel art (paleta mestra, tons de pergaminho e madeira) e os 6 baloes de emote.
Desenho por codigo e mapas ASCII, sem IA. Rodar da raiz do projeto Godot:  python3 tools/art/ui/gen_ui.py
Saida: assets/ui/*.png, assets/ui/emotes/emote_<id>.png e assets/ui/ui_kit.json (margens 9-slice e cursores)."""
import json, os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'ui')
C = {  # paleta mestra (assets/_reference/style_anchor/paleta-mestra.gpl)
    'K': (22, 19, 28), 'W': (252, 250, 245),
    'w1': (50, 28, 24), 'w2': (129, 50, 43), 'w3': (177, 68, 50), 'w4': (238, 178, 72),
    'p1': (82, 56, 44), 'p2': (150, 105, 75), 'p3': (221, 178, 119), 'p4': (255, 239, 190),
    'g1': (90, 58, 16), 'g2': (184, 121, 28), 'g3': (238, 178, 72), 'g4': (255, 219, 88),
    'r1': (86, 18, 28), 'r2': (146, 30, 38), 'r3': (219, 55, 52), 'r4': (255, 132, 103),
    'b1': (22, 42, 92), 'b2': (37, 99, 176), 'b3': (75, 165, 235), 'b4': (166, 225, 255),
    's1': (43, 38, 48), 's2': (86, 80, 94), 's3': (140, 135, 148), 's4': (199, 195, 204),
    'k1': (107, 62, 46), 'k2': (176, 113, 90), 'k3': (224, 163, 134), 'k4': (247, 210, 184),
    'n1': (90, 31, 58), 'n2': (184, 61, 111), 'n3': (238, 103, 166), 'n4': (255, 181, 214),
}


def img(w, h): return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height: im.putpixel((x, y), C[c] + (255,))


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): px(im, x, y, c)


def ascii_draw(im, ox, oy, rows, key):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in key: px(im, ox + x, oy + y, key[ch])


def frame(w, h, outer='w1', mid='w3', hi='w4', lo='w2', fill='p4', fill_hi=None, border=4, rivets=True):
    """Moldura de madeira chanfrada com miolo de pergaminho (9-slice)."""
    im = img(w, h)
    rect(im, 0, 0, w - 1, h - 1, outer)
    rect(im, 1, 1, w - 2, h - 2, mid)
    for x in range(1, w - 1): px(im, x, 1, hi)
    for y in range(1, h - 1): px(im, 1, y, hi)
    for x in range(1, w - 1): px(im, x, h - 2, lo)
    for y in range(1, h - 1): px(im, w - 2, y, lo)
    # veio da madeira
    for y in range(2, border - 1):
        for x in range(3 + (y % 2) * 3, w - 3, 7): px(im, x, y, lo)
    rect(im, border - 1, border - 1, w - border, h - border, outer)
    rect(im, border, border, w - border - 1, h - border - 1, fill)
    for x in range(border, w - border): px(im, x, border, 'p3')
    for y in range(border, h - border): px(im, border, y, 'p3')
    if fill_hi:
        for x in range(border + 1, w - border - 1): px(im, x, h - border - 1, fill_hi)
    if rivets:
        for (x, y) in ((1, 1), (w - 3, 1), (1, h - 3), (w - 3, h - 3)):
            rect(im, x, y, x + 1, y + 1, 'g3'); px(im, x, y, 'g4'); px(im, x + 1, y + 1, 'g2')
    return im


def button(state):
    w, h = 32, 16
    im = img(w, h)
    fill = {'normal': 'w3', 'hover': 'w4', 'pressed': 'w2'}[state]
    hi = {'normal': 'w4', 'hover': 'g4', 'pressed': 'w1'}[state]
    lo = {'normal': 'w2', 'hover': 'w3', 'pressed': 'w3'}[state]
    rect(im, 1, 0, w - 2, h - 1, 'w1'); rect(im, 0, 1, w - 1, h - 2, 'w1')
    rect(im, 1, 1, w - 2, h - 2, fill)
    for x in range(2, w - 2): px(im, x, 1, hi)
    for y in range(2, h - 3): px(im, 1, y, hi)
    for x in range(2, w - 2): px(im, x, h - 2, lo)
    for y in range(2, h - 2): px(im, w - 2, y, lo)
    if state == 'hover':
        for x in range(2, w - 2): px(im, x, 0, 'g2')
    if state != 'pressed':  # veio
        for x in range(5, w - 5, 6): px(im, x, h // 2, lo)
    return im


def item_slot(selected=False):
    im = img(36, 36)
    rect(im, 0, 0, 35, 35, 'g2' if selected else 'p1')
    rect(im, 1, 1, 34, 34, 'p2')
    rect(im, 2, 2, 33, 33, 'p3')
    for x in range(2, 34): px(im, x, 2, 'p2')
    for y in range(2, 34): px(im, 2, y, 'p2')
    if selected:
        for x in range(1, 35): px(im, x, 1, 'g4'); px(im, x, 34, 'g3')
        for y in range(1, 35): px(im, 1, y, 'g4'); px(im, 34, y, 'g3')
    return im


def tooltip():
    im = img(16, 16)
    rect(im, 0, 0, 15, 15, 'g2'); rect(im, 1, 1, 14, 14, 's1')
    for x in range(1, 15): px(im, x, 1, 's2')
    px(im, 0, 0, 'g4'); px(im, 15, 0, 'g4'); px(im, 0, 15, 'g1'); px(im, 15, 15, 'g1')
    return im


def dialogue_box():
    im = frame(96, 48, border=6, fill_hi='p3')
    # ornamentos dourados no meio das bordas de cima e de baixo
    for cx in (48,):
        for y in (0, 47):
            rect(im, cx - 3, y, cx + 2, y, 'g2'); rect(im, cx - 2, max(0, y - 1) if y else 1, cx + 1, max(0, y - 1) if y else 1, 'g3')
    return im


def name_plate():
    im = img(24, 12)
    rect(im, 1, 0, 22, 11, 'w1'); rect(im, 0, 1, 23, 10, 'w1'); rect(im, 1, 1, 22, 10, 'r2')
    for x in range(2, 22): px(im, x, 1, 'r3')
    for x in range(2, 22): px(im, x, 10, 'r1')
    return im


CURSOR = [
    "K...........",
    "KK..........",
    "KaK.........",
    "KabK........",
    "KabbK.......",
    "KabbbK......",
    "KabbbbK.....",
    "KabbbbbK....",
    "KabbbbbbK...",
    "KabbbbbbbK..",
    "KabbbbbKKKK.",
    "KabbKbbK....",
    "KabK.KbbK...",
    "KaK..KbbK...",
    "KK....KbbK..",
    "K.....KbbK..",
    ".......KK...",
]


def cursor(interact=False):
    im = img(24, 24)
    ascii_draw(im, 0, 0, CURSOR, {'K': 'w1', 'a': 'g4', 'b': 'g3'})
    for y, row in enumerate(CURSOR):  # sombra a direita da ponta
        for x, ch in enumerate(row):
            if ch == 'b' and (x + 1 >= len(row) or row[x + 1] == 'K'): px(im, x, y, 'g2')
    if interact:  # balaozinho de fala com reticencias (falar / usar)
        bub = [
            ".KKKKKKKK.",
            "KWWWWWWWWK",
            "KWbWWbWWbK",
            "KWWWWWWWWK",
            ".KKKWWKKK.",
            "....KWK...",
            ".....K....",
        ]
        ascii_draw(im, 13, 0, bub, {'K': 'w1', 'W': 'W', 'b': 'w2'})
    return im


# ---------------------------------------------------------------- emotes (balao 32x32)
BUBBLE = [
    "......KKKKKKKKKKKKKKKKKKKK......",
    "....KKWWWWWWWWWWWWWWWWWWWWKK....",
    "...KWWWWWWWWWWWWWWWWWWWWWWWWK...",
    "..KWWWWWWWWWWWWWWWWWWWWWWWWWWK..",
    ".KWWWWWWWWWWWWWWWWWWWWWWWWWWWWK.",
    ".KWWWWWWWWWWWWWWWWWWWWWWWWWWWWK.",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWSK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWSK",
    "KWWWWWWWWWWWWWWWWWWWWWWWWWWWWWSK",
    ".KWWWWWWWWWWWWWWWWWWWWWWWWWWWSK.",
    ".KWWWWWWWWWWWWWWWWWWWWWWWWWWSSK.",
    "..KWWWWWWWWWWWWWWWWWWWWWWWSSSK..",
    "...KSWWWWWWWWWWWWWWWWWWWSSSSK...",
    "....KKSSSSSSSSSSSSSSSSSSSSKK....",
    "......KKKKKKWWSKKKKKKKKKKK......",
    "...........KWWSK................",
    "..........KWWSK.................",
    ".........KWSSK..................",
    ".........KSKK...................",
    ".........KK.....................",
]
ICONS = {
    'wave': ([
        "....K.K.K.......",
        "...KhKhKhK......",
        "...KhKhKhK.K....",
        "...KhKhKhKKhK...",
        "...KhhhhhKhhK...",
        ".K.KhhhhhhhK....",
        "KhKKhhhhhhhK....",
        "KhhKhhhhhhK.....",
        ".KhhhhhhhhK.....",
        "..KhhhhhhK......",
        "...KhhhhK.......",
        "....KKKK........",
    ], {'K': 'k1', 'h': 'k3'}, [(12, 1, 'b3'), (13, 3, 'b3'), (13, 5, 'b3'), (14, 2, 'b3'), (14, 6, 'b3')]),
    'sit': ([
        "..KKKK..........",
        "..KwwK..........",
        "..KwwK..........",
        "..KwwK..........",
        "..KwwK..........",
        "..KwwKKKKKKKK...",
        "..KwwwwwwwwwK...",
        "..KKKKKKKKKKK...",
        "..KwK.....KwK...",
        "..KwK.....KwK...",
        "..KwK.....KwK...",
        "..KKK.....KKK...",
    ], {'K': 'w1', 'w': 'w3'}, [(13, 1, 'b2'), (14, 1, 'b2'), (14, 2, 'b2'), (13, 3, 'b2'), (14, 3, 'b2')]),
    'laugh': ([
        "....KKKKKK......",
        "..KKyyyyyyKK....",
        ".KyyyyyyyyyyK...",
        ".KyKKyyyyKKyK...",
        "KyKyyKyyKyyKyK..",
        "KyyyyyyyyyyyyK..",
        "KyyKKKKKKKKyyK..",
        "KyyKmmmmmmKyyK..",
        ".KyyKmrrmKyyK...",
        ".KyyyKKKKyyyK...",
        "..KKyyyyyyKK....",
        "....KKKKKK......",
    ], {'K': 'g1', 'y': 'g3', 'm': 'r1', 'r': 'r3'}, [(1, 2, 'g4'), (2, 1, 'g4')]),
    'cry': ([
        "....KKKKKK......",
        "..KKyyyyyyKK....",
        ".KyyyyyyyyyyK...",
        ".KyKKKyyKKKyK...",
        "KyybbyyyybbyyK..",
        "KyybyyyyyybyyK..",
        "KyybyKKKKybyyK..",
        "KyybKyyyyKbyyK..",
        ".KybyyyyyybyK...",
        ".KyByyyyyyByK...",
        "..KBKyyyyKBK....",
        "....KKKKKK......",
    ], {'K': 'g1', 'y': 'g3', 'b': 'b3', 'B': 'b2'}, [(1, 2, 'g4'), (2, 1, 'g4')]),
    'angry': ([
        "..RRRR....RRRR..",
        ".RrrrR....RrrrR.",
        ".RrrR......RrrR.",
        ".RrR........RrR.",
        ".RR..........RR.",
        "................",
        "................",
        ".RR..........RR.",
        ".RrR........RrR.",
        ".RrrR......RrrR.",
        ".RrrrR....RrrrR.",
        "..RRRR....RRRR..",
    ], {'R': 'r2', 'r': 'r3'}, []),
    'heart': ([
        "..KKK...KKK.....",
        ".KrrrK.KrrrK....",
        "KrwwrrKrrrrrK...",
        "KrwrrrrrrrrrK...",
        "KrrrrrrrrrrRK...",
        "KrrrrrrrrrrRK...",
        ".KrrrrrrrrRK....",
        "..KrrrrrrRK.....",
        "...KrrrrRK......",
        "....KrrRK.......",
        ".....KRK........",
        "......K.........",
    ], {'K': 'r1', 'r': 'r3', 'R': 'r2', 'w': 'r4'}, []),
}


def emote(eid):
    im = img(32, 32)
    ascii_draw(im, 0, 1, BUBBLE, {'K': 'w1', 'W': 'W', 'S': 'p4'})
    rows, key, extra = ICONS[eid]
    ox = 8; oy = 6
    ascii_draw(im, ox, oy, rows, key)
    for (x, y, c) in extra: px(im, ox + x, oy + y, c)
    return im


def main():
    os.makedirs(os.path.join(OUT, 'emotes'), exist_ok=True)
    kit = {}
    def save(name, im, **meta):
        im.save(os.path.join(OUT, name)); kit[name] = dict(size=list(im.size), **meta)
    save('ui_panel.png', frame(48, 48), nine_slice=[8, 8, 8, 8], note='janela/painel; miolo de pergaminho')
    for st in ('normal', 'hover', 'pressed'):
        save(f'ui_button_{st}.png', button(st), nine_slice=[5, 5, 5, 5])
    save('ui_item_slot.png', item_slot(), nine_slice=[3, 3, 3, 3], note='espaco 36x36 para icone 32x32 (2 px de borda)')
    save('ui_item_slot_selected.png', item_slot(True), nine_slice=[3, 3, 3, 3])
    save('ui_tooltip.png', tooltip(), nine_slice=[4, 4, 4, 4], note='fundo escuro; texto claro')
    save('ui_dialogue_box.png', dialogue_box(), nine_slice=[12, 12, 12, 12])
    save('ui_name_plate.png', name_plate(), nine_slice=[4, 4, 4, 4], note='placa do nome de quem fala no dialogo')
    save('cursor_normal.png', cursor(False), hotspot=[0, 0])
    save('cursor_interact.png', cursor(True), hotspot=[0, 0])
    for e in ('wave', 'sit', 'laugh', 'cry', 'angry', 'heart'):
        emote(e).save(os.path.join(OUT, 'emotes', f'emote_{e}.png')); kit[f'emotes/emote_{e}.png'] = dict(size=[32, 32])
    kit['_doc'] = ('Kit de UI (C). nine_slice = [esquerda, cima, direita, baixo] em px para StyleBoxTexture/NinePatchRect '
                   '(texture_filter nearest, escala inteira). hotspot = ponto do clique do cursor. Cores da paleta mestra.')
    kit['_colors'] = {'text_dark': '#3a2418', 'text_light': '#f2e6c8', 'text_gold': '#e6b43a',
                      'rarity': {'common': '#fcfaf5', 'uncommon': '#5aa048', 'rare': '#5a90e0', 'epic': '#8e66c4'}}
    json.dump(kit, open(os.path.join(OUT, 'ui_kit.json'), 'w'), ensure_ascii=False, indent=1)
    print('ok', len(kit))


if __name__ == '__main__':
    main()
