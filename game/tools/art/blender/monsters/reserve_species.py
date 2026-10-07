"""Thirty regional species; reusable Blender geometry and animation, no gameplay registration.
Catalog records: id, normal/boss/atroz names, anatomy, material, signature, provenance.
Stages follow the native convention: 1 normal, 3 boss, 4 atroz.
"""
import json
import math
from pathlib import Path
from mathutils import Vector
import mon_rig as R

CATALOG = json.loads((Path(__file__).parent / 'reserve/catalog.json').read_text())
SPECIES = {row[0]: row for rows in CATALOG.values() for row in rows}
STAGES = (1, 3, 4)
FRAME = {1: 96, 3: 240, 4: 240}
ANIMS = [('idle', 8), ('walk', 8), ('attack', 8), ('hit', 4), ('death', 8)]


def build(species, stage):
    if stage not in STAGES:
        raise ValueError('Available stages: normal=1, boss=3, atroz=4')
    row = SPECIES[species]
    anatomy, skin, motif = row[4:7]
    R.reset()
    rig = R.Rig(species)
    rig.turn.scale = ((1.05 if stage == 1 else 2.15),) * 3
    body = rig.empty('body', (0, 0, .48), rig.root)
    head = rig.empty('face', (0, -.32, .85), body)
    tail = rig.empty('tail', (0, .3, .4), body)
    crown = rig.empty('signature', (0, 0, .9), body)
    rig.limbs = []
    skin = 'obsidian_n' if stage == 4 else skin
    accent = 'water' if stage == 4 else {'flame':'cap', 'ice':'fur_blue', 'palm':'moss', 'reeds':'moss', 'bamboo':'moss', 'bark':'wood', 'sail':'cap', 'mane':'gold', 'coral':'fur_cream'}.get(motif, 'gold')

    def ball(name, p, size, mat=skin, parent=body):
        return rig.add_mesh(R.ellipsoid(name, Vector(p), size, seg=16, rings=10), name, mat, parent)

    def spike(name, p, q, width=.07, mat=accent, parent=crown):
        return rig.add_mesh(R.cone(name, Vector(p), Vector(q), width, .005, seg=8, rings=3), name, mat, parent)

    def limb(name, p, q, width=.085, mat=skin):
        pivot = rig.empty(name+'_joint', p, body)
        rig.limbs.append(pivot)
        spike(name, p, q, width, mat, pivot)
        ball(name+'_foot', q, (width*1.25, width*1.7, width*.7), mat, pivot)
        return pivot

    quad = anatomy in ('horse', 'boar', 'dragon', 'wolf', 'cat', 'crocodile', 'salamander')
    insect = anatomy in ('crab', 'beetle', 'spider', 'mantis')
    bird = anatomy in ('bird', 'bat', 'fish')
    if quad:
        long = anatomy in ('crocodile', 'salamander')
        ball('torso', (0, .07, .43), (.28, .48 if long else .36, .23))
        for side in (-1, 1):
            for k, y in enumerate((-.23, .33)):
                limb(f'leg{side}_{k}', (side*.21, y, .44), (side*.26, y-.03, .09), .065 if anatomy == 'horse' else .085)
        spike('tail_base', (0, .34, .44), (0, .92, .3), .12, skin, tail)
        if anatomy in ('horse', 'wolf', 'cat'):
            for side in (-1, 1):
                spike(f'ear{side}', (side*.15, -.3, .96), (side*.22, -.25, 1.2), .09, skin, head)
        ball('muzzle', (0, -.59 if long else -.52, .73), (.21, .31 if long else .13, .09 if long else .11), skin, head)
        if anatomy == 'boar':
            for side in (-1, 1):
                spike(f'tusk{side}', (side*.18, -.47, .66), (side*.27, -.59, .88), .055, 'claw', head)
        if anatomy == 'dragon' and motif != 'mane':
            for side in (-1, 1):
                for k in range(3):
                    spike(f'wing{side}_{k}', (side*.2, .05, .6), (side*(.55+.09*k), .05+.16*k, .92-.09*k), .15, accent, body)
    elif insect:
        ball('carapace', (0, .15 if anatomy == 'mantis' else .05, .43), (.18,.43,.2) if anatomy == 'mantis' else (.36, .35, .25))
        count = 4 if anatomy == 'spider' else 3
        for side in (-1, 1):
            for k in range(count):
                y = -.23+k*.17
                pivot = limb(f'leg{side}_{k}', (side*.24, y, .45), (side*.58, y+.08, .12), .045)
                spike(f'knee{side}_{k}', (side*.24, y, .45), (side*.43, y, .52), .06, skin, pivot)
            if anatomy in ('crab', 'mantis'):
                pivot = limb(f'claw{side}', (side*.25, -.12, .5), (side*.48, -.43, .58), .09)
                for k in ((1,) if anatomy == 'mantis' else (-1,1)):
                    spike(f'pincer{side}_{k}', (side*.48+k*.065, -.43, .58), (side*.48+k*.03, -.65, .64), .065, accent, pivot)
        if anatomy == 'beetle':
            for side in (-1, 1):
                ball(f'elytron{side}', (side*.16, .13, .6), (.17, .3, .13), accent)
            spike('beetle_horn', (0, -.2, .77), (0, -.46, 1.02), .09)
    elif anatomy in ('serpent', 'hydra'):
        for k in range(15):
            angle = k*.6
            ball(f'coil{k}', (.25*math.cos(angle), .12+.23*math.sin(angle), .12+.021*k), (.115,)*3)
        for k in range(3 if anatomy == 'hydra' else 1):
            x = (k-1)*.3 if anatomy == 'hydra' else 0
            spike(f'neck{k}', (x*.5, .02, .38), (x, -.23, .8), .13, skin, head)
            if anatomy == 'hydra' and k != 1:
                ball(f'extra_head{k}', (x, -.3, .83), (.18, .2, .15), skin, head)
                for s in (-1, 1):
                    ball(f'extra_eye{k}_{s}', (x+s*.075, -.47, .88), (.035,.023,.046), 'eye', head)
    elif bird:
        ball('torso', (0, .08, .6), (.22, .3, .3))
        for side in (-1, 1):
            pivot = rig.empty(f'wing{side}_joint', (side*.16, 0, .72), body)
            rig.limbs.append(pivot)
            for k in range(5):
                spike(f'feather{side}_{k}', (side*.18, .02+k*.025, .7), (side*(.64-k*.055), .05+k*.12, .65-k*.035), .105, accent if k%2 else skin, pivot)
            if anatomy == 'bat':
                verts=[(side*.17,0,.73),(side*.7,.06,.78),(side*.62,.3,.48),(side*.46,.28,.58),(side*.35,.53,.4),(side*.22,.3,.57)]
                membrane=R._obj_from(f'membrane{side}',verts,[(0,1,2),(0,2,3),(0,3,4),(0,4,5)],smooth=False)
                rig.add_mesh(membrane,f'membrane{side}',skin,pivot)
            if anatomy != 'fish':
                limb(f'foot{side}', (side*.1, 0, .4), (side*.12, -.1, .12), .045, 'claw')
        if anatomy == 'bird':
            spike('beak', (0,-.48,.81), (0,-.68,.73), .1, 'gold', head)
        else:
            ball('snout',(0,-.49,.78),(.12,.07,.07),skin,head)
        if anatomy == 'fish':
            for k in range(4):
                spike(f'dorsal_fin{k}',(0,.02+k*.1,.79),(0,.07+k*.1,1.05-k*.04),.075,accent,body)
        for k in range(3):
            spike(f'tail_feather{k}', ((k-1)*.06,.25,.5), ((k-1)*.16,.72,.42+k*.07), .09, accent, tail)
        if anatomy == 'bat':
            for side in (-1,1):
                spike(f'bat_ear{side}', (side*.14,-.3,.94), (side*.22,-.25,1.26), .11, skin, head)
    elif anatomy in ('golem', 'turtle'):
        ball('torso', (0, .05, .5), (.29, .22, .36))
        for side in (-1, 1):
            limb(f'arm{side}', (side*.25, 0, .7), (side*.42, -.1, .34), .13)
            limb(f'leg{side}', (side*.14, 0, .3), (side*.17, -.03, .07), .11)
        if anatomy == 'turtle':
            ball('shell', (0,.22,.57), (.34,.17,.4), 'wood')
            for k in range(5):
                ball(f'shell_plate{k}', ((k%2-.5)*.26,.34,.3+k*.12), (.14,.08,.12), accent)
            spike('turtle_beak',(0,-.42,.8),(0,-.59,.74),.13,'gold',head)
    else:
        shape = {'spindle':(.19,.19,.45), 'lantern':(.33,.25,.36), 'mortar':(.31,.29,.32), 'wisp':(.23,.2,.27)}[anatomy]
        ball('vessel', (0,0,.52), shape)
        if anatomy == 'spindle':
            spike('spindle_axis',(0,0,.1),(0,0,1.22),.075,'wood')
        if anatomy in ('lantern','mortar'):
            for z in (.24,.8):
                for k in range(12):
                    a = k*math.tau/12
                    ball(f'rim{z}_{k}',(.28*math.cos(a),.23*math.sin(a),z),(.065,.06,.045),'wood')
        if anatomy == 'wisp':
            spike('wisp_flame',(0,0,.62),(.1,.07,1.15),.2,'water')
        else:
            for side in (-1,1):
                limb(f'foot{side}',(side*.12,0,.23),(side*.19,-.03,.07),.065,'wood')

    if motif == 'mane':
        for k in range(11):
            a=k*math.tau/11
            ball(f'mane_curl{k}',(.24*math.cos(a),-.21,.83+.24*math.sin(a)),(.1,.12,.1),'gold',head)
        spike('nian_horn',(0,-.27,1.0),(.03,-.23,1.23),.065,'claw',head)
    # A shared readable face with anatomy-specific placement, never a flat billboard.
    face_z = .84 if anatomy not in ('lantern','mortar','spindle','wisp') else .57
    face_y = -.35 if face_z == .84 else -.22
    if face_z == .84:
        ball('head', (0, -.31, .83), (.23,.22,.19), skin, head)
    for side in (-1,1):
        p = (side*.095, face_y-.17 if face_z == .84 else face_y-.025, face_z+.045)
        ball(f'eye{side}',p,(.062,.036,.078),'lamp2' if stage == 4 else 'eye',head)
        ball(f'glint{side}',(p[0]-.012,p[1]-.031,p[2]+.025),(.018,)*3,'white',head)
        if stage >= 3:
            spike(f'brow{side}',(p[0]-side*.065,p[1]-.01,p[2]+.065),(p[0]+side*.065,p[1],p[2]+.1),.025,skin,head)
    # Species-specific signature, expanded geometrically for the boss.
    count = 3 if stage == 1 else 7
    if motif in ('flame','ice','gem','reeds','bamboo','bark','palm','sail','crest','mane','coral'):
        for k in range(count):
            a = k*math.tau/count
            p = (.2*math.cos(a),.08+.2*math.sin(a),.64)
            height = .22 + .07*(k%3) + (.18 if stage >= 3 else 0)
            q = (p[0]*1.65,p[1]+.12,p[2]+height)
            if motif == 'flame':
                ball(f'flame_base{k}',p,(.085,.09,height*.42),accent,crown)
                rig.add_mesh(R.cone(f'flame_tip{k}',Vector(p),Vector(q),.09,.003,seg=8,rings=5,bend=(.08,0,.05)),f'flame_tip{k}',accent,crown)
                ball(f'flame_core{k}',(p[0],p[1]-.05,p[2]+.03),(.04,.04,.09),'lamp2',crown)
            elif motif == 'palm':
                spike(f'palm_stem{k}',p,q,.03,'wood')
                for side in (-1,1):
                    leaf=ball(f'palm_leaf{k}_{side}',(q[0]+side*.09,q[1],q[2]-.025),(.17,.055,.035),'moss',crown)
                    # Leaf geometry stays in model coordinates, attached to the crown pivot.
            else:
                spike(f'{motif}_{k}',p,q,.095 if motif in ('sail','mane') else .055,accent)
            if motif in ('bark','coral','palm'):
                spike(f'{motif}_branch{k}',q,(q[0]+.13,q[1],q[2]+.1),.035,skin)
    elif motif == 'hood':
        for side in (-1,1):
            ball(f'hood{side}',(side*.19,-.2,.76),(.16,.075,.29),accent,head)
    elif motif in ('horns','chest'):
        if motif == 'chest':
            ball('chest_mark',(0,-.27,.45),(.13,.05,.13),'fur_cream')
        else:
            for side in (-1,1):
                spike(f'horn{side}',(side*.18,-.27,.96),(side*.4,-.3,1.19),.085,'claw',head)
    elif motif == 'gills':
        for side in (-1,1):
            for k in range(3):
                spike(f'gill{side}_{k}',(side*.18,-.27,.83),(side*(.37+.045*k),-.25+.1*k,.97-k*.1),.065,'cap',head)
    elif motif == 'handtail':
        ball('tail_hand',(0,.9,.32),(.16,.09,.09),accent,tail)
        for k in range(4):
            spike(f'tail_finger{k}',((k-1.5)*.075,.9,.32),((k-1.5)*.09,1.13,.39),.034,accent,tail)
    elif motif == 'bowl':
        ball('water_bowl',(0,-.28,1),(.18,.16,.035),'water',head)
        for k in range(10):
            a=k*math.tau/10
            ball(f'bowl_rim{k}',(.18*math.cos(a),-.28+.15*math.sin(a),1.02),(.045,)*3,skin,head)
    elif motif in ('thread','paper'):
        for k in range(7):
            z=.3+k*.07
            for s in (-1,1):
                ball(f'band{k}_{s}',(s*.15,-.22,z),(.14,.04,.02),accent)
        spike('ribbon',(0,0,.18),(.2,-.1,.02),.065,'cap',tail)
    elif motif == 'pestle':
        spike('pestle',(.16,.08,.45),(.4,.16,1.25),.085,'wood',crown)
        ball('pestle_knob',(.4,.16,1.23),(.13,.13,.17),accent,crown)
    elif motif == 'anchor':
        spike('anchor_shaft',(.3,-.1,.3),(.3,-.1,.9),.045,'rock')
        for s in (-1,1):
            spike(f'anchor_fluke{s}',(.3,-.1,.3),(.3+s*.17,-.1,.46),.055,'rock')
    elif motif == 'whiskers':
        for s in (-1,1):
            spike(f'whisker{s}',(s*.1,-.5,.78),(s*.44,-.54,.82),.025,accent,head)
    elif motif == 'fan':
        for k in range(5):
            spike(f'fan{k}',(.35,-.15,.45),(.25+k*.1,-.22,.89-abs(k-2)*.04),.065,'moss')
    elif motif == 'mist':
        for k in range(count):
            ball(f'mist{k}',(.37*math.cos(k*2),.37*math.sin(k*2),.2+k*.08),(.09,.08,.045),'water',crown)

    # Boss: additional anatomy follows each body plan, not just a larger normal.
    if stage >= 3:
        for side in (-1,1):
            if bird:
                for k in range(3):
                    spike(f'boss_wing{side}_{k}',(side*.25,.1,.7),(side*(.83-k*.08),.25+k*.17,.85-k*.08),.09,accent,body)
            elif insect:
                ball(f'boss_shoulder{side}',(side*.31,-.05,.6),(.16,.19,.12),accent)
                spike(f'boss_scythe{side}',(side*.3,-.18,.63),(side*.55,-.46,.88),.09,'claw',body)
            else:
                offset = -.27 if anatomy in ('spindle','lantern','mortar','wisp') else 0
                spike(f'boss_antler{side}',(side*.18,-.12,.97+offset),(side*.34,-.1,1.35+offset),.085,accent,head)
                spike(f'boss_antler_branch{side}',(side*.27,-.14,1.18+offset),(side*.46,-.18,1.28+offset),.05,accent,head)
        for k in range(4):
            ball(f'boss_armor{k}',(0,.02+k*.13,.72),(.14,.075,.08),accent)
    # Atroz: separate silhouette, split dorsal blades, fangs and animated embers.
    if stage == 4:
        for side in (-1,1):
            front = face_y - (.15 if face_z == .84 else .04)
            spike(f'atroz_fang{side}',(side*.14,front,face_z-.03),(side*.17,front-.04,face_z-.22),.035,'claw',head)
            for k in range(3):
                spike(f'atroz_blade{side}_{k}',(side*.17,.02+k*.17,.66),(side*(.48+k*.025),.14+k*.18,1.03-k*.06),.075,'water',body)
        for k in range(5):
            a=k*math.tau/5
            ball(f'atroz_ember{k}',(.45*math.cos(a),.45*math.sin(a),.37+k*.12),(.038,.038,.065),'lamp2',crown)
    rig.save_rest()
    return rig


def pose(rig, anim, i, n, stage):
    t=i/n
    s=math.sin(math.tau*t)
    body, head = rig.n('body'), rig.n('face')
    if anim == 'idle':
        body.scale.z = 1+.035*s
        head.rotation_euler.z=.045*s
        rig.n('tail').rotation_euler.z=.14*s
        if i == n-2:
            for side in (-1,1): rig.n(f'eye{side}').scale.z=.18
    elif anim == 'walk':
        rig.root.location.z += .06*(1-math.cos(math.tau*t*2))
        body.rotation_euler.y=.045*s
        for k,p in enumerate(rig.limbs): p.rotation_euler.x=.38*math.sin(math.tau*t+(k%2)*math.pi)
        rig.n('tail').rotation_euler.z=.25*s
    elif anim == 'attack':
        curve=(0,.18,-.35,-.5,-.22,-.08,0,0)[i]
        body.rotation_euler.x=curve
        head.rotation_euler.x=-curve*.55
        for k,p in enumerate(rig.limbs): p.rotation_euler.x=-curve*(1 if k%2 else -1)
        rig.n('signature').rotation_euler.z=.35*math.sin(math.pi*i/(n-1))
    elif anim == 'hit':
        body.scale.z=(.77,1.13,.95,1)[i]
        head.rotation_euler.y=(.25,-.14,.05,0)[i]
    elif anim == 'death':
        u=i/(n-1)
        body.rotation_euler.y=1.35*u
        body.location.z-=.26*u
        for side in (-1,1): rig.n(f'eye{side}').scale.z=max(.08,1-u*2)
        rig.n('signature').scale=(max(.05,1-u),)*3
    if stage == 4 and anim != 'death':
        rig.n('signature').rotation_euler.z += .15*s
        for k in range(5):
            rig.n(f'atroz_ember{k}').location.z+=.045*math.sin(math.tau*t+k)
