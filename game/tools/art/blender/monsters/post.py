#!/usr/bin/env python3
"""Pos-processamento do pipeline de monstros no Blender (docs/arte-monstros-blender.md).
  .tools/pyvenv/bin/python game/tools/art/blender/monsters/post.py <id> <estagio> [--work .work/b3]
        [--no-install] [--light -0.55,0.65,0.55]
Le <work>/npz/<id>_s<n>.npz (pecas, profundidade e normais por quadro, ja no tamanho final) e faz:
  1. cel shading: tom = faixa de N.L (luz de cima-esquerda) numa rampa de 4 cores da paleta mestra;
  2. contorno interno seletivo: pixel de uma peca ATRAS de outra peca vira linha (tom 0 da propria rampa, ou
     o contorno do material quando os materiais diferem); pecas 'noline' (olhos, brilhos) nao geram linha;
  3. contorno externo de 1 px colorido (tom escuro do material vizinho), nunca preto puro;
  4. recorte fixo por estagio: origem (pes) no centro horizontal; ponto mais baixo de todos os quadros na
     ultima linha - 1; avisa se algo for cortado;
  5. folhas no formato do jogo (linhas S, SE, E, NE, N; colunas = quadros) em assets/monsters/<id>/ e
     previas (prancha + GIFs) em <work>/preview/.
Todas as cores saem da paleta mestra (paleta-mestra.gpl)."""
import argparse, json, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
ROOT = os.path.dirname(GAME)
sys.path.insert(0, os.path.join(GAME, "tools", "art"))
import palette as PAL  # noqa: E402

PALETTE = [c for c, _ in PAL.load_palette()]
PN = {n: c for c, n in PAL.load_palette()}


def P(name):
    return PN[name]


# Rampas de 4 tons (escuro -> claro) + contorno. Nomes = paleta-mestra.gpl.
MATS = {
    "shell": dict(ramp=[P("Pele escura 2"), P("Pele escura 3"), P("Pele clara 2"), P("Pele clara 3")],
                  line=P("Pele clara 1"), out=P("Pele escura 1")),
    "skin": dict(ramp=[P("Pele escura 3"), P("Pele clara 2"), P("Pele clara 3"), P("Pele clara 4")],
                 line=P("Pele clara 2"), out=P("Pele clara 1")),
    "blush": dict(flat=P("Rosa 3"), out=P("Rosa 2")),
    "leg": dict(ramp=[P("Pele escura 2"), P("Pele escura 3"), P("Pele clara 2"), P("Pele clara 3")],
                line=P("Pele escura 2"), out=P("Pele escura 1")),
    "nose": dict(ramp=[P("Rosa 1"), P("Rosa 2"), P("Rosa 3"), P("Rosa 4")], line=P("Rosa 1"), out=P("Rosa 1")),
    "moss": dict(ramp=[P("Verde folha 1"), P("Verde folha 2"), P("Verde folha 3"), P("Verde folha 4")],
                 line=P("Verde folha 1"), out=P("Verde folha 1")),
    "claw": dict(ramp=[P("Pergaminho 2"), P("Pergaminho 3"), P("Pergaminho 4"), P("Base 2")],
                 line=P("Pergaminho 2"), out=P("Pergaminho 1")),
    "rock": dict(ramp=[P("Pedra/metal 1"), P("Pedra/metal 2"), P("Pedra/metal 3"), P("Pedra/metal 4")],
                 line=P("Pedra/metal 1"), out=P("Base 1")),
    # redemoinho
    "wind": dict(ramp=[P("Pergaminho 2"), P("Pergaminho 3"), P("Pergaminho 4"), P("Base 2")],
                 line=P("Pergaminho 2"), out=P("Pergaminho 1")),
    "dust": dict(ramp=[P("Madeira/cabelo 2"), P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 4")],
                 line=P("Madeira/cabelo 2"), out=P("Madeira/cabelo 1")),
    "dust_dark": dict(flat=P("Madeira/cabelo 1"), out=P("Madeira/cabelo 1")),
    "mouth": dict(flat=P("Madeira/cabelo 1"), out=P("Madeira/cabelo 1")),
    "cap": dict(ramp=[P("Vermelho 1"), P("Vermelho 2"), P("Vermelho 3"), P("Vermelho 4")], line=P("Vermelho 1"),
                out=P("Vermelho 1")),
    "cap_band": dict(ramp=[P("Vermelho 1"), P("Vermelho 1"), P("Vermelho 2"), P("Vermelho 3")], line=P("Vermelho 1"),
                     out=P("Vermelho 1")),
    "gold": dict(ramp=[P("Ouro/amarelo 1"), P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 4")],
                 line=P("Ouro/amarelo 1"), out=P("Ouro/amarelo 1")),
    "leaf_o": dict(ramp=[P("Vermelho 2"), P("Vermelho 3"), P("Vermelho 4"), P("Ouro/amarelo 4")], line=P("Vermelho 1"),
                   out=P("Vermelho 1")),
    "leaf_y": dict(ramp=[P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 4"), P("Ouro/amarelo 4")],
                   line=P("Ouro/amarelo 1"), out=P("Ouro/amarelo 1")),
    "leaf_g": dict(ramp=[P("Verde folha 2"), P("Verde folha 3"), P("Verde folha 4"), P("Verde folha 4")],
                   line=P("Verde folha 1"), out=P("Verde folha 1")),
    "leaf_r": dict(ramp=[P("Vermelho 1"), P("Vermelho 2"), P("Vermelho 3"), P("Vermelho 4")], line=P("Vermelho 1"),
                   out=P("Vermelho 1")),
    "pebble": dict(ramp=[P("Vermelho 1"), P("Pele escura 2"), P("Pele escura 3"), P("Pele escura 4")],
                   line=P("Vermelho 1"), out=P("Pele escura 1")),
    "wood": dict(ramp=[P("Madeira/cabelo 1"), P("Madeira/cabelo 2"), P("Madeira/cabelo 3"), P("Madeira/cabelo 4")],
                 line=P("Madeira/cabelo 1"), out=P("Madeira/cabelo 1")),
    "fur": dict(ramp=[P("Madeira/cabelo 1"), P("Madeira/cabelo 2"), P("Madeira/cabelo 3"), P("Madeira/cabelo 4")],
                 line=P("Madeira/cabelo 1"), out=P("Base 1")),
    "fur_light": dict(ramp=[P("Madeira/cabelo 2"), P("Madeira/cabelo 3"), P("Pergaminho 3"), P("Pergaminho 4")],
                       line=P("Madeira/cabelo 2"), out=P("Madeira/cabelo 1")),
    "fur_dark": dict(ramp=[P("Base 1"), P("Madeira/cabelo 1"), P("Madeira/cabelo 2"), P("Madeira/cabelo 3")],
                      line=P("Base 1"), out=P("Base 1")),
    "smoke": dict(ramp=[P("Pedra/metal 2"), P("Pedra/metal 3"), P("Pedra/metal 4"), P("Base 2")],
                  line=P("Pedra/metal 2"), out=P("Pedra/metal 2")),
    "amber": dict(ramp=[P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 4"), P("Base 2")],
                  line=P("Ouro/amarelo 2"), out=P("Vermelho 2")),
    # vaga-lume
    "bug": dict(ramp=[P("Verde folha 1"), P("Verde folha 2"), P("Verde folha 3"), P("Verde folha 4")],
                line=P("Verde folha 1"), out=P("Verde agua 1")),
    "bug_dark": dict(flat=P("Verde folha 1"), out=P("Verde agua 1")),
    "lamp0": dict(ramp=[P("Ouro/amarelo 1"), P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 3")],
                  line=P("Ouro/amarelo 1"), out=P("Ouro/amarelo 1")),
    "lamp1": dict(ramp=[P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 4"), P("Ouro/amarelo 4")],
                  line=P("Ouro/amarelo 2"), out=P("Ouro/amarelo 2")),
    "lamp2": dict(ramp=[P("Ouro/amarelo 3"), P("Ouro/amarelo 4"), P("Base 2"), P("Base 2")],
                  line=P("Ouro/amarelo 3"), out=P("Ouro/amarelo 3")),
    "lamp_off": dict(ramp=[P("Pedra/metal 1"), P("Pergaminho 1"), P("Pergaminho 2"), P("Pergaminho 3")],
                     line=P("Pedra/metal 1"), out=P("Base 1")),
    "lamp_rib": dict(ramp=[P("Vermelho 2"), P("Vermelho 2"), P("Vermelho 3"), P("Vermelho 3")], line=P("Vermelho 1"),
                     out=P("Vermelho 1")),
    "wing": dict(ramp=[P("Azul ceu 3"), P("Azul ceu 4"), P("Azul ceu 4"), P("Base 2")], line=P("Azul ceu 3"),
                 out=P("Azul ceu 2")),
    "wing_gold": dict(ramp=[P("Ouro/amarelo 3"), P("Ouro/amarelo 4"), P("Pergaminho 4"), P("Base 2")],
                      line=P("Ouro/amarelo 2"), out=P("Ouro/amarelo 2")),
    "wisp_b": dict(flat=P("Azul ceu 4"), out=P("Azul ceu 3")),
    # packs (outras nacoes)
    "fur_white": dict(ramp=[P("Pedra/metal 3"), P("Pedra/metal 4"), P("Pergaminho 4"), P("Base 2")],
                      line=P("Pedra/metal 3"), out=P("Azul ceu 1")),
    "fur_blue": dict(ramp=[P("Azul ceu 2"), P("Azul ceu 3"), P("Azul ceu 4"), P("Base 2")], line=P("Azul ceu 2"),
                     out=P("Azul ceu 1")),
    "spirit_flame": dict(flat=P("Azul ceu 4"), out=P("Azul ceu 2")),
    "fur_gold": dict(ramp=[P("Ouro/amarelo 1"), P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 4")],
                     line=P("Ouro/amarelo 1"), out=P("Madeira/cabelo 1")),
    "fur_tawny": dict(ramp=[P("Madeira/cabelo 2"), P("Madeira/cabelo 3"), P("Madeira/cabelo 4"), P("Pergaminho 4")],
                      line=P("Madeira/cabelo 2"), out=P("Madeira/cabelo 1")),
    "fur_brown": dict(ramp=[P("Madeira/cabelo 1"), P("Madeira/cabelo 2"), P("Madeira/cabelo 3"), P("Madeira/cabelo 4")],
                      line=P("Madeira/cabelo 1"), out=P("Base 1")),
    "fur_cream": dict(ramp=[P("Pergaminho 2"), P("Pergaminho 3"), P("Pergaminho 4"), P("Base 2")],
                      line=P("Pergaminho 2"), out=P("Madeira/cabelo 1")),
    "fur_dark": dict(ramp=[P("Base 1"), P("Pedra/metal 1"), P("Madeira/cabelo 1"), P("Madeira/cabelo 2")],
                     line=P("Base 1"), out=P("Base 1")),
    "fur_black": dict(ramp=[P("Base 1"), P("Roxo 1"), P("Pedra/metal 1"), P("Pedra/metal 2")],
                      line=P("Base 1"), out=P("Base 1")),
    "spot": dict(flat=P("Madeira/cabelo 1"), out=P("Base 1")),
    "water": dict(ramp=[P("Verde agua 1"), P("Verde agua 2"), P("Verde agua 3"), P("Verde agua 4")],
                  line=P("Verde agua 1"), out=P("Azul ceu 1")),
    "seaweed": dict(ramp=[P("Verde folha 1"), P("Verde folha 2"), P("Verde folha 3"), P("Verde folha 4")],
                    line=P("Verde folha 1"), out=P("Verde agua 1")),
    "horn": dict(ramp=[P("Pergaminho 1"), P("Pergaminho 2"), P("Pergaminho 3"), P("Pergaminho 4")],
                 line=P("Pergaminho 1"), out=P("Base 1")),
    "hoof": dict(ramp=[P("Base 1"), P("Pedra/metal 1"), P("Pedra/metal 2"), P("Pedra/metal 3")], line=P("Base 1"),
                 out=P("Base 1")),
    "eye_green": dict(flat=P("Verde folha 4"), out=P("Verde agua 1")),
    "eye_gold": dict(flat=P("Ouro/amarelo 4"), out=P("Ouro/amarelo 1")),
    "eye_orange": dict(flat=P("Vermelho 4"), out=P("Vermelho 1")),
    "obsidian": dict(ramp=[P("Base 1"), P("Roxo 1"), P("Pedra/metal 2"), P("Roxo 3")], line=P("Base 1"),
                     out=P("Base 1")),
    "turquoise": dict(ramp=[P("Verde agua 2"), P("Verde agua 3"), P("Verde agua 4"), P("Base 2")],
                      line=P("Verde agua 1"), out=P("Verde agua 1")),
    "beak": dict(ramp=[P("Ouro/amarelo 1"), P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 4")],
                 line=P("Ouro/amarelo 1"), out=P("Madeira/cabelo 1")),
    "cloth_blue": dict(ramp=[P("Azul ceu 1"), P("Azul ceu 2"), P("Azul ceu 3"), P("Azul ceu 4")], line=P("Azul ceu 1"),
                       out=P("Azul ceu 1")),
    "snake": dict(ramp=[P("Verde folha 1"), P("Verde folha 2"), P("Verde folha 3"), P("Verde folha 4")],
                  line=P("Verde folha 1"), out=P("Verde folha 1")),
    "leaf": dict(ramp=[P("Verde folha 1"), P("Verde folha 2"), P("Verde folha 3"), P("Verde folha 4")],
                 line=P("Verde folha 1"), out=P("Verde folha 1")),
    "tongue": dict(flat=P("Vermelho 3"), out=P("Vermelho 1")),
    "sand": dict(ramp=[P("Madeira/cabelo 2"), P("Ouro/amarelo 2"), P("Pergaminho 3"), P("Pergaminho 4")],
                 line=P("Madeira/cabelo 2"), out=P("Madeira/cabelo 1")),
    "ice": dict(ramp=[P("Azul ceu 2"), P("Azul ceu 3"), P("Azul ceu 4"), P("Base 2")], line=P("Azul ceu 2"),
                out=P("Azul ceu 1")),
    "robe": dict(ramp=[P("Verde agua 1"), P("Verde agua 2"), P("Verde agua 3"), P("Verde agua 4")],
                 line=P("Verde agua 1"), out=P("Base 1")),
    "pale_skin": dict(ramp=[P("Verde agua 2"), P("Verde agua 3"), P("Verde agua 4"), P("Base 2")],
                      line=P("Verde agua 2"), out=P("Verde agua 1")),
    "hat": dict(ramp=[P("Base 1"), P("Base 1"), P("Pedra/metal 1"), P("Pedra/metal 2")], line=P("Base 1"),
                out=P("Base 1")),
    "goblin": dict(ramp=[P("Verde folha 1"), P("Verde folha 2"), P("Verde folha 3"), P("Verde folha 4")],
                   line=P("Verde folha 1"), out=P("Verde folha 1")),
    "tunic": dict(ramp=[P("Madeira/cabelo 1"), P("Madeira/cabelo 2"), P("Madeira/cabelo 3"), P("Madeira/cabelo 4")],
                  line=P("Madeira/cabelo 1"), out=P("Madeira/cabelo 1")),
    "wood_log": dict(ramp=[P("Madeira/cabelo 1"), P("Madeira/cabelo 2"), P("Madeira/cabelo 3"), P("Pergaminho 3")],
                     line=P("Madeira/cabelo 1"), out=P("Madeira/cabelo 1")),
    "thatch": dict(ramp=[P("Ouro/amarelo 1"), P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 4")],
                   line=P("Ouro/amarelo 1"), out=P("Madeira/cabelo 1")),
    "chicken_leg": dict(ramp=[P("Ouro/amarelo 2"), P("Ouro/amarelo 3"), P("Ouro/amarelo 4"), P("Ouro/amarelo 4")],
                        line=P("Ouro/amarelo 1"), out=P("Madeira/cabelo 1")),
    "paper": dict(ramp=[P("Vermelho 1"), P("Vermelho 2"), P("Vermelho 3"), P("Vermelho 4")], line=P("Vermelho 1"),
                  out=P("Vermelho 1")),
    "paper_cream": dict(ramp=[P("Pergaminho 2"), P("Pergaminho 3"), P("Pergaminho 4"), P("Base 2")],
                        line=P("Pergaminho 2"), out=P("Pergaminho 1")),
    "window": dict(flat=P("Ouro/amarelo 4"), out=P("Madeira/cabelo 1")),
    "eye_glow": dict(flat=P("Ouro/amarelo 3"), out=P("Vermelho 1")),
    "eye": dict(flat=P("Base 1"), out=P("Base 1")),
    "iris": dict(flat=P("Vermelho 1"), out=P("Base 1")),
    "white": dict(flat=P("Base 2"), out=P("Base 1")),
    "brow": dict(flat=P("Pele escura 1"), out=P("Pele escura 1")),
    "glow": dict(flat=P("Ouro/amarelo 3"), out=P("Vermelho 2")),
    "glow_hot": dict(flat=P("Ouro/amarelo 4"), out=P("Vermelho 2")),
    # ---- forma atroz (estagio 4, chefe a noite): rampas frias (anil/roxo) + brasas/luz fria. Sombras puxam para o
    # roxo, contorno escuro; as pecas de luz (brasa, fogo-fatuo, raio) sao chapadas e carregam a leitura no escuro.
    "obsidian_n": dict(ramp=[P("Base 1"), P("Roxo 1"), P("Roxo 2"), P("Roxo 3")], line=P("Base 1"), out=P("Base 1")),
    "basalt_n": dict(ramp=[P("Azul ceu 1"), P("Pedra/metal 2"), P("Pedra/metal 3"), P("Pedra/metal 4")],
                     line=P("Base 1"), out=P("Base 1")),
    "skin_n": dict(ramp=[P("Roxo 1"), P("Pedra/metal 2"), P("Pedra/metal 3"), P("Roxo 4")], line=P("Roxo 1"),
                   out=P("Base 1")),
    "nose_n": dict(ramp=[P("Roxo 1"), P("Rosa 1"), P("Rosa 2"), P("Rosa 3")], line=P("Rosa 1"), out=P("Base 1")),
    "horn_n": dict(ramp=[P("Pergaminho 2"), P("Pergaminho 3"), P("Pergaminho 4"), P("Base 2")],
                   line=P("Pergaminho 1"), out=P("Base 1")),
    "chitin_n": dict(ramp=[P("Base 1"), P("Azul ceu 1"), P("Roxo 2"), P("Roxo 3")], line=P("Base 1"), out=P("Base 1")),
    "chitin_dark_n": dict(flat=P("Base 1"), out=P("Base 1")),
    "wing_n": dict(ramp=[P("Roxo 1"), P("Roxo 2"), P("Roxo 3"), P("Roxo 4")], line=P("Roxo 1"), out=P("Base 1")),
    "storm_n": dict(ramp=[P("Azul ceu 1"), P("Roxo 1"), P("Roxo 2"), P("Roxo 3")], line=P("Base 1"), out=P("Base 1")),
    "storm_d_n": dict(ramp=[P("Base 1"), P("Azul ceu 1"), P("Azul ceu 2"), P("Azul ceu 3")], line=P("Base 1"),
                      out=P("Base 1")),
    "cloud_n": dict(ramp=[P("Roxo 1"), P("Roxo 2"), P("Pedra/metal 3"), P("Roxo 4")], line=P("Roxo 1"), out=P("Base 1")),
    "hood_n": dict(ramp=[P("Base 1"), P("Vermelho 1"), P("Vermelho 2"), P("Vermelho 3")], line=P("Base 1"),
                   out=P("Base 1")),
    "thorn_n": dict(ramp=[P("Base 1"), P("Madeira/cabelo 1"), P("Madeira/cabelo 2"), P("Madeira/cabelo 3")],
                    line=P("Base 1"), out=P("Base 1")),
    "gold_n": dict(ramp=[P("Madeira/cabelo 1"), P("Ouro/amarelo 1"), P("Ouro/amarelo 2"), P("Ouro/amarelo 3")],
                   line=P("Madeira/cabelo 1"), out=P("Base 1")),
    "moss_n": dict(ramp=[P("Verde agua 1"), P("Verde agua 2"), P("Verde agua 3"), P("Verde agua 4")],
                   line=P("Verde agua 1"), out=P("Base 1")),
    "fur_n": dict(ramp=[P("Base 1"), P("Roxo 1"), P("Roxo 2"), P("Roxo 3")], line=P("Base 1"), out=P("Base 1")),
    "fur_blue_n": dict(ramp=[P("Base 1"), P("Azul ceu 1"), P("Azul ceu 2"), P("Azul ceu 3")], line=P("Base 1"),
                       out=P("Base 1")),
    "fur_teal_n": dict(ramp=[P("Base 1"), P("Verde agua 1"), P("Verde agua 2"), P("Verde agua 3")], line=P("Base 1"),
                       out=P("Base 1")),
    "fur_wine_n": dict(ramp=[P("Base 1"), P("Rosa 1"), P("Vermelho 2"), P("Rosa 2")], line=P("Base 1"), out=P("Base 1")),
    "fur_slate_n": dict(ramp=[P("Base 1"), P("Pedra/metal 1"), P("Pedra/metal 2"), P("Pedra/metal 3")],
                        line=P("Base 1"), out=P("Base 1")),
    "pale_n": dict(ramp=[P("Roxo 2"), P("Roxo 3"), P("Roxo 4"), P("Base 2")], line=P("Roxo 2"), out=P("Base 1")),
    "brow_n": dict(flat=P("Base 1"), out=P("Base 1")),
    "fang_n": dict(ramp=[P("Pedra/metal 3"), P("Pedra/metal 4"), P("Base 2"), P("Base 2")], line=P("Pedra/metal 2"),
                   out=P("Base 1")),
    # luzes (chapadas): brasa, olho, luz fria, fogo-fatuo, raio
    "ember": dict(flat=P("Vermelho 3"), out=P("Vermelho 1")),
    "ember_hot": dict(flat=P("Ouro/amarelo 3"), out=P("Vermelho 2")),
    "ember_core": dict(flat=P("Ouro/amarelo 4"), out=P("Vermelho 3")),
    "ember_dim": dict(flat=P("Vermelho 2"), out=P("Vermelho 1")),
    "eye_ember": dict(flat=P("Vermelho 3"), out=P("Vermelho 1")),
    "eye_cyan": dict(flat=P("Verde agua 4"), out=P("Verde agua 2")),
    "eye_slit": dict(flat=P("Base 1"), out=P("Base 1")),
    "cold": dict(flat=P("Verde agua 3"), out=P("Azul ceu 1")),
    "cold_hot": dict(flat=P("Verde agua 4"), out=P("Verde agua 2")),
    "vein_n": dict(flat=P("Verde agua 4"), out=P("Verde agua 2")),
    "wisp_v": dict(flat=P("Roxo 4"), out=P("Roxo 2")),
    "wisp_v2": dict(flat=P("Roxo 3"), out=P("Roxo 1")),
    "wisp_c": dict(flat=P("Verde agua 4"), out=P("Verde agua 2")),
    "wisp_c2": dict(flat=P("Verde agua 3"), out=P("Verde agua 1")),
    "bolt": dict(flat=P("Base 2"), out=P("Azul ceu 3")),
    "bolt2": dict(flat=P("Azul ceu 4"), out=P("Roxo 3")),
    "nlamp0": dict(ramp=[P("Azul ceu 1"), P("Azul ceu 2"), P("Verde agua 2"), P("Verde agua 3")], line=P("Azul ceu 1"),
                   out=P("Azul ceu 1")),
    "nlamp1": dict(ramp=[P("Verde agua 2"), P("Verde agua 3"), P("Verde agua 4"), P("Verde agua 4")],
                   line=P("Verde agua 2"), out=P("Verde agua 1")),
    "nlamp2": dict(ramp=[P("Verde agua 3"), P("Verde agua 4"), P("Base 2"), P("Base 2")], line=P("Verde agua 3"),
                   out=P("Verde agua 2")),
    "nlamp_off": dict(ramp=[P("Base 1"), P("Azul ceu 1"), P("Roxo 1"), P("Roxo 2")], line=P("Base 1"), out=P("Base 1")),
    "nlamp_rib": dict(ramp=[P("Base 1"), P("Roxo 1"), P("Roxo 1"), P("Roxo 2")], line=P("Base 1"), out=P("Base 1")),
}
# faixas de N.L -> tom 0..3
THRESH = (0.15, 0.52, 0.86)
# salto de profundidade (fracao de 24 m) que vira linha dentro da mesma peca: ~0,14 m
JUMP = 0.006
LIGHT = np.array([-0.55, 0.65, 0.55])
# duracoes (ms) iguais ao DirectionalSprite3D.ANIM_FRAME_MS (walk: ciclo tipico de 2 celulas)
GIF_MS = {"idle": 100, "walk": 110, "attack": 100, "hit": 60, "death": 150}  # idle 8 x 100 = ciclo de 0,8 s (ANIM_REF_FRAMES)


def load_extra_mats(mid):
    """Materiais proprios da especie: <id>_mats.json ao lado (opcional)."""
    p = os.path.join(HERE, f"{mid}_mats.json")
    if os.path.exists(p):
        for k, v in json.load(open(p)).items():
            MATS[k] = {kk: ([P(x) for x in vv] if isinstance(vv, list) else P(vv)) for kk, vv in v.items()}


def shift(a, dy, dx, fill):
    """out[y, x] = a[y - dy, x - dx] (sem dar a volta na borda, ao contrario de np.roll)."""
    out = np.full_like(a, fill)
    H, W = a.shape[:2]
    ys, yd = (slice(0, H - dy), slice(dy, H)) if dy >= 0 else (slice(-dy, H), slice(0, H + dy))
    xs, xd = (slice(0, W - dx), slice(dx, W)) if dx >= 0 else (slice(-dx, W), slice(0, W + dx))
    out[yd, xd] = a[ys, xs]
    return out


# forma atroz (estagio 4): aro de "luar" de 1 px por fora do contorno escuro (le no mapa noturno); pecas de luz
# (brasas, fogos-fatuos) ficam sem aro
RIM = {4: "Roxo 2"}


def shade_frame(pid, depth, nx, ny, parts, light, rim=None):
    H, W = pid.shape
    out = np.zeros((H, W, 4), np.uint8)
    nx = nx.astype(np.float32); ny = ny.astype(np.float32)
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    L = light / np.linalg.norm(light)
    ndl = nx * L[0] + ny * L[1] + nz * L[2]
    tone = np.digitize(ndl, THRESH)
    opaque = pid > 0
    info = [None] + parts[1:]
    matof = {}
    for i in np.unique(pid):
        if i == 0:
            continue
        pi = info[i]; m = MATS[pi["mat"]]
        matof[i] = m
        sel = pid == i
        if "flat" in m or pi.get("unlit"):
            c = m.get("flat") or m["ramp"][2]
            out[sel, :3] = c
        else:
            ramp = np.array(m["ramp"], np.uint8)
            out[sel, :3] = ramp[tone[sel]]
        out[sel, 3] = 255
    # contorno interno: pixel atras de um vizinho de outra peca
    line = np.zeros((H, W), bool); line_col = np.zeros((H, W, 3), np.uint8)
    noline = np.zeros(256, bool); group = np.full(256, -1)
    gids = {}
    for i in range(1, len(info)):
        noline[i] = bool(info[i].get("noline"))
        g = info[i].get("group")
        if g:
            group[i] = gids.setdefault(g, len(gids))
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        q = shift(pid, dy, dx, 0)
        dq = shift(depth, dy, dx, 1.0)
        m = opaque & (q > 0) & (q != pid) & ~noline[pid] & ~noline[q] & (depth > dq + 1e-4)
        m &= ~((group[pid] >= 0) & (group[pid] == group[q]))
        line |= m
    # quebra de profundidade dentro da mesma peca (cabeca na frente do corpo com a mesma cor): linha tambem
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        q = shift(pid, dy, dx, 0)
        dq = shift(depth, dy, dx, 1.0)
        line |= opaque & (q == pid) & ~noline[pid] & (depth > dq + JUMP)
    for i in np.unique(pid[line]):
        sel = line & (pid == i)
        m = matof[i]
        # a mesma rampa -> junta suave (tom 0); material diferente -> contorno
        ys, xs = np.nonzero(sel)
        for y, x in zip(ys, xs):
            same = True
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                yy, xx = y - dy, x - dx
                if 0 <= yy < H and 0 <= xx < W and pid[yy, xx] > 0 and pid[yy, xx] != i \
                        and depth[yy, xx] + 1e-4 < depth[y, x]:
                    same = same and info[pid[yy, xx]]["mat"] == info[i]["mat"]
            out[y, x, :3] = m.get("line", m.get("out")) if same else m.get("out")
    # contorno externo (4 vizinhos), cor do material vizinho mais a frente
    ext = ~opaque
    best = np.full((H, W), 9.0); col = np.zeros((H, W, 3), np.uint8)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        q = shift(pid, dy, dx, 0)
        dq = shift(depth, dy, dx, 1.0)
        m = ext & (q > 0) & (dq < best)
        if m.any():
            for i in np.unique(q[m]):
                s2 = m & (q == i)
                col[s2] = matof[i]["out"]
            best[m] = dq[m]
    e = ext & (best < 9.0)
    out[e, :3] = col[e]; out[e, 3] = 255
    if rim is not None:
        # contorno que veio de peca iluminada (nao-luz) -> ganha aro por fora
        lit = np.zeros(256, bool)
        for i in range(1, len(info)):
            m = MATS[info[i]["mat"]]
            lit[i] = not ("flat" in m or info[i].get("unlit"))
        src = np.zeros((H, W), bool)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            q = shift(pid, dy, dx, 0)
            src |= e & (q > 0) & lit[q]
        rr = np.zeros((H, W), bool)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            rr |= shift(src, dy, dx, False)
        rr &= ~opaque & ~e
        out[rr, :3] = rim; out[rr, 3] = 255
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id"); ap.add_argument("stage", type=int)
    ap.add_argument("--work", default=os.path.join(ROOT, ".work", "b3"))
    ap.add_argument("--no-install", action="store_true")
    ap.add_argument("--light", default="")
    ap.add_argument("--scale", type=int, default=0)
    ap.add_argument("--zoom", action="store_true", help="le o render de depuracao (--zoom) e so gera previas")
    ap.add_argument("--rim", default=None, help="cor (nome da paleta) do aro externo; padrao RIM[estagio]; 'none' desliga")
    a = ap.parse_args()
    load_extra_mats(a.id)
    light = np.array([float(x) for x in a.light.split(",")]) if a.light else LIGHT
    base = os.path.join(a.work, "npz", f"{a.id}_s{a.stage}" + ("_zoom" if a.zoom else ""))
    if a.zoom:
        a.no_install = True
    meta = json.load(open(base + ".json")); z = np.load(base + ".npz")
    F = meta["frame"]; C = meta["canvas"]; parts = meta["parts"]
    rim_name = a.rim if a.rim is not None else RIM.get(a.stage)
    rim = P(rim_name) if rim_name and rim_name != "none" else None
    shaded = {}
    for anim, n in meta["anims"]:
        ids, d, nx, ny = z[f"{anim}_id"], z[f"{anim}_d"], z[f"{anim}_nx"], z[f"{anim}_ny"]
        shaded[anim] = np.stack([np.stack([shade_frame(ids[r, f], d[r, f], nx[r, f], ny[r, f], parts, light, rim)
                                           for f in range(n)]) for r in range(5)])
    # quadros de golpe/dano/morte que descem abaixo do chao das animacoes "em pe" (o corpo cai para a frente, na
    # direcao da camera) sobem so o que passar, como um pixel artista faria: o parado nao fica flutuando
    stand_low = {}
    for anim in ("idle", "walk"):
        if anim in shaded:
            op = shaded[anim][..., 3] > 0
            for r in range(5):
                ys = np.nonzero(op[r].any(0).any(1))[0]
                if len(ys):
                    stand_low[r] = max(stand_low.get(r, 0), int(ys.max()))
    if stand_low:
        lim = max(stand_low.values())
        for anim, arr in shaded.items():
            if anim in ("idle", "walk"):
                continue
            for r in range(5):
                for f in range(arr.shape[1]):
                    ys = np.nonzero((arr[r, f, ..., 3] > 0).any(1))[0]
                    if len(ys) and ys.max() > lim:
                        dy = int(ys.max() - lim)
                        arr[r, f] = np.concatenate([arr[r, f, dy:], np.zeros_like(arr[r, f, :dy])], 0)
    # recorte fixo do estagio
    allop = np.zeros((C, C), bool); lows = {}
    for anim, arr in shaded.items():
        op = (arr[..., 3] > 0).any((0, 1))
        allop |= op
        ys = np.nonzero(op.any(1))[0]; lows[anim] = int(ys.max())
    # pes: o ponto mais baixo das animacoes 'em pe' (idle/walk) na ultima linha - 1
    stand = [lows[k] for k in ('idle', 'walk') if k in lows] or list(lows.values())
    low = max(max(stand), max(lows.values()))  # nunca cortar; em pe pode sobrar 1-3 px
    y1 = min(C, max(F, low + 2)); y0 = y1 - F
    x0 = C // 2 - F // 2; x1 = x0 + F
    ys, xs = np.nonzero(allop)
    ext = {}
    for anim, arr in shaded.items():
        op = (arr[..., 3] > 0).any((0, 1)); yy, xx = np.nonzero(op)
        ext[anim] = [int(yy.min() - y0), int(xx.min() - x0), int(xx.max() - x0), int(yy.max() - y0)]
    clip = dict(top=int(max(0, y0 - ys.min())), left=int(max(0, x0 - xs.min())), right=int(max(0, xs.max() + 1 - x1)), bottom=int(max(0, ys.max() + 1 - y1)))
    info = dict(frame=F, extent_top_left_right_bottom=ext, lowest_by_anim={k: v - y0 for k, v in lows.items()}, clip=clip,
                bbox_h=int(ys.max() - ys.min() + 1), bbox_w=int(xs.max() - xs.min() + 1))
    idle = shaded[meta["anims"][0][0]][:, 0, y0:y1, x0:x1]
    hs = []
    for r in range(5):
        yy = np.nonzero((idle[r, ..., 3] > 0).any(1))[0]; xx = np.nonzero((idle[r, ..., 3] > 0).any(0))[0]
        if not len(yy):
            hs.append((0, 0)); continue
        hs.append((int(yy.max() - yy.min() + 1), int(xx.max() - xx.min() + 1)))
    info["idle_hw_by_dir"] = hs
    print(f"[post] {a.id} s{a.stage}: {json.dumps(info)}")
    if any(clip.values()):
        print(f"[post] AVISO: conteudo cortado {clip}")
    sheets = {}
    for anim, arr in shaded.items():
        n = arr.shape[1]
        sh = np.zeros((5 * F, n * F, 4), np.uint8)
        for r in range(5):
            for f in range(n):
                sh[r * F:(r + 1) * F, f * F:(f + 1) * F] = arr[r, f, y0:y1, x0:x1]
        sheets[anim] = sh
    dest = os.path.join(GAME, "assets", "monsters", a.id)
    if a.no_install and not a.zoom:
        # revisao: as folhas ficam em <work>/sheets/<id>/ (nada vai para o jogo)
        sd = os.path.join(a.work, "sheets", a.id); os.makedirs(sd, exist_ok=True)
        for anim, sh in sheets.items():
            Image.fromarray(sh, "RGBA").save(os.path.join(sd, f"mon_{a.id}_s{a.stage}_{anim}.png"))
    if not a.no_install:
        os.makedirs(dest, exist_ok=True)
        for anim, sh in sheets.items():
            Image.fromarray(sh, "RGBA").save(os.path.join(dest, f"mon_{a.id}_s{a.stage}_{anim}.png"))
    pv = os.path.join(a.work, "preview"); os.makedirs(pv, exist_ok=True)
    k = a.scale or max(1, 384 // F)
    write_previews(pv, f"{a.id}_s{a.stage}" + ("_zoom" if a.zoom else ""), sheets, F, 1 if a.zoom else k)
    json.dump(info, open(os.path.join(pv, f"{a.id}_s{a.stage}_info.json"), "w"), indent=1)


BG = (118, 158, 86, 255)


def write_previews(pv, name, sheets, F, k):
    # prancha: todas as animacoes (5 linhas cada), fundo de grama, ampliada k x
    W = max(sh.shape[1] for sh in sheets.values()); gap = 6
    H = sum(sh.shape[0] + gap for sh in sheets.values())
    board = Image.new("RGBA", (W, H), BG)
    y = 0
    for anim, sh in sheets.items():
        im = Image.fromarray(sh, "RGBA")
        board.alpha_composite(im, (0, y)); y += sh.shape[0] + gap
    board.resize((W * k, H * k), Image.NEAREST).save(os.path.join(pv, f"{name}_board.png"))
    # amostra ampliada para revisar de perto: poses-chave x 5 direcoes
    picks = [(an, f) for an, fs in (("idle", (0, 3, 6)), ("walk", (1, 3, 5)), ("attack", (0, 1, 2, 4, 6)),
                                     ("hit", (0, 1)), ("death", (1, 2, 7))) if an in sheets
             for f in fs if f < sheets[an].shape[1] // F]
    kk = max(3, 320 // F)
    samp = Image.new("RGBA", (len(picks) * (F + 2), 5 * (F + 2)), BG)
    for c, (an, f) in enumerate(picks):
        for r in range(5):
            samp.alpha_composite(Image.fromarray(sheets[an][r * F:(r + 1) * F, f * F:(f + 1) * F], "RGBA"),
                                 (c * (F + 2), r * (F + 2)))
    samp.resize((samp.width * kk, samp.height * kk), Image.NEAREST).save(os.path.join(pv, f"{name}_sample.png"))
    # GIF por animacao: 5 direcoes lado a lado
    for anim, sh in sheets.items():
        n = sh.shape[1] // F
        frames = []
        for f in range(n):
            im = Image.new("RGBA", (5 * F, F), BG)
            for r in range(5):
                im.alpha_composite(Image.fromarray(sh[r * F:(r + 1) * F, f * F:(f + 1) * F], "RGBA"), (r * F, 0))
            frames.append(im.resize((5 * F * k, F * k), Image.NEAREST).convert("RGB"))
        durs = [GIF_MS.get(anim, 120)] * n
        if anim == "death":
            durs[-1] = 1200
        frames[0].save(os.path.join(pv, f"{name}_{anim}.gif"), save_all=True, append_images=frames[1:],
                       duration=durs, loop=0, disposal=1)


if __name__ == "__main__":
    main()
