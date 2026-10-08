"""Empacota as passagens do Blender em mount_back/front no recorte comum 144px."""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image

GAME = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(GAME / 'tools/art/blender/monsters'))
import post

def main():
    work = Path(sys.argv[1] if len(sys.argv) > 1 else '.work/mounts')
    base = work / 'npz/pindorama_donkey_s1'
    meta = json.loads(base.with_suffix('.json').read_text())
    raw = np.load(base.with_suffix('.npz'))
    parts = meta['parts']
    front_ids = [i for i, p in enumerate(parts) if p and (p['name'].startswith('saddle_front') or p['name'].startswith('bridle'))]
    shaded, fronts = {}, {}
    for anim, count in meta['anims']:
        frames, covers = [], []
        for row in range(5):
            body_row, cover_row = [], []
            for frame in range(count):
                ids = raw[f'{anim}_id'][row, frame]
                pixels = post.shade_frame(ids, raw[f'{anim}_d'][row, frame], raw[f'{anim}_nx'][row, frame],
                                          raw[f'{anim}_ny'][row, frame], parts, post.LIGHT, None)
                cover = pixels.copy()
                cover[~np.isin(ids, front_ids)] = 0
                body_row.append(pixels)
                cover_row.append(cover)
            frames.append(body_row)
            covers.append(cover_row)
        shaded[anim], fronts[anim] = np.array(frames), np.array(covers)
    canvas, frame_px = meta['canvas'], 144
    low = max(int(np.nonzero((a[..., 3] > 0).any((0, 1)).any(1))[0].max()) for a in shaded.values())
    y1 = min(canvas, max(frame_px, low + 2)); y0 = y1 - frame_px
    x0 = canvas // 2 - frame_px // 2
    dest = GAME / 'assets/mounts/pindorama_mount_donkey'
    dest.mkdir(parents=True, exist_ok=True)
    for layer, arrays in [('back', shaded), ('front', fronts)]:
        for anim, pixels in arrays.items():
            count = pixels.shape[1]
            sheet = np.zeros((frame_px * 5, frame_px * count, 4), dtype=np.uint8)
            for row in range(5):
                for frame in range(count):
                    sheet[row*frame_px:(row+1)*frame_px, frame*frame_px:(frame+1)*frame_px] = pixels[row, frame, y0:y1, x0:x0+frame_px]
            Image.fromarray(sheet).save(dest / f'mount_donkey_{layer}_{anim}.png')
    print(dest)

if __name__ == '__main__':
    main()
