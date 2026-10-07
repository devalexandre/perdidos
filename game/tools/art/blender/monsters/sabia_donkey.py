"""Jumento do Sertão: base equina da Mula de Brasa, sem fogo, com arreio.
Render: render_monster.py sabia_donkey 1 --anims idle:4,walk:6 --work .work/mounts
Pack: tools/art/mounts/pack_donkey.py
"""
from mathutils import Vector
import mon_rig as R
import reserve_species as S

STAGES = (1,)
FRAME = {1: 144}
ANIMS = [('idle', 4), ('walk', 6)]
ORIGIN_FRAC = 0.64

def build(stage):
    row = list(S.SPECIES['ember_mule'])
    row[0], row[4], row[5], row[6] = 'sabia_donkey', 'horse', 'rock', 'none'
    S.SPECIES['sabia_donkey'] = row
    rig = S.build('sabia_donkey', 1)
    rig.turn.scale = (1.55,) * 3
    for side in (-1, 1):
        rig.n(f'ear{side}').scale.z = 1.7
    def ball(name, location, size, mat, parent):
        rig.add_mesh(R.ellipsoid(name, Vector(location), size, seg=16, rings=10), name, mat, parent)
    ball('saddle_back', (0, .08, .65), (.30, .26, .065), 'wood', rig.n('body'))
    for side in (-1, 1):
        ball(f'saddle_front{side}', (side*.25, .05, .5), (.045, .28, .20), 'wood', rig.n('body'))
        ball(f'bridle{side}', (side*.195, -.49, .75), (.026, .13, .08), 'wood', rig.n('face'))
    rig.save_rest()
    return rig

def pose(rig, anim, frame, count, stage):
    S.pose(rig, anim, frame, count, 1)

