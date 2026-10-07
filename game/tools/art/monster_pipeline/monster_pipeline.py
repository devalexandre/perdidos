"""Pipeline de MONSTROS (mesmo estilo aprovado dos NPCs/Viajante v2 e da Ancora 3 - Tatu-Pedra).
Bria FIBO (generate/edit) + RMBG-2.0, reaproveitando tools/art/character_pipeline/{gen,edit,rmbg}.py.
Cada etapa e reexecutavel (pula arquivos ja feitos). Pasta de trabalho: $MON_WORK/<id>_s<n> (padrao ./work).
  gen    <id> <n>            6 variacoes 3/4 frente-direita (SE) a partir do texto (style + monsters.json)
  seed   <id> <n> <png>      usa uma imagem pronta como SE escolhida (ex.: Ancora 3 para o Tatu-Pedra s1)
  evolve <id> <n>            estagio n (2 ou 3) por EDICAO da SE escolhida do estagio n-1 (3 variacoes)
  dirs   <id> <n>            S, E, NE, N por edicao da SE escolhida (2 variacoes cada)
  attack <id> <n>            pose de ataque por edicao de cada direcao escolhida (2 variacoes cada)
  rmbg   <id> <n>            remove o fundo dos arquivos escolhidos (picks.json)
  board  <id> <n> <glob>     prancha de candidatos para escolher OLHANDO
picks.json: {"se": "f_2.png", "dirs": {"s": f, "se": f, "e": f, "ne": f, "n": f}, "atk": {"s": f, ...},
             "flip": ["e", ...] (espelhar a linha para olhar a DIREITA), "atk_flip": [...]}
Chave: variavel BK (nunca imprimir). Folhas: build_monster.py."""
import glob, json, os, sys, time, zlib, concurrent.futures as cf
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'character_pipeline'))
import gen as G  # noqa: E402
from edit import edit  # noqa: E402
from rmbg import rmbg as _rmbg  # noqa: E402

CFG = json.load(open(os.path.join(HERE, 'monsters.json')))
STYLE = open(os.path.join(HERE, 'style_block.txt')).read().strip()
NEG = open(os.path.join(HERE, 'neg.txt')).read().strip()
KEEP = ("Keep exactly the same creature design, face, colors, markings, proportions, size, pixel art style, "
        "dark warm brown outline and plain white background. Single creature, full body, same 3/4 top-down game camera.")
DIR_TXT = {
    's': "Rotate the creature to face the viewer directly (front view, body symmetric, both eyes visible, looking toward the bottom of the image).",
    'e': "Rotate the creature to an exact side profile facing to the RIGHT edge of the image (only one eye visible, nose/front pointing right).",
    'ne': "Rotate the creature to a three-quarter BACK view, turned away from the viewer toward the upper right: we see its back and the back of its head, the eyes are NOT visible.",
    'n': "Rotate the creature to a full BACK view, turned completely away from the viewer: we see only its back and the back of its head; the face and eyes are NOT visible at all. Symmetric.",
}


def work(mid, n):
    d = os.path.join(os.environ.get('MON_WORK', os.path.join(HERE, 'work')), f'{mid}_s{n}')
    os.makedirs(d, exist_ok=True)
    return d


def seed_of(mid, n):
    return 30000 + zlib.crc32(f'{mid}_{n}'.encode()) % 50000


def picks(mid, n):
    p = os.path.join(work(mid, n), 'picks.json')
    return json.load(open(p)) if os.path.exists(p) else {}


def save_picks(mid, n, P):
    json.dump(P, open(os.path.join(work(mid, n), 'picks.json'), 'w'), indent=1)


def _retry(fn, *a):
    for t in range(6):
        try: return fn(*a)
        except Exception as e:
            if t == 5 or not any(s in str(e) for s in ('429', 'timed out', '500', '502', '503', 'Connection')): raise
            time.sleep(8 * (t + 1))


def run_edits(jobs):
    jobs = [j for j in jobs if not os.path.exists(j[2])]
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '3'))) as ex:
        futs = {ex.submit(_retry, edit, *j): j for j in jobs}
        for f in cf.as_completed(futs):
            try: print('ok', os.path.basename(f.result()), flush=True)
            except Exception as e: print('err', os.path.basename(futs[f][2]), str(e)[:160], flush=True)


def stage_gen(mid, n, count=6):
    c = CFG[mid]['stages'][str(n)]
    prompt = STYLE.format(desc=c['desc'], dir='facing three-quarters to the front-right')
    wd = work(mid, n)
    open(os.path.join(wd, 'prompt.txt'), 'w').write(prompt + '\n\nNEGATIVE: ' + NEG + f'\nSEED: {seed_of(mid, n)}+i\n')
    G.NEG, G.AR, G.SEED = NEG, '1:1', seed_of(mid, n)
    G.sys.argv = ['gen', os.path.join(wd, 'f')]
    todo = [i for i in range(count) if not os.path.exists(os.path.join(wd, f'f_{i}.png'))]
    with cf.ThreadPoolExecutor(3) as ex:
        for f in cf.as_completed([ex.submit(_retry, G.gen, i, prompt) for i in todo]):
            try: print('ok', mid, n, f.result(), flush=True)
            except Exception as e: print('err', mid, n, str(e)[:160], flush=True)


def stage_seed(mid, n, png):
    import shutil
    wd = work(mid, n); shutil.copy(png, os.path.join(wd, 'f_seed.png'))
    P = picks(mid, n); P['se'] = 'f_seed.png'; save_picks(mid, n, P)


def stage_evolve(mid, n, count=3):
    prev = picks(mid, n - 1)
    src = os.path.join(work(mid, n - 1), prev['se'])
    c = CFG[mid]['stages'][str(n)]
    wd = work(mid, n)
    instr = c['evolve'] + " Keep the same pixel art style, dark warm brown outline, 3/4 top-down camera facing front-right, plain white background, single creature, full body."
    open(os.path.join(wd, 'prompt.txt'), 'w').write('EDIT of ' + src + ':\n' + instr + f'\nSEED: {seed_of(mid, n)}+k\n')
    run_edits([[src, instr, os.path.join(wd, f'f_{k}.png'), seed_of(mid, n) + k] for k in range(count)])


def stage_dirs(mid, n, dirs=None, variants=2, base=0):
    wd = work(mid, n); P = picks(mid, n); src = os.path.join(wd, P['se'])
    jobs = [[src, DIR_TXT[d] + ' ' + KEEP, os.path.join(wd, f'd_{d}_{k}.png'), seed_of(mid, n) + 100 + k]
            for d in (dirs or DIR_TXT) for k in range(base, base + variants)]
    run_edits(jobs)


def stage_attack(mid, n, dirs=None, variants=2, base=0):
    wd = work(mid, n); P = picks(mid, n); act = CFG[mid]['attack']
    jobs = []
    for d, f in P['dirs'].items():
        if dirs and d not in dirs: continue
        for k in range(base, base + variants):
            jobs.append([os.path.join(wd, f), f"Change the pose: the creature is attacking, {act}. Keep the same facing direction and camera angle. " + KEEP,
                         os.path.join(wd, f'a_{d}_{k}.png'), seed_of(mid, n) + 300 + k])
    run_edits(jobs)


def stage_rmbg(mid, n):
    wd = work(mid, n); P = picks(mid, n)
    files = set(v.lstrip('!') for v in list(P.get('dirs', {}).values()) + list(P.get('atk', {}).values()))
    todo = [f for f in files if not os.path.exists(os.path.join(wd, 'rb_' + f))]
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '3'))) as ex:
        futs = {ex.submit(_retry, _rmbg, os.path.join(wd, f), os.path.join(wd, 'rb_' + f)): f for f in todo}
        for f in cf.as_completed(futs):
            try: print('ok', os.path.basename(f.result()), flush=True)
            except Exception as e: print('err', futs[f], str(e)[:160], flush=True)


def stage_board(mid, n, pattern):
    from PIL import Image, ImageDraw
    wd = work(mid, n); fs = sorted(glob.glob(os.path.join(wd, pattern)))
    cols = min(6, max(1, len(fs))); rows = (len(fs) + cols - 1) // cols; S = 256
    b = Image.new('RGB', (cols * S, rows * (S + 16)), (240, 230, 200)); dr = ImageDraw.Draw(b)
    for i, f in enumerate(fs):
        im = Image.open(f).convert('RGBA'); bg = Image.new('RGBA', im.size, (240, 230, 200, 255)); bg.alpha_composite(im)
        b.paste(bg.convert('RGB').resize((S, S), Image.BOX), ((i % cols) * S, (i // cols) * (S + 16) + 16))
        dr.text(((i % cols) * S + 4, (i // cols) * (S + 16) + 2), os.path.basename(f), fill=(60, 30, 20))
    out = os.path.join(wd, 'board_' + pattern.replace('*', 'X').replace('.png', '') + '.png'); b.save(out); print(out)


if __name__ == '__main__':
    st, mid, n, *rest = sys.argv[1:]
    n = int(n)
    {'gen': lambda: stage_gen(mid, n), 'seed': lambda: stage_seed(mid, n, rest[0]), 'evolve': lambda: stage_evolve(mid, n),
     'dirs': lambda: stage_dirs(mid, n, rest or None), 'attack': lambda: stage_attack(mid, n, rest or None),
     'rmbg': lambda: stage_rmbg(mid, n), 'board': lambda: stage_board(mid, n, rest[0]),
     'dirs2': lambda: stage_dirs(mid, n, rest, 2, 2), 'attack2': lambda: stage_attack(mid, n, rest, 2, 2)}[st]()
