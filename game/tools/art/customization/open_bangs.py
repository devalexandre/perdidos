"""Abre a franja sobre os olhos (Agente F, 28/09/2026). Deterministico e idempotente; roda DEPOIS de eyes.py.

    python open_bangs.py [--dry]

O rabo de cavalo feminino (cabelo padrao, pixels originais do Viajante) tem uma mecha que cai sobre o olho
esquerdo (da tela) em S e em parte do L: a cor do olho quase nao aparece desse lado. Aqui, em toda folha
hair/<estilo>/<corpo>_<anim>.png listada em TARGETS, os pixels de cabelo que cobrem o DESENHO do olho (camada
eyes/<corpo>_<anim>.png: iris ou cor literal - cilio, branco, reflexo; nao a pele de cobertura) sao apagados
(tipicamente 1-3 px por linha, so onde a mecha cruza o olho). Linhas S, SE e L (NE/N nao tem olho). Idempotente.
Tambem vale para o quadro do piscar (eyes/<corpo>_idle_blink.png), que usa a mesma folha idle do cabelo.
"""
import os, sys
import numpy as np
from PIL import Image
from common import GAME, FR

CH = os.path.join(GAME, 'assets', 'characters')
TARGETS = [('ponytail', 'female')]
ROWS = (0, 1, 2)


def eye_drawing(e):
    """Pixels do desenho do olho (nao a pele de cobertura codificada (v,0,0))."""
    op = e[..., 3] > 0
    skin = (e[..., 0] > 0) & (e[..., 1] == 0) & (e[..., 2] == 0)
    return op & ~skin


def open_frame(h, e):
    """Apaga o cabelo que cobre o desenho do olho. Devolve px apagados."""
    m = eye_drawing(e) & (h[..., 3] > 0); h[m] = 0
    return int(m.sum())


def main(dry):
    for style, body in TARGETS:
        for f in sorted(os.listdir(os.path.join(CH, 'hair', style))):
            if not (f.startswith(body + '_') and f.endswith('.png')): continue
            anim = f[len(body) + 1:-4]
            hp = os.path.join(CH, 'hair', style, f)
            eps = [os.path.join(CH, 'eyes', f'{body}_{anim}.png')]
            if anim == 'idle': eps.append(os.path.join(CH, 'eyes', f'{body}_idle_blink.png'))
            eps = [p for p in eps if os.path.exists(p)]
            if not eps: continue
            h = np.asarray(Image.open(hp).convert('RGBA')).copy(); tot = 0
            for ep in eps:
                e = np.asarray(Image.open(ep).convert('RGBA'))
                if e.shape != h.shape: print('  tamanho diferente', ep); continue
                for r in ROWS:
                    for c in range(h.shape[1] // FR):
                        sl = (slice(r * FR, (r + 1) * FR), slice(c * FR, (c + 1) * FR))
                        hf = h[sl].copy(); tot += open_frame(hf, e[sl]); h[sl] = hf
            if tot and not dry: Image.fromarray(h, 'RGBA').save(hp)
            print(('(dry) ' if dry else '') + f'{hp}: {tot} px abertos')


if __name__ == '__main__':
    main('--dry' in sys.argv)
