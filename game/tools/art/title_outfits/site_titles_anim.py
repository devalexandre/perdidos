#!/usr/bin/env python3
"""Monta os títulos animados do site (site/img/titles/<título>_<m|f>.webp) a partir dos quadros salvos por
render_site_titles.tscn -- --anim (<dir>/_frames/<título>_<m|f>_NN.png + <título>_<m|f>.txt com os ms por quadro).

WebP animado sem perdas, com alfa (a sombra fica com meia transparência, igual ao PNG estático), em loop.
Quadros iguais seguidos viram um só (soma os tempos).

    python3 game/tools/art/title_outfits/site_titles_anim.py site/img/titles [--keep-frames]
"""
import glob, os, shutil, sys
from PIL import Image


def build(out_dir, keep=False):
    fdir = os.path.join(out_dir, '_frames')
    total = 0
    for txt in sorted(glob.glob(os.path.join(fdir, '*.txt'))):
        tag = os.path.basename(txt)[:-4]
        durs = [int(x) for x in open(txt).read().strip().split(',') if x]
        frames = [Image.open(os.path.join(fdir, f'{tag}_{i:02d}.png')).convert('RGBA') for i in range(len(durs))]
        imgs, ds = [], []
        for f, d in zip(frames, durs):
            if imgs and f.tobytes() == imgs[-1].tobytes():
                ds[-1] += d
                continue
            imgs.append(f); ds.append(d)
        dst = os.path.join(out_dir, f'{tag}.webp')
        imgs[0].save(dst, save_all=True, append_images=imgs[1:], duration=ds, loop=0, lossless=True, method=6)
        sz = os.path.getsize(dst); total += sz
        print(f'{tag}.webp: {len(imgs)} quadros, {sum(ds)} ms, {sz / 1024:.1f} KiB')
    if not keep and os.path.isdir(fdir):
        shutil.rmtree(fdir)
    print(f'total: {total / 1024:.1f} KiB')


if __name__ == '__main__':
    build(sys.argv[1], '--keep-frames' in sys.argv)
