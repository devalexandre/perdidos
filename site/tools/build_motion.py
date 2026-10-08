#!/usr/bin/env python3
"""GIFs de repouso e trechos do próprio jogo. Requer Pillow e ffmpeg.
Uso: python3 site/tools/build_motion.py --title-frames .work/site-idle/_frames --clips .work/living-scenario
"""
import argparse
import subprocess
from pathlib import Path
from PIL import Image

SITE = Path(__file__).resolve().parents[1]


def titles(source):
    count = 0
    for timing in sorted(source.glob('*.txt')):
        durations = [int(value) for value in timing.read_text().split(',') if value]
        frames = [Image.open(source / f'{timing.stem}_{i:02d}.png').convert('RGBA') for i in range(len(durations))]
        if not frames:
            continue
        # GIF usa passos de 10 ms; distribui o arredondamento sem acelerar o ciclo inteiro.
        elapsed = 0
        previous = 0
        gif_durations = []
        for duration in durations:
            elapsed += duration
            boundary = round(elapsed / 10) * 10
            gif_durations.append(boundary - previous)
            previous = boundary
        # Paleta compartilhada: reserva o índice zero para transparência em todos os quadros.
        atlas = Image.new('RGB', (frames[0].width, frames[0].height * len(frames)))
        for i, frame in enumerate(frames):
            atlas.paste(frame.convert('RGB'), (0, i * frame.height))
        palette = atlas.quantize(colors=255)
        colors = [0, 0, 0] + palette.getpalette()[:765]
        indexed = []
        for frame in frames:
            quantized = frame.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE)
            data = bytes(0 if alpha < 128 else index + 1 for index, alpha in zip(quantized.tobytes(), frame.getchannel('A').tobytes()))
            result = Image.frombytes('P', frame.size, data)
            result.putpalette(colors)
            indexed.append(result)
        indexed[0].save(SITE / 'img' / 'titles' / f'{timing.stem}.gif', save_all=True,
                        append_images=indexed[1:], duration=gif_durations, loop=0,
                        transparency=0, disposal=2, optimize=False)
        count += 1
    print(f'{count} GIFs de personagens em repouso')


def clips(source):
    target = SITE / 'img' / 'clips'
    target.mkdir(parents=True, exist_ok=True)
    # Converte só os MP4 presentes na pasta (os outros GIFs do site ficam como estão).
    for name in ['acampamento-noite', 'neblina', 'portal', 'chuva-acampamento', 'passaros', 'campos']:
        if not (source / f'{name}.mp4').exists():
            continue
        destination = target / f'{name}.gif'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-threads', '2',
                        '-i', str(source / f'{name}.mp4'), '-filter_complex_threads', '1',
                        '-filter_complex', '[0:v]fps=12,scale=480:270:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3',
                        '-t', '4', '-loop', '0', str(destination)], check=True)
        with Image.open(destination) as image:
            image.seek(0)
            image.convert('RGB').save(target / f'{name}.webp', quality=90)
        print(f'{name}: {destination.stat().st_size // 1024} KiB')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--title-frames', type=Path)
    parser.add_argument('--clips', type=Path)
    args = parser.parse_args()
    if args.title_frames:
        titles(args.title_frames)
    if args.clips:
        clips(args.clips)
