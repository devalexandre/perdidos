"""Etapa 4: gera data/customization/palettes.tres (de palettes.json) e data/customization/options.tres.

    python make_data.py
Padroes = Viajante atual: pele 0, cabelo 0 (castanho), olhos 0, sem brinco, estilo = o primeiro da lista.
"""
import json, os
from common import GAME
from edits import STYLES, DEFAULT_STYLE

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(GAME, 'data', 'customization')
EARRINGS = ['hoop', 'seed', 'feather']
# ordem no seletor: padrao primeiro, "raspado" por ultimo
ORDER = {b: [DEFAULT_STYLE[b]] + [s for s in STYLES[b] if s not in (DEFAULT_STYLE[b], 'buzz')] + ['buzz'] for b in STYLES}


def colors(ramp):
    return 'PackedColorArray(%s)' % ', '.join('%.6g, %.6g, %.6g, 1' % tuple(c / 255 for c in rgb) for rgb in ramp)


def strs(xs): return 'PackedStringArray(%s)' % ', '.join(json.dumps(x) for x in xs)


def snames(xs): return 'Array[StringName]([%s])' % ', '.join('&"%s"' % x for x in xs)


def main():
    os.makedirs(OUT, exist_ok=True)
    P = json.load(open(os.path.join(HERE, 'palettes.json')))
    lines = ['[gd_resource type="Resource" script_class="CustomizationPalettes" format=3]', '',
             '[ext_resource type="Script" path="res://scripts/shared/data/customization_palettes.gd" id="1_pal"]', '',
             '[resource]', 'script = ExtResource("1_pal")']
    for g in ('skin', 'hair', 'eye'):
        lines.append('%s_ramps = Array[PackedColorArray]([%s])' % (g, ', '.join(colors(r) for _, r in P[g])))
        lines.append('%s_keys = %s' % (g, strs([k for k, _ in P[g]])))
    open(os.path.join(OUT, 'palettes.tres'), 'w').write('\n'.join(lines) + '\n')
    all_styles = sorted({s for b in ORDER for s in ORDER[b]})
    sk = ', '.join('&"%s": "CUSTOM_HAIR_%s"' % (s, s.upper()) for s in all_styles)
    ek = ', '.join('&"%s": "CUSTOM_EARRING_%s"' % (e, e.upper()) for e in EARRINGS)
    lines = ['[gd_resource type="Resource" script_class="CustomizationOptions" format=3]', '',
             '[ext_resource type="Script" path="res://scripts/shared/data/customization_options.gd" id="1_opt"]',
             '[ext_resource type="Resource" path="res://data/customization/palettes.tres" id="2_pal"]', '',
             '[resource]', 'script = ExtResource("1_opt")', 'palettes = ExtResource("2_pal")',
             'hair_styles_male = %s' % snames(ORDER['male']), 'hair_styles_female = %s' % snames(ORDER['female']),
             'earrings = %s' % snames(EARRINGS),
             'style_keys = Dictionary[StringName, String]({%s})' % sk,
             'earring_keys = Dictionary[StringName, String]({&"": "CUSTOM_EARRING_NONE", %s})' % ek,
             'default_skin = 0', 'default_hair_color = 0', 'default_eye_color = 0', 'default_earrings = &""']
    open(os.path.join(OUT, 'options.tres'), 'w').write('\n'.join(lines) + '\n')
    print('ok', OUT)


if __name__ == '__main__':
    main()
