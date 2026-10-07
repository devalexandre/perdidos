"""Correcao de orientacao nas folhas prontas (Agente F, 28/09/2026). Deterministico, sem IA, idempotente.

    python fix_orientation.py [--dry] [male|female ...]

Roda DEPOIS de build.py / earrings.py / build_sheets.py / build_equipment.py / build_combat.py e ANTES de
eyes.py e cleanup_sheets.py. Trabalha so nas folhas de assets/ (as fontes da IA podem nao existir mais).

1. SE (linha 1): pela regra do DirectionalSprite3D.compute_sector, SE = frente + DIREITA da tela (como L, o sit e
   todo o combate). A imagem-chave aprovada do idle SE olha para a esquerda; os passos do andar, para a direita.
   Resultado antigo: no andar SE a cabeca virava a cada 2 quadros. Aqui, quando o idle SE olha para o lado
   oposto ao dos passos (teste pela silhueta/cor da parte de cima, direto x espelhado):
     - idle: a linha SE inteira e espelhada (espelho exato do quadro 96x96);
     - walk: as colunas "paradas" (2, 3, 6, 7 = copias do idle) sao espelhadas;
     - camadas cujos passos sao o idle deslocado pela cabeca (estilos de cabelo nao padrao e brincos): as colunas
       de passo (0, 1, 4, 5) sao refeitas = idle novo deslocado pela cabeca (head_offset do build.py);
     - head_anchors.json (combate): mirror_idle = false na linha SE (o idle ja olha para o lado do golpe).
   Familias (cada uma testada pela sua folha de corpo inteiro): corpo-base (base, mascara, cabelos, brincos),
   Viajante (chr_traveler_*), roupa (outfits + chapeus + armas, que saem do build_equipment com as mesmas fontes).
2. Feminino N (linha 4): o idle e os passos vinham de imagens-chave diferentes (o raspado dos passos mostrava rosto,
   o cabelo trocava de forma/lado). Os passos passam a usar a cabeca do IDLE (de costas), deslocada pela cabeca
   medida no Viajante - a mesma regra que o pipeline ja usa nas outras direcoes:
     - camadas so de cabeca (cabelos, brincos, chapeus): passo = idle deslocado;
     - camadas de corpo inteiro (base, mascara, Viajante, roupa): linhas da cabeca (acima do pescoco) = idle
       deslocado; o resto do passo fica; no Viajante e na roupa o cabelo padrao do passo (rabo de cavalo) sai e
       entra o do idle deslocado.
   Idempotente: pula se o cabelo padrao do passo ja e o do idle deslocado.
Depois: python eyes.py --report ; python ../cleanup_sheets.py (ver docs/ajustes-personagens.md).
"""
import json, os, sys
import numpy as np
from PIL import Image
from common import GAME, FR, translate
from build import head_offset
from edits import STYLES, DEFAULT_STYLE

CH = os.path.join(GAME, 'assets', 'characters')
EQ = os.path.join(GAME, 'assets', 'equipment')
HEAD_ANCHORS = os.path.join(GAME, 'tools', 'art', 'combat_anims', 'head_anchors.json')
SE, N = 1, 4
STAND = (2, 3, 6, 7)           # colunas do walk que sao o idle (bob / parado)
STEPS = ((0, 1, 0), (4, 5, 4))  # (coluna, coluna, coluna de referencia) wl e wr
FACES = ['hoop', 'seed', 'feather']
HEADS = ['straw_hat', 'ipe_flower_crown']
WEAPONS = ['blade', 'staff']
DRY = False
LOG = []


def load(p): return np.asarray(Image.open(p).convert('RGBA')).copy()


def save(a, p):
    if not DRY: Image.fromarray(a, 'RGBA').save(p)
    LOG.append(p)


def fr(a, r, c): return a[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR]


def put(a, r, c, f): a[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR] = f


def tr(f, off): return np.asarray(translate(Image.fromarray(np.ascontiguousarray(f)), off[0], off[1]))


def top_part(f, frac=0.4):
    ys = np.nonzero(f[..., 3].any(1))[0]
    o = f.copy()
    if len(ys): o[ys.min() + int((ys.max() - ys.min()) * frac):] = 0
    return o


def match(a, b, rng=8):
    """Melhor concordancia (pixels opacos nos dois com cor parecida - alfa diferente) entre a e b deslocado."""
    A = a.astype(int); best = -1e9
    for dy in range(-rng, rng + 1):
        for dx in range(-rng, rng + 1):
            B = shift_np(b, dx, dy).astype(int)
            oa, ob = A[..., 3] > 0, B[..., 3] > 0
            ok = oa & ob & (np.abs(A[..., :3] - B[..., :3]).sum(-1) < 90)
            best = max(best, ok.sum() * 2 - (oa ^ ob).sum())
    return best


def shift_np(a, dx, dy):
    o = np.zeros_like(a); h, w = a.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    o[yd, xd] = a[ys, xs]; return o


def idle_faces_away(idle_sheet, walk_sheet, r=SE):
    """True se o idle da linha r olha para o lado OPOSTO ao dos passos (espelhado combina melhor)."""
    i = top_part(fr(idle_sheet, r, 0)); d = m = 0
    for c in (0, 4):
        s = top_part(fr(walk_sheet, r, c)); d += match(i, s); m += match(i[:, ::-1], s)
    return m > d * 1.1, d, m


# ------------------------------------------------------------------------------------------------ SE

def flip_se_idle_walk(idle_p, walk_p, derived=False, base_idle=None, base_walk=None):
    I, W = load(idle_p), load(walk_p)
    for c in range(I.shape[1] // FR):
        put(I, SE, c, fr(I, SE, c)[:, ::-1])
    for c in STAND:
        put(W, SE, c, fr(W, SE, c)[:, ::-1])
    if not np.array_equal(fr(W, SE, 3), fr(I, SE, 0)):
        print('  AVISO: walk c3 != idle c0 em', os.path.basename(walk_p))
    if derived:
        i0 = fr(I, SE, 0)
        for c1, c2, cref in STEPS:
            off = head_offset(Image.fromarray(fr(base_idle, SE, 0)), Image.fromarray(fr(base_walk, SE, cref)))
            f = tr(i0, off); put(W, SE, c1, f); put(W, SE, c2, f)
    save(I, idle_p); save(W, walk_p)


def check_derived(idle_p, walk_p, base_idle, base_walk, r):
    """Confere que os passos da camada sao o idle deslocado pela cabeca (regra do build.py)."""
    I, W = load(idle_p), load(walk_p); bad = 0
    for c1, c2, cref in STEPS:
        off = head_offset(Image.fromarray(fr(base_idle, r, 0)), Image.fromarray(fr(base_walk, r, cref)))
        bad += int((tr(fr(I, r, 0), off) != fr(W, r, c1)).any(-1).sum())
    return bad


def fix_se(body):
    print('== SE', body)
    bi_p, bw_p = f'{CH}/base/chr_{body}_base_idle.png', f'{CH}/base/chr_{body}_base_walk.png'
    BI, BW = load(bi_p), load(bw_p)
    away, d, m = idle_faces_away(BI, BW)
    print(f'  corpo-base: direto {d} x espelhado {m} ->', 'ESPELHAR' if away else 'ok')
    if away:
        default = DEFAULT_STYLE[body]
        for st in STYLES[body]:
            if st == 'buzz' or st == default: continue
            p = f'{CH}/hair/{st}/{body}'
            print('   ', st, 'passos = idle deslocado? diferenca', check_derived(p + '_idle.png', p + '_walk.png', BI, BW, SE), 'px')
        for fa in FACES:
            p = f'{CH}/face/{fa}/{body}'
            print('   ', fa, 'passos = idle deslocado? diferenca', check_derived(p + '_idle.png', p + '_walk.png', BI, BW, SE), 'px')
        flip_se_idle_walk(bi_p, bw_p)
        flip_se_idle_walk(f'{CH}/base/chr_{body}_base_mask_idle.png', f'{CH}/base/chr_{body}_base_mask_walk.png')
        BI2 = load(bi_p) if not DRY else None
        if DRY:  # simula o corpo-base espelhado para os deslocamentos
            BI2 = BI.copy()
            for c in range(BI2.shape[1] // FR): put(BI2, SE, c, fr(BI, SE, c)[:, ::-1])
        for st in STYLES[body]:
            if st == 'buzz': continue
            p = f'{CH}/hair/{st}/{body}'
            flip_se_idle_walk(p + '_idle.png', p + '_walk.png', derived=st != DEFAULT_STYLE[body], base_idle=BI2, base_walk=BW)
        for fa in FACES:
            p = f'{CH}/face/{fa}/{body}'
            flip_se_idle_walk(p + '_idle.png', p + '_walk.png', derived=True, base_idle=BI2, base_walk=BW)
    # Viajante
    ti, tw = f'{CH}/chr_traveler_{body}_idle.png', f'{CH}/chr_traveler_{body}_walk.png'
    away, d, m = idle_faces_away(load(ti), load(tw))
    print(f'  Viajante: direto {d} x espelhado {m} ->', 'ESPELHAR' if away else 'ok')
    if away: flip_se_idle_walk(ti, tw)
    # roupa (+ chapeus e armas: mesmas fontes do build_equipment)
    oi, ow = f'{CH}/outfits/chr_{body}_leather_jerkin_idle.png', f'{CH}/outfits/chr_{body}_leather_jerkin_walk.png'
    away, d, m = idle_faces_away(load(oi), load(ow))
    print(f'  roupa/chapeus/armas: direto {d} x espelhado {m} ->', 'ESPELHAR' if away else 'ok')
    if away:
        flip_se_idle_walk(oi, ow)
        for h in HEADS: flip_se_idle_walk(f'{EQ}/head/{h}/{body}_idle.png', f'{EQ}/head/{h}/{body}_walk.png')
        for w in WEAPONS: flip_se_idle_walk(f'{EQ}/weapon/{w}/{body}_idle.png', f'{EQ}/weapon/{w}/{body}_walk.png')
    # combate: o idle SE agora olha para o lado do golpe
    A = json.load(open(HEAD_ANCHORS)); n = 0
    for anim, rows in A.get(body, {}).items():
        for q in rows[SE]:
            if q and q.get('mirror_idle'): q['mirror_idle'] = False; n += 1
    if n and not DRY:
        A['_doc'] = A['_doc'].split(' Linha SE:')[0] + (' Linha SE: mirror_idle = false desde o Agente F (28/09): o idle SE foi '
                                                        'espelhado (fix_orientation.py) e olha para a direita, como o golpe.')
        json.dump(A, open(HEAD_ANCHORS, 'w'), indent=0)
    print('  head_anchors SE mirror_idle -> false:', n)


# ------------------------------------------------------------------------------------------------ feminino N

def neck_row(base_idle_f):
    """Linha do pescoco no idle (fim da cabeca): topo + 30% da altura do corpo."""
    ys = np.nonzero(base_idle_f[..., 3].any(1))[0]; return ys.min() + int((ys.max() - ys.min()) * 0.30)


def fix_female_n():
    body = 'female'; print('== N', body)
    ti, tw = load(f'{CH}/chr_traveler_{body}_idle.png'), load(f'{CH}/chr_traveler_{body}_walk.png')
    offs = {c: head_offset(Image.fromarray(fr(ti, N, 0)), Image.fromarray(fr(tw, N, c))) for c in (0, 4)}
    print('  deslocamento da cabeca idle -> passo (Viajante):', offs)
    hp = f'{CH}/hair/{DEFAULT_STYLE[body]}/{body}'
    HI, HW = load(hp + '_idle.png'), load(hp + '_walk.png')
    done = all(np.array_equal(tr(fr(HI, N, 0), offs[c]), fr(HW, N, c)) for c in (0, 4))
    if done: print('  ja feito (cabelo padrao dos passos = idle deslocado)'); return
    bi = load(f'{CH}/base/chr_{body}_base_idle.png'); cut = neck_row(fr(bi, N, 0))
    hair_i = fr(HI, N, 0)[..., 3] > 0
    def head_only(idle_p, walk_p):
        I, W = load(idle_p), load(walk_p)
        for c1, c2, cref in STEPS:
            f = tr(fr(I, N, 0), offs[cref]); put(W, N, c1, f); put(W, N, c2, f)
        save(W, walk_p)
    def full_body(idle_p, walk_p, hair=False):
        I, W = load(idle_p), load(walk_p); i0 = fr(I, N, 0)
        for c1, c2, cref in STEPS:
            off = offs[cref]; s = fr(W, N, cref).copy(); moved = tr(i0, off)
            y = cut + off[1]
            if hair:  # tira o rabo de cavalo do passo (abaixo do pescoco) e poe o do idle deslocado
                hs = fr(HW, N, cref)[..., 3] > 0
                bs = fr(BW0, N, cref)
                s[hs] = bs[hs]
                hm = tr(np.where(hair_i[..., None], i0, 0).astype(np.uint8), off)
                s[:y] = moved[:y]
                m = hm[..., 3] > 0; s[m] = hm[m]
            else:
                s[:y] = moved[:y]
            put(W, N, c1, s); put(W, N, c2, s)
        save(W, walk_p)
    global BW0
    BW0 = load(f'{CH}/base/chr_{body}_base_walk.png')  # passo do corpo-base ANTES da troca (corpo sem cabelo)
    full_body(f'{CH}/chr_traveler_{body}_idle.png', f'{CH}/chr_traveler_{body}_walk.png', hair=True)
    full_body(f'{CH}/outfits/chr_{body}_leather_jerkin_idle.png', f'{CH}/outfits/chr_{body}_leather_jerkin_walk.png', hair=True)
    full_body(f'{CH}/base/chr_{body}_base_idle.png', f'{CH}/base/chr_{body}_base_walk.png')
    full_body(f'{CH}/base/chr_{body}_base_mask_idle.png', f'{CH}/base/chr_{body}_base_mask_walk.png')
    for st in STYLES[body]:
        if st != 'buzz': head_only(f'{CH}/hair/{st}/{body}_idle.png', f'{CH}/hair/{st}/{body}_walk.png')
    for fa in FACES: head_only(f'{CH}/face/{fa}/{body}_idle.png', f'{CH}/face/{fa}/{body}_walk.png')
    for h in HEADS: head_only(f'{EQ}/head/{h}/{body}_idle.png', f'{EQ}/head/{h}/{body}_walk.png')
    print('  passos N refeitos com a cabeca do idle; pescoco na linha', cut)


if __name__ == '__main__':
    DRY = '--dry' in sys.argv
    bodies = [a for a in sys.argv[1:] if not a.startswith('--')] or ['male', 'female']
    for b in bodies: fix_se(b)
    if 'female' in bodies: fix_female_n()
    print(('(dry) ' if DRY else '') + f'{len(set(LOG))} folhas')
