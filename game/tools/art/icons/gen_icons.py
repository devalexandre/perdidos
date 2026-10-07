"""Icones de item (32x32) e enfeites de cenario (sprites) no estilo da Ancora 5 (GDD 17.0.3).
Pipeline: Bria texto->imagem (4 variacoes, um objeto por imagem) -> recorte do fundo -> reducao BOX ->
quantizacao em Lab para a PALETA MESTRA -> contorno colorido de 1 px (tom escuro da propria cor) -> limpeza.
  gen_icons.py gen [ids...]      gera as variacoes em $ICON_WORK (padrao ./work)
  gen_icons.py board             prancha de candidatos (para escolher olhando)
  gen_icons.py final             grava os escolhidos (picks.json na pasta de trabalho; padrao variacao 0)
Chave: variavel BK (nunca imprimir)."""
import json, os, sys, time, concurrent.futures as cf
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label, binary_erosion
HERE = os.path.dirname(os.path.abspath(__file__)); GAME = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(HERE, '..', 'anchor_pipeline')); sys.path.insert(0, os.path.join(HERE, '..', 'character_pipeline'))  # gen.py do personagem vence
WORK = os.environ.get('ICON_WORK', os.path.join(HERE, 'work'))
STYLE_ICON = ("pixel art game item icon, {d}, single object centered with empty space around it, bold readable silhouette, "
              "crisp hand-placed pixels, 1px dark colored outline (not pure black), soft multi-tone cel shading with warm "
              "highlights, light from top-left, soft bright slightly pastel colors, cozy medieval fantasy, plain white background, "
              "no text, no watermark, no shadow")
STYLE_PROP = ("pixel art game prop sprite, {d}, seen from a 3/4 top-down game camera, single object centered, bold readable "
              "silhouette, crisp hand-placed pixels, 1px dark warm outline, rich warm cel shading, light from top-left, "
              "soft bright colors, cozy medieval fantasy town, plain white background, no text, no ground, no shadow")
ICONS = {
    'potion_hp_small': "a small round glass potion bottle filled with red liquid, with a cork stopper",
    'potion_hp_medium': "a tall glass potion bottle filled with red liquid, with a cork stopper and a twine tied around the neck",
    'potion_mp_small': "a small round glass potion bottle filled with glowing blue liquid, with a cork stopper",
    'potion_mp_medium': "a tall glass potion bottle filled with glowing blue liquid, with a cork stopper and a twine tied around the neck",
    'machete': "a short machete with a broad slightly curved steel blade and a wooden handle, placed diagonally",
    'short_sword': "a short iron sword with a simple crossguard and a leather-wrapped grip, placed diagonally",
    'wooden_staff': "a wooden staff with a small blue crystal at the top, placed diagonally",
    'ipe_wand': "a slim wooden wand made from a twig with a small bright yellow flower at the tip, placed diagonally",
    'leather_shield': "a round leather shield on a wooden rim with small iron studs, front view",
    'simple_tome': "a closed book with a brown leather cover, a simple golden corner trim and a red cloth bookmark",
    'straw_hat': "a woven straw hat with a red band and a small pink flower",
    'leather_jerkin': "a brown sleeveless leather jerkin vest with front laces and stitched seams, front view",
    'walking_boots': "a pair of soft brown leather walking boots",
    'seed_necklace': "a necklace of round red and black seeds strung on a cord",
    'ribbon_bracelet': "a bracelet of colorful woven ribbons, red yellow and green, tied with small knots",
    'spinning_leaf': "a single dry orange-brown leaf spinning inside a small swirl of wind with curved motion lines",
    'ipe_flower_crown': "a small round wreath crown woven from bright yellow flowers and green leaves",
    # Campo de Treino (agente W): drops novos
    'firefly_light': "a small glowing drop of warm yellow light floating inside a tiny glass bead, with soft sparkles",
    'armadillo_shell': "a reddish smooth stone armadillo shell plate with a small patch of green moss",
    'red_cap': "a tiny red knitted pointed cap with a small tassel",
    'thick_leather': "a folded piece of thick brown tanned leather tied with a cord",
    # arco (agente das roupas de titulo): item simple_bow
    'simple_bow': "a simple short hunting bow made of light yellow bamboo cane with a brown leather grip wrap and a taut thin string, placed diagonally",
}
FIELD = {  # Campo de Treino (agente W): vegetacao em sprite -> assets/environment/field/ (id: descricao, altura px)
    'fld_golden_grass': ("a tuft of tall golden dry savanna grass with thin seed stalks", 34),
    'fld_cerrado_shrub': ("a small twisted savanna shrub with a gnarled dark trunk and round olive green leaves", 64),
    'fld_cerrado_flowers': ("a small clump of wild savanna flowers, purple and white blossoms on thin stems with grass", 26),
    'fld_grass_tuft': ("a small tuft of bright green grass", 22),
    'fld_white_flowers': ("a small clump of tiny white and yellow daisies with green leaves", 22),
    'fld_round_bush': ("a small round leafy green bush", 40),
    'fld_reeds': ("a clump of tall green river reeds and cattails", 56),
    'fld_snow_shrub': ("a small dark green shrub dusted with white snow", 36),
    'fld_dry_bush': ("a small dry desert bush with thin brown twigs and a few grey-green leaves", 34),
    'fld_fern': ("a lush green jungle fern plant", 44),
    'fld_big_leaf': ("a tropical jungle plant with a few huge broad green leaves", 56),
    'fld_heather': ("a small clump of purple heather flowers", 26),
    'fld_lavender': ("a small bush of purple lavender flowers", 32),
    'fld_mushrooms': ("a small cluster of red capped forest mushrooms with white dots", 20),
    'fld_rosemary': ("a small rosemary herb bush with thin green leaves and tiny blue flowers", 32),
    'fld_bamboo_small': ("a small clump of young green bamboo shoots", 48),
    'fld_ipe_yellow': ("a tall ipe tree in full bloom, a crooked dark trunk and branches under a wide rounded crown completely covered in bright yellow flowers, no leaves", 300),
    'fld_ipe_purple': ("a tall ipe tree in full bloom, a crooked dark trunk and branches under a wide rounded crown completely covered in pink-purple flowers", 280),
    'fld_buriti': ("a tall buriti palm tree with a straight slender grey trunk, a crown of large round fan-shaped green leaves and hanging clusters of reddish brown fruits", 340),
    'fld_pequi_tree': ("a small crooked savanna tree with thick corky bark, twisted branches and clusters of broad olive green leaves", 190),
    'fld_termite_mound': ("a tall reddish brown earth termite mound shaped like a lumpy tower, with a few tufts of dry grass at its base", 96),
    'fld_red_rock': ("a reddish sandstone boulder with a few cracks and a small tuft of grass", 52),
    'fld_grey_rock': ("a rounded grey granite boulder with a patch of moss", 52),
    'fld_olive_tree': ("a gnarled olive tree with a twisted silver-grey trunk and a crown of small grey-green leaves", 210),
    'fld_pine_snow': ("a tall dark green pine tree with snow resting on its branches", 290),
    'fld_sakura': ("a cherry blossom tree with a dark curved trunk and a crown full of pale pink flowers", 240),
    'fld_birch': ("a slender birch tree with a white trunk with black marks and a light green airy crown", 270),
    'fld_date_palm': ("a tall date palm tree with a textured brown trunk and a crown of long feathery green fronds with hanging orange dates", 310),
    'fld_jungle_tree': ("a big tropical jungle tree with buttress roots, a thick trunk covered in vines and a wide dense dark green crown", 320),
    'fld_leafy_tree': ("a round leafy green deciduous tree with a brown trunk", 250),
}
PROPS = {  # id: (descricao, altura final em px)
    'prop_flower_pot': ("a round terracotta clay pot with pink and yellow flowers and green leaves", 46),
    'prop_fruit_crate': ("a small wooden crate full of mangoes, oranges and bananas", 44),
    'prop_lantern': ("a standing iron street lantern with a warm glowing yellow light on top of a short dark wooden post", 92),
    'prop_fishing_net': ("a fishing net hung to dry on a small wooden rack, with round cork floats", 72),
    'prop_flowers': ("a small bush of wild flowers, pink and yellow blossoms with green leaves", 38),
}


def _pal():
    cols = []
    for l in open(os.path.join(GAME, 'assets', '_reference', 'style_anchor', 'paleta-mestra.gpl')):
        p = l.split()
        if len(p) >= 3 and all(x.isdigit() for x in p[:3]): cols.append(tuple(map(int, p[:3])))
    return np.array(cols, float)


PAL = _pal()


def lab(a):
    a = a / 255.0; a = np.where(a > 0.04045, ((a + 0.055) / 1.055) ** 2.4, a / 12.92)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = a @ M.T / np.array([0.9505, 1.0, 1.089]); f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


PL = lab(PAL)


def nearest(rgb):
    return PAL[((lab(np.asarray(rgb, float))[..., None, :] - PL) ** 2).sum(-1).argmin(-1)]


def gen_one(name, prompt, i):
    import urllib.request, gen as G
    out = os.path.join(WORK, f'{name}_{i}.png')
    if os.path.exists(out): return out
    body = {"prompt": prompt, "aspect_ratio": "1:1", "seed": 31000 + (sum(map(ord, name)) * 7) % 9000 + i,
            "negative_prompt": "blurry, anti-aliasing, gradient background, photorealistic, 3d render, text, watermark, multiple objects, cropped, shadow"}
    for t in range(6):
        try:
            d = G.post("https://engine.prod.bria-api.com/v2/image/generate", body)
            url = d.get("result", {}).get("image_url") or G.poll(d["status_url"])
            urllib.request.urlretrieve(url, out); return out
        except Exception as e:
            if '429' not in str(e) or t == 5: raise
            time.sleep(10 * (t + 1))


def cmd_gen(ids):
    os.makedirs(WORK, exist_ok=True); jobs = []
    for k, d in ICONS.items():
        if not ids or k in ids: jobs += [(k, STYLE_ICON.format(d=d), i) for i in range(4)]
    for k, (d, _) in list(PROPS.items()) + list(FIELD.items()):
        if not ids or k in ids: jobs += [(k, STYLE_PROP.format(d=d).replace('cozy medieval fantasy town', 'cozy medieval fantasy countryside'), i) for i in range(4)]
    with cf.ThreadPoolExecutor(int(os.environ.get('BRIA_THREADS', '3'))) as ex:
        for f in cf.as_completed([ex.submit(gen_one, *j) for j in jobs]):
            try: f.result()
            except Exception as e: print('err', str(e)[:150])
    print('gen ok', len(jobs))


def outline(a):
    """Contorno colorido: pixels da borda da silhueta viram o tom escuro (cor * 0.45 -> paleta) da propria cor."""
    m = a[..., 3] > 0; edge = m & ~binary_erosion(m)
    dark = nearest(a[..., :3].astype(float) * 0.42 + np.array([6, 4, 8]))
    a[edge, :3] = dark[edge]; return a


def process(path, box):
    from pix import cutout
    im = cutout(Image.open(path)); a = np.asarray(im).copy(); a[..., 3] = np.where(a[..., 3] > 128, 255, 0)
    # fundo branco preso dentro de objetos em anel (colar, pulseira, coroa): regioes grandes quase brancas somem
    wh = (a[..., :3].min(-1) > 236) & (np.ptp(a[..., :3], -1) < 18) & (a[..., 3] > 0)
    lw, nw = label(wh)
    if nw:
        area = max(1, (a[..., 3] > 0).sum()); sz = np.bincount(lw.ravel()); big = sz > area * 0.04; big[0] = False
        a[big[lw], 3] = 0
    lb, n = label(a[..., 3] > 0)
    if n > 1:
        sz = np.bincount(lb.ravel()); keep = sz >= sz[1:].max() * 0.03; keep[0] = False; a[~keep[lb]] = 0
    im = Image.fromarray(a, 'RGBA'); im = im.crop(im.getbbox())
    if isinstance(box, int):  # icone: cabe em box x box
        s = box / max(im.size)
    else:  # enfeite: altura fixa
        s = box[1] / im.height
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.BOX)
    a = np.asarray(im).astype(float); al = a[..., 3] > 140
    q = nearest(a[..., :3]); out = np.zeros(a.shape, np.uint8); out[al, :3] = q[al]; out[al, 3] = 255
    out = outline(out)
    lb, n = label(out[..., 3] > 0)  # sem pixels orfaos
    if n > 1:
        sz = np.bincount(lb.ravel()); keep = sz >= 3; keep[0] = False; out[~keep[lb]] = 0
    return Image.fromarray(out, 'RGBA')


def place_icon(sp):
    o = Image.new('RGBA', (32, 32)); o.alpha_composite(sp, ((32 - sp.width) // 2, (32 - sp.height) // 2)); return o


def cmd_board():
    names = [k for k in list(ICONS) + list(PROPS) + list(FIELD) if os.path.exists(os.path.join(WORK, f'{k}_0.png'))]; S = 4
    ALLP = {**PROPS, **FIELD}
    b = Image.new('RGBA', (4 * 80 * S // 2 + 200, len(names) * 80 * S // 2), (240, 230, 200, 255)); d = ImageDraw.Draw(b)
    for r, k in enumerate(names):
        d.text((2, r * 160 + 2), k, fill=(60, 30, 20))
        for i in range(4):
            p = os.path.join(WORK, f'{k}_{i}.png')
            if not os.path.exists(p): continue
            sp = process(p, 28 if k in ICONS else (0, ALLP[k][1]))
            sp = place_icon(sp) if k in ICONS else sp
            big = sp.resize((sp.width * S if k in ICONS else sp.width * 2, sp.height * S if k in ICONS else sp.height * 2), Image.NEAREST)
            b.alpha_composite(big, (200 + i * 160, r * 160 + 12))
    b.save(os.path.join(WORK, 'board.png')); print(os.path.join(WORK, 'board.png'))


def cmd_final():
    pp = os.path.join(WORK, 'picks.json'); P = json.load(open(pp)) if os.path.exists(pp) else {}
    for k in ICONS:
        p = os.path.join(WORK, f'{k}_{P.get(k, 0)}.png')
        if os.path.exists(p): place_icon(process(p, 28)).save(os.path.join(GAME, 'assets', 'items', 'icons', f'icon_item_{k}.png'))
    os.makedirs(os.path.join(GAME, 'assets', 'environment', 'props'), exist_ok=True)
    for k, (_, h) in PROPS.items():
        p = os.path.join(WORK, f'{k}_{P.get(k, 0)}.png')
        if os.path.exists(p): process(p, (0, h)).save(os.path.join(GAME, 'assets', 'environment', 'props', f'{k}.png'))
    os.makedirs(os.path.join(GAME, 'assets', 'environment', 'field'), exist_ok=True)
    for k, (_, h) in FIELD.items():
        p = os.path.join(WORK, f'{k}_{P.get(k, 0)}.png')
        if os.path.exists(p): process(p, (0, h)).save(os.path.join(GAME, 'assets', 'environment', 'field', f'{k}.png'))
    json.dump({k: P.get(k, 0) for k in list(ICONS) + list(PROPS) + list(FIELD)}, open(pp, 'w'), indent=1); print('final ok')


if __name__ == '__main__':
    c = sys.argv[1]
    {'gen': lambda: cmd_gen(sys.argv[2:]), 'board': cmd_board, 'final': cmd_final}[c]()
