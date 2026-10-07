"""Animacoes de combate do Viajante (GDD §10.2.1, §17.3): poses-chave geradas por edicao IA (Bria).

Fonte de cada direcao = a imagem-chave APROVADA do idle, na versao "raspada" (edicao buzz do pipeline de
personalizacao: cabeca com cabelo curtinho VERDE). O verde serve de ancora da cabeca (cabelo/brinco/chapeu
seguem a cabeca quadro a quadro) e de mascara do raspado. Armas sao pedidas MAGENTA (nada no Viajante e
magenta) e saem por cor para a camada da arma, recolorida depois com a paleta da arma aprovada.

    export BK=...                 (chave Bria; nunca imprimir)
    python keys.py edits [body ...]      edicoes das poses-chave (+ remocao de fundo); pula o que ja existe
    python keys.py jerkin [body ...]     roupa leather_jerkin sobre cada pose-chave (+ remocao de fundo)
    python keys.py redo                  refaz o que estiver em redo.json ({"<body>/<dir>/<key>": seed})

Trabalho: $COMBAT_WORK/<body>/<dir>/<key>.png (+ rb_*, jerkin/).
"""
import json, os, sys, shutil, time, concurrent.futures as cf
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'customization'))
sys.path.insert(0, os.path.join(HERE, '..', 'character_pipeline'))
from common import SCRATCH, TRAVELER_WORK, CUSTOM_WORK, DIRS  # noqa: E402

COMBAT_WORK = os.environ.get('COMBAT_WORK', os.path.join(SCRATCH, 'a', 'work'))
BODIES = ['male', 'female']
SEED = 4242

KEEP = (" Keep exactly the same character: the same face, the same very short bright green hair, the same outfit, "
        "backpack, gloves, trousers and sneakers, the same proportions and the same size in the image, the same "
        "head size, the same pixel art style with a dark 1-pixel outline, and a plain white background. "
        "Single character, full body, nothing else in the image.")
MACHETE = (" The machete is entirely bright magenta pink, blade and handle, one flat solid magenta color with no "
           "other colors on it.")
STAFF = (" The staff is entirely bright magenta pink from end to end, one flat solid magenta color, plain straight "
         "pole with no crystal and no decorations.")
# Para onde o golpe vai em cada linha da folha (a vista do personagem nao muda).
TOWARD = {
    's': "straight toward the viewer (front view: the character faces the viewer)",
    'se': "toward the lower right of the image (three-quarter front view: the character faces the lower right)",
    'e': "to the right of the image (side view: the character faces right)",
    'ne': ("toward the upper right of the image, away from the viewer (three-quarter back view: the character "
           "faces the upper right, we mostly see the back and the backpack)"),
    'n': ("straight away from the viewer (back view: the character faces away from us, we see the back of the "
          "head and the backpack, the face is NOT visible)"),
}
# Poses-chave: key -> (texto, extra). {t} = TOWARD da linha.
KEYS = {
    'u_wind': ("The character takes a fighting stance facing {t}: pulls one fist back beside the chest to "
               "prepare a punch, the other fist raised in guard, knees bent, weight on the back leg.", ''),
    'u_punch': ("The character throws a strong straight punch {t} with one fist, that arm fully extended, the "
                "other fist guarding near the chest, legs in a wide forward lunge stance.", ''),
    'u_kick': ("The character does a front kick {t}, one leg raised and extended forward at hip height, the "
               "other leg standing, arms up in guard.", ''),
    'b_wind': ("The character, facing {t}, raises a short machete high above and behind the shoulder with the "
               "right hand, ready to strike, body twisted back.", MACHETE),
    'b_slash': ("The character slashes a short machete downward and forward {t}, the sword arm fully extended "
                "forward at chest height, in a forward lunge stance.", MACHETE),
    'b_follow': ("The character, facing {t}, has just finished a slash with a short machete: the blade is held "
                 "low and across the body near the opposite hip, the arm crossed in front, lunge stance, body "
                 "leaning forward.", MACHETE),
    's_wind': ("The character, facing {t}, holds a long straight staff with both hands, pulled back beside the "
               "hip ready to thrust, knees bent.", STAFF),
    's_thrust': ("The character thrusts a long straight staff forward {t} with both hands like a spear, arms "
                 "extended, forward lunge stance.", STAFF),
    'c_gather': ("The character, facing {t}, prepares a magic spell: both hands brought together in front of "
                 "the chest, palms cupped facing each other, feet firmly apart, focused.", ''),
    'c_release': ("The character casts a magic spell {t}: both arms stretched straight forward, palms open "
                  "facing forward, fingers spread, feet firmly apart.", ''),
    'd_stagger': ("The character, facing {t}, staggers backward hurt, body bent, one hand holding the "
                  "stomach, knees weak, about to fall.", ''),
    'd_kneel': ("The character, facing {t}, falls to the knees: kneeling on both knees on the ground, body "
                "upright but slumped, arms hanging down, exhausted.", ''),
    'd_slump': ("The character, facing {t}, has collapsed: kneeling on the ground, sitting back on the heels, "
                "torso slumped forward with both hands resting on the ground in front of the knees, defeated; "
                "the head stays upright and level, at the same angle as in the original image, eyes half closed.", ''),
}
JERKIN = ("Replace the blue hoodie with a brown leather jerkin: a sleeveless laced leather doublet with stitched "
          "seams and a belt, worn over a cream linen long-sleeved shirt. Keep the backpack, legs, trousers and "
          "sneakers. Keep exactly the same pose, the same position and size in the image, the same very short "
          "bright green hair, the same face, pixel art style and plain white background. If the character holds "
          "a magenta weapon, keep it exactly the same, same magenta color.")


def picks(body):
    return json.load(open(os.path.join(TRAVELER_WORK, f'traveler_{body}', 'picks.json')))['dirs']


def src_flip(body, d):
    """(fonte buzz, espelhar a fonte?, camadas do idle espelhadas?). A imagem-chave SE aprovada olha para a
    esquerda; o golpe usa a fonte espelhada (olha para baixo-direita, regra do DirectionalSprite3D). Desde o
    Agente F (27/09) o picks.json espelha tambem o idle SE (flip_each.idle = true), entao as folhas idle ja olham
    para a direita e as camadas do idle NAO sao espelhadas (mirror_idle = false). Se o idle voltar a nao ser
    espelhado no picks, o golpe continua certo e mirror_idle volta a true."""
    p = picks(body)[d]; fl = p.get('flip_each', {}).get('idle', False)
    mirror = d == 'se' and not fl
    if d == 'se': return p['idle'], True, mirror
    return p['idle'], fl != mirror, mirror


def wdir(body, d):
    p = os.path.join(COMBAT_WORK, body, d); os.makedirs(p, exist_ok=True); return p


# Corpos cuja edicao "raspado" inteira nao e fiel a imagem aprovada (feminino: a IA trocou a legging por
# pernas nuas / manchas verdes) -> a fonte e a imagem APROVADA com so a regiao do cabelo trocada pelo raspado
# (mesma regra do corpo-base em customization/build.py, na resolucao da IA).
FAITHFUL = {'female'}


def faithful(body, src):
    """Imagem aprovada (RGBA) com o cabelo trocado pelo raspado verde (alinhado pela cabeca/tronco)."""
    from scipy.ndimage import binary_dilation, label
    from common import prep, params, align_color, shift, H_IDLE
    import build as cb
    from edits import DEFAULT_STYLE
    O = prep(os.path.join(TRAVELER_WORK, f'traveler_{body}', 'rb_' + src), False); pr = params(O, H_IDLE)
    def aligned(variant):
        e = prep(os.path.join(CUSTOM_WORK, body, variant, 'rb_' + src), False)
        dx, dy = align_color(O, e, pr); return shift(e, dx, dy)
    G = aligned(DEFAULT_STYLE[body]); Z = aligned('buzz')
    mh = cb.hair_mask(Image.fromarray(G), 0.9, ref=Image.fromarray(O)) & (O[..., 3] > 0)
    ms = cb.hair_mask(Image.fromarray(Z), 0.3, ref=Image.fromarray(O))
    top, bot = cb.body_bounds(O); ms[top + int((bot - top) * 0.35):] = False
    R = binary_dilation(mh, np.ones((3, 3), bool), iterations=12) | ms
    # fios soltos que a edicao "recolorir" nao pintou: cor de cabelo na original, diferente no raspado,
    # na metade de cima e colados na regiao do cabelo
    hr = np.array(json.load(open(os.path.join(CUSTOM_WORK, body, 'measured.json')))['hair'], np.int32)
    oc = O[..., :3].astype(np.int32)
    hairish = (np.sqrt(((oc[:, :, None, :] - hr[None, None]) ** 2).sum(-1)).min(-1) < 38) & (O[..., 3] > 0)
    diff = np.abs(oc - Z[..., :3].astype(np.int32)).sum(-1) > 90
    cand = hairish & (diff | (Z[..., 3] == 0)); cand[top + int((bot - top) * 0.5):] = False
    lab, n = label(cand | R)
    keep = np.zeros(n + 1, bool); keep[np.unique(lab[R])] = True; keep[0] = False
    R |= binary_dilation(cand & keep[lab], np.ones((3, 3), bool), iterations=6) & (keep[lab] | ~(O[..., 3] > 0))
    o = O.copy(); o[R] = Z[R]; o[..., 3] = np.where(o[..., 3] > 0, 255, 0)
    lab, n = label(o[..., 3] > 0)
    if n > 1:
        sz = np.bincount(lab.ravel()); keep = sz >= sz[1:].max() * 0.01; keep[0] = False; o[~keep[lab]] = 0
    return o


def source_image(body, d):
    """Fonte raspada (fundo branco, para a IA) e a mesma com alfa (rb__src.png), ja orientadas."""
    src, fl, _ = src_flip(body, d)
    out = os.path.join(wdir(body, d), '_src.png'); rb = os.path.join(wdir(body, d), 'rb__src.png')
    if os.path.exists(out) and os.path.exists(rb): return out
    if body in FAITHFUL:
        a = Image.fromarray(faithful(body, src), 'RGBA')
        w = Image.new('RGBA', a.size, (255, 255, 255, 255)); w.alpha_composite(a); im = w.convert('RGB')
    else:
        im = Image.open(os.path.join(CUSTOM_WORK, body, 'buzz', src)).convert('RGB')
        a = Image.open(os.path.join(CUSTOM_WORK, body, 'buzz', 'rb_' + src)).convert('RGBA')
    (im.transpose(Image.FLIP_LEFT_RIGHT) if fl else im).save(out)
    (a.transpose(Image.FLIP_LEFT_RIGHT) if fl else a).save(rb)
    return out


def prompt(key, d):
    t, extra = KEYS[key]; return t.format(t=TOWARD[d]) + extra + KEEP


def _retry(fn, *a):
    for t in range(8):
        try: return fn(*a)
        except Exception as e:
            if t == 7: raise
            time.sleep(8 * (t + 1))


def run(jobs):
    from edit import edit
    from rmbg import rmbg
    todo = [j for j in jobs if not os.path.exists(j[2])]
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '6'))) as ex:
        for f in cf.as_completed([ex.submit(_retry, edit, *j) for j in todo]):
            try: f.result()
            except Exception as e: print('edit err', str(e)[:160])
    rb = [(j[2], os.path.join(os.path.dirname(j[2]), 'rb_' + os.path.basename(j[2]))) for j in jobs]
    rb = [r for r in rb if os.path.exists(r[0]) and not os.path.exists(r[1])]
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '6'))) as ex:
        for f in cf.as_completed([ex.submit(_retry, rmbg, *r) for r in rb]):
            try: f.result()
            except Exception as e: print('rmbg err', str(e)[:160])
    print('done', len(jobs), 'jobs,', len(todo), 'edits,', len(rb), 'rmbg')


def edit_jobs(bodies):
    out = []
    for b in bodies:
        for d in DIRS:
            s = source_image(b, d)
            for k in KEYS: out.append([s, prompt(k, d), os.path.join(wdir(b, d), k + '.png'), SEED])
    return out


def jerkin_jobs(bodies):
    out = []
    for b in bodies:
        for d in DIRS:
            jd = os.path.join(wdir(b, d), 'jerkin'); os.makedirs(jd, exist_ok=True)
            for k in KEYS:
                s = os.path.join(wdir(b, d), k + '.png')
                if os.path.exists(s): out.append([s, JERKIN, os.path.join(jd, k + '.png'), SEED])
    return out


REDO_PATH = os.path.join(HERE, 'redo.json')


def redo_jobs():
    """redo.json: {"<body>/<dir>/<key>": {"seed": n, "extra": "..."}} -> refaz (a anterior vai para rejected/).
    "<body>/<dir>/jerkin/<key>" refaz so a roupa."""
    R = json.load(open(REDO_PATH)) if os.path.exists(REDO_PATH) else {}; out = []
    for key, r in R.items():
        parts = key.split('/'); body, d, k = parts[0], parts[1], parts[-1]; jer = len(parts) == 4
        wd = os.path.join(wdir(body, d), 'jerkin') if jer else wdir(body, d)
        mark = os.path.join(wd, '.seed_' + k)
        if os.path.exists(mark) and open(mark).read() == str(r['seed']): continue
        os.makedirs(os.path.join(wd, 'rejected'), exist_ok=True)
        for f in (k + '.png', 'rb_' + k + '.png'):
            if os.path.exists(os.path.join(wd, f)):
                shutil.move(os.path.join(wd, f), os.path.join(wd, 'rejected', f'{r["seed"]}_{f}'))
        open(mark, 'w').write(str(r['seed']))
        if jer:
            out.append([os.path.join(wdir(body, d), k + '.png'), JERKIN + r.get('extra', ''), os.path.join(wd, k + '.png'), r['seed']])
        else:
            src = source_image(body, d)
            out.append([src, prompt(k, d).replace(KEEP, r.get('extra', '') + KEEP), os.path.join(wd, k + '.png'), r['seed']])
            # a roupa da pose refeita tambem precisa ser refeita
            jd = os.path.join(wdir(body, d), 'jerkin')
            for f in (k + '.png', 'rb_' + k + '.png'):
                if os.path.exists(os.path.join(jd, f)): os.remove(os.path.join(jd, f))
    return out


if __name__ == '__main__':
    cmd = sys.argv[1]; bodies = sys.argv[2:] or BODIES
    if cmd == 'edits': run(edit_jobs(bodies))
    elif cmd == 'jerkin': run(jerkin_jobs(bodies))
    elif cmd == 'redo':
        j = redo_jobs(); run(j)
