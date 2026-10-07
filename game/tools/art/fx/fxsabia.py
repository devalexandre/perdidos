"""Biblioteca das arvores da Terra do Sabia (30/09/2026): rampas das escolas novas e sprites desenhados a mao,
pixel a pixel (1 caractere = 1 pixel), para as pecas-chave dos efeitos e dos icones.

Tudo original, feito aqui (GDD §0 regra 5). Temas: suporte (folhas, sementes, garrafada, pequizeiro, coco,
buriti), debuff da Matinta (pio, penas escuras, visgo, fumaca amarga), tanque (casco de jabuti, couro de anta,
pegadas), berserker (Mapinguari: garras, urro, marcas vermelhas), arco (flechas de taquara, cipos, lama,
gaviao-real). Nenhum simbolo religioso (sem cruz, hexagrama ou pentagrama)."""
from __future__ import annotations

import math

import numpy as np

from fxdraw import Canvas, Frame, Ramp, Spr, blit, lerp, rng

TAU = math.tau
D = math.radians

# ------------------------------------------------------------------ rampas
GLOW_TH = [0.05, 0.16, 0.32, 0.5, 0.7, 0.88]
GLOW_A = [90, 170, 255, 255, 255, 255]
SOLID_TH = [0.1, 0.38, 0.6, 0.82]


def glow_ramp(cols, alphas=None):
    return Ramp(cols, GLOW_TH, alphas or GLOW_A)


def solid_ramp(cols, alphas=None):
    return Ramp(cols, SOLID_TH, alphas)


LEAF_G = glow_ramp(["#10240e", "#2f6b3e", "#5aa048", "#a6d86a", "#e0f8b0", "#ffffff"])
LEAF = solid_ramp(["#1f3b2c", "#2f6b3e", "#5aa048", "#a6d86a"])
LEAF_LINE = "#12261a"
SAP_G = glow_ramp(["#3a2408", "#7a4a12", "#c8801e", "#f0b640", "#fae58c", "#fffcf0"])
WATER_G = glow_ramp(["#12303a", "#2a6e6e", "#4fa8a0", "#9ee0c8", "#dcfff0", "#ffffff"])
MANA_G = glow_ramp(["#0c1c48", "#1c3c9c", "#3a78de", "#84b8f6", "#d2e8ff", "#ffffff"])
MATINTA_G = glow_ramp(["#140c1e", "#2e1f4a", "#5a3a8c", "#8e66c4", "#c9a8ec", "#f4ecff"])
MATINTA_GROUND = glow_ramp(["#140c1e", "#2e1f4a", "#5a3a8c", "#8e66c4", "#c9a8ec", "#f4ecff"],
                           [40, 140, 230, 255, 255, 255])
SMOKE = solid_ramp(["#3a3242", "#554c60", "#746a80", "#958aa2"], [150, 190, 220, 235])
SMOKE_LINE = "#1e1824"
BITTER = solid_ramp(["#2c3222", "#46502e", "#66723e", "#8e9a5a"], [150, 190, 225, 240])
BITTER_LINE = "#161a10"
WOOD = solid_ramp(["#3a2418", "#6b4226", "#9c6a3c", "#c9985e"])
WOOD_LINE = "#1e120a"
MUD = solid_ramp(["#3a2a1a", "#5e4428", "#86643c", "#a88a5c"])
MUD_LINE = "#1c140a"
BRONZE = solid_ramp(["#4a2e10", "#8a5a22", "#c08a3a", "#ecc070"])
BRONZE_LINE = "#221406"
BRONZE_G = glow_ramp(["#2a1808", "#6a4214", "#b07a2e", "#e0aa4a", "#fae0a0", "#fffcf0"])
BRONZE_GROUND = glow_ramp(["#2a1808", "#6a4214", "#b07a2e", "#e0aa4a", "#fae0a0", "#fffcf0"],
                          [36, 150, 255, 255, 255, 255])
RAGE_G = glow_ramp(["#2a0808", "#6e1010", "#b4201c", "#e8483a", "#ff9a7a", "#fff0e8"])
RAGE_GROUND = glow_ramp(["#2a0808", "#6e1010", "#b4201c", "#e8483a", "#ff9a7a", "#fff0e8"],
                        [40, 150, 255, 255, 255, 255])
EMBER_G = glow_ramp(["#3a0e08", "#8c1e12", "#d2421e", "#f4842a", "#fcc84a", "#fff4c8"])
EMBER_GROUND = glow_ramp(["#3a0e08", "#8c1e12", "#d2421e", "#f4842a", "#fcc84a", "#fff4c8"],
                         [36, 150, 255, 255, 255, 255])
OLIVE_G = glow_ramp(["#1e2410", "#3e4a1c", "#6e7e2e", "#a8b44a", "#e2e8a0", "#ffffff"])
OLIVE_GROUND = glow_ramp(["#1e2410", "#3e4a1c", "#6e7e2e", "#a8b44a", "#e2e8a0", "#ffffff"],
                         [36, 150, 255, 255, 255, 255])
HIDE = solid_ramp(["#2e2626", "#4e4240", "#72625a", "#9a887a"])
HIDE_LINE = "#161010"
SHELL = solid_ramp(["#3a2a12", "#6a4e22", "#9c7a3a", "#d0aa5c"])
SHELL_LINE = "#1a1206"
CRYSTAL = solid_ramp(["#0f3c46", "#1a7a80", "#46c4bc", "#c0fff4"])
CRYSTAL_LINE = "#08222a"
CRYSTAL_G = glow_ramp(["#0a2a36", "#115a66", "#1a9ea4", "#46dcd2", "#b0fff2", "#ffffff"])
ARCANE_GROUND = glow_ramp(["#0a2a36", "#115a66", "#1a9ea4", "#46dcd2", "#b0fff2", "#ffffff"],
                          [36, 150, 255, 255, 255, 255])
DUST = solid_ramp(["#9a8468", "#b8a080", "#d4bf9a", "#eee2c4"], [110, 170, 215, 235])
DUST_LINE = "#8a7458"  # contorno macio: poeira, nao pedra
GOO = solid_ramp(["#6a6a1e", "#a0a034", "#cfd05a", "#f2f0a8"])
GOO_LINE = "#2e2e0a"
BLOOD = solid_ramp(["#4a0c0c", "#8c1a16", "#c83228", "#f07a5a"])
BLOOD_LINE = "#220404"
STEEL = solid_ramp(["#5a5462", "#8e8a98", "#c8c4d0", "#f4f2f8"])
STEEL_LINE = "#2e2834"
STONE_SHADOW = Ramp(["#1c1830", "#2a2448", "#3a3464"], [0.08, 0.4, 0.75], [70, 110, 140])
SHADOW = Ramp(["#141018", "#1e1824", "#2a2230"], [0.08, 0.4, 0.75], [60, 95, 125])

W_WHITE, W_GOLD, W_PALE = "#ffffff", "#fae58c", "#e6b43a"

# ------------------------------------------------------------------ paletas dos sprites
K = "#1a120c"  # contorno escuro quente (padrao dos sprites)
PAL_ARROW = {"s": "#dcc07a", "S": "#a07c3e", "n": "#5e4020", "h": "#eeeaf2", "H": "#9a96a4", "d": "#5a5462",
             "f": "#8cc860", "F": "#3e7a34", "w": "#c8401e", "k": K}


def spr(text: str, pal: dict[str, str], line: str | None = K) -> Spr:
    s = Spr.parse(text, pal)
    return s.outlined(line) if line else s


# Flecha de taquara (aponta para a DIREITA): ponta de ferro, gomos da taquara, amarracao vermelha e penas.
ARROW_TXT = """
ff.....ff...............................
.fF.....fF...........................h..
..fFFFFFFfF..........................hh.
...wwsssssssnsssssssssnsssssssssssssHhhh
...wwSSSSSSSnSSSSSSSSSnSSSSSSSSSSSSSHHHH
..fFFFFFFfF..........................HH.
.fF.....fF...........................H..
ff.....ff...............................
"""


def arrow(fletch=("#8cc860", "#3e7a34"), head=("#eeeaf2", "#9a96a4"), ribbon="#c8401e", shaft=None) -> Spr:
    pal = dict(PAL_ARROW)
    pal["f"], pal["F"] = fletch
    pal["h"], pal["H"] = head
    pal["w"] = ribbon
    if shaft:
        pal["s"], pal["S"] = shaft
    return spr(ARROW_TXT, pal)


# Pena (vertical, ponta para cima), 7x17.
FEATHER_TXT = """
...a...
..aab..
..abb..
.aabbc.
.aabbc.
aaabbcc
aaabbcc
aaabbcc
.aabbc.
.aabbc.
a.abb.c
..abc..
...b...
...b...
...b...
...b...
...b...
"""
FEATHER_DARK = {"a": "#4e4460", "b": "#2e2638", "c": "#16121e"}
FEATHER_GOLD = {"a": "#fae58c", "b": "#c89030", "c": "#6a4a14"}
FEATHER_WHITE = {"a": "#fffcf0", "b": "#d8d0c0", "c": "#8a7e6c"}
FEATHER_GREEN = {"a": "#a6d86a", "b": "#5aa048", "c": "#2f6b3e"}
FEATHER_RED = {"a": "#f07a5a", "b": "#c83228", "c": "#6e1010"}


def feather(pal) -> Spr:
    return spr(FEATHER_TXT, pal)


# Folha larga (ponta para cima), 13x19, nervura clara.
LEAF_TXT = """
......a......
.....aba.....
....aabaa....
...aaabaaa...
..aaaabaaac..
..aaaabaaac..
.caaaabaaacc.
.caaaabaaacc.
.caaabbbaacc.
cccaabcbaaccc
cccaabcbaaccc
.ccaabcbaacc.
.ccaabcbaacc.
..ccabcbacc..
..cccabacc...
...ccabacc...
.....cbc.....
......b......
......b......
"""
LEAF_PAL = {"a": "#8ccc5a", "b": "#d6f09a", "c": "#3e8a3c"}


def leaf(pal=None) -> Spr:
    return spr(LEAF_TXT, pal or LEAF_PAL, "#12261a")


# Folhinha pequena (particula), 5x7.
LEAFLET_TXT = """
..a..
.aab.
aaabc
aabbc
.abc.
..c..
..c..
"""
LEAFLET_PAL = {"a": "#a6d86a", "b": "#5aa048", "c": "#2f6b3e"}

# Garrafada: garrafa de vidro com ervas e raiz dentro, rolha de sabugo e cordao.
BOTTLE_TXT = """
.....cc.....
.....CC.....
....tttt....
.....gg.....
.....gg.....
....gGGg....
...gGllGg...
..gGlllLGg..
.gGlhllLLGg.
.gllhlrlLLg.
.glhllrrLLg.
.glhlrlrLLg.
.gllrllrlLg.
.glllrllLLg.
.gLllllLLLg.
.gLLlllLLLg.
..gLLLLLLg..
...gggggg...
"""
BOTTLE_PAL = {"c": "#e6c880", "C": "#a07c3e", "t": "#c8401e", "g": "#2a5a3a", "G": "#9ee0c8", "l": "#5aa048",
              "L": "#2f6b3e", "h": "#d6f7e8", "r": "#9c6a3c"}

# Cuia (cabaca cortada) com cha de erva e vapor, 18x10.
CUIA_TXT = """
..bbbbbbbbbbbbbb..
.bllllllllllllllb.
bBllLlllllLllllLBb
bBBllllllllllllBBb
.bBBBBBBBBBBBBBBb.
.bBBbBBBBBBBBbBBb.
..bBBBBBBBBBBBBb..
...bBBBBBBBBBBb...
....bbBBBBBBbb....
......bbbbbb......
"""
CUIA_PAL = {"b": "#6b4226", "B": "#9c6a3c", "l": "#8cc860", "L": "#d6f09a"}

# Coco verde aberto no alto (a agua sai por cima), 18x16.
COCO_TXT = """
..............rw..
.............rw...
............wr....
...........rw.....
..........wr......
....wwwwwwwwww....
...wWWWWWWWWWWw...
..wWwwwwwwwwwwWw..
..gwwwwwwwwwwwwg..
.gGwwwwwwwwwwwwGg.
.gGGgwwwwwwwwgGGg.
gGGGGggggggggGGGGg
gGGgGGGGGGGGGGgGGg
gGGgGGGGGGGGGGgGGg
gGgGGGGGGGGGGGGgGg
gGgGGGGGGGGGGGGgGg
.gGGGGGGGGGGGGGGg.
.gGGGGGGGGGGGGGGg.
..gGGGGGGGGGGGGg..
...ggGGGGGGGGgg...
.....gggggggg.....
"""
COCO_PAL = {"w": "#f4f0dc", "W": "#c8e8e0", "g": "#2f6b3e", "G": "#6ab04a", "r": "#e8483a"}

# Pequi (fruto amarelo-esverdeado), 7x7 e flor branca.
PEQUI_TXT = """
..bbb..
.baaab.
baaaaab
baaAaab
baaaaab
.baaab.
..bbb..
"""
PEQUI_PAL = {"a": "#c8d84a", "A": "#f2f0a8", "b": "#6a7e22"}

# Vaga-lume (asa aberta / fechada) — 9x7, abdomen aceso.
FIREFLY_A = """
.ww...ww.
wWWw.wWWw
.wWWkWWw.
...kKk...
...yYy...
...YyY...
....Y....
"""
FIREFLY_B = """
.........
...wkw...
..wWkWw..
...kKk...
...yYy...
...YyY...
....Y....
"""
FIREFLY_PAL = {"w": "#c8d0d8", "W": "#f4f8fc", "k": "#2a2418", "K": "#5a4a2a", "y": "#e8f070", "Y": "#fffcc0"}

# Passarinho escuro da Matinta (asas abertas / fechadas), 17x9, olho vermelho.
BIRD_UP = """
aa.............aa
.aab.........baa.
..aabb.....bbaa..
...abbb...bbba...
....abbbrbbba....
.....bbbbbbb.....
......bbbbb......
.......bcb.......
......cc.cc......
"""
BIRD_DOWN = """
.......brb.......
......bbbbb......
....abbbbbbba....
...aabbbbbbbaa...
..aab.bbbbb.baa..
.aa...bbbbb...aa.
aa.....bcb.....aa
......cc.cc......
.................
"""
BIRD_PAL = {"a": "#4e4460", "b": "#241c2e", "c": "#6a5e7a", "r": "#e8483a"}

# Rasga-mortalha (coruja-das-torres): cara branca em coracao, asas abertas, 27x17.
OWL_TXT = """
aa.......................aa
aaa.....................aaa
.aab......bbbbbbb......baa.
.aabb...bbwwwwwwwbb...bbaa.
..aabb.bwwwwwwwwwwwb.bbaa..
..aabbbbwwkkwwwkkwwbbbbaa..
...aabbbwwkewwwkewwbbbaa...
...aabbbwwwwwowwwwwbbbaa...
....aabbbwwwwowwwwbbbaa....
....aabbbbwwwwwwwbbbbaa....
.....aabbbbbwwwbbbbbaa.....
......aabbbbbbbbbbbaa......
.......aabbcbcbcbbaa.......
........abbbcbcbbba........
..........bbbbbbb..........
...........o...o...........
..........oo...oo..........
"""
OWL_PAL = {"a": "#8a7e6c", "b": "#d8b880", "w": "#fffcf0", "k": "#1a1418", "e": "#3a2e28", "o": "#e6b43a",
           "c": "#a08050"}

# Gaviao-real mergulhando (visto de frente, asas para cima, garras abertas), 29x23.
HAWK_TXT = """
aa.........................aa
aab.......................baa
aabb.....................bbaa
.aabb...................bbaa.
.aabbb.......ccc.......bbbaa.
..aabbb.....cwwwc.....bbbaa..
..aaabbb...cwwwwwc...bbbaaa..
...aaabbb..cwkwkwc..bbbaaa...
...aaabbbb.ccwowcc.bbbbaaa...
....aaabbbbbcwoowcbbbbaaa....
....aaabbbbbbwwwbbbbbbaaa....
.....aaabbbbbbwbbbbbbaaa.....
......aaabbbbbbbbbbbaaa......
.......aaabbbbbbbbbaaa.......
........aabbbwwwbbbaa........
.........abbwwwwwbba.........
..........bbwwwwwbb..........
...........bwwwwwb...........
...........cbbbbbc...........
..........oo.....oo..........
.........o.o.....o.o.........
.........o..o...o..o.........
.................................
"""
HAWK_PAL = {"a": "#2a2430", "b": "#5a5060", "c": "#8a8494", "w": "#f4f2f8", "k": "#1a1418", "o": "#e6b43a"}

# Onca-pintada saltando (perfil, para a DIREITA), 40x18, rosetas.
JAGUAR_TXT = """
...............................oo.......
..............................oyyo.o....
.............................oyyyyoyo...
.......oooooooooooooooo....oyyyyyyyyyo..
.....ooyyyyyyyyyyyyyyyyooooyyyyyyykyyyo.
...ooyyyykkyyyyykkyyyyyykkyyyyyyyyyyyyyo
..oyyyykyykyyyykyykyyyykyykyyyyyyyyyww.o
.oyyyyyykkyyyyyykkyyyyyykkyyyyyyyyyywwwo
oyyykkyyyyykkyyyyykkyyyyyyyyyyyyyyoooo..
oyykyykyyykyykyyykyykyyyyyyyyyyyyo......
.oyykkyyyyykkyyyyykkyyyyyyyyyyyyo.......
..ooyyyyyyyyyyyyyyyyyyyyyyyyyyyo........
....oyyyyyoooooooooooooyyyyyyyo.........
...oyyyyo..............oyyyyyyo.........
..oyyyo.................oyyyyyyo........
.oyyo....................oowwyyyo.......
owwo.......................owwwwo.......
oo..........................oooo........
"""
JAGUAR_PAL = {"o": "#3a2412", "y": "#e8a83a", "k": "#3a2412", "w": "#fae8b8"}

# Anta investindo (perfil, para a DIREITA), 36x20, focinho curto em tromba.
TAPIR_TXT = """
...........bbbbbbbbbbb.....................
........bbbhhhhhhhhhhhbbbb.........bb......
......bbhhhhhhhhhhhhhhhhhhbbb.....bwwb.....
....bbhhhhhhhhhhhhhhhhhhhhhhhbb..bwhhb.....
...bhhhhhhhhhhhhhhhhhhhhhhhhhhhbbbhhhbb....
..bhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhbb..
.bhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhkhhhhb.
bbhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb
bhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb
bhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb
bhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhbbbhhhhb
.bhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb...bhhhb
.bhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.....bhhb
..bhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhb.......bhb
..bhhhhhhbbbbbbbbbbbbbbbbbhhhhhhb........bhb
..bhhhhhb................bhhhhhb.........bb.
..bhhhhb.................bhhhhb.............
..bhhhhb.................bhhhhb.............
..bgggb..................bgggb..............
..bbbbb..................bbbbb..............
"""
TAPIR_PAL = {"b": "#1e1818", "h": "#6e6068", "k": "#e8e0d0", "g": "#3a3036"}

# Casco de jabuti (de lado, domo), 30x16, placas com borda clara.
SHELL_TXT = """
...........ssssssss...........
........sssPPPPPPPPsss........
......ssPPPPlPPPPlPPPPss......
.....sPPPlllPsPPsPllPPPPs.....
....sPPlllPPsPPPPsPPlllPPs....
...sPPPPPPPsPPPPPPsPPPPPPPs...
..sPPlPPPPsPPPlPPPPsPPPPlPPs..
..sPlllPPPsPPlllPPPsPPPlllPs..
.ssPPPPPPssssssssssssPPPPPPss.
.sssssssssBBBBBBBBBBsssssssss.
sBBBBBBBBBBBBBBBBBBBBBBBBBBBBs
sBBsBBBBsBBBBBBBBBBBBsBBBBsBBs
.sBBBBBBBBBBBBBBBBBBBBBBBBBBs.
..ssssssssssssssssssssssssss..
..............................
..............................
"""
SHELL_PAL = {"s": "#2a1c0a", "P": "#9c7a3a", "l": "#e0bc6a", "B": "#c8a050"}

# Bigorna e martelo do ferreiro (Seu Ze), 26x16.
ANVIL_TXT = """
..........................
...mmmmmmmmmmmmmmmmmmm....
.mmMMMMMMMMMMMMMMMMMMMmm..
mMMMMMMMMMMMMMMMMMMMMMMMmm
.mmmmmmMMMMMMMMMMMmmmmmmm.
.......mMMMMMMMMMm........
........mMMMMMMMm.........
........mMMMMMMMm.........
.......mmMMMMMMMmm........
.....mmMMMMMMMMMMMmm......
....mmmmmmmmmmmmmmmmm.....
"""
ANVIL_PAL = {"m": "#2e2834", "M": "#8e8a98"}
HAMMER_TXT = """
.hhhhhh.
hHHHHHHh
hHHHHHHh
.hhwwhh.
...ww...
...ww...
...ww...
...ww...
...ww...
...ww...
...WW...
"""
HAMMER_PAL = {"h": "#2e2834", "H": "#c8c4d0", "w": "#9c6a3c", "W": "#6b4226"}

# Facao (lamina para a DIREITA), 30x7.
MACHETE_TXT = """
..........ssssssssssssssssss..
bbbbbbb..sSSSSSSSSSSSSSSSSSSs.
bBBwBBBbbsSSSSSSSSSSSSSSSSSSSs
bBBwBBBbbsSSSSSSSSSSSSSSSSSSSs
bbbbbbb..sEEEEEEEEEEEEEEEEEEs.
..........ssssssssssssssssss..
"""
MACHETE_PAL = {"b": "#3a2418", "B": "#9c6a3c", "w": "#c9985e", "s": "#2e2834", "S": "#c8c4d0", "E": "#f4f2f8"}

# Pedra de amolar, 12x5.
WHET_TXT = """
.gggggggggg.
gGGGGGGGGGGg
gGGgGGGGgGGg
gGGGGGGGGGGg
.gggggggggg.
"""
WHET_PAL = {"g": "#3a3440", "G": "#8a8a7a"}

# Provocacao: balao espinhudo vermelho com "!" (o monstro so enxerga voce), 17x17.
TAUNT_TXT = """
........r........
.....r.rRr.r.....
....rRrRRRrRr....
.r..rRRRRRRRr..r.
.rrrRRRRwwRRRrrr.
..rRRRRRwwRRRRr..
..rRRRRRwwRRRRr..
rrRRRRRRwwRRRRRrr
.rRRRRRRwwRRRRRr.
..rRRRRRwwRRRRr..
..rRRRRRRRRRRRr..
.rrRRRRRwwRRRRrr.
.r..rRRRwwRRRr.r.
....rRrRRRrRr....
.....r.rRr.r.....
........r........
"""
TAUNT_PAL = {"r": "#6e1010", "R": "#e8483a", "w": "#fff4e0"}


# Olho de serpente de fogo (Boitata), 24x12 — pupila em fenda.
SERPENT_EYE_TXT = """
.........oooooo.........
......oooyyyyyyooo......
....ooyyyyyyyyyyyyoo....
..ooyyyyyyykkyyyyyyyoo..
.oyyyyyyyyykkyyyyyyyyyo.
oyyyYYYYyyykkyyyYYYYyyyo
oyyyYYYYyyykkyyyYYYYyyyo
.oyyyyyyyyykkyyyyyyyyyo.
..ooyyyyyyykkyyyyyyyoo..
....ooyyyyyyyyyyyyoo....
......oooyyyyyyooo......
.........oooooo.........
"""
SERPENT_EYE_PAL = {"o": "#8c1e12", "y": "#f4842a", "Y": "#fcc84a", "k": "#1a0806"}

# Olho do gaviao (iris dourada, sobrancelha escura), 22x11.
HAWK_EYE_TXT = """
bbbbbbbbbbbbbbbbbbbb..
.bbbbbbbbbbbbbbbbbbbbb
..bbwwwoooooowwwbbbb..
..bwwooooooooooowwb...
..woooooookkoooooow...
..wooooookkkkoooooow..
..woooooookkkooooow...
...wwooooooooooowww...
....wwwwoooooowww.....
.......wwwwwwww.......
......................
"""
HAWK_EYE_PAL = {"b": "#2a2430", "w": "#f4f2f8", "o": "#e6a830", "k": "#1a1418"}

# Olhos de onca (par), 26x8 — brilho amarelo-vermelho.
JAG_EYES_TXT = """
.oooooo............oooooo.
oyyyyyyo..........oyyyyyyo
oyyykyyyo........oyyykyyyo
oyyykkyyo........oyykkyyyo
.oyykyyo..........oyykyyo.
..oooooo..........oooooo..
"""
JAG_EYES_PAL = {"o": "#6e1010", "y": "#fcc84a", "k": "#1a0806"}

# Boca do Mapinguari (na barriga, conta a lenda): dentes grandes, 30x16.
MOUTH_TXT = """
..rrrrrrrrrrrrrrrrrrrrrrrrrr..
.rRRRRRRRRRRRRRRRRRRRRRRRRRRr.
rRRwRRwRRRwRRRRwRRRwRRwRRwRRRr
rRwwRwwRRwwwRRwwwRRwwwRwwRwwRr
rRwwkwwkkwwwkkwwwkkwwwkwwkwwRr
rkwkkkwkkkwkkkkwkkkkwkkkwkkkwr
rkkkkkkkkkkkkkkkkkkkkkkkkkkkkr
rkkkkkkkkkkttttttttkkkkkkkkkkr
rkwkkkkwkkkkkttttkkkkkwkkkkwkr
rwwkkkwwkkkwkkkkkkwkkkwwkkkwwr
rRwwkwwwkkwwwkkkkwwwkkwwwkwwRr
rRRwwRwwRwwwRRwRwwwRRwwRRwwRRr
.rRRRRRRRRRRRRRRRRRRRRRRRRRRr.
..rrrrrrrrrrrrrrrrrrrrrrrrrr..
"""
MOUTH_PAL = {"r": "#3a0a0a", "R": "#8c1a16", "w": "#f4ecd8", "k": "#1a0404", "t": "#c83228"}

# Mao de garras do Mapinguari (golpe de cima para baixo), 22x22.
CLAW_HAND_TXT = """
......................
....h....h....h.......
...hH...hH...hH.......
...hH...hH...hH....h..
...hH...hH...hH...hH..
...hHf..hHf..hHf..hH..
...fFf..fFf..fFf..hHf.
..fFFf.fFFf.fFFf..fFf.
..fFFffFFFffFFFffffFf.
..fFFFFFFFFFFFFFFFFFf.
..fFFFFFFFFFFFFFFFFf..
..fFFFFFFFFFFFFFFFFf..
...fFFFFFFFFFFFFFFf...
...fFFFFFFFFFFFFFFf...
....fFFFFFFFFFFFFf....
.....fFFFFFFFFFFf.....
......fFFFFFFFFf......
......fFFFFFFFFf......
......fFFFFFFFFf......
......ffffffffff......
"""
CLAW_HAND_PAL = {"h": "#f4ecd8", "H": "#b8ae98", "f": "#2a1a14", "F": "#5a3a2a"}

# Bandeirinha de festa (triangulo pendurado), 7x8 — recolorida por cor.
FLAG_TXT = """
kkkkkkk
kaaaaak
kaaaaak
.kaaak.
.kaaak.
..kak..
..kak..
...k...
"""

# Gota (seiva / agua / sangue), 5x8.
DROP_TXT = """
..a..
..a..
.aab.
.abb.
aabbc
aabbc
.bbc.
..c..
"""

# Ferradura? nao — pegada de anta (3 dedos), 16x16, vista de cima.
PRINT_TXT = """
......dd........
.....dDDd.......
.....dDDd..dd...
..dd..dd..dDDd..
.dDDd.....dDDd..
.dDDd......dd...
..dd............
....dddddddd....
...dDDDDDDDDd...
..dDDDDDDDDDDd..
..dDDDDDDDDDDd..
..dDDDDDDDDDDd..
...dDDDDDDDDd...
....dDDDDDDd....
.....dddddd.....
................
"""
PRINT_PAL = {"d": "#3a2a1a", "D": "#5e4428"}


def drop(a, b, c) -> Spr:
    return spr(DROP_TXT, {"a": a, "b": b, "c": c})


def flag(color: str) -> Spr:
    return Spr.parse(FLAG_TXT, {"k": "#2a1c10", "a": color})


# ------------------------------------------------------------------ desenho procedural comum
def vine(cv: Canvas, pts, w0: float, w1: float, v: float) -> None:
    n = len(pts)
    cv.stroke(pts, [lerp(w0, w1, i / max(n - 1, 1)) for i in range(n)], [v] * n)


def spiral_vine(cx, cy, r0, r1, turns, ry, a0=0.0, n=40, rise=0.0):
    """Cipo em espiral achatada (enrola nos pes/corpo). rise = quanto sobe (px) do inicio ao fim."""
    pts = []
    for i in range(n):
        t = i / (n - 1)
        a = a0 + t * turns * TAU
        r = lerp(r0, r1, t)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * ry - t * rise))
    return pts


def leaf_poly(x, y, ang, ln, wd):
    """Folha (lente) de comprimento ln e largura wd, apontando em ang, base em (x, y)."""
    c, s = math.cos(ang), math.sin(ang)
    pts = []
    for i in range(9):
        t = i / 8
        o = math.sin(t * math.pi) * wd * 0.5
        pts.append((x + c * t * ln - s * o, y + s * t * ln + c * o))
    for i in range(7, 0, -1):
        t = i / 8
        o = -math.sin(t * math.pi) * wd * 0.5
        pts.append((x + c * t * ln - s * o, y + s * t * ln + c * o))
    return pts


def claw_marks(cv: Canvas, cx, cy, ang, ln, gap, n, w, v, curve=0.18):
    """n riscos paralelos de garra (curvos, afinando nas pontas)."""
    c, s = math.cos(ang), math.sin(ang)
    px, py = -s, c
    for k in range(n):
        o = (k - (n - 1) / 2) * gap
        pts, ws = [], []
        for i in range(9):
            t = i / 8
            d = (t - 0.5) * ln
            bend = math.sin(t * math.pi) * ln * curve
            pts.append((cx + c * d + px * (o + bend), cy + s * d + py * (o + bend)))
            ws.append(w * math.sin(t * math.pi) ** 0.6 + 0.3)
        cv.stroke(pts, ws, [v] * 9)


def puff(cv: Canvas, x, y, r, v_out=0.3, v_mid=0.55, v_in=0.8):
    """Nuvem de poeira/fumaca: tres bolotas sobrepostas de tamanhos diferentes (contorno irregular, nada de
    bola lisa) com o claro so num canto de cima."""
    for (dx, dy, k) in ((-0.45, 0.15, 0.62), (0.4, 0.2, 0.55), (0.0, -0.1, 0.78)):
        cv.circle(x + dx * r, y + dy * r, r * k, v_out)
    cv.circle(x - r * 0.1, y - r * 0.05, r * 0.6, v_mid)
    cv.circle(x - r * 0.25, y - r * 0.3, r * 0.28, v_in)


def dither_alpha(fr: Frame, keep: float, seed: int = 0) -> None:
    """Some em pontilhado (pixel art): mantem a fracao 'keep' dos pixels num padrao ordenado 4x4."""
    if keep >= 0.999:
        return
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
    h, w = fr.h, fr.w
    th = np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w]
    if seed:
        th = np.roll(th, seed, axis=1)
    fr.rgba[th >= keep, 3] = 0


def sparkle(fr: Frame, x, y, size, core=W_WHITE, arm=W_GOLD, tip=W_PALE):
    fr.twinkle(x, y, size, core, arm, tip)


__all__ = [n for n in dir() if not n.startswith("_")]
_ = (rng, blit)
