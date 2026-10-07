"""Etapa 1 (IA, reexecutavel; pula o que ja existe): edicoes Bria das imagens-chave do Viajante + remocao de fundo.

    export BK=...   (chave Bria; nunca imprimir)
    python edits.py <body|all> [variante ...]
    python edits.py redo            (refaz as fontes listadas em redo.json, com outra semente)

Variantes (STYLES): 'buzz' = cabelo raspado e o estilo padrao (so recolorido) usam TODAS as 20 fontes (5 idle,
10 passos, 5 sentado);
cada estilo de cabelo = so as fontes idle + sit (nos passos o cabelo do idle acompanha a cabeca, ver build.py:
fica sem "piscar" entre quadros). O cabelo e sempre pedido em VERDE VIVO: nada no Viajante e verde, entao o
cabelo sai por cor (e depois vira rampa de cinza recolorida pelo shader).
"""
import json, os, sys, time, concurrent.futures as cf
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'character_pipeline'))
from common import frames, src_dir, work

KEEP = (" Keep everything else exactly the same: the same character, face, eyes, eyebrows, outfit, backpack, the same pose, "
        "the same body position and size in the image, the same camera angle, colors, pixel art style with a colored "
        "1-pixel outline, and plain white background. Single character, full body.")
GREEN = " The hair is colored vivid bright green with darker green shading and a dark green outline."
SIT = " The character stays sitting on the ground with legs crossed."
STYLES = {
    'male': {
        'buzz': "Shave the character's head: replace the hair with a very short even buzzcut tight to the scalp, showing the round head shape and the ears.",
        'spiky': "Recolor only the hair, keeping exactly the same messy spiky hairstyle, the same hair shape, size and shading.",
        'neat': "Replace the hairstyle with short neat hair: short on the sides, a bit longer on top, combed to one side with a soft side part.",
        'ponytail': "Replace the hairstyle with long straight hair tied back in a low ponytail at the nape of the neck, a few loose strands framing the face.",
        'curly': "Replace the hairstyle with a voluminous rounded afro of tight coily curls, textured with small curl clusters.",
    },
    'female': {
        'buzz': "Shave the character's head: replace the hair with a very short even buzzcut tight to the scalp, showing the round head shape and the ears.",
        'ponytail': "Recolor only the hair, keeping exactly the same long high ponytail hairstyle, the same hair shape, size and shading.",
        'bob': "Replace the hairstyle with a chin-length bob cut with straight bangs across the forehead.",
        'waves': "Replace the hairstyle with long loose wavy hair flowing down past the shoulders to the middle of the back.",
        'braid': "Replace the hairstyle with hair pulled back into a single long thick braid hanging down the back to the waist.",
    },
}
SEED = 4242
BACK = (" The character is seen from BEHIND (back view): we see the back of the head and the backpack, "
        "the face is NOT visible.")
# Estilo atual do Viajante: a edicao so RECOLORE o cabelo (verde) -> mascara exata do cabelo original em todos
# os quadros (usada para montar o corpo-base e para o cabelo padrao, que usa os pixels ORIGINAIS).
DEFAULT_STYLE = {'male': 'spiky', 'female': 'ponytail'}
# Direcoes em que a cabeca do idle aprovado esta num angulo diferente da dos passos (feminino N: idle de
# perfil/3-4, passos de costas) -> o cabelo dos passos nao pode ser o do idle deslocado: edita cada passo.
# (Agente F, 28/09: as folhas do jogo ja tem o idle N feminino de costas, montado a partir da cabeca dos passos por
# tools/art/customization/fix_orientation.py; rodar esse script de novo depois de refazer as folhas por aqui.)
PER_FRAME_WALK = {'male': [], 'female': ['n']}


def jobs_for(body, variant):
    out = []; seen = set()
    for an, d, t, src, fl, H in frames(body):
        if variant not in ('buzz', DEFAULT_STYLE[body]) and an == 'walk' and d not in PER_FRAME_WALK[body]: continue
        if src in seen: continue
        seen.add(src)
        txt = STYLES[body][variant] + GREEN + (SIT if an == 'sit' else '') + (BACK if an == 'walk' and d == 'n' else '') + KEEP
        out.append([os.path.join(src_dir(body), src), txt, os.path.join(work(body, variant), src), SEED])
    return out


def _retry(fn, *a):
    for t in range(8):
        try: return fn(*a)
        except Exception as e:
            if t == 7 or not any(k in str(e) for k in ('429', 'timed out', '50', 'Remote')): raise
            time.sleep(8 * (t + 1))


def run(jobs):
    from edit import edit      # (importa a chave BK so quando vai chamar a IA)
    from rmbg import rmbg
    todo = [j for j in jobs if not os.path.exists(j[2])]
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '4'))) as ex:
        for f in cf.as_completed([ex.submit(_retry, edit, *j) for j in todo]):
            try: f.result()
            except Exception as e: print('edit err', str(e)[:160])
    rb = [(j[2], os.path.join(os.path.dirname(j[2]), 'rb_' + os.path.basename(j[2]))) for j in jobs]
    rb = [r for r in rb if os.path.exists(r[0]) and not os.path.exists(r[1])]
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '4'))) as ex:
        for f in cf.as_completed([ex.submit(_retry, rmbg, *r) for r in rb]):
            try: f.result()
            except Exception as e: print('rmbg err', str(e)[:160])
    print('done', len(jobs), 'jobs,', len(todo), 'new edits,', len(rb), 'new rmbg')


REDO = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'redo.json'))) \
    if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'redo.json')) else {}


def redo_jobs():
    """Refacoes escolhidas olhando (redo.json: {"<body>/<variante>/<fonte>": {"seed": n, "back": bool, "extra": ""}}).
    A edicao anterior vai para <variante>/rejected/ e a nova usa outra semente (+ reforco de costas)."""
    import shutil
    out = []
    for key, r in REDO.items():
        body, variant, src = key.split('/'); wd = work(body, variant)
        an = next(a for a, d, t, s, fl, H in frames(body) if s == src)
        txt = STYLES[body][variant] + GREEN + (SIT if an == 'sit' else '') + (BACK if r.get('back') else '') + r.get('extra', '') + KEEP
        mark = os.path.join(wd, '.seed_' + src)
        if os.path.exists(mark) and open(mark).read() == str(r['seed']): continue
        os.makedirs(os.path.join(wd, 'rejected'), exist_ok=True)
        for f in (src, 'rb_' + src):
            if os.path.exists(os.path.join(wd, f)): shutil.move(os.path.join(wd, f), os.path.join(wd, 'rejected', f))
        open(mark, 'w').write(str(r['seed']))
        out.append([os.path.join(src_dir(body), src), txt, os.path.join(wd, src), r['seed']])
    return out


if __name__ == '__main__':
    if sys.argv[1] == 'redo':
        run(redo_jobs()); sys.exit(0)
    bodies = ['male', 'female'] if sys.argv[1] == 'all' else [sys.argv[1]]
    js = []
    for b in bodies:
        for v in (sys.argv[2:] or list(STYLES[b])): js += jobs_for(b, v)
    run(js)
