#!/usr/bin/env python3
"""Gera icones pixel art de flechas (32x32) na paleta mestra para o sistema de municao.
Tipos de flecha:
  - simple_arrow: ponta de pedra lascada, madeira simples, penas claras
  - iron_arrow: ponta de ferro forjado farpada, haste escura, penas cinzas
  - silver_arrow: ponta de prata brilhante com brilho, penas alvas
  - thorn_arrow: ponta de espinho de mandacaru, haste com brotos, penas verdes
  - fire_arrow: ponta em chamas com brasa, haste chamuscada, penas rubras
  - poison_arrow: ponta embebida em peconha esmeralda gotejante, penas violeta
  - crystal_arrow: ponta lapidada de cristal de Ratanaba, penas prismáticas
  - lightning_arrow: ponta de fulgurito com faíscas elétricas, penas azuis
"""
import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(HERE, '..'))
import palette as PALM

PN = {n: c for c, n in PALM.load_palette()}
S = 32

def P(name):
    return PN[name]

def nearest_color(rgb):
    min_d = float('inf')
    best = (0, 0, 0)
    for c in PALM.colors():
        dr = int(rgb[0]) - int(c[0])
        dg = int(rgb[1]) - int(c[1])
        db = int(rgb[2]) - int(c[2])
        d = dr * dr + dg * dg + db * db
        if d < min_d:
            min_d = d
            best = c
    return best

class ArrowCanvas:
    def __init__(self):
        self.img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.img)

    def px(self, x, y, col):
        if 0 <= x < S and 0 <= y < S:
            self.img.putpixel((int(x), int(y)), (col[0], col[1], col[2], 255))

    def line(self, x0, y0, x1, y1, col):
        self.draw.line([(x0, y0), (x1, y1)], fill=(col[0], col[1], col[2], 255))

    def poly(self, pts, col):
        self.draw.polygon(pts, fill=(col[0], col[1], col[2], 255))

    def finish(self, outline_color=None):
        """Aplica contorno de 1px usando tom escuro da paleta mestra."""
        arr = np.array(self.img)
        alpha = arr[:, :, 3] > 0
        h, w = alpha.shape
        out = arr.copy()
        
        # Detecta bordas
        edge = np.zeros_like(alpha)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                sy0 = max(0, -dy)
                sy1 = min(h, h - dy)
                sx0 = max(0, -dx)
                sx1 = min(w, w - dx)
                dy0 = max(0, dy)
                dy1 = min(h, h + dy)
                dx0 = max(0, dx)
                dx1 = min(w, w + dx)
                edge[dy0:dy1, dx0:dx1] |= (~alpha[dy0:dy1, dx0:dx1]) & alpha[sy0:sy1, sx0:sx1]

        # Contorno na borda exterior
        for y in range(h):
            for x in range(w):
                if edge[y, x]:
                    # Pega a cor do pixel adjacente opaco
                    neighbor_rgb = None
                    for ny in (y-1, y, y+1):
                        for nx in (x-1, x, x+1):
                            if 0 <= nx < w and 0 <= ny < h and alpha[ny, nx]:
                                neighbor_rgb = arr[ny, nx, :3]
                                break
                        if neighbor_rgb is not None:
                            break
                    if outline_color:
                        c = outline_color
                    elif neighbor_rgb is not None:
                        dark_rgb = (int(neighbor_rgb[0] * 0.4), int(neighbor_rgb[1] * 0.4), int(neighbor_rgb[2] * 0.4))
                        c = nearest_color(dark_rgb)
                    else:
                        c = P('Base 1')
                    out[y, x] = [c[0], c[1], c[2], 255]

        # Garante que todo pixel está estritamente na paleta mestra
        final_img = Image.fromarray(out, 'RGBA')
        final_arr = np.array(final_img)
        for y in range(S):
            for x in range(S):
                if final_arr[y, x, 3] > 127:
                    final_arr[y, x, 3] = 255
                    c = nearest_color(tuple(final_arr[y, x, :3]))
                    final_arr[y, x, 0] = c[0]
                    final_arr[y, x, 1] = c[1]
                    final_arr[y, x, 2] = c[2]
                else:
                    final_arr[y, x] = [0, 0, 0, 0]
        return Image.fromarray(final_arr, 'RGBA')


def draw_base_arrow(shaft_ramp, feather_ramp, head_ramp, binding_col, head_type='broadhead', extras=None):
    """Desenha flecha na diagonal de (5,26) a (26,5)."""
    cv = ArrowCanvas()
    
    # 1. HASTE (Shaft) - diagonal de x=6, y=25 ate x=22, y=9
    # Desenhamos com 2 camadas para relevo (luz em cima-esquerda)
    for i in range(17):
        x = 6 + i
        y = 25 - i
        cv.px(x, y, shaft_ramp[2])      # corpo da haste
        cv.px(x - 1, y, shaft_ramp[3])  # luz na haste (topo)
        cv.px(x, y + 1, shaft_ramp[1])  # sombra embaixo

    # 2. PENAS / EMPENAGEM (Fletching) - de x=5..11
    # Vane superior-esquerda
    cv.poly([(5, 25), (4, 21), (7, 19), (8, 20), (10, 18), (11, 20), (8, 23)], feather_ramp[2])
    cv.line(5, 23, 8, 20, feather_ramp[3]) # nervura da pena
    # Vane inferior-direita
    cv.poly([(7, 27), (11, 27), (13, 24), (12, 23), (14, 22), (12, 21), (9, 24)], feather_ramp[1])
    cv.line(8, 26, 11, 23, feather_ramp[2])

    # Detalhe do encaixe / nock na extremidade traseira
    cv.px(4, 27, shaft_ramp[0])
    cv.px(3, 28, P('Base 1')) # ranhura onde encaixa a corda

    # Amarras de fio (bindings) junto às penas
    cv.px(12, 19, binding_col)
    cv.px(13, 18, binding_col)
    cv.px(11, 20, binding_col)

    # Amarras junto à ponta
    cv.px(20, 11, binding_col)
    cv.px(21, 10, binding_col)

    # 3. PONTA DA FLECHA (Arrowhead)
    if head_type == 'broadhead':
        # Ponta de ferro/aço farpada
        cv.poly([(20, 8), (22, 6), (28, 3), (25, 9), (23, 11), (21, 9)], head_ramp[2])
        cv.poly([(21, 7), (23, 5), (28, 3), (26, 5)], head_ramp[3]) # crista iluminada
        cv.poly([(23, 11), (24, 10), (28, 3), (25, 9)], head_ramp[1]) # rebarba sombreada
        cv.px(28, 3, head_ramp[3]) # ponta afiada extrema
    elif head_type == 'flint':
        # Ponta de pedra lascada triangular
        cv.poly([(20, 9), (22, 7), (27, 4), (25, 9), (22, 11)], head_ramp[2])
        cv.px(23, 7, head_ramp[3])
        cv.px(24, 6, head_ramp[3])
        cv.px(27, 4, head_ramp[3])
        cv.px(23, 9, head_ramp[1])
    elif head_type == 'silver':
        # Ponta de prata radiante elegante
        cv.poly([(19, 8), (22, 5), (28, 3), (26, 9), (23, 12)], head_ramp[2])
        cv.line(22, 9, 28, 3, head_ramp[3]) # fio de corte reluzente
        cv.px(28, 3, P('Base 2')) # brilho puro
        cv.px(27, 4, head_ramp[3])
    elif head_type == 'thorn':
        # Espinho de mandacaru / cacto curvado e rígido
        cv.poly([(20, 9), (21, 6), (25, 4), (28, 2), (26, 7), (23, 11)], head_ramp[2])
        cv.line(22, 8, 28, 2, head_ramp[3])
        cv.px(28, 2, head_ramp[3])
    elif head_type == 'fire':
        # Ponta em chamas
        cv.poly([(20, 9), (22, 6), (27, 4), (25, 9), (22, 11)], head_ramp[2])
        # Chamas ao redor da ponta
        cv.poly([(21, 5), (25, 1), (27, 3), (30, 2), (28, 6), (30, 8), (26, 10)], P('Vermelho 3'))
        cv.poly([(23, 4), (26, 2), (28, 4), (29, 6), (26, 8)], P('Ouro/amarelo 3'))
        cv.px(26, 3, P('Ouro/amarelo 4'))
        cv.px(27, 4, P('Base 2'))
    elif head_type == 'poison':
        # Ponta com veneno e gota
        cv.poly([(20, 9), (22, 6), (27, 4), (25, 9), (22, 11)], head_ramp[2])
        cv.poly([(23, 7), (26, 4), (28, 3), (26, 6)], head_ramp[3])
        # Gota de veneno escorrendo
        cv.px(25, 10, P('Verde folha 3'))
        cv.px(26, 11, P('Verde folha 4'))
        cv.px(26, 12, P('Verde folha 3'))
    elif head_type == 'crystal':
        # Ponta de cristal lapidada em losangos
        cv.poly([(20, 9), (22, 5), (28, 3), (26, 9), (22, 11)], head_ramp[2])
        cv.poly([(22, 6), (25, 4), (28, 3), (25, 7)], head_ramp[3])
        cv.px(28, 3, P('Base 2'))
        cv.px(24, 5, P('Base 2'))
    elif head_type == 'lightning':
        # Ponta de fulgurito em zigue-zague com faiscas
        cv.poly([(20, 9), (23, 6), (25, 7), (28, 3), (25, 9), (22, 11)], head_ramp[2])
        cv.line(22, 8, 28, 3, head_ramp[3])
        # Faíscas elétricas
        cv.px(29, 2, P('Ouro/amarelo 4'))
        cv.px(30, 5, P('Azul ceu 4'))
        cv.px(26, 1, P('Azul ceu 3'))

    if extras:
        extras(cv)

    return cv.finish()


# ------------------------------------------------------------------ GERADORES
def gen_simple_arrow():
    """Flecha Simples: haste de madeira comum, ponta de pedra lascada, penas claras."""
    shaft = [P('Madeira/cabelo 1'), P('Madeira/cabelo 2'), P('Madeira/cabelo 3'), P('Madeira/cabelo 4')]
    feather = [P('Pergaminho 1'), P('Pergaminho 2'), P('Pergaminho 3'), P('Pergaminho 4')]
    head = [P('Pedra/metal 1'), P('Pedra/metal 2'), P('Pedra/metal 3'), P('Pedra/metal 4')]
    return draw_base_arrow(shaft, feather, head, P('Madeira/cabelo 1'), head_type='flint')


def gen_iron_arrow():
    """Flecha de Ferro: ponta de ferro forjado farpada, haste reforçada, penas cinzas."""
    shaft = [P('Madeira/cabelo 1'), P('Madeira/cabelo 2'), P('Madeira/cabelo 2'), P('Madeira/cabelo 3')]
    feather = [P('Pedra/metal 1'), P('Pedra/metal 2'), P('Pedra/metal 3'), P('Pedra/metal 4')]
    head = [P('Pedra/metal 1'), P('Pedra/metal 2'), P('Pedra/metal 3'), P('Pedra/metal 4')]
    return draw_base_arrow(shaft, feather, head, P('Pedra/metal 1'), head_type='broadhead')


def gen_silver_arrow():
    """Flecha de Prata: ponta de prata polida, haste alva, penas de garça e brilho radiante."""
    shaft = [P('Pedra/metal 2'), P('Pedra/metal 3'), P('Pedra/metal 4'), P('Pergaminho 4')]
    feather = [P('Pergaminho 2'), P('Pergaminho 3'), P('Pergaminho 4'), P('Base 2')]
    head = [P('Pedra/metal 2'), P('Pedra/metal 3'), P('Pedra/metal 4'), P('Base 2')]
    def extras(cv):
        # Cruz de brilho místico perto da ponta
        cv.px(29, 2, P('Base 2'))
        cv.px(29, 1, P('Pedra/metal 4'))
        cv.px(29, 3, P('Pedra/metal 4'))
        cv.px(28, 2, P('Pedra/metal 4'))
        cv.px(30, 2, P('Pedra/metal 4'))
    return draw_base_arrow(shaft, feather, head, P('Pedra/metal 2'), head_type='silver', extras=extras)


def gen_thorn_arrow():
    """Flecha de Espinho: espinho rígido de mandacaru, haste com nós vegetais, penas verdes."""
    shaft = [P('Madeira/cabelo 1'), P('Madeira/cabelo 2'), P('Madeira/cabelo 3'), P('Verde folha 2')]
    feather = [P('Verde folha 1'), P('Verde folha 2'), P('Verde folha 3'), P('Verde folha 4')]
    head = [P('Madeira/cabelo 1'), P('Madeira/cabelo 2'), P('Madeira/cabelo 3'), P('Verde folha 3')]
    def extras(cv):
        # Pequenos espinhos brotando na haste
        cv.px(15, 14, P('Verde folha 4'))
        cv.px(18, 17, P('Madeira/cabelo 4'))
    return draw_base_arrow(shaft, feather, head, P('Verde folha 1'), head_type='thorn', extras=extras)


def gen_fire_arrow():
    """Flecha de Fogo: ponta incandescente com labaredas, haste chamuscada, penas vermelhas."""
    shaft = [P('Base 1'), P('Madeira/cabelo 1'), P('Madeira/cabelo 2'), P('Vermelho 2')]
    feather = [P('Vermelho 1'), P('Vermelho 2'), P('Vermelho 3'), P('Vermelho 4')]
    head = [P('Vermelho 2'), P('Vermelho 3'), P('Ouro/amarelo 3'), P('Ouro/amarelo 4')]
    def extras(cv):
        # Fagulhas flutuantes
        cv.px(22, 3, P('Ouro/amarelo 4'))
        cv.px(30, 10, P('Vermelho 3'))
        cv.px(18, 10, P('Vermelho 2'))
    return draw_base_arrow(shaft, feather, head, P('Vermelho 1'), head_type='fire', extras=extras)


def gen_poison_arrow():
    """Flecha Envenenada: ponta escorrendo peçonha esmeralda, penas violeta e amarra roxa."""
    shaft = [P('Base 1'), P('Madeira/cabelo 1'), P('Madeira/cabelo 2'), P('Verde folha 2')]
    feather = [P('Roxo 1'), P('Roxo 2'), P('Roxo 3'), P('Roxo 4')]
    head = [P('Verde folha 2'), P('Verde folha 3'), P('Verde folha 4'), P('Verde agua 4')]
    def extras(cv):
        # Gota caindo
        cv.px(27, 13, P('Verde folha 3'))
    return draw_base_arrow(shaft, feather, head, P('Roxo 1'), head_type='poison', extras=extras)


def gen_crystal_arrow():
    """Flecha de Cristal: ponta prismática lapidada de cristal rúnico, penas turquesa cintilantes."""
    shaft = [P('Pedra/metal 1'), P('Pedra/metal 2'), P('Azul ceu 2'), P('Azul ceu 3')]
    feather = [P('Verde agua 1'), P('Verde agua 2'), P('Verde agua 3'), P('Verde agua 4')]
    head = [P('Verde agua 2'), P('Verde agua 3'), P('Azul ceu 3'), P('Base 2')]
    def extras(cv):
        cv.px(29, 5, P('Verde agua 4'))
        cv.px(21, 3, P('Azul ceu 4'))
    return draw_base_arrow(shaft, feather, head, P('Pedra/metal 1'), head_type='crystal', extras=extras)


def gen_lightning_arrow():
    """Flecha do Trovão: ponta forjada de pedra de raio (fulgurito), penas de tempestade e faíscas."""
    shaft = [P('Azul ceu 1'), P('Azul ceu 2'), P('Azul ceu 3'), P('Ouro/amarelo 3')]
    feather = [P('Azul ceu 1'), P('Azul ceu 2'), P('Azul ceu 3'), P('Azul ceu 4')]
    head = [P('Azul ceu 2'), P('Azul ceu 3'), P('Ouro/amarelo 3'), P('Base 2')]
    def extras(cv):
        cv.px(19, 7, P('Ouro/amarelo 4'))
        cv.px(27, 8, P('Azul ceu 4'))
    return draw_base_arrow(shaft, feather, head, P('Azul ceu 1'), head_type='lightning', extras=extras)


ARROW_GENERATORS = {
    'simple_arrow': gen_simple_arrow,
    'iron_arrow': gen_iron_arrow,
    'silver_arrow': gen_silver_arrow,
    'thorn_arrow': gen_thorn_arrow,
    'fire_arrow': gen_fire_arrow,
    'poison_arrow': gen_poison_arrow,
    'crystal_arrow': gen_crystal_arrow,
    'lightning_arrow': gen_lightning_arrow,
}


def main():
    icons_dir = os.path.join(GAME, 'assets', 'items', 'icons')
    os.makedirs(icons_dir, exist_ok=True)
    
    print(f">> Gerando {len(ARROW_GENERATORS)} icones de flechas...")
    for item_id, gen_fn in ARROW_GENERATORS.items():
        img = gen_fn()
        out_path = os.path.join(icons_dir, f'icon_item_{item_id}.png')
        img.save(out_path)
        print(f"   [OK] {out_path} ({img.size[0]}x{img.size[1]})")

    print(">> Validando contra a paleta mestra...")
    val_cmd = f"python3 {os.path.join(GAME, 'tools', 'art', 'palette.py')} validate {' '.join([os.path.join(icons_dir, f'icon_item_{k}.png') for k in ARROW_GENERATORS])}"
    res = os.system(val_cmd)
    if res == 0:
        print(">> Todas as flechas passaram na validação da paleta mestra com 100% de conformidade!")
    else:
        print(">> AVISO: Houve erros na validação da paleta.")
        sys.exit(1)


if __name__ == '__main__':
    main()
