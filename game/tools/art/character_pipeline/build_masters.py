"""Mestres do Campo de Treino (agente W): folha idle 5 direcoes pelo build_npc.py (mesmo formato dos NPCs) e uma
folha walk de reserva feita do idle (os Mestres ficam parados, rotina IDLE; o visual exige a folha walk).
build_masters.py <npc> ...   (picks.json de cada um so com "idle" por direcao)"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_npc as B
FR = 96
for npc in sys.argv[1:]:
    B.build(npc, only='idle')
    base = os.path.join(B.GAME, 'assets', 'npcs', f'npc_{npc}')
    idle = Image.open(base + '_idle.png')
    walk = Image.new('RGBA', (FR * 8, FR * 5))
    for r in range(5):
        f0 = idle.crop((0, r * FR, FR, r * FR + FR))
        for c in range(8):
            walk.alpha_composite(f0, (c * FR, r * FR - (1 if c % 4 in (1, 2) else 0)))
    walk.save(base + '_walk.png'); print('walk', base)
