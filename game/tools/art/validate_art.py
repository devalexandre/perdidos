#!/usr/bin/env python3
"""Validador de tamanho e paleta das artes novas do marco "Passeio no Porto do Despertar".
  python3 tools/art/validate_art.py      (exit 1 se houver problema)
- icones (32x32), enfeites, UI e emotes: so cores da paleta mestra e alfa binario (tools/art/palette.py);
- folhas de personagem (NPCs, Viajante sit, roupas): quadros 96x96 (idle 4, walk 8, sit 1 coluna; 5 linhas),
  no maximo 48 cores (paleta propria por personagem, como o Viajante v2), conteudo dentro do quadro;
- camadas de equipamento: mesmo formato das folhas do corpo, no maximo 32 cores."""
import glob, os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); GAME = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import palette as P
errs = []
COLS = {'idle': 4, 'walk': 8, 'sit': 1}
# combate vivo (GDD §10.2.1 / §17.3, Agente A): golpes por arma, cast e morte, 6 quadros
COLS.update({'attack_unarmed': 6, 'attack_blade': 6, 'attack_staff': 6, 'cast': 6, 'death': 6})
# arco (30/09/2026): attack_bow = poses de golpe/cast recompostas + camada do arco (title_outfits/bow.py)
COLS['attack_bow'] = 6
# C3 (28/09/2026, GDD §17.0.B): personagem jogavel do pipeline 3D (tools/art/blender/characters) com mais quadros:
# idle 8, golpes/cast/morte 8, hit 4. As folhas antigas (NPCs) continuam valendo com as contagens acima.
COLS_ALT = {'idle': (4, 8), 'attack_unarmed': (6, 8), 'attack_blade': (6, 8), 'attack_staff': (6, 8), 'cast': (6, 8),
            'death': (6, 8), 'hit': (2, 4)}
COLS.setdefault('hit', 4)


def err(f, m): errs.append(f'{os.path.relpath(f, GAME)}: {m}')


def master(files, size=None):
    for f in files:
        im = Image.open(f).convert('RGBA')
        if size and im.size != size: err(f, f'tamanho {im.size} != {size}')
        a = np.asarray(im); op = a[..., 3] > 0
        if ((a[..., 3] > 0) & (a[..., 3] < 255)).any(): err(f, 'alfa semitransparente')
        pal = {c for c, _ in P.load_palette()}
        bad = {tuple(c) for c in a[op][:, :3]} - pal
        if bad: err(f, f'{len(bad)} cor(es) fora da paleta mestra')


def sheet(f, maxc):
    im = Image.open(f).convert('RGBA'); a = np.asarray(im)
    anim = next((k for k in COLS if f'_{k}' in os.path.basename(f)), None)
    if anim is None: err(f, 'animacao desconhecida'); return
    ok_cols = COLS_ALT.get(anim, (COLS[anim],))
    ncol = im.size[0] // 96
    if im.size[1] != 96 * 5 or im.size[0] % 96 or ncol not in ok_cols:
        err(f, f'tamanho {im.size} != {[(96 * c, 480) for c in ok_cols]}')
        return
    COLS_F = ncol
    n = len({tuple(c) for c in a[a[..., 3] > 0][:, :3]})
    if n > maxc: err(f, f'{n} cores > {maxc}')
    # Mascaras de recoloracao podem ficar totalmente transparentes quando a pose nao expoe pele/cabelo.
    if 'equipment' not in f and '_mask_' not in os.path.basename(f):
        for r in range(5):
            for c in range(COLS_F):
                fr = a[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96, 3] > 0
                if not fr.any(): err(f, f'quadro vazio linha {r} coluna {c}')


master(glob.glob(f'{GAME}/assets/items/icons/*.png'), (32, 32))
master(glob.glob(f'{GAME}/assets/environment/props/*.png'))
master(glob.glob(f'{GAME}/assets/ui/*.png') + glob.glob(f'{GAME}/assets/ui/emotes/*.png'))
for f in glob.glob(f'{GAME}/assets/npcs/*.png') + glob.glob(f'{GAME}/assets/characters/outfits/*.png') + glob.glob(f'{GAME}/assets/characters/*_sit.png') \
        + [f for k in ('attack_unarmed', 'attack_blade', 'attack_staff', 'attack_bow', 'cast', 'death') for f in glob.glob(f'{GAME}/assets/characters/chr_traveler_*_{k}.png')]:
    sheet(f, 48)
for f in glob.glob(f'{GAME}/assets/equipment/**/*.png', recursive=True):
    sheet(f, 32)
# monstros do Campo de Treino (agente W): quadros quadrados (altura/5), colunas idle 4 / walk 6 / attack 6 / hit 2 /
# death 6, alfa binario, ate 40 cores por folha, nenhum quadro vazio exceto o fim do death
# Monstros do Blender (agente B3, docs/arte-monstros-blender.md): idle 8 / walk 8 / attack 8 / hit 4 / death 8 e
# quadros de 64/96/144/240 (GDD 17.2); so cores da paleta mestra (ate as 50 dela).
MCOLS = {'idle': (4, 8), 'walk': (6, 8), 'attack': (6, 8), 'hit': (2, 4), 'death': (6, 8)}
MPAL = {c for c, _ in P.load_palette()}
for f in glob.glob(f'{GAME}/assets/monsters/*/*.png'):
    anim = f.rsplit('_', 1)[1][:-4]
    im = Image.open(f).convert('RGBA'); a = np.asarray(im); F = im.height // 5
    if anim not in MCOLS: err(f, 'animacao desconhecida'); continue
    cols = im.width // F if F else 0
    if im.height % 5 or im.width % F or cols not in MCOLS[anim]:
        err(f, f'tamanho {im.size} (quadro {F}, {cols} colunas; esperado {MCOLS[anim]})')
    if ((a[..., 3] > 0) & (a[..., 3] < 255)).any(): err(f, 'alfa semitransparente')
    used = {tuple(int(x) for x in c) for c in a[a[..., 3] > 0][:, :3]}
    if len(used) > 40 and not used <= MPAL: err(f, f'{len(used)} cores > 40')
    for r in range(5):
        for c in range(cols):
            if not (a[r * F:(r + 1) * F, c * F:(c + 1) * F, 3] > 0).any(): err(f, f'quadro vazio linha {r} coluna {c}')
# crianca visivelmente menor que os adultos
def height(f):
    a = np.asarray(Image.open(f).convert('RGBA'))[0:96, 0:96, 3] > 0; ys = np.nonzero(a.any(1))[0]; return ys.max() - ys.min() + 1
ch = height(f'{GAME}/assets/npcs/npc_curious_child_idle.png'); ad = height(f'{GAME}/assets/npcs/npc_merchant_idle.png')
if ch > ad * 0.85: err('npc_curious_child_idle.png', f'crianca ({ch}px) nao e menor que adulto ({ad}px)')
n = len(glob.glob(f'{GAME}/assets/items/icons/*.png'))
print(f'{n} icones; problemas: {len(errs)}')
for e in errs: print('  ' + e)
sys.exit(1 if errs else 0)
