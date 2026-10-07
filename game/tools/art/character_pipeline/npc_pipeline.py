"""Pipeline de NPCs (mesmo estilo do Viajante v2). Etapas, cada uma reexecutavel (pula arquivos ja feitos):
  gen   <id>              8 variacoes de frente a partir do texto (style_block + npcs.json + neg.txt)
  dirs  <id> <frente.png> SE, E, NE, N por EDICAO da frente escolhida (2 variacoes cada)
  walk  <id>              passos wl/wr por edicao do idle escolhido de cada direcao (picks.json da pasta)
  sit   <id> [src_dir]    sentado no chao (1 quadro por direcao) a partir dos idles escolhidos
  rmbg  <id>              remove o fundo de todos os arquivos citados em picks.json
  dirs2 <id> <frente.png> <dir...>  nova tentativa com instrucao reforcada (costas sem rosto etc.)
  walk2 <id> <dir...>     passos com instrucao reforcada (costas/perfil)
  edit  <id> <src> <chave|instrucao> <prefixo>   edicao livre (3 variacoes), ex.: chave idle_n
  board <id> <glob>       prancha de candidatos (para escolher olhando)
Pasta de trabalho: $NPC_WORK/<id> (padrao: ./work/<id>). Chave: variavel BK (nunca imprimir).
Depois: build_npc.py monta as folhas."""
import glob, json, os, sys, zlib, concurrent.futures as cf
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen as G
from edit import edit
from rmbg import rmbg as _rmbg

CFG = json.load(open(os.path.join(HERE, 'npc', 'npcs.json')))
STYLE = open(os.path.join(HERE, 'npc', 'style_block.txt')).read().strip()
NEG = open(os.path.join(HERE, 'neg.txt')).read().strip()
KEEP = ("Keep exactly the same character design, face, outfit, {prop}, colors, hair, proportions, size, "
        "pixel art style and white background. Single character, full body, same 3/4 top-down camera.")
DIR_TXT = {
    'se': "Rotate the character to face three-quarters to the right (front-right view, body turned 45 degrees to the viewer's right, face still visible), standing idle pose.",
    'e': "Rotate the character to a full side profile view facing to the right, standing idle pose.",
    'ne': "Rotate the character to a three-quarter back view facing away to the upper right (back-right view, face mostly hidden), standing idle pose.",
    'n': "Rotate the character to a full back view facing away from the viewer, showing the back of the head, standing idle pose.",
}
WALK_TXT = {
    's': "Make the character walk straight toward the viewer, body and face facing directly forward (front view, symmetric), {foot} foot stepping forward and slightly lower, {other} foot behind, arms swinging naturally.",
    'n': "Make the character walk straight away from the viewer, seen directly from behind (back view, symmetric, face not visible), {foot} foot stepping forward, {other} foot behind, arms swinging naturally.",
    'side': "Change the pose to a walking mid-stride: {foot} leg stepping forward, {other} leg behind, arms swinging naturally. Keep the same facing direction.",
}
SIT_TXT = ("Change the pose to sitting on the ground with legs crossed, relaxed, hands resting on the knees, "
           "keeping the same facing direction and the same camera angle. Nothing else drawn, no furniture.")


def work(npc):
    d = os.path.join(os.environ.get('NPC_WORK', os.path.join(HERE, 'work')), npc)
    os.makedirs(d, exist_ok=True)
    return d


def keep(npc):
    return KEEP.format(prop=CFG[npc]['prop']) if npc in CFG else KEEP.format(prop='accessories')


def _edit_retry(*j):
    import time
    for t in range(6):
        try: return edit(*j)
        except Exception as e:
            if '429' not in str(e) or t == 5: raise
            time.sleep(10 * (t + 1))


def run_edits(jobs):
    jobs = [j for j in jobs if not os.path.exists(j[2])]
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '3'))) as ex:
        futs = {ex.submit(_edit_retry, *j): j for j in jobs}
        for f in cf.as_completed(futs):
            try: print('ok', os.path.basename(f.result()))
            except Exception as e: print('err', os.path.basename(futs[f][2]), str(e)[:200])


def seed_of(npc):
    return 20000 + zlib.crc32(npc.encode()) % 50000


def stage_gen(npc, n=8):
    c = CFG[npc]
    prompt = STYLE.format(build=c['build'], face=c['face'], desc=c['desc'])
    neg = ', '.join(t.strip() for t in NEG.split(',') if t.strip() not in c.get('neg_drop', []))
    wd = work(npc)
    open(os.path.join(wd, 'prompt.txt'), 'w').write(prompt + '\n\nNEGATIVE: ' + neg + '\n')
    G.NEG, G.AR, G.SEED = neg, '1:1', seed_of(npc)
    G.sys.argv = ['gen', os.path.join(wd, 'f')]
    todo = [i for i in range(n) if not os.path.exists(os.path.join(wd, f'f_{i}.png'))]
    with cf.ThreadPoolExecutor(4) as ex:
        for f in cf.as_completed([ex.submit(G.gen, i, prompt) for i in todo]):
            try: print('ok', f.result())
            except Exception as e: print('err', str(e)[:200])


def stage_dirs(npc, front):
    wd = work(npc)
    src = os.path.join(wd, front)
    jobs = [[src, DIR_TXT[d] + ' ' + keep(npc), os.path.join(wd, f'd_{d}_{k}.png'), seed_of(npc) + 100 + k]
            for d in DIR_TXT for k in range(2)]
    run_edits(jobs)


DIR_STRONG = {
    'se': "Turn the character 45 degrees so the body and face point toward the lower right of the image (front-right three-quarter view). The nose and eyes point to the viewer's right.",
    'e': "Show the character in exact side profile walking direction to the RIGHT: nose pointing to the right edge of the image, only one eye visible, standing idle pose.",
    'ne': "Show the character from BEHIND at a three-quarter angle, turned away from the viewer toward the upper right: we see the back of the head, the back of the clothes and only a sliver of the cheek on the right side; the eyes and face are NOT visible. Standing idle pose.",
    'n': "Show the character completely from BEHIND, turned away from the viewer: we see only the back of the head, the back of the hat and the back of the clothes; the face, eyes and glasses are NOT visible at all. Symmetric back view, standing idle pose.",
}


def stage_dirs2(npc, front, dirs, n=3):
    wd = work(npc)
    jobs = [[os.path.join(wd, front), DIR_STRONG[d] + ' ' + keep(npc), os.path.join(wd, f'd_{d}_{k}.png'), seed_of(npc) + 200 + k]
            for d in dirs for k in range(2, 2 + n)]
    run_edits(jobs)


WALK_STRONG = {
    'n': "Seen completely from BEHIND (face, eyes and glasses NOT visible, only the back of the head and clothes): make the character walk straight away from the viewer, symmetric back view, {foot} foot stepping forward, {other} foot behind, arms swinging naturally.",
    'ne': "Seen from BEHIND at a three-quarter angle (face and eyes NOT visible, only the back of the head and a sliver of cheek on the right): make the character walk away from the viewer toward the upper right, {foot} leg stepping forward, {other} leg behind, arms swinging naturally.",
    'e': "Exact side profile, nose pointing to the RIGHT edge of the image, only one eye visible: make the character walk to the right, {foot} leg stepping forward, {other} leg behind, arms swinging naturally.",
    'se': "Three-quarter front view, body and face turned toward the lower RIGHT of the image: make the character walk toward the lower right, {foot} leg stepping forward, {other} leg behind, arms swinging naturally.",
    's': WALK_TXT['s'],
    'sit_n': "Seen completely from BEHIND (face NOT visible, only the back of the head and the back of the clothes): change the pose to sitting on the ground with legs crossed in front of him, relaxed, hands on the knees, the body still turned away from the viewer (the backpack stays on the back if there is one). Nothing else drawn, no furniture.",
    'sit_ne': "Seen from BEHIND at a three-quarter angle toward the upper right (face NOT visible, only a sliver of cheek on the right): change the pose to sitting on the ground with legs crossed, relaxed, hands on the knees, the body still turned away from the viewer (the backpack stays on the back if there is one). Nothing else drawn, no furniture.",
    'idle_n': "Change the pose to standing still in a relaxed idle pose, feet side by side slightly apart, arms relaxed at the sides, seen completely from BEHIND (face not visible), symmetric back view.",
}


def stage_walk2(npc, dirs, n=3):
    wd = work(npc); P = picks(npc); jobs = []
    for d in dirs:
        src = os.path.join(wd, P['dirs'][d]['idle'])
        for foot, other, tag in (('left', 'right', 'wl'), ('right', 'left', 'wr')):
            for k in range(2, 2 + n):
                jobs.append([src, WALK_STRONG[d].format(foot=foot, other=other) + ' ' + keep(npc),
                             os.path.join(wd, f'w_{d}_{tag}_{k}.png'), seed_of(npc) + 700 + k])
    run_edits(jobs)


def stage_edit(npc, src, key, out, n=3):
    wd = work(npc)
    run_edits([[os.path.join(wd, src), WALK_STRONG.get(key, key) + ' ' + keep(npc), os.path.join(wd, f'{out}_{k}.png'), seed_of(npc) + 900 + k] for k in range(n)])


def picks(npc):
    return json.load(open(os.path.join(work(npc), 'picks.json')))


def stage_walk(npc, variants=2):
    wd = work(npc); P = picks(npc); jobs = []
    for d, p in P['dirs'].items():
        src = os.path.join(wd, p['idle'])
        for foot, other, tag in (('left', 'right', 'wl'), ('right', 'left', 'wr')):
            t = WALK_TXT[d if d in ('s', 'n') else 'side'].format(foot=foot, other=other)
            for k in range(variants):
                jobs.append([src, t + ' ' + keep(npc), os.path.join(wd, f'w_{d}_{tag}_{k}.png'), seed_of(npc) + 300 + k])
    run_edits(jobs)


def stage_sit(npc, variants=2):
    wd = work(npc); P = picks(npc); jobs = []
    for d, p in P['dirs'].items():
        for k in range(variants):
            jobs.append([os.path.join(wd, p['idle']), SIT_TXT + ' ' + keep(npc), os.path.join(wd, f's_{d}_{k}.png'), seed_of(npc) + 500 + k])
    run_edits(jobs)


def stage_rmbg(npc):
    wd = work(npc); P = picks(npc); files = set()
    for p in P['dirs'].values():
        files.update(v.lstrip('!') for v in p.values() if isinstance(v, str) and v)
    files.update(P.get('sit', {}).values())
    todo = [f for f in files if not os.path.exists(os.path.join(wd, 'rb_' + f))]
    def rb(src, out):
        import time
        for t in range(6):
            try: return _rmbg(src, out)
            except Exception as e:
                if '429' not in str(e) or t == 5: raise
                time.sleep(10 * (t + 1))
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '3'))) as ex:
        futs = {ex.submit(rb, os.path.join(wd, f), os.path.join(wd, 'rb_' + f)): f for f in todo}
        for f in cf.as_completed(futs):
            try: print('ok', os.path.basename(f.result()))
            except Exception as e: print('err', futs[f], str(e)[:200])


def stage_board(npc, pattern):
    from PIL import Image, ImageDraw
    wd = work(npc); fs = sorted(glob.glob(os.path.join(wd, pattern)))
    cols = min(8, len(fs)); rows = (len(fs) + cols - 1) // cols; S = 256
    b = Image.new('RGB', (cols * S, rows * (S + 16)), (240, 230, 200)); dr = ImageDraw.Draw(b)
    for i, f in enumerate(fs):
        im = Image.open(f).convert('RGBA'); bg = Image.new('RGBA', im.size, (240, 230, 200, 255)); bg.alpha_composite(im)
        b.paste(bg.convert('RGB').resize((S, S), Image.BOX), ((i % cols) * S, (i // cols) * (S + 16) + 16))
        dr.text(((i % cols) * S + 4, (i // cols) * (S + 16) + 2), os.path.basename(f), fill=(60, 30, 20))
    out = os.path.join(wd, 'board_' + pattern.replace('*', 'X').replace('.png', '').replace('/', '_') + '.png'); b.save(out); print(out)


if __name__ == '__main__':
    st, npc, *rest = sys.argv[1:]
    {'gen': lambda: stage_gen(npc), 'dirs': lambda: stage_dirs(npc, rest[0]), 'walk': lambda: stage_walk(npc),
     'sit': lambda: stage_sit(npc), 'rmbg': lambda: stage_rmbg(npc), 'board': lambda: stage_board(npc, rest[0]),
     'dirs2': lambda: stage_dirs2(npc, rest[0], rest[1:]), 'walk2': lambda: stage_walk2(npc, rest),
     'edit': lambda: stage_edit(npc, rest[0], rest[1], rest[2])}[st]()
