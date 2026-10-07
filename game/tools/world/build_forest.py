"""Sabiá woodland: connected trails cut through dense native vegetation.
Run this after changing build_hunt_areas; cave interiors are never overwritten.
"""
import math
import random
import re
from collections import defaultdict
from build_hunt_areas import AREAS, GAME, write_scene, trail_points, branch_paths, clearings

import worldgen as wg

wg.install()  # writes go through worldgen (--check = dry run + validation)


def build(a):
    a = dict(a, ground='sabia_forest')
    a['spawns'] = list(a['spawns']) + [('sabia_jaguar', 1 if a['variant'] < 2 else 2, 2, 22, -23)]
    write_scene(a)
    path = GAME/'scenes/maps'/f'{a["id"]}.tscn'
    source = path.read_text()
    paths = [trail_points(a)] + branch_paths(a)
    rooms = clearings(a) + [(0,33,6),(0,-34,6)]
    roots = a['id'].endswith('_roots')
    if roots:
        paths += [[(x,28) for x in range(-7,25)], [(24,z) for z in range(24,29)]]
        rooms += [(24,28,6),(-12,4,4),(12,-10,4),(-4,20,4)]
    samples = [p for route in paths for p in route]
    def walk(x,z):
        return any((x-px)**2+(z-pz)**2 < 4.2**2 for px,pz in samples) or any((x-px)**2+(z-pz)**2 < (r+1.5)**2 for px,pz,r in rooms)
    cells = {(x,z) for x in range(-44,44,2) for z in range(-44,44,2) if walk(x+1,z+1)}
    # Shared vertices ensure paths and clearings are one connected navigation surface.
    verts, indexes, polys = [], {}, []
    for x,z in sorted(cells):
        face=[]
        for p in [(x,z),(x,z+2),(x+2,z+2),(x+2,z)]:
            if p not in indexes:
                indexes[p]=len(indexes); verts.extend([p[0],0,p[1]])
            face.append(indexes[p])
        polys.append('PackedInt32Array('+', '.join(map(str,face))+')')
    nav='[sub_resource type="NavigationMesh" id="nav"]\ncell_size = 0.2\ncell_height = 0.2\nvertices = PackedVector3Array('+', '.join(map(str,verts))+')\npolygons = Array[PackedInt32Array](['+', '.join(polys)+'])\n\n'
    source=re.sub(r'\[sub_resource type="NavigationMesh" id="nav"\].*?(?=\[node)',nav,source,flags=re.S)
    # Replace sparse regular rows; all large plants are outside the walkable footprint.
    source=re.sub(r'\[node [^\n]*parent="Decor"\].*?(?=\[node|\Z)','',source,flags=re.S)
    if roots:
        source=source.replace('Vector3(0, 2, 24)','Vector3(24, 2, 24)').replace('Vector3(0, 0, 24)','Vector3(24, 0, 24)').replace('Vector3(0, 0, 21)','Vector3(24, 0, 29)')
        source=re.sub(r'\[node name="Gate" type="MeshInstance3D" parent="Interactables/cave"\].*?(?=\[node)','',source,flags=re.S)
        source=source.replace('metadata/recommended_level = "12–25"','metadata/recommended_level = "12–30"')
    resources=[]; nodes=[]
    def node(name, kind, props, parent='Decor'):
        if name.startswith(('Gate','OpenGate','CaveMouth','CaveCliff')):
            props = re.sub(r'position = Vector3\(([^,]+), ([^,]+), ([^)]+)\)', lambda m: f'position = Vector3({m[1]}, {m[2]}, {48-float(m[3])})', props)
        nodes.append(f'[node name="{name}" type="{kind}" parent="{parent}"]\n{props}\n')
    palette=['tree_jungle_a','tree_ipe_yellow_a','tree_ipe_purple_a','palm_buriti_a','bamboo_clump_a','bush_jungle_a','fern','grass_tuft','rock_moss_a','prop_log']
    for mesh in palette:
        resources.append(f'[ext_resource type="ArrayMesh" path="res://assets/environment/painted/meshes/{mesh}.res" id="wood_{mesh}"]')
    rng=random.Random(824+a['variant']); groups=defaultdict(list)
    def place(mesh,x,z,scale,y=0):
        angle=rng.uniform(0,math.tau); c=math.cos(angle)*scale; s=math.sin(angle)*scale
        # MultiMesh uses row-major 3x4 transforms.
        groups[mesh].extend([c,0,s,x, 0,scale*rng.uniform(.9,1.15),0,y, -s,0,c,z])
    def in_nav(x,z,margin=0):
        return any((math.floor((x+dx)/2)*2,math.floor((z+dz)/2)*2) in cells for dx,dz in [(0,0),(margin,0),(-margin,0),(0,margin),(0,-margin)])
    for x in range(-48,49,4):
        for z in range(-48,49,4):
            px=x+rng.uniform(-1,1); pz=z+rng.uniform(-1,1)
            if not in_nav(px,pz,1.8) and not (roots and abs(px-24)<9 and abs(pz-26)<7):
                mesh=rng.choices(palette[:5],[65,5,3,12,15])[0]
                place(mesh,px,pz,rng.uniform(.85,1.35))
    for _ in range(2600):
        x,z=rng.uniform(-48,48),rng.uniform(-48,48)
        if roots and abs(x-24)<7 and abs(z-24)<7: continue
        distance=min((x-px)**2+(z-pz)**2 for px,pz in samples)
        if distance<2.4**2: continue
        if in_nav(x,z,1):
            if distance<4**2: place('fern',x,z,rng.uniform(.5,1.0))
        else:
            mesh=rng.choices(['bush_jungle_a','fern','grass_tuft','rock_moss_a','prop_log'],[42,32,20,5,1])[0]
            place(mesh,x,z,rng.uniform(.7,1.5))
    for mesh,buffer in groups.items():
        resources.append(f'[sub_resource type="MultiMesh" id="mm_{mesh}"]\ntransform_format = 1\nmesh = ExtResource("wood_{mesh}")\ninstance_count = {len(buffer)//12}\nbuffer = PackedFloat32Array('+', '.join(f'{v:.4f}' for v in buffer)+')')
        node('Woodland_'+mesh,'MultiMeshInstance3D',f'multimesh = SubResource("mm_{mesh}")')
    if roots:
        for mat in ['stonewall','wood_dark']:
            resources.append(f'[ext_resource type="Material" path="res://assets/environment/painted/materials/mat_{mat}.tres" id="gate_{mat}_texture"]')
        # A real open gate set into a moss-covered rock face; trigger sits in its threshold.
        for ident,kind,props in [
            ('gate_stone','StandardMaterial3D','albedo_color = Color(0.27, 0.32, 0.22, 1)\nroughness = 1.0'),
            ('gate_wood','StandardMaterial3D','albedo_color = Color(0.21, 0.12, 0.055, 1)\nroughness = 1.0'),
            ('gate_iron','StandardMaterial3D','albedo_color = Color(0.10, 0.12, 0.11, 1)\nmetallic = 0.6\nroughness = 0.65'),
            ('gate_cube','BoxMesh','size = Vector3(1, 1, 1)')]:
            resources.append(f'[sub_resource type="{kind}" id="{ident}"]\n{props}')
        def box(name,x,y,z,sx,sy,sz,mat='gate_stone'):
            material = 'ExtResource("gate_stonewall_texture")' if mat == 'gate_stone' else ('ExtResource("gate_wood_dark_texture")' if mat == 'gate_wood' else 'SubResource("gate_iron")')
            node(name,'MeshInstance3D',f'position = Vector3({x}, {y}, {z})\nscale = Vector3({sx}, {sy}, {sz})\nmesh = SubResource("gate_cube")\nmaterial_override = {material}')
        node('CaveMouth','MeshInstance3D','position = Vector3(24, 2.4, 26)\nscale = Vector3(3.2, 2.4, 0.4)\nmesh = SubResource("cave_mouth")\nmaterial_override = SubResource("cave_mouth_mat")')
        for side in [-1,1]:
            for row in range(5): box(f'GatePier{side}_{row}',24+side*3.1,row*.9+.45,24.8,1.3, .85,1.6)
            # Leaves stand open beside the entrance, never across the walk trigger.
            box(f'OpenGate{side}',24+side*2.5,2,22.9,.22,4,2.8,'gate_wood')
            for y in [0.8,3.2]: box(f'GateStrap{side}_{y}',24+side*2.5,y,22.9,.26,.18,2.9,'gate_iron')
        box('GateLintel',24,4.8,24.8,7.5, .85,1.8)
        box('GateThreshold',24,.08,24,5,.16,2)
        for i in range(13):
            x=24+rng.choice([-1,1])*rng.uniform(5.5,9); z=rng.uniform(27,30)
            node(f'CaveCliff{i}','MeshInstance3D',f'position = Vector3({x}, 0, {z})\nscale = Vector3(4, {rng.uniform(7,11)}, 5)\nmesh = ExtResource("wood_rock_moss_a")')
        points=', '.join(f'{x}, 0.029, 28' for x in range(-7,25))
        node('CaveApproach','MeshInstance3D',f'script = ExtResource("trail_script")\npoints = PackedVector3Array({points})\nhalf_width = 1.5',parent='.')
    # Ext resources must precede subresources.
    ext=[r for r in resources if r.startswith('[ext')]; sub=[r for r in resources if r.startswith('[sub')]
    source=source.replace('[sub_resource', '\n\n'.join(ext)+'\n\n[sub_resource',1)
    source=source.replace('[node', '\n\n'.join(sub)+'\n\n[node',1)
    source+='\n'+'\n'.join(nodes)
    source=re.sub(r'load_steps=\d+',f'load_steps={1+source.count("[ext_resource")+source.count("[sub_resource")}',source,count=1)
    path.write_text(source)
    zone=GAME/'data/zones'/f'{a["id"]}.tres'
    text=zone.read_text()
    text=re.sub(r'^.*(?:id="minimap"|minimap_texture =|minimap_world_rect =).*\n','',text,flags=re.M)
    zone.write_text(text)
    print(a['id'],len(cells),'walk cells',sum(len(v)//12 for v in groups.values()),'plants/props')

if __name__=='__main__':
    # Regional variant preserves the original species in its existing nation.
    text=(GAME/'data/monsters/jaguar_cub.tres').read_text().replace('MON_JAGUAR_CUB_', 'MON_SABIA_JAGUAR_').replace('id = &"jaguar_cub"','id = &"sabia_jaguar"').replace('region_id = &"mexico"','region_id = &"sabia"')
    (GAME/'data/monsters/sabia_jaguar.tres').write_text(text)
    localization=GAME/'localization/monsters.csv'
    names=localization.read_text()
    if 'MON_SABIA_JAGUAR_S1_NAME' not in names:
        localization.write_text(names.rstrip()+'\nMON_SABIA_JAGUAR_S1_NAME,Onça-pintada Jovem\nMON_SABIA_JAGUAR_S2_NAME,Onça-pintada\n')
    for area in AREAS:
        if area['scenery']=='forest': build(area)
    wg.finish([a['id'] for a in AREAS if a['scenery'] == 'forest'], 'forest')
