#!/usr/bin/env python3
"""Teste de ponta a ponta do importador (sem ChatGPT).

    python3 tools/art/ai_guides/make_ai_guides.py <render> <guias> --fake <falsas>     (devolucao falsa)
    python3 tools/art/ai_guides/test_import.py <falsas> <pasta_temporaria>

Importa a devolucao falsa como a roupa `student_pindorama_test` numa pasta temporaria (nunca em assets/) e confere:
tamanhos das folhas, alfa binario, <= 48 cores, nenhum quadro vazio, pes na linha do chao nas animacoes em pe
(sem deslizar: base e centro dos pes), ancoras do pescoco (formato, e perto do pescoco da guia) e as recusas
(quadro apagado e parte faltando). Sai com codigo 1 se algo falhar.
"""
import glob, json, os, shutil, subprocess, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import import_ai_sheet as IM  # noqa: E402

OUTFIT = 'student_pindorama_test'
EXPECT = {'idle': 4, 'walk': 8, 'sit': 1, 'attack_unarmed': 6, 'cast': 6, 'hit': 4, 'death': 6}
STANDING_GAME = ['idle', 'walk', 'attack_unarmed', 'cast', 'hit']


def main(fake, tmp):
    fails = []
    ok = lambda c, m: None if c else fails.append(m)  # noqa: E731
    out, work = os.path.join(tmp, 'outfits'), os.path.join(tmp, 'work')
    shutil.rmtree(tmp, ignore_errors=True)
    for body in ('male', 'female'):
        imgs = sorted(glob.glob(os.path.join(fake, f'{body}_p*.png')))
        rep, errs = IM.import_body(body, OUTFIT, imgs, out, work, preview=True)
        ok(not errs, f'{body}: importacao recusada: {errs}')
        if errs:
            continue
        lay, _ = IM.load_guides(body)
        anc = json.load(open(os.path.join(out, f'chr_{OUTFIT}_anchors.json')))
        for anim, n in EXPECT.items():
            p = os.path.join(out, f'chr_{body}_{OUTFIT}_{anim}.png')
            ok(os.path.exists(p), f'falta {p}')
            if not os.path.exists(p):
                continue
            a = np.asarray(Image.open(p).convert('RGBA'))
            ok(a.shape[:2] == (480, 96 * n), f'{body} {anim}: tamanho {a.shape[1]}x{a.shape[0]} != {96 * n}x480')
            ok(set(np.unique(a[..., 3])) <= {0, 255}, f'{body} {anim}: alfa nao binario')
            nc = len({tuple(c) for c in a[a[..., 3] > 0][:, :3]})
            ok(nc <= 48, f'{body} {anim}: {nc} cores > 48')
            rows = anc[body][anim]
            ok(len(rows) == 5 and all(len(r) == n for r in rows), f'{body} {anim}: ancoras {len(rows)}x{len(rows[0])}')
            for r in range(5):
                bots, cxs = [], []
                for c in range(n):
                    fr = a[r * 96:(r + 1) * 96, c * 96:(c + 1) * 96, 3] > 0
                    ok(fr.any(), f'{body} {anim} linha {r} coluna {c}: quadro vazio')
                    if not fr.any():
                        continue
                    ys, xs = np.nonzero(fr)
                    bots.append(ys.max())
                    feet = xs[ys >= ys.max() - 3]; cxs.append(feet.mean())
                    e = rows[r][c]
                    ok(set(e) >= {'dx', 'dy', 'mirror_idle', 'key', 'fit'}, f'{body} {anim}: ancora sem campos')
                if anim in STANDING_GAME:
                    ok(max(bots) == min(bots) == IM.GROUND_Y,
                       f'{body} {anim} {IM.DIRS[r]}: pes fora da linha do chao {sorted(set(bots))}')
                if anim == 'idle':
                    ok(np.ptp(cxs) <= 2.0, f'{body} idle {IM.DIRS[r]}: pes deslizam {np.ptp(cxs):.1f} px')
        # pescoco detectado x pescoco da guia
        d = []
        for k, f in rep['frames'].items():
            d.append(np.hypot(f['neck'][0] - f['neck_guide'][0], f['neck'][1] - f['neck_guide'][1]))
        d = np.array(d)
        ok(np.median(d) <= 3.0, f'{body}: pescoco longe da guia (mediana {np.median(d):.1f} px)')
        print(f'{body}: {len(rep["frames"])} quadros, IoU min {min(f["iou"] for f in rep["frames"].values()):.2f}, '
              f'pescoco x guia: mediana {np.median(d):.1f} px, p90 {np.percentile(d, 90):.1f} px, max {d.max():.1f} px')
    # recusas: quadro apagado e parte faltando
    body = 'male'
    imgs = sorted(glob.glob(os.path.join(fake, f'{body}_p*.png')))
    bad_dir = os.path.join(tmp, 'bad'); os.makedirs(bad_dir, exist_ok=True)
    src = [p for p in imgs if 'p2_andar' in p][0]
    im = Image.open(src).convert('RGB'); W, H = im.size
    lay, _ = IM.load_guides(body)
    c = lay['parts']['p2_andar']['cells']['walk|SE|3']
    sx, sy = W / IM.PARTS['p2_andar']['size'][0], H / IM.PARTS['p2_andar']['size'][1]
    x, y, w, h = c['rect']
    im.paste((255, 255, 255), (int((x + 9) * sx), int((y - 7) * sy), int((x + 9 + w) * sx), int((y - 7 + h) * sy)))
    bad = os.path.join(bad_dir, os.path.basename(src)); im.save(bad)
    rep, errs = IM.import_body(body, 'x_bad', [p if p != src else bad for p in imgs], os.path.join(tmp, 'bad_out'),
                               os.path.join(tmp, 'bad_work'))
    ok(rep is None and any('walk SE 4' in e for e in errs), f'quadro apagado nao foi recusado: {errs}')
    ok(not os.path.exists(os.path.join(tmp, 'bad_out')), 'recusa escreveu arquivos')
    print('recusa (quadro apagado):', errs)
    rep, errs = IM.import_body(body, 'x_bad', imgs[:3], os.path.join(tmp, 'bad_out'), os.path.join(tmp, 'bad_work'))
    ok(rep is None and any('faltando' in e for e in errs), f'parte faltando nao foi recusada: {errs}')
    print('recusa (parte faltando):', errs)
    # CLI: codigo de saida 2 e mensagem clara
    r = subprocess.run([sys.executable, os.path.join(os.path.dirname(HERE), 'import_ai_sheet.py'), body, 'x_bad',
                        *[p if p != src else bad for p in imgs], '--out', os.path.join(tmp, 'bad_out')],
                       capture_output=True, text=True)
    ok(r.returncode == 2 and 'recusada' in r.stderr, f'CLI: codigo {r.returncode}, {r.stderr[:200]}')
    if fails:
        print('FALHOU:'); [print('  -', f) for f in fails]
        sys.exit(1)
    print('OK: importador de ponta a ponta')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
